/* ------------------------------------------------------------------ *
 * Background extraction — sampling and rejection
 *
 * Module 1, step 4 of section 6. This build measures and reports; it fits no
 * surface and changes no pixel. The image comes back the way it went in.
 *
 * That is not an unfinished state left lying around, it is the deliverable of
 * this step: sampling and rejection are the part that can be wrong in ways a
 * picture does not show, so they get to be tested on their own, against a
 * fixture whose background is known, before anything is subtracted from
 * anything. The surface lands in step 5 and the correction in step 6.
 *
 * The record therefore reports `applied: false`, which keeps "background
 * extraction" in the log's "Not applied" sentence. That sentence is a claim
 * made to whoever reads the log, and it stays true until a pixel actually
 * moves. steps/registry.js flips it in step 7, and it flips because the step
 * starts reporting applied, not because a string was edited.
 * ------------------------------------------------------------------ */

// Fewer accepted samples than this and the step refuses. A surface fitted to a
// handful of points is not a background model, it is an interpolation of noise
// with the shape of the object it failed to reject — which is precisely how a
// background extraction eats a galaxy arm. Section 2.2.
var BG_MIN_SAMPLES = 8;

// "At the top of the range". The chain is not clamped, so a saturated pixel
// arrives as whatever the decode produced; what matters is that it sits at the
// ceiling of the scale the frame was normalised onto.
var BG_CLIP_LEVEL = 1 - 1e-6;
var BG_CLIP_FRACTION = 0.05;

// The surface is evaluated on a lattice of every Nth pixel and interpolated
// between, because evaluating a thin-plate spline at every pixel of an 8 Mpx
// frame with 100 centres is 800 million kernel evaluations and the lattice is
// 12 million. The divisor halves until the interpolation error measured against
// direct evaluation is under the limit — it is not assumed to be negligible,
// it is measured, every run, and recorded.
var BG_GRID_DIVISOR = 8;
var BG_INTERP_LIMIT_LEVELS = 0.5;
var BG_INTERP_PROBES = 1000;

// A prime stride over the pixel index, so the probes scatter deterministically
// instead of landing on a pattern. 104729 is odd and coprime with every power
// of two, so consecutive probes fall at different phases within a lattice cell
// — which is where the interpolation error actually lives. A stride sharing a
// factor with the divisor would sample the cell corners and report zero.
var BG_PROBE_STRIDE = 104729;

/**
 * Collects one box for one channel: median, plus the two counts that can
 * disqualify it. One pass, because the box is read once and asked three
 * questions.
 *
 * `scratch` is a Float64Array of exactly box*box, reused across every box and
 * every channel. It is filled completely each time, so sorting the whole array
 * is sorting exactly this box and nothing stale survives.
 */
function bgCollectBox(data, base, w, cx, cy, half, scratch){
  var n = 0, nonFinite = 0, clipped = 0;
  for (var y = cy - half; y <= cy + half; y++){
    var row = base + y * w;
    for (var x = cx - half; x <= cx + half; x++){
      var v = data[row + x];
      if (!isFinite(v)){ nonFinite++; v = 0; }
      else if (v >= BG_CLIP_LEVEL) clipped++;
      scratch[n++] = v;
    }
  }
  // TypedArray sort is numeric by default — no comparator, and no risk of the
  // lexicographic sort that bites Array.prototype.sort on numbers.
  scratch.sort();
  return { median: scratch[n >> 1], nonFinite: nonFinite, clipped: clipped, count: n };
}

/* ------------------------------------------------------------------ *
 * Thin-plate spline
 *
 * phi(r) = r^2 * ln(r), phi(0) = 0. Written as 0.5 * r2 * ln(r2) so the square
 * root never happens: r^2 ln r = r^2 * (1/2) ln(r^2), exactly, and the kernel
 * is called a few million times.
 * ------------------------------------------------------------------ */
