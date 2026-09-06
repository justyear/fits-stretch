# Golden artifacts

Critério de aceitação: **a tolerância da §7 do Módulo 0**, aplicada por
`compare-golden.ps1`, que responde em duas partes e diz qual respondeu —
`PASS` quando os bytes são idênticos, `PASS~` quando diferem e toda diferença
cabe na tolerância, `FAIL` fora disso. O log continua exato, sem tolerância.

O critério anterior — PNG, log e records byte a byte, diagnóstico byte a byte
menos `timingsMs` — valeu enquanto a cadeia tinha uma etapa e o LUT era a
autoridade sobre o valor do pixel. Morreu no passo 2 do Módulo 1, por
construção e no prazo. Ver "O que o float pleno mudou", abaixo.

Capturados do build sha256
`54c003607bbc29f91686630597cdd91c9e3b8dd7e4a26904da7d0548dc80ad5a`
(147.173 bytes — pipeline em 13 arquivos, cadeia em float pleno, extração de
fundo aplicada, dither no quantise).

Navegador: Chromium 148 (`Chrome/148.0.7778.280`, in-app browser do Claude
Code). Isso ainda importa para o PNG, mas menos do que importava: o comparador
agora **decodifica** o PNG e compara pixels, então outro encoder com os mesmos
pixels passa. O que continua dependendo do Chromium é o sha256 da tabela
abaixo, não o veredito.

## Como reproduzir

```
powershell -File .claude\make-fixture.ps1        # se os fixtures não existirem
powershell -File .claude\serve.ps1 -Port 8791
```

Abrir `http://127.0.0.1:8791/`, colar `test/capture-golden.js` no console,
`await __captureAll()`. Os quatro artefatos por fixture caem em
`.claude/shots/`. Depois:

```
powershell -File test\compare-golden.ps1      # nao-regressao, com tolerancia
powershell -File test\compare-reference.ps1   # correção, contra o Python (ver nota)
powershell -File test\negative-controls.ps1   # a tolerância ainda reprova?
```

E, no mesmo console do navegador, colar `test/compare-truth.js` e
`await __compareTruth()` — compara o modelo de fundo ajustado contra o gradiente
que está gravado nos cards `HISTORY` do `fixture-gradient.fit` e escreve
`gradient-truth.json`. É a única verificação da suíte que não herda a fórmula
compartilhada; ver a seção "O modelo contra a verdade", abaixo.

`negative-controls.ps1` não precisa de captura nem de navegador: ele muta cópias
descartáveis dos próprios goldens e confere que o comparador chega ao veredito
certo em cada caso. Existe porque "controle negativo verificado" escrito numa
spec é uma afirmação que deixa de ser verdadeira no instante em que ninguém
consegue rodá-la de novo. São 23 casos, e dois importam mais que os outros. O
`madn +8e-6` reprova pela regra de `span` e passaria pela regra de [0,1], que
nessa magnitude é **21 vezes** mais frouxa — é o único caso capaz de distinguir
as duas. E o par `png every sample +1` contra `png one sample +1`: mesmo
veredito, mesma magnitude, mesmo limite, achados opostos. É o que prova que o
detector de deslocamento sistemático não dispara em arredondamento comum.

Os casos ancoram em valores concretos dos goldens e **têm que ser reancorados
quando os goldens mudam** — no passo 6 o `"clipLow": 266` deixou de existir
porque a correção eliminou o corte de sombra, e o script parou com a mensagem
dizendo qual padrão não achou. Falhar alto é o comportamento certo: um controle
negativo que se auto-desativasse em silêncio seria pior que não existir.

