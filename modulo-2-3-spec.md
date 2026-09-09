# Justyear Stretch — Módulos 2 e 3

**Módulo 2:** calibração de cor a partir do fluxo estelar.
**Módulo 3:** esticamento ligado, com alvo de imagem final.

As duas specs vêm juntas porque **nenhuma das duas produz efeito visível sozinha**.
Calibrar cor e depois esticar cada canal com parâmetros próprios desfaz a
calibração. Esticar ligado sem calibrar antes trava a dominante que existe. Só o
par muda a imagem.

---

## 0. O que foi medido, e onde

Todos os números abaixo saíram de um empilhamento real de M 31 — S30 Pro,
3.637 quadros de 60 s, 60,6 h de integração — processado em Python fora deste
repositório. **O arquivo é de terceiro e não entra na árvore**; os números
entram como caso de calibração da spec, não como fixture.

Fundo, mediana por canal: R 0,001163 · G 0,001189 · B 0,001183.
Razões de fundo: R/G 0,978 · B/G 0,995 — o fundo já está quase neutro.

### Os ganhos corretos

**R 1,059 · G 1,000 · B 1,360**, normalizando o verde.

### A versão anterior desta seção estava errada, e como

A primeira medição desta spec dizia **R 0,9491 · G 1,0000 · B 1,4002**, a partir
de razões estelares R/G 1,054 · B/G 0,714 sobre 98.599 pixels. Dois defeitos de
método, os dois descobertos ao implementar o Módulo 2, e um deles inverte o
sinal da correção do vermelho:

| | R/G | B/G | ganho R | ganho B |
|---|---|---|---|---|
| como estava | 1,054 | 0,714 | 0,949 | 1,400 |
| subtraindo o pedestal | 1,062 | 0,668 | 0,942 | 1,496 |
| ...e rejeitando o extenso | **0,945** | **0,735** | **1,059** | **1,360** |

**1. A razão era tomada sobre o valor do pixel, não sobre o fluxo acima do céu.**
A cor de uma estrela é o fluxo acima do fundo. O pixel carrega o céu junto, e
depois da neutralização esse céu é **o mesmo número nos três canais** — logo é um
termo aditivo comum ao numerador e ao denominador de toda razão, e arrasta todas
para 1 na proporção do quanto ele pesa contra a estrela. No M 31: B/G de 0,714
para 0,668, ganho azul de 1,400 para 1,496. Sete por cento, no canal que o
próprio dado aponta como o deficiente.

**2. A seleção era dominada pelo objeto extenso.** 39% dos pixels selecionados
eram o núcleo de M 31, que tem cor própria e não é a cor da população estelar.
Rejeitando-o, R/G vai de 1,066 para 0,945 — **o ganho vermelho troca de sinal**:
sem rejeição a calibração *reduz* vermelho, com rejeição ela *aumenta*. Não é
refinamento; sem isso a calibração aponta para o lado errado.

O resultado é estável entre limiares de rejeição de 0,25 e 0,60, o que indica
população real sendo separada e não artefato de onde o corte caiu.

**O azul continua deficiente, e o fundo continua não mostrando isso.** É por
isso que a calibração mede estrela e não fundo: o fundo é céu, e céu não tem cor
de referência. Estrela tem. O que mudou é *como* a estrela é medida.
---

## 1. Ordem na cadeia, e por que ela é essa

```
decode → debayer → extração de fundo → [2a neutralização] → [2b ganhos] → [3 esticamento] → quantise
```

**A extração de fundo vem antes** porque um gradiente forte enviesa a mediana de
fundo por canal, e a neutralização mediria a inclinação em vez da dominante.
Isso já está implementado e preserva a razão entre canais de propósito — o
pedestal por canal existe exatamente para não decidir cor antes desta etapa.

**A neutralização (2a) vem antes dos ganhos (2b)** porque o ganho é multiplicativo
e o offset de fundo é aditivo. Multiplicar antes de zerar o offset escala o
offset junto.

**O esticamento vem por último** e tem que ser ligado, senão desfaz tudo.

---

## 2. Módulo 2 — calibração de cor

Só roda com 3 canais. Em mono, `applied: false` com `skipReason`.

