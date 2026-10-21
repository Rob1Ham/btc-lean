# R-leg report — rbitcoin LLVM IR lane

Date: 2026-10-19. Role: RUST-IR. Write scope: `findings/rust/` and
`shims/rust/build.md` only. Nothing committed.

## Status in one paragraph

The R leg is **mapped and buildable**, and both tools have now been exercised
on real rbitcoin IR. It is **not green**. Official artifacts come from a clean
worktree at the pin. SAW 1.6 loads a call-graph closure and verifies one clean
Rust leaf; Alive2 v20.0 translates `eval_script` and `verify_input` only after
a deterministic attribute/metadata/volatile-load transform, and only in
self-comparison. The proposal-only whole-entry SAW probe stops at
`llvm.usub.sat.i64`; Alive2 stops at Rust atomics and the allocator-shim
volatile load unless transformed. The
contract's `equiv_entry(error_kind)` is not implemented, and the FFI patch that
would provide the 7-argument entry is **not authorized** by the patch policy.

## Pin and toolchain

| Item | Value |
|---|---|
| Commit | `ae47aa98174e04d0d8c493f13041daf65e4ac1d3` |
| Version | 0.8.99 (untagged) |
| Clean tree | `rbitcoin-clean`, `git status --porcelain` empty |
| Repo toolchain | rustc 1.95.0 (59807616e), LLVM 22.1.2 |
| Proof toolchain used | rustc 1.88.0 (6b00bc388), LLVM 20.1.5 |
| SAW | 1.6 (68eed5f), LLVM 20.1.2 |
| Alive2 | v20.0, LLVM 20.1.2 |
| Crypto | secp256k1 0.29.1 -> secp256k1-sys 0.10.1 -> vendored C libsecp256k1 0.4.1 |

Why 1.88: rustc 1.95/1.99 emit LLVM 22/23 IR, which carries `dead_on_return`;
Alive2 v20 rejects it at parse time (`ir-reject-llvm22.txt`,
`ir-reject-llvm23.txt`), and SAW 1.6 is built against LLVM 20.1.2. rustc 1.88
emits LLVM 20 IR that both tools can read. This is a **non-repo toolchain**:
the source is at the pin, but the front-end is not the repo's 1.95. PINS must
record it as a proof-lane toolchain, not pretend it is the repo pin.

## Crate map and entry points

| Crate / file | Role |
|---|---|
| `crates/rbitcoin-consensus/src/script/mod.rs` | dispatch and single-input core: `verify_job_all_inputs:52`, `verify_input:111`, `crypto` module `:293` |
| `.../script/interpreter.rs` | `eval_script:453`; opcode handlers; `op_checksig:956`, `op_checksigadd:979`, `op_checkmultisig:1077`; `checksig_schnorr:1416` |
| `.../block/mod.rs` | `ScriptVerifyFlags:765`, `ScriptCheckJob:913`, `ScriptCheckJob::new:949` |
| `.../script/p2tr.rs` | BIP341 key path `verify:21`, `verify_key_path:58`, control commitment `:117`, script path `:166` |
| `crates/rbitcoin-primitives/src/scriptnum.rs` | `scriptnum_is_minimal:44`, `scriptnum_decode_width:59` |
| `crates/rbitcoin-consensus/src/lib.rs` | public `verify_tx_scripts_with_flags:70`; hops to `script_pool::run_detached_join` |
| `crates/rbitcoin-consensus/src/script_pool.rs` | detached worker `run_detached_join:563` |

The public tx-level entry is **unusable for IR cells**: it spawns a detached
thread and returns a worker result, so it is neither deterministic in the
contract sense nor a single-function boundary. The single-input verifier is
`pub(crate)` but survives as a standalone symbol in the clean release IR:
`script::verify_input` (872 IR lines) and `interpreter::eval_script` (6,071
lines). `verify_job_all_inputs` (175 lines) is the all-inputs loop.

## Crypto path and seam

