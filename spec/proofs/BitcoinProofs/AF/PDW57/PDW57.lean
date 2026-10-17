import Bitcoin.Interpreter.Defs

/-! # PDW57 — CHECKMULTISIG gate taxonomy + P2SH/P2A shape (TOP-306..310)

Row-face theorems for {SCR-026, SCR-027, SCR-028, SCR-054, SCR-055}.
`stepBody.checkMultiSig` (Defs.lean:1042, interpreter.cpp:1113-1225) owns
the key-count / sig-count / op-budget gates; `isPayToScriptHash` (:483)
and `isPayToAnchor` (:506) are the bare-script shape predicates.
Route B: tags on my theorems, zero core writes. -/

namespace BitcoinProofs.AF.PDW57

open Bitcoin.Interpreter

/-- SCR-026: the CMS key-count must lie in `[0, 20]`, else PUBKEY_COUNT. -/
@[rule "SCR-026"]
theorem checkMultiSig_pubKeyCount (ctx : Ctx) (w : Nat) (st : State)
    (hsv : ctx.sv ≠ .tapscript) (hne : ¬ st.stack.length < 1)
    {nkv : Bitcoin.Numeric.ScriptNum}
    (hnk : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hr : nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) :
    stepBody.checkMultiSig ctx w st = .error .pubKeyCount := by
  unfold stepBody.checkMultiSig
  rw [ite_eq_right hsv]
  simp [hne, hnk, hr]

/-- SCR-027: the CMS sig-count must satisfy `0 ≤ nSigs ≤ nKeys`, else SIG_COUNT. -/
@[rule "SCR-027"]
theorem checkMultiSig_sigCount (ctx : Ctx) (w : Nat) (st : State)
    (hsv : ctx.sv ≠ .tapscript) (hne : ¬ st.stack.length < 1)
    {nkv : Bitcoin.Numeric.ScriptNum}
    (hnk : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hkr : ¬ (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv))
    (hop : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat))
    (hlen : ¬ st.stack.length < nkv.toNat + 2)
    {nsv : Bitcoin.Numeric.ScriptNum}
    (hns : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hsr : nsv < 0 ∨ max nkv 0 < nsv) :
    stepBody.checkMultiSig ctx w st = .error .sigCount := by
  unfold stepBody.checkMultiSig
  rw [ite_eq_right hsv]
  simp [hne, hnk, hkr, hop, hlen, hns, hsr]

/-- SCR-028: the CMS key count is charged to `nOpCount`; over 201 fails. -/
@[rule "SCR-028"]
theorem checkMultiSig_opCount (ctx : Ctx) (w : Nat) (st : State)
    (hsv : ctx.sv ≠ .tapscript) (hne : ¬ st.stack.length < 1)
    {nkv : Bitcoin.Numeric.ScriptNum}
    (hnk : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hkr : ¬ (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv))
    (hr : MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) :
    stepBody.checkMultiSig ctx w st = .error .opCount := by
  unfold stepBody.checkMultiSig
  rw [ite_eq_right hsv]
  simp [hne, hnk, hkr, hr]

/-- SCR-054: exact P2SH template: 23 bytes, `OP_HASH160 <20> … OP_EQUAL`. -/
@[rule "SCR-054"]
theorem isPayToScriptHash_iff (b : ByteArray) :
    isPayToScriptHash b = true ↔
      b.size = 23 ∧ (b.get! 0).toNat = 0xa9 ∧ (b.get! 1).toNat = 0x14 ∧
        (b.get! 22).toNat = 0x87 := by
  simp [isPayToScriptHash]

/-- SCR-055: BIP345 P2A template: witness v1 with program `0x4e73`. -/
@[rule "SCR-055"]
theorem isPayToAnchor_iff (v : Nat) (p : ByteArray) :
    isPayToAnchor v p = true ↔
      v = 1 ∧ p.size = 2 ∧ (p.get! 0).toNat = 0x4e ∧ (p.get! 1).toNat = 0x73 := by
  simp [isPayToAnchor]

end BitcoinProofs.AF.PDW57

#print axioms BitcoinProofs.AF.PDW57.checkMultiSig_pubKeyCount
#print axioms BitcoinProofs.AF.PDW57.checkMultiSig_sigCount
#print axioms BitcoinProofs.AF.PDW57.checkMultiSig_opCount
#print axioms BitcoinProofs.AF.PDW57.isPayToScriptHash_iff
#print axioms BitcoinProofs.AF.PDW57.isPayToAnchor_iff
