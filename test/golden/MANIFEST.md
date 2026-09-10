# Golden artifacts

CritÃƒÆ’Ã‚Â©rio de aceitaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o: **a tolerÃƒÆ’Ã‚Â¢ncia da Ãƒâ€šÃ‚Â§7 do MÃƒÆ’Ã‚Â³dulo 0**, aplicada por
`compare-golden.ps1`, que responde em duas partes e diz qual respondeu ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â
`PASS` quando os bytes sÃƒÆ’Ã‚Â£o idÃƒÆ’Ã‚Âªnticos, `PASS~` quando diferem e toda diferenÃƒÆ’Ã‚Â§a
cabe na tolerÃƒÆ’Ã‚Â¢ncia, `FAIL` fora disso. O log continua exato, sem tolerÃƒÆ’Ã‚Â¢ncia.

O critÃƒÆ’Ã‚Â©rio anterior ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â PNG, log e records byte a byte, diagnÃƒÆ’Ã‚Â³stico byte a byte
menos `timingsMs` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â valeu enquanto a cadeia tinha uma etapa e o LUT era a
autoridade sobre o valor do pixel. Morreu no passo 2 do MÃƒÆ’Ã‚Â³dulo 1, por
construÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o e no prazo. Ver "O que o float pleno mudou", abaixo.

Os goldens abaixo foram capturados de `.claude/index-test.html`, o build **com
ganchos**. O publicado ÃƒÆ’Ã‚Â© `index.html` e difere dele apenas pelo bloco de
ganchos. Os dois:

<!--BUILD_HASHES-->

| arquivo | bytes | sha256 |
|---|---|---|
| `index.html` | 225332 | `da011723cacf6d3bbdec304574303408e1aa0642c43da1181dff111dc5bcbdf1` |
| `.claude/index-test.html` | 227025 | `7aca984a7f37282c6d98fc1b8eb76b51bd8298052078866c94ce6f2e3089edc1` |

<!--/BUILD_HASHES-->

**Esta tabela ÃƒÆ’Ã‚Â© verificada por `build.ps1 -Check`**, que a lÃƒÆ’Ã‚Âª entre os dois
marcadores acima e compara com o build que acabou de montar. Ela existe para
quem quer conferir o download sem rodar o build; ser escrita ÃƒÆ’Ã‚Â  mÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© o motivo
pelo qual precisa ser verificada, nÃƒÆ’Ã‚Â£o uma licenÃƒÆ’Ã‚Â§a para nÃƒÆ’Ã‚Â£o ser.

Precisou existir: os nÃƒÆ’Ã‚Âºmeros daqui ficaram desatualizados desde `741f0e1` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â a
correÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o do pedestal mudou `background.js`, logo mudou o build ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â e ninguÃƒÆ’Ã‚Â©m
percebeu, porque nenhum comparador os lia. ÃƒÆ’Ã¢â‚¬Â° a forma invertida do argumento que
o prÃƒÆ’Ã‚Â³prio log usa: a frase do log nÃƒÆ’Ã‚Â£o envelhece porque ÃƒÆ’Ã‚Â© gerada; estes nÃƒÆ’Ã‚Âºmeros
envelhecem porque nÃƒÆ’Ã‚Â£o sÃƒÆ’Ã‚Â£o. O conserto nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© gerÃƒÆ’Ã‚Â¡-los, ÃƒÆ’Ã‚Â© medi-los.

Navegador: Chromium 148 (`Chrome/148.0.7778.280`, in-app browser do Claude
Code). Isso ainda importa para o PNG, mas menos do que importava: o comparador
agora **decodifica** o PNG e compara pixels, entÃƒÆ’Ã‚Â£o outro encoder com os mesmos
pixels passa. O que continua dependendo do Chromium ÃƒÆ’Ã‚Â© o sha256 da tabela
abaixo, nÃƒÆ’Ã‚Â£o o veredito.

### Abre por duplo clique ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â os quatro caminhos, e como cada um foi verificado

| navegador | protocolo | caminho | como |
|---|---|---|---|
| Firefox 155 | `file://` | worker | automatizado |
| Chrome 151 | `file://` | inline | automatizado |
| Chrome 148 | `http://` | worker | automatizado, a sessÃƒÆ’Ã‚Â£o inteira |
| **Chrome** | **`file://`** | **worker** | **manual, 2026-09-07** |

O ÃƒÆ’Ã‚Âºltimo foi verificado ÃƒÆ’Ã‚Â  mÃƒÆ’Ã‚Â£o porque nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© automatizÃƒÆ’Ã‚Â¡vel aqui: o headless do
Chrome com `--virtual-time-budget` nÃƒÆ’Ã‚Â£o avanÃƒÆ’Ã‚Â§a os timers de dentro de um Worker,
entÃƒÆ’Ã‚Â£o a mediÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o automÃƒÆ’Ã‚Â¡tica diz "nÃƒÆ’Ã‚Â£o completou" mesmo quando a pÃƒÆ’Ã‚Â¡gina funciona.
EstÃƒÆ’Ã‚Â¡ registrado no `NOTAS` como o caso que gerou a regra do controle positivo.

**Verificado manualmente em 2026-09-07:** `index.html` aberto por duplo clique
no Chrome, arquivo solto na pÃƒÆ’Ã‚Â¡gina, processou. Nos quatro caminhos, nenhuma
requisiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o externa.

## Como reproduzir

```
powershell -File .claude\make-fixture.ps1        # se os fixtures nÃƒÆ’Ã‚Â£o existirem
powershell -File .claude\serve.ps1 -Port 8791
```

Abrir **`http://127.0.0.1:8791/test.html`** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â e nÃƒÆ’Ã‚Â£o a raiz. A raiz serve o
`index.html` publicado, que **nÃƒÆ’Ã‚Â£o tem** `__loadFromURL`: os ganchos de teste
saem do arquivo que as pessoas baixam, e `/test.html` serve o
`.claude/index-test.html`, que ÃƒÆ’Ã‚Â© o mesmo build com o bloco de ganchos. Os dois
saem do mesmo `template.html` e `build.ps1 -Check` valida os dois, entÃƒÆ’Ã‚Â£o nÃƒÆ’Ã‚Â£o
podem divergir em nada alÃƒÆ’Ã‚Â©m daquele bloco.

Colar `test/capture-golden.js` no console e `await __captureAll()`. Os quatro
artefatos por fixture caem em `.claude/shots/`. Depois:

```
powershell -File test\compare-golden.ps1      # nao-regressao, com tolerancia
powershell -File test\compare-reference.ps1   # correÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o, contra o Python (ver nota)
powershell -File test\negative-controls.ps1   # a tolerÃƒÆ’Ã‚Â¢ncia ainda reprova?
```

E, no mesmo console do navegador, colar `test/compare-truth.js` e
`await __compareTruth()` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â compara o modelo de fundo ajustado contra o gradiente
que estÃƒÆ’Ã‚Â¡ gravado nos cards `HISTORY` do `fixture-gradient.fit` e escreve
`gradient-truth.json`. ÃƒÆ’Ã¢â‚¬Â° a ÃƒÆ’Ã‚Âºnica verificaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o da suÃƒÆ’Ã‚Â­te que nÃƒÆ’Ã‚Â£o herda a fÃƒÆ’Ã‚Â³rmula
compartilhada; ver a seÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o "O modelo contra a verdade", abaixo.

`negative-controls.ps1` nÃƒÆ’Ã‚Â£o precisa de captura nem de navegador: ele muta cÃƒÆ’Ã‚Â³pias
descartÃƒÆ’Ã‚Â¡veis dos prÃƒÆ’Ã‚Â³prios goldens e confere que o comparador chega ao veredito
certo em cada caso. Existe porque "controle negativo verificado" escrito numa
spec ÃƒÆ’Ã‚Â© uma afirmaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o que deixa de ser verdadeira no instante em que ninguÃƒÆ’Ã‚Â©m
consegue rodÃƒÆ’Ã‚Â¡-la de novo. SÃƒÆ’Ã‚Â£o 26 casos, e dois importam mais que os outros. O
`madn +8e-6` reprova pela regra de `span` e passaria pela regra de [0,1], que
nessa magnitude ÃƒÆ’Ã‚Â© **21 vezes** mais frouxa ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â ÃƒÆ’Ã‚Â© o ÃƒÆ’Ã‚Âºnico caso capaz de distinguir
as duas. E o par `png every sample +1` contra `png one sample +1`: mesmo
veredito, mesma magnitude, mesmo limite, achados opostos. ÃƒÆ’Ã¢â‚¬Â° o que prova que o
detector de deslocamento sistemÃƒÆ’Ã‚Â¡tico nÃƒÆ’Ã‚Â£o dispara em arredondamento comum.

Os casos ancoram em valores concretos dos goldens e **tÃƒÆ’Ã‚Âªm que ser reancorados
quando os goldens mudam** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â no passo 6 o `"clipLow": 266` deixou de existir
porque a correÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o eliminou o corte de sombra, e o script parou com a mensagem
dizendo qual padrÃƒÆ’Ã‚Â£o nÃƒÆ’Ã‚Â£o achou. Falhar alto ÃƒÆ’Ã‚Â© o comportamento certo: um controle
negativo que se auto-desativasse em silÃƒÆ’Ã‚Âªncio seria pior que nÃƒÆ’Ã‚Â£o existir.

