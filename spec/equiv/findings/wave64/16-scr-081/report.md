# wave64 / 16-scr-081 — SCR-081 `nMaxNumSize = 5` special case

**Task.** Build a minimal three-leg cell for the `nMaxNumSize = 5` special
case *and its call sites*, or file a precise blocker.  Real Alive2 + SAW, raw
logs, tracked-input certificates.

**Verdict: cell built, both tools green, coverage `full` for SCR-081's
check.**  No blocker was needed.

| | |
|---|---|
| Row | SCR-081 — "nMaxNumSize=5 special case", check "5-byte limit for CLTV/CSV" |
| Core ref | `interpreter.cpp:556,584@cce32b168` |
| Pin | `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` |
| Base | `5946c02` (`wave64/16-scr-081`) |
| Cell | `spec/equiv/cells/numeric/C-L-nmaxnum5/` |
| Commit | the commit that adds this report (single commit on the branch) |
| Patches | none |
| Shared edits | none (only this cell and this finding are added) |

## What the row asks for, and what was proved

Core keeps `CScriptNum`'s default operand limit at 4 bytes
(`script.h:242`) but asks for **5** at exactly two call sites:

```cpp
// interpreter.cpp:556  (OP_CHECKLOCKTIMEVERIFY)
const CScriptNum nLockTime(stacktop(-1), fRequireMinimal, 5);
// interpreter.cpp:584  (OP_CHECKSEQUENCEVERIFY)
const CScriptNum nSequence(stacktop(-1), fRequireMinimal, 5);
```

The cell models those two call sites, not just the decode primitive: the
decode is followed by the branches Core actually takes on the decoded value
(`:561-562` negative locktime, `:595-596` CSV disable-flag NOP), so the extra
width is observable rather than cited.

Three entry points, one observable layout
`err(6) | value40(40) << 6 | outcome(2) << 46`:

| entry | Core slice | proved |
|---|---|---|
| `cell_cltv` | `interpreter.cpp:556-566` | decode at width 5, `SCRIPT_ERR_SCRIPTNUM` (4) on failure, `NEGATIVE_LOCKTIME` (21) on `d < 0`, else continue to `CheckLockTime` |
| `cell_csv` | `interpreter.cpp:584-600` | same, plus `outcome 2` when `d & (1<<31)` (disable-flag NOP), else continue to `CheckSequence` |
| `cell_default4` | `script.h:242,246-271` | width-4 control: the same length-5 operand is rejected (the "special case" contrast) |

All inputs symbolic: `len : uint32` (full range — the width guard precedes
every byte read), `b0..b4 : i8`, and `md : uint32` (`fRequireMinimal =
flags & MINIMALDATA`, `interpreter.cpp:442`), so the minimality guard is
proved in both settings, including the `+-255` exception and the redundant
5-byte encodings.

Observable facts proved universally:

1. `len > 5` ⇒ `err 4` (SCRIPT_ERR_SCRIPTNUM), at both call sites.
2. `len <= 5` ⇒ the exact LE sign-magnitude value, carried as a 40-bit
   two's-complement pattern, so the reach `[-(2^39-1), 2^39-1]` is observed
   and not truncated to 32 bits.  Examples proved (and replayed in the
   vectors): `00 00 00 80 00` = `+2^31`, `00 00 00 80 80` = `-2^31`,
   `ff ff ff ff 7f` = `2^39-1`.
3. `d < 0` ⇒ `err 21`; CSV `d & (1<<31)` ⇒ NOP (`outcome 2`).  Bit 31 is
   only reachable through a 5-byte operand, which is precisely why the width
   exists.
4. At `nMaxNumSize = 4` the same length-5 operand is rejected ⇒ the
   special case is proved by contrast, not asserted.

### Exact bounds (what is *not* claimed)

- Activation flag-off NOPs (`:534-536`, `:573-575`) are outside the cell —
  rows SCR-072/SCR-127.
- Stack-underflow guards (`:539`, `:578`) are outside — SCR-051/SCR-078.
- `CheckLockTime`/`CheckSequence` and the transaction context are outside —
  SCR-122..SCR-126, SCR-129.  The cell stops at the branch that calls them.
- The minimal-encoding rule as a row of its own is SCR-084; here it is
  modelled only as the constructor argument Core passes at these sites.
- Bounded element: 5 bytes.  Longer real elements (>5, up to 520) all take
  the width-guard reject, which *is* proved.

## Evidence (raw logs, all in-tree)

