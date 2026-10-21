# Wave 64 — task `55-tapscript-opsuccess-symbolic`

**Branch:** `wave64/55-tapscript-opsuccess-symbolic` (base `5946c02`)
**Pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Rows:** SCR-153, SCR-154 (both remain **partial**, with a wider exact bound)
**Tools:** Alive2 20.0 (`alive-tv`), SAW 1.6, clang/LLVM 20.1.2, Z3 4.8.12
**Verdict:** new both-green cell at **length <= 8** (was <= 4): Alive2 19.2 s
for both directions, SAW 150–178 s.  Alive2-only, **both directions, green
through length 16** — the largest width the 128-bit shift-register encoding
supports — including under the repo's standard 60 s SMT budget (48.6 s /
60.1 s wall).  Arbitrary script length is an honest **no-go for any loop-free
fixed unroll**; the exact reason and the next experiment are below.

## 1. What was attacked

The wave-32 cell `tapscript/C-L-w32-op-success-prescan` proves SCR-153/154 for
every script of length <= 4 by unrolling Core's `while (pc < pend)` loop with a
**symbolic index** `i` and a **symbolic advance** `nx` from `GetOp`.  A length-8
version of that shape was attempted in wave 32 and could not be discharged by
Alive2 inside 60 s (recorded in
`findings/wave32/27-tapscript-149-155/report.md`).

This task tried a different loop-free encoding at a wider length and asked for
the exact SMT bound or an honest no-go.

## 2. Encoding: byte-granular shift register (fixed unroll)

Both legs now consume exactly **one script byte per unrolled iteration**
(`MAX_SCAN_LEN = N` fixed iterations; no C loop):

- the script is one register (`uint64_t` for N <= 8, `unsigned __int128` for
  N <= 16); its low byte is the current byte; each iteration shifts right by 8
  (a **constant** shift);
- a push's header/payload is carried in a small `skip` counter
  (`skip = hdr + k`), decremented once per consumed byte; payload bytes are
  never tested for OP_SUCCESSx;
- a truncated push sets a three-valued `status = 2` (aborted) and later
  iterations are no-ops; an OP_SUCCESSx sets `status = 1`;
- `POS` is a `template` parameter, so there is **no symbolic index and no
  symbolic shift amount** anywhere in either function.

The jump loop is not assumed away.  The independent Cryptol specification in
`src/cell.cry` keeps the **jump form** (`getop_next` returns a variable `next`;
`step` folds over it).  SAW proves both IR legs against that jump-based spec on
the whole length-N domain, so the shift-register encoding is *machine-checked*
against Core's variable-`nx` advance, not merely asserted equivalent.

C keeps Core's subtraction-form bounds (`len - (i+1) < c`, ...); L keeps Lean's
unbounded Nat advance (`i + 1 + hdr + k > len`, encoded in `uint64`, exact
because the sum is < 2^33) and Lean's push-vs-op distinction (`0x4f`,
`0x51..0x60` are pushes; `0x50` is an op).  This preserves the independence of
the two legs.

## 3. Results

### 3.1 Committed cell (both-green)

`spec/equiv/cells/tapscript/C-L-w64-op-success-prescan`

- `cell_scan_finds_success(len, b0..b7)`: every script of length 0..8, all
  byte values.
- `cell_prescan_tail(found, discourage, too_many, oversize, later_rc)`: the
  unchanged ordering face (success beats STACK_SIZE, PUSH_SIZE and the
  EvalScript tail; `DISCOURAGE_OP_SUCCESS` = 36 under the policy flag).

Alive2: 4 correct transformations (2 functions x 2 directions: C -> L and
L -> C), 0 incorrect, 0 failed-to-prove (`alive2/result.txt`, ~110 KB of raw IR
+ summaries).  SAW: 4 `Proof succeeded!` (scan and tail, both legs) against
`src/cell.cry` (`saw/result.txt`).  Both `certificate.sha256` files verify with
`sha256sum -c`.

The both-direction check is not cosmetic.  It is what surfaced the extraction
artifact in section 4.4: in `l -> c` Alive2 reported a spurious
`Source is more defined than target` on a truncated PUSHDATA4 at the last
byte, which the single-direction run could never show.  After the fix both
directions are green.

### 3.2 Width sweep (Alive2)

