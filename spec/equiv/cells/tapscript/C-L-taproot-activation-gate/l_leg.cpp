#include "cell_common.h"

// L leg: REVIEWED HAND TRANSLITERATION of the Verified Lean definitions.
// The Activation module has no generated twin (spec/equiv/README.md section 3
// documents the hand-transliterated fallback), so this file restates:
//
//   Bitcoin.Activation.getBlockScriptFlagsP mainnetParams hash height
//     (spec/core/Bitcoin/Activation/Flags.lean:145-157)
//   Bitcoin.Activation.mainnetExceptionMap
//     (spec/core/Bitcoin/Activation/Flags.lean:69-76)
//   Bitcoin.Activation.buriedActive
//     (spec/core/Bitcoin/Activation/Flags.lean:127-128)
//   Bitcoin.Interpreter.Defs.verifyWitnessProgram taproot arm
//     (spec/core/Bitcoin/Interpreter/Defs.lean:1280-1285)
//
// Representation deliberately differs from the C leg: Core uses a 64-bit
// script_verify_flags bitmask and a std::map lookup; Lean uses a Bool record
// plus Option.  That difference is what the Alive2 compare closes.
//
// Lean source shape, quoted:
//
//   let base :=
//     match P.scriptFlagExceptions hash with
//     | some exf => exf
//     | none => { p2sh := true, witness := true, taproot := true }   -- :149-152
//   { base with
//       dersig    := base.dersig    || buriedActive P P.bip66Height  height,
//       cltv      := base.cltv      || buriedActive P P.bip65Height  height,
//       csv       := base.csv       || buriedActive P P.csvHeight    height,
//       nullDummy := base.nullDummy || buriedActive P P.segwitHeight height }
//                                                                    -- :153-157
//
//   else if version = 1 ∧ program.size = 32 ∧ !isP2SH then             -- :1280
//     -- BIP341 taproot
//     if !flags.taproot then .ok                                       -- :1282
//     else match witness with
//       | [] => .fail .witnessProgramWitnessEmpty                      -- :1284
//       | _ => ... annex / key / script path ...                       -- :1286+

// Bitcoin.Activation.ScriptFlags (the fields flag selection reads).
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

// buriedActive P since height := since ≤ height (Flags.lean:127-128).
TAP_INLINE bool l_buried_active(uint32_t since, uint32_t height) {
  return since <= height;
}

// mainnetExceptionMap (Flags.lean:69-76).  Lean carries the hash as a 256-bit
// Nat; four limbs are a representation choice (equality of limbs = equality
// of the Nat).
TAP_INLINE LMaybeFlags l_mainnet_exception_map(uint64_t h0, uint64_t h1,
                                               uint64_t h2, uint64_t h3) {
  if (h0 == TAP_BIP16_H0 && h1 == TAP_BIP16_H1 &&
      h2 == TAP_BIP16_H2 && h3 == TAP_BIP16_H3) {
    // some { p2sh := false, witness := false, taproot := false }
    return {true, {false, false, false, false, false, false, false}};
  } else if (h0 == TAP_TR_H0 && h1 == TAP_TR_H1 &&
             h2 == TAP_TR_H2 && h3 == TAP_TR_H3) {
    // some { p2sh := true, witness := true, taproot := false }
    return {true, {true, true, false, false, false, false, false}};
  }
  return {false, {false, false, false, false, false, false, false}};
}

// getBlockScriptFlagsP mainnetParams (Flags.lean:145-157).
TAP_INLINE LScriptFlags l_get_block_script_flags(uint64_t h0, uint64_t h1,
                                                 uint64_t h2, uint64_t h3,
                                                 uint32_t height) {
  const LMaybeFlags exc = l_mainnet_exception_map(h0, h1, h2, h3);
  // let base := match ... with some exf => exf | none => { true, true, true }
  LScriptFlags base = exc.has
      ? exc.v
      : LScriptFlags{true, true, true, false, false, false, false};
  // { base with dersig := base.dersig || buriedActive ... }
  base.dersig = base.dersig || l_buried_active(TAP_BIP66_HEIGHT, height);
  base.cltv = base.cltv || l_buried_active(TAP_BIP65_HEIGHT, height);
  base.csv = base.csv || l_buried_active(TAP_CSV_HEIGHT, height);
  base.nullDummy = base.nullDummy || l_buried_active(TAP_SEGWIT_HEIGHT, height);
  return base;
}

// verifyWitnessProgram taproot arm (Defs.lean:1280-1285).
TAP_INLINE uint64_t l_interpreter_gate(const LScriptFlags& flags,
                                       uint64_t version, uint64_t program_size,
                                       uint64_t is_p2sh,
                                       uint64_t witness_len) {
  // :1280
  if (version == 1u && program_size == 32u && is_p2sh == 0u) {
    // :1282
    if (!flags.taproot) return tap_pack(TAP_OK, 0u);
    // :1283-1284
    if (witness_len == 0u)
      return tap_pack(TAP_FAIL, TAP_ERR_WITNESS_PROGRAM_WITNESS_EMPTY);
    // :1286+
    return tap_pack(TAP_CONTINUE, 0u);
  }
  return tap_pack(TAP_OUTSIDE, 0u);
}

extern "C" uint64_t cell_taproot_activation(
    uint64_t h0, uint64_t h1, uint64_t h2, uint64_t h3, uint32_t height,
    uint64_t version, uint64_t program_len, uint64_t is_p2sh,
    uint64_t witness_n) {
  const LScriptFlags flags = l_get_block_script_flags(h0, h1, h2, h3, height);
  const uint64_t gate =
      l_interpreter_gate(flags, version, program_len, is_p2sh, witness_n);
  return gate | (flags.taproot ? 0x100u : 0u);
}
