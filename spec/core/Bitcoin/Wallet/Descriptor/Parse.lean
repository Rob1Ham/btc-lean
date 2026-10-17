import Bitcoin.Wallet.Descriptor.Ast
import Bitcoin.Wallet.Descriptor.Checksum
import Bitcoin.Crypto.Seam.Hash
import Bitcoin.Crypto.Curve.Secp

/-!
# Bitcoin.Wallet.Descriptor.Parse

A recursive-descent parser for the descriptor fragment in
`Bitcoin.Wallet.Descriptor.Ast`, with Core's checksum gate.

## Grammar

```
descriptor   ::= payload [ "#" checksum ]
checksum     ::= 8 characters of Core's checksum alphabet
payload      ::= "pk(" key ")"
               | "pkh(" key ")"
               | "wpkh(" key ")"
               | "sh(wpkh(" key "))"
               | ("multi" | "sortedmulti") "(" threshold ","
                    key ("," key)* ")"
               | "tr(" key ")"
key          ::= [ origin ] body path [ wildcard ]
origin       ::= "[" fingerprint ( "/" child )* "]"
fingerprint  ::= 8 hexadecimal characters
body         ::= hex-public-key | xpub
path         ::= ( "/" child )*
child        ::= decimal [ "'" | "h" ]
wildcard     ::= "/*" | "/*'" | "/*h"
```

`threshold` and each `child` are decimal. A child must be `< 2^31`; bit 31
is the hardened flag. Origin paths may not contain a wildcard and may not
contain multipath `<a;b>` specifiers. All of those restrictions are Core's
(`src/util/bip32.cpp:17-39`, `src/script/descriptor.cpp:1873-1962`).

## Error categories

The parser returns `Except DescriptorError Descriptor`. `DescriptorError`
separates the categories Core's `CheckChecksum` / `ParseScript` produce:

* `multipleChecksums`, `missingChecksum`, `checksumLength`,
  `checksumMismatch` — the `#` gate
  (`src/script/descriptor.cpp:2971-3008`);
* `invalidCharacter` — a payload character outside the input alphabet;
* `unexpectedToken` — wrong function, missing `(`, `)` or comma, trailing
  text, or an unsupported construct such as `combo()` / `wsh()` / a taproot
  script tree;
* `invalidKey` — malformed pubkey hex, invalid xpub Base58Check, bad key
  origin, whitespace, or a literal key with a derivation path;
* `keyPathRange` — a child number `>= 2^31`, an empty path element, a
  misplaced wildcard, or a multipath specifier;
* `threshold` — multisig cardinality/threshold violations.

The parser also validates compressed/uncompressed/x-only keys against the
secp256k1 curve using the existing `Bitcoin.Crypto.Curve.Secp` definitions,
and validates xpub Base58Check with the existing SHA-256 seam. It does not
derive children: the xpub text, path, origin, and wildcard are carried in
the AST.

## What is not modelled

Private keys (`xprv`/`tprv`), `addr`, `raw`, `combo`, `wsh`, bare `sh(...)`
other than `sh(wpkh(...))`, miniscript, taproot script trees, multipath
`<a;b>` keys, and the full BIP32 key-validity rules (depth/fingerprint/child
consistency inside the 78-byte xpub payload). Only the xpub/tpub version
bytes and the Base58Check checksum are checked, not whether the payload's
chain code or public key came from a particular master.
-/

namespace Bitcoin.Wallet.Descriptor

/-- Error categories mirroring Core's descriptor parse/checksum failures.
Each constructor carries enough context to print a diagnosis. -/
inductive DescriptorError where
  /-- More than one `#` in the input (`src/script/descriptor.cpp:2975-2978`). -/
  | multipleChecksums
  /-- A checksum was required but `#` was absent
  (`src/script/descriptor.cpp:2979-2982`). -/
  | missingChecksum
  /-- The supplied checksum is not exactly eight characters
  (`src/script/descriptor.cpp:2983-2987`). -/
  | checksumLength (found : Nat)
  /-- The payload contains a character outside Core's input alphabet
  (`src/script/descriptor.cpp:2989-2992`). -/
  | invalidCharacter (found : Char)
  /-- The provided checksum differs from the computed one
  (`src/script/descriptor.cpp:2993-2998`). -/
  | checksumMismatch (provided computed : String)
  /-- A token was not expected at this position. -/
  | unexpectedToken (expected found : String)
  /-- A key is not a valid literal key or extended public key. -/
  | invalidKey (detail : String)
  /-- A derivation path element is out of range or malformed. -/
  | keyPathRange (detail : String)
  /-- Multisig threshold/key-count rules failed. -/
  | threshold (detail : String)
  /-- A descriptor was used in a context this fragment does not allow. -/
  | context (detail : String)
