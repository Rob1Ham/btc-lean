#include "cell.h"
// C leg: source-excerpt slice of Bitcoin Core cce32b168
// src/script/interpreter.cpp:663-675 (case OP_VERIFY).
//
//   case OP_VERIFY:
//   {
//       // (true -- ) or
//       // (false -- false) and return
//       if (stack.size() < 1)
//           return set_error(serror, SCRIPT_ERR_INVALID_STACK_OPERATION);
//       bool fValue = CastToBool(stacktop(-1));
//       if (fValue)
//           popstack(stack);
//       else
//           return set_error(serror, SCRIPT_ERR_VERIFY);
//   }
//   break;
//
// CastToBool (interpreter.cpp:46-59) is inlined at a compile-time-fixed
// element length, one exported function per length in {0,1,2}.  The handler
// is modelled as dispatched (OP_VERIFY is outside [OP_IF..OP_ENDIF], so it is
// reached only when fExec is true; the gate is a separate row).

BINLINE bool core_cast_to_bool(const uint8_t* vch, unsigned int n) {
  for (unsigned int i = 0; i < n; i++) {
    if (vch[i] != 0) {
      if (i == n - 1 && vch[i] == 0x80)
        return false;
      return true;
    }
  }
  return false;
}

template <unsigned int LEN>
BINLINE bool core_cast_len(const uint8_t* vch) {
  return core_cast_to_bool(vch, LEN);
}

template <unsigned int LEN>
BINLINE uint32_t core_verify(uint32_t depth, const uint8_t* vch) {
  if (depth < 1)
    return 18;                             // SCRIPT_ERR_INVALID_STACK_OPERATION
  bool fValue = core_cast_len<LEN>(vch);   // interpreter.cpp:46-59
  if (!fValue)
    return 11;                             // SCRIPT_ERR_VERIFY
  return 0;                                // popstack(stack)
}

extern "C" uint64_t cell_verify_len0(uint32_t depth) {
  const uint8_t vch[1] = {0};
  const uint32_t e = core_verify<0>(depth, vch);
  VSt st{depth};
  if (e == 0)
    st.depth = depth - 1;
  return verify_pack(e, st);
}

extern "C" uint64_t cell_verify_len1(uint32_t depth, uint8_t b0) {
  const uint8_t vch[1] = {b0};
  const uint32_t e = core_verify<1>(depth, vch);
  VSt st{depth};
  if (e == 0)
    st.depth = depth - 1;
  return verify_pack(e, st);
}

extern "C" uint64_t cell_verify_len2(uint32_t depth, uint8_t b0, uint8_t b1) {
  const uint8_t vch[2] = {b0, b1};
  const uint32_t e = core_verify<2>(depth, vch);
  VSt st{depth};
  if (e == 0)
    st.depth = depth - 1;
  return verify_pack(e, st);
}
