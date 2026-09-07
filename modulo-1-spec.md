# Justyear Stretch — Módulo 1: extração de fundo

**Objetivo:** remover gradiente de poluição luminosa antes de qualquer esticamento,
com colocação automática de amostras, rejeição visível ponto a ponto, e ajuste
manual quando o automático errar.

**Divisão:** 1a (matemática + automático + rejeição visível) e 1b (edição
interativa). 1a entrega valor sozinho e é testável contra a referência Python.
1b é UI pura e não pode quebrar a matemática.

---

## 0. O pré-requisito que quebra a identidade byte a byte

Isto vem antes de qualquer linha de extração de fundo.

Hoje a etapa devolve float valendo `k/255` — 256 níveis. Aceitável enquanto a
cadeia tem uma etapa. A extração de fundo é a primeira e entrega para o
esticamento; 256 níveis passados adiante jogam fora a sombra, que é onde a
nebulosa fraca vive.

**Mudança:**

1. Toda etapa devolve float de precisão plena.
2. `quantise` acontece uma vez, no fim da cadeia.
3. `compare-golden.ps1` ganha a tolerância da §7 do Módulo 0. O PNG deixa de ser
   critério byte a byte e os `records` viram o critério.

A identidade byte a byte morre aqui, por construção. Não é regressão, é o preço,
e já está registrado na spec do Módulo 0.

**Ordem obrigatória:** implementar 2 e 3 antes de 1. Se a tolerância não estiver
no comparador quando a cadeia virar float, o harness reprova trabalho correto e
você não sabe distinguir isso de uma regressão real.

---

## 1. Os defeitos que esta etapa existe para não repetir

Pesquisados em GraXpert e Siril, e nas 21 confusões documentadas.

### Do GraXpert

| defeito | consequência |
|---|---|
| O modo IA ignora os pontos colocados à mão, sem avisar | usuário ajusta, roda, nada do que ele fez entra na conta |
| A IA remove nebulosidade demais em certas imagens | mediu-se 12,5% de perda no braço do M31 contra 5% no ajuste manual |
| A extração acaba mexendo no balanço de cor | muda a ordem correta em relação à calibração |
| Artefatos que aparecem em outro programa e não no display do próprio GraXpert | o que se vê não é o que sai |

### Do Siril

| defeito | consequência |
|---|---|
| Não tem arrastar — clique adiciona, clique direito remove | mover um ponto é apagar e recolocar |
| Tolerância global única para a imagem inteira | baixar para proteger o objeto perde amostra na borda também |
| Regerar a grade apaga o ajuste manual | trabalho perdido sem aviso |
| Amostras na borda dão trabalho recorrente | escreveram patch no Siril por causa disso |
| Ciclo lento: ajusta, aperta, olha, ajusta | iteração cara desestimula ajuste |
| Banding depois da extração | precisa de dither; pior em 16 bits |

### Das confusões documentadas

| # | confusão | regra que ela impõe |
|---|---|---|
| 02 | paralisia por excesso de opções | dois controles visíveis, o resto em "avançado" |
| 08 | 15 min procurando um toggle | controle fica onde a ação acontece, não em menu |
| 10 | menu desabilitado sem motivo | controle desabilitado diz por quê, ali mesmo |
| 11 | aviso enterrado em log de 60 linhas | aviso aparece sobre a imagem, no ponto do problema |
| 12, 19 | janelas travadas, sem zoom | zoom e pan obrigatórios; nada de janela modal presa |
| 20 | autostretch calibrando em céu vazio | a estatística tem que vir da região certa |
| 21 | denoise que não fez nada, sem avisar | **nenhuma operação silenciosa** |

**A regra que atravessa tudo:** nenhuma operação silenciosa. Toda ação ou faz algo
visível, ou diz por que não pode. É a 21 e é o pecado do modo IA do GraXpert, e é
o que o `record` já resolve de graça — o log diz exatamente quais pontos entraram.

