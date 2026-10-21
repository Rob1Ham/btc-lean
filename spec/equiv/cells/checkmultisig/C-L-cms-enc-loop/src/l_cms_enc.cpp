// L leg -- SCR-117 CHECKMULTISIG per-pair encoding gates.
//
// REVIEWED TRANSLITERATION of Bitcoin.Interpreter.Defs.cmsLoop
// (spec/core/Bitcoin/Interpreter/Defs.lean:672-700) and of the call that
// supplies its arguments (Defs.lean:1113-1118):
//
//   cmsLoop flags pol sv chk ed scriptCode st fuel nKeys nSigs isig ikey :=
//     if nSigs = 0 then .ok true
//     else match fuel with
//       | 0 => .ok false
//       | f+1 =>
//         let sig := st[isig-1]!
//         let pk  := st[ikey-1]!
//         match checkSigEncoding flags pol sig, checkPubKeyEncoding flags pol sv pk with
//         | some e, _ => .error e
//         | _, some e => .error e
//         | none, none =>
//           let fOk := chk.base.checkECDSASignature sig pk scriptCode sv ed
//           let isig' := if fOk then isig + 1 else isig
//           let nSigs' := if fOk then nSigs - 1 else nSigs
//           let ikey' := ikey + 1
//           let nKeys' := nKeys - 1
//           if nSigs' > nKeys' then .ok false
//           else cmsLoop ... f nKeys' nSigs' isig' ikey'
//
// The `some e, _` alternative is the signature gate taking precedence; the
// encoding error replaces the loop result with `.error e`, so the checker is
// not consulted and the counters are not updated.  This is the same latch the
// C leg gets from `||` short-circuit plus `return false`.
//
// Initial call: cmsLoop ... (nKeys + nSigs + 1) nKeys nSigs (nKeys + 3) 2
// (Defs.lean:1114-1116).  Lean's stack is top-first: `st[isig-1]!` walks
// signatures upward from the bottom-most one, `st[ikey-1]!` walks keys
// downward from the top-most one.  Body t therefore pairs signature index
// (isig-1 - (nKeys+2)) with key t, matching the C leg's element convention.
//
// Bound: this leg unrolls 2 bodies and the guard caps nKeys/nSigs at 2, so
// no reachable body lies outside the unrolled prefix (partial for the row).
// Fuel = nKeys+nSigs+1 exceeds the 2 bodies, so it is never the exit cause.
#include <cstdint>
#include "cms_obs.h"
#include "cms_seam.h"

#define CMS_SC 0x4142u
#define SIG_ENC(k) ((1u << 16) | (0x40u + (k)))
#define KEY_ENC(j) ((1u << 16) | (0x40u + (j)))

// One cmsLoop body at key position t.  `sigId` is 0-based from the bottom-most
// signature; `fuelLeft` mirrors the decreasing fuel argument.
#define CMS_ENC_STEP()                                                     \
  if (fs && nSigs > 0 && fuelLeft > 0) {                                   \
    const uint32_t t = steps++;                                            \
    const uint32_t sig = SIG_ENC(sigId);                                   \
    const uint32_t pk = KEY_ENC(t);                                        \
    entered |= (1u << t);                                                  \
    const uint32_t se = btc_equiv_check_sig_encoding(sig, 0u);             \
    if (se != 0u) {                                                        \
      err = se;                                                            \
      sigRej |= (1u << t);                                                 \
      fs = false;                                                          \
    } else {                                                               \
      const uint32_t pe = btc_equiv_check_pubkey_encoding(pk, 0u, 0u);     \
      if (pe != 0u) {                                                      \
        err = pe;                                                          \
        pkRej |= (1u << t);                                                \
        fs = false;                                                        \
      } else {                                                             \
        chkCalled |= (1u << t);                                            \
        const bool ok = btc_equiv_check_sig(sig, pk, CMS_SC, 0u) != 0;      \
        if (ok) {                                                          \
          chkTrue |= (1u << t);                                            \
          sigId += 1;                                                      \
          nSigs -= 1;                                                      \
        }                                                                  \
        nKeys -= 1;                                                        \
        fuelLeft -= 1;                                                     \
        if (nSigs > nKeys) fs = false;                                     \
      }                                                                    \
    }                                                                      \
  }

extern "C" uint64_t cell_cms_enc(uint32_t nkeys, uint32_t nsigs) {
  if (nkeys > 2u || nsigs > nkeys) return 0xFFFFu;   // cell domain guard
  int64_t nSigs = (int64_t)nsigs;
  int64_t nKeys = (int64_t)nkeys;
  int64_t sigId = 0;
  int64_t fuelLeft = (int64_t)(nkeys + nsigs + 1u);
  bool fs = true;
  uint32_t steps = 0u, entered = 0u, sigRej = 0u, pkRej = 0u;
  uint32_t chkCalled = 0u, chkTrue = 0u, err = 0u;
  CMS_ENC_STEP()
  CMS_ENC_STEP()
  return cms_pack_enc(fs ? 1u : 0u, err, steps, entered, sigRej, pkRej,
                      chkCalled, chkTrue);
}
