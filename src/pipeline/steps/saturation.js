/* ------------------------------------------------------------------ *
 * Selective saturation — the first step here that is a preference
 *
 * Every step before this one measures. The background extraction measures a
 * gradient that is in the frame. The colour calibration measures a flux ratio
 * that is a property of the photons. The stretch measures a median. None of
 * them decides anything.
 *
 * THIS ONE DECIDES, and the test that settles it is: ask "what is the true
 * saturation of this object?" and notice the question has no answer. There is
 * no saturation the sky has that this step is recovering. Chrominance in the
 * output is already whatever the calibration determined; scaling it says
 * nothing about the object and something about how much the viewer wants to
 * see.
 *
 * The `amount` constant does not change that. It was measured — from a manual
 * delivery of a real frame, section 1 of the spec — and what that measurement
 * measured is WHAT A PERSON CHOSE. It is an accurate measurement of a taste.
 *
 * What keeps the product honest is not pretending otherwise. The step is a
 * preference applied under MEASURED CONSTRAINTS: the SNR mask and the highlight
 * roll-off are not taste — "do not amplify where there is no signal" is a claim
 * about noise, and "do not push past where a channel clips" is arithmetic. The
 * constraints stop the preference from lying. They do not launder it into a
 * measurement, and the log must not use them to imply that they do.
 * ------------------------------------------------------------------ */

// Same weights as the linked stretch. Using a different luminance here would
// mean the step that preserves brightness and the step that scales chroma
// disagreed about what brightness is.
var SAT_LUM_R = 0.2126, SAT_LUM_G = 0.7152, SAT_LUM_B = 0.0722;

/* HUE, MEASURED FROM THE RGB TRIPLE AND NOT FROM THE DECOMPOSITION.
 *
 * This matters, and it is the difference between a check and a tautology.
 *
 * Hue preservation here is a THEOREM, not an empirical fact:
 * `ch' = Y + (ch - Y)*k` scales every channel difference by k, since
 * `R' - G' = k(R - G)`, and hue depends only on ratios of those differences, so
 * k cancels. Both overflow paths preserve it too — dividing all three by m
 * gives Y'=Y/m and C'=C/m, and adding d to all three leaves C untouched because
 * the weights sum to 1.
 *
 * So a hue drift of zero is the correct result AND also what comes out if the
 * step does nothing at all. It is the same shape as `colourFidelity` in Module
 * 3 and as the class in NOTAS about a step whose failure mode is becoming the
 * identity: it verifies the IMPLEMENTATION, never the design.
 *
 * Computing it from the triple rather than from C is what keeps it useful: a
 * per-channel k, a sign error, a swapped index — anything that breaks the
 * decomposition — shows up here instead of cancelling with itself. And it is
 * worth only as much as the negative control that proves it can fire.
 *
 * Returned in turns of the full circle, so the 1e-6 limit is dimensionless.
 */
function satHue(r, g, b){
  var mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
  var mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
  var d = mx - mn;
  if (!(d > 0)) return -1;              // grey: hue is undefined, not zero
  var h;
  if (mx === r)      h = ((g - b) / d) % 6;
  else if (mx === g) h = ((b - r) / d) + 2;
  else               h = ((r - g) / d) + 4;
  h /= 6;
  return h < 0 ? h + 1 : h;
}

// Shortest way round the circle, in turns.
function satHueDelta(a, b){
  var d = Math.abs(a - b);
  return d > 0.5 ? 1 - d : d;
}

// HSV saturation, which is what the reference table in section 1 measured.
function satOf(r, g, b){
  var mx = r > g ? (r > b ? r : b) : (g > b ? g : b);
  var mn = r < g ? (r < b ? r : b) : (g < b ? g : b);
  return (mx > 0) ? (mx - mn) / mx : 0;
}

// Section 2.4: if the background's colour noise grows by more than this, refuse.
var SAT_NOISE_GROWTH_MAX = 2.0;

// Section 2.4 again: a hue drift above this is an implementation error, not a
// tight tolerance.
var SAT_HUE_DRIFT_MAX = 1e-6;

