#include "x_common.h"

// C leg: line-cited source-excerpt slices of Bitcoin Core at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66.
//
//   src/script/interpreter.cpp:2012-2131   VerifyScript
//   src/script/script.cpp:266-282          CScript::IsPushOnly
//   src/shim                                      (contract domain check:
//                                          spec/equiv/shims/core/entry.cpp:93-100)
//
// Declared abstractions (each one is outside the SCR row it serves; the cell
// specs name them):
//
//  * Script parsing.  `CScript::GetOp` / `GetScriptOp` is not modelled; the
//    scriptSig arrives as already-decoded opcodes (wire bytes).  The
//    malformed-tail error-kind seam is F-DIV-001 and is excluded from these
//    cells.  SCR-006 is the push-only *classification and placement*, not the
//    parser.
//  * EvalScript (interpreter.cpp:2029, :2034, :2080).  The stack produced by
//    each EvalScript call is an input of the bounded slice.  The EvalScript
//    loop is the E5 residual (findings/e5/E5-RESIDUAL.md, B3).
//  * VerifyWitnessProgram / ExecuteWitnessScript and signature checking are
//    never reached in this slice.
//
// Error ordinals are the shared EQUIV_ERR_* values, 1:1 with Core
// ScriptError at the pin (contract/error_enum.md):
//   1 UNKNOWN_ERROR, 2 EVAL_FALSE, 26 SIG_PUSHONLY, 30 CLEANSTACK.

// ---------------------------------------------------------------------------
// SCR-006: "scriptSig must be push-only for P2SH evaluation"
// interpreter.cpp:2065-2066 (inside the P2SH arm opened at :2062):
//
//     if (!scriptSig.IsPushOnly())
//         return set_error(serror, SCRIPT_ERR_SIG_PUSHONLY);
//
// CScript::IsPushOnly (script.cpp:266-282):
//
//     while (pc < end()) {
//         if (!GetOp(pc, opcode)) return false;
//         if (opcode > OP_16) return false;     // OP_16 == 0x60
//     }
//     return true;
//
// The decoded scriptSig is the cell input: at most three opcodes with their
// wire bytes.  A parse failure would return false from GetOp here; that arm
// is the F-DIV-001 seam and is not part of this cell.
// ---------------------------------------------------------------------------
XINLINE bool c_is_push_only(uint32_t n, uint64_t w0, uint64_t w1, uint64_t w2) {
  n = n > 3u ? 3u : n;
  if (n > 0u && w0 > 0x60u) return false;
  if (n > 1u && w1 > 0x60u) return false;
  if (n > 2u && w2 > 0x60u) return false;
  return true;
}

// Observable: (result, error) for the push-only gate only.
//   1, 0  -> the P2SH arm's gate passed (the redeem-script EvalScript at
//            :2080 is abstracted to success; no verdict beyond the gate)
//   0, 26 -> SIG_PUSHONLY from :2066
// With the P2SH flag clear the arm at :2062 is not entered at all.
extern "C" uint64_t cell_p2sh_pushonly_gate(uint64_t n_ops, uint64_t w0,
                                            uint64_t w1, uint64_t w2,
                                            uint64_t p2sh_flag) {
  if (p2sh_flag != 0u) {
    if (!c_is_push_only((uint32_t)(n_ops & 0xffu), w0 & 0xffu, w1 & 0xffu,
                        w2 & 0xffu)) {
      return x_pack2(0, 26);
    }
  }
  return x_pack2(1, 0);
}

