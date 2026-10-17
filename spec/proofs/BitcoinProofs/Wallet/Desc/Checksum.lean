import BitcoinProofs.Wallet.Obligations
import Bitcoin.Wallet.RuleAttr
import Mathlib.Tactic

/-!
# Descriptor checksum laws

This file proves the checksum-row obligations for
`Bitcoin.Wallet.Descriptor.Checksum` and `...Parse.checkChecksum` that are
visible in `BitcoinProofs.Wallet.Obligations`:

* `DESC-001`: the empty-string sentinel is returned exactly when a payload
  character is outside `INPUT_CHARSET`;
* `DESC-003`: the final state is obtained by eight zero `polyMod` steps and
  one XOR with `1`;
* `DESC-004`: the eight output characters are the base-32 slices of that
  final state, looked up in `CHECKSUM_CHARSET`;
* `DESC-005`: `AddChecksum` is payload `#` checksum, definitionally;
* `DESC-006`: two or more `#` characters are rejected before any length or
  equality test;
* `DESC-007`: a required checksum with no `#` gives `missingChecksum`.

The descriptive helper lemmas (`charsetIndex_*`, `loop_none`) are not
tagged: they are proof plumbing for `DESC-001`, not independent census
rows.

## What is not modelled

* No error-detection distance or collision-resistance claim is made; the
  checksum remains a typo detector.
* `DESC-002` (the three-character class grouping) is not proved here.
* `DESC-008`/`DESC-009` are not proved here: their obligations quantify
  over `payload ++ "#" ++ checksum`, and this file does not develop the
  missing `String.splitOn` append lemmas.  The definitions themselves are
  unchanged.
* `Parse` still decides descriptor grammar; nothing here claims that a
  checksum-valid payload parses to a valid descriptor (`DESC-010`).
-/

namespace BitcoinProofs.Wallet.Desc

open Bitcoin.Wallet.Descriptor

/-! ## Character-set plumbing -/

/-- `charsetIndex.go` returns `none` exactly for characters absent from the
scanned suffix. -/
theorem charsetIndex_go_none (ch : Char) :
    ∀ (i : Nat) (cs : List Char), charsetIndex.go ch i cs = none ↔ ch ∉ cs := by
  intro i cs
  induction cs generalizing i with
  | nil => simp [charsetIndex.go]
  | cons x xs ih =>
      rw [charsetIndex.go]
      split
      · rename_i h
        simp [h]
      · rename_i h
        rw [ih (i + 1)]
        constructor
        · intro hn hmem
          rcases List.mem_cons.mp hmem with rfl | hmem
          · exact h rfl
          · exact hn hmem
        · intro hmem hx
          exact hmem (by simp [hx])

/-- `charsetIndex` misses exactly the characters outside `inputCharset`. -/
theorem charsetIndex_none (ch : Char) :
    charsetIndex inputCharset ch = none ↔ ch ∉ inputCharset.toList := by
  unfold charsetIndex
  exact charsetIndex_go_none ch 0 inputCharset.toList

/-- The payload loop fails exactly on a character outside `inputCharset`. -/
theorem loop_none (cs : List Char) :
    ∀ (c cls : UInt64) (count : Nat),
      descriptorChecksum.loop cs c cls count = none ↔
        ∃ ch ∈ cs, charsetIndex inputCharset ch = none := by
  induction cs with
  | nil => intro c cls count; simp [descriptorChecksum.loop.eq_1]
  | cons x xs ih =>
      intro c cls count
      rw [descriptorChecksum.loop.eq_2]
      split
      · rename_i hx
        constructor
        · intro _; exact ⟨x, by simp, hx⟩
        · intro _; rfl
      · rename_i pos hpos
        by_cases hc : count + 1 = 3
        · rw [if_pos hc]
          have h := ih (polyMod (polyMod c (pos % 32).toUInt64)
            (cls * 3 + (pos / 32).toUInt64)) 0 0
          rw [h]
          constructor
          · rintro ⟨y, hy, hyi⟩; exact ⟨y, by simp [hy], hyi⟩
          · rintro ⟨y, hy, hyi⟩
            rcases List.mem_cons.mp hy with rfl | hy'
            · rw [hpos] at hyi; contradiction
            · exact ⟨y, hy', hyi⟩
        · rw [if_neg hc]
          have h := ih (polyMod c (pos % 32).toUInt64)
            (cls * 3 + (pos / 32).toUInt64) (count + 1)
          rw [h]
          constructor
          · rintro ⟨y, hy, hyi⟩; exact ⟨y, by simp [hy], hyi⟩
          · rintro ⟨y, hy, hyi⟩
            rcases List.mem_cons.mp hy with rfl | hy'
            · rw [hpos] at hyi; contradiction
            · exact ⟨y, hy', hyi⟩

