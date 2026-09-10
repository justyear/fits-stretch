# Golden artifacts

CritÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©rio de aceitaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o: **a tolerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia da ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§7 do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 0**, aplicada por
`compare-golden.ps1`, que responde em duas partes e diz qual respondeu ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
`PASS` quando os bytes sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o idÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªnticos, `PASS~` quando diferem e toda diferenÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a
cabe na tolerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia, `FAIL` fora disso. O log continua exato, sem tolerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia.

O critÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©rio anterior ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â PNG, log e records byte a byte, diagnÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³stico byte a byte
menos `timingsMs` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â valeu enquanto a cadeia tinha uma etapa e o LUT era a
autoridade sobre o valor do pixel. Morreu no passo 2 do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 1, por
construÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o e no prazo. Ver "O que o float pleno mudou", abaixo.

Os goldens abaixo foram capturados de `.claude/index-test.html`, o build **com
ganchos**. O publicado ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© `index.html` e difere dele apenas pelo bloco de
ganchos. Os dois:

<!--BUILD_HASHES-->

| arquivo | bytes | sha256 |
|---|---|---|
| `index.html` | 236942 | `e63258d633d45bb93a9bc080f0b38954eea68d421982a6dee01d773a62d3565c` |
| `.claude/index-test.html` | 238635 | `b673ac6876633d12e8b11f381b724d0fb598ad1aa492232e6c09e1cb09a83f50` |

<!--/BUILD_HASHES-->

**Esta tabela ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© verificada por `build.ps1 -Check`**, que a lÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âª entre os dois
marcadores acima e compara com o build que acabou de montar. Ela existe para
quem quer conferir o download sem rodar o build; ser escrita ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â  mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o motivo
pelo qual precisa ser verificada, nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o uma licenÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a para nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ser.

Precisou existir: os nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmeros daqui ficaram desatualizados desde `741f0e1` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â a
correÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o do pedestal mudou `background.js`, logo mudou o build ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â e ninguÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m
percebeu, porque nenhum comparador os lia. ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° a forma invertida do argumento que
o prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³prio log usa: a frase do log nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o envelhece porque ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© gerada; estes nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmeros
envelhecem porque nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o. O conserto nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© gerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡-los, ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© medi-los.

Navegador: Chromium 148 (`Chrome/148.0.7778.280`, in-app browser do Claude
Code). Isso ainda importa para o PNG, mas menos do que importava: o comparador
agora **decodifica** o PNG e compara pixels, entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o outro encoder com os mesmos
pixels passa. O que continua dependendo do Chromium ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o sha256 da tabela
abaixo, nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o o veredito.

### Abre por duplo clique ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â os quatro caminhos, e como cada um foi verificado

| navegador | protocolo | caminho | como |
|---|---|---|---|
| Firefox 155 | `file://` | worker | automatizado |
| Chrome 151 | `file://` | inline | automatizado |
| Chrome 148 | `http://` | worker | automatizado, a sessÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o inteira |
| **Chrome** | **`file://`** | **worker** | **manual, 2026-09-07** |

O ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºltimo foi verificado ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â  mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o porque nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© automatizÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡vel aqui: o headless do
Chrome com `--virtual-time-budget` nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o avanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a os timers de dentro de um Worker,
entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o a mediÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o automÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡tica diz "nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o completou" mesmo quando a pÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡gina funciona.
EstÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ registrado no `NOTAS` como o caso que gerou a regra do controle positivo.

**Verificado manualmente em 2026-09-07:** `index.html` aberto por duplo clique
no Chrome, arquivo solto na pÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡gina, processou. Nos quatro caminhos, nenhuma
requisiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o externa.

## Como reproduzir

```
powershell -File .claude\make-fixture.ps1        # se os fixtures nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o existirem
powershell -File .claude\serve.ps1 -Port 8791
```

Abrir **`http://127.0.0.1:8791/test.html`** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o a raiz. A raiz serve o
`index.html` publicado, que **nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o tem** `__loadFromURL`: os ganchos de teste
saem do arquivo que as pessoas baixam, e `/test.html` serve o
`.claude/index-test.html`, que ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o mesmo build com o bloco de ganchos. Os dois
saem do mesmo `template.html` e `build.ps1 -Check` valida os dois, entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o
podem divergir em nada alÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m daquele bloco.

Colar `test/capture-golden.js` no console e `await __captureAll()`. Os quatro
artefatos por fixture caem em `.claude/shots/`. Depois:

```
powershell -File test\compare-golden.ps1      # nao-regressao, com tolerancia
powershell -File test\compare-reference.ps1   # correÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o, contra o Python (ver nota)
powershell -File test\negative-controls.ps1   # a tolerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia ainda reprova?
```

E, no mesmo console do navegador, colar `test/compare-truth.js` e
`await __compareTruth()` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â compara o modelo de fundo ajustado contra o gradiente
que estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ gravado nos cards `HISTORY` do `fixture-gradient.fit` e escreve
`gradient-truth.json`. ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° a ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnica verificaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o da suÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­te que nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o herda a fÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³rmula
compartilhada; ver a seÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o "O modelo contra a verdade", abaixo.

`negative-controls.ps1` nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o precisa de captura nem de navegador: ele muta cÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³pias
descartÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡veis dos prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³prios goldens e confere que o comparador chega ao veredito
certo em cada caso. Existe porque "controle negativo verificado" escrito numa
spec ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© uma afirmaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o que deixa de ser verdadeira no instante em que ninguÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m
consegue rodÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡-la de novo. SÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o 26 casos, e dois importam mais que os outros. O
`madn +8e-6` reprova pela regra de `span` e passaria pela regra de [0,1], que
nessa magnitude ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© **21 vezes** mais frouxa ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnico caso capaz de distinguir
as duas. E o par `png every sample +1` contra `png one sample +1`: mesmo
veredito, mesma magnitude, mesmo limite, achados opostos. ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° o que prova que o
detector de deslocamento sistemÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡tico nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o dispara em arredondamento comum.

Os casos ancoram em valores concretos dos goldens e **tÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªm que ser reancorados
quando os goldens mudam** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â no passo 6 o `"clipLow": 266` deixou de existir
porque a correÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o eliminou o corte de sombra, e o script parou com a mensagem
dizendo qual padrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o achou. Falhar alto ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o comportamento certo: um controle
negativo que se auto-desativasse em silÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncio seria pior que nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o existir.

