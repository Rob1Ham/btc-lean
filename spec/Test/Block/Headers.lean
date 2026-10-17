import Bitcoin.Capstone.Pow
import Bitcoin.Serialization.Interface
import Bitcoin.Block.Params
import Bitcoin.Data.Basic

/-!
# Bitcoin.Test.Block.Headers — mainnet header vectors (X08)

Six real mainnet headers (80 bytes each) from `spec/vectors/blk-headers/`
(derived from the hash-manifest-verified anchor raws of W17 S1 /
`spec/vectors/anchors/`; each header re-verifies against its pinned
display hash via double-SHA256 — asserted in the manifest pipeline):

* `0`      — genesis (difficulty-1 `0x1d00ffff`, the Times coinbase era)
* `74638`  — pre-BIP34 v1 header era
* `91842`  — BIP30 duplicate-txid pair block 1
* `91880`  — BIP30 duplicate-txid pair block 2
* `481824` — SegWit activation block (BIP9 version bit 1 set: v0x20000002)
* `709632` — Taproot activation block (v0x20200004)

Checks (Test-scoped `native_decide` per the D2 L1 convention, as in
`Test/Crypto/SeamHashTest.lean`):

1. **BLK-001** — the 80-byte vector decodes, and re-encodes to the very
   same bytes (decode/encode stability on real wire data).
2. **BLK-003** — `SHA256d(header)` reversed = the pinned display hash.
3. **BLK-037/038/039** — `powOk`: target decode gate + high-hash ≤ target
   on REAL mainnet proof-of-work.
4. chain linkage — `hashPrevBlock` (internal order) = reversed parent
   display hash.
5. the Params genesis header IS vector 0, byte for byte (BLK-111).

`main` re-adjudicates everything at runtime (`lake env lean --run`) and
exits nonzero on any failure.
-/

open Bitcoin.Data
open Bitcoin.Chain
open Bitcoin.Capstone.Pow
open Bitcoin.Serialization

namespace Bitcoin.Test.Block.Headers

/-! ## Helpers -/

private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

/-- Hex string → ByteArray (vector-loader convention, SeamHashTest). -/
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

/-- Byte reversal — display (big-endian) vs internal (little-endian)
hash order. -/
def rev32 (b : ByteArray) : ByteArray :=
  (List.range b.size).foldl (fun acc i => acc.push (b.get! (b.size - 1 - i))) ByteArray.empty

/-- The header a raw vector decodes to (total: failure ⇒ zero header). -/
def vecHeader (raw : ByteArray) : BlockHeader :=
  match decodeBlockHeader raw with
  | .ok h => h
  | .error _ =>
      ({ version := 0, hashPrevBlock := ByteArray.empty, hashMerkleRoot := ByteArray.empty,
          time := 0, bits := 0, nonce := 0 } :
        Bitcoin.Chain.BlockHeader)

/-- Decode-encode stability: the vector round-trips to its own bytes. -/
def roundTrips (raw : ByteArray) : Bool :=
  bytesBEq (encodeBlockHeader (vecHeader raw)) raw

/-! ## The six vectors -/

def RAW0 : ByteArray := fromHex
  "0100000000000000000000000000000000000000000000000000000000000000000000003ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a29ab5f49ffff001d1dac2b7c"
def HASH0 : ByteArray := fromHex
  "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"
def PARENT0 : ByteArray := fromHex
  "0000000000000000000000000000000000000000000000000000000000000000"

def RAW74638 : ByteArray := fromHex
  "01000000846e2b968653ef0a25a92c12e8884d76919907df8e3079e66568600000000000acbb1212652163fd97a07dc58adc6cc5698e8c97a7579fc854d05bcab054585f177e684c0e80001c5a63b1c6"
def HASH74638 : ByteArray := fromHex
  "000000000069e1affe7161ab4bcbeacebb4ddf155b50e807f42de971b688a09b"
def PARENT74638 : ByteArray := fromHex
  "0000000000606865e679308edf079991764d88e8122ca9250aef5386962b6e84"

