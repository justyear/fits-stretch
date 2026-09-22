# Cobertura de FRASES: cada texto que o log pode emitir tem um caso que o imprime?
#
#   powershell -File test\compare-frases.ps1
#
# COBERTURA DE CODIGO E COBERTURA DE FRASES NAO SAO A MESMA COISA.
#
# Um ramo pode estar coberto por um teste que verifica o NUMERO e nunca imprime
# a FRASE -- e num produto cujo produto e o log, a frase e o que o usuario le.
#
# O caso que originou isto: o ramo `historyHits && mediana < 0,02` emitia
#
#     "Data is linear: median 0.01010, no stretch recorded in the header."
#
# num arquivo cujo header REGISTRA Autostretch e Midtones transfer. A frase era
# incondicional e nunca teve como ser contradita, porque nenhum fixture caia
# naquele ramo. O codigo passou por revisao -- alguem escreveu a condicao, alguem
# leu o diff. O TEXTO nao, porque ninguem nunca o viu impresso.
#
#   Um ramo sem fixture nao e so um ramo nao testado: e um ramo cujas frases
#   ninguem leu.
#
# COMO ELE MEDE, e o metodo e grosso de proposito:
#
#   1. tira os comentarios do log.js -- senao o apostrofo de "someone's" abre
#      uma string que nao existe;
#   2. extrai os literais de string e fica com os que parecem PROSA (25+ chars,
#      4+ palavras);
#   3. procura cada um na uniao de todos os goldens de log.
#
# Um literal que nao aparece em golden nenhum e uma frase que a suite nunca viu
# impressa. Fragmento concatenado conta: se o pedaco literal aparece, aquele
# caminho foi exercitado.
#
# E POR QUE E VERIFICACAO E NAO RELATORIO: um relatorio nao impede a proxima
# frase falsa. Frase sem caso que nao esteja DECLARADA abaixo reprova; declaracao
# que ganhou caso tambem reprova, porque envelheceu. Mesma disciplina do
# compare-margens e das ancoras de clip.
#
# ASCII apenas, sem BOM -- ver a nota no topo do compare-golden.ps1.

param([switch]$Tudo)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$gold = Join-Path $PSScriptRoot 'golden'

