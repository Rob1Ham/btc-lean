# tapscript/C-L-taproot-annex — notes

## Source excerpts (pin `cce32b168`)

`src/script/interpreter.cpp:1961-1969`:

```cpp
        if (stack.size() >= 2 && !stack.back().empty() && stack.back()[0] == ANNEX_TAG) {
            // Drop annex (this is non-standard; see IsWitnessStandard)
            const valtype& annex = SpanPopBack(stack);
            execdata.m_annex_hash = (HashWriter{} << annex).GetSHA256();
            execdata.m_annex_present = true;
        } else {
            execdata.m_annex_present = false;
        }
        execdata.m_annex_init = true;
```

`src/script/script.h:59`:

```cpp
inline constexpr unsigned int ANNEX_TAG = 0x50;
```

Lean (`spec/core/Bitcoin/Interpreter/Defs.lean:1287-1289`):

```lean
        let annex := 2 ≤ witness.length ∧ (witness.getLast!).size ≠ 0 ∧
          (byteOr (witness.getLast!) 0).toNat = ANNEX_TAG
        let stack := if annex then witness.dropLast else witness
```

## Design

Core reads exactly three facts at :1961: item count, last item size, last
item first byte. The cell takes those three as symbolic inputs instead of a
byte array, so the predicate is total without a memory model. `last_first` is
masked with `0xff` because Core indexes an `unsigned char`.

`cell_annex_remaining` models `SpanPopBack` / `dropLast`: exactly one item is
removed. The annex hash is deliberately not modelled; it is a sighash input
and belongs to a different row.

## Commands and versions

- clang: Ubuntu clang 20.1.2 (0ubuntu1~24.04.3)
- Alive2: Ubuntu LLVM version 20.1.2 (`/usr/local/bin/alive-tv`, v20.0)
- SAW: 1.6 (68eed5f release-1.6), solver `abc`
- IR: `clang++-20 -O1 -S -emit-llvm`; `llvm-extract --recursive`.

```sh
bash spec/equiv/cells/tapscript/C-L-taproot-annex/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-taproot-annex/saw/run.sh
```

## Raw result tails

Alive2 (`alive2/result.txt`):

```
Transformation seems to be correct!
These functions seem to be equivalent!
Summary:
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

SAW (`saw/result.txt`):

```
Proof succeeded! cell_annex_detected
Proof succeeded! cell_annex_detected
Proof succeeded! cell_annex_remaining
Proof succeeded! cell_annex_remaining
CELL_tapscript_annex_SAW_GREEN
STATUS=saw-green (4/4 proofs)
```

## Honesty notes

- Alive2 reports `syntactically equal` for both functions: clang emitted the
  same IR for the two total boolean forms. That is still a valid C=L check,
  but the semantic content is carried by the shared Cryptol statement and the
  source review, not by IR syntax.
- The cell is full for SCR-143 because the row is the detection predicate.
  It does not claim the annex hash or any sighash behavior.
- No mutation was executed; the proposed mutant is recorded in `spec.md`.