// The luminance bands of the reference table, section 1. Kept as data so the
// record and the spec cannot drift apart.
var SAT_BANDS =[[0.0, 0.10], [0.10, 0.20], [0.20, 0.35], [0.35, 0.55], [0.55, 0.80], [0.80, 1.01]];

/* UMA FUNCAO, DUAS CHAMADAS. A salvaguarda tem que medir a MESMA aritmetica que
 * roda, e nao uma copia dela.
 *
 * A pre-passada do ruido de croma comecou duplicando este calculo, e o controle
 * negativo pegou: com o clamp do `w` invertido so no laco principal, a
 * pre-passada continuou prevendo k = 1 no fundo, nao viu crescimento nenhum, e
 * deixou a mascara quebrada passar. A salvaguarda estava medindo uma funcao
 * diferente da que ia rodar.
 *
 * E a mesma classe do `records[0]` e da nota sobre duas medicoes da mesma coisa
 * que podem discordar: duas copias da verdade, e a que ninguem lembraria de
 * atualizar e justamente a que verifica a outra.
 */
function satFactor(y, background, noiseSigma, amount, snrLow, snrSpan, knee, floorFrac, kneeSpan){
  var snr = (noiseSigma > 0) ? ((y - background) / noiseSigma) : 0;
  var w = (snrSpan > 0) ? ((snr - snrLow) / snrSpan) : (snr > snrLow ? 1 : 0);
  if (w < 0) w = 0; else if (w > 1) w = 1;

  var roll = 1;
  if (y > knee && kneeSpan > 0){
    roll = floorFrac + (1 - floorFrac) * (1 - (y - knee) / kneeSpan);
    if (roll < floorFrac) roll = floorFrac;
    if (roll > 1) roll = 1;
  }
  return { snr: snr, w: w, roll: roll, k: 1 + (amount - 1) * w * roll };
}

/**
 * Selective saturation.
 *
 * @param {Image}    img     mutated in place
 * @param {Object}   params  { amount, snrLow, snrHigh, highlightKnee,
 *                             highlightFloor, stride, before }
 * @param {Function} report  report(record)
 * @returns {Image}
 */
