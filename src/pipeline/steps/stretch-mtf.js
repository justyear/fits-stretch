/* ------------------------------------------------------------------ *
 * Midtones transfer function (PixInsight STF / Siril autostretch)
 * ------------------------------------------------------------------ */

function MTF(x, m){
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  if (m === 0.5) return x;
  return ((m - 1) * x) / (((2 * m - 1) * x) - m);
}

var LUT_BITS = 20, LUT_N = 1 << LUT_BITS;

function buildLUT(midtones){
  var lut = new Uint8Array(LUT_N), inv = 1 / (LUT_N - 1);
  for (var i = 0; i < LUT_N; i++){
    lut[i] = (MTF(i * inv, midtones) * 255 + 0.5) | 0;
  }
  return lut;
}

