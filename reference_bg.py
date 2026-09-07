#!/usr/bin/env python3
"""
Referencia independente do Modulo 1 -- extracao de fundo.

Duas coisas separadas aqui, e a distincao importa:

  (A) A VERDADE. O gradiente esta escrito nos cards HISTORY do fixture.
      E avaliado analiticamente, em float64. Nao veio de nenhuma das
      duas implementacoes -- e o unico eixo da suite que nao herda a
      formula compartilhada.

  (B) A SEGUNDA IMPLEMENTACAO. Amostragem, rejeicao, TPS e pedestal em
      numpy/scipy. Mesma formula de proposito; valida aritmetica.

O deliverable principal e (A): a superficie verdadeira avaliada numa
retícula fixa de pontos. Qualquer implementacao pode ser conferida
contra ela sem que as grades de amostragem precisem coincidir.
"""
import json
import numpy as np
from astropy.io import fits

# ------------------------------------------------------------ (A) verdade

def parse_truth(path):
    """Le os coeficientes do gradiente e a geometria do objeto do HISTORY."""
    with fits.open(path) as hl:
        hdu = next(h for h in hl if h.data is not None)
        hdr = hdu.header
        cards = [str(c) for c in hdr.get('HISTORY', [])]
        w, h = int(hdr['NAXIS1']), int(hdr['NAXIS2'])
        row_order = str(hdr.get('ROWORDER', '')).strip().upper()

    grad = {}
    obj = {}
    probes = []
    for c in cards:
        t = c.split()
        if t[:1] == ['GRADIENT'] and len(t) >= 3 and t[1] in ('R', 'G', 'B'):
            ch = t[1]
            grad.setdefault(ch, {})
            for kv in t[2:]:
                if '=' in kv:
                    k, v = kv.split('=', 1)
                    grad[ch][k] = float(v)
        elif t[:1] == ['OBJECT']:
            for kv in t[1:]:
                if '=' in kv and not kv.startswith('R/G/B'):
                    k, v = kv.split('=', 1)
                    try:
                        obj[k] = float(v)
                    except ValueError:
                        pass
            if 'tint R/G/B =' in c:
                seg = c.split('tint R/G/B =', 1)[1].split(',')[0].strip()
                obj['tint'] = [float(x) for x in seg.split('/')]
        elif t[:1] == ['PROBE'] and 'x,y:' in c:
            for pair in c.split('x,y:')[1].split():
                x, y = pair.split(',')
                probes.append((int(x), int(y)))
    return dict(w=w, h=h, rowOrder=row_order, gradient=grad,
                obj=obj, probes=probes)


def truth_surface(truth, ch, xs, ys):
    """g(u,v) = A0 + A1 u + A2 v + A3 u^2 + A4 v^2 + A5 u v, em float64.

    u = x/(NAXIS1-1), v = y/(NAXIS2-1). ROWORDER TOP-DOWN, entao v=0 e a
    primeira linha armazenada e o indice de linha do array e v direto.
    """
    a = truth['gradient'][ch]
    u = np.asarray(xs, dtype=np.float64) / (truth['w'] - 1)
    v = np.asarray(ys, dtype=np.float64) / (truth['h'] - 1)
    return (a['A0'] + a['A1'] * u + a['A2'] * v
            + a['A3'] * u * u + a['A4'] * v * v + a['A5'] * u * v)


def truth_object_mask(truth, xs, ys):
    """R <= 1 do objeto estendido -- a regiao onde o modelo DEVE errar."""
    o = truth['obj']
    dx = (np.asarray(xs, dtype=np.float64) - o['CX']) / o['A']
    dy = (np.asarray(ys, dtype=np.float64) - o['CY']) / o['B']
    return np.hypot(dx, dy) <= 1.0


# --------------------------------------------------- (B) segunda implementacao

def load_planes(path):
    with fits.open(path) as hl:
        hdu = next(h for h in hl if h.data is not None)
        hdr = hdu.header
        d = np.array(hdu.data).astype(np.float64)
        row_order = str(hdr.get('ROWORDER', '')).strip().upper()
        if row_order != 'TOP-DOWN':
            d = d[:, ::-1, :] if d.ndim == 3 else d[::-1, :]
    return [d[i] for i in range(d.shape[0])] if d.ndim == 3 else [d]


def madn_exact(v):
    m = float(np.median(v))
    return m, 1.4826 * float(np.median(np.abs(v - m)))


