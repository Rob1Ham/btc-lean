import Bitcoin.Wallet.Descriptor.Expand
import Bitcoin.Wallet.Encoding.Base58
import Bitcoin.Wallet.Key.Bip32

/-!
# DescDump — descriptor expansion dump for differential comparison

Reads one descriptor per line from standard input and writes one compact
JSON object per line:

```
{"input":"<descriptor>","ok":true|false,"scripts":["<hex>",...],"error":null|"<text>"}
```

## Documented policies

**Checksum policy.** By default the input is parsed with
`Descriptor.parseRequired`, because the corpus method that records
script-bearing results is `deriveaddresses`, and Core's `deriveaddresses`
requires a checksum (`src/rpc/output_script.cpp:325`, calling
`Parse(..., require_checksum=true)`). Setting the environment variable
`DESC_CHECKSUM=optional` selects `Descriptor.parse`, the mode used by
`getdescriptorinfo` (`src/rpc/output_script.cpp:175`). The two modes are run
as separate processes by `compare_desc.py`.

**Derivation-index policy.** A descriptor with a wildcard (`*`, `*'`, `*h`)
is expanded at the three explicit indices `0,1,2`. A descriptor without a
wildcard is expanded at index `0`. This is the smallest policy that covers
the corpus ranges `[0,0]`, `[0,1]` and `[0,2]` without asking the caller for
a range. Core takes the position as an argument
(`Descriptor::Expand(pos, ...)`, `src/script/descriptor.cpp:1069-1071`);
this runner fixes that argument rather than modelling `deriveaddresses`'
range parsing.

**Key provider.** Literal keys come from the parsed AST. An `xpub`/`tpub`
is Base58Check-decoded into a 78-byte BIP32 payload, its compressed public
key is lifted, and the child path plus wildcard index is derived with
`Bitcoin.Wallet.Key.derivePubPath` / `ckdPub`. Hardened steps from a public
key fail (`DeriveError.hardenedFromPublic`), exactly the condition Core
reports as `Cannot derive script without private keys`
(`src/rpc/output_script.cpp:241`). Private keys (`xprv`/`tprv`) are outside
the modelled fragment and are rejected by the parser as invalid keys.

## What is not modelled here

No address encoding, no `deriveaddresses` range-argument validation, no
`getdescriptorinfo` redaction or metadata. The runner reports scripts and
parse/expansion errors only. `compare_desc.py` performs the address →
scriptPubKey join using Core's address rules, and marks cases outside this
fragment as skipped.
-/

namespace WalletDiff

open Bitcoin.Wallet.Descriptor
open Bitcoin.Wallet.Encoding
open Bitcoin.Wallet.Key

/-- Four big-endian bytes at `off` as a `UInt32` (BIP32 `ser32` field). -/
def readU32BE (b : ByteArray) (off : Nat) : UInt32 :=
  (Bitcoin.Crypto.Curve.Secp.bytesToNatBE (b.extract off (off + 4))).toUInt32

/-- Decode a 78-byte BIP32 extended public key from Base58Check. Only the
serialization envelope and the compressed point are checked; depth and
parent/fingerprint consistency are not (the Descriptor parser makes the
same choice for the textual form). -/
def decodeExtPub (s : String) : Except String ExtPubKey :=
  match base58CheckDecode s 78 with
  | Except.error e => Except.error s!"key '{s}' is not valid Base58Check: {reprStr e}"
  | .ok payload =>
      if payload.size ≠ 78 then
        .error s!"key '{s}' does not decode to a 78-byte BIP32 payload"
      else
        let version := Bitcoin.Data.toHex (payload.extract 0 4)
        if version ≠ "0488b21e" ∧ version ≠ "043587cf" then
          .error s!"key '{s}' is not an xpub/tpub (version {version})"
        else
          let keyBytes := payload.extract 45 78
          if keyBytes.size ≠ 33 ∨
              (keyBytes.get! 0 ≠ 0x02 ∧ keyBytes.get! 0 ≠ 0x03) then
            .error s!"key '{s}' does not carry a compressed public key"
          else
            match Bitcoin.Crypto.Curve.Secp.liftX
                (Bitcoin.Crypto.Curve.Secp.bytesToNatBE
                  (keyBytes.extract 1 33)) with
            | none => .error s!"key '{s}' public key does not lift to a curve point"
            | some point =>
                -- `liftX` is BIP340's even-y lift. A serialized key with
                -- prefix `03` is the odd-y point, so negate it before
                -- deriving: CKDpub hashes `ser_P(parent)`, whose parity
                -- byte must match the original key (`src/pubkey.h`).
                let point :=
                  if keyBytes.get! 0 = 0x03 then
                    Bitcoin.Crypto.Curve.Secp.negP (some point)
                  else some point
                .ok { depth := payload.get! 4
                      parentFingerprint := payload.extract 5 9
                      childNumber := readU32BE payload 9
                      chainCode := payload.extract 13 45
                      key := point }

