# tapscript/C-L-w32-tap-codesep-pos

## What is proved

Over a bounded, pre-decoded four-opcode stream with symbolic `pend`,
`kind` (push/op), wire byte, push payload length and `fExec` bit:

- `codeSepPos` starts at `0xFFFFFFFF`;
- `opcode_pos` increments by exactly one per *parsed* opcode, so a push of
  `len` bytes consumes `1+len` script bytes but one opcode slot;
- an unexecuted opcode still consumes a slot (and an unexecuted
  `OP_CODESEPARATOR` records nothing);
- an executed `OP_CODESEPARATOR` records the current 0-based index; the
  last executed one wins.

Alive2 checks the C↔L pair; SAW checks each leg against the independent
Cryptol `walk`.

## Why the row is partial

The stream is an input to the cell, so the byte-level parse (`GetScriptOp`)
and the `vfExec` stack are premises. The cell therefore proves the counter
and the assignment in isolation, not "the EvalScript loop over real script
bytes". That is the same parse seam as F-DIV-001 / SCR-045.

Also out of scope: `pbegincodehash` (the *byte offset* used by the legacy
scriptCode path, `interpreter.cpp:1064`) — this cell observes only
`opcode_pos`; the SCRIPT_VERIFY_CONST_SCRIPTCODE pre-check; and scripts
longer than four opcodes.

Next experiment: add a bounded `GetScriptOp` advance leaf over ≤8 concrete
script bytes and run the counter over that, which removes the parse
premise without claiming the whole loop.
