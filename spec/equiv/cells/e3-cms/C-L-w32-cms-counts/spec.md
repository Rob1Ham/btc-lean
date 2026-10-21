---
# Cell e3-cms/C-L-w32-cms-counts
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
r_leg: "not attempted: the pinned rbitcoin render/error path is documented non-proof (F-HARNESS-002, F-TOOL-001)"
cell: C-L-w32-cms-counts
family: checkmultisig
tool_status: both-green (symbolic prelude over all 64-bit inputs; 27 oracle scenarios)
precondition: |
  - The cell is the OP_CHECKMULTISIG / OP_CHECKMULTISIGVERIFY argument
    prelude of interpreter.cpp:1122-1146 at the pin, and nothing after the
    third depth check. Four symbolic 64-bit inputs:
      n          stack depth before the opcode (used as a uint32);
      keys_enc   the nKeys element (stacktop(-1));
      sigs_enc   the nSigs element (stacktop(-nKeys-2));
      ops_before the opCount accumulated before this opcode.
  - Element encoding is injective over len <= 5:
      bits 0..7 length, bits 8..47 payload bytes in wire order.
    keys_enc/sigs_enc are only ever decoded through the 4-byte
    CScriptNum rule, so lengths > 4 are the SCRIPTNUM edge.
  - The stack is the cell harness model `e32_top`: slot k = 1 is the nKeys
    element, slot k = nKeys + 2 is the nSigs element, every other slot is a
    one-byte zero (an element of value 0 with length 1). The model is shared
    by both legs, so a wrong *read depth* is not the comparison target; the
    three depth checks themselves are written separately in each leg.
  - opCount is an input (`ops_before`), not an interpreter-computed
    counter: SCR-113's per-op counting is outside this cell. MAX_OPS = 201
    and MAX_PUBKEYS_PER_MULTISIG = 20 are the pinned constants.
  - Every value is same-crypto-free: no checker and no signature is
    involved in the prelude.
postcondition: |
  - The observable is one packed uint64:
      result (bit 0) | error ordinal (bits 2..7) | nKeys (8..15) |
      nSigs (16..23) | opCount (24..31, low 8 bits) | depth n (32..39)
    On an error result = 0 with all fields zero (contract/ABI.md v2: only
    (result, error_kind) is observable on failure). Error ordininals:
      EQUIV_ERR_INVALID_STACK_OPERATION = 18 (all three depth checks)
      EQUIV_ERR_SCRIPTNUM = 4              (5+ byte CScriptNum)
      EQUIV_ERR_PUBKEY_COUNT = 10          (nKeys < 0 or nKeys > 20)
      EQUIV_ERR_OP_COUNT = 7               (ops_before + nKeys > 201)
      EQUIV_ERR_SIG_COUNT = 9              (nSigs < 0 or nSigs > nKeys)
  - Success is 0x01 with nKeys/nSigs/opCount/depth in the fields above.
    Check order is exactly Core's: depth(1) -> decode nKeys -> pubkey count
    -> opcount -> depth(nKeys+2) -> decode nSigs -> sig count ->
    depth(nKeys+nSigs+3).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-114
scr_row_coverage: full
coverage: full
patches: none
source_citations:
  - "interpreter.cpp:1122-1124 (i = 1 depth check), 1136-1138 (ikey/i = nKeys+2), 1143-1145 (isig/i += nSigs, third depth check)"
  - "interpreter.cpp:1126-1132 (CScriptNum(nKeys, 4), nKeys < 0 || nKeys > MAX_PUBKEYS_PER_MULTISIG)"
  - "interpreter.cpp:1133-1135 (nOpCount += nKeys; nOpCount > MAX_OPS_PER_SCRIPT)"
  - "interpreter.cpp:1140-1142 (CScriptNum(nSigs, 4) at stacktop(-nKeys-2); nSigs < 0 || nSigs > nKeys)"
  - "scriptnum CScriptNum(vch, fRequireMinimal=false, nMaxNumSize=4); overflow maps to EQUIV_ERR_SCRIPTNUM per contract/error_enum.md:96"
  - "spec/core/Bitcoin/Interpreter/Defs.lean:1071-1105 (checkMultiSig prelude), 629-635 (decodeScriptNum minimal=false maxSize=4)"
  - "contract/error_kind.h:22,30,36,42,49 (ordinals 4,7,9,10,18)"
