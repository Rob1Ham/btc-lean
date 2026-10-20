# R-leg tool probes (SAW 1.6 / Alive2 v20.0)

Date: 2026-10-19. Role: RUST-IR. These are **real local runs**, not
release-note inferences. They are tool-capability probes, not equivalence
certificates: the Alive2 runs compare a module with itself, and the SAW leaf
has no postcondition. Nothing here may be promoted to a green cell without a
cell record.

## Environment

| Item | Value |
|---|---|
| Clean checkout | `/tmp/opencode/equiv-work/rbitcoin-clean` |
| Commit | `ae47aa98174e04d0d8c493f13041daf65e4ac1d3` |
| `git status --porcelain` | empty (clean worktree) |
| rustc | 1.88.0 (6b00bc388 2025-06-23), LLVM 20.1.5 |
| LLVM tools | Ubuntu LLVM 20.1.2 under `/usr/lib/llvm-20/bin` |
| SAW | 1.6 (68eed5f release-1.6); `/opt/equiv-tools/saw-1.6/bin/saw`; sha256 `ca07da51c8f1ea98f91b6faf723f9ec795d908bf2c90f63eff57e97c7c2e7220` |
| Alive2 | v20.0; `/opt/equiv-tools/alive-tv-v20.0`; sha256 `91d9c14af27444c5248b948437b64e9dc7b0ed63d1bf478305a1e9cef2ed50ff` |
| Solvers | SAW bundle `abc`, `z3`, `cvc5`; **put `/opt/equiv-tools/saw-1.6/bin` on PATH** or SAW fails with `posix_spawnp: does not exist` |

Clean build:

```sh
cd /tmp/opencode/equiv-work/rbitcoin-clean
CARGO_TARGET_DIR=/tmp/opencode/equiv-work/target-188-clean \
  cargo +1.88.0 rustc --release --ignore-rust-version \
    -p rbitcoin-consensus --lib -- \
    --emit=llvm-ir,llvm-bc -C lto=no -C panic=abort
```

## Probe 1 — SAW cannot parse the whole consensus module

```sh
printf 'm <- llvm_load_module "target-188-clean/release/deps/rbitcoin_consensus-b3449e40c0e43013.bc";\n' > saw-rust-clean-load.saw
PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw saw-rust-clean-load.saw
```

Exact tail:

```text
Expected integer or float operand, found PtrOpaque
from:
	FUNC_CODE_INST_ATOMICRMW
	@_ZN4core3ptr134drop_in_place$LT$std..sync..mpsc..Receiver$LT$core..result..Result$LT$$LP$$RP$$C$rbitcoin_consensus..error..ConsensusError$GT$$GT$$GT$17h49e771dbc3e096ceE
	FUNCTION_BLOCK
	FUNCTION_BLOCK_ID
	value symbol table
	MODULE_BLOCK
	Bitstream
```

Cause: SAW 1.6's LLVM 20 bitcode reader does not accept `atomicrmw` on an
opaque pointer in unreachable `mpsc::Receiver` drop glue. The function is not
on the single-input script path.

Mitigation actually tested: extract a call-graph closure, which drops the
threaded/mpsc code. For an internal symbol, rewrite its `define internal` to
`define`, then internalize/globaldce:

```sh
perl -pe 's/^define internal /define / if /_ZN...eval_script.../' clean.ll > ext.ll
opt -passes='internalize,globaldce' \
    -internalize-public-api-list='_ZN...eval_script...' ext.ll -o closure.bc
```

Results:

| Module | Bytes | sha256 | SAW load |
|---|---:|---|---|
| `out/bc/rbitcoin_verify_input_closure.bc` | 530,120 | `265ea2d9cea644d76f082a437b2aa78c3506a22917d2191edc99aab2fa6f8160` | **OK** (99 defs / 81 undef) |
| `out/bc/rbitcoin_eval_script_closure.bc` | 377,128 | `720c298f82cae18e55276d001f27c3e3d6c90e78630720192ac14355f624eefa` | **OK** (78 defs / 68 undef) |

Both print `SAW_VI_CLOSURE_OK` / `SAW_EVAL_CLOSURE_OK`. Loading is not
verification: symbolic execution still needs overrides for the undefined
allocator, crypto, formatting, and helper symbols.

## Probe 2 — SAW verifies a clean Rust leaf

Artifact: `scriptnum_decode_width` from the **clean** `rbitcoin-primitives`
build (same commit, 1.88.0), `out/bc/scriptnum_decode_width_clean.bc`,
3,900 bytes, sha256 `b6298690c605b7491b331e56ef54cf9b5afd087378cb3c8da155dd912f7ca9a1`.

Spec: `findings/rust/saw-rust-leaf.saw` (also at
`/tmp/opencode/equiv-work/saw20-rust-leaf-clean.saw`). Fixed `v` length 5;
five bytes, `max_len`, and `require_minimal` symbolic; no postcondition.

```sh
PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw saw20-rust-leaf-clean.saw
```

```text
Verifying _ZN19rbitcoin_primitives9scriptnum22scriptnum_decode_width17h745f9dd8aee20e20E...
Simulating _ZN19rbitcoin_primitives9scriptnum22scriptnum_decode_width17h745f9dd8aee20e20E...
Checking proof obligations _ZN19rbitcoin_primitives9scriptnum22scriptnum_decode_width17h745f9dd8aee20e20E...
Proof succeeded! _ZN19rbitcoin_primitives9scriptnum22scriptnum_decode_width17h745f9dd8aee20e20E
SAW_RUST_LEAF_OK
```

