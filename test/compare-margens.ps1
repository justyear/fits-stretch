# Inventario de margens: a que distancia cada fixture esta de cada limiar.
#
#   powershell -File test\compare-margens.ps1
#
# A TERCEIRA PERGUNTA QUE A SUITE NAO FAZIA.
#
#   golden                  o caso mudou?
#   referencia              os dois lados concordam?
#   controle negativo       a cota consegue reprovar?
#   varredura de unidades   a cota esta na unidade certa?
#   ESTE                    A QUE DISTANCIA DA FRONTEIRA O CASO ESTA?
#
# As quatro primeiras medem a ferramenta contra si mesma ou contra outra
# implementacao. Nenhuma pergunta ONDE o caso esta -- so se ele mudou. E um caso
# encostado numa fronteira passa em todas elas, hoje e no dia em que trocar de
# lado.
#
# Foi assim que o `bigobject` ficou a 1,2% do limiar da regra linear sem que
# ninguem visse: mediana 0,04938 contra 0,05. Um aumento de exposicao de 1,3%
# inverte o veredito dele -- contra 200% que o `gradient` precisa para cruzar o
# MESMO limiar. A margem e propriedade do quadro, nao da regra.
#
# O QUE UM FIXTURE PERTO DE UM LIMIAR SIGNIFICA, e sao duas coisas e as duas
# importam:
#
#   1. o limiar pode estar no lugar errado -- se um caso legitimo senta em cima
#      dele, ele nao esta separando as duas populacoes que deveria separar;
#   2. o fixture pode estar testando outra coisa do que se pensa -- um caso a
#      1,2% da fronteira e um caso que vai trocar de ramo com qualquer mexida, e
#      o golden dele fixa um comportamento que e acidente.
#
# E A SAIDA RESPONDE UMA PERGUNTA QUE A SPEC DA ESCALA DEIXOU ABERTA: quais
# limiares tem populacao perto deles. Onde nao tiver, o limiar e robusto POR
# ACIDENTE -- ninguem testou o outro lado dele, e vale saber qual e a diferenca
# entre "escolhido bem" e "nunca exercitado".
#
# POR QUE E VERIFICACAO E NAO RELATORIO: um relatorio que ninguem le nao impede
# o proximo `bigobject`. Um caso dentro da faixa que NAO esteja declarado abaixo
# reprova; um declarado que saiu da faixa tambem reprova, porque a declaracao
# ficou velha. E a mesma disciplina das ancoras de clip do negative-controls.
#
# ASCII apenas, sem BOM -- ver a nota no topo do compare-golden.ps1.

param([double]$Faixa = 0.05, [switch]$Tudo)

$ErrorActionPreference = 'Stop'
$gold = Join-Path $PSScriptRoot 'golden'

