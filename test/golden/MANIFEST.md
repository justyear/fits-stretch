# Golden artifacts — Módulo 0

Referência do critério de aceitação da §0 da spec: PNG e log **byte a byte**,
diagnóstico igual **menos `timingsMs`**.

Capturados do build sha256
`68b376f430556ab17198df9b5b5366094a4eb66ecf89de2cc7bfaf91e10d5781`
(82.890 bytes — pipeline em 10 arquivos, com `opts.now`).

Navegador: Chromium 148 (`Chrome/148.0.7778.280`, in-app browser do Claude
Code). Isso importa para o PNG: os bytes saem do encoder do Chromium via
`canvas.toBlob`, e outro encoder produz outro arquivo com os mesmos pixels.

## Como reproduzir

```
powershell -File .claude\make-fixture.ps1        # se os fixtures não existirem
powershell -File .claude\serve.ps1 -Port 8791
```

Abrir `http://127.0.0.1:8791/`, colar `test/capture-golden.js` no console,
`await __captureAll()`. Os arquivos caem em `.claude/shots/`. Depois:

```
powershell -File test\compare-golden.ps1
```

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
| `seestar-fixture.diag.json` | 4.212 | `ee605012756698960b9467f184abaa78f6c4fae913a99f83aab279321a3be9e5` |
| `seestar-fixture.png` | 4.546.903 | `6f3cdf8f87c404de8ffe44410bc09e48682cfc9c5e1b92e9a2134a4596fa154b` |
| `rice-fixture.log.txt` | 1.765 | `6337bfc4a2f5b73645798896ae5668e7c1e8e94c03908dd2734e9490efd7fc4f` |
| `rice-fixture.diag.json` | 4.646 | `7ac9261a522e6f09e1b5e9d87a5eec70356bf0e78078436f423b8632f7a303a5` |
| `rice-fixture.png` | 5.862.316 | `60771ed6315dd282839bab410677c8004553bfa032c9c7b5b2fda233399be871` |
| `nonlinear-fixture.log.txt` | 1.634 | `f4b8c6e22a629ba8ddb825da0f6fe557908f11242261d7cfe3bb38c29c61847e` |
| `nonlinear-fixture.diag.json` | 3.567 | `46ad7b8c4dae0a2bbdb6a46fae473524edd63c6cae28d176f6ad1af031a074e7` |
| `nonlinear-fixture.png` | 1.340.904 | `c5dfa4aa96f226a6070bda4e1bcb0ad9077c030e8f36c1a58da7a14e5aac67bb` |

O `.diag.json` é `JSON.stringify(state.diag, null, 2)` — o objeto cru, não o
`dump()` do painel, que arredonda para 8 dígitos significativos. Guardar o cru
significa que uma regressão de ponto flutuante aparece em vez de ser arredondada
para fora. (Os sha256 do diag mudam a cada captura por causa de `timingsMs`; os
da tabela são do arquivo versionado.)

## O que não é estável, e o que deixou de não ser

**`timingsMs`** no diagnóstico continua sendo relógio de parede. A spec permite;
`compare-golden.ps1` recorta o bloco dos dois lados antes de comparar. É a única
tolerância que o comparador tem.

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
