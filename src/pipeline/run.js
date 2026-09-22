/* ------------------------------------------------------------------ *
 * Pipeline — open / run / export
 *
 * The decoded frame is read once and kept here, so re-running the chain with
 * different parameters costs a stretch instead of a decode. `source` and
 * `preview` are immutable from the moment open() finishes: every run works on
 * a clone.
 * ------------------------------------------------------------------ */

/* O CATALOGO DE TERMOS DE ESTICAMENTO, COM PROCEDENCIA POR ENTRADA.
 *
 * Esta tabela e uma afirmacao sobre O QUE OUTROS PROGRAMAS ESCREVEM, e ate esta
 * linha ser escrita ela nao tinha origem registrada em lugar nenhum -- nem
 * comentario, nem spec, nem NOTAS. Sete padroes, nenhuma evidencia.
 *
 * E o circuito estava fechado: a unica coisa na suite que a "confirmava" e o
 * HISTORY do `fixture-nonlinear`, QUE FOI ESCRITO A PARTIR DESTA MESMA CRENCA.
 * Uma crenca virou codigo, a mesma crenca virou fixture, e o fixture confirma o
 * codigo -- duas pecas, um autor, zero contato com o mundo, e um verde
 * indistinguivel do verde de uma coisa medida.
 *
 * A defesa nao e desconfiar mais: e anotar DE ONDE VEIO, entrada por entrada.
 * Tres niveis, e a diferenca entre eles muda o que a proxima pessoa faz:
 *
 *   MEDIDO       lido de um arquivo real, com o texto verbatim
 *   DOCUMENTADO  esta escrito na documentacao do programa
 *   SUPOSTO      ninguem verificou; e o que se acredita
 *
 * Estado hoje: UMA MEDIDA, UMA REFUTADA, cinco SUPOSTO. As duas primeiras sao o
 * mesmo arquivo do Siril 1.4.4 -- ele NAO escreve "autostretch" e escreve
 * "Histogram Transf.", entao uma medicao fechou duas entradas em direcoes
 * opostas.
 *
 * O que fecha cada uma das cinco restantes e um arquivo do programa
 * correspondente com a operacao aplicada, reportando so as linhas de HISTORY.
 *
 * A ORDEM IMPORTA: o laco pula uma regra cujo rotulo ja esta em `historyHits`.
 */
