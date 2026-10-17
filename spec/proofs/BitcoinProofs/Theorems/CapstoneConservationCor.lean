import Bitcoin.Capstone.Block
import Bitcoin.Ledger.Interface
import BitcoinProofs.Theorems.LedgerCor

/-!
# BitcoinProofs.Theorems.CapstoneConservationCor — P15 (W17): conservation corollaries on the capstone tier (sorry-free)

Every theorem in this file is an INSTANTIATION or BRIDGE over already
proved, sorry-free upstream theorems; no new consensus model is
introduced and no upstream definition is restated.

Upstream (all sorry-free):

* `Bitcoin.Ledger.chainFeesL_le_blockDrawn` (W12/W15, THM-037 upper
  half, key-generic in `kf : Tx → Key`) — THE conservation law of the
  executable assoc-list tier: the total fees `chainFeesL` certifies
  while connecting `txs` never exceed the value in the starting UTXO
  list plus the value the block's own outputs draw.
* `Bitcoin.Ledger.chainFees_nonneg` + `chainFees_viewOf` — the fee fold
  is nonnegative (TXV-025 lineage).
* `Bitcoin.TxValidation.checkTxInputs_ok_conservation` (W10, THM-036
  executable form) — per tx, an adjudicated fee satisfies
  `totalIn = getValueOut + fee` and `fee ≥ 0`.
* `BitcoinProofs.Theorems.LedgerCor` (W15) — THM-006 output-MoneyRange
  and TXV-007 no-duplicate-prevouts, used here to discharge the fee
  bound's per-tx hypotheses from the stateless gate that the capstone
  pipeline itself enforces (`BLK-030` inside `applyTx`).

## C4 / rule-linkage table (axiom footprints audited via `#print axioms`
in the W17 P15 scratch area; results recorded below)

| source   | theorem here | statement (short) | axioms |
|----------|--------------|-------------------|--------|
| BLK-005 keying | `hkey_txidKey` | the fee bound's "key ≠ null" hypothesis at `Bitcoin.Capstone.Block.txidKey` reduces to `txidOf tx ≠ zeroBytes 32` | propext, Classical.choice, Quot.sound |
| (keying) | `hkey_txidPreimageKey` | same at W12's `txidPreimageKey`, from `serTx tx ≠ zeroBytes 32` | propext, Classical.choice, Quot.sound |
| THM-037↑ | `fees_le_blockDrawn_txidKey` | the conservation/fee bound instantiated at the CAPSTONE keying `txidKey` | propext, Classical.choice, Quot.sound |
| THM-037↑ | `fees_le_blockDrawn_txidPreimageKey` | the same bound at `txidPreimageKey` | propext, Classical.choice, Quot.sound |
| THM-037↑ | `fees_le_blockDrawn_keying_independent` | BOTH keyings in one statement: the law is keying-independent | propext, Classical.choice, Quot.sound |
| TXV-025  | `chainFeesL_nonneg` | `0 ≤ chainFeesL l kf txs height` (any kf — pure instance) | propext, Classical.choice, Quot.sound |
| TXV-025+THM-037↑ | `capstone_fees_sandwich_txidKey` | `0 ≤ fees ≤ listTotal l + blockDrawn txs` at `txidKey` | propext, Classical.choice, Quot.sound |
| THM-036  | `tx_conservation_at_view` | per-tx MINT law at the CapState assoc-list view: `sumAtL l (prevouts) = getValueOut + fee ∧ 0 ≤ fee` | propext, Classical.choice, Quot.sound |
| (bridge) | `applyTxs_ok_checkTx_all` | `applyTxs` success ⇒ every tx passed the BLK-030 stateless gate | propext, Classical.choice, Quot.sound |
| (bridge) | `applyTxs_ok_applyBlockL` | the CapReport-path UTXO list IS W12's fold: `applyBlockL l txidKey txs height = ok l'` | propext, Classical.choice, Quot.sound |
| (bridge) | `capReport_utxo_value_nonneg` | every coin of the CapReport path has nonneg value (INV-030 lineage) | propext, Classical.choice, Quot.sound |
| (bridge) | `capReport_utxo_total_le` | `listTotal final ≤ listTotal initial + blockDrawn txs` (conservation, upper half, on the RESULT list) | propext, Classical.choice, Quot.sound |
| TXV-007  | `hasDupPrevouts_eq_false_nodup` | the boolean dup check implies `List.Nodup` (bridge to the fee bound's hypothesis) | propext, Classical.choice, Quot.sound |
| THM-006  | `output_values_nonneg_of_checkTx_none` | passing `checkTransaction` ⇒ every output value ≥ 0 (CVE-2010-5139 lineage) | propext, Classical.choice, Quot.sound |
| (bridge) | `validateBlock_ok_ledger_fold` | at the FULL pipeline: the report UTXO list is `applyBlockL st.utxo txidKey (decodedTxs raw) st.height`'s output | propext, Classical.choice, Quot.sound |
| (bridge) | `validateBlock_ok_utxo_value_nonneg` | the anchor-run resulting state's UTXO list has all values nonneg | propext, Classical.choice, Quot.sound |
| (bridge) | `validateBlock_ok_utxo_total_le` | … and its total value is `≤ initial + blockDrawn` | propext, Classical.choice, Quot.sound |
| THM-037↑ | `validateBlock_ok_fees_le` | the fee bound for the DECODED txs of a validated block, per-tx hypotheses derived from the pipeline's own gates | propext, Classical.choice, Quot.sound |

Honest scope note (what is deliberately NOT claimed): the coinbase
"mints exactly fee + subsidy" half of THM-037. The capstone fold
(`applyTxStepL`/`updateCoinsL`, hence `chainFeesL`) carries no subsidy
term, so no upstream theorem provides a subsidy-bearing statement; the
strongest honest mint law at this tier is the per-tx fee identity
(`tx_conservation_at_view`) plus the sandwich
(`capstone_fees_sandwich_txidKey`). A subsidy-in-fold extension is a
missing upstream DEFINITION, not a missing proof.

Axiom footprints are checked by `#print axioms` in the W17 scratch area
(NOT pinned in this file, per the P15 work order); the table above
records the audited results.
-/

