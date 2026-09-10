# As salvaguardas que nenhum fixture faz disparar ainda disparam?
#
#   powershell -File test\compare-safeguards.ps1
#
# ASCII apenas -- ver o cabecalho de compare-golden.ps1.
#
# POR QUE ESTE ARQUIVO EXISTE.
#
# Duas regras deste projeto sao verdadeiras em todo fixture, o que quer dizer
# que nenhum fixture as viu recusar: a estabilidade dos ganhos da calibracao de
# cor (secoes 1 a 4) e o ruido de croma da saturacao (secao 5). Uma regra que
# nunca disparou e uma afirmacao, e este arquivo e o que a torna um controle.
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


# =============================================================================
# 5. A SALVAGUARDA DE RUIDO DE CROMA DA SATURACAO
#
# Mesma doenca, outra etapa. A secao 2.4 do Modulo 4 pede: meca o desvio padrao
# da crominancia nos pixels com snr < snrLow, antes e depois, e recuse se
# crescer mais de 2%. Com o codigo publicado ela NAO PODE disparar -- naqueles
# pixels o w satura em 0, k e exatamente 1, e a crominancia nao e tocada. O
# crescimento medido e -1,05e-9%, que e tambem o que sai quando a etapa nao faz
# nada. Uma regra nessas condicoes e afirmacao, nao controle.
#
# A cobertura vem de duas fontes deliberadamente quebradas, rodadas pela MESMA
# cadeia do golden saturation-fixture. E a alavanca e a FIACAO, nao um
# parametro -- as duas alavancas obvias nao funcionam, e o motivo esta no
# cabecalho de test/capture-golden.js e no NOTAS:
#
#   baixar snrLow   esvazia o conjunto medido em vez de desproteger alguem: a
#                   salvaguarda e a mascara leem o MESMO limiar.
#   ceu sem sinal   deixa todo mundo em k = 1, ou seja, protege tudo.
#
# O QUE E ASSERCAO AQUI:
#
#   1. UMA copia do clamp do w na fonte publicada. A pre-passada do ruido e o
#      laco principal tem que chamar a mesma funcao. Quando eram duas copias, o
#      clamp quebrado atingiu so o laco e a copia intacta APROVOU a mascara
#      quebrada -- a salvaguarda estava verificando uma funcao diferente da que
#      ia rodar. Esta contagem e a unica coisa que impede isso de voltar, e por
#      isso ela e verificada antes de qualquer numero.
#   2. o clamp invertido faz a etapa RECUSAR, e pelo motivo certo: o texto da
#      recusa tem que ser o do ruido de croma, nao outro qualquer.
#   3. o azul com k proprio passa PELA salvaguarda de ruido e e pego pela de
#      matiz. As duas nao sao redundantes, e o crescimento identico ao do codigo
#      publicado e a prova de que a de ruido e cega para essa falha.
# =============================================================================

function Compare-SatNumber($e, $g, $absFloor) {
    if ($null -eq $e -and $null -eq $g) { return @{ ok = $true;  d = 0.0 } }
    if ($null -eq $e -or  $null -eq $g) { return @{ ok = $false; d = [double]::NaN } }
    $de = [double]$e; $dg = [double]$g
    $d  = [math]::Abs($de - $dg)
    $lim = [math]::Max(1e-9 * [math]::Abs($de), $absFloor)
    return @{ ok = ($d -le $lim); d = $d }
}

function Show-Num($v, $fmt) {
    if ($null -eq $v) { return '-' }
    return ($fmt -f [double]$v)
}

Write-Host ''
Write-Host '--- saturacao: a salvaguarda de ruido de croma ---'

if ($null -eq $got.saturacao -or $null -eq $expect.saturacao) {
    Write-Host 'SATURACAO FAIL - o bloco saturacao nao esta na captura ou no esperado; recapture com __captureAll()'
    exit 1
}

# --- 5.1 uma copia da formula ------------------------------------------------
$copias = [int]$got.saturacao.copiasDoClamp
if ($copias -ne 1) {
    Write-Host ("CLAMP FAIL - a fonte publicada tem {0} copias do clamp do w; tem que ter exatamente 1." -f $copias)
    Write-Host '            Duas copias ja aconteceram aqui, e a segunda era a que verificava a primeira.'
    $fail++
} else {
    Write-Host 'copias do clamp do w na fonte publicada: 1  (a pre-passada e o laco principal chamam a mesma satFactor)'
}
if ($copias -ne [int]$expect.saturacao.copiasDoClamp) { $fail++ }

# --- 5.2 cada caso contra o esperado -----------------------------------------
$satE = @($expect.saturacao.casos)
$satG = @($got.saturacao.casos)
if ($satG.Count -ne $satE.Count) {
    Write-Host ("SATURACAO FAIL - {0} casos capturados, {1} esperados" -f $satG.Count, $satE.Count)
    exit 1
}

