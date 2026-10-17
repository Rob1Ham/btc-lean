import Bitcoin.Wallet.Descriptor.Ast
import Bitcoin.Wallet.Descriptor.Parse
import Bitcoin.Data.Script
import Bitcoin.Crypto.Seam.Hash
import Bitcoin.Crypto.Taproot.Verify

/-!
# Bitcoin.Wallet.Descriptor.Expand

Turn a parsed descriptor into scriptPubKeys, reusing the existing script
model (`Bitcoin.Data.Script`) and the existing hash/taproot primitives.

## Key provider and ranges

`expand` / `expand?` take a `KeyProvider`:

```
KeyProvider := KeyExpr → List ByteArray
```

A provider returns the serialised public keys contributed by one key
expression, in derivation-index order. A literal key is handled by the
expander itself and never reaches the provider. For an xpub without a
wildcard the list must have length one; for an xpub with `*` (or `*'`/`*h`)
the list has one entry per explicit index the caller wants. This is the
explicit-index boundary corresponding to Core's `Descriptor::Expand(pos,
provider, ...)` (`src/script/descriptor.cpp:1069-1071`): the descriptor
text records the path and wildcard, the provider supplies the actual
derived keys.

Mixing ranged and non-ranged keys follows Core's multipath alignment rule:
length-one vectors are cloned to the maximum length, and any other unequal
length is an error (`src/script/descriptor.cpp:2508-2515`).

## Script construction anchors

* P2PK — `GetScriptForRawPubKey` (`src/script/solver.cpp:213-216`).
* P2PKH — `CScriptVisitor` PKHash arm (`src/addresstype.cpp:120-123`).
* P2WPKH — `CScriptVisitor` WitnessV0KeyHash arm
  (`src/addresstype.cpp:128-131`).
* P2SH — `CScriptVisitor` ScriptHash arm (`src/addresstype.cpp:125-128`)
  with `ScriptHash = Hash160(script)`.
* Bare multisig — `GetScriptForMultisig` (`src/script/solver.cpp:218-227`).
* Sortedmultisig — `std::sort` on `CPubKey`, whose `operator<` compares the
  serialized length byte and then `memcmp`s the bytes
  (`src/pubkey.h:133-137`); the call site is
  `src/script/descriptor.cpp:1373-1378`.
* P2TR key-path — `TaprootBuilder::Finalize` with an empty tree tweaks the
  internal key with a null Merkle root (`src/script/signingprovider.cpp:462-470`)
  and `GetOutput` yields `WitnessV1Taproot`; the scriptPubKey is
  `OP_1 <32-byte x(Q)>` (`src/addresstype.cpp:136-139`). The executable
  model is `Bitcoin.Crypto.Taproot.Verify.p2trOutput`.

## What is not modelled

No BIP32 derivation, no private keys, no taproot script trees, no `wsh`,
`sh(multi)`, `combo`, `addr`, `raw`, or miniscript. `tr` is key-path only.
`expand` silently returns `[]` on provider/taproot failures; use `expand?`
when the error matters.
-/

namespace Bitcoin.Wallet.Descriptor

open Bitcoin.Data (Script)
open Bitcoin.Crypto.Seam.Hash (hash160)

/-- Resolve a key expression to the list of serialised public keys it
contributes, one per explicit derivation index. The expander calls this
only for xpub expressions; literal keys are used directly. -/
abbrev KeyProvider := KeyExpr → List ByteArray

/-- Append one data push using Core's `AppendDataSize` encoding
(`src/script/script.h:408-427`). For the keys and hashes in this fragment
the short form is always used, but the full encoding is kept so the helper
is usable for future fragments. -/
def pushData (data : ByteArray) : ByteArray :=
  let n := data.size
  if n < 0x4c then
    (ByteArray.empty.push n.toUInt8) ++ data
  else if n ≤ 0xff then
    ((ByteArray.empty.push 0x4c).push n.toUInt8) ++ data
  else if n ≤ 0xffff then
    (((ByteArray.empty.push 0x4d).push (n % 256).toUInt8).push
      ((n / 256) % 256).toUInt8) ++ data
  else
    ((((ByteArray.empty.push 0x4e).push (n % 256).toUInt8).push
      ((n / 256) % 256).toUInt8).push ((n / 65536) % 256).toUInt8).push
      ((n / 16777216) % 256).toUInt8 ++ data

/-- One raw opcode byte. -/
def opcode (n : Nat) : ByteArray := ByteArray.empty.push n.toUInt8

/-- Push a small integer the way `CScript::push_int64` does
(`src/script/script.h:432-448`): `OP_0`, `OP_1`..`OP_16`, then the minimal
CScriptNum encoding. Thresholds in this fragment are at most three, but the
helper is written for the general small-integer case. -/
def pushInt (n : Nat) : ByteArray :=
  if n = 0 then opcode 0x00
  else if 1 ≤ n ∧ n ≤ 16 then opcode (0x50 + n)
  else if n < 0x80 then pushData (ByteArray.empty.push n.toUInt8)
  else pushData (ByteArray.empty.push (n % 256).toUInt8 |>.push (n / 256).toUInt8)

/-- `GetScriptForRawPubKey`: `<pubkey> OP_CHECKSIG`
(`src/script/solver.cpp:213-216`). -/
def payToPubkey (pubkey : ByteArray) : Script :=
  ⟨pushData pubkey ++ opcode 0xac⟩

/-- P2PKH: `OP_DUP OP_HASH160 <Hash160(pubkey)> OP_EQUALVERIFY OP_CHECKSIG`
(`src/addresstype.cpp:120-123`). -/
def payToPubkeyHash (pubkey : ByteArray) : Script :=
  ⟨opcode 0x76 ++ opcode 0xa9 ++ pushData (hash160 pubkey) ++
    opcode 0x88 ++ opcode 0xac⟩

/-- P2WPKH: `OP_0 <Hash160(pubkey)>` (`src/addresstype.cpp:128-131`). -/
def payToWitnessPubkeyHash (pubkey : ByteArray) : Script :=
  ⟨opcode 0x00 ++ pushData (hash160 pubkey)⟩

/-- P2SH: `OP_HASH160 <Hash160(redeemScript)> OP_EQUAL`
(`src/addresstype.cpp:125-128`). -/
def payToScriptHash (redeemScript : Script) : Script :=
  ⟨opcode 0xa9 ++ pushData (hash160 redeemScript.bytes) ++ opcode 0x87⟩

/-- Bare multisig: `<threshold> <key>... <nkeys> OP_CHECKMULTISIG`
(`src/script/solver.cpp:218-227`). -/
def multiScript (threshold : Nat) (pubkeys : List ByteArray) : Script :=
  let keys := pubkeys.foldl (fun acc k => acc ++ pushData k) ByteArray.empty
  ⟨pushInt threshold ++ keys ++ pushInt pubkeys.length ++ opcode 0xae⟩

/-- Byte-wise public-key ordering, matching `CPubKey::operator<`
(`src/pubkey.h:133-137`): Core compares the serialized length byte first
(`vch[0]`), then the key bytes with `memcmp`. Since the length byte *is*
the serialized size, this is equivalent to comparing sizes first and then
the byte strings. -/
def pubkeyLt (a b : ByteArray) : Bool :=
  if a.size < b.size then true
  else if b.size < a.size then false
  else
    match (List.range a.size).find? (fun i => a.get! i ≠ b.get! i) with
    | none => false
    | some i => a.get! i < b.get! i

/-- Insert one key into an already sorted list. -/
private def insertPubkey (k : ByteArray) : List ByteArray → List ByteArray
  | [] => [k]
  | x :: xs => if pubkeyLt k x then k :: x :: xs else x :: insertPubkey k xs

/-- Ascending byte-wise sort of public keys, the operation `std::sort`
performs in `MultisigDescriptor::MakeScripts`
(`src/script/descriptor.cpp:1373-1378`). -/
def sortPubkeys : List ByteArray → List ByteArray
  | [] => []
  | x :: xs => insertPubkey x (sortPubkeys xs)

/-- Turn a taproot internal key into a key-path-only P2TR scriptPubKey.
Accepts a 32-byte x-only key or a 33-byte compressed key (whose first byte
is dropped, as `XOnlyPubKey(CPubKey)` does). Uses the existing
`p2trOutput` with `tree = none`, i.e. the null-Merkle-root tweak
(`src/script/signingprovider.cpp:462-470`). -/
def taprootKeyPath (internalKey : ByteArray) : Option Script :=
  let xonly :=
    if internalKey.size = 33 then internalKey.extract 1 33 else internalKey
  if xonly.size = 32 then
    (Bitcoin.Crypto.Taproot.Verify.p2trOutput xonly none).map fun bytes =>
      (⟨bytes⟩ : Script)
  else none

/-- Resolve one key expression. Literal keys ignore the provider; xpub keys
ask it for their explicit derivation indices. -/
def resolveKey (provider : KeyProvider) : KeyExpr → List ByteArray
  | .const _ pubkey _ _ => [pubkey]
  | k@(.xpub ..) => provider k

/-- Number of expansion positions for a key list, with the length-one
cloning rule applied. `none` means the list is empty or incompatible with
the maximum. -/
private def alignedCount (lists : List (List ByteArray)) : Option Nat :=
  let maxLen := lists.foldl (fun m xs => max m xs.length) 0
  if maxLen = 0 then none
  else if lists.all (fun xs => xs.length = 1 ∨ xs.length = maxLen) then
    some maxLen
  else none

/-- Clone length-one key vectors to `n`, leaving equal-length vectors
unchanged. -/
private def alignOne (n : Nat) : List ByteArray → List ByteArray
  | [x] => List.replicate n x
  | xs => xs

/-- `i`-th element of a list, without relying on `get!`. -/
private def nth? (xs : List ByteArray) (i : Nat) : Option ByteArray :=
  match xs.drop i with
  | [] => none
  | x :: _ => some x

/-- Build the script at one expansion position. All key vectors have already
been aligned to a common length. -/
private def buildAt (d : Descriptor) (vectors : List (List ByteArray))
    (idx : Nat) : Except String Script :=
  match d, vectors with
  | .pk _, [ks] =>
      match nth? ks idx with
      | some k => .ok (payToPubkey k)
      | none => .error "missing key at expansion index"
  | .pkh _, [ks] =>
      match nth? ks idx with
      | some k => .ok (payToPubkeyHash k)
      | none => .error "missing key at expansion index"
  | .wpkh _, [ks] =>
      match nth? ks idx with
      | some k => .ok (payToWitnessPubkeyHash k)
      | none => .error "missing key at expansion index"
  | .shWpkh _, [ks] =>
      match nth? ks idx with
      | some k => .ok (payToScriptHash (payToWitnessPubkeyHash k))
      | none => .error "missing key at expansion index"
  | .multi threshold _ sorted, ks =>
      let keys := ks.filterMap (fun xs => nth? xs idx)
      if keys.length ≠ ks.length then .error "missing key at expansion index"
      else
        let ordered := if sorted then sortPubkeys keys else keys
        .ok (multiScript threshold ordered)
  | .tr _, [ks] =>
      match nth? ks idx with
      | some k =>
          match taprootKeyPath k with
          | some script => .ok script
          | none => .error "internal key does not lift to a taproot output"
      | none => .error "missing key at expansion index"
  | _, _ => .error "descriptor/expansion shape mismatch"

/-- Error-aware expansion. The provider's per-key lists must be non-empty,
non-ranged keys must yield exactly one key, and ranged/non-ranged lists are
aligned by Core's length-one clone rule. Returns one script per range index,
in ascending index order. -/
def expand? (d : Descriptor) (provider : KeyProvider) :
    Except String (List Script) :=
  let rec resolve : List KeyExpr → Except String (List (List ByteArray))
    | [] => .ok []
    | k :: ks =>
        let xs := resolveKey provider k
        if xs.isEmpty then
          .error s!"key provider returned no keys for '{KeyExpr.raw k}'"
        else if !k.isRanged && xs.length > 1 then
          .error s!"key provider returned multiple keys for non-ranged '{KeyExpr.raw k}'"
        else
          match resolve ks with
          | .error e => .error e
          | .ok rest => .ok (xs :: rest)
  match resolve d.keys with
  | .error e => .error e
  | .ok vectors =>
      match alignedCount vectors with
      | none => .error "no key can be expanded (empty key list)"
      | some n =>
          let ordered := vectors.map (alignOne n)
          (List.range n).mapM (buildAt d ordered)

/-- Total expansion returning `List Script`, as the public interface. On a
provider or taproot failure it returns the empty list; use `expand?` to
observe the error. -/
def expand (d : Descriptor) (provider : KeyProvider) : List Script :=
  match expand? d provider with
  | .ok scripts => scripts
  | .error _ => []

/-! ## Example tests

Every expected script is the scriptPubKey hex printed by the cited Core
test vector in `src/test/descriptor_tests.cpp`. The xpub range vectors use
keys derived from the published BIP32 test-vector xpubs; the derivation was
done once with an independent Python BIP32 implementation, and the resulting
pubkeys are hard-coded below.

`(name, ok)` tuples are evaluated at build time.
-/

/-- Decode one hex string, with the empty byte string as the failure value.
Test-only convenience. -/
def hexOrEmpty (s : String) : ByteArray :=
  match hexDecode? s with
  | some b => b
  | none => ByteArray.empty

/-- Hex string of the single script in an expansion. -/
def oneScriptHex (input : String) (provider : KeyProvider := fun _ => []) :
    Except String String :=
  match parse input with
  | .error e => .error e.message
  | .ok d =>
      match expand? d provider with
      | .error e => .error e
      | .ok [script] => .ok (Bitcoin.Data.toHex script.bytes)
      | .ok _ => .error "expected exactly one script"

/-- Comma-joined hex of every script in an expansion. -/
def allScriptsHex (input : String) (provider : KeyProvider) :
    Except String String :=
  match parse input with
  | .error e => .error e.message
  | .ok d =>
      match expand? d provider with
      | .error e => .error e
      | .ok scripts => .ok (String.intercalate "," (scripts.map fun s => Bitcoin.Data.toHex s.bytes))

/-- The `wpkh([ffffffff/13']xpub.../1/2/*)` provider: derived compressed
pubkeys at indices 0, 1, 2. -/
def wpkhRangeProvider : KeyProvider := fun
  | .xpub _ encoded _ _ _ =>
      if encoded = "xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH" then
        [hexOrEmpty "021a45661073b3902a29ab5d1bf2545d3bc09420d8ff1f574e5eebd3c4da98c589",
         hexOrEmpty "02c99d4ca62021dadf698e56d7d0542660dfe6f090e466d0232026052b078a9b19",
         hexOrEmpty "02683791601676cdefeabbc87d3740f31050b83419c9cc40d0aaf83c64fd862b81"]
      else []
  | _ => []

/-- The `multi(1,xpub.../*,<const>)` provider: derived pubkeys at indices
0, 1, 2. -/
def multiRangeProvider : KeyProvider := fun
  | .xpub _ encoded _ _ _ =>
      if encoded = "xpub6FHa3pjLCk84BayeJxFW2SP4XRrFd1JYnxeLeU8EqN3vDfZmbqBqaGJAyiLjTAwm6ZLRQUMv1ZACTj37sR62cfN7fe5JnJ7dh8zL4fiyLHV" then
        [hexOrEmpty "02df12b7035bdac8e3bab862a3a83d06ea6b17b6753d52edecba9be46f5d09e076",
         hexOrEmpty "032869a233c9adff9a994e4966e5b821fd5bac066da6c3112488dc52383b4a98ec",
         hexOrEmpty "035d30b6c66dc1e036c45369da8287518cf7e0d6ed1e2b905171c605708f14ca03"]
      else []
  | _ => []

/-- Fixed-key expansion vectors (one script each), grouped by descriptor
family. Each pair is `(descriptor, expected scriptPubKey hex)`. -/
def fixedVectors : List (String × String) :=
  [
    -- line 612: pk(compressed)
    ("pk(03a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd)",
     "2103a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bdac"),
    -- line 623: pk(uncompressed)
    ("pk(04a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd5b8dec5235a0fa8722476c7709c02559e3aa73aa03918ba2d492eea75abea235)",
     "4104a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd5b8dec5235a0fa8722476c7709c02559e3aa73aa03918ba2d492eea75abea235ac"),
    -- line 613: pkh with origin
    ("pkh([deadbeef/1/2'/3/4']03a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd)",
     "76a9149a1c78a507689f6f54b847ad1cef1e614ee23f1e88ac"),
    -- line 624: pkh(uncompressed)
    ("pkh(04a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd5b8dec5235a0fa8722476c7709c02559e3aa73aa03918ba2d492eea75abea235)",
     "76a914b5bd079c4d57cc7fc28ecf8213a6b791625b818388ac"),
    -- line 614: wpkh
    ("wpkh(03a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd)",
     "00149a1c78a507689f6f54b847ad1cef1e614ee23f1e"),
    -- line 615: sh(wpkh)
    ("sh(wpkh(03a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd))",
     "a91484ab21b1b2fd065d4504ff693d832434b6108d7b87"),
    -- line 1001: multi(1, compressed, uncompressed)
    ("multi(1,03a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd,04a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd5b8dec5235a0fa8722476c7709c02559e3aa73aa03918ba2d492eea75abea235)",
     "512103a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd4104a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd5b8dec5235a0fa8722476c7709c02559e3aa73aa03918ba2d492eea75abea23552ae"),
    -- line 1002: multi(2, three compressed keys)
    ("multi(2,03669b8afcec803a0d323e9a17f3ea8e68e8abe5a278020a929adbec52421adbd0,0260b2003c386519fc9eadf2b5cf124dd8eea4c4e68d5e154050a9346ea98ce600,0362a74e399c39ed5593852a30147f2959b56bb827dfa3e60e464b02ccf87dc5e8)",
     "522103669b8afcec803a0d323e9a17f3ea8e68e8abe5a278020a929adbec52421adbd0210260b2003c386519fc9eadf2b5cf124dd8eea4c4e68d5e154050a9346ea98ce600210362a74e399c39ed5593852a30147f2959b56bb827dfa3e60e464b02ccf87dc5e853ae"),
    -- line 1003: sortedmulti(1, compressed, uncompressed)
    ("sortedmulti(1,03a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd,04a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd5b8dec5235a0fa8722476c7709c02559e3aa73aa03918ba2d492eea75abea235)",
     "512103a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd4104a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd5b8dec5235a0fa8722476c7709c02559e3aa73aa03918ba2d492eea75abea23552ae"),
    -- line 1004: sortedmulti(1, uncompressed, compressed) — same script,
    -- proving the byte-wise sort reorders the two keys.
    ("sortedmulti(1,04a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd5b8dec5235a0fa8722476c7709c02559e3aa73aa03918ba2d492eea75abea235,03a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd)",
     "512103a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd4104a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd5b8dec5235a0fa8722476c7709c02559e3aa73aa03918ba2d492eea75abea23552ae"),
    -- line 616: tr(x-only const) — Core's expected 512077aab6... (key-path only)
    ("tr(a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd)",
     "512077aab6e066f8a7419c5ab714c12c67d25007ed55a43cadcacb4d7a970a093f11")
  ]

/-- Compare an expansion result against an expected script hex string. -/
def hexResultOk : Except String String → String → Bool
  | .ok actual, expected => actual == expected
  | .error _, _ => false

/-- All fixed-key vectors expand to the Core scriptPubKey hex. -/
def fixedVectorsOk : Bool :=
  fixedVectors.all fun (descriptor, expected) =>
    hexResultOk (oneScriptHex descriptor) expected

/-- The `wpkh(.../1/2/*)` range vector from line 648, including the
descending order of the three expected Core scripts. -/
def wpkhRangeOk : Bool :=
  hexResultOk (allScriptsHex
    "wpkh([ffffffff/13']xpub69H7F5d8KSRgmmdJg2KhpAK8SR3DjMwAdkxj3ZuxV27CprR9LgpeyGmXUbC6wb7ERfvrnKZjXoUmmDznezpbZb7ap6r1D3tgFxHmwMkQTPH/1/2/*)"
    wpkhRangeProvider)
    "0014326b2249e3a25d5dc60935f044ee835d090ba859,0014af0bd98abc2f2cae66e36896a39ffe2d32984fb7,00141fa798efd1cbf95cebf912c031b8a4a6e9fb9f27"

/-- The bare `multi(1,<xpub>/*,<const>)` range vector from line 655. Core's
expected scripts at positions 0,1,2 are listed there in reverse index order
(`{2},{1},{0}`); the expansion here is in ascending index order. -/
def multiRangeOk : Bool :=
  hexResultOk (allScriptsHex
    "multi(1,xpub6FHa3pjLCk84BayeJxFW2SP4XRrFd1JYnxeLeU8EqN3vDfZmbqBqaGJAyiLjTAwm6ZLRQUMv1ZACTj37sR62cfN7fe5JnJ7dh8zL4fiyLHV/*,03a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd)"
    multiRangeProvider)
    "512102df12b7035bdac8e3bab862a3a83d06ea6b17b6753d52edecba9be46f5d09e0762103a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd52ae,5121032869a233c9adff9a994e4966e5b821fd5bac066da6c3112488dc52383b4a98ec2103a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd52ae,5121035d30b6c66dc1e036c45369da8287518cf7e0d6ed1e2b905171c605708f14ca032103a34b99f22c790c4e36b2b3c2c35a36db06226e41c692fc82b8b56ac1c540c5bd52ae"

-- `(fixed-vectors, wpkh-range, multi-range)` evaluated at build time.
#eval (fixedVectorsOk, wpkhRangeOk, multiRangeOk)

end Bitcoin.Wallet.Descriptor
