# Negative controls for compare-reference.ps1, IN A SWEEP.
#
#   powershell -File test\negative-controls-reference.ps1
#
# "A tolerance that cannot fail is not a tolerance, it is a rubber stamp" is in
# the header of negative-controls.ps1 and has been true since it was written.
# That file controls compare-golden, and of compare-reference it exercised ONE
# field. The comparator carries a quota on 447 lines.
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
# THE QUOTA COMES FROM THE COMPARATOR, NOT FROM HERE. compare-reference emits a
# `cota` column for exactly this. A perturbation sized by a number copied into
# this file would go stale silently, which is the failure the clip anchors in
# negative-controls.ps1 already paid for once.
#
# ---------------------------------------------------------------------------
# A VARREDURA PERTURBA TUDO DE UMA VEZ, E ISSO TEM UMA ARMADILHA PROPRIA
# ---------------------------------------------------------------------------
#
# Mover todos os campos numa rodada so e barato: cada linha le o proprio campo,
# entao 300 linhas saem no tempo de duas rodadas em vez de 600.
#
# So que ALGUMAS COTAS SAO CALCULADAS A PARTIR DE CAMPOS QUE ESTAO NA TABELA.
# `clipLow` tira a dela de |shadows - ref| + |lum.mediana - ref|, e os dois sao
# alvos; `mascara.abaixoDoLimiar` tira a dela de `mascara.fundo` e
# `mascara.ruido`, idem. Perturbar o alvo E a fonte da cota dele na mesma rodada
# mede uma cota que nao existe fora do teste, e o veredito nao vale.
#
# Supor quais interferem seria a mesma doenca que esta varredura existe para
# tratar. Entao ela MEDE: depois de cada rodada, a cota de cada linha e
# comparada com a da linha de base. Se mudou, aquela linha nao recebe veredito
# nesta passada -- vai para a proxima, onde as fontes dela ficam quietas. Repete
# ate parar de progredir, e o que sobrar e dito com nome.
#
# ASCII only, no BOM - see the note at the top of compare-golden.ps1.

param([switch]$Quiet, [int]$MaxPassadas = 6)

$ErrorActionPreference = 'Stop'

$here   = $PSScriptRoot
$root   = Split-Path -Parent $here
$gold   = Join-Path $here 'golden'
$cmpRef = Join-Path $here 'compare-reference.ps1'

if (-not (Test-Path -LiteralPath $cmpRef)) { Write-Host 'compare-reference.ps1 ausente'; exit 2 }