> **NOTA SOBRE `compare-reference.ps1`, a partir do passo 6.** O `reference.py`
> modela o decode e o autostretch, e **nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o** conhece a extraÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de fundo. Desde
> que a etapa passou a mexer em pixel, o bloco por canal compara dois quadros
> diferentes, e o comparador diz isso **uma vez** em vez de reprovar 63 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmeros:
> `N/A ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â pipeline roda background e reference.py nao modela ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â passo 8 da ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§6`.
>
> O que sobra do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 0: **todo o bloco de decode**, nos quatro fixtures.
>
> ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° `N/A` e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o `KNOWN` de propÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³sito. A lista `KNOWN` ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© para divergÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncias entre
> duas implementaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes que descrevem a mesma coisa; esta ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© as duas deixando de
> descrever a mesma coisa. Encher `KNOWN` com sessenta entradas transformaria um
> registro de dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vida em papel de parede ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§7 do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 0, "KNOWN nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© uma saÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­da
> de emergÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncia".
>
> **`referencia-cadeia.json` reabriu o bloco.** Ele monta a cadeia inteira ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
> decode, fundo, autostretch sobre o quadro **corrigido** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â e volta a ser
> comparÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡vel nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero a nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero. Ver a seÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o abaixo.

## A cadeia completa contra `chain.py`

`referencia-cadeia.json` fecha o que o passo 6 abriu. O comparador vai a **180
linhas: 174 PASS, 5 N/A, 1 FAIL.**

| fixture | linhas | PASS | FAIL | N/A |
|---|---|---|---|---|
| `seestar` | 13 | 11 | 0 | 2 |
| `rice` | 61 | 60 | 0 | 1 |
| `nonlinear` | 17 | 14 | 1 | 2 |
| `gradient` | 89 | 89 | 0 | 0 |

### A confirmaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o independente do bug do passo 6

O `before` do stretch **ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©** a mediÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o do quadro corrigido. Que estes nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmeros
batam ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© confirmaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de fora de que o conserto do passo 6 estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ certo: uma segunda
implementaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o, escrita depois e montada do zero, mede o mesmo MADN
pÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³s-correÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o. A razÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o entre o dela e o meu:

| `rice` | `nonlinear` | `gradient` |
|---|---|---|
| 1,0062 | 1,0034 | 0,9991 |

O `seestar` dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ 4,51 e **nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© discordÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia**: a referÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncia nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o faz debayer, entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o
o MADN dela ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© dominado pelo padrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o Bayer, que nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© gradiente. O 0,000951 dela
coincide com o valor **prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©**-correÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o daqui (0,000939) porque ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a mesma
grandeza. Bloco por canal em N/A, mesma lacuna do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 0.

### A que reprova, e o que ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©

**Uma linha: `nonlinear fundo.aceitas` 81 contra 82.** As consequÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncias ficam
`N/A` com prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©-condiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o explÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­cita no comparador ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â a tolerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia da ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§7 pressupÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµe
que os dois lados medem **os mesmos pixels**, e conjuntos de amostras diferentes
significam superfÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­cies diferentes.

A causa foi isolada e **nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© nenhuma das trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªs suspeitas ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³bvias**: os limiares
concordam a 0,34 / 0,86 / 0,08 bins; a amostra marginal em (638, 563) estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ 6,2
bins acima do limiar **exato** tambÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m, entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o os dois a rejeitam; e o critÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©rio de
rejeiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© idÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªntico. O que difere ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© **onde a caixa estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡**: `Math.round(562,5)`
dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ 563 em JavaScript e 562 no Python, que arredonda meio para o par. SÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³ o
`nonlinear` cai nisso, porque sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³ nele `w/cols = 75` produz centros em meio
exato. Registrado na ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§2.1 do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 1 como lacuna de especificaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o.

### As 6 que reprovavam antes do termo da mediana

Eram `mad`/`madn` acima do piso da ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§7:

| | bins de span | limite |
|---|---|---|
| `rice` G, B `madn` | 8,75 / 9,45 | 8,00 |
| `gradient` R `mad`, `madn` | 14,58 / 21,62 | 8,00 |
| `gradient` B `mad`, `madn` | 8,59 / 12,74 | 8,00 |

**DiagnÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³stico, e por que nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o afrouxei o nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero.** As medianas concordam
**muito** bem ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 0,19 a 0,81 bins do eixo [0,1], contra um limite de 4. O que
falha ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³ a dispersÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o. A causa ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© que `MAD = mediana(|v ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ m|)` ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© medida
**relativa ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â  mediana**, e o piso da ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§7 ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© dimensionado em bins de `span`, que
depois da correÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ficou 2,5 a 5ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â menor. Um deslocamento de mediana de 0,81 bins
do eixo [0,1] sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o 143 bins de `span` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â o MADN herda a incerteza da mediana
medida num eixo muito mais grosso.

**O termo entrou na ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§7**, e ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© cota e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ajuste: `MAD(m) = mediana(|vÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢m|)` e
`ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“vÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢mÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢d|ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢|vÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢mÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“ ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â°Ãƒâ€šÃ‚Â¤ |d|` pela desigualdade triangular; a mediana ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© monÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³tona, entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o
a cota passa para o MAD. Vale antes de olhar os dados, para qualquer
distribuiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o.

    |a ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ b| ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â°Ãƒâ€šÃ‚Â¤ max( 1e-4ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â·|ref| ,  8ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â·span/65535  +  1,4826ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â·|ÃƒÆ’Ã…Â½ÃƒÂ¢Ã¢â€šÂ¬Ã‚Âmediana| )

Com ele as seis passam com folga ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â para `gradient` R o termo vale 1,84e-5 contra
um `ÃƒÆ’Ã…Â½ÃƒÂ¢Ã¢â€šÂ¬Ã‚Âmadn` observado de 1,87e-6, dez vezes maior. **Controle negativo, para o
termo nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o virar licenÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a:** `madn` perturbado em 3ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â a cota reprova; dentro da
cota passa. Auto-calibrado a partir do `span` do prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³prio golden e da mediana da
prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³pria referÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncia, para nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o envelhecer em silÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncio como os ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncoras de clip
envelheceram.