> **NOTA SOBRE `compare-reference.ps1`, a partir do passo 6.** O `reference.py`
> modela o decode e o autostretch, e **não** conhece a extração de fundo. Desde
> que a etapa passou a mexer em pixel, o bloco por canal compara dois quadros
> diferentes, e o comparador diz isso **uma vez** em vez de reprovar 63 números:
> `N/A — pipeline roda background e reference.py nao modela — passo 8 da §6`.
>
> O que sobra e continua valendo: **36 comparações, 33 PASS, todo o bloco de
> decode**, nos quatro fixtures. O que se perdeu: a verificação por segunda
> implementação de mediana, MAD, quartis, percentis, `shadows`, `midtones`,
> `scale` e contagens de clip. **Está fora do ar até o passo 8**, e isso é a
> dívida mais cara em aberto no projeto agora.
>
> É `N/A` e não `KNOWN` de propósito. A lista `KNOWN` é para divergências entre
> duas implementações que descrevem a mesma coisa; esta é as duas deixando de
> descrever a mesma coisa. Encher `KNOWN` com sessenta entradas transformaria um
> registro de dívida em papel de parede — §7 do Módulo 0, "KNOWN não é uma saída
> de emergência".

## O que o float pleno mudou, medido

O passo 2 do Módulo 1 tirou o LUT de 2^20 entradas do `stretch-mtf` e passou a
gravar MTF em precisão plena; `quantise` virou o único lugar onde um nível é
decidido. A tabela é a captura float comparada contra os goldens de 8 bits:

| artefato | veredito | o que aconteceu |
|---|---|---|
| `log.txt` × 3 | **PASS** byte a byte | todo número que o log imprime vem do `before` do record de stretch, que nenhuma etapa a jusante move |
| `diag.json` × 3 | **PASS** byte a byte | mesmo motivo: o painel também é construído do `before` |
| `png` × 3 | **PASS~** | 0,031% a 0,781% das amostras diferem, **todas por exatamente 1 nível** (média do \|d\| = 1,00) |
| `records.json` × 3 | **FAIL** | 23 a 24 campos, **todos em `after.perChannel[*]`**: median, mad, madn, span, q1, q3, p001, p999 |

Nenhum campo de `before` se moveu. Nenhuma contagem de clip se moveu —
`outLow` e `outHigh` contam os mesmos dois ramos sobre o mesmo `u`, e a mudança
não os alcança. Foi por isso que os goldens de log e diag sobreviveram: o que
mudou fica inteiramente a jusante da quantização que saiu.

**A identidade que a cadeia de 8 bits escondia.** No ramo não-linear o alvo do
autostretch é a própria mediana do canal, então `MTF` mapeia mediana em mediana
por construção e `after.median` deve ser igual a `before.median`. Na cadeia de
8 bits isso era invisível: a mediana pousava em 67/255 = 0,262745. Na cadeia
float ela pousa em 0,2640573739223316 — o mesmo dígito a dígito que
`before.median`, nos canais R e B; 3,05e-5 no G, que é resolução de histograma.
Isso é evidência independente de que o caminho novo está certo, e não apenas
diferente.

**Reprodutibilidade verificada.** Uma segunda captura independente, depois de
recarregar a página, devolveu os doze artefatos byte a byte idênticos aos
goldens promovidos. A tolerância existe para mudança de build, não para ruído
de rodada — não há ruído de rodada.

**Custo.** `transfer`, relógio de parede, uma amostra por fixture: 244→216,
233→268, 134→96 ms. `quantise` passou a aparecer separado, em 23 a 71 ms. Não é
medição — é uma amostra — e não há evidência de regressão que importe. O
orçamento real da §3.6 do Módulo 1 é o arraste sobre o buffer de preview, e é lá
que isso precisa ser medido de verdade quando a RBF entrar.

## Fixtures — todos sintéticos

**Nenhum arquivo de terceiro entra aqui.** Ver `CLAUDE.md`. Os quatro saem de
`.claude/make-fixture.ps1` com semente fixa e são reprodutíveis byte a byte —
verificado: regerar o `fixture-seestar.fit` devolve o mesmo sha256 do arquivo
versionado.

| nome | arquivo | bytes | sha256 |
|---|---|---|---|
| `seestar-fixture` | `test/fixtures/fixture-seestar.fit` | 4.150.080 | `6d0acf7bbd4ce595d926ccc9bbf8e239447cda8ed7207c682fe598f5534cb28b` |
| `rice-fixture` | `test/fixtures/fixture-rice.fit.fz` | 8.671.680 | ver `make-fixture.ps1` |
| `nonlinear-fixture` | `test/fixtures/fixture-nonlinear.fit` | 6.482.880 | ver `make-fixture.ps1` |
| `gradient-fixture` | `test/fixtures/fixture-gradient.fit` | 23.042.880 | `b14ac76614949a4feef20e1c9aa263b29813f7b2a7298f9b461388d482e1fc25` |

