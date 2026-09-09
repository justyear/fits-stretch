# Números de referência — segunda implementação em Python

Gerado sobre os três fixtures sintéticos. Destrava o bloqueio do Módulo 1.

## O que é independente e o que não é

**Independente:** linguagem, leitor de FITS (astropy vs o parser JS próprio),
descompressão Rice (astropy vs `riceDecompress`), precisão (float64 vs float32),
estatística (exata sobre todos os pixels vs histograma de 65536 bins) e
transferência (MTF avaliada direto vs LUT de 2²⁰).

**Não independente:** a fórmula. Li o `index.html` para implementar o mesmo
algoritmo — MTF, `SHADOW_SIGMA = -2.80`, `TARGET = 0.25`, `BLACK_PCT = 0.0005`,
a regra do `nonLinear`, a normalização por faixa de container.

Então isto valida **aritmética, não escolha de algoritmo**. Se a fórmula do
autostretch estiver errada, as duas implementações erram junto. O que isto pega
é bug de leitura, de normalização, de row order, de estatística e de
quantização.

---

## Correção — a divergência do `rawMin` era erro meu

O harness achou `rice.decode.rawMin` = 0 na implementação JS e −0,5066 nesta
referência. **A implementação JS estava certa e esta referência estava errada.**

A convenção reserva o inteiro `−2147483647` no `SUBTRACTIVE_DITHER_2` para
significar "o valor original era 0.0". Verifiquei que a sentinela está
fisicamente no arquivo: com `ZSCALE = 6,2e-06` e `ZZERO = 13313,892` da tabela
binária, dequantizar a sentinela **sem** tratá-la como tal dá
`(−2147483647 + 0,5 − r) × ZSCALE + ZZERO`, que varre de −0,5066083 (r=0) a
−0,5066145 (r→1). É exatamente a faixa que o astropy produz, e são exatamente
576 pixels por canal — o patch 24×24.

O astropy 8.0.1 **documenta** que restaura esses pixels para 0.0 e não
restaura. O `reference.py` agora detecta a faixa e restaura: 1728 pixels
(576 × 3), `rawMin` volta a 0,0, medianas e `clipLow` inalterados. `clipLow`
bate em 576 por canal nos dois lados.

Isso também descarta a hipótese de erro simétrico no par codificador/
decodificador: a sentinela está no arquivo no padrão de bits exato que a
convenção especifica, confirmado por uma ferramenta terceira que a lê como
inteiro cru.

O item `KNOWN` do comparador pode ser fechado.

---

## Resultado 1 — o decodificador Rice está confirmado por fora

Este é o resultado mais forte da rodada.

O `fixture-rice.fit.fz` decodificado pelo astropy, com medianas exatas em
float64 pelo numpy:

```
R = 0.017072571
G = 0.015522887
B = 0.014283289

R/G = 1.0998    B/G = 0.9201
```

O Claude Code reportou, pelo decodificador JS com estatística de histograma:
`R:G:B = 1,099 : 1 : 0,920`.

Batem. São dois decodificadores Rice diferentes e dois motores de estatística
diferentes chegando ao mesmo lugar. Somando ao Siril, que leu o arquivo como
`3 layer(s), 2600x1000, 32 bits`, a pendência do codificador Rice fecha por
duas vias independentes.

---

## Resultado 2 — a preocupação com `BINS = 65536` era exagerada

Eu tinha estimado ~8% de erro na mediana de fundo. Medido, o erro é bem menor,
e o motivo é que o estimador de MAD dele é melhor do que histograma ingênuo: o
segundo histograma usa escala adaptativa `span = 3*(q3-q1)`, então a resolução
do MAD é `span/65535` em vez de `1/65535`.

Erro do histograma contra o exato, nos três fixtures:

| fixture | Δmediana rel. | ΔMADN rel. | Δmidtones rel. |
|---|---|---|---|
| seestar | 0,000% | 0,005% | 0,005% |
| rice | ≤0,013% | ≤0,045% | ≤0,046% |
| nonlinear | ≤0,004% | ≤0,021% | ≤0,027% |

Onde a preocupação se sustenta é em fundo escuro, e o erro cresce rápido:

