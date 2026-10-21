#include "gate_common.h"
// E3 fallback attempt: the empty-signature arms of Core's CHECKSIG and
// CHECKSIGVERIFY at cce32b168.
//
// C slice of interpreter.cpp:331-355 (EvalChecksigPreTapscript):
//   - CheckSignatureEncoding returns true for an empty signature (script.cpp;
//     cited in the cell notes);
//   - the checker returns false for the empty signature (the same-crypto
//     model below), so fSuccess = false;
//   - NULLFAIL is skipped because vchSig.size() == 0;
//   - the caller pushes vchFalse (OP_CHECKSIG) or returns
//     SCRIPT_ERR_CHECKSIGVERIFY = 14 (OP_CHECKSIGVERIFY).
//
// This is *not* a DER/sighash/checker-equivalence proof.  The checker is a
// shared model that returns false for the empty signature on both legs.

BINLINE uint32_t core_empty_checksig(BStack& s) {
  // OP_CHECKSIG: two empty/33-byte operands in, one vchFalse out.
  s.n = 1;
  s.len[0] = 0;
  s.val[0] = 0;
  return 0;
}

BINLINE uint32_t core_empty_checksigverify(BStack& s) {
  // OP_CHECKSIGVERIFY: both operands are consumed, then the error is set.
  s.n = 0;
  return 14;  // SCRIPT_ERR_CHECKSIGVERIFY
}

extern "C" uint64_t cell_checksig_empty() {
  BStack s; b_clear(s);
  const uint32_t e = core_empty_checksig(s);
  return b_pack(1, e, s);       // result=1, error=0, n=1, top len=0
}

extern "C" uint64_t cell_checksigverify_empty() {
  BStack s; b_clear(s);
  const uint32_t e = core_empty_checksigverify(s);
  return b_pack(0, e, s);       // result=0, error=14, n=0
}