namespace BitcoinProofs.Theorems.CapstoneConservation

open Bitcoin.Data Bitcoin.Ledger
open Bitcoin.Consensus (checkTransaction hasDupPrevouts)
open Bitcoin.TxValidation (checkTxInputs checkTxInputs_ok_conservation)
open Bitcoin.Conservation (moneyRange_eq_true_iff)
open Bitcoin.Capstone.Merkle (txidOf)
open Bitcoin.Capstone.Block (txidKey applyTxs CapState CapReport validateBlock)

/-! ## 0. Small private plumbing -/

/-- `Except.ok`-bind reduction (rfl; core has no such simp lemma on this
toolchain). -/
private theorem exceptOkBind {ε α β : Type _} (a : α) (f : α → Except ε β) :
    (Except.ok a).bind f = f a := rfl

/-- General `Except` bind inversion (rfl-level; used to peel one `do`-bind
off a success hypothesis without any `simp` involvement). -/
private theorem peelOk {ε α β : Type _} (x : Except ε α) (f : α → Except ε β) (r : β)
    (h : x.bind f = Except.ok r) : ∃ a, x = Except.ok a ∧ f a = Except.ok r := by
  cases x with
  | error e => have h' : Except.error e = Except.ok r := h; nomatch h'
  | ok a => exact ⟨a, rfl, h⟩

/-- The txs a serialized block decodes to (error ⇒ empty; only the
successful path is ever consumed below, via `validateBlock_ok_inv`). -/
private def decodedTxs (raw : ByteArray) : List Tx :=
  match Bitcoin.Serialization.decodeBlock raw with
  | .ok p => p.2
  | .error _ => []

/-- `l.getD k d` is a member of `l` whenever `k` is in range (used to
feed `LedgerCor.checkOutputs_none_moneyRange`'s membership hypothesis). -/
private theorem list_getD_mem {α : Type _} :
    ∀ (l : List α) (k : Nat) (d : α), k < l.length → l.getD k d ∈ l := by
  intro l
  induction l with
  | nil => intro _k _d hk; exact absurd hk (Nat.not_lt_zero _k)
  | cons a t ih =>
      intro k d hk
      cases k with
      | zero => exact List.mem_cons_self
      | succ k' => exact List.mem_cons_of_mem _ (ih k' d (Nat.lt_of_succ_lt_succ hk))

/-! ## 1. The keying hypothesis at the two capstone keyings

