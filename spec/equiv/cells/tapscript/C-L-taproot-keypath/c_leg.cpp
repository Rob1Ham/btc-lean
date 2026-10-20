#include "cell_common.h"
#include "checker_abi.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Excerpt -- the key-path arm, interpreter.cpp:1970-1975:
//
//   if (stack.size() == 1) {
//       // Key path spending (stack size is 1 after removing optional annex)
//       if (!checker.CheckSchnorrSignature(stack.front(), program,
//               SigVersion::TAPROOT, execdata, serror)) {
//           return false; // serror is set
//       }
//       return set_success(serror);
//   } else { ... script path ... }
//
// Precondition of this cell (spec.md): v1-32 non-P2SH, SCRIPT_VERIFY_TAPROOT
// set, annex already stripped.  `stack.front()` is the only item; `program` is
// the 32-byte output key.  The checker is the shared external seam
// checker_abi.h; its verdict and error are on both legs.
TAP_INLINE uint64_t c_keypath(uint64_t stack_n, uint32_t sig_id,
                              uint32_t program_key_id) {
  if (stack_n == 1u) {
    // :1972 -- same symbol, same arguments on both legs.
    const uint32_t r =
        btc_equiv_check_schnorr(sig_id, program_key_id, 2u /*TAPROOT*/, 32u);
    if ((r & 1u) == 0u) {
      // :1973 -- return false; serror was set by the checker.
      return tap_pack(TAP_FAIL, (r >> 1) & 0x3fu);
    }
    // :1975 -- set_success(serror)
    return tap_pack(TAP_OK, 0u);
  }
  // :1976+ -- script path is the sibling dispatch cell.
  return tap_pack(TAP_SCRIPT_PATH, 0u);
}

extern "C" uint64_t cell_keypath(uint64_t stack_n, uint32_t sig_id,
                                 uint32_t program_key_id) {
  return c_keypath(stack_n, sig_id, program_key_id);
}