### 2.1 — Neutralização de fundo

```
params: { backgroundNeutralise: true }
```

Mede a mediana de cada canal (via `measure()`, que já existe), calcula a média
das três, e desloca cada canal para essa média:

```
alvo   = média(mediana_R, mediana_G, mediana_B)
canal_c = canal_c − (mediana_c − alvo)
```

Aditivo, não multiplicativo. Preserva a diferença de brilho entre canais nos
objetos e neutraliza só o piso.

Sem clampear. Negativos sobrevivem até o `quantise`, como já é a regra.

### 2.2 — Ganhos a partir do fluxo estelar

```
params: {
  starSigma: 12.0,        // corte inferior: mediana + starSigma x MADN da luminancia
  starMax: 0.85,          // corte superior: ignora estrela saturada
  extendedWindow: 25,     // janela da rejeicao de fonte extensa
  extendedFrac: 0.50,     // acima desta fracao de vizinhos acesos, rejeita
  minStarPixels: 2000,    // abaixo disso a etapa nao roda
  reference: 'green',     // canal normalizado para ganho 1
}
```

**Seleção.** Luminância `L = (R+G+B)/3`. Um pixel é candidato se
`L > mediana(L) + starSigma × MADN(L)` **e** `L < starMax`. Depois passa pela
rejeição de fonte extensa.

**Medianas exatas, não por histograma.** O `measure()` divide [0,1] em 65536
bins, e 1/65535 = 1,526e-5. Os offsets de neutralização do M 31 são 1,00 · 0,70
· 0,31 bin: **a correção é menor que o instrumento em dois canais de três**. As
medianas desta etapa saem de `quickselect` sobre os valores, na convenção do
`np.median`, para que a referência Python e esta implementação computem a mesma
definição em vez de duas aproximações dela.

#### O corte superior, e por que ele não é detalhe

Estrela saturada tem os três canais presos em 1,0. As razões dela são exatamente
1 e ela não carrega cor nenhuma — é um buraco no dado com formato de medição.

**O mecanismo é um degrau, não uma degradação suave, e a versão anterior desta
seção descrevia errado.** Dizia "uma população saturada puxa todas as razões
para 1", o que vale para uma **média**. Com **mediana** o comportamento é outro,
e foi medido em três construções do fixture:

| saturados na seleção | R/G com corte | R/G sem corte |
|---|---|---|
| 2,4 % | 1,127 | 1,129 |
| 37 % | 1,220 | **1,240** |
| 50,4 % | 1,230 | **1,117** |

Abaixo de ~50% a população saturada **empurra a razão para LONGE de 1**, porque
a mediana sobe para dentro do anel parcialmente saturado — onde o vermelho já
está preso em 1,0 e o verde não, e ali a razão é *maior* que a estelar. Só
quando a população saturada passa de metade a mediana cai sobre ela e as razões
colapsam para 1.

Ou seja: **a mediana é mais robusta do que esta spec creditava**, e o modo de
falha real é um degrau. O corte continua necessário — no fixture, com o corte
superior e a rejeição de extenso ambos desligados, o ganho vermelho vai de
0,799 para **0,997**, identidade — mas o argumento é outro.

#### Rejeição de fonte extensa

Uma seleção por brilho seleciona pixels brilhantes. Num campo estelar isso é
majoritariamente estrela, mas o núcleo de uma galáxia é brilhante numa área
grande e conectada, entra inteiro, e traz a cor **dele**.

Medido: no fixture sintético o objeto forneceu 29,8% dos pixels selecionados e a
etapa devolveu a razão do OBJETO (1,127/0,798 contra um tint de 1,10/0,80) em
vez da das estrelas. No M 31 real o núcleo é 39% da seleção.

O discriminante é ocupação de vizinhança, não forma: estrela é pequena e tem
vizinhança vazia, fonte extensa está dentro do próprio corpo. Para cada pixel
selecionado, a fração de vizinhos **também selecionados** numa janela de
`extendedWindow`; acima de `extendedFrac`, rejeita. Somas de caixa separáveis,
O(N), duas passadas.

