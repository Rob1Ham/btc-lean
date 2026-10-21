# Wave 66 / 09 — SCR-040: loop-to-fold bridge at arbitrary item count

**Branch:** `wave66/09-scr-040`
**Base:** `8142cff0ed6ea6edd448b609817d2a706ab5e057`
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (Bitcoin Core v32.99)
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Row:** SCR-040 — *budget = serialized witness stack size (including the
CompactSize item count) + 50 WU* (interpreter.cpp:1991; script.h:62-65)
**Cell:** `spec/equiv/cells/limits/C-L-scr-040-loop-fold`
**Scope:** new cell and this finding only. No shared proof, pin, contract,
ledger, results, docs, twin or existing cell was edited. No Core patch.

---

## 1. Verdict

The wave65 cell proved the seed arithmetic for item counts 0..8 and an
arbitrary-list identity on the model side, but it left the step

```text
GetSerializeSize(witness.stack)  =  foldl step 0 (items)
```

as a **reviewed prose premise**.  That was the reason SCR-040 stayed partial.

This cell replaces the premise with a kernel-checked theorem over the pinned
source fragments, for an arbitrary item list:

```text
runLoop innerStep items acc = acc + items.foldl innerStep 0
```

where `runLoop` is an operational loop — explicit index, `i < items.length`
guard, one element per iteration, index increment, fuel `items.length + 1` —
not a fold in disguise, and `innerStep d = CompactSize(d.size) + d.size`.
It then proves the full seed expression of interpreter.cpp:1991 equals the
live btc-lean definition:

```text
seedValue items = csSize items.length + items.foldl innerStep 0 + 50
seedValue items = validationWeightInit items
```

with the 50 parsed from the pinned `VALIDATION_WEIGHT_OFFSET{50}` line and
the count prefix from the pinned `VectorFormatter::Ser` text.  Together with
the unchanged shared theorem `validationWeightInit_eq_encoder`, this reaches
`Int.ofNat (encStackL items).length + 50`, i.e. the actual encoder length the
live `executeWitnessScript` receives.

**Recommendation for SCR-040: full.**  The row flip itself is deliberately
not made in this branch: `spec/equiv/results/**`, the ledger and the coverage
matrix are outside the allowed edit set.  The integrator should cite
`lean/result.txt` (arbitrary count) plus `saw/result.txt` and
`alive2/result.txt` (bounded IR).

The residual is now a **source-level modelling premise**, not the program
claim `loop = foldl`: see §5.

---

## 2. What was wrong in the wave65 anchors

The wave65 cell cited the serializer loop loosely.  The fragments actually
embedded here are:

| Fragment | Pin location | Checked literal |
|---|---|---|
| `VectorFormatter::Ser` element loop | serialize.h:666-676 | 671-675 |
| BasicByte element serializer | serialize.h:900-902 | 901-902 |
| `SizeComputer::write` / `seek` | serialize.h:1121-1124, 1127-1130 | 1123, 1129 |
| `WriteCompactSize(SizeComputer&, n)` | serialize.h:1151-1154 | 1153 |
| `GetSerializeSize(t)` | serialize.h:1156-1160 | 1159 |
| `VALIDATION_WEIGHT_OFFSET{50}` | script.h:65 | 65 |
| tapscript seed assignment | interpreter.cpp:1991 | 1991 |

The per-item body is the BasicByte arm, **not** a generic `VectorFormatter`
recursion; the accumulator is a `SizeComputer`; the offset is 50.

---

## 3. Lean bridge (arbitrary count)

`spec/equiv/cells/limits/C-L-scr-040-loop-fold/src/lean/LoopToFold.lean`,
compiled against the zero-dependency `spec/core` package with Lean 4.35.0.

### 3.1 Pinned-text extraction is kernel-checked, not asserted

`src/extract_pinned.py` embeds eight exact excerpts from the pinned Core tree
as Lean string literals (generated region).  The Lean file then proves, by
`decide`:

- `sameCode exVectorFormatterSer (renderO vecSerProg) = true`
- `sameCode exBasicByteSerialize (renderI innerProg) = true`
- the same for the SizeComputer lines, `WriteCompactSize`,
  `GetSerializeSize`, the offset initializer and the seed assignment.

`sameCode` removes C++ whitespace and compares the remaining characters.
`renderO`/`renderI` are pretty-printers for the `OEff`/`IEff` ASTs that the
semantics functions `runO`/`runI` interpret.  Thus the kernel binds the
source text to the AST the proof reasons about.  `lean/run.sh` re-runs
`extract_pinned.py --check`, which verifies:

- `git rev-parse HEAD = cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`;
- sha256 of `src/serialize.h`, `src/script/script.h`,
  `src/script/interpreter.cpp`;
- every embedded literal against a fresh extraction.

### 3.2 The loop model and the bridge

```text
runLoopF f items n acc i =
  if n = 0 then acc
  else if i < items.length then
    runLoopF f items (n-1) (f acc items[i]) (i+1)
  else acc

runLoop f items acc = runLoopF f items (items.length+1) acc 0
```

`runLoopF_eq_fold` is proved by induction on the fuel for an arbitrary
`List ByteArray`, with the index and guard explicit.  `runLoop_eq_fold`
instantiates it at index 0 and fuel `|items|+1`; `foldl_add` distributes the
seed.  `runI_innerProg` proves the per-element effect is
`acc + (csSize d.size + d.size)`, discharging the `if (!v.empty())` guard
because an empty span has size 0.  `runO_vecSerProg` then gives
`csSize |items| + fold`, and `seed_eq_validationWeightInit` adds the parsed
offset and matches the live model definition.

Axiom audit (`lean/result.txt`):

```text
'runLoop_eq_fold' depends on axioms: [propext, Quot.sound]
'seed_eq_validationWeightInit' depends on axioms: [propext, Quot.sound]
'pinned_vector_ser' depends on axioms: [propext, Classical.choice, Quot.sound]
```

No `sorryAx`; no `native_decide`.  `Classical.choice` comes from the
decidable `String` equality used by `decide`, not from a trusted oracle.

---

## 4. Tool evidence

### 4.1 SAW 1.6 (symbolic count <= 8)

`saw/run.sh` compiles both legs, copies `cell.cry`/`cell.saw` into `build/`,
and runs `saw cell.saw` with Bitwuzla.

- **40** `llvm_verify` successes: `cell_compact_size_size` (2 legs) and
  `cell_basic_byte_ser` (2 legs); for each count 0..8, `cell_vector_ser` and
  `cell_seed` on each leg (36).
- **6** `prove_print` lemmas: 9-byte branch iff `n > 0xffffffff`; no 32-bit
  length takes it; item term <= 523 for len <= 520; 8-item seed <= 4237;
  empty seed = 51; `seed = vector_size + 50`.
- `saw/result.txt`: `STATUS=saw-green`,
  `CELL_limits_C_L_scr_040_loop_fold_SAW_GREEN`, no `Proof failed`.

The Cryptol spec `src/cell.cry` is an independent byte-count predicate
(`cs_size` + per-item `cs_size(len)+len`, threaded accumulator), not a copy
of the C code.

### 4.2 Alive2 v20 (per-count 0..8 + scalar step)

`alive2/run.sh` compares C and L IR after `src/normalize_alive2.py` removes
`nocapture`/`readonly`/`writeonly`/`memory(...)` ABI hints and clang's
inferred `nsw`/`nuw` flags from **both** legs (no instruction changed; see
`notes.md` for the soundness argument and the timeout that motivated it).

- `cell_compact_size_size`: C = L, full 64-bit.
- `cell_basic_byte_ser`: C = L, all 32-bit lengths, `0 <= acc <= 2^62`.
- `cell_vector_ser_k` and `cell_seed_k` for **every k = 0..8**, all item
  lengths symbolic: C = L (18 comparisons), plus the two scalar comparisons,
  for 20 green transformations total.
