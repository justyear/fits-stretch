/* ------------------------------------------------------------------ *
 * Half-scale copy — a second output, never the default
 *
 * THE MEASUREMENT THAT PUT THIS HERE. Comparing the v1.3.0 output against a
 * manual delivery of the same target, the tool's detail-to-noise ratio came out
 * BETTER (6.51 against 5.84): the processing is not losing structure and not
 * inventing noise. What the reference had was half the apparent sky noise — and
 * it had it because it was delivered reduced and cropped, 2500x1500 against
 * 2160x3840 at full resolution.
 *
 * Halving the linear size divides the apparent noise by two. That is sampling
 * arithmetic, not processing, and it is the largest remaining visual difference
 * between the two deliveries.
 *
 * SO THE REDUCED COPY IS A SECOND BUTTON AND NOT THE DEFAULT, and the reason is
 * the product rather than the code: the reduced one looks better and is what a
 * person will post, but it looks better BECAUSE IT HID NOISE. A tool whose whole
 * argument is that nothing happens to the pixels without being written down
 * cannot ship, by default, the version that quietly hides some. The full frame
 * stays the default; this one is offered, with the log saying the scale and
 * saying why it is offered.
 *
 * EXACT 2x2 BOX AVERAGE, AND NOTHING ELSE WILL DO. Four independent pixels
 * become one, so the noise falls by sqrt(4) = 2 — and the log states that number
 * out loud. Bicubic and Lanczos have negative lobes: they do not divide the
 * noise by the same factor, and the sentence would become a lie. The filter is
 * not a quality preference here; it is what makes the claim checkable.
 *
 * BEFORE `quantise`, ON THE FLOAT. Averaging 8-bit values has already thrown
 * away the precision the averaging was supposed to recover: four levels that
 * differ below the quantisation step are four identical integers, and their mean
 * carries no more information than one of them.
 *
 * AN ODD DIMENSION DROPS THE LAST ROW OR COLUMN, and the record says which.
 * Interpolating to make the count come out even would reintroduce correlation
 * between neighbouring pixels — and the noise number this step reports is only
 * meaningful while the four inputs to each output are independent. The one line
 * of arithmetic that would tidy the edge is the one that would invalidate the
 * measurement.
 * ------------------------------------------------------------------ */

// The threshold that separates "sky" from "signal", in deviations above the
// background. Same number and same meaning as the saturation mask: a pixel this
// close to the noise floor carries no object.
var HALF_SKY_SIGMA = 3.0;

// What exact 2x2 averaging predicts for independent samples. The record carries
// the MEASURED ratio against this; the point of the field is that they can
// disagree, and a disagreement means the reduction is not doing what the log
// says it does.
var HALF_EXPECTED_RATIO = 2.0;

// The real sky is not perfectly white noise — a stacked frame carries some
// correlation between neighbours from registration and interpolation upstream —
// so 2.00 exactly is not expectable. Outside this band the filter is not a box
// average, or the sky selection is picking up structure.
var HALF_RATIO_MIN = 1.8, HALF_RATIO_MAX = 2.2;

