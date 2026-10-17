import Bitcoin.Capstone.Merkle

/-! # PDW41b.lean — proof-promotion review RC28, items TOP-291..295
(PDW41b, 2026-10-17). Claim `d5a85e0` (dedup relaunch).

`Capstone/Merkle` witness-commitment status-debt band (BIP141): the
executable defs and their W17/P08 corollaries
(`proofs/.../Theorems/CapstoneCommitmentCor.lean`) already exist and are
sorry-free; the rules.yaml rows were never flipped. Route B: zero core
writes, row-face theorems on my own `@[rule]` tags.

* **BLK-014** `witnessLeaves`: coinbase leaf is `0x00×32`, the rest are
  the non-coinbase `wtxid`s (merkle.cpp:118-126).
* **BLK-015** `witnessCommitmentOutput`: last coinbase output with the
  `6a24aa21a9ed` prefix and size ≥ 38 (validation.cpp:3880-3900).
* **BLK-016** `commitmentValueZero`: every matching commitment output
  carries `nValue = 0`.
* **BLK-022** `vtxNonempty`: empty vtx is `bad-cb-missing`.
* **INV-089** `commitmentNonceOk`: the coinbase scriptWitness is exactly
  one 32-byte item (validation.cpp:3886-3893).
-/

namespace BitcoinProofs.AF.PDW41b

open Bitcoin.Capstone.Merkle Bitcoin.Data

/-! ## BLK-014 — witness tree leaves -/

/-- **BLK-014**: the empty block has no witness leaves. -/
@[rule "BLK-014"]
theorem witnessLeaves_nil : witnessLeaves [] = [] := rfl

/-- **BLK-014**: on a nonempty block the first leaf is the all-zero
coinbase hash and every remaining leaf is the corresponding `wtxid`
(merkle.cpp:118-126 `WitnessMerkleRoot`). -/
@[rule "BLK-014"]
theorem witnessLeaves_cons (cb : Tx) (rest : List Tx) :
    witnessLeaves (cb :: rest) = zeroBytes 32 :: rest.map wtxidOf := rfl

/-- **BLK-014**: coinbase-only leaf vector is the singleton zero hash. -/
@[rule "BLK-014"]
theorem witnessLeaves_single (cb : Tx) :
    witnessLeaves [cb] = [zeroBytes 32] := rfl

/-- **BLK-014**: the leaf vector is one leaf per transaction. -/
@[rule "BLK-014"]
theorem witnessLeaves_length (txs : List Tx) :
    (witnessLeaves txs).length = txs.length := by
  cases txs with
  | nil => rfl
  | cons cb rest => simp [witnessLeaves]

/-- **BLK-014**: every nonempty block's leaf vector starts with the
all-zero coinbase leaf (the coinbase is never hashed into the tree). -/
@[rule "BLK-014"]
theorem witnessLeaves_head_zero (cb : Tx) (rest : List Tx) :
    (witnessLeaves (cb :: rest)).head? = some (zeroBytes 32) := rfl

/-! ## BLK-015 — commitment-output selection -/

/-- **BLK-015**: a commitment output is detected exactly when the
coinbase has at least one output of size ≥ 38 whose script starts with
the `6a24aa21a9ed` prefix (the `getLast?` scan is nonempty). -/
@[rule "BLK-015"]
theorem witnessCommitmentOutput_isSome_iff (tx : Tx) :
    (witnessCommitmentOutput tx).isSome ↔
      (tx.vout.filter (fun o =>
        38 ≤ o.scriptPubKey.bytes.size &&
        bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm)).getLast? ≠ none := by
  unfold witnessCommitmentOutput
  cases hg : (tx.vout.filter (fun o =>
      38 ≤ o.scriptPubKey.bytes.size &&
      bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm)).getLast? with
  | none => simp
  | some o => simp

