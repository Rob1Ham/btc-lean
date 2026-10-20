# E3 report — CHECKSIG / CHECKMULTISIG bounded C-L cells

**Status:** two cells delivered, both green in Alive2 and SAW on bounded
closed witnesses; coverage is explicitly `partial`.
**Date:** 2026-10-19
**repo_head:** `4d62a97e551082a69b13f495365bff0a903b0c99`
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
(v2 `c2fcc67a…` was superseded during this work by the `error_enum.md`
recipe fix; see `contract/CHANGELOG.md`. The cell specs and final runs cite v3.)
**Tools:** Alive2 v20.0 (LLVM 20.1.2), SAW 1.6 (`68eed5f`), Z3 4.8.12,
clang 20.1.2.
**Patches:** none. **Commits:** none.

This workstream ran only its own cell runners. It did not run `make equiv`,
`make gate-ir-pin`, or any mutation.

## Deliverables

| Cell | Family | SCR rows | Alive2 | SAW | Behavior | Coverage |
|---|---|---|---|---|---|---|
| `cells/e3-checksig/C-L-checksig-dispatch` | checksig | SCR-112 | green (3/3) | green (12/12) | match | partial |
| `cells/e3-cms/C-L-cms-1of1` | checkmultisig | SCR-114, SCR-118, SCR-119, SCR-120 | green (4/4) | green (16/16) | match | partial |

Both cells use the shared external checker symbol
`btc_equiv_check_sig(sig, pk, script_code, sigversion)` in both legs.

### Evidence files and hashes (sha256)

| Artifact | sha256 |
|---|---|
| checksig `spec.md` | `7e296e22dd386afdb1ea883898aa08e95bdf84cf159f9090c160bc3b8b6cd6d6` |
| checksig `alive2/result.txt` | `414037203d982619e22bb05a8c56ae35076ebb4cc35d3a34ea2cd6855eabe212` |
| checksig `alive2/certificate.sha256` | `14717ff35fc14e41d2cb2c87c4173b4ed5e811b548dce4f84038324d38c2f0bc` |
| checksig `saw/result.txt` | `a4ea788e3ee86ccedbe4ae3df50d6edfb87e536fb66dbb345f337683f69e7e14` |
| checksig `saw/certificate.sha256` | `14c841bb6e94dcd53b2a16659b341ca72fd96f2f58e0478136cc7ac459606d71` |
| checksig `behavior/result.txt` | `faf97504d509715efe96ead8d616bbf404eb17be5e886aedab2e9b78c0b806ef` |
| checksig `behavior/certificate.sha256` | `43237578225cc00932847e89e6897f5624ee552cffa288fb9b60c0d8bb3e5ce8` |
| CMS `spec.md` | `bce767c76e7474ec3993742424ca471be0e5b9ca387f01f49bc90d476ebef8ba` |
| CMS `alive2/result.txt` | `b46498cfdeb7ca9a5c0fbb509c5b398a593edd7f2e44fa18885efc7bebdb7efd` |
| CMS `alive2/certificate.sha256` | `d76cf23291abb23e0013ac3482ef32fb1bebbb47b0edbdf856a266225b301f88` |
| CMS `saw/result.txt` | `44820114496acc7e615265564de7106bc350e8168adb2a3035221bb7292e7689` |
| CMS `saw/certificate.sha256` | `b3e7cabed2993eb905c6f560bef396a71428e0a0b2dcdffa6a7e138889ff864e` |
| CMS `behavior/result.txt` | `5ea0ff7410554c8349bf71a6917f70e0b43612413096149cef7b47fb3a2beb32` |
| CMS `behavior/certificate.sha256` | `17273f14f5a00613be797fa74b26abfc525f56edc39fb0d2667db8774234ef38` |

All six certificates were re-verified from `/home/ubuntu/btc-lean-public`
with `sha256sum -c` after the final locked run. Each certificate covers the
cell `spec.md`, the lane script, the private harness sources, `twin/` inputs,
`contract/error_kind.h`, generated IR/bitcode, oracle scenarios, and the
result file. `notes.md` in each cell records commands, tool versions, design,
and limitations.

## What was proved

### CHECKSIG cell

Three closed witnesses, sigversion BASE, flags 0, fixed scriptCode
`0x4142`, no CODESEPARATOR. The checker verdict is the only
nondeterminism Alive2 quantifies; SAW pins it to 0 and 1 in two builds.

| Function | Checker | Packed observable | Meaning |
|---|---|---|---|
| `cell_checksig` | 0 | `0x108` | push `{}`; EVAL_FALSE=2 |
| `cell_checksig` | 1 | `0x2901` | push `{1}`; pass |
| `cell_checksigverify` | 0 | `0x38` | CHECKSIGVERIFY=14 |
| `cell_checksigverify` | 1 | `0x2901` | pass |
| `cell_checksig_underflow` | — | `0x48` | INVALID_STACK_OPERATION=18 |

### CHECKMULTISIG cell (1-of-1)

