"""Cadeia completa: decode -> fundo -> calibracao de cor -> esticamento ligado."""
import json, hashlib, sys
import numpy as np
sys.path.insert(0, '.')
from reference_bg import extract_background
from reference_m23 import (colour_calibrate, linked_stretch, density_report,
                           saturate, threshold_density, sat_factor,
                           half_scale, crop_detect, madn_exact, _sky_mask, box_sum)
from chain import load

BASE = '/mnt/user-data/uploads/'
JOBS = [('fixture-seestar.fit','seestar'), ('fixture-rice_fit.fz','rice'),
        ('fixture-nonlinear.fit','nonlinear'), ('fixture-gradient.fit','gradient'),
        ('fixture-colour.fit','colour'), ('fixture-edge.fit','edge'),
        ('fixture-saturation.fit','saturation'), ('fixture-flatsky.fit','flatsky'),
        ('fixture-oneobject.fit','oneobject'), ('fixture-twoobjects.fit','twoobjects'),
        ('fixture-bigobject.fit','bigobject'),
        # mesma fonte, com o recorte APLICADO: o terceiro estado
        ('fixture-oneobject.fit','cropped')]
# So estes dois tem a etapa LIGADA. Emitir saturacao para os outros nao
# ajuda: os goldens deles sao a cadeia com os defaults, sem saturacao.
SAT_ON = {'saturation', 'flatsky'}

def clean(o):
    if isinstance(o, dict):
        return {k: clean(v) for k, v in o.items() if not k.startswith('_')}
    if isinstance(o, (list, tuple)): return [clean(x) for x in o]
    if isinstance(o, (np.floating, np.integer)): return o.item()
    if isinstance(o, np.ndarray): return None
    return o

