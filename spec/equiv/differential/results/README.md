# Differential result runs

The primary files in this directory are the **current** run. Do not mix them
with the archived run.

| Run | Twin `libtwin.so` | Generated `twin.cpp` | C~L_twin | C~Lean model | C~expected | Determinism |
|---|---|---|---:|---:|---:|---|
| **current** | `b9ed129b…` | `39ab7c66…` | **922 / 0 / 336** | 1251 / 0 / 7 | 1258 / 0 | identical |
| `archive-d560/` | `d560a5f6…` | `7054375d…` | 854 / 0 / 404 | 1251 / 0 / 7 | 1258 / 0 | identical |

Counts are **agree / disagree / blocked**. The 336 blocked rows are the
twin's declared result `3` ("outside subset"), not disagreements; they are
what E1/E2 cells must turn green or file as gaps. The Lean-model lane is an
oracle cross-check and is never called L (F-HARNESS-001).

The archive is the first post-F-DIV-002 run; it is retained because it is the
run that exposed and verified the `OP_EQUAL` fix. It is not current evidence.

Hashes for the current run are in `summary.json` and in
`../../findings/differential/report.md`.
