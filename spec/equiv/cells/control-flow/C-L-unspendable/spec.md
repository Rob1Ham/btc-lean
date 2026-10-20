---
# Cell control-flow/C-L-unspendable
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: C-L-unspendable
family: control-flow
tool_status: both-green (symbolic, whole 32-bit size range and all first bytes)
precondition: |
  - the predicate's only inputs: script size (symbolic 32-bit) and first byte
    (symbolic 8-bit). No array is materialised.
  - no flags, sigversion, or stack: IsUnspendable is a pure CScript predicate.
postcondition: |
  - unspendable iff (size > 0 and first byte == OP_RETURN (0x6a)) or
    size > MAX_SCRIPT_SIZE (10000).
  - spendable otherwise, including size == 10000 and an empty script with any
    first-byte input (the first byte is not read when size == 0).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-070
scr_row_coverage: >-
  full — the row names exactly two sufficient conditions: an OP_RETURN first
  byte and a script larger than 10k. Both arms and the neither-arm are
  exercised symbolically over the whole 32-bit size range and every first
  byte, including the exact boundaries size = 10000 (spendable) / 10001
  (unspendable) and the empty script. Nothing named by the row is missing.
patches: none
source_citations:
  - script.h:564-567 (CScript::IsUnspendable)
  - Ledger/Interface.lean:96-101 (scriptUnspendable, MAX_SCRIPT_SIZE)
trust_note: >
  C is the exact two-predicate body of CScript::IsUnspendable at the pin,
  taking the size and first byte directly (the only facts the predicate
  reads). L transcribes the Lean definition scriptUnspendable, whose
  MAX_SCRIPT_SIZE is 10000; the leaf does not reuse the generated bounded
  MAX_* constants, which are re-bound to the leaf domain. Alive2 compares C
  and L over all inputs; SAW verifies each leg separately against an
  independent Cryptol predicate. No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: none (not a REDTEAM gate cell)
---
