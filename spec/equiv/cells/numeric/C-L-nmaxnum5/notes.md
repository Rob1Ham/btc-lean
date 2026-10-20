# numeric/C-L-nmaxnum5

SCR-081 — the `nMaxNumSize = 5` special case and its two call sites
(`interpreter.cpp:556,584` @ `cce32b168`).

## Shape

One bounded element (5 wire bytes + symbolic length), three entry points,
both tools on every entry point:

| entry point | role | Alive2 | SAW |
|---|---|---|---|
| `cell_cltv` | `interpreter.cpp:556-566` call site | C == L | C == spec, L == spec |
| `cell_csv` | `interpreter.cpp:584-600` call site | C == L | C == spec, L == spec |
| `cell_default4` | `nMaxNumSize = 4` control | C == L | C == spec, L == spec |

Observable: `err(6) | value40(40) << 6 | outcome(2) << 46`, where
`err ∈ {0, 4, 21}` is the `ScriptError` ordinal the opcode leaves behind
(`0` = continue, `4` = SCRIPT_ERR_SCRIPTNUM, `21` = SCRIPT_ERR_NEGATIVE_LOCKTIME),
`value40` is the exact two's-complement 40-bit decoded number (0 on a decode
error), and `outcome ∈ {0,1,2}` is `0` = stop, `1` = continue to the
locktime/sequence checker, `2` = CSV disable-flag NOP.

## Why the 5-byte width is observable

The width is not just a longer accept set:

- `+2^31` is `00 00 00 80 00` on the wire and `-2^31` is `00 00 00 80 80`;
  both are *minimal* (top byte minus sign bit is zero, second byte 0x80 has
  its high bit set) and both are rejected at the default width 4.
- CSV's `SEQUENCE_LOCKTIME_DISABLE_FLAG` is bit 31, so the NOP branch of
  `interpreter.cpp:595-596` is only reachable through a 5-byte operand.
- the largest accepted value is `2^39-1 = 0x7fffffffff`, carried in
  `value40` rather than truncated to 32 bits.

`md` (fRequireMinimal, `interpreter.cpp:442`) is a full symbolic `uint32`,
so the minimality guard — including the `+-255` exception and the redundant
5-byte encodings — is proved in both settings.

## Legs

- C: `src/c_leaf.cpp`, line-cited excerpt of `interpreter.cpp:556-566`,
  `584-600`, `1236-1238`, `script.h:242,246-271,287,376-391`,
  `primitives/transaction.h:94`.  The vector/throw is the bounded element and
  the error return; `break` is the observable outcome.
- L: `src/l_leaf.cpp`, reviewed transliteration of `decodeScriptNum` /
  `decodeBE` / `minimalOkBE` / `setVchBE` (`Numeric/Interface.lean:45-47`,
  `Numeric/ScriptNum.lean`) and the two `dispatchOp` branches
  (`Interpreter/Defs.lean:857-875`).  The twin's `decode_num`
  (`twin/runtime.inc:167-188`) is the same algorithm but loops over the
  symbolic length; the exact-length cases here are its unrolled form.
- Spec: `src/cell.cry`, written from the Core source and the Lean equations,
  independent of both legs.

## Results

```
alive2/result.txt   3 comparisons: "Transformation seems to be correct!",
                    1 correct transformations each, 0 Alive2 errors
saw/result.txt      6 x "Proof succeeded!", no "Proof failed"
                    (bitwuzla backend, SAW 1.6 / 68eed5f)
vectors/result.txt  22 call-site + 4 default-4 finite vectors, 0 failures
```

Finite vectors cover: empty operand; `01`; `81`; negative zero `80`
(accepted at `md=0`, rejected at `md=1`); `ff00`/`ff80` (+-255);
`00 80 00` (32768); the 4-byte max; the 5-byte `+-2^31` and `+-(2^39-1)`;
the redundant 5-byte encodings `00 00 00 00 00`, `ff ff ff 7f 00` and
`00 00 00 00 80` (rejected at `md=1`) against `00 00 00 80 80`, which is
accepted because the second byte's high bit is set; a 6-byte operand; a
`uint32`-max length; and the default-4 contrast on the same length-5
operand.

## Commands

```sh
cd spec/equiv/cells/numeric
./C-L-nmaxnum5/vectors/run.sh "$PWD/C-L-nmaxnum5"
./C-L-nmaxnum5/alive2/run.sh "$PWD/C-L-nmaxnum5"
./C-L-nmaxnum5/saw/run.sh    "$PWD/C-L-nmaxnum5"

# certificate verification (from the repository root)
sha256sum -c spec/equiv/cells/numeric/C-L-nmaxnum5/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/numeric/C-L-nmaxnum5/saw/certificate.sha256
sha256sum -c spec/equiv/cells/numeric/C-L-nmaxnum5/vectors/certificate.sha256
```

`build/` is gitignored; the leaf hashes, tool versions and repo head are in
`build/build.txt` and in the headers of the three `result.txt` files.

## Notes

- Two Cryptol type errors were found while writing the spec (unsized literals
  in a `[40]` context, and `not`/`!` not being available in this Cryptol
  version).  Both were spec-side errors fixed before any proof was accepted;
  the semantics did not change.
- SAW reports `Unused name: b4` on `prev` (the second-top byte of a 5-byte
  operand is b3, never b4) and `Redeclaration of mC/mL` between the three
  `llvm_load_module` blocks; both are benign and identical in kind to earlier
  numeric cells.
- Prior art: commit `3f207ba` on the unmerged `wave16/06-numeric-scriptnum`
  branch has `numeric/scriptnum-width5` (`cell_w5`), which proves the width-5
  *decode primitive* with `fRequireMinimal` fixed to false and cites the call
  sites.  This cell is independent of it, keeps the minimality guard
  symbolic, and slices both call-site bodies, so the width is tied to the
  opcode decisions Core actually makes.  The ledger line for SCR-081 at this
  base still reads "gap"; regenerating the ledger is an orchestrator step
  (this task makes no shared edits).
