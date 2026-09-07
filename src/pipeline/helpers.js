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
 * A RangeError here can only mean allocation: the header is validated before
 * any of these run — `truncated` fires when the declared data exceeds the file,
 * `baddims` when a dimension is not positive — so by the time a buffer is
 * requested, the size asked for is a size the file really claims.
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