var STRETCH_HISTORY = [
  /* REFUTADO -- e a refutacao e a primeira medicao que esta tabela recebeu.
   *
   * Um arquivo do Siril 1.4.4 com a transformacao de histograma APLICADA DE
   * VERDADE (mediana 0,001177 -> 0,250309) NAO contem a palavra `autostretch`
   * em lugar nenhum do HISTORY. As quatro linhas que ele grava sao:
   *
   *     mean stacking with winsorized sigma clipping ... normalized output ...
   *     TOP-DOWN mirror
   *     Assigned ICC profile: sRGB-elle-V4-srgbtrc.icc
   *     Histogram Transf. (mid=0.001, lo=0.001, hi=1.000)
   *
   * E o motivo e o que torna isto uma licao e nao um detalhe: no Siril o
   * "autostretch" e um MODO DE VISUALIZACAO. Ele muda como a tela mostra o
   * quadro e nao toca nos pixels -- medido tambem, num segundo arquivo: olhar em
   * autostretch e salvar devolve a mediana original, 0,001177, e nenhum rastro.
   *
   * O botao de visualizacao e a operacao de arquivo tem o mesmo nome, e so a
   * segunda deixa rastro -- COM OUTRO NOME. A entrada mais provavel de ser
   * confirmada primeiro era a que nao tinha candidato.
   *
   * Fica no lugar porque outro programa pode gravar a palavra, e remover uma
   * entrada refutada para UM escritor seria trocar uma suposicao por outra.
   */
  [/autostretch/i,            'Autostretch'],

  /* MEDIDO -- Siril 1.4.4, e a amostra e de DOIS arquivos, nao de um.
   *
   * Dois alvos diferentes, a mesma versao, a mesma sessao:
   *
   *     arquivo A   Histogram Transf. (mid=0.001, lo=0.001, hi=1.000)
   *     arquivo B   Histogram Transf. (mid=0.002, lo=0.000, hi=1.000)
   *
   * Duas cenas distintas, MESMO FORMATO DE LINHA e mesma estrutura. E o que
   * torna esta entrada MEDIDA e nao apenas vista uma vez: o que ela reconhece e
   * a forma, e a forma repetiu.
   *
   * Unica das sete que casa os arquivos medidos, e a unica MEDIDA das sete.
   *
   * E ELA ACERTA POR UM DETALHE QUE NINGUEM REGISTROU: o padrao usa o PREFIXO
   * `transf`, nao a palavra inteira. Conferido -- `histogram\s*transf` casa
   * "Histogram Transf."; `histogram\s*transformation` NAO casa. O Siril escreve
   * a forma abreviada, e a entrada sobrevive porque quem a escreveu parou em
   * `transf`.
   *
   * Nao ha registro de por que parou. Entao: acerta, e o motivo de acertar nao
   * estava escrito -- que e diferente de acertar por desenho, e a procedencia
   * existe para nao deixar os dois parecerem a mesma coisa.
   *
   * E A LINHA TRAZ OS PARAMETROS, mas NAO servem para o que parecia.
   *
   * `mid` e `lo` sao os midtones e o ponto preto da MTF. A tentacao e
   * reconstruir o esticamento a partir deles. NAO DA, e a causa foi medida do
   * outro lado, no arquivo B, cujos parametros foram resolvidos numericamente e
   * conferidos pixel a pixel:
   *
   *     HISTORY diz   mid=0.002     lo=0.000
   *     real          mid=0.002428  lo=0.000368
   *
   * O Siril ARREDONDA PARA TRES CASAS ao escrever. Com os valores reais, a
   * reconstrucao fecha em 3,5e-08 por pixel -- precisao de float32. Com os
   * valores escritos, nao fecha: `lo` vira 0,000 exato.
   *
   * E o dano e assimetrico. `mid` perde 18% e ainda diz a ordem de grandeza;
   * `lo` perde 100% DA INFORMACAO, porque tres casas nao distinguem 0,000368 de
   * zero -- e 0,000368 e exatamente a ordem onde o ponto preto mora num quadro
   * linear. O campo que mais precisa de precisao e o que recebe menos.
   *
   * SEGUNDA INSTANCIA do arredondamento de tres casas do Siril neste projeto. A
   * primeira esta no NOTAS e custou um dia.
   *
   * PARA O QUE ELES SERVEM, e e mais barato e mais util:
   *
   *   detectar    que houve esticamento -- o que a tabela ja faz
   *   ordem de grandeza  midtones ~0,002 e a escala do que foi aplicado
   *   CONFERIR    se a mediana observada e compativel com um MTF de midtones
   *               dessa ordem, as duas fontes concordam. Se o HISTORY declara
   *               mid=0,002 e a mediana esta em 0,001, alguma coisa esta errada.
   *
   * A terceira e a conferencia de falsificacao da spec-escala-decisao.md
   * aplicada ao ESTICAMENTO, e nao so a escala. Anotada, nao feita.
   *
   * E UMA CONFIRMACAO EXTERNA QUE VEIO DE GRACA: os TRES canais do arquivo usam
   * os MESMOS mid e lo. O Siril estica LIGADO, nao por canal -- que e a mesma
   * decisao que o Modulo 3 tomou aqui por medicao propria, chegando nela por
   * outro caminho. A ferramenta de referencia do campo faz a mesma escolha.
   */
  [/histogram\s*transf/i,     'Histogram Transf.'],
  // SUPOSTO -- o Siril tem um esticamento asinh. A palavra tambem aparece em
  // contexto que NAO e esticamento (discussao de escala), e isso nao foi medido.
  [/asinh/i,                  'Asinh stretch'],
  // SUPOSTO -- GHS e um script de terceiro, nao uma operacao nativa; se ele
  // grava HISTORY, e com que texto, e a entrada com menos base das sete.
  [/generalised hyperbolic|generalized hyperbolic|\bGHS\b/i, 'GHS'],
  // SUPOSTO -- "Midtones Transfer Function" e o nome da operacao nas duas
  // ferramentas; a forma abreviada no HISTORY nao foi vista.
  [/midtone/i,                'Midtones transfer'],
  // SUPOSTO, E A MAIS ARRISCADA DAS SETE -- e o risco esta medido, nao suposto.
  //
  // `curves` e a unica das sete que NAO e termo tecnico: e palavra comum em
  // ingles e pode casar numa linha de HISTORY que nao fala de esticamento.
  //
  // O CUSTO DO FALSO POSITIVO, e ele so existe numa janela estreita: casar aqui
  // troca o limiar da regra linear de 0,05 para 0,02. Isso so muda o veredito
  // quando a mediana do quadro esta ENTRE os dois. Fora da janela o veredito e o
  // mesmo com ou sem o falso positivo.
  //
  // Medido nos vinte fixtures: UM esta dentro da janela -- o `bigobject`, em
  // 0,04938. E e o mesmo que o inventario de margens ja pegou a 1,2% do limiar
  // de 0,05, entao ele esta exposto pelos dois lados.
  //
  // NAO MEDIDO, e e o que fecharia: existe HISTORY real que contenha "curves"
  // sem falar de esticamento? Precisa de um corpus de headers reais, que o
  // projeto ainda nao tem (n=3). Ate la fica SUPOSTO com o risco escrito -- que
  // e exatamente para o que a procedencia serve.
  [/\bcurves?\b/i,            'Curves'],
  // SUPOSTO para `modasinh` (asinh modificado, do Siril).
  //
  // E a alternativa `|autostretch` daqui e CODIGO MORTO, por construcao: a regra
  // 1 casa a mesma palavra e poe o mesmo rotulo, e o laco pula uma regra cujo
  // rotulo ja esta em `historyHits`. Esta linha so e alcancada quando a regra 1
  // NAO casou -- ou seja, quando `autostretch` nao esta no texto. Fica anotado
  // em vez de removido: remover e mudanca de comportamento zero, e mexer numa
  // tabela sem procedencia enquanto ela esta sendo medida e trocar a ordem das
  // coisas.
  [/modasinh|autostretch/i,   'Autostretch']
];


/* OS DOIS LIMIARES DA REGRA LINEAR, COM NOME.
 *
 * Estavam embutidos na expressao, e o log precisava do segundo para dizer ao
 * leitor CONTRA O QUE a mediana foi comparada quando a regra decide contra o
 * header. Um numero que o log cita tem que ter um lugar so.
 *
 * Os dois sao limiares ABSOLUTOS sobre dado linear, e por isso dependem da
 * escala -- ver a nota de `scaleSource` em fits/normalise.js e a
 * investigacao-regra-linear.md. O segundo nunca foi exercitado dos dois lados
 * ate o `fixture-declaraestica` entrar.
 */
var NONLINEAR_MEDIAN = 0.05;
var NONLINEAR_MEDIAN_WITH_HISTORY = 0.02;
var PREVIEW_EDGE = 1024;

// Everything open() decoded. Null until a file has been opened.
var SESSION = null;

/* ------------------------------------------------------------------ *
 * Message-safe copies
 *
 * A measurement carries a `percentile` closure over its histogram, which a
 * step needs and structured clone refuses. Stripping functions costs nothing
 * and keeps the two execution paths honest: the main-thread fallback hands the
 * object straight over and would have carried the closure across happily, so
 * without this the worker path and the file:// path would disagree about what
 * a record is.
 * ------------------------------------------------------------------ */

function plainValues(o){
  var out = {}, k;
  for (k in o) if (typeof o[k] !== 'function') out[k] = o[k];
  return out;
}

