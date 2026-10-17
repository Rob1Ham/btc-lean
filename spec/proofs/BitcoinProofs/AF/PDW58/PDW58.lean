import Bitcoin.Invariants.RC12
import Bitcoin.Capstone.Merkle
import Bitcoin.Ledger.Interface
import Bitcoin.SigHash.Digest
import Bitcoin.Invariants.RC07
import Bitcoin.Interpreter.Rules
import Bitcoin.Crypto.Ecdsa.Der

/-! # PDW58 — consensus commitment band (TOP-311..315)

Row-face theorems for {INV-134, SWT-030, INV-117, SCR-140, INV-073}.
Route B: tags on my theorems, zero core writes. -/

namespace BitcoinProofs.AF.PDW58

open Bitcoin.Data (bytesBEq)
open Bitcoin.Serialization (Bytes bL)
open Bitcoin.SigHash (bip143MsgL serAmountL serU32L serU64L serOutpointL
  hashPrevoutsL hashSequenceL hashOutputsL zeroHashL)

/-- INV-134: the BIP113 cutoff is the prev MTP exactly when CSV is active. -/
@[rule "INV-134"]
theorem bip113Cutoff_eq_prevMtp_iff (height blockTime prevMtp : UInt32) :
    Bitcoin.Invariants.RC12.bip113Cutoff height blockTime prevMtp = prevMtp ↔
      Bitcoin.Activation.CSV_HEIGHT ≤ height ∨ blockTime = prevMtp := by
  unfold Bitcoin.Invariants.RC12.bip113Cutoff
  by_cases h : Bitcoin.Activation.CSV_HEIGHT ≤ height
  · rw [ite_eq_left h]; simp [h]
  · rw [ite_eq_right h]; simp [h]

/-- SWT-030: the witness commitment is exactly the SHA256d(root ‖ 32 zero
bytes) versus scriptPubKey[6..38] of the selected commitment output. -/
@[rule "SWT-030"]
theorem witnessCommitmentOk_true_iff (txs : List Bitcoin.Data.Tx) (cb : Bitcoin.Data.Tx) :
    Bitcoin.Capstone.Merkle.witnessCommitmentOk txs cb = true ↔
      ∃ script, Bitcoin.Capstone.Merkle.witnessCommitmentOutput cb = some script ∧
        bytesBEq (Bitcoin.Crypto.Seam.sha256d
          (Bitcoin.Capstone.Merkle.witnessMerkleRoot txs ++ Bitcoin.Data.zeroBytes 32))
          (script.extract 6 38) = true := by
  unfold Bitcoin.Capstone.Merkle.witnessCommitmentOk
  cases h : Bitcoin.Capstone.Merkle.witnessCommitmentOutput cb with
  | none => simp
  | some script =>
      exact ⟨fun hb => ⟨script, rfl, hb⟩, fun ⟨s, hs, hb⟩ => by
        simp only [Option.some.injEq] at hs
        subst hs
        exact hb⟩

/-- INV-117: the undo payload wins over the post-state (restore lane). -/
@[rule "INV-117"]
theorem undoCoins_spent_restore (uAfter : Bitcoin.Ledger.UtxoSet) (spent : List (Bitcoin.Data.OutPoint × Bitcoin.Ledger.Coin))
    (tx : Bitcoin.Data.Tx) (key : Bitcoin.Ledger.Key) (height : UInt32) (o : Bitcoin.Data.OutPoint) (c : Bitcoin.Ledger.Coin)
    (h : Bitcoin.Ledger.coinLookup spent o = some c) :
    Bitcoin.Ledger.undoCoins uAfter spent tx key height o = some c := by
  unfold Bitcoin.Ledger.undoCoins
  rw [h]

/-- INV-117: keys `tx` added are blanked on disconnect (insert-reverse lane). -/
@[rule "INV-117"]
theorem undoCoins_added_blank (uAfter : Bitcoin.Ledger.UtxoSet) (spent : List (Bitcoin.Data.OutPoint × Bitcoin.Ledger.Coin))
    (tx : Bitcoin.Data.Tx) (key : Bitcoin.Ledger.Key) (height : UInt32) (o : Bitcoin.Data.OutPoint)
    (hsp : Bitcoin.Ledger.coinLookup spent o = none)
    (ha : (Bitcoin.Ledger.coinLookup (Bitcoin.Ledger.addedCoins tx key height) o).isSome = true) :
    Bitcoin.Ledger.undoCoins uAfter spent tx key height o = none := by
  unfold Bitcoin.Ledger.undoCoins
  rw [hsp]
  simp [ha]

