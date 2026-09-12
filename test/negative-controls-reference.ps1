# Negative controls for compare-reference.ps1, IN A SWEEP.
#
#   powershell -File test\negative-controls-reference.ps1
#
# "A tolerance that cannot fail is not a tolerance, it is a rubber stamp" is in
# the header of negative-controls.ps1 and has been true since it was written.
# That file controls compare-golden, and of compare-reference it exercised ONE
# field. The comparator had 418 lines carrying a quota.
#
# It took a line that could not fail to make the gap visible: `rect.x/y/w/h`
# were judged against a density curve of PIXEL COUNTS while being POSITIONS, so
# the quota came out in the thousands and a real 214 px change read PASS~. The
# four earlier instances of the wrong-axis quota all FAILED a correct
# implementation - somebody had to look. This one passed. Nobody looks at a PASS.
#
# WHAT THIS DOES, and it is the cheap half of the answer:
#
#   for every field in the table below, set the golden so the difference from
#   the reference is exactly `f * cota`, and assert the verdict.
#
#     f = 0.5   ->  must NOT fail    (the quota is not tighter than it says)
#     f = 3.0   ->  must FAIL        (the quota is not a rubber stamp)
#
#   A field that passes BOTH is a quota that cannot fail, and it is reported
#   under that name.
#
# THE PERTURBATION IS ABSOLUTE, NOT RELATIVE TO WHAT IS THERE. The two sides
# already disagree a little on most fields, and adding f*cota on top of an
# existing difference would test f*cota + whatever. The golden is set to
# `referencia + f*cota`, so the difference IS the number being tested.
#
# TWO RUNS, NOT TWO PER FIELD. Every target row reads its own field, and none of
# the quotas is computed from a field in the table: `ganho` and `razao` take
# theirs from the reference's `acimaDoPedestal`, and `rect.*` from `objectRect`,
# which is not perturbed. So all the fields move at once and the whole sweep is
# one comparator run per factor - 53 rows in the time of two runs, and the same
# shape works when the table grows.
#
# THE QUOTA COMES FROM THE COMPARATOR, NOT FROM HERE. compare-reference emits a
# `cota` column for exactly this. A perturbation sized by a number copied into
# this file would go stale silently, which is the failure the clip anchors in
# negative-controls.ps1 already paid for once.
#
# ASCII only, no BOM - see the note at the top of compare-golden.ps1.

param([switch]$Quiet)

$ErrorActionPreference = 'Stop'

$here   = $PSScriptRoot
$root   = Split-Path -Parent $here
$gold   = Join-Path $here 'golden'
$cmpRef = Join-Path $here 'compare-reference.ps1'

if (-not (Test-Path -LiteralPath $cmpRef)) { Write-Host 'compare-reference.ps1 ausente'; exit 2 }

# ---------------------------------------------------------------------------
# A TABELA DOS ALVOS
#
# Comeca pelas 45 linhas propagadas e pelas 8 de posicao: as que tem Jacobiano e
# as que acabaram de mudar. Acrescentar um campo e acrescentar uma linha aqui
# mais um ramo em Set-GoldenField -- nada mais.
# ---------------------------------------------------------------------------
$ALVOS = @(
    @{ campo = 'ganho';        inteiro = $false },
    @{ campo = 'razao.rOverG'; inteiro = $false },
    @{ campo = 'razao.bOverG'; inteiro = $false },
    @{ campo = 'rect.x';       inteiro = $true  },
    @{ campo = 'rect.y';       inteiro = $true  },
    @{ campo = 'rect.w';       inteiro = $true  },
    @{ campo = 'rect.h';       inteiro = $true  }
)
$CAMPOS = @($ALVOS | ForEach-Object { $_.campo })

$IDXCH = @{ 'R' = 0; 'G' = 1; 'B' = 2 }
$IDXR  = @{ 'rect.x' = 0; 'rect.y' = 1; 'rect.w' = 2; 'rect.h' = 3 }

function Set-GoldenField($recs, $escopo, $campo, $valor) {
    $cc = $null; $cp = $null
    foreach ($r in @($recs)) {
        if ($r.id -eq 'colour-cal') { $cc = $r }
        if ($r.id -eq 'crop')       { $cp = $r }
    }
    if ($campo -eq 'ganho') {
        if ($null -eq $cc -or -not $IDXCH.ContainsKey($escopo)) { return $false }
        $cc.gains[$IDXCH[$escopo]] = $valor; return $true
    }
    if ($campo -eq 'razao.rOverG') {
        if ($null -eq $cc -or $null -eq $cc.stars -or $null -eq $cc.stars.ratios) { return $false }
        $cc.stars.ratios.rOverG = $valor; return $true
    }
    if ($campo -eq 'razao.bOverG') {
        if ($null -eq $cc -or $null -eq $cc.stars -or $null -eq $cc.stars.ratios) { return $false }
        $cc.stars.ratios.bOverG = $valor; return $true
    }
    if ($IDXR.ContainsKey($campo)) {
        if ($null -eq $cp -or $null -eq $cp.rect) { return $false }
        $cp.rect[$IDXR[$campo]] = $valor; return $true
    }
    return $false
}

