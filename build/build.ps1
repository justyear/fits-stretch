# Assembles index.html from build/template.html + the pipeline source.
#
#   pwsh build/build.ps1           writes ../index.html
#   pwsh build/build.ps1 -Check    builds in memory and compares against the
#                                  index.html already on disk; exit 1 if they
#                                  differ. Also checks that nothing from the test
#                                  hooks leaked into the publication, that every
#                                  file the suite references is tracked by git,
#                                  and that the build hashes written into
#                                  test/golden/MANIFEST.md are today's.
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
    'src\pipeline\steps\colour-cal.js',
    'src\pipeline\steps\stretch-mtf.js',
    'src\pipeline\steps\saturation.js',
    'src\pipeline\steps\crop.js',
    'src\pipeline\render.js',
    'src\pipeline\log.js',
    'src\pipeline\header-summary.js',
    'src\pipeline\run.js'
) | ForEach-Object { Join-Path $root $_ }

# ISO-8859-1 maps bytes to chars one for one, so string work here is byte work:
# no BOM appears, no UTF-8 sequence is touched, no newline is rewritten.
$L1 = [System.Text.Encoding]::GetEncoding(28591)

function Read-Text($path) {
    if (-not (Test-Path -LiteralPath $path)) { throw "missing: $path" }
    return $L1.GetString([System.IO.File]::ReadAllBytes($path))
}

function Get-Sha256([byte[]]$b) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return -join ($sha.ComputeHash($b) | ForEach-Object { $_.ToString('x2') }) }
    finally { $sha.Dispose() }
}

$tpl = Read-Text $template

$at = $tpl.IndexOf($marker)
if ($at -lt 0) { throw "marker $marker not found in $template" }
if ($tpl.IndexOf($marker, $at + 1) -ge 0) { throw "marker $marker appears more than once in $template" }

$bundle = ($Sources | ForEach-Object { Read-Text $_ }) -join ''

<#
O CARIMBO DO BUILD, E POR QUE ELE E GERADO E NAO ESCRITO A MAO.

O bloco de header que a pessoa copia diz qual codigo mediu os tres numeros. Um
numero de versao escrito a mao so esta certo enquanto alguem lembra de mexer
nele -- e este projeto ja mediu o que acontece com uma lista escrita a mao que
ninguem atualiza (ver o MANIFEST desatualizado por dois commits, e a lista
`$Names` do compare-golden).

Entao o carimbo e o sha256 dos FONTES mais o template, cortado em 16 digitos, e
substitui `__BUILD_STAMP__` no pacote. Nao e circular: o hash e dos fontes COM o
marcador, nao da saida. Mexeu em qualquer fonte, o carimbo muda; nao mexeu, ele
nao muda -- que e o que faz `-Check` continuar comparando byte a byte.

O marcador tem que aparecer exatamente uma vez. Zero significa que o arquivo
saiu do pacote e o bloco passaria a anunciar um literal; duas significa duas
fontes de verdade.
#>
$stampMark = '__BUILD_STAMP__'
$stampHits = ([regex]::Matches($bundle, [regex]::Escape($stampMark))).Count
if ($stampHits -ne 1) { throw "$stampMark aparece $stampHits vez(es) no pacote; tem que aparecer exatamente uma" }
$buildStamp = (Get-Sha256 ($L1.GetBytes($bundle + $tpl))).Substring(0, 16)
$bundle = $bundle.Replace($stampMark, $buildStamp)

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


$hashTest    = Get-Sha256 $bytesTest
$hashPublish = Get-Sha256 $bytesPublish

# The published file must not contain what the block contained. Checked on the
# built bytes rather than trusted from the cut, because a second copy of any of
# these outside the markers would defeat the whole exercise silently.
$forbidden = @('__loadFromURL', '__state', 'fetch(')
$leaks = @()
foreach ($f in $forbidden) { if ($publish.Contains($f)) { $leaks += $f } }

