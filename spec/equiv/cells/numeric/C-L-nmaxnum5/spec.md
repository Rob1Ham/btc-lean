---
# Cell numeric/C-L-nmaxnum5
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 5946c02
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: numeric/C-L-nmaxnum5
family: numeric
tool_status: both-green (symbolic over every uint32 operand length, five symbolic wire bytes, and every fRequireMinimal value)
precondition: |
  - base sigversion; one transaction input.  The CLTV/CSV activation bit is
    on: the flag-off NOP paths are SCR-072/SCR-127, not this row.
  - the stack holds exactly one element (the operand), so the
    stack-underflow guard (interpreter.cpp:539, :578) is statically false;
    that guard is SCR-051/SCR-078.
  - the operand is the wire element itself: length `len` is a full uint32 and
    the five bytes b0..b4 are symbolic.  The width guard runs before any byte
    is read, so lengths 6..2^32-1 are covered by the same leaf.
  - fRequireMinimal is symbolic (interpreter.cpp:442: it is
    `flags & SCRIPT_VERIFY_MINIMALDATA`); both settings of the minimality
    guard are therefore proved, not assumed.
  - the two call sites are separate entry points: `cell_cltv` slices
    interpreter.cpp:556-566 and `cell_csv` slices interpreter.cpp:584-600.
  - `cell_default4` is the same operand decoded at CScriptNum's default
    nMaxNumSize = 4 (script.h:242); it exists only to prove the length-5
    contrast and claims no SCR-079/SCR-080 coverage.
postcondition: |
  Define d = CScriptNum(operand, fRequireMinimal, 5) (script.h:246-271,
  376-391) and err = 0 unless construction throws scriptnum_error, which
  EvalScript's catch maps to SCRIPT_ERR_SCRIPTNUM (4)
  (interpreter.cpp:1236-1238, contract/error_kind.h EQUIV_ERR_SCRIPTNUM=4).

  - len > 5: err 4, value observable 0.
  - len <= 5 and fRequireMinimal and the top byte minus its sign bit is zero
    and (len <= 1 or the second-top byte's high bit is clear): err 4,
    value observable 0.  This keeps the +-255 exception and rejects the
    5-byte redundant encodings (e.g. `00 00 00 00 00`, `00 00 00 80 80` is
    *accepted* because the second byte 0x80 has its high bit set).
  - otherwise d is the little-endian sign-magnitude value; the observable
    carries its exact two's-complement 40-bit pattern (so the 5-byte reach
    up to +-(2^39-1) is observed, not truncated to 32 bits), and
      * CLTV (interpreter.cpp:561-562): d < 0 => err 21
        (SCRIPT_ERR_NEGATIVE_LOCKTIME), outcome 0; else err 0, outcome 1
        (continues to CheckLockTime — the comparison is SCR-124).
      * CSV (interpreter.cpp:589-596): d < 0 => err 21, outcome 0; else if
        (d & CTxIn::SEQUENCE_LOCKTIME_DISABLE_FLAG) != 0 => err 0, outcome 2
        (the opcode is a NOP); else err 0, outcome 1 (continues to
        CheckSequence — the comparison is SCR-129).
  - at nMaxNumSize = 4 the same operand of length 5 is rejected with err 4,
    which is exactly the special case SCR-081 records.

  packed observable: err(6) | value40(40) << 6 | outcome(2) << 46.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-081
