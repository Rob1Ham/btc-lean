# cells/_tools/e2 — shared bounded-leaf tooling

Tools for the E2 numeric and hash op cells. They do not modify
`cells/_tools/mk_leaf.py` or any E1/control harness; they only add a cell
family and its build/run wrappers.

## Layout

- `e2_common.h` — bounded stack representations and packed observables.
  - `BStack` (depth 4, `uint32` element value): numeric op cells.
  - `HStack` (depth 4, 32-byte elements): hash op cells, so a 20/32-byte
    digest fits.
  - The packed formats encode `(result, error, depth, element metadata)` and
    are applied identically to both legs. A zero-length element
    canonicalises to value 0 (Core's `vchFalse` is the empty vector).
- `build_numeric.sh CELL_DIR` — emits `build/twin_ops.h` for `OP_WITHIN` via
  `mk_leaf.py` (`--max-depth 4 --max-elem 2`), checks it for drift, compiles
  the cell's `src/c_leaf.cpp` and `src/l_leaf.cpp`, and extracts
  `build/{c,l}_cell_within.{bc,ll}`.
- `build_hash.sh CELL_DIR` — emits `build/twin_ops.h` for `OP_HASH160`
  (`--max-depth 4 --max-elem 32`) for provenance, compiles the cell's
  sources, and extracts `build/{c,l}_cell_hash160.{bc,ll}`. The hash L leg is
  a reviewed transliteration because `mk_leaf.py`'s bounded copy is
  hard-wired to 2 bytes and cannot round-trip a 20-byte digest; see the cell
  notes.
- `run_alive2.sh CELL_DIR CELL_ID FN...` — calls `CELL_DIR/src/build.sh`,
  runs `alive-tv` per function, writes `alive2/result.txt` with the exact
  `STATUS=` line, and writes `alive2/certificate.sha256` from the repo root.
- `run_saw.sh CELL_DIR CELL_ID MIN_PROOFS` — calls `CELL_DIR/src/build.sh`,
  copies `src/cell.{cry,saw}` into `build/`, runs SAW with the pinned
  toolchain `PATH`, requires `MIN_PROOFS` `Proof succeeded!` lines and no
  `Proof failed` line, writes `saw/result.txt` and `saw/certificate.sha256`.

## Cell convention

Each cell has `src/{c_leaf.cpp,l_leaf.cpp,cell.cry,cell.saw,build.sh}` and
`{alive2,saw}/run.sh`. The `alive2/run.sh` and `saw/run.sh` are one-line
wrappers over the shared runners with the cell id and function list.

`src/build.sh` selects `build_numeric.sh` or `build_hash.sh`; it is the only
cell-specific build switch.

## Certificates

Both certificates are written relative to the repository root
(`/home/ubuntu/btc-lean-public`) with the `spec/equiv/...` prefix, matching
the control-flow/C-L-nop-return convention. They hash `spec.md`, the cell
`run.sh`/`src/`, the shared E2 tools, `mk_leaf.py`, `twin/ops_ir.py`,
`twin/gen.py`, `contract/error_kind.h`, the generated `build/twin_ops.h` and
`build/build.txt`, and the raw result (plus `cell.cry`/`cell.saw` for SAW).
Verify with:

```sh
cd /home/ubuntu/btc-lean-public
sha256sum -c spec/equiv/cells/e2-numeric/within-boundary/alive2/certificate.sha256
```