def RAW91842 : ByteArray := fromHex
  "0100000020114beba985ecbf1351bf5f4d5495105dc2ca94f5bdbcac921e0a00000000009985d82954e10f2233a08905dc7b490eb444660c8759e324c7dfa3d28779d2d5f34ee04c56720e1b021838e1"
def HASH91842 : ByteArray := fromHex
  "00000000000a4d0a398161ffc163c503763b1f4360639393e0e4c8e300e0caec"
def PARENT91842 : ByteArray := fromHex
  "00000000000a1e92acbcbdf594cac25d1095544d5fbf5113bfec85a9eb4b1120"

def RAW91880 : ByteArray := fromHex
  "01000000f3f32d77f94d5e971e202afa4a633056b2b14dda3f4abf569609040000000000e90f74856c0ed42ab7eea359487079e3f76e4076f91250fab8431f6241f56b2f8380e04c56720e1b1c467e89"
def HASH91880 : ByteArray := fromHex
  "00000000000743f190a18c5577a3c2d2a1f610ae9601ac046a38084ccb7cd721"
def PARENT91880 : ByteArray := fromHex
  "000000000004099656bf4a3fda4db1b25630634afa2a201e975e4df9772df3f3"

def RAW481824 : ByteArray := fromHex
  "02000020801b81629334be8e7af5ebfb9df09c18e1f833b5f0efcb00000000000000000040d1ca077fefe7fb797711baa0c063eca9b8ed9469ae0128982b44ad0c25386491329e59e93c011822ff5422"
def HASH481824 : ByteArray := fromHex
  "0000000000000000001c8018d9cb3b742ef25114f27563e3fc4a1902167f9893"
def PARENT481824 : ByteArray := fromHex
  "000000000000000000cbeff0b533f8e1189cf09dfbebf57a8ebe349362811b80"

def RAW709632 : ByteArray := fromHex
  "04002020ccbcc674693ef8751c939c0e6d4728dde62e24fc12370100000000000000000077ec1447375fc68029ab7a85fd6989c5d31351b619e8f709de682008103bda6a6f9b9061ea690c1702730f54"
def HASH709632 : ByteArray := fromHex
  "0000000000000000000687bca986194dc2c1f949318629b44bb54ec0a94d8244"
def PARENT709632 : ByteArray := fromHex
  "000000000000000000013712fc242ee6dd28476d0e9c931c75f83e6974c6bccc"

/-! ## BLK-001: decode/encode stability on real wire data -/

example : roundTrips RAW0 = true := by native_decide
example : roundTrips RAW74638 = true := by native_decide
example : roundTrips RAW91842 = true := by native_decide
example : roundTrips RAW91880 = true := by native_decide
example : roundTrips RAW481824 = true := by native_decide
example : roundTrips RAW709632 = true := by native_decide

/-! ## BLK-003: SHA256d header hash = the pinned display hash -/

example : bytesBEq (rev32 (headerHash (vecHeader RAW0))) HASH0 = true := by
  native_decide
example : bytesBEq (rev32 (headerHash (vecHeader RAW74638))) HASH74638 = true := by
  native_decide
example : bytesBEq (rev32 (headerHash (vecHeader RAW91842))) HASH91842 = true := by
  native_decide
example : bytesBEq (rev32 (headerHash (vecHeader RAW91880))) HASH91880 = true := by
  native_decide
example : bytesBEq (rev32 (headerHash (vecHeader RAW481824))) HASH481824 = true := by
  native_decide
example : bytesBEq (rev32 (headerHash (vecHeader RAW709632))) HASH709632 = true := by
  native_decide

/-! ## BLK-037/038/039: real mainnet proof-of-work passes -/

example : powOk (vecHeader RAW0) = true := by native_decide
example : powOk (vecHeader RAW74638) = true := by native_decide
example : powOk (vecHeader RAW91842) = true := by native_decide
example : powOk (vecHeader RAW91880) = true := by native_decide
example : powOk (vecHeader RAW481824) = true := by native_decide
example : powOk (vecHeader RAW709632) = true := by native_decide