---

## 2. Módulo 1a — matemática, automático e rejeição visível

### 2.1 Amostragem

Grade regular. Cada amostra é uma caixa de `boxSize` pixels de lado, e o valor da
amostra é a **mediana da caixa** por canal — mediana, não média, para sobreviver a
uma estrela dentro da caixa.

```
params: {
  samplesPerRow: 12,        // densidade; a grade é samplesPerRow x (samplesPerRow*h/w)
  boxSize: 25,              // lado da caixa em pixels do buffer sendo processado
  tolerance: 1.0,           // sigma acima do fundo global para rejeitar
  edgeMargin: 0.02,         // fração da menor dimensão excluída da borda
  smoothing: 0.10,          // regularizacao da RBF, 0..1
  correction: 'subtract',   // 'subtract' | 'divide'
  pedestal: 'model-median', // ver 2.4
}
```

`boxSize` escala com a resolução do buffer: no preview de 1024 px a caixa
encolhe proporcionalmente, senão a amostra do preview não corresponde à do
render final. Registre o valor efetivamente usado no record.

### A grade cobre o quadro inteiro; a margem só rejeita — CORRIGIDO

A implementação encaixava a grade dentro da margem, com centro em
`margem + (i+0,5)·(w−2·margem)/cols`, e depois testava se a caixa cruzava a
margem — teste que **nunca disparava**, porque a grade já tinha sido encolhida
para dentro. Os quatro fixtures reportavam `rejeitadas por borda: 0`, lido como
normal. Era sintoma: **o estado `rejected-edge` era inalcançável por
construção**.

Agora a grade tem centro em `(i+0,5)·w/cols`, cobrindo o quadro inteiro, e a
margem é só critério de rejeição — que é o que esta §2.2 sempre disse.

**Medido no `fixture-gradient.fit`, canal R:**

| | grade encaixada (atual) | grade no quadro inteiro | `reference_bg.py` |
|---|---|---|---|
| aceitas | 93 | **92** | 92 |
| rejeitadas por brilho | 15 | **16** | 16 |
| campo limpo, máximo | 0,1688 | **0,1112** | 0,1112 |
| campo limpo, média | 0,0337 | **0,0115** | 0,0115 |
| casco das amostras | 1422×1024 | 1466×1066 | — |

Com a grade sobre o quadro inteiro as duas implementações concordam **dígito a
dígito**, nos quatro números. A divergência que parecia ser "grade diferente e
álgebra diferente" era uma causa só, e é esta.

O custo da grade encaixada: **31,4% do campo limpo fica fora do casco das
amostras**, e a spline extrapola ali. O pior pixel de campo limpo está em
(1599, 1199), o canto exato do quadro.

**O contra, e por que não venceu.** Amostra perto da borda pega vinheta e
artefato de empilhamento, que é a razão de existir uma margem. Mas a resposta a
uma amostra ruim é **rejeitá-la**, com motivo no record e no tooltip — não
deixar de gerá-la. Rejeitar é visível; não gerar é silencioso, e silêncio é o
que a confusão 21 proíbe.

### Quando `rejected-edge` dispara, e por que continua 0 no padrão

Com a grade sobre o quadro inteiro, a primeira amostra fica em `w/(2·cols)` da
borda e a caixa alcança `w/(2·cols) − metade`. Então a condição é:

```
margem > w/(2·colunas) − (boxSize−1)/2
```

Com `samplesPerRow` 12 e `boxSize` 25, o padrão `edgeMargin: 0.02` fica abaixo
do limiar nos quatro fixtures — a borda continua em 0, e agora isso é uma
propriedade dos fixtures e não do código. Demonstrado, e não argumentado:

| fixture | margem no padrão | limiar | dispara em | rejeições ali |
|---|---|---|---|---|
| `nonlinear` 900×600 | 12 px | 26 px | `0,05` | 36 |
| `gradient` 1600×1200 | 24 px | 55 px | `0,05` | 38 |
| `seestar` 1920×1080 | 22 px | 65 px | `0,06` | 12 |
| `rice` 2600×1000 | 20 px | 88 px | `0,09` | 24 |

**FECHADO — `fixture-edge.fit`.** 400×300×3, 1,44 MB, o fixture mais barato da
suíte. A condição acima resolve para "quadro abaixo de ~554 px" com
`samplesPerRow` 12 e `boxSize` 25, então um quadro pequeno exercita o estado
sem mexer em nenhum parâmetro: margem 6 px, primeira amostra em x=17, caixa
alcança 5 < 6, dispara.

Com os parâmetros padrão: **38 de 108 rejeitadas por borda**, 6 por brilho, 64
aceitas — bem acima da salvaguarda de 8. E a frase aparece na entrega:

```
• Background extraction: measured the sky in 108 boxes of 25 pixels on a
  12 × 9 grid and used 64 of them (6 brighter than the background, 38 on the
  frame edge were left out).
```

Escolhido em vez de um golden do `gradient` com `edgeMargin` 0,05 por dois
motivos: o fluxo de captura não passa parâmetros, então o segundo exigiria mexer
no harness; e 1,44 MB cobre de graça uma segunda lacuna que também não tinha
nada — **quadro pequeno**, onde a grade e a margem interagem.

### 2.2 Rejeição — por ponto, com motivo

Estimativa global de fundo: mediana e MADN da imagem inteira, por canal,
via `measure()`.

Cada amostra recebe um estado:

| estado | critério |
|---|---|
| `accepted` | passou em tudo |
| `rejected-bright` | mediana da caixa > mediana global + `tolerance` × MADN, em qualquer canal |
| `rejected-edge` | a caixa cruza a margem de borda |
| `rejected-clipped` | mais de 5% dos pixels da caixa no topo da faixa |
| `rejected-nan` | a caixa contém não-finitos |
| `forced` | rejeitado pelo critério, aceito à mão pelo usuário (1b) |
| `moved` | movido à mão (1b) |

**Ponto rejeitado continua existindo e continua visível.** Não some. É a diferença
entre o usuário ver que 8 pontos foram descartados sobre a galáxia e o usuário não
ver nada. O `tolerance` mexe em quais são rejeitados, não em quais aparecem.

Cada ponto carrega o motivo em texto, para o tooltip e para o record.

**Salvaguarda:** se sobrarem menos de 8 pontos aceitos, a etapa **não roda**. Ela
devolve `applied: false` com `skipReason` explicando, e a UI mostra a mensagem
sobre a imagem. Nunca ajustar superfície com amostragem insuficiente — é como se
produz o artefato que come nebulosa.

### PENDÊNCIA DO PASSO 5 — rejeição contra fundo local, não global

O critério de `rejected-bright` acima compara a mediana da caixa contra a
**mediana global** da imagem. Isso é o que o Siril faz e é a queixa registrada
contra ele na §1: *tolerância global única para a imagem inteira*.

**O defeito está medido, num arquivo, antes de a solução existir.** No
`fixture-gradient.fit` a caixa em (1253, 1112) é rejeitada por brilho e não tem
objeto nenhum — é fundo puro mais uma estrela-sonda. O que a rejeita é o próprio
gradiente: naquele canto o fundo vale 0,020181 e o limiar global é
`0,016703 + 1,0 × 0,003269 = 0,019972`. A amostra está 0,2 nível de 255 acima de
um limiar que descreve a imagem inteira e não descreve aquele canto.

Com 13,9% rejeitado o fixture ainda funciona. **Com dado real vai piorar**, porque
gradiente de poluição luminosa é mais forte que o sintético daqui, e a fração
rejeitada cresce no lado claro justamente onde o modelo mais precisa de pontos.

