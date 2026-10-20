# Wave 32 / 09-push-045-050 — push-encoding rows SCR-045..SCR-050

**Task:** `/tmp/opencode/wave32/tasks/09-push-045-050.md`
**Branch:** `wave32/09-push-045-050`
**Base / repo HEAD:** `805c8042f92d3bed909ca40219a4d21fc9150cc1` (additive to PR #29)
**Pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`

## Result

Six assigned rows are closed with five new both-tool-green cells. Every cell
has a real Alive2 run and a real SAW run, raw `alive2/result.txt` /
`saw/result.txt`, and a `certificate.sha256` that verifies with
`sha256sum -c` from the repository root. No row is partial and no row is
blocked; the bounded domain of each claim is stated in its `spec.md` and
repeated below.

| SCR | status | cell | proved | remains | blocker |
|---|---|---|---|---|---|
| SCR-045 | full (8-byte single-opcode domain) | `push-encoding/C-L-w32-push-parse` | PUSHDATA1/2/4 1/2/4-byte LE length parsing; prefix and payload truncation ⇒ parse failure mapped to `SCRIPT_ERR_BAD_OPCODE` (16); payload/next offsets agree; every opcode byte and every 32-bit declared length in an 8-byte script. | Scripts with more than one opcode: the Lean eager-`parseWire` vs Core streaming-`GetOp` error-precedence seam (F-DIV-001) cannot fire at offset 0 and is not claimed. | none for the stated single-opcode domain. |
| SCR-046 | full (single-opcode domain) | `push-encoding/C-L-w32-pushnum` | `OP_0` pushes the empty vector; `OP_1..OP_16` push the single byte `0x01..0x10`; all 17 opcodes symbolic; final EVAL_FALSE verdict included. | Unexecuted branches (SCR-049); PUSHDATA encodings (SCR-045). | none. |
| SCR-047 | full (single-opcode domain) | `push-encoding/C-L-w32-pushnum` | `OP_1NEGATE` (0x4f) pushes the single byte `0x81`; no MINIMALDATA gate on this path, proved for both policy values. | Nothing for the row's premise. | none. |
| SCR-048 | full (whole decision function) | `push-encoding/C-L-w32-checkminimalpush` | `CheckMinimalPush` for every length class (0, 1, 2..75, 76..255, 256..65535, >65535), every first-byte class it reads, and every call-site opcode `0x00..0x4e`. | The `fExec`/`fRequireMinimal` gate that decides whether it is called (SCR-049, separate cell) and `PUSH_SIZE` (SCR-020). | none. |
| SCR-049 | full for the row's premise (fixed 6-byte script) | `push-encoding/C-L-w32-fexec-push` | `fExec` derived by executing `OP_0`/`OP_1` + `OP_IF`: the unexecuted non-minimal push `0x01 0x01` is not an error under MINIMALDATA; the same push executed is `SCRIPT_ERR_MINIMALDATA` (25). | Other `fExec` constructions (`ELSE`, nested `IF`, `NOTIF`), multi-byte payloads, general loop. | none for the fixed-script premise. |
| SCR-050 | full (n = 0..4, both policy values) | `push-encoding/C-L-w32-cscriptnum-minimal` | Exact `CScriptNum` minimality rule: `(top & 0x7f) == 0` requires size 1 or `(prev & 0x80) != 0`; rejection is `SCRIPT_ERR_SCRIPTNUM` (4); accepted LE sign-magnitude value, including `0x80`, `0xff00`, `0xff80`; symbolic over all four bytes and both `fRequireMinimal` values. | Width guard `n > 4` (SCR-079/SCR-080) and numeric opcode call sites (SCR-081+) are separate. | none. |

## Cells

All cells are under `spec/equiv/cells/push-encoding/`. Each directory has
`spec.md`, `notes.md`, `src/{c_leaf.cpp,l_leaf.cpp,build.sh,cell.cry,cell.saw}`,
`alive2/run.sh`, `saw/run.sh`, build products, raw results, and certificates.
No Core source patch is used anywhere (`patches: none`).

Legs: C is a line-cited source-excerpt slice of the pinned Core; L is the Lean
definition transcribed verbatim from the generated twin `twin/runtime.inc`
(and `Defs.lean`). SAW checks each leg against an *independent* Cryptol
predicate in that cell's `src/cell.cry`; Alive2 checks C against L directly.
Directions are both `L ⊑ C` and `C ⊑ L` for every cell.

### `C-L-w32-push-parse` — SCR-045

- Source: `script.cpp:313-363` (`GetScriptOp`), `interpreter.cpp:487-488`
  (`GetOp` failure ⇒ `SCRIPT_ERR_BAD_OPCODE`), `Parser/Defs.lean:206-229`.
- Domain: single opcode at offset 0 of an 8-byte buffer, length `n = 0..8`,
  all eight bytes symbolic.
- Entry points: `cell_parse_meta` (result/error/wire/dlen/next) and
  `cell_parse_payload` (eight payload lanes).
- Alive2: 2 correct transformations (meta + payload), 0 incorrect, 0 errors.
- SAW: 4 proofs (both legs × both observables), 0 failed.

### `C-L-w32-pushnum` — SCR-046 + SCR-047

- Source: `interpreter.cpp:499-503`, `415-427`, `527-546`, `1876-1880`;
  `Defs.lean:836-846`; `Numeric/Interface.lean:55-56`.
- Domain: one executed opcode selected by `sel` (0 = `OP_0`, 1 =
  `OP_1NEGATE`, 2..17 = `OP_1..OP_16`), `MINIMALDATA` symbolic.
- Alive2: 1 correct transformation, 0 incorrect, 0 errors.
- SAW: 2 proofs, 0 failed.

### `C-L-w32-checkminimalpush` — SCR-048

- Source: `script.cpp:373-396` (`CheckMinimalPush`),
  `interpreter.cpp:499-503` (only call site), `Defs.lean:529-537`.
- Domain: `n` all 64 bits; `b0` all bytes; `opcode` symbolic with
  `opcode <= 0x4e`. The C slice is reduced to the function's read set
  (`data.size()`, `data[0]`).
- Alive2: 1 correct transformation, 0 incorrect, 0 errors.
- SAW: 2 proofs, 0 failed.

### `C-L-w32-cscriptnum-minimal` — SCR-050

- Source: `script.h:246-268` (constructor: width + minimality guards),
  `script.h:376-391` (`set_vch`), `Numeric/Interface.lean:45-47`.
- Domain: `n = 0..4`, four payload bytes symbolic, `minimal` symbolic. The
  length loop is unrolled over the exact 0..4 lengths; `n > 4` is the width
  guard and outside the SAW precondition.
- Alive2: 1 correct transformation, 0 incorrect, 0 errors.
- SAW: 2 proofs, 0 failed. (SAW emits `Unused name: b3` for the Cryptol
  argument; `b3` is still passed symbolically and read by the `n == 4` value.)

### `C-L-w32-fexec-push` — SCR-049

- Source: `interpreter.cpp:476-503` (loop order and `fExec` push gate),
  `613-661` (IF/NOTIF/ENDIF), `527-546` (OP_1), `script.cpp:373-396`,
  `1876-1880`; `Defs.lean:816-846`, `878-900`.
- Domain: fixed 6-byte script
  `[cond, OP_IF, 0x01 0x01, OP_ENDIF, OP_1]`, `cond ∈ {OP_0, OP_1}`,
  `minimalData` symbolic; executor unrolled exactly six times (five executed
  steps plus EOF), element domain ≤ 1 byte.
- Entry points: `cell_fexec_false`, `cell_fexec_true`.
- Alive2: 2 correct transformations, 0 incorrect, 0 errors.
- SAW: 4 proofs (both legs × both scripts), 0 failed.

## Exact commands

Run from the repository root (`/tmp/opencode/wave32/09-push-045-050`):

```sh
C=$PWD/spec/equiv/cells/push-encoding

./spec/equiv/cells/push-encoding/C-L-w32-push-parse/alive2/run.sh "$C/C-L-w32-push-parse"
./spec/equiv/cells/push-encoding/C-L-w32-push-parse/saw/run.sh    "$C/C-L-w32-push-parse"
./spec/equiv/cells/push-encoding/C-L-w32-pushnum/alive2/run.sh "$C/C-L-w32-pushnum"
./spec/equiv/cells/push-encoding/C-L-w32-pushnum/saw/run.sh    "$C/C-L-w32-pushnum"
./spec/equiv/cells/push-encoding/C-L-w32-checkminimalpush/alive2/run.sh "$C/C-L-w32-checkminimalpush"
./spec/equiv/cells/push-encoding/C-L-w32-checkminimalpush/saw/run.sh    "$C/C-L-w32-checkminimalpush"
./spec/equiv/cells/push-encoding/C-L-w32-cscriptnum-minimal/alive2/run.sh "$C/C-L-w32-cscriptnum-minimal"
./spec/equiv/cells/push-encoding/C-L-w32-cscriptnum-minimal/saw/run.sh    "$C/C-L-w32-cscriptnum-minimal"
./spec/equiv/cells/push-encoding/C-L-w32-fexec-push/alive2/run.sh "$C/C-L-w32-fexec-push"
./spec/equiv/cells/push-encoding/C-L-w32-fexec-push/saw/run.sh    "$C/C-L-w32-fexec-push"
```

Certificate verification, from the same repository root:

```sh
for c in C-L-w32-push-parse C-L-w32-pushnum C-L-w32-checkminimalpush \
         C-L-w32-cscriptnum-minimal C-L-w32-fexec-push; do
  ( cd . && sha256sum -c spec/equiv/cells/push-encoding/$c/alive2/certificate.sha256 )
  ( cd . && sha256sum -c spec/equiv/cells/push-encoding/$c/saw/certificate.sha256 )
done
```

All ten runs exited 0. All ten certificates printed `OK` for every entry; the
`grep -rn 'outside-root' */{alive2,saw}/certificate.sha256` check returned
nothing.

## Raw outcomes

| cell | Alive2 | SAW |
|---|---|---|
| push-parse | 2 correct, 0 incorrect, 0 Alive2 errors — `STATUS=alive2-green` | 4 × `Proof succeeded!`, 0 failed — `STATUS=saw-green` |
| pushnum | 1 correct, 0 incorrect, 0 Alive2 errors — `STATUS=alive2-green` | 2 × `Proof succeeded!`, 0 failed — `STATUS=saw-green` |
| checkminimalpush | 1 correct, 0 incorrect, 0 Alive2 errors — `STATUS=alive2-green` | 2 × `Proof succeeded!`, 0 failed — `STATUS=saw-green` |
| cscriptnum-minimal | 1 correct, 0 incorrect, 0 Alive2 errors — `STATUS=alive2-green` | 2 × `Proof succeeded!`, 0 failed — `STATUS=saw-green` |
| fexec-push | 2 correct, 0 incorrect, 0 Alive2 errors — `STATUS=alive2-green` | 4 × `Proof succeeded!`, 0 failed — `STATUS=saw-green` |

Toolchain recorded in the result headers:

```text
alive-tv: Ubuntu LLVM version 20.1.2   (/usr/local/bin/alive-tv)
clang:    Ubuntu clang version 20.1.2  (/usr/bin/clang++-20)
saw:      1.6 (68eed5f release-1.6)    (/opt/equiv-tools/saw-1.6/bin/saw)
```

## Errors found and fixed while getting the proofs

Recorded here rather than hidden; each was a real defect found by the tools or
by the independent Cryptol statement:

1. **push-parse, real C-slice bug:** the first Alive2 run found that a
   non-push opcode returned `next = 0` instead of `next = pc`; fixed.
2. **push-parse, real Cryptol-spec bug:** the PUSHDATA4 bound used 32-bit
   `5 + k`, which overflows; changed to `k <= n - 5`. Alive2 then exposed a
   compiler-generated switch table in L as an Alive2 globals/poison
   limitation; the width is now computed arithmetically
   (`1u << ((c == 0x4e) ? 2u : (c - 0x4c))`). That is an Alive2 globals
   limitation, not a semantic divergence.
3. **fexec-push, real L-slice bug:** the first attempt lacked `OP_1`
   handling and ran one step too many for the 6-byte script; fixed to handle
   `.pushNum` and to five `step` calls.
4. **cscriptnum-minimal, spec/tooling bugs:** the first Cryptol predicate
   omitted the `fRequireMinimal` switch (`md` is now threaded through);
   Cryptol does not accept `--` comments (used `//`); tuple `let`/`where`
   layout failed and was replaced with `(parse n bs).0` projections.

None of these fixes changed the pinned Core or the Lean proofs.

## Limits and integration notes

- `scr_row_coverage` in each `spec.md` states the exact bounded domain. In
  particular: SCR-045 is a single-opcode parse cell and explicitly excludes
  the F-DIV-001 eager-parse/streaming precedence seam on malformed tails
  after an earlier runtime error; SCR-049 is a fixed-script `fExec` cell, not
  a general EvalScript loop proof; SCR-050 is the decode primitive for
  `n <= 4`, not the numeric-op call sites; SCR-048 proves the decision
  function, not its gate or `PUSH_SIZE`.
- The new cells are **not** registered in `spec/db/equiv-cells.yaml` and the
  shared ledger/results were not touched, per the brief. The orchestrator
  integrates and regenerates once the waves merge.
- No files outside `spec/equiv/cells/push-encoding/C-L-w32-*` and this
  report were changed; nothing was pushed.
