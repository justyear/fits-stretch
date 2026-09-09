# Golden artifacts

CritÃ©rio de aceitaÃ§Ã£o: **a tolerÃ¢ncia da Â§7 do MÃ³dulo 0**, aplicada por
`compare-golden.ps1`, que responde em duas partes e diz qual respondeu â€”
`PASS` quando os bytes sÃ£o idÃªnticos, `PASS~` quando diferem e toda diferenÃ§a
cabe na tolerÃ¢ncia, `FAIL` fora disso. O log continua exato, sem tolerÃ¢ncia.

O critÃ©rio anterior â€” PNG, log e records byte a byte, diagnÃ³stico byte a byte
menos `timingsMs` â€” valeu enquanto a cadeia tinha uma etapa e o LUT era a
autoridade sobre o valor do pixel. Morreu no passo 2 do MÃ³dulo 1, por
construÃ§Ã£o e no prazo. Ver "O que o float pleno mudou", abaixo.

Os goldens abaixo foram capturados de `.claude/index-test.html`, o build **com
ganchos**. O publicado Ã© `index.html` e difere dele apenas pelo bloco de
ganchos. Os dois:

<!--BUILD_HASHES-->

| arquivo | bytes | sha256 |
|---|---|---|
| `index.html` | 210946 | `852c349e150608fd3f38d4da0fdccad58fb41f9d217725d00939a49937101ee5` |
| `.claude/index-test.html` | 212639 | `f3e5ec1160591d9b3723c24379400522193feb8fd5eef32beb88484c899cba28` |

<!--/BUILD_HASHES-->

**Esta tabela Ã© verificada por `build.ps1 -Check`**, que a lÃª entre os dois
marcadores acima e compara com o build que acabou de montar. Ela existe para
quem quer conferir o download sem rodar o build; ser escrita Ã  mÃ£o Ã© o motivo
pelo qual precisa ser verificada, nÃ£o uma licenÃ§a para nÃ£o ser.

Precisou existir: os nÃºmeros daqui ficaram desatualizados desde `741f0e1` â€” a
correÃ§Ã£o do pedestal mudou `background.js`, logo mudou o build â€” e ninguÃ©m
percebeu, porque nenhum comparador os lia. Ã‰ a forma invertida do argumento que
o prÃ³prio log usa: a frase do log nÃ£o envelhece porque Ã© gerada; estes nÃºmeros
envelhecem porque nÃ£o sÃ£o. O conserto nÃ£o Ã© gerÃ¡-los, Ã© medi-los.

Navegador: Chromium 148 (`Chrome/148.0.7778.280`, in-app browser do Claude
Code). Isso ainda importa para o PNG, mas menos do que importava: o comparador
agora **decodifica** o PNG e compara pixels, entÃ£o outro encoder com os mesmos
pixels passa. O que continua dependendo do Chromium Ã© o sha256 da tabela
abaixo, nÃ£o o veredito.

### Abre por duplo clique â€” os quatro caminhos, e como cada um foi verificado

| navegador | protocolo | caminho | como |
|---|---|---|---|
| Firefox 155 | `file://` | worker | automatizado |
| Chrome 151 | `file://` | inline | automatizado |
| Chrome 148 | `http://` | worker | automatizado, a sessÃ£o inteira |
| **Chrome** | **`file://`** | **worker** | **manual, 2026-09-07** |

O Ãºltimo foi verificado Ã  mÃ£o porque nÃ£o Ã© automatizÃ¡vel aqui: o headless do
Chrome com `--virtual-time-budget` nÃ£o avanÃ§a os timers de dentro de um Worker,
entÃ£o a mediÃ§Ã£o automÃ¡tica diz "nÃ£o completou" mesmo quando a pÃ¡gina funciona.
EstÃ¡ registrado no `NOTAS` como o caso que gerou a regra do controle positivo.

**Verificado manualmente em 2026-09-07:** `index.html` aberto por duplo clique
no Chrome, arquivo solto na pÃ¡gina, processou. Nos quatro caminhos, nenhuma
requisiÃ§Ã£o externa.

## Como reproduzir

```
powershell -File .claude\make-fixture.ps1        # se os fixtures nÃ£o existirem
powershell -File .claude\serve.ps1 -Port 8791
```

Abrir **`http://127.0.0.1:8791/test.html`** â€” e nÃ£o a raiz. A raiz serve o
`index.html` publicado, que **nÃ£o tem** `__loadFromURL`: os ganchos de teste
saem do arquivo que as pessoas baixam, e `/test.html` serve o
`.claude/index-test.html`, que Ã© o mesmo build com o bloco de ganchos. Os dois
saem do mesmo `template.html` e `build.ps1 -Check` valida os dois, entÃ£o nÃ£o
podem divergir em nada alÃ©m daquele bloco.

Colar `test/capture-golden.js` no console e `await __captureAll()`. Os quatro
artefatos por fixture caem em `.claude/shots/`. Depois:

```
powershell -File test\compare-golden.ps1      # nao-regressao, com tolerancia
powershell -File test\compare-reference.ps1   # correÃ§Ã£o, contra o Python (ver nota)
powershell -File test\negative-controls.ps1   # a tolerÃ¢ncia ainda reprova?
```

E, no mesmo console do navegador, colar `test/compare-truth.js` e
`await __compareTruth()` â€” compara o modelo de fundo ajustado contra o gradiente
que estÃ¡ gravado nos cards `HISTORY` do `fixture-gradient.fit` e escreve
`gradient-truth.json`. Ã‰ a Ãºnica verificaÃ§Ã£o da suÃ­te que nÃ£o herda a fÃ³rmula
compartilhada; ver a seÃ§Ã£o "O modelo contra a verdade", abaixo.

`negative-controls.ps1` nÃ£o precisa de captura nem de navegador: ele muta cÃ³pias
descartÃ¡veis dos prÃ³prios goldens e confere que o comparador chega ao veredito
certo em cada caso. Existe porque "controle negativo verificado" escrito numa
spec Ã© uma afirmaÃ§Ã£o que deixa de ser verdadeira no instante em que ninguÃ©m
consegue rodÃ¡-la de novo. SÃ£o 26 casos, e dois importam mais que os outros. O
`madn +8e-6` reprova pela regra de `span` e passaria pela regra de [0,1], que
nessa magnitude Ã© **21 vezes** mais frouxa â€” Ã© o Ãºnico caso capaz de distinguir
as duas. E o par `png every sample +1` contra `png one sample +1`: mesmo
veredito, mesma magnitude, mesmo limite, achados opostos. Ã‰ o que prova que o
detector de deslocamento sistemÃ¡tico nÃ£o dispara em arredondamento comum.

Os casos ancoram em valores concretos dos goldens e **tÃªm que ser reancorados
quando os goldens mudam** â€” no passo 6 o `"clipLow": 266` deixou de existir
porque a correÃ§Ã£o eliminou o corte de sombra, e o script parou com a mensagem
dizendo qual padrÃ£o nÃ£o achou. Falhar alto Ã© o comportamento certo: um controle
negativo que se auto-desativasse em silÃªncio seria pior que nÃ£o existir.