Quatro, e não um, porque cobrem caminhos disjuntos:

- **`seestar-fixture`** — 1920×1080, BITPIX 16, BZERO 32768, ROWORDER BOTTOM-UP,
  BAYERPAT GRBG. Leitura de inteiro, flip de linha, detecção de CFA, debayer,
  ramo linear. `view.factor` 1.
- **`rice-fixture`** — 2600×1000×3, RICE_1 com SUBTRACTIVE_DITHER_2, uma tile
  por linha (3.000 tiles). Descompressão Rice, dither, caminho de 3 planos sem
  debayer. A borda longa é 2600 **de propósito**: passa de `MAX_VIEW` (2560) por
  40 px, então `view.factor` = 2 e o PNG vem do buffer de resolução plena, que é
  o caminho que o botão de download realmente usa.

  Traz duas armadilhas embutidas de propósito: um patch 24×24 de zeros exatos,
  que exercita o sentinela `DITHER_ZERO` do dither 2 (aparece como 576 pixels
  pretos por canal no diagnóstico), e uma quantização com `ZZERO ≈ 13313,9`
  contra `ZSCALE = 6,2e-6`, que deixa os inteiros logo acima do piso do int32 —
  a configuração que obriga o unquantize a ficar em double.
- **`nonlinear-fixture`** — 900×600×3, float32 sem compressão, ROWORDER
  TOP-DOWN, com cards HISTORY de autostretch e mediana medida 0,2467. Ramo
  não-linear: ponto preto por percentil, alvo na própria mediana. O midtones do
  gerador foi calibrado para pousar a mediana em ~0,25, que é onde um frame
  realmente esticado no Siril fica — um valor mais agressivo levava a mediana
  para 0,73 e o fixture deixava de representar o caso.
- **`gradient-fixture`** — 1600×1200×3, float32, TOP-DOWN. Para o Módulo 1.
  Ver a seção própria abaixo: é o único da suíte cujo fundo é conhecido
  independentemente das duas implementações.

## `fixture-gradient.fit` — o único com uma verdade externa

Os outros três respondem "hoje é igual a ontem?" e "as duas implementações
concordam?". Nenhuma das duas perguntas alcança um erro de fórmula, porque a
referência do Python leu a fórmula daqui — está registrado na §7 do Módulo 0 e
na §5 do Módulo 1. Este responde a uma terceira: **o modelo ajustado é o
gradiente que eu coloquei?**

O que está gravado em cards `HISTORY`, e é lido de volta pelo teste:

```
g(u,v) = A0 + A1*u + A2*v + A3*u^2 + A4*v^2 + A5*u*v
u = x/(NAXIS1-1)   v = y/(NAXIS2-1)   TOP-DOWN, então v=0 é a primeira linha
```

com os seis coeficientes por canal, mais a geometria do objeto estendido
(`CX CY A B PEAK K`, perfil `I = PEAK*exp(-K*R)` em raio elíptico), as posições
das estrelas-sonda, o sigma do ruído e as sementes. 21 cards. O gerador escreve
os cards **das mesmas variáveis** que passa ao construtor da cena, então não há
dois lugares onde o número possa divergir.

**Por que TOP-DOWN:** o flip de linha já está coberto pelo `seestar-fixture`.
Aqui a clareza do contrato vale mais — com TOP-DOWN as coordenadas do `HISTORY`
são as coordenadas da imagem, sem inversão no meio da comparação.

**Por que 1600×1200:** não é número redondo. Com `samplesPerRow` 12 a grade é
12×9, e com `PREVIEW_EDGE` 1024 o fator de preview é 2 — então o fixture
exercita o escalonamento de `boxSize` da §2.1, que é a exigência de que uma
caixa de amostra signifique o mesmo pedaço de céu no preview e no render.

