# Justyear Stretch — Módulo 0: refatoração estrutural

**Objetivo:** reorganizar `index.html` para que novas etapas de processamento possam ser
adicionadas como funções puras, sem tocar na leitura de FITS nem na UI, e para que o
worker segure o dado decodificado e aceite re-execução com parâmetros diferentes.

**Escopo:** esta tarefa NÃO adiciona nenhuma etapa de processamento nova. NÃO muda o
resultado visual. NÃO muda o texto do log. É movimentação de código + mudança de
protocolo + harness de teste.

---

## 0. Critério de aceitação (leia isto primeiro)

O build resultante, rodando no mesmo arquivo FITS de entrada, deve produzir:

1. **PNG byte-idêntico** ao produzido pelo `index.html` atual.
2. **String de log byte-idêntica** à produzida pelo `index.html` atual.
3. **Mesmo JSON de diagnóstico** (permitida diferença nos campos `timingsMs`).

Se qualquer um dos três divergir, a refatoração está errada. Não "melhore" nada no
caminho. A oportunidade de melhorar vem nos módulos 1 a 3.

Este critério tem prazo. Ele vale enquanto a cadeia tiver uma etapa só; quando a
segunda entrar, o quantise passa a acontecer uma vez no fim, a saída muda de
propósito e a comparação vira tolerância relativa. Ver a decisão registrada
na §4.

Antes de começar, gere os três artefatos de referência a partir do arquivo atual e
guarde em `test/golden/`.

> **Decisão (Módulo 0, passo 2): a data sai do relógio e vira parâmetro.**
> `buildLog` imprimia `new Date().toISOString().slice(0,10)` na linha de
> dimensões, então nenhum golden podia continuar byte a byte idêntico depois da
> meia-noite. Assinatura agora é
> `runPipeline(buffer, fileName, post, opts)`, com `opts.now` caindo em
> `new Date()` quando ausente — o navegador continua imprimindo o dia de hoje,
> e a captura de referência fixa a data (`test/capture-golden.js`,
> `__GOLDEN_DATE`). Costura de testabilidade; não muda comportamento. O
> comparador continua estrito e não perdoa campo nenhum além de `timingsMs`.

---

## 1. Estado atual (mapa do arquivo)

`index.html`, 2120 linhas, um arquivo. Três blocos:

| Linhas | Bloco |
|---|---|
| 7–146 | `<style>` |
| 148–223 | markup (drop, busy, err, out, diag, toast) |
| 231–1573 | `<script id="pipeline-src" type="text/worker">` — o pipeline |
| 1575–2118 | `<script>` — controlador de UI |

O bloco `pipeline-src` é lido como **texto** (linha 1635), e executa de duas formas:

- `startWorker()` (1637): `URL.createObjectURL(new Blob([src]))` → `new Worker(url)`
- `startInline()` (1649): `new Function('self', src)(shim)` quando o blob é bloqueado
  (Chrome bloqueia blob workers em `file://`)

**Consequência não negociável:** o código do pipeline não pode conter `import` nem
`export` no arquivo publicado. Ele tem que ser um IIFE clássico, autocontido.

### Funções no bloco pipeline

```
yieldNow, FitsError                                  238–244   helpers
decodeAscii, parseCard, readHeader, hduDataBytes,
  findImageHDU, swap16/32/64, tformBytes             253–455   header FITS
initRandoms, riceDecompress, decodeTileCompressed    456–692   Rice / .fz
normalisePhysical, toNormalisedFloat, flipRows       693–837   normalização
cumulativeAt, analysePlane                           838–889   estatísticas
PATTERNS, vflipPattern, hflipPattern, latticeMedian,
  detectCFA, greenAxisOf, resolvePattern             891–1009  detecção CFA
debayer                                              1015–1054 demosaic
MTF, buildLUT                                        1056–1075 transferência
downscale                                            1077–1106 redução p/ tela
fx, pad, buildLog                                    1108–1253 log
STRETCH_HISTORY, runPipeline                         1255–1555 orquestração
self.onmessage                                       1561–1572 protocolo
```

### Funções no bloco de UI

