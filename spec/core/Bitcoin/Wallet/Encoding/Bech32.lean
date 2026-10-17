import Bitcoin.Data.Basic

/-!
# Bitcoin.Wallet.Encoding.Bech32

Bech32 and Bech32m as used by native segwit addresses.  The model follows
Bitcoin Core `cce32b168` (`src/bech32.cpp`, `src/bech32.h`) and the two
BIPs it implements:

* the 32-character alphabet `qpzry9x8gf2tvdw0s3jn54khce6mua7l`
  (`src/bech32.cpp:22`) and its reverse table (`src/bech32.cpp:25-34`);
* `PolyMod` over GF(32), the five reduction constants, and the implicit
  leading one (`src/bech32.cpp:129-215`);
* human-readable-part expansion `high bits ‖ 0 ‖ low bits`
  (`src/bech32.cpp:310-323`);
* checksum creation and verification with constant `1` for Bech32 and
  `0x2bc830a3` for Bech32m (`src/bech32.cpp:120-124,326-352`);
* decoding: printable-ASCII and mixed-case checks, last-`1` separator,
  the 90-character limit, 5-bit symbol lookup, and checksum verification
  (`src/bech32.cpp:279-308,373-399`);
* the strict 5-to-8 regrouping used for witness programs
  (`ConvertBits<5,8,false>`, `src/key_io.cpp:155`), including the rule
  that an incomplete final group is at most four bits and all zero.

The segwit layer mirrors `DecodeDestination` (`src/key_io.cpp:133-204`):
the first data symbol is the witness version, the rest is regrouped into
program bytes, version 0 must use Bech32 and is limited to 20 or 32 bytes
(`src/key_io.cpp:145-176`), and version 1 must use Bech32m and is limited
to 32 bytes (`src/key_io.cpp:149-151,179-184`).

## What is not modelled

* Only witness versions 0 and 1 with their BIP141/BIP341 lengths are
  accepted: v0 is 20 or 32 bytes, v1 is 32 bytes.  Core also accepts
  versions 2 through 16 as `WitnessUnknown` with any 2-to-40-byte program,
  and treats a non-32-byte v1 program the same way; it additionally
  recognises pay-to-anchor (`src/key_io.cpp:186-200`).  Those cases are
  outside this wallet encoding fragment and are rejected.  In particular
  the BIP350 valid-address vector with a 40-byte v1 program
  (`bc1pw508...kt5nd6y`) is deliberately not a positive case here.
* The 1023-character silent-payments limit (`bech32.h:40-43`) is not
  exposed; every decode uses the 90-character address limit.
* There is no error localisation (`LocateErrors`, `src/bech32.cpp:401+`)
  and no error correction.  Decoding returns the first structural failure.
* The encoder emits lowercase only and rejects an uppercase HRP instead of
  asserting as Core does (`src/bech32.cpp:357-362`).  Encoding is not
  length-limited, matching Core's `Encode`, so a caller can construct a
  string that `bech32Decode` will then reject as too long.
* No network registry is built in: the caller supplies the HRP (`bc`,
  `tb`, `bcrt`, or any other string).  Address semantics, scriptPubKeys,
  WIF, BIP38, and address books are not modelled here.
-/

namespace Bitcoin.Wallet.Encoding

/-! ## Encoding kind and errors -/

/-- BIP173 Bech32 or BIP350 Bech32m.  The two differ only in the final
constant XORed into the checksum (`src/bech32.cpp:120-124`). -/
inductive Encoding where
  | bech32
  | bech32m
deriving Repr, DecidableEq

/-- Checksum failure and structural-decode failures.  The constructors
are deliberately finer than Core's `Encoding::INVALID`: callers can tell a
bad alphabet character from a bad checksum or an over-long string. -/
inductive Bech32Error where
  | tooLong (limit : Nat)
  | invalidCharacter (index : Nat)
  | mixedCase
  | missingSeparator
  | invalidSeparator (index : Nat)
  | invalidBase32 (index : Nat)
  | invalidChecksum
  | invalidHrp (hrp : String)
  | dataOutOfRange (value : Nat)
deriving Repr, DecidableEq

/-- A successfully decoded Bech32 string: which checksum variant matched,
the lowercased HRP, and the data symbols with the six checksum symbols
removed (`src/bech32.cpp:391-398`). -/
structure Bech32Decoded where
  encoding : Encoding
  hrp : String
  data : List Nat
