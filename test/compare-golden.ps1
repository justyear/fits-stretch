# Compares a freshly captured set of artifacts against test/golden/.
#
#   pwsh test/compare-golden.ps1 -Fresh .claude\shots -Names seestar-fixture
#   pwsh test/compare-golden.ps1 -Detail          # list every tolerated value
#
# ---------------------------------------------------------------------------
# Acceptance criterion - changed in Modulo 1, step 1 of section 6
# ---------------------------------------------------------------------------
#
# Modulo 0 asked for byte-identity on all four artifacts. That criterion dies
# when the chain carries full float and `quantise` runs once at the end
# (modulo-1-spec.md section 0), because the LUT stops being the authority on
# what a pixel becomes and the final rounding turns into real quantisation.
#
# So this comparator now answers a two-part question, and says which part it
# answered:
#
#   PASS   the bytes are identical. Still the strongest answer, still reported
#          whenever it is true, for every artifact.
#   PASS~  the bytes differ and every difference is inside the tolerance of
#          modulo-0-spec.md section 7. The worst case is printed as a fraction
#          of the limit, so drift is visible instead of merely forgiven.
#   FAIL   something is outside the tolerance, or is structural.
#
# The tolerance is entered BEFORE the chain becomes float, deliberately. If it
# arrived afterwards the harness would reprove correct work on the first run and
# there would be no way to tell that from a real regression.
#
# What is tolerated, and what is not:
#
#   records.json   before/after perChannel measurements only. `params`, `notes`,
#                  `id`, `applied`, `sampled`, `stride`, `nan`, `totalPixels`
#                  are exact - they are the basis of the measurement, not the
#                  measurement, and drift there is a different frame, not noise.
#   diag.json      the same per-channel statistics, and globalMedian.
#                  `decoded`, `cfa`, `header`, `view`, cards: exact. Those are
#                  read off the file and must not move at all.
#   png            per pixel, per channel, up to 1 level (section 7).
#   log.txt        EXACT. No tolerance, on purpose: every number the log prints
#                  comes from record.before, and buildLog is handed
#                  records[0].before.perChannel, which no step downstream can
#                  move. A log FAIL beside a records PASS is therefore a real
#                  finding and reads as one. The day a printed 5-decimal number
#                  sits on a rounding boundary and flips, recapture - do not
#                  loosen this.
#
# The blind spot, and what is done about it: a whole image shifted by exactly 1
# level passes the PNG check. That is what "up to 1 level" means, section 7
# chose it, and tightening it would reprove correct work instead.
#
# So the shift is detected on a different axis rather than forgiven. Alongside
# the absolute-difference limit the comparator takes the MEDIAN OF THE SIGNED
# difference, per colour channel. Rounding noise is symmetric - a pixel near a
# boundary rounds up about as often as down - so its signed median is 0. A
# constant offset moves every pixel the same way and its signed median moves
# with it. When all three colour channels have a non-zero signed median with the
# same sign, the comparator prints SYSTEMATIC SHIFT, in the row and in a note.
#
# This is aimed at one specific failure that has not been written yet: the
# pedestal of `out = in - model + pedestal` (modulo-1-spec.md section 2.4). A
# wrong pedestal displaces the entire frame by a constant, which is precisely
# the thing the per-pixel limit cannot see. It reports, it does not fail - a
# legitimate rounding change and a bad pedestal are told apart by the operator
# reading one line, not by a threshold guessing.
#
# `timingsMs` is wall-clock and is excised from both sides of diag.json before
# comparing, as it always was.
#
# ASCII only, no BOM. PowerShell 5.1 reads an unmarked .ps1 as CP1252, where the
# third byte of a UTF-8 em dash is a curly quote and silently ends a string.
#
# Capture is done from the browser, since the browser is where the tool runs;
# see test/golden/MANIFEST.md for the exact procedure.

param(
    [string]   $Fresh = '.claude\shots',
    [string[]] $Names = @('seestar-fixture', 'rice-fixture', 'nonlinear-fixture'),
    [switch]   $Detail
)

$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $PSScriptRoot
$gold   = Join-Path $PSScriptRoot 'golden'
$fresh  = if ([System.IO.Path]::IsPathRooted($Fresh)) { $Fresh } else { Join-Path $root $Fresh }
$L1     = [System.Text.Encoding]::GetEncoding(28591)

