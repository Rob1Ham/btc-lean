#include "x_common.h"

// L leg: REVIEWED TRANSLITERATIONS of the Lean interpreter model, not
// generated from the twin.  The generated twin (`twin/runtime.inc`) has a
// VerifyScript, but the E5/E4 convention is to compare against the Verified
// Lean definition where the row is stated over it.  Sources:
//
//   spec/core/Bitcoin/Interpreter/Defs.lean:1326-1359  p2shInner
//   spec/core/Bitcoin/Interpreter/Defs.lean:1363-1445  verifyScriptFull
//   spec/core/Bitcoin/Interpreter/Rules.lean:47-50     flagsComboOk
//   spec/core/Bitcoin/Interpreter/Defs.lean:496         isPushOnlyWire
//
// The Lean stack is a list with head = TOP; a cell stack is the same shape
// with at most two elements.  Error ordinals are the shared EQUIV_ERR_*
// values (unknownError=1, evalFalse=2, sigPushOnly=26, cleanstack=30).

// ---------------------------------------------------------------------------
// SCR-006.  Lean (`p2shInner`, Defs.lean:1326-1350):
//
//     match parseWire ss with
//     | none => .fail .badOpcode
//     | some ops =>
//       if !isPushOnlyWire ops then .fail .sigPushOnly
//       else <restore stackCopy and evaluate the redeem script>
//
//   isPushOnlyWire ops := ops.all (fun o => o.wire <= 0x60)
//
// `parseWire ss = some ops` is the cell precondition (the scriptSig is
// already decoded); parse failure is F-DIV-001 and would be `.badOpcode`
// here against Core's SIG_PUSHONLY.  The branch body below is a direct
// transcription of the `some ops` arm.
// ---------------------------------------------------------------------------
XINLINE bool l_is_push_only_wire(uint32_t n, uint64_t w0, uint64_t w1,
                                 uint64_t w2) {
  n = n > 3u ? 3u : n;
  const bool ok0 = n < 1u || w0 <= 0x60u;
  const bool ok1 = n < 2u || w1 <= 0x60u;
  const bool ok2 = n < 3u || w2 <= 0x60u;
  return ok0 && ok1 && ok2;
}

extern "C" uint64_t cell_p2sh_pushonly_gate(uint64_t n_ops, uint64_t w0,
                                            uint64_t w1, uint64_t w2,
                                            uint64_t p2sh_flag) {
  // Lean uses the P2SH arm only under `flags.p2sh ∧ isPayToScriptHash spk`
  // (verifyScriptFull, Defs.lean:1388).
  if (p2sh_flag != 0u) {
    if (!l_is_push_only_wire((uint32_t)(n_ops & 0xffu), w0 & 0xffu, w1 & 0xffu,
                             w2 & 0xffu)) {
      return x_pack2(0, 26);
    }
  }
  return x_pack2(1, 0);
}