> **NOTA SOBRE `compare-reference.ps1`, a partir do passo 6.** O `reference.py`
> modela o decode e o autostretch, e **nÃ£o** conhece a extraÃ§Ã£o de fundo. Desde
> que a etapa passou a mexer em pixel, o bloco por canal compara dois quadros
> diferentes, e o comparador diz isso **uma vez** em vez de reprovar 63 nÃºmeros:
> `N/A â€” pipeline roda background e reference.py nao modela â€” passo 8 da Â§6`.
>
> O que sobra do MÃ³dulo 0: **todo o bloco de decode**, nos quatro fixtures.
>
> Ã‰ `N/A` e nÃ£o `KNOWN` de propÃ³sito. A lista `KNOWN` Ã© para divergÃªncias entre
> duas implementaÃ§Ãµes que descrevem a mesma coisa; esta Ã© as duas deixando de
> descrever a mesma coisa. Encher `KNOWN` com sessenta entradas transformaria um
> registro de dÃ­vida em papel de parede â€” Â§7 do MÃ³dulo 0, "KNOWN nÃ£o Ã© uma saÃ­da
> de emergÃªncia".
>
> **`referencia-cadeia.json` reabriu o bloco.** Ele monta a cadeia inteira â€”
> decode, fundo, autostretch sobre o quadro **corrigido** â€” e volta a ser
> comparÃ¡vel nÃºmero a nÃºmero. Ver a seÃ§Ã£o abaixo.

## A cadeia completa contra `chain.py`

`referencia-cadeia.json` fecha o que o passo 6 abriu. O comparador vai a **180
linhas: 174 PASS, 5 N/A, 1 FAIL.**

| fixture | linhas | PASS | FAIL | N/A |
|---|---|---|---|---|
| `seestar` | 13 | 11 | 0 | 2 |
| `rice` | 61 | 60 | 0 | 1 |
| `nonlinear` | 17 | 14 | 1 | 2 |
| `gradient` | 89 | 89 | 0 | 0 |

### A confirmaÃ§Ã£o independente do bug do passo 6

O `before` do stretch **Ã©** a mediÃ§Ã£o do quadro corrigido. Que estes nÃºmeros
batam Ã© confirmaÃ§Ã£o de fora de que o conserto do passo 6 estÃ¡ certo: uma segunda
implementaÃ§Ã£o, escrita depois e montada do zero, mede o mesmo MADN
pÃ³s-correÃ§Ã£o. A razÃ£o entre o dela e o meu:

| `rice` | `nonlinear` | `gradient` |
|---|---|---|
| 1,0062 | 1,0034 | 0,9991 |

O `seestar` dÃ¡ 4,51 e **nÃ£o Ã© discordÃ¢ncia**: a referÃªncia nÃ£o faz debayer, entÃ£o
o MADN dela Ã© dominado pelo padrÃ£o Bayer, que nÃ£o Ã© gradiente. O 0,000951 dela
coincide com o valor **prÃ©**-correÃ§Ã£o daqui (0,000939) porque Ã© a mesma
grandeza. Bloco por canal em N/A, mesma lacuna do MÃ³dulo 0.

### A que reprova, e o que Ã©

**Uma linha: `nonlinear fundo.aceitas` 81 contra 82.** As consequÃªncias ficam
`N/A` com prÃ©-condiÃ§Ã£o explÃ­cita no comparador â€” a tolerÃ¢ncia da Â§7 pressupÃµe
que os dois lados medem **os mesmos pixels**, e conjuntos de amostras diferentes
significam superfÃ­cies diferentes.

A causa foi isolada e **nÃ£o Ã© nenhuma das trÃªs suspeitas Ã³bvias**: os limiares
concordam a 0,34 / 0,86 / 0,08 bins; a amostra marginal em (638, 563) estÃ¡ 6,2
bins acima do limiar **exato** tambÃ©m, entÃ£o os dois a rejeitam; e o critÃ©rio de
rejeiÃ§Ã£o Ã© idÃªntico. O que difere Ã© **onde a caixa estÃ¡**: `Math.round(562,5)`
dÃ¡ 563 em JavaScript e 562 no Python, que arredonda meio para o par. SÃ³ o
`nonlinear` cai nisso, porque sÃ³ nele `w/cols = 75` produz centros em meio
exato. Registrado na Â§2.1 do MÃ³dulo 1 como lacuna de especificaÃ§Ã£o.

### As 6 que reprovavam antes do termo da mediana

Eram `mad`/`madn` acima do piso da Â§7:

| | bins de span | limite |
|---|---|---|
| `rice` G, B `madn` | 8,75 / 9,45 | 8,00 |
| `gradient` R `mad`, `madn` | 14,58 / 21,62 | 8,00 |
| `gradient` B `mad`, `madn` | 8,59 / 12,74 | 8,00 |

**DiagnÃ³stico, e por que nÃ£o afrouxei o nÃºmero.** As medianas concordam
**muito** bem â€” 0,19 a 0,81 bins do eixo [0,1], contra um limite de 4. O que
falha Ã© sÃ³ a dispersÃ£o. A causa Ã© que `MAD = mediana(|v âˆ’ m|)` Ã© medida
**relativa Ã  mediana**, e o piso da Â§7 Ã© dimensionado em bins de `span`, que
depois da correÃ§Ã£o ficou 2,5 a 5Ã— menor. Um deslocamento de mediana de 0,81 bins
do eixo [0,1] sÃ£o 143 bins de `span` â€” o MADN herda a incerteza da mediana
medida num eixo muito mais grosso.

**O termo entrou na Â§7**, e Ã© cota e nÃ£o ajuste: `MAD(m) = mediana(|vâˆ’m|)` e
`â€–vâˆ’mâˆ’d|âˆ’|vâˆ’mâ€– â‰¤ |d|` pela desigualdade triangular; a mediana Ã© monÃ³tona, entÃ£o
a cota passa para o MAD. Vale antes de olhar os dados, para qualquer
distribuiÃ§Ã£o.

    |a âˆ’ b| â‰¤ max( 1e-4Â·|ref| ,  8Â·span/65535  +  1,4826Â·|Î”mediana| )

Com ele as seis passam com folga â€” para `gradient` R o termo vale 1,84e-5 contra
um `Î”madn` observado de 1,87e-6, dez vezes maior. **Controle negativo, para o
termo nÃ£o virar licenÃ§a:** `madn` perturbado em 3Ã— a cota reprova; dentro da
cota passa. Auto-calibrado a partir do `span` do prÃ³prio golden e da mediana da
prÃ³pria referÃªncia, para nÃ£o envelhecer em silÃªncio como os Ã¢ncoras de clip
envelheceram.

## O que o float pleno mudou, medido

