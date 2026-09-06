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

