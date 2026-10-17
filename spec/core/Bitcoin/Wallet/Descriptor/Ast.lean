import Bitcoin.Data.Basic

/-!
# Bitcoin.Wallet.Descriptor.Ast

Abstract syntax for the executable descriptor fragment modelled by this
directory: `pk`, `pkh`, `wpkh`, `sh(wpkh)`, `multi`, `sortedmulti`, and
`tr(<key>)` key-path only.

The AST deliberately keeps more than the minimum needed to build scripts:

* every key expression retains its original, checksum-free source spelling
  (`KeyExpr.raw`), so a parsed descriptor can be rendered back to the exact
  payload that the checksum was computed over;
* a BIP32 key keeps its origin (`KeyOrigin`), its derivation path as raw
  child numbers (`0x80000000` marks a hardened step), and a `Wildcard`
  marker instead of an eagerly chosen range length;
* `Descriptor` records whether a multisig is `multi` or `sortedmulti`
  (`sorted : Bool`) rather than duplicating constructors.

## What is not modelled

`addr()`, `raw()`, `combo()`, `wsh()`, `sh(multi(...))`, `sh(sortedmulti(...))`,
miniscript, taproot script trees / `tr(key, tree)`, multipath `<a;b>`
specifiers, private keys (`xprv`/`tprv`), BIP32 *derivation*, and network
checks on the xpub version beyond the two standard `xpub`/`tpub` prefixes.
Ranges are not a length stored in the descriptor: `KeyExpr` records the
path and wildcard, and `Bitcoin.Wallet.Descriptor.Expand` consumes the
explicit indices supplied by its key provider. That mirrors Core, where
`Descriptor::Expand(pos, ...)` takes the position as an argument
(`src/script/descriptor.cpp:1069-1071`).

The original text of a *key expression* is retained; the original text of
the whole descriptor is recovered by `Descriptor.render`, which re-emits the
raw key spellings. No semantic normalization occurs during parsing.
-/

namespace Bitcoin.Wallet.Descriptor

/-- A BIP32 wildcard marker at the end of a key path. Core distinguishes
three forms in `ParseDeriveType` (`src/script/descriptor.cpp:1968-1981`):
no wildcard, `*` (unhardened), and `*'` / `*h` (hardened). -/
inductive Wildcard where
  /-- No range: the key is expanded at the single implicit index 0. -/
  | none
  /-- `*`: unhardened wildcard (`DeriveType::UNHARDENED_RANGED`). -/
  | unhardened
  /-- `*'` or `*h`: hardened wildcard (`DeriveType::HARDENED_RANGED`). -/
  | hardened
deriving Repr, BEq, DecidableEq

/-- BIP32 key origin metadata: the 4-byte master fingerprint plus the
derivation path from the master key to `KeyExpr`'s xpub.

`fingerprint` is stored as exactly four bytes. `path` stores BIP32 child
numbers, with bit 31 set for hardened steps, exactly as Core's
`typedef std::vector<uint32_t> KeyPath` (`src/script/descriptor.cpp:195`).
-/
structure KeyOrigin where
  /-- The 4-byte master key fingerprint (`[deadbeef/...]` in the text). -/
  fingerprint : ByteArray
  /-- Child numbers from the master key to the xpub, hardened bit included. -/
  path : List UInt32
deriving Repr, BEq, DecidableEq

/-- One key expression: an optional origin followed by either a literal
public key or an extended public key plus derivation metadata.

The `raw` field is the original spelling of the whole expression (origin,
key body, path, wildcard). It is what `Descriptor.render` emits, so a parsed
descriptor round-trips to the checksummed payload without normalising `h`
to `'` or zero-padding path elements.

`KeyExpr.const` accepts:
* 33-byte compressed keys (`02`/`03` prefix),
* 65-byte uncompressed keys (`04` prefix) where the surrounding descriptor
  context permits them,
* 32-byte x-only keys only in a taproot context.

Curve validity is checked by the parser; this type only carries bytes.
-/
inductive KeyExpr where
  /-- A literal public key. `xonly` records that the source key was a
  bare 32-byte x-only key (only legal in `tr(...)`). -/
  | const (origin : Option KeyOrigin) (pubkey : ByteArray) (xonly : Bool)
      (raw : String)
  /-- An extended public key. `encoded` is the original Base58Check string;
  `path` is the explicit derivation path after the xpub; `wildcard` marks a
  trailing range. The actual child derivation is supplied by the key
  provider at expansion time. -/
  | xpub (origin : Option KeyOrigin) (encoded : String) (path : List UInt32)
      (wildcard : Wildcard) (raw : String)
