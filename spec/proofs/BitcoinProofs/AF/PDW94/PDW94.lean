import Bitcoin.Interpreter.Defs
import Bitcoin.Serialization.Interface
import Bitcoin.DataLaws.Interface

/-! # PDW94 — final-push row faces

* **SCR-078** — the 19 stack-shuffling opcodes below fail with
  `stackUnderflow` on an empty stack; this is a named subset, not every
  consuming opcode (`popstack`'s `UNKNOWN_ERROR` is unreachable on this
  lane). See the core theorem header for the uncovered families.
* **TXV-012** — CompactSize `0xfd` non-minimal rejection + canonical
  roundtrip (re-exported from the core serialization bank).
* **SWT-067** — BIP144 per-input witness framing (definitional faces).

Route B: zero core writes. Pins target `[propext, Classical.choice,
Quot.sound]`. -/

namespace BitcoinProofs.AF.PDW94

open Bitcoin.Interpreter Bitcoin.Numeric

/-- **SCR-078 (stack-shuffling subset)**: on an empty stack, the 19
stack-shuffling opcodes listed in `hw` pre-check depth and return
`SCRIPT_ERR_INVALID_STACK_OPERATION`. Numeric, hash, control-flow and
checksig consumers are separate rows: this theorem is not a claim about
"every consuming opcode". -/
@[rule "SCR-078"]
theorem stepBody_stackop_empty_underflow (ctx : Ctx) (op : WireOp) (st : State)
    (c : Fin 256) (ha : op.ast = .op c)
    (hw : op.wire = 0x6d ∨ op.wire = 0x6e ∨ op.wire = 0x6f ∨ op.wire = 0x70 ∨
      op.wire = 0x71 ∨ op.wire = 0x72 ∨ op.wire = 0x73 ∨ op.wire = 0x75 ∨
      op.wire = 0x76 ∨ op.wire = 0x77 ∨ op.wire = 0x78 ∨ op.wire = 0x79 ∨
      op.wire = 0x7a ∨ op.wire = 0x7b ∨ op.wire = 0x7c ∨ op.wire = 0x7d ∨
      op.wire = 0x82 ∨ op.wire = 0x87 ∨ op.wire = 0x88)
    (hempty : st.stack = [])
    (hfe : st.vf.all id = true)
    (hb : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1)) :
    stepBody ctx op st = .error .stackUnderflow := by
  have hb2 : (ctx.sv = .base ∨ ctx.sv = .witnessV0) →
      (if ctx.sv = .base ∨ ctx.sv = .witnessV0 then st.opCount + 1 else st.opCount)
        ≤ MAX_OPS_PER_SCRIPT := by
    intro hA
    rw [ite_eq_left hA]
    exact Nat.le_of_not_lt (fun hlt => hb ⟨hA, hlt⟩)
  rcases hw with hw | hw | hw | hw | hw | hw | hw | hw | hw | hw |
      hw | hw | hw | hw | hw | hw | hw | hw | hw <;>
    simp [stepBody, ha, hw, hempty, hfe, disabledWire,
      Bitcoin.Interpreter.stepBody.dispatchOp]
  all_goals exact hb2

/-- **TXV-012 (reject)**: a `0xfd`-prefixed CompactSize below `0xfd` is
non-minimal (`serialize.h:333-361` @ cce32b168). -/
@[rule "TXV-012"]
theorem decCS_nonMinimal_fd_row (b0 b1 : UInt8) (rest : Bitcoin.Serialization.Bytes)
    (h : b0.toNat + 256 * b1.toNat < 0xfd) :
    Bitcoin.Serialization.decCS (0xfd :: b0 :: b1 :: rest)
      = .error .compactSizeNonMinimal :=
  Bitcoin.Serialization.decCS_nonMin_0xfd b0 b1 rest h

/-- **TXV-012 (accept)**: canonical encodings decode back exactly. -/
@[rule "TXV-012"]
theorem decCS_canonical_roundtrip_row (n : Nat) (h : n ≤ Bitcoin.Serialization.MAX_SIZE)
    (rest : Bitcoin.Serialization.Bytes) :
    Bitcoin.Serialization.decCS (Bitcoin.Serialization.encCSL n ++ rest)
      = .ok (n, rest) :=
  Bitcoin.Serialization.decCS_encCSL n h rest

/-- **SWT-067**: the witness serialization is the per-input BIP144 fold
over the `vin` index range (one stack per input). -/
@[rule "SWT-067"]
theorem serWitness_framing_row (tx : Bitcoin.Data.Tx) :
    Bitcoin.DataLaws.serWitness tx
      = (List.range tx.vin.length).foldl
          (fun acc i => acc ++ Bitcoin.DataLaws.serWitnessStack (tx.witness.getD i []))
          ByteArray.empty := rfl

end BitcoinProofs.AF.PDW94

/-- info: 'BitcoinProofs.AF.PDW94.stepBody_stackop_empty_underflow' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW94.stepBody_stackop_empty_underflow
/-- info: 'BitcoinProofs.AF.PDW94.decCS_nonMinimal_fd_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW94.decCS_nonMinimal_fd_row
/-- info: 'BitcoinProofs.AF.PDW94.decCS_canonical_roundtrip_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW94.decCS_canonical_roundtrip_row
/-- info: 'BitcoinProofs.AF.PDW94.serWitness_framing_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW94.serWitness_framing_row
