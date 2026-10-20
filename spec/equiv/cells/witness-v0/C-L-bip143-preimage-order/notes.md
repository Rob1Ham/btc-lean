# witness-v0/C-L-bip143-preimage-order

Byte-level BIP143 preimage assembly: the ten fields in order, `amount` included,
with symbolic payloads and SHA256d left opaque.  Companion to
`witness-v0/C-L-bip143-layout` (which proves the width/offset table for every
`0 <= script_len <= 75`).

## Design

Three function pairs, one per concrete scriptCode length:

- `cell_bip143_preimage_l0`  (scriptCode empty, total 157)
- `cell_bip143_preimage_l1`  (one-byte scriptCode, total 158)
- `cell_bip143_preimage_l75` (75-byte scriptCode, total 232)

Each takes `out` plus eleven symbolic payload pointers (version, hashPrevouts,
hashSequence, txid, vout, script, amount, nSequence, hashOutputs, nLockTime,
nHashType), writes the preimage, and returns `157 + L`.

The C leg walks a running cursor in Core's `ss << ...` order; the L leg writes
the same bytes at explicit absolute offsets derived from `bip143MsgL`
(`spec/core/Bitcoin/SigHash/Digest.lean:288-305`).  Different formulations, so
the Alive2 comparison is semantic.

`scriptCode` is written as the one-byte CompactSize prefix `L` followed by the
script payload: `0x00`, `0x01`, `0x4b` for the three lengths.

## Why these three lengths

`L = 0` and `L = 1` pin the smallest cases; `L = 75` is the largest length
where the prefix is one byte and the script is still at the minimal-push
boundary.  All offsets that depend on L are therefore exercised at both ends.
The all-lengths claim remains with the sibling layout cell; this cell does not
claim `L > 75` (multi-byte CompactSize).

## Tool notes

- **`noinline,optnone`.**  At `-O1`, clang infers the `nocapture` parameter
  attribute for these pointer arguments, and Alive2 v20 rejects it
  (`ERROR: Unsupported attribute: nocapture`).  `optnone` keeps the attribute
  inference off and leaves each `memcpy` as a memory intrinsic in the IR.
- **Alive2 `--bidirectional`.**  The cell-local runner runs both directions, so
  `L ⊑ C` and `C ⊑ L` are each a real tool result (the shared witness-v0
  runner only runs C-vs-L one way; this cell does not rely on that).
- **SAW** verifies both legs against the same Cryptol concatenation spec, six
  proofs per run with z3.
- **Committed IR.**  `ir/*.ll` are the extracted per-function modules built by
  the shared `witness-v0/_tools/build.sh`; their `ModuleID`/`source_filename`
  comments record this worktree path, as with the other wave cells.

## Exact commands

```sh
bash spec/equiv/cells/witness-v0/C-L-bip143-preimage-order/alive2/run.sh
bash spec/equiv/cells/witness-v0/C-L-bip143-preimage-order/saw/run.sh
sha256sum -c spec/equiv/cells/witness-v0/C-L-bip143-preimage-order/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/witness-v0/C-L-bip143-preimage-order/saw/certificate.sha256
```

## Versions

Alive2 v20.0 (`/opt/equiv-tools/alive-tv-v20.0`, LLVM 20.1.2), SAW 1.6
(68eed5f), clang 20.1.2, solver z3.

## Result

- Alive2: three functions `These functions seem to be equivalent!` /
  `Transformation seems to be correct!`, `STATUS=alive2-green`.
- SAW: six `Proof succeeded!` (three lengths x C and L), `STATUS=saw-green`.

## Mutant

Two out-of-tree mutants, L leg only.

1. **Amount order swap**: write nSequence at `105+L` and amount at `109+L`
   (total length unchanged).  SAW rejects the l0 spec with a byte
   counterexample at `llvm_points_to out` (`cell.saw:55`), `Proof failed.`
2. **Dropped CompactSize byte**: copy the script at 104 and shift every later
   field down by one (total 156+L).  SAW rejects it as a 157-byte read through
   a 156-byte allocation at the same postcondition.

Alive2 does not decide either mutant within 120 s (symbolic-memory difference
times out).  That is a tool limit recorded here, not a pass; mutant sensitivity
is established by SAW.

## Limits / blockers

- SCR-140 stays **partial**: SHA256d, the three sub-hash definitions, the tx
  serializer, and the LE encodings of integer fields are outside the cell.
- Field payloads are symbolic byte arrays; the cell proves placement, not
  encoding.
- Only L = 0, 1, 75 are assembled.  General L in [0,75] is the sibling layout
  cell's claim; multi-byte CompactSize is outside both.
- The 0-based field id in the sibling cell numbers `amount` as id 5; Lean's
  comment calls it "field 6" (1-based).  Same slot.