```
spec/equiv/cells/numeric/C-L-nmaxnum5/
  alive2/result.txt      1039 lines, 3 comparisons:
                         "Transformation seems to be correct!" x3,
                         "1 correct transformations" x3,
                         "0 Alive2 errors" x3, STATUS=alive2-green
  saw/result.txt         6 x "Proof succeeded!" (3 entry points x C,L),
                         no "Proof failed", bitwuzla, STATUS=saw-green
  vectors/result.txt     22 call-site + 4 default-4 hand-computed Core
                         vectors, C and L, failures=0, STATUS=vectors-green
  alive2/certificate.sha256   spec.md, notes.md, alive2/run.sh, src/build.sh,
                              src/c_leaf.cpp, src/l_leaf.cpp,
                              contract/error_kind.h,
                              Numeric/ScriptNum.lean, Numeric/Interface.lean,
                              Interpreter/Defs.lean, spec/db/rules.yaml,
                              alive2/result.txt
  saw/certificate.sha256      same set + src/cell.cry, src/cell.saw,
                              saw/result.txt
  vectors/certificate.sha256  vectors/run.sh, src/vectors.cpp,
                              src/{c,l}_leaf.cpp, vectors/result.txt
```

All three certificates verify from the repository root with `sha256sum -c`
(ran after the final edit of `spec.md`/`notes.md`).  `build/` is gitignored;
leaf hashes, tool versions and the base commit are in `build/build.txt` and in
the `result.txt` headers.

Tools: `alive-tv` (Ubuntu LLVM 20.1.2), `clang++-20` 20.1.2, SAW 1.6
(`68eed5f release-1.6`) with the `bitwuzla` backend.  No solver timeouts, no
retries: Alive2 ~4 s wall, SAW ~2 s wall.

## Method notes

- C leg: line-cited excerpt of Core at the pin (`interpreter.cpp:556-566`,
  `584-600`, `1236-1238`, `script.h:242,246-271,287,376-391`,
  `primitives/transaction.h:94`).  The `std::vector` operand is the bounded
  5-byte element; the `throw` is the error return the real catch block maps to
  SCRIPT_ERR_SCRIPTNUM; `break` is the `outcome` field.  Every dynamic
  index/shift is a constant case (the width guard already rejects `len > 5`).
- L leg: reviewed transliteration of `decodeScriptNum`/`decodeBE`/
  `minimalOkBE`/`setVchBE` and the two `dispatchOp` branches.  The generated
  twin's `decode_num` (`twin/runtime.inc:167-188`) is the same algorithm but
  loops over the symbolic length; the exact-length cases are its unrolled
  form, cross-checked by the finite vector driver.
- Spec: `src/cell.cry` is written from Core and the Lean equations, not from
  either leg; SAW proves each leg against it, so a shared C/L transcription
  error cannot pass.  The vector driver additionally pins both legs to
  hand-computed Core values.
- Two spec-side Cryptol errors were found and fixed before any proof was
  accepted (unsized literals in a `[40]` context; `not` is not available in
  this Cryptol version).  Neither changed the stated rule.

## Relation to prior work

Commit `3f207ba` on the unmerged `wave16/06-numeric-scriptnum` branch contains
`numeric/scriptnum-width5` (`cell_w5`): a green decode-primitive cell with
`fRequireMinimal` fixed to `false` that cites the call sites.  That branch is
not an ancestor of this base, and the ledger here still records SCR-081 as a
gap (`findings/coverage/F-E6-GAPS.md:248`).  This cell is independent of it,
keeps `fRequireMinimal` symbolic, and slices both call-site bodies (including
the CSV disable-flag NOP and the default-4 contrast).

## Orchestrator follow-ups (not done here: shared files)

1. Regenerate the coverage ledger / matrix so SCR-081 moves from gap to the
   green set with this cell as evidence
   (`spec/equiv/results/matrix.md`, `findings/coverage/F-E6-GAPS.md`,
   `docs/STATE.md` and the derived STATUS files).
2. Optionally add the cell to `spec/equiv/cells/INDEX.md`.

## Reproduce

```sh
cd spec/equiv/cells/numeric
./C-L-nmaxnum5/vectors/run.sh "$PWD/C-L-nmaxnum5"
./C-L-nmaxnum5/alive2/run.sh "$PWD/C-L-nmaxnum5"
./C-L-nmaxnum5/saw/run.sh    "$PWD/C-L-nmaxnum5"
cd ../../..
sha256sum -c spec/equiv/cells/numeric/C-L-nmaxnum5/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/numeric/C-L-nmaxnum5/saw/certificate.sha256
sha256sum -c spec/equiv/cells/numeric/C-L-nmaxnum5/vectors/certificate.sha256
```
