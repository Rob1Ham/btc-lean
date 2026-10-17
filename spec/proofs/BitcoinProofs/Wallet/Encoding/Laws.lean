import Bitcoin.Wallet.Encoding.Base58
import Mathlib.Tactic
import Bitcoin.Wallet.RuleAttr

/-!
# Base58 and Base58Check laws

This file proves the two round-trip properties exposed by
`Bitcoin.Wallet.Encoding.Base58`: every byte string at most `maxLen`
bytes long survives `base58Encode`/`base58Decode`, and every payload at
most `maxLen` bytes long survives `base58CheckEncode`/`base58CheckDecode`.

The development first proves the natural-number core (`Nat` base-58
digits and big-endian bytes), then transports it to `ByteArray` through
explicit `ByteArray.toList` lemmas.  Only the canonical zero padding of
the encoder is used: leading zero bytes are emitted as `1` and stripped
by the decoder; a zero-length payload encodes as the empty string.

## What is not modelled

* No length limit is enforced by this file; the decoder's `maxLen` is an
  explicit parameter and the round-trip theorem assumes the input fits.
* The proof says nothing about SHA-256 collision resistance.  The
  Base58Check checksum is only shown to be reproduced byte-for-byte,
  using the existing `sha256d` model.
* Base58 alphabet case folding (none), whitespace handling, or decoding
  of non-canonical encodings is not claimed.
* The wallet census has no base58 encoding row, so no declaration here is
  tagged with `@[walletRule]`; these are shared encoder lemmas rather
  than checksum/address rule targets.
-/