/-- Derive one key expression. For a wildcard, `indices` are unhardened
child numbers; a hardened wildcard adds bit 31, which a public key cannot
derive and therefore reports a derivation error. -/
def deriveKeyExpr (indices : List Nat) : KeyExpr →
    Except String (List ByteArray)
  | .const _ pubkey _ _ => .ok [pubkey]
  | .xpub _ encoded path wildcard _ =>
      match decodeExtPub encoded with
      | .error e => .error e
      | .ok base =>
          match derivePubPath base path with
          | .error e => .error s!"public derivation failed: {repr e}"
          | .ok atPath =>
              match wildcard with
              | .none => .ok [serPub atPath.key]
              | .unhardened =>
                  let children := indices.map (fun i => i.toUInt32)
                  let derived := children.map fun i =>
                    match ckdPub atPath i with
                    | .ok child => some (serPub child.key)
                    | .error _ => none
                  if derived.all Option.isSome then
                    .ok (derived.filterMap id)
                  else
                    .error "public derivation failed: hardenedFromPublic"
              | .hardened =>
                  let children := indices.map (fun i =>
                    (i + 0x80000000).toUInt32)
                  let derived := children.map fun i =>
                    match ckdPub atPath i with
                    | .ok child => some (serPub child.key)
                    | .error _ => none
                  if derived.all Option.isSome then
                    .ok (derived.filterMap id)
                  else
                    .error "public derivation failed: hardenedFromPublic"

/-- The provider plus every provider-side error, keyed by key expression.
`expand?` itself has no error channel on `KeyProvider`, so the runner keeps
the first derivation failure and reports it when expansion fails. -/
def providerAndErrors (d : Descriptor) (indices : List Nat) :
    KeyProvider × List String :=
  let results := d.keys.map fun k => (k, deriveKeyExpr indices k)
  let provider : KeyProvider := fun k =>
    match results.find? (fun p => p.1 == k) with
    | some (_, .ok keys) => keys
    | _ => []
  let errors := results.filterMap fun p =>
    match p.2 with
    | .error e => some e
    | .ok _ => none
  (provider, errors)

/-- Expand one input under the documented policies and render a JSON line. -/
def describe (input : String) (requireChecksum : Bool) : String :=
  let parsed :=
    if requireChecksum then Bitcoin.Wallet.Descriptor.parseRequired input
    else Bitcoin.Wallet.Descriptor.parse input
  let (ok, scripts, error) :=
    match parsed with
    | .error e => (false, [], e.message)
    | .ok d =>
        let indices := if d.hasRange then [0, 1, 2] else [0]
        let (provider, errors) := providerAndErrors d indices
        match Bitcoin.Wallet.Descriptor.expand? d provider with
        | .error e => (false, [], errors.headD e)
        | .ok expanded =>
            (true, expanded.map (fun (s : Bitcoin.Data.Script) => Bitcoin.Data.toHex s.bytes), "")
  let scriptJson :=
    "[" ++ String.intercalate "," (scripts.map (fun s => reprStr s)) ++ "]"
  let errorJson := if ok then "null" else reprStr error
  "{\"input\":" ++ reprStr input ++ ",\"ok\":" ++
    (if ok then "true" else "false") ++
    ",\"scripts\":" ++ scriptJson ++
    ",\"error\":" ++ errorJson ++ "}"

/-- Read stdin line by line; skip empty and `#` comment lines. -/
partial def main : IO Unit := do
  let requireChecksum ←
    match ← IO.getEnv "DESC_CHECKSUM" with
    | some "optional" => pure false
    | _ => pure true
  let stdin ← IO.getStdin
  let rec loop : IO Unit := do
    let line ← stdin.getLine
    if line.isEmpty then
      pure ()
    else
      let rev := line.toList.reverse
      let rev := match rev with
        | '\n' :: rest => rest
        | _ => rev
      let rev := match rev with
        | '\r' :: rest => rest
        | _ => rev
      let input := String.ofList rev.reverse
      if input.isEmpty ∨ input.startsWith "#" then
        loop
      else
        IO.println (describe input requireChecksum)
        loop
  loop

end WalletDiff

def main : IO Unit := WalletDiff.main