# ---------------------------------------------------------------------------
# OS LIMIARES ABSOLUTOS DA CADEIA
#
# `valor` devolve a grandeza do fixture que e comparada com o limiar, ou $null
# quando o limiar nao se aplica aquele quadro. `limiar` devolve o numero, que em
# alguns casos vem do proprio record (e um parametro, nao uma constante).
#
# A distancia e relativa AO LIMIAR: |valor - limiar| / |limiar|. E a fracao que
# a spec pediu, e ela e comparavel entre limiares de unidades diferentes.
# ---------------------------------------------------------------------------
$LIMIARES = @(
    @{ id = 'decode.unit'; onde = 'normalise.js'; limiar = 1.5
       nota = 'fronteira do ramo que trata o float como ja normalizado'
       valor = { param($d, $r) if ($d.decoded.bitpix -lt 0) { [double]$d.decoded.rawMax } else { $null } } }

    @{ id = 'decode.float16'; onde = 'normalise.js'; limiar = 70000.0
       nota = 'fronteira entre dividir por 65535 e dividir pelo maior pixel'
       valor = { param($d, $r) if ($d.decoded.bitpix -lt 0 -and [double]$d.decoded.rawMax -gt 1.5) { [double]$d.decoded.rawMax } else { $null } } }

    @{ id = 'linear.mediana'; onde = 'run.js'; limiar = 0.05
       nota = 'regra linear/nao-linear -- a que erra BAIXO, ver investigacao-regra-linear.md'
       valor = { param($d, $r) [double]$d.linearity.globalMedian } }

    @{ id = 'linear.medianaComHistoria'; onde = 'run.js'; limiar = 0.02
       nota = 'o mesmo limiar rebaixado quando o HISTORY declara esticamento'
       valor = { param($d, $r) if (@($d.linearity.historyHits).Count -gt 0) { [double]$d.linearity.globalMedian } else { $null } } }

    @{ id = 'cfa.razaoDeTrelica'; onde = 'cfa.js'; limiar = 1.15
       nota = 'acima disto o quadro e lido como mosaico'
       valor = { param($d, $r)
                 if ($null -eq $d.cfa -or $null -eq $d.cfa.ratioH) { return $null }
                 [math]::Min([double]$d.cfa.ratioH, [double]$d.cfa.ratioV) } }

    @{ id = 'cor.sensibilidadeDoGanho'; onde = 'colour-cal.js'; limiar = 0.05
       nota = 'recusa a calibracao se 10% de erro no ceu mover os ganhos mais que isto'
       valor = { param($d, $r)
                 $cc = Rec $r 'colour-cal'
                 if ($null -eq $cc -or -not $cc.applied -or $null -eq $cc.stars.gainSensitivity) { return $null }
                 [double]$cc.stars.gainSensitivity } }

    @{ id = 'cor.janelaEstelar'; onde = 'colour-cal.js'; limiarDe = { param($d, $r) $cc = Rec $r 'colour-cal'; if ($cc -and $cc.stars) { [double]$cc.stars.thresholdHigh } else { $null } }
       nota = 'o piso da selecao encostando no teto de 0,85 fecha a janela'
       valor = { param($d, $r)
                 $cc = Rec $r 'colour-cal'
                 if ($null -eq $cc -or -not $cc.applied -or $null -eq $cc.stars.thresholdLow) { return $null }
                 [double]$cc.stars.thresholdLow } }

    @{ id = 'cor.minimoDeEstrelas'; onde = 'colour-cal.js'; limiarDe = { param($d, $r) $cc = Rec $r 'colour-cal'; if ($cc -and $cc.params) { [double]$cc.params.minStarPixels } else { $null } }
       nota = 'abaixo disto a calibracao recusa por amostra insuficiente'
       valor = { param($d, $r)
                 $cc = Rec $r 'colour-cal'
                 if ($null -eq $cc -or $null -eq $cc.stars -or $null -eq $cc.stars.pixels) { return $null }
                 [double]$cc.stars.pixels } }

    @{ id = 'recorte.pisoDoQuadro'; onde = 'crop.js'; limiarDe = { param($d, $r) $cp = Rec $r 'crop'; if ($cp -and $cp.params) { [double]$cp.params.minFrame } else { $null } }
       nota = 'componente menor que isto do quadro nao e tratado como o objeto'
       valor = { param($d, $r)
                 $cp = Rec $r 'crop'
                 if ($null -eq $cp -or $null -eq $cp.componentList -or @($cp.componentList).Count -eq 0) { return $null }
                 [double]@($cp.componentList)[0].boxFrac } }

    @{ id = 'recorte.ganhoMinimo'; onde = 'crop.js'; limiar = 1.5
       nota = 'abaixo disto o recorte nao se oferece'
       valor = { param($d, $r)
                 $cp = Rec $r 'crop'
                 if ($null -eq $cp -or -not $cp.suggested -or $null -eq $cp.coverageBefore) { return $null }
                 if ([double]$cp.coverageBefore -le 0) { return $null }
                 [double]$cp.coverageAfter / [double]$cp.coverageBefore } }
)

# ---------------------------------------------------------------------------
# O QUE ESTE INVENTARIO NAO COBRE, e por que -- dito, nao omitido.
# ---------------------------------------------------------------------------
$SEMCOBERTURA = @(
    @{ id = 'saturacao.snrBaixo/snrAlto'; limiar = '3,0 e 25,0 sigma'
       porque = 'a grandeza e uma DISTRIBUICAO de SNR por pixel, nao um escalar do quadro; a distancia so faz sentido por pixel e o record guarda contagens, nao a distribuicao' }
    @{ id = 'saturacao.joelhoDasAltasLuzes'; limiar = '0,80'
       porque = 'roda DEPOIS do esticamento, no eixo que a MTF ja normalizou -- nao e limiar absoluto sobre dado de entrada' }
    @{ id = 'recorte.densidadeDeOcupacao'; limiar = '0,50'
       porque = 'a ocupacao e por pixel e o record guarda a contagem dos que passaram, nao a margem de cada um' }
    @{ id = 'fundo.rejeicaoDeAmostra'; limiar = 'mediana + 1 x MADN'
       porque = 'e limiar RELATIVO, recalculado por quadro: nao ha fronteira fixa da qual medir distancia' }
)

