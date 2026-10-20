# Wave-64 translation census — advisory, off-pin

Input: pinned `rustc 1.95.0 / LLVM 22.1.2` rbitcoin_consensus module, sanitized
to LLVM-20/Alive2-v20 by `sanitize_v22_to_v20.py` (see `REPORT.md`).
`san7.ll` sha256 `c475de3053ec8dbc00de44b894bf9bcee6c77dcb928e835385565a4ef0de3c5f`.

Census command (self-comparison; `--skip-smt` is a translation census, not a
proof):

```sh
/opt/equiv-tools/alive-tv-v20.0 --skip-smt san7.bc san7.bc > alive-whole-module.out 2>&1
python3 census_w64.py --ll san7.ll --alive alive-whole-module.out \
    --out-json w64/census-san7.json --out-tsv w64/census-san7.tsv
```

## Overall (351 defined functions)

| status | functions |
|---|---:|
| translated, correct in self-comparison (`syntactically equal`) | 180 |
| translated, `correct` but not marked `(syntactically equal)` | 3 |
| translated, solver-only (`ERROR: Skip`) | 31 |
| **translated (total)** | **214 / 351 = 61.0%** |
| rejected at translation | 137 / 351 = 39.0% |

Translation failures are exactly two classes: `sret([N x i8])` 57 and
atomic instructions 80 (cmpxchg 12, atomicrmw 30, load atomic 37, store atomic
1, over all crates). No `load volatile`, no metadata-kind errors on the 1.95
side.

## rbitcoin_consensus (183 defined functions)

| status | functions |
|---|---:|
| translated, correct in self-comparison | 79 (78 syntactic + 1 non-syntactic `correct`) |
| translated, solver-only | 15 |
| **translated (total)** | **94 / 183 = 51.4%** |
| rejected: `sret([N x i8])` | 57 |
| rejected: atomic instruction | 32 (load atomic 18, atomicrmw 7, cmpxchg 6, store atomic 1) |
| **rejected (total)** | **89 / 183 = 48.6%** |

`eval_script` itself translates and self-compares syntactically; the public
engine wrappers do not, because they return `Result<(), ConsensusError>` via
`sret([24 x i8])`:

| engine entry | status | first blocker |
|---|---|---|
| `interpreter::eval_script` | translated | self-comparison only (no proof) |
| `interpreter::EvalContext::from_job` | rejected | `load atomic i32 ... acquire` |
| `script::verify_job_all_inputs` | rejected | `sret([24 x i8])` |
| `verify_tx_scripts_with_flags` | rejected | `sret([24 x i8])` |
| `verify_tx_scripts_detached` | **rejected** | `sret([24 x i8])` |
| `verify_tx_scripts_detached_forks` | **rejected** | `sret([24 x i8])` |
| `interpreter::bin_cmp` (6 monomorphisations) | translated, solver-only | 10 s solver budget |
| `interpreter::bin_arith` (2) | translated, solver-only | 10 s solver budget |
| `interpreter::op_checksigadd` | translated, solver-only | 10 s solver budget |
| `interpreter::op_checkmultisig` | translated, solver-only | 10 s solver budget |
| `interpreter::ecdsa_sig_matches` | translated, solver-only | 10 s solver budget |
| `p2tr::verify` | translated, solver-only | 10 s solver budget |
| `tx_precompute::from_tx_inner` | translated, solver-only | 10 s solver budget |
| `interpreter::script_code_bytes` | translated | self-comparison only |
| `interpreter::op_checksig` | translated | self-comparison only |
| `script::verify_native_witness` | translated | self-comparison only |

## Per-area translation (main areas)

`proved` = correct in self-comparison; `solver` = translated but needs the
solver; `sret`/`atomic` = translation blockers.

| area | total | translated | proved | solver | sret | atomic |
|---|---:|---:|---:|---:|---:|---:|
| non-rbitcoin (std/alloc/core/bitcoin deps) | 139 | 91 | 78 | 13 | 0 | 48 |
| bitcoin-crate | 29 | 29 | 26 | 3 | 0 | 0 |
| script::interpreter | 26 | 25 | 14 | 11 | 0 | 1 |
| block | 21 | 11 | 11 | 0 | 10 | 0 |
| impl/drop-glue | 17 | 8 | 7 | 1 | 1 | 8 |
| script_pool | 12 | 2 | 2 | 0 | 0 | 10 |
| block::facts | 11 | 0 | 0 | 0 | 11 | 0 |
| script::crypto | 10 | 8 | 8 | 0 | 0 | 2 |
| params::ChainParams | 9 | 2 | 2 | 0 | 7 | 0 |
| tx_precompute::TxPrecompute | 9 | 3 | 2 | 1 | 6 | 0 |
| regtest_pad | 7 | 1 | 1 | 0 | 4 | 2 |
| policy | 6 | 6 | 6 | 0 | 0 | 0 |
| clock::NodeClock | 5 | 1 | 1 | 0 | 0 | 4 |
| params (free functions) | 5 | 1 | 1 | 0 | 4 | 0 |
| script (top-level) | 5 | 4 | 4 | 0 | 1 | 0 |
| signet | 5 | 2 | 1 | 1 | 3 | 0 |
| block::ScriptCheckJob | 4 | 1 | 1 | 0 | 1 | 2 |
| script::nested | 4 | 4 | 4 | 0 | 0 | 0 |
| silent_payments | 4 | 2 | 2 | 0 | 1 | 1 |
| header | 3 | 0 | 0 | 0 | 3 | 0 |
| script::p2wpkh | 3 | 3 | 3 | 0 | 0 | 0 |

Full per-function rows: `w64/census-san7.tsv`. Exact blocked lists:
`w64/blockers-sret.tsv`, `w64/blockers-atomics.tsv`,
`w64/solver.tsv`.

## Cross-artifact side (official 1.88 / LLVM-20 module)

The same sanitizer is applied to the 1.88 artifact (it needs R5/R6/R7/R8/R10
and the legacy `nocapture` rule R12). Result: `r188c.ll` sha256
`dd1f858087fddb5f80386a11c545ba5279466db8a075cfc7b380712b261bc2a5`.

| status | functions |
|---|---:|
| translated | 163 / 366 = 44.5% |
| rejected | 203 / 366 = 55.5% |

The 1.88 side has a **new blocker class**: `load volatile i8, ptr
@__rust_no_alloc_shim_is_unstable` — 64 functions (41 of them
`rbitcoin_consensus`), including `eval_script`, `op_checksig`,
`verify_native_witness`, every `bin_cmp`, and `p2tr::verify`. It also has 60
`sret`, 79 atomic, and no metadata-kind errors after sanitization. Exact list:
`w64/blockers-188.tsv`.

Consequence: the cross-artifact lane is leaf-only in practice. A function that
translates on the 1.95 side but hits `load volatile` on the 1.88 side cannot be
compared at all (`eval_script` is the important example).

## Cross-artifact results (46 comparable pairs)

| status | pairs |
|---|---:|
| correct, SMT (not `syntactically equal`) | 8 |
| incorrect (`Source is more defined than target`) | 8 |
| failed-to-prove | 18 |
| timeout | 12 |

The 8 proofs are the real refinements; five are new in wave 64. The 8
`incorrect` are cross-build `!range`/callee-name artifacts, not source
divergences. Per-pair rows: `w64/cross/results.tsv`; report:
`../EXTENSION-W64.md` §3.