```
showError, toast                                     1615–1630
startWorker, startInline, process, finish            1637–1768  runner
handleFile, reset, listeners de drag/drop            1773–1812
handlers de copylog / dlpng / dlfits                 1817–1904
isStructuralKey, fitsCard, padCard, historyCards,
  buildFitsBlob                                      1914–2046  escritor FITS
section, dump, renderDiag, toggleDiag                2048–2117  painel diag
```

Nota: `buildFitsBlob` e companhia estão no lado da UI mas não usam DOM. Deixe onde
estão. Mover é churn sem ganho para a v2.

---

## 2. Estrutura de arquivos alvo

```
stretch-tool/
  src/
    pipeline/
      helpers.js          yieldNow, FitsError
      fits/
        header.js         decodeAscii, parseCard, readHeader, hduDataBytes,
                          findImageHDU, swap16/32/64, BLOCK, CARD
        rice.js           tformBytes, initRandoms, riceDecompress,
                          decodeTileCompressed
        normalise.js      normalisePhysical, toNormalisedFloat, flipRows
      image.js            contrato Image + clone + downscaleFloat
      stats.js            BINS, cumulativeAt, analysePlane, measure()
      cfa.js              PATTERNS, vflip/hflipPattern, latticeMedian, detectCFA,
                          greenAxisOf, resolvePattern, debayer
      steps/
        registry.js       catálogo de etapas conhecidas (ver §5)
        stretch-mtf.js    MTF, buildLUT, stepStretchMTF
      render.js           quantise (float→RGBA), downscale (8-bit, p/ tela)
      log.js              fx, pad, buildLog
      run.js              STRETCH_HISTORY, runPipeline, protocolo self.onmessage
  build/
    build.ps1             concatena $Sources + injeta no template  (-Check compara)
    template.html         index.html com um marcador no lugar do pipeline
  test/
    golden/               log, png e diag de referência + MANIFEST.md
    capture-golden.js     captura os três artefatos do navegador
    compare-golden.ps1    comparação estrita contra test/golden/
    fixtures/             .fit e .fz de teste (no .gitignore)
  .gitignore
  index.html              ARTEFATO GERADO — não editar à mão
```

`tformBytes` foi listada em `header.js` neste documento e está em `rice.js`:
é onde ela fisicamente estava, só o leitor Rice a chama (é TFORM de BINTABLE), e
movê-la seria reordenar em vez de cortar — o que custaria a identidade byte a
byte do passo 3 sem ganhar nada.

Os arquivos do passo 3 são só os que já existiam: `image.js`, `steps/registry.js`
e o `measure()` de `stats.js` nascem nos passos 4 e 5. `steps/stretch-mtf.js`
existe desde já com `MTF` e `buildLUT`; `stepStretchMTF` entra no passo 4.

### Build

> **Decisão (Módulo 0, passo 2): sem Node, sem esbuild. Concatenação.**
> Esta máquina não tem Node nem Python — é por isso que todo o harness é
> PowerShell (`NOTAS-SESSAO-FITS.md`). Mas o motivo decisivo não é esse: **o
> esbuild remove comentários** mesmo sem minificar, e os comentários são parte
> do produto pelo mesmo argumento que proíbe a minificação. Concatenar as
> fontes na ordem entrega o arquivo exatamente como foi escrito, e ainda torna
> a verificação mais forte — um passo que só move código sai byte a byte
> idêntico, o que nenhum bundler consegue prometer.

`build/build.ps1`:

1. Lê as fontes de `$Sources` — a lista ordenada dos arquivos de
   `src/pipeline/` — e concatena. Sem transformação: nem reencode, nem tradução
   de fim de linha, nem reordenação.
2. Lê `build/template.html`, substitui o marcador
   `<!--PIPELINE_SRC-->` dentro de `<script id="pipeline-src" type="text/worker">`
   pelo resultado.
3. Escreve `index.html` na raiz.

`build/build.ps1 -Check` monta em memória e compara com o `index.html` em disco,
sem escrever. Sai 1 na divergência.

Consequência da concatenação: as fontes compartilham um escopo só e não podem se
declarar independentes. Ordem importa para `var` de nível superior; declarações
de função sobem. `run.js` é sempre a última, porque termina com o
`self.postMessage({ type: 'ready' })` do handshake.

