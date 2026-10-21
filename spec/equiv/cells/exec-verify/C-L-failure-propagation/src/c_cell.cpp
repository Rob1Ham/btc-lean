#include "common.h"

// C leg — line-cited source-excerpt slice of Core `VerifyScript` at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
// SCR-017: every `EvalScript` / `VerifyWitnessProgram` failure returns false
// (input invalid) with the callee's `ScriptError` preserved.  There are five
// such call sites in `VerifyScript`:
//
//   2029-2031   if (!EvalScript(stack, scriptSig, ...)) return false;
//   2034-2036   if (!EvalScript(stack, scriptPubKey, ...)) return false;
//   2052-2054   if (!VerifyWitnessProgram(... is_p2sh=false)) return false;
//   2080-2082   if (!EvalScript(stack, pubKey2, ...)) return false;
//   2097-2099   if (!VerifyWitnessProgram(... is_p2sh=true)) return false;
//
// Each call returns false *immediately*: no later `set_error` overwrites the
// callee's error, and no later check runs.  The `// serror is set` comments
// at 2030/2035/2081 record exactly that contract.
//
// The cell models each callee as the pair (ok, err): `ok = 0` means the call
// failed and wrote `err`.  The three conditional sites are gated by declared
// activity inputs, read off the surrounding guards:
//   site 3 (2052)  active iff WITNESS ∧ scriptPubKey.IsWitnessProgram(...)
//   site 4 (2080)  active iff P2SH ∧ scriptPubKey.IsPayToScriptHash()
//   site 5 (2097)  active iff site 4 active ∧ WITNESS ∧
//                  pubKey2.IsWitnessProgram(...)
// The shape predicates and the arm dispatch are proved in the tail cell; this
// cell proves the failure wiring for every combination of their outcomes.
//
// Core only has two outcomes per call here (true / false-with-serror); Lean's
// `VerifyOutcome` also has `.unjudged`, which is outside this row and is not
// modelled.

EVINLINE uint64_t c_failprop(uint64_t ok1, uint64_t err1,
                             uint64_t ok2, uint64_t err2,
                             uint64_t act3, uint64_t ok3, uint64_t err3,
                             uint64_t act4, uint64_t ok4, uint64_t err4,
                             uint64_t act5, uint64_t ok5, uint64_t err5) {
    // 2029-2031
    if (!ok1) return ev_pack(0, err1, 1);
    // 2034-2036
    if (!ok2) return ev_pack(0, err2, 2);
    // 2052-2054
    if (act3 && !ok3) return ev_pack(0, err3, 3);
    // 2080-2082
    if (act4 && !ok4) return ev_pack(0, err4, 4);
    // 2097-2099
    if (act4 && act5 && !ok5) return ev_pack(0, err5, 5);
    return ev_pack(1, 0, 0);
}

extern "C" uint64_t cell_failprop(uint64_t ok1, uint64_t err1,
                                  uint64_t ok2, uint64_t err2,
                                  uint64_t act3, uint64_t ok3, uint64_t err3,
                                  uint64_t act4, uint64_t ok4, uint64_t err4,
                                  uint64_t act5, uint64_t ok5, uint64_t err5) {
    return c_failprop(ok1 & 1u, err1 & 0x3fu, ok2 & 1u, err2 & 0x3fu,
                      act3 & 1u, ok3 & 1u, err3 & 0x3fu,
                      act4 & 1u, ok4 & 1u, err4 & 0x3fu,
                      act5 & 1u, ok5 & 1u, err5 & 0x3fu);
}
