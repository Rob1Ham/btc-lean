// C leg -- SCR-110 at the CHECKMULTISIG NULLFAIL site.
//
// Line-cited slice of Bitcoin Core v32.99 interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   1132-1135  ikey = ++i; ikey2 = nKeysCount + 2
//   1140-1148  nSigsCount parse and range check (counts are cell inputs here;
//              SCR-114's cell owns the prelude)
//   1163-1191  verification loop (checker + counters + early exit)
//   1194-1201  cleanup scan: NULLFAIL arm (1196-1197), ikey2-- (1198-1199),
//              popstack (1200)
//   1209-1210  stack.size() < 1 -> INVALID_STACK_OPERATION
//   1211-1212  NULLDUMMY arm -> SIG_NULLDUMMY
//   1213       popstack: the extra item is consumed unchecked
//   1215       push vchTrue / vchFalse (the slice ends here: VERIFY's pop and
//              the script-end EVAL_FALSE are the tail cell's SCR-120)
//
// The row's claim at this site is the ikey2 (position) gate: the NULLFAIL arm
// is reached only once the scan has walked past the key block, i.e. only on
// the signature items.  With nKeys keys, ikey2 starts at nKeys+2 and is
// decremented *after* the test, so the signature region is the only region
// whose test sees ikey2 == 0 (with several signatures, each signature pop
// sees 0, and the scan stops at the first non-empty one).  Every
// non-signature item in the canonical test
// stack is non-empty on purpose: a scan that dropped !ikey2, or that tested
// ikey2 after decrementing it, would fire on the nKeys count, a pubkey or the
// nSigs count instead, and the packed observables would differ.
//
// Domain of this cell (see spec.md): counts 0 <= nSigs <= nKeys <= 2 (the
// unroll bound; MAX_PUBKEYS_PER_MULTISIG is 20, so the row stays partial --
// the exact residual is filed in the wave64 report), flags = NULLFAIL |
// NULLDUMMY only, sigversion BASE.  With DERSIG/LOW_S/STRICTENC/PUBKEYTYPE
// clear, CheckSignatureEncoding and CheckPubKeyEncoding return true without
// inspecting the element (interpreter.cpp:120-167), so the loop's only engine
// call is the checker; the enc-loop cell owns the validators' call sites.
// The checker is the family's one abstract seam symbol (same-crypto premise).
//
// The stack is canonical, top-down:
//   pos 1            nKeys count            (len 1, value nKeys)
//   pos 2..nKeys+1   pubkeys                (len 1, value 0x40+key index)
//   pos nKeys+2      nSigs count            (len 1, value nSigs)
//   pos nKeys+3..    signatures             (len sig0/sig1 slot, value 0x40+idx)
//   pos nKeys+nSigs+3 dummy                 (len dummylen)
// with no items below the dummy (the surviving-prefix shape with an `extra`
// prefix is the tail cell's, with NULLFAIL off).  Only lengths and the first
// byte are modelled: the NULLFAIL arm reads only stacktop(-1).size(), and the
// checker gets the family's 32-bit element word.
#include <cstdint>
#include "cms_seam.h"
#include "cms_nullfail_obs.h"

#define CMS_SC 0x4142u

// Family element encoding at the checker seam: (len << 16) | first byte.
// Signature index 0 and 1 carry their emptiness slot; keys are canonical.
static inline uint32_t nf_sig_word(uint32_t idx, uint32_t sig0,
                                   uint32_t sig1) {
  const uint32_t nonempty = (idx == 0u) ? (sig0 != 0u) : (sig1 != 0u);
  return (nonempty << 16) | (0x40u + idx);
}

static inline uint32_t nf_key_word(uint32_t idx) {
  return (1u << 16) | (0x40u + idx);
}

// Length bucket (0 empty, 1 non-empty) of the stack item at 1-based position
// p, or 0 for a position outside the CHECKMULTISIG argument block.
static inline uint32_t nf_item_len(uint32_t p, uint32_t nkeys, uint32_t nsigs,
                                   uint32_t sig0, uint32_t sig1) {
  if (p == 1u) return 1u;                                   // nKeys count
  if (p >= 2u && p <= nkeys + 1u) return 1u;                // pubkeys
  if (p == nkeys + 2u) return 1u;                           // nSigs count
  if (p >= nkeys + 3u && p <= nkeys + nsigs + 2u) {         // signatures
    const uint32_t idx = p - (nkeys + 3u);
    return (idx == 0u) ? (sig0 != 0u ? 1u : 0u)
                       : (sig1 != 0u ? 1u : 0u);
  }
  return 0u;
}

