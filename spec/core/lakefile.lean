import Lake
open Lake DSL

/-!
# `core` package — the zero-dependency Bitcoin consensus specification

Everything under namespace `Bitcoin.*` lives here. NO mathlib, NO FFI,
`native_decide` only under `Test/`-scoped files (the L1 axiom-pin gate).

Ground truth: Bitcoin Core v32.99 @ `cce32b168` (traceability DB pin; B-track
line anchors for B2–B5 were taken @ `cce32b168`, re-verify on rebase).
-/

package «core» where
  description := "btc-lean core: executable, eventually-proven Bitcoin consensus rules"

@[default_target]
lean_lib Bitcoin where
  -- `Bitcoin.lean` imports the selected production closure. Other library
  -- modules require the explicit module matrix.

@[default_target, test_driver]
lean_exe btclean where
  root := `Main

/-- Compiled partial anchor replay; ancestor/time context is not supplied. -/
lean_exe capstone where
  root := `Test.Capstone.Run

/-- Issue 22 single-entry-point and partial-report regression. -/
lean_exe issue22 where
  root := `Test.Capstone.Issue22

/-- Shared fixture decoding for public Taproot regressions. -/
lean_lib CapstoneTestSupport where
  roots := #[`Test.Capstone.TaprootFixture]