- `alive2/result.txt`: 20 × “Transformation seems to be correct”,
  `STATUS=alive2-green`, no incorrect/failed/error summary.

The symbolic-count `cell_vector_ser`/`cell_seed` are not compared by Alive2:
v20 times out on the 2^8 unrolled guard paths even after normalisation.  SAW
checks those with a symbolic count `<= 8`, and the Lean theorem covers any
count, so the per-count Alive2 set is supplementary, not the arbitrary-count
argument.

### 4.3 Lean

`lean/run.sh` runs `lake build Bitcoin`, `lake env lean LoopToFold.lean`, and
`extract_pinned.py --check`; `lean/result.txt` records
`STATUS=lean-green`, `PIN_CHECK=ok`, the three pinned file sha256s and eight
`OK ex...` lines.

---

## 5. Residual (and why this is not the old premise)

The Lean bridge is a **source-level refinement**.  Its remaining premise is:

1. the semantics of the modelled C++ fragment — range-for over
   `std::vector`, `size_t`/`int64` accumulation, `SizeComputer::seek/write`
   adding byte counts, and the BasicByte branch shape; and
2. the 1:1 transcription of the pinned text into the printed
   `OEff`/`IEff` ASTs (the transcription is kernel-checked character-by-
   character modulo whitespace, but the *semantics* of the AST is the
   hand-written `runO`/`runI`).

It is **not** the former prose premise `GetSerializeSize(loop) = foldl step`;
that equality is now `runLoop_eq_fold`, proved for an arbitrary list.

Out of cell:

- no whole-`VerifyWitnessProgram` proof; only the seed assignment and the
  serializer it calls are sliced; annex/chunk context above the seed is not
  modelled;
- item byte contents are abstracted to lengths, exactly as
  `GetSerializeSize` observes them;
- the 9-byte CompactSize branch is unreachable for a 32-bit item length, but
  it is implemented and proved over the full 64-bit domain;
- no Core patch is needed or proposed (no P-CORE).

---

## 6. Reproduce

```sh
bash spec/equiv/cells/limits/C-L-scr-040-loop-fold/saw/run.sh
bash spec/equiv/cells/limits/C-L-scr-040-loop-fold/alive2/run.sh
bash spec/equiv/cells/limits/C-L-scr-040-loop-fold/lean/run.sh
```

`src/extract_pinned.py` reads `CORE_SRC` (default
`/tmp/opencode/equiv-work/bitcoin`) and fails on a wrong pin, a changed file,
or a changed excerpt.  Each run writes `result.txt` and
`certificate.sha256` in the tool directory.

Result certificate hashes at this commit:

```text
8ed6dc847b9d8199732b61971c03ddf1d34bd1d5b1cca3e6a01d0474d7ed991a  saw/result.txt
c7b0c04768b2290cc3f9923998fb138e959c1ec142c0720a9486f5be67e48fac  alive2/result.txt
4e99d74715f7faac6b524044639a63afde8ded7087f36239a8db86c1bab0845f  lean/result.txt
b7ae5089d8779e02eb71427a516738a991c8b49bf8907bbb65607f92c6a99e28  {saw,alive2,lean}/certificate.sha256
```

Each certificate is a full `sha256sum` manifest of the cell (excluding
`build/`); `sha256sum -c` passes for all three.

---

## 7. Files

```text
spec/equiv/cells/limits/C-L-scr-040-loop-fold/
  spec.md, notes.md
  src/{c_leaf.cpp,l_leaf.cpp,cell.cry,cell.saw,gen_cell_saw.py,
       build.sh,build_cell.sh,extract_pinned.py,normalize_alive2.py,
       fns.txt,alive_fns.txt,cert-inputs.txt}
  src/lean/LoopToFold.lean
  saw/{run.sh,result.txt,certificate.sha256}
  alive2/{run.sh,result.txt,certificate.sha256}
  lean/{run.sh,result.txt,certificate.sha256}
```

`build/` is ignored by `spec/equiv/.gitignore`; it is reproducible from
`src/build*.sh` and its provenance is recorded in `build/build.txt`.