> **NOTA SOBRE `compare-reference.ps1`, a partir do passo 6.** O `reference.py`
> modela o decode e o autostretch, e **nÃƒÆ’Ã‚Â£o** conhece a extraÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o de fundo. Desde
> que a etapa passou a mexer em pixel, o bloco por canal compara dois quadros
> diferentes, e o comparador diz isso **uma vez** em vez de reprovar 63 nÃƒÆ’Ã‚Âºmeros:
> `N/A ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â pipeline roda background e reference.py nao modela ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â passo 8 da Ãƒâ€šÃ‚Â§6`.
>
> O que sobra do MÃƒÆ’Ã‚Â³dulo 0: **todo o bloco de decode**, nos quatro fixtures.
>
> ÃƒÆ’Ã¢â‚¬Â° `N/A` e nÃƒÆ’Ã‚Â£o `KNOWN` de propÃƒÆ’Ã‚Â³sito. A lista `KNOWN` ÃƒÆ’Ã‚Â© para divergÃƒÆ’Ã‚Âªncias entre
> duas implementaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes que descrevem a mesma coisa; esta ÃƒÆ’Ã‚Â© as duas deixando de
> descrever a mesma coisa. Encher `KNOWN` com sessenta entradas transformaria um
> registro de dÃƒÆ’Ã‚Â­vida em papel de parede ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â Ãƒâ€šÃ‚Â§7 do MÃƒÆ’Ã‚Â³dulo 0, "KNOWN nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© uma saÃƒÆ’Ã‚Â­da
> de emergÃƒÆ’Ã‚Âªncia".
>
> **`referencia-cadeia.json` reabriu o bloco.** Ele monta a cadeia inteira ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â
> decode, fundo, autostretch sobre o quadro **corrigido** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â e volta a ser
> comparÃƒÆ’Ã‚Â¡vel nÃƒÆ’Ã‚Âºmero a nÃƒÆ’Ã‚Âºmero. Ver a seÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o abaixo.

## A cadeia completa contra `chain.py`

`referencia-cadeia.json` fecha o que o passo 6 abriu. O comparador vai a **180
linhas: 174 PASS, 5 N/A, 1 FAIL.**

| fixture | linhas | PASS | FAIL | N/A |
|---|---|---|---|---|
| `seestar` | 13 | 11 | 0 | 2 |
| `rice` | 61 | 60 | 0 | 1 |
| `nonlinear` | 17 | 14 | 1 | 2 |
| `gradient` | 89 | 89 | 0 | 0 |

### A confirmaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o independente do bug do passo 6

O `before` do stretch **ÃƒÆ’Ã‚Â©** a mediÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o do quadro corrigido. Que estes nÃƒÆ’Ã‚Âºmeros
batam ÃƒÆ’Ã‚Â© confirmaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o de fora de que o conserto do passo 6 estÃƒÆ’Ã‚Â¡ certo: uma segunda
implementaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o, escrita depois e montada do zero, mede o mesmo MADN
pÃƒÆ’Ã‚Â³s-correÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o. A razÃƒÆ’Ã‚Â£o entre o dela e o meu:

| `rice` | `nonlinear` | `gradient` |
|---|---|---|
| 1,0062 | 1,0034 | 0,9991 |

O `seestar` dÃƒÆ’Ã‚Â¡ 4,51 e **nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© discordÃƒÆ’Ã‚Â¢ncia**: a referÃƒÆ’Ã‚Âªncia nÃƒÆ’Ã‚Â£o faz debayer, entÃƒÆ’Ã‚Â£o
o MADN dela ÃƒÆ’Ã‚Â© dominado pelo padrÃƒÆ’Ã‚Â£o Bayer, que nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© gradiente. O 0,000951 dela
coincide com o valor **prÃƒÆ’Ã‚Â©**-correÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o daqui (0,000939) porque ÃƒÆ’Ã‚Â© a mesma
grandeza. Bloco por canal em N/A, mesma lacuna do MÃƒÆ’Ã‚Â³dulo 0.

### A que reprova, e o que ÃƒÆ’Ã‚Â©

**Uma linha: `nonlinear fundo.aceitas` 81 contra 82.** As consequÃƒÆ’Ã‚Âªncias ficam
`N/A` com prÃƒÆ’Ã‚Â©-condiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o explÃƒÆ’Ã‚Â­cita no comparador ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â a tolerÃƒÆ’Ã‚Â¢ncia da Ãƒâ€šÃ‚Â§7 pressupÃƒÆ’Ã‚Âµe
que os dois lados medem **os mesmos pixels**, e conjuntos de amostras diferentes
significam superfÃƒÆ’Ã‚Â­cies diferentes.

A causa foi isolada e **nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© nenhuma das trÃƒÆ’Ã‚Âªs suspeitas ÃƒÆ’Ã‚Â³bvias**: os limiares
concordam a 0,34 / 0,86 / 0,08 bins; a amostra marginal em (638, 563) estÃƒÆ’Ã‚Â¡ 6,2
bins acima do limiar **exato** tambÃƒÆ’Ã‚Â©m, entÃƒÆ’Ã‚Â£o os dois a rejeitam; e o critÃƒÆ’Ã‚Â©rio de
rejeiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© idÃƒÆ’Ã‚Âªntico. O que difere ÃƒÆ’Ã‚Â© **onde a caixa estÃƒÆ’Ã‚Â¡**: `Math.round(562,5)`
dÃƒÆ’Ã‚Â¡ 563 em JavaScript e 562 no Python, que arredonda meio para o par. SÃƒÆ’Ã‚Â³ o
`nonlinear` cai nisso, porque sÃƒÆ’Ã‚Â³ nele `w/cols = 75` produz centros em meio
exato. Registrado na Ãƒâ€šÃ‚Â§2.1 do MÃƒÆ’Ã‚Â³dulo 1 como lacuna de especificaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o.

### As 6 que reprovavam antes do termo da mediana

Eram `mad`/`madn` acima do piso da Ãƒâ€šÃ‚Â§7:

| | bins de span | limite |
|---|---|---|
| `rice` G, B `madn` | 8,75 / 9,45 | 8,00 |
| `gradient` R `mad`, `madn` | 14,58 / 21,62 | 8,00 |
| `gradient` B `mad`, `madn` | 8,59 / 12,74 | 8,00 |

**DiagnÃƒÆ’Ã‚Â³stico, e por que nÃƒÆ’Ã‚Â£o afrouxei o nÃƒÆ’Ã‚Âºmero.** As medianas concordam
**muito** bem ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 0,19 a 0,81 bins do eixo [0,1], contra um limite de 4. O que
falha ÃƒÆ’Ã‚Â© sÃƒÆ’Ã‚Â³ a dispersÃƒÆ’Ã‚Â£o. A causa ÃƒÆ’Ã‚Â© que `MAD = mediana(|v ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢ m|)` ÃƒÆ’Ã‚Â© medida
**relativa ÃƒÆ’Ã‚Â  mediana**, e o piso da Ãƒâ€šÃ‚Â§7 ÃƒÆ’Ã‚Â© dimensionado em bins de `span`, que
depois da correÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o ficou 2,5 a 5ÃƒÆ’Ã¢â‚¬â€ menor. Um deslocamento de mediana de 0,81 bins
do eixo [0,1] sÃƒÆ’Ã‚Â£o 143 bins de `span` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â o MADN herda a incerteza da mediana
medida num eixo muito mais grosso.

**O termo entrou na Ãƒâ€šÃ‚Â§7**, e ÃƒÆ’Ã‚Â© cota e nÃƒÆ’Ã‚Â£o ajuste: `MAD(m) = mediana(|vÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢m|)` e
`ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬â€œvÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢mÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢d|ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢|vÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢mÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬â€œ ÃƒÂ¢Ã¢â‚¬Â°Ã‚Â¤ |d|` pela desigualdade triangular; a mediana ÃƒÆ’Ã‚Â© monÃƒÆ’Ã‚Â³tona, entÃƒÆ’Ã‚Â£o
a cota passa para o MAD. Vale antes de olhar os dados, para qualquer
distribuiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o.

    |a ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢ b| ÃƒÂ¢Ã¢â‚¬Â°Ã‚Â¤ max( 1e-4Ãƒâ€šÃ‚Â·|ref| ,  8Ãƒâ€šÃ‚Â·span/65535  +  1,4826Ãƒâ€šÃ‚Â·|ÃƒÅ½Ã¢â‚¬Âmediana| )

Com ele as seis passam com folga ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â para `gradient` R o termo vale 1,84e-5 contra
um `ÃƒÅ½Ã¢â‚¬Âmadn` observado de 1,87e-6, dez vezes maior. **Controle negativo, para o
termo nÃƒÆ’Ã‚Â£o virar licenÃƒÆ’Ã‚Â§a:** `madn` perturbado em 3ÃƒÆ’Ã¢â‚¬â€ a cota reprova; dentro da
cota passa. Auto-calibrado a partir do `span` do prÃƒÆ’Ã‚Â³prio golden e da mediana da
prÃƒÆ’Ã‚Â³pria referÃƒÆ’Ã‚Âªncia, para nÃƒÆ’Ã‚Â£o envelhecer em silÃƒÆ’Ã‚Âªncio como os ÃƒÆ’Ã‚Â¢ncoras de clip
envelheceram.

## O que o float pleno mudou, medido

O passo 2 do MÃƒÆ’Ã‚Â³dulo 1 tirou o LUT de 2^20 entradas do `stretch-mtf` e passou a
gravar MTF em precisÃƒÆ’Ã‚Â£o plena; `quantise` virou o ÃƒÆ’Ã‚Âºnico lugar onde um nÃƒÆ’Ã‚Â­vel ÃƒÆ’Ã‚Â©
decidido. A tabela ÃƒÆ’Ã‚Â© a captura float comparada contra os goldens de 8 bits:

| artefato | veredito | o que aconteceu |
|---|---|---|
| `log.txt` ÃƒÆ’Ã¢â‚¬â€ 3 | **PASS** byte a byte | todo nÃƒÆ’Ã‚Âºmero que o log imprime vem do `before` do record de stretch, que nenhuma etapa a jusante move |
| `diag.json` ÃƒÆ’Ã¢â‚¬â€ 3 | **PASS** byte a byte | mesmo motivo: o painel tambÃƒÆ’Ã‚Â©m ÃƒÆ’Ã‚Â© construÃƒÆ’Ã‚Â­do do `before` |
| `png` ÃƒÆ’Ã¢â‚¬â€ 3 | **PASS~** | 0,031% a 0,781% das amostras diferem, **todas por exatamente 1 nÃƒÆ’Ã‚Â­vel** (mÃƒÆ’Ã‚Â©dia do \|d\| = 1,00) |
| `records.json` ÃƒÆ’Ã¢â‚¬â€ 3 | **FAIL** | 23 a 24 campos, **todos em `after.perChannel[*]`**: median, mad, madn, span, q1, q3, p001, p999 |

Nenhum campo de `before` se moveu. Nenhuma contagem de clip se moveu ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â
`outLow` e `outHigh` contam os mesmos dois ramos sobre o mesmo `u`, e a mudanÃƒÆ’Ã‚Â§a
nÃƒÆ’Ã‚Â£o os alcanÃƒÆ’Ã‚Â§a. Foi por isso que os goldens de log e diag sobreviveram: o que
mudou fica inteiramente a jusante da quantizaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o que saiu.

**A identidade que a cadeia de 8 bits escondia.** No ramo nÃƒÆ’Ã‚Â£o-linear o alvo do
autostretch ÃƒÆ’Ã‚Â© a prÃƒÆ’Ã‚Â³pria mediana do canal, entÃƒÆ’Ã‚Â£o `MTF` mapeia mediana em mediana
por construÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o e `after.median` deve ser igual a `before.median`. Na cadeia de
8 bits isso era invisÃƒÆ’Ã‚Â­vel: a mediana pousava em 67/255 = 0,262745. Na cadeia
float ela pousa em 0,2640573739223316 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â o mesmo dÃƒÆ’Ã‚Â­gito a dÃƒÆ’Ã‚Â­gito que
`before.median`, nos canais R e B; 3,05e-5 no G, que ÃƒÆ’Ã‚Â© resoluÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o de histograma.
Isso ÃƒÆ’Ã‚Â© evidÃƒÆ’Ã‚Âªncia independente de que o caminho novo estÃƒÆ’Ã‚Â¡ certo, e nÃƒÆ’Ã‚Â£o apenas
diferente.

**Reprodutibilidade verificada.** Uma segunda captura independente, depois de
recarregar a pÃƒÆ’Ã‚Â¡gina, devolveu os doze artefatos byte a byte idÃƒÆ’Ã‚Âªnticos aos
goldens promovidos. A tolerÃƒÆ’Ã‚Â¢ncia existe para mudanÃƒÆ’Ã‚Â§a de build, nÃƒÆ’Ã‚Â£o para ruÃƒÆ’Ã‚Â­do
de rodada ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â nÃƒÆ’Ã‚Â£o hÃƒÆ’Ã‚Â¡ ruÃƒÆ’Ã‚Â­do de rodada.

**Custo.** `transfer`, relÃƒÆ’Ã‚Â³gio de parede, uma amostra por fixture: 244ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢216,
233ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢268, 134ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢96 ms. `quantise` passou a aparecer separado, em 23 a 71 ms. NÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â©
mediÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â ÃƒÆ’Ã‚Â© uma amostra ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â e nÃƒÆ’Ã‚Â£o hÃƒÆ’Ã‚Â¡ evidÃƒÆ’Ã‚Âªncia de regressÃƒÆ’Ã‚Â£o que importe. O
orÃƒÆ’Ã‚Â§amento real da Ãƒâ€šÃ‚Â§3.6 do MÃƒÆ’Ã‚Â³dulo 1 ÃƒÆ’Ã‚Â© o arraste sobre o buffer de preview, e ÃƒÆ’Ã‚Â© lÃƒÆ’Ã‚Â¡
que isso precisa ser medido de verdade quando a RBF entrar.

## Fixtures ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â todos sintÃƒÆ’Ã‚Â©ticos

**Nenhum arquivo de terceiro entra aqui.** Ver `CLAUDE.md`. Os cinco saem de
`.claude/make-fixture.ps1` com semente fixa e sÃƒÆ’Ã‚Â£o reprodutÃƒÆ’Ã‚Â­veis byte a byte ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â
verificado: regerar o `fixture-seestar.fit` devolve o mesmo sha256 do arquivo
versionado.

| nome | arquivo | bytes | sha256 |
|---|---|---|---|
| `seestar-fixture` | `test/fixtures/fixture-seestar.fit` | 4.150.080 | `6d0acf7bbd4ce595d926ccc9bbf8e239447cda8ed7207c682fe598f5534cb28b` |
| `rice-fixture` | `test/fixtures/fixture-rice.fit.fz` | 8.671.680 | ver `make-fixture.ps1` |
| `nonlinear-fixture` | `test/fixtures/fixture-nonlinear.fit` | 6.482.880 | ver `make-fixture.ps1` |
| `gradient-fixture` | `test/fixtures/fixture-gradient.fit` | 23.042.880 | `b14ac76614949a4feef20e1c9aa263b29813f7b2a7298f9b461388d482e1fc25` |
| `edge-fixture` | `test/fixtures/fixture-edge.fit` | 1.442.880 | `3f18a50b3e896aab13683cb0b88abd4cc2f26c6a399dcf71072b8531d64ebf38` |

Cinco, e nÃƒÆ’Ã‚Â£o um, porque cobrem caminhos disjuntos:

- **`seestar-fixture`** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 1920ÃƒÆ’Ã¢â‚¬â€1080, BITPIX 16, BZERO 32768, ROWORDER BOTTOM-UP,
  BAYERPAT GRBG. Leitura de inteiro, flip de linha, detecÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o de CFA, debayer,
  ramo linear. `view.factor` 1.
- **`rice-fixture`** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 2600ÃƒÆ’Ã¢â‚¬â€1000ÃƒÆ’Ã¢â‚¬â€3, RICE_1 com SUBTRACTIVE_DITHER_2, uma tile
  por linha (3.000 tiles). DescompressÃƒÆ’Ã‚Â£o Rice, dither, caminho de 3 planos sem
  debayer. A borda longa ÃƒÆ’Ã‚Â© 2600 **de propÃƒÆ’Ã‚Â³sito**: passa de `MAX_VIEW` (2560) por
  40 px, entÃƒÆ’Ã‚Â£o `view.factor` = 2 e o PNG vem do buffer de resoluÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o plena, que ÃƒÆ’Ã‚Â©
  o caminho que o botÃƒÆ’Ã‚Â£o de download realmente usa.

  Traz duas armadilhas embutidas de propÃƒÆ’Ã‚Â³sito: um patch 24ÃƒÆ’Ã¢â‚¬â€24 de zeros exatos,
  que exercita o sentinela `DITHER_ZERO` do dither 2 (aparece como 576 pixels
  pretos por canal no diagnÃƒÆ’Ã‚Â³stico), e uma quantizaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o com `ZZERO ÃƒÂ¢Ã¢â‚¬Â°Ã‹â€  13313,9`
  contra `ZSCALE = 6,2e-6`, que deixa os inteiros logo acima do piso do int32 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â
  a configuraÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o que obriga o unquantize a ficar em double.
- **`nonlinear-fixture`** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 900ÃƒÆ’Ã¢â‚¬â€600ÃƒÆ’Ã¢â‚¬â€3, float32 sem compressÃƒÆ’Ã‚Â£o, ROWORDER
  TOP-DOWN, com cards HISTORY de autostretch e mediana medida 0,2467. Ramo
  nÃƒÆ’Ã‚Â£o-linear: ponto preto por percentil, alvo na prÃƒÆ’Ã‚Â³pria mediana. O midtones do
  gerador foi calibrado para pousar a mediana em ~0,25, que ÃƒÆ’Ã‚Â© onde um frame
  realmente esticado no Siril fica ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â um valor mais agressivo levava a mediana
  para 0,73 e o fixture deixava de representar o caso.
- **`gradient-fixture`** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 1600ÃƒÆ’Ã¢â‚¬â€1200ÃƒÆ’Ã¢â‚¬â€3, float32, TOP-DOWN. Para o MÃƒÆ’Ã‚Â³dulo 1.
  Ver a seÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o prÃƒÆ’Ã‚Â³pria abaixo: ÃƒÆ’Ã‚Â© o ÃƒÆ’Ã‚Âºnico da suÃƒÆ’Ã‚Â­te cujo fundo ÃƒÆ’Ã‚Â© conhecido
  independentemente das duas implementaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes.
- **`edge-fixture`** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 400ÃƒÆ’Ã¢â‚¬â€300ÃƒÆ’Ã¢â‚¬â€3, float32, TOP-DOWN. 1,44 MB, o mais barato da
  suÃƒÆ’Ã‚Â­te, e o ÃƒÆ’Ã‚Âºnico pequeno o bastante para a margem **padrÃƒÆ’Ã‚Â£o** alcanÃƒÆ’Ã‚Â§ar a grade
  de amostras: 38 das 108 amostras sÃƒÆ’Ã‚Â£o rejeitadas por borda, 6 por brilho, 64
  aceitas. Existe porque `rejected-edge` era alcanÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â¡vel e nÃƒÆ’Ã‚Â£o exercitado ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â o
  estado aparecia na spec, no cÃƒÆ’Ã‚Â³digo e no tooltip, e em nenhum golden. Cobre de
  passagem o caso de quadro pequeno, que tambÃƒÆ’Ã‚Â©m nÃƒÆ’Ã‚Â£o tinha nada.