# ---------------------------------------------------------------------------
# A TABELA DOS ALVOS
#
# `{ci}` no caminho e o indice do canal, tirado do escopo R/G/B. `arquivo` diz
# em qual golden o campo mora: os records da cadeia, ou o diag do decode.
#
# Acrescentar um campo e acrescentar uma linha. O que NAO esta aqui esta fora
# por um motivo, e os motivos estao no rodape da saida -- nao em silencio.
# ---------------------------------------------------------------------------
$ALVOS = @(
    # --- calibracao de cor -------------------------------------------------
    @{ e = 'cor'; c = 'estrelas.pixels';    rec = 'colour-cal'; p = 'stars.pixels';              int = $true  }
    @{ e = 'cor'; c = 'limiar.inferior';    rec = 'colour-cal'; p = 'stars.thresholdLow';        int = $false }
    @{ e = 'cor'; c = 'lum.madn';           rec = 'colour-cal'; p = 'stars.luminanceMADN';       int = $false }
    @{ e = 'cor'; c = 'lum.mediana';        rec = 'colour-cal'; p = 'stars.luminanceMedian';     int = $false }
    @{ e = 'cor'; c = 'neutraliza.alvo';    rec = 'colour-cal'; p = 'neutralise.target';         int = $false }
    @{ e = 'cor'; c = 'razao.rOverG';       rec = 'colour-cal'; p = 'stars.ratios.rOverG';       int = $false }
    @{ e = 'cor'; c = 'razao.bOverG';       rec = 'colour-cal'; p = 'stars.ratios.bOverG';       int = $false }
    @{ e = 'cor'; c = 'rejeitado.extenso';  rec = 'colour-cal'; p = 'stars.rejected.extended';   int = $true  }
    @{ e = 'cor'; c = 'rejeitado.saturado'; rec = 'colour-cal'; p = 'stars.rejected.saturated';  int = $true  }
    @{ e = 'ch';  c = 'acimaDoPedestal';    rec = 'colour-cal'; p = 'stars.abovePedestal[{ci}]'; int = $false }
    @{ e = 'ch';  c = 'estrela.mediana';    rec = 'colour-cal'; p = 'stars.medians[{ci}]';       int = $false }
    @{ e = 'ch';  c = 'ganho';              rec = 'colour-cal'; p = 'gains[{ci}]';               int = $false }
    @{ e = 'ch';  c = 'neutraliza.offset';  rec = 'colour-cal'; p = 'neutralise.offsets[{ci}]';  int = $false }
    @{ e = 'ch';  c = 'pedestal';           rec = 'colour-cal'; p = 'stars.pedestals[{ci}]';     int = $false }

    # --- esticamento -------------------------------------------------------
    @{ e = 'stretch'; c = 'clipHigh';       rec = 'stretch';    p = 'linked.clipHigh';           int = $true  }
    @{ e = 'stretch'; c = 'clipLow';        rec = 'stretch';    p = 'linked.clipLow';            int = $true  }
    @{ e = 'stretch'; c = 'lum.madn';       rec = 'stretch';    p = 'linked.luminanceMADN';      int = $false }
    @{ e = 'stretch'; c = 'lum.mediana';    rec = 'stretch';    p = 'linked.luminanceMedian';    int = $false }
    @{ e = 'stretch'; c = 'pixelsRescaled'; rec = 'stretch';    p = 'colourFidelity.pixelsRescaled'; int = $true }
    @{ e = 'stretch'; c = 'shadows';        rec = 'stretch';    p = 'linked.shadows';            int = $false }
    @{ e = 'stretch'; c = 'target';         rec = 'stretch';    p = 'linked.target';             int = $false }

    # --- saturacao ---------------------------------------------------------
    @{ e = 'saturacao'; c = 'croma.sigmaAntes';      rec = 'saturation'; p = 'chromaNoise.sigmaBefore';  int = $false }
    @{ e = 'saturacao'; c = 'croma.sigmaDepois';     rec = 'saturation'; p = 'chromaNoise.sigmaAfter';   int = $false }
    @{ e = 'saturacao'; c = 'estouro.levantados';    rec = 'saturation'; p = 'overflow.pixelsLifted';    int = $true  }
    @{ e = 'saturacao'; c = 'estouro.reescalados';   rec = 'saturation'; p = 'overflow.pixelsRescaled';  int = $true  }
    @{ e = 'saturacao'; c = 'mascara.abaixoDoLimiar';rec = 'saturation'; p = 'mask.pixelsBelowSnrLow';   int = $true  }
    @{ e = 'saturacao'; c = 'mascara.fundo';         rec = 'saturation'; p = 'mask.background';          int = $false }
    @{ e = 'saturacao'; c = 'mascara.mascaraCheia';  rec = 'saturation'; p = 'mask.pixelsAtFullMask';    int = $true  }
    @{ e = 'saturacao'; c = 'mascara.ruido';         rec = 'saturation'; p = 'mask.noiseSigma';          int = $false }
    @{ e = 'saturacao'; c = 'matiz.amostras';        rec = 'saturation'; p = 'hueFidelity.driftSamples'; int = $true  }
    @{ e = 'saturacao'; c = 'faixa';                 rec = 'saturation'; p = 'FAIXA';                    int = $true  }

    # --- recorte -----------------------------------------------------------
    @{ e = 'recorte'; c = 'componentes';     rec = 'crop'; p = 'components';     int = $true  }
    @{ e = 'recorte'; c = 'extenso.pixels';  rec = 'crop'; p = 'extendedPixels'; int = $true  }
    @{ e = 'recorte'; c = 'sinal.pixels';    rec = 'crop'; p = 'signalPixels';   int = $true  }
    @{ e = 'recorte'; c = 'cobertura.antes'; rec = 'crop'; p = 'coverageBefore'; int = $false }
    @{ e = 'recorte'; c = 'cobertura.depois';rec = 'crop'; p = 'coverageAfter';  int = $false }
    @{ e = 'recorte'; c = 'rect.x';          rec = 'crop'; p = 'rect[0]';        int = $true  }
    @{ e = 'recorte'; c = 'rect.y';          rec = 'crop'; p = 'rect[1]';        int = $true  }
    @{ e = 'recorte'; c = 'rect.w';          rec = 'crop'; p = 'rect[2]';        int = $true  }
    @{ e = 'recorte'; c = 'rect.h';          rec = 'crop'; p = 'rect[3]';        int = $true  }

    # --- decode (mora no diag, nao nos records) ----------------------------
    @{ e = 'decode'; c = 'decode.rawMin';  arquivo = 'diag'; p = 'decoded.rawMin';  int = $false }
    @{ e = 'decode'; c = 'decode.rawMax';  arquivo = 'diag'; p = 'decoded.rawMax';  int = $false }
    @{ e = 'decode'; c = 'decode.normMin'; arquivo = 'diag'; p = 'decoded.normMin'; int = $false }
    @{ e = 'decode'; c = 'decode.normMax'; arquivo = 'diag'; p = 'decoded.normMax'; int = $false }

    # --- linearidade (tambem no diag) --------------------------------------
    #
    # Entrou quando a comparacao saiu de baixo de um `continue` e passou a rodar
    # de verdade. Esta varredura anunciou a falta sozinha, na mesma rodada:
    # "2 campo(s) com cota e SEM entrada na tabela" -- que e o comportamento
    # pelo qual ela existe, e a razao de ela nomear o que fica de fora em vez de
    # so contar o que cobre.
    @{ e = 'linearidade'; c = 'globalMedian'; arquivo = 'diag'; p = 'linearity.globalMedian'; int = $false }
)

