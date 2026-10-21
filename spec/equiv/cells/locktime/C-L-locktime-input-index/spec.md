---
# Cell locktime/C-L-locktime-input-index
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: locktime/C-L-locktime-input-index
family: locktime
tool_status: both-green (CheckLockTime and CheckSequence, symbolic over both indices)
precondition: |
  - the checker bodies only: `OP_CHECKLOCKTIMEVERIFY`/`OP_CHECKSEQUENCEVERIFY`
    dispatch, the flag checks, the stack guard and the CScriptNum decode are
    outside the cell (SCR-122..130 and SCR-051/052 own them); the cell starts
    at `GenericTransactionSignatureChecker::CheckLockTime` (`:1754`) and
    `CheckSequence` (`:1791`).
  - a two-input transaction: `vin[0]` and `vin[1]`, both `nSequence` fields
    fully symbolic, and `nIn` a boolean index that is symbolic, so both index
    values and all contents of both slots are covered.  This is the bounded
    two-input instance of the Lean row, which quantifies over any `vin` list
    and any `nIn`; the code reads exactly one slot, so the instance exercises
    the row's only input-access edge.  The `getD` fallback for an out-of-range
    index is never taken (nIn < 2 = vin.length).
  - `txTo->version` and `txTo->nLockTime` are the real uint32 fields
    (`primitives/transaction.h:299-300`); version is read only by
    CheckSequence, nLockTime only by CheckLockTime, and the other field is
    held at a constant.
  - operand >= 0.  The opcode rejects a negative operand before the checker
    (`interpreter.cpp:582-584` NEGATIVE_LOCKTIME for CLTV, `:589-590` for
    CSV), so the cell's domain is the opcode-reachable set.  The harness
    returns the sentinel -1 for operand < 0 on both legs rather than pretending
    the checker sees it; the row is about which *input* is read, not about
    operand decoding.
  - no `fRequireMinimal`/pol flags, no witness sigversion, no crypto.
postcondition: |
  For every `(nLockTime or version, operand, seq0, seq1, nIn)` tuple:

  - `cell_cltv_input_index` equals `checkLockTimeDef (locktimeEnvOf tx nIn) n`
    as 1/0: type agreement between tx nLockTime and the operand at
    LOCKTIME_THRESHOLD, `n <= txLockTime`, and
    `vin[nIn].nSequence != SEQUENCE_FINAL`; the verdict is a function of
    `vin[nIn]` only (CheckLockTime reads `vin[nIn]` for the final test).
  - `cell_csv_input_index` equals `checkSequenceDef (locktimeEnvOf tx nIn) n`:
    unsigned version >= 2, disable flag clear on `vin[nIn].nSequence`, the
    0x0040ffff mask, type agreement at TYPE_FLAG and the masked compare; again
    only `vin[nIn]` is read.

  In both cases the non-selected input's `nSequence` is a free parameter of
  both functions and the L side never mentions it, so the proved equality is
  precisely input locality: swapping or changing any input other than `nIn`
  cannot change the verdict.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-132
scr_row_coverage: >-
  partial — SCR-132's arbitrary-length vin claim is not mechanized; this
  cell proves the bounded two-input instance.  Both checkers are in the cell, the index is symbolic over both
  values of a two-input vin, and the unselected slot is fully symbolic, so the
  proof quantifies over every way the other input can differ.  Every branch of
  both checker bodies is exercised (type agreement both ways, numeric compare
  both ways, SEQUENCE_FINAL set/clear for CLTV; version < 2, disable flag,
  type agreement, masked above/below for CSV) — those branches are shared with
  SCR-122..130 and are proved here again as part of the per-input statement.
  The only bounded dimension is the vin length (2 inputs instead of an
  arbitrary list); the row's single input-access edge `txTo->vin[nIn]` is
  exercised at both possible indices, and longer vins add slots that the
  checker never names.  The general-n induction is not mechanized and is not
  claimed; the two-input instance is what the LLVM cell proves.
patches: none
source_citations:
  - interpreter.cpp:1754-1788 (GenericTransactionSignatureChecker::CheckLockTime; :1785 vin[nIn] final test)
  - interpreter.cpp:1791-1796 (CheckSequence reads txTo->vin[nIn].nSequence and txTo->version)
  - interpreter.cpp:1797-1836 (CheckSequence body)
  - primitives/transaction.h:94,100,105,115 (BIP68 constants; SEQUENCE_FINAL at :95)
  - primitives/transaction.h:277-300 (CTransaction fields)
  - script.h:47-48 (LOCKTIME_THRESHOLD = 500000000)
  - script.h:227-291 (CScriptNum operators used)
  - "lean: Defs.lean:235-243,272-283,285-297; Rules.lean:89-129; PDW33.lean:53,63,75 @4d62a97e (see src/lean_excerpt.md)"
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp,
  script.h and primitives/transaction.h at the pin, not the whole engine: the
  opcode preamble, the stack/index guards, the operand decode and all
  signature/hash code are elided, each named in the precondition.  L is a
  reviewed transliteration of `locktimeEnvOf` + `checkLockTimeDef` /
  `checkSequenceDef`, not the generated twin; the twin has no transaction
  context and rejects flag-on CSV/CLTV (`twin/ops_ir.py:44-58`, finding
  F-LOCKTIME-001).  Alive2 proves C = L on both checker bodies for every input;
  SAW proves each leg against an independent Cryptol predicate that itself
  selects only the nIn-th slot.  The two-input instantiation is the cell's
  stated bound; the general-n statement is the Lean theorem
  `checkLockTime_perInput_row` / `checkSequence_perInput_row`, and the cell is
  its bounded LLVM instance, not a re-proof of the induction.  No Core source
  patch is used.
evidence:
  - alive2/result.txt (2 correct transformations: CLTV and CSV)
  - saw/result.txt (4 proofs, 2 legs x 2 checkers, against src/cell.cry)
  - alive2/certificate.sha256, saw/certificate.sha256
---
# `locktime/C-L-locktime-input-index` — the checkers are per-input (SCR-132)

Core `GenericTransactionSignatureChecker::CheckLockTime`
(`interpreter.cpp:1754-1788`) and `CheckSequence` (`:1791-1836`) against the
Lean environment rule `locktimeEnvOf` and the per-input theorems
(`Interpreter/Rules.lean:89-129`, row face `PDW33.lean:53-85`).

SCR-132's content is the `nIn` dependency:

| checker | transaction data read | per-input? |
|---|---|---|
| `CheckLockTime` | `txTo->nLockTime` (whole tx) + `txTo->vin[nIn].nSequence` (one slot) | the final-sequence test is per-input; Core comments that testing this vin alone is sufficient |
| `CheckSequence` | `txTo->version` (whole tx) + `txTo->vin[nIn].nSequence` (one slot) | the relative lock is per-input |

The cell builds a two-input transaction, keeps both `nSequence` fields and the
index symbolic, and proves that the C bodies equal the Lean functions on
`locktimeEnvOf tx nIn` — an environment built from the selected slot alone.
Because the L side never names the other slot, the equality is exactly the
statement that no other input can influence the verdict.

See `notes.md` for commands and the exact bound.
