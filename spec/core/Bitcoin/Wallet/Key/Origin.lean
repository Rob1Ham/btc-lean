import Bitcoin.Data.Basic

/-!
# Bitcoin.Wallet.Key.Origin

Parsers for the two path grammars a wallet key expression carries:

* a BIP32 derivation path written from the master, `m/84h/0h/0h/0/5`
  (BIP32 "The key tree": `m/3H/2/5` denotes three nested CKD steps);
* a key origin, `fingerprint/path`, whose fingerprint is the first four
  bytes of `HASH160` of the root public key and whose path is relative to
  that root (BIP380 `KEYORIGIN = "[" FINGERPRINT { "/" CHILDNUM } "]"`,
  with the brackets added by the descriptor grammar).

Both parsers return structured values: a `ChildNumber` keeps the raw
index and the hardened bit separately, so no caller has to recover the
bit by masking; a `KeyOrigin` keeps the four fingerprint bytes and the
list of child numbers.

## Grammar and error taxonomy

A component is ASCII digits with an optional trailing `'` or `h`
(hardened). Core accepts exactly those two suffixes and no other marker
(`src/util/bip32.cpp:24-29`), parses the digits as `uint32_t`
(`src/util/bip32.cpp:31-34`), and rejects values at or above
`BIP32_HARDENED_FLAG` (`src/util/bip32.cpp:35-37`). A full path must
begin with `m`; a second `m` is rejected (`src/util/bip32.cpp:41-60`).
The origin fingerprint must be exactly eight characters and hex; Core
reports the two failures separately (`src/script/descriptor.cpp:2228-2236`).

Each malformed shape gets its own constructor of `OriginError`:

| constructor | rejected input |
|---|---|
| `emptyElement` | `""`, `m/`, `m//0`, `fpr/` |
| `emptyIndex` | `"'"`, `"h"` |
| `nonNumeric` | `1x`, `-1`, `1H`, `+1`, whitespace |
| `indexOutOfRange` | a decimal value of 2^31 or more |
| `missingRoot` | a full path not beginning with `m` |
| `unexpectedRoot` | `m` in a non-initial position |
| `emptyFingerprint` | empty text before the first `/` |
| `fingerprintLength` | a fingerprint whose character count is not 8 |
| `fingerprintNotHex` | eight characters containing a non-hex digit |
| `missingOpenBracket` | bracketed form without `[` |
| `missingCloseBracket` | bracketed form without a final `]` |

Empty components are errors rather than silently dropped: a trailing
slash is a typo in a descriptor and Core's splitter produces an empty
element that `ParseKeyPathElement` rejects (`src/util/bip32.cpp:20-22`).

## What is not modelled

No wildcard (`*`, `*'`, `*h`), no multipath (`<0;1>`), no whitespace
trimming, no normalization of `'` to `h`, and no range-descriptor
expansion. The parser does not decide whether an origin's fingerprint
matches any key: it only records the bytes. Uppercase `H` and uppercase
`M` are rejected, matching Core's byte comparisons.

## Checks

The `#eval` block at the bottom pins the accepted shapes and one
representative of every error constructor. The grammar references are
BIP32 "The key tree" and BIP380 §"Key Expressions"; Core anchors are
`src/util/bip32.cpp:17-39` and `src/script/descriptor.cpp:2220-2240`.
-/

namespace Bitcoin.Wallet.Key

/-- One BIP32 child-number component. `index` is the unhardened value
(strictly below 2^31) and `hardened` records the apostrophe/`h` suffix. -/
structure ChildNumber where
  index : Nat
  hardened : Bool
  lt : index < 0x80000000

/-- The 32-bit child number sent on the wire: `index` with bit 31 set
for a hardened step (BIP32 "Extended keys"; Core `KeyPathElement::ChildNumber`,
`src/util/bip32.h:19-25`). -/
def ChildNumber.toUInt32 (c : ChildNumber) : UInt32 :=
  c.index.toUInt32 ||| (if c.hardened then 0x80000000 else 0)

/-- A parsed key origin: four fingerprint bytes and a relative path. -/
structure KeyOrigin where
  fingerprint : ByteArray
  path : List ChildNumber

