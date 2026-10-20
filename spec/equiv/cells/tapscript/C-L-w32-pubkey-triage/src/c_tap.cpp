// C leg of C-L-w32-pubkey-triage (SCR-158, SCR-159, SCR-160).
//
// Line-cited source slice of Bitcoin Core v32.99 pin cce32b168:
//   * script/interpreter.cpp:357-400  EvalChecksigTapscript
//   * script/interpreter.cpp:367      success = !sig.empty()
//   * script/interpreter.cpp:369-375  validation-weight decrement / error
//   * script/interpreter.cpp:377-392  pubkey-size triage
//   * script/interpreter.cpp:1726-1752 CheckSchnorrSignature (only the fact
//     that the 32-byte non-empty arm invokes it; its body is SCR-161/162 and
//     is abstracted as the shared boolean seam here)
//
// This is a bounded source slice, not the whole EvalScript.  `called` is
// cell-harness instrumentation of the call site (see spec.md).

#include "tap_common.h"

// Triage-specific observable:
//   bit 0       eval_ok (EvalChecksigTapscript returned true)
//   bits 1..6   error ordinal
//   bit 7       success (0 on error: Core's partially-written success is not
//               part of the contract observable; Lean's Except drops it)
//   bits 8..23  validation weight after the call (int16, two's complement)
//   bit 24      checker call site reached
TPINLINE uint64_t tp_pack_triage(uint32_t ok, uint32_t err, uint32_t success,
                                 int32_t weight, uint32_t called) {
  return (uint64_t)(ok & 1u)
       | ((uint64_t)(err & 0x3fu) << 1)
       | ((uint64_t)(success & 1u) << 7)
       | ((uint64_t)((uint32_t)weight & 0xffffu) << 8)
       | ((uint64_t)(called & 1u) << 24);
}

// EvalChecksigTapscript (interpreter.cpp:357-400).  `vw` is threaded both
// ways so the decrement is observable on every path; `called` records
// whether the 32-byte non-empty arm reaches the checker call.
TPINLINE bool core_eval_checksig_tapscript(uint64_t sig, uint64_t pk,
                                           int64_t &vw, bool discourage,
                                           bool &success, uint32_t &err,
                                           bool &called) {
  const uint32_t sig_len = tp_len(sig);
  const uint32_t pk_len = tp_len(pk);
  success = sig_len != 0;                          // 367
  if (success) {
    vw = vw - 50;                                  // 372 (in-place decrement)
    if (vw < 0) { err = TP_ERR_TAPSCRIPT_VALIDATION_WEIGHT; return false; } // 373-375
  }
  if (pk_len == 0) {                               // 377
    err = TP_ERR_TAPSCRIPT_EMPTY_PUBKEY;           // 378
    return false;
  } else if (pk_len == 32) {                       // 379
    if (success) {                                 // 380
      called = true;                               // harness call-site marker
      if (!btc_equiv_check_schnorr(sig, pk, 2u)) { // 380-382
        err = TP_ERR_SCHNORR_SIG;                  // 382
        return false;
      }
    }
  } else {                                         // 383-392
    if (discourage) {                              // 389
      err = TP_ERR_DISCOURAGE_UPGRADABLE_PUBKEYTYPE; // 390
      return false;
    }
  }
  return true;
}


// CScriptNum::serialize (script.h:335-365), bounded.
TPINLINE void core_serialize(int64_t value, uint64_t &out) {
  if (value == 0) { out = 0; return; }
  const bool neg = value < 0;
  const uint64_t a = neg ? (~(uint64_t)value + 1) : (uint64_t)value;
  uint32_t b0 = (uint32_t)(a & 0xffu), b1 = (uint32_t)((a >> 8) & 0xffu);
  uint32_t b2 = (uint32_t)((a >> 16) & 0xffu);
  uint32_t b3 = (uint32_t)((a >> 24) & 0xffu);
  uint32_t b4 = (uint32_t)((a >> 32) & 0xffu);
  uint32_t len = b4 ? 5 : b3 ? 4 : b2 ? 3 : b1 ? 2 : 1;
  const uint32_t mb = (len == 5) ? b4 : (len == 4) ? b3
                    : (len == 3) ? b2 : (len == 2) ? b1 : b0;
  if (mb & 0x80u) {
    if (len == 1) { b1 = neg ? 0x80u : 0u; len = 2; }
    else if (len == 2) { b2 = neg ? 0x80u : 0u; len = 3; }
    else if (len == 3) { b3 = neg ? 0x80u : 0u; len = 4; }
    else if (len == 4) { b4 = neg ? 0x80u : 0u; len = 5; }
  } else if (neg) {
    if (len == 1) b0 |= 0x80u; else if (len == 2) b1 |= 0x80u;
    else if (len == 3) b2 |= 0x80u; else if (len == 4) b3 |= 0x80u;
    else b4 |= 0x80u;
  }
  out = tp_mk(len, b0, b1, b2, b3, b4);
}

extern "C" uint64_t cell_triage(uint64_t sig, uint64_t pk,
                                uint32_t discourage, uint32_t vw_seed) {
  if (tp_len(sig) > 255u || tp_len(pk) > 255u || discourage > 1u ||
      vw_seed > 1023u)
    return tp_ood();
  int64_t vw = (int64_t)vw_seed - 100;   // domain [-100, 923]
  bool success = false;
  bool called = false;
  uint32_t err = 0;
  const bool ok = core_eval_checksig_tapscript(
      sig, pk, vw, discourage != 0u, success, err,
      called);
  if (!ok)
    return tp_pack_triage(0, err, 0, (int32_t)vw, called ? 1u : 0u);
  return tp_pack_triage(1, 0, success ? 1u : 0u, (int32_t)vw,
                        called ? 1u : 0u);
}

// SCR-160 continuation: CHECKSIGADD after a successful EvalChecksig return
// (interpreter.cpp:1112).  sig empty + 32-byte key -> success = false, so the
// pushed value is the num operand unchanged and the script continues.
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
  if (!core_eval_checksig_tapscript(sig, pk, vw, discourage != 0u,
                                    success, err, called))
    return tp_fail(err);
  uint64_t top;
  core_serialize((int64_t)num_byte + (success ? 1 : 0), top);
  return tp_pack(1, 0, 1, top);
}