**Not pure Rust.** `secp256k1` 0.29.1 uses `secp256k1-sys` 0.10.1, which
builds vendored C libsecp256k1 0.4.1 with symbols prefixed
`rustsecp256k1_v0_10_0_*`. The IR has direct external calls, not an
interpreter or pure-Rust field implementation.

| Operation | Rust path | C symbol in IR |
|---|---|---|
| ECDSA parse | `crypto::parse_der_sig:320`, `Signature::from_der_lax` | `rustsecp256k1_v0_10_0_ecdsa_signature_parse_der_lax` (via crate) |
| Pubkey parse | `crypto::parse_pubkey:394`, `PublicKey::from_slice` | `rustsecp256k1_v0_10_0_ec_pubkey_parse` |
| ECDSA verify | `crypto::verify_ecdsa:777`, normalize S, `Secp256k1::verify_ecdsa` | `rustsecp256k1_v0_10_0_ecdsa_verify` |
| Schnorr verify | `interpreter::checksig_schnorr:1416` and p2tr -> `Secp256k1::verify_schnorr` | `rustsecp256k1_v0_10_0_schnorrsig_verify` |
| Taproot tweak | `p2tr` control-block check | `rustsecp256k1_v0_10_0_xonly_pubkey_tweak_add_check`, `xonly_pubkey_parse` |

`crypto::SECP` is a `thread_local!` `Secp256k1<VerifyOnly>` (`mod.rs:299`).
For symbolic proofs the seam should override `crypto::verify_ecdsa` and the
Schnorr verifier, or at the ABI level the four C symbols above. The
same-crypto premise must also account for rbitcoin's bundled libsecp256k1
0.4.1 versus Core's subtree version; that comparison is not done here.

## Panic policy

- `eval_script` and `verify_input` return `Result<_, ConsensusError>`, but the
  crate contains `expect`/`unwrap`/indexing panic sites, e.g.
  `interpreter.rs:1438` (`expect("64-byte schnorr slice")`).
- `panic=abort` is the Alive2 lane: no landing pads, no `invoke`, no unwind
  edges. A panic aborts the process, so result 3 is unavailable.
- `panic=unwind` is the contract/result-3 lane: the FFI uses `catch_unwind`,
  which introduces 2,895 `invoke`, 764 `landingpad`, 349 `resume` in the
  proposal build.
- No `extern "C"` boundary may unwind. The normative shim keeps
  `catch_unwind`; the proof lane must not claim result 3 from an abort build.

## IR artifacts

Official clean build (no source patch):

```sh
CARGO_TARGET_DIR=target-188-clean cargo +1.88.0 rustc --release \
  --ignore-rust-version -p rbitcoin-consensus --lib -- \
  --emit=llvm-ir,llvm-bc -C lto=no -C panic=abort
```

| Artifact | Bytes | sha256 |
|---|---:|---|
| `.../rbitcoin_consensus-b3449e40c0e43013.ll` | 6,557,818 | `0e80eaff568b0e58e7a93b34ef2ec36c9e3745f8005b073a2924243ee11699ea` |
| `.../rbitcoin_consensus-b3449e40c0e43013.bc` | 1,404,420 | `a568065fe89349d5c263c551a996c7fc0b1c71321ffafe962c7014376939cfaa` |

The module parses with LLVM 20.1.2 (`llvm-as`, `opt -passes=verify`). Shape:
81,696 lines, 375 defined / 195 undefined symbols, 0 `invoke`, 0
`landingpad`, 0 `resume`, 681 `unreachable`, 124 `ptrtoint`, 178 `inttoptr`,
2 inline-asm (std backtrace only). `eval_script` has 3 constant `inttoptr`
(1, 8) and 100 alloc/dealloc calls; `verify_input` has none of those and 7
allocations.

The patched `equiv-ffi` build (14,232,361 bytes, sha
`95037087...`) and its 613-line entry are **proposal-only**; see
`artifacts.md` for the trust split and `rbitcoin-ffi.patch` for the diff.

## Tool ingestion — what actually ran

Both tools were installed locally and exercised. Full commands and tails:
`tool-probes.md`.

