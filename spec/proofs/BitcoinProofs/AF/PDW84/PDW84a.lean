import Bitcoin.Interpreter.Defs

/-! # PDW84a — TOP-441 row face: `checkMultiSig` gate ladder

Route B, zero core writes. The CMS verdict ladder of
interpreter.cpp:1113-1145: tapscript ban, key-count bound `≤ 20`,
sig-count bound `≤ nKeys`, and the `nKeys+nSigs+3` arity that consumes
the historical off-by-one dummy. -/

namespace BitcoinProofs.AF.PDW84

open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Script.Parser

/-- **INV-049 (key bound)**: `nKeys` outside `[0,20]` ⇒ `pubKeyCount`,
after the tapscript ban and the depth-1 read. -/
@[rule "INV-049"]
theorem cms_pubKeyCount_row (ctx : Ctx) (st : State) (nkv : ScriptNum) (w : Nat)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hcond : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = true) :
    stepBody.checkMultiSig ctx w st = .error .pubKeyCount := by
  simp [stepBody.checkMultiSig, hsv, hne0, hd, hcond]

/-- **INV-049 (sig bound)**: `nSigs` outside `[0,nKeys]` ⇒ `sigCount`. -/
@[rule "INV-049"]
theorem cms_sigCount_row (ctx : Ctx) (st : State) (nkv nsv : ScriptNum) (w : Nat)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hcond : (nsv < 0 ∨ max (nkv : Int) 0 < nsv) = true) :
    stepBody.checkMultiSig ctx w st = .error .sigCount := by
  simp [stepBody.checkMultiSig, hsv, hne0, hd1, hrange, hop, hlen2, hd2, hcond]

/-- **INV-049 (off-by-one dummy arity)**: both counts in range but the
stack holds only `nKeys + nSigs + 2` items (all semantic arguments and
both counts) ⇒ `stackUnderflow`: the extra historical dummy is required
and consumed unconditionally. -/
@[rule "INV-049"]
theorem cms_arity_no_dummy_row (ctx : Ctx) (st : State) (nkv nsv : ScriptNum)
    (w : Nat)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hrange2 : (nsv < 0 ∨ max (nkv : Int) 0 < nsv) = false)
    (hcond : (st.stack.length < nkv.toNat + nsv.toNat + 3) = true) :
    stepBody.checkMultiSig ctx w st = .error .stackUnderflow := by
  simp [stepBody.checkMultiSig, hsv, hne0, hd1, hrange, hop, hlen2, hd2,
    hrange2, hcond]

end BitcoinProofs.AF.PDW84

#print axioms BitcoinProofs.AF.PDW84.cms_sigCount_row

/-- info: 'BitcoinProofs.AF.PDW84.cms_pubKeyCount_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cms_pubKeyCount_row

/-- info: 'BitcoinProofs.AF.PDW84.cms_sigCount_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cms_sigCount_row

/-- info: 'BitcoinProofs.AF.PDW84.cms_arity_no_dummy_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms BitcoinProofs.AF.PDW84.cms_arity_no_dummy_row