## O que o float pleno mudou, medido

O passo 2 do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 1 tirou o LUT de 2^20 entradas do `stretch-mtf` e passou a
gravar MTF em precisÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o plena; `quantise` virou o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnico lugar onde um nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©
decidido. A tabela ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a captura float comparada contra os goldens de 8 bits:

| artefato | veredito | o que aconteceu |
|---|---|---|
| `log.txt` ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 3 | **PASS** byte a byte | todo nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero que o log imprime vem do `before` do record de stretch, que nenhuma etapa a jusante move |
| `diag.json` ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 3 | **PASS** byte a byte | mesmo motivo: o painel tambÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© construÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­do do `before` |
| `png` ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 3 | **PASS~** | 0,031% a 0,781% das amostras diferem, **todas por exatamente 1 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel** (mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©dia do \|d\| = 1,00) |
| `records.json` ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 3 | **FAIL** | 23 a 24 campos, **todos em `after.perChannel[*]`**: median, mad, madn, span, q1, q3, p001, p999 |

Nenhum campo de `before` se moveu. Nenhuma contagem de clip se moveu ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
`outLow` e `outHigh` contam os mesmos dois ramos sobre o mesmo `u`, e a mudanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a
nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o os alcanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a. Foi por isso que os goldens de log e diag sobreviveram: o que
mudou fica inteiramente a jusante da quantizaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o que saiu.

**A identidade que a cadeia de 8 bits escondia.** No ramo nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o-linear o alvo do
autostretch ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³pria mediana do canal, entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o `MTF` mapeia mediana em mediana
por construÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o e `after.median` deve ser igual a `before.median`. Na cadeia de
8 bits isso era invisÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel: a mediana pousava em 67/255 = 0,262745. Na cadeia
float ela pousa em 0,2640573739223316 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â o mesmo dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­gito a dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­gito que
`before.median`, nos canais R e B; 3,05e-5 no G, que ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© resoluÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de histograma.
Isso ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© evidÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncia independente de que o caminho novo estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ certo, e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o apenas
diferente.

**Reprodutibilidade verificada.** Uma segunda captura independente, depois de
recarregar a pÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡gina, devolveu os doze artefatos byte a byte idÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªnticos aos
goldens promovidos. A tolerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia existe para mudanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a de build, nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o para ruÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­do
de rodada ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o hÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ ruÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­do de rodada.

**Custo.** `transfer`, relÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³gio de parede, uma amostra por fixture: 244ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢216,
233ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢268, 134ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢96 ms. `quantise` passou a aparecer separado, em 23 a 71 ms. NÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©
mediÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© uma amostra ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o hÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ evidÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncia de regressÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o que importe. O
orÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§amento real da ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§3.6 do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 1 ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o arraste sobre o buffer de preview, e ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© lÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡
que isso precisa ser medido de verdade quando a RBF entrar.

## Fixtures ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â todos sintÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©ticos

**Nenhum arquivo de terceiro entra aqui.** Ver `CLAUDE.md`. Os cinco saem de
`.claude/make-fixture.ps1` com semente fixa e sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o reprodutÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­veis byte a byte ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
verificado: regerar o `fixture-seestar.fit` devolve o mesmo sha256 do arquivo
versionado.

| nome | arquivo | bytes | sha256 |
|---|---|---|---|
| `seestar-fixture` | `test/fixtures/fixture-seestar.fit` | 4.150.080 | `6d0acf7bbd4ce595d926ccc9bbf8e239447cda8ed7207c682fe598f5534cb28b` |
| `rice-fixture` | `test/fixtures/fixture-rice.fit.fz` | 8.671.680 | ver `make-fixture.ps1` |
| `nonlinear-fixture` | `test/fixtures/fixture-nonlinear.fit` | 6.482.880 | ver `make-fixture.ps1` |
| `gradient-fixture` | `test/fixtures/fixture-gradient.fit` | 23.042.880 | `b14ac76614949a4feef20e1c9aa263b29813f7b2a7298f9b461388d482e1fc25` |
| `edge-fixture` | `test/fixtures/fixture-edge.fit` | 1.442.880 | `3f18a50b3e896aab13683cb0b88abd4cc2f26c6a399dcf71072b8531d64ebf38` |

Cinco, e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o um, porque cobrem caminhos disjuntos:

- **`seestar-fixture`** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 1920ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â1080, BITPIX 16, BZERO 32768, ROWORDER BOTTOM-UP,
  BAYERPAT GRBG. Leitura de inteiro, flip de linha, detecÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de CFA, debayer,
  ramo linear. `view.factor` 1.
- **`rice-fixture`** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 2600ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â1000ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â3, RICE_1 com SUBTRACTIVE_DITHER_2, uma tile
  por linha (3.000 tiles). DescompressÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o Rice, dither, caminho de 3 planos sem
  debayer. A borda longa ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© 2600 **de propÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³sito**: passa de `MAX_VIEW` (2560) por
  40 px, entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o `view.factor` = 2 e o PNG vem do buffer de resoluÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o plena, que ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©
  o caminho que o botÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de download realmente usa.

  Traz duas armadilhas embutidas de propÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³sito: um patch 24ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â24 de zeros exatos,
  que exercita o sentinela `DITHER_ZERO` do dither 2 (aparece como 576 pixels
  pretos por canal no diagnÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³stico), e uma quantizaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o com `ZZERO ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â°Ãƒâ€¹Ã¢â‚¬Â  13313,9`
  contra `ZSCALE = 6,2e-6`, que deixa os inteiros logo acima do piso do int32 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
  a configuraÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o que obriga o unquantize a ficar em double.
- **`nonlinear-fixture`** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 900ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â600ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â3, float32 sem compressÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o, ROWORDER
  TOP-DOWN, com cards HISTORY de autostretch e mediana medida 0,2467. Ramo
  nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o-linear: ponto preto por percentil, alvo na prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³pria mediana. O midtones do
  gerador foi calibrado para pousar a mediana em ~0,25, que ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© onde um frame
  realmente esticado no Siril fica ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â um valor mais agressivo levava a mediana
  para 0,73 e o fixture deixava de representar o caso.
