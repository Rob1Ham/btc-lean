# Rust toolchain × tool matrix (E0, R leg)

Purpose: decide which pinned rustc can produce R-leg IR that **both** Alive2
and SAW ingest. This is a tool-capability experiment on a trivial leaf
(`add_one(x: i32) = x wrapping_add 1`), not an engine cell.

## Result

| rustc | LLVM | Alive2 v20.0 | SAW 1.6 | note |
|---|---|---:|---:|---|
| 1.88.0 | 20.1.5 | PASS | PASS | works, but not rbitcoin's pin |
| **1.95.0** | **22.1.2** | **PASS** | **PASS** | **rbitcoin's `rust-toolchain.toml` pin — chosen** |
| 1.99.0 | 23.1.1 | PASS | FAIL | host default; SAW rejects the LLVM 23 bitstream |

Raw rustc bitcode from 1.88/1.95 loads directly in both tools **for this
leaf**. No down-conversion is needed here.

**This result does not generalize to the rbitcoin engine.** The leaf has
neither LLVM-22-only parameter attributes nor newer metadata. The real
rbitcoin 1.95 module carries `dead_on_return`, which Alive2's LLVM 20 parser
rejects, and a minimal -O2 probe fails on `Unsupported metadata: 8`; see
`../../../tools/F-TOOL-001-alive2-llvm22.md` and
`../../../tools/probes/alive2-rust195/`. The R pin for the engine and SAW is
rustc 1.95.0, matching `reardencode/rbitcoin`'s `rust-toolchain.toml`.
R/Alive2 cells at the pin are therefore recorded inapplicable (tool-gap); a
rustc 1.88 / LLVM 20 run is advisory only and is not an R green cell.

`rustc 1.99.0` must not be used: SAW exits 2 in the bitstream parser
(`MODULE_BLOCK`, value symbol table). Alive2 alone is not sufficient, because
the workstream requires both tools on every structurally possible cell.

## Correction log

An earlier attempt loaded a textual `.ll` via `llvm_load_module` and reported
"Invalid magic number". That was an operator error: SAW consumes **bitcode**,
not text. The raw `.bc` path was then tested and passes. The 1.99 failure is a
different, real failure (bitstream generation 23).

## Reproduction

```sh
export PATH=/tmp/opencode/equiv-work/saw/bin:$PATH   # SAW's bundled solvers
./build.sh
cat matrix.txt hashes.txt
```

`build.sh` emits `.bc` and `.ll` for each toolchain, extracts `add_one`,
writes one SAW spec per toolchain, and runs both tools. Outputs:
`alive2_<tc>.out`, `saw_<tc>.out`, `matrix.txt`, `hashes.txt`.

Recorded hashes (sha256) are in `hashes.txt`; the `.bc` files themselves are
gitignored and regenerable by `build.sh`.

## Scope

This establishes tool ingestion and a proof of a pure leaf. It says nothing
about rbitcoin's engine, its panics/allocations, its thread pool, or its error
codes; those are RUST-IR's cells.