# ---------------------------------------------------------------------------
# CASOS DECLARADOS: quem ja esta dentro da faixa, e por que isso e aceito.
#
# Entrada aqui e divida nomeada, nao desculpa. Duas regras, e as duas reprovam:
#   - caso dentro da faixa e SEM entrada aqui  -> FAIL (o proximo bigobject)
#   - entrada aqui que saiu da faixa           -> FAIL (a declaracao envelheceu)
# ---------------------------------------------------------------------------
$DECLARADOS = @{
    'bigobject|linear.mediana' =
        'mediana 0,04938 contra 0,05: 1,3% de exposicao inverte o veredito. ACHADO e nao escolhido -- o fixture foi construido para a salvaguarda de cobertura do recorte, e caiu encostado neste limiar por acaso. Ver investigacao-regra-linear.md secao 2.1'

    # Achado pela PRIMEIRA rodada deste inventario, e o numero estava impresso no
    # log desde sempre: "the largest extended object covers 19.4% of the frame,
    # under the 20% this step treats as a subject". Ninguem leu 19,4 e 20 como a
    # mesma informacao que 0,194469 contra 0,2.
    #
    # Qual das duas leituras vale, das que o cabecalho lista: a SEGUNDA. O
    # `fixture-saturation` existe para a etapa de saturacao; a recusa do recorte
    # nele e incidental, e o golden dela fixa uma moeda que caiu de um lado. Uma
    # mexida no limiar de sinal ou no filtro de ocupacao vira essa moeda, e o
    # diff do golden vai parecer regressao quando for a fronteira sendo cruzada.
    #
    # NAO e o limiar que esta errado: 20% do quadro e o que separa "objeto" de
    # "estrela grande", e o `oneobject` (37,1%) e o `bigobject` (que nem chega a
    # ter componente extenso) estao dos dois lados com folga.
    'saturation|recorte.pisoDoQuadro' =
        'boxFrac 0,194469 contra 0,2: recusa o recorte por 2,8%. O fixture e da SATURACAO e a recusa do recorte nele e incidental -- o golden fixa uma moeda que caiu de um lado. Se o comportamento do recorte neste quadro virar relevante, o certo e um fixture proprio dos dois lados do piso, nao mover o limiar'
}

function Rec($recs, $id) {
    foreach ($x in @($recs)) {
        if ($id -eq 'stretch') { if ($x.id -eq 'stretch-mtf' -or $x.id -eq 'stretch-asinh') { return $x } }
        elseif ($x.id -eq $id) { return $x }
    }
    return $null
}

# ---------------------------------------------------------------------------
$linhas = @()
$fixtures = @()
foreach ($f in (Get-ChildItem -LiteralPath $gold -Filter '*-fixture.diag.json' | Sort-Object Name)) {
    $nome = $f.Name -replace '-fixture\.diag\.json$', ''
    $recPath = Join-Path $gold ($nome + '-fixture.records.json')
    if (-not (Test-Path -LiteralPath $recPath)) { continue }
    $fixtures += $nome
    $d = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json
    $r = Get-Content -LiteralPath $recPath -Raw | ConvertFrom-Json

    foreach ($L in $LIMIARES) {
        $v = & $L.valor $d $r
        if ($null -eq $v) { continue }
        $lim = if ($L.ContainsKey('limiar')) { [double]$L.limiar } else { & $L.limiarDe $d $r }
        if ($null -eq $lim -or $lim -eq 0) { continue }
        $dist = [math]::Abs([double]$v - $lim) / [math]::Abs($lim)
        $linhas += [pscustomobject]@{
            fixture = $nome; limiar = $L.id; alvo = $lim; valor = [double]$v
            distancia = $dist; lado = $(if ([double]$v -lt $lim) { 'abaixo' } else { 'acima' })
        }
    }
}

# ---------------------------------------------------------------------------
# O veredito
# ---------------------------------------------------------------------------
$dentro = @($linhas | Where-Object { $_.distancia -lt $Faixa })
$chavesDentro = @{}
foreach ($x in $dentro) { $chavesDentro[('{0}|{1}' -f $x.fixture, $x.limiar)] = $x }

$naoDeclarados = @($dentro | Where-Object { -not $DECLARADOS.ContainsKey(('{0}|{1}' -f $_.fixture, $_.limiar)) })
$declaradosVelhos = @($DECLARADOS.Keys | Where-Object { -not $chavesDentro.ContainsKey($_) })

