#!/usr/bin/env python3
"""
Referencia independente dos Modulos 2 e 3.

Os seis detalhes que a spec marcou como decisivos estao implementados e
comentados no ponto onde valem. Errar qualquer um produz numeros
plausiveis e errados, que e o pior modo de falha possivel.
"""
import numpy as np

F32 = np.float32
F64 = np.float64


def med_exact(a):
    """np.median: para contagem par, media dos dois centrais.
    Detalhe 6 -- o quickselect do JS usa essa convencao de proposito."""
    return float(np.median(np.asarray(a, dtype=F64)))


def madn_exact(plane):
    """Detalhe 3 -- os desvios sao arredondados para float32 ANTES da mediana.
    O JS acumula num Float32Array reaproveitado."""
    v = np.asarray(plane, dtype=F64).ravel()
    m = med_exact(v)
    dev = np.abs(v - m).astype(F32)
    return m, 1.4826 * med_exact(dev)


def box_sum(a, size):
    """Somas de caixa separaveis, com zero fora da borda."""
    from scipy.ndimage import uniform_filter
    n = size * size
    return uniform_filter(np.asarray(a, dtype=F64), size=size,
                          mode='constant', cval=0.0) * n


# ------------------------------------------------------- Modulo 2

def colour_calibrate(planes, params=None):
    """Neutralizacao aditiva, depois ganhos multiplicativos do fluxo estelar."""
    p = dict(starSigma=12.0, starMax=0.85, minStarPixels=2000,
             extendedWindow=25, extendedMax=0.50, pedestalRatio=3.0,
             gainMin=0.25, gainMax=4.0, backgroundNeutralise=True)
    p.update(params or {})
    rec = {'params': p}

    if len(planes) != 3:
        return planes, dict(applied=False,
                            skipReason='colour calibration needs 3 channels', **rec)

    # --- 2.1 neutralizacao (aditiva, mediana EXATA: a correcao e menor
    #     que um bin do histograma em dois canais de tres)
    before = [med_exact(c) for c in planes]
    target = float(np.mean(before))
    offsets = [m - target for m in before]
    if p['backgroundNeutralise']:
        # Detalhe 1 -- reducao em float64, escrita de volta em float32
        planes = [(c.astype(F64) - o).astype(F32) for c, o in zip(planes, offsets)]
    rec['neutralizacao'] = dict(medianasAntes=before, alvo=target, offsets=offsets)
    rec['pedestais'] = [target] * 3 if p['backgroundNeutralise'] else before

    # --- 2.2 selecao estelar
    # Detalhe 2 -- AQUI a luminancia e a media simples. E criterio de brilho,
    # nao fotometria. O esticamento usa Rec.709; trocar as duas da numeros
    # plausiveis e errados.
    L = ((planes[0].astype(F64) + planes[1].astype(F64)
          + planes[2].astype(F64)) / 3.0).astype(F32)
    lmed, lmadn = madn_exact(L)
    lo = lmed + p['starSigma'] * lmadn
    hi = p['starMax']
    rec['luminanciaSelecao'] = dict(mediana=lmed, madn=lmadn)
    rec['limiares'] = dict(inferior=lo, superior=hi)

    bright = L > lo
    sel = bright & (L < hi)
    n_sat = int(np.count_nonzero(bright & ~sel))

    # rejeicao de fonte extensa: estrela e pequena e tem vizinhanca vazia
    # Detalhe 5 -- o denominador e a janela CLIPADA, senao todo pixel de
    # borda parece esparso e objeto encostado na borda passa.
    w = p['extendedWindow']
    cnt = box_sum(sel.astype(F64), w)
    win = box_sum(np.ones_like(cnt), w)
    dens = cnt / np.maximum(win, 1.0)
    ext = sel & (dens >= p['extendedMax'])
    n_ext = int(np.count_nonzero(ext))
    sel = sel & ~ext

    n = int(np.count_nonzero(sel))
    rec['selecionados'] = n
    rec['rejeitados'] = dict(saturado=n_sat, extenso=n_ext)
    rec['pixels'] = n

    if n < p['minStarPixels']:
        rec['motivoRecusa'] = (f'only {n} star pixels survived selection, '
                               f'{p["minStarPixels"]} are needed')
        return planes, dict(applied=False, skipReason=rec['motivoRecusa'], **rec)

    sm = [med_exact(c[sel]) for c in planes]
    rec['medianasEstelares'] = sm

    # salvaguarda 2: a razao fica instavel quando o numerador e pequeno
    ped = rec['pedestais']
    if min(sm) < p['pedestalRatio'] * max(ped):
        rec['motivoRecusa'] = (f'the faintest star median is {min(sm):.6f}, less '
                               f'than {p["pedestalRatio"]:.0f}x the sky pedestal '
                               f'({max(ped):.6f})')
        return planes, dict(applied=False, skipReason=rec['motivoRecusa'], **rec)

    # a cor de uma estrela e o fluxo ACIMA do ceu
    above = [s - q for s, q in zip(sm, ped)]
    rec['acimaDoPedestal'] = above
    rec['razoes'] = dict(rOverG=above[0] / above[1], bOverG=above[2] / above[1])

    gains = [above[1] / a for a in above]
    gains[1] = 1.0
    if any(not (p['gainMin'] <= g <= p['gainMax']) for g in gains):
        rec['motivoRecusa'] = f'a gain fell outside [{p["gainMin"]}, {p["gainMax"]}]'
        return planes, dict(applied=False, skipReason=rec['motivoRecusa'], **rec)

    rec['ganhos'] = gains
    planes = [(c.astype(F64) * g).astype(F32) for c, g in zip(planes, gains)]
    return planes, dict(applied=True, skipReason=None, **rec)