O passo 2 do MÃ³dulo 1 tirou o LUT de 2^20 entradas do `stretch-mtf` e passou a
gravar MTF em precisÃ£o plena; `quantise` virou o Ãºnico lugar onde um nÃ­vel Ã©
decidido. A tabela Ã© a captura float comparada contra os goldens de 8 bits:

| artefato | veredito | o que aconteceu |
|---|---|---|
| `log.txt` Ã— 3 | **PASS** byte a byte | todo nÃºmero que o log imprime vem do `before` do record de stretch, que nenhuma etapa a jusante move |
| `diag.json` Ã— 3 | **PASS** byte a byte | mesmo motivo: o painel tambÃ©m Ã© construÃ­do do `before` |
| `png` Ã— 3 | **PASS~** | 0,031% a 0,781% das amostras diferem, **todas por exatamente 1 nÃ­vel** (mÃ©dia do \|d\| = 1,00) |
| `records.json` Ã— 3 | **FAIL** | 23 a 24 campos, **todos em `after.perChannel[*]`**: median, mad, madn, span, q1, q3, p001, p999 |

Nenhum campo de `before` se moveu. Nenhuma contagem de clip se moveu â€”
`outLow` e `outHigh` contam os mesmos dois ramos sobre o mesmo `u`, e a mudanÃ§a
nÃ£o os alcanÃ§a. Foi por isso que os goldens de log e diag sobreviveram: o que
mudou fica inteiramente a jusante da quantizaÃ§Ã£o que saiu.

**A identidade que a cadeia de 8 bits escondia.** No ramo nÃ£o-linear o alvo do
autostretch Ã© a prÃ³pria mediana do canal, entÃ£o `MTF` mapeia mediana em mediana
por construÃ§Ã£o e `after.median` deve ser igual a `before.median`. Na cadeia de
8 bits isso era invisÃ­vel: a mediana pousava em 67/255 = 0,262745. Na cadeia
float ela pousa em 0,2640573739223316 â€” o mesmo dÃ­gito a dÃ­gito que
`before.median`, nos canais R e B; 3,05e-5 no G, que Ã© resoluÃ§Ã£o de histograma.
Isso Ã© evidÃªncia independente de que o caminho novo estÃ¡ certo, e nÃ£o apenas
diferente.

**Reprodutibilidade verificada.** Uma segunda captura independente, depois de
recarregar a pÃ¡gina, devolveu os doze artefatos byte a byte idÃªnticos aos
goldens promovidos. A tolerÃ¢ncia existe para mudanÃ§a de build, nÃ£o para ruÃ­do
de rodada â€” nÃ£o hÃ¡ ruÃ­do de rodada.

**Custo.** `transfer`, relÃ³gio de parede, uma amostra por fixture: 244â†’216,
233â†’268, 134â†’96 ms. `quantise` passou a aparecer separado, em 23 a 71 ms. NÃ£o Ã©
mediÃ§Ã£o â€” Ã© uma amostra â€” e nÃ£o hÃ¡ evidÃªncia de regressÃ£o que importe. O
orÃ§amento real da Â§3.6 do MÃ³dulo 1 Ã© o arraste sobre o buffer de preview, e Ã© lÃ¡
que isso precisa ser medido de verdade quando a RBF entrar.

## Fixtures â€” todos sintÃ©ticos

**Nenhum arquivo de terceiro entra aqui.** Ver `CLAUDE.md`. Os cinco saem de
`.claude/make-fixture.ps1` com semente fixa e sÃ£o reprodutÃ­veis byte a byte â€”
verificado: regerar o `fixture-seestar.fit` devolve o mesmo sha256 do arquivo
versionado.

| nome | arquivo | bytes | sha256 |
|---|---|---|---|
| `seestar-fixture` | `test/fixtures/fixture-seestar.fit` | 4.150.080 | `6d0acf7bbd4ce595d926ccc9bbf8e239447cda8ed7207c682fe598f5534cb28b` |
| `rice-fixture` | `test/fixtures/fixture-rice.fit.fz` | 8.671.680 | ver `make-fixture.ps1` |
| `nonlinear-fixture` | `test/fixtures/fixture-nonlinear.fit` | 6.482.880 | ver `make-fixture.ps1` |
| `gradient-fixture` | `test/fixtures/fixture-gradient.fit` | 23.042.880 | `b14ac76614949a4feef20e1c9aa263b29813f7b2a7298f9b461388d482e1fc25` |
| `edge-fixture` | `test/fixtures/fixture-edge.fit` | 1.442.880 | `3f18a50b3e896aab13683cb0b88abd4cc2f26c6a399dcf71072b8531d64ebf38` |

Cinco, e nÃ£o um, porque cobrem caminhos disjuntos:

- **`seestar-fixture`** â€” 1920Ã—1080, BITPIX 16, BZERO 32768, ROWORDER BOTTOM-UP,
  BAYERPAT GRBG. Leitura de inteiro, flip de linha, detecÃ§Ã£o de CFA, debayer,
  ramo linear. `view.factor` 1.
- **`rice-fixture`** â€” 2600Ã—1000Ã—3, RICE_1 com SUBTRACTIVE_DITHER_2, uma tile
  por linha (3.000 tiles). DescompressÃ£o Rice, dither, caminho de 3 planos sem
  debayer. A borda longa Ã© 2600 **de propÃ³sito**: passa de `MAX_VIEW` (2560) por
  40 px, entÃ£o `view.factor` = 2 e o PNG vem do buffer de resoluÃ§Ã£o plena, que Ã©
  o caminho que o botÃ£o de download realmente usa.

  Traz duas armadilhas embutidas de propÃ³sito: um patch 24Ã—24 de zeros exatos,
  que exercita o sentinela `DITHER_ZERO` do dither 2 (aparece como 576 pixels
  pretos por canal no diagnÃ³stico), e uma quantizaÃ§Ã£o com `ZZERO â‰ˆ 13313,9`
  contra `ZSCALE = 6,2e-6`, que deixa os inteiros logo acima do piso do int32 â€”
  a configuraÃ§Ã£o que obriga o unquantize a ficar em double.
- **`nonlinear-fixture`** â€” 900Ã—600Ã—3, float32 sem compressÃ£o, ROWORDER
  TOP-DOWN, com cards HISTORY de autostretch e mediana medida 0,2467. Ramo
  nÃ£o-linear: ponto preto por percentil, alvo na prÃ³pria mediana. O midtones do
  gerador foi calibrado para pousar a mediana em ~0,25, que Ã© onde um frame
  realmente esticado no Siril fica â€” um valor mais agressivo levava a mediana
  para 0,73 e o fixture deixava de representar o caso.
- **`gradient-fixture`** â€” 1600Ã—1200Ã—3, float32, TOP-DOWN. Para o MÃ³dulo 1.
  Ver a seÃ§Ã£o prÃ³pria abaixo: Ã© o Ãºnico da suÃ­te cujo fundo Ã© conhecido
  independentemente das duas implementaÃ§Ãµes.
