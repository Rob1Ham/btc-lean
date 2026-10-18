# Trusted computing base and scope limits

This document states what the candidate artifact trusts and what it does not
claim. It is deliberately narrower than a security audit.

## 1. Kernel and libraries

A proof is accepted by the Lean 4 kernel after elaboration. The repository
pins Lean `v4.35.0` (`spec/lean-toolchain`, SHA-256
`ead308ab4fc749eb2389819903fd7baa11bf06e490827f6896a8cbfe622fa703`). The
following are trusted:

* the Lean 4 kernel and its compiler/elaborator;
* the standard library and the pinned mathlib revision
  `cfc55fc58714a59dc06e6e79edc6d1d95140d3c2`, together with the transitive
  packages recorded in `spec/proofs/lake-manifest.json`;
* the operating system, filesystem, and hardware used to run Lean.

The theorem package is the only package allowed to depend on mathlib. The
`spec/core` model has no Lake dependencies. A successful default
`BitcoinProofs` build means the 29-module import closure elaborates; the other
380 proof modules are outside that closure (a post-audit per-name run gives 372
builds and 8 failures, none cited; see [`PROOF-BUILD.md`](PROOF-BUILD.md)).
It does not mean the statements are the
right statements, and it does not compare Lean with C++ execution.

## 2. Axioms and `sorry`

The probed row-closing declarations have `#print axioms` fingerprints within

```text
propext, Classical.choice, Quot.sound
```

The committed static manifest is checked by
`bash spec/scripts/axiom_manifest.sh --check-static`; the dynamic probe
`bash spec/scripts/axiom_manifest.sh` re-elaborates the probed declarations
and prints their footprints. The consensus manifest has 223 entries (237
physical lines). The wallet layer has its own 844-declaration manifest and
accepts the same three axioms.

The gate-scanned `spec/core` and `spec/proofs` trees contain no `sorry`;
the proof tree is scanned for `sorry` and the core tree additionally for
`native_decide`, `unsafe`, `partial`, and FFI hazards. A lint pass is not a
proof of correctness; it is a hygiene gate.

## 3. The model is not bitcoind

`proven` is a kernel claim about a stated Lean proposition. The row census
(`spec/db/rules.yaml`) records the proposition as a one-line summary, a Bitcoin
Core anchor, and a Lean target. The kernel checks the target; it does not
prove that the target's conclusion is a faithful paraphrase of the summary.

Statement fidelity is a review obligation. Twenty-seven rows have a known gap
between the cited target and the row summary; they are listed with the missing
link in [`RESIDUALS.md`](RESIDUALS.md). A `proven` status is therefore not a
claim that every relevant Bitcoin behaviour is modelled, and it is not a count
of theorem declarations.

The consensus model is also not a network node. It does not implement peer
discovery, mempool policy, wallet behaviour, chain selection under adversarial
network conditions, or live consensus. The capstone replay is an offline
replay of serialized blocks, not a live-node test.

## 4. Cryptographic seams

The model contains executable definitions and proofs for the hash and signature
interfaces. The ECDSA and Schnorr layers are supported by line-cited ports,
conformance vectors, and algebraic laws. They are not a proof that Lean equals
`libsecp256k1` or Bitcoin Core's C++ execution. The permanent port-fidelity
gap is recorded in [`DECISION-lax-ecdsa.md`](DECISION-lax-ecdsa.md) and in the
row-level residual notes.

Taproot output-key linkage and witness-size/annex budgeting also have explicit
model gaps (`TPR-007`, `TPR-071`); they remain visible in
[`RESIDUALS.md`](RESIDUALS.md) rather than being counted as proved.

## 5. Wallet layer

The wallet layer is additive and separate from the consensus census:

* 140 wallet rows in `spec/db/rules-wallet.yaml` (DESC 30, MS 35, PSBT 30,
  WSP 31, SGN2 14);
* 40 tagged rows (37 recorded as entailed; three tagged rows also have partial
  obligations);
* 99 rows in the obligation register (30 PARTIAL, 69 UNMODELLED; 75 model gaps
  and 24 proof gaps);
* four corrected statements without a proof.

The wallet modules do not import into the consensus roots, and the wallet
census is never merged into the 726-row database. The wallet axiom manifest
covers 844 declarations and accepts the same three axioms. The complete
obligation register is [`WALLET-OBLIGATIONS.md`](WALLET-OBLIGATIONS.md).

## 6. Policy and obsolete rows

Fifty consensus rows are `obsolete`: duplicates, policy/availability
boundaries, or entries outside the modelled consensus surface. They remain in
the denominator and keep their IDs. A `consensus: false` row is catalogued
evidence about a boundary; it is not a consensus theorem even when its status
is `proven`.

## 7. External audit

No third-party security audit, certification, or endorsement is claimed.
Review records are evidence of the project's own checks, not an external
attestation.