**Por que ruído gaussiano, e não uniforme como nos outros:** a rejeição é
`mediana da caixa > mediana global + tolerance × MADN`, e MADN só significa
"sigma" para ruído gaussiano. Com ruído uniforme o limiar de rejeição cairia num
lugar sem interpretação e o fixture estaria testando outra coisa.

### Medido no fixture gerado, com os parâmetros padrão da §2.2

Grade 12×9 = 108 amostras, caixa 25 px, margem 24 px, `tolerance` 1,0:

| | |
|---|---|
| aceitas | 93 |
| rejeitadas por brilho | 15, das quais **12 sobre o objeto** |
| rejeitadas por borda | 0 |
| fração rejeitada | 13,9% |

Fica bem acima da salvaguarda de 8 pontos e bem abaixo dos 40% que a §3.5 manda
avisar. O objeto força rejeição, que é para o que ele existe.

**Resíduo |mediana da caixa − verdade| nas aceitas: máximo 0,242 nível de 255,
médio 0,030.** A §5 sugere 1 nível como tolerância de partida para o modelo
ajustado contra o gradiente verdadeiro; a amostragem sozinha já entrega um
quarto disso, então o orçamento sobra para a RBF.

### A mediana sobrevive à estrela; a média não

Oito estrelas-sonda em posições gravadas, `PEAK` 0,45 e `sigma` 2,2. O sigma é
pequeno de propósito: numa caixa de 625 pixels a estrela levanta cerca de 22%
deles, confortavelmente abaixo de metade. Um sigma maior viraria a mediana
também e o fixture passaria a argumentar o contrário do que a §2.1 afirma.

Nas caixas que contêm uma sonda, canal G, em níveis de 255:

| desvio da mediana | desvio da média |
|---|---|
| 0,08 a 0,30 | **5,1 a 5,8** |

Cerca de **20× pior para a média**. É a §2.1 deixando de ser asserção e virando
número.

### Duas coisas que o fixture expõe de graça

**A fraqueza da tolerância global.** Uma das oito caixas-sonda, em (1253, 1112),
é rejeitada por brilho — e ali não há objeto nenhum, só fundo mais uma estrela.
No canto claro do gradiente o próprio fundo já passa de
`mediana global + 1,0 × MADN`. É exatamente a queixa registrada contra o Siril
na §1 ("tolerância global única para a imagem inteira"), reproduzida num arquivo
onde dá para medir. Não é defeito do fixture: é o defeito que o Módulo 1b
promete resolver, disponível para teste antes de a solução existir.

**Custo em disco, e a decisão sobre ele.** 23,0 MB, contra 19,3 MB dos outros
três somados; a árvore de fixtures passa a 42,3 MB.

**Fica assim: 1600×1200, sem compressão. Decidido, não pendente.**

Encolher o quadro perde o que ele testa — a grade 12×9 e o fator de preview 2
são os dois motivos de ele ter esse tamanho. E comprimir para `.fz` misturaria o
caminho Rice com o caminho do gradiente: uma falha neste fixture passaria a ter
duas explicações possíveis, e separar as duas custaria mais do que os 23 MB
valem. O `fixture-rice.fit.fz` existe para exercitar o Rice; este existe para
exercitar o gradiente. Um fixture, uma pergunta.

## Artefatos

