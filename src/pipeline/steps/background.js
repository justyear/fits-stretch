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

  var spanX = w - 2 * margin, spanY = h - 2 * margin;
  var dx = spanX / cols, dy = spanY / rows;

  var counts = { bright: 0, edge: 0, clipped: 0, nan: 0 };
  var points = [];
  var accepted = 0;

  // A frame too small to hold one box inside its own margin cannot be sampled
  // at all. Saying so is cheaper than producing zero points and letting the
  // minimum-sample guard explain it as if it were a rejection problem.
  if (spanX < boxEff || spanY < boxEff){
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
      var cx = Math.round(margin + (i + 0.5) * dx);
      var cy = Math.round(margin + (j + 0.5) * dy);

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

  // --- what the record says, and why it says applied: false ---------
  //
  // Two different falsehoods would be available here and neither is taken. The
  // step does not claim to have run, because no pixel moved. And it does not
  // stay silent, because it did do something and the points are the something.
  var skipReason;
  if (accepted < BG_MIN_SAMPLES){
    skipReason = 'only ' + accepted + ' of ' + generated + ' samples survived rejection, ' +
                 'and a surface is never fitted to fewer than ' + BG_MIN_SAMPLES + ' points';
  } else {
    skipReason = 'sampling only: this build places and judges the samples, fits no surface ' +
                 'and changes no pixel';
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

  report({
    id: 'background',
    name: 'Background extraction',
    applied: false,
    skipReason: skipReason,
    // Only the knobs this build actually reads. `smoothing`, `correction` and
    // `pedestal` belong to the surface and the correction; listing them now
    // would be the record claiming a behaviour that does not exist yet.
    params: {
      samplesPerRow: cols,
      boxSize: params.boxSize,
      tolerance: params.tolerance,
      edgeMargin: params.edgeMargin
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
    surface: null,
    before: before,
    // Nothing was measured after, because nothing happened after. A copy of
    // `before` under a name that says "after" would be a measurement that was
    // never taken.
    after: null,
    notes: notes
  });

  return img;
}
