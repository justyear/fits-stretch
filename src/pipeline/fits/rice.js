/* ------------------------------------------------------------------ *
 * Rice tile decompression (.fz)
 *
 * A tile-compressed FITS keeps its image in a BINTABLE: one row per tile,
 * holding a descriptor into the heap plus, for quantised float data, the
 * ZSCALE / ZZERO that turn the stored integers back into floating point.
 * This is a direct port of cfitsio's fits_rdecomp and unquantize_i4r4.
 * ------------------------------------------------------------------ */

// Bytes one table row spends on a column. Variable-length array columns
// ('P' / 'Q') store only a descriptor, whatever the array length.
function tformBytes(form){
  var mm = /^\s*(\d*)\s*([A-Z])/.exec(form);
  if (!mm) return 0;
  var rep = mm[1] === '' ? 1 : parseInt(mm[1], 10);
  var t = mm[2];
  if (t === 'P') return 8;
  if (t === 'Q') return 16;
  var size = { L: 1, X: 1, B: 1, I: 2, J: 4, K: 8, A: 1, E: 4, D: 8, C: 8, M: 16 }[t];
  return rep * (size || 1);
}

// Position of the most significant set bit, 1-based; 0 for 0.
var NONZERO_COUNT = (function(){
  var t = new Uint8Array(256);
  for (var i = 1; i < 256; i++){ var k = 0, v = i; while (v){ k++; v >>= 1; } t[i] = k; }
  return t;
})();

// cfitsio's fixed table of 10000 pseudo-random values, from a Park-Miller
// generator seeded at 1. Generated rather than embedded.
var N_RANDOM = 10000, randomValues = null;
function initRandoms(){
  if (randomValues) return randomValues;
  var a = 16807.0, m = 2147483647.0, seed = 1.0;
  var r = new Float64Array(N_RANDOM);
  for (var i = 0; i < N_RANDOM; i++){
    var temp = a * seed;
    seed = temp - m * Math.floor(temp / m);
    r[i] = seed / m;
  }
  randomValues = r;
  return r;
}

// Port of cfitsio fits_rdecomp / _short / _byte. Values come back in `out` as
// signed 32-bit; for bytepix 1 and 2 they are masked to the stored width.
function riceDecompress(src, cstart, clen, out, nx, nblock, bytepix){
  var fsbits, fsmax, bbits, mask;
  if (bytepix === 1){ fsbits = 3; fsmax = 6;  bbits = 8;  mask = 0xFF; }
  else if (bytepix === 2){ fsbits = 4; fsmax = 14; bbits = 16; mask = 0xFFFF; }
  else { fsbits = 5; fsmax = 25; bbits = 32; mask = 0; }   // 0 = full 32-bit

  var cend = cstart + clen;
  var c = cstart, i = 0, imax, fs, nzero, diff, k, b, nbits, q;

  var lastpix = 0;
  for (q = 0; q < bytepix; q++) lastpix = (lastpix << 8) | src[c++];
  if (bytepix === 4) lastpix = lastpix | 0;                // reinterpret as signed

  b = src[c++];
  nbits = 8;

  while (i < nx){
    nbits -= fsbits;
    while (nbits < 0){ b = ((b << 8) | src[c++]) >>> 0; nbits += 8; }
    fs = (b >>> nbits) - 1;
    b &= (1 << nbits) - 1;

    imax = i + nblock;
    if (imax > nx) imax = nx;

    if (fs < 0){
      // Whole block identical to the previous pixel.
      for (; i < imax; i++) out[i] = lastpix;
    } else if (fs === fsmax){
      // High entropy: differences written out in full.
      for (; i < imax; i++){
        k = bbits - nbits;
        diff = (b << k) >>> 0;
        for (k -= 8; k >= 0; k -= 8){
          b = src[c++];
          diff = (diff | (b << k)) >>> 0;
        }
        if (nbits > 0){
          b = src[c++];
          diff = (diff | (b >>> (-k))) >>> 0;
          b &= (1 << nbits) - 1;
        } else b = 0;

        if ((diff & 1) === 0) diff = diff >>> 1; else diff = ~(diff >>> 1);
        lastpix = mask ? ((diff + lastpix) & mask) : ((diff + lastpix) | 0);
        out[i] = lastpix;
      }
    } else {
      // Normal case: unary high part, then fs low bits.
      for (; i < imax; i++){
        while (b === 0){ nbits += 8; b = src[c++]; }
        nzero = nbits - NONZERO_COUNT[b];
        nbits -= nzero + 1;
        b ^= 1 << nbits;                                   // clear the leading one
        nbits -= fs;
        while (nbits < 0){ b = ((b << 8) | src[c++]) >>> 0; nbits += 8; }
        diff = (((nzero << fs) >>> 0) | (b >>> nbits)) >>> 0;
        b &= (1 << nbits) - 1;

        if ((diff & 1) === 0) diff = diff >>> 1; else diff = ~(diff >>> 1);
        lastpix = mask ? ((diff + lastpix) & mask) : ((diff + lastpix) | 0);
        out[i] = lastpix;
      }
    }
    if (c > cend + 4) throw FitsError('cmptype', 'Rice stream ran past the end of its tile');
  }
}

