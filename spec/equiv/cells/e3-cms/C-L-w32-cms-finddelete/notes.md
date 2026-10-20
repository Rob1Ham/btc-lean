# Notes — `e3-cms/C-L-w32-cms-finddelete`

- **repo_head:** `805c8042f92d3bed909ca40219a4d21fc9150cc1`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **row:** SCR-115 (`partial`: script ≤ 8, needle ≤ 4; general-needle chain
  only nSigs ≤ 2)
- **result:** Alive2 `--bidirectional` green (5/5 functions); SAW green
  (128/128 proofs, 64 scenarios × 2 legs).
- **patches:** none.

## Reproduce

From the repo root:

```sh
spec/equiv/cells/e3-cms/C-L-w32-cms-finddelete/alive2/run.sh
spec/equiv/cells/e3-cms/C-L-w32-cms-finddelete/saw/run.sh
sha256sum -c spec/equiv/cells/e3-cms/C-L-w32-cms-finddelete/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/e3-cms/C-L-w32-cms-finddelete/saw/certificate.sha256
```

## Design

Five functions: `cell_fd_found`, `cell_fd_len`, `cell_fd_bytes`,
`cell_fd_chain` (nSigs ∈ {0,1,2}, arbitrary caller needles) and
`cell_fd_chain_n` (nSigs 0..20 symbolic, one-byte signature pushes,
BASE deletes, non-BASE no-op). The C leg is a line-cited slice of
`script.cpp:239-265` plus `interpreter.cpp:1152-1160`; the L leg is a
reviewed transliteration of the Lean `findAndDeleteMatches` /
`findAndDeleteAux` / `findAndDelete` recursion and the pre-loop `foldl`.

Bounded domain: script ≤ 8 bytes, needle ≤ 4 bytes; inputs outside it return
`0xffffffffffffffff` from both legs. Cases exercised: a match inside a push
payload (not deleted), a match spanning an opcode boundary (not deleted),
adjacent greedy matches (all deleted), truncated pushes, PUSHDATA1/2/4
walks, no-match, empty needle.

## Mutation

Dropping the final tail accumulation is caught by Alive2 for both
`cell_fd_found` and `cell_fd_chain_n`. See
`findings/wave32/20-cms-114-117/report.md` §4.

## Tools

clang/LLVM 20.1.2, alive-tv v20.0, SAW 1.6 (`68eed5f release-1.6`),
Z3 4.8.12. The Alive2 lane compiles both legs at -O2 (SAW at -O0): at -O1
Alive2 v20.0 did not unroll the bounded loops and returned a vacuous green
for a bytes-changing mutant; at -O2 the mutant is caught. Alive2 runs with
`--smt-to=600000` (runner default).
