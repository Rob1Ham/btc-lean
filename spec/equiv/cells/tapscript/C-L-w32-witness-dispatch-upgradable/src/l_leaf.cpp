#include "w32_common.h"

// L leg: REVIEWED TRANSLITERATION of the Lean model, not generated.
//
// The generated twin (twin/ops_ir.py) carries stepBody handlers only; it has no
// verifyWitnessProgram handler, so no mk_leaf.py body can be copied.  This file
// transliterates the Verified Lean definition
//   spec/core/Bitcoin/Interpreter/Defs.lean:1259-1321
// (`Bitcoin.Interpreter.verifyWitnessProgram`), whose relevant arms are:
//
//   1312-1315  if ((byteOr control 0).toNat &&& 0xfe) = 0xc0 then
//                executeWitnessScript ... .tapscript ed
//   1316-1318  else if pol.discourageUpgradableTaprootVersion then
//                .fail .discourageUpgradableTaprootVersion
//              else .ok
//   1319       else if !isP2SH ∧ isPayToAnchor version program then .ok
//   1320-1321  else if pol.discourageUpgradableWitnessProgram then
//                .fail .discourageUpgradableWitnessProgram
//              else .ok
//
// and Defs.lean:523-525 (`isPayToAnchor`):
//   version = 1 ∧ program.size = 2 ∧ program[0] = 0x4e ∧ program[1] = 0x73
//
// As on the C leg, `executeWitnessScript` (leaf 0xc0) and the whole taproot
// arm are uninterpreted packed inputs, not asserted successes.

W32INLINE uint64_t l_leaf_version(uint8_t control0, uint32_t discourage_utv,
                                  uint64_t tapscript_rc) {
    if ((control0 & 0xfeu) == 0xc0u) return tapscript_rc;
    if (discourage_utv) return w32_pack(0, 35);
    return w32_pack(1, 0);
}

W32INLINE uint64_t l_program_tail(uint32_t version, uint32_t plen,
                                  uint8_t b0, uint8_t b1,
                                  uint32_t is_p2sh, uint32_t discourage_ugwp,
                                  uint64_t taproot_rc) {
    // IsWitnessProgram admits version 0..16 only; v0 is the other arm.
    if (version == 0 || version > 16) return w32_bad_domain();
    if (version == 1 && plen == 32 && is_p2sh == 0) return taproot_rc;
    const bool p2a = (version == 1) && (plen == 2) &&
                     (b0 == 0x4e) && (b1 == 0x73);
    if (!is_p2sh && p2a) return w32_pack(1, 0);
    if (discourage_ugwp) return w32_pack(0, 34);
    return w32_pack(1, 0);
}

extern "C" uint64_t cell_leaf_version_dispatch(uint8_t control0,
                                               uint32_t discourage_utv,
                                               uint64_t tapscript_rc) {
    return l_leaf_version(control0, discourage_utv, tapscript_rc);
}

extern "C" uint64_t cell_program_tail_dispatch(uint32_t version, uint32_t plen,
                                               uint8_t b0, uint8_t b1,
                                               uint32_t is_p2sh,
                                               uint32_t discourage_ugwp,
                                               uint64_t taproot_rc) {
    return l_program_tail(version, plen, b0, b1, is_p2sh, discourage_ugwp,
                          taproot_rc);
}
