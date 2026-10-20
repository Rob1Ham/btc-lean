// C leg -- SCR-117 CHECKMULTISIG per-pair encoding gates.
//
// Line-cited slice of Bitcoin Core v32.99 interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   1152-1160  per-signature FindAndDelete (off in this cell: SCR-115's row)
//   1163-1166  while (fSuccess && nSigsCount > 0)
//   1168-1169  vchSig = stacktop(-isig); vchPubKey = stacktop(-ikey);
//   1171-1174  if (!CheckSignatureEncoding(vchSig, flags, serror) ||
//                  !CheckPubKeyEncoding(vchPubKey, flags, sigversion, serror))
//                return false;                       // serror is set
//   1177       bool fOk = checker.CheckECDSASignature(...)
//   1186-1189  if (nSigsCount > nKeysCount) fSuccess = false;
//
// The row's claim is *where* the two encoding validators sit: once per pair,
// inside the loop, before the checker call, with the signature gate taking
// precedence (C's `||` short-circuit) and either gate aborting the operation
// with its own contract error ordinal.  The cell therefore reports the loop's
// *trace*: for each of the at-most-two bodies, whether the gates were
// evaluated, which one fired, whether the checker was reached, and what it
// returned.
//
// Bound: MAX_PUBKEYS_PER_MULTISIG is 20, so a complete rule needs 20 unrolled
// bodies; this cell unrolls 2 and says `partial` for that reason.  nKeys and
// nSigs are additionally capped at 2 so no loop iteration can fall outside the
// unrolled prefix.  Out-of-domain inputs return the sentinel 0xFFFF in both
// legs: the guard is cell harness, not engine code.
//
// flags = 0 (pre-tapscript, no DERSIG/LOW_S/STRICTENC/CONST_SCRIPTCODE) and
// sigversion = BASE (0) are fixed.  The validators themselves are abstract
// policy stubs at the seam; this cell proves the engine's call sites and
// error/latch behaviour, not BIP66/BIP62 content.  A gate failure aborts the
// operation before the checker and before any counter update, exactly as the
// early `return false` does in Core.
#include <cstdint>
#include "cms_obs.h"
#include "cms_seam.h"

#define CMS_SC 0x4142u
#define SIG_ENC(k) ((1u << 16) | (0x40u + (k)))
#define KEY_ENC(j) ((1u << 16) | (0x40u + (j)))

// One body of Core's verification loop.  `t` is the key position (the loop
// consumes exactly one key per body); `sigId` is Core's isig offset from the
// bottom of the signature block, advancing only on a match.
#define CMS_ENC_STEP()                                                     \
  if (fs && nSigsLeft > 0) {                                               \
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
          nSigsLeft -= 1;                                                  \
        }                                                                  \
        nKeysLeft -= 1;                                                    \
        if (nSigsLeft > nKeysLeft) fs = false;                             \
      }                                                                    \
    }                                                                      \
  }

extern "C" uint64_t cell_cms_enc(uint32_t nkeys, uint32_t nsigs) {
  if (nkeys > 2u || nsigs > nkeys) return 0xFFFFu;   // cell domain guard
  int64_t nSigsLeft = (int64_t)nsigs;
  int64_t nKeysLeft = (int64_t)nkeys;
  int64_t sigId = 0;                                 // bottom-up signature
  bool fs = true;
  uint32_t steps = 0u, entered = 0u, sigRej = 0u, pkRej = 0u;
  uint32_t chkCalled = 0u, chkTrue = 0u, err = 0u;
  // Core enters the loop with isig = nKeys+3 and ikey = nKeys+2 (two stack
  // positions above the key count), which is why body t pairs signature
  // (isig-nKeys-3) with key t counted down from the top key.
  CMS_ENC_STEP()
  CMS_ENC_STEP()
  return cms_pack_enc(fs ? 1u : 0u, err, steps, entered, sigRej, pkRej,
                      chkCalled, chkTrue);
}