/-- **BLK-015**: when a commitment output is returned it is (a) a real
coinbase output, (b) at least 38 bytes, (c) prefix-`6a24aa21a9ed`, and
(d) its script is exactly the returned bytes. -/
@[rule "BLK-015"]
theorem witnessCommitmentOutput_some_spec {tx : Tx} {s : ByteArray}
    (h : witnessCommitmentOutput tx = some s) :
    ∃ o ∈ tx.vout,
      38 ≤ o.scriptPubKey.bytes.size ∧
      bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm = true ∧
      o.scriptPubKey.bytes = s := by
  unfold witnessCommitmentOutput at h
  cases hg : (tx.vout.filter (fun o =>
      38 ≤ o.scriptPubKey.bytes.size &&
      bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm)).getLast? with
  | none => simp [hg] at h
  | some o =>
    simp [hg] at h
    obtain ⟨ys, hys⟩ := List.getLast?_eq_some_iff.mp hg
    have hmem : o ∈ tx.vout.filter (fun o =>
        38 ≤ o.scriptPubKey.bytes.size &&
        bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm) := by
      rw [hys]; simp
    rw [List.mem_filter] at hmem
    obtain ⟨hvout, hpred⟩ := hmem
    simp only [Bool.and_eq_true] at hpred
    obtain ⟨hsize, hpfx⟩ := hpred
    refine ⟨o, hvout, ?_, hpfx, h⟩
    simpa using hsize

/-- The commitment-output shape tested by `witnessCommitmentOutput`
(validation.cpp:3880-3900): at least 38 script bytes and the
`6a24aa21a9ed` prefix. -/
private def commitmentShape (o : TxOut) : Bool :=
  38 ≤ o.scriptPubKey.bytes.size &&
    bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm

private theorem commitmentShape_eq (o : TxOut) :
    commitmentShape o = true ↔
      38 ≤ o.scriptPubKey.bytes.size ∧
      bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm = true := by
  simp [commitmentShape, Bool.and_eq_true]

/-- Auxiliary list law for BLK-015: if `l.filter P = ys ++ [a]`, then `a`
is the LAST `P`-matching element of `l` and everything after it fails
`P`. -/
private theorem filter_eq_append_singleton {α : Type} (P : α → Bool) :
    ∀ {l ys : List α} {a : α}, l.filter P = ys ++ [a] →
      ∃ pre post : List α, l = pre ++ a :: post ∧ P a = true ∧
        ∀ b ∈ post, P b = false := by
  intro l
  induction l with
  | nil => intro ys a h; simp at h
  | cons x xs ih =>
    intro ys a h
    by_cases hx : P x = true
    · rw [List.filter_cons_of_pos hx] at h
      cases ys with
      | nil =>
        simp only [List.nil_append, List.cons.injEq, List.nil_eq] at h
        obtain ⟨rfl, hf⟩ := h
        exact ⟨[], xs, rfl, hx, fun b hb => by
          have hb' := (List.filter_eq_nil_iff.mp hf) b hb
          simpa using hb'⟩
      | cons y ys' =>
        simp only [List.cons_append, List.cons.injEq] at h
        obtain ⟨rfl, h'⟩ := h
        obtain ⟨pre, post, hsplit, hpa, hpost⟩ := ih h'
        exact ⟨x :: pre, post, by rw [hsplit]; rfl, hpa, hpost⟩
    · rw [List.filter_cons_of_neg hx] at h
      obtain ⟨pre, post, hsplit, hpa, hpost⟩ := ih h
      exact ⟨x :: pre, post, by rw [hsplit]; rfl, hpa, hpost⟩