- **`edge-fixture`** â€” 400Ã—300Ã—3, float32, TOP-DOWN. 1,44 MB, o mais barato da
  suÃ­te, e o Ãºnico pequeno o bastante para a margem **padrÃ£o** alcanÃ§ar a grade
  de amostras: 38 das 108 amostras sÃ£o rejeitadas por borda, 6 por brilho, 64
  aceitas. Existe porque `rejected-edge` era alcanÃ§Ã¡vel e nÃ£o exercitado â€” o
  estado aparecia na spec, no cÃ³digo e no tooltip, e em nenhum golden. Cobre de
  passagem o caso de quadro pequeno, que tambÃ©m nÃ£o tinha nada.

## `fixture-gradient.fit` â€” o Ãºnico com uma verdade externa

Os outros trÃªs respondem "hoje Ã© igual a ontem?" e "as duas implementaÃ§Ãµes
concordam?". Nenhuma das duas perguntas alcanÃ§a um erro de fÃ³rmula, porque a
referÃªncia do Python leu a fÃ³rmula daqui â€” estÃ¡ registrado na Â§7 do MÃ³dulo 0 e
na Â§5 do MÃ³dulo 1. Este responde a uma terceira: **o modelo ajustado Ã© o
gradiente que eu coloquei?**

O que estÃ¡ gravado em cards `HISTORY`, e Ã© lido de volta pelo teste:

```
g(u,v) = A0 + A1*u + A2*v + A3*u^2 + A4*v^2 + A5*u*v
u = x/(NAXIS1-1)   v = y/(NAXIS2-1)   TOP-DOWN, entÃ£o v=0 Ã© a primeira linha
```

com os seis coeficientes por canal, mais a geometria do objeto estendido
(`CX CY A B PEAK K`, perfil `I = PEAK*exp(-K*R)` em raio elÃ­ptico), as posiÃ§Ãµes
das estrelas-sonda, o sigma do ruÃ­do e as sementes. 21 cards. O gerador escreve
os cards **das mesmas variÃ¡veis** que passa ao construtor da cena, entÃ£o nÃ£o hÃ¡
dois lugares onde o nÃºmero possa divergir.

**Por que TOP-DOWN:** o flip de linha jÃ¡ estÃ¡ coberto pelo `seestar-fixture`.
Aqui a clareza do contrato vale mais â€” com TOP-DOWN as coordenadas do `HISTORY`
sÃ£o as coordenadas da imagem, sem inversÃ£o no meio da comparaÃ§Ã£o.

**Por que 1600Ã—1200:** nÃ£o Ã© nÃºmero redondo. Com `samplesPerRow` 12 a grade Ã©
12Ã—9, e com `PREVIEW_EDGE` 1024 o fator de preview Ã© 2 â€” entÃ£o o fixture
exercita o escalonamento de `boxSize` da Â§2.1, que Ã© a exigÃªncia de que uma
caixa de amostra signifique o mesmo pedaÃ§o de cÃ©u no preview e no render.

**Por que ruÃ­do gaussiano, e nÃ£o uniforme como nos outros:** a rejeiÃ§Ã£o Ã©
`mediana da caixa > mediana global + tolerance Ã— MADN`, e MADN sÃ³ significa
"sigma" para ruÃ­do gaussiano. Com ruÃ­do uniforme o limiar de rejeiÃ§Ã£o cairia num
lugar sem interpretaÃ§Ã£o e o fixture estaria testando outra coisa.

### Medido no fixture gerado, com os parÃ¢metros padrÃ£o da Â§2.2

Grade 12Ã—9 = 108 amostras, caixa 25 px, margem 24 px, `tolerance` 1,0:

| | |
|---|---|
| aceitas | 93 |
| rejeitadas por brilho | 15, das quais **12 sobre o objeto** |
| rejeitadas por borda | 0 |
| fraÃ§Ã£o rejeitada | 13,9% |

Fica bem acima da salvaguarda de 8 pontos e bem abaixo dos 40% que a Â§3.5 manda
avisar. O objeto forÃ§a rejeiÃ§Ã£o, que Ã© para o que ele existe.

**ResÃ­duo |mediana da caixa âˆ’ verdade| nas aceitas: mÃ¡ximo 0,242 nÃ­vel de 255,
mÃ©dio 0,030.** A Â§5 sugere 1 nÃ­vel como tolerÃ¢ncia de partida para o modelo
ajustado contra o gradiente verdadeiro; a amostragem sozinha jÃ¡ entrega um
quarto disso, entÃ£o o orÃ§amento sobra para a RBF.

### A mediana sobrevive Ã  estrela; a mÃ©dia nÃ£o

Oito estrelas-sonda em posiÃ§Ãµes gravadas, `PEAK` 0,45 e `sigma` 2,2. O sigma Ã©
pequeno de propÃ³sito: numa caixa de 625 pixels a estrela levanta cerca de 22%
deles, confortavelmente abaixo de metade. Um sigma maior viraria a mediana
tambÃ©m e o fixture passaria a argumentar o contrÃ¡rio do que a Â§2.1 afirma.

Nas caixas que contÃªm uma sonda, canal G, em nÃ­veis de 255:

| desvio da mediana | desvio da mÃ©dia |
|---|---|
| 0,08 a 0,30 | **5,1 a 5,8** |

Cerca de **20Ã— pior para a mÃ©dia**. Ã‰ a Â§2.1 deixando de ser asserÃ§Ã£o e virando
nÃºmero.

### Duas coisas que o fixture expÃµe de graÃ§a

**A fraqueza da tolerÃ¢ncia global.** Uma das oito caixas-sonda, em (1253, 1112),
Ã© rejeitada por brilho â€” e ali nÃ£o hÃ¡ objeto nenhum, sÃ³ fundo mais uma estrela.
No canto claro do gradiente o prÃ³prio fundo jÃ¡ passa de
`mediana global + 1,0 Ã— MADN`. Ã‰ exatamente a queixa registrada contra o Siril
na Â§1 ("tolerÃ¢ncia global Ãºnica para a imagem inteira"), reproduzida num arquivo
onde dÃ¡ para medir. NÃ£o Ã© defeito do fixture: Ã© o defeito que o MÃ³dulo 1b
promete resolver, disponÃ­vel para teste antes de a soluÃ§Ã£o existir.

**Custo em disco, e a decisÃ£o sobre ele.** 23,0 MB, contra 19,3 MB dos outros
trÃªs somados; a Ã¡rvore de fixtures passa a 42,3 MB.

**Fica assim: 1600Ã—1200, sem compressÃ£o. Decidido, nÃ£o pendente.**

Encolher o quadro perde o que ele testa â€” a grade 12Ã—9 e o fator de preview 2
sÃ£o os dois motivos de ele ter esse tamanho. E comprimir para `.fz` misturaria o
caminho Rice com o caminho do gradiente: uma falha neste fixture passaria a ter
duas explicaÃ§Ãµes possÃ­veis, e separar as duas custaria mais do que os 23 MB
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