## `fixture-gradient.fit` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â o ÃƒÆ’Ã‚Âºnico com uma verdade externa

Os outros trÃƒÆ’Ã‚Âªs respondem "hoje ÃƒÆ’Ã‚Â© igual a ontem?" e "as duas implementaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes
concordam?". Nenhuma das duas perguntas alcanÃƒÆ’Ã‚Â§a um erro de fÃƒÆ’Ã‚Â³rmula, porque a
referÃƒÆ’Ã‚Âªncia do Python leu a fÃƒÆ’Ã‚Â³rmula daqui ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â estÃƒÆ’Ã‚Â¡ registrado na Ãƒâ€šÃ‚Â§7 do MÃƒÆ’Ã‚Â³dulo 0 e
na Ãƒâ€šÃ‚Â§5 do MÃƒÆ’Ã‚Â³dulo 1. Este responde a uma terceira: **o modelo ajustado ÃƒÆ’Ã‚Â© o
gradiente que eu coloquei?**

O que estÃƒÆ’Ã‚Â¡ gravado em cards `HISTORY`, e ÃƒÆ’Ã‚Â© lido de volta pelo teste:

```
g(u,v) = A0 + A1*u + A2*v + A3*u^2 + A4*v^2 + A5*u*v
u = x/(NAXIS1-1)   v = y/(NAXIS2-1)   TOP-DOWN, entÃƒÆ’Ã‚Â£o v=0 ÃƒÆ’Ã‚Â© a primeira linha
```

com os seis coeficientes por canal, mais a geometria do objeto estendido
(`CX CY A B PEAK K`, perfil `I = PEAK*exp(-K*R)` em raio elÃƒÆ’Ã‚Â­ptico), as posiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes
das estrelas-sonda, o sigma do ruÃƒÆ’Ã‚Â­do e as sementes. 21 cards. O gerador escreve
os cards **das mesmas variÃƒÆ’Ã‚Â¡veis** que passa ao construtor da cena, entÃƒÆ’Ã‚Â£o nÃƒÆ’Ã‚Â£o hÃƒÆ’Ã‚Â¡
dois lugares onde o nÃƒÆ’Ã‚Âºmero possa divergir.

**Por que TOP-DOWN:** o flip de linha jÃƒÆ’Ã‚Â¡ estÃƒÆ’Ã‚Â¡ coberto pelo `seestar-fixture`.
Aqui a clareza do contrato vale mais ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â com TOP-DOWN as coordenadas do `HISTORY`
sÃƒÆ’Ã‚Â£o as coordenadas da imagem, sem inversÃƒÆ’Ã‚Â£o no meio da comparaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o.

**Por que 1600ÃƒÆ’Ã¢â‚¬â€1200:** nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© nÃƒÆ’Ã‚Âºmero redondo. Com `samplesPerRow` 12 a grade ÃƒÆ’Ã‚Â©
12ÃƒÆ’Ã¢â‚¬â€9, e com `PREVIEW_EDGE` 1024 o fator de preview ÃƒÆ’Ã‚Â© 2 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â entÃƒÆ’Ã‚Â£o o fixture
exercita o escalonamento de `boxSize` da Ãƒâ€šÃ‚Â§2.1, que ÃƒÆ’Ã‚Â© a exigÃƒÆ’Ã‚Âªncia de que uma
caixa de amostra signifique o mesmo pedaÃƒÆ’Ã‚Â§o de cÃƒÆ’Ã‚Â©u no preview e no render.

**Por que ruÃƒÆ’Ã‚Â­do gaussiano, e nÃƒÆ’Ã‚Â£o uniforme como nos outros:** a rejeiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â©
`mediana da caixa > mediana global + tolerance ÃƒÆ’Ã¢â‚¬â€ MADN`, e MADN sÃƒÆ’Ã‚Â³ significa
"sigma" para ruÃƒÆ’Ã‚Â­do gaussiano. Com ruÃƒÆ’Ã‚Â­do uniforme o limiar de rejeiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o cairia num
lugar sem interpretaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o e o fixture estaria testando outra coisa.

### Medido no fixture gerado, com os parÃƒÆ’Ã‚Â¢metros padrÃƒÆ’Ã‚Â£o da Ãƒâ€šÃ‚Â§2.2

Grade 12ÃƒÆ’Ã¢â‚¬â€9 = 108 amostras, caixa 25 px, margem 24 px, `tolerance` 1,0:

| | |
|---|---|
| aceitas | 93 |
| rejeitadas por brilho | 15, das quais **12 sobre o objeto** |
| rejeitadas por borda | 0 |
| fraÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o rejeitada | 13,9% |

Fica bem acima da salvaguarda de 8 pontos e bem abaixo dos 40% que a Ãƒâ€šÃ‚Â§3.5 manda
avisar. O objeto forÃƒÆ’Ã‚Â§a rejeiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o, que ÃƒÆ’Ã‚Â© para o que ele existe.

**ResÃƒÆ’Ã‚Â­duo |mediana da caixa ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢ verdade| nas aceitas: mÃƒÆ’Ã‚Â¡ximo 0,242 nÃƒÆ’Ã‚Â­vel de 255,
mÃƒÆ’Ã‚Â©dio 0,030.** A Ãƒâ€šÃ‚Â§5 sugere 1 nÃƒÆ’Ã‚Â­vel como tolerÃƒÆ’Ã‚Â¢ncia de partida para o modelo
ajustado contra o gradiente verdadeiro; a amostragem sozinha jÃƒÆ’Ã‚Â¡ entrega um
quarto disso, entÃƒÆ’Ã‚Â£o o orÃƒÆ’Ã‚Â§amento sobra para a RBF.

### A mediana sobrevive ÃƒÆ’Ã‚Â  estrela; a mÃƒÆ’Ã‚Â©dia nÃƒÆ’Ã‚Â£o

Oito estrelas-sonda em posiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes gravadas, `PEAK` 0,45 e `sigma` 2,2. O sigma ÃƒÆ’Ã‚Â©
pequeno de propÃƒÆ’Ã‚Â³sito: numa caixa de 625 pixels a estrela levanta cerca de 22%
deles, confortavelmente abaixo de metade. Um sigma maior viraria a mediana
tambÃƒÆ’Ã‚Â©m e o fixture passaria a argumentar o contrÃƒÆ’Ã‚Â¡rio do que a Ãƒâ€šÃ‚Â§2.1 afirma.

Nas caixas que contÃƒÆ’Ã‚Âªm uma sonda, canal G, em nÃƒÆ’Ã‚Â­veis de 255:

| desvio da mediana | desvio da mÃƒÆ’Ã‚Â©dia |
|---|---|
| 0,08 a 0,30 | **5,1 a 5,8** |

Cerca de **20ÃƒÆ’Ã¢â‚¬â€ pior para a mÃƒÆ’Ã‚Â©dia**. ÃƒÆ’Ã¢â‚¬Â° a Ãƒâ€šÃ‚Â§2.1 deixando de ser asserÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o e virando
nÃƒÆ’Ã‚Âºmero.

### Duas coisas que o fixture expÃƒÆ’Ã‚Âµe de graÃƒÆ’Ã‚Â§a

**A fraqueza da tolerÃƒÆ’Ã‚Â¢ncia global.** Uma das oito caixas-sonda, em (1253, 1112),
ÃƒÆ’Ã‚Â© rejeitada por brilho ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â e ali nÃƒÆ’Ã‚Â£o hÃƒÆ’Ã‚Â¡ objeto nenhum, sÃƒÆ’Ã‚Â³ fundo mais uma estrela.
No canto claro do gradiente o prÃƒÆ’Ã‚Â³prio fundo jÃƒÆ’Ã‚Â¡ passa de
`mediana global + 1,0 ÃƒÆ’Ã¢â‚¬â€ MADN`. ÃƒÆ’Ã¢â‚¬Â° exatamente a queixa registrada contra o Siril
na Ãƒâ€šÃ‚Â§1 ("tolerÃƒÆ’Ã‚Â¢ncia global ÃƒÆ’Ã‚Âºnica para a imagem inteira"), reproduzida num arquivo
onde dÃƒÆ’Ã‚Â¡ para medir. NÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© defeito do fixture: ÃƒÆ’Ã‚Â© o defeito que o MÃƒÆ’Ã‚Â³dulo 1b
promete resolver, disponÃƒÆ’Ã‚Â­vel para teste antes de a soluÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o existir.

**Custo em disco, e a decisÃƒÆ’Ã‚Â£o sobre ele.** 23,0 MB, contra 19,3 MB dos outros
trÃƒÆ’Ã‚Âªs somados; a ÃƒÆ’Ã‚Â¡rvore de fixtures passa a 42,3 MB.

**Fica assim: 1600ÃƒÆ’Ã¢â‚¬â€1200, sem compressÃƒÆ’Ã‚Â£o. Decidido, nÃƒÆ’Ã‚Â£o pendente.**