# ---------------------------------------------------------------------------
# FRASES SEM CASO, DECLARADAS.
#
# Duas classes, e a diferenca decide o que fazer com cada uma:
#
#   DIVIDA      da para cobrir com um fixture; falta o fixture
#   IMPOSSIVEL  nao pode aparecer num golden pela natureza do caso
#
# A chave e um pedaco do literal, o bastante para identificar sem repetir a
# frase inteira aqui -- repetir texto e criar uma segunda copia que envelhece.
# ---------------------------------------------------------------------------
$DECLARADAS = @(
    @{ chave = 'non-finite pixels were left out'
       classe = 'DIVIDA'
       porque = 'precisa de um fixture com NaN ou infinito na ENTRADA. O corpus malformed tem quatro (e4-tudo-nan, e6-metade-nan, e7-infinitos), mas ele mede VEREDITO DE DECODE e nao produz log -- entao a frase existe e nenhum golden a imprime. Fecha promovendo um dos casos parciais (e6) a fixture de cadeia' }

    @{ chave = 'odd frame dimensions rule out'
       classe = 'DIVIDA'
       porque = 'precisa de um quadro MONO de lado impar. Os tres de lado impar da suite (twoobjects, bigobject, oneobject) tem 3 planos, entao nem chegam ao teste de mosaico' }

    @{ chave = 'the header records stacking or registration'
       classe = 'DIVIDA'
       porque = 'precisa de um quadro de DOIS eixos, dimensoes pares, com HISTORY de empilhamento e sem BAYERPAT -- um stack mono, ou um stack de cor que ficou em 2D. Nao e o caso mais comum do publico-alvo (o stack de camera colorida sai com 3 planos e nem chega aqui), mas e um arquivo real e plausivel e a suite nao o tem' }

    @{ chave = 'The asinh stretch could not reach that target'
       classe = 'DIVIDA'
       porque = 'precisa de um quadro em que o asinh nao alcance o alvo -- mediana ja acima dele. O asinh-fixture usa o gradient, cuja mediana esta muito abaixo. Tres literais desta mesma frase' }

    @{ chave = 'so the transfer was left as the identity'
       classe = 'DIVIDA'
       porque = 'segunda parte da frase do asinh inalcancavel' }

    @{ chave = 'alone was applied. Nothing was silently approximated'
       classe = 'DIVIDA'
       porque = 'terceira parte da frase do asinh inalcancavel' }

    @{ chave = 'target background held at each channel'
       classe = 'DIVIDA'
       porque = 'variante do texto do alvo no ramo NAO-LINEAR por canal. O nonlinear entra por outro caminho, entao esta forma da frase nunca sai' }

    @{ chave = 'this browser cannot allocate a canvas at full size'
       classe = 'IMPOSSIVEL'
       porque = 'depende de o navegador FALHAR em alocar o canvas. Nao ha como provocar isso de forma reprodutivel numa captura, e um golden que dependesse de pressao de memoria seria pior que a frase sem caso' }

    # A variante CURTA da frase do degrau 5 -- a que sai sem a distancia.
    # Ela existe porque a distancia e `limiar/mediana` e mediana ZERO nao tem
    # distancia: dividir daria infinito e a frase sairia com 'n/a' no meio.
    #
    # NAO E HIPOTETICO, e foi medido nesta rodada: com o `declaraestica`
    # multiplicado por 1,501 o `normalisePhysical` troca para /65535, a mediana
    # LIDA vira exatamente zero e a imagem sai 100% preta. O mesmo acontece com
    # um quadro que ja chega quase todo em zero. O que falta e o caso SEM
    # declaracao no header -- o daquela medicao tinha duas.
    @{ chave = 'the median decided this on its own.'
       classe = 'DIVIDA'
       porque = 'a variante sem distancia, para mediana zero (ou nao-finita), que nao tem como ser dividida. Fecha com um fixture de quadro praticamente todo em zero e header mudo sobre esticamento -- a cena e barata, e o caso e real: um float mal escalado cai nele' }

    # MESMA CAUSA que a primeira entrada desta lista, do outro lado: o bloco de
    # header so imprime esta linha quando o decode achou valor nao-finito, e os
    # unicos arquivos da suite que tem sao os do corpus `malformed`, que mede
    # veredito de decode e nao produz saida de texto nenhuma.
    #
    # As duas fecham com o MESMO fixture, e e por isso que ficam anotadas uma ao
    # lado da outra: promover o `e6-metade-nan` a fixture de cadeia paga as duas
    # de uma vez.
    @{ chave = 'non-finite sample(s) were left out of all three'
       classe = 'DIVIDA'
       porque = 'a linha de nao-finitos do BLOCO DE HEADER. Mesma causa e mesmo conserto da primeira entrada desta lista: um fixture de cadeia com NaN na entrada paga as duas' }
)

# ---------------------------------------------------------------------------
# AS FONTES DE TEXTO, E POR QUE ISTO E UMA TABELA E NAO UMA VARIAVEL.
#
# Este arquivo mediu UMA fonte -- `log.js` -- durante toda a sua vida. Quando o
# botao "Copy header summary" entrou, com uma segunda fonte de prosa e um
# segundo corpus de goldens, ele continuou imprimindo os mesmos 148/139 sem uma
# palavra: a fonte nova simplesmente nao existia para ele.
#
# E a MESMA classe que esta sessao ja pegou duas vezes em uma rodada -- a
# comparacao debaixo de um `continue` e a lista `$Names` do compare-golden. Uma
# enumeracao escrita a mao nao reclama quando a lista cresce: ela responde sobre
# o que conhece, com a mesma cara de sempre.
#
# Entao a tabela vem com a guarda logo abaixo: todo golden de TEXTO que existe no
# disco tem que ter uma fonte aqui.
# ---------------------------------------------------------------------------
$FONTES = @(
    @{ rotulo = 'log';    fonte = 'src\pipeline\log.js';            corpus = '*-fixture.log.txt' }
    @{ rotulo = 'header'; fonte = 'src\pipeline\header-summary.js'; corpus = '*-fixture.header.txt' }
)

