---
# Cell limits/C-L-scr-040-witness-budget
cell: C-L-scr-040-witness-budget
family: limits
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 76dbfe5e42f8a337e41a7308158b0de078afafd9
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (Alive2+SAW); supplementary cell-local Lean model check green
precondition: |
  - C leg (line-cited source excerpt, pin cce32b168).
      * `GetSizeOfCompactSize(n)` per serialize.h:291-297 for the full
        64-bit domain: 1 byte for n < 253, 3 for n <= 0xffff, 5 for
        n <= 0xffffffff, 9 otherwise.
      * `GetSerializeSize(witness.stack)` per serialize.h:898-906 and
        1156-1160, modelled as Core implements it: a SizeComputer whose
        `write(n)` adds exactly the n bytes the serializer emits
        (serialize.h:120-140).  The serialized stream is
        `CompactSize(count) || (CompactSize(len_i) || item_i)...`; item byte
        contents never enter a size, only their lengths.
      * The vector-serializer element loop is unrolled to the declared cell
        bound `W_MAX_ITEMS = 8`.  The SAW preconditions are
        `n_items <= 8` (a complete 9-way case split is verified, see below)
        and 32-bit item lengths.
      * The budget is the serialized size plus
        `VALIDATION_WEIGHT_OFFSET = 50` (interpreter.cpp:1991-1992;
        script.h:62-65).
  - L leg (reviewed transliteration, same pin/model).
      * `spec/core/Bitcoin/Crypto/Taproot/Program.lean:599-606,633-642`
        (`witnessPayloadSize`, `witnessSerSize`, `VALIDATION_WEIGHT_OFFSET`,
        `validationWeightInit`), `Bitcoin/Interpreter/Defs.lean:92-93,1197,
        1229` (live alias and `validationWeightLeft := vwSer + offset`), and
        `Bitcoin/Data/Basic.lean:73-77` (`compactSizeEnc` thresholds).
      * The L loop is the same Core-shaped unrolled loop, truncated to the
        same declared bound 8.
  - Item lengths are `uint32_t`; the 9-byte CompactSize branch (n >
    0xffffffff) is unreachable for a serialized witness item, but it is still
    implemented and separately proved at the full 64-bit domain.
postcondition: |
  - `cell_compact_size_size(n)`: C and L equal `cs_size n` for every 64-bit
    n, including the 9-byte branch; SAW also proves
    `cs_size n == 9 <-> n > 0xffffffff` and that no 32-bit n takes it.
  - `cell_witness_budget_count(n)`: C and L equal `CompactSize(n) + 50` for
    every 32-bit n (CompactSize 1/3/5-byte branches).
  - `cell_witness_item_step(len, acc)`: C and L equal
    `acc + CompactSize(len) + len` for every 32-bit len and every
    `0 <= acc <= 2^62`.
  - `cell_witness_serialized_size(n, lens)`: for every `n` in `0..8`
    (complete case split of the declared bound) and every symbolic 32-bit
    `len_0..len_7`, C and L equal the Cryptol byte-count
    `CompactSize(n) + sum_{i<n} (CompactSize(len_i) + len_i)`.
  - `cell_witness_budget(n, lens)`: same as the previous item plus 50.
  - SAW lemmas: the executed-domain item term is <= 523 WU, the count prefix
    is <= 3 bytes for <= 1000 items, and an 8-item stack of <= 520-byte items
    has budget <= 4237 WU (no int64 overflow).
  - Cell-local Lean (`src/lean/BudgetComposition.lean`, compiled, axiom
    audited): for an arbitrary `List ByteArray` with no arity hypothesis,
      `validationWeightInit items
         = CompactSize(items.length)
         + foldl (fun acc d => acc + CompactSize(d.size) + d.size) 0 items
         + 50`
    and the same value equals `Int.ofNat (encStackL items).length + 50`,
    where `encStackL` is the actual BIP144 stack encoder.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-040
scr_row_coverage: |
  partial. Proved: (a) the CompactSize size function over the full 64-bit
    domain including the 9-byte branch; (b) the stack-count term
    `CompactSize(n_items) + 50` for every 32-bit count; (c) the per-item term
    `acc + CompactSize(len) + len` for every 32-bit length; (d) the
    Core-shaped serializer loop for every count 0..8 (the declared unrolling
    bound) with symbolic 32-bit lengths, in both C and L, against an
    independent Cryptol byte-count spec; (e) budget = serialized size + 50;
    (f) a cell-local Lean kernel proof of the count + fold + 50 composition
    for an arbitrary list / arbitrary item count, and of equality with the
    BIP144 encoding length. NOT proved: the unbounded C++ element loop itself
    is not lifted to the Lean fold by a machine-checked refinement. The IR
    loop is verified only up to the declared bound 8, and the arbitrary-count
    transfer is the reviewed transliteration premise
    `GetSerializeSize(loop) = foldl step`; therefore this cell does not
    claim full SCR-040 coverage and the row stays gap. Also not claimed: a
    whole-VerifyWitnessProgram proof, or the surrounding witness/annex
    budget context.
