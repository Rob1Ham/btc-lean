#include "cell_common.h"

// C leg of the SCR-142 historical-window MODEL.
//
// READ THIS FIRST: this is a model leg, not a slice of any pinned Core
// source.  cce32b168 has no TAPROOT deployment and no height term on the
// TAPROOT bit; the only C text at the pin is validation.cpp:2249-2288, which
// is height-inert for TAPROOT.  This file implements the historical height
// abstraction that the row names, exactly as recorded in
// spec/core/Bitcoin/Activation/Taproot.lean:
//
//   TPR-075  taprootBip9Deployment.minActivation = 709632
//   TPR-076  taproot exception block …1e395ad: taproot = false, any height
//   TPR-078  deploymentActiveAt d height := d.minActivation <= height
//
// It is the C-shaped half of a *model* pair whose L-shaped half is l_leg.cpp.
// The model deliberately uses the representation of a historical Core flag
// word (64-bit script_verify_flags bitmask) so the two legs differ in
// representation (bitmask vs Bool record + Option), as the pinned-row cells
// do.  Equivalence of these two legs proves the model is well-formed; it is
// NOT evidence about cce32b168.  The pin-vs-model probe in ../compare/ is the
// evidence that the model is not the pin.
//
// Flag assembly modelled (only the TAPROOT term is historical; P2SH and
// WITNESS are the always-on base that was already buried by 2021):
//
//   flags = P2SH | WITNESS
//   if (709632 <= height) flags |= TAPROOT          // TPR-078
//   if (hash is an exception) flags = exception     // TPR-076, replaces
//   flags |= buried ORs by height                   // pin, unchanged
//
// Interpreter arm (interpreter.cpp:1957-1969 @cce32b168, unchanged):
//
//   v1-32 non-P2SH, TAPROOT off  -> set_success        (silent)
//   v1-32 non-P2SH, TAPROOT on, empty witness -> error 39
//   v1-32 non-P2SH, TAPROOT on, non-empty -> continue
//   other shape -> outside this arm

TAP_INLINE bool c_model_taproot_active(uint32_t height) {
  // TPR-078: deploymentActiveAt d height := d.minActivation <= height.
  return TAP_BIP9_TAPROOT_ACTIVATION_HEIGHT <= height;
}

TAP_INLINE bool c_hash_is_bip16_exception(uint64_t h0, uint64_t h1,
                                          uint64_t h2, uint64_t h3) {
  return h0 == TAP_BIP16_H0 && h1 == TAP_BIP16_H1 &&
         h2 == TAP_BIP16_H2 && h3 == TAP_BIP16_H3;
}

TAP_INLINE bool c_hash_is_taproot_exception(uint64_t h0, uint64_t h1,
                                            uint64_t h2, uint64_t h3) {
  return h0 == TAP_TR_H0 && h1 == TAP_TR_H1 &&
         h2 == TAP_TR_H2 && h3 == TAP_TR_H3;
}

// Historical BIP9-style flag assembly (MODEL, threshold form of TPR-078).
TAP_INLINE uint64_t c_model_block_flags(uint64_t h0, uint64_t h1, uint64_t h2,
                                        uint64_t h3, uint32_t height) {
  uint64_t flags = TAP_SV_P2SH | TAP_SV_WITNESS;
  if (c_model_taproot_active(height)) flags |= TAP_SV_TAPROOT;
  // TPR-076: a hash-keyed exception REPLACES the assembled base at any
  // height.  The taproot exception keeps P2SH|WITNESS and drops TAPROOT.
  if (c_hash_is_bip16_exception(h0, h1, h2, h3)) {
    flags = TAP_SV_NONE;
  } else if (c_hash_is_taproot_exception(h0, h1, h2, h3)) {
    flags = TAP_SV_P2SH | TAP_SV_WITNESS;
  }
  if (height >= TAP_BIP66_HEIGHT)  flags |= TAP_SV_DERSIG;
  if (height >= TAP_BIP65_HEIGHT)  flags |= TAP_SV_CLTV;
  if (height >= TAP_CSV_HEIGHT)    flags |= TAP_SV_CSV;
  if (height >= TAP_SEGWIT_HEIGHT) flags |= TAP_SV_NULLDUMMY;
  return flags;
}

// interpreter.cpp:1957-1969, shared with the pin (this arm is not historical).
TAP_INLINE uint64_t c_model_interpreter_gate(uint64_t flags, uint64_t version,
                                             uint64_t program_len,
                                             uint64_t is_p2sh,
                                             uint64_t witness_n) {
  if (version == 1u && program_len == 32u && is_p2sh == 0u) {
    if (!(flags & TAP_SV_TAPROOT)) return tap_pack(TAP_OK, 0u);
    if (witness_n == 0u)
      return tap_pack(TAP_FAIL, TAP_ERR_WITNESS_PROGRAM_WITNESS_EMPTY);
    return tap_pack(TAP_CONTINUE, 0u);
  }
  return tap_pack(TAP_OUTSIDE, 0u);
}

extern "C" uint64_t cell_model_taproot(
    uint64_t h0, uint64_t h1, uint64_t h2, uint64_t h3, uint32_t height,
    uint64_t version, uint64_t program_len, uint64_t is_p2sh,
    uint64_t witness_n) {
  const uint64_t flags = c_model_block_flags(h0, h1, h2, h3, height);
  const uint64_t gate =
      c_model_interpreter_gate(flags, version, program_len, is_p2sh, witness_n);
  const uint64_t taproot_on = (flags & TAP_SV_TAPROOT) != 0u ? 1u : 0u;
  return gate | (taproot_on << 8);
}
