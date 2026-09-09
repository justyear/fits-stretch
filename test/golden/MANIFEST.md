# Golden artifacts

CritÃƒÂ©rio de aceitaÃƒÂ§ÃƒÂ£o: **a tolerÃƒÂ¢ncia da Ã‚Â§7 do MÃƒÂ³dulo 0**, aplicada por
`compare-golden.ps1`, que responde em duas partes e diz qual respondeu Ã¢â‚¬â€
`PASS` quando os bytes sÃƒÂ£o idÃƒÂªnticos, `PASS~` quando diferem e toda diferenÃƒÂ§a
cabe na tolerÃƒÂ¢ncia, `FAIL` fora disso. O log continua exato, sem tolerÃƒÂ¢ncia.

O critÃƒÂ©rio anterior Ã¢â‚¬â€ PNG, log e records byte a byte, diagnÃƒÂ³stico byte a byte
menos `timingsMs` Ã¢â‚¬â€ valeu enquanto a cadeia tinha uma etapa e o LUT era a
autoridade sobre o valor do pixel. Morreu no passo 2 do MÃƒÂ³dulo 1, por
construÃƒÂ§ÃƒÂ£o e no prazo. Ver "O que o float pleno mudou", abaixo.

Os goldens abaixo foram capturados de `.claude/index-test.html`, o build **com
ganchos**. O publicado ÃƒÂ© `index.html` e difere dele apenas pelo bloco de
ganchos. Os dois:

<!--BUILD_HASHES-->

| arquivo | bytes | sha256 |
|---|---|---|
| `index.html` | 210946 | `852c349e150608fd3f38d4da0fdccad58fb41f9d217725d00939a49937101ee5` |
| `.claude/index-test.html` | 212639 | `f3e5ec1160591d9b3723c24379400522193feb8fd5eef32beb88484c899cba28` |

<!--/BUILD_HASHES-->

**Esta tabela ÃƒÂ© verificada por `build.ps1 -Check`**, que a lÃƒÂª entre os dois
marcadores acima e compara com o build que acabou de montar. Ela existe para
quem quer conferir o download sem rodar o build; ser escrita ÃƒÂ  mÃƒÂ£o ÃƒÂ© o motivo
pelo qual precisa ser verificada, nÃƒÂ£o uma licenÃƒÂ§a para nÃƒÂ£o ser.

Precisou existir: os nÃƒÂºmeros daqui ficaram desatualizados desde `741f0e1` Ã¢â‚¬â€ a
correÃƒÂ§ÃƒÂ£o do pedestal mudou `background.js`, logo mudou o build Ã¢â‚¬â€ e ninguÃƒÂ©m
percebeu, porque nenhum comparador os lia. Ãƒâ€° a forma invertida do argumento que
o prÃƒÂ³prio log usa: a frase do log nÃƒÂ£o envelhece porque ÃƒÂ© gerada; estes nÃƒÂºmeros
envelhecem porque nÃƒÂ£o sÃƒÂ£o. O conserto nÃƒÂ£o ÃƒÂ© gerÃƒÂ¡-los, ÃƒÂ© medi-los.

Navegador: Chromium 148 (`Chrome/148.0.7778.280`, in-app browser do Claude
Code). Isso ainda importa para o PNG, mas menos do que importava: o comparador
agora **decodifica** o PNG e compara pixels, entÃƒÂ£o outro encoder com os mesmos
pixels passa. O que continua dependendo do Chromium ÃƒÂ© o sha256 da tabela
abaixo, nÃƒÂ£o o veredito.

### Abre por duplo clique Ã¢â‚¬â€ os quatro caminhos, e como cada um foi verificado

| navegador | protocolo | caminho | como |
|---|---|---|---|
| Firefox 155 | `file://` | worker | automatizado |
| Chrome 151 | `file://` | inline | automatizado |
| Chrome 148 | `http://` | worker | automatizado, a sessÃƒÂ£o inteira |
| **Chrome** | **`file://`** | **worker** | **manual, 2026-09-07** |

O ÃƒÂºltimo foi verificado ÃƒÂ  mÃƒÂ£o porque nÃƒÂ£o ÃƒÂ© automatizÃƒÂ¡vel aqui: o headless do
Chrome com `--virtual-time-budget` nÃƒÂ£o avanÃƒÂ§a os timers de dentro de um Worker,
entÃƒÂ£o a mediÃƒÂ§ÃƒÂ£o automÃƒÂ¡tica diz "nÃƒÂ£o completou" mesmo quando a pÃƒÂ¡gina funciona.
EstÃƒÂ¡ registrado no `NOTAS` como o caso que gerou a regra do controle positivo.

**Verificado manualmente em 2026-09-07:** `index.html` aberto por duplo clique
no Chrome, arquivo solto na pÃƒÂ¡gina, processou. Nos quatro caminhos, nenhuma
requisiÃƒÂ§ÃƒÂ£o externa.

## Como reproduzir

```
powershell -File .claude\make-fixture.ps1        # se os fixtures nÃƒÂ£o existirem
powershell -File .claude\serve.ps1 -Port 8791
```

Abrir **`http://127.0.0.1:8791/test.html`** Ã¢â‚¬â€ e nÃƒÂ£o a raiz. A raiz serve o
`index.html` publicado, que **nÃƒÂ£o tem** `__loadFromURL`: os ganchos de teste
saem do arquivo que as pessoas baixam, e `/test.html` serve o
`.claude/index-test.html`, que ÃƒÂ© o mesmo build com o bloco de ganchos. Os dois
saem do mesmo `template.html` e `build.ps1 -Check` valida os dois, entÃƒÂ£o nÃƒÂ£o
podem divergir em nada alÃƒÂ©m daquele bloco.

Colar `test/capture-golden.js` no console e `await __captureAll()`. Os quatro
artefatos por fixture caem em `.claude/shots/`. Depois:

```
powershell -File test\compare-golden.ps1      # nao-regressao, com tolerancia
powershell -File test\compare-reference.ps1   # correÃƒÂ§ÃƒÂ£o, contra o Python (ver nota)
powershell -File test\negative-controls.ps1   # a tolerÃƒÂ¢ncia ainda reprova?
```

E, no mesmo console do navegador, colar `test/compare-truth.js` e
`await __compareTruth()` Ã¢â‚¬â€ compara o modelo de fundo ajustado contra o gradiente
que estÃƒÂ¡ gravado nos cards `HISTORY` do `fixture-gradient.fit` e escreve
`gradient-truth.json`. Ãƒâ€° a ÃƒÂºnica verificaÃƒÂ§ÃƒÂ£o da suÃƒÂ­te que nÃƒÂ£o herda a fÃƒÂ³rmula
compartilhada; ver a seÃƒÂ§ÃƒÂ£o "O modelo contra a verdade", abaixo.

`negative-controls.ps1` nÃƒÂ£o precisa de captura nem de navegador: ele muta cÃƒÂ³pias
descartÃƒÂ¡veis dos prÃƒÂ³prios goldens e confere que o comparador chega ao veredito
certo em cada caso. Existe porque "controle negativo verificado" escrito numa
spec ÃƒÂ© uma afirmaÃƒÂ§ÃƒÂ£o que deixa de ser verdadeira no instante em que ninguÃƒÂ©m
consegue rodÃƒÂ¡-la de novo. SÃƒÂ£o 26 casos, e dois importam mais que os outros. O
`madn +8e-6` reprova pela regra de `span` e passaria pela regra de [0,1], que
nessa magnitude ÃƒÂ© **21 vezes** mais frouxa Ã¢â‚¬â€ ÃƒÂ© o ÃƒÂºnico caso capaz de distinguir
as duas. E o par `png every sample +1` contra `png one sample +1`: mesmo
veredito, mesma magnitude, mesmo limite, achados opostos. Ãƒâ€° o que prova que o
detector de deslocamento sistemÃƒÂ¡tico nÃƒÂ£o dispara em arredondamento comum.

Os casos ancoram em valores concretos dos goldens e **tÃƒÂªm que ser reancorados
quando os goldens mudam** Ã¢â‚¬â€ no passo 6 o `"clipLow": 266` deixou de existir
porque a correÃƒÂ§ÃƒÂ£o eliminou o corte de sombra, e o script parou com a mensagem
dizendo qual padrÃƒÂ£o nÃƒÂ£o achou. Falhar alto ÃƒÂ© o comportamento certo: um controle
negativo que se auto-desativasse em silÃƒÂªncio seria pior que nÃƒÂ£o existir.

