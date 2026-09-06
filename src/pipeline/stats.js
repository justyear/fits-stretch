/* ------------------------------------------------------------------ *
 * Statistics: median and normalised MAD, from histograms
 * ------------------------------------------------------------------ */

var BINS = 65536;

function cumulativeAt(hist, total, frac){
  var target = frac * total, acc = 0;
  for (var i = 0; i < BINS; i++){
    acc += hist[i];
    if (acc >= target) return i;
  }
  return BINS - 1;
}

// `stride` subsamples very large planes; median and MAD from several million
// samples are indistinguishable from the full-frame values, and the sample size
// is recorded in the diagnostics.
function analysePlane(data, off, n, stride){
  stride = stride || 1;
  var hist = new Uint32Array(BINS), count = 0, nan = 0;
  var i, v, b;

  for (i = 0; i < n; i += stride){
    v = data[off + i];
    if (v !== v){ nan++; continue; }
    if (v <= 0) b = 0;
    else if (v >= 1) b = BINS - 1;
    else b = (v * (BINS - 1)) | 0;
    hist[b]++; count++;
  }
  if (!count) return null;

  var median = cumulativeAt(hist, count, 0.5) / (BINS - 1);
  var q1 = cumulativeAt(hist, count, 0.25) / (BINS - 1);
  var q3 = cumulativeAt(hist, count, 0.75) / (BINS - 1);

  // Second pass over deviations, on a range derived from the IQR so the
  // resolution stays useful even when the MAD is tiny.
  var span = 3 * (q3 - q1);
  if (!(span > 0)) span = 1 / (BINS - 1);
  var dev = new Uint32Array(BINS), dcount = 0;
  for (i = 0; i < n; i += stride){
    v = data[off + i];
    if (v !== v) continue;
    if (v < 0) v = 0; else if (v > 1) v = 1;
    var d = Math.abs(v - median);
    b = d >= span ? BINS - 1 : ((d / span) * (BINS - 1)) | 0;
    dev[b]++; dcount++;
  }
  var mad = cumulativeAt(dev, dcount, 0.5) / (BINS - 1) * span;

  return {
    median: median, madn: 1.4826 * mad, mad: mad,
    q1: q1, q3: q3, sampled: count, stride: stride, nan: nan,
    percentile: function(frac){ return cumulativeAt(hist, count, frac) / (BINS - 1); }
  };
}

// The per-channel measurement a step records before and after itself.
//
// The entries are the analysePlane results themselves, not a reduced copy of
// them, for two reasons.
//
// A step needs percentiles the record format does not carry: the autostretch
// black point is the 0.05% percentile, which is neither p001 nor p999. Handing
// the live object over means the step asks for what it needs instead of the
// record growing a field per caller.
//
// And there must be exactly one measurement object per channel per point in
// the chain. Two objects describing the same pixels are two things that can
// disagree, which is the failure that already cost a day once — see NOTAS,
// "Quantil de dois estágios que conta duas vezes".
function measure(img, stride){
  stride = stride || 1;
  var out = [];
  for (var c = 0; c < img.channels; c++){
    var s = analysePlane(img.data, c * img.N, img.N, stride);
    if (!s) throw FitsError('empty', 'channel ' + c + ' has no usable pixels');
    s.p001 = s.percentile(0.001);
    s.p999 = s.percentile(0.999);
    s.totalPixels = img.N;
    out.push(s);
  }
  return { perChannel: out };
}