extern "C" uint64_t cell_cms_nullfail(uint32_t nkeys, uint32_t nsigs,
                                      uint32_t nullfail, uint32_t nulldummy,
                                      uint32_t sig0, uint32_t sig1,
                                      uint32_t dummylen) {
  // Cell bound: two keys, nSigs <= nKeys.  Out-of-domain inputs return the
  // shared sentinel in both legs before any position is touched; the guard is
  // cell harness, not engine code.
  if (nkeys > 2u || nsigs > nkeys) return 0xFFFFu;

  // ---- verification loop (1163-1191) -------------------------------------
  // The loop consumes exactly one key per body, so nKeys <= 2 bounds it to two
  // bodies.  `sigId` is Core's isig offset from the bottom of the signature
  // block and advances only on a match; `keyPos` is the 0-based key index.
  int64_t nSigsLeft = (int64_t)nsigs;
  int64_t nKeysLeft = (int64_t)nkeys;
  int64_t sigId = 0;
  uint32_t keyPos = 0u;
  bool fs = true;

#define CMS_NF_BODY()                                                      \
  if (fs && nSigsLeft > 0) {                                               \
    const uint32_t sig = nf_sig_word((uint32_t)sigId, sig0, sig1);         \
    const uint32_t pk = nf_key_word(keyPos);                               \
    const bool ok = btc_equiv_check_sig(sig, pk, CMS_SC, 0u) != 0;         \
    if (ok) {                                                              \
      sigId += 1;                                                          \
      nSigsLeft -= 1;                                                      \
    }                                                                      \
    keyPos += 1u;                                                          \
    nKeysLeft -= 1;                                                        \
    if (nSigsLeft > nKeysLeft) fs = false;                                 \
  }
  CMS_NF_BODY()
  CMS_NF_BODY()
#undef CMS_NF_BODY

  // ---- cleanup scan (1194-1201) ------------------------------------------
  // i after the prelude is nKeys+nSigs+3, so `while (i-- > 1)` performs
  // i-1 = nKeys+nSigs+2 pops.  At pop p the *pre-decrement* ikey2 is
  // nKeys+2-(p-1), clamped at 0 (Core only decrements while ikey2 > 0).
  const uint32_t pops = nkeys + nsigs + 2u;
  uint32_t popped = 0u, firePos = 0u, ikey2Fire = 7u, fireLen = 2u;
  uint32_t err = 0u;
  bool errored = false;

#define CMS_NF_POP(P)                                                       \
  if (!errored && (P) <= pops) {                                             \
    int64_t k2 = (int64_t)nkeys + 2 - (int64_t)((P) - 1u);                   \
    if (k2 < 0) k2 = 0;                                                      \
    const uint32_t len = nf_item_len((P), nkeys, nsigs, sig0, sig1);         \
    if (!fs && nullfail != 0u && k2 == 0 && len != 0u) {                     \
      errored = true;                                                        \
      firePos = (P);                                                         \
      ikey2Fire = (uint32_t)k2;                                              \
      fireLen = len;                                                         \
      err = NF_SIG_NULLFAIL;          /* 1197: return before popstack */     \
    } else {                                                                 \
      popped += 1u;                   /* 1198-1199 then 1200 */              \
    }                                                                        \
  }
  CMS_NF_POP(1)
  CMS_NF_POP(2)
  CMS_NF_POP(3)
  CMS_NF_POP(4)
  CMS_NF_POP(5)
  CMS_NF_POP(6)
#undef CMS_NF_POP

  // Depth after the pops that were performed: the front matter guarantees the
  // argument block is exactly nKeys+nSigs+3 deep, so 1209-1210 cannot fire in
  // domain (one dummy always remains).
  const uint32_t depthAfter = nkeys + nsigs + 3u - popped;

  uint32_t pushed = 2u, finalDepth = 0u;
  if (!errored) {
    // 1211-1212: NULLDUMMY reads only the top item's size.
    if (nulldummy != 0u && dummylen != 0u) {
      err = NF_SIG_NULLDUMMY;
      errored = true;
    } else {
      // 1213: pop the extra item; 1215: push vchTrue / vchFalse.
      pushed = fs ? 1u : 0u;
      finalDepth = 1u;
    }
  }

  return cms_nf_pack(errored ? 0u : 1u, err, popped, firePos, ikey2Fire,
                     fireLen, depthAfter, dummylen != 0u, pushed, finalDepth,
                     fs ? 1u : 0u);
}