function bgPhi(r2){
  if (r2 <= 0) return 0;
  return 0.5 * r2 * Math.log(r2);
}

/**
 * Gauss elimination with partial pivoting, several right-hand sides at once.
 *
 * The three channels share the same points, so they share the same matrix and
 * differ only in what is being interpolated. Eliminating once and carrying
 * three vectors through is the same arithmetic as one solve plus two extra
 * back-substitutions, instead of three full eliminations.
 *
 * The system is symmetric but indefinite — the polynomial block makes it a
 * saddle point, not a positive definite one — so Cholesky is not available and
 * pivoting is not optional.
 *
 * Returns null on a singular matrix rather than dividing by zero and returning
 * a surface made of Infinity. Duplicate sample positions are the way that
 * happens, and a caller that gets null reports no surface.
 */
function bgSolve(M, rhs, n, nrhs){
  var i, j, k, r;
  for (k = 0; k < n; k++){
    var piv = k, best = Math.abs(M[k][k]);
    for (i = k + 1; i < n; i++){
      var av = Math.abs(M[i][k]);
      if (av > best){ best = av; piv = i; }
    }
    if (!(best > 0)) return null;
    if (piv !== k){
      var tm = M[k]; M[k] = M[piv]; M[piv] = tm;
      for (r = 0; r < nrhs; r++){ var tv = rhs[r][k]; rhs[r][k] = rhs[r][piv]; rhs[r][piv] = tv; }
    }
    var d = M[k][k];
    for (i = k + 1; i < n; i++){
      var f = M[i][k] / d;
      if (f === 0) continue;
      var Mi = M[i], Mk = M[k];
      for (j = k; j < n; j++) Mi[j] -= f * Mk[j];
      for (r = 0; r < nrhs; r++) rhs[r][i] -= f * rhs[r][k];
    }
  }
  var out = [];
  for (r = 0; r < nrhs; r++){
    var x = new Float64Array(n);
    for (k = n - 1; k >= 0; k--){
      var acc = rhs[r][k];
      var Mk2 = M[k];
      for (j = k + 1; j < n; j++) acc -= Mk2[j] * x[j];
      x[k] = acc / Mk2[k];
    }
    out.push(x);
  }
  return out;
}

// The model at one normalised coordinate, evaluated directly from the centres.
function bgEvalTPS(fit, c, uu, vv){
  var n = fit.n, u = fit.u, v = fit.v, wts = fit.weights[c];
  var sum = wts[n] + wts[n + 1] * uu + wts[n + 2] * vv;
  for (var i = 0; i < n; i++){
    var du = uu - u[i], dv = vv - v[i];
    sum += wts[i] * bgPhi(du * du + dv * dv);
  }
  return sum;
}

// The model at one pixel, read off the lattice by bilinear interpolation. This
// is what the correction will actually use; bgEvalTPS is what it is checked
// against.
function bgSampleGrid(surface, c, x, y){
  var d = surface.divisor, gw = surface.gw, g = surface.grid[c];
  var fx = x / d, fy = y / d;
  var gx = fx | 0, gy = fy | 0;
  var tx = fx - gx, ty = fy - gy;
  var i00 = gy * gw + gx;
  var a = g[i00] + (g[i00 + 1] - g[i00]) * tx;
  var b = g[i00 + gw] + (g[i00 + gw + 1] - g[i00 + gw]) * tx;
  return a + (b - a) * ty;
}