A contagem entra no record como estado próprio — `rejected.extended` — do mesmo
jeito que a amostragem do Módulo 1 reporta `rejected-bright` e `rejected-edge`.
**Rejeição que ninguém consegue contar é rejeição que ninguém consegue
auditar.**

#### Ganhos, acima do céu

```
pedestal_c = mediana do canal c sobre o quadro   (= alvo da neutralizacao, quando ela rodou)
acima_c    = mediana_estelar_c - pedestal_c
ganho_c    = acima_referencia / acima_c
canal_c    = canal_c x ganho_c
```

**A subtração do pedestal não é conveniência, é fotometria.** A cor de uma
estrela é o fluxo acima do céu. Depois da neutralização o céu é um nível comum
aos três canais, então deixá-lo dentro arrasta toda razão para 1. No M 31: B/G
de 0,714 para 0,668, ganho azul de 1,400 para 1,496.

Verificado contra verdade conhecida: no `fixture-colour.fit`, cujas razões
estelares são injetadas em 1,2500 / 0,8000, a etapa mede **1,2511 / 0,7994** —
0,09% e 0,08%. Sem a subtração do pedestal media 1,2297 / 0,8156, errado por
1,6% e 1,9%, sempre na direção da identidade.

**Não é detecção de estrela.** É seleção de pixels brilhantes, não saturados,
cuja vizinhança não está acesa. Em campo estelar isso é predominantemente
estrela. **Registre como limitação conhecida**, não como detecção — e a
limitação tem dois lados: um objeto extenso pouco brilhante ainda contribui, e
um campo estelar muito denso pode ser rejeitado como extenso por engano.

**Salvaguardas.** Nesta ordem, e cada uma escreve no log qual foi e por quê:

1. Menos de `minStarPixels` selecionados **depois** da rejeição: a etapa não
   roda. A mensagem distingue "não havia estrelas" de "foram rejeitadas como
   extensas", porque a segunda é um erro do filtro e não uma propriedade do céu.
2. A menor mediana estelar abaixo de **3× o pedestal**: a etapa não roda. A
   razão `(mediana − pedestal) / (referência − pedestal)` fica instável quando o
   numerador é uma diferença pequena de dois números grandes.
3. Qualquer ganho fora de [0,25 ; 4,0]: a etapa não roda. Ganho fora dessa faixa
   significa que a seleção pegou outra coisa, e aplicar um ganho de 8× cria uma
   cor que não existe no dado.
### 2.3 — O record

```js
{
  id: 'colour-cal',
  name: 'Colour calibration',
  applied: true,
  params: { ...efetivos... },
  neutralise: {
    beforeMedians: [r, g, b],
    target: t,
    offsets: [dr, dg, db],
  },
  stars: {
    pixels: 98599,
    pctFrame: 1.189,
    thresholdLow: 0.004612,
    thresholdHigh: 0.85,
    medians: [r, g, b],
    ratios: { rOverG: 1.0537, bOverG: 0.7142 },
  },
  gains: [0.9491, 1.0, 1.4002],
  reference: 'green',
  before: { perChannel: [...] },
  after:  { perChannel: [...] },
  notes: [...]
}
```

### 2.4 — O que o log diz, e por que importa

Esta é a etapa em que a ferramenta **passa a decidir cor**, e o log tem que ser
explícito sobre a diferença entre medir e escolher:

> Colour calibration: the sky background was levelled between channels, and the
> colour balance was measured from 98,599 star pixels in your own frame — red
> ×0.949, green ×1.000, blue ×1.400. Nothing here was a preference: the numbers
> came from the stars you photographed. Star colour is the reference because sky
> has no colour of its own to measure against.

**Sem catálogo, sem plate solve, sem rede.** O Siril precisa do Gaia DR3 e de
resolver astrometria para fazer isso. Esta implementação mede o próprio quadro.
É vantagem técnica e frase de marketing, e ela vai no log porque é verdade
verificável.

### 2.5 — A dívida do registry, que vence agora

O `registry.js` mapeia `colour-cal` ao rótulo `"colour grading"`, e isso já está
anotado como incorreto: **calibração é medição, grading é gosto.** Com a etapa
existindo, aplicar `colour-cal` retiraria a promessa sobre grading — que
continuaria verdadeira.