/-- SCR-140: BIP143 framing — the 10-field preimage length is the fixed
156-byte header (4 version + 32 prevouts + 32 sequence + 36 outpoint +
8 amount + 4 sequence + 32 outputs + 4 locktime + 4 hashtype, with the
outpoint hash contributing its actual size) plus the CompactSize-prefixed
scriptCode. The 8-byte amount slot is field 6. -/
@[rule "SCR-140"]
theorem bip143MsgL_length (tx : Bitcoin.Data.Tx) (nIn : Nat) (sc : Bytes) (ht : UInt32)
    (amount : Bitcoin.Data.Amount) :
    (bip143MsgL tx nIn sc ht amount).length =
      124 + (tx.vin.getD nIn (⟨Bitcoin.Data.OutPoint.null, Bitcoin.Data.Script.empty, 0⟩ : Bitcoin.Data.TxIn)).prevout.hash.size
        + (Bitcoin.Serialization.encCSL sc.length).length + sc.length := by
  have hp : (hashPrevoutsL tx ht).length = 32 := by
    unfold hashPrevoutsL
    split <;> simp [zeroHashL, bL, Bitcoin.SigHash.dshaL, Bitcoin.Crypto.Seam.sha256d_size, Array.length_toList]
  have hs : (hashSequenceL tx ht).length = 32 := by
    unfold hashSequenceL
    split <;> simp [zeroHashL, bL, Bitcoin.SigHash.dshaL, Bitcoin.Crypto.Seam.sha256d_size, Array.length_toList]
  have ho : (hashOutputsL tx nIn ht).length = 32 := by
    unfold hashOutputsL
    split <;> (try split) <;> simp [zeroHashL, bL, Bitcoin.SigHash.dshaL, Bitcoin.Crypto.Seam.sha256d_size, Array.length_toList]
  unfold bip143MsgL
  simp only [List.length_append, hp, hs, ho, serU32L, serU64L, serAmountL,
    serOutpointL, bL, Array.length_toList, List.length_cons, List.length_nil]
  simp
  omega

/-- INV-073: single-leaf (33-byte) control commits to the masked tapleaf hash. -/
@[rule "INV-073"]
theorem tapleafCommitment_singleLeaf_row (control script : ByteArray)
    (h33 : control.size = 33) :
    Bitcoin.Invariants.RC07.tapleafCommitment control script =
      some (Bitcoin.Interpreter.tapLeafHash (control[0]! &&& 0xfe) script) := by
  unfold Bitcoin.Invariants.RC07.tapleafCommitment
  rw [Bitcoin.Invariants.RC07.taprootMerkleRoot_empty _ _ h33]

/-- INV-073: a control block below the 33-byte base is rejected. -/
@[rule "INV-073"]
theorem tapleafCommitment_short_none (control script : ByteArray)
    (h : control.size < 33) :
    Bitcoin.Invariants.RC07.tapleafCommitment control script = none := by
  unfold Bitcoin.Invariants.RC07.tapleafCommitment
  rw [Bitcoin.Invariants.RC07.taprootMerkleRoot_short _ _ h]

/-- INV-073: the full script-path leaf commitment for a control block with
`k` internal taptree nodes (`control.size = 33 + 32·k`, Core's shape
convention, `k ≤ 128`): the root is the tapleaf hash (leaf version =
`control[0]! &&& 0xfe`) folded through exactly the `k` 32-byte nodes at
offsets `33 + 32·i` with the lexicographically-ordered `TapBranch` hash.
This is the general control-block/taptree-proof lane; the single-leaf
(`k = 0`) and one-node (`k = 1`) cases are the concrete corollaries
already present. -/
@[rule "INV-073"]
theorem tapleafCommitment_path_row (control script : ByteArray) (k : Nat)
    (hk : control.size = 33 + 32 * k) (hkmax : k ≤ 128) :
    Bitcoin.Invariants.RC07.tapleafCommitment control script =
      some ((List.range k).map
        (fun i => control.extract (33 + 32 * i) (33 + 32 * i + 32))
        |>.foldl (fun acc n => Bitcoin.Invariants.RC07.tapbranchHash acc n)
          (Bitcoin.Interpreter.tapLeafHash (control[0]! &&& 0xfe) script)) := by
  unfold Bitcoin.Invariants.RC07.tapleafCommitment
  unfold Bitcoin.Invariants.RC07.taprootMerkleRoot
  have hb : Bitcoin.Invariants.RC07.controlBaseSize = 33 := rfl
  have hn : Bitcoin.Invariants.RC07.controlNodeSize = 32 := rfl
  have hx : Bitcoin.Invariants.RC07.controlMaxSize = 4129 := rfl
  simp only [hb, hn, hx]
  rw [if_neg (by omega)]
  have hdiv : (33 + 32 * k - 33) / 32 = k := by omega
  rw [hk, hdiv]

