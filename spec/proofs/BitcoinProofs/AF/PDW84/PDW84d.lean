import Bitcoin.Interpreter.Defs

/-! # PDW84d — TOP-441 row face: dummy consumed unconditionally

Route B, zero core writes. The `nSigs = 0` success path of
`checkMultiSig` (interpreter.cpp:1212-1225): the cleanup pops exactly
`nKeys + 2` items, the historical dummy at depth `nKeys + 2` is consumed
whatever its contents (unless NULLDUMMY demands it empty), and the op
budget pays `nKeys` sigop units. -/

namespace BitcoinProofs.AF.PDW84

open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Script.Parser

/-- `cmsCleanup` on the success path pops exactly `i - 1` items. -/
theorem cmsCleanup_true_eq (pol : PolicyFlags) :
    ∀ (fuel i ikey2 : Nat) (st : Stack), i ≤ fuel → i - 1 ≤ st.length →
      cmsCleanup pol st true i ikey2 fuel = .ok (st.drop (i - 1)) := by
  intro fuel
  induction fuel with
  | zero =>
    intro i ikey2 st hfuel _
    have hi : i = 0 := by omega
    subst hi
    simp [cmsCleanup]
  | succ f ih =>
    intro i ikey2 st hfuel hlen
    rcases st with _ | ⟨a, tl⟩
    · have hle : i ≤ 1 := by
        have h0 : List.length ([] : List ByteArray) = 0 := rfl
        omega
      have hz : i - 1 = 0 := by omega
      simp [cmsCleanup, hle, hz]
    · rcases Nat.lt_or_ge i 2 with hlt | hge
      · have hle : i ≤ 1 := by omega
        have hz : i - 1 = 0 := by omega
        simp [cmsCleanup, hle, hz]
      · have hle : ¬(i ≤ 1) := by omega
        have hf' : i - 1 ≤ f := by omega
        have hlen1 : List.length (a :: tl) = tl.length + 1 := rfl
        have hlen' : (i - 1) - 1 ≤ tl.length := by rw [hlen1] at hlen; omega
        have hrec := ih (i - 1) (if 0 < ikey2 then ikey2 - 1 else ikey2) tl hf' hlen'
        have h2 : (i - 1) - 1 = i - 2 := by omega
        have h1 : i - 1 = (i - 2) + 1 := by omega
        have hk : (a :: tl).drop (i - 1) = tl.drop (i - 2) := by
          rw [h1, List.drop_succ_cons]
        simp [cmsCleanup, hle, hrec, h2, hk, List.tail_cons]

/-- **INV-049 (dummy consumed)**: with `nSigs = 0` the loop succeeds
without the checker; the cleanup pops `nKeys + 2` items and the separate
dummy pop removes the element at depth `nKeys + 2` *unchecked* unless
NULLDUMMY requires it empty. Net stack `vchTrue :: st.drop (nKeys+3)`,
opCount `st.opCount + nKeys`. -/
@[rule "INV-049"]
theorem cms_ok_zero_sigs_row (ctx : Ctx) (st : State) (nkv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok 0)
    (hlen3 : (st.stack.length < nkv.toNat + 3) = false)
    (hnd : ctx.flags.nullDummy = false ∨
      st.stack[nkv.toNat + 2]?.getD default = ByteArray.empty) :
    stepBody.checkMultiSig ctx 0xae st =
      .ok { st with opCount := st.opCount + nkv.toNat,
                    stack := vchTrue :: st.stack.drop (nkv.toNat + 3) } := by
  have hl3 : ¬(st.stack.length < nkv.toNat + 3) := by rw [hlen3]; simp
  have hne0 : st.stack ≠ [] := by
    intro h
    rw [h] at hl3
    have h0 : List.length ([] : List ByteArray) = 0 := rfl
    omega
  have hcond0 : ¬(max (nkv : Int) 0 < (0 : Int)) :=
    Int.not_lt_of_ge (Int.le_max_right (nkv : Int) 0)
  have hne4 : ¬(List.length st.stack - (nkv.toNat + 2) = 0) := by omega
  have hcl : cmsCleanup ctx.pol st.stack true (nkv.toNat + 3) (nkv.toNat + 2)
      (nkv.toNat + 3) = .ok (st.stack.drop (nkv.toNat + 2)) := by
    have h := cmsCleanup_true_eq ctx.pol (nkv.toNat + 3) (nkv.toNat + 3)
      (nkv.toNat + 2) st.stack (Nat.le_refl _) (by omega)
    rw [show nkv.toNat + 3 - 1 = nkv.toNat + 2 from by omega] at h
    exact h
  have hdrop : List.drop (nkv.toNat + 2 + 1) st.stack
      = List.drop (nkv.toNat + 3) st.stack := by
    rw [show nkv.toNat + 2 + 1 = nkv.toNat + 3 from by omega]
  rcases hnd with hnd | hnd
  · simp [stepBody.checkMultiSig, hsv, hd1, hrange, hop, hlen2, hd2, hlen3,
      cmsLoop, hcl, hne0, hcond0, hne4, hnd, pushBoolV, vchTrue, List.tail_drop,
      hdrop]
  · simp [stepBody.checkMultiSig, hsv, hd1, hrange, hop, hlen2, hd2, hlen3,
      cmsLoop, hcl, hne0, hcond0, hne4, hnd, pushBoolV, vchTrue, List.tail_drop,
      hdrop]

end BitcoinProofs.AF.PDW84

/-- info: 'BitcoinProofs.AF.PDW84.cms_ok_zero_sigs_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cms_ok_zero_sigs_row