/**
 * Fits a thin-plate spline to the accepted samples, one surface per channel,
 * and evaluates it onto a lattice.
 *
 * COORDINATES ARE NORMALISED, and isotropically. Section 2.3 asks for [0,1] and
 * the reason it gives is conditioning: at pixel scale the kernel argument runs
 * to millions and the matrix is ill-conditioned on a large frame. Dividing x
 * and y by their own extents would put both exactly in [0,1] but would squash
 * the frame to a square — a 4:3 image would become 33% stiffer along one axis
 * than the other, for no reason anyone chose. The kernel is radial and assumes
 * distance means the same thing in both directions, so both axes are divided by
 * the SAME number, the longer extent. The long axis lands on [0,1], the short
 * one on [0, h/w], and the conditioning point of the section is satisfied.
 *
 * THE REGULARISATION SCALE IS NOT THE DIAGONAL OF A. Section 2.3 says to scale
 * lambda by "the mean of the diagonal of A". For a thin-plate spline that mean
 * is exactly zero: A[i][i] = phi(0) = 0, by definition, for every i. Taken
 * literally the rule sets lambda to 0 and smoothing does nothing. The intent —
 * a lambda that means the same thing whatever the image scale — is kept by
 * scaling with the mean of |A[i][j]| over the off-diagonal entries, which is
 * the magnitude the kernel actually has here. The spec is wrong on the letter
 * and right on the purpose; this follows the purpose and says so.
 */
function bgFitSurface(points, w, h, nch, smoothing, startDivisor){
  var i, j, c, k;

  var acc = [];
  for (i = 0; i < points.length; i++) if (points[i].state === 'accepted') acc.push(points[i]);
  var n = acc.length;
  if (n < BG_MIN_SAMPLES) return null;

  var norm = Math.max(w - 1, h - 1);
  var u = new Float64Array(n), v = new Float64Array(n);
  for (i = 0; i < n; i++){ u[i] = acc[i].x / norm; v[i] = acc[i].y / norm; }

  var m = n + 3;
  var M = [];
  for (i = 0; i < m; i++) M.push(new Float64Array(m));

  var sumAbs = 0, cnt = 0;
  for (i = 0; i < n; i++){
    for (j = i + 1; j < n; j++){
      var du = u[i] - u[j], dv = v[i] - v[j];
      var p = bgPhi(du * du + dv * dv);
      M[i][j] = p; M[j][i] = p;
      sumAbs += Math.abs(p); cnt++;
    }
  }
  var scaleA = cnt > 0 ? sumAbs / cnt : 1;
  var lambda = smoothing * scaleA;
  for (i = 0; i < n; i++) M[i][i] = lambda;      // phi(0) is 0, so this IS the ridge

  // Degree-1 polynomial block: the affine part the spline does not have to bend
  // to produce. Without it a tilted background is paid for in bending energy
  // and the fit sags between points.
  for (i = 0; i < n; i++){
    M[i][n] = 1;     M[n][i] = 1;
    M[i][n + 1] = u[i]; M[n + 1][i] = u[i];
    M[i][n + 2] = v[i]; M[n + 2][i] = v[i];
  }

  var rhs = [];
  for (c = 0; c < nch; c++){
    var z = new Float64Array(m);
    for (i = 0; i < n; i++) z[i] = acc[i].median[c];
    rhs.push(z);
  }

  var weights = bgSolve(M, rhs, m, nch);
  if (!weights) return null;

  var fit = { n: n, u: u, v: v, weights: weights, norm: norm };

  // --- lattice, refined until the interpolation error is under the limit ---
  var N = w * h;
  var divisor = startDivisor, surface = null, maxErr = 0;

  for (;;){
    var gw = Math.ceil((w - 1) / divisor) + 1;
    var gh = Math.ceil((h - 1) / divisor) + 1;
    var grid = [];
    for (c = 0; c < nch; c++){
      var g = new Float64Array(gw * gh);
      for (var gy = 0; gy < gh; gy++){
        var vv = (gy * divisor) / norm;
        for (var gx = 0; gx < gw; gx++){
          g[gy * gw + gx] = bgEvalTPS(fit, c, (gx * divisor) / norm, vv);
        }
      }
      grid.push(g);
    }
    surface = { grid: grid, gw: gw, gh: gh, divisor: divisor };

    maxErr = 0;
    for (k = 0; k < BG_INTERP_PROBES; k++){
      var idx = (k * BG_PROBE_STRIDE) % N;
      var px = idx % w, py = (idx / w) | 0;
      for (c = 0; c < nch; c++){
        var e = Math.abs(bgEvalTPS(fit, c, px / norm, py / norm) - bgSampleGrid(surface, c, px, py));
        if (e > maxErr) maxErr = e;
      }
    }

    if (maxErr * 255 <= BG_INTERP_LIMIT_LEVELS || divisor <= 1) break;
    divisor = divisor >> 1;
  }

  // --- per-channel statistics of the model itself ---
  //
  // Taken over the lattice, not over every pixel. The lattice is a uniform
  // sample of a surface that is smooth by construction, so its median is the
  // spatial median to within the interpolation error just measured — and
  // materialising the full-resolution model here, only to measure it, would
  // cost the memory the lattice exists to avoid.
  var perChannel = [];
  for (c = 0; c < nch; c++){
    var gg = surface.grid[c];
    var lo = Infinity, hi = -Infinity;
    for (i = 0; i < gg.length; i++){
      if (gg[i] < lo) lo = gg[i];
      if (gg[i] > hi) hi = gg[i];
    }
    var sorted = Float64Array.from(gg);
    sorted.sort();
    var med = sorted[sorted.length >> 1];
    perChannel.push({
      modelMin: lo, modelMax: hi, modelMedian: med,
      // 'model-median' pedestal, section 2.4: give back the model's own median,
      // per channel, so the level survives and only the variation is removed.
      // Recorded here because it is a property of the surface; it is not
      // applied to anything until the correction lands.
      pedestal: med
    });
  }

  return {
    fit: fit,
    grid: surface.grid, gw: surface.gw, gh: surface.gh, divisor: surface.divisor,
    lambda: lambda, scaleA: scaleA,
    maxInterpErrorLevels: maxErr * 255,
    perChannel: perChannel
  };
}

