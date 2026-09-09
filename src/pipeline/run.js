/* ------------------------------------------------------------------ *
 * Pipeline — open / run / export
 *
 * The decoded frame is read once and kept here, so re-running the chain with
 * different parameters costs a stretch instead of a decode. `source` and
 * `preview` are immutable from the moment open() finishes: every run works on
 * a clone.
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

var PREVIEW_EDGE = 1024;

// Everything open() decoded. Null until a file has been opened.
var SESSION = null;

/* ------------------------------------------------------------------ *
 * Message-safe copies
 *
 * A measurement carries a `percentile` closure over its histogram, which a
 * step needs and structured clone refuses. Stripping functions costs nothing
 * and keeps the two execution paths honest: the main-thread fallback hands the
 * object straight over and would have carried the closure across happily, so
 * without this the worker path and the file:// path would disagree about what
 * a record is.
 * ------------------------------------------------------------------ */

function plainValues(o){
  var out = {}, k;
  for (k in o) if (typeof o[k] !== 'function') out[k] = o[k];
  return out;
}

function plainMeasurement(m){
  if (!m) return null;
  var out = [];
  for (var i = 0; i < m.perChannel.length; i++) out.push(plainValues(m.perChannel[i]));
  return { perChannel: out };
}

function plainRecords(records){
  var out = [];
  for (var i = 0; i < records.length; i++){
    var r = records[i];
    out.push({
      id: r.id, name: r.name, applied: r.applied, skipReason: r.skipReason,
      params: r.params, notes: r.notes,
      // `samples` and `surface` are plain data — numbers, strings and nulls —
      // so they cross the worker boundary as they are. They are carried rather
      // than dropped because they are the audit trail: the point that was
      // rejected, and the sentence saying why, are the whole argument that this
      // step is not doing something silently.
      samples: r.samples || null,
      surface: r.surface || null,
      correction: r.correction || null,
      clamped: r.clamped || null,
      // Colour calibration's audit trail, same argument: the offsets, the
      // thresholds, how many pixels were selected and what the gains came out
      // at are the evidence that the colour was measured and not chosen.
      // Carried even when the step refused, because a refusal with its reason
      // is the part a reader most needs.
      neutralise: r.neutralise || null,
      stars: r.stars || null,
      gains: r.gains || null,
      reference: r.reference || null,
      before: plainMeasurement(r.before),
      after: plainMeasurement(r.after)
    });
  }
  return out;
}

// A run must not inherit the fields a previous run's step wrote onto the shared
// source measurement. The percentile closure is copied by reference on purpose:
// it reads a histogram that is finished and never changes.
// A record is found by its id, never by its position. `records[0]` was a real
// bug once: a step inserted ahead of another silently handed the wrong
// measurement downstream, and it only surfaced because the shapes happened to
// differ enough to crash. With a third step in the chain the positions move
// again, which is exactly when this has to already be by name.
function recordById(records, id){
  for (var i = 0; i < records.length; i++){
    if (records[i] && records[i].id === id) return records[i];
  }
  return null;
}

function copyMeasurement(m){
  var out = [];
  for (var i = 0; i < m.perChannel.length; i++){
    var s = m.perChannel[i], o = {}, k;
    for (k in s) o[k] = s[k];
    out.push(o);
  }
  return { perChannel: out };
}

/* ------------------------------------------------------------------ *
 * open — decode once, measure once, then render with the defaults
 * ------------------------------------------------------------------ */

