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
