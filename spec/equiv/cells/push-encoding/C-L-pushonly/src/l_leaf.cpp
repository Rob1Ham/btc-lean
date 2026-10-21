#include "twin_ops.h"
#include "twin_extras.h"
#include "leaf_common.h"

using namespace twinleaf;

// L leg — the twin's classify_push_only (runtime.inc:297-306), with its
// `while (i < size)` unrolled for script size <= 2.  The step body is
// verbatim: decode_op (copied verbatim from runtime.inc:242-281 by
// _harness/extract_extras.py) and the `d.wire > 0x60` test.  The only reason
// for unrolling is that SAW cannot execute a loop whose trip count is a
// symbolic script size; the trip count here is at most 2 by construction.
//
// classify_push_only distinguishes ParseFail from NotPush; IsPushOnly returns
// false for both, and this cell's observable is the boolean, so both map to 0.
BINLINE uint32_t l_push_only(const uint8_t* b, uint32_t size) {
  uint32_t i = 0;
  Decoded d{};
  if (i < size) {
    if (!decode_op(b, size, i, d)) return 0;
    if (d.wire > 0x60) return 0;
    i = d.next;
    if (i < size) {
      if (!decode_op(b, size, i, d)) return 0;
      if (d.wire > 0x60) return 0;
    }
  }
  return 1;
}

extern "C" uint64_t cell_pushonly1(uint8_t w) {
  uint8_t b[8] = {}; b[0] = w;   // 8 bytes: branch-free reads stay in bounds
  return l_push_only(b, 1);
}

extern "C" uint64_t cell_pushonly2(uint8_t w0, uint8_t w1) {
  uint8_t b[8] = {}; b[0] = w0; b[1] = w1;
  return l_push_only(b, 2);
}
