# notes — C-L-w32-opsuccess-scan

Row: SCR-172.

## What is proved (partial row)

The wire mapping is full; the scan is proved for two-opcode scripts, not an
arbitrary-length induction. See spec.md `scr_row_coverage`.

Two functions, both directions by Alive2 equality and each leg independently
checked by SAW against `cell.cry`:

1. `cell_isopsuccess(w)` for every byte `w` in `0x00..0xff` — the pure
   `IsOpSuccess` table.  The fifteen legacy-disabled bytes
   `0x7e-0x81, 0x83-0x86, 0x8d, 0x8e, 0x95-0x99` are all in the set, so under
   tapscript the same wire byte is OP_SUCCESSx, not DISABLED_OPCODE.
2. `cell_scan(w0, w1, discourage)` — the `ExecuteWitnessScript` pre-scan over
   a two-opcode tapscript.  For every ordered pair of non-push opcode bytes:
   the first success byte returns OK (0), or DISCOURAGE_OP_SUCCESS (36) when
   the policy flag is set; if neither byte is a success byte the scan
   completes (66) and EvalScript would run.  A success at `w0` makes `w1`
   irrelevant, which is the BIP342 ordering rule.

## What is not covered

- Push payloads and truncated-push ordering (F-DIV-001); the domain requires
  both bytes to be non-push opcodes and reports 254 otherwise.
- The rest of `ExecuteWitnessScript`: witness item size cap, initial stack
  depth, validation-weight budget, annex/control-block handling, and the
  eventual cleanstack/eval verdict.  Those are SCR-153/157/168 territory.
- `DISCOURAGE_OP_SUCCESS` is policy; only the flag-to-error mapping is
  modelled, not where policy flags come from.
- The row's statement in `F-E6-GAPS.md` that success "depends on the
  OP_SUCCESS pre-scan seam (SCR-153)" is refined here: the pre-scan itself is
  now a proved bounded cell; only its surroundings remain.

## Tool note

No generated handler is used on the L side because the twin's dispatch table
starts after the scan. The L leg is a literal transcription of
`Defs.lean:463-490` and the tapscript arm at `:1207-1216`, cited in `spec.md`.
Alive2 therefore checks two independent transcriptions; SAW checks each
against the Cryptol predicate.
