/* ------------------------------------------------------------------ *
 * Registry — the catalogue of processing this log can speak about
 *
 * The "Not applied" line used to be a string literal, which made it a promise
 * nobody was keeping: the day background extraction lands, the sentence turns
 * into a false statement and nothing in the code notices. It is generated now,
 * as the complement between this catalogue and the steps that actually ran, so
 * adding a step to the chain retracts its denial automatically.
 *
 * That sentence is the trust mechanism of the product. Treat edits here as
 * edits to a public claim, not to a data structure.
 * ------------------------------------------------------------------ */

var CATALOGUE = [
  // The order below is the order the sentence reads. It is not alphabetical
  // and not pipeline order — it is the order the sentence has always had, and
  // people have already pasted it in public.
  { id: 'denoise',       label: 'noise reduction' },
  { id: 'sharpen',       label: 'sharpening',                neverImplemented: true },
  /* SATURATION STAYS IN THE SENTENCE, AND SECTION 4 OF MODULE 4 IS WRONG ABOUT
   * THIS — measured, not argued.
   *
   * The spec asks for `announce: false`, on the argument that the log gives the
   * step a block of its own. That argument holds for the stretch and for the
   * colour calibration, and it does not hold here, because `announce: false`
   * removes the word in BOTH directions:
   *
   *   step ran and applied     no denial, block describes it        fine
   *   step ran and refused     no denial, block says why            fine
   *   STEP DID NOT RUN         NO DENIAL, NO BLOCK                  broken
   *
   * The third row is today's state and will be the state of any build where
   * saturation is off. The word would leave the promise without anything having
   * been done — the tool would quietly stop claiming it does not saturate, on a
   * frame it did not saturate.
   *
   * The stretch and the calibration never hit that row: they run on every
   * three-channel frame. Saturation is the first step that can simply be
   * absent, and the catalogue's default — announce — already produces the right
   * sentence in all three cases, because `notAppliedLabels` drops a label the
   * moment a record claims `applied`. Nothing needed inventing; the mechanism
   * from Module 0 already handles it.
   *
   * If saturation ever becomes unconditional, revisit — but the block carrying
   * "this is a preference rather than a measurement" is what would have to earn
   * the change, not the mere existence of a block.
   */
  { id: 'saturation',    label: 'saturation' },
  { id: 'deconv',        label: 'deconvolution',             neverImplemented: true },
  { id: 'star-split',    label: 'star removal' },          // MIS-PAIRED, see below
  { id: 'background',    label: 'background extraction' },
  // The debt below came due in Module 2. `colour-cal` no longer answers for the
  // word "grading": it has its own id with an honest label and does not
  // announce, because the log gives it a section with the measured numbers, and
  // `colour-grade` stays here as a separate entry that nothing retracts.
  //
  // The sentence therefore keeps saying "colour grading" after a frame has been
  // colour calibrated, which is the whole point: calibration is measurement,
  // grading is taste, and only one of them happened.
  { id: 'colour-grade',  label: 'colour grading',            neverImplemented: true },
  { id: 'ai',            label: 'any AI or generative step', neverImplemented: true },

  // Declared so a step can claim the id, but not enumerated in the sentence.
  // `announce: false` is the exception and has to be argued for one entry at a
  // time; leaving the field off means the reader gets told, which is the safe
  // default and the one the goldens catch.
  //
  // The stretch family: the log gives the stretch that ran a section of its
  // own, with the measured numbers. Denying the other one there would read as
  // a warning about something the reader can already see was handled.
  { id: 'stretch-mtf',   label: 'autostretch',               announce: false },
  { id: 'stretch-asinh', label: 'asinh stretch',             announce: false },

  // Colour calibration, with `announce: false` on the same argument as the
  // stretch family: the log dedicates a block to it, with the gains and the
  // pixel count, so a denial elsewhere in the sentence would be a warning about
  // something the reader can already see was handled and measured.
  { id: 'colour-cal',    label: 'colour calibration',        announce: false },

  // (`saturation` is NOT here — see the entry above and the note below.)

  // Not in the sentence today, and not implemented. Whoever writes the step
  // decides whether it announces — flipping this changes a sentence people
  // have already pasted, so it is a decision, not a detail.
  { id: 'multiscale',    label: 'multiscale enhancement',    announce: false }
];

/* ONE ENTRY IS STILL MIS-PAIRED AND HAS TO BE SPLIT BEFORE ITS STEP LANDS.
 *
 * The label names what the reader is worried about; the id names what we would
 * actually build. When those are not the same thing, the sentence comes out
 * wrong — and it comes out wrong in two opposite directions.
 *
 *   colour-cal -> "colour grading"   SPLIT, Module 2, done above
 *
 * Colour calibration is measurement — stellar flux ratios decide the gains.
 * Grading is taste. Wired together, calibrating retracted the promise about
 * grading, so the tool would have stopped claiming something that stayed true
 * the whole time. "We did not colour grade" is the sentence that separates this
 * tool from the manufacturer's app; giving it away for free, in exchange for
 * nothing, would have been the worst trade in the catalogue.
 *
 *   star-split -> "star removal"     (split in Module 4)
 *
 * Same fault, worse consequence, because this one misleads instead of merely
 * conceding. "Star removal" is what a neural network does. If the Module 4 step
 * is morphological opening and the log denies star removal, a technical reader
 * concludes the stars were never separated — when they were. The sentence would
 * be literally true and would still leave the reader with a false belief, which
 * is the one failure mode this whole line exists to prevent.
 *
 * The fix in both cases is two entries, not a reworded one: the step keeps its
 * id and gets an honest label of its own, and the thing being denied stays a
 * separate entry that nothing retracts. Both edits change the sentence on
 * purpose, so both require re-capturing the goldens.
 */

// The labels the log denies: everything the catalogue announces that no record
// claims. Order follows CATALOGUE.
function notAppliedLabels(records){
  var applied = {}, i;
  for (i = 0; i < records.length; i++){
    if (records[i] && records[i].applied) applied[records[i].id] = true;
  }

  var out = [];
  for (i = 0; i < CATALOGUE.length; i++){
    var entry = CATALOGUE[i];
    if (applied[entry.id]){
      // A step the catalogue declares as never implemented reporting that it
      // ran means the two disagree. Refuse to produce a log at all rather than
      // produce one that denies something that just happened.
      if (entry.neverImplemented){
        throw FitsError('unknown',
          'step "' + entry.id + '" reported as applied, but the catalogue declares it never implemented');
      }
      continue;
    }
    if (entry.announce === false) continue;
    out.push(entry.label);
  }
  return out;
}
