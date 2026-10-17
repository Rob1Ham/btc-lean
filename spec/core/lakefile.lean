import Lake
open Lake DSL

/-!
# `core` package — the zero-dependency Bitcoin consensus specification

Everything under namespace `Bitcoin.*` lives here. NO mathlib, NO FFI,
`native_decide` only under `Test/`-scoped files (D2 ladder L1 gate).

Ground truth: Bitcoin Core v32.99 @ `cce32b168` (traceability DB pin; B-track
line anchors for B2–B5 were taken @ `cce32b168`, re-verify on rebase).
-/

package «core» where
  description := "btc-lean core: executable, eventually-proven Bitcoin consensus rules"

@[default_target]
lean_lib Bitcoin where
  -- Root module `Bitcoin.lean` transitively imports every submodule.

@[default_target, test_driver]
lean_exe btclean where
  root := `Main

/-- W17 capstone runner (compiled): the end-to-end anchor validation. -/
lean_exe capstone where
  root := `Test.Capstone.Run