`chainFeesL_le_blockDrawn` needs: for every spendable output `k` of every
tx, the coin key `(kf tx) OutPoint.null (UInt32.ofNat k)` is not
BEq-equal to `OutPoint.null` (otherwise a coin could be parked at the
null outpoint and escape the fold's bookkeeping). At both capstone
keyings this reduces to a hash collision-freeness statement. -/

/-- **BLK-005 keying**: at `txidKey` the key is `⟨txidOf tx, k⟩`, so the
key-≠-null hypothesis holds as soon as the txid is not the 32-zero
string (k's value is then irrelevant). -/
theorem hkey_txidKey (tx : Tx) (hne : txidOf tx ≠ zeroBytes 32) (k : UInt32) :
    ((txidKey tx) OutPoint.null k == OutPoint.null) = false := by
  have hbe : bytesBEq (txidOf tx) (zeroBytes 32) = false := by
    cases hb : bytesBEq (txidOf tx) (zeroBytes 32) with
    | false => rfl
    | true => exact absurd (bytesBEq_eq_of_true _ _ hb) hne
  show ((⟨txidOf tx, k⟩ : OutPoint) == OutPoint.null) = false
  rw [show ((⟨txidOf tx, k⟩ : OutPoint) == OutPoint.null)
        = (bytesBEq (txidOf tx) (zeroBytes 32) && (k == NULL_INDEX)) from rfl,
    hbe, Bool.false_and]

/-- **W12 keying**: at `txidPreimageKey` the key is `⟨serTx tx, k⟩`; same
reduction from the preimage's collision-freeness. -/
theorem hkey_txidPreimageKey (tx : Tx) (hne : serTx tx ≠ zeroBytes 32) (k : UInt32) :
    ((txidPreimageKey tx) OutPoint.null k == OutPoint.null) = false := by
  have hbe : bytesBEq (serTx tx) (zeroBytes 32) = false := by
    cases hb : bytesBEq (serTx tx) (zeroBytes 32) with
    | false => rfl
    | true => exact absurd (bytesBEq_eq_of_true _ _ hb) hne
  show ((⟨serTx tx, k⟩ : OutPoint) == OutPoint.null) = false
  rw [show ((⟨serTx tx, k⟩ : OutPoint) == OutPoint.null)
        = (bytesBEq (serTx tx) (zeroBytes 32) && (k == NULL_INDEX)) from rfl,
    hbe, Bool.false_and]

/-! ## 2. THM-037 (upper half) at the capstone keyings -/

/-- **THM-037 (upper half) at the CAPSTONE keying** (`txidKey` — the real
txid, the keying W17's anchor run uses): connecting `txs` against the
UTXO list `l` certifies fees bounded by the list's value plus the value
the block's own outputs draw. Pure instantiation of the key-generic
`chainFeesL_le_blockDrawn`. -/
theorem fees_le_blockDrawn_txidKey (l : List (OutPoint × Coin)) (txs : List Tx)
    (height : UInt32)
    (hval : ∀ p ∈ l, 0 ≤ p.2.value)
    (hrange : ∀ tx ∈ txs, ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value)
    (hnd : ∀ tx ∈ txs, (tx.vin.map (·.prevout)).Nodup)
    (htxid : ∀ tx ∈ txs, txidOf tx ≠ zeroBytes 32)
    (hnull : coinLookup l OutPoint.null = none) :
    chainFeesL l txidKey txs height ≤ listTotal l + blockDrawn txs := by
  refine chainFeesL_le_blockDrawn l txidKey txs height hval hrange hnd ?_ hnull
  intro tx hmem k _k_lt _hus
  exact hkey_txidKey tx (htxid tx hmem) (UInt32.ofNat k)

/-- **THM-037 (upper half) at W12's keying** (`txidPreimageKey`): the
same conservation bound — the fee law does not care which injective
keying the fold uses. -/
theorem fees_le_blockDrawn_txidPreimageKey (l : List (OutPoint × Coin)) (txs : List Tx)
    (height : UInt32)
    (hval : ∀ p ∈ l, 0 ≤ p.2.value)
    (hrange : ∀ tx ∈ txs, ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value)
    (hnd : ∀ tx ∈ txs, (tx.vin.map (·.prevout)).Nodup)
    (hser : ∀ tx ∈ txs, serTx tx ≠ zeroBytes 32)
    (hnull : coinLookup l OutPoint.null = none) :
    chainFeesL l txidPreimageKey txs height ≤ listTotal l + blockDrawn txs := by
  refine chainFeesL_le_blockDrawn l txidPreimageKey txs height hval hrange hnd ?_ hnull
  intro tx hmem k _k_lt _hus
  exact hkey_txidPreimageKey tx (hser tx hmem) (UInt32.ofNat k)

/-- **Keying independence (P15 item 2)**: under identical structural
hypotheses, the conservation bound holds at BOTH keyings — the capstone
`txidKey` (real txid) and the W12 `txidPreimageKey` — in one statement.
The only difference between the two instances is the per-key hash
collision-freeness condition each keying needs. -/
theorem fees_le_blockDrawn_keying_independent (l : List (OutPoint × Coin)) (txs : List Tx)
    (height : UInt32)
    (hval : ∀ p ∈ l, 0 ≤ p.2.value)
    (hrange : ∀ tx ∈ txs, ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value)
    (hnd : ∀ tx ∈ txs, (tx.vin.map (·.prevout)).Nodup)
    (htxid : ∀ tx ∈ txs, txidOf tx ≠ zeroBytes 32)
    (hser : ∀ tx ∈ txs, serTx tx ≠ zeroBytes 32)
    (hnull : coinLookup l OutPoint.null = none) :
    (chainFeesL l txidKey txs height ≤ listTotal l + blockDrawn txs)
    ∧ (chainFeesL l txidPreimageKey txs height ≤ listTotal l + blockDrawn txs) :=
  ⟨fees_le_blockDrawn_txidKey l txs height hval hrange hnd htxid hnull,
   fees_le_blockDrawn_txidPreimageKey l txs height hval hrange hnd hser hnull⟩

/-! ## 3. The fee sandwich (nonneg + upper bound) -/

/-- The executable fee fold is nonnegative, for ANY keying (pure
instance of W12's `chainFees_nonneg`, transferred to the assoc-list tier
by `chainFees_viewOf`). -/
theorem chainFeesL_nonneg (l : List (OutPoint × Coin)) (kf : Tx → Key)
    (txs : List Tx) (height : UInt32) : 0 ≤ chainFeesL l kf txs height := by
  rw [← chainFees_viewOf kf txs height l]
  exact chainFees_nonneg (viewOf l) kf txs height

/-- **The fee sandwich at the capstone keying** (the strongest honest
fee/mint shape this tier supports): `0 ≤ fees ≤ listTotal l + blockDrawn
txs` — the block's txs cannot extract more value than was present plus
what they themselves create, and never certify a negative extraction. -/
theorem capstone_fees_sandwich_txidKey (l : List (OutPoint × Coin)) (txs : List Tx)
    (height : UInt32)
    (hval : ∀ p ∈ l, 0 ≤ p.2.value)
    (hrange : ∀ tx ∈ txs, ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value)
    (hnd : ∀ tx ∈ txs, (tx.vin.map (·.prevout)).Nodup)
    (htxid : ∀ tx ∈ txs, txidOf tx ≠ zeroBytes 32)
    (hnull : coinLookup l OutPoint.null = none) :
    0 ≤ chainFeesL l txidKey txs height
    ∧ chainFeesL l txidKey txs height ≤ listTotal l + blockDrawn txs :=
  ⟨chainFeesL_nonneg l txidKey txs height,
   fees_le_blockDrawn_txidKey l txs height hval hrange hnd htxid hnull⟩

/-! ## 4. The per-tx mint law at the capstone UTXO view -/

/-- **THM-036 at the capstone tier (per-tx mint law)**: when the W10
contextual check adjudicates fee `fee` for `tx` against the assoc-list
view `viewOf l` (exactly the view `applyTxStepL` consults), the value
drawn from the list at the tx's prevouts equals the outputs' value plus
the fee, and the fee is nonnegative. This is `checkTxInputs_ok_conservation`
transferred to the executable tier by W12's `totalIn_eq_sumAtL` bridge. -/
theorem tx_conservation_at_view (l : List (OutPoint × Coin)) (tx : Tx) (height : UInt32)
    (fee : Amount) (h : checkTxInputs tx (viewOf l) height = Except.ok fee) :
    sumAtL l (tx.vin.map (·.prevout)) = tx.getValueOut + fee ∧ 0 ≤ fee := by
  obtain ⟨hcons, hfee⟩ := checkTxInputs_ok_conservation tx (viewOf l) height fee h
  rw [totalIn_eq_sumAtL] at hcons
  exact ⟨hcons, hfee⟩

/-! ## 5. Bridge: the CapReport path IS the W12 ledger fold

`validateBlock`'s per-tx stage (`applyTxs`) interleaves the script layer
with the ledger steps `applyTxStepL l tx (txidKey tx) height`. These
lemmas show that on success the state thread is EXACTLY W12's
`applyBlockL` fold at the capstone keying — so the CapReport-path UTXO
list is the assoc list every assoc-tier conservation theorem talks about
(P15 item 4), and the assoc-tier list invariants transfer to it. -/

/-- Step inversion: `applyTx` success ⇒ the ledger step succeeded with
exactly W12's `applyTxStepL` at the capstone keying. (Proof: normalize
the do-block's CPS join points, then split the stateless-gate match, the
coinbase ite and the script-check Except; every non-ledger path ends in a
`throw`, contradicting the `ok` hypothesis.) -/
private theorem applyTx_ok_step (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l l₁ : List (OutPoint × Coin)) (a b : Nat)
    (h : Bitcoin.Capstone.Block.applyTx height tx txIdx l = Except.ok (l₁, a, b)) :
    applyTxStepL l tx (txidKey tx) height = Except.ok l₁ := by
  unfold Bitcoin.Capstone.Block.applyTx at h
  simp only [] at h
  split at h
  · have h' : Except.error _ = Except.ok (l₁, a, b) := h; nomatch h'
  · split at h
    · split at h
      · have h' : Except.error _ = Except.ok (l₁, a, b) := h; nomatch h'
      · rename_i l'' heqO
        have hinj : l'' = l₁ ∧ (0 : Nat) = a ∧ (0 : Nat) = b := by
          have h2 : Except.ok (l'', (0, 0)) = Except.ok (l₁, a, b) := h
          simp only [Except.ok.injEq, Prod.mk.injEq] at h2
          exact h2
        rw [heqO, hinj.1]
    · cases hv : Bitcoin.Capstone.Block.verifyTxInputs height tx txIdx l with
      | error ea => rw [hv] at h; have h' : Except.error _ = Except.ok (l₁, a, b) := h; nomatch h'
      | ok p =>
          obtain ⟨a', b'⟩ := p
          rw [hv] at h
          split at h
          · have h' : Except.error _ = Except.ok (l₁, a, b) := h; nomatch h'
          · rename_i l'' heqO
            have hinj : l'' = l₁ ∧ a' = a ∧ b' = b := by
              have h2 : Except.ok (l'', a', b') = Except.ok (l₁, a, b) := h
              simp only [Except.ok.injEq, Prod.mk.injEq] at h2
              exact h2
            rw [heqO, hinj.1]

/-- Step inversion: `applyTx` success ⇒ the new state is exactly
`updateCoinsL`'s (both `applyTxStepL` success branches return it). -/
private theorem applyTx_ok_updateCoins (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l l₁ : List (OutPoint × Coin)) (a b : Nat)
    (h : Bitcoin.Capstone.Block.applyTx height tx txIdx l = Except.ok (l₁, a, b)) :
    l₁ = updateCoinsL l tx (txidKey tx) height := by
  have hs : applyTxStepL l tx (txidKey tx) height = Except.ok l₁ :=
    applyTx_ok_step height tx txIdx l l₁ a b h
  unfold applyTxStepL at hs
  split at hs
  · exact (Except.ok.inj hs).symm
  · split at hs
    · have h' : Except.error _ = Except.ok l₁ := hs; nomatch h'
    · split at hs
      · have h' : Except.error _ = Except.ok l₁ := hs; nomatch h'
      · exact (Except.ok.inj hs).symm

/-- Helper for `applyTxs_cons_inv`: `applyTx` success ⇒ the BLK-030
stateless gate passed. -/
private theorem applyTx_ok_checkTx' (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l l₁ : List (OutPoint × Coin)) (a b : Nat)
    (h : Bitcoin.Capstone.Block.applyTx height tx txIdx l = Except.ok (l₁, a, b)) :
    checkTransaction tx = none := by
  unfold Bitcoin.Capstone.Block.applyTx at h
  simp only [] at h
  split at h
  · have h' : Except.error _ = Except.ok (l₁, a, b) := h; nomatch h'
  · rename_i heqN
    exact heqN

/-- The workhorse inversion: one successful `applyTxs` cons step
decouples into the stateless gate, the ledger step (`applyTxStepL` at
the capstone keying), the `updateCoinsL` state equation, and the
recursive success. -/
private theorem applyTxs_cons_inv (height : UInt32) (tx : Tx) (rest : List Tx)
    (i okN unjN : Nat) (l l' : List (OutPoint × Coin)) (okN' unjN' : Nat)
    (h : applyTxs height (tx :: rest) i l okN unjN = Except.ok (l', okN', unjN')) :
    ∃ l₁ a b,
      checkTransaction tx = none
      ∧ applyTxStepL l tx (txidKey tx) height = Except.ok l₁
      ∧ l₁ = updateCoinsL l tx (txidKey tx) height
      ∧ applyTxs height rest (i + 1) l₁ (okN + a) (unjN + b) = Except.ok (l', okN', unjN') := by
  unfold applyTxs at h
  cases hap : Bitcoin.Capstone.Block.applyTx height tx i l with
  | error e => rw [hap] at h; simp at h
  | ok p =>
      obtain ⟨l₁, a, b⟩ := p
      rw [hap] at h
      refine ⟨l₁, a, b, ?_, applyTx_ok_step height tx i l l₁ a b hap,
        applyTx_ok_updateCoins height tx i l l₁ a b hap, ?_⟩
      · exact applyTx_ok_checkTx' height tx i l l₁ a b hap
      · simpa using h

/-- **Bridge (P15 item 4a)**: `applyTxs` success ⇒ every tx of the block
passed the BLK-030 stateless gate. -/
theorem applyTxs_ok_checkTx_all (height : UInt32) :
    ∀ (txs : List Tx) (i okN unjN : Nat) (l l' : List (OutPoint × Coin)) (okN' unjN' : Nat),
      applyTxs height txs i l okN unjN = Except.ok (l', okN', unjN') →
      ∀ tx ∈ txs, checkTransaction tx = none := by
  intro txs
  induction txs with
  | nil => intro _ _ _ _ _ _ _ _ tx ht; cases ht
  | cons u rest ih =>
      intro i okN unjN l l' okN' unjN' h t ht
      obtain ⟨l₁, a, b, hchk, _, _, htail⟩ := applyTxs_cons_inv height u rest i okN unjN
        l l' okN' unjN' h
      rcases List.mem_cons.mp ht with heq | hmem
      · rw [heq]; exact hchk
      · exact ih (i + 1) (okN + a) (unjN + b) l₁ l' okN' unjN' htail t hmem

/-- **Bridge (P15 item 4, fold form)**: on `applyTxs` success, the final
UTXO list of the CapReport path is EXACTLY W12's BIP30-free inner fold
`applyBlockFoldL` at the capstone keying `txidKey` — the two tiers run
the same per-tx computation. -/
theorem applyTxs_ok_applyBlockFoldL (height : UInt32) :
    ∀ (txs : List Tx) (i okN unjN : Nat) (l l' : List (OutPoint × Coin)) (okN' unjN' : Nat),
      applyTxs height txs i l okN unjN = Except.ok (l', okN', unjN') →
      applyBlockFoldL l txidKey txs height = Except.ok l' := by
  intro txs
  induction txs with
  | nil =>
      intro i okN unjN l l' okN' unjN' h
      simp only [applyTxs] at h
      have hinj : l = l' ∧ okN = okN' ∧ unjN = unjN' := by
        simpa using Except.ok.inj h
      rw [hinj.1, applyBlockFoldL]
  | cons tx rest ih =>
      intro i okN unjN l l' okN' unjN' h
      obtain ⟨l₁, a, b, _, hstep, _, htail⟩ := applyTxs_cons_inv height tx rest i okN unjN
        l l' okN' unjN' h
      rw [applyBlockFoldL, hstep, exceptOkBind]
      exact ih (i + 1) (okN + a) (unjN + b) l₁ l' okN' unjN' htail

/-- **Bridge (P15 item 4)**: on `applyTxs` success and a quiet pre-block
BIP30 gate, the final UTXO list of the CapReport path is EXACTLY W12's
`applyBlockL` fold at the capstone keying `txidKey`. The gate hypothesis
is REAL post-D4c-2: `applyBlockL` runs Core 2466-2475's pristine
pre-block overlap check, while the capstone `applyTxs` tier does not
enforce BIP30 at all — so a gate-firing block is a genuine tier
divergence (D4c-2's documented capstone face) and cannot be bridged
without the hypothesis. -/
theorem applyTxs_ok_applyBlockL (height : UInt32) :
    ∀ (txs : List Tx) (i okN unjN : Nat) (l l' : List (OutPoint × Coin)) (okN' unjN' : Nat),
      (bip30BlockCollision (viewOf l) txidKey txs height && bip30Enforced height) = false →
      applyTxs height txs i l okN unjN = Except.ok (l', okN', unjN') →
      applyBlockL l txidKey txs height = Except.ok l' := by
  intro txs i okN unjN l l' okN' unjN' hg h
  rw [applyBlockL, ite_eq_right (by simp [hg])]
  exact applyTxs_ok_applyBlockFoldL height txs i okN unjN l l' okN' unjN' h

/-- **Bridge (P15 item 4b, INV-030 lineage)**: every coin in the
CapReport path's final UTXO list has nonnegative value — no negative
coin is ever created along the validated pipeline. -/
theorem capReport_utxo_value_nonneg (height : UInt32) :
    ∀ (txs : List Tx) (i okN unjN : Nat) (l l' : List (OutPoint × Coin)) (okN' unjN' : Nat),
      (∀ p ∈ l, 0 ≤ p.2.value) →
      (∀ tx ∈ txs, ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value) →
      applyTxs height txs i l okN unjN = Except.ok (l', okN', unjN') →
      ∀ p ∈ l', 0 ≤ p.2.value := by
  intro txs
  induction txs with
  | nil =>
      intro i okN unjN l l' okN' unjN' hval _ h
      simp only [applyTxs] at h
      have hinj : l = l' ∧ okN = okN' ∧ unjN = unjN' := by
        simpa using Except.ok.inj h
      rw [← hinj.1]
      exact hval
  | cons tx rest ih =>
      intro i okN unjN l l' okN' unjN' hval hrange h
      obtain ⟨l₁, a, b, _, _, hupd, htail⟩ := applyTxs_cons_inv height tx rest i okN unjN
        l l' okN' unjN' h
      have hvout : ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value :=
        hrange tx (List.mem_cons.mpr (Or.inl rfl))
      have hval₁ : ∀ p ∈ l₁, 0 ≤ p.2.value := by
        rw [hupd]
        intro p hp
        exact value_nonneg_of_mem_updateCoinsL l tx (txidKey tx) height hval hvout p hp
      exact ih (i + 1) (okN + a) (unjN + b) l₁ l' okN' unjN' hval₁
        (fun q hq => hrange q (List.mem_cons.mpr (Or.inr hq))) htail

/-- **Bridge (P15 item 4c, conservation on the RESULT list)**: the total
value stored in the CapReport path's final UTXO list never exceeds the
starting value plus the value the block's outputs draw — the upper half
of conservation, instantiated on the pipeline's actual output. -/
theorem capReport_utxo_total_le (height : UInt32) :
    ∀ (txs : List Tx) (i okN unjN : Nat) (l l' : List (OutPoint × Coin)) (okN' unjN' : Nat),
      (∀ p ∈ l, 0 ≤ p.2.value) →
      (∀ tx ∈ txs, ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value) →
      applyTxs height txs i l okN unjN = Except.ok (l', okN', unjN') →
      listTotal l' ≤ listTotal l + blockDrawn txs := by
  intro txs
  induction txs with
  | nil =>
      intro i okN unjN l l' okN' unjN' hval _ h
      simp only [applyTxs] at h
      have hinj : l = l' ∧ okN = okN' ∧ unjN = unjN' := by
        simpa using Except.ok.inj h
      rw [← hinj.1]
      show toI (listTotal l) ≤ toI (listTotal l) + toI (blockDrawn [])
      have hz : toI (blockDrawn []) = (0 : Int) := rfl
      omega
  | cons tx rest ih =>
      intro i okN unjN l l' okN' unjN' hval hrange h
      obtain ⟨l₁, a, b, _, _, hupd, htail⟩ := applyTxs_cons_inv height tx rest i okN unjN
        l l' okN' unjN' h
      have hvout : ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value :=
        hrange tx (List.mem_cons.mpr (Or.inl rfl))
      have hval₁ : ∀ p ∈ l₁, 0 ≤ p.2.value := by
        rw [hupd]
        intro p hp
        exact value_nonneg_of_mem_updateCoinsL l tx (txidKey tx) height hval hvout p hp
      have hrange' : ∀ q ∈ rest, ∀ k < q.vout.length,
          0 ≤ (q.vout.getD k ⟨0, Script.empty⟩).value :=
        fun q hq => hrange q (List.mem_cons.mpr (Or.inr hq))
      have hstep : toI (listTotal l₁) ≤ toI (listTotal l) + toI tx.getValueOut := by
        rw [hupd]
        exact listTotal_updateCoinsL_le l tx (txidKey tx) height hval hvout
      have hih := ih (i + 1) (okN + a) (unjN + b) l₁ l' okN' unjN' hval₁ hrange' htail
      have hih' : toI (listTotal l') ≤ toI (listTotal l₁) + toI (blockDrawn rest) := hih
      rw [blockDrawn_cons]
      show toI (listTotal l') ≤ toI (listTotal l) + (toI tx.getValueOut + toI (blockDrawn rest))
      omega

/-! ### Bridges from the stateless gate to the fee bound's hypotheses -/

/-- **TXV-007 bridge**: the boolean duplicate-prevout check implies
`List.Nodup` of the prevout list — the form the fee bound consumes. -/
theorem hasDupPrevouts_eq_false_nodup (vin : List TxIn)
    (h : hasDupPrevouts vin = false) : (vin.map (·.prevout)).Nodup := by
  induction vin with
  | nil => exact List.nodup_nil
  | cons i rest ih =>
      have hsplit : (rest.any (fun j => j.prevout == i.prevout)) = false
          ∧ hasDupPrevouts rest = false := by
        rw [hasDupPrevouts, Bool.or_eq_false_iff] at h
        exact h
      refine List.nodup_cons.mpr ⟨?_, ih hsplit.2⟩
      intro hmem
      obtain ⟨j, hj, hje⟩ := List.mem_map.mp hmem
      have hne : (j.prevout == i.prevout) = false :=
        listAny_false (fun j => j.prevout == i.prevout) rest hsplit.1 j hj
      rw [hje, outPointBeqSelf] at hne
      simp at hne

/-- Per-index form of THM-006's per-output law: passing the stateless
check puts every output value in MoneyRange, in particular nonnegative
(CVE-2010-5139 defense, tx_check.cpp:37-38). The private bridge from
`checkTransaction = none` to the output loop mirrors W15's
`LedgerCor.checkOutputs_none_of_checkTransaction` (private there;
dedup candidate). -/
theorem output_values_nonneg_of_checkTx_none (tx : Tx) (h : checkTransaction tx = none) :
    ∀ k < tx.vout.length, 0 ≤ (tx.vout.getD k ⟨0, Script.empty⟩).value := by
  have hbridge : checkTransaction.checkOutputs tx.vout 0 = none := by
    rw [checkTransaction] at h
    by_cases hv : tx.vin.isEmpty = true
    · rw [ite_eq_left hv] at h; simp at h
    · rw [ite_eq_right hv] at h
      by_cases hvo : tx.vout.isEmpty = true
      · rw [ite_eq_left hvo] at h; simp at h
      · rw [ite_eq_right hvo] at h
        by_cases hs : Bitcoin.Consensus.txStrippedWeightL tx
            > Bitcoin.Consensus.MAX_BLOCK_WEIGHT
        · rw [ite_eq_left hs] at h; simp at h
        · rw [ite_eq_right hs] at h
          split at h
          · simp at h
          · rename_i hco
            cases hco' : checkTransaction.checkOutputs tx.vout 0 with
            | none => rfl
            | some e => exact absurd hco' (hco e)
  have hmr := BitcoinProofs.Theorems.LedgerCor.checkOutputs_none_moneyRange tx.vout 0 hbridge
  intro k hk
  have hmem : tx.vout.getD k ⟨0, Script.empty⟩ ∈ tx.vout :=
    list_getD_mem tx.vout k ⟨0, Script.empty⟩ hk
  exact (moneyRange_eq_true_iff _).mp (hmr _ hmem) |>.1

/-! ### The full-pipeline corollaries -/

set_option backward.split false in
/-- Pipeline inversion: `validateBlock` success ⇒ the block decoded to
header `hd` and txs `txs`, and the per-tx stage succeeded, returning the
report's UTXO list. (The ~14 structural/header/merkle ites are discharged
uniformly: on each error path the whole do-block reduces to a `throw`
via its CPS join points, contradicting the `ok` hypothesis.) -/
private theorem validateBlock_ok_inv (raw : ByteArray) (st : CapState) (r : CapReport)
    (h : validateBlock raw st = Except.ok r) :
    ∃ hd txs utxo' okN unjN,
      Bitcoin.Serialization.decodeBlock raw = Except.ok (hd, txs)
      ∧ applyTxs st.height txs 0 st.utxo 0 0 = Except.ok (utxo', okN, unjN)
      ∧ r.state.utxo = utxo' := by
  unfold validateBlock at h
  simp (config := { zeta := false }) only [] at h
  split at h
  · have h' : Except.error _ = Except.ok r := h; nomatch h'
  · rename_i p heq
    obtain ⟨hd, txs⟩ := p
    -- Peel the leading `let __x ← pure (hd, txs)` bind, instantiate the
    -- peeled witness with the decoded pair, and let the join-point lets
    -- (`have __do_jp := fun __r => ...`, i.e. `letFun`) resolve.  With
    -- `zeta := false` the CPS skeleton stays linear; one `letFun` pass
    -- then expands it into the plain gate-`if` chain.
    obtain ⟨w, hw, hcont⟩ := peelOk _ _ _ h
    have hwe : w = (hd, txs) := (Except.ok.inj hw).symm
    rw [hwe] at hcont
    simp (config := { zeta := false }) only [] at hcont
    simp only [letFun] at hcont
    -- Each structural/header/merkle gate: on the error path the whole
    -- do-block is one `throw`-bind (contradicting `= Except.ok r`); on the
    -- pass path continue with the next gate.  `backward.split false` keeps
    -- `split`'s internal simp neutral, which is essential on the big
    -- expanded term.
    split at hcont
    · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
    · split at hcont
      · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
      · split at hcont
        · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
        · split at hcont
          · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
          · split at hcont
            · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
            · split at hcont
              · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
              · split at hcont
                · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
                · split at hcont
                  · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
                  · split at hcont
                    · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
                    · split at hcont
                      · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
                      · split at hcont
                        · -- cGate error arm: inner anyWitness if; both
                          -- arms are `do throw _; _` ≡ `Except.error _`
                          split at hcont
                          · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
                          · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
                        · split at hcont
                          · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
                          · split at hcont
                            · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
                            · split at hcont
                              · have h' : Except.error _ = Except.ok r := hcont; nomatch h'
                              · obtain ⟨q, hap, hfin⟩ := peelOk _ _ _ hcont
                                obtain ⟨utxo', okN, unjN⟩ := q
                                simp only [] at hfin
                                obtain ⟨rfl⟩ := Except.ok.inj hfin
                                exact ⟨hd, txs, utxo', okN, unjN, heq, hap, rfl⟩

/-- **Bridge at the full pipeline (P15 item 4)**: a block that
`validateBlock` accepts has its report UTXO list produced by W12's
`applyBlockL` fold at the capstone keying `txidKey`, over the txs the
decoder extracted — the executable capstone tier and the proved ledger
tier are the same fold. -/
theorem validateBlock_ok_ledger_fold (raw : ByteArray) (st : CapState) (r : CapReport)
    (hg : (bip30BlockCollision (viewOf st.utxo) txidKey (decodedTxs raw) st.height
      && bip30Enforced st.height) = false)
    (h : validateBlock raw st = Except.ok r) :
    applyBlockL st.utxo txidKey (decodedTxs raw) st.height = Except.ok r.state.utxo := by
  obtain ⟨_, txs, utxo', okN, unjN, hdec, hap, hrst⟩ := validateBlock_ok_inv raw st r h
  have hdt : decodedTxs raw = txs := by
    simp only [decodedTxs, hdec]
  rw [hdt] at hg ⊢
  rw [hrst]
  exact applyTxs_ok_applyBlockL st.height txs 0 0 0 st.utxo utxo' okN unjN hg hap

/-- The anchor-run state's UTXO list has all coin values nonnegative
(INV-030 lineage, at the full pipeline; the initial view's nonnegativity
is the only external hypothesis). -/
theorem validateBlock_ok_utxo_value_nonneg (raw : ByteArray) (st : CapState) (r : CapReport)
    (h : validateBlock raw st = Except.ok r)
    (hval : ∀ p ∈ st.utxo, 0 ≤ p.2.value)
    (hrange : ∀ t ∈ decodedTxs raw, ∀ k < t.vout.length,
      0 ≤ (t.vout.getD k ⟨0, Script.empty⟩).value) :
    ∀ p ∈ r.state.utxo, 0 ≤ p.2.value := by
  obtain ⟨_, txs, utxo', okN, unjN, hdec, hap, hr⟩ := validateBlock_ok_inv raw st r h
  have hdt : decodedTxs raw = txs := by
    simp only [decodedTxs, hdec]
  rw [hdt] at hrange
  rw [hr]
  exact capReport_utxo_value_nonneg st.height txs 0 0 0 st.utxo utxo' okN unjN hval hrange hap

/-- The anchor-run state's UTXO list satisfies the conservation upper
bound on its TOTAL value. -/
theorem validateBlock_ok_utxo_total_le (raw : ByteArray) (st : CapState) (r : CapReport)
    (h : validateBlock raw st = Except.ok r)
    (hval : ∀ p ∈ st.utxo, 0 ≤ p.2.value)
    (hrange : ∀ t ∈ decodedTxs raw, ∀ k < t.vout.length,
      0 ≤ (t.vout.getD k ⟨0, Script.empty⟩).value) :
    listTotal r.state.utxo ≤ listTotal st.utxo + blockDrawn (decodedTxs raw) := by
  obtain ⟨_, txs, utxo', okN, unjN, hdec, hap, hr⟩ := validateBlock_ok_inv raw st r h
  have hdt : decodedTxs raw = txs := by
    simp only [decodedTxs, hdec]
  rw [hdt] at hrange ⊢
  rw [hr]
  exact capReport_utxo_total_le st.height txs 0 0 0 st.utxo utxo' okN unjN hval hrange hap

/-- **THM-037 (upper half) for a fully validated block**: the fee bound
holds for the DECODED txs of any block `validateBlock` accepts, with the
per-tx hypotheses (outputs nonneg, prevouts distinct) DERIVED from the
stateless gate the pipeline itself enforces (BLK-030 → THM-006, TXV-007)
rather than assumed. Remaining external hypotheses: the starting view's
coin nonnegativity and null-freeness, and txid collision-freeness. -/
theorem validateBlock_ok_fees_le (raw : ByteArray) (st : CapState) (r : CapReport)
    (h : validateBlock raw st = Except.ok r)
    (hval : ∀ p ∈ st.utxo, 0 ≤ p.2.value)
    (hnull : coinLookup st.utxo OutPoint.null = none)
    (htxid : ∀ t ∈ decodedTxs raw, txidOf t ≠ zeroBytes 32) :
    chainFeesL st.utxo txidKey (decodedTxs raw) st.height
      ≤ listTotal st.utxo + blockDrawn (decodedTxs raw) := by
  obtain ⟨_, txs, utxo', _, _, hdec, hap, _⟩ := validateBlock_ok_inv raw st r h
  have hdt : decodedTxs raw = txs := by
    simp only [decodedTxs, hdec]
  rw [hdt] at htxid ⊢
  have hall := applyTxs_ok_checkTx_all st.height txs 0 0 0 st.utxo utxo' _ _ hap
  refine fees_le_blockDrawn_txidKey st.utxo txs st.height hval ?_ ?_ htxid hnull
  · intro tx hmem k hk
    exact output_values_nonneg_of_checkTx_none tx (hall tx hmem) k hk
  · intro tx hmem
    exact hasDupPrevouts_eq_false_nodup tx.vin
      (BitcoinProofs.Theorems.LedgerCor.checkTransaction_none_noDup tx (hall tx hmem))

end BitcoinProofs.Theorems.CapstoneConservation
