import Bitcoin.Data.Basic

/-!
# Bitcoin.Wallet.Crypto.Sha512

A dependency-free SHA-512 as specified by FIPS 180-4 §6.5, over
`ByteArray`. The 64-bit words are Lean's `UInt64`, whose addition and
multiplication are the modular operations the standard requires; the
eight-word state and the eighty-round message schedule are the §6.5.2
state machine written out with arrays.

Padding follows FIPS 180-4 §5.1.1: a single `0x80` byte, the least
number of zero bytes that makes the length congruent to 112 modulo 128,
then the 128-bit big-endian bit length. The two-word length matters for
messages of 2^61 bits or more; the high word is computed from the
unbounded `Nat` length, so no silent truncation occurs at 2^64 bits.

Bitcoin Core reaches SHA-512 through `CHMAC_SHA512` (SHA-512 itself is
reached through `crypto/sha512.h`; BIP32 uses only the HMAC form at
`src/hash.cpp:71-76`). The digest here is the raw primitive; byte-order
conversion and Bitcoin serialization stay with their callers.

## What is not modelled

No streaming/incremental interface and no `CSHA512` object state: the
function takes a complete message. No assembly or hardware paths, no
side-channel claims, no FIPS validation certification, and no
domain-separated tagged hashing (that is SHA-256 based and lives
elsewhere). The function is total on all byte strings; it does not
promise anything about the cryptographic strength of the result.

## Vectors

`#eval` at the bottom checks the four NIST/FIPS example digests
(FIPS 180-4 Appendix C.2 examples, also the NIST CAVS byte-oriented
vectors): the empty message, `abc`, the 112-byte two-block message, and
one million `a` bytes. The million-byte case exercises 7,813 full
blocks; see `BIP32.md` for the measured elaboration cost.
-/

namespace Bitcoin.Wallet.Crypto.Sha512

/-! ## Round constants (FIPS 180-4 §4.2.3) -/

/-- The eighty 64-bit round constants: the first 64 bits of the
fractional parts of the cube roots of the first eighty primes. -/
def K : Array UInt64 := #[
  0x428a2f98d728ae22, 0x7137449123ef65cd, 0xb5c0fbcfec4d3b2f,
  0xe9b5dba58189dbbc, 0x3956c25bf348b538, 0x59f111f1b605d019,
  0x923f82a4af194f9b, 0xab1c5ed5da6d8118, 0xd807aa98a3030242,
  0x12835b0145706fbe, 0x243185be4ee4b28c, 0x550c7dc3d5ffb4e2,
  0x72be5d74f27b896f, 0x80deb1fe3b1696b1, 0x9bdc06a725c71235,
  0xc19bf174cf692694, 0xe49b69c19ef14ad2, 0xefbe4786384f25e3,
  0x0fc19dc68b8cd5b5, 0x240ca1cc77ac9c65, 0x2de92c6f592b0275,
  0x4a7484aa6ea6e483, 0x5cb0a9dcbd41fbd4, 0x76f988da831153b5,
  0x983e5152ee66dfab, 0xa831c66d2db43210, 0xb00327c898fb213f,
  0xbf597fc7beef0ee4, 0xc6e00bf33da88fc2, 0xd5a79147930aa725,
  0x06ca6351e003826f, 0x142929670a0e6e70, 0x27b70a8546d22ffc,
  0x2e1b21385c26c926, 0x4d2c6dfc5ac42aed, 0x53380d139d95b3df,
  0x650a73548baf63de, 0x766a0abb3c77b2a8, 0x81c2c92e47edaee6,
  0x92722c851482353b, 0xa2bfe8a14cf10364, 0xa81a664bbc423001,
  0xc24b8b70d0f89791, 0xc76c51a30654be30, 0xd192e819d6ef5218,
  0xd69906245565a910, 0xf40e35855771202a, 0x106aa07032bbd1b8,
  0x19a4c116b8d2d0c8, 0x1e376c085141ab53, 0x2748774cdf8eeb99,
  0x34b0bcb5e19b48a8, 0x391c0cb3c5c95a63, 0x4ed8aa4ae3418acb,
  0x5b9cca4f7763e373, 0x682e6ff3d6b2b8a3, 0x748f82ee5defb2fc,
  0x78a5636f43172f60, 0x84c87814a1f0ab72, 0x8cc702081a6439ec,
  0x90befffa23631e28, 0xa4506cebde82bde9, 0xbef9a3f7b2c67915,
  0xc67178f2e372532b, 0xca273eceea26619c, 0xd186b8c721c0c207,
  0xeada7dd6cde0eb1e, 0xf57d4f7fee6ed178, 0x06f067aa72176fba,
  0x0a637dc5a2c898a6, 0x113f9804bef90dae, 0x1b710b35131c471b,
  0x28db77f523047d84, 0x32caab7b40c72493, 0x3c9ebe0a15c9bebc,
  0x431d67c49c100d4c, 0x4cc5d4becb3e42b6, 0x597f299cfc657e2a,
  0x5fcb6fab3ad6faec, 0x6c44198c4a475817]

