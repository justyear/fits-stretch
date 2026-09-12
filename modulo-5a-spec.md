# Justyear Stretch — Módulo 5a: enquadramento

**Objetivo:** oferecer um recorte no objeto, sem nunca aplicá-lo por conta
própria.

> **O objetivo era duplo e encolheu.** A outra metade — uma segunda saída em
> meia escala — foi implementada, liberada e depois **retirada inteira**, com o
> motivo e o que ele ensinou registrados na **§2**. O título deste módulo dizia
> *"escala e enquadramento"*; hoje diz só enquadramento, e a diferença entre os
> dois é a seção que ficou no lugar da etapa.

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

> **Metade desta conclusão não sobreviveu, e o motivo não estava na medição.** A
> escala de fato explica a diferença visual — este quadro reduzido tem mesmo
> metade do ruído aparente. O que não se sustentou foi *oferecer* a redução: a
> condição que liberava o botão quase nunca fecha em dado real. A medição de §0
> continua certa; a etapa que ela justificou saiu na §2.

---

## 1. As duas decisões de produto, e o motivo

### 1.1 A saída cheia é a única saída

O reduzido parece melhor e é o que a pessoa vai postar. Ainda assim a
ferramenta entrega resolução cheia, porque ela inteira se apoia em não esconder
nada, e **entregar uma versão que parece melhor porque escondeu ruído contradiz
o argumento do produto**.

A decisão original era mais fraca: o reduzido virava um segundo botão,
explícito, com o log dizendo a escala. Esse botão existiu e saiu — **§2**. A
decisão de produto sobreviveu à etapa que a implementava; o que caiu foi a
medição que a condicionava.

### 1.2 O recorte é sugerido, nunca aplicado

Enquadramento é autoria. Recortar sozinho é decidir a composição da foto de
outra pessoa — e é a mesma classe de erro do modo IA do GraXpert, que decide
onde está o objeto e erra 12,5%.

A ferramenta detecta, mostra o retângulo sobre a imagem, e oferece. Aplicar é um
clique.

---

## 2. A saída em meia escala — REMOVIDA

A etapa foi especificada, implementada, testada contra referência Python,
capturada em golden, liberada na v1.4.0 — e **retirada inteira** na primeira
rodada em dado real. Esta seção fica no lugar dela, porque apagá-la esconderia
a única coisa que o módulo ensinou de graça.

### 2.1 O que era

Redução por **média de caixa 2×2 exata**, em float, antes do `quantise`,
oferecida num **segundo botão** e nunca aplicada ao arquivo principal. Quatro
pixels independentes viram um e o ruído cai por √4 = 2; o log afirmava a razão
**medida**, não a prevista, e o botão **só aparecia quando a razão medida
estava entre 1,8 e 2,2**. Fora disso, nada de botão: dizer a verdade num texto
que ninguém lê não é o mesmo que não prometer.

**Nada disso estava errado.** A condição está certa — um botão não deve
prometer 2× e entregar 1,07. O erro foi outro.

### 2.2 Por que saiu

```
nos treze fixtures       12 oferecem
em dado real             não oferece
```

**Onze dos treze fixtures são sintéticos com ruído independente por pixel:
brancos por construção.** Só o `seestar` passa por um debayer, e ele dá 0,753 —
que é o **extremo otimista**, porque um quadro real tem debayer *mais* registro
e empilhamento, e cai para 0,657.

Quase todo alvo interessante é colorido; quase todo dado colorido de amador é
CFA; **CFA sempre correlaciona vizinhos.** O portão foi construído para uma
condição que a população real quase nunca satisfaz.

**Removida, não desligada.** Código morto com aparência de funcionalidade é
pior que ausência: o próximo a ler conta uma capacidade que não existe. Saíram
`half-scale.js`, o segundo botão, o bloco do log, os campos do record, as
curvas de densidade da referência, o bloco do comparador e a entrada do
registry.

### 2.3 O que isso ensinou, e é o que fica

A suíte estava verde o tempo inteiro, e estava certa: cada verificação
respondia exatamente a pergunta que sabe responder.

