---
# Cell witness-v0/C-L-bip143-layout
cell: C-L-bip143-layout
family: witness-v0
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (10-field preimage layout/offsets; contents abstracted)
precondition: |
  - WITNESS_V0 sighash path (interpreter.cpp:1655-1670), 0-based field id
    0..9.  `field` is symbolic and total (unknown ids return 0).
  - 0 <= script_len <= 75.  This keeps the CompactSize prefix one byte
    (`encCSL`) and the one-byte push boundary, and keeps every offset inside
    the 8-bit offset field of the descriptor.  The functions are total over
    u64, but the layout claim is only asserted in this range; CompactSize is
    not modelled for larger scripts, so lengths > 75 are outside the claim.
  - The transaction, its inputs/outputs, the three sub-hashes and SHA256d are
    NOT modelled.  Only widths and offsets are observed; the preimage bytes are
    opaque (same-hash premise, spec/equiv/README.md §7).
postcondition: |
  Field descriptor = width | offset << 8, with offsets measured from the start
  of the BIP143 preimage:
    id 0  version        width 4   offset 0
    id 1  hashPrevouts   width 32  offset 4
    id 2  hashSequence   width 32  offset 36
    id 3  outpoint       width 36  offset 68      (txid 32 + vout 4)
    id 4  scriptCode     width 1+script_len  offset 104
          (CompactSize prefix + script bytes)
    id 5  amount         width 8   offset 105+script_len
    id 6  nSequence      width 4   offset 113+script_len
    id 7  hashOutputs    width 32  offset 117+script_len
    id 8  nLockTime      width 4   offset 149+script_len
    id 9  nHashType      width 4   offset 153+script_len
    any other id         -> 0 (no such field)
  Total preimage length = 157 + script_len.  The `amount` field (id 5) is
  BIP143's added 8-byte value and sits between scriptCode and nSequence, which
  is the SCR-140 commitment.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-140
scr_row_coverage: |
  partial.  The row asks for "field order per BIP143; amount included".  This
  cell proves the complete 10-field order, every width and offset, and the
  presence/position of the 8-byte amount, for all field ids and all
  script lengths in [0,75].  It does not model the field CONTENTS: the three
  sub-hashes (hashPrevouts/hashSequence/hashOutputs), the transaction
  serializer, or the final double SHA256.  Those keep SCR-140 partial; it is
  not promoted to full.
patches: none
source_citations:
  - interpreter.cpp:1655-1656 (version, 4 bytes)
  - interpreter.cpp:1657-1659 (hashPrevouts then hashSequence, 32 bytes each)
  - interpreter.cpp:1660-1663 (outpoint: txid 32 + vout 4 = 36)
  - interpreter.cpp:1664 (scriptCode, CScript serialization = CompactSize + bytes)
  - interpreter.cpp:1665 (amount, 8-byte CAmount; BIP143's added field)
  - interpreter.cpp:1666 (nSequence, 4)
  - interpreter.cpp:1667-1668 (hashOutputs, 32)
  - interpreter.cpp:1669-1670 (nLockTime, 4; nHashType appended after the arm)
  - spec/core/Bitcoin/SigHash/Digest.lean:288-302 (bip143MsgL field order)
  - spec/core/Bitcoin/SigHash/Digest.lean:118-121 (htBase; not part of the
    layout but the value appended as field 9)
  - spec/equiv/README.md §7 (same-hash premise)
trust_note: >
  C is a line-cited layout slice of SignatureHash's WITNESS_V0 arm, not the
  whole sighash.  L is a REVIEWED TRANSLITERATION of bip143MsgL's concatenation
  order with explicit offset sums rather than Core's running cursor, so the
  Alive2 comparison is semantic.  Widths come from the Core serializer types
  and the Lean ser* helpers cited above.  The preimage contents and all hashes
  are opaque; this is a layout proof only.  No Core patch is used.
evidence:
  - alive2/result.txt (alive-tv v20, clang 20.1.2; two functions)
  - saw/result.txt (SAW 1.6, solver z3; four proofs)
  - alive2/certificate.sha256, saw/certificate.sha256
mutant: >
  Not executed here.  A useful mutant is placing `amount` after nSequence
  (offset 117+script_len instead of 105+script_len), which must fail at
  field 5, or omitting the CompactSize byte (width script_len), which must
  fail at field 4 and every later offset.  Both are single-field
  counterexamples, so the descriptor split does not hide them.
---
# witness-v0/C-L-bip143-layout

BIP143 replaced the legacy copy-and-delete sighash serialization with a fixed
10-field preimage.  SCR-140 is the two consensus-relevant claims about that
preimage: the field ORDER and the inclusion of the spent output's 8-byte
`amount` (which legacy sighash does not commit to).

## What is proved

Two functions, both total over the stated domain:

- `cell_bip143_field(field, script_len)` returns `width | offset << 8` for the
  ten fields, and 0 for any other id.
- `cell_bip143_total_len(script_len)` returns `157 + script_len`.

| # | field | width | offset |
|---:|---|---:|---:|
| 0 | version | 4 | 0 |
| 1 | hashPrevouts | 32 | 4 |
| 2 | hashSequence | 32 | 36 |
| 3 | outpoint | 36 | 68 |
| 4 | scriptCode | 1+len | 104 |
| 5 | amount | 8 | 105+len |
| 6 | nSequence | 4 | 113+len |
| 7 | hashOutputs | 32 | 117+len |
| 8 | nLockTime | 4 | 149+len |
| 9 | nHashType | 4 | 153+len |

Alive2 proves the C cursor form equal to the L explicit-sum form for all
(field, script_len); SAW checks both modules against the Cryptol table with
solver z3 (abc does not converge on the descriptor arithmetic), four proofs.

## What is not proved

- The CONTENTS of the three sub-hashes and the serialized transaction.  Those
  are other rows/cells; the digest here is not computed.
- CompactSize beyond one byte: `script_len` is restricted to [0,75].  For
  larger scripts `encCSL` grows and the offsets shift; that is outside this
  cell and is named as a limit rather than silently assumed.
- SHA256d over the preimage.

SCR-140 therefore stays partial: layout is complete, contents are not.
