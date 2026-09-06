/* ------------------------------------------------------------------ *
 * Pipeline
 * ------------------------------------------------------------------ */

var STRETCH_HISTORY = [
  [/autostretch/i,            'Autostretch'],
  [/histogram\s*transf/i,     'Histogram Transf.'],
  [/asinh/i,                  'Asinh stretch'],
  [/generalised hyperbolic|generalized hyperbolic|\bGHS\b/i, 'GHS'],
  [/midtone/i,                'Midtones transfer'],
  [/\bcurves?\b/i,            'Curves'],
  [/modasinh|autostretch/i,   'Autostretch']
];

// `opts.now` is the only reading of the wall clock the log depends on. It is a
// parameter so that a reference capture can pin it: with the clock read inline,
// the log carried the day it was produced and no golden could stay byte-exact
// past midnight. Nothing else changes — an ordinary run passes no opts and gets
// the clock.
async function runPipeline(buffer, fileName, post, opts){
  opts = opts || {};
  var now = opts.now ? new Date(opts.now) : new Date();

  var t0 = Date.now(), timings = {};
  function mark(name, from){ timings[name] = Date.now() - from; }
  function stage(label, pct){ post({ type: 'progress', stage: label, pct: pct }); }

  var step = Date.now();
  stage('Reading FITS header', 4);
  var hdu = findImageHDU(buffer);
  mark('header', step);

  await yieldNow();
  step = Date.now();
  var decodedInfo = null;
  var keep = function(info){ decodedInfo = info; };
  var dec;
  if (hdu.compressed){
    stage('Unpacking Rice tiles', 12);
    dec = decodeTileCompressed(buffer, hdu, keep, stage);
  } else {
    stage('Decoding pixel data', 12);
    dec = toNormalisedFloat(buffer, hdu, keep);
  }
  mark('decode', step);

  var w = dec.w, h = dec.h, planes = dec.planes;
  var m = hdu.map;

  // Row order --------------------------------------------------------
  var rowOrder = (typeof m.ROWORDER === 'string') ? m.ROWORDER.trim().toUpperCase() : null;
  var flipped = (rowOrder !== 'TOP-DOWN');   // absent means the FITS default, BOTTOM-UP
  if (flipped){
    await yieldNow();
    step = Date.now();
    stage('Correcting row order', 22);
    flipRows(dec.data, w, h, planes);
    mark('roworder', step);
  }

  // Colour filter array ----------------------------------------------
  var data = dec.data;
  var outChannels = 1, cfa = null, patternInfo = null, headerPattern = null;

  if (planes >= 3){
    outChannels = 3;
  } else {
    await yieldNow();
    step = Date.now();
    stage('Testing for a Bayer mosaic', 32);

    var stackedBefore = hdu.history.some(function(l){
      return /debayer|demosaic|stack|drizzle|registration|register/i.test(l);
    });

    var bp = (typeof m.BAYERPAT === 'string') ? m.BAYERPAT.trim().toUpperCase() : null;
    headerPattern = (bp && PATTERNS.indexOf(bp) >= 0) ? bp : null;

    cfa = detectCFA(data, w, h);
    cfa.stackedHistory = stackedBefore;
    cfa.headerDeclared = !!headerPattern;
    cfa.trustedHeader = false;

    // BAYERPAT is the strong evidence and is not overruled by statistics. The
    // lattice tests exist to catch a mosaic whose keyword was stripped, and to
    // settle which diagonal the greens sit on once row order has been applied.
    // A real 10-second sub-frame carries only a couple of percent of lattice
    // contrast beneath a per-pixel noise floor several times larger, so the
    // neighbour-ratio test cannot see it — vetoing the header on that basis
    // renders colour frames as grey mosaics.
    if (headerPattern && cfa.evenDims && !stackedBefore){
      cfa.isMosaic = true;
      cfa.trustedHeader = true;
    }
    mark('cfa', step);

    if (cfa.isMosaic){
      patternInfo = resolvePattern(headerPattern, cfa, (m.XBAYROFF | 0), (m.YBAYROFF | 0));

      await yieldNow();
      step = Date.now();
      stage('Debayering', 42);
      data = debayer(data, w, h, patternInfo.pattern);
      outChannels = 3;
      mark('debayer', step);
    }
  }

  var N = w * h;

  // Statistics --------------------------------------------------------
  await yieldNow();
  step = Date.now();
  stage('Measuring median and MAD', 56);
  var statStride = Math.max(1, Math.ceil(N / 8000000));
  var channels = [];
  for (var c = 0; c < outChannels; c++){
    var s = analysePlane(data, c * N, N, statStride);
    if (!s) throw FitsError('empty', 'channel ' + c + ' has no usable pixels');
    s.totalPixels = N;
    channels.push(s);
  }
  mark('stats', step);

  // Linearity ---------------------------------------------------------
  var globalMedian = 0;
  for (c = 0; c < channels.length; c++) globalMedian += channels[c].median;
  globalMedian /= channels.length;

  var historyHits = [];
  for (var hi = 0; hi < STRETCH_HISTORY.length; hi++){
    var rule = STRETCH_HISTORY[hi];
    if (historyHits.indexOf(rule[1]) >= 0) continue;
    for (var li = 0; li < hdu.history.length; li++){
      if (rule[0].test(hdu.history[li])){ historyHits.push(rule[1]); break; }
    }
  }
  var nonLinear = (globalMedian >= 0.05) || (historyHits.length > 0 && globalMedian >= 0.02);

  var SHADOW_SIGMA = -2.80, TARGET = 0.25, BLACK_PCT = 0.0005;

  // Transfer ----------------------------------------------------------
  await yieldNow();
  step = Date.now();
  stage('Applying autostretch', 68);

  var luts = [];
  for (c = 0; c < channels.length; c++){
    var st = channels[c];
    var shadows, target;

    if (nonLinear){
      shadows = st.percentile(BLACK_PCT);
      target = Math.min(0.6, Math.max(0.02, st.median));
    } else {
      shadows = st.median + SHADOW_SIGMA * st.madn;
      target = TARGET;
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

  var rgba = new Uint8ClampedArray(N * 4);
  var LMAX = LUT_N - 1;

  for (c = 0; c < channels.length; c++){
    var stc = channels[c];
    var lut = luts[c], sh = stc.shadows, sc = stc.scale, base = c * N;
    var low = 0, high = 0;
    for (var i = 0; i < N; i++){
      var v = data[base + i];
      if (v !== v) v = 0;
      var u = (v - sh) * sc;
      var out;
      if (u <= 0){ out = 0; low++; }
      else if (u >= 1){ out = 255; high++; }
      else out = lut[(u * LMAX) | 0];
      var o = i * 4 + c;
      rgba[o] = out;
      if (channels.length === 1){ rgba[o + 1] = out; rgba[o + 2] = out; }
    }
    stc.outLow = low; stc.outHigh = high;
  }
  for (i = 3; i < rgba.length; i += 4) rgba[i] = 255;
  mark('transfer', step);

  // Display copy ------------------------------------------------------
  await yieldNow();
  step = Date.now();
  stage('Rendering', 88);
  var view = downscale(rgba, w, h);
  mark('downscale', step);

  // Log ---------------------------------------------------------------
  var ctx = {
    fileName: fileName,
    date: now.toISOString().slice(0, 10),
    decoded: decodedInfo,
    rowOrder: rowOrder,
    cfa: cfa,
    headerPattern: headerPattern,
    pattern: patternInfo || { pattern: null, source: null, corrected: false, notes: [] },
    outChannels: outChannels,
    channels: channels,
    exportScaled: false, exportW: w, exportH: h,
    stretch: {
      nonLinear: nonLinear, globalMedian: globalMedian, historyHits: historyHits,
      shadowSigma: SHADOW_SIGMA, target: TARGET, blackPercentile: BLACK_PCT
    }
  };
  var log = buildLog(ctx);

  timings.total = Date.now() - t0;

  var diag = {
    file: fileName,
    hduIndex: hdu.index,
    dataStart: hdu.dataStart,
    header: {
      BITPIX: m.BITPIX, NAXIS: m.NAXIS, NAXIS1: m.NAXIS1, NAXIS2: m.NAXIS2, NAXIS3: m.NAXIS3,
      BZERO: m.BZERO, BSCALE: m.BSCALE, ROWORDER: m.ROWORDER, BAYERPAT: m.BAYERPAT,
      XBAYROFF: m.XBAYROFF, YBAYROFF: m.YBAYROFF, PROGRAM: m.PROGRAM, INSTRUME: m.INSTRUME,
      CREATOR: m.CREATOR, TELESCOP: m.TELESCOP,
      OBJECT: m.OBJECT, STACKCNT: m.STACKCNT, EXPTIME: m.EXPTIME,
      compressedHDU: !!hdu.compressed,
      ZCMPTYPE: m.ZCMPTYPE, ZQUANTIZ: m.ZQUANTIZ, ZDITHER0: m.ZDITHER0,
      ZBITPIX: m.ZBITPIX, ZTILE: hdu.compressed ? [m.ZTILE1, m.ZTILE2, m.ZTILE3] : undefined,
      tableNAXIS1: hdu.table ? hdu.table.NAXIS1 : undefined,
      tableNAXIS2: hdu.table ? hdu.table.NAXIS2 : undefined,
      tablePCOUNT: hdu.table ? hdu.table.PCOUNT : undefined
    },
    decoded: decodedInfo,
    rowOrder: { keyword: rowOrder, flipApplied: flipped },
    cfa: cfa ? {
      evenDims: cfa.evenDims, isMosaic: cfa.isMosaic,
      headerDeclared: cfa.headerDeclared, trustedHeader: cfa.trustedHeader,
      decidedBy: cfa.trustedHeader ? 'BAYERPAT keyword (statistics used only for the green axis)'
                                   : 'lattice statistics (no usable BAYERPAT)',
      ratioH: cfa.ratioH, ratioV: cfa.ratioV, threshold: 1.15,
      latticeMedians: { r0c0: cfa.lattice[0], r0c1: cfa.lattice[1], r1c0: cfa.lattice[2], r1c1: cfa.lattice[3] },
      latticeContrast: cfa.contrast, greenAxis: cfa.greenAxis,
      stackedHistory: cfa.stackedHistory
    } : 'skipped — file already has ' + planes + ' planes',
    pattern: patternInfo || 'no debayer',
    linearity: {
      globalMedian: globalMedian, historyHits: historyHits,
      rule: 'nonLinear = median >= 0.05 OR (history stretch AND median >= 0.02)',
      verdict: nonLinear ? 'NON-LINEAR — reduced stretch' : 'LINEAR — full autostretch'
    },
    channels: channels.map(function(s, idx){
      return {
        channel: outChannels === 1 ? 'L' : ['R', 'G', 'B'][idx],
        median: s.median, madn: s.madn, q1: s.q1, q3: s.q3,
        shadows: s.shadows, midtones: s.midtones, target: s.target,
        pixelsBlack: s.outLow, pixelsWhite: s.outHigh,
        totalPixels: s.totalPixels, statSamples: s.sampled, statStride: s.stride, nonFinite: s.nan
      };
    }),
    view: { width: view.w, height: view.h, downscaleFactor: view.factor },
    timingsMs: timings,
    historyCards: hdu.history,
    allCards: hdu.cards
  };

  // A tile-compressed file can be handed back as a plain FITS. What goes out is
  // the linear, pre-stretch, pre-debayer data — the thing the .fz actually
  // holds — so Siril receives the file it would have had if the frame had never
  // been packed. `dec.data` survives the debayer (which allocates its own
  // output) and any row flip is undone at write time.
  var fitsMeta = null, fitsBuffer = null;
  if (hdu.compressed){
    fitsMeta = {
      cards: hdu.cards,
      bitpix: decodedInfo.bitpix, bzero: decodedInfo.bzero, bscale: decodedInfo.bscale,
      width: w, height: h, planes: planes,
      flipApplied: flipped,
      scaleLo: decodedInfo.scaleLo, scaleDiv: decodedInfo.scaleDiv,
      cmptype: (decodedInfo.compression && decodedInfo.compression.type) || 'tile'
    };
    fitsBuffer = dec.data.buffer;
  }

  var transfer = (view.factor === 1) ? [view.data.buffer] : [view.data.buffer, rgba.buffer];
  if (fitsBuffer) transfer.push(fitsBuffer);

  post({
    type: 'done',
    log: log,
    width: w, height: h,
    view: { w: view.w, h: view.h, factor: view.factor },
    viewData: view.data.buffer,
    fullData: (view.factor === 1) ? null : rgba.buffer,
    fitsMeta: fitsMeta,
    fitsData: fitsBuffer,
    diag: diag
  }, transfer);
}

/* ------------------------------------------------------------------ *
 * Message protocol — identical in worker and main-thread fallback
 * ------------------------------------------------------------------ */

self.onmessage = function(ev){
  var msg = ev.data;
  runPipeline(msg.buffer, msg.fileName, function(payload, transfer){
    self.postMessage(payload, transfer || []);
  }, msg.opts).catch(function(e){
    self.postMessage({ type: 'error', kind: e.kind || 'unknown', message: String(e && e.message || e) });
  });
};

// Handshake: the host waits for this before handing over the file buffer, so a
// worker that cannot start never costs us the (already transferred) data.
self.postMessage({ type: 'ready' });
