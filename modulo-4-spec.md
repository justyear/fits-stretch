# Justyear Stretch — Módulo 4: saturação seletiva

**Objetivo:** tornar visível a cor que a calibração já mediu, sem alterar
qual cor é, sem estourar o núcleo, e sem colorir o ruído do fundo.

**Restrição de projeto que governa tudo:** tem que funcionar em qualquer alvo.
Galáxia, nebulosa de emissão, aglomerado, Via Láctea. Saturação uniforme falha
de jeitos diferentes em cada um, e falha visivelmente.

---

## 0. A mudança de natureza, e como o produto sobrevive a ela

Todas as etapas anteriores **medem**. A extração de fundo mede um gradiente. A
calibração mede o fluxo estelar. O esticamento mede a mediana. Nenhuma decide.

**Saturação não mede nada.** E o teste que resolve isso é perguntar *"qual é a
saturação verdadeira deste objeto?"* — a pergunta não tem resposta. O gradiente
**está** no quadro; a razão de fluxo estelar **é** propriedade dos fótons. Não
existe uma saturação que o céu tenha e que a ferramenta esteja recuperando.

O `amount: 1.45` da §1 não desfaz isso. Ele foi medido de uma entrega manual, e
**o que essa medição mediu foi o que uma pessoa escolheu.** É medição precisa de
um gosto.

E o log hoje termina dizendo:

> Not applied: noise reduction, sharpening, **saturation**, deconvolution, star
> removal, colour grading, or any AI or generative step.

Essa palavra sai da frase quando a etapa roda, e é a primeira vez no projeto em
que a ferramenta faz algo que não é medição.

### A formulação, e ela é mais apertada que "é gosto"

> A etapa é uma **preferência aplicada sob restrições medidas**. A máscara de
> SNR e a queda nas altas luzes **não são gosto** — "não amplifique onde não há
> sinal" é afirmação sobre ruído, e "não empurre além de onde um canal satura" é
> aritmética. As restrições **impedem a preferência de mentir**. Elas **não a
> convertem em medição.**

Isso tem consequência operacional para o texto: **o log não pode usar a máscara
medida para insinuar que a etapa é medida.** Um produto que satura, explica a
máscara em detalhe e nunca diz "esta parte é uma escolha" usou medição como
cobertura. Por isso a última linha do bloco da §4 fica, e não se suaviza.

**O que preserva a integridade além disso:** a operação escala **crominância** e
não toca em **matiz**. Ela torna mais visível a cor que a calibração mediu; não
decide qual cor é.

⚠ **Mas cuidado com o que essa verificação prova.** A preservação de matiz aqui é
**teorema, não propriedade**: `ch' = Y + (ch−Y)k` escala toda diferença entre
canais por `k`, e matiz depende só de razões dessas diferenças, então `k`
cancela — e os dois caminhos de estouro também preservam. Deriva zero é o
resultado certo **e também o que sai se a etapa não fizer nada**. Ela verifica a
**implementação**, nunca o desenho, e só vale acompanhada do controle negativo
que prova que dispara. Ver a §2.4 e o NOTAS.

**O log tem que dizer as duas coisas:** que saturação foi aplicada, com o fator
exato, e que o matiz não mudou, com a deriva medida. Uma etapa estética
declarada é honesta; uma escondida destrói o argumento inteiro.
---

## 1. O que a referência profissional faz, medido

Medi a saturação por faixa de luminância numa entrega manual de M 31 feita no
Siril:

| luminância | % do quadro | saturação média |
|---|---|---|
| 0,00–0,10 | 0,3 % | 0,281 |
| 0,10–0,20 | 83,4 % | 0,148 |
| 0,20–0,35 | 7,8 % | 0,131 |
| 0,35–0,55 | 5,0 % | 0,213 |
| **0,55–0,80** | 2,3 % | **0,335** |
| 0,80–1,01 | 1,2 % | 0,227 |

**O padrão: sobe do fundo até o meio-tom, atinge o pico em 0,55–0,80, e cai nas
altas luzes.**

E a saída atual da ferramenta, no mesmo quadro: saturação média de **0,167** nos
10 % mais brilhantes, contra **0,236** da referência. **Fator 1,4.**

Não é diferença de categoria. É um multiplicador, e a curva dele tem forma
conhecida.