/-- **BLK-015** (full selection rule, validation.cpp:3880-3900): when
`witnessCommitmentOutput` returns a script, that script comes from the
**last** coinbase output of size ≥ 38 whose scriptPubKey begins with
`6a24aa21a9ed`; every output after it in `vout` is non-matching. This
closes the audit gap in `witnessCommitmentOutput_some_spec`, which only
exhibited *some* matching output. -/
@[rule "BLK-015"]
theorem witnessCommitmentOutput_some_last {tx : Tx} {s : ByteArray}
    (h : witnessCommitmentOutput tx = some s) :
    ∃ (pre : List TxOut) (o : TxOut) (post : List TxOut),
      tx.vout = pre ++ o :: post ∧
      38 ≤ o.scriptPubKey.bytes.size ∧
      bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm = true ∧
      o.scriptPubKey.bytes = s ∧
      ∀ o' ∈ post, commitmentShape o' = false := by
  unfold witnessCommitmentOutput at h
  change (match (tx.vout.filter commitmentShape).getLast? with
    | some o => some o.scriptPubKey.bytes
    | none => none) = some s at h
  cases hg : (tx.vout.filter commitmentShape).getLast? with
  | none => simp [hg] at h
  | some o =>
    simp [hg] at h
    obtain ⟨ys, hys⟩ := List.getLast?_eq_some_iff.mp hg
    obtain ⟨pre, post, hsplit, hpred, hpost⟩ :=
      filter_eq_append_singleton commitmentShape hys
    obtain ⟨hsize, hpfx⟩ := (commitmentShape_eq o).mp hpred
    exact ⟨pre, o, post, hsplit, hsize, hpfx, h, hpost⟩

/-! ## BLK-016 — commitment value zero -/

/-- **BLK-016**: the value check passes iff every output that matches the
commitment shape carries `nValue = 0` (BIP141: the commitment output is
provably unspendable and must not burn spendable value). -/
@[rule "BLK-016"]
theorem commitmentValueZero_eq_true_iff (tx : Tx) :
    commitmentValueZero tx = true ↔
      ∀ o ∈ tx.vout,
        (38 ≤ o.scriptPubKey.bytes.size &&
         bytesBEq (o.scriptPubKey.bytes.extract 0 6) wcm) = true →
        o.value = 0 := by
  unfold commitmentValueZero
  rw [List.all_eq_true]
  constructor
  · intro h o ho hpred
    have := h o (List.mem_filter.mpr ⟨ho, hpred⟩)
    simpa using this
  · intro h o ho
    obtain ⟨hvout, hpred⟩ := List.mem_filter.mp ho
    simpa using h o hvout hpred

/-! ## BLK-022 — empty-vtx gate -/

/-- **BLK-022**: `vtxNonempty` accepts exactly the nonempty transactions
lists (Core `CheckBlock` rejects `vtx.empty()` as `bad-cb-missing`,
validation.cpp:3955). -/
@[rule "BLK-022"]
theorem vtxNonempty_eq_true_iff (txs : List Tx) :
    vtxNonempty txs = true ↔ txs ≠ [] := by
  cases txs with
  | nil => simp [vtxNonempty]
  | cons t rest => simp [vtxNonempty]

/-! ## INV-089 — coinbase witness nonce shape -/

/-- **INV-089**: the nonce check is the singleton match on the coinbase
scriptWitness — exactly one item, and that item is 32 bytes. -/
@[rule "INV-089"]
theorem commitmentNonceOk_shape (cb : Tx) :
    commitmentNonceOk cb =
      match cb.witness.getD 0 [] with
      | [nonce] => nonce.size = 32
      | _ => false := rfl

/-- **INV-089**: nonce-ok implies the coinbase carries a scriptWitness. -/
@[rule "INV-089"]
theorem commitmentNonceOk_ne_nil (cb : Tx) (h : commitmentNonceOk cb = true) :
    cb.witness ≠ [] := by
  cases hl : cb.witness with
  | nil =>
    exfalso
    rw [commitmentNonceOk, hl] at h
    simp at h
  | cons w rest =>
    intro hne
    exact absurd hne (List.cons_ne_nil w rest)

/-- **INV-089**: nonce-ok yields the 32-byte nonce as the single item of
the coinbase's first witness stack (content unconstrained; only the size
is consensus-checked). -/
@[rule "INV-089"]
theorem commitmentNonceOk_head_32 (cb : Tx) (h : commitmentNonceOk cb = true) :
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
        rw [commitmentNonceOk, hl, hw, hws] at h
        simpa using h
      | cons n1 ws' =>
        exfalso
        rw [commitmentNonceOk, hl, hw, hws] at h
        simp at h

end BitcoinProofs.AF.PDW41b
