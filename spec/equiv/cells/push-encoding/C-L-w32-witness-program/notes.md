# push-encoding/C-L-w32-witness-program

Closes SCR-053 at the predicate level.  The cell is symbolic in the three
inputs the rule reads, not a closed witness.

The C leg is the byte-level core of `CScript::IsWitnessProgram`; the L leg
calls the twin's `is_witness_program` verbatim.  Both are checked by Alive2
against each other and by SAW against an independent Cryptol predicate.

What is *not* in this cell:

- version decoding (`OP_0 -> 0`, `OP_1..OP_16 -> 1..16`, SWT-002);
- copying the program bytes out;
- the VerifyWitnessProgram dispatch (E4 seam).

Those do not change the recognition Boolean, which is the whole of SCR-053.
