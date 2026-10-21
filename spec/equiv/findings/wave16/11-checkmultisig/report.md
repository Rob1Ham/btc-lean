# Wave 16 / `11-checkmultisig` — CHECKMULTISIG (SCR-114 … SCR-121)

- **Branch:** `wave16/11-checkmultisig`, cut from `805c8042f92d3bed909ca40219a4d21fc9150cc1`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **Contract:** v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **Family:** `spec/equiv/cells/checkmultisig/`
- **Patches:** `none` in every cell
- **Pushes:** none (local commit only)

## Row dispositions

| Row | Claim | Cell | Coverage |
|---|---|---|---|
| SCR-114 | nKeys∈[0,20], nSigs∈[0,nKeys], depth checks | `C-L-cms-layout-sym` | **full** (both tools green) |
| SCR-115 | all nSigsCount sigs FindAndDelete'd before any check (BASE) | `C-L-cms-fad-probe` | **partial** |
| SCR-116 | sigs to keys in order; early fail when sigs>keys remain | `C-L-cms-order-unroll` | **partial** |
| SCR-117 | CheckSignatureEncoding+CheckPubKeyEncoding inside loop | `C-L-cms-enc-loop` | **partial** |
| SCR-118 | extra stack item consumed unchecked | `C-L-cms-tail-sym` | **full** (both tools green) |
| SCR-119 | dummy must be ∅ (cons. post-SegWit) | `C-L-cms-tail-sym` | **full** (both tools green) |
| SCR-120 | false ⇒ CHECKMULTISIGVERIFY error | `C-L-cms-tail-sym` | **full** (both tools green) |
| SCR-121 | CMS banned in tapscript | `C-L-cms-tapscript-ban` | **full** (both tools green) |

**Rows both-tool green with full coverage: 5** — SCR-114, SCR-118, SCR-119,
SCR-120, SCR-121.
**Rows partial: 3** — SCR-115, SCR-116, SCR-117.
**Gap/seam rows with a blocking IR feature: 0** in this family; the three
partials are bounded/abstracted, not blocked.

## Cells and evidence

Each cell has `src/{c,l}_*.cpp`, `alive2/{run.sh,result.txt,certificate.sha256}`,
`saw/{run.sh,spec.saw.in,model.cry,result.txt,certificate.sha256}`,
`spec.md`, `notes.md`, and a generated `build/`.  All four green-cell
certificate files verify with `sha256sum -c` from the repository root; the
generated `build/` is intentionally untracked (repository convention), so the
certificates pin the IR produced by the runners and were re-verified in the
final worktree after the last run.

| Cell | Function | Alive2 | SAW | Coverage reason |
|---|---|---|---|---|
| `C-L-cms-layout-sym` | `cell_cms_layout` | green, 1/1 bidirectional | green, 2 proofs / 1 case | decisive decision function, all arms symbolic |
| `C-L-cms-tapscript-ban` | `cell_cms_tapscript_ban` | green, 1/1 | green, 2 proofs / 1 case | ban + non-tapscript negative |
| `C-L-cms-tail-sym` | `cell_cms_tail` | green, 1/1 | green, 2 proofs / 1 case | tail general over counts/fSuccess/dummy |
| `C-L-cms-order-unroll` | `cell_cms_order` | green, 1/1 | green, 10 proofs / 5 cases | nKeys ≤ 4 unroll |
| `C-L-cms-enc-loop` | `cell_cms_enc` | green, 1/1 | green, 12 proofs / 6 cases | 2 pairs; validators abstract |
| `C-L-cms-fad-probe` | `cell_cms_fad` | green, 1/1 | green, 4 proofs / 2 cases | nSigs ≤ 2; FindAndDelete abstract |

Total: 6 cells, 12 tool lanes, 32 SAW proofs across 16 stub cases.

### What each cell actually proves

- **SCR-114 (full).**  `cell_cms_layout(nKeys, nSigs, stackSize, opCount)`
  reproduces Core's front-matter precedence (depth → nKeys range → opCount →
  key depth → nSigs range → sig depth → ok) over fully symbolic int32/u32
  inputs and returns the derived `ikey2 = nKeys+2` / `isig = nKeys+3`.
  Precondition: the two count elements are already decoded (decodeNum is not
  part of the row).
- **SCR-121 (full).**  `sigversion == TAPSCRIPT` returns ordinal 50 before any
  arity/range work; BASE and WITNESS_V0 still walk the front matter, so
  "reject everything" is not accepted.
- **SCR-118/119/120 (full).**  The post-loop tail is general over
  `nKeys`, `nSigs`, `extra`, `fSuccess`, the NULLDUMMY switch, both opcodes,
  and empty/non-empty dummies.  `dummyBytes` is a free input absent from every
  oracle RHS; only `dummyLen` enters the NULLDUMMY gate.  A false `fSuccess`
  under `OP_CHECKMULTISIGVERIFY` returns ordinal 13; under `OP_CHECKMULTISIG`
  it pushes false and the script-end tail is EVAL_FALSE (2).