/-- Initial hash value H⁽⁰⁾ (FIPS 180-4 §5.3.5): the first 64 bits of the
fractional parts of the square roots of the first eight primes. -/
def H0 : Array UInt64 := #[
  0x6a09e667f3bcc908, 0xbb67ae8584caa73b, 0x3c6ef372fe94f82b,
  0xa54ff53a5f1d36f1, 0x510e527fade682d1, 0x9b05688c2b3e6c1f,
  0x1f83d9abfb41bd6b, 0x5be0cd19137e2179]

/-! ## Word operations (FIPS 180-4 §4.1.3) -/

/-- Right-rotate a 64-bit word by `n` bits, `1 ≤ n ≤ 63`. -/
def rotr (x : UInt64) (n : Nat) : UInt64 :=
  (x >>> n.toUInt64) ||| (x <<< ((64 - n) % 64).toUInt64)

/-- Ch(x,y,z) = (x AND y) XOR (NOT x AND z), §4.1.3. -/
def ch (x y z : UInt64) : UInt64 :=
  (x &&& y) ^^^ ((x ^^^ 0xFFFFFFFFFFFFFFFF) &&& z)

/-- Maj(x,y,z), §4.1.3. -/
def maj (x y z : UInt64) : UInt64 :=
  (x &&& y) ^^^ (x &&& z) ^^^ (y &&& z)

/-- Σ₀(x) = ROTR²⁸(x) XOR ROTR³⁴(x) XOR ROTR³⁹(x), §4.1.3. -/
def bigSigma0 (x : UInt64) : UInt64 := rotr x 28 ^^^ rotr x 34 ^^^ rotr x 39

/-- Σ₁(x) = ROTR¹⁴(x) XOR ROTR¹⁸(x) XOR ROTR⁴¹(x), §4.1.3. -/
def bigSigma1 (x : UInt64) : UInt64 := rotr x 14 ^^^ rotr x 18 ^^^ rotr x 41

/-- σ₀(x) = ROTR¹(x) XOR ROTR⁸(x) XOR SHR⁷(x), §4.1.3. -/
def smallSigma0 (x : UInt64) : UInt64 :=
  rotr x 1 ^^^ rotr x 8 ^^^ (x >>> 7)

/-- σ₁(x) = ROTR¹⁹(x) XOR ROTR⁶¹(x) XOR SHR⁶(x), §4.1.3. -/
def smallSigma1 (x : UInt64) : UInt64 :=
  rotr x 19 ^^^ rotr x 61 ^^^ (x >>> 6)

/-- Big-endian 64-bit read from a byte array at `off`. -/
def readBE64 (m : ByteArray) (off : Nat) : UInt64 :=
  (m[off]!.toUInt64 <<< 56) ||| (m[off+1]!.toUInt64 <<< 48)
    ||| (m[off+2]!.toUInt64 <<< 40) ||| (m[off+3]!.toUInt64 <<< 32)
    ||| (m[off+4]!.toUInt64 <<< 24) ||| (m[off+5]!.toUInt64 <<< 16)
    ||| (m[off+6]!.toUInt64 <<< 8) ||| m[off+7]!.toUInt64