| verificação | pergunta | não pergunta |
|---|---|---|
| golden | mudou? | — |
| referência Python | os dois concordam? | — |
| controle negativo | a salvaguarda dispara? | — |
| **nenhuma** | | **os fixtures representam a população?** |

**O teste que faltava não era de corretude — era de REPRESENTATIVIDADE.** E ele
custa uma linha, feita antes de escrever a etapa:

> **Antes de construir um portão, qual fração da população real passa por ele?**

Aqui a resposta seria *"quase nenhuma, porque quase todo dado amador é CFA"*, e
teria matado a etapa na spec em vez de na entrega. O custo real: uma seção de
spec, uma implementação, dois botões, campos de record, curvas de referência,
goldens e sete passos de execução.

**Se alguma versão reduzida voltar**, ela volta pelo outro caminho: não como
portão condicionado a uma medição que quase nunca fecha, e sim como escolha
explícita da pessoa, com o log dizendo a escala e sem prometer número nenhum
sobre ruído.
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
  // Folga em volta do retangulo, fracao do LADO MAIOR DA CAIXA DO OBJETO --
  // nunca do quadro. Varredura no fixture-oneobject (quadro 1601x1200, caixa
  // 960x743): 0,040 -> 2,14x de ganho; 0,050 -> 2,05x; 0,055 -> 2,00x (o
  // cruzamento); 0,120 -> 1,52x, que mal passaria da salvaguarda de ganho.
  cropMargin: 0.05,
  cropMinFrame: 0.20,    // nunca sugere recorte menor que isto do quadro
  // cropMaxCoverage SAIU -- ver a nota abaixo
}
```

1. Máscara de sinal: `Y > céu + cropSigma × ruído`.
2. Máscara de extenso: densidade de vizinhança ≥ `cropDensity` na janela
   `cropWindow`. Estrela é pequena e cai fora; objeto extenso fica.
3. Maior componente conexo da máscara de extenso.
4. Retângulo envolvente, mais `cropMargin × max(largura, altura) da caixa`.
5. Ajusta para a proporção do quadro original, expandindo o lado menor.

**Salvaguardas, e cada uma tem que ter caso que a exercite:**

- componente conexo menor que `cropMinFrame` do quadro → não sugere; um alvo
  pequeno demais provavelmente é uma estrela grande ou um artefato
- ~~objeto já ocupando mais que `cropMaxCoverage`~~
  > **REMOVIDA, e não é dívida.** Esta salvaguarda foi implementada e depois
  > retirada, porque medida ela **não pode disparar** — e o motivo não é falta
  > de fixture. Um objeto que cobre mais de ~70% do quadro **é o fundo**, pela
  > definição da etapa que roda antes: o modelo de placa fina ajusta a mancha
  > suave que domina o quadro e a subtrai. Medido no `fixture-bigobject`,
  > construído de propósito com 72,9% de cobertura: **16.915 px de sinal e 115
  > px de extenso**, contra 571.279 e 557.356 no `fixture-oneobject`.
  >
  > Não existe estado da cadeia em que ela tenha o que julgar, e fabricar um
  > exigiria desligar a extração de fundo — testando um caminho que a ferramenta
  > real nunca percorre.
  >
  > | | o estado existe? | veredito |
  > |---|---|---|
  > | salvaguarda **sem caso ainda** | sim, falta fixture | **dívida** |
  > | salvaguarda **vazia por construção** | não existe | **fechado** |
  >
  > Esta é a segunda. O registro fica para que ninguém a reimplemente daqui a
  > seis meses achando que encontrou um buraco: a pergunta foi feita, medida e
  > respondida. O record carrega `coverageGuard` com o número e o motivo —
  > **nunca uma salvaguarda que aparenta vigiar algo.**
- mais de um componente acima de `cropMinFrame` → **não sugere**, e diz por quê.
  Dois objetos no quadro (M 31 e M 110, Coração e Alma) são um enquadramento
  deliberado, e escolher um deles é decidir pela pessoa qual ela queria.
- ganho de cobertura abaixo de `CROP_MIN_GAIN` (1,5×) → **não sugere.** Um
  recorte que leva o objeto de 10% para 13% do quadro não vale um clique, e
  oferecê-lo gastaria a atenção da pessoa num retângulo que não reenquadra
  quase nada.
  > **A ordem importou.** Com a margem antiga — fração do quadro — o único
  > fixture que sugere dava **1,44×**, e esta salvaguarda o teria silenciado: a
  > suíte voltaria a zero casos que sugerem e o 1,44 seria lido como *"este
  > quadro não vale recorte"* quando o que ele dizia era *"a margem está
  > errada"*. Depois do conserto, **2,05×** — folga de 37%. Uma salvaguarda que
  > silenciaria o seu único caso bom não está pronta: está apontando para uma
  > causa a montante.

A salvaguarda dos **dois componentes** é a mais importante do módulo, e é a
que separa isto do recorte automático que seria errado.

**Duas saídas propostas, ANOTADAS E NÃO IMPLEMENTADAS.** Em dado real o maior
componente não é o objeto: é o objeto **mais o halo fraco espalhado**, tudo
ligado pela máscara de ocupação, e a caixa envolvente de um borrão espalhado é
o quadro. O diagnóstico é a densidade `pixelFrac / boxFrac` — 72 a 78% nos
fixtures, ~14% em dado real.

| proposta | o que faz | por que não entrou |
|---|---|---|
| subir o `cropSigma` | o componente vira só o corpo brilhante | nos fixtures a densidade **não se move** com o sigma (78% em 2,5; 76% em 8,0), porque a borda é dura por construção |
| retângulo por **percentil** | a caixa que contém 90% dos pixels, ignorando a cauda | nos fixtures p90 dá sempre **80% da caixa em cada eixo** — um fator fixo de elipse sólida, não uma medição |

**Nenhum fixture distingue as duas**, e escolher sem evidência seria fixar uma
hipótese num ponto só. É a mesma regra do `rejected-edge`: **modo de falha sem
fixture é dívida nomeada, não trabalho.** O fixture que falta está na §4.

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

`fixture-twoobjects.fit` — 1601×1200×3, determinístico, com **dois objetos
extensos separados**, ambos acima de `cropMinFrame`, posições e tamanhos nos
cards `HISTORY`.

É o único fixture que exercita a salvaguarda que mais importa. Sem ele, ela é
afirmação e não controle — a regra que este projeto já gravou.

Os fixtures existentes cobrem o resto: `gradient` tem um objeto só e sugere;
`flatsky` não tem objeto e não sugere; `colour` tem objeto pequeno.

> **A frase que estava aqui era o erro do módulo:** *"Para a meia escala,
> nenhum fixture novo é preciso — a razão de ruído é medida em todos."* Medir
> em todos os fixtures não é cobertura quando todos os fixtures são sintéticos
> com ruído independente por pixel. Doze de treze ofereciam a redução; dado
> real não oferece. Ver §2.

**O fixture que falta, e é dívida nomeada:** um objeto com **halo** — perfil
que cai devagar, sem borda dura — para que a densidade `pixelFrac / boxFrac`
saia baixa. Os três fixtures de recorte têm elipse sólida com borda logística
em `r = 1`, então a densidade fica em 76–78% **qualquer que seja o
`cropSigma`**, e o retângulo que conteria 90% dos pixels dá sempre 80% da caixa
em cada eixo. É um fator fixo de uma elipse sólida, não uma medição. Sem esse
fixture, as duas saídas anotadas na §3.1 não podem ser escolhidas por
evidência.

---

## 5. Referência Python

`reference_m23.py` ganha o recorte. (A meia escala saiu antes de a referência
dela virar dívida — ver §2.)

O maior componente conexo depende do algoritmo de rotulagem, e
`scipy.ndimage.label` e uma implementação própria em JS podem diferir em um
pixel na fronteira. **O número de componentes é comparado exatamente** —
inteiro contado — e `signalPixels` / `extendedPixels` pela cota de contagem por
limiar, que é a cota certa para eles: são contagens de pixels perto de um
limiar de brilho.

> **CORREÇÃO, e ela vale mais que a linha original.** Esta seção mandava
> comparar **o retângulo** pela mesma cota de contagem por limiar. Está errado,
> e o erro passou para o comparador: uma aresta de retângulo é uma **posição**,
> não uma contagem de pixels, e a cota lida no eixo errado saiu em milhares de
> pixels. Medido quando a margem mudou de fração do quadro para fração do
> objeto:
>
> ```
> rect.w   1119 contra 1333   difere 214 px   "cota 2543 pixels"   PASS~
> ```
>
> Uma mudança real de 214 pixels passou sem ser notada. Quem pegou foi
> `cobertura.depois`, que é uma razão no eixo [0,1]. É a **quinta** instância da
> classe "cota lida no eixo errado" e a primeira que **afrouxa** em vez de
> reprovar — ver o `NOTAS`.
>
> O conserto é isolamento de fórmula, como em `shadows(formula)`: o retângulo é
> função determinística de `objectRect` + margem + razão + quadro, então
> alimentar a fórmula daqui com o `objectRect` de lá separa *"a caixa é a
> mesma?"* de *"a regra da margem é a mesma?"*. **Implementado.**
>
> O que a suíte compara hoje, e a ordem importa:
>
> | linha | pergunta | cota |
> |---|---|---|
> | `caixa.x/y/w/h` | a caixa do objeto é a mesma? | exata — e ela **bate**: 279,229,960,743 dos dois lados |
> | `rect(copia do comparador)` | a cópia da fórmula no comparador é fiel a este lado? | exata — afirmação sobre o comparador, não comparação |
> | `rect(formula)` | a regra da margem é a mesma? | exata, alimentada com a caixa **deles** |
> | `rect.x/y/w/h` | o retângulo é o mesmo? | **propagada pela fórmula** a partir da diferença das caixas — hoje zero |
>
> Com as caixas idênticas a cota propagada é **zero**, então a comparação das
> arestas é exata — calculada, não afirmada. A cópia em PowerShell tem que
> reproduzir `Math.round` do JS com `Floor(x + 0.5)`: `[math]::Round` do .NET
> arredonda meio para par e inventaria divergência em toda aresta que caísse no
> meio. Uma isolação de fórmula que erra metade da fórmula mede outra coisa.

---

## 6. Ordem de execução

A ordem em que o módulo foi de fato executado, com o que sobrou de cada passo.
Os dois primeiros estão riscados e ficam escritos: apagá-los esconderia que o
módulo entregou uma etapa e depois a retirou.

1. ~~Redução 2×2 em float, antes do `quantise`, com a razão de ruído medida.~~
2. ~~Segundo botão de download, e o bloco do log.~~ **Removidos — ver §2.**
3. Detecção do objeto e o retângulo. Sem UI ainda — só o record.
4. As três salvaguardas, com o `fixture-twoobjects` para a de dois objetos.
   **E um fixture de dimensão ímpar**, que entrou por causa do passo 1 e ficou
   por outro motivo: `1601 − 1` é múltiplo do divisor da treliça do fundo, e é
   esse o caso que produziu um NaN na última coluna. O card `HISTORY` do
   fixture diz isso.
5. O retângulo desenhado e o botão.
6. `registry` com o estado `suggested`, round-trip nos três estados.
7. Referência Python e `compare-reference`.
8. **Depois da primeira rodada em dado real:** a margem vira fração do objeto,
   a salvaguarda de ganho entra, e a etapa da meia escala sai inteira.

Os passos 3 a 8 são o recorte, e hoje são o módulo.

---

## 7. Restrições

- Continua sem rede, sem dependência, sem modelo treinado, um `index.html`.
- **A saída sai em resolução cheia, e hoje ela é a única.** Uma versão reduzida
  parece melhor porque escondeu ruído; se alguma voltar, volta como escolha
  explícita e nunca como padrão — ver §2.
- **O recorte nunca é aplicado sem clique.** Enquadramento é autoria.
- **A margem do recorte é fração do OBJETO, nunca do quadro.** Um número que
  não sabe o tamanho do que está enquadrando enquadra errado nos dois extremos.
- Toda salvaguarda precisa de um fixture que a faça disparar, **e todo portão
  precisa de uma estimativa de quanto da população real passa por ele.** A
  primeira metade é antiga; a segunda foi o que custou a §2.