/-! ## Chain linkage: hashPrevBlock = reversed parent display hash -/

example : bytesBEq (vecHeader RAW74638).hashPrevBlock (rev32 PARENT74638) = true := by
  native_decide
example : bytesBEq (vecHeader RAW91842).hashPrevBlock (rev32 PARENT91842) = true := by
  native_decide
example : bytesBEq (vecHeader RAW91880).hashPrevBlock (rev32 PARENT91880) = true := by
  native_decide
example : bytesBEq (vecHeader RAW481824).hashPrevBlock (rev32 PARENT481824) = true := by
  native_decide
example : bytesBEq (vecHeader RAW709632).hashPrevBlock (rev32 PARENT709632) = true := by
  native_decide

/-! ## BLK-111: the Params genesis header IS vector 0, byte for byte -/

example : bytesBEq (encodeBlockHeader Bitcoin.Block.Params.genesisHeader) RAW0 = true := by
  native_decide

/-! ## BIP9 version-bit eras (BLK-082 context): pre-BIP9 v1 vs BIP9 eras -/

example : (vecHeader RAW74638).version = 1 := by native_decide
example : (vecHeader RAW481824).version = 0x20000002 := by native_decide
example : (vecHeader RAW709632).version = 0x20200004 := by native_decide

/-! ## Runtime adjudication (`lake env lean --run`) -/

def checks : List (String × Bool) :=
  [("0 roundtrip", roundTrips RAW0), ("0 hash", bytesBEq (rev32 (headerHash (vecHeader RAW0))) HASH0),
   ("0 pow", powOk (vecHeader RAW0)),
   ("74638 roundtrip", roundTrips RAW74638), ("74638 hash", bytesBEq (rev32 (headerHash (vecHeader RAW74638))) HASH74638),
   ("74638 pow", powOk (vecHeader RAW74638)), ("74638 link", bytesBEq (vecHeader RAW74638).hashPrevBlock (rev32 PARENT74638)),
   ("91842 roundtrip", roundTrips RAW91842), ("91842 hash", bytesBEq (rev32 (headerHash (vecHeader RAW91842))) HASH91842),
   ("91842 pow", powOk (vecHeader RAW91842)), ("91842 link", bytesBEq (vecHeader RAW91842).hashPrevBlock (rev32 PARENT91842)),
   ("91880 roundtrip", roundTrips RAW91880), ("91880 hash", bytesBEq (rev32 (headerHash (vecHeader RAW91880))) HASH91880),
   ("91880 pow", powOk (vecHeader RAW91880)), ("91880 link", bytesBEq (vecHeader RAW91880).hashPrevBlock (rev32 PARENT91880)),
   ("481824 roundtrip", roundTrips RAW481824), ("481824 hash", bytesBEq (rev32 (headerHash (vecHeader RAW481824))) HASH481824),
   ("481824 pow", powOk (vecHeader RAW481824)), ("481824 link", bytesBEq (vecHeader RAW481824).hashPrevBlock (rev32 PARENT481824)),
   ("709632 roundtrip", roundTrips RAW709632), ("709632 hash", bytesBEq (rev32 (headerHash (vecHeader RAW709632))) HASH709632),
   ("709632 pow", powOk (vecHeader RAW709632)), ("709632 link", bytesBEq (vecHeader RAW709632).hashPrevBlock (rev32 PARENT709632)),
   ("genesis==vec0", bytesBEq (encodeBlockHeader Bitcoin.Block.Params.genesisHeader) RAW0)]

def runAll : IO Unit := do
  let mut fails := 0
  for (name, ok) in checks do
    IO.println s!"{if ok then "PASS" else "FAIL"} {name}"
    if ¬ ok then fails := fails + 1
  if fails > 0 then
    IO.println s!"{fails} FAILURES"
    throw (IO.userError "header vectors failed")

end Bitcoin.Test.Block.Headers

open Bitcoin.Test.Block.Headers in
def main : IO Unit := runAll
