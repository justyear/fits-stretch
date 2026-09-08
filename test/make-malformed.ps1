# Gera o corpus de arquivos malformados da suite.
#
#   powershell -File test\make-malformed.ps1
#
# ASCII apenas -- ver make-fixture.ps1: o terceiro byte de um travessao em UTF-8
# e uma aspa curva em CP1252 e termina a string.
#
# POR QUE ESTES ARQUIVOS NAO SAO VERSIONADOS, sendo que os fixtures sao.
#
# A regra do projeto e que todo artefato de que a suite precisa esta rastreado,
# ou esta escrito por que nao esta. Este e o "por que".
#
# Os fixtures ficam versionados porque sao gerados com aritmetica de ponto
# flutuante em .NET, e determinismo entre maquinas era provavel, nao garantido;
# se a geracao divergisse, quem duvida nao poderia verificar nada. Aqui nao ha
# ponto flutuante nenhum: sao cartoes ASCII de 80 colunas, inteiros escritos em
# big-endian por [BitConverter], e blocos de bytes zerados. A geracao e
# identica em qualquer maquina por construcao, nao por sorte.
#
# E a divergencia continua detectavel: test/golden/malformed.json guarda o
# sha256 de cada arquivo, e compare-malformed.ps1 regenera e confere antes de
# olhar qualquer veredito. Se a geracao mudar, o teste falha dizendo isso, em
# vez de comparar em silencio outra coisa.
#
# O bonus e que .gitignore ja cobre *.fit e *.fz em qualquer pasta: nenhum
# arquivo daqui precisa de excecao escrita a mao, e a pergunta "de quem e isso?"
# continua sendo feita para todo .fit novo que aparecer na arvore.

$ErrorActionPreference = 'Stop'
$OUT = Join-Path (Split-Path -Parent $PSCommandPath) 'malformed'
if (-not (Test-Path $OUT)) { New-Item -ItemType Directory $OUT | Out-Null }
Get-ChildItem $OUT -File -ErrorAction SilentlyContinue | Remove-Item -Force

$written = New-Object System.Collections.ArrayList

function Raw([string]$s) { if ($s.Length -gt 80) { $s = $s.Substring(0, 80) }; return $s.PadRight(80) }
function Num([string]$k, $v) { return Raw ($k.PadRight(8) + '= ' + ("$v".PadLeft(20))) }
function Str([string]$k, [string]$v) { return Raw ($k.PadRight(8) + "= '" + $v + "'") }
function Pad2880([string]$t) { return $t + (' ' * ((2880 - ($t.Length % 2880)) % 2880)) }

function Put([string]$name, [string]$hdr, [byte[]]$body) {
    $b = [System.Text.Encoding]::ASCII.GetBytes((Pad2880 $hdr))
    $all = New-Object byte[] ($b.Length + $body.Length)
    [Array]::Copy($b, 0, $all, 0, $b.Length)
    if ($body.Length) { [Array]::Copy($body, 0, $all, $b.Length, $body.Length) }
    [System.IO.File]::WriteAllBytes((Join-Path $OUT $name), $all)
    [void]$written.Add($name)
    return $all.Length
}

# ---- imagem simples -------------------------------------------------------
# $over sobrescreve ou acrescenta cartoes; $bodyBytes de dado zerado atras.
function Img([string]$name, [string[]]$cards, [int]$bodyBytes, [byte[]]$body) {
    if ($null -eq $body) { $body = New-Object byte[] $bodyBytes }
    $n = Put $name ((@((Raw 'SIMPLE  =                    T')) + $cards + @((Raw 'END'))) -join '') $body
    '{0,-26} {1,8} B' -f $name, $n
}

$F32 = @((Num 'BITPIX' -32), (Num 'NAXIS' 2), (Num 'NAXIS1' 16), (Num 'NAXIS2' 16))

