#include "cell.h"
#include "twin_ops.h"
using namespace twinleaf;
// L leg: direct transcription of the Lean model of OP_VERIFY,
// spec/core/Bitcoin/Interpreter/Defs.lean:901-904 (which cites
// interpreter.cpp:663-675):
//
//   else if w = 0x69 then                                   -- OP_VERIFY
//     if st.stack.length < 1 then .error .stackUnderflow
//     else if castToBool (topAt st.stack 1) then .ok { st with stack := st.stack.tail }
//     else .error .verifyFailed
//
// The bounded cast_to_bool and the TwinErr -> Core ordinal map come from
// build/twin_ops.h; the element length is fixed per exported function.

template <unsigned int LEN>
BINLINE uint32_t l_verify(uint32_t depth, const uint8_t* vch) {
  if (depth < 1)
    return (uint32_t)core_ord(TWIN_INVALID_STACK_OPERATION);
  if (!cast_to_bool(vch, LEN))                // castToBool (topAt stack 1)
    return (uint32_t)core_ord(TWIN_VERIFY);
  return 0;                                   // stack := stack.tail
}

extern "C" uint64_t cell_verify_len0(uint32_t depth) {
  const uint8_t vch[1] = {0};
  const uint32_t e = l_verify<0>(depth, vch);
  VSt st{depth};
  if (e == 0)
    st.depth = depth - 1;
  return verify_pack(e, st);
}

extern "C" uint64_t cell_verify_len1(uint32_t depth, uint8_t b0) {
  const uint8_t vch[1] = {b0};
  const uint32_t e = l_verify<1>(depth, vch);
  VSt st{depth};
  if (e == 0)
    st.depth = depth - 1;
  return verify_pack(e, st);
}

extern "C" uint64_t cell_verify_len2(uint32_t depth, uint8_t b0, uint8_t b1) {
  const uint8_t vch[2] = {b0, b1};
  const uint32_t e = l_verify<2>(depth, vch);
  VSt st{depth};
  if (e == 0)
    st.depth = depth - 1;
  return verify_pack(e, st);
}
