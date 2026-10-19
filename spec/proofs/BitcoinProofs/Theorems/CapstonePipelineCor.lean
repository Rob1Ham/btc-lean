import Bitcoin.Capstone.Block
import BitcoinProofs.Theorems.CapstoneFoldAgree

/-!
# BitcoinProofs.Theorems.CapstonePipelineCor — P16: the proved pipeline-shape spec (sorry-free)

Theorems about the SHAPE of the capstone pipeline (`Bitcoin.Capstone.Block`,
S2b): what `applyTx` / `applyTxs` / `validateBlock` return, as exact
`Except`-monad equations. These turn the runtime booleans of the anchor
run (6/6 PASS, 11,825 inputs adjudicated) into proved statements: the
success state's height, parent link, UTXO set, tx count and script counters
are pinned to the pipeline's actual dataflow.

C4 portfolio linkage:

| C4 ID | theorem here | statement (short) | axioms |
|-------|--------------|-------------------|--------|
| (P16-3) | `applyTx_eq` | the exact equation: stateless gate, checked input values/fees, scripts (coinbase skipped), then ledger update | T |
| (P16-2) | `applyTx_coinbase_eq` / `applyTx_coinbase_counters` | the coinbase skips the script layer: counters exactly (0, 0) | T |
| (P16-3 cor) | `applyTx_ledger_first` / `applyTx_ledger_first_coinbase` | non-coinbase input errors precede scripts; the coinbase branch skips input/script validation | T |
| (P16-3 cor) | `applyTx_script_first` | after input validation succeeds, the script layer's failure propagates verbatim | T |
| (P16-1) | `applyTxs_counters_sum` | `applyTxs` threads counters monotonically: `okN ≤ okN'` and `unjN ≤ unjN'` | T |
| (P16-1 cor) | `applyTxs_counters_bound` | `okN' + unjN' ≤ okN + unjN + totalVins txs` | T |
| (P16-4) | `verifyTxInputs_loop_total` / `verifyTxInputs_total` | `verifyTxInputs = .ok (okN, unjN)` implies `okN + unjN ≤ tx.vin.length` (induction on the input loop, invariant `okN + unjN ≤ i`) | T |
| (P16-4 cor) | `applyTx_counters_bound` | one `applyTx` success: `a + b ≤ tx.vin.length` | T |
| (P16-5) | `validateBlock_ok_shape` | IF `validateBlock raw st = .ok r` THEN the report is exactly the decode/applyTxs dataflow, with the nameable gate conjunction as hypotheses | P + T |
| (P16-5 cor) | `validateBlock_ok_height` / `validateBlock_ok_prevHash` / `validateBlock_ok_txCount` / `validateBlock_counters_le` | the honest poststate contract, field by field | P + T |

Honesty notes: (a) the `cbLengthOk` / `bip34Ok` / witness-commitment gates
mention the module-private `dummyTx` stand-in in `validateBlock`'s body, so
they are enforced by the pipeline but not nameable from outside the module;
every OTHER gate appears as a hypothesis of `validateBlock_ok_shape`.
(b) `applyTx`'s stateless gate is reflected exactly: `applyTx_eq` keeps the
`match checkTransaction tx` at the top, so a `txCheck` failure
short-circuits before the script and ledger layers. (c) inputs whose coin
is missing from the UTXO view contribute NO script verdict
(`verifyTxInputs`' `coinLookup = none` lane) — hence the counters are
bounded by, not equal to, the input supply.

Axiom footprints (audited with `#print axioms` in the P16 scratch area,
NOT in this file; `T := [propext, Classical.choice, Quot.sound]`,
`P := [propext]`):

* `ebind_ok` / `ebind_err` / `ethrow` / `epure_ok` / `totalVins_nil` /
  `totalVins_cons`: NO axioms (pure `rfl`).
* `gate_true_of_not_not` / `bool_not_false` / `gate_step` / `gate_step2`:
  `propext` only.
* Every theorem row marked `T` depends on exactly
  `[propext, Classical.choice, Quot.sound]`. This triple is INHERITED from
  the core definitions themselves — `#print axioms` shows
  `Bitcoin.Consensus.checkTransaction`, `Bitcoin.Capstone.Block.verifyTxInputs`,
  `applyTxs`, `applyTx` and their `eq_1` equation lemmas each carry exactly
  this triple, so any theorem stating their shape cannot do better without
  editing the core module. In particular no `sorryAx` appears anywhere, and
  the rows marked `P + T` add nothing beyond `propext` on top of the
  inherited triple.
-/

namespace BitcoinProofs.Theorems.CapstonePipeline

-- Script flags are threaded uniformly through every compared execution.
variable {flags : Bitcoin.Activation.ScriptFlags}

open Bitcoin.Capstone.Block Bitcoin.Capstone.Pow Bitcoin.Capstone.Merkle
open Bitcoin.Data Bitcoin.Ledger Bitcoin.Consensus Bitcoin.Serialization

/-! ## Helpers -/

/-- Except-bind reduction on the `ok` branch (core ships no `Except.bind_ok`
in v4.35). Stated with `>>=` so its head symbol is the generic `Bind.bind`
that do-notation actually elaborates to. -/
@[simp] theorem ebind_ok {ε α β : Type} {a : α} (f : α → Except ε β) :
    (Except.ok a) >>= f = f a := rfl

/-- Except-bind reduction on the `error` branch. -/
@[simp] theorem ebind_err {ε α β : Type} {e : ε} (f : α → Except ε β) :
    (Except.error e) >>= f = Except.error e := rfl

/-- do-notation's `throw` is `Except.error` (`throw` is a plain definition,
so simp cannot see through it without this lemma). -/
@[simp] theorem ethrow {ε β : Type} (e : ε) :
    (throw e : Except ε β) = Except.error e := rfl

