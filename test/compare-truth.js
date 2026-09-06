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
  // Every pixel and every channel. Not a sample: the interesting error is
  // between the sample points, and a model can pass at its own knots while
  // sagging in between.
  //
  // FOUR REGIONS, NOT TWO, and the boundary that matters is 2.5.
  //
  // The first version of this file split the frame at R<=1 (object) and R>2
  // (clean), which quietly threw away the shell between them and called what
  // was left "outside the object". That was wrong, and the object's own profile
  // says why: it is PEAK*exp(-3R), so at R=1.2 it still sits at about 1.6x the
  // noise sigma. There is real signal well past R=1, the model error follows it
  // out, and a mask at R=1 reports the error of a region that is not clean.
  //
  //   dentro       R < 1      the model is supposed to be wrong here
  //   halo proximo 1 <= R < 1.5   still bright enough to pull the fit
  //   halo distante 1.5 <= R < 2.5  the object fading into the background
  //   campo limpo  R >= 2.5    the only region where "model accuracy" is the
  //                            whole story
  var BX = 10, BY = 8;                        // block map, for "where is it worst"
  var blockMax = [];
  for (var b = 0; b < BX * BY; b++) blockMax.push(0);

  function mkRegion() {
    var r = { pixels: 0, ch: [] };
    for (var i = 0; i < planes; i++) r.ch.push({ max: 0, sum: 0 });
    return r;
  }
  var regions = {
    dentroObjeto: mkRegion(),
    haloProximo:  mkRegion(),
    haloDistante: mkRegion(),
    campoLimpo:   mkRegion(),
    frame:        mkRegion(),
    // Kept because the local-rejection pendency in section 2.2 tracks it: the
    // region where the background alone passes the global rejection threshold.
    cantoRejeitado: mkRegion()
  };

  var thr = [];
  for (var c = 0; c < planes; c++) {
    thr.push(stats.perChannel[c].median + 1.0 * stats.perChannel[c].madn);
  }

  var worst = { e: 0, x: 0, y: 0, c: 0 };
  // Where the CLEAN-FIELD worst pixel sits, separately: if it lands on a frame
  // corner it is extrapolation past the sample hull, which is a different
  // failure from the model sagging between points.
  var cleanWorst = { e: 0, x: 0, y: 0, R: 0 };
  var errBuf = new Float64Array(planes);

  for (var y = 0; y < h; y++) {
    var by = Math.min(BY - 1, (y * BY / h) | 0);
    for (var x = 0; x < w; x++) {
      var bx = Math.min(BX - 1, (x * BX / w) | 0);
      var bi = by * BX + bx;
      var R = objectRadius(x, y);
      var inCorner = false;
      for (c = 0; c < planes; c++) {
        // Expected = THE GRADIENT ALONE, everywhere, including under the
        // object. That is the definition of the thing being modelled: the
        // object is signal to be preserved, not background to be removed, and
        // a background model that follows it is one that will subtract it.
        var expected = truthAt(c, x, y);
        var e = Math.abs(P.bgSampleGrid(surface, c, x, y) - expected) * 255;
        errBuf[c] = e;
        if (e > blockMax[bi]) blockMax[bi] = e;
        if (e > worst.e) { worst = { e: e, x: x, y: y, c: c }; }
        if (expected > thr[c]) inCorner = true;
      }
      var target = (R < 1)   ? regions.dentroObjeto
                 : (R < 1.5) ? regions.haloProximo
                 : (R < 2.5) ? regions.haloDistante
                             : regions.campoLimpo;
      if (R >= 2.5 && errBuf[0] > cleanWorst.e) {
        cleanWorst = { e: errBuf[0], x: x, y: y, R: +R.toFixed(2) };
      }
      target.pixels++; regions.frame.pixels++;
      if (inCorner) regions.cantoRejeitado.pixels++;
      for (c = 0; c < planes; c++) {
        var ee = errBuf[c];
        if (ee > target.ch[c].max) target.ch[c].max = ee;
        target.ch[c].sum += ee;
        if (ee > regions.frame.ch[c].max) regions.frame.ch[c].max = ee;
        regions.frame.ch[c].sum += ee;
        if (inCorner) {
          if (ee > regions.cantoRejeitado.ch[c].max) regions.cantoRejeitado.ch[c].max = ee;
          regions.cantoRejeitado.ch[c].sum += ee;
        }
      }
    }
  }

  function fin(r) {
    var out = { pixels: r.pixels, pctFrame: +(100 * r.pixels / (w * h)).toFixed(6) };
    for (var i = 0; i < planes; i++) {
      out[chans[i]] = { maxLevels: +r.ch[i].max.toFixed(6),
                        meanLevels: +(r.pixels ? r.ch[i].sum / r.pixels : 0).toFixed(6) };
    }
    return out;
  }

  // --- the 192-point lattice: the target that shares nothing --------------
  //
  // The reference publishes a lattice of the ANALYTIC gradient, computed from
  // the HISTORY coefficients. Evaluating this surface there and differencing is
  // the one comparison in the suite that depends on neither implementation's
  // sampling grid, neither one's linear algebra, and neither one's formula: the
  // right answer is arithmetic on numbers the fixture generator wrote.
  var lattice = null;
  try {
    var refJson = await fetch('/f/referencia-modulo1.json').then(function (r) { return r.json(); });
    if (refJson && refJson.verdade && refJson.verdade.reticula) {
      var pts = refJson.verdade.reticula;
      // Binned by the same four regions as the pixel pass. A single number over
      // all 192 points is dominated by the handful that sit on the object, and
      // would read as model error when it is contamination.
      var bins = { todos: [], dentroObjeto: [], haloProximo: [], haloDistante: [], campoLimpo: [] };
      for (var bn in bins) {
        for (c = 0; c < planes; c++) bins[bn].push({ max: 0, sum: 0, n: 0, worstAt: null });
      }
      function latAdd(bin, ci, d, pt) {
        var s = bins[bin][ci];
        s.sum += d; s.n++;
        if (d > s.max) { s.max = d; s.worstAt = [pt.x, pt.y, +pt.objectRadius.toFixed(3)]; }
      }
      for (var li = 0; li < pts.length; li++) {
        var pt = pts[li];
        var Rp = pt.objectRadius;
        var bin = (Rp < 1) ? 'dentroObjeto' : (Rp < 1.5) ? 'haloProximo'
                : (Rp < 2.5) ? 'haloDistante' : 'campoLimpo';
        for (c = 0; c < planes; c++) {
          var d2 = Math.abs(P.bgSampleGrid(surface, c, pt.x, pt.y) - pt[chans[c]]) * 255;
          latAdd('todos', c, d2, pt);
          latAdd(bin, c, d2, pt);
        }
      }
      lattice = { points: pts.length, source: 'referencia-modulo1.json verdade.reticula',
                  note: 'analytic gradient from the HISTORY cards; shares neither grid nor algebra' };
      for (var bn2 in bins) {
        var o = { points: bins[bn2][0].n };
        for (c = 0; c < planes; c++) {
          o[chans[c]] = { maxLevels: +bins[bn2][c].max.toFixed(6),
                          meanLevels: +(bins[bn2][c].n ? bins[bn2][c].sum / bins[bn2][c].n : 0).toFixed(6),
                          worstAt: bins[bn2][c].worstAt };
        }
        lattice[bn2] = o;
      }
    }
  } catch (e) {
    lattice = { error: String(e && e.message || e) };
  }

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
      interpLimitLevels: rec.surface.interpLimitLevels,
      // Carried so compare-reference.ps1 can check the pedestals without
      // having to re-run the fit: they are the one number of the surface that
      // reaches the pixels directly.
      perChannel: rec.surface.perChannel.map(function (p) {
        return { modelMin: p.modelMin, modelMax: p.modelMax,
                 modelMedian: p.modelMedian, pedestal: p.pedestal };
      })
    },
    // Model minus the true gradient, by region. In the clean field this is
    // model accuracy; under the object and in its halo it is contamination.
    residualVsGradient: {
      dentroObjeto:   fin(regions.dentroObjeto),
      haloProximo:    fin(regions.haloProximo),
      haloDistante:   fin(regions.haloDistante),
      campoLimpo:     fin(regions.campoLimpo),
      frame:          fin(regions.frame),
      cantoRejeitado: fin(regions.cantoRejeitado),
      worst: { levels: +worst.e.toFixed(3), x: worst.x, y: worst.y, channel: chans[worst.c] },
      campoLimpoWorst: { levels: +cleanWorst.e.toFixed(3), x: cleanWorst.x, y: cleanWorst.y, objectRadius: cleanWorst.R, channel: 'R' }
    },
    latticeVsTruth: lattice,
    // Contamination per region, as a fraction of the object's own peak. The
    // halo numbers are the ones the old R<=1 mask was hiding.
    objectContamination: {
      objectPeakLevels: +objPeakLevels.toFixed(3),
      dentroPercentOfPeak: +(100 * regions.dentroObjeto.ch[0].max / objPeakLevels).toFixed(3),
      haloProximoPercentOfPeak: +(100 * regions.haloProximo.ch[0].max / objPeakLevels).toFixed(3),
      haloDistantePercentOfPeak: +(100 * regions.haloDistante.ch[0].max / objPeakLevels).toFixed(3),
      campoLimpoPercentOfPeak: +(100 * regions.campoLimpo.ch[0].max / objPeakLevels).toFixed(3),
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