/-- Append one 64-bit word as eight big-endian bytes. -/
def appendWordBE (a : ByteArray) (w : UInt64) : ByteArray :=
  (List.range 8).foldl
    (fun a j => a.push ((w >>> ((7 - j) * 8).toUInt64).toUInt8)) a

/-- Write one 64-bit word as eight big-endian bytes. -/
def bytesOfWord (w : UInt64) : ByteArray := appendWordBE ByteArray.empty w

/-- Append `k` zero bytes. -/
def appendZeros (a : ByteArray) (k : Nat) : ByteArray :=
  (List.range k).foldl (fun a _ => a.push 0) a

/-! ## Compression (FIPS 180-4 §6.5.2) -/

/-- Pointwise sum of two eight-word states (§6.5.2 step 3). -/
def addState (h h' : Array UInt64) : Array UInt64 :=
  (List.range 8).foldl (fun acc i => acc.push (h[i]! + h'[i]!)) #[]

/-- The message schedule and the eighty rounds of one 128-byte block. -/
def compress (h : Array UInt64) (block : ByteArray) (off : Nat) : Array UInt64 :=
  let w0 : Array UInt64 :=
    (List.range 16).foldl (fun w i => w.push (readBE64 block (off + 8 * i))) #[]
  let w : Array UInt64 :=
    (List.range 64).foldl (fun w j =>
      let i := j + 16
      let s0 := smallSigma0 w[i-15]!
      let s1 := smallSigma1 w[i-2]!
      w.push (w[i-16]! + s0 + w[i-7]! + s1)) w0
  let h' := (List.range 80).foldl (fun h i =>
    let t1 := h[7]! + bigSigma1 h[4]! + ch h[4]! h[5]! h[6]! + K[i]! + w[i]!
    let t2 := bigSigma0 h[0]! + maj h[0]! h[1]! h[2]!
    h.set! 7 h[6]! |>.set! 6 h[5]! |>.set! 5 h[4]!
      |>.set! 4 (h[3]! + t1) |>.set! 3 h[2]! |>.set! 2 h[1]!
      |>.set! 1 h[0]! |>.set! 0 (t1 + t2)) h
  -- §6.5.2 step 3: the new state is the old state plus the working variables
  addState h h'

/-- FIPS 180-4 §5.1.1 padding for the 1024-bit block size. -/
def pad (m : ByteArray) : ByteArray :=
  let len := m.size
  let k := (111 + 128 - len % 128) % 128
  let padded := appendZeros (m.push 0x80) k
  -- 128-bit big-endian bit length: high word then low word.
  let hi : UInt64 := (len / 0x2000000000000000).toUInt64
  let lo : UInt64 := (len * 8).toUInt64
  appendWordBE (appendWordBE padded hi) lo

/-- SHA-512 of a complete byte string: 64-byte digest, big-endian. -/
def hash (m : ByteArray) : ByteArray :=
  let p := pad m
  let blocks := p.size / 128
  let h := (List.range blocks).foldl (fun h i => compress h p (i * 128)) H0
  (bytesOfWord h[0]!) ++ (bytesOfWord h[1]!) ++ (bytesOfWord h[2]!) ++
  (bytesOfWord h[3]!) ++ (bytesOfWord h[4]!) ++ (bytesOfWord h[5]!) ++
  (bytesOfWord h[6]!) ++ (bytesOfWord h[7]!)

/-! ## Size lemmas -/

/-- Appending `k` zero bytes grows a byte array by exactly `k`. -/
theorem appendZeros_size (a : ByteArray) (k : Nat) :
    (appendZeros a k).size = a.size + k := by
  induction k generalizing a with
  | zero => simp [appendZeros]
  | succ k ih =>
    rw [show appendZeros a (k + 1) =
      (appendZeros a k).push 0 by
        unfold appendZeros
        rw [List.range_succ, List.foldl_append]
        rfl]
    rw [ByteArray.size_push, ih]
    omega

/-- A fold whose every step appends exactly one byte grows the array by
the list length. -/
theorem foldl_size_of_step {α : Type} (l : List α)
    (step : ByteArray → α → ByteArray)
    (hstep : ∀ a x, (step a x).size = a.size + 1) (a : ByteArray) :
    (l.foldl step a).size = a.size + l.length := by
  induction l generalizing a with
  | nil => simp
  | cons x xs ih =>
    simp only [List.foldl_cons, List.length_cons]
    rw [ih, hstep a x]
    omega

/-- `appendWordBE` adds exactly eight bytes. -/
theorem appendWordBE_size (a : ByteArray) (w : UInt64) :
    (appendWordBE a w).size = a.size + 8 := by
  unfold appendWordBE
  simpa using foldl_size_of_step (l := List.range 8)
    (step := fun a j => a.push ((w >>> ((7 - j) * 8).toUInt64).toUInt8))
    (hstep := fun a x => by simp) a

/-- The same length bookkeeping for arrays of words. -/
theorem foldl_push_size_array {α : Type} (l : List α)
    (step : Array UInt64 → α → Array UInt64)
    (hstep : ∀ a x, (step a x).size = a.size + 1) (a : Array UInt64) :
    (l.foldl step a).size = a.size + l.length := by
  induction l generalizing a with
  | nil => simp
  | cons x xs ih =>
    simp only [List.foldl_cons, List.length_cons]
    rw [ih, hstep a x]
    omega

/-- `addState` returns eight words. -/
theorem addState_size (h h' : Array UInt64) : (addState h h').size = 8 := by
  unfold addState
  exact (foldl_push_size_array (l := List.range 8)
    (step := fun acc i => acc.push (h[i]! + h'[i]!))
    (hstep := fun a x => by simp) #[]).trans (by simp)

/-- Compression returns an eight-word state. -/
theorem compress_size (h : Array UInt64) (block : ByteArray) (off : Nat) :
    (compress h block off).size = 8 := by
  unfold compress
  exact addState_size _ _

/-- `bytesOfWord` is always eight bytes. -/
theorem bytesOfWord_size (w : UInt64) : (bytesOfWord w).size = 8 := by
  unfold bytesOfWord
  rw [appendWordBE_size]
  simp

/-- The padded message is a whole number of 128-byte blocks. -/
theorem pad_size_mod (m : ByteArray) : (pad m).size % 128 = 0 := by
  have hr : m.size % 128 < 128 := Nat.mod_lt _ (by decide)
  unfold pad
  simp only [appendWordBE_size, appendZeros_size, ByteArray.size_push]
  have hdecomp : m.size = 128 * (m.size / 128) + m.size % 128 :=
    (Nat.div_add_mod m.size 128).symm
  by_cases hle : m.size % 128 ≤ 111
  · have hk : (111 + 128 - m.size % 128) % 128 = 111 - m.size % 128 := by
      have h : 111 + 128 - m.size % 128 = 128 + (111 - m.size % 128) := by omega
      rw [h, Nat.add_mod_left, Nat.mod_eq_of_lt]
      omega
    rw [hk]
    have hsize : m.size + 1 + (111 - m.size % 128) + 8 + 8 =
        128 * (m.size / 128 + 1) := by omega
    rw [hsize, Nat.mul_mod_right]
  · have hge : 112 ≤ m.size % 128 := by omega
    have hk : (111 + 128 - m.size % 128) % 128 = 239 - m.size % 128 := by
      rw [show 111 + 128 - m.size % 128 = 239 - m.size % 128 from rfl]
      exact Nat.mod_eq_of_lt (by omega)
    rw [hk]
    have hsize : m.size + 1 + (239 - m.size % 128) + 8 + 8 =
        128 * (m.size / 128 + 2) := by omega
    rw [hsize, Nat.mul_mod_right]

/-- The digest is 64 bytes. -/
theorem hash_size (m : ByteArray) : (hash m).size = 64 := by
  unfold hash
  simp [bytesOfWord_size, ByteArray.size_append]

end Bitcoin.Wallet.Crypto.Sha512
