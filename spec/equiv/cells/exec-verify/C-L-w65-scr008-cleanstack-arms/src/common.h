#ifndef CELLS_EXEC_VERIFY_W65_SCR008_COMMON_H
#define CELLS_EXEC_VERIFY_W65_SCR008_COMMON_H
#include <cstdint>

#define EVINLINE static inline __attribute__((always_inline))

// Error ordinals, contract/error_kind.h (Core ScriptError at the pin).
#define EV_EVAL_FALSE               2
#define EV_CLEANSTACK               30
#define EV_WITNESS_MALLEATED        41
#define EV_WITNESS_MALLEATED_P2SH   42
#define EV_WITNESS_UNEXPECTED       43

// Packed observable: result (2 bits) | error ordinal (6 bits) << 2.
// result 0 = fail, 1 = pass.  Packing is cell harness.
EVINLINE uint64_t ev_pack(uint64_t result, uint64_t error) {
  return (result & 3u) | ((error & 0x3fu) << 2);
}

// Sentinel for the declared input domain's complement.  Both legs call this
// same inlined predicate, so the equality proof is a statement *about the
// declared domain only* — see spec.md `precondition` / `boundary`.
#define EV_OUT_OF_DOMAIN 0xffffffffffffffffULL

EVINLINE uint64_t ev_scr008_in_domain(uint64_t cleanstack, uint64_t witness,
                                      uint64_t p2sh, uint64_t spk_wit,
                                      uint64_t spk_p2sh, uint64_t redeem_wit,
                                      uint64_t ss_push_ok) {
  // 1. A scriptPubKey cannot simultaneously be a witness program and a P2SH
  //    script: `IsWitnessProgram` requires a leading OP_0/OP_1..OP_16,
  //    `IsPayToScriptHash` requires a leading OP_HASH160 (script.cpp at the
  //    pin).  Core's two arms are mutually exclusive on real inputs; the
  //    symbolic inputs must not invent the intersection.
  if (spk_wit && spk_p2sh) return 0;
  // 2. F-DIV-W32-01 boundary.  The pinned Lean `verifyScriptFull` computes
  //    `finalLen` for the P2SH branch as
  //        if flags.witness && isWitnessProgram spk then 1 else <redeem eval len>
  //    -- `spk` is the P2SH scriptPubKey, so the wrapped-witness arm keeps the
  //    inner length instead of Core's `stack.resize(1)` (:2102).  The class
  //    is reachable only when the 2092 guard passes (`ss_push_ok`); with a
  //    non-push scriptSig both models return 42 first.  The exact divergent
  //    set is therefore excluded here and demonstrated in
  //    findings/wave65/02-scr008-full-cell/ (Alive2 counterexample + concrete
  //    Core/Lean probes).  This cell does NOT cover it.
  if (p2sh && spk_p2sh && witness && redeem_wit && cleanstack && ss_push_ok)
    return 0;
  return 1;
}
#endif
