#include <cstdint>

// Wave64 / 41-div-w32-p2sh-cleanstack — L leg of the bounded differential
// probe for F-DIV-W32-01: a reviewed transliteration of the Lean
// `finalLen` rule (Defs.lean:1395-1418) exactly as the cost of the cleanstack
// tail (:1418-1420).  `bare` is `flags.witness && isWitnessProgram spk` (the
// scriptPubKey); `wrapped` is irrelevant to the model — that is the defect.
//
// Same domain as the C leg: both=1 is mapped to the bare arm so the only
// surviving disagreement is `wrapped && !bare`.

extern "C" uint64_t probe_cleanstack_witness(uint64_t inner_len,
                                             uint64_t cs_flag,
                                             uint32_t bare,
                                             uint32_t wrapped) {
  (void)wrapped;  // Lean never consults the P2SH redeem script for finalLen
  const bool b = bare != 0u;
  const uint64_t len = b ? 1u : inner_len;  // Lean: only the BARE arm resizes
  if (cs_flag != 0u) {
    if (len != 1u) return 0u | (30u << 2);
  }
  return 1u | (0u << 2);
}
