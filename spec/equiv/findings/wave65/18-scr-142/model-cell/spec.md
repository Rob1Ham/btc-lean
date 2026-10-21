---
cell: C-L-w65-taproot-bip9-window-model
family: tapscript
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 76dbfe5
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
model_only: true
ledger_cell: false
tool_status: both-green (MODEL ONLY; not row evidence)
precondition: |
  - FINDING-SCOPED MODEL, deliberately under findings/ and not under cells/ so
    it cannot be cited as ledger evidence or green SCR-142.
  - Cell-local ABI (NOT contract/tape.md): the entry takes a block hash as
    four 64-bit limbs (equality only) and a uint32 block height.  This is the
    "add height/hash to the cell-local tape/ABI" option from the row's gap
    record.
  - The C and L legs both implement the HISTORICAL taproot BIP9 height
    abstraction recorded in spec/core/Bitcoin/Activation/Taproot.lean
    (TPR-075 minActivation = 709632; TPR-076 hash-keyed exception; TPR-078
    deploymentActiveAt d height := d.minActivation <= height).  This is a
    model choice, not a cce32b168 source slice.
  - Only the TAPROOT term is historical.  P2SH | WITNESS is the always-on
    base (already buried by 2021); the four buried ORs are the pin's.
  - Interpreter arm is interpreter.cpp:1957-1969 at the pin (unchanged).
postcondition: |
  - Packed observable: result(2) | error_ordinal(6) << 2 | taproot_on << 8.
  - taproot_on = 0 iff the block hash is one of the two mainnet
    script_flag_exceptions entries (any height, TPR-076);
    taproot_on = 1 iff 709632 <= height (TPR-078) and the hash is not an
    exception.
  - v1-32 non-P2SH, taproot_on = 0 -> (1, 0) silent success
  - v1-32 non-P2SH, taproot_on = 1, witness_n = 0 -> (0, 39)
  - v1-32 non-P2SH, taproot_on = 1, witness_n > 0 -> (2, 0) continuation
  - any other shape -> (3, 0) outside this arm
  - Both legs return the same packed value for every hash/height/shape, in
    both directions.  This proves the MODEL is well-formed.  It does NOT
    prove any cce32b168 behaviour: ../compare/ proves the model and the pin
    differ at height 709631.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-142
scr_row_coverage: |
  partial, MODEL ONLY.  This cell supplies no row coverage and must not be
  cited to green SCR-142.  It demonstrates that the row's historical
  "only pre-activation (height 709632)" clause is exactly representable once
  (i) a cell-local height/hash ABI is admitted and (ii) the historical Lean
  record TPR-075/076/078 is accepted as the specification.  It does not make
  that clause a property of Bitcoin Core cce32b168, whose GetBlockScriptFlags
  (validation.cpp:2249-2288) sets TAPROOT unconditionally at every height and
  has no DEPLOYMENT_TAPROOT (consensus/params.h:38-44).  For row coverage a
  second pin is required (a BIP341-era tree with DEPLOYMENT_TAPROOT and its
  versionbits state machine); see ../report.md residual R1/R2.
patches: none
source_citations:
  - "spec/core/Bitcoin/Activation/Taproot.lean:44-51 (TPR-075 historical deployment, minActivation 709632)"
  - "spec/core/Bitcoin/Activation/Taproot.lean:95-107 (TPR-076 taproot exception block, hash-keyed, any height)"
  - "spec/core/Bitcoin/Activation/Taproot.lean:133-137 (TPR-078 deploymentActiveAt d height := d.minActivation <= height)"
  - "spec/core/Bitcoin/Activation/Taproot.lean:152-176 (taproot_first_active 709632 / taproot_not_active_before 709631)"
  - "spec/core/Bitcoin/Activation/Taproot.lean:68-79 (mainnetDeployments_no_taproot: the historical row is NOT in the pin's table)"
  - "spec/core/Bitcoin/Activation/Flags.lean:69-76,127-128,145-157 (exception map / buriedActive / getBlockScriptFlagsP shape)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1280-1285 (taproot arm head; reused unchanged)"
  - "validation.cpp:2249-2288 @cce32b168 (why this cannot be a pin claim: TAPROOT is unconditional)"
  - "consensus/params.h:38-44; kernel/chainparams.cpp:132-137 @cce32b168 (no DEPLOYMENT_TAPROOT; TESTDUMMY only)"
  - "interpreter.cpp:1957-1969 @cce32b168 (gate branch table)"
