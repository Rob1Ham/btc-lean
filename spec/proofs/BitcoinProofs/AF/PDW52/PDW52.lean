import Bitcoin.Interpreter.Defs
import Bitcoin.Interpreter.Rules

/-! # PDW52 — TOP-256..260: witness-malleation + program-dispatch band (route B)

Row-face theorems for the BIP141/BIP16 witness gates in
`Bitcoin/Interpreter/Defs.lean` (`interpreter.cpp:1827-2111`):

* **INV-068** `verifyScriptFull` — bare witness program + non-empty
  scriptSig ⇒ `SCRIPT_ERR_WITNESS_MALLEATED` (:1331).
* **INV-077** `verifyScriptFull` — unexpected witness data on a
  non-witness spend fails closed (:1364).
* **INV-067** `verifyWitnessProgram` — v0 program shapes: length ∉ {20,32}
  ⇒ wrong-length; 32+empty ⇒ witness-empty; 20+arity≠2 ⇒ mismatch.
* **INV-069** `p2shInner` — P2SH-wrapped program whose scriptSig is not
  exactly the redeem-script push ⇒ `WITNESS_MALLEATED_P2SH` (:1291).
* **INV-070** `verifyWitnessProgram` — version dispatch: v1-32 non-P2SH is
  the taproot lane (inactive ⇒ ok), v1 else is upgradable (policy gate).

Route B: tags on my row-face theorems, zero core writes, pins ⊆ the trio. -/

namespace BitcoinProofs.AF.PDW52

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Activation Bitcoin.Script.Parser
open Bitcoin.Numeric

