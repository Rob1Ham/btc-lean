---
# Cell tapscript/C-L-taproot-activation-gate
cell: C-L-taproot-activation-gate
family: tapscript
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c02
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (one total symbolic predicate; all 2^256 block hashes x all 2^32 heights x all shapes)
precondition: |
  - Cell seam: the TAPROOT bit of GetBlockScriptFlags (validation.cpp:
    2249-2288) composed with the head of the taproot arm of
    VerifyWitnessProgram (interpreter.cpp:1957-1969). No other engine step.
  - Mainnet chain parameters at the pin.  Exception keys are the two
    256-bit hashes in kernel/chainparams.cpp:115-118, carried as four
    64-bit limbs (equality only, so the limb grouping is representation).
  - `height` is any uint32.  It is a real input: it drives the four buried
    ORs (DERSIG/CLTV/CSV/NULLDUMMY) exactly as in the pinned function.
  - `version`, `program_len`, `is_p2sh`, `witness_n` are arbitrary 64-bit
    values.  Only `version == 1 && program_len == 32 && is_p2sh == 0`
    enters the taproot arm; the other shapes leave it, as in the engine.
  - No SHA256, no Schnorr/EC, no EvalScript, no ExecuteWitnessScript, no
    annex/key/script dispatch, no transaction or block decoding, no
    scriptPubKey recognition (the arm condition is an input, as in the
    sibling C-L-taproot-gate cell).
postcondition: |
  - Packed observable: result(2) | error_ordinal(6) << 2 | taproot_on << 8.
  - `taproot_on` is the SCRIPT_VERIFY_TAPROOT bit of the pinned
    GetBlockScriptFlags:
      taproot_on = 0  iff  block_hash is one of the two mainnet
      script_flag_exceptions entries (BIP16 -> SCRIPT_VERIFY_NONE,
      taproot -> P2SH|WITNESS; both clear TAPROOT),
      taproot_on = 1  otherwise,
      for every uint32 height.
  - v1-32 non-P2SH, taproot_on = 0        -> (1, 0)   silent success
  - v1-32 non-P2SH, taproot_on = 1, witness_n = 0 -> (0, 39)
                                            WITNESS_PROGRAM_WITNESS_EMPTY
  - v1-32 non-P2SH, taproot_on = 1, witness_n > 0 -> (2, 0)   continuation
  - any other shape                       -> (3, 0)   outside this arm
  - Codes 2 and 3 are cell-harness markers, not engine results.  Both legs
    return the same packed value for every input, in both directions.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-142
scr_row_coverage: |
  partial, and the remaining gap is now exact.
  - COVERED: "with the flag, a v1-32 non-P2SH spend is not anyone-can-spend"
    (empty witness -> error 39; non-empty -> continuation) for every
    hash/height/shape.  COVERED: "without the flag it succeeds silently"
    for the taproot exception block, hash `…1e395ad` at height 692261, and
    for the same hash at every other height.  COVERED/NEGATIVE: the pinned
    assembly has no height term for TAPROOT, so the cell proves height
    709631 and 709632 produce identical results (the historical "only
    pre-activation" window is not a property of this pin).
  - NOT COVERED: the row's historical clause "only pre-activation (height
    709632 ...)" as a height-gated behaviour.  At cce32b168 there is no
    DEPLOYMENT_TAPROOT and no height compare on the TAPROOT bit; the BIP9
    window survives only as a historical Lean record
    (Activation/Taproot.lean, TPR-075/078, min_activation 709632).  The
    exact missing contract context is filed in GAP-CONTEXT.md: the tape has
    no block-height/block-hash flag-assembly channel, and the pin has no
    function to transliterate.  A cell asserting a 709632 gate would have
    to invent source.
  - Out of scope: annex (SCR-143), key path (SCR-144), control block
    (SCR-145), commitment (SCR-146/147), leaf version (SCR-149..151), and
    any executed tapscript.
patches: none
source_citations:
  - "validation.cpp:2249-2288 (GetBlockScriptFlags; base, exception replace, buried ORs)"
  - "validation.cpp:2259-2261 (P2SH|WITNESS|TAPROOT is always-on except the two violating blocks)"
  - "validation.cpp:2262-2265 (hash-keyed script_flag_exceptions lookup REPLACES the base)"
  - "validation.cpp:2267-2285 (DERSIG/CLTV/CSV/NULLDUMMY buried ORs; none touches TAPROOT)"
  - "kernel/chainparams.cpp:115-118 (the two mainnet exception hashes and their flag sets)"
  - "kernel/chainparams.cpp:119-125 (BIP34/BIP66/BIP65/CSV/Segwit heights; MinBIP9WarningHeight comment names taproot activation height 709632)"
  - "consensus/params.h:26-36 (BuriedDeployment list ends at SEGWIT; no TAPROOT)"
  - "consensus/params.h:38-44 (DeploymentPos list carries only TESTDUMMY)"
  - "deploymentstatus.h:13-18,26-31,33-37 (DeploymentActiveAfter/At: buried compare; BIP9 via versionbits)"
  - "interpreter.cpp:1957 (v1-32 non-P2SH arm condition)"
  - "interpreter.cpp:1959 (flag off -> set_success)"
  - "interpreter.cpp:1960 (empty witness -> SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY)"
  - "interpreter.h:240 (WITNESS_V1_TAPROOT_SIZE = 32); verify_flags.h:31 + interpreter.h:137 (TAPROOT = 1 << 17)"
  - "spec/core/Bitcoin/Activation/Flags.lean:69-76 (mainnetExceptionMap)"
  - "spec/core/Bitcoin/Activation/Flags.lean:127-128 (buriedActive)"
  - "spec/core/Bitcoin/Activation/Flags.lean:145-157 (getBlockScriptFlagsP)"
  - "spec/core/Bitcoin/Activation/Taproot.lean:29-40,44-51 (historical taproot BIP9 record, TPR-075)"
  - "spec/core/Bitcoin/Activation/Taproot.lean:133-152 (deploymentActiveAt gate, TPR-078; NOT in the pin's table)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1280-1285 (taproot arm head)"
  - "spec/equiv/contract/tape.md:14-25 (equiv_entry has no block context); :100-104 (flags is a caller-supplied mask)"
  - "spec/equiv/contract/error_enum.md:69 and error_kind.h:78 (ordinal 39)"
