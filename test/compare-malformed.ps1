# Compara os vereditos do corpus malformado contra test/golden/malformed.json.
#
#   powershell -File test\compare-malformed.ps1
#
# ASCII apenas -- ver o cabecalho de compare-golden.ps1.
#
# O QUE ESTE COMPARADOR PERGUNTA, e nao e o mesmo que os outros perguntam.
#
# compare-golden pergunta "a saida de hoje e a de ontem?". Aqui a pergunta e
# "isto continua sendo recusado?", e a falha que importa e assimetrica:
#
#   rejeita -> aceita   e a falha grave. Um arquivo que a pagina recusava passou
#                       a produzir imagem, e a imagem vem de bytes que ninguem
#                       verificou. Para uma pagina cujo argumento e que nada
#                       acontece com os pixels sem estar escrito, esta e a pior
#                       forma de errar, porque parece uma rodada bem-sucedida.
#
#   aceita -> rejeita   tambem e falha, e mais facil de notar: alguem apertou
#                       uma validacao demais e um arquivo legitimo parou de
#                       abrir. a8, a9, a10, c2, e2, e3, e6, e7 e e8 estao aqui
#                       exatamente para isso -- sao os casos estranhos que TEM
#                       que passar.
#
#   kind diferente      e falha. A classe do erro e o que decide a mensagem que
#                       a pessoa le, e uma mensagem errada manda ela para o
#                       lugar errado. Foi assim que um arquivo de 5 kB pediu
#                       para fechar as outras abas.
#
# ANTES DE OLHAR QUALQUER VEREDITO, os arquivos sao regerados e conferidos por
# sha256. Se a geracao divergir numa outra maquina, o teste diz isso, em vez de
# comparar em silencio outra coisa.

param([switch]$SkipGenerate)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath
$root = Split-Path -Parent $here

$expectPath  = Join-Path $here 'golden\malformed.json'
$resultPath  = Join-Path $root '.claude\shots\malformed.results.json'
$corpusDir   = Join-Path $here 'malformed'

if (-not (Test-Path $expectPath)) { throw "faltando: $expectPath" }
if (-not (Test-Path $resultPath)) {
    throw "faltando: $resultPath -- rode a captura no navegador (await __captureAll())"
}

$expect = (Get-Content $expectPath -Raw | ConvertFrom-Json)
$got    = (Get-Content $resultPath -Raw | ConvertFrom-Json)

# ---- 1. os arquivos sao os que o golden descreve? -------------------------
if (-not $SkipGenerate) {
    & powershell -NoProfile -File (Join-Path $here 'make-malformed.ps1') | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'make-malformed.ps1 falhou' }
}

$hashFail = 0
foreach ($name in $expect.casos.PSObject.Properties.Name) {
    $p = Join-Path $corpusDir $name
    if (-not (Test-Path $p)) {
        Write-Host ('CORPUS FAIL - {0} nao foi gerado' -f $name); $hashFail++; continue
    }
    $h = (Get-FileHash -Algorithm SHA256 $p).Hash.ToLower()
    if ($h -ne $expect.casos.$name.sha256) {
        Write-Host ('CORPUS FAIL - {0}: sha256 {1}, o golden diz {2}' -f `
            $name, $h.Substring(0,16), $expect.casos.$name.sha256.Substring(0,16))
        $hashFail++
    }
}
if ($hashFail -gt 0) {
    Write-Host ''
    Write-Host ('{0} arquivo(s) do corpus nao batem com o golden. Os vereditos nao foram comparados:' -f $hashFail)
    Write-Host 'comparar vereditos de arquivos diferentes dos descritos responderia a pergunta errada.'
    exit 1
}
Write-Host ('corpus: {0} arquivos regerados, todos com o sha256 do golden' -f `
    $expect.casos.PSObject.Properties.Name.Count)
Write-Host ''

# ---- 2. os vereditos --------------------------------------------------------
$rows = New-Object System.Collections.ArrayList
$fail = 0
$maxMs = 0

foreach ($name in ($expect.casos.PSObject.Properties.Name | Sort-Object)) {
    $e = $expect.casos.$name
    $g = $got.casos.$name

    $quero = if ($e.veredito -eq 'aceita') { 'aceita ' + $e.dims } else { 'rejeita ' + $e.kind }

    if ($null -eq $g) {
        [void]$rows.Add([pscustomobject]@{ caso=$name; quero=$quero; tenho='(ausente)'; ms=''; v='FAIL' })
        $fail++; continue
    }

    $tenho = if ($g.veredito -eq 'aceita') { 'aceita ' + $g.dims } else { 'rejeita ' + $g.kind }
    if ($g.ms -gt $maxMs) { $maxMs = $g.ms }

    $ok = ($quero -eq $tenho)
    $v = if ($ok) { 'ok' } elseif ($e.veredito -eq 'rejeita' -and $g.veredito -eq 'aceita') { 'ACEITOU' } else { 'FAIL' }
    if (-not $ok) { $fail++ }

    [void]$rows.Add([pscustomobject]@{ caso=$name; quero=$quero; tenho=$tenho; ms=$g.ms; v=$v })
}

$rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host

# ---- 3. nenhum caso pode ter demorado ---------------------------------------
# "parou" e metade da afirmacao. Um arquivo que trava a aba falha diferente de
# um que da erro, e o tempo e o que separa os dois. O teto e frouxo de proposito:
# hoje o pior caso e o cabecalho de 4 MB, em dezenas de milissegundos, e o que
# este limite pega e a ordem de grandeza, nao a variacao de maquina.
$LIMITE_MS = 3000
$lentos = $rows | Where-Object { $_.ms -ne '' -and [int]$_.ms -gt $LIMITE_MS }
if ($lentos) {
    Write-Host ('TEMPO FAIL - caso(s) acima de {0} ms:' -f $LIMITE_MS)
    foreach ($l in $lentos) { Write-Host ('  {0}  {1} ms' -f $l.caso, $l.ms) }
    $fail++
}

Write-Host ''
Write-Host ('{0} casos: {1} como esperado, {2} divergentes  |  pior tempo {3} ms' -f `
    $rows.Count, ($rows.Count - $fail), $fail, $maxMs)

$aceitou = $rows | Where-Object { $_.v -eq 'ACEITOU' }
if ($aceitou) {
    Write-Host ''
    Write-Host 'ATENCAO - arquivo(s) que eram recusados e passaram a ser aceitos:'
    foreach ($a in $aceitou) { Write-Host ('  {0}: {1}' -f $a.caso, $expect.casos.($a.caso).porque) }
}

if ($fail -gt 0) { exit 1 }
Write-Host 'MALFORMED PASS'
exit 0