# ---- A. geometria ---------------------------------------------------------
Img 'a1-naxis1-negativo.fit'  @((Num 'BITPIX' -32), (Num 'NAXIS' 2), (Num 'NAXIS1' -100),       (Num 'NAXIS2' 16)) 2048 $null
Img 'a2-naxis1-zero.fit'      @((Num 'BITPIX' -32), (Num 'NAXIS' 2), (Num 'NAXIS1' 0),          (Num 'NAXIS2' 16)) 2048 $null
Img 'a3-naxis1-2e31.fit'      @((Num 'BITPIX' -32), (Num 'NAXIS' 2), (Num 'NAXIS1' 2147483648), (Num 'NAXIS2' 16)) 2048 $null
Img 'a4-17gb-declarado.fit'   @((Num 'BITPIX' -32), (Num 'NAXIS' 2), (Num 'NAXIS1' 65536),      (Num 'NAXIS2' 65536)) 2048 $null
Img 'a5-3planos-entrega1.fit' @((Num 'BITPIX' -32), (Num 'NAXIS' 3), (Num 'NAXIS1' 16), (Num 'NAXIS2' 16), (Num 'NAXIS3' 3)) 1024 $null
Img 'a6-produto-2e9.fit'      @((Num 'BITPIX' -32), (Num 'NAXIS' 2), (Num 'NAXIS1' 46341),      (Num 'NAXIS2' 46341)) 2048 $null
Img 'a7-pcount-negativo.fit'  @((Num 'BITPIX' -32), (Num 'NAXIS' 2), (Num 'NAXIS1' 4096), (Num 'NAXIS2' 4096), (Num 'PCOUNT' -67108864)) 2048 $null
Img 'a8-naxis-999.fit'        @((Num 'BITPIX' -32), (Num 'NAXIS' 999), (Num 'NAXIS1' 16), (Num 'NAXIS2' 16)) 2048 $null
Img 'a9-naxis3-negativo.fit'  @((Num 'BITPIX' -32), (Num 'NAXIS' 3), (Num 'NAXIS1' 16), (Num 'NAXIS2' 16), (Num 'NAXIS3' -5)) 2048 $null
Img 'a10-1x1.fit'             @((Num 'BITPIX' -32), (Num 'NAXIS' 2), (Num 'NAXIS1' 1), (Num 'NAXIS2' 1)) 0 ([byte[]](0x3D,0xCC,0xCC,0xCD))

# ---- B. BITPIX -----------------------------------------------------------
Img 'b1-bitpix-24.fit'     @((Num 'BITPIX' 24), (Num 'NAXIS' 2), (Num 'NAXIS1' 16), (Num 'NAXIS2' 16)) 2048 $null
Img 'b2-bitpix-zero.fit'   @((Num 'BITPIX' 0),  (Num 'NAXIS' 2), (Num 'NAXIS1' 16), (Num 'NAXIS2' 16)) 2048 $null
Img 'b3-bitpix-ausente.fit' @((Num 'NAXIS' 2), (Num 'NAXIS1' 16), (Num 'NAXIS2' 16)) 2048 $null
Img 'b4-bitpix-texto.fit'  @((Str 'BITPIX' 'abc'), (Num 'NAXIS' 2), (Num 'NAXIS1' 16), (Num 'NAXIS2' 16)) 2048 $null

# ---- C. cabecalho --------------------------------------------------------
# sem END: o leitor tem que parar no fim do arquivo, nao girar
$n = Put 'c1-sem-end.fit' ((@((Raw 'SIMPLE  =                    T')) + $F32) -join '') (New-Object byte[] 0)
'{0,-26} {1,8} B' -f 'c1-sem-end.fit', $n
# 50 mil cards antes do END: 4 MB de cabecalho
$many = New-Object System.Text.StringBuilder
[void]$many.Append((Raw 'SIMPLE  =                    T'))
foreach ($c in $F32) { [void]$many.Append($c) }
for ($i = 0; $i -lt 50000; $i++) { [void]$many.Append((Raw 'COMMENT')) }
[void]$many.Append((Raw 'END'))
$n = Put 'c2-50k-cards.fit' $many.ToString() (New-Object byte[] 2048)
'{0,-26} {1,8} B' -f 'c2-50k-cards.fit', $n
# menor que um bloco
[System.IO.File]::WriteAllBytes((Join-Path $OUT 'c3-curto.fit'),
    [System.Text.Encoding]::ASCII.GetBytes('SIMPLE  =                    T'))