scr_row_coverage: >-
  full for the row's check ("5-byte limit for CLTV/CSV").  Both Core call
  sites of the nMaxNumSize = 5 constructor are modelled and proved for every
  uint32 length, every five-byte wire vector and every fRequireMinimal value:
  the accept boundary at length 5, the SCRIPT_ERR_SCRIPTNUM reject for
  length > 5, the exact decoded value over the whole [-(2^39-1), 2^39-1]
  reach (two's-complement 40-bit observable), and the two consumers that
  make the extra width observable — CLTV's negative-locktime rejection and
  CSV's SEQUENCE_LOCKTIME_DISABLE_FLAG NOP, whose trigger bit 31 is only
  reachable through a 5-byte operand.  The default-4 control proves the
  contrast (the same length-5 operand is rejected at nMaxNumSize = 4).
  Excluded, and owned by other rows: the activation flag-off NOPs
  (SCR-072/SCR-127), the stack-underflow guards (SCR-051/SCR-078), the
  minimal-encoding rule stated as its own row (SCR-084 — modelled here only
  as part of the constructor argument), and the CheckLockTime/CheckSequence
  comparisons with the transaction context (SCR-122..SCR-126, SCR-129).
patches: none
source_citations:
  - interpreter.cpp:532-568 (case OP_CHECKLOCKTIMEVERIFY; :556 the CScriptNum(...,5) construction, :561-562 NEGATIVE_LOCKTIME, :565 checker call)
  - interpreter.cpp:571-600 (case OP_CHECKSEQUENCEVERIFY; :584 the CScriptNum(...,5) construction, :589-590 NEGATIVE_LOCKTIME, :595-596 disable-flag NOP, :599 checker call)
  - interpreter.cpp:442 (fRequireMinimal = flags & SCRIPT_VERIFY_MINIMALDATA)
  - interpreter.cpp:1233-1238 (catch scriptnum_error => SCRIPT_ERR_SCRIPTNUM)
  - script.h:242 (nDefaultMaxNumSize = 4)
  - script.h:246-271 (CScriptNum(vch, fRequireMinimal, nMaxNumSize): width guard, minimality guard with the +-255 exception)
  - script.h:376-391 (set_vch: LE sign-magnitude, sign bit on the top byte)
  - script.h:287 (CScriptNum::operator&(int64_t))
  - primitives/transaction.h:94 (SEQUENCE_LOCKTIME_DISABLE_FLAG = 1u << 31)
  - contract/error_kind.h:25,29,54,55 (EQUIV_ERR_OK=0, SCRIPTNUM=4, NEGATIVE_LOCKTIME=21, UNSATISFIED_LOCKTIME=22)
  - "lean: Numeric/Interface.lean:45-47 (decodeScriptNum), Numeric/ScriptNum.lean decodeBE / minimalOkBE / setVchBE, Interpreter/Defs.lean:629-632 (decodeNum) and :857-875 (CLTV/CSV branches)"
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core interpreter.cpp,
  script.h and primitives/transaction.h at the pin, not the whole EvalScript:
  the std::vector operand is the bounded 5-byte element of the leaf, the
  throw is the error return that the real catch block turns into
  SCRIPT_ERR_SCRIPTNUM, `break` is spelled as the observable outcome, and
  every dynamic index/shift is a constant case (the width guard already
  rejects lengths above 5 before any byte is read).  L is a reviewed
  transliteration of the pinned Lean equations (decodeBE / minimalOkBE /
  setVchBE / decodeNum / the two dispatchOp branches), not generated twin
  code: twin/runtime.inc:167-188 decode_num is the same algorithm but loops
  over a symbolic length, which Alive2/SAW would have to reason about as a
  loop; the exact-length cases are the unrolled form, asserted by the finite
  vector driver.  The independent Cryptol model in src/cell.cry states the
  rule directly from script.h/interpreter.cpp; SAW proves each leg against
  it, so a shared C/L transcription error cannot pass unnoticed (and the
  known-answer vectors cross-check both legs against hand-computed Core
  values).  No crypto, hash or signature code is reached, so the same-crypto
  premise is not used.  This is a bounded call-site cell, not a whole-engine
  equivalence proof.  No Core source patch is used.
evidence:
  - alive2/result.txt (3 comparisons, each 1 correct transformation, 0 Alive2 errors)
  - saw/result.txt (6 proofs against src/cell.cry, one per entry point per leg)
  - vectors/result.txt (22 call-site + 4 default-4 finite known-answer vectors, 0 failures)
  - alive2/certificate.sha256, saw/certificate.sha256, vectors/certificate.sha256
---
# `numeric/C-L-nmaxnum5` — the nMaxNumSize = 5 special case and its call sites

SCR-081 ("5-byte limit for CLTV/CSV", `interpreter.cpp:556,584@cce32b168`).

Core keeps the default `CScriptNum` operand limit at 4 bytes but asks for
**5** at exactly two call sites, the `OP_CHECKLOCKTIMEVERIFY` and
`OP_CHECKSEQUENCEVERIFY` operand decodes:

```cpp
// interpreter.cpp:556
const CScriptNum nLockTime(stacktop(-1), fRequireMinimal, 5);
// interpreter.cpp:584
const CScriptNum nSequence(stacktop(-1), fRequireMinimal, 5);
```

The extra byte exists so a 32-bit `nLockTime`/`nSequence` that needs a sign
byte still decodes; the admitted range is `[-(2^39-1), 2^39-1]`
(`interpreter.cpp:542-555`).

## What this cell proves

Each entry point is a leaf with the same signature
`uint64_t f(uint32_t len, uint8_t b0..b4, uint32_t md)` returning
`err(6) | value40(40) << 6 | outcome(2) << 46`:

| entry point | Core slice | observable |
|---|---|---|
| `cell_cltv` | `interpreter.cpp:556-566` | `err 4` on a decode failure, `err 21` on a negative operand, otherwise `outcome 1` (continues to `CheckLockTime`) |
| `cell_csv` | `interpreter.cpp:584-600` | as above, plus `outcome 2` when `nSequence & (1<<31)` is set (the disable-flag NOP) |
| `cell_default4` | `script.h:242,246-271` | width-4 control: the same operand decoded at `nMaxNumSize = 4` (`err 4` at length 5) |

`md` is `fRequireMinimal`, so the minimality guard is proved in both
settings.  `value40` is the exact two's-complement 40-bit pattern of the
decoded number, so the extra reach of the 5-byte decode is observable: the
largest accepted value is `2^39-1 = 0x7fffffffff`, not `2^31-1`.

## Branches, with the rows they belong to

| condition | err | outcome | row |
|---|---|---|---|
| `len > 5` | 4 | 0 | **SCR-081** |
| non-minimal under `md` | 4 | 0 | SCR-084 (modelled as the constructor argument) |
| `d < 0` | 21 | 0 | SCR-122 / SCR-126 |
| CSV and `d & (1<<31)` | 0 | 2 (NOP) | SCR-081 observable / CSV dispatch |
| otherwise | 0 | 1 (checker) | SCR-124 / SCR-129 |

The two outcomes that follow the decode are kept because they consume the
decoded value; the checker comparisons themselves are not modelled and are
not claimed.

## Limits

- Both activation flag-off NOPs (SCR-072/SCR-127) and the stack-underflow
  guards (SCR-051/SCR-078) are outside this cell.
- `CheckLockTime`/`CheckSequence` and the transaction fields are outside it
  (SCR-122..SCR-126, SCR-129).
- The operands are a bounded 5-byte element; a real element may be up to
  `MAX_SCRIPT_ELEMENT_SIZE = 520` bytes, but every length above 5 takes the
  width-guard reject, which is the proved branch.