All runs use `alive-tv --always-verify` on the `opt -O2` forms.  The "first
sweep" column is C -> L only; "both dirs" is C -> L and L -> C with the
constant initializer kept (`widths/rerun_bothdir.sh`, section 4.4).  Times are
wall clock on a shared, heavily loaded host (load average ~30 on 16 cores), so
treat them as upper bounds; the pass boundary is stable, the times are not.

| N (max script len) | first sweep, C -> L, 60 s | both dirs, 60 s (C->L / L->C) | both dirs, 300 s (C->L / L->C) | main SMT query (`value`) |
|---|---|---|---|---|
| 4 (existing cell, jump loop) | green, 8.96 s | — | — | not dumped |
| **8 (new cell, shift register)** | **green, 9.68 s** | **green, 19.2 s total** | — | 89,284 B, 1 assertion |
| 12 | green, 25.47 s | green, 24.23 / 23.03 s | — | not dumped |
| 13 | green, 26.26 s | green, 24.57 / 25.62 s | — | not dumped |
| 14 | green, 35.54 s | green, 30.04 / 106.01 s | — | not dumped |
| 15 | green, 47.98 s | green, 27.78 / 50.58 s | — | not dumped |
| **16** | timeout, 64.05 s | **green, 48.56 / 60.10 s** | **green, 39.85 / 42.49 s** | 189,901 B, 1 assertion |

**Exact Alive2 bound: N = 16, in both directions, under the repo's standard
60 s per-query SMT budget** (`--smt-to=60000`).  N = 16 is the largest width
this encoding supports (`unsigned __int128` register); going further needs a
different register representation, not a longer unroll of this one.  The
earlier "timeout, 64.05 s" at N = 16 was the stripped-table, higher-load run:
with the initializer kept the same width finishes inside the budget.  The
106 s wall at N = 14 shows how much host load moves these numbers; none of the
individual queries hit the 60 s cap.

Z3 4.8.12 alone solved the (stripped-module) N = 16 `value` query in 43.15 s
and the N = 8 `value` query in 2.50 s; the Alive2 total also discharges
`poison`, `retdom`, `ub`, `ub_src` and `pre`.  With the constant initializer
kept, the dumped queries are N = 8: `value` 89,284 B, `poison` 89,258 B,
`retdom` 84,928 B, `ub` 85,728 B, `ub_src` 52,118 B, `pre` 789 B; N = 16:
`value` 189,901 B, `poison` 189,875 B, `retdom` 184,449 B, `ub` 185,448 B,
`ub_src` 115,997 B, `pre` 789 B
(`widths/results/smt-n{8,16}-defined-query-sizes.txt`).

The encoding change buys the wider bound at **constant Alive2 cost**: N = 8
shift-register (9.68 s) is the same as N = 4 jump-loop (8.96 s), while the
N = 8 jump-loop form timed out at 60 s in wave 32.  IR size still grows roughly
linearly:

| N | C leg lines / blocks / bytes | L leg lines / blocks / bytes |
|---|---|---|
| 4 | 330 / 38 / 17,171 | 460 / 59 / 24,523 |
| 8 | 747 / 84 / 42,820 | 860 / 117 / 47,817 |
| 12 | 1,179 / 129 / 69,384 | 1,347 / 179 / 85,899 |
| 16 | 1,600 / 173 / 95,819 | 1,828 / 239 / 118,520 |

### 3.3 Width sweep (SAW)

SAW verifies the scan and the tail against the jump-based Cryptol spec, so its
cost is the N-step unfold of a symbolic-index fold (a mux tree), not the IR
branch structure.

| N | SAW result |
|---|---|
| 8 | **green**, 4 proofs; 150.7 s with `abc` in the first run, 152.4 s in the final cell run (177.8 s in an earlier loaded run); 100.4 s with `z3` |
| 12 | not discharged: `abc` killed after 15 min, `z3` killed after >15 min |
| 16 | not discharged: `z3` killed after 21m50s |

All three failures were still inside `Checking proof obligations` when killed;
the truncated raw logs end with a `STATUS=not-discharged` line recording the
cap (`widths/results/saw-n12-z3.txt`, `saw-n16-z3.txt`).  N = 13/14/15 were not
attempted: 12 already fails in both backends and the fold only grows with N.

SAW is the binding tool above length 8 in this environment.  This is a tool
limit, not a semantic one: the same `cell.cry` statement is what Alive2
independently confirms at N = 12/16 through the two IR legs.

## 4. Evidence quality checks