Os PNG cresceram entre 15% e 24%: o dither substitui bandas lisas por ruÃ­do, e
ruÃ­do nÃ£o comprime. Ã‰ o custo direto de nÃ£o ter bandas.

`gradient-truth.json` Ã© o Ãºnico destes que `compare-golden.ps1` **nÃ£o** compara:
ele vem de `compare-truth.js`, nÃ£o da captura, e Ã© medida de referÃªncia e nÃ£o
artefato de saÃ­da. Comparar automaticamente entra junto com o passo 8, quando o
`reference.py` conhecer o fixture.

### O que o passo 4 mudou nestes goldens, medido

A etapa de fundo entrou na cadeia amostrando e rejeitando, sem ajustar
superfÃ­cie e sem tocar em pixel. Contra os goldens do passo 3:

| artefato | veredito |
|---|---|
| `log.txt` Ã— 4 | **PASS** byte a byte |
| `diag.json` Ã— 4 | **PASS** byte a byte |
| `png` Ã— 4 | **PASS** byte a byte |
| `records.json` Ã— 4 | **FAIL**, `length 1 vs 2` |

O PNG idÃªntico Ã© a verificaÃ§Ã£o de que a etapa devolve a imagem intacta: se um
pixel tivesse se movido, ele apareceria. O log idÃªntico Ã© a verificaÃ§Ã£o de que
"background extraction" continua na frase "Not applied" â€” `applied: false`, e
`notAppliedLabels` chaveia nisso. E o `records.json` reprova por **mudanÃ§a
estrutural**, nÃ£o por deriva numÃ©rica: a cadeia ganhou um record, e nenhuma
tolerÃ¢ncia deve perdoar isso.

Os `records.json` cresceram de ~3,8 KB para 22â€“35 KB. Ã‰ a lista de pontos: cada
amostra com coordenada, estado, mediana por canal e a frase que diz por que foi
rejeitada. A Â§2.2 pede que o motivo esteja no record e nÃ£o sÃ³ no tooltip, e um
ponto rejeitado que some do registro Ã© a operaÃ§Ã£o silenciosa que a confusÃ£o 21
proÃ­be. 117 KB somados, contra 16,5 MB de PNG nos mesmos goldens.

## O modelo contra a verdade â€” passo 5

`test/compare-truth.js` roda no navegador, ajusta a superfÃ­cie com o cÃ³digo
entregue e compara contra os coeficientes do gradiente lidos de volta dos cards
`HISTORY`. O relatÃ³rio fica em `test/golden/gradient-truth.json`.

Isto Ã© o que `compare-golden` e `compare-reference` nÃ£o conseguem responder. Um
pergunta se hoje Ã© igual a ontem; o outro se as duas implementaÃ§Ãµes concordam â€”
e elas concordam sobre uma fÃ³rmula que foi lida deste cÃ³digo. Um erro de fÃ³rmula
Ã© invisÃ­vel para os dois. Aqui a resposta vem de nÃºmeros que o gerador escreveu
e que nenhuma das duas implementaÃ§Ãµes viu.

### ResÃ­duo `|modelo âˆ’ gradiente verdadeiro|`, em nÃ­veis de 255

| regiÃ£o | mÃ¡ximo | mÃ©dio |
|---|---|---|
| fora do objeto (raio elÃ­ptico > 2) | **0,168** | 0,031 |
| no canto que a rejeiÃ§Ã£o global descarta | **0,168** | 0,067 |
| sob o objeto (raio â‰¤ 1) | 0,840 | 0,649 |

A Â§5 do MÃ³dulo 1 sugere 1 nÃ­vel como tolerÃ¢ncia de partida fora das regiÃµes
rejeitadas. O medido Ã© **0,168** â€” seis vezes dentro.

O resÃ­duo sob o objeto **nÃ£o Ã© erro**: ali o esperado Ã© o gradiente sozinho,
porque o objeto Ã© sinal a preservar e nÃ£o fundo a remover. O nÃºmero mede
**contaminaÃ§Ã£o** â€” quanto do objeto vazou para o modelo e seria subtraÃ­do dele
no passo 6.

### ContaminaÃ§Ã£o, e o que a rejeiÃ§Ã£o compra

O pico do objeto vale 13,39 nÃ­veis. O modelo absorve 0,840 â†’ **6,27%**.

| `tolerance` | aceitas | contaminaÃ§Ã£o | resÃ­duo fora do objeto |
|---|---|---|---|
| 10 (sem rejeiÃ§Ã£o) | 108 | **38,9%** | 0,267 |
| 2,0 | 101 | 10,96% | 0,148 |
| **1,0 (padrÃ£o)** | **93** | **6,27%** | **0,168** |
| 0,5 | 72 | 5,43% | 0,170 |
| 0,25 | 62 | 4,27% | 0,216 |
| 0,0 | 54 | 4,35% | 0,333 |

**A rejeiÃ§Ã£o vale um fator de 6.** Sem ela o modelo come 38,9% do objeto â€” trÃªs
vezes pior que os 12,5% que o GraXpert perdeu num braÃ§o do M31 (Â§1). Com ela,
6,27%, entre os 12,5% do modo IA e os 5% do ajuste manual.

Apertar alÃ©m de 1,0 rende pouco e cobra: a contaminaÃ§Ã£o para de melhorar perto
de 4% enquanto o resÃ­duo fora do objeto piora de 0,168 para 0,333. O padrÃ£o 1,0
estÃ¡ perto do joelho da curva, e agora isso Ã© medida e nÃ£o escolha.

### Erro da interpolaÃ§Ã£o â€” medido, nÃ£o presumido

A Â§2.3 manda avaliar numa grade de 1/8 e interpolar, e **medir** o erro contra
avaliaÃ§Ã£o direta em 1000 pixels, aumentando a grade se passar de 0,5 nÃ­vel.

| fixture | grade | erro mÃ¡ximo |
|---|---|---|
| `seestar` | 241Ã—136 | 0,0001 |
| `rice` | 326Ã—126 | 0,0000 |
| `nonlinear` | 114Ã—76 | 0,0039 |
| `gradient` | 201Ã—151 | 0,0004 |

Duas ordens de grandeza dentro do limite no pior caso. O divisor nunca precisou
aumentar â€” mas isso Ã© resultado, nÃ£o premissa, e Ã© remedido a cada execuÃ§Ã£o.

Os 1000 pixels sÃ£o varridos por passo primo (104729) sobre o Ã­ndice, que Ã©
Ã­mpar e portanto coprimo com qualquer potÃªncia de dois: sondas consecutivas
caem em fases diferentes dentro da cÃ©lula da grade, que Ã© onde o erro vive. Um
passo que compartilhasse fator com o divisor amostraria os cantos das cÃ©lulas e
reportaria zero.

## Passo 6 â€” a correÃ§Ã£o, e o que medi-la encontrou

