import Bitcoin.Crypto.Seam.Interface
import Bitcoin.Crypto.Seam.Mock
import Bitcoin.Crypto.Ecdsa.Verify
import Bitcoin.Script.Interp

/-!
# Bitcoin.Proofs.Shortcuts.CENSUS2.FailOpenStub — B03/D03/F01 re-land (RC4)

CENSUS2 re-land of S05's phantom
`Shortcuts/S05/FailOpenStub.lean` (F-C2-001). SCS-B03/D03/F01, the
fail-OPEN axis + the fail-closed controls:

* the real lax-ECDSA verifier rejects a non-DER-headed signature
  BEFORE any EC math (`parseDerLax:146`'s first check — the
  `CensusProbeA.c2_parseDerLax_bad_head` / `c2_verifyImpl_bad_head`
  general pair; the witness side re-landed here for the splits);
* the fail-OPEN witnesses: `stubChecker`
  (`Seam/Interface.lean:161-163`, both entry points nonempty-accept)
  and the shipped PoC interpreter's stub `OP_CHECKSIG`
  (`Script/Interp.lean:86-90`, runsTrue on nonempty non-DER garbage)
  both accept what the real verifier REJECTS — F-W16-005's stub-blindness
  made a *soundness* edge (S05 F-S05-004);
* the fail-CLOSED control: `mockFind` misses return `false`
  (`Seam/Mock.lean:32`, the `[]`-clause = `mockFind_nil` :66, re-pinned
  at the checker level) — the two stand-ins SPLIT on the failure
  axis (mock miss = fail-closed = agrees with the real verifier;
  stub = fail-open = diverges);
* the negative control (A21/G08-style): the fail-open stub still
  satisfies the frozen-seam laws (`stubChecker_deterministic`
  `Interface.lean:171`, `mockChecker_deterministic` `Mock.lean`,
  both `rfl`) — the frozen-seam laws do NOT discriminate the failure
  direction; stub-safety needs the fail-axis pins, not the seam's own
  laws (the stub-blindness statement at the checker level).

Both fail-open sites are off the production verdict path (B01/B02
pinned in `FailClosedSeam.lean`; `stubChecker` reaches a verdict only
via the `Inhabited` default, `verifyInput` binds `realCheckerOf`
explicitly) — the edge is real but unreachable (S05 F-S05-004:
unreachable-by-grep + fail-closed-at-the-sites-by-theorem).

Nothing reduces `verifyImpl`'s EC math (reduction discipline), the SHA256
layer, or any tagged rule row. No `@[rule]`. New file, CENSUS2-owned,
outside the `BitcoinProofs` root closure (A18 pattern).
-/

namespace Bitcoin.Proofs.Shortcuts.CENSUS2.FailOpenStub

open Bitcoin.Data Bitcoin.Crypto.Seam Bitcoin.Crypto.Seam.Mock
  Bitcoin.Crypto.Ecdsa.Verify Bitcoin.Script

/-! ## The witness (push-built, F-E07-003 decide-clean) -/

/-- The bad-head witness `#[0x31]` (nonempty, non-`0x30` head):
push-built ByteArrays (`.push`/`.data.size`/`.data.getD` only = the
`PubKeyCorProbe` P1b decide-clean representation). -/

private def c2oW1 : ByteArray := ByteArray.empty.push 0x31  -- "sig" (bad head)
private def c2oW2 : ByteArray := ByteArray.empty.push 0x02   -- "pk"
private def c2oW3 : ByteArray := ByteArray.empty.push 0x00   -- code/msg

/-! ## B03 — the stub checker fails OPEN (SCS-B03) -/

/-- `stubChecker` (Seam/Interface.lean:161-163) accepts ANY nonempty
`(sig, pk)` on the ECDSA entry point — including the non-DER-headed
witness the real verifier rejects (`verifyImpl … = false` below). -/

theorem c2o_stub_ecdsa_fails_open :
    stubChecker.checkECDSASignature c2oW1 c2oW2 c2oW3
      SigVersion.base (default : ScriptExecutionData) = true := by
  decide

/-- Same on the Schnorr entry point (both lanes of the frozen stub
are nonempty-accept). -/

theorem c2o_stub_schnorr_fails_open :
    stubChecker.checkSchnorrSignature c2oW1 c2oW2
      SigVersion.base (default : ScriptExecutionData) = true := by
  decide

/-! ## F01 — the PoC interpreter's stub OP_CHECKSIG fails OPEN (SCS-F01) -/

/-- The shipped PoC interpreter's stub `OP_CHECKSIG`
(`Script/Interp.lean:86-90`: pops `(pk, sig)`, pushes `0x01` iff both
nonempty) accepts nonempty non-DER garbage: `runsTrue` on the
checksig script over the same witness. -/

