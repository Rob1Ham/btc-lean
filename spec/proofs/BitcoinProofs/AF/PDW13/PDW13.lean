import Bitcoin.Capstone.Merkle
import Bitcoin.Block.Pow
import BitcoinProofs.AF.PDW13.WitnessCommitmentReserved

/-! # PDW13.lean

Five sorry-free promotion theorems, one per claimed rules.yaml row
(claim v1 = commit 4fd8dda; the PD02 Table-1 ErrMap attr+flip
remainder head-5 = PDW12 v2's next-tier list):

* **BLK-017** `witnessCommitmentOk` (Capstone/Merkle.lean:146) →
  `witnessCommitmentOk_eq_true` (the row equation verbatim) +
  `witnessCommitmentOk_none` (fail-closed none-lane).
* **BLK-018** `commitmentNonceOk` (Capstone/Merkle.lean:157) →
  `commitmentNonceOk_eq_true` (P9/P10 full iff) + 3 fail-closed
  pins (`_witness_nil`, `_head_nil`, `_head_multi`).
* **BLK-019** `commitmentGate` (Capstone/Merkle.lean:170) →
  `commitmentGate_unexpected_witness` (the row's own reject face) +
  `commitmentGate_eq` (P10 determination) +
  `commitmentGate_witness_free_pass` (Cor:112 restated).
* **BLK-055** `timewarpOk` (Block/Pow.lean:211) →
  `timewarpOk_true_iff` (P11 flag-gate iff).
* **BLK-057** `timeNotTooOld` (Block/Pow.lean:242) →
  `timeNotTooOld_eq` (P12 STRICT iff, the general law).

Route B (PDW11 21f0745 / PDW12 04c27a7 pattern): zero core
writes, theorems over the exact core gates (no statement
weakening), tags `@[rule "row"]` ride these decls. The module is
deliberately NOT imported by the `BitcoinProofs` root (the
PDW12-AF isolation pattern) — own-target built, outside
`core/**` (sorry_lint scans core only). BLK-020 (same
lean_target `commitmentGate`) = the next head, NOT tagged
here (F-PDW13 hand-off, PDW11/PDW12 non-goal discipline). -/

namespace BitcoinProofs.AF.PDW13

/-! ## BLK-017 — `witnessCommitmentOk` (V:3898-3906):
`SHA256d(witnessRoot ‖ reserved) = script[6..38]`, where `reserved` is
the coinbase witness reserved value (exactly one 32-byte item).

The equation lane (some-output + some-reserved): the gate IS the row
equation — no `bytesBEq`-folding (the binding soundness itself = the
real-SHA seam, out of tier P5). The none-lane: no commitment output or
no valid reserved value ⇒ the gate fails CLOSED. -/

@[rule "BLK-017"]
theorem witnessCommitmentOk_eq_true (txs : List Bitcoin.Data.Tx)
    (cb : Bitcoin.Data.Tx) (script reserved : ByteArray)
    (h : Bitcoin.Capstone.Merkle.witnessCommitmentOutput cb = some script)
    (hr : Bitcoin.Capstone.Merkle.witnessReservedValue cb = some reserved) :
    Bitcoin.Capstone.Merkle.witnessCommitmentOk txs cb
      = Bitcoin.Data.bytesBEq (Bitcoin.Crypto.Seam.Hash.sha256d
          (Bitcoin.Capstone.Merkle.witnessMerkleRoot txs
            ++ reserved)) (script.extract 6 38) := by
  rw [Bitcoin.Capstone.Merkle.witnessCommitmentOk, h, hr]

@[rule "BLK-017"]
theorem witnessCommitmentOk_none (txs : List Bitcoin.Data.Tx)
    (cb : Bitcoin.Data.Tx)
    (h : Bitcoin.Capstone.Merkle.witnessCommitmentOutput cb = none) :
    Bitcoin.Capstone.Merkle.witnessCommitmentOk txs cb = false := by
  rw [Bitcoin.Capstone.Merkle.witnessCommitmentOk, h]

/-! ## BLK-018 — `commitmentNonceOk` (V:3884-3892,
`bad-witness-nonce-size`): the coinbase scriptWitness is exactly
one 32-byte element (content = the nonce, unconstrained).

The full iff (P9/P10): gate = true ⇔ the witness is a nonempty
stack-list whose HEAD stack is the singleton `[nonce]` with
`nonce.size = 32` — the `match cb.witness.getD 0 []` singleton
match (`getD 0 []` = head stack or the empty default). Fail
closed on: no witness stacks at all / empty head stack /
multi-element head stack (the `_ => false` arms). Cor
`commitmentNonceOk_shape/_ok_ne_nil/_ok_head_32` =
the →-directions + shape; the iff = the promoted row law. -/

@[rule "BLK-018"]
theorem commitmentNonceOk_eq_true (cb : Bitcoin.Data.Tx) :
    Bitcoin.Capstone.Merkle.commitmentNonceOk cb = true ↔
      ∃ (nonce : ByteArray) (rest : List Bitcoin.Data.WitnessStack),
        cb.witness = ([nonce] : Bitcoin.Data.WitnessStack) :: rest ∧ nonce.size = 32 := by
  constructor
  · intro h
    cases hl : cb.witness with
    | nil =>
      exfalso
      rw [Bitcoin.Capstone.Merkle.commitmentNonceOk, hl] at h
      simp at h
    | cons w rest =>
      cases hw : w with
      | nil =>
        exfalso
        rw [Bitcoin.Capstone.Merkle.commitmentNonceOk, hl, hw] at h
        simp at h
      | cons n0 ws =>
        cases hws : ws with
        | nil =>
          refine ⟨n0, rest, rfl, ?_⟩
          · rw [Bitcoin.Capstone.Merkle.commitmentNonceOk, hl, hw, hws] at h
            simpa using h
        | cons n1 ws' =>
          exfalso
          rw [Bitcoin.Capstone.Merkle.commitmentNonceOk, hl, hw, hws] at h
          simp at h
  · rintro ⟨nonce, rest, heq, hs⟩
    rw [Bitcoin.Capstone.Merkle.commitmentNonceOk, heq]
    simp [hs]

@[rule "BLK-018"]
theorem commitmentNonceOk_witness_nil {cb : Bitcoin.Data.Tx}
    (hl : cb.witness = []) :
    Bitcoin.Capstone.Merkle.commitmentNonceOk cb = false := by
  rw [Bitcoin.Capstone.Merkle.commitmentNonceOk, hl]; rfl

@[rule "BLK-018"]
theorem commitmentNonceOk_head_nil {cb : Bitcoin.Data.Tx}
    {w : Bitcoin.Data.WitnessStack} {rest : List Bitcoin.Data.WitnessStack}
    (hw : cb.witness = w :: rest) (hl : w = []) :
    Bitcoin.Capstone.Merkle.commitmentNonceOk cb = false := by
  rw [Bitcoin.Capstone.Merkle.commitmentNonceOk, hw, hl]; rfl

@[rule "BLK-018"]
theorem commitmentNonceOk_head_multi {cb : Bitcoin.Data.Tx}
    {w : Bitcoin.Data.WitnessStack} {rest : List Bitcoin.Data.WitnessStack}
    {n0 n1 : ByteArray} {ws : List ByteArray}
    (hw : cb.witness = w :: rest) (hl : w = n0 :: n1 :: ws) :
    Bitcoin.Capstone.Merkle.commitmentNonceOk cb = false := by
  rw [Bitcoin.Capstone.Merkle.commitmentNonceOk, hw, hl]; rfl

/-! ## BLK-019 — `commitmentGate` (V:3908-3916,
`unexpected-witness`): witness txs exist iff a valid commitment
does. The row's own reject face: witness data present AND no
commitment output ⇒ the gate fails (the `unexpected-witness`
error). Determination (`_eq`): the gate is the flag-conditional two-way `if`
verbatim (P10). Witness-free + no-output is the flag-independent pass
shape (Cor `commitmentGate_true_of_no_witness_no_output` restated).
The explicit `segwitActive` argument is the activation condition: ON +
a commitment output forces binding, OFF takes Core's no-witness
fall-through (validation.cpp:4177). -/