deriving Repr, DecidableEq

/-- Human-readable form of a parse error. The wording follows Core's test
expectations where the categories coincide, but it is not a byte-for-byte
copy of every `strprintf`. -/
def DescriptorError.message : DescriptorError → String
  | .multipleChecksums => "Multiple '#' symbols"
  | .missingChecksum => "Missing checksum"
  | .checksumLength n => s!"Expected 8 character checksum, not {n} characters"
  | .invalidCharacter c => s!"Invalid characters in payload: '{c}'"
  | .checksumMismatch p c =>
      s!"Provided checksum '{p}' does not match computed checksum '{c}'"
  | .unexpectedToken expected found =>
      s!"Expected {expected}, got '{found}'"
  | .invalidKey detail => s!"Invalid key: {detail}"
  | .keyPathRange detail => s!"Key path error: {detail}"
  | .threshold detail => s!"Multisig error: {detail}"
  | .context detail => s!"Context error: {detail}"

/-! ## Low-level scanners -/

/-- Decimal digit test without relying on `Char.isDigit`. -/
private def isDigitChar (c : Char) : Bool :=
  let n := c.toNat
  48 ≤ n ∧ n ≤ 57

/-- ASCII alphabetic test; descriptor function names are ASCII. -/
private def isAlphaChar (c : Char) : Bool :=
  let n := c.toNat
  (65 ≤ n ∧ n ≤ 90) ∨ (97 ≤ n ∧ n ≤ 122)

/-- ASCII whitespace test. Core rejects whitespace at the ends of a key
(`src/script/descriptor.cpp:1994-1998`); this fragment rejects it anywhere
inside a key expression. -/
private def isSpaceChar (c : Char) : Bool :=
  c = ' ' ∨ c = '\t' ∨ c = '\n' ∨ c = '\r'

/-- Build a `ByteArray` from a list of bytes without relying on array
conversion APIs whose kernel reduction is fragile. -/
private def bytesOf (xs : List UInt8) : ByteArray :=
  xs.foldl (fun acc b => acc.push b) ByteArray.empty

