import Bitcoin.Interpreter.Rules

/-! # PDW18 — INV-051 (route B: tag rides MY theorem, zero core writes)

BIP146 NULLFAIL flag gate in the `CleanupScriptCode` key-scan
`Bitcoin.Interpreter.cmsCleanup` (interpreter.cpp:351-352/1196-1198
@cce32b168): with a failed signature, `SCRIPT_VERIFY_NULLFAIL` set,
`ikey2 = 0` and a non-empty signature, the scan returns
`SIG_NULLFAIL`; with the flag off it can never do so. The core def and
its two tag sites (Defs.lean:667/685) stay untouched. -/

namespace BitcoinProofs.AF.PDW18

open Bitcoin.Interpreter

@[rule "INV-051"]
theorem cmsCleanup_nullFail_fires (pol : PolicyFlags) (st : Stack)
    (fSuccess : Bool) (i ikey2 fuel : Nat)
    (hi : 1 < i) (hf : 1 ≤ fuel) (hsucc : fSuccess = false)
    (hnf : pol.nullFail = true) (hk : ikey2 = 0) (hs : st[0]!.size ≠ 0) :
    cmsCleanup pol st fSuccess i ikey2 fuel = .error .sigNullFail := by
  obtain ⟨f, rfl⟩ : ∃ f, fuel = f + 1 := ⟨fuel - 1, by omega⟩
  have hne : st[0]?.getD default ≠ ByteArray.empty := by
    intro h; exact hs (by simpa using h)
  simp [cmsCleanup, show ¬ i ≤ 1 by omega, hsucc, hnf, hk, hne]

theorem cmsCleanup_nullFail_off (pol : PolicyFlags) (hnf : pol.nullFail = false)
    (fuel : Nat) (st : Stack) (fSuccess : Bool) (i ikey2 : Nat) :
    cmsCleanup pol st fSuccess i ikey2 fuel ≠ .error .sigNullFail := by
  induction fuel generalizing i ikey2 st with
  | zero => intro h; simp [cmsCleanup] at h
  | succ f ih =>
    intro h
    by_cases hi : i ≤ 1
    · simp [cmsCleanup, hi] at h
    · rw [cmsCleanup] at h
      rw [if_neg hi] at h
      have hc : ¬ (!fSuccess ∧ pol.nullFail ∧ ikey2 = 0 ∧ st[0]!.size ≠ 0) := by
        rw [hnf]; simp
      rw [if_neg hc] at h
      exact ih st.tail (i - 1) (if 0 < ikey2 then ikey2 - 1 else ikey2) h

theorem cmsCleanup_boundary_i (pol : PolicyFlags) (st : Stack)
    (fSuccess : Bool) (i ikey2 fuel : Nat) (hi : i ≤ 1) :
    cmsCleanup pol st fSuccess i ikey2 fuel = .ok st := by
  rw [Bitcoin.Interpreter.cmsCleanup.eq_def, if_pos hi]

theorem cmsCleanup_boundary_fuel (pol : PolicyFlags) (st : Stack)
    (fSuccess : Bool) (i ikey2 : Nat) (hi : ¬ i ≤ 1) :
    cmsCleanup pol st fSuccess i ikey2 0 = .ok st := by
  rw [Bitcoin.Interpreter.cmsCleanup.eq_def, if_neg hi]

end BitcoinProofs.AF.PDW18