$frases = @(); $corpusPorFonte = @{}; $faltando = @()
foreach ($F in $FONTES) {
    $fp = Join-Path $root $F.fonte
    if (-not (Test-Path -LiteralPath $fp)) { $faltando += $F.fonte; continue }
    $texto = Get-Content -LiteralPath $fp -Raw -Encoding UTF8

    # Comentarios fora ANTES dos literais: o apostrofo de "someone's post" abre
    # uma string que nao existe e engole metade do arquivo. Foi o primeiro
    # resultado errado deste instrumento, e ele parecia plausivel -- quatro
    # "frases" que eram pedacos de codigo.
    $limpo = [regex]::Replace($texto, '/\*(?:.|\n)*?\*/', ' ')
    $limpo = [regex]::Replace($limpo, '(?m)//.*$', '')

    $literais = [regex]::Matches($limpo, "'((?:[^'\\]|\\.)*)'") | ForEach-Object { $_.Groups[1].Value }
    foreach ($l in $literais) {
        if ($l.Length -ge 25 -and (($l -split ' ').Count -ge 4) -and $l -notmatch '^\s+$') {
            $frases += [pscustomobject]@{ texto = $l; rotulo = $F.rotulo }
        }
    }

    $arqs = @(Get-ChildItem -LiteralPath $gold -Filter $F.corpus -ErrorAction SilentlyContinue)
    $corpusPorFonte[$F.rotulo] = @{
        texto = (($arqs | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }) -join "`n")
        n     = $arqs.Count
    }
}
if ($faltando.Count) { Write-Host ('fonte ausente: ' + ($faltando -join ', ')); exit 2 }

# Uma frase identica em duas fontes conta uma vez, e basta aparecer no corpus de
# QUALQUER uma delas: o que se pergunta e se alguem ja leu aquele texto impresso.
$frases = @($frases | Group-Object texto | ForEach-Object { $_.Group[0] })

$semCaso = @($frases | Where-Object { -not $corpusPorFonte[$_.rotulo].texto.Contains($_.texto) })
$comCaso = $frases.Count - $semCaso.Count
$logs = @($corpusPorFonte.Values | ForEach-Object { $_.n } | Measure-Object -Sum).Sum

# ---------------------------------------------------------------------------
# GUARDA: TODO GOLDEN DE TEXTO TEM UMA FONTE NA TABELA ACIMA.
#
# Mecanica de proposito -- os sufixos de texto que existem no disco menos os que
# a tabela cobre. A lista de fontes e escrita a mao, e foi escrita a mao que ela
# ficou para tras; a guarda e o que a impede de ficar de novo.
# ---------------------------------------------------------------------------
$sufixosNoDisco = @(Get-ChildItem -LiteralPath $gold -Filter '*-fixture.*.txt' -ErrorAction SilentlyContinue |
                    ForEach-Object { ($_.Name -replace '^.*?-fixture\.', '') } | Select-Object -Unique)
$sufixosCobertos = @($FONTES | ForEach-Object { $_.corpus -replace '^\*-fixture\.', '' })
$sufixosSemFonte = @($sufixosNoDisco | Where-Object { $sufixosCobertos -notcontains $_ })

function Declarada($f) {
    foreach ($d in $DECLARADAS) { if ($f.texto.Contains($d.chave)) { return $d } }
    return $null
}

