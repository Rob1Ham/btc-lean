from: orchestrator
to: CORE-IR
status: open
artifacts:
  - /tmp/opencode/equiv-work/ir/interpreter-O0.ll
  - /tmp/opencode/equiv-work/ir/interpreter-O1.ll
  - spec/equiv/PINS.lock [llvm] (clang 20.1.2)
ask: |
  The Core IR currently on disk is NOT the pinned-clang artifact:
  `interpreter-O0.ll` carries producer "Ubuntu clang version 18.1.3" and
  `interpreter-O1.ll` is from the same build. The pin is clang 20.1.2
  (`/usr/bin/clang-20`, `/usr/bin/clang++-20`, installed and recorded in
  PINS.lock). Regenerate all Core/Core-shim IR with clang 20.1.2, at -O0
  (primary) and -O1 (robustness), and record sha256 hashes in
  findings/core/ and PINS.lock. Mark the clang-18 artifacts non-proof and
  ensure no cell cites them.
  Also: the CONTRACT smoke link used test-only `FileCommit`/`TruncateFile`
  stubs. The proof build must use Core's real objects (CMake-derived), not
  those stubs. Record the exact object list and flags.
  Do not change Core source unless a patch is registered under
  patches/README.md with differential evidence.
blockers: none
evidence: |
  $ grep -m1 producer /tmp/opencode/equiv-work/ir/interpreter-O0.ll
  !5 = !{!"Ubuntu clang version 18.1.3 (1ubuntu1)"}
  $ /usr/bin/clang-20 --version | head -1
  Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)