Encolher o quadro perde o que ele testa ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â a grade 12ÃƒÆ’Ã¢â‚¬â€9 e o fator de preview 2
sÃƒÆ’Ã‚Â£o os dois motivos de ele ter esse tamanho. E comprimir para `.fz` misturaria o
caminho Rice com o caminho do gradiente: uma falha neste fixture passaria a ter
duas explicaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes possÃƒÆ’Ã‚Â­veis, e separar as duas custaria mais do que os 23 MB
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

Os PNG cresceram entre 15% e 24%: o dither substitui bandas lisas por ruÃƒÆ’Ã‚Â­do, e
ruÃƒÆ’Ã‚Â­do nÃƒÆ’Ã‚Â£o comprime. ÃƒÆ’Ã¢â‚¬Â° o custo direto de nÃƒÆ’Ã‚Â£o ter bandas.

`gradient-truth.json` ÃƒÆ’Ã‚Â© o ÃƒÆ’Ã‚Âºnico destes que `compare-golden.ps1` **nÃƒÆ’Ã‚Â£o** compara:
ele vem de `compare-truth.js`, nÃƒÆ’Ã‚Â£o da captura, e ÃƒÆ’Ã‚Â© medida de referÃƒÆ’Ã‚Âªncia e nÃƒÆ’Ã‚Â£o
artefato de saÃƒÆ’Ã‚Â­da. Comparar automaticamente entra junto com o passo 8, quando o
`reference.py` conhecer o fixture.

### O que o passo 4 mudou nestes goldens, medido

A etapa de fundo entrou na cadeia amostrando e rejeitando, sem ajustar
superfÃƒÆ’Ã‚Â­cie e sem tocar em pixel. Contra os goldens do passo 3:

| artefato | veredito |
|---|---|
| `log.txt` ÃƒÆ’Ã¢â‚¬â€ 4 | **PASS** byte a byte |
| `diag.json` ÃƒÆ’Ã¢â‚¬â€ 4 | **PASS** byte a byte |
| `png` ÃƒÆ’Ã¢â‚¬â€ 4 | **PASS** byte a byte |
| `records.json` ÃƒÆ’Ã¢â‚¬â€ 4 | **FAIL**, `length 1 vs 2` |

O PNG idÃƒÆ’Ã‚Âªntico ÃƒÆ’Ã‚Â© a verificaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o de que a etapa devolve a imagem intacta: se um
pixel tivesse se movido, ele apareceria. O log idÃƒÆ’Ã‚Âªntico ÃƒÆ’Ã‚Â© a verificaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o de que
"background extraction" continua na frase "Not applied" ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â `applied: false`, e
`notAppliedLabels` chaveia nisso. E o `records.json` reprova por **mudanÃƒÆ’Ã‚Â§a
estrutural**, nÃƒÆ’Ã‚Â£o por deriva numÃƒÆ’Ã‚Â©rica: a cadeia ganhou um record, e nenhuma
tolerÃƒÆ’Ã‚Â¢ncia deve perdoar isso.

Os `records.json` cresceram de ~3,8 KB para 22ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“35 KB. ÃƒÆ’Ã¢â‚¬Â° a lista de pontos: cada
amostra com coordenada, estado, mediana por canal e a frase que diz por que foi
rejeitada. A Ãƒâ€šÃ‚Â§2.2 pede que o motivo esteja no record e nÃƒÆ’Ã‚Â£o sÃƒÆ’Ã‚Â³ no tooltip, e um
ponto rejeitado que some do registro ÃƒÆ’Ã‚Â© a operaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o silenciosa que a confusÃƒÆ’Ã‚Â£o 21
proÃƒÆ’Ã‚Â­be. 117 KB somados, contra 16,5 MB de PNG nos mesmos goldens.

## O modelo contra a verdade ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â passo 5

`test/compare-truth.js` roda no navegador, ajusta a superfÃƒÆ’Ã‚Â­cie com o cÃƒÆ’Ã‚Â³digo
entregue e compara contra os coeficientes do gradiente lidos de volta dos cards
`HISTORY`. O relatÃƒÆ’Ã‚Â³rio fica em `test/golden/gradient-truth.json`.

Isto ÃƒÆ’Ã‚Â© o que `compare-golden` e `compare-reference` nÃƒÆ’Ã‚Â£o conseguem responder. Um
pergunta se hoje ÃƒÆ’Ã‚Â© igual a ontem; o outro se as duas implementaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes concordam ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â
e elas concordam sobre uma fÃƒÆ’Ã‚Â³rmula que foi lida deste cÃƒÆ’Ã‚Â³digo. Um erro de fÃƒÆ’Ã‚Â³rmula
ÃƒÆ’Ã‚Â© invisÃƒÆ’Ã‚Â­vel para os dois. Aqui a resposta vem de nÃƒÆ’Ã‚Âºmeros que o gerador escreveu
e que nenhuma das duas implementaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes viu.

### ResÃƒÆ’Ã‚Â­duo `|modelo ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢ gradiente verdadeiro|`, em nÃƒÆ’Ã‚Â­veis de 255

| regiÃƒÆ’Ã‚Â£o | mÃƒÆ’Ã‚Â¡ximo | mÃƒÆ’Ã‚Â©dio |
|---|---|---|
| fora do objeto (raio elÃƒÆ’Ã‚Â­ptico > 2) | **0,168** | 0,031 |
| no canto que a rejeiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o global descarta | **0,168** | 0,067 |
| sob o objeto (raio ÃƒÂ¢Ã¢â‚¬Â°Ã‚Â¤ 1) | 0,840 | 0,649 |

A Ãƒâ€šÃ‚Â§5 do MÃƒÆ’Ã‚Â³dulo 1 sugere 1 nÃƒÆ’Ã‚Â­vel como tolerÃƒÆ’Ã‚Â¢ncia de partida fora das regiÃƒÆ’Ã‚Âµes
rejeitadas. O medido ÃƒÆ’Ã‚Â© **0,168** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â seis vezes dentro.

O resÃƒÆ’Ã‚Â­duo sob o objeto **nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© erro**: ali o esperado ÃƒÆ’Ã‚Â© o gradiente sozinho,
porque o objeto ÃƒÆ’Ã‚Â© sinal a preservar e nÃƒÆ’Ã‚Â£o fundo a remover. O nÃƒÆ’Ã‚Âºmero mede
**contaminaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â quanto do objeto vazou para o modelo e seria subtraÃƒÆ’Ã‚Â­do dele
no passo 6.

### ContaminaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o, e o que a rejeiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o compra

O pico do objeto vale 13,39 nÃƒÆ’Ã‚Â­veis. O modelo absorve 0,840 ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ **6,27%**.

| `tolerance` | aceitas | contaminaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o | resÃƒÆ’Ã‚Â­duo fora do objeto |
|---|---|---|---|
| 10 (sem rejeiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o) | 108 | **38,9%** | 0,267 |
| 2,0 | 101 | 10,96% | 0,148 |
| **1,0 (padrÃƒÆ’Ã‚Â£o)** | **93** | **6,27%** | **0,168** |
| 0,5 | 72 | 5,43% | 0,170 |
| 0,25 | 62 | 4,27% | 0,216 |
| 0,0 | 54 | 4,35% | 0,333 |

**A rejeiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o vale um fator de 6.** Sem ela o modelo come 38,9% do objeto ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â trÃƒÆ’Ã‚Âªs
vezes pior que os 12,5% que o GraXpert perdeu num braÃƒÆ’Ã‚Â§o do M31 (Ãƒâ€šÃ‚Â§1). Com ela,
6,27%, entre os 12,5% do modo IA e os 5% do ajuste manual.

Apertar alÃƒÆ’Ã‚Â©m de 1,0 rende pouco e cobra: a contaminaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o para de melhorar perto
de 4% enquanto o resÃƒÆ’Ã‚Â­duo fora do objeto piora de 0,168 para 0,333. O padrÃƒÆ’Ã‚Â£o 1,0
estÃƒÆ’Ã‚Â¡ perto do joelho da curva, e agora isso ÃƒÆ’Ã‚Â© medida e nÃƒÆ’Ã‚Â£o escolha.

### Erro da interpolaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â medido, nÃƒÆ’Ã‚Â£o presumido

A Ãƒâ€šÃ‚Â§2.3 manda avaliar numa grade de 1/8 e interpolar, e **medir** o erro contra
avaliaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o direta em 1000 pixels, aumentando a grade se passar de 0,5 nÃƒÆ’Ã‚Â­vel.

| fixture | grade | erro mÃƒÆ’Ã‚Â¡ximo |
|---|---|---|
| `seestar` | 241ÃƒÆ’Ã¢â‚¬â€136 | 0,0001 |
| `rice` | 326ÃƒÆ’Ã¢â‚¬â€126 | 0,0000 |
| `nonlinear` | 114ÃƒÆ’Ã¢â‚¬â€76 | 0,0039 |
| `gradient` | 201ÃƒÆ’Ã¢â‚¬â€151 | 0,0004 |

Duas ordens de grandeza dentro do limite no pior caso. O divisor nunca precisou
aumentar ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â mas isso ÃƒÆ’Ã‚Â© resultado, nÃƒÆ’Ã‚Â£o premissa, e ÃƒÆ’Ã‚Â© remedido a cada execuÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o.

Os 1000 pixels sÃƒÆ’Ã‚Â£o varridos por passo primo (104729) sobre o ÃƒÆ’Ã‚Â­ndice, que ÃƒÆ’Ã‚Â©
ÃƒÆ’Ã‚Â­mpar e portanto coprimo com qualquer potÃƒÆ’Ã‚Âªncia de dois: sondas consecutivas
caem em fases diferentes dentro da cÃƒÆ’Ã‚Â©lula da grade, que ÃƒÆ’Ã‚Â© onde o erro vive. Um
passo que compartilhasse fator com o divisor amostraria os cantos das cÃƒÆ’Ã‚Â©lulas e
reportaria zero.

