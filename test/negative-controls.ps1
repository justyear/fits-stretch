# Negative controls for compare-golden.ps1.
#
#   pwsh test/negative-controls.ps1
#
# Every case mutates one artifact and asserts the verdict the comparator should
# reach. A tolerance that cannot fail is not a tolerance, it is a rubber stamp,
# and "controle negativo verificado" written in a spec is a claim that stops
# being true the moment nobody can re-run it.
#
# The goldens are never touched: each case works on a throwaway copy, and the
# copies are deleted even when a case throws.
#
# Requires test/golden/ to be current, so run it after compare-golden.ps1
# passes, not instead of it. It compares the goldens against mutated copies of
# themselves, so it needs neither a fresh capture nor the browser.
#
# ASCII only, no BOM - see the note at the top of compare-golden.ps1.
#
# Two PowerShell traps cost time while this file was being written, and both
# produced a wrong path silently instead of an error where the mistake was:
#
#   - Braces are load-bearing. "$FIX.records.json" parses the dots as property
#     access on the string and evaluates to the empty string.
#   - Variable names are case-insensitive, so a name like $D used inside a
#     scriptblock that declares param($d) resolves to the parameter. Hence the
#     ART_ prefix on the artifact names and $tmpdir rather than $d below.

$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$gold = Join-Path $here 'golden'
$cmp  = Join-Path $here 'compare-golden.ps1'
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('golden-neg-' + [guid]::NewGuid().ToString('N').Substring(0, 8))

Add-Type -AssemblyName System.Drawing

# One fixture is enough: the cases exercise the comparator, not the pipeline.
$FIX = 'nonlinear-fixture'

$ART_REC  = "${FIX}.records.json"
$ART_DIAG = "${FIX}.diag.json"
$ART_PNG  = "${FIX}.png"
$ART_LOG  = "${FIX}.log.txt"

