---
# Cell locktime/C-L-cltv-op
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: locktime/C-L-cltv-op
family: locktime
tool_status: both-green (symbolic over the whole CLTV opcode rule)
precondition: |
  - base sigversion; one transaction input (nIn = 0); no other script flags.
  - the SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY activation bit is symbolic (both
    off and on are proved).
  - the operand is a *pre-decoded* CScriptNum: the 5-byte decode
    (`interpreter.cpp:557-558`, `CScriptNum(vch, fRequireMinimal, 5)`) is
    outside the cell, so `n` is an arbitrary int64.  The real decode range is
    -(2^39-1) <= n <= 2^39-1, a strict subset of the proved domain, so the
    proof is stronger than the row needs.  The operand-decode rows are
    SCR-051/SCR-052, not SCR-122..125.
  - tx nLockTime and tx vin[0].nSequence are arbitrary uint32 values.
  - the stack-underflow guard (`interpreter.cpp:537-539`) is statically false
    in the domain (exactly one operand) and belongs to SCR-051.
postcondition: |
  The opcode leaves the ScriptError ordinal from contract/error_kind.h:

  - flag clear: EQUIV_ERR_OK (0), consensus NOP2 (`break`);
  - operand < 0: EQUIV_ERR_NEGATIVE_LOCKTIME (21);
  - type mismatch (one side < 500000000, the other >=): 22;
  - operand > tx nLockTime: 22;
  - vin[0].nSequence == 0xffffffff (input final): 22;
  - otherwise: 0.

  Both legs return the same i32 for every symbolic input; the proof is an
  equality of total functions, so L ⊑ C and C ⊑ L coincide.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-122, SCR-123, SCR-124, SCR-125
scr_row_coverage: >-
  full — the cell is symbolic over the operands that decide all four rows and
  exercises every branch of the CLTV opcode path: the activation NOP, the
  negative-operand rejection (SCR-122), the block-height/timestamp type
  agreement at 500000000 (SCR-123), the numeric `operand <= tx nLockTime`
  comparison (SCR-124), and the final-input rejection
  `vin[nIn].nSequence == 0xffffffff` (SCR-125), plus the accept path.  The
  rows' transaction-context fields are modelled exactly (uint32 nLockTime and
  uint32 nSequence); no field of the rule is dropped.  Operand decoding
  (SCR-051/052) and the per-input indexing proof (SCR-132) are separate rows
  and are not claimed here.
patches: none
source_citations:
  - interpreter.cpp:532-568 (case OP_CHECKLOCKTIMEVERIFY, incl. :561-562 NEGATIVE_LOCKTIME and :565-566 UNSATISFIED_LOCKTIME)
  - interpreter.cpp:1755-1788 (GenericTransactionSignatureChecker::CheckLockTime)
  - interpreter.cpp:1764-1768 (type agreement against LOCKTIME_THRESHOLD)
  - interpreter.cpp:1772-1773 (nLockTime > (int64_t)txTo->nLockTime)
  - interpreter.cpp:1785-1786 (CTxIn::SEQUENCE_FINAL == txTo->vin[nIn].nSequence)
  - interpreter.cpp:30-41 (set_success/set_error)
  - script.h:47-48 (LOCKTIME_THRESHOLD = 500'000'000)
  - script.h:227-291 (CScriptNum value and comparison operators)
  - primitives/transaction.h:77 (CTxIn::SEQUENCE_FINAL = 0xffffffff)
  - primitives/transaction.h:299-300 (CTransaction::version, nLockTime are uint32_t)
  - interpreter.h:102 + verify_flags.h:25 (SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY bit = 1 << 9)
  - "lean: Defs.lean:77-79,235-243,272-283,857-865 @4d62a97e (see src/lean_excerpt.md)"
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp,
  script.h and primitives/transaction.h at the pin, not the whole EvalScript:
  the stack guard and the CScriptNum operand decode are elided (stated in the
  precondition), and `break` (continue execution) is spelled `return true`
  with the ScriptError as the observable.  L is a reviewed transliteration of
  the Lean equations (`checkLockTimeDef`, `dispatchOp` wire 0xb1), not the
  generated twin: `twin/ops_ir.py` has no transaction context and returns
  TWIN_INVALID_UNSUPPORTED on the flag-on path (finding F-LOCKTIME-001 in
  findings/wave16/12-locktime/report.md).  No crypto, hash or signature code
  is reached, so the same-crypto premise is not used.  Alive2 proves C = L
  over all 2^129 input tuples; SAW proves each leg against an independent
  Cryptol predicate.  This is a bounded opcode cell, not a whole-engine
  equivalence proof.  No Core source patch is used.
evidence:
  - alive2/result.txt (1 correct transformation)
  - saw/result.txt (2 proofs against src/cell.cry)
  - alive2/certificate.sha256, saw/certificate.sha256
---
# `locktime/C-L-cltv-op` — OP_CHECKLOCKTIMEVERIFY

Core `interpreter.cpp:532-568` + `CheckLockTime` (`:1755-1788`) against the
Lean `dispatchOp` wire `0xb1` branch (`Defs.lean:857-865`) and
`checkLockTimeDef` (`Defs.lean:272-283`).

Observable: the ScriptError ordinal left behind by the opcode
(`0` continue, `21` NEGATIVE_LOCKTIME, `22` UNSATISFIED_LOCKTIME).

| branch | condition | ordinal | row |
|---|---|---|---|
| activation off | `!(flags & CLTV)` | 0 | (NOP2, SCR-127 sibling) |
| negative operand | `n < 0` | 21 | SCR-122 |
| type mismatch | `(txlt < T) != (n < T)` | 22 | SCR-123 |
| above locktime | `n > tx nLockTime` | 22 | SCR-124 |
| input final | `vin[0].nSequence == 0xffffffff` | 22 | SCR-125 |
| accept | otherwise | 0 | — |

See `notes.md` for commands, the elisions, and the L-leg provenance.