**A correção não é ajustar a constante.** Subir `tolerance` para salvar o canto
claro deixa de rejeitar o objeto no canto escuro — é o mesmo trade que a §1
descreve como o problema, não como a solução. A correção é comparar cada caixa
contra uma **estimativa local** de fundo em vez da global: mediana de uma
vizinhança, ou uma primeira passada de superfície usada só como referência para
a segunda.

Isso é decisão de arquitetura e fica para o passo 5, **depois** de a RBF existir
e o defeito estar medido contra o gradiente verdadeiro. Não antecipar: uma
estimativa local escrita antes de haver superfície seria a terceira coisa nesta
etapa a estimar fundo, e as três poderiam discordar.

#### MEDIDO NO PASSO 5 — e a decisão é adiar, com prazo

O modelo foi ajustado com o critério global como está e comparado contra o
gradiente verdadeiro dos cards `HISTORY`. **A rejeição falsa não custa nada
mensurável.**

A sonda em (1253, 1112) continua sendo rejeitada. O resíduo do modelo naquele
ponto é **0,039 nível de 255 — o menor das oito sondas**, incluindo as sete
aceitas. A spline atravessa o buraco sem sagar, porque o gradiente ali é suave e
há pontos aceitos em volta.

E a região inteira onde o fundo passa do limiar global tem resíduo máximo de
**0,168 nível**, que é exatamente o resíduo máximo fora do objeto no quadro
todo. O canto rejeitado não é onde o modelo erra; ele erra sob o objeto, que é
onde deve errar.

**Portanto: fica global.** Trocar por estimativa local agora seria arquitetura
nova para consertar um defeito de custo medido igual a zero, e a §7 do Módulo 0
já registra que o que não é medido não deve ser otimizado.

**O que muda a decisão, e o que observar:**

| sinal | onde aparece |
|---|---|
| fração rejeitada acima de 40% | já é aviso na §3.5 |
| uma borda inteira rejeitada | já é aviso na §3.5 |
| resíduo no canto rejeitado subindo acima do resíduo geral | `gradient-truth.json`, campos `rejectedCorner` contra `outsideObject` |

O terceiro é o sinal específico desta pendência e agora tem número de linha de
base: `0,168` contra `0,168`, iguais. **Quando `rejectedCorner.maxLevels` passar
de `outsideObject.maxLevels` de forma consistente, a rejeição local vira
necessária e não mais opcional.** Até lá, a queixa contra o Siril está
reproduzida, medida e custando zero.

Reabrir com dado real: o gradiente sintético daqui é mais fraco que poluição
luminosa de verdade, e a fração rejeitada cresce do lado claro. O fixture mostra
o mecanismo; ele não mostra a magnitude que o mecanismo alcança em campo.

### 2.3 A superfície — RBF

Thin-plate spline sobre os pontos aceitos, por canal, independentemente.

```
phi(r) = r^2 * log(r)      // r = distancia euclidiana, phi(0) = 0
```

Sistema linear `(A + lambda*I) w = v`, onde `A[i][j] = phi(|pi - pj|)`, mais o
termo polinomial de grau 1 (3 colunas: 1, x, y) para a parte afim. `lambda` vem
do `smoothing`, escalado pela média da diagonal de `A` para ser invariante à
escala da imagem.

`N` é o número de pontos aceitos — tipicamente 40 a 150. O sistema é
`(N+3) x (N+3)`. Resolva por eliminação de Gauss com pivotamento parcial. Em
JavaScript puro isso é milissegundos e não precisa de biblioteca.

