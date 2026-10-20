#include "cell.h"
#include "twin_ops.h"
using namespace twinleaf;
// L leg: the twin's bounded `cast_to_bool` helper emitted verbatim by
// cells/_tools/mk_leaf.py into build/twin_ops.h.  That helper is the twin's
// bounded form of CastToBool (interpreter.cpp:46-59; Numeric/Interface.lean:
// 87-91) specialised to element length <= 2, the same domain as the C leaf.
// The tiny exported wrappers are cell harness.

extern "C" uint32_t cell_cast_empty() {
  const uint8_t vch[1] = {0};
  return cast_to_bool(vch, 0) ? 1u : 0u;
}

extern "C" uint32_t cell_cast_len1(uint8_t b0) {
  const uint8_t vch[1] = {b0};
  return cast_to_bool(vch, 1) ? 1u : 0u;
}

extern "C" uint32_t cell_cast_len2(uint8_t b0, uint8_t b1) {
  const uint8_t vch[2] = {b0, b1};
  return cast_to_bool(vch, 2) ? 1u : 0u;
}
