#include "twin_ops.h"
#include "twin_extras.h"
#include "leaf_common.h"

// C leg — Bitcoin Core cce32b168 src/script/interpreter.cpp:
//   :460-465  opcode budget: (BASE|WITNESS_V0) && opcode > OP_16 && ++nOpCount > 201
//   :488      fExec gate
//   :776-785  OP_IFDUP:
//               if (stack.size() < 1) return INVALID_STACK_OPERATION;
//               valtype vch = stacktop(-1);
//               if (CastToBool(vch)) stack.push_back(vch);
//
// SCR-077: duplicate the top element iff CastToBool(top).  A one-byte element
// is false only for 0x00 and for negative zero 0x80; a zero-length element is
// false.  The symbolic v0 entry covers all 256 one-byte encodings, so both
// outcomes, including 0x80, are in the proof.  Depth 2 additionally checks
// that only the top element is duplicated.
namespace core {

BINLINE bool budget_fails(uint8_t opCount, uint8_t sv) {
  return sv != 2 && (uint32_t)opCount + 1u > 201u;
}

// CastToBool (interpreter.cpp:46-59).
BINLINE bool cast_to_bool(const uint8_t* d, uint32_t len) {
  for (uint32_t i = 0; i < len; ++i) {
    if (d[i] != 0) {
      if (i + 1 == len && d[i] == 0x80) return false;
      return true;
    }
  }
  return false;
}

// Seed `bottoms` data elements (0..2), then optionally one top element of
// length tl (0 or 1).  `has_top = false` with zero bottoms is the empty stack.
BINLINE uint64_t body(uint32_t bottoms, uint8_t e0, uint8_t e1, uint8_t v0,
                      uint32_t tl, bool has_top, uint8_t opCount, uint8_t sv) {
  LStack st;
  ls_clear(st);
  if (bottoms > 0) ls_push(st, &e0, 1);
  if (bottoms > 1) ls_push(st, &e1, 1);
  if (has_top) ls_push(st, &v0, tl);

  if (budget_fails(opCount, sv)) return pack_fail(EQUIV_ERR_OP_COUNT);
  if (st.n < 1) return pack_fail(EQUIV_ERR_INVALID_STACK_OPERATION);
  const uint32_t i = st.n - 1u;
  if (cast_to_bool(st.e[i], st.len[i])) {
    uint8_t vch[LEAF_MAXE];
    const uint32_t l = st.len[i];
    vch[0] = st.e[i][0];
    if (LEAF_MAXE >= 2 && l >= 2) vch[1] = st.e[i][1];
    ls_push(st, vch, l);
  }
  return pack_l4(1u, st);
}

}  // namespace core

extern "C" uint64_t cell_ifdup_empty(uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::body(0, 0, 0, 0, 0, false, opc, sv);
}

// One zero-length element: CastToBool is false, so nothing is duplicated.
extern "C" uint64_t cell_ifdup_len0(uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::body(0, 0, 0, 0, 0, true, opc, sv);
}

extern "C" uint64_t cell_ifdup_d1(uint8_t v0, uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::body(0, 0, 0, v0, 1, true, opc, sv);
}

extern "C" uint64_t cell_ifdup_d2(uint8_t e0, uint8_t e1, uint8_t v0,
                                  uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::body(2, e0, e1, v0, 1, true, opc, sv);
}