> **CORREÇÃO, aplicada no passo 5.** "Escalado pela média da diagonal de `A`"
> não funciona: para thin-plate spline a diagonal de `A` é `phi(0) = 0`, em toda
> entrada, por definição. A regra ao pé da letra zera `lambda` e o `smoothing`
> deixa de fazer efeito.
>
> O implementado escala pela média de `|A[i][j]|` **fora** da diagonal, que é a
> magnitude que o kernel de fato tem. Mantém a intenção — `lambda` significar a
> mesma coisa em qualquer escala de imagem — e o `smoothing` volta a ser um
> knob.
>
> Medido no `fixture-gradient.fit`: `smoothing 0` (que é o que a regra literal
> produziria sempre) dá resíduo máximo de 0,245 nível fora do objeto e absorve
> 8,49% do objeto. Com `smoothing 0,10` são 0,168 nível e 6,27%. A regra
> literal é a pior linha da tabela.

**Avaliação:** calcule a superfície numa grade de 1/8 da resolução e interpole
bilinearmente para a resolução cheia. Avaliar RBF em 8 milhões de pixels com 100
centros é 800 milhões de operações; na grade 1/8 são 12 milhões. A superfície é
suave por construção, então a interpolação não introduz erro visível — mas
**meça**: registre no record o erro máximo entre a grade interpolada e a avaliação
direta em 1000 pixels amostrados. Se passar de 0,5 nível de 255, aumente a grade.

Normalize as coordenadas para [0,1] antes de montar o sistema. Sem isso, o
condicionamento fica ruim em imagens grandes.

### 2.4 Correção, e o offset

```
subtract:  out = in - model + pedestal
divide:    out = in / model * pedestalMultiplicativo
```

**O pedestal não é opcional.** Subtrair o modelo sem devolver nada joga o fundo
para perto de zero, e a métrica alvo é fundo entre 13 e 25 de 255. Zero é
sombra cortada.

> **A FAIXA 13–25 DESCREVE OUTRA COISA — corrigido, com a origem.**
>
> Os 13–25 vêm das **entregas manuais**, onde o `target` era escolhido caso a
> caso entre 0,10 e 0,25 conforme o alvo: `0,10 × 255 = 25,5` e um alvo mais
> escuro desce a faixa. É a saída de um processo com alvo **variável**, decidido
> por quem processava, imagem a imagem.
>
> Esta ferramenta tem `target` **fixo em 0,25**, que é o padrão do Módulo 0, a
> convenção do PixInsight STF / Siril, e está conferido contra a segunda
> implementação. `0,25 × 255 = 63,75`, por definição e não por acidente. Medido
> nos quatro fixtures depois da correção: 63,8 / 63,9 / 64,2 / 67,2.
>
> As duas afirmações são compatíveis e descrevem saídas diferentes. Confundi-las
> teria custado caro na direção errada: a leitura "13–25 é a métrica, logo o
> pedestal está errado" levaria a mexer no pedestal, que está certo, para
> perseguir um número que pertence ao `target`.
>
> **O pedestal não decide esse número.** Ele preserva o nível *antes* do
> esticamento; o autostretch depois mapeia a mediana para o alvo dele, qualquer
> que fosse ela. Um pedestal errado não muda o 64 — ele degenera o esticamento
> por outro caminho (com fundo em zero, `midtones` cai fora de `(0,1)`, vira
> 0,5, e a transformação vira identidade: imagem preta).
>
> **A verificação certa do pedestal**, e é a que passou: a mediana de fundo
> *sobrevive à correção*. Antes e depois, em níveis de 255:
>
> | fixture | antes | depois |
> |---|---|---|
> | `seestar` | 3,12 2,79 2,51 | 3,12 2,78 2,50 |
> | `rice` | 4,35 3,96 3,64 | 4,32 3,93 3,61 |
> | `nonlinear` | 67,33 62,65 58,75 | 67,19 62,47 58,62 |
> | `gradient` | 4,70 4,26 3,86 | 4,71 4,27 3,89 |
>
> Deriva máxima 0,14 nível. O gradiente inteiro saiu e o nível ficou.
>
> **Decidir depois, e não aqui:** se 0,25 fixo é o alvo certo, ou se o `target`
> deveria voltar a variar como variava no processo manual, é questão do
> autostretch e não da extração de fundo. Mudar `target` muda a saída de todo
> mundo e reprova a referência do Python; é decisão do Módulo 0, com dado real,
> e não efeito colateral desta etapa.

