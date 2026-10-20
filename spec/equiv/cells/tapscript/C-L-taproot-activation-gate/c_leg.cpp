#include "cell_common.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core v32.99 at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// The cell is the *composition* of two pinned slices:
//
//   (1) the TAPROOT bit of GetBlockScriptFlags, validation.cpp:2249-2288:
//
//       script_verify_flags flags{SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_WITNESS
//                                 | SCRIPT_VERIFY_TAPROOT};          // :2261
//       const auto it{consensusparams.script_flag_exceptions.find(
//                         *Assert(block_index.phashBlock))};         // :2262
//       if (it != ...end()) { flags = it->second; }                  // :2263-2265
//       ... DERSIG / CLTV / CSV / NULLDUMMY OR-ed by buried height    // :2267-2285
//
//     The hash-keyed lookup is written as equality against the two mainnet
//     entries (kernel/chainparams.cpp:115-118).  The map has exactly those
//     two entries at the pin, so the slice is fail-closed for every other
//     256-bit hash.  The four DeploymentActiveAt calls are BuriedDeployment
//     compares (deploymentstatus.h:27-31); none of them reads or writes the
//     TAPROOT bit.  Height is a genuine input and is carried through the
//     buried ORs -- it simply has no TAPROOT term.  That is the claim under
//     test (GAP-CONTEXT.md: the pin has no 709632 height gate).
//
//   (2) the interpreter gate, interpreter.cpp:1957-1969:
//
//       } else if (witversion == 1 &&
//                  program.size() == WITNESS_V1_TAPROOT_SIZE &&
//                  !is_p2sh) {                                       // :1957
//           if (!(flags & SCRIPT_VERIFY_TAPROOT))
//               return set_success(serror);                           // :1959
//           if (stack.size() == 0) return set_error(serror,
//               SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY);            // :1960
//           ... annex / key path / script path ...                    // :1961+
//
//     The cell stops at the continuation marker; :1970+ is the sibling
//     key-path / script-path subjects.
//
// Constants: interpreter.h:240 WITNESS_V1_TAPROOT_SIZE = 32; the TAPROOT
// script_verify_flags bit is 1 << 17 (verify_flags.h:31 + interpreter.h:137).

// validation.cpp:2262-2265 -- the two mainnet script_flag_exceptions keys.
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

// validation.cpp:2249-2288, full flag word (the buried ORs are kept so the
// height input is real; only the TAPROOT bit is observable in this cell).
TAP_INLINE uint64_t c_block_flags(uint64_t h0, uint64_t h1, uint64_t h2,
                                  uint64_t h3, uint32_t height) {
  // :2261 -- always-on base.
  uint64_t flags = TAP_SV_P2SH | TAP_SV_WITNESS | TAP_SV_TAPROOT;
  // :2262-2265 -- an exception hit REPLACES the base.
  if (c_hash_is_bip16_exception(h0, h1, h2, h3)) {
    flags = TAP_SV_NONE;                                  // SCRIPT_VERIFY_NONE
  } else if (c_hash_is_taproot_exception(h0, h1, h2, h3)) {
    flags = TAP_SV_P2SH | TAP_SV_WITNESS;                 // P2SH | WITNESS
  }
  // :2267-2285 -- buried ORs.  None of these touches TAPROOT.
  if (height >= TAP_BIP66_HEIGHT)  flags |= TAP_SV_DERSIG;
  if (height >= TAP_BIP65_HEIGHT)  flags |= TAP_SV_CLTV;
  if (height >= TAP_CSV_HEIGHT)    flags |= TAP_SV_CSV;
  if (height >= TAP_SEGWIT_HEIGHT) flags |= TAP_SV_NULLDUMMY;
  return flags;
}

// interpreter.cpp:1957-1969 -- v1-32 non-P2SH taproot arm head.
TAP_INLINE uint64_t c_interpreter_gate(uint64_t flags, uint64_t version,
                                       uint64_t program_len, uint64_t is_p2sh,
                                       uint64_t witness_n) {
  // :1957 -- native v1-32 only; P2SH-wrapped v1 is NOT this arm.
  if (version == 1u && program_len == 32u && is_p2sh == 0u) {
    // :1959 -- no TAPROOT flag: silent success, no witness inspection.
    if (!(flags & TAP_SV_TAPROOT)) return tap_pack(TAP_OK, 0u);
    // :1960 -- TAPROOT on and empty witness: WITNESS_PROGRAM_WITNESS_EMPTY.
    if (witness_n == 0u)
      return tap_pack(TAP_FAIL, TAP_ERR_WITNESS_PROGRAM_WITNESS_EMPTY);
    // :1961+ -- annex/key/script dispatch, sibling cells.
    return tap_pack(TAP_CONTINUE, 0u);
  }
  return tap_pack(TAP_OUTSIDE, 0u);
}

extern "C" uint64_t cell_taproot_activation(
    uint64_t h0, uint64_t h1, uint64_t h2, uint64_t h3, uint32_t height,
    uint64_t version, uint64_t program_len, uint64_t is_p2sh,
    uint64_t witness_n) {
  const uint64_t flags = c_block_flags(h0, h1, h2, h3, height);
  const uint64_t gate =
      c_interpreter_gate(flags, version, program_len, is_p2sh, witness_n);
  const uint64_t taproot_on = (flags & TAP_SV_TAPROOT) != 0u ? 1u : 0u;
  return gate | (taproot_on << 8);
}
