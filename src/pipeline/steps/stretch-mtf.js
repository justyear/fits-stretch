/* ------------------------------------------------------------------ *
 * Midtones transfer function (PixInsight STF / Siril autostretch)
 * ------------------------------------------------------------------ */

function MTF(x, m){
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  if (m === 0.5) return x;
  return ((m - 1) * x) / (((2 * m - 1) * x) - m);
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
 * The output is full-precision float. Until Module 1 it was float carrying
 * 8-bit levels — every pixel came back as k/255 for the k a 2^20-entry LUT
 * produced — because while this was the whole chain the LUT could be the
 * authority on what a pixel becomes, and byte-identity of the PNG depended on
 * it staying that way.
 *
 * The second step ends that, which is why it was ended here, one step early and
 * on its own: 256 levels handed from one step to the next throws away the
 * shadows, which is where the faint nebula lives and exactly where background
 * extraction works. The LUT is gone rather than converted to float, because a
 * table indexed by `(u * LMAX) | 0` quantises the input too, and the whole
 * point of this change is that nothing between the decode and the final
 * quantise rounds anything.
 *
 * `quantise` in render.js is now the only place a level is decided, and it runs
 * once, at the end of the chain. The byte-identity criterion died with this
 * commit, deliberately and on schedule — modulo-1-spec.md section 0, and the
 * decision block in modulo-0-spec.md section 4.
 *
 * What did NOT change, and is worth knowing before reading a diff of the
 * goldens: `outLow` and `outHigh` still count the same two branches on the same
 * `u`, so the clip counts, the log and the diagnostics are unmoved. Only
 * `record.after` and the PNG can differ, because only they are downstream of
 * the rounding that went away.
 */
function stepStretchMTF(img, params, report){
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

