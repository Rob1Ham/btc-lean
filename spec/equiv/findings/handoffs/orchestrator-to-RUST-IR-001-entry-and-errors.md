from: orchestrator
to: RUST-IR
status: open
artifacts:
  - /tmp/opencode/equiv-work/rbitcoin @ ae47aa98174e04d0d8c493f13041daf65e4ac1d3
  - rbitcoin/rust-toolchain.toml (channel = "1.95.0")
  - rbitcoin/crates/rbitcoin-consensus/src/lib.rs (public tx-level entry)
  - rbitcoin/crates/rbitcoin-consensus/src/script/mod.rs:50 (verify_job_all_inputs, pub(crate))
  - rbitcoin/crates/rbitcoin-consensus/src/error.rs (ConsensusError::Script(String))
  - rbitcoin/script-oracle/verify.cpp (a *Core* oracle, not an rbitcoin shim)
ask: |
  Three decisions that shape the R leg:
  (1) Entry point. The only public script path is
      `verify_tx_scripts_with_flags(prevouts, tx, flags)`, and it hops to a
      detached worker thread (`script_pool::run_detached_join`). The actual
      single-input verifier (`script::verify_input`, `verify_job_all_inputs`)
      is `pub(crate)`. Do NOT put the threaded tx-level entry in a cell's IR.
      Preferred: compile rbitcoin-consensus with `--emit=llvm-ir`, locate the
      mangled symbol for the single-input interpreter/verify function with
      `nm`, and define the cell at that function boundary (the same technique
      CORE-IR uses for Core's non-exported `EvalScript`). A separate
      `equiv-shim` crate may call the public API for the E0 hello-world only.
  (2) No rbitcoin source patch without policy. `patches/README.md` authorizes
      Core C++ patches only. If a callable single-input entry is unavoidable,
      file a finding and a proposed `patches/rust/` policy before touching the
      crate; do not patch rbitcoin unilaterally.
  (3) Error kind. rbitcoin surfaces failure as
      `ConsensusError::Script(String)` (e.g. "SIG_DER", "EVAL_FALSE",
      "WITNESS_UNEXPECTED"), not as Core ordinals. E3's error-enum equality
      therefore needs a total, tested string→ordinal map, and a finding for
      every Core code rbitcoin cannot distinguish. Do not assume 1:1.
blockers: none
evidence: |
  $ git -C /tmp/opencode/equiv-work/rbitcoin rev-parse HEAD
  ae47aa98174e04d0d8c493f13041daf65e4ac1d3
  $ cat rust-toolchain.toml   -> channel = "1.95.0"
  $ grep -n "mod script" crates/rbitcoin-consensus/src/lib.rs  -> 12:mod script;
  $ grep -n "verify_job_all_inputs" .../script/mod.rs  -> 50:pub(crate) fn ...
  $ grep -A2 '^name = "secp256k1"' Cargo.lock
  secp256k1 0.28.2 and 0.29.1 (rust-bitcoin 0.32.102, default features)
  => same libsecp256k1 C family as Core; record the exact versions and compare
     with Core's src/secp256k1 pin for the same-crypto premise.
