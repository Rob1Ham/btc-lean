// C leg: source-excerpt slice of Bitcoin Core cce32b168
// src/script/script.cpp:365-371 (IsOpSuccess) and
// src/script/interpreter.cpp:1846-1862 (ExecuteWitnessScript OP_SUCCESSx
// pre-scan), specialised to a tapscript of exactly two non-push opcodes.
//
//   bool IsOpSuccess(const opcodetype& opcode) {
//     return opcode == 80 || opcode == 98 || (opcode >= 126 && opcode <= 129) ||
//            (opcode >= 131 && opcode <= 134) || (opcode >= 137 && opcode <= 138) ||
//            (opcode >= 141 && opcode <= 142) || (opcode >= 149 && opcode <= 153) ||
//            (opcode >= 187 && opcode <= 254);
//   }
//
//   // ExecuteWitnessScript, tapscript arm:
//   while (pc < pend) {
//       if (!script.GetOp(pc, opcode)) break;
//       ++opcode_pos;
//       if (IsOpSuccess(opcode)) {
//           if (flags & SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS)
//               return set_error(serror, SCRIPT_ERR_DISCOURAGE_OP_SUCCESS);
//           return set_success(serror);
//       }
//   }
//
// Domain: both script bytes are non-push opcodes (w >= 0x4f), so GetOp
// consumes one byte each and cannot fail.  Push payloads and decode ordering
// are F-DIV-001 / SCR-153 territory, not this row.  A byte below 0x4f is
// reported as OUT_OF_DOMAIN rather than guessed.
//
// Observable codes: 0 OK, 36 DISCOURAGE_OP_SUCCESS, 66 no success byte,
// 254 out of the declared two-opcode domain.
#include <cstdint>

#define BINLINE static inline __attribute__((always_inline))
namespace {
constexpr uint32_t OK = 0;
constexpr uint32_t DISCOURAGE_OP_SUCCESS = 36;  // EQUIV_ERR_DISCOURAGE_OP_SUCCESS
constexpr uint32_t NO_SUCCESS = 66;             // scan completed, no OP_SUCCESSx
constexpr uint32_t OUT_OF_DOMAIN = 254;

// script.cpp:365-371 verbatim.
BINLINE bool core_is_op_success(uint32_t w) {
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

// SCR-172 mapping face: IsOpSuccess over every byte 0x00..0xff.
extern "C" uint64_t cell_isopsuccess(uint8_t w) {
  return pack(core_is_op_success(w) ? 1u : 0u);
}

// SCR-172 outcome face: the tapscript pre-scan over two opcode bytes.
extern "C" uint64_t cell_scan(uint8_t w0, uint8_t w1, uint32_t discourage) {
  if (w0 < 0x4f || w1 < 0x4f) {
    return pack(OUT_OF_DOMAIN);
  }
  if (core_is_op_success(w0)) {
    return pack((discourage & 1u) ? DISCOURAGE_OP_SUCCESS : OK);
  }
  if (core_is_op_success(w1)) {
    return pack((discourage & 1u) ? DISCOURAGE_OP_SUCCESS : OK);
  }
  return pack(NO_SUCCESS);
}
