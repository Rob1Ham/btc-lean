#include "twin_ops.h"
#include "twin_extras.h"
#include "leaf_common.h"

// C leg — Bitcoin Core cce32b168 src/script/interpreter.cpp:833-849
// (OP_PICK / OP_ROLL), with the surrounding EvalScript gates:
//   :460-465  opcode budget: (BASE|WITNESS_V0) && opcode > OP_16 && ++nOpCount > 201
//   :488      fExec gate (0x79/0x7a are outside the 0x63..0x68 window)
//   :67-72    popstack
//
// SCR-075: ScriptNum(top); after the index is popped, n in [0, remaining size)
// else INVALID_STACK_OPERATION (18); ROLL erases, PICK copies; the transition
// runs in BASE/WITNESS_V0/TAPSCRIPT (the first two charge one budget unit),
// and fExec = 0 skips.
//
// Depth and, for ROLL, the index are constants per entry.  Alive2 cannot close
// the query with a symbolic depth (SMT array stores); a symbolic index is fine
// for PICK (a read) but not for ROLL, whose handler shifts a data-dependent
// number of slots in a loop.  Every entry is the same body with constants.
namespace core {

BINLINE bool budget_fails(uint8_t opCount, uint8_t sv) {
  return sv != 2 && (uint32_t)opCount + 1u > 201u;
}

// CScriptNum of a one-byte vector: 0x80 is negative zero; 0x81..0xff = -1..-127.
BINLINE int scriptnum1(uint8_t b) {
  return (b & 0x80) ? -((int)(b & 0x7f)) : (int)b;
}

// d = number of data elements under the index; the index is always pushed last.
BINLINE uint64_t body(uint8_t d, uint8_t e0, uint8_t e1, uint8_t e2,
                      uint8_t idx, uint8_t opCount, uint8_t sv, bool fExec,
                      bool roll) {
  LStack st;
  ls_clear(st);
  if (d > 0) ls_push(st, &e0, 1);
  if (d > 1) ls_push(st, &e1, 1);
  if (d > 2) ls_push(st, &e2, 1);
  ls_push(st, &idx, 1);

  if (budget_fails(opCount, sv)) return pack_fail(EQUIV_ERR_OP_COUNT);
  if (fExec) {
    // if (stack.size() < 2) return SCRIPT_ERR_INVALID_STACK_OPERATION;
    if (st.n < 2) return pack_fail(EQUIV_ERR_INVALID_STACK_OPERATION);
    // int n = CScriptNum(stacktop(-1), fRequireMinimal).getint();
    const int n = scriptnum1(idx);
    st.n -= 1;  // popstack(stack)
    // if (n < 0 || n >= (int)stack.size()) return INVALID_STACK_OPERATION;
    if (n < 0 || n >= (int)st.n) return pack_fail(EQUIV_ERR_INVALID_STACK_OPERATION);
    const uint32_t src = st.n - 1u - (uint32_t)n;  // stacktop(-n-1)
    uint8_t vch[LEAF_MAXE];
    const uint32_t vl = st.len[src];
    vch[0] = st.e[src][0];
    if (roll) {
      // stack.erase(stack.end() - n - 1);
      for (uint32_t i = src; i + 1 < st.n; ++i) {
        st.e[i][0] = st.e[i + 1][0];
        st.len[i] = st.len[i + 1];
      }
      st.n -= 1;
    }
    // stack.push_back(vch);
    ls_push(st, vch, vl);
  }
  return pack_obs(1u, st);
}

}  // namespace core

// Symbolic index (PICK only): index byte is an input.
#define PICK_ARM(NAME, D)                                                    \
  extern "C" uint64_t NAME(uint8_t e0, uint8_t e1, uint8_t e2, uint8_t idx,  \
                           uint8_t opc, uint8_t sv) {                        \
    if (sv > 2) return pack_domain();                                        \
    return core::body(D, e0, e1, e2, idx, opc, sv, true, false);             \
  }

// Constant index (ROLL): IDXB is the one-byte same-value encoding of IDXK.
#define ROLL_ARM(NAME, D, IDXB)                                              \
  extern "C" uint64_t NAME(uint8_t e0, uint8_t e1, uint8_t e2, uint8_t opc,  \
                           uint8_t sv) {                                     \
    if (sv > 2) return pack_domain();                                        \
    return core::body(D, e0, e1, e2, IDXB, opc, sv, true, true);             \
  }

PICK_ARM(cell_pick_d3_sym, 3)

// Smaller depths have fewer seeded elements, hence their own ABIs.
extern "C" uint64_t cell_pick_d1_sym(uint8_t e0, uint8_t idx, uint8_t opc,
                                     uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::body(1, e0, 0, 0, idx, opc, sv, true, false);
}

extern "C" uint64_t cell_pick_d2_sym(uint8_t e0, uint8_t e1, uint8_t idx,
                                     uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::body(2, e0, e1, 0, idx, opc, sv, true, false);
}

ROLL_ARM(cell_roll_d3_k0, 3, 0x00)
ROLL_ARM(cell_roll_d3_k1, 3, 0x01)
ROLL_ARM(cell_roll_d3_k2, 3, 0x02)

extern "C" uint64_t cell_roll_d2_k0(uint8_t e0, uint8_t e1, uint8_t opc,
                                    uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::body(2, e0, e1, 0, 0x00, opc, sv, true, true);
}

extern "C" uint64_t cell_roll_d2_k1(uint8_t e0, uint8_t e1, uint8_t opc,
                                    uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::body(2, e0, e1, 0, 0x01, opc, sv, true, true);
}

// Depth 1 has no e1/e2 inputs, so this entry has its own three-argument ABI.
extern "C" uint64_t cell_roll_d1_k0(uint8_t e0, uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::body(1, e0, 0, 0, 0x00, opc, sv, true, true);
}

// Underflow: only the index on the stack (size 1 < 2), both opcodes.
extern "C" uint64_t cell_pick_d0(uint8_t idx, uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::body(0, 0, 0, 0, idx, opc, sv, true, false);
}

extern "C" uint64_t cell_roll_d0(uint8_t idx, uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::body(0, 0, 0, 0, idx, opc, sv, true, true);
}

// Unexecuted branch: both opcodes skip identically and both charge the same
// budget unit (0x79/0x7a > OP_16), so one entry covers the pair.
extern "C" uint64_t cell_skip(uint8_t e0, uint8_t e1, uint8_t e2, uint8_t idx,
                              uint8_t opc, uint8_t sv) {
  if (sv > 2) return pack_domain();
  return core::body(3, e0, e1, e2, idx, opc, sv, false, false);
}
