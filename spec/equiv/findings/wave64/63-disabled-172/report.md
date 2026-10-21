# Wave 64 / task 63 — SCR-172 independent flip cell

Commit: this commit on `wave64/63-disabled-172`.
Branch: `wave64/63-disabled-172`, base `5946c024546e39f55775bfd9a077b042e3feeef4`.
Pin: Bitcoin Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.
Worktree: `/tmp/opencode/wave64/63-disabled-172`.
Additive only: no shared ledger, `results/**`, matrix, contract, pins, Lean,
wave32 cell, or existing file was edited. No push.

## Outcome

`disabled/C-L-w64-row172-flip` is a new, independent, both-tool cell. It
distinguishes the BASE/WITNESS_V0 disabled failure from the TAPSCRIPT
OP_SUCCESSx result for the same one-byte script, including both positions of
the `DISCOURAGE_OP_SUCCESS` policy bit.

| Tool | Result |
|---|---|
| Alive2 v20.0 | 2/2 `Transformation seems to be correct!` (1 correct / 0 incorrect / 0 failed-to-prove each) |
| SAW 1.6 | 4/4 `Proof succeeded!` (`cell_pair` C/L, `cell_flip` C/L) |

No blocker for this cell. The row remains **partial** only for the
arbitrary-length scan induction and the surrounding `ExecuteWitnessScript`
checks; those are named below, not hidden.

## The distinguishing table

`cell_pair(w, flags)` returns `(BASE << 32) | TAPSCRIPT` for a one-byte
non-push script (`0x4f <= w <= 0xff`). `cell_flip` is 1 exactly when the same
byte is BASE 17 and TAPSCRIPT 0 (flag clear) or 36 (bit 19 set).

Concrete evaluation of the verified C leaf (`build/matrix_main`, ad hoc,
not a tool proof):

| wire | BASE | TAPSCRIPT flag clear | TAPSCRIPT bit 19 | flip (both) |
|---|---|---|---|---|
| `0x7e 0x7f 0x80 0x81 0x83 0x84 0x85 0x86 0x8d 0x8e 0x95 0x96 0x97 0x98 0x99` | `17` | `0` | `36` | **1** |
| `0x50`, `0x62`, `0xbb`-`0xfe` | `64` (reaches switch) | `0` | `36` | 0 |
| `0x65`, `0x66`, `0xba`, `0xff`, `0x4f`, `0x7d`, `0x82`, `0x87`, `0x9a` | `64` | `66` (scan completes) | `66` | 0 |

The fifteen disabled wires are exactly the flip set. The non-disabled
OP_SUCCESSx bytes also become success in tapscript, but they were never
legacy-disabled, so they are excluded by `cell_flip`; this cell does not
inflate the row into "every OP_SUCCESSx byte was disabled".

## Policy-flag caveat

`SCRIPT_VERIFY_DISCOURAGE_OP_SUCCESS` is **policy/standardness**, not
consensus. Core's enum ordinal is 19 (`interpreter.h:143-144`) and
`script_verify_flags` maps a name to `1 << ordinal`, so the cell tests real
bit `0x80000`, not an abstract flag. The cell proves both branches:

- bit clear: tapscript returns `OK` (0) — the consensus success path;
- bit set: tapscript returns `SCRIPT_ERR_DISCOURAGE_OP_SUCCESS` (36) —
  a policy rejection.

The BASE `SCRIPT_ERR_DISABLED_OPCODE` (17) is consensus and independent of
the policy bit. The cell does not claim that block validation sets bit 19.

## Exact commands and raw outcomes

```sh
spec/equiv/cells/disabled/C-L-w64-row172-flip/alive2/run.sh
spec/equiv/cells/disabled/C-L-w64-row172-flip/saw/run.sh
```

Alive2 raw tail:

```
# command: alive-tv build/c_cell_pair.ll build/l_cell_pair.ll
Transformation seems to be correct!
  1 correct transformations / 0 incorrect / 0 failed-to-prove
# command: alive-tv build/c_cell_flip.ll build/l_cell_flip.ll
Transformation seems to be correct!
  1 correct transformations / 0 incorrect / 0 failed-to-prove
STATUS=alive2-green
```

SAW raw tail:

```
Proof succeeded! cell_pair   (C)
Proof succeeded! cell_pair   (L)
Proof succeeded! cell_flip   (C)
Proof succeeded! cell_flip   (L)
CELL_W64_ROW172_FLIP_SAW_GREEN
STATUS=saw-green
```

## Evidence hashes

| Artifact | SHA-256 |
|---|---|
| `alive2/certificate.sha256` | `a8a7ec76338958f806506999635cde4aaaeed13b07d912cc5159a17e305678c1` |
| `saw/certificate.sha256` | `2aff3a59045e0e9508bf42fd5a2d8d867d156e11bc4ebec4ea94897b10dc3357` |
| `alive2/result.txt` | `127ee5f759e5e1b6ab581ed1bf4c6927a0ab5c40f80bdad6e71adebddfa1d121` |
| `saw/result.txt` | `be39ac20977652a5a0bca9d9e8562aad54e3eb3a3b93123320adcfef2490dae2` |
| `spec.md` | `108e64d6fdf8846115a8281e6daf4dacefaf440ea80b56b82dc846f679e5e477` |
| `notes.md` | `7edde9ff1c21320558f5370078316288de6a24fb00ab24377a0defde7648f91d` |

Each certificate hashes the cell spec/notes/runner/sources, the contract
`error_kind.h`, the three pinned Lean source files
(`Interpreter/Defs.lean`, `Interpreter/Rules.lean`,
`Script/Tapscript/Delta.lean`), `build/build.txt` and the tool result. The
result and certificate files are tracked; `build/` is git-ignored, so
reproduction is `run.sh` (which rebuilds) followed by
`sha256sum -c certificate.sha256` from the repository root.

## What remains for the whole SCR-172 row

- Arbitrary-length scan induction: the pre-scan is a fold of the same
  per-byte predicate; this cell instantiates one byte.
- Push payloads, truncated pushes, decode ordering (F-DIV-001); the domain
  excludes `0x00`-`0x4e`.
- The rest of `ExecuteWitnessScript` (initial stack limit, 520-byte item cap,
  validation-weight budget, annex/control block) and EvalScript after the
  disabled guard: SCR-153/157/168 territory.
- Whether a node sets the policy bit (mempool vs block context), outside the
  consensus rule.
