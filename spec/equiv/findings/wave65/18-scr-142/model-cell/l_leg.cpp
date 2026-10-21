#include "cell_common.h"

// L leg of the SCR-142 historical-window MODEL.
//
// This is a reviewed hand transliteration of the historical Lean record in
// spec/core/Bitcoin/Activation/Taproot.lean, in the Bool-record + Option
// representation used by spec/core/Bitcoin/Activation/Flags.lean.  It is the
// L-shaped half of a model pair; c_leg.cpp is the bitmask-shaped half.
//
// Lean source shape being modelled (historical, NOT mainnetParams at the pin):
//
//   TPR-075  taprootBip9Deployment : { bit := 2, start := 1619222400,
//              timeout := 1628640000, minActivation := 709632,
//              threshold := 1815, period := 2016 }        -- Taproot.lean:44-51
//   TPR-078  def deploymentActiveAt (d) (height) : Bool :=
//              d.minActivation <= height                   -- Taproot.lean:133-137
//   TPR-076  taproot exception block: taproot = false, any height
//                                                          -- Taproot.lean:95-107
//   Flags.lean:145-157 getBlockScriptFlagsP base/exception/buried shape
//
// The historical deployment is deliberately NOT in mainnetDeployments at
// cce32b168 (mainnetDeployments_no_taproot, Taproot.lean:68-79).  A model
// leg is the only way to state the row's height clause without inventing a
// claim about the pin.
//
// NOTE on fidelity: TPR-078 is itself the *height abstraction* of the BIP9
// state machine (deploymentstatus.h:14-18 composes with pprev;
// versionbitscache.IsActiveAfter is the real historical test).  This cell
// models the row's threshold sentence ("only pre-activation at height
// 709632"), not the versionbits period voting.  Even a second Core pin would
// need that state machine (or a fixed chain-state harness) to be exact; see
// ../report.md residual R2.

// Bitcoin.Activation.ScriptFlags (historical model fields).
struct LScriptFlags {
  bool p2sh;
  bool witness;
  bool taproot;
  bool dersig;
  bool cltv;
  bool csv;
  bool nullDummy;
};

// Option ScriptFlags: `has = false` is `none`.
struct LMaybeFlags {
  bool has;
  LScriptFlags v;
};

// TPR-078: deploymentActiveAt d height := d.minActivation <= height.
TAP_INLINE bool l_model_taproot_active(uint32_t height) {
  return TAP_BIP9_TAPROOT_ACTIVATION_HEIGHT <= height;
}

// mainnetExceptionMap (Flags.lean:69-76), historical taproot row.
TAP_INLINE LMaybeFlags l_model_exception_map(uint64_t h0, uint64_t h1,
                                             uint64_t h2, uint64_t h3) {
  if (h0 == TAP_BIP16_H0 && h1 == TAP_BIP16_H1 &&
      h2 == TAP_BIP16_H2 && h3 == TAP_BIP16_H3) {
    return {true, {false, false, false, false, false, false, false}};
  } else if (h0 == TAP_TR_H0 && h1 == TAP_TR_H1 &&
             h2 == TAP_TR_H2 && h3 == TAP_TR_H3) {
    return {true, {true, true, false, false, false, false, false}};
  }
  return {false, {false, false, false, false, false, false, false}};
}

// Historical getBlockScriptFlagsP: base P2SH|WITNESS, TAPROOT iff
// deploymentActiveAt (TPR-078), exception replaces; buried ORs unchanged.
TAP_INLINE LScriptFlags l_model_block_flags(uint64_t h0, uint64_t h1,
                                            uint64_t h2, uint64_t h3,
                                            uint32_t height) {
  const LMaybeFlags exc = l_model_exception_map(h0, h1, h2, h3);
  LScriptFlags base = exc.has
      ? exc.v
      : LScriptFlags{true, true, l_model_taproot_active(height),
                     false, false, false, false};
  base.dersig = base.dersig || (TAP_BIP66_HEIGHT <= height);
  base.cltv = base.cltv || (TAP_BIP65_HEIGHT <= height);
  base.csv = base.csv || (TAP_CSV_HEIGHT <= height);
  base.nullDummy = base.nullDummy || (TAP_SEGWIT_HEIGHT <= height);
  return base;
}

// verifyWitnessProgram taproot arm (Defs.lean:1280-1285).
TAP_INLINE uint64_t l_model_interpreter_gate(const LScriptFlags& flags,
                                             uint64_t version,
                                             uint64_t program_size,
                                             uint64_t is_p2sh,
                                             uint64_t witness_len) {
  if (version == 1u && program_size == 32u && is_p2sh == 0u) {
    if (!flags.taproot) return tap_pack(TAP_OK, 0u);
    if (witness_len == 0u)
      return tap_pack(TAP_FAIL, TAP_ERR_WITNESS_PROGRAM_WITNESS_EMPTY);
    return tap_pack(TAP_CONTINUE, 0u);
  }
  return tap_pack(TAP_OUTSIDE, 0u);
}

extern "C" uint64_t cell_model_taproot(
    uint64_t h0, uint64_t h1, uint64_t h2, uint64_t h3, uint32_t height,
    uint64_t version, uint64_t program_len, uint64_t is_p2sh,
    uint64_t witness_n) {
  const LScriptFlags flags = l_model_block_flags(h0, h1, h2, h3, height);
  const uint64_t gate =
      l_model_interpreter_gate(flags, version, program_len, is_p2sh, witness_n);
  return gate | (flags.taproot ? 0x100u : 0u);
}
