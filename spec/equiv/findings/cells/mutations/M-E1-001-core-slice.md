# M-E1-001 core-slice mutant check

- cell: `cells/e1-stack/swap-order` (`cell_swap_order`)
- mutation: OP_SWAP becomes a no-op at the C source-slice site
- target: `spec/equiv/cells/_tools/gate/c_leaf.cpp` (disposable copy)
- sha256 before: `d828dd3a3f624739f73a0f7fab622dae40c4403ded2c13e1085679b9f7093844`
- sha256 mutant: `54906c53303c2a3ce900b26e1a7ac57baab7917fcce37d783717dcf88f51c650`
- sha256 after revert: `d828dd3a3f624739f73a0f7fab622dae40c4403ded2c13e1085679b9f7093844`
- original repo target untouched: `d828dd3a3f624739f73a0f7fab622dae40c4403ded2c13e1085679b9f7093844`

## Mutant result

- Alive2: `STATUS=alive2-not-green` (runner rc 1)
- SAW: `STATUS=saw-not-green` (runner rc 1)
- killed: `M-E1-001` core-slice

### Alive2 excerpt

```text
Transformation doesn't verify!
ERROR: Value mismatch
Summary:
  1 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-not-green
```

### SAW excerpt

```text
Subgoal failed: cell_swap_order cell.saw:8:1: error: in _SAW_LLVM_withMethodSpec
<<All settings of the symbolic variables constitute a counterexample>>
Proof failed.
STATUS=saw-not-green
```

Full mutant outputs: `findings/cells/mutations/raw/M-E1-001-core-slice-alive2.txt`
and `...-saw.txt`.

## Revert / baseline

- Alive2: `STATUS=alive2-green` (rc 0)
- SAW: `STATUS=saw-green` (rc 0)