/-- do-notation's `pure` is `Except.ok`. -/
@[simp] theorem epure_ok {ε α : Type} (a : α) :
    (pure a : Except ε α) = Except.ok a := rfl

/-- A `validateBlock` gate: the pipeline tests `g = true` for some `Bool` `g`
and, if so, exits with `throw E`; otherwise the `Unit`-continuation `jp`
runs. On success (`= .ok r`) the gate test must have FAILED (`g = false`)
and the continuation returned `r`. The continuation `jp` is inferred by
higher-order unification, so gates mentioning module-private definitions
(`dummyTx` stand-ins) peel too. For the plain gates `g` is the negation
`!check`, so `g = false` converts to `check = true` via `bool_not_false`;
for the witness-commitment gates `g` is a conjunction of `Bool`s. -/
theorem gate_true_of_not_not (c : Bool) (h : ¬ ((!c) = true)) : c = true := by
  cases hc : c with
  | true => rfl
  | false => simp [hc] at h

theorem bool_not_false {b : Bool} (h : (!b) = false) : b = true := by
  cases hb : b with
  | true => rfl
  | false => rw [hb] at h; simp at h

theorem gate_step (g : Bool) {E : CapError} (jp : Unit → Except CapError CapReport)
    {r : CapReport}
    (h : (if g = true then ((throw E : Except CapError Unit) >>= jp)
          else jp ()) = .ok r) :
    g = false ∧ jp () = .ok r := by
  split at h
  · rw [ethrow, ebind_err] at h; simp at h
  · rename_i hc
    refine ⟨?_, h⟩
    cases hg : g with
    | false => rfl
    | true => simp [hg] at hc

/-- The commitment gate: a nested decision with two error exits (`anyWitness`
lane). On success the commitment gate test failed and the continuation runs. -/
theorem gate_step2 (cg aw : Bool) {E₁ E₂ : CapError}
    (jp : Unit → Except CapError CapReport) {r : CapReport}
    (h : (if (!cg) = true then
            (if aw = true then ((throw E₁ : Except CapError Unit) >>= jp)
                      else ((throw E₂ : Except CapError Unit) >>= jp))
          else jp ()) = .ok r) :
    (!cg) = false ∧ jp () = .ok r := by
  split at h
  · split at h
    · rw [ethrow, ebind_err] at h; simp at h
    · rw [ethrow, ebind_err] at h; simp at h
  · rename_i hc
    refine ⟨?_, h⟩
    cases hg : cg with
    | false => simp [hg] at hc
    | true => rfl

/-- The ledger continuation of `applyTx`: given the script layer's counters
`(okN, unjN)`, run the ledger step and attach the counters to its
success value. Its error is wrapped as `CapError.block`. -/
def applyTxCont (height : UInt32) (tx : Tx) (_txIdx : Nat)
    (l : List (OutPoint × Coin)) (x : Nat × Nat) :
    Except CapError (List (OutPoint × Coin) × Nat × Nat) :=
  match x with
  | (okN, unjN) =>
    match applyTxStepL l tx (txidKey tx) height with
    | .error e => .error (CapError.block e)
    | .ok l' => .ok (l', okN, unjN)

