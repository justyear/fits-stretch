# O catalogo de esticamento contra o texto que os escritores gravaram de verdade.
#
#   powershell -File test\compare-catalogo.ps1
#
# ASCII apenas -- ver o cabecalho de compare-golden.ps1.
#
# POR QUE ESTE ARQUIVO EXISTE.
#
# Os fixtures de escritor afirmam o rotulo de CINCO saidas. O catalogo tem oito
# regras, e o GHS simples, o asinh, o midtone e o autostretch ficaram de fora da
# lista de fixtures -- o texto real deles estava medido e nenhum teste o lia.
# Aqui entra TODA linha de HISTORY medida: as do ensaio no Siril 1.2.1, as da
# parte A no 1.4.4 e as de arquivo real ja citadas no run.js e no NOTAS, cada uma
# com o rotulo que tem que receber -- inclusive NENHUM.
#
# A tabela e test/golden/catalogo-historico.json. A captura
# (__captureCatalogo, em test/capture-golden.js) passa cada linha pela
# historyLabels do pipeline publicado e grava .claude/shots/catalogo.results.json.
#
# O QUE E ASSERCAO AQUI:
#
#   1. a captura e DESTE catalogo: as regras que ela gravou sao, na ordem, as
#      que estao escritas em src/pipeline/run.js. Captura velha de outro
#      catalogo reprova, em vez de passar com os rotulos de ontem;
#   2. a captura rodou ESTA tabela: mesma contagem, mesmas linhas, mesma ordem;
#   3. cada linha recebe exatamente os rotulos esperados;
#   4. toda regra do catalogo e a primeira a casar em pelo menos uma linha
#      medida, ou esta declarada em `sem_linha_medida` com o motivo. As duas
#      metades: regra sem linha e sem declaracao reprova, e declaracao cuja
#      regra passou a ter linha reprova tambem -- divida paga sai da lista.
#
# -Results aponta para outra captura (a demonstracao contra o catalogo antigo).
param([string]$Results)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath
$root = Split-Path -Parent $here
$expectPath = Join-Path $here 'golden\catalogo-historico.json'
$runJs      = Join-Path $root 'src\pipeline\run.js'
if (-not $Results) { $Results = Join-Path $root '.claude\shots\catalogo.results.json' }
foreach ($p in @($expectPath, $runJs)) { if (-not (Test-Path -LiteralPath $p)) { throw "faltando: $p" } }
if (-not (Test-Path -LiteralPath $Results)) {
    throw "faltando: $Results -- rode a captura no navegador (__captureAll ou __captureCatalogo)"
}
$expect = Get-Content -LiteralPath $expectPath -Raw | ConvertFrom-Json
$got    = Get-Content -LiteralPath $Results -Raw | ConvertFrom-Json
$fail = 0

function Rot($a) { $l = @($a); if ($l.Count -eq 0) { '-' } else { $l -join ' + ' } }

# 1. As regras da captura contra as regras escritas no run.js, lidas do texto.
#    Uma linha por regra: `[/.../flags, 'Rotulo'],`, entre a abertura da tabela
#    e o `];` que a fecha.
$src = [System.IO.File]::ReadAllText($runJs)
$a = $src.IndexOf('var STRETCH_HISTORY = [')
$b = if ($a -ge 0) { $src.IndexOf("`n];", $a) } else { -1 }
if ($a -lt 0 -or $b -lt 0) { throw 'run.js: tabela STRETCH_HISTORY nao encontrada -- este comparador le o texto dela' }
$escritas = @()
foreach ($m in [regex]::Matches($src.Substring($a, $b - $a), "(?m)^\s*\[(/.+/[a-z]*),\s*'([^']*)'\],?\s*$")) {
    $escritas += ,@($m.Groups[1].Value, $m.Groups[2].Value)
}
$capturadas = @($got.regras)
if ($escritas.Count -eq 0) { throw 'run.js: nenhuma regra lida da tabela -- o formato da linha mudou?' }
$mesmas = ($escritas.Count -eq $capturadas.Count)
if ($mesmas) {
    for ($k = 0; $k -lt $escritas.Count; $k++) {
        if ($escritas[$k][0] -cne $capturadas[$k][0] -or $escritas[$k][1] -cne $capturadas[$k][1]) { $mesmas = $false; break }
    }
}
if (-not $mesmas) {
    Write-Host ("CATALOGO FAIL - a captura e de outro catalogo: run.js tem {0} regras, a captura {1}, e elas nao coincidem na ordem. Recapture." -f $escritas.Count, $capturadas.Count)
    $fail++
}