# Todo arquivo de que a suite depende esta rastreado pelo git?
#
# Existe porque `git status` limpo respondeu a pergunta errada por uma sessao
# inteira: ele diz que tudo QUE E RASTREADO esta commitado, e nao diz nada sobre
# o que nao e. Dois fixtures foram gerados, tiveram goldens capturados e sha256
# escritos no MANIFEST, e nunca entraram no repositorio -- casavam com `*.fit` no
# .gitignore e a lista de excecoes tinha parado nos tres primeiros. Num clone
# novo a suite passaria a mentir sobre o que cobre.
#
# As referencias sao lidas dos proprios arquivos do harness, e nao de uma lista
# aqui: uma lista aqui seria a terceira copia da mesma verdade, e a que ninguem
# lembraria de atualizar.
function Test-Tracked {
    $probe = & git -C $root rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or $probe -ne 'true') {
        Write-Host 'rastreamento: pulado (nao e um repositorio git)'
        return @()
    }
    $tracked = @{}
    foreach ($f in (& git -C $root ls-files)) { $tracked[$f.Replace('\', '/')] = $true }

    $need = New-Object System.Collections.ArrayList
    $cap = Join-Path $root 'test\capture-golden.js'
    if (Test-Path -LiteralPath $cap) {
        foreach ($m in [regex]::Matches([System.IO.File]::ReadAllText($cap), "'/f/([^']+)'")) {
            $ref = $m.Groups[1].Value
            # Um prefixo concatenado no codigo -- '/f/test/malformed/' + f -- casa
            # com o mesmo regex e nao nomeia arquivo nenhum. Termina em barra.
            if ($ref.EndsWith('/')) { continue }
            [void]$need.Add($ref)
        }
    }
    $cmp = Join-Path $root 'test\compare-golden.ps1'
    if (Test-Path -LiteralPath $cmp) {
        $txt = [System.IO.File]::ReadAllText($cmp)
        $m = [regex]::Match($txt, '\$Names\s*=\s*@\(([^)]*)\)')
        if ($m.Success) {
            foreach ($n in [regex]::Matches($m.Groups[1].Value, "'([^']+)'")) {
                foreach ($kind in @('log.txt', 'diag.json', 'records.json', 'png')) {
                    [void]$need.Add('test/golden/' + $n.Groups[1].Value + '.' + $kind)
                }
            }
        }
    }

    # O corpus malformado nao e rastreado, e isso esta escrito: make-malformed.ps1
    # explica no cabecalho por que (geracao so com ASCII e inteiros, identica em
    # qualquer maquina por construcao), e malformed.json guarda o sha256 de cada
    # arquivo para que a divergencia seja detectavel. A lista sai desse mesmo
    # JSON, e nao de uma copia aqui: uma lista aqui seria a terceira copia da
    # mesma verdade, e a que ninguem lembraria de atualizar.
    $generated = @{}
    $mf = Join-Path $root 'test\golden\malformed.json'
    if (Test-Path -LiteralPath $mf) {
        $j = [System.IO.File]::ReadAllText($mf) | ConvertFrom-Json
        foreach ($n in $j.casos.PSObject.Properties.Name) { $generated['test/malformed/' + $n] = $true }
    }

    $missing = @()
    foreach ($f in ($need | Sort-Object -Unique)) {
        if (-not $tracked.ContainsKey($f) -and -not $generated.ContainsKey($f)) { $missing += $f }
    }
    if ($missing.Count -eq 0) {
        Write-Host ("rastreamento: {0} arquivos da suite, todos no git" -f $need.Count)
    }
    return $missing
}

# A tabela de hashes do MANIFEST bate com o build?
#
# Ela existe para quem quer conferir o arquivo baixado sem montar o build, entao
# nao pode sair -- e por ser escrita a mao, envelhece. Ficou desatualizada desde
# 509b705 sem que nada reclamasse, porque nenhum comparador a lia.
#
# Le entre marcadores em vez de casar a prosa: um regex sobre o texto corrido
# passaria a nao casar nada no dia em que alguem reescrevesse a frase, e uma
# verificacao que para de achar o que verificar vira PASS silencioso. Por isso
# marcador ausente, bloco vazio ou linha faltando sao FAIL, e nao "nada a
# fazer": este arquivo ja registra o caso do `rejected-edge`, onde quatro zeros
# foram lidos como medicao quando eram um teste morto.
function Test-Manifest($expect) {
    $path = Join-Path $root 'test\golden\MANIFEST.md'
    if (-not (Test-Path -LiteralPath $path)) { return @("MANIFEST.md ausente: $path") }
    $txt = [System.IO.File]::ReadAllText($path)

    $a = $txt.IndexOf('<!--BUILD_HASHES-->')
    $b = $txt.IndexOf('<!--/BUILD_HASHES-->')
    if ($a -lt 0 -or $b -lt 0 -or $b -lt $a) {
        return @('MANIFEST.md: marcadores BUILD_HASHES ausentes ou fora de ordem')
    }
    $block = $txt.Substring($a, $b - $a)

    $rows = @{}
    foreach ($m in [regex]::Matches($block, '\|\s*`([^`]+)`\s*\|\s*([0-9]+)\s*\|\s*`([0-9a-f]{64})`\s*\|')) {
        $rows[$m.Groups[1].Value] = @{ bytes = [int]$m.Groups[2].Value; hash = $m.Groups[3].Value }
    }

    $problems = @()
    foreach ($e in $expect) {
        $name = $e.name
        if (-not $rows.ContainsKey($name)) { $problems += "MANIFEST.md: sem linha para $name"; continue }
        $r = $rows[$name]
        if ($r.bytes -ne $e.bytes) {
            $problems += ("MANIFEST.md: {0} diz {1} bytes, o build tem {2}" -f $name, $r.bytes, $e.bytes)
        }
        if ($r.hash -ne $e.hash) {
            $problems += ("MANIFEST.md: {0} diz sha256 {1}, o build tem {2}" -f $name, $r.hash.Substring(0,16), $e.hash.Substring(0,16))
        }
    }
    if ($problems.Count -eq 0) {
        Write-Host ("MANIFEST: {0} hashes de build conferem com o que acabou de ser montado" -f $expect.Count)
    }
    return $problems
}

<#
O README MOSTRA DUAS SAIDAS "DE VERDADE", E ESTA CHECAGEM E O QUE AS TORNA DE
VERDADE.

A secao do log diz: "This is the whole log for the frame at the top of this
page -- not a sample, not an illustration, the actual file". A do bloco de header
diz "as it is stored and compared byte for byte". As duas frases eram promessa e
nao verificacao -- e a do log ja estava FALSA: a frase do degrau 5 mudou numa
rodada, o golden foi recapturado, e a copia do README ficou com a frase velha,
"no stretch recorded in the header", que o produto nao imprime mais.

E a mesma classe que esta sessao registrou tres vezes em uma semana: uma copia
escrita a mao ao lado de uma afirmacao de que ela e a coisa. O criterio tambem e
o mesmo: esquecer de atualizar a copia nao quebra nada, e o README continua
perfeitamente plausivel -- entao precisa de guarda.

A comparacao e byte a byte contra o golden, com UMA concessao dita: o bloco
cercado do markdown termina com uma quebra de linha antes da cerca, e o golden
nao. Nada mais e normalizado.
#>
function Test-ReadmeCopies {
    $path = Join-Path $root 'README.md'
    if (-not (Test-Path -LiteralPath $path)) { return @('README.md ausente') }
    $md = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($path))
    $problems = @()
    $pares = @(
        @{ secao = '## The log';            golden = 'test\golden\gradient-fixture.log.txt' },
        @{ secao = '## The header summary'; golden = 'test\golden\seestar-fixture.header.txt' }
    )
    foreach ($p in $pares) {
        $at = $md.IndexOf("`n" + $p.secao + "`n")
        if ($at -lt 0) { $problems += ("README.md: secao '{0}' nao encontrada" -f $p.secao); continue }
        $open = $md.IndexOf("`n" + '```' + "`n", $at)
        if ($open -lt 0) { $problems += ("README.md: '{0}' sem bloco cercado" -f $p.secao); continue }
        $start = $open + 5
        $close = $md.IndexOf("`n" + '```' + "`n", $start - 1)
        if ($close -lt 0) { $problems += ("README.md: bloco de '{0}' sem cerca de fechamento" -f $p.secao); continue }
        $bloco = $md.Substring($start, $close - $start)
        $gp = Join-Path $root $p.golden
        if (-not (Test-Path -LiteralPath $gp)) { $problems += ("{0} ausente" -f $p.golden); continue }
        $gold = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($gp))
        if ($bloco -ne $gold) {
            $bl = $bloco -split "`n"; $gl = $gold -split "`n"; $linha = 0
            for ($i = 0; $i -lt [Math]::Max($bl.Count, $gl.Count); $i++) {
                if ($i -ge $bl.Count -or $i -ge $gl.Count -or $bl[$i] -ne $gl[$i]) { $linha = $i + 1; break }
            }
            $problems += ("README.md, secao '{0}': difere de {1} a partir da linha {2} do bloco" -f $p.secao, $p.golden, $linha)
        }
    }
    if ($problems.Count -eq 0) {
        Write-Host ("README: {0} blocos que se dizem o arquivo de verdade conferem com o golden, byte a byte" -f $pares.Count)
    }
    return $problems
}

