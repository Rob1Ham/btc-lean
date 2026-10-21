# notes — C-L-w32-opname-table

Row: SCR-173 (display/name table; consensus: false).

## What is proved

`cell_opname(w)` over every wire byte compares two independent transcriptions
of the opcode-name table:

- `src/core_names.txt` — the `case` labels and string literals of
  `script.cpp:19-157` `GetOpName`;
- `src/lean_names.txt` — the `opNameWire` equations of
  `PDW68.lean:253-405`.

The build assigns ids from the union of both name sets, so a byte whose name
differs between the tables gets a different id and Alive2 reports it. The
generator does not compare the tables; `src/check_names.py` is only a
reviewer convenience.

The important edges, all exercised:

- `0x01..0x4b` direct pushes: **no** case, fall through to `OP_UNKNOWN`.
  (`Script.cpp` has no `case` for direct-push bytes; PDW68 records the same
  push-opcode gap.)
- `0xbb..0xfe`: **no** case, `OP_UNKNOWN`.
- `0xff`: named `OP_INVALIDOPCODE` (one of only two bytes above `0xba` with a
  name).
- the fifteen disabled bytes `0x7e..0x99` all have `OP_*` names.

Named bytes = 113, unnamed = 143 (the generator's `check_names.py` prints the
counts). This replaces the old `opNameKnown` domain predicate (`w <= 0xba ∨
w = 0xff`) with the concrete table, including the push-gap correction recorded
in PDW68.

## What is not covered

- Display strings are encoded as ids; the byte-for-byte string data lives in
  the two data files and the generated Cryptol table, not in the proof
  obligation.
- `GetOpName` is not used by consensus; this cell makes no execution claim.
- `ScriptToAsmStr`/`FormatScript` callers are not modelled.

## Tool note

`llvm-extract` on the two modules yields switch-based functions with no
globals, so Alive2 compares them directly. SAW checks each against
`build/cell.cry`, generated from the Core table.
