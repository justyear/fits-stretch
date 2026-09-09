/* ------------------------------------------------------------------ *
 * Stretch — midtones transfer (PixInsight STF / Siril autostretch) and asinh,
 * per channel or linked through the luminance.
 * ------------------------------------------------------------------ */

function MTF(x, m){
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  if (m === 0.5) return x;
  return ((m - 1) * x) / (((2 * m - 1) * x) - m);
}

/* asinh, normalised so that f(0)=0 and f(1)=1.
 *
 * Lifts faint signal far more than the MTF does without lifting the background
 * in the same proportion, which is what opens a galaxy arm. Applied to the
 * black-point-subtracted value, never to the raw one: run on the raw value the
 * background rises with everything else and the operator's whole advantage
 * disappears (section 3.5).
 */
function ASINH(x, s){
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  return Math.asinh(s * x) / Math.asinh(s);
}

/* `stretch` derived from the data instead of typed in.
 *
 * f(x, s) rises monotonically in s from x (as s approaches 0) to 1 (as s grows),
 * so "which s puts the median on the target?" is one monotone equation in one
 * variable and a bisection settles it. 40 halvings of [1e-6, 1e7] leave a
 * bracket far below any difference the 8-bit output could show, and the whole
 * search costs 40 calls to Math.asinh — nothing, next to one pass over the
 * frame.
 *
 * Returns null when the target is not reachable, which happens when the median
 * already sits above it. The caller treats that as "asinh has nothing to do
 * here" and says so in the record, rather than silently clamping to an
 * endpoint — an operator that quietly stops operating is the failure mode this
 * project keeps finding.
 */
function solveAsinh(x, target){
  if (!(x > 0 && x < 1) || !(target > 0 && target < 1)) return null;
  if (target <= x) return null;
  var lo = 1e-6, hi = 1e7;
  if (ASINH(x, hi) < target) return null;
  for (var k = 0; k < 40; k++){
    var mid = Math.sqrt(lo * hi);          // geometric: s spans seven decades
    if (ASINH(x, mid) < target) lo = mid; else hi = mid;
  }
  return Math.sqrt(lo * hi);
}

// Rec. 709 luminance. These are the weights the sRGB primaries imply, so
// "luminance" here means the same thing it means in the colour space the PNG is
// written in, rather than a convenient average.
var LUM_R = 0.2126, LUM_G = 0.7152, LUM_B = 0.0722;

// Below this the luminance carries no ratio worth preserving and the division
// would be noise over noise. Section 3.2's epsilon.
var LINK_EPS = 1e-8;

/**
 * Autostretch.
 *
 * @param {Image}    img     mutated in place; clone first if you still need it
 * @param {Object}   params  { linked, operator, shadowSigma, target, blackPct,
 *                             nonLinear, stretch, stride, before }
 * @param {Function} report  report(record)
 * @returns {Image}
 *
 * `params.before` is an optional measurement of `img` the caller already holds.
 * It is not a knob and does not appear in record.params: the orchestrator has
 * to measure the frame anyway to decide `nonLinear`, and measuring the same
 * pixels twice would burn a histogram pass and put two objects in play where
 * the log and the diagnostics have to agree on one.
 *
 * The output is full-precision float. Until Module 1 it was float carrying
 * 8-bit levels — every pixel came back as k/255 for the k a 2^20-entry LUT
 * produced — because while this was the whole chain the LUT could be the
 * authority on what a pixel becomes, and byte-identity of the PNG depended on
 * it staying that way.
 *
 * The second step ended that: 256 levels handed from one step to the next
 * throws away the shadows, which is where the faint nebula lives and exactly
 * where background extraction works. `quantise` in render.js is now the only
 * place a level is decided, and it runs once, at the end of the chain.
 */
function stepStretch(img, params, report){
  var linked = !!params.linked && img.channels === 3;
  return linked ? stretchLinked(img, params, report)
                : stretchPerChannel(img, params, report);
}