A correÃ§Ã£o Ã© `out = in âˆ’ model + pedestal`, com o pedestal sendo a mediana do
prÃ³prio modelo, **por canal**. A partir daqui a etapa reporta `applied: true`.

### A razÃ£o entre canais sobrevive â€” e o nÃºmero que sustenta a frase de log

Medido no `fixture-rice`, mediana de fundo antes e depois da correÃ§Ã£o:

| | antes | depois | deriva |
|---|---|---|---|
| R/G | 1,099312 | 1,099010 | **âˆ’0,028%** |
| B/G | 0,920354 | 0,919802 | **âˆ’0,060%** |

E o contrafactual, aritmeticamente, se o pedestal fosse **Ãºnico** (a mÃ©dia dos
trÃªs) em vez de por canal:

| | resultado | deriva |
|---|---|---|
| R/G | 0,999904 | **âˆ’9,04%** |
| B/G | 0,999918 | **+8,64%** |

O pedestal Ãºnico colapsa as duas razÃµes para 1,0: ele **lava a cor do fundo**.
Por canal preserva ~150Ã— melhor. Nos quatro fixtures a deriva por canal fica
entre 0,016% e 0,44%; a de pedestal Ãºnico, entre 6,6% e 11,2%.

Ã‰ este o nÃºmero por trÃ¡s da frase *"the ratio between channels is therefore
unchanged: no colour grading"*, que agora estÃ¡ no log.

### Negativos, e por que a contagem zero aqui nÃ£o Ã© clamp

A regra Ã© nÃ£o clampear, e o teste natural â€” "se nÃ£o sobrou negativo, algo
clampeou" â€” dÃ¡ **falso alarme nestes fixtures**. Medido no `fixture-gradient`,
canal R:

| | mÃ­nimo | negativos |
|---|---|---|
| entrada | 0,007542 | 0 |
| corrigido, pedestal real | **0,012405** | 0 |
| corrigido, pedestal forÃ§ado a 0 | **âˆ’0,005950** | 882.624 (46%) |

O sinal de clamp nÃ£o Ã© a contagem, Ã© **o mÃ­nimo pousar exatamente em zero**. Ele
pousa em 0,0124, longe de zero, e com o pedestal zerado os 882 mil negativos
atravessam intactos. Nada clampeia.

A contagem zero Ã© aritmÃ©tica: o pedestal (0,0184) Ã© maior que a excursÃ£o do
modelo acima da prÃ³pria mediana (~0,0064), entÃ£o `in âˆ’ model + pedestal` nÃ£o
alcanÃ§a zero. **Lacuna de cobertura:** nenhum fixture tem gradiente forte o
bastante em relaÃ§Ã£o ao nÃ­vel de fundo para produzir negativos no caminho normal.
Dado real com poluiÃ§Ã£o luminosa forte produz.

### O dither Ã© determinÃ­stico

Duas capturas independentes, cada uma depois de recarregar a pÃ¡gina: os quatro
PNG **byte a byte idÃªnticos**. Semente 20260906, amplitude Â±0,5 nÃ­vel, ambas no
record do `quantise` e no log.

### O bug que a correÃ§Ã£o expÃ´s: o stretch media o quadro errado

`stepStretchMTF` recebia a mediÃ§Ã£o tirada **antes** da etapa de fundo. Enquanto
a etapa sÃ³ amostrava isso era inofensivo â€” as duas mediam os mesmos pixels â€” e
virou errado no instante em que um pixel se moveu.

O MADN Ã© a parte que importa, porque o ponto preto Ã© `mediana âˆ’ 2,8 Ã— MADN`, e o
gradiente removido fazia parte da dispersÃ£o que o MADN media:

| fixture | MADN antes | MADN depois | fator |
|---|---|---|---|
| `seestar` | 0,000939 | 0,000211 | **4,5Ã—** |
| `rice` | 0,001868 | 0,000364 | **5,1Ã—** |
| `nonlinear` | 0,019943 | 0,005833 | **3,4Ã—** |
| `gradient` | 0,003549 | 0,001395 | **2,5Ã—** |

O ponto preto estava de 2,5 a 5 vezes fundo demais, em todo quadro.

**E era invisÃ­vel na mÃ©trica de saÃ­da:** a mediana pÃ³s-esticamento fica em ~64
de qualquer jeito, porque o MTF mapeia mediana no alvo seja qual for o MADN. Ã‰ a
mesma classe do erro do Î» â€” nÃ£o falha, nÃ£o avisa, e fica pior para sempre. O
`before` do stretch passa a vir do `after` da etapa de fundo, que jÃ¡ estava
medido e custava zero.

## Passo 7 â€” a frase "Not applied", verificada nos dois sentidos

O passo 7 era verificaÃ§Ã£o, e o que havia a verificar jÃ¡ tinha acontecido
sozinho: a frase perdeu "background extraction" no passo 6, **com zero ediÃ§Ãµes
em `registry.js`** â€” o arquivo nÃ£o Ã© tocado desde o passo 5 do MÃ³dulo 0.

Verificar que o rÃ³tulo sumiu Ã© fraco: uma string apagada tambÃ©m some. A prova Ã©
o **round-trip**, e ela passa pelo `buildLog` real:

| `background.applied` | descreve a etapa | nega a etapa |
|---|---|---|
| `true` | **1 linha** | ausente da frase |
| `false` | 0 linhas | **presente na frase** |

Os dois se movem juntos e em direÃ§Ãµes opostas. O invariante nÃ£o Ã© "o rÃ³tulo
some", Ã© **o log ou descreve a operaÃ§Ã£o ou a nega, nunca nenhum dos dois e nunca
os dois**. Foi essa a segunda metade que o passo 6 quase deixou aberta: a frase
parou de negar antes de alguÃ©m escrever a que afirma.

Com `applied: false`, a frase volta **idÃªntica** Ã  de antes do MÃ³dulo 1 â€”
comparada contra o resultado de `notAppliedLabels` sem nenhum record de fundo.

E o guarda do catÃ¡logo continua vivo: um passo declarado `neverImplemented`
reportando que rodou faz `notAppliedLabels` recusar produzir log, em vez de
produzir um que negue o que acabou de acontecer. Verificado com `id: 'ai'`.

## Grade sobre o quadro inteiro â€” e as duas implementaÃ§Ãµes coincidindo

A grade deixou de ser encaixada dentro da margem. Centro em `(i+0,5)Â·w/cols`; a
margem Ã© sÃ³ critÃ©rio de rejeiÃ§Ã£o, que Ã© o que a Â§2.2 sempre disse.

**Depois da mudanÃ§a, contra `reference_bg.py`:**

