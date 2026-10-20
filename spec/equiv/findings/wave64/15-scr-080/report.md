# Wave 64 — task 15-scr-080

Row: **SCR-080** (`all numeric opcodes`, check `Default 4-byte operand limit`,
`script.h:244,247@cce32b168`).  Previously a gap in
`spec/db/equiv-cells.yaml`.

Pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
Contract: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
Branch: `wave64/15-scr-080`, cut from `5946c02`. Not pushed, no shared edits.

## Result

**Row disposition: full at the decode boundary, both arms, both tools, with a
precise bound.**  One new cell,
`spec/equiv/cells/numeric/C-L-numeric-default-4byte`, proves the default-4
`CScriptNum` cap at **every** site in `EvalScript` that omits the size
argument: the normal arm (length <= 4 accepted with the decoded value the site
consumes) and the size-limit/error arm (length > 4 -> `SCRIPT_ERR_SCRIPTNUM`),
symbolically over the whole operand domain.

| Row | status | cell | proved | remains |
|---|---|---|---|---|
| SCR-080 | full (decode boundary) | `numeric/C-L-numeric-default-4byte` | 7 decode sites / 10 decode expressions / 24 opcodes: PICK, ROLL, 1ADD..0NOTEQUAL (6), ADD..MAX (13), WITHIN, CHECKSIGADD, CHECKMULTISIG keys, CHECKMULTISIG sigs. Alive2 `--bidirectional` 7/7; SAW 14/14. | the *post-decode* op bodies are deliberately not re-proved here (see Bounds); they are already green in the sibling cells named below |

The row is not left as "partial": the cell's obligation is exactly the
`check` text ("Default 4-byte operand limit"), which is a statement about the
decode, not about the arithmetic.  The normal-arm op results were already
proved over the same length domain 0..7 by:

- `numeric/C-L-unary-4byte` — SCR-087, unary normal arm + reject edge
- `numeric/C-L-binary-4byte` — SCR-088/090, binary normal arm + reject edge
- `numeric/C-L-within-4byte` — SCR-089, WITHIN normal arm + reject edge

PICK/ROLL's stack shuffle, CHECKMULTISIG's count/range/signature logic and
CHECKSIGADD's checker call are owned by SCR-078, SCR-086, SCR-114..117 and the
tapscript rows; this cell does not claim them.

## Call-site enumeration

`call-sites.tsv` is generated from the pinned `interpreter.cpp` by
`enumerate_sites.py` (EvalScript scope, nearest case-label group as a reading
aid).  It finds 25 `CScriptNum` mentions: 4 int/static constructions, 2
explicit-5 decodes (SCR-081), **10 default-4 decode expressions** (7 sites) and
9 reading-aid/int-constructor lines.  The 10 decode expressions are the row's
object and map to the seven entry points:

| site | core line | expression | entry point | opcodes |
|---|---:|---|---|---|
| 1 | 840 | `CScriptNum(stacktop(-1), fRequireMinimal).getint()` | `cell_pick_roll` | PICK, ROLL |
| 2 | 939 | `CScriptNum bn(stacktop(-1), fRequireMinimal)` | `cell_unary` | 1ADD, 1SUB, NEGATE, ABS, NOT, 0NOTEQUAL |
| 3 | 972 | `CScriptNum bn1(stacktop(-2), fRequireMinimal)` | `cell_binary` | ADD, SUB, BOOLAND, BOOLOR, NUMEQUAL, NUMEQUALVERIFY, NUMNOTEQUAL, LESSTHAN, GREATERTHAN, LESSTHANOREQUAL, GREATERTHANOREQUAL, MIN, MAX |
| 3 | 973 | `CScriptNum bn2(stacktop(-1), fRequireMinimal)` | `cell_binary` | (same 13) |
| 4 | 1017 | `CScriptNum bn1(stacktop(-3), fRequireMinimal)` | `cell_within` | WITHIN |
| 4 | 1018 | `CScriptNum bn2(stacktop(-2), fRequireMinimal)` | `cell_within` | WITHIN |
| 4 | 1019 | `CScriptNum bn3(stacktop(-1), fRequireMinimal)` | `cell_within` | WITHIN |
| 5 | 1103 | `CScriptNum num(stacktop(-2), fRequireMinimal)` | `cell_checksigadd` | CHECKSIGADD (tapscript) |
| 6 | 1126 | `CScriptNum(stacktop(-i), fRequireMinimal).getint()` | `cell_cms_nkeys` | CHECKMULTISIG, CHECKMULTISIGVERIFY |
| 7 | 1140 | `CScriptNum(stacktop(-i), fRequireMinimal).getint()` | `cell_cms_nsigs` | CHECKMULTISIG, CHECKMULTISIGVERIFY |

Excluded, with reason: `interpreter.cpp:556,584` pass `5` explicitly
(CLTV/CSV, SCR-081); `:419,420,518,790,888,974` construct from an integer or a
size, so no operand is decoded and no cap applies.

The enumeration is a reading of the pinned file; the cell proves each listed
site, not that the list is exhaustive.  That is the first bound below.

## Evidence

Cell: `spec/equiv/cells/numeric/C-L-numeric-default-4byte/`

