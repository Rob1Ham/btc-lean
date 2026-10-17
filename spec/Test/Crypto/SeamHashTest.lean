import Bitcoin.Crypto.Seam.Interface

/-!
# W13 test harness — crypto seam hash floor (Interface)

Run: `bash spec/Test/Crypto/run.sh` (from anywhere).

Two layers:
1. Build-time `native_decide` examples — the compiler itself verifies the
   digest bytes (native_decide is allowed under `Test/` per the L1 rule;
   plain `decide` does not whnf-reduce the 64-round compression).
2. An IO harness that prints the same digests for diffing against
   `python3 hashlib` / Bitcoin Core vectors.

Vectors: FIPS 180-4 / RIPEMD-160 spec set, hash.h composites, and the
genesis block header dsha256 (block 0, `000000000019d668...` displayed
big-endian; the seam returns the little-endian internal order exactly
like Core's `uint256`).
-/

open Bitcoin.Crypto.Seam

set_option maxRecDepth 100000

private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

/-- Parse a hex string into a ByteArray (test infra only). -/
def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

/-- Lowercase hex of a ByteArray (test infra only). -/
private def hexOf (b : ByteArray) : String :=
  (List.range b.size).foldl (fun acc i =>
    let v := b[i]!.toNat
    acc ++ "0123456789abcdef".toList[v / 16]!.toString
        ++ "0123456789abcdef".toList[v % 16]!.toString) ""

/-! ## Build-time-verified hash vectors (native_decide) -/

-- SHA-256 of the empty string (FIPS 180-4 vector).
example : (sha256 ByteArray.empty).data.toList.map (·.toNat) =
    [0xe3,0xb0,0xc4,0x42,0x98,0xfc,0x1c,0x14,0x9a,0xfb,0xf4,0xc8,0x99,0x6f,0xb9,0x24,
     0x27,0xae,0x41,0xe4,0x64,0x9b,0x93,0x4c,0xa4,0x95,0x99,0x1b,0x78,0x52,0xb8,0x55] := by
  native_decide

-- SHA-256 of "abc" (FIPS 180-4 vector).
example : (sha256 "abc".toUTF8).data.toList.map (·.toNat) =
    [0xba,0x78,0x16,0xbf,0x8f,0x01,0xcf,0xea,0x41,0x41,0x40,0xde,0x5d,0xae,0x22,0x23,
     0xb0,0x03,0x61,0xa3,0x96,0x17,0x7a,0x9c,0xb4,0x10,0xff,0x61,0xf2,0x00,0x15,0xad] := by
  native_decide

-- SHA-256 padding boundary: 55 bytes (no extra block) and 56 bytes (extra block).
example : (sha256 (ByteArray.mk (Array.replicate 55 0x61))).data.toList.map (·.toNat) =
    [0x9f,0x43,0x90,0xf8,0xd3,0x0c,0x2d,0xd9,0x2e,0xc9,0xf0,0x95,0xb6,0x5e,0x2b,0x9a,
     0xe9,0xb0,0xa9,0x25,0xa5,0x25,0x8e,0x24,0x1c,0x9f,0x1e,0x91,0x0f,0x73,0x43,0x18] := by
  native_decide
example : (sha256 (ByteArray.mk (Array.replicate 56 0x61))).data.toList.map (·.toNat) =
    [0xb3,0x54,0x39,0xa4,0xac,0x6f,0x09,0x48,0xb6,0xd6,0xf9,0xe3,0xc6,0xaf,0x0f,0x5f,
     0x59,0x0c,0xe2,0x0f,0x1b,0xde,0x70,0x90,0xef,0x79,0x70,0x68,0x6e,0xc6,0x73,0x8a] := by
  native_decide

-- RIPEMD-160 of the empty string and of "abc" (spec vectors).
example : (hash160 ByteArray.empty).data.toList.map (·.toNat) =
    [0xb4,0x72,0xa2,0x66,0xd0,0xbd,0x89,0xc1,0x37,0x06,
     0xa4,0x13,0x2c,0xcf,0xb1,0x6f,0x7c,0x3b,0x9f,0xcb] := by
  native_decide
example : (Bitcoin.Crypto.Seam.Hash.Ripemd160.ripemd160 "abc".toUTF8).data.toList.map (·.toNat) =
    [0x8e,0xb2,0x08,0xf7,0xe0,0x5d,0x98,0x7a,0x9b,0x04,
     0x4a,0x8e,0x98,0xc6,0xb0,0x87,0xf1,0x5a,0x0b,0xfc] := by
  native_decide

-- dsha256 of the empty string (CHash256 vector).
example : (sha256d ByteArray.empty).data.toList.map (·.toNat) =
    [0x5d,0xf6,0xe0,0xe2,0x76,0x13,0x59,0xd3,0x0a,0x82,0x75,0x05,0x8e,0x29,0x9f,0xcc,
     0x03,0x81,0x53,0x45,0x45,0xf5,0x5c,0xf4,0x3e,0x41,0x98,0x3f,0x5d,0x4c,0x94,0x56] := by
  native_decide

-- THE genesis block header dsha256 (block 0): internal little-endian byte
-- order, i.e. big-endian display 000000000019d668...  (BLK-005 shape).
example : (sha256d (fromHex
    "0100000000000000000000000000000000000000000000000000000000000000000000003ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a29ab5f49ffff001d1dac2b7c")).data.toList.map (·.toNat) =
    [0x6f,0xe2,0x8c,0x0a,0xb6,0xf1,0xb3,0x72,0xc1,0xa6,0xa2,0x46,0xae,0x63,0xf7,0x4f,
     0x93,0x1e,0x83,0x65,0xe1,0x5a,0x08,0x9c,0x68,0xd6,0x19,0x00,0x00,0x00,0x00,0x00] := by
  native_decide

-- hash160 of the secp256k1 generator's compressed key (BIP341 test vector).
example : (hash160 (fromHex
    "0279BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798")).data.toList.map (·.toNat) =
    [0x75,0x1e,0x76,0xe8,0x19,0x91,0x96,0xd4,0x54,0x94,
     0x1c,0x45,0xd1,0xb3,0xa3,0x23,0xf1,0x43,0x3b,0xd6] := by
  native_decide

-- Digest-size contracts (B5): these are PROVEN theorems, decide just
-- re-instances them.
example : (sha256d ByteArray.empty).size = 32 := by decide
example : (hash160 ByteArray.empty).size = 20 := by decide

/-! ## IO harness (diffs against `python3 hashlib`) -/

def inputs : List (String × ByteArray) :=
  [("empty", ByteArray.empty),
   ("abc", "abc".toUTF8),
   ("message digest", "message digest".toUTF8),
   ("alphabet", "abcdefghijklmnopqrstuvwxyz".toUTF8),
   ("55a", ByteArray.mk (Array.replicate 55 0x61)),
   ("genesis-header", fromHex
    "0100000000000000000000000000000000000000000000000000000000000000000000003ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a29ab5f49ffff001d1dac2b7c")]

def main : IO Unit := do
  for (name, m) in inputs do
    IO.println (name ++ " sha256   " ++ hexOf (sha256 m))
    IO.println (name ++ " sha256d  " ++ hexOf (sha256d m))
    IO.println (name ++ " hash160  " ++ hexOf (hash160 m))