def sample_grid(planes, samples_per_row=12, box=25, edge_margin=0.02):
    """Grade regular; valor da amostra = mediana da caixa, por canal."""
    h, w = planes[0].shape
    ny = max(2, int(round(samples_per_row * h / w)))
    nx = samples_per_row
    half = box // 2
    margin = edge_margin * min(w, h)

    pts = []
    for j in range(ny):
        for i in range(nx):
            x = int(np.floor((i + 0.5) * w / nx + 0.5))   # meio para cima, como Math.round
            y = int(np.floor((j + 0.5) * h / ny + 0.5))   # meio para cima, como Math.round
            pts.append(dict(x=x, y=y))

    out = []
    for p in pts:
        x, y = p['x'], p['y']
        x0, x1 = x - half, x + half + 1
        y0, y1 = y - half, y + half + 1
        rec = dict(x=x, y=y, state='accepted', reason=None, medians=[])
        if (x0 < margin or y0 < margin
                or x1 > w - margin or y1 > h - margin):
            rec['state'] = 'rejected-edge'
            rec['reason'] = 'box crosses the edge margin'
        for pl in planes:
            b = pl[max(0, y0):min(h, y1), max(0, x0):min(w, x1)]
            rec['medians'].append(float(np.median(b)))
            if not np.all(np.isfinite(b)) and rec['state'] == 'accepted':
                rec['state'] = 'rejected-nan'
                rec['reason'] = 'box contains non-finite pixels'
        out.append(rec)
    return out


def reject_bright(samples, planes, tolerance=1.0):
    """Rejeicao contra o fundo GLOBAL, como a spec decidiu no passo 5."""
    thr = []
    for pl in planes:
        m, s = madn_exact(pl.ravel())
        thr.append(m + tolerance * s)
    for rec in samples:
        if rec['state'] != 'accepted':
            continue
        for c, med in enumerate(rec['medians']):
            if med > thr[c]:
                rec['state'] = 'rejected-bright'
                rec['reason'] = ('box median %.6f above global threshold %.6f'
                                 % (med, thr[c]))
                break
    return thr


def tps_fit(pts_xy, values, w, h, smoothing=0.10):
    """Thin-plate spline com termo afim.

    Duas correcoes que a implementacao JS encontrou e que sao necessarias:
      - lambda NAO pode escalar pela media da diagonal de A: para TPS
        phi(0)=0 por definicao, entao a diagonal e zero e lambda zeraria.
        Usa-se a media de |A[i][j]| fora da diagonal.
      - normalizacao ISOTROPICA: os dois eixos dividem pelo mesmo numero
        (o maior extent), senao um quadro 4:3 vira quadrado e o kernel,
        que e radial, fica 33 pct mais rigido num eixo.
    """
    P = np.asarray(pts_xy, dtype=np.float64)
    n = len(P)
    scale = float(max(w - 1, h - 1))
    Q = P / scale

    d = np.hypot(Q[:, None, 0] - Q[None, :, 0], Q[:, None, 1] - Q[None, :, 1])
    with np.errstate(divide='ignore', invalid='ignore'):
        A = np.where(d > 0, d * d * np.log(d), 0.0)

    off = ~np.eye(n, dtype=bool)
    mean_off = float(np.mean(np.abs(A[off]))) if n > 1 else 1.0
    lam = smoothing * mean_off

    M = np.zeros((n + 3, n + 3), dtype=np.float64)
    M[:n, :n] = A + lam * np.eye(n)
    M[:n, n] = 1.0
    M[:n, n + 1] = Q[:, 0]
    M[:n, n + 2] = Q[:, 1]
    M[n, :n] = 1.0
    M[n + 1, :n] = Q[:, 0]
    M[n + 2, :n] = Q[:, 1]

    rhs = np.zeros(n + 3, dtype=np.float64)
    rhs[:n] = np.asarray(values, dtype=np.float64)
    sol = np.linalg.solve(M, rhs)
    return dict(Q=Q, wts=sol[:n], aff=sol[n:], scale=scale, lam=lam,
                meanOff=mean_off)


def tps_eval(fit, xs, ys):
    Q, wts, aff, scale = fit['Q'], fit['wts'], fit['aff'], fit['scale']
    qx = np.asarray(xs, dtype=np.float64).ravel() / scale
    qy = np.asarray(ys, dtype=np.float64).ravel() / scale
    out = np.full(qx.shape, aff[0]) + aff[1] * qx + aff[2] * qy
    CHUNK = 200_000
    for s in range(0, qx.size, CHUNK):
        e = min(s + CHUNK, qx.size)
        d = np.hypot(qx[s:e, None] - Q[None, :, 0], qy[s:e, None] - Q[None, :, 1])
        with np.errstate(divide='ignore', invalid='ignore'):
            phi = np.where(d > 0, d * d * np.log(d), 0.0)
        out[s:e] += phi @ wts
    return out


