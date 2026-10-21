---
# Cell stack/C-L-dup-drop-swap

contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: stack/C-L-dup-drop-swap
family: stack-ops
tool_status: both-green (bounded closed witnesses)
witnesses:
  - '`cell_dup_underflow`: spk `76` (`OP_DUP`) -> `0x0000000000000048` (result 0, err 18, n=0)'
  - '`cell_swap_underflow`: spk `7c` (`OP_SWAP`) -> `0x0000000000000048` (result 0, err 18, n=0)'
  - '`cell_drop_underflow`: spk `75` (`OP_DROP`) -> `0x0000000000000048` (result 0, err 18, n=0)'
  - '`cell_dup_drop_swap_ok`: spk `5152767c528775` (`OP_1 OP_2 OP_DUP OP_SWAP OP_2 OP_EQUAL OP_DROP`) -> `0x0000000001202a01` (result 1, err 0, n=2, [1,2])'
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
scr_rows: SCR-074, SCR-078
scr_row_coverage: |
  partial — closed branches only: empty-stack DUP/SWAP/DROP failures plus one success composition; no symbolic depth or elements, no stack-size edge.
patches: none
source_citations:
  - interpreter.cpp:495-529 (pushes)
  - interpreter.cpp:795-802 (OP_DROP)
  - interpreter.cpp:804-811 (OP_DUP)
  - interpreter.cpp:863-869 (OP_SWAP)
  - interpreter.cpp:897-910 (OP_EQUAL)
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