trust_note: >
  Both legs are MODELS transcribed from the historical Lean record, not from
  any pinned Core C source.  Alive2 and SAW therefore prove only that the two
  transcriptions agree with the TPR-078 height abstraction; they are not
  evidence about cce32b168.  The companion probe in ../compare/ is the
  evidence that the model is not the pin: pinned C is height-inert across
  709631/709632, the model is not, and the two differ exactly below 709632.
  TPR-078 is itself a height abstraction of the BIP9 state machine
  (versionbitscache.IsActiveAfter + pprev composition), so even a second pin
  would need the state machine or a fixed chain-state harness; see
  ../report.md residual R2.  No shared contract, tape, pin, ledger, proof,
  existing cell or results file is touched.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - ../compare/alive2/result.txt (pin-vs-model distinction; the actual result)
  - ../compare/saw/result.txt (height-free pinned predicate)
  - ../behavior/result.txt (concrete witness table; not proof evidence)
---

# `C-L-w65-taproot-bip9-window-model` (finding-scoped MODEL)

## What this is

Two independent transcriptions (bitmask C-shaped and Bool-record L-shaped) of
the historical taproot BIP9 height abstraction that the Lean tree records as
TPR-075/076/078. The ABI is cell-local and carries a block hash plus a
`uint32` block height; `contract/tape.md` is **not** modified.

## What this is not

It is **not** a `cce32b168` result and **not** row coverage. At the pin:

- `validation.cpp:2261` sets `SCRIPT_VERIFY_TAPROOT` unconditionally;
- the only clears are hash-keyed `script_flag_exceptions` (`:2262-2265`);
- `consensus/params.h:38-44` has no `DEPLOYMENT_TAPROOT`;
- `interpreter.cpp:1959` is a flag test, never a height test.

So any C leg that returns TAPROOT off at 709631 is a model, not the pin. The
companion probe proves the inequality rather than claiming it.

## Result

```
STATUS=alive2-green (model-only)          # 1/1 bidirectional equivalence
STATUS=saw-green (2/2 proofs, model-only)
```

The same model is then compared with the pinned slice in `../compare/`:

```
A pin@709631 vs pin@709632        EQUIV    the pin has no height term
B model@709631 vs model@709632    DIFF     the model's gate is live
C pin@709632 vs model@709632      EQUIV    agreement at activation
D pin@709631 vs model@709631      DIFF     the exact missing term
E pin@exc692261 vs model@exc692261 EQUIV   agreement at the exception block
```

## Exact commands

```sh
bash spec/equiv/findings/wave65/18-scr-142/model-cell/alive2/run.sh
bash spec/equiv/findings/wave65/18-scr-142/model-cell/saw/run.sh
bash spec/equiv/findings/wave65/18-scr-142/compare/alive2/run.sh
bash spec/equiv/findings/wave65/18-scr-142/compare/saw/run.sh
bash spec/equiv/findings/wave65/18-scr-142/behavior/run.sh
sha256sum -c spec/equiv/findings/wave65/18-scr-142/model-cell/alive2/certificate.sha256
sha256sum -c spec/equiv/findings/wave65/18-scr-142/model-cell/saw/certificate.sha256
sha256sum -c spec/equiv/findings/wave65/18-scr-142/compare/alive2/certificate.sha256
sha256sum -c spec/equiv/findings/wave65/18-scr-142/compare/saw/certificate.sha256
```
