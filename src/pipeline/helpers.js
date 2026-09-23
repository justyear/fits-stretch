'use strict';

/* ------------------------------------------------------------------ *
 * Small helpers
 * ------------------------------------------------------------------ */

function yieldNow(){ return new Promise(function(r){ setTimeout(r, 0); }); }

function FitsError(kind, message){
  var e = new Error(message);
  e.kind = kind;
  return e;
}

/* ------------------------------------------------------------------ *
 * Allocation
 *
 * Every large typed array in the chain goes through here, so that running out
 * of memory reaches the user as "not enough memory" and not as "something went
 * wrong — if it opens correctly in Siril, it is worth reporting".
 *
 * That distinction is the whole reason this exists. A big frame is not an
 * exceptional case for this audience: a 4K sensor is the ordinary one, and the
 * ordinary case must not produce a message that asks for a bug report about a
 * browser limit. The message says what to do instead.
 *
 * A RangeError *inside this function* can only mean allocation, because that is
 * all this function does: `new ctor(length)` with a plain length, never a view
 * over the file. That is why the label is safe to attach here and nowhere else.
 *
 * It used to say something broader and wrong — that the header is fully
 * validated before any of these run, so any RangeError anywhere was an
 * allocation. It was not. A negative PCOUNT and an oversized ZTILE both reached
 * a typed-array constructor with a bad length, and the resulting RangeError was
 * reported to the user as a memory limit about a file of a few kilobytes. Both
 * are rejected upstream now (`badheader`), and `fail` in run.js no longer
 * guesses `memory` from the error type. The invariant this comment may claim is
 * the narrow one: everything that scales with the file comes through here.
 *
 * `what` names the buffer, so the diagnostics say which allocation failed and
 * at what size rather than just that one did.
 * ------------------------------------------------------------------ */
function alloc(ctor, length, what){
  try {
    return new ctor(length);
  } catch (e){
    throw FitsError('memory',
      'could not allocate ' + what + ' (' + length + ' values, ' +
      Math.round(length * ctor.BYTES_PER_ELEMENT / 1048576) + ' MB): ' +
      String((e && e.message) || e));
  }
}

// The copy-constructor form, for cloning an existing buffer.
function allocFrom(ctor, source, what){
  try {
    return new ctor(source);
  } catch (e){
    throw FitsError('memory',
      'could not copy ' + what + ' (' + (source && source.length) + ' values, ' +
      Math.round((source && source.length || 0) * ctor.BYTES_PER_ELEMENT / 1048576) + ' MB): ' +
      String((e && e.message) || e));
  }
}


/* SHA-256 dos bytes do arquivo, os 8 primeiros bytes em hexadecimal.
 *
 * Identifica o arquivo para quem o tem, e nao diz nada para quem nao tem. Ver
 * a nota longa em `openFile`, que e onde a decisao esta escrita.
 *
 * `null` quando o navegador nao oferece `crypto.subtle` -- contexto nao-seguro,
 * ou navegador velho. Quem chama tem que ter os dois lados escritos: uma
 * impressao digital ausente que saisse como string vazia viraria um campo em
 * branco no log, e campo em branco num log auditavel e pior que uma frase
 * dizendo que nao deu.
 */
async function fileDigestShort(buffer){
  try {
    var c = (typeof self !== 'undefined' && self.crypto) ? self.crypto : null;
    if (!c || !c.subtle || !c.subtle.digest) return null;
    var h = await c.subtle.digest('SHA-256', buffer);
    var b = new Uint8Array(h), s = '', i;
    for (i = 0; i < 8; i++){
      var d = b[i].toString(16);
      s += (d.length === 1 ? '0' : '') + d;
    }
    return s;
  } catch (e){
    return null;
  }
}
