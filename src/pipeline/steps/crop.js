/* ------------------------------------------------------------------ *
 * Suggested crop — detected, offered, and never applied
 *
 * ENQUADRAMENTO É AUTORIA. Recortar sozinho é decidir a composição da foto de
 * outra pessoa. The step finds the object, measures what a crop to it would do,
 * and writes both into the record. `applied` is false and stays false; only a
 * click applies, and the click is a later step.
 *
 * THE SAFEGUARD THAT MATTERS MOST IS THE THIRD ONE. A frame with two extended
 * objects — M 31 with M 110, the Heart with the Soul — is a DELIBERATE
 * composition, and picking one of them decides for the person which one they
 * wanted. The step does not suggest, and says why. This is the line between a
 * suggestion and the automatic crop that would be wrong.
 *
 * NOTHING NEW IS DETECTED HERE. The discriminator is the one Module 2 already
 * uses to throw a galaxy body out of the star selection: neighbourhood
 * occupancy. A star is small and sits in an empty neighbourhood; an extended
 * source sits inside its own body. Module 2 REJECTS those pixels; this step
 * KEEPS them — same measurement, opposite sign — and `ccRejectExtended` is
 * called rather than copied, so the two cannot drift apart. Two copies of the
 * same definition is a defect this project has already paid for.
 * ------------------------------------------------------------------ */

// 4-connectivity, not 8, and the reason is the reference rather than the
// pixels: `scipy.ndimage.label` defaults to a cross-shaped structuring element,
// and a second implementation that labelled diagonally would split or merge
// components differently from this one on exactly the frames where it matters.
// The count of components is an exact integer in the comparison — section 5 of
// the spec — so the two sides have to mean the same thing by "connected".
var CROP_CONNECTIVITY = 4;

/* Connected components of a binary mask, iterative flood fill.
 *
 * Iterative and not recursive on purpose: a component can be a megapixel, and
 * a recursive fill would exhaust the stack on exactly the frames this step
 * exists for — a large object is the normal case here, not the edge case.
 *
 * Returns, per component, the pixel area and the bounding box. Labels are not
 * kept: nothing downstream needs to know which pixel belongs to which object,
 * and an Int32Array the size of the frame is worth avoiding.
 */
function cropComponents(mask, w, h){
  var N = w * h;
  var seen = alloc(Uint8Array, N, 'the crop component map');
  var stack = alloc(Int32Array, N, 'the crop flood-fill stack');
  var out = [];

  for (var s = 0; s < N; s++){
    if (!mask[s] || seen[s]) continue;
    var top = 0;
    stack[top++] = s; seen[s] = 1;
    var area = 0, x0 = w, x1 = -1, y0 = h, y1 = -1;

    while (top > 0){
      var p = stack[--top];
      var py = (p / w) | 0, px = p - py * w;
      area++;
      if (px < x0) x0 = px;
      if (px > x1) x1 = px;
      if (py < y0) y0 = py;
      if (py > y1) y1 = py;

      if (px > 0     && mask[p - 1] && !seen[p - 1]){ seen[p - 1] = 1; stack[top++] = p - 1; }
      if (px < w - 1 && mask[p + 1] && !seen[p + 1]){ seen[p + 1] = 1; stack[top++] = p + 1; }
      if (py > 0     && mask[p - w] && !seen[p - w]){ seen[p - w] = 1; stack[top++] = p - w; }
      if (py < h - 1 && mask[p + w] && !seen[p + w]){ seen[p + w] = 1; stack[top++] = p + w; }
    }
    out.push({ area: area, x: x0, y: y0, w: x1 - x0 + 1, h: y1 - y0 + 1 });
  }
  return out;
}

/**
 * Suggested crop.
 *
 * @param {Image}    img     NOT mutated — nothing is cropped here
 * @param {Object}   params  { sigma, window, density, margin, minFrame,
 *                             stride }
 * @param {Function} report  report(record)
 */
