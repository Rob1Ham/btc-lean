import Lake
open Lake DSL

/-!
# btc-lean spec — workspace root

Single repo, two lake packages (C1 architecture, report 10 F4/R1):

  * `core`   — zero-dependency, all `Bitcoin.*` namespaces, executable spec.
  * `proofs` — `Bitcoin.Proofs.*`, mathlib leaf-dep allowed.

## Deliberate scope of THIS workspace

The root workspace requires ONLY `core`, so `lake build` / `lake test`
here never resolve or build mathlib (the proofs package's mathlib
require must not gate core builds — earlier plan §W01 brief). The
`proofs` package is its own workspace: `cd proofs && lake update && lake
build` is the deliberate, W15-owned mathlib step.
-/

package «btclean» where
  description := "btc-lean: a complete, executable, eventually-proven Lean 4 formalization of Bitcoin consensus rules"

require «core» from "core"

@[default_target]
lean_lib BtcLean where
  roots := #[`BtcLean]

@[test_driver]
lean_exe specsmoke where
  root := `SpecSmoke