### 4.1 Inclusion of the old bound (machine-checked)

`compare/` proves, with SAW/ABC, that the length-4 contract is contained in the
length-8 contract:

```cryptol
same4 len b0 b1 b2 b3 =
  (len <= 4) ==> (c4_scan_finds_success len b0 b1 b2 b3 ==
                  scan_finds_success len b0 b1 b2 b3 0 0 0 0)
```

`compare3.saw` prints `CELL4_SUBSET_OF_CELL8` (prove_print is silent on
success in SAW 1.6); the negative control without the `len <= 4` restriction
fails with a counterexample (`len=6`, bytes `4d 00 00 03 f3 ...`), so the
prover is really discharging the goal.  `make_compare_cry.py` derives
`compare.cry` by reading the two *cell* specs and prefixing only the length-4
copy's top-level names; both originals and the generated file are hashed in
`certificate.sha256`.

### 4.2 Alive2 non-vacuity (mutation)

Imported from the wave-32 discipline: Alive2 20.0 can silently skip some IR
shapes.  A mutant of the L leg that drops the abort guard (a truncated push
continues scanning) is detected:

```
Transformation doesn't verify!
Summary: 0 correct transformations, 1 incorrect transformations
Example: len=6, b0=0x00, b1=0x06, ... (C=0, L=1)
```

Raw output: `widths/results/alive2-mutant.txt`.  The cell's Alive2 runs are
therefore not vacuous.  (The full mutation is described in the cell
`spec.md` `mutant:` field.)

### 4.3 Tooling bug found in the shared runner (recorded, not patched)

`spec/equiv/cells/_tools/w32-tap27/run_alive2.sh` parses each function with
`printf '%s' "$fnout" | grep -q ...` under `set -o pipefail`.  For the
length-8 IR the alive-tv output (71 KB for two functions) exceeds the pipe
buffer, `grep -q` exits early, `printf` takes SIGPIPE, and with `pipefail` the
pipeline is considered failed.  The runner then writes
`STATUS=alive2-not-green` although the same file contains `1 correct
transformations` for both functions.  The length-4 cell (smaller output) does
not trigger it.

This cell uses a cell-local `alive2/run.sh` that runs the identical alive-tv
command and parses a temp file instead of a pipe.  **No shared file was
edited.**  Suggested fix for the integrator: replace the `printf | grep -q`
checks with `grep -q -- pattern "$tmpfile"` (or `grep -q` on a here-string with
`pipefail` disabled for that pipeline).

### 4.4 Extraction artifact: `llvm-extract` drops Clang's `switch.table`

The both-direction Alive2 run (section 3.1) failed `l -> c` on

```
len=8, b0..b6=0x00, b7=0x4e            (PUSHDATA4 as the last byte)
%switch.load = poison
UB triggered on br
ERROR: Source is more defined than target
```

This is a toolchain artifact, not a C-leg difference.  Clang -O1 lowers the
three PUSHDATA tests to a dense `switch` and emits a private constant lookup
table.  `llvm-extract --func=FN --recursive`, as used by the shared build,
keeps the global's **declaration** and drops its **initializer**:

```
@switch.table.cell_scan_finds_success = external hidden unnamed_addr constant [3 x i64]
```

Alive2 models a load from an external constant as poison, so the C leg looks
undefined on every input that reaches the table.  The whole module
`c_leaf.bc` (which SAW loads) has the table defined, and re-extracting with
`llvm-extract --keep-const-init` makes both directions pass with no other
change.  The cell now builds through `alive2/build_defined.sh`: it compiles
its own leaves with the shared build's compile line, extracts with
`--keep-const-init`, names the results `.defined.*` so it never overwrites the
artifacts the SAW certificate hashes, and fails if any extracted module still
has an external declaration.  **No shared file was edited.**

The same artifact affects the one-direction width sweep: its C -> L runs used
the stripped module, so inputs that reach the table were vacuously refined
(poison source) rather than genuinely checked.  That can only weaken a green
result, never manufacture one, but the sweep was re-run in both directions
with the fix (section 3.2).

## 5. Honest no-go: arbitrary script length

A loop-free fixed unroll proves a bounded instance.  Nothing in this task
changes that: length 8 is a 2x improvement and the Alive2-only length-16
instance is a 4x improvement over wave 32, but neither is an induction.

The exact remaining gap for SCR-153/154 is therefore:

