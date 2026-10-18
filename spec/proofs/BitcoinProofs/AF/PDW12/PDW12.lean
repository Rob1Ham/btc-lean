import Bitcoin.Block.Pow
import Bitcoin.Block.Connect
import Bitcoin.Invariants.RC08

/-! # PDW12.lean

Five sorry-free promotion theorems, one per claimed rules.yaml row
(claim v1 = commit 04c27a7):

* **BLK-010** `merkleOk` (Capstone/Merkle.lean:98) →
  `merkleOk_of_eq` (accept-lane).
* **BLK-011** `levelHasAdjacentDup` (Block/Connect.lean:205) →
  `levelHasAdjacentDup_cons2_of_beq` (CVE-2012-2459 fold-accept).
* **BLK-042** `nextWorkRequired` (Block/Pow.lean:164) →
  `nextWorkRequired_nonboundary_const` + `nextWorkRequired_none`
  (pow.cpp copy-arm + no-prev-arm).
* **BLK-058** `timeNotTooNew` (Block/Pow.lean:247) →
  `timeNotTooNew_eq` (P12 2h-future bound iff-pin).
* **BLK-091** `feeAccumInRange` (Block/Connect.lean:170) →
  `feeAccumInRange_eq` (P12 MoneyRange bridge).

Route B (PDW11 21f0745 / PDW5 pattern): zero core writes, theorems
over the exact core gates, tags `@[rule "row"]` ride these decls.
The module is deliberately NOT imported by the `BitcoinProofs`
root (LedgerCor-13 RED crown-debt, S15/F-S15-004(b); the
`Shortcuts/S05`/PDW5-AF isolation pattern) — own-target built,
outside `core/**` (sorry_lint scans core only). -/

namespace BitcoinProofs.AF.PDW12

/-! ## Aux (NOT a row): the ByteArray `==` bridge.

