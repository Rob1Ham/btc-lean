# F-DIV-001 — Lean eager `parseWire` vs Core's streaming `GetOp`

- **status:** **confirmed by execution** (2026-10-19); open, disposition = domain seam
- **legs:** L, C
- **cells:** base-script parse/error family (E1); any cell whose input can
  contain a malformed tail
- **severity for the claim:** affects **error kind only** for scripts that
  fail to parse; accept/reject agrees (both reject).

## Symptom

`Bitcoin/Interpreter/Defs.lean:1163-1176` (`evalScriptBytes`) calls
`parseWire b` on the whole script and returns `.badOpcode` on `none` *before*
`evalFrom` executes any opcode. Core's `EvalScript`
(`src/script/interpreter.cpp:406-570` at the pin) calls `GetOp` inside the
execution loop, so an earlier runtime error is reported before a later
truncated push is ever decoded.

Concrete candidates:

| script bytes | Core | Lean |
|---|---|---|
| `69 02 01` (`OP_VERIFY`, truncated PUSH2) | `INVALID_STACK_OPERATION` | `BAD_OPCODE` |
| `7e 02 01` (disabled `OP_CAT`, truncated PUSH2) | `DISABLED_OPCODE` | `BAD_OPCODE` |

Both legs return "reject" (result 0); only `error_kind` differs.

## Evidence

- Lean: `Defs.lean:1163-1176` (`parseWire` before `evalFrom`),
  `Defs.lean:421-431` (`parseWire` is all-or-nothing).
- Core: `interpreter.cpp:406-570` at `cce32b168` (`GetOp` per loop
  iteration; `set_error(SCRIPT_ERR_BAD_OPCODE)` only when the current decode
  fails).
- The Lean tree already documents the same all-or-nothing limitation for the
  BIP342 OP_SUCCESSx pre-pass (`Defs.lean:467-475`), where a separate
  byte-order scanner (`opSuccessScanFrom`) was added. No equivalent scanner
  exists for the base/witness-v0 `EvalScript` error path.

## Execution confirmation (2026-10-19)

Run through ABI v2 `equiv_entry` on the two built libraries (`ctypes`, same
`legacy_tx()` tape builder as `tools/tests/e0_triple.py`; empty scriptSig,
flags 0):

| scriptPubKey | C `(result, kind)` | L `(result, kind)` | Core kind | Lean kind |
|---|---|---|---|---|
| `69 02 01` (`OP_VERIFY`, truncated `PUSH2`) | `(0, 18)` | `(0, 16)` | INVALID_STACK_OPERATION | BAD_OPCODE |
| `7e 02 01` (disabled `OP_CAT`, truncated `PUSH2`) | `(0, 17)` | `(0, 16)` | DISABLED_OPCODE | BAD_OPCODE |
| `69 4c` (`OP_VERIFY`, truncated `PUSHDATA1`) | `(0, 18)` | `(0, 16)` | INVALID_STACK_OPERATION | BAD_OPCODE |
| `75 04 de ad` (`OP_DROP`, truncated `PUSH4`) | `(0, 18)` | `(0, 16)` | INVALID_STACK_OPERATION | BAD_OPCODE |
| `51 02 01` (`OP_1`, truncated `PUSH2`) | `(0, 16)` | `(0, 16)` | BAD_OPCODE | BAD_OPCODE |

The fifth row is the control: when the decode error is reached before any
runtime error, both legs agree. The first four are genuine C-L error-kind
divergences (accept/reject agrees: both return 0).

Artifacts:

- C `/tmp/opencode/cbuild/libequiv-core.so`, sha256
  `5fef1df004adae637ffd7d3d7bf7dc96700c552dc2c22729d0de06d81457fbb5`.
- L `spec/equiv/twin/build/libtwin.so`, sha256
  `9d787f1beaf2214a5bb47d925526dc19e8b308ed2f64c52ba9e2b95c033516ce`.
- Core ordinals: `contract/error_kind.h` (BAD_OPCODE 16, DISABLED_OPCODE 17,
  INVALID_STACK_OPERATION 18).

This is why the 1,258-row corpus differential did not expose the seam: none
of its rows carries a truncated tail after an earlier runtime error. A green
cell must not be used to claim this family is covered.

## Disposition

1. **Do not patch the Lean model** (constraint).
2. E1 cells that include malformed tails must either
   - restrict the cell precondition to scripts whose full `parseWire`
     succeeds (then the two decoders agree op-for-op), or
   - be recorded `unjudged-seam` with this finding as the named blocker.
3. E3's error-enum equality excludes malformed-tail inputs unless Core and
   Lean are reconciled; the accept/reject relation is unaffected.
4. **Execution done** (above). The four divergent rows should be added to a
   dedicated seam lane, not to the green corpus denominator: they are
   evidence that the seam exists, not failures to hide. The Ledger must carry
   them as `unjudged-seam` (or a `gap`) with this finding id.

## Notes

This is a **model** finding, not a twin bug. The generated twin deliberately
mirrors Lean (`twin/generator.md` §5). A twin that mirrored Core here would
no longer be a faithful L leg; it would hide the divergence instead of
recording it.
