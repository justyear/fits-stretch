# Gera docs/before-after.png. Gemeo de make-before-after.py, para esta maquina,
# que nao tem Python -- ver NOTAS-SESSAO-FITS.md, "Harness de teste".
#
#   powershell -File docs\make-before-after.ps1
#
# ASCII apenas -- ver o cabecalho de test\compare-golden.ps1.
#
# OS DOIS SCRIPTS TEM QUE PRODUZIR A MESMA IMAGEM. As constantes de geometria,
# cor, fonte e tamanho estao duplicadas nos dois de proposito -- e duplicacao, e
# a alternativa (um arquivo de config lido pelos dois) custaria mais do que
# resolve para dez numeros. O que impede a divergencia e a verificacao no fim:
# os dois imprimem as MESMAS tres medidas, e elas vem da imagem gerada, nao das
# constantes.
#
# O PAINEL DA DIREITA E O GOLDEN LIDO DO DISCO, sem reprocessar. Se ele fosse
# regerado por outra implementacao, a imagem e o log do README voltariam a ser
# de builds diferentes -- que e o defeito que este script existe para consertar.
#
# O PAINEL DA ESQUERDA e o dado linear quantizado direto: level = round(v*255).
# Sem esticamento, sem fundo, sem calibracao, sem saturacao, sem dither. E o que
# um visualizador comum mostra. Como este lado nao tem leitor de FITS fora do
# navegador, ele entra pronto em .claude\shots\before-panel-linear.png, gerado
# pela fonte publicada -- o snippet esta no fim deste arquivo.

param(
    [string]$Left  = '.claude\shots\before-panel-linear.png',
    [string]$Out   = 'docs\before-after.png'
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$root = Split-Path -Parent $PSScriptRoot

# ----------------------------------------------------------- geometria
#
# MEDIDA do composto original, nao escolhida. Onde a medicao discordou do
# make-before-after.py, o numero aqui e o do artefato e o .py foi corrigido:
#
#   fonte       Segoe UI 16px   (o .py dizia 13; a 13 o rotulo sai 16% curto)
#   cor         139,151,168     (o .py dizia 168,176,190; nenhum canal da
#                                imagem original passa de 139/151/168, e um
#                                pixel atinge os tres -- e cor de preenchimento
#                                atingida em cobertura total, nao um teto de
#                                antialiasing)
#   rotulo x    1 e 715         (o .py dizia 5 e 719)
#
# A fonte foi identificada pelas posicoes de inicio de palavra, que sao
# impressao digital das larguras de avanco: o original tem 31,70,96,113,133,
# 196,240 e Segoe UI 16px da 30,71,97,113,134,198,242 -- seis das sete dentro
# de 2 px ao longo de 284 px. Verdana e Arial erram desde a primeira.
$COMPOSITE_W = 1414; $COMPOSITE_H = 555
$PANEL_W = 700;      $PANEL_H = 525
$PANEL_Y = 30
$RIGHT_X = 714
$BG = [System.Drawing.Color]::FromArgb(11, 14, 19)
$LABEL_RGB = [System.Drawing.Color]::FromArgb(139, 151, 168)
$LABEL_L = 'The same file in an ordinary photo viewer'
$LABEL_R = 'The same file through this page'
$LABEL_L_INK_X = 1
$LABEL_R_INK_X = 715
$LABEL_INK_Y = 8
$FONT_FAMILY = 'Segoe UI'
$FONT_PX = 16

$leftPath  = Join-Path $root $Left
$rightPath = Join-Path $root 'test\golden\gradient-fixture.png'
$outPath   = Join-Path $root $Out

foreach ($p in @($leftPath, $rightPath)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "nao encontrei: $p" }
}

# --- reducao ---------------------------------------------------------
#
# 1600x1200 -> 700x525, fator 0,4375. O composto original nao registra o
# filtro. HighQualityBicubic e a escolha, e o teste sao as duas medianas
# impressas no fim: 4 no esquerdo e 21 no direito. Se elas nao sairem assim, o
# filtro e outro -- nao ajuste a expectativa, troque o filtro.
function Reduce([string]$path) {
    $src = New-Object System.Drawing.Bitmap($path)
    $dst = New-Object System.Drawing.Bitmap($PANEL_W, $PANEL_H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $PANEL_W, $PANEL_H)))
    $g.Dispose(); $src.Dispose()
    return $dst
}

$panelL = Reduce $leftPath
$panelR = Reduce $rightPath