/-- SCR-163: BIP341/342 hashtype validity is exactly `≤3` or `0x81..0x83`. -/
@[rule "SCR-163"]
theorem isValidBip341Hashtype_valid_iff (ht : UInt8) :
    Bitcoin.Interpreter.isValidBip341Hashtype ht = true ↔
      ht ≤ 3 ∨ (0x81 ≤ ht ∧ ht ≤ 0x83) :=
  Bitcoin.Interpreter.isValidBip341Hashtype_char ht

/-- SCR-146: TapLeaf tagged hash is a 32-byte digest. -/
@[rule "SCR-146"]
theorem tapLeafHash_size_row (leafVersion : UInt8) (script : ByteArray) :
    (Bitcoin.Interpreter.tapLeafHash leafVersion script).size = 32 :=
  Bitcoin.Interpreter.tapLeafHash_size leafVersion script

/-- SCR-146: the TapLeaf preimage is exactly
`TaggedHash("TapLeaf", leaf_ver ‖ CompactSize(script) ‖ script)` with
`leaf_ver = control[0]! &&& 0xfe` on the script-path lane (`INV-073`
passes that masked byte to this function). `TaggedHash` here is
`sha256(sha256 tag ‖ sha256 tag ‖ msg)`, so the whole BIP341 leaf-hash
construction is visible definitionally, not just its size. -/
@[rule "SCR-146"]
theorem tapLeafHash_preimage_row (leafVersion : UInt8) (script : ByteArray) :
    Bitcoin.Interpreter.tapLeafHash leafVersion script =
      Bitcoin.Crypto.Schnorr.taggedHash Bitcoin.Crypto.Schnorr.tagTapLeaf
        (ByteArray.mk #[leafVersion &&& 0xfe] ++
          Bitcoin.Data.compactSizeEnc script.size ++ script) := rfl

/-- SCR-172: all 15 disabled wire bytes are OP_SUCCESS126..153 in tapscript. -/
@[rule "SCR-172"]
theorem disabledWire_successx_matrix_row :
    Bitcoin.Interpreter.isOpSuccessWire 0x7e = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x7f = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x80 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x81 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x83 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x84 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x85 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x86 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x8d = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x8e = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x95 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x96 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x97 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x98 = true ∧
    Bitcoin.Interpreter.isOpSuccessWire 0x99 = true :=
  Bitcoin.Interpreter.disabledWire_successx_matrix

/-- SCR-172 execution lane: a tapscript whose OP_SUCCESSx pre-scan fires
succeeds (`VerifyOutcome.ok`) before the initial-stack/per-item limits,
regardless of the witness stack contents, the flags or the checker. -/
theorem executeWitnessScript_ok_of_opSuccessScan (fuel : Nat) (items : List ByteArray)
    (vwSer : Int) (exec : ByteArray) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : Bitcoin.Interpreter.PolicyFlags) (chk : Bitcoin.Interpreter.ScriptChecker)
    (hscan : Bitcoin.Interpreter.opSuccessScan exec = true)
    (hd : pol.discourageOpSuccess = false) :
    Bitcoin.Interpreter.executeWitnessScript fuel items vwSer exec flags pol chk
      Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok := by
  simp [Bitcoin.Interpreter.executeWitnessScript, hscan, hd]