### SAW 1.6

1. **Whole clean module: parse failure.**
   `Expected integer or float operand, found PtrOpaque` from
   `FUNC_CODE_INST_ATOMICRMW` in `mpsc::Receiver` drop glue. Not on the script
   path.
2. **Closures load.** After rewriting the target `define internal` to
   `define` and running `internalize,globaldce`, both
   `verify_input` (99 defs / 81 undef) and `eval_script` (78 defs / 68 undef)
   load successfully.
3. **Clean leaf verifies.** `scriptnum_decode_width`, fixed 5-byte input with
   symbolic bytes/`max_len`/`require_minimal`, no postcondition:
   `Proof succeeded!`. This is safety-only, not equivalence.
4. **Entry probe fails at an intrinsic.** The proposal-only 7-argument entry
   stops in `bitcoin`'s transaction decoder:
   `Failed to load function handle: llvm.usub.sat.i64` — no implementation or
   override.
5. SAW 1.6 quirk: a 16-byte sret buffer allocated as `[16 x i8]` fails with
   `Memory store failed`; `[2 x i64]` succeeds.

### Alive2 v20.0

1. **Raw Rust IR is rejected** for unsupported `noalias`, `nocapture`,
   `sret([N x i8])`, and non-debug metadata. `sanitize_ir.sh` strips them.
2. **The allocator-shim volatile load is rejected**:
   `Unsupported instruction: load volatile i8, ptr @__rust_no_alloc_shim_is_unstable`.
   The loaded value is unused; for the single-threaded harness it can be
   dropped deterministically.
3. **After both transforms**, self-comparison is green for the leaf,
   `verify_input`, and `eval_script` (1 correct, 0 incorrect, 0 failed,
   0 errors). This proves translation/ingestion, not equivalence. The
   self-comparison is reported by Alive2 as `syntactically equal`.
4. Atomics (`load atomic`, `atomicrmw`) remain unsupported; the proposal-only
   whole entry reports 55 correct, 2 failed-to-prove, 63 errors, with
   `eval_script` failing on the volatile load.

### Capability conclusion

| Boundary | SAW 1.6 | Alive2 v20.0 |
|---|---|---|
| Clean leaf (`scriptnum_decode_width`) | **yes** (safety, no post) | **yes** (self, after transform) |
| `verify_input` / `eval_script` closure | loads; needs overrides | single-function cell self-translates; closure not run |
| Whole module | parse fails on atomics | atomics/volatile fail |
| Full ABI entry | fails at `llvm.usub.sat.i64` | not reached |

## Contract gaps and findings

| ID | Gap | Consequence | Owner / next |
|---|---|---|---|
| R-GAP-01 | No typed script error: `ConsensusError::Script(String)` (`error.rs:12`); no `ScriptError` ordinal. The FFI entry has no `error_kind` out-param. | Result 0 cannot carry the ABI's Core ordinal; all failures must be `EQUIV_ERR_UNKNOWN_ERROR` plus a finding. E3 error equality blocked. | CONTRACT + RUST-IR: add `equiv_entry`, total string→ordinal map or typed error upstream. |
| R-GAP-02 | `flags_from_core` returns 2 for `SIGPUSHONLY`, `DISCOURAGE_NOPS`, `DISCOURAGE_TAPROOT`, `DISCOURAGE_SUCCESS`, `DISCOURAGE_PUBKEY`. ABI §5 admits bits 0..20 as in-domain. | A cell using those flags gets 2 instead of a verdict; silent domain narrowing if not recorded. | CELLS: scope those flags out explicitly, or rbitcoin must ignore policy-only bits. |
| R-GAP-03 | Tape carries one prevout; BIP341 commits to all spent outputs. | Multi-input taproot is a harness convention, out of contract. | CELLS: file the gap; no green claim. |
| R-GAP-04 | The 7-argument FFI patch is unregistered; patch policy is Core-only. | Patched artifacts cannot be green; official lane is internal-symbol cells. | Owner: relocate to `patches/rust/proposed/` and approve or reject; do not use in cells meanwhile. |
| R-GAP-05 | FFI null handling: `(tx_bytes.is_null() && tx_len != 0)` lets null+0 reach `from_raw_parts`, which is UB. | Out-of-domain result 2 is not guaranteed panic/UB-free. | CONTRACT: reject any null `tx_bytes`, and null `spk` when `spk_len==0` is allowed only with a dangling pointer. |
| R-GAP-06 | Whole-function SAW needs overrides for `__rust_alloc*` and ~68–81 std/core/crypto/formatting symbols; std is not in the bitcode. | E5 whole-function proof not yet possible. | TOOLS/CELLS: allocator + crypto overrides; or a fixed-capacity/no-std build. |

