#include "limits_common.h"

// L leg: reviewed transliteration of the btc-lean twin's BIP342 budget and
// EvalChecksigTapscript accounting.
//
//   spec/core/Bitcoin/Interpreter/Defs.lean:1229
//       validationWeightLeft := vwSer + VALIDATION_WEIGHT_OFFSET
//   spec/core/Bitcoin/Crypto/Taproot/Program.lean:595-606, 633-642
//       witnessSerSize items =
//         Int.ofNat (compactSizeEnc items.length).size + witnessPayloadSize items
//       witnessPayloadSize items =
//         items.foldl (fun acc d =>
//           acc + Int.ofNat ((compactSizeEnc d.size).size + d.size)) 0
//       VALIDATION_WEIGHT_OFFSET = 50
//   spec/core/Bitcoin/Data/Basic.lean:73-77  compactSizeEnc thresholds
//       n < 0xfd -> 1 ; n <= 0xffff -> 3 ; n <= 0xffffffff -> 5 ; else 9
//
//   spec/core/Bitcoin/Interpreter/Defs.lean:757-788  evalChecksigTapscript
//       let success := sig.size ≠ 0
//       if success then
//         let vw' := (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED
//         if vw' < 0 then .error .tapscriptValidationWeight
//         else if pk.size = 0 then .error .tapscriptEmptyPubkey
//         else if pk.size = 32 then
//           match checkSchnorrWithContext ... with
//           | .error e => .error e
//           | .ok () => .ok (true, some vw')
//         else if pol.discourageUpgradablePubkeyType then .error .discourageUpgradablePubkeyType
//         else .ok (success, some vw')
//       else
//         if pk.size = 0 then .error .tapscriptEmptyPubkey
//         else if pk.size = 32 then .ok (false, vw)
//         else if pol.discourageUpgradablePubkeyType then .error .discourageUpgradablePubkeyType
//         else .ok (false, vw)
//
// VALIDATION_WEIGHT_PER_SIGOP_PASSED = 50 is script.h:60 / Defs.lean's
// constant.  The budget base is bounded to 4 items, matching the C leg.
// The Schnorr checker's `.error e` is the declared same-crypto seam; the
// cell encodes it as decision=2 with no ordinal, exactly as the C leg does.

constexpr int64_t L_VALIDATION_WEIGHT_PER_SIGOP_PASSED = 50;
constexpr int64_t L_VALIDATION_WEIGHT_OFFSET = 50;

LIMITS_INLINE uint64_t l_compact_size_size(uint64_t n) {
    if (n < 0xfd) return 1;
    if (n <= 0xffff) return 3;
    if (n <= 0xffffffffULL) return 5;
    return 9;
}

LIMITS_INLINE int64_t l_tapscript_budget(uint32_t n_items, uint32_t len0, uint32_t len1,
                                         uint32_t len2, uint32_t len3) {
    int64_t total = (int64_t)l_compact_size_size(n_items);
    if (n_items > 0) total += (int64_t)l_compact_size_size(len0) + (int64_t)len0;
    if (n_items > 1) total += (int64_t)l_compact_size_size(len1) + (int64_t)len1;
    if (n_items > 2) total += (int64_t)l_compact_size_size(len2) + (int64_t)len2;
    if (n_items > 3) total += (int64_t)l_compact_size_size(len3) + (int64_t)len3;
    return total + L_VALIDATION_WEIGHT_OFFSET;
}

LIMITS_INLINE uint64_t l_tapscript_checksig(int64_t w_in, uint8_t sig_nonempty,
                                            uint8_t pk_class, uint8_t discourage, uint8_t checker_ok) {
    const bool success = (sig_nonempty != 0);
    int64_t w = w_in;
    if (success) {
        w -= L_VALIDATION_WEIGHT_PER_SIGOP_PASSED;
        if (w < 0)
            return lim_pack_acc(0, 49, 1, w);
    }
    if (pk_class == 0)
        return lim_pack_acc(0, 52, success ? 1u : 0u, w);
    if (pk_class == 1) {
        if (success && !checker_ok)
            return lim_pack_acc(2, 0, 1, w);
        return lim_pack_acc(1, 0, success ? 1u : 0u, w);
    }
    if (discourage)
        return lim_pack_acc(0, 37, success ? 1u : 0u, w);
    return lim_pack_acc(1, 0, success ? 1u : 0u, w);
}

extern "C" int64_t cell_tapscript_budget(uint32_t n_items, uint32_t len0, uint32_t len1,
                                         uint32_t len2, uint32_t len3) {
    return l_tapscript_budget(n_items, len0, len1, len2, len3);
}

extern "C" uint64_t cell_tapscript_checksig(int64_t w_in, uint8_t sig_nonempty,
                                            uint8_t pk_class, uint8_t discourage, uint8_t checker_ok) {
    return l_tapscript_checksig(w_in, sig_nonempty, pk_class, discourage, checker_ok);
}
