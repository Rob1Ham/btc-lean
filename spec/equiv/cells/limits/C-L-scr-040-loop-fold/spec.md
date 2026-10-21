---
# Cell limits/C-L-scr-040-loop-fold
cell: C-L-scr-040-loop-fold
family: limits
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 8142cff0ed6ea6edd448b609817d2a706ab5e057
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: SAW green (40 llvm_verify + 6 lemmas); Alive2 green (scalar step + per-count 0..8); cell-local Lean kernel proof green at arbitrary count
precondition: |
  - C leg (line-cited source slice at pin cce32b168).
      * `GetSerializeSize(witness.stack)` at interpreter.cpp:1991, with
        `VALIDATION_WEIGHT_OFFSET = 50` at script.h:65.
      * `VectorFormatter::Ser` (serialize.h:666-676) writes
        `CompactSize(v.size())` and then calls the element serializer for
        every element of `v`, in order, into the same `SizeComputer`.
      * The element serializer for `vector<unsigned char>` is the BasicByte
        arm (serialize.h:900-902): `CompactSize(len)` and then, when the
        vector is non-empty, `os.write(MakeByteSpan(v))`.
      * `WriteCompactSize(SizeComputer&, n)` is `s.seek(cs(n))`
        (serialize.h:1151-1154); `SizeComputer::seek`/`write` add the byte
        count (serialize.h:1127-1130, 1121-1124); `GetSizeOfCompactSize`
        is 1/3/5/9 bytes (serialize.h:291-297).
      * IR legs: item count is `uint32_t`; the symbolic-count SAW checks
        restrict it to `n_items <= 8` (the declared unrolling bound) and item
        lengths are symbolic 32-bit values.  Alive2 additionally compares the
        per-count instantiations `k = 0..8` (all item lengths symbolic).
        The scalar step precondition is `0 <= acc <= 2^62`.
  - L leg (the live btc-lean model, same pin).
      * `spec/core/Bitcoin/Crypto/Taproot/Program.lean:599-606,633-642`
        (`witnessPayloadSize`, `witnessSerSize`,
        `VALIDATION_WEIGHT_OFFSET`, `validationWeightInit`) and
        `Bitcoin/Data/Basic.lean:73-77` (`compactSizeEnc`).
      * The L IR is the model's fold shape: count prefix + left fold of
        `CompactSize(len_i) + len_i`, then + 50.
  - Lean bridge (cell-local, no shared file edited).
      * The pinned source fragments are embedded as string literals by
        `src/extract_pinned.py`; `sameCode` deletes C++ whitespace and the
        kernel proves (by `decide`) that each literal is the pinned text and
        that `renderO vecSerProg` / `renderI innerProg` reproduce the cited
        statements.
      * `runLoopF` is an operational loop with an explicit index, the
        `i < items.length` guard and an index increment; it is not a fold in
        disguise.  Its fuel is `items.length + 1`.
      * The residual modelling premise is only the semantics of the C++
        fragment (range-for over a vector, `size_t` accumulation,
        SizeComputer seek/write) and the 1:1 transcription of the pinned text
        into the `IEff`/`OEff` ASTs.  The former wave65 premise
        `loop = foldl` is not assumed; it is `runLoop_eq_fold`.
