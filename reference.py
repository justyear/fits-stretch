#!/usr/bin/env python3
"""
Implementacao de referencia independente do pipeline Justyear.

Independente em: linguagem, biblioteca de leitura (astropy vs leitor JS
proprio), precisao (float64 vs float32), estatistica (exata vs histograma
de 65536 bins) e transferencia (MTF avaliada direto vs LUT de 2^20).

O algoritmo e o mesmo de proposito -- se fosse outro, a comparacao nao
significaria nada. O que se compara e a aritmetica, nao a formula.
"""
import json
import numpy as np
from astropy.io import fits

SHADOW_SIGMA = -2.80
TARGET = 0.25
BLACK_PCT = 0.0005
BINS = 65536
LUT_BITS = 20
LUT_N = 1 << LUT_BITS


# ---------------------------------------------------------------- decode

def normalise_physical(phys, bitpix, bzero, bscale):
    """Espelha normalisePhysical(). Retorna (dados, descricao)."""
    finite = np.isfinite(phys)
    mn = float(phys[finite].min())
    mx = float(phys[finite].max())

    if bitpix > 0:
        bot = 0.0 if bitpix == 8 else -(2.0 ** (bitpix - 1))
        top = 255.0 if bitpix == 8 else (2.0 ** (bitpix - 1) - 1)
        lo = bzero + bscale * bot
        hi = bzero + bscale * top
        div = (hi - lo) or 1.0
        mode = 'int'
    elif mx <= 1.5:
        lo, div, mode = 0.0, 1.0, 'unit'
    elif mx <= 70000:
        lo, div, mode = 0.0, 65535.0, 'float16'
    else:
        lo, div, mode = 0.0, mx, 'floatmax'

    out = (phys.astype(np.float64) - lo) / div
    return out, dict(rawMin=mn, rawMax=mx, scaleMode=mode,
                     scaleLo=lo, scaleDiv=div,
                     normMin=(mn - lo) / div, normMax=(mx - lo) / div)


def _restore_dither2_zeros(hl, data):
    """Restaura a sentinela de zero exato do SUBTRACTIVE_DITHER_2.

    A convencao reserva o inteiro -2147483647 para significar "o valor
    original era 0.0". O astropy 8.0.1 documenta que restaura esses pixels
    e NAO restaura -- ele dequantiza a sentinela como se fosse dado, o que
    produz (S + 0.5 - r)*ZSCALE + ZZERO para r em [0,1).

    Identificamos essa faixa e devolvemos 0.0, como manda a convencao e
    como faz o cfitsio.
    """
    try:
        raw = fits.open(hl.filename(), disable_image_compression=True)
    except Exception:
        return data, None
    with raw:
        hdr = raw[1].header if len(raw) > 1 else None
        if hdr is None or hdr.get('ZQUANTIZ') != 'SUBTRACTIVE_DITHER_2':
            return data, None
        cols = raw[1].data.columns.names
        if 'ZSCALE' not in cols or 'ZZERO' not in cols:
            return data, None
        zs = np.array(raw[1].data['ZSCALE'], dtype=np.float64)
        zz = np.array(raw[1].data['ZZERO'], dtype=np.float64)

    S = -2147483647
    lo = min((S + 0.5 - 1.0) * zs.min() + zz.min(),
             (S + 0.5 - 0.0) * zs.max() + zz.max())
    hi = max((S + 0.5 - 1.0) * zs.min() + zz.min(),
             (S + 0.5 - 0.0) * zs.max() + zz.max())
    # O astropy devolve float32, entao o valor dequantizado chega arredondado
    # e pode cair alguns ULP fora da faixa exata calculada em float64.
    # eps generoso o bastante para absorver isso e ainda 4 ordens de grandeza
    # abaixo do menor pixel de imagem real (~0,014 neste fixture).
    eps = max(abs(hi - lo) * 1e-3, abs(hi) * 1e-6)
    mask = (data >= lo - eps) & (data <= hi + eps)
    hits = int(np.count_nonzero(mask))
    if hits:
        data = data.copy()
        data[mask] = 0.0
    return data, dict(sentinelRange=[lo, hi], pixelsRestored=hits)


