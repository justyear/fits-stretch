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
$fonte = Join-Path $root 'src\pipeline\log.js'

if (-not (Test-Path -LiteralPath $fonte)) { Write-Host 'src/pipeline/log.js ausente'; exit 2 }

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

    @{ chave = 'so the green sites line up with the'
       classe = 'DIVIDA'
       porque = 'o ramo `pattern.corrected`: BAYERPAT no header que NAO bate com a diagonal verde medida, e e espelhado. O seestar e o nobayer casam de primeira, entao o caminho da correcao nunca roda' }

    @{ chave = 'diagonal the pixels actually show'
       classe = 'DIVIDA'
       porque = 'mesma frase do ramo `pattern.corrected` acima, segunda metade' }

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
)

# ---------------------------------------------------------------------------
$texto = Get-Content -LiteralPath $fonte -Raw -Encoding UTF8

# Comentarios fora ANTES dos literais: o apostrofo de "someone's post" abre uma
# string que nao existe e engole metade do arquivo. Foi o primeiro resultado
# errado deste instrumento, e ele parecia plausivel -- quatro "frases" que eram
# pedacos de codigo.
$limpo = [regex]::Replace($texto, '/\*(?:.|\n)*?\*/', ' ')
$limpo = [regex]::Replace($limpo, '(?m)//.*$', '')

$literais = [regex]::Matches($limpo, "'((?:[^'\\]|\\.)*)'") | ForEach-Object { $_.Groups[1].Value }
$frases = @($literais | Where-Object {
    $_.Length -ge 25 -and (($_ -split ' ').Count -ge 4) -and $_ -notmatch '^\s+$'
} | Select-Object -Unique)

$logs = @(Get-ChildItem -LiteralPath $gold -Filter '*-fixture.log.txt')
$corpus = ($logs | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8 }) -join "`n"

$semCaso = @($frases | Where-Object { -not $corpus.Contains($_) })
$comCaso = $frases.Count - $semCaso.Count

function Declarada($f) {
    foreach ($d in $DECLARADAS) { if ($f.Contains($d.chave)) { return $d } }
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
Write-Host ('COBERTURA DE FRASES -- {0} frases no log.js, {1} goldens de log' -f $frases.Count, $logs.Count)
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
        $t = if ($f.Length -gt 78) { $f.Substring(0, 78) + '...' } else { $f }
        Write-Host ('  [{0}] {1}' -f $c, $t)
        if ($d) { Write-Host ('           {0}' -f $d.porque) }
    }
    Write-Host ''
}

$bad = 0
if ($naoDeclaradas.Count) {
    Write-Host ('FRASES FAIL -- {0} frase(s) sem caso e sem declaracao:' -f $naoDeclaradas.Count)
    foreach ($f in $naoDeclaradas) {
        $t = if ($f.Length -gt 78) { $f.Substring(0, 78) + '...' } else { $f }
        Write-Host ('  ' + $t)
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

if ($bad -gt 0) { exit 1 }
Write-Host 'FRASES PASS'