| fundo | Δmediana rel. | ΔMADN rel. |
|---|---|---|
| 0,0002 | 0,82% | 1,29% |
| 0,0005 | 2,33% | 11,16% |
| 0,001 | 0,82% | 1,43% |
| 0,005 | 0,21% | 0,15% |
| 0,017 | 0,009% | 0,005% |
| 0,05 | 0,017% | 0,001% |

Dado real de Seestar/S30 fica em torno de 0,017 — a medida de um stack de
parceiro de teste foi 0,017060. Nessa faixa o histograma é irrelevante. Abaixo
de 0,005 ele começa a doer, e a calibração de cor do Módulo 2 deriva ganhos de
razões entre medianas.

**Não é bloqueio.** É uma linha na spec: se a mediana de um canal cair abaixo
de 0,005, trocar o estimador por seleção exata antes de derivar ganho.

---

## Resultado 3 — o custo do LUT é ±1 nível, e não é o problema

| fixture | pixels que diferem | máx. diferença |
|---|---|---|
| seestar | 2,14% | 1 |
| rice | 0,47–0,51% | 1 |
| nonlinear | 0,042–0,045% | 1 |

O LUT de 2²⁰ custa no máximo 1 nível de 255, em poucos por cento dos pixels.
Isso confirma que o LUT em si está bem dimensionado.

O problema que discutimos é outro e continua de pé: não é a precisão do LUT, é
a **cadeia**. Uma etapa que devolve float valendo `k/255` entrega 256 níveis
para a próxima, não 2²⁰. É a diferença entre perder 1 nível uma vez e trabalhar
em 8 bits o caminho todo.

---

## Números por fixture

### seestar — 1920×1080, BITPIX 16, BZERO 32768, GRBG, BOTTOM-UP

Normalização `int`, faixa de container [0, 65535]. Flip aplicado.
`globalMedian = 0.010940719`, `nonLinear = false`.

Mosaico CFA antes do debayer:

| | mediana | MADN | q1 | q3 | p0,05% | min | max |
|---|---|---|---|---|---|---|---|
| MONO | 0,010940719 | 0,001221643 | 0,010147250 | 0,011795224 | 0,008072023 | 0,007797360 | 0,315098802 |

Autostretch: `shadows = 0.007520117`, `midtones = 0.010268776`, `target = 0.25`,
`scale = 1.0075770979`. Saída: mediana 64, clipLow 0,0000%, clipHigh 0,0000%.

**Ressalva:** estes números são do mosaico, antes do debayer. Não implementei o
debayer dele, então o método de interpolação não está validado aqui. Para
comparar, o harness precisa medir o mosaico no mesmo ponto do pipeline.

### rice — 2600×1000×3, float32, RICE_1, sem ROWORDER

Normalização `unit` (float já em [0,1]). Sem `ROWORDER` → default FITS
bottom-up → flip aplicado. `globalMedian = 0.015626249`, `nonLinear = false`.

| ch | mediana | MADN | shadows | midtones | saída med | clipLow% | clipHigh% |
|---|---|---|---|---|---|---|---|
| R | 0,017072571 | 0,001868839 | 0,011839822 | 0,015719848 | 64 | 0,0222 | 0,0004 |
| G | 0,015522887 | 0,001704462 | 0,010750395 | 0,014334758 | 64 | 0,0222 | 0,0000 |
| B | 0,014283289 | 0,001572996 | 0,009878899 | 0,013227324 | 64 | 0,0222 | 0,0003 |

### nonlinear — 900×600×3, float32, TOP-DOWN, HISTORY de autostretch

Sem flip. `globalMedian = 0.246722261`, 2 HISTORY casaram,
`nonLinear = true` → ramo de esticamento reduzido.

| ch | mediana | MADN | shadows | midtones | target | saída med | clipLow% |
|---|---|---|---|---|---|---|---|
| R | 0,264060393 | 0,019945229 | 0,218156753 | 0,148093440 | 0,264060 | 67 | 0,0500 |
| G | 0,245694630 | 0,019134358 | 0,201546737 | 0,152316825 | 0,245695 | 63 | 0,0500 |
| B | 0,230411761 | 0,018398624 | 0,187791586 | 0,156099596 | 0,230412 | 59 | 0,0500 |

O ramo `nonLinear` está exercitado: `shadows` vem do percentil 0,05% e não da
regra de sigma, e `target` é a própria mediana em vez de 0,25.