/* ------------------------------------------------------------------ *
 * Linked — one transfer, derived from the luminance, applied as a ratio
 *
 * THE DEFECT THIS EXISTS TO FIX. Per channel, `shadows` and `midtones` come
 * from each channel's own median and MADN, so each channel goes through a
 * DIFFERENT curve and the ratio between channels on the way out is not the
 * ratio on the way in. Measured on a real M 31 stack: linear stellar ratios
 * R/G 1.054, B/G 0.714; after the per-channel stretch, in the highlights,
 * R/G 1.008, B/G 0.950. The curve ate the colour.
 *
 * That makes the per-channel stretch an undeclared white balance — precisely
 * what the log promises the tool does not do. It is also what makes Module 2
 * pointless on its own: calibrate the colour, then stretch each channel by its
 * own curve, and the calibration is undone by the next step.
 *
 * Linked through the luminance preserves the ratio BY CONSTRUCTION, not by
 * approximation:
 *
 *     Y  = 0.2126R + 0.7152G + 0.0722B
 *     Y' = f(Y)
 *     r  = Y > eps ? Y'/Y : 1
 *     R' = R*r,  G' = G*r,  B' = B*r
 *
 * Every channel is multiplied by the SAME number, so R'/G' = R/G exactly, in
 * real arithmetic. What is left is float32 rounding, and `colourFidelity`
 * measures that on every run rather than asserting it: section 3.2 asks for
 * under 1e-6, and a number above that means the implementation is wrong — not
 * that the tolerance is tight.
 * ------------------------------------------------------------------ */