/-- Parse failures, one constructor per rejected shape. -/
inductive OriginError where
  | emptyElement
  | emptyIndex
  | nonNumeric
  | indexOutOfRange
  | missingRoot
  | unexpectedRoot
  | emptyFingerprint
  | fingerprintLength (n : Nat)
  | fingerprintNotHex
  | missingOpenBracket
  | missingCloseBracket
  deriving Repr, DecidableEq

/-! ## Lexical helpers -/

/-- ASCII decimal digit test; `Char.isDigit` would also accept non-ASCII
digits, which BIP32 does not. -/
def isAsciiDigit (c : Char) : Bool :=
  let n := c.toNat
  decide (48 ≤ n ∧ n ≤ 57)

/-- Value of one hexadecimal digit, lower- or uppercase. -/
def hexDigit (c : Char) : Option UInt8 :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48).toUInt8
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87).toUInt8
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55).toUInt8
  else none

/-- Split on one separator, preserving empty components. Structural on
the character list, so it needs no fuel and no partial definition. -/
def splitOnAux (sep : Char) (cur : List Char) (acc : List String) :
    List Char → List String
  | [] => acc.reverse ++ [String.ofList cur.reverse]
  | c :: cs =>
    if c = sep then splitOnAux sep [] (String.ofList cur.reverse :: acc) cs
    else splitOnAux sep (c :: cur) acc cs

/-- Split a string on `sep`, keeping empty components. -/
def splitOn (sep : Char) (s : String) : List String :=
  splitOnAux sep [] [] s.toList

/-- Decimal digits to a natural number, `none` on the first non-digit. -/
def digitsValueAux : Nat → List Char → Option Nat
  | acc, [] => some acc
  | acc, c :: cs =>
    if isAsciiDigit c then digitsValueAux (acc * 10 + (c.toNat - 48)) cs else none

/-- Parse one child-number component, accepting `'` or `h` as the
hardened marker and rejecting values of 2^31 or more. -/
def parseChildNumber (s : String) : Except OriginError ChildNumber :=
  match s.toList with
  | [] => .error .emptyElement
  | cs =>
    let (body, hardened) :=
      match cs.getLast? with
      | some c => if c = '\'' || c = 'h' then (cs.dropLast, true) else (cs, false)
      | none => (cs, false)
    if body.isEmpty then .error .emptyIndex
    else
      match digitsValueAux 0 body with
      | none => .error .nonNumeric
      | some v =>
        if h : v < 0x80000000 then .ok ⟨v, hardened, h⟩
        else .error .indexOutOfRange

/-- Parse a sequence of child-number components (no `m`). -/
def parseChildNumbers : List String → Except OriginError (List ChildNumber)
  | [] => .ok []
  | x :: xs =>
    if x = "m" then .error .unexpectedRoot
    else
      match parseChildNumber x with
      | .error e => .error e
      | .ok c =>
        match parseChildNumbers xs with
        | .error e => .error e
        | .ok cs => .ok (c :: cs)

/-- A full BIP32 path from the master, e.g. `m/84h/0h/0h/0/5`.
The bare root `m` is the empty path. -/
def parsePath (s : String) : Except OriginError (List ChildNumber) :=
  match splitOn '/' s with
  | [] => .error .missingRoot
  | root :: rest =>
    if root = "m" then parseChildNumbers rest else .error .missingRoot

/-- Eight hex characters to four bytes. -/
def parseFingerprint (s : String) : Option ByteArray :=
  match s.toList with
  | [a, b, c, d, e, f, g, h] =>
    match hexDigit a, hexDigit b, hexDigit c, hexDigit d,
          hexDigit e, hexDigit f, hexDigit g, hexDigit h with
    | some x0, some x1, some x2, some x3,
      some x4, some x5, some x6, some x7 =>
      some (ByteArray.mk #[x0 * 16 + x1, x2 * 16 + x3,
                          x4 * 16 + x5, x6 * 16 + x7])
    | _, _, _, _, _, _, _, _ => none
  | _ => none

