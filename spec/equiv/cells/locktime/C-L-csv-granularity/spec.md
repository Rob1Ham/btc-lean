---
# Cell locktime/C-L-csv-granularity
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: locktime/C-L-csv-granularity
family: locktime
tool_status: both-green (four symbolic claims covering the SCR-131 split)
precondition: |
  - base sigversion; the SCRIPT_VERIFY_CHECKSEQUENCEVERIFY flag and the
    operand checks are outside this cell (they are SCR-126..130 in
    `locktime/C-L-csv-op`); the CSV opcode has already reached the tail of
    `CheckSequence`.
  - the operand is a *pre-decoded* CScriptNum (`n`, arbitrary int64); operand
    decoding is SCR-051/SCR-052.
  - `txSequence` is an arbitrary uint32.  For the script-level claims the
    version gate and the transaction disable-flag gate have already passed;
    they are proved in `locktime/C-L-csv-op` (SCR-128/129).
  - one transaction input, so the `std::max` fold in `CalculateSequenceLocks`
    (`tx_verify.cpp:94`) is the identity and there is no cross-input
    interaction (per-input indexing is SCR-132).
  - the time-lane coin time and block time are uint32 MTPs.  This is exactly
    the reachable domain: `GetMedianTimePast()` (`chain.h:233`) returns the
    median of `CBlockHeader::nTime` values, each a `uint32_t`, so every MTP is
    one of those 32-bit values.  It also keeps `nCoinTime + masked*512 - 1`
    inside the `int64_t` type Core uses for it.
  - `fEnforceBIP68` is true (the sequence-lock path is entered); the
    `!fEnforceBIP68` early return and `prevHeights` bookkeeping are outside
    the row.
postcondition: |
  Four proven claims, each checked against an independent Cryptol predicate on
  both legs:

  1. `cell_csv_masked` — the script-level verdict uses the *raw* masked values
     (`mask = TYPE_FLAG|MASK = 0x0040ffff`, no scaling): 0 (continue) iff the
     masked type bits agree and `nMasked <= txMasked`; otherwise 22
     (UNSATISFIED_LOCKTIME).
  2. `cell_csv_mask_probe` — toggling any subset of bits 16..21 and 23..30 on
     either operand leaves the verdict unchanged: the granularity split lives
     in the masked bits, and the mask discards exactly the rest.
  3. `cell_seq_granularity` — the time-lane relative value is
     `(txSequence & 0x0000ffff) << 9`, i.e. exactly `seqRelative * 512`
     seconds.  This is the 512 = 2^9 split (SCR-131 proper).
  4. `cell_seq_time_ok` — the time lane accepts iff
     `mtpBlock >= mtpParent + seqRelative*512`, and a height-based
     `txSequence` (TYPE_FLAG clear) contributes nothing to the time lane.
     This is `EvaluateSequenceLocks`' `nMinTime >= nBlockTime -> false`
     applied to `nCoinTime + masked*512 - 1`, i.e. the last-invalid `-1`
     convention is the same integer inequality, with no off-by-one.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-131
scr_row_coverage: >-
  full — SCR-131 is the split between the height lane (masked value used
  directly) and the time lane (masked value scaled by 512 seconds).  The cell
  proves all four pieces of that split symbolically: the script-level compare
  deliberately uses the raw masked value (claim 1), the mask is exactly the
  BIP68 payload and nothing outside it can influence the verdict (claim 2),
  the time conversion is `masked << 9` = `masked * 512` (claim 3), and the
  resulting time lock is compared with the last-invalid `-1`/`>=` convention
  against the block MTP with the height-based case contributing nothing
  (claim 4).  Every branch of every function is exercised: the masked compare
  covers all four type-bit combinations and both `>` outcomes, the probe
  covers toggles on both operands, and the time predicate covers both the
  TYPE_FLAG-set and TYPE_FLAG-clear branches.  No value used by the rule is
  left unquantified.  The script-level version/disable gates (SCR-128/129),
  operand decoding (SCR-051/052) and per-input indexing (SCR-132) are separate
  rows and are not claimed here.
patches: none
source_citations:
  - interpreter.cpp:1812-1814 (nLockTimeMask and both masked values)
  - interpreter.cpp:1823-1828 (type agreement on raw masked values)
  - interpreter.cpp:1830-1833 (raw masked numeric compare, no scaling)
  - consensus/tx_verify.cpp:79-94 (time branch; :94 masked << GRANULARITY, minus 1)
  - consensus/tx_verify.cpp:96 (height branch uses the masked value unscaled)
  - consensus/tx_verify.cpp:103-111 (EvaluateSequenceLocks; `nMinTime >= nBlockTime -> false`)
  - primitives/transaction.h:105 (SEQUENCE_LOCKTIME_MASK = 0x0000ffff)
  - primitives/transaction.h:100 (SEQUENCE_LOCKTIME_TYPE_FLAG = 1 << 22)
  - primitives/transaction.h:115 (SEQUENCE_LOCKTIME_GRANULARITY = 9)
  - chain.h:233 (GetMedianTimePast; median of uint32 header times)
  - "lean: DataLaws/Laws.lean:62-64,240,250-252,427-444 and Defs.lean:285-297 @4d62a97e (see src/lean_excerpt.md)"
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp,
  script.h, primitives/transaction.h and consensus/tx_verify.cpp at the pin,
  not the whole engine: the opcode dispatch, the version/disable gates, the
  stack guard, the CScriptNum decode and the multi-input fold are elided, each
  named in the precondition with the row that owns it.  L is a reviewed
  transliteration of the Lean equations (`seqRelative`, `seqIsTimeBased`,
  `seqTimeGranularity_pow`, `seqTimeOk`, `checkSequenceDef` tail), not the
  generated twin, which has no transaction context and rejects the flag-on
  CSV/CLTV paths (`twin/ops_ir.py:44-58`, finding F-LOCKTIME-001).  No crypto,
  hash or signature code is reached.  Alive2 proves C = L for every input of
  each of the four slices; SAW proves each leg against an independent Cryptol
  predicate.  This is a bounded rule cell, not a whole-engine proof.  No Core
  source patch is used.
evidence:
  - alive2/result.txt (4 correct transformations, one per claim)
  - saw/result.txt (8 proofs against src/cell.cry)
  - alive2/certificate.sha256, saw/certificate.sha256
---
# `locktime/C-L-csv-granularity` — BIP68 512-second granularity (SCR-131)

Core `CheckSequence`'s raw masked compare (`interpreter.cpp:1812-1833`) and
`CalculateSequenceLocks`/`EvaluateSequenceLocks`' time lane
(`tx_verify.cpp:79-94`, `:103-111`) against the Lean `seqRelative`,
`seqIsTimeBased`, `seqTimeOk` and `seqTimeGranularity_pow`
(`Laws.lean:240,250-252,427-444`).

The split SCR-131 names:

| lane | Core | Lean |
|---|---|---|
| height | `nCoinHeight + (int)(seq & MASK) - 1` (`tx_verify.cpp:96`) | `seqHeightLock` |
| time | `nCoinTime + (int64_t)((seq & MASK) << 9) - 1` (`:94`) | `mtpParent + seqRelative s * 512` |
| script | compare raw `seq & (TYPE_FLAG\|MASK)` (`interpreter.cpp:1824,1832`) | `checkSequenceDef` tail |

The time value is the masked payload times 512 (= 2^9).  The script-level
comparison does *not* scale: it compares the masked values as they are,
because both sides are in the same domain; the time conversion happens only
when the masked value is turned into an absolute coin time.

See `notes.md` for commands and the branch-by-branch argument.
