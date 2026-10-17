import Bitcoin.Ledger.Interface

/-!
# CapstoneBip30Loop — the 2465-2475 overlap-loop theorem (TXV-063)

Core validation.cpp @cce32b168:2429/2465-2475. The BIP30 duplicate-txid
ban is ONE pre-block loop on the PRISTINE view: for every tx of the
block, for every output index, `view.HaveCoin(COutPoint(txid, o))`
rejects the block with `bad-txns-BIP30`. Post-D4c-2 the tree has exactly
that shape: `bip30Collision` (every vout, unfiltered, pristine) inside
`bip30BlockCollision`, gated by `bip30Enforced` in `applyBlockU/L`, and
the inner per-tx folds are BIP30-free.

These theorems are the theorem-tier statement of the loop: the block
fails with `badTxnsBIP30` IFF enforcement is on AND some tx of the block
re-creates an outpoint already live in the pristine view.
-/

open Bitcoin.Data
open Bitcoin.Ledger

namespace BitcoinProofs.Theorems.CapstoneBip30Loop

/-- `bip30Collision` unfolds to the verbatim Core inner loop test. -/
theorem bip30Collision_eq_true_iff (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32) :
    bip30Collision u tx key height = true ↔
      ∃ o, o < tx.vout.length ∧ (u (key OutPoint.null (UInt32.ofNat o))).isSome := by
  unfold bip30Collision
  rw [List.any_eq_true]
  constructor
  · rintro ⟨o, ho, hp⟩
    exact ⟨o, List.mem_range.mp ho, by simpa using hp⟩
  · rintro ⟨o, ho, hp⟩
    exact ⟨o, List.mem_range.mpr ho, by simpa using hp⟩

/-- `bip30BlockCollision` = Core's `for (tx : block.vtx)` loop, verbatim. -/
theorem bip30BlockCollision_eq_true_iff (u : UtxoSet) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) :
    bip30BlockCollision u kf txs height = true ↔
      ∃ tx ∈ txs, ∃ o, o < tx.vout.length ∧
        (u (kf tx OutPoint.null (UInt32.ofNat o))).isSome := by
  induction txs with
  | nil => simp [bip30BlockCollision]
  | cons tx rest ih =>
    rw [bip30BlockCollision, Bool.or_eq_true, bip30Collision_eq_true_iff, ih]
    constructor
    · rintro (h | ⟨t, ht, ho⟩)
      · exact ⟨tx, List.mem_cons_self, h⟩
      · exact ⟨t, List.mem_cons_of_mem _ ht, ho⟩
    · rintro ⟨t, ht, ho⟩
      rcases List.mem_cons.mp ht with rfl | hmem
      · exact Or.inl ho
      · exact Or.inr ⟨t, hmem, ho⟩

/-- The post-D4c-2 per-tx step can never raise `badTxnsBIP30`. -/
theorem applyTxStepU_ne_badTxnsBIP30 (u : UtxoSet) (tx : Tx) (key : Key) (height : UInt32) :
    applyTxStepU u tx key height ≠ Except.error BlockError.badTxnsBIP30 := by
  unfold applyTxStepU
  split
  · simp
  · split
    · simp
    · split <;> simp

/-- Same, assoc tier. -/
theorem applyTxStepL_ne_badTxnsBIP30 (l : List (OutPoint × Coin)) (tx : Tx)
    (key : Key) (height : UInt32) :
    applyTxStepL l tx key height ≠ Except.error BlockError.badTxnsBIP30 := by
  unfold applyTxStepL
  split
  · simp
  · split
    · simp
    · split <;> simp

