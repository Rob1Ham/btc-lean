# Notes — `e3-cms/C-L-cms-1of1`

- **repo_head:** `4d62a97e551082a69b13f495365bff0a903b0c99`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **contract:** v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
  (v2 `c2fcc67a…` was superseded during this work by the `error_enum.md`
  recipe fix; see `contract/CHANGELOG.md`. The final runs cite v3.)
- **result:** Alive2 green (4/4 functions, bidirectional), SAW green
  (16/16 proofs), behavioral match for checker 0 and 1. Bounded closed
  witnesses, 1-of-1 specialization, `coverage: partial`.
- **patches:** none. No commits were made; the worktree is uncommitted.

## Reproduce

From `/home/ubuntu/btc-lean-public/spec/equiv`:

```bash
./cells/e3-cms/C-L-cms-1of1/alive2/run.sh
./cells/e3-cms/C-L-cms-1of1/saw/run.sh
./cells/e3-cms/C-L-cms-1of1/behavior/run.sh
```

Certificates are repo-root relative; verify from
`/home/ubuntu/btc-lean-public`:

```bash
sha256sum -c spec/equiv/cells/e3-cms/C-L-cms-1of1/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/e3-cms/C-L-cms-1of1/saw/certificate.sha256
sha256sum -c spec/equiv/cells/e3-cms/C-L-cms-1of1/behavior/certificate.sha256
```

Observed terminal lines: `STATUS=alive2-green`, `STATUS=saw-green (16/16
proofs)`, `STATUS=behavior-match`.

Toolchain (recorded in the result headers and `build/build.txt`):

| Tool | Version |
|---|---|
| clang/clang++ | Ubuntu clang 20.1.2 (24.04.3) |
| LLVM (`llvm-link`, `llvm-dis`) | Ubuntu LLVM 20.1.2 |
| alive-tv | Ubuntu LLVM 20.1.2 (Alive2 v20.0) |
| SAW | 1.6 (`68eed5f release-1.6`) |
| Z3 | 4.8.12 |

## Artifact hashes (sha256)

| Artifact | sha256 |
|---|---|
| `spec.md` | `bce767c76e7474ec3993742424ca471be0e5b9ca387f01f49bc90d476ebef8ba` |
| `alive2/result.txt` | `b46498cfdeb7ca9a5c0fbb509c5b398a593edd7f2e44fa18885efc7bebdb7efd` |
| `alive2/certificate.sha256` | `d76cf23291abb23e0013ac3482ef32fb1bebbb47b0edbdf856a266225b301f88` |
| `saw/result.txt` | `44820114496acc7e615265564de7106bc350e8168adb2a3035221bb7292e7689` |
| `saw/certificate.sha256` | `b3e7cabed2993eb905c6f560bef396a71428e0a0b2dcdffa6a7e138889ff864e` |
| `behavior/result.txt` | `5ea0ff7410554c8349bf71a6917f70e0b43612413096149cef7b47fb3a2beb32` |
| `behavior/certificate.sha256` | `17273f14f5a00613be797fa74b26abfc525f56edc39fb0d2667db8774234ef38` |
| `build/build.txt` | `d88c95d25ec6a7189bf12fedf70782345043d57da82ae7c03e1397fac25a46c4` |

The certificates also pin the harness sources, `twin/ops_ir.py`,
`twin/gen.py`, `contract/error_kind.h`, the extracted per-function IR, the
linked SAW bitcode, the oracle scenarios, and the result file. All three
certificates were re-verified after the last run.

## Experiment design

### Observable and stack shape

One `uint64_t` per closed witness, packed as in
`cells/_tools/e3/cellsig/e3_common.h`: `result (2) | error ordinal (6) |
depth (3) | up to three (len 2, val 8)`. On failure only
`(result, error_kind)` is observable per `contract/ABI.md` v2, so both legs
pack an empty stack via `e3_fail`.

Base sigversion, flags 0. The witness stack is Core's CHECKMULTISIG layout
(bottom to top): `[dummy, sig, nSigs=1, pubkey, nKeys=1]` with a one-byte
signature `0x41`, one-byte pubkey `0x02`, and fixed scriptCode `0x4142`. All
four functions have this shape except `cell_cms_empty` (empty stack).

### Checker seam

Both legs declare and call exactly one external symbol:

```c
extern "C" uint8_t btc_equiv_check_sig(uint32_t sig, uint32_t pk,
                                       uint32_t script_code, uint32_t sigversion);
```

