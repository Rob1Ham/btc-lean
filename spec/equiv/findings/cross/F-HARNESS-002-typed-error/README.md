# F-HARNESS-002 typed-error probe

Advisory, off-pin probe for the R-leg boundary finding
[`../F-HARNESS-002-rbitcoin-boundary.md`](../F-HARNESS-002-rbitcoin-boundary.md).
Read [`report.md`](report.md) first. Nothing here is a PINS-listed artifact or
an equivalence claim.

## Layout

```
report.md              findings, blocker analysis, upstream ask, verdict
entry-typed.diff       drop-in diff for spec/equiv/shims/rust/entry.rs
cases.tsv              27 bounded tapes (26 ABI + 1 direct-only)
build.sh               builds witness, tests, pinned shim, proposed typed shim
src/typed_error.rs     dependency-free token -> equiv_error_kind classifier
src/witness.rs         calls rbitcoin public verify; prints raw msg + kind
tools/witness.py       C vs pinned-R vs proposed-typed-shim comparison
tools/abi_domain.py    amount/flags/spk/multi-input domain probes
tools/census.py        source-token completeness audit
tools/env.sh           pin/toolchain/hash record
logs/                  observed outputs (witness.tsv, census, domain, env)
```

`build/` is gitignored and must be regenerated.

## Reproduce

```sh
cd spec/equiv/findings/cross/F-HARNESS-002-typed-error

# rbitcoin clean at ae47aa98; rustc 1.95.0 available via rustup
./build.sh

python3 tools/census.py        # CENSUS_ACCOUNTED
python3 tools/witness.py       # WITNESS_TYPED_OK
python3 tools/abi_domain.py    # 6/8 divergences (expected)
./tools/env.sh                 # pins, versions, sha256
```

Defaults assume the fleet paths:

- `RBTC=/tmp/opencode/equiv-work/rbitcoin-clean`
- `TARGET=/tmp/opencode/equiv-work/target-195-lib`
- Core shim `/tmp/opencode/cbuild/libequiv-core.so`

Override with `RBTC=…`, `TARGET=…`, `python3 tools/witness.py --core-so …`.

## Status

- source/toolchain at the pin; artifacts off-pin (not in `PINS.lock`)
- 26/26 bounded ABI tapes match Core with the proposed classifier
- 6/26 match with the current pinned shim
- no R equivalence, no E3 green, no shared-file edits