> **NOTA SOBRE `compare-reference.ps1`, a partir do passo 6.** O `reference.py`
> modela o decode e o autostretch, e **nÃƒÂ£o** conhece a extraÃƒÂ§ÃƒÂ£o de fundo. Desde
> que a etapa passou a mexer em pixel, o bloco por canal compara dois quadros
> diferentes, e o comparador diz isso **uma vez** em vez de reprovar 63 nÃƒÂºmeros:
> `N/A Ã¢â‚¬â€ pipeline roda background e reference.py nao modela Ã¢â‚¬â€ passo 8 da Ã‚Â§6`.
>
> O que sobra do MÃƒÂ³dulo 0: **todo o bloco de decode**, nos quatro fixtures.
>
> Ãƒâ€° `N/A` e nÃƒÂ£o `KNOWN` de propÃƒÂ³sito. A lista `KNOWN` ÃƒÂ© para divergÃƒÂªncias entre
> duas implementaÃƒÂ§ÃƒÂµes que descrevem a mesma coisa; esta ÃƒÂ© as duas deixando de
> descrever a mesma coisa. Encher `KNOWN` com sessenta entradas transformaria um
> registro de dÃƒÂ­vida em papel de parede Ã¢â‚¬â€ Ã‚Â§7 do MÃƒÂ³dulo 0, "KNOWN nÃƒÂ£o ÃƒÂ© uma saÃƒÂ­da
> de emergÃƒÂªncia".
>
> **`referencia-cadeia.json` reabriu o bloco.** Ele monta a cadeia inteira Ã¢â‚¬â€
> decode, fundo, autostretch sobre o quadro **corrigido** Ã¢â‚¬â€ e volta a ser
> comparÃƒÂ¡vel nÃƒÂºmero a nÃƒÂºmero. Ver a seÃƒÂ§ÃƒÂ£o abaixo.

## A cadeia completa contra `chain.py`

`referencia-cadeia.json` fecha o que o passo 6 abriu. O comparador vai a **180
linhas: 174 PASS, 5 N/A, 1 FAIL.**

| fixture | linhas | PASS | FAIL | N/A |
|---|---|---|---|---|
| `seestar` | 13 | 11 | 0 | 2 |
| `rice` | 61 | 60 | 0 | 1 |
| `nonlinear` | 17 | 14 | 1 | 2 |
| `gradient` | 89 | 89 | 0 | 0 |

### A confirmaÃƒÂ§ÃƒÂ£o independente do bug do passo 6

O `before` do stretch **ÃƒÂ©** a mediÃƒÂ§ÃƒÂ£o do quadro corrigido. Que estes nÃƒÂºmeros
batam ÃƒÂ© confirmaÃƒÂ§ÃƒÂ£o de fora de que o conserto do passo 6 estÃƒÂ¡ certo: uma segunda
implementaÃƒÂ§ÃƒÂ£o, escrita depois e montada do zero, mede o mesmo MADN
pÃƒÂ³s-correÃƒÂ§ÃƒÂ£o. A razÃƒÂ£o entre o dela e o meu:

| `rice` | `nonlinear` | `gradient` |
|---|---|---|
| 1,0062 | 1,0034 | 0,9991 |

O `seestar` dÃƒÂ¡ 4,51 e **nÃƒÂ£o ÃƒÂ© discordÃƒÂ¢ncia**: a referÃƒÂªncia nÃƒÂ£o faz debayer, entÃƒÂ£o
o MADN dela ÃƒÂ© dominado pelo padrÃƒÂ£o Bayer, que nÃƒÂ£o ÃƒÂ© gradiente. O 0,000951 dela
coincide com o valor **prÃƒÂ©**-correÃƒÂ§ÃƒÂ£o daqui (0,000939) porque ÃƒÂ© a mesma
grandeza. Bloco por canal em N/A, mesma lacuna do MÃƒÂ³dulo 0.

### A que reprova, e o que ÃƒÂ©

**Uma linha: `nonlinear fundo.aceitas` 81 contra 82.** As consequÃƒÂªncias ficam
`N/A` com prÃƒÂ©-condiÃƒÂ§ÃƒÂ£o explÃƒÂ­cita no comparador Ã¢â‚¬â€ a tolerÃƒÂ¢ncia da Ã‚Â§7 pressupÃƒÂµe
que os dois lados medem **os mesmos pixels**, e conjuntos de amostras diferentes
significam superfÃƒÂ­cies diferentes.

A causa foi isolada e **nÃƒÂ£o ÃƒÂ© nenhuma das trÃƒÂªs suspeitas ÃƒÂ³bvias**: os limiares
concordam a 0,34 / 0,86 / 0,08 bins; a amostra marginal em (638, 563) estÃƒÂ¡ 6,2
bins acima do limiar **exato** tambÃƒÂ©m, entÃƒÂ£o os dois a rejeitam; e o critÃƒÂ©rio de
rejeiÃƒÂ§ÃƒÂ£o ÃƒÂ© idÃƒÂªntico. O que difere ÃƒÂ© **onde a caixa estÃƒÂ¡**: `Math.round(562,5)`
dÃƒÂ¡ 563 em JavaScript e 562 no Python, que arredonda meio para o par. SÃƒÂ³ o
`nonlinear` cai nisso, porque sÃƒÂ³ nele `w/cols = 75` produz centros em meio
exato. Registrado na Ã‚Â§2.1 do MÃƒÂ³dulo 1 como lacuna de especificaÃƒÂ§ÃƒÂ£o.

### As 6 que reprovavam antes do termo da mediana

Eram `mad`/`madn` acima do piso da Ã‚Â§7:

| | bins de span | limite |
|---|---|---|
| `rice` G, B `madn` | 8,75 / 9,45 | 8,00 |
| `gradient` R `mad`, `madn` | 14,58 / 21,62 | 8,00 |
| `gradient` B `mad`, `madn` | 8,59 / 12,74 | 8,00 |

**DiagnÃƒÂ³stico, e por que nÃƒÂ£o afrouxei o nÃƒÂºmero.** As medianas concordam
**muito** bem Ã¢â‚¬â€ 0,19 a 0,81 bins do eixo [0,1], contra um limite de 4. O que
falha ÃƒÂ© sÃƒÂ³ a dispersÃƒÂ£o. A causa ÃƒÂ© que `MAD = mediana(|v Ã¢Ë†â€™ m|)` ÃƒÂ© medida
**relativa ÃƒÂ  mediana**, e o piso da Ã‚Â§7 ÃƒÂ© dimensionado em bins de `span`, que
depois da correÃƒÂ§ÃƒÂ£o ficou 2,5 a 5Ãƒâ€” menor. Um deslocamento de mediana de 0,81 bins
do eixo [0,1] sÃƒÂ£o 143 bins de `span` Ã¢â‚¬â€ o MADN herda a incerteza da mediana
medida num eixo muito mais grosso.

**O termo entrou na Ã‚Â§7**, e ÃƒÂ© cota e nÃƒÂ£o ajuste: `MAD(m) = mediana(|vÃ¢Ë†â€™m|)` e
`Ã¢â‚¬â€“vÃ¢Ë†â€™mÃ¢Ë†â€™d|Ã¢Ë†â€™|vÃ¢Ë†â€™mÃ¢â‚¬â€“ Ã¢â€°Â¤ |d|` pela desigualdade triangular; a mediana ÃƒÂ© monÃƒÂ³tona, entÃƒÂ£o
a cota passa para o MAD. Vale antes de olhar os dados, para qualquer
distribuiÃƒÂ§ÃƒÂ£o.

    |a Ã¢Ë†â€™ b| Ã¢â€°Â¤ max( 1e-4Ã‚Â·|ref| ,  8Ã‚Â·span/65535  +  1,4826Ã‚Â·|ÃŽâ€mediana| )

Com ele as seis passam com folga Ã¢â‚¬â€ para `gradient` R o termo vale 1,84e-5 contra
um `ÃŽâ€madn` observado de 1,87e-6, dez vezes maior. **Controle negativo, para o
termo nÃƒÂ£o virar licenÃƒÂ§a:** `madn` perturbado em 3Ãƒâ€” a cota reprova; dentro da
cota passa. Auto-calibrado a partir do `span` do prÃƒÂ³prio golden e da mediana da
prÃƒÂ³pria referÃƒÂªncia, para nÃƒÂ£o envelhecer em silÃƒÂªncio como os ÃƒÂ¢ncoras de clip
envelheceram.

## O que o float pleno mudou, medido

