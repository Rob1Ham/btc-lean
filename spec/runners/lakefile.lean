import Lake
open Lake DSL

/-!
# `bvectors` — W07 conformance package (vector records + runner)

Own workspace (same pattern as `proofs/`): the root btc-lean workspace
requires ONLY `core`, so this package never gates `lake build` at the
root and never pulls mathlib. Path-dep on core resolves in place.

Targets:
  * `BitcoinVectors` — typed vector records (GENERATED data), the backend
    seam (hand-written), and the curated `decide`-theorem tier (GENERATED).
  * `vectorrunner`   — compiled conformance runner → `spec/db/results.json`.
-/

package «bvectors» where
  description := "btc-lean W07: conformance vector records, codegen'd decide tier, compiled runner"

require «core» from "../core"

@[default_target]
lean_lib BitcoinVectors where
  roots := #[`BitcoinVectors]

@[default_target]
lean_exe vectorrunner where
  root := `VectorRunnerMain