$canvas = New-Object System.Drawing.Bitmap($COMPOSITE_W, $COMPOSITE_H, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($canvas)
$g.Clear($BG)
$g.DrawImageUnscaled($panelL, 0, $PANEL_Y)
$g.DrawImageUnscaled($panelR, $RIGHT_X, $PANEL_Y)
$panelL.Dispose(); $panelR.Dispose()

# --- rotulos ---------------------------------------------------------
#
# A posicao pedida e a da TINTA, nao a da origem do desenho: entre as duas ha o
# side bearing da fonte, que muda com o tamanho. Mede-se uma vez e desloca-se.
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$font = New-Object System.Drawing.Font($FONT_FAMILY, $FONT_PX, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$brush = New-Object System.Drawing.SolidBrush($LABEL_RGB)
$fmt = [System.Drawing.StringFormat]::GenericTypographic

function InkOffset([string]$txt) {
    $probe = New-Object System.Drawing.Bitmap(800, 64, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $pg = [System.Drawing.Graphics]::FromImage($probe)
    $pg.Clear($BG); $pg.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $pg.DrawString($txt, $font, $brush, (New-Object System.Drawing.PointF(20, 20)), $fmt)
    $pg.Flush()
    $minx = 9999; $miny = 9999
    for ($y = 0; $y -lt 64; $y++) { for ($x = 0; $x -lt 800; $x++) {
        $c = $probe.GetPixel($x, $y)
        if ($c.R -ne $BG.R -or $c.G -ne $BG.G -or $c.B -ne $BG.B) {
            if ($x -lt $minx) { $minx = $x }
            if ($y -lt $miny) { $miny = $y }
        } } }
    $pg.Dispose(); $probe.Dispose()
    return @{ dx = ($minx - 20); dy = ($miny - 20) }
}

$offL = InkOffset $LABEL_L
$offR = InkOffset $LABEL_R
$g.DrawString($LABEL_L, $font, $brush, (New-Object System.Drawing.PointF(($LABEL_L_INK_X - $offL.dx), ($LABEL_INK_Y - $offL.dy))), $fmt)
$g.DrawString($LABEL_R, $font, $brush, (New-Object System.Drawing.PointF(($LABEL_R_INK_X - $offR.dx), ($LABEL_INK_Y - $offR.dy))), $fmt)
$g.Flush()
$font.Dispose(); $brush.Dispose(); $g.Dispose()

if (Test-Path -LiteralPath $outPath) { Remove-Item -LiteralPath $outPath -Force }
$canvas.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)

# --- verificacao -----------------------------------------------------
#
# AS MESMAS TRES MEDIDAS QUE O .py IMPRIME, tiradas da imagem gerada e nao das
# constantes. E o unico mecanismo que impede os dois scripts de divergirem.
function PanelMedian($bmp, $x0, $x1) {
    $hist = New-Object 'int[]' 256; $n = 0; $mx = 0
    for ($y = $PANEL_Y; $y -lt $COMPOSITE_H; $y++) { for ($x = $x0; $x -le $x1; $x++) {
        $c = $bmp.GetPixel($x, $y)
        $l = [int][math]::Round(($c.R + $c.G + $c.B) / 3.0)
        $hist[$l]++; $n++
        if ($l -gt $mx) { $mx = $l }
    } }
    $acc = 0
    for ($i = 0; $i -lt 256; $i++) { $acc += $hist[$i]; if ($acc -ge $n / 2) { return @{ med = $i; max = $mx } } }
    return @{ med = 0; max = $mx }
}

$sl = PanelMedian $canvas 0 ($PANEL_W - 1)
$sr = PanelMedian $canvas $RIGHT_X ($COMPOSITE_W - 1)
$bgPix = $canvas.GetPixel(706, 0)

Write-Host ("escrito {0}  {1}x{2}" -f $outPath, $canvas.Width, $canvas.Height)
Write-Host ("  painel esquerdo: mediana {0}  max {1}   (esperado ~4 e ~100)" -f $sl.med, $sl.max)
Write-Host ("  painel direito : mediana {0}   (esperado ~21; o log diz 22 de 255, o downscale dilui 1)" -f $sr.med)
Write-Host ("  fundo do canvas: {0},{1},{2}   (esperado {3},{4},{5})" -f $bgPix.R, $bgPix.G, $bgPix.B, $BG.R, $BG.G, $BG.B)

$ok = ($sl.med -eq 4) -and ($sr.med -eq 21) -and ($bgPix.R -eq $BG.R -and $bgPix.G -eq $BG.G -and $bgPix.B -eq $BG.B)
$canvas.Dispose()
if (-not $ok) { Write-Host 'VERIFICACAO FALHOU - ver a nota sobre o filtro de reducao'; exit 1 }
Write-Host 'BEFORE-AFTER PASS'
exit 0

# ---------------------------------------------------------------------
# COMO REGERAR O PAINEL ESQUERDO (.claude\shots\before-panel-linear.png)
#
# Nao ha leitor de FITS fora do navegador nesta maquina, entao ele sai da fonte
# publicada, pelo mesmo shim que test\capture-golden.js usa. Com o servidor de
# pe em http://127.0.0.1:8791/test.html, no console:
#
#   var src = document.getElementById('pipeline-src').textContent;
#   var shim = { onmessage: null, postMessage: function(){} };
#   new Function('self', src + ';self.__P={findImageHDU:findImageHDU,' +
#     'toNormalisedFloat:toNormalisedFloat,flipRows:flipRows};')(shim);
#   var P = shim.__P;
#   var buf = await fetch('/f/test/fixtures/fixture-gradient.fit')
#               .then(function(r){ return r.arrayBuffer(); });
#   var hdu = P.findImageHDU(buf);
#   var d = P.toNormalisedFloat(buf, hdu, function(){});
#   var ro = (typeof hdu.map.ROWORDER === 'string')
#              ? hdu.map.ROWORDER.trim().toUpperCase() : null;
#   if (ro !== 'TOP-DOWN') P.flipRows(d.data, d.w, d.h, d.planes);
#   var N = d.w * d.h, px = new Uint8ClampedArray(N * 4);
#   for (var i = 0; i < N; i++){
#     px[4*i+0] = Math.round(d.data[i] * 255);
#     px[4*i+1] = Math.round(d.data[N + i] * 255);
#     px[4*i+2] = Math.round(d.data[2*N + i] * 255);
#     px[4*i+3] = 255;
#   }
#   var c = document.createElement('canvas'); c.width = d.w; c.height = d.h;
#   c.getContext('2d').putImageData(new ImageData(px, d.w, d.h), 0, 0);
#   var blob = await new Promise(function(res){ c.toBlob(res, 'image/png'); });
#   await fetch('/save/before-panel-linear.png',
#               { method: 'POST', body: await blob.arrayBuffer() });
#
# O fixture-gradient traz ROWORDER = TOP-DOWN, entao flipRows NAO roda nele.
# A linha esta ali porque a regra e a do decodificador e nao a deste fixture.
