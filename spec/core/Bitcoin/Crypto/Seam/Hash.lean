import Bitcoin.Data.Basic

/-!
# Bitcoin.Crypto.Seam.Hash — the verified hash floor

## Provenance

* **SHA-256**: verbatim port of the zero-dependency prototype PoC
  (the SHA-256 prototype, namespace renamed; 9/9 FIPS
  180-4 + Bitcoin vectors verified against `python3 hashlib`
  and the genesis header dsha256 — see `Test/Crypto/SeamHashTest.lean`).
  Chosen over `fips-180-4-lean` (GPL-3.0) per DECISIONS.md D-003 /
  OPEN-001; license-clean for this repo.
* **RIPEMD-160**: clean-room implementation (nothing in-repo existed).
  Ported from the spec tables (Bosselaers/Dobbertin/Preneel reference
  implementation), cross-checked against Bitcoin Core's test-only
  `test/functional/test_framework/ripemd160.py` (MIT, Pieter Wuille)
  and `python3 hashlib.new('ripemd160')`; 5/5 official vectors.

Both hashers are `UInt32`/`ByteArray`-based, dependency-free, and
compile to plain structured folds (no well-founded recursion), so the
kernel can `decide` small vectors.

Traceability: Bitcoin Core `hash.h` (CHash256 / CHash160),
`crypto/sha256.cpp`, `crypto/ripemd160.cpp`.
-/

namespace Bitcoin.Crypto.Seam.Hash

namespace Sha256

/-! ## SHA-256 (FIPS 180-4 §6.2) — vendored from the prototype's PoC -/

/-- Round constants, FIPS 180-4 §4.2.2. -/
def K : Array UInt32 := #[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]

/-- Initial hash values, FIPS 180-4 §5.3.3. -/
def H0 : Array UInt32 := #[
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]

/-- Right-rotate (FIPS 180-4 §4.1.2 ROTR^n(x)). -/
def rotr (x : UInt32) (n : Nat) : UInt32 :=
  (x >>> n.toUInt32) ||| (x <<< ((32 - n) % 32).toUInt32)

/-- Ch(x,y,z) = (x AND y) XOR (NOT x AND z), FIPS 180-4 §4.1.2. -/
def ch (x y z : UInt32) : UInt32 := (x &&& y) ^^^ ((x ^^^ 0xFFFFFFFF) &&& z)

/-- Maj(x,y,z), FIPS 180-4 §4.1.2. -/
def maj (x y z : UInt32) : UInt32 := (x &&& y) ^^^ (x &&& z) ^^^ (y &&& z)

/-- Σ0, FIPS 180-4 §4.1.2 (SHA-256). -/
def bigSigma0 (x : UInt32) : UInt32 := rotr x 2 ^^^ rotr x 13 ^^^ rotr x 22

/-- Σ1. -/
def bigSigma1 (x : UInt32) : UInt32 := rotr x 6 ^^^ rotr x 11 ^^^ rotr x 25

/-- σ0. -/
def smallSigma0 (x : UInt32) : UInt32 := rotr x 7 ^^^ rotr x 18 ^^^ (x >>> 3)

/-- σ1. -/
def smallSigma1 (x : UInt32) : UInt32 := rotr x 17 ^^^ rotr x 19 ^^^ (x >>> 10)

/-- Big-endian 32-bit read from a ByteArray block. -/
def readBE32 (m : ByteArray) (off : Nat) : UInt32 :=
  (m[off]!.toUInt32 <<< 24) ||| (m[off+1]!.toUInt32 <<< 16)
    ||| (m[off+2]!.toUInt32 <<< 8) ||| m[off+3]!.toUInt32

