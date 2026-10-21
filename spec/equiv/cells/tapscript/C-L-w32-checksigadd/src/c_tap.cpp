// C leg of C-L-w32-checksigadd.
//
// Line-cited source slice of Bitcoin Core v32.99 pin cce32b168:
//   * script/interpreter.cpp:1094-1113  case OP_CHECKSIGADD
//   * script/interpreter.cpp:357-400    EvalChecksigTapscript
//   * script/interpreter.cpp:437-442    fRequireMinimal
//   * script/interpreter.cpp:1236-1240  scriptnum_error -> SCRIPT_ERR_SCRIPTNUM
//   * script/script.h:246-271           CScriptNum ctor (width + minimality)
//   * script/script.h:335-365           CScriptNum::serialize (getvch)
//   * script/script.h:376-391           CScriptNum::set_vch
//
// The only changes from the source are bounded, loop-free transliterations
// of the variable-length ScriptNum helpers for the declared 5-byte domain.
// This is a bounded source slice, not the whole EvalScript.

#include "tap_common.h"

// CScriptNum::set_vch (script.h:376-391), bounded len <= 4.
TPINLINE bool core_set_vch(uint64_t e, int64_t &out) {
  const uint32_t len = tp_len(e);
  if (len == 0) { out = 0; return true; }
  uint64_t r = 0;
  if (len > 0) r |= (uint64_t)tp_byte(e, 0);
  if (len > 1) r |= (uint64_t)tp_byte(e, 1) << 8;
  if (len > 2) r |= (uint64_t)tp_byte(e, 2) << 16;
  if (len > 3) r |= (uint64_t)tp_byte(e, 3) << 24;
  const uint32_t msb = tp_byte(e, len - 1);
  if (msb & 0x80u) {
    const uint64_t mask = ~(0x80ULL << (8u * (len - 1)));
    out = -(int64_t)(r & mask);
  } else {
    out = (int64_t)r;
  }
  return true;
}

// CScriptNum ctor (script.h:246-271) with nMaxNumSize = 4, plus the
// EvalScript catch (interpreter.cpp:1236-1240) mapping a throw to
// SCRIPT_ERR_SCRIPTNUM (4).  false = throw.
TPINLINE bool core_decode_num(uint64_t e, bool require_minimal, int64_t &out) {
  const uint32_t len = tp_len(e);
  if (len > 4) return false;                       // script.h:249-251
  if (require_minimal && len > 0) {                // script.h:252
    const uint32_t msb = tp_byte(e, len - 1);
    if ((msb & 0x7fu) == 0) {
      if (len <= 1) return false;
      const uint32_t second = tp_byte(e, len - 2);
      if ((second & 0x80u) == 0) return false;
    }
  }
  return core_set_vch(e, out);
}

// CScriptNum::serialize (script.h:335-365), bounded to the values the
// 4-byte ctor plus one can produce.  getvch() == serialize(m_value).
TPINLINE void core_serialize(int64_t value, uint64_t &out) {
  if (value == 0) { out = 0; return; }
  const bool neg = value < 0;
  const uint64_t a = neg ? (~(uint64_t)value + 1) : (uint64_t)value;
  uint32_t b0 = (uint32_t)(a & 0xffu);
  uint32_t b1 = (uint32_t)((a >> 8) & 0xffu);
  uint32_t b2 = (uint32_t)((a >> 16) & 0xffu);
  uint32_t b3 = (uint32_t)((a >> 24) & 0xffu);
  uint32_t b4 = (uint32_t)((a >> 32) & 0xffu);
  uint32_t len;
  if (b4 != 0) len = 5;
  else if (b3 != 0) len = 4;
  else if (b2 != 0) len = 3;
  else if (b1 != 0) len = 2;
  else len = 1;
  const uint32_t mb = (len == 5) ? b4 : (len == 4) ? b3
                    : (len == 3) ? b2 : (len == 2) ? b1 : b0;
  if (mb & 0x80u) {
    if (len == 1) { b1 = neg ? 0x80u : 0u; len = 2; }
    else if (len == 2) { b2 = neg ? 0x80u : 0u; len = 3; }
    else if (len == 3) { b3 = neg ? 0x80u : 0u; len = 4; }
    else if (len == 4) { b4 = neg ? 0x80u : 0u; len = 5; }
    // len == 5 is unreachable for |value| <= 2^31 + 1.
  } else if (neg) {
    if (len == 1) b0 |= 0x80u;
    else if (len == 2) b1 |= 0x80u;
    else if (len == 3) b2 |= 0x80u;
    else if (len == 4) b3 |= 0x80u;
    else b4 |= 0x80u;
  }
  out = tp_mk(len, b0, b1, b2, b3, b4);
}