function New-Fresh {
    $dir = Join-Path $work ([guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Force $dir | Out-Null
    Get-ChildItem $gold -File | Where-Object { $_.Name -like ($FIX + '.*') } | Copy-Item -Destination $dir -Force
    return $dir
}

function Edit-Text($dir, $file, $from, $to) {
    $path = Join-Path $dir $file
    $text = [System.IO.File]::ReadAllText($path)
    if (-not $text.Contains($from)) { throw "pattern not found in ${file}: $from" }
    [System.IO.File]::WriteAllText($path, $text.Replace($from, $to))
}

# Shifts `count` colour samples by `delta`, leaving alpha alone. -Resize crops
# two columns instead, to exercise the dimension check. -Lane restricts the
# shift to one byte lane (0=B, 1=G, 2=R in Format32bppArgb memory order), which
# is how a partial shift is produced on purpose.
function Edit-Png($dir, $file, [int]$delta, [long]$count, [switch]$Resize, [int]$Lane = -1) {
    $path = Join-Path $dir $file
    $src = New-Object System.Drawing.Bitmap($path)
    $w = $src.Width; $h = $src.Height
    if ($Resize) { $w = $w - 2 }
    $bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.DrawImage($src, 0, 0, $src.Width, $src.Height)
    $gfx.Dispose(); $src.Dispose()

    $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
    $bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite,
                        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $len = [Math]::Abs($bd.Stride) * $h
    $buf = New-Object byte[] $len
    [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $buf, 0, $len)
    $n = 0
    for ($i = 0; $i -lt $len -and $n -lt $count; $i++) {
        # $laneIdx, not $lane: PowerShell variable names are case-insensitive,
        # so `$lane` and the -Lane parameter would be one variable and the
        # filter would erase itself on the first iteration. This file warns
        # about that trap at the top and still walked into it here.
        $laneIdx = $i % 4
        if ($laneIdx -eq 3) { continue }
        if ($Lane -ge 0 -and $laneIdx -ne $Lane) { continue }
        $v = [int]$buf[$i] + $delta
        if ($v -lt 0) { $v = 0 } elseif ($v -gt 255) { $v = 255 }
        $buf[$i] = [byte]$v
        $n++
    }
    [System.Runtime.InteropServices.Marshal]::Copy($buf, 0, $bd.Scan0, $len)
    $bmp.UnlockBits($bd)
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# --- ancoras, lidas do golden em tempo de execucao ------------------------
#
# Nao hardcoded. Os valores concretos mudaram quatro vezes nesta suite -- cada
# recaptura de golden os movia e o script parava com "pattern not found", que e
# o modo de falha certo mas custa uma reancoragem manual toda vez. Lidos daqui,
# os casos seguem valendo enquanto a ESTRUTURA nao mudar, que e o que eles
# realmente testam.
#
# A busca usa o literal exato como o JSON.stringify o escreveu, porque .NET nao
# tem o round-trip mais curto do JavaScript e reformatar erraria o alvo.
$recTxt  = [System.IO.File]::ReadAllText((Join-Path $gold $ART_REC))
$diagTxt = [System.IO.File]::ReadAllText((Join-Path $gold $ART_DIAG))
$logTxt  = [System.IO.File]::ReadAllText((Join-Path $gold $ART_LOG))
$recJson = $recTxt | ConvertFrom-Json
$sti = 0
for ($k9 = 0; $k9 -lt @($recJson).Count; $k9++) {
    if (@($recJson)[$k9].id -eq 'stretch-mtf' -or @($recJson)[$k9].id -eq 'stretch-asinh') { $sti = $k9 }
}
$b9 = @($recJson)[$sti].before.perChannel[0]
$a9 = @($recJson)[$sti].after.perChannel[0]

function Find-Literal([string]$text, [string]$key, [string]$approx) {
    $m = [regex]::Match($text, '"' + $key + '":\s*(' + [regex]::Escape($approx.Substring(0, [Math]::Min(10, $approx.Length))) + '[0-9eE+-]*)')
    if (-not $m.Success) { throw "literal de $key nao encontrado no golden" }
    return $m.Groups[1].Value
}
# InvariantCulture em toda formatacao: neste sistema a cultura usa virgula
# decimal, e "{0:R}" -f produziria "0,2635..." -- um prefixo que nunca casa com
# o ponto que o JSON escreveu. Foi exatamente assim que a primeira versao falhou.
$inv9   = [cultureinfo]::InvariantCulture
function RT9([double]$v){ return [string]::Format($inv9, '{0:R}', $v) }
$MED    = Find-Literal $recTxt  'median' (RT9 ([double]$b9.median))
$MADN   = Find-Literal $recTxt  'madn'   (RT9 ([double]$b9.madn))
$DIAGMED= Find-Literal $diagTxt 'median' (RT9 ([double]$b9.median))
$medV   = [double]::Parse($MED,  $inv9)
$madV   = [double]::Parse($MADN, $inv9)
$spanV  = [double]$b9.span

# Os deltas sao calculados a partir dos limites da secao 7, nao escolhidos:
#   unit  = max(1e-4*ref, 4/65535)          -> dentro em 0.82x, fora em 1.15x
#   span  = max(1e-4*ref, 8*span/65535)     -> dentro em 0.69x, fora em 2.77x
$uLim9  = [Math]::Max(1e-4 * $medV, 4.0 / 65535.0)
$mLim9  = [Math]::Max(1e-4 * $madV, 8.0 * $spanV / 65535.0)
$MED_IN  = [string]::Format($inv9, '{0:G17}', ($medV + 0.82 * $uLim9))
$MED_OUT = [string]::Format($inv9, '{0:G17}', ($medV + 1.15 * $uLim9))
$MAD_IN  = [string]::Format($inv9, '{0:G17}', ($madV + 0.69 * $mLim9))
$MAD_OUT = [string]::Format($inv9, '{0:G17}', ($madV + 2.77 * $mLim9))
$CLIPHI  = '"clipHigh": ' + $a9.clipHigh
$CLIPLO  = '"clipLow": '  + $a9.clipLow
$PXBLACK = '"pixelsBlack": ' + $a9.clipLow
# A ancora do log tem que sair de onde o log de HOJE imprime um numero.
#
# Ela era a mediana por canal, e o Modulo 3 a tirou do log: com o esticamento
# ligado ha UMA curva, derivada da luminancia, e a linha por canal deixou de
# existir. O script parou com a mensagem dizendo qual padrao nao achou, que e o
# comportamento certo -- um controle negativo que se auto-desativasse em
# silencio seria pior que nao existir. Reancorado na mediana da luminancia, que
# esta no record em `linked` e no log na linha "Luminance median ...".
$stretchRec9 = @($recJson)[$sti]
if ($stretchRec9 -and $stretchRec9.linked) {
    $logMedV = [double]$stretchRec9.linked.luminanceMedian
} else {
    $logMedV = [double]$b9.median
}
$LOGMED  = 'median ' + $logMedV.ToString('0.00000', $inv9)
$LOGMED2 = 'median ' + ($logMedV + 0.00001).ToString('0.00000', $inv9)
if (-not $logTxt.Contains($LOGMED)) { throw "ancora do log nao encontrada: $LOGMED" }
# The numbers are read off the current goldens. Each pair sits just inside and
# just outside one specific limit, so a limit that silently widened shows up as
# a MISMATCH here instead of as a quiet pass.
#
#   median  unit rule,  max(1e-4 * ref, 4/65535)      = 6.104e-5 at ref 0.26357
#   madn    span rule,  max(1e-4 * ref, 8*span/65535) = 2.884e-6 at span 0.02362
#   clip    0.05% of totalPixels                      = 270 of 540000
#
# The madn +8e-6 case is the one that matters most: it fails the span rule and
# would pass the [0,1] rule, which is 21 times looser at this magnitude. It is
# the only case that can tell the two rules apart.
$cases = @(
    @{ name = 'baseline, untouched'; art = $null; want = 'PASS'; do = { } }

    @{ name = 'records median +5e-5 (0.82 of limit)'; art = $ART_REC; want = 'PASS~'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC $MED $MED_IN } }
    @{ name = 'records median +7e-5 (1.15 of limit)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC $MED $MED_OUT } }

    @{ name = 'records madn +2e-6 (0.69 of the span limit)'; art = $ART_REC; want = 'PASS~'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC $MADN $MAD_IN } }
    @{ name = 'records madn +8e-6, fails span rule, passes [0,1] rule'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC $MADN $MAD_OUT } }

    # Clip counts are exact in this comparator, so all three of these fail, and
    # the third is the one the rule exists for. Under the old 0.05% tolerance
    # the first two passed and the third passed too - a shadow clip vanishing
    # completely read as "within tolerance", by one pixel.
    @{ name = 'records clipHigh 58 -> 57 (one pixel, exact now)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC $CLIPHI ($CLIPHI -replace '\d+$', ([int]$a9.clipHigh + 1)) } }
    @{ name = 'records clipHigh 58 -> 290 (was inside the old 0.05%)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC $CLIPHI ($CLIPHI -replace '\d+$', ([int]$a9.clipHigh + 234)) } }
    @{ name = 'records clipHigh 58 -> 0 (the clip vanished)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC $CLIPHI '"clipHigh": 0' } }
    @{ name = 'records clipLow 249 -> 0 (the clip vanished)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC $CLIPLO '"clipLow": 0' } }
    @{ name = 'diag pixelsBlack 249 -> 0 (the clip vanished)'; art = $ART_DIAG; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_DIAG $PXBLACK '"pixelsBlack": 0' } }

    @{ name = 'records params.target nudged (input knob, exact)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '"target": 0.25,' '"target": 0.2501,' } }
    @{ name = 'records sampled 540000 -> 539999 (basis, exact)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '"sampled": 540000' '"sampled": 539999' } }
    @{ name = 'records key renamed (structural)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '"madn"' '"madnX"' } }
    @{ name = 'records applied true -> false'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '"applied": true' '"applied": false' } }

    @{ name = 'diag channels[0].median +5e-5'; art = $ART_DIAG; want = 'PASS~'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_DIAG ('"median": ' + $DIAGMED) ('"median": ' + $MED_IN) } }
    @{ name = 'diag decoded.normMax nudged (off the file, exact)'; art = $ART_DIAG; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_DIAG '"normMax": 1' '"normMax": 1.0001' } }

    @{ name = 'png one sample +1'; art = $ART_PNG; want = 'PASS~'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 1 1 } }
    @{ name = 'png one sample +2'; art = $ART_PNG; want = 'FAIL'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 2 1 } }
    @{ name = 'png re-encoded, pixels untouched'; art = $ART_PNG; want = 'PASS~'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 0 0 } }
    @{ name = 'png width cropped by 2'; art = $ART_PNG; want = 'FAIL'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 0 0 -Resize } }

    # The pedestal guard. A constant offset is the failure mode of
    # `out = in - model + pedestal` and it fits inside the per-pixel limit, so
    # the limit cannot be what catches it. The signed median is.
    #
    # The pair that matters is the first two: same verdict, same magnitude, same
    # limit - and opposite shift findings. One sample moved is rounding noise
    # and its signed median stays 0; every sample moved is an offset and the
    # signed median moves with it.
    @{ name = 'png every sample +1 (blind spot: passes, must be reported)'
       art = $ART_PNG; want = 'PASS~'; shift = 'SYSTEMATIC SHIFT'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 1 99999999 } }
    @{ name = 'png one sample +1 must NOT read as a shift'
       art = $ART_PNG; want = 'PASS~'; shift = ''; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 1 1 } }
    @{ name = 'png every sample -1 (offset the other way)'
       art = $ART_PNG; want = 'PASS~'; shift = 'SYSTEMATIC SHIFT'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG -1 99999999 } }
    @{ name = 'png one channel +1 only (colour balance, not a pedestal)'
       art = $ART_PNG; want = 'PASS~'; shift = 'PARTIAL SHIFT'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 1 99999999 -Lane 2 } }
    @{ name = 'png every sample +2 (offset AND over the limit: both said)'
       art = $ART_PNG; want = 'FAIL'; shift = 'SYSTEMATIC SHIFT'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 2 99999999 } }

    @{ name = 'log one digit changed'; art = $ART_LOG; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_LOG $LOGMED $LOGMED2 } }
)

