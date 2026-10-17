import Bitcoin.RuleAttr

/-!
# Bitcoin.Data.Basic

Byte-level primitives shared by everything above: little-endian
serialization helpers, `CompactSize` (the Bitcoin varint), and the
`Amount` / `MoneyRange` money model.

Core counterparts:
  * LE serialization  — `src/serialize.h` (`WriteLE32`, `WriteLE64`, ...)
  * CompactSize       — `src/serialize.h` (`WriteVarInt`, `GetSizeOfCompactSize`)
  * Amount/MoneyRange — `src/consensus/amount.h` (`CAmount`, `MAX_MONEY`, `MoneyRange`)
-/

namespace Bitcoin.Data

deriving instance Repr for ByteArray

/-! ## Bytes -/

/-- Display helper (test only): lowercase hex of a `ByteArray`, as
`List Char` so that `decide`/`rfl` can reduce it in the kernel.
NOTE: avoid `ByteArray.toList` in kernel-reduced code — its core
definition is well-founded and does not reduce under `decide`. -/
def hexChars (b : ByteArray) : List Char :=
  let hexDigit (n : Nat) : Char :=
    if n < 10 then Char.ofNat (48 + n) else Char.ofNat (87 + n) -- 'a' = 97
  (List.range b.size).flatMap (fun i =>
    let n := (b.get! i).toNat
    [hexDigit (n / 16), hexDigit (n % 16)])

/-- Display helper (test only): lowercase hex of a `ByteArray`. -/
def toHex (b : ByteArray) : String := String.ofList (hexChars b)

/-- Byte-wise equality as a plain `Bool` (used in `decide`-able specs). -/
def bytesBEq (a b : ByteArray) : Bool :=
  a.size = b.size ∧ (List.range a.size).all (fun i => a.get! i == b.get! i)

/-! ## Little-endian writers (`serialize.h`) -/

def serU8 (x : UInt8) : ByteArray := ByteArray.empty.push x

def serU16 (x : UInt16) : ByteArray :=
  ByteArray.empty
    |>.push x.toUInt8
    |>.push (x >>> 8).toUInt8

def serU32 (x : UInt32) : ByteArray :=
  ByteArray.empty
    |>.push x.toUInt8
    |>.push (x >>> 8).toUInt8
    |>.push (x >>> 16).toUInt8
    |>.push (x >>> 24).toUInt8

def serU64 (x : UInt64) : ByteArray :=
  ByteArray.empty
    |>.push x.toUInt8
    |>.push (x >>> 8).toUInt8
    |>.push (x >>> 16).toUInt8
    |>.push (x >>> 24).toUInt8
    |>.push (x >>> 32).toUInt8
    |>.push (x >>> 40).toUInt8
    |>.push (x >>> 48).toUInt8
    |>.push (x >>> 56).toUInt8

/-! ## CompactSize varint (`serialize.h`) -/

/-- Max value encodable in a CompactSize (2^64-1). -/
def MAX_SIZE : Nat := 18446744073709551615

/-- Serialize a `CompactSize` length prefix. -/
def compactSizeEnc (n : Nat) : ByteArray :=
  if n < 0xfd then serU8 n.toUInt8
  else if n ≤ 0xffff then serU8 0xfd ++ serU16 n.toUInt16  -- marker + 2 bytes LE
  else if n ≤ 0xffffffff then serU8 0xfe ++ serU32 n.toUInt32
  else serU8 0xff ++ serU64 n.toUInt64

/-- Parse a CompactSize prefix; returns value and bytes consumed. -/
def compactSizeDec (b : ByteArray) (i : Nat) : Option (Nat × Nat) :=
  match b[i]? with
  | none => none
  | some first =>
    if first < 0xfd then some (first.toNat, 1)
    else if first = 0xfd then
      match b[i+1]?, b[i+2]? with
      | some lo, some hi => some (hi.toNat * 256 + lo.toNat, 3)
      | _, _ => none
    else if first = 0xfe then
      le32At b (i+1) |>.map (fun v => (v, 5))
    else
      le64At b (i+1) |>.map (fun v => (v, 9))
where
  le32At (b : ByteArray) (i : Nat) : Option Nat :=
    (List.range 4).foldl (fun acc k =>
      acc.bind (fun v => (b[i+k]? ).map (fun u => v + u.toNat * 256 ^ k))) (some 0)
  le64At (b : ByteArray) (i : Nat) : Option Nat :=
    (List.range 8).foldl (fun acc k =>
      acc.bind (fun v => (b[i+k]? ).map (fun u => v + u.toNat * 256 ^ k))) (some 0)

/-! ## Amounts (`consensus/amount.h`) -/

/-- `CAmount` is `int64_t` in Core; we keep signed `Int` so that the
"negative output" rule (`bad-txns-vout-negative`) is expressible exactly
as in `tx_check.cpp`, then constrain with `MoneyRange`. `abbrev` keeps
the `Int` instances (ordering, arithmetic) available. -/
abbrev Amount := Int

/-- `Amount` → raw unsigned 64-bit wire value (two's complement).
Core serializes the `int64_t` bit pattern (`primitives/transaction.cpp`). -/
def amtToU64 (v : Amount) : Nat :=
  if v < 0 then (v + 18446744073709551616).toNat else v.toNat

/-- Raw unsigned 64-bit wire value → `Amount` (two's complement). -/
def u64ToAmt (u : Nat) : Amount :=
  if u < 9223372036854775808 then (u : Int) else (u : Int) - 18446744073709551616

/-- `COIN` — number of satoshis in one bitcoin (`consensus/amount.h`). -/
def COIN : Amount := 100000000

/-- `MAX_MONEY = 21'000'000 * COIN` (`consensus/amount.h:26`). -/
def MAX_MONEY : Amount := 21000000 * COIN

/-- `MoneyRange` (`consensus/amount.h:27`). -/
@[rule "INV-024"]
def MoneyRange (n : Amount) : Bool := decide (0 ≤ n ∧ n ≤ MAX_MONEY)

theorem moneyRange_zero : MoneyRange 0 = true := by
  rfl

/-- Concrete sanity: reflexivity on a known value (`rfl` reduces). -/
example : bytesBEq (serU8 0x51) (serU8 0x51) = true := by rfl

end Bitcoin.Data