// EvalChecksigTapscript (interpreter.cpp:357-400) for the abstract boolean
// checker seam.  Core mutates execdata.m_validation_weight_left in place;
// this slice threads `vw` in/out so the decrement is observable even on the
// error paths (the cell-harness addition is recorded in spec.md).
TPINLINE bool core_eval_checksig_tapscript(uint64_t sig, uint64_t pk,
                                           int64_t &vw, bool discourage,
                                           bool &success, uint32_t &err) {
  const uint32_t sig_len = tp_len(sig);
  const uint32_t pk_len = tp_len(pk);
  success = sig_len != 0;                          // 367
  if (success) {
    const int64_t vw2 = vw - 50;                   // 372, VALIDATION_WEIGHT_PER_SIGOP_PASSED
    if (vw2 < 0) { err = TP_ERR_TAPSCRIPT_VALIDATION_WEIGHT; return false; } // 373-375
    vw = vw2;
  }
  if (pk_len == 0) {                               // 377
    err = TP_ERR_TAPSCRIPT_EMPTY_PUBKEY;           // 378
    return false;
  } else if (pk_len == 32) {                       // 379
    if (success && !btc_equiv_check_schnorr(sig, pk, 2u)) { // 380-382
      err = TP_ERR_SCHNORR_SIG;                    // 382 serror set by checker
      return false;
    }
  } else {                                         // 383-392
    if (discourage) {                              // 389
      err = TP_ERR_DISCOURAGE_UPGRADABLE_PUBKEYTYPE; // 390
      return false;
    }
  }
  return true;
}

// OP_CHECKSIGADD (interpreter.cpp:1094-1113): tapscript-only, arity 3,
// num parsed first, then EvalChecksig, pop 3, push num + (success ? 1 : 0).
TPINLINE uint64_t core_checksigadd(uint32_t sv, uint32_t depth,
                                   uint64_t sig, uint64_t num, uint64_t pk,
                                   bool require_minimal, bool discourage,
                                   int64_t vw) {
  // 1096-1097: only BASE/WITNESS_V0 are rejected; TAPSCRIPT continues.
  // TAPROOT is unreachable for a script path and is outside the domain.
  if (sv == 0u || sv == 1u) return tp_fail(TP_ERR_BAD_OPCODE);
  if (sv != 2u) return tp_ood();
  if (depth < 3u) return tp_fail(TP_ERR_INVALID_STACK_OPERATION); // 1100-1101
  int64_t n;
  if (!core_decode_num(num, require_minimal, n))                  // 1103
    return tp_fail(TP_ERR_SCRIPTNUM);                             // 1236-1240
  bool success = false;
  uint32_t err = 0;
  if (!core_eval_checksig_tapscript(sig, pk, vw, discourage, success, err))
    return tp_fail(err);
  const int64_t r = n + (success ? 1 : 0);                        // 1112
  uint64_t top;
  core_serialize(r, top);
  return tp_pack(1, 0, depth - 2u, top);                          // pop 3, push 1
}

// --- entry points ---------------------------------------------------------

// sv in {0,1,2}, depth in 0..TP_MAX_DEPTH.  Exercises the BAD_OPCODE gate
// for both pre-tapscript sigversions and the arity check for tapscript.
extern "C" uint64_t cell_add_dispatch(uint32_t sv, uint32_t depth) {
  if (sv > 2u || depth > TP_MAX_DEPTH) return tp_ood();
  // Closed operands: empty signature, num = 2, 32-byte key.
  return core_checksigadd(sv, depth, tp_mk(0, 0, 0, 0, 0, 0),
                          tp_mk(1, 2, 0, 0, 0, 0),
                          tp_mk(32, 0, 0, 0, 0, 0), true, false, 100);
}

// Symbolic num (len 0..5, bytes arbitrary), sig len 0..255, pk len 0..255,
// MINIMALDATA flag, DISCOURAGE_UPGRADABLE_PUBKEYTYPE flag, validation
// weight seed.  Covers SCR-156's stack effect for every success value and
// every legal num value, and SCR-157's parse rule.
extern "C" uint64_t cell_add_num(uint64_t num, uint64_t sig, uint64_t pk,
                                 uint32_t depth, uint32_t minimal,
                                 uint32_t discourage, uint32_t vw_seed) {
  if (tp_len(num) > TP_MAX_LEN || tp_len(sig) > 255u ||
      tp_len(pk) > 255u || depth > TP_MAX_DEPTH || minimal > 1u ||
      discourage > 1u || vw_seed > 1023u)
    return tp_ood();
  const int64_t vw = (int64_t)vw_seed - 100;   // domain [-100, 923]
  return core_checksigadd(2u, depth, sig, num, pk, minimal != 0u,
                          discourage != 0u, vw);
}
