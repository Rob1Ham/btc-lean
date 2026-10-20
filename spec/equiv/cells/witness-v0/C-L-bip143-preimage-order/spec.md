---
# Cell witness-v0/C-L-bip143-preimage-order
cell: C-L-bip143-preimage-order
family: witness-v0
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c024546e39f55775bfd9a077b042e3feeef4
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (byte-level 10-field assembly, symbolic payloads, script_len 0/1/75, SHA256d opaque)
precondition: |
  - WITNESS_V0 sighash preimage path, interpreter.cpp:1655-1670, with the
    ten fields in BIP143 order and `nHashType` appended after the arm.
  - scriptCode length `L` is one of the three concrete values 0, 1, 75.  These
    are the empty script, the smallest non-empty script, and the largest length
    whose CompactSize prefix is still one byte while staying at the
    minimal-push boundary.  The sibling cell `witness-v0/C-L-bip143-layout`
    proves the width/offset table for every 0 <= L <= 75, so the two cells
    together span the row's length domain.
  - All ten field payloads are symbolic byte arrays of exactly their BIP143
    width: version 4, hashPrevouts 32, hashSequence 32, txid 32, vout 4,
    script L, amount 8, nSequence 4, hashOutputs 32, nLockTime 4, nHashType 4.
    The cell observes where each payload lands, not how an integer becomes
    bytes: version/amount/nSequence/nLockTime/nHashType are already-encoded
    byte arrays (the LE encodings of serU32L/serAmountL are not re-derived).
  - `out` points to a writable buffer of 157+L bytes.  The functions write
    exactly those bytes and nothing outside that range.
  - SHA256d is NOT modelled and is not called.  It is an opaque function whose
    complete input is `out[0 .. 157+L)`; this cell proves that input.  The
    three sub-hashes and the transaction serializer are also opaque (same-hash
    / same-serializer premise, spec/equiv/README.md §7).
postcondition: |
  Both legs write the same 157+L bytes, in this exact order:

    [0,4)         version          4
    [4,36)        hashPrevouts     32
    [36,68)       hashSequence     32
    [68,100)      txid             32  (outpoint, part a)
    [100,104)     vout             4   (outpoint, part b)
    [104]         CompactSize(L)   1   (0x00 / 0x01 / 0x4b)
    [105,105+L)   script           L
    [105+L,113+L) amount           8   <- BIP143's added field, SCR-140
    [113+L,117+L) nSequence        4
    [117+L,149+L) hashOutputs      32
    [149+L,153+L) nLockTime        4
    [153+L,157+L) nHashType        4

  i.e. out == version # hashPrevouts # hashSequence # txid # vout
  # CompactSize(L) # script # amount # nSequence # hashOutputs # nLockTime
  # nHashType, the `bip143MsgL` concatenation (Digest.lean:288-305).  Both
  functions return 157+L, the number of bytes SHA256d consumes.

  The claim is byte-level and includes amount inclusion: all eight bytes of
  the spent output's amount sit between scriptCode and nSequence, at
  [105+L, 113+L), for symbolic amount contents.  Every preimage byte is
  attributed to exactly one field; there is no gap or overlap, and no byte
  outside [0,157+L) is written.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-140
scr_row_coverage: |
  partial, but this closes the layout half of the row at byte granularity.
  SCR-140 is "field order per BIP143; amount included".  Three claims are now
  checked:
    (a) the ten fields appear in BIP143 order as contiguous byte ranges of the
        preimage (byte-level, not just a width/offset table);
    (b) `amount` is present as 8 bytes at [105+L,113+L), between scriptCode and
        nSequence, with symbolic contents;
    (c) the total hashed length is 157+L, and nHashType is the last field.
  For L in {0,1,75}.  General L in [0,75] is covered by the width/offset table
  of C-L-bip143-layout.  Still outside SCR-140: the field CONTENTS/encodings
  (LE serialization of version/amount/sequence/locktime/hashtype), the three
  sub-hash definitions and the transaction serializer, and the SHA256d value.
  The row therefore stays partial and is not promoted to full.
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
  - spec/core/Bitcoin/SigHash/Digest.lean:288-305 (bip143MsgL concatenation)
  - spec/core/Bitcoin/SigHash/Digest.lean:279-286 (serAmountL = 8 bytes)
  - spec/equiv/README.md §7 (same-hash premise)