async function openFile(buffer, fileName, opts, post){
  opts = opts || {};

  // `opts.now` is the only reading of the wall clock the log depends on. It is
  // a parameter so a reference capture can pin it: read inline, the log carried
  // the day it was produced and no golden could stay byte-exact past midnight.
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

  // The linear frame, as read. Immutable from here: every run clones it.
  //
  // When no debayer ran, `data` IS `dec.data` — the buffer the FITS export
  // hands back. That aliasing is why nothing downstream is allowed to write
  // through `source`, and why export copies instead of transferring.
  var source = new Image(data, w, h, outChannels);

  await yieldNow();
  step = Date.now();
  stage('Building preview', 50);
  var preview = downscaleFloat(source, PREVIEW_EDGE);
  mark('preview', step);

  // Statistics --------------------------------------------------------
  await yieldNow();
  step = Date.now();
  stage('Measuring median and MAD', 56);
  var statStride = Math.max(1, Math.ceil(N / 8000000));
  var sourceStats = measure(source, statStride);
  mark('stats', step);

  // Linearity — an orchestration decision, so it is decided here and handed
  // to the step as a parameter rather than sniffed inside it.
  var channels = sourceStats.perChannel;
  var globalMedian = 0, c;
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

  // A tile-compressed file can be handed back as a plain FITS. What goes out is
  // the linear, pre-stretch, pre-debayer data — the thing the .fz actually
  // holds — so Siril receives the file it would have had if the frame had never
  // been packed. Any row flip is undone at write time.
  var fitsMeta = null;
  if (hdu.compressed){
    fitsMeta = {
      cards: hdu.cards,
      bitpix: decodedInfo.bitpix, bzero: decodedInfo.bzero, bscale: decodedInfo.bscale,
      width: w, height: h, planes: planes,
      flipApplied: flipped,
      scaleLo: decodedInfo.scaleLo, scaleDiv: decodedInfo.scaleDiv,
      cmptype: (decodedInfo.compression && decodedInfo.compression.type) || 'tile'
    };
  }

  // One flat bag for the whole chain, so the host has one object to edit and
  // one object to send back. The background knobs carry a bg prefix here and
  // lose it on the way into the step: `tolerance` and `target` are meaningful
  // names inside a step and ambiguous the moment two steps share a namespace.
  var defaults = {
    shadowSigma: -2.80,
    target: 0.25,
    blackPct: 0.0005,
    nonLinear: nonLinear,
    bgSamplesPerRow: 12,
    bgBoxSize: 25,
    bgTolerance: 1.0,
    bgEdgeMargin: 0.02,
    bgSmoothing: 0.10,
    bgCorrection: 'subtract',
    bgPedestal: 'model-median',
    // Colour calibration. Off by default in this delivery: Module 2 lands
    // measured and verified, and the switch that turns it on for everyone waits
    // for Module 3, because calibrating and then stretching each channel by its
    // own curve undoes the calibration - modulo-2-3-spec.md section 3.1 measured
    // exactly that. Shipping it on now would mean shipping a step whose effect
    // the next step removes.
    colourCal: false,
    ccNeutralise: true,
    ccStarSigma: 12.0,
    ccStarMax: 0.85,
    ccMinStarPixels: 2000,
    // Extended-source rejection. 25 px is the same window the background sampler
    // uses for its boxes, and 0.50 was stable between 0.25 and 0.60 on real data
    // - a plateau that wide means a real population is being separated, not an
    // artefact of where the threshold happens to sit.
    ccExtendedWindow: 25,
    ccExtendedFrac: 0.50,
    ccReference: 'green',
    dither: true
  };

  SESSION = {
    fileName: fileName,
    now: now,
    hdu: hdu, map: m,
    decData: dec.data,
    decodedInfo: decodedInfo,
    rowOrder: rowOrder, flipped: flipped,
    cfa: cfa, patternInfo: patternInfo, headerPattern: headerPattern,
    planes: planes, outChannels: outChannels,
    source: source, preview: preview,
    sourceStats: sourceStats, statStride: statStride,
    globalMedian: globalMedian, historyHits: historyHits,
    defaults: defaults,
    fitsMeta: fitsMeta,
    openTimings: timings, openMs: Date.now() - t0,
    autoRunDone: false
  };

  post({
    type: 'opened',
    fileName: fileName,
    width: w, height: h, channels: outChannels,
    // The preview buffer stays here — it is float, and nothing on the host can
    // draw float. What the host gets is its shape, so it can size a control.
    preview: { w: preview.w, h: preview.h, factor: Math.ceil(Math.max(w, h) / PREVIEW_EDGE) },
    header: headerSummary(hdu, m),
    cfa: cfaSummary(cfa, planes),
    records: [],                 // step records; nothing has run yet
    defaults: defaults,
    canExportFits: !!fitsMeta
  });

  // Dropping a file still produces an image and a log without the host asking
  // for anything. The protocol got a shape; the behaviour did not change.
  await runChain(defaults, 'full', post);
}