- **`gradient-fixture`** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 1600ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â1200ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â3, float32, TOP-DOWN. Para o MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 1.
  Ver a seÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³pria abaixo: ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnico da suÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­te cujo fundo ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© conhecido
  independentemente das duas implementaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes.
- **`edge-fixture`** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 400ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â300ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â3, float32, TOP-DOWN. 1,44 MB, o mais barato da
  suÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­te, e o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnico pequeno o bastante para a margem **padrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o** alcanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ar a grade
  de amostras: 38 das 108 amostras sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o rejeitadas por borda, 6 por brilho, 64
  aceitas. Existe porque `rejected-edge` era alcanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡vel e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o exercitado ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â o
  estado aparecia na spec, no cÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³digo e no tooltip, e em nenhum golden. Cobre de
  passagem o caso de quadro pequeno, que tambÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o tinha nada.

## `fixture-gradient.fit` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnico com uma verdade externa

Os outros trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªs respondem "hoje ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© igual a ontem?" e "as duas implementaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes
concordam?". Nenhuma das duas perguntas alcanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a um erro de fÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³rmula, porque a
referÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncia do Python leu a fÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³rmula daqui ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ registrado na ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§7 do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 0 e
na ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§5 do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 1. Este responde a uma terceira: **o modelo ajustado ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o
gradiente que eu coloquei?**

O que estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ gravado em cards `HISTORY`, e ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© lido de volta pelo teste:

```
g(u,v) = A0 + A1*u + A2*v + A3*u^2 + A4*v^2 + A5*u*v
u = x/(NAXIS1-1)   v = y/(NAXIS2-1)   TOP-DOWN, entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o v=0 ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a primeira linha
```

com os seis coeficientes por canal, mais a geometria do objeto estendido
(`CX CY A B PEAK K`, perfil `I = PEAK*exp(-K*R)` em raio elÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­ptico), as posiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes
das estrelas-sonda, o sigma do ruÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­do e as sementes. 21 cards. O gerador escreve
os cards **das mesmas variÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡veis** que passa ao construtor da cena, entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o hÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡
dois lugares onde o nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero possa divergir.

**Por que TOP-DOWN:** o flip de linha jÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ coberto pelo `seestar-fixture`.
Aqui a clareza do contrato vale mais ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â com TOP-DOWN as coordenadas do `HISTORY`
sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o as coordenadas da imagem, sem inversÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o no meio da comparaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o.

**Por que 1600ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â1200:** nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero redondo. Com `samplesPerRow` 12 a grade ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©
12ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â9, e com `PREVIEW_EDGE` 1024 o fator de preview ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© 2 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o o fixture
exercita o escalonamento de `boxSize` da ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§2.1, que ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a exigÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncia de que uma
caixa de amostra signifique o mesmo pedaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§o de cÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©u no preview e no render.

**Por que ruÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­do gaussiano, e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o uniforme como nos outros:** a rejeiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©
`mediana da caixa > mediana global + tolerance ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â MADN`, e MADN sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³ significa
"sigma" para ruÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­do gaussiano. Com ruÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­do uniforme o limiar de rejeiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o cairia num
lugar sem interpretaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o e o fixture estaria testando outra coisa.

### Medido no fixture gerado, com os parÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢metros padrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o da ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§2.2

Grade 12ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â9 = 108 amostras, caixa 25 px, margem 24 px, `tolerance` 1,0:

| | |
|---|---|
| aceitas | 93 |
| rejeitadas por brilho | 15, das quais **12 sobre o objeto** |
| rejeitadas por borda | 0 |
| fraÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o rejeitada | 13,9% |

Fica bem acima da salvaguarda de 8 pontos e bem abaixo dos 40% que a ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§3.5 manda
avisar. O objeto forÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a rejeiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o, que ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© para o que ele existe.

**ResÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­duo |mediana da caixa ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ verdade| nas aceitas: mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ximo 0,242 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel de 255,
mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©dio 0,030.** A ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§5 sugere 1 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel como tolerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia de partida para o modelo
ajustado contra o gradiente verdadeiro; a amostragem sozinha jÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ entrega um
quarto disso, entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o o orÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§amento sobra para a RBF.

### A mediana sobrevive ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â  estrela; a mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©dia nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o

Oito estrelas-sonda em posiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes gravadas, `PEAK` 0,45 e `sigma` 2,2. O sigma ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©
pequeno de propÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³sito: numa caixa de 625 pixels a estrela levanta cerca de 22%
deles, confortavelmente abaixo de metade. Um sigma maior viraria a mediana
tambÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m e o fixture passaria a argumentar o contrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡rio do que a ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§2.1 afirma.

Nas caixas que contÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªm uma sonda, canal G, em nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­veis de 255:

| desvio da mediana | desvio da mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©dia |
|---|---|
| 0,08 a 0,30 | **5,1 a 5,8** |

Cerca de **20ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â pior para a mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©dia**. ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° a ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§2.1 deixando de ser asserÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o e virando
nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero.

### Duas coisas que o fixture expÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµe de graÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a

**A fraqueza da tolerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia global.** Uma das oito caixas-sonda, em (1253, 1112),
ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© rejeitada por brilho ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â e ali nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o hÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ objeto nenhum, sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³ fundo mais uma estrela.
No canto claro do gradiente o prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³prio fundo jÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ passa de
`mediana global + 1,0 ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â MADN`. ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° exatamente a queixa registrada contra o Siril
na ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§1 ("tolerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia global ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnica para a imagem inteira"), reproduzida num arquivo
onde dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ para medir. NÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© defeito do fixture: ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o defeito que o MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 1b
promete resolver, disponÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel para teste antes de a soluÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o existir.

**Custo em disco, e a decisÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o sobre ele.** 23,0 MB, contra 19,3 MB dos outros
trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªs somados; a ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡rvore de fixtures passa a 42,3 MB.

**Fica assim: 1600ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â1200, sem compressÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o. Decidido, nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o pendente.**

Encolher o quadro perde o que ele testa ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â a grade 12ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â9 e o fator de preview 2
sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o os dois motivos de ele ter esse tamanho. E comprimir para `.fz` misturaria o
caminho Rice com o caminho do gradiente: uma falha neste fixture passaria a ter
duas explicaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes possÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­veis, e separar as duas custaria mais do que os 23 MB
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