Separe em duas entradas:

```js
{ id: 'colour-cal',    label: 'colour calibration', announce: false },
{ id: 'colour-grade',  label: 'colour grading',     neverImplemented: true },
```

`colour-cal` com `announce: false` porque o log dedica um bloco inteiro a ela,
como já acontece com o stretch. `colour-grade` como nunca-implementada, para a
frase continuar negando o que a ferramenta de fato não faz.

**A linha "Not applied" muda de texto.** Isso é mudança deliberada e tem que ser
verificada com o mesmo round-trip do passo 7 do Módulo 1: com `applied: true` o
log descreve e não nega; com `applied: false` nega e não descreve.

---

## 3. Módulo 3 — esticamento ligado

### 3.1 — O defeito que ele corrige

Hoje `stepStretchMTF` calcula `shadows` e `midtones` **por canal**, cada um da
sua própria mediana e MADN. Cada canal passa por uma curva diferente, e a razão
entre canais na saída não é a razão na entrada.

Medido no M 31: razões estelares lineares `R/G 1,054 · B/G 0,714`. Depois do
esticamento por canal, nas altas luzes: `R/G 1,008 · B/G 0,950`. **A curva
comeu a cor.** O esticamento por canal é, na prática, um balanço de branco
não declarado — exatamente o que o log promete não fazer.

### 3.2 — Ligado: um parâmetro, três canais

```
params: {
  linked: true,               // false = comportamento antigo, por canal
  operator: 'mtf',            // 'mtf' | 'asinh'
  target: 0.085,              // ver 3.4
  shadowSigma: -2.80,
  stretch: 120,               // só para asinh
  applyVia: 'luminance',      // 'luminance' | 'perChannel'
}
```

**`applyVia: 'luminance'` é o que preserva cor exatamente.** Calcule a
luminância, aplique a transferência nela, e multiplique cada canal pela razão:

```
Y   = 0.2126·R + 0.7152·G + 0.0722·B
Y'  = f(Y)
r   = Y > ε ? Y'/Y : 1
R' = R·r ,  G' = G·r ,  B' = B·r
```

A razão entre canais fica **idêntica**, por construção. Verificável: meça
`R/G` e `B/G` antes e depois nas altas luzes e exija diferença abaixo de 1e-6.

**Estouro.** `R·r` pode passar de 1 num pixel onde um canal é muito mais forte
que a luminância. Não clampeie por canal — isso muda a cor. Se `max(R',G',B') > 1`,
divida os três pelo máximo. Preserva a razão e o pixel vira branco em vez de
virar de cor. Registre a contagem no record.

`applyVia: 'perChannel'` aplica a mesma `f` aos três independentemente. Mais
simples, comprime a cor nas altas luzes. Fica disponível, não é o padrão.

### 3.3 — Parâmetros a partir da luminância

`shadows` e `midtones` (ou `stretch`, no asinh) saem da mediana e MADN **da
luminância**, não de canal nenhum. Um conjunto só.

### 3.4 — O alvo, que estava errado

`target: 0.25` vem do autostretch do Siril e do STF do PixInsight, e é um
esticamento **de inspeção**: serve para olhar dado linear na tela. `0,25 × 255 =
64`, e fundo em 64 é cinza claro.

A métrica de entrega registrada neste projeto é fundo entre 13 e 25 de 255.
Isso são alvos entre **0,051 e 0,098**.

Medido no M 31 com `target = 0.085`: fundo na saída **21 de 255**, estourado
0,13 %.

**Novo padrão: `target = 0.085`.** O `0.25` continua disponível como valor, e o
log diz qual foi usado e o que ele significa em níveis de 255.

Isto muda todos os goldens. É mudança deliberada, e a §0 do Módulo 1 já
encerrou a identidade byte a byte — o comparador tem tolerância.

### 3.5 — asinh

```
f(x) = asinh(stretch · x) / asinh(stretch)
```

Levanta o sinal fraco muito mais que o MTF sem levantar o fundo na mesma
proporção. É o operador que abre o braço de galáxia.

Aplique **depois** de subtrair o ponto preto (`x = max(0, x − c0)`), senão o
fundo é levantado junto.

