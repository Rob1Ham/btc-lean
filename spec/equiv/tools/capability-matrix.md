# Capability matrix — Alive2 v20.0 vs SAW 1.6

Scope: **E0 probes only.** These are small hand-written LLVM IR/C probes run on
2026-10-19 against the pinned tools. They establish tool *ingestion and
basic semantics*, not any equivalence cell. A "YES" below is backed by a log
in `findings/tools/probes/`; "TODO" means not probed here.

Pins: Alive2 `v20.0` (`c0f5434…`, built with LLVM 20.1.2 + Z3 4.8.12);
SAW `1.6` (`68eed5f`, Ubuntu 24.04 X64 bundle); clang `20.1.2`.
Probe inputs live in `tools/tests/probes/`; the E0 hello-world is in
`tools/tests/`.

| Capability | Alive2 | SAW | How verified | Notes |
|---|---|---|---|---|
| C++ exceptions: `invoke` / `landingpad` | **NO** | **PARTIAL** | `alive2-exceptions.out`: `ERROR: Unsupported instruction: invoke …` → `Could not translate 'f'`, exit 1. `saw-exceptions.out`: symbolic simulation completed with side conditions, then `Failed to load function handle: __cxa_allocate_exception`. | Alive2 cannot translate exception edges at all. SAW *can* simulate `invoke`/`landingpad`, but the C++ runtime calls (`__cxa_allocate_exception`, `__cxa_throw`, `__cxa_begin_catch`, …) need explicit overrides. No green exception proof was produced in E0. |
| Indirect calls / function pointers | **NO** (practical) | **PARTIAL** | `alive2-indirect-semantic.out`: translates `call i32 %p(...)` but equivalence fails with `Source and target don't have the same return domain`. `saw-indirect.out`: `Global symbol "g" has no associated allocation`. | Alive2 self-comparison is only "syntactically equal" and proves nothing; the semantic probe fails. SAW documents indirect calls via overrides, but the probe needs the global/pointer allocated and an override; no green proof yet. |
| `ptrtoint` | **YES** (basic) | **TODO** | `alive2-ptrtoint-semantic.out`: `ptrtoint %p` vs `add (ptrtoint %p), 0` proved correct. Self-compare of both `p2i` and `i2p` also translated. | Contradicts the older README/GOAL wording "no ptrtoint" for Alive2 v20. Still verify provenance-sensitive cases per cell. SAW pointer-to-int was not probed. |
| `inttoptr` | **PARTIAL / unsound-looking** | **TODO** | `alive2-inttoptr-semantic.out`: `inttoptr(ptrtoint p)` vs `p` is reported **incorrect**, with `phy-ptr(...)` vs concrete `pointer(...)` values. | Alive2 translates it but does not treat the round-trip as identity (pointer provenance). Do **not** rely on `inttoptr` cells without a dedicated argument; expect counterexamples. SAW not probed. |
| Unbounded loops | **NO** (bounded unrolling only) | **NO** (without invariant) | `alive2-loop-semantic.out`: mismatch found on the `n < 1` path; Alive2 exposes only `--src-unroll` / `--tgt-unroll` (default 0), no invariant mechanism. `saw-loop.out`: 180 s timeout with no invariant. | Alive2 is a bounded translator: loops must be unrolled to a fixed depth or sliced away. SAW needs a loop invariant (`llvm_loop_invariant` / invariant-based proof) for unbounded loops; E1+ cells must provide one. |
| Memory-model refinement (final memory) | **YES** (checked) | **TODO** | `alive2-memory-semantic.out`: `store v; load` vs `ret v` fails with `ERROR: Mismatch in memory` (target memory is unchanged → poison), i.e. final memory is compared. | Alive2 is stricter than return-value-only: a source store must be matched. This is useful but means dead-store / final-memory cells need care. SAW points-to/final-memory postconditions were not probed. |
| External / unknown calls | **YES** (uninterpreted) | **NO** without override | `alive2-external-semantic.out`: `ext(x)+1` vs `ext(x)+2` → concrete value mismatch. `saw-external.out`: `Failed to load function handle: ext` / `No implementation or override found for pointer`. | Alive2 models an unknown external as an uninterpreted function, so it can detect misuse and can prove equality of identical call patterns. SAW requires an explicit `llvm_override`/spec for every external; this is exactly the crypto seam (`§7`) mechanism. |
| LLVM version support | **LLVM 20.1.2** (build + ingest) | **LLVM 20.1.2** ingested | Alive2 v20.0 built against `/usr/lib/llvm-20`; parses clang-20 IR in all probes. SAW 1.6 loaded clang-20 `hello.bc` and proved it. | Alive2 `master` did **not** build against LLVM 18/20 (API drift); v20.0 is the pinned compatible tag. SAW's maximum bitcode version was not probed. `PINS.lock` records a separate RUST-IR experiment claiming LLVM 22.1.2 ingestion; it was not re-run by this role. |
| Proof / certificate export | **NO** certificate | **PARTIAL**: JSON summary yes; Rocq TODO | `saw-summary.json` produced by `saw --summary=… --summary-format=json`; per-method/per-VC `status: verified`, solver, elapsed time. | SAW's JSON summary is evidence metadata, **not** a proof object. Rocq/Coq proof export was not exercised. Alive2 emits a textual report only; no machine-checkable certificate. |
| Counterexample quality | **YES** (concrete values) | **YES** (concrete values + UB reason) | `alive2-hello-bad.out`: `i32 %x = #x00000003`, source 4 / target 5. `saw-hello-nsw-poison.out`: input `x: 2147483647`, "Signed addition caused wrapping even though the `nsw` flag was set". | Both give replayable inputs. SAW additionally names the UB/poison cause and source line. |
| Poison / UB modeling | **YES** | **YES** | Same logs as above; SAW's `nsw` poison finding is a real clang `-O0` artifact (`add nsw` on signed C addition). | Cells must decide whether to use `-fwrapv`/unsigned types or assert `nsw` preconditions. This is a recurring source of spurious "proof" failures, not a tool bug. |

