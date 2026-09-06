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
