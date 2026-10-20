// L leg: the twin's EvalScript step ordering and dispatch table.
//
// Guard order is the emitted eval_script (spec/equiv/twin/runtime.inc):
//   (2) :459-463  201-op budget, BASE/WITNESS_V0 and wire > 0x60
//   (3) :614      disabled_wire(w) -> TWIN_DISABLED_OPCODE (before fExec)
//   (4) :634      fExec || (0x63 <= w <= 0x68) gates dispatch
//   (5) :597-633  dispatch(): Kind::PushBytes/PushNum, then handlers.
// The wire classes are generated from twin/ops_ir.py + runtime.inc by
// src/gen_wire_table.py; no handler body is edited.
//
// Lean anchors: Defs.lean:817-848 (stepBody) and Defs.lean:455-462
// (disabledWire).  `wv0` = 1 selects WITNESS_V0, 0 selects BASE.
#include <cstdint>
#include "wire_table.h"

#define BINLINE static inline __attribute__((always_inline))
namespace {
constexpr uint32_t ERR_OP_COUNT = 7;
constexpr uint32_t ERR_BAD_OPCODE = 16;
constexpr uint32_t ERR_DISABLED_OPCODE = 17;
constexpr uint32_t REACH_EXEC = 64;
constexpr uint32_t REACH_SKIP = 65;
constexpr uint32_t MAX_OPS_PER_SCRIPT = 201;

BINLINE uint64_t pack(uint32_t outcome) {
  return static_cast<uint64_t>(outcome);
}
}  // namespace

extern "C" uint64_t cell_guard(uint8_t w, uint32_t wv0, uint32_t nOpCount,
                               uint32_t fExec) {
  if (wv0 != 0 && w > 0x60 && nOpCount + 1 > MAX_OPS_PER_SCRIPT) {
    return pack(ERR_OP_COUNT);
  }
  if (w32wire::W32_DISABLED(w)) {
    return pack(ERR_DISABLED_OPCODE);
  }
  return pack(fExec != 0 ? REACH_EXEC : REACH_SKIP);
}

extern "C" uint64_t cell_default(uint8_t w, uint32_t wv0, uint32_t nOpCount,
                                 uint32_t fExec) {
  if (wv0 != 0 && w > 0x60 && nOpCount + 1 > MAX_OPS_PER_SCRIPT) {
    return pack(ERR_OP_COUNT);
  }
  if (w32wire::W32_DISABLED(w)) {
    return pack(ERR_DISABLED_OPCODE);
  }
  const bool switch_entered = fExec != 0 || (0x63 <= w && w <= 0x68);
  if (!switch_entered) {
    return pack(REACH_SKIP);
  }
  if (w32wire::W32_PUSHBYTES(w) || w32wire::W32_PUSHNUM(w)) {
    return pack(REACH_EXEC);
  }
  if (w32wire::W32_BAD(w)) {
    return pack(ERR_BAD_OPCODE);   // OP_BAD_OPCODE handler / CHECKSIGADD_BASE
  }
  if (w32wire::W32_DISPATCHED(w)) {
    return pack(REACH_EXEC);
  }
  // dispatch()'s safety net: unreachable because the generator proves the
  // five classes partition 0x00..0xff.  Never invent a verdict.
  return pack(ERR_BAD_OPCODE);
}
