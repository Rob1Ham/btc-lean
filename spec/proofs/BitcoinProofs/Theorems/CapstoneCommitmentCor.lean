import Bitcoin.Capstone.Merkle

/-!
# BitcoinProofs.Theorems.CapstoneCommitmentCor — W17/P08: witness-commitment corollaries (sorry-free)

Corollaries of the W17 capstone's executable witness-commitment tier
(`Bitcoin.Capstone.Merkle`, direct ports of Core `consensus/merkle.cpp
@cce32b168`). All proofs are `rfl`/`simp`/case-analysis over the executable
definitions — no hashing is ever entered (a single-leaf merkle root is the
leaf itself, and the commitment gate is a two-way `if`).

C4 portfolio linkage:

| C4 ID | theorem here | statement (short) |
|-------|--------------|-------------------|
| (BIP141 pin) | `wcm_shape` / `wcm_size` | the commitment prefix is exactly the 6 bytes `6a 24 aa 21 a9 ed` |
| (BLK-014) | `witnessLeaves_single_cb` | the coinbase-only leaf vector is `[0x00…00]` |
| (BLK-014+BLK-013 cor) | `witnessMerkleRoot_single_cb` | a coinbase-only block's witness root is `0x00…00` (root of a single leaf = the leaf; sha256d never entered) |
| (BLK-013 cor) | `merkleRootOfF_singleton` / `merkleRootOf_singleton` | fuel lemma: any positive fuel gives a singleton level its element back |
| (BLK-019) | `commitmentGate_no_witness_no_output` / `commitmentGate_true_of_no_witness_no_output` | without witness txs the gate is exactly "no commitment output present" (`unexpected-witness`) |
| (BLK-020) | `commitmentGate_forces_binding` | with witness txs the gate IS `witnessCommitmentOk` — a witness block MUST bind its tree |
| (BLK-018) | `commitmentNonceOk_shape` | the nonce check is literally the singleton-match on the coinbase scriptWitness |
| (BLK-018 cor) | `commitmentNonceOk_ok_ne_nil` / `commitmentNonceOk_ok_head_32` | nonce-ok ⇒ the coinbase witness is nonempty with a 32-byte head element |
| (BLK-017 cor) | `witnessCommitmentOk_needs_output` | `witnessCommitmentOk = true` presupposes a commitment output exists |

Dependencies: `Bitcoin.Capstone.Merkle` (all sorry-free executable defs),
`Bitcoin.Data.zeroBytes` (via `Bitcoin.Data.Tx`).

Axiom footprints (verified via `#print axioms` in the W17/P08 scratch
area; pins are NOT asserted in this file):

| theorem | axioms |
|---------|--------|
| `wcm_shape` | — (none) |
| `wcm_size` | — (none) |
| `witnessLeaves_single_cb` | propext, Quot.sound |
| `merkleRootOfF_singleton` | propext, Quot.sound |
| `merkleRootOf_singleton` | propext, Quot.sound |
| `witnessMerkleRoot_single_cb` | propext, Quot.sound |
| `commitmentGate_no_witness_no_output` | propext, Classical.choice, Quot.sound |
| `commitmentGate_true_of_no_witness_no_output` | propext, Classical.choice, Quot.sound |
| `commitmentGate_forces_binding` | propext, Classical.choice, Quot.sound |
| `commitmentNonceOk_shape` | propext |
| `commitmentNonceOk_ok_ne_nil` | propext |
| `commitmentNonceOk_ok_head_32` | propext |
| `witnessCommitmentOk_needs_output` | propext, Classical.choice, Quot.sound |

The `Classical.choice` footprints are INHERITED from the core layer
generalized from: the core defs `Bitcoin.Capstone.Merkle.commitmentGate`,
`witnessCommitmentOk` and `witnessCommitmentOutput` themselves already
depend on `[propext, Classical.choice, Quot.sound]` (their equational
lemmas route through `List`/`ByteArray` simp lemmas); no choice is
introduced by these proofs.
-/

namespace BitcoinProofs.Theorems.CapstoneCommitment

open Bitcoin.Capstone.Merkle Bitcoin.Data

/-! ## The commitment prefix (BIP141) -/

/-- The 6-byte commitment script prefix `OP_RETURN OP_PUSH36 0x24
aa21a9ed` is exactly that byte vector (BIP141 §commitment). -/
theorem wcm_shape :
    wcm = ⟨#[0x6a, 0x24, 0xaa, 0x21, 0xa9, 0xed]⟩ := rfl

/-- The commitment prefix is 6 bytes long. -/
theorem wcm_size : wcm.size = 6 := by
  rw [wcm_shape]; rfl

/-! ## The witness tree leaves (BLK-014) -/

/-- BLK-014 (leaf vector): a block whose only transaction is the coinbase
has the single leaf `0x00…00` — the coinbase's leaf is the null hash by
definition, and there are no other txs to contribute `wtxid`s. -/
theorem witnessLeaves_single_cb (cb : Tx) :
    witnessLeaves [cb] = [zeroBytes 32] := rfl

/-! ## Single-leaf roots (BLK-013 corollaries) -/

/-- Fuel lemma for `ComputeMerkleRoot`: at any positive fuel a
singleton level IS its own root — `merkleRootOfF`'s `| _+1, [a] => a`
branch fires before any pairing, so `sha256d` is never entered. -/
theorem merkleRootOfF_singleton (f : Nat) (a : ByteArray) :
    merkleRootOfF (f + 1) [a] = a := rfl

