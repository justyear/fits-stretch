/* ------------------------------------------------------------------ *
 * Quantise: float Image -> 8-bit RGBA. Mono is replicated across R, G and B.
 *
 * The multiply back to 255 is exact, not approximate: the stretch step resolved
 * every pixel through the LUT, so the values arriving here are 8-bit levels
 * carried as floats, and fl32(k/255) * 255 rounds back to k for all 256 of
 * them. Uint8ClampedArray still does the clamping, which is what will catch the
 * negatives a background-subtraction step is allowed to produce.
 *
 * That exactness is a property of today's one-step chain, not a guarantee this
 * function offers. From the second step on the chain carries full float, this
 * runs once at the very end, and the rounding here becomes real quantisation
 * rather than a lossless unpacking. Nothing changes in this function; what
 * changes is that the goldens stop being byte-comparable. See the decision
 * block in modulo-0-spec.md section 4.
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