patches: none
source_citations:
  - interpreter.cpp:1991-1992 (validation_weight_left = GetSerializeSize(witness.stack) + VALIDATION_WEIGHT_OFFSET)
  - script.h:60-65 (VALIDATION_WEIGHT_PER_SIGOP_PASSED = 50; VALIDATION_WEIGHT_OFFSET = 50)
  - serialize.h:291-297 (GetSizeOfCompactSize)
  - serialize.h:120-140 (SizeComputer::write advances the byte count)
  - serialize.h:898-906,1156-1160 (vector serialization and GetSerializeSize)
  - spec/core/Bitcoin/Crypto/Taproot/Program.lean:599-606,633-642 (witnessSerSize, VALIDATION_WEIGHT_OFFSET, validationWeightInit)
  - spec/core/Bitcoin/Interpreter/Defs.lean:92-93,1197,1229 (live alias, budget init)
  - spec/core/Bitcoin/Data/Basic.lean:73-77 (compactSizeEnc)
  - spec/core/Bitcoin/Serialization/Interface.lean:493-506,866-867 (encCSL, bL_compactSizeEnc, encStackL)
trust_note: >
  C is a line-cited source-excerpt slice of interpreter.cpp, script.h and
  serialize.h at the pin; it models GetSerializeSize through Core's own
  SizeComputer semantics (a write of n bytes adds n).  L is a reviewed
  transliteration of the Lean witnessSerSize / validationWeightInit
  definitions.  Alive2 compares C and L IR (with only caller-contract
  attributes dropped, cell-locally, before Alive2) and SAW verifies both
  against the independent Cryptol byte-count predicate.  The cell-local Lean
  file is a supplementary kernel check of the arbitrary-list identity; it is
  not imported by spec/proofs and does not modify any shared proof.  No
  hash, signature, script execution or whole-Program claim is made.  No Core
  patch is used.
---

# limits/C-L-scr-040-witness-budget

SCR-040 partial: the BIP342 tapscript validation-weight seed,
`GetSerializeSize(witness.stack) + 50`, composed as the stack-count
CompactSize + the per-item CompactSize/length fold + 50.

## What is machine-checked

| Slice | Alive2 | SAW | Scope |
|---|---|---|---|
| `cell_compact_size_size` | C = L | C,L = `cs_size` | full 64-bit domain; 9-byte branch |
| `cell_witness_budget_count` | C = L | C,L = `CompactSize(n)+50` | all 32-bit counts |
| `cell_witness_item_step` | C = L | C,L = `acc+CompactSize(len)+len` | all 32-bit lengths; `0<=acc<=2^62` |
| `cell_witness_serialized_size` | C = L | C,L = `serialized_size` | counts 0..8 (complete case split), symbolic lengths |
| `cell_witness_budget` | C = L | C,L = `budget` | same, plus 50 |
| Lean `BudgetComposition.lean` | — | — | arbitrary `List ByteArray`, kernel-checked |

The Lean theorems are:

```text
validationWeightInit_eq_count_add_fold :
  validationWeightInit items =
    Int.ofNat (compactSizeEnc items.length).size +
      items.foldl witnessItemStep 0 + 50
validationWeightInit_eq_encoder_add_offset :
  validationWeightInit items = Int.ofNat (encStackL items).length + 50
```

Both quantify over an arbitrary list; there is no arity bound.  `#print
axioms` reports only Lean's kernel axioms (see `lean/result.txt`).

## What is not machine-checked (residual)

- The unbounded C++ `GetSerializeSize` element loop is not refined against
  the Lean `foldl` by a machine-checked proof.  The IR loop is checked for
  every count in the declared bound 0..8; the step from that finite check to
  an arbitrary count is the reviewed premise
  `GetSerializeSize(loop) = foldl witnessItemStep`.  This is why SCR-040
  remains **partial**, not green.
- No whole-`VerifyWitnessProgram` proof; only the two cited lines are
  sliced.  Annex and witness-context handling above the seed is out of cell.
- Item byte contents are abstracted to their lengths, exactly as
  `GetSerializeSize` observes them.

## Reproduce

```sh
bash spec/equiv/cells/limits/C-L-scr-040-witness-budget/alive2/run.sh
bash spec/equiv/cells/limits/C-L-scr-040-witness-budget/saw/run.sh
bash spec/equiv/cells/limits/C-L-scr-040-witness-budget/lean/run.sh
```
