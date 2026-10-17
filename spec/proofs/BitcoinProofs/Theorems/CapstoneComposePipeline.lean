import BitcoinProofs.Theorems.CapstonePipelineCor
import BitcoinProofs.Theorems.CapstoneBip30Loop

/-!
# BitcoinProofs.Theorems.CapstoneComposePipeline — Phase-3 pipeline composition

Flagship shape: one block-application step succeeds iff (a) the pre-block
BIP30 overlap check is quiet, (b) every tx satisfies its STATE-based ledger
predicate (coinbase, or inputs available + maturity) on the view threaded by
the preceding txs, and (c) the resulting UTXO list is the reference update
fold. The sound direction is specialised to the full `validateBlock`
pipeline; undo-data consistency is stated at the per-step tier.

Residual: `validateBlock`'s header/structure gates mention module-private
definitions, so only its sound direction is bridged (P16-5); the iff is
stated at `applyBlockL`, the ledger tier both sides share.
-/

namespace BitcoinProofs.Theorems.CapstoneComposePipeline

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Capstone.Block
open BitcoinProofs.Theorems.CapstonePipeline
open Bitcoin.Consensus (checkTransaction)
open Bitcoin.Serialization (decodeBlock)
open BitcoinProofs.Theorems.CapstoneBip30Loop

/-- `¬ (!b = true)` gives `b = true` (the `split` branch hypothesis shape). -/
theorem not_not_true {b : Bool} (h : ¬ ((!b) = true)) : b = true := by
  cases b <;> simp_all

/-- The three state predicates `applyTxStepL` actually enforces. Note
`checkTransaction` is NOT here: it is the capstone tier's own stateless gate
(`applyTx`), already bridged by `applyTxs_ok_checkTx_all`. -/
def TxStatefulOk (l : List (OutPoint × Coin)) (tx : Tx) (height : UInt32) : Prop :=
  tx.isCoinBase = true ∨
    (inputsAvailable (viewOf l) tx = true ∧ maturityOk (viewOf l) tx height = true)

