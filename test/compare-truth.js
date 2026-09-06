/* Compares the fitted background model against the gradient that was put into
 * the fixture, read back out of its own HISTORY cards.
 *
 * This is the only check in the suite that does not inherit the shared formula.
 * compare-golden asks "is today the same as yesterday". compare-reference asks
 * "do the two implementations agree", and they agree about a formula that was
 * read out of this codebase, so a wrong formula is invisible to both. This asks
 * "is the fitted model the gradient I put in", and the answer comes from
 * numbers the generator wrote and neither implementation ever saw.
 *
 * Procedure, same as capture-golden.js:
 *   1.  powershell -File .claude\serve.ps1 -Port 8791
 *   2.  open http://127.0.0.1:8791/
 *   3.  paste this whole file into the console
 *   4.  await __compareTruth()
 *
 * The report is POSTed to .claude/shots/gradient-truth.json and printed.
 */

// The pipeline is evaluated into a private scope, the same way the main-thread
// fallback does it. Not a second implementation: this runs the shipped source,
// and calls the same bgFitSurface the step calls.
window.__pipelineScope = function () {
  var src = document.getElementById('pipeline-src').textContent;
  var shim = { onmessage: null, postMessage: function () {} };
  var exportLine = ';self.__x = { Image: Image, measure: measure, ' +
                   'stepBackground: stepBackground, bgFitSurface: bgFitSurface, ' +
                   'bgSampleGrid: bgSampleGrid, bgEvalTPS: bgEvalTPS, ' +
                   'findImageHDU: findImageHDU, toNormalisedFloat: toNormalisedFloat };';
  new Function('self', src + exportLine)(shim);
  return shim.__x;
};

// Reads the truth back out of the header, exactly as make-fixture.ps1 wrote it.
// Parsed rather than hardcoded here: a copy of the coefficients in this file
// would be a second place for them to live, and the day the two disagreed the
// test would be checking the wrong number with total confidence.
window.__parseTruth = function (cards) {
  var truth = { coef: {}, obj: {}, probes: [], noiseSigma: null };
  var chans = ['R', 'G', 'B'];

  for (var ci = 0; ci < chans.length; ci++) {
    var ch = chans[ci];
    var a = [0, 0, 0, 0, 0, 0], found = 0;
    for (var i = 0; i < cards.length; i++) {
      var line = cards[i];
      if (line.indexOf('GRADIENT ' + ch + ' A') < 0) continue;
      var re = /A(\d)=(-?[0-9.]+)/g, m;
      while ((m = re.exec(line)) !== null) { a[+m[1]] = parseFloat(m[2]); found++; }
    }
    if (found !== 6) throw new Error('expected 6 coefficients for ' + ch + ', found ' + found);
    truth.coef[ch] = a;
  }

  for (i = 0; i < cards.length; i++) {
    if (cards[i].indexOf('OBJECT CX=') >= 0) {
      var re2 = /([A-Z]+)=(-?[0-9.]+)/g, m2;
      while ((m2 = re2.exec(cards[i])) !== null) truth.obj[m2[1]] = parseFloat(m2[2]);
    }
    if (cards[i].indexOf('PROBE x,y:') >= 0) {
      var re3 = /(\d+),(\d+)/g, m3;
      while ((m3 = re3.exec(cards[i])) !== null) truth.probes.push([+m3[1], +m3[2]]);
    }
    if (cards[i].indexOf('NOISE gaussian sigma=') >= 0) {
      var m4 = /sigma=([0-9.]+)/.exec(cards[i]);
      if (m4) truth.noiseSigma = parseFloat(m4[1]);
    }
  }
  if (!truth.obj.CX) throw new Error('no OBJECT card');
  if (truth.probes.length === 0) throw new Error('no PROBE cards');
  return truth;
};