function stepSaturation(img, params, report){
  var before = params.before || measure(img, params.stride);
  var N = img.N, data = img.data, i;

  var effective = {
    amount: params.amount,
    snrLow: params.snrLow,
    snrHigh: params.snrHigh,
    highlightKnee: params.highlightKnee,
    highlightFloor: params.highlightFloor
  };

  if (img.channels !== 3){
    report({
      id: 'saturation', name: 'Selective saturation',
      applied: false,
      skipReason: 'the frame has ' + img.channels + ' channel' +
                  (img.channels === 1 ? '' : 's') + '; there is no chrominance to scale',
      params: effective,
      mask: null, hueFidelity: null, chromaNoise: null,
      saturationByLuminance: null, overflow: null,
      before: before, after: null,
      notes: ['Mono frame: chrominance does not exist, so there is nothing to make more visible.']
    });
    return img;
  }

  var bR = 0, bG = N, bB = 2 * N;

  var Y = alloc(Float32Array, N, 'the saturation luminance buffer');
  for (i = 0; i < N; i++){
    Y[i] = SAT_LUM_R * data[bR + i] + SAT_LUM_G * data[bG + i] + SAT_LUM_B * data[bB + i];
  }

  /* THE MASK IS DRIVEN BY SNR, NEVER BY ABSOLUTE LUMINANCE.
   *
   * This is a requirement, not a preference, and it is what decides whether the
   * step works on one target or on all of them. A threshold in absolute
   * luminance works on one image and fails on the next, because the background
   * level depends on the target, the sky and the integration time. SNR is
   * dimensionless: "three deviations above the noise" means the same thing
   * under a dark sky and a bright one, in a twenty-minute frame and a
   * sixty-hour one.
   *
   * Both numbers come from the same instrument the stretch used, measured on
   * the frame this step is about to touch — not carried in from an earlier
   * point in the chain, where the stretch has since moved every pixel.
   */
  var ys = analysePlane(Y, 0, N, params.stride || 1);
  if (!ys) throw FitsError('empty', 'the luminance has no usable pixels');
  var background = ys.median, noiseSigma = ys.madn;

  var snrSpan = effective.snrHigh - effective.snrLow;
  var knee = effective.highlightKnee, floorFrac = effective.highlightFloor;
  var kneeSpan = 1 - knee;

  /* SALVAGUARDA DE RUIDO DE CROMA -- E O QUE ELA CONSEGUE E NAO CONSEGUE PEGAR.
   *
   * A secao 2.4 pede: meca o desvio padrao da crominancia nos pixels com
   * snr < snrLow, antes e depois; se crescer mais de 2%, recuse.
   *
   * MEDIDO: ela nao pode disparar com a mascara ligada. Em snr <= snrLow o `w`
   * satura em 0, entao `k` e exatamente 1 e a crominancia daqueles pixels nao e
   * tocada -- crescimento zero por construcao. O unico caminho que os move e o
   * `min < 0`, que ENCOLHE a crominancia ao reescalar para preservar Y. O
   * crescimento e sempre <= 0.
   *
   * E a terceira verificacao desta etapa cujo valor esperado coincide com o que
   * sai quando nada acontece -- as outras duas sao a deriva de matiz e o proprio
   * `k = 1` do fundo. Registrada como tal, e nao como prova de que a mascara
   * protege: ela prova que a mascara ESTA LIGADA, o que e menos e ainda vale.
   *
   * O que ela pega de verdade: um `w` que nao zerasse, um clamp invertido, um
   * snrLow que deixasse de proteger. A alavanca do controle negativo e o
   * `snrLow`, nao o SNR do quadro -- um ceu inteiro de SNR baixo mantem todo
   * mundo abaixo do limiar e portanto intocado, que e o oposto de faze-la
   * disparar.
   *
   * Medida numa pre-passada, antes de qualquer escrita, para que a recusa possa
   * ser uma recusa: uma etapa que aplicasse e depois desfizesse teria que
   * inverter aritmetica com perda.
   */
  var nBg = 0, sumC0 = 0, sumC0sq = 0, sumC1 = 0, sumC1sq = 0;
  for (i = 0; i < N; i++){
    var yp = Y[i];
    if (yp !== yp) yp = 0;
    var snrp = (noiseSigma > 0) ? ((yp - background) / noiseSigma) : 0;
    if (snrp >= effective.snrLow) continue;

    var Rp = data[bR + i], Gp = data[bG + i], Bp = data[bB + i];
    var kp = satFactor(yp, background, noiseSigma, effective.amount, effective.snrLow,
                       snrSpan, knee, floorFrac, kneeSpan).k;

    var cr0 = Rp - yp, cg0 = Gp - yp, cb0 = Bp - yp;
    var m0 = Math.sqrt(cr0 * cr0 + cg0 * cg0 + cb0 * cb0);

    var Rq = yp + cr0 * kp, Gq = yp + cg0 * kp, Bq = yp + cb0 * kp;
    var mnq = Rq < Gq ? (Rq < Bq ? Rq : Bq) : (Gq < Bq ? Gq : Bq);
    if (mnq < 0){
      var lq = -mnq; Rq += lq; Gq += lq; Bq += lq;
      var ylq = yp + lq;
      if (ylq > 0){ var fq = yp / ylq; Rq *= fq; Gq *= fq; Bq *= fq; }
    }
    var mxq = Rq > Gq ? (Rq > Bq ? Rq : Bq) : (Gq > Bq ? Gq : Bq);
    if (mxq > 1){ Rq /= mxq; Gq /= mxq; Bq /= mxq; }

    var yq = SAT_LUM_R * Rq + SAT_LUM_G * Gq + SAT_LUM_B * Bq;
    var cr1 = Rq - yq, cg1 = Gq - yq, cb1 = Bq - yq;
    var m1 = Math.sqrt(cr1 * cr1 + cg1 * cg1 + cb1 * cb1);

    sumC0 += m0; sumC0sq += m0 * m0;
    sumC1 += m1; sumC1sq += m1 * m1;
    nBg++;
  }

  var sigmaBefore = null, sigmaAfter = null, growthPct = null;
  if (nBg > 1){
    var v0 = sumC0sq / nBg - (sumC0 / nBg) * (sumC0 / nBg);
    var v1 = sumC1sq / nBg - (sumC1 / nBg) * (sumC1 / nBg);
    sigmaBefore = Math.sqrt(v0 > 0 ? v0 : 0);
    sigmaAfter  = Math.sqrt(v1 > 0 ? v1 : 0);
    growthPct = (sigmaBefore > 0) ? (100 * (sigmaAfter - sigmaBefore) / sigmaBefore) : 0;
  }

  var chromaNoise = {
    sigmaBefore: sigmaBefore, sigmaAfter: sigmaAfter, growthPct: growthPct,
    pixels: nBg, limitPct: SAT_NOISE_GROWTH_MAX,
    note: 'measured on the pixels the mask leaves at k = 1; with the mask wired ' +
          'correctly this cannot grow, so it verifies the mask is on, not that ' +
          'the mask is right'
  };

  if (growthPct !== null && growthPct > SAT_NOISE_GROWTH_MAX){
    report({
      id: 'saturation', name: 'Selective saturation',
      applied: false,
      skipReason: 'scaling chroma would raise the colour noise of the background by ' +
                  growthPct.toFixed(2) + '%, over the ' + SAT_NOISE_GROWTH_MAX +
                  '% this step accepts; the signal mask is not protecting the sky ' +
                  'on this frame',
      params: effective,
      mask: { background: background, noiseSigma: noiseSigma, luminanceSpan: ys.span,
              pixelsBelowSnrLow: nBg, pctBelowSnrLow: 100 * nBg / N,
              pixelsAtFullAmount: null, pctAtFullAmount: null,
              pixelsAtFullMask: null, pctAtFullMask: null,
              meanK: null, maxK: null },
      hueFidelity: null, chromaNoise: chromaNoise,
      saturationByLuminance: null, overflow: null,
      before: before, after: null,
      notes: ['Nothing was applied: the frame was left exactly as the stretch produced it.']
    });
    return img;
  }

  var belowLow = 0, atFull = 0, atFullMask = 0, sumK = 0, maxK = 0;
  var rescaled = 0, lifted = 0;
  var maxHueDrift = 0, driftSamples = 0;

  var bandPct = [], bandBefore = [], bandAfter = [], bandN = [];
  var nb = SAT_BANDS.length, bi;
  for (bi = 0; bi < nb; bi++){ bandPct.push(0); bandBefore.push(0); bandAfter.push(0); bandN.push(0); }

  for (i = 0; i < N; i++){
    var y = Y[i];
    if (y !== y) y = 0;
    var R = data[bR + i], G = data[bG + i], B = data[bB + i];

    // --- the local factor ---------------------------------------------
    //
    // The same call the noise pre-pass makes. The roll-off inside it is what
    // stops a bright core from becoming a flat orange disc and an emission
    // nebula from becoming neon: the reference delivery FALLS from 0.335 to
    // 0.227 above 0.80, and this reproduces that fall rather than inventing one.
    var fac = satFactor(y, background, noiseSigma, effective.amount, effective.snrLow,
                        snrSpan, knee, floorFrac, kneeSpan);
    var w = fac.w, roll = fac.roll, k = fac.k;
    if (w <= 0) belowLow++;
    if (w >= 1) atFullMask++;
    // `pixelsAtFullAmount` conta w>=1 E roll>=1, que e o que a secao 3 pede -- e
    // num quadro tipico isso e uma fresta. Medido no fixture-colour: o limiar de
    // snrHigh cai em Y = 0.798 e o joelho em 0.80, entao a faixa onde os dois
    // saturam tem 0.002 de largura, o campo da 0.06% e le como "a mascara mal
    // engatou" -- quando ela esta em w = 0.927 na faixa do pico.
    //
    // O campo fica, porque a spec o pede e porque ele responde uma pergunta
    // real ("quanto do quadro recebeu o amount inteiro"). `pixelsAtFullMask`
    // acompanha e responde a outra, que e a que se costuma querer: o sinal forte
    // foi reconhecido pela mascara?
    if (w >= 1 && roll >= 1) atFull++;
    sumK += k;
    if (k > maxK) maxK = k;

    // --- the operation -------------------------------------------------
    // The SAME k on all three chrominance components. Hue is direction,
    // saturation is length; scaling the vector moves only the length.
    var Ro = y + (R - y) * k;
    var Go = y + (G - y) * k;
    var Bo = y + (B - y) * k;

    /* OVERFLOW AND UNDERFLOW MOVE ALL THREE, NEVER ONE.
     *
     * Clamping a single channel pulls it toward the other two and changes the
     * hue of the pixel — which is precisely what this step promises not to do,
     * and the promise is the only reason an aesthetic step belongs in this
     * pipeline at all. Same rule as the linked stretch, for the same reason.
     */
    var mn = Ro < Go ? (Ro < Bo ? Ro : Bo) : (Go < Bo ? Go : Bo);
    if (mn < 0){
      // Lift all three, then rescale so Y is where it was. Adding a constant to
      // all three leaves C untouched (the weights sum to 1) and raises Y; the
      // rescale puts Y back and takes C with it. Hue survives both halves.
      var lift = -mn;
      Ro += lift; Go += lift; Bo += lift;
      var yl = y + lift;
      if (yl > 0){
        var f = y / yl;
        Ro *= f; Go *= f; Bo *= f;
      }
      lifted++;
    }
    var mx = Ro > Go ? (Ro > Bo ? Ro : Bo) : (Go > Bo ? Go : Bo);
    if (mx > 1){ Ro /= mx; Go /= mx; Bo /= mx; rescaled++; }

    // --- what the record has to be able to say --------------------------
    var h0 = satHue(R, G, B);
    if (h0 >= 0){
      var h1 = satHue(Ro, Go, Bo);
      if (h1 >= 0){
        var hd = satHueDelta(h0, h1);
        if (hd > maxHueDrift) maxHueDrift = hd;
        driftSamples++;
      }
    }

    for (bi = 0; bi < nb; bi++){
      if (y >= SAT_BANDS[bi][0] && y < SAT_BANDS[bi][1]){
        bandN[bi]++;
        bandBefore[bi] += satOf(R, G, B);
        bandAfter[bi] += satOf(Ro, Go, Bo);
        break;
      }
    }

    data[bR + i] = Ro; data[bG + i] = Go; data[bB + i] = Bo;
  }

  var byLum = [];
  for (bi = 0; bi < nb; bi++){
    byLum.push({
      range: [SAT_BANDS[bi][0], SAT_BANDS[bi][1]],
      pixels: bandN[bi],
      pctFrame: 100 * bandN[bi] / N,
      before: bandN[bi] ? bandBefore[bi] / bandN[bi] : null,
      after:  bandN[bi] ? bandAfter[bi] / bandN[bi] : null
    });
  }

  var after = measure(img, params.stride);

  report({
    id: 'saturation',
    name: 'Selective saturation',
    applied: true,
    skipReason: null,
    params: effective,
    mask: {
      background: background, noiseSigma: noiseSigma,
      // A largura do segundo histograma do analysePlane, que e a RESOLUCAO do
      // madn: o bin dele e span/(BINS-1), nao 1/(BINS-1). Registrado para que uma
      // comparacao contra outra implementacao dimensione a cota ao instrumento
      // em vez de ao eixo [0,1], onde ela ficaria centenas de vezes larga demais.
      luminanceSpan: ys.span,
      pixelsBelowSnrLow: belowLow, pctBelowSnrLow: 100 * belowLow / N,
      pixelsAtFullAmount: atFull, pctAtFullAmount: 100 * atFull / N,
      pixelsAtFullMask: atFullMask, pctAtFullMask: 100 * atFullMask / N,
      meanK: sumK / N, maxK: maxK
    },
    // An implementation check, not a property check — see the note on satHue.
    // Recorded with what it is, so nobody reads a zero here as evidence that
    // the design is sound rather than that the code matches the design.
    hueFidelity: {
      maxHueDrift: maxHueDrift, driftSamples: driftSamples,
      limit: SAT_HUE_DRIFT_MAX, withinLimit: (maxHueDrift <= SAT_HUE_DRIFT_MAX),
      unit: 'turns of the hue circle',
      note: 'preserved by construction; this measures the implementation, not the design'
    },
    chromaNoise: chromaNoise,
    saturationByLuminance: byLum,
    overflow: { pixelsRescaled: rescaled, pixelsLifted: lifted },
    before: before,
    after: after,
    notes: []
  });

  return img;
}
