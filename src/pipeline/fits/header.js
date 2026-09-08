/* ------------------------------------------------------------------ *
 * FITS header parsing
 * ------------------------------------------------------------------ */

var BLOCK = 2880;
var CARD  = 80;

function decodeAscii(bytes, from, to){
  var s = '';
  for (var i = from; i < to; i += 4096){
    var end = Math.min(i + 4096, to);
    s += String.fromCharCode.apply(null, bytes.subarray(i, end));
  }
  return s;
}

// Splits one 80-char card into {key, value, comment}. Returns null for blanks.
function parseCard(card){
  var key = card.slice(0, 8).trim();
  if (key === '') return null;
  if (key === 'END') return { key: 'END' };
  if (key === 'COMMENT' || key === 'HISTORY') return { key: key, value: card.slice(8).trim() };

  var rest, name = key;
  if (key === 'HIERARCH'){
    // HIERARCH SOME LONG NAME = value
    var eq = card.indexOf('=');
    if (eq < 0) return null;
    name = card.slice(9, eq).trim();
    rest = card.slice(eq + 1);
  } else if (card.charAt(8) === '='){
    rest = card.slice(9);
  } else {
    return { key: name, value: card.slice(8).trim(), raw: true };
  }

  rest = rest.replace(/^\s+/, '');
  var value, comment = '';

  if (rest.charAt(0) === "'"){
    // Quoted string; '' is an escaped quote.
    var i = 1, buf = '';
    while (i < rest.length){
      if (rest.charAt(i) === "'"){
        if (rest.charAt(i + 1) === "'"){ buf += "'"; i += 2; continue; }
        i++; break;
      }
      buf += rest.charAt(i); i++;
    }
    value = buf.trim();
    var slash = rest.indexOf('/', i);
    if (slash >= 0) comment = rest.slice(slash + 1).trim();
  } else {
    var cut = rest.indexOf('/');
    var v = (cut >= 0 ? rest.slice(0, cut) : rest).trim();
    if (cut >= 0) comment = rest.slice(cut + 1).trim();
    if (v === 'T') value = true;
    else if (v === 'F') value = false;
    else {
      var n = Number(v.replace(/[dD]/, 'e'));
      value = (v !== '' && isFinite(n)) ? n : v;
    }
  }
  return { key: name, value: value, comment: comment };
}

// Reads one header starting at byte `start`. Returns {map, cards, history, end}.
function readHeader(bytes, start){
  var map = {}, cards = [], history = [], off = start, done = false;

  while (!done){
    if (off + BLOCK > bytes.length) throw FitsError('truncated', 'header runs past end of file');
    var text = decodeAscii(bytes, off, off + BLOCK);
    for (var c = 0; c < BLOCK; c += CARD){
      var raw = text.substr(c, CARD);
      var parsed = parseCard(raw);
      if (!parsed) continue;
      cards.push(raw.replace(/\s+$/, ''));
      if (parsed.key === 'END'){ done = true; break; }
      if (parsed.key === 'HISTORY' || parsed.key === 'COMMENT'){
        if (parsed.key === 'HISTORY') history.push(parsed.value);
        continue;
      }
      if (!(parsed.key in map)) map[parsed.key] = parsed.value;
    }
    off += BLOCK;
  }
  return { map: map, cards: cards, history: history, end: off };
}

function hduDataBytes(map){
  var naxis = map.NAXIS | 0;
  if (!naxis) return 0;
  var n = 1;
  for (var i = 1; i <= naxis; i++) n *= (map['NAXIS' + i] | 0);
  var width = Math.abs(map.BITPIX | 0) / 8;
  var extra = 0;
  if (map.PCOUNT){
    extra = map.PCOUNT | 0;
    // PCOUNT is a count. A negative one is not a strange file, it is an
    // impossible one - and it used to be the way through this check: `need`
    // is n*width + extra, so a large negative extra shrank the declared size
    // to nothing and the "does the data fit in the file?" test passed a header
    // claiming 64 MB inside 4928 bytes. The typed-array view then threw a bare
    // RangeError, which reached the user as "this frame is too large for the
    // browser to hold". Rejecting it here is the fix; the classification in
    // run.js was only the symptom.
    if (extra < 0) throw FitsError('badheader', 'PCOUNT is negative (' + extra + ')');
  }
  return n * width + extra;
}

