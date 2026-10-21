# push-encoding/C-L-w32-p2a-anchor

SCR-055 at the predicate level.

Both the C and L legs are four comparisons.  The C leg is the core of
`IsPayToAnchor`; the L leg is a reviewed transcription of the Lean
`isPayToAnchor` because the imperative twin has no anchor helper.  This is
called out in `spec.md` and is the main trust gap of the cell.

The serialized 4-byte script `51 02 4e 73` is recognised by the sibling cell
`push-encoding/C-L-w32-witness-program` (SCR-053) as witness v1 with program
length 2; this cell then recognises the program bytes as `4e73`.

## L-link status (wave 64, task 61)

The gap has two halves and they have different dispositions:

1. **Generator-linked L leg — buildable, hook filed.**  A 48-line
   `twin/runtime.inc` hook (`is_pay_to_anchor`, `pay_to_anchor_branch`,
   `decode_witness_program`, plus the two branch sites) turns the L leg into a
   call into generated twin code.  It was built and proved in a scratch tree:
   Alive2 bidirectional green for the predicate and the branch guard, SAW 4/4,
   the twin's own smoke suite 147/147, and an `equiv_entry` tape table with
   8/8 Core verdicts (the native and P2SH-wrapped P2A arms, including the
   `DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM` ordering edge) plus 2 declared E4
   boundaries (witness v0, bare v1-2-byte non-P2A).
   Patch and acceptance: `findings/handoffs/CELLS-to-TWIN-002-p2a-anchor-hook.md`.
   It is not landed here because `twin/runtime.inc` is hashed by 21 cells
   (42 certificates) and `make gate-ir-pin` replays them; a wave-64 sibling
   task edits the same twin files.

2. **Lean binding — already proved, ledger target wrong.**  The Lean model
   proves the branch: `PDW57.isPayToAnchor_iff` (`@[rule "SCR-055"]`),
   `PDW41.verifyWitnessProgram_p2a_ok` (`@[rule "TPR-004"]`, every witness /
   flags / policy / checker), `PDW59.verifyWitnessProgram_v1_anchor_ok`
   (SCR-150) and the v1/P2SH policy arms (SCR-151).  But `rules.yaml` SCR-055
   sets `lean_target: Bitcoin.Interpreter.Defs.isWitnessProgram` — the
   *recognizer*, not the anchor predicate — so the row does not name its own
   evidence.  The ledger ask is in the same handoff.

Full evidence, commands and artifact hashes:
`findings/wave64/61-p2a-l-link/report.md`; runnable probes
`p2a_link_probe.py` (contract entry) and `p2a_link_probe.lean` (model).
