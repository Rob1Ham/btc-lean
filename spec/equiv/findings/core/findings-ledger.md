# CORE-IR finding ledger

Findings raised by the CORE-IR role. IDs are local to `findings/core/`; the
orchestrator can promote them into `spec/db/equiv-cells.yaml` / the global
findings index. All are **open** unless stated. Evidence paths are relative to
`spec/equiv/findings/core/`.

| ID | Area | Symptom | Evidence | Disposition | Blocking feature / next |
|---|---|---|---|---|---|
| **F-TOOL-001** | TOOL | Alive2 v20.0 cannot translate unpatched `EvalScript`: `Unsupported instruction: load atomic i8, ptr @_ZGVZ10EvalScript…` (the `__cxa_guard` guard variable). | `logs/alive2-unpatched-evalscript.log`; `interpreter-O0.bc` `f5718af…` | open / tool-gap | P-CORE-03 hoists the statics; after hoist-only the next blocker is F-TOOL-002 |
| **F-TOOL-002** | TOOL | Alive2 cannot translate `EvalScript` even with P-CORE-03 and P-CORE-01/02 because C++ exception edges remain: `Unsupported instruction: invoke … set_error`. | `logs/alive2-hoistonly-evalscript.log`, `logs/alive2-patched-evalscript.log`; `984177b…`, `5993460…` | open / tool-gap | Need a no-throw source refactor, or the domain-restricting `erase_exceptions.py` transform; the latter is recorded as a residual in `core-ir-report.md` §5 |
| **F-TOOL-003** | TOOL | Alive2/SAW ingest of the erased module still fails until `internalize,globaldce` removes undefined C++ ABI globals; SAW reports `Global was not a compile-time constant: _ZTVN10__cxxabiv117__class_type_infoE`. | earlier SAW trace in `/tmp/opencode/equiv-work/logs/saw-verify-abi-global-error.log`; `roots.bc` `2b9f683…` | open / tool-gap | Five-symbol public API list documented in `commands.md`; cells must cite `roots.bc`, not the pre-internalize module |
| **F-TOOL-004** | TOOL | O1 is not a usable proof lane for `ptrtoint`: module count 559 (vs 104 at O0), `EvalScript` alone 223, `inttoptr` 4. | `ir-features.tsv`; `interpreter-O1.bc` `01003ec…` | open / tool-gap | Keep O0 as primary; P-CORE-05 designs span leaf overloads; do not claim O1 proofs |
| **F-TOOL-005** | TOOL | Whole-function `EvalScript`/`VerifyScript` proof is not available: unbounded dispatch loop (`interpreter.cpp:449-1234`), heap/`std::vector` traffic, 32 undefined externals after erasure. Alive2 has only translated the erased function; no SMT run was attempted. SAW has no `EvalScript` spec. | `core-ir-report.md` §4/§6; `logs/callgraph-patched-erased.log` | open / tool-gap | P-CORE-04 `EvalStep` design; SAW overrides or real bitcode for externals; loop invariant |
| **F-TOOL-006** | TOOL | The scriptnum / `catch (...)` erasure is domain-restricting: unwind paths become `unreachable`; Core's old `SCRIPT_ERR_UNKNOWN_ERROR` behavior differs on out-of-domain exceptions (`bad_alloc`, `at()` out-of-range, empty-`popstack`). | `scripts/erase_exceptions.py`; `core-ir-report.md` §5 | open / domain-restricted | Differential fuzz must show these paths unreachable from the shim domain; otherwise replace erasure with P-CORE-01 + a no-throw proof |
| **F-HARNESS-001** | HARNESS | P-CORE-02's devirtualized checker has no linking shim yet: `shims/core/entry.cpp:137-149` constructs `TransactionSignatureChecker` directly, which would leave `BaseSignatureChecker::m_ctx` null under `BTC_EQUIV_DEVIRT`. | `handoff-contract-pcore02.md`; `shims/core/entry.cpp` | open / blocked on CONTRACT | CONTRACT must add the `CoreCheckerCtx` + four hooks; no cell may use the devirt engine before that |
| **F-PATCH-001** | PATCH | No differential behavior evidence exists for P-CORE-01/02/03; all three are PROPOSED. | `patches/core/README.md` registry; `core-ir-report.md` §7 | open / pending evidence | Execute the registry differential plans (1,258 script + 500 sighash + fuzz) before any status change |
| **F-PIN-001** | HARNESS | The first extraction used clang 18.1.3, not the pinned clang 20.1.2. | `NONPROOF-clang18.txt`; handoff `orchestrator-to-CORE-IR-001-clang-pin.md` | fixed locally (clang-20 artifacts in `hashes.txt`) / ledger action required | CELLS/LEDGER must ensure no cell cites the retired hashes |

## Notes

- F-TOOL-001…004 are tool-ingest facts, not Core defects.
- F-TOOL-006 and the P-CORE-01/03 exception/allocation differences are the
  main soundness caveats on any conditional equivalence claim.
- The leaf-level green results (`CastToBool` in Alive2, `operator|` in SAW)
  are **not** evidence that the engine is proved; see `core-ir-report.md` §6.