| arquivo | bytes | sha256 |
|---|---|---|
| `seestar-fixture.log.txt` | 2.332 | `5f40ca462cca18bca67cb58a530e9f742b9e48b687c92c6604ffb348bb4a9862` |
| `seestar-fixture.diag.json` | 4.283 | `4cf141ca6af4ce0478a430702219b93e4bd2639aa282ada6a6ff4f791d3d1152` |
| `seestar-fixture.records.json` | 32.882 | `4a181beb31401881f356c1b56ca6eae45d08057b0b0f60324b77d07445e8d65d` |
| `seestar-fixture.png` | 5.679.044 | `dd7331c3745881609eed53c33a5a3a42340bfda686f9cd8e3b737245e3400996` |
| `rice-fixture.log.txt` | 2.487 | `8f22891637361c099ced36902bbfec58f010df84d2cac901284362d6f87e4e16` |
| `rice-fixture.diag.json` | 4.722 | `ad87d86525ae64e4ad454490410bb0ba57ed70227bad4ed81fd45583e8f596c8` |
| `rice-fixture.records.json` | 26.399 | `d751ad14f2c969e1303fc05d09ad3a6ebc2d601e16efd817e4b455252fba1265` |
| `rice-fixture.png` | 7.277.474 | `91f8fe3da9f6a55726716381e4d67c0babfc67937974be4d9f95f2349d4ca2ea` |
| `nonlinear-fixture.log.txt` | 2.357 | `df7fdedb9c5a56c6e1200405a2db8e735f9013c4362761403acb24eb3dcfb9be` |
| `nonlinear-fixture.diag.json` | 3.631 | `4dac24395b085242893ef026171679aecf05b7409db3e89a6d30d9d214f3ada9` |
| `nonlinear-fixture.records.json` | 35.345 | `2e3eea800822f960ace9c2bde248fe0f77b4d35619a29a01a86a63f7644bb3bd` |
| `nonlinear-fixture.png` | 1.638.531 | `827020c9d40136612d5db1c2bbb391df553b2083fafb027928dac240c9d01adb` |
| `gradient-fixture.log.txt` | 2.104 | `e1fb7808ff0f17d48995b8a494a83cf9bb833988528c79499b2f1da1f3175f00` |
| `gradient-fixture.diag.json` | 6.219 | `1860973f33824d621b3ce797ca3cd3f0e9b1c1b5a32fb0b583abf644004a625f` |
| `gradient-fixture.records.json` | 39.151 | `45c30ab8548b0235b50b3981407b062246897df3a9a3aa6553b867958bc3a972` |
| `gradient-fixture.png` | 5.530.241 | `9815296a1f323521887423d8bbb744a39920e9caabc6bce37f3ffc9e4eb3afe0` |
| `gradient-truth.json` | 4.144 | `dd5d2351e46eec9e80ccecf4afe6e47fd577ae7326ad83e034f21db57b99fe93` |

Os PNG cresceram entre 15% e 24%: o dither substitui bandas lisas por ruído, e
ruído não comprime. É o custo direto de não ter bandas.

`gradient-truth.json` é o único destes que `compare-golden.ps1` **não** compara:
ele vem de `compare-truth.js`, não da captura, e é medida de referência e não
artefato de saída. Comparar automaticamente entra junto com o passo 8, quando o
`reference.py` conhecer o fixture.

### O que o passo 4 mudou nestes goldens, medido

A etapa de fundo entrou na cadeia amostrando e rejeitando, sem ajustar
superfície e sem tocar em pixel. Contra os goldens do passo 3:

| artefato | veredito |
|---|---|
| `log.txt` × 4 | **PASS** byte a byte |
| `diag.json` × 4 | **PASS** byte a byte |
| `png` × 4 | **PASS** byte a byte |
| `records.json` × 4 | **FAIL**, `length 1 vs 2` |

O PNG idêntico é a verificação de que a etapa devolve a imagem intacta: se um
pixel tivesse se movido, ele apareceria. O log idêntico é a verificação de que
"background extraction" continua na frase "Not applied" — `applied: false`, e
`notAppliedLabels` chaveia nisso. E o `records.json` reprova por **mudança
estrutural**, não por deriva numérica: a cadeia ganhou um record, e nenhuma
tolerância deve perdoar isso.

Os `records.json` cresceram de ~3,8 KB para 22–35 KB. É a lista de pontos: cada
amostra com coordenada, estado, mediana por canal e a frase que diz por que foi
rejeitada. A §2.2 pede que o motivo esteja no record e não só no tooltip, e um
ponto rejeitado que some do registro é a operação silenciosa que a confusão 21
proíbe. 117 KB somados, contra 16,5 MB de PNG nos mesmos goldens.

## O modelo contra a verdade — passo 5

