#include "w32_common.h"

// C leg: line-cited source-excerpt slices of Bitcoin Core
// src/script/interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Slices:
//   interpreter.cpp:1988-1993  leaf-version dispatch in the script-path arm:
//                              (control[0] & TAPROOT_LEAF_MASK) == TAPROOT_LEAF_TAPSCRIPT
//   interpreter.cpp:1995-1998  unknown leaf version: policy failure, else success
//   interpreter.cpp:2000-2001  P2A: !is_p2sh && CScript::IsPayToAnchor(v, program)
//   interpreter.cpp:2002-2008  every other version/size/p2sh combination
//   script.cpp:216-222         CScript::IsPayToAnchor(version, program)
//
// Declared abstractions (they are arbitrary inputs, not asserted successes):
//   * tapscript_rc: ExecuteWitnessScript for leaf version 0xc0
//     (interpreter.cpp:1990-1993).  Script execution is not modelled.
//   * taproot_rc: the witversion 1 / 32-byte program / !is_p2sh arm
//     (interpreter.cpp:1970-1998: annex, control block, commitment,
//     key/script path).  Not modelled.
//
// Both are uninterpreted 64-bit packed (result,error) values, so the equality
// proof says nothing about them and cannot fabricate a pass.
//
// Error ordinals (contract/error_kind.h):
//   34 EQUIV_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
//   35 EQUIV_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION

// interpreter.h:242-243
#define TAPROOT_LEAF_MASK 0xfe
#define TAPROOT_LEAF_TAPSCRIPT 0xc0

W32INLINE uint64_t c_leaf_version(uint8_t control0, uint32_t discourage_utv,
                                  uint64_t tapscript_rc) {
    // interpreter.cpp:1988-1993
    if ((control0 & TAPROOT_LEAF_MASK) == TAPROOT_LEAF_TAPSCRIPT) {
        return tapscript_rc;  // ExecuteWitnessScript(stack, ..., TAPSCRIPT)
    }
    // interpreter.cpp:1995-1998
    if (discourage_utv != 0) return w32_pack(0, 35);
    return w32_pack(1, 0);
}

W32INLINE uint64_t c_program_tail(uint32_t version, uint32_t plen,
                                  uint8_t b0, uint8_t b1,
                                  uint32_t is_p2sh, uint32_t discourage_ugwp,
                                  uint64_t taproot_rc) {
    // VerifyWitnessProgram is only reached for witversion 0..16
    // (CScript::IsWitnessProgram, script.cpp:176-205); 0 is the v0 arm and is
    // outside this cell.
    if (version == 0 || version > 16) return w32_bad_domain();
    // interpreter.cpp:1970-1998: taproot arm, not modelled.
    if (version == 1 && plen == 32 && is_p2sh == 0) return taproot_rc;
    // interpreter.cpp:2000-2001 + script.cpp:216-222 (IsPayToAnchor).
    // This arm precedes the discourage check, so P2A is success under any flag.
    if (is_p2sh == 0 && version == 1 && plen == 2 &&
        b0 == 0x4e && b1 == 0x73) {
        return w32_pack(1, 0);
    }
    // interpreter.cpp:2002-2008
    if (discourage_ugwp != 0) return w32_pack(0, 34);
    return w32_pack(1, 0);
}

extern "C" uint64_t cell_leaf_version_dispatch(uint8_t control0,
                                               uint32_t discourage_utv,
                                               uint64_t tapscript_rc) {
    return c_leaf_version(control0, discourage_utv, tapscript_rc);
}

extern "C" uint64_t cell_program_tail_dispatch(uint32_t version, uint32_t plen,
                                               uint8_t b0, uint8_t b1,
                                               uint32_t is_p2sh,
                                               uint32_t discourage_ugwp,
                                               uint64_t taproot_rc) {
    return c_program_tail(version, plen, b0, b1, is_p2sh, discourage_ugwp,
                          taproot_rc);
}