Four closed witnesses, stack `[dummy, sig, nSigs=1, pubkey, nKeys=1]`
(except the empty arm). Cleanup and dummy pops follow Core; the checker
verdict is again the only nondeterminism.

| Function | Checker | Packed observable | Meaning |
|---|---|---|---|
| `cell_cms` | 0 | `0x108` | push `{}`; EVAL_FALSE=2 |
| `cell_cms` | 1 | `0x2901` | push `{1}`; pass |
| `cell_cmsverify` | 0 | `0x34` | CHECKMULTISIGVERIFY=13 |
| `cell_cmsverify` | 1 | `0x2901` | pass |
| `cell_cms_nulldummy` | — | `0x70` | SIG_NULLDUMMY=28 |
| `cell_cms_empty` | — | `0x48` | INVALID_STACK_OPERATION=18 |

### Error-enum equality observed

| Path | Ordinal | Evidence |
|---|---:|---|
| failed CHECKSIG, script tail | `EVAL_FALSE = 2` | `0x108` |
| OP_CHECKSIGVERIFY false | `CHECKSIGVERIFY = 14` | `0x38` |
| failed CHECKMULTISIG, script tail | `EVAL_FALSE = 2` | `0x108` |
| OP_CHECKMULTISIGVERIFY false | `CHECKMULTISIGVERIFY = 13` | `0x34` |
| non-empty dummy + NULLDUMMY | `SIG_NULLDUMMY = 28` | `0x70` |
| empty stack / underflow | `INVALID_STACK_OPERATION = 18` | `0x48` |

Both legs agree on every value in both checker builds. This is error-map
equality **on the modeled branches only**; it is not a proof that Core and
Lean share a complete error taxonomy.

## Design notes that matter to the claim

- **Same crypto.** Both legs call one external symbol; Alive2 treats equal
  calls to the same declaration as equal, and SAW links one stub into both
  modules. Nothing proves ECDSA/secp256k1 agreement; the claim is conditional
  per `docs/DECISION-lax-ecdsa.md`.
- **`noundef` checker return.** `run_alive2.sh` deterministically annotates
  the external declaration as `noundef` on both extracted functions. A C
  `bool` return is never poison; without it, Alive2's uninterpreted-call
  model admits a poison verdict and the L leg's branch becomes UB while the
  C leg's `select` does not, producing a spurious "source is more defined
  than target" failure (observed on CMS).
- **Closed witnesses.** `result | error<<2 | depth<<8 | element fields` is
  the ABI v2 observable. On failure both legs pack an empty stack, because
  the ABI exposes only `(result, error_kind)` and the Lean `Except` carries
  no state. Elements are encoded injectively for `len <= 2`, and empty
  elements expose no payload.
- **L legs are reviewed transliterations.** At this repo_head
  `twin/ops_ir.py` has no CHECKSIG/CHECKMULTISIG handler (wires 0xac/0xad and
  0xae/0xaf map to `OP_UNSUPPORTED_CHECKSIG`). `l_checksig.cpp` and
  `l_cms.cpp` were written and reviewed against the Lean equations; they are
  **not** generated by `twin/gen.py`.

## Coverage, honestly

- **SCR-112 (partial).** Proves the push-false/continue mechanism and verdict
  passthrough conditional on the checker returning false. Does not prove
  pubkey validity/encoding or the STRICTENC/WITNESS_PUBKEYTYPE policy arms.
- **SCR-109 (not assigned here).** The checksig-dispatch cell uses the
  non-empty signature `0x41`; the narrow `checksig/C-L-checksig-empty`
  fallback attempts the empty-signature arm. SCR-109 remains a gap.
- **SCR-114 (partial).** Depth underflow and the in-range 1-of-1 layout are
  covered; `nKeys/nSigs` ranges, `nSigs > nKeys`, decode errors, opcount, and
  multi-key layouts are not.
- **SCR-118 (partial).** Dummy consumption is proved for an empty dummy; a
  non-empty dummy with NULLDUMMY off is not exercised.
- **SCR-119 (partial).** NULLDUMMY rejection is proved for one non-empty
  dummy; empty dummy with the gate on is not separately exercised.
- **SCR-120.** CHECKMULTISIGVERIFY false returns ordinal 13 exactly, within
  the bounded 1-of-1 domain.
- **Not covered at all:** SCR-113 (sigop/opcount), SCR-110 (NULLFAIL),
  SCR-115 (FindAndDelete), SCR-116 (matching order / early exit), SCR-117
  (per-pair encoding policy), SCR-098..101 (FindAndDelete/CONST_SCRIPTCODE/
  CODESEPARATOR), SCR-111 (hashtype), tapscript CHECKSIGADD and
  CHECKMULTISIG rejection.
- No row is marked `full`. These are bounded closed witnesses, not
  whole-engine `EvalScript`/`VerifyScript` proofs.

## R leg: not attempted (explicit)

The R leg is absent by decision, not by omission:

- **F-HARNESS-002** (`findings/cross/F-HARNESS-002-rbitcoin-boundary.md`):
  the pinned rbitcoin public entry has no typed script error, maps only a
  narrow set of tokens, accepts a single-input domain, and rejects
  `flags != 0`. It cannot express these cells or their error enums.
- **F-TOOL-001** (`findings/tools/F-TOOL-001-alive2-llvm22.md`): Alive2 v20
  cannot ingest the pinned rustc 1.95 / LLVM 22 module (`dead_on_return`
  parameter attribute; unsupported metadata kind 8).

No R result, R green, or three-way error-enum equality is asserted here.

## Proposed mutations (NOT executed by this workstream)

These are the next checks for a redteam runner. They are listed, not run; no
source file was modified for them by this workstream.

1. **Invert the checker verdict in the L leg.** Change
   `btc_equiv_check_sig(...) != 0` to `== 0` in
   `cells/_tools/e3/cellsig/l_checksig.cpp` and `l_cms.cpp`. Expected:
   Alive2 reports a value mismatch on every checker-dependent witness (the
   `0x2901` / `0x108` cases invert; failure ordinals differ), and SAW fails
   the corresponding proofs. A verdict-only cell that does not carry the
   checker into both legs would miss this.
2. **Wrong CHECKSIGVERIFY ordinal.** Return ordinal 11
   (`EQUIV_ERR_VERIFY`) instead of 14 on the false path of
   `l_checksig.cpp`. Expected observable `0x2c` vs `0x38`: Alive2 mismatch
   on `cell_checksigverify` and SAW counterexample; the other witnesses stay
   green. This tests error-enum equality specifically.
3. **Wrong NULLDUMMY ordinal.** Return 32 (`EQUIV_ERR_SIG_NULLFAIL`)
   instead of 28 in the NULLDUMMY arm of `l_cms.cpp`. Expected observable
   `0x80` vs `0x70`: Alive2 mismatch on `cell_cms_nulldummy` and SAW
   counterexample, with the other three CMS witnesses green.

A fourth, harness-level check is to remove the `noundef` rewrite from
`run_alive2.sh`; it is expected to reproduce the CMS "source is more defined
than target" artifact and demonstrates that the seam premise is load-bearing.
It is not a source mutation.

## Concurrent/external activity (provenance)

Another process sharing this workspace ran a redteam mutant
`M-E3-008` against `l_cms.cpp` at 23:01 and wrote
`cells/_redteam/runs/M-E3-008-e3-cell-20261019T230115Z.md`; it reports a kill
(Alive2 mismatch on `cell_cmsverify`, SAW 11/16) and a verified revert to the
reviewed hash `f775117e...`. This workstream did not invoke that runner and
does not rely on its result as primary evidence, but the episode explains
transient failures seen while the mutant and restored sources were being
swapped underneath concurrent builds.

Because of that race, the three harness runners now serialize per cell with
`flock "$CELL_DIR/.e3.lock"`. The final evidence above was produced in one
locked batch on the reviewed sources and its certificates re-verify.

## Reproduce and verify

```bash
cd /home/ubuntu/btc-lean-public/spec/equiv
./cells/e3-checksig/C-L-checksig-dispatch/{alive2,saw,behavior}/run.sh
./cells/e3-cms/C-L-cms-1of1/{alive2,saw,behavior}/run.sh

cd /home/ubuntu/btc-lean-public
for c in spec/equiv/cells/e3-checksig/C-L-checksig-dispatch/{alive2,saw,behavior}/certificate.sha256 \
         spec/equiv/cells/e3-cms/C-L-cms-1of1/{alive2,saw,behavior}/certificate.sha256; do
  sha256sum -c "$c" || exit 1
done
```

An earlier concurrent draft of this report is preserved verbatim as
`findings/e3/report.orchestrator-draft.md`. It references an older contract
identifier and lists SCR-116 for the CMS cell; this report supersedes it for
the bounded-1-of-1 evidence actually in the two cells.

---

## Orchestrator addendum — mutation and E6 integration

The E3 role itself did not run a mutation. The orchestrator then executed
`M-E3-008` against `cells/_tools/e3/cellsig/l_cms.cpp` (the E3 CMS reviewed
transliteration): baseline Alive2 green / SAW 16/16; mutant Alive2 not-green
on `cell_cmsverify` (source `0x34` = CHECKMULTISIGVERIFY 13, target `0x18` =
a different error) and SAW 11/16; source restored to
`f775117e523eed92cb5ffb91c598e468505667c2c272b24624eacbd7ab89fb41`;
baseline green again. Full run:
`cells/_redteam/runs/M-E3-008-e3-cell-20261019T230115Z.md`.

The two cells are integrated in the current ledger as **partial**:
`e3-checksig` lists SCR-112 and `e3-cms` lists SCR-114/118/119/120, with
`scr_row_coverage: partial`; no E3 row is green. `make equiv` reports both
cells green at the tool level, and no R proof cell exists (`F-TOOL-001`).
