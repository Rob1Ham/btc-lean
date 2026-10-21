# F-UB-001 — Core `CScriptNum` signed `int64_t` overflow (analyzed, not reachable)

- **status:** closed — no reachable UB found within the operand-size limits
- **legs:** C, L
- **raised by:** TWIN code reading (`findings/twin/twin-report.md`,
  F-UB-TWIN-001)

## Claim under test

Lean models `ScriptNum` as unbounded `Int` (`Defs.lean:36-40`); Core uses
`int64_t` (`src/script/script.h`, `CScriptNum`). If two operands could drive a
signed `int64_t` operation past `INT64_MAX`/`INT64_MIN`, Core would have C++
signed-overflow UB and Lean/Core could diverge (including across `-O0`/`-O1`).

## Analysis

- `CScriptNum` construction for arithmetic uses `nMaxNumSize = 4`
  (`interpreter.cpp`, arithmetic sites). Any operand longer than 4 bytes is
  rejected with `SCRIPTNUM_OVERFLOW` before the operation.
- A 4-byte sign-magnitude ScriptNum is in `[-2^31+1, 2^31-1]` (the magnitude
  is at most 31 bits; the sign bit uses the top bit of the last byte).
- `ADD`/`SUB`/`1ADD`/`1SUB`/`NEGATE`/`ABS`/`MIN`/`MAX`/`WITHIN` on such
  operands stay within `[-2^32, 2^32]`, far inside `int64_t`.
- `MUL`, `DIV`, `MOD`, `LSHIFT`, `RSHIFT`, `2MUL`, `2DIV` are disabled
  opcodes; they cannot reach the arithmetic.
- `CHECKLOCKTIMEVERIFY`/`CHECKSEQUENCEVERIFY` use `nMaxNumSize = 5`
  (`[-2^39+1, 2^39-1]`), still far inside `int64_t`.
- A result that grows past 4 bytes is pushed as a 5+ byte ScriptNum and is
  rejected by the next 4-byte-limited arithmetic op before overflow could
  accumulate.

## Disposition

No upstream UB issue is warranted for this path. The twin's `int64_t`
representation is correct for Core fidelity; the differential oracle need not
exclude "no-overflow" inputs on account of this finding. If a future opcode
or a 5-byte arithmetic path is added, re-open this analysis.

This is an **analysis**, not a tool run. It closes a flagged risk; it is not
evidence of equivalence.
