// C leg: source-excerpt slice of Bitcoin Core cce32b168
// src/script/interpreter.cpp:442-493 and :1227-1228 (EvalScript loop head).
//
// The slice keeps Core's exact guard order and its exact default arm:
//
//   :445   bool fExec = vfExec.all_true();
//   :455   if (!script.GetOp(pc, opcode, vchPushValue)) BAD_OPCODE
//   :457   if (vchPushValue.size() > MAX_SCRIPT_ELEMENT_SIZE) PUSH_SIZE
//   :459   if ((sigversion == BASE || sigversion == WITNESS_V0) &&
//              opcode > OP_16 && ++nOpCount > MAX_OPS_PER_SCRIPT) OP_COUNT
//   :465   if (opcode == OP_CAT || ... OP_RSHIFT) DISABLED_OPCODE
//   :484   if (opcode == OP_CODESEPARATOR && ... ) OP_CODESEPARATOR
//   :488   if (fExec && 0 <= opcode && opcode <= OP_PUSHDATA4) push
//   :493   else if (fExec || (OP_IF <= opcode && opcode <= OP_ENDIF))
//              switch (opcode) { ... default: BAD_OPCODE }   :1227-1228
//
// GetOp/push-size are outside this row and are not modelled; the cell starts
// after a successful GetOp with an empty push value.  `wv0` is 1 for
// WITNESS_V0 and 0 for BASE (the row's domain); TAPSCRIPT is deliberately not
// an input because these bytes are OP_SUCCESSx there (SCR-172 cell).
//
// Observable codes: the contract error ordinals for failures, plus
//   64 = reached the execute arm (push or switch case)
//   65 = skipped (dead branch, no switch entry)
#include <cstdint>

#define BINLINE static inline __attribute__((always_inline))
namespace {
constexpr uint32_t ERR_OP_COUNT = 7;           // EQUIV_ERR_OP_COUNT
constexpr uint32_t ERR_BAD_OPCODE = 16;        // EQUIV_ERR_BAD_OPCODE
constexpr uint32_t ERR_DISABLED_OPCODE = 17;   // EQUIV_ERR_DISABLED_OPCODE
constexpr uint32_t REACH_EXEC = 64;
constexpr uint32_t REACH_SKIP = 65;
constexpr uint32_t MAX_OPS_PER_SCRIPT = 201;   // script.h:MAX_OPS_PER_SCRIPT
constexpr uint32_t OP_16 = 0x60;
constexpr uint32_t OP_PUSHDATA4 = 0x4e;

// interpreter.cpp:459-463.  OP_RESERVED and the push opcodes do not count;
// the condition is `opcode > OP_16` and only BASE/WITNESS_V0 consult it.
BINLINE bool core_counts(uint32_t w, uint32_t wv0) {
  return wv0 != 0 && w > OP_16;
}

// interpreter.cpp:465-482, the fifteen-case list verbatim.
BINLINE bool core_disabled(uint32_t w) {
  return w == 0x7e || w == 0x7f || w == 0x80 || w == 0x81 ||
         w == 0x83 || w == 0x84 || w == 0x85 || w == 0x86 ||
         w == 0x8d || w == 0x8e ||
         w == 0x95 || w == 0x96 || w == 0x97 || w == 0x98 || w == 0x99;
}

// The case labels of Core's switch (:493-1226).  Every label below is an
// explicit `case` in the pinned source; the disabled wires are let through
// here because the :465 guard dominates, but they are not case labels either.
BINLINE bool core_case_label(uint32_t w) {
  return w == 0x4f ||                       // OP_1NEGATE
         (0x51 <= w && w <= 0x61) ||        // OP_1..OP_16, OP_NOP
         w == 0x63 || w == 0x64 ||          // OP_IF, OP_NOTIF
         (0x67 <= w && w <= 0x7d) ||        // ELSE..TUCK
         w == 0x82 ||                       // OP_SIZE
         w == 0x87 || w == 0x88 ||          // EQUAL, EQUALVERIFY
         (0x8b <= w && w <= 0x8c) ||        // 1ADD, 1SUB
         (0x8f <= w && w <= 0x94) ||        // NEGATE..SUB (0x8d/0x8e disabled)
         (0x9a <= w && w <= 0xba);          // BOOLAND..CHECKSIGADD
}

BINLINE uint64_t pack(uint32_t outcome) {
  return static_cast<uint64_t>(outcome);
}
}  // namespace

// SCR-170 / SCR-171: the disabled guard fires after the op-count gate and
// before any fExec consultation.
extern "C" uint64_t cell_guard(uint8_t w, uint32_t wv0, uint32_t nOpCount,
                               uint32_t fExec) {
  if (core_counts(w, wv0) && nOpCount + 1 > MAX_OPS_PER_SCRIPT) {
    return pack(ERR_OP_COUNT);               // :459-463, dominates :465
  }
  if (core_disabled(w)) {
    return pack(ERR_DISABLED_OPCODE);        // :465-482, unconditional on fExec
  }
  return pack(fExec ? REACH_EXEC : REACH_SKIP);
}

// SCR-174: dispatch of every wire 0x00..0xff under BASE/WITNESS_V0, including
// the default arm at :1227-1228.  OP_CHECKSIGADD (0xba) is an explicit case
// that returns BAD_OPCODE for BASE/WITNESS_V0 (:1097).
extern "C" uint64_t cell_default(uint8_t w, uint32_t wv0, uint32_t nOpCount,
                                 uint32_t fExec) {
  if (core_counts(w, wv0) && nOpCount + 1 > MAX_OPS_PER_SCRIPT) {
    return pack(ERR_OP_COUNT);
  }
  if (core_disabled(w)) {
    return pack(ERR_DISABLED_OPCODE);
  }
  // :493: the switch body runs when fExec, or for the conditional window
  // OP_IF..OP_ENDIF (0x63..0x68) even in a dead branch.
  const bool switch_entered = fExec != 0 || (0x63 <= w && w <= 0x68);
  if (!switch_entered) {
    return pack(REACH_SKIP);
  }
  if (w <= OP_PUSHDATA4) {
    return pack(REACH_EXEC);                 // :488 push arm, fExec true
  }
  if (w == 0x4f || (0x51 <= w && w <= 0x60)) {
    return pack(REACH_EXEC);                 // push-number cases
  }
  if (w == 0xba) {
    return pack(ERR_BAD_OPCODE);             // OP_CHECKSIGADD under BASE/WV0
  }
  if (core_case_label(w)) {
    return pack(REACH_EXEC);
  }
  return pack(ERR_BAD_OPCODE);               // :1227-1228 default
}
