#include "w32_common.h"
#include "error_kind.h"

// L leg: reviewed transliteration of the verified Lean `verifyScriptFull`
// empty-scriptPubKey face (spec/proofs/BitcoinProofs/AF/PDW90/PDW90.lean:22-34,
// `verifyScriptFull_empty_spk`) and of the twin's `verify_script_full`
// witness/cleanstack tails (twin/runtime.inc:806-841).
//
// The twin keeps the checks in this order (empty scriptPubKey => spk_wp and
// is_p2sh are both false, so those blocks are skipped):
//
//   spk_wp = is_witness_program(spk, spk_len)              -- false
//   if (witness && spk_wp) { ... }                          -- skipped
//   if (p2sh && is_p2sh(spk)) { ... }                       -- false
//   if (cleanstack && st.stack.n != 1) return CLEANSTACK;   -- n == 1 here
//   if (witness && tx.witness_nonempty && !spk_wp) return WITNESS_UNEXPECTED;
//   return OK;
//
// The Lean face proves the WITNESS-off arm from these hypotheses; the
// WITNESS-on arm is the last two lines. `cleanstack` is policy; the row notes
// that its one-element arm was previously unproved — this cell covers it
// symbolically (n == 1 passes; the n != 1 failure is SCR-008, a different
// row with a symbolic depth input).

namespace l_w32_witness {

struct State {
  uint64_t n;   // final stack depth after both evaluations
};

W32INLINE uint64_t verify_empty_spk(uint64_t ss_err, uint64_t witness,
                                    uint64_t witness_nonempty, uint64_t cleanstack) {
  if (ss_err != 0) return w32_pack(0, (uint32_t)ss_err);
  State st{1};                     // scriptSig left one truthy element
  const bool spk_wp = false;       // empty scriptPubKey
  if (witness != 0 && spk_wp) return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);
  // P2SH block: empty script is not pay-to-script-hash.
  if (cleanstack != 0) {
    // Core asserts WITNESS (and P2SH) when CLEANSTACK is set; declared guard.
    if (witness == 0) return w32_pack(0, EQUIV_ERR_UNKNOWN_ERROR);
    if (st.n != 1) return w32_pack(0, EQUIV_ERR_CLEANSTACK);
  }
  if (witness != 0 && witness_nonempty != 0 && !spk_wp) {
    return w32_pack(0, EQUIV_ERR_WITNESS_UNEXPECTED);
  }
  return w32_pack(1, EQUIV_ERR_OK);
}

}  // namespace l_w32_witness

extern "C" uint64_t cell_witness_flag(uint64_t ss_err, uint64_t witness,
                                      uint64_t witness_nonempty, uint64_t cleanstack) {
  return l_w32_witness::verify_empty_spk(ss_err, witness, witness_nonempty, cleanstack);
}
