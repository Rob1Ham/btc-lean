# tapscript/C-L-w64-tap-codesep-byteseq

## Shape of the cell

Both legs walk a **six-byte symbolic script** with a symbolic
per-parsed-opcode `fExec` mask:

- C: `src/c_leaf.cpp` — `interpreter.cpp:431-446`, `1058-1066` and
  `script.cpp:313-363` (`GetScriptOp`) at pin `cce32b168`.
- L: `src/l_leaf.cpp` — `Defs.lean:601-604,1031-1032,1145-1150,1171` and
  `Ops.lean:50-78` (`getOpAt`).
- Spec: `src/cell.cry` — independent Cryptol restatement of the same rules.

State: `(pc, opcodeIndex, codeSep, codeSepPos, bad)`.
The packed observable (cell harness) exposes `codeSepPos` (32 bits),
`codeSep` (4), `opcodeIndex` (4), the separation bit, the parse-failure bit,
and the final cursor.

## What is proved

For every six-byte script and every mask:

1. `codeSepPos` starts at `0xFFFFFFFF`.
2. An executed `0xab` sets `codeSepPos` to the 0-based parsed-opcode index
   and `codeSep` to the byte offset just after the opcode; an unexecuted
   `0xab` changes neither.
3. `opcodeIndex` advances once per *parsed* opcode, including unexecuted
   ones and multi-byte pushes.
4. `sepOk`: no executed separator ⇒ `codeSep = 0 ∧ codeSepPos = 0xFFFFFFFF`;
   otherwise `codeSep > codeSepPos`.  The legacy byte offset and the
   tapscript opcode index are never equal.
5. A truncated push (all four `GetScriptOp` push forms are modelled) sets the
   failure bit and stops the walk.

The domain contains the Lean witness `pushTwoBytes; OP_CODESEPARATOR`
(`02 aa bb ab .. ..`), where the observable is `codeSep = 4`,
`codeSepPos = 1`, `sepOk = 1` — the same values as
`PDW47.codesep_index_vs_byteoffset_witness` / `codesep_byteoffset_witness`.

## Bounds and premises

- Bound: six script bytes, ≤ six parsed opcodes, direct pushes of ≤ four
  bytes before a separator (longer pushes cannot fit), PUSHDATA1/2/4 payloads
  only as far as six bytes allow.
- `fExec` is an input mask, not a `vfExec` derivation.
- The pre-checks before the separator arm (SCRIPT_SIZE, PUSH_SIZE, OP_COUNT,
  disabled ops, CONST_SCRIPTCODE) are premises.
- Neither tool runs the Core loop; the six iterations are unrolled.

## Reproduce

```sh
spec/equiv/cells/tapscript/C-L-w64-tap-codesep-byteseq/alive2/run.sh
spec/equiv/cells/tapscript/C-L-w64-tap-codesep-byteseq/saw/run.sh
spec/equiv/cells/tapscript/C-L-w64-tap-codesep-byteseq/mutant/run.sh
```

Alive2 lane ≈ 2 min (SMT timeout 180 s, both directions proved), SAW lane
≈ 3 min (two symbolic proofs, `z3`).  `alive2/certificate.sha256` and
`saw/certificate.sha256` hash every tracked input of the cell plus the raw
`result.txt` transcript; no `build/` path is included.

## Mutation control

`mutant/run.sh` copies the sources to `build-mutant/`, rewrites the L leaf's
executed-separator arm from `codeSep = nx` to `codeSep = opcodeIndex`, and
re-runs both lanes.  A correct cell must fail both; `mutant/result.txt`
records the observed counterexamples.  This is evidence that the symbolic
contracts are not vacuous, not a claim about the mutant.

## Residual

The row stays **partial**: the mask is assumed, the script is six bytes, and
the pre-checks are not modelled.  The next step is an eight-byte bound with
an explicit symbolic `vfExec` walk feeding the mask.