---

## Tolerâncias sugeridas para o harness

**Corrigido.** A primeira versão deste documento sugeria 1e-4 relativo para
tudo, o que fica **abaixo do piso do próprio histograma** — um bin vale
1/65535 = 1,53e-5, que numa mediana de 0,017 já é 9e-4 relativo. Reprovaria a
implementação correta.

| grandeza | tolerância |
|---|---|
| mediana, q1, q3, percentis, shadows, midtones | `max(1e-4 × \|ref\|, 4/65535)` |
| MAD e MADN | `max(1e-4 × \|ref\|, 8 × span/65535)` |
| saída em 8 bits, por pixel | até 1 nível |
| contagem de clip | 0,05% do total |

`span = 3 × (q3 − q1)` do canal, ou `1/65535` se o IQR for zero.

MAD e MADN precisam de piso próprio porque não vivem na escala [0,1] — vivem
na escala adaptativa do segundo histograma. Nos fixtures lineares `span` fica
em ~0,007, o que faz um piso plano de 4/65535 valer entre **526 e 809 bins de
MADN**. Aceitaria erro 500 vezes maior que a resolução real.

Pior caso observado com o critério acima: 2,76 bins em [0,1] (limite 4) e 7,25
bins de span em MADN (limite 8). É o piso do instrumento, não folga.

---

## O que isto ainda não cobre

- **Debayer.** Não implementado aqui. O `fixture-seestar` só tem referência de
  mosaico.
- **A fórmula do autostretch.** Compartilhada de propósito, então erro comum
  passa nas duas.
- **Fundo abaixo de 0,005.** Nenhum fixture chega lá. O caso onde o histograma
  degrada não está representado.
- **BYTEPIX 1/2 e BITPIX −64.** Já anotados na spec.

---

## Travamento contra fixture trocado

O JSON grava o `sha256` e o tamanho de cada fixture de que foi calculado. Se um
fixture for regerado, os números ficam obsoletos em silêncio — o comparador
deve verificar o hash antes de comparar e falhar com mensagem clara, não
comparar contra referência velha.

```
seestar    4.150.080 B  sha256 6d0acf7bbd4ce595...
rice       8.671.680 B  sha256 6d12044518489703...
nonlinear  6.482.880 B  sha256 f11ae11071b83e48...
```

Ambiente que gerou: astropy 8.0.1, numpy 2.4.4.

---

# Passo 7 — o que `reference_bg.py` e `chain.py` precisam cobrir

A cadeia mudou duas vezes desde a última referência. Hoje ela é:

```
decode → debayer → extração de fundo → calibração de cor → esticamento LIGADO → quantise
```

`chain.py` modela até o fundo e depois faz autostretch **por canal**. Os dois
últimos elos são novos, e é por isso que 7 comparações estão em N/A e os dois
controles negativos do termo da mediana ficaram não-exercitáveis.

Este documento é a especificação executável. **Tudo que está escrito aqui é
comportamento observado do código que está commitado**, não intenção. Onde há
uma escolha de arredondamento ou de definição, ela está marcada com ⚠ — foram
esses dois tipos de detalhe que custaram duas rodadas da última vez.

---

## 1. Regra de aritmética, que vale para tudo abaixo

O quadro é **float32** do decode até o quantise.

⚠ **Toda escrita de volta no quadro arredonda para float32. Toda redução
(mediana, média, soma) roda em float64 sobre valores que estavam em float32.**

Em NumPy isso é:

```python
# ler para reduzir: sobe para float64, não arredonda nada
med = float(np.median(plane.astype(np.float64)))

# escrever de volta: desce para float32, arredonda
plane[:] = (plane.astype(np.float64) - offset).astype(np.float32)
```

Fazer a subtração inteira em float32 dá um resultado diferente, e é a diferença
que aparece no quinto decimal do golden.

**Mediana**: `np.median`, isto é, para contagem par a **média dos dois centrais**,
calculada em float64. A implementação JS usa `quickselect` com exatamente essa
convenção, de propósito, para que as duas estejam computando a mesma definição
em vez de duas aproximações dela.

**NaN**: excluído de toda redução, sempre. Nunca propagado, nunca substituído
por zero — exceto num lugar, marcado abaixo.

---