# 2. A captura rodou esta tabela.
$E = @($expect.linhas)
$G = @($got.linhas)
if ($E.Count -ne $G.Count) {
    Write-Host ("CATALOGO FAIL - a tabela tem {0} linhas e a captura {1}. Recapture." -f $E.Count, $G.Count)
    $fail++
}
$n = [Math]::Min($E.Count, $G.Count)
for ($i = 0; $i -lt $n; $i++) {
    if ($E[$i].linha -cne $G[$i].linha) {
        Write-Host ("CATALOGO FAIL - linha {0}: a tabela e a captura divergem no texto. Recapture." -f ($i + 1))
        $fail++
    }
}

# 3. Cada linha, o rotulo esperado.
$rows = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $n; $i++) {
    $esp = Rot $E[$i].espera
    $rec = Rot $G[$i].rotulos
    $ok = ($esp -ceq $rec)
    if (-not $ok) { $fail++ }
    [void]$rows.Add([pscustomobject]@{
        fonte = $E[$i].fonte; saida = $E[$i].saida
        espera = $esp; recebeu = $rec; resultado = $(if ($ok) { 'ok' } else { 'FAIL' })
        linha = $E[$i].linha
    })
}
$rows | Format-Table fonte, saida, espera, recebeu, resultado, linha -AutoSize | Out-String -Width 260 | Write-Host

# 4. Cobertura das regras, com as duas metades.
$reivindicadas = @{}
foreach ($g in $G) { if ([int]$g.regra -ge 0) { $reivindicadas[[int]$g.regra] = $true } }
$declaradas = @{}
foreach ($d in @($expect.sem_linha_medida)) { $declaradas[$d.regra] = $d.motivo }
$semLinha = 0
for ($k = 0; $k -lt $capturadas.Count; $k++) {
    $rx = $capturadas[$k][0]
    $tem = $reivindicadas.ContainsKey($k)
    $dec = $declaradas.ContainsKey($rx)
    if ($tem -and $dec) {
        Write-Host ("CATALOGO FAIL - {0} esta em sem_linha_medida e agora tem linha medida: divida paga, tire a declaracao" -f $rx)
        $fail++
    } elseif (-not $tem -and -not $dec) {
        Write-Host ("CATALOGO FAIL - {0} nao e a primeira regra de nenhuma linha medida, e nao esta declarada em sem_linha_medida" -f $rx)
        $fail++
    } elseif (-not $tem) { $semLinha++ }
}
foreach ($rx in $declaradas.Keys) {
    if (-not (@($capturadas | ForEach-Object { $_[0] }) -ccontains $rx)) {
        Write-Host ("CATALOGO FAIL - sem_linha_medida cita {0}, que nao e regra do catalogo" -f $rx)
        $fail++
    }
}

$nOk = @($rows | Where-Object { $_.resultado -eq 'ok' }).Count
$nNenhum = @($rows | Where-Object { $_.espera -eq '-' }).Count
Write-Host ("{0} linhas medidas: {1} com o rotulo esperado ({2} delas com NENHUM)  |  regras: {3}, {4} com linha medida, {5} declaradas sem" -f `
    $rows.Count, $nOk, $nNenhum, $capturadas.Count, $reivindicadas.Count, $semLinha)
if ($fail -eq 0) { Write-Host 'CATALOGO PASS' } else { Write-Host ("CATALOGO FAIL - {0} problema(s)" -f $fail); exit 1 }