function stretchLinked(img, params, report){
  var before = params.before || measure(img, params.stride);
  var data = img.data, N = img.N;
  var i;

  var Y = alloc(Float32Array, N, 'the luminance buffer');
  var bR = 0, bG = N, bB = 2 * N;
  for (i = 0; i < N; i++){
    Y[i] = LUM_R * data[bR + i] + LUM_G * data[bG + i] + LUM_B * data[bB + i];
  }

  // ONE set of parameters, off the luminance, never off a channel (section 3.3).
  var ys = analysePlane(Y, 0, N, params.stride || 1);
  if (!ys) throw FitsError('empty', 'the luminance has no usable pixels');

  var shadows, target;
  if (params.nonLinear){
    shadows = ys.percentile(params.blackPct);
    target = Math.min(0.6, Math.max(0.02, ys.median));
  } else {
    shadows = ys.median + params.shadowSigma * ys.madn;
    target = params.target;
  }
  if (!(shadows >= 0)) shadows = 0;
  if (shadows >= ys.median) shadows = Math.max(0, ys.median * 0.5);
  if (shadows >= 1) shadows = 0;

  var scale = 1 / (1 - shadows);
  var xMedian = (ys.median - shadows) * scale;

  var operator = (params.operator === 'asinh') ? 'asinh' : 'mtf';
  var midtones = 0.5, solvedStretch = null, transfer;

  if (operator === 'asinh'){
    // Derived from the data unless the caller pinned one. Derived is the
    // default because it makes asinh answer to the same `target` the MTF
    // answers to, which is the only thing that makes the two comparable.
    solvedStretch = (typeof params.stretch === 'number' && params.stretch > 0)
      ? params.stretch : solveAsinh(xMedian, target);
    if (solvedStretch === null){
      transfer = function(u){ return u; };
    } else {
      var sFixed = solvedStretch;
      transfer = function(u){ return ASINH(u, sFixed); };
    }
  } else {
    midtones = (ys.madn > 0 && xMedian > 0 && xMedian < 1) ? MTF(xMedian, target) : 0.5;
    if (!(midtones > 0 && midtones < 1)) midtones = 0.5;
    var mFixed = midtones;
    transfer = function(u){ return MTF(u, mFixed); };
  }

  // Highlights, for the before/after ratios the record carries: the top 1% of
  // the luminance. Bright enough that a ratio there is a colour and not noise,
  // wide enough that it is not one star.
  var hiCut = ys.percentile(0.99);

  var sumRb = 0, sumGb = 0, sumBb = 0, sumRa = 0, sumGa = 0, sumBa = 0, hiCount = 0;
  var maxDrift = 0, rescaled = 0, low = 0, high = 0, driftSamples = 0;

  for (i = 0; i < N; i++){
    var y = Y[i];
    if (y !== y) y = 0;
    var R = data[bR + i], G = data[bG + i], B = data[bB + i];
    var isHi = (y >= hiCut);

    var u = (y - shadows) * scale;
    var yo;
    // The two clip branches are kept rather than left to the transfer's own
    // guards, because they are what the clip counts count. They are counted on
    // the LUMINANCE now, which is what "this pixel clipped" means once one curve
    // governs all three channels.
    if (u <= 0){ yo = 0; low++; }
    else if (u >= 1){ yo = 1; high++; }
    else yo = transfer(u);

    var r = (y > LINK_EPS) ? (yo / y) : 1;
    var Ro = R * r, Go = G * r, Bo = B * r;

    /* OVERFLOW IS DIVIDED, NOT CLAMPED, AND THE DIFFERENCE IS THE COLOUR.
     *
     * R*r can pass 1 where one channel is much stronger than the luminance.
     * Clamping that channel alone would pull it toward the other two and change
     * the hue of the pixel — a red star would come back pink, and the log would
     * still be claiming nothing was decided about colour.
     *
     * Dividing all three by the maximum keeps every ratio and lands the pixel on
     * white, which is what an overexposed pixel is. The count goes in the record
     * because it is the number that says how much of the frame this touched.
     */
    var mx = Ro > Go ? (Ro > Bo ? Ro : Bo) : (Go > Bo ? Go : Bo);
    if (mx > 1){ Ro /= mx; Go /= mx; Bo /= mx; rescaled++; }

    data[bR + i] = Ro; data[bG + i] = Go; data[bB + i] = Bo;

    if (isHi){
      sumRb += R; sumGb += G; sumBb += B;
      sumRa += Ro; sumGa += Go; sumBa += Bo;
      hiCount++;
    }
    // Per-pixel drift, which is a far stronger statement than comparing two
    // medians: it reports the WORST pixel in the frame, not the typical one.
    // Only where both denominators are big enough for the quotient to mean
    // something — near zero it would be measuring float noise.
    if (G > 1e-3 && Go > 1e-3){
      var d1 = Math.abs(Ro / Go - R / G);
      var d2 = Math.abs(Bo / Go - B / G);
      if (d1 > maxDrift) maxDrift = d1;
      if (d2 > maxDrift) maxDrift = d2;
      driftSamples++;
    }
  }

  var after = measure(img, params.stride);
  var ac = after.perChannel;
  for (var c2 = 0; c2 < ac.length; c2++){
    // One curve, so one pair of clip counts. Written onto every channel rather
    // than into a field of its own, so the record shape does not fork between
    // linked and unlinked and every consumer keeps reading the same key.
    ac[c2].clipLow = low;
    ac[c2].clipHigh = high;
    ac[c2].clipPct = 100 * (low + high) / N;
  }

  /* THE CURVE IS WRITTEN ONTO EVERY CHANNEL, BECAUSE IT GOVERNED EVERY CHANNEL.
   *
   * The diagnostics and the log read `shadows`, `midtones`, `target`, `outLow`
   * and `outHigh` off the stretch record's `before` channels. Leaving them unset
   * on the linked path did not produce an error: JSON.stringify drops undefined,
   * so four fields per channel vanished out of the diagnostics in silence, and
   * the only reason it surfaced is that a negative control was anchored on one
   * of them and stopped with the pattern it could not find.
   *
   * Writing the luminance curve onto each channel is not a patch to keep a
   * consumer quiet: it is the true statement. One curve ran, and it ran on all
   * three.
   */
  var bc = before.perChannel;
  for (var c3 = 0; c3 < bc.length; c3++){
    bc[c3].shadows = shadows;
    bc[c3].midtones = midtones;
    bc[c3].target = target;
    bc[c3].scale = scale;
    bc[c3].outLow = low;
    bc[c3].outHigh = high;
  }

  function ratio(a, b){ return b !== 0 ? a / b : null; }

  report({
    id: operator === 'asinh' ? 'stretch-asinh' : 'stretch-mtf',
    name: operator === 'asinh' ? 'Asinh stretch' : 'Autostretch',
    applied: true,
    skipReason: null,
    params: {
      linked: true, operator: operator, applyVia: 'luminance',
      shadowSigma: params.shadowSigma, target: params.target,
      blackPct: params.blackPct, nonLinear: params.nonLinear,
      stretch: (typeof params.stretch === 'number') ? params.stretch : null
    },
    linked: {
      luminanceMedian: ys.median, luminanceMADN: ys.madn,
      shadows: shadows, midtones: midtones, target: target,
      solvedStretch: solvedStretch,
      stretchUnreachable: (operator === 'asinh' && solvedStretch === null),
      clipLow: low, clipHigh: high, highlightCut: hiCut
    },
    // The module's reason to exist, measured on every run and stored in the
    // golden. If the drift ever rises, the harness catches it.
    colourFidelity: {
      ratiosBefore: { rOverG: ratio(sumRb, sumGb), bOverG: ratio(sumBb, sumGb) },
      ratiosAfter:  { rOverG: ratio(sumRa, sumGa), bOverG: ratio(sumBa, sumGa) },
      maxRatioDrift: maxDrift,
      driftSamples: driftSamples,
      highlightPixels: hiCount,
      pixelsRescaled: rescaled
    },
    before: before,
    after: after,
    notes: []
  });

  return img;
}