/--
Message-schedule + compression of one 64-byte block (FIPS 180-4 §6.2.2),
mutating the 8-word state. This is the "SHA256Transform" analogue
(cf. Bitcoin Core sha256.cpp `sha256_compress` / SHA256Transform).
-/
def processBlock (h : Array UInt32) (block : ByteArray) (off : Nat) : Array UInt32 :=
  -- Message schedule W[0..63] (§6.2.2 step 1).
  let w : Array UInt32 :=
    (List.range 64).foldl (fun w i =>
      if i < 16 then
        w.push (readBE32 block (off + 4*i))
      else
        let s0 := smallSigma0 w[i-15]!
        let s1 := smallSigma1 w[i-2]!
        w.push (w[i-16]! + s0 + w[i-7]! + s1)) #[]
  -- 64 rounds (§6.2.2 steps 2-4).
  (List.range 64).foldl (fun h i =>
    let S1 := bigSigma1 h[4]!
    let t1 := h[7]! + S1 + ch h[4]! h[5]! h[6]! + K[i]! + w[i]!
    let S0 := bigSigma0 h[0]!
    let t2 := S0 + maj h[0]! h[1]! h[2]!
    h.set! 7 h[6]! |>.set! 6 h[5]! |>.set! 5 h[4]!
      |>.set! 4 (h[3]! + t1) |>.set! 3 h[2]! |>.set! 2 h[1]!
      |>.set! 1 h[0]! |>.set! 0 (t1 + t2)) h

/--
Padding (FIPS 180-4 §5.1.1): append 0x80, zeros, then the 64-bit big-endian
bit length, so the total is a multiple of 64.
-/
def pad (m : ByteArray) : ByteArray :=
  let len := m.size
  -- zero bytes so that (len%64 + 1 + k + 8) % 64 == 0 (FIPS 180-4 §5.1.1)
  let k := (55 + 64 - len % 64) % 64
  let padded := m.push 0x80
  let padded := (List.range k).foldl (fun a _ => a.push 0) padded
  let bits : UInt64 := (len.toUInt64) * 8
  let padded := (List.range 8).foldl (fun a i =>
      a.push ((bits >>> ((7 - i) * 8).toUInt64).toUInt8)) padded
  padded

/--
Full SHA-256 (FIPS 180-4 §6.2.3): iterate compression over padded blocks,
add the working state into the intermediate hash.
-/
def compressLoop (m : ByteArray) : Array UInt32 :=
  let nblocks := m.size / 64
  (List.range nblocks).foldl
    (fun h i =>
      let h' := processBlock h m (64 * i)
      -- Add the compressed chunk of this block into the state (§6.2.2 step 6).
      (Array.range 8).map (fun j => h[j]! + h'[j]!)) H0

/-- SHA-256 digest as a 32-byte ByteArray (big-endian concat of H0..H7). -/
def sha256 (m : ByteArray) : ByteArray :=
  let h := compressLoop (pad m)
  (List.range 32).foldl (fun a i =>
      let v := h[i / 4]!
      a.push ((v >>> ((3 - i % 4) * 8).toUInt32).toUInt8)) {}

/--
The padded length is always a positive multiple of the 64-byte block size
(FIPS 180-4 §5.1.1 requires `len + 1 + k + 8 ≡ 0 (mod 64)` with `0 ≤ k < 64`).
PROVED, not tested — this discharges the padding-length side condition that
`compressLoop`'s `m.size / 64` relies on being exact.
(the prototype's `pad_size_multiple`, ported verbatim.)
-/
theorem pad_size_multiple (n : Nat) : (n % 64 + 1 + ((55 + 64 - n % 64) % 64) + 8) % 64 = 0 := by
  omega

end Sha256

namespace Ripemd160

/-! ## RIPEMD-160 (Dobbertin, Bosselaers, Preneel) — clean-room the seam layer -/

/-- Left-rotate by `n` bits (n taken mod 32). -/
def rol (x : UInt32) (n : Nat) : UInt32 :=
  (x <<< n.toUInt32) ||| (x >>> ((32 - n) % 32).toUInt32)

/-- Message-word selection, left line (80 entries). -/
def rL : Array Nat := #[
  0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
  7,4,13,1,10,6,15,3,12,0,9,5,2,14,11,8,
  3,10,14,4,9,15,8,1,2,7,0,6,13,11,5,12,
  1,9,11,10,0,8,12,4,13,3,7,15,14,5,6,2,
  4,0,5,9,7,12,2,10,14,1,3,8,11,6,15,13]

/-- Message-word selection, right line (80 entries). -/
def rR : Array Nat := #[
  5,14,7,0,9,2,11,4,13,6,15,8,1,10,3,12,
  6,11,3,7,0,13,5,10,14,15,8,12,4,9,1,2,
  15,5,1,3,7,14,6,9,11,8,12,2,10,0,4,13,
  8,6,4,1,3,11,15,0,5,12,2,13,9,7,10,14,
  12,15,10,4,1,5,8,7,6,2,13,14,0,3,9,11]

/-- Rotations, left line (80 entries). -/
def sL : Array Nat := #[
  11,14,15,12,5,8,7,9,11,13,14,15,6,7,9,8,
  7,6,8,13,11,9,7,15,7,12,15,9,11,7,13,12,
  11,13,6,7,14,9,13,15,14,8,13,6,5,12,7,5,
  11,12,14,15,14,15,9,8,9,14,5,6,8,6,5,12,
  9,15,5,11,6,8,13,12,5,12,13,14,11,8,5,6]

