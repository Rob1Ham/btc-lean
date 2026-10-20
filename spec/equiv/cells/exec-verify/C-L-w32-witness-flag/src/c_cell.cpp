#include "w32_common.h"
#include "error_kind.h"

// C leg: line-cited source-excerpt slice of Bitcoin Core
// src/script/interpreter.cpp at pin cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// Slice: VerifyScript around the empty scriptPubKey face named by SCR-004
// (interpreter.cpp:2037-2111), with P2SH always active (the flag set in which
// both the CLEANSTACK and WITNESS asserts below hold):
//
//   2037-2040  empty/false top -> SCRIPT_ERR_EVAL_FALSE
//   2045-2059  bare witness programs: only when SCRIPT_VERIFY_WITNESS and
//              scriptPubKey.IsWitnessProgram(...). An empty scriptPubKey is
//              never a witness program, so this block exits without
//              setting hadWitness.
//   2062-2105  P2SH: only when SCRIPT_VERIFY_P2SH and
//              scriptPubKey.IsPayToScriptHash(). Empty is not P2SH.
//   2106-2128  CLEANSTACK (asserts P2SH and WITNESS are set); stack.size()
//              == 1 here (the row's one-element hypothesis), so it passes.
//              Then, with WITNESS set, `if (!hadWitness && !witness->IsNull())`
//              -> SCRIPT_ERR_WITNESS_UNEXPECTED.
//
// Script evaluation is the declared seam of the row face (PDW90.lean:22-34,
// `verifyScriptFull_empty_spk`): the scriptSig succeeded leaving exactly one
// truthy element (the row hypothesis), and the empty scriptPubKey evaluation
// is the identity on that stack (PDW90.lean:15-18, evalScriptBytes_empty).
//
// Flags: `witness` and `cleanstack` are symbolic; P2SH is fixed on. Core
// asserts CLEANSTACK -> (P2SH and WITNESS); the cell returns UNKNOWN for
// `cleanstack && !witness` instead of modelling an assert (declared guard).

W32INLINE uint64_t c_witness_flag(uint64_t ss_err, uint64_t witness,
                                  uint64_t witness_nonempty, uint64_t cleanstack) {
  // interpreter.cpp:2029-2031 (scriptSig)
  if (ss_err != 0) return w32_pack(0, (uint32_t)ss_err);
  // interpreter.cpp:2037-2040 -- one truthy element (row hypothesis).
  const bool hadWitness = false;   // empty spk is not a witness program
  // interpreter.cpp:2106-2119 -- CLEANSTACK with a one-element stack.
  if (cleanstack != 0) {
    if (witness == 0) return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);  // assert guard
    // stack.size() == 1 -> passes
  }
  // interpreter.cpp:2120-2128 -- WITNESS: no witness program was seen.
  if (witness != 0) {
    if (!hadWitness && witness_nonempty != 0) {
      return w32_pack(0, EQUIV_ERR_WITNESS_UNEXPECTED);
    }
  }
  return w32_pack(1, EQUIV_ERR_OK);
}

extern "C" uint64_t cell_witness_flag(uint64_t ss_err, uint64_t witness,
                                      uint64_t witness_nonempty, uint64_t cleanstack) {
  return c_witness_flag(ss_err, witness, witness_nonempty, cleanstack);
}