## 2. Calibração de cor — `colour_cal(planes, w, h, params)`

Entra o quadro **depois da extração de fundo** (o `corrected` que o `chain.py`
já produz). Só roda com 3 canais.

Parâmetros efetivos, e são os defaults de hoje:

```python
starSigma      = 12.0
starMax        = 0.85
minStarPixels  = 2000
extendedWindow = 25
extendedFrac   = 0.50
reference      = 'green'          # índice 1
```

### 2a — neutralização, nesta ordem exata

```python
beforeMedians = [ np.median(p.astype(f8)) for p in planes ]      # EXATA
target        = (beforeMedians[0] + beforeMedians[1] + beforeMedians[2]) / 3.0
offsets       = [ m - target for m in beforeMedians ]
for c in range(3):
    if offsets[c] != 0.0:
        planes[c] = (planes[c].astype(f8) - offsets[c]).astype(np.float32)
```

⚠ **Aditivo, e antes dos ganhos.** Invertido, o ganho escala o offset junto.

⚠ **Sem clampear.** Negativos sobrevivem até o quantise.

⚠ A mediana aqui é **exata**, não por histograma. Motivo medido: o `measure()`
do JS tem resolução 1/65535 = 1,526e-5, e os offsets do M 31 são 1,00 / 0,70 /
0,31 bin — a correção é menor que o instrumento em dois canais de três.

### 2b — pedestal

```python
pedestals = [target, target, target]     # porque a neutralização rodou
```

Se `backgroundNeutralise` estiver desligado, `pedestals[c]` é a mediana exata do
canal `c` sobre o quadro inteiro. Nos goldens ela sempre roda, então os três são
o `target`.

### 2c — luminância da seleção

⚠ **Aqui a luminância é a média simples, `(R+G+B)/3`, e não os pesos Rec. 709.**
Os pesos aparecem só no esticamento (§3). São duas luminâncias diferentes no
mesmo pipeline, de propósito: esta é um critério de brilho, aquela é fotométrica.

```python
L = ((R.astype(f8) + G.astype(f8) + B.astype(f8)) / 3.0).astype(np.float32)

lumMedian = np.median(L[np.isfinite(L)].astype(f8))

# ⚠ os desvios são arredondados para float32 ANTES da mediana.
dev       = np.abs(L.astype(f8) - lumMedian).astype(np.float32)
lumMadn   = 1.4826 * np.median(dev[np.isfinite(dev)].astype(f8))
```

O arredondamento do `dev` não é enfeite: o JS acumula num `Float32Array`
reaproveitado, e a mediana sai desses float32.

### 2d — seleção, com os dois cortes

```python
thresholdLow  = lumMedian + starSigma * lumMadn
thresholdHigh = starMax

finite = np.isfinite(L)
mask   = finite & (L > thresholdLow) & (L < thresholdHigh)    # AMBOS estritos
selectedRaw = int(mask.sum())

# contado sobre a seleção ANTES da rejeição de extenso
rejectedSaturated = int((finite & (L > thresholdLow) & ~(L < thresholdHigh)).sum())
```

### 2e — rejeição de fonte extensa

⚠ Roda sobre a máscara **depois** do corte superior, nunca antes.

```python
r = extendedWindow // 2                      # 25 // 2 = 12
# soma de caixa exata sobre a máscara binária, via imagem integral em int64
I = np.zeros((h+1, w+1), dtype=np.int64)
I[1:,1:] = np.cumsum(np.cumsum(mask.astype(np.int64), axis=0), axis=1)

y  = np.arange(h)[:, None]; x = np.arange(w)[None, :]
yl = np.maximum(y - r, 0);  yh = np.minimum(y + r, h - 1)
xl = np.maximum(x - r, 0);  xh = np.minimum(x + r, w - 1)
box = I[yh+1, xh+1] - I[yl, xh+1] - I[yh+1, xl] + I[yl, xl]
n   = (yh - yl + 1) * (xh - xl + 1)          # ⚠ janela CLIPADA na borda

reject = mask & (box > extendedFrac * n)     # ⚠ estritamente maior
rejectedExtended = int(reject.sum())
mask = mask & ~reject
count = selectedRaw - rejectedExtended
```