/**
 * Applies the correction, in place. Returns the per-channel counts of what it
 * produced, which the record reports.
 *
 *   subtract:  out = in - model + pedestal
 *   divide:    out = in / model * pedestal
 *
 * THE PEDESTAL IS NOT OPTIONAL, and it is per channel. Subtracting the model
 * and giving nothing back drops the background to around zero, which is not a
 * dark sky, it is a clipped shadow — the faint end of the nebula goes with it.
 * Giving back the model's own median per channel preserves the level and
 * removes only the VARIATION, which is what the word gradient means.
 *
 * PER CHANNEL is the part that matters for colour. Returning the same pedestal
 * to all three channels would move R, G and B by different relative amounts and
 * change the ratio between them — the tool would have colour-graded the frame
 * without saying so. Per channel, the ratio survives, and the log gets to say
 * the colour balance was not touched. That claim is measured, not asserted:
 * see the R/G and B/G figures in test/golden/MANIFEST.md.
 *
 * NOTHING IS CLAMPED. Pixels of noise that sat below the model come out
 * negative and they are supposed to. Clamping here would fold the bottom half
 * of the noise distribution onto zero, which biases the median upward — the
 * measurement would then report a background that the file does not contain.
 * The Image contract says not clamped, and quantise is where the range is
 * finally decided.
 */
