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
$out      = Join-Path $root 'index.html'
$marker   = '<!--PIPELINE_SRC-->'

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

$html  = $tpl.Substring(0, $at) + $bundle + $tpl.Substring($at + $needle.Length)
$bytes = $L1.GetBytes($html)

function Get-Sha256([byte[]]$b) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return -join ($sha.ComputeHash($b) | ForEach-Object { $_.ToString('x2') }) }
    finally { $sha.Dispose() }
}

$hash = Get-Sha256 $bytes

if ($Check) {
    if (-not (Test-Path -LiteralPath $out)) { Write-Host "CHECK FAIL - no $out to compare against"; exit 1 }
    $have = [System.IO.File]::ReadAllBytes($out)
    $haveHash = Get-Sha256 $have
    Write-Host ("built  {0,7} bytes  sha256 {1}" -f $bytes.Length, $hash)
    Write-Host ("ondisk {0,7} bytes  sha256 {1}" -f $have.Length, $haveHash)
    if ($hash -eq $haveHash) { Write-Host 'CHECK PASS - identical'; exit 0 }
    Write-Host 'CHECK FAIL - differs'; exit 1
}

[System.IO.File]::WriteAllBytes($out, $bytes)
Write-Host ("wrote {0} - {1} bytes - sha256 {2}" -f $out, $bytes.Length, $hash)
foreach ($s in $Sources) { Write-Host ("  <- {0} ({1} bytes)" -f $s, (Get-Item -LiteralPath $s).Length) }
