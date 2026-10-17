import Bitcoin.Wallet.Encoding.Bech32

/-!
# Bech32 / Bech32m structural proofs

This file proves the checksum, alphabet, separator and witness-program
round-trip properties of `Bitcoin.Wallet.Encoding.Bech32` that the wallet
address layer relies on.  The Core anchor is Bitcoin Core `cce32b168`
(`src/bech32.cpp`, `src/bech32.h`, `src/key_io.cpp`); the model's module
documentation gives the precise line references.

## Proved here

* `verifyChecksum_createChecksum`: for a valid lowercase HRP and data
  symbols in `0..31`, verifying the six symbols produced by
  `createChecksum` succeeds and reports the same encoding variant.
* The encoder's data part is drawn from exactly the BIP173 alphabet
  `qpzry9x8gf2tvdw0s3jn54khce6mua7l`, and `bech32Char`/`bech32Value?`
  are inverse on `0..31` (the alphabet is a 32-element duplicate-free
  list).
* The separator position and the six-symbol checksum suffix produced by
  the encoder satisfy exactly the decoder's structural bounds
  (`0 < pos`, `pos + 6 < length`), and the decoder reaches its checksum
  branch on such strings.
* `bech32Decode_encode`: decoding an encoder output (within the
  decoder's length limit) returns the same encoding, HRP and data.
* Consequence: a checksum made with the other constant is not accepted
  (`verifyChecksum_createChecksum_ne`), and `decodeSegwit` reports
  `wrongEncoding` for the wrong BIP350 pairing
  (`decodeSegwit_v0_bech32m`, `decodeSegwit_v1_bech32`).
* Printable strings that mix upper and lower case are rejected with
  `mixedCase`, which is how the model enforces BIP173's case rule
  (`bech32Decode_mixedCase`).
* The three official witness-program vectors round-trip through
  `encodeSegwit`/`decodeSegwit`: v0/P2WPKH with a 20-byte program,
  v0/P2WSH with a 32-byte program, and v1/P2TR with a 32-byte program
  (`roundtrip_v0_20`, `roundtrip_v0_32`, `roundtrip_v1_32`).

## Not proved / not modelled

* **The generic `ConvertBits` inverse is not proved.**  The witness
  round-trips above are the official BIP173/BIP350 vectors, evaluated
  by the kernel on their concrete programs.  There is no theorem that
  `dataToBytes (bytesToData p) = some p` for an arbitrary `ByteArray p`;
  in particular this file does not claim that every v0/v1 program
  produced by `encodeSegwit` decodes back to the same program.
* No error-detection distance, error-localisation or error-correction
  claim is made.  The BIP173/BIP350 minimum-distance property is **not
  proven** here; the checksum is only shown to round-trip.
* The model accepts only witness versions 0 and 1 with the BIP141/BIP341
  lengths.  Core's `WitnessUnknown` versions 2..16 and its
  pay-to-anchor handling are outside the model.
* `encodeSegwit` is not length-limited, matching Core's `Encode`; a
  caller can still build a string longer than 90 characters.  The decode
  round-trip therefore carries an explicit `limit` hypothesis.
* SHA-256, secp256k1 and scriptPubKey semantics are untouched.

## Design note

The checksum algebra is developed independently of Mathlib.  The model's
`polymod` is a 30-bit CRC; we identify its one-symbol transition `step`
with a linear map `L` on `GF(2)^30`, prove `L` additive, and use the
base-32 chunk decomposition of the 30-bit residue.  The only finite case
checks (`decide`) are over `Fin 32`.
-/

namespace BitcoinProofs.Wallet.Encoding.Bech32Props
open Bitcoin.Wallet.Encoding

-- Kernel evaluation of the concrete conformance vectors needs a deeper
-- recursion budget than the default.
set_option maxRecDepth 100000

def step (c : UInt32) (v : Nat) : UInt32 :=
  let c0 := c >>> (25 : UInt32)
  let c1 := ((c &&& (0x1ffffff : UInt32)) <<< (5 : UInt32)) ^^^ v.toUInt32
  let c2 := if (c0 &&& (1 : UInt32)) = 0 then c1 else c1 ^^^ (0x3b6a57b2 : UInt32)
  let c3 := if (c0 &&& (2 : UInt32)) = 0 then c2 else c2 ^^^ (0x26508e6d : UInt32)
  let c4 := if (c0 &&& (4 : UInt32)) = 0 then c3 else c3 ^^^ (0x1ea119fa : UInt32)
  let c5 := if (c0 &&& (8 : UInt32)) = 0 then c4 else c4 ^^^ (0x3d4233dd : UInt32)
  if (c0 &&& (16 : UInt32)) = 0 then c5 else c5 ^^^ (0x2a1462b3 : UInt32)

def redConst (k : UInt32) : UInt32 :=
  (if k &&& (1 : UInt32) = 0 then 0 else (0x3b6a57b2 : UInt32)) ^^^
  (if k &&& (2 : UInt32) = 0 then 0 else (0x26508e6d : UInt32)) ^^^
  (if k &&& (4 : UInt32) = 0 then 0 else (0x1ea119fa : UInt32)) ^^^
  (if k &&& (8 : UInt32) = 0 then 0 else (0x3d4233dd : UInt32)) ^^^
  (if k &&& (16 : UInt32) = 0 then 0 else (0x2a1462b3 : UInt32))

def redConstN (k : Nat) : Nat :=
  (if k &&& 1 = 0 then 0 else 0x3b6a57b2) ^^^
  (if k &&& 2 = 0 then 0 else 0x26508e6d) ^^^
  (if k &&& 4 = 0 then 0 else 0x1ea119fa) ^^^
  (if k &&& 8 = 0 then 0 else 0x3d4233dd) ^^^
  (if k &&& 16 = 0 then 0 else 0x2a1462b3)

def L (c : UInt32) : UInt32 := step c 0
def LN (x : Nat) : Nat := ((x % 2^25) <<< 5) ^^^ redConstN (x / 2^25)

theorem redConstN_lt (a : Nat) (ha : a < 32) : redConstN a < 2^30 := by
  have h : ∀ a : Fin 32, redConstN a.1 < 2^30 := by decide
  exact h ⟨a, ha⟩

theorem redConst_bridge (k : UInt32) (hk : k.toNat < 32) :
    redConst k = (redConstN k.toNat).toUInt32 := by
  have h : ∀ k : Fin 32, redConst (k.val.toUInt32) = (redConstN k.val).toUInt32 := by decide
  have h2 := h ⟨k.toNat, hk⟩
  simp only [Nat.toUInt32, Fin.val_mk] at h2
  rwa [UInt32.ofNat_toNat] at h2

theorem u32_xor_left_comm (a b c : UInt32) : a ^^^ (b ^^^ c) = b ^^^ (a ^^^ c) := by
  rw [← UInt32.xor_assoc, ← UInt32.xor_assoc, UInt32.xor_comm a b]

theorem step_expr (c : UInt32) :
    step c 0 = ((c &&& (0x1ffffff : UInt32)) <<< (5 : UInt32)) ^^^ redConst (c >>> 25) := by
  unfold step redConst
  dsimp only
  repeat' split
  all_goals simp [u32_xor_left_comm, UInt32.xor_assoc, UInt32.xor_comm]

theorem and_mask25 (x : Nat) : x &&& 33554431 = x % 2^25 := by
  have h : (33554431 : Nat) = 2^25 - 1 := by decide
  rw [h, Nat.and_two_pow_sub_one_eq_mod]

theorem shiftRight_toNat_div (c : UInt32) : (c >>> (25 : UInt32)).toNat = c.toNat / 2^25 := by
  rw [UInt32.toNat_shiftRight]
  have h : (UInt32.toNat 25 % 32) = 25 := by decide
  rw [h, Nat.shiftRight_eq_div_pow]

theorem toUInt32_toNat (x : Nat) (h : x < 2^32) : x.toUInt32.toNat = x := by
  simp only [Nat.toUInt32, UInt32.toNat_ofNat]
  exact Nat.mod_eq_of_lt h

theorem shiftLeft_five_mod (x : Nat) (hx : x < 2^25) : x <<< 5 % 2^32 = x <<< 5 := by
  rw [Nat.shiftLeft_eq]
  have h5 : (2:Nat)^5 = 32 := by decide
  rw [h5]
  exact Nat.mod_eq_of_lt (by omega)

theorem L_toNat (c : UInt32) (hc : c.toNat < 2^30) : (L c).toNat = LN c.toNat := by
  rw [show L c = ((c &&& (0x1ffffff : UInt32)) <<< (5 : UInt32)) ^^^ redConst (c >>> 25) from step_expr c]
  have hk : (c >>> (25 : UInt32)).toNat < 32 := by
    rw [shiftRight_toNat_div]; omega
  rw [redConst_bridge _ hk]
  simp only [UInt32.toNat_xor, UInt32.toNat_shiftLeft, UInt32.toNat_and,
    UInt32.toNat_ofNat, LN, shiftRight_toNat_div]
  rw [and_mask25]
  have hm : c.toNat % 2^25 < 2^25 := Nat.mod_lt c.toNat (y := 2^25) (by decide)
  rw [shiftLeft_five_mod _ hm]
  rw [toUInt32_toNat _ (by
    have h := redConstN_lt (c.toNat / 2^25) (by omega)
    omega)]

theorem nat_xor_left_comm (a b c : Nat) : a ^^^ (b ^^^ c) = b ^^^ (a ^^^ c) := by
  rw [← Nat.xor_assoc, ← Nat.xor_assoc, Nat.xor_comm a b]

theorem nat_xor_swap (a b c d : Nat) :
    a ^^^ b ^^^ (c ^^^ d) = a ^^^ c ^^^ (b ^^^ d) := by
  rw [Nat.xor_assoc a b, Nat.xor_assoc a c, nat_xor_left_comm b c d]

theorem redConstN_xor (a b : Nat) (ha : a < 32) (hb : b < 32) :
    redConstN (a ^^^ b) = redConstN a ^^^ redConstN b := by
  have h : ∀ a b : Fin 32, redConstN (a.1 ^^^ b.1) = redConstN a.1 ^^^ redConstN b.1 := by decide
  exact h ⟨a, ha⟩ ⟨b, hb⟩

theorem step_eq_zero (c : UInt32) (v : Nat) :
    step c v = step c 0 ^^^ v.toUInt32 := by
  unfold step
  dsimp only
  repeat' split
  all_goals simp [u32_xor_left_comm, UInt32.xor_assoc, UInt32.xor_comm]

theorem LN_linear (a b : Nat) (ha : a < 2^30) (hb : b < 2^30) :
    LN (a ^^^ b) = LN a ^^^ LN b := by
  unfold LN
  rw [Nat.xor_mod_two_pow, Nat.xor_div_two_pow]
  have ha' : a / 2^25 < 32 := by omega
  have hb' : b / 2^25 < 32 := by omega
  rw [redConstN_xor _ _ ha' hb', Nat.shiftLeft_xor_distrib]
  exact nat_xor_swap _ _ _ _

theorem LN_lt (a : Nat) (ha : a < 2^30) : LN a < 2^30 := by
  unfold LN
  have h1 : a % 2^25 < 2^25 := Nat.mod_lt a (y := 2^25) (by decide)
  have h2 : (a % 2^25) <<< 5 < 2^30 := by
    rw [Nat.shiftLeft_eq]
    have h5 : (2:Nat)^5 = 32 := by decide
    have h30 : (2:Nat)^30 = 1073741824 := by decide
    rw [h5, h30]
    omega
  have h3 := redConstN_lt (a / 2^25) (by omega)
  exact Nat.xor_lt_two_pow h2 h3

theorem L_lt (c : UInt32) (hc : c.toNat < 2^30) : (L c).toNat < 2^30 := by
  rw [L_toNat c hc]
  exact LN_lt c.toNat hc

theorem L_xor (a b : UInt32) (ha : a.toNat < 2^30) (hb : b.toNat < 2^30) :
    L (a ^^^ b) = L a ^^^ L b := by
  apply UInt32.toNat_inj.mp
  rw [UInt32.toNat_xor, L_toNat _ (by rw [UInt32.toNat_xor]; exact Nat.xor_lt_two_pow ha hb),
    L_toNat _ ha, L_toNat _ hb, UInt32.toNat_xor, LN_linear _ _ ha hb]

theorem step_eq (c : UInt32) (v : Nat) (hv : v < 32) :
    step c v = L c ^^^ v.toUInt32 := by
  rw [step_eq_zero]
  rfl

theorem step_lt (c : UInt32) (v : Nat) (hc : c.toNat < 2^30) (hv : v < 32) :
    (step c v).toNat < 2^30 := by
  rw [step_eq c v hv, UInt32.toNat_xor]
  apply Nat.xor_lt_two_pow (L_lt c hc)
  rw [toUInt32_toNat v (by omega)]
  omega

def powL : Nat → UInt32 → UInt32
  | 0, c => c
  | n+1, c => powL n (L c)

theorem powL_lt (n : Nat) (c : UInt32) (hc : c.toNat < 2^30) :
    (powL n c).toNat < 2^30 := by
  induction n generalizing c with
  | zero => simpa [powL] using hc
  | succ n ih => exact ih (L c) (L_lt c hc)

theorem powL_xor (n : Nat) (a b : UInt32) (ha : a.toNat < 2^30) (hb : b.toNat < 2^30) :
    powL n (a ^^^ b) = powL n a ^^^ powL n b := by
  induction n generalizing a b with
  | zero => simp [powL]
  | succ n ih =>
      simp only [powL]
      rw [L_xor a b ha hb]
      exact ih (L a) (L b) (L_lt a ha) (L_lt b hb)

theorem powL_succ (n : Nat) (c : UInt32) : powL (n+1) c = powL n (L c) := rfl

theorem toUInt32_lt_pow (v : Nat) (hv : v < 2^30) : v.toUInt32.toNat < 2^30 := by
  have h := toUInt32_toNat v (by omega : v < 2^32)
  omega

theorem L_zero : L 0 = 0 := by decide

theorem foldl_L_eq (xs : List Nat) (h : ∀ v ∈ xs, v < 32) (x : UInt32) (hx : x.toNat < 2^30) :
    xs.foldl (fun acc v => L acc ^^^ v.toUInt32) x =
      powL xs.length x ^^^ xs.foldl (fun acc v => L acc ^^^ v.toUInt32) 0 := by
  induction xs generalizing x with
  | nil => simp [powL]
  | cons v vs ih =>
      have hv : v < 32 := h v (by simp)
      have hvs : ∀ w ∈ vs, w < 32 := by intro w hw; exact h w (by simp [hw])
      rw [List.foldl_cons, List.length_cons, powL_succ]
      rw [ih hvs (L x ^^^ v.toUInt32) (Nat.xor_lt_two_pow (L_lt x hx) (toUInt32_lt_pow v (by omega)))]
      rw [List.foldl_cons, L_zero]
      simp only [UInt32.zero_xor]
      rw [ih hvs v.toUInt32 (toUInt32_lt_pow v (by omega))]
      rw [powL_xor vs.length (L x) v.toUInt32 (L_lt x hx) (toUInt32_lt_pow v (by omega))]
      rw [UInt32.xor_assoc]

theorem polymod_append (xs ys : List Nat) :
    polymod (xs ++ ys) = ys.foldl step (polymod xs) := by
  rw [show polymod (xs ++ ys) = (xs ++ ys).foldl step 1 from rfl,
      show polymod xs = xs.foldl step 1 from rfl, List.foldl_append]

theorem foldl_step_lt (xs : List Nat) (h : ∀ v ∈ xs, v < 32) (c : UInt32) (hc : c.toNat < 2^30) :
    (xs.foldl step c).toNat < 2^30 := by
  induction xs generalizing c with
  | nil => simpa using hc
  | cons v vs ih =>
      have hv : v < 32 := h v (by simp)
      have hvs : ∀ w ∈ vs, w < 32 := by intro w hw; exact h w (by simp [hw])
      rw [List.foldl_cons]
      exact ih hvs (step c v) (step_lt c v hc hv)

theorem polymod_lt (xs : List Nat) (h : ∀ v ∈ xs, v < 32) : (polymod xs).toNat < 2^30 := by
  rw [show polymod xs = xs.foldl step 1 from rfl]
  exact foldl_step_lt xs h 1 (by decide)

theorem foldl_step_eq (xs : List Nat) (h : ∀ v ∈ xs, v < 32) (c : UInt32) (hc : c.toNat < 2^30) :
    xs.foldl step c = powL xs.length c ^^^ xs.foldl (fun acc v => L acc ^^^ v.toUInt32) 0 := by
  induction xs generalizing c with
  | nil => simp [powL]
  | cons v vs ih =>
      have hv : v < 32 := h v (by simp)
      have hvs : ∀ w ∈ vs, w < 32 := by intro w hw; exact h w (by simp [hw])
      rw [List.foldl_cons, List.length_cons, powL_succ, step_eq c v hv]
      rw [ih hvs (L c ^^^ v.toUInt32) (Nat.xor_lt_two_pow (L_lt c hc) (toUInt32_lt_pow v (by omega)))]
      rw [List.foldl_cons, L_zero]
      simp only [UInt32.zero_xor]
      rw [foldl_L_eq vs hvs v.toUInt32 (toUInt32_lt_pow v (by omega))]
      rw [powL_xor vs.length (L c) v.toUInt32 (L_lt c hc) (toUInt32_lt_pow v (by omega))]
      rw [UInt32.xor_assoc]

theorem u32Fold_toNat (xs : List Nat) (h : ∀ v ∈ xs, v < 32) (c : UInt32) (hc : c.toNat < 2^30) :
    (xs.foldl (fun acc v => L acc ^^^ v.toUInt32) c).toNat =
      xs.foldl (fun acc v => LN acc ^^^ v) c.toNat := by
  induction xs generalizing c with
  | nil => rfl
  | cons v vs ih =>
      have hv : v < 32 := h v (by simp)
      have hvs : ∀ w ∈ vs, w < 32 := by intro w hw; exact h w (by simp [hw])
      rw [List.foldl_cons, List.foldl_cons]
      have hc' : (L c ^^^ v.toUInt32).toNat < 2^30 :=
        Nat.xor_lt_two_pow (L_lt c hc) (toUInt32_lt_pow v (by omega))
      rw [ih hvs (L c ^^^ v.toUInt32) hc']
      rw [UInt32.toNat_xor, L_toNat c hc, toUInt32_toNat v (by omega)]

def natChunks (N : Nat) : List Nat :=
  [ (N / 2^25) % 32, (N / 2^20) % 32, (N / 2^15) % 32,
    (N / 2^10) % 32, (N / 2^5) % 32, N % 32 ]

theorem LN_zero : LN 0 = 0 := by decide

theorem redConstN_zero : redConstN 0 = 0 := by decide

theorem LN_shift (x : Nat) (hx : x < 2^25) : LN x = x <<< 5 := by
  unfold LN
  rw [Nat.mod_eq_of_lt hx, Nat.div_eq_of_lt hx, redConstN_zero, Nat.xor_zero]

theorem shiftLeft_xor_low (a b : Nat) (hb : b < 32) :
    a <<< 5 ^^^ b = a <<< 5 + b := by
  have hor : a <<< 5 ^^^ b = a <<< 5 ||| b := by
    apply Nat.eq_of_testBit_eq
    intro j
    rw [Nat.testBit_xor, Nat.testBit_or]
    by_cases hj : j < 5
    · have ha : (a <<< 5).testBit j = false := by
        simp [Nat.testBit_shiftLeft, Nat.not_le_of_lt hj]
      simp [ha]
    · have hb' : b.testBit j = false := by
        apply Nat.testBit_lt_two_pow
        exact Nat.lt_of_lt_of_le hb (Nat.pow_le_pow_right (n := 2) (by decide : 2 > 0) (Nat.le_of_not_lt hj))
      simp [hb']
  rw [hor]
  exact (Nat.shiftLeft_add_eq_or_of_lt (i := 5) hb a).symm

theorem natFold_chunks (N : Nat) (hN : N < 2^30) :
    (natChunks N).foldl (fun acc x => LN acc ^^^ x) 0 = N := by
  have h5 : N / 2^25 < 32 := by omega
  have hd5 : (N / 2^25) % 32 = N / 2^25 := Nat.mod_eq_of_lt h5
  have h4 : (N / 2^20) % 32 < 32 := Nat.mod_lt _ (y := 32) (by decide)
  have h3 : (N / 2^15) % 32 < 32 := Nat.mod_lt _ (y := 32) (by decide)
  have h2 : (N / 2^10) % 32 < 32 := Nat.mod_lt _ (y := 32) (by decide)
  have h1 : (N / 2^5) % 32 < 32 := Nat.mod_lt _ (y := 32) (by decide)
  have h0 : N % 32 < 32 := Nat.mod_lt _ (y := 32) (by decide)
  have e1 : LN 0 ^^^ ((N / 2^25) % 32) = N / 2^25 := by
    rw [hd5, LN_zero, Nat.zero_xor]
  have e2 : LN ((N / 2^25) % 32) ^^^ ((N / 2^20) % 32) = N / 2^20 := by
    have hlt : (N / 2^25) % 32 < 2^25 := by omega
    rw [LN_shift _ hlt, shiftLeft_xor_low _ _ h4, hd5]
    omega
  have e3 : LN (N / 2^20) ^^^ ((N / 2^15) % 32) = N / 2^15 := by
    have hlt : N / 2^20 < 2^25 := by omega
    rw [LN_shift _ hlt, shiftLeft_xor_low _ _ h3]
    omega
  have e4 : LN (N / 2^15) ^^^ ((N / 2^10) % 32) = N / 2^10 := by
    have hlt : N / 2^15 < 2^25 := by omega
    rw [LN_shift _ hlt, shiftLeft_xor_low _ _ h2]
    omega
  have e5 : LN (N / 2^10) ^^^ ((N / 2^5) % 32) = N / 2^5 := by
    have hlt : N / 2^10 < 2^25 := by omega
    rw [LN_shift _ hlt, shiftLeft_xor_low _ _ h1]
    omega
  have e6 : LN (N / 2^5) ^^^ (N % 32) = N := by
    have hlt : N / 2^5 < 2^25 := by omega
    rw [LN_shift _ hlt, shiftLeft_xor_low _ _ h0]
    omega
  have e2' : LN (N / 2^25) ^^^ ((N / 2^20) % 32) = N / 2^20 := by
    simpa [hd5] using e2
  simp only [natChunks, List.foldl_cons, List.foldl_nil]
  rw [e1, e2', e3, e4, e5, e6]

def u32Chunks (m : UInt32) : List Nat :=
  (List.range 6).map fun i => (m >>> (5 * (5 - i)).toUInt32).toNat % 32

theorem u32Chunks_toNat (m : UInt32) (hm : m.toNat < 2^30) :
    u32Chunks m = natChunks m.toNat := by
  have hr : List.range 6 = [0, 1, 2, 3, 4, 5] := by decide
  rw [u32Chunks, hr, natChunks]
  simp [UInt32.toNat_shiftRight, Nat.shiftRight_eq_div_pow]

theorem u32Chunks_lt (m : UInt32) : ∀ v ∈ u32Chunks m, v < 32 := by
  intro v hv
  simp only [u32Chunks, List.mem_map, List.mem_range] at hv
  obtain ⟨i, hi, rfl⟩ := hv
  exact Nat.mod_lt _ (y := 32) (by decide)

theorem chunks_fold (m : UInt32) (hm : m.toNat < 2^30) :
    (u32Chunks m).foldl (fun acc v => L acc ^^^ v.toUInt32) 0 = m := by
  apply UInt32.toNat_inj.mp
  rw [u32Fold_toNat (u32Chunks m) (u32Chunks_lt m) 0 (by decide)]
  rw [u32Chunks_toNat m hm]
  simp only [UInt32.toNat_zero]
  rw [natFold_chunks m.toNat hm]

/-! ## Checksum composition -/

theorem hrp_char_le (hrp : String) (h : hrpValid hrp = true) :
    ∀ c ∈ hrp.toList, c.toNat ≤ 126 := by
  intro c hc
  unfold hrpValid at h
  simp only [Bool.and_eq_true, List.all_eq_true, decide_eq_true_eq] at h
  exact (h.2 c hc).1.2

theorem hrpExpand_lt32 (hrp : String) (h : hrpValid hrp = true) :
    ∀ v ∈ hrpExpand hrp, v < 32 := by
  have hle := hrp_char_le hrp h
  intro v hv
  unfold hrpExpand at hv
  simp only [List.mem_append, List.mem_map, List.mem_cons, List.not_mem_nil, or_false] at hv
  rcases hv with (⟨c, hc, rfl⟩ | rfl) | ⟨c, hc, rfl⟩
  · have := hle c hc
    omega
  · omega
  · exact Nat.mod_lt _ (y := 32) (by decide)

theorem encodingConstant_lt (enc : Encoding) : (encodingConstant enc).toNat < 2^30 := by
  cases enc <;> decide

def zeros6 : List Nat := [0, 0, 0, 0, 0, 0]

theorem zeros6_lt : ∀ v ∈ zeros6, v < 32 := by
  intro v hv
  simp [zeros6] at hv
  omega

theorem foldl_zero6 : zeros6.foldl (fun acc v => L acc ^^^ v.toUInt32) 0 = 0 := by
  simp [zeros6, L_zero]

theorem polymod_zeros6 (p : List Nat) (hs : (polymod p).toNat < 2^30) :
    polymod (p ++ zeros6) = powL 6 (polymod p) := by
  rw [polymod_append]
  rw [foldl_step_eq zeros6 zeros6_lt (polymod p) hs, foldl_zero6]
  rw [show zeros6.length = 6 from rfl]
  simp

theorem polymod_createChecksum (enc : Encoding) (hrp : String) (data : List Nat)
    (hhrp : hrpValid hrp = true) (hdata : ∀ v ∈ data, v < 32) :
    polymod (hrpExpand hrp ++ data ++ createChecksum enc hrp data) = encodingConstant enc := by
  let p := hrpExpand hrp ++ data
  let s := polymod p
  let M : UInt32 := powL 6 s ^^^ encodingConstant enc
  have hp : ∀ v ∈ p, v < 32 := by
    intro v hv
    simp only [p, List.mem_append] at hv
    rcases hv with hv | hv
    · exact hrpExpand_lt32 hrp hhrp v hv
    · exact hdata v hv
  have hs : s.toNat < 2^30 := polymod_lt p hp
  have hM : M.toNat < 2^30 :=
    Nat.xor_lt_two_pow (powL_lt 6 s hs) (encodingConstant_lt enc)
  have hzeros : polymod (p ++ zeros6) = powL 6 s := polymod_zeros6 p hs
  have hchunks : createChecksum enc hrp data = u32Chunks M := by
    unfold createChecksum
    dsimp only
    rw [show hrpExpand hrp ++ data ++ [0, 0, 0, 0, 0, 0] = p ++ zeros6 by
      simp [p, zeros6, List.append_assoc]]
    rw [hzeros]
    rfl
  have hfold : (u32Chunks M).foldl (fun acc v => L acc ^^^ v.toUInt32) 0 = M :=
    chunks_fold M hM
  have hlen : (u32Chunks M).length = 6 := by simp [u32Chunks]
  have hmain : polymod (p ++ createChecksum enc hrp data) = encodingConstant enc := by
    rw [hchunks, polymod_append]
    rw [foldl_step_eq (u32Chunks M) (u32Chunks_lt M) s hs]
    rw [hlen, hfold]
    unfold M
    rw [← UInt32.xor_assoc, UInt32.xor_self, UInt32.zero_xor]
  rw [show hrpExpand hrp ++ data ++ createChecksum enc hrp data
      = p ++ createChecksum enc hrp data by simp [p, List.append_assoc]]
  exact hmain

theorem verifyChecksum_createChecksum (enc : Encoding) (hrp : String) (data : List Nat)
    (hhrp : hrpValid hrp = true) (hdata : ∀ v ∈ data, v < 32) :
    verifyChecksum hrp (data ++ createChecksum enc hrp data) = some enc := by
  have h := polymod_createChecksum enc hrp data hhrp hdata
  unfold verifyChecksum
  rw [show hrpExpand hrp ++ (data ++ createChecksum enc hrp data)
      = hrpExpand hrp ++ data ++ createChecksum enc hrp data by rw [List.append_assoc]]
  rw [h]
  cases enc <;> decide

/-! ## Alphabet and encoder output -/

theorem charset_length : bech32CharsetChars.length = 32 := rfl

theorem charset_nodup : bech32CharsetChars.Nodup := by decide

theorem one_not_mem_charset : '1' ∉ bech32CharsetChars := by decide

theorem bech32Char_mem (v : Nat) (hv : v < 32) : bech32Char v ∈ bech32CharsetChars := by
  have h : ∀ v : Fin 32, bech32CharsetChars.getD v.val 'q' ∈ bech32CharsetChars := by decide
  simpa [bech32Char, Nat.mod_eq_of_lt hv] using h ⟨v, hv⟩

theorem bech32Value?_bech32Char (v : Nat) (hv : v < 32) :
    bech32Value? (bech32Char v) = some v := by
  have h : ∀ v : Fin 32, bech32Value? (bech32CharsetChars.getD v.val 'q') = some v.val := by decide
  simpa [bech32Char, Nat.mod_eq_of_lt hv] using h ⟨v, hv⟩

theorem bech32Char_ne_one (v : Nat) (hv : v < 32) : bech32Char v ≠ '1' := by
  intro h
  have hm := bech32Char_mem v hv
  rw [h] at hm
  exact one_not_mem_charset hm

theorem bech32Char_surj (c : Char) (hc : c ∈ bech32CharsetChars) :
    ∃ v, v < 32 ∧ bech32Char v = c := by
  obtain ⟨i, hi, hget⟩ := List.mem_iff_getElem.mp hc
  refine ⟨i, hi, ?_⟩
  rw [← hget]
  have h : ∀ i : Fin 32, bech32CharsetChars.getD i.val 'q' = bech32CharsetChars[i.val] := by decide
  have hmod : i % 32 = i := Nat.mod_eq_of_lt hi
  simpa [bech32Char, hmod] using h ⟨i, hi⟩

theorem createChecksum_length (enc : Encoding) (hrp : String) (data : List Nat) :
    (createChecksum enc hrp data).length = 6 := by
  simp [createChecksum, List.length_map]

theorem createChecksum_lt (enc : Encoding) (hrp : String) (data : List Nat) :
    ∀ v ∈ createChecksum enc hrp data, v < 32 := by
  intro v hv
  simp only [createChecksum, List.mem_map, List.mem_range] at hv
  obtain ⟨i, hi, rfl⟩ := hv
  exact Nat.mod_lt _ (y := 32) (by decide)

theorem data_lt_of_find_none (data : List Nat)
    (h : data.find? (fun v => decide (v ≥ 32)) = none) :
    ∀ v ∈ data, v < 32 := by
  intro v hv
  have hh := (List.find?_eq_none.mp h) v hv
  simp at hh
  omega

theorem bech32Encode_ok_parts (enc : Encoding) (hrp : String) (data : List Nat) (s : String)
    (h : bech32Encode enc hrp data = .ok s) :
    hrpValid hrp = true ∧
    (∃ rest, s.toList = hrp.toList ++ '1' :: rest ∧
      rest = (data ++ createChecksum enc hrp data).map bech32Char) := by
  unfold bech32Encode at h
  by_cases hh : hrpValid hrp = true
  · rw [if_neg (by simp [hh])] at h
    split at h
    next v hv => simp at h
    next hnone =>
      injection h with hs
      subst hs
      refine ⟨hh, (data ++ createChecksum enc hrp data).map bech32Char, ?_, rfl⟩
      simp [String.toList_append, List.append_assoc]
  · rw [if_pos (by simp [hh])] at h
    simp at h

/-! ## Separator position -/

theorem lastIndexChar_go_none (target : Char) (cs : List Char) (i : Nat) (last : Option Nat)
    (h : target ∉ cs) : lastIndexChar.go target i last cs = last := by
  induction cs generalizing i last with
  | nil => rfl
  | cons c cs ih =>
      have hc : c ≠ target := by intro hh; exact h (by simp [hh])
      have hcs : target ∉ cs := by intro hh; exact h (by simp [hh])
      simpa [lastIndexChar.go, hc] using ih (i+1) last hcs

theorem lastIndexChar_go_append_target (target : Char) (l1 l2 : List Char) (i : Nat) (last : Option Nat)
    (h : target ∉ l2) :
    lastIndexChar.go target i last (l1 ++ target :: l2) = some (i + l1.length) := by
  induction l1 generalizing i last with
  | nil =>
      simp only [List.nil_append, List.length_nil, Nat.add_zero, lastIndexChar.go]
      simp only [if_true]
      exact lastIndexChar_go_none target l2 (i+1) (some i) h
  | cons c cs ih =>
      rw [List.cons_append, lastIndexChar.go]
      by_cases hc : c = target
      · rw [if_pos hc]
        rw [ih (i+1) (some i)]
        simp
        omega
      · rw [if_neg hc]
        rw [ih (i+1) last]
        simp
        omega

theorem lastIndexChar_append_target (target : Char) (l1 l2 : List Char)
    (h : target ∉ l2) :
    lastIndexChar target (l1 ++ target :: l2) = some l1.length := by
  simpa [lastIndexChar] using lastIndexChar_go_append_target target l1 l2 0 none h

/-! ## Base-32 decoding of encoder output -/

theorem decodeBase32_map (start : Nat) (vs : List Nat) (h : ∀ v ∈ vs, v < 32) :
    decodeBase32 start (vs.map bech32Char) = .ok vs := by
  induction vs generalizing start with
  | nil => rfl
  | cons v vs ih =>
      have hv : v < 32 := h v (by simp)
      have hvs : ∀ w ∈ vs, w < 32 := by intro w hw; exact h w (by simp [hw])
      simp only [List.map_cons, decodeBase32, bech32Value?_bech32Char v hv]
      rw [ih (start+1) hvs]

/-! ## The model's mixed-case rule -/

theorem checkCharacters_go_none_of_no_upper (cs : List Char) (i : Nat) (lower : Bool)
    (hprint : ∀ c ∈ cs, 33 ≤ c.toNat ∧ c.toNat ≤ 126)
    (hup : ∀ c ∈ cs, isUpperChar c = false) :
    checkCharacters.go i lower false cs = none := by
  induction cs generalizing i lower with
  | nil => rfl
  | cons c cs ih =>
      have hp := hprint c (by simp)
      have hpc : ¬(c.toNat < 33 ∨ c.toNat > 126) := by omega
      have hupc := hup c (by simp)
      have hcs : ∀ d ∈ cs, 33 ≤ d.toNat ∧ d.toNat ≤ 126 := by
        intro d hd; exact hprint d (by simp [hd])
      have hucs : ∀ d ∈ cs, isUpperChar d = false := by
        intro d hd; exact hup d (by simp [hd])
      rw [checkCharacters.go, if_neg hpc]
      by_cases hl : isLowerChar c = true
      · rw [if_pos hl]
        exact ih (i+1) true hcs hucs
      · rw [if_neg hl]
        by_cases hu : isUpperChar c = true
        · exact absurd hu (by simp [hupc])
        · rw [if_neg hu]
          exact ih (i+1) lower hcs hucs

theorem checkCharacters_go_none_or_mixed (cs : List Char) (i : Nat) (lower upper : Bool)
    (hprint : ∀ c ∈ cs, 33 ≤ c.toNat ∧ c.toNat ≤ 126) :
    checkCharacters.go i lower upper cs = none ∨
      checkCharacters.go i lower upper cs = some .mixedCase := by
  induction cs generalizing i lower upper with
  | nil => left; rfl
  | cons c cs ih =>
      have hp := hprint c (by simp)
      have hpc : ¬(c.toNat < 33 ∨ c.toNat > 126) := by omega
      have hcs : ∀ d ∈ cs, 33 ≤ d.toNat ∧ d.toNat ≤ 126 := by
        intro d hd; exact hprint d (by simp [hd])
      rw [checkCharacters.go, if_neg hpc]
      by_cases hl : isLowerChar c = true
      · rw [if_pos hl]
        by_cases hu : upper = true
        · right; rw [if_pos hu]
        · rw [if_neg hu]
          exact ih (i+1) true upper hcs
      · rw [if_neg hl]
        by_cases hu : isUpperChar c = true
        · rw [if_pos hu]
          by_cases hl' : lower = true
          · right; rw [if_pos hl']
          · rw [if_neg hl']
            exact ih (i+1) lower true hcs
        · rw [if_neg hu]
          exact ih (i+1) lower upper hcs

theorem lower_upper_false (c : Char) :
    ¬(isLowerChar c = true ∧ isUpperChar c = true) := by
  intro ⟨hl, hu⟩
  unfold isLowerChar at hl
  unfold isUpperChar at hu
  simp only [decide_eq_true_eq] at hl hu
  omega

theorem checkCharacters_go_mixed_of_both (cs : List Char) (i : Nat) (lower upper : Bool)
    (hprint : ∀ c ∈ cs, 33 ≤ c.toNat ∧ c.toNat ≤ 126)
    (h : (lower = true ∧ ∃ c ∈ cs, isUpperChar c = true) ∨
         (upper = true ∧ ∃ c ∈ cs, isLowerChar c = true) ∨
         ((∃ c ∈ cs, isLowerChar c = true) ∧ (∃ c ∈ cs, isUpperChar c = true))) :
    checkCharacters.go i lower upper cs = some .mixedCase := by
  induction cs generalizing i lower upper with
  | nil =>
      rcases h with ⟨_, ⟨c, hc, _⟩⟩ | ⟨_, ⟨c, hc, _⟩⟩ | ⟨⟨c, hc, _⟩, _⟩ <;> simp at hc
  | cons c cs ih =>
      have hp := hprint c (by simp)
      have hpc : ¬(c.toNat < 33 ∨ c.toNat > 126) := by omega
      have hcs : ∀ d ∈ cs, 33 ≤ d.toNat ∧ d.toNat ≤ 126 := by
        intro d hd; exact hprint d (by simp [hd])
      rw [checkCharacters.go, if_neg hpc]
      by_cases hl : isLowerChar c = true
      · rw [if_pos hl]
        by_cases hu : upper = true
        · rw [if_pos hu]
        · rw [if_neg hu]
          refine ih (i+1) true upper hcs ?_
          rcases h with ⟨_, ⟨d, hd, hdu⟩⟩ | ⟨hu', _⟩ | ⟨⟨d, hd, hdl⟩, ⟨e, he, heu⟩⟩
          · rcases List.mem_cons.mp hd with rfl | hd
            · exact absurd ⟨hl, hdu⟩ (lower_upper_false _)
            · exact Or.inl ⟨rfl, d, hd, hdu⟩
          · exact absurd hu' hu
          · rcases List.mem_cons.mp he with rfl | he
            · exact absurd ⟨hl, heu⟩ (lower_upper_false _)
            · exact Or.inl ⟨rfl, e, he, heu⟩
      · rw [if_neg hl]
        by_cases hu : isUpperChar c = true
        · rw [if_pos hu]
          by_cases hl' : lower = true
          · rw [if_pos hl']
          · rw [if_neg hl']
            refine ih (i+1) lower true hcs ?_
            rcases h with ⟨hlu, ⟨d, hd, hdu⟩⟩ | ⟨_, ⟨d, hd, hdl⟩⟩ | ⟨⟨d, hd, hdl⟩, ⟨e, he, heu⟩⟩
            · exact absurd hlu hl'
            · rcases List.mem_cons.mp hd with rfl | hd
              · exact absurd ⟨hdl, hu⟩ (lower_upper_false _)
              · exact Or.inr (Or.inl ⟨rfl, d, hd, hdl⟩)
            · rcases List.mem_cons.mp hd with rfl | hd
              · exact absurd ⟨hdl, hu⟩ (lower_upper_false _)
              · exact Or.inr (Or.inl ⟨rfl, d, hd, hdl⟩)
        · rw [if_neg hu]
          refine ih (i+1) lower upper hcs ?_
          rcases h with ⟨hlu, ⟨d, hd, hdu⟩⟩ | ⟨hu', ⟨d, hd, hdl⟩⟩ | ⟨⟨d, hd, hdl⟩, ⟨e, he, heu⟩⟩
          · rcases List.mem_cons.mp hd with rfl | hd
            · exact absurd hdu hu
            · exact Or.inl ⟨hlu, d, hd, hdu⟩
          · rcases List.mem_cons.mp hd with rfl | hd
            · exact absurd hdl hl
            · exact Or.inr (Or.inl ⟨hu', d, hd, hdl⟩)
          · rcases List.mem_cons.mp hd with rfl | hd
            · exact absurd hdl hl
            · rcases List.mem_cons.mp he with rfl | he
              · exact absurd heu hu
              · exact Or.inr (Or.inr ⟨⟨d, hd, hdl⟩, ⟨e, he, heu⟩⟩)


theorem charset_printable (c : Char) (hc : c ∈ bech32CharsetChars) :
    33 ≤ c.toNat ∧ c.toNat ≤ 126 := by
  have h : bech32CharsetChars.all (fun c => decide (33 ≤ c.toNat ∧ c.toNat ≤ 126)) = true := by decide
  exact of_decide_eq_true ((List.all_eq_true.mp h) c hc)

theorem charset_upper_false (c : Char) (hc : c ∈ bech32CharsetChars) :
    isUpperChar c = false := by
  have h : bech32CharsetChars.all (fun c => !isUpperChar c) = true := by decide
  have hh := (List.all_eq_true.mp h) c hc
  simpa using hh

theorem hrpValid_printable (hrp : String) (h : hrpValid hrp = true) :
    ∀ c ∈ hrp.toList, 33 ≤ c.toNat ∧ c.toNat ≤ 126 := by
  intro c hc
  unfold hrpValid at h
  simp only [Bool.and_eq_true, List.all_eq_true, decide_eq_true_eq] at h
  exact (h.2 c hc).1

theorem hrpValid_upper_false (hrp : String) (h : hrpValid hrp = true) :
    ∀ c ∈ hrp.toList, isUpperChar c = false := by
  intro c hc
  unfold hrpValid at h
  simp only [Bool.and_eq_true, List.all_eq_true, decide_eq_true_eq] at h
  simpa using (h.2 c hc).2

theorem hrpValid_nonempty (hrp : String) (h : hrpValid hrp = true) :
    hrp.toList ≠ [] := by
  intro hnil
  unfold hrpValid at h
  rw [hnil] at h
  simp at h

theorem asciiLowerChar_of_not_upper (c : Char) (h : isUpperChar c = false) :
    asciiLowerChar c = c := by
  unfold asciiLowerChar
  unfold isUpperChar at h
  rw [decide_eq_false_iff_not] at h
  simp [h]

theorem map_asciiLowerChar_eq_self_aux (cs : List Char)
    (h : ∀ c ∈ cs, isUpperChar c = false) :
    cs.map asciiLowerChar = cs := by
  induction cs with
  | nil => rfl
  | cons c cs ih =>
      simp only [List.map_cons]
      rw [asciiLowerChar_of_not_upper c (h c (by simp))]
      rw [ih (fun d hd => h d (by simp [hd]))]

theorem map_asciiLowerChar_eq_self (s : String)
    (h : ∀ c ∈ s.toList, isUpperChar c = false) :
    s.toList.map asciiLowerChar = s.toList :=
  map_asciiLowerChar_eq_self_aux s.toList h

theorem ofList_map_lower (hrp : String) (h : hrpValid hrp = true) :
    String.ofList ((hrp.toList).map asciiLowerChar) = hrp := by
  rw [map_asciiLowerChar_eq_self hrp (hrpValid_upper_false hrp h)]
  simp

theorem bech32Encode_data_lt (enc : Encoding) (hrp : String) (data : List Nat) (s : String)
    (h : bech32Encode enc hrp data = .ok s) :
    ∀ v ∈ data, v < 32 := by
  unfold bech32Encode at h
  by_cases hh : hrpValid hrp = true
  · rw [if_neg (by simp [hh])] at h
    split at h
    next v hv => simp at h
    next hnone => exact data_lt_of_find_none data hnone
  · rw [if_pos (by simp [hh])] at h
    simp at h


theorem bech32Decode_encode (enc : Encoding) (hrp : String) (data : List Nat)
    (s : String) (limit : Nat)
    (henc : bech32Encode enc hrp data = .ok s)
    (hlimit : s.toList.length ≤ limit) :
    bech32Decode s limit = .ok ⟨enc, hrp, data⟩ := by
  obtain ⟨hhrp, rest, hs, hrest⟩ := bech32Encode_ok_parts enc hrp data s henc
  have hdata : ∀ v ∈ data, v < 32 := bech32Encode_data_lt enc hrp data s henc
  have hrest_mem : ∀ c ∈ rest, c ∈ bech32CharsetChars := by
    intro c hc
    rw [hrest] at hc
    obtain ⟨v, hv, rfl⟩ := List.mem_map.mp hc
    apply bech32Char_mem
    rw [List.mem_append] at hv
    rcases hv with hv | hv
    · exact hdata v hv
    · exact createChecksum_lt enc hrp data v hv
  have hrest_ne_one : '1' ∉ rest := by
    intro hmem
    exact one_not_mem_charset (hrest_mem '1' hmem)
  have hcs_print : ∀ c ∈ s.toList, 33 ≤ c.toNat ∧ c.toNat ≤ 126 := by
    intro c hc
    rw [hs] at hc
    rcases List.mem_append.mp hc with hc | hc
    · exact hrpValid_printable hrp hhrp c hc
    · rcases List.mem_cons.mp hc with rfl | hc
      · decide
      · exact charset_printable c (hrest_mem c hc)
  have hcs_upper : ∀ c ∈ s.toList, isUpperChar c = false := by
    intro c hc
    rw [hs] at hc
    rcases List.mem_append.mp hc with hc | hc
    · exact hrpValid_upper_false hrp hhrp c hc
    · rcases List.mem_cons.mp hc with rfl | hc
      · decide
      · exact charset_upper_false c (hrest_mem c hc)
  have hcheck : checkCharacters s.toList = none := by
    unfold checkCharacters
    exact checkCharacters_go_none_of_no_upper s.toList 0 false hcs_print hcs_upper
  have hpos : lastIndexChar '1' s.toList = some hrp.toList.length := by
    rw [hs]
    exact lastIndexChar_append_target '1' hrp.toList rest hrest_ne_one
  have hsep0 : hrp.toList.length ≠ 0 := by
    intro h
    exact hrpValid_nonempty hrp hhrp (by simpa using h)
  have hcs_len : s.toList.length = hrp.toList.length + 1 + rest.length := by
    rw [hs]
    simp only [List.length_append, List.length_cons]
    omega
  have hrest_len : rest.length = data.length + 6 := by
    rw [hrest, List.length_map, List.length_append, createChecksum_length]
  have hsep6 : ¬(hrp.toList.length + 6 ≥ s.toList.length) := by omega
  have hhrp_lower :
      String.ofList ((s.toList.take hrp.toList.length).map asciiLowerChar) = hrp := by
    have htake_hrp : s.toList.take hrp.toList.length = hrp.toList := by
      rw [hs]; simp
    rw [htake_hrp]
    exact ofList_map_lower hrp hhrp
  have hdrop : s.toList.drop (hrp.toList.length + 1) = rest := by
    rw [hs]; simp
  have hdec : decodeBase32 (hrp.toList.length + 1)
      (s.toList.drop (hrp.toList.length + 1)) =
      .ok (data ++ createChecksum enc hrp data) := by
    rw [hdrop, hrest]
    apply decodeBase32_map
    intro v hv
    rw [List.mem_append] at hv
    rcases hv with hv | hv
    · exact hdata v hv
    · exact createChecksum_lt enc hrp data v hv
  have hverify : verifyChecksum hrp (data ++ createChecksum enc hrp data) = some enc :=
    verifyChecksum_createChecksum enc hrp data hhrp hdata
  have htake : (data ++ createChecksum enc hrp data).take
      ((data ++ createChecksum enc hrp data).length - 6) = data := by
    rw [List.length_append, createChecksum_length]
    simp
  dsimp only [bech32Decode]
  simp only [hcheck, hpos]
  rw [if_neg (by omega)]
  rw [if_neg (by intro h; exact h.elim hsep0 hsep6)]
  rw [hhrp_lower]
  rw [hdec]
  simp only []
  rw [hverify]
  simp only [htake]

theorem encodingConstant_injective : Function.Injective encodingConstant := by
  intro a b h
  cases a <;> cases b <;> first | rfl | exact absurd h (by decide)

theorem verifyChecksum_createChecksum_ne (enc enc' : Encoding) (hrp : String) (data : List Nat)
    (hne : enc ≠ enc') (hhrp : hrpValid hrp = true) (hdata : ∀ v ∈ data, v < 32) :
    verifyChecksum hrp (data ++ createChecksum enc hrp data) ≠ some enc' := by
  intro h
  have hh := verifyChecksum_createChecksum enc hrp data hhrp hdata
  rw [hh] at h
  injection h with he
  exact hne he

theorem bech32Decode_encode_ne (enc enc' : Encoding) (hrp : String) (data : List Nat)
    (s : String) (limit : Nat) (hne : enc ≠ enc')
    (henc : bech32Encode enc hrp data = .ok s)
    (hlimit : s.toList.length ≤ limit) :
    bech32Decode s limit ≠ .ok ⟨enc', hrp, data⟩ := by
  intro h
  have hh := bech32Decode_encode enc hrp data s limit henc hlimit
  rw [hh] at h
  have he : enc = enc' := by
    injection h with hs
    cases hs
    rfl
  exact hne he

theorem checkCharacters_mixed_of_both (cs : List Char)
    (hprint : ∀ c ∈ cs, 33 ≤ c.toNat ∧ c.toNat ≤ 126)
    (hlower : ∃ c ∈ cs, isLowerChar c = true)
    (hupper : ∃ c ∈ cs, isUpperChar c = true) :
    checkCharacters cs = some .mixedCase := by
  unfold checkCharacters
  exact checkCharacters_go_mixed_of_both cs 0 false false hprint
    (Or.inr (Or.inr ⟨hlower, hupper⟩))

theorem bech32Decode_mixedCase (s : String) (limit : Nat)
    (hprint : ∀ c ∈ s.toList, 33 ≤ c.toNat ∧ c.toNat ≤ 126)
    (hlower : ∃ c ∈ s.toList, isLowerChar c = true)
    (hupper : ∃ c ∈ s.toList, isUpperChar c = true) :
    bech32Decode s limit = .error .mixedCase := by
  dsimp only [bech32Decode]
  rw [checkCharacters_mixed_of_both s.toList hprint hlower hupper]

theorem decodeSegwit_v0_bech32m (hrp : String) (tail : List Nat) (s : String)
    (henc : bech32Encode .bech32m hrp (0 :: tail) = .ok s)
    (hlimit : s.toList.length ≤ 90) :
    decodeSegwit hrp s = .error (.wrongEncoding 0 .bech32m) := by
  unfold decodeSegwit
  rw [bech32Decode_encode .bech32m hrp (0 :: tail) s 90 henc hlimit]
  simp only []
  simp

theorem decodeSegwit_v1_bech32 (hrp : String) (tail : List Nat) (s : String)
    (henc : bech32Encode .bech32 hrp (1 :: tail) = .ok s)
    (hlimit : s.toList.length ≤ 90) :
    decodeSegwit hrp s = .error (.wrongEncoding 1 .bech32) := by
  unfold decodeSegwit
  rw [bech32Decode_encode .bech32 hrp (1 :: tail) s 90 henc hlimit]
  simp only []
  simp


private def hexDigit (c : Char) : Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then n - 48
  else if 97 ≤ n ∧ n ≤ 102 then n - 87
  else if 65 ≤ n ∧ n ≤ 70 then n - 55
  else 0

private def hexBytes (s : String) : ByteArray :=
  let rec go : List Char → ByteArray → ByteArray
    | a :: b :: rest, acc =>
        go rest (acc.push ((hexDigit a * 16 + hexDigit b).toUInt8))
    | _, acc => acc
  go s.toList ByteArray.empty

def wpV0P2WPKH : WitnessProgram :=
  ⟨0, hexBytes "751e76e8199196d454941c45d1b3a323f1433bd6"⟩

def wpV0P2WSH : WitnessProgram :=
  ⟨0, hexBytes "1863143c14c5166804bd19203356da136c985678cd4d27a1b8c6329604903262"⟩

def wpV1Taproot : WitnessProgram :=
  ⟨1, hexBytes "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"⟩

theorem wpV0P2WPKH_size : wpV0P2WPKH.program.size = 20 := by decide
theorem wpV0P2WSH_size : wpV0P2WSH.program.size = 32 := by decide
theorem wpV1Taproot_size : wpV1Taproot.program.size = 32 := by decide

theorem encode_v0_20 :
    encodeSegwit "bc" wpV0P2WPKH = .ok "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4" := by
  with_unfolding_all rfl

theorem decode_v0_20 :
    decodeSegwit "bc" "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4" = .ok wpV0P2WPKH := by
  with_unfolding_all rfl

theorem encode_v0_32 :
    encodeSegwit "tb" wpV0P2WSH = .ok "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7" := by
  with_unfolding_all rfl

theorem decode_v0_32 :
    decodeSegwit "tb" "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7" = .ok wpV0P2WSH := by
  with_unfolding_all rfl

theorem encode_v1_32 :
    encodeSegwit "bc" wpV1Taproot = .ok "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0" := by
  with_unfolding_all rfl

theorem decode_v1_32 :
    decodeSegwit "bc" "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0" = .ok wpV1Taproot := by
  with_unfolding_all rfl

/-! The three concrete BIP173/BIP350 round-trips.  These are instantiations
of the address layer on the official vectors, not a claim that
`dataToBytes (bytesToData p) = some p` holds for every `p`; the generic
`ConvertBits` inverse is left open (see the module report). -/

theorem roundtrip_v0_20 (s : String) (h : encodeSegwit "bc" wpV0P2WPKH = .ok s) :
    decodeSegwit "bc" s = .ok wpV0P2WPKH := by
  rw [encode_v0_20] at h
  cases h
  exact decode_v0_20

theorem roundtrip_v0_32 (s : String) (h : encodeSegwit "tb" wpV0P2WSH = .ok s) :
    decodeSegwit "tb" s = .ok wpV0P2WSH := by
  rw [encode_v0_32] at h
  cases h
  exact decode_v0_32

theorem roundtrip_v1_32 (s : String) (h : encodeSegwit "bc" wpV1Taproot = .ok s) :
    decodeSegwit "bc" s = .ok wpV1Taproot := by
  rw [encode_v1_32] at h
  cases h
  exact decode_v1_32

theorem wp_sizes : wpV0P2WPKH.program.size = 20 ∧
    wpV0P2WSH.program.size = 32 ∧ wpV1Taproot.program.size = 32 :=
  ⟨wpV0P2WPKH_size, wpV0P2WSH_size, wpV1Taproot_size⟩

end BitcoinProofs.Wallet.Encoding.Bech32Props
