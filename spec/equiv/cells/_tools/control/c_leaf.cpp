#include "gate_common.h"
// C leg: exact source slices from Bitcoin Core cce32b168
// src/script/interpreter.cpp.  Each function is a closed witness over a
// bounded stack (depth <= 6, element <= 1 byte).
BINLINE uint32_t core_push(BStack& s, uint32_t v) {
  if (s.n >= 6) return 8;                       // SCRIPT_ERR_STACK_SIZE
  s.len[s.n] = 1; s.val[s.n] = v; s.n += 1;
  return 0;
}
// interpreter.cpp:529-530: case OP_NOP: break;
BINLINE uint32_t core_nop(BStack& s) { (void)s; return 0; }
// interpreter.cpp:605-609: NOP1/NOP4..NOP10 are no-ops unless the
// DISCOURAGE_UPGRADABLE_NOPS policy flag is set (the cell uses flags=0).
BINLINE uint32_t core_nop_upgradable(BStack& s) { (void)s; return 0; }
// interpreter.cpp:677-680: case OP_RETURN: return SCRIPT_ERR_OP_RETURN;
BINLINE uint32_t core_return(BStack& s) { (void)s; return 3; }
// interpreter.cpp:1876-1880: empty/false top => EVAL_FALSE.
BINLINE uint64_t core_finish(BStack& s) {
  if (s.n == 0) return b_pack(0, 2, s);
  if (!b_truth(s, s.n - 1)) return b_pack(0, 2, s);
  return b_pack(1, 0, s);
}
extern "C" uint64_t cell_op_return() {
  BStack s; b_clear(s);
  const uint32_t e = core_return(s);
  return b_pack(0, e, s);
}
extern "C" uint64_t cell_plain_nop() {
  BStack s; b_clear(s);
  uint32_t e = core_push(s, 1);
  if (e) return b_pack(0, e, s);
  e = core_nop(s);
  if (e) return b_pack(0, e, s);
  return core_finish(s);
}
extern "C" uint64_t cell_nop1() {
  BStack s; b_clear(s);
  uint32_t e = core_push(s, 1);
  if (e) return b_pack(0, e, s);
  e = core_nop_upgradable(s);
  if (e) return b_pack(0, e, s);
  return core_finish(s);
}
extern "C" uint64_t cell_nop4_to_10() {
  BStack s; b_clear(s);
  uint32_t e = core_push(s, 1);
  if (e) return b_pack(0, e, s);
  // OP_NOP4..OP_NOP10, straight-line so Alive2 sees a return.
  e = core_nop_upgradable(s); if (e) return b_pack(0, e, s);
  e = core_nop_upgradable(s); if (e) return b_pack(0, e, s);
  e = core_nop_upgradable(s); if (e) return b_pack(0, e, s);
  e = core_nop_upgradable(s); if (e) return b_pack(0, e, s);
  e = core_nop_upgradable(s); if (e) return b_pack(0, e, s);
  e = core_nop_upgradable(s); if (e) return b_pack(0, e, s);
  e = core_nop_upgradable(s); if (e) return b_pack(0, e, s);
  return core_finish(s);
}
