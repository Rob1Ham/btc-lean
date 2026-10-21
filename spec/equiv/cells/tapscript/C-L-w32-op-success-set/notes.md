# tapscript/C-L-w32-op-success-set

Total, symbolic proof of the BIP342 `IsOpSuccess` byte table (SCR-152).

## Why this is a full row

SCR-152 is a pure set-membership test over one byte.  The cell takes *every*
wire byte 0x00..0xff symbolically (not a witness list) and proves the exact
table, so there is no edge of the row left out: the 87 members and the 169
non-members are both covered by the same symbolic proof, and the SAW spec is an
independent interval-table statement of the same set.

## Three independent formulations

- C: verbatim `IsOpSuccess` body, `script.cpp:365-371`.
- L: reviewed transliteration of Lean `isOpSuccessWire`,
  `Defs.lean:463-468`, in Lean's disjunction order.
- SAW spec: explicit intervals `[80] # [98] # [126..129] # ... # [187..254]`
  in `src/cell.cry`.

## Boundary facts the proof fixes

- OP_RESERVED `0x50` (80) **is** an OP_SUCCESSx.  In base/v0 it is an error
  path; under tapscript the pre-scan makes it success (SCR-153).
- The disabled bytes (0x7e..0x86, 0x8d..0x8e, 0x95..0x99) are all in the set;
  the disabled table and the success table overlap by design (SCR-170/172).
- `0xff` is **not** in the set; `0xfe` (254) is.
- `0x62` = OP_VER (98) is in the set, `0x61` = OP_NOP is not.

## What is not proved

The consequence — that a decoded OP_SUCCESSx makes `ExecuteWitnessScript`
return success before item-size checks and before `EvalScript`, and fails with
DISCOURAGE_OP_SUCCESS under the policy flag — is SCR-153/154, cell
`tapscript/C-L-w32-op-success-prescan`, which composes this predicate with the
following branches over a bounded script length.

## Exact commands

```sh
spec/equiv/cells/tapscript/C-L-w32-op-success-set/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w32-op-success-set/saw/run.sh
cd <repo root> && sha256sum -c spec/equiv/cells/tapscript/C-L-w32-op-success-set/alive2/certificate.sha256
cd <repo root> && sha256sum -c spec/equiv/cells/tapscript/C-L-w32-op-success-set/saw/certificate.sha256
```

## Raw results

`alive2/result.txt` (one correct transformation) and `saw/result.txt` (two
`Proof succeeded!` lines, one per leg).
