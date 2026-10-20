// L leg of C-L-w32-checksigadd.
//
// Reviewed transliteration of the Lean model at repo head
// 4d62a97e551082a69b13f495365bff0a903b0c99:
//   * spec/core/Bitcoin/Interpreter/Defs.lean:629-635   decodeNum
//   * spec/core/Bitcoin/Interpreter/Defs.lean:757-780   evalChecksigTapscript
//   * spec/core/Bitcoin/Interpreter/Defs.lean:803-815   checksigAddStep
//   * spec/core/Bitcoin/Interpreter/Defs.lean:1048-1059 CHECKSIGADD arm
//   * spec/core/Bitcoin/Numeric/Interface.lean:50-52   decodeScriptNum
//   * spec/core/Bitcoin/Numeric/Interface.lean:60-61   encodeScriptNum
//   * spec/core/Bitcoin/Numeric/ScriptNum.lean:385-389 encodeSignBE
//   * spec/core/Bitcoin/Numeric/ScriptNum.lean:449-453 setVchBE
//   * spec/core/Bitcoin/Numeric/ScriptNum.lean:493-500 minimalOkBE
//   * spec/core/Bitcoin/Numeric/ScriptNum.lean:628-631 decodeBE
//
// The Lean model uses ByteArray/List; this is a bounded, loop-free
// transliteration over the 5-byte cell ABI.  The equations are unchanged:
// bytesOf is little-endian wire order, decodeBE reverses it to big-endian.

#include "tap_common.h"

// minimalOkBE (ScriptNum.lean:493-500): on the big-endian list d0 :: t,
// d0 % 128 = 0 is rejected unless t is non-empty and its head has bit 7.
TPINLINE bool lean_minimal_ok_be(uint64_t e) {
  const uint32_t len = tp_len(e);
  if (len == 0) return true;
  const uint32_t d0 = tp_byte(e, len - 1);
  if ((d0 % 128u) == 0u) {
    if (len == 1) return false;
    return tp_byte(e, len - 2) >= 128u;
  }
  return true;
}

// setVchBE (ScriptNum.lean:449-453) over bytesOf e reversed.
TPINLINE int64_t lean_set_vch_be(uint64_t e) {
  const uint32_t len = tp_len(e);
  if (len == 0) return 0;
  const uint32_t d0 = tp_byte(e, len - 1);
  uint64_t mag;
  if (len == 1) {
    mag = (uint64_t)d0;
  } else if (len == 2) {
    mag = (uint64_t)d0 * 256u + (uint64_t)tp_byte(e, 0);
  } else if (len == 3) {
    mag = (uint64_t)d0 * 65536u + (uint64_t)tp_byte(e, 0)
        + (uint64_t)tp_byte(e, 1) * 256u;
  } else {
    mag = (uint64_t)d0 * 16777216u + (uint64_t)tp_byte(e, 0)
        + (uint64_t)tp_byte(e, 1) * 256u
        + (uint64_t)tp_byte(e, 2) * 65536u;
  }
  if (d0 < 128u) return (int64_t)mag;
  const uint64_t signbit = 128ULL << (8u * (len - 1));
  return -(int64_t)(mag - signbit);
}

// decodeBE (ScriptNum.lean:628-631) with maxSize = 4.
//   length > maxSize -> none; minimal && !minimalOkBE -> none;
//   otherwise some (setVchBE l).  none maps to ExecError.scriptNum.
TPINLINE bool lean_decode_num(uint64_t e, bool minimal, int64_t &out) {
  const uint32_t len = tp_len(e);
  if (len > 4u) return false;
  if (minimal && !lean_minimal_ok_be(e)) return false;
  out = lean_set_vch_be(e);
  return true;
}