function Invoke-Comparador($goldenDir) {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $cmpRef -Csv -Golden $goldenDir 2>$null
    return ($out | ConvertFrom-Csv)
}

function Read-Double($s, [ref]$dest) {
    return [double]::TryParse($s, [System.Globalization.NumberStyles]::Float,
                              [cultureinfo]::InvariantCulture, $dest)
}

# ---------------------------------------------------------------------------
# A linha de base: quem tem cota, e qual e
# ---------------------------------------------------------------------------
Write-Host 'lendo a linha de base...'
$baseRows = Invoke-Comparador $gold

$alvoRows = @()
foreach ($r in $baseRows) {
    if ($CAMPOS -notcontains $r.campo) { continue }
    if ([string]::IsNullOrWhiteSpace($r.cota)) { continue }
    $c = 0.0; $rv = 0.0
    if (-not (Read-Double $r.cota ([ref]$c)))       { continue }
    if (-not (Read-Double $r.referencia ([ref]$rv))) { continue }
    $inte = [bool](@($ALVOS | Where-Object { $_.campo -eq $r.campo })[0].inteiro)
    $alvoRows += [pscustomobject]@{ fixture = $r.fixture; escopo = $r.escopo; campo = $r.campo
                                    cota = $c; refv = $rv; inteiro = $inte }
}
$chaves = New-Object 'System.Collections.Generic.HashSet[string]'
foreach ($a in $alvoRows) { [void]$chaves.Add(('{0}|{1}|{2}' -f $a.fixture, $a.escopo, $a.campo)) }

# UMA LINHA DA TABELA SEM COTA NA COLUNA NAO E CONTROLAVEL, e isso e um defeito
# do comparador e nao um resultado desta varredura. Aparece separado, com nome,
# porque foi o primeiro achado: as oito linhas de `rect.*` construiam a cota,
# imprimiam em prosa e nao a punham na coluna.
$semCota = @()
foreach ($r in $baseRows) {
    if ($CAMPOS -notcontains $r.campo) { continue }
    $k = '{0}|{1}|{2}' -f $r.fixture, $r.escopo, $r.campo
    if (-not $chaves.Contains($k)) { $semCota += $k }
}

Write-Host ("{0} linhas alvo com cota" -f $alvoRows.Count)
if ($semCota.Count) {
    Write-Host ("{0} linha(s) da tabela SEM cota na coluna -- nao controlaveis:" -f $semCota.Count)
    $semCota | ForEach-Object { Write-Host ("   $_") }
}
if ($alvoRows.Count -eq 0) { Write-Host 'nada a controlar'; exit 1 }

$FILE = @{}
foreach ($f in (Get-ChildItem -LiteralPath $gold -Filter '*-fixture.records.json')) {
    $FILE[($f.Name -replace '-fixture\.records\.json$', '')] = $f.Name
}

