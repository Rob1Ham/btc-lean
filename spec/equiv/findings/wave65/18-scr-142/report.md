# Wave 65 / 18 — SCR-142: TAPROOT gate and the 709632 clause

**Branch:** `wave65/18-scr-142`
**Base:** `76dbfe5e42f8a337e41a7308158b0de078afafd9` (`equiv/llvm-three-leg`, PR #29)
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (Bitcoin Core v32.99)
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Row:** SCR-142 — *TAPROOT gate: with the flag, a v1-32 non-P2SH spend is
not anyone-can-spend; without the flag it succeeds silently only
pre-activation (height 709632, except block 692261)*
**Status of this work:** new finding + finding-scoped model probe. **No row
promotion.** Ledger cell count, `spec/db/**`, `results/**`, `contract/**`,
`PINS.lock`, `spec/proofs/**` and all existing cells are untouched.

---

## 1. Verdict

The row is **two different claims**, and only one of them is a property of
the pin:

| clause | at `cce32b168` | evidence |
|---|---|---|
| with TAPROOT, a v1-32 non-P2SH spend is not anyone-can-spend | **true** and already both-green | existing `cells/tapscript/C-L-taproot-gate` and `…-activation-gate` |
| without TAPROOT it succeeds silently | **true** and already both-green | same cells |
| “**only pre-activation** (height 709632, except 692261)” | **NOT a property of the pin** — precise inapplicability | this finding (`compare/`) |

The earlier gap note is **right about the outcome but wrong about the
blocker**. The blocker is *not* that the tape lacks a height/hash channel:
cell-local ABIs are permitted, and the existing activation-gate cell already
carries `height` and the block hash. The blocker is that **no C source at the
pin contains a TAPROOT height term to transliterate**:

- `validation.cpp:2261`: `script_verify_flags flags{SCRIPT_VERIFY_P2SH |
  SCRIPT_VERIFY_WITNESS | SCRIPT_VERIFY_TAPROOT};` — unconditional.
- `validation.cpp:2262-2265`: the only clear is the hash-keyed
  `script_flag_exceptions` lookup.
- `consensus/params.h:38-44`: `DeploymentPos` has only `TESTDUMMY`.
- `kernel/chainparams.cpp:125`: 709632 survives only in the
  `MinBIP9WarningHeight = 711648; // taproot activation height + …` comment.
- `interpreter.cpp:1959`: `if (!(flags & SCRIPT_VERIFY_TAPROOT))` — a flag
  test, never a height test.

So adding `block_height`/`block_hash` to a **cell-local** ABI is sound and
sufficient for the *channel*; it does not and cannot supply the missing
*source term*. A C leg that turns TAPROOT off at 709631 is a **model choice**,
not Bitcoin Core behaviour at this pin. This finding makes that distinction
machine-checked instead of asserting it.

**Result: precise inapplicability at the pin for the historical height
clause; the row remains `gap`. The only sound row-closing path is a second
pin (§6, R1).**

---

## 2. Can height/hash be added to the cell-local ABI?

**Yes, soundly, without touching `contract/tape.md`.** The probe uses:

```
cell_model_taproot(h0, h1, h2, h3, height,
                   version, program_len, is_p2sh, witness_n)
```

`h0..h3` are the block hash as four 64-bit limbs (equality only; the limb
grouping is representation), `height` is `uint32`. This is a cell-local ABI,
not a new tape version. The existing `C-L-taproot-activation-gate` cell
already did the same thing, which is why “the tape has no height” was never
the real obstacle for a cell.

What changes when the channel exists is *what you can write down*:

- **Pinned leg** (the only C behaviour at the pin): `height` is present, real
  (it drives the four buried ORs), and **inert for TAPROOT**.
- **Model leg** (historical): `taproot_on = (709632 <= height)` away from the
  hash-keyed exception, per `Activation/Taproot.lean` TPR-078.

Both are representable. Only the second is the row's historical sentence.
Therefore the channel resolves *representability*, not *provenance*.

---

## 3. Machine-checked result

Two real tools, raw logs tracked.

### 3.1 Model well-formedness (`model-cell/`)

Two independent transcriptions of TPR-075/076/078 — a bitmask C-shaped leg
and a Bool-record/Option L-shaped leg — against one cell-local ABI:

```
Alive2 --bidirectional : correct / equivalent
                         1 correct, 0 incorrect, 0 Alive2 errors
SAW (abc)              : 2/2 Proof succeeded
STATUS=alive2-green (model-only)
STATUS=saw-green (2/2 proofs, model-only)
```

This is **not** evidence about `cce32b168`; it proves the model is
well-formed and the ABI works.

### 3.2 Pin vs model (`compare/`) — the actual result

One symbol `cell_compare`, six fixed-context builds, five `alive-tv
--bidirectional` pairs. Expected outcome stated before the run; raw
counterexamples retained.

| pair | context | Alive2 | meaning |
|---|---|---|---|
| A | pin @709631 vs pin @709632 | **EQUIV** | the pin's TAPROOT observable is height-inert |
| B | model @709631 vs model @709632 | **DIFF** | the model's gate is live (non-vacuity) |
| C | pin @709632 vs model @709632 | **EQUIV** | agreement at activation |
| D | pin @709631 vs model @709631 | **DIFF** | **the exact missing term** |
| E | pin @exception hash @692261 vs model same | **EQUIV** | agreement at the exception block |

```
STATUS=probe-as-expected (2 equivalence pairs, 2 inequivalence pairs, 1 exception pair)
RESULT=pin_has_no_height_term; model_has_709632_gate; they_agree_at_709632_and_at_exc692261
```

Raw pair-B counterexample (trimmed; full text in `compare/alive2/result.txt`):

```
Transformation doesn't verify!
ERROR: Value mismatch
Source value: #x0000000000000003 (3)      <- model @709631: TAPROOT off
Target value: #x0000000000000103 (259)    <- model @709632: TAPROOT on
```

Pair-D is the row-critical one: **pinned C @709631 = `0x103`; model @709631 =
`0x003`** — they differ by exactly the TAPROOT bit. Pair-A plus the SAW
height-free predicate (`compare/saw/`) prove the pin cannot be moved to the
model by a height input.

### 3.3 Concrete witness (`behavior/`)

```
non-exc h=709631 wn=0   pin=0x19c  model=0x001  DIFF
non-exc h=709631 wn=2   pin=0x102  model=0x001  DIFF
non-exc h=709632 wn=0   pin=0x19c  model=0x19c  SAME
non-exc h=709632 wn=2   pin=0x102  model=0x102  SAME
taproot exc h=692261    pin=0x001  model=0x001  SAME
bip16 exc  h=170060     pin=0x001  model=0x001  SAME
```

Witness only; the proofs are §3.1–3.2.

---

## 4. Model choice vs Core behaviour (explicit)

- The `model-cell/` legs are transcribed from the **historical Lean record**
  `spec/core/Bitcoin/Activation/Taproot.lean` (TPR-075 minActivation 709632,
  TPR-076 hash-keyed exception, TPR-078 `deploymentActiveAt`). They are not a
  slice of any pinned C file.
- The row's `lean_target`
  `verifyWitnessProgram_taproot_gate_silent_ok`
  (`spec/core/Bitcoin/Interpreter/Rules.lean:374-381`) proves exactly the
  **flag-off branch** given `flags.taproot = false`. It does **not** model
  activation, height, or who sets the flag. `rules.yaml`'s `status: proven`
  is about that theorem, not about the 709632 clause.
- Even the historical Core did not implement the clause as a bare height
  compare: `DeploymentActiveAt` for a `DeploymentPos` is
  `versionbitscache.IsActiveAfter(pindex.pprev, …)`
  (`deploymentstatus.h:26-31`). 709632 is the **observed mainnet activation
  height**, and TPR-078 is already a height abstraction of that state
  machine. A model using `709632 <= height` is therefore a *threshold model of
  the observed chain outcome*, one abstraction above the historical Core
  function. This is stated so the model is not mistaken for a historical
  `GetBlockScriptFlags` transliteration.

---

## 5. Why this is an inapplicability, not a failed proof

A proof of the row's historical clause at this pin would require one of:

1. a pinned C function that reads height and clears TAPROOT below 709632 —
   **does not exist at `cce32b168`**; or
2. a C leg written by hand from the row — that is inventing source, and any
   “equivalence” would compare the invention with itself; or
3. a second pin whose `DeploymentPos` contains `DEPLOYMENT_TAPROOT` — the
   only option that yields **Core** behaviour (§6 R1).

Option 1 is factually false; option 2 is a model (§3.1/§4); option 3 is out
of scope for this worktree (it changes `PINS.lock`, the contract pin, and the
ledger's pin provenance). Hence the precise statement is:
**the clause is inapplicable at the pin, and the row cannot be greened by any
cell-local ABI addition alone.**

This refines `cells/tapscript/C-L-taproot-activation-gate/GAP-CONTEXT.md`,
which lists both the missing tape channel and the missing function. The tape
channel is now demonstrated to be non-blocking (and was already bypassed by
that cell); the missing function is decisive.

---

## 6. Residual

| id | residual | owner |
|---|---|---|
| **R1** | Row coverage needs a **second pin**: a BIP341-era Core tree with `Consensus::DEPLOYMENT_TAPROOT` (`bit 2`, `min_activation_height = 709632`) and a C leg built from that tree's `GetBlockScriptFlags`/`DeploymentActiveAt`. That cell must carry its own pin and must not be presented as `cce32b168`. | future wave + pin owner |
| **R2** | Even with R1, BIP9 activation is a **versionbits state machine** (`IsActiveAfter`), not a raw `height >= 709632`. The cell must either model the state machine or fix the chain state (the observed `ACTIVE` at 709632) and say which. TPR-078 is the height abstraction; do not silently promote it to Core behaviour. | R1 cell |
| **R3** | SCR-142 stays `gap` with the existing pinned-half cell plus this finding. No `spec/db/**` edit was made, so the ledger is unchanged by design. | ledger owner |
| **R4** | The model's coverage of the non-TAPROOT flags is deliberately minimal: only the TAPROOT term is historical; P2SH/WITNESS and the buried ORs are the pin's. A historical-pin cell must re-derive the whole flag word from that tree. | R1 cell |

---

## 7. Evidence: exact commands, certificates, hashes

```sh
cd /tmp/opencode/wave65/18-scr-142
bash spec/equiv/findings/wave65/18-scr-142/model-cell/alive2/run.sh
bash spec/equiv/findings/wave65/18-scr-142/model-cell/saw/run.sh
bash spec/equiv/findings/wave65/18-scr-142/compare/alive2/run.sh
bash spec/equiv/findings/wave65/18-scr-142/compare/saw/run.sh
bash spec/equiv/findings/wave65/18-scr-142/behavior/run.sh
sha256sum -c spec/equiv/findings/wave65/18-scr-142/model-cell/alive2/certificate.sha256
sha256sum -c spec/equiv/findings/wave65/18-scr-142/model-cell/saw/certificate.sha256
sha256sum -c spec/equiv/findings/wave65/18-scr-142/compare/alive2/certificate.sha256
sha256sum -c spec/equiv/findings/wave65/18-scr-142/compare/saw/certificate.sha256
sha256sum -c spec/equiv/findings/wave65/18-scr-142/behavior/certificate.sha256
```

Tool versions (from the logs): Alive2 `Ubuntu LLVM version 20.1.2`
(`/usr/local/bin/alive-tv`), SAW `1.6 (68eed5f release-1.6)`, solver `abc`,
`clang++-20 20.1.2`, `llvm-extract` 20.1.2.

Certificate digests:

```
model-cell/alive2/certificate.sha256  2effb75ae2aef3a33e6351a9b906c7da57e8be9144e8baced218faba56d785b2
model-cell/saw/certificate.sha256     3651e63d5aa51f3bd144cf903eef0108d731a83a2f3ee2e7a84b58ea4f7f3420
compare/alive2/certificate.sha256     44c38885848c49805f61f974d78dd9463c0f5a6f4ed25ee894b5a8dc8409d2b5
compare/saw/certificate.sha256        3fde394304d15d5a8858cb64cec30c3ca13703944fe7a69a3bb342c257d80ca4
behavior/certificate.sha256           aa7b61189a1acff690bb7dde4271b61e217369099bad47f995c2aad8346a527e
```

Raw result digests:

```
model-cell/alive2/result.txt   3f8ee5c72f62719130523f4a835c026fdb69e047c658495c92376f32ba9e7ed8
model-cell/saw/result.txt      a1ca23168d50a2959c79d566a747293689dedc004af08877bc0450da1affa057
compare/alive2/result.txt      23ddbbc65d356d6470d97fafff865025bef62b7a49636fbad98d22158741b61a
compare/saw/result.txt         fd310e26eac9c07b45d85c14ebc776ac157a87205538c8308f2163baed3ca55e
behavior/result.txt            ccb788bd843019e47c217518595aee97144aa8c2b74497a0b3a0d02b7d5560f9
```

Certificates are tracked-input only: no `build/` artifact, no absolute path,
no timestamp. `sha256sum -c` is green for all five.

---

## 8. Files added, and what was deliberately not touched

Added (all under `spec/equiv/findings/wave65/18-scr-142/`):

```
report.md
model-cell/spec.md, notes.md, build.sh, cell_common.h, c_leg.cpp, l_leg.cpp
model-cell/alive2/{run.sh,result.txt,certificate.sha256}
model-cell/saw/{run.sh,cell.cry,cell.saw,result.txt,certificate.sha256}
compare/README.md, build.sh, compare_common.h, variants.cpp
compare/alive2/{run.sh,result.txt,certificate.sha256}
compare/saw/{run.sh,pin.cry,pin.saw,result.txt,certificate.sha256}
behavior/{driver.cpp,run.sh,result.txt,certificate.sha256}
```

Not touched: `spec/proofs/**`, `PINS.lock`, `contract/**`, `spec/db/**`,
`results/**`, `docs/**`, `spec/equiv/twin/**`, `spec/equiv/shims/**`, any
existing cell, and any shared runtime. The finding is deliberately **not**
under `cells/`, so `tools/run_equiv.py`, `update_ledger.py` and
`build_matrix.py` do not see it and no cell/row count changes.