# ---------------------------------------------------------------------------
# O QUE FICA DE FORA, E POR QUE. Aparece na saida, nunca em silencio.
# ---------------------------------------------------------------------------
$FORA = @(
    @{ padrao = '\(formula\)$'
       motivo = 'isolacao de formula: o lado "nosso" e CALCULADO pelo comparador a partir das entradas DELES, entao nenhum campo do golden o alimenta e perturbar o golden nao o move' }
)

$IDXCH = @{ 'R' = 0; 'G' = 1; 'B' = 2 }

function Get-RecordPorId($recs, $id) {
    foreach ($r in @($recs)) {
        if ($id -eq 'stretch') { if ($r.id -eq 'stretch-mtf' -or $r.id -eq 'stretch-asinh') { return $r } }
        elseif ($r.id -eq $id) { return $r }
    }
    return $null
}

# Caminho simples: `a.b`, `a[0].b`, `a.b[2]`. Devolve $false quando o caminho nao
# existe naquele golden -- que e informacao, nao erro: um fixture sem aquela
# etapa simplesmente nao tem o campo.
function Set-ByPath($obj, [string]$path, $valor) {
    if ($null -eq $obj) { return $false }
    $partes = $path -split '\.'
    $cur = $obj
    for ($i = 0; $i -lt $partes.Count; $i++) {
        $p = $partes[$i]; $idx = $null
        if ($p -match '^(.*)\[(\d+)\]$') { $p = $matches[1]; $idx = [int]$matches[2] }
        $ultimo = ($i -eq $partes.Count - 1)
        if ($null -eq $cur.PSObject.Properties[$p]) { return $false }
        if ($ultimo) {
            if ($null -eq $idx) { $cur.$p = $valor }
            else {
                if ($null -eq $cur.$p -or $idx -ge @($cur.$p).Count) { return $false }
                $cur.$p[$idx] = $valor
            }
            return $true
        }
        $cur = if ($null -eq $idx) { $cur.$p } else { $cur.$p[$idx] }
        if ($null -eq $cur) { return $false }
    }
    return $false
}

