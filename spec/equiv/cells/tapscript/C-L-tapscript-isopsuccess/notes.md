# tapscript/C-L-tapscript-isopsuccess — notes

## Source excerpts (pin `cce32b168`)

`src/script/script.cpp:365-371`:

```cpp
bool IsOpSuccess(const opcodetype& opcode)
{
    return opcode == 80 || opcode == 98 || (opcode >= 126 && opcode <= 129) ||
           (opcode >= 131 && opcode <= 134) || (opcode >= 137 && opcode <= 138) ||
           (opcode >= 141 && opcode <= 142) || (opcode >= 149 && opcode <= 153) ||
           (opcode >= 187 && opcode <= 254);
}
```

Lean (`spec/core/Bitcoin/Interpreter/Defs.lean:463-466`):

```lean
def isOpSuccessWire (w : Nat) : Bool :=
  w = 80 ∨ w = 98 ∨ (126 ≤ w ∧ w ≤ 129) ∨ (131 ≤ w ∧ w ≤ 134) ∨
  (137 ≤ w ∧ w ≤ 138) ∨ (141 ≤ w ∧ w ≤ 142) ∨ (149 ≤ w ∧ w ≤ 153) ∨
  (187 ≤ w ∧ w ≤ 254)
```

## Design

The whole cell is the predicate. The C leg is the literal expression; the L
leg is the literal Lean expression. The harness takes a 64-bit input because
both engines accept `Nat`/`opcodetype` values outside 0..255 and both return
false for them.

## Commands and versions

- clang: Ubuntu clang 20.1.2 (0ubuntu1~24.04.3)
- Alive2: Ubuntu LLVM version 20.1.2 (`/usr/local/bin/alive-tv`, v20.0)
- SAW: 1.6 (68eed5f release-1.6), solver `abc`
- IR: `clang++-20 -O1 -S -emit-llvm`; `llvm-extract --recursive`.

```sh
bash spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/alive2/run.sh
bash spec/equiv/cells/tapscript/C-L-tapscript-isopsuccess/saw/run.sh
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
Proof succeeded! cell_is_op_success
Proof succeeded! cell_is_op_success
CELL_tapscript_isopsuccess_SAW_GREEN
STATUS=saw-green (2/2 proofs)
```

## Honesty notes

- The row is fully covered *as a predicate*. Its execution consequence is
  SCR-153/154 and is deliberately outside this cell.
- The SAW statement is independent of both C++ legs: it is written from the
  documented BIP342 byte set.
- No mutation was executed; the proposed mutant is recorded in `spec.md`.
