# Notes — `e3-checksig/C-L-checksig-dispatch`

- **repo_head:** `4d62a97e551082a69b13f495365bff0a903b0c99`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **contract:** v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
  (v2 `c2fcc67a…` was superseded during this work by the `error_enum.md`
  recipe fix; see `contract/CHANGELOG.md`. The final runs cite v3.)
- **result:** Alive2 green (3/3 functions, bidirectional), SAW green
  (12/12 proofs), behavioral match for checker 0 and 1. Bounded closed
  witnesses, `coverage: partial`.
- **patches:** none. No commits were made; the worktree is uncommitted.

## Reproduce

From `/home/ubuntu/btc-lean-public/spec/equiv`:

```bash
./cells/e3-checksig/C-L-checksig-dispatch/alive2/run.sh
./cells/e3-checksig/C-L-checksig-dispatch/saw/run.sh
./cells/e3-checksig/C-L-checksig-dispatch/behavior/run.sh
```

Each lane regenerates its `result.txt` and `certificate.sha256`. Certificates
are repo-root relative; verify from `/home/ubuntu/btc-lean-public`:

```bash
sha256sum -c spec/equiv/cells/e3-checksig/C-L-checksig-dispatch/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/e3-checksig/C-L-checksig-dispatch/saw/certificate.sha256
sha256sum -c spec/equiv/cells/e3-checksig/C-L-checksig-dispatch/behavior/certificate.sha256
```

Observed terminal lines: `STATUS=alive2-green`, `STATUS=saw-green (12/12
proofs)`, `STATUS=behavior-match`.

Toolchain (recorded in the result headers and `build/build.txt`):

| Tool | Version |
|---|---|
| clang/clang++ | Ubuntu clang 20.1.2 (24.04.3) |
| LLVM (`llvm-extract`, `llvm-dis`) | Ubuntu LLVM 20.1.2 |
| alive-tv | Ubuntu LLVM 20.1.2 (Alive2 v20.0) |
| SAW | 1.6 (`68eed5f release-1.6`) |
| Z3 | 4.8.12 |

## Artifact hashes (sha256)

| Artifact | sha256 |
|---|---|
| `spec.md` | `7e296e22dd386afdb1ea883898aa08e95bdf84cf159f9090c160bc3b8b6cd6d6` |
| `alive2/result.txt` | `414037203d982619e22bb05a8c56ae35076ebb4cc35d3a34ea2cd6855eabe212` |
| `alive2/certificate.sha256` | `14717ff35fc14e41d2cb2c87c4173b4ed5e811b548dce4f84038324d38c2f0bc` |
| `saw/result.txt` | `a4ea788e3ee86ccedbe4ae3df50d6edfb87e536fb66dbb345f337683f69e7e14` |
| `saw/certificate.sha256` | `14c841bb6e94dcd53b2a16659b341ca72fd96f2f58e0478136cc7ac459606d71` |
| `behavior/result.txt` | `faf97504d509715efe96ead8d616bbf404eb17be5e886aedab2e9b78c0b806ef` |
| `behavior/certificate.sha256` | `43237578225cc00932847e89e6897f5624ee552cffa288fb9b60c0d8bb3e5ce8` |
| `build/build.txt` | `fa1a8318c64a50527eefe34ccae5db4f7a6fc820fd3619dcec6a7cef90d9b4b3` |

The certificates also pin the harness sources, `twin/ops_ir.py`,
`twin/gen.py`, `contract/error_kind.h`, the extracted per-function IR, and
the result file. All three certificates were re-verified after the last run.

## Experiment design

### Observable

One `uint64_t` per closed witness, packed as in `cells/_tools/e3/cellsig/e3_common.h`:
`result (2) | error ordinal (6) | depth (3) | up to three (len 2, val 8)`.
Per `contract/ABI.md` v2, on failure only `(result, error_kind)` is observable,
so both legs pack an empty stack via `e3_fail` (Core mutates its stack before
returning false; the Lean `Except` error carries no state).

### Checker seam