## Passo 6 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â a correÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o, e o que medi-la encontrou

A correÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© `out = in ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢ model + pedestal`, com o pedestal sendo a mediana do
prÃƒÆ’Ã‚Â³prio modelo, **por canal**. A partir daqui a etapa reporta `applied: true`.

### A razÃƒÆ’Ã‚Â£o entre canais sobrevive ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â e o nÃƒÆ’Ã‚Âºmero que sustenta a frase de log

Medido no `fixture-rice`, mediana de fundo antes e depois da correÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o:

| | antes | depois | deriva |
|---|---|---|---|
| R/G | 1,099312 | 1,099010 | **ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢0,028%** |
| B/G | 0,920354 | 0,919802 | **ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢0,060%** |

E o contrafactual, aritmeticamente, se o pedestal fosse **ÃƒÆ’Ã‚Âºnico** (a mÃƒÆ’Ã‚Â©dia dos
trÃƒÆ’Ã‚Âªs) em vez de por canal:

| | resultado | deriva |
|---|---|---|
| R/G | 0,999904 | **ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢9,04%** |
| B/G | 0,999918 | **+8,64%** |

O pedestal ÃƒÆ’Ã‚Âºnico colapsa as duas razÃƒÆ’Ã‚Âµes para 1,0: ele **lava a cor do fundo**.
Por canal preserva ~150ÃƒÆ’Ã¢â‚¬â€ melhor. Nos quatro fixtures a deriva por canal fica
entre 0,016% e 0,44%; a de pedestal ÃƒÆ’Ã‚Âºnico, entre 6,6% e 11,2%.

ÃƒÆ’Ã¢â‚¬Â° este o nÃƒÆ’Ã‚Âºmero por trÃƒÆ’Ã‚Â¡s da frase *"the ratio between channels is therefore
unchanged: no colour grading"*, que agora estÃƒÆ’Ã‚Â¡ no log.

### Negativos, e por que a contagem zero aqui nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© clamp

A regra ÃƒÆ’Ã‚Â© nÃƒÆ’Ã‚Â£o clampear, e o teste natural ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â "se nÃƒÆ’Ã‚Â£o sobrou negativo, algo
clampeou" ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â dÃƒÆ’Ã‚Â¡ **falso alarme nestes fixtures**. Medido no `fixture-gradient`,
canal R:

| | mÃƒÆ’Ã‚Â­nimo | negativos |
|---|---|---|
| entrada | 0,007542 | 0 |
| corrigido, pedestal real | **0,012405** | 0 |
| corrigido, pedestal forÃƒÆ’Ã‚Â§ado a 0 | **ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢0,005950** | 882.624 (46%) |

O sinal de clamp nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© a contagem, ÃƒÆ’Ã‚Â© **o mÃƒÆ’Ã‚Â­nimo pousar exatamente em zero**. Ele
pousa em 0,0124, longe de zero, e com o pedestal zerado os 882 mil negativos
atravessam intactos. Nada clampeia.

A contagem zero ÃƒÆ’Ã‚Â© aritmÃƒÆ’Ã‚Â©tica: o pedestal (0,0184) ÃƒÆ’Ã‚Â© maior que a excursÃƒÆ’Ã‚Â£o do
modelo acima da prÃƒÆ’Ã‚Â³pria mediana (~0,0064), entÃƒÆ’Ã‚Â£o `in ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢ model + pedestal` nÃƒÆ’Ã‚Â£o
alcanÃƒÆ’Ã‚Â§a zero. **Lacuna de cobertura:** nenhum fixture tem gradiente forte o
bastante em relaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o ao nÃƒÆ’Ã‚Â­vel de fundo para produzir negativos no caminho normal.
Dado real com poluiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o luminosa forte produz.

### O dither ÃƒÆ’Ã‚Â© determinÃƒÆ’Ã‚Â­stico

Duas capturas independentes, cada uma depois de recarregar a pÃƒÆ’Ã‚Â¡gina: os quatro
PNG **byte a byte idÃƒÆ’Ã‚Âªnticos**. Semente 20260906, amplitude Ãƒâ€šÃ‚Â±0,5 nÃƒÆ’Ã‚Â­vel, ambas no
record do `quantise` e no log.

### O bug que a correÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o expÃƒÆ’Ã‚Â´s: o stretch media o quadro errado

`stepStretchMTF` recebia a mediÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o tirada **antes** da etapa de fundo. Enquanto
a etapa sÃƒÆ’Ã‚Â³ amostrava isso era inofensivo ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â as duas mediam os mesmos pixels ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â e
virou errado no instante em que um pixel se moveu.

O MADN ÃƒÆ’Ã‚Â© a parte que importa, porque o ponto preto ÃƒÆ’Ã‚Â© `mediana ÃƒÂ¢Ã‹â€ Ã¢â‚¬â„¢ 2,8 ÃƒÆ’Ã¢â‚¬â€ MADN`, e o
gradiente removido fazia parte da dispersÃƒÆ’Ã‚Â£o que o MADN media:

| fixture | MADN antes | MADN depois | fator |
|---|---|---|---|
| `seestar` | 0,000939 | 0,000211 | **4,5ÃƒÆ’Ã¢â‚¬â€** |
| `rice` | 0,001868 | 0,000364 | **5,1ÃƒÆ’Ã¢â‚¬â€** |
| `nonlinear` | 0,019943 | 0,005833 | **3,4ÃƒÆ’Ã¢â‚¬â€** |
| `gradient` | 0,003549 | 0,001395 | **2,5ÃƒÆ’Ã¢â‚¬â€** |

O ponto preto estava de 2,5 a 5 vezes fundo demais, em todo quadro.

**E era invisÃƒÆ’Ã‚Â­vel na mÃƒÆ’Ã‚Â©trica de saÃƒÆ’Ã‚Â­da:** a mediana pÃƒÆ’Ã‚Â³s-esticamento fica em ~64
de qualquer jeito, porque o MTF mapeia mediana no alvo seja qual for o MADN. ÃƒÆ’Ã¢â‚¬Â° a
mesma classe do erro do ÃƒÅ½Ã‚Â» ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â nÃƒÆ’Ã‚Â£o falha, nÃƒÆ’Ã‚Â£o avisa, e fica pior para sempre. O
`before` do stretch passa a vir do `after` da etapa de fundo, que jÃƒÆ’Ã‚Â¡ estava
medido e custava zero.

## Passo 7 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â a frase "Not applied", verificada nos dois sentidos

O passo 7 era verificaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o, e o que havia a verificar jÃƒÆ’Ã‚Â¡ tinha acontecido
sozinho: a frase perdeu "background extraction" no passo 6, **com zero ediÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes
em `registry.js`** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â o arquivo nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© tocado desde o passo 5 do MÃƒÆ’Ã‚Â³dulo 0.

Verificar que o rÃƒÆ’Ã‚Â³tulo sumiu ÃƒÆ’Ã‚Â© fraco: uma string apagada tambÃƒÆ’Ã‚Â©m some. A prova ÃƒÆ’Ã‚Â©
o **round-trip**, e ela passa pelo `buildLog` real:

| `background.applied` | descreve a etapa | nega a etapa |
|---|---|---|
| `true` | **1 linha** | ausente da frase |
| `false` | 0 linhas | **presente na frase** |

Os dois se movem juntos e em direÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes opostas. O invariante nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© "o rÃƒÆ’Ã‚Â³tulo
some", ÃƒÆ’Ã‚Â© **o log ou descreve a operaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o ou a nega, nunca nenhum dos dois e nunca
os dois**. Foi essa a segunda metade que o passo 6 quase deixou aberta: a frase
parou de negar antes de alguÃƒÆ’Ã‚Â©m escrever a que afirma.

Com `applied: false`, a frase volta **idÃƒÆ’Ã‚Âªntica** ÃƒÆ’Ã‚Â  de antes do MÃƒÆ’Ã‚Â³dulo 1 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â
comparada contra o resultado de `notAppliedLabels` sem nenhum record de fundo.

E o guarda do catÃƒÆ’Ã‚Â¡logo continua vivo: um passo declarado `neverImplemented`
reportando que rodou faz `notAppliedLabels` recusar produzir log, em vez de
produzir um que negue o que acabou de acontecer. Verificado com `id: 'ai'`.

## Grade sobre o quadro inteiro ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â e as duas implementaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes coincidindo

A grade deixou de ser encaixada dentro da margem. Centro em `(i+0,5)Ãƒâ€šÃ‚Â·w/cols`; a
margem ÃƒÆ’Ã‚Â© sÃƒÆ’Ã‚Â³ critÃƒÆ’Ã‚Â©rio de rejeiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o, que ÃƒÆ’Ã‚Â© o que a Ãƒâ€šÃ‚Â§2.2 sempre disse.

**Depois da mudanÃƒÆ’Ã‚Â§a, contra `reference_bg.py`:**

| | esta implementaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o | `reference_bg.py` | diferenÃƒÆ’Ã‚Â§a |
|---|---|---|---|
| amostras aceitas | 92 | 92 | 0 |
| rejeitadas por brilho | 16 | 16 | 0 |
| campo limpo R, mÃƒÆ’Ã‚Â¡ximo | 0,111218 | 0,111214 | 4,5e-6 nÃƒÆ’Ã‚Â­vel |
| campo limpo R, mÃƒÆ’Ã‚Â©dia | 0,011537 | 0,011537 | 2,4e-7 nÃƒÆ’Ã‚Â­vel |
| campo limpo G, mÃƒÆ’Ã‚Â¡ximo | 0,129388 | 0,129384 | 4,1e-6 nÃƒÆ’Ã‚Â­vel |
| campo limpo B, mÃƒÆ’Ã‚Â¡ximo | 0,111776 | 0,111772 | 3,6e-6 nÃƒÆ’Ã‚Â­vel |
| pedestal R | 0,018307595 | 0,018308640 | 0,00027 nÃƒÆ’Ã‚Â­vel |