/* ------------------------------------------------------------------ *
 * Per channel — the original behaviour, kept exactly
 *
 * Still reachable through `linked: false`, and still what a mono frame gets,
 * because there is no ratio between channels to preserve when there is one
 * channel. Not the default any more: section 3.1.
 * ------------------------------------------------------------------ */
function stretchPerChannel(img, params, report){
  var before = params.before || measure(img, params.stride);
  var ch = before.perChannel;
  var data = img.data, N = img.N;
  var c, i;

  for (c = 0; c < ch.length; c++){
    var st = ch[c];
    var shadows, target;

    if (params.nonLinear){
      shadows = st.percentile(params.blackPct);
      target = Math.min(0.6, Math.max(0.02, st.median));
    } else {
      shadows = st.median + params.shadowSigma * st.madn;
      target = params.target;
    }
    if (!(shadows >= 0)) shadows = 0;
    if (shadows >= st.median) shadows = Math.max(0, st.median * 0.5);
    if (shadows >= 1) shadows = 0;

    var x = (st.median - shadows) / (1 - shadows);
    var midtones = (st.madn > 0 && x > 0 && x < 1) ? MTF(x, target) : 0.5;
    if (!(midtones > 0 && midtones < 1)) midtones = 0.5;

    st.shadows = shadows;
    st.midtones = midtones;
    st.target = target;
    st.scale = 1 / (1 - shadows);
    st.outLow = 0; st.outHigh = 0;
  }

  for (c = 0; c < ch.length; c++){
    var stc = ch[c];
    var sh = stc.shadows, sc = stc.scale, mid = stc.midtones, base = c * N;
    var low = 0, high = 0;
    for (i = 0; i < N; i++){
      var v = data[base + i];
      if (v !== v) v = 0;
      var u = (v - sh) * sc;
      var out;
      // The two clip branches are kept rather than left to MTF's own guards,
      // because they are what outLow and outHigh count. MTF would return the
      // same 0 and 1 silently, and the record would lose the two numbers the
      // log prints.
      if (u <= 0){ out = 0; low++; }
      else if (u >= 1){ out = 1; high++; }
      else out = MTF(u, mid);
      data[base + i] = out;
    }
    stc.outLow = low; stc.outHigh = high;
  }

  var after = measure(img, params.stride);
  for (c = 0; c < ch.length; c++){
    // The same two counts under two names. `outLow`/`outHigh` is the dialect
    // the log and the diagnostics already speak; `clipLow`/`clipHigh`/`clipPct`
    // is the record contract. They collapse into one once the log is built
    // from records instead of from ctx.channels.
    var a = after.perChannel[c];
    a.clipLow = ch[c].outLow;
    a.clipHigh = ch[c].outHigh;
    a.clipPct = 100 * (a.clipLow + a.clipHigh) / N;
  }

  report({
    id: 'stretch-mtf',
    name: 'Autostretch',
    applied: true,
    skipReason: null,
    params: {
      shadowSigma: params.shadowSigma,
      target: params.target,
      blackPct: params.blackPct,
      nonLinear: params.nonLinear
    },
    before: before,
    after: after,
    // Empty on purpose. buildLog still writes its own sentences, and the log
    // has to stay byte-identical this module; duplicating those strings here
    // would create two places to edit and one of them would drift. They move
    // in when the log is generated from records.
    notes: []
  });

  return img;
}

