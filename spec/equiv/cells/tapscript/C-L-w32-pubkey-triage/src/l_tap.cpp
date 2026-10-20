// L leg of C-L-w32-pubkey-triage (SCR-158, SCR-159, SCR-160).
//
// Reviewed transliteration of the Lean model at repo head
// 4d62a97e551082a69b13f495365bff0a903b0c99:
//   * spec/core/Bitcoin/Interpreter/Defs.lean:757-780 evalChecksigTapscript
//   * spec/core/Bitcoin/Interpreter/Defs.lean:261-267 checkSchnorrWithContext
//     (with checkSchnorrTyped = none: the abstract boolean seam)
//   * spec/core/Bitcoin/Interpreter/Defs.lean:91  VALIDATION_WEIGHT_PER_SIGOP_PASSED
//
// `called` and the error-path weight are cell-harness threading: the Lean
// `Except` value drops the machine state and the boolean seam has no call
// marker, so this transliteration records the call site and the weight
// before the error is returned.  The equations themselves are unchanged.

#include "tap_common.h"

TPINLINE uint64_t tp_pack_triage(uint32_t ok, uint32_t err, uint32_t success,
                                 int32_t weight, uint32_t called) {
  return (uint64_t)(ok & 1u)
       | ((uint64_t)(err & 0x3fu) << 1)
       | ((uint64_t)(success & 1u) << 7)
       | ((uint64_t)((uint32_t)weight & 0xffffu) << 8)
       | ((uint64_t)(called & 1u) << 24);
}

// evalChecksigTapscript (Defs.lean:757-780), boolean checker seam.
TPINLINE bool lean_eval_checksig_tapscript(uint64_t sig, uint64_t pk,
                                           int64_t &vw, bool discourage,
                                           bool &success, uint32_t &err,
                                           bool &called) {
  const uint32_t sig_len = tp_len(sig);
  const uint32_t pk_len = tp_len(pk);
  success = sig_len != 0;
  if (success) {
    vw = vw - 50;                 // Defs.lean: vw' = vw.getD 0 - 50
    if (vw < 0) { err = TP_ERR_TAPSCRIPT_VALIDATION_WEIGHT; return false; }
    if (pk_len == 0) { err = TP_ERR_TAPSCRIPT_EMPTY_PUBKEY; return false; }
    if (pk_len == 32) {
      called = true;                       // call site of checkSchnorrWithContext
      if (!btc_equiv_check_schnorr(sig, pk, 2u)) {
        err = TP_ERR_SCHNORR_SIG;
        return false;
      }
      success = true;
      return true;
    }
    if (discourage) { err = TP_ERR_DISCOURAGE_UPGRADABLE_PUBKEYTYPE; return false; }
    success = true;
    return true;
  } else {
    if (pk_len == 0) { err = TP_ERR_TAPSCRIPT_EMPTY_PUBKEY; return false; }
    if (pk_len == 32) { success = false; return true; }
    if (discourage) { err = TP_ERR_DISCOURAGE_UPGRADABLE_PUBKEYTYPE; return false; }
    success = false;
    return true;
  }
}


// scriptNumBE (ScriptNum.lean:534) + encodeSignBE (385-389) + bytesFromLE
// (Interface.lean:60-61), bounded.
TPINLINE void lean_encode_num(int64_t v, uint64_t &out) {
  if (v == 0) { out = 0; return; }
  const bool neg = v < 0;
  const uint64_t a = neg ? (~(uint64_t)v + 1) : (uint64_t)v;
  const uint32_t b0 = (uint32_t)(a & 0xffu), b1 = (uint32_t)((a >> 8) & 0xffu);
  const uint32_t b2 = (uint32_t)((a >> 16) & 0xffu);
  const uint32_t b3 = (uint32_t)((a >> 24) & 0xffu);
  uint32_t d0, d1, d2, d3, m;
  if (b3) { d0=b3; d1=b2; d2=b1; d3=b0; m=4; }
  else if (b2) { d0=b2; d1=b1; d2=b0; d3=0; m=3; }
  else if (b1) { d0=b1; d1=b0; d2=0; d3=0; m=2; }
  else { d0=b0; d1=0; d2=0; d3=0; m=1; }
  uint32_t o0=0,o1=0,o2=0,o3=0,o4=0,len;
  const uint32_t pad = neg ? 0x80u : 0u;
  if (m == 1) {
    if (d0 < 128u) { o0 = neg ? d0+128u : d0; len=1; }
    else { o0=d0; o1=pad; len=2; }
  } else if (m == 2) {
    if (d0 < 128u) { o0=d1; o1=neg?d0+128u:d0; len=2; }
    else { o0=d1; o1=d0; o2=pad; len=3; }
  } else if (m == 3) {
    if (d0 < 128u) { o0=d2; o1=d1; o2=neg?d0+128u:d0; len=3; }
    else { o0=d2; o1=d1; o2=d0; o3=pad; len=4; }
  } else {
    if (d0 < 128u) { o0=d3; o1=d2; o2=d1; o3=neg?d0+128u:d0; len=4; }
    else { o0=d3; o1=d2; o2=d1; o3=d0; o4=pad; len=5; }
  }
  out = tp_mk(len, o0, o1, o2, o3, o4);
}

extern "C" uint64_t cell_triage(uint64_t sig, uint64_t pk,
                                uint32_t discourage, uint32_t vw_seed) {
  if (tp_len(sig) > 255u || tp_len(pk) > 255u || discourage > 1u ||
      vw_seed > 1023u)
    return tp_ood();
  int64_t vw = (int64_t)vw_seed - 100;
  bool success = false;
  bool called = false;
  uint32_t err = 0;
  const bool ok = lean_eval_checksig_tapscript(
      sig, pk, vw, discourage != 0u, success, err, called);
  if (!ok)
    return tp_pack_triage(0, err, 0, (int32_t)vw, called ? 1u : 0u);
  return tp_pack_triage(1, 0, success ? 1u : 0u, (int32_t)vw,
                        called ? 1u : 0u);
}

// SCR-160 continuation: CHECKSIGADD after a successful EvalChecksig return
// (Defs.lean:1059, encodeScriptNum r false).
extern "C" uint64_t cell_triage_continue(uint64_t sig, uint64_t pk,
                                         uint32_t num_byte,
                                         uint32_t discourage,
                                         uint32_t vw_seed) {
  if (tp_len(sig) > 255u || tp_len(pk) > 255u || num_byte > 255u ||
      discourage > 1u || vw_seed > 1023u)
    return tp_ood();
  int64_t vw = (int64_t)vw_seed - 100;
  bool success = false, called = false;
  uint32_t err = 0;
  if (!lean_eval_checksig_tapscript(sig, pk, vw, discourage != 0u,
                                    success, err, called))
    return tp_fail(err);
  uint64_t top;
  lean_encode_num((int64_t)num_byte + (success ? 1 : 0), top);
  return tp_pack(1, 0, 1, top);
}
