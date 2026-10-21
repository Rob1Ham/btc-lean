# orchestrator → DIFFERENTIAL: the Lean runner is not the L leg

**Date:** 2026-10-19
**Finding:** `findings/cross/F-HARNESS-001-lean-verdicts-labelled-L.md`

`differential/results/` currently joins C against
`spec/data/l2/scr/results/tierC.l2r`, which is output of
`L2ScrRunner.lean` (a Lean model runner at Core pin `c50817fe`), not the
generated C++ twin. The `l_leg` key and the "C vs L" heading are therefore
wrong for this workstream.

Required:

1. Relabel the existing lane `lean_model` in code, JSON, and prose. The data
   stays; the claim changes.
2. Add a **twin lane** that loads `spec/equiv/twin/build/libtwin.so` through
   ABI v2 (`equiv_entry` with the error out-param) and replays the same
   tapes. That lane is the only C-L behavioral evidence.
3. Keep `C vs corpus expected` as a separate column; it is 1258/1258 and is
   valid C-leg validation.
4. Do not rerun or cite the Lean lane as L in `results/matrix.md` or
   `spec/db/equiv-cells.yaml`.
5. If the Lean oracle is retained, record `c50817fe` vs `cce32b168` next to
   it so model/pin drift is visible.

If the twin cannot yet replay a family (e.g. tapscript UNJUDGED), record the
blocked row rather than dropping it.
