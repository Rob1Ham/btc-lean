#include "twin_ops.h"
#include "twin_extras.h"
#include "leaf_common.h"
#include "obs.h"

// C leg — Bitcoin Core cce32b168 src/script/interpreter.cpp:
//   :460-465  opcode budget: (BASE|WITNESS_V0) && opcode > OP_16 && ++nOpCount > 201
//   :488      fExec gate
//   :787-793  OP_DEPTH: push CScriptNum(stack.size()).getvch()
//   :883-891  OP_SIZE: n < 1 -> INVALID_STACK_OPERATION, else push
//             CScriptNum(stacktop(-1).size()).getvch()
//
// SCR-076: DEPTH and SIZE both push a minimal CScriptNum.  DEPTH covers every
// stack depth in the leaf domain (0..3); the push at d = 3 fills the fourth
// slot.  SIZE covers element lengths 0,1,2,127,128,255,256,520, so both the
// one-byte/two-byte boundary (127/128) and the 0xff/0x0100 sign-byte cases are
// exercised, plus the empty-stack failure.
namespace core {

BINLINE bool budget_fails(uint8_t opCount, uint8_t sv) {
  return sv != 2 && (uint32_t)opCount + 1u > 201u;
}

// CScriptNum::getvch (interpreter.cpp:415-427): little-endian, minimal,
// sign-magnitude.  Values here are 0..520, so at most two bytes.
BINLINE uint32_t enc_num(uint32_t v, uint8_t* out) {
  if (v == 0) return 0;
  uint32_t n = 0;
  uint32_t a = v;
  while (a != 0) {
    out[n++] = (uint8_t)(a & 0xffu);
    a >>= 8;
  }
  if ((out[n - 1] & 0x80u) != 0) out[n++] = 0x00u;
  return n;
}

BINLINE uint64_t depth_body(uint8_t d, uint8_t e0, uint8_t e1, uint8_t e2,
                            uint8_t opCount, uint8_t sv) {
  LStack st;
  ls_clear(st);
  if (d > 0) ls_push(st, &e0, 1);
  if (d > 1) ls_push(st, &e1, 1);
  if (d > 2) ls_push(st, &e2, 1);

  if (budget_fails(opCount, sv)) return pack_fail(EQUIV_ERR_OP_COUNT);
  // OP_DEPTH has no stack-size pre-check: CScriptNum(0).getvch() is empty.
  uint8_t out[2];
  const uint32_t n = enc_num(st.n, out);
  ls_push(st, out, n);
  return pack_dcount(1u, st);
}

// Seed one element of exactly `len` bytes: e0 is the first byte and every
// remaining byte is zero (the bounded stores are already zeroed).
BINLINE void seed_len(LStack& st, uint32_t len, uint8_t e0) {
  st.n = 1;
  st.len[0] = len;
  if (len > 0) st.e[0][0] = e0;
}

BINLINE uint64_t size_body(uint32_t len, uint8_t e0, uint8_t opCount,
                           uint8_t sv) {
  LStack st;
  ls_clear(st);
  seed_len(st, len, e0);

  if (budget_fails(opCount, sv)) return pack_fail(EQUIV_ERR_OP_COUNT);
  if (st.n < 1) return pack_fail(EQUIV_ERR_INVALID_STACK_OPERATION);
  uint8_t out[2];
  const uint32_t n = enc_num(st.len[st.n - 1], out);
  ls_push(st, out, n);
  return pack_size(1u, st);
}

BINLINE uint64_t size_empty(uint8_t opCount, uint8_t sv) {
  LStack st;
  ls_clear(st);
  if (budget_fails(opCount, sv)) return pack_fail(EQUIV_ERR_OP_COUNT);
  if (st.n < 1) return pack_fail(EQUIV_ERR_INVALID_STACK_OPERATION);
  return pack_size(1u, st);
}

}  // namespace core

// DEPTH at stack depth 0..3.
extern "C" uint64_t cell_depth_d0(uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::depth_body(0, 0, 0, 0, opc, sv);
}
extern "C" uint64_t cell_depth_d1(uint8_t e0, uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::depth_body(1, e0, 0, 0, opc, sv);
}
extern "C" uint64_t cell_depth_d2(uint8_t e0, uint8_t e1, uint8_t opc,
                                  uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::depth_body(2, e0, e1, 0, opc, sv);
}
extern "C" uint64_t cell_depth_d3(uint8_t e0, uint8_t e1, uint8_t e2,
                                  uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::depth_body(3, e0, e1, e2, opc, sv);
}

// SIZE at one element length per entry.
#define SIZE_ARM(NAME, LEN)                                                 \
  extern "C" uint64_t NAME(uint8_t e0, uint8_t opc, uint8_t sv) {           \
    if (sv > 2) return pack_domain();                                       \
    return core::size_body(LEN, e0, opc, sv);                               \
  }

SIZE_ARM(cell_size_l0, 0u)
SIZE_ARM(cell_size_l1, 1u)
SIZE_ARM(cell_size_l2, 2u)
SIZE_ARM(cell_size_l127, 127u)
SIZE_ARM(cell_size_l128, 128u)
SIZE_ARM(cell_size_l255, 255u)
SIZE_ARM(cell_size_l256, 256u)
SIZE_ARM(cell_size_l520, 520u)

extern "C" uint64_t cell_size_empty(uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::size_empty(opc, sv);
}