Sem minificação. O log tem que continuar auditável e o código legível por quem baixar
a página — isso é parte do argumento de confiança do produto.

O `index.html` gerado tem que continuar abrindo por duplo clique, sem servidor, sem
rede. Teste isso explicitamente.

---

## 3. Contrato `Image`

Estrutura única que atravessa todo o pipeline.

```js
// image.js
function Image(data, w, h, channels){
  this.data = data;          // Float32Array, PLANAR, comprimento w*h*channels
  this.w = w;
  this.h = h;
  this.channels = channels;  // 1 ou 3
  this.N = w * h;            // canal c começa em c*N
}
Image.prototype.clone = function(){ ... };   // cópia profunda do data
```

Valores em torno de [0,1] mas **não clampeados** — subtração de fundo pode gerar
negativos e eles precisam sobreviver até o quantize final.

Layout planar já é o que `toNormalisedFloat` e `debayer` produzem hoje. Não mude.

### Downscale em float

```js
function downscaleFloat(img, maxEdge)   // média de caixa, por canal, retorna novo Image
```

Usado para o preview. Não confundir com `downscale()` de `render.js`, que continua
operando em RGBA 8-bit para a tela.

---

## 4. Contrato `Step`

Toda etapa de processamento tem esta assinatura:

```js
/**
 * @param {Image}    img     imagem de entrada (pode ser mutada in place)
 * @param {Object}   params  parâmetros da etapa
 * @param {Function} report  report(record) — empurra um registro no log
 * @returns {Image}          imagem de saída
 */
function step(img, params, report){ ... }
```

### Formato do `record`

```js
{
  id: 'stretch-mtf',            // id estável, casa com registry.js
  name: 'Autostretch',          // nome legível
  applied: true,                // false = etapa existe mas não rodou nesta imagem
  skipReason: null,             // string quando applied === false
  params: { ... },              // EXATAMENTE os valores usados, não os pedidos
  before: {
    perChannel: [ { median, madn, q1, q3, p001, p999 }, ... ]
  },
  after: {
    perChannel: [ { median, madn, q1, q3, p001, p999,
                    clipLow, clipHigh, clipPct }, ... ]
  },
  notes: [ 'frase para o log', ... ]
}
```

`before` e `after` são obrigatórios em toda etapa que toca pixels. É o que permite:

- montar o log com números medidos
- comparar contra a saída do Python no harness de teste
- diagnosticar regressão sem olhar a imagem

`stats.js` ganha um helper:

```js
function measure(img){        // retorna { perChannel: [...] } no formato acima
```

Deve reutilizar `analysePlane`. Não reimplemente.

### Etapa nesta entrega

Só uma: `steps/stretch-mtf.js`, extraída das linhas 1386–1443. Ela recebe os
parâmetros que hoje são constantes locais:

```js
{ shadowSigma: -2.80, target: 0.25, blackPct: 0.0005, nonLinear: <bool> }
```

O cálculo de `nonLinear` fica em `run.js` (é decisão de orquestração, não da etapa) e
entra como parâmetro.

**Não mexa na matemática.** Nem no LUT de 2^20 entradas. O asinh entra no Módulo 3.

> **Decisão (tomada no passo 4, com prazo de validade no Módulo 1): o quantise
> acontece uma vez só, no fim.**
>
> `stepStretchMTF` hoje devolve float com valor de 8 bits — cada pixel volta
> como `k/255` para o `k` que o LUT produziu. Não dá para fazer diferente e
> manter a identidade deste módulo: o LUT quantiza `u` em 2^20 níveis antes de
> avaliar o MTF, então recalcular em precisão plena move os pixels que caem em
> cima da fronteira de arredondamento.
>
> Isso é aceitável **enquanto houver uma etapa só**, porque o 8 bits é a última
> coisa que acontece antes da tela. Deixa de ser no instante em que existir uma
> segunda: a extração de fundo é a **primeira** da cadeia e entrega para a
> seguinte, e uma cadeia em que cada etapa devolve 256 níveis perde a sombra —
> que é exatamente onde a nebulosa fraca vive. Duas etapas em 8 bits não perdem
> o dobro de uma; perdem a faixa inteira em que o Módulo 1 trabalha.
>
> **Regra a partir da segunda etapa:** a cadeia é float pleno de ponta a ponta,
> e `quantise` roda uma única vez, no fim.
>
> **Consequência aceita:** a identidade byte a byte do Módulo 0 morre nesse
> momento, por construção. Não é regressão e não deve ser tratada como uma — é
> o preço, e ele está sendo pago com os olhos abertos.
>
> **O Módulo 5 precisa saber disto antes de começar:** o golden deixa de ser
> comparação byte a byte e passa a ser comparação com tolerância.
> `compare-golden.ps1` tem que ganhar tolerância relativa antes daquele ponto, e
> o PNG deixa de ser critério útil — o critério passa a ser `record.before` e
> `record.after`, por etapa e por canal. É a mesma conclusão da §7: sem os
> números do Python sobre os fixtures, essa comparação não tem contra o que
> pousar.

