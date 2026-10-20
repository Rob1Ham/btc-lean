# E4:F-TOOL-001 — the bounded leaf seam cannot ingest whole VerifyWitnessProgram

Area: TOOL
Legs: C, L
Cell: `cells/e4-witness/C-L-witness-v0-dispatch` (leaf only; no whole-entry cell)
Disposition: tool-gap (seam), open
Scope: E4-DISPATCH role-local finding id. Cite as `E4:F-TOOL-001`; promote to a
global `F-TOOL-nnn` only by orchestrator decision.

## Symptom

The E4 harness can prove a loop-free dispatch leaf, but it cannot load the
whole `VerifyWitnessProgram` / `ExecuteWitnessScript` / `EvalScript` chain into
either tool. Rows whose claim needs that chain are therefore not "not
attempted"; they are outside the tool seam.

## Evidence (recorded, not re-run by E4-DISPATCH)

1. `cells/_tools/gate/whole_entry_alive2_probe.txt` — recorded probe of the
   whole twin entry:
   - Alive2 v20 reports `ERROR: Unsupported attribute: noalias`,
     `nocapture`, `sret(...)`, and `Could not translate` for
     `verify_script_full`, `eval_script`, `classify_push_only`, etc.;
   - summary `48 Alive2 errors` while 5 functions translate.
2. `findings/verifications/artifacts/tool-limits/README.md` — observed on the
   pinned host: Alive2 cannot translate `EvalScript`/`VerifyScript` as emitted
   (invoke/landingpad), while SAW can tolerate them under a domain
   precondition and with overrides. That is a SAW capability, not a proved
   whole-entry equivalence.
3. `cells/e4-witness/C-L-witness-v0-dispatch/alive2/result.txt` and
   `saw/result.txt` — the actual E4 run: the loop-free
   `cell_v0_dispatch(i64,i64)` is both-green. No whole-entry claim is made.

## Consequence

- Full-dispatch / EvalScript-loop / ExecuteWitnessScript rows (SCR-136,
  SCR-138, SCR-153, SCR-154, SCR-156, SCR-167, SCR-183) are
  `unjudged-seam`, not `gap`.
- The E4 leaf proves dispatch predicates only. A future whole-function SAW
  campaign may use checker overrides, but that is E5 work and is conditional
  on `docs/DECISION-lax-ecdsa.md` for the crypto seam.
- Crypto/hash/EC seam rows cite `docs/DECISION-lax-ecdsa.md` directly; this
  finding is not a substitute for that decision record.