`test/compare-truth.js` roda no navegador, ajusta a superfície com o código
entregue e compara contra os coeficientes do gradiente lidos de volta dos cards
`HISTORY`. O relatório fica em `test/golden/gradient-truth.json`.

Isto é o que `compare-golden` e `compare-reference` não conseguem responder. Um
pergunta se hoje é igual a ontem; o outro se as duas implementações concordam —
e elas concordam sobre uma fórmula que foi lida deste código. Um erro de fórmula
é invisível para os dois. Aqui a resposta vem de números que o gerador escreveu
e que nenhuma das duas implementações viu.

### Resíduo `|modelo − gradiente verdadeiro|`, em níveis de 255

| região | máximo | médio |
|---|---|---|
| fora do objeto (raio elíptico > 2) | **0,168** | 0,031 |
| no canto que a rejeição global descarta | **0,168** | 0,067 |
| sob o objeto (raio ≤ 1) | 0,840 | 0,649 |

A §5 do Módulo 1 sugere 1 nível como tolerância de partida fora das regiões
rejeitadas. O medido é **0,168** — seis vezes dentro.

O resíduo sob o objeto **não é erro**: ali o esperado é o gradiente sozinho,
porque o objeto é sinal a preservar e não fundo a remover. O número mede
**contaminação** — quanto do objeto vazou para o modelo e seria subtraído dele
no passo 6.

### Contaminação, e o que a rejeição compra

O pico do objeto vale 13,39 níveis. O modelo absorve 0,840 → **6,27%**.

| `tolerance` | aceitas | contaminação | resíduo fora do objeto |
|---|---|---|---|
| 10 (sem rejeição) | 108 | **38,9%** | 0,267 |
| 2,0 | 101 | 10,96% | 0,148 |
| **1,0 (padrão)** | **93** | **6,27%** | **0,168** |
| 0,5 | 72 | 5,43% | 0,170 |
| 0,25 | 62 | 4,27% | 0,216 |
| 0,0 | 54 | 4,35% | 0,333 |

**A rejeição vale um fator de 6.** Sem ela o modelo come 38,9% do objeto — três
vezes pior que os 12,5% que o GraXpert perdeu num braço do M31 (§1). Com ela,
6,27%, entre os 12,5% do modo IA e os 5% do ajuste manual.

Apertar além de 1,0 rende pouco e cobra: a contaminação para de melhorar perto
de 4% enquanto o resíduo fora do objeto piora de 0,168 para 0,333. O padrão 1,0
está perto do joelho da curva, e agora isso é medida e não escolha.

### Erro da interpolação — medido, não presumido

A §2.3 manda avaliar numa grade de 1/8 e interpolar, e **medir** o erro contra
avaliação direta em 1000 pixels, aumentando a grade se passar de 0,5 nível.

| fixture | grade | erro máximo |
|---|---|---|
| `seestar` | 241×136 | 0,0001 |
| `rice` | 326×126 | 0,0000 |
| `nonlinear` | 114×76 | 0,0039 |
| `gradient` | 201×151 | 0,0004 |

Duas ordens de grandeza dentro do limite no pior caso. O divisor nunca precisou
aumentar — mas isso é resultado, não premissa, e é remedido a cada execução.

Os 1000 pixels são varridos por passo primo (104729) sobre o índice, que é
ímpar e portanto coprimo com qualquer potência de dois: sondas consecutivas
caem em fases diferentes dentro da célula da grade, que é onde o erro vive. Um
passo que compartilhasse fator com o divisor amostraria os cantos das células e
reportaria zero.

## Passo 6 — a correção, e o que medi-la encontrou

A correção é `out = in − model + pedestal`, com o pedestal sendo a mediana do
próprio modelo, **por canal**. A partir daqui a etapa reporta `applied: true`.

### A razão entre canais sobrevive — e o número que sustenta a frase de log

Medido no `fixture-rice`, mediana de fundo antes e depois da correção:

| | antes | depois | deriva |
|---|---|---|---|
| R/G | 1,099312 | 1,099010 | **−0,028%** |
| B/G | 0,920354 | 0,919802 | **−0,060%** |

E o contrafactual, aritmeticamente, se o pedestal fosse **único** (a média dos
três) em vez de por canal:

