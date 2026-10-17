import Bitcoin.Wallet.Psbt.Model
import Bitcoin.Wallet.Psbt.Decode
import Bitcoin.Wallet.Psbt.Encode
import Bitcoin.Wallet.Psbt.Laws
import Bitcoin.Wallet.Psbt.Tests

/-!
# PSBT v0

Umbrella module for the version-0 Partially Signed Bitcoin Transaction
model built from the pinned Bitcoin Core tree (`src/psbt.h`,
`src/psbt.cpp`, commit `cce32b168`).

* `Bitcoin.Wallet.Psbt.Model` — typed maps, key types, `WellFormed`,
  `extract`.
* `Bitcoin.Wallet.Psbt.Decode` — byte-level decoder and error
  constructors.
* `Bitcoin.Wallet.Psbt.Encode` — canonical encoder, sorting, and framing
  inversions.
* `Bitcoin.Wallet.Psbt.Laws` — payload inversion lemmas, lifecycle laws,
  and the explicitly stated whole-file round-trip targets.
* `Bitcoin.Wallet.Psbt.Tests` — the Core-validated vector corpus.

PSBT version 2 and cryptographic verification are out of scope; see the
not-modelled lists in `Model` and `Encode`.
-/