/* ------------------------------------------------------------------ *
 * run — the chain, on a clone, at preview or full resolution
 * ------------------------------------------------------------------ */

async function runChain(params, mode, post){
  if (!SESSION) throw FitsError('unknown', 'run before open');
  mode = (mode === 'preview') ? 'preview' : 'full';
  params = params || SESSION.defaults;

  var runStart = Date.now();
  var timings = {}, k;
  for (k in SESSION.openTimings) timings[k] = SESSION.openTimings[k];
  function mark(name, from){ timings[name] = Date.now() - from; }
  function stage(label, pct){ post({ type: 'progress', stage: label, pct: pct }); }

  var full = (mode === 'full');
  var base = full ? SESSION.source : SESSION.preview;

  await yieldNow();
  var step = Date.now();

  var work = base.clone();
  // Full mode reuses the measurement open() already took of these exact pixels.
  // Preview is a different frame and has to be measured on its own — reusing
  // the full-frame numbers would stretch the preview by parameters derived
  // from an image it is not.
  var measured = full ? SESSION.sourceStats : measure(work, 1);

  var records = [];
  function report(record){ records.push(record); }

  // The measurement is copied rather than shared: stepStretchMTF writes
  // shadows, midtones, target and scale onto the channels of its own `before`,
  // and the background record would otherwise carry stretch parameters inside a
  // measurement taken before the stretch existed.
  stage('Sampling the background', 60);
  work = stepBackground(work, {
    samplesPerRow: params.bgSamplesPerRow,
    boxSize: params.bgBoxSize,
    tolerance: params.bgTolerance,
    edgeMargin: params.bgEdgeMargin,
    smoothing: params.bgSmoothing,
    correction: params.bgCorrection,
    pedestal: params.bgPedestal,
    // Which buffer this is, expressed as a fraction of the frame the user is
    // working on. The step scales its sample box by it. Full runs are 1 by
    // definition; the preview is whatever downscaleFloat produced.
    scale: full ? 1 : (work.w / SESSION.source.w),
    stride: full ? SESSION.statStride : 1,
    before: copyMeasurement(measured)
  }, report);
  mark('background', step);

  await yieldNow();
  step = Date.now();
  stage('Applying autostretch', 68);

  // THE STRETCH MUST MEASURE THE FRAME IT IS ABOUT TO TRANSFORM, not the frame
  // that arrived. Background extraction removes the gradient, and the gradient
  // was part of the spread the MADN measured: reusing the earlier measurement
  // sets the black point at `median - 2.8 x MADN` on a MADN inflated by
  // variation that is no longer there, and the stretch comes out weaker than it
  // should be, everywhere, quietly.
  //
  // This was harmless while the background step only sampled — the two
  // measurements described the same pixels — and became wrong the moment a
  // pixel moved. The background step already measured the corrected frame as
  // its own `after`, so the right number is free; what is not free is
  // remembering to use it.
  var bgRecord = recordById(records, 'background');
  var lastMeasured = bgRecord.after ? bgRecord.after : measured;

  // Colour calibration ------------------------------------------------
  //
  // Between the background and the stretch, and in that order for a reason the
  // spec states and the arithmetic enforces: neutralisation is additive, gains
  // are multiplicative, and the background step is what makes a per-channel
  // median mean anything (a gradient biases it, and the neutralisation would be
  // measuring the slope instead of the cast).
  if (params.colourCal){
    await yieldNow();
    step = Date.now();
    stage('Measuring colour from the stars', 64);
    work = stepColourCal(work, {
      backgroundNeutralise: params.ccNeutralise,
      starSigma: params.ccStarSigma,
      starMax: params.ccStarMax,
      minStarPixels: params.ccMinStarPixels,
      extendedWindow: params.ccExtendedWindow,
      extendedFrac: params.ccExtendedFrac,
      reference: params.ccReference,
      stride: full ? SESSION.statStride : 1,
      before: copyMeasurement(lastMeasured)
    }, report);
    mark('colour', step);

    var ccRecord = recordById(records, 'colour-cal');
    if (ccRecord && ccRecord.after) lastMeasured = ccRecord.after;
  }

  var stretchBefore = copyMeasurement(lastMeasured);

  work = stepStretchMTF(work, {
    shadowSigma: params.shadowSigma,
    target: params.target,
    blackPct: params.blackPct,
    nonLinear: params.nonLinear,
    stride: full ? SESSION.statStride : 1,
    before: stretchBefore
  }, report);
  mark('transfer', step);

  // Quantise ----------------------------------------------------------
  await yieldNow();
  step = Date.now();
  var rgba = quantise(work, { dither: params.dither }, report);
  mark('quantise', step);

  // Display copy ------------------------------------------------------
  await yieldNow();
  step = Date.now();
  stage('Rendering', 88);
  var view = downscale(rgba, work.w, work.h);
  mark('downscale', step);

  // By id, not by position. The log and the diagnostics print the numbers the
  // autostretch derived — shadows, midtones, the clip counts — and those live
  // on the channels of the stretch step's own `before`. Reading records[0]
  // worked only while the stretch was the whole chain, and would have silently
  // started reporting another step's measurement the moment one landed in
  // front of it.
  var stretchRecord = recordById(records, 'stretch-mtf');
  if (!stretchRecord) throw FitsError('unknown', 'the chain produced no stretch record');

  var channels = stretchRecord.before.perChannel;
  var log = null, diag = null;

  if (full){
    var ctx = {
      fileName: SESSION.fileName,
      date: SESSION.now.toISOString().slice(0, 10),
      decoded: SESSION.decodedInfo,
      rowOrder: SESSION.rowOrder,
      cfa: SESSION.cfa,
      headerPattern: SESSION.headerPattern,
      pattern: SESSION.patternInfo || { pattern: null, source: null, corrected: false, notes: [] },
      outChannels: SESSION.outChannels,
      channels: channels,
      records: records,
      exportScaled: false, exportW: work.w, exportH: work.h,
      stretch: {
        nonLinear: params.nonLinear, globalMedian: SESSION.globalMedian,
        historyHits: SESSION.historyHits,
        shadowSigma: params.shadowSigma, target: params.target,
        blackPercentile: params.blackPct
      }
    };
    log = buildLog(ctx);

    timings.total = (SESSION.autoRunDone ? 0 : SESSION.openMs) + (Date.now() - runStart);
    diag = buildDiag(channels, view, timings, params);
  }
  SESSION.autoRunDone = true;

  var transfer = (view.factor === 1) ? [view.data.buffer] : [view.data.buffer, rgba.buffer];

  post({
    type: 'rendered',
    mode: mode,
    width: work.w, height: work.h,
    view: { w: view.w, h: view.h, factor: view.factor },
    viewData: view.data.buffer,
    rgba: (view.factor === 1) ? null : rgba.buffer,
    log: log,
    // Preview measures a smaller frame, so its numbers describe that frame and
    // not the one the log is about. Handing back a diagnostics panel built from
    // them would invite reading preview statistics as frame statistics.
    diag: diag,
    records: plainRecords(records)
  }, transfer);
}