# As faixas de luminancia sao um array cujo rotulo e o limite inferior:
# `faixa[0.20]` e a entrada com range[0] = 0.20. Procurar pelo rotulo em vez de
# fixar o indice mantem isto valido se as faixas mudarem.
function Set-Faixa($rec, [string]$campo, $valor) {
    if ($null -eq $rec -or $null -eq $rec.saturationByLuminance) { return $false }
    if ($campo -notmatch '^faixa\[([0-9.]+)\]\.pixels$') { return $false }
    $lo = [double]$matches[1]
    foreach ($b in @($rec.saturationByLuminance)) {
        $rl = 0.0
        if ($null -eq $b.range) { continue }
        $rl = [double]@($b.range)[0]
        if ([math]::Abs($rl - $lo) -lt 5e-3) { $b.pixels = $valor; return $true }
    }
    return $false
}

# O `Write-Host` do comparador NAO some quando ele roda como processo filho: em
# PowerShell 5.1 a saida de Write-Host desce para o stdout do processo, entao as
# duas linhas de resumo dele ("comparados 701 ...", "nenhuma divergencia") vinham
# junto com o CSV e o ConvertFrom-Csv as lia como duas linhas a mais.
#
# Nao mudavam veredito -- elas nao tem cota e nunca casam com um alvo -- mas
# faziam ESTE script imprimir 703 onde o comparador imprime 701. Um instrumento
# que erra a propria contagem por dois nao merece credito nos outros numeros,
# entao o filtro e pelo veredito: so passa linha que tem um.
$VEREDITOS = @('PASS', 'PASS~', 'FAIL', 'N/A', 'KNOWN')

function Invoke-Comparador($goldenDir) {
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $cmpRef -Csv -Golden $goldenDir 2>$null
    return @($out | ConvertFrom-Csv | Where-Object { $VEREDITOS -contains $_.resultado })
}

function Read-Double($s, [ref]$dest) {
    return [double]::TryParse($s, [System.Globalization.NumberStyles]::Float,
                              [cultureinfo]::InvariantCulture, $dest)
}

# Casa uma linha do comparador com uma entrada da tabela.
function Find-Alvo([string]$escopo, [string]$campo) {
    foreach ($a in $ALVOS) {
        if ($a.c -eq 'faixa') {
            if ($a.e -eq $escopo -and $campo -like 'faixa[[]*].pixels') { return $a }
            continue
        }
        if ($a.c -ne $campo) { continue }
        if ($a.e -eq 'ch') { if ($IDXCH.ContainsKey($escopo)) { return $a } ; continue }
        if ($a.e -eq $escopo) { return $a }
    }
    return $null
}

# ---------------------------------------------------------------------------
# A linha de base
# ---------------------------------------------------------------------------
Write-Host 'lendo a linha de base...'
$baseRows = Invoke-Comparador $gold
Write-Host ("{0} linhas no comparador" -f $baseRows.Count)

$comCota = @($baseRows | Where-Object { -not [string]::IsNullOrWhiteSpace($_.cota) })
Write-Host ("{0} delas carregam cota" -f $comCota.Count)

