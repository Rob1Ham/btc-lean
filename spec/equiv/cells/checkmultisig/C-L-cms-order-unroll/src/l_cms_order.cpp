// L leg -- SCR-116 CHECKMULTISIG matching order and early failure.
//
// REVIEWED TRANSLITERATION of Bitcoin.Interpreter.Defs.cmsLoop
// (spec/core/Bitcoin/Interpreter/Defs.lean:672-700) and of the pass that calls
// it (Defs.lean:1113-1118):
//
//   cmsLoop flags pol sv chk ed scriptCode st fuel nKeys nSigs isig ikey :=
//     if nSigs = 0 then .ok true
//     else match fuel with
//       | 0 => .ok false
//       | f+1 =>
//         let sig := st[isig-1]!
//         let pk  := st[ikey-1]!
//         match checkSigEncoding flags pol sig, checkPubKeyEncoding flags pol sv pk with
//         | none, none =>
//           let fOk := chk.base.checkECDSASignature sig pk scriptCode sv ed
//           let isig' := if fOk then isig + 1 else isig
//           let nSigs' := if fOk then nSigs - 1 else nSigs
//           let ikey' := ikey + 1
//           let nKeys' := nKeys - 1
//           if nSigs' > nKeys' then .ok false
//           else cmsLoop ... f nKeys' nSigs' isig' ikey'
//
// with the initial call `cmsLoop ... (nKeys + nSigs + 1) nKeys nSigs
// (nKeys + 3) 2` (Defs.lean:1114-1116).  Lean's stack is top-first, so
// `st[isig-1]!` walks signatures upward from the bottom-most one and
// `st[ikey-1]!` walks keys downward from the top-most one; the element
// encodings below follow that convention, as in the C leg.
//
// Fuel is nKeys+nSigs+1, and every iteration consumes a key, so at most nKeys
// iterations ever run; this leg unrolls 4 (the cell's bound) and the guard
// rejects anything outside it with the sentinel 0xFFFF in both legs.
#include <cstdint>
#include "cms_obs.h"
#include "cms_seam.h"

#define CMS_SC 0x4142u
#define SIG_ENC(k) ((1u << 16) | (0x40u + (k)))
#define KEY_ENC(j) ((1u << 16) | (0x40u + (j)))

// One cmsLoop iteration at key position j.  `fuelLeft` mirrors the decreasing
// fuel argument; `nSigs`/`nKeys` are cmsLoop's remaining counts; the iteration
// only runs while nSigs > 0 and fuel > 0.
#define CMS_STEP(j)                                                        \
  if (fs && nSigs > 0 && fuelLeft > 0) {                                   \
    const bool fOk =                                                       \
        btc_equiv_check_sig(SIG_ENC((uint32_t)isig), KEY_ENC(j), CMS_SC,    \
                            0u) != 0;                                      \
    examined += 1u;                                                        \
    if (fOk) {                                                             \
      isig += 1;                                                           \
      nSigs -= 1;                                                          \
      mask |= (1u << (j));                                                 \
    }                                                                      \
    nKeys -= 1;                                                            \
    fuelLeft -= 1;                                                         \
    if (nSigs > nKeys) {                                                   \
      fs = false;                                                          \
      early = 1u;                                                          \
    }                                                                      \
  }

extern "C" uint64_t cell_cms_order(uint32_t nkeys, uint32_t nsigs) {
  if (nkeys > 4u || nsigs > nkeys) return 0xFFFFu;   // cell domain guard
  int64_t isig = 0;                                  // 0-based, bottom-up
  int64_t nSigs = (int64_t)nsigs;
  int64_t nKeys = (int64_t)nkeys;
  int64_t fuelLeft = (int64_t)(nkeys + nsigs + 1u);
  bool fs = true;
  uint32_t examined = 0u, mask = 0u, early = 0u;
  CMS_STEP(0u)
  CMS_STEP(1u)
  CMS_STEP(2u)
  CMS_STEP(3u)
  return cms_pack_order(examined, mask, early, fs ? 1u : 0u);
}
