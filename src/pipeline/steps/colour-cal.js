/* ------------------------------------------------------------------ *
 * Colour calibration — background neutralisation, then stellar gains
 *
 * This is the step where the tool starts deciding colour, and the whole design
 * is built so that "deciding" stays a synonym for "measuring". The gains come
 * from the stars in the frame the user opened. There is no catalogue, no plate
 * solve, no network, and no default colour that gets applied when measurement
 * fails — when it fails the step does not run and says so.
 *
 * Order is not a preference. Neutralisation is ADDITIVE and runs FIRST; the
 * gains are MULTIPLICATIVE and run second. Reversed, the gain scales the
 * background offset along with the signal, and the offset is the thing that was
 * supposed to be removed.
 * ------------------------------------------------------------------ */

/* WHY THIS FILE DOES NOT TAKE ITS MEDIANS FROM measure().
 *
 * modulo-2-3-spec.md section 2.1 says to use `measure()`, which already exists.
 * It cannot be used for this, and the spec's own calibration numbers are what
 * prove it.
 *
 * `measure()` bins [0,1] into 65536, so one bin is 1/65535 = 1.526e-5. The
 * background medians the spec measured on the M 31 stack are R 0.001163,
 * G 0.001189, B 0.001183, and the offsets the neutralisation has to apply are
 * the distances from those to their mean:
 *
 *     dR = -1.533e-05   1.00 bin
 *     dG = +1.067e-05   0.70 bin
 *     dB = +4.67e-06    0.31 bin
 *
 * The correction is SMALLER THAN THE INSTRUMENT for two channels out of three.
 * Fed through a histogram median, dB rounds to zero or to a whole bin - nothing
 * or three times too much - and neither outcome would look wrong in the record:
 * a plausible small number would be printed either way.
 *
 * The same applies to the stellar medians. Gains are ratios of numbers around
 * 0.006 to 0.009; at 1.5e-5 resolution that is 2e-3 of relative error, and
 * section 5 of the spec asks for gains to agree with the Python reference to
 * 1e-4. The tolerance would be unmeetable by construction, and the honest
 * reading of that is not "loosen the tolerance" - it is that the instrument is
 * too coarse for the quantity.
 *
 * So the medians here are EXACT: quickselect over the actual values, in the same
 * even-length convention numpy uses, so the reference implementation and this
 * one are computing the same definition rather than two approximations of it.
 * `measure()` still produces the `before`/`after` blocks of the record, which
 * are for the log and the diagnostics and not for any decision taken here.
 */

// Hoare-partition selection: rearranges a[0..n) so that a[k] holds the value it
// would have if the array were sorted, and everything before it is <= it.
// O(n) expected, no allocation, and it is the whole array that gets reordered -
// callers must pass a scratch buffer they own.
function nthElement(a, n, k){
  var lo = 0, hi = n - 1;
  while (lo < hi){
    // Median-of-three pivot. Plain "first element" degenerates to O(n^2) on
    // already-sorted input, and a background plane read row by row is very
    // nearly sorted in places.
    var mid = (lo + hi) >>> 1, t;
    if (a[mid] < a[lo]){ t = a[mid]; a[mid] = a[lo]; a[lo] = t; }
    if (a[hi] < a[lo]){ t = a[hi]; a[hi] = a[lo]; a[lo] = t; }
    if (a[hi] < a[mid]){ t = a[hi]; a[hi] = a[mid]; a[mid] = t; }
    var pivot = a[mid];

    var i = lo, j = hi;
    while (i <= j){
      while (a[i] < pivot) i++;
      while (a[j] > pivot) j--;
      if (i <= j){ t = a[i]; a[i] = a[j]; a[j] = t; i++; j--; }
    }
    if (k <= j) hi = j;
    else if (k >= i) lo = i;
    else return a[k];
  }
  return a[k];
}

