import Bitcoin.Data.Basic
import Bitcoin.Crypto.Seam.Hash

/-!
# Bitcoin.Wallet.Encoding.Base58

The base-58 alphabet, the integer radix conversion behind it, and the
truncated-double-SHA256 checksum used by legacy Bitcoin addresses and
extended-key serialisation.  The implementation follows Bitcoin Core
`cce32b168` (`src/base58.cpp`, `src/base58.h`):

* alphabet `123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz`
  (`src/base58.cpp:19-20`), chosen to omit `0`, `I`, `O`, and `l`;
* encoding is a repeated division of a big-endian integer by 58, with one
  leading `1` per leading zero byte (`src/base58.cpp:89-127`);
* decoding is the inverse multiply-and-add, again preserving leading
  zero bytes (`src/base58.cpp:40-87`);
* `EncodeBase58Check` appends the first four bytes of `SHA256(SHA256(x))`
  before encoding (`src/base58.cpp:137-144`); `DecodeBase58Check` splits
  those four bytes off and compares them (`src/base58.cpp:146-161`).

The arithmetic is `Nat`, so there is no fixed-width overflow: Core bounds
the result through `max_ret_len` instead of through a big-integer type.
`base58Decode` mirrors that bound and reports `tooLong` with the limit
that was exceeded.  `base58CheckDecode` reserves four extra bytes for the
checksum, exactly as Core does at `src/base58.cpp:148` (its int-overflow
guard is elided because Lean's `Nat` cannot wrap).

## What is not modelled

* No WIF private-key parsing or serialisation, no BIP38 encrypted keys, and
  no address book: this module only turns bytes into text and back.
* Core skips leading and trailing ASCII whitespace and rejects embedded
  NUL (`src/base58.cpp:42-45,74-78,131-133,165-167`).  This model accepts
  no whitespace and no NUL at all; every character outside the alphabet
  is `badCharacter`.  Address parsing in Core depends on the whitespace
  behaviour, so callers must not assume these decoders are drop-in
  replacements for `DecodeBase58`.
* The alphabet is fixed to Bitcoin's; alternative base58 alphabets used
  by other systems are out of scope.
* `base58EncodeNat` is a canonical digit string with no leading `1`
  (and the empty string for zero).  It is an arithmetic helper, not an
  address encoding; the byte-level functions carry the zero-byte rule.
-/

namespace Bitcoin.Wallet.Encoding

open Bitcoin.Crypto.Seam.Hash (sha256d)

/-! ## Alphabet and character lookup -/

/-- Bitcoin's base58 alphabet, in value order (`src/base58.cpp:19-20`). -/
def base58Alphabet : String :=
  "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

/-- The alphabet as characters, for indexed lookups. -/
def base58AlphabetChars : List Char := base58Alphabet.toList

/-- Value of a base58 character, or `none` when it is not in the
alphabet (the analogue of `mapBase58[c] == -1`, `src/base58.cpp:21-38`). -/
def base58Value? (c : Char) : Option Nat :=
  let rec go (i : Nat) : List Char → Option Nat
    | [] => none
    | d :: ds => if d = c then some i else go (i + 1) ds
  go 0 base58AlphabetChars

/-- Decoding failures.  `badCharacter` records the first character that is
not in the alphabet; `tooLong` records the caller's byte budget;
`tooShort` is `DecodeBase58Check`'s `vchRet.size() < 4` branch
(`src/base58.cpp:149`); `checksumMismatch` is the `memcmp` failure at
`src/base58.cpp:155`. -/
inductive Base58Error where
  | badCharacter (c : Char)
  | checksumMismatch
  | tooLong (maxLen : Nat)
  | tooShort
deriving Repr, DecidableEq

/-! ## Integer radix conversion -/

/-- Big-endian base-256 value of a byte list. -/
def bytesToNatBE (l : List UInt8) : Nat :=
  l.foldl (fun acc b => acc * 256 + b.toNat) 0

/-- Minimal big-endian base-256 digits of a `Nat`; zero has no digits. -/
def natToBytesBE (n : Nat) : List UInt8 :=
  let rec go (fuel n : Nat) (acc : List UInt8) : List UInt8 :=
    match fuel with
    | 0 => acc
    | fuel + 1 =>
        if n = 0 then acc
        else go fuel (n / 256) ((n % 256).toUInt8 :: acc)
  go (n + 1) n []

/-- Minimal base58 digits of a `Nat`, most significant first; zero has no
digits.  The fuel is the input value, which strictly decreases while the
quotient is nonzero. -/
def base58DigitsNat (n : Nat) : List Char :=
  let rec go (fuel n : Nat) (acc : List Char) : List Char :=
    match fuel with
    | 0 => acc
    | fuel + 1 =>
        if n = 0 then acc
        else
          let d := n % 58
          go fuel (n / 58) (base58AlphabetChars.getD d '1' :: acc)
  go (n + 1) n []

/-- Canonical base58 spelling of a natural number, without leading zeroes.
Zero is the empty string; use `base58Encode` for the byte-level rule that
maps a zero byte to the character `1`. -/
def base58EncodeNat (n : Nat) : String :=
  String.ofList (base58DigitsNat n)

/-- Value of a base58 digit string.  Leading `1`s contribute zero, as in
the byte-level decoder. -/
def base58DecodeNat (s : String) : Except Base58Error Nat :=
  let rec go : List Char → Nat → Except Base58Error Nat
    | [], acc => .ok acc
    | c :: cs, acc =>
        match base58Value? c with
        | none => .error (.badCharacter c)
        | some d => go cs (acc * 58 + d)
  go s.toList 0

/-! ## Byte encoding and decoding -/

/-- Number of leading zero bytes. -/
def countLeadingZeroBytes (l : List UInt8) : Nat :=
  match l with
  | [] => 0
  | b :: bs => if b = 0 then 1 + countLeadingZeroBytes bs else 0

/-- Base58 encoding of a byte string.  One `1` is emitted for every leading
zero byte, then the remaining bytes are treated as one big-endian integer
(`src/base58.cpp:89-127`). -/
def base58Encode (b : ByteArray) : String :=
  let l := b.toList
  let zeros := countLeadingZeroBytes l
  let rest := l.drop zeros
  String.ofList (List.replicate zeros '1' ++ base58DigitsNat (bytesToNatBE rest))

/-- Base58 decoding into bytes, with Core's byte budget `max_ret_len`
(`src/base58.cpp:30,50,71`).  Leading `1`s become leading zero bytes; the
remaining characters are one big-endian integer written with the minimal
number of bytes. -/
def base58Decode (s : String) (maxLen : Nat) : Except Base58Error ByteArray :=
  let rec splitZeros : List Char → Nat × List Char
    | [] => (0, [])
    | '1' :: cs => let (z, rest) := splitZeros cs; (z + 1, rest)
    | cs => (0, cs)
  let (zeros, rest) := splitZeros s.toList
  if zeros > maxLen then .error (.tooLong maxLen)
  else
    match base58DecodeNat (String.ofList rest) with
    | .error e => .error e
    | .ok n =>
        let bytes := natToBytesBE n
        if zeros + bytes.length > maxLen then .error (.tooLong maxLen)
        else
          .ok (List.toByteArray
            (List.replicate zeros (0 : UInt8) ++ bytes))

/-! ## Base58Check -/

/-- `EncodeBase58Check`: payload followed by the first four bytes of its
double SHA-256 (`src/base58.cpp:137-144`).  `sha256d` is the existing
executable hash from `Bitcoin.Crypto.Seam.Hash`; it is not reimplemented
here. -/
def base58CheckEncode (payload : ByteArray) : String :=
  let checksum := (sha256d payload).extract 0 4
  base58Encode (payload ++ checksum)

/-- `DecodeBase58Check`: decode, require at least four bytes, recompute the
truncated double SHA-256 over the payload, and compare (`src/base58.cpp:
146-161`).  The budget is applied to the decoded bytes including the
checksum, which is Core's `max_ret_len + 4` (`src/base58.cpp:148`). -/
def base58CheckDecode (s : String) (maxLen : Nat) : Except Base58Error ByteArray :=
  match base58Decode s (maxLen + 4) with
  | .error e => .error e
  | .ok raw =>
      if raw.size < 4 then .error .tooShort
      else
        let payload := raw.extract 0 (raw.size - 4)
        let supplied := raw.extract (raw.size - 4) raw.size
        let expected := (sha256d payload).extract 0 4
        if Bitcoin.Data.bytesBEq supplied expected then .ok payload
        else .error .checksumMismatch

/-! ## Conformance vectors

The encode/decode vectors are the JSON corpus consumed by
`src/test/base58_tests.cpp:27,50-60` (`src/test/data/base58_encode_decode.json`,
line numbers below).  The Base58Check payloads are the address vectors in
`src/test/key_io_valid.json` as consumed by `src/test/key_io_tests.cpp:38,53`;
the invalid-checksum pair is `src/test/base58_tests.cpp:79-82`.
-/

namespace Base58Test

/-- Decode a lowercase hexadecimal string.  Test plumbing only. -/
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

/-- `(input hex, base58 text, JSON line)`. -/
def encodeVectors : List (String × String × Nat) :=
  [
    ("", "", 2),
    ("61", "2g", 3),
    ("626262", "a3gV", 4),
    ("73696d706c792061206c6f6e6720737472696e67",
     "2cFupjhnEsSn59qHXstmK2ffpLv2", 6),
    ("00eb15231dfceb60925886b67d065299925915aeb172c06647",
     "1NS17iag9jJgTHD1VXjvLCEnZuQ3rJDE9L", 7),
    ("00000000000000000000", "1111111111", 13),
    ("00000000000000000000000000000000000000000000000000000000000000000000000000000001",
     "1111111111111111111111111111111111111112", 15),
    ("000111d38e5fc9071ffcd20b4a763cc9ae4f252bb4e48fd66a835e252ada93ff480d6dd43dc62a641155a5",
     "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz", 17),
    ("271F359E", "zzzzy", 19),
    ("271F35A0", "211111", 21)
  ]

/-- `(address, payload hex, JSON line)` for Base58Check.  Payloads include
the address-version byte (mainnet P2PKH/P2SH, testnet4, regtest), so these
check the checksum and the leading-zero path without modelling address
semantics. -/
def checkVectors : List (String × String × Nat) :=
  [
    ("1FsSia9rv4NeEwvJ2GvXrX7LyxYspbN2mo",
     "00a31c06bd463e3923bc1aadbde48b16976c080717", 3),
    ("36j4NfKv6Akva9amjWrLG6MuSQym1GuEmm",
     "05373b819a068f32b7a6b38b6b38729647cfde01c2", 11),
    ("mzK2FFDEhxqHcmrJw1ysqFkVyhUULo45hZ",
     "6fce28b26c57472737f5c3561a1761185bd8589a43", 19),
    ("n4fajahJrAuKbN7uNsKjLjQkz9Qn5ewJXQ",
     "6ffdeca3b08e38af53d7c4c60e3ad208ce50664410", 51),
    ("2MxFajLApXpYk4VodBSZSt7rw8y4ryABkfA",
     "c436e9f191e0b75036a77f65e2eaa4752443233fbe", 59),
    ("3vQB7B6MrGQZaxCuFg4oh",
     "68656c6c6f20776f726c64", 79)
  ]

/-- Every byte-vector encodes and decodes exactly. -/
def encodeVectorsOk : List (String × Bool) :=
  encodeVectors.map fun (hex, expected, line) =>
    let bytes := hexDecode hex
    let encoded := base58Encode bytes
    let decodedOk :=
      match base58Decode expected 256 with
      | .ok got => Bitcoin.Data.bytesBEq got bytes
      | .error _ => false
    (s!"base58 encode/decode json:{line}",
      (encoded == expected) && decodedOk)

/-- Every Base58Check address decodes to the announced payload and
re-encodes byte-for-byte. -/
def checkVectorsOk : List (String × Bool) :=
  checkVectors.map fun (address, payloadHex, line) =>
    let payload := hexDecode payloadHex
    let decodedOk :=
      match base58CheckDecode address 21 with
      | .ok got => Bitcoin.Data.bytesBEq got payload
      | .error _ => false
    (s!"base58check key_io_valid.json:{line} (key_io_tests.cpp:38,53)",
      decodedOk && (base58CheckEncode payload == address))

/-- Failure cases with the error class they must produce.  The first four
are characters Core's `mapBase58` marks invalid (`src/base58_tests.cpp:64-71`);
the next is the mismatched checksum at `src/base58_tests.cpp:80`; the last
two exercise the byte budget at `src/base58_tests.cpp:74` and the
less-than-four-bytes branch at `src/base58.cpp:149`. -/
def negativeCases : List (String × Bool) :=
  [
    ("bad char 0", match base58Decode "bad0IOl" 100 with
      | .error (.badCharacter '0') => true | _ => false),
    ("bad char I", match base58Decode "I" 100 with
      | .error (.badCharacter 'I') => true | _ => false),
    ("bad char O", match base58Decode "O" 100 with
      | .error (.badCharacter 'O') => true | _ => false),
    ("bad char l", match base58Decode "l" 100 with
      | .error (.badCharacter 'l') => true | _ => false),
    ("bad checksum base58check",
      match base58CheckDecode "3vQB7B6MrGQZaxCuFg4oi" 100 with
      | .error .checksumMismatch => true | _ => false),
    ("checksum payload too long", match base58CheckDecode
        ("3vQB7B6MrGQZaxCuFg4oh" ++ "0IOl") 100 with
      | .error (.badCharacter '0') => true | _ => false),
    ("too long decode", match base58Decode "1111" 3 with
      | .error (.tooLong 3) => true | _ => false),
    ("too short base58check", match base58CheckDecode "1" 100 with
      | .error .tooShort => true | _ => false)
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

end Base58Test

open Base58Test in
#eval runChecks (encodeVectorsOk ++ checkVectorsOk ++ negativeCases)

end Bitcoin.Wallet.Encoding