$satRows = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $satE.Count; $i++) {
    $e = $satE[$i]; $g = $satG[$i]

    $okNome = ($e.nome -eq $g.nome)
    $okVer  = ($e.veredito -eq $g.veredito)
    $okLin  = ([bool]$e.naoLinear -eq [bool]$g.naoLinear)

    # Pontos percentuais. O piso absoluto de 1e-6 fica seis ordens de grandeza
    # abaixo do limite de 2%, entao nao pode esconder mudanca que importe.
    $cres = Compare-SatNumber $e.crescimentoPct $g.crescimentoPct 1e-6
    # Voltas do circulo de matiz, contra um limite de 1e-6.
    $mat  = Compare-SatNumber $e.derivaMatiz    $g.derivaMatiz    1e-12
    $mk   = Compare-SatNumber $e.maxK           $g.maxK           1e-12

    $okDentro = (($null -eq $e.matizDentroDoLimite) -and ($null -eq $g.matizDentroDoLimite)) -or
                (($null -ne $e.matizDentroDoLimite) -and ($null -ne $g.matizDentroDoLimite) -and
                 ([bool]$e.matizDentroDoLimite -eq [bool]$g.matizDentroDoLimite))

    $ok = $okNome -and $okVer -and $okLin -and $cres.ok -and $mat.ok -and $mk.ok -and $okDentro
    if (-not $ok) { $fail++ }

    [void]$satRows.Add([pscustomobject]@{
        fonte       = $g.nome
        veredito    = $g.veredito
        esperado    = $e.veredito
        crescimento = (Show-Num $g.crescimentoPct '{0:0.0000}%')
        limite      = (Show-Num $g.limitePct '{0:0.00}%')
        matiz       = (Show-Num $g.derivaMatiz '{0:E2}')
        matizOk     = $(if ($null -eq $g.matizDentroDoLimite) { '-' } else { [string][bool]$g.matizDentroDoLimite })
        v           = $(if ($ok) { 'ok' } else { 'FAIL' })
    })
}
$satRows | Format-Table -AutoSize | Out-String -Width 200 | Write-Host

# --- 5.3 a regra tem que ter sido vista dos dois lados -----------------------
$satAplica = @($satG | Where-Object { $_.veredito -eq 'aplica' }).Count
$satRecusa = @($satG | Where-Object { $_.veredito -eq 'recusa' }).Count
if ($satAplica -eq 0 -or $satRecusa -eq 0) {
    Write-Host ("COBERTURA FAIL - a salvaguarda de ruido tem {0} 'aplica' e {1} 'recusa'; precisa dos dois" -f `
        $satAplica, $satRecusa)
    $fail++
}

# --- 5.4 quem recusa, recusa pelo motivo certo -------------------------------
foreach ($g in $satG) {
    if ($g.veredito -ne 'recusa') { continue }
    if ([string]$g.motivo -notlike '*colour noise*') {
        Write-Host ("MOTIVO FAIL - {0} recusou, mas nao pela salvaguarda de ruido de croma: {1}" -f $g.nome, $g.motivo)
        $fail++
    }
    if ([double]$g.crescimentoPct -le [double]$g.limitePct) {
        Write-Host ("MOTIVO FAIL - {0} recusou com crescimento {1} dentro do limite {2}" -f `
            $g.nome, $g.crescimentoPct, $g.limitePct)
        $fail++
    }
}
foreach ($g in $satG) {
    if ($g.veredito -ne 'aplica') { continue }
    if ([double]$g.crescimentoPct -gt [double]$g.limitePct) {
        Write-Host ("MOTIVO FAIL - {0} aplicou com crescimento {1} acima do limite {2}" -f `
            $g.nome, $g.crescimentoPct, $g.limitePct)
        $fail++
    }
}

# --- 5.5 as duas verificacoes nao sao a mesma verificacao --------------------
#
# O caso do azul passa pela salvaguarda de ruido com o crescimento IDENTICO ao
# do codigo publicado -- a quebra esta so no laco principal, e a pre-passada nem
# a ve -- e e pego pela deriva de matiz. Se um dia as duas passassem a pegar as
# mesmas falhas, uma delas estaria sobrando e este teste diria qual.
$publicado = $satG | Where-Object { $_.nome -eq 'codigo-publicado' } | Select-Object -First 1
$soMatiz   = $satG | Where-Object { ($_.veredito -eq 'aplica') -and ($null -ne $_.matizDentroDoLimite) -and
                                    (-not [bool]$_.matizDentroDoLimite) } | Select-Object -First 1
if ($null -eq $publicado) {
    Write-Host 'SATURACAO FAIL - o caso codigo-publicado sumiu da varredura'
    $fail++
} elseif (-not [bool]$publicado.matizDentroDoLimite) {
    Write-Host ("MATIZ FAIL - o codigo publicado derivou {0} de volta, acima do limite {1}" -f `
        $publicado.derivaMatiz, $publicado.limiteMatiz)
    $fail++
}
if ($null -eq $soMatiz) {
    Write-Host 'INDEPENDENCIA FAIL - nenhum caso passa pela salvaguarda de ruido e e pego pela de matiz;'
    Write-Host '                     sem ele a de matiz nunca foi vista disparar.'
    $fail++
} elseif ($null -ne $publicado) {
    $mesmo = Compare-SatNumber $publicado.crescimentoPct $soMatiz.crescimentoPct 1e-12
    Write-Host ("independencia: {0} passa pelo ruido com o mesmo crescimento do codigo publicado e o matiz o pega em {1}" -f `
        $soMatiz.nome, ('{0:E2}' -f [double]$soMatiz.derivaMatiz))
    if (-not $mesmo.ok) {
        Write-Host ("            (o crescimento nao ficou identico: diferenca {0})" -f $mesmo.d)
    }
}

Write-Host ''
Write-Host ("calibracao de cor: {0} casos, {1} como esperado, {2} divergentes  |  {3} aplica, {4} recusa" -f `
    $rows.Count, ($rows.Count - @($rows | Where-Object { $_.v -ne 'ok' }).Count), `
    @($rows | Where-Object { $_.v -ne 'ok' }).Count, $aplicou, $recusou)
Write-Host ("saturacao:         {0} fontes, {1} divergentes  |  {2} aplica, {3} recusa" -f `
    $satRows.Count, @($satRows | Where-Object { $_.v -ne 'ok' }).Count, $satAplica, $satRecusa)

if ($fail -gt 0) { exit 1 }
Write-Host 'SAFEGUARDS PASS'
exit 0
