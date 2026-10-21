// Wave-32 CHECKMULTISIG loop cell -- C leg (SCR-116, SCR-117).
//
// Line-cited slice of Bitcoin Core v32.99
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
// src/script/interpreter.cpp OP_CHECKMULTISIG (1160-1225), starting after
// the argument prelude (that prelude is the SCR-114 cell):
//
//   bool fSuccess = true;
//   while (fSuccess && nSigsCount > 0) {
//       vchSig    = stacktop(-isig);
//       vchPubKey = stacktop(-ikey);
//       if (!CheckSignatureEncoding(...) || !CheckPubKeyEncoding(...))
//           return false;                      // 1171-1174
//       fOk = checker.CheckECDSASignature(...); // 1177
//       if (fOk) { isig++; nSigsCount--; }
//       ikey++; nKeysCount--;
//       if (nSigsCount > nKeysCount) fSuccess = false;
//   }
//   cleanup pops i-1 items (1194-1205)
//   dummy pop, NULLDUMMY (1209-1213; dummy is empty here)
//   push fSuccess; CMSVERIFY ordinal 13 on false (1215-1223)
//
// Domain (checked by the cell): 0 <= nSigs <= nKeys <= 20, base-shaped
// stack of exactly nKeys+nSigs+3 elements.  The ECDSA verdict is a concrete
// deterministic predicate shared by both legs (e32_check_pair), so this cell
// proves loop order and encoding precedence, not crypto.
#include "e32_common.h"
#include "c_sigenc.h"

E32INLINE uint64_t core_cms_loop(uint64_t nKeys, uint64_t nSigs, uint64_t salt,
                                 uint64_t flags_raw) {
  const uint32_t flags = (uint32_t)flags_raw;
  if (nKeys > 20u || nSigs > nKeys)
    return e32_loop_out(3u, 0u, 0u, 0u, 0u, 0u, 0u, 0u);  // outside the cell domain

  const uint32_t nk0 = (uint32_t)nKeys;
  const uint32_t ns0 = (uint32_t)nSigs;
  uint32_t ikey = 2u;                    // ikey = ++i after nKeys (1139)
  uint32_t isig = nk0 + 3u;              // isig = ++i after nSigs (1146)
  int32_t nSigsLeft = (int32_t)ns0;
  int32_t nKeysLeft = (int32_t)nk0;
  bool fSuccess = true;
  bool early = false;
  uint32_t err = 0u;

  while (fSuccess && nSigsLeft > 0) {
    E32Elem sig, pk;
    e32_stack_top(nk0, ns0, salt, (uint64_t)isig, sig);   // stacktop(-isig)
    e32_stack_top(nk0, ns0, salt, (uint64_t)ikey, pk);    // stacktop(-ikey)
    // 1171-1174: signature encoding first, then pubkey encoding.
    const uint32_t se = core_sig_enc_err(sig, flags);
    if (se != 0u) { err = se; break; }
    const uint32_t pe = core_pk_enc_err(pk, flags);
    if (pe != 0u) { err = pe; break; }
    // 1177: shared concrete checker (see e32_common.h).
    const bool fOk = e32_check_pair(sig, pk, (uint32_t)salt);
    if (fOk) { isig += 1u; nSigsLeft -= 1; }
    ikey += 1u;
    nKeysLeft -= 1;
    // 1186-1188: too many failed signatures -> early exit.
    if (nSigsLeft > nKeysLeft) fSuccess = false;
  }

  if (err != 0u)
    return e32_loop_out(0u, err, 0u, 0u, (uint32_t)nSigsLeft,
                        (uint32_t)nKeysLeft, isig, ikey);

  early = (!fSuccess && nSigsLeft > 0);
  const bool verify_wire = (flags & E32_F_VERIFY_WIRE) != 0u;
  if (verify_wire) {
    if (fSuccess)
      return e32_loop_out(1u, 0u, 1u, 0u, 0u, (uint32_t)nKeysLeft, isig, ikey);
    return e32_loop_out(0u, EQUIV_ERR_CHECKMULTISIGVERIFY, 0u, early ? 1u : 0u,
                        (uint32_t)nSigsLeft, (uint32_t)nKeysLeft, isig, ikey);
  }
  if (fSuccess)
    return e32_loop_out(1u, 0u, 1u, 0u, 0u, (uint32_t)nKeysLeft, isig, ikey);
  return e32_loop_out(0u, EQUIV_ERR_EVAL_FALSE, 0u, early ? 1u : 0u,
                      (uint32_t)nSigsLeft, (uint32_t)nKeysLeft, isig, ikey);
}

extern "C" uint64_t cell_cms_loop(uint64_t nKeys, uint64_t nSigs,
                                  uint64_t salt, uint64_t flags) {
  return core_cms_loop(nKeys, nSigs, salt, flags);
}
