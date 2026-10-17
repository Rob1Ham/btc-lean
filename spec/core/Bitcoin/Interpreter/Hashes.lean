import Bitcoin.Data.Basic

/-!
# Bitcoin.Interpreter.Hashes — the interpreter's hash floor (W09)

Self-contained, kernel-decidable implementations of the hash primitives
the interpreter's crypto opcodes need:

* `hashSha256`    — FIPS 180-4 (OP_SHA256; composed into OP_HASH256 and
  the P2WSH witness-program check);
* `hashSha1`      — FIPS 180-4 (OP_SHA1);
* `hashRipemd160` — RIPEMD-160 (OP_RIPEMD160);
* `hashHash160`   — RIPEMD160(SHA256(x)) (OP_HASH160, P2WPKH program check).

Design notes:

* Word arithmetic over `UInt32` (wrapping `+`, `&&&`, `|||`, `~~~`,
  `<<<`, `>>>`); message blocks read from `ByteArray` by index — no
  `ByteArray.toList` in executable code, so everything reduces under
  `decide` for the small payloads the tests use.
* These are **interim implementations owned by the interpreter** (B2
  finding: the frozen W13 seam exposes only `sha256`/`sha256d`/
  `hash160` — not RIPEMD-160 or SHA-1, which OP_RIPEMD160/OP_SHA1
  need). When W13's verified hash floor lands, the five-line hash
  dispatch in `Defs.lean` (`hashForOp`) is the only call site to
  repoint (interface-change PR). Correctness is pinned by standard
  test vectors in `Test/Script/Interpreter/Tests.lean` (FIPS 180-4 +
  RIPEMD-160 appendix digests, cross-checked against Python
  `hashlib` in W09). The digest pins use `native_decide`: full
  block-compression is quadratic through the kernel's list-backed
  `Array`/`ByteArray` and exceeds `decide`'s heartbeat budget
  (cf. W05 codegen gotchas). Cheap corollaries (output length 32,
  etc.) are kernel-`decide`d.
-/

namespace Bitcoin.Interpreter

/-! ## Word helpers -/

/-- Rotate right (32-bit). `n` is taken mod 32 by the caller's usage
pattern; `n ≥ 32` is handled via the `32 - n % 32` idiom below. -/
def rotr32 (x : UInt32) (n : Nat) : UInt32 :=
  (x >>> (n % 32).toUInt32) ||| (x <<< ((32 - n % 32) % 32).toUInt32)

/-- Rotate left (32-bit). -/
def rotl32 (x : UInt32) (n : Nat) : UInt32 :=
  (x <<< (n % 32).toUInt32) ||| (x >>> ((32 - n % 32) % 32).toUInt32)

/-- Big-endian 32-bit word at byte offset `i` (caller ensures bounds). -/
def wordBE (b : ByteArray) (i : Nat) : UInt32 :=
  (b[i]!.toUInt32 <<< 24) ||| (b[i+1]!.toUInt32 <<< 16) |||
    (b[i+2]!.toUInt32 <<< 8) ||| b[i+3]!.toUInt32

/-- Little-endian 32-bit word at byte offset `i`. -/
def wordLE (b : ByteArray) (i : Nat) : UInt32 :=
  b[i]!.toUInt32 ||| (b[i+1]!.toUInt32 <<< 8) |||
    (b[i+2]!.toUInt32 <<< 16) ||| (b[i+3]!.toUInt32 <<< 24)

/-- Emit a word big-endian. -/
def wordBEEmit (x : UInt32) : ByteArray :=
  List.toByteArray [(x >>> 24).toUInt8, ((x >>> 16) &&& 0xFF).toUInt8,
    ((x >>> 8) &&& 0xFF).toUInt8, (x &&& 0xFF).toUInt8]

/-- Emit a word little-endian. -/
def wordLEEmitted (x : UInt32) : ByteArray :=
  List.toByteArray [(x &&& 0xFF).toUInt8, ((x >>> 8) &&& 0xFF).toUInt8,
    ((x >>> 16) &&& 0xFF).toUInt8, ((x >>> 24) &&& 0xFF).toUInt8]

/-- Merkle–Damgård padding: `0x80`, zeros to a 56 ≡ 4 (mod 64) boundary,
then the 8-byte bit length (`lenBE`: big-endian for SHA-1/SHA-256,
little-endian for RIPEMD-160). -/
def mdPad (data : ByteArray) (lenBE : Bool) : ByteArray :=
  let zeros := ((55 : Nat) + 64 - data.size % 64) % 64
  let bitLen := data.size * 8
  let lenBytes : ByteArray :=
    List.toByteArray ((List.range 8).map (fun i =>
      let sh := if lenBE then 8 * (7 - i) else 8 * i
      ((bitLen >>> sh) &&& 0xFF).toUInt8))
  data.push 0x80 ++ (List.replicate zeros 0).toByteArray ++ lenBytes

/-! ## SHA-256 (FIPS 180-4, interpreter.cpp OP_SHA256 via CSHA256) -/

def K256 : Array UInt32 := #[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]

