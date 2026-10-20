# Alive2 v20 × rustc 1.95 (LLVM 22.1.2) ingestion probe

Reproduce F-TOOL-001. All commands run 2026-10-19 on the pinned host.

## Inputs

- `probe.rs`: minimal crate whose `probe_sum` collects `0..n` into a `Vec`.
- `probe.ll` / `probe.bc`: emitted by
  `rustc +1.95.0 --crate-type=lib --emit=llvm-bc,llvm-ir -C opt-level=2 -C panic=abort`.
- `real-rbitcoin-195-ll.out`: Alive2 v20 on the real rbitcoin 1.95 module
  (`target-195-ir/release/deps/rbitcoin_consensus-68e7c81c2384e3ba.ll`).
- `alive.out`: Alive2 v20 on `probe.bc`.

## Results

| Input | Parser result |
|---|---|
| real rbitcoin 1.95 `.ll` | **reject**: `expected ')' at end of argument list` at `dead_on_return`; `Could not read bitcode` |
| `probe.ll` (text) | `llvm-as` 20 accepts this particular function (no `dead_on_return`) |
| `probe.bc` (bitcode) | parsed, but Alive2: `ERROR: Unsupported metadata: 8`; `Could not translate 'probe_sum'`; exit 1 |

`dead_on_return` is an LLVM 22 parameter attribute; metadata kind 8 is not in
Alive2's LLVM 20. `add_one` in `../../verifications/artifacts/rust-hello/`
passes because it contains neither, so that leaf result does not generalize to
the rbitcoin engine.

Hashes: `hashes.txt`.
