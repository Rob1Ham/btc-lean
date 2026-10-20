# Orchestrator cross-checks (independent of role reports)

Run 2026-10-19 against the working tree and the role clones. These are
reviewer-style checks: they verify artifacts produced by roles without
editing them.

## V1 — Core pin

```sh
git -C /tmp/opencode/equiv-work/bitcoin rev-parse HEAD
# cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
git -C /tmp/opencode/equiv-work/bitcoin describe --tags --always
# cce32b1
```

Matches `PINS.lock`'s Core pin. **PASS.**

## V2 — shared error enum equals Core's at the pin

Parsed `src/script/script_error.h` (`typedef enum ScriptError_t`) and compared
each `SCRIPT_ERR_X` ordinal with `contract/error_kind.h`'s `EQUIV_ERR_X`.

```
Core count: 56   header count: 56   mismatches: 0
```

Including `EQUIV_ERR_ERROR_COUNT = 55` (the sentinel). **PASS** — the Core
shim can pass `ScriptError` through with no translation table.

Consequence: the twin must map its internal `TwinErr` onto these ordinals at
the harness boundary. It currently does not (`TWIN_EVAL_FALSE = 14` vs Core
`2`). Handoff `orchestrator-to-TWIN-001-twin-domain.md` is open.

## V3 — twin Lean anchors and four op semantics

Spot-checked against `spec/core/Bitcoin/Interpreter/Defs.lean`:

| Twin anchor | Lean line | Match |
|---|---|---|
| `OP_NOP` `Defs.lean:856` | 856 `if w = 0x61 then .ok st` | yes |
| `OP_VERIFY` `Defs.lean:901-904` | 901-904, underflow then `castToBool`/`verifyFailed` | yes |
| `OP_DROP` `Defs.lean:954-956` | 954-956, underflow then `stack.tail` | yes |
| `OP_DUP` `Defs.lean:957-959` | 957-959, `topAt st.stack 1 :: st.stack` | yes |
| `OP_SWAP` `Defs.lean:983-987` | 983-987, `b :: a :: drop 2` | yes |

Semantics in `twin/gen.py` for these four ops match the Lean equations
(head = top, index 0 = bottom; SWAP exchanges the two entries). **PASS for the
four emitted ops**; this is not a claim about the rest.

## V4 — twin consumable domain is empty in the pinned corpus

```sh
# over spec/equiv/corpus/selections/*.jsonl
stack   n=316  empty_scriptSig=50  flags_empty=42  both=0
flow    n=297  empty_scriptSig=24  flags_empty=2   both=1
numeric n=335  empty_scriptSig=7   flags_empty=69  both=0
hash    n=115  empty_scriptSig=0   flags_empty=4   both=0
checksig n=90  empty_scriptSig=1   flags_empty=38  both=0
cms     n=117  empty_scriptSig=57  flags_empty=18  both=1
locktime n=21  empty_scriptSig=2   flags_empty=0   both=0
witness n=134  empty_scriptSig=63  flags_empty=0   both=0
taproot n=7    empty_scriptSig=7   flags_empty=0   both=0
```

The twin's current domain (empty scriptSig ∧ flags == 0) intersects the
corpus in **2 rows out of 1258** (one flow, one CMS) — and zero stack rows.
**FAIL for corpus reach.** Blocking handoff filed TWIN-001.

## V5 — ABI signature ambiguity

`contract/ABI.md` §1 shows a 7-argument `entry`; §2 says `error_kind` is an
"optional out-parameter". `twin/gen.py` emits both `twin_entry` (8 args) and a
7-arg `entry`. E3's error-enum equality needs the out-parameter, so "optional"
is the wrong default. Handoff CONTRACT-001 filed.

## V7 — R leg pin, entry points, error surface

Read-only from `/tmp/opencode/equiv-work/rbitcoin`:

```sh
git rev-parse HEAD        # ae47aa98174e04d0d8c493f13041daf65e4ac1d3
cat rust-toolchain.toml   # channel = "1.95.0"
grep -n "mod script" crates/rbitcoin-consensus/src/lib.rs   # 12:mod script;
grep -n verify_job_all_inputs crates/rbitcoin-consensus/src/script/mod.rs
# 50: pub(crate) fn verify_job_all_inputs
```

- Pin is a commit, not a tag (`git describe` = `ae47aa9`). It must be
  recorded verbatim; it is the R pin.
- Public script API is tx-level (`verify_tx_scripts_with_flags`) and runs on a
  detached worker thread. The single-input verifier is `pub(crate)`.
- Script failures are `ConsensusError::Script(String)` (e.g. `"SIG_DER"`),
  not Core ordinals.
- `Cargo.lock` has `secp256k1` 0.28.2 and 0.29.1 (rust-bitcoin 0.32.102,
  default features) — same libsecp256k1 C family as Core; exact-version
  comparison is required for the same-crypto premise.
- `script-oracle/verify.cpp` is a **Core** oracle wrapper, not an rbitcoin
  shim. It returns accept/reject only (no error kind), so it cannot serve as
  the contract shim unchanged.

Handoff `orchestrator-to-RUST-IR-001-entry-and-errors.md` is open.

## V8 — R toolchain × tool matrix (executed, 2026-10-19)

A trivial Rust leaf (`add_one(x: i32) = x wrapping_add 1`) was compiled with
three installed toolchains and loaded into both tools:

| rustc | LLVM | Alive2 v20.0 | SAW 1.6 |
|---|---|---:|---:|
| 1.88.0 | 20.1.5 | PASS | PASS |
| **1.95.0** | **22.1.2** | **PASS** | **PASS** |
| 1.99.0 | 23.1.1 | PASS | FAIL (bitstream) |

**Chosen:** rustc 1.95.0, exactly rbitcoin's `rust-toolchain.toml` pin.
SAW consumes bitcode, not text `.ll`; raw rustc bitcode needs no
normalization. rustc 1.99 (host default) must not be used — SAW fails before
solving. Artifacts and reproduction:
`findings/verifications/artifacts/rust-hello/`.

An earlier note in this file (and the first PINS.lock edit) said "SAW needs
LLVM ≤ 20". That was wrong: it came from loading a textual `.ll` into SAW.
Corrected here; `PINS.lock [rbitcoin]` now records 1.95.0.

## V9 — Core IR feature census and tool limits (executed)

Core interpreter IR (`/tmp/opencode/equiv-work/ir/interpreter-O0.ll`,
clang 20.1.2, `-O0`, 1026 functions):

| function | instrs | invoke | landingpad | ptrtoint | indirect calls |
|---|---:|---:|---:|---:|---:|
| `EvalScript(... ScriptExecutionData ...)` | 3138 | 336 | 32 | 0 | 5 |
| `VerifyScript` | 588 | 58 | 6 | 0 | 0 |
| `VerifyWitnessProgram` | 440 | 35 | 1 | 0 | 0 |
| `CheckSignatureEncoding` | 121 | 0 | 0 | 0 | 0 |
| `CScriptNum::set_vch` | 57 | 0 | 0 | 0 | 0 |
| `CastToBool` | 48 | 0 | 0 | 0 | 0 |

The five indirect calls in `EvalScript` are the virtual `BaseSignatureChecker`
calls; the invoke/landingpad edges are `scriptnum_error` (and friends).

Tool experiment (`findings/verifications/artifacts/tool-limits/`):

| feature | Alive2 v20.0 | SAW 1.6 |
|---|---|---|
| C++ try/catch/throw (`invoke`/`landingpad`) | **hard error**: "Could not translate to Alive IR" | loads; **proves** under a precondition that prunes the throw path |
| indirect call, self-refinement, `--always-verify` | 1 correct, 0 errors | needs an override (not tested here) |
| `ptrtoint`/`inttoptr`, self-refinement, `--always-verify` | 1 correct, 0 errors | not tested |

SAW also caught a genuine `nsw` signed-overflow in the test function at
`x = INT_MAX`; that is UB evidence, not an equivalence failure.