/-- One SHA-256 compression step over the expanded schedule. -/
def sha256Round (i : Nat) (w : Array UInt32) (a b c d e f g h : UInt32) :
    UInt32 × UInt32 × UInt32 × UInt32 × UInt32 × UInt32 × UInt32 × UInt32 :=
  let s1 := rotr32 e 6 ^^^ rotr32 e 11 ^^^ rotr32 e 25
  let ch := (e &&& f) ^^^ (~~~e &&& g)
  let t1 := h + s1 + ch + K256[i]! + w[i]!
  let s0 := rotr32 a 2 ^^^ rotr32 a 13 ^^^ rotr32 a 22
  let maj := (a &&& b) ^^^ (a &&& c) ^^^ (b &&& c)
  let t2 := s0 + maj
  ((t1 + t2), a, b, c, (d + t1), e, f, g)

/-- Expand the 16-word block schedule to 64 words. -/
def sha256Schedule (block : ByteArray) (off : Nat) : Array UInt32 :=
  let w0 : Array UInt32 := (List.range 16).toArray.map (fun i => wordBE block (off + 4*i))
  (List.range 48).foldl (fun w _i =>
    let t := w.size
    let s0 := rotr32 w[t-15]! 7 ^^^ rotr32 w[t-15]! 18 ^^^ (w[t-15]! >>> 3)
    let s1 := rotr32 w[t-2]! 17 ^^^ rotr32 w[t-2]! 19 ^^^ (w[t-2]! >>> 10)
    w.push (w[t-16]! + s0 + w[t-7]! + s1)) w0

/-- One SHA-256 block compression (h state as 8-word Array). -/
def sha256Compress (h : Array UInt32) (block : ByteArray) (off : Nat) : Array UInt32 :=
  let w := sha256Schedule block off
  let fin := (List.range 64).foldl (fun acc i =>
      let (a, b, c, d, e, f, g, hh) := acc
      sha256Round i w a b c d e f g hh)
    (h[0]!, h[1]!, h[2]!, h[3]!, h[4]!, h[5]!, h[6]!, h[7]!)
  let (a, b, c, d, e, f, g, hh) := fin
  #[(h[0]! + a), (h[1]! + b), (h[2]! + c), (h[3]! + d),
    (h[4]! + e), (h[5]! + f), (h[6]! + g), (h[7]! + hh)]

/-- SHA-256 over `data` (bits = data.size * 8 fits comfortably in Nat). -/
def hashSha256 (data : ByteArray) : ByteArray :=
  let padded := mdPad data true
  let nblocks := padded.size / 64
  let h := (List.range nblocks).foldl (fun h i => sha256Compress h padded (64 * i))
    #[0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
      0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
  (List.range 8).foldl (fun acc i => acc ++ wordBEEmit h[i]!) ByteArray.empty

/-! ## SHA-1 (FIPS 180-4, OP_SHA1) -/

def sha1F (i : Nat) (b c d : UInt32) : UInt32 :=
  if i < 20 then (b &&& c) ||| (~~~b &&& d)
  else if i < 40 then b ^^^ c ^^^ d
  else if i < 60 then (b &&& c) ||| (b &&& d) ||| (c &&& d)
  else b ^^^ c ^^^ d

def sha1K (i : Nat) : UInt32 :=
  if i < 20 then 0x5A827999 else if i < 40 then 0x6ED9EBA1
  else if i < 60 then 0x8F1BBCDC else 0xCA62C1D6

def sha1Compress (h : Array UInt32) (block : ByteArray) (off : Nat) : Array UInt32 :=
  let w0 : Array UInt32 := (List.range 16).toArray.map (fun i => wordBE block (off + 4*i))
  let w := (List.range 64).foldl (fun w i =>
      w.push (rotl32 (w[i]! ^^^ w[i+2]! ^^^ w[i+8]! ^^^ w[i+13]!) 1)) w0
  let fin := (List.range 80).foldl (fun acc i =>
      let (a, b, c, d, e) := acc
      let t := rotl32 a 5 + sha1F i b c d + e + sha1K i + w[i]!
      (t, a, rotl32 b 30, c, d))
    (h[0]!, h[1]!, h[2]!, h[3]!, h[4]!)
  let (a, b, c, d, e) := fin
  #[(h[0]! + a), (h[1]! + b), (h[2]! + c), (h[3]! + d), (h[4]! + e)]

def hashSha1 (data : ByteArray) : ByteArray :=
  let padded := mdPad data true
  let nblocks := padded.size / 64
  let h := (List.range nblocks).foldl (fun h i => sha1Compress h padded (64 * i))
    #[0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]
  (List.range 5).foldl (fun acc i => acc ++ wordBEEmit h[i]!) ByteArray.empty

/-! ## RIPEMD-160 (OP_RIPEMD160; Dobbertin, Bosselaers, Preneel) -/

def RMD_R1 : Array Nat := #[
  0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
  7,4,13,1,10,6,15,3,12,0,9,5,2,14,11,8,
  3,10,14,4,9,15,8,1,2,7,0,6,13,11,5,12,
  1,9,11,10,0,8,12,4,13,3,7,15,14,5,6,2,
  4,0,5,9,7,12,2,10,14,1,3,8,11,6,15,13]
