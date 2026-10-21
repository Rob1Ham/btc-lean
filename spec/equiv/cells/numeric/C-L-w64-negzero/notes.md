# numeric/C-L-w64-negzero — notes

Row: SCR-083 (`0x80` decodes to 0; `CastToBool(0x80) = false`), a bounded
C-vs-Lean cell with both tools green.

## Commands actually run

Run from the worktree root `/tmp/opencode/wave64/18-scr-083`:

```sh
bash spec/equiv/cells/numeric/C-L-w64-negzero/alive2/run.sh
bash spec/equiv/cells/numeric/C-L-w64-negzero/saw/run.sh
bash spec/equiv/cells/numeric/C-L-w64-negzero/_tools/concrete_check.sh
sha256sum -c spec/equiv/cells/numeric/C-L-w64-negzero/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/numeric/C-L-w64-negzero/saw/certificate.sha256
```

## What is proved

One root, `cell_negzero(b0, b1, b2, b3, len)`, over every four-byte wire
vector and every uint32 length:

```text
bits  0..7    err    = 4 iff len > 4 (SCRIPT_ERR_SCRIPTNUM), else 0
bits  8..39   value  = set_vch(b0..b[len-1]), sign-extended int32
bit   40      cast   = CastToBool(b0..b[len-1])
```

- **Negative zero decodes to 0.** `0x80` is the sign bit on the
  most-significant (wire-last) byte; when the magnitude is zero the
  `-((int64_t)(result & ~sign))` arm produces 0. This holds for every
  negative-zero encoding within the four-byte cap:
  `80`, `00 80`, `00 00 80`, `00 00 00 80` (little-endian on the wire).
- **CastToBool(0x80) is false.** The interpreter's loop returns false when
  the only nonzero byte is `0x80` in the top position. The same holds for
  the empty vector.
- **The exception is exact.** A `0x80` byte below the top position, or a
  zero top byte with a nonzero lower byte, is an ordinary true value:
  `80 00` decodes to +128 and casts true; `ff 80` decodes to -255 and casts
  true.
- **The width guard is the only failure.** Lengths 5 and above return
  error 4 before any byte is interpreted, matching the constructor's
  `vch.size() > nMaxNumSize` check.

## Legs

- C: `c_cell.cpp`, line-cited slice of `script.h:246-271`, `script.h:376-391`
  and `interpreter.cpp:46-61` at `cce32b168`. The loops are fully unrolled to
  the constant four-byte bound with `i < n` guards; the byte accesses are
  constant-indexed, the `~(0x80 << 8*(n-1))` mask keeps the source's symbolic
  shift.
- L: `l_cell.cpp`, a reviewed transliteration of the pinned Lean equations
  `Bitcoin.Numeric.setVchBE` (ScriptNum.lean:449-458) and
  `castToBoolList` (:648-652). Lean's lists are big-endian, so the top byte is
  the wire-last byte; `magOfBE` of the tail is the little-endian `lower`
  accumulation. It is not `mk_leaf.py` output: the shared generator's bounded
  decode is two-byte-only, which cannot express this row's 3- and 4-byte
  negative-zero encodings.
- Spec: `saw/cell.cry`, written from the two source functions, independent of
  both C++ legs. `packed` is the only shared harness (in
  `_tools/negzero_common.h`).

## Tool results

- Alive2 `/opt/equiv-tools/alive-tv-v20.0` (v20.0, LLVM 20.1.2) on the
  tracked textual IR, both directions: 2/2 `Transformation seems to be
  correct`, 0 incorrect, 0 failed-to-prove, 0 Alive2 errors.
- SAW 1.6 (`68eed5f`) with solver `z3`, `llvm_verify` on
  `build/c_leaf.bc` and `build/l_leaf.bc`: 2/2 `Proof succeeded!`, no
  `Proof failed`, marker `CELL_W64_NEGZERO_SAW_GREEN`.
- The SAW runner disassembles both bitcode modules and byte-compares them with
  the tracked `ir/*.ll` before proving, so the certificate hashes the modules
  that were actually verified.
- `concrete_check.sh` compiles the same driver against each leg and requires
  byte-identical output; the 13 vectors are in `concrete_check.out`.

## Certificates

`alive2/certificate.sha256` and `saw/certificate.sha256` list **tracked**
inputs only: `spec.md`, `buildspec`, `c_cell.cpp`, `l_cell.cpp`, the
cell-local `_tools/` harness, the tracked `ir/` modules and `ir/build.txt`,
the SAW spec/script, and the raw `result.txt`. They never list `build/`
(gitignored), so `sha256sum -c` succeeds from a fresh checkout.

## Bounds

The cell covers the default four-byte CScriptNum operand domain (lengths
0..4). It does **not** cover elements longer than four bytes: the five-byte
CLTV/CSV operand (SCR-081) and arbitrary longer stack elements for
CastToBool. The only nontrivial negative-zero vector named by the row is the
one-byte `0x80`, which is in domain; the length 1..4 family is proved as the
natural closure. No other row is claimed.