`pedestal: 'model-median'` devolve a mediana do próprio modelo, por canal. Isso
preserva o nível de fundo e remove só a **variação** — que é o que gradiente
significa.

**Consequência de cor:** o pedestal por canal preserva a razão entre canais tal
como estava. Um pedestal único para os três canais mudaria o balanço. Fique com
por canal, e registre no record que o balanço foi preservado — isso é o que o
GraXpert não faz e é frase de log.

Negativos podem sobrar após a subtração em pixels de ruído abaixo do modelo.
**Não clampeie.** O contrato do `Image` já diz não clampeado, e o `quantise` final
resolve. Clampear aqui destrói a simetria do ruído e enviesa a mediana para cima.

### 2.5 O record

```js
{
  id: 'background',
  name: 'Background extraction',
  applied: true,
  params: { ...todos os efetivos, incluindo boxSize escalado... },
  samples: {
    generated: 144,
    accepted: 118,
    rejected: { bright: 21, edge: 4, clipped: 1, nan: 0 },
    forced: 0,
    moved: 0,
    boxSizeEffective: 25,
  },
  surface: {
    method: 'thin-plate-spline',
    lambda: 0.0034,
    gridDivisor: 8,
    maxInterpErrorLevels: 0.11,
    perChannel: [ { modelMin, modelMax, modelMedian, pedestal }, ... ]
  },
  before: { perChannel: [...] },
  after:  { perChannel: [...] },
  notes: [
    '118 de 144 amostras usadas; 26 rejeitadas por brilho, borda ou saturacao.',
    'Superficie thin-plate spline, suavizacao 0,10.',
    'Nivel de fundo preservado por canal; balanco de cor inalterado.',
  ]
}
```

O `samples.rejected` detalhado é o que permite ao usuário e ao log dizerem
**por quê**. Não colapse num total.

### 2.6 Dither no quantise

Subtrair uma superfície suave de dado quantizado produz banding. A cadeia é float,
então o problema só aparece no `quantise` final.

Adicione dither de ±0,5 nível no `quantise`, com **gerador determinístico de
semente fixa**. Determinismo importa por dois motivos: o golden precisa ser
reprodutível, e o argumento do produto é que nada é aleatório sem registro.

Registre no record do `quantise`: dither aplicado, amplitude, semente.

Torne desligável (`dither: false`), porque o comparador de não-regressão pode
querer desligar.

---

## 3. Módulo 1b — edição interativa

Só depois de 1a passar no harness.

### 3.1 Interações

| ação | resultado |
|---|---|
| arrastar um ponto | move; estado vira `moved`; recalcula ao soltar |
| clicar em área vazia | adiciona ponto ali |
| clicar num ponto rejeitado | força aceitação; estado vira `forced` |
| clicar num ponto forçado | volta a rejeitado |
| tecla Delete com ponto selecionado | remove de vez |
| botão direito | remove de vez |
| roda do mouse | zoom |
| arrastar fora de ponto | pan |

**Arrastar, não apagar e recolocar.** É o atrito principal do Siril.

### 3.2 Regerar preserva o manual

Mudar `samplesPerRow` regera a grade. Os pontos com estado `moved`, `forced` ou
adicionados à mão **sobrevivem**. Os automáticos são substituídos.

Um botão separado, "descartar ajustes manuais", faz a limpeza completa — explícito,
nunca como efeito colateral.

### 3.3 O que o usuário vê

Ponto desenhado como caixa do tamanho real da amostra, não como marcador de tamanho
fixo. O usuário precisa ver o que está sendo medido.

| estado | aparência |
|---|---|
| aceito | contorno fino, sólido |
| rejeitado | contorno tracejado, apagado |
| forçado | contorno sólido, marcado |
| movido | contorno sólido, com marca de canto |