def RMD_R2 : Array Nat := #[
  5,14,7,0,9,2,11,4,13,6,15,8,1,10,3,12,
  6,11,3,7,0,13,5,10,14,15,8,12,4,9,1,2,
  15,5,1,3,7,14,6,9,11,8,12,2,10,0,4,13,
  8,6,4,1,3,11,15,0,5,12,2,13,9,7,10,14,
  12,15,10,4,1,5,8,7,6,2,13,14,0,3,9,11]
def RMD_S1 : Array Nat := #[
  11,14,15,12,5,8,7,9,11,13,14,15,6,7,9,8,
  7,6,8,13,11,9,7,15,7,12,15,9,11,7,13,12,
  11,13,6,7,14,9,13,15,14,8,13,6,5,12,7,5,
  11,12,14,15,14,15,9,8,9,14,5,6,8,6,5,12,
  9,15,5,11,6,8,13,12,5,12,13,14,11,8,5,6]
def RMD_S2 : Array Nat := #[
  8,9,9,11,13,15,15,5,7,7,8,11,14,14,12,6,
  9,13,15,7,12,8,9,11,7,7,12,7,6,15,13,11,
  9,7,15,11,8,6,6,14,12,13,5,14,13,13,7,5,
  15,5,8,11,14,14,6,14,6,9,12,9,12,5,15,8,
  8,5,12,9,12,5,14,6,8,13,6,5,15,13,11,11]
def RMD_K1 : Array UInt32 := #[0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E]
def RMD_K2 : Array UInt32 := #[0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000]

/-- The five RIPEMD-160 round functions, left line (rounds 0..4) and
right line (5..1): indexed by `round`. -/
def rmdF (round : Nat) (b c d : UInt32) : UInt32 :=
  match round with
  | 0 => b ^^^ c ^^^ d
  | 1 => (b &&& c) ||| (~~~b &&& d)
  | 2 => (b ||| (~~~c)) ^^^ d
  | 3 => (b &&& d) ||| (c &&& (~~~d))
  | _ => b ^^^ (c ||| (~~~d))

def rmdF2 (round : Nat) (b c d : UInt32) : UInt32 :=
  match round with
  | 0 => b ^^^ (c ||| (~~~d))
  | 1 => (b &&& d) ||| (c &&& (~~~d))
  | 2 => (b ||| (~~~c)) ^^^ d
  | 3 => (b &&& c) ||| (~~~b &&& d)
  | _ => b ^^^ c ^^^ d

def rmdCompress (h : Array UInt32) (block : ByteArray) (off : Nat) : Array UInt32 :=
  let x : Array UInt32 := (List.range 16).toArray.map (fun i => wordLE block (off + 4*i))
  let fin := (List.range 80).foldl (fun acc j =>
      let (a, b, c, d, e, aa, bb, cc, dd, ee) := acc
      let rnd := j / 16
      -- left line: T = rol_s(a + f + x + k) + e; then (a,b,c,d,e) := (e,T,b,rol10 c,d)
      let tL := (rotl32 (a + rmdF rnd b c d + RMD_K1[rnd]! + x[RMD_R1[j]!]!) RMD_S1[j]!) + e
      -- right line: mirror with rmdF2 / K2 / R2 / S2
      let tR := (rotl32 (aa + rmdF2 rnd bb cc dd + RMD_K2[rnd]! + x[RMD_R2[j]!]!) RMD_S2[j]!) + ee
      (e, tL, b, rotl32 c 10, d, ee, tR, bb, rotl32 cc 10, dd))
    (h[0]!, h[1]!, h[2]!, h[3]!, h[4]!, h[0]!, h[1]!, h[2]!, h[3]!, h[4]!)
  -- unpack and combine the two lines
  let (a, b, c, d, e, aa, bb, cc, dd, ee) := fin
  #[h[1]! + c + dd, h[2]! + d + ee, h[3]! + e + aa, h[4]! + a + bb, h[0]! + b + cc]

def hashRipemd160 (data : ByteArray) : ByteArray :=
  let padded := mdPad data false
  let nblocks := padded.size / 64
  let h := (List.range nblocks).foldl (fun h i => rmdCompress h padded (64 * i))
    #[0x67452301, 0xEFCDAB89, 0x98BADCFE, 0x10325476, 0xC3D2E1F0]
  (List.range 5).foldl (fun acc i => acc ++ wordLEEmitted h[i]!) ByteArray.empty

/-- RIPEMD160(SHA256(x)) — `CHash160` (hash.h), OP_HASH160 and the
P2WPKH witness-program check. -/
def hashHash160 (data : ByteArray) : ByteArray := hashRipemd160 (hashSha256 data)

/-- SHA256 twice — `CHash256` (hash.h), OP_HASH256. -/
def hashSha256d (data : ByteArray) : ByteArray := hashSha256 (hashSha256 data)

end Bitcoin.Interpreter