`(a == b) = true → a = b` for the raw ByteArray `BEq` (used by
`levelHasAdjacentDup`'s `a == b` head). No `LawfulBEq ByteArray`
instance exists in-tree (probe p1); `simp only [BEq.beq]` peels
to the data-Array comparison, `eq_of_beq` (List `LawfulBEq`)
closes it, `congrArg ByteArray.mk` re-fits the one-field
structure (probe p10, lake env lean EXIT=0). -/

theorem bytes_eq_of_beq_eq_true (a b : ByteArray)
    (h : (a == b) = true) : a = b := by
  simp only [BEq.beq] at h
  exact congrArg ByteArray.mk (eq_of_beq h)

/-! ## BLK-010 — `merkleOk` accept-lane (CheckMerkleRoot:3848-3852).

`merkleOk h txs = bytesBEq h.hashMerkleRoot (merkleRootOfBlock txs)`
(Capstone/Merkle.lean:98); `bytesBEq`-refl = Params.lean:444
(`bytesBEq_self`, 2-liner, core-only; re-proved here verbatim —
out of my import closure to import Params directly: none). -/

@[rule "BLK-010"]
theorem merkleOk_of_eq (h : Bitcoin.Chain.BlockHeader) (txs : List Bitcoin.Data.Tx)
    (heq : h.hashMerkleRoot = Bitcoin.Capstone.Merkle.merkleRootOfBlock txs) :
    Bitcoin.Capstone.Merkle.merkleOk h txs = true := by
  unfold Bitcoin.Capstone.Merkle.merkleOk
  rw [heq]
  unfold Bitcoin.Data.bytesBEq
  simp

/-! ### REM-10: the full equality characterization (both directions)

`merkleOk` is the row's equality gate, not merely its accept half. The
`bytesBEq` bridge supplies the converse; the `= false` form is the
`bad-txnmrklroot` reject trigger consumed by
`Bitcoin.Capstone.Block.validateBlock_badMerkleRoot` (Block.lean:375). -/

theorem bytesBEq_eq_true_iff (a b : ByteArray) :
    Bitcoin.Data.bytesBEq a b = true ↔ a = b := by
  constructor
  · exact Bitcoin.Ledger.bytesBEq_eq_of_true a b
  · intro hab
    subst hab
    unfold Bitcoin.Data.bytesBEq
    simp

@[rule "BLK-010"]
theorem merkleOk_eq_true_iff (h : Bitcoin.Chain.BlockHeader)
    (txs : List Bitcoin.Data.Tx) :
    Bitcoin.Capstone.Merkle.merkleOk h txs = true ↔
      h.hashMerkleRoot = Bitcoin.Capstone.Merkle.merkleRootOfBlock txs := by
  unfold Bitcoin.Capstone.Merkle.merkleOk
  exact bytesBEq_eq_true_iff _ _

@[rule "BLK-010"]
theorem merkleOk_eq_false_iff (h : Bitcoin.Chain.BlockHeader)
    (txs : List Bitcoin.Data.Tx) :
    Bitcoin.Capstone.Merkle.merkleOk h txs = false ↔
      h.hashMerkleRoot ≠ Bitcoin.Capstone.Merkle.merkleRootOfBlock txs := by
  constructor
  · intro hf he
    have ht := (merkleOk_eq_true_iff h txs).mpr he
    rw [ht] at hf
    cases hf
  · intro hne
    cases hb : Bitcoin.Capstone.Merkle.merkleOk h txs with
    | false => rfl
    | true => exact absurd ((merkleOk_eq_true_iff h txs).mp hb) hne

/-- The reject verdict's Core string (`bad-txnmrklroot`). -/
@[rule "BLK-010"]
theorem badMerkleRoot_reason :
    Bitcoin.Capstone.Block.CapError.reason .badMerkleRoot = "bad-txnmrklroot" := rfl

/-! ## BLK-011 — `levelHasAdjacentDup` fold-accept
(ComputeMerkleRoot:55-63 + V:3853-3864, CVE-2012-2459).

The 2+-element level scan is `a == b || recurse` (Connect.lean:
205-208). Detect-lane (CVE-2012-2459 shape): two ADJACENT EQUAL
hashes at a 2+-element head ⇒ the scan fires (`(a == b) = true →
= true`, short-circuit `||`; hypothesis in the def's own exec
`==` form; honest weaker form than the too-strong
`= true → a = b` converse, which the right-recursion arm defeats:
`lHad [x;y;y] = true` with `x ≠ y`). No-false-positive base pins:
empty / single-hash levels never fire. -/

@[rule "BLK-011"]
theorem levelHasAdjacentDup_cons2_of_beq (a b : ByteArray)
    (rest : List ByteArray) (h : (a == b) = true) :
    Bitcoin.Block.Connect.levelHasAdjacentDup (a :: b :: rest) = true := by
  show ((a == b) || Bitcoin.Block.Connect.levelHasAdjacentDup (b :: rest)) = true
  rw [h]
  simp

@[rule "BLK-011"]
theorem levelHasAdjacentDup_nil : Bitcoin.Block.Connect.levelHasAdjacentDup
    ([] : List ByteArray) = false := rfl

@[rule "BLK-011"]
theorem levelHasAdjacentDup_singleton (a : ByteArray) :
    Bitcoin.Block.Connect.levelHasAdjacentDup [a] = false := rfl

/-! ### REM-10: the converse / exact characterization

The audit's missing direction: the detector fires **iff** some adjacent
pair of equal hashes occurs. `pre`/`post` span every level shape, so
this is not tied to a head-position or 2-element instance. -/

theorem beq_true_of_eq (a b : ByteArray) (h : a = b) : (a == b) = true := by
  subst h
  simp only [BEq.beq, ByteArray.beq]
  exact beq_self_eq_true a.data

@[rule "BLK-011"]
theorem levelHasAdjacentDup_eq_true_iff (l : List ByteArray) :
    Bitcoin.Block.Connect.levelHasAdjacentDup l = true ↔
      ∃ (pre : List ByteArray) (a b : ByteArray) (post : List ByteArray),
        l = pre ++ a :: b :: post ∧ a = b := by
  induction l using List.rec with
  | nil => simp [Bitcoin.Block.Connect.levelHasAdjacentDup]
  | cons x xs ih =>
    cases xs with
    | nil =>
      simp only [Bitcoin.Block.Connect.levelHasAdjacentDup]
      constructor
      · intro h; cases h
      · rintro ⟨pre, a, b, post, heq, _⟩
        cases pre <;> simp at heq
    | cons y rest =>
      rw [show Bitcoin.Block.Connect.levelHasAdjacentDup (x :: y :: rest) =
            ((x == y) || Bitcoin.Block.Connect.levelHasAdjacentDup (y :: rest)) from rfl]
      rw [Bool.or_eq_true]
      constructor
      · rintro (hxy | hrec)
        · exact ⟨[], x, y, rest, rfl, bytes_eq_of_beq_eq_true x y hxy⟩
        · obtain ⟨pre, a, b, post, heq, hab⟩ := ih.mp hrec
          exact ⟨x :: pre, a, b, post, by rw [heq]; rfl, hab⟩
      · rintro ⟨pre, a, b, post, heq, hab⟩
        cases pre with
        | nil =>
          simp only [List.nil_append, List.cons.injEq] at heq
          obtain ⟨hx, hy, -⟩ := heq
          subst hx
          subst hy
          exact Or.inl (beq_true_of_eq x y hab)
        | cons z pre' =>
          apply Or.inr
          apply ih.mpr
          refine ⟨pre', a, b, post, ?_, hab⟩
          injection heq with _ htail

@[rule "BLK-011"]
theorem levelHasAdjacentDup_eq_false_iff (l : List ByteArray) :
    Bitcoin.Block.Connect.levelHasAdjacentDup l = false ↔
      ¬ ∃ (pre : List ByteArray) (a b : ByteArray) (post : List ByteArray),
        l = pre ++ a :: b :: post ∧ a = b := by
  constructor
  · intro hf hex
    have ht := (levelHasAdjacentDup_eq_true_iff l).mpr hex
    rw [ht] at hf
    cases hf
  · intro hno
    cases hb : Bitcoin.Block.Connect.levelHasAdjacentDup l with
    | false => rfl
    | true => exact absurd ((levelHasAdjacentDup_eq_true_iff l).mp hb) hno

/-- The BLK-011 reject verdict: a 2+-element level with an adjacent
equal pair forces the `BLOCK_MUTATED` classification (`bad-txns-duplicate`,
merkle.cpp:55-63 + validation.cpp:3853-3864), not merely the raw flag. -/
@[rule "BLK-011"]
theorem merkleFailureKind_levelDup (leaves : List ByteArray) (f : Nat)
    (hdup : Bitcoin.Block.Connect.levelHasAdjacentDup leaves = true)
    (hlen : 2 ≤ leaves.length) :
    Bitcoin.Block.Connect.merkleFailureKind leaves (f + 1) =
      Bitcoin.Block.Connect.MerkleFailure.mutatedDuplicate := by
  unfold Bitcoin.Block.Connect.merkleFailureKind
  have hmf : Bitcoin.Block.Connect.merkleMutationFree leaves (f + 1) = false := by
    rw [show Bitcoin.Block.Connect.merkleMutationFree leaves (f + 1) =
          (if leaves.length ≤ 1 then true
           else !(Bitcoin.Block.Connect.levelHasAdjacentDup leaves) &&
             Bitcoin.Block.Connect.merkleMutationFree
               (Bitcoin.Capstone.Merkle.merkleLevel leaves) f) from rfl]
    rw [if_neg (by omega), hdup]
    rfl
  rw [hmf]
  rfl

/-! ### BLK-011 pipeline consumer (F-L2BLK-003 closed)

`Capstone/Block.lean` now gates the real pipeline on `merkleMutationOk`
immediately after `merkleOk`, at the `CheckMerkleRoot` call site.
`Block/Connect.lean` and `Capstone/Block.lean` form an import cycle
(`Block/Connect.lean` imports both), so `Capstone/Merkle.lean` carries the
identical fold as the upstream bridge `merkleMutationFreeCap`; the
theorems below prove that bridge is exactly
`Bitcoin.Block.Connect.merkleMutationFree` (the detector cited, not
edited). The final pipeline theorem consumes the row target
`levelHasAdjacentDup_cons2_of_beq`, so an adjacent-equal internal level
now rejects through the real `validateBlock` as
`BLOCK_MUTATED` / `bad-txns-duplicate` (`CapError.blockMutated`), not as
`bad-txnmrklroot` and not as a `BLOCK_CONSENSUS` cache write (BLK-012). -/

/-- BLK-011 bridge equality: `Capstone/Merkle.lean`'s level scan is
exactly `Bitcoin.Block.Connect.levelHasAdjacentDup`. -/
theorem levelHasAdjacentDupCap_eq (l : List ByteArray) :
    Bitcoin.Capstone.Merkle.levelHasAdjacentDupCap l =
      Bitcoin.Block.Connect.levelHasAdjacentDup l := by
  induction l using List.rec with
  | nil => rfl
  | cons a xs ih =>
    cases xs with
    | nil => rfl
    | cons b rest =>
      show ((a == b) || Bitcoin.Capstone.Merkle.levelHasAdjacentDupCap (b :: rest)) =
        ((a == b) || Bitcoin.Block.Connect.levelHasAdjacentDup (b :: rest))
      rw [ih]

/-- BLK-011 bridge equality: the upstream mutation fold is exactly
`Bitcoin.Block.Connect.merkleMutationFree`, at every fuel value. -/
theorem merkleMutationFreeCap_eq (l : List ByteArray) (f : Nat) :
    Bitcoin.Capstone.Merkle.merkleMutationFreeCap l f =
      Bitcoin.Block.Connect.merkleMutationFree l f := by
  induction f generalizing l with
  | zero =>
    cases l with
    | nil => rfl
    | cons a l' => rfl
  | succ f ih =>
    rw [show Bitcoin.Capstone.Merkle.merkleMutationFreeCap l (f + 1) =
          (if l.length ≤ 1 then true
           else !(Bitcoin.Capstone.Merkle.levelHasAdjacentDupCap l) &&
             Bitcoin.Capstone.Merkle.merkleMutationFreeCap
               (Bitcoin.Capstone.Merkle.merkleLevel l) f) from rfl]
    rw [show Bitcoin.Block.Connect.merkleMutationFree l (f + 1) =
          (if l.length ≤ 1 then true
           else !(Bitcoin.Block.Connect.levelHasAdjacentDup l) &&
             Bitcoin.Block.Connect.merkleMutationFree
               (Bitcoin.Capstone.Merkle.merkleLevel l) f) from rfl]
    by_cases hl : l.length ≤ 1
    · simp [hl]
    · simp only [hl, if_false]
      rw [levelHasAdjacentDupCap_eq l, ih (Bitcoin.Capstone.Merkle.merkleLevel l)]

/-- BLK-011: the real pipeline's gate is the existing detector on the
block's txid leaf vector, at fuel `length + 1`. -/
@[rule "BLK-011"]
theorem merkleMutationOk_eq (txs : List Bitcoin.Data.Tx) :
    Bitcoin.Capstone.Merkle.merkleMutationOk txs =
      Bitcoin.Block.Connect.merkleMutationFree
        (txs.map Bitcoin.Capstone.Merkle.txidOf) (txs.length + 1) := by
  unfold Bitcoin.Capstone.Merkle.merkleMutationOk
  exact merkleMutationFreeCap_eq _ _

/-- BLK-011 (reject iff): the pipeline gate rejects exactly when the
existing `merkleMutationFree` detector finds a mutation. -/
@[rule "BLK-011"]
theorem merkleMutationOk_eq_false_iff (txs : List Bitcoin.Data.Tx) :
    Bitcoin.Capstone.Merkle.merkleMutationOk txs = false ↔
      Bitcoin.Block.Connect.merkleMutationFree
        (txs.map Bitcoin.Capstone.Merkle.txidOf) (txs.length + 1) = false := by
  rw [merkleMutationOk_eq]

/-- BLK-011 (accept lane): a mutation-free tree passes the pipeline gate. -/
@[rule "BLK-011"]
theorem merkleMutationOk_of_mutationFree (txs : List Bitcoin.Data.Tx)
    (h : Bitcoin.Block.Connect.merkleMutationFree
      (txs.map Bitcoin.Capstone.Merkle.txidOf) (txs.length + 1) = true) :
    Bitcoin.Capstone.Merkle.merkleMutationOk txs = true := by
  rw [merkleMutationOk_eq]
  exact h

/-- BLK-011: the real pipeline rejects a mutated leaf vector with the
distinct `blockMutated` bucket (`bad-txns-duplicate`). -/
@[rule "BLK-011"]
theorem validateBlock_badMutated_of_mutationFree_false
    (raw : ByteArray) (st : Bitcoin.Capstone.Block.CapState)
    (h : Bitcoin.Chain.BlockHeader) (txs : List Bitcoin.Data.Tx)
    (hdec : Bitcoin.Serialization.decodeBlock raw = .ok (h, txs))
    (hstruct : Bitcoin.Capstone.Merkle.vtxNonempty txs = true)
    (hcbpos : Bitcoin.Capstone.Block.cbPositionOk txs = true)
    (hcblen : Bitcoin.Capstone.Block.cbLengthOk (txs.getD 0
      Bitcoin.Capstone.Block.dummyTx) = true)
    (hver : Bitcoin.Capstone.Block.versionOk st.height h.version = true)
    (hbip34 : Bitcoin.Capstone.Block.bip34Ok st.height (txs.getD 0
      Bitcoin.Capstone.Block.dummyTx) = true)
    (htarget : Bitcoin.Capstone.Pow.targetOk h.bits = true)
    (hpow : Bitcoin.Capstone.Pow.powOk h = true)
    (hlink : Bitcoin.Data.bytesBEq h.hashPrevBlock st.prevHash = true)
    (hmerkle : Bitcoin.Capstone.Merkle.merkleOk h txs = true)
    (hmut : Bitcoin.Block.Connect.merkleMutationFree
      (txs.map Bitcoin.Capstone.Merkle.txidOf) (txs.length + 1) = false) :
    Bitcoin.Capstone.Block.validateBlock raw st =
      .error Bitcoin.Capstone.Block.CapError.blockMutated := by
  exact Bitcoin.Capstone.Block.validateBlock_badMutated raw st h txs
    hdec hstruct hcbpos hcblen hver hbip34 htarget hpow hlink hmerkle
    ((merkleMutationOk_eq_false_iff txs).mpr hmut)

/-- BLK-011: a block whose merkle fold has a 2+-element level with an
adjacent-equal pair fails the real pipeline with `blockMutated`. -/
@[rule "BLK-011"]
theorem validateBlock_badMutated_of_levelDup
    (raw : ByteArray) (st : Bitcoin.Capstone.Block.CapState)
    (h : Bitcoin.Chain.BlockHeader) (txs : List Bitcoin.Data.Tx)
    (hdec : Bitcoin.Serialization.decodeBlock raw = .ok (h, txs))
    (hstruct : Bitcoin.Capstone.Merkle.vtxNonempty txs = true)
    (hcbpos : Bitcoin.Capstone.Block.cbPositionOk txs = true)
    (hcblen : Bitcoin.Capstone.Block.cbLengthOk (txs.getD 0
      Bitcoin.Capstone.Block.dummyTx) = true)
    (hver : Bitcoin.Capstone.Block.versionOk st.height h.version = true)
    (hbip34 : Bitcoin.Capstone.Block.bip34Ok st.height (txs.getD 0
      Bitcoin.Capstone.Block.dummyTx) = true)
    (htarget : Bitcoin.Capstone.Pow.targetOk h.bits = true)
    (hpow : Bitcoin.Capstone.Pow.powOk h = true)
    (hlink : Bitcoin.Data.bytesBEq h.hashPrevBlock st.prevHash = true)
    (hmerkle : Bitcoin.Capstone.Merkle.merkleOk h txs = true)
    (hdup : Bitcoin.Block.Connect.levelHasAdjacentDup
      (txs.map Bitcoin.Capstone.Merkle.txidOf) = true)
    (hlen : 2 ≤ (txs.map Bitcoin.Capstone.Merkle.txidOf).length) :
    Bitcoin.Capstone.Block.validateBlock raw st =
      .error Bitcoin.Capstone.Block.CapError.blockMutated := by
  have hk := merkleFailureKind_levelDup
    (txs.map Bitcoin.Capstone.Merkle.txidOf)
    (txs.map Bitcoin.Capstone.Merkle.txidOf).length hdup hlen
  have hmf : Bitcoin.Block.Connect.merkleMutationFree
      (txs.map Bitcoin.Capstone.Merkle.txidOf)
      ((txs.map Bitcoin.Capstone.Merkle.txidOf).length + 1) = false :=
    (Bitcoin.Block.Connect.merkleFailureKind_mutated_iff _ _).mp hk
  exact validateBlock_badMutated_of_mutationFree_false raw st h txs
    hdec hstruct hcbpos hcblen hver hbip34 htarget hpow hlink hmerkle
    (by simpa using hmf)

/-- BLK-011 row-target consumer: an adjacent-equal internal level
(`levelHasAdjacentDup_cons2_of_beq`) now rejects through the REAL
pipeline with the `blockMutated` bucket. -/
@[rule "BLK-011"]
theorem validateBlock_badMutated_of_adjacent_eq
    (raw : ByteArray) (st : Bitcoin.Capstone.Block.CapState)
    (h : Bitcoin.Chain.BlockHeader) (txs : List Bitcoin.Data.Tx)
    (a b : ByteArray) (rest : List ByteArray)
    (hdec : Bitcoin.Serialization.decodeBlock raw = .ok (h, txs))
    (hstruct : Bitcoin.Capstone.Merkle.vtxNonempty txs = true)
    (hcbpos : Bitcoin.Capstone.Block.cbPositionOk txs = true)
    (hcblen : Bitcoin.Capstone.Block.cbLengthOk (txs.getD 0
      Bitcoin.Capstone.Block.dummyTx) = true)
    (hver : Bitcoin.Capstone.Block.versionOk st.height h.version = true)
    (hbip34 : Bitcoin.Capstone.Block.bip34Ok st.height (txs.getD 0
      Bitcoin.Capstone.Block.dummyTx) = true)
    (htarget : Bitcoin.Capstone.Pow.targetOk h.bits = true)
    (hpow : Bitcoin.Capstone.Pow.powOk h = true)
    (hlink : Bitcoin.Data.bytesBEq h.hashPrevBlock st.prevHash = true)
    (hmerkle : Bitcoin.Capstone.Merkle.merkleOk h txs = true)
    (hleaves : txs.map Bitcoin.Capstone.Merkle.txidOf = a :: b :: rest)
    (hbeq : (a == b) = true) :
    Bitcoin.Capstone.Block.validateBlock raw st =
      .error Bitcoin.Capstone.Block.CapError.blockMutated := by
  have hdup := levelHasAdjacentDup_cons2_of_beq a b rest hbeq
  have hdup' : Bitcoin.Block.Connect.levelHasAdjacentDup
      (txs.map Bitcoin.Capstone.Merkle.txidOf) = true := by
    rw [hleaves]; exact hdup
  have hlen : 2 ≤ (txs.map Bitcoin.Capstone.Merkle.txidOf).length := by
    rw [hleaves]; simp
  exact validateBlock_badMutated_of_levelDup raw st h txs hdec hstruct hcbpos
    hcblen hver hbip34 htarget hpow hlink hmerkle hdup' hlen

/-! ## BLK-042 — `nextWorkRequired` (ContextualCheckBlockHeader:
4096-4098; pow.cpp). None-lane (no `get lastHeight`): reject;
non-boundary no-min-difficulty arm (pow.cpp:74-80): copy `last.bits`
— `fPowAllowMinDifficultyBlocks = false` covers Core mainnet
(testnet BLK-053/054 arms skipped). -/

