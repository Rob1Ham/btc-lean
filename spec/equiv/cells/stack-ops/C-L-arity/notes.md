# stack-ops/C-L-arity

SCR-074, "each op checks depth ⇒ INVALID_STACK_OPERATION", over the
2DROP..TUCK band (`interpreter.cpp:705-875@cce32b168`).

## What changed

The cell used to have one closed function per opcode, all at an empty stack
(`n = 0`).  Since every opcode's guard is `n < K`, that table could not tell
`K = 6` from `K = 2` (wave16b audit S2-2).  It now has **one row per (opcode,
depth)** in `table.csv`:

| kind | rows | depth | expected |
|---|---:|---|---|
| underflow | 39 | every `d < K` | `INVALID_STACK_OPERATION` (18) for all seed bytes |
| boundary | 16 | `d == K` | guard admits; net case depth `post_depth` |

`K` per opcode: 1 for IFDUP/DROP/DUP, 2 for 2DROP/2DUP/NIP/OVER/PICK/ROLL/
SWAP/TUCK, 3 for 3DUP/ROT, 4 for 2OVER/2SWAP, 6 for 2ROT.  Total 55 rows =
39 underflow + 16 boundary.

Rows that the old cell already had (depth 0): 16.  Rows it did not have: **39**
= 23 missing insufficient depths (all the `1..K-1` cases) plus all 16
boundary rows.  The `old_cell` and `previously_missing` columns in `table.csv`
mark them; `check_table.py` refuses a table whose columns disagree with that
split.

## Rows and observable

`src/table.csv` is the census.  Each row names the Core case line and guard
line, the wire, the arity, the depth, the expected packed value, and the
function name.

- Underflow rows take six symbolic seed bytes and must return `0x48`
  (`res=0`, `18 << 2`).  Because the bytes are symbolic on both legs, the SAW
  proof says the verdict is independent of element content — the guard is a
  pure depth test.
- Boundary rows seed the stack with the uniform one-byte `0x01` (PICK/ROLL
  put the zero-length index 0 on top) and assert `pack_vals`:
  `res=1 | post_depth<<8 | 0x01 in each live slot`.  The C side models only the
  net depth of the case body; element semantics and order are not claimed.

The observable function lives in `src/arity_common.h` and is used by both
legs.  It is always-inline on purpose: the family header's `pack_vals` is
plain `static inline` and clang keeps it as a call at `-O1`, which alive-tv
then rejects as an unknown libcall.

## Tools

- **Alive2** `alive2/result.txt`: 55/55 rows
  `Transformation seems to be correct` / `1 correct transformations`.
  Alive2 is invoked with `--src-unroll=16 --tgt-unroll=16`; without it the
  2ROT boundary row fails to reach a return instruction because the twin's
  four-iteration shift loop is not unrolled (alive-tv default unroll is 0).
- **SAW** `saw/result.txt`: 110/110 `Proof succeeded!` (C and L for each row),
  `STATUS=saw-green`.  `src/cell.cry` re-states the packed format
  independently; `src/cell.saw` is generated from `table.csv` by
  `src/gen_saw.py` (the runner fails on drift).
- **Mutations** `mutations/result.txt` (`STATUS=mutants-killed`): three
  threshold mutants patch the generated `build/twin_ops.h` only.

  | mutant | depth 0 | new rows |
  |---|---|---|
  | 2ROT `n<6 → n<2` | green (survives) | d2, d5 red |
  | NIP `n<2 → n<1` | green (survives) | d1 red |
  | 2ROT `n<6 → n<7` | green (survives) | boundary red |

  The first two are exactly the mutants S2-2 said would survive: they are
  invisible at the only depth the old cell had.  The third is the opposite
  error (too strict) and is caught only by a boundary row.

## Certificates

`alive2/certificate.sha256`, `saw/certificate.sha256` and
`mutations/certificate.sha256` list every tracked input in the cell (table,
leaves, checkers, spec generator, this note, the cell spec), the family
harness, `mk_leaf.py`, the twin sources and `error_kind.h`, plus the raw
`result.txt`.  Ignored `build/` products are not hashed, so the certificates
replay with `sha256sum -c` from the repository root on a clean checkout.
`src/normalize_cert.py` is the cell-local equivalent of
`spec/equiv/tools/normalize_certificates.py` and runs at the end of each
runner.

## Trust and non-claims

C is a line-cited source-excerpt model of the guard, plus the documented net
depth of each case body for the boundary rows; it is not Core's full
`EvalScript`.  L is the twin handler, generated verbatim from
`twin/ops_ir.py`.  The seed and packer are cell harness, identical on both
legs.  The enumeration is bounded: depth ≤ 6, one-byte elements, uniform seed,
base sigversion, no budget edge, `nOpCount = 0`.  Depths above `K` other than
the boundary, symbolic depth, element semantics, and budget-first ordering are
out of scope.  The Lean side (`BitcoinProofs.AF.PDW79b.stepBody_*_depth`)
quantifies an arbitrary `st.stack.length < K`; this table is the bounded C/L
witness for that face.
