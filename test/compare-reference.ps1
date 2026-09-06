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
#   mad and madn:             |a-b| <= max(1e-4*|ref|, 8*span/65535)
#   pixel counts:             0.05% of the frame
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
    [switch]   $Quiet
)

$ErrorActionPreference = 'Stop'
[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture

$root = Split-Path -Parent $PSScriptRoot
$gold = Join-Path $PSScriptRoot 'golden'
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
function Compare-Value($fixture, $scope, $field, $mine, $refv, $kind, $span, $total) {
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
        $floor = 8.0 * $unit
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
                 ("pipeline roda " + ($unmodelled -join ', ') + " e reference.py nao modela - passo 8 da secao 6")
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
        foreach ($f in @('mad', 'madn')) {
            $rows += Compare-Value $fixture $ch "before.$f" $b.$f $e.$f 'mad' $span $total
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

if (-not $Quiet) { $rows | Format-Table -AutoSize -Wrap }

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
