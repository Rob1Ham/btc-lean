# Read this before citing `differential/results/`

**There are two L-shaped lanes. Only `L_twin` is the L leg.**

| Key | Artifact | Identity | May be cited as |
|---|---|---|---|
| `L_twin` | `spec/equiv/twin/build/libtwin.so` (ABI v2) | `twin-libtwin` | **C-L** |
| `L` | `spec/data/l2/scr/results/tierC.l2r` | `lean-model-not-twin` | **C-vs-Lean-model** only |

- The primary `status` / `agree` fields in `c-l.jsonl` and `summary.json`
  are the **C vs L_twin** comparison.
- `L` is produced by `L2ScrRunner.lean` (the Lean interpreter model), oracle
  pin `c50817fe` — not the generated twin. Its comparison is
  `c_vs_lean_model` / `lean_model_status`. See
  `../../findings/cross/F-HARNESS-001-lean-verdicts-labelled-L.md`.
- `C vs corpus expected: 1258 / 1258` **is** a valid C-leg check.
- `L_twin` result `3` is the twin's declared outside-subset boundary: those
  rows are **blocked**, not disagreements.
- Behavioral agreement is **not** LLVM IR evidence.

Current recorded run: C~L_twin `854 agree / 0 disagree / 404 blocked`;
C~Lean-model `1251 agree / 0 disagree / 7 blocked`.

An earlier twin build (`9d787f1b…`) had one C-L disagreement, `sc-0365`
(twin `EQUAL`-false encoding). It is fixed in the recorded twin
(`d560a5f6…`); see
`../../findings/differential/F-DIV-002-twin-equal-false-encoding.md`.
