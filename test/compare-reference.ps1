# Compares the captured records against the independent Python implementation.
#
#   powershell -File test\compare-reference.ps1
#   powershell -File test\compare-reference.ps1 -Verbose:$false -Only rice
#
# This is the other half of the harness. compare-golden.ps1 proves the output
# has not changed; this proves the numbers agree with something that is not this
# code. The two answer different questions and neither replaces the other.
#
# What is independent about the reference: language, FITS reader, Rice
# decompression, precision (float64 vs float32), statistics (exact over every
# pixel vs a 65536-bin histogram) and the transfer (MTF evaluated directly vs a
# 2^20 LUT. What is NOT: the formula, which was read from this repository. A
# mistake in the autostretch formula is invisible to both.
#
# ---------------------------------------------------------------------------
# Tolerance - see modulo-0-spec.md section 7
#
#   value on the [0,1] axis:  |a-b| <= max(1e-4*|ref|, 4/65535)
#   mad and madn:             |a-b| <= max(1e-4*|ref|, 8*span/65535
#                                             + 1.4826*|dMediana|)
#   pixel counts:             0.05% of the frame
#
# The median term is a BOUND, not a fitted constant: MAD(m) = mediana(|v-m|),
# and ||v-m-d| - |v-m|| <= |d| for every v by the triangle inequality, so the
# bound passes through the median because the median is monotone. It is needed
# because the median is judged in bins of [0,1] and the MAD in bins of `span`,
# and after background extraction `span` shrinks 2.5-5x - so the MAD is judged
# on a fine scale while carrying uncertainty inherited from a coarse one.
#
# The floors are the resolution of the instrument, not slack. A flat 1e-4
# relative would fail 14 of 24 values of a correct implementation, because one
# histogram bin is already 9e-4 relative at a median of 0.017. And mad/madn do
# not live on [0,1] at all - they come out of the adaptive second histogram,
# whose bin is span/65535, so a [0,1] floor would be hundreds of times too
# loose for them.

param(
    [string]   $Reference = 'justyear-referencia.json',
    [string[]] $Only,
    [switch]   $Quiet,
    [switch]   $Csv,
    # Diretorio de goldens. Existe para que os controles negativos possam apontar
    # o comparador para copias descartaveis em vez de mexer nos goldens reais.
    [string]   $Golden
)

$ErrorActionPreference = 'Stop'
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$root = Split-Path -Parent $PSScriptRoot
$gold = if ($Golden) { $Golden } else { Join-Path $PSScriptRoot 'golden' }
$refPath = if ([System.IO.Path]::IsPathRooted($Reference)) { $Reference } else { Join-Path $root $Reference }

if (-not (Test-Path -LiteralPath $refPath)) {
    Write-Host "no reference at $refPath"
    Write-Host "generate it with the Python implementation, or pass -Reference <path>"
    exit 2
}

$BINS = 65535.0
$ref = Get-Content -LiteralPath $refPath -Raw | ConvertFrom-Json

# Fixture name in test/golden -> key under fixtures{} in the reference, and the
# file both sides measured. The file is checked by hash before anything else:
# regenerating a fixture without regenerating the reference would leave two sets
# of numbers describing two different images, agreeing or disagreeing for no
# reason anyone could read off the output.
$MAP = [ordered]@{
    'seestar-fixture'   = @{ key = 'seestar';   file = 'test\fixtures\fixture-seestar.fit' }
    'rice-fixture'      = @{ key = 'rice';      file = 'test\fixtures\fixture-rice.fit.fz' }
    'nonlinear-fixture' = @{ key = 'nonlinear'; file = 'test\fixtures\fixture-nonlinear.fit' }
}

# Differences that are understood and are NOT regressions. An entry needs a
# written reason and the module that resolves it; anything without one is a
# failure, not an exception. This list is debt, not an escape hatch: if it
# grows, the harness has stopped meaning anything.
#
# Empty, and it should stay that way. The one entry it ever held was the
# SUBTRACTIVE_DITHER_2 zero sentinel, closed in favour of this implementation
# once the reserved integer was read straight out of the .fz by a third tool.
$KNOWN = @()

# The reference measures fixture-seestar as the CFA mosaic, before debayer,
# because the Python side never implemented the demosaic. Our records describe
# the frame after it. The per-channel numbers are therefore measurements of two
# different images and comparing them would be meaningless; the decode block
# still is comparable, and is compared.
$MOSAIC_ONLY = @('seestar-fixture')

# The steps reference.py implements. A step that runs here and is missing from
# this list makes the per-channel comparison meaningless, and the comparator
# says so once instead of failing every number. Add an id here only when the
# reference actually models it.
#
# 'quantise' is listed because the reference stops at the float chain and never
# measures the 8-bit output, so nothing in the per-channel block depends on it.
$REFERENCE_MODELS = @('stretch-mtf', 'quantise')

function Get-Known($fixture, $field) {
    foreach ($k in $KNOWN) { if ($k.fixture -eq $fixture -and $k.field -eq $field) { return $k } }
    return $null
}

function New-Row($fixture, $scope, $field, $mine, $refv, $verdict, $detail) {
    return [pscustomobject]@{
        fixture = $fixture.Replace('-fixture', ''); escopo = $scope; campo = $field
        nosso = $mine; referencia = $refv; resultado = $verdict; detalhe = $detail
    }
}

# kind: 'unit' for anything on the [0,1] axis, 'mad' for mad/madn, 'count' for
# pixel counts, 'exact' for integers and strings that must match outright.
#
# $medianDelta only matters for kind 'mad'. It is the difference between the two
# sides' medians of the same channel, and it enters the floor as
# 1.4826*|dMediana| because MAD is measured RELATIVE to the median:
# MAD(m) = mediana(|v-m|), and ||v-m-d| - |v-m|| <= |d| for every v by the
# triangle inequality, so the bound passes through the median, which is
# monotone. It is a bound, not a fitted constant - see section 7.
$CH3 = @('R', 'G', 'B')

<#
CONTAGEM POR LIMIAR: A TOLERANCIA E DERIVADA, NAO ESCOLHIDA.

A regra "inteiro contado e exato" vale para contagem sobre OS MESMOS pixels.
Estas nao sao: cada lado resolve o proprio RBF, mede as proprias estatisticas, e
compara uma grandeza contra um limiar. Um pixel troca de lado quando `q - T`
troca de sinal, e as duas pontas mexem nos dois termos -- logo

    tolerancia = #{ i : |q_i - T| <= Delta_q + Delta_T }

que e exatamente a curva `densidadePorLimiar` que a referencia emite. Nao ha
constante ajustada aqui: o Delta entra medido e a cota sai da curva.

DELTA E POR CONTAGEM, NUNCA UM SO. Medido: a selecao estelar tem Delta ~1e-6
(as duas usam mediana exata); o clipLow tem ~6e-6 (nosso limiar vem do
histograma de 65536 bins e o deles da mediana exata); o pixelsRescaled tem
Delta MULTIPLICATIVO atraves de `r`, tres ordens acima do por-pixel. Um Delta
unico para as quatro reprova uma e afrouxa as outras.

A REGRA SE APERTA SOZINHA, e e por isso que ela e melhor que uma excecao por
nome: onde o limiar cai numa regiao vazia a densidade e zero, a tolerancia e
zero, e a contagem TEM que ser exata -- por calculo, nao por afirmacao. O
clipHigh e o pixelsRescaled sao esse caso em alguns fixtures e nao em outros, e
uma lista de nomes teria errado nos dois sentidos.

Cota medida, nao provada. O pior caso analitico e ~36,6*Delta_q, porque a MADN
entra no limiar multiplicada por 12; medido em tres formatos de perturbacao a
MADN se move ~Delta_q/100 e um deslocamento constante nao a move nada, entao
Delta_T <= Delta_q. Escrever 36,6 seria uma tolerancia que desliga o
instrumento. Se o Delta_T reportado passar de Delta_q, isso e achado.
#>
function Compare-Threshold-Count($fixture, $scope, $field, $mine, $refv, $delta, $curve) {
    $m = [int]$mine; $r = [int]$refv
    $diff = [math]::Abs($m - $r)

    if (-not $curve -or -not $curve.density) {
        return New-Row $fixture $scope $field $m $r 'N/A' `
               'a referencia nao emitiu densidadePorLimiar para este limiar'
    }

    # A curva e tabelada; le-se o primeiro ponto >= Delta, que e conservador por
    # construcao. Abaixo do primeiro ponto a cota e a densidade dele -- nunca
    # extrapolada para baixo, porque extrapolar uma cota para baixo e inventa-la.
    $pts = @()
    foreach ($p in $curve.density.PSObject.Properties) {
        $pts += [pscustomobject]@{ d = [double]$p.Name; n = [int]$p.Value }
    }
    $pts = $pts | Sort-Object d
    $cota = $pts[-1].n
    foreach ($p in $pts) { if ($p.d -ge $delta) { $cota = $p.n; break } }

    $ok = ($diff -le $cota)
    $verdict = if ($ok) { if ($diff -eq 0) { 'PASS' } else { 'PASS~' } } else { 'FAIL' }
    $detail = ("difere {0}, cota {1} pixels a menos de {2} do limiar" -f `
               $diff, $cota, $delta.ToString('0.0e+00', [cultureinfo]::InvariantCulture))
    if ($cota -eq 0 -and $ok) { $detail = 'densidade zero no limiar: exata por calculo' }
    return New-Row $fixture $scope $field $m $r $verdict $detail
}