$sobVarredura = @(); $foraPorMotivo = @{}; $semTabela = @{}
foreach ($r in $comCota) {
    $ignorada = $false
    foreach ($f in $FORA) {
        if ($r.campo -match $f.padrao) {
            if (-not $foraPorMotivo.ContainsKey($f.motivo)) { $foraPorMotivo[$f.motivo] = 0 }
            $foraPorMotivo[$f.motivo]++; $ignorada = $true; break
        }
    }
    if ($ignorada) { continue }

    $a = Find-Alvo $r.escopo $r.campo
    if ($null -eq $a) {
        $k = '{0}|{1}' -f $r.escopo, $r.campo
        if (-not $semTabela.ContainsKey($k)) { $semTabela[$k] = 0 }
        $semTabela[$k]++; continue
    }
    $c = 0.0; $rv = 0.0
    if (-not (Read-Double $r.cota ([ref]$c)))        { continue }
    if (-not (Read-Double $r.referencia ([ref]$rv))) { continue }

    $sobVarredura += [pscustomobject]@{
        fixture = $r.fixture; escopo = $r.escopo; campo = $r.campo
        cota = $c; refv = $rv; inteiro = [bool]$a.int
        rec = $a.rec; caminho = $a.p
        arquivo = $(if ($a.ContainsKey('arquivo')) { $a.arquivo } else { 'records' })
        ci = $(if ($IDXCH.ContainsKey($r.escopo)) { $IDXCH[$r.escopo] } else { -1 })
        chave = '{0}|{1}|{2}' -f $r.fixture, $r.escopo, $r.campo
    }
}
Write-Host ("{0} sob varredura" -f $sobVarredura.Count)

$FILEREC = @{}; $FILEDIAG = @{}
foreach ($f in (Get-ChildItem -LiteralPath $gold -Filter '*-fixture.records.json')) {
    $FILEREC[($f.Name -replace '-fixture\.records\.json$', '')] = $f.Name
}
foreach ($f in (Get-ChildItem -LiteralPath $gold -Filter '*-fixture.diag.json')) {
    $FILEDIAG[($f.Name -replace '-fixture\.diag\.json$', '')] = $f.Name
}

$baseCota = @{}
foreach ($a in $sobVarredura) { $baseCota[$a.chave] = $a.cota }