O passo 2 do MÃƒÂ³dulo 1 tirou o LUT de 2^20 entradas do `stretch-mtf` e passou a
gravar MTF em precisÃƒÂ£o plena; `quantise` virou o ÃƒÂºnico lugar onde um nÃƒÂ­vel ÃƒÂ©
decidido. A tabela ÃƒÂ© a captura float comparada contra os goldens de 8 bits:

| artefato | veredito | o que aconteceu |
|---|---|---|
| `log.txt` Ãƒâ€” 3 | **PASS** byte a byte | todo nÃƒÂºmero que o log imprime vem do `before` do record de stretch, que nenhuma etapa a jusante move |
| `diag.json` Ãƒâ€” 3 | **PASS** byte a byte | mesmo motivo: o painel tambÃƒÂ©m ÃƒÂ© construÃƒÂ­do do `before` |
| `png` Ãƒâ€” 3 | **PASS~** | 0,031% a 0,781% das amostras diferem, **todas por exatamente 1 nÃƒÂ­vel** (mÃƒÂ©dia do \|d\| = 1,00) |
| `records.json` Ãƒâ€” 3 | **FAIL** | 23 a 24 campos, **todos em `after.perChannel[*]`**: median, mad, madn, span, q1, q3, p001, p999 |

Nenhum campo de `before` se moveu. Nenhuma contagem de clip se moveu Ã¢â‚¬â€
`outLow` e `outHigh` contam os mesmos dois ramos sobre o mesmo `u`, e a mudanÃƒÂ§a
nÃƒÂ£o os alcanÃƒÂ§a. Foi por isso que os goldens de log e diag sobreviveram: o que
mudou fica inteiramente a jusante da quantizaÃƒÂ§ÃƒÂ£o que saiu.

**A identidade que a cadeia de 8 bits escondia.** No ramo nÃƒÂ£o-linear o alvo do
autostretch ÃƒÂ© a prÃƒÂ³pria mediana do canal, entÃƒÂ£o `MTF` mapeia mediana em mediana
por construÃƒÂ§ÃƒÂ£o e `after.median` deve ser igual a `before.median`. Na cadeia de
8 bits isso era invisÃƒÂ­vel: a mediana pousava em 67/255 = 0,262745. Na cadeia
float ela pousa em 0,2640573739223316 Ã¢â‚¬â€ o mesmo dÃƒÂ­gito a dÃƒÂ­gito que
`before.median`, nos canais R e B; 3,05e-5 no G, que ÃƒÂ© resoluÃƒÂ§ÃƒÂ£o de histograma.
Isso ÃƒÂ© evidÃƒÂªncia independente de que o caminho novo estÃƒÂ¡ certo, e nÃƒÂ£o apenas
diferente.

**Reprodutibilidade verificada.** Uma segunda captura independente, depois de
recarregar a pÃƒÂ¡gina, devolveu os doze artefatos byte a byte idÃƒÂªnticos aos
goldens promovidos. A tolerÃƒÂ¢ncia existe para mudanÃƒÂ§a de build, nÃƒÂ£o para ruÃƒÂ­do
de rodada Ã¢â‚¬â€ nÃƒÂ£o hÃƒÂ¡ ruÃƒÂ­do de rodada.

**Custo.** `transfer`, relÃƒÂ³gio de parede, uma amostra por fixture: 244Ã¢â€ â€™216,
233Ã¢â€ â€™268, 134Ã¢â€ â€™96 ms. `quantise` passou a aparecer separado, em 23 a 71 ms. NÃƒÂ£o ÃƒÂ©
mediÃƒÂ§ÃƒÂ£o Ã¢â‚¬â€ ÃƒÂ© uma amostra Ã¢â‚¬â€ e nÃƒÂ£o hÃƒÂ¡ evidÃƒÂªncia de regressÃƒÂ£o que importe. O
orÃƒÂ§amento real da Ã‚Â§3.6 do MÃƒÂ³dulo 1 ÃƒÂ© o arraste sobre o buffer de preview, e ÃƒÂ© lÃƒÂ¡
que isso precisa ser medido de verdade quando a RBF entrar.

## Fixtures Ã¢â‚¬â€ todos sintÃƒÂ©ticos

**Nenhum arquivo de terceiro entra aqui.** Ver `CLAUDE.md`. Os cinco saem de
`.claude/make-fixture.ps1` com semente fixa e sÃƒÂ£o reprodutÃƒÂ­veis byte a byte Ã¢â‚¬â€
verificado: regerar o `fixture-seestar.fit` devolve o mesmo sha256 do arquivo
versionado.

| nome | arquivo | bytes | sha256 |
|---|---|---|---|
| `seestar-fixture` | `test/fixtures/fixture-seestar.fit` | 4.150.080 | `6d0acf7bbd4ce595d926ccc9bbf8e239447cda8ed7207c682fe598f5534cb28b` |
| `rice-fixture` | `test/fixtures/fixture-rice.fit.fz` | 8.671.680 | ver `make-fixture.ps1` |
| `nonlinear-fixture` | `test/fixtures/fixture-nonlinear.fit` | 6.482.880 | ver `make-fixture.ps1` |
| `gradient-fixture` | `test/fixtures/fixture-gradient.fit` | 23.042.880 | `b14ac76614949a4feef20e1c9aa263b29813f7b2a7298f9b461388d482e1fc25` |
| `edge-fixture` | `test/fixtures/fixture-edge.fit` | 1.442.880 | `3f18a50b3e896aab13683cb0b88abd4cc2f26c6a399dcf71072b8531d64ebf38` |

Cinco, e nÃƒÂ£o um, porque cobrem caminhos disjuntos:

- **`seestar-fixture`** Ã¢â‚¬â€ 1920Ãƒâ€”1080, BITPIX 16, BZERO 32768, ROWORDER BOTTOM-UP,
  BAYERPAT GRBG. Leitura de inteiro, flip de linha, detecÃƒÂ§ÃƒÂ£o de CFA, debayer,
  ramo linear. `view.factor` 1.
- **`rice-fixture`** Ã¢â‚¬â€ 2600Ãƒâ€”1000Ãƒâ€”3, RICE_1 com SUBTRACTIVE_DITHER_2, uma tile
  por linha (3.000 tiles). DescompressÃƒÂ£o Rice, dither, caminho de 3 planos sem
  debayer. A borda longa ÃƒÂ© 2600 **de propÃƒÂ³sito**: passa de `MAX_VIEW` (2560) por
  40 px, entÃƒÂ£o `view.factor` = 2 e o PNG vem do buffer de resoluÃƒÂ§ÃƒÂ£o plena, que ÃƒÂ©
  o caminho que o botÃƒÂ£o de download realmente usa.

  Traz duas armadilhas embutidas de propÃƒÂ³sito: um patch 24Ãƒâ€”24 de zeros exatos,
  que exercita o sentinela `DITHER_ZERO` do dither 2 (aparece como 576 pixels
  pretos por canal no diagnÃƒÂ³stico), e uma quantizaÃƒÂ§ÃƒÂ£o com `ZZERO Ã¢â€°Ë† 13313,9`
  contra `ZSCALE = 6,2e-6`, que deixa os inteiros logo acima do piso do int32 Ã¢â‚¬â€
  a configuraÃƒÂ§ÃƒÂ£o que obriga o unquantize a ficar em double.
- **`nonlinear-fixture`** Ã¢â‚¬â€ 900Ãƒâ€”600Ãƒâ€”3, float32 sem compressÃƒÂ£o, ROWORDER
  TOP-DOWN, com cards HISTORY de autostretch e mediana medida 0,2467. Ramo
  nÃƒÂ£o-linear: ponto preto por percentil, alvo na prÃƒÂ³pria mediana. O midtones do
  gerador foi calibrado para pousar a mediana em ~0,25, que ÃƒÂ© onde um frame
  realmente esticado no Siril fica Ã¢â‚¬â€ um valor mais agressivo levava a mediana
  para 0,73 e o fixture deixava de representar o caso.
- **`gradient-fixture`** Ã¢â‚¬â€ 1600Ãƒâ€”1200Ãƒâ€”3, float32, TOP-DOWN. Para o MÃƒÂ³dulo 1.
  Ver a seÃƒÂ§ÃƒÂ£o prÃƒÂ³pria abaixo: ÃƒÂ© o ÃƒÂºnico da suÃƒÂ­te cujo fundo ÃƒÂ© conhecido
  independentemente das duas implementaÃƒÂ§ÃƒÂµes.
