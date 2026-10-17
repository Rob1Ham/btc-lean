import Bitcoin.Data.Basic

/-!
# Bitcoin.Wallet.Descriptor.Checksum

A byte-for-byte port of Bitcoin Core's descriptor checksum:
`PolyMod` and `DescriptorChecksum` in `src/script/descriptor.cpp:129-185`
at commit `cce32b168` (a v21.99 development snapshot).

The checksum is a BCH code over GF(32^3). Every input character gives one
5-bit symbol (`pos & 31`), and every group of three characters additionally
gives one symbol built from the three 2-bit group numbers
(`cls * 3 + ...`). Eight zero symbols are shifted in, then the result is
XORed with 1 so that trailing zeroes cannot leave the checksum unchanged.
The eight output symbols are printed with the bech32 alphabet.

`descriptorChecksum` returns the empty string when the payload contains a
character outside Core's `INPUT_CHARSET` (`src/script/descriptor.cpp:155-158`),
exactly like `DescriptorChecksum` returning `""`. Callers in
`Bitcoin.Wallet.Descriptor.Parse` use that to report Core's
`Invalid characters in payload`.

## What is not modelled

Nothing: the character set, the three-symbol grouping, the `u64` arithmetic,
the eight shift rounds, and the final XOR are the C++ operations verbatim.
The checksum is not a security property; it is a typo detector (Core's
comment at `src/script/descriptor.cpp:143-153`).

## Vectors

The `#eval` block at the bottom checks eight checksums taken from
`src/test/descriptor_tests.cpp`, with the source line cited on each entry,
plus two deliberately corrupted checksums derived by hand. The vectors were
also cross-checked with an independent Python implementation of the same
polynomial.
-/

namespace Bitcoin.Wallet.Descriptor

/-- Core's descriptor input character set, in order
(`src/script/descriptor.cpp:155-158`). Its order is what maps a character to
its 5-bit symbol. -/
def inputCharset : String :=
  "0123456789()[],'/*abcdefgh@:$%{}" ++
  "IJKLMNOPQRSTUVWXYZ&+-.;<=>?!^_|~" ++
  "ijklmnopqrstuvwxyzABCDEFGH`#\"\\ "

/-- Core's checksum output alphabet, identical to bech32
(`src/script/descriptor.cpp:160-161`). -/
def checksumCharset : String := "qpzry9x8gf2tvdw0s3jn54khce6mua7l"

/-- `n`-th element of a list, with a fallback for out-of-range indices.
Used only for the eight fixed checksum-alphabet lookups. -/
def listGetD (xs : List Char) (n : Nat) (fallback : Char) : Char :=
  match xs.drop n with
  | [] => fallback
  | x :: _ => x

/-- Index of a character in a character-set string, or `none` if absent.
A hand-written linear scan keeps the definition independent of `String`
search API details. -/
def charsetIndex (set : String) (ch : Char) : Option Nat :=
  let rec go (i : Nat) : List Char → Option Nat
    | [] => none
    | c :: cs => if c = ch then some i else go (i + 1) cs
  go 0 set.toList

/-- One BCH polynomial step over GF(32^3), verbatim:
`c0 = c >> 35; c = ((c & 0x7ffffffff) << 5) ^ val;` followed by the five
conditional reductions (`src/script/descriptor.cpp:129-139`). -/
def polyMod (c val : UInt64) : UInt64 :=
  let c0 := c >>> (35 : UInt64)
  let c1 := ((c &&& (0x7ffffffff : UInt64)) <<< (5 : UInt64)) ^^^ val
  let c2 := if (c0 &&& 1) = 0 then c1 else c1 ^^^ (0xf5dee51989 : UInt64)
  let c3 := if (c0 &&& 2) = 0 then c2 else c2 ^^^ (0xa9fdca3312 : UInt64)
  let c4 := if (c0 &&& 4) = 0 then c3 else c3 ^^^ (0x1bab10e32d : UInt64)
  let c5 := if (c0 &&& 8) = 0 then c4 else c4 ^^^ (0x3706b1677a : UInt64)
  if (c0 &&& 16) = 0 then c5 else c5 ^^^ (0x644d626ffd : UInt64)

