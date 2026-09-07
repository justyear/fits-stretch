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
powershell -File test\compare-golden.ps1          # nao-regressao; sai 1 na divergência
powershell -File test\compare-reference.ps1       # correção; sai 1 na divergência
```

São **quatro** artefatos por fixture: `log.txt`, `diag.json`, `records.json` e
`png`. O `records.json` é o `record.before` / `record.after` da §4 — a tabela por
etapa e por canal, com `median / mad / madn / q1 / q3 / p001 / p999 / span`,
`shadows / midtones / target / scale`, e `clipLow / clipHigh / clipPct`.

Os dois comparadores respondem a perguntas diferentes e nenhum substitui o
outro:

- **`compare-golden.ps1`** — a saída de hoje é a de ontem? ~~PNG, log e
  `records.json` byte a byte; diagnóstico byte a byte menos `timingsMs`.~~
  Controle negativo verificado: bit virado no log, no PNG e valor trocado no
  diag reprovam os três.

  > **Critério substituído no passo 2 do Módulo 1, como esta spec previu na
  > §4.** A cadeia virou float pleno, `quantise` passou a rodar uma vez no fim, e
  > a identidade byte a byte morreu junto — por construção, não por regressão.
  >
  > O comparador agora responde em duas partes e diz qual respondeu: `PASS`
  > quando os bytes são idênticos, `PASS~` quando diferem e toda diferença cabe
  > na tolerância desta mesma §7, `FAIL` fora disso. O pior caso sai impresso
  > como fração do limite. O log continua exato, porque todo número que ele
  > imprime vem de `record.before` e nenhuma etapa a jusante o move.
  >
  > A tolerância entrou **antes** da mudança de cadeia, e foi verificada
  > não-portante: com o build pré-float e os goldens antigos, os doze artefatos
  > voltaram `PASS` byte a byte. Sem essa ordem, o harness reprovaria trabalho
  > correto na primeira rodada e não haveria como distinguir isso de regressão.
  >
  > Controles negativos refeitos para o critério novo: 19, todos como esperado.
  > Ver o cabeçalho de `test/compare-golden.ps1` e a seção "O que o float pleno
  > mudou" em `test/golden/MANIFEST.md`.
- **`compare-reference.ps1`** — os números concordam com algo que não é este
  código? Compara `records.json` e o bloco `decoded` do diagnóstico contra
  `justyear-referencia.json`, com a tolerância acima. Controle negativo
  verificado: uma mediana deslocada de 1e-4 absoluto reprova.

Estado atual: **116 linhas, 115 PASS, 0 KNOWN, 1 N/A, 0 FAIL.** O N/A é o
`fixture-seestar`, que a referência mede como mosaico CFA antes do debayer — o
bloco `decoded` ainda é comparável e é comparado; os canais não são, porque são
medições de imagens diferentes.

### Verificação de hash antes de comparar

As três primeiras linhas conferem o sha256 e o tamanho de cada fixture contra o
que a referência registra. Fixture divergente é pulado inteiro, com FAIL e
mensagem dizendo o que fazer. Sem isso, regerar um fixture sem regerar a
referência deixaria dois conjuntos de números descrevendo imagens diferentes,
concordando ou discordando por motivo nenhum que se pudesse ler na saída.
Controle negativo verificado.

### `KNOWN` não é uma saída de emergência

O comparador aceita uma lista de divergências conhecidas, e cada entrada exige
motivo escrito e o módulo que resolve. Qualquer coisa fora dela é FAIL. A lista
é dívida, não exceção — se crescer, o harness parou de significar alguma coisa.

**Está vazia, e deve continuar.** A única entrada que ela já teve foi o
sentinela de zero exato do `SUBTRACTIVE_DITHER_2`, fechada — e fechada a favor
desta implementação.

### O sentinela do `SUBTRACTIVE_DITHER_2` — fechado

As duas implementações discordavam sobre 576 pixels por canal do `fixture-rice`,
o patch 24×24 de zeros exatos: `rawMin` 0 aqui, `-0.5066145062446594` na
referência.

O inteiro reservado `-2147483647` está fisicamente no `.fz`, no padrão de bits
exato. Com o `ZSCALE = 6,2e-06` e o `ZZERO = 13313,892` lidos da tabela binária,
dequantizá-lo sem tratá-lo como sentinela varre de `-0,5066083` a `-0,5066145`
em exatamente 576 pixels por canal — que é exatamente a faixa que a referência
reportava. O astropy 8.0.1 documenta que restaura o sentinela; na prática não
restaurou. Corrigido no `reference.py`: 1728 pixels, `rawMin` volta a 0,0,
medianas e `clipLow` inalterados.

**Consequência que vale mais que o próprio conserto:** isto descarta a hipótese
de erro simétrico levantada quando o codificador Rice foi escrito. O sentinela
foi lido como inteiro cru por ferramenta terceira, direto do arquivo. Um
codificador e um decodificador que errassem juntos não colocariam o padrão de
bits certo no lugar certo do heap. A conformidade do `RICE_1` daqui não depende
mais de concordância entre duas metades escritas pela mesma pessoa.

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

**FECHADO — o codificador Rice tem verificação independente.** O
`fixture-rice.fit.fz` foi lido por dois softwares que não são este: astropy
mediu R/G = 1,0998 e B/G = 0,9201 contra os 1,099 / 0,920 daqui, e o Siril abriu
o arquivo como `3 layer(s), 2600x1000, 32 bits`. E o inteiro reservado do
`SUBTRACTIVE_DITHER_2` foi lido como inteiro cru, direto do heap, por ferramenta
terceira — ver §7. A hipótese de erro simétrico está descartada: duas metades
escritas pela mesma pessoa podem concordar sobre uma convenção errada, mas não
colocam o padrão de bits certo no lugar certo do arquivo. `RICE_1` com
`BYTEPIX 4`, `SUBTRACTIVE_DITHER_2` e o sentinela de zero exato estão conformes.

**FECHADO — as medidas de referência do Python existem.** Geradas sobre os três
fixtures sintéticos, em `REFERENCIA-PYTHON.md` e `justyear-referencia.json`.
Independentes em linguagem, leitor de FITS, descompressão, precisão (float64
contra float32), estatística (exata contra histograma) e transferência (MTF
direta contra LUT). **Não** independentes na fórmula, que foi lida daqui — então
validam aritmética, não escolha de algoritmo. Um erro na fórmula do autostretch
continua invisível para as duas.

**Pendências de cobertura:**

- **`.fz` que ainda seja mosaico CFA.** Descompressão e debayer estão cobertos
  em separado, nunca combinados. O gerador já sabe escrever Rice e já sabe
  escrever CFA; falta juntar os dois num fixture.
- **BYTEPIX 1 e 2 no Rice, e BITPIX −64.** Implementados, exercidos zero vezes.
- **Debayer contra segunda implementação.** O Python não implementou o debayer,
  então o `fixture-seestar` só tem referência de mosaico, antes da interpolação.
- **Fundo abaixo de 0,005.** Nenhum fixture chega lá, e é onde o histograma de
  `BINS = 65536` começa a degradar de verdade (2,3% de erro na mediana a 0,0005,
  contra 0,009% a 0,017). A calibração de cor do Módulo 2 deriva ganhos de
  razões entre medianas: se a mediana de um canal cair abaixo de 0,005, trocar o
  estimador por seleção exata antes de derivar ganho.

### Tolerância da comparação contra a segunda implementação

O golden é comparado byte a byte; a referência do Python **não pode ser**, e não
por frouxidão. As duas implementações medem a mesma coisa por caminhos
diferentes, e o piso do erro é a resolução do histograma daqui, não desacordo.

    valor na escala [0,1]  (mediana, q1, q3, percentis, shadows, midtones):
        |a − b| ≤ max( 1e-4 × |ref| ,  4 / 65535 )

    MAD e MADN:
        |a − b| ≤ max( 1e-4 × |ref| ,  8 × span / 65535  +  1,4826 × |Δmediana| )
        onde span = 3 × (q3 − q1) do canal, ou 1/65535 se o IQR for zero,
        e Δmediana é a diferença entre as medianas dos dois lados

**Derivação do termo `1,4826 × |Δmediana|`, em uma linha:**
`MAD(m) = mediana(|v − m|)`, e `‖v − m − d| − |v − m‖ ≤ |d|` para todo `v` pela
desigualdade triangular; a mediana é monótona, então a cota passa para o MAD,
e `MADN = 1,4826 × MAD`. **É cota, não ajuste** — vale antes de olhar qualquer
dado, para qualquer distribuição.

**O motivo estrutural, que é o que torna o termo necessário e não cosmético:**
a mediana é julgada em bins do eixo `[0,1]` e o MAD em bins de `span`. Depois da
extração de fundo o `span` encolhe 2,5 a 5×, porque a variação que ele media era
o gradiente — então **o MAD passa a ser julgado numa escala fina carregando
incerteza herdada de uma escala grossa**. Um deslocamento de mediana de 0,81 bins
de `[0,1]` são 143 bins de `span`. Sem o termo, seis comparações corretas
reprovavam.

Medido no que forçou o termo: `gradient` R, `Δmadn` observado 1,87e-6 contra um
termo novo de 1,84e-5 — dez vezes de folga. A cota não é apertada; ela só
precisa existir.

    saída em 8 bits, por pixel:   até 1 nível
    contagem de clip:             0,05% do total  <- SÓ contra o Python

### A contagem de clip tem dois limites, e o motivo é a pergunta

**Contra a segunda implementação (`compare-reference.ps1`): 0,05% do total.**
As duas contam a mesma coisa por caminhos diferentes — histograma contra seleção
exata, float32 contra float64 — e um punhado de pixels de cada lado de um limiar
é o instrumento, não desacordo.

**Contra o golden (`compare-golden.ps1`): EXATA, sem tolerância.** Ali é uma
implementação contra ela mesma. `outLow` é um inteiro contado por um laço sobre
os mesmos pixels com o mesmo ramo: entre duas rodadas do mesmo código ou bate,
ou o código mudou. Não existe piso de ruído a perdoar.

**O que forçou a distinção**, e é por isso que ela está escrita aqui em vez de
ser convenção: no passo 6 do Módulo 1 a contagem `pixelsBlack` do canal G do
`nonlinear-fixture` foi de **269 para 0** — o corte de sombra desapareceu por
inteiro, porque a extração de fundo removeu o gradiente que o causava — e passou
como "dentro da tolerância", **por um pixel** (269 contra o limite de 270).

Uma tolerância que perdoa uma contagem indo a zero não está medindo aquela
contagem. E a generalização vale além do clip: **grandeza medida admite piso de
instrumento; inteiro contado não.** Antes de dar tolerância a um campo, pergunte
qual das duas coisas ele é.

Controle negativo adicionado, em `test/negative-controls.ps1`: clip de 56 para
57, de 56 para 290 e de 56 para 0, mais `pixelsBlack` de 265 para 0 no
diagnóstico. Os quatro reprovam.

**Por que 1e-4 relativo sozinho não serve:** um bin vale 1/65535 = 1,53e-5, que
numa mediana de 0,017 já são 9e-4 relativos. Um limite de 1e-4 reprovaria 14 dos
24 valores de uma implementação correta — o mesmo erro que reprovar o LUT por
±1 nível.

**Por que MAD e MADN precisam de outro piso:** eles não vivem em [0,1]. Saem do
segundo histograma do `analysePlane`, que usa escala adaptativa
`span = 3×(q3−q1)`, então o bin deles é `span/65535`. Nos fixtures lineares o
span fica em torno de 0,007, o que faria o piso plano de `4/65535` valer entre
500 e 800 bins de MADN — passaria erro quinhentas vezes maior que a resolução
real. O piso tem que acompanhar a escala.

Verificado nos 24 valores das duas tabelas: nenhum reprovado, pior caso 2,76
bins em [0,1] (limite 4) e 7,25 bins de span em MADN (limite 8). As margens são
estreitas de propósito — o critério é o piso do instrumento, não folga.

Para que a segunda linha seja calculável, `measure()` expõe `span` junto do MAD.
É campo de diagnóstico e não muda comportamento.

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