trust_note: >
  C is a line-cited source-excerpt slice of validation.cpp:2249-2288 and
  interpreter.cpp:1957-1969 at the pin.  The std::map lookup is written as
  equality against the two mainnet entries; the map has exactly those two
  entries, so the slice is fail-closed for every other 256-bit hash.  The
  four DeploymentActiveAt calls are all BuriedDeployment compares, which
  deploymentstatus.h:27-31 defines as `nHeight >= DeploymentHeight`.  L is
  a reviewed hand transliteration of getBlockScriptFlagsP (Bool record +
  Option) and the VerifyWitnessProgram taproot arm; the twin has no
  Activation handler.  The legs differ in representation (64-bit bitmask +
  limb equality vs Bool record + Option), which is what the Alive2 compare
  closes.  Neither leg is the whole node path.  No Core source patch is
  used.  The historical 709632 BIP9 window is deliberately outside the
  model; see GAP-CONTEXT.md.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - behavior/result.txt (concrete witness table; not proof evidence)
  - GAP-CONTEXT.md (the exact missing contract context)
mutant: >
  Proposed, not executed: in l_leg.cpp make l_interpreter_gate return
  tap_pack(TAP_FAIL, 0) instead of TAP_OK when flags.taproot is false.
  Expected Alive2 counterexample at any exception hash (C packs 1, L packs
  0) and expected SAW proof failure for the L module.  A second proposed
  mutant adds a fabricated `height >= 709632` conjunct to the L taproot
  bit; expected Alive2 counterexample at height 709631, since the pinned C
  slice has no such gate.  Neither mutant was run; this is a proposal only.
mutant_site: "cells/tapscript/C-L-taproot-activation-gate/l_leg.cpp l_interpreter_gate :1282 branch; l_get_block_script_flags taproot bit"
---

# `tapscript/C-L-taproot-activation-gate`

## What is proved

One total symbolic function per leg:

```
cell_taproot_activation(h0, h1, h2, h3, height,
                        version, program_len, is_p2sh, witness_n)
```

Alive2 quantifies over every 256-bit block hash, every uint32 height and
every shape tuple; SAW verifies each leg against the independent Cryptol
statement in `build/cell.cry`.  The packed result is
`result | error << 2 | taproot_on << 8`.

| block hash | height | shape | result |
|---|---|---|---|
| `…1e395ad` (taproot exception) | any, incl. 692261 | v1-32 non-P2SH | success, silent |
| `…4f9c22` (BIP16 exception) | any, incl. 170060 | v1-32 non-P2SH | success, silent |
| any other hash | 709631 | v1-32 non-P2SH, empty witness | error 39 |
| any other hash | 709632 | v1-32 non-P2SH, empty witness | error 39 |
| any other hash | any | v1-32 non-P2SH, non-empty witness | continuation |
| any | any | other version/length/P2SH | outside this arm |

The two middle rows are the activation-height finding: **at the pin there is
no 709632 gate to cross.**  `GetBlockScriptFlags` leaves TAPROOT on at every
height except the two hash-keyed exception blocks, and both exception blocks
are below 709632.  The cell's `height` input is real (it drives the buried
ORs) but provably does not reach the TAPROOT bit.

## What is not proved

- The historical BIP9 pre-activation window (709631 vs 709632) as a
  *height-gated TAPROOT bit*.  The pin has removed `DEPLOYMENT_TAPROOT`
  (`consensus/params.h:38-44`: only TESTDUMMY) and hardcodes TAPROOT on.
  The historical record exists in `Bitcoin.Activation.Taproot`
  (TPR-075/078) but has no C counterpart at cce32b168.  See
  `GAP-CONTEXT.md` for the exact contract context that is missing.
- Annex detection (SCR-143), key path (SCR-144), control block
  (SCR-145), commitment (SCR-146/147), leaf version (SCR-149..151):
  sibling cells under `cells/tapscript/`.
- Any whole-engine ingestion.  This is a bounded flag-assembly + dispatch
  leaf.

## Exact commands

```sh
bash spec/equiv/cells/tapscript/C-L-taproot-activation-gate/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-activation-gate/saw/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-activation-gate/behavior/run.sh
sha256sum -c spec/equiv/cells/tapscript/C-L-taproot-activation-gate/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-taproot-activation-gate/saw/certificate.sha256
```