var DITHER_ZERO = -2147483647;   // cfitsio sentinel: the pixel was exactly 0.0

function decodeTileCompressed(buffer, hdu, report, stage){
  var m = hdu.map, tbl = hdu.table;
  var bytes = new Uint8Array(buffer);
  var dv = new DataView(buffer);

  var cmp = String(m.ZCMPTYPE || '').trim().toUpperCase();
  if (cmp !== 'RICE_1') throw FitsError('cmptype', cmp || '(no ZCMPTYPE)');

  var w = m.NAXIS1 | 0, h = m.NAXIS2 | 0;
  var planes = (m.NAXIS | 0) >= 3 ? (m.NAXIS3 | 0) : 1;
  if (planes < 1) planes = 1;
  if (!(w > 0 && h > 0)) throw FitsError('baddims', 'compressed image is ' + w + ' x ' + h);

  var zbitpix = m.BITPIX | 0;
  var bzero  = (typeof m.BZERO  === 'number') ? m.BZERO  : 0;
  var bscale = (typeof m.BSCALE === 'number') ? m.BSCALE : 1;
  if (bscale === 0) bscale = 1;

  var t1 = (m.ZTILE1 | 0) || w, t2 = (m.ZTILE2 | 0) || 1, t3 = (m.ZTILE3 | 0) || 1;

  var blocksize = 32, bytepix = Math.abs(zbitpix) / 8;
  for (var zi = 1; zi <= 16; zi++){
    var nm = m['ZNAME' + zi];
    if (typeof nm !== 'string') continue;
    nm = nm.trim().toUpperCase();
    if (nm === 'BLOCKSIZE') blocksize = m['ZVAL' + zi] | 0;
    else if (nm === 'BYTEPIX') bytepix = m['ZVAL' + zi] | 0;
  }
  if (blocksize < 1) blocksize = 32;
  if (bytepix !== 1 && bytepix !== 2 && bytepix !== 4){
    throw FitsError('cmptype', 'RICE_1 with BYTEPIX ' + bytepix);
  }

  // --- binary table layout -----------------------------------------
  var rowBytes = tbl.NAXIS1 | 0, rows = tbl.NAXIS2 | 0, tfields = tbl.TFIELDS | 0;
  var col = {}, coff = 0;
  for (var ci = 1; ci <= tfields; ci++){
    var cname = String(tbl['TTYPE' + ci] || '').trim().toUpperCase();
    var cform = String(tbl['TFORM' + ci] || '').trim().toUpperCase();
    col[cname] = { offset: coff, form: cform, wide: /^\s*\d*\s*Q/.test(cform) };
    coff += tformBytes(cform);
  }
  var cData = col['COMPRESSED_DATA'];
  var cScale = col['ZSCALE'], cZero = col['ZZERO'];
  if (!cData) throw FitsError('cmptype', 'the table has no COMPRESSED_DATA column');

  // EVERY OFFSET BELOW COMES OUT OF THE FILE AND IS CHECKED AGAINST THE FILE.
  //
  // None of this was here, and the gap was not theoretical: a descriptor
  // pointing two billion bytes past the end of a 14 kB file produced a picture.
  // Reading past a Uint8Array returns `undefined`, the arithmetic degenerates
  // quietly, and the decoder handed back a flat frame with no error at all.
  //
  // That is the worst failure this page can have. A wrong message sends someone
  // to the wrong fix; silence tells them the file was read when it was not, and
  // the whole argument of the page is that nothing happens to the pixels that is
  // not written down. A frame assembled from bytes that were never in the file
  // is exactly that, and it looks like a successful run.
  //
  // So the rule is: an offset that does not land inside the file is an error
  // about the file, before any read.
  var fileLen = bytes.length;
  if (!(rowBytes > 0) || !(rows > 0)){
    throw FitsError('badheader', 'the compressed table declares ' + rows + ' rows of ' + rowBytes + ' bytes');
  }
  var tableEnd = hdu.dataStart + rowBytes * rows;
  if (tableEnd > fileLen){
    throw FitsError('badheader', 'the compressed table (' + rows + ' x ' + rowBytes +
      ' bytes) ends at ' + tableEnd + ', past the end of a ' + fileLen + '-byte file');
  }
  if (rowBytes < cData.offset + (cData.wide ? 16 : 8)){
    throw FitsError('badheader', 'a table row is ' + rowBytes +
      ' bytes, too short to hold the COMPRESSED_DATA descriptor it declares');
  }

  var theap = (typeof tbl.THEAP === 'number') ? tbl.THEAP : rowBytes * rows;
  var heap = hdu.dataStart + theap;
  if (!(theap >= 0) || heap > fileLen){
    throw FitsError('badheader', 'the heap starts at ' + heap + ', outside a ' + fileLen + '-byte file');
  }

  // --- quantisation -------------------------------------------------
  var quant = String(m.ZQUANTIZ || '').trim().toUpperCase();
  var ditherMethod = (quant === 'SUBTRACTIVE_DITHER_2') ? 2
                   : (quant === 'SUBTRACTIVE_DITHER_1') ? 1 : 0;
  var dither0 = (typeof m.ZDITHER0 === 'number') ? (m.ZDITHER0 | 0) : 0;
  var quantised = !!(cScale && cZero);
  var rnd = (quantised && ditherMethod) ? initRandoms() : null;

  // --- tile geometry ------------------------------------------------
  var tilesX = Math.ceil(w / t1), tilesY = Math.ceil(h / t2), tilesZ = Math.ceil(planes / t3);
  var expected = tilesX * tilesY * tilesZ;
  if (rows !== expected){
    throw FitsError('cmptype', 'table holds ' + rows + ' tiles but the geometry needs ' + expected);
  }

  var out = alloc(Float32Array, w * h * planes, 'the decompressed frame');

  // THE TILE BUFFER IS CAPPED BY THE IMAGE, AND IT GOES THROUGH alloc().
  //
  // It used to be `new Int32Array(t1 * t2 * t3)` with the three values taken
  // straight from ZTILE1/2/3 and nothing between them and the allocator. A
  // 14 kB file with ZTILE 16384 x 16384 moved the renderer from 411 MB to
  // 1179 MB - 768 MB measured, before a single byte of tile data was read - and
  // ZTILE 100000 x 100000 threw a bare RangeError that came out as "this frame
  // is too large for the browser to hold", about a file of fourteen kilobytes.
  //
  // The clamp is not a guess: the decoder already writes at most
  // `nx = min(t1, w - x0)` columns per tile, so a tile larger than the image was
  // never going to be filled past the image anyway. Clamping changes no output -
  // ceil(w/t1) is 1 for every t1 >= w - and turns an unbounded request into one
  // bounded by the frame that `out` above already had to fit.
  var tDecl = [t1, t2, t3];
  if (t1 > w) t1 = w;
  if (t2 > h) t2 = h;
  if (t3 > planes) t3 = planes;
  var tileClamped = (t1 !== tDecl[0] || t2 !== tDecl[1] || t3 !== tDecl[2]);
  var idata = alloc(Int32Array, t1 * t2 * t3, 'the tile buffer');
  var plane = w * h;
  var scaleIdentity = (bzero === 0 && bscale === 1);
  var everyN = Math.max(1, Math.floor(rows / 20));

  for (var t = 0; t < rows; t++){
    if (stage && (t % everyN) === 0) stage('Unpacking Rice tiles', 12 + Math.round(10 * t / rows));

    var rowBase = hdu.dataStart + t * rowBytes;
    var dp = rowBase + cData.offset;
    var nelem, hoff;
    if (cData.wide){
      nelem = Number(dv.getBigInt64(dp, false));
      hoff  = Number(dv.getBigInt64(dp + 8, false));
    } else {
      nelem = dv.getInt32(dp, false);
      hoff  = dv.getInt32(dp + 4, false);
    }
    if (nelem <= 0){
      throw FitsError('cmptype', 'tile ' + (t + 1) + ' is not Rice-coded (this .fz mixes in gzip or raw tiles)');
    }
    // The descriptor is two numbers the file chose. Both are checked here, and
    // the stream this tile claims has to lie inside the file before it is read.
    if (!(hoff >= 0) || !isFinite(hoff) || !isFinite(nelem) || heap + hoff + nelem > fileLen){
      throw FitsError('badheader', 'tile ' + (t + 1) + ' says its ' + nelem +
        ' compressed bytes start at ' + (heap + hoff) + ', which is not inside a ' +
        fileLen + '-byte file');
    }

    var tx = t % tilesX, ty = Math.floor(t / tilesX) % tilesY, tz = Math.floor(t / (tilesX * tilesY));
    var x0 = tx * t1, y0 = ty * t2, z0 = tz * t3;
    var nx = Math.min(t1, w - x0), ny = Math.min(t2, h - y0), nz = Math.min(t3, planes - z0);
    var tileLen = nx * ny * nz;

    riceDecompress(bytes, heap + hoff, nelem, idata, tileLen, blocksize, bytepix);

    var zs = 1, zz = 0, iseed = 0, nextrand = 0;
    if (quantised){
      zs = dv.getFloat64(rowBase + cScale.offset, false);
      zz = dv.getFloat64(rowBase + cZero.offset, false);
      if (ditherMethod){
        iseed = (t + dither0 - 1) % N_RANDOM;
        if (iseed < 0) iseed += N_RANDOM;
        nextrand = (rnd[iseed] * 500) | 0;
      }
    }

    var k = 0;
    for (var pz = 0; pz < nz; pz++){
      for (var py = 0; py < ny; py++){
        var dst = (z0 + pz) * plane + (y0 + py) * w + x0;
        for (var px = 0; px < nx; px++, k++, dst++){
          var iv = idata[k], val;
          if (!quantised){
            val = iv;
          } else if (ditherMethod){
            // Kept in double: ZZERO can be many orders of magnitude larger
            // than the value it reconstructs, so this subtraction is where
            // the precision would be lost.
            val = (ditherMethod === 2 && iv === DITHER_ZERO)
                ? 0.0
                : (iv - rnd[nextrand] + 0.5) * zs + zz;
            nextrand++;
            if (nextrand === N_RANDOM){
              iseed++;
              if (iseed === N_RANDOM) iseed = 0;
              nextrand = (rnd[iseed] * 500) | 0;
            }
          } else {
            val = iv * zs + zz;
          }
          out[dst] = scaleIdentity ? val : (bzero + bscale * val);
        }
      }
    }
  }

  var kind = (zbitpix > 0 ? zbitpix + '-bit integer' : Math.abs(zbitpix) + '-bit IEEE float') +
             ', Rice-compressed';
  var meta = {
    w: w, h: h, planes: planes, bitpix: zbitpix, bzero: bzero, bscale: bscale, kind: kind,
    compression: {
      type: 'RICE_1', tiles: rows, tileDims: [t1, t2, t3], blocksize: blocksize, bytepix: bytepix,
      quantise: quant || 'none', ditherSeed: dither0, heapStart: heap, tableRowBytes: rowBytes
    }
  };
  // The effective tile is what was used; the declared one is only recorded when
  // the two differ, so a clamp is never silent.
  if (tileClamped) meta.compression.tileDeclared = tDecl;
  normalisePhysical(out, w * h * planes, meta, report);
  return { data: out, w: w, h: h, planes: planes };
}