/-- **Per-step exactness (iff)**: the W12 ledger step succeeds iff the
state predicate holds, and then the output is EXACTLY the reference
`updateCoinsL`. -/
theorem applyTxStepL_ok_iff (l l' : List (OutPoint × Coin)) (tx : Tx)
    (key : Key) (height : UInt32) :
    applyTxStepL l tx key height = Except.ok l' ↔
      TxStatefulOk l tx height ∧ l' = updateCoinsL l tx key height := by
  unfold applyTxStepL TxStatefulOk
  constructor
  · intro h
    split at h
    · rename_i hcb
      exact ⟨Or.inl hcb, (Except.ok.inj h).symm⟩
    · split at h
      · simp at h
      · split at h
        · simp at h
        · rename_i hin hmat
          exact ⟨Or.inr ⟨not_not_true hin, not_not_true hmat⟩,
            (Except.ok.inj h).symm⟩
  · rintro ⟨hp, rfl⟩
    rcases hp with hcb | ⟨hin, hmat⟩
    · rw [if_pos hcb]
    · by_cases hcb : tx.isCoinBase = true
      · rw [if_pos hcb]
      · rw [if_neg hcb, if_neg (by simp [hin]), if_neg (by simp [hmat])]

/-! ## The fold composition -/

/-- Relational per-tx fold: the exact sequence of `applyTxStepL` successes. -/
def FoldL (l : List (OutPoint × Coin)) (kf : Tx → Key) :
    List Tx → UInt32 → List (OutPoint × Coin) → Prop
  | [], _, l' => l' = l
  | tx :: rest, height, l' =>
      ∃ l₁, applyTxStepL l tx (kf tx) height = Except.ok l₁ ∧
        FoldL l₁ kf rest height l'

/-- The reference update fold: the deterministic `updateCoinsL` chain. -/
def updateFoldL (l : List (OutPoint × Coin)) (kf : Tx → Key) :
    List Tx → UInt32 → List (OutPoint × Coin)
  | [], _ => l
  | tx :: rest, height =>
      updateFoldL (updateCoinsL l tx (kf tx) height) kf rest height

/-- Per-tx state predicates along the view threaded by the preceding txs. -/
def FoldPred (l : List (OutPoint × Coin)) (kf : Tx → Key) :
    List Tx → UInt32 → Prop
  | [], _ => True
  | tx :: rest, height =>
      TxStatefulOk l tx height ∧
        FoldPred (updateCoinsL l tx (kf tx) height) kf rest height

/-- The relational fold is exactly "all state predicates + reference update". -/
theorem foldL_iff_foldPred (l l' : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) :
    FoldL l kf txs height l' ↔
      FoldPred l kf txs height ∧ l' = updateFoldL l kf txs height := by
  induction txs generalizing l with
  | nil => simp [FoldL, FoldPred, updateFoldL]
  | cons tx rest ih =>
      constructor
      · rintro ⟨l₁, hs, hf⟩
        obtain ⟨hp, rfl⟩ := (applyTxStepL_ok_iff l l₁ tx (kf tx) height).mp hs
        exact ⟨⟨hp, ((ih (updateCoinsL l tx (kf tx) height)).mp hf).1⟩,
          ((ih (updateCoinsL l tx (kf tx) height)).mp hf).2⟩
      · rintro ⟨⟨hp, hpred⟩, rfl⟩
        exact ⟨updateCoinsL l tx (kf tx) height,
          (applyTxStepL_ok_iff l (updateCoinsL l tx (kf tx) height) tx
            (kf tx) height).mpr ⟨hp, rfl⟩,
          (ih (updateCoinsL l tx (kf tx) height)).mpr ⟨hpred, rfl⟩⟩

/-- **Fold exactness (iff)**: `applyBlockFoldL` succeeds iff the relational
fold holds. -/
theorem applyBlockFoldL_ok_iff (l l' : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) :
    applyBlockFoldL l kf txs height = Except.ok l' ↔ FoldL l kf txs height l' := by
  induction txs generalizing l with
  | nil => simp [applyBlockFoldL, FoldL, eq_comm]
  | cons tx rest ih =>
      rw [applyBlockFoldL]
      constructor
      · intro h
        cases hs : applyTxStepL l tx (kf tx) height with
        | error e => rw [hs] at h; cases h
        | ok l₁ => rw [hs] at h; exact ⟨l₁, hs, (ih l₁).mp h⟩
      · rintro ⟨l₁, hs, hf⟩
        rw [hs]
        exact (ih l₁).mpr hf

/-- **Fold composition**: `applyBlockFoldL` succeeds iff every tx satisfies
its state predicate on the threaded view AND the output is the reference
update fold. -/
theorem applyBlockFoldL_ok_iff_pred (l l' : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) :
    applyBlockFoldL l kf txs height = Except.ok l' ↔
      FoldPred l kf txs height ∧ l' = updateFoldL l kf txs height := by
  rw [applyBlockFoldL_ok_iff, foldL_iff_foldPred]

/-! ## Bridging the capstone tier to the ledger tier -/

/-- An `applyTx` success exposes its ledger step: the state change it
threaded is exactly one `applyTxStepL` success. -/
theorem applyTx_ok_stepL (height : UInt32) (tx : Tx) (i : Nat)
    (l l' : List (OutPoint × Coin)) (a b : Nat)
    (h : Bitcoin.Capstone.Block.applyTx height tx i l = Except.ok (l', a, b)) :
    applyTxStepL l tx (txidKey tx) height = Except.ok l' := by
  by_cases hchk : checkTransaction tx = none
  · by_cases hcb : tx.isCoinBase = true
    · cases hs : applyTxStepL l tx (txidKey tx) height with
      | ok l₁ =>
          have heq : Bitcoin.Capstone.Block.applyTx height tx i l
              = Except.ok (l₁, 0, 0) := by
            unfold Bitcoin.Capstone.Block.applyTx
            simp [hchk, hcb, hs]
          rw [heq] at h
          simp only [Except.ok.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, _, _⟩ := h
          rfl
      | error e =>
          rw [applyTx_ledger_first_coinbase height tx i l e hcb hchk hs] at h
          cases h
    · have hcb' : tx.isCoinBase = false := by
        cases hx : tx.isCoinBase <;> simp_all
      cases hv : verifyTxInputs height tx i l with
      | error e =>
          rw [applyTx_script_first height tx i l e hcb' hchk hv] at h
          cases h
      | ok c =>
          obtain ⟨x, y⟩ := c
          cases hs : applyTxStepL l tx (txidKey tx) height with
          | ok l₁ =>
              have heq : Bitcoin.Capstone.Block.applyTx height tx i l
                  = Except.ok (l₁, x, y) := by
                unfold Bitcoin.Capstone.Block.applyTx
                simp [hchk, hcb', hv, hs]
              rw [heq] at h
              simp only [Except.ok.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, _, _⟩ := h
              rfl
          | error e =>
              rw [applyTx_ledger_first height tx i l e x y hcb' hchk hv hs] at h
              cases h
  · cases hc : checkTransaction tx with
    | none => exact absurd hc hchk
    | some e =>
        rw [applyTx_eq, hc] at h
        simp at h

/-- Peel one `applyTx` off an `applyTxs` success. -/
theorem applyTxs_cons_inv (height : UInt32) (tx : Tx) (rest : List Tx)
    (i okN unjN : Nat) (l l' : List (OutPoint × Coin)) (okN' unjN' : Nat)
    (h : applyTxs height (tx :: rest) i l okN unjN = Except.ok (l', okN', unjN')) :
    ∃ (l₁ : List (OutPoint × Coin)) (a b : Nat),
      Bitcoin.Capstone.Block.applyTx height tx i l = Except.ok (l₁, a, b) ∧
      applyTxs height rest (i + 1) l₁ (okN + a) (unjN + b) =
        Except.ok (l', okN', unjN') := by
  simp only [applyTxs] at h
  cases ha : Bitcoin.Capstone.Block.applyTx height tx i l with
  | error e => rw [ha] at h; cases h
  | ok p =>
      obtain ⟨l₁, a, b⟩ := p
      rw [ha] at h
      exact ⟨l₁, a, b, rfl, h⟩

/-- **Pipeline-to-ledger bridge**: a successful capstone `applyTxs` is a
successful W12 `applyBlockFoldL` at the real `txidKey` with the same list. -/
theorem applyTxs_ok_applyBlockFoldL (height : UInt32) :
    ∀ (txs : List Tx) (i okN unjN : Nat) (l l' : List (OutPoint × Coin))
      (okN' unjN' : Nat),
      applyTxs height txs i l okN unjN = Except.ok (l', okN', unjN') →
      applyBlockFoldL l txidKey txs height = Except.ok l' := by
  intro txs
  induction txs with
  | nil =>
      intro i okN unjN l l' okN' unjN' h
      simp only [applyTxs] at h
      obtain ⟨rfl, rfl, rfl⟩ := h
      simp [applyBlockFoldL]
  | cons tx rest ih =>
      intro i okN unjN l l' okN' unjN' h
      obtain ⟨l₁, a, b, hstep, htail⟩ :=
        applyTxs_cons_inv height tx rest i okN unjN l l' okN' unjN' h
      have hsl : applyTxStepL l tx (txidKey tx) height = Except.ok l₁ :=
        applyTx_ok_stepL height tx i l l₁ a b hstep
      rw [applyBlockFoldL, hsl]
      exact ih (i + 1) (okN + a) (unjN + b) l₁ l' okN' unjN' htail


/-! ## The composition theorems -/

/-- `&&` is false iff one side is. -/
theorem and_eq_false {a b : Bool} : (a && b) = false ↔ a = false ∨ b = false := by
  cases a <;> cases b <;> simp

/-- **THE COMPOSITION (iff, ledger tier)**: `applyBlockL` succeeds iff
the pre-block BIP30 overlap gate is quiet, every tx satisfies its state
predicate on the view threaded by its predecessors, and the resulting
UTXO list is exactly the reference `updateCoinsL` fold. -/
theorem applyBlockL_ok_iff (l l' : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) :
    applyBlockL l kf txs height = Except.ok l' ↔
      (bip30BlockCollision (viewOf l) kf txs height && bip30Enforced height) = false ∧
      FoldPred l kf txs height ∧ l' = updateFoldL l kf txs height := by
  unfold applyBlockL
  by_cases hg : (bip30BlockCollision (viewOf l) kf txs height
    && bip30Enforced height) = true
  · rw [ite_eq_left hg]
    constructor
    · intro h; cases h
    · rintro ⟨hf, _⟩; rw [hf] at hg; simp at hg
  · rw [ite_eq_right hg]
    constructor
    · intro h
      refine ⟨?_, (applyBlockFoldL_ok_iff_pred l l' kf txs height).mp h⟩
      cases hb : (bip30BlockCollision (viewOf l) kf txs height
        && bip30Enforced height) with
      | false => rfl
      | true => exact absurd hb hg
    · rintro ⟨_, hp⟩
      exact (applyBlockFoldL_ok_iff_pred l l' kf txs height).mpr hp

/-- **THE COMPOSITION (explicit BIP30 form)**: the quiet gate is exactly
"BIP30 enforcement off, or no block tx re-creates a pristine outpoint". -/
theorem applyBlockL_ok_iff_bip30 (l l' : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) :
    applyBlockL l kf txs height = Except.ok l' ↔
      (bip30Enforced height = false ∨
        ¬ ∃ tx ∈ txs, ∃ o, o < tx.vout.length ∧
          (viewOf l (kf tx OutPoint.null (UInt32.ofNat o))).isSome) ∧
      FoldPred l kf txs height ∧ l' = updateFoldL l kf txs height := by
  rw [applyBlockL_ok_iff]
  constructor
  · rintro ⟨hg, hp, hl⟩
    refine ⟨?_, hp, hl⟩
    rcases and_eq_false.mp hg with hc | he
    · refine Or.inr (fun h => ?_)
      have hc' : bip30BlockCollision (viewOf l) kf txs height = true :=
        (bip30BlockCollision_eq_true_iff (viewOf l) kf txs height).mpr h
      rw [hc'] at hc; cases hc
    · exact Or.inl he
  · rintro ⟨h | hno, hp, hl⟩
    · exact ⟨and_eq_false.mpr (Or.inr h), hp, hl⟩
    · refine ⟨and_eq_false.mpr (Or.inl ?_), hp, hl⟩
      cases hc : bip30BlockCollision (viewOf l) kf txs height with
      | false => rfl
      | true => exact absurd ((bip30BlockCollision_eq_true_iff
          (viewOf l) kf txs height).mp hc) hno

/-- **BIP30 sound direction**: if enforcement is on, a successful block
application canNOT contain a tx output that re-creates a pristine
outpoint — the TXV-063 overlap-loop ban, transported to success. -/
theorem applyBlockL_ok_no_bip30 (l l' : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) (henf : bip30Enforced height = true)
    (hok : applyBlockL l kf txs height = Except.ok l') :
    ¬ ∃ tx ∈ txs, ∃ o, o < tx.vout.length ∧
      (viewOf l (kf tx OutPoint.null (UInt32.ofNat o))).isSome := by
  have hg := ((applyBlockL_ok_iff l l' kf txs height).mp hok).1
  have hc : bip30BlockCollision (viewOf l) kf txs height = false := by
    cases hb : bip30BlockCollision (viewOf l) kf txs height with
    | false => rfl
    | true => rw [hb, henf] at hg; simp at hg
  intro h
  have htrue := (bip30BlockCollision_eq_true_iff (viewOf l) kf txs height).mpr h
  rw [htrue] at hc; cases hc

/-- **Sound direction at the FULL pipeline**: a `validateBlock` success
decodes to a header/tx list whose capstone fold is W12's `applyBlockFoldL`
at `txidKey`, satisfies every per-tx state predicate on the threaded view,
and whose report UTXO list is the reference update fold. -/
theorem validateBlock_ok_fold (raw : ByteArray) (st : CapState) (r : CapReport)
    (h : validateBlock raw st = Except.ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx),
      decodeBlock raw = Except.ok (bh, txs) ∧
      applyBlockFoldL st.utxo txidKey txs st.height = Except.ok r.state.utxo ∧
      FoldPred st.utxo txidKey txs st.height ∧
      r.state.utxo = updateFoldL st.utxo txidKey txs st.height := by
  obtain ⟨bh, txs, u', k, j, hdec, _, _, _, _, _, _, _, _, hfold, hst, _, _, _⟩ :=
    BitcoinProofs.Theorems.CapstonePipeline.validateBlock_ok_shape raw st r h
  have hb : applyBlockFoldL st.utxo txidKey txs st.height = Except.ok u' :=
    applyTxs_ok_applyBlockFoldL st.height txs 0 0 0 st.utxo u' k j hfold
  have hp := (applyBlockFoldL_ok_iff_pred st.utxo u' txidKey txs st.height).mp hb
  exact ⟨bh, txs, hdec, by rw [hst]; exact hb, hp.1, by rw [hst]; exact hp.2⟩

/-- **Undo-data consistency (per step)**: on a successful ledger step, the
disconnect payload (`spentUndo`, Core's `CTxUndo` layout) restores the
pre-state exactly, given Core's "added key was fresh or re-spent" side
condition. -/
theorem applyTxStepL_undo (l l' : List (OutPoint × Coin)) (tx : Tx)
    (key : Key) (height : UInt32)
    (hok : applyTxStepL l tx key height = Except.ok l')
    (h5 : ∀ q ∈ addedKeys tx key height,
      viewOf l q = none ∨ tx.vin.any (fun i => i.prevout == q) = true) :
    undoCoins (viewOf l') (spentUndo (viewOf l) tx) tx key height = viewOf l := by
  obtain ⟨_, rfl⟩ := (applyTxStepL_ok_iff l l' tx key height).mp hok
  rw [updateCoinsL_abstract]
  exact updateCoins_undo (viewOf l) tx key height h5

/-- Value the block's outputs draw (reference conservation total). -/
def drawn (txs : List Tx) : Amount := txs.foldr (fun t acc => t.getValueOut + acc) 0

/-- **Conservation along the reference fold**: the resulting UTXO list's
total value never exceeds the initial total plus the value the block's
outputs draw (INV-030/THM-037 upper half, on the composition's output). -/
theorem foldL_total_le (l l' : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32)
    (hval : ∀ p ∈ l, 0 ≤ p.2.value)
    (hrange : ∀ tx ∈ txs, ∀ k < tx.vout.length,
      0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value)
    (hok : applyBlockFoldL l kf txs height = Except.ok l') :
    listTotal l' ≤ listTotal l + drawn txs := by
  induction txs generalizing l with
  | nil =>
      simp only [applyBlockFoldL, Except.ok.injEq] at hok
      rw [← hok]; simp [drawn]
  | cons tx rest ih =>
      rw [applyBlockFoldL] at hok
      cases hs : applyTxStepL l tx (kf tx) height with
      | error e => rw [hs] at hok; cases hok
      | ok l₁ =>
          rw [hs] at hok
          have hupd : l₁ = updateCoinsL l tx (kf tx) height :=
            ((applyTxStepL_ok_iff l l₁ tx (kf tx) height).mp hs).2
          have hvout : ∀ k < tx.vout.length,
              0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value :=
            fun k hk => hrange tx (List.mem_cons.mpr (Or.inl rfl)) k hk
          have hval₁ : ∀ p ∈ l₁, 0 ≤ p.2.value := by
            rw [hupd]
            exact fun p hp => value_nonneg_of_mem_updateCoinsL l tx (kf tx)
              height hval hvout p hp
          have h1 : listTotal l₁ ≤ listTotal l + tx.getValueOut := by
            rw [hupd]
            exact listTotal_updateCoinsL_le l tx (kf tx) height hval hvout
          have h2 := ih l₁ hval₁
            (fun t ht => hrange t (List.mem_cons_of_mem _ ht)) hok
          simp only [drawn, List.foldr_cons]
          have h1' : toI (listTotal l₁) ≤ toI (listTotal l) + toI tx.getValueOut := h1
          have h2' : toI (listTotal l') ≤ toI (listTotal l₁) + toI (drawn rest) := h2
          show toI (listTotal l') ≤
            toI (listTotal l) + (toI tx.getValueOut + toI (drawn rest))
          omega

/-! ## Whole-block disconnect composition -/

/-- Forward-collected disconnect payloads (one `CTxUndo` per tx). -/
def undoPayloads (l : List (OutPoint × Coin)) (kf : Tx → Key) :
    List Tx → UInt32 → List (List (OutPoint × Coin))
  | [], _ => []
  | tx :: rest, height =>
      spentUndo (viewOf l) tx ::
        undoPayloads (updateCoinsL l tx (kf tx) height) kf rest height

/-- Apply disconnect payloads in the given order. -/
def undoChain (kf : Tx → Key) : UtxoSet → List (Tx × List (OutPoint × Coin)) → UInt32 → UtxoSet
  | u, [], _ => u
  | u, (tx, p) :: rest, height => undoChain kf (undoCoins u p tx (kf tx) height) rest height

/-- Payload list composition. -/
theorem undoChain_append (kf : Tx → Key) (u : UtxoSet)
    (l₁ l₂ : List (Tx × List (OutPoint × Coin))) (height : UInt32) :
    undoChain kf u (l₁ ++ l₂) height = undoChain kf (undoChain kf u l₁ height) l₂ height := by
  induction l₁ generalizing u with
  | nil => simp [undoChain]
  | cons x xs ih =>
      obtain ⟨tx, p⟩ := x
      simp only [List.cons_append, undoChain]
      exact ih (undoCoins u p tx (kf tx) height)

/-- Side conditions of the undo tier along the threaded view. -/
def UndoOk (l : List (OutPoint × Coin)) (kf : Tx → Key) : List Tx → UInt32 → Prop
  | [], _ => True
  | tx :: rest, height =>
      (∀ q ∈ addedKeys tx (kf tx) height,
        viewOf l q = none ∨ tx.vin.any (fun i => i.prevout == q) = true) ∧
      UndoOk (updateCoinsL l tx (kf tx) height) kf rest height

/-- **Whole-block undo consistency**: replaying the forward-collected
payloads in REVERSE order on the connected view restores the pre-block
view exactly. This is Core's `DisconnectBlock` round-trip for a block the
composition accepts. -/
theorem foldL_undo_chain (l l' : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32)
    (hok : FoldL l kf txs height l') (hundo : UndoOk l kf txs height) :
    undoChain kf (viewOf l') ((txs.zip (undoPayloads l kf txs height)).reverse) height
      = viewOf l := by
  induction txs generalizing l with
  | nil =>
      simp only [FoldL] at hok
      subst hok
      simp [undoChain, undoPayloads]
  | cons tx rest ih =>
      obtain ⟨l₁, hs, hf⟩ := hok
      obtain ⟨h5, hrest⟩ := hundo
      have hupd : l₁ = updateCoinsL l tx (kf tx) height :=
        ((applyTxStepL_ok_iff l l₁ tx (kf tx) height).mp hs).2
      have hrest' : UndoOk l₁ kf rest height := by rw [hupd]; exact hrest
      have hstep : undoCoins (viewOf l₁) (spentUndo (viewOf l) tx)
          tx (kf tx) height = viewOf l :=
        applyTxStepL_undo l l₁ tx (kf tx) height hs h5
      have hih := ih l₁ hf hrest'
      simp only [undoPayloads, List.zip_cons_cons, List.reverse_cons]
      rw [← hupd, undoChain_append, hih]
      simp [undoChain, hstep]

/-- **FLAGSHIP (Phase-3 pipeline composition)**: a successful block
application, at the ledger tier, entails ALL of: the BIP30 overlap gate
was quiet (enforcement off, or no pristine-outpoint collision), every tx
satisfied its state predicate on the threaded view, the resulting UTXO
list IS the reference update fold, value is conserved (upper bound), and
the forward-collected undo payloads replayed in reverse restore the
pre-block view. The converse of the first three conjuncts is
`applyBlockL_ok_iff_bip30`. -/
theorem applyBlockL_ok_flagship (l l' : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32)
    (hval : ∀ p ∈ l, 0 ≤ p.2.value)
    (hrange : ∀ tx ∈ txs, ∀ k < tx.vout.length,
      0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value)
    (hundo : UndoOk l kf txs height)
    (hok : applyBlockL l kf txs height = Except.ok l') :
    (bip30Enforced height = false ∨
      ¬ ∃ tx ∈ txs, ∃ o, o < tx.vout.length ∧
        (viewOf l (kf tx OutPoint.null (UInt32.ofNat o))).isSome) ∧
    FoldPred l kf txs height ∧
    l' = updateFoldL l kf txs height ∧
    listTotal l' ≤ listTotal l + drawn txs ∧
    undoChain kf (viewOf l') ((txs.zip (undoPayloads l kf txs height)).reverse) height
      = viewOf l := by
  obtain ⟨hbip, hpred, heq⟩ := (applyBlockL_ok_iff_bip30 l l' kf txs height).mp hok
  have hg : (bip30BlockCollision (viewOf l) kf txs height
    && bip30Enforced height) = false :=
    ((applyBlockL_ok_iff l l' kf txs height).mp hok).1
  have hfold : applyBlockFoldL l kf txs height = Except.ok l' := by
    unfold applyBlockL at hok
    rw [ite_eq_right (by rw [hg]; simp)] at hok
    exact hok
  have hfl : FoldL l kf txs height l' :=
    (applyBlockFoldL_ok_iff l l' kf txs height).mp hfold
  exact ⟨hbip, hpred, heq, foldL_total_le l l' kf txs height hval hrange hfold,
    foldL_undo_chain l l' kf txs height hfl hundo⟩

end BitcoinProofs.Theorems.CapstoneComposePipeline
