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
`dde0e8b7ca3556c57b90546436f2c21992370777f6b44e2eda4a3908d3be650f`
(123.320 bytes — pipeline em 13 arquivos, cadeia em float pleno, amostragem de
fundo na cadeia).

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
powershell -File test\compare-reference.ps1   # correção, contra o Python
powershell -File test\negative-controls.ps1   # a tolerância ainda reprova?
```

O terceiro não precisa de captura nem de navegador: ele muta cópias
descartáveis dos próprios goldens e confere que o comparador chega ao veredito
certo em cada caso. Existe porque "controle negativo verificado" escrito numa
spec é uma afirmação que deixa de ser verdadeira no instante em que ninguém
consegue rodá-la de novo. São 23 casos, e dois importam mais que os outros. O
`madn +2e-5`:
ele reprova pela regra de `span` e passaria pela regra de [0,1], que nessa
magnitude é seis vezes mais frouxa — é o único caso capaz de distinguir as duas.
E o par `png every sample +1` contra `png one sample +1`: mesmo veredito, mesma
magnitude, mesmo limite, achados opostos. É o que prova que o detector de
deslocamento sistemático não dispara em arredondamento comum.

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
| `seestar-fixture.log.txt` | 1.609 | `9e8c6311cf06c888e8c2357cccf780060bc6765d5043757f8a893f68c3175869` |
| `seestar-fixture.diag.json` | 4.273 | `5c498ca243706bcdfff1af9c9f8c9d28ead58c72f1977363df858eaf8a80b204` |
| `seestar-fixture.records.json` | 28.658 | `0eccfca99f12b164d51502fffe8ee68d0d63df7cb2b70350c69c34e02e3d1454` |
| `seestar-fixture.png` | 4.546.701 | `6287a0b25b937c3b5cb309cc9a9df130136e3e6dbda7fb0e987f54a6c28162a5` |
| `rice-fixture.log.txt` | 1.765 | `6337bfc4a2f5b73645798896ae5668e7c1e8e94c03908dd2734e9490efd7fc4f` |
| `rice-fixture.diag.json` | 4.708 | `15663b67284a4b3c591ea2b99eefb3b4b1cbd5d0c2b923d1bc27562479a67bbb` |
| `rice-fixture.records.json` | 22.154 | `6465260e959a2533ab034a45f77579a7e302d8adfe5ca70bb8e2aedca0b2eb6f` |
| `rice-fixture.png` | 5.862.158 | `2af37579df49ff18becf49a0f2b5917230fe3298310321f943800e28a19be65d` |
| `nonlinear-fixture.log.txt` | 1.634 | `f4b8c6e22a629ba8ddb825da0f6fe557908f11242261d7cfe3bb38c29c61847e` |
| `nonlinear-fixture.diag.json` | 3.626 | `930192758594769478df7a6c0ee4ea27f48ee5ed9cc233194926e673f973c6f1` |
| `nonlinear-fixture.records.json` | 31.186 | `b5c3fb0e8f9ba00d34b8bc4fd36dba92cdb73c357140df8e6dcfda561c68e290` |
| `nonlinear-fixture.png` | 1.340.894 | `3003c8f9ccb75042fb430b9772825ae5fbb2d0aafefc17761cdd71cc37de04ec` |
| `gradient-fixture.log.txt` | 1.380 | `3a3c952b8ff1e2b3f2a090964316a3c846987c538beef96fe0bb3c63303aad78` |
| `gradient-fixture.diag.json` | 6.210 | `4d0217e69affe6bea836e68df8e9d6b668fd23b4867d9a1ce5efee2a0817e3cb` |
| `gradient-fixture.records.json` | 34.994 | `b755b4f2e4f59d060d7d31b830d5e09320534ed9cc5475f022f89c16a5bfdbd9` |
| `gradient-fixture.png` | 4.814.737 | `45f6a1a2e0b32dcd78d906c728e379d1933f954d9fe09347cf72a68e120579a9` |

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