window.__compareTruth = async function (opts) {
  opts = opts || {};
  var P = window.__pipelineScope();

  var buf = await fetch('/f/test/fixtures/fixture-gradient.fit').then(function (r) { return r.arrayBuffer(); });
  var hdu = P.findImageHDU(buf);
  var dec = P.toNormalisedFloat(buf, hdu, function () {});
  var w = dec.w, h = dec.h, planes = dec.planes;
  var img = new P.Image(dec.data, w, h, planes);
  var N = w * h;

  var truth = window.__parseTruth(hdu.history);
  var norm = Math.max(w - 1, h - 1);

  // The scene, as the generator built it: gradient plus object, no noise and no
  // stars. That is what a background model is supposed to recover — the smooth
  // part. Stars and noise are what the box median is supposed to throw away.
  var chans = ['R', 'G', 'B'];
  var objTint = [1.05, 1.00, 0.95];
  function truthAt(c, x, y) {
    var k = truth.coef[chans[c]];
    var u = x / (w - 1), v = y / (h - 1);
    return k[0] + k[1] * u + k[2] * v + k[3] * u * u + k[4] * v * v + k[5] * u * v;
  }
  function objectAt(x, y) {
    var dx = (x - truth.obj.CX) / truth.obj.A, dy = (y - truth.obj.CY) / truth.obj.B;
    return truth.obj.PEAK * Math.exp(-truth.obj.K * Math.sqrt(dx * dx + dy * dy));
  }
  function objectRadius(x, y) {
    var dx = (x - truth.obj.CX) / truth.obj.A, dy = (y - truth.obj.CY) / truth.obj.B;
    return Math.sqrt(dx * dx + dy * dy);
  }

  // Sampling and rejection through the shipped step, then the shipped fit.
  var stats = P.measure(img, 1);
  var rec = null;
  P.stepBackground(img, {
    samplesPerRow: opts.samplesPerRow || 12,
    boxSize: opts.boxSize || 25,
    tolerance: (opts.tolerance === undefined) ? 1.0 : opts.tolerance,
    edgeMargin: 0.02,
    smoothing: (opts.smoothing === undefined) ? 0.10 : opts.smoothing,
    scale: 1, stride: 1, before: stats
  }, function (r) { rec = r; });

  var surface = P.bgFitSurface(rec.samples.points, w, h, planes,
                               (opts.smoothing === undefined) ? 0.10 : opts.smoothing, 8);
  if (!surface) throw new Error('no surface: ' + rec.skipReason);

  // --- residual over the whole frame, by region -----------------------
  //
  // Every pixel, not a sample: the interesting error is between the sample
  // points, and a model can pass at its own knots while sagging in between.
  var BX = 10, BY = 8;                        // block map, for "where is it worst"
  var blockMax = [], blockSum = [], blockN = [];
  for (var b = 0; b < BX * BY; b++) { blockMax.push(0); blockSum.push(0); blockN.push(0); }

  var regions = {
    frame:        { max: 0, sum: 0, n: 0 },
    outsideObject:{ max: 0, sum: 0, n: 0 },   // elliptical radius > 2
    insideObject: { max: 0, sum: 0, n: 0 },   // elliptical radius <= 1
    rejectedCorner:{ max: 0, sum: 0, n: 0 }   // background above the global threshold
  };
  function add(reg, e) { if (e > reg.max) reg.max = e; reg.sum += e; reg.n++; }

  var thr = [];
  for (var c = 0; c < planes; c++) {
    thr.push(stats.perChannel[c].median + 1.0 * stats.perChannel[c].madn);
  }

  var worst = { e: 0, x: 0, y: 0, c: 0 };
  // Every 2nd pixel in each direction: a quarter of the work, and the surface
  // varies by far less than one level over two pixels.
  for (var y = 0; y < h; y += 2) {
    var by = Math.min(BY - 1, (y * BY / h) | 0);
    for (var x = 0; x < w; x += 2) {
      var bx = Math.min(BX - 1, (x * BX / w) | 0);
      var bi = by * BX + bx;
      var R = objectRadius(x, y);
      for (c = 0; c < planes; c++) {
        // Expected = THE GRADIENT ALONE, everywhere, including under the
        // object. That is the definition of the thing being modelled: the
        // object is signal to be preserved, not background to be removed, and
        // a background model that follows it is a background model that will
        // subtract it. So the residual means two different things in two
        // places, and both are worth having:
        //
        //   outside the object -> how accurate the model is
        //   inside the object  -> how much of the object leaked into the model,
        //                         which is exactly the GraXpert failure in
        //                         section 1: 12.5% of an M31 arm eaten
        var expected = truthAt(c, x, y);
        var got = P.bgSampleGrid(surface, c, x, y);
        var e = Math.abs(got - expected) * 255;
        if (e > blockMax[bi]) blockMax[bi] = e;
        blockSum[bi] += e; blockN[bi]++;
        add(regions.frame, e);
        if (R > 2) add(regions.outsideObject, e);
        if (R <= 1) add(regions.insideObject, e);
        if (truthAt(c, x, y) > thr[c]) add(regions.rejectedCorner, e);
        if (e > worst.e) { worst = { e: e, x: x, y: y, c: c }; }
      }
    }
  }

  function fin(r) { return { maxLevels: +r.max.toFixed(4), meanLevels: +(r.n ? r.sum / r.n : 0).toFixed(4), pixels: r.n }; }

  // The object's own peak, in levels, so contamination reads as a fraction of
  // the thing at risk rather than as a bare number.
  var objPeakLevels = truth.obj.PEAK * objTint[0] * 255;

  // --- the probe that the global tolerance rejects --------------------
  var probeReport = [];
  for (var pi = 0; pi < truth.probes.length; pi++) {
    var px = truth.probes[pi][0], py = truth.probes[pi][1];
    var pt = null, bestD = 1e9;
    for (var k = 0; k < rec.samples.points.length; k++) {
      var q = rec.samples.points[k];
      var d = Math.abs(q.x - px) + Math.abs(q.y - py);
      if (d < bestD) { bestD = d; pt = q; }
    }
    probeReport.push({
      probe: [px, py], box: [pt.x, pt.y], state: pt.state,
      truthG: +truthAt(1, pt.x, pt.y).toFixed(6),
      modelG: +P.bgSampleGrid(surface, 1, pt.x, pt.y).toFixed(6),
      residualLevels: +(Math.abs(P.bgSampleGrid(surface, 1, pt.x, pt.y) - truthAt(1, pt.x, pt.y)) * 255).toFixed(3)
    });
  }

  var report = {
    fixture: 'fixture-gradient.fit',
    frame: [w, h, planes],
    smoothing: (opts.smoothing === undefined) ? 0.10 : opts.smoothing,
    tolerance: (opts.tolerance === undefined) ? 1.0 : opts.tolerance,
    samples: {
      generated: rec.samples.generated, accepted: rec.samples.accepted,
      rejected: rec.samples.rejected, boxSizeEffective: rec.samples.boxSizeEffective
    },
    surface: {
      lambda: rec.surface.lambda, kernelScale: rec.surface.kernelScale,
      gridDivisor: rec.surface.gridDivisor, gridSize: rec.surface.gridSize,
      maxInterpErrorLevels: +rec.surface.maxInterpErrorLevels.toFixed(4),
      interpLimitLevels: rec.surface.interpLimitLevels
    },
    // Model minus the true gradient. Outside the object this is accuracy;
    // inside it, it is contamination.
    residualVsGradient: {
      frame: fin(regions.frame),
      outsideObject: fin(regions.outsideObject),
      insideObject: fin(regions.insideObject),
      rejectedCorner: fin(regions.rejectedCorner),
      worst: { levels: +worst.e.toFixed(3), x: worst.x, y: worst.y, channel: chans[worst.c] }
    },
    objectContamination: {
      objectPeakLevels: +objPeakLevels.toFixed(2),
      absorbedLevels: +regions.insideObject.max.toFixed(3),
      absorbedPercentOfPeak: +(100 * regions.insideObject.max / objPeakLevels).toFixed(2),
      note: 'GraXpert measured 12.5% of an M31 arm removed; 5% for the manual fit. Section 1.'
    },
    blockMap: { cols: BX, rows: BY, maxLevels: blockMax.map(function (v) { return +v.toFixed(2); }) },
    probes: probeReport
  };

  if (!opts.noPost) {
    await fetch('/save/gradient-truth.json', { method: 'POST', body: JSON.stringify(report, null, 2) });
  }
  return report;
};
