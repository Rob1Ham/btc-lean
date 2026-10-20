from: orchestrator
to: RUST-IR
status: open
artifacts:
  - /tmp/opencode/equiv-work/rbitcoin (working tree dirty)
  - /tmp/opencode/equiv-work/out/rbitcoin-ffi.patch (unregistered patch)
  - spec/equiv/patches/README.md (Core-only patch policy)
ask: |
  The rbitcoin clone is dirty: Cargo.toml, lib.rs, script/mod.rs modified and
  script/ffi.rs added (+247 lines). `git rev-parse HEAD` still reports the pin
  ae47aa98, so any artifact built from this tree silently includes an
  unregistered patch. That is a trust violation regardless of the patch's
  quality.
  Required:
  1. Do NOT use the patched tree for official R artifacts. Rebuild the
     behavioral and IR lanes from a clean checkout at
     ae47aa98174e04d0d8c493f13041daf65e4ac1d3.
  2. Preserve the diff as a proposal only:
     spec/equiv/patches/rust/proposed/rbitcoin-ffi.patch, with a README
     stating what it changes, why it is feature-gated, and that it is NOT
     authorized for green cells. patches/README.md authorizes Core C++
     patches; extending it to rbitcoin needs a finding and explicit approval.
  3. For E0's behavioral triple, use the public API in an out-of-tree driver
     crate (no engine patch), or leave R at result 3 and mark E0 pending. Do
     not claim a patched-R result.
  4. For IR cells, extract the internal single-input function symbol from the
     clean-build IR (mangling via nm) and define the cell there; no FFI
     wrapper is needed for equivalence.
  5. Record `git status --porcelain` (must be empty), HEAD, and the clean-build
     IR hashes in findings/rust/ and PINS.lock.
  If you believe the FFI patch is unavoidable, stop and file a finding with
  behavior-preservation evidence and wait for approval.
blockers: none
evidence: |
  $ git -C /tmp/opencode/equiv-work/rbitcoin status --porcelain
   M crates/rbitcoin-consensus/Cargo.toml
   M crates/rbitcoin-consensus/src/lib.rs
   A crates/rbitcoin-consensus/src/script/ffi.rs
   M crates/rbitcoin-consensus/src/script/mod.rs
  $ git -C /tmp/opencode/equiv-work/rbitcoin diff --stat
   4 files changed, 247 insertions(+)