<#
RAZAO DE DUAS DIFERENCAS PEQUENAS: A TOLERANCIA VEM DAS ENTRADAS, AMPLIFICADA.

Os ganhos e as razoes estelares sao `above_a / above_b`, e `above` e uma
diferenca de dois numeros muito maiores que ela -- mediana estelar menos
pedestal, 0.0279 saindo de 0.0447 menos 0.0168.

Comparar o quociente com a tolerancia do eixo [0,1] ignora o Jacobiano.
d(a/b)/(a/b) = da/a + db/b, e com `above` perto de 0.028 o fator 1/above vale
36x: uma diferenca de 1.14 bins em `above` -- que PASSA na propria linha dela --
vira 33 bins no ganho, e a linha do ganho reprova descrevendo a mesma
discordancia que a linha de cima acabou de aprovar.

Medido no gradient: `R acimaDoPedestal` passa em 1.14 de 4.00 bins, e `R ganho`
reprovava em 32.77 de 6.64. Uma discordancia, duas linhas, vereditos opostos.

A tolerancia aqui e a das ENTRADAS propagada pela formula -- nao um numero
escolhido para caber, e nao a tolerancia do eixo aplicada a um quociente que
nao mora nele. Se a entrada estourar a tolerancia dela, a linha da entrada
reprova, que e onde a causa esta.
#>
function Compare-Ratio($fixture, $scope, $field, $mine, $refv, $numRef, $denRef) {
    $known = Get-Known $fixture $field
    $m = [double]$mine; $r = [double]$refv
    $diff = [math]::Abs($m - $r)

    $rel = 0.0
    foreach ($v in @([math]::Abs([double]$numRef), [math]::Abs([double]$denRef))) {
        if ($v -gt 0) { $rel += [math]::Max(1e-4 * $v, 4.0 / 65535.0) / $v }
    }
    $lim = [math]::Abs($r) * $rel

    $ok = ($diff -le $lim)
    $verdict = if ($ok) { if ($diff -eq 0) { 'PASS' } else { 'PASS~' } } elseif ($known) { 'KNOWN' } else { 'FAIL' }
    $detail = if ($known -and -not $ok) { $known.reason } else {
        ("{0:0.00} de {1:0.00} bins - tolerancia das entradas propagada (1/above = {2:0.0}x)" -f `
         ($diff * 65535), ($lim * 65535), (1.0 / [math]::Max([double]$denRef, 1e-12)))
    }
    return New-Row $fixture $scope $field $m $r $verdict $detail
}

function Compare-Value($fixture, $scope, $field, $mine, $refv, $kind, $span, $total, $medianDelta = 0) {
    $known = Get-Known $fixture $field

    if ($kind -eq 'exact') {
        $ok = ("$mine" -eq "$refv")
        $verdict = if ($ok) { 'PASS' } elseif ($known) { 'KNOWN' } else { 'FAIL' }
        $detail = if ($ok) { 'igual' } elseif ($known) { $known.reason } else { 'difere' }
        return New-Row $fixture $scope $field $mine $refv $verdict $detail
    }

    $m = [double]$mine; $r = [double]$refv
    $diff = [math]::Abs($m - $r)

    if ($kind -eq 'mad') {
        if ($span -le 0) { $span = 1.0 / $BINS }
        $unit = $span / $BINS
        $floor = 8.0 * $unit + 1.4826 * [math]::Abs([double]$medianDelta)
        $label = 'bins de span'
    } elseif ($kind -eq 'count') {
        $unit = 1.0
        $floor = 0.0005 * $total
        $label = 'pixels'
    } else {
        $unit = 1.0 / $BINS
        $floor = 4.0 * $unit
        $label = 'bins'
    }

    $tol = [math]::Max(1e-4 * [math]::Abs($r), $floor)
    $ok = ($diff -le $tol)
    $bins = if ($unit -gt 0) { $diff / $unit } else { 0 }

    $verdict = if ($ok) { 'PASS' } elseif ($known) { 'KNOWN' } else { 'FAIL' }
    $detail = ('{0:F2} {1} / limite {2:F2}' -f $bins, $label, ($tol / $unit))
    if (-not $ok -and $known) { $detail = $known.reason }

    return New-Row $fixture $scope $field ('{0:G9}' -f $m) ('{0:G9}' -f $r) $verdict $detail
}

$rows = @()

function Get-Sha256([string]$path) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return -join ($sha.ComputeHash([System.IO.File]::ReadAllBytes($path)) | ForEach-Object { $_.ToString('x2') }) }
    finally { $sha.Dispose() }
}

foreach ($fixture in $MAP.Keys) {
    if ($Only -and ($Only -notcontains $fixture) -and ($Only -notcontains $fixture.Replace('-fixture',''))) { continue }

    $key = $MAP[$fixture].key
    $rf = $ref.fixtures.$key
    if (-not $rf) { $rows += New-Row $fixture 'fixture' '-' '-' '-' 'NO REF' "sem $key na referencia"; continue }

    # --- the two sides must be talking about the same file ---------------
    $fxPath = Join-Path $root $MAP[$fixture].file
    if (-not (Test-Path -LiteralPath $fxPath)) {
        $rows += New-Row $fixture 'fixture' 'sha256' 'ausente' $rf.sha256 'FAIL' `
                 "fixture nao encontrado: $($MAP[$fixture].file) - rode .claude\make-fixture.ps1"
        continue
    }
    $fxBytes = (Get-Item -LiteralPath $fxPath).Length
    $fxHash  = Get-Sha256 $fxPath
    if ($fxHash -ne "$($rf.sha256)" -or $fxBytes -ne [int64]$rf.bytes) {
        $rows += New-Row $fixture 'fixture' 'sha256' $fxHash.Substring(0,16) "$($rf.sha256)".Substring(0,16) 'FAIL' `
                 'fixture mudou desde a referencia - regere a referencia ou restaure o fixture'
        continue
    }
    $rows += New-Row $fixture 'fixture' 'sha256' $fxHash.Substring(0,16) "$($rf.sha256)".Substring(0,16) 'PASS' `
             ("mesmo arquivo, {0:N0} bytes" -f $fxBytes)

    $diagPath = Join-Path $gold "$fixture.diag.json"
    $recPath  = Join-Path $gold "$fixture.records.json"
    if (-not (Test-Path -LiteralPath $diagPath) -or -not (Test-Path -LiteralPath $recPath)) {
        $rows += New-Row $fixture 'fixture' '-' '-' '-' 'NO GOLDEN' 'capture-golden.js primeiro'
        continue
    }
    $diag = Get-Content -LiteralPath $diagPath -Raw | ConvertFrom-Json
    $records = Get-Content -LiteralPath $recPath -Raw | ConvertFrom-Json

    # --- decode ---------------------------------------------------------
    $d = $diag.decoded
    $rd = $rf.decode
    $rows += Compare-Value $fixture 'decode' 'decode.width'   $d.width   $rd.width   'exact' 0 0
    $rows += Compare-Value $fixture 'decode' 'decode.height'  $d.height  $rd.height  'exact' 0 0
    $rows += Compare-Value $fixture 'decode' 'decode.planes'  $d.planes  $rd.planes  'exact' 0 0
    $rows += Compare-Value $fixture 'decode' 'decode.bitpix'  $d.bitpix  $rd.bitpix  'exact' 0 0
    $rows += Compare-Value $fixture 'decode' 'decode.scaleMode' $d.scaleMode $rd.scaleMode 'exact' 0 0
    $rows += Compare-Value $fixture 'decode' 'decode.flipApplied' $diag.rowOrder.flipApplied ("$($rd.flipApplied)" -eq 'True') 'exact' 0 0
    $rows += Compare-Value $fixture 'decode' 'decode.rawMin'  $d.rawMin  $rd.rawMin  'unit' 0 0
    $rows += Compare-Value $fixture 'decode' 'decode.rawMax'  $d.rawMax  $rd.rawMax  'unit' 0 0
    $rows += Compare-Value $fixture 'decode' 'decode.normMin' $d.normMin $rd.normMin 'unit' 0 0
    $rows += Compare-Value $fixture 'decode' 'decode.normMax' $d.normMax $rd.normMax 'unit' 0 0

    if ($MOSAIC_ONLY -contains $fixture) {
        $rows += New-Row $fixture 'canais' '(todos)' '-' '-' 'N/A' `
                 'referencia mede o mosaico CFA, antes do debayer - imagens diferentes'
        continue
    }

    # --- does the reference still describe this pipeline? ----------------
    #
    # reference.py models the decode and the autostretch. When the chain runs a
    # step it does not model, every per-channel number is a comparison between
    # two different images, and reporting that as sixty-odd numeric FAILs
    # describes the symptom instead of the fact.
    #
    # One fact, said once: the reference is behind the pipeline. The decode
    # block above still compares, because the decode is what both still share.
    #
    # This is N/A and not KNOWN on purpose. The KNOWN list is for divergences
    # the two implementations have while describing the same thing; this is the
    # two no longer describing the same thing. Filling KNOWN with sixty entries
    # would turn a debt register into wallpaper - see section 7 of
    # modulo-0-spec.md, "KNOWN nao e uma saida de emergencia".
    $unmodelled = @()
    foreach ($rec in $records) {
        if ($rec.applied -and ($REFERENCE_MODELS -notcontains $rec.id)) { $unmodelled += $rec.id }
    }
    if ($unmodelled.Count -gt 0) {
        $rows += New-Row $fixture 'canais' '(todos)' '-' '-' 'N/A' `
                 ("reference.py nao modela " + ($unmodelled -join ', ') + " - coberto pelo bloco 'cadeia' abaixo")
        continue
    }

    # --- linearity ------------------------------------------------------
    $rows += Compare-Value $fixture 'linearidade' 'globalMedian' $diag.linearity.globalMedian $rf.globalMedian 'unit' 0 0
    $mineNonLinear = ($diag.linearity.verdict -like 'NON-LINEAR*')
    $rows += Compare-Value $fixture 'linearidade' 'nonLinear' $mineNonLinear ("$($rf.nonLinear)" -eq 'True') 'exact' 0 0

    # --- per channel ----------------------------------------------------
    # By id, not by position. What the reference has numbers for is the
    # autostretch: its before, its after, its shadows and midtones. records[0]
    # meant that only while the stretch was the whole chain, and stopped
    # meaning it the moment background sampling landed in front of it - which
    # showed up here as a null-array crash, not as a wrong comparison, only
    # because the background step reports `after: null`. A step that reported a
    # measurement would have been compared against the stretch's reference
    # numbers and the mismatch would have read as a pipeline regression.
    $rec = $records | Where-Object { $_.id -eq 'stretch-mtf' } | Select-Object -First 1
    if (-not $rec) { $rows += New-Row $fixture 'canais' '-' '-' '-' 'NO RECORD' 'nenhum record de stretch-mtf'; continue }

    $names = $rf.canais.PSObject.Properties.Name
    for ($i = 0; $i -lt $names.Count; $i++) {
        $ch = $names[$i]
        $rc = $rf.canais.$ch
        $b = $rec.before.perChannel[$i]
        $a = $rec.after.perChannel[$i]
        if (-not $b) { $rows += New-Row $fixture $ch '-' '-' '-' 'NO RECORD' "canal $i ausente"; continue }

        # Our own histogram width, because the floor being sized is the
        # resolution of our instrument. The reference publishes its own as
        # spanDoHistograma; they agree, and either would do.
        $span = if ($null -ne $b.span) { [double]$b.span }
                elseif ($null -ne $rc.spanDoHistograma) { [double]$rc.spanDoHistograma }
                else { 3.0 * ([double]$b.q3 - [double]$b.q1) }
        $total = [double]$b.totalPixels

        $e = $rc.estatisticaExata
        foreach ($f in @('median', 'q1', 'q3', 'p001', 'p999')) {
            $rows += Compare-Value $fixture $ch "before.$f" $b.$f $e.$f 'unit' $span $total
        }
        # A mediana entra no piso do mad/madn: ver a derivacao na secao 7.
        $dMed = [math]::Abs([double]$b.median - [double]$e.median)
        foreach ($f in @('mad', 'madn')) {
            $rows += Compare-Value $fixture $ch "before.$f" $b.$f $e.$f 'mad' $span $total $dMed
        }

        $p = $rc.parametros
        foreach ($f in @('shadows', 'midtones', 'target', 'scale')) {
            $rows += Compare-Value $fixture $ch "params.$f" $b.$f $p.$f 'unit' $span $total
        }

        $s = $rc.saida
        $rows += Compare-Value $fixture $ch 'after.clipLow'  $a.clipLow  $s.clipLow  'count' $span $total
        $rows += Compare-Value $fixture $ch 'after.clipHigh' $a.clipHigh $s.clipHigh 'count' $span $total
    }
}

# ---------------------------------------------------------------------------
# Modulo 1: the background step, against reference_bg.py
# ---------------------------------------------------------------------------
#
# A separate reference file and a separate block, because it answers a different
# question with a different currency.
#
# The Modulo 0 reference compares two estimators of the SAME statistic and its
# tolerance is the resolution of the instrument. Here the two implementations
# fit DIFFERENT surfaces: they accept 92 and 93 samples out of the same 108,
# because their global median and MADN come from different estimators and a box
# near the threshold falls on different sides. The fits are not the same object,
# so a tolerance sized for histogram resolution would be meaningless.
#
# The currency here is the 8-bit level, which is what the output is made of and
# what section 5 of modulo-1-spec.md states its limit in. Two surfaces that
# agree to a fraction of a level produce the same image, whatever their
# intermediate numbers did.
$M1_REF   = Join-Path $root 'referencia-modulo1.json'
$M1_MINE  = Join-Path $gold 'gradient-truth.json'
$LEVEL    = 1.0 / 255.0

# A value on the [0,1] axis, compared with a limit stated in 8-bit levels.
function Compare-Level($field, $mine, $refv, [double]$limitLevels, $note) {
    $d = [math]::Abs([double]$mine - [double]$refv) * 255.0
    $ok = ($d -le $limitLevels)
    $v = if ($ok) { 'PASS' } else { 'FAIL' }
    return New-Row 'gradient-fixture' 'fundo' $field ("{0:F6}" -f [double]$mine) ("{0:F6}" -f [double]$refv) $v `
           ("{0:F4} nivel / limite {1:F2}{2}" -f $d, $limitLevels, $(if ($note) { " - $note" } else { '' }))
}

# Both must be under a ceiling, and they must agree in magnitude. The ceiling is
# the criterion; the ratio is the agreement, and it is a judgement call - stated
# here rather than hidden, because nothing in either spec derives it. Two fits
# of the same surface from different point sets landing within 3x of each other
# on a sub-level quantity is a strong statement; 10x would not be.
function Compare-Both($field, [double]$mineLevels, [double]$refLevels, [double]$ceilingLevels, [double]$ratioLimit) {
    $hi = [math]::Max($mineLevels, $refLevels)
    $lo = [math]::Min($mineLevels, $refLevels)
    $ratio = if ($lo -gt 0) { $hi / $lo } else { [double]::PositiveInfinity }
    $okCeil  = ($ceilingLevels -le 0) -or ($hi -le $ceilingLevels)
    $okRatio = ($ratioLimit -le 0) -or ($ratio -le $ratioLimit)
    $v = if ($okCeil -and $okRatio) { 'PASS' } else { 'FAIL' }
    $why = @()
    if (-not $okCeil)  { $why += ("pior {0:F3} > teto {1:F2}" -f $hi, $ceilingLevels) }
    if (-not $okRatio) { $why += ("razao {0:F2} > {1:F2}" -f $ratio, $ratioLimit) }
    $detail = if ($why.Count) { $why -join '; ' } else { ("razao {0:F2}{1}" -f $ratio, $(if ($ceilingLevels -gt 0) { " / teto {0:F2}" -f $ceilingLevels } else { ' / sem teto' })) }
    return New-Row 'gradient-fixture' 'fundo' $field ("{0:F4}" -f $mineLevels) ("{0:F4}" -f $refLevels) $v $detail
}

if (-not (Test-Path -LiteralPath $M1_REF)) {
    $rows += New-Row 'gradient-fixture' 'fundo' '(todos)' '-' '-' 'N/A' 'referencia-modulo1.json ausente'
} elseif (-not (Test-Path -LiteralPath $M1_MINE)) {
    $rows += New-Row 'gradient-fixture' 'fundo' '(todos)' '-' '-' 'NO GOLDEN' 'rode compare-truth.js e promova gradient-truth.json'
} else {
    $m1r = Get-Content -LiteralPath $M1_REF  -Raw | ConvertFrom-Json
    $m1m = Get-Content -LiteralPath $M1_MINE -Raw | ConvertFrom-Json

    # The fixture both sides measured has to be the same bytes, or nothing below
    # means anything. Same guard the Modulo 0 block applies to its own fixtures.
    $fxPath = Join-Path $root 'test\fixtures\fixture-gradient.fit'
    $fxHash = (Get-FileHash -LiteralPath $fxPath -Algorithm SHA256).Hash.ToLower()
    $rows += Compare-Value 'gradient-fixture' 'fixture' 'sha256' $fxHash $m1r.fixture.sha256 'exact' 0 0

    $ra = $m1r.minhaImplementacao.amostras
    $ma = $m1m.samples
    $rows += Compare-Value 'gradient-fixture' 'fundo' 'amostras.geradas' $ma.generated $ra.geradas 'exact' 0 0

    # Not exact, and the reason is the point of this block: the two grids differ
    # because the two rejection thresholds come from different estimators.
    $dAcc = [math]::Abs([double]$ma.accepted - [double]$ra.aceitas)
    $rows += New-Row 'gradient-fixture' 'fundo' 'amostras.aceitas' $ma.accepted $ra.aceitas `
             $(if ($dAcc -le 2) { 'PASS' } else { 'FAIL' }) `
             ("difere de {0} de {1} - estimadores de limiar diferentes; limite 2" -f $dAcc, $ma.generated)

    foreach ($ch in @('R', 'G', 'B')) {
        $i = @('R', 'G', 'B').IndexOf($ch)
        $rows += Compare-Level "pedestal.$ch" $m1m.surface.perChannel[$i].pedestal $m1r.minhaImplementacao.pedestais.$ch 0.5 'piso de quantizacao'
    }

    # One lambda here, three there (identical to each other), because A is built
    # from the sample positions and the channels share them.
    $rows += Compare-Both 'lambda' ($m1m.surface.lambda * 255) ($m1r.minhaImplementacao.lambdas.R * 255) 0 1.5

    $rows += Compare-Both 'erroInterpolacao' $m1m.surface.maxInterpErrorLevels `
             $m1r.minhaImplementacao.erroInterpolacaoMaxNiveis 0.5 0

    # Residual against the analytic truth, region by region and channel by
    # channel. Only the clean field has a ceiling from the spec (section 5, one
    # level outside the rejected regions); under the object the residual IS the
    # contamination and there is no published limit, so agreement carries it.
    $regions = @(
        @{ mine = 'dentroObjeto'; ref = 'dentroObjeto'; ceiling = 0.0; ratio = 3.0 },
        @{ mine = 'haloProximo';  ref = 'haloProximo';  ceiling = 0.0; ratio = 3.0 },
        @{ mine = 'haloDistante'; ref = 'haloDistante'; ceiling = 0.0; ratio = 3.0 },
        @{ mine = 'campoLimpo';   ref = 'campoLimpo';   ceiling = 1.0; ratio = 3.0 }
    )
    foreach ($rg in $regions) {
        $mr = $m1m.residualVsGradient.($rg.mine)
        $rr = $m1r.minhaImplementacao.residuoContraVerdade.($rg.ref)
        # The masks have to select the same pixels before the errors mean
        # anything. This is the check that the four regions were adopted, not
        # merely named.
        $rows += Compare-Value 'gradient-fixture' 'fundo' "$($rg.mine).pixels" $mr.pixels $rr.pixels 'exact' 0 0
        foreach ($ch in @('R', 'G', 'B')) {
            $rows += Compare-Both "$($rg.mine).$ch.max"  $mr.$ch.maxLevels  $rr.$ch.maxLevels  $rg.ceiling $rg.ratio
            $rows += Compare-Both "$($rg.mine).$ch.mean" $mr.$ch.meanLevels $rr.$ch.meanLevels $rg.ceiling $rg.ratio
        }
    }

    # The 192-point lattice. This one has no reference counterpart to compare
    # against and does not need one: the target is the analytic gradient from
    # the HISTORY cards, so the comparison is against arithmetic, not against
    # another implementation. Ceiling from section 5.
    if ($m1m.latticeVsTruth -and $m1m.latticeVsTruth.points) {
        $rows += Compare-Value 'gradient-fixture' 'reticula' 'pontos' $m1m.latticeVsTruth.points $m1r.verdade.reticula.Count 'exact' 0 0
        foreach ($ch in @('R', 'G', 'B')) {
            $cl = $m1m.latticeVsTruth.campoLimpo.$ch.maxLevels
            $ok = ($cl -le 1.0)
            $rows += New-Row 'gradient-fixture' 'reticula' "campoLimpo.$ch.max" ("{0:F4}" -f $cl) 'verdade analitica' `
                     $(if ($ok) { 'PASS' } else { 'FAIL' }) `
                     ("{0} pontos, teto 1,00 nivel (secao 5)" -f $m1m.latticeVsTruth.campoLimpo.points)
        }
    }
}

# ---------------------------------------------------------------------------
# Cadeia completa, contra chain.py
# ---------------------------------------------------------------------------
#
# Este arquivo reabre o que o passo 6 fechou. `justyear-referencia.json` descreve
# a cadeia SEM extracao de fundo, entao desde que a etapa passou a mexer em pixel
# o bloco por canal do Modulo 0 compara dois quadros diferentes.
# `referencia-cadeia.json` monta a cadeia inteira -- decode, fundo, autostretch
# sobre o quadro CORRIGIDO -- e volta a ser comparavel numero a numero.
#
# A moeda aqui e a da secao 7: sao dois estimadores da mesma grandeza sobre os
# mesmos pixels, e nao dois ajustes diferentes como no bloco anterior. Histograma
# contra selecao exata, float32 contra float64. As tolerancias da secao 7
# aplicam-se sem ajuste.
$CHAIN_REF = Join-Path $root 'referencia-cadeia.json'

if (-not (Test-Path -LiteralPath $CHAIN_REF)) {
    $rows += New-Row 'cadeia' 'canais' '(todos)' '-' '-' 'N/A' 'referencia-cadeia.json ausente'
} else {
    $cr = Get-Content -LiteralPath $CHAIN_REF -Raw | ConvertFrom-Json
    $stillNa = @($cr.cobertura.porCanalAindaNA)

    foreach ($fx in $cr.fixtures.PSObject.Properties.Name) {
        $name = "$fx-fixture"
        $rf2  = $cr.fixtures.$fx

        # N/A escrito, nao falha. A referencia nao faz debayer, entao para um
        # mosaico ela mede o padrao Bayer e nao o quadro demosaicado: a razao de
        # MADN da 4,51 e isso nao e discordancia, sao grandezas diferentes. A
        # propria referencia declara quais fixtures ficam de fora, e este bloco
        # obedece a declaracao dela em vez de manter a lista aqui.
        if ($stillNa -contains $fx) {
            $rows += New-Row $name 'cadeia' '(todos)' '-' '-' 'N/A' $cr.cobertura.motivo
            continue
        }

        $recPath2 = Join-Path $gold "$name.records.json"
        if (-not (Test-Path -LiteralPath $recPath2)) {
            $rows += New-Row $name 'cadeia' '-' '-' '-' 'NO GOLDEN' 'capture-golden.js primeiro'
            continue
        }
        $recs2 = Get-Content -LiteralPath $recPath2 -Raw | ConvertFrom-Json
        $bgRec = $recs2 | Where-Object { $_.id -eq 'background' }  | Select-Object -First 1
        $stRec = $recs2 | Where-Object { $_.id -eq 'stretch-mtf' -or $_.id -eq 'stretch-asinh' } | Select-Object -First 1
        $ccRec = $recs2 | Where-Object { $_.id -eq 'colour-cal' } | Select-Object -First 1

        # A pre-condicao N/A que estava aqui saiu: reference_m23.py modela a
        # cadeia nova inteira. Ver os blocos 'cor' e 'esticamento' abaixo.
        if (-not $stRec) {
            $rows += New-Row $name 'cadeia' '-' '-' '-' 'NO RECORD' 'nenhum record de stretch-mtf'
            continue
        }

        $fxFile = Get-ChildItem -LiteralPath (Join-Path $root 'test\fixtures') -File |
                  Where-Object { $_.Name -like "fixture-$fx.*" } | Select-Object -First 1
        if ($fxFile) {
            $h2 = (Get-FileHash -LiteralPath $fxFile.FullName -Algorithm SHA256).Hash.ToLower()
            $rows += Compare-Value $name 'cadeia' 'sha256' $h2 $rf2.sha256 'exact' 0 0
        }

        # A etapa de fundo, como a referencia a viu.
        # `geradas` e a grade, nao uma medicao: a referencia nao a emite mais, e
        # comparar contra ausente descreveria a falta de um campo como
        # divergencia de numero. `aceitas` e o que carrega o resultado.
        if ($null -ne $rf2.fundo.geradas) {
            $rows += Compare-Value $name 'cadeia' 'fundo.geradas' $bgRec.samples.generated $rf2.fundo.geradas 'exact' 0 0
        }
        $rows += Compare-Value $name 'cadeia' 'fundo.aceitas' $bgRec.samples.accepted $rf2.fundo.aceitas 'exact' 0 0

        # A REFERENCIA DECLARA O QUE NAO COBRE, e este bloco obedece a declaracao
        # dela em vez de manter a lista aqui. Sem debayer, para um mosaico ela
        # mede o padrao Bayer e nao o quadro demosaicado -- grandezas diferentes,
        # nao discordancia. Se ela parar de declarar, isto reprova ALTO em vez de
        # comparar em silencio duas coisas que nao sao a mesma.
        $naDecl = @()
        if ($cr.cobertura -and $cr.cobertura.porCanalAindaNA) { $naDecl = @($cr.cobertura.porCanalAindaNA) }
        if ($naDecl -contains $fx) {
            $rows += New-Row $name 'cadeia' '(pos-decode)' '-' '-' 'N/A' $cr.cobertura.motivo
            continue
        }

        # ---- Modulo 2: calibracao de cor -------------------------------
        $cr2ref = $rf2.calibracaoCor
        if ($ccRec -and $cr2ref) {
            $rows += Compare-Value $name 'cor' 'aplicado' $ccRec.applied $cr2ref.applied 'exact' 0 0
            if ($ccRec.applied -and $cr2ref.applied) {
                $nu = $ccRec.neutralise; $nr = $cr2ref.neutralizacao
                $rows += Compare-Value $name 'cor' 'neutraliza.alvo' $nu.target $nr.alvo 'unit' 0 0
                foreach ($ci in 0..2) {
                    $rows += Compare-Value $name $CH3[$ci] 'neutraliza.offset' $nu.offsets[$ci] $nr.offsets[$ci] 'unit' 0 0
                    $rows += Compare-Value $name $CH3[$ci] 'pedestal'         $ccRec.stars.pedestals[$ci] $cr2ref.pedestais[$ci] 'unit' 0 0
                }
                $rows += Compare-Value $name 'cor' 'lum.mediana' $ccRec.stars.luminanceMedian $cr2ref.luminanciaSelecao.mediana 'unit' 0 0
                $rows += Compare-Value $name 'cor' 'lum.madn'    $ccRec.stars.luminanceMADN   $cr2ref.luminanciaSelecao.madn   'unit' 0 0
                $rows += Compare-Value $name 'cor' 'limiar.inferior' $ccRec.stars.thresholdLow $cr2ref.limiares.inferior 'unit' 0 0

                # AS TRES CONTAGENS POR LIMIAR, CADA UMA COM O SEU DELTA.
                #
                # A selecao estelar compara L contra med+12*MADN: o Delta e a
                # discordancia do limiar (os dois reportam) mais a da propria
                # grandeza, para a qual a diferenca das medianas e o substituto
                # medido. A rejeicao por saturacao usa o mesmo limiar superior
                # fixo em 0.85, entao so o Delta da grandeza entra.
                $dLum = [math]::Abs([double]$ccRec.stars.luminanceMedian - [double]$cr2ref.luminanciaSelecao.mediana)
                $dThr = [math]::Abs([double]$ccRec.stars.thresholdLow - [double]$cr2ref.limiares.inferior)
                $rows += Compare-Threshold-Count $name 'cor' 'estrelas.pixels' `
                         $ccRec.stars.pixels $cr2ref.pixels ($dThr + $dLum) $rf2.densidadePorLimiar.selecaoEstelar
                # O corte superior e fixo em 0.85, mas a contagem tambem e
                # limitada por baixo pelo mesmo thrLow -- os dois limiares entram.
                $rows += Compare-Threshold-Count $name 'cor' 'rejeitado.saturado' `
                         $ccRec.stars.rejected.saturated $cr2ref.rejeitados.saturado ($dThr + $dLum) $rf2.densidadePorLimiar.selecaoEstelar
                # A rejeicao de extenso conta sobre a mascara: ela herda a
                # incerteza da selecao, e nao tem limiar proprio no eixo dos
                # valores -- a cota e a mesma da selecao que a alimenta.
                $rows += Compare-Threshold-Count $name 'cor' 'rejeitado.extenso' `
                         $ccRec.stars.rejected.extended $cr2ref.rejeitados.extenso ($dThr + $dLum) $rf2.densidadePorLimiar.selecaoEstelar

                # As medianas estelares so existem se a selecao chegou a
                # produzi-las: uma recusa por minStarPixels acontece antes delas,
                # e comparar contra ausente descreveria a falta de um campo como
                # divergencia de numero. Que as duas pontas concordem sobre a
                # AUSENCIA e comparado logo abaixo, junto com a recusa.
                $temMed = ($null -ne $ccRec.stars.medians) -and ($null -ne $cr2ref.medianasEstelares)
                $rows += Compare-Value $name 'cor' 'estrelas.medidas' `
                         ($null -ne $ccRec.stars.medians) ($null -ne $cr2ref.medianasEstelares) 'exact' 0 0
                # Cada sub-bloco e guardado pelo proprio campo: os tres nao
                # nascem juntos, e uma recusa pode parar entre eles.
                if ($temMed) {
                    foreach ($ci in 0..2) {
                        $rows += Compare-Value $name $CH3[$ci] 'estrela.mediana' $ccRec.stars.medians[$ci] $cr2ref.medianasEstelares[$ci] 'unit' 0 0
                    }
                }
                if (($null -ne $ccRec.stars.abovePedestal) -and ($null -ne $cr2ref.acimaDoPedestal)) {
                    foreach ($ci in 0..2) {
                        $rows += Compare-Value $name $CH3[$ci] 'acimaDoPedestal' $ccRec.stars.abovePedestal[$ci] $cr2ref.acimaDoPedestal[$ci] 'unit' 0 0
                    }
                }
                if (($null -ne $ccRec.stars.ratios) -and ($null -ne $cr2ref.razoes)) {
                    $rows += Compare-Ratio $name 'cor' 'razao.rOverG' $ccRec.stars.ratios.rOverG $cr2ref.razoes.rOverG `
                             $cr2ref.acimaDoPedestal[0] $cr2ref.acimaDoPedestal[1]
                    $rows += Compare-Ratio $name 'cor' 'razao.bOverG' $ccRec.stars.ratios.bOverG $cr2ref.razoes.bOverG `
                             $cr2ref.acimaDoPedestal[2] $cr2ref.acimaDoPedestal[1]
                }
                if ($ccRec.gains -and $cr2ref.ganhos) {
                    foreach ($ci in 0..2) {
                        $rows += Compare-Ratio $name $CH3[$ci] 'ganho' $ccRec.gains[$ci] $cr2ref.ganhos[$ci] `
                                 $cr2ref.acimaDoPedestal[1] $cr2ref.acimaDoPedestal[$ci]
                        # A LINHA ACIMA E LARGA DE PROPOSITO, E ESTA E A QUE A COBRE.
                        #
                        # A tolerancia propagada herda o piso 4/65535 do eixo, que sobre
                        # um `above` de 0.013 vale 4.6e-3 relativo -- ponto cego de quase
                        # 1% num ganho, e 1% no azul se ve. Ela responde "os ganhos
                        # concordam dentro do que as entradas permitem?", que e uma
                        # pergunta legitima e frouxa.
                        #
                        # Esta responde a outra: "a formula e a mesma?". Alimentada com o
                        # `above` DELES, tem que reproduzir o ganho deles ao nivel do
                        # float. Um erro de formula de 1% aparece aqui mesmo escondido
                        # na folga da linha de cima, e um erro de ENTRADA aparece na
                        # linha do proprio acimaDoPedestal, que tem tolerancia estreita.
                        $meuGanho = if ([double]$cr2ref.acimaDoPedestal[$ci] -ne 0) {
                            [double]$cr2ref.acimaDoPedestal[1] / [double]$cr2ref.acimaDoPedestal[$ci]
                        } else { [double]::NaN }
                        $rows += Compare-Value $name $CH3[$ci] 'ganho(formula)' $meuGanho $cr2ref.ganhos[$ci] 'unit' 0 0
                    }
                } else {
                    # A recusa e resultado, e concordar sobre ela vale tanto
                    # quanto concordar sobre um numero.
                    $rows += Compare-Value $name 'cor' 'ganhos.recusou' `
                             ($null -eq $ccRec.gains) ($null -eq $cr2ref.ganhos) 'exact' 0 0
                }
            }
        }

        # ---- Modulo 3: esticamento ligado ------------------------------
        $es = $rf2.esticamento
        if ($es -and $stRec.linked) {
            $lk = $stRec.linked
            $rows += Compare-Value $name 'stretch' 'ligado'   $true            $es.ligado   'exact' 0 0
            $rows += Compare-Value $name 'stretch' 'operador' $stRec.params.operator $es.operador 'exact' 0 0
            $dLumY = [math]::Abs([double]$lk.luminanceMedian - [double]$es.luminancia.mediana)
            $rows += Compare-Value $name 'stretch' 'lum.mediana' $lk.luminanceMedian $es.luminancia.mediana 'unit' 0 0
            # O span do segundo histograma do analysePlane, que e a resolucao real
            # do MADN: o bin dele e span/(BINS-1). Passar o proprio MADN como
            # span dimensionaria a tolerancia a grandeza medida em vez de ao
            # instrumento que a mediu.
            $lumSpan = 0.0
            if ($null -ne $lk.luminanceSpan) { $lumSpan = [double]$lk.luminanceSpan }
            $rows += Compare-Value $name 'stretch' 'lum.madn'    $lk.luminanceMADN   $es.luminancia.madn 'mad' `
                     $lumSpan 0 $dLumY
            # `target` no ramo nao-linear NAO e o parametro: e a mediana do
            # proprio quadro, limitada a [0.02, 0.6]. Comparado explicitamente
            # porque e a unica entrada do esticamento que muda de significado
            # entre os dois ramos, e usar o parametro ali muda a curva inteira.
            $rows += Compare-Value $name 'stretch' 'target' $lk.target $es.target 'unit' 0 0

            # SHADOWS E MIDTONES SAO DERIVADOS, NAO MEDIDOS, e comparar o valor
            # final mistura duas perguntas: "a formula e a mesma?" e "as entradas
            # sao as mesmas?".
            #
            # A segunda ja esta respondida nas linhas lum.mediana e lum.madn
            # acima. Para responder a primeira sozinha, a formula daqui e
            # alimentada com as entradas DELES e o resultado comparado com o
            # valor deles. Se bater, a diferenca no valor final e propagacao da
            # entrada e nao discordancia de metodo.
            #
            # Isso importa porque a propagacao AMPLIFICA: no colour, 1.9e-6 de
            # diferenca na mediana vira 2.4e-4 em midtones, 131x, porque a MTF e
            # ingreme onde midtones vale 0.10. Alargar a tolerancia ate caber
            # esconderia uma divergencia de formula junto; isolar nao.
            $refMed = [double]$es.luminancia.mediana
            $refMadn = [double]$es.luminancia.madn
            $refC0 = [double]$es.shadows
            if (-not $lk.stretchUnreachable -and $stRec.params.operator -ne 'asinh') {
                if (-not $stRec.params.nonLinear) {
                    $meuShadows = $refMed + ([double]$stRec.params.shadowSigma) * $refMadn
                    $rows += Compare-Value $name 'stretch' 'shadows(formula)' $meuShadows $es.shadows 'unit' 0 0
                } else {
                    # No ramo nao-linear shadows sai de um percentil, que esta
                    # ponta tira do histograma e a outra do array exato. Nao ha
                    # como recomputar aqui, entao vai comparado direto e a
                    # diferenca e do instrumento.
                    $rows += Compare-Value $name 'stretch' 'shadows' $lk.shadows $es.shadows 'unit' 0 0
                }
                $sc2 = 1.0 / (1.0 - $refC0)
                $x2 = ($refMed - $refC0) * $sc2
                $meuMid = 0.5
                if ($refMadn -gt 0 -and $x2 -gt 0 -and $x2 -lt 1) {
                    $tg2 = [double]$es.target
                    $meuMid = if ($tg2 -eq 0.5) { $x2 } else { (($tg2 - 1) * $x2) / (((2 * $tg2 - 1) * $x2) - $tg2) }
                }
                $rows += Compare-Value $name 'stretch' 'midtones(formula)' $meuMid $es.midtones 'unit' 0 0
            }

            $dShad = [math]::Abs([double]$lk.shadows - [double]$es.shadows)
            $rows += Compare-Threshold-Count $name 'stretch' 'clipLow'  $lk.clipLow  $es.clipLow  ($dShad + $dLumY) $rf2.densidadePorLimiar.clipLow
            $rows += Compare-Threshold-Count $name 'stretch' 'clipHigh' $lk.clipHigh $es.clipHigh ($dShad + $dLumY) $rf2.densidadePorLimiar.clipHigh

            $cf = $stRec.colourFidelity; $cfr = $es.colourFidelity
            if ($cf -and $cfr) {
                # ASSERCAO, NAO COMPARACAO. Acima de 1e-6 a implementacao esta
                # errada, nao a tolerancia -- secao 3.2. Os dois lados sao
                # afirmados contra o limite, e nao um contra o outro.
                foreach ($par in @(@('nosso', $cf.maxRatioDrift), @('referencia', $cfr.maxRatioDrift))) {
                    $ok = ([double]$par[1] -le 1e-6)
                    $rows += New-Row $name 'stretch' ("deriva.$($par[0])") $par[1] '<= 1e-6' `
                             $(if ($ok) { 'PASS' } else { 'FAIL' }) `
                             $(if ($ok) { 'preservada por construcao' } else { 'a razao entre canais nao foi preservada' })
                }
                # pixelsRescaled compara max(R,G,B)*r contra 1.0. O limiar nao se
                # move; a grandeza sim, e de forma MULTIPLICATIVA atraves de r,
                # que carrega midtones. O Delta e relativo, nao aditivo.
                $dRel = 0.0
                if ([double]$lk.midtones -ne 0) {
                    $dRel = [math]::Abs([double]$lk.midtones - [double]$es.midtones) / [math]::Abs([double]$lk.midtones)
                }
                $rows += Compare-Threshold-Count $name 'stretch' 'pixelsRescaled' `
                         $cf.pixelsRescaled $cfr.pixelsRescaled $dRel $rf2.densidadePorLimiar.pixelsRescaled
            }
        }

        # ---- Modulo 4: saturacao seletiva ------------------------------
        #
        # A referencia le a etapa em `saturacao`, com as chaves que
        # reference_m23.saturate() devolve:
        #
        #   applied, skipReason
        #   mask{ background, noiseSigma, pixelsBelowSnrLow, pctFrame,
        #         pixelsAtFullAmount, pixelsAtFullMask, meanK, maxK }
        #   chromaNoise{ sigmaBefore, sigmaAfter, growthPct }
        #   overflow{ pixelsRescaled, pixelsLifted }
        #   hueFidelity{ maxHueDrift, driftSamples }
        #   saturationByLuminance[]{ range, pct, before, after }
        #
        # Uma contagem `pixels` por faixa e bem-vinda e preferida a `pct`:
        # reconstruir a contagem da percentagem custa meio pixel de
        # arredondamento por faixa, que nao muda veredito mas mede o
        # arredondamento junto com a etapa.
        #
        # TRES DIFERENCAS DE DEFINICAO, NAO DE PRECISAO, e por isso estao aqui
        # e nao numa tolerancia larga. Alimentar uma formula com as entradas da
        # outra so separa entrada de metodo quando as duas medem a MESMA
        # grandeza; nestas tres elas nao medem.
        #
        #   1. chromaNoise.sigma*  Aqui e o desvio padrao da NORMA da
        #      crominancia, sqrt(cr^2+cg^2+cb^2), um escalar por pixel. La e o
        #      desvio padrao das TRES COMPONENTES empilhadas num array de 3N.
        #      Sao estatisticas diferentes do mesmo conjunto: os valores nao sao
        #      comparaveis, e comparados dariam divergencia sem causa legivel.
        #      O que E comparavel e a afirmacao do produto -- "nao cresce mais
        #      que 2%" -- entao os dois lados sao afirmados contra o limite e
        #      nao um contra o outro, como ja e feito com colourFidelity.
        #      (E nao vem do analysePlane de nenhum dos dois lados: as duas somas
        #      sao exatas sobre os pixels protegidos. O que sai do histograma e a
        #      MEDIANA e o MADN que definem QUAIS pixels estao no conjunto.)
        #
        #   2. Ordem do estouro. Aqui: subfluxo primeiro (levanta os tres e
        #      reescala para PRESERVAR Y), depois transbordo (divide os tres).
        #      La: transbordo primeiro, depois um levantamento que NAO preserva
        #      Y, e um np.clip por canal no fim. Nos tres fixtures que existem
        #      hoje `pixelsLifted` e 0 nos dois lados, entao esta discordancia
        #      nao aparece como divergencia -- ela e NAO EXERCITADA, que nao e a
        #      mesma coisa que concordancia. Registrada aqui para nao ser lida
        #      como acordo.
        #
        #   3. saturationByLuminance.before/after. Aqui a saturacao HSV e
        #      (max-min)/max sempre que max > 0. La ela e zerada quando
        #      max <= 0.03. Nas faixas baixas isso muda a media, e nao por
        #      precisao.
        $sa = $rf2.saturacao
        $satRec = $recs2 | Where-Object { $_.id -eq 'saturation' } | Select-Object -First 1
        if ($null -eq $sa) {
            $rows += New-Row $name 'saturacao' '(todos)' '-' '-' 'N/A' `
                     'a referencia nao emite saturacao para este fixture'
        } elseif ($null -eq $satRec) {
            $rows += New-Row $name 'saturacao' '(todos)' '-' '-' 'N/A' `
                     'golden sem record de saturacao: capture o fixture com { saturation: true }'
        } else {
            $rows += Compare-Value $name 'saturacao' 'aplicado' $satRec.applied $sa.applied 'exact' 0 0

            if ($satRec.applied -and $sa.applied) {
                $mk = $satRec.mask; $rk = $sa.mask
                $pTot = [int]$rf2.decode.width * [int]$rf2.decode.height

                # O fundo e o ruido da luminancia: mediana e MADN, histograma de
                # 65536 bins contra selecao exata. Mesma moeda do bloco do
                # esticamento, e a origem de tudo que vem depois neste bloco.
                $dBg = [math]::Abs([double]$mk.background - [double]$rk.background)
                $rows += Compare-Value $name 'saturacao' 'mascara.fundo' `
                         $mk.background $rk.background 'unit' 0 0
                $lumSpan = 0.0
                if ($null -ne $mk.luminanceSpan) { $lumSpan = [double]$mk.luminanceSpan }
                $rows += Compare-Value $name 'saturacao' 'mascara.ruido' `
                         $mk.noiseSigma $rk.noiseSigma 'mad' $lumSpan 0 $dBg
                $dSig = [math]::Abs([double]$mk.noiseSigma - [double]$rk.noiseSigma)

                <#
                O FATOR k NAO MORA NO EIXO [0,1], e a cota dele e derivada.

                    k    = 1 + (A-1) * w * roll
                    w    = clip((snr - L) / (H - L), 0, 1)
                    snr  = (Y - b) / sigma

                `roll` depende so de Y, que os dois lados calculam dos mesmos
                pixels -- nao carrega a discordancia. Ela entra por `b` e
                `sigma`, e o Jacobiano do snr e

                    d(snr) <= (db + |snr| * dsigma) / sigma

                com o pior caso em snr = H, que e onde `w` ainda responde (acima
                dele o clamp satura e a sensibilidade e ZERO). Logo

                    dk <= (A-1) * (db + H * dsigma) / (sigma * (H - L))

                Medido no fixture-colour isso vale ~2.8e-4, o dobro do que a
                tolerancia do eixo [0,1] permitiria -- usa-la aqui reprovaria
                uma implementacao correta. O piso do eixo fica como minimo para
                que a cota nunca desca abaixo do instrumento.
                #>
                $pAmt = [double]$satRec.params.amount
                $pLow = [double]$satRec.params.snrLow
                $pHigh = [double]$satRec.params.snrHigh
                $sig = [math]::Max([double]$mk.noiseSigma, 1e-12)
                $dK = ($pAmt - 1.0) * ($dBg + $pHigh * $dSig) / ($sig * [math]::Max($pHigh - $pLow, 1e-12))
                $dK = [math]::Max($dK, 4.0 / 65535.0)
                foreach ($par in @(@('mascara.maxK', $mk.maxK, $rk.maxK), @('mascara.mediaK', $mk.meanK, $rk.meanK))) {
                    $dd = [math]::Abs([double]$par[1] - [double]$par[2])
                    $ok = ($dd -le $dK)
                    $rows += New-Row $name 'saturacao' $par[0] ('{0:G9}' -f [double]$par[1]) ('{0:G9}' -f [double]$par[2]) `
                             $(if ($ok) { if ($dd -eq 0) { 'PASS' } else { 'PASS~' } } else { 'FAIL' }) `
                             ('{0:0.0e+00} de {1:0.0e+00} - cota propagada de db e dsigma' -f $dd, $dK)
                }

                <#
                AS CONTAGENS DA MASCARA SAO CONTAGENS POR LIMIAR.

                `snr` contra `snrLow` e contra `snrHigh`: um pixel troca de lado
                quando `snr - T` troca de sinal, e as duas pontas mexem em `snr`
                pelos mesmos db e dsigma de cima. O Delta e POR LIMIAR, porque o
                termo |snr|*dsigma cresce com o limiar: em snrLow = 3 ele vale
                3*dsigma, em snrHigh = 25 vale 25*dsigma, oito vezes mais.

                Quando a referencia emitir `densidadePorLimiar.saturacao.<campo>`
                a cota sai da curva, como no clipLow. Sem a curva a linha cai na
                cota de contagem da secao 7 (0,05% do quadro) e o detalhe diz
                que a cota nao foi derivada -- que e menos, e esta escrito.
                #>
                $dens = $null
                if ($rf2.densidadePorLimiar -and $rf2.densidadePorLimiar.saturacao) {
                    $dens = $rf2.densidadePorLimiar.saturacao
                }
                $dSnrLow  = ($dBg + $pLow  * $dSig) / $sig
                $dSnrHigh = ($dBg + $pHigh * $dSig) / $sig

                foreach ($t in @(
                    @('mascara.abaixoDoLimiar', $mk.pixelsBelowSnrLow, $rk.pixelsBelowSnrLow, $dSnrLow,  'pixelsBelowSnrLow'),
                    @('mascara.mascaraCheia',   $mk.pixelsAtFullMask,  $rk.pixelsAtFullMask,  $dSnrHigh, 'pixelsAtFullMask'),
                    @('mascara.amountCheio',    $mk.pixelsAtFullAmount, $rk.pixelsAtFullAmount, $dSnrHigh, 'pixelsAtFullAmount'))) {
                    $curve = $null
                    if ($dens) { $curve = $dens.($t[4]) }
                    if ($curve) {
                        $rows += Compare-Threshold-Count $name 'saturacao' $t[0] $t[1] $t[2] $t[3] $curve
                    } else {
                        $r0 = Compare-Value $name 'saturacao' $t[0] $t[1] $t[2] 'count' 0 $pTot
                        $r0.detalhe = $r0.detalhe + ' - cota da secao 7, nao derivada (sem densidadePorLimiar.saturacao)'
                        $rows += $r0
                    }
                }

                # Estouro. O limiar e 1.0 e nao se move; a grandeza e
                # max(R,G,B) depois de multiplicada por k, entao o Delta e
                # MULTIPLICATIVO atraves de k -- a mesma forma do pixelsRescaled
                # do esticamento, onde o Delta vem de midtones.
                $dRelK = 0.0
                if ([double]$mk.maxK -ne 0) { $dRelK = $dK / [math]::Abs([double]$mk.maxK) }
                $ov = $satRec.overflow; $rov = $sa.overflow
                if ($ov -and $rov) {
                    foreach ($t in @(
                        @('estouro.reescalados', $ov.pixelsRescaled, $rov.pixelsRescaled, 'pixelsRescaled'),
                        @('estouro.levantados',  $ov.pixelsLifted,   $rov.pixelsLifted,   'pixelsLifted'))) {
                        $curve = $null
                        if ($dens) { $curve = $dens.($t[3]) }
                        if ($curve) {
                            $rows += Compare-Threshold-Count $name 'saturacao' $t[0] $t[1] $t[2] $dRelK $curve
                        } else {
                            $r0 = Compare-Value $name 'saturacao' $t[0] $t[1] $t[2] 'count' 0 $pTot
                            $r0.detalhe = $r0.detalhe + ' - cota da secao 7, nao derivada'
                            $rows += $r0
                        }
                    }
                    # O caminho do subfluxo tem contagem zero nos dois lados em
                    # todos os fixtures de hoje. Dito em voz alta, porque zero
                    # igual a zero le como acordo e aqui e ausencia de caso --
                    # a mesma classe dos quatro zeros do rejected-edge.
                    if ([int]$ov.pixelsLifted -eq 0 -and [int]$rov.pixelsLifted -eq 0) {
                        $rows += New-Row $name 'saturacao' 'estouro.subfluxo' '0' '0' 'N/A' `
                                 'nenhum pixel abaixo de zero: o caminho onde as duas implementacoes discordam de ORDEM nao foi exercitado'
                    }
                }

                # AFIRMACAO, NAO COMPARACAO -- secao 3.2 do Modulo 4 e o mesmo
                # padrao do colourFidelity. Acima de 1e-6 a implementacao esta
                # errada, e nao a tolerancia. Os dois lados sao afirmados contra
                # o limite; um contra o outro nao diria nada, porque zero e zero
                # e tambem o que sai quando a etapa nao faz nada.
                $hf = $satRec.hueFidelity; $rhf = $sa.hueFidelity
                if ($hf -and $rhf) {
                    foreach ($par in @(@('nosso', $hf.maxHueDrift), @('referencia', $rhf.maxHueDrift))) {
                        $ok = ([double]$par[1] -le 1e-6)
                        $rows += New-Row $name 'saturacao' ("matiz.$($par[0])") $par[1] '<= 1e-6' `
                                 $(if ($ok) { 'PASS' } else { 'FAIL' }) `
                                 $(if ($ok) { 'preservado por construcao' } else { 'o matiz andou: erro de implementacao, nao de cota' })
                    }
                    # `driftSamples` conta os pixels com matiz definido, e as
                    # duas pontas usam limiares diferentes para "definido"
                    # (max-min > 0 aqui, > 1e-12 la). E contagem por limiar com
                    # Delta que nenhum dos dois lados mede; vai pela cota da
                    # secao 7 com a causa escrita.
                    $r0 = Compare-Value $name 'saturacao' 'matiz.amostras' `
                          $hf.driftSamples $rhf.driftSamples 'count' 0 $pTot
                    $r0.detalhe = $r0.detalhe + ' - limiar de "matiz definido" difere: >0 aqui, >1e-12 la'
                    $rows += $r0
                }

                # Ruido de croma: afirmacao contra o limite dos dois lados, e os
                # dois sigmas reportados sem veredito. Ver a nota 1 no topo
                # deste bloco -- sao estatisticas diferentes do mesmo conjunto.
                $cn = $satRec.chromaNoise; $rcn = $sa.chromaNoise
                if ($cn -and $rcn) {
                    $limPct = 2.0
                    if ($null -ne $cn.limitPct) { $limPct = [double]$cn.limitPct }
                    foreach ($par in @(@('nosso', $cn.growthPct), @('referencia', $rcn.growthPct))) {
                        $ok = ([double]$par[1] -le $limPct)
                        $rows += New-Row $name 'saturacao' ("croma.crescimento.$($par[0])") `
                                 ('{0:0.0000}%' -f [double]$par[1]) ("<= $limPct%") `
                                 $(if ($ok) { 'PASS' } else { 'FAIL' }) `
                                 $(if ($ok) { 'a mascara protege o fundo' } else { 'a mascara nao esta protegendo o ceu' })
                    }
                    $rows += New-Row $name 'saturacao' 'croma.sigma' `
                             ('{0:G6}' -f [double]$cn.sigmaBefore) ('{0:G6}' -f [double]$rcn.sigmaBefore) 'N/A' `
                             'desvio da NORMA aqui, das tres componentes empilhadas la: grandezas diferentes'
                }

                # A tabela por faixa de luminancia -- a metrica do produto, a
                # unica que permite comparar contra uma entrega manual sem olhar
                # a imagem. `pct` e contagem por limiar em Y; `before`/`after`
                # sao medias sobre o conjunto da faixa.
                $bl = @($satRec.saturationByLuminance); $rbl = @($sa.saturationByLuminance)
                if ($bl.Count -gt 0 -and $rbl.Count -gt 0) {
                    if ($bl.Count -ne $rbl.Count) {
                        $rows += New-Row $name 'saturacao' 'faixas' $bl.Count $rbl.Count 'FAIL' `
                                 'numero de faixas difere: as duas tabelas nao descrevem a mesma particao'
                    } else {
                        for ($bi = 0; $bi -lt $bl.Count; $bi++) {
                            $lo = [double]$bl[$bi].range[0]
                            $tag = ('faixa[{0:0.00}]' -f $lo)
                            # A contagem direta quando a referencia a emite; reconstruida
                            # da percentagem quando nao. Reconstruir custa meio pixel
                            # de arredondamento e nao muda veredito, mas o campo
                            # direto e o que se deve pedir.
                            $refN = $rbl[$bi].pixels
                            $viaPct = $false
                            if ($null -eq $refN) { $refN = [math]::Round([double]$rbl[$bi].pct / 100.0 * $pTot); $viaPct = $true }
                            $r0 = Compare-Value $name 'saturacao' "$tag.pixels" $bl[$bi].pixels $refN 'count' 0 $pTot
                            $r0.detalhe = $r0.detalhe + ' - contagem por limiar em Y' + $(if ($viaPct) { ' (reconstruida de pct)' } else { '' })
                            $rows += $r0
                            foreach ($w in @('before', 'after')) {
                                $mv = $bl[$bi].$w; $rv = $rbl[$bi].$w
                                if ($null -eq $mv -or $null -eq $rv) { continue }
                                $r1 = Compare-Value $name 'saturacao' "$tag.$w" $mv $rv 'unit' 0 0
                                if ($r1.resultado -eq 'FAIL' -and $lo -lt 0.10) {
                                    $r1.detalhe = $r1.detalhe + ' - a referencia zera a saturacao abaixo de max=0.03; aqui nao'
                                }
                                $rows += $r1
                            }
                        }
                    }
                }
            } elseif ((-not $satRec.applied) -and (-not $sa.applied)) {
                # As duas recusaram. O motivo importa mais que o veredito: duas
                # recusas por razoes diferentes leem como acordo e nao sao.
                $rows += New-Row $name 'saturacao' 'motivo' `
                         $satRec.skipReason $sa.skipReason 'N/A' `
                         'as duas recusaram; os textos sao proprios de cada implementacao'
            }
        }

        # PRE-CONDICAO para comparar estatistica pos-correcao.
        #
        # A tolerancia da secao 7 pressupoe que os dois lados medem OS MESMOS
        # PIXELS por caminhos diferentes. Depois da extracao de fundo isso deixa
        # de ser verdade se as duas aceitarem conjuntos de amostras diferentes:
        # ajustes diferentes, correcoes diferentes, quadros corrigidos
        # diferentes. Comparar as medianas desses dois quadros nao mede
        # concordancia de estimador, mede a diferenca entre as duas superficies,
        # e reprovar catorze campos por canal descreve o sintoma catorze vezes
        # em vez de nomear a causa uma.
        #
        # A causa fica visivel na linha `fundo.aceitas` acima, que reprova. As
        # consequencias ficam N/A com o motivo escrito.
        if ([int]$bgRec.samples.accepted -ne [int]$rf2.fundo.aceitas) {
            $rows += New-Row $name 'canais' '(todos)' $bgRec.samples.accepted $rf2.fundo.aceitas 'N/A' `
                     ("conjuntos de amostras diferentes ({0} contra {1}): as duas corrigem com superficies diferentes, entao nao medem os mesmos pixels" -f `
                      $bgRec.samples.accepted, $rf2.fundo.aceitas)
            continue
        }

        $names2 = $rf2.canais.PSObject.Properties.Name
        for ($ci = 0; $ci -lt $names2.Count; $ci++) {
            $ch2 = $names2[$ci]
            $rc2 = $rf2.canais.$ch2
            $b2  = $stRec.before.perChannel[$ci]
            $a2  = $stRec.after.perChannel[$ci]

            $span2 = if ($null -ne $b2.span) { [double]$b2.span } else { 3.0 * ([double]$b2.q3 - [double]$b2.q1) }
            $tot2  = [double]$b2.totalPixels

            # O `before` do stretch E a medicao do quadro corrigido. Que estes
            # numeros batam e a confirmacao independente do bug corrigido no
            # passo 6: uma segunda implementacao, escrita depois e montada do
            # zero, mede o mesmo MADN pos-correcao.
            $e2 = $rc2.estatisticaExata
            foreach ($f in @('median', 'q1', 'q3', 'p001', 'p999')) {
                $rows += Compare-Value $name $ch2 "corrigido.$f" $b2.$f $e2.$f 'unit' $span2 $tot2
            }
            $dMed2 = [math]::Abs([double]$b2.median - [double]$e2.median)
            foreach ($f in @('mad', 'madn')) {
                $rows += Compare-Value $name $ch2 "corrigido.$f" $b2.$f $e2.$f 'mad' $span2 $tot2 $dMed2
            }

            $p2 = $rc2.parametros
            foreach ($f in @('shadows', 'midtones', 'target', 'scale')) {
                $rows += Compare-Value $name $ch2 "params.$f" $b2.$f $p2.$f 'unit' $span2 $tot2
            }

            # O pedestal vem do ajuste, nao da medicao: duas superficies
            # diferentes, entao a moeda e o nivel de 8 bits e nao o bin do
            # histograma. Mesmo criterio do bloco anterior.
            if ($bgRec.surface -and $bgRec.surface.perChannel) {
                $d3 = [math]::Abs([double]$bgRec.surface.perChannel[$ci].pedestal - [double]$rc2.pedestal) * 255.0
                $rows += New-Row $name $ch2 'pedestal' ("{0:F6}" -f [double]$bgRec.surface.perChannel[$ci].pedestal) `
                         ("{0:F6}" -f [double]$rc2.pedestal) $(if ($d3 -le 0.5) { 'PASS' } else { 'FAIL' }) `
                         ("{0:F4} nivel / limite 0,50 - piso de quantizacao" -f $d3)
            }

            $s2 = $rc2.saida
            $rows += Compare-Value $name $ch2 'saida.clipLow'  $a2.clipLow  $s2.clipLow  'count' $span2 $tot2
            $rows += Compare-Value $name $ch2 'saida.clipHigh' $a2.clipHigh $s2.clipHigh 'count' $span2 $tot2

            # A saida da referencia esta em niveis e e a mediana dos INTEIROS; a
            # minha e a mediana do float antes do quantise. Um nivel de limite,
            # porque a diferenca entre as duas e a quantizacao em si.
            $d4 = [math]::Abs([double]$a2.median * 255.0 - [double]$s2.median)
            $rows += New-Row $name $ch2 'saida.median' ("{0:F2}" -f ([double]$a2.median * 255.0)) `
                     ("{0:F2}" -f [double]$s2.median) $(if ($d4 -le 1.0) { 'PASS' } else { 'FAIL' }) `
                     ("{0:F3} nivel / limite 1,00 - minha mediana e do float, a dela do inteiro" -f $d4)
        }
    }

    # A confirmacao do bug, como a referencia a publica. Nao e uma comparacao
    # nova, e o registro de que ela existe e do que ela diz.
    foreach ($fx in $cr.cobertura.confirmacaoDoBugDoMADN.PSObject.Properties.Name) {
        if ($fx -eq 'nota') { continue }
        $ratio = [double]$cr.cobertura.confirmacaoDoBugDoMADN.$fx
        $rows += New-Row "$fx-fixture" 'cadeia' 'razaoMADN' ("{0:F4}" -f $ratio) '1,0000' `
                 $(if ([math]::Abs($ratio - 1.0) -le 0.02) { 'PASS' } else { 'FAIL' }) `
                 'razao entre o MADN pos-correcao dela e o meu; 1,00 confirma o conserto do passo 6'
    }
}

# -Csv existe porque a tabela formatada trunca a coluna do veredito quando os
# campos sao largos (um sha256 empurra tudo para fora da tela), e "quais
# linhas reprovaram" e a pergunta que mais se faz deste script.
if ($Csv) { $rows | ConvertTo-Csv -NoTypeInformation }
elseif (-not $Quiet) { $rows | Format-Table -AutoSize -Wrap }

# Not $known: PowerShell variable names are case-insensitive, so that would be
# the same variable as $KNOWN and would overwrite the debt list with its count.
$nFail  = @($rows | Where-Object { $_.resultado -eq 'FAIL' -or $_.resultado -like 'NO *' }).Count
$nKnown = @($rows | Where-Object { $_.resultado -eq 'KNOWN' }).Count
$nNa    = @($rows | Where-Object { $_.resultado -eq 'N/A' }).Count
$nPass  = @($rows | Where-Object { $_.resultado -eq 'PASS' }).Count

Write-Host ''
Write-Host ("comparados {0}  |  PASS {1}  KNOWN {2}  N/A {3}  FAIL {4}" -f $rows.Count, $nPass, $nKnown, $nNa, $nFail)

if ($nKnown -gt 0) {
    Write-Host ''
    Write-Host 'Divergencias conhecidas (nao sao regressao, sao divida):'
    foreach ($k in $KNOWN) {
        Write-Host ("  {0} {1} [{2}] - {3}" -f $k.fixture, $k.field, $k.module, $k.reason)
    }
}

if ($nFail -gt 0) { Write-Host ''; Write-Host "$nFail divergencia(s) NAO explicada(s)"; exit 1 }
Write-Host 'nenhuma divergencia inesperada'