Os PNG cresceram entre 15% e 24%: o dither substitui bandas lisas por ruÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­do, e
ruÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­do nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o comprime. ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° o custo direto de nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ter bandas.

`gradient-truth.json` ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnico destes que `compare-golden.ps1` **nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o** compara:
ele vem de `compare-truth.js`, nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o da captura, e ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© medida de referÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncia e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o
artefato de saÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­da. Comparar automaticamente entra junto com o passo 8, quando o
`reference.py` conhecer o fixture.

### O que o passo 4 mudou nestes goldens, medido

A etapa de fundo entrou na cadeia amostrando e rejeitando, sem ajustar
superfÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­cie e sem tocar em pixel. Contra os goldens do passo 3:

| artefato | veredito |
|---|---|
| `log.txt` ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 4 | **PASS** byte a byte |
| `diag.json` ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 4 | **PASS** byte a byte |
| `png` ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 4 | **PASS** byte a byte |
| `records.json` ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â 4 | **FAIL**, `length 1 vs 2` |

O PNG idÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªntico ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a verificaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de que a etapa devolve a imagem intacta: se um
pixel tivesse se movido, ele apareceria. O log idÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªntico ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a verificaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de que
"background extraction" continua na frase "Not applied" ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â `applied: false`, e
`notAppliedLabels` chaveia nisso. E o `records.json` reprova por **mudanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a
estrutural**, nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o por deriva numÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©rica: a cadeia ganhou um record, e nenhuma
tolerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia deve perdoar isso.

Os `records.json` cresceram de ~3,8 KB para 22ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ35 KB. ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° a lista de pontos: cada
amostra com coordenada, estado, mediana por canal e a frase que diz por que foi
rejeitada. A ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§2.2 pede que o motivo esteja no record e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³ no tooltip, e um
ponto rejeitado que some do registro ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a operaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o silenciosa que a confusÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o 21
proÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­be. 117 KB somados, contra 16,5 MB de PNG nos mesmos goldens.

## O modelo contra a verdade ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â passo 5

`test/compare-truth.js` roda no navegador, ajusta a superfÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­cie com o cÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³digo
entregue e compara contra os coeficientes do gradiente lidos de volta dos cards
`HISTORY`. O relatÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³rio fica em `test/golden/gradient-truth.json`.

Isto ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o que `compare-golden` e `compare-reference` nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o conseguem responder. Um
pergunta se hoje ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© igual a ontem; o outro se as duas implementaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes concordam ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
e elas concordam sobre uma fÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³rmula que foi lida deste cÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³digo. Um erro de fÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³rmula
ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© invisÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel para os dois. Aqui a resposta vem de nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmeros que o gerador escreveu
e que nenhuma das duas implementaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes viu.

### ResÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­duo `|modelo ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ gradiente verdadeiro|`, em nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­veis de 255

| regiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o | mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ximo | mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©dio |
|---|---|---|
| fora do objeto (raio elÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­ptico > 2) | **0,168** | 0,031 |
| no canto que a rejeiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o global descarta | **0,168** | 0,067 |
| sob o objeto (raio ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â°Ãƒâ€šÃ‚Â¤ 1) | 0,840 | 0,649 |

A ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§5 do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 1 sugere 1 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel como tolerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia de partida fora das regiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes
rejeitadas. O medido ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© **0,168** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â seis vezes dentro.

O resÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­duo sob o objeto **nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© erro**: ali o esperado ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o gradiente sozinho,
porque o objeto ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© sinal a preservar e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o fundo a remover. O nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero mede
**contaminaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â quanto do objeto vazou para o modelo e seria subtraÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­do dele
no passo 6.

### ContaminaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o, e o que a rejeiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o compra

O pico do objeto vale 13,39 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­veis. O modelo absorve 0,840 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ **6,27%**.

| `tolerance` | aceitas | contaminaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o | resÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­duo fora do objeto |
|---|---|---|---|
| 10 (sem rejeiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o) | 108 | **38,9%** | 0,267 |
| 2,0 | 101 | 10,96% | 0,148 |
| **1,0 (padrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o)** | **93** | **6,27%** | **0,168** |
| 0,5 | 72 | 5,43% | 0,170 |
| 0,25 | 62 | 4,27% | 0,216 |
| 0,0 | 54 | 4,35% | 0,333 |

**A rejeiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o vale um fator de 6.** Sem ela o modelo come 38,9% do objeto ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªs
vezes pior que os 12,5% que o GraXpert perdeu num braÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§o do M31 (ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§1). Com ela,
6,27%, entre os 12,5% do modo IA e os 5% do ajuste manual.

Apertar alÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m de 1,0 rende pouco e cobra: a contaminaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o para de melhorar perto
de 4% enquanto o resÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­duo fora do objeto piora de 0,168 para 0,333. O padrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o 1,0
estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ perto do joelho da curva, e agora isso ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© medida e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o escolha.

### Erro da interpolaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â medido, nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o presumido

A ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§2.3 manda avaliar numa grade de 1/8 e interpolar, e **medir** o erro contra
avaliaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o direta em 1000 pixels, aumentando a grade se passar de 0,5 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel.

| fixture | grade | erro mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ximo |
|---|---|---|
| `seestar` | 241ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â136 | 0,0001 |
| `rice` | 326ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â126 | 0,0000 |
| `nonlinear` | 114ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â76 | 0,0039 |
| `gradient` | 201ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â151 | 0,0004 |

Duas ordens de grandeza dentro do limite no pior caso. O divisor nunca precisou
aumentar ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â mas isso ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© resultado, nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o premissa, e ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© remedido a cada execuÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o.

Os 1000 pixels sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o varridos por passo primo (104729) sobre o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­ndice, que ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©
ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­mpar e portanto coprimo com qualquer potÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncia de dois: sondas consecutivas
caem em fases diferentes dentro da cÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©lula da grade, que ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© onde o erro vive. Um
passo que compartilhasse fator com o divisor amostraria os cantos das cÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©lulas e
reportaria zero.

## Passo 6 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â a correÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o, e o que medi-la encontrou

A correÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© `out = in ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ model + pedestal`, com o pedestal sendo a mediana do
prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³prio modelo, **por canal**. A partir daqui a etapa reporta `applied: true`.

