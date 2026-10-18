# Third-party provenance

Question this provenance review answers: **does any GPL-3.0
code live in `spec/`?**

**Finding: NO.** Zero GPL code is vendored anywhere in the repo (the only
GPL artifact ever identified — `remix7531/fips-180-4-lean` — was fetched
to a temporary clone for comparison during this review and never entered
`spec/`). Evidence per file below; structural clean-room comparison of
the SHA-256 implementations in §A.

## 1. Per-file third-party provenance

Paths in sections 1a, 1b, and 1d are relative to `spec/`.

### 1a. Lean sources in `spec/core/` (the kernel-trusted package)

| File | Origin | License | Clean-room status / notes | Compat with MIT project |
|---|---|---|---|---|
| `core/Bitcoin/Crypto/Seam/Hash.lean` (SHA-256 half) | Verbatim port of the project's original SHA-256 PoC (namespace rename only) | own code | The PoC was written from the FIPS 180-4 spec text (§4.2.2 constants, §5.1.1 padding, §6.2.2/6.2.3); header cites "Reference: NIST FIPS PUB 180-4" only. See §A for the structural diff vs the GPL repo. FIPS constants (K, H0) are mandated standard values, not copyrightable. | ✓ |
| `core/Bitcoin/Crypto/Seam/Hash.lean` (RIPEMD-160 half) | Clean-room implementation from the algorithm's spec tables (Bosselaers/Dobbertin/Preneel); cross-checked (results-only) against Core's `test/functional/test_framework/ripemd160.py` (MIT, Pieter Wuille) and `hashlib` | own code | Cross-check consumed digests, not code | ✓ |
| `core/Bitcoin/Crypto/Seam/Der.lean`, `core/Bitcoin/Crypto/Ecdsa/Der.lean` | Line-by-line transliteration of Bitcoin Core @ `cce32b168` (`pubkey.cpp::ecdsa_signature_parse_der_lax`, `interpreter.cpp::IsValidSignatureEncoding`/`CheckSignatureEncoding`) | Core = **MIT** (COPYING @ `cce32b168`: "The MIT License (MIT), Copyright (c) 2009-2026 The Bitcoin Core developers") | Port, not copy: translated to Lean `ByteArray`/`Nat` defs; Core notice cited in file headers. The MIT notice text is retained with these files (MIT §2 permission grant). | ✓ |
| `core/Bitcoin/Crypto/Curve/*`, `Ecdsa/Verify.lean`, `Field/Interface.lean` | project originals; constants (p, n, G, a=b) = secp256k1 domain parameters (public facts, SEC2) | own code | Domain parameters are uncopyrightable facts | ✓ |
| everything else in `core/Bitcoin/**` | project originals | own code | No third-party source detected (grep sweep: no license headers, no external repo names) | ✓ |

### 1b. Lean sources in `spec/proofs/`

| Item | Origin | License | Compat with MIT project |
|---|---|---|---|
| `proofs/BitcoinProofs/**` | project originals | own code | ✓ |
| mathlib (lake dep, `.lake/packages/mathlib`) | leanprover-community | **Apache-2.0** (LICENSE verified in-tree) | ✓ — Apache-2.0 is a one-way-compatible dep for MIT; the lake layout keeps it a leaf dep of `proofs/` only, so `spec/core` stays zero-dep and MIT-pure |
| batteries, aesop, Qq, plausible, LeanSearchClient, importGraph, proofwidgets (transitive lake deps) | leanprover-community / others | Apache-2.0 each (LICENSE files verified in-tree) | ✓ |
| Cli (transitive dep) | leanprover-community | MIT (LICENSE verified in-tree) | ✓ |
| **No GPL dep anywhere** — `fips-180-4-lean` is NOT in any lakefile/manifest | — | — | ✓ |

### 1c. Data in `spec/data/` and the release bundle

Paths in this table are relative to `spec/data/` in the candidate. The release
bundle preserves the source prefix `spec/vectors/`, so `core/tx_valid.json`
appears there as `spec/vectors/core/tx_valid.json`.

| File(s) | Upstream (pinned commit) | License (verified per-file, 2026-10-16) | Compat |
|---|---|---|---|
| `core/tx_valid.json`, `core/tx_invalid.json`, `core/script_tests.json`, `core/sighash.json` | bitcoin/bitcoin @ `cce32b168`, `src/test/data/*` | **MIT** (repo COPYING: "The MIT License (MIT), Copyright (c) 2009-2026 The Bitcoin Core developers"; the JSON test corpora carry no more restrictive per-file header) | ✓ |
| `bips/bip-0340_test-vectors.csv` | bitcoin/bips @ `927b6de…`, `bip-0340/test-vectors.csv` | bip-0340.mediawiki header at that commit: doc = **BSD-2-Clause**, `License-Code: BSD-2-Clause OR MIT OR CC0-1.0` → test-vector *code* selectable as **MIT/CC0** | ✓ (BSD-2-Clause permissive; MIT option available for the CSV) |
| `bips/bip-0341_wallet-test-vectors.json` | bitcoin/bips @ `927b6de…` | bip-0341.mediawiki header: **BSD-3-Clause** | ✓ (permissive; no copyleft) |
| `bips/bip-0143.mediawiki` | bitcoin/bips @ `927b6de…` | bip-0143.mediawiki header: **License: PD** (public domain) | ✓ |
| `anchors/*.raw/.hash/.parent/.seeds` | Fetched live from mempool.space / blockstream.info APIs by `spec/scripts/fetch_anchors.sh`, hash-verified against canonical block hashes; distributed only in the release bundle | **Public blockchain data** — raw mainnet blocks are factual ledger data, uncopyrightable in substance; scripts are own code | ✓ |
| `cve/*.json` | Curated from the public record + live-fetched mainnet txs (see `cve/README.md`) | own data | ✓ |