theorem loop_eq (bs : ByteArray) : ∀ (i : Nat) (r : List UInt8),
    i ≤ bs.size → ByteArray.toList.loop bs i r = r.reverse ++ (bs.data.toList.drop i) := by
  intro i r
  induction k : bs.size - i using Nat.strongRecOn generalizing i r with
  | _ k ih =>
    intro hi
    rw [ByteArray.toList.loop.eq_1]
    split
    next hlt =>
      rw [ih (bs.size - (i+1)) (by omega) (i+1) (bs.get! i :: r) (by omega) (by omega)]
      have hget : bs.get! i = bs.data[i] := by
        have h' : i < bs.data.size := by simpa [ByteArray.size_data] using hlt
        rw [ByteArray.get!, Array.getElem!_eq_getD, Array.getD_eq_getD_getElem?, Array.getElem?_eq_getElem h']
        simp
      rw [hget]
      have hlen : i < bs.data.toList.length := by simpa using hlt
      have hdrop : bs.data.toList.drop i = bs.data[i] :: bs.data.toList.drop (i+1) := by
        rw [List.drop_eq_getElem_cons hlen, Array.getElem_toList]
      rw [hdrop, List.reverse_cons]
      simp
    next hge =>
      have hile : i = bs.size := by omega
      subst hile
      simp

theorem toList_data (bs : ByteArray) : bs.toList = bs.data.toList := by
  rw [ByteArray.toList.eq_1]
  simpa using loop_eq bs 0 [] (by omega)

theorem toList_toByteArray (bs : ByteArray) : bs.toList.toByteArray = bs := by
  rw [ByteArray.ext_iff]
  rw [List.data_toByteArray, toList_data]

theorem toByteArray_toList (l : List UInt8) : l.toByteArray.toList = l := by
  rw [toList_data, List.data_toByteArray]


namespace BitcoinProofs.Wallet.Encoding
open Bitcoin.Wallet.Encoding

theorem alphabet_length : base58AlphabetChars.length = 58 := rfl

theorem alphabet_getD_lt (d : Nat) (hd : d < 58) :
    base58Value? (base58AlphabetChars.getD d '1') = some d := by
  unfold base58AlphabetChars
  interval_cases d <;> rfl

theorem value?_one : base58Value? '1' = some 0 := rfl

theorem getD_ne_one (d : Nat) (hd : d < 58) (h0 : d ≠ 0) :
    base58AlphabetChars.getD d '1' ≠ '1' := by
  intro h
  have hv := alphabet_getD_lt d hd
  rw [h, value?_one] at hv
  injection hv with hd0
  exact h0 hd0.symm

theorem value?_go_lt (c : Char) : ∀ (i : Nat) (l : List Char) {d : Nat},
    base58Value?.go c i l = some d → d < i + l.length
  | i, [], d, h => by simp [base58Value?.go] at h
  | i, x :: xs, d, h => by
      rw [base58Value?.go] at h
      split at h
      next hx =>
        injection h with hd
        subst hd
        simp
      next hx =>
        have := value?_go_lt c (i+1) xs h
        simp at this ⊢
        omega

theorem value?_lt {c : Char} {d : Nat} (h : base58Value? c = some d) : d < 58 := by
  have hh := value?_go_lt c 0 base58AlphabetChars h
  rw [alphabet_length] at hh
  simpa [base58Value?] using hh

theorem decodeNat_go_eq (l : List Char) (a : Nat)
    (h : ∀ c ∈ l, ∃ d, base58Value? c = some d) :
    base58DecodeNat.go l a =
      .ok (l.foldl (fun a c => a * 58 + (base58Value? c).getD 0) a) := by
  induction l generalizing a with
  | nil => simp [base58DecodeNat.go]
  | cons c cs ih =>
      have hc : ∃ d, base58Value? c = some d := h c (by simp)
      obtain ⟨d, hd⟩ := hc
      have hcs : ∀ x ∈ cs, ∃ e, base58Value? x = some e := by
        intro x hx; exact h x (by simp [hx])
      rw [base58DecodeNat.go]
      simp only [hd, ih (a*58+d) hcs]
      simp [List.foldl_cons, hd]

theorem decodeNat_eq (l : List Char)
    (h : ∀ c ∈ l, ∃ d, base58Value? c = some d) :
    base58DecodeNat (String.ofList l) =
      .ok (l.foldl (fun a c => a * 58 + (base58Value? c).getD 0) 0) := by
  simpa [base58DecodeNat] using decodeNat_go_eq l 0 h

end BitcoinProofs.Wallet.Encoding

namespace BitcoinProofs.Wallet.Encoding
open Bitcoin.Wallet.Encoding

def b58Digits : Nat → List Nat
  | 0 => []
  | n+1 => b58Digits ((n+1)/58) ++ [(n+1)%58]

theorem go_eq_digits (fuel n : Nat) (acc : List Char) (hn : n < fuel) :
    base58DigitsNat.go fuel n acc =
      (b58Digits n).map (fun d => base58AlphabetChars.getD d '1') ++ acc := by
  induction fuel generalizing n acc with
  | zero => omega
  | succ k ih =>
      by_cases h0 : n = 0
      · subst h0
        simp [base58DigitsNat.go, b58Digits]
      · obtain ⟨m, rfl⟩ := Nat.exists_eq_succ_of_ne_zero h0
        rw [base58DigitsNat.go]
        simp only [Nat.succ_ne_zero, if_false]
        have hq : (m+1)/58 < k := by omega
        have hih := ih ((m+1)/58) (base58AlphabetChars.getD ((m+1)%58) '1' :: acc) hq
        rw [hih]
        simp [b58Digits, List.map_append]

theorem digitsChars_eq (n : Nat) :
    base58DigitsNat n = (b58Digits n).map (fun d => base58AlphabetChars.getD d '1') := by
  have := go_eq_digits (n+1) n [] (by omega)
  simpa [base58DigitsNat] using this

theorem digits_lt (n : Nat) : ∀ d ∈ b58Digits n, d < 58 := by
  induction n using Nat.strongRecOn with
  | _ n ih =>
    match n with
    | 0 => intro d hd; simp [b58Digits] at hd
    | m+1 =>
      intro d hd
      have hq : (m+1)/58 < m+1 := by
        have := Nat.div_le_self (m+1) 58
        omega
      rw [b58Digits] at hd
      rcases List.mem_append.mp hd with h | h
      · exact ih ((m+1)/58) hq d h
      · simp at h
        omega

theorem fold_b58Digits (n : Nat) :
    (b58Digits n).foldl (fun a d => a * 58 + d) 0 = n := by
  induction n using Nat.strongRecOn with
  | _ n ih =>
    match n with
    | 0 => simp [b58Digits]
    | m+1 =>
      have hq : (m+1)/58 < m+1 := by
        have := Nat.div_le_self (m+1) 58
        omega
      rw [b58Digits, List.foldl_append]
      simp only [List.foldl_cons, List.foldl_nil]
      rw [ih ((m+1)/58) hq]
      have := Nat.div_add_mod (m+1) 58
      omega

theorem fold_map_eq (ds : List Nat) (a : Nat) (h : ∀ d ∈ ds, d < 58) :
    (ds.map (fun d => base58AlphabetChars.getD d '1')).foldl
      (fun x c => x * 58 + (base58Value? c).getD 0) a =
    ds.foldl (fun x d => x * 58 + d) a := by
  induction ds generalizing a with
  | nil => rfl
  | cons d ds ih =>
      have hd : d < 58 := h d (by simp)
      have hds : ∀ e ∈ ds, e < 58 := by intro e he; exact h e (by simp [he])
      simp only [List.map_cons, List.foldl_cons]
      rw [alphabet_getD_lt d hd]
      simp only [Option.getD_some]
      rw [ih (a * 58 + d) hds]

theorem fold_digitsChars (n : Nat) :
    ((b58Digits n).map (fun d => base58AlphabetChars.getD d '1')).foldl
      (fun a c => a * 58 + (base58Value? c).getD 0) 0 = n := by
  rw [fold_map_eq (b58Digits n) 0 (digits_lt n), fold_b58Digits n]

theorem digitsChars_valid (n : Nat) :
    ∀ c ∈ (b58Digits n).map (fun d => base58AlphabetChars.getD d '1'),
      ∃ d, base58Value? c = some d := by
  intro c hc
  rw [List.mem_map] at hc
  obtain ⟨d, hd, rfl⟩ := hc
  exact ⟨d, alphabet_getD_lt d (digits_lt n d hd)⟩

theorem decodeNat_base58EncodeNat (n : Nat) :
    base58DecodeNat (base58EncodeNat n) = .ok n := by
  rw [base58EncodeNat, digitsChars_eq, decodeNat_eq _ (digitsChars_valid n), fold_digitsChars]

end BitcoinProofs.Wallet.Encoding

namespace BitcoinProofs.Wallet.Encoding
open Bitcoin.Wallet.Encoding

theorem foldl_horner (l : List UInt8) (a : Nat) :
    l.foldl (fun acc b => acc * 256 + b.toNat) a =
      a * 256 ^ l.length + bytesToNatBE l := by
  induction l generalizing a with
  | nil => simp [bytesToNatBE]
  | cons b bs ih =>
      simp only [List.length_cons, List.foldl_cons]
      rw [ih (a * 256 + b.toNat)]
      have hb : bytesToNatBE (b :: bs) =
          b.toNat * 256 ^ bs.length + bytesToNatBE bs := by
        have := ih b.toNat
        simpa [bytesToNatBE, List.foldl_cons] using this
      rw [hb, pow_succ]
      ring

theorem bytesToNatBE_append_singleton (l : List UInt8) (b : UInt8) :
    bytesToNatBE (l ++ [b]) = bytesToNatBE l * 256 + b.toNat := by
  simp only [bytesToNatBE, List.foldl_append, List.foldl_cons, List.foldl_nil]

def natBytes : Nat → List UInt8
  | 0 => []
  | n+1 => natBytes ((n+1)/256) ++ [((n+1)%256).toUInt8]

theorem natToBytesBE_go_eq (fuel n : Nat) (acc : List UInt8) (hn : n < fuel) :
    natToBytesBE.go fuel n acc = natBytes n ++ acc := by
  induction fuel generalizing n acc with
  | zero => omega
  | succ k ih =>
      by_cases h0 : n = 0
      · subst h0
        simp [natToBytesBE.go, natBytes]
      · obtain ⟨m, rfl⟩ := Nat.exists_eq_succ_of_ne_zero h0
        rw [natToBytesBE.go]
        simp only [Nat.succ_ne_zero, if_false]
        have hq : (m+1)/256 < k := by
          have := Nat.div_le_self (m+1) 256
          omega
        have hih := ih ((m+1)/256) (((m+1)%256).toUInt8 :: acc) hq
        rw [hih]
        simp [natBytes]

theorem natToBytesBE_eq (n : Nat) : natToBytesBE n = natBytes n := by
  have := natToBytesBE_go_eq (n+1) n [] (by omega)
  simpa [natToBytesBE] using this

theorem natBytes_mul_add (n c : Nat) (hc : c < 256) (h : n ≠ 0 ∨ c ≠ 0) :
    natBytes (n * 256 + c) = natBytes n ++ [c.toUInt8] := by
  have hm : n * 256 + c ≠ 0 := by
    rcases h with h | h
    · omega
    · omega
  have hdiv : (n * 256 + c) / 256 = n := by
    rw [Nat.mul_comm n 256]
    rw [Nat.mul_add_div (by omega : 0 < 256) n c, Nat.div_eq_of_lt hc]
    omega
  have hmod : (n * 256 + c) % 256 = c := by
    rw [Nat.mul_comm n 256, Nat.mul_add_mod]
    exact Nat.mod_eq_of_lt hc
  have hstep : n * 256 + c = (n * 256 + c - 1) + 1 := by omega
  conv_lhs => rw [hstep]
  rw [natBytes, ← hstep, hdiv, hmod]

theorem bytesToNatBE_cons (b : UInt8) (bs : List UInt8) :
    bytesToNatBE (b :: bs) = b.toNat * 256 ^ bs.length + bytesToNatBE bs := by
  rw [bytesToNatBE, List.foldl_cons]
  simp only [Nat.zero_mul, Nat.zero_add]
  exact foldl_horner bs b.toNat

theorem foldl_horner_ge (l : List UInt8) (a : Nat) :
    a ≤ l.foldl (fun acc b => acc * 256 + b.toNat) a := by
  induction l generalizing a with
  | nil => simp
  | cons b bs ih =>
      rw [List.foldl_cons]
      have h1 : a ≤ a * 256 + b.toNat := by nlinarith
      exact le_trans h1 (ih (a * 256 + b.toNat))

theorem bytesToNatBE_eq_zero_iff (l : List UInt8) :
    bytesToNatBE l = 0 ↔ ∀ b ∈ l, b = 0 := by
  constructor
  · intro h b hb
    induction l with
    | nil => simp at hb
    | cons x xs ih =>
        rw [bytesToNatBE_cons] at h
        have hx : x = 0 := by
          by_contra hx
          have hpos : 0 < x.toNat := by
            have : x.toNat ≠ 0 := by
              intro hz
              apply hx
              rw [← UInt8.toNat_inj]
              simpa using hz
            omega
          have hp : 0 < 256 ^ xs.length := pow_pos (by omega) _
          nlinarith
        subst hx
        have htail : bytesToNatBE xs = 0 := by
          simpa using h
        rcases List.mem_cons.mp hb with rfl | hb
        · rfl
        · exact ih htail hb
  · intro h
    induction l with
    | nil => rfl
    | cons b bs ih =>
        have hb : b = 0 := h b (by simp)
        have hbs : ∀ x ∈ bs, x = 0 := by intro x hx; exact h x (by simp [hx])
        rw [bytesToNatBE_cons, hb]
        simpa using ih hbs

theorem bytesToNatBE_pos_of_head (b : UInt8) (bs : List UInt8) (hb : b ≠ 0) :
    0 < bytesToNatBE (b :: bs) := by
  rw [bytesToNatBE_cons]
  have hb' : 0 < b.toNat := by
    have : b.toNat ≠ 0 := by
      intro hz
      apply hb
      rw [← UInt8.toNat_inj]
      simpa using hz
    omega
  have : 0 < 256 ^ bs.length := pow_pos (by omega) _
  nlinarith

end BitcoinProofs.Wallet.Encoding

namespace BitcoinProofs.Wallet.Encoding
open Bitcoin.Wallet.Encoding

theorem nat_toUInt8_toNat (c : Nat) (hc : c < 256) : (c.toUInt8).toNat = c := by
  simp [Nat.toUInt8, Nat.mod_eq_of_lt hc]

theorem toNat_toUInt8 (b : UInt8) : (b.toNat).toUInt8 = b := by
  rw [← UInt8.toNat_inj]
  simp [Nat.toUInt8, UInt8.toNat_lt]

theorem natBytes_single (b : UInt8) (hb : b ≠ 0) : natBytes b.toNat = [b] := by
  have hlt : b.toNat < 256 := b.toNat_lt
  have hne : b.toNat ≠ 0 := by
    intro hz
    apply hb
    rw [← UInt8.toNat_inj]
    simpa using hz
  have := natBytes_mul_add 0 b.toNat hlt (Or.inr hne)
  simpa [natBytes, toNat_toUInt8] using this

theorem natBytes_bytesToNatBE (l : List UInt8)
    (h : l = [] ∨ l.head? ≠ some 0) : natBytes (bytesToNatBE l) = l := by
  have main : ∀ k, ∀ l : List UInt8, l.length = k →
      (l = [] ∨ l.head? ≠ some 0) → natBytes (bytesToNatBE l) = l := by
    intro k
    induction k using Nat.strongRecOn with
    | _ k ih =>
      intro l hlen h
      rcases List.eq_nil_or_concat l with hnil | ⟨l', b, hEq⟩
      · subst hnil
        simp [bytesToNatBE, natBytes]
      · subst hEq
        rw [List.concat_eq_append] at hlen h ⊢
        by_cases hl' : l' = []
        · subst hl'
          have hb : b ≠ 0 := by
            intro hb0
            subst hb0
            rcases h with hnil | hhead
            · simp at hnil
            · exact hhead (by simp)
          rw [bytesToNatBE_append_singleton]
          simp only [bytesToNatBE, List.foldl_nil, Nat.zero_mul, Nat.zero_add]
          exact natBytes_single b hb
        · have hhead : l'.head? ≠ some 0 := by
            rcases h with hnil | hbhead
            · simp at hnil
            · intro hh
              exact hbhead (by rw [List.head?_append, hh]; simp)
          have hlen' : l'.length < k := by
            simp only [List.length_append, List.length_cons, List.length_nil] at hlen
            omega
          have ih' := ih l'.length hlen' l' rfl (Or.inr hhead)
          have hpos : bytesToNatBE l' ≠ 0 := by
            rcases l' with _ | ⟨x, xs⟩
            · exact absurd rfl hl'
            · have hx : x ≠ 0 := by
                intro hx0
                apply hhead
                simp [hx0]
              exact ne_of_gt (bytesToNatBE_pos_of_head x xs hx)
          rw [bytesToNatBE_append_singleton,
            natBytes_mul_add (bytesToNatBE l') b.toNat b.toNat_lt (Or.inl hpos),
            ih', toNat_toUInt8]
  exact main l.length l rfl h

end BitcoinProofs.Wallet.Encoding

namespace BitcoinProofs.Wallet.Encoding
open Bitcoin.Wallet.Encoding

theorem countLeadingZeroBytes_replicate_append (z : Nat) (l : List UInt8) :
    countLeadingZeroBytes (List.replicate z (0 : UInt8) ++ l) = z + countLeadingZeroBytes l := by
  induction z with
  | zero => simp
  | succ z ih =>
      rw [List.replicate_succ, List.cons_append]
      rw [show countLeadingZeroBytes ((0 : UInt8) :: (List.replicate z 0 ++ l)) =
          1 + countLeadingZeroBytes (List.replicate z 0 ++ l) by simp [countLeadingZeroBytes]]
      rw [ih]
      omega

theorem countLeadingZeroBytes_decomp (l : List UInt8) :
    l = List.replicate (countLeadingZeroBytes l) (0 : UInt8) ++ l.drop (countLeadingZeroBytes l) := by
  induction l with
  | nil => rfl
  | cons b bs ih =>
      by_cases hb : b = 0
      · subst hb
        rw [show countLeadingZeroBytes ((0 : UInt8) :: bs) = countLeadingZeroBytes bs + 1 by
          simp [countLeadingZeroBytes]; omega]
        rw [List.replicate_succ, List.drop_succ_cons]
        conv_lhs => rw [ih]
        rw [List.cons_append]
      · rw [show countLeadingZeroBytes (b :: bs) = 0 by simp [countLeadingZeroBytes, hb]]
        simp

theorem countLeadingZeroBytes_drop (l : List UInt8) :
    l.drop (countLeadingZeroBytes l) = [] ∨
      (l.drop (countLeadingZeroBytes l)).head? ≠ some 0 := by
  induction l with
  | nil => simp
  | cons b bs ih =>
      by_cases hb : b = 0
      · subst hb
        rw [show countLeadingZeroBytes ((0 : UInt8) :: bs) = countLeadingZeroBytes bs + 1 by
          simp [countLeadingZeroBytes]; omega]
        rw [List.drop_succ_cons]
        exact ih
      · rw [show countLeadingZeroBytes (b :: bs) = 0 by simp [countLeadingZeroBytes, hb]]
        simp only [List.drop_zero, List.head?_cons, List.nil_eq]
        right
        intro h
        exact hb (Option.some.inj h)

theorem countLeadingZeroBytes_le (l : List UInt8) : countLeadingZeroBytes l ≤ l.length := by
  induction l with
  | nil => simp [countLeadingZeroBytes]
  | cons b bs ih =>
      by_cases hb : b = 0
      · simp [countLeadingZeroBytes, hb]
        try omega
      · simp [countLeadingZeroBytes, hb]

theorem splitZeros_head_ne (l : List Char)
    (h : l = [] ∨ l.head? ≠ some '1') : base58Decode.splitZeros l = (0, l) := by
  rcases l with _ | ⟨c, cs⟩
  · rfl
  · have hc : c ≠ '1' := by
      intro hc
      subst hc
      rcases h with hnil | hhead
      · simp at hnil
      · exact hhead rfl
    simp [base58Decode.splitZeros, hc]

theorem splitZeros_replicate (z : Nat) (l : List Char)
    (h : l = [] ∨ l.head? ≠ some '1') :
    base58Decode.splitZeros (List.replicate z '1' ++ l) = (z, l) := by
  induction z with
  | zero => simpa using splitZeros_head_ne l h
  | succ z ih =>
      rw [List.replicate_succ, List.cons_append]
      simp only [base58Decode.splitZeros]
      rw [ih]

end BitcoinProofs.Wallet.Encoding

namespace BitcoinProofs.Wallet.Encoding
open Bitcoin.Wallet.Encoding

theorem b58Digits_head (n : Nat) (hn : n ≠ 0) :
    ∃ d ds, b58Digits n = d :: ds ∧ d ≠ 0 := by
  induction n using Nat.strongRecOn with
  | _ n ih =>
    match n with
    | 0 => exact absurd rfl hn
    | m+1 =>
      rw [b58Digits]
      by_cases hq : (m+1)/58 = 0
      · rw [hq]
        refine ⟨(m+1)%58, [], by simp [b58Digits], ?_⟩
        have : (m+1) % 58 = m+1 := by
          rw [Nat.mod_eq_of_lt]
          omega
        omega
      · have hqpos : (m+1)/58 ≠ 0 := hq
        obtain ⟨d, ds, hd, hd0⟩ := ih ((m+1)/58) (by omega) hqpos
        refine ⟨d, ds ++ [(m+1)%58], ?_, hd0⟩
        rw [hd]
        rfl

theorem digitsChars_head_ne_one (v : Nat) (hv : v ≠ 0) :
    (b58Digits v).map (fun d => base58AlphabetChars.getD d '1') = [] ∨
      ((b58Digits v).map (fun d => base58AlphabetChars.getD d '1')).head? ≠ some '1' := by
  right
  obtain ⟨d, ds, hd, hd0⟩ := b58Digits_head v hv
  rw [hd]
  simp only [List.map_cons, List.head?_cons, Option.some.injEq]
  simpa using getD_ne_one d (digits_lt v d (by rw [hd]; simp)) hd0

theorem base58Encode_toList (p : ByteArray) :
    (base58Encode p).toList =
      List.replicate (countLeadingZeroBytes p.toList) '1' ++
        (b58Digits (bytesToNatBE (p.toList.drop (countLeadingZeroBytes p.toList)))).map
          (fun d => base58AlphabetChars.getD d '1') := by
  simp [base58Encode, digitsChars_eq]

theorem base58Decode_encode (p : ByteArray) (maxLen : Nat) (h : p.size ≤ maxLen) :
    base58Decode (base58Encode p) maxLen = .ok p := by
  let l := p.toList
  let z := countLeadingZeroBytes l
  let rest := l.drop z
  let v := bytesToNatBE rest
  let f := fun d => base58AlphabetChars.getD d '1'
  have hdecomp : l = List.replicate z (0 : UInt8) ++ rest := countLeadingZeroBytes_decomp l
  have hrest : rest = [] ∨ rest.head? ≠ some 0 := countLeadingZeroBytes_drop l
  have hchars : (b58Digits v).map f = [] ∨ ((b58Digits v).map f).head? ≠ some '1' := by
    by_cases hv : v = 0
    · left
      rw [hv, b58Digits]
      rfl
    · exact digitsChars_head_ne_one v hv
  have hsplit : base58Decode.splitZeros (List.replicate z '1' ++ (b58Digits v).map f) = (z, (b58Digits v).map f) :=
    splitZeros_replicate z _ hchars
  have henc : (base58Encode p).toList = List.replicate z '1' ++ (b58Digits v).map f := by
    simpa [l, z, rest, v, f] using base58Encode_toList p
  have hnat : base58DecodeNat (String.ofList ((b58Digits v).map f)) = .ok v := by
    rw [← digitsChars_eq v]
    exact decodeNat_base58EncodeNat v
  have hbytes : natToBytesBE v = rest := by
    rw [natToBytesBE_eq]
    by_cases hv : v = 0
    · rcases rest with _ | ⟨b, bs⟩
      · rw [hv]; simp [natBytes]
      · exfalso
        have hz := (bytesToNatBE_eq_zero_iff (b :: bs)).mp hv
        have hb : b = 0 := hz b (by simp)
        rcases hrest with hnil | hhead
        · simp at hnil
        · exact hhead (by simp [hb])
    · exact natBytes_bytesToNatBE rest hrest
  have hlen : z + rest.length = l.length := by
    rw [hdecomp]
    simp
  have hlen' : z + (natToBytesBE v).length ≤ maxLen := by
    rw [hbytes, hlen]
    have : l.length = p.size := by
      rw [show l = p.toList from rfl, toList_data]
      simp [ByteArray.size_data]
    omega
  have hm : z ≤ maxLen := by omega
  unfold base58Decode
  rw [henc]
  simp only [String.toList_ofList, hsplit]
  rw [if_neg (by omega : ¬ z > maxLen)]
  rw [hnat]
  dsimp only
  rw [if_neg (by omega : ¬ z + (natToBytesBE v).length > maxLen)]
  have hfin : (List.replicate z 0 ++ rest).toByteArray = p := by
    rw [← hdecomp]
    exact toList_toByteArray p
  rw [hbytes, hfin]

end BitcoinProofs.Wallet.Encoding

namespace BitcoinProofs.Wallet.Encoding
open Bitcoin.Wallet.Encoding
open Bitcoin.Crypto.Seam.Hash (sha256d sha256d_size)

theorem bytesBEq_self (a : ByteArray) : Bitcoin.Data.bytesBEq a a = true := by
  simp [Bitcoin.Data.bytesBEq]

theorem base58CheckDecode_encode (p : ByteArray) (maxLen : Nat) (h : p.size ≤ maxLen) :
    base58CheckDecode (base58CheckEncode p) maxLen = .ok p := by
  let c := (sha256d p).extract 0 4
  have hc : c.size = 4 := by
    simp [c, sha256d_size]
  have hraw : (p ++ c).size ≤ maxLen + 4 := by
    rw [ByteArray.size_append, hc]
    omega
  have hdec := base58Decode_encode (p ++ c) (maxLen + 4) hraw
  have hpayload : (p ++ c).extract 0 ((p ++ c).size - 4) = p := by
    have hsz : (p ++ c).size - 4 = p.size := by
      rw [ByteArray.size_append, hc]
      omega
    rw [hsz]
    exact ByteArray.extract_append_eq_left rfl
  have hsupplied : (p ++ c).extract ((p ++ c).size - 4) (p ++ c).size = c := by
    have hsz : (p ++ c).size - 4 = p.size := by
      rw [ByteArray.size_append, hc]
      omega
    rw [hsz]
    rw [show (p ++ c).size = p.size + c.size by rw [ByteArray.size_append]]
    exact ByteArray.extract_append_eq_right rfl rfl
  unfold base58CheckDecode base58CheckEncode
  rw [hdec]
  dsimp only
  rw [if_neg (by rw [ByteArray.size_append, hc]; omega)]
  rw [hpayload, hsupplied]
  simp [c, bytesBEq_self]

end BitcoinProofs.Wallet.Encoding
