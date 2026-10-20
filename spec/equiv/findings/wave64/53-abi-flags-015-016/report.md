# Wave 64 — independent audit of SCR-015/SCR-016 flag-derivation cells

**Agent:** wave64 agent `53-abi-flags-015-016`
**Worktree:** `/tmp/opencode/wave64/53-abi-flags-015-016`
**Branch:** `wave64/53-abi-flags-015-016` (base `5946c02`)
**Integration HEAD audited:** `5946c024546e39f55775bfd9a077b042e3feeef4`
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (v32.99)
**Contract hash:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
(recomputed from `contract/ABI.md`, `tape.md`, `error_kind.h`,
`corpus_schema.md`, `error_enum.md`)
**Tools:** clang/LLVM 20.1.2, Alive2 v20.0 (`/usr/local/bin/alive-tv` →
`/opt/equiv-tools/alive-tv-v20.0`), SAW 1.6 (`68eed5f`)

## Cells audited

| SCR | cell | claimed |
|---|---|---|
| SCR-015 | `spec/equiv/cells/exec-verify/C-L-w32-block-flags` | `GetBlockScriptFlags` for every 256-bit hash × uint32 height, mainnet |
| SCR-016 | `spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions` | two-entry exception map (fail-closed), full height schedules, named block words |

Both were promoted from `gap` to `both-green` in `0686996` and are
`both-green` in `spec/db/equiv-cells.yaml` at the audited HEAD.

## Verdict

**PASS for the proved function; two documentation/scope overclaims, no
semantic or tool defect.**

The flag derivation that the cells state is faithful to the pinned Core
source.  I reproduced both tools byte-for-byte, verified all four
certificates, and built an independent differential oracle from the pinned
Core tree: **278,033 comparisons, zero mismatches**, plus **49/49** cases from
the separate in-repo L2-ACT hash-keyed oracle.  Negative controls at the
library, Alive2, and SAW levels all caught an injected off-by-one, so the
proofs are not vacuous.

The cells are *not* contract-tape/ABI cells: `equiv_entry` has no height or
block-hash channel and receives `flags` as a caller input
(`contract/ABI.md:17-22`).  The cells prove a block-level selector, with a
hand-written C source slice and a hand transliteration as the two legs — no
compiled pinned Core, no R leg.  (The Rust shim's current domain is
`flags == 0`, `shims/rust/entry.rs:86-95`, so it cannot accept the words
these cells derive even if a caller supplied them.)  That is disclosed in
every trust note, but it is not visible in the ledger's `both-green` status.
Treat the result as function-level C-slice ≡ L-transliteration evidence, not
as tape-level coverage.

## 1. Reproduction (real tools, this worktree)

All four documented runners were executed; each exited 0:

```sh
spec/equiv/cells/exec-verify/C-L-w32-block-flags/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-block-flags/saw/run.sh
spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/saw/run.sh
```

The regenerated `result.txt` transcripts are **byte-identical** to the
committed/ledger ones:

| cell | leg | sha256(result.txt) | ledger value | status |
|---|---|---|---|---|
| `C-L-w32-block-flags` | alive2 | `737d257184d8cdd376755ae6c816a4d2ff0a733a50f87c1a8c4043b58ba04db3` | `737d257184d8cdd376755ae6c816a4d2ff0a733a50f87c1a8c4043b58ba04db3` | `alive2-green` |
| `C-L-w32-block-flags` | saw | `b04f4031c0a81288fb1ba924b0ec3f1e40b8463975f6d9fcb986558980864449` | `b04f4031c0a81288fb1ba924b0ec3f1e40b8463975f6d9fcb986558980864449` | `saw-green` |
| `C-L-w32-flag-exceptions` | alive2 | `191ef720ed01065f24a1b70c8270a2651b0f693ab78a94f2047cc0514d6e14f2` | `191ef720ed01065f24a1b70c8270a2651b0f693ab78a94f2047cc0514d6e14f2` | `alive2-green` |
| `C-L-w32-flag-exceptions` | saw | `e01c25dcf888657be32616b14a954172c4034b4accc12cef8a5b92a3adbea843` | `e01c25dcf888657be32616b14a954172c4034b4accc12cef8a5b92a3adbea843` | `saw-green` |

All four `certificate.sha256` manifests verify from the repository root
(12, 14, 20, 22 lines `OK`; transcripts in `evidence/*-check.txt`).  Tool
identity is correct: `alive-tv` is the PINS binary (same sha256), SAW reports
`1.6 (68eed5f release-1.6)`.

Gate status (from this worktree):

* `PINS.lock`: OK.
* SCR coverage: 183/183 adjudicated; 143 both-green / 38 gap / 2 seam.
* Certificate section: the *global* gate is red, but all 224 failures are
  pre-existing `stack-ops/C-L-pick` certificates that hash ignored
  `build-*/` artifacts; the two audited cells are not mentioned in the gate
  output at all.  This is out of scope for this audit (see `evidence/gate-coverage.txt`).