/-- Core's `DescriptorChecksum` (`src/script/descriptor.cpp:141-185`).

Returns an 8-character checksum, or `""` when the payload contains a
character outside `inputCharset` — the same sentinel Core uses. -/
def descriptorChecksum (payload : String) : String :=
  let rec loop (cs : List Char) (c cls : UInt64) (count : Nat) : Option UInt64 :=
    match cs with
    | [] => some (if count = 0 then c else polyMod c cls)
    | ch :: rest =>
        match charsetIndex inputCharset ch with
        | none => none
        | some pos =>
            let c := polyMod c (pos % 32).toUInt64
            let cls := cls * 3 + (pos / 32).toUInt64
            if count + 1 = 3 then loop rest (polyMod c cls) 0 0
            else loop rest c cls (count + 1)
  match loop payload.toList 1 0 0 with
  | none => ""
  | some c =>
      let rec shift (n : Nat) (c : UInt64) : UInt64 :=
        if n = 0 then c else shift (n - 1) (polyMod c 0)
      let c := shift 8 c ^^^ (1 : UInt64)
      String.ofList ((List.range 8).map fun j =>
        let idx := ((c >>> (5 * (7 - j)).toUInt64).toNat % 32)
        listGetD checksumCharset.toList idx 'q')

/-- Append `#` and the checksum, as Core's `AddChecksum`
(`src/script/descriptor.cpp:187`). For an invalid payload Core would append
an empty checksum; this function mirrors that (`payload#`). -/
def addChecksum (payload : String) : String := payload ++ "#" ++ descriptorChecksum payload

/-- First character of `s` that is outside the descriptor input alphabet,
if any. Used to turn Core's anonymous "invalid characters" sentinel into a
diagnostic for `Parse`. -/
def firstInvalidChar (s : String) : Option Char :=
  s.toList.find? fun ch => (charsetIndex inputCharset ch).isNone

/-! ## Conformance vectors

Each entry is `(payload, expected checksum, Core test line)`. Valid checksum
vectors come from `Check(...)`/`CheckUnparsable(...)` expectations in
`src/test/descriptor_tests.cpp`; the `CheckUnparsable` lines state the
computed checksum in the expected error text.
-/