/-- Hexadecimal digit value. -/
private def hexValue (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

/-- Whether every character is a hexadecimal digit (and the string is
non-empty). -/
private def isHexString (s : String) : Bool :=
  !s.isEmpty && s.toList.all (fun c => (hexValue c).isSome)

/-- Decode usual hexadecimal text. Returns `none` for an odd number of
characters or a non-hex character. -/
def hexDecode? (s : String) : Option ByteArray :=
  let rec go : List Char → Option (List UInt8)
    | [] => some []
    | [_] => none
    | a :: b :: rest => do
        let x ← hexValue a
        let y ← hexValue b
        let tail ← go rest
        pure ((x * 16 + y).toUInt8 :: tail)
  match go s.toList with
  | none => none
  | some xs => some (bytesOf xs)

/-- `n` as big-endian bytes, with no leading zero bytes (zero is the empty
byte string). Used only while decoding Base58Check. The 96-byte window is
ample for a 78-byte xpub payload plus its 4-byte checksum; a longer Base58
string is truncated to 96 bytes and consequently fails the 78-byte xpub
shape check rather than wrapping around. -/
private def natToBytesMinimal (n : Nat) : List UInt8 :=
  let bytes := (List.range 96).map fun i =>
    ((n / 256 ^ (95 - i)) % 256).toUInt8
  let rec dropZeros : List UInt8 → List UInt8
    | [] => []
    | 0 :: rest => dropZeros rest
    | x :: rest => x :: rest
  dropZeros bytes

/-- Base58 alphabet (`src/base58.cpp:28-30`). -/
private def base58Alphabet : String :=
  "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"

/-- Base58 value of one character. -/
private def base58Value (c : Char) : Option Nat := charsetIndex base58Alphabet c

/-- Count leading `1` characters, which encode leading zero bytes in
Base58 (`src/base58.cpp:DecodeBase58`). -/
private def leadingOnes : List Char → Nat
  | '1' :: rest => 1 + leadingOnes rest
  | _ => 0

/-- Decode Base58 text to bytes. `none` means an invalid character. -/
def base58Decode? (s : String) : Option ByteArray :=
  let rec go (cs : List Char) (acc : Nat) : Option Nat :=
    match cs with
    | [] => some acc
    | c :: rest =>
        match base58Value c with
        | none => none
        | some d => go rest (acc * 58 + d)
  match go s.toList 0 with
  | none => none
  | some n =>
      let zeros := leadingOnes s.toList
      some (bytesOf (List.replicate zeros 0 ++ natToBytesMinimal n))

/-- Decode Base58Check: strip and verify the four-byte double-SHA256
checksum (`src/base58.cpp:146-168`). Returns the payload without checksum. -/
def base58CheckDecode? (s : String) : Option ByteArray :=
  match base58Decode? s with
  | none => none
  | some data =>
      if data.size < 4 then none
      else
        let payload := data.extract 0 (data.size - 4)
        let provided := data.extract (data.size - 4) data.size
        let hash := Bitcoin.Crypto.Seam.Hash.sha256d payload
        if provided.size = 4 && hash.extract 0 4 = provided then some payload
        else none

/-- Descriptor parsing contexts. They decide which literal key shapes are
allowed and mirror `ParseScriptContext`
(`src/script/descriptor.cpp:1863-1871`). -/
inductive KeyContext where
  /-- Top-level `pk`, `pkh`, and bare multisig: compressed or uncompressed. -/
  | legacy
  /-- `wpkh` / `sh(wpkh)`: compressed keys only. -/
  | segwit
  /-- `tr(...)`: 32-byte x-only or 33-byte compressed keys. -/
  | taproot
deriving Repr, DecidableEq

/-- A 33-byte compressed key is valid when its prefix is `02`/`03` and the
x-coordinate lifts to a curve point. `liftX` already checks `x < p` and
that `x^3 + 7` is a square (`src/pubkey.cpp:CPubKey::IsFullyValid`). -/
def compressedKeyValid (b : ByteArray) : Bool :=
  b.size = 33 &&
    (b.get! 0 = 0x02 || b.get! 0 = 0x03) &&
    (Bitcoin.Crypto.Curve.Secp.liftX
      (Bitcoin.Crypto.Curve.Secp.bytesToNatBE (b.extract 1 33))).isSome

/-- A 65-byte uncompressed key is valid when its prefix is `04` and both
coordinates satisfy `y^2 = x^3 + 7 (mod p)`. -/
def uncompressedKeyValid (b : ByteArray) : Bool :=
  b.size = 65 && b.get! 0 = 0x04 &&
    let x := Bitcoin.Crypto.Curve.Secp.bytesToNatBE (b.extract 1 33)
    let y := Bitcoin.Crypto.Curve.Secp.bytesToNatBE (b.extract 33 65)
    x < Bitcoin.Crypto.Curve.Secp.P &&
      y < Bitcoin.Crypto.Curve.Secp.P &&
      Bitcoin.Crypto.Curve.Secp.onCurveN x y

/-- Whether a literal key is acceptable in a parsing context. Core permits
uncompressed keys at top level and inside `sh()`, but not in witness
contexts (`src/script/descriptor.cpp:1986`, `:2009-2023`). -/
def constKeyValid (ctx : KeyContext) (b : ByteArray) : Bool :=
  match ctx with
  | .legacy => compressedKeyValid b || uncompressedKeyValid b
  | .segwit => compressedKeyValid b
  | .taproot =>
      (b.size = 32 &&
        (Bitcoin.Crypto.Curve.Secp.liftX
          (Bitcoin.Crypto.Curve.Secp.bytesToNatBE b)).isSome) ||
      compressedKeyValid b

/-- The two extended-public-key version prefixes accepted here: mainnet
`xpub` (`0488B21E`) and testnet `tpub` (`043587CF`)
(`src/chainparams.cpp` EXT_PUBLIC_KEY; `src/key_io.cpp:246-256`). -/
private def xpubVersionOk (payload : ByteArray) : Bool :=
  payload.size = 78 &&
    (payload.extract 0 4 = bytesOf [0x04, 0x88, 0xb2, 0x1e] ||
     payload.extract 0 4 = bytesOf [0x04, 0x35, 0x87, 0xcf])

/-- Validate an extended public key. Returns `none` on success, or a short
reason. Derivation is deliberately not performed; only the serialization
envelope is checked. -/
def validateXpub (s : String) : Option String :=
  match base58CheckDecode? s with
  | none => some s!"key '{s}' is not valid Base58Check"
  | some payload =>
      if xpubVersionOk payload then none
      else some s!"key '{s}' is not a valid xpub/tpub (78-byte payload with xpub/tpub version expected)"

/-! ## Character-stream helpers -/

/-- Split a list at the first character satisfying `p`. -/
private def takeWhileChars (p : Char → Bool) : List Char → List Char × List Char
  | [] => ([], [])
  | c :: cs =>
      if p c then
        let (a, b) := takeWhileChars p cs
        (c :: a, b)
      else ([], c :: cs)

/-- Take characters up to (but not including) `stop`. `none` if `stop` is
absent. -/
private def takeUntilChar (stop : Char) : List Char → Option (List Char × List Char)
  | [] => none
  | c :: cs =>
      if c = stop then some ([], cs)
      else
        match takeUntilChar stop cs with
        | none => none
        | some (pre, rest) => some (c :: pre, rest)

/-- Parse a non-empty decimal string. -/
def parseDecimal? (s : String) : Option Nat :=
  let rec go (cs : List Char) (acc : Nat) : Option Nat :=
    match cs with
    | [] => some acc
    | c :: rest =>
        let n := c.toNat
        if 48 ≤ n ∧ n ≤ 57 then go rest (acc * 10 + (n - 48)) else none
  if s.isEmpty then none else go s.toList 0

/-- Parse one BIP32 path element (`src/util/bip32.cpp:17-39`).

Hardened suffixes are `'` and lower-case `h` only; the numeric part must be
a valid `uint32` strictly below `2^31`. The result stores the hardened bit
`0x80000000`. -/
def parsePathElement (text : String) : Except DescriptorError UInt32 :=
  if text.isEmpty then
    .error (.keyPathRange "empty path element")
  else if text.toList.any (fun c => c = '<' || c = '>') then
    .error (.keyPathRange s!"multipath specifier '{text}' is not modelled")
  else
    let chars := text.toList
    let (numChars, hardened) :=
      match chars.reverse with
      | c :: rest =>
          if c = '\'' || c = 'h' then (rest.reverse, true) else (chars, false)
      | [] => ([], false)
    if numChars.isEmpty then
      .error (.keyPathRange s!"key path value '{text}' is not a valid uint32")
    else if numChars.any (fun c => !isDigitChar c) then
      .error (.keyPathRange s!"key path value '{text}' is not a valid uint32")
    else
      match parseDecimal? (String.ofList numChars) with
      | none =>
          .error (.keyPathRange s!"key path value '{text}' is not a valid uint32")
      | some n =>
          if n ≥ 0x80000000 then
            .error (.keyPathRange s!"key path value {n} is out of range")
          else
            .ok ((if hardened then n + 0x80000000 else n).toUInt32)

/-- Parse a list of path elements, rejecting a wildcard marker in any
position (the caller strips the legal trailing marker first). -/
def parsePathElements (xs : List String) : Except DescriptorError (List UInt32) :=
  match xs with
  | [] => .ok []
  | x :: rest =>
      if x = "*" || x = "*'" || x = "*h" then
        .error (.keyPathRange "wildcard is only allowed at the end of a key path")
      else
        match parsePathElement x with
        | .error e => .error e
        | .ok child =>
            match parsePathElements rest with
            | .error e => .error e
            | .ok tail => .ok (child :: tail)

/-! ## Key expressions -/

/-- Parse the optional `[fingerprint/path]` origin prefix. The fingerprint
must be exactly eight hexadecimal characters
(`src/script/descriptor.cpp:2210-2245`). -/
def parseOrigin (raw : String) : Except DescriptorError (Option KeyOrigin × String) :=
  match raw.toList with
  | '[' :: restChars =>
      let parts := (String.ofList restChars).splitOn "]"
      match parts with
      | [inside, after] =>
          match inside.splitOn "/" with
          | [] => .error (.invalidKey "empty key origin")
          | fp :: pathStrs =>
              if fp.length ≠ 8 then
                .error (.invalidKey
                  s!"fingerprint is not 4 bytes ({fp.length} characters instead of 8 characters)")
              else
                match hexDecode? fp with
                | none => .error (.invalidKey s!"fingerprint '{fp}' is not hexadecimal")
                | some fingerprint =>
                    if fingerprint.size ≠ 4 then
                      .error (.invalidKey s!"fingerprint '{fp}' is not 4 bytes")
                    else
                      match parsePathElements pathStrs with
                      | .error e => .error e
                      | .ok path => .ok (some ⟨fingerprint, path⟩, after)
      | _ => .error (.invalidKey "Multiple ']' characters found for a single pubkey")
  | _ => .ok (none, raw)

/-- Parse one key expression. This is the heart of the key grammar: optional
origin, literal key or xpub, explicit path, trailing wildcard.

Literal keys are rejected when a path or wildcard is present, matching
Core, where a hex body with `split.size() > 1` falls through to the
extended-key decoder (`src/script/descriptor.cpp:1997-2050`). -/
def parseKeyExpr (raw : String) (ctx : KeyContext) : Except DescriptorError KeyExpr :=
  if raw.isEmpty then
    .error (.invalidKey "No key provided")
  else if raw.toList.any isSpaceChar then
    .error (.invalidKey s!"key '{raw}' is invalid due to whitespace")
  else
    match parseOrigin raw with
    | .error e => .error e
    | .ok (origin, body) =>
        match body.splitOn "/" with
        | [] => .error (.invalidKey "No key provided")
        | keyBody :: pathStrs =>
            if keyBody.isEmpty then
              .error (.invalidKey "No key provided")
            else
              let (wildcard, pathStrs) :=
                match pathStrs.reverse with
                | "*" :: rest => (Wildcard.unhardened, rest.reverse)
                | "*'" :: rest => (Wildcard.hardened, rest.reverse)
                | "*h" :: rest => (Wildcard.hardened, rest.reverse)
                | _ => (Wildcard.none, pathStrs)
              match parsePathElements pathStrs with
              | .error e => .error e
              | .ok path =>
                  if isHexString keyBody then
                    if !path.isEmpty || wildcard ≠ .none then
                      .error (.invalidKey
                        "a literal public key cannot have a derivation path")
                    else
                      match hexDecode? keyBody with
                      | none => .error (.invalidKey s!"pubkey '{keyBody}' is invalid")
                      | some pubkey =>
                          if constKeyValid ctx pubkey then
                            .ok (.const origin pubkey (ctx = .taproot ∧ pubkey.size = 32) raw)
                          else if ctx = .segwit ∧ uncompressedKeyValid pubkey then
                            -- Core's witness contexts reject a valid uncompressed
                            -- key with its own message (`src/script/descriptor.cpp:2021-2023`).
                            .error (.invalidKey "Uncompressed keys are not allowed")
                          else
                            .error (.invalidKey s!"pubkey '{keyBody}' is invalid in this context")
                  else
                    match validateXpub keyBody with
                    | some reason => .error (.invalidKey reason)
                    | none => .ok (.xpub origin keyBody path wildcard raw)

/-! ## Descriptor grammar -/

/-- Parse `key)` and return the key plus the remaining characters after the
closing parenthesis. -/
private def parseKeyArg (rest : List Char) (ctx : KeyContext) :
    Except DescriptorError (KeyExpr × List Char) :=
  match takeUntilChar ')' rest with
  | none => .error (.unexpectedToken "')' after the key" "end of input")
  | some (keyChars, after) =>
      match parseKeyExpr (String.ofList keyChars) ctx with
      | .error e => .error e
      | .ok key => .ok (key, after)

/-- Parse a single-key function body (`pk`, `pkh`, `wpkh`). -/
private def parseSingleKeyFunction (name : String) (rest : List Char)
    (ctx : KeyContext) : Except DescriptorError (Descriptor × List Char) :=
  match parseKeyArg rest ctx with
  | .error e => .error e
  | .ok (key, after) =>
      let descriptor :=
        match name with
        | "pk" => Descriptor.pk key
        | "pkh" => Descriptor.pkh key
        | _ => Descriptor.wpkh key
      .ok (descriptor, after)

/-- Parse `multi(threshold,key,...)` / `sortedmulti(threshold,key,...)`.

The whole argument list is taken up to the first `)`. Keys cannot contain
`)` in this fragment, so that is unambiguous. Threshold and key counts are
checked here: Core requires 1..20 keys for `multi`, and at most three keys
at top level (`src/script/descriptor.cpp:2488-2501`). Since this fragment
only supports top-level bare multisig, the tighter top-level cap applies. -/
private def parseMultiFunction (sorted : Bool) (rest : List Char) :
    Except DescriptorError (Descriptor × List Char) :=
  match takeUntilChar ')' rest with
  | none => .error (.unexpectedToken "')' after the multisig keys" "end of input")
  | some (insideChars, after) =>
      match (String.ofList insideChars).splitOn "," with
      | [] => .error (.threshold "empty multisig argument list")
      | thresholdText :: keyTexts =>
          if keyTexts.isEmpty then
            .error (.threshold "a multisig needs at least one key")
          else
            match parseDecimal? thresholdText with
            | none =>
                .error (.threshold s!"threshold '{thresholdText}' is not a valid number")
            | some threshold =>
                if keyTexts.length > 3 then
                  .error (.threshold
                    s!"cannot have {keyTexts.length} pubkeys in bare multisig; only at most 3")
                else if threshold < 1 then
                  .error (.threshold s!"threshold cannot be {threshold}, must be at least 1")
                else if threshold > keyTexts.length then
                  .error (.threshold
                    s!"threshold {threshold} is larger than the number of keys {keyTexts.length}")
                else
                  let rec parseKeys : List String → Except DescriptorError (List KeyExpr)
                    | [] => .ok []
                    | k :: ks =>
                        match parseKeyExpr k .legacy with
                        | .error e => .error e
                        | .ok key =>
                            match parseKeys ks with
                            | .error e => .error e
                            | .ok tail => .ok (key :: tail)
                  match parseKeys keyTexts with
                  | .error e => .error e
                  | .ok keys => .ok (Descriptor.multi threshold keys sorted, after)

/-- Parse `sh(wpkh(key))`. Any other `sh(...)` content is rejected: `sh(multi)`
and `sh(pk)` are outside this fragment, even though Core accepts them. -/
private def parseShFunction (rest : List Char) :
    Except DescriptorError (Descriptor × List Char) :=
  match rest with
  | 'w' :: 'p' :: 'k' :: 'h' :: '(' :: inner =>
      match parseKeyArg inner .segwit with
      | .error e => .error e
      | .ok (key, afterInner) =>
          match afterInner with
          | ')' :: after => .ok (Descriptor.shWpkh key, after)
          | _ => .error (.unexpectedToken "')' closing sh(wpkh(...))"
                   (String.ofList (afterInner.take 16)))
  | _ => .error (.unexpectedToken "'wpkh(' (only sh(wpkh(...)) is modelled)"
           (String.ofList (rest.take 16)))

/-- Parse `tr(key)`. A comma after the key means a taproot script tree, which
is outside this fragment. -/
private def parseTrFunction (rest : List Char) :
    Except DescriptorError (Descriptor × List Char) :=
  match takeUntilChar ')' rest with
  | none => .error (.unexpectedToken "')' after the taproot internal key" "end of input")
  | some (keyChars, after) =>
      let keyText := String.ofList keyChars
      if keyText.toList.any (fun c => c = ',' || c = '{' || c = '}') then
        .error (.unexpectedToken "')' after the internal key (taproot script trees are not modelled)"
          keyText)
      else
        match parseKeyExpr keyText .taproot with
        | .error e => .error e
        | .ok key => .ok (Descriptor.tr key, after)

/-- Dispatch a function name to its parser. Unknown names are
`unexpectedToken`s; the supported set is exactly the fragment in `Ast`. -/
private def parseFunction (name : String) (rest : List Char) :
    Except DescriptorError (Descriptor × List Char) :=
  match name with
  | "pk" => parseSingleKeyFunction "pk" rest .legacy
  | "pkh" => parseSingleKeyFunction "pkh" rest .legacy
  | "wpkh" => parseSingleKeyFunction "wpkh" rest .segwit
  | "multi" => parseMultiFunction false rest
  | "sortedmulti" => parseMultiFunction true rest
  | "sh" => parseShFunction rest
  | "tr" => parseTrFunction rest
  | _ => .error (.unexpectedToken
           "a supported descriptor function (pk, pkh, wpkh, sh(wpkh), multi, sortedmulti, tr)"
           name)

/-- Parse one descriptor payload from a character stream. -/
private def parseTop (cs : List Char) : Except DescriptorError (Descriptor × List Char) :=
  let (nameChars, afterName) := takeWhileChars isAlphaChar cs
  if nameChars.isEmpty then
    .error (.unexpectedToken "a descriptor function" (String.ofList (cs.take 16)))
  else
    match afterName with
    | '(' :: rest => parseFunction (String.ofList nameChars) rest
    | _ =>
        .error (.unexpectedToken "'(' after the descriptor function"
          (String.ofList (afterName.take 16)))

/-! ## Checksum gate and public entry points -/

/-- Core's `CheckChecksum` (`src/script/descriptor.cpp:2971-3008`): split at
`#`, enforce the optional/required checksum rules, verify the eight-character
digest, and return the checksum-free payload.

When `requireChecksum` is false, a descriptor without `#` is accepted; when
true, its absence is `missingChecksum`. -/
def checkChecksum (input : String) (requireChecksum : Bool) :
    Except DescriptorError String :=
  let parts := input.splitOn "#"
  if parts.length > 2 then
    .error .multipleChecksums
  else
    let payload := match parts with
      | [] => ""
      | p :: _ => p
    let provided :=
      match parts with
      | [_] => none
      | [_, checksum] => some checksum
      | _ => none
    if provided.isNone && requireChecksum then
      .error .missingChecksum
    else
      match provided with
      | some checksum =>
          if checksum.length ≠ 8 then
            .error (.checksumLength checksum.length)
          else
            let computed := descriptorChecksum payload
            if computed.isEmpty then
              match firstInvalidChar payload with
              | some c => .error (.invalidCharacter c)
              | none => .error (.invalidCharacter '?')
            else if checksum ≠ computed then
              .error (.checksumMismatch checksum computed)
            else .ok payload
      | none =>
          let computed := descriptorChecksum payload
          if computed.isEmpty then
            match firstInvalidChar payload with
            | some c => .error (.invalidCharacter c)
            | none => .error (.invalidCharacter '?')
          else .ok payload

/-- Parse a descriptor payload (no `#` handling). -/
def parsePayload (payload : String) : Except DescriptorError Descriptor :=
  match parseTop payload.toList with
  | .error e => .error e
  | .ok (descriptor, rest) =>
      if rest.isEmpty then .ok descriptor
      else .error (.unexpectedToken "end of descriptor" (String.ofList (rest.take 24)))

/-- Parse a descriptor, accepting input with or without a checksum.
Without `#` the checksum is computed only to reject invalid characters, as
Core does (`src/script/descriptor.cpp:2989-2992`). -/
def parseWithChecksum (requireChecksum : Bool) (input : String) :
    Except DescriptorError Descriptor :=
  match checkChecksum input requireChecksum with
  | .error e => .error e
  | .ok payload => parsePayload payload

/-- Parse a descriptor without requiring a checksum. This is the usual
wallet/RPC mode (`Parse(..., require_checksum=false)`). -/
def parse (input : String) : Except DescriptorError Descriptor :=
  parseWithChecksum false input

/-- Parse a descriptor and require an explicit eight-character checksum
(Core's `require_checksum=true`). -/
def parseRequired (input : String) : Except DescriptorError Descriptor :=
  parseWithChecksum true input

/-- String-error view of `parse`, for callers that do not want to depend on
the `DescriptorError` constructors. -/
def parseString (input : String) : Except String Descriptor :=
  match parse input with
  | .error e => .error e.message
  | .ok d => .ok d

/-! ## Parser tests

The checksum *algorithm* is verified against Core's vectors in
`Bitcoin.Wallet.Descriptor.Checksum`. The tests here exercise the grammar
and the checksum gate: rejection categories, key metadata, and the
render/parse round trip. `(name, ok)` tuples are evaluated at build time.
-/

/-- The compressed key used throughout Core's descriptor tests
(`src/test/descriptor_tests.cpp:612`). -/
def testCompressedKey : String :=
  "03a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd"

/-- The matching uncompressed key (`src/test/descriptor_tests.cpp:623`). -/
def testUncompressedKey : String :=
  "04a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd5b8dec5235a0fa8722476c7709c02559e3aa73aa03918ba2d492eea75abea235"

/-- The BIP32 test-vector public key used by the range tests
(`src/test/descriptor_tests.cpp:648`). -/
def testXpub : String :=
  "xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH"

/-- A descriptor payload with a Core-style origin. -/
def originPayload : String :=
  s!"pkh([deadbeef/1/2'/3/4']{testCompressedKey})"

/-- Rendering a parsed descriptor reproduces the checksum-free payload. -/
def roundTripOk : Bool :=
  match parse originPayload with
  | .ok d => d.render = originPayload
  | .error _ => false

/-- The origin's fingerprint and hardened path survive parsing. -/
def originMetadataOk : Bool :=
  match parse originPayload with
  | .ok (.pkh (.const (some o) _ _ _)) =>
      Bitcoin.Data.toHex o.fingerprint = "deadbeef" &&
        o.path == ([1, 0x80000002, 3, 0x80000004] : List UInt32)
  | _ => false

/-- A checksummed descriptor parses and renders back to its payload. -/
def checksumGateOk : Bool :=
  let input := originPayload ++ "#" ++ descriptorChecksum originPayload
  match parse input with
  | .ok d => d.render = originPayload
  | .error _ => false

/-- `parseRequired` rejects a payload without `#`. -/
def missingChecksumOk : Bool :=
  match parseRequired s!"pk({testCompressedKey})" with
  | .error .missingChecksum => true
  | _ => false

/-- Two `#` characters are rejected before any parsing. -/
def multipleChecksumsOk : Bool :=
  match parse s!"pk({testCompressedKey})#aaaaaaaa#bbbbbbbb" with
  | .error .multipleChecksums => true
  | _ => false

/-- A checksum shorter than eight characters is rejected. -/
def checksumLengthOk : Bool :=
  match parse s!"pk({testCompressedKey})#abc" with
  | .error (.checksumLength 3) => true
  | _ => false

/-- A well-formed but incorrect checksum is a `checksumMismatch`. -/
def checksumMismatchOk : Bool :=
  match parse s!"pk({testCompressedKey})#qqqqqqqq" with
  | .error (.checksumMismatch "qqqqqqqq" _) => true
  | _ => false

/-- `Ü` is outside Core's descriptor input alphabet (see the `raw(Ü)` case
at `src/test/descriptor_tests.cpp:1055`). -/
def invalidCharacterOk : Bool :=
  match parse s!"pk({testCompressedKey})Ü" with
  | .error (.invalidCharacter 'Ü') => true
  | _ => false

/-- An unsupported top-level function is an `unexpectedToken`. -/
def unsupportedFunctionOk : Bool :=
  match parse s!"wsh(pk({testCompressedKey}))" with
  | .error (.unexpectedToken _ "wsh") => true
  | _ => false

/-- An uncompressed key is not valid in a witness context. -/
def segwitUncompressedOk : Bool :=
  match parse s!"wpkh({testUncompressedKey})" with
  | .error (.invalidKey _) => true
  | _ => false

/-- A malformed literal key is an `invalidKey`. -/
def malformedKeyOk : Bool :=
  match parse "pk(02zz)" with
  | .error (.invalidKey _) => true
  | _ => false

/-- A path child at or above `2^31` is a `keyPathRange` error. -/
def keyPathRangeOk : Bool :=
  match parse s!"pkh({testXpub}/2147483648)" with
  | .error (.keyPathRange _) => true
  | _ => false

/-- A threshold larger than the key count is a `threshold` error. -/
def thresholdOk : Bool :=
  match parse s!"multi(2,{testCompressedKey})" with
  | .error (.threshold _) => true
  | _ => false

/-- A fourth key exceeds Core's top-level bare-multisig limit. -/
def multisigKeyCountOk : Bool :=
  let k := testCompressedKey
  match parse s!"multi(1,{k},{k},{k},{k})" with
  | .error (.threshold _) => true
  | _ => false

/-- The string-error wrapper reports the same category. -/
def parseStringOk : Bool :=
  match parseString "pk(02zz)" with
  | .error msg => msg.startsWith "Invalid key:"
  | .ok _ => false

/-- All parser tests hold. -/
def parseTestsOk : Bool :=
  roundTripOk && originMetadataOk && checksumGateOk &&
    missingChecksumOk && multipleChecksumsOk && checksumLengthOk &&
    checksumMismatchOk && invalidCharacterOk && unsupportedFunctionOk &&
    segwitUncompressedOk && malformedKeyOk && keyPathRangeOk &&
    thresholdOk && multisigKeyCountOk && parseStringOk

-- `(round-trip, origin, checksum gate, all errors, string view)`.
#eval (roundTripOk, originMetadataOk, checksumGateOk,
  missingChecksumOk && multipleChecksumsOk && checksumLengthOk &&
    checksumMismatchOk && invalidCharacterOk && unsupportedFunctionOk &&
    segwitUncompressedOk && malformedKeyOk && keyPathRangeOk &&
    thresholdOk && multisigKeyCountOk,
  parseStringOk)

end Bitcoin.Wallet.Descriptor