/* O PORTAO DO BOTAO E A PROPRIA RAZAO MEDIDA, E NAO UM LIMIAR DE BRANCURA.
 *
 * O botao diz "half-scale" e a pessoa clica porque quer menos ruido. Num quadro
 * onde a razao sai 1,29 ela recebe metade do beneficio que o botao sugere, e a
 * explicacao mora num log que a maioria nao le. DIZER A VERDADE NUM TEXTO QUE
 * NINGUEM LE NAO E O MESMO QUE NAO PROMETER: quando a grandeza que o botao
 * promete nao se sustenta, o botao nao aparece.
 *
 * O limiar e `HALF_RATIO_MIN`, o mesmo 1,8 da faixa, e nao ha constante nova.
 *
 * POR QUE NAO UM LIMIAR DE BRANCURA. O caminho obvio era derivar a brancura que
 * produz razao 1,8 e cortar ali. Tentado, com os nove fixtures, e a relacao NAO
 * SUPORTA:
 *
 *     ajuste            n   r       r2      W(razao = 1,8)
 *     nove fixtures     9   0,979   0,957   0,920
 *     sem o seestar     8   0,262   0,069   0,628
 *
 * O r2 de 0,957 e um ponto de alavanca: tirar um de nove move o limiar de 0,92
 * para 0,63. Os outros oito ocupam 0,045 de largura em brancura, onde o
 * espalhamento e ruido de medicao. E o 0,920 cai numa lacuna de 0,20 de largura
 * sem nenhuma observacao. Ajustar assim seria inventar a curva.
 *
 * E nao e preciso: A RAZAO E MEDIDA EM TODO QUADRO, antes de o botao aparecer.
 * Cortar pela brancura seria substituir a grandeza que o botao promete por um
 * proxy ajustado dela. A brancura fica como EXPLICACAO -- e o que diz por que a
 * razao caiu -- e nao como criterio.
 *
 * Mede o quadro, nao o formato: um FITS ja demosaicado por outro programa chega
 * aqui como tres planos e dispara igual, e deve disparar.
 */

// Above this many samples the median is taken on a stride. Deterministic, and
// the same reason `analysePlane` has a stride: a median does not get better by
// reading twenty million values instead of four.
var HALF_MAX_SAMPLES = 4000000;

/* THE HIGH-FREQUENCY ESTIMATOR, AND WHY IT IS A FIRST DIFFERENCE.
 *
 * `madn` of the sky plane itself measures the spread of the sky, which includes
 * whatever large-scale structure survived background extraction. That is not
 * what falls by two when you halve the frame — a smooth gradient survives
 * resampling untouched, and mixing it in would drag the measured ratio toward 1
 * for reasons that have nothing to do with the reduction.
 *
 * The difference between horizontally adjacent pixels kills everything smooth
 * and leaves the noise:
 *
 *     for white noise of sigma,  sigma(v[x+1] - v[x]) = sigma * sqrt(2)
 *
 * so dividing by sqrt(2) puts the estimate back in per-pixel units. After exact
 * 2x2 averaging each output pixel has noise sigma/2, and — this is the part the
 * box average buys — adjacent OUTPUT pixels are still independent, because the
 * blocks partition the grid instead of overlapping. The same estimator on the
 * reduced frame therefore returns sigma/2, and the ratio is 2 by construction
 * for white noise.
 *
 * A filter with overlapping support would correlate neighbouring outputs, the
 * difference would come out smaller than sqrt(2) times the pixel noise, and the
 * ratio would read HIGH — better than 2, which is exactly the flattering
 * artefact this step must not produce.
 */
function halfHighFreq(plane, w, h, sky, scratch, lag){
  lag = lag || 1;
  var n = 0, x, y, i;
  // Count first, then stride, then fill: the stride has to be decided before
  // anything is written or the sample set depends on where it stopped.
  for (y = 0; y < h; y++){
    i = y * w;
    for (x = 0; x + lag < w; x++){ if (sky[i + x] && sky[i + x + lag]) n++; }
  }
  if (n < 64) return null;                    // too little sky to measure

  var stride = Math.ceil(n / HALF_MAX_SAMPLES);
  var k = 0, seen = 0;
  for (y = 0; y < h; y++){
    i = y * w;
    for (x = 0; x + lag < w; x++){
      if (!(sky[i + x] && sky[i + x + lag])) continue;
      if ((seen++ % stride) !== 0) continue;
      var d = plane[i + x + lag] - plane[i + x];
      scratch[k++] = d < 0 ? -d : d;
    }
  }
  if (k < 64) return null;

  // MAD about zero — the difference of two samples of the same population is
  // zero-mean by construction, so centring it again would only add noise to the
  // estimate. 1.4826 is the same Gaussian consistency factor `analysePlane`
  // uses, so this number is comparable with every other sigma in the log.
  var mad = exactMedian(scratch, k);
  return { sigma: 1.4826 * mad / Math.SQRT2, samples: k, stride: stride };
}

