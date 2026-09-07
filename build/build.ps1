# Assembles index.html from build/template.html + the pipeline source.
#
#   pwsh build/build.ps1           writes ../index.html
#   pwsh build/build.ps1 -Check    builds in memory and compares against the
#                                  index.html already on disk; exit 1 if they differ
#
# Why not build.mjs + esbuild, which is what modulo-0-spec.md asks for: this
# machine has no Node and no Python (NOTAS-SESSAO-FITS.md, "Harness de teste"),
# which is why the whole harness is PowerShell. At this step the pipeline is
# still a single file, so the bundle *is* that file and no bundler is involved —
# the thing being validated here is the template split and the injection, and a
# byte-for-byte concatenation validates it more strictly than a bundler could.
# When the pipeline is split into modules (spec step 3), either $Sources below
# grows into an ordered concatenation list, or esbuild is installed and called
# from here.
#
# Constraints this script must not break:
#   - no minification: the page argues for its own trustworthiness by being
#     readable to whoever downloads it
#   - no import/export in the emitted block: it is read as text and executed
#     either as a blob Worker or through new Function('self', src)
#   - byte-exact injection: no re-encoding, no line-ending translation

param([switch]$Check)

$ErrorActionPreference = 'Stop'

$here     = $PSScriptRoot
$root     = Split-Path -Parent $here
$template = Join-Path $here 'template.html'
$marker   = '<!--PIPELINE_SRC-->'

# TWO OUTPUTS FROM ONE TEMPLATE.
#
#   index.html              the download. No test hooks, and therefore no fetch
#                           anywhere in the file.
#   .claude/index-test.html the same page plus window.__loadFromURL and
#                           window.__state, which is what the golden capture
#                           opens. Lives under .claude/ with the rest of the
#                           harness, so nothing about it looks like a deliverable.
#
# They are built from the same source and both are byte-checked by -Check. That
# is the point: two artifacts that could drift are two artifacts that will, so
# the check has to cover both or it covers neither. If the published file ever
# stops matching the tested one in anything but the hooks block, -Check fails.
$outPublish = Join-Path $root 'index.html'
$outTest    = Join-Path $root '.claude\index-test.html'
$hooksStart = '/*TEST_HOOKS_START*/'
$hooksEnd   = '/*TEST_HOOKS_END*/'

# The pipeline, in the order it is emitted.
#
# These files share one scope: they are concatenated, not imported. Function
# declarations hoist, so only top-level `var` initialisation depends on this
# order — and `run.js` must stay last, because it ends with the
# self.postMessage({type:'ready'}) handshake the host waits for.
#
# The order is the order the code had inside index.html. Keeping it that way is
# what lets a pure move come out byte-identical, which is a far stronger check
# on a refactor than "the output looked the same".
$Sources = @(
    'src\pipeline\helpers.js',
    'src\pipeline\fits\header.js',
    'src\pipeline\fits\rice.js',
    'src\pipeline\fits\normalise.js',
    'src\pipeline\image.js',
    'src\pipeline\stats.js',
    'src\pipeline\cfa.js',
    'src\pipeline\steps\registry.js',
    'src\pipeline\steps\background.js',
    'src\pipeline\steps\stretch-mtf.js',
    'src\pipeline\render.js',
    'src\pipeline\log.js',
    'src\pipeline\run.js'
) | ForEach-Object { Join-Path $root $_ }

# ISO-8859-1 maps bytes to chars one for one, so string work here is byte work:
# no BOM appears, no UTF-8 sequence is touched, no newline is rewritten.
$L1 = [System.Text.Encoding]::GetEncoding(28591)

function Read-Text($path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "missing: $path" }
    return $L1.GetString([System.IO.File]::ReadAllBytes($path))
}

$tpl = Read-Text $template

$at = $tpl.IndexOf($marker)
if ($at -lt 0) { throw "marker $marker not found in $template" }
if ($tpl.IndexOf($marker, $at + 1) -ge 0) { throw "marker $marker appears more than once in $template" }

$bundle = ($Sources | ForEach-Object { Read-Text $_ }) -join ''