/-- The inner point fold is BIP30-free. -/
theorem applyBlockFoldU_ne_badTxnsBIP30 (u : UtxoSet) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) :
    applyBlockFoldU u kf txs height ≠ Except.error BlockError.badTxnsBIP30 := by
  induction txs generalizing u with
  | nil => simp [applyBlockFoldU]
  | cons tx rest ih =>
    rw [applyBlockFoldU]
    cases h : applyTxStepU u tx (kf tx) height with
    | error e =>
      intro he
      exact applyTxStepU_ne_badTxnsBIP30 u tx (kf tx) height (h.trans he)
    | ok u' =>
      rw [show (Except.ok u').bind (fun u' => applyBlockFoldU u' kf rest height) =
          applyBlockFoldU u' kf rest height from rfl]
      exact ih u'

/-- The inner assoc fold is BIP30-free. -/
theorem applyBlockFoldL_ne_badTxnsBIP30 (l : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) :
    applyBlockFoldL l kf txs height ≠ Except.error BlockError.badTxnsBIP30 := by
  induction txs generalizing l with
  | nil => simp [applyBlockFoldL]
  | cons tx rest ih =>
    rw [applyBlockFoldL]
    cases h : applyTxStepL l tx (kf tx) height with
    | error e =>
      intro he
      exact applyTxStepL_ne_badTxnsBIP30 l tx (kf tx) height (h.trans he)
    | ok l' =>
      rw [show (Except.ok l').bind (fun l' => applyBlockFoldL l' kf rest height) =
          applyBlockFoldL l' kf rest height from rfl]
      exact ih l'

/-- **The overlap-loop theorem (point tier)**: the block is rejected with
`bad-txns-BIP30` iff enforcement is on and some tx output re-creates an
outpoint live in the pristine view. -/
theorem applyBlockU_loop_iff (u : UtxoSet) (kf : Tx → Key) (txs : List Tx)
    (height : UInt32) :
    applyBlockU u kf txs height = Except.error BlockError.badTxnsBIP30 ↔
      bip30Enforced height = true ∧
        ∃ tx ∈ txs, ∃ o, o < tx.vout.length ∧
          (u (kf tx OutPoint.null (UInt32.ofNat o))).isSome := by
  unfold applyBlockU
  by_cases hg : (bip30BlockCollision u kf txs height && bip30Enforced height) = true
  · rw [ite_eq_left hg]
    obtain ⟨hc, he⟩ := Bool.and_eq_true_iff.mp hg
    exact ⟨fun _ => ⟨he, (bip30BlockCollision_eq_true_iff u kf txs height).mp hc⟩,
      fun _ => rfl⟩
  · rw [ite_eq_right hg]
    constructor
    · intro he
      exact absurd he (applyBlockFoldU_ne_badTxnsBIP30 u kf txs height)
    · rintro ⟨he, hc⟩
      exact absurd (Bool.and_eq_true_iff.mpr
        ⟨(bip30BlockCollision_eq_true_iff u kf txs height).mpr hc, he⟩) hg

/-- **The overlap-loop theorem (assoc/executable tier)** — the TXV-063
statement: exactly Core's 2466-2475 pre-block pristine loop. -/
@[rule "TXV-063"]
theorem applyBlockL_loop_iff (l : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) :
    applyBlockL l kf txs height = Except.error BlockError.badTxnsBIP30 ↔
      bip30Enforced height = true ∧
        ∃ tx ∈ txs, ∃ o, o < tx.vout.length ∧
          (viewOf l (kf tx OutPoint.null (UInt32.ofNat o))).isSome := by
  unfold applyBlockL
  by_cases hg : (bip30BlockCollision (viewOf l) kf txs height && bip30Enforced height) = true
  · rw [ite_eq_left hg]
    obtain ⟨hc, he⟩ := Bool.and_eq_true_iff.mp hg
    exact ⟨fun _ => ⟨he, (bip30BlockCollision_eq_true_iff (viewOf l) kf txs height).mp hc⟩,
      fun _ => rfl⟩
  · rw [ite_eq_right hg]
    constructor
    · intro he
      exact absurd he (applyBlockFoldL_ne_badTxnsBIP30 l kf txs height)
    · rintro ⟨he, hc⟩
      exact absurd (Bool.and_eq_true_iff.mpr
        ⟨(bip30BlockCollision_eq_true_iff (viewOf l) kf txs height).mpr hc, he⟩) hg

end BitcoinProofs.Theorems.CapstoneBip30Loop