/* IS THE NOISE WHITE? THE PREMISE, MEASURED INSTEAD OF ASSUMED.
 *
 * "Four independent pixels become one, so the noise falls by 2" has two halves,
 * and only the second is arithmetic. The first is a claim about the frame, and
 * on a debayered mosaic it is FALSE: the demosaic reconstructs two of every
 * three colour samples per pixel from its neighbours, so neighbouring pixels
 * share information and the four entering a 2x2 block are not four independent
 * samples.
 *
 * Measured, on `fixture-seestar`, as sigma(lag L) / sigma(lag 1):
 *
 *     L        1      2      3      4      5      6
 *     seestar  1.000  1.000  1.291  1.063  1.291  1.063   <- period 4
 *     gradient 1.000  1.000  1.000  1.000  1.000  1.000   <- white
 *
 * For white noise every lag gives the same sigma. Where a short lag reads LOWER
 * than a far one, adjacent pixels are correlated and the lag-1 estimator is
 * reading less noise than there is.
 *
 * The lags to look at come from the block, not from the data: the reduction
 * averages a 2x2 block, so independence has to hold across it and its immediate
 * neighbour — L = 2, 3, 4. Picking the lag that happens to show the effect on
 * one fixture would be fitting the diagnostic to the answer.
 *
 * 1.0 means white. Below 1 means the premise of the factor of 2 does not hold on
 * this frame, and it is the evidence the log points at instead of guessing why.
 */
var HALF_WHITENESS_LAGS = [2, 3, 4];

function halfWhiteness(plane, w, h, sky, scratch, base){
  if (!base || !(base.sigma > 0)) return null;
  var worst = 1.0, worstLag = 0;
  for (var li = 0; li < HALF_WHITENESS_LAGS.length; li++){
    var L = HALF_WHITENESS_LAGS[li];
    var far = halfHighFreq(plane, w, h, sky, scratch, L);
    if (!far || !(far.sigma > 0)) continue;
    var r = base.sigma / far.sigma;
    if (r < worst){ worst = r; worstLag = L; }
  }
  return { value: worst, lag: worstLag };
}

/**
 * Half-scale copy.
 *
 * Returns a NEW Image and does not touch `img`: the full-resolution frame is
 * the default output and the chain continues on it.
 *
 * @param {Image}    img     NOT mutated
 * @param {Object}   params  { stride, before }
 * @param {Function} report  report(record)
 * @returns {Image}  the reduced frame, or null when the frame is too small
 */
