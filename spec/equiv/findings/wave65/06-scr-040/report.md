# Wave 65 · `06-scr-040` — SCR-040 budget composition, cell-level rebuild

**Branch:** `wave65/06-scr-040`
**Base:** `76dbfe5e42f8a337e41a7308158b0de078afafd9`
(`origin/equiv/llvm-three-leg`, PR #29)
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Scope:** `spec/equiv/cells/limits/C-L-scr-040-witness-budget/**` and this
finding directory only.

## Result

**SCR-040 remains `partial`.**  This branch adds a new cell and finding; it
does **not** edit `spec/proofs/**`, `PINS.lock`, `contract/**`, `spec/db/**`,
`results/**`, `docs/**`, the shared `limits/_shared` harness, or any existing
cell, and it does not promote SCR-040 in the ledger.

Proved at the cell level (Alive2 + SAW, real runs):

| Function | Statement checked |
|---|---|
| `cell_compact_size_size` | `GetSizeOfCompactSize(n)` for every 64-bit `n`, including the 9-byte branch; C = L |
| `cell_witness_budget_count` | `CompactSize(n_items) + 50` for every 32-bit count; C = L |
| `cell_witness_item_step` | `acc + CompactSize(len) + len` for every 32-bit `len`, `0 <= acc <= 2^62`; C = L |
| `cell_witness_serialized_size` | Core-shaped serializer loop (`CompactSize(count)` then per-item prefix + payload) equals the Cryptol byte-count for every count `0..8` (complete case split of the declared unrolling bound) with symbolic 32-bit lengths; C = L |
| `cell_witness_budget` | the same stream + 50 WU; C = L |

SAW also proves: the 9-byte branch holds exactly when `n > 0xffffffff`; no
32-bit item length takes it; the count prefix is at most 3 bytes for
`<= 1000` items; a `<= 520`-byte item contributes at most 523 WU; an 8-item
stack of `<= 520`-byte items has budget `<= 4237` WU; and
`budget = serialized_size + 50`.

A **cell-local** Lean file
(`cells/limits/C-L-scr-040-witness-budget/src/lean/BudgetComposition.lean`)
kernel-checks the arbitrary-count composition with **no arity hypothesis**:

```text
validationWeightInit items =
  Int.ofNat (compactSizeEnc items.length).size +
    items.foldl witnessItemStep 0 + 50
validationWeightInit items = Int.ofNat (encStackL items).length + 50
```

`#print axioms` reports only `propext` (and `Quot.sound` for the encoder
form): no `sorry`, no `Classical.choice`.  This file is not imported by
`spec/proofs/**` and changes no shared proof.

## Residual — why this is not full coverage

The unbounded C++ `GetSerializeSize` element loop is **not** machine-checked
against the Lean `foldl`.  The IR loop is verified for every count `0..8`
(the cell's declared unrolling bound); the transfer to an arbitrary count is
the **reviewed transliteration premise**

```text
GetSerializeSize(loop)  =  foldl witnessItemStep
```

Therefore:

- the count + fold + 50 composition over an arbitrary list is
  **machine-checked on the Lean model**;
- the bridge from the compiled C++ loop to that fold is a **reviewed
  premise**, not an IR refinement;
- SCR-040 is `partial` and must not be cited as a full green.

Also not claimed: a whole-`VerifyWitnessProgram` proof, annex/witness context
around the seed, or item byte values (only lengths, exactly as
`GetSerializeSize` observes them).  The 9-byte CompactSize branch is
unreachable for a 32-bit item length, but it is implemented and proved over
the full 64-bit domain rather than assumed dead.

## Relationship to wave64/07

The wave64/07 branch (`19e95cf`) added a theorem to the shared
`spec/proofs/BitcoinProofs/Theorems/WitnessSerialization.lean` and edited the
shared ledger.  That is not integrable under this workstream's constraints.
This branch rebuilds the evidence independently:

- a new cell with its own C/L leaves, Cryptol spec, SAW script and runners;
- a cell-local Lean file that is not part of the shared proof closure;
- no ledger, `results/`, `docs/`, or `PINS.lock` edits;
- the same honest residual: bounded IR loop plus arbitrary-count model
  theorem, with the loop-to-fold bridge left as a reviewed premise.

## Exact commands and raw logs

All commands are run from the worktree root
`/tmp/opencode/wave65/06-scr-040`.

```sh
# Alive2: build, cell-local IR normalization, --always-verify, 60 s SMT budget
bash spec/equiv/cells/limits/C-L-scr-040-witness-budget/alive2/run.sh
# raw:  spec/equiv/cells/limits/C-L-scr-040-witness-budget/alive2/result.txt

# SAW 1.6: 42 llvm_verify proofs + 6 prove_print lemmas (bitwuzla)
bash spec/equiv/cells/limits/C-L-scr-040-witness-budget/saw/run.sh
# raw:  spec/equiv/cells/limits/C-L-scr-040-witness-budget/saw/result.txt

# Cell-local Lean kernel check (core package; not spec/proofs)
bash spec/equiv/cells/limits/C-L-scr-040-witness-budget/lean/run.sh
# raw:  spec/equiv/cells/limits/C-L-scr-040-witness-budget/lean/result.txt

# Certificate replay over all cells (includes this cell's three certs)
cd spec/equiv && python3 tools/gate_ir_pin.py
```

Copies of the raw transcripts are kept at
`spec/equiv/findings/wave65/06-scr-040/logs/`.

## Certificates and hashes

Each leg writes `certificate.sha256` over its tracked inputs, the raw
`result.txt`, the four cited core model files, and the cell's spec/notes/src
files.  The three certificates normalize to the same tracked-input digest set
and replay cleanly.

```text
8d8231d49ebac667d53c02375c61daee35ee8d70fb9e2fbdfe326801a628c69a  alive2/result.txt
2d09854f6cfe958153aab9dfeed78ff9aa9f182131c6160483f78e602e04efc7  saw/result.txt
16c82aea28d8d35ec52befc3fe01b5978705525949a6b18e3126b2a835b8cd4e  lean/result.txt
52ea565faa1c4a35ca9399acc3b5a656544308b51ffea01ba5a80fa451228310  alive2|certificate.sha256 (all three legs normalize identically)
e44c5915616c929a9186ec21d98fbbc7f993a54c7f10200a63220eba81c4d7d6  src/c_leaf.cpp
a634246a53ecf6c2c5b8eb3e23c33e25db2dc2cc65c34f9e9ef03e9bb510ef30  src/l_leaf.cpp
8daa61e2ec6c8c3fb34e115612d69a1232d49de35e9ba6368e3d18713695c38d  src/cell.cry
a411965697236c9b51027fcb9e1a8d7d21cf6272b737cd590ea415190aebcac4  src/cell.saw
832fcb48e4efcb2c21e001a805489f30b6e9a2bcad9a45c0a568b07ed7b680cf  src/lean/BudgetComposition.lean
```

The full list, tool versions and timestamp are in
`logs/sha256sums.txt`.

**Verification gates at this commit:**

```text
python3 tools/gate_ir_pin.py                  -> PASS (347 certificates, 0 failures, 0 warnings)
python3 results/scripts/coverage_report.py --strict
                                             -> PASS (183/183 rows adjudicated; SCR-040 stays gap)
```

`gate-ir-pin` counts 347 rather than the base's 344 because this cell adds
three fully replayable certificates.

**Toolchain note.**  The cell-local Lean check uses `spec/core`'s
`lean-toolchain` (Lean 4.35.0), not the separate `spec/proofs` mathlib
workspace; it is supplementary model-side evidence.  Alive2 and SAW are the
pinned tools (`alive-tv` LLVM 20.1.2, SAW 1.6 `68eed5f`).

## Files added

```text
spec/equiv/cells/limits/C-L-scr-040-witness-budget/
  spec.md, notes.md
  src/{c_leaf.cpp,l_leaf.cpp,cell.cry,cell.saw,build.sh,fns.txt,cert-inputs.txt}
  src/normalize_alive2.py, src/gen_cell_saw.py
  src/lean/BudgetComposition.lean
  alive2/{run.sh,result.txt,certificate.sha256}
  saw/{run.sh,result.txt,certificate.sha256}
  lean/{run.sh,result.txt,certificate.sha256}
spec/equiv/findings/wave65/06-scr-040/{report.md,logs/}
```