* `results/scripts/update_ledger.py --check`: ledger is up to date.
* `results/scripts/coverage_report.py --strict`: PASS (183 adjudicated).

## 2. Independent differential check

New harness: `check_flags_diff.py` (this directory).  It does **not** read
the cell's transcribed constants from `w32_common.h`.  It parses the expected
semantics from the pinned Core tree at run time:

* `src/kernel/chainparams.cpp` — the two `CMainParams` exception hashes and
  flag payloads, plus `BIP65Height/BIP66Height/CSVHeight/SegwitHeight`;
* `src/validation.cpp` — base set, REPLACE ordering, and the four
  `DeploymentActiveAt` ORs (shape and order are asserted);
* `src/script/interpreter.h` — flag ordinals, so bit values are
  `1 << ordinal` exactly as `verify_flags.h` defines them.

It compiles `c_flags.cpp` and `l_flags.cpp` with clang-20 into shared
objects and compares the C leg, the L leg, and the model over:

* every single-bit flip of both exception hashes (512 cases), plus limb-edge
  patterns;
* 4,000 random 256-bit hashes and the 0/1/2²⁵⁵/2²⁵⁶−1 edges;
* every buried height ±1 (and ±0), `0`, `1`, `2³¹`, `2³²−2`, `2³²−1`, and 500
  random heights, crossed with hash samples on both axes;
* the `*_at` schedules over all height vectors and the two closed named
  wrappers;
* the contract flag domain: `flags & ~0x1fffff == 0`, `WITNESS ⇒ P2SH`,
  `CLEANSTACK ⇒ P2SH ∧ WITNESS` (`contract/tape.md` §5).

Result (`flags-audit.json`):

```
comparisons:              278033
mismatches:               0
abi_domain_violations:    0
negative controls:        both caught
named:                    bip16@170060 = 0x0; taproot@692261 = 0xe15
L2-ACT class E cases:     49/49 agree
verdict:                  PASS
```

The model-source files are recorded by sha256 in `flags-audit.json`
(`chainparams.cpp`, `validation.cpp`, `interpreter.h`), so the audit is
re-runnable against the same pin.

### Independent in-repo oracle

`spec/data/l2/act/cases.jsonl` comes from a different workstream
(`L2ActMirror.py`, a "verbatim-cited transliteration, NO Lean reuse").  Its
class-E rows are hash-keyed and supply the hash selector, so they are
directly comparable.  All 49 class-E cases agree with the model and both
legs, including:

* `170060` + BIP16 hash → `0000000` (= `0x0`);
* `692261` + taproot hash → `1111110` (= `0xe15`);
* all the `+1/-1` and up-to-`2³²−1` schedules for both hashes.

### Negative controls (not vacuous)

1. **Library level** (`check_flags_diff.py`): a C leg built with
   `BIP66_HEIGHT = 363726` is caught at height 363725; an L leg with one
   BIP16 hash limb flipped is caught by `cell_exc_select`.
2. **Alive2 level**: C leg vs L leg with `BIP66_HEIGHT = 363726` reports
   `Transformation doesn't verify! ERROR: Value mismatch`, counterexample
   `height = 363725` (`evidence/alive2-mutation-height.txt`).
3. **SAW level**: C leg vs a `spec.cry` with the DERSIG threshold changed to
   363726 reports `Proof failed` with counterexample `height: 363725`
   (`evidence/saw-mutation-height.txt`).

## 3. Row coverage

### SCR-015 — `GetBlockScriptFlags` (validation.cpp:2249-2288)

Verified against the pinned function:

* base `P2SH|WITNESS|TAPROOT` (`flags{...}`, line 2259-2261);
* `script_flag_exceptions.find(hash)` → `flags = it->second;` (REPLACE,
  2262-2265); mainnet has exactly the two entries;
* DERSIG / CLTV / CSV / NULLDUMMY OR-ed after the replacement with
  `nHeight >= DeploymentHeight(dep)` (2266-2285; `deploymentstatus.h:27-31`,
  `params.h:140-157`).

The cell covers every branch and edge of that function, including the
fail-closed lookup and both sides of each of the four height comparisons.
The named claims are confirmed by the independent model and the L2 oracle.

**Gap in the row, not the function:** the row summary's final clause
“Scripts and costs use actual candidate flags” is caller wiring
(ConnectBlock / TXV-055), not part of `core_ref` validation.cpp:2249-2288.
`spec.md` lines 29-36 explicitly say the cell does not claim it.  The Lean
capstone target `BitcoinProofs.Theorems.CapstoneSigops.validateBlock_script_flags`
does cover the wiring at the Lean level, but that is outside this cell and
outside the tape ABI.  The ledger entry carries `status: both-green` with
`gap_note: null`, so a reader of `equiv-cells.yaml` alone does not see this
qualification.

### SCR-016 — two named exception blocks

* `mainnetExceptionMap` has exactly the two entries and is fail-closed for
  every other 256-bit hash; the payloads are `NONE` and `P2SH|WITNESS`.
