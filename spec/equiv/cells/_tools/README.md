# Cell tooling (E1)

This directory contains the deterministic scaffold/generator and the shared
bounded-leaf harness used by the E1 gate cells.  It is **not** engine code and
is not part of the trust base for a semantics claim.

## `new_cell.py`

Creates a cell skeleton under `cells/<id>/`:

```sh
python3 cells/_tools/new_cell.py \
  --id e1-stack/example \
  --fn cell_example \
  --spk 51527c5187 \
  --expected 0x0000000000a04a01 \
  --script "OP_1 OP_2 OP_SWAP OP_1 OP_EQUAL" \
  --mutant "OP_SWAP becomes a no-op"
```

It writes `spec.md`, `notes.md`, `alive2/run.sh`, `saw/run.sh`, and
`behavior/run.sh`.  It refuses an existing scaffold unless `--force`, refuses
`_redteam` and `_tools`, and does not run a tool.  Output is deterministic: no
timestamps or host-specific values beyond the file contents; the contract hash
and repository `HEAD` are embedded.

## `mk_leaf.py`

Emits a bounded instance of the twin's imperative op handlers.  The handler
bodies are copied **verbatim** from `twin/ops_ir.py` (the same string table
`twin/gen.py` emits).  The generator only:

- re-binds `MAX_STACK_SIZE` and `MAX_SCRIPT_ELEMENT_SIZE` to the cell's
  bounded domain;
- substitutes the exact-for-`len <= 2` `std::memcpy` / `std::memcmp` calls
  with loop-free `bounded_memcpy` / `bounded_memcmp` helpers;
- adds the bounded `st_push`/`st_push_copy`/`st_push_num`/`decode_num`
  helpers needed by handler bodies.

No handler semantics are changed.  The generated header records the SHA-256 of
`twin/ops_ir.py`, `twin/gen.py`, and `contract/error_kind.h`.

```sh
python3 cells/_tools/mk_leaf.py \
  --ops OP_SWAP,OP_DUP --max-depth 6 --max-elem 1 \
  --out build/twin_ops.h --meta build/twin_ops.meta.json
python3 cells/_tools/mk_leaf.py --ops ... --check build/twin_ops.h
```

## Shared gate harness (`gate/`)

- `gate_common.h` — bounded `BStack`, truth, and the packed-observable format:
  result (2 bits), error ordinal (6), depth (3), then the **top three**
  elements as `(len:2, val:8)` each.  The packing is cell harness, not engine
  semantics.  `pick-depth` has final depth 4, so its bottom element is not
  packed; the depth field still distinguishes it.
- `c_leaf.cpp` — C leg: line-cited slices of Bitcoin Core
  `src/script/interpreter.cpp` at the pin for the six gate scripts, plus the
  closed `C-L-*` edge functions (VERIFY/DROP underflow and composition).
- `l_leaf.cpp` — L leg: calls the generated twin handlers verbatim, with a
  bounded dispatcher and stack initialization.  The dispatcher/pack/finish are
  harness, not twin engine code.
- `build_leaf.sh` — regenerates `twin_ops.h` from `twin/ops_ir.py`, compiles
  both legs with clang-20 at `-O1 -fno-strict-aliasing`, and extracts the
  requested `cell_*` function with `llvm-extract --recursive`.
- `run_alive2.sh` — runs `alive-tv` on the extracted C/L IR, writes raw
  `alive2/result.txt`, and writes a `certificate.sha256` over the runner,
  sources, generated handler header, extracted IR, and output.
- `run_saw.sh` — verifies both extracted modules against the cell's declared
  packed observable with SAW 1.6, writes `saw/result.txt` and a certificate.
- `run_alive2_multi.sh` / `run_saw_multi.sh` / `run_behavior_multi.sh` —
  multi-function variants for the broader `cells/stack/C-L-*` cells.  They
  read a per-cell `manifest.txt` (`<fn> <packed-constant>` or
  `<spk> <rc,err> <label>`), build each extracted pair, run all proofs, and
  require every function to be green.
- `run_behavior.sh` / `witness.py` — calls the **real** C and L
  `equiv_entry` libraries on the exact tape.  This is a behavioral witness,
  never proof evidence.
- `whole_entry_alive2_probe.txt` — the recorded tool gap for the whole
  `equiv_entry` module (unsupported attributes/loops), so no cell claims a
  whole-entry green.

### Exact run commands

Each cell has thin wrappers:

```sh
cells/e1-stack/swap-order/alive2/run.sh
cells/e1-stack/swap-order/saw/run.sh
cells/e1-stack/swap-order/behavior/run.sh

# broader closed-witness cells
cells/stack/C-L-verify/alive2/run.sh
cells/stack/C-L-dup-drop-swap/saw/run.sh
cells/stack/C-L-altstack/behavior/run.sh
```

The raw outputs and certificates are regenerated deterministically from the
pinned sources.  The L handler header is regenerated on every run, so a
mutation to `twin/ops_ir.py` is observed.  A mutation to only
`twin/build/twin.cpp` is **not** observed by these cells; use the `ops_ir.py`
site for REDTEAM mutation runs.

### Toolchain

- clang/clang++ 20.1.2 (`/usr/bin/clang++-20`)
- LLVM 20.1.2 (`llvm-extract`, `llvm-dis`, `llvm-as`)
- Alive2 (LLVM 20 build, `/usr/local/bin/alive-tv`)
- SAW 1.6 (`/opt/equiv-tools/saw-1.6/bin/saw`, solver `abc`)
- Python 3 for the deterministic generators/scaffolder and witness driver

### Scope limits

- The leaf proves handler/script-sequence semantics for the exact closed
  witness on a bounded stack (depth 6, element 1 byte).  It does **not** prove
  whole `VerifyScript`, tx decoding, witness handling, or full flag matrices.
- The SAW postcondition is the closed witness's packed constant, not a
  symbolic op law.
- The broader `cells/stack/C-L-*` cells are **closed edge witnesses**, not
  symbolic depth/value-domain proofs.  The remaining gap is a symbolic
  initial-stack ABI plus a shared Cryptol stack model.
- `-O0` fully-inlined leaf IR was attempted and did not finish in the Alive2
  harness timeout; recorded artifacts use `-O1 -fno-strict-aliasing`.
- F-DIV-001 (truncated-push tails) is not exercised: all gate scripts are
  fully parseable.
- F-ERR-TWIN-001 (non-OK error-kind mapping) is not exercised: only success
  paths are observed.
