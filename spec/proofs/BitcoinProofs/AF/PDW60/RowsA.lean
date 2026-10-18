import Bitcoin.Interpreter.Rules
import Bitcoin.Block.Params
import Bitcoin.Invariants.RC08

/-! # PDW60 RowsA — TOP-321/322/325: SCR-147, BLK-106, INV-086 (RC29).
Route B status-debt promotion: row faces stated on the core declarations;
zero core writes. -/

namespace BitcoinProofs.AF.PDW60

open Bitcoin.Crypto.Taproot (tweakPoint tweakScalar)

/-- SCR-147: the output key depends on commitment inputs ONLY through the
32-byte tap-tweak scalar. -/
@[rule "SCR-147"]
theorem tweakPoint_eq_of_tweakScalar_eq (p p' : ByteArray) (P : Bitcoin.Crypto.Curve.Secp.RawPoint)
    (root root' : Option ByteArray)
    (h : tweakScalar p root = tweakScalar p' root') :
    tweakPoint p P root = tweakPoint p' P root' := by
  unfold tweakPoint
  rw [h]

/-- SCR-147 row face: equal (p, merkle_root) ⇒ equal tweaked output key;
the control parity bit is serialization-only. -/
@[rule "SCR-147"]
theorem taprootOutputKey_determined (p p' : ByteArray) (P : Bitcoin.Crypto.Curve.Secp.RawPoint)
    (root root' : Option ByteArray) (hp : p = p') (hr : root = root') :
    tweakPoint p P root = tweakPoint p' P root' := by
  subst hp; subst hr; rfl

/-- BLK-106: the undo replay is exactly the reverse of the batch. -/
@[rule "BLK-106"]
theorem replayUndos_eq_reverse
    (undo : List (Bitcoin.Data.OutPoint × Bitcoin.Ledger.Coin)) :
    Bitcoin.Block.Params.replayUndos undo = undo.reverse := rfl

/-- BLK-106: batch order is reversed on concatenation. -/
@[rule "BLK-106"]
theorem replayUndos_append
    (u v : List (Bitcoin.Data.OutPoint × Bitcoin.Ledger.Coin)) :
    Bitcoin.Block.Params.replayUndos (u ++ v)
      = Bitcoin.Block.Params.replayUndos v
        ++ Bitcoin.Block.Params.replayUndos u := by
  unfold Bitcoin.Block.Params.replayUndos
  exact List.reverse_append

/-- BLK-106: disconnect is reversible. -/
@[rule "BLK-106"]
theorem replayUndos_involutive
    (undo : List (Bitcoin.Data.OutPoint × Bitcoin.Ledger.Coin)) :
    Bitcoin.Block.Params.replayUndos (Bitcoin.Block.Params.replayUndos undo)
      = undo := by
  unfold Bitcoin.Block.Params.replayUndos
  exact List.reverse_reverse undo

/-- INV-086: pass iff gate inactive (off-signet or no POW) or solution ok. -/
@[rule "INV-086"]
theorem signetBlockOk_iff (signetBlocks fCheckPOW solutionOk : Bool) :
    Bitcoin.Invariants.RC08.signetBlockOk signetBlocks fCheckPOW solutionOk = true
      ↔ (¬(signetBlocks = true ∧ fCheckPOW = true) ∨ solutionOk = true) := by
  cases signetBlocks <;> cases fCheckPOW <;> cases solutionOk <;>
    simp [Bitcoin.Invariants.RC08.signetBlockOk]

/-- INV-086: off-signet always passes. -/
@[rule "INV-086"]
theorem signetBlockOk_off (fCheckPOW solutionOk : Bool) :
    Bitcoin.Invariants.RC08.signetBlockOk false fCheckPOW solutionOk = true := by
  simp [Bitcoin.Invariants.RC08.signetBlockOk]


/-! ## Axiom pins (guard_msgs) -/

/-- info: 'BitcoinProofs.AF.PDW60.tweakPoint_eq_of_tweakScalar_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.tweakPoint_eq_of_tweakScalar_eq
/-- info: 'BitcoinProofs.AF.PDW60.taprootOutputKey_determined' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.taprootOutputKey_determined
/-- info: 'BitcoinProofs.AF.PDW60.replayUndos_eq_reverse' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.replayUndos_eq_reverse
/-- info: 'BitcoinProofs.AF.PDW60.replayUndos_append' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.replayUndos_append
/-- info: 'BitcoinProofs.AF.PDW60.replayUndos_involutive' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.replayUndos_involutive
/-- info: 'BitcoinProofs.AF.PDW60.signetBlockOk_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.signetBlockOk_iff
/-- info: 'BitcoinProofs.AF.PDW60.signetBlockOk_off' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60.signetBlockOk_off

end BitcoinProofs.AF.PDW60