## Reading the matrix

- "NO" means the probe **failed with a tool error**, not that the cell is
  impossible: Alive2 may accept a sliced/bounded form, and SAW may accept the
  same code after overrides/invariants. Those are cell-level work items.
- "PARTIAL" means the tool got past parsing/simulation but the probe did not
  reach a green proof.
- Every TODO above is a candidate E1 probe. Do not infer capability from the
  README's upstream-limits table alone: the Alive2 `ptrtoint` and final-memory
  results already differ from the stale summary in `../README.md`.

## Addendum — orchestrator cross-checks (2026-10-19)

Two rows above were re-probed after this matrix was written; the artifacts are
under `../findings/verifications/artifacts/`.

1. **SAW + exceptions can be green when the throw path is infeasible.**
   `tool-limits/ex_edges` (clang 20.1.2, `-O0`, 2 `invoke` / 2 `landingpad`)
   was proved by SAW 1.6 under `llvm_precond {{ x < 0x7fffffff }}`:
   `Proof succeeded! ex_edges`. The same function is hard-rejected by Alive2
   (`Could not translate 'ex_edges' to Alive IR`). This does not contradict
   the PARTIAL row: when the exceptional path is *feasible*, the `__cxa_*`
   runtime calls still need overrides. It does mean E5 should try SAW with a
   domain precondition before declaring a residual.
2. **SAW's bitcode ceiling is at least LLVM 22.1.2.** Raw rustc 1.95.0
   bitcode (LLVM 22.1.2) loaded and proved (`SAW_1.95.0_OK`); rustc 1.99.0
   bitcode (LLVM 23.1.1) fails in the bitstream parser. See
   `../findings/verifications/artifacts/rust-hello/matrix.txt`. The row's
   "maximum bitcode version was not probed" is therefore superseded: 22.1.2
   is accepted, 23.1.1 is not. **Alive2's ceiling is lower for Rust:** the
   real rbitcoin 1.95 text is rejected at `dead_on_return`, and a minimal
   -O2 leaf is rejected at metadata kind 8 (`F-TOOL-001`). The `add_one` leaf
   passes only because it contains neither. R/Alive2 at the pin is
   inapplicable, not green.
3. **Alive2 on `ex_edges`:** confirmed hard error at exit 1, independent of
   the probe above.