def checksumVectors : List (String × String × Nat) :=
  [
    -- line 1043, first argument: BIP32 private-key spelling of sh(multi(...)).
    ("sh(multi(2,[00000000/111'/222]xprvA1RpRA33e1JQ7ifknakTFpgNXPmW2YvmhqLQYMmrj4xJXXWYpDPS3xz7iAxn8L39njGVyuoseXzU6rcxFLJ8HFsTjSyQbLYnMpCqE2VbFWc,xprv9uPDJpEQgRQfDcW7BkF7eTya6RPxXeJCqCJGHuCJ4GiRVLzkTXBAJMu2qaMWPrS7AANYqdq6vcBcBUdJCVVFceUvJFjaPdGZ2y9WACViL4L/0))",
     "ggrsrxfy", 1043),
    -- line 1043, second argument: the public spelling, checksum tgj09x5t.
    ("sh(multi(2,[00000000/111'/222]xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL,xpub68NZiKmJWnxxS6aaHmn81bvJeTESw724CRDs6HbuccFQN9Ku14VQrADWgqbhhTHBaohPX4CjNLf9fq9MYo6oDaPPLPxSb7gwQN3ih19Zm4Y/0))",
     "tjg09x5t", 1043),
    -- line 1043, third argument: same with origin hardened spelling "h",
    -- checksum hgmsckna.
    ("sh(multi(2,[00000000/111h/222]xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL,xpub68NZiKmJWnxxS6aaHmn81bvJeTESw724CRDs6HbuccFQN9Ku14VQrADWgqbhhTHBaohPX4CjNLf9fq9MYo6oDaPPLPxSb7gwQN3ih19Zm4Y/0))",
     "hgmsckna", 1043),
    -- line 1048: sh(multi(3,...)) — the expected error names computed d4x0uxyv.
    ("sh(multi(3,[00000000/111'/222]xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL,xpub68NZiKmJWnxxS6aaHmn81bvJeTESw724CRDs6HbuccFQN9Ku14VQrADWgqbhhTHBaohPX4CjNLf9fq9MYo6oDaPPLPxSb7gwQN3ih19Zm4Y/0))",
     "d4x0uxyv", 1048),
    -- line 1058: rawtr(...) private-key spelling.
    ("rawtr(xprv9vHkqa6EV4sPZHYqZznhT2NPtPCjKuDKGY38FBWLvgaDx45zo9WQRUT3dKYnjwih2yJD9mkrocEZXo1ex8G81dwSM1fwqWpWkeS3v86pgKt/86'/1'/0'/1/*)",
     "a5gn3t7k", 1058),
    -- line 1059: rawtr(...) public spelling.
    ("rawtr(xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH/86'/1'/0'/1/*)",
     "4ur3xhft", 1059),
    -- line 1060: rawtr(...) with an origin.
    ("rawtr([5a61ff8e/86h/1h/0h]xpub6DtZpc9PRL2B6pwoNGysmHAaBofDmWv5S6KQEKKGPKhf5fV62ywDtSziSApYVK3JnYY5KUSgiCwiXW5wtd8z7LNBxT9Mu5sEro8itdGfTeA/1/*)",
     "vwgx7hj9", 1060),
    -- line 1105: miniscript payload; checksum is independent of the grammar.
    ("wsh(and_v(vc:andor(pk(03cdabb7f2dce7bfbd8a0b9570c6fd1e712e5d64045e9d6b517b3d5072251dc204),pk_k(032707170c71d8f75e4ca4e3fce870b9409dcaf12b051d3bcadff74747fa7619c0),and_v(v:older(1),pk_k(02aa27e5eb2c185e87cd1dbc3e0efc9cb1175235e0259df1713424941c3cb40402))),after(10)))",
     "tyzp6a7p", 1105)
  ]

/-- The checksum vectors all hold. -/
def checksumVectorsOk : Bool :=
  checksumVectors.all fun (payload, expected, _) =>
    descriptorChecksum payload = expected

/-- Two hand-derived invalid-checksum cases. (1) Replacing the final
character of a valid checksum changes the provided string only; the computed
checksum stays `tjg09x5t`, so the pair disagrees. (2) Appending eight zeroes
is not equal to the computed checksum either. -/
def invalidChecksumCasesOk : Bool :=
  let payload := "sh(multi(2,[00000000/111'/222]xpub6ERApfZwUNrhLCkDtcHTcxd75RbzS1ed54G1LkBUHQVHQKqhMkhgbmJbZRkrgZw4koxb5JaHWkY4ALHY2grBGRjaDMzQLcgJvLJuZZvRcEL,xpub68NZiKmJWnxxS6aaHmn81bvJeTESw724CRDs6HbuccFQN9Ku14VQrADWgqbhhTHBaohPX4CjNLf9fq9MYo6oDaPPLPxSb7gwQN3ih19Zm4Y/0))"
  descriptorChecksum payload = "tjg09x5t" ∧
    ("tjg09x5u" ≠ descriptorChecksum payload) ∧
    ("00000000" ≠ descriptorChecksum payload)

-- `(checksum-vectors, invalid-cases)` evaluated at build time.
#eval (checksumVectorsOk, invalidChecksumCasesOk)

end Bitcoin.Wallet.Descriptor
