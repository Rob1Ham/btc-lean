#include "cell.h"
#include "twin_cast_to_bool.h"
// L leg: the twin's actual CastToBool helper, extracted verbatim from
// spec/equiv/twin/runtime.inc (lines 130-139 at this commit) by
// src/extract_twin.py.  The extractor pins the SHA-256 of the function text,
// so a change to the twin's loop fails the build instead of silently
// verifying a different helper.
//
// The wrapper is cell harness: it adds only the consensus domain assumption
// n <= 520 and converts the Boolean result to the shared 0/1 observable.

extern "C" uint32_t cell_cast_arb(const uint8_t* vch, uint32_t n) {
  __builtin_assume(n <= 520u);  // element domain, MAX_SCRIPT_ELEMENT_SIZE
  return twin::cast_to_bool(vch, n) ? 1u : 0u;
}