- **`edge-fixture`** Ã¢â‚¬â€ 400Ãƒâ€”300Ãƒâ€”3, float32, TOP-DOWN. 1,44 MB, o mais barato da
  suÃƒÂ­te, e o ÃƒÂºnico pequeno o bastante para a margem **padrÃƒÂ£o** alcanÃƒÂ§ar a grade
  de amostras: 38 das 108 amostras sÃƒÂ£o rejeitadas por borda, 6 por brilho, 64
  aceitas. Existe porque `rejected-edge` era alcanÃƒÂ§ÃƒÂ¡vel e nÃƒÂ£o exercitado Ã¢â‚¬â€ o
  estado aparecia na spec, no cÃƒÂ³digo e no tooltip, e em nenhum golden. Cobre de
  passagem o caso de quadro pequeno, que tambÃƒÂ©m nÃƒÂ£o tinha nada.

## `fixture-gradient.fit` Ã¢â‚¬â€ o ÃƒÂºnico com uma verdade externa

Os outros trÃƒÂªs respondem "hoje ÃƒÂ© igual a ontem?" e "as duas implementaÃƒÂ§ÃƒÂµes
concordam?". Nenhuma das duas perguntas alcanÃƒÂ§a um erro de fÃƒÂ³rmula, porque a
referÃƒÂªncia do Python leu a fÃƒÂ³rmula daqui Ã¢â‚¬â€ estÃƒÂ¡ registrado na Ã‚Â§7 do MÃƒÂ³dulo 0 e
na Ã‚Â§5 do MÃƒÂ³dulo 1. Este responde a uma terceira: **o modelo ajustado ÃƒÂ© o
gradiente que eu coloquei?**

O que estÃƒÂ¡ gravado em cards `HISTORY`, e ÃƒÂ© lido de volta pelo teste:

```
g(u,v) = A0 + A1*u + A2*v + A3*u^2 + A4*v^2 + A5*u*v
u = x/(NAXIS1-1)   v = y/(NAXIS2-1)   TOP-DOWN, entÃƒÂ£o v=0 ÃƒÂ© a primeira linha
```

com os seis coeficientes por canal, mais a geometria do objeto estendido
(`CX CY A B PEAK K`, perfil `I = PEAK*exp(-K*R)` em raio elÃƒÂ­ptico), as posiÃƒÂ§ÃƒÂµes
das estrelas-sonda, o sigma do ruÃƒÂ­do e as sementes. 21 cards. O gerador escreve
os cards **das mesmas variÃƒÂ¡veis** que passa ao construtor da cena, entÃƒÂ£o nÃƒÂ£o hÃƒÂ¡
dois lugares onde o nÃƒÂºmero possa divergir.

**Por que TOP-DOWN:** o flip de linha jÃƒÂ¡ estÃƒÂ¡ coberto pelo `seestar-fixture`.
Aqui a clareza do contrato vale mais Ã¢â‚¬â€ com TOP-DOWN as coordenadas do `HISTORY`
sÃƒÂ£o as coordenadas da imagem, sem inversÃƒÂ£o no meio da comparaÃƒÂ§ÃƒÂ£o.

**Por que 1600Ãƒâ€”1200:** nÃƒÂ£o ÃƒÂ© nÃƒÂºmero redondo. Com `samplesPerRow` 12 a grade ÃƒÂ©
12Ãƒâ€”9, e com `PREVIEW_EDGE` 1024 o fator de preview ÃƒÂ© 2 Ã¢â‚¬â€ entÃƒÂ£o o fixture
exercita o escalonamento de `boxSize` da Ã‚Â§2.1, que ÃƒÂ© a exigÃƒÂªncia de que uma
caixa de amostra signifique o mesmo pedaÃƒÂ§o de cÃƒÂ©u no preview e no render.

**Por que ruÃƒÂ­do gaussiano, e nÃƒÂ£o uniforme como nos outros:** a rejeiÃƒÂ§ÃƒÂ£o ÃƒÂ©
`mediana da caixa > mediana global + tolerance Ãƒâ€” MADN`, e MADN sÃƒÂ³ significa
"sigma" para ruÃƒÂ­do gaussiano. Com ruÃƒÂ­do uniforme o limiar de rejeiÃƒÂ§ÃƒÂ£o cairia num
lugar sem interpretaÃƒÂ§ÃƒÂ£o e o fixture estaria testando outra coisa.

### Medido no fixture gerado, com os parÃƒÂ¢metros padrÃƒÂ£o da Ã‚Â§2.2

Grade 12Ãƒâ€”9 = 108 amostras, caixa 25 px, margem 24 px, `tolerance` 1,0:

| | |
|---|---|
| aceitas | 93 |
| rejeitadas por brilho | 15, das quais **12 sobre o objeto** |
| rejeitadas por borda | 0 |
| fraÃƒÂ§ÃƒÂ£o rejeitada | 13,9% |

Fica bem acima da salvaguarda de 8 pontos e bem abaixo dos 40% que a Ã‚Â§3.5 manda
avisar. O objeto forÃƒÂ§a rejeiÃƒÂ§ÃƒÂ£o, que ÃƒÂ© para o que ele existe.

**ResÃƒÂ­duo |mediana da caixa Ã¢Ë†â€™ verdade| nas aceitas: mÃƒÂ¡ximo 0,242 nÃƒÂ­vel de 255,
mÃƒÂ©dio 0,030.** A Ã‚Â§5 sugere 1 nÃƒÂ­vel como tolerÃƒÂ¢ncia de partida para o modelo
ajustado contra o gradiente verdadeiro; a amostragem sozinha jÃƒÂ¡ entrega um
quarto disso, entÃƒÂ£o o orÃƒÂ§amento sobra para a RBF.

### A mediana sobrevive ÃƒÂ  estrela; a mÃƒÂ©dia nÃƒÂ£o

Oito estrelas-sonda em posiÃƒÂ§ÃƒÂµes gravadas, `PEAK` 0,45 e `sigma` 2,2. O sigma ÃƒÂ©
pequeno de propÃƒÂ³sito: numa caixa de 625 pixels a estrela levanta cerca de 22%
deles, confortavelmente abaixo de metade. Um sigma maior viraria a mediana
tambÃƒÂ©m e o fixture passaria a argumentar o contrÃƒÂ¡rio do que a Ã‚Â§2.1 afirma.

Nas caixas que contÃƒÂªm uma sonda, canal G, em nÃƒÂ­veis de 255:

| desvio da mediana | desvio da mÃƒÂ©dia |
|---|---|
| 0,08 a 0,30 | **5,1 a 5,8** |

Cerca de **20Ãƒâ€” pior para a mÃƒÂ©dia**. Ãƒâ€° a Ã‚Â§2.1 deixando de ser asserÃƒÂ§ÃƒÂ£o e virando
nÃƒÂºmero.

### Duas coisas que o fixture expÃƒÂµe de graÃƒÂ§a

**A fraqueza da tolerÃƒÂ¢ncia global.** Uma das oito caixas-sonda, em (1253, 1112),
ÃƒÂ© rejeitada por brilho Ã¢â‚¬â€ e ali nÃƒÂ£o hÃƒÂ¡ objeto nenhum, sÃƒÂ³ fundo mais uma estrela.
No canto claro do gradiente o prÃƒÂ³prio fundo jÃƒÂ¡ passa de
`mediana global + 1,0 Ãƒâ€” MADN`. Ãƒâ€° exatamente a queixa registrada contra o Siril
na Ã‚Â§1 ("tolerÃƒÂ¢ncia global ÃƒÂºnica para a imagem inteira"), reproduzida num arquivo
onde dÃƒÂ¡ para medir. NÃƒÂ£o ÃƒÂ© defeito do fixture: ÃƒÂ© o defeito que o MÃƒÂ³dulo 1b
promete resolver, disponÃƒÂ­vel para teste antes de a soluÃƒÂ§ÃƒÂ£o existir.

**Custo em disco, e a decisÃƒÂ£o sobre ele.** 23,0 MB, contra 19,3 MB dos outros
trÃƒÂªs somados; a ÃƒÂ¡rvore de fixtures passa a 42,3 MB.

**Fica assim: 1600Ãƒâ€”1200, sem compressÃƒÂ£o. Decidido, nÃƒÂ£o pendente.**

Encolher o quadro perde o que ele testa Ã¢â‚¬â€ a grade 12Ãƒâ€”9 e o fator de preview 2
sÃƒÂ£o os dois motivos de ele ter esse tamanho. E comprimir para `.fz` misturaria o
caminho Rice com o caminho do gradiente: uma falha neste fixture passaria a ter
duas explicaÃƒÂ§ÃƒÂµes possÃƒÂ­veis, e separar as duas custaria mais do que os 23 MB
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

