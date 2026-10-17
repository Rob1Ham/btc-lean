# Lax ECDSA parsing: decision and residual boundary

## 1. Context

Bitcoin Core's legacy signature path parses DER loosely and then uses
`secp256k1_ecdsa_signature_parse_compact`. The compact parser calls
`scalar_set_b32` on the 32-byte `r` and `s` values. If a value is at least the
curve order `n`, the overflow path zeroes both scalars; the subsequent zero
check rejects the signature. The 32-byte **message hash** is reduced modulo
`n`, with overflow ignored.

BIP66 is a separate wire-encoding gate. It admits 33-byte DER integers, so a
value `r >= n` can pass BIP66 and reach the compact parser. The distinction
matters: BIP66 is about DER shape, not scalar range.

## 2. Decision

The model keeps the faithful Core split:

* the interpreter applies BIP66 strictness at the encoding boundary;
* the cryptographic seam models the compact parser's overflow rejection;
* no consensus rule is changed to make the model easier to prove.

The executable `verifyImpl` in `spec/core/Bitcoin/Crypto/Ecdsa/Verify.lean`
reduces `r` and `s` modulo `n` before the group equation. That is a deliberate
model simplification, not a claim about Core. The Core-faithful seam is
`verifyImplCore`, which rejects the overflow window. The SGN-107 targets prove
the Core-side rejection, the relationship between the two implementations, and
the exact window in which they differ:

```text
BitcoinProofs.AF.PDW95.verifyImplCore_overflow_rejects
BitcoinProofs.AF.PDW95.verifyImplCore_eq_of_window
BitcoinProofs.AF.PDW95.parseDerLax_sigFork
BitcoinProofs.AF.PDW95.isDERSignature_sigFork
BitcoinProofs.AF.PDW95.sigFork_core_rejects
BitcoinProofs.AF.PDW95.sgn107_verifyImpl_mod_n_invariant
```

## 3. What is and is not proved

The four seam theorems pin the flag/encoding dispatch, not the value-zeroing
inside `parse_compact`. SGN-107 is recorded as `proven` because its cited
targets include the Core-faithful rejection and an explicit divergence
theorem; the row summary states the divergence rather than hiding it.

The permanent limitation remains: these are theorems about the Lean model and
the documented Core source path. They are not a proof that Lean equals
`libsecp256k1`, and they are not a byte-level differential test of every
signature. The row-level review and conformance vectors provide that evidence.

## 4. References

* `spec/db/rules.yaml`, row `SGN-107`
* `src/pubkey.cpp:283` and `src/secp256k1/src/secp256k1.c:407-425` at
  Bitcoin Core `cce32b168`
* `spec/core/Bitcoin/Crypto/Ecdsa/Verify.lean`
* `spec/proofs/BitcoinProofs/AF/PDW95/` for the targets above
