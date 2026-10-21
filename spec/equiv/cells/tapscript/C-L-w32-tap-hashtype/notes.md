# tapscript/C-L-w32-tap-hashtype

## What is proved

- **SCR-163** (`interpreter.cpp:1526`). `cell_ht_valid` is checked for all
  256 hashtype bytes in both legs against the Cryptol predicate
  `validHt`, and the C↔L pair is checked by Alive2. The error side is the
  Core mapping at `interpreter.cpp:1747-1748`: a failed preimage
  construction produces `SCRIPT_ERR_SCHNORR_SIG_HASHTYPE` (46).
- **SCR-165** (`interpreter.cpp:1524,1736-1743`). `cell_sig_to_ht` is
  checked over all 2^32 signature sizes and all 2^8 trailing bytes: a
  64-byte signature carries the implicit `SIGHASH_DEFAULT` (0x00) and
  `cell_output_type` shows that DEFAULT normalizes to `SIGHASH_ALL` (=1).
  The 65-byte explicit-byte path and the 45 (`SCHNORR_SIG_SIZE`) path are
  exercised in the same function.

The SAW oracle is written from the row text/BIP341, not copied from either
leg, and both legs are verified against it. The Alive2 run is a direct
C-module vs L-module transformation check (two directions are both
implicit in Alive2's refinement check for these total functions; the
harness also runs the pair source→target as `alive-tv c l`).

## Scope limits (not hidden extensions)

- The signature *body* and the BIP340 verdict are not modelled. The
  checker is never called; this cell covers the hashtype/size normalization
  that precedes `SignatureHashSchnorr`.
- The 65-byte-with-explicit-0x00 rejection is SCR-162's rule, not
  SCR-165's. It is exercised because it is in the same three lines and the
  cell must not silently agree on a wrong answer, but this cell does **not**
  claim SCR-162 coverage.
- `SIGHASH_SINGLE` output existence (SCR-166), the preimage field order /
  epoch / annex (SCR-164, SCR-169), SHA256 and secp256k1 are outside.
- R is not attempted: the pinned rbitcoin lane is documented non-proof
  (F-HARNESS-002, F-TOOL-001).