$good = 0; $bad = 0
$out = @()

try {
    foreach ($c in $cases) {
        $tmpdir = New-Fresh
        & $c.do $tmpdir
        $raw = & powershell -NoProfile -ExecutionPolicy Bypass -File $cmp -Fresh $tmpdir -Names $FIX 2>&1 | Out-String

        if ($null -eq $c.art) {
            # -match is case-insensitive, so 'FAIL' would match the word
            # "failed" in the summary line. Read the printed counts instead.
            $got = 'PASS'
            if ($raw -cmatch '(\d+) failed' -and [int]$matches[1] -gt 0) { $got = 'FAIL' }
            elseif ($raw -cmatch 'PASS~') { $got = 'PASS~' }
        } else {
            $line = ($raw -split "`n" | Where-Object { $_ -match [regex]::Escape($c.art) } | Select-Object -First 1)
            $got = 'NONE'
            if ($line -match '\s(PASS~|PASS|FAIL)\s') { $got = $matches[1] }
        }

        # The shift finding is asserted separately from the verdict, because the
        # whole point of it is that it is orthogonal: a case can pass the limit
        # and still have to report a shift, or fail the limit and report one too.
        # A case with shift = '' asserts the line is ABSENT, which is what stops
        # the detector from firing on ordinary rounding noise.
        $wantShift = ''
        if ($c.ContainsKey('shift')) { $wantShift = $c.shift }
        $gotShift = ''
        if     ($raw -cmatch 'SYSTEMATIC SHIFT') { $gotShift = 'SYSTEMATIC SHIFT' }
        elseif ($raw -cmatch 'PARTIAL SHIFT')    { $gotShift = 'PARTIAL SHIFT' }

        $hit = ($got -eq $c.want) -and ($gotShift -eq $wantShift)
        if ($hit) { $good++ } else { $bad++ }
        $out += [pscustomobject]@{
            case = $c.name; want = $c.want; got = $got
            wantShift = $(if ($wantShift) { $wantShift } else { '-' })
            gotShift  = $(if ($gotShift)  { $gotShift }  else { '-' })
            verdict = $(if ($hit) { 'ok' } else { 'MISMATCH' })
        }
        Remove-Item -Recurse -Force $tmpdir
    }
} finally {
    if (Test-Path $work) { Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue }
}