| | esta implementaÃ§Ã£o | `reference_bg.py` | diferenÃ§a |
|---|---|---|---|
| amostras aceitas | 92 | 92 | 0 |
| rejeitadas por brilho | 16 | 16 | 0 |
| campo limpo R, mÃ¡ximo | 0,111218 | 0,111214 | 4,5e-6 nÃ­vel |
| campo limpo R, mÃ©dia | 0,011537 | 0,011537 | 2,4e-7 nÃ­vel |
| campo limpo G, mÃ¡ximo | 0,129388 | 0,129384 | 4,1e-6 nÃ­vel |
| campo limpo B, mÃ¡ximo | 0,111776 | 0,111772 | 3,6e-6 nÃ­vel |
| pedestal R | 0,018307595 | 0,018308640 | 0,00027 nÃ­vel |

**Cinco algarismos significativos**, com grades independentes e Ã¡lgebra
independente (`numpy.linalg.solve` contra eliminaÃ§Ã£o de Gauss escrita Ã  mÃ£o). O
resÃ­duo de 4,5e-6 nÃ­vel Ã© 1,7e-8 em [0,1] e tem causa identificada: as duas
avaliam a superfÃ­cie em retÃ­culas de tamanhos diferentes â€” 201Ã—151 aqui,
200Ã—150 lÃ¡ â€” entÃ£o o valor interpolado num pixel difere nessa ordem. O pedestal
difere um pouco mais porque Ã© a **mediana** dessa retÃ­cula, e as duas tomam a
mediana sobre conjuntos de nÃ³s diferentes.

Antes da mudanÃ§a eram 93 contra 92 aceitas e 0,1688 contra 0,1112 no campo
limpo. **"Grade diferente e Ã¡lgebra diferente" era uma causa sÃ³.**

**O que a mudanÃ§a custou e rendeu**, medido no `fixture-gradient`:

| | grade encaixada | quadro inteiro |
|---|---|---|
| campo limpo fora do casco das amostras | 31,4% | â€” |
| campo limpo, mÃ¡ximo | 0,1688 | **0,1112** |
| campo limpo, mÃ©dia | 0,0337 | **0,0115** |
| casco das amostras | 1422Ã—1024 | 1466Ã—1066 |

### Amostragem, por fixture

| fixture | quadro | grade | caixa | geradas | aceitas | brilho | borda |
|---|---|---|---|---|---|---|---|
| `seestar` | 1920Ã—1080 | 12Ã—7 | 25 | 84 | 72 | 12 | 0 |
| `rice` | 2600Ã—1000 | 12Ã—5 | 25 | 60 | 53 | 7 | 0 |
| `nonlinear` | 900Ã—600 | 12Ã—8 | 25 | 96 | 85 | 11 | 0 |
| `gradient` | 1600Ã—1200 | 12Ã—9 | 25 | 108 | 93 | 15 | 0 |

Os quatro reportam `applied: false` com o mesmo `skipReason`: *sampling only*.

**VerificaÃ§Ã£o cruzada do `gradient`:** 93/15/0/0 Ã© exatamente o que a anÃ¡lise
independente em PowerShell tinha medido no fixture, e ela usou mediana e MAD por
**seleÃ§Ã£o exata** enquanto a etapa usa **histograma de 65536 bins**. Dois
estimadores diferentes do limiar, 108 vereditos idÃªnticos.

**Preview contra render, medido:** com o buffer reduzido a 800Ã—600 e `boxSize`
escalado de 25 para 13, os 108 pontos recebem a **mesma classificaÃ§Ã£o** e a
maior diferenÃ§a de mediana de caixa Ã© **0,0185 nÃ­vel de 255**. Ã‰ a afirmaÃ§Ã£o da
Â§2.1 sobre correspondÃªncia preview/render, com nÃºmero.

O `.diag.json` Ã© `JSON.stringify(state.diag, null, 2)` â€” o objeto cru, nÃ£o o
`dump()` do painel, que arredonda para 8 dÃ­gitos significativos. Guardar o cru
significa que uma regressÃ£o de ponto flutuante aparece em vez de ser arredondada
para fora. (Os sha256 do diag mudam a cada captura por causa de `timingsMs`; os
da tabela sÃ£o do arquivo versionado.)

## O que nÃ£o Ã© estÃ¡vel, e o que deixou de nÃ£o ser

**`timingsMs`** no diagnÃ³stico continua sendo relÃ³gio de parede.
`compare-golden.ps1` recorta o bloco dos dois lados antes de comparar. Ã‰ a Ãºnica
coisa que ele ignora inteiramente, em vez de comparar com tolerÃ¢ncia.

Nota de arqueologia: os goldens anteriores foram capturados de um build de 10
arquivos cujo `timingsMs` nÃ£o tinha `preview` nem `quantise`. Eles continuaram
vÃ¡lidos atravÃ©s de todos os refactors do MÃ³dulo 0 porque aqueles refactors foram
neutros nos artefatos comparados, e as duas chaves novas caÃ­ram dentro do Ãºnico
bloco que o comparador recorta. O sha256 de build que este arquivo registrava
estava desatualizado desde o passo 7 do MÃ³dulo 0; estÃ¡ corrigido acima.

**A data no log** era o outro relÃ³gio, e nÃ£o Ã© mais. `runPipeline(buffer,
fileName, post, opts)` recebe `opts.now`, que cai em `new Date()` quando
ausente. O navegador segue imprimindo o dia de hoje; a captura fixa
`__GOLDEN_DATE = '2026-09-05'`. Estes goldens nÃ£o expiram. NÃ£o mude
`__GOLDEN_DATE`: invalida todos os logs guardados e nÃ£o compra nada.

## O corpus malformado

33 arquivos que mentem sobre si mesmos, em `test/malformed/`, gerados por
`test/make-malformed.ps1` e comparados por `test/compare-malformed.ps1` contra
`test/golden/malformed.json`. Vieram de uma auditoria de robustez feita antes da
publicaÃ§Ã£o; quatro achados dela viraram correÃ§Ã£o de cÃ³digo.

**NÃ£o sÃ£o versionados, e o cabeÃ§alho do gerador explica por quÃª**: a geraÃ§Ã£o Ã© sÃ³
ASCII e inteiros big-endian, idÃªntica em qualquer mÃ¡quina por construÃ§Ã£o â€” ao
contrÃ¡rio dos fixtures, que passam por ponto flutuante e por isso ficam
versionados. A divergÃªncia continua detectÃ¡vel: o `malformed.json` guarda o
sha256 de cada arquivo e o comparador regenera e confere **antes** de olhar
qualquer veredito. `build.ps1 -Check` lÃª a mesma lista para saber que estes
arquivos nÃ£o precisam estar no git.

**A pergunta Ã© outra que a dos goldens.** `compare-golden` pergunta "a saÃ­da de
hoje Ã© a de ontem?". Aqui Ã© "isto continua sendo recusado?", e a falha grave Ã©
assimÃ©trica: `rejeita â†’ aceita` Ã© a pior, porque parece uma rodada
bem-sucedida â€” a pÃ¡gina produz imagem a partir de bytes que ninguÃ©m verificou.
Nove casos existem para o lado oposto (`a8`, `a9`, `a10`, `c2`, `d13`, `e2`,
`e3`, `e6`, `e7`, `e8`): sÃ£o os arquivos estranhos que **tÃªm** que passar, e
pegam o dia em que alguÃ©m apertar uma validaÃ§Ã£o demais.