function stepHalfScale(img, params, report){
  params = params || {};
  var before = params.before || measure(img, params.stride);

  var w = img.w, h = img.h, ch = img.channels, N = img.N, src = img.data;
  var w2 = w >> 1, h2 = h >> 1;
  var droppedColumn = (w & 1) === 1, droppedRow = (h & 1) === 1;

  if (w2 < 1 || h2 < 1){
    report({
      id: 'half-scale', name: 'Half-scale copy',
      applied: false,
      skipReason: 'the frame is ' + w + ' x ' + h + '; there is nothing to halve',
      params: { filter: 'box2x2' },
      inputSize: [w, h], outputSize: null,
      droppedRow: false, droppedColumn: false,
      noise: null, before: before, after: null, notes: []
    });
    return null;
  }

  // --- the sky, chosen ONCE on the full frame -------------------------
  //
  // Both measurements have to describe the same patch of sky. Selecting it
  // again on the reduced frame would pick a slightly different population --
  // the reduced MADN is half, so `median + 3 sigma` lands somewhere else -- and
  // the ratio would then carry that difference as well as the reduction. The
  // full-frame mask is carried down to the blocks instead.
  var Y = alloc(Float32Array, N, 'the half-scale luminance');
  var i, c;
  if (ch === 3){
    var bR = 0, bG = N, bB = 2 * N;
    for (i = 0; i < N; i++){
      Y[i] = SAT_LUM_R * src[bR + i] + SAT_LUM_G * src[bG + i] + SAT_LUM_B * src[bB + i];
    }
  } else {
    for (i = 0; i < N; i++) Y[i] = src[i];
  }

  var ys = analysePlane(Y, 0, N, params.stride || 1);
  if (!ys) throw FitsError('empty', 'the luminance has no usable pixels');
  var skyCut = ys.median + HALF_SKY_SIGMA * ys.madn;

  var sky = alloc(Uint8Array, N, 'the half-scale sky mask');
  var skyCount = 0;
  for (i = 0; i < N; i++){
    var yv = Y[i];
    if (yv === yv && yv < skyCut){ sky[i] = 1; skyCount++; }
  }

  // --- the reduction --------------------------------------------------
  var N2 = w2 * h2;
  var out = alloc(Float32Array, N2 * ch, 'the half-scale frame');
  var x, y;
  for (c = 0; c < ch; c++){
    var sBase = c * N, dBase = c * N2;
    for (y = 0; y < h2; y++){
      var r0 = sBase + (2 * y) * w, r1 = r0 + w, o = dBase + y * w2;
      for (x = 0; x < w2; x++){
        var j = 2 * x;
        // Four terms, one divide. Written out rather than looped because this
        // is the arithmetic the log's factor of 2 rests on, and it should be
        // readable as exactly that and nothing else.
        out[o + x] = (src[r0 + j] + src[r0 + j + 1] + src[r1 + j] + src[r1 + j + 1]) * 0.25;
      }
    }
  }
  var half = new Image(out, w2, h2, ch);

  // --- the same sky, in the reduced frame ------------------------------
  //
  // A reduced pixel counts as sky only if ALL FOUR of its sources did. A block
  // straddling the edge of an object is neither sky nor object, and letting it
  // in would put object structure into a noise measurement.
  var Y2 = alloc(Float32Array, N2, 'the half-scale luminance, reduced');
  var sky2 = alloc(Uint8Array, N2, 'the half-scale sky mask, reduced');
  var sky2Count = 0;
  for (y = 0; y < h2; y++){
    var sr0 = (2 * y) * w, sr1 = sr0 + w, oo = y * w2;
    for (x = 0; x < w2; x++){
      var jj = 2 * x;
      if (sky[sr0 + jj] && sky[sr0 + jj + 1] && sky[sr1 + jj] && sky[sr1 + jj + 1]){
        sky2[oo + x] = 1; sky2Count++;
      }
      if (ch === 3){
        Y2[oo + x] = SAT_LUM_R * out[oo + x] + SAT_LUM_G * out[N2 + oo + x] + SAT_LUM_B * out[2 * N2 + oo + x];
      } else {
        Y2[oo + x] = out[oo + x];
      }
    }
  }

  var scratch = alloc(Float32Array, Math.min(N, HALF_MAX_SAMPLES + 8), 'the half-scale noise samples');
  var hfBefore = halfHighFreq(Y, w, h, sky, scratch);
  var hfAfter  = halfHighFreq(Y2, w2, h2, sky2, scratch);
  // A premissa do fator 2, medida no quadro CHEIO -- que e onde ela tem que
  // valer. Se o ruido ja nao e branco na entrada, os quatro pixels do bloco nao
  // sao quatro amostras independentes, e o problema nao e a media.
  var wht = halfWhiteness(Y, w, h, sky, scratch, hfBefore);

  var ratio = null;
  if (hfBefore && hfAfter && hfAfter.sigma > 0) ratio = hfBefore.sigma / hfAfter.sigma;

  var noise = {
    skyHighFreqBefore: hfBefore ? hfBefore.sigma : null,
    skyHighFreqAfter:  hfAfter  ? hfAfter.sigma  : null,
    ratio: ratio,
    expectedRatio: HALF_EXPECTED_RATIO,
    // The band, carried in the record so the reader does not have to know it,
    // and so a comparison against the reference can assert it rather than
    // reinvent it.
    withinBand: (ratio !== null && ratio >= HALF_RATIO_MIN && ratio <= HALF_RATIO_MAX),
    band: [HALF_RATIO_MIN, HALF_RATIO_MAX],
    skyPixels: skyCount, skyPixelsReduced: sky2Count,
    samplesBefore: hfBefore ? hfBefore.samples : 0,
    samplesAfter:  hfAfter  ? hfAfter.samples  : 0,
    // 1,0 = ruido branco na entrada. Abaixo disso a premissa do fator 2 nao
    // vale neste quadro, e este campo e a evidencia -- nao a explicacao.
    whiteness: wht ? wht.value : null,
    whitenessLag: wht ? wht.lag : null,
    note: 'first difference of horizontally adjacent sky pixels, divided by ' +
          'sqrt(2) to read as a per-pixel sigma; measured on the same sky on ' +
          'both frames, chosen once on the full one'
  };


  /* O BOTAO, DECIDIDO AQUI E NAO NA INTERFACE.
   *
   * `offered` e o que o host le para mostrar ou esconder o botao, e a frase de
   * `offerReason` e o que ele mostra no lugar dele. A decisao mora nesta etapa
   * porque e aqui que a grandeza foi medida -- deixar o host decidir com base
   * num campo numerico seria espalhar o criterio por dois arquivos, e um deles
   * nao tem como saber o que o botao promete.
   *
   * O log continua dizendo TUDO, inclusive quando o botao nao aparece. O log
   * explica; o botao nao promete.
   */
  var offered = (ratio !== null && ratio >= HALF_RATIO_MIN);
  var offerReason = null;
  if (!offered){
    if (ratio === null){
      offerReason = 'half-scale not offered: there was not enough sky on this frame to ' +
                    'measure whether averaging would reduce the noise, and the button ' +
                    'would be promising a number nobody checked';
    } else if (wht && wht.value < 1 && ratio < HALF_RATIO_MIN){
      offerReason = 'half-scale not offered: the sky noise on this frame is correlated ' +
                    'between neighbouring pixels (usually a demosaiced frame), so ' +
                    'averaging would only reduce it by ' + ratio.toFixed(2) + '× instead of ' +
                    HALF_EXPECTED_RATIO.toFixed(0) + '×';
    } else {
      offerReason = 'half-scale not offered: averaging would only reduce the sky noise by ' +
                    ratio.toFixed(2) + '× on this frame instead of ' +
                    HALF_EXPECTED_RATIO.toFixed(0) + '×, and the button would be promising ' +
                    'the difference';
    }
  }
  var notes = [];
  if (droppedRow || droppedColumn){
    notes.push('Odd dimension: the last ' +
               (droppedRow && droppedColumn ? 'row and column were' :
                droppedRow ? 'row was' : 'column was') +
               ' dropped rather than interpolated. Interpolating would correlate ' +
               'neighbouring pixels and the noise figure above would stop meaning ' +
               'anything.');
  }
  if (ratio !== null && !noise.withinBand){
    // NOT a refusal. This step cannot corrupt the default output -- it works on
    // a copy -- so the honest failure mode is to say the number came out wrong,
    // loudly, and let the reader decide. Refusing would hide the evidence.
    notes.push('The measured noise ratio is outside ' + HALF_RATIO_MIN + '-' +
               HALF_RATIO_MAX + '. The average itself is exact by construction; what ' +
               'this says is that the four pixels entering each block were not four ' +
               'independent samples on this frame. The whiteness field measures that ' +
               'premise instead of assuming it.');
  }

  report({
    id: 'half-scale',
    name: 'Half-scale copy',
    applied: true,
    skipReason: null,
    params: { filter: 'box2x2' },
    inputSize: [w, h],
    outputSize: [w2, h2],
    droppedRow: droppedRow,
    droppedColumn: droppedColumn,
    noise: noise,
    offered: offered,
    offerReason: offerReason,
    before: before,
    after: measure(half, params.stride),
    notes: notes
  });

  // O quadro reduzido so volta quando o botao vai aparecer. Quando nao vai, ele
  // foi construido e MEDIDO mesmo assim -- e a medicao que decide -- e e
  // descartado aqui em vez de virar um arquivo que ninguem deveria baixar.
  return offered ? half : null;
}
