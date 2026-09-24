#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
medicao_escritores.py -- entrada sintetica e leitura das saidas da medicao de
escritores: o que cada programa grava no header. Protocolo: medicao-escritores.md.

  python medicao_escritores.py gera PASTA   escreve entrada.fit, entrada-limpa.fit e entrada.json
  python medicao_escritores.py le   PASTA   le as saidas, compara cada uma com a sua referencia,
                                      escreve relatorio-medicao.txt e relatorio-medicao.json

So numpy e astropy. Nenhum dado de terceiro: os pixels nascem aqui, com semente
fixa, e os valores das chaves de escritor se anunciam sinteticos.

O que este arquivo NAO decide: nenhum limiar. Ele imprime as contas (1 - r2,
razao contra o controle negativo, contagens) e aplica so as regras de sim/nao
pre-registradas no protocolo: linha nova existe ou nao, casa no catalogo ou nao,
pixel identico ou nao.
"""
import hashlib
import json
import os
import re
import sys

import numpy as np
from astropy.io import fits

# ---------------------------------------------------------------- geracao --

SEMENTE = 20260923
LARG, ALT = 512, 384            # NAXIS1, NAXIS2 ; NAXIS3 = 3 (RGB)
BP_CONTROLE = 0.0010            # o -BP= do linstretch no script: tem que ficar ABAIXO do minimo


def sintetiza():
    """Quadro linear por construcao: valor = fundo afim + fluxo + ruido cuja
    variancia e afim no sinal (leitura + fotons). Nada e cortado: o maximo fica
    abaixo de 1 e o minimo acima de 1,5 x BP_CONTROLE (conferido em gera())."""
    rs = np.random.RandomState(SEMENTE)   # RandomState: fluxo congelado (NEP 19)
    yy, xx = np.mgrid[0:ALT, 0:LARG].astype(np.float64)
    u, v = xx / (LARG - 1.0), yy / (ALT - 1.0)

    fundo = (0.0042, 0.0050, 0.0038)      # dominante de cor, como pilha OSC antes da calibracao
    grad_x = (0.0012, 0.0008, 0.0005)     # gradiente: algo para o GraXpert extrair
    grad_y = (0.0004, 0.0003, 0.0006)
    sinal = np.empty((3, ALT, LARG))
    for c in range(3):
        sinal[c] = fundo[c] + grad_x[c] * u + grad_y[c] * v

    # objeto extenso: nucleo + halo, elipse inclinada, cor de emissao
    cx, cy, a, b, th = 0.58 * LARG, 0.46 * ALT, 70.0, 38.0, np.deg2rad(28.0)
    dx, dy = xx - cx, yy - cy
    xr = dx * np.cos(th) + dy * np.sin(th)
    yr = -dx * np.sin(th) + dy * np.cos(th)
    r2 = (xr / a) ** 2 + (yr / b) ** 2
    perfil = 0.020 * np.exp(-2.0 * r2) + 0.012 * np.exp(-0.5 * r2)
    for c, k in enumerate((1.00, 0.55, 0.70)):
        sinal[c] += k * perfil

    # estrelas: gaussianas, pico log-uniforme, leve variacao de cor
    n, sig, raio = 160, 1.4, 7
    ex = rs.uniform(raio + 1, LARG - raio - 1, n)
    ey = rs.uniform(raio + 1, ALT - raio - 1, n)
    pico = np.exp(rs.uniform(np.log(0.004), np.log(0.80), n))
    temp = rs.uniform(-1.0, 1.0, n)
    for i in range(n):
        x0, y0 = int(round(ex[i])), int(round(ey[i]))
        ys, xs = slice(y0 - raio, y0 + raio + 1), slice(x0 - raio, x0 + raio + 1)
        g = np.exp(-0.5 * ((xx[ys, xs] - ex[i]) ** 2 + (yy[ys, xs] - ey[i]) ** 2) / sig ** 2)
        for c, m in enumerate((1 + 0.15 * temp[i], 1.0, 1 - 0.15 * temp[i])):
            sinal[c, ys, xs] += pico[i] * m * g

    leitura, k_foton = 1.5e-4, 2.0e-6
    img = sinal + rs.standard_normal(sinal.shape) * np.sqrt(leitura ** 2 + k_foton * sinal)
    return img.astype(np.float32)


def sha256(caminho):
    h = hashlib.sha256()
    with open(caminho, 'rb') as f:
        for bloco in iter(lambda: f.read(1 << 20), b''):
            h.update(bloco)
    return h.hexdigest()


def stats_canal(d):
    med = float(np.median(d))
    return {'min': float(d.min()), 'max': float(d.max()), 'mediana': med,
            'madn': float(1.4826 * np.median(np.abs(d - med)))}


def gera(pasta):
    os.makedirs(pasta, exist_ok=True)
    img = sintetiza()
    if not (img.max() < 1.0 and img.min() > 1.5 * BP_CONTROLE):
        sys.exit('entrada fora da faixa prometida: min %.6g max %.6g' % (img.min(), img.max()))

    arquivos = {}
    for nome, com_chaves in (('entrada.fit', True), ('entrada-limpa.fit', False)):
        hdu = fits.PrimaryHDU(img)
        h = hdu.header
        if com_chaves:
            # Valores que se anunciam sinteticos e NAO imitam nenhum programa real:
            # servem para ver o que o Siril preserva, sobrescreve ou remove.
            h['SWCREATE'] = ('justyear-sintetico 0 (captura ficticia)', 'valor sintetico')
            h['CREATOR'] = ('justyear-sintetico 0 (dispositivo ficticio)', 'valor sintetico')
            h['PROGRAM'] = ('justyear-sintetico 0 (programa ficticio)', 'valor sintetico')
            h['SWMODIFY'] = ('justyear-sintetico 0 (modificador ficticio)', 'valor sintetico')
            h['DATAMAX'] = (float(img.max()), 'maximo real desta entrada')
            h.add_history('justyear: entrada sintetica da medicao de escritores, sem processamento')
            h.add_comment('justyear: semente %d, gerada por medicao_escritores.py' % SEMENTE)
        caminho = os.path.join(pasta, nome)
        hdu.writeto(caminho, overwrite=True)
        arquivos[nome] = sha256(caminho)

    reg = {'semente': SEMENTE, 'naxis': [LARG, ALT, 3], 'bitpix': -32,
           'bp_controle': BP_CONTROLE, 'sha256': arquivos,
           'por_canal': [stats_canal(img[c]) for c in range(3)]}
    with open(os.path.join(pasta, 'entrada.json'), 'w', encoding='utf-8') as f:
        json.dump(reg, f, indent=2)
    print('ok: entrada.fit e entrada-limpa.fit em %s' % pasta)
    print('    min %.6f  max %.6f  (BP do controle negativo: %.4f)' % (img.min(), img.max(), BP_CONTROLE))
    for nome, s in arquivos.items():
        print('    %-18s sha256 %s' % (nome, s[:16]))


# ---------------------------------------------------------------- leitura --

EXT = ('.fit', '.fits', '.fts')

# LISTA DE PERMISSAO DE NOMES. So se abre arquivo cujo nome esta na tabela do
# protocolo. Um arquivo de parceiro esquecido na pasta nao e lido, e o relatorio
# conta quantos ficaram de fora sem nomear nenhum.
NOME_VALIDO = re.compile(r'^(entrada|entrada-limpa|[sgc]\d\d[a-z]?(-[a-z0-9]+)+)$', re.I)

# prefixo da saida -> prefixo da referencia. A primeira regra que casa vence,
# entao as mais especificas vem antes. Ver a tabela de nomes no protocolo.
REFERENCIA = [
    ('s00b', 'entrada-limpa'),
    ('s00', 'entrada'),
    ('c00', 'entrada'),
    ('c03', 'c01'),
    ('c0', 's00-base'),
    ('s', 's00-base'),
    ('g', 's00-base'),
]
TONAIS = ('s01', 's02', 's03', 's04', 's05', 's06', 's07', 's08', 's09', 's10', 's11',
          'g01', 'g02', 'g03', 'g04', 'g05', 'g06', 'g07', 'g08', 'g09')
CONTROLES = ('s20', 's21', 'g20')       # o catalogo nao pode casar em nenhum
CONTROLE_AFIM = ('s20', 'g20')          # exatamente afins: a base da razao de 1 - r2

# COPIA de STRETCH_HISTORY (src/pipeline/run.js), mesma ordem e mesma regra de
# laco: UM ROTULO POR LINHA -- cada linha recebe o rotulo da primeira regra que
# casa nela -- e os rotulos saem na ordem da tabela, sem repetir. Se a tabela
# mudar la, mude aqui; o teste de verdade continua sendo o da suite, rodando a
# ferramenta nos fixtures.
#
# Copiada depois da parte A (Siril 1.4.4, 2026-09-24): entrou `GHS asinh`, a
# regra de GHS passou a reconhecer `AutoGHS` e a recusar `GHS BP shift`, e a
# ultima entrada deixou de rotular `modasinh` como `Autostretch`.
CATALOGO = [
    (r'autostretch', 'Autostretch'),
    (r'histogram\s*transf', 'Histogram Transf.'),
    (r'GHS asinh', 'Modified asinh'),
    (r'asinh', 'Asinh stretch'),
    (r'generalised hyperbolic|generalized hyperbolic|\b(?:auto)?GHS\b(?!\s+BP shift)', 'GHS'),
    (r'midtone', 'Midtones transfer'),
    (r'\bcurves?\b', 'Curves'),
    (r'modasinh', 'Modified asinh'),
]
CATALOGO = [(re.compile(p, re.I), rot) for p, rot in CATALOGO]

ESTRUTURAIS = {'SIMPLE', 'BITPIX', 'NAXIS', 'NAXIS1', 'NAXIS2', 'NAXIS3', 'EXTEND',
               'BZERO', 'BSCALE', 'END', ''}
ESCRITOR = ('PROGRAM', 'CREATOR', 'SWCREATE', 'SWMODIFY', 'PRODUCER', 'SOFTWARE', 'ORIGIN')
PARECE_ESCRITOR = re.compile(r'SOFT|PROG|CREAT|MODIF|ORIGIN|WRIT|APP', re.I)
PARECE_CAMINHO = re.compile(r'[A-Za-z]:[\\/]|\\\\|(?:/[^/\s]+){2,}|~/|'
                            r'\.(?:fits?|fts|cr2|cr3|nef|arw|raf|dng|tiff?|xisf)\b', re.I)


def casa_catalogo(linhas):
    vistos = set()
    for l in linhas:
        for rx, rot in CATALOGO:
            if rx.search(l):
                vistos.add(rot)
                break                       # um rotulo por linha
    rotulos = []
    for _, rot in CATALOGO:                 # na ordem da tabela, sem repetir
        if rot in vistos and rot not in rotulos:
            rotulos.append(rot)
    return rotulos


def le_arquivo(caminho):
    """A imagem e a primeira HDU com dados de 2 ou 3 eixos (um escritor pode
    deixar a primaria vazia, ou pendurar outra HDU depois). Os cartoes sao os da
    primaria seguidos dos da HDU da imagem, quando forem HDUs diferentes."""
    with fits.open(caminho, memmap=False) as f:
        n_hdu = len(f)
        idx = next((i for i, u in enumerate(f)
                    if u.data is not None and getattr(u.data, 'ndim', 0) in (2, 3)), 0)
        h = f[idx].header
        dados = f[idx].data
        cartoes = [(c.keyword, c.value) for c in f[0].header.cards]
        if idx != 0:
            cartoes += [(c.keyword, c.value) for c in h.cards]
        estrut = {k: h.get(k) for k in ('BITPIX', 'NAXIS', 'NAXIS1', 'NAXIS2', 'NAXIS3', 'BZERO', 'BSCALE')}
        estrut['HDU_IMAGEM'] = idx
    d = None
    if dados is not None:
        d = np.asarray(dados, dtype=np.float64)        # astropy ja aplicou BZERO/BSCALE
        if d.ndim == 2:
            d = d[np.newaxis]
    return {'cartoes': cartoes, 'estrut': estrut, 'dados': d, 'n_hdu': n_hdu,
            'sha256': sha256(caminho)}


def historico(cartoes, chave):
    return [(i, str(v)) for i, (k, v) in enumerate(cartoes) if k == chave]


def chaves(cartoes):
    out = {}
    for k, v in cartoes:
        if k in ESTRUTURAIS or k in ('HISTORY', 'COMMENT'):
            continue
        out.setdefault(k, []).append(v)
    return out


def novas(linhas, linhas_ref):
    """Linhas desta saida que a referencia nao tem (contando repeticoes)."""
    resto = list(linhas_ref)
    out = []
    for l in linhas:
        if l in resto:
            resto.remove(l)
        else:
            out.append(l)
    return out


def postos(a):
    ordem = np.argsort(a, kind='mergesort')
    r = np.empty(len(a))
    r[ordem] = np.arange(len(a), dtype=np.float64)
    _, inv, cont = np.unique(a, return_inverse=True, return_counts=True)
    return (np.bincount(inv, weights=r) / cont)[inv]


def spearman(a, b):
    ra, rb = postos(a), postos(b)
    ra -= ra.mean()
    rb -= rb.mean()
    den = np.sqrt((ra * ra).sum() * (rb * rb).sum())
    return float((ra * rb).sum() / den) if den > 0 else float('nan')


ORIENTACOES = {
    'identidade': lambda d: d,
    'espelho vertical': lambda d: d[:, ::-1, :],
    'espelho horizontal': lambda d: d[:, :, ::-1],
    'rotacao 180': lambda d: d[:, ::-1, ::-1],
}


def relacao(out, ref):
    """Mede a relacao pixel a pixel entre a saida e a referencia. Tudo aqui e
    invariante a ganho e offset nos dois lados: 1 - r2 e zero para qualquer
    transformacao afim e cresce com a curvatura; rho de Spearman e 1 para
    qualquer curva monotona ponto a ponto e cai para operacoes locais."""
    if out is None or ref is None or out.shape != ref.shape:
        return {'erro': 'geometria diferente: %s contra %s' % (
            None if out is None else out.shape, None if ref is None else ref.shape)}
    amostra = np.random.RandomState(1).choice(out[0].size, min(20000, out[0].size), replace=False)
    melhor, rho_melhor = None, -2.0
    for nome, f in ORIENTACOES.items():
        rho = spearman(f(ref)[0].ravel()[amostra], out[0].ravel()[amostra])
        if rho > rho_melhor:
            melhor, rho_melhor = nome, rho
    ref = ORIENTACOES[melhor](ref)
    canais = []
    for c in range(out.shape[0]):
        x, y = ref[c].ravel(), out[c].ravel()
        xm, ym = x - x.mean(), y - y.mean()
        vx, vy = (xm * xm).mean(), (ym * ym).mean()
        cov = (xm * ym).mean()
        r2 = cov * cov / (vx * vy) if vx > 0 and vy > 0 else float('nan')
        a = cov / vx if vx > 0 else float('nan')
        canais.append({
            'um_menos_r2': float(1.0 - r2) if r2 == r2 else float('nan'),
            'rho': spearman(x[amostra], y[amostra]),
            'ganho': float(a), 'offset': float(y.mean() - a * x.mean()),
            'max_abs_dif': float(np.abs(y - x).max()),
        })
    return {'orientacao': melhor, 'canais': canais,
            'identico': all(ch['max_abs_dif'] == 0.0 for ch in canais)}


def prefixo(nome):
    return nome.split('-')[0]


def le(pasta):
    todos = sorted(n for n in os.listdir(pasta) if n.lower().endswith(EXT))
    nomes = [n for n in todos if NOME_VALIDO.match(os.path.splitext(n)[0])]
    fora = len(todos) - len(nomes)
    base = {os.path.splitext(n)[0]: n for n in nomes}
    if 'entrada' not in base:
        sys.exit('nao achei entrada.fit em %s -- rode "gera" primeiro' % pasta)
    lidos = {stem: le_arquivo(os.path.join(pasta, n)) for stem, n in base.items()}

    def ref_de(stem):
        for pfx, alvo in REFERENCIA:
            if stem.startswith(pfx):
                if alvo in lidos:
                    return alvo
                achados = [s for s in lidos if s.startswith(alvo + '-') or s == alvo]
                return achados[0] if achados else None
        return None

    rel = {}
    for stem in sorted(lidos):
        if stem in ('entrada', 'entrada-limpa'):
            continue
        a = lidos[stem]
        rstem = ref_de(stem)
        r = lidos.get(rstem) if rstem else None
        hist = [l for _, l in historico(a['cartoes'], 'HISTORY')]
        hist_ref = [l for _, l in historico(r['cartoes'], 'HISTORY')] if r else []
        com = [l for _, l in historico(a['cartoes'], 'COMMENT')]
        com_ref = [l for _, l in historico(r['cartoes'], 'COMMENT')] if r else []
        k, kr = chaves(a['cartoes']), (chaves(r['cartoes']) if r else {})
        dif = {'novas': {}, 'removidas': {}, 'mudadas': {}}
        for nome in k:
            if nome not in kr:
                dif['novas'][nome] = k[nome]
            elif k[nome] != kr[nome]:
                dif['mudadas'][nome] = {'antes': kr[nome], 'depois': k[nome]}
        for nome in kr:
            if nome not in k:
                dif['removidas'][nome] = kr[nome]
        h_novas = novas(hist, hist_ref)
        h_removidas = novas(hist_ref, hist)
        suspeitas = [l for l in h_novas + novas(com, com_ref) if PARECE_CAMINHO.search(l)]
        for nome, vals in dif['novas'].items():
            suspeitas += ['%s = %s' % (nome, v) for v in vals
                          if isinstance(v, str) and PARECE_CAMINHO.search(v)]
        d = a['dados']
        canais = []
        if d is not None:
            for c in range(d.shape[0]):
                ch = d[c]
                rc = r['dados'][c] if (r is not None and r['dados'] is not None
                                       and r['dados'].shape == d.shape) else None
                canais.append({'min': float(ch.min()), 'max': float(ch.max()),
                               'mediana': float(np.median(ch)),
                               'n_no_min': int((ch == ch.min()).sum()),
                               'n_no_max': int((ch == ch.max()).sum()),
                               'n_no_min_ref': None if rc is None else int((rc == rc.min()).sum()),
                               'n_no_max_ref': None if rc is None else int((rc == rc.max()).sum())})
        datamax = None
        if 'DATAMAX' in k and d is not None and r is not None and r['dados'] is not None:
            dm = k['DATAMAX'][-1]
            try:
                dm = float(dm)
                datamax = {'valor': dm, 'max_real': float(d.max()),
                           'max_da_referencia': float(r['dados'].max()),
                           'desatualizado': bool(dm == np.float64(np.float32(r['dados'].max()))
                                                 and float(d.max()) != float(r['dados'].max()))}
            except (TypeError, ValueError):
                datamax = {'valor': dm, 'erro': 'nao numerico'}
        rel[stem] = {
            'arquivo': base[stem], 'sha256': a['sha256'], 'referencia': rstem,
            'n_hdu': a['n_hdu'], 'estrut': a['estrut'],
            'escritor': {c: k.get(c) for c in ESCRITOR if c in k},
            'escritor_outras': {c: v for c, v in dif['novas'].items()
                                if c not in ESCRITOR and PARECE_ESCRITOR.search(c)},
            'history': hist, 'history_novas': h_novas, 'history_removidas': h_removidas,
            'comment_novas': novas(com, com_ref), 'comment_removidas': novas(com_ref, com),
            'catalogo_todas': casa_catalogo(hist), 'catalogo_novas': casa_catalogo(h_novas),
            'chaves': dif, 'suspeitas_de_caminho': suspeitas, 'canais': canais,
            'datamax': datamax,
            'relacao': relacao(d, r['dados'] if r else None) if r else {'erro': 'sem referencia'},
        }

    # razao contra o controle negativo (a conta feita, nao os dois lados)
    ctrl = [max(ch['um_menos_r2'] for ch in rel[s]['relacao']['canais'])
            for s in rel if prefixo(s) in CONTROLE_AFIM and 'canais' in rel[s]['relacao']]
    n_ctrl = max(ctrl) if ctrl else None
    for s in rel:
        cs = rel[s]['relacao'].get('canais')
        if cs:
            n = max(ch['um_menos_r2'] for ch in cs)
            rel[s]['relacao']['um_menos_r2_max'] = n
            rel[s]['relacao']['razao_contra_controle'] = (n / n_ctrl) if n_ctrl else None

    # newline='\n': sem ele o Windows grava CRLF e o Linux LF, e o mesmo relatorio
    # sai com bytes -- e sha256 -- diferentes conforme o sistema. Medido: a copia
    # da parte A, gravada no Windows, tinha 273 CR.
    with open(os.path.join(pasta, 'relatorio-medicao.json'), 'w', encoding='utf-8', newline='\n') as f:
        json.dump({'controle_um_menos_r2': n_ctrl, 'saidas': rel}, f, indent=1, default=str)
    texto = relatorio(rel, n_ctrl, lidos, fora)
    with open(os.path.join(pasta, 'relatorio-medicao.txt'), 'w', encoding='utf-8', newline='\n') as f:
        f.write(texto)
    sys.stdout.write(texto.encode('ascii', 'replace').decode('ascii') + '\n')


def veredito(s, r):
    rl = r['relacao']
    papel = 'controle' if prefixo(s) in CONTROLES else 'tonal' if prefixo(s) in TONAIS else 'info'
    if 'erro' in rl:
        return 'SEM MEDICAO (%s)' % rl['erro']
    if rl['identico']:
        return 'INVALIDA: pixels identicos a referencia, a operacao nao rodou'
    if papel == 'controle':
        if r['catalogo_novas']:
            return 'CONTROLE FALHOU: o catalogo casa (%s)' % ', '.join(r['catalogo_novas'])
        return 'CONTROLE OK: nenhuma entrada casa'
    if papel == 'info':
        return 'informativo'
    if not r['history_novas']:
        return 'MUDA: mudou os pixels e nao escreveu HISTORY'
    if r['catalogo_novas']:
        return 'DECLARADA E RECONHECIDA: ' + ', '.join(r['catalogo_novas'])
    return 'DECLARADA, CATALOGO NAO RECONHECE'


def papel(s):
    p = prefixo(s)
    if p in ('s00', 's00b'):
        return 'base'
    if p in CONTROLES:
        return 'controle'
    if p in TONAIS:
        return 'tonal'
    if p.startswith('c'):
        return 'cadeia'
    return 'info'


def resumo(s, r):
    pp, rl = papel(s), r['relacao']
    if pp in ('tonal', 'controle'):
        return veredito(s, r)
    if 'erro' in rl:
        return 'SEM MEDICAO (%s)' % rl['erro']
    if pp == 'base':
        return 'BASE: pixels %s' % ('identicos a entrada' if rl['identico'] else 'MUDARAM')
    if pp == 'cadeia':
        return 'CADEIA: PROGRAM %s ; HISTORY +%d -%d ; catalogo %s' % (
            r['escritor'].get('PROGRAM', '(ausente)'), len(r['history_novas']),
            len(r['history_removidas']), r['catalogo_novas'] or 'nada')
    return 'informativo' + (': pixels identicos' if rl['identico'] else '')


def relatorio(rel, n_ctrl, lidos, fora=0):
    L = []
    L.append('relatorio-medicao.txt -- medicao_escritores.py (medicao-escritores.md)')
    L.append('')
    if fora:
        L.append('!! %d arquivo(s) FITS na pasta fora da tabela de nomes: NAO foram abertos.' % fora)
        L.append('')
    L.append('entrada.fit        sha256 %s' % lidos['entrada']['sha256'][:16])
    if 'entrada-limpa' in lidos:
        L.append('entrada-limpa.fit  sha256 %s' % lidos['entrada-limpa']['sha256'][:16])
    escritores = sorted({str(r['escritor'].get('PROGRAM')) for s, r in rel.items()
                         if papel(s) in ('base', 'tonal', 'controle')})
    L.append('PROGRAM nas saidas do Siril: %s' % ', '.join(escritores))
    L.append('controle afim, 1 - r2 (maior canal): %s' % (
        '%.3g' % n_ctrl if n_ctrl is not None else '(nao medido)'))
    L.append('')
    L.append('=== RESUMO ===')
    L.append('%-28s %-6s %-6s %-9s %-9s %s' % ('saida', 'BITPIX', 'novas', '1-r2', 'x ctrl', 'veredito'))
    for s in sorted(rel):
        r = rel[s]
        rl = r['relacao']
        n, x = rl.get('um_menos_r2_max'), rl.get('razao_contra_controle')
        L.append('%-28s %-6s %-6d %-9s %-9s %s' % (
            s[:28], r['estrut'].get('BITPIX'), len(r['history_novas']),
            '%.3g' % n if n is not None else '-', '%.3g' % x if x is not None else '-',
            resumo(s, r)))
    L.append('')

    L.append('=== REGRAS PRE-REGISTRADAS ===')
    medidas = sorted(s for s in rel if papel(s) == 'tonal')
    vs = {s: veredito(s, rel[s]) for s in medidas}
    mudas = [s for s in medidas if vs[s].startswith('MUDA')]
    invalidas = [s for s in medidas if vs[s].startswith(('INVALIDA', 'SEM'))]
    nao_rec = [s for s in medidas if vs[s].startswith('DECLARADA, CATALOGO')]
    declaradas = [s for s in medidas if vs[s].startswith('DECLARADA')]
    faltam = [p for p in TONAIS if not any(prefixo(s) == p for s in rel)]
    L.append('1. Cobertura da declaracao (secao 3.1 da investigacao), por operacao:')
    L.append('   %d de %d operacoes tonais medidas deixaram linha de HISTORY.' % (
        len(declaradas), len(medidas) - len(invalidas)))
    L.append('   mudas: %s' % (', '.join(mudas) or 'nenhuma'))
    L.append('   declaradas que o catalogo nao reconhece: %s' % (', '.join(nao_rec) or 'nenhuma'))
    if invalidas:
        L.append('   INVALIDAS, refazer: %s' % ', '.join(invalidas))
    L.append('   autoridade estrita do silencio: %s' % (
        'NAO (ha operacao muda)' if mudas else
        'INDECIDIDA (ha medicao invalida)' if invalidas else
        'SIM para as operacoes medidas'))
    if faltam:
        L.append('   nao medidas (nada se conclui sobre elas): %s' % ', '.join(faltam))
    L.append('2. Controles (preservam a classe; nenhuma entrada do catalogo pode casar):')
    for s in sorted(x for x in rel if papel(x) == 'controle'):
        r = rel[s]
        clip = ['%d (ref %s)' % (c['n_no_min'], c['n_no_min_ref']) for c in r['canais']]
        L.append('   %s: %s ; pixels no minimo por canal: %s' % (s, veredito(s, r), ', '.join(clip)))
    L.append('3. Cadeias (o ultimo escritor se identifica?):')
    cadeias = sorted(x for x in rel if papel(x) == 'cadeia')
    if not cadeias:
        L.append('   (nenhuma cadeia medida)')
    for s in cadeias:
        r = rel[s]
        ref = rel.get(r['referencia'], {}).get('escritor', {}) if r['referencia'] in rel else \
            {c: v for c, v in chaves(lidos[r['referencia']]['cartoes']).items() if c in ESCRITOR} \
            if r['referencia'] in lidos else {}
        L.append('   %s <- %s' % (s, r['referencia']))
        L.append('      escritor antes %s ; depois %s' % (ref or '{}', r['escritor'] or '{}'))
        L.append('      outras chaves novas com cara de escritor: %s' % (r['escritor_outras'] or 'nenhuma'))
        L.append('      HISTORY novas %d, removidas %d ; catalogo nas novas: %s ; 1-r2 %s' % (
            len(r['history_novas']), len(r['history_removidas']), r['catalogo_novas'] or 'nada',
            '%.3g' % r['relacao']['um_menos_r2_max'] if r['relacao'].get('um_menos_r2_max') is not None else '-'))
    L.append('')

    L.append('=== POR SAIDA ===')
    for s in sorted(rel):
        r = rel[s]
        e = r['estrut']
        L.append('')
        L.append('--- %s  (referencia: %s ; papel: %s)' % (r['arquivo'], r['referencia'], papel(s)))
        L.append('sha256 %s ; HDUs %d (imagem na %s) ; BITPIX %s BZERO %s BSCALE %s ; NAXIS %s x %s x %s' % (
            r['sha256'][:16], r['n_hdu'], e.get('HDU_IMAGEM'), e.get('BITPIX'), e.get('BZERO'),
            e.get('BSCALE'), e.get('NAXIS1'), e.get('NAXIS2'), e.get('NAXIS3')))
        L.append('escritor: %s' % (r['escritor'] or '(nenhuma das chaves conhecidas)'))
        if r['escritor_outras']:
            L.append('outras chaves novas com cara de escritor: %s' % r['escritor_outras'])
        L.append('HISTORY novas (%d), em ordem:' % len(r['history_novas']))
        for l in r['history_novas']:
            L.append('    ' + l + ('    <- 72 caracteres: cartao cheio, texto pode continuar no seguinte'
                                   if len(l) >= 72 else ''))
        if r['history_removidas']:
            L.append('HISTORY da referencia que SUMIRAM (%d):' % len(r['history_removidas']))
            for l in r['history_removidas']:
                L.append('    ' + l)
        if r['comment_novas']:
            L.append('COMMENT novas (%d):' % len(r['comment_novas']))
            for l in r['comment_novas']:
                L.append('    ' + l)
        if r['comment_removidas']:
            L.append('COMMENT da referencia que SUMIRAM (%d):' % len(r['comment_removidas']))
            for l in r['comment_removidas']:
                L.append('    ' + l)
        L.append('catalogo: linhas novas -> %s ; todas as linhas -> %s' % (
            r['catalogo_novas'] or 'nenhum', r['catalogo_todas'] or 'nenhum'))
        ch = r['chaves']
        for rot in ('novas', 'mudadas', 'removidas'):
            if ch[rot]:
                L.append('chaves %s: %s' % (rot, ch[rot]))
        if r['datamax']:
            L.append('DATAMAX: %s' % r['datamax'])
        for i, c in enumerate(r['canais']):
            L.append('canal %d: min %.6g max %.6g mediana %.6g ; pixels no min %d (ref %s) ; no max %d (ref %s)' % (
                i, c['min'], c['max'], c['mediana'], c['n_no_min'], c['n_no_min_ref'],
                c['n_no_max'], c['n_no_max_ref']))
        rl = r['relacao']
        if 'erro' in rl:
            L.append('relacao: %s' % rl['erro'])
        else:
            L.append('relacao com a referencia: orientacao %s ; identico %s' % (rl['orientacao'], rl['identico']))
            for i, c in enumerate(rl['canais']):
                L.append('   canal %d: 1-r2 %.3g ; rho %.6f ; ganho %.6g offset %.6g ; max|dif| %.3g' % (
                    i, c['um_menos_r2'], c['rho'], c['ganho'], c['offset'], c['max_abs_dif']))
        if r['suspeitas_de_caminho']:
            L.append('!! %d linha(s) nova(s) parecem trazer caminho ou nome de arquivo -- '
                     'revise antes de levar ao repositorio:' % len(r['suspeitas_de_caminho']))
            for l in r['suspeitas_de_caminho']:
                L.append('!!   ' + l)
    L.append('')
    return '\n'.join(L)


if __name__ == '__main__':
    if len(sys.argv) != 3 or sys.argv[1] not in ('gera', 'le'):
        sys.exit(__doc__)
    (gera if sys.argv[1] == 'gera' else le)(sys.argv[2])
