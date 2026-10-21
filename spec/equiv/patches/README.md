# Core patch policy and registry

Small modifications to the pinned Bitcoin Core source are allowed **only** to
make a function expressible for a tool. They must never change consensus
behavior.

## Rules

1. **Minimal and localized.** One intent per patch (devirtualize a checker,
   replace a throw with an error return at the same site, remove a
   ptrtoint, split a function for cell slicing).
2. **Tracked.** Each patch has an id and a file here, plus the diff in
   `patches/core/<id>.patch`.
3. **Behavior-preserving evidence.** Differential run against the unpatched
   build on the full corpus plus fuzz lanes; zero divergences required.
   Record the command, corpus hash, and result.
4. **Explicit in results.** IR artifacts record `patched: yes` and the patch
   id set. Cells that depend on a patch say so in their trust note.
5. **Upstreamable in principle.** If a patch is not upstreamable, flag it.

## Registry

| ID | Upstream file:line | Purpose | Evidence | Upstream status |
|---|---|---|---|---|
| — | — | — | — | — |

## Forbidden

- Changing opcode semantics, limits, flag handling, error selection, or
  serialization.
- Removing checks to make a cell pass.
- Patching based on a divergence without filing the divergence first.

## Non-Core legs (L and R)

The patch allowance above is for the **C leg**. It does not authorize changes
to the other two legs:

- **L (twin).** The twin is generated from the Lean model. Do not patch it to
  hide a Lean/Core divergence; record the divergence instead (e.g.
  `findings/cross/F-DIV-001-eager-parse.md`).
- **R (rbitcoin).** R is the pinned third-party engine. Engine source changes
  are not authorized for any official artifact. A harness wrapper may live
  outside the crate, or the cell may extract the engine's internal symbol from
  a clean build. If a wrapper truly cannot be built without modifying
  rbitcoin, write a finding and a proposed `patches/rust/` policy and **do not
  apply it** to the artifact of record. Proposals may be kept as diffs under
  `patches/rust/proposed/` with status `not authorized`.

Every official artifact records the source tree's `git status --porcelain`
(must be empty) and `git rev-parse HEAD`. A dirty tree cannot inherit the pin.