---

## 5. `steps/registry.js` — o catálogo

Este arquivo existe para resolver o bloqueio da linha 1248 do arquivo atual, que hoje
é uma string literal:

```
'• Not applied: noise reduction, sharpening, saturation, deconvolution,
  star removal, background extraction, colour grading, or any AI or generative step.'
```

Essa frase é o mecanismo de confiança do produto. No dia em que a extração de fundo
entrar, ela vira uma declaração falsa. Ela tem que passar a ser **gerada**.

```js
// registry.js
var CATALOGUE = [
  { id: 'background',    label: 'background extraction' },
  { id: 'denoise',       label: 'noise reduction' },
  { id: 'colour-cal',    label: 'colour calibration' },
  { id: 'star-split',    label: 'star separation' },
  { id: 'stretch-mtf',   label: 'autostretch' },
  { id: 'stretch-asinh', label: 'asinh stretch' },
  { id: 'multiscale',    label: 'multiscale enhancement' },
  { id: 'saturation',    label: 'saturation' },
  // nunca implementadas — declaradas para poderem ser negadas
  { id: 'sharpen',       label: 'sharpening',       neverImplemented: true },
  { id: 'deconv',        label: 'deconvolution',    neverImplemented: true },
  { id: 'ai',            label: 'any AI or generative step', neverImplemented: true }
];
```

`buildLog` gera a linha "Not applied" como o complemento entre o catálogo e os
`record.id` com `applied === true`. Nesta entrega o resultado tem que sair
**textualmente idêntico** à string atual — ajuste a ordem e a redação do catálogo até
bater. É o teste de que a geração funciona.

---

## 6. Mudança de protocolo (o núcleo da tarefa)

### Hoje

```
host → worker : { buffer, fileName }        (buffer transferido, some do host)
worker → host : ready | progress | done | error
```

One-shot. O dado decodificado é descartado ao fim do `runPipeline`.

### Alvo

```
host → worker : { cmd:'open',   buffer, fileName }
worker → host : { type:'opened', preview, header, cfa, records, defaults }

host → worker : { cmd:'run',    params, mode:'preview'|'full' }
worker → host : { type:'rendered', rgba, view, log, records, diag }

host → worker : { cmd:'export', kind:'fits' }
worker → host : { type:'exported', fitsMeta, fitsData }

worker → host : { type:'ready' } | { type:'progress', stage, pct }
              | { type:'error', kind, message }
```

### Regras

- **`open` decodifica uma vez** e guarda no escopo do worker:
  - `source` — o `Image` linear, com row order corrigido e debayer aplicado.
    Imutável a partir daqui.
  - `preview` — `downscaleFloat(source, 1024)`, também imutável.
  - o `hdu`, os records de leitura/CFA, e o `dec.data` original para o export FITS.
- **`run` nunca muta `source` nem `preview`.** Trabalha sempre em `.clone()`.
- `mode:'preview'` roda a cadeia no buffer pequeno. `mode:'full'` no grande.
- O log completo só é montado em `mode:'full'`. Preview devolve `records` mas
  `log: null`.
- `open` já dispara internamente um `run` full com os defaults, para que o
  comportamento visível hoje (soltar arquivo → imagem + log) não mude.

### Custo de memória