// Walks HDUs until the first one holding a plain image.
function findImageHDU(buffer){
  var bytes = new Uint8Array(buffer);
  if (bytes.length < BLOCK) throw FitsError('notfits', 'file is smaller than a single FITS block');

  var magic = decodeAscii(bytes, 0, 6);
  if (magic !== 'SIMPLE') throw FitsError('notfits', 'missing SIMPLE keyword');

  var off = 0, index = 0, first = null;
  while (off + BLOCK <= bytes.length){
    var h = readHeader(bytes, off);
    var m = h.map;

    if (index === 0) first = h;

    var compressed = (m.ZIMAGE === true) || (typeof m.ZCMPTYPE === 'string');
    var naxis = m.NAXIS | 0;

    if (compressed){
      // The image lives in this table. Present it to the rest of the pipeline
      // as the image HDU it describes, so nothing downstream has to care: the
      // Z* geometry takes over BITPIX/NAXIS, and the ordinary keywords
      // (BAYERPAT, ROWORDER, HISTORY) are already sitting in this same header.
      var zm = {};
      for (var key in m) zm[key] = m[key];
      zm.BITPIX = m.ZBITPIX;
      zm.NAXIS  = m.ZNAXIS;
      zm.NAXIS1 = m.ZNAXIS1;
      zm.NAXIS2 = m.ZNAXIS2;
      zm.NAXIS3 = m.ZNAXIS3;
      return {
        map: zm, table: m, cards: h.cards, history: h.history,
        dataStart: h.end, index: index, compressed: true
      };
    }

    if (naxis >= 2 && (m.XTENSION === undefined || m.XTENSION === 'IMAGE')){
      var need = hduDataBytes(m);
      if (h.end + need > bytes.length){
        throw FitsError('truncated', 'declared image data (' + need + ' bytes) exceeds the file');
      }
      return { map: m, cards: h.cards, history: h.history, dataStart: h.end, index: index };
    }

    var pad = Math.ceil(hduDataBytes(m) / BLOCK) * BLOCK;
    off = h.end + pad;
    index++;
    if (index > 64) break;
  }
  throw FitsError('noimage', 'no image HDU found in this file');
}

/* ------------------------------------------------------------------ *
 * Byte order + scaling to normalised float
 * ------------------------------------------------------------------ */

function swap16(buffer, start, n){
  var u = new Uint16Array(buffer, start, n);
  for (var i = 0; i < n; i++){ var v = u[i]; u[i] = ((v >>> 8) | (v << 8)) & 0xFFFF; }
}
function swap32(buffer, start, n){
  var u = new Uint32Array(buffer, start, n);
  for (var i = 0; i < n; i++){
    var v = u[i];
    u[i] = ((v >>> 24) | ((v >>> 8) & 0xFF00) | ((v & 0xFF00) << 8) | (v << 24)) >>> 0;
  }
}
function swap64(buffer, start, n){
  var u = new Uint32Array(buffer, start, n * 2);
  for (var i = 0; i < n * 2; i += 2){
    var a = u[i], b = u[i + 1];
    var ra = ((b >>> 24) | ((b >>> 8) & 0xFF00) | ((b & 0xFF00) << 8) | (b << 24)) >>> 0;
    var rb = ((a >>> 24) | ((a >>> 8) & 0xFF00) | ((a & 0xFF00) << 8) | (a << 24)) >>> 0;
    u[i] = ra; u[i + 1] = rb;
  }
}