postcondition: |
  - Alive2 (per-count 0..8): C = L for `cell_vector_ser_k` and
    `cell_seed_k`, with every item length symbolic; C = L for
    `cell_compact_size_size` (full 64-bit domain) and
    `cell_basic_byte_ser` (all 32-bit lengths, accumulator 0..2^62).
  - SAW (symbolic count <= 8): for both legs,
    `cell_vector_ser(n, lens) = vector_size n lens` and
    `cell_seed(n, lens) = vector_size n lens + 50`, where
    `vector_size n lens = CompactSize(n) +
       sum_{i<n} (CompactSize(lens_i) + lens_i)`;
    `cell_basic_byte_ser(acc, len) = acc + CompactSize(len) + len`;
    `cell_compact_size_size(n) = cs_size n` over the full 64-bit domain.
  - SAW side lemmas: `cs_size n = 9` iff `n > 0xffffffff`; no 32-bit length
    takes the 9-byte branch; an item term is <= 523 for `len <= 520`; an
    8-item stack of <= 520-byte items has seed <= 4237; `seed 0 [] = 51`;
    `seed = vector_size + 50`.
  - Lean, arbitrary `List ByteArray` (no arity bound):
      `runLoop innerStep items acc = acc + items.foldl innerStep 0`
    (the loop from index 0 is the left fold);
      `seedValue items =
         csSize items.length + items.foldl innerStep 0 + parsedOffset`
    with `parsedOffset = 50` parsed from the pinned script.h:65 line; and
      `seedValue items = validationWeightInit items`,
    hence, by the existing shared theorem `validationWeightInit_eq_encoder`,
    the seed is `Int.ofNat (encStackL items).length + 50`.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-040
scr_row_coverage: |
  full for the loop-to-fold bridge at arbitrary witness-stack item count.
    The wave65 cell proved the arithmetic for 0..8 items and left
    `GetSerializeSize(loop) = foldl step` as a reviewed prose premise; this
    cell replaces that premise with a kernel-checked theorem over the pinned
    source fragments (`runLoop_eq_fold`, arbitrary `List ByteArray`), proves
    the per-element effect (`runI_innerProg`), and proves the full seed
    expression equals the live model's `validationWeightInit`
    (`seed_eq_validationWeightInit`), including the offset parsed from the
    pinned initializer.  Combined with the unchanged shared theorem
    `BitcoinProofs.Theorems.WitnessSerialization.validationWeightInit_eq_encoder`,
    this covers the actual `VerifyWitnessProgram` budget seed, not a
    separately invented predicate.  The 9-byte CompactSize branch is proved
    over the full 64-bit domain.  Row flip is deliberately not made here:
    the matrix/ledger/results are not edited by this cell; the integrator
    should cite this cell's `lean/result.txt` and the two tool result files.
  residual: the Lean bridge is a source-level refinement over a formalised
    fragment, so the remaining premise is the fragment's semantics and the
    pin-text-to-AST transcription, not `loop = foldl`.  No whole-
    `VerifyWitnessProgram` proof, no annex/chunk context above the seed, and
    no statement about item byte contents beyond their lengths.
patches: none
source_citations:
  - interpreter.cpp:1991 (tapscript seed = GetSerializeSize(witness.stack) + VALIDATION_WEIGHT_OFFSET)
  - script.h:65 (VALIDATION_WEIGHT_OFFSET{50}; comment at 62-64)
  - serialize.h:666-676 (VectorFormatter::Ser element loop; body 671-675)
  - serialize.h:900-902 (BasicByte arm: CompactSize + guarded write)
  - serialize.h:291-297 (GetSizeOfCompactSize 1/3/5/9)
  - serialize.h:1121-1124,1127-1130 (SizeComputer write/seek)
  - serialize.h:1151-1154,1156-1160 (WriteCompactSize, GetSerializeSize)
  - spec/core/Bitcoin/Crypto/Taproot/Program.lean:599-606,633-642 (witnessSerSize, validationWeightInit)
  - spec/core/Bitcoin/Data/Basic.lean:73-77 (compactSizeEnc thresholds)
  - spec/proofs/BitcoinProofs/Theorems/WitnessSerialization.lean:59-104 (shared seed/encoder composition, unchanged)