**Cinco algarismos significativos**, com grades independentes e ÃƒÆ’Ã‚Â¡lgebra
independente (`numpy.linalg.solve` contra eliminaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o de Gauss escrita ÃƒÆ’Ã‚Â  mÃƒÆ’Ã‚Â£o). O
resÃƒÆ’Ã‚Â­duo de 4,5e-6 nÃƒÆ’Ã‚Â­vel ÃƒÆ’Ã‚Â© 1,7e-8 em [0,1] e tem causa identificada: as duas
avaliam a superfÃƒÆ’Ã‚Â­cie em retÃƒÆ’Ã‚Â­culas de tamanhos diferentes ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 201ÃƒÆ’Ã¢â‚¬â€151 aqui,
200ÃƒÆ’Ã¢â‚¬â€150 lÃƒÆ’Ã‚Â¡ ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â entÃƒÆ’Ã‚Â£o o valor interpolado num pixel difere nessa ordem. O pedestal
difere um pouco mais porque ÃƒÆ’Ã‚Â© a **mediana** dessa retÃƒÆ’Ã‚Â­cula, e as duas tomam a
mediana sobre conjuntos de nÃƒÆ’Ã‚Â³s diferentes.

Antes da mudanÃƒÆ’Ã‚Â§a eram 93 contra 92 aceitas e 0,1688 contra 0,1112 no campo
limpo. **"Grade diferente e ÃƒÆ’Ã‚Â¡lgebra diferente" era uma causa sÃƒÆ’Ã‚Â³.**

**O que a mudanÃƒÆ’Ã‚Â§a custou e rendeu**, medido no `fixture-gradient`:

| | grade encaixada | quadro inteiro |
|---|---|---|
| campo limpo fora do casco das amostras | 31,4% | ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â |
| campo limpo, mÃƒÆ’Ã‚Â¡ximo | 0,1688 | **0,1112** |
| campo limpo, mÃƒÆ’Ã‚Â©dia | 0,0337 | **0,0115** |
| casco das amostras | 1422ÃƒÆ’Ã¢â‚¬â€1024 | 1466ÃƒÆ’Ã¢â‚¬â€1066 |

### Amostragem, por fixture

| fixture | quadro | grade | caixa | geradas | aceitas | brilho | borda |
|---|---|---|---|---|---|---|---|
| `seestar` | 1920ÃƒÆ’Ã¢â‚¬â€1080 | 12ÃƒÆ’Ã¢â‚¬â€7 | 25 | 84 | 72 | 12 | 0 |
| `rice` | 2600ÃƒÆ’Ã¢â‚¬â€1000 | 12ÃƒÆ’Ã¢â‚¬â€5 | 25 | 60 | 53 | 7 | 0 |
| `nonlinear` | 900ÃƒÆ’Ã¢â‚¬â€600 | 12ÃƒÆ’Ã¢â‚¬â€8 | 25 | 96 | 85 | 11 | 0 |
| `gradient` | 1600ÃƒÆ’Ã¢â‚¬â€1200 | 12ÃƒÆ’Ã¢â‚¬â€9 | 25 | 108 | 93 | 15 | 0 |

Os quatro reportam `applied: false` com o mesmo `skipReason`: *sampling only*.

**VerificaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o cruzada do `gradient`:** 93/15/0/0 ÃƒÆ’Ã‚Â© exatamente o que a anÃƒÆ’Ã‚Â¡lise
independente em PowerShell tinha medido no fixture, e ela usou mediana e MAD por
**seleÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o exata** enquanto a etapa usa **histograma de 65536 bins**. Dois
estimadores diferentes do limiar, 108 vereditos idÃƒÆ’Ã‚Âªnticos.

**Preview contra render, medido:** com o buffer reduzido a 800ÃƒÆ’Ã¢â‚¬â€600 e `boxSize`
escalado de 25 para 13, os 108 pontos recebem a **mesma classificaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o** e a
maior diferenÃƒÆ’Ã‚Â§a de mediana de caixa ÃƒÆ’Ã‚Â© **0,0185 nÃƒÆ’Ã‚Â­vel de 255**. ÃƒÆ’Ã¢â‚¬Â° a afirmaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o da
Ãƒâ€šÃ‚Â§2.1 sobre correspondÃƒÆ’Ã‚Âªncia preview/render, com nÃƒÆ’Ã‚Âºmero.

O `.diag.json` ÃƒÆ’Ã‚Â© `JSON.stringify(state.diag, null, 2)` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â o objeto cru, nÃƒÆ’Ã‚Â£o o
`dump()` do painel, que arredonda para 8 dÃƒÆ’Ã‚Â­gitos significativos. Guardar o cru
significa que uma regressÃƒÆ’Ã‚Â£o de ponto flutuante aparece em vez de ser arredondada
para fora. (Os sha256 do diag mudam a cada captura por causa de `timingsMs`; os
da tabela sÃƒÆ’Ã‚Â£o do arquivo versionado.)

## O que nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© estÃƒÆ’Ã‚Â¡vel, e o que deixou de nÃƒÆ’Ã‚Â£o ser

**`timingsMs`** no diagnÃƒÆ’Ã‚Â³stico continua sendo relÃƒÆ’Ã‚Â³gio de parede.
`compare-golden.ps1` recorta o bloco dos dois lados antes de comparar. ÃƒÆ’Ã¢â‚¬Â° a ÃƒÆ’Ã‚Âºnica
coisa que ele ignora inteiramente, em vez de comparar com tolerÃƒÆ’Ã‚Â¢ncia.

Nota de arqueologia: os goldens anteriores foram capturados de um build de 10
arquivos cujo `timingsMs` nÃƒÆ’Ã‚Â£o tinha `preview` nem `quantise`. Eles continuaram
vÃƒÆ’Ã‚Â¡lidos atravÃƒÆ’Ã‚Â©s de todos os refactors do MÃƒÆ’Ã‚Â³dulo 0 porque aqueles refactors foram
neutros nos artefatos comparados, e as duas chaves novas caÃƒÆ’Ã‚Â­ram dentro do ÃƒÆ’Ã‚Âºnico
bloco que o comparador recorta. O sha256 de build que este arquivo registrava
estava desatualizado desde o passo 7 do MÃƒÆ’Ã‚Â³dulo 0; estÃƒÆ’Ã‚Â¡ corrigido acima.

**A data no log** era o outro relÃƒÆ’Ã‚Â³gio, e nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© mais. `runPipeline(buffer,
fileName, post, opts)` recebe `opts.now`, que cai em `new Date()` quando
ausente. O navegador segue imprimindo o dia de hoje; a captura fixa
`__GOLDEN_DATE = '2026-09-05'`. Estes goldens nÃƒÆ’Ã‚Â£o expiram. NÃƒÆ’Ã‚Â£o mude
`__GOLDEN_DATE`: invalida todos os logs guardados e nÃƒÆ’Ã‚Â£o compra nada.

## O corpus malformado

33 arquivos que mentem sobre si mesmos, em `test/malformed/`, gerados por
`test/make-malformed.ps1` e comparados por `test/compare-malformed.ps1` contra
`test/golden/malformed.json`. Vieram de uma auditoria de robustez feita antes da
publicaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o; quatro achados dela viraram correÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o de cÃƒÆ’Ã‚Â³digo.

**NÃƒÆ’Ã‚Â£o sÃƒÆ’Ã‚Â£o versionados, e o cabeÃƒÆ’Ã‚Â§alho do gerador explica por quÃƒÆ’Ã‚Âª**: a geraÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© sÃƒÆ’Ã‚Â³
ASCII e inteiros big-endian, idÃƒÆ’Ã‚Âªntica em qualquer mÃƒÆ’Ã‚Â¡quina por construÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â ao
contrÃƒÆ’Ã‚Â¡rio dos fixtures, que passam por ponto flutuante e por isso ficam
versionados. A divergÃƒÆ’Ã‚Âªncia continua detectÃƒÆ’Ã‚Â¡vel: o `malformed.json` guarda o
sha256 de cada arquivo e o comparador regenera e confere **antes** de olhar
qualquer veredito. `build.ps1 -Check` lÃƒÆ’Ã‚Âª a mesma lista para saber que estes
arquivos nÃƒÆ’Ã‚Â£o precisam estar no git.

**A pergunta ÃƒÆ’Ã‚Â© outra que a dos goldens.** `compare-golden` pergunta "a saÃƒÆ’Ã‚Â­da de
hoje ÃƒÆ’Ã‚Â© a de ontem?". Aqui ÃƒÆ’Ã‚Â© "isto continua sendo recusado?", e a falha grave ÃƒÆ’Ã‚Â©
assimÃƒÆ’Ã‚Â©trica: `rejeita ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ aceita` ÃƒÆ’Ã‚Â© a pior, porque parece uma rodada
bem-sucedida ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â a pÃƒÆ’Ã‚Â¡gina produz imagem a partir de bytes que ninguÃƒÆ’Ã‚Â©m verificou.
Nove casos existem para o lado oposto (`a8`, `a9`, `a10`, `c2`, `d13`, `e2`,
`e3`, `e6`, `e7`, `e8`): sÃƒÆ’Ã‚Â£o os arquivos estranhos que **tÃƒÆ’Ã‚Âªm** que passar, e
pegam o dia em que alguÃƒÆ’Ã‚Â©m apertar uma validaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o demais.

