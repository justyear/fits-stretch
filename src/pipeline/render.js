/* ------------------------------------------------------------------ *
 * Quantise: float Image -> 8-bit RGBA. Mono is replicated across R, G and B.
 *
 * This is the only place in the pipeline where a level is decided, and it runs
 * once, at the end of the chain.
 *
 * Until Module 1 it was not: the stretch step resolved every pixel through a
 * 2^20-entry LUT, so the values arriving here were 8-bit levels carried as
 * floats and fl32(k/255) * 255 rounded back to k for all 256 of them. The
 * multiply was a lossless unpacking, and the PNG was byte-reproducible because
 * of it. The chain now carries full float from the decode to this line, so the
 * rounding here is real quantisation and the goldens stopped being
 * byte-comparable — deliberately, on schedule, modulo-1-spec.md section 0.
 *
 * Not one character of this function changed when that happened. Uint8Clamped-
 * Array still does the clamping, which is what catches the negatives a
 * background-subtraction step is allowed to produce.
 *
 * Module 1 adds one thing here and it is not here yet: +/-0.5 level of
 * deterministic dither, seeded, switchable off. Subtracting a smooth surface
 * from quantised data bands, and this is the only line where the banding can be
 * broken. See modulo-1-spec.md section 2.6 — it lands with the correction step,
 * not before, because until something subtracts a surface there is nothing to
 * band.
 * ------------------------------------------------------------------ */

/* ------------------------------------------------------------------ *
 * Dither
 *
 * Subtracting a smooth surface from quantised data produces banding: a whole
 * region of the frame lands on the same side of the same rounding boundary and
 * the boundary becomes a visible contour. The chain is float, so the banding
 * can only appear here, at the one place a level is decided — and it can only
 * be broken here.
 *
 * Plus or minus half a level of noise, added before rounding, turns the hard
 * threshold into a probabilistic one. A value sitting exactly on k stays on k;
 * a value on k+0.5 goes either way with equal chance, so the contour becomes
 * noise and the eye stops seeing an edge that is not in the sky.
 *
 * DETERMINISTIC, and that is not a convenience. Two reasons, and the second is
 * the product:
 *   - a golden that moved every capture would not be a golden;
 *   - the whole argument of this tool is that nothing happens to the pixels
 *     that is not written down. "Random noise was added" is not something the
 *     log can honestly claim to have measured. A seed makes it reproducible by
 *     anyone holding the same file, which is the difference between a stated
 *     process and a black box.
 *
 * The value is a hash of the planar index rather than a running generator, so
 * it does not depend on iteration order and the three channels decorrelate for
 * free — index c*N+i already differs per channel, so the dither does not paint
 * coloured speckle.
 * ------------------------------------------------------------------ */

var QUANTISE_DITHER_SEED = 20260906;
var QUANTISE_DITHER_LEVELS = 0.5;

function ditherAt(seed, idx){
  var x = (idx + seed) | 0;
  x = Math.imul(x ^ (x >>> 16), 2246822507);
  x = Math.imul(x ^ (x >>> 13), 3266489909);
  x = (x ^ (x >>> 16)) >>> 0;
  return x / 4294967296;           // [0, 1)
}

/**
 * Float Image -> 8-bit RGBA.
 *
 * @param {Image}    img
 * @param {Object}   opts    { dither: bool, ditherSeed: int }
 * @param {Function} report  optional report(record)
 *
 * `dither: false` exists because a non-regression comparison may want the
 * transfer without it. It is not a quality setting and the default is on.
 */
function quantise(img, opts, report){
  opts = opts || {};
  var useDither = (opts.dither !== false);
  var seed = (opts.ditherSeed === undefined) ? QUANTISE_DITHER_SEED : (opts.ditherSeed | 0);
  var amp = QUANTISE_DITHER_LEVELS;

  var data = img.data, N = img.N, channels = img.channels;
  var rgba = new Uint8ClampedArray(N * 4);
  var c, i, o, v, out, idx;
  var low = 0, high = 0, nan = 0;

  for (c = 0; c < channels; c++){
    var base = c * N;
    for (i = 0; i < N; i++){
      idx = base + i;
      v = data[idx];
      if (v !== v){ v = 0; nan++; }
      var scaled = v * 255;
      if (useDither) scaled += (ditherAt(seed, idx) - 0.5) * 2 * amp;
      out = Math.round(scaled);
      // Counted before Uint8ClampedArray does the clamping, because after it
      // the information is gone. These are the negatives a background
      // subtraction is allowed to produce and the highlights a stretch is
      // allowed to blow: the chain does not clamp, so this is where they land,
      // and the record says how many.
      if (out < 0){ low++; }
      else if (out > 255){ high++; }
      o = i * 4 + c;
      rgba[o] = out;
      if (channels === 1){ rgba[o + 1] = out; rgba[o + 2] = out; }
    }
  }
  for (i = 3; i < rgba.length; i += 4) rgba[i] = 255;

  if (report){
    var total = N * channels;
    report({
      id: 'quantise',
      name: 'Quantise to 8-bit',
      applied: true,
      skipReason: null,
      params: { dither: useDither, ditherSeed: useDither ? seed : null,
                ditherAmplitudeLevels: useDither ? amp : 0 },
      clamped: { low: low, high: high, nonFinite: nan, samples: total,
                 lowPct: 100 * low / total, highPct: 100 * high / total },
      before: null, after: null,
      notes: [
        useDither
          ? ('Dithered by plus or minus ' + amp + ' of one level before rounding, from a fixed seed (' +
             seed + '), so the result is reproducible from the same file.')
          : 'Dither off: rounding only.',
        low + ' value' + (low === 1 ? '' : 's') + ' below black and ' + high +
          ' above white were clamped here, out of ' + total + '.'
      ]
    });
  }
  return rgba;
}

/* ------------------------------------------------------------------ *
 * Display downscale (box average)
 * ------------------------------------------------------------------ */

var MAX_VIEW = 2560;

function downscale(rgba, w, h){
  var f = Math.ceil(Math.max(w, h) / MAX_VIEW);
  if (f <= 1) return { data: rgba, w: w, h: h, factor: 1 };

  var dw = Math.max(1, Math.floor(w / f)), dh = Math.max(1, Math.floor(h / f));
  var out = new Uint8ClampedArray(dw * dh * 4);
  var area = f * f;

  for (var y = 0; y < dh; y++){
    for (var x = 0; x < dw; x++){
      var r = 0, g = 0, b = 0;
      for (var yy = 0; yy < f; yy++){
        var row = ((y * f + yy) * w + x * f) * 4;
        for (var xx = 0; xx < f; xx++){
          r += rgba[row]; g += rgba[row + 1]; b += rgba[row + 2];
          row += 4;
        }
      }
      var o = (y * dw + x) * 4;
      out[o] = r / area; out[o + 1] = g / area; out[o + 2] = b / area; out[o + 3] = 255;
    }
  }
  return { data: out, w: dw, h: dh, factor: f };
}

