/* ------------------------------------------------------------------ *
 * Midtones transfer function (PixInsight STF / Siril autostretch)
 * ------------------------------------------------------------------ */

function MTF(x, m){
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  if (m === 0.5) return x;
  return ((m - 1) * x) / (((2 * m - 1) * x) - m);
}

var LUT_BITS = 20, LUT_N = 1 << LUT_BITS;

function buildLUT(midtones){
  var lut = new Uint8Array(LUT_N), inv = 1 / (LUT_N - 1);
  for (var i = 0; i < LUT_N; i++){
    lut[i] = (MTF(i * inv, midtones) * 255 + 0.5) | 0;
  }
  return lut;
}

/**
 * Autostretch — midtones transfer, per channel, unlinked.
 *
 * @param {Image}    img     mutated in place; clone first if you still need it
 * @param {Object}   params  { shadowSigma, target, blackPct, nonLinear, stride,
 *                             before }
 * @param {Function} report  report(record)
 * @returns {Image}
 *
 * `params.before` is an optional measurement of `img` the caller already holds.
 * It is not a knob and does not appear in record.params: the orchestrator has
 * to measure the frame anyway to decide `nonLinear`, and measuring the same
 * pixels twice would burn a histogram pass and put two objects in play where
 * the log and the diagnostics have to agree on one.
 *
 * The output is float, but 8-bit-valued: every pixel comes back as k/255 for
 * the k the 2^20-entry LUT produced. The LUT is the authority on what a pixel
 * becomes, and recomputing MTF at full precision here would move pixels that
 * sit on a rounding boundary, which this module's byte-identity forbids.
 *
 * That holds only while this is the whole chain. THE SECOND STEP ENDS IT: 256
 * levels handed from one step to the next throws away the shadows, which is
 * where the faint nebula lives and exactly where background extraction works.
 * From Module 1 on the chain is full float and quantise runs once, at the end —
 * and the byte-identity criterion dies with it, deliberately. See the decision
 * block in modulo-0-spec.md section 4 before touching this.
 */
function stepStretchMTF(img, params, report){
  var before = params.before || measure(img, params.stride);
  var ch = before.perChannel;
  var data = img.data, N = img.N;
  var luts = [], c, i;

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
    luts.push(buildLUT(midtones));
  }

  var LMAX = LUT_N - 1, INV255 = 1 / 255;

  for (c = 0; c < ch.length; c++){
    var stc = ch[c];
    var lut = luts[c], sh = stc.shadows, sc = stc.scale, base = c * N;
    var low = 0, high = 0;
    for (i = 0; i < N; i++){
      var v = data[base + i];
      if (v !== v) v = 0;
      var u = (v - sh) * sc;
      var out;
      if (u <= 0){ out = 0; low++; }
      else if (u >= 1){ out = 255; high++; }
      else out = lut[(u * LMAX) | 0];
      data[base + i] = out * INV255;
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

