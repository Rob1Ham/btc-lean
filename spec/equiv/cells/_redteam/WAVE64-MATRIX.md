# Wave64 E3/E4 required-mutation matrix

Base commit: `5946c02`. Branch: `wave64/48-mutations-e3e4`.
Tools: `alive-tv` (Ubuntu LLVM 20.1.2), `saw` 1.6, `clang++-20`.
Status values: **KILLED** = admissible mutant run with a non-green
expected cell, concrete witness, reverting record and green post-revert
baseline; **UNOBSERVED** = no existing cell exercises the mutant's witness;
**WITHDRAWN** = historical report retained but not evidence.

## E3 required set (2/5 admitted)

| ID | Status | Cell that would observe it | Evidence / blocker |
|---|---|---|---|
| `M-E3-001` (CMS sig/key iteration order) | **UNOBSERVED** | none | The only materialized CMS cell is the 1-of-1 `cells/e3-cms/C-L-cms-1of1`. With one signature and one key, swapping the loop index is unobservable. Needs a 2-of-3 CMS cell. |
| `M-E3-002` (NULLDUMMY dropped) | **KILLED** | `cells/e3-cms/C-L-cms-1of1` (`cell_cms_nulldummy`) | `runs/M-E3-002-e3-cell-20261020T220746Z/report.md`; alive2 green→not-green, saw 16/16→10/16; witness 112 (`SIG_NULLDUMMY=28`) vs 264 (success). |
| `M-E3-003` (NULLFAIL dropped) | **UNOBSERVED** | none | `l_cms.cpp` only models `nullFail=false`; no non-empty failing-signature scenario exists in the cell. Needs a NULLFAIL cell/flag set. |
| `M-E3-004` (HIGH_S/low-S gate) | **UNOBSERVED** | none | `l_checksig.cpp`/`c_checksig.cpp` state flags=0, so `CheckSignatureEncoding` (HIGH_S/LOW_S) is a no-op and no high-S witness exists. |
| `M-E3-005` (CMS count bounds) | **UNOBSERVED** | none | The 1-of-1 cell guards the domain at `nKeys=nSigs=1` and never constructs `nKeys=21` or `nSigs>nKeys`. No count-bound scenario exists. |
| `M-E3-006` (FindAndDelete in v0) | **UNOBSERVED** | none | The cell passes a fixed 2-byte `scriptCode` and does not model FindAndDelete or the SigVersion gate. |
| `M-E3-007` (CODESEPARATOR offset) | **UNOBSERVED** | none | No CODESEPARATOR witness; `codeSepPos` is initialized but never exercised by a closed scenario. |
| `M-E3-008` (CHECKMULTISIGVERIFY error kind) | **KILLED** | `cells/e3-cms/C-L-cms-1of1` (`cell_cmsverify`) | `runs/M-E3-008-e3-cell-20261020T220846Z/report.md`; alive2 green→not-green, saw 16/16→11/16; witness 52 (`CHECKMULTISIGVERIFY=13`) vs 24 (`EVAL_FALSE=2`). |

Required "one of `M-E3-004`–`M-E3-007`": **not met**; all four are unobserved.

## E4 required set (3/5 admitted)

| ID | Status | Cell that would observe it | Evidence / blocker |
|---|---|---|---|
| `M-E4-001` (P2SH redeem source) | **UNOBSERVED** | none | No P2SH cell is materialized. The existing E4 cells are witness-v0 dispatch/hash/build and taproot/tapscript dispatch. |
| `M-E4-002` (witness stack order) | **UNOBSERVED** | none | No stack-order cell exists. The witness-v0 cells take `witness_n`/`hash_ok`/`exec_*` as scalars and abstract script execution. |
| `M-E4-003` (taproot leaf version/mask) | **KILLED** | `cells/tapscript/C-L-taproot-scriptpath-dispatch` (`cell_leaf_version`) | `runs/M-E4-003-e4-cell-20261020T221027Z/report.md`; alive2 green→not-green, saw 6/6→3/6; witness result 2 (tapscript) vs 1; SAW `control0=0xffffffffffffffc1` with the wrong mask. |
| `M-E4-004` (v0 program length/arity) | **KILLED** | `cells/e4-witness/C-L-witness-v0-dispatch` (`cell_v0_dispatch`) | `runs/M-E4-004-e4-cell-20261020T221054Z/report.md`; alive2 green→not-green, saw green→not-green; witness `plen=20, wn=3`: packed 160 (fail,40) vs 1 (success). |
| `M-E4-007` (`OP_SUCCESSx`) | **KILLED** | `cells/tapscript/C-L-tapscript-isopsuccess` (`cell_is_op_success`) | `runs/M-E4-007-e4-cell-20261020T221110Z/report.md`; alive2 green→not-green, saw 2/2→1/2; witness `w=80`/`w=98`: 1 vs 0. |

## Historical rows (unchanged)

| Row | Status | Note |
|---|---|---|
| 2026-10-19 `M-E1-001` twin, `M-E1-002` twin, `M-E1-006` twin, `M-E1-001` core-copy, `M-E2-010` twin, `M-E1-008` twin | **WITHDRAWN** | `KILLED` header contradicts the pasted green tail; retained as raw records, not evidence (`AUDIT-ADJUDICATION.md`). |
| 2026-10-19 `M-E3-008`, `M-E4-004` | **SUPERSEDED** | Observed non-green output, but machine records stayed `pending`; new wave64 runs above supersede them. Original records/reports retained unchanged. |

## Explicit non-claims

- E3 is **not green**: 2/5 required mutants admitted.
- E4 is **not green**: 3/5 required mutants admitted.
- No mutation PASS is claimed for any family.
- No new kill is a model-site or core-copy kill; all are L-leg
  transliteration (`e3-cell`/`e4-cell`) proof-sensitivity kills.
- No SCR row is promoted. The E3/E4 cells remain partial.
