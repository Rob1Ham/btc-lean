# witness-v0/C-L-bip143-layout

The layout half of SCR-140: the 10-field BIP143 segwit v0 preimage order, field
widths/offsets, and the 8-byte `amount` slot (interpreter.cpp:1655-1670).

## Design

Two functions:

- `cell_bip143_field(field, script_len)` returns `width | offset << 8` for field
  ids 0..9 and 0 for any other id.
- `cell_bip143_total_len(script_len)` returns `157 + script_len`.

The C leg walks a running cursor in Core's `ss << ...` order; the L leg returns
explicit offset sums derived from `bip143MsgL`
(`spec/core/Bitcoin/SigHash/Digest.lean:288-302`).  The different formulations
make the Alive2 comparison semantic.

Precondition `0 <= script_len <= 75` keeps the CompactSize prefix at one byte
and the offsets inside the descriptor's 8-bit offset field.  The functions are
total over u64, but the layout claim is only made in that range; CompactSize
growth for larger scripts is not modelled.

## Exact commands

```sh
bash spec/equiv/cells/witness-v0/C-L-bip143-layout/alive2/run.sh
bash spec/equiv/cells/witness-v0/C-L-bip143-layout/saw/run.sh
sha256sum -c spec/equiv/cells/witness-v0/C-L-bip143-layout/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/witness-v0/C-L-bip143-layout/saw/certificate.sha256
```

## Versions

Alive2 v20.0 (`/opt/equiv-tools/alive-tv-v20.0`, LLVM 20.1.2), SAW 1.6
(68eed5f), clang 20.1.2.

## Solver note

`src/solver.txt` contains `z3`.  With the default `abc`, SAW does not converge
on the descriptor arithmetic within the run budget; z3 proves both functions on
both modules promptly.  `_tools/run_saw.sh` reads `src/solver.txt` if present
and otherwise uses `abc`; the chosen solver is recorded in `saw/result.txt` as
`# solver: z3`.

## Result

- Alive2: both functions `Transformation seems to be correct!` (semantic),
  `STATUS=alive2-green`.
- SAW: four `Proof succeeded!` (2 functions x C and L), `STATUS=saw-green`.

## Limits / blockers

- SCR-140 stays **partial**: the field contents (hashPrevouts/hashSequence/
  hashOutputs), the transaction serializer, and SHA256d are not modelled.
- `script_len > 75` is outside the claim (multi-byte CompactSize).
- The field id encoding is 0-based; Lean's own comment numbers `amount` as
  "field 6" (1-based).  Id 5 here is the same amount slot.
- `amount` is an 8-byte width only; its numeric value/range (SWT-055) is out of
  scope.
