# tapscript/C-L-w32-tap-single-output

## What is proved

For every `hash_type` in 0..255 and every `in_pos`, `vout_size` in
0..2^32-1:

- `hash_type & 3 == 3` (SIGHASH_SINGLE; `hash_type == 0x00` is ALL and does
  not enter this branch) and `in_pos >= vout_size` ⇒ construction fails with
  ordinal 46 (`SCHNORR_SIG_HASHTYPE`);
- the same branch with `in_pos < vout_size` ⇒ construction succeeds and the
  single-output hash is committed;
- every other output type succeeds regardless of the output count.

The error mapping is Core's `interpreter.cpp:1747-1748` and the Lean
`RealChecker.lean:131-132`; the gate itself is `interpreter.cpp:1559-1560`
and `Sighash.lean:219-226`.

## Scope

- `vout.size() < 2^32` is a physical premise (serialization limits).
- The single-output hash *value* is abstracted: this cell proves that a
  hash is committed, not what it is. That is SCR-169's lane.
- The 65-byte explicit-hashtype rejection (SCR-162), hashtype validity
  (SCR-163), and the extension slice (SCR-164) are separate cells.
