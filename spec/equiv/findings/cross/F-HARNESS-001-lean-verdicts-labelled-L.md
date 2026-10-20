# F-HARNESS-001 — Differential harness labels the Lean model as the L leg

- **status:** open (trust-base/labelling defect; data is usable, the label is not)
- **legs:** C, L (and the Lean model, which is not L)
- **cells:** all cells that would cite `differential/results/` as C-L evidence
- **severity for the claim:** high if uncorrected. The 1251/1258 agreement is
  a real result, but it is **C vs the Lean interpreter model**, not C vs the
  Lean-derived C++ twin compiled by clang. It cannot satisfy E1's C-L
  behavioral lane.

## Symptom

`differential/run.py` says it compares "the L leg's verdict in
`spec/data/l2/scr/results/tierC.l2r`" (line 10; `L_VERDICTS` at line 63).
`results/summary.json` emits that path under `l_leg` and
`results/c-l.jsonl` / `disagreements.md` call the comparison "C vs L".

`spec/data/l2/scr/README.md` states that `results/tierC.l2r` is produced by
`L2ScrRunner.lean`, a Lean DUT runner (`Backend.scrVerdict` clone) replaying
the corpus. It is the **model interpreter**, not the generated C++ twin in
`spec/equiv/twin/` compiled by the pinned clang. The file predates this
workstream (2026-10-18).

The summary also records a pin mismatch that the label hides:

> L verdicts were produced by the Lean L2-SCR runner whose oracle was read at
> **c50817fe**; the vendored corpus is pinned at **cce32b168**.

So even as a model oracle it is not at the C pin. The harness mitigated this
by checking `want` against the vector expectation for all 1258 rows
(`want_matches_vector_expected: 1258`), which makes the **C vs expected**
column trustworthy. It does not make the L column a twin result.

## Evidence

- `differential/run.py:10,63`
- `spec/data/l2/scr/README.md` (artefact table: `L2ScrRunner.lean`,
  `results/tierC.l2r`)
- `differential/results/summary.json` (`l_leg.source_pin_note`)
- `spec/equiv/GOAL.md:11-12` (L is the Lean-derived twin compiled by clang)

## What is still valid

- **C vs corpus expected: 1258/1258.** This validates the C shim/ABI and the
  corpus encoding, independent of L.
- **C vs Lean model: 1251 agree, 0 disagree, 7 blocked (witness).** This is a
  useful model-level differential and may be cited as `C-vs-Lean-model`, not
  as L. The 7 `UNJUDGED` witness/tapscript rows stay blocked.
- It is **not** LLVM IR evidence and **not** C-L.

## Disposition

1. Rename the harness's leg label to `lean_model` (and the output file to
   `c-lean-model.jsonl`), or keep the path but add
   `leg_identity: lean-model-not-twin` to every record.
2. Add a separate twin lane that loads `spec/equiv/twin/build/libtwin.so`
   (ABI v2) and replays the same tapes. Only that lane may be called C-L.
3. Do not copy the current 1251/1258 number into `results/matrix.md` or any
   SCR ledger row as L coverage. The C-vs-expected column may be used as
   C-leg validation.
4. If the Lean runner is retained as an oracle, record its `c50817fe` pin
   explicitly next to the `cce32b168` corpus pin; a model/pin drift finding
   is separate from this labelling defect.

## Owner

DIFFERENTIAL (harness), LEDGER (acceptance), EVALUATOR (audit).
