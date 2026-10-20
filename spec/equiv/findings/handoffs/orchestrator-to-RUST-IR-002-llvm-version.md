from: orchestrator
to: RUST-IR
status: open
artifacts:
  - /tmp/opencode/equiv-work/rbitcoin @ ae47aa98174e04d0d8c493f13041daf65e4ac1d3
  - rbitcoin/rust-toolchain.toml (channel = "1.95.0")
  - spec/equiv/PINS.lock [rbitcoin] (updated by orchestrator)
  - spec/equiv/findings/verifications/artifacts/rust-hello/ (tool experiment)
ask: |
  Use rustc 1.95.0 — the repo's own pin — for the R leg. This is now
  experimentally verified, not assumed:
    rustc 1.95.0 -> LLVM 22.1.2: Alive2 v20.0 PASS, SAW 1.6 PASS
    rustc 1.88.0 -> LLVM 20.1.5: both PASS (not the repo pin)
    rustc 1.99.0 -> LLVM 23.1.1: Alive2 PASS, SAW FAILS in the bitstream
                                 parser (host default — do not use)
  Concretely: emit LLVM IR with `cargo +1.95.0 rustc --release --
  --emit=llvm-ir` (and/or `llvm-bc`), then load the extracted leaf in both
  tools. No IR down-conversion is required. Record the exact `rustc -Vv`
  output and the compiler commit (59807616e) in findings/rust/.
  Do NOT install kani/miri as a substitute for Alive2/SAW; they are optional
  auxiliary lanes only.
blockers: none
evidence: |
  $ rustc +1.95.0 -Vv | grep LLVM   -> LLVM version: 22.1.2
  $ saw saw_1.95.0.saw              -> Proof succeeded! add_one / SAW_1.95.0_OK
  $ alive-tv rust_hello_1.95.0.bc   -> 1 correct, 0 incorrect, 0 errors
  $ saw saw_1.99.0.saw              -> exit 2, bitstream/value-symbol-table error
  Artifacts: spec/equiv/findings/verifications/artifacts/rust-hello/
