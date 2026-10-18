import Bitcoin.Capstone.Block

/-!
# BitcoinProofs.Theorems.CapstoneFold — P07: the capstone fold-agreement theorem

capstone executable (`Test.Capstone.Run.runAnchor`) validates each
anchor block through `validateBlock` — whose per-tx stage is
`applyTxs`, the script-layer-interleaved fold — and then cross-checks
the final UTXO list against pure ledger fold
`applyBlockL seeds txidKey txs height`, reporting `foldAgrees`.
All 6 anchors printed `foldAgrees=true` on REAL mainnet data.

This module turns that runtime boolean into proved statements about the
two folds, for arbitrary inputs. The honest shape of the agreement:

* `applyTxs` = `applyBlockL` + stateless, input-value and script gates that can
  abort the fold EARLY (`CapError.txCheck`, `CapError.tx`, `CapError.scriptFail`,
  `CapError.scriptFalse`). Whenever `applyTxs` runs to completion
  (`.ok`), its UTXO list is exactly `applyBlockL`'s — and conversely,
  when the pure ledger fold succeeds and the input-value/script gates pass at
  every step (the `ScriptPass` relation), `applyTxs` succeeds with the
  same UTXO list and explicit counter sums.
* The counters thread additively: the final `(okN, unjN)` dominates the
  start pair (the `CapReport` honesty claims are type-level true).
* The coinbase never reaches the script layer (its `(0, 0)` counters
  are hardwired); only the stateless gate (BLK-030) can stop it.

## Honesty notes (statement hygiene)