The 1.88 `cargo test` route is also blocked by `rbitcoin-log`'s
`floor_char_boundary` dev-dependency (`E0658`); the lib and staticlib build
fine. This is a test-lane limitation, not a consensus blocker.

## PINS.lock proposal (not applied)

`PINS.lock` currently pins `rustc 1.95.0` and calls the 1.88 lane advisory.
This report does not edit it. Two consistent options:

**Option A (dual-tool, recommended if the ledger accepts a proof-lane
front-end):** keep the repo pin and add the proof lane explicitly.

```toml
[rbitcoin]
commit = ae47aa98174e04d0d8c493f13041daf65e4ac1d3
version = 0.8.99
source = reardencode/rbitcoin
toolchain = rustc 1.95.0 (59807616e 2026-04-14), LLVM 22.1.2   # repo pin
proof_toolchain = rustc 1.88.0 (6b00bc388 2025-06-23), LLVM 20.1.5
proof_toolchain_note = non-repo front-end; required because Alive2 v20 rejects LLVM 22/23 dead_on_return and SAW 1.6 embeds LLVM 20.1.2. Source commit unchanged.
build = clean worktree; cargo +1.88.0 rustc --release --ignore-rust-version -p rbitcoin-consensus --lib -- --emit=llvm-ir,llvm-bc -C lto=no -C panic=abort
ir_ll_sha256 = 0e80eaff568b0e58e7a93b34ef2ec36c9e3745f8005b073a2924243ee11699ea
ir_bc_sha256 = a568065fe89349d5c263c551a996c7fc0b1c71321ffafe962c7014376939cfaa
crypto = secp256k1 0.29.1 / secp256k1-sys 0.10.1 / bundled libsecp256k1 0.4.1
patched_artifacts = none (FFI patch is proposal-only, not a pin)
```

**Option B (strict repo pin):** keep `toolchain = 1.95.0` and record R as
SAW-only / Alive2-inapplicable. The 1.88 artifacts then remain advisory and
cannot support a green cell. Do not mix the two in one cell.

`[tools]` already pins SAW 1.6 (68eed5f) and Alive2 v20.0; no change needed.
Record the solver PATH requirement and the SAW/Alive2 binary hashes from
`tool-probes.md` if the ledger hashes executables.

## Next actions

1. **TOOLS**: reproduce the four probes; decide Option A or B in PINS.lock;
   record `saw`/`alive-tv` hashes and the solver bundle hash.
2. **CONTRACT**: implement `equiv_entry` with `error_kind`, fix R-GAP-05, and
   resolve R-GAP-02 domain scope. Do not use the FFI patch in a cell until
   R-GAP-04 is approved.
3. **CELLS**: start with `scriptnum_decode_width` (SAW safety spec exists) and
   `verify_input`/`eval_script` closures; add allocator/crypto overrides; keep
   self-comparison labelled as ingestion, not equivalence.
4. **RUST-IR**: hand off the clean artifacts and this report; no claim of a
   green R cell, no equivalence certificate, no whole-function result.

## Non-claims

- No R-vs-C or R-vs-L equivalence proof was run.
- The SAW leaf has no postcondition; it is safety-only.
- The Alive2 results are module-vs-itself (`syntactically equal`), not
  refinement.
- No error-kind equality; no multi-input taproot; no result-3 claim from the
  abort build.