@[rule "BLK-042"]
theorem nextWorkRequired_nonboundary_const
    (P : Bitcoin.Block.Pow.PowParams)
    (get : Nat → Option Bitcoin.Block.Pow.IndexNode)
    (lastHeight : Nat) (newTime : UInt32)
    (last : Bitcoin.Block.Pow.IndexNode)
    (hget : get lastHeight = some last)
    (hnb : (lastHeight + 1) % Bitcoin.Block.Pow.difficultyAdjustmentInterval P ≠ 0)
    (hmin : P.fPowAllowMinDifficultyBlocks = false) :
    Bitcoin.Block.Pow.nextWorkRequired P get lastHeight newTime = some last.bits := by
  simp only [Bitcoin.Block.Pow.nextWorkRequired, hget]
  split
  case isTrue hcond =>
    rw [hmin]
    split
    · next hmin' => exact absurd hmin' (by simp)
    · rfl
  case isFalse hb => exact absurd hnb (by simpa using hb)

@[rule "BLK-042"]
theorem nextWorkRequired_none
    (P : Bitcoin.Block.Pow.PowParams)
    (get : Nat → Option Bitcoin.Block.Pow.IndexNode)
    (lastHeight : Nat) (newTime : UInt32)
    (hnone : get lastHeight = none) :
    Bitcoin.Block.Pow.nextWorkRequired P get lastHeight newTime = none := by
  simp only [Bitcoin.Block.Pow.nextWorkRequired, hnone]

