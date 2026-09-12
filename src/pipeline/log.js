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
// Thousands separators, matching how the decode and Rice lines already print
// counts. A six-digit pixel count read as one run of digits is a number nobody
// checks, and these are the counts the calibration's whole claim rests on.
function grp(v){ return Number(v).toLocaleString('en-US'); }

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

  // --- colour calibration -----------------------------------------
  //
  // THIS BLOCK IS A PRECONDITION FOR THE STEP RUNNING AT ALL, not a decoration
  // on top of it. `colour-cal` is registered with `announce: false`, so the
  // "Not applied" sentence neither denies nor mentions it — which means that
  // without these lines a frame could come back with its colour changed and the
  // log would say nothing whatsoever about colour having been touched. That is
  // the silent operation section 7 forbids, arrived at by omission instead of
  // by intent. The step is off by default until this exists, and the order of
  // those two facts is deliberate.
  //
  // Every number below is read from the record. None is recomputed here.
  var cc = null;
  for (var ci = 0; ci < ctx.records.length; ci++){
    if (ctx.records[ci].id === 'colour-cal') cc = ctx.records[ci];
  }
  if (cc && cc.applied){
    var nt = cc.neutralise, sr = cc.stars;
    var parts = [];
    if (nt && nt.applied){
      parts.push('the sky background was levelled between channels (R ' +
                 fx(nt.offsets[0], 6) + ', G ' + fx(nt.offsets[1], 6) + ', B ' +
                 fx(nt.offsets[2], 6) + ' subtracted, additively, so only the floor moved)');
    }
    if (sr && sr.applied){
      parts.push('and the colour balance was measured from ' + grp(sr.pixels) +
                 ' star pixels in your own frame — red ×' + fx(cc.gains[0], 3) +
                 ', green ×' + fx(cc.gains[1], 3) + ', blue ×' + fx(cc.gains[2], 3));
    }
    L.push('• Colour calibration: ' + parts.join(', ') + '.');

    if (sr && sr.applied){
      L.push('    Pixels between ' + fx(sr.thresholdLow, 5) + ' and ' + fx(sr.thresholdHigh, 2) +
             ' in luminance were taken as stars' +
             (sr.rejected.saturated ? '; ' + grp(sr.rejected.saturated) +
                ' brighter than the upper cut were left out, because a saturated star ' +
                'is 1.0 in all three channels and carries no colour' : '') +
             (sr.rejected.extended ? '; ' + grp(sr.rejected.extended) +
                ' were left out as extended source, being pixels whose neighbourhood ' +
                'is also mostly lit — a galaxy body, not stars' : '') + '.');
      L.push('    The ratio was taken above the sky, not against the raw pixel: the sky ' +
             'is a level common to all three channels and leaving it in drags every ' +
             'ratio toward 1. Star medians ' +
             'R ' + fx(sr.medians[0], 5) + ', G ' + fx(sr.medians[1], 5) + ', B ' + fx(sr.medians[2], 5) +
             '; above a sky of ' + fx(sr.pedestals[1], 5) + ' that is ' +
             'R ' + fx(sr.abovePedestal[0], 5) + ', G ' + fx(sr.abovePedestal[1], 5) +
             ', B ' + fx(sr.abovePedestal[2], 5) + '.');
      // WHY IT TRUSTED, not just that it did. The gains are a ratio taken above
      // the sky, so the question that decides whether they mean anything is how
      // far they move when the sky estimate moves. That is measured on every
      // run, and printing it lets the reader judge the answer instead of taking
      // it — which is the difference this whole log exists to make.
      if (sr.gainSensitivity !== null && sr.gainSensitivity !== undefined){
        L.push('    Checked for stability before applying: a ' +
               Math.round(sr.pedestalProbe * 100) + '% error in the sky estimate would move ' +
               'the gains by at most ' + fx(100 * sr.gainSensitivity, 2) + '%' +
               (sr.gainSensitivityChannel ? ' (in ' + sr.gainSensitivityChannel + ')' : '') +
               '. A ratio taken above the sky is only worth applying if it barely ' +
               'moves when the sky estimate does.');
      }
      L.push('    Nothing here was a preference: the numbers came from the stars you ' +
             'photographed. Star colour is the reference because sky has no colour of ' +
             'its own to measure against. No catalogue was consulted, no astrometry was ' +
             'solved, and nothing left this machine.');
    }
    for (var cn = 0; cn < cc.notes.length; cn++) L.push('    ' + cc.notes[cn]);
  } else if (cc && !cc.applied){
    // A refusal is an outcome, and it gets said. Colour calibration is not in
    // the "Not applied" sentence, so if this line were missing the reader would
    // have no way to learn that the step existed, tried, and declined.
    L.push('• Colour calibration: not applied. ' + cc.skipReason + '.');
  }

  // --- stretch ----------------------------------------------------
  var i, clipped = 0, total = 0;
  var names = ctx.outChannels === 3 ? ['R', 'G', 'B'] : ['L'];

  if (st.linked){
    var lk = st.linked, cf = st.colourFidelity;
    var opName = st.operator === 'asinh'
      ? 'asinh transfer, f(x) = asinh(' + (lk.solvedStretch === null ? 'stretch' : fx(lk.solvedStretch, 1)) +
        '·x) / asinh(' + (lk.solvedStretch === null ? 'stretch' : fx(lk.solvedStretch, 1)) + ')'
      : 'midtones transfer function (PixInsight STF / Siril autostretch)';

    L.push('• Autostretch — ' + opName + ', ' +
           (st.nonLinear
              ? 'target background held at the luminance median'
              : 'shadow clip ' + fx(st.shadowSigma, 2) + 'σ, target background ' + fx(st.target, 3) +
                ' — that is ' + Math.round(st.target * 255) + ' of 255') +
           '. Applied LINKED: one curve, derived from the luminance, and every ' +
           'channel multiplied by the same number. Highlights untouched at 1.000.');

    L.push('    Luminance  median ' + pad(fx(lk.luminanceMedian, 5), 9) +
           'MADN ' + pad(fx(lk.luminanceMADN, 5), 9) +
           '→  shadows ' + pad(fx(lk.shadows, 5), 9) +
           (st.operator === 'asinh'
              ? 'stretch ' + (lk.solvedStretch === null ? 'n/a' : fx(lk.solvedStretch, 1))
              : 'midtones ' + fx(lk.midtones, 5)));
    if (lk.stretchUnreachable){
      L.push('    The asinh stretch could not reach that target — the median already sits ' +
             'above it — so the transfer was left as the identity and the black point ' +
             'alone was applied. Nothing was silently approximated.');
    }

    // WHY THIS SENTENCE IS IN THE LOG AND NOT ONLY IN THE RECORD.
    //
    // "Colour is preserved" is exactly the kind of claim a tool makes about
    // itself and nobody can check. Here it is a number, measured on this frame,
    // on this run: the largest change to any channel ratio, over the pixels
    // where a ratio means anything.
    if (cf){
      L.push('    Because one curve governs all three channels, the ratio between them ' +
             'is unchanged by construction. Measured on this frame, the largest change ' +
             'to any channel ratio was ' + cf.maxRatioDrift.toExponential(1) +
             ' across ' + grp(cf.driftSamples) + ' pixels — float rounding, nothing else. ' +
             'In the highlights, R/G ' + fx(cf.ratiosBefore.rOverG, 4) + ' → ' + fx(cf.ratiosAfter.rOverG, 4) +
             ' and B/G ' + fx(cf.ratiosBefore.bOverG, 4) + ' → ' + fx(cf.ratiosAfter.bOverG, 4) + '.');
      if (cf.pixelsRescaled){
        L.push('    ' + grp(cf.pixelsRescaled) + ' pixels came out above 1.0 in one channel. ' +
               'All three were divided by their own maximum rather than the bright channel ' +
               'being clipped on its own: clipping one channel changes the colour of the ' +
               'pixel, dividing takes it to white and keeps it.');
      }
    }
    // TWO DIFFERENT COUNTS, AND THEY HAVE TO SAY SO.
    //
    // The line above reports pixels that overflowed and were divided down; this
    // one reports pixels the transfer itself clipped, on the luminance. On a
    // frame with saturated stars the first is large and the second is zero, and
    // the old wording — "% of pixels land on pure black or pure white" — read as
    // a flat contradiction of the line before it. Both numbers are true; the
    // sentence now says which is which.
    var lkTotal = ch.length ? ch[0].totalPixels : 0;
    if (lkTotal > 0){
      L.push('    ' + fx(100 * (lk.clipLow + lk.clipHigh) / lkTotal, 3) +
             '% of pixels were clipped by the transfer itself — luminance at or below the ' +
             'black point, or at or above 1.0. That is a different count from the line ' +
             'above: this one is the curve, that one is the overflow.');
    }
    clipped = 0; total = 0;
  } else {
    L.push('• Autostretch — midtones transfer function (PixInsight STF / Siril autostretch), ' +
           (st.nonLinear
              ? 'target background held at each channel’s own median'
              : 'shadow clip ' + fx(st.shadowSigma, 2) + 'σ, target background ' + fx(st.target, 2)) +
           ', applied per channel (unlinked). Highlights untouched at 1.000.');

    for (i = 0; i < ch.length; i++){
      var c = ch[i];
      L.push('    ' + names[i] +
             '  median ' + pad(fx(c.median, 5), 9) +
             'MADN ' + pad(fx(c.madn, 5), 9) +
             '→  shadows ' + pad(fx(c.shadows, 5), 9) +
             'midtones ' + fx(c.midtones, 5));
    }
    for (i = 0; i < ch.length; i++){
      clipped += ch[i].outLow + ch[i].outHigh;
      total += ch[i].totalPixels;
    }
  }

  if (total > 0){
    L.push('    ' + fx(100 * clipped / total, 3) + '% of pixels land on pure black or pure white after the transfer.');
  }

  /* --- selective saturation ---------------------------------------
   *
   * THE LAST SENTENCE OF THIS BLOCK IS NOT DECORATION AND DOES NOT GET SOFTENED.
   *
   * `saturation` left the "Not applied" line when this step arrived, and it is
   * the first entry to leave it because a step actually does the thing — every
   * earlier departure was a mis-paired label being corrected. So this is the
   * first moment in the whole pipeline where the tool applies a TASTE, and the
   * reader has no other place to learn that: the denial that used to carry the
   * word is gone, and `announce: false` means nothing will put it back.
   *
   * The mask and the roll-off are measured, and the block says so — but they
   * are constraints on the preference, not evidence that it is a measurement,
   * and the wording must not let one read as the other. A tool that saturates
   * and explains the mask in detail while never saying "this part is a choice"
   * has used measurement as cover.
   */
  var sat = null;
  for (var si = 0; si < ctx.records.length; si++){
    if (ctx.records[si].id === 'saturation') sat = ctx.records[si];
  }
  if (sat && sat.applied){
    var mk = sat.mask, hf = sat.hueFidelity, cn = sat.chromaNoise;
    // THE HEADLINE REPORTS WHAT HAPPENED, NOT WHAT WAS ASKED FOR. `amount` is
    // the ceiling; `maxK` is the largest factor any pixel actually received. On
    // a frame with no signal those differ by everything — the ceiling is 1.45
    // and nothing above 1.03 is applied — and printing the ceiling there would
    // be a true sentence that leaves the reader with a false belief.
    L.push('• Selective saturation: chroma was scaled by up to ×' + fx(mk.maxK, 3) +
           ' (the ceiling in use is ×' + fx(sat.params.amount, 2) + '), strongest where the ' +
           'signal is well above the noise and rolled off in the highlights so a bright core ' +
           'does not turn into a flat disc of colour.');
    L.push('    The mask is driven by signal-to-noise, never by brightness: a pixel is ' +
           'left alone below ' + fx(sat.params.snrLow, 1) + 'σ above the sky and gets the full ' +
           'factor above ' + fx(sat.params.snrHigh, 1) + 'σ. On this frame the sky sits at ' +
           fx(mk.background, 5) + ' with a noise of ' + fx(mk.noiseSigma, 5) + ', so ' +
           grp(mk.pixelsBelowSnrLow) + ' pixels (' + fx(mk.pctBelowSnrLow, 1) +
           '%) were not touched at all. Average factor across the frame: ×' + fx(mk.meanK, 3) + '.');
    L.push('    Hue was not changed — all three channels were scaled by the same number, so ' +
           'the direction of the colour is untouched and only its strength moved. Measured ' +
           'on this frame, the largest hue change was ' + hf.maxHueDrift.toExponential(1) +
           ' of a turn across ' + grp(hf.driftSamples) + ' pixels.' +
           (cn && cn.growthPct !== null
              ? ' Background chroma noise grew ' + fx(cn.growthPct, 2) + '%.' : ''));
    if (sat.overflow && sat.overflow.pixelsRescaled){
      L.push('    ' + grp(sat.overflow.pixelsRescaled) + ' pixels came out above 1.0 in one ' +
             'channel and ' + grp(sat.overflow.pixelsLifted) + ' below 0.0. All three channels ' +
             'were moved together in both cases rather than the offending one being clipped ' +
             'on its own: clipping one channel changes the colour of the pixel, which is the ' +
             'one thing this step promises not to do.');
    }
    L.push('    This is the one step here that is a preference rather than a measurement, ' +
           'and it says so. The mask and the roll-off are measured — they are what stops a ' +
           'preference from colouring noise or flattening a core — but how much colour you ' +
           'want is a choice, and it was made for you at ×' + fx(sat.params.amount, 2) + '.');
  } else if (sat && !sat.applied){
    // A refusal is an outcome and it gets said. With `announce: false` nothing
    // else in the log would mention that the step exists, tried, and declined.
    L.push('• Selective saturation: not applied. ' + sat.skipReason + '.');
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

  /* --- o recorte sugerido -------------------------------------------
   *
   * TRES ESTADOS, e o do meio e o que define a etapa: sugerido e NAO aplicado.
   * O log descreve a sugestao e a frase "Not applied" continua negando o
   * recorte, porque nada foi recortado. As duas coisas ao mesmo tempo nao sao
   * contradicao -- e a diferenca entre oferecer e fazer, dita duas vezes.
   *
   * Quando nao sugere, o motivo vai aqui e tambem ao lado do botao. Nunca
   * silencio: a confusao 10 da lista e um controle que some sem explicacao.
   */
  var cp = null;
  for (var cpi = 0; cpi < ctx.records.length; cpi++){
    if (ctx.records[cpi].id === 'crop') cp = ctx.records[cpi];
  }
  if (cp){
    if (cp.applied && cp.rect){
      L.push('• Cropped to the object, because you asked: ' + cp.frameSize[0] + ' × ' +
             cp.frameSize[1] + ' → ' + cp.rect[2] + ' × ' + cp.rect[3] + '. The object ' +
             'goes from ' + fx(100 * cp.coverageBefore, 0) + '% of the frame to ' +
             fx(100 * cp.coverageAfter, 0) + '%.');
      L.push('    Every measurement above describes the FULL frame, because that is what ' +
             'was measured: the crop is the last thing that happened and it moved no ' +
             'pixel values, only which pixels are in the file. Nothing was resampled and ' +
             'nothing was interpolated.');
    } else if (cp.suggested && cp.rect){
      L.push('• A crop was suggested and NOT applied: ' + cp.frameSize[0] + ' × ' +
             cp.frameSize[1] + ' → ' + cp.rect[2] + ' × ' + cp.rect[3] + ' would take the ' +
             'object from ' + fx(100 * cp.coverageBefore, 0) + '% of the frame to ' +
             fx(100 * cp.coverageAfter, 0) + '%.');
      L.push('    The object was found by neighbourhood occupancy — the same measurement ' +
             'that keeps a galaxy body out of the star selection — and it is ' +
             grp(cp.extendedPixels) + ' pixels in ' + grp(cp.components) + ' connected ' +
             'regions, of which ' + cp.componentsAboveMin + ' is large enough to be the ' +
             'subject. Framing is authorship, so the rectangle is offered and nothing ' +
             'was done to your file.');
    } else {
      L.push('• No crop suggested: ' + cp.reason + '.');
    }
  }


  /* --- the half-scale copy ------------------------------------------
   *
   * AFTER the output line, and the order is the argument. The line above
   * describes the file the main button hands over: full resolution, no
   * resampling. This block describes a SECOND file that exists only if someone
   * asks for it. Putting it first would read as a correction to the line above
   * -- two true sentences that together say something false, which this project
   * has paid for once already.
   *
   * The last sentence is the one that has to survive edits. A reduced copy
   * looks better because it hid noise, and a tool that offers it without saying
   * so has quietly started doing the thing it promises not to do.
   */
  // Pelo id, com o mesmo laco que os outros blocos deste arquivo usam. log.js
  // nao chama o recordById de run.js: o bundle junta os dois, mas o log e o
  // unico artefato que sai daqui e nao deve depender da ordem de concatenacao.
  var hs = null;
  for (var hi = 0; hi < ctx.records.length; hi++){
    if (ctx.records[hi].id === 'half-scale') hs = ctx.records[hi];
  }
  if (hs && hs.applied && hs.noise){
    var hn = hs.noise;
    var ratioTxt = (hn.ratio === null) ? null : fx(hn.ratio, 2);
    L.push('• Half-scale copy, ' + (hs.offered
             ? 'offered as a second download and not applied to the file above'
             : 'built and measured, and NOT offered -- see below') + ': ' +
           hs.inputSize[0] + ' × ' + hs.inputSize[1] + ' reduced to ' +
           hs.outputSize[0] + ' × ' + hs.outputSize[1] + ' by averaging each 2 × 2 block.');
    if (ratioTxt !== null){
      // "Quatro pixels independentes" e uma afirmacao sobre o QUADRO, e so a
      // segunda metade da frase e aritmetica. Quando a razao sai fora da faixa,
      // a causa quase nunca e a media -- ela e exata por construcao -- e sim a
      // premissa. Culpar a media aqui seria apontar o lugar errado, que e a
      // classe de defeito que este projeto mais registra.
      var premiseBroken = (hn.whiteness !== null && hn.whiteness < 0.97);
      L.push('    Four ' + (premiseBroken ? '' : 'independent ') +
             'pixels become one, so the noise in the sky falls by a ' +
             'factor of ' + ratioTxt + ' — measured on this frame, across ' +
             grp(hn.samplesBefore) + ' pairs of neighbouring sky pixels, against the ' +
             fx(hn.expectedRatio, 2) + ' that exact averaging predicts for independent ' +
             'samples. ' +
             (hn.withinBand
               ? 'That is the arithmetic of sampling, not a filter: the average is exact ' +
                 'and nothing was smoothed.'
               : 'THAT IS OUTSIDE ' + fx(hn.band[0], 1) + '–' + fx(hn.band[1], 1) + '. ' +
                 (premiseBroken
                   ? 'The averaging is still exact — what does not hold on this frame is ' +
                     'the independence it assumes. The difference between neighbouring ' +
                     'sky pixels reads only ' + fx(hn.whiteness, 3) + ' of what it reads ' +
                     'between pixels ' + hn.whitenessLag + ' apart, so each pixel shares ' +
                     'part of its noise with the one beside it. A demosaiced frame is the ' +
                     'usual reason: two of every three colour samples per pixel were ' +
                     'reconstructed from neighbours, so the four going into a block were ' +
                     'never four measurements.'
                   : 'The factor should not be trusted on this frame.')));
    } else {
      L.push('    There was not enough sky on this frame to measure the noise ratio, so ' +
             'the factor of 2 that exact averaging predicts is stated here unverified — ' +
             'which is worth less than a measurement and is being said so.');
    }
    if (hs.offered){
      L.push('    No detail was removed: averaging resamples, it does not smooth, and the ' +
             'full-resolution file above has everything this one has.' +
             ((hs.droppedRow || hs.droppedColumn)
               ? ' The last ' + (hs.droppedRow && hs.droppedColumn ? 'row and column were'
                   : hs.droppedRow ? 'row was' : 'column was') +
                 ' dropped rather than interpolated, because interpolating would correlate ' +
                 'neighbouring pixels and the number above would stop meaning anything.'
               : ''));
      L.push('    This copy is offered because it is easier to share, not because it is ' +
             'better. The full-resolution one is the honest size of what your telescope ' +
             'recorded.');
    } else {
      // O LOG DIZ TUDO, INCLUSIVE QUE O BOTAO NAO APARECEU. Uma copia que foi
      // construida, medida e descartada e um evento, e omiti-lo deixaria o
      // leitor sem saber que a ferramenta chegou a considerar a reducao.
      L.push('    THE COPY WAS NOT OFFERED. It was built and measured, and the measurement ' +
             'is the reason: the button says "half-scale" and a person clicks it to get ' +
             'less noise, so offering it where the noise would fall by ' +
             (hs.noise.ratio === null ? 'an unmeasured amount' : fx(hs.noise.ratio, 2) + '×') +
             ' instead of ' + fx(hs.noise.expectedRatio, 0) + '× would be promising the ' +
             'difference. Saying so here and offering it anyway would be telling the truth ' +
             'in a place most people do not read.');
      L.push('    Nothing was lost: the full-resolution download is unaffected, and it is ' +
             'the one this tool considers honest anyway.');
    }
  }
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

