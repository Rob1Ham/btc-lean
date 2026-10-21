#include "twin_ops.h"
#include "twin_extras.h"
#include "leaf_common.h"
#include "arity_common.h"

using namespace twinleaf;

// L leg — the twin's stack-op handlers, generated VERBATIM into
// build/twin_ops.h by cells/_tools/mk_leaf.py from twin/ops_ir.py, called at
// the depth named by each table.csv row.  Nothing about the handler bodies is
// specialised: the same op_OP_* function is used as in the engine.
//
// Seeding (harness, identical on both legs): depth d elements, each one byte.
// Element i carries the symbolic byte b_i; the PICK/ROLL index element (the
// top, i == d-1) is a zero-length element, i.e. the index 0, so the boundary
// row reaches the case's stacktop/push path rather than the index range error
// of SCR-075.  On a failure the ABI observable is verdict+error only
// (pack_fail), so the seeded bytes vanish exactly as they do on the C side.

BINLINE void l_init(State& st) {
  st.stack.n = 0;
  for (uint32_t i = 0; i < MAX_STACK_SIZE; ++i) {
    st.stack.len[i] = 0;
    for (uint32_t j = 0; j < MAX_SCRIPT_ELEMENT_SIZE; ++j) st.stack.e[i][j] = 0;
  }
  st.alt.n = 0; st.saved.n = 0; st.vf_n = 0; st.opCount = 0;
  st.codeSep = 0; st.codeSepPos = 0xffffffffu; st.opcodeIndex = 0;
  st.vwLeft = 0; st.has_vw = false;
}

// push element i of the seed stack.  `depth` and `wire` are row constants.
BINLINE TwinErr l_seed_one(State& st, uint32_t i, uint32_t depth, uint32_t wire,
                           uint8_t b) {
  const bool is_index = (wire == 0x79u || wire == 0x7au) && (depth == i + 1u);
  uint8_t v[1] = { is_index ? (uint8_t)0 : b };
  const uint32_t l = is_index ? 0u : 1u;
  return st_push(st.stack, v, l);
}

BINLINE uint64_t l_run(uint32_t depth, uint32_t wire, const uint8_t* eb) {
  Ctx ctx{};
  State st{};
  l_init(st);
  // Six unrolled conditional seeds: the i-th element exists iff depth > i.
  if (depth > 0) { if (l_seed_one(st, 0, depth, wire, eb[0]) != TWIN_OK) return pack_domain(); }
  if (depth > 1) { if (l_seed_one(st, 1, depth, wire, eb[1]) != TWIN_OK) return pack_domain(); }
  if (depth > 2) { if (l_seed_one(st, 2, depth, wire, eb[2]) != TWIN_OK) return pack_domain(); }
  if (depth > 3) { if (l_seed_one(st, 3, depth, wire, eb[3]) != TWIN_OK) return pack_domain(); }
  if (depth > 4) { if (l_seed_one(st, 4, depth, wire, eb[4]) != TWIN_OK) return pack_domain(); }
  if (depth > 5) { if (l_seed_one(st, 5, depth, wire, eb[5]) != TWIN_OK) return pack_domain(); }

  Decoded d{};
  d.kind = Kind::Op; d.data = nullptr; d.dlen = 0; d.wire = wire; d.next = 1;

  TwinErr e;
  switch (wire) {
    case 0x6d: e = op_OP_2DROP(st, ctx, d); break;
    case 0x6e: e = op_OP_2DUP(st, ctx, d); break;
    case 0x6f: e = op_OP_3DUP(st, ctx, d); break;
    case 0x70: e = op_OP_2OVER(st, ctx, d); break;
    case 0x71: e = op_OP_2ROT(st, ctx, d); break;
    case 0x72: e = op_OP_2SWAP(st, ctx, d); break;
    case 0x73: e = op_OP_IFDUP(st, ctx, d); break;
    case 0x75: e = op_OP_DROP(st, ctx, d); break;
    case 0x76: e = op_OP_DUP(st, ctx, d); break;
    case 0x77: e = op_OP_NIP(st, ctx, d); break;
    case 0x78: e = op_OP_OVER(st, ctx, d); break;
    case 0x79: e = op_OP_PICK(st, ctx, d); break;
    case 0x7a: e = op_OP_PICK(st, ctx, d); break;  // twin shares PICK/ROLL body
    case 0x7b: e = op_OP_ROT(st, ctx, d); break;
    case 0x7c: e = op_OP_SWAP(st, ctx, d); break;
    case 0x7d: e = op_OP_TUCK(st, ctx, d); break;
    default: return pack_domain();
  }
  if (e != TWIN_OK) return pack_err(e);

  // Loop-free copy of the engine stack into the observable stack.  Slot i is
  // copied unconditionally: l_init zeroes every slot and st_push only advances
  // n, so slots at or above n are zero and pack_vals masks them anyway.  The
  // unrolled form matters: alive-tv's default unroll factor does not cover the
  // family harness ls_of loop for n >= 2 and reports "doesn't reach a return".
  LStack m;
  m.n = st.stack.n;
  m.len[0] = st.stack.len[0]; m.e[0][0] = st.stack.e[0][0];
  m.len[1] = st.stack.len[1]; m.e[1][0] = st.stack.e[1][0];
  m.len[2] = st.stack.len[2]; m.e[2][0] = st.stack.e[2][0];
  m.len[3] = st.stack.len[3]; m.e[3][0] = st.stack.e[3][0];
  m.len[4] = st.stack.len[4]; m.e[4][0] = st.stack.e[4][0];
  m.len[5] = st.stack.len[5]; m.e[5][0] = st.stack.e[5][0];
  return arity_obs(1u, m);
}

