// Wave-32 CHECKMULTISIG loop cell -- L leg (SCR-116, SCR-117).
//
// REVIEWED TRANSLITERATION of Bitcoin.Interpreter.Defs.cmsLoop
// (spec/core/Bitcoin/Interpreter/Defs.lean:672-700) together with
// checkSigEncoding (373-385) / checkPubKeyEncoding (398-411) called from the
// loop, and cmsCleanup (702-718) + the checkMultiSig tail (1107-1127).
//
// The loop is written as a while over Lean's (nSigs, nKeys) counters; the
// Lean equation recurses with nSigs' = if fOk then nSigs-1 else nSigs,
// nKeys' = nKeys-1, isig' = if fOk then isig+1 else isig, ikey' = ikey+1,
// then returns .ok false when nSigs' > nKeys'.  Identical control flow.
#include "e32_common.h"
#include "l_sigenc.h"
#include "twin_ops.h"

using namespace twinleaf;

E32INLINE uint64_t lean_cms_loop(uint64_t nKeys, uint64_t nSigs,
                                 uint64_t salt, uint64_t flags_raw) {
  const uint32_t flags = (uint32_t)flags_raw;
  if (nKeys > 20u || nSigs > nKeys)
    return e32_loop_out(3u, 0u, 0u, 0u, 0u, 0u, 0u, 0u);  // outside the cell domain

  const uint32_t nk0 = (uint32_t)nKeys;
  const uint32_t ns0 = (uint32_t)nSigs;
  uint32_t ikey = 2u;
  uint32_t isig = nk0 + 3u;
  int32_t nSigsLeft = (int32_t)ns0;
  int32_t nKeysLeft = (int32_t)nk0;
  bool fSuccess = true;
  TwinErr err = TWIN_OK;

  while (fSuccess && 0 < nSigsLeft) {
    E32Elem sig, pk;
    e32_stack_top(nk0, ns0, salt, (uint64_t)isig, sig);   // st[isig-1]!
    e32_stack_top(nk0, ns0, salt, (uint64_t)ikey, pk);    // st[ikey-1]!
    // match checkSigEncoding, checkPubKeyEncoding with
    //   | some e, _ => .error e
    //   | _, some e => .error e
    const TwinErr se = lean_sig_enc_err(sig, flags);
    if (se != TWIN_OK) { err = se; break; }
    const TwinErr pe = lean_pk_enc_err(pk, flags);
    if (pe != TWIN_OK) { err = pe; break; }
    // chk.base.checkECDSASignature sig pk scriptCode sv (shared predicate)
    const bool fOk = e32_check_pair(sig, pk, (uint32_t)salt);
    if (fOk) { isig = isig + 1u; nSigsLeft = nSigsLeft - 1; }
    ikey = ikey + 1u;
    nKeysLeft = nKeysLeft - 1;
    // if nSigs' > nKeys' then .ok false
    if (nSigsLeft > nKeysLeft) fSuccess = false;
  }

  if (err != TWIN_OK)
    return e32_loop_out(0u, (uint32_t)core_ord(err), 0u, 0u,
                        (uint32_t)nSigsLeft, (uint32_t)nKeysLeft, isig, ikey);

  // cmsCleanup (nullFail=false): pops i-1 = nKeys+nSigs+2 items; the dummy
  // is then the top item.  It is the empty element here, and NULLDUMMY is
  // off, so the gate passes and the dummy is popped.
  const bool early = (!fSuccess && nSigsLeft > 0);
  const bool verify_wire = (flags & E32_F_VERIFY_WIRE) != 0u;
  if (verify_wire) {
    if (fSuccess)
      return e32_loop_out(1u, 0u, 1u, 0u, 0u, (uint32_t)nKeysLeft, isig, ikey);
    return e32_loop_out(0u, (uint32_t)core_ord(TWIN_CHECKMULTISIGVERIFY),
                        0u, early ? 1u : 0u, (uint32_t)nSigsLeft,
                        (uint32_t)nKeysLeft, isig, ikey);
  }
  if (fSuccess)
    return e32_loop_out(1u, 0u, 1u, 0u, 0u, (uint32_t)nKeysLeft, isig, ikey);
  return e32_loop_out(0u, (uint32_t)core_ord(TWIN_EVAL_FALSE), 0u,
                      early ? 1u : 0u, (uint32_t)nSigsLeft,
                      (uint32_t)nKeysLeft, isig, ikey);
}

extern "C" uint64_t cell_cms_loop(uint64_t nKeys, uint64_t nSigs,
                                  uint64_t salt, uint64_t flags) {
  return lean_cms_loop(nKeys, nSigs, salt, flags);
}
