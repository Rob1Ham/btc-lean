# numeric/C-L-scriptnum-signext-exception

SCR-084 (CScriptNum minimality sign-extension exception): `+255` encodes to
`0xff00` and `-255` to `0xff80`, and **both are minimal**; the extra byte is
required because the magnitude's high bit would otherwise be read as the
sign.  This cell proves the exception and its role in the minimality
predicate on both tools.

## Source

Pinned Core `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`:

- `src/script/script.h:246-271` — `CScriptNum(const std::vector<unsigned
  char>&, bool fRequireMinimal, size_t nMaxNumSize = 4)`.  The guard at
  252-268 rejects a payload whose top byte has `(top & 0x7f) == 0` unless
  `size > 1` **and** the second-most-significant byte has `0x80` set.  The
  comment at 260-264 names `+-255` / `0xff00` / `0xff80`.
- `src/script/script.h:342-373` — `serialize` (`getvch`): canonical
  little-endian sign-magnitude.  When the magnitude's top byte has `0x80`
  set, an extra `0x00` (positive) or `0x80` (negative) byte is appended.
- `src/script/script.h:376-391` — `set_vch`: LE magnitude, top-byte `0x80`
  as sign, cleared from the magnitude before negation.

Lean source of record: `Numeric/Interface.lean:45-54`
(`decodeScriptNum`, `encodeScriptNum`), the row theorem
`scriptNum_sign_extension_255` at `Numeric/Interface.lean:222-231`, and
`Numeric/ScriptNum.lean:493-500,534` (`minimalOkBE`, `scriptNumBE`).
Imperative twin: `spec/equiv/twin/runtime.inc:141-157` (`encode_num`) and
`167-188` (`decode_num`).

## Symbolic claim

Two entry points, each compiled on both legs and checked by Alive2
(bidirectional) and by SAW against `src/cell.cry`:

1. `cell_signext_roundtrip(mag, neg)` — for every rank-8 magnitude
   `m = mag & 0xff` and sign bit, serialize `+-m` and decode it with
   `fRequireMinimal = true`, `nMaxNumSize = 4`.  The observable carries the
   decoded verdict, error ordinal, exact length and bytes, the 16-bit
   two's-complement value, the real guard's acceptance, the no-exception
   guard's acceptance, and whether a sign-extension byte was appended.
   Proved: the bytes are exactly

   | magnitude | wire bytes |
   |---|---|
   | `m = 0` | empty (`n = 0`) |
   | `1 <= m < 128`, positive | `m` |
   | `1 <= m < 128`, negative | `m \| 0x80` |
   | `128 <= m <= 255`, positive | `m, 0x00` |
   | `128 <= m <= 255`, negative | `m, 0x80` |

   the real guard accepts all of them, the decoded value is `+-m`, and the
   no-exception guard accepts exactly the `m < 128` encodings.  The two
   named vectors are the `m = 255` instances:

   ```text
   +255  ok=1 err=0 n=2 b0=0xff b1=0x00 v16=0x00ff real=1 strict=0 sx=1
   -255  ok=1 err=0 n=2 b0=0xff b1=0x80 v16=0xff01 real=1 strict=0 sx=1
   +127  ok=1 err=0 n=1 b0=0x7f b1=0x00 v16=0x007f real=1 strict=1 sx=0
   -127  ok=1 err=0 n=1 b0=0xff b1=0x00 v16=0xff81 real=1 strict=1 sx=0
   +128  ok=1 err=0 n=2 b0=0x80 b1=0x00 v16=0x0080 real=1 strict=0 sx=1
   -128  ok=1 err=0 n=2 b0=0x80 b1=0x80 v16=0xff80 real=1 strict=0 sx=1
   ```

   (`v16` is the 16-bit two's-complement image; `0xff01` is -255.)

2. `cell_signext_pred(two, b0, b1)` — for every one- and two-byte payload
   (`n = 1 + (two & 1)`), report the real guard and the no-exception guard.
   Proved: `real = ((top & 0x7f) != 0) || (n == 2 && (b0 & 0x80) != 0)` and
   `strict = ((top & 0x7f) != 0)`.  Concrete instances:

   ```text
   0xff00 -> real=1 strict=0
   0xff80 -> real=1 strict=0
   0x7f00 -> real=0 strict=0
   ```

   The third row shows that a second byte alone is not enough: the
   predecessor must have its `0x80` bit set.  The first two are exactly the
   clause the exception adds.

The `strict` bit is a counterfactual harness evaluation of the guard with
the exception removed; it is not engine code.  The `real` bit is produced by
the actual `CScriptNum`/`decode_num` path.  SAW's model (`src/cell.cry`)
states both predicates independently of either leg.

## Bounds

- `fRequireMinimal = true`, `nMaxNumSize = 4`; `fRequireMinimal = false`
  is the separate SCR-050 cell.
- The magnitude is rank-8 (`|value| <= 255`), so the encoder's
  `while (absvalue)` loop is exactly one iteration and the decoder sees
  `n <= 2` bytes.  Payload lengths > 2 and magnitudes > 255 are **not**
  covered; they are also not what the row or its two vectors state.
- Negative-zero decoding (`0x80`, SCR-083) is outside this cell; `m = 0`
  is covered only as the encoder's empty output.
- The cell is the `CScriptNum` primitive.  No numeric opcode call site,
  stack operation or error mapping (`EvalScript`'s catch) is exercised.
- `nMaxNumSize = 5` (CLTV/CSV) is not re-run; the guard's shape does not
  depend on the width once `n <= 2`, and SCR-081/SCR-051 own that call-site
  story.

## Commands

```sh
cd spec/equiv/cells/numeric/C-L-scriptnum-signext-exception
./alive2/run.sh "$PWD"
./saw/run.sh    "$PWD"
```

Both runners call `src/build.sh`, which uses clang++-20 `-O1`, extracts one
module per entry point and records tool/source hashes in `build/build.txt`.
Alive2 is run `--bidirectional --smt-to=60000`; SAW 1.6 runs four proofs
(two entry points x two legs) against the Cryptol model.

## Raw tails

`alive2/result.txt` (two entry points, each `--bidirectional`):

```text
Transformation seems to be correct!

These functions seem to be equivalent!

Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

`saw/result.txt`:

```text
Proof succeeded! cell_signext_roundtrip
Proof succeeded! cell_signext_roundtrip
Proof succeeded! cell_signext_pred
Proof succeeded! cell_signext_pred
CELL_NUMERIC_SIGNEXT_SAW_GREEN
STATUS=saw-green
```

SAW warns that `n` and `b1` (in `top2`) and `neg` (in `encN`) are unused in
those helpers; all three are still symbolic inputs to the legs and are used
elsewhere in the model.

## Sensitivity check (not a tracked result)

A scratch copy of the C leg with the exception replaced by `if (true)`
(i.e. reject any top byte with `(top & 0x7f) == 0`, with no predecessor
test) fails the same SAW model immediately:

```text
----------Counterexample----------
  mag: 4294967175        # 0xffffff87 -> low byte 0x87, sign positive
  neg: 4294967294        # even -> positive
----------------------------------
Proof failed.
```

`0x87 0x00` is a canonical +135 encoding; the mutant rejects it because the
exception clause was removed.  The mutated source is not committed and no
tracked input depends on it.  This is the operational form of the
`strict` bit: removing the clause breaks values the encoder produces.

## Trust and reproduction

- Alive2 v20.0 and SAW 1.6 at the pins in `spec/equiv/PINS.lock`; raw output
  is `alive2/result.txt` and `saw/result.txt`.
- Certificates hash the tracked cell inputs, the shared
  `contract/error_kind.h`, `twin/runtime.inc`, `spec.md`, `notes.md` and the
  raw result, so a fresh checkout can replay them.
- No Core, Lean, twin, contract or shared-tool edit is made.  `patches:
  none`.
- C and L are both bounded transcriptions of the same rule, as the repo's
  cell model requires; the independent Cryptol predicate is what rules out a
  shared transcription error for the guarded property.  The two encoders
  use different absolute-value expressions (`~x + 1` in C,
  `-(v + 1) + 1` in the twin), so their Alive2 equivalence is not a
  syntactic self-comparison.