$naoDeclaradas = @()
$usadas = @{}
foreach ($f in $semCaso) {
    $d = Declarada $f
    if ($null -eq $d) { $naoDeclaradas += $f; continue }
    $usadas[$d.chave] = $true
}
$declaracoesVelhas = @($DECLARADAS | Where-Object { -not $usadas.ContainsKey($_.chave) })

Write-Host ''
Write-Host ('COBERTURA DE FRASES -- {0} frases em {1} fonte(s), {2} goldens de texto' -f `
            $frases.Count, $FONTES.Count, $logs)
foreach ($F in $FONTES) {
    $nf = @($frases | Where-Object { $_.rotulo -eq $F.rotulo }).Count
    $ns = @($semCaso | Where-Object { $_.rotulo -eq $F.rotulo }).Count
    Write-Host ('  {0,-8} {1,4} frases, {2} sem caso, {3} goldens' -f `
                $F.rotulo, $nf, $ns, $corpusPorFonte[$F.rotulo].n)
}
Write-Host ('  com caso  {0,4}   ({1:P0})' -f $comCaso, ($comCaso / [double]$frases.Count))
Write-Host ('  sem caso  {0,4}' -f $semCaso.Count)
Write-Host ''

if ($semCaso.Count) {
    $porClasse = @{}
    foreach ($f in $semCaso) {
        $d = Declarada $f
        $c = if ($d) { $d.classe } else { 'NAO DECLARADA' }
        if (-not $porClasse.ContainsKey($c)) { $porClasse[$c] = 0 }
        $porClasse[$c]++
    }
    Write-Host 'SEM CASO, por classe:'
    foreach ($k in ($porClasse.Keys | Sort-Object)) { Write-Host ('  {0,-14} {1}' -f $k, $porClasse[$k]) }
    Write-Host ''
}

if ($Tudo -and $semCaso.Count) {
    Write-Host 'DETALHE:'
    foreach ($f in $semCaso) {
        $d = Declarada $f
        $c = if ($d) { $d.classe } else { 'NAO DECLARADA' }
        $t = if ($f.texto.Length -gt 70) { $f.texto.Substring(0, 70) + '...' } else { $f.texto }
        Write-Host ('  [{0}] [{1}] {2}' -f $c, $f.rotulo, $t)
        if ($d) { Write-Host ('           {0}' -f $d.porque) }
    }
    Write-Host ''
}

$bad = 0
if ($naoDeclaradas.Count) {
    Write-Host ('FRASES FAIL -- {0} frase(s) sem caso e sem declaracao:' -f $naoDeclaradas.Count)
    foreach ($f in $naoDeclaradas) {
        $t = if ($f.texto.Length -gt 70) { $f.texto.Substring(0, 70) + '...' } else { $f.texto }
        Write-Host ('  [{0}] {1}' -f $f.rotulo, $t)
    }
    Write-Host 'Ou o fixture que a imprime esta faltando, ou a frase esta morta.'
    Write-Host 'Decida qual, e escreva a entrada em $DECLARADAS com a classe e o motivo.'
    $bad += $naoDeclaradas.Count
}
if ($declaracoesVelhas.Count) {
    Write-Host ('FRASES FAIL -- {0} declaracao(oes) que nao valem mais:' -f $declaracoesVelhas.Count)
    $declaracoesVelhas | ForEach-Object { Write-Host ('  ' + $_.chave) }
    Write-Host 'A frase ganhou caso. Apague a entrada em vez de deixa-la envelhecer.'
    $bad += $declaracoesVelhas.Count
}
if ($sufixosSemFonte.Count) {
    Write-Host ('FRASES FAIL -- {0} golden(s) de texto sem fonte na tabela $FONTES:' -f $sufixosSemFonte.Count)
    $sufixosSemFonte | ForEach-Object { Write-Host ('  *-fixture.' + $_) }
    Write-Host 'Uma saida de texto nova entrou e este arquivo continuaria medindo so as antigas.'
    $bad += $sufixosSemFonte.Count
}

if ($bad -gt 0) { exit 1 }
Write-Host 'FRASES PASS'
