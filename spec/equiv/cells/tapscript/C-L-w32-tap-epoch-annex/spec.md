---
# Cell tapscript/C-L-w32-tap-epoch-annex
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
lean_model_rev: 4d62a97e551082a69b13f495365bff0a903b0c99
legs: C, L
cell: C-L-w32-tap-epoch-annex
family: tapscript
tool_status: both-green for the three modelled facts; SCR-169 is PARTIAL
precondition: |
  - SigVersion in {TAPROOT (0), TAPSCRIPT (1)}; no other value reaches the
    BIP341 message builder (Core asserts at interpreter.cpp:1506, Lean
    extFlagOf returns none).
  - hash_type is any 8-bit value (SCR-163 governs validity; this cell does
    not re-check it).
  - annex_present is a boolean; the annex hash, when present, is an
    arbitrary 32-byte uint256 (execdata.m_annex_hash).
  - SHA256, TaggedHash("TapSighash") and the transaction-level sub-hashes
    are abstracted (same-hash premise, see trust_note).
postcondition: |
  - cell_epoch_ht: the first two bytes of the hashed message are
    0x00 (EPOCH) then hash_type.
  - cell_spend_type: spend_type = 2*ext_flag + annex_present, with
    ext_flag = 0 (TAPROOT) / 1 (TAPSCRIPT); the value is exposed with
    ext_flag.
  - cell_annex_slice: the annex-hash slice is empty when no annex is
    present, otherwise exactly 32 bytes whose first word is the supplied
    uint256 word unchanged.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-169
scr_row_coverage: partial — the epoch byte/position, the spend_type formula
  and the annex-hash inclusion/length/first-word placement are proved for
  all inputs in the domain; the SHA256 of the annex, the TapSighash tagged
  hash, the tx-level sub-hashes and the full SigMsg byte order are not
  modelled.  The row's own text names the digest, so the row is not claimed
  full.
patches: none
source_citations:
  - "interpreter.cpp:1529-1533 (EPOCH = 0; ss << EPOCH; ss << hash_type)"
  - "interpreter.cpp:1543-1546 (have_annex; spend_type = (ext_flag<<1)+annex)"
  - "interpreter.cpp:1554-1556 (if (have_annex) ss << m_annex_hash)"
  - "interpreter.cpp:1964 (m_annex_hash = SHA256(CSize(len) || annex))"
  - "interpreter.cpp:1494-1508 (ext_flag 0/1 by SigVersion)"
  - "spec/core/Bitcoin/Crypto/Taproot/Sighash.lean:171-183 (extFlagOf, spendType)"
  - "spec/core/Bitcoin/Crypto/Taproot/Sighash.lean:257-300 (sigMsgTaproot, sighashTaproot)"
  - "spec/core/Bitcoin/Crypto/Seam/Interface.lean:105-110 (validationWeightLeft, annexHash)"
trust_note: >
  SAME-HASH CONDITION: no SHA256 is linked into either leaf.  Both legs
  treat the annex hash as an uninterpreted 32-byte input and the tagged
  hash as an uninterpreted function; the cell proves the epoch byte, the
  spend_type byte and *that/where* the annex hash is appended, never the
  digest value.  This is not a claim that the model has no SHA256: the
  pinned Lean tree defines an executable `Seam.Hash.sha256`
  (`Crypto/Seam/Hash.lean:133`, re-exported at
  `Crypto/Seam/Interface.lean:62`) plus a size theorem, and Core computes
  the annex hash with `HashWriter` (`interpreter.cpp:1964`).  What is
  missing is the same-hash link between those two implementations, not a
  model.  C is a line-cited slice of SignatureHashSchnorr; L is a reviewed
  transliteration of the Lean equations.  The packed observables are cell
  harness.  This cell must not be read as an SCR-169 closure.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: "use ext_flag 0 for TAPSCRIPT (spend_type 0/1 instead of 2/3), or append the annex hash unconditionally; expect both tools to fail"
mutant_site: "src/c_leaf.cpp / src/l_leaf.cpp cell_spend_type / cell_annex_slice"
---

# Cell `tapscript/C-L-w32-tap-epoch-annex`

SCR-169 names three things: epoch 0, spend_type, and the annex hash. This
cell proves the structural parts and records the hash lane as open.

| Fact | Status | How |
|---|---|---|
| first message byte is epoch 0x00, then hash_type | proved | `cell_epoch_ht` |
| `spend_type = 2*ext_flag + annex_present`, ext 0/1 | proved | `cell_spend_type` |
| annex hash appended iff present, 32 bytes, verbatim word | proved (structure) | `cell_annex_slice` |
| `sha_annex = SHA256(CSize(len) ‖ annex)` | **not modelled** | needs the Core↔Lean same-hash link |
| full SigMsg order / TAGFIX / tagged hash | **not modelled** | SCR-169 blocker |

## Exact blocker for the rest of SCR-169

- **SHA256.** No SHA256 is linked into either leaf. The Lean tree does
  contain an executable `Sha256.sha256` (`Crypto/Seam/Hash.lean:133`,
  re-exported at `Crypto/Seam/Interface.lean:62`), and Core computes
  `execdata.m_annex_hash = (HashWriter{} << annex).GetSHA256()`
  (`interpreter.cpp:1964`). The missing piece is a proved same-hash link
  between `HashWriter` and the Lean definition; substituting an
  uninterpreted function would prove only the surrounding byte layout,
  which is what this cell already does.
- **Full preimage.** `sigMsgTaproot` concatenates eight serialized fields
  including four tx-level sub-hashes, a `CTxOut` serialization for ACP and
  the SIGHASH_SINGLE output hash. Proving the whole byte order needs a tx
  decoder + serializer model, which the tape contract does not provide at
  the leaf seam.
- **Smallest next experiment.** Link Core's `HashWriter`/`SHA256` from the
  pinned `ir/` closure as an opaque symbol and prove
  `sha_annex(annex) == HashWriter{}(CSize(len) || annex)` on the concrete
  vectors, and evaluate Lean `Sha256.sha256` on the same vectors so the
  two agree. Then extend `cell_annex_slice` with the actual digest. That is
  a different (crypto-lane) cell, not an extension of this one.