⚠ O denominador é o número de pixels **realmente olhados**, não a janela
nominal 25×25. Dividir pela nominal faria todo pixel de borda parecer esparso e
deixaria passar um objeto encostado na borda — que é onde uma galáxia mal
enquadrada fica.

### 2f — medianas estelares e ganhos

```python
starMedians = [ np.median(p[mask & np.isfinite(p)].astype(f8)) for p in planes ]
above       = [ starMedians[c] - pedestals[c] for c in range(3) ]
ratios      = { 'rOverG': above[0]/above[1], 'bOverG': above[2]/above[1] }
gains       = [ above[1] / above[c] for c in range(3) ]        # referência = verde
for c in range(3):
    if gains[c] != 1.0:
        planes[c] = (planes[c].astype(f8) * gains[c]).astype(np.float32)
```

⚠ **A razão é acima do pedestal.** O pedestal é comum aos três canais depois da
neutralização, então deixá-lo dentro arrasta toda razão para 1.

⚠ A máscara de cada canal é `mask & isfinite(canal)`, então os três podem ter
contagens diferentes se houver NaN. Nos fixtures não há.

### 2g — salvaguardas, **nesta ordem**

A ordem importa porque a primeira que dispara é a que escreve o motivo.

| # | condição | resultado |
|---|---|---|
| 1 | `count < minStarPixels` | ganhos não rodam |
| 2 | `min(starMedians) < 3.0 * max(pedestals)` | ganhos não rodam |
| 3 | `above[1] <= 0` | ganhos não rodam |
| 4 | algum `gain` fora de `[0.25, 4.0]` | ganhos não rodam |

⚠ A regra 2 compara a **mediana estelar crua** contra o pedestal, não a acima
dele. E usa o **mínimo** das três contra o **máximo** dos pedestais.

Quando os ganhos não rodam, a neutralização **já rodou e fica** — o quadro sai
neutralizado e sem ganhos, e `applied` do registro é `True` mesmo assim.

---

## 3. Esticamento ligado — `stretch_linked(planes, params)`

```python
linked   = True
operator = 'mtf'          # 'asinh' no golden asinh-fixture
target        = 0.085     # ⚠ mudou de 0.25
shadowSigma   = -2.80
blackPct      = 0.0005
```

### 3a — luminância, agora Rec. 709

```python
Y = (0.2126*R.astype(f8) + 0.7152*G.astype(f8) + 0.0722*B.astype(f8)).astype(np.float32)
```

### 3b — parâmetros, um conjunto só, da luminância

⚠ **Aqui o JS usa o histograma de 65536 bins (`analysePlane`), não a mediana
exata.** Reporte as estatísticas exatas da luminância como o `reference.py` já
faz para os canais; a tolerância da §7 do Módulo 0 absorve a diferença, que é a
mesma situação que já valia no caminho por canal.

```python
median, madn = stats_exact(Y)          # como reference.py já calcula
if nonLinear:
    shadows = percentile(Y, blackPct)
    tgt     = min(0.6, max(0.02, median))
else:
    shadows = median + shadowSigma * madn
    tgt     = target

if not (shadows >= 0):      shadows = 0.0
if shadows >= median:       shadows = max(0.0, median * 0.5)
if shadows >= 1:            shadows = 0.0

scale   = 1.0 / (1.0 - shadows)
xMedian = (median - shadows) * scale
midtones = MTF(xMedian, tgt) if (madn > 0 and 0 < xMedian < 1) else 0.5
if not (0 < midtones < 1):  midtones = 0.5

hiCut = percentile(Y, 0.99)
```

```python
def MTF(x, m):
    if x <= 0: return 0.0
    if x >= 1: return 1.0
    if m == 0.5: return x
    return ((m - 1.0)*x) / (((2.0*m - 1.0)*x) - m)
```

### 3c — a transferência, por pixel

```python
y = Y[i];  y = 0.0 if isnan(y) else float(y)      # ⚠ o ÚNICO NaN→0 do pipeline
R, G, B = float(planes[0][i]), float(planes[1][i]), float(planes[2][i])
isHi = (y >= hiCut)

u = (y - shadows) * scale
if   u <= 0: yo = 0.0; low  += 1
elif u >= 1: yo = 1.0; high += 1
else:        yo = MTF(u, midtones)

r  = (yo / y) if y > 1e-8 else 1.0
Ro, Go, Bo = R*r, G*r, B*r                        # float64

mx = max(Ro, Go, Bo)
if mx > 1.0:
    Ro /= mx; Go /= mx; Bo /= mx; rescaled += 1   # ⚠ os TRÊS, nunca clampear um

planes[0][i] = np.float32(Ro); planes[1][i] = np.float32(Go); planes[2][i] = np.float32(Bo)
```