# ---------------------------------------------------------------------------
# As duas rodadas
# ---------------------------------------------------------------------------
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('ncref-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$resultados = @{}
$semDentro  = @()

try {
    foreach ($fator in @(0.5, 3.0)) {
        $dir = Join-Path $work ('f' + ($fator.ToString('0.0', [cultureinfo]::InvariantCulture) -replace '\.', '_'))
        New-Item -ItemType Directory -Force $dir | Out-Null
        # So os .json e os .txt: o comparador nao le PNG, e copiar 50 MB de
        # imagem por rodada seria o grosso do tempo desta varredura.
        Get-ChildItem -LiteralPath $gold -File -Filter '*.json' | Copy-Item -Destination $dir -Force
        Get-ChildItem -LiteralPath $gold -File -Filter '*.txt'  | Copy-Item -Destination $dir -Force

        foreach ($g in ($alvoRows | Group-Object fixture)) {
            $fx = $g.Name
            if (-not $FILE.ContainsKey($fx)) { continue }
            $p = Join-Path $dir $FILE[$fx]
            $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json
            foreach ($a in $g.Group) {
                $delta = $fator * $a.cota

                # COTA ZERO E UM CASO PROPRIO, E E O CASO CERTO EM VARIAS
                # LINHAS: `rect.*` propaga zero enquanto as caixas forem iguais,
                # e `decode.raw*` e exato por derivacao. Multiplicar zero por 3
                # nao perturba nada e a rodada leria PASS -- exatamente o
                # veredito que esta varredura existe para desconfiar.
                #
                # Por fora, o teste passa a ser "a menor diferenca possivel ja
                # reprova?", que e o que cota zero AFIRMA. Por dentro nao ha o
                # que testar: nao existe folga dentro de zero, e isso e dito.
                if ($a.cota -eq 0) {
                    if ($fator -lt 1) {
                        $semDentro += ('{0}|{1}|{2}' -f $fx, $a.escopo, $a.campo)
                        continue
                    }
                    $delta = if ($a.inteiro) { 1.0 }
                             else { [math]::Max([math]::Abs($a.refv) * 1e-9, 1e-12) }
                }
                elseif ($a.inteiro) {
                    # Campo inteiro: a perturbacao tem que ser inteira, senao o
                    # comparador trunca e a rodada mede zero. Por dentro
                    # arredonda para baixo -- e quando isso da 0, a rodada nao
                    # testa nada, o que e DITO em vez de virar um PASS de graca.
                    if ($fator -lt 1) { $delta = [math]::Floor($delta) }
                    else              { $delta = [math]::Ceiling($delta) }
                    if ($fator -lt 1 -and $delta -lt 1) {
                        $semDentro += ('{0}|{1}|{2}' -f $fx, $a.escopo, $a.campo)
                        continue
                    }
                }
                [void](Set-GoldenField $j $a.escopo $a.campo ($a.refv + $delta))
            }
            [System.IO.File]::WriteAllText($p, (@($j) | ConvertTo-Json -Depth 40))
        }

        Write-Host ('rodando com a diferenca fixada em ' + $fator + 'x a cota...')
        foreach ($r in (Invoke-Comparador $dir)) {
            $k = '{0}|{1}|{2}' -f $r.fixture, $r.escopo, $r.campo
            # SO O QUE FOI PERTURBADO RECEBE VEREDITO. Uma linha que esta na
            # tabela mas nao entrou em $alvoRows nao foi mexida, e dar a ela um
            # veredito seria julgar uma cota que este script nao exercitou --
            # foi assim que a primeira rodada acusou `rect.*` de nao reprovar
            # quando o que faltava era a cota chegar na coluna.
            if (-not $chaves.Contains($k)) { continue }
            if (-not $resultados.ContainsKey($k)) { $resultados[$k] = @{} }
            $resultados[$k][$fator] = $r.resultado
        }
    }
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# O veredito
# ---------------------------------------------------------------------------
$linhas = @()
foreach ($k in ($resultados.Keys | Sort-Object)) {
    $p = $k -split '\|'
    $dentro = $resultados[$k][0.5]
    $fora   = $resultados[$k][3.0]
    $naoTestouDentro = ($semDentro -contains $k)

    $okDentro = $naoTestouDentro -or ($dentro -ne 'FAIL')
    $okFora   = ($fora -eq 'FAIL')

    $v = 'ok'
    if ($okDentro -and $okFora) { if ($naoTestouDentro) { $v = 'ok (so por fora)' } }
    elseif ((-not $okFora) -and (-not $okDentro)) { $v = 'INVERTIDA' }
    elseif (-not $okFora) { $v = 'COTA QUE NAO REPROVA' }
    else { $v = 'COTA APERTADA DEMAIS' }

    $linhas += [pscustomobject]@{
        fixture = $p[0]; escopo = $p[1]; campo = $p[2]
        'x0.5' = $(if ($naoTestouDentro) { '-' } else { $dentro }); 'x3' = $fora; veredito = $v
    }
}

if (-not $Quiet) { $linhas | Sort-Object veredito, campo, fixture | Format-Table -AutoSize }

$ok  = @($linhas | Where-Object { $_.veredito -like 'ok*' }).Count
$bad = @($linhas | Where-Object { $_.veredito -notlike 'ok*' }).Count

Write-Host ''
if ($semDentro.Count) {
    # Nao e aprovacao e nao e divergencia: e uma cota pequena demais para caber
    # meia unidade inteira dentro dela. Dizer isso e melhor que fingir que a
    # metade de dentro rodou.
    Write-Host ('{0} linha(s) so testadas por fora: a cota e menor que 2 e nao cabe meia unidade inteira' -f $semDentro.Count)
}
Write-Host ('{0} campos controlados: {1} como esperado, {2} divergentes' -f $linhas.Count, $ok, $bad)
if ($bad -gt 0) { Write-Host 'NEGATIVE CONTROLS (REFERENCE) FAIL'; exit 1 }
Write-Host 'NEGATIVE CONTROLS (REFERENCE) PASS'