/-- Rotations, right line (80 entries). -/
def sR : Array Nat := #[
  8,9,9,11,13,15,15,5,7,7,8,11,14,14,12,6,
  9,13,15,7,12,8,9,11,7,7,12,7,6,15,13,11,
  9,7,15,11,8,6,6,14,12,13,5,14,13,13,7,5,
  15,5,8,11,14,14,6,14,6,9,12,9,12,5,15,8,
  8,5,12,9,12,5,14,6,8,13,6,5,15,13,11,11]

/-- Round constants: left line. -/
def kL : Array UInt32 := #[0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E]

/-- Round constants: right line. -/
def kR : Array UInt32 := #[0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000]

/-- The five boolean round functions f1..f5, indexed by round group 0..4
(f = j/16 on the left line, f = 4 - j/16 on the right line). -/
def f (grp : Nat) (x y z : UInt32) : UInt32 :=
  match grp with
  | 0 => x ^^^ y ^^^ z
  | 1 => (x &&& y) ||| ((x ^^^ 0xFFFFFFFF) &&& z)
  | 2 => (x ||| (y ^^^ 0xFFFFFFFF)) ^^^ z
  | 3 => (x &&& z) ||| (y &&& (z ^^^ 0xFFFFFFFF))
  | _ => x ^^^ (y ||| (z ^^^ 0xFFFFFFFF))

/-- Round group of step `j` (16 steps per group, 5 groups, 80 steps). -/
def grpOf (j : Nat) : Nat := j / 16

/-- Little-endian 32-bit read (RIPEMD-160 is little-endian). -/
def readLE32 (m : ByteArray) (off : Nat) : UInt32 :=
  (m[off]!.toUInt32) ||| ((m[off+1]!.toUInt32) <<< 8)
    ||| ((m[off+2]!.toUInt32) <<< 16) ||| ((m[off+3]!.toUInt32) <<< 24)