Os PNG cresceram entre 15% e 24%: o dither substitui bandas lisas por ruÃƒÂ­do, e
ruÃƒÂ­do nÃƒÂ£o comprime. Ãƒâ€° o custo direto de nÃƒÂ£o ter bandas.

`gradient-truth.json` ÃƒÂ© o ÃƒÂºnico destes que `compare-golden.ps1` **nÃƒÂ£o** compara:
ele vem de `compare-truth.js`, nÃƒÂ£o da captura, e ÃƒÂ© medida de referÃƒÂªncia e nÃƒÂ£o
artefato de saÃƒÂ­da. Comparar automaticamente entra junto com o passo 8, quando o
`reference.py` conhecer o fixture.

### O que o passo 4 mudou nestes goldens, medido

A etapa de fundo entrou na cadeia amostrando e rejeitando, sem ajustar
superfÃƒÂ­cie e sem tocar em pixel. Contra os goldens do passo 3:

| artefato | veredito |
|---|---|
| `log.txt` Ãƒâ€” 4 | **PASS** byte a byte |
| `diag.json` Ãƒâ€” 4 | **PASS** byte a byte |
| `png` Ãƒâ€” 4 | **PASS** byte a byte |
| `records.json` Ãƒâ€” 4 | **FAIL**, `length 1 vs 2` |

O PNG idÃƒÂªntico ÃƒÂ© a verificaÃƒÂ§ÃƒÂ£o de que a etapa devolve a imagem intacta: se um
pixel tivesse se movido, ele apareceria. O log idÃƒÂªntico ÃƒÂ© a verificaÃƒÂ§ÃƒÂ£o de que
"background extraction" continua na frase "Not applied" Ã¢â‚¬â€ `applied: false`, e
`notAppliedLabels` chaveia nisso. E o `records.json` reprova por **mudanÃƒÂ§a
estrutural**, nÃƒÂ£o por deriva numÃƒÂ©rica: a cadeia ganhou um record, e nenhuma
tolerÃƒÂ¢ncia deve perdoar isso.

Os `records.json` cresceram de ~3,8 KB para 22Ã¢â‚¬â€œ35 KB. Ãƒâ€° a lista de pontos: cada
amostra com coordenada, estado, mediana por canal e a frase que diz por que foi
rejeitada. A Ã‚Â§2.2 pede que o motivo esteja no record e nÃƒÂ£o sÃƒÂ³ no tooltip, e um
ponto rejeitado que some do registro ÃƒÂ© a operaÃƒÂ§ÃƒÂ£o silenciosa que a confusÃƒÂ£o 21
proÃƒÂ­be. 117 KB somados, contra 16,5 MB de PNG nos mesmos goldens.

## O modelo contra a verdade Ã¢â‚¬â€ passo 5

`test/compare-truth.js` roda no navegador, ajusta a superfÃƒÂ­cie com o cÃƒÂ³digo
entregue e compara contra os coeficientes do gradiente lidos de volta dos cards
`HISTORY`. O relatÃƒÂ³rio fica em `test/golden/gradient-truth.json`.

Isto ÃƒÂ© o que `compare-golden` e `compare-reference` nÃƒÂ£o conseguem responder. Um
pergunta se hoje ÃƒÂ© igual a ontem; o outro se as duas implementaÃƒÂ§ÃƒÂµes concordam Ã¢â‚¬â€
e elas concordam sobre uma fÃƒÂ³rmula que foi lida deste cÃƒÂ³digo. Um erro de fÃƒÂ³rmula
ÃƒÂ© invisÃƒÂ­vel para os dois. Aqui a resposta vem de nÃƒÂºmeros que o gerador escreveu
e que nenhuma das duas implementaÃƒÂ§ÃƒÂµes viu.

### ResÃƒÂ­duo `|modelo Ã¢Ë†â€™ gradiente verdadeiro|`, em nÃƒÂ­veis de 255

| regiÃƒÂ£o | mÃƒÂ¡ximo | mÃƒÂ©dio |
|---|---|---|
| fora do objeto (raio elÃƒÂ­ptico > 2) | **0,168** | 0,031 |
| no canto que a rejeiÃƒÂ§ÃƒÂ£o global descarta | **0,168** | 0,067 |
| sob o objeto (raio Ã¢â€°Â¤ 1) | 0,840 | 0,649 |

A Ã‚Â§5 do MÃƒÂ³dulo 1 sugere 1 nÃƒÂ­vel como tolerÃƒÂ¢ncia de partida fora das regiÃƒÂµes
rejeitadas. O medido ÃƒÂ© **0,168** Ã¢â‚¬â€ seis vezes dentro.

O resÃƒÂ­duo sob o objeto **nÃƒÂ£o ÃƒÂ© erro**: ali o esperado ÃƒÂ© o gradiente sozinho,
porque o objeto ÃƒÂ© sinal a preservar e nÃƒÂ£o fundo a remover. O nÃƒÂºmero mede
**contaminaÃƒÂ§ÃƒÂ£o** Ã¢â‚¬â€ quanto do objeto vazou para o modelo e seria subtraÃƒÂ­do dele
no passo 6.

### ContaminaÃƒÂ§ÃƒÂ£o, e o que a rejeiÃƒÂ§ÃƒÂ£o compra

O pico do objeto vale 13,39 nÃƒÂ­veis. O modelo absorve 0,840 Ã¢â€ â€™ **6,27%**.

| `tolerance` | aceitas | contaminaÃƒÂ§ÃƒÂ£o | resÃƒÂ­duo fora do objeto |
|---|---|---|---|
| 10 (sem rejeiÃƒÂ§ÃƒÂ£o) | 108 | **38,9%** | 0,267 |
| 2,0 | 101 | 10,96% | 0,148 |
| **1,0 (padrÃƒÂ£o)** | **93** | **6,27%** | **0,168** |
| 0,5 | 72 | 5,43% | 0,170 |
| 0,25 | 62 | 4,27% | 0,216 |
| 0,0 | 54 | 4,35% | 0,333 |

**A rejeiÃƒÂ§ÃƒÂ£o vale um fator de 6.** Sem ela o modelo come 38,9% do objeto Ã¢â‚¬â€ trÃƒÂªs
vezes pior que os 12,5% que o GraXpert perdeu num braÃƒÂ§o do M31 (Ã‚Â§1). Com ela,
6,27%, entre os 12,5% do modo IA e os 5% do ajuste manual.

Apertar alÃƒÂ©m de 1,0 rende pouco e cobra: a contaminaÃƒÂ§ÃƒÂ£o para de melhorar perto
de 4% enquanto o resÃƒÂ­duo fora do objeto piora de 0,168 para 0,333. O padrÃƒÂ£o 1,0
estÃƒÂ¡ perto do joelho da curva, e agora isso ÃƒÂ© medida e nÃƒÂ£o escolha.

### Erro da interpolaÃƒÂ§ÃƒÂ£o Ã¢â‚¬â€ medido, nÃƒÂ£o presumido

A Ã‚Â§2.3 manda avaliar numa grade de 1/8 e interpolar, e **medir** o erro contra
avaliaÃƒÂ§ÃƒÂ£o direta em 1000 pixels, aumentando a grade se passar de 0,5 nÃƒÂ­vel.

| fixture | grade | erro mÃƒÂ¡ximo |
|---|---|---|
| `seestar` | 241Ãƒâ€”136 | 0,0001 |
| `rice` | 326Ãƒâ€”126 | 0,0000 |
| `nonlinear` | 114Ãƒâ€”76 | 0,0039 |
| `gradient` | 201Ãƒâ€”151 | 0,0004 |

Duas ordens de grandeza dentro do limite no pior caso. O divisor nunca precisou
aumentar Ã¢â‚¬â€ mas isso ÃƒÂ© resultado, nÃƒÂ£o premissa, e ÃƒÂ© remedido a cada execuÃƒÂ§ÃƒÂ£o.

Os 1000 pixels sÃƒÂ£o varridos por passo primo (104729) sobre o ÃƒÂ­ndice, que ÃƒÂ©
ÃƒÂ­mpar e portanto coprimo com qualquer potÃƒÂªncia de dois: sondas consecutivas
caem em fases diferentes dentro da cÃƒÂ©lula da grade, que ÃƒÂ© onde o erro vive. Um
passo que compartilhasse fator com o divisor amostraria os cantos das cÃƒÂ©lulas e
reportaria zero.