Passar o mouse mostra: coordenada, mediana por canal, e o motivo se rejeitado.

**A cor não pode carregar a informação sozinha.** Traço, preenchimento e marca
fazem a distinção — parte dos astrofotógrafos tem daltonismo, e a imagem por baixo
já é colorida.

### 3.4 Três visualizações

Botões, não menu (confusão 08):

- **Original** — antes da correção
- **Fundo** — só o modelo, esticado. É como se vê sobreajuste: se a galáxia
  aparece no modelo, os pontos estão errados. O GraXpert tem isso e é a
  ferramenta de diagnóstico mais útil da etapa.
- **Corrigido** — o resultado

Todas as três com o autostretch por cima. Dado linear é quase preto; sem esticar,
o usuário não enxerga onde está a nebulosa e não tem como julgar ponto nenhum.

### 3.5 Avisos vão sobre a imagem

Nunca só no log (confusão 11). Ancorados no ponto do problema:

- menos de 8 pontos aceitos → a etapa não rodou, e diz isso
- mais de 40% rejeitados → provável objeto grande no quadro, sugerir baixar
  densidade ou aumentar tolerância
- todos os pontos de uma borda rejeitados → provável vinheta, sugerir divisão

Se um controle estiver desabilitado, ele diz por quê no próprio lugar
(confusão 10).

### 3.6 Custo de latência

O ajuste roda sempre no buffer de preview. Um `run` de preview no Módulo 0 custou
102 ms; a RBF acrescenta poucos milissegundos com 150 pontos. Arrastar um ponto e
ver o resultado tem que ficar abaixo de 150 ms, senão o usuário não itera — é o
ciclo lento do Siril.

Recalcule ao **soltar** o ponto, não durante o arraste.

---

## 4. Fixture novo

Nenhum fixture atual tem gradiente nem objeto, então a rejeição não é testável.

Estenda `make-fixture.ps1` para gerar `fixture-gradient.fit`:

- 1600×1200×3, float32
- fundo em ~0,015 com ruído gaussiano
- **gradiente conhecido**: plano inclinado mais um termo quadrático, com os
  coeficientes gravados em cards `HISTORY` — assim o teste compara o modelo
  ajustado contra a verdade, não contra si mesmo
- **objeto extenso** de brilho conhecido ocupando ~12% do quadro, para forçar
  rejeição (a fração do M31 no quadro do parceiro)
- **algumas estrelas** dentro de caixas de amostra, para testar que a mediana da
  caixa sobrevive a elas
- determinístico, como os outros três

Esse fixture é o único jeito de responder "o modelo ajustado é o gradiente que eu
coloquei?" em vez de "o modelo é o mesmo de ontem?".

---

## 5. Referência Python

`reference.py` precisa ganhar a etapa: mesma amostragem, mesma rejeição, mesma
RBF, em float64 e com `scipy.linalg.solve` em vez de eliminação própria.

O que a comparação valida: a montagem do sistema, a rejeição, a avaliação da
superfície e o pedestal. O que **não** valida: a escolha do kernel e do critério de
rejeição, que são compartilhados de propósito — mesma limitação já registrada no
Módulo 0.

O fixture com gradiente conhecido cobre parte dessa lacuna, porque a verdade está
nos cards `HISTORY` e não veio de nenhuma das duas implementações.

Tolerâncias: as mesmas da §7 do Módulo 0, mais uma nova para o modelo ajustado —
erro máximo do modelo contra o gradiente verdadeiro, em níveis de 255. Sugestão de
partida: 1 nível fora das regiões rejeitadas.

### A máscara do objeto para métrica é R ≤ 2,5, não R ≤ 1

**"Fora das regiões rejeitadas" precisa de um raio, e o raio óbvio está errado.**