out = {}
for fn, label in JOBS:
    planes, hist, norm = load(BASE + fn)
    h, w = planes[0].shape
    bg = extract_background(planes, w, h)
    pl = [p.astype(np.float32) for p in (bg['corrected'] if bg['applied'] else planes)]

    pl2, cc = colour_calibrate(pl)
    gmed = float(np.mean([float(np.median(c)) for c in pl2]))
    hits = [c for c in hist if any(k in c.lower() for k in ('stretch','histogram','asinh','curve','ght'))]
    nl = (gmed >= 0.05) or (len(hits) > 0 and gmed >= 0.02)
    res, st = linked_stretch(pl2, non_linear=nl)
    dens = density_report(pl, cc, pl2, st, res)

    sat = None
    if label in SAT_ON:
        satout, sat = saturate(res)
        Yv = (0.2126*res[0].astype(np.float64) + 0.7152*res[1].astype(np.float64)
              + 0.0722*res[2].astype(np.float64))
        b, nz = sat['mask']['background'], sat['mask']['noiseSigma']
        pr = sat['params']
        kk, _, _ = sat_factor(Yv, b, nz, pr)
        mxo = np.maximum(np.maximum(Yv+(res[0].astype(np.float64)-Yv)*kk,
                                    Yv+(res[1].astype(np.float64)-Yv)*kk),
                         Yv+(res[2].astype(np.float64)-Yv)*kk)
        dens['saturacao'] = dict(
            pixelsBelowSnrLow=dict(
                count=sat['mask']['pixelsBelowSnrLow'],
                threshold=b + pr['snrLow']*nz,
                density=threshold_density(Yv, b + pr['snrLow']*nz)),
            pixelsAtFullMask=dict(
                count=sat['mask']['pixelsAtFullMask'],
                threshold=b + pr['snrHigh']*nz,
                density=threshold_density(Yv, b + pr['snrHigh']*nz)),
            pixelsAtFullAmount=dict(
                count=sat['mask']['pixelsAtFullAmount'],
                threshold=pr['highlightKnee'],
                density=threshold_density(Yv, pr['highlightKnee'])),
            pixelsRescaled=dict(
                count=sat['overflow']['pixelsRescaled'], threshold=1.0,
                density=threshold_density(mxo, 1.0)),
            # As cinco fronteiras INTERIORES da tabela por faixa. A media de
            # uma faixa nao e uma contagem por limiar: pixels trocam nas duas
            # bordas em sentidos opostos e se cancelam na contagem liquida.
            # Por isso a cota conta as duas bordas, nao a diferenca de n.
            bordasDeFaixa=[dict(threshold=t, density=threshold_density(Yv, t))
                           for t in (0.10, 0.20, 0.35, 0.55, 0.80)])

    # ordem: saturacao -> recorte -> meia escala -> quantise
    cr = crop_detect(res) if len(res) == 3 else None
    base = res
    if label == 'cropped' and cr and cr['suggested']:
        x, y, cw, ch = cr['rect']          # o terceiro estado, com override
        base = [c[y:y+ch, x:x+cw] for c in res]
        cr = dict(cr, applied=True)
    _, hs = half_scale(base)

    Yc = (0.2126*res[0].astype(np.float64) + 0.7152*res[1].astype(np.float64)
          + 0.0722*res[2].astype(np.float64)).astype(np.float32) if len(res) == 3 else res[0]
    mY, sY = madn_exact(Yc)
    dens['recorte'] = dict(
        signalPixels=dict(count=cr['signalPixels'] if cr else 0,
                          threshold=mY + 2.5*sY,
                          density=threshold_density(Yc, mY + 2.5*sY)))
    if cr is not None and '_occupancy' in cr:
        # A cota de components e extendedPixels precisa das trocas no limiar
        # de OCUPACAO, nao so no de sinal. Delta aqui e adimensional.
        occ = cr['_occupancy'][cr['_signalMask']]
        dens['recorte']['extendedPixels'] = dict(
            count=cr['extendedPixels'], threshold=0.50,
            density=threshold_density(occ, 0.50,
                                      deltas=(1e-4, 1e-3, 4e-3, 1e-2, 4e-2)))
    dens['meiaEscala'] = dict(
        skyPixels=dict(count=hs['noise']['skyPixels'],
                       threshold=mY + 3.0*sY,
                       density=threshold_density(Yc, mY + 3.0*sY)))

    out[label] = dict(
        sha256=hashlib.sha256(open(BASE+fn,'rb').read()).hexdigest(),
        decode=dict(width=w, height=h, planes=len(planes)),
        fundo=dict(aplicado=bg['applied'], aceitas=bg.get('accepted')),
        calibracaoCor=clean(cc),
        esticamento=clean(st),
        saturacao=clean(sat) if sat else None,
        meiaEscala=clean(hs),
        recorte=clean(cr) if cr else None,
        densidadePorLimiar=clean(dens))
    st_extra = ('' if not sat else
                f"  sat {'aplica' if sat['applied'] else 'RECUSA'} "
                f"maxK {sat['mask']['maxK']:.3f} "
                f"croma {sat['chromaNoise']['growthPct']:+.3f}% "
                f"matiz {sat['hueFidelity']['maxHueDrift']:.1e}")
    g = cc.get('ganhos')
    print(f"{label:10} cc {str(cc['applied']):5} ganhos "
          f"{'-' if not g else ' '.join('%.4f'%x for x in g):26} "
          f"drift {st['colourFidelity']['maxRatioDrift'] if st.get('colourFidelity') else 0:.2e}"
          f"  clipLow {st['clipLow']}" + st_extra)

json.dump(dict(
  geradoPor='reference_m23.py + reference_bg.py -- segunda implementacao dos Modulos 2 e 3',
  cadeia=['decode','extracao de fundo','calibracao de cor','esticamento ligado'],
  nota=('as estatisticas do esticamento aqui sao mediana EXATA; a implementacao JS '
        'usa analysePlane (histograma de 65536 bins). A diferenca e conhecida, medida '
        'e coberta pela cota de densidade -- ver densidadePorLimiar.'),
  cotaDeContagem=('Delta e a discordancia da GRANDEZA comparada com o limiar e do '
                  'proprio limiar, nao a dos pixels do passo anterior. pixelsRescaled '
                  'compara max(R,G,B)*r, e r carrega midtones -- o Delta ali e '
                  'multiplicativo e tres ordens acima do por-pixel.'),
  cobertura=dict(porCanalAindaNA=['seestar'],
    motivo=('a referencia nao faz debayer: num mosaico ela mede o padrao '
            'Bayer, nao o quadro demosaicado')),
  fixtures=out), open('/home/claude/referencia-cadeia.json','w'), indent=2, ensure_ascii=False)