[void]$written.Add('c3-curto.fit')
'{0,-26} {1,8} B' -f 'c3-curto.fit', 30

# ---- D. Rice / .fz -------------------------------------------------------
# Todos tem a mesma forma: HDU primario vazio, uma BINTABLE de UMA linha, e
# ZTILE cobrindo a imagem inteira -- entao tilesX*tilesY = 1 = NAXIS2 e a
# checagem de geometria passa, e o teste chega no que quer testar. O que muda
# entre eles e ZTILE, NAXIS1 (bytes por linha) e o descritor (nelem, hoff).
#
# $hoffFromEnd: -9999 significa "use o $hoff literal". Qualquer outro valor faz
# hoff ser calculado a partir do FIM do arquivo, com esse deslocamento -- e como
# os casos de limite ficam corretos mesmo se o cabecalho mudar de tamanho.
function Fz([string]$name, [int]$zt1, [int]$zt2, [int]$naxis1, [long]$nelem, [long]$hoff, [int]$hoffFromEnd) {
    $prim = Pad2880 ((Raw 'SIMPLE  =                    T') + (Num 'BITPIX' 8) + (Num 'NAXIS' 0) + (Raw 'END'))
    $tbl = (@(
        (Str 'XTENSION' 'BINTABLE'), (Num 'BITPIX' 8), (Num 'NAXIS' 2),
        (Num 'NAXIS1' $naxis1), (Num 'NAXIS2' 1), (Num 'PCOUNT' 200), (Num 'GCOUNT' 1),
        (Num 'TFIELDS' 1), (Str 'TTYPE1' 'COMPRESSED_DATA'), (Str 'TFORM1' '1PB(100)'),
        (Raw 'ZIMAGE  =                    T'), (Str 'ZCMPTYPE' 'RICE_1'),
        (Num 'ZBITPIX' 16), (Num 'ZNAXIS' 2), (Num 'ZNAXIS1' 64), (Num 'ZNAXIS2' 64),
        (Num 'ZTILE1' $zt1), (Num 'ZTILE2' $zt2),
        (Str 'ZNAME1' 'BLOCKSIZE'), (Num 'ZVAL1' 32), (Str 'ZNAME2' 'BYTEPIX'), (Num 'ZVAL2' 2),
        (Raw 'END')) -join '')
    $hdr = [System.Text.Encoding]::ASCII.GetBytes($prim + (Pad2880 $tbl))
    $all = New-Object byte[] ($hdr.Length + 8192)
    [Array]::Copy($hdr, 0, $all, 0, $hdr.Length)

    $ds = $hdr.Length                 # dataStart = primeira linha da tabela
    $heap = $ds + $naxis1 * 1         # THEAP ausente => rowBytes * rows
    if ($hoffFromEnd -ne -9999) { $hoff = $all.Length - $heap - $nelem + $hoffFromEnd }

    $e = [System.BitConverter]::GetBytes([int]$nelem); [Array]::Reverse($e); [Array]::Copy($e, 0, $all, $ds, 4)
    $e = [System.BitConverter]::GetBytes([int]$hoff);  [Array]::Reverse($e); [Array]::Copy($e, 0, $all, $ds + 4, 4)
    # bytes de "stream" logo depois do heap, para o caso hoff = 0. Alguns casos
    # apontam o heap para fora de proposito -- ai nao ha onde escrever.
    for ($i = 0; $i -lt 128; $i++) {
        $at = $heap + $i
        if ($at -ge 0 -and $at -lt $all.Length) { $all[$at] = [byte](($i * 37) % 256) }
    }

    [System.IO.File]::WriteAllBytes((Join-Path $OUT $name), $all)
    [void]$written.Add($name)
    '{0,-26} {1,8} B  ztile={2}x{3} rowBytes={4} nelem={5} hoff={6}' -f $name, $all.Length, $zt1, $zt2, $naxis1, $nelem, $hoff
}