def load(path):
    """Le, normaliza e corrige row order. Devolve (planos, meta)."""
    with fits.open(path) as hl:
        hdu = next(h for h in hl if h.data is not None)
        hdr = hdu.header
        raw = np.array(hdu.data).astype(np.float64)

        raw, dither = _restore_dither2_zeros(hl, raw)

        bitpix = hdr.get('BITPIX')
        # CompImageHDU expoe ZBITPIX; astropy ja devolve o array descomprimido
        if 'ZBITPIX' in hdr:
            bitpix = hdr['ZBITPIX']
        elif raw.dtype == np.float32:
            bitpix = -32
        bzero = float(hdr.get('BZERO', 0))
        bscale = float(hdr.get('BSCALE', 1))

        # astropy ja aplicou BZERO/BSCALE ao devolver uint16
        phys = raw

        data, norm = normalise_physical(phys, bitpix, bzero, bscale)

        if data.ndim == 2:
            planes = [data]
        else:
            planes = [data[i] for i in range(data.shape[0])]

        row_order = hdr.get('ROWORDER')
        row_order = row_order.strip().upper() if isinstance(row_order, str) else None
        flipped = (row_order != 'TOP-DOWN')      # ausente = default FITS = bottom-up
        if flipped:
            planes = [np.flipud(p) for p in planes]

        history = [str(c) for c in hdr.get('HISTORY', [])]

        meta = dict(path=path, bitpix=bitpix, bzero=bzero, bscale=bscale,
                    width=planes[0].shape[1], height=planes[0].shape[0],
                    planes=len(planes), rowOrder=row_order, flipApplied=flipped,
                    bayerpat=hdr.get('BAYERPAT'), history=history,
                    dither2=dither, **norm)
        return planes, meta


# ------------------------------------------------------------ estatistica

def stats_exact(plane):
    """Estatistica exata em float64. Sem histograma."""
    v = plane.ravel()
    v = v[np.isfinite(v)]
    med = float(np.median(v))
    mad = float(np.median(np.abs(v - med)))
    return dict(
        median=med,
        madn=1.4826 * mad,
        mad=mad,
        q1=float(np.percentile(v, 25)),
        q3=float(np.percentile(v, 75)),
        p001=float(np.percentile(v, 0.1)),
        p999=float(np.percentile(v, 99.9)),
        pBlack=float(np.percentile(v, BLACK_PCT * 100)),
        min=float(v.min()), max=float(v.max()),
        n=int(v.size),
    )


def stats_histogram(plane, bins=BINS):
    """Emulacao fiel do analysePlane do JS.

    Trunca o bin (| 0), nao arredonda. O MAD usa um segundo histograma
    com escala adaptativa span = 3*(q3-q1), o que da resolucao span/(BINS-1)
    em vez de 1/(BINS-1) -- muito mais fino quando o IQR e apertado.

    Existe para medir o erro de quantizacao, nao para uso.
    """
    v = plane.ravel()
    v = v[np.isfinite(v)]

    b = np.where(v <= 0, 0,
                 np.where(v >= 1, bins - 1,
                          (v * (bins - 1)).astype(np.int64)))
    hist = np.bincount(np.clip(b, 0, bins - 1), minlength=bins)
    cum = np.cumsum(hist)
    n = int(cum[-1])

    def at(frac):
        # cumulativeAt: primeiro i com acc >= frac*total
        i = int(np.searchsorted(cum, frac * n, side='left'))
        return min(i, bins - 1) / (bins - 1)

    med, q1, q3 = at(0.5), at(0.25), at(0.75)

    span = 3.0 * (q3 - q1)
    if not (span > 0):
        span = 1.0 / (bins - 1)

    vc = np.clip(v, 0.0, 1.0)
    d = np.abs(vc - med)
    db = np.where(d >= span, bins - 1, ((d / span) * (bins - 1)).astype(np.int64))
    dhist = np.bincount(np.clip(db, 0, bins - 1), minlength=bins)
    dcum = np.cumsum(dhist)
    dn = int(dcum[-1])
    j = int(np.searchsorted(dcum, 0.5 * dn, side='left'))
    mad = min(j, bins - 1) / (bins - 1) * span

    return dict(median=med, madn=1.4826 * mad, mad=mad,
                q1=q1, q3=q3, span=span,
                p001=at(0.001), p999=at(0.999), pBlack=at(BLACK_PCT))


# ------------------------------------------------------------ transferencia

def mtf(x, m):
    x = np.asarray(x, dtype=np.float64)
    out = np.empty_like(x)
    lo, hi = x <= 0, x >= 1
    mid = ~(lo | hi)
    out[lo] = 0.0
    out[hi] = 1.0
    if m == 0.5:
        out[mid] = x[mid]
    else:
        xm = x[mid]
        out[mid] = ((m - 1.0) * xm) / (((2.0 * m - 1.0) * xm) - m)
    return out


def mtf_scalar(x, m):
    if x <= 0:
        return 0.0
    if x >= 1:
        return 1.0
    if m == 0.5:
        return x
    return ((m - 1.0) * x) / (((2.0 * m - 1.0) * x) - m)