# --- tolerances, modulo-0-spec.md section 7 --------------------------------
$TOL_REL   = 1e-4          # relative, all measured values
$TOL_UNIT  = 4 / 65535     # absolute floor for values on the [0,1] axis
$TOL_MADK  = 8 / 65535     # absolute floor for mad/madn, in units of `span`
$TOL_COUNT = 0.0005        # clip counts: 0.05% of the channel's pixels
$TOL_PCT   = 0.05          # clipPct is already a percentage: 0.05 points
$TOL_LEVEL = 1             # 8-bit output, per pixel, per channel

Add-Type -AssemblyName System.Drawing

# A byte-by-byte histogram of |a-b| written in PowerShell would take about a
# minute per PNG on 10 MB of samples. This is the same loop, compiled once.
if (-not ('GoldenDiff' -as [type])) {
    Add-Type -TypeDefinition @'
public static class GoldenDiff {
    public static long[] Hist(byte[] a, byte[] b, int len) {
        long[] h = new long[256];
        for (int i = 0; i < len; i++) {
            int d = a[i] - b[i];
            if (d < 0) d = -d;
            h[d]++;
        }
        return h;
    }

    // Signed fresh-minus-golden differences, one histogram per byte lane.
    // Format32bppArgb is B,G,R,A in memory on a little-endian machine.
    // Flat layout: lane c occupies [c*511 .. c*511+510], index = diff + 255.
    public static long[] SignedHist(byte[] a, byte[] b, int len) {
        long[] h = new long[4 * 511];
        for (int i = 0; i + 3 < len; i += 4) {
            for (int c = 0; c < 4; c++) {
                int d = b[i + c] - a[i + c];
                h[c * 511 + d + 255]++;
            }
        }
        return h;
    }
}
'@
}

function Get-Sha256([byte[]]$b) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return -join ($sha.ComputeHash($b) | ForEach-Object { $_.ToString('x2') }) }
    finally { $sha.Dispose() }
}

# The timings block is pretty-printed at indent 2, so it closes on a "  }" line.
function Strip-Timings([byte[]]$b) {
    $s = $L1.GetString($b)
    $s = [regex]::Replace($s, '(?s)\r?\n\s*"timingsMs": \{.*?\n  \},?', '')
    if ($s.Contains('timingsMs')) { throw 'timingsMs block did not match the excision pattern - the comparison would be wrong' }
    return $L1.GetBytes($s)
}

