# wave64 / 18-scr-083 — SCR-083 negative zero

## Result

SCR-083 is covered by one bounded C-vs-Lean cell with **both tools green**:

| tool | result |
|---|---|
| Alive2 v20.0 (LLVM 20.1.2) | 2/2 direction checks correct (L ⊑ C and C ⊑ L) |
| SAW 1.6 (`z3`) | 2/2 proofs (C leg and L leg against one independent Cryptol model) |
| concrete spot check | C and L byte-identical on 13 corner vectors |

Cell: `spec/equiv/cells/numeric/C-L-w64-negzero`.

## Row

- **SCR-083** — `0x80 → 0; CastToBool(0x80)=false`,
  `script.h:387-390@cce32b168`.
- Coverage: **full for the default four-byte CScriptNum operand domain**.
  The root quantifies over every wire vector `b0..b3` and every `uint32`
  length; in-domain lengths are 0..4.
- Both halves are proved symbolically: the negative-zero family
  `80`, `00 80`, `00 00 80`, `00 00 00 80` decodes to 0 and casts false,
  and the `0x80` top-byte exception in `CastToBool` is exact (a `0x80`
  below the top byte is an ordinary magnitude).

## Observable

`cell_negzero(b0,b1,b2,b3,len)` returns
`err(8) | value32(32) << 8 | cast(1) << 40`:

- `len > 4` → `err = 4` (`SCRIPT_ERR_SCRIPTNUM`, the constructor's width
  guard), value 0, cast 0;
- `len == 0` → 0 (empty vector decodes to 0, casts false);
- otherwise `value = set_vch(b0..b[len-1])` and `cast = CastToBool` of the
  same bytes.

## Legs

- **C**: `c_cell.cpp`, line-cited slice of `script.h:246-271`,
  `script.h:376-391` and `interpreter.cpp:46-61` at the pin. Loops fully
  unrolled to the four-byte bound with `i < n` guards; no patch.
- **L**: `l_cell.cpp`, reviewed transliteration of
  `Bitcoin.Numeric.setVchBE` (ScriptNum.lean:449-454) and
  `castToBoolList` (:648-652). Big-endian Lean list vs little-endian wire
  is the only bridge; not `mk_leaf.py` output (its bounded decode is
  two-byte-only).
- **Spec**: `saw/cell.cry`, written independently from the two source
  functions.

## Evidence

- `alive2/result.txt`, `alive2/certificate.sha256`
  (`STATUS=alive2-green (2 direction checks)`).
- `saw/result.txt`, `saw/certificate.sha256`
  (`STATUS=saw-green (2 proofs for 1 root(s) x 2 legs)`,
  marker `CELL_W64_NEGZERO_SAW_GREEN`).
- `ir/` — tracked textual IR of both legs and both extracted roots, plus
  `ir/build.txt`. The SAW runner byte-compares the bitcode it loads against
  `ir/*.ll` before proving; certificates hash tracked files only.
- `concrete_check.out` — 13 corner vectors, output identical for both legs.

## Bounds

- Four-byte CScriptNum operand cap (default `nMaxNumSize = 4`). Elements
  longer than four bytes are not in the domain: the five-byte CLTV/CSV
  operand (SCR-081) and arbitrary-length `CastToBool` are not claimed.
- No opcode execution, no serialization (`getvch`/SCR-082) and no
  minimality rule (SCR-084) is modelled; those are other rows.
- No Core patch, pin change, twin change, ledger edit or shared-tool edit.

## Reproduction

From the worktree root:

```sh
bash spec/equiv/cells/numeric/C-L-w64-negzero/alive2/run.sh
bash spec/equiv/cells/numeric/C-L-w64-negzero/saw/run.sh
bash spec/equiv/cells/numeric/C-L-w64-negzero/_tools/concrete_check.sh
sha256sum -c spec/equiv/cells/numeric/C-L-w64-negzero/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/numeric/C-L-w64-negzero/saw/certificate.sha256
```
