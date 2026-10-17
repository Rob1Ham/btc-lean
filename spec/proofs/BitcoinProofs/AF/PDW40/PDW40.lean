import Bitcoin.Serialization.Interface

/-! # PDW40.lean — proof-promotion review RC27, items TOP-196..200

Claim v1. D-SER BIP144 tx-framing band of
`Bitcoin/Serialization/Interface.lean` (`decTxCore`, tag site :944):

* **TXV-011** `decTxCore_base_layout` — the base (no-witness) layout
  version·vin·vout·nLockTime decodes exactly (round-trip face).
* **TXV-013** `decTxCore_flag0_shortRecord` — vin-count `0x00` + flag
  `0x00` is Core's short empty-vin record (vout is not read).
* **TXV-014** `decTxCore_witness_layout` — witness-carrying tx round-trips
  through the extended layout (one stack per input after vout).
* **TXV-015** `decTxCore_superfluous` — flag set with all-empty stacks is
  rejected with `superfluousWitness`.
* **TXV-016** `decTxCore_unknownFlag` — flag ∉ {0,1} is a decode failure;
  odd flags whose witness stacks are all empty hit `superfluousWitness`
  first (Core's check order), otherwise the error is `unknownFlag`.

Route B: zero core writes, pins ⊆ [propext, Classical.choice, Quot.sound].
-/

namespace BitcoinProofs.AF.PDW40

open Bitcoin.Serialization Bitcoin.Data

/-- **TXV-011**: base (no-witness) tx layout round-trip. -/
@[rule "TXV-011"]
theorem decTxCore_base_layout (tx : Tx) (rest : Bytes) (h : wireDomain tx)
    (hw : hasWitness tx = false) :
    decTxCore (bL (serTx tx) ++ rest) = .ok (tx, rest) := by
  have he : encTxL tx = bL (serTx tx) := by
    unfold encTxL
    rw [if_neg (by simp [hw])]
  rw [← he]
  exact decTxCore_encTxL tx rest h

/-- **TXV-013**: flag-0 short record — vin stays empty and no vout is read. -/
@[rule "TXV-013"]
theorem decTxCore_flag0_shortRecord (v lt : UInt32) (rest : Bytes) :
    decTxCore (encU32L v ++ (0x00 : UInt8) :: (0x00 : UInt8) :: (encU32L lt ++ rest))
      = .ok (⟨UInt32.toInt32 v, [], [], lt, []⟩, rest) := by
  unfold decTxCore
  rw [decU32L_encU32L]
  simp only [bindE_ok]
  rw [decCS_zero]
  simp only [bindE_ok]
  rw [if_pos True.intro]
  rw [decU8L_cons]
  simp only [bindE_ok]
  rw [if_pos True.intro]
  rw [decU32L_encU32L]
  simp only [bindE_ok]

/-- **TXV-013** (general re-read face): any NONZERO flag after the empty-vin
count re-enters the extended layout — the decoder continues with `decVinL`,
then the output count/`decTxOutL`, then (odd flag) the witness stacks and
`nLockTime`. This is the row's positive direction for every flag `≠ 0`, not
just the `0x00` short-record instance above. -/
@[rule "TXV-013"]
theorem decTxCore_empty_vin_nonzero_flag
    (v : UInt32) (flag : UInt8) (h0 : flag ≠ 0) (l : Bytes) :
    decTxCore (encU32L v ++ (0x00 : UInt8) :: flag :: l)
      = (do
          let (vin, l4) ← decVinL l
          let (m, l5) ← decCS l4
          let (vout, l6) ← decN decTxOutL m l5
          if flag.toNat % 2 = 1 then
            let (w, l7) ← decN decStackL vin.length l6
            if w.all (fun s : List ByteArray => s.isEmpty) then
              .error .superfluousWitness
            else if flag ≠ 1 then
              .error .unknownFlag
            else
              let (lt, l8) ← decU32L l7
              .ok (⟨UInt32.toInt32 v, vin, vout, lt, w⟩, l8)
          else if flag ≠ 1 then
            .error .unknownFlag
          else
            let (lt, l7) ← decU32L l6
            .ok (⟨UInt32.toInt32 v, vin, vout, lt, List.replicate vin.length []⟩, l7)) := by
  unfold decTxCore
  rw [decU32L_encU32L]
  simp only [bindE_ok]
  rw [decCS_zero]
  simp only [bindE_ok, decU8L_cons, if_neg h0, if_true]

/-- Match-form of `decTxCore_empty_vin_nonzero_flag`: the do-block expanded
into one equation per decoder step (the workhorse for the rejection
theorems below). -/
theorem decTxCore_empty_vin_nonzero_flag_match
    (v : UInt32) (flag : UInt8) (h0 : flag ≠ 0) (l : Bytes) :
    decTxCore (encU32L v ++ (0x00 : UInt8) :: flag :: l)
      = (match decVinL l with
         | .error e => .error e
         | .ok p =>
           match decCS p.2 with
           | .error e => .error e
           | .ok q =>
             match decN decTxOutL q.1 q.2 with
             | .error e => .error e
             | .ok r =>
               if flag.toNat % 2 = 1 then
                 match decN decStackL p.1.length r.2 with
                 | .error e => .error e
                 | .ok s =>
                   if s.1.all (fun x : List ByteArray => x.isEmpty) then
                     .error .superfluousWitness
                   else if flag ≠ 1 then
                     .error .unknownFlag
                   else
                     match decU32L s.2 with
                     | .error e => .error e
                     | .ok u => .ok (⟨UInt32.toInt32 v, p.1, r.1, u.1, s.1⟩, u.2)
               else if flag ≠ 1 then
                 .error .unknownFlag
               else
                 match decU32L r.2 with
                 | .error e => .error e
                 | .ok u => .ok (⟨UInt32.toInt32 v, p.1, r.1, u.1, List.replicate p.1.length []⟩, u.2)) := by
  rw [decTxCore_empty_vin_nonzero_flag v flag h0 l]
  cases h1v : decVinL l with
  | error e => simp only [h1v, bindE_err]
  | ok p =>
    obtain ⟨vin, l4⟩ := p
    cases h2v : decCS l4 with
    | error e => simp only [h1v, h2v, bindE_ok, bindE_err]
    | ok q =>
      obtain ⟨m, l5⟩ := q
      cases h3v : decN decTxOutL m l5 with
      | error e => simp only [h1v, h2v, h3v, bindE_ok, bindE_err]
      | ok r =>
        obtain ⟨vout, l6⟩ := r
        simp only [h1v, h2v, h3v, bindE_ok]
        by_cases hpar : flag.toNat % 2 = 1
        · simp only [if_pos hpar]
          cases h4v : decN decStackL vin.length l6 with
          | error e => simp only [h4v, bindE_err]
          | ok s =>
            obtain ⟨w, l7⟩ := s
            by_cases hw : w.all (fun x : List ByteArray => x.isEmpty) = true
            · simp only [h4v, if_pos hw, bindE_ok]
            · by_cases hne : flag ≠ 1
              · simp only [h4v, if_neg hw, if_pos hne, bindE_ok]
              · simp only [h4v, if_neg hw, if_neg hne, bindE_ok]
                cases h5v : decU32L l7 <;> simp only [h5v, bindE_ok, bindE_err]
        · simp only [if_neg hpar]
          by_cases hne : flag ≠ 1
          · simp only [if_pos hne]
          · simp only [if_neg hne]
            cases h5v : decU32L l6 <;> simp only [h5v, bindE_ok, bindE_err]

/-- **TXV-014**: witness-carrying tx round-trips through the extended
layout, i.e. the per-input stacks are read after vout and before nLockTime. -/
@[rule "TXV-014"]
theorem decTxCore_witness_layout (tx : Tx) (rest : Bytes) (h : wireDomain tx)
    (hw : hasWitness tx = true) :
    decTxCore (encTxL tx ++ rest) = .ok (tx, rest) :=
  decTxCore_encTxL tx rest h

/-- **TXV-015**: flag set with every witness stack empty ⇒ superfluousWitness. -/
@[rule "TXV-015"]
theorem decTxCore_superfluous (v lt : UInt32) (rest : Bytes) :
    decTxCore (encU32L v ++ (0x00 : UInt8) :: (0x01 : UInt8)
        :: ((0x00 : UInt8) :: (0x00 : UInt8) :: (encU32L lt ++ rest)))
      = .error SerError.superfluousWitness := by
  unfold decTxCore
  rw [decU32L_encU32L]
  simp only [bindE_ok]
  rw [decCS_zero]
  simp only [bindE_ok]
  rw [if_pos True.intro]
  rw [decU8L_cons]
  simp only [bindE_ok]
  rw [if_neg (by decide : ¬ ((0x01 : UInt8) = 0))]
  have hvin : decVinL ((0x00 : UInt8) :: (0x00 : UInt8) :: (encU32L lt ++ rest))
      = .ok ([], (0x00 : UInt8) :: (encU32L lt ++ rest)) := by
    simp only [decVinL, decCS_zero, bindE_ok, decN]
  rw [hvin]
  simp only [bindE_ok]
  rw [decCS_zero]
  simp only [bindE_ok]
  have hout : decN decTxOutL 0 (encU32L lt ++ rest) = .ok ([], encU32L lt ++ rest) := rfl
  rw [hout]
  simp only [bindE_ok]
  first
  | rw [if_pos True.intro]
  | rw [if_pos (by decide : ((0x01 : UInt8).toNat % 2 = 1))]
  have hstk : decN decStackL ([] : List TxIn).length (encU32L lt ++ rest)
      = .ok ([], encU32L lt ++ rest) := rfl
  rw [hstk]
  simp only [bindE_ok, List.all_nil, if_true]

/-- **TXV-016**: flag `0x02` (≠ 1) ⇒ unknownFlag. -/
@[rule "TXV-016"]
theorem decTxCore_unknownFlag (v lt : UInt32) (rest : Bytes) :
    decTxCore (encU32L v ++ (0x00 : UInt8) :: (0x02 : UInt8)
        :: ((0x00 : UInt8) :: (0x00 : UInt8) :: (encU32L lt ++ rest)))
      = .error SerError.unknownFlag := by
  unfold decTxCore
  rw [decU32L_encU32L]
  simp only [bindE_ok]
  rw [decCS_zero]
  simp only [bindE_ok]
  rw [if_pos True.intro]
  rw [decU8L_cons]
  simp only [bindE_ok]
  rw [if_neg (by decide : ¬ ((0x02 : UInt8) = 0))]
  have hvin : decVinL ((0x00 : UInt8) :: (0x00 : UInt8) :: (encU32L lt ++ rest))
      = .ok ([], (0x00 : UInt8) :: (encU32L lt ++ rest)) := by
    simp only [decVinL, decCS_zero, bindE_ok, decN]
  rw [hvin]
  simp only [bindE_ok]
  rw [decCS_zero]
  simp only [bindE_ok]
  have hout : decN decTxOutL 0 (encU32L lt ++ rest) = .ok ([], encU32L lt ++ rest) := rfl
  rw [hout]
  simp only [bindE_ok]
  rw [if_neg (by decide : ¬ ((0x02 : UInt8).toNat % 2 = 1))]
  rw [if_pos (by decide : ¬ ((0x02 : UInt8) = 1))]

/-- Every replicated empty stack passes the `all isEmpty` test. -/
theorem replicate_all_empty (n : Nat) :
    (List.replicate n ([] : List ByteArray)).all (fun x => x.isEmpty) = true := by
  induction n with
  | zero => rfl
  | succ k ih => simp [List.replicate, ih]

/-- **TXV-015** (general face): for ANY canonical transaction (arbitrary
`vin`/`vout`, all wire-domain side conditions) whose witness stacks are
all empty, an odd (witness-carrying) flag is rejected with
`superfluousWitness` — not merely the empty-vin 1-in/1-out instance above.
This is Core transaction.h:229-232: `(flags & 1) && !tx.HasWitness()`
throws before the unknown-flag check. -/
@[rule "TXV-015"]
theorem decTxCore_superfluous_general
    (v : UInt32) (flag : UInt8) (hodd : flag.toNat % 2 = 1)
    (vin : List TxIn) (vout : List TxOut) (lt : UInt32) (rest : Bytes)
    (hvin : ∀ i ∈ vin, i.prevout.hash.size = 32 ∧
      i.scriptSig.bytes.size ≤ Bitcoin.Serialization.MAX_SIZE)
    (hvout : ∀ o ∈ vout, o.scriptPubKey.bytes.size ≤ Bitcoin.Serialization.MAX_SIZE ∧
      0 ≤ o.value ∧ o.value < 9223372036854775808)
    (hvc : vin.length ≤ Bitcoin.Serialization.MAX_SIZE)
    (hvoc : vout.length ≤ Bitcoin.Serialization.MAX_SIZE) :
    decTxCore (encU32L v ++ (0x00 : UInt8) :: flag ::
        (encCSL vin.length ++ vin.flatMap (fun i => bL (serTxIn i)) ++
         (encCSL vout.length ++ vout.flatMap (fun o => bL (serTxOut o)) ++
          ((List.replicate vin.length []).flatMap encStackL ++
           (encU32L lt ++ rest)))))
      = .error .superfluousWitness := by
  have h0 : flag ≠ 0 := by
    intro h; rw [h] at hodd; simp at hodd
  rw [decTxCore_empty_vin_nonzero_flag_match v flag h0]
  have H1 : ∀ a ∈ vin, ∀ r, decTxInL (bL (serTxIn a) ++ r) = .ok (a, r) := by
    intro a ha r; exact decTxInL_enc a r (hvin a ha).1 (hvin a ha).2
  have H2 : ∀ o ∈ vout, ∀ r, decTxOutL (bL (serTxOut o) ++ r) = .ok (o, r) := by
    intro o ho r
    obtain ⟨hsz, hval⟩ := hvout o ho
    exact decTxOutL_enc o r hval.1 hval.2 hsz
  have H3 : ∀ s ∈ (List.replicate vin.length ([] : List ByteArray)),
      ∀ r, decStackL (encStackL s ++ r) = .ok (s, r) := by
    intro s hs r
    obtain ⟨_, rfl⟩ := List.mem_replicate.mp hs
    exact decStackL_enc [] r (by simp) (by simp)
  simp only [decVinL, List.append_assoc]
  rw [decCS_encCSL _ hvc]
  simp only [bindE_ok]
  rw [decN_enc vin H1]
  simp only [bindE_ok]
  rw [decCS_encCSL _ hvoc]
  simp only [bindE_ok]
  rw [decN_enc vout H2]
  simp only [bindE_ok]
  rw [if_pos hodd]
  have hd := decN_enc (List.replicate vin.length ([] : List ByteArray)) H3
    (encU32L lt ++ rest)
  simp only [List.length_replicate] at hd
  rw [hd]
  simp only [bindE_ok, replicate_all_empty, if_true]

/-- **TXV-016** (general face): for ANY continuation bytes, a NONZERO flag
other than `1` is rejected with `unknownFlag` — this is the true content of
transaction.h:234-237 (`flags != 0` after bit 0 is cleared throws). `flag = 0`
is deliberately excluded: it is Core's valid short empty-vin record and
belongs to TXV-013. -/
@[rule "TXV-016"]
theorem decTxCore_unknownFlag_general (v : UInt32) (flag : UInt8)
    (h0 : flag ≠ 0) (h1 : flag ≠ 1) (l : Bytes) :
    ∃ e, decTxCore (encU32L v ++ (0x00 : UInt8) :: flag :: l) = .error e := by
  rw [decTxCore_empty_vin_nonzero_flag_match v flag h0]
  cases h1v : decVinL l with
  | error e => exact ⟨e, by simp only [h1v]⟩
  | ok p =>
    obtain ⟨vin, l4⟩ := p
    cases h2v : decCS l4 with
    | error e => exact ⟨e, by simp only [h1v, h2v]⟩
    | ok q =>
      obtain ⟨m, l5⟩ := q
      cases h3v : decN decTxOutL m l5 with
      | error e => exact ⟨e, by simp only [h1v, h2v, h3v]⟩
      | ok r =>
        obtain ⟨vout, l6⟩ := r
        simp only [h1v, h2v, h3v]
        by_cases hpar : flag.toNat % 2 = 1
        · rw [if_pos hpar]
          cases h4v : decN decStackL vin.length l6 with
          | error e => exact ⟨e, by simp only [h4v]⟩
          | ok s =>
            obtain ⟨w, l7⟩ := s
            by_cases hw : w.all (fun x : List ByteArray => x.isEmpty) = true
            · exact ⟨.superfluousWitness, by simp only [h4v, if_pos hw]⟩
            · exact ⟨.unknownFlag, by simp only [h4v, if_neg hw, if_pos h1]⟩
        · rw [if_neg hpar]
          exact ⟨.unknownFlag, by simp only [if_pos h1]⟩

/-- **TXV-016** (error-class distinction on a decode-valid tail): when the
vin count/items, vout count/items and (for an odd flag) the witness stacks
all decode, the rejection class is exactly the one Core selects. An odd flag
with all-empty witness stacks is `superfluousWitness` (transaction.h:229-232,
checked before the unknown-flag test); an even nonzero flag is `unknownFlag`
(transaction.h:234-237), and an odd flag with a non-empty stack reaches the
same unknown-flag check. This is the qualification the row needs: the
rejection is not uniformly `unknownFlag`. -/
@[rule "TXV-016"]
theorem decTxCore_unknownFlag_general_distinguish
    (v : UInt32) (flag : UInt8) (h0 : flag ≠ 0) (h1 : flag ≠ 1)
    (l : Bytes) (vin : List TxIn) (l4 : Bytes) (m : Nat) (l5 : Bytes)
    (vout : List TxOut) (l6 : Bytes) (w : List (List ByteArray)) (l7 : Bytes)
    (hvin : decVinL l = .ok (vin, l4))
    (hcs : decCS l4 = .ok (m, l5))
    (hout : decN decTxOutL m l5 = .ok (vout, l6)) :
    (flag.toNat % 2 = 1 →
      decN decStackL vin.length l6 = .ok (w, l7) →
      w.all (fun s : List ByteArray => s.isEmpty) = true →
      decTxCore (encU32L v ++ (0x00 : UInt8) :: flag :: l)
        = .error .superfluousWitness) ∧
    (¬ (flag.toNat % 2 = 1) →
      decTxCore (encU32L v ++ (0x00 : UInt8) :: flag :: l)
        = .error .unknownFlag) ∧
    (flag.toNat % 2 = 1 →
      decN decStackL vin.length l6 = .ok (w, l7) →
      ¬ (w.all (fun s : List ByteArray => s.isEmpty) = true) →
      decTxCore (encU32L v ++ (0x00 : UInt8) :: flag :: l)
        = .error .unknownFlag) := by
  rw [decTxCore_empty_vin_nonzero_flag_match v flag h0]
  simp only [hvin, hcs, hout]
  refine ⟨?_, ?_, ?_⟩
  · intro hpar hstk hw
    rw [if_pos hpar]
    simp only [hstk]
    rw [if_pos hw]
  · intro hpar
    rw [if_neg hpar, if_pos h1]
  · intro hpar hstk hw
    rw [if_pos hpar]
    simp only [hstk]
    rw [if_neg hw, if_pos h1]

end BitcoinProofs.AF.PDW40
