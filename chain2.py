"""Cadeia completa: decode -> fundo -> calibracao de cor -> esticamento ligado."""
import json, hashlib, sys
import numpy as np
sys.path.insert(0, '.')
from reference_bg import extract_background
from reference_m23 import colour_calibrate, linked_stretch, density_report
from chain import load

BASE = '/mnt/user-data/uploads/'
JOBS = [('fixture-seestar.fit','seestar'), ('fixture-rice_fit.fz','rice'),
        ('fixture-nonlinear.fit','nonlinear'), ('fixture-gradient.fit','gradient'),
        ('fixture-colour.fit','colour'), ('fixture-edge.fit','edge')]

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

    out[label] = dict(
        sha256=hashlib.sha256(open(BASE+fn,'rb').read()).hexdigest(),
        decode=dict(width=w, height=h, planes=len(planes)),
        fundo=dict(aplicado=bg['applied'], aceitas=bg.get('accepted')),
        calibracaoCor=clean(cc),
        esticamento=clean(st),
        densidadePorLimiar=clean(dens))
    g = cc.get('ganhos')
    print(f"{label:10} cc {str(cc['applied']):5} ganhos "
          f"{'-' if not g else ' '.join('%.4f'%x for x in g):26} "
          f"drift {st['colourFidelity']['maxRatioDrift'] if st.get('colourFidelity') else 0:.2e}"
          f"  clipLow {st['clipLow']}")

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