1. **Scripts longer than the bound.**  For arbitrary length, prove
   `opSuccessScan exec` (the Lean fold, `Defs.lean:479-492`, fuel `b.size+1`)
   by induction on the fuel/index, or prove the C `while` loop with a SAW loop
   invariant.  SAW 1.6's LLVM verifier unrolls loops; the loop-invariant
   command it ships (`llvm_verify_x86_with_invariant`) is x86 machine code
   only, so the realistic route is a Lean theorem (the twin already has
   `opSuccessScanFrom`; the needed lemma is a fold invariant over `getOp`'s
   advance).  The shift-register step proved here is a natural invariant
   statement: one byte consumed, `skip`/`status` updated, at most one success.
2. **Malformed-tail error kind.**  Unchanged from wave 32: Core returns
   BAD_OPCODE on a truncated push before the size checks; the Lean model
   returns false and reaches STACK_SIZE/PUSH_SIZE (`F-DIV-w32-001`).  This cell
   compares only the `found` bit, so the divergence is excluded, not hidden.
3. `later_rc` (EvalScript + cleanstack/CastToBool) remains uninterpreted.

The bound is exact as reported: **both tools green at N = 8; Alive2 green in
both directions at N = 16 under the standard 60 s SMT budget (48.6 s / 60.1 s
wall; 39.9 s / 42.5 s at 300 s), and N = 16 is the largest width this encoding
supports; SAW not discharged at N = 12/16.  A loop-free unroll of width N says
nothing about scripts of length N+1.**

## 6. Scope / no-overclaim notes

- No hash, curve, Schnorr, tx, annex or control-block code is used.  The
  cell is the pre-scan and the three branches it precedes, with the EvalScript
  tail as an uninterpreted packed input.
- The L leg is a transliteration of the Lean definitions cited in the cell
  `spec.md`; the C leg is a line-cited source slice at the pin.  The
  shift-register encoding is harness/encoding for both legs and is itself
  proved against an independent jump-based Cryptol fold.
- The policy flag is an input; the cell does not claim it is a consensus
  `ScriptFlags` bit (SCR-154 is `consensus: false`).
- **No shared edit:** no existing cell, finding, ledger, contract, pin, proof,
  `spec/db/equiv-cells.yaml` row or tool file was modified.  The SCR-153/154
  ledger rows are left for the integrator; they still point at the wave-32 cell.

## 7. Files

New (all under this worktree):

```
spec/equiv/cells/tapscript/C-L-w64-op-success-prescan/
  spec.md  notes.md
  src/{c_leaf.cpp,l_leaf.cpp,cell.cry,cell.saw}
  alive2/{run.sh,build_defined.sh,result.txt,certificate.sha256}
  saw/{run.sh,result.txt,certificate.sha256}
spec/equiv/findings/wave64/55-tapscript-opsuccess-symbolic/
  report.md  certify.sh
  widths/{README.md,gen.py,rerun_bothdir.sh,n12/,n16/,results/}
  compare/{make_compare_cry.py,compare.cry,compare*.saw,*-result.txt}
  certificate.sha256
```

Generated `build/` directories are git-ignored; the cell certificates hash the
extracted `.ll`/`.opt.ll`/`.bc` artifacts they reference, so the runs are
reproducible from the tracked inputs.

## 8. Exact commands

```sh
# committed cell
spec/equiv/cells/tapscript/C-L-w64-op-success-prescan/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w64-op-success-prescan/saw/run.sh
cd <repo root> && sha256sum -c spec/equiv/cells/tapscript/C-L-w64-op-success-prescan/alive2/certificate.sha256
cd <repo root> && sha256sum -c spec/equiv/cells/tapscript/C-L-w64-op-success-prescan/saw/certificate.sha256

# width sweep (regenerate any N <= 16)
python3 spec/equiv/findings/wave64/55-tapscript-opsuccess-symbolic/widths/gen.py 16 /tmp/exp/n16
spec/equiv/cells/_tools/w32-tap27/build.sh /tmp/exp/n16 cell_scan_finds_success
cd /tmp/exp/n16 && /usr/local/bin/alive-tv --always-verify --smt-to=300000 \
  build/c_cell_scan_finds_success.opt.ll build/l_cell_scan_finds_success.opt.ll

# inclusion + negative control
cd spec/equiv/findings/wave64/55-tapscript-opsuccess-symbolic/compare
PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw compare3.saw
PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw compare-negative.saw   # expected rc=2
```
