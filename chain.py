"""Cadeia completa em Python: decode -> extracao de fundo -> autostretch.

Reabre as comparacoes por canal que ficaram em N/A: a referencia do
Modulo 0 descrevia a cadeia SEM extracao de fundo, entao o bloco por
canal comparava dois quadros diferentes.
"""
import json, sys, hashlib
import numpy as np
sys.path.insert(0, '.')
from reference import (normalise_physical, stats_exact, stretch_params,
                       transfer_exact, mtf_scalar, _restore_dither2_zeros)
from reference_bg import extract_background
from astropy.io import fits

BASE = '/mnt/user-data/uploads/'
JOBS = [('fixture-seestar.fit', 'seestar'), ('fixture-rice_fit.fz', 'rice'),
        ('fixture-nonlinear.fit', 'nonlinear'), ('fixture-gradient.fit', 'gradient')]

def load(path):
    with fits.open(path) as hl:
        hdu = next(h for h in hl if h.data is not None)
        hdr = hdu.header
        raw = np.array(hdu.data).astype(np.float64)
        raw, dither = _restore_dither2_zeros(hl, raw)
        bitpix = hdr.get('ZBITPIX', hdr.get('BITPIX'))
        data, norm = normalise_physical(raw, bitpix, float(hdr.get('BZERO', 0)),
                                        float(hdr.get('BSCALE', 1)))
        planes = [data] if data.ndim == 2 else [data[i] for i in range(data.shape[0])]
        ro = hdr.get('ROWORDER')
        ro = ro.strip().upper() if isinstance(ro, str) else None
        if ro != 'TOP-DOWN':
            planes = [np.flipud(p) for p in planes]
        hist = [str(c) for c in hdr.get('HISTORY', [])]
    return planes, hist, norm

if __name__ == '__main__':
    out = {}
    for fn, label in JOBS:
        planes, hist, norm = load(BASE + fn)
        h, w = planes[0].shape
        names = ['R', 'G', 'B'] if len(planes) == 3 else ['MONO']

        bg = extract_background(planes, w, h)
        corrected = bg['corrected'] if bg['applied'] else planes

        # o autostretch mede o quadro CORRIGIDO -- o bug que ele consertou
        st = [stats_exact(p) for p in corrected]
        gmed = float(np.mean([s['median'] for s in st]))
        hits = [c for c in hist if any(k in c.lower() for k in
                ('stretch', 'histogram', 'asinh', 'curve', 'ght'))]
        nonlin = (gmed >= 0.05) or (len(hits) > 0 and gmed >= 0.02)

        ch = {}
        for i, p in enumerate(corrected):
            prm = stretch_params(st[i], nonlin)
            o, lo, hi = transfer_exact(p, prm)
            ch[names[i]] = dict(
                estatisticaExata=st[i], parametros=prm,
                saida=dict(median=float(np.median(o)), mean=float(o.mean()),
                           clipLow=lo, clipHigh=hi,
                           clipLowPct=100.0*lo/o.size, clipHighPct=100.0*hi/o.size),
                pedestal=bg['pedestais'] if False else (bg['pedestals'][i] if bg['applied'] else None))
        out[label] = dict(
            sha256=hashlib.sha256(open(BASE+fn,'rb').read()).hexdigest(),
            decode=dict(width=w, height=h, planes=len(planes), **norm),
            fundo=dict(aplicado=bg['applied'],
                       aceitas=bg.get('accepted'), geradas=len(bg['samples']) if 'samples' in bg else None),
            globalMedian=gmed, nonLinear=nonlin, canais=ch)
        print('%-10s aceitas %3s  gmed %.6f  nonLinear %-5s  saida med %s' % (
            label, bg.get('accepted'), gmed, nonlin,
            [int(ch[n]['saida']['median']) for n in names]))

    json.dump(dict(
      geradoPor='chain.py -- cadeia completa com extracao de fundo',
      proposito='reabre as comparacoes por canal que ficaram em N/A no passo 8',
      cadeia=['decode', 'extracao de fundo (grade no quadro inteiro)', 'autostretch sobre o quadro CORRIGIDO'],
      fixtures=out), open('/home/claude/referencia-cadeia.json','w'), indent=2, ensure_ascii=False)
