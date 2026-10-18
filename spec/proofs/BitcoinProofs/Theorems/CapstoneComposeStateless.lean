import BitcoinProofs.Theorems.CapstonePipelineCor
import BitcoinProofs.Theorems.CapstoneFoldAgree

/-!
# BitcoinProofs.Theorems.CapstoneComposeStateless — Phase-3 flagship:
the stateless block-validation composition theorem (sorry-free)

The capstone pipeline `Bitcoin.Capstone.Block.validateBlock` decides a block
by a fixed gate sequence.  This file isolates its **context-free** (no UTXO
view, no chain link) segment and states the composition theorem:

  the stateless model accepts `raw` at connection `height`
    **iff**
  the decoded block satisfies every applicable row predicate.

Row list (all `@[rule]`-backed in core, context-free):

| rows | predicate |
|------|-----------|
| BLK-022 | `vtxNonempty` |
| BLK-027/028 | `cbPositionOk` (coinbase is `txs[0]` and unique) |
| BLK-029 | `cbLengthOk` (scriptSig 2..100) |
| BLK-023/024/025/026 | `weightOk` (stripped/base weight ≤ 4e6) |
| BLK-060/061/062 | `versionOk` (buried version gates) |
| BLK-069 | `bip34Ok` (height commitment) |
| BLK-037/038/039 | `targetOk` ∧ `powOk` |
| BLK-010 (+008/009, CVE-2012-2459) | `merkleOk` |
| BLK-015..020 | commitment gate, zero value, 32-byte nonce |
| BLK-030 (INV-001..009) | `checkTransaction t = none` for every `t ∈ txs` |

`versionOk`/`bip34Ok` take the connection `height`: Core classes them as
contextual, but they are context-free w.r.t. the UTXO view and are part of
this model's assumed context.  The chain link (`hashPrevBlock = st.prevHash`),
script execution against spent coins, and the ledger fold are
deliberately **outside** this theorem.  Sigops are likewise not part of the
Capstone pipeline (no `GetBlockSigOpsCost` gate exists there), so they are
NOT claimed here.
-/

namespace BitcoinProofs.Theorems.CapstoneComposeStateless

open Bitcoin.Capstone.Block Bitcoin.Capstone.Merkle Bitcoin.Capstone.Pow
open Bitcoin.Data Bitcoin.Chain Bitcoin.Consensus Bitcoin.Serialization Bitcoin.Activation
open Bitcoin.Ledger BitcoinProofs.Theorems.CapstonePipeline

/-- The pipeline's coinbase stand-in (`getD 0` fallback). -/
def cbOf (txs : List Tx) : Tx := txs.getD 0 ⟨0, [], [], 0, []⟩

/-- Core's `expect_witness_commitment = DeploymentActiveAfter(prev, SEGWIT)`,
i.e. the block's own height reaches the buried activation height. -/
def segwitActive (height : UInt32) : Bool := SEGWIT_HEIGHT ≤ height

/-- **The row conjunction**, over a decoded header and tx list.  Each
conjunct is exactly one context-free gate the pipeline enforces. -/
def StatelessRows (bh : BlockHeader) (txs : List Tx) (raw : ByteArray)
    (height : UInt32) : Prop :=
  vtxNonempty txs = true ∧
  cbPositionOk txs = true ∧
  cbLengthOk (cbOf txs) = true ∧
  weightOk txs raw.size = true ∧
  versionOk height bh.version = true ∧
  bip34Ok height (cbOf txs) = true ∧
  targetOk bh.bits = true ∧
  powOk bh = true ∧
  merkleOk bh txs = true ∧
  commitmentGate (segwitActive height) txs (cbOf txs) = true ∧
  (!(segwitActive height) || (witnessCommitmentOutput (cbOf txs)).isNone ||
    commitmentValueZero (cbOf txs)) = true ∧
  (!(segwitActive height) || (witnessCommitmentOutput (cbOf txs)).isNone ||
    commitmentNonceOk (cbOf txs)) = true ∧
  (∀ t ∈ txs, checkTransaction t = none)

