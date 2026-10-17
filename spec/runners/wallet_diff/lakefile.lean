import Lake
open Lake DSL

/-!
# wallet_diff-descriptor runner package

A separate small workspace under `spec/runners/wallet_diff/` so the root
`spec/lakefile.lean` stays untouched. It path-depends on the `core` package
and builds the `DescDump` executable used by `compare_desc.py`.
-/

package «wallet-diff-desc» where
  description := "btc-lean wallet descriptor differential dump"

require «core» from "../../core"

@[default_target]
lean_exe descDump where
  root := `DescDump
