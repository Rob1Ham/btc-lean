---
# Cell push-encoding/C-L-w32-p2a-anchor
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c8042f92d3bed909ca40219a4d21fc9150cc1
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: push-encoding/C-L-w32-p2a-anchor
family: push-encoding
tool_status: both-green (symbolic predicate; L transcription, twin hook filed — see trust_note)
precondition: |
  - the predicate does not read flags, sigversion or policy.
  - the decoded witness (version, program) pair is given: version is the
    version number 0..16; program has length plen and bytes p0, p1.
postcondition: |
  - both legs return the same Boolean:
    version = 1 ∧ plen = 2 ∧ p0 = 0x4e ∧ p1 = 0x73.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-055
scr_row_coverage: >-
  full — the row is the P2A pattern: witness v1 with the two-byte program
  4e73, whose serialized scriptPubKey is the four bytes 51 02 4e 73.  The
  cell is symbolic over version, both program bytes and the program length,
  so every accept/reject edge is exercised.  The decoding of the serialized
  four-byte script into (version, program) is IsWitnessProgram's rule and is
  covered by push-encoding/C-L-w32-witness-program (SCR-053); it is not
  re-proved here.
patches: none
source_citations:
  - script.cpp:207-222 (IsPayToAnchor)
  - Defs.lean:523-526 (isPayToAnchor)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.cpp at the
  pin.  The imperative twin has no anchor helper: runtime.inc's
  verify_script_full returns TWIN_INVALID_UNSUPPORTED for every witness
  program, so there is no generated L function.  The L leg is therefore a
  direct, reviewed four-conjunct transcription of Defs.lean:523-526, not a
  call into generated twin code; the transcription is in the certificate.
  The C-L binding of the predicate into VerifyWitnessProgram's P2A branch is
  not proved by this cell.
  The exact twin hook that removes both caveats is filed, with a patch that
  was built and proved in a scratch tree (Alive2 bidirectional green, SAW
  4/4, twin smoke 147/147, contract-entry table 8/8 Core verdicts + 2
  declared E4 boundaries):
  findings/handoffs/CELLS-to-TWIN-002-p2a-anchor-hook.md.  It cannot land
  from this cell because twin/runtime.inc is content-addressed by 21 cells
  (42 certificates) that `make gate-ir-pin` replays; the
  determination and evidence are in
  findings/wave64/61-p2a-l-link/report.md.
  The Lean side already proves the binding (PDW57.isPayToAnchor_iff tagged
  SCR-055; PDW41.verifyWitnessProgram_p2a_ok; PDW59 v1 anchor/P2SH arms), but
  rules.yaml SCR-055 points lean_target at isWitnessProgram; the ledger ask
  is in the same handoff.  This cell uses no Core or twin patch.
---