trust_note: >
  C is a line-cited slice of the pinned Core serializer; item bytes are
  abstracted to their lengths, exactly as GetSerializeSize observes them.  L
  is the live btc-lean fold.  Alive2 compares the two IR legs after a
  cell-local preparation that removes caller-contract pointer attributes and
  clang-inferred nsw/nuw overflow flags from both legs (no instruction is
  changed); the flags are codegen facts true on the stated domain, and SAW
  checks the same arithmetic as total 64-bit bitvectors.  The symbolic-count
  IR loop is SAW-only because Alive2 v20 times out on its 2^8 guard paths;
  Alive2 covers all counts 0..8 by instantiation instead.  The Lean file is
  cell-local: it is not imported by spec/proofs, edits no shared proof, pin,
  contract or ledger file, and its axiom audit shows no sorryAx.  No Core
  patch is used.
---

# limits/C-L-scr-040-loop-fold

SCR-040 closure attempt for the BIP342 tapscript validation-weight seed,
`GetSerializeSize(witness.stack) + 50`, with the loop-to-fold bridge checked
at arbitrary item count instead of assumed.

## The gap this cell closes

The wave65 cell (`limits/C-L-scr-040-witness-budget`) proved the seed
arithmetic for item counts 0..8 and an arbitrary-list identity on the model
side, but the step from the compiled C++ element loop to the Lean fold was a
reviewed prose premise.  This cell makes that step a theorem:

| Claim | Evidence |
|---|---|
| scalar CompactSize size function, full 64-bit domain | Alive2 + SAW |
| per-element serializer effect `CompactSize(len) + len` | Alive2 + SAW |
| vector serializer equals count prefix + fold, counts 0..8 | Alive2 per-count + SAW symbolic |
| the actual C++ loop (index + guard + increment) equals the left fold, **any count** | Lean `runLoop_eq_fold` |
| the seed expression equals the live model `validationWeightInit`, **any count** | Lean `seed_eq_validationWeightInit` |
| pinned source text is what the Lean ASTs claim | kernel `decide` via `sameCode` |

## Machine-checked statement (Lean)

For an arbitrary `items : List ByteArray` and any accumulator:

```text
runLoop innerStep items acc = acc + items.foldl innerStep 0
```

`runLoop` executes the modelled `for (elem : v)` control flow — explicit
index, `i < items.length` guard, one element per iteration, increment — with
fuel `items.length + 1`.  The per-element body is the pinned BasicByte arm:

```text
runI innerProg d acc = acc + (csSize d.size + d.size)
```

The outer `VectorFormatter::Ser` is the count prefix followed by that loop,
and the seed adds the 50 parsed from the pinned
`VALIDATION_WEIGHT_OFFSET{50}` line:

```text
seedValue items = csSize items.length + items.foldl innerStep 0 + 50
seedValue items = validationWeightInit items
```

`#print axioms` reports `[propext, Quot.sound]` for the two main theorems and
no `sorryAx` (see `lean/result.txt`).

## What is not machine-checked (residual)

- The Lean bridge is a **source-level** refinement.  Its remaining premise is
  the semantics of the C++ fragment (range-for over a vector, `size_t`
  accumulation, `SizeComputer` seek/write) and the 1:1 transcription of the
  pinned text into the printed ASTs.  The former premise
  `GetSerializeSize(loop) = foldl step` is **not** assumed any more; the loop
  itself is modelled and the equality is proved.
- Alive2 v20 cannot discharge the symbolic-count 8-way unrolled loop in the
  cell's time budget; it is checked per count 0..8 instead.  SAW checks the
  same loop with a symbolic count `<= 8`.
- No whole-`VerifyWitnessProgram` proof and no annex/chunk context above the
  seed; only the cited seed slice is in scope.  Item byte contents are
  abstracted to lengths, exactly as `GetSerializeSize` observes them.
- No Core patch is used or proposed; the cell stays at pin `cce32b168`.

## Reproduce

```sh
bash spec/equiv/cells/limits/C-L-scr-040-loop-fold/alive2/run.sh
bash spec/equiv/cells/limits/C-L-scr-040-loop-fold/saw/run.sh
bash spec/equiv/cells/limits/C-L-scr-040-loop-fold/lean/run.sh
```