⚠ **`Ro`, `Go`, `Bo` continuam float64 quando entram em `colourFidelity`
abaixo.** O arredondamento para float32 acontece só na escrita. É por isso que a
deriva medida é 4,4e-16 (dois épsilons de double) e não épsilon de float32 — se
a referência medir a deriva sobre os valores já armazenados, vai dar ~1e-7 e
parecer que a implementação está errada quando não está.

### 3d — `colourFidelity`, medido na mesma passada

```python
# razões nas altas luzes: razão de SOMAS (fluxo), não mediana de razões
if isHi:
    sumRb += R;  sumGb += G;  sumBb += B
    sumRa += Ro; sumGa += Go; sumBa += Bo
    hiCount += 1

# deriva por pixel, o PIOR do quadro, não o típico
if G > 1e-3 and Go > 1e-3:
    maxDrift = max(maxDrift, abs(Ro/Go - R/G), abs(Bo/Go - B/G))
    driftSamples += 1

ratiosBefore = { 'rOverG': sumRb/sumGb, 'bOverG': sumBb/sumGb }
ratiosAfter  = { 'rOverG': sumRa/sumGa, 'bOverG': sumBa/sumGa }
```

### 3e — asinh, só para o golden `asinh-fixture`

```python
def ASINH(x, s):
    if x <= 0: return 0.0
    if x >= 1: return 1.0
    return math.asinh(s*x) / math.asinh(s)

def solve_asinh(x, target):
    if not (0 < x < 1) or not (0 < target < 1): return None
    if target <= x:                             return None
    lo, hi = 1e-6, 1e7
    if ASINH(x, hi) < target:                   return None
    for _ in range(40):                         # ⚠ 40, e média GEOMÉTRICA
        mid = math.sqrt(lo*hi)
        if ASINH(x, mid) < target: lo = mid
        else:                      hi = mid
    return math.sqrt(lo*hi)
```

`solvedStretch = solve_asinh(xMedian, tgt)`, e a transferência vira
`ASINH(u, solvedStretch)`. Se der `None`, a transferência é a identidade e o
registro marca `stretchUnreachable`.

---

## 4. O JSON que eu preciso de volta

Mesma forma de hoje, com dois blocos novos por fixture:

```jsonc
"fixtures": {
  "colour": {
    "decode": { ... como hoje ... },
    "fundo":  { ... como hoje ... },
    "calibracaoCor": {
      "aplicado": true,
      "neutralizacao": { "medianasAntes": [r,g,b], "alvo": t, "offsets": [dr,dg,db] },
      "pedestais": [p,p,p],
      "luminanciaSelecao": { "mediana": m, "madn": mn },
      "limiares": { "baixo": lo, "alto": 0.85 },
      "selecionados": 276145,
      "rejeitados": { "saturado": 302053, "extenso": 1646 },
      "pixels": 274499,
      "medianasEstelares": [r,g,b],
      "acimaDoPedestal": [r,g,b],
      "razoes": { "rOverG": x, "bOverG": y },
      "ganhos": [gr, gg, gb],
      "motivoRecusa": null
    },
    "esticamento": {
      "ligado": true,
      "operador": "mtf",
      "luminancia": { "mediana": m, "madn": mn },
      "shadows": s, "midtones": mid, "target": 0.085,
      "solvedStretch": null,
      "clipLow": 0, "clipHigh": 0,
      "highlightCut": hc,
      "colourFidelity": {
        "ratiosBefore": {...}, "ratiosAfter": {...},
        "maxRatioDrift": d, "driftSamples": n,
        "highlightPixels": n, "pixelsRescaled": n
      }
    },
    "canais": { "R": { "saida": { "median": ..., "mean": ..., "clipLow": ..., "clipHigh": ... } }, ... }
  }
}
```