@[rule "BLK-019"]
theorem commitmentGate_unexpected_witness (segwitActive : Bool)
    (txs : List Bitcoin.Data.Tx)
    (cb : Bitcoin.Data.Tx) (hw : Bitcoin.Capstone.Merkle.anyWitness txs = true)
    (ho : Bitcoin.Capstone.Merkle.witnessCommitmentOutput cb = none) :
    Bitcoin.Capstone.Merkle.commitmentGate segwitActive txs cb = false := by
  cases segwitActive <;>
    simp [Bitcoin.Capstone.Merkle.commitmentGate, hw, ho]

@[rule "BLK-019"]
theorem commitmentGate_eq (segwitActive : Bool) (txs : List Bitcoin.Data.Tx)
    (cb : Bitcoin.Data.Tx) :
    Bitcoin.Capstone.Merkle.commitmentGate segwitActive txs cb
      = (if segwitActive &&
             (Bitcoin.Capstone.Merkle.witnessCommitmentOutput cb).isSome
         then Bitcoin.Capstone.Merkle.witnessCommitmentOk txs cb
         else !(Bitcoin.Capstone.Merkle.anyWitness txs)) := rfl

@[rule "BLK-019"]
theorem commitmentGate_witness_free_pass (segwitActive : Bool)
    (txs : List Bitcoin.Data.Tx)
    (cb : Bitcoin.Data.Tx) (hw : Bitcoin.Capstone.Merkle.anyWitness txs = false)
    (ho : Bitcoin.Capstone.Merkle.witnessCommitmentOutput cb = none) :
    Bitcoin.Capstone.Merkle.commitmentGate segwitActive txs cb = true := by
  cases segwitActive <;>
    simp [Bitcoin.Capstone.Merkle.commitmentGate, hw, ho]

