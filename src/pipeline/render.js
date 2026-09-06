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