| | resultado | deriva |
|---|---|---|
| R/G | 0,999904 | **−9,04%** |
| B/G | 0,999918 | **+8,64%** |

O pedestal único colapsa as duas razões para 1,0: ele **lava a cor do fundo**.
Por canal preserva ~150× melhor. Nos quatro fixtures a deriva por canal fica
entre 0,016% e 0,44%; a de pedestal único, entre 6,6% e 11,2%.

É este o número por trás da frase *"the ratio between channels is therefore
unchanged: no colour grading"*, que agora está no log.

### Negativos, e por que a contagem zero aqui não é clamp

A regra é não clampear, e o teste natural — "se não sobrou negativo, algo
clampeou" — dá **falso alarme nestes fixtures**. Medido no `fixture-gradient`,
canal R:

| | mínimo | negativos |
|---|---|---|
| entrada | 0,007542 | 0 |
| corrigido, pedestal real | **0,012405** | 0 |
| corrigido, pedestal forçado a 0 | **−0,005950** | 882.624 (46%) |

O sinal de clamp não é a contagem, é **o mínimo pousar exatamente em zero**. Ele
pousa em 0,0124, longe de zero, e com o pedestal zerado os 882 mil negativos
atravessam intactos. Nada clampeia.

A contagem zero é aritmética: o pedestal (0,0184) é maior que a excursão do
modelo acima da própria mediana (~0,0064), então `in − model + pedestal` não
alcança zero. **Lacuna de cobertura:** nenhum fixture tem gradiente forte o
bastante em relação ao nível de fundo para produzir negativos no caminho normal.
Dado real com poluição luminosa forte produz.

### O dither é determinístico

Duas capturas independentes, cada uma depois de recarregar a página: os quatro
PNG **byte a byte idênticos**. Semente 20260906, amplitude ±0,5 nível, ambas no
record do `quantise` e no log.

### O bug que a correção expôs: o stretch media o quadro errado

`stepStretchMTF` recebia a medição tirada **antes** da etapa de fundo. Enquanto
a etapa só amostrava isso era inofensivo — as duas mediam os mesmos pixels — e
virou errado no instante em que um pixel se moveu.

O MADN é a parte que importa, porque o ponto preto é `mediana − 2,8 × MADN`, e o
gradiente removido fazia parte da dispersão que o MADN media:

| fixture | MADN antes | MADN depois | fator |
|---|---|---|---|
| `seestar` | 0,000939 | 0,000211 | **4,5×** |
| `rice` | 0,001868 | 0,000364 | **5,1×** |
| `nonlinear` | 0,019943 | 0,005833 | **3,4×** |
| `gradient` | 0,003549 | 0,001395 | **2,5×** |

O ponto preto estava de 2,5 a 5 vezes fundo demais, em todo quadro.

**E era invisível na métrica de saída:** a mediana pós-esticamento fica em ~64
de qualquer jeito, porque o MTF mapeia mediana no alvo seja qual for o MADN. É a
mesma classe do erro do λ — não falha, não avisa, e fica pior para sempre. O
`before` do stretch passa a vir do `after` da etapa de fundo, que já estava
medido e custava zero.

## Passo 7 — a frase "Not applied", verificada nos dois sentidos

O passo 7 era verificação, e o que havia a verificar já tinha acontecido
sozinho: a frase perdeu "background extraction" no passo 6, **com zero edições
em `registry.js`** — o arquivo não é tocado desde o passo 5 do Módulo 0.

Verificar que o rótulo sumiu é fraco: uma string apagada também some. A prova é
o **round-trip**, e ela passa pelo `buildLog` real:

| `background.applied` | descreve a etapa | nega a etapa |
|---|---|---|
| `true` | **1 linha** | ausente da frase |
| `false` | 0 linhas | **presente na frase** |

Os dois se movem juntos e em direções opostas. O invariante não é "o rótulo
some", é **o log ou descreve a operação ou a nega, nunca nenhum dos dois e nunca
os dois**. Foi essa a segunda metade que o passo 6 quase deixou aberta: a frase
parou de negar antes de alguém escrever a que afirma.