deriving Repr, DecidableEq

/-! ## Character helpers -/

/-- Bech32's data alphabet (`src/bech32.cpp:22`). -/
def bech32Charset : String := "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

/-- The data alphabet as characters. -/
def bech32CharsetChars : List Char := bech32Charset.toList

/-- ASCII lowercase for a single character, leaving everything else
unchanged.  Core lowercases the HRP before checksum verification
(`src/bech32.cpp:279-283,391-395`). -/
def asciiLowerChar (c : Char) : Char :=
  if 65 ≤ c.toNat ∧ c.toNat ≤ 90 then Char.ofNat (c.toNat + 32) else c

/-- ASCII lowercase for a whole string. -/
def asciiLowerString (s : String) : String :=
  String.ofList (s.toList.map asciiLowerChar)

/-- `true` for `A` through `Z`. -/
def isUpperChar (c : Char) : Bool := decide (65 ≤ c.toNat ∧ c.toNat ≤ 90)

/-- `true` for `a` through `z`. -/
def isLowerChar (c : Char) : Bool := decide (97 ≤ c.toNat ∧ c.toNat ≤ 122)

/-- Value of a Bech32 data character, case-insensitively.  This is the
reverse table at `src/bech32.cpp:25-34`: both cases map to the same
5-bit value, and characters absent from the table return `none`. -/
def bech32Value? (c : Char) : Option Nat :=
  let lc := asciiLowerChar c
  let rec go (i : Nat) : List Char → Option Nat
    | [] => none
    | d :: ds => if d = lc then some i else go (i + 1) ds
  go 0 bech32CharsetChars

/-- Character for a 5-bit value.  Values are masked to five bits; callers
that need rejection use `bech32Encode`'s range check. -/
def bech32Char (v : Nat) : Char :=
  bech32CharsetChars.getD (v % 32) 'q'

/-! ## Checksum -/

/-- Build one 30-bit residue step of `PolyMod` (`src/bech32.cpp:176-214`).
`c0` is the five-bit overflow, `c1` shifts in the next symbol, and the
five conditional XORs are Core's GF(32) reduction constants. -/
def polymod (values : List Nat) : UInt32 :=
  values.foldl (fun c v =>
    let c0 := c >>> (25 : UInt32)
    let c1 := ((c &&& (0x1ffffff : UInt32)) <<< (5 : UInt32)) ^^^ v.toUInt32
    let c2 := if (c0 &&& (1 : UInt32)) = 0 then c1
      else c1 ^^^ (0x3b6a57b2 : UInt32)
    let c3 := if (c0 &&& (2 : UInt32)) = 0 then c2
      else c2 ^^^ (0x26508e6d : UInt32)
    let c4 := if (c0 &&& (4 : UInt32)) = 0 then c3
      else c3 ^^^ (0x1ea119fa : UInt32)
    let c5 := if (c0 &&& (8 : UInt32)) = 0 then c4
      else c4 ^^^ (0x3d4233dd : UInt32)
    if (c0 &&& (16 : UInt32)) = 0 then c5
    else c5 ^^^ (0x2a1462b3 : UInt32)) (1 : UInt32)

/-- The final checksum constant: `1` for Bech32, `0x2bc830a3` for Bech32m
(`src/bech32.cpp:120-124`; BIP350). -/
def encodingConstant : Encoding → UInt32
  | .bech32 => 1
  | .bech32m => 0x2bc830a3

/-- HRP expansion: high five bits of every character, a zero, then the low
five bits (`src/bech32.cpp:310-323`). -/
def hrpExpand (hrp : String) : List Nat :=
  hrp.toList.map (fun c => c.toNat / 32) ++ [0] ++
    hrp.toList.map (fun c => c.toNat % 32)

/-- Create the six checksum symbols (`src/bech32.cpp:340-352`). -/
def createChecksum (enc : Encoding) (hrp : String) (data : List Nat) : List Nat :=
  let m := polymod (hrpExpand hrp ++ data ++ [0, 0, 0, 0, 0, 0])
    ^^^ encodingConstant enc
  (List.range 6).map fun i =>
    ((m >>> (5 * (5 - i)).toUInt32).toNat) % 32