/-- INV-068: once a bare scriptPubKey is a witness program and the
scriptSig is non-empty, `VerifyScript` fails with `WITNESS_MALLEATED`
(`interpreter.cpp:2041-2042`) — after the base evaluation has passed. -/
@[rule "INV-068"]
theorem witnessMalleated_bare
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : WitnessStack) (chk : ScriptChecker)
    (stack1 stack : Stack) (v : Nat) (prog : ByteArray)
    (hpush : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (hne : stack ≠ []) (htop : castToBool (stack[0]?.getD default) = true)
    (hwit : flags.witness = true)
    (hp : isWitnessProgram spk = some (v, prog))
    (hssne : ss.size ≠ 0) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .witnessMalleated := by
  unfold verifyScriptFull
  simp [hpush, hss, hspk, hne, htop, hwit, hp, hssne]

/-- INV-069: a P2SH-wrapped witness program must have the scriptSig be
exactly the single push of the redeem script; otherwise
`WITNESS_MALLEATED_P2SH` (`interpreter.cpp:2071-2072`). -/
@[rule "INV-069"]
theorem p2shInner_witnessMalleatedP2SH
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (ss : ByteArray) (redeem : ByteArray) (rest st : Stack)
    (witness : WitnessStack) (chk : ScriptChecker)
    (ops : List WireOp) (v : Nat) (prog : ByteArray)
    (hparse : parseWire ss = some ops)
    (hpushonly : isPushOnlyWire ops = true)
    (heval : evalScriptBytes fuel flags pol redeem rest chk .base default = .ok st)
    (hne : st ≠ []) (htop : castToBool (st[0]?.getD default) = true)
    (hwit : flags.witness = true)
    (hp : isWitnessProgram redeem = some (v, prog))
    (hm : (ss != pushBytesWire redeem) = true) :
    p2shInner fuel flags pol ss (redeem :: rest) witness chk
      = .fail .witnessMalleatedP2SH := by
  unfold p2shInner
  simp [hparse, hpushonly, heval, hne, htop, hwit, hp, hm]

/-- INV-067 (length shape): a v0 program whose size is neither 20 nor 32
fails with `WITNESS_PROGRAM_WRONG_LENGTH` before witness inspection
(`interpreter.cpp:1848-1849`). -/
@[rule "INV-067"]
theorem verifyWitnessProgram_v0_wrongLength (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h20 : program.size ≠ 20) (h32 : program.size ≠ 32) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = .fail .witnessProgramWrongLength := by
  simp [verifyWitnessProgram, h32, h20]

/-- INV-067 (P2WSH shape): a v0-32 program with an empty witness fails
`WITNESS_PROGRAM_WITNESS_EMPTY` before hashing (`interpreter.cpp:1841-1843`). -/
@[rule "INV-067"]
theorem verifyWitnessProgram_v0_32_empty (fuel : Nat) (program : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker) (isP2SH : Bool)
    (h32 : program.size = 32) :
    verifyWitnessProgram fuel [] 0 program flags pol chk isP2SH
      = .fail .witnessProgramWitnessEmpty := by
  simp [verifyWitnessProgram, h32]

/-- INV-067 (P2WPKH shape): a v0-20 program requires exactly 2 witness
items (`interpreter.cpp:1852-1854`). -/
@[rule "INV-067"]
theorem verifyWitnessProgram_v0_20_arity (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h20 : program.size = 20) (harity : witness.length ≠ 2) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = .fail .witnessProgramMismatch := by
  simp [verifyWitnessProgram, h20, harity]

/-- INV-070 (taproot lane): a v1-32 bare program is BIP341; with the
taproot flag inactive the lane returns success (upgradable, no softfork
violation) (`interpreter.cpp:1875-1877`). -/
@[rule "INV-070"]
theorem verifyWitnessProgram_v1_32_taproot_inactive (fuel : Nat)
    (witness : WitnessStack) (program : ByteArray) (flags : ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker)
    (h32 : program.size = 32) (htap : flags.taproot = false) :
    verifyWitnessProgram fuel witness 1 program flags pol chk false = .ok := by
  simp [verifyWitnessProgram, h32, htap]

/-- INV-070 (upgradable dispatch): a v1 program that is not the v1-32
taproot shape and not pay-to-anchor takes the upgradable-witness branch:
policy gate off ⇒ success, on ⇒ `DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM`
(`interpreter.cpp:1999-2005`). -/
@[rule "INV-070"]
theorem verifyWitnessProgram_v1_upgradable (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h32 : program.size ≠ 32) (hanchor : isPayToAnchor 1 program = false)
    (hdis : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel witness 1 program flags pol chk isP2SH = .ok := by
  simp [verifyWitnessProgram, h32, hanchor, hdis]

/-- INV-077: a non-witness, non-P2SH spend that carries a witness fails
closed with `SCRIPT_ERR_WITNESS_UNEXPECTED` (`interpreter.cpp:2104-2106`);
`cleanstack` off isolates the witness gate. -/
@[rule "INV-077"]
theorem witnessUnexpected_nonWitness
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : WitnessStack) (chk : ScriptChecker)
    (stack1 stack : Stack)
    (hpush : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok stack1)
    (hspk : evalScriptBytes fuel flags pol spk stack1 chk .base default = .ok stack)
    (hne : stack ≠ []) (htop : castToBool (stack[0]?.getD default) = true)
    (hwit : flags.witness = true) (hp : isWitnessProgram spk = none)
    (hp2sh : flags.p2sh = false) (hcl : pol.cleanstack = false)
    (hwne : witness ≠ []) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .witnessUnexpected := by
  unfold verifyScriptFull
  simp [hpush, hss, hspk, hne, htop, hwit, hp, hp2sh, hcl, hwne]

/-! ## INV-077 — both halves: WITNESS ⇒ P2SH and both unexpected-witness tails -/

/-- INV-077 (WITNESS ⇒ P2SH): the flag-combination invariant Core asserts
before the witness gate (`interpreter.cpp:2113-2119`, :2124) — a
WITNESS-enabled flag word always carries P2SH, so the unexpected-witness
check can never be bypassed by disabling P2SH. -/
@[rule "INV-077"]
theorem witness_implies_p2sh_of_flagsComboOk (flags : ScriptFlags)
    (pol : PolicyFlags)
    (hok : flagsComboOk flags pol = true) (hw : flags.witness = true) :
    flags.p2sh = true := by
  unfold flagsComboOk at hok
  rw [decide_eq_true_iff] at hok
  have h2 := hok.2
  simpa [hw] using h2

/-- INV-077 (P2SH tail): a P2SH spend whose redeem script is not a witness
program but which carries witness data fails
`SCRIPT_ERR_WITNESS_UNEXPECTED` (`interpreter.cpp:2113-2119`).  Together
with `witnessUnexpected_nonWitness` (the bare tail, :2121-2128) this
covers both unexpected-witness failure tails. -/
@[rule "INV-077"]
theorem witnessUnexpected_p2shNonWitness
    (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (ss spk redeem : ByteArray) (rest st : Stack)
    (witness : WitnessStack) (chk : ScriptChecker)
    (ops : List WireOp) (stack : Stack)
    (hpush : pol.sigPushOnly = false)
    (hss : evalScriptBytes fuel flags pol ss [] chk .base default = .ok (redeem :: rest))
    (hspk : evalScriptBytes fuel flags pol spk (redeem :: rest) chk .base default = .ok stack)
    (hne : stack ≠ []) (htop : castToBool (stack[0]?.getD default) = true)
    (hwit : flags.witness = true)
    (hp : isWitnessProgram spk = none)
    (hp2sh : flags.p2sh = true) (hsh : isPayToScriptHash spk = true)
    (hred : isWitnessProgram redeem = none)
    (hparse : parseWire ss = some ops)
    (hpushonly : isPushOnlyWire ops = true)
    (heval : evalScriptBytes fuel flags pol redeem rest chk .base default = .ok st)
    (hstne : st ≠ []) (hsttop : castToBool (st[0]?.getD default) = true)
    (hcl : pol.cleanstack = false)
    (hwne : witness ≠ []) :
    verifyScriptFull fuel flags pol ss spk witness chk = .fail .witnessUnexpected := by
  have hp2 : p2shInner fuel flags pol ss (redeem :: rest) witness chk = .ok := by
    unfold p2shInner
    simp [hparse, hpushonly, heval, hstne, hsttop, hwit, hred]
  unfold verifyScriptFull
  simp [hpush, hss, hspk, hne, htop, hwit, hp, hp2sh, hsh, hp2, hcl, hwne]
  rw [hred]
  simp

/-! ## Axiom pins -/

/-- info: 'BitcoinProofs.AF.PDW52.witnessMalleated_bare' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms witnessMalleated_bare
/-- info: 'BitcoinProofs.AF.PDW52.p2shInner_witnessMalleatedP2SH' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms p2shInner_witnessMalleatedP2SH
/-- info: 'BitcoinProofs.AF.PDW52.verifyWitnessProgram_v0_wrongLength' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyWitnessProgram_v0_wrongLength
/-- info: 'BitcoinProofs.AF.PDW52.verifyWitnessProgram_v0_32_empty' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyWitnessProgram_v0_32_empty
/-- info: 'BitcoinProofs.AF.PDW52.verifyWitnessProgram_v0_20_arity' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyWitnessProgram_v0_20_arity
/-- info: 'BitcoinProofs.AF.PDW52.verifyWitnessProgram_v1_32_taproot_inactive' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyWitnessProgram_v1_32_taproot_inactive
/-- info: 'BitcoinProofs.AF.PDW52.verifyWitnessProgram_v1_upgradable' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms verifyWitnessProgram_v1_upgradable
/-- info: 'BitcoinProofs.AF.PDW52.witnessUnexpected_nonWitness' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms witnessUnexpected_nonWitness
/-- info: 'BitcoinProofs.AF.PDW52.witness_implies_p2sh_of_flagsComboOk' depends on axioms: [propext] -/
#guard_msgs in #print axioms witness_implies_p2sh_of_flagsComboOk
/-- info: 'BitcoinProofs.AF.PDW52.witnessUnexpected_p2shNonWitness' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms witnessUnexpected_p2shNonWitness