// numpy's median convention: for an even count, the mean of the two middle
// values. Matched deliberately - the Python reference calls np.median, and two
// implementations that disagree about the definition would spend a session
// looking for a bug in the arithmetic.
//
// Destroys the order of `a[0..n)`.
function exactMedian(a, n){
  if (n <= 0) return NaN;
  var half = n >> 1;
  var hiVal = nthElement(a, n, half);
  if (n & 1) return hiVal;
  // After selection everything in [0, half) is <= a[half], so the lower middle
  // is the largest of them. One linear scan, no second selection.
  var loVal = a[0];
  for (var i = 1; i < half; i++) if (a[i] > loVal) loVal = a[i];
  return (loVal + hiVal) / 2;
}

var CC_GAIN_MIN = 0.25;
var CC_GAIN_MAX = 4.0;

/* THE STABILITY TEST, AND WHY IT IS NOT A MULTIPLE OF THE PEDESTAL.
 *
 * What has to be true before a ratio taken above the sky can be trusted is that
 * it does not move much when the sky estimate moves a little. That is a
 * question about SENSITIVITY, and it is measurable: perturb the pedestal, redo
 * the arithmetic, see how far the gains travel.
 *
 * This used to be "the faintest star median must be at least 3x the pedestal",
 * and that rule is a guess wearing the costume of a criterion. It was written
 * without measuring the thing it claims to protect, and it was wrong in the
 * direction that costs most: on a 60-hour stack it refused gains of
 * R 1.038 / G 1.000 / B 1.341 -- values independently confirmed against the raw
 * file by another route -- because the ratio came out at 1.87x instead of 3x.
 *
 * The ratio was not unstable. Measured on that stack, perturbing the pedestal:
 *
 *     2% error  ->  blue gain moves 0.60%
 *     5%        ->  1.55%
 *    10%        ->  3.29%
 *    25%        ->  10.2%
 *
 * and the pedestal's real disagreement between two independent implementations
 * is 0.048%, where the blue gain moves less than 0.02%. The safeguard was
 * defending against an error four hundred times larger than the one that
 * happens.
 *
 * So: probe the pedestal by CC_PEDESTAL_PROBE in both directions and refuse if
 * any gain moves by more than CC_SENSITIVITY_MAX. Where the stars really are
 * buried in the sky, `above` is small, the perturbation is a large fraction of
 * it, and the same test refuses on its own -- without a constant anyone had to
 * pick.
 *
 * The measured number goes in the record either way, so the log can say why it
 * trusted rather than only that it did.
 */
var CC_PEDESTAL_PROBE = 0.10;      // 10% error in the sky estimate
var CC_SENSITIVITY_MAX = 0.05;     // ...may move any gain by at most 5%

/* --- extended-source rejection -----------------------------------------
 *
 * A brightness cut selects bright pixels. In a star field that is mostly
 * stars, but a galaxy core is bright over a large connected area and it enters
 * wholesale - and it carries its own colour, which is not the colour of the
 * star population being measured.
 *
 * Measured, and this is why the step has this filter at all: on the synthetic
 * colour fixture the extended object supplied 29.8% of the selected pixels and
 * the step returned the OBJECT's ratio (1.127 / 0.798 against an object tint of
 * 1.10 / 0.80) instead of the stars' 1.25 / 0.80. On a real M 31 stack the core
 * is 39% of the selection, and rejecting it moves R/G from 1.066 to 0.945 -
 * the red gain CHANGES SIGN, from reducing red to increasing it. That is not a
 * refinement; without this the calibration points the wrong way.
 *
 * The discriminator is neighbourhood occupancy, not shape: a star is small and
 * sits in an empty neighbourhood, an extended source sits inside its own body.
 * For every selected pixel, the fraction of ALSO-selected pixels in a window
 * around it; above `frac`, reject. Separable box sums, so O(N) and two passes.
 *
 * The count of rejected pixels is reported as its own state, the same way the
 * background sampler reports rejected-bright and rejected-edge: a rejection
 * nobody can count is a rejection nobody can audit.
 */
