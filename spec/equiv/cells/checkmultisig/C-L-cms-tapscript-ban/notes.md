# Notes — `checkmultisig/C-L-cms-tapscript-ban`

- **repo_head:** `805c8042f92d3bed909ca40219a4d21fc9150cc1`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **contract:** v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **row:** SCR-121, `scr_row_coverage: full`
- **patches:** none
- **status:** Alive2 green (1/1, bidirectional); SAW green (2/2 proofs,
  1 case).

## Reproduce

From the repository root:

```bash
bash spec/equiv/cells/checkmultisig/C-L-cms-tapscript-ban/alive2/run.sh
bash spec/equiv/cells/checkmultisig/C-L-cms-tapscript-ban/saw/run.sh
sha256sum -c spec/equiv/cells/checkmultisig/C-L-cms-tapscript-ban/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/checkmultisig/C-L-cms-tapscript-ban/saw/certificate.sha256
```

## Toolchain

| Tool | Version |
|---|---|
| clang/clang++ | Ubuntu clang 20.1.2 (0ubuntu1~24.04.3) |
| LLVM | Ubuntu LLVM 20.1.2 |
| alive-tv | Alive2 v20.0 (Ubuntu LLVM 20.1.2) |
| SAW | 1.6 (`68eed5f release-1.6`) |

## Design

- C leg: `interpreter.cpp:1113-1146`.  The tapscript test is literally the
  first statement of the shared CHECKMULTISIG arm (line 1118) and returns
  ordinal 50 before the arity, count, range and opCount work.
- L leg: reviewed transliteration of `checkMultiSig` with the
  `if ctx.sv = .tapscript` branch first (`Defs.lean:1071-1078`).
- The non-tapscript half is kept deliberately.  A slice that returns 50 for
  every sigversion would pass the tapscript half but would not prove the ban
  is tapscript-only; the cell therefore walks the front matter for BASE and
  WITNESS_V0 and returns the same status code as the layout cell (minus the
  opCount arm, which has no input here).
- The opcode word is accepted and ignored in both legs, matching Core's shared
  arm for 0xae/0xaf.

## Result detail

Alive2: `Transformation seems to be correct!`, one correct transformation,
0 errors.  SAW: two `Proof succeeded!` lines and `CASE_0_OK`; the case number
only selects a checker stub, and this cell never calls the checker.

## Limits

- opCount is not an input; the op_count arm is not reachable here (see
  `C-L-cms-layout-sym` for it).
- The post-ban verification loop is out of scope.
- No crypto call is reached, so docs/DECISION-lax-ecdsa.md is vacuous.