def stretch_params(st, non_linear):
    """Espelha o bloco de parametros do runPipeline."""
    if non_linear:
        shadows = st['pBlack']
        target = min(0.6, max(0.02, st['median']))
    else:
        shadows = st['median'] + SHADOW_SIGMA * st['madn']
        target = TARGET

    if not (shadows >= 0):
        shadows = 0.0
    if shadows >= st['median']:
        shadows = max(0.0, st['median'] * 0.5)
    if shadows >= 1:
        shadows = 0.0

    x = (st['median'] - shadows) / (1.0 - shadows)
    if st['madn'] > 0 and 0 < x < 1:
        midtones = mtf_scalar(x, target)
    else:
        midtones = 0.5
    if not (0 < midtones < 1):
        midtones = 0.5

    return dict(shadows=shadows, midtones=midtones, target=target,
                scale=1.0 / (1.0 - shadows), x=x)


def transfer_exact(plane, p):
    """MTF avaliada direto em float64. Sem LUT."""
    u = (np.nan_to_num(plane, nan=0.0) - p['shadows']) * p['scale']
    low = int(np.count_nonzero(u <= 0))
    high = int(np.count_nonzero(u >= 1))
    out = mtf(u, p['midtones']) * 255.0 + 0.5
    return np.floor(out).astype(np.uint8), low, high


def transfer_lut(plane, p):
    """Reproduz o caminho do LUT de 2^20 do JS, para medir a diferenca."""
    inv = 1.0 / (LUT_N - 1)
    i = np.arange(LUT_N, dtype=np.float64)
    lut = np.floor(mtf(i * inv, p['midtones']) * 255.0 + 0.5).astype(np.uint8)

    u = (np.nan_to_num(plane, nan=0.0) - p['shadows']) * p['scale']
    out = np.empty(u.shape, dtype=np.uint8)
    lo, hi = u <= 0, u >= 1
    mid = ~(lo | hi)
    out[lo] = 0
    out[hi] = 255
    out[mid] = lut[(u[mid] * (LUT_N - 1)).astype(np.int64)]
    return out


# ------------------------------------------------------------------ saida

def run(path, label):
    planes, meta = load(path)
    names = ['R', 'G', 'B'] if len(planes) == 3 else ['MONO']

    exact = [stats_exact(p) for p in planes]
    histo = [stats_histogram(p) for p in planes]

    global_median = float(np.mean([s['median'] for s in exact]))
    history_hits = [h for h in meta['history']
                    if any(k in h.lower() for k in
                           ('stretch', 'histogram', 'asinh', 'curve', 'ght'))]
    non_linear = (global_median >= 0.05) or (len(history_hits) > 0 and global_median >= 0.02)

    result = dict(fixture=label, meta={k: v for k, v in meta.items() if k != 'history'},
                  history=meta['history'],
                  globalMedian=global_median,
                  historyHits=history_hits,
                  nonLinear=non_linear,
                  channels=[])

    for i, p in enumerate(planes):
        st = exact[i]
        prm = stretch_params(st, non_linear)
        out_exact, low, high = transfer_exact(p, prm)
        out_lut = transfer_lut(p, prm)
        diff = np.abs(out_exact.astype(np.int16) - out_lut.astype(np.int16))

        # o mesmo, mas com a estatistica do histograma alimentando os parametros
        prm_h = stretch_params(histo[i], non_linear)

        result['channels'].append(dict(
            name=names[i],
            exact=st,
            histogram=histo[i],
            statDelta=dict(
                median=st['median'] - histo[i]['median'],
                madn=st['madn'] - histo[i]['madn'],
                medianRelPct=100.0 * (st['median'] - histo[i]['median']) / st['median']
                if st['median'] else 0.0,
            ),
            params=prm,
            paramsFromHistogram=prm_h,
            paramDelta=dict(
                shadows=prm['shadows'] - prm_h['shadows'],
                midtones=prm['midtones'] - prm_h['midtones'],
            ),
            out=dict(
                median=float(np.median(out_exact)),
                mean=float(out_exact.mean()),
                clipLow=low, clipHigh=high,
                clipLowPct=100.0 * low / out_exact.size,
                clipHighPct=100.0 * high / out_exact.size,
            ),
            lutVsExact=dict(
                pixelsDiffer=int(np.count_nonzero(diff)),
                pctDiffer=100.0 * int(np.count_nonzero(diff)) / diff.size,
                maxDiff=int(diff.max()),
            ),
        ))
    return result


if __name__ == '__main__':
    import sys
    base = '/mnt/user-data/uploads/'
    jobs = [(base + 'fixture-seestar.fit', 'seestar'),
            (base + 'fixture-rice_fit.fz', 'rice'),
            (base + 'fixture-nonlinear.fit', 'nonlinear')]
    out = [run(p, l) for p, l in jobs]
    json.dump(out, open('/home/claude/reference.json', 'w'), indent=2)
    print(json.dumps(out, indent=2))
