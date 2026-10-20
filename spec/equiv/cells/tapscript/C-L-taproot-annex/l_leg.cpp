#include "cell_common.h"

// L leg: REVIEWED TRANSLITERATION, not generated from the twin.
//
// The Verified Lean definition
//   Bitcoin.Interpreter.Defs.verifyWitnessProgram
// (spec/core/Bitcoin/Interpreter/Defs.lean:1287-1289) states:
//
//   let annex := 2 ≤ witness.length ∧ (witness.getLast!).size ≠ 0 ∧
//     (byteOr (witness.getLast!) 0).toNat = ANNEX_TAG
//   let stack := if annex then witness.dropLast else witness
//
// with ANNEX_TAG = 0x50 (Defs.lean:94-95).  `witness.dropLast` removes exactly
// the annex item, matching Core's SpanPopBack.  The annex hash
// (Defs.lean:1244-1246 annexHash) is a sighash input, not part of SCR-143.
TAP_INLINE uint64_t l_annex_detected(uint64_t witness_len, uint64_t last_size,
                                     uint64_t last_byte0) {
  const uint64_t b0 = last_byte0 & 0xffu;  // byteOr returns a UInt8
  const bool annex = witness_len >= 2u && last_size != 0u && b0 == TAP_ANNEX_TAG;
  return annex ? 1u : 0u;
}

TAP_INLINE uint64_t l_annex_remaining(uint64_t witness_len, uint64_t last_size,
                                      uint64_t last_byte0) {
  return l_annex_detected(witness_len, last_size, last_byte0)
             ? witness_len - 1u
             : witness_len;
}

extern "C" uint64_t cell_annex_detected(uint64_t witness_n, uint64_t last_len,
                                        uint64_t last_first) {
  return l_annex_detected(witness_n, last_len, last_first);
}

extern "C" uint64_t cell_annex_remaining(uint64_t witness_n, uint64_t last_len,
                                         uint64_t last_first) {
  return l_annex_remaining(witness_n, last_len, last_first);
}
