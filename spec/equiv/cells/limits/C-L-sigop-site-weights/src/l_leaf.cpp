#include "limits_common.h"

// L leg: reviewed transliteration of the btc-lean twin's per-opcode sigop
// contribution, spec/core/Bitcoin/Interpreter/SigOps.lean:
//
//   def opNumberOf (o : Opcode) : Option Nat :=
//     match o with
//     | .pushNum n => if 1 ≤ n ∧ n ≤ 16 then some n else none
//     | _ => none
//
//   def sigOpStep (prev : Option Opcode) (op : WireOp) : Nat :=
//     if isCheckSigWire op.wire then 1
//     else if isCheckMultiSigWire op.wire then
//       match prev >>= opNumberOf with
//       | some n => n
//       | none => MAX_PUBKEYS_PER_MULTISIG
//     else 0
//
// with isCheckSigWire = {0xac,0xad}, isCheckMultiSigWire = {0xae,0xaf}
// (SigOps.lean) and MAX_PUBKEYS_PER_MULTISIG = 20 (Defs.lean:76).
// The Core `lastOpcode >= OP_1 && lastOpcode <= OP_16` range test is exactly
// the `.pushNum n` with 1 <= n <= 16 arm (OP_1 = 0x51 .. OP_16 = 0x60), and
// DecodeOP_N is `lastOpcode - 0x50`; a non-push opcode never enters it.
// `accurate` is Core's fAccurate bool; only 0/1 are in the domain.

constexpr uint32_t L_MAX_PUBKEYS_PER_MULTISIG = 20;

LIMITS_INLINE uint32_t l_sigop_site_weight(uint8_t prev, uint8_t wire, uint8_t accurate) {
    const bool checkSig = (wire == 0xac) || (wire == 0xad);
    const bool checkMultiSig = (wire == 0xae) || (wire == 0xaf);
    if (checkSig) return 1;
    if (checkMultiSig) {
        if ((accurate != 0) && prev >= 0x51 && prev <= 0x60)
            return (uint32_t)(prev - 0x50);
        return L_MAX_PUBKEYS_PER_MULTISIG;
    }
    return 0;
}

extern "C" uint32_t cell_sigop_site_weight(uint8_t lastOpcode, uint8_t opcode, uint8_t fAccurate) {
    return l_sigop_site_weight(lastOpcode, opcode, fAccurate);
}