def extract_background(planes, w, h, samples_per_row=12, box=25,
                       tolerance=1.0, edge_margin=0.02, smoothing=0.10,
                       grid_divisor=8):
    samples = sample_grid(planes, samples_per_row, box, edge_margin)
    thr = reject_bright(samples, planes, tolerance)
    acc = [s for s in samples if s['state'] == 'accepted']

    if len(acc) < 8:
        return dict(applied=False,
                    skipReason='only %d of %d samples survived rejection'
                               % (len(acc), len(samples)),
                    samples=samples)

    gx = np.linspace(0, w - 1, max(2, w // grid_divisor))
    gy = np.linspace(0, h - 1, max(2, h // grid_divisor))
    GX, GY = np.meshgrid(gx, gy)

    models, fits_, pedestals = [], [], []
    for c in range(len(planes)):
        fit = tps_fit([(s['x'], s['y']) for s in acc],
                      [s['medians'][c] for s in acc], w, h, smoothing)
        coarse = tps_eval(fit, GX, GY).reshape(GY.shape)
        # interpolacao bilinear para a resolucao cheia
        full = np.empty((h, w), dtype=np.float64)
        yi = np.interp(np.arange(h), gy, np.arange(len(gy)))
        xi = np.interp(np.arange(w), gx, np.arange(len(gx)))
        y0 = np.clip(np.floor(yi).astype(int), 0, len(gy) - 1)
        y1 = np.clip(y0 + 1, 0, len(gy) - 1)
        x0 = np.clip(np.floor(xi).astype(int), 0, len(gx) - 1)
        x1 = np.clip(x0 + 1, 0, len(gx) - 1)
        fy = (yi - y0)[:, None]
        fx = (xi - x0)[None, :]
        full = ((coarse[np.ix_(y0, x0)] * (1 - fx) + coarse[np.ix_(y0, x1)] * fx) * (1 - fy)
                + (coarse[np.ix_(y1, x0)] * (1 - fx) + coarse[np.ix_(y1, x1)] * fx) * fy)
        models.append(full)
        fits_.append(fit)
        pedestals.append(float(np.median(full)))

    corrected = [planes[c] - models[c] + pedestals[c] for c in range(len(planes))]
    return dict(applied=True, samples=samples, thresholds=thr,
                models=models, fits=fits_, pedestals=pedestals,
                corrected=corrected, accepted=len(acc))


# ------------------------------------------------------------------ relatorio

if __name__ == '__main__':
    PATH = '/mnt/user-data/uploads/fixture-gradient.fit'
    truth = parse_truth(PATH)
    planes = load_planes(PATH)
    h, w = planes[0].shape
    names = ['R', 'G', 'B']

    res = extract_background(planes, w, h)
    print('amostras: %d aceitas de %d' % (res['accepted'], len(res['samples'])))
    from collections import Counter
    print('estados:', dict(Counter(s['state'] for s in res['samples'])))
    print()

    Y, X = np.mgrid[0:h, 0:w]
    obj = truth_object_mask(truth, X, Y)
    print('%-3s %12s %12s %12s %12s' % ('ch', 'fora max', 'fora medio',
                                        'sob obj max', 'pedestal'))
    summary = {}
    for c, nm in enumerate(names):
        T = truth_surface(truth, nm, X, Y)
        err = np.abs(res['models'][c] - T) * 255.0
        summary[nm] = dict(
            outsideMax=float(err[~obj].max()), outsideMean=float(err[~obj].mean()),
            insideMax=float(err[obj].max()), insideMean=float(err[obj].mean()),
            pedestal=res['pedestals'][c],
            modelMin=float(res['models'][c].min()),
            modelMax=float(res['models'][c].max()),
            lam=res['fits'][c]['lam'],
        )
        print('%-3s %12.4f %12.4f %12.4f %12.6f'
              % (nm, summary[nm]['outsideMax'], summary[nm]['outsideMean'],
                 summary[nm]['insideMax'], summary[nm]['pedestal']))
    json.dump(dict(truth=truth, summary=summary),
              open('/home/claude/bg_summary.json', 'w'), indent=2, default=str)