Com `applied: false`, a frase volta **idêntica** à de antes do Módulo 1 —
comparada contra o resultado de `notAppliedLabels` sem nenhum record de fundo.

E o guarda do catálogo continua vivo: um passo declarado `neverImplemented`
reportando que rodou faz `notAppliedLabels` recusar produzir log, em vez de
produzir um que negue o que acabou de acontecer. Verificado com `id: 'ai'`.

### Amostragem, por fixture

| fixture | quadro | grade | caixa | geradas | aceitas | brilho | borda |
|---|---|---|---|---|---|---|---|
| `seestar` | 1920×1080 | 12×7 | 25 | 84 | 72 | 12 | 0 |
| `rice` | 2600×1000 | 12×5 | 25 | 60 | 53 | 7 | 0 |
| `nonlinear` | 900×600 | 12×8 | 25 | 96 | 85 | 11 | 0 |
| `gradient` | 1600×1200 | 12×9 | 25 | 108 | 93 | 15 | 0 |

Os quatro reportam `applied: false` com o mesmo `skipReason`: *sampling only*.

**Verificação cruzada do `gradient`:** 93/15/0/0 é exatamente o que a análise
independente em PowerShell tinha medido no fixture, e ela usou mediana e MAD por
**seleção exata** enquanto a etapa usa **histograma de 65536 bins**. Dois
estimadores diferentes do limiar, 108 vereditos idênticos.

**Preview contra render, medido:** com o buffer reduzido a 800×600 e `boxSize`
escalado de 25 para 13, os 108 pontos recebem a **mesma classificação** e a
maior diferença de mediana de caixa é **0,0185 nível de 255**. É a afirmação da
§2.1 sobre correspondência preview/render, com número.

O `.diag.json` é `JSON.stringify(state.diag, null, 2)` — o objeto cru, não o
`dump()` do painel, que arredonda para 8 dígitos significativos. Guardar o cru
significa que uma regressão de ponto flutuante aparece em vez de ser arredondada
para fora. (Os sha256 do diag mudam a cada captura por causa de `timingsMs`; os
da tabela são do arquivo versionado.)

## O que não é estável, e o que deixou de não ser

**`timingsMs`** no diagnóstico continua sendo relógio de parede.
`compare-golden.ps1` recorta o bloco dos dois lados antes de comparar. É a única
coisa que ele ignora inteiramente, em vez de comparar com tolerância.

Nota de arqueologia: os goldens anteriores foram capturados de um build de 10
arquivos cujo `timingsMs` não tinha `preview` nem `quantise`. Eles continuaram
válidos através de todos os refactors do Módulo 0 porque aqueles refactors foram
neutros nos artefatos comparados, e as duas chaves novas caíram dentro do único
bloco que o comparador recorta. O sha256 de build que este arquivo registrava
estava desatualizado desde o passo 7 do Módulo 0; está corrigido acima.

**A data no log** era o outro relógio, e não é mais. `runPipeline(buffer,
fileName, post, opts)` recebe `opts.now`, que cai em `new Date()` quando
ausente. O navegador segue imprimindo o dia de hoje; a captura fixa
`__GOLDEN_DATE = '2026-09-05'`. Estes goldens não expiram. Não mude
`__GOLDEN_DATE`: invalida todos os logs guardados e não compra nada.

## Cobertura que ainda falta

Nenhum fixture cobre **`.fz` que ainda seja mosaico CFA** — descompressão e
debayer estão cobertos em separado, nunca combinados. O gerador consegue
produzir isso (é o caminho int16 + BAYERPAT dentro do escritor Rice); ninguém
escreveu ainda.

**FECHADO — gradiente e objeto extenso.** Era o passo 3 da §6 do Módulo 1 e
existe: `fixture-gradient.fit`, seção própria acima.

O que ainda falta em volta dele: o `reference.py` não conhece este fixture, então
`compare-reference.ps1` continua em 116 linhas e não o cobre. É o passo 8 da §6,
e até lá o gradiente é verificável contra os cards `HISTORY` mas não contra uma
segunda implementação.
