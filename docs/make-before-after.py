#!/usr/bin/env python3
"""
Gera docs/before-after.png.

RODE ESTE SCRIPT NA MAQUINA DO REPOSITORIO, nao em outro lugar.

O painel da direita e o golden `test/golden/gradient-fixture.png` lido do
disco, sem reprocessar. Se ele fosse regerado por outra implementacao, a
imagem e o log do README passariam a ser de builds diferentes -- que e
exatamente o defeito que este script existe para consertar.

O painel da esquerda e o dado linear quantizado direto: level = round(v*255).
Sem esticamento, sem extracao de fundo, sem calibracao, sem saturacao, sem
dither. E o que um visualizador comum mostra.

    python docs/make-before-after.py

Depende de: astropy, numpy, pillow.
Se a maquina nao tiver Python, o bloco no fim do arquivo tem a mesma
geometria descrita passo a passo para refazer a mao.
"""
import os
import sys
import numpy as np
from astropy.io import fits
from PIL import Image, ImageDraw, ImageFont

# ----------------------------------------------------------- geometria
COMPOSITE = (1414, 555)
PANEL = (700, 525)
PANEL_Y = 30
GUTTER_X = 700
GUTTER_W = 14
RIGHT_X = 714
BG = (11, 14, 19)                      # #0B0E13
LABEL_L = 'The same file in an ordinary photo viewer'
LABEL_R = 'The same file through this page'
LABEL_L_X = 0                          # origem do desenho; a tinta cai em x=1
LABEL_R_X = 714                        # idem, tinta em x=715
LABEL_BASELINE = 8                     # topo do texto; a faixa vai de y 0 a 29
LABEL_RGB = (139, 151, 168)            # MEDIDO no composto original
FONT_PX = 16                           # MEDIDO; ver a nota no fim
RESAMPLE = Image.LANCZOS               # ver a nota no fim

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FITS_IN = os.path.join(ROOT, 'test', 'fixtures', 'fixture-gradient.fit')
GOLDEN = os.path.join(ROOT, 'test', 'golden', 'gradient-fixture.png')
OUT = os.path.join(HERE, 'before-after.png')


def linear_panel(path):
    """O quadro como um visualizador comum o mostra: v*255, arredondado."""
    with fits.open(path) as hl:
        hdu = next(h for h in hl if h.data is not None)
        hdr = hdu.header
        d = np.array(hdu.data).astype(np.float64)
        row_order = str(hdr.get('ROWORDER', '')).strip().upper()
    # ROWORDER ausente = bottom-up (default FITS). TOP-DOWN nao vira.
    if row_order != 'TOP-DOWN':
        d = d[:, ::-1, :] if d.ndim == 3 else d[::-1, :]
    if d.ndim == 2:
        d = np.stack([d, d, d])
    a = np.clip(np.round(d * 255.0), 0, 255).astype(np.uint8)
    return Image.fromarray(np.transpose(a, (1, 2, 0)), 'RGB')


def pick_font(size=FONT_PX):
    """Sans do sistema. A lista cobre Windows, macOS e Linux."""
    for name in ('segoeui.ttf', 'Segoe UI.ttf', 'arial.ttf',
                 'DejaVuSans.ttf', 'Helvetica.ttc', 'LiberationSans-Regular.ttf'):
        try:
            return ImageFont.truetype(name, size)
        except Exception:
            pass
    for p in ('C:/Windows/Fonts/segoeui.ttf',
              '/System/Library/Fonts/Helvetica.ttc',
              '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'):
        try:
            return ImageFont.truetype(p, size)
        except Exception:
            pass
    print('AVISO: nenhuma fonte TrueType encontrada; usando a bitmap do PIL.',
          file=sys.stderr)
    return ImageFont.load_default()


