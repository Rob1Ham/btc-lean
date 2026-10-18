import Bitcoin.SigHash.Interface

/-!
# Bitcoin.SigHash.Theorems — proof pins

All declarations in this module are sorry-free; every theorem carries an axiom pin
(`#guard_msgs in #print axioms`) at the bottom of the file.

## What is pinned

1. **Hashtype classification totality** (`htBase_cover`, Digest.lean,
   `@[rule "INV-055"]`): every `UInt32` hashtype classifies into exactly one
   of the three base classes — the `match` in every consumer is exhaustive.
2. **Determinism through the hashtype class** (`htClass_eq`, the
   `*_determined` family, `@[rule "INV-078"]`, `@[rule "INV-071"]`): both
   preimages depend on the hashtype ONLY through `htBase`/`htAcp` plus the
   raw 4-byte hashtype suffix. Digest-level cross-hashtype determinism is
   deliberately NOT claimed: the messages end in `serU32L ht` (raw bytes),
   so e.g. `0x01` and `0x21` (same ALL/¬ACP class) hash differently.
3. **hashXxx field dispatch** (`hashPrevoutsL_cases` `@[rule "SWT-043"]`,
   `hashSequenceL_cases` `@[rule "SWT-044"]`, `hashOutputsL_cases`
   `@[rule "SWT-045"]`, cover corollary `hashOutputsL_cover`): the
   zero-vs-hash condition matrix of BIP143 §3–5, as 4-case/2-case/2-case
   exhaustive dispatch.
4. **Tri-modal SIGHASH_SINGLE** (`legacyImpl_single_oor`,
   `bip143_single_oor` `@[rule "SCR-141", rule "SWT-046"]`; legacy
   interface-level pin `legacy_single_overflow`): out-of-range SINGLE is
   `uint256::ONE` for legacy but zero `hashOutputs` for BIP143. BIP341
   (fail-closed hashtype error) is out of scope — see the stub note below.
5. **scriptCode substitution well-definedness** (`findAndDeleteL_codeSep_eq`
   `@[rule "INV-057"]`, `scriptCodeOf_idempotent` `@[rule "SCR-101"]`): the
   byte-exact `FindAndDelete(OP_CODESEPARATOR)` walk, and its closure law.
6. **Witness-v0 scriptCode shape** (`p2wpkhScriptCodeL_spec`
   `@[rule "SWT-047"]`, `witnessScriptSizeOk_spec` `@[rule "SWT-011"]`).
-/

namespace Bitcoin.SigHash

open Bitcoin.Serialization (Bytes bL bytesOfList encCSL)
open Bitcoin.Data

/-! ## 1. Hashtype classification -/

/-- `htClass` is a faithful pair: equal classes have equal components. -/
theorem htClass_eq {ht ht' : UInt32} (h : htClass ht = htClass ht') :
    htBase ht = htBase ht' ∧ htAcp ht = htAcp ht' := by
  unfold htClass at h
  simp only [Prod.mk.injEq] at h
  exact h

/-! ## 2. Determinism through the hashtype class -/

/-- The legacy modified-serialization depends on the hashtype only through
`htBase`/`htAcp` (`interpreter.cpp:1337-1356` — no raw hashtype bytes). -/
theorem legacyPreimageL_determined (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht ht' : UInt32) (hcls : htClass ht = htClass ht') :
    legacyPreimageL tx nIn sc ht = legacyPreimageL tx nIn sc ht' := by
  obtain ⟨hb, ha⟩ := htClass_eq hcls
  unfold legacyPreimageL
  simp only [ha, hb]