/-- **The stateless model's accept predicate**: decode, then every
context-free gate in the pipeline's order, then the per-tx stateless
checks.  Written as an early-exit decision procedure, not as the
conjunction above, so the theorem below is a real composition result. -/
def statelessValidate (raw : ByteArray) (height : UInt32) : Bool :=
  match decodeBlock raw with
  | .error _ => false
  | .ok (bh, txs) =>
      if !vtxNonempty txs then false
      else if !cbPositionOk txs then false
      else if !cbLengthOk (cbOf txs) then false
      else if !weightOk txs raw.size then false
      else if !versionOk height bh.version then false
      else if !bip34Ok height (cbOf txs) then false
      else if !targetOk bh.bits then false
      else if !powOk bh then false
      else if !merkleOk bh txs then false
      else if !commitmentGate (segwitActive height) txs (cbOf txs) then false
      else if segwitActive height && (witnessCommitmentOutput (cbOf txs)).isSome && !commitmentValueZero (cbOf txs) then false
      else if segwitActive height && (witnessCommitmentOutput (cbOf txs)).isSome && !commitmentNonceOk (cbOf txs) then false
      else txs.all (fun t => (checkTransaction t).isNone)

/-- The model accepts `raw` at `height` when the row conjunction holds. -/
def StatelessAccepts (raw : ByteArray) (height : UInt32) : Prop :=
  ∃ bh txs, decodeBlock raw = .ok (bh, txs) ∧ StatelessRows bh txs raw height

/-! ## Unfolding helpers for the real pipeline's desugared `do`-term -/

private theorem bind_throw {ε α β : Type} (e : ε) (F : α → Except ε β) :
    Bind.bind (throw e) F = Except.error e := rfl

private theorem bind_ok_inv {ε α β : Type} (m : Except ε α)
    (F : α → Except ε β) (r : β) (h : Bind.bind m F = Except.ok r) :
    ∃ x, m = Except.ok x ∧ F x = Except.ok r := by
  cases m with
  | error e => simp at h
  | ok x => exact ⟨x, rfl, h⟩

private theorem decodeMatch_inv (raw : ByteArray)
    (JP : BlockHeader × List Tx → Except CapError CapReport)
    (rep : CapReport)
    (hm : (match decodeBlock raw with
      | .error e => Bind.bind (throw (CapError.ser e)) JP
      | .ok p => Bind.bind (pure p) JP) = Except.ok rep) :
    ∃ h txs, decodeBlock raw = Except.ok (h, txs) ∧ JP (h, txs) = Except.ok rep := by
  revert hm
  cases decodeBlock raw with
  | error e =>
      intro hm
      exact absurd hm (by simp)
  | ok p =>
      intro hm
      obtain ⟨h, txs⟩ := p
      exact ⟨h, txs, rfl, hm⟩

/-- A failed `!g` guard: the run continued (inlined continuation `cont`)
and `g` is true. -/
private theorem guard_inv {ε α : Type} (g : Bool) (e : ε)
    (cont : Except ε α) (r : α)
    (h : (if (!g) = true then (Except.error e : Except ε α) else cont) =
      Except.ok r) :
    g = true ∧ cont = Except.ok r := by
  cases hg : g with
  | true => simp [hg] at h; exact ⟨rfl, h⟩
  | false => simp [hg] at h

/-- The nested witness-commitment guard (`anyWitness` lane). -/
private theorem guard2_inv {ε α : Type} (cg aw : Bool) (e₁ e₂ : ε)
    (cont : Except ε α) (r : α)
    (h : (if (!cg) = true then
            (if aw = true then (Except.error e₁ : Except ε α)
              else Except.error e₂)
          else cont) = Except.ok r) :
    cg = true ∧ cont = Except.ok r := by
  cases hg : cg with
  | true => simp [hg] at h; exact ⟨rfl, h⟩
  | false => cases aw <;> simp [hg] at h