### 1d. Test and helper files (outside the kernel TCB)

| File | Origin | License | Compat |
|---|---|---|---|
| `core/Test/Script/Parser/Conformance.lean`, `core/Test/Script/Parser/run.sh`, `core/Test/Script/Parser/ref.py` | Parser conformance checks against the pinned Core behaviour; `ref.py` is the independent Python reference parser (MIT notice in the file) | Core = MIT for the derived parser; test harness = own code | ✓ (checks consume outputs, not Core code) |
| `Test/Sighash/SighashTest.lean`, `Test/Sighash/run.sh`, `Test/Sighash/crosscheck.py`, `Test/Sighash/mirror.py`, `Test/Crypto/EcdsaTest.lean`, `Test/Crypto/run_ecdsa.sh` | project originals (use `hashlib` at test time only) | own code | ✓ |
| `Test/Crypto/gen_ecdsa_vectors.py`, `gen_schnorr_vectors.py`, `gen_schnorr_random.py`, `taproot_sighash_crosscheck.py`, `taproot_verify_crosscheck.py`; `proofs/BitcoinProofs/{Conservation,EcdsaDeep,SmallCurve,Bip/B14,Property/Y11}` reference and generator scripts | project originals; independent Python references for the generated Lean tables and cross-checks | own code | ✓ |
| `spec/scripts/fetch_anchors.sh`, `spec/scripts/fetch_anchors2.sh` | own code (call public APIs; clone pinned upstreams to a temporary directory, never into the repository) | own code | ✓ |

## 2. License recommendation

**Recommendation: MIT** for the whole repo (spec/core, spec/proofs, docs, scripts), with:

* mathlib & friends remain external Apache-2.0 lake deps (no distribution
  action needed; the leaf-dependency boundary already isolates them);
* vendored data files keep their upstream notices in this table (MIT /
  BSD-2/3-Clause / PD — all one-way compatible with MIT);
* `fips-180-4-lean` stays **out** of the dependency graph: its GPL-3.0
  equivalence proofs and 1415 CAVP vectors are used as *cross-check
  evidence only* (never imported, never vendored), so no GPL obligation
  attaches.

MIT is the only choice that (i) matches the license of the dominant
upstream data source (Core test corpora), (ii) permits any future
re-licensing or dual-licensing (Apache-2.0 would too, but MIT is simpler
and matches the permissive posture of every vendored artifact), and
(iii) imposes no runtime obligations on users running the verified
checker. The rationale is the license policy summarized on this page.

## A. Clean-room verification: our SHA-256 vs `fips-180-4-lean` (GPL-3.0)

Structural comparison performed 2026-10-16 (the GPL repository was cloned to a
temporary directory, never added to the tree):

| Axis | `fips-180-4-lean` `impl/SHA256.lean` | ours (`Seam/Hash.lean`) |
|---|---|---|
| Namespace | `SHS.SHA256.Impl` | `BtcLean.Sha256` / `Bitcoin.Crypto.Seam.Hash.Sha256` |
| State representation | perf-tuned `RoundState` **struct** with inlined UInt32 fields `a..h`, single ctor-update round step | plain `Array UInt32` state, `Array.set!` chain in a `foldl` |
| Block representation | `Vector UInt8 64` / `Vector UInt32 16` (`toU32s`, `beU32`, `Fin`-indexed) | raw `ByteArray` + `Nat` offset (`readBE32 block off`) |
| Round fn names | `Ch`, `Maj`, `smallSigma0/1`, `bigSigma0/1`, `UInt32.rotr` redefinition | `ch`, `maj`, `smallSigma0/1`, `bigSigma0/1`, `rotr` — names taken from FIPS 180-4 §4.1.2 notation, the only (inevitable) overlap |
| Size / style | 343+ LOC, `@[inline]` hot-path tuning, `impl.Unroll` import, ~170 MiB/s | ~150 LOC, zero attributes, no imports beyond `Bitcoin.Data.Basic`, kernel-`decide`-able |
| Architecture | separate spec/impl/equiv packages with machine-checked impl↔FIPS equivalence | single file + one `omega` padding theorem (`pad_size_multiple`) |
| Padding | shared `Preprocessing.lean` module | inline `pad`, independently derived `k = (55 + 64 - len % 64) % 64` |

Conclusion: independent derivations from the same FIPS 180-4 text. Shared
tokens are limited to FIPS-standard terminology and the mandated constants
(`K`, `H0`) that any conforming implementation must reproduce verbatim.
No GPL expression copied. The original PoC predates any clone of the GPL
repository.

---
Review method: repo-wide grep for license markers and
upstream repo names (excluding `.lake/`), per-file license-header fetch of
the pinned upstream commits, structural diff of SHA-256 sources. Re-run the data checksum manifest under `spec/data/`; nothing else in the
provenance surface is mechanical today.
