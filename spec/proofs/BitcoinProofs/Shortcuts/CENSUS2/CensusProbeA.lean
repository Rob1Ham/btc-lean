import Bitcoin.Crypto.Ecdsa.Verify
import Bitcoin.Crypto.Seam.Entry

/-!
# Bitcoin.Proofs.Shortcuts.CENSUS2.CensusProbeA — probe A (RC4, CENSUS2)

Re-landing S05's phantom lane (F-C2-001: `Shortcuts/S05/` never landed —
S05.md §2.1/2.2 is the theorem set, §6 build-evidence was an unfilled
placeholder). This probe A is the direct-lean elaboration probe for the
CENSUS2 fail-axis files: it pins the three proof shapes everything else
rides (parseDerLax bad-head elimination `if_pos`-style on the Prop
disjunct; push-built literal `decide` witnesses; the `txCheckerOf` none-
elimination bridge) before they are used en masse in
`FailClosedSeam.lean` / `FailOpenStub.lean`.

Nothing here reduces `verifyImpl`'s EC math (reduction discipline), the
SHA256 layer, or any tagged rule row. No `@[rule]` (nothing is a
rules.yaml row). New file, CENSUS2-owned, outside the `BitcoinProofs`
root closure (A18 pattern).
-/

namespace Bitcoin.Proofs.Shortcuts.CENSUS2.CensusProbeA

open Bitcoin.Crypto.Seam Bitcoin.Crypto.Seam.Entry
  Bitcoin.Crypto.Ecdsa.Der Bitcoin.Crypto.Ecdsa.Verify

/-! ## A1 — parseDerLax bad-head rejects (SCS-B03 real-verifier edge) -/

/-- A non-`0x30`-headed signature fails the lax parse at the FIRST
check (`Der.lean:146`: `blen b < 1 || byteAt b 0 != 0x30`): no EC math
is ever reached. Hypothesis in the Bool world (`bne … = true`), matching
the elaborated condition `((decide (blen b < 1)) || (byteAt b 0 != 0x30)) = true`. -/

theorem c2_parseDerLax_bad_head (b : ByteArray) (h0 : (byteAt b 0 != 0x30) = true) :
    parseDerLax b = none := by
  unfold parseDerLax
  simp only [h0, Bool.or_true, ite_true]

/-- The real lax-ECDSA verifier rejects a bad-headed signature before
any EC math (Core: `CPubKey::Verify` → `ecdsa_signature_parse_der_lax`
→ parse fail). -/

theorem c2_verifyImpl_bad_head (b pk msg : ByteArray) (h0 : (byteAt b 0 != 0x30) = true) :
    verifyImpl b pk msg = false := by
  unfold verifyImpl
  rw [c2_parseDerLax_bad_head b h0]

/-! ## A2 — push-built literal witness (decide) -/

/-- The bad-head witness `#[0x31]` (nonempty, non-`0x30` head):
push-built ByteArrays (`.push`/`.data.size`/`.data.getD` only — the
F-E07-003 decide-clean representation) fail the real verifier. -/

theorem c2_witness_badhead_rejects :
    verifyImpl (ByteArray.empty.push 0x31) (ByteArray.empty.push 0x02)
      (ByteArray.empty.push 0x00) = false := by
  decide

/-! ## A3 — one none-site elimination (the `txCheckerOf` bridge) -/

/-- At every none-wired production site, the Schnorr arm reduces to
`schnorrVerdict verifySchnorr (fun _ _ _ => none) sig pk v d`, whose
sighash-match arm is `none`-fail-closed definitionally. Proof-shape
probe for `FailClosedSeam.lean`'s three-site elimination. -/

theorem c2_schnorr_verdict_none_fail_closed
    (verifySchnorr : ByteArray → ByteArray → ByteArray → Bool)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    schnorrVerdict verifySchnorr (fun _ _ _ => none) sig pk v d = false := by
  unfold schnorrVerdict
  split
  · split
    · cases hs : schnorrHashtype sig with
      | none => rfl
      | some p =>
        cases p with
        | mk body ht => rfl
    · rfl
  · rfl

/-! ## Axiom guard (S16-P9/G08 style, CENSUS2 anchors) -/

#print axioms c2_parseDerLax_bad_head   -- expect [propext]; no sorryAx
#print axioms c2_verifyImpl_bad_head    -- expect [propext]; no sorryAx
#print axioms c2_witness_badhead_rejects -- expect [propext, Decidable]; no sorryAx
#print axioms c2_schnorr_verdict_none_fail_closed -- expect [propext]; no sorryAx

end Bitcoin.Proofs.Shortcuts.CENSUS2.CensusProbeA