/-- Total input supply of a tx list: the sum of `tx.vin.length`. -/
def totalVins (txs : List Tx) : Nat := txs.foldr (fun t acc => t.vin.length + acc) 0

/-- `totalVins` of the empty list. -/
theorem totalVins_nil : totalVins [] = 0 := rfl

/-- `totalVins` of a cons is the head's input count plus the tail's. -/
theorem totalVins_cons (tx : Tx) (rest : List Tx) :
    totalVins (tx :: rest) = tx.vin.length + totalVins rest := rfl

/-! ## The exact `applyTx` equation -/

/-- **P16-3 — the exact `Except`-bind equation for `applyTx`**. Unfolds the
do-block honestly: the stateless gate (`checkTransaction`) runs first
and short-circuits with `CapError.txCheck`; non-coinbases next run
`checkTxInputs` against the current view, then `verifyTxInputs` against the
CURRENT utxo `l`; then the ledger step `applyTxStepL` keyed by the
real txid, whose error is wrapped as `CapError.block` and whose success
threads the final utxo together with the script counters. -/
theorem applyTx_eq (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l : List (OutPoint × Coin)) :
    applyTx height tx txIdx l flags =
      match checkTransaction tx with
      | some e =>
          (throw (CapError.txCheck e) :
              Except CapError (List (OutPoint × Coin) × Nat × Nat)) >>= fun _ =>
            if tx.isCoinBase = true then (Except.ok (0, 0)) >>= applyTxCont height tx txIdx l
            else (match Bitcoin.TxValidation.checkTxInputs tx (viewOf l) height with
              | .error e => Except.error (CapError.tx e)
              | .ok _ => verifyTxInputs height tx txIdx l flags) >>= applyTxCont height tx txIdx l
      | none =>
          if tx.isCoinBase = true then (Except.ok (0, 0)) >>= applyTxCont height tx txIdx l
          else (match Bitcoin.TxValidation.checkTxInputs tx (viewOf l) height with
              | .error e => Except.error (CapError.tx e)
              | .ok _ => verifyTxInputs height tx txIdx l flags) >>= applyTxCont height tx txIdx l := by
  cases hc : checkTransaction tx with
  | some e => simp [Bitcoin.Capstone.Block.applyTx_unfold, hc, ethrow]
  | none =>
    by_cases hcb : tx.isCoinBase = true
    · simp [Bitcoin.Capstone.Block.applyTx_unfold, hc, hcb, applyTxCont] <;> rfl
    · cases hm : Bitcoin.TxValidation.checkTxInputs tx (viewOf l) height with
      | error e =>
        simp [Bitcoin.Capstone.Block.applyTx_unfold, hc, hcb, hm, applyTxCont, ethrow]
      | ok fee =>
        cases hv : verifyTxInputs height tx txIdx l flags with
        | error e =>
          simp [Bitcoin.Capstone.Block.applyTx_unfold, hc, hcb, hm, hv, applyTxCont] <;> rfl
        | ok c =>
          obtain ⟨a, b⟩ := c
          simp [Bitcoin.Capstone.Block.applyTx_unfold, hc, hcb, hm, hv, applyTxCont] <;> rfl

/-- **P16-2 (equation form)**: for the coinbase (stateless check passing),
`applyTx` IS the ledger step with counters pinned to `(0, 0)` — the
coinbase never touches the script layer. -/
theorem applyTx_coinbase_eq (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l : List (OutPoint × Coin))
    (hcb : tx.isCoinBase = true) (hchk : checkTransaction tx = none) :
    applyTx height tx txIdx l flags =
      match applyTxStepL l tx (txidKey tx) height with
      | .error e => .error (CapError.block e)
      | .ok l' => .ok (l', 0, 0) := by
  simp only [Bitcoin.Capstone.Block.applyTx_unfold, hchk, hcb, ethrow, epure_ok, ebind_ok]
  rfl