## Passo 6 Ã¢â‚¬â€ a correÃƒÂ§ÃƒÂ£o, e o que medi-la encontrou

A correÃƒÂ§ÃƒÂ£o ÃƒÂ© `out = in Ã¢Ë†â€™ model + pedestal`, com o pedestal sendo a mediana do
prÃƒÂ³prio modelo, **por canal**. A partir daqui a etapa reporta `applied: true`.

### A razÃƒÂ£o entre canais sobrevive Ã¢â‚¬â€ e o nÃƒÂºmero que sustenta a frase de log

Medido no `fixture-rice`, mediana de fundo antes e depois da correÃƒÂ§ÃƒÂ£o:

| | antes | depois | deriva |
|---|---|---|---|
| R/G | 1,099312 | 1,099010 | **Ã¢Ë†â€™0,028%** |
| B/G | 0,920354 | 0,919802 | **Ã¢Ë†â€™0,060%** |

E o contrafactual, aritmeticamente, se o pedestal fosse **ÃƒÂºnico** (a mÃƒÂ©dia dos
trÃƒÂªs) em vez de por canal:

| | resultado | deriva |
|---|---|---|
| R/G | 0,999904 | **Ã¢Ë†â€™9,04%** |
| B/G | 0,999918 | **+8,64%** |

O pedestal ÃƒÂºnico colapsa as duas razÃƒÂµes para 1,0: ele **lava a cor do fundo**.
Por canal preserva ~150Ãƒâ€” melhor. Nos quatro fixtures a deriva por canal fica
entre 0,016% e 0,44%; a de pedestal ÃƒÂºnico, entre 6,6% e 11,2%.

Ãƒâ€° este o nÃƒÂºmero por trÃƒÂ¡s da frase *"the ratio between channels is therefore
unchanged: no colour grading"*, que agora estÃƒÂ¡ no log.

### Negativos, e por que a contagem zero aqui nÃƒÂ£o ÃƒÂ© clamp

A regra ÃƒÂ© nÃƒÂ£o clampear, e o teste natural Ã¢â‚¬â€ "se nÃƒÂ£o sobrou negativo, algo
clampeou" Ã¢â‚¬â€ dÃƒÂ¡ **falso alarme nestes fixtures**. Medido no `fixture-gradient`,
canal R:

| | mÃƒÂ­nimo | negativos |
|---|---|---|
| entrada | 0,007542 | 0 |
| corrigido, pedestal real | **0,012405** | 0 |
| corrigido, pedestal forÃƒÂ§ado a 0 | **Ã¢Ë†â€™0,005950** | 882.624 (46%) |

O sinal de clamp nÃƒÂ£o ÃƒÂ© a contagem, ÃƒÂ© **o mÃƒÂ­nimo pousar exatamente em zero**. Ele
pousa em 0,0124, longe de zero, e com o pedestal zerado os 882 mil negativos
atravessam intactos. Nada clampeia.

A contagem zero ÃƒÂ© aritmÃƒÂ©tica: o pedestal (0,0184) ÃƒÂ© maior que a excursÃƒÂ£o do
modelo acima da prÃƒÂ³pria mediana (~0,0064), entÃƒÂ£o `in Ã¢Ë†â€™ model + pedestal` nÃƒÂ£o
alcanÃƒÂ§a zero. **Lacuna de cobertura:** nenhum fixture tem gradiente forte o
bastante em relaÃƒÂ§ÃƒÂ£o ao nÃƒÂ­vel de fundo para produzir negativos no caminho normal.
Dado real com poluiÃƒÂ§ÃƒÂ£o luminosa forte produz.

### O dither ÃƒÂ© determinÃƒÂ­stico

Duas capturas independentes, cada uma depois de recarregar a pÃƒÂ¡gina: os quatro
PNG **byte a byte idÃƒÂªnticos**. Semente 20260906, amplitude Ã‚Â±0,5 nÃƒÂ­vel, ambas no
record do `quantise` e no log.

### O bug que a correÃƒÂ§ÃƒÂ£o expÃƒÂ´s: o stretch media o quadro errado

`stepStretchMTF` recebia a mediÃƒÂ§ÃƒÂ£o tirada **antes** da etapa de fundo. Enquanto
a etapa sÃƒÂ³ amostrava isso era inofensivo Ã¢â‚¬â€ as duas mediam os mesmos pixels Ã¢â‚¬â€ e
virou errado no instante em que um pixel se moveu.

O MADN ÃƒÂ© a parte que importa, porque o ponto preto ÃƒÂ© `mediana Ã¢Ë†â€™ 2,8 Ãƒâ€” MADN`, e o
gradiente removido fazia parte da dispersÃƒÂ£o que o MADN media:

| fixture | MADN antes | MADN depois | fator |
|---|---|---|---|
| `seestar` | 0,000939 | 0,000211 | **4,5Ãƒâ€”** |
| `rice` | 0,001868 | 0,000364 | **5,1Ãƒâ€”** |
| `nonlinear` | 0,019943 | 0,005833 | **3,4Ãƒâ€”** |
| `gradient` | 0,003549 | 0,001395 | **2,5Ãƒâ€”** |

O ponto preto estava de 2,5 a 5 vezes fundo demais, em todo quadro.

**E era invisÃƒÂ­vel na mÃƒÂ©trica de saÃƒÂ­da:** a mediana pÃƒÂ³s-esticamento fica em ~64
de qualquer jeito, porque o MTF mapeia mediana no alvo seja qual for o MADN. Ãƒâ€° a
mesma classe do erro do ÃŽÂ» Ã¢â‚¬â€ nÃƒÂ£o falha, nÃƒÂ£o avisa, e fica pior para sempre. O
`before` do stretch passa a vir do `after` da etapa de fundo, que jÃƒÂ¡ estava
medido e custava zero.

## Passo 7 Ã¢â‚¬â€ a frase "Not applied", verificada nos dois sentidos

O passo 7 era verificaÃƒÂ§ÃƒÂ£o, e o que havia a verificar jÃƒÂ¡ tinha acontecido
sozinho: a frase perdeu "background extraction" no passo 6, **com zero ediÃƒÂ§ÃƒÂµes
em `registry.js`** Ã¢â‚¬â€ o arquivo nÃƒÂ£o ÃƒÂ© tocado desde o passo 5 do MÃƒÂ³dulo 0.

Verificar que o rÃƒÂ³tulo sumiu ÃƒÂ© fraco: uma string apagada tambÃƒÂ©m some. A prova ÃƒÂ©
o **round-trip**, e ela passa pelo `buildLog` real:

| `background.applied` | descreve a etapa | nega a etapa |
|---|---|---|
| `true` | **1 linha** | ausente da frase |
| `false` | 0 linhas | **presente na frase** |

Os dois se movem juntos e em direÃƒÂ§ÃƒÂµes opostas. O invariante nÃƒÂ£o ÃƒÂ© "o rÃƒÂ³tulo
some", ÃƒÂ© **o log ou descreve a operaÃƒÂ§ÃƒÂ£o ou a nega, nunca nenhum dos dois e nunca
os dois**. Foi essa a segunda metade que o passo 6 quase deixou aberta: a frase
parou de negar antes de alguÃƒÂ©m escrever a que afirma.

Com `applied: false`, a frase volta **idÃƒÂªntica** ÃƒÂ  de antes do MÃƒÂ³dulo 1 Ã¢â‚¬â€
comparada contra o resultado de `notAppliedLabels` sem nenhum record de fundo.

E o guarda do catÃƒÂ¡logo continua vivo: um passo declarado `neverImplemented`
reportando que rodou faz `notAppliedLabels` recusar produzir log, em vez de
produzir um que negue o que acabou de acontecer. Verificado com `id: 'ai'`.

## Grade sobre o quadro inteiro Ã¢â‚¬â€ e as duas implementaÃƒÂ§ÃƒÂµes coincidindo

A grade deixou de ser encaixada dentro da margem. Centro em `(i+0,5)Ã‚Â·w/cols`; a
margem ÃƒÂ© sÃƒÂ³ critÃƒÂ©rio de rejeiÃƒÂ§ÃƒÂ£o, que ÃƒÂ© o que a Ã‚Â§2.2 sempre disse.

**Depois da mudanÃƒÂ§a, contra `reference_bg.py`:**