### A razÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o entre canais sobrevive ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â e o nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero que sustenta a frase de log

Medido no `fixture-rice`, mediana de fundo antes e depois da correÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o:

| | antes | depois | deriva |
|---|---|---|---|
| R/G | 1,099312 | 1,099010 | **ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢0,028%** |
| B/G | 0,920354 | 0,919802 | **ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢0,060%** |

E o contrafactual, aritmeticamente, se o pedestal fosse **ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnico** (a mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©dia dos
trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªs) em vez de por canal:

| | resultado | deriva |
|---|---|---|
| R/G | 0,999904 | **ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢9,04%** |
| B/G | 0,999918 | **+8,64%** |

O pedestal ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnico colapsa as duas razÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes para 1,0: ele **lava a cor do fundo**.
Por canal preserva ~150ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â melhor. Nos quatro fixtures a deriva por canal fica
entre 0,016% e 0,44%; a de pedestal ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnico, entre 6,6% e 11,2%.

ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° este o nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero por trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡s da frase *"the ratio between channels is therefore
unchanged: no colour grading"*, que agora estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ no log.

### Negativos, e por que a contagem zero aqui nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© clamp

A regra ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o clampear, e o teste natural ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â "se nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o sobrou negativo, algo
clampeou" ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ **falso alarme nestes fixtures**. Medido no `fixture-gradient`,
canal R:

| | mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­nimo | negativos |
|---|---|---|
| entrada | 0,007542 | 0 |
| corrigido, pedestal real | **0,012405** | 0 |
| corrigido, pedestal forÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ado a 0 | **ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢0,005950** | 882.624 (46%) |

O sinal de clamp nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a contagem, ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© **o mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­nimo pousar exatamente em zero**. Ele
pousa em 0,0124, longe de zero, e com o pedestal zerado os 882 mil negativos
atravessam intactos. Nada clampeia.

A contagem zero ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© aritmÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©tica: o pedestal (0,0184) ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© maior que a excursÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o do
modelo acima da prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³pria mediana (~0,0064), entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o `in ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ model + pedestal` nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o
alcanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a zero. **Lacuna de cobertura:** nenhum fixture tem gradiente forte o
bastante em relaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ao nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel de fundo para produzir negativos no caminho normal.
Dado real com poluiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o luminosa forte produz.

### O dither ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© determinÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­stico

Duas capturas independentes, cada uma depois de recarregar a pÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡gina: os quatro
PNG **byte a byte idÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªnticos**. Semente 20260906, amplitude ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±0,5 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel, ambas no
record do `quantise` e no log.

### O bug que a correÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o expÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â´s: o stretch media o quadro errado

`stepStretchMTF` recebia a mediÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o tirada **antes** da etapa de fundo. Enquanto
a etapa sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³ amostrava isso era inofensivo ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â as duas mediam os mesmos pixels ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â e
virou errado no instante em que um pixel se moveu.

O MADN ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a parte que importa, porque o ponto preto ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© `mediana ÃƒÆ’Ã‚Â¢Ãƒâ€¹Ã¢â‚¬Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ 2,8 ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â MADN`, e o
gradiente removido fazia parte da dispersÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o que o MADN media:

| fixture | MADN antes | MADN depois | fator |
|---|---|---|---|
| `seestar` | 0,000939 | 0,000211 | **4,5ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â** |
| `rice` | 0,001868 | 0,000364 | **5,1ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â** |
| `nonlinear` | 0,019943 | 0,005833 | **3,4ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â** |
| `gradient` | 0,003549 | 0,001395 | **2,5ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â** |

O ponto preto estava de 2,5 a 5 vezes fundo demais, em todo quadro.

**E era invisÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel na mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©trica de saÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­da:** a mediana pÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³s-esticamento fica em ~64
de qualquer jeito, porque o MTF mapeia mediana no alvo seja qual for o MADN. ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° a
mesma classe do erro do ÃƒÆ’Ã…Â½Ãƒâ€šÃ‚Â» ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o falha, nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o avisa, e fica pior para sempre. O
`before` do stretch passa a vir do `after` da etapa de fundo, que jÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ estava
medido e custava zero.

## Passo 7 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â a frase "Not applied", verificada nos dois sentidos

O passo 7 era verificaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o, e o que havia a verificar jÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ tinha acontecido
sozinho: a frase perdeu "background extraction" no passo 6, **com zero ediÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes
em `registry.js`** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â o arquivo nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© tocado desde o passo 5 do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 0.

Verificar que o rÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³tulo sumiu ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© fraco: uma string apagada tambÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m some. A prova ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©
o **round-trip**, e ela passa pelo `buildLog` real:

| `background.applied` | descreve a etapa | nega a etapa |
|---|---|---|
| `true` | **1 linha** | ausente da frase |
| `false` | 0 linhas | **presente na frase** |

Os dois se movem juntos e em direÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes opostas. O invariante nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© "o rÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³tulo
some", ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© **o log ou descreve a operaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ou a nega, nunca nenhum dos dois e nunca
os dois**. Foi essa a segunda metade que o passo 6 quase deixou aberta: a frase
parou de negar antes de alguÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m escrever a que afirma.

Com `applied: false`, a frase volta **idÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªntica** ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â  de antes do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 1 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â
comparada contra o resultado de `notAppliedLabels` sem nenhum record de fundo.

E o guarda do catÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡logo continua vivo: um passo declarado `neverImplemented`
reportando que rodou faz `notAppliedLabels` recusar produzir log, em vez de
produzir um que negue o que acabou de acontecer. Verificado com `id: 'ai'`.

## Grade sobre o quadro inteiro ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â e as duas implementaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes coincidindo

A grade deixou de ser encaixada dentro da margem. Centro em `(i+0,5)ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â·w/cols`; a
margem ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³ critÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©rio de rejeiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o, que ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o que a ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§2.2 sempre disse.

**Depois da mudanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a, contra `reference_bg.py`:**