function plainMeasurement(m){
  if (!m) return null;
  var out = [];
  for (var i = 0; i < m.perChannel.length; i++) out.push(plainValues(m.perChannel[i]));
  return { perChannel: out };
}

function plainRecords(records){
  var out = [];
  for (var i = 0; i < records.length; i++){
    var r = records[i];
    out.push({
      id: r.id, name: r.name, applied: r.applied, skipReason: r.skipReason,
      params: r.params, notes: r.notes,
      // `samples` and `surface` are plain data — numbers, strings and nulls —
      // so they cross the worker boundary as they are. They are carried rather
      // than dropped because they are the audit trail: the point that was
      // rejected, and the sentence saying why, are the whole argument that this
      // step is not doing something silently.
      samples: r.samples || null,
      surface: r.surface || null,
      correction: r.correction || null,
      clamped: r.clamped || null,
      // Colour calibration's audit trail, same argument: the offsets, the
      // thresholds, how many pixels were selected and what the gains came out
      // at are the evidence that the colour was measured and not chosen.
      // Carried even when the step refused, because a refusal with its reason
      // is the part a reader most needs.
      neutralise: r.neutralise || null,
      // O esticamento ligado: os parametros unicos derivados da luminancia, e a
      // medicao de fidelidade de cor que e a razao de existir do Modulo 3.
      linked: r.linked || null,
      colourFidelity: r.colourFidelity || null,
      // Saturacao seletiva: a mascara de SNR, a fidelidade de matiz e a tabela
      // por faixa de luminancia, que e a metrica do produto -- ela e o que
      // permite comparar a saida contra uma entrega manual sem olhar a imagem.
      mask: r.mask || null,
      // Recorte sugerido: o retangulo, os componentes e o que o recorte faria
      // com a cobertura do objeto. "suggested" e estado novo e nao e "applied".
      suggested: (r.suggested === undefined) ? null : r.suggested,
      reason: r.reason || null,
      frameSize: r.frameSize || null,
      outputSize: r.outputSize || null,
      skyMedian: (r.skyMedian === undefined) ? null : r.skyMedian,
      skyMadn: (r.skyMadn === undefined) ? null : r.skyMadn,
      signalPixels: (r.signalPixels === undefined) ? null : r.signalPixels,
      extendedPixels: (r.extendedPixels === undefined) ? null : r.extendedPixels,
      components: (r.components === undefined) ? null : r.components,
      componentsAboveMin: (r.componentsAboveMin === undefined) ? null : r.componentsAboveMin,
      componentList: r.componentList || null,
      rect: r.rect || null,
      objectRect: r.objectRect || null,
      coverageBefore: (r.coverageBefore === undefined) ? null : r.coverageBefore,
      coverageAfter: (r.coverageAfter === undefined) ? null : r.coverageAfter,
      coverageGuard: r.coverageGuard || null,
      hueFidelity: r.hueFidelity || null,
      chromaNoise: r.chromaNoise || null,
      saturationByLuminance: r.saturationByLuminance || null,
      overflow: r.overflow || null,
      stars: r.stars || null,
      gains: r.gains || null,
      reference: r.reference || null,
      before: plainMeasurement(r.before),
      after: plainMeasurement(r.after)
    });
  }
  return out;
}

// A run must not inherit the fields a previous run's step wrote onto the shared
// source measurement. The percentile closure is copied by reference on purpose:
// it reads a histogram that is finished and never changes.
// A record is found by its id, never by its position. `records[0]` was a real
// bug once: a step inserted ahead of another silently handed the wrong
// measurement downstream, and it only surfaced because the shapes happened to
// differ enough to crash. With a third step in the chain the positions move
// again, which is exactly when this has to already be by name.
function recordById(records, id){
  for (var i = 0; i < records.length; i++){
    if (records[i] && records[i].id === id) return records[i];
  }
  return null;
}

function copyMeasurement(m){
  var out = [];
  for (var i = 0; i < m.perChannel.length; i++){
    var s = m.perChannel[i], o = {}, k;
    for (k in s) o[k] = s[k];
    out.push(o);
  }
  return { perChannel: out };
}

/* ------------------------------------------------------------------ *
 * open — decode once, measure once, then render with the defaults
 * ------------------------------------------------------------------ */