O comparador tambÃƒÆ’Ã‚Â©m verifica **tempo**, com teto de 3000 ms. "Parou" ÃƒÆ’Ã‚Â© metade da
afirmaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o: um arquivo que trava a aba falha diferente de um que dÃƒÆ’Ã‚Â¡ erro. Pior
caso hoje: 32 ms, o cabeÃƒÆ’Ã‚Â§alho de 4 MB.

### O que a auditoria achou, e o que mudou

| achado | era | virou |
|---|---|---|
| descritor de heap fora do arquivo | **aceitava**, quadro chapado, sem erro | `badheader` antes de qualquer leitura |
| `ZTILE` sem teto | `new Int32Array(t1*t2*t3)` fora do `alloc()`; **+768 MB medidos** de um arquivo de 14 kB | tile limitado pela imagem, atravÃƒÆ’Ã‚Â©s do `alloc()` |
| `PCOUNT` negativo | encolhia o tamanho declarado e passava; `RangeError` cru lido como "memÃƒÆ’Ã‚Â³ria" | `badheader` |
| `RangeError` sem `kind` ÃƒÂ¢Ã¢â‚¬Â Ã¢â‚¬â„¢ `memory` | a justificativa escrita era falsa, e os dois casos acima a desmentiam | `unknown`, e a razÃƒÆ’Ã‚Â£o inversa estÃƒÆ’Ã‚Â¡ escrita: tudo que escala com o arquivo passa pelo `alloc()`, que rotula sozinho |

O par `d11`/`d13` ÃƒÆ’Ã‚Â© o guarda de off-by-one da validaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o de ponteiro: um byte
alÃƒÆ’Ã‚Â©m do fim ÃƒÆ’Ã‚Â© `badheader`, o byte exato passa e decodifica.

A correÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o nÃƒÆ’Ã‚Â£o mexeu em nenhuma saÃƒÆ’Ã‚Â­da legÃƒÆ’Ã‚Â­tima ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â os 20 goldens saÃƒÆ’Ã‚Â­ram
byte-idÃƒÆ’Ã‚Âªnticos sem recaptura, incluindo o `rice-fixture`, que ÃƒÆ’Ã‚Â© o que prova que
o teto de `ZTILE` e a validaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o de heap nÃƒÆ’Ã‚Â£o tocam um `.fz` vÃƒÆ’Ã‚Â¡lido.

## `fixture-colour` ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â a cor conhecida por construÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o

1600ÃƒÆ’Ã¢â‚¬â€1200ÃƒÆ’Ã¢â‚¬â€3, float32, TOP-DOWN. ÃƒÆ’Ã¢â‚¬Â° o ÃƒÆ’Ã‚Âºnico golden capturado com parÃƒÆ’Ã‚Â¢metros que
**nÃƒÆ’Ã‚Â£o** sÃƒÆ’Ã‚Â£o os defaults: `colourCal` fica desligado atÃƒÆ’Ã‚Â© o MÃƒÆ’Ã‚Â³dulo 3, entÃƒÆ’Ã‚Â£o
capturar com os defaults nÃƒÆ’Ã‚Â£o exercitaria nada da calibraÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o. Os parÃƒÆ’Ã‚Â¢metros vÃƒÆ’Ã‚Â£o
pelo mesmo `requestRun` que a interface usaria ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â nÃƒÆ’Ã‚Â£o hÃƒÆ’Ã‚Â¡ caminho de teste
separado.

TrÃƒÆ’Ã‚Âªs populaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes, trÃƒÆ’Ã‚Âªs razÃƒÆ’Ã‚Âµes, **nenhuma perto de outra**, e ÃƒÆ’Ã‚Â© isso que faz o
resultado dizer *qual* populaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o foi medida em vez de sÃƒÆ’Ã‚Â³ "o nÃƒÆ’Ã‚Âºmero ÃƒÆ’Ã‚Â© plausÃƒÆ’Ã‚Â­vel":

| populaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o | R/G | B/G | papel |
|---|---|---|---|
| fundo | 0,8571 | 0,5714 | o que a Ãƒâ€šÃ‚Â§2.1 nivela |
| **estrelas** | **1,2500** | **0,8000** | o que a Ãƒâ€šÃ‚Â§2.2 tem que achar |
| objeto extenso | 0,9500 | 1,1000 | o que contamina a Ãƒâ€šÃ‚Â§2.2 |

Medido, com tudo ligado: **1,2511 / 0,7994** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 0,09% e 0,08% da verdade
injetada. Ganhos 0,7993 Ãƒâ€šÃ‚Â· 1,0000 Ãƒâ€šÃ‚Â· 1,2510 contra 0,8000 Ãƒâ€šÃ‚Â· 1,0000 Ãƒâ€šÃ‚Â· 1,2500.

### As quatro configuraÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes, e o que cada uma prova

| configuraÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o | R/G | ganho R |
|---|---|---|
| tudo ligado | 1,2511 | 0,7993 |
| sem rejeiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o de extenso | 1,2513 | 0,7992 |
| sem corte superior | 1,2521 | 0,7987 |
| **sem os dois** | **1,0027** | **0,9973** |

A ÃƒÆ’Ã‚Âºltima linha ÃƒÆ’Ã‚Â© o modo de falha inteiro: com as duas defesas desligadas o ganho
vermelho vira **0,9973 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â identidade**. A etapa roda, o record preenche, o log
imprime, e a cor nunca foi medida. As duas linhas do meio mostram que as defesas
se cobrem: o filtro de extenso tambÃƒÆ’Ã‚Â©m rejeita os aglomerados saturados, porque
um borrÃƒÆ’Ã‚Â£o saturado tem vizinhanÃƒÆ’Ã‚Â§a cheia.

### TrÃƒÆ’Ã‚Âªs construÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Âµes, e a primeira reprovou

Registrado porque a reprovaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o foi a parte ÃƒÆ’Ã‚Âºtil.

1. **Objeto 240ÃƒÆ’Ã¢â‚¬â€150, pico 0,060; 40 estrelas saturadas.** A etapa devolveu
   1,127/0,798 ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â a razÃƒÆ’Ã‚Â£o do **objeto**, quase exata. Medido: 29,8% dos pixels
   selecionados estavam dentro da elipse do objeto. Um fixture que nÃƒÆ’Ã‚Â£o separa
   essas duas respostas certificaria um passo que mede a populaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o errada.
2. **Saturadas com amplitude 3,0 e brilho igual nos trÃƒÆ’Ã‚Âªs canais.** As asas
   ficavam cinzas, o que nÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© o que uma estrela saturada real faz ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â e o nÃƒÆ’Ã‚Âºcleo
   totalmente preso era menor que o anel parcialmente preso, cuja razÃƒÆ’Ã‚Â£o ÃƒÆ’Ã‚Â© *maior*
   que a estelar. Desligar o corte movia a resposta para o lado errado.
3. **A atual:** objeto restaurado, saturadas com a mesma razÃƒÆ’Ã‚Â£o das estrelas e
   amplitude 30,0, para que o nÃƒÆ’Ã‚Âºcleo cinza domine o anel.

### O que este fixture ainda nÃƒÆ’Ã‚Â£o prova

A rejeiÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o de extenso remove **1.646 pixels** aqui, contra 39% da seleÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o no
empilhamento real de M 31. O limiar de brilho sobe muito com 900 estrelas
saturadas no quadro e o objeto acaba quase todo abaixo dele. O filtro estÃƒÆ’Ã‚Â¡
exercitado, nÃƒÆ’Ã‚Â£o estressado; a evidÃƒÆ’Ã‚Âªncia forte para ele ÃƒÆ’Ã‚Â© a mediÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o real
registrada na Ãƒâ€šÃ‚Â§0 da spec, nÃƒÆ’Ã‚Â£o este fixture.

## Cobertura que ainda falta

Nenhum fixture cobre **`.fz` que ainda seja mosaico CFA** ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â descompressÃƒÆ’Ã‚Â£o e
debayer estÃƒÆ’Ã‚Â£o cobertos em separado, nunca combinados. O gerador consegue
produzir isso (ÃƒÆ’Ã‚Â© o caminho int16 + BAYERPAT dentro do escritor Rice); ninguÃƒÆ’Ã‚Â©m
escreveu ainda.

**FECHADO ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â gradiente e objeto extenso.** Era o passo 3 da Ãƒâ€šÃ‚Â§6 do MÃƒÆ’Ã‚Â³dulo 1 e
existe: `fixture-gradient.fit`, seÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o prÃƒÆ’Ã‚Â³pria acima.

O que ainda falta em volta dele: o `reference.py` nÃƒÆ’Ã‚Â£o conhece este fixture, entÃƒÆ’Ã‚Â£o
`compare-reference.ps1` continua em 116 linhas e nÃƒÆ’Ã‚Â£o o cobre. ÃƒÆ’Ã¢â‚¬Â° o passo 8 da Ãƒâ€šÃ‚Â§6,
e atÃƒÆ’Ã‚Â© lÃƒÆ’Ã‚Â¡ o gradiente ÃƒÆ’Ã‚Â© verificÃƒÆ’Ã‚Â¡vel contra os cards `HISTORY` mas nÃƒÆ’Ã‚Â£o contra uma
segunda implementaÃƒÆ’Ã‚Â§ÃƒÆ’Ã‚Â£o.
