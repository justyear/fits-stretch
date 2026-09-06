/* ------------------------------------------------------------------ *
 * Image — the structure every processing step takes and returns
 *
 * Planar Float32: channel c starts at c * N. That is already the layout
 * toNormalisedFloat and debayer produce, so nothing is rearranged here.
 *
 * Values sit around [0,1] and are deliberately NOT clamped. Background
 * subtraction produces negatives and they have to survive intact until the
 * final quantise — a step that silently clipped its own output could not be
 * audited afterwards, and auditability is the product.
 *
 * On the name: this shadows the DOM's Image constructor, which is safe here
 * and only here. A Worker global scope has no Image, and the main-thread
 * fallback evaluates this source inside `new Function('self', src)`, so the
 * declaration stays local to that call and never reaches window.
 * ------------------------------------------------------------------ */

function Image(data, w, h, channels){
  this.data = data;          // Float32Array, planar, length w*h*channels
  this.w = w;
  this.h = h;
  this.channels = channels;  // 1 or 3
  this.N = w * h;            // channel c starts at c * N
}

// Deep copy. A step is allowed to mutate its input in place, so anything the
// caller still needs afterwards is cloned before the step sees it — see the
// note in run.js about dec.data, which the FITS export hands back untouched.
Image.prototype.clone = function(){
  return new Image(new Float32Array(this.data), this.w, this.h, this.channels);
};

// Box average, per channel, in float. Used to build the preview buffer the
// chain runs on when the host asks for a fast answer.
//
// Not the same thing as downscale() in render.js, which averages 8-bit RGBA for
// the screen. This one runs before any transfer function, so it has to stay in
// float: averaging after quantisation would mean the preview measures a
// different frame than the full run does, and the two would disagree about the
// numbers the log prints.
//
// Always returns a new Image, even when nothing is resampled, so the caller can
// treat the result as its own.
function downscaleFloat(img, maxEdge){
  var f = Math.ceil(Math.max(img.w, img.h) / maxEdge);
  if (f <= 1) return img.clone();

  var dw = Math.max(1, Math.floor(img.w / f));
  var dh = Math.max(1, Math.floor(img.h / f));
  var out = new Float32Array(dw * dh * img.channels);
  var area = f * f, src = img.data;

  for (var c = 0; c < img.channels; c++){
    var sBase = c * img.N, dBase = c * dw * dh;
    for (var y = 0; y < dh; y++){
      for (var x = 0; x < dw; x++){
        var acc = 0;
        for (var yy = 0; yy < f; yy++){
          var row = sBase + (y * f + yy) * img.w + x * f;
          for (var xx = 0; xx < f; xx++) acc += src[row + xx];
        }
        out[dBase + y * dw + x] = acc / area;
      }
    }
  }
  return new Image(out, dw, dh, img.channels);
}
