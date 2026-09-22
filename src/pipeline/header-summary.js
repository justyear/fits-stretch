/* ------------------------------------------------------------------ *
 * header-summary.js — o bloco de texto que a pessoa copia e cola
 *
 * PARA QUE ISTO EXISTE. O catalogo de convencoes deste projeto
 * (`STRETCH_HISTORY`, a escada da escala) esta parado na mesma pergunta ha
 * rodadas: QUE FRACAO DOS ARQUIVOS DECLARA o que fez, e com que palavras. A
 * resposta nao esta em nenhuma medicao que se possa fazer aqui dentro -- ela
 * precisa de headers de arquivos que nao sao nossos.
 *
 * Pedir isso por escrito nao funcionou: quatro dias, cinco grupos, zero
 * respostas. O pedido dava trabalho a quem responde e nao dava nada em troca.
 * Entao a ferramenta passa a montar o bloco: ela ja leu o header inteiro, ja
 * mediu os tres numeros, e a pessoa so precisa apertar um botao e olhar.
 *
 * A PROMESSA DO PRODUTO, APLICADA AO PEDIDO DE AJUDA. O resto da pagina diz
 * "nada foi enviado, o arquivo nunca saiu desta maquina". Um botao que juntasse
 * dados para mandar para outra pessoa tem que ser a MESMA coisa: o texto vai
 * para a area de transferencia, ninguem o envia, e a pessoa le antes de colar.
 *
 * LISTA DE PERMISSAO, NAO DE PROIBICAO -- e esta e a decisao de desenho que
 * carrega o resto.
 *
 * A tentacao e listar o que nao pode sair: OBJECT, DATE-OBS, TELESCOP... Uma
 * lista de proibicao exige ANTECIPAR cada chave identificadora que existe ou
 * que vai existir, e antecipar e exatamente o que falha: `SWCREATE`, `SITELAT`,
 * `OBJCTRA`, `FOCUSER`, a chave privada que o proximo programa inventar. Errar
 * por omissao numa lista de proibicao VAZA; errar por omissao numa lista de
 * permissao so perde um dado.
 *
 * Entao: nada e lido do header a nao ser o que esta em HEADER_SUMMARY_KEYS. A
 * lista de proibicao existe (HEADER_SUMMARY_NEVER) e NAO e o mecanismo -- ela e
 * o que o teste afirma e o que a frase ao lado do botao promete. Duas leitoras,
 * uma lista: `test/compare-golden.ps1` le estas constantes DESTE arquivo em vez
 * de manter uma segunda copia que envelheceria.
 *
 * A EXCECAO, E ELA E CONSCIENTE: HISTORY e COMMENT saem INTEIROS, porque e
 * neles que esta a resposta que o catalogo procura -- e eles sao texto livre.
 * Um programa pode ter escrito um caminho, um nome de usuario ou o nome do alvo
 * ali dentro, e nenhuma lista de chaves alcanca isso. O que da para fazer, e o
 * que e feito: apontar as linhas suspeitas para onde o olho da pessoa vai
 * primeiro, sem apagar nada. Quem decide e quem le.
 * ------------------------------------------------------------------ */

/* Carimbo do build. Trocado por `build.ps1` pelo sha256 dos fontes + template,
 * cortado em 16 digitos. Gerado e nao escrito a mao: um numero de versao a mao
 * so esta certo enquanto alguem lembra de mexer nele, e uma medicao colada num
 * catalogo precisa dizer QUAL CODIGO a produziu.
 *
 * A captura de golden o fixa, como ja fixa a data -- senao todo golden deste
 * bloco mudaria a cada mexida em qualquer fonte, e um diff que muda sempre e um
 * diff que ninguem le. */
var BUILD_STAMP = '__BUILD_STAMP__';

/* AS CHAVES QUE O CATALOGO PRECISA.
 *
 * `NAXISn` sai do proprio NAXIS, e nao desta lista: um cubo de quatro eixos
 * existe, e uma lista fixa de 1 a 3 o truncaria em silencio. */
