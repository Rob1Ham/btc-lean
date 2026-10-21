#include "cell_common.h"

// L leg: REVIEWED TRANSLITERATION, not generated from the twin.
//
// At repo_head 805c804 the twin has no VerifyWitnessProgram handler, so this
// file restates the Verified Lean definition
//   Bitcoin.Interpreter.Defs.verifyWitnessProgram
//     (spec/core/Bitcoin/Interpreter/Defs.lean:1259-1321),
// taproot-arm head. Lean's branch order, quoted from the source:
//
//   else if version = 1 ∧ program.size = 32 ∧ !isP2SH then        -- :1280
//     -- BIP341 taproot
//     if !flags.taproot then .ok                                   -- :1282
//     else match witness with
//       | [] => .fail .witnessProgramWitnessEmpty                  -- :1284
//       | _ => ... annex / key / script path ...                   -- :1287-1300
//
// ScriptFlags.taproot is the Lean field for SCRIPT_VERIFY_TAPROOT. The cell
// stops at the same continuation marker as the C leg; annex, key path and
// script path are sibling cells. Error ordinals are the shared EQUIV_ERR_*
// values (witnessProgramWitnessEmpty = 39).

struct LOut { uint32_t result; uint32_t error; };

TAP_INLINE uint64_t l_taproot_gate(uint64_t version, uint64_t program_size,
                                   uint64_t is_p2sh, uint64_t taproot_flag,
                                   uint64_t witness_len) {
  // :1280
  if (version == 1u && program_size == 32u && is_p2sh == 0u) {
    // :1282
    if (taproot_flag == 0u) return tap_pack(TAP_OK, 0u);
    // :1283-1284
    if (witness_len == 0u) {
      return tap_pack(TAP_FAIL, TAP_ERR_WITNESS_PROGRAM_WITNESS_EMPTY);
    }
    // :1287-1300
    return tap_pack(TAP_CONTINUE, 0u);
  }
  return tap_pack(TAP_OUTSIDE, 0u);
}

extern "C" uint64_t cell_taproot_gate(uint64_t version, uint64_t program_len,
                                      uint64_t is_p2sh, uint64_t taproot_flag,
                                      uint64_t witness_n) {
  return l_taproot_gate(version, program_len, is_p2sh, taproot_flag,
                        witness_n);
}