function ccRejectExtended(sel, w, h, win, frac){
  var N = w * h, r = win >> 1, x, y, i;
  var rows = alloc(Int32Array, N, 'the star-neighbourhood row sums');
  var cols = alloc(Int32Array, N, 'the star-neighbourhood column sums');

  for (y = 0; y < h; y++){
    var base = y * w, acc = 0, x0, x1;
    for (x = 0; x <= r && x < w; x++) acc += sel[base + x];
    for (x = 0; x < w; x++){
      rows[base + x] = acc;
      x0 = x - r; x1 = x + r + 1;
      if (x1 < w) acc += sel[base + x1];
      if (x0 >= 0) acc -= sel[base + x0];
    }
  }
  for (x = 0; x < w; x++){
    var acc2 = 0, y0, y1;
    for (y = 0; y <= r && y < h; y++) acc2 += rows[y * w + x];
    for (y = 0; y < h; y++){
      cols[y * w + x] = acc2;
      y0 = y - r; y1 = y + r + 1;
      if (y1 < h) acc2 += rows[y1 * w + x];
      if (y0 >= 0) acc2 -= rows[y0 * w + x];
    }
  }

  var rejected = 0;
  for (y = 0; y < h; y++){
    // The window is clipped at the frame edge, so the denominator is the number
    // of pixels actually looked at. Dividing by the nominal window instead would
    // make every edge pixel look sparse and let an object touching the edge
    // through - which is where a galaxy in a badly framed shot sits.
    var yl = (y - r < 0) ? 0 : y - r, yh = (y + r >= h) ? h - 1 : y + r;
    var nY = yh - yl + 1;
    for (x = 0; x < w; x++){
      i = y * w + x;
      if (!sel[i]) continue;
      var xl = (x - r < 0) ? 0 : x - r, xh = (x + r >= w) ? w - 1 : x + r;
      if (cols[i] > frac * nY * (xh - xl + 1)){ sel[i] = 0; rejected++; }
    }
  }
  return rejected;
}

/**
 * Colour calibration.
 *
 * @param {Image}    img     mutated in place
 * @param {Object}   params  { backgroundNeutralise, starSigma, starMax,
 *                             minStarPixels, reference, stride, before }
 * @param {Function} report  report(record)
 * @returns {Image}
 */
