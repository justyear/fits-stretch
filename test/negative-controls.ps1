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
# two columns instead, to exercise the dimension check.
function Edit-Png($dir, $file, [int]$delta, [long]$count, [switch]$Resize) {
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
        if (($i % 4) -eq 3) { continue }
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

# The numbers are read off the current goldens. Each pair sits just inside and
# just outside one specific limit, so a limit that silently widened shows up as
# a MISMATCH here instead of as a quiet pass.
#
#   median  unit rule,  max(1e-4 * ref, 4/65535)      = 6.104e-5 at ref 0.264
#   madn    span rule,  max(1e-4 * ref, 8*span/65535) = 9.851e-6 at span 0.0807
#   clip    0.05% of totalPixels                      = 270 of 540000
#
# The madn +2e-5 case is the one that matters most: it fails the span rule and
# would pass the [0,1] rule, which is six times looser at this magnitude. It is
# the only case that can tell the two rules apart.
$cases = @(
    @{ name = 'baseline, untouched'; art = $null; want = 'PASS'; do = { } }

    @{ name = 'records median +5e-5 (0.82 of limit)'; art = $ART_REC; want = 'PASS~'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '0.2640573739223316' '0.2641073739223316' } }
    @{ name = 'records median +7e-5 (1.15 of limit)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '0.2640573739223316' '0.2641273739223316' } }

    @{ name = 'records madn +8e-6 (0.81 of span limit)'; art = $ART_REC; want = 'PASS~'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '0.0199431101944289' '0.0199511101944289' } }
    @{ name = 'records madn +2e-5, fails span rule, passes [0,1] rule'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '0.0199431101944289' '0.0199631101944289' } }

    @{ name = 'records clipLow 266 -> 500 (234 of 270)'; art = $ART_REC; want = 'PASS~'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '"clipLow": 266' '"clipLow": 500' } }
    @{ name = 'records clipLow 266 -> 600 (334 of 270)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '"clipLow": 266' '"clipLow": 600' } }

    @{ name = 'records params.target nudged (input knob, exact)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '"target": 0.25,' '"target": 0.2501,' } }
    @{ name = 'records sampled 540000 -> 539999 (basis, exact)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '"sampled": 540000' '"sampled": 539999' } }
    @{ name = 'records key renamed (structural)'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '"madn"' '"madnX"' } }
    @{ name = 'records applied true -> false'; art = $ART_REC; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_REC '"applied": true' '"applied": false' } }

    @{ name = 'diag channels[0].median +5e-5'; art = $ART_DIAG; want = 'PASS~'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_DIAG '"median": 0.2640573739223316' '"median": 0.2641073739223316' } }
    @{ name = 'diag decoded.normMax nudged (off the file, exact)'; art = $ART_DIAG; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_DIAG '"normMax": 1' '"normMax": 1.0001' } }

    @{ name = 'png one sample +1'; art = $ART_PNG; want = 'PASS~'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 1 1 } }
    @{ name = 'png one sample +2'; art = $ART_PNG; want = 'FAIL'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 2 1 } }
    @{ name = 'png every sample +1 (the known blind spot)'; art = $ART_PNG; want = 'PASS~'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 1 99999999 } }
    @{ name = 'png re-encoded, pixels untouched'; art = $ART_PNG; want = 'PASS~'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 0 0 } }
    @{ name = 'png width cropped by 2'; art = $ART_PNG; want = 'FAIL'; do = { param($tmpdir)
         Edit-Png $tmpdir $ART_PNG 0 0 -Resize } }

    @{ name = 'log one digit changed'; art = $ART_LOG; want = 'FAIL'; do = { param($tmpdir)
         Edit-Text $tmpdir $ART_LOG 'median 0.26406' 'median 0.26407' } }
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

        $hit = ($got -eq $c.want)
        if ($hit) { $good++ } else { $bad++ }
        $out += [pscustomobject]@{
            case = $c.name; want = $c.want; got = $got
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
if ($bad -gt 0) { exit 1 }
exit 0