trust_note: >
  C is a line-cited slice of pinned interpreter.cpp specialized to the
  CHECKMULTISIG argument prelude; it is not whole EvalScript. L is a
  reviewed transliteration of the Lean checkMultiSig prelude equations
  written from the big-endian digit view, not copied from the C slice.
  Alive2 compares the two functions as total functions of the four
  symbolic 64-bit inputs in both directions; SAW checks 27 oracle-derived
  packed constants against both linked modules. The harness stack accessor
  `e32_top` is shared by both legs and is part of the cell model, not engine
  code; correctness of the *depth arithmetic* is still engine code in each
  leg. No ECDSA, script parsing, or engine state is modelled, and no rbitcoin
  leg is claimed. "full" refers to SCR-114 only: every prelude branch and
  every error edge is exercised symbolically, with opCount supplied as an
  input (SCR-113 excluded).

  Tooling note: the Alive2 lane compiles at -O2 (the cell has no loops, so
  this only affects inlining/codegen). The runner-wide reason is recorded in
  findings/wave32/20-cms-114-117/report.md §2: at -O1 Alive2 v20.0 does not
  unroll the bounded loops of the sibling cells and returns vacuous greens;
  -O2 avoids that. The counts cell was also mutation-checked at -O2.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
  - build/ (twin_ops.h, c_leaf.ll, l_leaf.ll, extracted per-function IR)
mutant: "change the nKeys bound 20 -> 19 (or reorder the two depth checks); expect Alive2/SAW to fail. Recorded in findings/wave32/20-cms-114-117/report.md"
mutant_site: "cells/_tools/w32cms/c_counts.cpp (C leg) / l_counts.cpp (L leg)"
---

# Cell `e3-cms/C-L-w32-cms-counts`

## What is proved

`cell_cms_counts(n, keys_enc, sigs_enc, ops_before)` is the
OP_CHECKMULTISIG argument prelude: three stack-depth checks, two CScriptNum
decodes, and the nKeys / opCount / nSigs range checks, in Core's exact
order. Both legs are compared with `alive-tv --bidirectional` (L ⊑ C and
C ⊑ L) as total functions over all 64-bit inputs; no witness is fixed and no
branch is skipped. SAW then verifies both linked modules against 27
independently generated packed constants (54 proofs).

| Situation | Packed result |
|---|---|
| `n = 0` | `0x48` (INVALID_STACK_OPERATION 18) |
| nKeys element length > 4 | `0x10` (SCRIPTNUM 4) |
| nKeys < 0 or nKeys > 20 | `0x28` (PUBKEY_COUNT 10) |
| `ops_before + nKeys > 201` | `0x1c` (OP_COUNT 7) |
| `n < nKeys + 2` | `0x48` |
| nSigs element length > 4 | `0x10` (SCRIPTNUM 4) |
| nSigs < 0 or nSigs > nKeys | `0x24` (SIG_COUNT 9) |
| `n < nKeys + nSigs + 3` | `0x48` |
| success | `0x1 | nKeys<<8 | nSigs<<16 | opCount<<24 | n<<32` |

Exact outputs and the Alive2 transcript are in `alive2/result.txt`.

## SCR-114

`SCR-114 (nKeys∈[0,20], nSigs∈[0,nKeys], depth checks)` is fully covered
inside this cell's model: the bound checks, both decodes, the opCount arm,
and all three depth checks are exercised on symbolic values, including the
negative-number (sign-magnitude high bit) encoding. The cell does not model
SCR-113's accumulation of `nOpCount` across other opcodes; `ops_before` is
an input. Boundary encodings (len 5..255) all collapse to SCRIPTNUM because
the 4-byte limit rejects them before any payload interpretation, which is
also what Core does.

## Directions

`alive2/result.txt` compares C to L with `--bidirectional`; SAW proves both
legs separately against the same oracle constants in one build. No R leg and
no whole-engine claim is made.