/-- Verify a checksum and report which variant matched
(`src/bech32.cpp:325-338`). -/
def verifyChecksum (hrp : String) (values : List Nat) : Option Encoding :=
  let m := polymod (hrpExpand hrp ++ values)
  if m = encodingConstant .bech32 then some .bech32
  else if m = encodingConstant .bech32m then some .bech32m
  else none

/-! ## 5-bit regrouping (`ConvertBits`) -/

/-- Emit complete `toBits` groups from the accumulator, most significant
group first.  `fuel` bounds the inner loop; the caller supplies enough. -/
def flushGroups (toBits maxv : Nat) (fuel acc bits : Nat) (out : List Nat) :
    Nat × Nat × List Nat :=
  match fuel with
  | 0 => (acc, bits, out)
  | fuel + 1 =>
      if bits ≥ toBits then
        let bits' := bits - toBits
        let v := (acc >>> bits') &&& maxv
        flushGroups toBits maxv fuel acc bits' (out ++ [v])
      else (acc, bits, out)

/-- Generic regrouping between bit widths.  With `pad = true` an incomplete
group is zero-padded (8-to-5 for encoding); with `pad = false` an incomplete
group must be shorter than one source group and all zero (5-to-8 for
segwit decoding), exactly BIP173's reference `convertbits`. -/
def convertBits (fromBits toBits : Nat) (pad : Bool) (data : List Nat) :
    Option (List Nat) :=
  if fromBits = 0 ∨ toBits = 0 then none
  else
    let maxv := (1 <<< toBits) - 1
    let maxAcc := (1 <<< (fromBits + toBits - 1)) - 1
    let rec go (fuel : Nat) (acc bits : Nat) (ds out : List Nat) :
        Option (List Nat) :=
      match fuel with
      | 0 => none
      | fuel + 1 =>
          match ds with
          | [] =>
              if bits ≥ fromBits then none
              else if pad then
                if bits = 0 then some out
                else some (out ++ [((acc <<< (toBits - bits)) &&& maxv)])
              else if ((acc <<< (toBits - bits)) &&& maxv) ≠ 0 then none
              else some out
          | d :: rest =>
              if d ≥ (1 <<< fromBits) then none
              else
                let acc := ((acc <<< fromBits) ||| d) &&& maxAcc
                let bits := bits + fromBits
                let (acc, bits, out) :=
                  flushGroups toBits maxv (fromBits + toBits) acc bits out
                go fuel acc bits rest out
    go (data.length + 1) 0 0 data []

/-- Regroup witness-program bytes into 5-bit symbols, zero-padding the
tail (`ConvertBits<8,5,true>`). -/
def bytesToData (b : ByteArray) : List Nat :=
  (convertBits 8 5 true (b.toList.map (fun x => x.toNat))).getD []

/-- Regroup 5-bit symbols into bytes, rejecting incomplete non-zero groups
(`ConvertBits<5,8,false>`). -/
def dataToBytes (data : List Nat) : Option ByteArray :=
  match convertBits 5 8 false data with
  | none => none
  | some bs => some (List.toByteArray (bs.map fun n => n.toUInt8))

/-! ## String-level encode and decode -/

/-- An HRP is 1 to 83 printable ASCII characters, all lowercase in this
model.  The separator `1` is allowed inside the HRP; the last one is the
separator (`src/bech32.cpp:376-378`). -/
def hrpValid (hrp : String) : Bool :=
  let cs := hrp.toList
  !cs.isEmpty && cs.all (fun c =>
    decide (33 ≤ c.toNat ∧ c.toNat ≤ 126) && !isUpperChar c)

/-- Encode data symbols with the chosen checksum variant.  The HRP must be
lowercase, and every data symbol must be in `0..31`; otherwise this returns
an error instead of Core's assertion failure (`src/bech32.cpp:357-369`). -/
def bech32Encode (enc : Encoding) (hrp : String) (data : List Nat) :
    Except Bech32Error String :=
  if !hrpValid hrp then .error (.invalidHrp hrp)
  else
    match data.find? (fun v => decide (v ≥ 32)) with
    | some v => .error (.dataOutOfRange v)
    | none =>
        let values := data ++ createChecksum enc hrp data
        .ok (hrp ++ "1" ++ String.ofList (values.map bech32Char))

/-- First structural character error: a byte outside printable ASCII, or a
string that mixes uppercase and lowercase (`src/bech32.cpp:285-308`). -/
def checkCharacters (cs : List Char) : Option Bech32Error :=
  let rec go (i : Nat) (lower upper : Bool) : List Char → Option Bech32Error
    | [] => none
    | c :: rest =>
        if c.toNat < 33 ∨ c.toNat > 126 then some (.invalidCharacter i)
        else if isLowerChar c then
          if upper then some .mixedCase else go (i + 1) true upper rest
        else if isUpperChar c then
          if lower then some .mixedCase else go (i + 1) lower true rest
        else go (i + 1) lower upper rest
  go 0 false false cs

/-- Index of the last occurrence of a character, or `none`. -/
def lastIndexChar (target : Char) (cs : List Char) : Option Nat :=
  let rec go (i : Nat) (last : Option Nat) : List Char → Option Nat
    | [] => last
    | c :: rest => go (i + 1) (if c = target then some i else last) rest
  go 0 none cs

/-- Decode the data part after the separator.  The index in
`invalidBase32` is the character's position in the original string. -/
def decodeBase32 (start : Nat) (cs : List Char) :
    Except Bech32Error (List Nat) :=
  match cs with
  | [] => .ok []
  | c :: rest =>
      match bech32Value? c with
      | none => .error (.invalidBase32 start)
      | some v =>
          match decodeBase32 (start + 1) rest with
          | .error e => .error e
          | .ok vs => .ok (v :: vs)

/-- Decode a Bech32 or Bech32m string.  The default limit is the BIP173
address limit of 90 characters (`bech32.h:40-43`). -/
def bech32Decode (s : String) (limit : Nat := 90) :
    Except Bech32Error Bech32Decoded :=
  let cs := s.toList
  match checkCharacters cs with
  | some e => .error e
  | none =>
      if cs.length > limit then .error (.tooLong limit)
      else
        match lastIndexChar '1' cs with
        | none => .error .missingSeparator
        | some pos =>
            if pos = 0 ∨ pos + 6 ≥ cs.length then .error (.invalidSeparator pos)
            else
              let hrp := String.ofList ((cs.take pos).map asciiLowerChar)
              match decodeBase32 (pos + 1) (cs.drop (pos + 1)) with
              | .error e => .error e
              | .ok values =>
                  match verifyChecksum hrp values with
                  | none => .error .invalidChecksum
                  | some enc =>
                      .ok ⟨enc, hrp, values.take (values.length - 6)⟩

/-! ## Segwit addresses -/

/-- Witness version and program bytes, before any address text exists. -/
structure WitnessProgram where
  version : Nat
  program : ByteArray
deriving Repr, DecidableEq

/-- Segwit-address failures.  `wrongEncoding` is BIP350's pairing rule;
`invalidPadding` is the strict 5-to-8 conversion failure; `badProgramLength`
carries the version and the observed length. -/
inductive SegwitError where
  | bech32 (e : Bech32Error)
  | wrongHrp (expected actual : String)
  | emptyData
  | invalidWitnessVersion (version : Nat)
  | unsupportedWitnessVersion (version : Nat)
  | wrongEncoding (version : Nat) (actual : Encoding)
  | invalidPadding
  | badProgramLength (version : Nat) (actual : Nat)
deriving Repr, DecidableEq

/-- Encode a witness program as an address.  Version 0 uses Bech32 and is
restricted to 20 or 32 bytes; version 1 uses Bech32m and must be 32 bytes
(`src/key_io.cpp:145-184`, BIP350). -/
def encodeSegwit (hrp : String) (wp : WitnessProgram) : Except SegwitError String :=
  let v := wp.version
  let n := wp.program.size
  if v = 0 then
    if n ≠ 20 ∧ n ≠ 32 then .error (.badProgramLength 0 n)
    else
      match bech32Encode .bech32 hrp (0 :: bytesToData wp.program) with
      | .ok s => .ok s
      | .error e => .error (.bech32 e)
  else if v = 1 then
    if n ≠ 32 then .error (.badProgramLength 1 n)
    else
      match bech32Encode .bech32m hrp (1 :: bytesToData wp.program) with
      | .ok s => .ok s
      | .error e => .error (.bech32 e)
  else if v ≤ 16 then .error (.unsupportedWitnessVersion v)
  else .error (.invalidWitnessVersion v)

/-- Decode a segwit address for a given HRP.  This models Core's
`DecodeDestination` for versions 0 and 1 only: reject an empty data part,
check the HRP, take the first data symbol as version, enforce the
version/checksum pairing, regroup the rest with strict padding, then
enforce the BIP141/BIP341 lengths
(`src/key_io.cpp:133-204`). -/
def decodeSegwit (hrp : String) (s : String) : Except SegwitError WitnessProgram :=
  match bech32Decode s with
  | .error e => .error (.bech32 e)
  | .ok d =>
      match d.data with
      | [] => .error .emptyData
      | v :: rest =>
          if d.hrp ≠ hrp then .error (.wrongHrp hrp d.hrp)
          else
            if v > 16 then .error (.invalidWitnessVersion v)
            else if v ≠ 0 ∧ v ≠ 1 then .error (.unsupportedWitnessVersion v)
            else
              let expected := if v = 0 then Encoding.bech32 else Encoding.bech32m
              if d.encoding ≠ expected then .error (.wrongEncoding v d.encoding)
              else
                match dataToBytes rest with
                | none => .error .invalidPadding
                | some prog =>
                    if v = 0 then
                      if prog.size ≠ 20 ∧ prog.size ≠ 32 then
                        .error (.badProgramLength 0 prog.size)
                      else .ok ⟨v, prog⟩
                    else if prog.size ≠ 32 then
                      .error (.badProgramLength 1 prog.size)
                    else .ok ⟨v, prog⟩

/-! ## Conformance vectors

The Bech32 and Bech32m strings are the valid/invalid lists in BIP173 and
BIP350, also present in Core's `src/test/bech32_tests.cpp:15-159`
(valid Bech32 15-33, valid Bech32m 35-53, invalid Bech32 55-107, invalid
Bech32m 109-159).  The segwit addresses and their scriptPubKey hex are the
BIP173/BIP350 address vectors; they are the same construction Core
exercises through `src/test/key_io_tests.cpp:24-83` and
`src/test/data/key_io_valid.json`.
-/

namespace Bech32Test

/-- Decode lowercase hexadecimal.  Test plumbing only. -/
private def hexDecode (s : String) : ByteArray :=
  let digit (c : Char) : Option Nat :=
    let n := c.toNat
    if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
    else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
    else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
    else none
  let rec go : List Char → ByteArray → ByteArray
    | a :: b :: rest, acc =>
        match digit a, digit b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => acc
    | _, acc => acc
  go s.toList ByteArray.empty

/-- `(string, expected checksum variant)`. -/
def validStrings : List (String × Encoding) :=
  [
    ("A12UEL5L", .bech32),
    ("a12uel5l", .bech32),
    ("an83characterlonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1tt5tgs", .bech32),
    ("abcdef1qpzry9x8gf2tvdw0s3jn54khce6mua7lmqqqxw", .bech32),
    ("11qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqc8247j", .bech32),
    ("split1checkupstagehandshakeupstreamerranterredcaperred2y9e3w", .bech32),
    ("?1ezyfcl", .bech32),
    ("A1LQFN3A", .bech32m),
    ("a1lqfn3a", .bech32m),
    ("an83characterlonghumanreadablepartthatcontainsthetheexcludedcharactersbioandnumber11sg7hg6", .bech32m),
    ("abcdef1l7aum6echk45nj3s0wdvt2fg8x9yrzpqzd3ryx", .bech32m),
    ("11llllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllllludsr8", .bech32m),
    ("split1checkupstagehandshakeupstreamerranterredcaperredlc445v", .bech32m),
    ("?1v759aa", .bech32m)
  ]

/-- Decode and report the checksum variant. -/
private def decodesAs (s : String) (enc : Encoding) : Bool :=
  match bech32Decode s with
  | .ok d => d.encoding = enc
  | .error _ => false

/-- Decode, re-encode, and compare case-insensitively (Core's test uses
`CaseInsensitiveEqual`, `src/test/bech32_tests.cpp:31,51`). -/
private def roundTrips (s : String) : Bool :=
  match bech32Decode s with
  | .ok d =>
      match bech32Encode d.encoding d.hrp d.data with
      | .ok out => out = asciiLowerString s
      | .error _ => false
  | .error _ => false

def validStringChecks : List (String × Bool) :=
  validStrings.map fun (s, enc) =>
    (s!"bech32 vector {s} ({repr enc})", decodesAs s enc && roundTrips s)

/-- `(hrp, address, version, program hex, BIP source)`. -/
def validSegwit : List (String × String × Nat × String × String) :=
  [
    ("bc", "BC1QW508D6QEJXTDG4Y5R3ZARVARY0C5XW7KV8F3T4", 0,
     "751e76e8199196d454941c45d1b3a323f1433bd6", "BIP173 valid v0/P2WPKH"),
    ("tb", "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sl5k7", 0,
     "1863143c14c5166804bd19203356da136c985678cd4d27a1b8c6329604903262", "BIP173 valid v0/P2WSH"),
    ("tb", "tb1qqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesrxh6hy", 0,
     "000000c4a5cad46221b2a187905e5266362b99d5e91c6ce24d165dab93e86433", "BIP350 valid v0/P2WSH"),
    ("tb", "tb1pqqqqp399et2xygdj5xreqhjjvcmzhxw4aywxecjdzew6hylgvsesf3hn0c", 1,
     "000000c4a5cad46221b2a187905e5266362b99d5e91c6ce24d165dab93e86433", "BIP350 valid v1"),
    ("bc", "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqzk5jj0", 1,
     "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798", "BIP350 valid v1")
  ]

/-- Both directions: decode the official address, and independently encode
the announced program to the same lowercase string. -/
def validSegwitChecks : List (String × Bool) :=
  validSegwit.map fun (hrp, addr, version, progHex, src) =>
    let wp : WitnessProgram := ⟨version, hexDecode progHex⟩
    let encodeOk :=
      match encodeSegwit hrp wp with
      | .ok got => got = asciiLowerString addr
      | .error _ => false
    let decodeOk :=
      match decodeSegwit hrp addr with
      | .ok d =>
          d.version = version && (Bitcoin.Data.toHex d.program == progHex) &&
            (match encodeSegwit hrp d with
             | .ok got => got = asciiLowerString addr
             | .error _ => false)
      | .error _ => false
    (s!"segwit {src}: {addr}", encodeOk && decodeOk)

/-- Bech32 failures with the error class they must produce. -/
private def bech32Fails (s : String) (p : Bech32Error → Bool) : Bool :=
  match bech32Decode s with
  | .error e => p e
  | .ok _ => false

/-- Segwit failures with the error class they must produce. -/
private def segwitFails (hrp s : String) (p : SegwitError → Bool) : Bool :=
  match decodeSegwit hrp s with
  | .error e => p e
  | .ok _ => false

/-- Eight generic Bech32/Bech32m negative vectors from
`src/test/bech32_tests.cpp:57-74,111-128` plus structural cases. -/
def invalidBech32Checks : List (String × Bool) :=
  [
    ("hrp char out of range (bech32_tests.cpp:58)",
      bech32Fails (String.ofList (Char.ofNat 32 :: "1nwldj5".toList))
        fun e => match e with | .invalidCharacter 0 => true | _ => false),
    ("no separator (bech32_tests.cpp:62)",
      bech32Fails "pzry9x0s0muk" fun e => match e with
        | .missingSeparator => true | _ => false),
    ("empty hrp (bech32_tests.cpp:63)",
      bech32Fails "1pzry9x0s0muk" fun e => match e with
        | .invalidSeparator 0 => true | _ => false),
    ("invalid data char (bech32_tests.cpp:64)",
      bech32Fails "x1b4n0q5v" fun e => match e with
        | .invalidBase32 2 => true | _ => false),
    ("too short checksum (bech32_tests.cpp:65)",
      bech32Fails "li1dgmt3" fun e => match e with
        | .invalidSeparator 2 => true | _ => false),
    ("uppercase-hrp checksum (bech32_tests.cpp:67)",
      bech32Fails "A1G7SGD8" fun e => match e with
        | .invalidChecksum => true | _ => false),
    ("mixed case (bech32_tests.cpp:70)",
      bech32Fails "a12UEL5L" fun e => match e with
        | .mixedCase => true | _ => false),
    ("over 90 chars (bech32_tests.cpp:74)",
      bech32Fails (String.ofList (List.replicate 100 'q')) fun e => match e with
        | .tooLong 90 => true | _ => false),
    ("bech32m no separator (bech32_tests.cpp:115)",
      bech32Fails "qyrz8wqd2c9m" fun e => match e with
        | .missingSeparator => true | _ => false),
    ("bech32m invalid data char (bech32_tests.cpp:118)",
      bech32Fails "y1b0jsk6g" fun e => match e with
        | .invalidBase32 2 => true | _ => false),
    ("bech32m uppercase-hrp checksum (bech32_tests.cpp:123)",
      bech32Fails "M1VUXWEZ" fun e => match e with
        | .invalidChecksum => true | _ => false),
    ("bech32m over 90 chars (bech32_tests.cpp:115)",
      bech32Fails
        "an84characterslonghumanreadablepartthatcontainsthetheexcludedcharactersbioandnumber11d6pts4"
        fun e => match e with | .tooLong 90 => true | _ => false)
  ]

/-- Segwit negative vectors.  Each entry names the expected in-model error
class; BIP173/BIP350 reasons are in the labels. -/
def invalidSegwitChecks : List (String × Bool) :=
  [
    ("wrong hrp (BIP173 tc1...)",
      segwitFails "bc" "tc1qw508d6qejxtdg4y5r3zarvary0c5xw7kg3g4ty"
        fun e => match e with | .wrongHrp "bc" "tc" => true | _ => false),
    ("bad checksum (BIP173 ...v8f3t5)",
      segwitFails "bc" "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t5"
        fun e => match e with | .bech32 .invalidChecksum => true | _ => false),
    ("witness version 17 (BIP173 BC13W...)",
      segwitFails "bc" "BC13W508D6QEJXTDG4Y5R3ZARVARY0C5XW7KN40WF2"
        fun e => match e with | .invalidWitnessVersion 17 => true | _ => false),
    ("v0 wrong length (BIP173 BC1QR...)",
      segwitFails "bc" "BC1QR508D6QEJXTDG4Y5R3ZARVARYV98GJ9P"
        fun e => match e with | .badProgramLength 0 16 => true | _ => false),
    ("mixed case (BIP173 ...q0sL5k7)",
      segwitFails "tb" "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sL5k7"
        fun e => match e with | .bech32 .mixedCase => true | _ => false),
    ("v0 non-zero padding (BIP173 ...pjxtptv)",
      segwitFails "tb" "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3pjxtptv"
        fun e => match e with | .invalidPadding => true | _ => false),
    ("empty data section (BIP173 bc1gmk9yu)",
      segwitFails "bc" "bc1gmk9yu" fun e => match e with
        | .emptyData => true | _ => false),
    ("v1 uses bech32 (BIP350 ...qh2y7hd)",
      segwitFails "bc" "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vqh2y7hd"
        fun e => match e with | .wrongEncoding 1 .bech32 => true | _ => false),
    ("v0 uses bech32m (BIP350 ...kemeawh)",
      segwitFails "bc" "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kemeawh"
        fun e => match e with | .wrongEncoding 0 .bech32m => true | _ => false),
    ("v1 one-byte program (BIP350 bc1pw5dgrnzv)",
      segwitFails "bc" "bc1pw5dgrnzv" fun e => match e with
        | .badProgramLength 1 1 => true | _ => false),
    ("v1 41-byte program (BIP350 ...253zgeav)",
      segwitFails "bc"
        "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7v8n0nx0muaewav253zgeav"
        fun e => match e with | .badProgramLength 1 41 => true | _ => false),
    ("v1 zero padding over four bits (BIP350 ...07qwwzcrf)",
      segwitFails "bc"
        "bc1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7v07qwwzcrf"
        fun e => match e with | .invalidPadding => true | _ => false),
    ("v1 non-zero padding (BIP350 ...pggkg4j)",
      segwitFails "tb"
        "tb1p0xlxvlhemja6c4dqv22uapctqupfhlxm9h8z3k2e72q4k9hcz7vpggkg4j"
        fun e => match e with | .invalidPadding => true | _ => false)
  ]

/-- Print one PASS/FAIL line per check and a summary. -/
private def runChecks (checks : List (String × Bool)) : IO Unit := do
  let mut pass := 0
  let mut fail := 0
  for (name, ok) in checks do
    if ok then
      pass := pass + 1
      IO.println s!"PASS {name}"
    else
      fail := fail + 1
      IO.println s!"FAIL {name}"
  IO.println s!"SUMMARY pass={pass} fail={fail}"

end Bech32Test

open Bech32Test in
#eval runChecks (validStringChecks ++ validSegwitChecks ++
  invalidBech32Checks ++ invalidSegwitChecks)

end Bitcoin.Wallet.Encoding