---

## 2. A operação

### 2.1 Decomposição

```
Y = 0.2126·R + 0.7152·G + 0.0722·B          (Rec. 709, a mesma do Módulo 3)
C_c = canal_c − Y                            (crominância, com sinal)
canal_c' = Y + C_c · k                       (k = fator local, ver 2.2)
```

**Por que isto preserva matiz.** Os três `C_c` são multiplicados pelo **mesmo**
`k`, então a direção do vetor de crominância não muda — só o comprimento. Matiz
é direção; saturação é comprimento. Igual ao `applyVia: 'luminance'` do Módulo 3,
e pela mesma razão.

`Y` não é tocado. Brilho não muda.

### 2.2 O fator local, dirigido por SNR

Aqui está a diferença entre funcionar num alvo e funcionar em todos.

```
params: {
  amount: 1.45,          // fator no pico
  snrLow: 3.0,           // abaixo disso, k = 1 (nada acontece)
  snrHigh: 25.0,         // acima disso, k = amount
  highlightKnee: 0.80,   // onde comeca a cair
  highlightFloor: 0.35,  // fracao do amount que sobra em Y = 1
}
```

**A máscara de sinal não usa luminância absoluta, usa SNR:**

```
snr = (Y − fundo) / sigma_ruido
w   = clamp((snr − snrLow) / (snrHigh − snrLow), 0, 1)
```

`fundo` e `sigma_ruido` já são medidos — vêm de `measure()` sobre a luminância,
que o Módulo 3 calcula. Nada novo a estimar.

**Por que SNR e não luminância.** Um limiar em luminância absoluta funciona numa
imagem e falha na seguinte, porque o nível do fundo depende do alvo, do céu e do
tempo de integração. SNR é adimensional: "três desvios acima do ruído" significa
a mesma coisa num Bortle 4 e num Bortle 8, num quadro de 20 minutos e num de 60
horas.

**É isto que faz a etapa funcionar em qualquer alvo.**

**A queda nas altas luzes:**

```
roll = Y <= highlightKnee ? 1
     : highlightFloor + (1 − highlightFloor)·(1 − (Y − knee)/(1 − knee))
k    = 1 + (amount − 1) · w · roll
```

Sem isso, o núcleo de galáxia vira um disco laranja chapado e a nebulosa de
emissão vira vermelho neon. Foi medido: a referência **cai** de 0,335 para 0,227
acima de 0,80.

### 2.3 Estouro

`Y + C·k` pode passar de 1 num canal. **Mesma regra do Módulo 3:** se
`max(R',G',B') > 1`, divide os três pelo máximo. Nunca clampeia um canal só —
isso muda o matiz, que é exatamente o que a etapa promete não fazer.

Se `min < 0`, some o mínimo dos três e reescale para preservar `Y`. Registre as
duas contagens.

### 2.4 Salvaguardas

**Ruído de croma no fundo.** Saturar amplifica o ruído de cor. A máscara de SNR
já protege — em `snr < 3` o `k` é 1 — mas a etapa tem que **medir** o efeito e
recusar se ele for grande:

```
Antes e depois, meça o desvio padrão da crominância nos pixels com snr < snrLow.
Se ele crescer mais de 2 %, a máscara não está protegendo o fundo: recuse,
com o número na mensagem.
```

Isso é a mesma forma da salvaguarda de sensibilidade do Módulo 2 — mede a
grandeza que alega proteger, em vez de usar uma constante escolhida.

**Deriva de matiz.** Medida em execução, exigida abaixo de 1e-6, como o
`colourFidelity`. Se der mais, a implementação está errada, não a tolerância.

**Mono.** Sem crominância. `applied: false` com `skipReason`.

---

## 3. O record

```js
{
  id: 'saturation',
  name: 'Selective saturation',
  applied: true,
  params: { ...efetivos... },
  mask: {
    background, noiseSigma,          // de onde o SNR saiu
    pixelsBelowSnrLow, pctFrame,     // quantos ficaram intocados
    pixelsAtFullAmount, pctFrame,
    meanK, maxK,
  },
  hueFidelity: {
    maxHueDrift,                     // exigido < 1e-6
    driftSamples,
  },
  chromaNoise: {
    sigmaBefore, sigmaAfter, growthPct,   // a salvaguarda
  },
  saturationByLuminance: [           // a tabela da §1, para o golden
    { range: [0.0,0.1], pct, before, after }, ...
  ],
  overflow: { pixelsRescaled, pixelsLifted },
  before: { perChannel: [...] },
  after:  { perChannel: [...] },
}
```