function bgApplyCorrection(data, surface, w, h, N, nch, mode){
  var divisor = surface.divisor, gw = surface.gw;
  var rowbuf = new Float64Array(gw);

  // gx and tx depend only on x, so they are computed once for the whole frame
  // instead of once per pixel per channel.
  var gxA = new Int32Array(w), txA = new Float64Array(w);
  for (var x = 0; x < w; x++){
    var fx = x / divisor, gx = fx | 0;
    gxA[x] = gx; txA[x] = fx - gx;
  }

  var stats = [];
  var divide = (mode === 'divide');
  // A divisor that reaches zero would send a pixel to infinity. The spline can
  // undershoot below the data, so this is reachable, and a guard that silently
  // did nothing would be an operation with no record. Counted and reported.
  var GUARD = 1e-6;

  for (var c = 0; c < nch; c++){
    var g = surface.grid[c], base = c * N;
    var ped = surface.perChannel[c].pedestal;
    var negatives = 0, guarded = 0;

    for (var y = 0; y < h; y++){
      var fy = y / divisor, gy = fy | 0, ty = fy - gy;
      var r0 = gy * gw, r1 = r0 + gw;
      for (var k = 0; k < gw; k++) rowbuf[k] = g[r0 + k] + (g[r1 + k] - g[r0 + k]) * ty;

      var o = base + y * w;
      for (x = 0; x < w; x++){
        var gx2 = gxA[x], tx = txA[x];
        var model = rowbuf[gx2] + (rowbuf[gx2 + 1] - rowbuf[gx2]) * tx;
        var vin = data[o + x], vout;
        if (divide){
          if (model > GUARD || model < -GUARD) vout = vin / model * ped;
          else { vout = vin; guarded++; }
        } else {
          vout = vin - model + ped;
        }
        if (vout < 0) negatives++;
        data[o + x] = vout;
      }
    }
    stats.push({ pedestal: ped, negatives: negatives, guarded: guarded,
                 negativePct: 100 * negatives / N });
  }
  return stats;
}

// Five decimals for a value on the [0,1] axis, one for a percentage. These end
// up in a tooltip a person reads while deciding whether the tool was right to
// throw a point away, so the precision is the precision that helps them.
function bgFixed(v){ return (Math.round(v * 100000) / 100000).toFixed(5); }
function bgPct(v){ return (Math.round(v * 10) / 10).toFixed(1); }

/**
 * Background sampling.
 *
 * @param {Image}    img     returned untouched; nothing here writes a pixel
 * @param {Object}   params  { samplesPerRow, boxSize, tolerance, edgeMargin,
 *                             scale, before, stride }
 * @param {Function} report  report(record)
 * @returns {Image}          the same img
 *
 * `params.scale` is the width of this buffer over the width of the frame the
 * user is actually working on — 1 for a full run, about 0.5 for the preview.
 * It is decided by the orchestrator and handed in, the same way `nonLinear` is,
 * rather than sniffed here: which buffer this is, is not a fact the step can
 * see, and a step that guessed would be right until the day it was not.
 *
 * `params.before` is a measurement of these exact pixels the caller already
 * holds. It is the global background estimate the rejection threshold is built
 * on, and it is not a knob, so it does not appear in record.params.
 */
