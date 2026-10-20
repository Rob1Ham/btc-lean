# limits/C-L-tapscript-weight

SCR-040 (partial), SCR-041 and SCR-042 (full): the BIP342 validation-weight
budget and the tapscript checksig charge. Both tools green.

## Source (pin cce32b168)

- `src/script/interpreter.cpp:1991-1992` — budget =
  `GetSerializeSize(witness.stack) + VALIDATION_WEIGHT_OFFSET`.
- `src/script/script.h:60-65` — 50 WU per passing sigop; 50 WU offset.
- `src/serialize.h:291-297` — `GetSizeOfCompactSize` (1/3/5/9 bytes).
- `src/serialize.h:898-906,1156-1160` — vector serialization:
  CompactSize(count) then each item's CompactSize + bytes.
- `src/script/interpreter.cpp:360-377` — `success = !sig.empty()`, decrement
  by 50, `< 0` -> TAPSCRIPT_VALIDATION_WEIGHT.
- `src/script/interpreter.cpp:379-395` — empty pubkey, 32-byte key check,
  upgradable-key discouragement.
- `spec/core/Bitcoin/Interpreter/Defs.lean:757-788,1207-1229`;
  `spec/core/Bitcoin/Crypto/Taproot/Program.lean:595-642`;
  `spec/core/Bitcoin/Data/Basic.lean:73-77`.

## Model

- `cell_tapscript_budget`: bounded to 4 witness items, 32-bit lengths.
- `cell_tapscript_checksig`: the accounting and error precedence, with the
  Schnorr checker result as an explicit input. Checker rejection is encoded as
  `decision = 2` because its error ordinal is outside the cell (same-crypto
  seam). Observable packs decision, error, success and the signed post-weight.

## Symbolic claim

- Alive2: both functions equal for every input.
- SAW: four proofs (both legs x both functions) against `src/cell.cry`.

## Commands

```sh
bash spec/equiv/cells/limits/C-L-tapscript-weight/alive2/run.sh
bash spec/equiv/cells/limits/C-L-tapscript-weight/saw/run.sh
```

## Limits

- SCR-040 is **partial**: item count is bounded to 4; the 9-byte CompactSize
  branch is implemented but unreachable for a serialized witness item. Do not
  cite this cell as a full SCR-040 green.
- The Schnorr checker is abstracted; its ordinal is not modelled.
- No Core patch.