# The marker sits on its own line; the source already ends in a newline, so the
# marker's own line break is consumed with it.
$needle = $marker
if ($tpl.Substring($at + $marker.Length, 1) -eq "`n") { $needle = $marker + "`n" }

$withHooks = $tpl.Substring(0, $at) + $bundle + $tpl.Substring($at + $needle.Length)

# The publication build is the test build minus exactly the marked block. Cut by
# marker rather than rebuilt from a second template, so the two can differ in
# that block and in nothing else.
$hs = $withHooks.IndexOf($hooksStart)
$he = $withHooks.IndexOf($hooksEnd)
if ($hs -lt 0 -or $he -lt 0) { throw "test-hook markers not found in $template" }
if ($withHooks.IndexOf($hooksStart, $hs + 1) -ge 0) { throw 'TEST_HOOKS_START appears more than once' }
if ($he -lt $hs) { throw 'TEST_HOOKS_END appears before TEST_HOOKS_START' }
$cut = $he + $hooksEnd.Length
if ($withHooks.Substring($cut, 1) -eq "`n") { $cut += 1 }
$publish = $withHooks.Substring(0, $hs) + $withHooks.Substring($cut)

$bytesTest    = $L1.GetBytes($withHooks)
$bytesPublish = $L1.GetBytes($publish)

function Get-Sha256([byte[]]$b) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return -join ($sha.ComputeHash($b) | ForEach-Object { $_.ToString('x2') }) }
    finally { $sha.Dispose() }
}

$hashTest    = Get-Sha256 $bytesTest
$hashPublish = Get-Sha256 $bytesPublish

# The published file must not contain what the block contained. Checked on the
# built bytes rather than trusted from the cut, because a second copy of any of
# these outside the markers would defeat the whole exercise silently.
$forbidden = @('__loadFromURL', '__state', 'fetch(')
$leaks = @()
foreach ($f in $forbidden) { if ($publish.Contains($f)) { $leaks += $f } }

if ($Check) {
    $fail = 0
    foreach ($pair in @(@($outPublish, $bytesPublish, $hashPublish, 'publicacao'),
                        @($outTest,    $bytesTest,    $hashTest,    'com ganchos'))) {
        $path = $pair[0]; $bytes = $pair[1]; $hash = $pair[2]; $label = $pair[3]
        if (-not (Test-Path -LiteralPath $path)) {
            Write-Host ("CHECK FAIL - {0} ausente ({1})" -f $path, $label); $fail++; continue
        }
        $have = [System.IO.File]::ReadAllBytes($path)
        $haveHash = Get-Sha256 $have
        Write-Host ("{0,-12} built {1,7} bytes {2}" -f $label, $bytes.Length, $hash.Substring(0, 16))
        Write-Host ("{0,-12} disk  {1,7} bytes {2}" -f '', $have.Length, $haveHash.Substring(0, 16))
        if ($hash -ne $haveHash) { Write-Host ("CHECK FAIL - {0} difere" -f $label); $fail++ }
    }
    if ($leaks.Count) { Write-Host ("CHECK FAIL - vazou para a publicacao: " + ($leaks -join ', ')); $fail++ }
    else { Write-Host ('publicacao limpa: sem ' + ($forbidden -join ', ')) }
    if ($fail -gt 0) { exit 1 }
    Write-Host 'CHECK PASS - os dois identicos'; exit 0
}

if ($leaks.Count) { throw ('the publication build still contains: ' + ($leaks -join ', ')) }

$testDir = Split-Path -Parent $outTest
if (-not (Test-Path -LiteralPath $testDir)) { New-Item -ItemType Directory -Path $testDir | Out-Null }
[System.IO.File]::WriteAllBytes($outPublish, $bytesPublish)
[System.IO.File]::WriteAllBytes($outTest, $bytesTest)
Write-Host ("wrote {0} - {1} bytes - sha256 {2}" -f $outPublish, $bytesPublish.Length, $hashPublish)
Write-Host ("wrote {0} - {1} bytes - sha256 {2}" -f $outTest, $bytesTest.Length, $hashTest)
Write-Host ('publicacao limpa: sem ' + ($forbidden -join ', '))
foreach ($s in $Sources) { Write-Host ("  <- {0} ({1} bytes)" -f $s, (Get-Item -LiteralPath $s).Length) }