/* ------------------------------------------------------------------ *
 * export — the linear frame, back out as a plain FITS
 * ------------------------------------------------------------------ */

function exportFits(kind, post){
  if (!SESSION) throw FitsError('unknown', 'export before open');
  if (kind && kind !== 'fits') throw FitsError('unknown', 'unknown export kind: ' + kind);
  if (!SESSION.fitsMeta){
    throw FitsError('unknown', 'this file did not arrive compressed, so there is nothing to unpack');
  }

  // A copy, never a transfer. When no debayer ran, `source.data` and `decData`
  // are the same buffer, and transferring it would detach the frame every
  // later run depends on.
  var copy = allocFrom(Float32Array, SESSION.decData, 'the FITS export buffer');
  post({ type: 'exported', kind: 'fits', fitsMeta: SESSION.fitsMeta, fitsData: copy.buffer },
       [copy.buffer]);
}

/* ------------------------------------------------------------------ *
 * Diagnostics
 * ------------------------------------------------------------------ */

function headerSummary(hdu, m){
  return {
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
  };
}

function cfaSummary(cfa, planes){
  if (!cfa) return 'skipped — file already has ' + planes + ' planes';
  return {
    evenDims: cfa.evenDims, isMosaic: cfa.isMosaic,
    headerDeclared: cfa.headerDeclared, trustedHeader: cfa.trustedHeader,
    decidedBy: cfa.trustedHeader ? 'BAYERPAT keyword (statistics used only for the green axis)'
                                 : 'lattice statistics (no usable BAYERPAT)',
    ratioH: cfa.ratioH, ratioV: cfa.ratioV, threshold: 1.15,
    latticeMedians: { r0c0: cfa.lattice[0], r0c1: cfa.lattice[1], r1c0: cfa.lattice[2], r1c1: cfa.lattice[3] },
    latticeContrast: cfa.contrast, greenAxis: cfa.greenAxis,
    stackedHistory: cfa.stackedHistory
  };
}

