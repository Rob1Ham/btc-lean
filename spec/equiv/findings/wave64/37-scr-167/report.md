# wave64 / 37-scr-167 — SCR-167 `m_codeseparator_pos` and the legacy byte offset

**Row:** SCR-167 (tapscript, `BIP342`)
**Cell:** `spec/equiv/cells/tapscript/C-L-w64-tap-codesep-byteseq`
**Base:** `5946c02` (`integrate checksig scriptcode, stack-op, pushonly, and 2DIV cells`)
**Pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (Core), `4d62a97e…` (Lean model)
**Legs:** C (Core source slice) and L (Lean transcription); no R leg (out of scope, rbitcoin render path non-proof at the pin).

## Result

| lane | kind | result | certificate |
|---|---|---|---|
| Alive2 | symbolic, bidirectional, `--fail-src-ub` | **green** (1 correct, 0 incorrect, 0 failed, 0 errors) | `alive2/certificate.sha256` |
| SAW | symbolic, both legs vs independent Cryptol | **green** (2/2 proofs) | `saw/certificate.sha256` |
| mutation | L separator arm `codeSep = nx → codeSep = opcodeIndex` | **detected by both lanes** | `mutant/result.txt` |

Both certificates are repo-relative SHA-256 lists over the cell's tracked
inputs plus the raw `result.txt`; no `build/` artifact or absolute path is
included. `normalize_certificates.py --check` reports no difference for this
cell (the only two differences in the tree are the pre-existing
`stack-ops/C-L-pick` certificates, which this work does not touch).

## What is proved (bounded)

Domain: exactly **six symbolic script bytes**, every `GetScriptOp` form
(direct push `OP_0..OP_75`, `PUSHDATA1/2/4`, one-byte opcodes), symbolic
per-parsed-opcode `fExec` mask.  At most six parsed opcodes.

- `codeSepPos` initialises to `0xFFFFFFFF` (`interpreter.cpp:445`).
- An **executed** `OP_CODESEPARATOR` records the **0-based parsed-opcode
  index** in `codeSepPos` (`interpreter.cpp:1065`) and the **byte offset
  immediately after the opcode** (`op.next`) in the legacy `codeSep`
  (`interpreter.cpp:1064`).  An unexecuted separator records nothing.
- `opcodeIndex` increments by exactly one per parsed opcode, executed or not,
  independently of push payload length (`interpreter.cpp:446`, Lean
  `evalFrom`).
- **Separation invariant:** with no executed separator
  `(codeSep, codeSepPos) = (0, 0xFFFFFFFF)`; after any executed separator
  `codeSep ≥ codeSepPos + 1`.  The two fields are never equal, so the legacy
  byte offset is provably *not* the opcode index and vice versa.
- A truncated push sets a failure bit and stops the walk, matching
  `GetScriptOp`/`getOpAt`.

The concrete Lean witness (`pushTwoBytes; OP_CODESEPARATOR`, `op.next = 4`,
index `1`, bytes `02 aa bb ab .. ..`) is in-domain: the cell reports
`codeSep = 4`, `codeSepPos = 1`, `sepOk = 1`, matching
`PDW47.codesep_index_vs_byteoffset_witness` and
`PDW47.codesep_byteoffset_witness`.

## Bounds / residual (row stays PARTIAL)

- Six script bytes, ≤ six parsed opcodes.
- `fExec` is a symbolic input mask; the `vfExec` derivation from
  `IF/ELSE/ENDIF` is a premise.
- The pre-checks before the separator arm (SCRIPT_SIZE, PUSH_SIZE, OP_COUNT,
  disabled opcodes, CONST_SCRIPTCODE) are premises.
- Neither tool executes the Core `EvalScript` loop; the six iterations are
  unrolled, with `-O1` IR and no loop back-edges (checked by
  `opt -passes='print<loops>'` in the Alive2 lane).

This closes the gap the wave32 cell explicitly left open (`pbegincodehash`
and the byte-offset/index separation) for the bounded domain, but it does not
claim the whole loop or the pre-checks.  `spec.md` carries
`scr_row_coverage: partial` for that reason.

## Reproduction

```sh
spec/equiv/cells/tapscript/C-L-w64-tap-codesep-byteseq/alive2/run.sh   # ~2 min
spec/equiv/cells/tapscript/C-L-w64-tap-codesep-byteseq/saw/run.sh      # ~2.5 min
spec/equiv/cells/tapscript/C-L-w64-tap-codesep-byteseq/mutant/run.sh   # ~4 min, expects failure
```

## Integration notes (orchestrator, not done here)

No shared files were edited: `spec/db/equiv-cells.yaml`, `rules.yaml`,
`results/matrix.md` and `results/LEDGER-REPORT.md` are untouched.  To wire the
row, add the cell to SCR-167's `cells:` list with the two certificate hashes
and the transcript notes (`Transformation seems to be correct!`,
`Proof succeeded! cell_codesep_byteseq`), and keep the row `partial` with the
bounds above.