deriving Repr, BEq, DecidableEq

namespace KeyExpr

/-- The origin attached to a key, if any. -/
def origin : KeyExpr → Option KeyOrigin
  | .const o _ _ _ => o
  | .xpub o _ _ _ _ => o

/-- The derivation path after the key body (empty for literal keys). -/
def path : KeyExpr → List UInt32
  | .const _ _ _ _ => []
  | .xpub _ _ p _ _ => p

/-- The wildcard marker (always `none` for literal keys). -/
def wildcard : KeyExpr → Wildcard
  | .const _ _ _ _ => .none
  | .xpub _ _ _ w _ => w

/-- Whether this key contributes more than one expansion position. -/
def isRanged : KeyExpr → Bool
  | .const _ _ _ _ => false
  | .xpub _ _ _ .none _ => false
  | .xpub _ _ _ _ _ => true

/-- The original source spelling of the key expression. -/
def raw : KeyExpr → String
  | .const _ _ _ r => r
  | .xpub _ _ _ _ r => r

end KeyExpr

/-- A parsed descriptor in the supported fragment.

`multi` and `sortedmulti` share one constructor: `sorted = true` is
`sortedmulti`. The parser enforces Core's context and cardinality rules
(`src/script/descriptor.cpp:2392-2525`); this type does not re-check them.

`tr` carries only the internal key: taproot script paths would require a
`TapTree` and are outside this fragment (`tr(key,tree)` is rejected by the
parser as an unexpected token). -/
inductive Descriptor where
  /-- `pk(key)`: a bare pay-to-pubkey output. -/
  | pk (key : KeyExpr)
  /-- `pkh(key)`: pay-to-pubkey-hash. -/
  | pkh (key : KeyExpr)
  /-- `wpkh(key)`: native v0 pay-to-witness-pubkey-hash. -/
  | wpkh (key : KeyExpr)
  /-- `sh(wpkh(key))`: P2SH-wrapped v0 pay-to-witness-pubkey-hash. -/
  | shWpkh (key : KeyExpr)
  /-- `multi(threshold,keys...)` or, when `sorted = true`,
  `sortedmulti(threshold,keys...)`. -/
  | multi (threshold : Nat) (keys : List KeyExpr) (sorted : Bool)
  /-- `tr(key)`: taproot key-path-only output. -/
  | tr (internalKey : KeyExpr)
deriving Repr, BEq, DecidableEq

namespace Descriptor

/-- The key expressions of a descriptor, in source order. -/
def keys : Descriptor → List KeyExpr
  | .pk k => [k]
  | .pkh k => [k]
  | .wpkh k => [k]
  | .shWpkh k => [k]
  | .multi _ ks _ => ks
  | .tr k => [k]

/-- Whether any key expression carries a range wildcard. -/
def hasRange (d : Descriptor) : Bool := d.keys.any KeyExpr.isRanged

end Descriptor

/-! ## Rendering

Rendering is intentionally a re-emission of the stored source spellings.
It exists to demonstrate that parsing preserves the checksum payload; it is
not a canonical stringifier (Core's `ToString` normalises `h` to `'`, which
this fragment does not do). -/

/-- Render a BIP32 path in descriptor syntax. Hardened child numbers are
printed with `'`; the hardened bit is `0x80000000`
(`src/util/bip32.cpp:17-39`). -/
def renderPath (path : List UInt32) : String :=
  String.intercalate "/" (path.map fun child =>
    let hardened := child ≥ 0x80000000
    let value := if hardened then child - 0x80000000 else child
    toString value.toNat ++ (if hardened then "'" else ""))

/-- Render the original source spelling of a key expression. -/
def renderKey (k : KeyExpr) : String := k.raw

/-- Render a descriptor back to its checksum-free payload. Because every
key is emitted from `KeyExpr.raw`, this reproduces the parsed input byte for
byte for the supported grammar. -/
def Descriptor.render : Descriptor → String
  | .pk k => s!"pk({renderKey k})"
  | .pkh k => s!"pkh({renderKey k})"
  | .wpkh k => s!"wpkh({renderKey k})"
  | .shWpkh k => s!"sh(wpkh({renderKey k}))"
  | .multi t ks sorted =>
      let name := if sorted then "sortedmulti" else "multi"
      s!"{name}({t},{String.intercalate "," (ks.map renderKey)})"
  | .tr k => s!"tr({renderKey k})"

end Bitcoin.Wallet.Descriptor