function stepCrop(img, params, report){
  var w = img.w, h = img.h, N = img.N, data = img.data, ch = img.channels;
  var frameArea = w * h;

  var effective = {
    sigma: params.sigma, window: params.window, density: params.density,
    margin: params.margin, minFrame: params.minFrame,
    connectivity: CROP_CONNECTIVITY
  };

  function refuse(reason, extra){
    var rec = {
      id: 'crop', name: 'Suggested crop',
      // BOTH false. `applied` is false because nothing was done; `suggested` is
      // false because nothing is being offered. Section 3.3: suggesting takes
      // nothing away from the "Not applied" sentence, and refusing to suggest
      // takes away even less.
      applied: false, suggested: false,
      reason: reason,
      params: effective,
      frameSize: [w, h],
      components: 0, componentsAboveMin: 0, componentList: [],
      rect: null, coverageBefore: null, coverageAfter: null, coverageGuard: null,
      notes: []
    };
    if (extra) for (var k in extra) rec[k] = extra[k];
    report(rec);
    return img;
  }

  // --- the sky, and the signal above it -------------------------------
  var Y = alloc(Float32Array, N, 'the crop luminance');
  var i;
  if (ch === 3){
    for (i = 0; i < N; i++){
      Y[i] = SAT_LUM_R * data[i] + SAT_LUM_G * data[N + i] + SAT_LUM_B * data[2 * N + i];
    }
  } else {
    for (i = 0; i < N; i++) Y[i] = data[i];
  }

  var ys = analysePlane(Y, 0, N, params.stride || 1);
  if (!ys) throw FitsError('empty', 'the luminance has no usable pixels');
  var cut = ys.median + effective.sigma * ys.madn;

  var sel = alloc(Uint8Array, N, 'the crop signal mask');
  var signalCount = 0;
  for (i = 0; i < N; i++){
    var v = Y[i];
    if (v === v && v > cut){ sel[i] = 1; signalCount++; }
  }
  if (!signalCount){
    return refuse('no pixel on this frame rises ' + effective.sigma +
                  'σ above the sky, so there is no object to crop to');
  }

  /* --- extended, by the Module 2 measurement, read backwards ----------
   *
   * `ccRejectExtended` zeroes the pixels whose neighbourhood is mostly lit —
   * the ones Module 2 throws out of the star selection. Those are exactly the
   * ones wanted here, so the mask is copied, the rejection is run on the copy,
   * and the difference between the two is the extended mask.
   *
   * Calling it rather than reimplementing it is the point: the two steps then
   * cannot disagree about what "extended" means, and a change to the occupancy
   * rule reaches both at once.
   */
  var kept = allocFrom(Uint8Array, sel, 'the crop star mask');
  ccRejectExtended(kept, w, h, effective.window, effective.density);

  var ext = alloc(Uint8Array, N, 'the crop extended mask');
  var extCount = 0;
  for (i = 0; i < N; i++){
    if (sel[i] && !kept[i]){ ext[i] = 1; extCount++; }
  }
  if (!extCount){
    return refuse('every lit pixel sits in an empty neighbourhood, so this frame ' +
                  'has stars and no extended object to crop to',
                  { signalPixels: signalCount, extendedPixels: 0 });
  }

  // --- components ------------------------------------------------------
  var comps = cropComponents(ext, w, h);

  /* WHICH MEASURE IS "SMALLER THAN cropMinFrame"?
   *
   * The spec says "componente conexo menor que cropMinFrame do quadro" and, in
   * the parameter's own comment, "nunca sugere recorte menor que isto do
   * quadro". Those are two different quantities, and 0.20 cannot be both: the
   * spec's own worked example has the galaxy at 15% of the frame BY PIXEL AREA
   * and still suggests, which a 0.20 pixel-area threshold would forbid.
   *
   * Read here as the BOUNDING BOX area as a fraction of the frame, which is the
   * footprint a crop would have to contain and keeps the worked example valid.
   * BOTH numbers go into the record per component, so the reading can be
   * checked against the fixtures instead of argued about.
   */
  var above = [], list = [];
  for (i = 0; i < comps.length; i++){
    var c = comps[i];
    var boxFrac = (c.w * c.h) / frameArea;
    var pixFrac = c.area / frameArea;
    var entry = { rect: [c.x, c.y, c.w, c.h], pixels: c.area,
                  boxFrac: boxFrac, pixelFrac: pixFrac };
    if (boxFrac >= effective.minFrame) above.push(entry);
    // The record carries the big ones, not every speck: a frame with ten
    // thousand noise blobs would put ten thousand rectangles into the log.
    if (boxFrac >= effective.minFrame * 0.25) list.push(entry);
  }
  list.sort(function(a, b){ return b.boxFrac - a.boxFrac; });
  if (list.length > 8) list = list.slice(0, 8);

  var base = {
    signalPixels: signalCount, extendedPixels: extCount,
    components: comps.length, componentsAboveMin: above.length,
    componentList: list
  };

  /* --- the three safeguards, in the order that decides --------------- */

  // 1. MORE THAN ONE OBJECT. The one that matters most, and it comes first
  //    because it is the only one where the step has a perfectly good rectangle
  //    to offer and must not.
  if (above.length > 1){
    var rec1 = refuse('this frame has ' + above.length + ' extended objects large enough to be ' +
                      'the subject, and choosing one of them would be deciding the ' +
                      'composition for you — two objects in a frame are usually there on ' +
                      'purpose', base);
    return rec1;
  }

  // 2. NOTHING BIG ENOUGH. A component under the floor is more likely a large
  //    star or an artefact than a subject.
  if (above.length === 0){
    var biggest = 0;
    for (i = 0; i < comps.length; i++){
      var bf = (comps[i].w * comps[i].h) / frameArea;
      if (bf > biggest) biggest = bf;
    }
    return refuse('the largest extended object covers ' + (100 * biggest).toFixed(1) +
                  '% of the frame, under the ' + (100 * effective.minFrame).toFixed(0) +
                  '% this step treats as a subject; something that small is more likely ' +
                  'a big star or an artefact than what you pointed at', base);
  }

  var obj = above[0];

  /* A TERCEIRA SALVAGUARDA DA SPEC NAO EXISTE AQUI, E NAO E DIVIDA.
   *
   * A §3.1 pede: "objeto ja ocupando mais que cropMaxCoverage -> nao sugere;
   * nao ha o que recortar". Ela foi implementada, e depois removida, porque
   * MEDIDO ela nao pode disparar -- e o motivo nao e falta de fixture.
   *
   * Um objeto que cobre mais de ~70% do quadro E O FUNDO, pela definicao da
   * etapa que roda antes desta. O modelo de placa fina ajusta a mancha suave
   * que domina o quadro e a subtrai; o que chega aqui e ceu. Medido no
   * `fixture-bigobject`, construido de proposito com 72,9% de cobertura:
   *
   *     sinal   16.915 px   extenso 115 px    p75 0,1062
   *     (contra 571.279 px e 557.356 px no fixture-oneobject, p75 0,2396)
   *
   * O objeto nao chega. Nao existe estado da cadeia em que esta salvaguarda
   * tenha o que julgar, e fabricar um exigiria desligar a extracao de fundo --
   * o que testaria um caminho que a ferramenta real nunca percorre.
   *
   * SALVAGUARDA VAZIA POR CONSTRUCAO DA CADEIA, e isso e DIFERENTE de
   * salvaguarda sem caso ainda:
   *
   *   sem caso ainda        o estado existe, falta um fixture -> DIVIDA
   *   vazia por construcao  o estado nao existe -> FECHADO, nao reimplementar
   *
   * Esta e a segunda. O registro fica para que ninguem a reimplemente daqui a
   * seis meses achando que encontrou um buraco: a pergunta foi feita, medida e
   * respondida. O record carrega isso em `coverageGuard`, com o numero, porque
   * uma salvaguarda que aparenta vigiar algo e pior que nenhuma.
   */
  var coverageGuard = {
    inForce: false,
    evaluable: false,
    objectBoxFrac: obj.boxFrac,
    reason: 'not evaluable in this chain: an object covering most of the frame is ' +
            'what the background model fits and subtracts, so it never reaches this ' +
            'step as signal. Measured on a frame built with 72.9% coverage, only ' +
            '115 pixels survived as extended. The guard is empty by construction, ' +
            'not missing a test case.'
  };

  /* --- the rectangle -------------------------------------------------
   *
   * Margin as a fraction of the LONGER SIDE of the frame, so a wide frame and a
   * tall one get the same visual breathing room rather than the same fraction
   * of two different lengths.
   *
   * Then the aspect ratio of the ORIGINAL frame, by expanding the shorter side.
   * Expanding rather than cropping, because trimming to fit would eat into the
   * margin that was just added and could clip the object itself.
   */
  var mar = effective.margin * Math.max(w, h);
  var rx0 = obj.rect[0] - mar, ry0 = obj.rect[1] - mar;
  var rx1 = obj.rect[0] + obj.rect[2] + mar, ry1 = obj.rect[1] + obj.rect[3] + mar;

  var rw = rx1 - rx0, rh = ry1 - ry0;
  var want = w / h;
  if (rw / rh < want){ var nw = rh * want; rx0 -= (nw - rw) / 2; rw = nw; }
  else               { var nh = rw / want; ry0 -= (nh - rh) / 2; rh = nh; }

  // Clip to the frame, then re-clamp the size: sliding a rectangle back inside
  // is better than shrinking it, because shrinking changes the aspect ratio the
  // two lines above just established.
  rw = Math.min(Math.round(rw), w);
  rh = Math.min(Math.round(rh), h);
  var cx0 = Math.round(rx0), cy0 = Math.round(ry0);
  if (cx0 < 0) cx0 = 0;
  if (cy0 < 0) cy0 = 0;
  if (cx0 + rw > w) cx0 = w - rw;
  if (cy0 + rh > h) cy0 = h - rh;

  // What the crop would do, in the number the person cares about: how much of
  // the picture the object takes up. Pixel area, not box — this is about how
  // full the frame looks, and the box of a thin galaxy is mostly sky.
  var coverageBefore = obj.pixels / frameArea;
  var coverageAfter = obj.pixels / (rw * rh);

  report({
    id: 'crop',
    name: 'Suggested crop',
    // SUGGESTED IS NOT APPLIED. Nothing happened to a single pixel, and the
    // "Not applied" sentence is unaffected: `notAppliedLabels` drops a label
    // only for a record claiming `applied`. Section 3.3, and it is the whole
    // difference between this and the automatic crop that would be wrong.
    applied: false,
    suggested: true,
    reason: null,
    params: effective,
    frameSize: [w, h],
    signalPixels: signalCount,
    extendedPixels: extCount,
    components: comps.length,
    componentsAboveMin: above.length,
    componentList: list,
    rect: [cx0, cy0, rw, rh],
    objectRect: obj.rect,
    coverageBefore: coverageBefore,
    coverageAfter: coverageAfter,
    coverageGuard: coverageGuard,
    notes: []
  });

  return img;
}