function buildDiag(channels, view, timings, params){
  var S = SESSION;
  return {
    file: S.fileName,
    hduIndex: S.hdu.index,
    dataStart: S.hdu.dataStart,
    header: headerSummary(S.hdu, S.map),
    decoded: S.decodedInfo,
    rowOrder: { keyword: S.rowOrder, flipApplied: S.flipped },
    cfa: cfaSummary(S.cfa, S.planes),
    pattern: S.patternInfo || 'no debayer',
    linearity: {
      globalMedian: S.globalMedian, historyHits: S.historyHits,
      rule: 'nonLinear = median >= 0.05 OR (history stretch AND median >= 0.02)',
      verdict: params.nonLinear ? 'NON-LINEAR — reduced stretch' : 'LINEAR — full autostretch'
    },
    channels: channels.map(function(s, idx){
      return {
        channel: S.outChannels === 1 ? 'L' : ['R', 'G', 'B'][idx],
        median: s.median, madn: s.madn, q1: s.q1, q3: s.q3,
        shadows: s.shadows, midtones: s.midtones, target: s.target,
        pixelsBlack: s.outLow, pixelsWhite: s.outHigh,
        totalPixels: s.totalPixels, statSamples: s.sampled, statStride: s.stride, nonFinite: s.nan
      };
    }),
    view: { width: view.w, height: view.h, downscaleFactor: view.factor },
    timingsMs: timings,
    historyCards: S.hdu.history,
    allCards: S.hdu.cards
  };
}

/* ------------------------------------------------------------------ *
 * Message protocol — identical in worker and main-thread fallback
 * ------------------------------------------------------------------ */

self.onmessage = function(ev){
  var msg = ev.data || {};

  function post(payload, transfer){ self.postMessage(payload, transfer || []); }
  function fail(e){
    // An unlabelled RangeError is NOT a memory limit. This used to say the
    // opposite, and the reasoning it gave — "the header is validated before
    // anything large is requested, so by the time a RangeError can happen the
    // size is one the file genuinely declares" — was false. Two files proved
    // it: a negative PCOUNT walked past the size check and a ZTILE of
    // 100000 x 100000 asked for a 40 GB tile buffer, and both came out as
    // "this frame is too large for the browser to hold" about files of five
    // and fourteen kilobytes. Both are now rejected as `badheader` upstream.
    //
    // The direction that is actually provable runs the other way. Every
    // allocation this chain makes that scales with the file goes through
    // `alloc`/`allocFrom`, which label failure as `memory` themselves and name
    // the buffer. What remains unlabelled is a typed-array *view* over the file
    // buffer, and one of those throws when an offset or length does not fit —
    // which is a bounds error, not a browser limit. So it maps to `unknown`,
    // whose text asks for a report, and that is the correct request: reaching
    // here means a validation gap upstream, and the gap is worth hearing about.
    var kind = (e && e.kind) || 'unknown';
    post({ type: 'error', kind: kind, message: String((e && e.message) || e) });
  }

  try {
    if (msg.cmd === 'open'){
      openFile(msg.buffer, msg.fileName, msg.opts, post).catch(fail);
    } else if (msg.cmd === 'run'){
      runChain(msg.params, msg.mode, post).catch(fail);
    } else if (msg.cmd === 'export'){
      exportFits(msg.kind, post);
    } else {
      throw FitsError('unknown', 'unknown command: ' + msg.cmd);
    }
  } catch (e){
    fail(e);
  }
};

// Handshake: the host waits for this before handing over the file buffer, so a
// worker that cannot start never costs us the (already transferred) data.
self.postMessage({ type: 'ready' });
