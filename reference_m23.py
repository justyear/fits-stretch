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
             extendedWindow=25, extendedMax=0.50,
             pedestalProbe=0.10, sensitivityMax=0.05,
             gainMin=0.25, gainMax=4.0, backgroundNeutralise=True)
    p.update(params or {})
    rec = {'params': p}

    if len(planes) != 3:
        return planes, dict(applied=False, ganhos=None,
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
        return planes, dict(applied=p['backgroundNeutralise'],
                            skipReason=rec['motivoRecusa'], **rec)

    sm = [med_exact(c[sel]) for c in planes]
    rec['medianasEstelares'] = sm

    # Salvaguarda 2: mede a instabilidade em vez de usar um multiplo
    # escolhido. Um multiplo fixo bloqueou um empilhamento de 60 h com cor
    # boa; a sondagem mede a grandeza que a salvaguarda alega proteger.
    ped = rec['pedestais']

    def gains_at(scale):
        ref = sm[1] - ped[1] * scale
        if not ref > 0:
            return None
        out = []
        for k in range(3):
            a = sm[k] - ped[k] * scale
            if not a > 0:
                return None
            out.append(ref / a)
        return out

    g0 = gains_at(1.0)
    if g0 is None:
        rec['motivoRecusa'] = 'a star median does not sit above the sky pedestal'
        rec['gainSensitivity'] = float('inf')
        return planes, dict(applied=p['backgroundNeutralise'],
                            skipReason=rec['motivoRecusa'], **rec)

    sens = 0.0
    # Os dois sentidos: nao sao simetricos, e o lado que encolhe 'above'
    # e onde a razao se desfaz.
    for scale in (1 + p['pedestalProbe'], 1 - p['pedestalProbe']):
        probe = gains_at(scale)
        if probe is None:
            sens = float('inf')
            break
        for k in range(3):
            if g0[k] > 0:
                sens = max(sens, abs(probe[k] - g0[k]) / g0[k])
    rec['gainSensitivity'] = sens

    if not (sens <= p['sensitivityMax']):
        rec['motivoRecusa'] = (
            f'a {p["pedestalProbe"]*100:.0f}% error in the sky pedestal would move '
            f'a gain by {sens*100:.2f}%, over the {p["sensitivityMax"]*100:.0f}% '
            f'limit -- the ratio is not reliable on this frame')
        return planes, dict(applied=p['backgroundNeutralise'],
                            skipReason=rec['motivoRecusa'], **rec)

    # a cor de uma estrela e o fluxo ACIMA do ceu
    above = [s - q for s, q in zip(sm, ped)]
    rec['acimaDoPedestal'] = above
    rec['razoes'] = dict(rOverG=above[0] / above[1], bOverG=above[2] / above[1])

    gains = [above[1] / a for a in above]
    gains[1] = 1.0
    if any(not (p['gainMin'] <= g <= p['gainMax']) for g in gains):
        rec['motivoRecusa'] = f'a gain fell outside [{p["gainMin"]}, {p["gainMax"]}]'
        return planes, dict(applied=p['backgroundNeutralise'],
                            skipReason=rec['motivoRecusa'], **rec)

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


def percentile_nearest_rank(v, frac):
    """Nearest-rank: o menor valor cujo acumulado atinge frac*N.

    E a convencao do JS (histograma, borda inferior do bin). Aqui e a
    versao exata da mesma convencao -- np.percentile INTERPOLA e da
    outro numero.
    """
    s = np.sort(np.asarray(v, dtype=F64).ravel())
    k = int(np.ceil(frac * s.size)) - 1
    return float(s[min(max(k, 0), s.size - 1)])


BLACK_PCT = 0.0005


def linked_stretch(planes, params=None, non_linear=False):
    p = dict(linked=True, operator='mtf', target=0.085,
             shadowSigma=-2.80, applyVia='luminance', blackPct=BLACK_PCT)
    p.update(params or {})
    rec = {'params': p, 'ligado': p['linked'], 'operador': p['operator'],
           'nonLinear': non_linear}

    # Detalhe 2 -- AQUI e Rec.709, fotometrica.
    if len(planes) == 3:
        Y = (0.2126 * planes[0].astype(F64) + 0.7152 * planes[1].astype(F64)
             + 0.0722 * planes[2].astype(F64)).astype(F32)
    else:
        Y = planes[0]

    ymed, ymadn = madn_exact(Y)
    rec['luminancia'] = dict(mediana=ymed, madn=ymadn)

    # No ramo nao-linear o alvo NAO e o parametro: e a mediana do proprio
    # quadro, limitada a [0.02, 0.6]. E o ponto preto sai do percentil,
    # nao da regra de sigma.
    if non_linear:
        c0 = percentile_nearest_rank(Y, p['blackPct'])
        target = min(0.6, max(0.02, ymed))
    else:
        c0 = ymed + p['shadowSigma'] * ymadn
        target = p['target']
    if not (c0 >= 0): c0 = 0.0
    if c0 >= ymed: c0 = max(0.0, ymed * 0.5)
    rec['shadows'] = c0
    rec['luminanceSpan'] = 3.0 * (med_exact(np.percentile(Y, 75))
                                  - med_exact(np.percentile(Y, 25))) \
        if False else 3.0 * (float(np.percentile(Y, 75)) - float(np.percentile(Y, 25)))
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
            if f_at(mid) < target: lo_s = mid
            else: hi_s = mid
        s = (lo_s + hi_s) / 2
        rec['solvedStretch'] = s
        rec['midtones'] = None
        Yp = np.arcsinh(s * np.clip(u, 0, 1)) / np.arcsinh(s)
    else:
        x = (ymed - c0) * scale
        m = _mtf_scalar(x, target) if 0 < x < 1 else 0.5
        if not (0 < m < 1): m = 0.5
        rec['midtones'] = m
        rec['solvedStretch'] = None
        Yp = _mtf(u, m)
    rec['target'] = target

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

def threshold_density(values, threshold, deltas=(1e-7, 1e-6, 2.4e-6, 6.1e-6, 1e-5, 6.8e-5, 1e-4, 1e-3, 1e-2)):
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


# ------------------------------------------------- Modulo 4: saturacao

def sat_factor(Y, background, noise, p):
    """O fator local k. UMA copia.

    A implementacao JS teve um defeito exatamente aqui: a pre-passada do
    ruido duplicava esta formula, o conserto atingiu so o laco principal,
    e a copia intacta aprovou a mascara quebrada. A salvaguarda estava
    medindo uma funcao diferente da que ia rodar. Aqui a pre-passada e a
    aplicacao chamam esta funcao, nao uma copia dela.
    """
    Y = np.asarray(Y, dtype=F64)
    snr = (Y - background) / max(noise, 1e-12)
    w = np.clip((snr - p['snrLow']) / (p['snrHigh'] - p['snrLow']), 0.0, 1.0)

    knee, floor = p['highlightKnee'], p['highlightFloor']
    roll = np.where(Y <= knee, 1.0,
                    floor + (1.0 - floor) * (1.0 - (Y - knee) / (1.0 - knee)))
    roll = np.clip(roll, floor, 1.0)
    return 1.0 + (p['amount'] - 1.0) * w * roll, w, roll


def _hue_hsv(r, g, b):
    """Matiz em voltas [0,1), do trio RGB direto.

    Do trio, NAO da decomposicao Y-C: um k por canal ou um erro de sinal
    dentro da decomposicao se cancelaria consigo mesmo se o matiz fosse
    calculado a partir dela.
    """
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    d = mx - mn
    h = np.zeros_like(mx)
    ok = d > 1e-12
    ir = ok & (mx == r)
    ig = ok & (mx == g) & ~ir
    ib = ok & ~ir & ~ig
    with np.errstate(invalid='ignore', divide='ignore'):
        h[ir] = ((g[ir] - b[ir]) / d[ir]) % 6.0
        h[ig] = ((b[ig] - r[ig]) / d[ig]) + 2.0
        h[ib] = ((r[ib] - g[ib]) / d[ib]) + 4.0
    return (h / 6.0) % 1.0, ok


def saturate(planes, params=None, background=None, noise=None):
    p = dict(amount=1.45, snrLow=3.0, snrHigh=25.0,
             highlightKnee=0.80, highlightFloor=0.35,
             chromaGrowthMax=0.02, hueDriftMax=1e-6)
    p.update(params or {})
    rec = {'params': p}

    if len(planes) != 3:
        return planes, dict(applied=False,
                            skipReason='saturation needs 3 channels', **rec)

    R, G, B = [c.astype(F64) for c in planes]
    Y = 0.2126 * R + 0.7152 * G + 0.0722 * B

    if background is None or noise is None:
        background, noise = madn_exact(Y.astype(F32))
    q1, q3 = float(np.percentile(Y, 25)), float(np.percentile(Y, 75))
    rec['mask'] = dict(background=background, noiseSigma=noise,
                       luminanceSpan=3.0 * (q3 - q1))

    k, w, roll = sat_factor(Y, background, noise, p)
    protected = w <= 0.0
    rec['mask'].update(
        pixelsBelowSnrLow=int(np.count_nonzero(protected)),
        pctFrame=100.0 * float(np.mean(protected)),
        pixelsAtFullAmount=int(np.count_nonzero((w >= 1.0) & (roll >= 1.0))),
        pixelsAtFullMask=int(np.count_nonzero(w >= 1.0)),
        meanK=float(k.mean()), maxK=float(k.max()))

    Ro, Go, Bo = Y + (R - Y) * k, Y + (G - Y) * k, Y + (B - Y) * k

    # Salvaguarda de ruido de croma, sobre o conjunto protegido, com o
    # MESMO k que a aplicacao usa.
    if np.count_nonzero(protected):
        # Desvio da NORMA da crominancia, um escalar por pixel -- nao das
        # tres componentes empilhadas. Sao grandezas diferentes: empilhar
        # mede dispersao por componente, a norma mede dispersao do vetor.
        nb = np.sqrt((R - Y)[protected]**2 + (G - Y)[protected]**2
                     + (B - Y)[protected]**2)
        na = np.sqrt((Ro - Y)[protected]**2 + (Go - Y)[protected]**2
                     + (Bo - Y)[protected]**2)
        sb, sa = float(nb.std()), float(na.std())
        growth = (sa - sb) / sb if sb > 0 else 0.0
    else:
        sb = sa = 0.0
        growth = 0.0
    rec['chromaNoise'] = dict(sigmaBefore=sb, sigmaAfter=sa,
                              growthPct=100.0 * growth)

    if growth > p['chromaGrowthMax']:
        rec['motivoRecusa'] = (
            f'background chroma noise would grow {growth*100:.2f}%, over the '
            f'{p["chromaGrowthMax"]*100:.0f}% limit -- the mask is not '
            f'protecting the sky')
        return planes, dict(applied=False, skipReason=rec['motivoRecusa'], **rec)

    # Estouro: os TRES juntos, nunca um canal sozinho.
    # Subfluxo PRIMEIRO, reescalando para preservar Y; transbordo depois.
    # A ordem importa e este caminho nao e exercitado por nenhum fixture --
    # zero contra zero nao e acordo, e o comparador diz isso.
    mn = np.minimum(np.minimum(Ro, Go), Bo)
    cold = mn < 0.0
    lift = np.where(cold, -mn, 0.0)
    Ro, Go, Bo = Ro + lift, Go + lift, Bo + lift
    # reescala para devolver Y ao valor que tinha antes do levantamento
    Yl = 0.2126 * Ro + 0.7152 * Go + 0.0722 * Bo
    with np.errstate(divide='ignore', invalid='ignore'):
        f = np.where(Yl > 1e-12, Y / Yl, 1.0)
    Ro, Go, Bo = Ro * f, Go * f, Bo * f

    mx = np.maximum(np.maximum(Ro, Go), Bo)
    hot = mx > 1.0
    d = np.where(hot, mx, 1.0)
    Ro, Go, Bo = Ro / d, Go / d, Bo / d
    rec['overflow'] = dict(pixelsRescaled=int(np.count_nonzero(hot)),
                           pixelsLifted=int(np.count_nonzero(cold)),
                           pixelsUnderflow=int(np.count_nonzero(cold)))

    h0, ok0 = _hue_hsv(R, G, B)
    h1, ok1 = _hue_hsv(Ro, Go, Bo)
    m = ok0 & ok1
    if np.count_nonzero(m):
        dh = np.abs(h1[m] - h0[m])
        dh = np.minimum(dh, 1.0 - dh)          # matiz e circular
        rec['hueFidelity'] = dict(maxHueDrift=float(dh.max()),
                                  driftSamples=int(np.count_nonzero(m)))
    else:
        rec['hueFidelity'] = dict(maxHueDrift=0.0, driftSamples=0)

    def satur(r, g, b):
        # (max-min)/max sempre que max > 0. Sem piso em 0,03: o piso era
        # meu e zerava a faixa escura inteira, que e onde a salvaguarda de
        # ruido vive.
        M = np.maximum(np.maximum(r, g), b)
        mm = np.minimum(np.minimum(r, g), b)
        return np.where(M > 0.0, (M - mm) / np.maximum(M, 1e-12), 0.0)

    tab = []
    s0, s1 = satur(R, G, B), satur(Ro, Go, Bo)
    for lo, hi in [(0.0, 0.10), (0.10, 0.20), (0.20, 0.35),
                   (0.35, 0.55), (0.55, 0.80), (0.80, 1.01)]:
        sel = (Y >= lo) & (Y < hi)
        n = int(np.count_nonzero(sel))
        tab.append(dict(range=[lo, hi], pixels=n, pct=100.0 * float(np.mean(sel)),
                        before=float(s0[sel].mean()) if n else 0.0,
                        after=float(s1[sel].mean()) if n else 0.0))
    rec['saturationByLuminance'] = tab

    out = [np.clip(x, 0, 1).astype(F32) for x in (Ro, Go, Bo)]
    return out, dict(applied=True, skipReason=None, **rec)


# --------------------------------------- Modulo 5a: escala e recorte

def _sigma_lag(v, sky, lag, want_span=False):
    """1.4826 * mediana(|v[x+lag] - v[x]|) / sqrt(2), so na horizontal,
    sobre pares em que AMBOS sao ceu.

    Dois pontos onde uma implementacao razoavel diverge em silencio:
    o MAD e sobre ZERO (mediana de |diff|, nao de |diff - mediana(diff)|),
    e a divisao por sqrt(2) porque a diferenca de duas amostras
    independentes tem variancia dobrada.
    """
    a = v[:, :-lag]
    b = v[:, lag:]
    m = sky[:, :-lag] & sky[:, lag:]
    if not np.count_nonzero(m):
        return 0.0
    d = np.abs(b[m].astype(F64) - a[m].astype(F64))
    return 1.4826 * med_exact(d) / np.sqrt(2.0)


def half_scale(planes, params=None):
    """Media de caixa 2x2 exata, sobre o float, antes do quantise."""
    p = dict(band=(1.8, 2.2), expectedRatio=2.0, skySigma=3.0)
    p.update(params or {})
    rec = {'params': p}

    h, w = planes[0].shape
    w2, h2 = w >> 1, h >> 1          # dimensao impar DESCARTA, nunca interpola
    rec['inputSize'] = [w, h]
    rec['outputSize'] = [w2, h2]
    rec['droppedRow'] = bool(h % 2)
    rec['droppedColumn'] = bool(w % 2)

    if len(planes) == 3:
        Y = (0.2126 * planes[0].astype(F64) + 0.7152 * planes[1].astype(F64)
             + 0.0722 * planes[2].astype(F64)).astype(F32)
    else:
        Y = planes[0]
    med, madn = madn_exact(Y)
    sky = Y < med + p['skySigma'] * madn

    # brancura: lags vindos do BLOCO 2x2, nao dos dados
    s1 = _sigma_lag(Y, sky, 1)
    best, bestL = 1.0, 2
    for L in (2, 3, 4):
        sL = _sigma_lag(Y, sky, L)
        r = (s1 / sL) if sL > 0 else 1.0
        if r < best:
            best, bestL = r, L

    out = []
    for c in planes:
        a = c.astype(F64)[:h2 * 2, :w2 * 2]
        out.append((((a[0::2, 0::2] + a[0::2, 1::2]
                      + a[1::2, 0::2] + a[1::2, 1::2]) * 0.25)).astype(F32))

    if len(out) == 3:
        Y2 = (0.2126 * out[0].astype(F64) + 0.7152 * out[1].astype(F64)
              + 0.0722 * out[2].astype(F64)).astype(F32)
    else:
        Y2 = out[0]
    # um pixel reduzido e ceu sse os QUATRO de origem eram ceu
    s = sky[:h2 * 2, :w2 * 2]
    sky2 = s[0::2, 0::2] & s[0::2, 1::2] & s[1::2, 0::2] & s[1::2, 1::2]

    sb = _sigma_lag(Y, sky, 1)
    sa = _sigma_lag(Y2, sky2, 1)
    ratio = (sb / sa) if sa > 0 else 0.0

    rec['noise'] = dict(
        skyHighFreqBefore=sb, skyHighFreqAfter=sa, ratio=ratio,
        expectedRatio=p['expectedRatio'], band=list(p['band']),
        whiteness=best, whitenessLag=bestL,
        skyPixels=int(np.count_nonzero(sky)),
        skyPixelsReduced=int(np.count_nonzero(sky2)),
        skyThreshold=med + p['skySigma'] * madn)
    rec['offered'] = bool(ratio >= p['band'][0])
    rec['applied'] = True
    return out, rec


def crop_detect(planes, params=None, apply_crop=False):
    """Detecta o objeto e SUGERE. Nunca aplica sem apply_crop."""
    from scipy.ndimage import label
    p = dict(cropSigma=2.5, cropWindow=25, cropDensity=0.50,
             cropMargin=0.08, cropMinFrame=0.20)
    p.update(params or {})
    rec = {'params': p}

    h, w = planes[0].shape
    rec['frameSize'] = [w, h]
    if len(planes) == 3:
        Y = (0.2126 * planes[0].astype(F64) + 0.7152 * planes[1].astype(F64)
             + 0.0722 * planes[2].astype(F64)).astype(F32)
    else:
        Y = planes[0]
    med, madn = madn_exact(Y)
    thr = med + p['cropSigma'] * madn
    sig = Y > thr
    rec['signalPixels'] = int(np.count_nonzero(sig))
    rec['signalThreshold'] = thr

    # a mascara do Modulo 2 lida ao contrario: extenso e o que ELA rejeita.
    # Janela RECORTADA na borda -- o denominador e quantos pixels foram
    # realmente olhados, senao objeto encostado na borda escapa.
    win = p['cropWindow']
    cnt = box_sum(sig.astype(F64), win)
    den = box_sum(np.ones_like(cnt), win)
    ext = sig & ((cnt / np.maximum(den, 1.0)) >= p['cropDensity'])
    rec['extendedPixels'] = int(np.count_nonzero(ext))

    lab, n = label(ext)               # 4-conectividade, o padrao
    rec['components'] = int(n)
    comps = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        if not ys.size:
            continue
        x0, x1 = int(xs.min()), int(xs.max())
        y0, y1 = int(ys.min()), int(ys.max())
        bw, bh = x1 - x0 + 1, y1 - y0 + 1
        comps.append(dict(rect=[x0, y0, bw, bh], pixels=int(ys.size),
                          boxFrac=(bw * bh) / float(w * h),        # detalhe 8
                          pixelFrac=ys.size / float(w * h)))
    comps.sort(key=lambda c: -c['boxFrac'])
    rec['componentList'] = comps[:8]
    big = [c for c in comps if c['boxFrac'] >= p['cropMinFrame']]
    rec['componentsAboveMin'] = len(big)

    rec['coverageGuard'] = dict(
        inForce=False, evaluable=False,
        reason=('not evaluable in this chain: an object covering most of the '
                'frame is what the background model fits and subtracts'))

    if len(big) == 0:
        rec.update(suggested=False, applied=False, rect=None, objectRect=None,
                   reason='no extended object large enough to be the subject')
        return planes, rec
    if len(big) > 1:
        rec.update(suggested=False, applied=False, rect=None, objectRect=None,
                   reason=(f'this frame has {len(big)} extended objects large '
                           'enough to be the subject, and choosing one of them '
                           'would be deciding the composition for you'))
        return planes, rec

    c = big[0]
    x0, y0, bw, bh = c['rect']
    m = p['cropMargin'] * max(w, h)
    x0 -= m; y0 -= m; bw += 2 * m; bh += 2 * m
    # razao do quadro original, EXPANDINDO o lado menor
    ar = w / float(h)
    if bw / bh < ar:
        nb = bh * ar
        x0 -= (nb - bw) / 2.0; bw = nb
    else:
        nb = bw / ar
        y0 -= (nb - bh) / 2.0; bh = nb
    x0, y0 = int(round(x0)), int(round(y0))
    bw, bh = int(round(bw)), int(round(bh))
    bw, bh = min(bw, w), min(bh, h)
    x0 = max(0, min(x0, w - bw))      # desliza para dentro, nao encolhe
    y0 = max(0, min(y0, h - bh))

    rec['rect'] = [x0, y0, bw, bh]
    rec['objectRect'] = c['rect']
    # detalhe 10: area de PIXELS, nao a caixa
    rec['coverageBefore'] = c['pixels'] / float(w * h)
    rec['coverageAfter'] = c['pixels'] / float(bw * bh)
    rec['suggested'] = True
    rec['reason'] = None

    if apply_crop:
        rec['applied'] = True
        out = [c2[y0:y0 + bh, x0:x0 + bw] for c2 in planes]
        return out, rec
    rec['applied'] = False
    return planes, rec


# ------------------------------------------- Modulo 5a: escala e recorte

def _sky_mask(Y, k=3.0):
    """Ceu escolhido UMA VEZ no quadro cheio."""
    m, s = madn_exact(np.asarray(Y, dtype=F32))
    return np.asarray(Y, dtype=F64) < m + k * s


def _sigma_lag(v, sky, lag, want_span=False):
    """1.4826 * mediana(|v[x+lag]-v[x]|) / sqrt(2), so na horizontal, e so
    em pares onde AMBOS sao ceu.

    Os dois pontos onde uma implementacao razoavel diverge em silencio:
    o MAD e tomado sobre ZERO (nao sobre a mediana das diferencas), e a
    divisao por sqrt(2) converte desvio-de-diferenca em desvio-de-pixel.
    """
    a = np.asarray(v, dtype=F64)
    d = np.abs(a[:, lag:] - a[:, :-lag])
    both = sky[:, lag:] & sky[:, :-lag]
    if not np.count_nonzero(both):
        return (0.0, 0, 0.0) if want_span else (0.0, 0)
    dd = d[both]
    sig = 1.4826 * med_exact(dd) / np.sqrt(2.0)
    n = int(np.count_nonzero(both))
    if not want_span:
        return sig, n
    # span da distribuicao de |d|, na mesma forma do span do MADN: e o que
    # a cota de uma estatistica de forma MAD precisa, e sem ele a cota teria
    # que ser escolhida.
    q1, q3 = float(np.percentile(dd, 25)), float(np.percentile(dd, 75))
    return sig, n, 3.0 * (q3 - q1)


def half_scale(planes, params=None):
    """Media de caixa 2x2 EXATA, sobre o float, antes do quantise."""
    p = dict(band=(1.8, 2.2), expectedRatio=2.0, skySigma=3.0)
    p.update(params or {})
    h, w = planes[0].shape
    w2, h2 = w >> 1, h >> 1
    rec = dict(applied=True, inputSize=[w, h], outputSize=[w2, h2],
               droppedRow=bool(h % 2), droppedColumn=bool(w % 2))

    Y = (0.2126 * planes[0].astype(F64) + 0.7152 * planes[1].astype(F64)
         + 0.0722 * planes[2].astype(F64)).astype(F32) if len(planes) == 3 \
        else planes[0].astype(F32)
    skyMed, skyMadn = madn_exact(Y)     # os numeros QUE ESTAO no limiar
    sky = np.asarray(Y, dtype=F64) < skyMed + p['skySigma'] * skyMadn

    out = []
    for c in planes:
        a = c.astype(F64)[:h2 * 2, :w2 * 2]
        # quatro termos, uma divisao -- e a aritmetica em que o log se apoia
        out.append((((a[0::2, 0::2] + a[0::2, 1::2]
                      + a[1::2, 0::2] + a[1::2, 1::2]) * 0.25).astype(F32)))

    Y2 = (0.2126 * out[0].astype(F64) + 0.7152 * out[1].astype(F64)
          + 0.0722 * out[2].astype(F64)).astype(F32) if len(out) == 3 \
        else out[0].astype(F32)
    s = sky[:h2 * 2, :w2 * 2]
    # um pixel reduzido e ceu sse os QUATRO de origem eram ceu
    sky2 = s[0::2, 0::2] & s[0::2, 1::2] & s[1::2, 0::2] & s[1::2, 1::2]

    sb, nb, spanB = _sigma_lag(Y, sky, 1, want_span=True)
    sa, na, spanA = _sigma_lag(Y2, sky2, 1, want_span=True)
    ratio = sb / sa if sa > 0 else 0.0

    # brancura: os lags vem do bloco 2x2, nao dos dados
    # Sem teto em 1,0: acima de 1 e anticorrelacao entre vizinhos, que
    # tambem e informacao. Limitar esconderia o caso.
    best, bestL = None, None
    for L in (2, 3, 4):
        sL, _ = _sigma_lag(Y, sky, L)
        if sL > 0:
            r = sb / sL
            if best is None or r < best:
                best, bestL = r, L

    rec['noise'] = dict(skyMedian=skyMed, skyMadn=skyMadn,
                        skyHighFreqBefore=sb, skyHighFreqAfter=sa, ratio=ratio,
                        skyHighFreqSpanBefore=spanB, skyHighFreqSpanAfter=spanA,
                        expectedRatio=p['expectedRatio'], band=list(p['band']),
                        whiteness=best, whitenessLag=bestL,
                        skyPixels=int(np.count_nonzero(sky)),
                        skyPixelsReduced=int(np.count_nonzero(sky2)),
                        samplesBefore=nb, samplesAfter=na)
    rec['offered'] = bool(ratio >= p['band'][0])
    return out, rec


def crop_detect(planes, params=None):
    """Detecta o objeto e SUGERE o retangulo. Nunca aplica sozinho."""
    from scipy.ndimage import label
    p = dict(cropSigma=2.5, cropWindow=25, cropDensity=0.50,
             cropMargin=0.08, cropMinFrame=0.20)
    p.update(params or {})
    h, w = planes[0].shape
    rec = dict(applied=False, suggested=False, reason=None, frameSize=[w, h])

    Y = (0.2126 * planes[0].astype(F64) + 0.7152 * planes[1].astype(F64)
         + 0.0722 * planes[2].astype(F64)).astype(F32) if len(planes) == 3 \
        else planes[0].astype(F32)
    m, s = madn_exact(Y)
    rec['skyMedian'], rec['skyMadn'] = m, s      # os numeros no limiar
    sig = np.asarray(Y, dtype=F64) > m + p['cropSigma'] * s
    rec['signalPixels'] = int(np.count_nonzero(sig))

    # A mascara de extenso e a do Modulo 2 lida ao contrario. Janela
    # RECORTADA na borda: com a janela nominal, objeto encostado na borda
    # escapa e a contagem de componentes diverge.
    wnd = p['cropWindow']
    cnt = box_sum(sig.astype(F64), wnd)
    win = box_sum(np.ones_like(cnt), wnd)
    occ = cnt / np.maximum(win, 1.0)
    ext = sig & (occ >= p['cropDensity'])
    rec['extendedPixels'] = int(np.count_nonzero(ext))
    rec['_occupancy'] = occ      # so para a curva de densidade
    rec['_signalMask'] = sig

    lab, n = label(ext)                       # 4-conectividade, o padrao
    rec['components'] = int(n)
    comps = []
    for i in range(1, n + 1):
        ys, xs = np.nonzero(lab == i)
        if not ys.size:
            continue
        x0, x1, y0, y1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
        bw, bh = x1 - x0 + 1, y1 - y0 + 1
        comps.append(dict(rect=[x0, y0, bw, bh], pixels=int(ys.size),
                          boxFrac=(bw * bh) / float(w * h),      # sobre a CAIXA
                          pixelFrac=ys.size / float(w * h)))
    comps.sort(key=lambda c: -c['boxFrac'])
    rec['componentList'] = comps
    big = [c for c in comps if c['boxFrac'] >= p['cropMinFrame']]
    rec['componentsAboveMin'] = len(big)

    rec['coverageGuard'] = dict(
        inForce=False, evaluable=False,
        objectBoxFrac=comps[0]['boxFrac'] if comps else 0.0,
        reason=('not evaluable in this chain: an object covering most of the '
                'frame is what the background model fits and subtracts. The '
                'guard is empty by construction, not missing a test case.'))

    if len(big) == 0:
        rec['reason'] = 'no extended object large enough to be the subject'
        rec['rect'] = rec['objectRect'] = None
        return rec
    if len(big) > 1:
        rec['reason'] = (f'this frame has {len(big)} extended objects large '
                         f'enough to be the subject, and choosing one of them '
                         f'would be deciding the composition for you')
        rec['rect'] = rec['objectRect'] = None
        return rec

    c = big[0]
    x0, y0, bw, bh = c['rect']
    rec['objectRect'] = [x0, y0, bw, bh]
    # margem nos quatro lados
    mg = p['cropMargin'] * max(w, h)
    x0 -= mg; y0 -= mg; bw += 2 * mg; bh += 2 * mg
    # razao do quadro original, EXPANDINDO o lado menor
    ar = w / float(h)
    if bw / bh < ar:
        nbw = bh * ar
        x0 -= (nbw - bw) / 2.0
        bw = nbw
    else:
        nbh = bw / ar
        y0 -= (nbh - bh) / 2.0
        bh = nbh
    x0, y0, bw, bh = (int(round(v)) for v in (x0, y0, bw, bh))
    bw, bh = min(bw, w), min(bh, h)
    # desliza para dentro; nao encolhe, porque encolher desfaria a razao
    x0 = max(0, min(x0, w - bw))
    y0 = max(0, min(y0, h - bh))
    rec['rect'] = [x0, y0, bw, bh]
    rec['suggested'] = True
    # cobertura sobre a AREA DE PIXELS do componente, nao sobre a caixa
    rec['coverageBefore'] = c['pixels'] / float(w * h)
    rec['coverageAfter'] = c['pixels'] / float(bw * bh)
    return rec
