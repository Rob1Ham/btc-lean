#include "cell_common.h"

// L leg: REVIEWED TRANSLITERATION, not generated from the twin.
//
// At repo_head 805c804 the twin has no VerifyWitnessProgram handler.  The
// three predicates below restate Verified Lean definitions:
//
// 1. controlBlockSizeOk (spec/core/Bitcoin/Crypto/Taproot/Program.lean:495-499)
//      TAPROOT_CONTROL_BASE_SIZE ≤ control.size ∧
//        control.size ≤ TAPROOT_CONTROL_MAX_SIZE ∧
//        (control.size - TAPROOT_CONTROL_BASE_SIZE) %
//          TAPROOT_CONTROL_NODE_SIZE = 0
//    with 33 / 32 / 33+128*32 (:490-492).
//
// 2. isTapscriptLeaf and verifyTaprootLeafDispatch
//    (spec/core/Bitcoin/Script/Tapscript/LeafVersion.lean:36-70):
//      isTapscriptLeaf control := leafVersionOf control = TAPROOT_LEAF_TAPSCRIPT
//      if isTapscriptLeaf control then executeWitnessScript ... .tapscript
//      else if pol.discourageUpgradableTaprootVersion then
//        .fail .discourageUpgradableTaprootVersion
//      else .ok
//    leafVersionOf control = (control[0]).toNat &&& 0xfe (Program.lean:554-555).
//
// 3. isPayToAnchor (Defs.lean:523-525) and the verifyWitnessProgram tail
//    (Defs.lean:1319-1321):
//      else if !isP2SH ∧ isPayToAnchor version program then .ok
//      else if pol.discourageUpgradableWitnessProgram then
//        .fail .discourageUpgradableWitnessProgram
//      else .ok
//
// Policy flags are Lean's pol.discourageUpgradable* booleans; they correspond
// to SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION and
// SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM.

struct LOut { uint32_t result; uint32_t error; };
TAP_INLINE uint64_t l_pack(LOut o) { return tap_pack(o.result, o.error); }

// Program.lean:495-499
TAP_INLINE uint64_t l_control_size(uint64_t size) {
  const bool ok = size >= TAP_CONTROL_BASE_SIZE &&
                  size <= TAP_CONTROL_MAX_SIZE &&
                  ((size - TAP_CONTROL_BASE_SIZE) % TAP_CONTROL_NODE_SIZE) == 0;
  if (!ok) return tap_pack(TAP_FAIL, TAP_ERR_TAPROOT_WRONG_CONTROL_SIZE);
  return tap_pack(TAP_OK, 0u);
}

// LeafVersion.lean:36-40, 62-70 (the masked test)
TAP_INLINE uint64_t l_leaf_version(uint64_t control0,
                                   uint64_t discourage_taproot) {
  const uint64_t leaf = (control0 & 0xffu) & TAP_LEAF_MASK;  // leafVersionOf
  if (leaf == TAP_LEAF_TAPSCRIPT) return tap_pack(TAP_TAPSCRIPT, 0u);
  if (discourage_taproot != 0u) {
    return tap_pack(TAP_FAIL, TAP_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION);
  }
  return tap_pack(TAP_OK, 0u);
}

// Defs.lean:523-525
TAP_INLINE bool l_is_pay_to_anchor(uint64_t version, uint64_t program_len,
                                   uint64_t prog0, uint64_t prog1) {
  return version == 1u && program_len == 2u && (prog0 & 0xffu) == 0x4eu &&
         (prog1 & 0xffu) == 0x73u;
}

// Defs.lean:1319-1321, with the two earlier arms delegated as in the C leg.
TAP_INLINE uint64_t l_tail(uint64_t version, uint64_t program_len,
                           uint64_t prog0, uint64_t prog1, uint64_t is_p2sh,
                           uint64_t discourage_witness) {
  if (version > 16u || version == 0u) return tap_pack(TAP_DELEGATED, 0u);
  if (version == 1u && program_len == 32u && is_p2sh == 0u) {
    return tap_pack(TAP_DELEGATED, 0u);
  }
  if (is_p2sh == 0u &&
      l_is_pay_to_anchor(version, program_len, prog0, prog1)) {
    return tap_pack(TAP_OK, 0u);
  }
  if (discourage_witness != 0u) {
    return tap_pack(TAP_FAIL, TAP_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM);
  }
  return tap_pack(TAP_OK, 0u);
}

extern "C" uint64_t cell_control_size(uint64_t size) {
  return l_control_size(size);
}

extern "C" uint64_t cell_leaf_version(uint64_t control0,
                                      uint64_t discourage_taproot) {
  return l_leaf_version(control0, discourage_taproot);
}

extern "C" uint64_t cell_tail(uint64_t version, uint64_t program_len,
                              uint64_t prog0, uint64_t prog1, uint64_t is_p2sh,
                              uint64_t discourage_witness) {
  return l_tail(version, program_len, prog0, prog1, is_p2sh,
                discourage_witness);
}