trust_note: >
  C is a byte-level, line-cited slice of SignatureHash's WITNESS_V0 serializer
  arm: the `ss << ...` order is reproduced with a running cursor and memcpy of
  the cited type widths.  It is not the real CHashWriter/SHA256d pipeline; the
  hash object is replaced by the returned input length.  L is a REVIEWED
  TRANSLITERATION of bip143MsgL with explicit absolute offsets rather than
  Core's cursor, so the Alive2 comparison is semantic (different formulations,
  same bytes).  Field payloads are symbolic; the LE encodings of integer fields
  and the three sub-hash definitions are abstracted, as is SHA256d.  This is a
  layout/order proof only, not a sighash-value proof.  Alive2 runs with
  `--bidirectional`; SAW checks both legs against the same Cryptol
  concatenation.  `noinline,optnone` is required because Alive2 v20 rejects the
  `nocapture` parameter attribute that clang -O1 infers for these pointer
  arguments.  No Core patch is used.
evidence:
  - alive2/result.txt (alive-tv v20, clang 20.1.2; three functions,
    --bidirectional)
  - saw/result.txt (SAW 1.6, solver z3; six proofs, C and L x three lengths)
  - alive2/certificate.sha256, saw/certificate.sha256
mutant: >
  Two mutants were tested out-of-tree, in the L leg only.  (1) Move `amount`
  after `nSequence` (write nSequence at 105+L and amount at 109+L; total length
  unchanged): SAW rejects it on the l0 spec with a concrete byte counterexample
  at `llvm_points_to out` (cell.saw:55), `Proof failed`.  (2) Drop the
  CompactSize byte (copy the script at 104 and shift amount/nSequence/... down
  by one; total length 156+L): SAW rejects it as a 157-byte read through a
  156-byte allocation at the same postcondition.  Alive2 does not decide either
  mutant within 120 s — the symbolic-memory difference times out — so the
  sensitivity evidence is SAW's; the Alive2 timeout is recorded as a tool
  limit, not a pass.
---

# witness-v0/C-L-bip143-preimage-order

Byte-level companion to `witness-v0/C-L-bip143-layout`.

## Why another BIP143 cell

`C-L-bip143-layout` proves a *descriptor table*: for each field id it returns
`width | offset << 8`, and the two legs agree on that table for every
`0 <= script_len <= 75`.  A table is not the preimage.  It does not prove that
the bytes actually assembled by the serializer are the ten fields in that
order, nor that `amount` is really written between scriptCode and nSequence.

This cell closes that gap at byte granularity.  Both legs take the ten field
payloads as symbolic byte arrays and write them into `out`; the observable is
the resulting 157+L-byte buffer plus the returned input length.  Alive2 checks
that the two buffer-writing functions agree (bidirectional), and SAW checks
each leg against the Cryptol concatenation `preimage_l*`.

## What is proved

For `L` in {0, 1, 75}, with every field payload symbolic:

- the ten fields occupy the contiguous ranges in the postcondition above, in
  BIP143 order;
- `amount` is 8 bytes at `[105+L, 113+L)`, i.e. after scriptCode and before
  nSequence (the SCR-140 "amount included" claim);
- scriptCode is `CompactSize(L) # script`, with a one-byte prefix
  (0x00/0x01/0x4b);
- nHashType is the final field;
- the return value is 157+L = the byte count SHA256d consumes;
- no byte outside `[0,157+L)` is written.

## What is not proved

- **SHA256d.**  Opaque, not called.  The digest is `H(out[0..157+L))` for an
  unmodelled `H`; only its input is proved.  This is the README §7 same-hash
  premise, not a hash proof.
- **Sub-hashes and serializer.**  `hashPrevouts`, `hashSequence`,
  `hashOutputs` are symbolic 32-byte payloads; the transactions and output
  vectors they summarize are not decoded (other rows/cells).
- **Field encodings.**  Integer fields arrive as already-encoded byte arrays.
  The cell does not re-derive the LE encodings (`serU32L`, `serAmountL`).
- **All script lengths.**  Only L = 0, 1, 75 are assembled.  The sibling
  layout cell proves the offset table for every L in [0,75]; CompactSize growth
  beyond 75 is outside both cells.

## Exact commands

```sh
bash spec/equiv/cells/witness-v0/C-L-bip143-preimage-order/alive2/run.sh
bash spec/equiv/cells/witness-v0/C-L-bip143-preimage-order/saw/run.sh
sha256sum -c spec/equiv/cells/witness-v0/C-L-bip143-preimage-order/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/witness-v0/C-L-bip143-preimage-order/saw/certificate.sha256
```

Alive2 v20.0 (`/opt/equiv-tools/alive-tv-v20.0`, LLVM 20.1.2), SAW 1.6
(68eed5f), clang 20.1.2.  SAW uses z3 (`src/solver.txt`); the descriptor
arithmetic in the sibling cell already needs z3, and the memcpy/array
obligations here do as well.
