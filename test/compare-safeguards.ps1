# A salvaguarda de estabilidade da calibracao de cor ainda dispara?
#
#   powershell -File test\compare-safeguards.ps1
#
# ASCII apenas -- ver o cabecalho de compare-golden.ps1.
#
# POR QUE ESTE ARQUIVO EXISTE.
#
# A regra dos ganhos e "um erro de 10% no ceu pode mover qualquer ganho em no
# maximo 5%". Depois que ela substituiu a regra dos 3x, nenhum dos seis fixtures
# a faz disparar: todos ficam entre 0,03% e 1,3%. Isso e o resultado certo -- a
# regra antiga reprovava medicoes estaveis -- e cria o problema que este projeto
# ja pagou uma vez, nos quatro zeros do `rejected-edge`: uma salvaguarda que
# nunca dispara e uma salvaguarda que ninguem verificou.
#
# A varredura: somar uma constante ao quadro nao muda `above` (o pedestal e a
# mediana estelar sobem juntos) mas AUMENTA a sondagem, que e 10% do pedestal.
# E o caso fisico exato que a regra existe para pegar -- ceu alto contra estrela
# fraca -- e nao um numero forcado a mao.
#
# O QUE E ASSERCAO AQUI, e nao e so "os numeros batem":
#
#   1. a sensibilidade cresce MONOTONICAMENTE com o ceu somado
#   2. o veredito passa de `aplica` para `recusa` e nunca volta
#   3. os ganhos mal se movem enquanto passa -- a regra recusa quando a medicao
#      fica NAO CONFIAVEL, nao quando fica diferente. Se os ganhos derivassem
#      junto, a regra estaria medindo outra coisa.

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath
$root = Split-Path -Parent $here

$expectPath = Join-Path $here 'golden\safeguards.json'
$resultPath = Join-Path $root '.claude\shots\safeguards.results.json'

if (-not (Test-Path $expectPath)) { throw "faltando: $expectPath" }
if (-not (Test-Path $resultPath)) {
    throw "faltando: $resultPath -- rode a captura no navegador (await __captureAll())"
}

$expect = (Get-Content $expectPath -Raw | ConvertFrom-Json)
$got    = (Get-Content $resultPath -Raw | ConvertFrom-Json)

$inv = [cultureinfo]::InvariantCulture
$rows = New-Object System.Collections.ArrayList
$fail = 0

if (@($got.casos).Count -ne @($expect.casos).Count) {
    Write-Host ("SAFEGUARD FAIL - {0} casos capturados, {1} esperados" -f `
        @($got.casos).Count, @($expect.casos).Count)
    exit 1
}

# --- 1. cada caso contra o esperado ------------------------------------------
for ($i = 0; $i -lt @($expect.casos).Count; $i++) {
    $e = @($expect.casos)[$i]
    $g = @($got.casos)[$i]

    $okCeu = ([double]$e.ceuAdicionado -eq [double]$g.ceuAdicionado)
    $okVer = ($e.veredito -eq $g.veredito)

    # A sensibilidade e grandeza medida e herda a tolerancia unitaria da secao 7:
    # ela sai de medianas exatas dos dois lados, mas o pedestal vem do modelo de
    # fundo e carrega a discordancia dele.
    $okSen = $true; $dSen = 0.0
    if ($null -ne $e.sensibilidade -and $null -ne $g.sensibilidade) {
        $dSen = [math]::Abs([double]$e.sensibilidade - [double]$g.sensibilidade)
        $lim = [math]::Max(1e-4 * [math]::Abs([double]$e.sensibilidade), 4.0 / 65535.0)
        $okSen = ($dSen -le $lim)
    } elseif (($null -eq $e.sensibilidade) -ne ($null -eq $g.sensibilidade)) {
        $okSen = $false
    }

    $ok = $okCeu -and $okVer -and $okSen
    if (-not $ok) { $fail++ }
    [void]$rows.Add([pscustomobject]@{
        ceu = ('+{0:0.00}' -f [double]$g.ceuAdicionado)
        sensibilidade = $(if ($null -ne $g.sensibilidade) { '{0:0.000}%' -f (100 * [double]$g.sensibilidade) } else { 'inf' })
        veredito = $g.veredito
        esperado = $e.veredito
        ganhos = $(if ($g.ganhos) { ($g.ganhos | ForEach-Object { '{0:0.0000}' -f [double]$_ }) -join '/' } else { '-' })
        v = $(if ($ok) { 'ok' } else { 'FAIL' })
    })
}

$rows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host

# --- 2. a sensibilidade cresce monotonicamente -------------------------------
$prev = -1.0
foreach ($g in @($got.casos)) {
    $s = $(if ($null -ne $g.sensibilidade) { [double]$g.sensibilidade } else { [double]::PositiveInfinity })
    if ($s -lt $prev) {
        Write-Host ("MONOTONIA FAIL - sensibilidade caiu em ceu +{0}: {1} depois de {2}" -f `
            $g.ceuAdicionado, $s, $prev)
        $fail++
    }
    $prev = $s
}

# --- 3. o veredito vira uma vez e nao volta ----------------------------------
$viu = $false
foreach ($g in @($got.casos)) {
    if ($g.veredito -eq 'recusa') { $viu = $true }
    elseif ($viu) {
        Write-Host ("VEREDITO FAIL - voltou a aplicar em ceu +{0} depois de ja ter recusado" -f $g.ceuAdicionado)
        $fail++
    }
}
$aplicou = @($got.casos | Where-Object { $_.veredito -eq 'aplica' }).Count
$recusou = @($got.casos | Where-Object { $_.veredito -eq 'recusa' }).Count
if ($aplicou -eq 0 -or $recusou -eq 0) {
    # O ponto inteiro do arquivo. Uma varredura que so aplica, ou so recusa, nao
    # exercita a regra -- descreve um lado dela.
    Write-Host ("COBERTURA FAIL - a varredura tem {0} 'aplica' e {1} 'recusa'; precisa dos dois" -f $aplicou, $recusou)
    $fail++
}

# --- 4. os ganhos nao derivam enquanto a regra ainda aceita ------------------
$aplicados = @($got.casos | Where-Object { $_.ganhos })
if ($aplicados.Count -ge 2) {
    $maxDrift = 0.0
    $base = $aplicados[0].ganhos
    foreach ($a in $aplicados) {
        for ($k = 0; $k -lt 3; $k++) {
            if ([double]$base[$k] -ne 0) {
                $d = [math]::Abs([double]$a.ganhos[$k] - [double]$base[$k]) / [math]::Abs([double]$base[$k])
                if ($d -gt $maxDrift) { $maxDrift = $d }
            }
        }
    }
    $LIM_DRIFT = 0.02
    $okDrift = ($maxDrift -le $LIM_DRIFT)
    Write-Host ("deriva dos ganhos enquanto a regra aceita: {0:0.000}%  (limite {1:0.0}%)" -f `
        (100 * $maxDrift), (100 * $LIM_DRIFT))
    if (-not $okDrift) {
        Write-Host 'DERIVA FAIL - os ganhos mudaram junto com o ceu, entao a regra nao esta medindo estabilidade'
        $fail++
    }
}

Write-Host ''
Write-Host ("{0} casos: {1} como esperado, {2} divergentes  |  {3} aplica, {4} recusa" -f `
    $rows.Count, ($rows.Count - @($rows | Where-Object { $_.v -ne 'ok' }).Count), `
    @($rows | Where-Object { $_.v -ne 'ok' }).Count, $aplicou, $recusou)

if ($fail -gt 0) { exit 1 }
Write-Host 'SAFEGUARDS PASS'
exit 0