A tabela `saturationByLuminance` é o que permite comparar a saída contra uma
entrega manual sem olhar a imagem. É a métrica do produto.

---

## 4. O registry, e a frase que muda

```js
{ id: 'saturation', label: 'saturation', announce: false },
```

`announce: false` porque o log dedica um bloco à etapa. E a linha "Not applied"
perde a palavra **sozinha**, pelo mecanismo do Módulo 0.

**Verifique o round-trip nas duas direções**, como no passo 7 do Módulo 1: com
`applied: true` o log descreve e não nega; com `applied: false` nega e não
descreve.

O bloco do log tem que carregar, no mínimo:

> Selective saturation: chroma was scaled by up to ×1.45, strongest where the
> signal is well above the noise and rolled off in the highlights so a bright
> core does not turn into a flat disc of colour. **Hue was not changed** — all
> three channels were scaled by the same number, so the direction of the colour
> is untouched and only its strength moved. Measured on this frame, the largest
> hue change was 2.1e-16. Background chroma noise grew 0.4 %.
>
> This is the one step here that is a preference rather than a measurement, and
> it says so.

Aquela última frase fica. É o que separa este produto de um que satura em
silêncio.

---

## 5. Fixture novo

`fixture-saturation.fit` — 1600×1200×3, determinístico, com **quatro regiões de
matiz conhecido e escritas em `HISTORY`**, cada uma testando um modo de falha
diferente:

| região | o que testa |
|---|---|
| **núcleo brilhante**, quente, saturando até 0,95 | a queda nas altas luzes; sem ela vira disco chapado |
| **nebulosa de emissão**, vermelho forte em meio-tom | o caso que satura para neon |
| **braço fraco**, azul, logo acima do ruído | a máscara de SNR deixa passar sinal fraco de verdade? |
| **fundo puro**, ruído de croma sem sinal | a salvaguarda de ruído; tem que sair intocado |

O teste que importa: **os matizes na saída têm que bater com os matizes nos
cards**, dentro de 1e-6, enquanto a saturação sobe pelo fator esperado em cada
região. Verdade externa, como o gradiente do Módulo 1.

Acrescente também um caso de céu com SNR baixo em todo o quadro, para a
salvaguarda de ruído disparar — nenhum fixture atual a exercita, e a regra do
`compare-safeguards` do Módulo 2 diz que salvaguarda sem caso que dispare é
afirmação, não controle.

---

## 6. Ordem de execução

1. `steps/saturation.js` com a decomposição e o `k` uniforme, sem máscara. Mede
   `hueFidelity`. Verifica que o matiz não anda.
2. Máscara de SNR. Verifica no `fixture-saturation` que o fundo sai intocado e o
   braço fraco não.
3. Queda nas altas luzes. Verifica que o núcleo não chapa.
4. Salvaguardas: ruído de croma e deriva de matiz.
5. `fixture-saturation.fit` no gerador; golden capturado.
6. `registry.js`: entrada nova, round-trip nas duas direções.
7. Bloco do log com os números do record.
8. `compare-safeguards` ganha o caso que faz a salvaguarda de ruído disparar.
9. `reference_m23.py` estendido; `compare-reference` cobre os campos novos.

Os passos 1 a 3 já produzem imagem melhor. Os 4 a 9 são o que permite publicar.

---

## 7. Restrições

- Continua sem rede, sem dependência, sem modelo treinado, um `index.html`.
- **Matiz nunca muda.** Se uma operação futura precisar mudar matiz, ela é
  `colour-grade` e tem id próprio.
- A máscara é dirigida por SNR, nunca por luminância absoluta. É o que faz a
  etapa valer em qualquer alvo, e é requisito, não preferência.
- Nenhuma constante entra sem ter sido medida contra um caso real ou contra a
  verdade de um fixture. O `amount: 1.45` sai da medição da §1; se ele mudar,
  a medição que o justifica muda junto.
- Toda salvaguarda precisa de um caso que a faça disparar, no
  `compare-safeguards`.