- **Alive2 lane:** bare declaration in both modules; equal arguments to the
  same external symbol return the same value, so Alive2 quantifies the ECDSA
  verdict. The harness deterministically adds `noundef` to the declaration on
  both extracted functions (`run_alive2.sh`). Rationale: a C `bool` return is
  never poison; without the annotation Alive2 admits a poison return and the
  L leg's branch on the verdict becomes UB while the C leg's `select` does
  not, yielding a spurious "source is more defined than target". This is a
  property of the seam, recorded as part of the same-crypto premise.
- **SAW lane:** one shared `checker_stub.cpp` compiled with
  `-DBTC_EQUIV_CHECKER_RESULT=0/1` and linked into both modules; each
  oracle-derived scenario is verified against both legs in the same build.

Element encoding at the seam is injective over `len <= 2`: bits 0–7 byte 0,
bits 8–15 byte 1, bits 16–23 length. Empty elements expose no payload bytes.

### Witnesses and 1-of-1 specialization

| Function | Checker | Stack / flags | Expected packed |
|---|---|---|---|
| `cell_cms` | 0 | 5 items, empty dummy, NULLDUMMY off | `0x108` |
| `cell_cms` | 1 | same | `0x2901` |
| `cell_cmsverify` | 0 | same, OP_CHECKMULTISIGVERIFY | `0x34` (ordinal 13) |
| `cell_cmsverify` | 1 | same | `0x2901` |
| `cell_cms_nulldummy` | — | dummy `<0x55>`, NULLDUMMY on | `0x70` (ordinal 28) |
| `cell_cms_empty` | — | empty stack | `0x48` (ordinal 18) |

`nSigs = nKeys = 1` is fixed by the harness; the L leg rejects other counts
with `TWIN_INVALID_UNSUPPORTED` and the C leg assumes the witness-fixed
counts, so values outside the 1-of-1 shape are outside the evidence domain.
`opCount` is not threaded in either leg (SCR-113/SCR-114 opcount arm not
covered).

The C leg (`c_cms.cpp`) is a line-cited slice of pinned `interpreter.cpp`,
specialized to the 1-of-1 stack. The L leg (`l_cms.cpp`) is a **reviewed
transliteration** of Lean `checkMultiSig` / `cmsLoop` / `cmsCleanup`; at this
repo_head `twin/ops_ir.py` has no CHECKMULTISIG handler (wires 0xae/0xaf map
to `OP_UNSUPPORTED_CHECKSIG`), so it is explicitly not generated by
`twin/gen.py`.

## Results

SAW counts 4 scenarios × 2 checker builds × 2 legs = 16 proofs. The
`behavior/` binary links both legs against one concrete stub per checker value
and matches the independent oracle; it is corroboration, not proof evidence.

`saw/result.txt` records 16/16 successful proofs with no failed proof. The
Alive2 lane records one green status per function; `cell_cms_empty` is
constant and reported `syntactically equal`, while the other three are
semantic proofs over the external checker verdict.

## Limitations and non-coverage

- **SCR-114** (`partial`): the depth underflow arm (ordinal 18) and the
  in-range 1-of-1 layout are covered. `nKeys < 0`, `nKeys > 20`,
  `nSigs > nKeys`, decodeNum errors, `opCount`, and multi-key/multi-sig
  layouts are not modeled.
- **SCR-118** (`partial`): unconditional dummy consumption after cleanup is
  proved for an empty dummy. A non-empty dummy with NULLDUMMY **off** is not
  exercised, so "contents unchecked" is only partially demonstrated.
- **SCR-119** (`partial`): NULLDUMMY on with a one-byte non-empty dummy
  returns ordinal 28. Empty dummy under the enabled gate is not separately
  exercised.
- **SCR-120** (`full` within this bounded cell): checker false returns
  CHECKMULTISIGVERIFY ordinal 13 exactly.
- Not covered at all: SCR-115 (FindAndDelete), SCR-116 (matching order /
  early exit), SCR-117 (per-pair encoding policy), SCR-110 (NULLFAIL), the
  legacy `nSigs = 0` shape, CODESEPARATOR, tapscript CHECKMULTISIG rejection.
- Bounded closed witnesses only: no symbolic stack bytes, element length <= 1,
  stack depth <= 5, bounded leaf generation (`--max-depth 6 --max-elem 2`).