/-- BLK-013 corollary: the merkle root of a single-element list is that
element (no hashing — the loop terminates immediately). -/
theorem merkleRootOf_singleton (a : ByteArray) :
    merkleRootOf [a] = a := by
  rw [merkleRootOf]; exact merkleRootOfF_singleton _ a

/-- BLK-014+BLK-013 corollary: a block whose only transaction is the
coinbase has witness merkle root `0x00…00` — the leaf itself, since the
root fold stops at the first (singleton) level. -/
theorem witnessMerkleRoot_single_cb (cb : Tx) :
    witnessMerkleRoot [cb] = zeroBytes 32 := by
  rw [witnessMerkleRoot, witnessLeaves_single_cb, merkleRootOf_singleton]

/-! ## The commitment gate (BLK-019 / BLK-020) -/

/-- BLK-019: with NO witness txs anywhere in the block, the commitment
gate is exactly "no commitment output is present" — a commitment script
in a witness-free block is the `unexpected-witness` error. -/
theorem commitmentGate_no_witness_no_output (segwitActive : Bool)
    (txs : List Tx) (cb : Tx)
    (h : anyWitness txs = false) :
    commitmentGate segwitActive txs cb =
      (if segwitActive && (witnessCommitmentOutput cb).isSome then
         witnessCommitmentOk txs cb else true) := by
  simp [commitmentGate, h]

/-- BLK-019 corollary: a witness-free block with no commitment output
passes the gate regardless of activation (the standard pre-SegWit shape). -/
theorem commitmentGate_true_of_no_witness_no_output (segwitActive : Bool)
    (txs : List Tx) (cb : Tx)
    (h : anyWitness txs = false) (ho : witnessCommitmentOutput cb = none) :
    commitmentGate segwitActive txs cb = true := by
  simp [commitmentGate, h, ho]

/-- BLK-020: when the block DOES carry witness txs, the gate is literally
`witnessCommitmentOk` — a witness block must BIND its witness tree: the
gate passes only if `SHA256d(witnessRoot ‖ reserved) = script[6..38]`. -/
theorem commitmentGate_forces_binding (segwitActive : Bool)
    (txs : List Tx) (cb : Tx)
    (h : anyWitness txs = true) (hseg : segwitActive = true) :
    commitmentGate segwitActive txs cb = witnessCommitmentOk txs cb := by
  subst hseg
  cases ho : witnessCommitmentOutput cb <;>
    simp [commitmentGate, h, ho, witnessCommitmentOk]

/-! ## The commitment nonce (BLK-018) -/

/-- BLK-018 (unfolded): the nonce check is exactly the singleton-match on
the coinbase's scriptWitness — precisely one element, and that element
(the nonce) must be 32 bytes. -/
theorem commitmentNonceOk_shape (cb : Tx) :
    commitmentNonceOk cb
      = match cb.witness.getD 0 [] with
        | [n] => n.size = 32
        | _ => False := rfl

/-- BLK-018 corollary: if the nonce check passes, the coinbase carries a
witness at all (the singleton match needs a head element). -/
theorem commitmentNonceOk_ok_ne_nil (cb : Tx) (h : commitmentNonceOk cb = true) :
    cb.witness ≠ [] := by
  cases hl : cb.witness with
  | nil =>
    exfalso
    rw [commitmentNonceOk, hl] at h
    simp at h
  | cons w rest =>
    intro hne
    exact absurd hne (List.cons_ne_nil w rest)

/-- BLK-018 corollary: if the nonce check passes, the head witness
element is a stack of exactly one 32-byte item — the nonce (its content
is unconstrained, `bad-witness-nonce-size` only checks the size). -/
theorem commitmentNonceOk_ok_head_32 (cb : Tx) (h : commitmentNonceOk cb = true) :
    ∃ (nonce : ByteArray) (rest : List WitnessStack),
      cb.witness = ([nonce] : WitnessStack) :: rest ∧ nonce.size = 32 := by
  cases hl : cb.witness with
  | nil =>
    exfalso
    rw [commitmentNonceOk, hl] at h
    simp at h
  | cons w rest =>
    cases hw : w with
    | nil =>
      exfalso
      rw [commitmentNonceOk, hl, hw] at h
      simp at h
    | cons n0 ws =>
      cases hws : ws with
      | nil =>
        refine ⟨n0, rest, rfl, ?_⟩
        · rw [commitmentNonceOk, hl, hw, hws] at h
          simpa using h
      | cons n1 ws' =>
        exfalso
        rw [commitmentNonceOk, hl, hw, hws] at h
        simp at h

/-! ## The commitment binding (BLK-017 corollary) -/

/-- BLK-017 corollary: `witnessCommitmentOk = true` presupposes that a
commitment output exists at all — the `none` branch of
`witnessCommitmentOutput` yields `false` unconditionally. -/
theorem witnessCommitmentOk_needs_output (txs : List Tx) (cb : Tx)
    (h : witnessCommitmentOk txs cb = true) :
    (witnessCommitmentOutput cb).isSome := by
  cases hw : witnessCommitmentOutput cb with
  | none =>
    rw [witnessCommitmentOk, hw] at h
    simp at h
  | some s => simp

end BitcoinProofs.Theorems.CapstoneCommitment
