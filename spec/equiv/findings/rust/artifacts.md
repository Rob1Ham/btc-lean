# R-leg artifact index (rbitcoin)

All paths below are from `/tmp/opencode/equiv-work/`. Hashes are SHA-256 of
the exact bytes produced. Nothing here was git-committed.

**Trust split.** The official artifacts are built from a **clean worktree**
(`rbitcoin-clean`, `git status --porcelain` empty) at the pin. Artifacts built
from the `equiv-ffi` patch are **proposal-only**: `patches/README.md`
authorizes Core patches, not rbitcoin patches, and handoff
`orchestrator-to-RUST-IR-003` requires approval before any patched artifact is
used. They are kept to document the ABI lane and must not be cited as green.

## Pin

| Item | Value |
|---|---|
| Repository | `https://github.com/reardencode/rbitcoin` |
| Commit | `ae47aa98174e04d0d8c493f13041daf65e4ac1d3` |
| Commit date | 2026-10-19 16:37:50 -0500 |
| Cargo version | `0.8.99` |
| `Cargo.lock` sha256 | `d0f177616e0c48925e24b1a37bfb7faa2059768cb7c7d1c51ed71d03700d5026` |
| `rust-toolchain.toml` sha256 | `12dc5d64dbd96c1b07be2943241d52d9f6127a79ba47a820455ba7b873fc896a` |
| Repo toolchain | rustc 1.95.0 (59807616e 2026-04-14), LLVM 22.1.2 |
| Proof-lane toolchain | rustc 1.88.0 (6b00bc388 2025-06-23), LLVM 20.1.5 |
| Crypto | secp256k1 0.29.1 -> secp256k1-sys 0.10.1 (vendored C libsecp256k1 0.4.1) |

## Official clean artifacts (no source patch)

Built with:

```sh
CARGO_TARGET_DIR=target-188-clean cargo +1.88.0 rustc --release \
  --ignore-rust-version -p rbitcoin-consensus --lib -- \
  --emit=llvm-ir,llvm-bc -C lto=no -C panic=abort
```

| Artifact | Bytes | sha256 | LLVM 20.1.2 parse |
|---|---:|---|---|
| `target-188-clean/release/deps/rbitcoin_consensus-b3449e40c0e43013.ll` | 6,557,818 | `0e80eaff568b0e58e7a93b34ef2ec36c9e3745f8005b073a2924243ee11699ea` | **OK** (`llvm-as`, `opt -passes=verify`) |
| `target-188-clean/release/deps/rbitcoin_consensus-b3449e40c0e43013.bc` | 1,404,420 | `a568065fe89349d5c263c551a996c7fc0b1c71321ffafe962c7014376939cfaa` | **OK** |
| round-trip `llvm-as` bitcode | — | `68e769caf42eddff263cafc0ffa5770d042010f013a4315efbb9023d987a9121` | **OK** |

Module shape: 81,696 lines, 375 defined symbols, 195 undefined; 0 `invoke`,
0 `landingpad`, 0 `resume`, 681 `unreachable`, 124 `ptrtoint`, 178 `inttoptr`,
2 inline-asm (std backtrace only, not in the script call graph).

### Clean cell modules

`eval_script` and `verify_input` are local (`t`) symbols. To build a
call-graph closure, rewrite that one `define internal` to `define`, then:

```sh
opt -passes='internalize,globaldce' \
    -internalize-public-api-list='<mangled-symbol>' ext.ll -o closure.bc
```

| Artifact | Bytes | sha256 | SAW 1.6 load |
|---|---:|---|---|
| `out/bc/rbitcoin_verify_input_closure.bc` (99 defs / 81 undef) | 530,120 | `265ea2d9cea644d76f082a437b2aa78c3506a22917d2191edc99aab2fa6f8160` | **OK** |
| `out/bc/rbitcoin_eval_script_closure.bc` (78 defs / 68 undef) | 377,128 | `720c298f82cae18e55276d001f27c3e3d6c90e78630720192ac14355f624eefa` | **OK** |
| `out/bc/rbitcoin_verify_input_cell.bc` (`llvm-extract`, 30 undef) | 25,016 | `919bc8179f1d6c60460a05a26fc170435b8fc9ad0533defdd453ede5be64cfa3` | not run |
| `out/bc/eval_script_cell.bc` (`llvm-extract`, 109 undef) | 90,768 | `59972f994e968f37a9b55aa03b8f387a9d59e2f389f25b972244e976caec9b7b` | not run |

Per-function shape in the clean module:

| Function | IR lines | invoke | landingpad | ptrtoint | inttoptr | alloc/dealloc calls |
|---|---:|---:|---:|---:|---:|---:|
| `interpreter::eval_script` | 6,071 | 0 | 0 | 0 | 3 (constant sentinels 1, 8) | 100 |
| `script::verify_input` | 872 | 0 | 0 | 0 | 0 | 7 |
| `script::verify_job_all_inputs` | 175 | 0 | 0 | 0 | 0 | 1 |

### Clean leaf

`rbitcoin_primitives::scriptnum::scriptnum_decode_width` (same commit,
`rbitcoin-primitives` 1.88.0 build):