/-- A failed positive guard: the run continued and `g` is false. -/
private theorem guard_pos_inv {ε α : Type} (g : Bool) (e : ε)
    (cont : Except ε α) (r : α)
    (h : (if g = true then (Except.error e : Except ε α) else cont) =
      Except.ok r) :
    g = false ∧ cont = Except.ok r := by
  cases hg : g with
  | true => simp [hg] at h
  | false => simp [hg] at h; exact ⟨rfl, h⟩

/-- Peel one early-exit guard: `if c then false else b` is `true` exactly
when the guard failed and the continuation is `true`. -/
private theorem ite_false_eq_true_iff (c b : Bool) :
    ((if c = true then false else b) = true) ↔ (c = false ∧ b = true) := by
  cases c <;> simp

/-- Material implication over an activation bit. -/
private theorem segwit_imp_iff {sa : Bool} {p : Prop} :
    (sa = true → p) ↔ (sa = false ∨ p) := by
  cases sa <;> simp

/-- Activation-conditional commitment guard: a failed
`sa && isSome && !b` is a passed `!sa || isNone || b`. -/
private theorem commitment_gate_pass {α : Type} {sa : Bool} {o : Option α}
    {b : Bool} (h : (sa && o.isSome && !b) = false) :
    (!sa || o.isNone || b) = true := by
  cases sa <;> cases o <;> cases b <;> simp_all

/-- **Composition, decoded form**: on a fixed successful decode, the
early-exit stateless model accepts iff the row conjunction holds. -/
theorem statelessValidate_ok_iff (bh : BlockHeader) (txs : List Tx)
    (raw : ByteArray) (height : UInt32)
    (hd : decodeBlock raw = .ok (bh, txs)) :
    statelessValidate raw height = true ↔ StatelessRows bh txs raw height := by
  simp only [statelessValidate, hd, StatelessRows, ite_false_eq_true_iff]
  simp [segwit_imp_iff, or_assoc]

/-- **THE STATELESS COMPOSITION THEOREM**: the model accepts a block iff
the decoded block satisfies every applicable context-free row predicate. -/
theorem capstone_stateless_composition (raw : ByteArray) (height : UInt32) :
    statelessValidate raw height = true ↔ StatelessAccepts raw height := by
  constructor
  · intro h
    cases hd : decodeBlock raw with
    | error e => simp [statelessValidate, hd] at h
    | ok p =>
        obtain ⟨bh, txs⟩ := p
        exact ⟨bh, txs, hd, (statelessValidate_ok_iff bh txs raw height hd).1 h⟩
  · rintro ⟨bh, txs, hd, hrows⟩
    exact (statelessValidate_ok_iff bh txs raw height hd).2 hrows