function Test-Numeric($v) {
    return ($v -is [double] -or $v -is [single] -or $v -is [int] -or `
            $v -is [long] -or $v -is [decimal] -or $v -is [int16] -or $v -is [byte])
}

function Get-Prop($obj, [string]$name) {
    if ($null -eq $obj) { return $null }
    $p = $obj.PSObject.Properties[$name]
    if ($null -eq $p) { return $null }
    return $p.Value
}

# The width of the second histogram in stats.js, which is the resolution of mad
# and madn. Prefer the recorded field; fall back to the definition; never zero.
function Get-Span($ctx) {
    $s = Get-Prop $ctx 'span'
    if ((Test-Numeric $s) -and $s -gt 0) { return [double]$s }
    $q1 = Get-Prop $ctx 'q1'; $q3 = Get-Prop $ctx 'q3'
    if ((Test-Numeric $q1) -and (Test-Numeric $q3)) {
        $sp = 3 * ([double]$q3 - [double]$q1)
        if ($sp -gt 0) { return $sp }
    }
    return 1 / 65535
}

# Returns $null when the leaf must be exact, otherwise the absolute tolerance.
# Classification is by PATH, never by leaf name alone: `target` under .params is
# an input knob and must be exact, while `target` under .perChannel[i] is a
# measured quantity. Same word, opposite rule.
function Get-Tolerance([string]$kind, [string]$path, $refVal, $ctx) {
    if (-not (Test-Numeric $refVal)) { return $null }
    $r = [Math]::Abs([double]$refVal)

    $unit = [Math]::Max($TOL_REL * $r, $TOL_UNIT)
    $madn = [Math]::Max($TOL_REL * $r, $TOL_MADK * (Get-Span $ctx))

    if ($kind -eq 'records.json') {
        $stat = '^\[\d+\]\.(before|after)\.perChannel\[\d+\]\.'
        if ($path -match ($stat + '(median|q1|q3|p001|p999|shadows|midtones|target|scale|span)$')) { return $unit }
        if ($path -match ($stat + '(mad|madn)$'))                                                  { return $madn }
        if ($path -match ($stat + '(outLow|outHigh|clipLow|clipHigh)$')) {
            $tp = Get-Prop $ctx 'totalPixels'
            if (Test-Numeric $tp) { return $TOL_COUNT * [double]$tp }
            return 0
        }
        if ($path -match ($stat + 'clipPct$')) { return $TOL_PCT }
        return $null
    }

    if ($kind -eq 'diag.json') {
        if ($path -match '^channels\[\d+\]\.(median|q1|q3|shadows|midtones|target)$') { return $unit }
        if ($path -match '^channels\[\d+\]\.madn$')                                   { return $madn }
        if ($path -match '^channels\[\d+\]\.(pixelsBlack|pixelsWhite)$') {
            $tp = Get-Prop $ctx 'totalPixels'
            if (Test-Numeric $tp) { return $TOL_COUNT * [double]$tp }
            return 0
        }
        if ($path -eq 'linearity.globalMedian') { return $unit }
        return $null
    }

    return $null
}

# Walks both trees together. Any structural difference - a missing key, an extra
# key, a different array length, a changed type - is a failure, and is not
# something a tolerance can reach. `$st.skip` holds paths already judged by an
# earlier pass, so no leaf is counted twice.
function Compare-Node($g, $f, [string]$path, [string]$kind, $st) {
    if ($st.skip.ContainsKey($path)) { return }

    if ($null -eq $g -and $null -eq $f) { return }
    if ($null -eq $g -or  $null -eq $f) { [void]$st.fails.Add("$path : one side is null ($g vs $f)"); return }

    if ($g -is [System.Management.Automation.PSCustomObject]) {
        if (-not ($f -is [System.Management.Automation.PSCustomObject])) {
            [void]$st.fails.Add("$path : golden is an object, fresh is not"); return
        }
        $gk = @($g.PSObject.Properties.Name)
        $fk = @($f.PSObject.Properties.Name)
        foreach ($k in $gk) { if ($fk -notcontains $k) { [void]$st.fails.Add("$path.$k : missing from fresh") } }
        foreach ($k in $fk) { if ($gk -notcontains $k) { [void]$st.fails.Add("$path.$k : not in golden") } }
        foreach ($k in $gk) {
            if ($fk -contains $k) {
                $sub = if ($path) { "$path.$k" } else { $k }
                Compare-Node $g.$k $f.$k $sub $kind $st
            }
        }
        return
    }

    if ($g -is [object[]]) {
        if (-not ($f -is [object[]])) { [void]$st.fails.Add("$path : golden is an array, fresh is not"); return }
        if ($g.Count -ne $f.Count) { [void]$st.fails.Add("$path : length $($g.Count) vs $($f.Count)"); return }
        for ($i = 0; $i -lt $g.Count; $i++) { Compare-Node $g[$i] $f[$i] "$path[$i]" $kind $st }
        return
    }

    if (Test-Numeric $g) {
        if (-not (Test-Numeric $f)) { [void]$st.fails.Add("$path : golden is numeric, fresh is '$f'"); return }
        $gd = [double]$g; $fd = [double]$f
        if ($gd -eq $fd) { return }

        $tol = Get-Tolerance $kind $path $g $st.ctx
        if ($null -eq $tol) { [void]$st.fails.Add("$path : $gd vs $fd (exact field)"); return }

        $d = [Math]::Abs($gd - $fd)
        if ($d -le $tol) {
            $frac = 0.0
            if ($tol -gt 0) { $frac = $d / $tol }
            [void]$st.tol.Add([pscustomobject]@{ path = $path; golden = $gd; fresh = $fd
                                                 diff = $d; limit = $tol; frac = $frac })
        } else {
            $over = ''
            if ($tol -gt 0) { $over = ' = {0:N2}x the limit' -f ($d / $tol) }
            [void]$st.fails.Add(("$path : $gd vs $fd, abs diff {0:E3} over limit {1:E3}{2}" -f $d, $tol, $over))
        }
        return
    }

    if ($g -ne $f) { [void]$st.fails.Add("$path : '$g' vs '$f'") }
}

# The containing object has to be reachable when a leaf is classified, because
# the mad/madn limit is sized by that channel's `span` and the clip limit by its
# `totalPixels`. Walking the perChannel blocks first, each with its own `ctx`,
# is cheaper and clearer than threading a parent through every recursion.
function Compare-Json([byte[]]$gb, [byte[]]$fb, [string]$kind) {
    $st = @{ fails = New-Object System.Collections.ArrayList
             tol   = New-Object System.Collections.ArrayList
             ctx   = $null
             skip  = @{} }

    $gj = $L1.GetString($gb) | ConvertFrom-Json
    $fj = $L1.GetString($fb) | ConvertFrom-Json

    $blocks = New-Object System.Collections.ArrayList
    if ($kind -eq 'records.json') {
        $ga = @($gj); $fa = @($fj)
        if ($ga.Count -eq $fa.Count) {
            for ($i = 0; $i -lt $ga.Count; $i++) {
                foreach ($side in @('before', 'after')) {
                    $gs = Get-Prop $ga[$i] $side
                    $fs = Get-Prop $fa[$i] $side
                    if ($null -eq $gs -or $null -eq $fs) { continue }
                    $gc = @(Get-Prop $gs 'perChannel'); $fc = @(Get-Prop $fs 'perChannel')
                    if ($gc.Count -eq 0 -or $gc.Count -ne $fc.Count) { continue }
                    for ($c = 0; $c -lt $gc.Count; $c++) {
                        [void]$blocks.Add([pscustomobject]@{ g = $gc[$c]; f = $fc[$c]
                                                             path = "[$i].$side.perChannel[$c]" })
                    }
                }
            }
        }
    } elseif ($kind -eq 'diag.json') {
        $gc = @(Get-Prop $gj 'channels'); $fc = @(Get-Prop $fj 'channels')
        if ($gc.Count -gt 0 -and $gc.Count -eq $fc.Count) {
            for ($c = 0; $c -lt $gc.Count; $c++) {
                [void]$blocks.Add([pscustomobject]@{ g = $gc[$c]; f = $fc[$c]; path = "channels[$c]" })
            }
        }
    }

    foreach ($b in $blocks) {
        $st.ctx = $b.g
        Compare-Node $b.g $b.f $b.path $kind $st
        $st.skip[$b.path] = $true
    }

    $st.ctx = $null
    Compare-Node $gj $fj '' $kind $st
    return $st
}

# Median and mean of the signed fresh-minus-golden difference, per byte lane.
#
# This is the one statistic that separates rounding noise from an offset.
# Rounding noise is symmetric: a pixel that lands near a boundary rounds up
# about as often as down, so the signed median is 0 and the signed mean is near
# 0. A constant offset is not symmetric at all - it moves every pixel the same
# way, and the signed median moves with it.
#
# It matters because "up to 1 level per pixel" forgives a whole frame shifted by
# 1 level, and that is exactly the shape of a wrong pedestal: `out = in - model
# + pedestal` with the wrong pedestal displaces the entire frame by a constant
# (modulo-1-spec.md section 2.4). The tolerance cannot catch it and should not
# be tightened to try - the fix is to report it, not to fail it.
function Get-SignedStats($signedHist, [long]$pixels) {
    $out = @()
    for ($c = 0; $c -lt 4; $c++) {
        $acc = 0L; $sum = 0.0; $med = 0; $found = $false
        for ($d = -255; $d -le 255; $d++) {
            $n = $signedHist[$c * 511 + $d + 255]
            if ($n -eq 0) { continue }
            $acc += $n; $sum += [double]$n * $d
            if (-not $found -and ($acc * 2) -ge $pixels) { $med = $d; $found = $true }
        }
        $mean = 0.0
        if ($pixels -gt 0) { $mean = $sum / $pixels }
        $out += [pscustomobject]@{ lane = @('B', 'G', 'R', 'A')[$c]; median = $med; mean = $mean }
    }
    return $out
}

function Read-Png([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $ms = New-Object System.IO.MemoryStream(,$bytes)
    $bmp = New-Object System.Drawing.Bitmap($ms)
    try {
        $rect = New-Object System.Drawing.Rectangle 0, 0, $bmp.Width, $bmp.Height
        $bd = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            $len = [Math]::Abs($bd.Stride) * $bmp.Height
            $buf = New-Object byte[] $len
            [System.Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $buf, 0, $len)
            return [pscustomobject]@{ w = $bmp.Width; h = $bmp.Height; data = $buf; len = $len }
        } finally { $bmp.UnlockBits($bd) }
    } finally { $bmp.Dispose(); $ms.Dispose() }
}

$fail  = 0
$rows  = @()
$notes = @()

foreach ($name in $Names) {
    foreach ($kind in @('log.txt', 'diag.json', 'records.json', 'png')) {
        $g = Join-Path $gold  "$name.$kind"
        $f = Join-Path $fresh "$name.$kind"

        if (-not (Test-Path -LiteralPath $g)) { $rows += [pscustomobject]@{ artifact = "$name.$kind"; result = 'NO GOLDEN'; detail = $g }; $fail++; continue }
        if (-not (Test-Path -LiteralPath $f)) { $rows += [pscustomobject]@{ artifact = "$name.$kind"; result = 'NO FRESH';  detail = $f }; $fail++; continue }

        $gb = [System.IO.File]::ReadAllBytes($g)
        $fb = [System.IO.File]::ReadAllBytes($f)
        $note = 'byte-identical'

        if ($kind -eq 'diag.json') {
            $gb = Strip-Timings $gb
            $fb = Strip-Timings $fb
            $note = 'byte-identical ignoring timingsMs'
        }

        $gh = Get-Sha256 $gb
        $fh = Get-Sha256 $fb

        # The strongest answer first, and it is still available to every
        # artifact. Tolerance is only consulted once the bytes have differed.
        if ($gh -eq $fh) {
            $rows += [pscustomobject]@{ artifact = "$name.$kind"; result = 'PASS'
                                        detail = "$note  $($gh.Substring(0,16))  $($gb.Length) bytes" }
            continue
        }

        if ($kind -eq 'log.txt') {
            $rows += [pscustomobject]@{ artifact = "$name.$kind"; result = 'FAIL'
                detail = "log is compared exactly; golden $($gh.Substring(0,16)) ($($gb.Length) B) vs fresh $($fh.Substring(0,16)) ($($fb.Length) B)" }
            $fail++
            continue
        }

        if ($kind -eq 'png') {
            $gp = Read-Png $g
            $fp = Read-Png $f
            if ($gp.w -ne $fp.w -or $gp.h -ne $fp.h) {
                $rows += [pscustomobject]@{ artifact = "$name.$kind"; result = 'FAIL'
                                            detail = "dimensions $($gp.w)x$($gp.h) vs $($fp.w)x$($fp.h)" }
                $fail++
                continue
            }
            $hist = [GoldenDiff]::Hist($gp.data, $fp.data, $gp.len)
            $maxd = 0
            for ($d = 255; $d -ge 1; $d--) { if ($hist[$d] -gt 0) { $maxd = $d; break } }
            $ndiff = 0L; $sum = 0.0
            for ($d = 1; $d -le 255; $d++) { $ndiff += $hist[$d]; $sum += $hist[$d] * $d }
            $pct  = 100.0 * $ndiff / $gp.len
            $mean = 0.0
            if ($ndiff -gt 0) { $mean = $sum / $ndiff }

            # Computed before the verdict, so it is reported whichever way the
            # verdict goes. A frame that both shifts and breaks the limit should
            # say both things.
            $sst   = Get-SignedStats ([GoldenDiff]::SignedHist($gp.data, $fp.data, $gp.len)) ([long]($gp.len / 4))
            $col   = @($sst[0], $sst[1], $sst[2])
            $nzero = @($col | Where-Object { $_.median -ne 0 }).Count
            $pos   = @($col | Where-Object { $_.median -gt 0 }).Count
            $neg   = @($col | Where-Object { $_.median -lt 0 }).Count
            $shift = ''
            if ($nzero -eq 3 -and ($pos -eq 3 -or $neg -eq 3)) { $shift = 'SYSTEMATIC SHIFT' }
            elseif ($nzero -gt 0)                              { $shift = 'PARTIAL SHIFT' }

            if ($shift) {
                # The sign is the finding, so it is always printed: the section
                # format "+0;-0;0" shows it for positive and negative alike.
                $per = ($col | ForEach-Object { "{0} {1,3:+0;-0;0}" -f $_.lane, $_.median }) -join '  '
                $avg = ($col | ForEach-Object { "{0} {1,8:+0.000;-0.000;0.000}" -f $_.lane, $_.mean }) -join '  '
                $notes += "$name.$kind  $shift  signed median (fresh minus golden): $per   signed mean: $avg"
                if ($shift -eq 'SYSTEMATIC SHIFT') {
                    $notes += "    Every colour channel moved the same way. Rounding noise has a signed median of zero; a constant offset does not."
                    $notes += "    This is the shape of a wrong pedestal: out = in - model + pedestal displaces the whole frame by a constant"
                    $notes += "    (modulo-1-spec.md section 2.4), and the per-pixel limit forgives it. Reported, not failed. Read it before accepting."
                } else {
                    $notes += "    Some but not all colour channels moved, or they moved in opposite directions. Not rounding noise either. Worth reading."
                }
            }

            $tag = ''
            if ($shift) { $tag = "  [$shift]" }

            if ($maxd -le $TOL_LEVEL) {
                $rows += [pscustomobject]@{ artifact = "$name.$kind"; result = 'PASS~'
                    detail = ("{0}x{1}  {2:N0}/{3:N0} samples differ ({4:N3}%), max {5} level (limit {6}), mean abs {7:N2}{8}" -f `
                              $gp.w, $gp.h, $ndiff, $gp.len, $pct, $maxd, $TOL_LEVEL, $mean, $tag) }
            } else {
                $rows += [pscustomobject]@{ artifact = "$name.$kind"; result = 'FAIL'
                    detail = ("{0}x{1}  max {2} levels over limit {3}; {4:N0} samples differ ({5:N3}%){6}" -f `
                              $gp.w, $gp.h, $maxd, $TOL_LEVEL, $ndiff, $pct, $tag) }
                $fail++
            }
            continue
        }

        # records.json / diag.json
        $st = Compare-Json $gb $fb $kind
        if ($st.fails.Count -gt 0) {
            $rows += [pscustomobject]@{ artifact = "$name.$kind"; result = 'FAIL'
                detail = ("$($st.fails.Count) field(s) outside tolerance, $($st.tol.Count) within") }
            foreach ($x in $st.fails) { $notes += "$name.$kind  FAIL  $x" }
            $fail++
        } else {
            $worst = $st.tol | Sort-Object frac -Descending | Select-Object -First 1
            $w = 'no numeric differences'
            if ($worst) { $w = ("worst {0:N2} of limit at {1}" -f $worst.frac, $worst.path) }
            $rows += [pscustomobject]@{ artifact = "$name.$kind"; result = 'PASS~'
                                        detail = ("$($st.tol.Count) value(s) within tolerance, $w") }
        }
        if ($Detail) {
            foreach ($x in ($st.tol | Sort-Object frac -Descending)) {
                $notes += ("  {0,-48} {1,-22} vs {2,-22} abs {3:E3}  limit {4:E3}  {5:N2}x" -f `
                           $x.path, $x.golden, $x.fresh, $x.diff, $x.limit, $x.frac)
            }
        }
    }
}

$rows | Format-Table -AutoSize -Wrap

if ($notes.Count) {
    Write-Host ''
    foreach ($n in $notes) { Write-Host $n }
}

$exact = @($rows | Where-Object { $_.result -eq 'PASS'  }).Count
$tolp  = @($rows | Where-Object { $_.result -eq 'PASS~' }).Count
Write-Host ''
Write-Host "$($rows.Count) checks: $exact byte-identical, $tolp within tolerance, $fail failed"

if ($fail -gt 0) { exit 1 }
exit 0
