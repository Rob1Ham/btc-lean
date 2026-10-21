#include "cell_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Excerpt -- the TAPROOT flag gate and the v1-32 arm head,
// interpreter.cpp:1957-1969:
//
//   } else if (witversion == 1 && program.size() == WITNESS_V1_TAPROOT_SIZE && !is_p2sh) {
//       // BIP341 Taproot: 32-byte non-P2SH witness v1 program
//       if (!(flags & SCRIPT_VERIFY_TAPROOT)) return set_success(serror);        // :1959
//       if (stack.size() == 0) return set_error(serror,
//           SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY);                            // :1960
//       if (stack.size() >= 2 && !stack.back().empty() &&
//           stack.back()[0] == ANNEX_TAG) { ... SpanPopBack(stack) ... }          // :1961-1969
//       if (stack.size() == 1) { ... key path ... } else { ... script path ... }  // :1970...
//
// The cell stops at the continuation marker: 1970+ is the sibling key-path and
// script-path cells' subject. result codes are cell harness, see
// cell_common.h.
//
// Constants: interpreter.h:240 WITNESS_V1_TAPROOT_SIZE = 32; the
// SCRIPT_VERIFY_TAPROOT script_verify_flags bit is passed as a bool.
TAP_INLINE uint64_t c_taproot_gate(uint64_t version, uint64_t program_len,
                                   uint64_t is_p2sh, uint64_t taproot_flag,
                                   uint64_t witness_n) {
  // :1957 -- native v1-32 only; P2SH-wrapped v1 is NOT this arm.
  if (version == 1u && program_len == 32u && is_p2sh == 0u) {
    // :1959 -- activation softfork gate: silent success with the flag off.
    if (taproot_flag == 0u) return tap_pack(TAP_OK, 0u);
    // :1960 -- empty witness fails (not anyone-can-spend).
    if (witness_n == 0u)
      return tap_pack(TAP_FAIL, TAP_ERR_WITNESS_PROGRAM_WITNESS_EMPTY);
    // :1961-1970 annex/key/script dispatch: sibling cells.
    return tap_pack(TAP_CONTINUE, 0u);
  }
  return tap_pack(TAP_OUTSIDE, 0u);
}

extern "C" uint64_t cell_taproot_gate(uint64_t version, uint64_t program_len,
                                      uint64_t is_p2sh, uint64_t taproot_flag,
                                      uint64_t witness_n) {
  return c_taproot_gate(version, program_len, is_p2sh, taproot_flag, witness_n);
}