- **SCR-116 (partial).**  The loop trace (keys examined, matched mask, early
  exit, fSuccess) is proved for `nKeys ≤ 4` with the checker uninterpreted
  (Alive2) and for five concrete match relations (SAW).  Missing: the
  remaining 16 keys of Core's `MAX_PUBKEYS_PER_MULTISIG = 20` domain.
- **SCR-117 (partial).**  Per-pair gate order/precedence/latch and the
  checker-not-called-after-a-gate-error property are proved for two pairs.
  Missing: 18 more bodies, and the concrete BIP66/BIP62 policy (the validators
  are abstract shared symbols; `flags = 0`).
- **SCR-115 (partial).**  The pre-loop `for k in 0..nSigs-1` fold, the BASE-only
  gate, the `found > 0 && CONST_SCRIPTCODE` latch (ordinal 54), and the
  scriptCode handed to every checker call are proved for `nSigs = nKeys ≤ 2`.
  Missing: the byte-walking FindAndDelete algorithm itself (SCR-098/INV-056),
  which is a shared abstract seam symbol here, and 18 more signatures.

## Trust notes

- **Same crypto.**  Every cell that reaches a check calls the one external
  `btc_equiv_check_sig` with the same four arguments in both legs.  Alive2
  ingests a bare declaration in both modules and quantifies over the checker;
  the harness deterministically adds `noundef` to the extracted declaration on
  both sides (a C bool return is never poison).  SAW links one concrete stub
  instance per case.  Nothing here proves ECDSA/secp256k1 agreement; the claim
  is conditional on the two checkers agreeing, per
  `docs/DECISION-lax-ecdsa.md`.
- **Encoding validators (SCR-117)** are a second shared abstraction, with
  `flags` fixed at 0.  The cell proves placement/order/error propagation, not
  DERSIG/LOW_S/STRICTENC content.
- **FindAndDelete (SCR-115)** is a third shared abstraction.  The cell proves
  the fold order, BASE gate and error latch; the GetOp-walking deletion is
  SCR-098/INV-056 and is not claimed.
- C legs are line-cited slices of the pinned `interpreter.cpp`; L legs are
  reviewed transliterations of `spec/core/Bitcoin/Interpreter/Defs.lean`
  (`checkMultiSig`, `cmsLoop`, `cmsCleanup`).  `twin/gen.py` generated none of
  them (`twin/ops_ir.py` has no CHECKMULTISIG handler at this repo head).
  No Core patch is used.

## Reproduce

```sh
cd /tmp/opencode/wave16/11-checkmultisig
for c in C-L-cms-layout-sym C-L-cms-tapscript-ban C-L-cms-tail-sym \
         C-L-cms-order-unroll C-L-cms-enc-loop C-L-cms-fad-probe; do
  bash spec/equiv/cells/checkmultisig/$c/alive2/run.sh
  bash spec/equiv/cells/checkmultisig/$c/saw/run.sh
  sha256sum -c spec/equiv/cells/checkmultisig/$c/alive2/certificate.sha256
  sha256sum -c spec/equiv/cells/checkmultisig/$c/saw/certificate.sha256
done
```

Observed terminal lines: `STATUS=alive2-green` in all six `alive2/result.txt`
and `STATUS=saw-green (2|10|12|4 proofs, …)` in the six `saw/result.txt`.

## Toolchain

| Tool | Version |
|---|---|
| clang/clang++ | Ubuntu clang 20.1.2 (0ubuntu1~24.04.3) |
| LLVM (`llvm-extract`, `llvm-link`, `llvm-dis`) | Ubuntu LLVM 20.1.2 |
| alive-tv | Alive2 v20.0 (Ubuntu LLVM 20.1.2) |
| SAW | 1.6 (`68eed5f release-1.6`) |

## Harness

The family harness is copied into `spec/equiv/cells/checkmultisig/_shared/`
(`cms_obs.h`, `cms_seam.h`, `checker_stub.cpp`, `build_ir.sh`,
`run_alive2.sh`, `run_saw.sh`) rather than added to `cells/_tools/`, per the
wave's scope rule.  Both runners build from source on every run; `spec.md` and
`notes.md` are hashed by the certificates, so the final tool runs were made
after the final spec/notes edits.

## Blockers and anomalies

- **No tool/infrastructure blocker.**  Alive2 ingested every module; SAW
  proved every case.  Both tools are the pinned absolute binaries.
- The only "blocking IR feature" style limits are the deliberate unroll
  bounds and abstract seams listed above; nothing is filed as an infra
  blocker.
- Anomalies found and fixed during development (details in each `notes.md`):
  the tail packer's error shift (`<<2` vs `<<1`), the enc cell's
  bodies-entered field (mask vs count), the fad oracle's error-path script
  update and probe suppression, and the shared certificate path depth
  (`_shared/../../..`, not `../../../..`, to reach `spec/equiv`).  None of the
  discarded runs are in the committed evidence.

## Files changed

Only these paths are new:

```
spec/equiv/cells/checkmultisig/_shared/...
spec/equiv/cells/checkmultisig/C-L-cms-{layout-sym,tapscript-ban,tail-sym,
    order-unroll,enc-loop,fad-probe}/...
spec/equiv/findings/wave16/11-checkmultisig/report.md
```

No shared ledger, results, docs, contract, twin, shims, or `_tools` file was
edited.