Dois `Image` float grandes vivos (`source` + o clone de trabalho) mais o RGBA de
saída. Num frame 3840×2160 RGB isso é ~99 MB + 99 MB + 33 MB. Aceitável. **Não**
implemente pool de buffers nesta entrega; ele entra quando a separação
estrelas/objeto chegar, no Módulo 4.

### Lado da UI

`process()` (linha 1666) se parte em `open()` e `run()`. `finish()` (1742) passa a
tratar `rendered`. O handshake de `ready`, o timeout de 2 s e o fallback para
`goInline()` continuam exatamente como estão — essa lógica está correta e é o que faz
a página funcionar em `file://`. Não mexa.

O botão `dlfits` passa a mandar `{cmd:'export'}` em vez de usar dado que veio junto
com o `done`.

---

## 7. Harness de regressão

> **INVÁLIDA. Substituída pelo harness de navegador — decisão do Módulo 0,
> passo 2.** Cai junto com o Node (ver §2). O texto original fica abaixo, riscado,
> porque o *requisito* que ele expressa continua valendo; só o meio mudou.

O harness roda no navegador, que é onde a ferramenta roda. Não é concessão: o PNG
sai do encoder do Chromium via `canvas.toBlob`, e nenhum processo fora do
navegador produz os mesmos bytes — um harness em Node mediria um artefato que
não é o entregue.

```
powershell -File .claude\serve.ps1 -Port 8791     # servidor estático + POST /save
```

Abrir `http://127.0.0.1:8791/`, colar `test/capture-golden.js` no console,
`await __captureAll()`. Cada fixture é carregada por `window.__loadFromURL(url,
{ now: __GOLDEN_DATE })` e os três artefatos são POSTados para `.claude/shots/`.
Depois:

```
powershell -File test\compare-golden.ps1          # estrito; sai 1 na divergência
```

`compare-golden.ps1` compara PNG e log byte a byte e o diagnóstico byte a byte
menos o bloco `timingsMs`. Tem controle negativo verificado: bit virado no log,
no PNG e valor trocado no diag reprovam os três.

**O que falta trazer para cá quando os módulos 1 a 3 chegarem:** a tabela por
etapa e por canal (`median / madn / q1 / q3 / p001 / p999 / clipPct`, antes e
depois) e a comparação com tolerância relativa contra as medidas do pipeline
Python. Isso é `record.before` / `record.after` da §4 — existe assim que o
contrato de step existir, e o lugar dele é uma extensão de `capture-golden.js`
que salva `records` como quarto artefato.

~~`test/run.mjs`, roda em Node, importa os módulos de `src/pipeline/`
diretamente (aí sim como módulos ES — é só o artefato publicado que precisa ser
IIFE).~~

~~`node test/run.mjs fixtures/m31_stack.fit` — saída: para cada etapa, cada
canal, `median / madn / q1 / q3 / p001 / p999 / clipPct`, antes e depois. Em JSON
e em tabela legível. `node test/run.mjs --compare golden/m31.json
fixtures/m31_stack.fit` compara contra um golden com tolerância relativa
configurável (default 1e-4) e sai com código diferente de zero na divergência.~~

**Construa isto agora, no Módulo 0, mesmo sem etapa nova para testar.** Existem
medidas de referência do pipeline Python para os arquivos reais, e os módulos 1 a 3
precisam pousar contra um teste que já funciona. Sem o harness, a validação vira olhar
a imagem — que é exatamente o método que falhou a semana inteira.

### Cobertura dos fixtures

Nenhum arquivo de terceiro entra nesta árvore — ver `CLAUDE.md`. Todos os
fixtures são sintéticos, gerados por `.claude/make-fixture.ps1` com semente
fixa, e reprodutíveis byte a byte.

| fixture | cobre |
|---|---|
| `fixture-seestar.fit` | int16 + BZERO, BOTTOM-UP, CFA, debayer GRBG, ramo linear |
| `fixture-rice.fit.fz` | RICE_1, dither 2, sentinela de zero exato, 3 planos, `view.factor` 2 |
| `fixture-nonlinear.fit` | float32 cru, TOP-DOWN, ramo não-linear (mediana 0,25 + HISTORY) |