async function openFile(buffer, fileName, opts, post){
  opts = opts || {};

  // `opts.now` is the only reading of the wall clock the log depends on. It is
  // a parameter so a reference capture can pin it: read inline, the log carried
  // the day it was produced and no golden could stay byte-exact past midnight.
  var now = opts.now ? new Date(opts.now) : new Date();

  var t0 = Date.now(), timings = {};
  function mark(name, from){ timings[name] = Date.now() - from; }
  function stage(label, pct){ post({ type: 'progress', stage: label, pct: pct }); }

  var step = Date.now();
  stage('Reading FITS header', 4);
  var hdu = findImageHDU(buffer);
  mark('header', step);

  await yieldNow();
  step = Date.now();
  var decodedInfo = null;
  var keep = function(info){ decodedInfo = info; };
  var dec;
  if (hdu.compressed){
    stage('Unpacking Rice tiles', 12);
    dec = decodeTileCompressed(buffer, hdu, keep, stage);
  } else {
    stage('Decoding pixel data', 12);
    dec = toNormalisedFloat(buffer, hdu, keep);
  }
  mark('decode', step);

  var w = dec.w, h = dec.h, planes = dec.planes;
  var m = hdu.map;

  // Row order --------------------------------------------------------
  var rowOrder = (typeof m.ROWORDER === 'string') ? m.ROWORDER.trim().toUpperCase() : null;
  var flipped = (rowOrder !== 'TOP-DOWN');   // absent means the FITS default, BOTTOM-UP
  if (flipped){
    await yieldNow();
    step = Date.now();
    stage('Correcting row order', 22);
    flipRows(dec.data, w, h, planes);
    mark('roworder', step);
  }

  // Colour filter array ----------------------------------------------
  var data = dec.data;
  var outChannels = 1, cfa = null, patternInfo = null, headerPattern = null;

  if (planes >= 3){
    outChannels = 3;
  } else {
    await yieldNow();
    step = Date.now();
    stage('Testing for a Bayer mosaic', 32);

    var stackedBefore = hdu.history.some(function(l){
      return /debayer|demosaic|stack|drizzle|registration|register/i.test(l);
    });

    var bp = (typeof m.BAYERPAT === 'string') ? m.BAYERPAT.trim().toUpperCase() : null;
    headerPattern = (bp && PATTERNS.indexOf(bp) >= 0) ? bp : null;

    cfa = detectCFA(data, w, h);
    cfa.stackedHistory = stackedBefore;
    cfa.headerDeclared = !!headerPattern;
    cfa.trustedHeader = false;

    // BAYERPAT is the strong evidence and is not overruled by statistics. The
    // lattice tests exist to catch a mosaic whose keyword was stripped, and to
    // settle which diagonal the greens sit on once row order has been applied.
    // A real 10-second sub-frame carries only a couple of percent of lattice
    // contrast beneath a per-pixel noise floor several times larger, so the
    // neighbour-ratio test cannot see it — vetoing the header on that basis
    // renders colour frames as grey mosaics.
    if (headerPattern && cfa.evenDims && !stackedBefore){
      cfa.isMosaic = true;
      cfa.trustedHeader = true;
    }
    mark('cfa', step);

    if (cfa.isMosaic){
      patternInfo = resolvePattern(headerPattern, cfa, (m.XBAYROFF | 0), (m.YBAYROFF | 0));

      await yieldNow();
      step = Date.now();
      stage('Debayering', 42);
      data = debayer(data, w, h, patternInfo.pattern);
      outChannels = 3;
      mark('debayer', step);
    }
  }

  var N = w * h;

  // The linear frame, as read. Immutable from here: every run clones it.
  //
  // When no debayer ran, `data` IS `dec.data` — the buffer the FITS export
  // hands back. That aliasing is why nothing downstream is allowed to write
  // through `source`, and why export copies instead of transferring.
  var source = new Image(data, w, h, outChannels);

  await yieldNow();
  step = Date.now();
  stage('Building preview', 50);
  var preview = downscaleFloat(source, PREVIEW_EDGE);
  mark('preview', step);

  // Statistics --------------------------------------------------------
  await yieldNow();
  step = Date.now();
  stage('Measuring median and MAD', 56);
  var statStride = Math.max(1, Math.ceil(N / 8000000));
  var sourceStats = measure(source, statStride);
  mark('stats', step);

  // Linearity — an orchestration decision, so it is decided here and handed
  // to the step as a parameter rather than sniffed inside it.
  var channels = sourceStats.perChannel;
  var globalMedian = 0, c;
  for (c = 0; c < channels.length; c++) globalMedian += channels[c].median;
  globalMedian /= channels.length;

  var historyHits = [];
  for (var hi = 0; hi < STRETCH_HISTORY.length; hi++){
    var rule = STRETCH_HISTORY[hi];
    if (historyHits.indexOf(rule[1]) >= 0) continue;
    for (var li = 0; li < hdu.history.length; li++){
      if (rule[0].test(hdu.history[li])){ historyHits.push(rule[1]); break; }
    }
  }
  var nonLinear = (globalMedian >= NONLINEAR_MEDIAN) ||
                  (historyHits.length > 0 && globalMedian >= NONLINEAR_MEDIAN_WITH_HISTORY);

  // A tile-compressed file can be handed back as a plain FITS. What goes out is
  // the linear, pre-stretch, pre-debayer data — the thing the .fz actually
  // holds — so Siril receives the file it would have had if the frame had never
  // been packed. Any row flip is undone at write time.
  var fitsMeta = null;
  if (hdu.compressed){
    fitsMeta = {
      cards: hdu.cards,
      bitpix: decodedInfo.bitpix, bzero: decodedInfo.bzero, bscale: decodedInfo.bscale,
      width: w, height: h, planes: planes,
      flipApplied: flipped,
      scaleLo: decodedInfo.scaleLo, scaleDiv: decodedInfo.scaleDiv,
      cmptype: (decodedInfo.compression && decodedInfo.compression.type) || 'tile'
    };
  }

  // One flat bag for the whole chain, so the host has one object to edit and
  // one object to send back. The background knobs carry a bg prefix here and
  // lose it on the way into the step: `tolerance` and `target` are meaningful
  // names inside a step and ambiguous the moment two steps share a namespace.
  var defaults = {
    shadowSigma: -2.80,
    // 0.085, nao 0.25.
    //
    // O 0.25 vem do autostretch do Siril e do STF do PixInsight e e um
    // esticamento DE INSPECAO: serve para olhar dado linear numa tela. 0,25 x
    // 255 = 64, e fundo em 64 e cinza claro -- a imagem sai lavada.
    //
    // A metrica de entrega registrada neste projeto e fundo entre 13 e 25 de
    // 255, o que sao alvos entre 0,051 e 0,098. Medido nos fixtures lineares,
    // este alvo poe o fundo em 22 de 255 contra 64 antes.
    //
    // Nao toca o ramo nao-linear, que segura o alvo na mediana do proprio
    // quadro e ignora este numero: o fixture-nonlinear sai em 63 nos dois.
    target: 0.085,
    blackPct: 0.0005,
    nonLinear: nonLinear,
    bgSamplesPerRow: 12,
    bgBoxSize: 25,
    bgTolerance: 1.0,
    bgEdgeMargin: 0.02,
    bgSmoothing: 0.10,
    bgCorrection: 'subtract',
    bgPedestal: 'model-median',
    // Stretch. `linked` is what stops the curve eating the colour. `operator`
    // stays 'mtf' in this delivery — asinh is implemented and verified beside
    // it, waiting for a real frame to compare against before it could become a
    // default. `stretch` null means "derive it from the data".
    linked: true,
    operator: 'mtf',
    stretch: null,
    // Colour calibration, ON, and it is on in the same delivery as the linked
    // stretch because neither works without the other. Calibrate and then
    // stretch each channel by its own curve and the calibration is undone;
    // stretch linked without calibrating and the cast that is there gets locked
    // in. Only the pair changes the image - modulo-2-3-spec.md, first paragraph.
    colourCal: true,
    ccNeutralise: true,
    ccStarSigma: 12.0,
    ccStarMax: 0.85,
    ccMinStarPixels: 2000,
    // Extended-source rejection. 25 px is the same window the background sampler
    // uses for its boxes, and 0.50 was stable between 0.25 and 0.60 on real data
    // - a plateau that wide means a real population is being separated, not an
    // artefact of where the threshold happens to sit.
    ccExtendedWindow: 25,
    ccExtendedFrac: 0.50,
    ccReference: 'green',
    // Saturacao seletiva. LIGADA a partir da v1.3.0, e a etapa so chegou aqui
    // depois dos nove passos da secao 6 do Modulo 4 -- em particular do nono,
    // que e a segunda implementacao. Ate ele fechar a etapa estava verificada
    // contra si mesma (goldens, controles negativos, teoremas) e nao contra
    // codigo que nao e este; ligar antes teria rebaixado o padrao que as outras
    // tres etapas da cadeia ja cumpriam.
    //
    // O que a autoriza, em ordem de peso:
    //   - matiz contra os cards do fixture: nucleo 0,0832 e nebulosa 0,9929,
    //     identicos antes e depois da etapa. Verdade EXTERNA, que nao saiu de
    //     nenhuma das duas implementacoes.
    //   - 426 comparacoes contra reference_m23.py, 0 FAIL.
    //   - a salvaguarda de ruido de croma com controle permanente que a ve
    //     recusar (compare-safeguards), e nao so prometer.
    //
    // amount 1.45 saiu da medicao da secao 1 contra uma entrega manual, nao de
    // escolha: se ele mudar, a medicao que o justifica muda junto. E o log diz
    // em voz alta que esta e a unica etapa da cadeia que e preferencia e nao
    // medicao -- as restricoes medidas impedem a preferencia de mentir, nao a
    // convertem em medicao.
    saturation: true,
    satAmount: 1.45,
    satSnrLow: 3.0,
    satSnrHigh: 25.0,
    satHighlightKnee: 0.80,
    satHighlightFloor: 0.35,
    // Recorte SUGERIDO. Os parametros sao os da secao 3.1 do Modulo 5a; a
    // janela e a fracao de densidade sao as MESMAS do filtro de extenso do
    // Modulo 2, e isso nao e coincidencia -- e a mesma medicao, lida ao
    // contrario. Ligado por padrao porque sugerir nao aplica nada: a etapa mede,
    // escreve o retangulo no record, e so o clique no segundo botao recorta.
    crop: true,
    cropSigma: 2.5,
    cropWindow: 25,
    cropDensity: 0.50,
    // Fracao do LADO MAIOR DA CAIXA DO OBJETO, nao do quadro -- ver a varredura
    // em steps/crop.js. 0,05 e o maior valor que mantem o ganho de cobertura
    // acima de 2x no fixture que sugere.
    cropMargin: 0.05,
    cropMinFrame: 0.20,
    // Aplicar o recorte. FALSO, e so um clique muda isso. Enquadramento e
    // autoria: a cadeia sugere e nunca decide.
    cropApply: false,
    // O parametro cropMaxCoverage saiu: a salvaguarda dele e vazia por
    // construcao da cadeia -- ver o comentario em steps/crop.js -- e um
    // parametro que nao governa nada e uma salvaguarda aparente. O record
    // explica no lugar dele, com o numero medido.
    dither: true
  };

  SESSION = {
    fileName: fileName,
    now: now,
    // Pinned the same way `now` is, and for the same reason: the build stamp
    // moves with every source change, so a golden that carried the real one
    // would differ on every commit and nobody would read the diff.
    buildStamp: opts.buildStamp || null,
    hdu: hdu, map: m,
    decData: dec.data,
    decodedInfo: decodedInfo,
    rowOrder: rowOrder, flipped: flipped,
    cfa: cfa, patternInfo: patternInfo, headerPattern: headerPattern,
    planes: planes, outChannels: outChannels,
    source: source, preview: preview,
    sourceStats: sourceStats, statStride: statStride,
    globalMedian: globalMedian, historyHits: historyHits,
    defaults: defaults,
    fitsMeta: fitsMeta,
    openTimings: timings, openMs: Date.now() - t0,
    autoRunDone: false
  };

  post({
    type: 'opened',
    fileName: fileName,
    width: w, height: h, channels: outChannels,
    // The preview buffer stays here — it is float, and nothing on the host can
    // draw float. What the host gets is its shape, so it can size a control.
    preview: { w: preview.w, h: preview.h, factor: Math.ceil(Math.max(w, h) / PREVIEW_EDGE) },
    header: headerSummary(hdu, m),
    cfa: cfaSummary(cfa, planes),
    records: [],                 // step records; nothing has run yet
    defaults: defaults,
    canExportFits: !!fitsMeta
  });

  // Dropping a file still produces an image and a log without the host asking
  // for anything. The protocol got a shape; the behaviour did not change.
  await runChain(defaults, 'full', post);
}

