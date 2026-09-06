/* ------------------------------------------------------------------ *
 * Shared tail: measure the physical values, decide the [0,1] mapping,
 * apply it in place. Both the plain and the compressed reader end here so
 * that they can never disagree about what the numbers mean.
 * ------------------------------------------------------------------ */
function normalisePhysical(phys, n, meta, report){
  var bitpix = meta.bitpix, bzero = meta.bzero, bscale = meta.bscale;
  var mn = Infinity, mx = -Infinity, bad = 0, i, v;

  for (i = 0; i < n; i++){
    v = phys[i];
    if (!isFinite(v)){ bad++; continue; }
    if (v < mn) mn = v;
    if (v > mx) mx = v;
  }
  if (!isFinite(mn)) throw FitsError('empty', 'the image contains no usable pixel values');

  var lo = 0, hi = 0, div, basis, mode;
  if (bitpix > 0){
    // Integers keep their container scale: rescaling by the observed maximum
    // would be an undeclared stretch.
    var bot = (bitpix === 8) ? 0 : -Math.pow(2, bitpix - 1);
    var top = (bitpix === 8) ? 255 : (Math.pow(2, bitpix - 1) - 1);
    lo = bzero + bscale * bot; hi = bzero + bscale * top;
    div = (hi - lo) || 1;
    mode = 'int';
    basis = 'container range [' + lo + ', ' + hi + ']';
  } else if (mx <= 1.5){
    div = 1; lo = 0; mode = 'unit';
    basis = 'float already normalised to [0,1]';
  } else if (mx <= 70000){
    div = 65535; lo = 0; mode = 'float16';
    basis = 'float on a 16-bit scale (max ' + mx.toFixed(1) + ')';
  } else {
    div = mx; lo = 0; mode = 'floatmax';
    basis = 'float divided by observed maximum ' + mx.toExponential(3);
  }

  if (!(lo === 0 && div === 1 && bad === 0)){
    for (i = 0; i < n; i++){
      v = phys[i];
      phys[i] = isFinite(v) ? (v - lo) / div : NaN;
    }
  }

  var summary = {
    bitpix: bitpix, kind: meta.kind, bzero: bzero, bscale: bscale,
    width: meta.w, height: meta.h, planes: meta.planes,
    rawMin: mn, rawMax: mx, nonFinite: bad,
    normMin: (mn - lo) / div, normMax: (mx - lo) / div,
    scaleBasis: basis, scaleMode: mode, scaleLo: lo, scaleHi: hi, scaleDiv: div
  };
  if (meta.compression) summary.compression = meta.compression;
  report(summary);
  return summary;
}

// Produces a Float32Array of physical values normalised to roughly [0,1].
// Reuses the source buffer in place when the data is already 32-bit float.
function toNormalisedFloat(buffer, hdu, report){
  var m = hdu.map;
  var bitpix = m.BITPIX | 0;
  var bzero  = (typeof m.BZERO  === 'number') ? m.BZERO  : 0;
  var bscale = (typeof m.BSCALE === 'number') ? m.BSCALE : 1;
  if (bscale === 0) bscale = 1;

  var w = m.NAXIS1 | 0, h = m.NAXIS2 | 0;
  var planes = (m.NAXIS | 0) >= 3 ? (m.NAXIS3 | 0) : 1;
  if (planes < 1) planes = 1;
  var n = w * h * planes;
  var start = hdu.dataStart;

  if (!(w > 0 && h > 0)) throw FitsError('baddims', 'image dimensions are not usable (' + w + ' x ' + h + ')');

  var src, kind;
  if (bitpix === 8){
    src = new Uint8Array(buffer, start, n);
    kind = '8-bit unsigned integer';
  } else if (bitpix === 16){
    swap16(buffer, start, n);
    src = new Int16Array(buffer, start, n);
    kind = (bzero === 32768)
      ? '16-bit unsigned integer (BZERO 32768)'
      : (bzero === 0 ? '16-bit signed integer' : '16-bit integer (BZERO ' + bzero + ')');
  } else if (bitpix === 32){
    swap32(buffer, start, n);
    src = new Int32Array(buffer, start, n);
    kind = '32-bit integer';
  } else if (bitpix === -32){
    swap32(buffer, start, n);
    src = new Float32Array(buffer, start, n);
    kind = '32-bit IEEE float';
  } else if (bitpix === -64){
    swap64(buffer, start, n);
    src = new Float64Array(buffer, start, n);
    kind = '64-bit IEEE float';
  } else {
    throw FitsError('bitpix', 'unsupported BITPIX value ' + bitpix);
  }

  // Bring everything onto one physical-value array, then hand it to the same
  // tail the compressed reader uses. 32-bit float with an identity BZERO/BSCALE
  // is already that array, so it stays in place — that matters when the file is
  // hundreds of megabytes.
  var out;
  if (bitpix === -32){
    out = src;
    if (bzero !== 0 || bscale !== 1){
      for (var j = 0; j < n; j++) out[j] = bzero + bscale * src[j];
    }
  } else {
    // 64-bit source keeps 64-bit intermediates: physical values can be far
    // outside [0,1], and rounding them to float32 before normalising would
    // throw away precision the file actually carries.
    out = (bitpix === -64) ? new Float64Array(n) : new Float32Array(n);
    for (var j2 = 0; j2 < n; j2++) out[j2] = bzero + bscale * src[j2];
  }

  normalisePhysical(out, n, {
    w: w, h: h, planes: planes, bitpix: bitpix, bzero: bzero, bscale: bscale, kind: kind
  }, report);

  // Kept separate: the summary is structure-cloned into the diagnostics, and
  // the pixel array must never ride along with it.
  return { data: out, w: w, h: h, planes: planes };
}

/* ------------------------------------------------------------------ *
 * Row order
 * ------------------------------------------------------------------ */

function flipRows(data, w, h, planes){
  var row = new data.constructor(w);
  for (var p = 0; p < planes; p++){
    var base = p * w * h;
    for (var y = 0; y < (h >> 1); y++){
      var a = base + y * w, b = base + (h - 1 - y) * w;
      row.set(data.subarray(a, a + w));
      data.copyWithin(a, b, b + w);
      data.set(row, b);
    }
  }
}