theorem c2o_poc_stub_fails_open :
    runsTrue 10 [ScriptInstr.push c2oW1, ScriptInstr.push c2oW2,
      ScriptInstr.checkSig] = true := by
  decide

/-! ## D03 — the soundness edge: stub/PoC accept what the real verifier rejects -/

/-- The stub vs the real lax-ECDSA verifier on the SAME
`(sig, pk)`: stub `true`, `verifyImpl` `false` — the stub has no
real-EC backing = a *soundness* edge, one step beyond F-W16-005's
*coverage* blindness (S05 F-S05-004). -/

theorem c2o_stub_not_sound_witness :
    stubChecker.checkECDSASignature c2oW1 c2oW2 c2oW3
        SigVersion.base (default : ScriptExecutionData) = true
      ∧ verifyImpl c2oW1 c2oW2 c2oW3 = false := by
  decide

/-- The same divergence for the shipped PoC interpreter
(root-imported `Bitcoin.lean:5`): the Review-1 PoC simplification is
fail-open (documented as "simplified", censused as HB/BOUNDED, but
never before pinned as accepting-without-verifying). -/

theorem c2o_poc_vs_real_divergence :
    runsTrue 10 [ScriptInstr.push c2oW1, ScriptInstr.push c2oW2,
        ScriptInstr.checkSig] = true
      ∧ verifyImpl c2oW1 c2oW2 c2oW3 = false := by
  decide

/-! ## The fail-closed control: `mockFind` misses (SCS-B03) -/

/-- `Mock.lean:32`'s `mockFind` on the empty table = the `[]`-clause
(`mockFind_nil` :66) re-pinned at the CHECKER level, on the same
witness: a miss fails closed (pre-baked rows = the ratified trust
link). -/

theorem c2o_mock_miss_fail_closed :
    (mockChecker ([] : MockTable)).checkECDSASignature c2oW1 c2oW2 c2oW3
      SigVersion.base (default : ScriptExecutionData) = false := by
  rfl

/-- The two stand-ins SPLIT on the failure axis (S05
`s05_standins_split`): on the same witness, the mock agrees with the
real verifier (`false` = `false`) and ONLY the stub diverges (`true`). -/

theorem c2o_standins_split :
    stubChecker.checkECDSASignature c2oW1 c2oW2 c2oW3
        SigVersion.base (default : ScriptExecutionData) = true
      ∧ (mockChecker ([] : MockTable)).checkECDSASignature c2oW1 c2oW2 c2oW3
        SigVersion.base (default : ScriptExecutionData) = false
      ∧ verifyImpl c2oW1 c2oW2 c2oW3 = false := by
  decide

/-! ## The negative control (A21/G08-style) -/

/-- The fail-open stub still satisfies the frozen-seam law
(`stubChecker_deterministic`, `Interface.lean:171`, re-checked here):
a deterministic checker can be fail-open — the frozen-seam laws do
NOT discriminate the failure direction (the stub-blindness statement
at the checker level). -/

theorem c2o_stub_checker_deterministic (sig pk code : ByteArray) (v : SigVersion)
    (d₁ d₂ : ScriptExecutionData) :
    stubChecker.checkECDSASignature sig pk code v d₁
      = stubChecker.checkECDSASignature sig pk code v d₂ := by
  rfl

/-- Same for the table mock (`mockChecker_deterministic`,
`Mock.lean`): the mock's laws hold at every table — laws alone cannot
see the fail-axis. -/

theorem c2o_mock_checker_deterministic (table : MockTable)
    (sig pk code : ByteArray) (v : SigVersion)
    (d₁ d₂ : ScriptExecutionData) :
    (mockChecker table).checkECDSASignature sig pk code v d₁
      = (mockChecker table).checkECDSASignature sig pk code v d₂ := by
  rfl

/-! ## Axiom guard (S16-P9/G08 style, CENSUS2 anchors) -/

#print axioms c2o_stub_ecdsa_fails_open     -- no sorryAx
#print axioms c2o_stub_schnorr_fails_open   -- no sorryAx
#print axioms c2o_poc_stub_fails_open       -- no sorryAx
#print axioms c2o_stub_not_sound_witness    -- no sorryAx
#print axioms c2o_poc_vs_real_divergence    -- no sorryAx
#print axioms c2o_mock_miss_fail_closed     -- no sorryAx
#print axioms c2o_standins_split            -- no sorryAx
#print axioms c2o_stub_checker_deterministic -- no sorryAx (rfl)
#print axioms c2o_mock_checker_deterministic -- no sorryAx (rfl)

end Bitcoin.Proofs.Shortcuts.CENSUS2.FailOpenStub
