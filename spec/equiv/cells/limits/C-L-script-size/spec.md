---
# Cell limits/C-L-script-size
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-script-size
family: limits
tool_status: both-green (symbolic, all UInt64 lengths and all sigversion bytes)
precondition: |
  - SigVersion code sv ∈ {0 = BASE, 1 = WITNESS_V0, 2 = TAPSCRIPT}
    (Core's TAPROOT never executes a script and is outside the cell domain;
    other codes are out of domain and return result 2).
  - `script_len` is the whole-script byte length (`script.size()`), symbolic
    over all 2^64 values.  The tape-level flags are irrelevant to this row
    (the guard reads no flag).
  - no P2SH/witness wrapping; the cell is the EvalScript prologue only.
postcondition: |
  - if sv ∈ {BASE, WITNESS_V0} and script_len > 10000: result 0,
    error_kind 5 (EQUIV_ERR_SCRIPT_SIZE), payload 0.
  - otherwise (including every TAPSCRIPT length, and BASE/WITNESS_V0
    lengths ≤ 10000): result 1 ("guard admitted to the opcode loop"),
    error_kind 0, payload = script_len mod 2^24.
  - out-of-domain sv: result 2, error_kind 1 (EQUIV_ERR_UNKNOWN_ERROR).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: [SCR-018, SCR-019]
scr_row_coverage: >-
  full — SCR-018 and SCR-019 are exactly the EvalScript entry guard
  (interpreter.cpp:438-440 / Defs.lean:1163-1164): the predicate over
  `script.size()` and `sigversion`, evaluated once before the opcode loop.
  The cell is symbolic over the whole uint64 length domain and all three
  executable sigversions, so both the firing branch (> 10000 for
  BASE/WITNESS_V0) and the non-firing branch (≤ 10000, and every TAPSCRIPT
  length) are exercised, not a single witness.  The opcode loop after the
  guard is not part of either row; the payload records admission.
patches: none
source_citations:
  - interpreter.cpp:427-428 (sigversion assert; TAPROOT admits no execution)
  - interpreter.cpp:438-440 (MAX_SCRIPT_SIZE guard, BASE/WITNESS_V0 only)
  - interpreter.cpp:449 (the guard precedes the opcode loop, hence once)
  - script.h:41 (MAX_SCRIPT_SIZE = 10'000)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1163-1166 (evalScriptBytes)
  - spec/equiv/twin/runtime.inc:594-597 (twin EvalScript prologue)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp and
  script.h at the pin, not the whole EvalScript; the slice is the prologue
  guard with the sigversion enum and MAX_SCRIPT_SIZE constant spelled out.
  L is a reviewed transliteration of the Lean `evalScriptBytes` guard (and
  the identical structural guard in the generated twin), not a generated
  handler: the twin has no per-opcode handler for this limit.  The domain
  guard and the packed observable are cell harness shared by both legs.
  Alive2 compares the two extracted modules over symbolic i64/i8 inputs; SAW
  verifies each leg separately against an independent Cryptol predicate over
  all 2^64 lengths and 2^8 sigversion bytes.  This is a bounded prologue
  predicate, not a whole-engine equivalence proof.  No Core patch is used.
evidence:
  alive2: alive2/result.txt (STATUS=alive2-green)
  saw: saw/result.txt (STATUS=saw-green, 2 proofs)
  certificates:
    - alive2/certificate.sha256
    - saw/certificate.sha256
---

# limits/C-L-script-size

C vs L for the `MAX_SCRIPT_SIZE` prologue guard.

The interesting half is the *exclusion*: SCR-019 says TAPSCRIPT has no 10k
script limit.  The cell proves both directions for every TAPSCRIPT length
(payload carries the admitted length) and for every BASE/WITNESS_V0 length,
including the boundary 10000 → admit and 10001 → `SCRIPT_SIZE`.

Run:

```sh
bash spec/equiv/cells/limits/C-L-script-size/alive2/run.sh
bash spec/equiv/cells/limits/C-L-script-size/saw/run.sh
```
