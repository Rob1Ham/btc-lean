// E3 CHECKSIG cell -- C leg.
//
// Line-cited transliteration of Bitcoin Core v32.99
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, src/script/interpreter.cpp.
// This is a bounded source slice, not the whole EvalScript.
//
// Closed witnesses: the stack bytes are fixed, and the ONLY nondeterminism
// is the return value of the shared external checker.  Alive2 therefore
// quantifies over "same checker, any verdict"; the SAW lane pins that return
// to 0 and 1 in two builds.
#include "e3_common.h"
#include "checker_abi.h"

static const uint32_t CS_SIG = (1u << 16) | 0x41u;   // <0x41>
static const uint32_t CS_PK  = (1u << 16) | 0x02u;   // <0x02>
static const uint32_t CS_SC  = 0x4142u;              // 2-byte scriptCode, B0 'A', B1 'B'

// EvalChecksigPreTapscript (331-369) under the cell domain:
//   * SigVersion::BASE; flags = 0, hence the CONST_SCRIPTCODE FindAndDelete
//     arm (339-343), CheckSignatureEncoding (347) and CheckPubKeyEncoding
//     (347) all pass in this cell;
//   * the NULLFAIL arm (351-352) is off because SCRIPT_VERIFY_NULLFAIL is
//     not set;
//   * scriptCode is passed explicitly (no CODESEPARATOR in the witness).
// fSuccess = checker.CheckECDSASignature(vchSig, vchPubKey, scriptCode,
//             sigversion)                                            (349)
// is the single shared external call.
E3INLINE uint32_t core_eval_checksig(const E3Stack& s) {
  const uint32_t sig_enc = e3_enc(s, s.n - 2);   // stacktop(-2), 1076
  const uint32_t pk_enc  = e3_enc(s, s.n - 1);   // stacktop(-1), 1077
  const uint8_t ok = btc_equiv_check_sig(sig_enc, pk_enc, CS_SC, 0u);
  return ok != 0;
}

// OP_CHECKSIG / OP_CHECKSIGVERIFY (1069-1092).
// Returns 0 on success, else the Core ScriptError ordinal used by the cell
// contract (14 = EQUIV_ERR_CHECKSIGVERIFY, 18 =
// EQUIV_ERR_INVALID_STACK_OPERATION).  On a CHECKSIGVERIFY failure the stack
// still carries the pushed vchFalse, as Core's pop-pop-push-then-error does.
E3INLINE uint32_t core_checksig(E3Stack& s, uint32_t wire) {
  if (s.n < 2) return 18;                        // 1073-1074
  const bool fSuccess = core_eval_checksig(s);
  s.n -= 2;                                      // popstack x2, 1080-1081
  e3_push_bool(s, fSuccess);                     // 1082
  if (wire == 0xad) {                            // OP_CHECKSIGVERIFY
    if (fSuccess) s.n -= 1;                      // 1086 popstack
    else return 14;                              // 1088 SCRIPT_ERR_CHECKSIGVERIFY
  }
  return 0;
}

E3INLINE uint64_t core_closed(uint32_t wire, uint32_t stack_n) {
  E3Stack s; e3_clear(s);
  s.len[0] = e3_elen(CS_SIG); s.val[0] = e3_eval(CS_SIG); s.n = 1;
  if (stack_n >= 2) {
    s.len[1] = e3_elen(CS_PK); s.val[1] = e3_eval(CS_PK); s.n = 2;
  }
  const uint32_t e = core_checksig(s, wire);
  if (e != 0) return e3_fail(e);
  // Harness continuation: a successful CHECKSIGVERIFY has popped both
  // operands and the verdict, so the standard form is `... CHECKSIGVERIFY OP_1`.
  if (wire == 0xad) { s.len[s.n] = 1; s.val[s.n] = 1; s.n += 1; }
  return e3_finish(s, 0);
}

// (sig pubkey -- true/false) then script finish.
extern "C" uint64_t cell_checksig() { return core_closed(0xac, 2); }
// (sig pubkey -- ) on success, SCRIPT_ERR_CHECKSIGVERIFY on failure.
extern "C" uint64_t cell_checksigverify() { return core_closed(0xad, 2); }
// A one-element stack: the 1073-1074 underflow arm.
extern "C" uint64_t cell_checksig_underflow() { return core_closed(0xac, 1); }