E no topo, como hoje: `geradoPor`, `proposito`, `cadeia`, e o bloco `cobertura`
com `porCanalAindaNA` e `motivo` — a referência continua declarando ela mesma o
que não cobre, em vez de eu manter a lista do lado de cá.

**Fixtures a cobrir:** `seestar`, `rice`, `nonlinear`, `gradient`, `colour`.
O `asinh` é o mesmo quadro do `gradient` com `operator='asinh'` — se der para
emitir os dois, ótimo; se não, o `gradient` já fecha as 7 N/A.

---

## 5. Números para conferir antes de me mandar

Se estes baterem, o resto bate. Se algum não bater, o erro está no passo que ele
mede e não adianta olhar os outros.

### `colour-fixture` — a calibração roda inteira

```
neutralização  alvo      0.015217204578220844
               offsets   +0.0006394730880856514
                         +0.001999109983444214
                         -0.0026385830715298653
seleção        lumMed    0.014729655347764492
               lumMadn   0.0031653492129407822
               thrLow    0.05271384590305388
               selecionados     276145
               rej. saturado    302053
               rej. extenso       1646
               pixels           274499
estrelas       medianas  0.22911791503429413
                         0.18618783354759216
                         0.15188860893249512
               acima     0.21390071045607328
                         0.17097062896937132
                         0.13667140435427427
ganhos                   0.7992990233872174
                         1.0
                         1.2509612363840787
esticamento    lumMed    0.014572365911345083     (histograma; tolerância §7)
               lumMadn   0.0036483292696452008
               shadows   0.004357043956338522
               midtones  0.10038860889501716
               hiCut     0.9767452506294346
               clip      0 / 0
fidelidade     maxDrift  8.88178419700125e-16
               rescaled  302040
               hiPixels  19489
```

### `gradient-fixture` — a calibração RECUSA, e é isso que tem que ser reproduzido

```
neutralização  alvo      0.01682377342755596      (roda, e fica)
               offsets   +0.0016671426904698201
                         -0.0000665012436608485
                         -0.001600641446808975
seleção        lumMed    0.016749536618590355
               lumMadn   0.0008336659418419003
               thrLow    0.02675352792069316
               selecionados      61143
               rej. extenso      46129            (75% da seleção: o objeto extenso)
               pixels            15014
estrelas       medianas  0.04470996558666229
                         0.045081574469804764
                         0.045550307258963585
ganhos                   NÃO RODAM
               motivo    salvaguarda 2: min(medianas) = 0.04471 < 3 x 0.016824 = 0.050471
esticamento    lumMed    0.016769665064469367
               lumMadn   0.0010589015610251832
               shadows   0.013804740693598855
               midtones  0.03144031631393108
               hiCut     0.040283817807278556
               clip      1677 / 0
fidelidade     maxDrift  4.44089209850063e-16
               rescaled  405
               hiPixels  19220
```

⚠ O `gradient` é o caso mais valioso dos dois, porque exercita a recusa. Se a
referência produzir ganhos ali, uma das duas implementações está com a
salvaguarda errada — e essa é a discordância que eu quero que apareça.

O `nonlinear` também recusa, pela mesma salvaguarda 2.

---

## 6. Tolerâncias

Valem as da §7 do Módulo 0 como estão, mais as da §5 do Módulo 2/3:

| grandeza | tolerância | por quê |
|---|---|---|
| ganhos | `max(1e-4·|ref|, 4/65535)` | §5 |
| razões estelares na saída | 1e-6 absoluto | §3.2 |
| `maxRatioDrift` | **≤ 1e-6, e é asserção, não comparação** | acima disso a implementação está errada |
| contagem de pixels estelares | **exata** | inteiro contado |
| `rejeitados.saturado` / `.extenso` | **exata** | inteiro contado |
| `pixelsRescaled` | **exata** | inteiro contado |
| `clipLow` / `clipHigh` | **exata** | inteiro contado |
| medianas exatas (§2) | `max(1e-4·|ref|, 4/65535)` | unidade |
| estatísticas da luminância (§3b) | `max(1e-4·|ref|, 8·span/65535 + 1.4826·|Δmediana|)` | histograma vs exata |

⚠ As contagens inteiras são **exatas** porque são coisas contadas, não grandezas
medidas — a regra já gravada. Se uma delas divergir por um, é diferença de
critério, e eu quero saber qual.