Fz 'd1-ztile-100000.fz'     100000 100000 8 64 0 -9999          # teto: 1e10 int32 pedidos
Fz 'd6-ztile-16384.fz'       16384  16384 8 64 0 -9999          # teto: 1 GB pedido
Fz 'd7-heap-fora.fz'            64     64 8 100 2000000000 -9999
Fz 'd8-nelem-enorme.fz'         64     64 8 2000000000 0 -9999
Fz 'd9-heap-negativo.fz'        64     64 8 100 -2000000000 -9999
Fz 'd10-rowbytes-mentira.fz'    64     64 1000000 100 0 -9999
Fz 'd11-heap-1-alem.fz'         64     64 8 100 0 1         # heap+hoff+nelem = fim + 1
Fz 'd13-heap-no-limite.fz'      64     64 8 100 0 0         # ... = fim exato
Fz 'd12-stream-curto.fz'        64     64 8 64 0 -9999

# ---- E. escala e valores -------------------------------------------------
$d16 = New-Object byte[] 512
for ($i = 0; $i -lt 512; $i += 2) { $d16[$i] = 0x12; $d16[$i+1] = 0x34 }
Img 'e2-bscale-zero.fit'  @((Num 'BITPIX' 16), (Num 'NAXIS' 2), (Num 'NAXIS1' 16), (Num 'NAXIS2' 16), (Num 'BSCALE' 0)) 0 $d16
Img 'e3-bscale-texto.fit' @((Num 'BITPIX' 16), (Num 'NAXIS' 2), (Num 'NAXIS1' 16), (Num 'NAXIS2' 16), (Str 'BSCALE' 'nan')) 0 $d16
Img 'e5-bzero-bscale-1e308.fit' @((Num 'BITPIX' 16), (Num 'NAXIS' 2), (Num 'NAXIS1' 16), (Num 'NAXIS2' 16), (Num 'BZERO' '1.0E308'), (Num 'BSCALE' '1.0E308')) 0 $d16

$nan = New-Object byte[] 1024
for ($i = 0; $i -lt 1024; $i += 4) { $nan[$i]=0x7F; $nan[$i+1]=0xC0; $nan[$i+2]=0; $nan[$i+3]=0 }
Img 'e4-tudo-nan.fit' $F32 0 $nan

$half = New-Object byte[] 1024
for ($i = 0; $i -lt 1024; $i += 4) {
  if ((($i / 4) % 2) -eq 0) { $half[$i]=0x7F; $half[$i+1]=0xC0; $half[$i+2]=0; $half[$i+3]=0 }
  else { $half[$i]=0x3D; $half[$i+1]=0xCC; $half[$i+2]=0xCC; $half[$i+3]=0xCD }
}
Img 'e6-metade-nan.fit' $F32 0 $half

$inf = New-Object byte[] 1024
for ($i = 0; $i -lt 1024; $i += 4) {
  $k = ($i / 4) % 3
  if ($k -eq 0) { $inf[$i]=0x7F; $inf[$i+1]=0x80; $inf[$i+2]=0; $inf[$i+3]=0 }
  elseif ($k -eq 1) { $inf[$i]=0xFF; $inf[$i+1]=0x80; $inf[$i+2]=0; $inf[$i+3]=0 }
  else { $inf[$i]=0x3D; $inf[$i+1]=0xCC; $inf[$i+2]=0xCC; $inf[$i+3]=0xCD }
}
Img 'e7-infinitos.fit' $F32 0 $inf

$const = New-Object byte[] 1024
for ($i = 0; $i -lt 1024; $i += 4) { $const[$i]=0x3D; $const[$i+1]=0xCC; $const[$i+2]=0xCC; $const[$i+3]=0xCD }
Img 'e8-constante.fit' $F32 0 $const

Write-Host ''
Write-Host ('{0} arquivos em {1}' -f $written.Count, $OUT)

# sha256 de cada um, para quem estiver montando o malformed.json
if ($args -contains '-Hashes') {
    Write-Host ''
    foreach ($f in ($written | Sort-Object)) {
        $h = (Get-FileHash -Algorithm SHA256 (Join-Path $OUT $f)).Hash.ToLower()
        '  "{0}": "{1}",' -f $f, $h
    }
}
