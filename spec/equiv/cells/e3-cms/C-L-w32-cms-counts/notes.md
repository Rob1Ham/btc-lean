# Notes — `e3-cms/C-L-w32-cms-counts`

- **repo_head:** `805c8042f92d3bed909ca40219a4d21fc9150cc1`
- **Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
- **row:** SCR-114 (`full` within the cell model)
- **result:** Alive2 `--bidirectional` green (1/1 function); SAW green
  (54/54 proofs, 27 scenarios × 2 legs).
- **patches:** none.

## Reproduce

From the repo root:

```sh
spec/equiv/cells/e3-cms/C-L-w32-cms-counts/alive2/run.sh
spec/equiv/cells/e3-cms/C-L-w32-cms-counts/saw/run.sh
sha256sum -c spec/equiv/cells/e3-cms/C-L-w32-cms-counts/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/e3-cms/C-L-w32-cms-counts/saw/certificate.sha256
```

## Design

`cell_cms_counts(n, keys_enc, sigs_enc, ops_before)` is
`interpreter.cpp:1122-1146`. Elements are encoded injectively for
`len ≤ 5`; `e32_top` is the shared stack model (slot 1 = nKeys, slot
`nKeys+2` = nSigs, everything else a one-byte zero). `ops_before` is an
input, so SCR-113 is not claimed.

Alive2 quantifies over all 64-bit inputs, so every branch is exercised
without witnesses. SAW compares both linked modules to 27 constants from
`oracle_counts.py`, which is written from the rule text and the Core lines,
not from the cell sources.

## Known limitation found while mutating

An uninitialised decode out-parameter produced an `undef` phi incoming;
Alive2 then reported a behavioural mutant (`nk > 19`) as equivalent. The
cell now initialises `nk`/`ns` (and the harness accessor) to `0`. The
mutant is caught: `0x48` vs `0x28`. See
`findings/wave32/20-cms-114-117/report.md` §2 and §4.

## Tools

clang/LLVM 20.1.2, alive-tv v20.0, SAW 1.6 (`68eed5f release-1.6`),
Z3 4.8.12. The Alive2 lane compiles both legs at -O2 (the runner-wide
reason is in `findings/wave32/20-cms-114-117/report.md` §2); SAW uses -O0.
Alive2 runs with `--smt-to=600000` (runner default).
