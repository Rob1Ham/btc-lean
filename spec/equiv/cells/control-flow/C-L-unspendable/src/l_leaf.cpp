#include "cell.h"
// L leg: direct transcription of the Lean model,
// spec/core/Bitcoin/Ledger/Interface.lean:96-101:
//
//   def MAX_SCRIPT_SIZE : Nat := 10000
//
//   @[rule "INV-112", rule "BLK-094", rule "SCR-070"]
//   def scriptUnspendable (s : Script) : Bool :=
//     (s.bytes.size > 0 && s.bytes.get! 0 == 0x6a) || s.bytes.size > MAX_SCRIPT_SIZE
//
// MAX_SCRIPT_SIZE is from the Lean model (script.h); it is not taken from
// build/twin_ops.h, whose MAX_* constants are re-bound to the bounded leaf
// domain and therefore do not carry the consensus script-size limit.

namespace {
constexpr uint32_t MAX_SCRIPT_SIZE = 10000;  // script.h; Interface.lean:96-97
}

extern "C" uint32_t cell_unspendable(uint32_t size, uint8_t first) {
  return ((size > 0 && first == 0x6a) || size > MAX_SCRIPT_SIZE) ? 1u : 0u;
}
