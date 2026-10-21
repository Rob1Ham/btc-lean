// E3 CHECKMULTISIG cell -- C leg (1-of-1 specialization).
//
// Line-cited transliteration of Bitcoin Core v32.99
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, src/script/interpreter.cpp
// OP_CHECKMULTISIG / OP_CHECKMULTISIGVERIFY (1115-1225), specialized to:
//   * base sigversion, flags = 0 (no NULLFAIL, no CONST_SCRIPTCODE,
//     NULLDUMMY off except in cell_cms_nulldummy);
//   * exactly one signature and one pubkey (nSigs = nKeys = 1);
//   * element length <= 1; stack depth 5 (or 0 for the underflow arm);
//   * no CODESEPARATOR, scriptCode passed explicitly.
// Stack layout (bottom -> top), exactly Core's:
//   [ dummy, sig, nSigs=1, pubkey, nKeys=1 ]
#include "e3_common.h"
#include "checker_abi.h"

static const uint32_t CMS_SIG = (1u << 16) | 0x41u;
static const uint32_t CMS_PK  = (1u << 16) | 0x02u;
static const uint32_t CMS_SC  = 0x4142u;

E3INLINE uint32_t core_cms_1of1(E3Stack& s, uint32_t wire, bool null_dummy) {
  if (s.n < 1) return 18;                          // 1122-1124 INVALID_STACK_OPERATION
  // nKeys = CScriptNum(stacktop(-1)).getint(); the witness fixes it to 1 (1130).
  if (s.n < 3) return 18;                          // ikey = 2, 1136-1138
  // nSigs = CScriptNum(stacktop(-3)).getint(); the witness fixes it to 1 (1140).
  if (s.n < 5) return 18;                          // i = 5, 1143-1145
  const uint32_t sig_enc = e3_enc(s, 1);           // stacktop(-4)
  const uint32_t pk_enc  = e3_enc(s, 3);           // stacktop(-2)
  const bool fSuccess =                            // CheckECDSASignature, 1179
      btc_equiv_check_sig(sig_enc, pk_enc, CMS_SC, 0u) != 0;
  // cmsLoop: one pair checked; nSigs'=0 <= nKeys'=0 so the loop exits.
  // Cleanup pops nKeys+nSigs+2 = 4 items (i-- > 1), leaving the dummy.
  s.n -= 4;                                        // 1197-1205
  if (s.n < 1) return 18;                          // 1211-1213
  if (null_dummy && s.len[s.n - 1] != 0) return 28; // 1212 SIG_NULLDUMMY
  s.n -= 1;                                        // popstack, 1214
  e3_push_bool(s, fSuccess);                       // 1216
  if (wire == 0xaf) {                              // OP_CHECKMULTISIGVERIFY
    if (fSuccess) s.n -= 1;                        // 1220
    else return 13;                                // 1222 SCRIPT_ERR_CHECKMULTISIGVERIFY
  }
  return 0;
}

E3INLINE uint64_t core_cms_closed(uint32_t wire, uint32_t stack_n,
                                  uint32_t dummy, bool null_dummy) {
  E3Stack s; e3_clear(s);
  if (stack_n == 5) {
    s.len[0] = e3_elen(dummy); s.val[0] = e3_eval(dummy);      // dummy
    s.len[1] = e3_elen(CMS_SIG); s.val[1] = e3_eval(CMS_SIG);  // sig
    s.len[2] = 1; s.val[2] = 1;                                // nSigs = OP_1
    s.len[3] = e3_elen(CMS_PK); s.val[3] = e3_eval(CMS_PK);    // pubkey
    s.len[4] = 1; s.val[4] = 1;                                // nKeys = OP_1
    s.n = 5;
  }
  const uint32_t e = core_cms_1of1(s, wire, null_dummy);
  if (e != 0) return e3_fail(e);
  if (wire == 0xaf) { s.len[s.n] = 1; s.val[s.n] = 1; s.n += 1; }
  return e3_finish(s, 0);
}

extern "C" uint64_t cell_cms() {
  return core_cms_closed(0xae, 5, 0x0u, false);
}
extern "C" uint64_t cell_cmsverify() {
  return core_cms_closed(0xaf, 5, 0x0u, false);
}
extern "C" uint64_t cell_cms_nulldummy() {
  return core_cms_closed(0xae, 5, (1u << 16) | 0x55u, true);
}
extern "C" uint64_t cell_cms_empty() {
  return core_cms_closed(0xae, 0, 0x0u, false);
}
