> **HISTORICAL ROLE REPORT — not the current state.** The live E6 checkpoint is
> `spec/equiv/results/STATUS.md` and `spec/equiv/docs/STATE.md`; the generated
> coverage view is `spec/equiv/results/matrix.md`. This file is retained for
> provenance and may describe an earlier zero-green/TODO-pin state.

# TOOLS report — E0 (2026-10-19)

Role: TOOLS. Scope written: `spec/equiv/tools/`,
`spec/equiv/findings/tools/`, and `[tools]` values in `PINS.lock`.
No git commit was made.

## Installed and verified

| Tool | Version actually observed | How |
|---|---|---|
| z3 | `Z3 version 4.8.12 - 64 bit` | Ubuntu `z3` + `libz3-dev` |
| clang | `Ubuntu clang version 20.1.2` | Ubuntu `clang-20` (LLVM 18.1.3 also present) |
| LLVM | `20.1.2`, RTTI `YES` | `llvm-20-dev`, `/usr/lib/llvm-20` |
| Alive2 | tag `v20.0`, commit `c0f5434f402ad91714ee0952f686cd0f524920ad` | built Release with Ninja against LLVM 20.1.2 + Z3 4.8.12 |
| SAW | `1.6 (68eed5f release-1.6)` | official `saw-1.6-ubuntu-24.04-X64-with-solvers.tar.gz` |
| cvc5 | `1.3.1 [git ea1b484fa]` | shipped in the SAW bundle |
| re2c / ninja | `3.1` / `1.11.1` | Ubuntu packages (build deps) |

Stable paths: `/opt/equiv-tools/alive-tv-v20.0`,
`/opt/equiv-tools/saw-1.6`, with `/usr/local/bin/{alive-tv,saw,cvc5}`
symlinks. Raw version transcript: `findings/tools/versions.txt`. Exact
commands, hashes and the failed-build tail are in `tools/install.md`.

`PINS.lock [tools]` now records Alive2, SAW, z3, cvc5 (python/cmake were
already set). `kani`/`miri` were **not installed or verified by TOOLS**; the
current lock (edited concurrently by another role) records them as
"not installed (optional)". `[llvm]` was filled concurrently by CORE-IR with
**clang 20.1.2 / LLVM 20.1.2**, matching what TOOLS verified.

## What actually ran

E0 smoke, all green:

- `alive-tv tools/tests/hello-a.ll tools/tests/hello-b.ll`
  → `2 correct transformations`, `0 incorrect`, `0 Alive2 errors`
  (`findings/tools/alive2-hello.out`).
- `alive-tv tools/tests/hello-a.ll tools/tests/hello-bad.ll`
  → `Transformation doesn't verify!`, concrete `%x = 3` counterexample,
  source 4 / target 5 (`findings/tools/alive2-hello-bad.out`).
  **The process exit code was 0** — gates must parse the report.
- `saw tools/tests/hello.saw` with the bundle `bin/` on PATH
  → `Proof succeeded! id32`, `Proof succeeded! add_one`,
  `SAW_E0_HELLO_OK` (`findings/tools/saw-hello.out`).
- `saw --summary=… --summary-format=json` → per-method/per-VC `verified`
  records (`findings/tools/saw-summary.json`).
- SAW negative/UB probe: clang `-O0` emits `add nsw`; SAW found
  `x = 2147483647`, "Signed addition caused wrapping even though the `nsw`
  flag was set" (`findings/tools/saw-hello-nsw-poison.out`).

Capability probes (`tools/tests/probes/`, logs in
`findings/tools/probes/`):

- Alive2 **rejects** `invoke`/`landingpad` (`Unsupported instruction: invoke`).
- Alive2 **models** unknown externals (counterexample for `ext(x)+1` vs
  `ext(x)+2`) and **checks final memory** (store vs no-store → `Mismatch in
  memory`).
- Alive2 proved `ptrtoint p` = `add (ptrtoint p), 0`, but **failed**
  `inttoptr(ptrtoint p) = p` with a provenance/proxy-pointer mismatch.
- Alive2 indirect calls translate but the semantic probe fails (`Source and
  target don't have the same return domain`); self-compare was only
  "syntactically equal".
- SAW simulated exception edges but needs overrides for
  `__cxa_allocate_exception`; requires overrides for externals and
  allocation/override for global function pointers; an unbounded loop without
  an invariant timed out at 180 s.

Full table: `tools/capability-matrix.md`.

## Blockers and limitations

1. **Alive2 master does not build against LLVM 18 or 20.** Its `llvm2alive`
   uses newer `llvm::Attribute` APIs. Pinned `v20.0` is the LLVM-20-compatible
   release; do not float to master unless LLVM is upgraded to match.
2. **SAW needs its bundle `bin/` on PATH** for `abc`; otherwise `llvm_verify …
   abc` fails at `posix_spawnp`. All runner scripts prepend it.
3. **Alive2's exit status is not a verdict.** A failed refinement exits 0.
4. **SAW needs overrides/invariants**, not magic: externals (the crypto seam),
   C++ runtime exception calls, global function pointers, and unbounded loops
   all stopped at simulation/override boundaries in the probes. These are
   cell-engineering tasks, not parser failures.
5. **`inttoptr`/provenance** is a real Alive2 limitation in practice. Cells
   that need pointer↔integer round-trips must be sliced or filed.
6. SAW's maximum LLVM bitcode version was only verified for LLVM 20.1.2.
   `PINS.lock` records a separate RUST-IR experiment with LLVM 22.1.2; this
   role did not re-run it.
7. `kani`/`miri` are not installed. Miri additionally needs a pinned nightly;
   the repo's rustc is a stable 1.95 pin. See `tools/install.md §5`.

## Gate script status (executed)

- `python3 tools/run_e0.py` → `RESULT: PASS` (TOOLS probes GREEN). The three
  shim sources (`shims/{core,twin,rust}/entry.*`) are now present but
  `run_e0.py` deliberately does **not** execute them.
- `python3 tools/run_equiv.py` → `SKIP: no cells under cells/<family>/<cell>/`.
- `python3 tools/check_pins.py --allow-todo` → tool probes OK; 2 TODO pins at
  the final run (core.build, rbitcoin.build; other roles filled the rest).
- `python3 tools/gate_ir_pin.py --allow-todo` → FAIL as expected:
  183/183 SCR rows still `planned`, 0 cell records, 0 adjudicated rows.

## Exact next action for E0

1. CORE-IR/TWIN-IR/RUST-IR build and run the three `shims/*/entry.*` against
   the pinned clang 20.1.2 (same flags) and add
   `tools/tests/e0-triple.sh`, which must print `E0_TRIPLE_OK` only after the
   three-entry differential run passes. `run_e0.py` will not claim a triple
   from source files alone.
2. Finish the two remaining build pins (`core.build`, `rbitcoin.build`).
   `[llvm]` is now filled (clang **20.1.2**, LLVM IR **20.1.2**, triple
   **x86_64-pc-linux-gnu**, `-O0` primary / `-O1` robustness), matching the
   TOOLS verification.
3. Then run `python3 tools/run_e0.py --strict-e0`; it exits 0 only when
   `tools/tests/e0-triple.sh` has run green (and the tool probes are green).
   Until then it prints `TOOLS READY; E0 TRIPLE PENDING` and exits 1 in strict
   mode. The full
   `make gate-ir-pin` remains an E6 gate: it should stay red until CELLS
   records exist and SCR rows are adjudicated.
