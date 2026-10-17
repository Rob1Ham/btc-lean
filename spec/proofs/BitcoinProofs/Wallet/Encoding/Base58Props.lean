import BitcoinProofs.Wallet.Encoding.Laws

/-!
# BitcoinProofs.Wallet.Encoding.Base58Props

Properties of the executable base58 / base58check model in
`Bitcoin.Wallet.Encoding.Base58`, stated over the same `Nat` arithmetic
that the model uses.  Bitcoin Core is pinned at `cce32b168`.

## Claims proved here

1. **Alphabet only.** Every character of `base58Encode p` has a
   `base58Value?` (i.e. belongs to Bitcoin's 58-character alphabet).
   Core: `src/base58.cpp:19-20` (alphabet), `src/base58.cpp:21-38`
   (`mapBase58`).
2. **Leading zero bytes become leading `1`s.** The number of leading
   `'1'` characters of `(base58Encode p).toList` is exactly
   `countLeadingZeroBytes p.toList`, and the remainder starts with a
   non-`'1'` character (or is empty).  Core: `src/base58.cpp:89-127`.
3. **Leading `1`s decode to leading zero bytes.** Decoding
   `"1" * z ++ <canonical digits of n>` yields exactly `z` zero bytes
   followed by the minimal big-endian bytes of `n`.  Core:
   `src/base58.cpp:40-87`.
4. **Round trip.** If `p.size ≤ maxLen` (the model's only bound - the
   caller-supplied byte budget `max_ret_len`), then
   `base58Decode (base58Encode p) maxLen = .ok p`; the canonical choice
   `maxLen = p.size` needs no side condition.  For Base58Check the same
   holds with `maxLen = p.size` because the decoder reserves four extra
   bytes for the checksum, matching Core's `max_ret_len + 4`.
5. **Checksum is four bytes of double SHA-256.** `base58CheckEncode p`
   is `base58Encode (p ++ (sha256d p).extract 0 4)`, that suffix has
   size exactly 4, and every accepted Base58Check string decodes to a
   raw byte string whose final four bytes equal
   `(sha256d payload).extract 0 4`.  Core: `src/base58.cpp:137-144`
   (`EncodeBase58Check`), `src/base58.cpp:146-161`
   (`DecodeBase58Check`).
6. **Checksum mismatch is rejected.** If the final four bytes of a raw
   string differ from the recomputed truncated double SHA-256 of its
   payload, decoding returns `.error .checksumMismatch`; concretely,
   `base58Encode (payload ++ bad)` is rejected when `bad` is a four-byte
   suffix other than the correct checksum.

## What is NOT modelled or claimed

* No collision resistance or preimage resistance of SHA-256.  The
  checksum is only shown to be *the modelled* `sha256d` truncated to four
  bytes, not to be an unforgeable authenticator.
* No fixed-width overflow: the model uses unbounded `Nat`, so Core's
  `max_ret_len` integer-overflow guard is elided rather than proved.
* No whitespace skipping, embedded-NUL rejection, or alternative
  alphabets (see the "What is not modelled" section of
  `Bitcoin.Wallet.Encoding.Base58`).
* No claim about non-canonical base58 spellings beyond the leading-`1`
  rule proved in item 3; in particular this file does not prove that
  `base58Decode` rejects every over-long spelling of the same integer.
* No address/WIF semantics: the payload is an arbitrary byte string.
-/

namespace BitcoinProofs.Wallet.Encoding

open Bitcoin.Wallet.Encoding
open Bitcoin.Crypto.Seam.Hash (sha256d sha256d_size)

/-! ## Alphabet-only output -/

/-- Every character emitted by `base58Encode` belongs to Bitcoin's
base58 alphabet (`base58Value? c` is defined).  This is the model-level
form of Core's encoder indexing `pszBase58` only
(`src/base58.cpp:19-20,89-127`). -/
theorem base58Encode_alphabet (p : ByteArray) :
    ∀ c ∈ (base58Encode p).toList, ∃ d : Nat, base58Value? c = some d := by
  intro c hc
  rw [base58Encode_toList] at hc
  rcases List.mem_append.mp hc with h | h
  · have hc1 : c = '1' := List.eq_of_mem_replicate h
    subst hc1
    exact ⟨0, value?_one⟩
  · exact digitsChars_valid _ c h

/-- The characters `0`, `I`, `O`, and `l`, which Bitcoin's alphabet
deliberately omits (`src/base58.cpp:19-20`), never occur in encoded
output. -/
theorem base58Encode_ne_forbidden (p : ByteArray) :
    ∀ c ∈ (base58Encode p).toList,
      c ≠ '0' ∧ c ≠ 'I' ∧ c ≠ 'O' ∧ c ≠ 'l' := by
  have h0 : base58Value? '0' = none := by decide
  have hI : base58Value? 'I' = none := by decide
  have hO : base58Value? 'O' = none := by decide
  have hl : base58Value? 'l' = none := by decide
  intro c hc
  obtain ⟨d, hd⟩ := base58Encode_alphabet p c hc
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro h; subst h; rw [h0] at hd; cases hd
  · intro h; subst h; rw [hI] at hd; cases hd
  · intro h; subst h; rw [hO] at hd; cases hd
  · intro h; subst h; rw [hl] at hd; cases hd

/-! ## Leading zero bytes and leading `1` characters -/

/-- Number of leading `'1'` characters of a character list; the
character-level analogue of `countLeadingZeroBytes`. -/
def countLeadingOnes : List Char → Nat
  | [] => 0
  | c :: cs => if c = '1' then countLeadingOnes cs + 1 else 0

theorem countLeadingOnes_eq_zero (l : List Char)
    (h : l = [] ∨ l.head? ≠ some '1') : countLeadingOnes l = 0 := by
  rcases l with _ | ⟨c, cs⟩
  · rfl
  · have hc : c ≠ '1' := by
      intro hc
      rcases h with hnil | hhead
      · simp at hnil
      · exact hhead (by simp [hc])
    simp [countLeadingOnes, hc]

theorem countLeadingOnes_replicate_append (z : Nat) (l : List Char)
    (h : l = [] ∨ l.head? ≠ some '1') :
    countLeadingOnes (List.replicate z '1' ++ l) = z := by
  induction z with
  | zero => simpa using countLeadingOnes_eq_zero l h
  | succ z ih =>
      rw [List.replicate_succ, List.cons_append]
      simp [countLeadingOnes, ih]

/-- The canonical digit block `base58DigitsNat v` is empty or starts
with a character other than `'1'`. -/
theorem base58DigitsNat_nil_or_head (v : Nat) :
    base58DigitsNat v = [] ∨ (base58DigitsNat v).head? ≠ some '1' := by
  rw [digitsChars_eq]
  by_cases hv : v = 0
  · left
    rw [hv, b58Digits]
    rfl
  · exact digitsChars_head_ne_one v hv

/-- `base58Encode p` is exactly `countLeadingZeroBytes p.toList` copies
of `'1'` followed by the canonical digits of the remaining big-endian
integer. -/
theorem base58Encode_eq_leading_ones (p : ByteArray) :
    (base58Encode p).toList =
      List.replicate (countLeadingZeroBytes p.toList) '1' ++
        base58DigitsNat
          (bytesToNatBE (p.toList.drop (countLeadingZeroBytes p.toList))) := by
  rw [base58Encode_toList, ← digitsChars_eq]

/-- The digit block after the leading `1`s is empty or starts with a
character other than `'1'`, so `countLeadingZeroBytes` is exactly the
number of leading `1`s. -/
theorem base58Encode_tail_nil_or_head (p : ByteArray) :
    base58DigitsNat
        (bytesToNatBE (p.toList.drop (countLeadingZeroBytes p.toList))) = [] ∨
      (base58DigitsNat
        (bytesToNatBE (p.toList.drop (countLeadingZeroBytes p.toList)))).head? ≠
        some '1' :=
  base58DigitsNat_nil_or_head _

/-- The number of leading `'1'` characters of the encoded text equals
the number of leading zero bytes of the payload.  Core emits one `'1'`
per leading zero byte and no others (`src/base58.cpp:89-127`). -/
theorem countLeadingOnes_base58Encode (p : ByteArray) :
    countLeadingOnes (base58Encode p).toList =
      countLeadingZeroBytes p.toList := by
  rw [base58Encode_toList, ← digitsChars_eq]
  exact countLeadingOnes_replicate_append _ _ (base58DigitsNat_nil_or_head _)

/-- Decoding `z` leading `'1'`s followed by the canonical base58 digits
of `n` produces exactly `z` leading zero bytes followed by the minimal
big-endian representation of `n`.  The budget is exactly the decoded
length, so no truncation is involved. -/
theorem base58Decode_replicate_one (z n : Nat) :
    base58Decode
        (String.ofList (List.replicate z '1' ++ base58DigitsNat n))
        (z + (natToBytesBE n).length) =
      .ok (List.toByteArray
        (List.replicate z (0 : UInt8) ++ natToBytesBE n)) := by
  have hhead := base58DigitsNat_nil_or_head n
  have hsplit : base58Decode.splitZeros
      (List.replicate z '1' ++ base58DigitsNat n) = (z, base58DigitsNat n) :=
    splitZeros_replicate z _ hhead
  have hnat : base58DecodeNat (String.ofList (base58DigitsNat n)) = .ok n := by
    simpa [base58EncodeNat] using decodeNat_base58EncodeNat n
  have hz : ¬ z > z + (natToBytesBE n).length := by omega
  have hz' : ¬ z + (natToBytesBE n).length >
      z + (natToBytesBE n).length := by omega
  unfold base58Decode
  simp only [String.toList_ofList, hsplit]
  rw [if_neg hz, hnat]
  dsimp only
  rw [if_neg hz']

/-- The leading-zero rule seen from the encoder: exactly the payload's
leading zero bytes appear as leading `'1'`s, and decoding the same text
restores the payload (under the model's byte budget). -/
theorem leadingZeroBytes_encode_decode (p : ByteArray) (maxLen : Nat)
    (h : p.size ≤ maxLen) :
    countLeadingOnes (base58Encode p).toList = countLeadingZeroBytes p.toList ∧
      base58Decode (base58Encode p) maxLen = .ok p := by
  exact ⟨countLeadingOnes_base58Encode p,
    base58Decode_encode p maxLen h⟩

/-! ## Round trip and the model bound -/

/-- `base58Decode` inverts `base58Encode` whenever the payload fits the
caller-supplied byte budget.  This restates `base58Decode_encode` from
`Laws.lean` with the bound made explicit in the name. -/
theorem base58Decode_encode_within_bound (p : ByteArray) (maxLen : Nat)
    (h : p.size ≤ maxLen) :
    base58Decode (base58Encode p) maxLen = .ok p :=
  base58Decode_encode p maxLen h

/-- The canonical bound: using the payload length itself as the budget
always round-trips. -/
theorem base58Decode_encode_self (p : ByteArray) :
    base58Decode (base58Encode p) p.size = .ok p :=
  base58Decode_encode p p.size (le_refl _)

/-- `base58CheckDecode` inverts `base58CheckEncode` whenever the payload
fits the budget; the checksum's four bytes are accounted for inside the
decoder (`max_ret_len + 4`, `src/base58.cpp:148`). -/
theorem base58CheckDecode_encode_within_bound (p : ByteArray) (maxLen : Nat)
    (h : p.size ≤ maxLen) :
    base58CheckDecode (base58CheckEncode p) maxLen = .ok p :=
  base58CheckDecode_encode p maxLen h

/-- Base58Check round-trip with the canonical bound. -/
theorem base58CheckDecode_encode_self (p : ByteArray) :
    base58CheckDecode (base58CheckEncode p) p.size = .ok p :=
  base58CheckDecode_encode p p.size (le_refl _)

/-! ## `bytesBEq` soundness -/

/-- Soundness of `bytesBEq` for byte arrays (the same argument as
`Bitcoin.Ledger.bytesBEq_eq_of_true`, reproduced here so the proof does
not depend on the ledger layer). -/
theorem bytesBEq_eq_of_true (a b : ByteArray)
    (h : Bitcoin.Data.bytesBEq a b = true) : a = b := by
  simp only [Bitcoin.Data.bytesBEq, decide_eq_true_eq] at h
  obtain ⟨hsz, hall⟩ := h
  refine ByteArray.ext (Array.ext hsz (fun i h1 h2 => ?_))
  have hget2 : a.get! i = b.get! i := by
    have hm : i ∈ List.range a.size := List.mem_range.mpr h1
    exact eq_of_beq (List.all_eq_true.mp hall i hm)
  rw [show a.data[i] = a.get! i from by
        rw [← getElem!_pos a.data i h1]; rfl,
      show b.data[i] = b.get! i from by
        rw [← getElem!_pos b.data i h2]; rfl]
  exact hget2

/-- `bytesBEq` is false on unequal byte arrays. -/
theorem bytesBEq_false_of_ne (a b : ByteArray) (h : a ≠ b) :
    Bitcoin.Data.bytesBEq a b = false := by
  cases hb : Bitcoin.Data.bytesBEq a b with
  | false => rfl
  | true => exact absurd (bytesBEq_eq_of_true a b hb) h

/-! ## The four-byte double-SHA256 checksum -/

/-- The modelled checksum has exactly four bytes: the truncation
`extract 0 4` of a 32-byte double SHA-256. -/
theorem checksum_size (p : ByteArray) :
    ((sha256d p).extract 0 4).size = 4 := by
  rw [ByteArray.size_extract, sha256d_size]
  simp

/-- The encoded Base58Check input is the payload followed by exactly the
four-byte checksum (`src/base58.cpp:137-144`). -/
theorem base58CheckEncode_eq_append_checksum (p : ByteArray) :
    base58CheckEncode p = base58Encode (p ++ (sha256d p).extract 0 4) := rfl

/-- Size bookkeeping for the encoded raw string. -/
theorem base58CheckEncode_raw_size (p : ByteArray) :
    (p ++ (sha256d p).extract 0 4).size = p.size + 4 := by
  rw [ByteArray.size_append, checksum_size]

/-- Decoding `base58CheckEncode p` at the payload bound yields exactly
`p` followed by its four-byte truncated double SHA-256. -/
theorem base58Decode_base58CheckEncode_raw (p : ByteArray) (maxLen : Nat)
    (h : p.size ≤ maxLen) :
    base58Decode (base58CheckEncode p) (maxLen + 4) =
      .ok (p ++ (sha256d p).extract 0 4) := by
  unfold base58CheckEncode
  exact base58Decode_encode _ _ (by rw [base58CheckEncode_raw_size]; omega)

/-- Every accepted Base58Check string exposes its checksum: the raw
decoded bytes have at least four bytes, the returned payload is the raw
string minus its final four bytes, and those final four bytes are
exactly `(sha256d payload).extract 0 4` (`src/base58.cpp:146-161`). -/
theorem base58CheckDecode_ok_checksum (s : String) (maxLen : Nat) (p : ByteArray)
    (h : base58CheckDecode s maxLen = .ok p) :
    ∃ raw : ByteArray,
      base58Decode s (maxLen + 4) = .ok raw ∧
        4 ≤ raw.size ∧
          p = raw.extract 0 (raw.size - 4) ∧
            raw.extract (raw.size - 4) raw.size =
              (sha256d p).extract 0 4 := by
  unfold base58CheckDecode at h
  cases hdec : base58Decode s (maxLen + 4) with
  | error e => simp [hdec] at h
  | ok raw =>
      simp only [hdec] at h
      by_cases hshort : raw.size < 4
      · simp [hshort] at h
      · have h4 : 4 ≤ raw.size := by omega
        simp only [hshort, if_false] at h
        by_cases hbe : Bitcoin.Data.bytesBEq
            (raw.extract (raw.size - 4) raw.size)
            ((sha256d (raw.extract 0 (raw.size - 4))).extract 0 4) = true
        · simp only [hbe, if_true] at h
          have hp : p = raw.extract 0 (raw.size - 4) := by
            injection h with h'
            exact h'.symm
          exact ⟨raw, rfl, h4, hp, by
            rw [hp]
            exact bytesBEq_eq_of_true _ _ hbe⟩
        · simp [hbe] at h

/-! ## Checksum mismatch -/

/-- If the final four bytes of a raw string are not the recomputed
truncated double SHA-256 of the preceding payload, Base58Check decoding
returns `.error .checksumMismatch` (`src/base58.cpp:155`). -/
theorem base58CheckDecode_mismatch (raw : ByteArray) (maxLen : Nat)
    (h4 : 4 ≤ raw.size) (hbound : raw.size ≤ maxLen + 4)
    (hbad : raw.extract (raw.size - 4) raw.size ≠
      (sha256d (raw.extract 0 (raw.size - 4))).extract 0 4) :
    base58CheckDecode (base58Encode raw) maxLen =
      .error .checksumMismatch := by
  have hdec : base58Decode (base58Encode raw) (maxLen + 4) = .ok raw :=
    base58Decode_encode raw (maxLen + 4) hbound
  have hfalse : Bitcoin.Data.bytesBEq
      (raw.extract (raw.size - 4) raw.size)
      ((sha256d (raw.extract 0 (raw.size - 4))).extract 0 4) = false :=
    bytesBEq_false_of_ne _ _ hbad
  unfold base58CheckDecode
  rw [hdec]
  dsimp only
  rw [if_neg (by omega : ¬ raw.size < 4)]
  simp [hfalse]

/-- Concrete mismatch: appending a four-byte suffix that is not the
double-SHA256 checksum makes the encoded string fail with
`.checksumMismatch`.  No assumption about SHA-256 is used beyond the
executable `sha256d` model. -/
theorem base58CheckDecode_append_badChecksum (payload bad : ByteArray)
    (hbadSize : bad.size = 4)
    (hbad : bad ≠ (sha256d payload).extract 0 4) :
    base58CheckDecode (base58Encode (payload ++ bad)) payload.size =
      .error .checksumMismatch := by
  apply base58CheckDecode_mismatch (payload ++ bad) payload.size
  · rw [ByteArray.size_append, hbadSize]; omega
  · simp [ByteArray.size_append, hbadSize]
  · have hsz : (payload ++ bad).size - 4 = payload.size := by
      rw [ByteArray.size_append, hbadSize]; omega
    have hleft : (payload ++ bad).extract 0 ((payload ++ bad).size - 4) =
        payload := by
      rw [hsz]
      exact ByteArray.extract_append_eq_left rfl
    have hright : (payload ++ bad).extract ((payload ++ bad).size - 4)
        (payload ++ bad).size = bad := by
      rw [hsz]
      rw [show (payload ++ bad).size = payload.size + bad.size by
        rw [ByteArray.size_append]]
      exact ByteArray.extract_append_eq_right rfl rfl
    rw [hleft, hright]
    exact hbad

end BitcoinProofs.Wallet.Encoding
