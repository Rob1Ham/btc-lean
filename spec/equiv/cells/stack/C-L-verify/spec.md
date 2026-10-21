---
# Cell stack/C-L-verify

contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: stack/C-L-verify
family: control-flow
tool_status: both-green (bounded closed witnesses)
witnesses:
  - '`cell_verify_true`: spk `516951` (`OP_1 OP_VERIFY OP_1`) -> `0x0000000000002901` (result 1, err 0, n=1, top [1])'
  - '`cell_verify_false`: spk `0069` (`OP_0 OP_VERIFY`) -> `0x000000000000012c` (result 0, err 11 (VERIFY), n=1, top empty)'
  - '`cell_verify_empty`: spk `69` (`OP_VERIFY`) -> `0x0000000000000048` (result 0, err 18 (INVALID_STACK_OPERATION), n=0)'
precondition: |
  - base sigversion; flags = 0; amount = 0; input_index = 0; one input.
  - empty scriptSig; no witness record; fully parseable scriptPubKey.
  - closed spk exactly as listed per function; script length <= 5 bytes.
  - bounded leaf domain: element length <= 1 byte, stack depth <= 6.
postcondition: |
  - Each listed function returns its packed observable exactly.
  - Packed layout: result (2), error ordinal (6), depth (3), top three
    elements `(len:2,val:8)`.
direction:
  - L ⊑ C
  - C ⊑ L
  # Both directions are proved on the bounded closed leaves; this is not a
  # claim about the whole `equiv_entry` function or a symbolic op law.
behavioral_witness: whole-entry C and L agree on every listed spk; see
  `behavior/result.txt`.  Behavioral only, not proof evidence.
scr_rows: SCR-068
scr_row_coverage: |
  partial — closed branches only: true (pop), false (VERIFY), and empty-stack (INVALID_STACK_OPERATION); no symbolic truth values, no flags, no scriptSig.
patches: none
source_citations:
  - interpreter.cpp:495-529 (pushes)
  - interpreter.cpp:663-674 (OP_VERIFY)
  - interpreter.cpp:1876-1880 (EVAL_FALSE tail)
trust_note: >
  C leg is a line-cited source-excerpt slice of Bitcoin Core
  `src/script/interpreter.cpp` at the pin, not the whole EvalScript.  L leg
  uses the twin's handler bodies verbatim, generated from `twin/ops_ir.py`
  into `build/twin_ops.h`; the shared bounded stack/dispatch/pack code is
  cell harness, not engine code.  These are closed witnesses, not a symbolic
  proof of the op law; the SAW postcondition is the declared constant.
  Whole-entry Alive2 is not ingestible (loops/unsupported attributes), so the
  whole-entry evidence is behavioral only.  `-O1 -fno-strict-aliasing` is
  used because the fully inlined `-O0` build did not finish in the Alive2
  harness timeout.  F-DIV-001 does not apply (scripts fully parseable).
  F-ERR-TWIN-001 (whole-entry non-OK error-kind mapping) is not discharged;
  the leaf proves only the exact closed error ordinals listed here.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - behavior/result.txt, behavior/certificate.sha256
mutant: none (broader exploratory cell; not a REDTEAM gate)
---