$out | Format-Table -AutoSize
Write-Host ''
Write-Host "$($out.Count) negative controls: $good as expected, $bad mismatched"

# ---------------------------------------------------------------------------
# compare-reference.ps1: the mad/madn median term must not become a licence
# ---------------------------------------------------------------------------
#
# Section 7 gained `+ 1.4826*|dMediana|` in the mad/madn floor. It is a derived
# bound, but a bound that cannot fail is indistinguishable from no bound at all,
# so this proves it still refuses an error larger than itself.
#
# Self-calibrating on purpose: the perturbations are computed from the golden's
# own span and the reference's own median, so they stay meaningful when the
# goldens are recaptured. A hardcoded delta here would go stale exactly like the
# clip anchors did, and would go stale SILENTLY, by drifting to the wrong side
# of a limit instead of failing to match a string.
$refChain = Join-Path (Split-Path -Parent $here) 'referencia-cadeia.json'
$cmpRef   = Join-Path $here 'compare-reference.ps1'
$madOut   = @()

if ((Test-Path $refChain) -and (Test-Path $cmpRef)) {
    $FX2  = 'gradient'
    $recF = Join-Path $gold "$FX2-fixture.records.json"
    $cr2  = Get-Content $refChain -Raw | ConvertFrom-Json
    $e3   = $cr2.fixtures.$FX2.canais.G.estatisticaExata

    $recJ = Get-Content $recF -Raw | ConvertFrom-Json
    $sti  = 0
    for ($k2 = 0; $k2 -lt @($recJ).Count; $k2++) { if (@($recJ)[$k2].id -eq 'stretch-mtf') { $sti = $k2 } }
    $b3   = @($recJ)[$sti].before.perChannel[1]           # canal G

    $bound = [math]::Max(1e-4 * [math]::Abs([double]$e3.madn),
                         8.0 * [double]$b3.span / 65535.0 + 1.4826 * [math]::Abs([double]$b3.median - [double]$e3.median))
    $have  = [math]::Abs([double]$b3.madn - [double]$e3.madn)
    $room  = $bound - $have
    if ($room -le 0) { $room = $bound * 0.1 }

    foreach ($case in @(
        @{ label = 'madn dentro da cota'; delta = $room * 0.5;  want = 'PASS' },
        @{ label = 'madn acima da cota';  delta = $bound * 3.0; want = 'FAIL' })) {

        # Copia descartavel do diretorio inteiro de goldens, e o comparador
        # apontado para ela com -Golden. Os goldens reais nao sao tocados.
        $d2 = Join-Path $work ([guid]::NewGuid().ToString('N').Substring(0, 8))
        New-Item -ItemType Directory -Force $d2 | Out-Null
        Get-ChildItem $gold -File | Copy-Item -Destination $d2 -Force

        # Reserializa em vez de trocar literal: o valor perturbado nao precisa
        # casar com nenhuma string do arquivo, e reserializar nao pode errar o
        # alvo como uma busca por texto pode.
        $j2 = Get-Content (Join-Path $d2 "$FX2-fixture.records.json") -Raw | ConvertFrom-Json
        @($j2)[$sti].before.perChannel[1].madn = [double]$b3.madn + $case.delta
        [System.IO.File]::WriteAllText((Join-Path $d2 "$FX2-fixture.records.json"),
                                       (@($j2) | ConvertTo-Json -Depth 30))

        $csv = & powershell -NoProfile -ExecutionPolicy Bypass -File $cmpRef -Csv -Golden $d2 2>$null | ConvertFrom-Csv
        $row = $csv | Where-Object { $_.fixture -eq $FX2 -and $_.campo -eq 'corrigido.madn' -and $_.escopo -eq 'G' } | Select-Object -First 1
        $got = if ($row) { $row.resultado } else { 'NONE' }
        $madOut += [pscustomobject]@{ case = $case.label; want = $case.want; got = $got
                                      verdict = $(if ($got -eq $case.want) { 'ok' } else { 'MISMATCH' }) }
        Remove-Item -Recurse -Force $d2 -ErrorAction SilentlyContinue
    }
}

if ($madOut.Count) {
    Write-Host ''
    Write-Host 'termo da mediana no piso de mad/madn (compare-reference):'
    $madOut | Format-Table -AutoSize
    $badMad = @($madOut | Where-Object { $_.verdict -ne 'ok' }).Count
    Write-Host "$($madOut.Count) controles do termo: $(@($madOut | Where-Object { $_.verdict -eq 'ok' }).Count) como esperado, $badMad divergentes"
    $bad += $badMad
}

if ($bad -gt 0) { exit 1 }
exit 0