/-! ## BLK-055 — `timewarpOk` (V:4103-4113, CC:35, the BIP94
`time-timewarp-attack` guard): P11 flag-gate iff — on a period
boundary under `enforce_BIP94`, `blockTime ≥ prevTime − 600`;
off-networks / non-boundary heights unconstrained. Bip94Tests
`timewarpOk_true_iff` restated (P13 PDW12 route-B); PDW3
`timewarpOk_reject` [propext] = the reject lane (INV-100). -/

@[rule "BLK-055"]
theorem timewarpOk_true_iff {enforce atBoundary : Bool} {bt pt : UInt32} :
    Bitcoin.Block.Pow.timewarpOk enforce atBoundary bt pt = true ↔
      enforce = false ∨ atBoundary = false ∨ pt.toNat ≤ bt.toNat + 600 := by
  unfold Bitcoin.Block.Pow.timewarpOk
  cases enforce <;> cases atBoundary <;> simp <;> omega <;> omega

/-! ## BLK-057 — `timeNotTooOld` (V:4100-4102,
`time-too-old`): P12 STRICT iff — `blockTime > MTP(prev)`
strictly (equality rejects). The Bip113MTP:202 S-evidence was a
2-point decide vector only; this = the general law. -/

@[rule "BLK-057"]
theorem timeNotTooOld_eq {bt mtp : UInt32} :
    Bitcoin.Block.Pow.timeNotTooOld bt mtp = true ↔ mtp.toNat < bt.toNat := by
  simp [Bitcoin.Block.Pow.timeNotTooOld, UInt32.lt_iff_toNat_lt]

end BitcoinProofs.AF.PDW13