// encodeSignBE (ScriptNum.lean:385-389) + bytesFromLE of the reverse
// (Interface.lean:60-61, scriptNumBE at ScriptNum.lean:534).
TPINLINE void lean_encode_num(int64_t v, uint64_t &out) {
  if (v == 0) { out = 0; return; }
  const bool neg = v < 0;
  const uint64_t a = neg ? (~(uint64_t)v + 1) : (uint64_t)v;
  const uint32_t b0 = (uint32_t)(a & 0xffu);
  const uint32_t b1 = (uint32_t)((a >> 8) & 0xffu);
  const uint32_t b2 = (uint32_t)((a >> 16) & 0xffu);
  const uint32_t b3 = (uint32_t)((a >> 24) & 0xffu);
  // magBE: big-endian digits without leading zeros, m in 1..4.
  uint32_t d0, d1, d2, d3, m;
  if (b3 != 0) { d0 = b3; d1 = b2; d2 = b1; d3 = b0; m = 4; }
  else if (b2 != 0) { d0 = b2; d1 = b1; d2 = b0; d3 = 0; m = 3; }
  else if (b1 != 0) { d0 = b1; d1 = b0; d2 = 0; d3 = 0; m = 2; }
  else { d0 = b0; d1 = 0; d2 = 0; d3 = 0; m = 1; }
  uint32_t o0 = 0, o1 = 0, o2 = 0, o3 = 0, o4 = 0;
  uint32_t out_len;
  const uint32_t pad = neg ? 0x80u : 0u;
  if (m == 1) {
    if (d0 < 128u) { o0 = neg ? d0 + 128u : d0; out_len = 1; }
    else { o0 = d0; o1 = pad; out_len = 2; }
  } else if (m == 2) {
    if (d0 < 128u) { o0 = d1; o1 = neg ? d0 + 128u : d0; out_len = 2; }
    else { o0 = d1; o1 = d0; o2 = pad; out_len = 3; }
  } else if (m == 3) {
    if (d0 < 128u) { o0 = d2; o1 = d1; o2 = neg ? d0 + 128u : d0; out_len = 3; }
    else { o0 = d2; o1 = d1; o2 = d0; o3 = pad; out_len = 4; }
  } else {
    if (d0 < 128u) { o0 = d3; o1 = d2; o2 = d1; o3 = neg ? d0 + 128u : d0; out_len = 4; }
    else { o0 = d3; o1 = d2; o2 = d1; o3 = d0; o4 = pad; out_len = 5; }
  }
  out = tp_mk(out_len, o0, o1, o2, o3, o4);
}

// evalChecksigTapscript (Defs.lean:757-780), boolean checker seam.
// Returns false with err set on .error; `vw` is the threaded budget.
TPINLINE bool lean_eval_checksig_tapscript(uint64_t sig, uint64_t pk,
                                           int64_t &vw, bool discourage,
                                           bool &success, uint32_t &err) {
  const uint32_t sig_len = tp_len(sig);
  const uint32_t pk_len = tp_len(pk);
  success = sig_len != 0;
  if (success) {
    const int64_t vw2 = vw - 50;
    if (vw2 < 0) { err = TP_ERR_TAPSCRIPT_VALIDATION_WEIGHT; return false; }
    vw = vw2;
    if (pk_len == 0) { err = TP_ERR_TAPSCRIPT_EMPTY_PUBKEY; return false; }
    if (pk_len == 32) {
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

// CHECKSIGADD arm (Defs.lean:1048-1059) + checksigAddStep (803-815).
TPINLINE uint64_t lean_checksigadd(uint32_t sv, uint32_t depth,
                                   uint64_t sig, uint64_t num, uint64_t pk,
                                   bool require_minimal, bool discourage,
                                   int64_t vw) {
  if (sv == 0u || sv == 1u) return tp_fail(TP_ERR_BAD_OPCODE);  // 1050
  if (sv != 2u) return tp_ood();
  if (depth < 3u) return tp_fail(TP_ERR_INVALID_STACK_OPERATION); // 1051
  int64_t n;
  if (!lean_decode_num(num, require_minimal, n))
    return tp_fail(TP_ERR_SCRIPTNUM);                            // checksigAddStep
  bool success = false;
  uint32_t err = 0;
  if (!lean_eval_checksig_tapscript(sig, pk, vw, discourage, success, err))
    return tp_fail(err);
  const int64_t r = n + (success ? 1 : 0);                       // 1059
  uint64_t top;
  lean_encode_num(r, top);                                       // encodeScriptNum r false
  return tp_pack(1, 0, depth - 2u, top);
}

// --- entry points ---------------------------------------------------------

extern "C" uint64_t cell_add_dispatch(uint32_t sv, uint32_t depth) {
  if (sv > 2u || depth > TP_MAX_DEPTH) return tp_ood();
  return lean_checksigadd(sv, depth, tp_mk(0, 0, 0, 0, 0, 0),
                          tp_mk(1, 2, 0, 0, 0, 0),
                          tp_mk(32, 0, 0, 0, 0, 0), true, false, 100);
}

extern "C" uint64_t cell_add_num(uint64_t num, uint64_t sig, uint64_t pk,
                                 uint32_t depth, uint32_t minimal,
                                 uint32_t discourage, uint32_t vw_seed) {
  if (tp_len(num) > TP_MAX_LEN || tp_len(sig) > 255u ||
      tp_len(pk) > 255u || depth > TP_MAX_DEPTH || minimal > 1u ||
      discourage > 1u || vw_seed > 1023u)
    return tp_ood();
  const int64_t vw = (int64_t)vw_seed - 100;
  return lean_checksigadd(2u, depth, sig, num, pk, minimal != 0u,
                          discourage != 0u, vw);
}
