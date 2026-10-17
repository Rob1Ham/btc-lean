import Bitcoin.Capstone.Merkle
import Bitcoin.Activation.Interface

/-!
# BitcoinProofs.AF.PDW43b — TOP-296..300 row faces, Capstone/Merkle

Route B: proofs-side restatements of the witness-root and commitment-gate
rows. Zero core writes; `@[rule]` tags ride these theorems.
Axiom pin target: `[propext, Classical.choice, Quot.sound]`.
-/

namespace BitcoinProofs.AF.PDW43b
open Bitcoin.Capstone.Merkle Bitcoin.Data

/-! ## SWT-032 — witness merkle root over non-coinbase wtxids -/

/-- **SWT-032** (unfolded): the witness tree is the `0x00…00` coinbase
leaf followed by the wtxids of every non-coinbase tx (merkle.cpp:118-126). -/
@[rule "SWT-032"]
theorem witnessMerkleRoot_cons (cb : Tx) (rest : List Tx) :
    witnessMerkleRoot (cb :: rest) = merkleRootOf (zeroBytes 32 :: rest.map wtxidOf) := rfl

/-- SWT-032 corner: the empty leaf vector hashes to the 32-zero null root. -/
@[rule "SWT-032"]
theorem witnessMerkleRoot_nil : witnessMerkleRoot ([] : List Tx) = zeroBytes 32 := rfl

/-- SWT-032 corollary: a coinbase-only block's witness root is the null
leaf itself (no wtxid enters the fold). -/
@[rule "SWT-032"]
theorem witnessMerkleRoot_coinbase_only (cb : Tx) :
    witnessMerkleRoot [cb] = zeroBytes 32 := by
  rw [witnessMerkleRoot_cons, List.map_nil]; rfl

/-! ## SWT-033 — no witness data without a commitment output -/

/-- **SWT-033** no-witness lane: with no witness txs the gate is the
SegWit-active commitment binding when an output is present, and passes
otherwise (pre-activation the whole requirement is a no-op). -/
@[rule "SWT-033"]
theorem commitmentGate_no_witness (segwitActive : Bool) (txs : List Tx)
    (cb : Tx) (hw : anyWitness txs = false) :
    commitmentGate segwitActive txs cb =
      (if segwitActive && (witnessCommitmentOutput cb).isSome then
         witnessCommitmentOk txs cb else true) := by
  simp [commitmentGate, hw]

/-- SWT-033 post-activation reject lane: at activation height, a
witness-free block that carries a commitment output passes exactly when
that output binds; a non-binding output fails the gate. The
`segwitActive = true` and `witnessCommitmentOk = false` hypotheses are
genuinely necessary under the conditional gate: pre-activation the
no-witness fall-through accepts a commitment-shaped output even without
witness data (block 470000, F-V12-006), and post-activation a
witness-free output is otherwise accepted. -/
@[rule "SWT-033"]
theorem commitmentGate_no_witness_output_reject (segwitActive : Bool)
    (txs : List Tx) (cb : Tx)
    (hw : anyWitness txs = false) (ho : (witnessCommitmentOutput cb).isSome)
    (hseg : segwitActive = true) (hk : witnessCommitmentOk txs cb = false) :
    commitmentGate segwitActive txs cb = false := by
  subst hseg
  rw [commitmentGate_no_witness true txs cb hw]
  simp [ho, hk]

