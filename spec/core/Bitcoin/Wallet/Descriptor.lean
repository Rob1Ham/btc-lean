import Bitcoin.Wallet.Descriptor.Ast
import Bitcoin.Wallet.Descriptor.Checksum
import Bitcoin.Wallet.Descriptor.Parse
import Bitcoin.Wallet.Descriptor.Expand

/-!
# Bitcoin.Wallet.Descriptor

An executable model of the output-descriptor fragment

```
pk, pkh, wpkh, sh(wpkh), multi, sortedmulti, tr(<key>)   (taproot key-path)
```

with literal public keys and BIP32 extended public keys, key origins,
derivation paths, and range wildcards.

## Module layout

* `Ast` — abstract syntax, source-preserving key spellings, rendering.
* `Checksum` — Core's BCH descriptor checksum, byte for byte.
* `Parse` — recursive-descent parser and the `#` checksum gate.
* `Expand` — scriptPubKey construction from a parsed descriptor and a
  key provider (the explicit-index boundary for BIP32 derivation).

## What is modelled

* The seven descriptor forms above at top level, with `multi` /
  `sortedmulti` limited to bare (non-`sh`, non-`wsh`) top-level use.
* Literal compressed keys everywhere the context allows, uncompressed keys
  in `pk` / `pkh` / bare multisig, and 32-byte x-only keys in `tr`.
* BIP32 key expressions with origin `[fingerprint/path]`, a child path, and
  `*` / `*'` / `*h` ranges. The parser validates the xpub Base58Check
  payload and version; expansion asks a `KeyProvider` for the keys at each
  explicit index.
* Core's checksum gate, including the required-checksum mode.
* `sortedmulti` ordering by `CPubKey::operator<`.

## What is not modelled

* BIP32 child derivation itself, private keys, and xprv/tprv descriptors.
* `addr`, `raw`, `combo`, `wsh`, `sh(multi)`, `sh(sortedmulti)`,
  `sh(pk)`, miniscript, and taproot script trees (`tr(key,tree)`).
* Multipath `<a;b>` key specifiers.
* Signature checking or spend semantics; this layer produces scriptPubKeys
  only.
* Network policy beyond recognising the `xpub` and `tpub` version bytes.

## Ground truth

Bitcoin Core `cce32b168` (v21.99 development snapshot). The per-module
docstrings cite the exact `src/script/descriptor.cpp`,
`src/script/solver.cpp`, `src/addresstype.cpp`, `src/pubkey.h`, and
`src/script/signingprovider.cpp` lines for each rule. The accompanying
`DESC.md` collects the same anchors and the vector-regeneration procedure.
-/

namespace Bitcoin.Wallet.Descriptor

end Bitcoin.Wallet.Descriptor