**Consequences:** E5's whole-function path is SAW-first. Exceptions do not by
themselves force a residual; a residual is for behavior SAW cannot model
(e.g. dynamic dispatch without an override). Alive2 is for leaf cells, not
`EvalScript`/`VerifyScript`. The documented blanket "no ptrtoint / no
function pointers" is too strong for v20 on trivial shapes — re-test per cell,
never assume.

## V6 — tool hello-worlds are real

`findings/tools/{alive2-hello,alive2-hello-bad,saw-hello,saw-hello-nsw-poison}.out`
contain genuine run logs: Alive2 reports 2 correct / 0 incorrect for the
equivalent pair and a value-mismatch counterexample for `add + 2`; SAW proves
`id32`/`add_one` and catches the `nsw` poison with counterexample
`x = 2147483647`. **PASS** (these are E0 tool smoke tests, not engine cells).

## V10 — contract v2 and real E0 gate (current state)

- `contract/ABI.md` is now **v2**: normative `equiv_entry` with a mandatory
  `equiv_error_kind*`, plus a non-proof-bearing 7-argument `entry` wrapper.
  This agrees with `contract/tape.md` §1, `contract/error_enum.md`,
  `error_kind.h` (`EQUIV_ABI_VERSION == 2`), and all three shim sources.
- Contract hash recomputed over `ABI.md + tape.md + error_kind.h +
  corpus_schema.md`:

  ```
  f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
  ```

  `PINS.lock [contract]` records it. `make pins` now reports only
  `[core] build` and `[rbitcoin] build` as TODO (artifact hashes pending
  clean builds); every other pin is filled.
- `make e0` was a presence check. It now executes the real triple:
  `tools/e0.sh` → `tools/run_e0.py --strict-e0` →
  `tools/tests/e0-triple.sh` → `tools/tests/e0_triple.py`. The runner builds
  real `TX_WITH_WITNESS` tapes, calls ABI v2 via ctypes, and prints
  `E0_TRIPLE_OK` only if all three legs agree with the expected
  `(result, error_kind)`.
- Actual result at this checkpoint: tool probes **GREEN**; C green on all four
  tapes (`OP_1` pass, `OP_0` EVAL_FALSE, `OP_RETURN`, empty-tx bad input);
  L and R are `(3, UNKNOWN)` stubs. `make e0` exits 2 with
  `E0_TRIPLE_PENDING`. This is the honest E0 state; the triple is **not**
  claimed green.

## V11 — trust defects found and handed off

1. **Core IR was built by clang 18.1.3, not the pinned clang 20.1.2.**
   `interpreter-O0.ll` carries `Ubuntu clang version 18.1.3`. It is
   non-proof; no cell may cite it. Handoff
   `orchestrator-to-CORE-IR-001-clang-pin.md`.
2. **The rbitcoin clone is dirty at the pin.** `git status --porcelain`
   shows 4 modified/added files (+247 lines: an `equiv-ffi` feature and
   `script/ffi.rs`), not registered in `patches/`. A build from that tree
   silently includes an unregistered patch. Handoff
   `orchestrator-to-RUST-IR-003-no-unregistered-patch.md`; `patches/README.md`
   now states that R engine changes are not authorized for official artifacts
   and that a dirty tree cannot inherit the pin.
3. **The CONTRACT smoke link used test-only `FileCommit`/`TruncateFile`
   stubs.** The C library's behavior on the four E0 tapes is real, but it is
   not yet the proof build; CORE-IR must link real Core objects (recorded in
   the handoff).
4. **Alive2 exits 0 on a failing transformation** (TOOLS finding). Gates must
   parse `incorrect transformations` / `Alive2 errors`, never the exit code.
   `run_e0.py` already parses output.
5. **R toolchain matrix corrected:** rustc 1.95.0 (rbitcoin's own pin) passes
   both Alive2 and SAW; rustc 1.99.0 fails SAW. See V8 and
   `findings/verifications/artifacts/rust-hello/`.