```text
alive2/result.txt        d4403a5220418423df656b54b848832c11c43b48368c6609018c3a130c289022
saw/result.txt           660b4b94f0fbf06053b65b09fecafda612063a4a55f354426f75163f02d7c007
alive2/certificate.sha256 06b325641713eccd32ae32a91bc68fc9a1869ff63bec9d1a8ee885782da8d477
saw/certificate.sha256     d940b7be341aa3d0354aeaa5a84c60fbea324f098cd0de7afff2ab5206b7d5d9
```

- Alive2 v20.0, `--bidirectional`, `--smt-to=120000`: 7/7 entry points print
  `These functions seem to be equivalent!` and `1 correct transformations`,
  with 0 incorrect, 0 failed-to-prove, 0 Alive2 errors.  `--bidirectional`
  means both L ⊑ C and C ⊑ L are in the result.
- SAW 1.6, solver z3: 14 `Proof succeeded!` (7 entry points x C and L legs),
  0 `Proof failed`; the script also prints
  `CELL_W64_NUMERIC_DEFAULT_4BYTE_SAW_GREEN`.
- Certificates are repo-root relative and hash every tracked input: `spec.md`,
  `notes.md`, both runners, `src/**`, `findings/wave64/15-scr-080/tools/**`,
  `contract/error_kind.h`, `twin/{ops_ir.py,gen.py,runtime.inc}`,
  `cells/_tools/mk_leaf.py`, the wave-16 `mk_num_leaf.py`, and the raw
  `result.txt`.  `sha256sum -c` from the repository root passes both (21 files
  each).  Generated `build/` is gitignored and its IR hashes are in the
  `result.txt` header and `build/build.txt`.

## Exact commands

```sh
cd /tmp/opencode/wave64/15-scr-080

# enumeration (against a Core checkout at the pin)
python3 spec/equiv/findings/wave64/15-scr-080/enumerate_sites.py \
        /tmp/opencode/core-pin/src/script/interpreter.cpp \
        > spec/equiv/findings/wave64/15-scr-080/call-sites.tsv

# cell (each runner rebuilds both legs first)
bash spec/equiv/cells/numeric/C-L-numeric-default-4byte/alive2/run.sh
bash spec/equiv/cells/numeric/C-L-numeric-default-4byte/saw/run.sh

# certificates, from the repository root
sha256sum -c spec/equiv/cells/numeric/C-L-numeric-default-4byte/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/numeric/C-L-numeric-default-4byte/saw/certificate.sha256

# mutation test (scratch copy, tracked cell untouched)
bash spec/equiv/findings/wave64/15-scr-080/mutation/run_mutation.sh
```

## Mutation test

`M-W64-080-a`: in a scratch copy of the cell, the L leg's site-1 cap is
changed from 4 to 5 (the twin decoder now accepts a 5-byte `OP_PICK/OP_ROLL`
depth while Core rejects it).  Both tools kill it:

- Alive2: `Transformation doesn't verify! / ERROR: Value mismatch`,
  `1 incorrect transformations`, only `cell_pick_roll` fails; the other six
  entry points stay green (the mutation is local to site 1).
- SAW: `Proof succeeded! cell_pick_roll` (C leg) then `Proof failed` (L leg).

Record: `mutation/runs/M-W64-080-a.diff`, `M-W64-080-a-verdict.txt`.

## Bounds (what this does not prove)

1. **Site list is source-read, not machine-exhaustive.** The cell proves the
   seven listed sites; it does not prove that no other default-4 decode exists
   in the pinned tree.  `enumerate_sites.py` + `call-sites.tsv` make the list
   auditable (10 default-4 expressions, no others in `EvalScript`).
2. **Decode boundary only.** The slice stops after `CScriptNum(...)`; the
   arithmetic/stack/count/signature work after the decode is not executed.
   Normal-arm op results are green in `C-L-unary-4byte`, `C-L-binary-4byte`,
   `C-L-within-4byte`; the stack/count/signature behaviour is other rows.
3. **CMS second decode is position-fixed.** Site 7 fixes `nKeysCount` to
   `{0x00}` so `stacktop(-(2+nKeysCount))` is reachable inside the bounded
   stack; site 6 covers the `nKeysCount` operand itself.  The `nSigsCount`
   decode is symbolic over all 4-byte operands and the reject edge, but its
   stack *position* is one point of the harness, not all key counts.
4. **Bounded leaf.** Stack depth 8, element 8 bytes.  No operand longer than
   the symbolic length 0..7 is in the domain; Core's 520-byte element limit and
   the 1000-op/stack-size limits are not exercised (other rows).
5. **Tool premises.** Alive2 v20 / SAW 1.6 semantics, z3, clang 20.1.2 and the
   two normalisations in `src/build.sh` (post-extract `default<O2>`;
   `strip_range.py` removing a derived return-range attribute).  The M/W
   translation is conditional on those, as the E6 ledger states.
6. **No whole-engine claim.** This is a bounded decode cell; it is not
   `Lean == Core` and not a node-validation result.

## What was not done

- No edits to `spec/db/*` (ledger), `PINS.lock`, `contract/**`, `results/**`,
  `docs/STATE.md`, `README.md`, Lean proofs/census, existing cells or findings,
  or another wave's worktree; the new files are additive only.
- `make equiv`, the ledger updater and any push were not run (the orchestrator
  integrates and regenerates).  No R leg is claimed (SCR-080 is C/L).
- No behavioural run is used as proof evidence; every green above has raw
  Alive2/SAW output and a verified certificate.