var HEADER_SUMMARY_KEYS = [
  'BITPIX', 'NAXIS',
  'BZERO', 'BSCALE',
  'DATAMIN', 'DATAMAX', 'BUNIT',
  'ROWORDER', 'BAYERPAT',
  'PROGRAM', 'CREATOR', 'PRODUCER'
];

/* O QUE NUNCA SAI. Nao e o mecanismo -- a lista de permissao acima e. Esta e a
 * afirmacao: o que o teste verifica e o que a frase ao lado do botao promete.
 *
 * Coordenadas entram aqui porque um par de coordenadas mais uma data identifica
 * uma sessao de observacao tao bem quanto um nome. */
var HEADER_SUMMARY_NEVER = [
  'OBJECT', 'DATE-OBS', 'DATE-END', 'TELESCOP', 'INSTRUME', 'OBSERVER',
  'RA', 'DEC', 'OBJCTRA', 'OBJCTDEC', 'CRVAL1', 'CRVAL2',
  'SITELAT', 'SITELONG', 'SITEELEV', 'LAT-OBS', 'LONG-OBS', 'ALT-OBS',
  'FILENAME', 'ORIGFILE'
];

/* Caminho, nome de usuario ou nome de arquivo dentro de texto livre.
 *
 * HEURISTICA, e declarada como tal: ela nunca apaga nem esconde nada, so
 * acrescenta um aviso com os numeros das linhas. Um falso positivo custa uma
 * linha lida a mais; um falso negativo custa o que a pessoa nao olhou. */
