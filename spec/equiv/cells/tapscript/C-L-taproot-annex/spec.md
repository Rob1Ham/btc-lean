---
# Cell tapscript/C-L-taproot-annex
cell: C-L-taproot-annex
family: tapscript
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (two total symbolic predicates)
precondition: |
  - Cell seam: annex detection and removal in the taproot arm,
    interpreter.cpp:1961-1969.
  - `witness_n` = witness stack item count, arbitrary 64-bit.
  - `last_len` = size of the last witness item, arbitrary 64-bit.
  - `last_first` = value of the last item's first byte (Core indexes an
    unsigned char; the harness masks with 0xff).
  - The annex *contents* and the annex hash are not modelled. The row is the
    detection predicate, not the sighash.
  - No SHA256, no Schnorr/EC, no EvalScript, no ExecuteWitnessScript.
postcondition: |
  - cell_annex_detected = 1 iff
      witness_n >= 2 && last_len != 0 && last_first == 0x50
    else 0, exactly Core interpreter.cpp:1961 / Lean Defs.lean:1287-1288.
  - cell_annex_remaining = witness_n - 1 when annex is detected, else
    witness_n (Core :1965 SpanPopBack; Lean :1289 dropLast).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-143
scr_row_coverage: |
  full. SCR-143's claim is exactly the annex detection rule ">=2 items, last
  non-empty, first byte 0x50" plus the removal of that item. Both predicates
  are proved total over all 64-bit (witness_n, last_len, last_first), so every
  arity/empty/non-0x50/0x50 case is exercised symbolically, not merely one
  closed witness. Annex hashing (`SHA256(CompactSize(len)||annex)`) is a
  sighash input and is not part of this row; it is not claimed.
patches: none
source_citations:
  - "interpreter.cpp:1961 (stack.size() >= 2 && !stack.back().empty() && stack.back()[0] == ANNEX_TAG)"
  - "interpreter.cpp:1965 (SpanPopBack(stack))"
  - "script.h:59 (ANNEX_TAG = 0x50)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:94-95 (ANNEX_TAG)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1287-1288 (annex predicate)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1289 (dropLast)"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1745-1755 (verifyWitnessProgram_annex_keypath)"
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp at
  the pin. L is a reviewed transliteration of the Verified Lean
  verifyWitnessProgram annex predicate; the twin has no VerifyWitnessProgram
  handler, so it is not generated from twin/ops_ir.py. The two input facts
  (last item size and first byte) are exactly the facts Core reads at :1961.
  No hash, signature or script-loop semantics is modelled. Both tools prove
  the same total predicates: Alive2 compares the C and L IR bidirectionally;
  SAW verifies each leg against one shared Cryptol statement derived from the
  Core rule. No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: >
  Proposed, not executed: in l_leg.cpp change the detection guard from
  `witness_len >= 2` to `witness_len > 2`. Expected Alive2 counterexample at
  witness_len=2, last_size=1, last_byte0=0x50 (C detects, L does not), and a
  SAW proof failure for the L module on both functions.
mutant_site: "cells/tapscript/C-L-taproot-annex/l_leg.cpp l_annex_detected, Defs.lean:1287 guard"
---

# `tapscript/C-L-taproot-annex`

## What is proved

| function | claim | result |
|---|---|---|
| `cell_annex_detected` | `n>=2 && last_len!=0 && last_byte0==0x50` over all inputs | both-green, 3-arg symbolic |
| `cell_annex_remaining` | annex detected => `n-1`, else `n` | both-green, 3-arg symbolic |

This is a total symbolic proof of the rule, not a closed witness: Alive2
quantifies over every 64-bit `(witness_n, last_len, last_first)`, and SAW
verifies the same statement against `build/cell.cry`.

## Why this is full row coverage

SCR-143 is the detection rule itself: ">=2 items, last non-empty, first byte
0x50". The cell proves the complete truth table by symbolic enumeration and
also proves the resulting span size. The annex hash is a different row's
subject (sighash / SCR-146-adjacent), so abstracting it does not narrow
SCR-143.

## What is not proved

- Annex hashing and `ScriptExecutionData` annex fields.
- Any consumer of the annex (sighash, key path, script path).
- Any whole-engine ingestion.

## Exact commands

```sh
bash spec/equiv/cells/tapscript/C-L-taproot-annex/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-annex/saw/run.sh
sha256sum -c spec/equiv/cells/tapscript/C-L-taproot-annex/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-taproot-annex/saw/certificate.sha256
```