/* ------------------------------------------------------------------ *
 * run — the chain, on a clone, at preview or full resolution
 * ------------------------------------------------------------------ */

async function runChain(params, mode, post){
  if (!SESSION) throw FitsError('unknown', 'run before open');
  mode = (mode === 'preview') ? 'preview' : 'full';
  params = params || SESSION.defaults;

  var runStart = Date.now();
  var timings = {}, k;
  for (k in SESSION.openTimings) timings[k] = SESSION.openTimings[k];
  function mark(name, from){ timings[name] = Date.now() - from; }
  function stage(label, pct){ post({ type: 'progress', stage: label, pct: pct }); }

  var full = (mode === 'full');
  var base = full ? SESSION.source : SESSION.preview;

  await yieldNow();
  var step = Date.now();

  var work = base.clone();
  // Full mode reuses the measurement open() already took of these exact pixels.
  // Preview is a different frame and has to be measured on its own — reusing
  // the full-frame numbers would stretch the preview by parameters derived
  // from an image it is not.
  var measured = full ? SESSION.sourceStats : measure(work, 1);

  var records = [];
  function report(record){ records.push(record); }

  // The measurement is copied rather than shared: stepStretchMTF writes
  // shadows, midtones, target and scale onto the channels of its own `before`,
  // and the background record would otherwise carry stretch parameters inside a
  // measurement taken before the stretch existed.
  stage('Sampling the background', 60);
  work = stepBackground(work, {
    samplesPerRow: params.bgSamplesPerRow,
    boxSize: params.bgBoxSize,
    tolerance: params.bgTolerance,
    edgeMargin: params.bgEdgeMargin,
    smoothing: params.bgSmoothing,
    correction: params.bgCorrection,
    pedestal: params.bgPedestal,
    // Which buffer this is, expressed as a fraction of the frame the user is
    // working on. The step scales its sample box by it. Full runs are 1 by
    // definition; the preview is whatever downscaleFloat produced.
    scale: full ? 1 : (work.w / SESSION.source.w),
    stride: full ? SESSION.statStride : 1,
    before: copyMeasurement(measured)
  }, report);
  mark('background', step);

  await yieldNow();
  step = Date.now();
  stage('Applying autostretch', 68);

  // THE STRETCH MUST MEASURE THE FRAME IT IS ABOUT TO TRANSFORM, not the frame
  // that arrived. Background extraction removes the gradient, and the gradient
  // was part of the spread the MADN measured: reusing the earlier measurement
  // sets the black point at `median - 2.8 x MADN` on a MADN inflated by
  // variation that is no longer there, and the stretch comes out weaker than it
  // should be, everywhere, quietly.
  //
  // This was harmless while the background step only sampled — the two
  // measurements described the same pixels — and became wrong the moment a
  // pixel moved. The background step already measured the corrected frame as
  // its own `after`, so the right number is free; what is not free is
  // remembering to use it.
  var bgRecord = recordById(records, 'background');
  var lastMeasured = bgRecord.after ? bgRecord.after : measured;

  // Colour calibration ------------------------------------------------
  //
  // Between the background and the stretch, and in that order for a reason the
  // spec states and the arithmetic enforces: neutralisation is additive, gains
  // are multiplicative, and the background step is what makes a per-channel
  // median mean anything (a gradient biases it, and the neutralisation would be
  // measuring the slope instead of the cast).
  if (params.colourCal){
    await yieldNow();
    step = Date.now();
    stage('Measuring colour from the stars', 64);
    work = stepColourCal(work, {
      backgroundNeutralise: params.ccNeutralise,
      starSigma: params.ccStarSigma,
      starMax: params.ccStarMax,
      minStarPixels: params.ccMinStarPixels,
      extendedWindow: params.ccExtendedWindow,
      extendedFrac: params.ccExtendedFrac,
      reference: params.ccReference,
      stride: full ? SESSION.statStride : 1,
      before: copyMeasurement(lastMeasured)
    }, report);
    mark('colour', step);

    var ccRecord = recordById(records, 'colour-cal');
    if (ccRecord && ccRecord.after) lastMeasured = ccRecord.after;
  }

  var stretchBefore = copyMeasurement(lastMeasured);

  work = stepStretch(work, {
    linked: params.linked,
    operator: params.operator,
    stretch: params.stretch,
    shadowSigma: params.shadowSigma,
    target: params.target,
    blackPct: params.blackPct,
    nonLinear: params.nonLinear,
    stride: full ? SESSION.statStride : 1,
    before: stretchBefore
  }, report);
  mark('transfer', step);

  // Selective saturation ----------------------------------------------
  //
  // AFTER the stretch, because it works on display-referred values: the
  // highlight knee at 0.80 and the roll-off toward Y = 1 only mean anything
  // once the frame is where it will be shown.
  //
  // OFF BY DEFAULT, and for the reason Module 2 already paid for once. The
  // catalogue entry for `saturation` announces, so a step reporting applied
  // would drop the word from the "Not applied" sentence — and until the log has
  // a block describing what it did (step 7), that is an operation the log stops
  // denying without describing. Section 7 of Module 0 forbids exactly that, and
  // arriving at it by omission is still arriving at it.
  if (params.saturation){
    await yieldNow();
    step = Date.now();
    stage('Scaling chroma', 78);
    work = stepSaturation(work, {
      amount: params.satAmount,
      snrLow: params.satSnrLow,
      snrHigh: params.satSnrHigh,
      highlightKnee: params.satHighlightKnee,
      highlightFloor: params.satHighlightFloor,
      stride: full ? SESSION.statStride : 1
    }, report);
    mark('saturation', step);
  }

  /* Recorte sugerido ----------------------------------------------------
   *
   * DEPOIS do esticamento, porque a mascara de sinal e `Y > ceu + 2,5 sigma` e
   * isso so tem significado no quadro que a pessoa vai ver -- num quadro linear
   * o objeto inteiro mora nos primeiros centesimos do eixo.
   *
   * E ULTIMO, que hoje e a mesma coisa que dizer que nada depende dele: ele so
   * reenquadra o que ja esta pronto.
   *
   * `work` so e reatribuido quando `cropApply` vem de um clique. Sem ele a etapa
   * nao toca em pixel nenhum: mede, escreve o retangulo no record, e devolve o
   * mesmo quadro.
   */
  if (full && params.crop){
    await yieldNow();
    step = Date.now();
    stage('Looking for the object', 85);
    work = stepCrop(work, {
      sigma: params.cropSigma,
      window: params.cropWindow,
      density: params.cropDensity,
      margin: params.cropMargin,
      minFrame: params.cropMinFrame,
      // So chega true vindo de um clique. A cadeia nunca liga sozinha.
      apply: !!params.cropApply,
      stride: SESSION.statStride
    }, report);
    mark('crop', step);
  }

  // Quantise ----------------------------------------------------------
  await yieldNow();
  step = Date.now();
  var rgba = quantise(work, { dither: params.dither }, report);
  mark('quantise', step);

  // Display copy ------------------------------------------------------
  await yieldNow();
  step = Date.now();
  stage('Rendering', 88);
  var view = downscale(rgba, work.w, work.h);
  mark('downscale', step);

  // By id, not by position. The log and the diagnostics print the numbers the
  // autostretch derived — shadows, midtones, the clip counts — and those live
  // on the channels of the stretch step's own `before`. Reading records[0]
  // worked only while the stretch was the whole chain, and would have silently
  // started reporting another step's measurement the moment one landed in
  // front of it.
  // Either operator, by id. The asinh path reports 'stretch-asinh', and looking
  // for one name would have made switching operator produce a log about a run
  // that did not happen -- or no log at all.
  var stretchRecord = recordById(records, 'stretch-mtf') || recordById(records, 'stretch-asinh');
  if (!stretchRecord) throw FitsError('unknown', 'the chain produced no stretch record');

  var channels = stretchRecord.before.perChannel;
  var log = null, diag = null, headerText = null;

  if (full){
    var ctx = {
      fileName: SESSION.fileName,
      date: SESSION.now.toISOString().slice(0, 10),
      decoded: SESSION.decodedInfo,
      rowOrder: SESSION.rowOrder,
      cfa: SESSION.cfa,
      headerPattern: SESSION.headerPattern,
      pattern: SESSION.patternInfo || { pattern: null, source: null, corrected: false, notes: [] },
      outChannels: SESSION.outChannels,
      channels: channels,
      records: records,
      exportScaled: false, exportW: work.w, exportH: work.h,
      stretch: {
        nonLinear: params.nonLinear, globalMedian: SESSION.globalMedian,
        historyHits: SESSION.historyHits,
        shadowSigma: params.shadowSigma, target: params.target,
        blackPercentile: params.blackPct,
        // The two the log needs to describe a linked run, taken from the record
        // rather than from `params`: what ran is what the record says ran, and
        // a mono frame gets the per-channel path whatever `linked` was asked
        // for.
        linked: stretchRecord.linked || null,
        colourFidelity: stretchRecord.colourFidelity || null,
        operator: stretchRecord.params.operator || 'mtf'
      }
    };
    log = buildLog(ctx);

    /* O BLOCO DE HEADER, montado aqui junto do log porque as duas saidas de
     * texto saem da mesma rodada e nenhuma delas toca em pixel.
     *
     * Ele NAO depende dos parametros da rodada -- so do arquivo -- mas montar
     * num lugar so evita a pergunta "qual dos dois esta atualizado". */
    headerText = buildHeaderSummary({
      map: SESSION.map,
      cards: SESSION.hdu.cards,
      decoded: SESSION.decodedInfo,
      median: SESSION.globalMedian,
      build: SESSION.buildStamp
    });

    timings.total = (SESSION.autoRunDone ? 0 : SESSION.openMs) + (Date.now() - runStart);
    diag = buildDiag(channels, view, timings, params, {
      linked: stretchRecord.linked || null,
      operator: stretchRecord.params.operator || null,
      colourFidelity: stretchRecord.colourFidelity || null
    });
  }
  SESSION.autoRunDone = true;

  var transfer = (view.factor === 1) ? [view.data.buffer] : [view.data.buffer, rgba.buffer];

  post({
    type: 'rendered',
    mode: mode,
    width: work.w, height: work.h,
    view: { w: view.w, h: view.h, factor: view.factor },
    viewData: view.data.buffer,
    rgba: (view.factor === 1) ? null : rgba.buffer,
    log: log,
    headerSummary: headerText,
    // Preview measures a smaller frame, so its numbers describe that frame and
    // not the one the log is about. Handing back a diagnostics panel built from
    // them would invite reading preview statistics as frame statistics.
    diag: diag,
    records: plainRecords(records)
  }, transfer);
}

