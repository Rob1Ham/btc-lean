---
# Cell tapscript/C-L-tapscript-isopsuccess
cell: C-L-tapscript-isopsuccess
family: tapscript
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (one total symbolic byte predicate)
precondition: |
  - Cell seam: the pure one-byte membership test CScript::IsOpSuccess
    (script.cpp:365-371). No script parsing, no OP_SUCCESS pre-scan loop, no
    EvalScript.
  - `opcode` is an arbitrary 64-bit value. Core's parameter is an enum whose
    values are 0..255; any value outside the listed ranges matches nothing
    and returns false, so the function is total over the harness domain.
postcondition: |
  - cell_is_op_success(opcode) = 1 iff
      opcode == 80 || opcode == 98 ||
      (126 <= opcode <= 129) || (131 <= opcode <= 134) ||
      (137 <= opcode <= 138) || (141 <= opcode <= 142) ||
      (149 <= opcode <= 153) || (187 <= opcode <= 254)
    else 0.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-152
scr_row_coverage: |
  full. SCR-152 is exactly the pure set-membership test over one byte. The
  cell proves the predicate total over all 64-bit inputs, so every byte
  0..255 and every out-of-domain value is covered, not just a witness. The
  execution consequence (OP_SUCCESS pre-scan and immediate success) is
  SCR-153, a separate seam, and is not claimed here.
patches: none
source_citations:
  - "script.cpp:365-371 (bool IsOpSuccess(const opcodetype& opcode))"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:463-466 (isOpSuccessWire)"
  - "spec/core/Bitcoin/Script/Tapscript/Delta.lean:91 (checksigadd_not_success)"
trust_note: >
  C is the exact source expression at script.cpp:365-371. L is a reviewed
  transliteration of the Verified Lean isOpSuccessWire (Defs.lean:463-466).
  No crypto, hash, memory or loop semantics is modelled. Both tools prove the
  same total predicate: Alive2 compares the C and L IR bidirectionally; SAW
  verifies each leg against an independent Cryptol statement written from the
  ledger's documented byte set. No Core source patch is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: >
  Proposed, not executed: in l_leg.cpp drop the 149..153 range or widen
  187..254 to 187..255. Expected Alive2 counterexample at opcode=150 (first)
  or opcode=255 (second), and a SAW proof failure for the L module.
mutant_site: "cells/tapscript/C-L-tapscript-isopsuccess/l_leg.cpp l_is_op_success"
---

# `tapscript/C-L-tapscript-isopsuccess`

## What is proved

`cell_is_op_success(opcode)` is symbolic over all 64-bit inputs. The proved
set is exactly:

```
{80, 98, 126-129, 131-134, 137-138, 141-142, 149-153, 187-254}
```

Alive2 checks C vs L bidirectionally; SAW checks both legs against the
Cryptol set in `build/cell.cry`, which is written from the ledger row rather
than from either C++ file.

## What is not proved

The row is the wire-table membership test. What executing an OP_SUCCESSx
byte does (the raw-byte pre-scan, immediate success, and the
DISCOURAGE_OP_SUCCESS policy failure) is SCR-153/154 and remains a seam.
This cell makes no claim about it.

## Exact commands

```sh
bash spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/saw/run.sh
sha256sum -c spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/saw/certificate.sha256
```