/-! ### REM-10: the general nBits gate, every branch

`blockBitsOk` (RC08:178, INV-094) is Core's
`block.nBits != GetNextWorkRequired(pindexPrev, &block, params)`
comparison. The audit's cited theorem only covered the non-boundary
copy arm; these faces quantify over **all** arms: the gate is exactly
the `some bits` equality, its failure is exactly the mismatch, the
retarget-boundary arm accepts `calculateNextWorkRequired`, and a missing
parent (the `none` arm) rejects. -/

@[rule "BLK-042"]
theorem blockBitsOk_eq_true_iff
    (P : Bitcoin.Block.Pow.PowParams)
    (get : Nat → Option Bitcoin.Block.Pow.IndexNode)
    (lastHeight : Nat) (newTime bits : UInt32) :
    Bitcoin.Invariants.RC08.blockBitsOk P get lastHeight newTime bits = true ↔
      Bitcoin.Block.Pow.nextWorkRequired P get lastHeight newTime = some bits := by
  unfold Bitcoin.Invariants.RC08.blockBitsOk
  simp

@[rule "BLK-042"]
theorem blockBitsOk_eq_false_iff
    (P : Bitcoin.Block.Pow.PowParams)
    (get : Nat → Option Bitcoin.Block.Pow.IndexNode)
    (lastHeight : Nat) (newTime bits : UInt32) :
    Bitcoin.Invariants.RC08.blockBitsOk P get lastHeight newTime bits = false ↔
      Bitcoin.Block.Pow.nextWorkRequired P get lastHeight newTime ≠ some bits := by
  constructor
  · intro hf he
    have ht := (blockBitsOk_eq_true_iff P get lastHeight newTime bits).mpr he
    rw [ht] at hf
    cases hf
  · intro hne
    cases hb : Bitcoin.Invariants.RC08.blockBitsOk P get lastHeight newTime bits with
    | false => rfl
    | true =>
      exact absurd ((blockBitsOk_eq_true_iff P get lastHeight newTime bits).mp hb) hne

