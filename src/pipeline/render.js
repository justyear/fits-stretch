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

function quantise(img){
  var data = img.data, N = img.N, channels = img.channels;
  var rgba = new Uint8ClampedArray(N * 4);
  var c, i, o, v, out;

  for (c = 0; c < channels; c++){
    var base = c * N;
    for (i = 0; i < N; i++){
      v = data[base + i];
      if (v !== v) v = 0;
      out = Math.round(v * 255);
      o = i * 4 + c;
      rgba[o] = out;
      if (channels === 1){ rgba[o + 1] = out; rgba[o + 2] = out; }
    }
  }
  for (i = 3; i < rgba.length; i += 4) rgba[i] = 255;
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

