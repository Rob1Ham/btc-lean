// C leg -- SCR-115: all nSigsCount signatures are FindAndDelete'd from the
// scriptCode before any checker call, in BASE only.
//
// Line-cited slice of Bitcoin Core v32.99 interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66:
//   1152       CScript scriptCode(pbegincodehash, pend);
//   1154-1160  for (int k = 0; k < nSigsCount; k++) {
//                valtype& vchSig = stacktop(-isig-k);
//                if (sigversion == SigVersion::BASE) {
//                  int found = FindAndDelete(scriptCode, CScript() << vchSig);
//                  if (found > 0 && (flags & SCRIPT_VERIFY_CONST_SCRIPTCODE))
//                    return set_error(serror, SCRIPT_ERR_SIG_FINDANDDELETE);
//                }
//              }
//   1163-1189  the verification loop (pairs from SCR-116)
//
// Observable: the deletion fold's result, how many deletions ran, whether the
// CONST_SCRIPTCODE latch fired, and the scriptCode *seen by each checker
// call* -- so a leg that deletes lazily (between or after checks) cannot
// agree with one that deletes up front.  The cell's checker calls use the
// same scriptCode variable the fold mutates; `c0_eq_final`/`c1_eq_c0` are
// computed from that variable, not from a fresh copy.
//
// SCOPE / SAME-SYMBOL PREMISE: FindAndDelete itself is an abstract seam
// symbol shared by both legs (Alive2 quantifies over it, SAW links one concrete
// stub).  The byte-walking deletion algorithm is NOT proved here -- it is the
// subject of SCR-098/INV-056.  What this cell proves is the fold's order, the
// BASE-only gate, the per-signature found>0 latch and the scriptCode handed to
// every checker call.  Hence scr_row_coverage: partial.
//
// Bound: nSigs <= 2 and the loop unrolls 2 pairs (the row allows up to 20).
// nKeys = nSigs so every signature has a pair to verify.  Out-of-domain
// inputs return 0xFFFF in both legs (harness guard, not engine code).
#include <cstdint>
#include "cms_obs.h"
#include "cms_seam.h"

#define SIG_ENC(k) ((1u << 16) | (0x40u + (k)))
#define KEY_ENC(j) ((1u << 16) | (0x40u + (j)))
// CScript() << vchSig for a one-byte signature: 0x01 <byte>.
#define PUSH_ENC(k) ((1u << 16) | (0x01u << 8) | (0x11u + (k)))

#define CMS_FAD_STEP(k)                                                    \
  if (!errored && base && (uint32_t)(k) < nsigs) {                        \
    const uint64_t r = btc_equiv_find_and_delete(cur, PUSH_ENC(k));         \
    const uint32_t found = (uint32_t)(r & 0xffffffffu);                     \
    cur = (uint32_t)(r >> 32);                                              \
    applied += 1u;                                                          \
    if (found > 0u) {                                                       \
      foundpos += 1u;                                                       \
      if (constflag != 0u) {                                                \
        err = 54u;                                                          \
        errored = true;                                                     \
      }                                                                     \
    }                                                                       \
  }

// One verification-loop body (the loop itself is SCR-116's row; here it is
// the probe).  The checker is called with `cur`, the same variable the fold
// mutated.
#define CMS_PROBE_STEP(t)                                                  \
  if (!errored && fs && nSigsLeft > 0) {                                    \
    if (calls == 0u) { c0_eq_final = (cur == finalSc); }                    \
    if (calls == 1u) { c1_eq_c0 = (cur == c0Sc); }                          \
    if (calls == 0u) { c0Sc = cur; }                                        \
    calls += 1u;                                                            \
    const bool ok = btc_equiv_check_sig(SIG_ENC(sigId), KEY_ENC(t), cur,   \
                                         sigversion) != 0;                  \
    if (ok) { sigId += 1; nSigsLeft -= 1; }                                 \
    nKeysLeft -= 1;                                                         \
    if (nSigsLeft > nKeysLeft) fs = false;                                  \
  }

extern "C" uint64_t cell_cms_fad(uint32_t nsigs, uint32_t sigversion,
                                 uint32_t constflag, uint32_t sc) {
  if (nsigs > 2u || sigversion > 1u || constflag > 1u) return 0xFFFFu;

  const bool base = (sigversion == 0u);
  uint32_t cur = sc;
  uint32_t applied = 0u, foundpos = 0u, err = 0u, calls = 0u;
  uint32_t c0Sc = 0u, c1Sc = 0u;
  uint32_t c0_eq_final = 0u, c1_eq_c0 = 0u;
  bool errored = false, fs = true;
  int64_t nSigsLeft = (int64_t)nsigs, nKeysLeft = (int64_t)nsigs;
  int64_t sigId = 0;

  // The fold as Core writes it: after nsigs is decoded (line 1141) and before
  // the loop (1163).  All the deletions happen here, not inside the loop.
  CMS_FAD_STEP(0u)
  CMS_FAD_STEP(1u)
  const uint32_t finalSc = cur;

  CMS_PROBE_STEP(0u)
  CMS_PROBE_STEP(1u)

  uint32_t res;
  if (errored) {
    res = 3u;
  } else {
    res = fs ? 1u : 0u;
  }
  (void)c1Sc;
  return cms_pack_fad(res, err, calls, applied, finalSc, c0_eq_final, c1_eq_c0,
                      foundpos, base ? 1u : 0u);
}
