import Lake
open Lake DSL

/-!
# `proofs` package — theorems about the core (`Bitcoin.Proofs.*`)

Mathlib leaf-dependency is ALLOWED here and ONLY here (charter exit
criterion 1, C1's two-package architecture F4/R1). The core package
(`../core`) must stay zero-dependency so `#print axioms` audits are
trivially interpretable.

## Bootstrap (skeleton)

This package is its own lake workspace (the repo-root workspace
deliberately does NOT require it — see `../lakefile.lean`). The mathlib
dependency is DECLARED below; activating it is a deliberate step owned
:

    cd spec/proofs
    lake update        # resolves mathlib + toolchain deps (large)
    lake build         # builds BitcoinProofs against core + mathlib

Until that runs there is no lake-manifest.json here; nothing outside
this directory will ever try to resolve mathlib.
-/

package «proofs» where
  description := "btc-lean proofs: Bitcoin.Proofs.* theorems (mathlib leaf-dep allowed)"

require core from "../core"

require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "master"

@[default_target]
lean_lib BitcoinProofs where
  roots := #[`BitcoinProofs]
