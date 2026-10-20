# E1 mutation replay records

These are independent CELLS-E1 replays of the E1 gate mutations.  The real
repository source (`spec/equiv/twin/ops_ir.py` and
`spec/equiv/cells/_tools/gate/c_leaf.cpp`) was **never** modified.  Each run
used a disposable copy at `/tmp/opencode/cells-work/mut-repo`, applied one
exact textual mutation, ran the gate cell's Alive2 and SAW runners, then
restored the copy from the original file and reran the baseline green.

The separate `cells/_redteam/runs/` records are REDTEAM's own artifacts; this
directory is the independent CELLS-E1 replay used by `findings/cells/E1-report.md`.

Files:

- `M-E1-001.md` — OP_SWAP no-op, twin site.
- `M-E1-002.md` — OP_DUP second-from-top, twin site.
- `M-E1-003.md` — OP_ROT opposite direction, twin site.
- `M-E1-004.md` — OP_TOALTSTACK acts on main stack, twin site.
- `M-E1-006.md` — OP_DEPTH returns depth-1, twin site.
- `M-E1-007.md` — OP_PICK selects a neighbor, twin site.
- `M-E1-001-core-slice.md` — OP_SWAP no-op at the C source-slice site.

`raw/` contains the complete mutant and baseline `result.txt` files.  For
M-E1-004 the mutant SAW run fails during symbolic execution
(`Error during memory load`, non-green), not with a counterexample; the
mutant Alive2 run reports `Target is more poisonous than source`.  All other
mutants produce `Value mismatch` in Alive2 and `Proof failed` in SAW.

M-E1-005 (push-size 520 -> 521) is not part of this gate batch: the
`e1-push/size-boundary` cell does not exist yet, so it was not run.