/-- SCR-172: the same 15 bytes that legacy consensus rejects as disabled
opcodes are OP_SUCCESS126..153 in tapscript, so a tapscript consisting of
one of them EXECUTES SUCCESSFULLY — for every witness stack (including
more than `MAX_STACK_SIZE` items, which the success pre-scan bypasses),
every flag word and every checker. This is the execution-level reading of
"same bytes become success in tapscript", not just the membership matrix. -/
@[rule "SCR-172"]
theorem disabledWire_tapscript_success_row (items : List ByteArray) (vwSer : Int)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (chk : Bitcoin.Interpreter.ScriptChecker)
    (hd : pol.discourageOpSuccess = false) :
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x7e])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x7f])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x80])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x81])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x83])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x84])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x85])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x86])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x8d])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x8e])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x95])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x96])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x97])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x98])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok ∧
    Bitcoin.Interpreter.executeWitnessScript 0 items vwSer (ByteArray.mk #[0x99])
        flags pol chk Bitcoin.Crypto.Seam.SigVersion.tapscript = .ok := by
  refine ⟨?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_, ?_⟩ <;>
    exact executeWitnessScript_ok_of_opSuccessScan _ _ _ _ _ _ _ (by decide) hd

/-- SGN-108: low-S is policy-only — the predicate implies strict DER. -/
@[rule "SGN-108"]
theorem isLowDERSignature_true_imp_der (b : ByteArray)
    (h : Bitcoin.Crypto.Ecdsa.Der.isLowDERSignature b = true) :
    Bitcoin.Crypto.Ecdsa.Der.isDERSignature b = true := by
  simp only [Bitcoin.Crypto.Ecdsa.Der.isLowDERSignature, Bool.and_eq_true] at h
  exact h.1

/-- SGN-108: non-DER input is never low-S. -/
@[rule "SGN-108"]
theorem isLowDERSignature_false_of_not_der (b : ByteArray)
    (h : Bitcoin.Crypto.Ecdsa.Der.isDERSignature b = false) :
    Bitcoin.Crypto.Ecdsa.Der.isLowDERSignature b = false := by
  unfold Bitcoin.Crypto.Ecdsa.Der.isLowDERSignature
  rw [h]
  rfl

/-- SGN-109: lax parser — a non-sequence tag is rejected immediately. -/
@[rule "SGN-109"]
theorem parseDerLax_tag_none (b : ByteArray)
    (h : Bitcoin.Crypto.Ecdsa.Der.byteAt b 0 ≠ 0x30) :
    Bitcoin.Crypto.Ecdsa.Der.parseDerLax b = none := by
  unfold Bitcoin.Crypto.Ecdsa.Der.parseDerLax
  simp [h]

/-- SGN-109: empty input does not parse (totality base case). -/
@[rule "SGN-109"]
theorem parseDerLax_empty_row :
    Bitcoin.Crypto.Ecdsa.Der.parseDerLax ByteArray.empty = none :=
  Bitcoin.Crypto.Ecdsa.Der.parseDerLax_nil

/-- SGN-109: the sequence length may use long form and its byte(s) are
skipped without any validation — here `0x81 0xff` (a wildly wrong length)
is ignored and the two integers still parse. The trailing suffix is
arbitrary/irrelevant. -/
@[rule "SGN-109"]
theorem parseDerLax_longSeqLength_skipped_row (r s : UInt8) (hr : r ≠ 0) (hs : s ≠ 0)
    (trail : Bytes) :
    Bitcoin.Crypto.Ecdsa.Der.parseDerLax
      (Bitcoin.Serialization.bytesOfList
        [0x30, 0x81, 0xff, 0x02, 0x01, r, 0x02, 0x01, s]
        ++ Bitcoin.Serialization.bytesOfList trail) = some (r.toNat, s.toNat) := by
  have hr0 : r.toNat ≠ 0 := fun h => hr (UInt8.toNat_inj.mp h)
  have hs0 : s.toNat ≠ 0 := fun h => hs (UInt8.toNat_inj.mp h)
  simp [Bitcoin.Crypto.Ecdsa.Der.parseDerLax, Bitcoin.Crypto.Ecdsa.Der.blen,
    Bitcoin.Crypto.Ecdsa.Der.byteAt, Bitcoin.Crypto.Ecdsa.Der.readLenAt,
    Bitcoin.Crypto.Ecdsa.Der.skipZeroBytes, Bitcoin.Crypto.Ecdsa.Der.stripZeros,
    Bitcoin.Crypto.Ecdsa.Der.readBE, Bitcoin.Serialization.bytesOfList, hr0, hs0]

/-- SGN-109: long-form integer lengths skip leading `0x00` length bytes
(`0x82 0x00 0x01` is read as length 1) and the descriptor must fit the
`< 4`-byte bound. Both integers here use the long form; the declared
lengths are honoured. -/
@[rule "SGN-109"]
theorem parseDerLax_longFormInt_zeroSkip_row (r s : UInt8) (hr : r ≠ 0) (hs : s ≠ 0)
    (trail : Bytes) :
    Bitcoin.Crypto.Ecdsa.Der.parseDerLax
      (Bitcoin.Serialization.bytesOfList
        [0x30, 0x2c, 0x02, 0x82, 0x00, 0x01, r, 0x02, 0x01, s]
        ++ Bitcoin.Serialization.bytesOfList trail) = some (r.toNat, s.toNat) := by
  have hr0 : r.toNat ≠ 0 := fun h => hr (UInt8.toNat_inj.mp h)
  have hs0 : s.toNat ≠ 0 := fun h => hs (UInt8.toNat_inj.mp h)
  have h1 : ¬ (List.length trail + 6 < 2) := by omega
  simp [Bitcoin.Crypto.Ecdsa.Der.parseDerLax, Bitcoin.Crypto.Ecdsa.Der.blen,
    Bitcoin.Crypto.Ecdsa.Der.byteAt, Bitcoin.Crypto.Ecdsa.Der.readLenAt,
    Bitcoin.Crypto.Ecdsa.Der.skipZeroBytes, Bitcoin.Crypto.Ecdsa.Der.stripZeros,
    Bitcoin.Crypto.Ecdsa.Der.readBE, Bitcoin.Serialization.bytesOfList, hr0, hs0, h1]

/-- SGN-109: lax integers tolerate leading-zero padding and "negative" DER
payloads (a payload byte with the high bit set is NOT rejected); the raw
big-endian value is used. Trailing bytes after `s` are ignored, so the
parse result is the same for every suffix. -/
@[rule "SGN-109"]
theorem parseDerLax_leadingZero_negative_trailing_row (r s : UInt8) (hr : r ≠ 0)
    (hs : s ≠ 0) (trail : Bytes) :
    Bitcoin.Crypto.Ecdsa.Der.parseDerLax
      (Bitcoin.Serialization.bytesOfList
        [0x30, 0x07, 0x02, 0x02, 0x00, r, 0x02, 0x01, s]
        ++ Bitcoin.Serialization.bytesOfList trail) = some (r.toNat, s.toNat) := by
  have hr0 : r.toNat ≠ 0 := fun h => hr (UInt8.toNat_inj.mp h)
  have hs0 : s.toNat ≠ 0 := fun h => hs (UInt8.toNat_inj.mp h)
  simp [Bitcoin.Crypto.Ecdsa.Der.parseDerLax, Bitcoin.Crypto.Ecdsa.Der.blen,
    Bitcoin.Crypto.Ecdsa.Der.byteAt, Bitcoin.Crypto.Ecdsa.Der.readLenAt,
    Bitcoin.Crypto.Ecdsa.Der.skipZeroBytes, Bitcoin.Crypto.Ecdsa.Der.stripZeros,
    Bitcoin.Crypto.Ecdsa.Der.readBE, Bitcoin.Serialization.bytesOfList, hr0, hs0]

/-- SGN-109 concrete negative-DER instance of the general law: `0x00 0xff`
is the lax encoding of -127 in DER (leading zero plus high-bit payload),
yet the parser returns the raw value `255`; trailing garbage is ignored. -/
@[rule "SGN-109"]
theorem parseDerLax_negativePayload_row (trail : Bytes) :
    Bitcoin.Crypto.Ecdsa.Der.parseDerLax
      (Bitcoin.Serialization.bytesOfList
        [0x30, 0x07, 0x02, 0x02, 0x00, 0xff, 0x02, 0x01, 0x01]
        ++ Bitcoin.Serialization.bytesOfList trail) = some (255, 1) :=
  parseDerLax_leadingZero_negative_trailing_row 0xff 0x01 (by decide) (by decide) trail

end BitcoinProofs.AF.PDW58