/-- **SWT-033 (the row's reject direction, general in activation)**:
`validation.cpp:3913-3921` — a block with no commitment output may carry
no witness data. If the gate *passes* while the coinbase has no
commitment output, then the block is completely witness-free, whichever
side of the activation boundary it is on. This is the direction the
original `commitmentGate_no_witness` did not state. -/
@[rule "SWT-033"]
theorem commitmentGate_no_commitment_no_witness (segwitActive : Bool)
    (txs : List Tx) (cb : Tx)
    (hgate : commitmentGate segwitActive txs cb = true)
    (ho : (witnessCommitmentOutput cb).isSome = false) :
    anyWitness txs = false := by
  cases hw : anyWitness txs with
  | false => rfl
  | true =>
    exfalso
    simp [commitmentGate, ho, hw] at hgate

/-- **SWT-033 (reject form)**: witness data with no commitment output
fails the gate unconditionally — pre- and post-activation alike. This is
Core's `unexpected-witness` condition. -/
@[rule "SWT-033"]
theorem commitmentGate_no_commitment_rejects (segwitActive : Bool)
    (txs : List Tx) (cb : Tx)
    (ho : (witnessCommitmentOutput cb).isSome = false)
    (hw : anyWitness txs = true) :
    commitmentGate segwitActive txs cb = false := by
  simp [commitmentGate, ho, hw]

/-! ## SWT-034 — post-activation binding requirement -/

/-- **SWT-034**: when the block carries witness txs and SegWit is active,
the gate IS the binding check — the commitment must be present and match
the tree. The activation hypothesis is genuinely necessary: the fixed
gate is `CheckWitnessMalleation(block, expect_witness_commitment, state)`,
so pre-activation the fall-through no-witness rule applies instead. -/
@[rule "SWT-034"]
theorem commitmentGate_witness_forces_binding (segwitActive : Bool)
    (txs : List Tx) (cb : Tx) (hw : anyWitness txs = true)
    (hseg : segwitActive = true) :
    commitmentGate segwitActive txs cb = witnessCommitmentOk txs cb := by
  subst hseg
  cases ho : witnessCommitmentOutput cb <;>
    simp [commitmentGate, hw, ho, witnessCommitmentOk]

/-- SWT-034 determinacy: under witness data at activation height the gate
passes iff the commitment binds (new converse lane; BLK-020 only stated
equality). On the activation hypothesis, see `_witness_forces_binding`. -/
@[rule "SWT-034"]
theorem commitmentGate_witness_true_iff (segwitActive : Bool)
    (txs : List Tx) (cb : Tx) (hw : anyWitness txs = true)
    (hseg : segwitActive = true) :
    commitmentGate segwitActive txs cb = true ↔
      witnessCommitmentOk txs cb = true := by
  rw [commitmentGate_witness_forces_binding segwitActive txs cb hw hseg]

/-- Binding implies the commitment output exists (Core's `CheckWitnessMalleation`
reads `vCommitPos` / the last matching output); the converse of presence. -/
theorem witnessCommitmentOk_isSome {txs : List Tx} {cb : Tx}
    (h : witnessCommitmentOk txs cb = true) :
    (witnessCommitmentOutput cb).isSome = true := by
  cases ho : witnessCommitmentOutput cb with
  | none =>
    unfold witnessCommitmentOk at h
    rw [ho] at h
    simp at h
  | some s => rfl

/-- **SWT-034 (post-activation requirement, full statement)**: with
SegWit active and witness data present, the block must both *carry* a
commitment output and have it bind the witness tree — gate-true is
exactly `commitment output present ∧ tree binds`. This strengthens
`commitmentGate_witness_true_iff` (binding only) with the existence half
Core enforces through `CheckWitnessMalleation(block, expect=true)`. -/
@[rule "SWT-034"]
theorem commitmentGate_post_activation_requires_commitment
    (segwitActive : Bool) (txs : List Tx) (cb : Tx)
    (hw : anyWitness txs = true) (hseg : segwitActive = true) :
    commitmentGate segwitActive txs cb = true ↔
      (witnessCommitmentOutput cb).isSome = true ∧
        witnessCommitmentOk txs cb = true := by
  rw [commitmentGate_witness_true_iff segwitActive txs cb hw hseg]
  exact ⟨fun h => ⟨witnessCommitmentOk_isSome h, h⟩, fun h => h.2⟩

/-- The buried-deployment predicate Core passes as `expect_witness_commitment`:
`SEGWIT_HEIGHT ≤ height` (kernel/chainparams.cpp:124; `DeploymentActiveAfter`
uses `pprev->nHeight + 1`, so the block's own height at the boundary).
This is the model's activation-height bridge for SWT-034. -/
def segwitActiveAt (height : UInt32) : Bool :=
  Bitcoin.Activation.SEGWIT_HEIGHT ≤ height

/-- The bridge is exactly the height comparison (no hidden state). -/
theorem segwitActiveAt_iff (height : UInt32) :
    segwitActiveAt height = true ↔ Bitcoin.Activation.SEGWIT_HEIGHT ≤ height := by
  unfold segwitActiveAt
  exact decide_eq_true_iff

/-- **SWT-034 (activation-height form)**: for any block at or after the
buried SegWit activation height, witness data forces a present, binding
commitment output. This ties the gate to the height predicate rather
than an uninterpreted boolean. -/
@[rule "SWT-034"]
theorem commitmentGate_post_activation_height (height : UInt32)
    (txs : List Tx) (cb : Tx)
    (hheight : Bitcoin.Activation.SEGWIT_HEIGHT ≤ height)
    (hw : anyWitness txs = true) :
    commitmentGate (segwitActiveAt height) txs cb = true ↔
      (witnessCommitmentOutput cb).isSome = true ∧
        witnessCommitmentOk txs cb = true := by
  have hseg : segwitActiveAt height = true := (segwitActiveAt_iff height).mpr hheight
  exact commitmentGate_post_activation_requires_commitment _ _ _ hw hseg

/-! ## INV-091 — the commitment gate pass/fail determination -/

/-- **INV-091**: the gate passes exactly when (activation on, a commitment
output present, and the tree binds) or (the fall-through no-witness lane
is reached and there is no witness data). -/
@[rule "INV-091"]
theorem commitmentGate_true_iff (segwitActive : Bool) (txs : List Tx)
    (cb : Tx) :
    commitmentGate segwitActive txs cb = true ↔
      (segwitActive = true ∧ (witnessCommitmentOutput cb).isSome = true ∧
        witnessCommitmentOk txs cb = true) ∨
      (anyWitness txs = false ∧
        (segwitActive = false ∨ (witnessCommitmentOutput cb).isSome = false)) := by
  cases segwitActive <;> cases hw : anyWitness txs <;>
    cases ho : witnessCommitmentOutput cb <;>
    simp [commitmentGate, hw, ho, witnessCommitmentOk]

/-- INV-091 fail lane: the gate fails exactly when activation is on and a
present commitment does not bind, or witness data meets the fall-through
no-commitment lane. -/
@[rule "INV-091"]
theorem commitmentGate_false_iff (segwitActive : Bool) (txs : List Tx)
    (cb : Tx) :
    commitmentGate segwitActive txs cb = false ↔
      (segwitActive = true ∧ (witnessCommitmentOutput cb).isSome = true ∧
        witnessCommitmentOk txs cb = false) ∨
      (anyWitness txs = true ∧
        (segwitActive = false ∨ (witnessCommitmentOutput cb).isSome = false)) := by
  cases segwitActive <;> cases hw : anyWitness txs <;>
    cases ho : witnessCommitmentOutput cb <;>
    simp [commitmentGate, hw, ho, witnessCommitmentOk]

/-! ## INV-136 — the executable two-way gate -/

/-- **INV-136**: the validation gate is literally Core's
`CheckWitnessMalleation` conditional — when expected and present the
commitment must bind, otherwise witness data is forbidden
(definitional determinacy). -/
@[rule "INV-136"]
theorem commitmentGate_eq_if (segwitActive : Bool) (txs : List Tx) (cb : Tx) :
    commitmentGate segwitActive txs cb =
      (if segwitActive && (witnessCommitmentOutput cb).isSome
       then witnessCommitmentOk txs cb else !(anyWitness txs)) := rfl

/-! ## Axiom pins (subset of the charter trio) -/

/-- info: 'BitcoinProofs.AF.PDW43b.witnessMerkleRoot_cons' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.witnessMerkleRoot_cons

/-- info: 'BitcoinProofs.AF.PDW43b.witnessMerkleRoot_nil' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.witnessMerkleRoot_nil

/-- info: 'BitcoinProofs.AF.PDW43b.witnessMerkleRoot_coinbase_only' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.witnessMerkleRoot_coinbase_only

/-- info: 'BitcoinProofs.AF.PDW43b.commitmentGate_no_witness' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.commitmentGate_no_witness

/-- info: 'BitcoinProofs.AF.PDW43b.commitmentGate_no_witness_output_reject' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.commitmentGate_no_witness_output_reject

/-- info: 'BitcoinProofs.AF.PDW43b.commitmentGate_witness_forces_binding' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.commitmentGate_witness_forces_binding

/-- info: 'BitcoinProofs.AF.PDW43b.commitmentGate_witness_true_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.commitmentGate_witness_true_iff

/-- info: 'BitcoinProofs.AF.PDW43b.commitmentGate_true_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.commitmentGate_true_iff

/-- info: 'BitcoinProofs.AF.PDW43b.commitmentGate_false_iff' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.commitmentGate_false_iff

/-- info: 'BitcoinProofs.AF.PDW43b.commitmentGate_eq_if' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.commitmentGate_eq_if

/-- info: 'BitcoinProofs.AF.PDW43b.commitmentGate_no_commitment_no_witness' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.commitmentGate_no_commitment_no_witness

/-- info: 'BitcoinProofs.AF.PDW43b.commitmentGate_no_commitment_rejects' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.commitmentGate_no_commitment_rejects

/-- info: 'BitcoinProofs.AF.PDW43b.witnessCommitmentOk_isSome' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.witnessCommitmentOk_isSome

/-- info: 'BitcoinProofs.AF.PDW43b.commitmentGate_post_activation_requires_commitment' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.commitmentGate_post_activation_requires_commitment

/-- info: 'BitcoinProofs.AF.PDW43b.segwitActiveAt' does not depend on any axioms -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.segwitActiveAt

/-- info: 'BitcoinProofs.AF.PDW43b.segwitActiveAt_iff' depends on axioms: [propext] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.segwitActiveAt_iff

/-- info: 'BitcoinProofs.AF.PDW43b.commitmentGate_post_activation_height' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms BitcoinProofs.AF.PDW43b.commitmentGate_post_activation_height

end BitcoinProofs.AF.PDW43b