# ---------------------------------------------------------------------------
# As passadas
# ---------------------------------------------------------------------------
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('ncref-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$resolvidos = @{}     # chave -> @{ dentro; fora; soFora }
$pendentes  = @($sobVarredura)
$deslocadas = @{}
$passada    = 0

try {
    while ($pendentes.Count -gt 0 -and $passada -lt $MaxPassadas) {
        $passada++
        Write-Host ("passada {0}: {1} campo(s)" -f $passada, $pendentes.Count)
        $rodada = @{}
        $semDentro = New-Object 'System.Collections.Generic.HashSet[string]'

        foreach ($fator in @(0.5, 3.0)) {
            $dir = Join-Path $work ('p{0}_f{1}' -f $passada, ($fator.ToString('0.0', [cultureinfo]::InvariantCulture) -replace '\.', '_'))
            New-Item -ItemType Directory -Force $dir | Out-Null
            # So os .json e os .txt: o comparador nao le PNG, e copiar 50 MB de
            # imagem por rodada seria o grosso do tempo desta varredura.
            Get-ChildItem -LiteralPath $gold -File -Filter '*.json' | Copy-Item -Destination $dir -Force
            Get-ChildItem -LiteralPath $gold -File -Filter '*.txt'  | Copy-Item -Destination $dir -Force

            foreach ($g in ($pendentes | Group-Object fixture)) {
                $fx = $g.Name
                foreach ($arq in @('records', 'diag')) {
                    $doArq = @($g.Group | Where-Object { $_.arquivo -eq $arq })
                    if ($doArq.Count -eq 0) { continue }
                    $nome = if ($arq -eq 'records') { $FILEREC[$fx] } else { $FILEDIAG[$fx] }
                    if (-not $nome) { continue }
                    $p = Join-Path $dir $nome
                    $j = Get-Content -LiteralPath $p -Raw | ConvertFrom-Json

                    foreach ($a in $doArq) {
                        $delta = $fator * $a.cota

                        # COTA ZERO E UM CASO PROPRIO, e e o caso certo em
                        # varias linhas: `rect.*` propaga zero enquanto as caixas
                        # forem iguais, e `decode.raw*` e exato por derivacao.
                        # Multiplicar zero por 3 nao perturba nada e a rodada
                        # leria PASS -- exatamente o veredito que esta varredura
                        # existe para desconfiar. Por fora o teste vira "a menor
                        # diferenca possivel ja reprova?", que e o que cota zero
                        # AFIRMA. Por dentro nao ha folga dentro de zero.
                        if ($a.cota -eq 0) {
                            if ($fator -lt 1) { [void]$semDentro.Add($a.chave); continue }
                            $delta = if ($a.inteiro) { 1.0 }
                                     else { [math]::Max([math]::Abs($a.refv) * 1e-9, 1e-12) }
                        }
                        elseif ($a.inteiro) {
                            # Campo inteiro: a perturbacao tem que ser inteira,
                            # senao o comparador trunca e a rodada mede zero.
                            if ($fator -lt 1) { $delta = [math]::Floor($delta) }
                            else              { $delta = [math]::Ceiling($delta) }
                            if ($fator -lt 1 -and $delta -lt 1) { [void]$semDentro.Add($a.chave); continue }
                        }

                        $novo = $a.refv + $delta
                        $ok = $false
                        if ($a.arquivo -eq 'diag') {
                            $ok = Set-ByPath $j $a.caminho $novo
                        } elseif ($a.caminho -eq 'FAIXA') {
                            $ok = Set-Faixa (Get-RecordPorId $j $a.rec) $a.campo $novo
                        } else {
                            $cam = $a.caminho -replace '\{ci\}', "$($a.ci)"
                            $ok = Set-ByPath (Get-RecordPorId $j $a.rec) $cam $novo
                        }
                        if (-not $ok) { [void]$semDentro.Add('NAOALCANCADO|' + $a.chave) }
                    }
                    [System.IO.File]::WriteAllText($p, (@($j) | ConvertTo-Json -Depth 40))
                }
            }

            foreach ($r in (Invoke-Comparador $dir)) {
                $k = '{0}|{1}|{2}' -f $r.fixture, $r.escopo, $r.campo
                if (-not $baseCota.ContainsKey($k)) { continue }
                if (-not $rodada.ContainsKey($k)) { $rodada[$k] = @{} }
                $cv = 0.0
                $temCota = (-not [string]::IsNullOrWhiteSpace($r.cota)) -and (Read-Double $r.cota ([ref]$cv))
                $rodada[$k][$fator] = @{ v = $r.resultado; cota = $(if ($temCota) { $cv } else { $null }) }
            }
        }

        # Quem teve a cota deslocada pela propria varredura nao recebe veredito.
        $aindaPendentes = @()
        foreach ($a in $pendentes) {
            $k = $a.chave
            if (-not $rodada.ContainsKey($k)) { $aindaPendentes += $a; continue }
            $d = $rodada[$k][0.5]; $f = $rodada[$k][3.0]
            $mexeu = $false
            foreach ($lado in @($d, $f)) {
                if ($null -eq $lado) { $mexeu = $true; continue }
                if ($null -eq $lado.cota) { $mexeu = $true; continue }
                if ([math]::Abs($lado.cota - $a.cota) -gt ([math]::Abs($a.cota) * 1e-9 + 1e-12)) { $mexeu = $true }
            }
            if ($mexeu -and $passada -lt $MaxPassadas) {
                $deslocadas[$k] = $true
                $aindaPendentes += $a
                continue
            }
            $resolvidos[$k] = @{
                dentro = $(if ($d) { $d.v } else { 'NONE' })
                fora   = $(if ($f) { $f.v } else { 'NONE' })
                soFora = $semDentro.Contains($k)
                naoAlcancado = $semDentro.Contains('NAOALCANCADO|' + $k)
                cotaDeslocada = $mexeu
            }
        }

        if ($aindaPendentes.Count -eq $pendentes.Count) {
            # Sem progresso: os que sobraram interferem entre si e repetir a
            # mesma passada nao muda nada. Sai do laco e eles sao DITOS.
            $pendentes = $aindaPendentes
            break
        }
        $pendentes = $aindaPendentes
    }
} finally {
    Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# O veredito
# ---------------------------------------------------------------------------
$linhas = @()
foreach ($k in ($resolvidos.Keys | Sort-Object)) {
    $p = $k -split '\|'
    $r = $resolvidos[$k]
    $okDentro = $r.soFora -or ($r.dentro -ne 'FAIL')
    $okFora   = ($r.fora -eq 'FAIL')

    $v = 'ok'
    if ($r.naoAlcancado) { $v = 'CAMPO NAO ALCANCADO NO GOLDEN' }
    elseif ($okDentro -and $okFora) { if ($r.soFora) { $v = 'ok (so por fora)' } }
    elseif ((-not $okFora) -and (-not $okDentro)) { $v = 'INVERTIDA' }
    elseif (-not $okFora) { $v = 'COTA QUE NAO REPROVA' }
    else { $v = 'COTA APERTADA DEMAIS' }

    $linhas += [pscustomobject]@{
        fixture = $p[0]; escopo = $p[1]; campo = $p[2]
        'x0.5' = $(if ($r.soFora) { '-' } else { $r.dentro }); 'x3' = $r.fora; veredito = $v
    }
}

if (-not $Quiet) {
    $ruins = @($linhas | Where-Object { $_.veredito -notlike 'ok*' })
    if ($ruins.Count) { $ruins | Sort-Object campo, fixture | Format-Table -AutoSize }
    else { $linhas | Group-Object campo | Sort-Object Name |
           ForEach-Object { '{0,-26} {1,3} campo(s) ok' -f $_.Name, $_.Count } }
}

$ok  = @($linhas | Where-Object { $_.veredito -like 'ok*' }).Count
$bad = @($linhas | Where-Object { $_.veredito -notlike 'ok*' }).Count
$soF = @($linhas | Where-Object { $_.veredito -eq 'ok (so por fora)' }).Count

Write-Host ''
Write-Host ('{0} linhas no comparador, {1} com cota, {2} sob varredura' -f $baseRows.Count, $comCota.Count, $sobVarredura.Count)
if ($soF) {
    Write-Host ('   {0} testadas so por fora: cota zero, ou menor que 2 num campo inteiro' -f $soF)
}
if ($pendentes.Count) {
    # Nao e aprovacao e nao e divergencia: sao linhas cuja cota se move quando a
    # varredura mexe nas fontes dela, e que nao se separaram em passadas.
    Write-Host ('   {0} sem veredito: a cota delas se desloca com a propria varredura' -f $pendentes.Count)
    $pendentes | ForEach-Object { Write-Host ('      {0}' -f $_.chave) }
}
foreach ($k in $foraPorMotivo.Keys) {
    Write-Host ('   {0} fora da tabela: {1}' -f $foraPorMotivo[$k], $k)
}
if ($semTabela.Count) {
    Write-Host ('   {0} campo(s) com cota e SEM entrada na tabela:' -f ($semTabela.Values | Measure-Object -Sum).Sum)
    $semTabela.Keys | Sort-Object | ForEach-Object { Write-Host ('      {0}  x{1}' -f $_, $semTabela[$_]) }
}
Write-Host ''
Write-Host ('{0} campos controlados em {1} passada(s): {2} como esperado, {3} divergentes' -f $linhas.Count, $passada, $ok, $bad)
if ($bad -gt 0) { Write-Host 'NEGATIVE CONTROLS (REFERENCE) FAIL'; exit 1 }
Write-Host 'NEGATIVE CONTROLS (REFERENCE) PASS'