function stepBackground(img, params, report){
  var w = img.w, h = img.h, N = img.N, nch = img.channels;
  var data = img.data;
  var chNames = (nch === 1) ? ['L'] : ['R', 'G', 'B'];
  var c, i, j;

  var before = params.before || measure(img, params.stride);

  // --- geometry -----------------------------------------------------
  //
  // boxSize is stated in pixels of the full-resolution frame and scaled to
  // whatever buffer this is. Without that, a 25 px box on the preview would
  // cover four times the sky a 25 px box on the full frame covers, the two runs
  // would sample different things, and the preview would stop being a preview.
  //
  // Forced odd so the box has a centre pixel and spans the same distance either
  // side of it. An even box is off-centre by half a pixel, in a fixed direction,
  // everywhere at once — a bias, not noise.
  var scale = (params.scale > 0) ? params.scale : 1;
  var boxEff = Math.round(params.boxSize * scale);
  if (boxEff % 2 === 0) boxEff += 1;
  if (boxEff < 3) boxEff = 3;
  var half = (boxEff - 1) / 2;

  var margin = Math.round(params.edgeMargin * Math.min(w, h));
  var cols = Math.max(2, params.samplesPerRow | 0);
  var rows = Math.max(2, Math.round(cols * h / w));

  // THE GRID COVERS THE WHOLE FRAME. The margin is a rejection criterion and
  // nothing else.
  //
  // It used to inset the grid as well — centres at `margin + (i+0.5)*(w-2m)/n`
  // — which applied the margin twice and made section 2.2's `rejected-edge`
  // unreachable by construction: no box could cross a margin the grid had
  // already been shrunk inside. All four fixtures reported zero edge
  // rejections, and that read as normal rather than as the symptom it was.
  //
  // Measured cost of the inset, on fixture-gradient: 31.4% of the clean field
  // fell outside the convex hull of the accepted samples, where a thin-plate
  // spline extrapolates — the classic RBF failure. Clean-field max error was
  // 0.169 of a level against 0.094 inside the hull.
  //
  // And the argument for the inset does not survive contact with the rule this
  // project runs on: a sample near the edge may catch vignetting or a stacking
  // artefact, and the answer to that is to REJECT it, visibly, with a reason in
  // the record and the tooltip. Not generating it is silent, and silence is
  // what confusion 21 forbids.
  var dx = w / cols, dy = h / rows;

  var counts = { bright: 0, edge: 0, clipped: 0, nan: 0 };
  var points = [];
  var accepted = 0;

  // A frame too small to hold one box inside its own margin cannot be sampled
  // at all: every box would cross the margin and every sample would be an edge
  // rejection. Saying so is cheaper than producing a full grid of rejections
  // and letting the minimum-sample guard explain it as if it were a threshold
  // problem.
  if (w - 2 * margin < boxEff || h - 2 * margin < boxEff){
    report({
      id: 'background', name: 'Background extraction',
      applied: false,
      skipReason: 'the frame is ' + w + ' x ' + h + ' and the ' + margin +
                  ' px edge margin leaves no room for a ' + boxEff + ' px sample box',
      params: { samplesPerRow: cols, boxSize: params.boxSize,
                tolerance: params.tolerance, edgeMargin: params.edgeMargin },
      samples: { generated: 0, accepted: 0, rejected: counts, forced: 0, moved: 0,
                 boxSizeEffective: boxEff, minimum: BG_MIN_SAMPLES,
                 grid: { cols: cols, rows: rows, marginPx: margin, spacingX: 0, spacingY: 0 },
                 points: [] },
      surface: null, before: before, after: null,
      notes: ['No samples were placed: the frame is too small for the box and margin in use.']
    });
    return img;
  }

  // --- the global estimate the rejection is measured against --------
  var threshold = [];
  for (c = 0; c < nch; c++){
    var st = before.perChannel[c];
    threshold.push(st.median + params.tolerance * st.madn);
  }

  var scratch = new Float64Array(boxEff * boxEff);
  var boxPixels = boxEff * boxEff;
  var clipLimit = BG_CLIP_FRACTION * boxPixels;

  for (j = 0; j < rows; j++){
    for (i = 0; i < cols; i++){
      var cx = Math.round((i + 0.5) * dx);
      var cy = Math.round((j + 0.5) * dy);

      var pt = { x: cx, y: cy, state: 'accepted', reason: null, median: [] };

      // Order of judgement, and it is deliberate: geometry, then whether the
      // pixels are readable at all, then whether they are usable, then the
      // statistical call. Each test is cheaper and more certain than the next,
      // and a point rejected for a hard reason should never be reported under a
      // soft one.
      if (cx - half < margin || cx + half >= w - margin ||
          cy - half < margin || cy + half >= h - margin){
        pt.state = 'rejected-edge';
        pt.reason = 'the ' + boxEff + ' px box crosses the ' + margin + ' px edge margin';
        counts.edge++;
        points.push(pt);
        continue;
      }

      // Every count is per channel and the worst channel is the one named. A
      // total across channels would read as a pixel count and be wrong by a
      // factor of three; "in any channel" is the rule, so the reason has to say
      // which channel tripped it.
      var worstNonFinite = 0, nanCh = -1;
      var worstClipped = 0, clipCh = -1;
      var bright = -1, brightMedian = 0;

      for (c = 0; c < nch; c++){
        var box = bgCollectBox(data, c * N, w, cx, cy, half, scratch);
        pt.median.push(box.median);
        if (box.nonFinite > worstNonFinite){ worstNonFinite = box.nonFinite; nanCh = c; }
        if (box.clipped > worstClipped){ worstClipped = box.clipped; clipCh = c; }
        // "in any channel" — the first channel that trips it names the reason.
        if (bright < 0 && box.median > threshold[c]){ bright = c; brightMedian = box.median; }
      }

      if (worstNonFinite > 0){
        pt.state = 'rejected-nan';
        pt.reason = 'the box has ' + worstNonFinite + ' non-finite pixel' +
                    (worstNonFinite === 1 ? '' : 's') + ' in ' + chNames[nanCh];
        counts.nan++;
      } else if (worstClipped > clipLimit){
        pt.state = 'rejected-clipped';
        pt.reason = bgPct(100 * worstClipped / boxPixels) +
                    '% of the box is at the top of the range in ' + chNames[clipCh] +
                    ', over the ' + (100 * BG_CLIP_FRACTION) + '% limit';
        counts.clipped++;
      } else if (bright >= 0){
        pt.state = 'rejected-bright';
        pt.reason = chNames[bright] + ' median ' + bgFixed(brightMedian) +
                    ' is above the background estimate ' + bgFixed(before.perChannel[bright].median) +
                    ' + ' + params.tolerance + ' x MADN ' + bgFixed(before.perChannel[bright].madn) +
                    ' = ' + bgFixed(threshold[bright]);
        counts.bright++;
      } else {
        accepted++;
      }

      points.push(pt);
    }
  }

  var generated = cols * rows;
  var rejected = counts.bright + counts.edge + counts.clipped + counts.nan;

  // --- the surface -------------------------------------------------
  //
  // Fitted, measured and reported. Not applied: the correction and the pedestal
  // land in step 6, and until they do no pixel moves. Fitting it now is what
  // makes it testable now — the fixture carries the true gradient in its HISTORY
  // cards, so the model can be checked against the answer instead of against
  // yesterday, before anything depends on it being right.
  var surface = bgFitSurface(points, w, h, nch, params.smoothing, BG_GRID_DIVISOR);
  var surfaceRecord = null;
  var correction = null;
  var after = null;

  if (surface){
    // The pixels move here, and from this line on the step is applied. That is
    // why `applied` is computed from whether this ran rather than set by hand:
    // the log's "Not applied" sentence is generated from it, and a sentence
    // that has to be maintained by hand is a sentence that eventually lies.
    correction = bgApplyCorrection(data, surface, w, h, N, nch, params.correction);
    after = measure(img, params.stride);

    surfaceRecord = {
      method: 'thin-plate-spline',
      // One lambda, not three: A is built from the sample POSITIONS, which the
      // channels share. Only the right-hand side differs.
      lambda: surface.lambda,
      kernelScale: surface.scaleA,
      gridDivisor: surface.divisor,
      gridSize: [surface.gw, surface.gh],
      maxInterpErrorLevels: surface.maxInterpErrorLevels,
      interpProbes: BG_INTERP_PROBES,
      interpLimitLevels: BG_INTERP_LIMIT_LEVELS,
      correction: params.correction,
      perChannel: surface.perChannel
    };
  }

  // --- what the record says, and why it says applied: false ---------
  //
  // Two different falsehoods would be available here and neither is taken. The
  // step does not claim to have run, because no pixel moved. And it does not
  // stay silent, because it did do something and the points are the something.
  var applied = !!surfaceRecord;
  var skipReason = null;
  if (accepted < BG_MIN_SAMPLES){
    skipReason = 'only ' + accepted + ' of ' + generated + ' samples survived rejection, ' +
                 'and a surface is never fitted to fewer than ' + BG_MIN_SAMPLES + ' points';
  } else if (!surfaceRecord){
    skipReason = 'the ' + accepted + ' accepted samples do not define a surface: the linear ' +
                 'system is singular, which means two samples share a position';
  }

  var notes = [
    'Placed ' + generated + ' samples on a ' + cols + ' x ' + rows + ' grid, ' +
      boxEff + ' px boxes, ' + accepted + ' accepted and ' + rejected + ' rejected.',
    'Rejected: ' + counts.bright + ' brighter than the background estimate, ' +
      counts.edge + ' on the edge margin, ' + counts.clipped + ' clipped, ' +
      counts.nan + ' non-finite.',
    'Every rejected sample is still in the record, with the reason it was rejected.'
  ];
  if (accepted < BG_MIN_SAMPLES){
    notes.push('Not enough samples survived to fit a background, so none will be fitted. ' +
               'Lower the density, raise the tolerance, or accept points by hand.');
  }
  if (boxEff !== params.boxSize){
    notes.push('Box size ' + params.boxSize + ' px scaled to ' + boxEff +
               ' px for this ' + w + ' x ' + h + ' buffer, so a sample covers the same sky ' +
               'here as it does at full resolution.');
  }
  if (surfaceRecord){
    notes.push('Thin-plate spline through the ' + accepted + ' accepted samples, smoothing ' +
               params.smoothing + ', per channel and unlinked.');
    notes.push('Evaluated on every ' + surfaceRecord.gridDivisor + 'th pixel and interpolated ' +
               'between; measured against direct evaluation at ' + BG_INTERP_PROBES +
               ' pixels, worst case ' + bgFixed(surfaceRecord.maxInterpErrorLevels) +
               ' of one 8-bit level.');
    var peds = [];
    for (c = 0; c < nch; c++) peds.push(chNames[c] + ' ' + bgFixed(surface.perChannel[c].pedestal));
    notes.push('Corrected by ' + (params.correction === 'divide' ? 'division' : 'subtraction') +
               ', returning each channel its own model median as the pedestal (' +
               peds.join(', ') + '). The background LEVEL is preserved and only the ' +
               'variation is removed, so the ratio between channels is unchanged and no ' +
               'colour grading happened.');
    var negTotal = 0;
    for (c = 0; c < nch; c++) negTotal += correction[c].negatives;
    notes.push(negTotal + ' pixels came out below zero, which is expected: noise that sat ' +
               'under the model stays under it, and nothing is clamped until the 8-bit step.');
  }

  report({
    id: 'background',
    name: 'Background extraction',
    applied: applied,
    skipReason: skipReason,
    // Only the knobs this build actually reads. `smoothing`, `correction` and
    // `pedestal` belong to the surface and the correction; listing them now
    // would be the record claiming a behaviour that does not exist yet.
    params: {
      samplesPerRow: cols,
      boxSize: params.boxSize,
      tolerance: params.tolerance,
      edgeMargin: params.edgeMargin,
      smoothing: params.smoothing,
      correction: params.correction,
      pedestal: params.pedestal
    },
    samples: {
      generated: generated,
      accepted: accepted,
      rejected: counts,
      forced: 0,
      moved: 0,
      boxSizeEffective: boxEff,
      minimum: BG_MIN_SAMPLES,
      // The grid, in eight numbers, pins every sample position exactly. The
      // points below carry the same information point by point; this is what a
      // reader checks first when the counts look wrong.
      grid: { cols: cols, rows: rows, marginPx: margin, spacingX: dx, spacingY: dy },
      points: points
    },
    surface: surfaceRecord,
    // What the correction produced, per channel. `negatives` is the count that
    // has to be non-zero on real data: a background subtraction that produces
    // no negative pixel has clamped somewhere it should not have, and the
    // symmetry of the noise is gone.
    correction: correction,
    before: before,
    // Measured when the pixels moved, null when they did not. A copy of
    // `before` under a name that says "after" would be a measurement that was
    // never taken.
    after: after,
    notes: notes
  });

  return img;
}