/-- `firstInvalidChar` is `some` exactly when the loop would fail. -/
theorem firstInvalidChar_isSome (s : String) :
    (firstInvalidChar s).isSome = true ↔
      ∃ ch ∈ s.toList, charsetIndex inputCharset ch = none := by
  rw [firstInvalidChar, List.find?_isSome]
  constructor
  · rintro ⟨ch, hch, h⟩
    exact ⟨ch, hch, by simpa using h⟩
  · rintro ⟨ch, hch, h⟩
    exact ⟨ch, hch, by simpa using h⟩

/-- **DESC-001.** Empty checksum iff an invalid payload character exists. -/
@[walletRule "DESC-001"]
theorem descriptorChecksum_eq_empty_iff (s : String) :
    descriptorChecksum s = "" ↔ (firstInvalidChar s).isSome := by
  unfold descriptorChecksum
  split
  · rename_i hnone
    constructor
    · intro _
      exact (firstInvalidChar_isSome s).2 ((loop_none s.toList 1 0 0).mp hnone)
    · intro _; rfl
  · rename_i c hc
    have hfi_false : (firstInvalidChar s).isSome ≠ true := by
      intro htrue
      have hex := (firstInvalidChar_isSome s).1 htrue
      have hnone := (loop_none s.toList 1 0 0).2 hex
      rw [hc] at hnone
      contradiction
    constructor
    · intro h
      have hlen := congrArg String.length h
      simp at hlen
    · intro h
      exact absurd h hfi_false

/-! ## Finalisation and emission -/

/-- **DESC-003.** Once the payload loop succeeds with state `c`, the final
value is `polyMod` iterated eight times with zero, XOR `1`, and each output
character is the corresponding five-bit slice of that value. -/
@[walletRule "DESC-003"]
theorem descriptorChecksum_final (s : String) (c : UInt64)
    (hc : descriptorChecksum.loop s.toList 1 0 0 = some c) :
    descriptorChecksum s =
      (let c := descriptorChecksum.shift 8 c ^^^ (1 : UInt64)
       String.ofList ((List.range 8).map fun j =>
         let idx := ((c >>> (5 * (7 - j)).toUInt64).toNat % 32)
         listGetD checksumCharset.toList idx 'q')) := by
  unfold descriptorChecksum
  rw [hc]

/-- **DESC-004.** The character list of a successful checksum is exactly the
eight base-32 slices looked up in `CHECKSUM_CHARSET`. -/
@[walletRule "DESC-004"]
theorem descriptorChecksum_toList (s : String) (c : UInt64)
    (hc : descriptorChecksum.loop s.toList 1 0 0 = some c) :
    (descriptorChecksum s).toList =
      (List.range 8).map (fun j =>
        let idx := (((descriptorChecksum.shift 8 c ^^^ (1 : UInt64)) >>>
          (5 * (7 - j)).toUInt64).toNat % 32)
        listGetD checksumCharset.toList idx 'q') := by
  rw [descriptorChecksum_final s c hc]
  simp

/-- **DESC-005.** Attachment is exactly payload, `#`, computed checksum. -/
@[walletRule "DESC-005"]
theorem addChecksum_eq (payload : String) :
    addChecksum payload = payload ++ "#" ++ descriptorChecksum payload := by
  rfl

/-! ## Separator and required-checksum gates -/

/-- **DESC-006.** More than two split parts (at least two `#`) is rejected
before any checksum inspection. -/
@[walletRule "DESC-006"]
theorem checkChecksum_multiple (input : String) (requireChecksum : Bool)
    (h : (input.splitOn "#").length > 2) :
    checkChecksum input requireChecksum =
      .error DescriptorError.multipleChecksums := by
  unfold checkChecksum
  rw [if_pos h]

/-- **DESC-007.** A required checksum with a single split part (no `#`) is
`missingChecksum`. -/
@[walletRule "DESC-007"]
theorem checkChecksum_missing (input : String)
    (h : (input.splitOn "#").length = 1) :
    checkChecksum input true = .error DescriptorError.missingChecksum := by
  unfold checkChecksum
  rw [if_neg (by omega : ¬ (input.splitOn "#").length > 2)]
  rcases hp : input.splitOn "#" with _ | ⟨p, rest⟩
  · simp_all
  · cases rest with
    | nil => simp [hp]
    | cons q rest => simp_all

end BitcoinProofs.Wallet.Desc