O comparador tambÃ©m verifica **tempo**, com teto de 3000 ms. "Parou" Ã© metade da
afirmaÃ§Ã£o: um arquivo que trava a aba falha diferente de um que dÃ¡ erro. Pior
caso hoje: 32 ms, o cabeÃ§alho de 4 MB.

### O que a auditoria achou, e o que mudou

| achado | era | virou |
|---|---|---|
| descritor de heap fora do arquivo | **aceitava**, quadro chapado, sem erro | `badheader` antes de qualquer leitura |
| `ZTILE` sem teto | `new Int32Array(t1*t2*t3)` fora do `alloc()`; **+768 MB medidos** de um arquivo de 14 kB | tile limitado pela imagem, atravÃ©s do `alloc()` |
| `PCOUNT` negativo | encolhia o tamanho declarado e passava; `RangeError` cru lido como "memÃ³ria" | `badheader` |
| `RangeError` sem `kind` â†’ `memory` | a justificativa escrita era falsa, e os dois casos acima a desmentiam | `unknown`, e a razÃ£o inversa estÃ¡ escrita: tudo que escala com o arquivo passa pelo `alloc()`, que rotula sozinho |

O par `d11`/`d13` Ã© o guarda de off-by-one da validaÃ§Ã£o de ponteiro: um byte
alÃ©m do fim Ã© `badheader`, o byte exato passa e decodifica.

A correÃ§Ã£o nÃ£o mexeu em nenhuma saÃ­da legÃ­tima â€” os 20 goldens saÃ­ram
byte-idÃªnticos sem recaptura, incluindo o `rice-fixture`, que Ã© o que prova que
o teto de `ZTILE` e a validaÃ§Ã£o de heap nÃ£o tocam um `.fz` vÃ¡lido.

## `fixture-colour` â€” a cor conhecida por construÃ§Ã£o

1600Ã—1200Ã—3, float32, TOP-DOWN. Ã‰ o Ãºnico golden capturado com parÃ¢metros que
**nÃ£o** sÃ£o os defaults: `colourCal` fica desligado atÃ© o MÃ³dulo 3, entÃ£o
capturar com os defaults nÃ£o exercitaria nada da calibraÃ§Ã£o. Os parÃ¢metros vÃ£o
pelo mesmo `requestRun` que a interface usaria â€” nÃ£o hÃ¡ caminho de teste
separado.

TrÃªs populaÃ§Ãµes, trÃªs razÃµes, **nenhuma perto de outra**, e Ã© isso que faz o
resultado dizer *qual* populaÃ§Ã£o foi medida em vez de sÃ³ "o nÃºmero Ã© plausÃ­vel":

| populaÃ§Ã£o | R/G | B/G | papel |
|---|---|---|---|
| fundo | 0,8571 | 0,5714 | o que a Â§2.1 nivela |
| **estrelas** | **1,2500** | **0,8000** | o que a Â§2.2 tem que achar |
| objeto extenso | 0,9500 | 1,1000 | o que contamina a Â§2.2 |

Medido, com tudo ligado: **1,2511 / 0,7994** â€” 0,09% e 0,08% da verdade
injetada. Ganhos 0,7993 Â· 1,0000 Â· 1,2510 contra 0,8000 Â· 1,0000 Â· 1,2500.

### As quatro configuraÃ§Ãµes, e o que cada uma prova

| configuraÃ§Ã£o | R/G | ganho R |
|---|---|---|
| tudo ligado | 1,2511 | 0,7993 |
| sem rejeiÃ§Ã£o de extenso | 1,2513 | 0,7992 |
| sem corte superior | 1,2521 | 0,7987 |
| **sem os dois** | **1,0027** | **0,9973** |

A Ãºltima linha Ã© o modo de falha inteiro: com as duas defesas desligadas o ganho
vermelho vira **0,9973 â€” identidade**. A etapa roda, o record preenche, o log
imprime, e a cor nunca foi medida. As duas linhas do meio mostram que as defesas
se cobrem: o filtro de extenso tambÃ©m rejeita os aglomerados saturados, porque
um borrÃ£o saturado tem vizinhanÃ§a cheia.

### TrÃªs construÃ§Ãµes, e a primeira reprovou

Registrado porque a reprovaÃ§Ã£o foi a parte Ãºtil.

1. **Objeto 240Ã—150, pico 0,060; 40 estrelas saturadas.** A etapa devolveu
   1,127/0,798 â€” a razÃ£o do **objeto**, quase exata. Medido: 29,8% dos pixels
   selecionados estavam dentro da elipse do objeto. Um fixture que nÃ£o separa
   essas duas respostas certificaria um passo que mede a populaÃ§Ã£o errada.
2. **Saturadas com amplitude 3,0 e brilho igual nos trÃªs canais.** As asas
   ficavam cinzas, o que nÃ£o Ã© o que uma estrela saturada real faz â€” e o nÃºcleo
   totalmente preso era menor que o anel parcialmente preso, cuja razÃ£o Ã© *maior*
   que a estelar. Desligar o corte movia a resposta para o lado errado.
3. **A atual:** objeto restaurado, saturadas com a mesma razÃ£o das estrelas e
   amplitude 30,0, para que o nÃºcleo cinza domine o anel.

### O que este fixture ainda nÃ£o prova

A rejeiÃ§Ã£o de extenso remove **1.646 pixels** aqui, contra 39% da seleÃ§Ã£o no
empilhamento real de M 31. O limiar de brilho sobe muito com 900 estrelas
saturadas no quadro e o objeto acaba quase todo abaixo dele. O filtro estÃ¡
exercitado, nÃ£o estressado; a evidÃªncia forte para ele Ã© a mediÃ§Ã£o real
registrada na Â§0 da spec, nÃ£o este fixture.

## Cobertura que ainda falta

Nenhum fixture cobre **`.fz` que ainda seja mosaico CFA** â€” descompressÃ£o e
debayer estÃ£o cobertos em separado, nunca combinados. O gerador consegue
produzir isso (Ã© o caminho int16 + BAYERPAT dentro do escritor Rice); ninguÃ©m
escreveu ainda.

**FECHADO â€” gradiente e objeto extenso.** Era o passo 3 da Â§6 do MÃ³dulo 1 e
existe: `fixture-gradient.fit`, seÃ§Ã£o prÃ³pria acima.

O que ainda falta em volta dele: o `reference.py` nÃ£o conhece este fixture, entÃ£o
`compare-reference.ps1` continua em 116 linhas e nÃ£o o cobre. Ã‰ o passo 8 da Â§6,
e atÃ© lÃ¡ o gradiente Ã© verificÃ¡vel contra os cards `HISTORY` mas nÃ£o contra uma
segunda implementaÃ§Ã£o.
