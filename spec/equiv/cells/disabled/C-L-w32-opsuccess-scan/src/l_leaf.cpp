// L leg: the Lean twin's tapscript pre-scan.
//
// Source of record (transcribed literally, not generated):
//   spec/core/Bitcoin/Interpreter/Defs.lean:463-466  isOpSuccessWire
//   spec/core/Bitcoin/Interpreter/Defs.lean:468-490  opSuccessScanFrom
//   spec/core/Bitcoin/Interpreter/Defs.lean:1207-1216 executeWitnessScript's
//     tapscript arm (scan true => .ok, or .fail .discourageOpSuccess)
//
// The scan walks decoded opcodes one at a time and returns true at the first
// OP_SUCCESSx; the twin has no generated handler for this pre-pass (the twin
// dispatch table is EvalScript, downstream of the scan), so the L table is a
// literal transcription of the Lean definition.  Both bytes are required to
// be non-push opcodes, matching the cell domain; a byte below 0x4f is
// OUT_OF_DOMAIN.
//
// Observable codes: 0 OK, 36 DISCOURAGE_OP_SUCCESS, 66 no success byte,
// 254 out of domain.
#include <cstdint>

#define BINLINE static inline __attribute__((always_inline))
namespace {
constexpr uint32_t OK = 0;
constexpr uint32_t DISCOURAGE_OP_SUCCESS = 36;
constexpr uint32_t NO_SUCCESS = 66;
constexpr uint32_t OUT_OF_DOMAIN = 254;

// Defs.lean:463-466 isOpSuccessWire.
BINLINE bool lean_is_op_success(uint32_t w) {
  return w == 80 || w == 98 ||
         (126 <= w && w <= 129) ||
         (131 <= w && w <= 134) ||
         (137 <= w && w <= 138) ||
         (141 <= w && w <= 142) ||
         (149 <= w && w <= 153) ||
         (187 <= w && w <= 254);
}

BINLINE uint64_t pack(uint32_t outcome) {
  return static_cast<uint64_t>(outcome);
}
}  // namespace

extern "C" uint64_t cell_isopsuccess(uint8_t w) {
  return pack(lean_is_op_success(w) ? 1u : 0u);
}

extern "C" uint64_t cell_scan(uint8_t w0, uint8_t w1, uint32_t discourage) {
  if (w0 < 0x4f || w1 < 0x4f) {
    return pack(OUT_OF_DOMAIN);
  }
  if (lean_is_op_success(w0)) {
    return pack((discourage & 1u) ? DISCOURAGE_OP_SUCCESS : OK);
  }
  if (lean_is_op_success(w1)) {
    return pack((discourage & 1u) ? DISCOURAGE_OP_SUCCESS : OK);
  }
  return pack(NO_SUCCESS);
}