/* ------------------------------------------------------------------ *
 * export — the linear frame, back out as a plain FITS
 * ------------------------------------------------------------------ */

function exportFits(kind, post){
  if (!SESSION) throw FitsError('unknown', 'export before open');
  if (kind && kind !== 'fits') throw FitsError('unknown', 'unknown export kind: ' + kind);
  if (!SESSION.fitsMeta){
    throw FitsError('unknown', 'this file did not arrive compressed, so there is nothing to unpack');
  }

  // A copy, never a transfer. When no debayer ran, `source.data` and `decData`
  // are the same buffer, and transferring it would detach the frame every
  // later run depends on.
  var copy = allocFrom(Float32Array, SESSION.decData, 'the FITS export buffer');
  post({ type: 'exported', kind: 'fits', fitsMeta: SESSION.fitsMeta, fitsData: copy.buffer },
       [copy.buffer]);
}

/* ------------------------------------------------------------------ *
 * Diagnostics
 * ------------------------------------------------------------------ */

function headerSummary(hdu, m){
  return {
    BITPIX: m.BITPIX, NAXIS: m.NAXIS, NAXIS1: m.NAXIS1, NAXIS2: m.NAXIS2, NAXIS3: m.NAXIS3,
    BZERO: m.BZERO, BSCALE: m.BSCALE, ROWORDER: m.ROWORDER, BAYERPAT: m.BAYERPAT,
    XBAYROFF: m.XBAYROFF, YBAYROFF: m.YBAYROFF, PROGRAM: m.PROGRAM, INSTRUME: m.INSTRUME,
    CREATOR: m.CREATOR, TELESCOP: m.TELESCOP,
    OBJECT: m.OBJECT, STACKCNT: m.STACKCNT, EXPTIME: m.EXPTIME,
    compressedHDU: !!hdu.compressed,
    ZCMPTYPE: m.ZCMPTYPE, ZQUANTIZ: m.ZQUANTIZ, ZDITHER0: m.ZDITHER0,
    ZBITPIX: m.ZBITPIX, ZTILE: hdu.compressed ? [m.ZTILE1, m.ZTILE2, m.ZTILE3] : undefined,
    tableNAXIS1: hdu.table ? hdu.table.NAXIS1 : undefined,
    tableNAXIS2: hdu.table ? hdu.table.NAXIS2 : undefined,
    tablePCOUNT: hdu.table ? hdu.table.PCOUNT : undefined
  };
}