def main():
    for p in (FITS_IN, GOLDEN):
        if not os.path.exists(p):
            print(f'ERRO: nao encontrei {p}', file=sys.stderr)
            return 1

    left = linear_panel(FITS_IN).resize(PANEL, RESAMPLE)
    right = Image.open(GOLDEN).convert('RGB').resize(PANEL, RESAMPLE)

    canvas = Image.new('RGB', COMPOSITE, BG)
    canvas.paste(left, (0, PANEL_Y))
    canvas.paste(right, (RIGHT_X, PANEL_Y))

    d = ImageDraw.Draw(canvas)
    f = pick_font(FONT_PX)
    d.text((LABEL_L_X, LABEL_BASELINE), LABEL_L, font=f, fill=LABEL_RGB)
    d.text((LABEL_R_X, LABEL_BASELINE), LABEL_R, font=f, fill=LABEL_RGB)

    canvas.save(OUT)

    # Verificacao, impressa para conferir contra os numeros do MANIFEST.
    a = np.array(canvas)
    lg = a[PANEL_Y:, 0:700].mean(2)
    rg = a[PANEL_Y:, RIGHT_X:].mean(2)
    print(f'escrito {OUT}  {canvas.size[0]}x{canvas.size[1]}')
    print(f'  painel esquerdo: mediana {np.median(lg):.0f}  max {lg.max():.0f}'
          f'   (esperado ~4 e ~100)')
    print(f'  painel direito : mediana {np.median(rg):.0f}'
          f'   (esperado ~21; o log diz 22 de 255, o downscale dilui 1)')
    print(f'  fundo do canvas: {tuple(a[0, 706])}   (esperado {BG})')
    return 0


if __name__ == '__main__':
    sys.exit(main())


# ---------------------------------------------------------------------
# Se precisar refazer a mao, sem Python:
#
#   composto        1414 x 555, fundo #0B0E13
#   painel esquerdo x 0..699,   y 30..554   (700 x 525, 4:3)
#   gutter          x 700..713  (14 px, mesma cor do fundo)
#   painel direito  x 714..1413, y 30..554
#   faixa de rotulo y 0..29, texto comecando em y=8
#   rotulo esq.     x=5    "The same file in an ordinary photo viewer"
#   rotulo dir.     x=719  "The same file through this page"
#   cor do texto    #A8B0BE
#
# Os dois paineis vem de 1600x1200 reduzidos por 0,4375.
#
# NOTA SOBRE O FILTRO DE REDUCAO: o composto original nao registra qual
# filtro usou. LANCZOS e a escolha aqui. Se a mediana do painel esquerdo
# nao sair 4 ou a do direito nao sair 21, troque por Image.BOX (media de
# area) e confira de novo -- as duas medianas sao o teste.
#
# FONTE E COR: MEDIDOS NO ARTEFATO, e os tres valores originais deste arquivo
# estavam errados. A medicao esta em docs/make-before-after.ps1, que e o gemeo
# que roda nesta maquina (sem Python).
#
#   tamanho  16px, nao 13. A 13 o rotulo sai 16% curto: Segoe UI 13px da 238 px
#            de largura e o original tem 284. A razao 284/238 x 13 = 15,5 bate
#            com a do rotulo da direita, 217/182 x 13 = 15,5 -- duas medidas
#            independentes no mesmo numero.
#   cor      #8B97A8 (139,151,168), nao (168,176,190). Nenhum canal da imagem
#            original passa de 139/151/168 em lugar nenhum da faixa do rotulo, e
#            um pixel atinge os tres ao mesmo tempo: isso e cor de preenchimento
#            alcancada em cobertura total, nao um teto de antialiasing.
#   x        a tinta comeca em 1 e 715, nao 5 e 719. Com a origem do desenho na
#            borda do painel (0 e 714) e o side bearing do 'T', a tinta cai
#            exatamente ali.
#
# A FAMILIA foi identificada pelas posicoes de inicio de palavra, que sao
# impressao digital das larguras de avanco e discriminam muito melhor que a
# largura total:
#
#   original      31, 70, 96, 113, 133, 196, 240
#   Segoe UI 16   30, 71, 97, 113, 134, 198, 242   <- seis das sete dentro de 2px
#   Verdana 14    20, 33, 41, 49, 62, 75, ...      <- erra desde a primeira
#   Arial 16      19, 32, 40, 49, 62, 74, ...      <- idem
#
# Residuo conhecido, e nao vale perseguir: renderizado por GDI+ o rotulo sai 3px
# mais largo (287 contra 284) e 2px mais alto (16 contra 14). FreeType e GDI+
# nao rasterizam igual, entao identidade exata nao esta disponivel por este
# caminho. Se o PIL sair mais proximo, melhor -- as tres medidas do fim do
# script sao o que decide se a imagem esta certa, nao o rotulo.