**Pendências de cobertura:**

- **O codificador Rice do `fixture-rice.fit.fz` não tem verificação
  independente.** Ele foi escrito como inverso exato do `riceDecompress` deste
  mesmo repositório, então o par é **auto-consistente**: um erro simétrico —
  mesma convenção errada nos dois lados — passa nos nove checks sem deixar
  rastro. O que o fixture prova hoje é que o decodificador não regride; não
  prova que ele lê RICE_1 como o resto do mundo escreve.

  Fecha abrindo o `fixture-rice.fit.fz` em software externo (Siril, ou
  `funpack` + astropy) e confirmando dimensões, medianas por canal e o patch de
  zeros. Enquanto não fechar, a evidência de conformidade continua sendo a
  histórica: 12/12 valores batendo com astropy num `.fz` real do Siril — que
  não está mais aqui.

- **`.fz` que ainda seja mosaico CFA.** Descompressão e debayer estão cobertos
  em separado, nunca combinados. O gerador já sabe escrever Rice e já sabe
  escrever CFA; falta juntar os dois num fixture.
- **BYTEPIX 1 e 2 no Rice, e BITPIX −64.** Implementados, exercidos zero vezes.

**Bloqueio do Módulo 1** (não do passo 4):

- **Medidas de referência do pipeline Python.** As que existiam foram medidas em
  arquivos de parceiro que não estão mais aqui. Antes do Módulo 1 começar, os
  números têm que ser gerados por fora **sobre os fixtures sintéticos** e
  trazidos para cá. Enquanto isso não acontecer, o harness prova
  não-regressão — que a saída de hoje é a de ontem — e **não** prova correção
  contra uma segunda implementação. A extração de fundo do Módulo 1 muda os
  números de propósito, e num mundo sem segunda opinião não haveria como
  distinguir "mudou porque melhorou" de "mudou porque quebrou".

---

## 8. Restrições

- **Nada de dependência em runtime.** O `index.html` gerado não busca nada da rede,
  nem CDN, nem fonte, nem modelo.
- **Nada de dependência em build-time também.** O build é PowerShell puro e não
  instala nada (ver §2). Não é dogma: é que o bundler que resolveria o problema
  cobra comentários por isso.
- **Nada de `import`/`export` no bundle publicado.** As fontes de `src/pipeline/`
  são concatenadas num escopo só e executadas como script clássico.
- **Não altere o código de leitura de FITS.** Header, Rice, normalização, CFA e
  debayer só mudam de arquivo. Nenhuma linha reescrita. Esse código está validado
  contra dado real de três telescópios e não vai ser revalidado nesta entrega.
- **Não reescreva estilo.** O pipeline usa `var` e `function`. Mantenha. Trocar por
  `const`/arrow gera diff enorme que esconde erro de movimentação.
- **Não "melhore" o MTF, o LUT, o `analysePlane` nem o `downscale`.**
- **Não mexa no CSS nem no markup.**
- `BINS = 65536` fica como está nesta entrega. (Registrado para o Módulo 2: a
  resolução da mediana é 1,5e-5, o que dá ~13 bins para um fundo em 0,0002 — cerca de
  8% de erro. A calibração de cor deriva ganhos de medianas e vai precisar de estimador
  melhor. Não é problema agora.)

---

## 9. Ordem de execução sugerida

1. Gerar os três artefatos golden a partir do `index.html` atual.
2. Montar `build/` e `template.html`, com o pipeline ainda num arquivo só. Buildar.
   Verificar identidade byte a byte. **Este passo sozinho já valida o build.**
3. Quebrar o pipeline nos arquivos de `src/pipeline/`. Buildar. Verificar identidade.
4. Introduzir `Image`, `measure()` e o contrato de step. Migrar o autostretch.
   Buildar. Verificar identidade.
5. Introduzir `registry.js` e gerar a linha "Not applied". Verificar que o log sai
   idêntico.
6. Trocar o protocolo para `open`/`run`/`export`. Verificar identidade.
7. Escrever `test/run.mjs`.

Cada passo termina com o build passando e os três artefatos idênticos. Se um passo
quebrar a identidade, pare e resolva antes do próximo.
