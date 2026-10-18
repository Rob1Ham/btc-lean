# Audit handoff — 2026-10-18

Branch: `codex/audit-handoff-2026-10-18`. This snapshot includes all previous remediation commits through `3623588e52969b683fc1c0c9a1984f813db93ec5`, plus unfinished R07d BIP30 work. The comprehensive audit and goal are incomplete.

Read [GOAL-PROMPT.txt](GOAL-PROMPT.txt), [REVIEW.md](REVIEW.md), [execution-ledger.json](execution-ledger.json), and [R07d-PLAN.txt](R07d-PLAN.txt) before continuing. The ledger records completed phases; its handoff entry records the newer WIP state. Earlier phase reports retain their historical counts and results.

## Current work and evidence

R07d replaces the public validator's height-only BIP30 exemption with the actual candidate hash and relevant BIP34 ancestor. Six pinned fixture files and a public regression driver are included. Five proof files have been adapted to the new ordered precheck, but the proof package has **not** been rebuilt after these edits. This is a WIP commit, not a fully validated fix.

Saved [receipts](handoff-evidence/receipts.json) show the core build (`Bitcoin.Capstone.Block CapstoneTestSupport`) and the focused `Test/Capstone/Bip30.lean` driver both exited zero. All 24 focused cases pass. The [strict pre-fix reproduction](handoff-evidence/btc-lean-r07d-strict-before.log) confirms 13 expected failures and 11 passing controls against the frozen parent validator. Logs are preserved alongside the receipts; paths elsewhere in older reports may refer to files available only on the original machine.

## Resume on another machine

Check out this branch, install the exact Lean version from the committed toolchain files (Lean 4.35.0), and restore dependencies from the committed Lake manifests. Mathlib is pinned to `cfc55fc58714a59dc06e6e79edc6d1d95140d3c2`; preserve that pin. The original machine used a manually downloaded toolchain and cache under `/tmp`; neither tools nor caches are committed. Python gates used Python 3.12.11 with PyYAML. Consult the Makefile and prior validation reports for exact gate invocations and dependencies.

Start with:

```sh
cd spec/core
lake build Bitcoin.Capstone.Block CapstoneTestSupport
lake env lean --run Test/Capstone/Bip30.lean
cd ../..
python3 docs/reviews/2026-10-18/reproduce_bip30.py
```

Then finish proof integration in `spec/proofs`, add exact policy/public-dataflow contracts and axiom guards, wire the new test into Make targets, update rule references and proof census, and run required gates. The new test and helper lemmas are not yet registered in those inventories. The proof-package build and complete regression suite remain unverified at this snapshot.

Add the planned reference comparison against the actual Core BIP30 repeat and ancestor logic. Normative Core pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`; alternative: `9be056a8a72b624dae9623b2f7bded92c2a21c91`. Cached Core sources and temporary C++ harnesses are not transferred. Earlier reports describe scoped comparisons, not full historical validation.

After R07d, continue R07b genesis connection semantics, R08 full module/CI coverage and stale T3/T4 contracts, remaining audit findings and issue obligations. See the goal prompt and ledger for the full scope. No issues were closed or PRs created for this handoff.