`stretch` é um número grande — 50 a 500. Um valor derivado do dado, em vez de
fixo: escolha `stretch` tal que `f(mediana)` caia em `target`. Isso é uma
resolução numérica de uma equação monotônica em uma variável — busca binária em
30 iterações, custo desprezível, e faz o asinh se comportar como o MTF em
relação ao alvo.

`operator: 'mtf'` continua o padrão nesta entrega. O asinh entra implementado e
verificado, e a decisão de trocar o padrão fica para depois de haver imagem
real para comparar.

### 3.6 — O record

```js
{
  id: 'stretch-mtf' | 'stretch-asinh',
  applied: true,
  params: { linked, operator, target, applyVia, shadowSigma, stretch },
  linked: {
    luminanceMedian, luminanceMADN, shadows, midtones,
    solvedStretch,           // quando asinh
  },
  colourFidelity: {          // a verificação da §3.2, medida em execução
    ratiosBefore: { rOverG, bOverG },
    ratiosAfter:  { rOverG, bOverG },
    maxRatioDrift,
    pixelsRescaled,          // quantos passaram de 1 e foram divididos pelo máximo
  },
  before: { perChannel: [...] },
  after:  { perChannel: [...] },
}
```

`colourFidelity` é a razão de existir do módulo, medida em cada execução e
gravada no golden. Se a deriva subir, o harness pega.

---

## 4. Fixture novo

Nenhum fixture tem cor conhecida, então nada disso é testável hoje.

`fixture-colour.fit` — 1600×1200×3, float32, determinístico:

- **fundo com dominante conhecida**, escrita em `HISTORY`: por exemplo
  `R 0,0150 · G 0,0165 · B 0,0120` — nem neutra nem igual às razões estelares,
  para que a neutralização e os ganhos sejam testáveis separadamente
- **população estelar com razões conhecidas**, também em `HISTORY`, e diferentes
  das do fundo: é isso que prova que a calibração mede estrela e não fundo
- **estrelas saturadas de propósito** (acima de `starMax`), em quantidade
  conhecida, para verificar que o corte superior as descarta — se entrarem, os
  ganhos derivam para 1 e o teste tem que pegar
- **objeto extenso colorido**, com razão própria, para medir o quanto ele
  contamina os ganhos
- **gradiente leve**, para a etapa de fundo ter o que fazer antes

O teste que importa: aplicar a cadeia e verificar que as razões estelares na
saída batem com as razões que foram escritas no arquivo. É a mesma forma do
`fixture-gradient` — a verdade vem dos cards, não de nenhuma implementação.

---

## 5. Referência Python

`reference_bg.py` ganha as duas etapas em float64, e o `chain.py` passa a cadeia
completa. As tolerâncias da §7 do Módulo 0 valem como estão, mais uma nova:

| grandeza | tolerância |
|---|---|
| ganhos | `max(1e-4·\|ref\|, 4/65535)` |
| razões estelares na saída | 1e-6 absoluto quando `applyVia: 'luminance'` |
| contagem de pixels estelares | exata — é inteiro contado |

A última segue a regra já gravada: grandeza medida admite piso de instrumento,
inteiro contado não.

---


### Contagem por limiar: a tolerância é derivada, não escolhida

A regra "inteiro contado é exato" vale para contagem sobre **os mesmos pixels**.
Estas não são: cada lado resolve o próprio RBF, mede as próprias estatísticas, e
compara uma grandeza contra um limiar. Um pixel troca de lado quando `q − T`
troca de sinal, e as duas pontas mexem nos dois termos:

```
tolerância = #{ i : |q_i − T| ≤ Δ_q + Δ_T }
```

que é a curva `densidadePorLimiar` que a referência emite. **Sem constante
ajustada**: o Δ entra medido e a cota sai da curva.

**Δ é por contagem, nunca um só.** Medido:

| contagem | grandeza | limiar | Δ dominante |
|---|---|---|---|
| seleção estelar | L = (R+G+B)/3 | mediana + 12·MADN | ~1e-6 — as duas usam mediana exata |
| `rejeitado.saturado` | L | mesmo, mais 0,85 fixo | ~1e-6 |
| `rejeitado.extenso` | máscara | fração de vizinhança | herda o da seleção |
| `clipLow` | Y Rec.709 | `c0` | ~6e-6 — nosso `c0` vem do histograma de 65536 bins, o deles da mediana exata |
| `pixelsRescaled` | `max(R,G,B)·r` | 1,0 | **multiplicativo** através de `r`, três ordens acima do por-pixel |

Um Δ único para as cinco reprova uma e afrouxa as outras.

**A regra se aperta sozinha.** Onde o limiar cai numa região vazia a densidade é
zero, a tolerância é zero, e a contagem **tem que ser exata — por cálculo, não
por afirmação**. `clipHigh` e `pixelsRescaled` são esse caso em alguns fixtures
e não em outros, e uma exceção por nome erraria nos dois sentidos: uma primeira
versão desta regra isentava `clipLow` por nome, e ele tem densidade 27 no
`gradient` — tão densa quanto a seleção estelar. Bateu exato por sorte.

**Cota medida, não provada.** O pior caso analítico é ~36,6·Δ_q, porque a MADN
entra no limiar multiplicada por 12. Medido em três formatos de perturbação
(aleatória, sistemática, rampa) a MADN se move ~Δ_q/100, e um deslocamento
constante não a move nada — então Δ_T ≤ Δ_q, com igualdade no caso constante.
Escrever 36,6 seria uma tolerância que desliga o instrumento. **Se o Δ_T
reportado passar de Δ_q, isso é achado, não ruído.**

### Derivado não se compara pelo valor final

`shadows` e `midtones` não são medidos, são funções de duas medições, e comparar
o valor final mistura duas perguntas: *a fórmula é a mesma?* e *as entradas são
as mesmas?*

A segunda já é respondida pelas linhas `lum.mediana` e `lum.madn`. Para isolar a
primeira, a fórmula desta ponta é alimentada com **as entradas da outra** e o
resultado comparado com o valor dela.

Isso importa porque a propagação **amplifica**: no `fixture-colour`, 1,9e-6 de
diferença na mediana vira 2,4e-4 em `midtones` — **131×** — porque a MTF é
íngreme onde `midtones` vale 0,10. Alargar a tolerância até caber esconderia uma
divergência de fórmula junto; isolar não esconde. Foi assim que o `target` do
ramo não-linear apareceu: `midtones(formula)` passou e `target` reprovou, o que
localiza o defeito na entrada e não no método.

## 6. Ordem de execução

1. `steps/colour-cal.js` — neutralização e ganhos, com as salvaguardas. Sem
   mexer no stretch ainda: verificar que os ganhos saem certos e que o
   `registry` se comporta.
2. `registry.js` — separar `colour-cal` de `colour-grade`, com o round-trip
   verificado nas duas direções.
3. `fixture-colour.fit` no gerador, golden capturado.
4. `stepStretch` ganha `linked` e `applyVia`, com `colourFidelity` medido.
   Padrão ainda `target: 0.25`, para isolar a mudança.
5. `target: 0.085` vira o padrão. **Recaptura completa dos goldens**, em commit
   próprio, com o motivo.
6. asinh implementado, com a resolução numérica de `stretch` contra o alvo. Não
   vira padrão.
7. `reference_bg.py` e `chain.py` estendidos; `compare-reference` cobre os
   campos novos.
8. Log: bloco da calibração de cor, e o alvo declarado em níveis de 255.

Os passos 1 a 3 são o Módulo 2 e entregam sozinhos: a imagem deixa de ter
dominante. Os passos 4 a 6 são o Módulo 3.

---

## 7. Restrições

- Continua sem rede, sem dependência, sem modelo treinado, um `index.html`.
- Nenhuma operação silenciosa: se uma salvaguarda impedir a etapa, o log diz
  qual e por quê.
- **A cor nunca é escolhida, só medida.** Se um dia houver um controle que
  ajuste cor por gosto, ele é `colour-grade` e o log tem que parar de negar
  grading. Não misture os dois ids.
- O arquivo de M 31 usado para calibrar esta spec é de terceiro e **não entra na
  árvore**, em nenhuma forma — nem como fixture, nem como golden, nem como
  recorte.
