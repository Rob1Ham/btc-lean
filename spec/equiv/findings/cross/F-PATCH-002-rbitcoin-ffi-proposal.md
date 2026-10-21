# F-PATCH-002 — rbitcoin FFI patch is proposal-only and must not back artifacts

- **status:** open (policy; proposal retained, not applied)
- **legs:** R
- **cells:** any R cell that would use `rbtc_rust_verify` / the `equiv-ffi`
  feature
- **severity for the claim:** high if used. The pinned tree would be dirty and
  the artifact would not be the pinned rbitcoin.

## Symptom

The working rbitcoin clone at `ae47aa98…` carries an unregistered change:
`equiv-ffi` feature + `crates/rbitcoin-consensus/src/script/ffi.rs`
(+247 lines across four files). It provides a 7-argument entry, but it is not
authorized by `patches/README.md`, is not a tracked patch under
`patches/rust/`, and the resulting tree cannot inherit the pin. The E0 run
therefore does **not** use it: `shims/rust/build.sh` refuses a dirty tree and
links the clean public API instead (`results/e0/`).

The proposal also has boundary hazards that would need review before it could
be an official entry (null/length handling, panic mode, and error-kind
mapping). Those are moot while it is proposal-only.

## Evidence

- `findings/rust/rbitcoin-ffi.patch` (proposal diff).
- `findings/rust/artifacts.md` (dirty tree, +247 lines, four files).
- `shims/rust/build.sh` (clean-tree guard).
- `PINS.lock [rbitcoin] note` (FFI artifacts are proposal only).

## Disposition

- Keep the diff as a proposal under `findings/rust/`; do **not** apply it to
  the pinned tree or cite its artifacts.
- If it is upstreamed, register it as a tracked patch with behavior-
  preservation evidence, then re-pin and re-run E0/E1.
- The clean public-API shim is the only official R behavioral lane until then.
