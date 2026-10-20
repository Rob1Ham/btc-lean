#ifndef E3_CHECKER_ABI_H
#define E3_CHECKER_ABI_H
// The single external checker seam for E3 CHECKSIG/CHECKMULTISIG cells.
//
// Both the C leg (Core's BaseSignatureChecker::CheckECDSASignature at the
// pin) and the L leg (Lean's ScriptChecker.base.checkECDSASignature) call
// THIS symbol with the same arguments.  In the Alive2 lane it is a bare
// declaration: Alive2 treats calls to the same external symbol with the same
// arguments as returning the same value, which is exactly the same-crypto
// premise of docs/DECISION-lax-ecdsa.md.  In the SAW lane a shared stub
// (checker_stub.cpp) implements it; scenario runs pin its return to 0 or 1,
// one build per value, so both legs are verified against the same checker.
//
// Argument encoding: see e3_common.h.  `script_code` packs two bytes of the
// post-CODESEPARATOR scriptCode (the cell has no CODESEPARATOR and a 2-byte
// scriptCode); `sigversion` is 0=BASE, 1=WITNESS_V0.
extern "C" uint8_t btc_equiv_check_sig(uint32_t sig, uint32_t pk,
                                       uint32_t script_code, uint32_t sigversion);

#endif