/-- **P16-2 (counter form)**: whenever the coinbase's `applyTx` succeeds,
the returned script counters are exactly `(0, 0)`. -/
theorem applyTx_coinbase_counters (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l l' : List (OutPoint × Coin)) (a b : Nat)
    (hcb : tx.isCoinBase = true)
    (h : applyTx height tx txIdx l flags = .ok (l', a, b)) :
    a = 0 ∧ b = 0 := by
  revert h
  simp only [Bitcoin.Capstone.Block.applyTx_unfold]
  split
  · intro h; simp at h
  · simp [hcb, ethrow]
    split
    · intro h; simp at h
    · intro h
      simp only [Except.ok.injEq, Prod.mk.injEq] at h
      omega

/-- Input availability, maturity and value failures precede script execution.
The name retains the ledger-before-script ordering of this contract, but
Core's `CheckTxInputs` error is now returned directly as `CapError.tx`. -/
theorem applyTx_ledger_first (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l : List (OutPoint × Coin)) (e : Bitcoin.TxValidation.TxError)
    (hcb : tx.isCoinBase = false) (hchk : checkTransaction tx = none)
    (hm : Bitcoin.TxValidation.checkTxInputs tx (viewOf l) height = .error e) :
    applyTx height tx txIdx l flags = .error (CapError.tx e) := by
  simp [Bitcoin.Capstone.Block.applyTx_unfold, hchk, hcb, hm, ethrow]

/-- **P16-3 (ledger-first, coinbase)**: same for the coinbase lane — the
script layer is skipped, but the ledger gate still runs and its error
surfaces as `CapError.block`. -/
theorem applyTx_ledger_first_coinbase (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l : List (OutPoint × Coin)) (e : BlockError)
    (hcb : tx.isCoinBase = true) (hchk : checkTransaction tx = none)
    (hl : applyTxStepL l tx (txidKey tx) height = .error e) :
    applyTx height tx txIdx l flags = .error (CapError.block e) := by
  simp [Bitcoin.Capstone.Block.applyTx_unfold, hchk, hcb, ethrow, hl]

/-- **P16-3 (script-first, non-coinbase)**: dually, an adjudicated script
failure of `verifyTxInputs` propagates VERBATIM (it is already a
`CapError.scriptFail txIdx inputIdx _` by the wiring) — the ledger
step is never reached, so a script failure can never be masked by a
ledger success. -/
theorem applyTx_script_first (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l : List (OutPoint × Coin)) (e : CapError)
    (hcb : tx.isCoinBase = false) (hchk : checkTransaction tx = none)
    (hm : ∃ fee, Bitcoin.TxValidation.checkTxInputs tx (viewOf l) height = .ok fee)
    (hs : verifyTxInputs height tx txIdx l flags = .error e) :
    applyTx height tx txIdx l flags = .error e := by
  have hnc : ¬ (tx.isCoinBase = true) := by rw [hcb]; decide
  obtain ⟨fee, hm⟩ := hm
  simp [Bitcoin.Capstone.Block.applyTx_unfold, hchk, hnc, hm, ethrow, hs]

/-! ## The per-input loop: bounded counters -/

/-- **P16-4 (loop invariant form)**: induction on the remaining input
budget `n` (`i + n = tx.vin.length`). The invariant `okN + unjN ≤ i` says
the counters only ever count inputs actually consumed; the conclusion
`a + b ≤ tx.vin.length` is the boundedness of the final counters. Inputs
whose coin is missing from the view (`coinLookup = none`) contribute
NOTHING — hence boundedness, not exactness (the corresponding modules own that
error). -/
theorem verifyTxInputs_loop_total (height : UInt32) (tx : Tx) (txIdx : Nat)
    (u : List (OutPoint × Coin)) (spentOutputs : Option (List TxOut)) :
    ∀ (n i okN unjN a b : Nat), i + n = tx.vin.length →
      okN + unjN ≤ i →
      verifyTxInputs.loop height tx txIdx u flags spentOutputs i okN unjN = .ok (a, b) →
      a + b ≤ tx.vin.length := by
  intro n
  induction n with
  | zero =>
      intro i okN unjN a b hi _hinv hloop
      have hie : i = tx.vin.length := by omega
      subst hie
      rw [verifyTxInputs.loop.eq_1] at hloop
      split at hloop
      · simp only [Except.ok.injEq, Prod.mk.injEq] at hloop
        obtain ⟨_, h1, h2⟩ := hloop
        omega
      · omega
  | succ m ih =>
      intro i okN unjN a b hi hinv hloop
      rw [verifyTxInputs.loop.eq_1] at hloop
      split at hloop
      · omega
      · -- else branch: i < tx.vin.length
        dsimp only at hloop
        split at hloop
        · -- coin missing from the view: no verdict recorded, loop stops
          simp only [Except.ok.injEq, Prod.mk.injEq] at hloop
          obtain ⟨_, h1, h2⟩ := hloop
          omega
        · split at hloop
          · -- InputVerdict.pass: recurse with (i+1, okN+1, unjN)
            exact ih (i + 1) (okN + 1) unjN a b (by omega) (by omega) hloop
          · -- InputVerdict.unjudgedTaproot: recurse with (i+1, okN, unjN+1)
            exact ih (i + 1) okN (unjN + 1) a b (by omega) (by omega) hloop
          · -- InputVerdict.fail: the loop errors, contradiction with .ok
            simp at hloop

/-- **P16-4**: whenever `verifyTxInputs` succeeds with counters
`(okN, unjN)`, the counters are bounded by the tx's input count:
`okN + unjN ≤ tx.vin.length`. Every counted verdict corresponds to a real
input — the counters cannot overcount. -/
theorem verifyTxInputs_total (height : UInt32) (tx : Tx) (txIdx : Nat)
    (u : List (OutPoint × Coin)) (a b : Nat)
    (h : verifyTxInputs height tx txIdx u flags = .ok (a, b)) :
    a + b ≤ tx.vin.length := by
  have h0 : verifyTxInputs height tx txIdx u flags
      = verifyTxInputs.loop height tx txIdx u flags (collectSpentOutputs u tx.vin) 0 0 0 := rfl
  rw [h0] at h
  exact verifyTxInputs_loop_total height tx txIdx u (collectSpentOutputs u tx.vin) tx.vin.length 0 0 0 a b
    (by omega) (by omega) h

/-! ## Counter bounds through one tx and the whole fold -/

/-- **P16-4 (corollary)**: the script counters of ONE `applyTx` success
never exceed that tx's input count (coinbase: counters are `(0, 0)`;
otherwise P16-4's `verifyTxInputs_total` bounds them). -/
theorem applyTx_counters_bound (height : UInt32) (tx : Tx) (txIdx : Nat)
    (l l' : List (OutPoint × Coin)) (a b : Nat)
    (h : applyTx height tx txIdx l flags = .ok (l', a, b)) :
    a + b ≤ tx.vin.length := by
  rcases (BitcoinProofs.Theorems.CapstoneFold.applyTx_ok_inv h).2.1 with
    ⟨_, ha, hb⟩ | ⟨_, _, hv⟩
  · omega
  · exact verifyTxInputs_total height tx txIdx l a b hv

/-- **P16-1 (bounded form)**: the counters `applyTxs` returns never exceed
the incoming counters plus the total input supply of the tx list — the
script layer can manufacture at most one verdict per input. -/
theorem applyTxs_counters_bound (height : UInt32) :
    ∀ (txs : List Tx) (i : Nat) (l : List (OutPoint × Coin)) (okN unjN : Nat)
        (l' : List (OutPoint × Coin)) (okN' unjN' : Nat),
      applyTxs height txs i l okN unjN flags = .ok (l', okN', unjN') →
      okN' + unjN' ≤ okN + unjN + totalVins txs := by
  intro txs
  induction txs with
  | nil =>
      intro i l okN unjN l' okN' unjN' h
      simp only [applyTxs, Except.ok.injEq, Prod.mk.injEq] at h
      obtain ⟨_, h1, h2⟩ := h
      rw [totalVins_nil]
      omega
  | cons tx rest ih =>
      intro i l okN unjN l' okN' unjN'
      simp only [applyTxs]
      cases hax : applyTx height tx i l flags with
      | error e => intro h; simp at h
      | ok p =>
        obtain ⟨l'', a, b⟩ := p
        intro h
        simp only [ebind_ok] at h
        have hab : a + b ≤ tx.vin.length :=
          applyTx_counters_bound height tx i l l'' a b hax
        have hih := ih (i + 1) l'' (okN + a) (unjN + b) l' okN' unjN' h
        rw [totalVins_cons]
        omega

/-- **P16-1**: `applyTxs` threads the script counters MONOTONICALLY — on
success the returned counters dominate the incoming ones (they only ever
accumulate `+ a` and `+ b` per tx). -/
theorem applyTxs_counters_sum (height : UInt32) :
    ∀ (txs : List Tx) (i : Nat) (l : List (OutPoint × Coin)) (okN unjN : Nat)
        (l' : List (OutPoint × Coin)) (okN' unjN' : Nat),
      applyTxs height txs i l okN unjN flags = .ok (l', okN', unjN') →
      okN ≤ okN' ∧ unjN ≤ unjN' := by
  intro txs
  induction txs with
  | nil =>
      intro i l okN unjN l' okN' unjN' h
      simp only [applyTxs, Except.ok.injEq, Prod.mk.injEq] at h
      obtain ⟨_, h1, h2⟩ := h
      exact ⟨by omega, by omega⟩
  | cons tx rest ih =>
      intro i l okN unjN l' okN' unjN'
      simp only [applyTxs]
      cases hax : applyTx height tx i l flags with
      | error e => intro h; simp at h
      | ok p =>
        obtain ⟨l'', a, b⟩ := p
        intro h
        simp only [ebind_ok] at h
        obtain ⟨h1, h2⟩ := ih (i + 1) l'' (okN + a) (unjN + b) l' okN' unjN' h
        exact ⟨by omega, by omega⟩

/-! ## The pipeline: the honest poststate contract -/

/-- **P16-5 — THE POSTSTATE CONTRACT**. If `validateBlock raw st` succeeds
with report `r`, then there are a decoded header `bh`, tx list `txs` and
fold result `(u', k, j)` such that:

* `decodeBlock raw = .ok (bh, txs)` (the block really decoded),
* every nameable gate passed (`vtxNonempty`, `cbPositionOk`, `weightOk`,
  `versionOk`, `targetOk`, `powOk`, chain link `bytesBEq`, `merkleOk`),
* the funded stage ran: `applyBlockTransactions st.height txs st.utxo (candidateScriptFlags st.height bh) = .ok (u', k, j)`,
* and the report is EXACTLY the dataflow:
  `r.state = { st with height := st.height + 1, prevHash := headerHash bh, utxo := u' }`,
  `r.txs = txs.length`, `r.scriptOk = k`, `r.scriptUnjudged = j`.

The `cbLengthOk` / `bip34Ok` / witness-commitment gates are also enforced
by the pipeline but mention the module-private `dummyTx` stand-in, so they
are not nameable here. This is the theorem that turns the anchor run's
runtime `PASS` into: the reported poststate height is the connection
height `+ 1`, the reported parent hash is the hash of the DECODED header
(and hence of the real bytes), and the reported UTXO set is the fold's
output. -/
theorem validateBlock_ok_funded_shape (raw : ByteArray) (st : CapState) (r : CapReport)
    (hval : validateBlock raw st = .ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx)
        (u' : List (OutPoint × Coin)) (k j : Nat),
      decodeBlock raw = .ok (bh, txs) ∧
      vtxNonempty txs = true ∧
      cbPositionOk txs = true ∧
      weightOk txs raw.size = true ∧
      versionOk st.height bh.version = true ∧
      targetOk bh.bits = true ∧
      powOk bh = true ∧
      bytesBEq bh.hashPrevBlock st.prevHash = true ∧
      merkleOk bh txs = true ∧
      applyBlockTransactions st.height txs st.utxo (candidateScriptFlags st.height bh) = .ok (u', k, j) ∧
      r.state = { st with height := st.height + 1, prevHash := headerHash bh, utxo := u' } ∧
      r.txs = txs.length ∧
      r.scriptOk = k ∧
      r.scriptUnjudged = j := by
  revert hval
  rw [validateBlock.eq_1]
  generalize hdec : decodeBlock raw = d
  cases d with
  | error e =>
      intro hval
      simp only [ethrow, ebind_err] at hval
      simp at hval
  | ok p =>
      obtain ⟨bh, txs⟩ := p
      intro hval
      simp only [epure_ok, ebind_ok] at hval
      -- gate: vtxNonempty (BLK-022)
      obtain ⟨hg1, hval⟩ := gate_step _ _ hval
      -- gate: cbPositionOk (BLK-027/028)
      obtain ⟨hg2, hval⟩ := gate_step _ _ hval
      -- gate: cbLengthOk (BLK-029; private dummy stand-in)
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      -- gate: targetOk (BLK-038)
      obtain ⟨hg5, hval⟩ := gate_step _ _ hval
      -- gate: powOk (BLK-039)
      obtain ⟨hg6, hval⟩ := gate_step _ _ hval
      -- gate: chain link
      obtain ⟨hg7, hval⟩ := gate_step _ _ hval
      -- gate: versionOk (BLK-060/061/062)
      obtain ⟨hg4, hval⟩ := gate_step _ _ hval
      -- gate: bip34Ok (BLK-069; private dummy stand-in)
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      -- gate: merkleOk (BLK-010)
      obtain ⟨hg8, hval⟩ := gate_step _ _ hval
      -- gate: merkleMutationOk (BLK-011)
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := unit_precheck_ok _ _ hval
      -- ordered witness shape/hash/no-commitment stage
      obtain ⟨_, hval⟩ := unit_precheck_ok _ _ hval
      -- gate: weightOk (BLK-024/026), AFTER the commitment gates (BLK-021)
      obtain ⟨hg3, hval⟩ := gate_step _ _ hval
      -- gate: actual-hash BIP30 pre-block overlap check
      obtain ⟨_, hval⟩ := unit_precheck_ok _ _ hval
      -- The funded transaction stage; the projection theorem below exposes applyTxs.
      generalize hbudget : applyBlockTransactionsWithSigops none st.height
        (candidateScriptFlags st.height bh) txs st.utxo = q at hval
      cases q with
      | error e =>
          rw [ebind_err] at hval
          simp at hval
      | ok q' =>
          obtain ⟨⟨u', k, j⟩, sigops⟩ := q'
          have hfund : applyBlockTransactions st.height txs st.utxo (candidateScriptFlags st.height bh) = .ok (u', k, j) :=
            applyBlockTransactionsWithSigops_projection hbudget
          rw [ebind_ok] at hval
          simp only [Option.isSome_none, Bool.false_and, Bool.false_eq_true,
            if_false] at hval
          simp only [Except.ok.injEq] at hval
          subst hval
          exact ⟨bh, txs, u', k, j, rfl,
            bool_not_false hg1, bool_not_false hg2, bool_not_false hg3,
            bool_not_false hg4, bool_not_false hg5, bool_not_false hg6,
            bool_not_false hg7, bool_not_false hg8,
            hfund, rfl, rfl, rfl, rfl⟩

/-- The funded public pipeline refines the earlier standalone-fold shape. -/
theorem validateBlock_ok_shape (raw : ByteArray) (st : CapState) (r : CapReport)
    (hval : validateBlock raw st = .ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx)
        (u' : List (OutPoint × Coin)) (k j : Nat),
      decodeBlock raw = .ok (bh, txs) ∧
      vtxNonempty txs = true ∧
      cbPositionOk txs = true ∧
      weightOk txs raw.size = true ∧
      versionOk st.height bh.version = true ∧
      targetOk bh.bits = true ∧
      powOk bh = true ∧
      bytesBEq bh.hashPrevBlock st.prevHash = true ∧
      merkleOk bh txs = true ∧
      applyTxs st.height txs 0 st.utxo 0 0 (candidateScriptFlags st.height bh) = .ok (u', k, j) ∧
      r.state = { st with height := st.height + 1, prevHash := headerHash bh, utxo := u' } ∧
      r.txs = txs.length ∧
      r.scriptOk = k ∧
      r.scriptUnjudged = j := by
  obtain ⟨bh, txs, u', k, j, hdec, h1, h2, h3, h4, h5, h6, h7, h8,
    hfund, hst, htxs, hok, hunj⟩ := validateBlock_ok_funded_shape raw st r hval
  exact ⟨bh, txs, u', k, j, hdec, h1, h2, h3, h4, h5, h6, h7, h8,
    applyBlockTransactions_ok hfund, hst, htxs, hok, hunj⟩

/-- **P16-5 (BLK-011 mutation corollary)**: `validateBlock` success
implies the decoded leaf vector passed `merkleMutationOk`, i.e. the
existing `Bitcoin.Block.Connect.merkleMutationFree` detector found no
CVE-2012-2459 mutation. The gate is extracted from the REAL pipeline
(the fourth `gate_step` after the merkle root); it is kept out of
`validateBlock_ok_shape`'s existential to keep its field arity stable. -/
theorem validateBlock_ok_mutationFree (raw : ByteArray) (st : CapState) (r : CapReport)
    (hval : validateBlock raw st = .ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx),
      decodeBlock raw = .ok (bh, txs) ∧ merkleMutationOk txs = true := by
  revert hval
  rw [validateBlock.eq_1]
  generalize hdec : decodeBlock raw = d
  cases d with
  | error e =>
      intro hval
      simp only [ethrow, ebind_err] at hval
      simp at hval
  | ok p =>
      obtain ⟨bh, txs⟩ := p
      intro hval
      simp only [epure_ok, ebind_ok] at hval
      -- vtxNonempty, cbPositionOk, cbLengthOk
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      -- versionOk, bip34Ok
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      -- targetOk, powOk, chain link, merkleOk
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      -- merkleMutationOk (BLK-011)
      obtain ⟨hmut, _hval⟩ := gate_step _ _ hval
      exact ⟨bh, txs, rfl, bool_not_false hmut⟩

/-- **P16-5 (BIP30 corollary)**: `validateBlock` success implies the
pre-block overlap gate is quiet — either BIP30 enforcement is off at
this height, or no tx of the block recreates an outpoint live in the
pristine pre-block view. This is the pipeline-level statement of Core's
2466-2475 loop (TXV-063) after the gate was wired into `validateBlock`. -/
theorem validateBlock_ok_bip30_quiet (raw : ByteArray) (st : CapState) (r : CapReport)
    (hval : validateBlock raw st = .ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx),
      decodeBlock raw = .ok (bh, txs) ∧
      (bip30BlockCollision (viewOf st.utxo) txidKey txs st.height
        && bip30Enforced st.height) = false := by
  revert hval
  rw [validateBlock.eq_1]
  generalize hdec : decodeBlock raw = d
  cases d with
  | error e =>
      intro hval
      simp only [ethrow, ebind_err] at hval
      simp at hval
  | ok p =>
      obtain ⟨bh, txs⟩ := p
      intro hval
      simp only [epure_ok, ebind_ok] at hval
      -- vtxNonempty, cbPositionOk, cbLengthOk
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      -- versionOk, bip34Ok
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      -- targetOk, powOk, chain link, merkleOk
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      -- merkleMutationOk
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      obtain ⟨_, hval⟩ := unit_precheck_ok _ _ hval
      -- ordered witness shape/hash/no-commitment stage
      obtain ⟨_, hval⟩ := unit_precheck_ok _ _ hval
      -- weightOk
      obtain ⟨_, hval⟩ := gate_step _ _ hval
      -- The exact gate implies the valid older canonical-height projection.
      obtain ⟨hbip30, _⟩ := unit_precheck_ok _ _ hval
      exact ⟨bh, txs, rfl, checkBip30Pristine_ok_height_quiet hbip30⟩

/-- **P16-5 (height corollary)**: on success the reported poststate height
is EXACTLY the connection height plus one — the pipeline never skips,
double-counts or re-uses a height. -/
theorem validateBlock_ok_height (raw : ByteArray) (st : CapState) (r : CapReport)
    (hval : validateBlock raw st = .ok r) :
    r.state.height = st.height + 1 := by
  obtain ⟨_, _, _, _, _, _, _, _, _, _, _, _, _, _, _, hst, _, _, _⟩ :=
    validateBlock_ok_shape raw st r hval
  rw [hst]

/-- **P16-5 (parent-link corollary)**: on success the reported poststate
`prevHash` is `headerHash` of the DECODED header — the chain link the next
block must satisfy is the real hash of the real bytes, not a recomputed or
synthetic value. -/
theorem validateBlock_ok_prevHash (raw : ByteArray) (st : CapState) (r : CapReport)
    (hval : validateBlock raw st = .ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx),
      decodeBlock raw = .ok (bh, txs) ∧ r.state.prevHash = headerHash bh := by
  obtain ⟨bh, txs, _, _, _, hdec, _, _, _, _, _, _, _, _, _, hst, _, _, _⟩ :=
    validateBlock_ok_shape raw st r hval
  exact ⟨bh, txs, hdec, by rw [hst]⟩

/-- **P16-5 (tx-count corollary)**: on success the reported tx count is
EXACTLY the number of decoded transactions — `r.txs = txs.length`, the
BLK-022/027-checked list, not a recount. -/
theorem validateBlock_ok_txCount (raw : ByteArray) (st : CapState) (r : CapReport)
    (hval : validateBlock raw st = .ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx),
      decodeBlock raw = .ok (bh, txs) ∧ r.txs = txs.length := by
  obtain ⟨bh, txs, _, _, _, hdec, _, _, _, _, _, _, _, _, _, _, htxs, _, _⟩ :=
    validateBlock_ok_shape raw st r hval
  exact ⟨bh, txs, hdec, htxs⟩

/-- **P16-5 (counters corollary)**: on success the script counters are
bounded by the decoded block's total input supply — `r.scriptOk +
r.scriptUnjudged ≤ totalVins txs` (P16-1's bound threaded through the
whole pipeline, on top of P16-4's per-tx bound). -/
theorem validateBlock_counters_le (raw : ByteArray) (st : CapState) (r : CapReport)
    (hval : validateBlock raw st = .ok r) :
    ∃ (bh : Bitcoin.Chain.BlockHeader) (txs : List Tx),
      decodeBlock raw = .ok (bh, txs) ∧
      r.scriptOk + r.scriptUnjudged ≤ totalVins txs := by
  obtain ⟨bh, txs, u', k, j, hdec, _, _, _, _, _, _, _, _, hfold, _, _, hok, hunj⟩ :=
    validateBlock_ok_shape raw st r hval
  have hbound := applyTxs_counters_bound st.height txs 0 st.utxo 0 0 u' k j hfold
  exact ⟨bh, txs, hdec, by omega⟩

end BitcoinProofs.Theorems.CapstonePipeline