| | esta implementaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o | `reference_bg.py` | diferenÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a |
|---|---|---|---|
| amostras aceitas | 92 | 92 | 0 |
| rejeitadas por brilho | 16 | 16 | 0 |
| campo limpo R, mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ximo | 0,111218 | 0,111214 | 4,5e-6 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel |
| campo limpo R, mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©dia | 0,011537 | 0,011537 | 2,4e-7 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel |
| campo limpo G, mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ximo | 0,129388 | 0,129384 | 4,1e-6 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel |
| campo limpo B, mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ximo | 0,111776 | 0,111772 | 3,6e-6 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel |
| pedestal R | 0,018307595 | 0,018308640 | 0,00027 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel |

**Cinco algarismos significativos**, com grades independentes e ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lgebra
independente (`numpy.linalg.solve` contra eliminaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de Gauss escrita ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â  mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o). O
resÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­duo de 4,5e-6 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© 1,7e-8 em [0,1] e tem causa identificada: as duas
avaliam a superfÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­cie em retÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­culas de tamanhos diferentes ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 201ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â151 aqui,
200ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â150 lÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o o valor interpolado num pixel difere nessa ordem. O pedestal
difere um pouco mais porque ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a **mediana** dessa retÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­cula, e as duas tomam a
mediana sobre conjuntos de nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³s diferentes.

Antes da mudanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a eram 93 contra 92 aceitas e 0,1688 contra 0,1112 no campo
limpo. **"Grade diferente e ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lgebra diferente" era uma causa sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³.**

**O que a mudanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a custou e rendeu**, medido no `fixture-gradient`:

| | grade encaixada | quadro inteiro |
|---|---|---|
| campo limpo fora do casco das amostras | 31,4% | ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â |
| campo limpo, mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ximo | 0,1688 | **0,1112** |
| campo limpo, mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©dia | 0,0337 | **0,0115** |
| casco das amostras | 1422ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â1024 | 1466ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â1066 |

### Amostragem, por fixture

| fixture | quadro | grade | caixa | geradas | aceitas | brilho | borda |
|---|---|---|---|---|---|---|---|
| `seestar` | 1920ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â1080 | 12ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â7 | 25 | 84 | 72 | 12 | 0 |
| `rice` | 2600ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â1000 | 12ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â5 | 25 | 60 | 53 | 7 | 0 |
| `nonlinear` | 900ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â600 | 12ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â8 | 25 | 96 | 85 | 11 | 0 |
| `gradient` | 1600ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â1200 | 12ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â9 | 25 | 108 | 93 | 15 | 0 |

Os quatro reportam `applied: false` com o mesmo `skipReason`: *sampling only*.

**VerificaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o cruzada do `gradient`:** 93/15/0/0 ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© exatamente o que a anÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lise
independente em PowerShell tinha medido no fixture, e ela usou mediana e MAD por
**seleÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o exata** enquanto a etapa usa **histograma de 65536 bins**. Dois
estimadores diferentes do limiar, 108 vereditos idÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªnticos.

**Preview contra render, medido:** com o buffer reduzido a 800ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â600 e `boxSize`
escalado de 25 para 13, os 108 pontos recebem a **mesma classificaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o** e a
maior diferenÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a de mediana de caixa ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© **0,0185 nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel de 255**. ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° a afirmaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o da
ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§2.1 sobre correspondÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncia preview/render, com nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero.

O `.diag.json` ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© `JSON.stringify(state.diag, null, 2)` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â o objeto cru, nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o o
`dump()` do painel, que arredonda para 8 dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­gitos significativos. Guardar o cru
significa que uma regressÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de ponto flutuante aparece em vez de ser arredondada
para fora. (Os sha256 do diag mudam a cada captura por causa de `timingsMs`; os
da tabela sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o do arquivo versionado.)

## O que nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡vel, e o que deixou de nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ser

**`timingsMs`** no diagnÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³stico continua sendo relÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³gio de parede.
`compare-golden.ps1` recorta o bloco dos dois lados antes de comparar. ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° a ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnica
coisa que ele ignora inteiramente, em vez de comparar com tolerÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ncia.

Nota de arqueologia: os goldens anteriores foram capturados de um build de 10
arquivos cujo `timingsMs` nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o tinha `preview` nem `quantise`. Eles continuaram
vÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lidos atravÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s de todos os refactors do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 0 porque aqueles refactors foram
neutros nos artefatos comparados, e as duas chaves novas caÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­ram dentro do ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnico
bloco que o comparador recorta. O sha256 de build que este arquivo registrava
estava desatualizado desde o passo 7 do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 0; estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ corrigido acima.

**A data no log** era o outro relÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³gio, e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© mais. `runPipeline(buffer,
fileName, post, opts)` recebe `opts.now`, que cai em `new Date()` quando
ausente. O navegador segue imprimindo o dia de hoje; a captura fixa
`__GOLDEN_DATE = '2026-09-05'`. Estes goldens nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o expiram. NÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o mude
`__GOLDEN_DATE`: invalida todos os logs guardados e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o compra nada.

## O corpus malformado

33 arquivos que mentem sobre si mesmos, em `test/malformed/`, gerados por
`test/make-malformed.ps1` e comparados por `test/compare-malformed.ps1` contra
`test/golden/malformed.json`. Vieram de uma auditoria de robustez feita antes da
publicaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o; quatro achados dela viraram correÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de cÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³digo.

**NÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o versionados, e o cabeÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§alho do gerador explica por quÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âª**: a geraÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³
ASCII e inteiros big-endian, idÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªntica em qualquer mÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡quina por construÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ao
contrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡rio dos fixtures, que passam por ponto flutuante e por isso ficam
versionados. A divergÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncia continua detectÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡vel: o `malformed.json` guarda o
sha256 de cada arquivo e o comparador regenera e confere **antes** de olhar
qualquer veredito. `build.ps1 -Check` lÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âª a mesma lista para saber que estes
arquivos nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o precisam estar no git.

**A pergunta ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© outra que a dos goldens.** `compare-golden` pergunta "a saÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­da de
hoje ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a de ontem?". Aqui ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© "isto continua sendo recusado?", e a falha grave ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©
assimÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©trica: `rejeita ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ aceita` ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a pior, porque parece uma rodada
bem-sucedida ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â a pÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡gina produz imagem a partir de bytes que ninguÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m verificou.
Nove casos existem para o lado oposto (`a8`, `a9`, `a10`, `c2`, `d13`, `e2`,
`e3`, `e6`, `e7`, `e8`): sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o os arquivos estranhos que **tÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªm** que passar, e
pegam o dia em que alguÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m apertar uma validaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o demais.

