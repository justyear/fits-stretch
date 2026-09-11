# Justyear Stretch — Módulo 5a: escala e enquadramento

**Objetivo:** entregar uma segunda saída em meia escala, e oferecer um recorte no
objeto — sem que nenhuma das duas seja aplicada por conta própria.

**Origem:** medição comparando a saída da ferramenta com uma entrega manual do
mesmo alvo. As duas concordam onde eu esperava diferença e divergem onde eu não
esperava.

---

## 0. O que a medição disse, e por que ela decide esta spec

Comparando a saída da v1.3.0 com uma entrega manual de M 31:

| | referência manual | ferramenta |
|---|---|---|
| ruído no céu (alta freq.) | 10,25 | **23,83** |
| alta frequência no objeto | 59,88 | 155,20 |
| **razão detalhe/ruído** | 5,84 | **6,51** |
| saturação no objeto | 0,252 | 0,198 |
| fundo | 37,1 / 255 | 23,0 / 255 |

**A razão detalhe/ruído da ferramenta é melhor.** O processamento não está
perdendo estrutura nem inventando ruído.

A referência tem metade do ruído no céu porque **está reduzida e recortada** —
2500×1500 contra 2160×3840 em resolução cheia. Reduzir pela metade divide o
ruído aparente por dois; é aritmética de amostragem, não processamento.

**Conclusão que governa o módulo:** a maior diferença visual restante não é
uma etapa de processamento que falta. É escala e enquadramento. Duas coisas
baratas, e nenhuma das duas deve acontecer sem o usuário pedir.

---

## 1. As duas decisões de produto, e o motivo

### 1.1 A saída cheia continua sendo o padrão

O reduzido parece melhor e é o que a pessoa vai postar. Ainda assim o padrão é
a resolução cheia, porque a ferramenta inteira se apoia em não esconder nada, e
**entregar por padrão uma versão que parece melhor porque escondeu ruído
contradiz o argumento do produto**.

O reduzido vira um segundo botão, explícito, com o log dizendo a escala. A
pessoa escolhe, sabendo o que escolheu.

### 1.2 O recorte é sugerido, nunca aplicado

Enquadramento é autoria. Recortar sozinho é decidir a composição da foto de
outra pessoa — e é a mesma classe de erro do modo IA do GraXpert, que decide
onde está o objeto e erra 12,5%.

A ferramenta detecta, mostra o retângulo sobre a imagem, e oferece. Aplicar é um
clique.

---

## 2. A saída em meia escala

```
params: { halfScale: { filter: 'box', gamma: 'linear' } }
```

**Redução por média de caixa 2×2 exata.** Não bicúbica, não Lanczos: média de
caixa é a única que corresponde ao que a medição justifica — quatro pixels
independentes viram um, e o ruído cai por √4 = 2. Um filtro com lóbulos
negativos não divide o ruído pelo mesmo fator e o log não poderia afirmar o
número.

**Onde ela acontece na cadeia importa.** A redução roda **antes do `quantise`**,
sobre o float, e não sobre o PNG de 8 bits. Reduzir depois já perdeu a
precisão que a média ia recuperar.

```
... → saturação → [redução 2×2 em float] → quantise → PNG
```

Dimensão ímpar: descarta a última linha ou coluna, e o log diz que descartou.
Nunca interpola para fechar a conta — isso reintroduz correlação entre pixels
vizinhos e o número do ruído deixa de valer.

**O dither do `quantise` continua**, com a mesma semente. Aplicado depois da
redução, sobre o quadro menor.

### 2.1 O que o record grava

```js
{
  id: 'half-scale',
  applied: true,
  params: { filter: 'box2x2' },
  inputSize: [w, h],
  outputSize: [w2, h2],
  droppedRow: bool, droppedColumn: bool,
  noise: {
    skyHighFreqBefore, skyHighFreqAfter, ratio,   // medido, não previsto
    expectedRatio: 2.0,
  },
  before: { perChannel: [...] },
  after:  { perChannel: [...] },
}
```

`noise.ratio` medido contra `expectedRatio: 2.0` é a verificação do módulo. Se
a razão sair longe de 2, a redução não está fazendo o que o log diz. Tolerância
sugerida: 1,8 a 2,2 — o ruído real não é perfeitamente branco, então 2,0 exato
não é esperável.

### 2.2 O que o log diz

> Half-scale copy: 2160 × 3840 reduced to 1080 × 1920 by averaging each 2 × 2
> block. Four independent pixels become one, so the noise in the sky falls by
> a factor of **2.03** — measured on this frame, against the 2.00 that exact
> averaging predicts. **No detail was removed**: averaging does not smooth, it
> resamples, and the full-resolution file above has everything this one has.
>
> This copy is offered because it is easier to share, not because it is better.
> The full-resolution one is the honest size of what your telescope recorded.

A última frase fica. É o que impede o botão de virar uma promessa escondida.

---

## 3. O recorte sugerido

### 3.1 Detecção

A mesma máquina que a rejeição de fonte extensa do Módulo 2 já usa — nada novo
a implementar.

