/* ------------------------------------------------------------------ *
 * Colour filter array detection
 * ------------------------------------------------------------------ */

var PATTERNS = ['RGGB', 'BGGR', 'GRBG', 'GBRG'];

function vflipPattern(p){ return p[2] + p[3] + p[0] + p[1]; }
function hflipPattern(p){ return p[1] + p[0] + p[3] + p[2]; }

// Median of one 2x2 sub-lattice, via a coarse histogram.
function latticeMedian(data, w, h, py, px, stride){
  var hist = new Uint32Array(4096), count = 0;
  for (var y = py; y < h; y += stride){
    var row = y * w;
    for (var x = px; x < w; x += stride){
      var v = data[row + x];
      if (v !== v) continue;
      var b = v <= 0 ? 0 : (v >= 1 ? 4095 : (v * 4095) | 0);
      hist[b]++; count++;
    }
  }
  if (!count) return 0;
  var target = count / 2, acc = 0;
  for (var i = 0; i < 4096; i++){ acc += hist[i]; if (acc >= target) return i / 4095; }
  return 1;
}

function detectCFA(data, w, h){
  var out = {
    isMosaic: false, evenDims: (w % 2 === 0 && h % 2 === 0),
    ratioH: 0, ratioV: 0, lattice: [0, 0, 0, 0], greenAxis: null, contrast: 0
  };
  if (!out.evenDims) return out;

  // Neighbour-1 vs neighbour-2 absolute differences. On a continuous image the
  // 2px difference is the larger of the two; on a mosaic it is the smaller.
  var step = Math.max(2, 2 * Math.floor(Math.sqrt((w * h) / 400000) / 2 + 0.5) || 2);
  var d1h = 0, d2h = 0, d1v = 0, d2v = 0, nh = 0, nv = 0;
  var x, y, i, a, b, c;

  for (y = 2; y < h - 2; y += step){
    for (x = 2; x < w - 4; x += step){
      i = y * w + x;
      a = data[i]; b = data[i + 1]; c = data[i + 2];
      if (a !== a || b !== b || c !== c) continue;
      d1h += Math.abs(b - a); d2h += Math.abs(c - a); nh++;
    }
  }
  for (y = 2; y < h - 4; y += step){
    for (x = 2; x < w - 2; x += step){
      i = y * w + x;
      a = data[i]; b = data[i + w]; c = data[i + 2 * w];
      if (a !== a || b !== b || c !== c) continue;
      d1v += Math.abs(b - a); d2v += Math.abs(c - a); nv++;
    }
  }
  if (!nh || !nv) return out;

  out.ratioH = (d2h > 0) ? (d1h / d2h) : 0;
  out.ratioV = (d2v > 0) ? (d1v / d2v) : 0;

  var lstride = Math.max(2, 2 * Math.round(Math.sqrt((w * h) / 1000000) / 2) || 2);
  var m00 = latticeMedian(data, w, h, 0, 0, lstride);
  var m01 = latticeMedian(data, w, h, 0, 1, lstride);
  var m10 = latticeMedian(data, w, h, 1, 0, lstride);
  var m11 = latticeMedian(data, w, h, 1, 1, lstride);
  out.lattice = [m00, m01, m10, m11];

  var mx = Math.max(m00, m01, m10, m11), mn = Math.min(m00, m01, m10, m11);
  out.contrast = (mx + mn > 0) ? (mx - mn) / (mx + mn) : 0;

  // The two greens always sit on one of the diagonals; it is the pair whose
  // medians agree most closely.
  out.greenAxis = Math.abs(m00 - m11) <= Math.abs(m01 - m10) ? 'main' : 'anti';

  out.isMosaic = (out.ratioH > 1.15 && out.ratioV > 1.15);
  return out;
}

function greenAxisOf(pat){
  return (pat[0] === 'G' && pat[3] === 'G') ? 'main' : 'anti';
}

// Reconciles the header pattern with what the pixels actually show.
//
// Producers disagree about whether BAYERPAT describes the array as stored or
// the image as displayed, so a row-order flip is deliberately NOT applied to
// the pattern here. Instead the measured green positions settle it: a vertical
// mirror is the only transform that moves the greens between the two
// diagonals, so one comparison absorbs the whole ambiguity. What measurement
// cannot settle is which of the two non-green sites is red — that distinction
// only ever comes from the header.
function resolvePattern(headerPattern, cfa, xoff, yoff){
  var notes = [];
  var p = headerPattern;

  if (p){
    if (xoff % 2){ p = hflipPattern(p); notes.push('XBAYROFF ' + xoff + ' is odd: pattern shifted one column to ' + p); }
    if (yoff % 2){ p = vflipPattern(p); notes.push('YBAYROFF ' + yoff + ' is odd: pattern shifted one row to ' + p); }
  }

  var source, corrected = false;
  if (p && PATTERNS.indexOf(p) >= 0){
    source = 'header';
    if (greenAxisOf(p) !== cfa.greenAxis){
      p = vflipPattern(p);
      corrected = true;
      notes.push('green sites measured on the ' + cfa.greenAxis +
                 ' diagonal; pattern mirrored to ' + p + ' to match');
    }
  } else {
    // No usable BAYERPAT: keep the green positions the pixels actually show
    // and take the red/blue assignment from the Seestar layout.
    source = 'inferred';
    p = (cfa.greenAxis === 'main') ? 'GRBG' : 'RGGB';
    notes.push('no BAYERPAT keyword; Seestar layout assumed on the measured green axis');
  }
  return { pattern: p, source: source, corrected: corrected, notes: notes };
}

/* ------------------------------------------------------------------ *
 * Bilinear demosaic
 * ------------------------------------------------------------------ */

function debayer(src, w, h, pattern){
  var code = new Int8Array(4);                       // 0 = R, 1 = G, 2 = B
  for (var k = 0; k < 4; k++) code[k] = pattern[k] === 'R' ? 0 : (pattern[k] === 'B' ? 2 : 1);

  var out = new Float32Array(w * h * 3);
  var N = w * h;

  function at(x, y){
    if (x < 0) x = -x; else if (x >= w) x = 2 * w - 2 - x;
    if (y < 0) y = -y; else if (y >= h) y = 2 * h - 2 - y;
    var v = src[y * w + x];
    return v === v ? v : 0;
  }

  for (var y2 = 0; y2 < h; y2++){
    var yp = y2 & 1;
    for (var x2 = 0; x2 < w; x2++){
      var xp = x2 & 1;
      var i = y2 * w + x2;
      var v = src[i]; if (v !== v) v = 0;
      var c = code[yp * 2 + xp];
      var r, g, b;

      if (c === 1){
        g = v;
        var hAvg = (at(x2 - 1, y2) + at(x2 + 1, y2)) * 0.5;
        var vAvg = (at(x2, y2 - 1) + at(x2, y2 + 1)) * 0.5;
        var hColour = code[yp * 2 + (xp ^ 1)];
        if (hColour === 0){ r = hAvg; b = vAvg; } else { r = vAvg; b = hAvg; }
      } else {
        var cross = (at(x2 - 1, y2) + at(x2 + 1, y2) + at(x2, y2 - 1) + at(x2, y2 + 1)) * 0.25;
        var diag  = (at(x2 - 1, y2 - 1) + at(x2 + 1, y2 - 1) + at(x2 - 1, y2 + 1) + at(x2 + 1, y2 + 1)) * 0.25;
        g = cross;
        if (c === 0){ r = v; b = diag; } else { b = v; r = diag; }
      }
      out[i] = r; out[N + i] = g; out[2 * N + i] = b;
    }
  }
  return out;
}