<#
AS CITACOES DE COMMIT DO NOTAS E DO MANIFEST EXISTEM NO HISTORICO ATUAL?

A reescrita do historico de 2026-09-23 trocou o SHA de todo commit a partir do
primeiro alterado, e nove citacoes -- sete no NOTAS, uma no MANIFEST, uma num
comentario deste arquivo -- ficaram apontando para commits que o historico atual
nao tem. Nada reclamou: uma citacao morta continua perfeitamente plausivel no
texto. E pior que plausivel: o GitHub ainda responde pelo SHA antigo, entao a
citacao era trilha para o historico que a reescrita existiu para tirar.

Como separar citacao de commit de sha256 de arquivo -- convencao desta arvore,
medida nos dois arquivos antes de virar regra:

  7 ou 40 hex    commit: a forma curta e a completa do git
  8, 16 ou 64    sha256: 8 com reticencias na prosa, 16 nos logs e relatorios,
                 64 completo

Qualquer outro comprimento com letra reprova como forma desconhecida, em vez de
passar sem conferencia: um commit citado com 9 caracteres escaparia de uma regra
que so olhasse os 7.

SO DIGITOS e o caso dificil: 3,7% dos SHAs curtos saem sem letra nenhuma, e a
parte fracionaria de um numero tambem -- `1,2509612` tem sete digitos depois da
virgula. A primeira versao desta checagem contava todo token de sete digitos e
reprovou tres ganhos de cor numa tabela do NOTAS; a medicao que a sustentava
tinha excluido, justamente, os numeros depois de virgula. A regra que a medicao
sustenta: toda citacao de commit dos dois arquivos esta entre crases. Entao um
token so de digitos conta como citacao quando e o conteudo inteiro de um trecho
entre crases, e token com letra conta em qualquer contexto.