Both legs declare and call exactly one external symbol:

```c
extern "C" uint8_t btc_equiv_check_sig(uint32_t sig, uint32_t pk,
                                       uint32_t script_code, uint32_t sigversion);
```

- **Alive2 lane:** bare declaration in both modules. Equal arguments to the
  same external symbol return the same value; Alive2 quantifies the verdict.
  The harness deterministically rewrites
  `declare zeroext i8 @btc_equiv_check_sig` to
  `declare noundef zeroext i8 @btc_equiv_check_sig` on both extracted
  functions before comparison. Rationale: a C `bool` return is never poison;
  without the annotation Alive2's uninterpreted-call model admits a poison
  return, and the branch in the L leg (but not the C leg's `select`) would
  become UB, producing a spurious "source is more defined than target".
  This transform is in `cells/_tools/e3/cellsig/run_alive2.sh` and is part of
  the same-crypto seam premise.
- **SAW lane:** one `checker_stub.cpp` compiled twice with
  `-DBTC_EQUIV_CHECKER_RESULT=0/1` and linked into **both** modules. Each
  oracle-derived scenario is verified against both legs in the same build.

Element encoding at the seam is injective over `len <= 2`: bits 0–7 byte 0,
bits 8–15 byte 1, bits 16–23 length. Empty elements expose no payload bytes.

### Witnesses

`cell_checksig` (stack `[<0x41>, <0x02>]`, OP_CHECKSIG),
`cell_checksigverify` (same stack, OP_CHECKSIGVERIFY then harness OP_1), and
`cell_checksig_underflow` (`[<0x41>]`). Sigversion BASE, flags 0, fixed
two-byte scriptCode `0x4142`, no CODESEPARATOR. The only nondeterminism is
the checker verdict.

The C leg (`c_checksig.cpp`) is a line-cited slice of pinned
`interpreter.cpp`. The L leg (`l_checksig.cpp`) is a **reviewed
transliteration** of Lean `stepBody`/`evalChecksigPreTapscript`; at this
repo_head `twin/ops_ir.py` has no CHECKSIG handler, so it is explicitly not
generated by `twin/gen.py`.

## Results

| Function | Checker | Alive2 | SAW | Expected packed |
|---|---|---|---|---|
| `cell_checksig` | 0 | green | green | `0x108` |
| `cell_checksig` | 1 | green | green | `0x2901` |
| `cell_checksigverify` | 0 | green | green | `0x38` (ordinal 14) |
| `cell_checksigverify` | 1 | green | green | `0x2901` |
| `cell_checksig_underflow` | — | green (syntactically equal) | green | `0x48` (ordinal 18) |

SAW counts 3 scenarios × 2 checker builds × 2 legs = 12 proofs. The
`behavior/` binary links both legs against one concrete stub per checker value
and matches the independent oracle; it is corroboration, not proof evidence.

Per-function Alive2 input hashes are recorded in `alive2/result.txt`. The
underflow function is branchless and constant on both sides; Alive2 reports
`syntactically equal`, which is a valid (if weak) equivalence for that
witness. The other two functions are semantic proofs over the external
checker verdict.

## Limitations and non-coverage

- SCR-112 only at `partial`: the cell proves the push-false / continue
  mechanism and verdict passthrough conditional on the checker returning
  false. It does not prove that real ECDSA returns false for an invalid
  pubkey, and does not model DER/LOW_S/STRICTENC/WITNESS_PUBKEYTYPE policy.
  SCR-109 is not assigned here: the signature is the non-empty byte `0x41`;
  the narrow `checksig/C-L-checksig-empty` fallback attempts the empty-sig
  arm, and SCR-109 remains a gap.
- Not covered: SCR-113 (sigop/OP_COUNT), SCR-110 (NULLFAIL), FindAndDelete /
  CONST_SCRIPTCODE (SCR-098/099/100/101), CODESEPARATOR, hashtype
  passthrough (SCR-111), tapscript CHECKSIGADD, stack-size limits.
- Bounded closed witnesses only: no symbolic stack bytes, element length <= 1,
  stack depth <= 3, bounded leaf generation (`--max-depth 6 --max-elem 2`).
- Nothing here proves ECDSA/secp256k1 agreement; the claim is conditional on
  both legs' checkers agreeing, per `docs/DECISION-lax-ecdsa.md`.

## R leg not attempted

The R leg is deliberately absent, not silently skipped. The pinned rbitcoin
shim has no typed script-error surface and cannot express CHECKSIG under the
E3 domain (`findings/cross/F-HARNESS-002-rbitcoin-boundary.md`: narrow error
map, single-input domain, flags = 0 only). Separately, Alive2 v20 cannot
ingest the pinned rustc 1.95 / LLVM 22 R module
(`findings/tools/F-TOOL-001-alive2-llvm22.md`: LLVM 22 `dead_on_return`
attribute and unsupported metadata kind 8). No R green is claimed and no
error-enum equality involving R is asserted.

## Blockers and anomalies (honest record)

1. **Symbolic-argument formulation timed out.** An earlier design passed
   symbolic signature/pubkey bytes and an unbounded operand stack. Alive2
   returned `ERROR: Timeout` even with `--smt-to=100000`. The cell was reduced
   to closed bounded witnesses where the checker verdict is the sole
   nondeterminism. This is a scope reduction, not a proof of the larger
   formulation.
2. **Concurrent-agent artifact races.** Another process repeatedly re-ran
   this cell's scripts and rewrote `build/`, `result.txt`, and certificates
   while this work was in progress. At one point the shared harness file
   `cells/_tools/e3/cellsig/l_cms.cpp` was observed with a foreign hash
   (`7aefca80...` instead of the reviewed `f775117e...`), which produced a
   transient CMS failure and stale checksig certificates. Mitigation: the
   harness scripts now serialize per-cell runs with
   `flock "$CELL_DIR/.e3.lock"`, and the final evidence was produced in a
   single locked batch with the sources at the hashes listed in the
   certificates. All six certificates re-verify as of this writing. If a
   foreign process later rewrites the cell, the certificates will fail and
   the run must be repeated; the hashes above are the reference.
3. **Harness bugs found and fixed during development** (recorded because they
   affected earlier, discarded runs): empty stack elements leaked a stale
   payload byte into the L packing; the bounded stack arrays were too small
   for the 5-element CHECKMULTISIG layout (L `MAX_STACK_SIZE` raised from 4
   to 6); and the checker-return `noundef` annotation described above was
   required for the CMS branch.

## Source citations

- `interpreter.cpp:331-369` — `EvalChecksigPreTapscript` (checker call 349,
  NULLFAIL 351–352).
- `interpreter.cpp:397-413` — `EvalChecksig` dispatch.
- `interpreter.cpp:1069-1092` — OP_CHECKSIG / OP_CHECKSIGVERIFY (underflow
  1073–1074, verdict push 1082, CHECKSIGVERIFY error 1088).
- `interpreter.cpp:1876-1880` — EVAL_FALSE tail (cell finish harness).
- `spec/core/Bitcoin/Interpreter/Defs.lean:305-310` — `vchTrue`/`vchFalse`/
  `pushBoolV`.
- `spec/core/Bitcoin/Interpreter/Defs.lean:720-742` —
  `evalChecksigPreTapscript`.
- `spec/core/Bitcoin/Interpreter/Defs.lean:784-791` —
  `evalChecksigDispatch`.
- `spec/core/Bitcoin/Interpreter/Defs.lean:1033-1047` — `stepBody` CHECKSIG
  arm.
- `spec/equiv/contract/error_kind.h:27,43,49` — `EVAL_FALSE=2`,
  `CHECKSIGVERIFY=14`, `INVALID_STACK_OPERATION=18`.
- `spec/db/rules.yaml` — SCR-109, SCR-110, SCR-112, SCR-113.
- `docs/DECISION-lax-ecdsa.md` — same-crypto abstraction decision.