Write-Host ''
Write-Host ('INVENTARIO DE MARGENS -- {0} fixtures, {1} limiares, {2} pares medidos' -f `
            $fixtures.Count, $LIMIARES.Count, $linhas.Count)
Write-Host ('faixa de alerta: {0:P0} do limiar' -f $Faixa)
Write-Host ''

Write-Host 'O CASO MAIS APERTADO DE CADA LIMIAR:'
foreach ($L in $LIMIARES) {
    $g = @($linhas | Where-Object { $_.limiar -eq $L.id } | Sort-Object distancia)
    if ($g.Count -eq 0) {
        Write-Host ('  {0,-26} SEM POPULACAO -- nenhum fixture chega a ser medido contra ele' -f $L.id)
        continue
    }
    $m = $g[0]
    $marca = if ($m.distancia -lt $Faixa) { '  <-- DENTRO DA FAIXA' }
             elseif ($m.distancia -gt 1.0) { '  (robusto por folga: o mais proximo esta a mais de 100%)' }
             else { '' }
    Write-Host ('  {0,-26} {1,-11} {2,10:G6} contra {3,-10:G6} {4,8:P1} {5}{6}' -f `
                $L.id, $m.fixture, $m.valor, $m.alvo, $m.distancia, $m.lado, $marca)
}

if ($Tudo) {
    Write-Host ''
    Write-Host 'TODOS OS PARES:'
    $linhas | Sort-Object distancia | ForEach-Object {
        Write-Host ('  {0,-26} {1,-11} {2,10:G6} contra {3,-10:G6} {4,8:P1} {5}' -f `
                    $_.limiar, $_.fixture, $_.valor, $_.alvo, $_.distancia, $_.lado)
    }
}

# Limiares sem populacao proxima: ninguem exercita os dois lados deles.
$semPop = @()
foreach ($L in $LIMIARES) {
    $g = @($linhas | Where-Object { $_.limiar -eq $L.id })
    if ($g.Count -eq 0) { $semPop += ('{0}  (nenhum fixture aplicavel)' -f $L.id); continue }
    $perto = @($g | Where-Object { $_.distancia -le 1.0 })
    if ($perto.Count -eq 0) { $semPop += ('{0}  (o mais proximo esta a {1:P0})' -f $L.id, (@($g | Sort-Object distancia)[0].distancia)) }
}
if ($semPop.Count) {
    Write-Host ''
    Write-Host 'LIMIARES ROBUSTOS POR ACIDENTE -- sem populacao proxima, entao o outro lado nunca foi exercitado:'
    $semPop | ForEach-Object { Write-Host ('  ' + $_) }
}

Write-Host ''
Write-Host 'NAO COBERTOS POR ESTE INVENTARIO, com o motivo:'
foreach ($s in $SEMCOBERTURA) {
    Write-Host ('  {0,-34} {1}' -f $s.id, $s.limiar)
    Write-Host ('  {0,-34} {1}' -f '', $s.porque)
}

Write-Host ''
if ($dentro.Count) {
    Write-Host ('{0} caso(s) dentro da faixa de {1:P0}:' -f $dentro.Count, $Faixa)
    foreach ($x in ($dentro | Sort-Object distancia)) {
        $k = '{0}|{1}' -f $x.fixture, $x.limiar
        $decl = $DECLARADOS.ContainsKey($k)
        Write-Host ('  {0} {1,-11} {2,-26} {3:P2} {4}' -f `
                    $(if ($decl) { 'DECLARADO  ' } else { 'NAO DECLARADO' }), $x.fixture, $x.limiar, $x.distancia, $x.lado)
        if ($decl) { Write-Host ('               {0}' -f $DECLARADOS[$k]) }
    }
}

$bad = 0
if ($naoDeclarados.Count) {
    Write-Host ''
    Write-Host ('MARGENS FAIL -- {0} caso(s) dentro da faixa sem declaracao.' -f $naoDeclarados.Count)
    Write-Host 'Ou o limiar esta no lugar errado, ou o fixture testa outra coisa do que se pensa.'
    Write-Host 'Decida qual, e escreva a entrada em $DECLARADOS com o motivo.'
    $bad += $naoDeclarados.Count
}
if ($declaradosVelhos.Count) {
    Write-Host ''
    Write-Host ('MARGENS FAIL -- {0} declaracao(oes) que nao valem mais:' -f $declaradosVelhos.Count)
    $declaradosVelhos | ForEach-Object { Write-Host ('  ' + $_) }
    Write-Host 'O caso saiu da faixa. Apague a entrada em vez de deixa-la envelhecer.'
    $bad += $declaradosVelhos.Count
}

if ($bad -gt 0) { exit 1 }
Write-Host 'MARGENS PASS'