```
params: {
  cropSigma: 2.5,        // sinal acima do céu que conta como objeto
  cropWindow: 25,        // a janela de densidade, a mesma do Módulo 2
  cropDensity: 0.50,
  cropMargin: 0.08,      // folga em volta do retangulo, fração do lado maior
  cropMinFrame: 0.20,    // nunca sugere recorte menor que isto do quadro
  cropMaxCoverage: 0.70, // se o objeto já ocupa mais que isto, não sugere
}
```

1. Máscara de sinal: `Y > céu + cropSigma × ruído`.
2. Máscara de extenso: densidade de vizinhança ≥ `cropDensity` na janela
   `cropWindow`. Estrela é pequena e cai fora; objeto extenso fica.
3. Maior componente conexo da máscara de extenso.
4. Retângulo envolvente, mais `cropMargin`.
5. Ajusta para a proporção do quadro original, expandindo o lado menor.

**Salvaguardas, e cada uma tem que ter caso que a exercite:**

- componente conexo menor que `cropMinFrame` do quadro → não sugere; um alvo
  pequeno demais provavelmente é uma estrela grande ou um artefato
- objeto já ocupando mais que `cropMaxCoverage` → não sugere; não há o que
  recortar
- mais de um componente acima de `cropMinFrame` → **não sugere**, e diz por quê.
  Dois objetos no quadro (M 31 e M 110, Coração e Alma) são um enquadramento
  deliberado, e escolher um deles é decidir pela pessoa qual ela queria.

Essa última salvaguarda é a mais importante do módulo, e é a que separa isto do
recorte automático que seria errado.

### 3.2 O que a pessoa vê

O retângulo desenhado sobre a imagem, com um botão. Nada muda até o clique.

Ao lado do botão, a consequência, em número:

> Crop to the object: 2160 × 3840 → 1180 × 2098. The galaxy goes from 15 % of
> the frame to 58 %.

E se não sugeriu, diz por quê, na mesma linha — nunca silêncio (confusão 10 e
21 da lista documentada).

### 3.3 O record

```js
{
  id: 'crop',
  applied: false,          // sugerido não é aplicado
  suggested: true,
  reason: null,            // ou o motivo de não sugerir
  components: n,           // quantos passaram de cropMinFrame
  rect: [x, y, w, h],
  coverageBefore, coverageAfter,
}
```

`applied: false` com `suggested: true` é estado novo. O `registry` tem que
tratá-lo: **sugerir não retira nada da frase "Not applied"**, porque nada foi
feito. Só o clique aplica, e só o clique muda a frase.

Verifique o round-trip nos **três** estados, pela lição do Módulo 4:
não sugerido, sugerido, aplicado.

---

## 4. Fixture novo

`fixture-twoobjects.fit` — 1600×1200×3, determinístico, com **dois objetos
extensos separados**, ambos acima de `cropMinFrame`, posições e tamanhos nos
cards `HISTORY`.

É o único fixture que exercita a salvaguarda que mais importa. Sem ele, ela é
afirmação e não controle — a regra que este projeto já gravou.

Os fixtures existentes cobrem o resto: `gradient` tem um objeto só e sugere;
`flatsky` não tem objeto e não sugere; `colour` tem objeto pequeno.

Para a meia escala, nenhum fixture novo é preciso — a razão de ruído é medida
em todos.

---

## 5. Referência Python

`reference_m23.py` ganha as duas etapas. A média de caixa 2×2 é trivial de
reproduzir e a razão de ruído é o número a comparar.

O recorte é mais delicado: o maior componente conexo depende do algoritmo de
rotulagem, e `scipy.ndimage.label` e uma implementação própria em JS podem
diferir em um pixel na fronteira. **Compare o retângulo com tolerância de
contagem por limiar**, pela cota que já existe, e o número de componentes
exatamente — inteiro contado.

---

## 6. Ordem de execução

1. Redução 2×2 em float, antes do `quantise`. Record com a razão de ruído
   medida.
2. Segundo botão de download, e o bloco do log.
3. Detecção do objeto e o retângulo. Sem UI ainda — só o record.
4. As três salvaguardas, com o `fixture-twoobjects` para a de dois objetos.
   **E um fixture de dimensão ímpar, que o passo 1 deixou por exercitar.**
   `stepHalfScale` descarta a última linha ou coluna e o log diz que descartou,
   mas nenhum dos nove fixtures tem lado ímpar — `droppedRow` e `droppedColumn`
   saem `false` em todos, dos dois lados, e zero contra zero não é acordo. O
   caminho está escrito e não está verificado. Basta um lado ímpar em qualquer
   fixture novo; não precisa de um próprio.
5. O retângulo desenhado e o botão.
6. `registry` com o estado `suggested`, round-trip nos três estados.
7. Referência Python e `compare-reference`.

Os passos 1 e 2 já mudam a imagem que a pessoa baixa. Os 3 a 6 são o recorte.

---

## 7. Restrições

- Continua sem rede, sem dependência, sem modelo treinado, um `index.html`.
- **A saída cheia é o padrão.** Nunca troque isso sem uma decisão explícita.
- **O recorte nunca é aplicado sem clique.** Enquadramento é autoria.
- A redução é média de caixa exata. Qualquer outro filtro invalida o número do
  ruído que o log afirma.
- Toda salvaguarda precisa de um fixture que a faça disparar.