/-- Parse a key origin in body form, `fingerprint/path` (the text that
BIP380 places between `[` and `]`). -/
def parseOrigin (s : String) : Except OriginError KeyOrigin :=
  match splitOn '/' s with
  | [] => .error .emptyFingerprint
  | fpr :: rest =>
    if fpr = "" then .error .emptyFingerprint
    else if fpr.toList.length ≠ 8 then .error (.fingerprintLength fpr.toList.length)
    else
      match parseFingerprint fpr with
      | none => .error .fingerprintNotHex
      | some fp =>
        match parseChildNumbers rest with
        | .error e => .error e
        | .ok path => .ok ⟨fp, path⟩

/-- Parse the bracketed BIP380 form `[fingerprint/path]`. -/
def parseOriginBracketed (s : String) : Except OriginError KeyOrigin :=
  match s.toList with
  | '[' :: rest =>
    match rest.getLast? with
    | some ']' => parseOrigin (String.ofList rest.dropLast)
    | some _ => .error .missingCloseBracket
    | none => .error .missingCloseBracket
  | _ => .error .missingOpenBracket

/-! ## Structural lemmas -/

/-- The path parser accepts the bare master path. -/
theorem parsePath_root : parsePath "m" = .ok [] := rfl

/-- Every parsed child number is below the hardened flag; the bound is
part of the value, so this is projection rather than arithmetic. -/
theorem parseChildNumber_range (c : ChildNumber) : c.index < 0x80000000 :=
  c.lt

/-! ## Checks -/

/-- Test view of a path: index and hardened flag per component. -/
def pathView (p : List ChildNumber) : List (Nat × Bool) :=
  p.map (fun c => (c.index, c.hardened))

def okPath (r : Except OriginError (List ChildNumber)) :
    Option (List (Nat × Bool)) :=
  match r with
  | .ok p => some (pathView p)
  | .error _ => none

def okOrigin (r : Except OriginError KeyOrigin) :
    Option (String × List (Nat × Bool)) :=
  match r with
  | .ok o => some (Bitcoin.Data.toHex o.fingerprint, pathView o.path)
  | .error _ => none

def errOf (r : Except OriginError α) : Option OriginError :=
  match r with
  | .error e => some e
  | .ok _ => none

def bip84 : Option (List (Nat × Bool)) :=
  some [(84, true), (0, true), (0, true), (0, false), (5, false)]

#eval s!"path m/84h/... = {okPath (parsePath "m/84h/0h/0h/0/5") == bip84}"
#eval s!"path apostrophe   = {okPath (parsePath "m/84'/0'/0'/0/5") == bip84}"
#eval s!"path m            = {okPath (parsePath "m") == some []}"
#eval s!"origin body       = {okOrigin (parseOrigin "d34db33f/84h/0h/0h/0/5") ==
  some ("d34db33f", [(84, true), (0, true), (0, true), (0, false), (5, false)])}"
#eval s!"origin bracketed  = {okOrigin (parseOriginBracketed "[d34db33f/84h/0h/0h/0/5]") ==
  some ("d34db33f", [(84, true), (0, true), (0, true), (0, false), (5, false)])}"
#eval s!"origin no path    = {okOrigin (parseOrigin "D34DB33F") == some ("d34db33f", [])}"
#eval s!"err missingRoot   = {errOf (parsePath "84h/0h") == some .missingRoot}"
#eval s!"err emptyElement  = {errOf (parsePath "m/") == some .emptyElement}"
#eval s!"err doubleSlash   = {errOf (parsePath "m//0") == some .emptyElement}"
#eval s!"err nonNumeric    = {errOf (parsePath "m/1H") == some .nonNumeric}"
#eval s!"err outOfRange    = {errOf (parsePath "m/2147483648") == some .indexOutOfRange}"
#eval s!"err unexpectedRoot= {errOf (parsePath "m/m") == some .unexpectedRoot}"
#eval s!"err fpr length    = {errOf (parseOrigin "d34db3f/0h") == some (.fingerprintLength 7)}"
#eval s!"err fpr not hex   = {errOf (parseOrigin "zzzzzzzz/0h") == some .fingerprintNotHex}"
#eval s!"err origin empty  = {errOf (parseOrigin "d34db33f/") == some .emptyElement}"
#eval s!"err no open       = {errOf (parseOriginBracketed "d34db33f/0h") == some .missingOpenBracket}"
#eval s!"err no close      = {errOf (parseOriginBracketed "[d34db33f/0h") == some .missingCloseBracket}"

end Bitcoin.Wallet.Key