| Artifact | Bytes | sha256 |
|---|---:|---|
| `out/bc/scriptnum_decode_width_clean.bc` | 3,900 | `b6298690c605b7491b331e56ef54cf9b5afd087378cb3c8da155dd912f7ca9a1` |

SAW 1.6 verifies this leaf (safety only, no postcondition); see
`tool-probes.md` and `saw-rust-leaf.saw`.

## Proposal-only `equiv-ffi` artifacts (not authorized)

Built from the dirty working tree with the patch in
`findings/rust/rbitcoin-ffi.patch`. These expose the convenience 7-argument
`rbtc_rust_verify`; they do **not** implement the normative 8-argument
`equiv_entry(error_kind)`. Do not use them in a green cell.

| rustc | LLVM | Profile | IR file | Bytes | IR sha256 | LLVM 20.1.2 parse |
|---|---|---|---|---:|---|---|
| 1.99.0 (b940084d7) | 23.1.1 | release, panic=abort (pre-patch) | `rbitcoin/target/release/deps/rbitcoin_consensus-387f44e21ef58a47.ll` | 15,386,655 | `b31a0ce3613569691ae926bd7ec84ecdbba63e036ca3e431d8baa0b7a08dca32` | **FAIL** (`dead_on_return`) |
| 1.95.0 (59807616e) | 22.1.2 | release, panic=abort (pre-gating) | `target-195-ir/release/deps/rbitcoin_consensus-68e7c81c2384e3ba.ll` | 14,216,525 | `1654c15d3bba8a89ffbd20ebf342fec310ca2e5d0337c26a81a37b8479632c86` | **FAIL** (`dead_on_return`) |
| 1.88.0 (6b00bc388) | 20.1.5 | release, panic=abort + `equiv-ffi` | `target-188-final/release/deps/rbitcoin_consensus-e64cd8423f8225c3.ll` | 14,232,361 | `95037087cd92b95dee88bcbf14519b99f9ec420be34d01642cc724f5e706cad5` | **OK** |
| 1.88.0 | 20.1.5 | release, unwind + `equiv-ffi` | `target-188-unwind/release/deps/rbitcoin_consensus-63dba520d41b25f8.ll` | 15,355,577 | `dca39396a6bf0c24414b3092091141f814f549a95f8f5b8da6286052dae5b418` | **OK** |
| 1.88.0 | 20.1.5 | dev (O0) + `equiv-ffi` | `target-188-dev/debug/deps/rbitcoin_consensus-b19b2a3fa7b10053.ll` | 12,272,707 | `8c9a215853b57b03abf3f142aa5ba1b24305c40c1e0d41ead309e4d04bdd1b5f` | **OK** |

Rejection evidence: `ir-reject-llvm23.txt`, `ir-reject-llvm22.txt`. Both fail
at the first `dead_on_return` parameter attribute; the LLVM 23 IR also carries
`!guid` metadata.

| Proposal bitcode | Bytes | sha256 |
|---|---:|---|
| `out/bc/rbitcoin_final.bc` (release, abort) | 2,791,480 | `eafe507b7efbe7c656643b0789f4a6dbbc8ef3c73a009f90c10ce3fa78b292b6` |
| `out/bc/rbitcoin_unwind.bc` (release, unwind) | 2,948,936 | `21fa574bde33dafade4c8e2fac00dcce5779e8734b58dcd56a8b2022a20f8292` |
| `out/bc/rbitcoin_entry.bc` (internalized entry) | 1,152,892 | `e290a8a5cf99cfe6fe42ce3ad3d21a3404a5450a39b4e0a3cae96b4c3db7d5e0` |

Proposal entry `rbtc_rust_verify` is 613 IR lines with 0 invoke/landingpad/
ptrtoint/inttoptr/indirect calls; `eval_script` in that build has 2 constant
`inttoptr` and 200 alloc/dealloc. Whole-module abort counts: 0 invoke,
0 landingpad, 0 resume, 731 `unreachable`, 70 `ptrtoint`, 174 `inttoptr`,
2 inline-asm.

The unwind build has 2,895 invoke, 764 landingpad, 349 resume; it is the
result-3/exception lane, not an Alive2 lane.

## Runtime validation (proposal-only ABI)

1. Rust unit test, rustc 1.95.0:
   `cargo test --ignore-rust-version -p rbitcoin-consensus --features equiv-ffi --lib script::ffi::tests`
   Result: `test script::ffi::tests::entry_maps_pass_fail_and_bad_input ... ok`.
   1.88 `cargo test` is blocked by `rbitcoin-log`'s unstable
   `floor_char_boundary` dev-dependency.
2. C-ABI staticlib + gcc test on 1.88.0: pass=1, fail=0, badidx=2, badlen=2.
   This validates the 7-argument name/order/result mapping, not `equiv_entry`.

## Evidence files

- `tool-probes.md` — exact SAW/Alive2 commands, hashes, and error tails.
- `saw-rust-leaf.saw` — clean-leaf SAW spec (safety-only).
- `saw-rust-entry.saw` — proposal-only entry probe.
- `sanitize_ir.sh` — Alive2 attribute/metadata transform.
- `ir-reject-llvm22.txt`, `ir-reject-llvm23.txt` — version barriers.
