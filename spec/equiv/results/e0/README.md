# E0 tape run — three legs green

**Date:** 2026-10-19. **Verdict: PASS** (`make e0` exits 0). This is a
**harness/ABI** pass, not an LLVM IR proof and not SCR coverage.

```
$ make e0
...
== three-leg E0 shims ==
  C: present: entry.cpp
  L: present: entry.cpp
  R: present: entry.rs
  triple script: GREEN (rc=0)

== summary ==
  TOOLS probes: GREEN
  Three-leg hello-world: GREEN (executed by tools/tests/e0-triple.sh)
  RESULT: PASS
```

Raw tape output (`results/e0/run-triple.txt`):

```
[PASS] OP_1 passes: C=(1,0)  L=(1,0)  R=(1,0)  want=(1, 0)
[PASS] OP_0 fails: C=(0,2)  L=(0,2)  R=(0,2)  want=(0, 2)
[PASS] OP_RETURN fails: C=(0,3)  L=(0,3)  R=(0,3)  want=(0, 3)
[PASS] empty tx is bad input: C=(2,1)  L=(2,1)  R=(2,1)  want=(2, 1)
E0_TRIPLE_OK
```

All three legs agree on verdict **and** Core error ordinal. `run-pre-R.txt`
preserves the earlier C/L-only run for history.

## Exact artifacts

| Artifact | sha256 |
|---|---|
| C `libequiv-core.so` (g++ 13.3.0; test-only `FileCommit`/`TruncateFile` stubs) | `5fef1df004adae637ffd7d3d7bf7dc96700c552dc2c22729d0de06d81457fbb5` |
| L `twin/build/libtwin.so` (generated twin; clang 20.1.2) | `b9ed129b9a0bd719da789c7accab7e522f436b08eb33e8cd18874659edeea72b` |
| L generated `twin/build/twin.cpp` (`gen.py --check` passes) | `39ab7c66ea112ea0108e6f2b93c6bbb8ad0b8261f3230310c989cb8d0af2478f` |
| R `shims/rust/build/libequiv-rust.so` (clean public-API shim) | `73e3d2d96de864e11e7cfb7cc5cc9fbba5d0dad1dc5de08b4cad6114ad1dffde` |
| contract bundle (`ABI.md`, `tape.md`, `error_kind.h`, `corpus_schema.md`) | `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6` |
| `tools/tests/e0_triple.py` | `13aa7f5dd64deecd173ae25923b114d0dc4cafd874731853a44375e07998887c` |
| `tools/tests/e0-triple.sh` | `a153671bc492b9f3064e32082f6342cdde16d24712bf5996a58e37184b044586` |

## Leg provenance

- **C**: behavioral build of the pinned Core `interpreter.cpp` shim. It is
  **not** the proof build: g++ rather than the pinned clang, plus test-only
  file-I/O stubs. The proof IR lane is `[core.ir]` in `PINS.lock`.
- **L**: the generated twins from `twin/gen.py`, compiled by clang 20.1.2.
  This build includes the F-DIV-002 `OP_EQUAL` fix (false pushes the empty
  vector). `python3 twin/gen.py --check twin/build/twin.cpp` exits 0.
- **R**: `shims/rust/build.sh` builds the crate rlib from the **clean**
  rbitcoin worktree at `ae47aa98…` with rustc **1.95.0** (the repo pin) and
  links a standalone ABI v2 shim against the **public**
  `verify_tx_scripts_with_flags` API. No engine source is patched. The
  proposal-only `equiv-ffi` lane is not used.

## Why this is still not a proof

1. **No IR is checked by E0.** It exercises shared libraries through ABI v2.
   Alive2/SAW evidence starts at the per-cell level.
2. **The C build is behavioral.** No cell may cite
   `/tmp/opencode/cbuild/libequiv-core.so` as IR evidence.
3. **The R shim is boundary-limited.** rbitcoin returns
   `ConsensusError::Script(String)` rather than a typed `ScriptError`
   (R-GAP-01). The shim maps only the tokens E0 exercises (`script false`,
   `unknown opcode 0x6a`, other `unknown opcode`); every other failure stays
   `EQUIV_ERR_UNKNOWN_ERROR`. It also accepts one input, `input_index == 0`,
   `flags == 0`, and `amount >= 0`; anything else is a named bad-input result.
   E3 error-enum equality is therefore **blocked** on R until a typed error or
   a complete tested string map exists.
4. **Zero of 183 SCR rows are adjudicated.** E0 is a gate, not coverage.

## Reproduce

```sh
cd spec/equiv
make pins                  # all pins filled, tool probes OK
shims/rust/build.sh        # RBTC=/path/to/clean/rbitcoin-clean
make e0                    # E0_TRIPLE_OK
```

`shims/rust/build.sh` refuses a dirty tree or a HEAD other than the pin. The
C shim build recipe is in `shims/README.md`; its reproducibility as a tracked
script is still an E6 packaging item.
