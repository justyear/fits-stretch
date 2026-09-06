/* ------------------------------------------------------------------ *
 * Log text — the deliverable
 * ------------------------------------------------------------------ */

// Shown on the first line of every log people paste in public. Set TOOL_URL
// once the page has a home; while it is empty the line simply names the tool,
// because a dead link in someone's post is worse than no link at all.
var TOOL_NAME = 'Stretch';
var TOOL_URL  = '';

function fx(v, n){
  if (!isFinite(v)) return 'n/a';
  return v.toFixed(n === undefined ? 4 : n);
}
function pad(s, n){ s = String(s); while (s.length < n) s += ' '; return s; }

function buildLog(ctx){
  var L = [];
  var d = ctx.decoded, cfa = ctx.cfa, st = ctx.stretch, ch = ctx.channels;

  L.push('Processed with ' + TOOL_NAME + ', a one-page FITS autostretch that runs in the browser' +
         (TOOL_URL ? ': ' + TOOL_URL : '.'));
  L.push('Nothing was uploaded. The file never left this machine.');
  L.push('');
  L.push('Processing log — ' + ctx.fileName);
  L.push(d.width + ' × ' + d.height + ' · ' +
         (d.bitpix > 0 ? d.bitpix + '-bit integer' : Math.abs(d.bitpix) + '-bit float') + ' · ' +
         (ctx.outChannels === 3 ? '3 channels' : 'monochrome') + ' · ' + ctx.date);
  L.push('');

  // --- read -------------------------------------------------------
  var rowNote;
  if (ctx.rowOrder === 'TOP-DOWN') rowNote = 'rows stored top-down';
  else if (ctx.rowOrder === 'BOTTOM-UP') rowNote = 'rows stored bottom-up and flipped back the right way up';
  else rowNote = 'no row-order keyword, so the FITS default of bottom-up was assumed and the rows flipped the right way up';

  var span = fx(d.normMin, 5) + ' to ' + fx(d.normMax, 5);
  var valueNote;
  if (d.scaleMode === 'unit'){
    valueNote = 'Pixel values were already on a 0–1 scale, and the data spans ' + span + '.';
  } else if (d.scaleMode === 'int'){
    valueNote = 'Pixel values rescaled onto 0–1 from the ' + d.scaleLo + ' to ' + d.scaleHi +
                ' range they were stored in, where the data spans ' + span + '.';
  } else if (d.scaleMode === 'float16'){
    valueNote = 'Pixel values divided down onto 0–1 from the 16-bit scale they were written on, ' +
                'where the data spans ' + span + '.';
  } else {
    valueNote = 'Pixel values divided onto 0–1 by the largest value in the frame, ' +
                d.scaleDiv.toExponential(3) + ', where the data spans ' + span + '.';
  }

  L.push('• Read the FITS: ' + d.kind + ', ' +
         (d.planes === 1 ? 'one image plane' : d.planes + ' image planes') + ', ' + rowNote + '. ' + valueNote +
         (d.nonFinite ? ' ' + d.nonFinite.toLocaleString('en-US') +
            ' non-finite pixels were left out of every measurement.' : ''));

  if (d.compression){
    var cz = d.compression;
    L.push('• The file arrived Rice-compressed (.fz): unpacked ' + cz.tiles.toLocaleString('en-US') +
           ' tiles of ' + cz.tileDims.join(' × ') + ', block size ' + cz.blocksize + ', ' +
           cz.bytepix + ' bytes per stored value' +
           (cz.quantise && cz.quantise !== 'none'
              ? ', then reversed the ' + cz.quantise + ' quantisation (dither seed ' + cz.ditherSeed +
                ') back to floating point. That quantisation was applied when the .fz was packed, not here.'
              : '.'));
  }

  // --- CFA --------------------------------------------------------
  if (d.planes >= 3){
    L.push('• No colour filter array: the file carries ' + d.planes +
           ' separate colour planes (NAXIS3 = ' + d.planes + ') and is already demosaiced. No debayer applied.');
  } else if (!cfa || !cfa.isMosaic){
    var why;
    if (cfa && !cfa.evenDims) why = 'odd frame dimensions rule out a 2×2 mosaic';
    else if (cfa && cfa.stackedHistory) why = 'the header records stacking or registration, which leaves no mosaic to recover, and no BAYERPAT is present';
    else why = 'the 2×2 lattice test found no mosaic (neighbour ratio ' +
               fx(cfa ? cfa.ratioH : 0, 2) + ' H / ' + fx(cfa ? cfa.ratioV : 0, 2) +
               ' V, where a mosaic reads above 1.15)';
    L.push('• No colour filter array detected: ' + why + '. Treated as monochrome, no debayer applied.');
  } else {
    var head;
    if (ctx.pattern.source === 'header'){
      head = 'Colour filter array: BAYERPAT = ' + ctx.headerPattern + ' read from the header';
      head += ctx.pattern.corrected
        ? ', mirrored to ' + ctx.pattern.pattern + ' so the green sites line up with the ' +
          cfa.greenAxis + ' diagonal the pixels actually show'
        : ', and its green sites already match the ' + cfa.greenAxis +
          ' diagonal the pixels show';
    } else {
      head = 'Colour filter array found by the 2×2 lattice test, but the file carries no BAYERPAT keyword. Pattern inferred as ' +
             ctx.pattern.pattern + ' (Seestar S30/S50 layout) from the measured green positions — inferred, not read from the header';
    }
    L.push('• ' + head + '. Measured lattice contrast ' + fx(cfa.contrast * 100, 1) +
           '%, neighbour ratio ' + fx(cfa.ratioH, 2) + ' H / ' + fx(cfa.ratioV, 2) + ' V.');
    L.push('• Debayered with bilinear interpolation to full-resolution RGB.');
  }

  // --- linearity --------------------------------------------------
  if (st.nonLinear){
    var reasons = [];
    if (st.historyHits.length) reasons.push('the header records ' + st.historyHits.join(' and '));
    reasons.push('the measured median sits at ' + fx(st.globalMedian, 4));
    L.push('• Data is already non-linear: ' + reasons.join(', ') +
           '. Stretch reduced accordingly — black point taken at the ' + fx(st.blackPercentile * 100, 3) +
           '% percentile instead of a sigma clip, and each channel’s median held where it already sits, so existing tonal placement is preserved.');
  } else {
    L.push('• Data is linear: median ' + fx(st.globalMedian, 5) +
           ', no stretch recorded in the header. Full autostretch applied.');
  }

  // --- background -------------------------------------------------
  //
  // Flipping a step to applied has two effects and only one of them is
  // automatic. The "Not applied" sentence retracts its denial on its own, which
  // is what steps/registry.js was built for. Nothing, however, makes the log
  // SAY what happened — and a log that stopped denying an operation without
  // describing it is the same silent operation, entered from the other side.
  // The numbers below all come from the record; none is recomputed here.
  var bg = null;
  for (var bi = 0; bi < ctx.records.length; bi++){
    if (ctx.records[bi].id === 'background' && ctx.records[bi].applied) bg = ctx.records[bi];
  }
  if (bg){
    var s = bg.samples, sf = bg.surface, rj = s.rejected;
    var why = [];
    if (rj.bright) why.push(rj.bright + ' brighter than the background');
    if (rj.edge) why.push(rj.edge + ' on the frame edge');
    if (rj.clipped) why.push(rj.clipped + ' saturated');
    if (rj.nan) why.push(rj.nan + ' with unusable pixels');

    L.push('• Background extraction: measured the sky in ' + s.generated + ' boxes of ' +
           s.boxSizeEffective + ' pixels on a ' + s.grid.cols + ' × ' + s.grid.rows +
           ' grid and used ' + s.accepted + ' of them' +
           (why.length ? ' (' + why.join(', ') + ' were left out)' : '') +
           '. A thin-plate spline through those points is the model that was removed.');
    L.push('    Each channel got its own model median back as a pedestal (' +
           (ctx.outChannels === 3 ? 'R ' + fx(sf.perChannel[0].pedestal, 5) +
                                    ', G ' + fx(sf.perChannel[1].pedestal, 5) +
                                    ', B ' + fx(sf.perChannel[2].pedestal, 5)
                                  : fx(sf.perChannel[0].pedestal, 5)) +
           '), so the background level is preserved and only its variation was removed.');
    L.push('    The ratio between channels is therefore unchanged: no colour grading, ' +
           'no white balance, nothing was decided about the colour of the sky.');
  }

  // --- stretch ----------------------------------------------------
  L.push('• Autostretch — midtones transfer function (PixInsight STF / Siril autostretch), ' +
         (st.nonLinear
            ? 'target background held at each channel’s own median'
            : 'shadow clip ' + fx(st.shadowSigma, 2) + 'σ, target background ' + fx(st.target, 2)) +
         ', applied per channel (unlinked). Highlights untouched at 1.000.');

  var names = ctx.outChannels === 3 ? ['R', 'G', 'B'] : ['L'];
  for (var i = 0; i < ch.length; i++){
    var c = ch[i];
    L.push('    ' + names[i] +
           '  median ' + pad(fx(c.median, 5), 9) +
           'MADN ' + pad(fx(c.madn, 5), 9) +
           '→  shadows ' + pad(fx(c.shadows, 5), 9) +
           'midtones ' + fx(c.midtones, 5));
  }

  var clipped = 0, total = 0;
  for (i = 0; i < ch.length; i++){
    clipped += ch[i].outLow + ch[i].outHigh;
    total += ch[i].totalPixels;
  }
  if (total > 0){
    L.push('    ' + fx(100 * clipped / total, 3) + '% of pixels land on pure black or pure white after the transfer.');
  }

  // --- output -----------------------------------------------------
  var qz = null;
  for (var qi = 0; qi < ctx.records.length; qi++){
    if (ctx.records[qi].id === 'quantise') qz = ctx.records[qi];
  }
  L.push('• Output: 8-bit sRGB' + (ctx.exportScaled
      ? ', downscaled to ' + ctx.exportW + ' × ' + ctx.exportH + ' (this browser cannot allocate a canvas at full size)'
      : ', full resolution, no resampling') + '.' +
      (qz && qz.params.dither
        ? ' Rounded with ±' + qz.params.ditherAmplitudeLevels +
          ' of a level of dither, from the fixed seed ' + qz.params.ditherSeed +
          ', which breaks the banding a subtracted surface would otherwise leave. ' +
          'The seed is fixed, so the same file always produces the same image.'
        : ''));
  // Generated, not written: the complement between the catalogue in
  // steps/registry.js and the steps that reported themselves applied. A step
  // added to the chain drops out of this sentence on its own, which is the
  // whole point — the line is a claim, and a claim that has to be maintained
  // by hand is a claim that eventually stops being true.
  var denied = notAppliedLabels(ctx.records);
  if (denied.length > 1){
    L.push('• Not applied: ' + denied.slice(0, -1).join(', ') +
           ', or ' + denied[denied.length - 1] + '.');
  } else if (denied.length === 1){
    L.push('• Not applied: ' + denied[0] + '.');
  }
  L.push('');
  L.push('Every number above was measured from the file itself.');

  return L.join('\n');
}