/-- `applyTxs` success ⇒ every decoded tx passed `CheckTransaction`
(BLK-030).  Re-derived here from `applyTx_ok_inv` (imported fold module). -/
private theorem applyTxs_checkTx_all (height : UInt32) :
    ∀ (txs : List Tx) (i okN unjN : Nat) (l l' : List (OutPoint × Coin))
      (okN' unjN' : Nat),
      applyTxs height txs i l okN unjN = .ok (l', okN', unjN') →
      ∀ t ∈ txs, checkTransaction t = none := by
  intro txs
  induction txs with
  | nil => intro _ _ _ _ _ _ _ _ t ht; cases ht
  | cons u rest ih =>
      intro i okN unjN l l' okN' unjN' h t ht
      simp only [applyTxs] at h
      cases hu : applyTx height u i l with
      | error e => rw [hu] at h; simp at h
      | ok q =>
          obtain ⟨l₁, a, b⟩ := q
          rw [hu] at h
          simp only [BitcoinProofs.Theorems.CapstonePipeline.ebind_ok] at h
          rcases List.mem_cons.mp ht with rfl | hmem
          · exact (BitcoinProofs.Theorems.CapstoneFold.applyTx_ok_inv hu).1
          · exact ih (i + 1) (okN + a) (unjN + b) l₁ l' okN' unjN' h t hmem

/-- **SOUNDNESS for the real pipeline**: a successful `validateBlock`
implies the stateless model accepts (all context-free rows hold).  This
is the direction the anchor runner exercises: every accepted block is a
model-accepted block. -/
theorem validateBlock_ok_statelessAccepts (raw : ByteArray) (st : CapState)
    (r : CapReport) (hval : validateBlock raw st = .ok r) :
    StatelessAccepts raw st.height := by
  unfold validateBlock at hval
  obtain ⟨bh, txs, hdec, hJP⟩ := decodeMatch_inv raw _ _ hval
  simp only [bind_throw] at hJP
  obtain ⟨hg1, hJP⟩ := guard_inv _ _ _ _ hJP      -- BLK-022
  obtain ⟨hg2, hJP⟩ := guard_inv _ _ _ _ hJP      -- BLK-027/028
  obtain ⟨hg3, hJP⟩ := guard_inv _ _ _ _ hJP      -- BLK-029
  obtain ⟨hg7, hJP⟩ := guard_inv _ _ _ _ hJP      -- BLK-038 target
  obtain ⟨hg8, hJP⟩ := guard_inv _ _ _ _ hJP      -- BLK-039 pow
  obtain ⟨_, hJP⟩ := guard_inv _ _ _ _ hJP        -- chain link (contextual)
  obtain ⟨hg5, hJP⟩ := guard_inv _ _ _ _ hJP      -- BLK-060..062
  obtain ⟨hg6, hJP⟩ := guard_inv _ _ _ _ hJP      -- BLK-069
  obtain ⟨hg9, hJP⟩ := guard_inv _ _ _ _ hJP      -- BLK-010 merkle
  obtain ⟨_, hJP⟩ := guard_inv _ _ _ _ hJP        -- BLK-011 mutation
  obtain ⟨hgc, hJP⟩ := guard2_inv _ _ _ _ _ _ hJP -- BLK-019/020
  obtain ⟨hgv, hJP⟩ := guard_pos_inv _ _ _ _ hJP    -- BLK-016 value
  obtain ⟨hgn, hJP⟩ := guard_pos_inv _ _ _ _ hJP    -- BLK-018 nonce
  obtain ⟨hg4, hJP⟩ := guard_inv _ _ _ _ hJP      -- BLK-023..026
  obtain ⟨_, hJP⟩ := guard_pos_inv _ _ _ _ hJP    -- BIP30 (contextual, outside model)
  obtain ⟨q, hap, _⟩ := bind_ok_inv (applyBlockTransactions st.height txs st.utxo) _ r hJP
  obtain ⟨u', k, j⟩ := q
  have hap := applyBlockTransactions_ok hap
  refine ⟨bh, txs, hdec, ?_⟩
  exact ⟨hg1, hg2, hg3, hg4, hg5, hg6, hg7, hg8, hg9, hgc,
    commitment_gate_pass hgv, commitment_gate_pass hgn,
    applyTxs_checkTx_all st.height txs 0 0 0 st.utxo u' k j hap⟩

/-- **Pipeline corollary**: if the full block-validation pipeline accepts
`raw` under ANY report, the stateless model accepts it at `st.height`.
The residual contextual gates (chain link, UTXO/script/ledger) are not
part of the model and are not claimed here. -/
theorem validateBlock_accepts_imp_model (raw : ByteArray) (st : CapState) :
    (∃ r, validateBlock raw st = .ok r) → StatelessAccepts raw st.height := by
  rintro ⟨r, hr⟩
  exact validateBlock_ok_statelessAccepts raw st r hr

end BitcoinProofs.Theorems.CapstoneComposeStateless

set_option pp.width 200 in
/-- info: 'BitcoinProofs.Theorems.CapstoneComposeStateless.capstone_stateless_composition' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.Theorems.CapstoneComposeStateless.capstone_stateless_composition
/-- info: 'BitcoinProofs.Theorems.CapstoneComposeStateless.validateBlock_ok_statelessAccepts' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.Theorems.CapstoneComposeStateless.validateBlock_ok_statelessAccepts
/-- info: 'BitcoinProofs.Theorems.CapstoneComposeStateless.validateBlock_accepts_imp_model' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.Theorems.CapstoneComposeStateless.validateBlock_accepts_imp_model