Interpretation: SAW 1.6 ingests and symbolically executes this clean Rust
leaf. Because there is no postcondition, this proves memory safety for the
bounded input, **not** functional correctness or equivalence.

Tool quirk: allocating the 16-byte sret buffer as `llvm_array 16 (llvm_int 8)`
made SAW report `Memory store failed` at the i64 store; `llvm_array 2
(llvm_int 64)` (same 16 bytes) succeeds. Recorded so the next cell author does
not rediscover it.

## Probe 3 — SAW entry probe (proposal-only FFI module)

This uses `out/bc/rbitcoin_entry.bc` from the unregistered FFI patch. It is
included only to name the whole-entry blocker.

```sh
PATH=/opt/equiv-tools/saw-1.6/bin:$PATH saw saw20-rust-entry.saw
```

```text
Symbolic execution failed.
Abort due to assertion failure:
  .../library/core/src/num/uint_macros.rs:1905:13: error: in
  _ZN102_$LT$bitcoin..blockdata..transaction..Transaction$u20$as$u20$bitcoin..consensus..encode..Decodable$GT$35consensus_decode_from_finite_reader...
  Failed to load function handle: llvm.usub.sat.i64
  Details:
    No implementation or override found for pointer
```

Mitigation options (not yet implemented): add a SAW override / `llvm_unsafe_assume_spec`
for `llvm.usub.sat.i64`, or rewrite the IR to the equivalent non-saturating
sequence. The call is in `bitcoin`'s transaction decoder, before the script
engine.

## Probe 4 — Alive2 ingestion and translation

Alive2 v20.0 rejects `noalias`, `nocapture`, `sret([N x i8])`, and non-debug
metadata. After `sanitize_ir.sh` plus removal of the discarded allocator-guard
loads, the following **self-comparisons** translate and report
`syntactically equal`:

| Artifact | Transform | Alive2 summary |
|---|---|---|
| clean leaf `scriptnum_decode_width` | `sanitize_ir.sh` | 1 correct, 0 incorrect, 0 failed, 0 errors |
| clean `verify_input` (872 lines, loops, 7 allocs) | sanitize + drop discarded `load volatile i8, ptr @__rust_no_alloc_shim_is_unstable` | 1 correct, 0 incorrect, 0 failed, 0 errors |
| clean `eval_script` (6,071 lines, loops, 3 constant `inttoptr`, 100 allocs) | sanitize + drop discarded allocator-guard loads | 1 correct, 0 incorrect, 0 failed, 0 errors |

Commands:

```sh
llvm-dis cell.bc -o cell.ll
./sanitize_ir.sh cell.ll cell.clean.ll
grep -v 'load volatile i8, ptr @__rust_no_alloc_shim_is_unstable' \
    cell.clean.ll > cell.alive2.ll
llvm-as cell.alive2.ll -o cell.alive2.bc
alive-tv cell.alive2.bc cell.alive2.bc
```

This establishes that the Rust IR is inside Alive2's supported subset after a
deterministic, recorded transform. It is **not** an equivalence result:
comparing a module with itself only checks the translation/serialization path.
The three runs above used the single extracted function, not the call-graph
closure; the closure contains additional std/formatting functions and has not
been run through Alive2.

Without the volatile-load removal, `verify_input` stops at:

```text
ERROR: Unsupported instruction:   %78 = load volatile i8, ptr @__rust_no_alloc_shim_is_unstable, align 1
ERROR: Could not translate '_ZN18rbitcoin_consensus6script12verify_input...' to Alive IR
Summary: 0 correct, 0 incorrect, 0 failed-to-prove, 1 Alive2 errors
```

The whole proposal-only entry module (381 functions) reports 55 correct,
2 failed-to-prove, 63 Alive2 errors; `eval_script` fails on the same volatile
allocator-guard load. Atomics (`load atomic`, `atomicrmw`) are also rejected.

## Probe 5 — 1.88 runtime smoke (proposal-only FFI module)

The staticlib from the patched tree built and linked on 1.88.0:

```text
Finished `release` profile [optimized] target(s) in 8.44s
tx_len=61
pass   = 1 (want 1)
fail   = 0 (want 0)
badidx = 2 (want 2)
badlen = 2 (want 2)
```

This validates the 7-argument C ABI and result mapping only. It does not
validate the normative 8-argument `equiv_entry` (error_kind is absent) and does
not make the patched artifact a green cell.

`cargo test` on 1.88 is blocked by a dev-dependency: `rbitcoin-log` uses
`floor_char_boundary` (`error[E0658]`, unstable at 1.88). The same unit test
passes on 1.95.0, outside the LLVM-20 proof lane.

## What is not claimed

- No SAW `llvm_verify` of `verify_input`, `eval_script`, or the ABI entry.
- No Alive2 R-vs-C or R-vs-L comparison; only self-comparison.
- No postcondition/equivalence certificate for the SAW leaf.
- No tool run on the 1.95.0/LLVM-22 artifact in this report; the R-leg
  artifacts here are the 1.88.0/LLVM-20 lane.