/-- Full legacy message = determined preimage ‖ raw 4-byte hashtype
(`:1684-1686`) — the raw suffix is the ONLY class-independent hashtype
dependence. -/
theorem legacyMsgL_determined (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht ht' : UInt32) (hcls : htClass ht = htClass ht')
    (hraw : serU32L ht = serU32L ht') :
    legacyMsgL tx nIn sc ht = legacyMsgL tx nIn sc ht' := by
  unfold legacyMsgL
  simp only [legacyPreimageL_determined tx nIn sc ht ht' hcls, hraw]

/-- Legacy digest is a pure function of `(tx, nIn, scriptCode, htClass ht,
raw ht bytes)` — `@[rule "INV-078"]` (construction level; the ONE corner is
`legacyImpl_single_oor` / `legacy_single_overflow`). -/
@[rule "INV-078"]
theorem signatureHashLegacyImpl_determined (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht ht' : UInt32) (hcls : htClass ht = htClass ht')
    (hraw : serU32L ht = serU32L ht') :
    signatureHashLegacyImpl tx nIn sc ht = signatureHashLegacyImpl tx nIn sc ht' := by
  obtain ⟨hb, ha⟩ := htClass_eq hcls
  have hpre := legacyPreimageL_determined tx nIn sc ht ht' hcls
  unfold signatureHashLegacyImpl legacyMsgL
  simp only [ha, hb, hpre, hraw]

/-- `hashPrevouts` dispatch (`:1639-1641`): zero iff ANYONECANPAY, else
dSHA256 of all outpoints — `@[rule "SWT-043"]`. -/
private theorem hashPrevoutsL_determined' {tx : Tx} {ht ht' : UInt32}
    (ha : htAcp ht = htAcp ht') :
    hashPrevoutsL tx ht = hashPrevoutsL tx ht' := by
  unfold hashPrevoutsL
  rw [ha]

/-- `hashSequence` class-determinism (helper for `bip143MsgL_determined`). -/
private theorem hashSequenceL_determined' {tx : Tx} {ht ht' : UInt32}
    (hb : htBase ht = htBase ht') (ha : htAcp ht = htAcp ht') :
    hashSequenceL tx ht = hashSequenceL tx ht' := by
  unfold hashSequenceL
  rw [ha, hb]

/-- `hashOutputs` class-determinism (helper for `bip143MsgL_determined`). -/
private theorem hashOutputsL_determined' {tx : Tx} {nIn : Nat} {ht ht' : UInt32}
    (hb : htBase ht = htBase ht') :
    hashOutputsL tx nIn ht = hashOutputsL tx nIn ht' := by
  unfold hashOutputsL
  rw [hb]

/-- `hashPrevouts` dispatch (`:1639-1641`): zero iff ANYONECANPAY, else
dSHA256 of all outpoints — `@[rule "SWT-043"]`. -/
@[rule "SWT-043"]
theorem hashPrevoutsL_cases (tx : Tx) (ht : UInt32) :
    (htAcp ht = true ∧ hashPrevoutsL tx ht = zeroHashL) ∨
    (htAcp ht = false ∧ hashPrevoutsL tx ht =
      bL (dshaL (tx.vin.foldl (fun acc i => acc ++ serOutpointL i.prevout) []))) := by
  unfold hashPrevoutsL
  cases ha : htAcp ht with
  | true => exact Or.inl ⟨rfl, rfl⟩
  | false => exact Or.inr ⟨rfl, rfl⟩

/-- `hashSequence` dispatch (`:1643-1645`): zero iff ACP ∨ SINGLE ∨ NONE,
else dSHA256 of all nSequence — `@[rule "SWT-044"]`. -/
@[rule "SWT-044"]
theorem hashSequenceL_cases (tx : Tx) (ht : UInt32) :
    ((htAcp ht = true ∨ htBase ht = HtBase.singleHt ∨ htBase ht = HtBase.noneHt) ∧
      hashSequenceL tx ht = zeroHashL) ∨
    ((htAcp ht = false ∧ htBase ht ≠ HtBase.singleHt ∧ htBase ht ≠ HtBase.noneHt) ∧
      hashSequenceL tx ht =
        bL (dshaL (tx.vin.foldl (fun acc i => acc ++ serU32L i.sequence) []))) := by
  unfold hashSequenceL
  cases ha : htAcp ht with
  | true =>
      refine Or.inl ⟨Or.inl rfl, ?_⟩
      rfl
  | false =>
      obtain h1 | h1 | h1 := htBase_cover ht
      · exact Or.inl ⟨Or.inr (Or.inl h1), by rw [h1]; rfl⟩
      · exact Or.inl ⟨Or.inr (Or.inr h1), by rw [h1]; rfl⟩
      · refine Or.inr ⟨⟨rfl, by rw [h1]; decide, by rw [h1]; decide⟩, ?_⟩
        rw [h1]; rfl

/-- `hashOutputs` 4-case dispatch (`:1647-1653`): SINGLE in range ⇒ dSHA256
of `vout[nIn]`; SINGLE out of range or NONE ⇒ zero (NOT `uint256::ONE`);
ALL ⇒ dSHA256 of all outputs — `@[rule "SWT-045"]`. -/
@[rule "SWT-045"]
theorem hashOutputsL_cases (tx : Tx) (nIn : Nat) (ht : UInt32) :
    (htBase ht = HtBase.singleHt ∧ nIn < tx.vout.length ∧
      hashOutputsL tx nIn ht =
        bL (dshaL (serTxOutL (tx.vout.getD nIn ⟨0, Script.empty⟩)))) ∨
    (htBase ht = HtBase.singleHt ∧ tx.vout.length ≤ nIn ∧
      hashOutputsL tx nIn ht = zeroHashL) ∨
    (htBase ht = HtBase.noneHt ∧ hashOutputsL tx nIn ht = zeroHashL) ∨
    (htBase ht = HtBase.all ∧
      hashOutputsL tx nIn ht =
        bL (dshaL (tx.vout.foldl (fun acc o => acc ++ serTxOutL o) []))) := by
  unfold hashOutputsL
  obtain h | h | h := htBase_cover ht
  · rw [h]
    by_cases hn : nIn < tx.vout.length
    · rw [if_pos hn]; exact Or.inl ⟨rfl, hn, rfl⟩
    · rw [if_neg hn]; exact Or.inr (Or.inl ⟨rfl, by omega, rfl⟩)
  · rw [h]; exact Or.inr (Or.inr (Or.inl ⟨rfl, rfl⟩))
  · rw [h]; exact Or.inr (Or.inr (Or.inr ⟨rfl, rfl⟩))

/-- Coverage corollary: `hashOutputs` is always one of the three shapes
(zero, single-output hash, all-outputs hash). -/
theorem hashOutputsL_cover (tx : Tx) (nIn : Nat) (ht : UInt32) :
    hashOutputsL tx nIn ht = zeroHashL ∨
    (∃ o : TxOut, hashOutputsL tx nIn ht = bL (dshaL (serTxOutL o))) ∨
    (∃ os : Bytes, hashOutputsL tx nIn ht = bL (dshaL os)) := by
  obtain h1 | h1 | h1 | h1 := hashOutputsL_cases tx nIn ht
  · exact Or.inr (Or.inl ⟨tx.vout.getD nIn ⟨0, Script.empty⟩, h1.2.2⟩)
  · exact Or.inl h1.2.2
  · exact Or.inl h1.2
  · exact Or.inr (Or.inr ⟨tx.vout.foldl (fun acc o => acc ++ serTxOutL o) [], h1.2⟩)

/-- The 10-field BIP143 preimage is a pure function of
`(tx, nIn, scriptCode, htClass ht, raw ht bytes, amount)` — `@[rule "INV-071"]`. -/
@[rule "INV-071"]
theorem bip143MsgL_determined (tx : Tx) (nIn : Nat) (sc : Bytes) (ht ht' : UInt32)
    (amount : Amount) (hcls : htClass ht = htClass ht')
    (hraw : serU32L ht = serU32L ht') :
    bip143MsgL tx nIn sc ht amount = bip143MsgL tx nIn sc ht' amount := by
  obtain ⟨hb, ha⟩ := htClass_eq hcls
  unfold bip143MsgL
  simp only [hashPrevoutsL_determined' ha, hashSequenceL_determined' hb ha,
    hashOutputsL_determined' hb, hraw]

/-- INV-071 (three-hash preimage): the BIP143 v0 message is the 10-field
preimage of BIP143 §6, whose slots 2, 3 and 8 are the three sub-hashes
`hashPrevouts`, `hashSequence`, `hashOutputs`; each sub-hash is the
documented zero-vs-dSHA256 dispatch of BIP143 §3-5.  This strengthens
`bip143MsgL_determined` from class-determinism to the preimage structure
itself (interpreter.cpp:SignatureHash(WITNESS_V0) +
PrecomputedTransactionData, interpreter.h:164-199). -/
@[rule "INV-071"]
theorem bip143MsgL_three_hash_preimage (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht : UInt32) (amount : Amount) :
    (bip143MsgL tx nIn sc ht amount =
      serU32L tx.version.toUInt32
        ++ hashPrevoutsL tx ht
        ++ hashSequenceL tx ht
        ++ serOutpointL (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).prevout
        ++ encCSL sc.length ++ sc
        ++ serAmountL amount
        ++ serU32L (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).sequence
        ++ hashOutputsL tx nIn ht
        ++ serU32L tx.locktime
        ++ serU32L ht) ∧
    (htAcp ht = true ∧ hashPrevoutsL tx ht = zeroHashL ∨
      htAcp ht = false ∧ hashPrevoutsL tx ht =
        bL (dshaL (tx.vin.foldl (fun acc i => acc ++ serOutpointL i.prevout) []))) ∧
    ((htAcp ht = true ∨ htBase ht = HtBase.singleHt ∨ htBase ht = HtBase.noneHt) ∧
        hashSequenceL tx ht = zeroHashL ∨
      (htAcp ht = false ∧ htBase ht ≠ HtBase.singleHt ∧ htBase ht ≠ HtBase.noneHt) ∧
        hashSequenceL tx ht =
          bL (dshaL (tx.vin.foldl (fun acc i => acc ++ serU32L i.sequence) []))) ∧
    (htBase ht = HtBase.singleHt ∧ nIn < tx.vout.length ∧
        hashOutputsL tx nIn ht =
          bL (dshaL (serTxOutL (tx.vout.getD nIn ⟨0, Script.empty⟩))) ∨
      htBase ht = HtBase.singleHt ∧ tx.vout.length ≤ nIn ∧
        hashOutputsL tx nIn ht = zeroHashL ∨
      htBase ht = HtBase.noneHt ∧ hashOutputsL tx nIn ht = zeroHashL ∨
      htBase ht = HtBase.all ∧ hashOutputsL tx nIn ht =
        bL (dshaL (tx.vout.foldl (fun acc o => acc ++ serTxOutL o) []))) := by
  refine ⟨rfl, hashPrevoutsL_cases tx ht, hashSequenceL_cases tx ht,
    hashOutputsL_cases tx nIn ht⟩

/-- INV-071 (digest form): for an in-range input the BIP143 v0 digest is
SHA256d over that three-hash preimage. -/
@[rule "INV-071"]
theorem signatureHashBip143Impl_three_hash_preimage (tx : Tx) (nIn : Nat)
    (sc : Bytes) (ht : UInt32) (amount : Amount) (h : nIn < tx.vin.length) :
    signatureHashBip143Impl tx nIn sc ht amount =
      dshaL (serU32L tx.version.toUInt32
        ++ hashPrevoutsL tx ht
        ++ hashSequenceL tx ht
        ++ serOutpointL (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).prevout
        ++ encCSL sc.length ++ sc
        ++ serAmountL amount
        ++ serU32L (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).sequence
        ++ hashOutputsL tx nIn ht
        ++ serU32L tx.locktime
        ++ serU32L ht) := by
  rw [signatureHashBip143Impl, if_neg (by omega),
    (bip143MsgL_three_hash_preimage tx nIn sc ht amount).1]

/-- BIP143 digest is a pure function of `(tx, nIn, scriptCode, htClass ht,
raw ht bytes, amount)` (the vin-range guard does not involve `ht`).
SWT-066: midstate-caching equivalence — the digest depends on the
hashtype ONLY through its 6-slot class (`htClass`: 3 base classes × ACP),
so a cache keyed by class is outcome-invisible (interpreter.cpp:1582-1607;
the same `*_determined` family covers the legacy preimage and sub-hashes). -/
@[rule "SWT-066"]
theorem signatureHashBip143Impl_determined (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht ht' : UInt32) (amount : Amount) (hcls : htClass ht = htClass ht')
    (hraw : serU32L ht = serU32L ht') :
    signatureHashBip143Impl tx nIn sc ht amount =
      signatureHashBip143Impl tx nIn sc ht' amount := by
  have hmsg := bip143MsgL_determined tx nIn sc ht ht' amount hcls hraw
  unfold signatureHashBip143Impl
  simp only [hmsg]

/-! ## 6-slot midstate cache (SWT-066)

`SignatureHash(WITNESS_V0)` reads the three BIP143 sub-hashes from
`PrecomputedTransactionData` when the cache is ready
(interpreter.cpp:1582-1607).  The cache contents are a function of the
hashtype CLASS only — `HtBase` (3) × ACP (2) = 6 slots — while the raw
hashtype bytes still enter the message suffix.  The theorems below model
the cache explicitly and prove it outcome-invisible. -/

/-- The three cached midstate inputs of BIP143 (`PrecomputedTransactionData`,
interpreter.h:164-199). -/
structure Bip143SubHashes where
  prevouts : Bytes
  sequence : Bytes
  outputs : Bytes
deriving Repr, DecidableEq

/-- The canonical cache contents for one hashtype: exactly the three
sub-hashes Core would compute for it. -/
def bip143SubHashes (tx : Tx) (nIn : Nat) (ht : UInt32) : Bip143SubHashes :=
  ⟨hashPrevoutsL tx ht, hashSequenceL tx ht, hashOutputsL tx nIn ht⟩

/-- The BIP143 preimage with the three sub-hash slots read from a cache
instead of recomputed. -/
def bip143MsgCached (c : Bip143SubHashes) (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht : UInt32) (amount : Amount) : Bytes :=
  let i := tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩
  serU32L tx.version.toUInt32
    ++ c.prevouts
    ++ c.sequence
    ++ serOutpointL i.prevout
    ++ encCSL sc.length ++ sc
    ++ serAmountL amount
    ++ serU32L i.sequence
    ++ c.outputs
    ++ serU32L tx.locktime
    ++ serU32L ht

/-- SWT-066: a cache filled with the canonical sub-hashes reproduces the
uncached BIP143 preimage exactly. -/
@[rule "SWT-066"]
theorem bip143MsgCached_eq (tx : Tx) (nIn : Nat) (sc : Bytes) (ht : UInt32)
    (amount : Amount) :
    bip143MsgCached (bip143SubHashes tx nIn ht) tx nIn sc ht amount =
      bip143MsgL tx nIn sc ht amount := rfl

/-- SWT-066: the cached sub-hashes are determined by the hashtype CLASS —
so six slots (3 base × ACP) suffice for every hashtype. -/
@[rule "SWT-066"]
theorem bip143SubHashes_class_determined (tx : Tx) (nIn : Nat) (ht ht' : UInt32)
    (hcls : htClass ht = htClass ht') :
    bip143SubHashes tx nIn ht = bip143SubHashes tx nIn ht' := by
  obtain ⟨hb, ha⟩ := htClass_eq hcls
  unfold bip143SubHashes
  rw [hashPrevoutsL_determined' ha, hashSequenceL_determined' hb ha,
    hashOutputsL_determined' hb]

/-- SWT-066: the cache is outcome-invisible — hashing the cached preimage
for an in-range input gives exactly the uncached BIP143 digest. -/
@[rule "SWT-066"]
theorem signatureHashBip143Impl_cached_eq (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht : UInt32) (amount : Amount) (h : nIn < tx.vin.length) :
    dshaL (bip143MsgCached (bip143SubHashes tx nIn ht) tx nIn sc ht amount) =
      signatureHashBip143Impl tx nIn sc ht amount := by
  rw [bip143MsgCached_eq, signatureHashBip143Impl, if_neg (by omega)]

/-- SWT-066: a cache slot filled for one hashtype serves every hashtype in
the same six-slot class (same base + ACP and same raw suffix) without
changing the digest. -/
@[rule "SWT-066"]
theorem signatureHashBip143Impl_cached_class (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht ht' : UInt32) (amount : Amount) (hcls : htClass ht = htClass ht')
    (hraw : serU32L ht = serU32L ht') (h : nIn < tx.vin.length) :
    dshaL (bip143MsgCached (bip143SubHashes tx nIn ht) tx nIn sc ht' amount) =
      signatureHashBip143Impl tx nIn sc ht amount := by
  rw [bip143SubHashes_class_determined tx nIn ht ht' hcls,
    signatureHashBip143Impl_cached_eq tx nIn sc ht' amount h]
  exact (signatureHashBip143Impl_determined tx nIn sc ht ht' amount hcls hraw).symm

/-! ## 4. Tri-modal SIGHASH_SINGLE -/

/-- **Legacy out-of-range SINGLE** (`:1614-1622`): the early return fires
before any vin indexing — digest is `uint256::ONE` (Bytes-level mirror of
`legacy_single_overflow`). -/
theorem legacyImpl_single_oor (tx : Tx) (nIn : Nat) (sc : Bytes)
    (h : tx.vout.length ≤ nIn) :
    signatureHashLegacyImpl tx nIn sc 0x03 = singleOverflowOneB := by
  unfold signatureHashLegacyImpl
  rw [if_pos (show htBase 0x03 = HtBase.singleHt ∧ tx.vout.length ≤ nIn from ⟨rfl, h⟩)]

/-- **BIP143 out-of-range SINGLE** (`:1647-1653`): NO `uint256::ONE` early
return — `hashOutputs` is the zero vector (`@[rule "SCR-141"]`,
`@[rule "SWT-046"]`). -/
@[rule "SCR-141", rule "SWT-046"]
theorem bip143_single_oor (tx : Tx) (nIn : Nat) (ht : UInt32)
    (hs : htBase ht = HtBase.singleHt) (h : tx.vout.length ≤ nIn) :
    hashOutputsL tx nIn ht = zeroHashL := by
  unfold hashOutputsL
  rw [hs, if_neg (by omega : ¬ (nIn < tx.vout.length))]

/-! **BIP341 stub note.** The taproot sighash (BIP341 SigMsg / tagged
hashes) is out of scope: `Bitcoin.SigHash` deliberately exposes no BIP341
digest in this module. The tri-modal SIGHASH_SINGLE dispatch is pinned for its
two implemented modes above (`legacyImpl_single_oor` → `uint256::ONE`,
`bip143_single_oor` → zero `hashOutputs`); the third mode (BIP341:
fail-closed hashtype error, `interpreter.cpp:1962-1964`) will be pinned by
the remaining proofs against the tagged-hash seam floor. -/

/-! ## 6. Witness-v0 scriptCode shape -/

/-- P2WPKH scriptCode program: `0x76 0xa9 0x14 {pkh} 0x88 0xac`
(`interpreter.cpp:1952`, BIP143 item 5) — `@[rule "SWT-047"]`. -/
@[rule "SWT-047"]
theorem p2wpkhScriptCodeL_spec (pkh : Bytes) :
    p2wpkhScriptCodeL pkh = [0x76, 0xa9, 0x14] ++ pkh ++ [0x88, 0xac] := rfl

/-- The P2WPKH scriptCode is 25 bytes for a 20-byte program (3 + 20 + 2;
the CompactSize prefix `0x19` = 25 is added by the digest serialization). -/
theorem p2wpkhScriptCodeL_length (pkh : Bytes) :
    (p2wpkhScriptCodeL pkh).length = pkh.length + 5 := by
  simp [p2wpkhScriptCodeL]

/-- The only size rule on the witness script is the 10,000-byte
`MAX_SCRIPT_SIZE` applied at EXECUTION time (`:438-440`), not at hashing —
`@[rule "SWT-011"]`. -/
@[rule "SWT-011"]
theorem witnessScriptSizeOk_spec (s : Bytes) :
    witnessScriptSizeOk s = true ↔ s.length ≤ 10000 := by
  unfold witnessScriptSizeOk
  exact decide_eq_true_iff

/-! ## 5. scriptCode substitution well-definedness (pins) -/

/-! The scriptCode hashed by the legacy digest is the subscript with the
parsed 1-byte OP_CODESEPARATOR ops spliced out; `FindAndDelete` of the
`[0xab]` pattern coincides with the GetOp walk (`@[rule "INV-057"]`), and
the induced `scriptCodeOf` is idempotent — a closure (`@[rule "SCR-101"]`,
Ops.lean / Interface.lean). -/

/-! ## Axiom pins

Each pin freezes the axiom footprint of a key theorem: exactly the three
harmless standard axioms (`propext`, `Classical.choice`, `Quot.sound`) via
the derived `Decidable` instances — no `sorryAx`, no custom axioms. -/

section AxiomPins

/-- info: 'Bitcoin.SigHash.htBase_cover' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms htBase_cover

/-- info: 'Bitcoin.SigHash.htClass_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms htClass_eq

/-- info: 'Bitcoin.SigHash.legacyPreimageL_determined' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms legacyPreimageL_determined

/-- info: 'Bitcoin.SigHash.signatureHashLegacyImpl_determined' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms signatureHashLegacyImpl_determined

/-- info: 'Bitcoin.SigHash.hashPrevoutsL_cases' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms hashPrevoutsL_cases

/-- info: 'Bitcoin.SigHash.hashSequenceL_cases' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms hashSequenceL_cases

/-- info: 'Bitcoin.SigHash.hashOutputsL_cases' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms hashOutputsL_cases

/-- info: 'Bitcoin.SigHash.hashOutputsL_cover' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms hashOutputsL_cover

/-- info: 'Bitcoin.SigHash.bip143MsgL_determined' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip143MsgL_determined

/-- info: 'Bitcoin.SigHash.signatureHashBip143Impl_determined' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms signatureHashBip143Impl_determined

/-- info: 'Bitcoin.SigHash.bip143MsgL_three_hash_preimage' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip143MsgL_three_hash_preimage

/-- info: 'Bitcoin.SigHash.signatureHashBip143Impl_three_hash_preimage' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms signatureHashBip143Impl_three_hash_preimage

/-- info: 'Bitcoin.SigHash.bip143MsgCached_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip143MsgCached_eq

/-- info: 'Bitcoin.SigHash.bip143SubHashes_class_determined' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip143SubHashes_class_determined

/-- info: 'Bitcoin.SigHash.signatureHashBip143Impl_cached_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms signatureHashBip143Impl_cached_eq

/-- info: 'Bitcoin.SigHash.signatureHashBip143Impl_cached_class' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms signatureHashBip143Impl_cached_class

/-- info: 'Bitcoin.SigHash.legacyImpl_single_oor' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms legacyImpl_single_oor

/-- info: 'Bitcoin.SigHash.bip143_single_oor' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip143_single_oor

/-- info: 'Bitcoin.SigHash.p2wpkhScriptCodeL_spec' does not depend on any axioms -/
#guard_msgs in #print axioms p2wpkhScriptCodeL_spec

/-- info: 'Bitcoin.SigHash.p2wpkhScriptCodeL_length' depends on axioms: [propext] -/
#guard_msgs in #print axioms p2wpkhScriptCodeL_length

/-- info: 'Bitcoin.SigHash.witnessScriptSizeOk_spec' depends on axioms: [propext] -/
#guard_msgs in #print axioms witnessScriptSizeOk_spec

/-- info: 'Bitcoin.SigHash.scriptCodeOf_idempotent' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms scriptCodeOf_idempotent

/-- info: 'Bitcoin.SigHash.legacy_single_overflow' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms legacy_single_overflow

/-- info: 'Bitcoin.SigHash.findAndDeleteL_codeSep_idempotent' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms findAndDeleteL_codeSep_idempotent

end AxiomPins

end Bitcoin.SigHash