// underflow rows: depth < K, six symbolic seed bytes.
#define ROW_FAIL(op, wire, d)                                                 \
  extern "C" uint64_t cell_##op##_d##d(uint8_t b0, uint8_t b1, uint8_t b2,    \
                                       uint8_t b3, uint8_t b4, uint8_t b5) {  \
    const uint8_t eb[6] = {b0, b1, b2, b3, b4, b5};                           \
    return l_run(d, wire, eb);                                                \
  }

// boundary rows: depth == K, fixed uniform seed.
#define ROW_OK(op, wire, k)                                                   \
  extern "C" uint64_t cell_##op##_ok() {                                      \
    const uint8_t eb[6] = {1, 1, 1, 1, 1, 1};                                 \
    return l_run(k, wire, eb);                                                \
  }

ROW_FAIL(2drop, 0x6d, 0)
ROW_FAIL(2drop, 0x6d, 1)
ROW_FAIL(2dup, 0x6e, 0)
ROW_FAIL(2dup, 0x6e, 1)
ROW_FAIL(3dup, 0x6f, 0)
ROW_FAIL(3dup, 0x6f, 1)
ROW_FAIL(3dup, 0x6f, 2)
ROW_FAIL(2over, 0x70, 0)
ROW_FAIL(2over, 0x70, 1)
ROW_FAIL(2over, 0x70, 2)
ROW_FAIL(2over, 0x70, 3)
ROW_FAIL(2rot, 0x71, 0)
ROW_FAIL(2rot, 0x71, 1)
ROW_FAIL(2rot, 0x71, 2)
ROW_FAIL(2rot, 0x71, 3)
ROW_FAIL(2rot, 0x71, 4)
ROW_FAIL(2rot, 0x71, 5)
ROW_FAIL(2swap, 0x72, 0)
ROW_FAIL(2swap, 0x72, 1)
ROW_FAIL(2swap, 0x72, 2)
ROW_FAIL(2swap, 0x72, 3)
ROW_FAIL(ifdup, 0x73, 0)
ROW_FAIL(drop, 0x75, 0)
ROW_FAIL(dup, 0x76, 0)
ROW_FAIL(nip, 0x77, 0)
ROW_FAIL(nip, 0x77, 1)
ROW_FAIL(over, 0x78, 0)
ROW_FAIL(over, 0x78, 1)
ROW_FAIL(pick, 0x79, 0)
ROW_FAIL(pick, 0x79, 1)
ROW_FAIL(roll, 0x7a, 0)
ROW_FAIL(roll, 0x7a, 1)
ROW_FAIL(rot, 0x7b, 0)
ROW_FAIL(rot, 0x7b, 1)
ROW_FAIL(rot, 0x7b, 2)
ROW_FAIL(swap, 0x7c, 0)
ROW_FAIL(swap, 0x7c, 1)
ROW_FAIL(tuck, 0x7d, 0)
ROW_FAIL(tuck, 0x7d, 1)

ROW_OK(2drop, 0x6d, 2)
ROW_OK(2dup, 0x6e, 2)
ROW_OK(3dup, 0x6f, 3)
ROW_OK(2over, 0x70, 4)
ROW_OK(2rot, 0x71, 6)
ROW_OK(2swap, 0x72, 4)
ROW_OK(ifdup, 0x73, 1)
ROW_OK(drop, 0x75, 1)
ROW_OK(dup, 0x76, 1)
ROW_OK(nip, 0x77, 2)
ROW_OK(over, 0x78, 2)
ROW_OK(pick, 0x79, 2)
ROW_OK(roll, 0x7a, 2)
ROW_OK(rot, 0x7b, 3)
ROW_OK(swap, 0x7c, 2)
ROW_OK(tuck, 0x7d, 2)