// ---------------------------------------------------------------------------
// SCR-007.  Lean, `verifyScriptFull` (Defs.lean:1372-1394):
//
//     | .ok stack1 =>
//       let stackCopy := stack1
//       match evalScriptBytes ... spk stack1 ... with
//       | .ok stack =>
//         if stack = [] ∨ !castToBool stack[0]! then .fail .evalFalse
//         else ... if flags.p2sh ∧ isPayToScriptHash spk then
//                match p2shInner ... ss stackCopy ... with ...
//
// and `p2shInner` (Defs.lean:1335-1340):
//
//     | pubKeySerialized :: rest =>
//       let pubKey2 := pubKeySerialized
//       match evalScriptBytes ... pubKey2 rest ... with ...
//
// `stackCopy` is bound to the post-scriptSig stack; the subscript evaluation
// receives `rest`, i.e. that snapshot with its top removed.  The two
// EvalScript results are cell inputs.  Lean's `stackCopy := stack1` is
// unconditional, while Core saves it only under P2SH; the conditional is
// unobservable because the snapshot is read only inside the P2SH arm, and
// this cell proves exactly that.
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_p2sh_stackcopy(uint64_t sig_n, uint64_t sig_e0,
                                        uint64_t sig_e1, uint64_t spk_n,
                                        uint64_t spk_e0, uint64_t spk_e1,
                                        uint64_t p2sh_flag) {
  const XStack stack1 = x_stack(sig_n, sig_e0, sig_e1);
  const XStack stack_copy = stack1;  // `let stackCopy := stack1`

  const XStack stack = x_stack(spk_n, spk_e0, spk_e1);
  // if stack = [] ∨ !castToBool stack[0]! then .fail .evalFalse
  if (stack.n == 0u || !x_cast_to_bool1(stack.e[0])) {
    return x_pack_stack(0, 2, 0, 0, 0, 0);
  }

  if (p2sh_flag != 0u) {
    // p2shInner: `match stackCopy with | p :: rest => ...`
    if (stack_copy.n == 0u) return x_pack_stack(0, 1, 0, 0, 0, 0);
    const uint8_t p = stack_copy.e[0];
    XStack rest;
    rest.n = stack_copy.n - 1u;
    rest.e[0] = rest.n >= 1u ? stack_copy.e[1] : 0u;
    rest.e[1] = 0u;
    // evalScriptBytes fuel flags pol p rest chk .base default abstracted .ok
    return x_pack_stack(1, 0, p, rest.n, rest.e[0], rest.e[1]);
  }
  return x_pack_stack(1, 0, 0, 0, 0, 0);
}

// ---------------------------------------------------------------------------
// SCR-008 (flag/policy face).  Lean (`verifyScriptFull`, Defs.lean:1418-1420
// and the bare face at :1442-1443):
//
//     if pol.cleanstack ∧ finalLen ≠ 1 then .fail .cleanstack
//     ...
//     if pol.cleanstack ∧ afterBare.length ≠ 1 then .fail .cleanstack
//
// The model carries CLEANSTACK in PolicyFlags (`pol.cleanstack`); Core
// carries it in the verify-flag word (SCRIPT_VERIFY_CLEANSTACK).  The cell
// fixes that mapping: one input bit, read as the Core flag on C and as
// `pol.cleanstack` on L.
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_cleanstack_flag(uint64_t final_len,
                                         uint64_t cs_flag) {
  if (cs_flag != 0u) {
    if (final_len != 1u) return x_pack2(0, 30);
  }
  return x_pack2(1, 0);
}

// Divergence probe (same names/arity as the C leg).  Lean's `finalLen`
// model (Defs.lean:1395-1410):
//
//     let finalLen : Nat :=
//       if flags.witness ∧ (isWitnessProgram spk).isSome then 1
//       else <re-evaluate the redeem script and take its length>
//
// so only a BARE witness program (bypass_kind 1) is resized; the
// P2SH-wrapped arm (kind 2, Core :2090-2103) keeps the inner length.
extern "C" uint64_t probe_cleanstack_witness(uint64_t final_len,
                                             uint64_t cs_flag,
                                             uint64_t bypass_kind) {
  const uint64_t len = bypass_kind == 1u ? 1u : final_len;
  if (cs_flag != 0u) {
    if (len != 1u) return x_pack2(0, 30);
  }
  return x_pack2(1, 0);
}

// ---------------------------------------------------------------------------
// SCR-009.  Lean (`flagsComboOk`, Rules.lean:47-50):
//
//     def flagsComboOk (flags : ScriptFlags) (pol : PolicyFlags) : Bool :=
//       (!pol.cleanstack ∨ (flags.p2sh ∧ flags.witness)) ∧
//       (!flags.witness ∨ flags.p2sh)
//
// `false` is the "not a well-formed flag/policy pair" answer, which the
// contract maps to bad input (result 2) instead of Core's debug assert.
// ---------------------------------------------------------------------------
extern "C" uint64_t cell_flag_combo_admissible(uint64_t p2sh, uint64_t witness,
                                               uint64_t cleanstack) {
  const bool p = p2sh != 0u;
  const bool w = witness != 0u;
  const bool c = cleanstack != 0u;
  const bool ok = (!c || (p && w)) && (!w || p);
  return ok ? 0u : 2u;
}