/-- Padding: 0x80, zeros, 64-bit LITTLE-endian bit length (same length
arithmetic as SHA-256's; spec §3.1). -/
def pad (m : ByteArray) : ByteArray :=
  let len := m.size
  let k := (55 + 64 - len % 64) % 64
  let padded := m.push 0x80
  let padded := (List.range k).foldl (fun a _ => a.push 0) padded
  let bits : UInt64 := (len.toUInt64) * 8
  let padded := (List.range 8).foldl (fun a i =>
      a.push ((bits >>> (i * 8).toUInt64).toUInt8)) padded
  padded

/-- Left line running state. -/
abbrev Line5 := UInt32 × UInt32 × UInt32 × UInt32 × UInt32

/-- One 64-byte block: 80 parallel steps of the two lines, then the
combine step (spec §3.4: T = h1 + cl + dr, etc.). -/
def compressBlock (h : Array UInt32) (m : ByteArray) (off : Nat) : Array UInt32 :=
  let x : Array UInt32 := (List.range 16).foldl (fun x i => x.push (readLE32 m (off + 4*i))) #[]
  let st : Line5 × Line5 :=
    (List.range 80).foldl (fun st j =>
      let (a, b, c, d, e) := st.1
      let (a', b', c', d', e') := st.2
      -- left line step
      let t := (rol (a + f (grpOf j) b c d + x[rL[j]!]! + kL[grpOf j]!) (sL[j]!)) + e
      -- right line step (f-index mirrored: 4 - grp)
      let t' := (rol (a' + f (4 - grpOf j) b' c' d' + x[rR[j]!]! + kR[grpOf j]!) (sR[j]!)) + e'
      ((e, t, b, rol c 10, d), (e', t', b', rol c' 10, d')))
      ((h[0]!, h[1]!, h[2]!, h[3]!, h[4]!), (h[0]!, h[1]!, h[2]!, h[3]!, h[4]!))
  let (al, bl, cl, dl, el) := st.1
  let (ar, br, cr, dr, er) := st.2
  #[h[1]! + cl + dr, h[2]! + dl + er, h[3]! + el + ar, h[4]! + al + br, h[0]! + bl + cr]

/-- Compression over the padded message. -/
def compress (m : ByteArray) : Array UInt32 :=
  let nblocks := m.size / 64
  (List.range nblocks).foldl (fun h b => compressBlock h m (64 * b))
    #[0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]

/-- RIPEMD-160 digest as a 20-byte ByteArray (little-endian concat). -/
def ripemd160 (m : ByteArray) : ByteArray :=
  let h := compress (pad m)
  (List.range 20).foldl (fun a i =>
      let v := h[i / 4]!
      a.push ((v >>> ((i % 4) * 8).toUInt32).toUInt8)) {}

end Ripemd160

/-! ## The seam-level composite hashes (hash.h) -/

/-- SHA-256 doubled — Core `hash.h` `CHash256::Finalize`:
`SHA256(SHA256(x))` written midstate-optimized there; the composition is
the same function. -/
def sha256d (m : ByteArray) : ByteArray := Sha256.sha256 (Sha256.sha256 m)

/-- RIPEMD-160(SHA-256(x)) — Core `hash.h` `CHash160`. -/
def hash160 (m : ByteArray) : ByteArray := Ripemd160.ripemd160 (Sha256.sha256 m)

/-! ## Digest-size contract (B5: 32-byte dsha256, 20-byte hash160) -/

/-- The 32-fold digest assembly always appends exactly one byte per step. -/
theorem foldl_push_size {g : Nat → UInt8} :
    ∀ (l : List Nat) (a : ByteArray),
      (l.foldl (fun (acc : ByteArray) (i : Nat) => acc.push (g i)) a).size = a.size + l.length := by
  intro l
  induction l with
  | nil => intro a; rfl
  | cons i l ih =>
      intro a
      have hstep : ((i :: l).foldl (fun (acc : ByteArray) (j : Nat) => acc.push (g j)) a)
          = (l.foldl (fun (acc : ByteArray) (j : Nat) => acc.push (g j)) (a.push (g i))) := rfl
      have hlen : (i :: l).length = l.length + 1 := rfl
      rw [hstep, ih, ByteArray.size_push, hlen]
      omega

/-- SHA-256 always returns exactly 32 bytes (FIPS 180-4 §6.2). -/
theorem sha256_size (m : ByteArray) : (Sha256.sha256 m).size = 32 := by
  unfold Sha256.sha256
  rw [foldl_push_size]
  simp

/-- RIPEMD-160 always returns exactly 20 bytes. -/
theorem ripemd160_size (m : ByteArray) : (Ripemd160.ripemd160 m).size = 20 := by
  unfold Ripemd160.ripemd160
  rw [foldl_push_size]
  simp

/-- dsha256 is 32 bytes (B5 seam contract). -/
theorem sha256d_size (m : ByteArray) : (sha256d m).size = 32 := by
  unfold sha256d; exact sha256_size _

/-- hash160 is 20 bytes (B5 seam contract). -/
theorem hash160_size (m : ByteArray) : (hash160 m).size = 20 := by
  unfold hash160; exact ripemd160_size _

end Bitcoin.Crypto.Seam.Hash