A falha diz arquivo, linha e comprimento, e NAO o SHA. A citacao morta tipica e
um SHA do historico antigo, e imprimi-la gravaria na saida exatamente o que se
quer fora dela.
#>
function Test-Citacoes {
    $probe = & git -C $root rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0 -or $probe -ne 'true') {
        Write-Host 'citacoes de commit: pulado (nao e um repositorio git)'
        return @()
    }
    if ((& git -C $root rev-parse --is-shallow-repository 2>$null) -eq 'true') {
        return @('clone raso: com o historico incompleto, nao da para conferir citacao de commit')
    }
    $historico = @(& git -C $root rev-list HEAD)
    $problems = @()
    $n = 0
    foreach ($rel in @('NOTAS-SESSAO-FITS.md', 'test\golden\MANIFEST.md')) {
        $path = Join-Path $root $rel
        if (-not (Test-Path -LiteralPath $path)) { $problems += "$rel ausente"; continue }
        $linhas = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($path)) -split "`n"
        for ($i = 0; $i -lt $linhas.Count; $i++) {
            $l = $linhas[$i]
            foreach ($m in [regex]::Matches($l, '(?<![0-9A-Za-z])[0-9a-f]{7,64}(?![0-9A-Za-z])')) {
                $t = $m.Value
                if ($t -notmatch '[a-f]') {
                    $fim = $m.Index + $t.Length
                    $entreCrases = ($m.Index -gt 0 -and $l[$m.Index - 1] -eq '`' -and $fim -lt $l.Length -and $l[$fim] -eq '`')
                    if (-not $entreCrases) { continue }
                }
                if ($t.Length -eq 7 -or $t.Length -eq 40) {
                    $n++
                    $k = @($historico | Where-Object { $_.StartsWith($t) }).Count
                    if ($k -eq 0) {
                        $problems += ('{0}:{1}: citacao de commit ({2} caracteres) que nao existe no historico atual' -f $rel, ($i + 1), $t.Length)
                    } elseif ($k -gt 1) {
                        $problems += ('{0}:{1}: citacao de commit ({2} caracteres) ambigua: casa {3} commits' -f $rel, ($i + 1), $t.Length, $k)
                    }
                } elseif ($t.Length -in 8, 16, 64) {
                    continue
                } elseif ($t -match '[a-f]') {
                    $problems += ('{0}:{1}: hex de {2} caracteres -- nem commit (7 ou 40) nem sha256 (8, 16 ou 64)' -f $rel, ($i + 1), $t.Length)
                }
            }
        }
    }
    if ($problems.Count -eq 0) {
        Write-Host ("citacoes de commit: {0} no NOTAS e no MANIFEST, todas no historico atual" -f $n)
    }
    return $problems
}

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

    $untracked = Test-Tracked
    if ($untracked.Count) {
        Write-Host 'CHECK FAIL - a suite depende de arquivos que nao estao no git:'
        foreach ($u in $untracked) { Write-Host ("  {0}" -f $u) }
        $fail++
    }

    $stale = Test-Manifest @(
        @{ name = 'index.html';                bytes = $bytesPublish.Length; hash = $hashPublish },
        @{ name = '.claude/index-test.html';   bytes = $bytesTest.Length;    hash = $hashTest }
    )
    if ($stale.Count) {
        Write-Host 'CHECK FAIL - a tabela de hashes do MANIFEST nao bate com o build:'
        foreach ($s in $stale) { Write-Host ("  {0}" -f $s) }
        $fail++
    }

    $readme = Test-ReadmeCopies
    if ($readme.Count) {
        Write-Host 'CHECK FAIL - o README diz que mostra o arquivo de verdade, e nao mostra:'
        foreach ($s in $readme) { Write-Host ("  {0}" -f $s) }
        $fail++
    }

    $citacoes = Test-Citacoes
    if ($citacoes.Count) {
        Write-Host 'CHECK FAIL - citacao de commit que o historico atual nao confirma:'
        foreach ($s in $citacoes) { Write-Host ("  {0}" -f $s) }
        $fail++
    }

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
