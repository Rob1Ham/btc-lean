#include "limits_common.h"

// L leg: reviewed transliteration of the btc-lean twin's
// `checkMultiSig` limit prefix, spec/core/Bitcoin/Interpreter/Defs.lean
// (wave16 provenance; the twin generator has no CMS-count handler):
//
//   def checkMultiSig ... :=
//     else match decodeNum ctx.pol (topAt st.stack 1) 4 with
//       | .error e => .error e
//       | .ok nkv =>
//         if nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv then .error .pubKeyCount
//         else
//           let nKeys := nkv.toNat
//           let opCount₂ := st.opCount + nKeys
//           if MAX_OPS_PER_SCRIPT < opCount₂ then .error .opCount
//           else ...
//             | .ok nsv =>
//               if nsv < 0 ∨ nKeys < nsv then .error .sigCount
//
// MAX_OPS_PER_SCRIPT = 201 and MAX_PUBKEYS_PER_MULTISIG = 20 are
// Defs.lean:72/76.  The transliteration keeps Core's `int` width for the
// decoded counters and the op-count accumulator, exactly like the C slice.
// Only the limit prefix is transliterated; the signature loop is outside the
// cell (SCR-026/027/028 are the three bound checks).

constexpr int L_MAX_OPS_PER_SCRIPT = 201;
constexpr int L_MAX_PUBKEYS_PER_MULTISIG = 20;

LIMITS_INLINE uint64_t l_cms_count_bounds(int32_t nkv, int32_t nsv, int32_t op0) {
    if (nkv < 0 || L_MAX_PUBKEYS_PER_MULTISIG < nkv)
        return lim_pack32(0, 10, (uint32_t)op0);
    int32_t nKeys = nkv;
    int32_t opCount2 = op0 + nKeys;
    if (L_MAX_OPS_PER_SCRIPT < opCount2)
        return lim_pack32(0, 7, (uint32_t)opCount2);
    if (nsv < 0 || nKeys < nsv)
        return lim_pack32(0, 9, (uint32_t)opCount2);
    return lim_pack32(1, 0, (uint32_t)opCount2);
}

extern "C" uint64_t cell_cms_count_bounds(int32_t nKeysCount, int32_t nSigsCount, int32_t nOpCountIn) {
    return l_cms_count_bounds(nKeysCount, nSigsCount, nOpCountIn);
}