function looksLikePath(s){
  return /[A-Za-z]:[\\/]/.test(s) ||
         /\\\\[A-Za-z0-9_.-]+\\/.test(s) ||
         /\/(?:home|Users|mnt|media|srv)\//i.test(s) ||
         /(^|[\s"'([<])~\//.test(s) ||
         /[\w-]+\.(?:fits?|fts|fz|xisf|tiff?|cr2|nef|arw|dng|ser|avi|png|jpe?g)\b/i.test(s);
}

function hsNum(v){
  if (typeof v !== 'number' || !isFinite(v)) return String(v);
  if (v === Math.floor(v) && Math.abs(v) < 1e15) return String(v);
  var s = v.toPrecision(9);
  if (s.indexOf('e') < 0 && s.indexOf('.') >= 0) s = s.replace(/0+$/, '').replace(/\.$/, '');
  return s;
}

function hsValue(v){
  if (v === undefined || v === null) return '(absent)';
  if (typeof v === 'number') return hsNum(v);
  if (typeof v === 'boolean') return v ? 'T' : 'F';
  return "'" + String(v) + "'";
}

/* buildHeaderSummary(ctx) -> string
 *
 *   ctx.map        o mapa de chaves do header (chave -> valor)
 *   ctx.cards      os cartoes crus, em ordem de arquivo
 *   ctx.decoded    o resumo do decode: rawMin, rawMax, scaleDiv, scaleLo, ...
 *   ctx.median     a mediana global, no eixo [0,1]
 *   ctx.build      o carimbo do build (fixado na captura de golden)
 */
function buildHeaderSummary(ctx){
  var m = ctx.map || {}, d = ctx.decoded || {}, L = [];

  L.push('Stretch — FITS header summary');
  L.push('Built on your machine, for the open catalogue of what FITS writers');
  L.push('actually declare. Nothing was sent. Read it before you paste it.');
  L.push('');
  L.push('tool     Stretch, build ' + (ctx.build || BUILD_STAMP));
  L.push('');

  /* CHAVES AUSENTES SAO IMPRESSAS COMO AUSENTES, e isso nao e enchimento.
   *
   * A pergunta que trava a escala e "que fracao dos arquivos declara DATAMAX /
   * BUNIT". Um bloco que simplesmente omitisse as chaves que faltam
   * responderia "sim" em todos os arquivos que as tem e NADA nos outros --
   * ausencia e metade do dado, e a metade mais dificil de conseguir. */
  L.push('--- header keys (absent ones are shown as absent, on purpose) ---');
  var keys = [], i;
  for (i = 0; i < HEADER_SUMMARY_KEYS.length; i++){
    keys.push(HEADER_SUMMARY_KEYS[i]);
    if (HEADER_SUMMARY_KEYS[i] === 'NAXIS'){
      var n = (typeof m.NAXIS === 'number') ? m.NAXIS : 0;
      if (n > 0 && n < 10) for (var a = 1; a <= n; a++) keys.push('NAXIS' + a);
    }
  }
  var wide = 0;
  for (i = 0; i < keys.length; i++) if (keys[i].length > wide) wide = keys[i].length;
  for (i = 0; i < keys.length; i++){
    var k = keys[i], pad = k;
    while (pad.length < wide) pad += ' ';
    L.push(pad + ' = ' + hsValue(m[k]));
  }
  L.push('');

  /* OS TRES NUMEROS, NAS UNIDADES DO ARQUIVO.
   *
   * `rawMin`/`rawMax` ja sao valor fisico: valor*BSCALE+BZERO. A mediana e
   * medida no eixo [0,1] e volta para as unidades do arquivo pela mesma
   * transformacao linear que a levou para la -- `norm*div + lo`, exata.
   *
   * O QUE NAO ENTRA AQUI, DE PROPOSITO: como ESTA ferramenta decidiu a escala.
   * Isso e inferencia nossa, e e justamente a coisa que o catalogo existe para
   * julgar. Colar a nossa suposicao junto do dado bruto convidaria alguem a ler
   * uma pela outra. */
  var med = (typeof ctx.median === 'number' && isFinite(ctx.median) &&
             typeof d.scaleDiv === 'number' && typeof d.scaleLo === 'number')
          ? (ctx.median * d.scaleDiv + d.scaleLo) : null;
  L.push('--- data, in the file’s own units (after BZERO/BSCALE) ---');
  L.push('min      ' + hsNum(d.rawMin));
  L.push('max      ' + hsNum(d.rawMax));
  L.push('median   ' + (med === null ? '(not measured)' : hsNum(med)));
  L.push('         the median is the mean of the per-channel medians, taken');
  L.push('         after debayer and before any background model was removed.');
  if (d.nonFinite) L.push('         ' + d.nonFinite + ' non-finite sample(s) were left out of all three.');
  L.push('');

  // --- HISTORY e COMMENT, inteiros e em ordem de arquivo -------------
  var cards = ctx.cards || [], hist = [], com = [], suspeitas = [];
  for (i = 0; i < cards.length; i++){
    var raw = String(cards[i]);
    var key = raw.substring(0, 8).replace(/\s+$/, '');
    if (key !== 'HISTORY' && key !== 'COMMENT') continue;
    var text = raw.substring(8).replace(/\s+$/, '');
    var bucket = (key === 'HISTORY') ? hist : com;
    bucket.push(text);
    if (looksLikePath(text)) suspeitas.push(key + ' ' + (bucket.length));
  }

  if (suspeitas.length){
    L.push('!! ' + suspeitas.length + ' free-text line(s) below look like they carry a file path,');
    L.push('!! a user name or a file name: ' + suspeitas.join(', ') + '.');
    L.push('!! Nothing was removed. Read them, and delete what you would rather');
    L.push('!! not send. Every other line here comes from a fixed list of keys.');
    L.push('');
  }

  L.push('--- HISTORY (' + hist.length + ' line' + (hist.length === 1 ? '' : 's') + ', in file order) ---');
  for (i = 0; i < hist.length; i++) L.push('  ' + hist[i]);
  if (!hist.length) L.push('  (none)');
  L.push('');
  L.push('--- COMMENT (' + com.length + ' line' + (com.length === 1 ? '' : 's') + ', in file order) ---');
  for (i = 0; i < com.length; i++) L.push('  ' + com[i]);
  if (!com.length) L.push('  (none)');
  L.push('');

  L.push('--- what is deliberately not here ---');
  L.push('No ' + HEADER_SUMMARY_NEVER.slice(0, 6).join(', ') + ', no sky');
  L.push('coordinates, no site position, no file name and no path. This block is');
  L.push('assembled from the fixed list of keys printed above — anything else in');
  L.push('your header was never read into it. The two free-text sections are the');
  L.push('one exception, and they are copied as they are because they are what');
  L.push('the catalogue is asking about.');

  return L.join('\n');
}