| | esta implementaÃƒÂ§ÃƒÂ£o | `reference_bg.py` | diferenÃƒÂ§a |
|---|---|---|---|
| amostras aceitas | 92 | 92 | 0 |
| rejeitadas por brilho | 16 | 16 | 0 |
| campo limpo R, mÃƒÂ¡ximo | 0,111218 | 0,111214 | 4,5e-6 nÃƒÂ­vel |
| campo limpo R, mÃƒÂ©dia | 0,011537 | 0,011537 | 2,4e-7 nÃƒÂ­vel |
| campo limpo G, mÃƒÂ¡ximo | 0,129388 | 0,129384 | 4,1e-6 nÃƒÂ­vel |
| campo limpo B, mÃƒÂ¡ximo | 0,111776 | 0,111772 | 3,6e-6 nÃƒÂ­vel |
| pedestal R | 0,018307595 | 0,018308640 | 0,00027 nÃƒÂ­vel |

**Cinco algarismos significativos**, com grades independentes e ÃƒÂ¡lgebra
independente (`numpy.linalg.solve` contra eliminaÃƒÂ§ÃƒÂ£o de Gauss escrita ÃƒÂ  mÃƒÂ£o). O
resÃƒÂ­duo de 4,5e-6 nÃƒÂ­vel ÃƒÂ© 1,7e-8 em [0,1] e tem causa identificada: as duas
avaliam a superfÃƒÂ­cie em retÃƒÂ­culas de tamanhos diferentes Ã¢â‚¬â€ 201Ãƒâ€”151 aqui,
200Ãƒâ€”150 lÃƒÂ¡ Ã¢â‚¬â€ entÃƒÂ£o o valor interpolado num pixel difere nessa ordem. O pedestal
difere um pouco mais porque ÃƒÂ© a **mediana** dessa retÃƒÂ­cula, e as duas tomam a
mediana sobre conjuntos de nÃƒÂ³s diferentes.

Antes da mudanÃƒÂ§a eram 93 contra 92 aceitas e 0,1688 contra 0,1112 no campo
limpo. **"Grade diferente e ÃƒÂ¡lgebra diferente" era uma causa sÃƒÂ³.**

**O que a mudanÃƒÂ§a custou e rendeu**, medido no `fixture-gradient`:

| | grade encaixada | quadro inteiro |
|---|---|---|
| campo limpo fora do casco das amostras | 31,4% | Ã¢â‚¬â€ |
| campo limpo, mÃƒÂ¡ximo | 0,1688 | **0,1112** |
| campo limpo, mÃƒÂ©dia | 0,0337 | **0,0115** |
| casco das amostras | 1422Ãƒâ€”1024 | 1466Ãƒâ€”1066 |

### Amostragem, por fixture

| fixture | quadro | grade | caixa | geradas | aceitas | brilho | borda |
|---|---|---|---|---|---|---|---|
| `seestar` | 1920Ãƒâ€”1080 | 12Ãƒâ€”7 | 25 | 84 | 72 | 12 | 0 |
| `rice` | 2600Ãƒâ€”1000 | 12Ãƒâ€”5 | 25 | 60 | 53 | 7 | 0 |
| `nonlinear` | 900Ãƒâ€”600 | 12Ãƒâ€”8 | 25 | 96 | 85 | 11 | 0 |
| `gradient` | 1600Ãƒâ€”1200 | 12Ãƒâ€”9 | 25 | 108 | 93 | 15 | 0 |

Os quatro reportam `applied: false` com o mesmo `skipReason`: *sampling only*.

**VerificaÃƒÂ§ÃƒÂ£o cruzada do `gradient`:** 93/15/0/0 ÃƒÂ© exatamente o que a anÃƒÂ¡lise
independente em PowerShell tinha medido no fixture, e ela usou mediana e MAD por
**seleÃƒÂ§ÃƒÂ£o exata** enquanto a etapa usa **histograma de 65536 bins**. Dois
estimadores diferentes do limiar, 108 vereditos idÃƒÂªnticos.

**Preview contra render, medido:** com o buffer reduzido a 800Ãƒâ€”600 e `boxSize`
escalado de 25 para 13, os 108 pontos recebem a **mesma classificaÃƒÂ§ÃƒÂ£o** e a
maior diferenÃƒÂ§a de mediana de caixa ÃƒÂ© **0,0185 nÃƒÂ­vel de 255**. Ãƒâ€° a afirmaÃƒÂ§ÃƒÂ£o da
Ã‚Â§2.1 sobre correspondÃƒÂªncia preview/render, com nÃƒÂºmero.

O `.diag.json` ÃƒÂ© `JSON.stringify(state.diag, null, 2)` Ã¢â‚¬â€ o objeto cru, nÃƒÂ£o o
`dump()` do painel, que arredonda para 8 dÃƒÂ­gitos significativos. Guardar o cru
significa que uma regressÃƒÂ£o de ponto flutuante aparece em vez de ser arredondada
para fora. (Os sha256 do diag mudam a cada captura por causa de `timingsMs`; os
da tabela sÃƒÂ£o do arquivo versionado.)

## O que nÃƒÂ£o ÃƒÂ© estÃƒÂ¡vel, e o que deixou de nÃƒÂ£o ser

**`timingsMs`** no diagnÃƒÂ³stico continua sendo relÃƒÂ³gio de parede.
`compare-golden.ps1` recorta o bloco dos dois lados antes de comparar. Ãƒâ€° a ÃƒÂºnica
coisa que ele ignora inteiramente, em vez de comparar com tolerÃƒÂ¢ncia.

Nota de arqueologia: os goldens anteriores foram capturados de um build de 10
arquivos cujo `timingsMs` nÃƒÂ£o tinha `preview` nem `quantise`. Eles continuaram
vÃƒÂ¡lidos atravÃƒÂ©s de todos os refactors do MÃƒÂ³dulo 0 porque aqueles refactors foram
neutros nos artefatos comparados, e as duas chaves novas caÃƒÂ­ram dentro do ÃƒÂºnico
bloco que o comparador recorta. O sha256 de build que este arquivo registrava
estava desatualizado desde o passo 7 do MÃƒÂ³dulo 0; estÃƒÂ¡ corrigido acima.

**A data no log** era o outro relÃƒÂ³gio, e nÃƒÂ£o ÃƒÂ© mais. `runPipeline(buffer,
fileName, post, opts)` recebe `opts.now`, que cai em `new Date()` quando
ausente. O navegador segue imprimindo o dia de hoje; a captura fixa
`__GOLDEN_DATE = '2026-09-05'`. Estes goldens nÃƒÂ£o expiram. NÃƒÂ£o mude
`__GOLDEN_DATE`: invalida todos os logs guardados e nÃƒÂ£o compra nada.

## O corpus malformado

33 arquivos que mentem sobre si mesmos, em `test/malformed/`, gerados por
`test/make-malformed.ps1` e comparados por `test/compare-malformed.ps1` contra
`test/golden/malformed.json`. Vieram de uma auditoria de robustez feita antes da
publicaÃƒÂ§ÃƒÂ£o; quatro achados dela viraram correÃƒÂ§ÃƒÂ£o de cÃƒÂ³digo.

**NÃƒÂ£o sÃƒÂ£o versionados, e o cabeÃƒÂ§alho do gerador explica por quÃƒÂª**: a geraÃƒÂ§ÃƒÂ£o ÃƒÂ© sÃƒÂ³
ASCII e inteiros big-endian, idÃƒÂªntica em qualquer mÃƒÂ¡quina por construÃƒÂ§ÃƒÂ£o Ã¢â‚¬â€ ao
contrÃƒÂ¡rio dos fixtures, que passam por ponto flutuante e por isso ficam
versionados. A divergÃƒÂªncia continua detectÃƒÂ¡vel: o `malformed.json` guarda o
sha256 de cada arquivo e o comparador regenera e confere **antes** de olhar
qualquer veredito. `build.ps1 -Check` lÃƒÂª a mesma lista para saber que estes
arquivos nÃƒÂ£o precisam estar no git.

**A pergunta ÃƒÂ© outra que a dos goldens.** `compare-golden` pergunta "a saÃƒÂ­da de
hoje ÃƒÂ© a de ontem?". Aqui ÃƒÂ© "isto continua sendo recusado?", e a falha grave ÃƒÂ©
assimÃƒÂ©trica: `rejeita Ã¢â€ â€™ aceita` ÃƒÂ© a pior, porque parece uma rodada
bem-sucedida Ã¢â‚¬â€ a pÃƒÂ¡gina produz imagem a partir de bytes que ninguÃƒÂ©m verificou.
Nove casos existem para o lado oposto (`a8`, `a9`, `a10`, `c2`, `d13`, `e2`,
`e3`, `e6`, `e7`, `e8`): sÃƒÂ£o os arquivos estranhos que **tÃƒÂªm** que passar, e
pegam o dia em que alguÃƒÂ©m apertar uma validaÃƒÂ§ÃƒÂ£o demais.