function stepColourCal(img, params, report){
  var before = params.before || measure(img, params.stride);
  var N = img.N, data = img.data, nch = img.channels;
  var i, c;

  var effective = {
    backgroundNeutralise: params.backgroundNeutralise !== false,
    starSigma: params.starSigma,
    starMax: params.starMax,
    minStarPixels: params.minStarPixels,
    extendedWindow: params.extendedWindow,
    extendedFrac: params.extendedFrac,
    reference: params.reference || 'green'
  };

  // --- mono ---------------------------------------------------------
  //
  // There is no colour to calibrate and nothing to compare against. This is a
  // refusal, not a no-op with a good outcome, so it is reported as one: the
  // "Not applied" line keeps naming colour calibration, which stays true.
  if (nch !== 3){
    report({
      id: 'colour-cal', name: 'Colour calibration',
      applied: false,
      skipReason: 'the frame has ' + nch + ' channel' + (nch === 1 ? '' : 's') +
                  '; colour calibration needs three',
      params: effective,
      neutralise: null, stars: null, gains: null,
      reference: effective.reference,
      before: before, after: null,
      notes: ['Mono frame: there is no channel ratio to measure or correct.']
    });
    return img;
  }

  var refIdx = (effective.reference === 'red') ? 0
             : (effective.reference === 'blue') ? 2 : 1;

  // One scratch buffer, reused for every median taken below. Allocated through
  // alloc() like everything else that scales with the frame.
  var scratch = alloc(Float32Array, N, 'the colour-calibration median buffer');

  function medianOfPlane(ch){
    var base = ch * N, m = 0, v;
    for (i = 0; i < N; i++){
      v = data[base + i];
      if (v === v) scratch[m++] = v;      // NaN excluded, as everywhere else
    }
    return { median: exactMedian(scratch, m), count: m };
  }

  /* --- 2a. background neutralisation -------------------------------
   *
   * Additive. Shifts each channel's floor to the mean of the three floors, and
   * leaves every difference above the floor exactly where it was: the object
   * keeps its brightness relative to the sky, and only the sky is levelled.
   *
   * Nothing is clamped. Negatives are the normal outcome of levelling a floor
   * and they have to survive to `quantise`, which is the rule the whole chain
   * already follows - a step that clipped its own output could not be audited
   * afterwards.
   */
  var neutralise = null;
  if (effective.backgroundNeutralise){
    var beforeMedians = [], target = 0;
    for (c = 0; c < 3; c++){
      var mm = medianOfPlane(c);
      beforeMedians.push(mm.median);
      target += mm.median;
    }
    target /= 3;

    var offsets = [];
    for (c = 0; c < 3; c++){
      var d = beforeMedians[c] - target;
      offsets.push(d);
      if (d !== 0){
        var b0 = c * N;
        for (i = 0; i < N; i++) data[b0 + i] -= d;
      }
    }
    neutralise = {
      applied: true, skipReason: null,
      beforeMedians: beforeMedians, target: target, offsets: offsets
    };
  } else {
    neutralise = {
      applied: false,
      skipReason: 'backgroundNeutralise is off',
      beforeMedians: null, target: null, offsets: null
    };
  }

  /* --- 2b. gains from stellar flux ---------------------------------
   *
   * Measured on the NEUTRALISED frame, which is the point of the order: with
   * the three floors levelled, a ratio between channels is a ratio between the
   * light above the sky rather than between light-plus-a-different-pedestal.
   */
  var lum = alloc(Float32Array, N, 'the luminance buffer');
  var bR = 0, bG = N, bB = 2 * N;
  for (i = 0; i < N; i++) lum[i] = (data[bR + i] + data[bG + i] + data[bB + i]) / 3;

  // Median and MADN of the luminance, both exact, for the same reason the
  // channel medians are: the threshold is median + 12 x MADN and a MADN
  // quantised at 1.5e-5 moves that threshold by 1.8e-4, which on this data is
  // larger than the whole distance from the background to the first stars.
  var lm = 0;
  for (i = 0; i < N; i++){ var lv = lum[i]; if (lv === lv) scratch[lm++] = lv; }
  var lumMedian = exactMedian(scratch, lm);

  var dm = 0;
  for (i = 0; i < N; i++){ var lv2 = lum[i]; if (lv2 === lv2) scratch[dm++] = Math.abs(lv2 - lumMedian); }
  var lumMadn = 1.4826 * exactMedian(scratch, dm);

  var thresholdLow = lumMedian + effective.starSigma * lumMadn;
  var thresholdHigh = effective.starMax;

  /* THE UPPER CUT IS NOT A DETAIL, AND THIS IS THE FAILURE IT PREVENTS.
   *
   * A saturated star has all three channels pinned at 1.0. Its ratios are
   * exactly 1, and it carries no colour information at all - it is a hole in
   * the data shaped like a measurement. Let a saturated population into the
   * selection and every ratio is pulled toward 1 in proportion to how much of
   * the selection is saturated, so the calibration degrades toward IDENTITY.
   *
   * That is the worst shape a failure can take here, because identity looks
   * like success: the step runs, the record fills in, the gains print as
   * 1.00 / 1.00 / 1.00, and the only way to know the colour was never measured
   * is to already know what the answer should have been. Nothing errors, and
   * the log says the numbers came from the stars - which would be true, and
   * would still leave the reader with a false belief.
   *
   * fixture-colour.fit carries a saturated population on purpose so that this
   * cut is exercised and not merely present.
   */
  var selectedRaw = 0;
  var sel = alloc(Uint8Array, N, 'the star mask');
  for (i = 0; i < N; i++){
    var L = lum[i];
    if (L === L && L > thresholdLow && L < thresholdHigh){ sel[i] = 1; selectedRaw++; }
  }
  var rejectedSaturated = 0;
  for (i = 0; i < N; i++){
    var Ls = lum[i];
    if (Ls === Ls && Ls > thresholdLow && !(Ls < thresholdHigh)) rejectedSaturated++;
  }
  var rejectedExtended = ccRejectExtended(sel, img.w, img.h,
                                          effective.extendedWindow, effective.extendedFrac);
  var count = selectedRaw - rejectedExtended;

  /* THE PEDESTAL, AND WHY THE RATIO IS TAKEN ABOVE IT.
   *
   * The colour of a star is its flux ABOVE the sky, not the number sitting in
   * the pixel. The pixel carries the sky as well, and after neutralisation that
   * sky is the SAME number in all three channels - so it is a common additive
   * term in the numerator and the denominator of every ratio, and it drags all
   * of them toward 1 in proportion to how large it is against the star.
   *
   * Measured on a real M 31 stack: B/G reads 0.714 with the pedestal in and
   * 0.668 with it out, which moves the blue gain from 1.400 to 1.496. Seven per
   * cent, in the channel the data says is the deficient one. The synthetic
   * fixture shows the same thing against a ratio known by construction.
   *
   * Per channel rather than one shared number, because neutralisation can be
   * off. When it ran, all three of these ARE the neutralisation target, and the
   * general form costs nothing.
   */
  var pedestals;
  if (neutralise.applied){
    pedestals = [neutralise.target, neutralise.target, neutralise.target];
  } else {
    pedestals = [];
    for (c = 0; c < 3; c++) pedestals.push(medianOfPlane(c).median);
  }

  var pctFrame = 100 * count / N;
  var stars = {
    applied: false, skipReason: null,
    pixels: count, pctFrame: pctFrame,
    selected: selectedRaw,
    rejected: { saturated: rejectedSaturated, extended: rejectedExtended },
    thresholdLow: thresholdLow, thresholdHigh: thresholdHigh,
    luminanceMedian: lumMedian, luminanceMADN: lumMadn,
    pedestals: pedestals,
    medians: null, abovePedestal: null, ratios: null
  };
  var gains = null;

  if (count < effective.minStarPixels){
    // Two ways to arrive here and they call for different reactions, so the
    // sentence says which. Nothing selected at all is a frame with no stars;
    // selected-then-rejected is a field dense enough to look extended, and
    // that is a misfire worth hearing about rather than a property of the sky.
    stars.skipReason = (rejectedExtended > 0 && selectedRaw >= effective.minStarPixels)
      ? ('only ' + count + ' star pixels survived extended-source rejection (' +
         selectedRaw + ' selected, ' + rejectedExtended + ' rejected as extended); ' +
         effective.minStarPixels + ' are needed. A very dense star field can be ' +
         'rejected as extended by mistake')
      : ('only ' + count + ' pixels are between the star thresholds (' +
         pctFrame.toFixed(3) + '% of the frame); ' + effective.minStarPixels + ' are needed');
  } else {
    var starMedians = [];
    for (c = 0; c < 3; c++){
      var base2 = c * N, k = 0;
      for (i = 0; i < N; i++){
        if (sel[i]){ var sv = data[base2 + i]; if (sv === sv) scratch[k++] = sv; }
      }
      starMedians.push(exactMedian(scratch, k));
    }
    stars.medians = starMedians;

    var above = [];
    for (c = 0; c < 3; c++) above.push(starMedians[c] - pedestals[c]);
    stars.abovePedestal = above;
    stars.ratios = {
      rOverG: above[1] !== 0 ? above[0] / above[1] : null,
      bOverG: above[1] !== 0 ? above[2] / above[1] : null
    };

    var refMedian = above[refIdx];

    // The gains as they stand, and the gains with the sky estimate moved. The
    // probe runs in both directions because the two are not symmetric: `above`
    // shrinks in one and grows in the other, and the shrinking side is where a
    // ratio comes apart.
    function gainsAt(scale){
      var out = [], ok = true;
      var refAbove = starMedians[refIdx] - pedestals[refIdx] * scale;
      if (!(refAbove > 0)) return null;
      for (var k = 0; k < 3; k++){
        var a = starMedians[k] - pedestals[k] * scale;
        if (!(a > 0)) { ok = false; break; }
        out.push(refAbove / a);
      }
      return ok ? out : null;
    }
    var gBase = gainsAt(1);
    var sensitivity = Infinity, sensChannel = -1;
    if (gBase){
      sensitivity = 0;
      for (var s = 0; s < 2; s++){
        var probe = gainsAt(1 + (s === 0 ? CC_PEDESTAL_PROBE : -CC_PEDESTAL_PROBE));
        if (!probe){ sensitivity = Infinity; sensChannel = -1; break; }
        for (var k2 = 0; k2 < 3; k2++){
          if (!(gBase[k2] > 0)) continue;
          var move = Math.abs(probe[k2] - gBase[k2]) / gBase[k2];
          if (move > sensitivity){ sensitivity = move; sensChannel = k2; }
        }
      }
    }
    stars.pedestalProbe = CC_PEDESTAL_PROBE;
    stars.gainSensitivity = isFinite(sensitivity) ? sensitivity : null;
    stars.gainSensitivityChannel = (sensChannel >= 0) ? ['red', 'green', 'blue'][sensChannel] : null;

    if (!(sensitivity <= CC_SENSITIVITY_MAX)){
      stars.skipReason = 'a ' + (100 * CC_PEDESTAL_PROBE).toFixed(0) +
        '% error in the sky estimate would move the ' +
        (sensChannel >= 0 ? ['red', 'green', 'blue'][sensChannel] + ' gain by ' +
           (100 * sensitivity).toFixed(2) + '%'
         : 'gains without limit') +
        ', over the ' + (100 * CC_SENSITIVITY_MAX).toFixed(0) +
        '% this step accepts; the stars are too close to the sky here for a ratio ' +
        'taken above it to be stable';
    } else if (!(refMedian > 0)){
      stars.skipReason = 'the ' + effective.reference + ' star median is ' + refMedian +
                         ' above the sky, which cannot be a reference';
    } else {
      var g = [], bad = null;
      for (c = 0; c < 3; c++){
        var gc = (above[c] > 0) ? (refMedian / above[c]) : NaN;
        g.push(gc);
        if (!(gc >= CC_GAIN_MIN && gc <= CC_GAIN_MAX)) bad = c;
      }
      if (bad !== null){
        // A gain this far out means the selection caught something that is not
        // a star population. Applying it would invent a colour that is not in
        // the data, which is the one thing this step must never do - so it
        // refuses, and says which channel and what it computed.
        stars.skipReason = 'the ' + ['red', 'green', 'blue'][bad] + ' gain came out at ' +
          (isFinite(g[bad]) ? g[bad].toFixed(4) : String(g[bad])) +
          ', outside the permitted range [' + CC_GAIN_MIN + ', ' + CC_GAIN_MAX +
          ']; the selected pixels are not behaving like a star population';
        stars.gainsRejected = g;
      } else {
        for (c = 0; c < 3; c++){
          if (g[c] !== 1){
            var b3 = c * N, gc2 = g[c];
            for (i = 0; i < N; i++) data[b3 + i] *= gc2;
          }
        }
        stars.applied = true;
        gains = g;
      }
    }
  }

  var applied = neutralise.applied || stars.applied;
  var after = applied ? measure(img, params.stride) : null;

  /* WHY `applied` IS THE OR OF THE TWO HALVES.
   *
   * `applied` drives the "Not applied" sentence, and that sentence is about
   * whether a pixel moved. Levelling the background between channels is
   * colour calibration - it is section 2.1 of the module - so if it ran, the
   * log must stop denying colour calibration even when the gains refused.
   *
   * The two halves keep their own `applied` and their own `skipReason`, so the
   * record never has to be read as all-or-nothing, and the log block can say
   * exactly which half ran.
   */
  var notes = [];
  if (!neutralise.applied) notes.push('Background neutralisation: ' + neutralise.skipReason + '.');
  if (!stars.applied) notes.push('Stellar gains: ' + stars.skipReason + '.');
  // Recorded on every run, not only when it bites. A limitation that is only
  // mentioned when it triggers is a limitation nobody reads.
  notes.push('Star selection is a brightness cut, not star detection: bright ' +
             'unsaturated pixels are predominantly stars in a star field. Pixels ' +
             'whose neighbourhood is also mostly selected are rejected as ' +
             'extended, which removes a galaxy core but would also remove a star ' +
             'field dense enough to look like one.');

  report({
    id: 'colour-cal',
    name: 'Colour calibration',
    applied: applied,
    skipReason: applied ? null : (stars.skipReason || neutralise.skipReason),
    params: effective,
    neutralise: neutralise,
    stars: stars,
    gains: gains,
    reference: effective.reference,
    before: before,
    after: after,
    notes: notes
  });

  return img;
}