* At any height, the BIP16 hash never regains P2SH/WITNESS/TAPROOT; the
  taproot hash never regains TAPROOT.
* Named words: `0x0` at height 170060 and `0xe15` at 692261.  Both are
  independently reproduced by the L2 class-E cases and the Core-source
  model.

The hash↔height pairs are not re-derived from block headers in the cell;
they come from `spec/core/Bitcoin/Activation/Flags.lean:42-57` /
`research/w2-06-flags-activation.md` §2.2 (external explorer check
2026-10-16).  The cell explicitly says so.  That external data is a real
dependency of the closed `*_named` witnesses; it is not missing context for
the symbolic map/schedule proofs.

## 4. Findings

| id | severity | finding | recommendation |
|---|---|---|---|
| A1 | **minor / scope overclaim** | The ledger's `both-green` for SCR-015/SCR-016 is not tape/ABI-level evidence.  `equiv_entry` has no height or hash input, and the C leg is a hand-written slice, not compiled pinned Core; the L leg is a hand transliteration.  `cells/README.md:31-32` says a precondition should be a subset of the tape domain, which these are not.  The trust notes disclose this, the ledger does not. | Add a scope note (e.g. `gap_note` or a matrix column) saying “function-level, out-of-tape; C/L are reviewed transcriptions; no R leg”.  Do not count these rows as contract-level three-leg coverage. |
| A2 | **minor / wording** | SCR-015 `scr_row_coverage: full` (spec.md:29) is immediately qualified by “this cell does not claim that wiring”, yet the word `full` and the ledger's green status are what downstream readers see.  The row's application clause is covered only by the Lean capstone target, not by this cell. | Change to “full for core_ref validation.cpp:2249-2288; the caller/application clause is outside the cell (Lean capstone target only)”.  Optionally add the same clause to the ledger note. |
| A3 | **minor / reproducibility** | The checked-in `certificate.sha256` files are *normalized* (`tools/normalize_certificates.py`), not the runner output.  Re-running the documented `run.sh` rewrites them into the raw runner format (they include `build/*.ll` and lose `notes.md`/`saw/*` entries).  The audit restored the committed files.  All hashes still verify, but “run.sh reproduces the committed certificate” is false as written. | After `run.sh`, run `python3 tools/normalize_certificates.py` before checking in, or make the runner emit the normalized set. |
| A4 | **informational** | `repo_head` in both `spec.md` files is `4d62a97e…`, a commit on `docs/hornet-attribution`, not an ancestor of the integration HEAD `5946c02`.  A reviewer cannot check out that state from this branch.  All 141 cells share this convention (`805c804…` / `4d62a97…`). | Record the integration HEAD at promotion time, or make the field “authoring head (may be pre-integration)”. |
| A5 | **informational** | `direction:` lists `L ⊑ C` and `C ⊑ L`, but `run_alive2.sh` invokes `alive-tv c.ll l.ll` once (no `--bidirectional`).  For these total, UB-free, deterministic functions one-direction refinement already implies equality, and the SAW leg proves both C and L equal the same total Cryptol spec, so both directions are discharged.  The Alive2 transcript alone is not bidirectional. | Optional: add `--bidirectional` for uniformity with cells that already use it. |

No finding changes the truth of the proved function.  A1/A2 are the only
places where the published status can be read as claiming more than the
cells establish.

## 5. Reproduction

```sh
# from the worktree root, pinned Core tree at /tmp/opencode/core-pin
python3 spec/equiv/findings/wave64/53-abi-flags-015-016/check_flags_diff.py \
        --json spec/equiv/findings/wave64/53-abi-flags-015-016/flags-audit.json

# tool-level reproduction
spec/equiv/cells/exec-verify/C-L-w32-block-flags/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-block-flags/saw/run.sh
spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/alive2/run.sh
spec/equiv/cells/exec-verify/C-L-w32-flag-exceptions/saw/run.sh
for c in C-L-w32-block-flags C-L-w32-flag-exceptions; do
  for leg in alive2 saw; do
    sha256sum -c spec/equiv/cells/exec-verify/$c/$leg/certificate.sha256
  done
done
```

`--core-src` may point at any checkout of the pin.  The script fails loudly
if the Core function shape, the two-entry map, or the ordering check does not
match the pin.

## 6. Files added by this audit (no shared edits)

```
spec/equiv/findings/wave64/53-abi-flags-015-016/
  report.md
  check_flags_diff.py
  flags-audit.json
  evidence/alive2-mutation-height.txt
  evidence/saw-mutation-height.txt
  evidence/C-L-w32-block-flags-alive2-check.txt
  evidence/C-L-w32-block-flags-saw-check.txt
  evidence/C-L-w32-flag-exceptions-alive2-check.txt
  evidence/C-L-w32-flag-exceptions-saw-check.txt
  evidence/gate-coverage.txt
  evidence/run-stdout.json
```

No cell, ledger, contract, pin, or result file was modified.  The four
certificates rewritten by the reproduction runs were restored with
`git checkout --` before this commit.