O comparador tambÃƒÂ©m verifica **tempo**, com teto de 3000 ms. "Parou" ÃƒÂ© metade da
afirmaÃƒÂ§ÃƒÂ£o: um arquivo que trava a aba falha diferente de um que dÃƒÂ¡ erro. Pior
caso hoje: 32 ms, o cabeÃƒÂ§alho de 4 MB.

### O que a auditoria achou, e o que mudou

| achado | era | virou |
|---|---|---|
| descritor de heap fora do arquivo | **aceitava**, quadro chapado, sem erro | `badheader` antes de qualquer leitura |
| `ZTILE` sem teto | `new Int32Array(t1*t2*t3)` fora do `alloc()`; **+768 MB medidos** de um arquivo de 14 kB | tile limitado pela imagem, atravÃƒÂ©s do `alloc()` |
| `PCOUNT` negativo | encolhia o tamanho declarado e passava; `RangeError` cru lido como "memÃƒÂ³ria" | `badheader` |
| `RangeError` sem `kind` Ã¢â€ â€™ `memory` | a justificativa escrita era falsa, e os dois casos acima a desmentiam | `unknown`, e a razÃƒÂ£o inversa estÃƒÂ¡ escrita: tudo que escala com o arquivo passa pelo `alloc()`, que rotula sozinho |

O par `d11`/`d13` ÃƒÂ© o guarda de off-by-one da validaÃƒÂ§ÃƒÂ£o de ponteiro: um byte
alÃƒÂ©m do fim ÃƒÂ© `badheader`, o byte exato passa e decodifica.

A correÃƒÂ§ÃƒÂ£o nÃƒÂ£o mexeu em nenhuma saÃƒÂ­da legÃƒÂ­tima Ã¢â‚¬â€ os 20 goldens saÃƒÂ­ram
byte-idÃƒÂªnticos sem recaptura, incluindo o `rice-fixture`, que ÃƒÂ© o que prova que
o teto de `ZTILE` e a validaÃƒÂ§ÃƒÂ£o de heap nÃƒÂ£o tocam um `.fz` vÃƒÂ¡lido.

## `fixture-colour` Ã¢â‚¬â€ a cor conhecida por construÃƒÂ§ÃƒÂ£o

1600Ãƒâ€”1200Ãƒâ€”3, float32, TOP-DOWN. Ãƒâ€° o ÃƒÂºnico golden capturado com parÃƒÂ¢metros que
**nÃƒÂ£o** sÃƒÂ£o os defaults: `colourCal` fica desligado atÃƒÂ© o MÃƒÂ³dulo 3, entÃƒÂ£o
capturar com os defaults nÃƒÂ£o exercitaria nada da calibraÃƒÂ§ÃƒÂ£o. Os parÃƒÂ¢metros vÃƒÂ£o
pelo mesmo `requestRun` que a interface usaria Ã¢â‚¬â€ nÃƒÂ£o hÃƒÂ¡ caminho de teste
separado.

TrÃƒÂªs populaÃƒÂ§ÃƒÂµes, trÃƒÂªs razÃƒÂµes, **nenhuma perto de outra**, e ÃƒÂ© isso que faz o
resultado dizer *qual* populaÃƒÂ§ÃƒÂ£o foi medida em vez de sÃƒÂ³ "o nÃƒÂºmero ÃƒÂ© plausÃƒÂ­vel":

| populaÃƒÂ§ÃƒÂ£o | R/G | B/G | papel |
|---|---|---|---|
| fundo | 0,8571 | 0,5714 | o que a Ã‚Â§2.1 nivela |
| **estrelas** | **1,2500** | **0,8000** | o que a Ã‚Â§2.2 tem que achar |
| objeto extenso | 0,9500 | 1,1000 | o que contamina a Ã‚Â§2.2 |

Medido, com tudo ligado: **1,2511 / 0,7994** Ã¢â‚¬â€ 0,09% e 0,08% da verdade
injetada. Ganhos 0,7993 Ã‚Â· 1,0000 Ã‚Â· 1,2510 contra 0,8000 Ã‚Â· 1,0000 Ã‚Â· 1,2500.

### As quatro configuraÃƒÂ§ÃƒÂµes, e o que cada uma prova

| configuraÃƒÂ§ÃƒÂ£o | R/G | ganho R |
|---|---|---|
| tudo ligado | 1,2511 | 0,7993 |
| sem rejeiÃƒÂ§ÃƒÂ£o de extenso | 1,2513 | 0,7992 |
| sem corte superior | 1,2521 | 0,7987 |
| **sem os dois** | **1,0027** | **0,9973** |

A ÃƒÂºltima linha ÃƒÂ© o modo de falha inteiro: com as duas defesas desligadas o ganho
vermelho vira **0,9973 Ã¢â‚¬â€ identidade**. A etapa roda, o record preenche, o log
imprime, e a cor nunca foi medida. As duas linhas do meio mostram que as defesas
se cobrem: o filtro de extenso tambÃƒÂ©m rejeita os aglomerados saturados, porque
um borrÃƒÂ£o saturado tem vizinhanÃƒÂ§a cheia.

### TrÃƒÂªs construÃƒÂ§ÃƒÂµes, e a primeira reprovou

Registrado porque a reprovaÃƒÂ§ÃƒÂ£o foi a parte ÃƒÂºtil.

1. **Objeto 240Ãƒâ€”150, pico 0,060; 40 estrelas saturadas.** A etapa devolveu
   1,127/0,798 Ã¢â‚¬â€ a razÃƒÂ£o do **objeto**, quase exata. Medido: 29,8% dos pixels
   selecionados estavam dentro da elipse do objeto. Um fixture que nÃƒÂ£o separa
   essas duas respostas certificaria um passo que mede a populaÃƒÂ§ÃƒÂ£o errada.
2. **Saturadas com amplitude 3,0 e brilho igual nos trÃƒÂªs canais.** As asas
   ficavam cinzas, o que nÃƒÂ£o ÃƒÂ© o que uma estrela saturada real faz Ã¢â‚¬â€ e o nÃƒÂºcleo
   totalmente preso era menor que o anel parcialmente preso, cuja razÃƒÂ£o ÃƒÂ© *maior*
   que a estelar. Desligar o corte movia a resposta para o lado errado.
3. **A atual:** objeto restaurado, saturadas com a mesma razÃƒÂ£o das estrelas e
   amplitude 30,0, para que o nÃƒÂºcleo cinza domine o anel.

### O que este fixture ainda nÃƒÂ£o prova

A rejeiÃƒÂ§ÃƒÂ£o de extenso remove **1.646 pixels** aqui, contra 39% da seleÃƒÂ§ÃƒÂ£o no
empilhamento real de M 31. O limiar de brilho sobe muito com 900 estrelas
saturadas no quadro e o objeto acaba quase todo abaixo dele. O filtro estÃƒÂ¡
exercitado, nÃƒÂ£o estressado; a evidÃƒÂªncia forte para ele ÃƒÂ© a mediÃƒÂ§ÃƒÂ£o real
registrada na Ã‚Â§0 da spec, nÃƒÂ£o este fixture.

## Cobertura que ainda falta

Nenhum fixture cobre **`.fz` que ainda seja mosaico CFA** Ã¢â‚¬â€ descompressÃƒÂ£o e
debayer estÃƒÂ£o cobertos em separado, nunca combinados. O gerador consegue
produzir isso (ÃƒÂ© o caminho int16 + BAYERPAT dentro do escritor Rice); ninguÃƒÂ©m
escreveu ainda.

**FECHADO Ã¢â‚¬â€ gradiente e objeto extenso.** Era o passo 3 da Ã‚Â§6 do MÃƒÂ³dulo 1 e
existe: `fixture-gradient.fit`, seÃƒÂ§ÃƒÂ£o prÃƒÂ³pria acima.

O que ainda falta em volta dele: o `reference.py` nÃƒÂ£o conhece este fixture, entÃƒÂ£o
`compare-reference.ps1` continua em 116 linhas e nÃƒÂ£o o cobre. Ãƒâ€° o passo 8 da Ã‚Â§6,
e atÃƒÂ© lÃƒÂ¡ o gradiente ÃƒÂ© verificÃƒÂ¡vel contra os cards `HISTORY` mas nÃƒÂ£o contra uma
segunda implementaÃƒÂ§ÃƒÂ£o.