function cfaSummary(cfa, planes){
  if (!cfa) return 'skipped — file already has ' + planes + ' planes';
  return {
    evenDims: cfa.evenDims, isMosaic: cfa.isMosaic,
    headerDeclared: cfa.headerDeclared, trustedHeader: cfa.trustedHeader,
    decidedBy: cfa.trustedHeader ? 'BAYERPAT keyword (statistics used only for the green axis)'
                                 : 'lattice statistics (no usable BAYERPAT)',
    ratioH: cfa.ratioH, ratioV: cfa.ratioV, threshold: 1.15,
    latticeMedians: { r0c0: cfa.lattice[0], r0c1: cfa.lattice[1], r1c0: cfa.lattice[2], r1c1: cfa.lattice[3] },
    latticeContrast: cfa.contrast, greenAxis: cfa.greenAxis,
    stackedHistory: cfa.stackedHistory
  };
}

function buildDiag(channels, view, timings, params, STRETCH_DIAG){
  var S = SESSION;
  return {
    file: S.fileName,
    hduIndex: S.hdu.index,
    dataStart: S.hdu.dataStart,
    header: headerSummary(S.hdu, S.map),
    decoded: S.decodedInfo,
    rowOrder: { keyword: S.rowOrder, flipApplied: S.flipped },
    cfa: cfaSummary(S.cfa, S.planes),
    pattern: S.patternInfo || 'no debayer',
    linearity: {
      globalMedian: S.globalMedian, historyHits: S.historyHits,
      rule: 'nonLinear = median >= ' + NONLINEAR_MEDIAN + ' OR (history stretch AND median >= ' + NONLINEAR_MEDIAN_WITH_HISTORY + ')',
      verdict: params.nonLinear ? 'NON-LINEAR — reduced stretch' : 'LINEAR — full autostretch'
    },
    channels: channels.map(function(s, idx){
      return {
        channel: S.outChannels === 1 ? 'L' : ['R', 'G', 'B'][idx],
        median: s.median, madn: s.madn, q1: s.q1, q3: s.q3,
        shadows: s.shadows, midtones: s.midtones, target: s.target,
        pixelsBlack: s.outLow, pixelsWhite: s.outHigh,
        totalPixels: s.totalPixels, statSamples: s.sampled, statStride: s.stride, nonFinite: s.nan
      };
    }),
    // What kind of stretch ran, and — when it was linked — the single curve and
    // the colour-fidelity measurement. Present rather than inferable: a reader
    // of the diagnostics should not have to notice that three channels happen to
    // carry identical `shadows` to work out that the run was linked.
    stretchMode: {
      linked: !!STRETCH_DIAG.linked,
      operator: STRETCH_DIAG.operator,
      luminance: STRETCH_DIAG.linked || null,
      colourFidelity: STRETCH_DIAG.colourFidelity || null
    },
    view: { width: view.w, height: view.h, downscaleFactor: view.factor },
    timingsMs: timings,
    historyCards: S.hdu.history,
    allCards: S.hdu.cards
  };
}

