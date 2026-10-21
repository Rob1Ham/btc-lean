// C leg -- SCR-116 CHECKMULTISIG matching order and early failure.
//
// Line-cited slice of Bitcoin Core v32.99 interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   1163-1166  while (fSuccess && nSigsCount > 0) {
//   1168-1169    vchSig = stacktop(-isig); vchPubKey = stacktop(-ikey);
//   1171-1174    encoding gates (off in this cell: flags = 0)
//   1177         bool fOk = checker.CheckECDSASignature(vchSig, vchPubKey,
//                                                  scriptCode, sigversion);
//   1179-1183    if (fOk) { isig++; nSigsCount--; }
//                ikey++; nKeysCount--;
//   1186-1189    if (nSigsCount > nKeysCount) fSuccess = false;
//
// The exact order of pairs and the early exit are the row's content, so the
// cell reports the loop's *trace*: which key positions were examined, which
// matched, whether the "more signatures than keys remain" exit fired, and the
// final fSuccess.  Keys are consumed top-down (ikey starts at 2 and advances),
// signatures bottom-up (isig starts at nKeys+3 and advances only on a match);
// the element encodings follow that convention: signature k is
// (len 1, byte 0x40+k) counting from the bottom of the signature block, key j
// is (len 1, byte 0x40+j) counting down from the top key.
//
// Bound: MAX_PUBKEYS_PER_MULTISIG is 20 and cmsLoop iterates at most nKeys
// times, so a *complete* rule needs 20 unrolled steps; this cell unrolls 4 and
// says `partial` for that reason.  Out-of-domain inputs (nkeys > 4, nsigs >
// nkeys) return the sentinel 0xFFFF, identically in both legs: the guard is
// cell harness, not engine code.
#include <cstdint>
#include "cms_obs.h"
#include "cms_seam.h"

#define CMS_SC 0x4142u
#define SIG_ENC(k) ((1u << 16) | (0x40u + (k)))
#define KEY_ENC(j) ((1u << 16) | (0x40u + (j)))

// One iteration of Core's loop.  `j` is the key position (constant per
// unrolled copy), `nSigsLeft`/`nKeysLeft` are Core's nSigsCount/nKeysCount,
// `isig` is Core's isig (an absolute bottom-first stack index).
#define CMS_STEP(j)                                                        \
  if (fs && nSigsLeft > 0) {                                               \
    const uint32_t sigId = (uint32_t)(isig - (int64_t)(nkeys + 3u));        \
    const bool fOk =                                                       \
        btc_equiv_check_sig(SIG_ENC(sigId), KEY_ENC(j), CMS_SC, 0u) != 0;   \
    examined += 1u;                                                        \
    if (fOk) {                                                             \
      isig += 1;                                                           \
      nSigsLeft -= 1;                                                      \
      mask |= (1u << (j));                                                 \
    }                                                                      \
    nKeysLeft -= 1;                                                        \
    if (nSigsLeft > nKeysLeft) {                                           \
      fs = false;                                                          \
      early = 1u;                                                          \
    }                                                                      \
  }

extern "C" uint64_t cell_cms_order(uint32_t nkeys, uint32_t nsigs) {
  if (nkeys > 4u || nsigs > nkeys) return 0xFFFFu;   // cell domain guard
  int64_t isig = (int64_t)nkeys + 3;                 // 1143
  int64_t nSigsLeft = (int64_t)nsigs;
  int64_t nKeysLeft = (int64_t)nkeys;
  bool fs = true;
  uint32_t examined = 0u, mask = 0u, early = 0u;
  CMS_STEP(0u)
  CMS_STEP(1u)
  CMS_STEP(2u)
  CMS_STEP(3u)
  return cms_pack_order(examined, mask, early, fs ? 1u : 0u);
}
