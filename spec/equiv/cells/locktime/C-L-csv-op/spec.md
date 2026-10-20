---
# Cell locktime/C-L-csv-op
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: locktime/C-L-csv-op
family: locktime
tool_status: both-green (symbolic over the whole CSV opcode rule)
precondition: |
  - base sigversion; one transaction input (nIn = 0); no other script flags.
  - the SCRIPT_VERIFY_CHECKSEQUENCEVERIFY activation bit is symbolic.
  - the operand is a *pre-decoded* CScriptNum: the 5-byte decode
    (`interpreter.cpp:586-587`, `CScriptNum(vch, fRequireMinimal, 5)`) is
    outside the cell, so `n` is an arbitrary int64.  The real decode range is
    -(2^39-1) <= n <= 2^39-1, a strict subset of the proved domain.
    Operand decoding is SCR-051/SCR-052, not SCR-126..130.
  - tx version and tx vin[0].nSequence are arbitrary uint32 values.
  - `CTransaction::version` is modelled as uint32_t because that is its type at
    the pin (`primitives/transaction.h:299`); `version < 2` is an unsigned
    comparison on both legs.
  - the stack-underflow guard (`interpreter.cpp:575-577`) is statically false
    in the domain (exactly one operand) and belongs to SCR-051.
postcondition: |
  The opcode leaves the ScriptError ordinal from contract/error_kind.h:

  - flag clear: EQUIV_ERR_OK (0), consensus NOP3 (`break`);
  - operand < 0: EQUIV_ERR_NEGATIVE_LOCKTIME (21);
  - operand bit 31 set: EQUIV_ERR_OK (0), consensus NOP, no checker call;
  - tx version < 2: EQUIV_ERR_UNSATISFIED_LOCKTIME (22);
  - tx vin[0].nSequence disable bit (bit 31) set: 22;
  - masked type disagreement (bit 22 differs after masking with 0x0040ffff): 22;
  - masked operand > masked tx sequence: 22;
  - otherwise: 0.

direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-126, SCR-127, SCR-128, SCR-129, SCR-130
scr_row_coverage: >-
  full — the cell is symbolic over every field the five rows read and exercises
  every branch: the activation NOP, the negative-operand rejection (SCR-126),
  the bit-31 disable-flag NOP that skips the checker entirely (SCR-127), the
  BIP68 version gate (SCR-128), the transaction-side disable-flag rejection
  (SCR-129), and the 0x0040ffff mask with its type-agreement and
  `operand <= masked tx sequence` comparisons (SCR-130), plus the accept path.
  No field of the rule is dropped; the transaction context is modelled exactly
  (uint32 version, uint32 nSequence).  Operand decoding (SCR-051/052), the
  512-second granularity split (SCR-131) and per-input indexing (SCR-132) are
  separate rows and are not claimed here.
patches: none
source_citations:
  - interpreter.cpp:571-603 (case OP_CHECKSEQUENCEVERIFY, incl. :589-590 NEGATIVE_LOCKTIME, :595-596 disable-flag NOP, :599-600 UNSATISFIED_LOCKTIME)
  - interpreter.cpp:1792-1836 (GenericTransactionSignatureChecker::CheckSequence)
  - interpreter.cpp:1800-1801 (tx version < 2 -> false; SCR-128)
  - interpreter.cpp:1807-1808 (tx sequence disable flag -> false; SCR-129)
  - interpreter.cpp:1812-1814 (nLockTimeMask = TYPE_FLAG|MASK; both masks)
  - interpreter.cpp:1825-1833 (type agreement and masked numeric compare; SCR-130)
  - primitives/transaction.h:94 (SEQUENCE_LOCKTIME_DISABLE_FLAG = 1U << 31)
  - primitives/transaction.h:100 (SEQUENCE_LOCKTIME_TYPE_FLAG = 1 << 22)
  - primitives/transaction.h:105 (SEQUENCE_LOCKTIME_MASK = 0x0000ffff)
  - primitives/transaction.h:299-300 (CTransaction::version, nLockTime are uint32_t)
  - interpreter.h:107 + verify_flags.h:25 (SCRIPT_VERIFY_CHECKSEQUENCEVERIFY bit = 1 << 10)
  - "lean: Defs.lean:80-85,235-243,285-297,866-875 @4d62a97e (see src/lean_excerpt.md)"
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp,
  script.h and primitives/transaction.h at the pin, not the whole EvalScript:
  the stack guard and the CScriptNum operand decode are elided (precondition),
  and `break` (NOP / continue) is spelled `return true` with the ScriptError as
  the observable.  L is a reviewed transliteration of the Lean equations
  (`checkSequenceDef`, `dispatchOp` wire 0xb2), not the generated twin:
  `twin/ops_ir.py` has no transaction context and returns
  TWIN_INVALID_UNSUPPORTED on the flag-on path (finding F-LOCKTIME-001).  No
  crypto, hash or signature code is reached, so the same-crypto premise is not
  used.  Alive2 proves C = L over all 2^97 input tuples; SAW proves each leg
  against an independent Cryptol predicate.  This is a bounded opcode cell, not
  a whole-engine equivalence proof.  No Core source patch is used.
evidence:
  - alive2/result.txt (1 correct transformation)
  - saw/result.txt (2 proofs against src/cell.cry)
  - alive2/certificate.sha256, saw/certificate.sha256
---
# `locktime/C-L-csv-op` — OP_CHECKSEQUENCEVERIFY

Core `interpreter.cpp:571-603` + `CheckSequence` (`:1792-1836`) against the
Lean `dispatchOp` wire `0xb2` branch (`Defs.lean:866-875`) and
`checkSequenceDef` (`Defs.lean:285-297`).

Observable: the ScriptError ordinal left behind by the opcode
(`0` continue/NOP, `21` NEGATIVE_LOCKTIME, `22` UNSATISFIED_LOCKTIME).

| branch | condition | ordinal | row |
|---|---|---|---|
| activation off | `!(flags & CSV)` | 0 | (NOP3) |
| negative operand | `n < 0` | 21 | SCR-126 |
| operand disable bit | `n & 0x80000000` | 0 (NOP, checker skipped) | SCR-127 |
| tx version gate | `tx version < 2` | 22 | SCR-128 |
| tx disable bit | `seq & 0x80000000` | 22 | SCR-129 |
| type disagreement | `(seq&m < 1<<22) != (n&m < 1<<22)` | 22 | SCR-130 |
| masked above | `(n&m) > (seq&m)` | 22 | SCR-130 |
| accept | otherwise | 0 | — |

`m = 0x0040ffff = SEQUENCE_LOCKTIME_TYPE_FLAG | SEQUENCE_LOCKTIME_MASK`.

See `notes.md` for commands, elisions and the L-leg provenance.
