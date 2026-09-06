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
`056aa018c30f02b097d7a4a403b017f8f4465b5c2b617796555e30699c650a4f`
(107.877 bytes — pipeline em 12 arquivos, cadeia em float pleno).

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
consegue rodá-la de novo. São 19 casos, e o que mais importa é o `madn +2e-5`:
ele reprova pela regra de `span` e passaria pela regra de [0,1], que nessa
magnitude é seis vezes mais frouxa. É o único caso capaz de distinguir as duas.

## O que o float pleno mudou, medido

O passo 2 do Módulo 1 tirou o LUT de 2^20 entradas do `stretch-mtf` e passou a
gravar MTF em precisão plena; `quantise` virou o único lugar onde um nível é
decidido. A tabela é a captura float comparada contra os goldens de 8 bits:

| artefato | veredito | o que aconteceu |
|---|---|---|
| `log.txt` × 3 | **PASS** byte a byte | todo número que o log imprime vem de `record.before`, e `buildLog` recebe `records[0].before.perChannel` |
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

**Nenhum arquivo de terceiro entra aqui.** Ver `CLAUDE.md`. Os três saem de
`.claude/make-fixture.ps1` com semente fixa e são reprodutíveis byte a byte —
verificado: regerar o `fixture-seestar.fit` devolve o mesmo sha256 do arquivo
versionado.

| nome | arquivo | bytes | sha256 |
|---|---|---|---|
| `seestar-fixture` | `test/fixtures/fixture-seestar.fit` | 4.150.080 | `6d0acf7bbd4ce595d926ccc9bbf8e239447cda8ed7207c682fe598f5534cb28b` |
| `rice-fixture` | `test/fixtures/fixture-rice.fit.fz` | 8.671.680 | ver `make-fixture.ps1` |
| `nonlinear-fixture` | `test/fixtures/fixture-nonlinear.fit` | 6.482.880 | ver `make-fixture.ps1` |

Três, e não um, porque cobrem caminhos disjuntos:

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

## Artefatos

| arquivo | bytes | sha256 |
|---|---|---|
| `seestar-fixture.log.txt` | 1.609 | `9e8c6311cf06c888e8c2357cccf780060bc6765d5043757f8a893f68c3175869` |
| `seestar-fixture.diag.json` | 4.251 | `642f32e25ee32b519556aa2bede9445c283d72f6ec5563cc52697f40c0df97ab` |
| `seestar-fixture.records.json` | 3.798 | `7cb47250bcc2c9ffb825ea64725f0294fd53d70f66dae3b203dcb6a8fb6d3f01` |
| `seestar-fixture.png` | 4.546.701 | `6287a0b25b937c3b5cb309cc9a9df130136e3e6dbda7fb0e987f54a6c28162a5` |
| `rice-fixture.log.txt` | 1.765 | `6337bfc4a2f5b73645798896ae5668e7c1e8e94c03908dd2734e9490efd7fc4f` |
| `rice-fixture.diag.json` | 4.685 | `96d69e52ebd6f63c94dc8ea64bdef45de5359ad6ba1afdccfed984048ea38e40` |
| `rice-fixture.records.json` | 3.842 | `f95a93459726ada75f3aa047f2c074376c176b4017c352474e2b1984efe6b706` |
| `rice-fixture.png` | 5.862.158 | `2af37579df49ff18becf49a0f2b5917230fe3298310321f943800e28a19be65d` |
| `nonlinear-fixture.log.txt` | 1.634 | `f4b8c6e22a629ba8ddb825da0f6fe557908f11242261d7cfe3bb38c29c61847e` |
| `nonlinear-fixture.diag.json` | 3.604 | `790642a11e7b47001137a8f5dd9f3971da132fd4ffc4a344a39ce17a21eeb972` |
| `nonlinear-fixture.records.json` | 3.860 | `f7108ba8dc3cc427f70ba7380f9efa179340dc4201c86b9e725bdd365d55dd8c` |
| `nonlinear-fixture.png` | 1.340.894 | `3003c8f9ccb75042fb430b9772825ae5fbb2d0aafefc17761cdd71cc37de04ec` |

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

E nenhum fixture tem gradiente ou objeto extenso, então a rejeição de amostras
do Módulo 1 ainda não é testável. É o passo 3 da §6 daquela spec:
`fixture-gradient.fit`, com os coeficientes do gradiente gravados em cards
`HISTORY` para que o teste compare o modelo ajustado contra a verdade, e não
contra si mesmo.
