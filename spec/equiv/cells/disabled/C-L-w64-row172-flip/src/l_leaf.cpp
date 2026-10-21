// L leg: literal transcription of the btc-lean model.
//
// Source of record (transcribed, not generated):
//   spec/core/Bitcoin/Interpreter/Defs.lean:455-462  disabledWire
//   spec/core/Bitcoin/Interpreter/Defs.lean:463-466  isOpSuccessWire
//   spec/core/Bitcoin/Interpreter/Defs.lean:468-490  opSuccessScanFrom
//   spec/core/Bitcoin/Interpreter/Defs.lean:817-832  stepBody guard order
//   spec/core/Bitcoin/Interpreter/Defs.lean:1207-1216 executeWitnessScript's
//     tapscript arm (scan true => .ok, or .fail .discourageOpSuccess)
//   spec/core/Bitcoin/Script/Tapscript/Delta.lean:62-85 (TPR-061/TPR-062)
//   spec/core/Bitcoin/Script/Tapscript/Delta.lean:98-... (TPR-074)
//   spec/core/Bitcoin/Interpreter/Rules.lean:731-752 (SCR-172 matrix)
//
// The Lean `executeWitnessScript` tests `opSuccessScan exec` BEFORE the
// initial stack limit and before EvalScript, then branches on
// `pol.discourageOpSuccess`; for a one-byte script whose byte is a non-push
// opcode, `opSuccessScan` is exactly `isOpSuccessWire w`. The Lean
// `stepBody` guard order is pushSize, opCount, disabledWire; for this domain
// the first two cannot fire, so the base classification is the disabled arm.
//
// The L leg differs from C in representation: it computes the policy bit as
// a Bool first (as Lean parses a policy string into a Bool field) and then
// dispatches, while C tests the raw bit. Both are transcriptions of the same
// pinned definitions, not generated twin code (the twin dispatch table starts
// downstream of the pre-scan).
//
// Codes match the C leaf: 0 OK, 17 DISABLED_OPCODE, 36
// DISCOURAGE_OP_SUCCESS, 64 base reaches switch (marker), 66 scan completes
// (marker), 254 out of domain.
#include <cstdint>

#define BINLINE static inline __attribute__((always_inline))
namespace {
constexpr uint32_t OK = 0;
constexpr uint32_t DISABLED_OPCODE = 17;
constexpr uint32_t DISCOURAGE_OP_SUCCESS = 36;
constexpr uint32_t BASE_REACHES_SWITCH = 64;
constexpr uint32_t TAPSCRIPT_SCAN_COMPLETE = 66;
constexpr uint32_t OUT_OF_DOMAIN = 254;
constexpr uint64_t DISCOURAGE_OP_SUCCESS_BIT = uint64_t{1} << 19;

// Defs.lean:455-462 disabledWire.
BINLINE bool lean_disabled_wire(uint32_t w) {
  return w == 0x7e || w == 0x7f || w == 0x80 || w == 0x81 ||
         w == 0x83 || w == 0x84 || w == 0x85 || w == 0x86 ||
         w == 0x8d || w == 0x8e || w == 0x95 || w == 0x96 ||
         w == 0x97 || w == 0x98 || w == 0x99;
}

// Defs.lean:463-466 isOpSuccessWire.
BINLINE bool lean_is_op_success_wire(uint32_t w) {
  return w == 80 || w == 98 ||
         (126 <= w && w <= 129) ||
         (131 <= w && w <= 134) ||
         (137 <= w && w <= 138) ||
         (141 <= w && w <= 142) ||
         (149 <= w && w <= 153) ||
         (187 <= w && w <= 254);
}

// stepBody (Defs.lean:817-832), restricted to a single non-push byte with
// fExec=true and the op budget clear: the only reachable rejection is
// disabledWire.
BINLINE uint32_t lean_base_outcome(uint32_t w) {
  if (w < 0x4f) return OUT_OF_DOMAIN;
  if (lean_disabled_wire(w)) return DISABLED_OPCODE;
  return BASE_REACHES_SWITCH;
}

// executeWitnessScript tapscript arm (Defs.lean:1207-1216), one-byte script.
BINLINE uint32_t lean_tapscript_outcome(uint32_t w, bool discourage) {
  if (w < 0x4f) return OUT_OF_DOMAIN;
  if (lean_is_op_success_wire(w)) {
    return discourage ? DISCOURAGE_OP_SUCCESS : OK;
  }
  return TAPSCRIPT_SCAN_COMPLETE;
}

BINLINE bool lean_discourage_op_success(uint64_t flags) {
  return (flags & DISCOURAGE_OP_SUCCESS_BIT) != 0;
}

BINLINE uint64_t lean_pack(uint32_t base, uint32_t tap) {
  return (static_cast<uint64_t>(base) << 32) | tap;
}
}  // namespace

extern "C" uint64_t cell_pair(uint8_t w, uint64_t flags) {
  const bool discourage = lean_discourage_op_success(flags);
  return lean_pack(lean_base_outcome(w),
                   lean_tapscript_outcome(w, discourage));
}

extern "C" uint64_t cell_flip(uint8_t w, uint64_t flags) {
  const bool discourage = lean_discourage_op_success(flags);
  const uint32_t base = lean_base_outcome(w);
  const uint32_t tap = lean_tapscript_outcome(w, discourage);
  const bool tap_success = tap == OK || tap == DISCOURAGE_OP_SUCCESS;
  return (base == DISABLED_OPCODE && tap_success) ? 1u : 0u;
}