- Nothing here proves ECDSA/secp256k1 agreement; the claim is conditional on
  both legs' checkers agreeing, per `docs/DECISION-lax-ecdsa.md`.

## R leg not attempted

The R leg is deliberately absent. The pinned rbitcoin shim has no typed
script-error surface and cannot express a CHECKMULTISIG cell under the E3
domain (`findings/cross/F-HARNESS-002-rbitcoin-boundary.md`: narrow error
map, single-input domain, flags = 0 only). Alive2 v20 also cannot ingest the
pinned rustc 1.95 / LLVM 22 R module
(`findings/tools/F-TOOL-001-alive2-llvm22.md`). No R green is claimed and no
error-enum equality involving R is asserted.

## Blockers and anomalies (honest record)

1. **Symbolic-argument formulation timed out.** The initial design used
   symbolic signature/pubkey bytes and an unbounded operand stack; Alive2
   returned `ERROR: Timeout` even with `--smt-to=100000`. The final cells are
   closed bounded witnesses whose only nondeterminism is the checker verdict.
   This is a scope reduction and is reflected in `coverage: partial`.
2. **Concurrent-agent artifact races.** A separate process repeatedly re-ran
   this cell and rewrote `build/`, `result.txt`, and certificates during
   development. One interleaved SAW run produced a spurious `22/16` count and
   one interleaved Alive2 run reported a CMSVERIFY mismatch; the shared
   `l_cms.cpp` was also observed temporarily at a foreign hash
   (`7aefca80...` instead of the reviewed `f775117e...`). Both anomalies were
   artifacts of clobbered inputs, not reproducible on stable sources.
   Mitigation: `run_alive2.sh`, `run_saw.sh`, and `run_behavior.sh` now take
   a per-cell `flock`; the final evidence was produced in one locked batch
   with the reviewed sources. All three certificates re-verify as of this
   writing.
3. **Harness bugs found and fixed** (earlier runs discarded): empty stack
   elements leaked a stale payload byte into L packing; the bounded stack
   arrays were too small for the 5-element CHECKMULTISIG layout (L
   `MAX_STACK_SIZE` raised 4 -> 6); and the checker-return `noundef`
   annotation was required to make the L branch on the verdict defined.

## Source citations

- `interpreter.cpp:1115-1225` — OP_CHECKMULTISIG / OP_CHECKMULTISIGVERIFY.
- `interpreter.cpp:1122-1124`, `1136-1138`, `1143-1145` — the three stack
  depth checks (all return `INVALID_STACK_OPERATION`).
- `interpreter.cpp:1140-1142` — `nSigs < 0 || nSigs > nKeys` (not modeled).
- `interpreter.cpp:1152-1160` — per-signature FindAndDelete (base only; the
  fixed scriptCode makes it a no-op here).
- `interpreter.cpp:1171-1174` — signature/pubkey encoding gates (flags 0).
- `interpreter.cpp:1177` — `checker.CheckECDSASignature` (the shared seam).
- `interpreter.cpp:1194-1205` — cleanup pops `i - 1` items, NULLFAIL arm off.
- `interpreter.cpp:1209-1212` — extra dummy item and the NULLDUMMY gate.
- `interpreter.cpp:1215-1223` — bool push and CHECKMULTISIGVERIFY ordinal 13.
- `interpreter.cpp:1876-1880` — EVAL_FALSE tail (cell finish harness).
- `spec/core/Bitcoin/Interpreter/Defs.lean:305-310` — `vchTrue`/`vchFalse`/
  `pushBoolV`.
- `spec/core/Bitcoin/Interpreter/Defs.lean:672-700` — `cmsLoop` (1-of-1 arm;
  loop exits after the single pair).
- `spec/core/Bitcoin/Interpreter/Defs.lean:702-718` — `cmsCleanup`
  (`nullFail = false`, pops `i - 1`).
- `spec/core/Bitcoin/Interpreter/Defs.lean:1071-1127` — `checkMultiSig`
  (dummy consumption and `checkMultiSigVerify` error arm).
- `spec/equiv/contract/error_kind.h:27,42,49,63` — `EVAL_FALSE=2`,
  `CHECKMULTISIGVERIFY=13`, `INVALID_STACK_OPERATION=18`,
  `SIG_NULLDUMMY=28`.
- `spec/db/rules.yaml` — SCR-114 through SCR-120.
- `docs/DECISION-lax-ecdsa.md` — same-crypto abstraction decision.