/* ------------------------------------------------------------------ *
 * Message protocol — identical in worker and main-thread fallback
 * ------------------------------------------------------------------ */

self.onmessage = function(ev){
  var msg = ev.data || {};

  function post(payload, transfer){ self.postMessage(payload, transfer || []); }
  function fail(e){
    // An unlabelled RangeError is NOT a memory limit. This used to say the
    // opposite, and the reasoning it gave — "the header is validated before
    // anything large is requested, so by the time a RangeError can happen the
    // size is one the file genuinely declares" — was false. Two files proved
    // it: a negative PCOUNT walked past the size check and a ZTILE of
    // 100000 x 100000 asked for a 40 GB tile buffer, and both came out as
    // "this frame is too large for the browser to hold" about files of five
    // and fourteen kilobytes. Both are now rejected as `badheader` upstream.
    //
    // The direction that is actually provable runs the other way. Every
    // allocation this chain makes that scales with the file goes through
    // `alloc`/`allocFrom`, which label failure as `memory` themselves and name
    // the buffer. What remains unlabelled is a typed-array *view* over the file
    // buffer, and one of those throws when an offset or length does not fit —
    // which is a bounds error, not a browser limit. So it maps to `unknown`,
    // whose text asks for a report, and that is the correct request: reaching
    // here means a validation gap upstream, and the gap is worth hearing about.
    var kind = (e && e.kind) || 'unknown';
    post({ type: 'error', kind: kind, message: String((e && e.message) || e) });
  }

  try {
    if (msg.cmd === 'open'){
      openFile(msg.buffer, msg.fileName, msg.opts, post).catch(fail);
    } else if (msg.cmd === 'run'){
      runChain(msg.params, msg.mode, post).catch(fail);
    } else if (msg.cmd === 'export'){
      exportFits(msg.kind, post);
    } else {
      throw FitsError('unknown', 'unknown command: ' + msg.cmd);
    }
  } catch (e){
    fail(e);
  }
};

// Handshake: the host waits for this before handing over the file buffer, so a
// worker that cannot start never costs us the (already transferred) data.
self.postMessage({ type: 'ready' });
