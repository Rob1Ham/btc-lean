#include <cstdint>

// Wave64 / 41-div-w32-p2sh-cleanstack — bounded differential probe for
// F-DIV-W32-01 (domain-exact revision of the wave-32 probe).
//
// Core (interpreter.cpp:2055-2057 bare, :2100-2102 P2SH-wrapped):
//   if a witness program was verified (bare OR P2SH-wrapped) -> stack.resize(1)
//   so the terminal CLEANSTACK test at :2115 sees size 1.
//
// Lean (Defs.lean:1395-1418):
//   finalLen := if flags.witness && (isWitnessProgram spk).isSome then 1
//               else <re-evaluate the redeem script; its length>
//   `spk` is the P2SH scriptPubKey, so only the BARE arm becomes 1.
//
// Domain is total over four inputs with no out-of-domain encode:
//   bare    = 1 iff a bare witness program was verified.
//   wrapped = 1 iff a P2SH-wrapped witness program was verified.
//   both 1 is ill-formed; both legs map it to the bare arm so that the only
//   surviving disagreement is `wrapped && !bare` (= a P2SH-wrapped witness
//   spend), which is exactly the finding.  No magic kind=4 counterexample.
//
// `inner_len` is the post-redeem-evaluation stack length (2 for any v0
// witness program: OP_0 and the program).  `cs` = SCRIPT_VERIFY_CLEANSTACK.

extern "C" uint64_t probe_cleanstack_witness(uint64_t inner_len,
                                             uint64_t cs_flag,
                                             uint32_t bare,
                                             uint32_t wrapped) {
  const bool b = bare != 0u;
  const bool w = (wrapped != 0u) && !b;
  const uint64_t len = (b || w) ? 1u : inner_len;  // Core: resize(1) if any
  if (cs_flag != 0u) {
    if (len != 1u) return 0u | (30u << 2);  // (result 0, CLEANSTACK 30)
  }
  return 1u | (0u << 2);                    // (result 1, OK)
}
