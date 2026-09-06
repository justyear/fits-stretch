# Compares a freshly captured set of artifacts against test/golden/.
#
#   pwsh test/compare-golden.ps1 -Fresh .claude\shots -Names seestar-fixture
#
# Acceptance (modulo-0-spec.md section 0): the PNG and the log must be
# byte-identical; the diagnostics JSON must match except for `timingsMs`, which
# is wall-clock and is excised from both sides before comparing.
#
# The comparison is strict and stays strict. The one other clock the output used
# to depend on was the date printed in the log, and that is now injected
# (runPipeline's opts.now, pinned by capture-golden.js) rather than tolerated
# here — a comparator that forgives a field stops guarding it.
#
# Capture is done from the browser, since the browser is where the tool runs;
# see test/golden/MANIFEST.md for the exact procedure.

param(
    [string]   $Fresh = '.claude\shots',
    [string[]] $Names = @('seestar-fixture', 'rice-fixture', 'nonlinear-fixture')
)

$ErrorActionPreference = 'Stop'

$root   = Split-Path -Parent $PSScriptRoot
$gold   = Join-Path $PSScriptRoot 'golden'
$fresh  = if ([System.IO.Path]::IsPathRooted($Fresh)) { $Fresh } else { Join-Path $root $Fresh }
$L1     = [System.Text.Encoding]::GetEncoding(28591)

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

$fail = 0
$rows = @()

foreach ($name in $Names) {
    foreach ($kind in @('log.txt', 'diag.json', 'records.json', 'png')) {
        $g = Join-Path $gold  "$name.$kind"
        $f = Join-Path $fresh "$name.$kind"

        if (-not (Test-Path -LiteralPath $g)) { $rows += [pscustomobject]@{ artifact="$name.$kind"; result='NO GOLDEN'; detail=$g }; $fail++; continue }
        if (-not (Test-Path -LiteralPath $f)) { $rows += [pscustomobject]@{ artifact="$name.$kind"; result='NO FRESH';  detail=$f }; $fail++; continue }

        $gb = [System.IO.File]::ReadAllBytes($g)
        $fb = [System.IO.File]::ReadAllBytes($f)
        $note = 'byte-identical'

        if ($kind -eq 'diag.json') {
            $gb = Strip-Timings $gb
            $fb = Strip-Timings $fb
            $note = 'identical ignoring timingsMs'
        }

        $gh = Get-Sha256 $gb
        $fh = Get-Sha256 $fb
        if ($gh -eq $fh) {
            $rows += [pscustomobject]@{ artifact="$name.$kind"; result='PASS'; detail="$note  $($gh.Substring(0,16))  $($gb.Length) bytes" }
        } else {
            $rows += [pscustomobject]@{ artifact="$name.$kind"; result='FAIL'; detail="golden $($gh.Substring(0,16)) ($($gb.Length) B) vs fresh $($fh.Substring(0,16)) ($($fb.Length) B)" }
            $fail++
        }
    }
}

$rows | Format-Table -AutoSize -Wrap

if ($fail -gt 0) { Write-Host "$fail check(s) FAILED"; exit 1 }
Write-Host "all $($rows.Count) checks passed"
