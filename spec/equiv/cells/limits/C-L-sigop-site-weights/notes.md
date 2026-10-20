# limits/C-L-sigop-site-weights

SCR-032/033: per-site legacy sigop weights, both tools green over all
256 x 256 opcode pairs and both counting modes.

## Source (pin cce32b168)

- `src/script/script.cpp:159-181` — `CScript::GetSigOpCount(bool)`.
  CHECKSIG/CHECKSIGVERIFY contribute 1 (:168); CHECKMULTISIG/
  CHECKMULTISIGVERIFY contribute `DecodeOP_N(lastOpcode)` when accurate and
  the previous opcode is OP_1..OP_16, else 20 (:173-177).
- `src/script/script.h:35` — `MAX_PUBKEYS_PER_MULTISIG = 20`.
- `src/script/opcode.h` — OP_1 0x51 .. OP_16 0x60; CHECKSIG..VERIFY 0xac..0xaf.
- `spec/core/Bitcoin/Interpreter/SigOps.lean` — `sigOpStep`, `opNumberOf`,
  `isCheckSigWire`, `isCheckMultiSigWire`; the Lean range test is the same
  `1 <= n <= 16` direct-push test.

## Model

The cell is one loop iteration: `weight(lastOpcode, opcode, fAccurate)`.
`lastOpcode` is an `opcodetype` (0..0xff; OP_INVALIDOPCODE is 0xff before the
first site). The script walk and malformed-push termination are not part of
the cell.

L is a reviewed transliteration of the Lean `sigOpStep` arm; the twin has no
generated C handler for the static counter.

## Symbolic claim

- Alive2: `alive-tv` on the two extracted i8 functions, every input.
- SAW: both modules verified against `weight` in `src/cell.cry`, every
  `lastOpcode`, `opcode` and mode byte.

## Commands

```sh
bash spec/equiv/cells/limits/C-L-sigop-site-weights/alive2/run.sh
bash spec/equiv/cells/limits/C-L-sigop-site-weights/saw/run.sh
```

## Limits

- The walk over a script (which sites exist; truncation) is SCR-034/045 and is
  not proved here. This is why the row wording "at each site" matters: the
  per-site rule is complete, the aggregation is separate.
- No Core patch.