* The mission's sketch `(applyTxs …).map Prod.fst = (applyBlockL …
  (txs.drop i) …).map Prod.fst` is ill-typed as written (the two
  `Except`s carry different error types — `CapError` vs `BlockError` —
  so `Except.map` cannot make them comparable) and FALSE for `i > 0`
  (`applyTxs` folds the WHOLE list regardless of `i`; only the runtime
  call at `i = 0` matches `txs.drop i = txs`). The landed theorems are
  the type-correct, true forms: ok-path agreement
  (`applyTxs_ledger_agrees`), lockstep UTXO equality
  (`applyTxs_utxo_lockstep`), the full `ScriptPass` characterization
  (`applyTxs_ok_iff`), and the prefix error refinement
  (`applyTxs_error_refines`).
* Goal 4 (coinbase no-script): the honest form carries the stateless
  gate explicitly — `checkTransaction` still runs on the coinbase
  (BLK-030); only the SCRIPT layer is skipped
  (`applyTx_coinbase_shape`, `applyTx_coinbase_no_script`).

C4 / rule linkage:

| rule / C4 | theorem here | statement (short) |
|-----------|--------------|-------------------|
| (BLK-005 key / BLK-102 core) | `applyTxs_ledger_agrees` | ok path: `applyTxs` success ⇒ `applyBlockL` success with the SAME UTXO list (keyed by the real `txidKey`) |
| (BLK-102 core) | `applyTxs_utxo_lockstep` | when BOTH folds succeed the UTXO lists are equal — the proved form of the runtime `foldAgrees` check |
| (BLK-102 core) | `applyTxs_ok_iff` | full characterization: `applyTxs = ok (l', a, b)` ⟺ `applyBlockL = ok l'` ∧ additive counter decomposition ∧ `ScriptPass` (script layer passes at every step against the true intermediate views) |
| (BLK-030 gate) | `applyTx_coinbase_shape` / `applyTx_coinbase_no_script` | the coinbase path of `applyTx` never calls the script layer; counters hardwired `(0, 0)` |
| (counters) | `applyTxs_counters_ge` | reported `scriptOk`/`scriptUnjudged` dominate the incoming counters |
| (error taxonomy) | `applyTx_error_cases`, `applyTxs_error_refines` | an `applyTxs` failure happens at a specific tx position the pure ledger fold has REACHED; the error is stateless / script-layer / ledger, exactly |
| (runtime bridge) | `validateBlock_fold_agrees` | `validateBlock raw st = ok rep` + the seeds-view ledger fold ok ⇒ the reported `rep.state.utxo` IS the pure ledger fold's result |

Dependencies: `Bitcoin.Capstone.Block` (core executable tier),
`Bitcoin.Ledger.Interface` (fold) — both sorry-free.

## Axiom footprints

Every theorem in this module has footprint
`[propext, Classical.choice, Quot.sound]`:

* `propext`, `Quot.sound` — introduced by the proof tactics
  (`simp`, `omega`, `injection`).
* `Classical.choice` — INHERITED from the layer, not introduced here:
  the core definitions the theorems quantify over and unfold
  (`applyTx`, `applyTxs`, `validateBlock`, `applyBlockL`,
  `checkTransaction`) already depend on it (verified with
  `#print axioms` against the core package).

No `sorry`, no `native_decide`, no `unsafe`/`partial` anywhere.
-/

namespace BitcoinProofs.Theorems.CapstoneFold

open Bitcoin.Data
open Bitcoin.Ledger (Coin Key applyBlockL applyBlockFoldL applyTxStepL bip30BlockCollision bip30Enforced viewOf)
open Bitcoin.Consensus (checkTransaction)
open Bitcoin.TxValidation (checkTxInputs)
open Bitcoin.Serialization (decodeBlock)
open Bitcoin.Capstone.Block (applyTxs applyTx txidKey verifyTxInputs CapError CapState CapReport validateBlock)

/-- Reduction set for `Except`-monad `do`-code: unfolds the monad-class
projections (`Bind.bind`, `throw`) down to `Except.bind` / `Except.error`
and iota-reduces on constructor scrutinees. -/
local macro "exceptSimp" "at" loc:ident : tactic =>
  `(tactic| try simp only [Bind.bind, Except.bind, throw, throwThe, MonadExceptOf.throw,
      Except.map, pure, Except.pure] at $loc:ident)
local macro "exceptSimp" : tactic =>
  `(tactic| try simp only [Bind.bind, Except.bind, throw, throwThe, MonadExceptOf.throw,
      Except.map, pure, Except.pure])

/-! ## One `applyTx` step: inversion and construction -/

/-- Inversion of one successful `applyTx` step: the stateless gate
passed, input values and fees were checked for non-coinbases, the script layer
either was skipped (coinbase: counters
hardwired `(0, 0)`) or returned its counters, and the ledger step
produced exactly the returned UTXO list. -/
theorem applyTx_ok_inv {height : UInt32} {tx : Tx} {txIdx : Nat}
    {l l' : List (OutPoint × Coin)} {a b : Nat}
    (h : applyTx height tx txIdx l = Except.ok (l', a, b)) :
    checkTransaction tx = none ∧
    ((tx.isCoinBase = true ∧ a = 0 ∧ b = 0) ∨
      (tx.isCoinBase = false ∧
        (∃ fee, checkTxInputs tx (viewOf l) height = Except.ok fee) ∧
        verifyTxInputs height tx txIdx l = Except.ok (a, b))) ∧
    applyTxStepL l tx (txidKey tx) height = Except.ok l' := by
  rw [Bitcoin.Capstone.Block.applyTx_unfold] at h
  cases hchk : checkTransaction tx with
  | some e' =>
    rw [hchk] at h
    exceptSimp at h
    simp at h
  | none =>
    rw [hchk] at h
    exceptSimp at h
    cases hcb : tx.isCoinBase with
    | true =>
      rw [hcb] at h
      exceptSimp at h
      cases hs : applyTxStepL l tx (txidKey tx) height with
      | error e => rw [hs] at h; simp at h
      | ok w =>
        rw [hs] at h
        exceptSimp at h
        simp at h
        obtain ⟨e1, e2, e3⟩ := h
        subst e1
        subst e2
        subst e3
        exact ⟨rfl, Or.inl ⟨rfl, rfl, rfl⟩, rfl⟩
    | false =>
      rw [hcb] at h
      exceptSimp at h
      cases hm : checkTxInputs tx (viewOf l) height with
      | error e => rw [hm] at h; exceptSimp at h; simp at h
      | ok fee =>
        rw [hm] at h
        exceptSimp at h
        cases hv : verifyTxInputs height tx txIdx l with
        | error e => rw [hv] at h; simp at h
        | ok q =>
          obtain ⟨c1, c2⟩ := q
          rw [hv] at h
          exceptSimp at h
          cases hs : applyTxStepL l tx (txidKey tx) height with
          | error e => rw [hs] at h; simp at h
          | ok w =>
            rw [hs] at h
            exceptSimp at h
            simp at h
            obtain ⟨e1, e2, e3⟩ := h
            subst e1
            subst e2
            subst e3
            exact ⟨rfl, Or.inr ⟨rfl, ⟨fee, rfl⟩, rfl⟩, rfl⟩

/-- Inversion of one failing `applyTx` step: the error is exactly one
of the stateless gate (`txCheck`), input-value validation (`tx`), the
script layer (non-coinbase only), or the ledger step (`block`). -/
theorem applyTx_error_cases {height : UInt32} {tx : Tx} {txIdx : Nat}
    {l : List (OutPoint × Coin)} {e : CapError}
    (h : applyTx height tx txIdx l = Except.error e) :
    (∃ te, e = CapError.txCheck te ∧ checkTransaction tx = some te) ∨
    (tx.isCoinBase = false ∧ ∃ te, e = CapError.tx te ∧
      checkTxInputs tx (viewOf l) height = Except.error te) ∨
    (tx.isCoinBase = false ∧ verifyTxInputs height tx txIdx l = Except.error e) ∨
    (∃ e', e = CapError.block e' ∧
      applyTxStepL l tx (txidKey tx) height = Except.error e') := by
  rw [Bitcoin.Capstone.Block.applyTx_unfold] at h
  cases hchk : checkTransaction tx with
  | some e' =>
    rw [hchk] at h
    exceptSimp at h
    simp at h
    exact Or.inl ⟨e', h.symm, rfl⟩
  | none =>
    rw [hchk] at h
    exceptSimp at h
    cases hcb : tx.isCoinBase with
    | true =>
      rw [hcb] at h
      exceptSimp at h
      cases hs : applyTxStepL l tx (txidKey tx) height with
      | error e2 =>
        rw [hs] at h
        simp at h
        exact Or.inr (Or.inr (Or.inr ⟨e2, h.symm, rfl⟩))
      | ok w => rw [hs] at h; simp at h
    | false =>
      rw [hcb] at h
      exceptSimp at h
      cases hm : checkTxInputs tx (viewOf l) height with
      | error te =>
        rw [hm] at h
        exceptSimp at h
        simp at h
        exact Or.inr (Or.inl ⟨rfl, te, h.symm, rfl⟩)
      | ok fee =>
        rw [hm] at h
        exceptSimp at h
        cases hv : verifyTxInputs height tx txIdx l with
        | error e2 =>
          rw [hv] at h
          simp at h
          exact Or.inr (Or.inr (Or.inl ⟨rfl, by rw [h]⟩))
        | ok q =>
          rw [hv] at h
          exceptSimp at h
          cases hs : applyTxStepL l tx (txidKey tx) height with
          | error e2 =>
            rw [hs] at h
            simp at h
            exact Or.inr (Or.inr (Or.inr ⟨e2, h.symm, rfl⟩))
          | ok w => rw [hs] at h; simp at h

/-- Forward construction, coinbase case: a coinbase tx that passes the
stateless gate and whose ledger step succeeds produces counters
hardwired to `(0, 0)` — the script layer is never invoked. -/
theorem applyTx_ok_coinbase {height : UInt32} {tx : Tx} {txIdx : Nat}
    {l l₁ : List (OutPoint × Coin)}
    (hc : checkTransaction tx = none) (hcb : tx.isCoinBase = true)
    (hs : applyTxStepL l tx (txidKey tx) height = Except.ok l₁) :
    applyTx height tx txIdx l = Except.ok (l₁, 0, 0) := by
  rw [Bitcoin.Capstone.Block.applyTx_unfold]
  rw [hc, hcb, hs]
  exceptSimp
  rfl

/-- Forward construction, non-coinbase case: the counters are exactly
`verifyTxInputs`'s verdict counts. -/
theorem applyTx_ok_script {height : UInt32} {tx : Tx} {txIdx : Nat}
    {l l₁ : List (OutPoint × Coin)} {a b : Nat}
    (hc : checkTransaction tx = none) (hcb : tx.isCoinBase = false)
    (hm : ∃ fee, checkTxInputs tx (viewOf l) height = Except.ok fee)
    (hv : verifyTxInputs height tx txIdx l = Except.ok (a, b))
    (hs : applyTxStepL l tx (txidKey tx) height = Except.ok l₁) :
    applyTx height tx txIdx l = Except.ok (l₁, a, b) := by
  rw [Bitcoin.Capstone.Block.applyTx_unfold]
  obtain ⟨fee, hm⟩ := hm
  rw [hc, hcb, hm, hv, hs]
  exceptSimp
  rfl

/-- Every successful non-coinbase step ran Core's input-value, maturity
and fee checks against the actual pre-step UTXO view. -/
theorem applyTx_inputs_checked {height : UInt32} {tx : Tx} {txIdx : Nat}
    {l l' : List (OutPoint × Coin)} {a b : Nat}
    (hcb : tx.isCoinBase = false)
    (h : applyTx height tx txIdx l = Except.ok (l', a, b)) :
    ∃ fee, checkTxInputs tx (viewOf l) height = Except.ok fee := by
  rcases (applyTx_ok_inv h).2.1 with ⟨hc, _, _⟩ | ⟨_, hm, _⟩
  · simp [hcb] at hc
  · exact hm

/-- A successful non-coinbase transaction in the live fold conserves
value and pays a nonnegative fee; input checking is obtained from the
pipeline's success, not assumed separately. -/
theorem applyTx_value_conserved {height : UInt32} {tx : Tx} {txIdx : Nat}
    {l l' : List (OutPoint × Coin)} {a b : Nat}
    (hcb : tx.isCoinBase = false)
    (h : applyTx height tx txIdx l = Except.ok (l', a, b)) :
    ∃ fee, checkTxInputs tx (viewOf l) height = Except.ok fee ∧
      Bitcoin.Conservation.totalIn (viewOf l) tx = tx.getValueOut + fee ∧ 0 ≤ fee := by
  obtain ⟨fee, hm⟩ := applyTx_inputs_checked hcb h
  exact ⟨fee, hm, Bitcoin.TxValidation.checkTxInputs_ok_conservation tx (viewOf l) height fee hm⟩

/-- info: 'BitcoinProofs.Theorems.CapstoneFold.applyTx_inputs_checked' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyTx_inputs_checked
/-- info: 'BitcoinProofs.Theorems.CapstoneFold.applyTx_value_conserved' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms applyTx_value_conserved

/-! ## The coinbase never runs the script layer -/

/-- **Coinbase shape (unconditional)**: for a coinbase tx, `applyTx` is
the stateless gate (BLK-030) followed by the ledger step relabeled with
counters hardwired `(0, 0)` — `verifyTxInputs` occurs nowhere in the
computation. -/
theorem applyTx_coinbase_shape {height : UInt32} {tx : Tx} {txIdx : Nat}
    {l : List (OutPoint × Coin)} (hcb : tx.isCoinBase = true) :
    applyTx height tx txIdx l =
      match checkTransaction tx with
      | some e => Except.error (CapError.txCheck e)
      | none =>
        match applyTxStepL l tx (txidKey tx) height with
        | Except.error e => Except.error (CapError.block e)
        | Except.ok w => Except.ok (w, 0, 0) := by
  rw [Bitcoin.Capstone.Block.applyTx_unfold]
  rw [hcb]
  exceptSimp
  cases hchk : checkTransaction tx with
  | some e => rfl
  | none =>
    cases hs : applyTxStepL l tx (txidKey tx) height with
    | error e => rfl
    | ok w => rfl

/-- **Coinbase no-script (gated form)**: when the stateless gate passes,
the coinbase's `applyTx` IS the pure ledger step (relabeled with the
`(0, 0)` counters), with the ledger's `BlockError` lifted to
`CapError.block` — the script layer (`verifyTxInputs`) is never
invoked. -/
theorem applyTx_coinbase_no_script {height : UInt32} {tx : Tx} {txIdx : Nat}
    {l : List (OutPoint × Coin)}
    (hc : checkTransaction tx = none) (hcb : tx.isCoinBase = true) :
    applyTx height tx txIdx l =
      ((applyTxStepL l tx (txidKey tx) height).mapError CapError.block).map
        (fun w => (w, 0, 0)) := by
  rw [applyTx_coinbase_shape hcb, hc]
  cases hs : applyTxStepL l tx (txidKey tx) height with
  | error e => rfl
  | ok w => rfl

/-! ## Counter monotonicity -/

/-- The counters reported by a successful fold dominate the incoming
counters (they are the incoming pair plus nonneg per-tx script
counts): the `CapReport` honesty claims are type-level true. -/
theorem applyTxs_counters_ge (height : UInt32) :
    ∀ (txs : List Tx) (i : Nat) (l : List (OutPoint × Coin)) (okN unjN : Nat)
      (l' : List (OutPoint × Coin)) (a b : Nat),
      applyTxs height txs i l okN unjN = Except.ok (l', a, b) →
      okN ≤ a ∧ unjN ≤ b := by
  intro txs
  induction txs with
  | nil =>
    intro i l okN unjN l' a b h
    simp only [applyTxs] at h
    simp at h
    obtain ⟨_, h2, h3⟩ := h
    omega
  | cons tx rest ih =>
    intro i l okN unjN l' a b h
    simp only [applyTxs] at h
    cases hres : applyTx height tx i l with
    | error e => rw [hres] at h; simp at h
    | ok q =>
      obtain ⟨l₁, a₁, b₁⟩ := q
      rw [hres] at h
      exceptSimp at h
      obtain ⟨h1, h2⟩ := ih (i + 1) l₁ (okN + a₁) (unjN + b₁) l' a b h
      omega

/-- Gate-false form: `applyBlockL` IS the inner fold when the pre-block
BIP30 overlap gate is quiet (D4c-2). -/
theorem applyBlockL_eq_fold {l : List (OutPoint × Coin)} {kf : Tx → Key}
    {txs : List Tx} {height : UInt32}
    (hg : (bip30BlockCollision (viewOf l) kf txs height && bip30Enforced height) = false) :
    applyBlockL l kf txs height = applyBlockFoldL l kf txs height := by
  unfold applyBlockL
  rw [ite_eq_right (by simp [hg])]

/-- A successful `applyBlockL` run certifies its pre-block BIP30 gate was
quiet (an open gate is an unconditional error). -/
theorem applyBlockL_gate_quiet {l : List (OutPoint × Coin)} {kf : Tx → Key}
    {txs : List Tx} {height : UInt32} {L : List (OutPoint × Coin)}
    (h : applyBlockL l kf txs height = Except.ok L) :
    (bip30BlockCollision (viewOf l) kf txs height && bip30Enforced height) = false := by
  unfold applyBlockL at h
  by_cases hg : (bip30BlockCollision (viewOf l) kf txs height
      && bip30Enforced height) = true
  · rw [if_pos hg] at h
    simp at h
  · exact Bool.eq_false_iff.mpr hg

/-! ## THE HEADLINE: ok-path agreement with the pure ledger fold -/

/-- **The capstone fold-agreement theorem (ok path, inner fold)**:
whenever the script-interleaved capstone fold `applyTxs` runs to
completion, the pure ledger inner fold `applyBlockFoldL` (same start
list, same REAL `txidKey` keying, same fixed height) succeeds and ends at
exactly the same UTXO list.

Note on the mission sketch: `applyTxs` folds the WHOLE list `txs`
regardless of the index `i` (which only feeds the per-tx `txIdx` and
the counter threading), so the agreement is with `applyBlockFoldL … txs …`
— at the runtime call site `i = 0` and `txs.drop i = txs`. -/
theorem applyTxs_ledgerFold_agrees (height : UInt32) :
    ∀ (txs : List Tx) (i : Nat) (l : List (OutPoint × Coin)) (okN unjN : Nat)
      (l' : List (OutPoint × Coin)) (a b : Nat),
      applyTxs height txs i l okN unjN = Except.ok (l', a, b) →
      applyBlockFoldL l txidKey txs height = Except.ok l' := by
  intro txs
  induction txs with
  | nil =>
    intro i l okN unjN l' a b h
    simp only [applyTxs] at h
    simp at h
    obtain ⟨e1, _, _⟩ := h
    subst e1
    simp only [applyBlockFoldL]
  | cons tx rest ih =>
    intro i l okN unjN l' a b h
    simp only [applyTxs] at h
    cases hres : applyTx height tx i l with
    | error e => rw [hres] at h; simp at h
    | ok q =>
      obtain ⟨l₁, a₁, b₁⟩ := q
      rw [hres] at h
      exceptSimp at h
      have hstep := (applyTx_ok_inv hres).2.2
      have hrest := ih (i + 1) l₁ (okN + a₁) (unjN + b₁) l' a b h
      rw [applyBlockFoldL, hstep]
      exceptSimp
      exact hrest

/-- **The capstone fold-agreement theorem (ok path, gated wrapper)**:
whenever `applyTxs` runs to completion and the pre-block BIP30 gate is
quiet, the ledger fold `applyBlockL` succeeds at the same UTXO list.
The gate hypothesis is REAL post-D4c-2: `applyBlockL` performs Core
2466-2475's pristine overlap check while the capstone tier does not, so
a gate-firing block is a genuine tier divergence and cannot be bridged
without it. -/
theorem applyTxs_ledger_agrees (height : UInt32) :
    ∀ (txs : List Tx) (i : Nat) (l : List (OutPoint × Coin)) (okN unjN : Nat)
      (l' : List (OutPoint × Coin)) (a b : Nat),
      (bip30BlockCollision (viewOf l) txidKey txs height && bip30Enforced height) = false →
      applyTxs height txs i l okN unjN = Except.ok (l', a, b) →
      applyBlockL l txidKey txs height = Except.ok l' := by
  intro txs i l okN unjN l' a b hg h
  rw [applyBlockL_eq_fold hg]
  exact applyTxs_ledgerFold_agrees height txs i l okN unjN l' a b h

/-- The runtime `i = 0` call shape: agreement with `txs.drop 0 = txs`. -/
theorem applyTxs_ledger_agrees_drop0 (height : UInt32) (txs : List Tx)
    (l : List (OutPoint × Coin)) (okN unjN : Nat)
    (l' : List (OutPoint × Coin)) (a b : Nat)
    (hg : (bip30BlockCollision (viewOf l) txidKey txs height && bip30Enforced height) = false)
    (h : applyTxs height txs 0 l okN unjN = Except.ok (l', a, b)) :
    applyBlockL l txidKey (txs.drop 0) height = Except.ok l' := by
  rw [List.drop_zero]
  exact applyTxs_ledger_agrees height txs 0 l okN unjN l' a b hg h

/-- **Lockstep (converse ok-path, inner fold)**: when BOTH the inner
ledger fold and the capstone fold succeed, the UTXO lists coincide —
the proved statement behind the runtime `foldAgrees` cross-check. -/
theorem applyTxs_utxo_lockstep_fold (height : UInt32) :
    ∀ (txs : List Tx) (i : Nat) (l : List (OutPoint × Coin)) (okN unjN : Nat)
      (L : List (OutPoint × Coin)) (l' : List (OutPoint × Coin)) (a b : Nat),
      applyBlockFoldL l txidKey txs height = Except.ok L →
      applyTxs height txs i l okN unjN = Except.ok (l', a, b) →
      l' = L := by
  intro txs
  induction txs with
  | nil =>
    intro i l okN unjN L l' a b hA hT
    simp only [applyTxs] at hT
    simp only [applyBlockFoldL] at hA
    exceptSimp at hT
    exceptSimp at hA
    injection hA with hA'
    injection hT with hT'
    injection hT' with hTx _
    exact hTx.symm.trans hA'
  | cons tx rest ih =>
    intro i l okN unjN L l' a b hA hT
    rw [applyBlockFoldL] at hA
    cases hs : applyTxStepL l tx (txidKey tx) height with
    | error e =>
      rw [hs] at hA
      exceptSimp at hA
      simp at hA
    | ok l₂ =>
      rw [hs] at hA
      exceptSimp at hA
      simp only [applyTxs] at hT
      cases hres : applyTx height tx i l with
      | error e => rw [hres] at hT; simp at hT
      | ok q =>
        obtain ⟨l₁, a₁, b₁⟩ := q
        rw [hres] at hT
        exceptSimp at hT
        have hstep := (applyTx_ok_inv hres).2.2
        -- align the two names for the post-head UTXO view: hstep and hs
        -- have the same left-hand side, so their ok-values coincide
        have hEq : l₁ = l₂ := by
          have h2 := hs.symm.trans hstep
          injection h2 with h3
          exact h3.symm
        rw [hEq] at hT
        exact ih (i + 1) l₂ (okN + a₁) (unjN + b₁) L l' a b hA hT

/-- **Lockstep (converse ok-path)**: when BOTH folds succeed, the UTXO
lists coincide — a successful `applyBlockL` certifies its gate quiet, so
this reduces to the inner-fold lockstep. -/
theorem applyTxs_utxo_lockstep (height : UInt32) :
    ∀ (txs : List Tx) (i : Nat) (l : List (OutPoint × Coin)) (okN unjN : Nat)
      (L : List (OutPoint × Coin)) (l' : List (OutPoint × Coin)) (a b : Nat),
      applyBlockL l txidKey txs height = Except.ok L →
      applyTxs height txs i l okN unjN = Except.ok (l', a, b) →
      l' = L := by
  intro txs i l okN unjN L l' a b hA hT
  have hg := applyBlockL_gate_quiet hA
  rw [applyBlockL_eq_fold hg] at hA
  exact applyTxs_utxo_lockstep_fold height txs i l okN unjN L l' a b hA hT

/-- Inversion of a successful pure ledger fold: either the list was
empty (nothing spent, nothing gained) or the first tx's step produced
`l₁` and the rest of the INNER fold succeeded from there (the block gate
has already been passed, so the continuation is gate-free). -/
theorem applyBlockL_ok_inv {l : List (OutPoint × Coin)} {kf : Tx → Key}
    {height : UInt32} {L : List (OutPoint × Coin)} {txs : List Tx}
    (h : applyBlockL l kf txs height = Except.ok L) :
    txs = [] ∧ L = l ∨
    ∃ tx rest l₁, txs = tx :: rest ∧
      applyTxStepL l tx (kf tx) height = Except.ok l₁ ∧
      applyBlockFoldL l₁ kf rest height = Except.ok L := by
  cases txs with
  | nil =>
    simp only [applyBlockL] at h
    exceptSimp at h
    injection h with h1
    exact Or.inl ⟨rfl, h1.symm⟩
  | cons tx rest =>
    simp only [applyBlockL] at h
    by_cases hg : (bip30BlockCollision (viewOf l) kf (tx :: rest) height
        && bip30Enforced height) = true
    · rw [if_pos hg] at h; simp at h
    · rw [if_neg hg] at h
      rw [applyBlockFoldL] at h
      cases hs : applyTxStepL l tx (kf tx) height with
      | error e =>
        rw [hs] at h
        exceptSimp at h
        simp at h
      | ok l₁ =>
        rw [hs] at h
        exceptSimp at h
        exact Or.inr ⟨tx, rest, l₁, rfl, hs, h⟩

/-! ## The ScriptPass relation: the script layer passes at every step -/

/-- `ScriptPass height txs i l l' a b`: starting from UTXO list `l` at
tx index `i`, every tx of `txs` passes the stateless gate (BLK-030),
its ledger step succeeds, and its input-value/script gates either are skipped
(coinbase: counters `(0, 0)`) or returns counters `(a, b)` without
error; the fold ends at `l'` having accumulated script counters
`a, b`. This is exactly "no additional validation gate fails along the fold", with
the TRUE intermediate UTXO views (each tx's script layer sees the view
produced by the preceding txs of the same block). -/
inductive ScriptPass (height : UInt32) :
    List Tx → Nat → List (OutPoint × Coin) → List (OutPoint × Coin) → Nat → Nat → Prop where
  | nil (i : Nat) (l : List (OutPoint × Coin)) :
      ScriptPass height [] i l l 0 0
  | base (tx : Tx) (rest : List Tx) (i : Nat)
      (l l₁ l' : List (OutPoint × Coin)) (a' b' : Nat)
      (hc : checkTransaction tx = none)
      (hs : applyTxStepL l tx (txidKey tx) height = Except.ok l₁)
      (hcb : tx.isCoinBase = true)
      (hrest : ScriptPass height rest (i + 1) l₁ l' a' b') :
      ScriptPass height (tx :: rest) i l l' a' b'
  | step (tx : Tx) (rest : List Tx) (i : Nat)
      (l l₁ l' : List (OutPoint × Coin)) (a b a' b' : Nat)
      (hc : checkTransaction tx = none)
      (hs : applyTxStepL l tx (txidKey tx) height = Except.ok l₁)
      (hcb : tx.isCoinBase = false)
      (hm : ∃ fee, checkTxInputs tx (viewOf l) height = Except.ok fee)
      (hv : verifyTxInputs height tx i l = Except.ok (a, b))
      (hrest : ScriptPass height rest (i + 1) l₁ l' a' b') :
      ScriptPass height (tx :: rest) i l l' (a + a') (b + b')

/-- `ScriptPass` implies the pure ledger fold succeeds with the same
final UTXO list. -/
theorem scriptPass_ledger_ok (height : UInt32) :
    ∀ (txs : List Tx) (i : Nat) (l l' : List (OutPoint × Coin)) (a b : Nat),
      ScriptPass height txs i l l' a b →
      applyBlockFoldL l txidKey txs height = Except.ok l' := by
  intro txs i l l' a b hsp
  induction hsp with
  | nil i l => simp only [applyBlockFoldL]
  | base tx rest i l l₁ l' a' b' hc hs hcb hrest ih =>
    rw [applyBlockFoldL, hs]
    exceptSimp
    exact ih
  | step tx rest i l l₁ l' a b a' b' hc hs hcb hm hv hrest ih =>
    rw [applyBlockFoldL, hs]
    exceptSimp
    exact ih

/-- `ScriptPass` determines the exact counter behavior of `applyTxs`. -/
theorem scriptPass_applyTxs (height : UInt32) :
    ∀ (txs : List Tx) (i : Nat) (l l' : List (OutPoint × Coin))
      (a b : Nat),
      ScriptPass height txs i l l' a b →
      ∀ (okN unjN : Nat),
        applyTxs height txs i l okN unjN = Except.ok (l', okN + a, unjN + b) := by
  intro txs i l l' a b hsp
  induction hsp with
  | nil i l => intro okN unjN; simp only [applyTxs]; rfl
  | base tx rest i l l₁ l' a' b' hc hs hcb hrest ih =>
    intro okN unjN
    simp only [applyTxs]
    rw [applyTx_ok_coinbase hc hcb hs]
    exceptSimp
    rw [Nat.add_zero, Nat.add_zero]
    exact ih (okN + 0) (unjN + 0)
  | step tx rest i l l₁ l' a b a' b' hc hs hcb hm hv hrest ih =>
    intro okN unjN
    simp only [applyTxs]
    rw [applyTx_ok_script hc hcb hm hv hs]
    exceptSimp
    rw [← Nat.add_assoc, ← Nat.add_assoc]
    exact ih (okN + a) (unjN + b)

/-- Converse: a pure-ledger success together with a completed
`applyTxs` run yields `ScriptPass` (with the counter difference as the
script-layer contribution). -/
theorem scriptPass_of_agree (height : UInt32) :
    ∀ (txs : List Tx) (i : Nat) (l l' : List (OutPoint × Coin))
      (okN unjN a b : Nat),
      applyBlockFoldL l txidKey txs height = Except.ok l' →
      applyTxs height txs i l okN unjN = Except.ok (l', a, b) →
      okN ≤ a → unjN ≤ b →
      ScriptPass height txs i l l' (a - okN) (b - unjN) := by
  intro txs
  induction txs with
  | nil =>
    intro i l l' okN unjN a b hA hT _ _
    simp only [applyBlockFoldL] at hA
    simp only [applyTxs] at hT
    exceptSimp at hA
    exceptSimp at hT
    injection hA with hA'
    injection hT with hT'
    injection hT' with _ eT23
    injection eT23 with eT2 eT3
    subst hA'
    subst eT2
    subst eT3
    simp only [Nat.sub_self]
    exact ScriptPass.nil i l
  | cons tx rest ih =>
    intro i l l' okN unjN a b hA hT hle₁ hle₂
    rw [applyBlockFoldL] at hA
    cases hstepA : applyTxStepL l tx (txidKey tx) height with
    | error e =>
      rw [hstepA] at hA
      exceptSimp at hA
      simp at hA
    | ok l₂ =>
      rw [hstepA] at hA
      exceptSimp at hA
      have hrestA := hA
      simp only [applyTxs] at hT
      cases hres : applyTx height tx i l with
      | error e => rw [hres] at hT; simp at hT
      | ok q =>
        obtain ⟨l₁, a₁, b₁⟩ := q
        rw [hres] at hT
        exceptSimp at hT
        have hstep := (applyTx_ok_inv hres).2.2
        have hEq : l₁ = l₂ := by
          have h2 := hstepA.symm.trans hstep
          injection h2 with h3
          exact h3.symm
        subst hEq
        obtain ⟨hge₁, hge₂⟩ :=
          applyTxs_counters_ge height rest (i + 1) l₁ (okN + a₁) (unjN + b₁) l' a b hT
        have hrec := ih (i + 1) l₁ l' (okN + a₁) (unjN + b₁) a b
          hrestA hT hge₁ hge₂
        rcases (applyTx_ok_inv hres).2.1 with ⟨hcb, ha0, hb0⟩ | ⟨hcb, hm, hv⟩
        · -- coinbase: this tx contributes counters (0, 0)
          rw [ha0, hb0] at hrec
          refine ScriptPass.base tx rest i l l₁ l' (a - okN) (b - unjN)
            (applyTx_ok_inv hres).1 hstepA hcb ?_
          simpa using hrec
        · have hkey₁ : a₁ + (a - (okN + a₁)) = a - okN := by omega
          have hkey₂ : b₁ + (b - (unjN + b₁)) = b - unjN := by omega
          rw [← hkey₁, ← hkey₂]
          exact ScriptPass.step tx rest i l l₁ l' a₁ b₁ (a - (okN + a₁)) (b - (unjN + b₁))
            (applyTx_ok_inv hres).1 hstepA hcb hm hv hrec

/-- **THE CHARACTERIZATION**: `applyTxs` succeeds with UTXO list `l'`
and counters `(a, b)` if and only if the pure ledger fold succeeds
with the SAME `l'` and the input-value/script gates pass at every step
(`ScriptPass`), the counters decomposing additively. -/
theorem applyTxs_ok_iff (height : UInt32) (txs : List Tx) (i : Nat)
    (l l' : List (OutPoint × Coin)) (okN unjN a b : Nat)
    (hg : (bip30BlockCollision (viewOf l) txidKey txs height && bip30Enforced height) = false) :
    applyTxs height txs i l okN unjN = Except.ok (l', a, b) ↔
      (applyBlockL l txidKey txs height = Except.ok l' ∧
        ∃ a' b', a = okN + a' ∧ b = unjN + b' ∧
          ScriptPass height txs i l l' a' b') := by
  constructor
  · intro h
    obtain ⟨hge₁, hge₂⟩ := applyTxs_counters_ge height txs i l okN unjN l' a b h
    have hA := applyTxs_ledger_agrees height txs i l okN unjN l' a b hg h
    refine ⟨hA, a - okN, b - unjN, by omega, by omega, ?_⟩
    rw [applyBlockL_eq_fold hg] at hA
    exact scriptPass_of_agree height txs i l l' okN unjN a b hA h hge₁ hge₂
  · intro ⟨hA, a', b', ha, hb, hsp⟩
    have h := scriptPass_applyTxs height txs i l l' a' b' hsp okN unjN
    rw [← ha, ← hb] at h
    exact h

/-! ## Error refinement: where the folds can diverge -/

/-- **Error refinement (the honest statement-2)**: if `applyTxs` fails,
then it fails at a specific tx — the head of the suffix after a prefix
`pre` that the pure ledger fold processed successfully (its view there
is `lPre`) — and the error is exactly one of: the stateless gate
(`txCheck`), the input-value gate (`tx`), the script layer on a non-coinbase
tx (a `verifyTxInputs` error — an additional failure on top of
`applyBlockL`), or the ledger step's own error (wrapped as
`CapError.block`). The script layer never changes the UTXO
computation — it can only stop the fold earlier. -/
theorem applyTxs_error_refines (height : UInt32) :
    ∀ (txs : List Tx) (i : Nat) (l : List (OutPoint × Coin)) (okN unjN : Nat)
      (e : CapError),
      applyTxs height txs i l okN unjN = Except.error e →
      ∃ (pre : List Tx) (tx : Tx) (rest : List Tx) (lPre : List (OutPoint × Coin)),
        txs = pre ++ tx :: rest ∧
        applyBlockFoldL l txidKey pre height = Except.ok lPre ∧
        ((∃ te, e = CapError.txCheck te ∧ checkTransaction tx = some te) ∨
          (tx.isCoinBase = false ∧ ∃ te, e = CapError.tx te ∧
            checkTxInputs tx (viewOf lPre) height = Except.error te) ∨
          (tx.isCoinBase = false ∧
            verifyTxInputs height tx (i + pre.length) lPre = Except.error e) ∨
          (∃ e', e = CapError.block e' ∧
            applyTxStepL lPre tx (txidKey tx) height = Except.error e')) := by
  intro txs
  induction txs with
  | nil =>
    intro i l okN unjN e h
    simp only [applyTxs] at h
    simp at h
  | cons tx rest ih =>
    intro i l okN unjN e h
    simp only [applyTxs] at h
    cases hres : applyTx height tx i l with
    | error e' =>
      rw [hres] at h
      exceptSimp at h
      have he : e' = e := by simp at h; exact h
      rw [he] at hres
      rcases applyTx_error_cases hres with
        ⟨te, hte, hchk⟩ | ⟨hcb, te, heq, hm⟩ | ⟨hcb, hv⟩ | ⟨e'', heq, hstep⟩
      · exact ⟨[], tx, rest, l, rfl, rfl, Or.inl ⟨te, hte, hchk⟩⟩
      · exact ⟨[], tx, rest, l, rfl, rfl,
          Or.inr (Or.inl ⟨hcb, te, heq, hm⟩)⟩
      · exact ⟨[], tx, rest, l, rfl, rfl,
          Or.inr (Or.inr (Or.inl ⟨hcb, by simpa using hv⟩))⟩
      · exact ⟨[], tx, rest, l, rfl, rfl,
          Or.inr (Or.inr (Or.inr ⟨e'', heq, hstep⟩))⟩
    | ok q =>
      obtain ⟨l₁, a₁, b₁⟩ := q
      rw [hres] at h
      exceptSimp at h
      obtain ⟨pre, tx', rest', lPre, heqTxs, hpre, hdisj⟩ :=
        ih (i + 1) l₁ (okN + a₁) (unjN + b₁) e h
      refine ⟨tx :: pre, tx', rest', lPre, ?_, ?_, ?_⟩
      · rw [heqTxs, List.cons_append]
      · rw [applyBlockFoldL, (applyTx_ok_inv hres).2.2]
        exceptSimp
        exact hpre
      · rw [List.length_cons,
          show i + (pre.length + 1) = i + 1 + pre.length from by omega]
        exact hdisj

/-! ## The runtime bridge: validateBlock's reported state -/

-- `backward.split false` selects `split`'s lightweight simp context: the
-- default-context path exceeds its simp step budget on the large
-- unfolded `validateBlock` `do`-term.
set_option backward.split false in
/-- **The runtime corollary**: if `validateBlock` succeeds (as it did
for all 6 anchors) and the decoded tx list folded through the pure
ledger fold `applyBlockL` (from the seed view, keyed by the real
`txidKey`, at the connection height) also succeeds, then the UTXO list
the capstone reports in `rep.state.utxo` IS the pure ledger fold's
result — the proved form of the anchor run's `foldAgrees=true`. -/
theorem validateBlock_fold_agrees (raw : ByteArray) (st : CapState)
    (rep : CapReport) (L : List (OutPoint × Coin)) (hd : Bitcoin.Chain.BlockHeader)
    (txs : List Tx)
    (hdec : decodeBlock raw = Except.ok (hd, txs))
    (hval : validateBlock raw st = Except.ok rep)
    (hfold : applyBlockL st.utxo txidKey txs st.height = Except.ok L) :
    L = rep.state.utxo := by
  unfold validateBlock at hval
  rw [hdec] at hval
  exceptSimp at hval
  -- walk the 14 header/structure/contextual/merkle gates: each
  -- either throws (contradiction with the ok report) or passes.
  split at hval
  · cases hval
  · split at hval
    · cases hval
    · split at hval
      · cases hval
      · split at hval
        · cases hval
        · split at hval
          · cases hval
          · split at hval
            · cases hval
            · split at hval
              · cases hval
              · split at hval
                · cases hval
                · split at hval
                  · cases hval
                  · split at hval
                    · cases hval
                    · have hval := (Bitcoin.Capstone.Block.unit_precheck_ok _ _ hval).2
                      split at hval
                      · -- commitmentGate hit: one more if (anyWitness)
                        split at hval
                        · cases hval
                        · cases hval
                      · split at hval
                        · cases hval
                        · split at hval
                          · cases hval
                          · split at hval
                            · cases hval
                            · split at hval
                              · cases hval
                              · -- per-tx stage: extract the applyTxs result
                                cases hbudget : Bitcoin.Capstone.Block.applyBlockTransactionsWithSigops none st.height
                                    (Bitcoin.Capstone.Block.candidateScriptFlags st.height hd) txs st.utxo with
                                | error e =>
                                  rw [hbudget] at hval
                                  exceptSimp at hval
                                  cases hval
                                | ok r =>
                                  obtain ⟨⟨u', okN, unjN⟩, sigops⟩ := r
                                  have hfund : Bitcoin.Capstone.Block.applyBlockTransactions st.height txs st.utxo =
                                      .ok (u', okN, unjN) :=
                                    Bitcoin.Capstone.Block.applyBlockTransactionsWithSigops_projection hbudget
                                  rw [hbudget] at hval
                                  exceptSimp at hval
                                  injection hval with hrep
                                  have hap := Bitcoin.Capstone.Block.applyBlockTransactions_ok hfund
                                  -- the report's utxo IS the applyTxs result
                                  have hu : u' = rep.state.utxo := by
                                    rw [← hrep]
                                  -- ledger agreement: L = u'
                                  have hg := applyBlockL_gate_quiet hfold
                                  have hagr :=
                                    applyTxs_ledger_agrees st.height txs 0 st.utxo 0 0
                                      u' okN unjN hg hap
                                  rw [hfold] at hagr
                                  injection hagr with hL
                                  rw [hL, hu]

end BitcoinProofs.Theorems.CapstoneFold
