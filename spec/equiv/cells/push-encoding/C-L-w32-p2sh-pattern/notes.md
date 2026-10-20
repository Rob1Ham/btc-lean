# push-encoding/C-L-w32-p2sh-pattern

Closes SCR-054 at the predicate level, symbolically.

The C leg is the byte-level core of `CScript::IsPayToScriptHash`; the L leg
calls the twin's `is_p2sh` verbatim.  Alive2 compares the legs and SAW checks
each against an independent Cryptol predicate.

The cell does not exercise the P2SH *dispatch* in VerifyScript (SCR-005..007,
012) or the scriptSig push-only requirement (SCR-006/010); those are separate
rows.