O comparador tambÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m verifica **tempo**, com teto de 3000 ms. "Parou" ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© metade da
afirmaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o: um arquivo que trava a aba falha diferente de um que dÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ erro. Pior
caso hoje: 32 ms, o cabeÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§alho de 4 MB.

### O que a auditoria achou, e o que mudou

| achado | era | virou |
|---|---|---|
| descritor de heap fora do arquivo | **aceitava**, quadro chapado, sem erro | `badheader` antes de qualquer leitura |
| `ZTILE` sem teto | `new Int32Array(t1*t2*t3)` fora do `alloc()`; **+768 MB medidos** de um arquivo de 14 kB | tile limitado pela imagem, atravÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©s do `alloc()` |
| `PCOUNT` negativo | encolhia o tamanho declarado e passava; `RangeError` cru lido como "memÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³ria" | `badheader` |
| `RangeError` sem `kind` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÂ¢Ã¢â€šÂ¬Ã¢â€žÂ¢ `memory` | a justificativa escrita era falsa, e os dois casos acima a desmentiam | `unknown`, e a razÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o inversa estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ escrita: tudo que escala com o arquivo passa pelo `alloc()`, que rotula sozinho |

O par `d11`/`d13` ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o guarda de off-by-one da validaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de ponteiro: um byte
alÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m do fim ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© `badheader`, o byte exato passa e decodifica.

A correÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o mexeu em nenhuma saÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­da legÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­tima ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â os 20 goldens saÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­ram
byte-idÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªnticos sem recaptura, incluindo o `rice-fixture`, que ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o que prova que
o teto de `ZTILE` e a validaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de heap nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o tocam um `.fz` vÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡lido.

## `fixture-colour` ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â a cor conhecida por construÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o

1600ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â1200ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â3, float32, TOP-DOWN. ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºnico golden capturado com parÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢metros que
**nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o** sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o os defaults: `colourCal` fica desligado atÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 3, entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o
capturar com os defaults nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o exercitaria nada da calibraÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o. Os parÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢metros vÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o
pelo mesmo `requestRun` que a interface usaria ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o hÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ caminho de teste
separado.

TrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªs populaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes, trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªs razÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes, **nenhuma perto de outra**, e ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© isso que faz o
resultado dizer *qual* populaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o foi medida em vez de sÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³ "o nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºmero ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© plausÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â­vel":

| populaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o | R/G | B/G | papel |
|---|---|---|---|
| fundo | 0,8571 | 0,5714 | o que a ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§2.1 nivela |
| **estrelas** | **1,2500** | **0,8000** | o que a ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§2.2 tem que achar |
| objeto extenso | 0,9500 | 1,1000 | o que contamina a ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§2.2 |

Medido, com tudo ligado: **1,2511 / 0,7994** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â 0,09% e 0,08% da verdade
injetada. Ganhos 0,7993 ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· 1,0000 ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· 1,2510 contra 0,8000 ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· 1,0000 ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· 1,2500.

### As quatro configuraÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes, e o que cada uma prova

| configuraÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o | R/G | ganho R |
|---|---|---|
| tudo ligado | 1,2511 | 0,7993 |
| sem rejeiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de extenso | 1,2513 | 0,7992 |
| sem corte superior | 1,2521 | 0,7987 |
| **sem os dois** | **1,0027** | **0,9973** |

A ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºltima linha ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o modo de falha inteiro: com as duas defesas desligadas o ganho
vermelho vira **0,9973 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â identidade**. A etapa roda, o record preenche, o log
imprime, e a cor nunca foi medida. As duas linhas do meio mostram que as defesas
se cobrem: o filtro de extenso tambÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m rejeita os aglomerados saturados, porque
um borrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o saturado tem vizinhanÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§a cheia.

### TrÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªs construÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âµes, e a primeira reprovou

Registrado porque a reprovaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o foi a parte ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºtil.

1. **Objeto 240ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Â150, pico 0,060; 40 estrelas saturadas.** A etapa devolveu
   1,127/0,798 ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â a razÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o do **objeto**, quase exata. Medido: 29,8% dos pixels
   selecionados estavam dentro da elipse do objeto. Um fixture que nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o separa
   essas duas respostas certificaria um passo que mede a populaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o errada.
2. **Saturadas com amplitude 3,0 e brilho igual nos trÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªs canais.** As asas
   ficavam cinzas, o que nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o que uma estrela saturada real faz ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â e o nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºcleo
   totalmente preso era menor que o anel parcialmente preso, cuja razÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© *maior*
   que a estelar. Desligar o corte movia a resposta para o lado errado.
3. **A atual:** objeto restaurado, saturadas com a mesma razÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o das estrelas e
   amplitude 30,0, para que o nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âºcleo cinza domine o anel.

### O que este fixture ainda nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o prova

A rejeiÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o de extenso remove **1.646 pixels** aqui, contra 39% da seleÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o no
empilhamento real de M 31. O limiar de brilho sobe muito com 900 estrelas
saturadas no quadro e o objeto acaba quase todo abaixo dele. O filtro estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡
exercitado, nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o estressado; a evidÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Âªncia forte para ele ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© a mediÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o real
registrada na ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§0 da spec, nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o este fixture.

## Cobertura que ainda falta

Nenhum fixture cobre **`.fz` que ainda seja mosaico CFA** ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â descompressÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o e
debayer estÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o cobertos em separado, nunca combinados. O gerador consegue
produzir isso (ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© o caminho int16 + BAYERPAT dentro do escritor Rice); ninguÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â©m
escreveu ainda.

**FECHADO ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â gradiente e objeto extenso.** Era o passo 3 da ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§6 do MÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³dulo 1 e
existe: `fixture-gradient.fit`, seÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o prÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³pria acima.

O que ainda falta em volta dele: o `reference.py` nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o conhece este fixture, entÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o
`compare-reference.ps1` continua em 116 linhas e nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o o cobre. ÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â° o passo 8 da ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§6,
e atÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© lÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡ o gradiente ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â© verificÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¡vel contra os cards `HISTORY` mas nÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o contra uma
segunda implementaÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â£o.
