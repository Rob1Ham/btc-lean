---
# Cell locktime/C-L-locktime-input-index-general
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 8142cff0ed6ea6edd448b609817d2a706ab5e057
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: locktime/C-L-locktime-input-index-general
family: locktime
tool_status: both-green (CheckLockTime and CheckSequence over an arbitrary-length vin and an arbitrary uint32 index; Lean induction over List TxIn)
precondition: |
  - the checker bodies only: `OP_CHECKLOCKTIMEVERIFY`/`OP_CHECKSEQUENCEVERIFY`
    dispatch, the flag checks, the stack guard and the CScriptNum decode are
    outside the cell (SCR-122..130 and SCR-051/052 own them); the cell starts
    at `GenericTransactionSignatureChecker::CheckLockTime` (`:1754`) and
    `CheckSequence` (`:1791`).
  - an arbitrary `vin`: a pointer to a run of `nSequence` fields of any length,
    with `nIn` any uint32 (Core's `unsigned int`).  Alive2 models a pointer
    argument's allocation size as nondeterministic, so an in-range `nIn` is
    checked for every vin length; the index is fully symbolic, not a boolean.
  - the `txTo->vin[nIn]` access carries Core's `assert(nIn < vin.size())`
    (consensus callers guarantee the index).  The cell materialises that
    assert as `nIn < len`, which is exactly Lean's `List.getD` guard
    (`Rules.lean:92-95`); on the reachable domain `nIn < len` the read is the
    verbatim `txTo->vin[nIn]`, and out of range the getD default input's
    sequence (0) is used.  `cltv_raw`/`csv_raw` keep the verbatim read and a
    harness domain guard, and are proved equal to the Lean environment.
  - `txTo->version` and `txTo->nLockTime` are the real uint32 fields
    (`primitives/transaction.h:299-300`); version is read only by
    CheckSequence, nLockTime only by CheckLockTime, and the other field is
    held at a constant.
  - operand >= 0.  The opcode rejects a negative operand before the checker
    (`interpreter.cpp:582-584` NEGATIVE_LOCKTIME for CLTV, `:589-590` for
    CSV), so the cell's domain is the opcode-reachable set.  The harness
    returns the sentinel -1 for operand < 0 on both legs.
  - no `fRequireMinimal`/pol flags, no witness sigversion, no crypto.
postcondition: |
  For every vin of any length, every `nIn`, and every
  `(nLockTime or version, operand, selected sequence, default sequence)`:

  - C and L agree on both checker bodies: `cell_cltv_general` =
    `locktimeEnvOf` + `checkLockTimeDef`, `cell_csv_general` =
    `locktimeEnvOf` + `checkSequenceDef`, for an arbitrary-length vin and any
    uint32 index.  In range that environment's `txSequence` is exactly
    `vin[nIn].sequence`; out of range it is the `getD` default (`0`).
  - locality: for two arbitrary vins `a`, `b` and the same `len`, `nIn` and
    `def`, `selected(a) = selected(b)` implies the same verdict.  Changing any
    input other than `nIn` -- in fact changing every other input and the
    length, as long as the `nIn < len` side is the same -- cannot change the
    verdict.  This is what `cltv_ni`/`csv_ni` prove.
  - the getD fallback: the selected sequence depends on the length only
    through `nIn < len` (`getd_len`); when `nIn >= len` every length returns
    the default and no slot is read.
  - at the model level, `src/GeneralIndex.lean` proves for an arbitrary
    `List TxIn`: the lookup's access trace is exactly `[nIn]` in range and
    `[]` out of range (`vinReads_eq`), no other index ever occurs
    (`vinReads_subset`), the environment carries `vin[nIn].sequence` in range
    and the default out of range, and `checkLockTime_perInput_row` /
    `checkSequence_perInput_row` hold for any two transactions that agree on
    version, locktime and the selected sequence (or are both out of range).
    This is an induction over the list, not a bounded instance.

  The verdict is 1/0; the `-1` operand sentinel is harness text.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-132
scr_row_coverage: >-
  full for the row's general statement ("CheckLockTime/Sequence see only input
  nIn"): the arbitrary-length vin is closed by the Lean induction over List
  TxIn (`src/GeneralIndex.lean`: `vinReads_eq`, `vinReads_subset`,
  `locktimeEnvOf_txSequence_of_lt`, `locktimeEnvOf_txSequence_default`,
  `locktimeEnvOf_eq_of_selected`, `checkLockTime_perInput_row`,
  `checkSequence_perInput_row`, `checkLockTime_outOfRange`,
  `checkSequence_outOfRange`), and the compiled checkers are proved equal over
  an arbitrary-length vin pointer and an arbitrary uint32 index by Alive2.  The
  out-of-range getD fallback is part of the statement, not an exclusion.  The
  earlier two-input cell proves the vin.length = 2 instance; this cell's
  `checkLockTime_twoInput_is_special_case` records that the two-input
  statement is a special case of the general one, not a relabelling of it.
  Alive2's pointer argument has a nondeterministic input-block size, so the
  C/L body transforms (`cltv`, `csv`, `cltv_raw`, `csv_raw`), the two-vin
  non-interference products (`cltv_ni`, `csv_ni`) and the getD
  length-irrelevance transform (`getd_len`) quantify over every vin length at
  every in-range index.  SAW independently re-proves both legs and both
  non-interference products against `src/cell.cry` at a disclosed 16-slot
  symbolic bound (symbolic 4-bit index and symbolically long length); that
  bound is a second-tool cross-check, not the general-length argument.  The
  Core body is the cited excerpt; Core's `vin[nIn]` has an `assert` in debug
  builds and is consensus-unreachable out of range, which is why the getD
  fallback is a totalisation (both legs implement the same guard).
patches: none
source_citations:
  - interpreter.cpp:1754-1788 (GenericTransactionSignatureChecker::CheckLockTime; :1785 vin[nIn] final test)
  - interpreter.cpp:1791-1796 (CheckSequence reads txTo->vin[nIn].nSequence and txTo->version)
  - interpreter.cpp:1797-1836 (CheckSequence body)
  - interpreter.cpp:582-584,589-590 (opcode NEGATIVE_LOCKTIME guards)
  - primitives/transaction.h:94,100,105,115 (BIP68 constants; SEQUENCE_FINAL at :95)
  - primitives/transaction.h:277-300 (CTransaction fields)
  - script.h:47-48 (LOCKTIME_THRESHOLD = 500000000)
  - script.h:227-291 (CScriptNum operators used)
  - "lean: Defs.lean:235-243,272-283,285-297; Rules.lean:89-129 @4d62a97e (see src/lean_excerpt.md)"
  - "List.getD / List.getElem semantics: Lean 4.35.0 core (used by src/GeneralIndex.lean)"
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp,
  script.h and primitives/transaction.h at the pin, not the whole engine: the
  opcode preamble, the stack/index guards, the operand decode and all
  signature/hash code are elided, each named in the precondition.  L is a
  reviewed transliteration of `locktimeEnvOf` + `checkLockTimeDef` /
  `checkSequenceDef`, not the generated twin; the twin has no transaction
  context and rejects flag-on CSV/CLTV (`twin/ops_ir.py:44-58`, finding
  F-LOCKTIME-001).  The general-vin closure is the Lean induction in
  `src/GeneralIndex.lean`, which imports the pinned model unchanged and is
  new in this cell; Alive2 proves the compiled C/L checkers over an
  arbitrary-length vin pointer, an arbitrary uint32 index and the getD
  fallback, and SAW independently re-proves the two legs and the two-vin
  non-interference product at a disclosed 16-slot bound.  The vin slot stride
  is modelled by the sequence field only (slot identity, not CTxIn byte
  layout).  No Core source patch is used.
evidence:
  - alive2/result.txt (7 correct transformations: body, raw body, non-interference and getD-length, for CLTV and CSV)
  - saw/result.txt (8 proofs: 2 legs x 2 checkers general, 2 legs x 2 checkers two-vin non-interference)
  - lean/result.txt (#print axioms, no sorryAx)
  - alive2/certificate.sha256, saw/certificate.sha256, lean/certificate.sha256
---
# `locktime/C-L-locktime-input-index-general` — the checkers are per-input for any vin

Core `GenericTransactionSignatureChecker::CheckLockTime`
(`interpreter.cpp:1754-1788`) and `CheckSequence` (`:1791-1836`) against the
Lean environment rule `locktimeEnvOf` and its per-input theorems
(`Interpreter/Rules.lean:89-129`), for an **arbitrary-length** input list.

SCR-132's content is the `nIn` dependency:

| checker | transaction data read | per-input? |
|---|---|---|
| `CheckLockTime` | `txTo->nLockTime` (whole tx) + `txTo->vin[nIn].nSequence` (one slot) | the final-sequence test is per-input; Core comments that testing this vin alone is sufficient |
| `CheckSequence` | `txTo->version` (whole tx) + `txTo->vin[nIn].nSequence` (one slot) | the relative lock is per-input |

The earlier cell `locktime/C-L-locktime-input-index` built a two-input
transaction with a boolean index.  That proves the row only for
`vin.length = 2`; this cell closes the general case:

1. **Lean induction over `List TxIn` (`src/GeneralIndex.lean`).** `vinReads`
   is an inductive access-trace model of the `getD` lookup.  `vinReads_eq`
   proves by induction that for an arbitrary list the trace is `[nIn]` in
   range and `[]` out of range; `vinReads_subset` says no other index can
   occur.  `locktimeEnvOf_txSequence_of_lt` / `_default` give the exact
   environment component in each case.  `locktimeEnvOf_eq_of_selected` and
   the two `*_perInput_row` theorems then say: any two transactions that
   agree on version, locktime and the selected sequence -- or are both
   out of range -- have the same verdict, whatever their other inputs,
   outputs and witnesses are.  `#print axioms` shows no `sorryAx`.
2. **Alive2 over an arbitrary-length vin.** The leaves take a pointer and a
   `uint32` index.  Alive2's input-block size for a pointer argument is
   nondeterministic, so `cltv`/`csv` (totalised C vs Lean getD), `cltv_raw`/
   `csv_raw` (verbatim `txTo->vin[nIn]` vs Lean), `cltv_ni`/`csv_ni`
   (two arbitrary vins agreeing on the selected slot) and `getd_len`
   (length matters only through `nIn < len`) are checked for every vin
   length at every in-range index.
3. **SAW cross-check.** Both legs and both non-interference products are
   re-proved against the independent Cryptol predicate `src/cell.cry`
   (16 symbolic slots, symbolic 4-bit index, symbolically long length,
   getD fallback included).

`src/lean_excerpt.md` reproduces the statements and axiom lines.  `notes.md`
has the exact commands, hashes and the disclosed SAW bound.
