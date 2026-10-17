import Bitcoin.Wallet.Encoding.Base58
import Bitcoin.Wallet.Encoding.Bech32

/-!
# Bitcoin.Wallet.Encoding

Umbrella module for the two textual encodings used by wallet artifacts:

* `Base58.lean` — Bitcoin's base58 alphabet, byte-level encode/decode with
  leading-zero handling, and Base58Check over the existing SHA-256d;
* `Bech32.lean` — Bech32 and Bech32m checksums, 5-bit regrouping, and
  segwit v0/v1 address encode/decode.

The consensus tree does not import this module.  Hash arithmetic is the
existing executable floor in `Bitcoin.Crypto.Seam.Hash`; nothing here
reimplements SHA-256.  Both modules carry their own `#eval` conformance
blocks, so importing this umbrella also runs the official-vector checks
when the modules are elaborated.

Scope boundary: no WIF, BIP38, address book, network registry, error
localisation, or witness versions other than 0 and 1.  See the per-module
docstrings for the exact omissions and the Core line anchors.
-/