/-- Boundary arm: the header must carry the retarget computation over
the period window (pow.cpp:33-35), not the previous block's bits. -/
@[rule "BLK-042"]
theorem blockBitsOk_boundary
    (P : Bitcoin.Block.Pow.PowParams)
    (get : Nat → Option Bitcoin.Block.Pow.IndexNode)
    (lastHeight : Nat) (newTime : UInt32)
    (last first : Bitcoin.Block.Pow.IndexNode)
    (hgetL : get lastHeight = some last)
    (hb : ((lastHeight + 1) % Bitcoin.Block.Pow.difficultyAdjustmentInterval P != 0) = false)
    (hgetF : get (lastHeight - (Bitcoin.Block.Pow.difficultyAdjustmentInterval P - 1)) = some first) :
    Bitcoin.Invariants.RC08.blockBitsOk P get lastHeight newTime
      (Bitcoin.Block.Pow.calculateNextWorkRequired P last.bits last.time first.time first.bits) = true := by
  rw [blockBitsOk_eq_true_iff]
  unfold Bitcoin.Block.Pow.nextWorkRequired
  simp [hgetL, hb, hgetF]

/-- Missing-parent arm: `GetNextWorkRequired` is undefined ⇒ reject. -/
@[rule "BLK-042"]
theorem blockBitsOk_none
    (P : Bitcoin.Block.Pow.PowParams)
    (get : Nat → Option Bitcoin.Block.Pow.IndexNode)
    (lastHeight : Nat) (newTime bits : UInt32)
    (hnone : Bitcoin.Block.Pow.nextWorkRequired P get lastHeight newTime = none) :
    Bitcoin.Invariants.RC08.blockBitsOk P get lastHeight newTime bits = false := by
  unfold Bitcoin.Invariants.RC08.blockBitsOk
  rw [hnone]
  rfl

/-! ## BLK-058 — `timeNotTooNew` (V:4115-4118): blockTime ≤ now +
7200 — P12 constant pin (iff). -/

@[rule "BLK-058"]
theorem timeNotTooNew_eq {bt now : UInt32} :
    Bitcoin.Block.Pow.timeNotTooNew bt now = true ↔ bt.toNat ≤ now.toNat + 7200 := by
  simp [Bitcoin.Block.Pow.timeNotTooNew]

/-! ## BLK-091 — `feeAccumInRange` (V:2543-2548):
`bad-txns-accumulated-fee-outofrange` — MoneyRange iff bridge
(Conservation/Interface.lean:51). -/

@[rule "BLK-091"]
theorem feeAccumInRange_eq {fees : Bitcoin.Data.Amount} :
    Bitcoin.Block.Connect.feeAccumInRange fees = true
      ↔ (0 ≤ fees ∧ fees ≤ Bitcoin.Data.MAX_MONEY) := by
  rw [Bitcoin.Block.Connect.feeAccumInRange]
  exact Bitcoin.Conservation.moneyRange_eq_true_iff fees

end BitcoinProofs.AF.PDW12