# ------------------------------------------------------- Modulo 3

def _mtf(x, m):
    x = np.clip(x, 0.0, 1.0)
    return np.where(x <= 0, 0.0, np.where(x >= 1, 1.0,
                    ((m - 1.0) * x) / (((2.0 * m - 1.0) * x) - m)))


def _mtf_scalar(x, m):
    if x <= 0: return 0.0
    if x >= 1: return 1.0
    return ((m - 1.0) * x) / (((2.0 * m - 1.0) * x) - m)


def linked_stretch(planes, params=None):
    p = dict(linked=True, operator='mtf', target=0.085,
             shadowSigma=-2.80, applyVia='luminance')
    p.update(params or {})
    rec = {'params': p, 'ligado': p['linked'], 'operador': p['operator']}

    # Detalhe 2 -- AQUI e Rec.709, fotometrica.
    if len(planes) == 3:
        Y = (0.2126 * planes[0].astype(F64) + 0.7152 * planes[1].astype(F64)
             + 0.0722 * planes[2].astype(F64)).astype(F32)
    else:
        Y = planes[0]

    ymed, ymadn = madn_exact(Y)
    rec['luminancia'] = dict(mediana=ymed, madn=ymadn)

    c0 = ymed + p['shadowSigma'] * ymadn
    if not (c0 >= 0): c0 = 0.0
    if c0 >= ymed: c0 = max(0.0, ymed * 0.5)
    rec['shadows'] = c0
    scale = 1.0 / (1.0 - c0)

    u = (Y.astype(F64) - c0) * scale
    rec['clipLow'] = int(np.count_nonzero(u <= 0))
    rec['clipHigh'] = int(np.count_nonzero(u >= 1))

    if p['operator'] == 'asinh':
        def f_at(s):
            x = (ymed - c0) * scale
            return float(np.arcsinh(s * x) / np.arcsinh(s))
        lo_s, hi_s = 1e-3, 1e6                      # bisseccao contra o alvo
        for _ in range(200):
            mid = (lo_s + hi_s) / 2
            if f_at(mid) < p['target']: lo_s = mid
            else: hi_s = mid
        s = (lo_s + hi_s) / 2
        rec['solvedStretch'] = s
        rec['midtones'] = None
        Yp = np.arcsinh(s * np.clip(u, 0, 1)) / np.arcsinh(s)
    else:
        x = (ymed - c0) * scale
        m = _mtf_scalar(x, p['target']) if 0 < x < 1 else 0.5
        if not (0 < m < 1): m = 0.5
        rec['midtones'] = m
        rec['solvedStretch'] = None
        Yp = _mtf(u, m)
    rec['target'] = p['target']

    if len(planes) != 3 or p['applyVia'] != 'luminance':
        out = [_mtf((c.astype(F64) - c0) * scale, rec['midtones'] or 0.5).astype(F32)
               for c in planes]
        rec['colourFidelity'] = None
        return out, rec

    Yd = Y.astype(F64)
    r = np.where(Yd > 1e-8, Yp / np.maximum(Yd, 1e-8), 1.0)
    Ro = planes[0].astype(F64) * r
    Go = planes[1].astype(F64) * r
    Bo = planes[2].astype(F64) * r

    # Detalhe 4 -- a deriva e medida sobre os valores float64, ANTES da
    # escrita. Medir depois do float32 da ~1e-7 e parece erro.
    mx = np.maximum(np.maximum(Ro, Go), Bo)
    hot = mx > 1.0
    n_hot = int(np.count_nonzero(hot))
    ok = (Go > 1e-6) & (planes[1].astype(F64) > 1e-6)
    if np.count_nonzero(ok):
        rb = (planes[0].astype(F64) / planes[1].astype(F64))[ok]
        ra = (Ro / Go)[ok]
        bb = (planes[2].astype(F64) / planes[1].astype(F64))[ok]
        ba = (Bo / Go)[ok]
        drift = max(float(np.max(np.abs(ra - rb))), float(np.max(np.abs(ba - bb))))
        rec['colourFidelity'] = dict(
            ratiosBefore=dict(rOverG=med_exact(rb), bOverG=med_exact(bb)),
            ratiosAfter=dict(rOverG=med_exact(ra), bOverG=med_exact(ba)),
            maxRatioDrift=drift, driftSamples=int(np.count_nonzero(ok)),
            highlightPixels=n_hot, pixelsRescaled=n_hot)
    else:
        rec['colourFidelity'] = None

    # estouro: divide os TRES pelo maximo. Clampear por canal muda a cor.
    d = np.where(hot, mx, 1.0)
    out = [np.clip(Ro / d, 0, 1).astype(F32),
           np.clip(Go / d, 0, 1).astype(F32),
           np.clip(Bo / d, 0, 1).astype(F32)]
    rec['highlightCut'] = n_hot
    rec['_preRescaleMax'] = mx        # so para a curva de densidade
    return out, rec