O objeto é `I = PEAK·exp(−3R)` em raio elíptico. Em `R = 1,2` a intensidade
ainda é cerca de **1,6× o sigma do ruído** — sinal real, bem fora da elipse
`R ≤ 1` que define a extensão nominal. Uma máscara em `R ≤ 1` chama de "campo
limpo" uma região que ainda tem objeto dentro, e o erro do modelo acompanha o
objeto para fora.

Medido, canal R, máximo em níveis de 255:

| região | fração do quadro | erro |
|---|---|---|
| dentro, `R < 1` | 12,0% | 0,839 |
| halo próximo, `1 ≤ R < 1,5` | 14,0% | 0,616 |
| halo distante, `1,5 ≤ R < 2,5` | 24,8% | 0,311 |
| **campo limpo, `R ≥ 2,5`** | **49,2%** | **0,169** |

O ajuste erra **6× mais no halo próximo do que no campo limpo**, e uma métrica
com máscara em `R ≤ 1` põe esses 14% do quadro do lado de fora e reporta o erro
deles como se fosse acurácia do modelo.

**As quatro regiões são a métrica.** Duas não bastam: o número que importa para
acurácia é o do campo limpo, e o que importa para contaminação é o de dentro, e
entre os dois existe uma faixa de 38% do quadro que não é nenhum dos dois.

Isto **não muda a decisão da rejeição global** da §2.2 — muda o que a mede. O
resíduo do canto rejeitado continua igual ao do campo limpo.

> Achado por `reference_bg.py`, a segunda implementação. A primeira versão de
> `compare-truth.js` usava `R ≤ 1` e `R > 2`, e o anel entre os dois não entrava
> em conta nenhuma.

---

## 6. Ordem de execução

1. `compare-golden.ps1` ganha a tolerância da §7. Verificar contra os goldens
   atuais: tem que continuar passando.
2. Cadeia vira float pleno; `quantise` uma vez no fim. Goldens recapturados com
   tolerância. **Identidade byte a byte encerrada aqui.**
3. `fixture-gradient.fit` no gerador; golden capturado.
4. `steps/background.js`: amostragem, rejeição, record. Sem RBF ainda — a etapa
   devolve a imagem intacta e só reporta os pontos. Testável.
5. RBF e avaliação em grade. Comparar contra o gradiente verdadeiro do fixture.
   **E decidir a pendência da §2.2:** rejeição contra fundo local em vez de
   global. O caso que a motiva é a sonda em (1253, 1112) do
   `fixture-gradient.fit`, rejeitada por brilho sem objeto nenhum. Decidir aqui,
   e não antes, porque a estimativa local provavelmente sai da própria
   superfície — e antes do passo 5 não existe superfície de onde tirá-la.
6. Correção com pedestal, e dither no `quantise`.
7. `registry.js`: `background` passa a `applied: true`. A linha "Not applied"
   perde "background extraction" sozinha — verificar que perde.
8. `reference.py` ganha a etapa; `compare-reference.ps1` cobre os novos campos.
9. **1b:** canvas com zoom, pan, pontos desenhados, três visualizações.
10. **1b:** arrastar, adicionar, remover, forçar; regerar preservando manual.
11. **1b:** avisos sobre a imagem.

Passos 1 a 8 são o 1a e entregam valor sozinhos: automático com rejeição visível
já é melhor que o modo IA que come 12,5%, porque grade com sigma-clipping é o que
rendeu os 5%.

---

## 7. Restrições

- Continua sem dependência em runtime, sem rede, sem modelo treinado.
- Continua um `index.html` que abre por duplo clique.
- Nenhuma operação silenciosa: toda ação faz algo visível ou diz por que não pode.
- Nenhum controle desabilitado sem motivo escrito ao lado.
- Nada de janela modal que prenda o usuário.
- Dois controles visíveis por padrão (densidade e tolerância); o resto em
  "avançado" fechado.
- A cor nunca carrega informação sozinha.
- Cor de fundo preservada por canal; nunca um pedestal único para os três.
