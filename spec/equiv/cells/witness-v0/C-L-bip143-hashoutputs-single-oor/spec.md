---
# Cell witness-v0/C-L-bip143-hashoutputs-single-oor
cell: C-L-bip143-hashoutputs-single-oor
family: witness-v0
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (hashOutputs slot selection, total)
precondition: |
  - WITNESS_V0 sighash path (interpreter.cpp:1633), with `hash_type`,
    `n_in` and `vout_len` symbolic u64 values.
  - `hash_type & 0x1f` is the SIGHASH base class; the cell observes only that
    low 5-bit field.  SIGHASH_ALL = 1, SIGHASH_NONE = 2, SIGHASH_SINGLE = 3;
    every other base value falls through to the ALL branch, exactly as Core's
    `!= SINGLE && != NONE` test.
  - `vout_len` is txTo.vout.size() and `n_in` is nIn.  The transaction and its
    outputs are not decoded or serialized; only their count/index relation is
    observed.
  - The three hashes (all-outputs SHA256d, single-output SHA256d) are opaque:
    the cell proves which slot is selected, not the digest (same-hash premise,
    spec/equiv/README.md §7).
postcondition: |
  The BIP143 `hashOutputs` slot receives one of four modes:
    0 = the default-constructed uint256 (32 zero bytes)   <- SCR-141
    1 = uint256::ONE (legacy SIGHASH_SINGLE overflow)      <- NEVER produced
    2 = SHA256d over all outputs                           (ALL/unrecognised)
    3 = SHA256d over the single output vout[nIn]           (SINGLE in range)
  Precisely, with b = hash_type mod 32:
    b = 3 and n_in <  vout_len -> mode 3
    b = 3 and n_in >= vout_len -> mode 0   (SINGLE out of range)
    b = 2                      -> mode 0   (NONE)
    otherwise                  -> mode 2   (ALL / every other base)
  Mode 1 is unreachable for every input, which is the SCR-141 claim.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-141
scr_row_coverage: |
  full for "hashOutputs = 0 (not uint256::ONE)".  The row is exactly the
  SIGHASH_SINGLE-out-of-range selection: Core's default-constructed uint256
  stays zero because the `else if` body is not entered.  The cell proves the
  zero selection for every n_in >= vout_len and, crucially, that the legacy
  uint256::ONE mode is never selected by this code.  It also covers the NONE
  zero arm and the ALL/in-range arms so the selection is total.  The hash
  bytes themselves are not modelled and are not part of this row.
patches: none
source_citations: |
  - interpreter.cpp:1633-1635 (WITNESS_V0 arm; uint256 hashPrevouts /
    hashSequence / hashOutputs declarations, default zero)
  - interpreter.cpp:1647-1648 (ALL/unrecognised -> SHA256d over all outputs)
  - interpreter.cpp:1649-1652 (SINGLE in range -> SHA256d over vout[nIn])
  - interpreter.cpp:1653 (no else: hashOutputs stays zero for NONE and
    SINGLE out of range)
  - spec/core/Bitcoin/SigHash/Digest.lean:118-121 (htBase classification)
  - spec/core/Bitcoin/SigHash/Digest.lean:274-285 (hashOutputsL; zeroHashL
    for .noneHt and for SINGLE out of range, never singleOverflowOneB)
  - spec/equiv/README.md §7 (same-hash premise)
trust_note: >
  C is a line-cited source-excerpt slice of SignatureHash's WITNESS_V0 arm,
  not the whole sighash.  L is a REVIEWED TRANSLITERATION of the verified Lean
  hashOutputsL branch structure.  The two SHA256d computations are opaque
  modes; no hash implementation is claimed.  The legacy `uint256::ONE` mode is
  carried in the observable only to prove it is unreachable, mirroring the
  Lean distinction between zeroHashL and singleOverflowOneB.  Both tools prove
  the same total selection.  No Core patch is used.
evidence:
  - alive2/result.txt (alive-tv v20, clang 20.1.2)
  - saw/result.txt (SAW 1.6, solver abc; two proofs)
  - alive2/certificate.sha256, saw/certificate.sha256
mutant: >
  Not executed here.  A useful mutant is `n_in <= vout_len` for the SINGLE
  range test (must fail at n_in = vout_len: mode 0 vs 3), or reproducing the
  legacy behaviour by returning mode 1 for SINGLE out of range (must fail at
  n_in > vout_len; this is the exact consensus divergence SCR-141 guards).
---
# witness-v0/C-L-bip143-hashoutputs-single-oor

BIP143 keeps the `hashOutputs` preimage slot at its default zero value when
SIGHASH_SINGLE names an input index beyond the output vector
(interpreter.cpp:1647-1653).  Legacy `SignatureHash` instead returns the
famous `uint256::ONE` "SIGHASH_SINGLE bug" value.  SCR-141 is the statement
that the segwit v0 path does the former.

## What is proved

`cell_bip143_hashoutputs_mode(hash_type, n_in, vout_len)` returns the mode of
the selected slot:

| base (`& 0x1f`) | relation | mode |
|---|---|---|
| 3 (SINGLE) | n_in < vout_len | 3: SHA256d(vout[n_in]) |
| 3 (SINGLE) | n_in >= vout_len | 0: zero uint256 |
| 2 (NONE) | any | 0: zero uint256 |
| anything else (incl. 1 = ALL) | any | 2: SHA256d(all outputs) |

Mode 1 (`uint256::ONE`) is in the codomain of the observable but is returned
by no input.  Alive2 proves the C and L functions equal for all 2^192 input
triples; SAW proves both modules against the Cryptol predicate, two proofs.
The L leg uses a `switch`-shaped branch order, the C leg an if-chain, so the
comparison is semantic.

## What is not proved

- The two SHA256d computations and the 32-byte preimage contents (same-hash
  premise).
- The tx output serializer / tx decoder: only `vout_len` and `n_in` are
  observed.  SCR-140's layout cell covers widths and offsets separately.
- ANYONECANPAY, hashPrevouts and hashSequence are untouched (other rows).
