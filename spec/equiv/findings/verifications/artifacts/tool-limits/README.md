# Tool-limit experiments: exceptions, indirect calls, ptrtoint

Purpose: replace documentation folklore with observed behavior on the exact
LLVM features that block Core's interpreter. Clang 20.1.2, Alive2 v20.0,
SAW 1.6, `-O0`.

`features.cpp` has three functions:

| function | feature | IR counts |
|---|---|---|
| `ex_edges` | C++ try/catch/throw | 2 `invoke`, 2 `landingpad` |
| `indirect` | call through a function pointer | 1 indirect `call` |
| `ptr_roundtrip` | `ptrtoint` + `inttoptr` | 2 `ptrtoint`, 1 `inttoptr` |

## Alive2 v20.0

| input | result |
|---|---|
| whole module | 2 correct, **1 Alive2 error** |
| `ex_edges` alone | **ERROR: Could not translate 'ex_edges' to Alive IR** |
| `indirect` alone, `--always-verify` | 1 correct, 0 errors |
| `ptr_roundtrip` alone, `--always-verify` | 1 correct, 0 errors |

So the blanket "Alive2 has no ptrtoint / no function pointers" is too strong
for v20 on these self-refinement shapes. The **hard** limit observed here is
exceptions: Alive2 refuses to translate any function with `invoke`/
`landingpad`. Treat ptrtoint/indirect support as shape-dependent and re-test
per cell; never assume it.

## SAW 1.6

`ex_edges` **loads and proves** under a domain precondition:

```saw
x <- llvm_fresh_var "x" (llvm_int 32);
// [32] comparisons are unsigned: this excludes negative i32 values
// (the throw path) and INT_MAX (the nsw overflow in x + 1).
llvm_precond {{ x < 0x7fffffff }};
llvm_execute_func [llvm_term x];
llvm_return (llvm_term {{ x + 1 : [32] }});
```

Result: `Proof succeeded! ex_edges`.

Two instructive failures before the preconditions were right:

1. Without the signed-nonnegative condition, SAW produced counterexample
   `x = 4294967295` — the throw path returns `-1`. That is correct behavior
   for the spec's missing precondition, not a tool limit.
2. With `x >= 0` but allowing `INT_MAX`, SAW rejected the C++ `x + 1` because
   `nsw` was set: "Signed addition caused wrapping". This is SAW **catching
   real C++ UB**, not a limitation.

## Consequences for the workstream

- **E5 tool choice:** SAW is the primary whole-function tool. It tolerates
  `invoke`/`landingpad` when the exceptional path is infeasible under the
  cell precondition, and it can use overrides for the virtual
  `BaseSignatureChecker` calls. Alive2 cannot translate `EvalScript` /
  `VerifyScript` as emitted (336/32 and 58/6 invoke/landingpad at `-O0`).
- **E5 residual:** a scoped residual is only needed for behavior SAW cannot
  model (dynamic dispatch without an override, unbounded allocator effects),
  not for exceptions per se.
- **E3 crypto seam:** the same override mechanism is the symbolic checker;
  the claim stays conditional on "same-crypto" per `docs/DECISION-lax-ecdsa.md`.
- **Cell discipline:** every cell must state which exceptional/UB paths its
  precondition excludes, and why. SAW findings on `nsw` are UB evidence, not
  equivalence failures.

## Reproduction

```sh
export PATH=/tmp/opencode/equiv-work/saw/bin:$PATH
./run.sh
```

Outputs: `alive2_*.out`, `saw_*.out`, `features.ll`, and `features.bc`
(regenerable). `run.sh` contains the exact commands.
