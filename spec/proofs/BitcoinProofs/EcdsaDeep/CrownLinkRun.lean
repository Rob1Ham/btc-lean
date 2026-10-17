import BitcoinProofs.EcdsaDeep.CrownBattery

/-!
# [CROWNLINK] CrownLinkRun — the runtime layer of the E05-battery ×
# E06-crown bridge: the 215 verdicts through `verifyImpl` (the W14b
# EcdsaTest conformance re-run over the CROWNLINK corpus)

Contributor CROWNLINK (recovery review 5), 2026-10-17. See `CrownBattery.lean`
(the corpus), `CrownLink.lean` (the bridge theorem), the kernel layer
`CrownLinkKernel.lean` (17/215 rows kernel-pinned) and
`db/findings-dl/CROWNLINK.md`.

**This layer's content**: compiled-interpreter execution (W14b
`EcdsaTest.lean:297-306` `main` shape, read-only; runner =
`lake env lean --run`, the `run_ecdsa.sh` route) of the consensus
verifier `verifyImpl` over all 215 corpus rows, against the battery's
`expected` verdicts — the verdict-pinning `hv` of `CrownLink.lean`'s
per-row bridge, for the 198 rows the KERNEL cannot reduce (the R6
wall: WF-recursive `mulP`/`expM`/`egcd` cannot be kernel-decided).
The 17 kernel rows (8 parse-rejects + 9 pk-structural-rejects,
`CrownLinkKernel.lean`) are re-run here too — the runtime layer
covers ALL 215 rows uniformly; the kernel layer is the
hypothesis-free pinning of 17 of them.

Verdict discipline: NO `native_decide` (D-004/D2), NO kernel
`decide` through the WF layer (R6); compiled runtime execution of
`verifyImpl` = the W14b conformance standard (EcdsaTest.lean:23-25
"deliberately NOT kernel/native_decide"). Exit 0 + `TOTAL 215
FAILURES 0` = all 215 verdicts = expected = (with `CrownLink`'s
`crownLink_corpus`) **all 215 battery verdicts pass through the E06
crown's equation side**: 139 accept-rows satisfy `VerifyEqRaw`
(E06 soundness), 76 reject-rows are dead on it (E06 exactness).
-/

namespace BitcoinProofs.EcdsaDeep.CrownLinkRun

open Bitcoin.Crypto.Ecdsa.Der Bitcoin.Crypto.Ecdsa.Verify
open BitcoinProofs.EcdsaDeep.CrownBattery

/-- The 215-verdict conformance pass (EcdsaTest.lean `main` shape:
`for r in crownBattery`, fail-count, TOTAL line, error-throw).
Verdicts are forced in the `!=`-discriminant (the lazy-eval trap
probed at CROWNLINK probe2). -/
def runBattery : IO Unit := do
  let mut fails := 0
  let mut accs := 0
  let mut rejs := 0
  for r in crownBattery do
    let got := verifyImpl r.sig r.pk r.msg
    if got != r.expected then
      fails := fails + 1
      IO.println s!"FAIL {r.name}: expected {r.expected}, got {got}"
    else if got then
      accs := accs + 1
    else
      rejs := rejs + 1
  IO.println s!"CROWNLINK-RUN total {crownBattery.length} accepts {accs} rejects {rejs}"
  IO.println s!"TOTAL {crownBattery.length} FAILURES {fails}"
  if fails > 0 then throw (IO.userError "CROWNLINK conformance failures")

end BitcoinProofs.EcdsaDeep.CrownLinkRun

/-- Runner entry (root `main` for `lake env lean --run`). -/
def main : IO Unit := BitcoinProofs.EcdsaDeep.CrownLinkRun.runBattery