# ------------------------------------------------- curva de densidade

def threshold_density(values, threshold, deltas=(1e-7, 1e-6, 2.4e-6, 6.1e-6, 1e-5, 1e-4, 1e-3, 1e-2)):
    """#{ i : |q_i - T| <= d } para cada d.

    E a tolerancia de uma contagem por limiar, calculada em vez de
    afirmada. Onde o limiar cai numa regiao vazia a curva devolve zero e
    a contagem passa a ser exata pela propria formula -- sem excecao por
    nome, que envelheceria.
    """
    q = np.asarray(values, dtype=F64).ravel()
    return {f'{d:.1e}': int(np.count_nonzero(np.abs(q - threshold) <= d))
            for d in deltas}


def density_report(planes_before_cc, cc_rec, stretch_in, st_rec, out_planes):
    """As quatro contagens por limiar de uma execucao, com a densidade
    de cada uma. O comparador le daqui em vez de recalcular."""
    rep = {}

    if 'limiares' in cc_rec:
        L = ((planes_before_cc[0].astype(F64) + planes_before_cc[1].astype(F64)
              + planes_before_cc[2].astype(F64)) / 3.0).astype(F32)
        rep['selecaoEstelar'] = dict(
            count=cc_rec.get('selecionados'),
            threshold=cc_rec['limiares']['inferior'],
            density=threshold_density(L, cc_rec['limiares']['inferior']))

    if len(stretch_in) == 3:
        Y = (0.2126*stretch_in[0].astype(F64) + 0.7152*stretch_in[1].astype(F64)
             + 0.0722*stretch_in[2].astype(F64)).astype(F32)
    else:
        Y = stretch_in[0]
    c0 = st_rec['shadows']
    scale = 1.0/(1.0 - c0)
    u = (Y.astype(F64) - c0) * scale

    rep['clipLow'] = dict(count=st_rec['clipLow'], threshold=0.0,
                          density=threshold_density(u, 0.0))
    rep['clipHigh'] = dict(count=st_rec['clipHigh'], threshold=1.0,
                           density=threshold_density(u, 1.0))
    cf = st_rec.get('colourFidelity')
    if cf and st_rec.get('_preRescaleMax') is not None:
        # A densidade tem que ser medida ANTES do reescalonamento. Depois
        # dele todo pixel afetado vale exatamente 1,0 por construcao, e a
        # curva devolveria a contagem inteira em qualquer delta -- que foi
        # o que ela fez antes desta correcao.
        rep['pixelsRescaled'] = dict(count=cf['pixelsRescaled'], threshold=1.0,
                                     density=threshold_density(
                                         st_rec['_preRescaleMax'], 1.0))
    return rep