// ---------------------------------------------------------------------------
// SCR-007: "stackCopy (taken after scriptSig) is restored for subscript eval"
// interpreter.cpp:2032-2033 and :2069:
//
//     if (flags & SCRIPT_VERIFY_P2SH)
//         stackCopy = stack;                       // :2032-2033
//     ...
//     swap(stack, stackCopy);                      // :2069
//     const valtype& pubKeySerialized = stack.back();
//     CScript pubKey2(...); popstack(stack);       // :2076-2078
//     EvalScript(stack, pubKey2, ...)              // :2080
//
// The two EvalScript calls (:2029 scriptSig, :2034 scriptPubKey) are
// abstracted to the stack inputs of this slice; the observable records the
// redeemScript byte and the stack handed to :2080, which is what "restored
// from the snapshot" means.  The push-only gate at :2065 is a precondition
// (push_only = true) here; it is SCR-006's cell.
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_p2sh_stackcopy(uint64_t sig_n, uint64_t sig_e0,
                                        uint64_t sig_e1, uint64_t spk_n,
                                        uint64_t spk_e0, uint64_t spk_e1,
                                        uint64_t p2sh_flag) {
  // Result of EvalScript(stack, scriptSig, ...) at :2029.
  XStack stack = x_stack(sig_n, sig_e0, sig_e1);
  XStack stackCopy;
  stackCopy.n = 0u;
  stackCopy.e[0] = 0u;
  stackCopy.e[1] = 0u;

  // :2032-2033
  if (p2sh_flag != 0u) stackCopy = stack;

  // Result of EvalScript(stack, scriptPubKey, ...) at :2034, abstracted.
  stack = x_stack(spk_n, spk_e0, spk_e1);
  // :2037-2040
  if (stack.n == 0u) return x_pack_stack(0, 2, 0, 0, 0, 0);
  if (!x_cast_to_bool1(stack.e[0])) return x_pack_stack(0, 2, 0, 0, 0, 0);

  // :2062 - the arm is entered iff the P2SH flag is set (spk is the P2SH
  // template by cell precondition).  Without it no subscript evaluation
  // happens, so the observable is the "arm not taken" marker.
  if (p2sh_flag == 0u) return x_pack_stack(1, 0, 0, 0, 0, 0);

  // :2069 restore
  XStack tmp = stack;
  stack = stackCopy;
  stackCopy = tmp;

  // :2074 assert(!stack.empty()) - unreachable when the P2SH scriptPubKey
  // evaluated successfully; the out-of-contract value is reported as
  // UNKNOWN_ERROR for totality, never as a verdict.
  if (stack.n == 0u) return x_pack_stack(0, 1, 0, 0, 0, 0);

  // :2076-2078
  const uint8_t redeem = stack.e[0];
  stack = x_popstack(stack);

  // :2080 EvalScript(pubKey2, stack, ...) abstracted to .ok; its inputs are
  // the observable (SCR-007).
  return x_pack_stack(1, 0, redeem, stack.n, stack.e[0], stack.e[1]);
}

// ---------------------------------------------------------------------------
// SCR-008 (flag/policy face): interpreter.cpp:2110-2118
//
//     if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0) {
//         assert((flags & SCRIPT_VERIFY_P2SH) != 0);
//         assert((flags & SCRIPT_VERIFY_WITNESS) != 0);
//         if (stack.size() != 1)
//             return set_error(serror, SCRIPT_ERR_CLEANSTACK);
//     }
//
// `final_len` is the cleanstack-relevant stack length after evaluation.
// The witness-program bypass (`stack.resize(1)` at :2057/:2102) is not part
// of this function; it is the divergence probe in the same cell, because the
// Lean model does not reproduce it for the P2SH-wrapped arm.
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_cleanstack_flag(uint64_t final_len,
                                         uint64_t cs_flag) {
  if (cs_flag != 0u) {
    if (final_len != 1u) return x_pack2(0, 30);
  }
  return x_pack2(1, 0);
}

// Divergence probe for SCR-008's "implicit in witness" face.
//   bypass_kind 0 = no witness program verified
//               1 = bare witness program verified  (:2046-2057)
//               2 = P2SH-wrapped witness program verified (:2090-2103)
// Core resizes the stack to one element in BOTH witness cases, so the
// CLEANSTACK check at :2115 always sees size 1.  The Lean model
// (`verifyScriptFull`, Defs.lean:1395-1418) tests `isWitnessProgram spk`,
// which is true only for the bare case, and never resizes for the
// P2SH-wrapped case.  This probe is expected to FAIL Alive2; its raw output
// is the counterexample, not a green claim.
extern "C" uint64_t probe_cleanstack_witness(uint64_t final_len,
                                             uint64_t cs_flag,
                                             uint64_t bypass_kind) {
  const uint64_t len = bypass_kind != 0u ? 1u : final_len;
  if (cs_flag != 0u) {
    if (len != 1u) return x_pack2(0, 30);
  }
  return x_pack2(1, 0);
}

// ---------------------------------------------------------------------------
// SCR-009: "Flag combination constraint" - interpreter.cpp:2113-2114
//
//     assert((flags & SCRIPT_VERIFY_P2SH) != 0);
//     assert((flags & SCRIPT_VERIFY_WITNESS) != 0);
//
// C leg: the contract makes the two VerifyScript assertions a domain rule
// instead of a debug abort (ABI.md/tape.md §5, spelled out in
// spec/equiv/shims/core/entry.cpp:93-100):
//
//     if (witness && !p2sh) return 2;
//     if (cleanstack && (!p2sh || !witness)) return 2;
//
// Observable: 0 = admissible flag combination, 2 = rejected as bad input.
// This is the domain predicate, not a script verdict.
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_flag_combo_admissible(uint64_t p2sh, uint64_t witness,
                                               uint64_t cleanstack) {
  if (witness != 0u && p2sh == 0u) return 2;
  if (cleanstack != 0u && (p2sh == 0u || witness == 0u)) return 2;
  return 0;
}
