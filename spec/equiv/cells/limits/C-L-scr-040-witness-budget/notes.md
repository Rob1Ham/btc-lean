# limits/C-L-scr-040-witness-budget

SCR-040 (**partial**): the BIP342 tapscript validation-weight seed,
`GetSerializeSize(witness.stack) + 50`, as the actual serialized byte count
(stack-count CompactSize + per-item CompactSize/length + payload) plus 50 WU.

This is a new cell, added because the prior evidence in
`limits/C-L-tapscript-weight` was bounded to four scalar length arguments and
did not verify the serializer loop or the 9-byte CompactSize branch.

## Source (pin cce32b168)

- `src/script/interpreter.cpp:1991-1992` — budget =
  `GetSerializeSize(witness.stack) + VALIDATION_WEIGHT_OFFSET`.
- `src/script/script.h:60-65` — 50 WU offset.
- `src/serialize.h:291-297` — `GetSizeOfCompactSize` (1/3/5/9 bytes).
- `src/serialize.h:120-140` — `SizeComputer::write(n)` adds n bytes.
- `src/serialize.h:898-906,1156-1160` — vector serialization: CompactSize
  count, then each item's CompactSize + bytes.
- `spec/core/Bitcoin/Crypto/Taproot/Program.lean:599-606,633-642` —
  `witnessPayloadSize`, `witnessSerSize`, `validationWeightInit`.
- `spec/core/Bitcoin/Interpreter/Defs.lean:92-93,1197,1229` — live alias.
- `spec/core/Bitcoin/Data/Basic.lean:73-77` — `compactSizeEnc`.

## Model

`cell_witness_serialized_size(n, lens)` is Core's `GetSerializeSize` as a
SizeComputer loop: write the count prefix, then for each `i < n` write
`CompactSize(len_i)` and `len_i` payload bytes.  `cell_witness_budget` adds
50.  The loop is unrolled to the declared cell bound `W_MAX_ITEMS = 8`.

The Cryptol spec (`src/cell.cry`) is an independent byte-count predicate:
`serialized_size n ls = cs_size n + sum [if i < n then cs_size(l_i)+l_i]`.

## Proofs actually run

| Function | Alive2 | SAW |
|---|---|---|
| `cell_compact_size_size` | C = L, full 64-bit | C,L = `cs_size` |
| `cell_witness_budget_count` | C = L | C,L = `CompactSize(n)+50`, all 32-bit n |
| `cell_witness_item_step` | C = L | C,L = `acc+CompactSize(len)+len`, all 32-bit len |
| `cell_witness_serialized_size` | C = L | C,L = `serialized_size` for counts 0..8 |
| `cell_witness_budget` | C = L | C,L = `budget` for counts 0..8 |

Alive2 is run with `--always-verify --smt-to=60000`; the cell-local
`src/normalize_alive2.py` only removes `nocapture`/`readonly`/`memory(...)`
caller-contract metadata that Alive2 v20 cannot parse (no instruction is
changed, and dropping a callee promise cannot hide a divergence).

SAW additionally proves:

- `cs_size n == 9` iff `n > 0xffffffff` (9-byte branch, both directions);
- no 32-bit length ever takes the 9-byte branch;
- the count prefix is <= 3 bytes for <= 1000 items, and a <= 520-byte item's
  term is <= 523 WU;
- an 8-item stack of <= 520-byte items has budget <= 4237 WU;
- `budget = serialized_size + 50`.

## Arbitrary item count — what is and is not machine-checked

`src/lean/BudgetComposition.lean` is a **cell-local** Lean file (not imported
by `spec/proofs/**`; no shared proof or ledger file edited).  It is compiled
with the built core model and proves, for an arbitrary
`List ByteArray` with **no arity hypothesis**:

```text
validationWeightInit items =
  Int.ofNat (compactSizeEnc items.length).size +
    items.foldl witnessItemStep 0 + 50
validationWeightInit items = Int.ofNat (encStackL items).length + 50
```

`encStackL` is the real BIP144 encoder, so the second theorem ties the
arithmetic to the emitted byte stream.  `#print axioms` shows only Lean's
kernel axioms; there is no `sorry`.

**But the arbitrary-count bridge from the compiled C++ loop to the Lean fold
is not machine-checked.**  The IR loop is verified for every count 0..8 (the
declared unrolling bound); the step to an unbounded count is the reviewed
transliteration premise `GetSerializeSize(loop) = foldl witnessItemStep`.
For that reason SCR-040 stays **partial** and is not promoted to green.

## Limits

- No whole-`VerifyWitnessProgram` proof; only the budget seed is sliced.
- Annex/witness-context handling above the seed is out of scope.
- Item bytes are abstracted to their lengths, exactly as `GetSerializeSize`
  observes them.
- The 9-byte CompactSize branch is unreachable for a 32-bit item length; it
  is nevertheless implemented and proved at the full 64-bit domain.

## Commands

```sh
bash spec/equiv/cells/limits/C-L-scr-040-witness-budget/alive2/run.sh
bash spec/equiv/cells/limits/C-L-scr-040-witness-budget/saw/run.sh
bash spec/equiv/cells/limits/C-L-scr-040-witness-budget/lean/run.sh
```

No Core patch is used.
