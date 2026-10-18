import BitcoinProofs.Theorems.Ops.O09
import Bitcoin.Numeric.Interface

/-!
# PDW80A — TOP-421..423: CHECKMULTISIG order/limits + CScriptNum minimality

Route-B row faces over the interpreter. Zero core writes.
Rows: INV-049 (multisig semantics + off-by-one dummy), SCR-114
(nKeys∈[0,20], nSigs∈[0,nKeys], depth checks), SCR-050 (non-minimal
CScriptNum rejected under fRequireMinimal).

The CHECKMULTISIG facts are the O09 dispatch lemmas restated under the
row ids; SCR-050 is the decodeNum lift of the frozen
`Numeric.scriptNum_minimal_reject`.
-/

namespace BitcoinProofs.AF.PDW80

open Bitcoin.Interpreter Bitcoin.Numeric Bitcoin.Data
open BitcoinProofs.Theorems.Ops.O09

/-! ## INV-049 — nKeys ≤ 20, nSigs ≤ nKeys, dummy consumed unchecked -/

@[rule "INV-049"]
theorem inv049_pubkey_limit (ctx : Ctx) (st : State) (nkv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hcond : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = true) :
    stepBody.checkMultiSig ctx 0xae st = .error .pubKeyCount :=
  cms_pubKeyCount ctx st nkv hsv hne0 hd hcond

@[rule "INV-049"]
theorem inv049_sig_limit (ctx : Ctx) (st : State) (nkv nsv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hcond : (nsv < 0 ∨ max (nkv : Int) 0 < nsv) = true) :
    stepBody.checkMultiSig ctx 0xae st = .error .sigCount :=
  cms_sigCount ctx st nkv nsv hsv hne0 hd1 hrange hop hlen2 hd2 hcond

/-- The historical off-by-one: the dummy is a 5th, unchecked slot;
a nonzero dummy is consumed regardless of content (NULLDUMMY off). -/
@[rule "INV-049"]
theorem inv049_dummy_consumed_unchecked :
    stepBody ctx0 opCMS { st0 with stack := [enc 0, enc 0, serU8 7, serU8 9] } =
      .ok { st0 with opCount := 1, stack := vchTrue :: [serU8 9] } :=
  cms_0of0_concrete

/-- **INV-049 (general off-by-one dummy, not the 0-of-0 vector)**: for an
arbitrary context, arbitrary stack and *any* in-range key count
`nKeys ∈ [0, 20]`, a `0`-of-`nKeys` CHECKMULTISIG succeeds by consuming
exactly `nKeys + 3` stack items — the `nKeys` keys, the two counts and the
historical dummy at depth `nKeys + 2` — leaving `vchTrue` on top. The
dummy's content is never inspected (NULLDUMMY off), so the popped slot
really is an extra, semantically-unused element, not an argument. -/
@[rule "INV-049"]
theorem inv049_dummy_popped_general (ctx : Ctx) (st : State) (nkv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok 0)
    (hlen3 : (st.stack.length < nkv.toNat + 3) = false)
    (hnd : ctx.flags.nullDummy = false) :
    stepBody.checkMultiSig ctx 0xae st =
      .ok { st with opCount := st.opCount + nkv.toNat,
                    stack := vchTrue :: st.stack.drop (nkv.toNat + 3) } :=
  cms_ok_zero_sigs ctx st nkv hsv hd1 hrange hop hlen2 hd2 hlen3 (Or.inl hnd)

/-! ## SCR-114 — the count/limit ladder -/

@[rule "SCR-114"]
theorem scr114_pubkey_range (ctx : Ctx) (st : State) (nkv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hcond : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = true) :
    stepBody.checkMultiSig ctx 0xae st = .error .pubKeyCount :=
  cms_pubKeyCount ctx st nkv hsv hne0 hd hcond

@[rule "SCR-114"]
theorem scr114_sig_range (ctx : Ctx) (st : State) (nkv nsv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hcond : (nsv < 0 ∨ max (nkv : Int) 0 < nsv) = true) :
    stepBody.checkMultiSig ctx 0xae st = .error .sigCount :=
  cms_sigCount ctx st nkv nsv hsv hne0 hd1 hrange hop hlen2 hd2 hcond

/-- Depth: `nKeys + nSigs + 3` items are required — the dummy incl. -/
@[rule "SCR-114"]
theorem scr114_depth (ctx : Ctx) (st : State) (nkv nsv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hrange2 : (nsv < 0 ∨ max (nkv : Int) 0 < nsv) = false)
    (hcond : (st.stack.length < nkv.toNat + nsv.toNat + 3) = true) :
    stepBody.checkMultiSig ctx 0xae st = .error .stackUnderflow :=
  cms_underflow_no_dummy ctx st nkv nsv hsv hne0 hd1 hrange hop hlen2 hd2 hrange2 hcond

/-! ## SCR-050 — minimal CScriptNum under fRequireMinimal -/

/-- A non-minimal operand (trailing 0x00 with a clear previous high bit)
is rejected by `decodeNum` whenever `pol.minimalData` is set. -/
@[rule "SCR-050"]
theorem scr050_minimal_reject (pol : PolicyFlags) (b : ByteArray)
    (hm : pol.minimalData = true)
    (h : 1 < b.size ∧ (b.get! (b.size - 1)).toNat = 0
       ∧ (b.get! (b.size - 2)).toNat < 128) :
    Bitcoin.Interpreter.decodeNum pol b SCRIPT_NUM_DEFAULT_MAX_SIZE
      = .error .scriptNum := by
  unfold Bitcoin.Interpreter.decodeNum
  rw [hm, scriptNum_minimal_reject b h]

/-- **SCR-050 (full byte-level minimality rule)**: the `minimalOkBE` test
on the big-endian view is exactly Core's `script.h:252-268` condition —
either the vector is empty, or the top byte minus its sign bit is nonzero,
or (more than one byte and) the second-to-top byte's high bit is set.
This is the accept-side counterpart of `scr050_minimal_reject`: the
`0x…80 0x00`-style two-byte exception is admitted, one-byte `0x00`/`0x80`
and clear-high-bit tails are not. -/
theorem minimalOkBE_reverse_iff (b : ByteArray) :
    minimalOkBE (bytesOf b).reverse = true ↔
      b.size = 0 ∨ (b.get! (b.size - 1)).toNat % 128 ≠ 0 ∨
        (1 < b.size ∧ 128 ≤ (b.get! (b.size - 2)).toNat) := by
  cases hlen : b.size with
  | zero =>
    have hb : bytesOf b = [] := by
      apply List.eq_nil_of_length_eq_zero
      rw [bytesOf_length, hlen]
    rw [hb]
    simp [minimalOkBE]
  | succ n =>
    cases hrev' : (bytesOf b).reverse with
    | nil =>
      have h0 : (bytesOf b).reverse.length = 0 := by rw [hrev']; rfl
      rw [List.length_reverse, bytesOf_length, hlen] at h0
      omega
    | cons d t =>
      have hd : d = (b.get! (b.size - 1)).toNat := by
        have h := bytesOf_reverse_get0 b (by omega)
        simp only [hrev', List.getElem_cons_zero] at h
        exact h
      cases ht : t with
      | nil =>
        have hb1 : b.size = 1 := by
          have h1 : (d :: t).length = b.size := by
            rw [← hrev', List.length_reverse, bytesOf_length]
          rw [ht] at h1
          simp at h1
          omega
        have hn0 : n = 0 := by omega
        subst hn0
        simp only [minimalOkBE]
        by_cases htop : (b.get! (b.size - 1)).toNat % 128 = 0
        · simp [hd, hb1, htop]
        · simp [hd, hb1, htop]
      | cons e s =>
        have hgt : 1 < b.size := by
          have h1 : (d :: t).length = b.size := by
            rw [← hrev', List.length_reverse, bytesOf_length]
          rw [ht] at h1
          simp at h1
          omega
        have he : e = (b.get! (b.size - 2)).toNat := by
          have h := bytesOf_reverse_get1 b hgt
          simp only [hrev', ht, List.getElem_cons_succ, List.getElem_cons_zero] at h
          exact h
        have hnpos : 0 < n := by omega
        simp only [minimalOkBE]
        by_cases htop : (b.get! (b.size - 1)).toNat % 128 = 0
        · simp [hd, he, hgt, htop, hlen, hnpos]
        · simp [hd, he, htop, hlen, hnpos]

/-- **SCR-050 (full statement, both directions)**: under `fRequireMinimal`
a `CScriptNum` decode of an operand within the 4-byte bound succeeds
exactly when the bytes satisfy Core's minimal-encoding condition. This
covers the size-1 case, the second-byte-high-bit exception and the
width gate in one iff — not just the reject branch. -/
@[rule "SCR-050"]
theorem scr050_minimal_iff (pol : PolicyFlags) (b : ByteArray)
    (hm : pol.minimalData = true) :
    (∃ n, Bitcoin.Interpreter.decodeNum pol b SCRIPT_NUM_DEFAULT_MAX_SIZE = .ok n) ↔
      b.size ≤ SCRIPT_NUM_DEFAULT_MAX_SIZE ∧
        (b.size = 0 ∨ (b.get! (b.size - 1)).toNat % 128 ≠ 0 ∨
          (1 < b.size ∧ 128 ≤ (b.get! (b.size - 2)).toNat)) := by
  constructor
  · rintro ⟨n, h⟩
    -- decode ok ⇒ width bound and `minimalOkBE`
    have hbound : b.size ≤ SCRIPT_NUM_DEFAULT_MAX_SIZE ∧
        minimalOkBE (bytesOf b).reverse = true := by
      unfold Bitcoin.Interpreter.decodeNum at h
      cases hd : Bitcoin.Numeric.decodeScriptNum b pol.minimalData
          SCRIPT_NUM_DEFAULT_MAX_SIZE with
      | none => rw [hd] at h; simp at h
      | some m =>
        unfold Bitcoin.Numeric.decodeScriptNum at hd
        unfold decodeBE at hd
        by_cases hw : (bytesOf b).reverse.length > SCRIPT_NUM_DEFAULT_MAX_SIZE
        · rw [if_pos hw] at hd; simp at hd
        · rw [if_neg hw] at hd
          refine ⟨?_, ?_⟩
          · rw [← bytesOf_length, ← List.length_reverse]; omega
          · by_cases hc : minimalOkBE (bytesOf b).reverse = true
            · exact hc
            · rw [if_pos (show pol.minimalData = true ∧
                  ¬ minimalOkBE (bytesOf b).reverse = true from ⟨hm, hc⟩)] at hd
              simp at hd
    exact ⟨hbound.1, (minimalOkBE_reverse_iff b).mp hbound.2⟩
  · rintro ⟨hsz, hmin⟩
    refine ⟨setVchBE (bytesOf b).reverse, ?_⟩
    unfold Bitcoin.Interpreter.decodeNum Bitcoin.Numeric.decodeScriptNum
    rw [decodeBE_some (minimal := pol.minimalData)
      (maxSize := SCRIPT_NUM_DEFAULT_MAX_SIZE) (l := (bytesOf b).reverse)
      (by rw [List.length_reverse, bytesOf_length]; exact hsz)
      (Or.inr ((minimalOkBE_reverse_iff b).mpr hmin))]

/-! ## Axiom pins -/

/-- info: 'BitcoinProofs.AF.PDW80.inv049_pubkey_limit' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms inv049_pubkey_limit

/-- info: 'BitcoinProofs.AF.PDW80.inv049_sig_limit' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms inv049_sig_limit

/-- info: 'BitcoinProofs.AF.PDW80.inv049_dummy_consumed_unchecked' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms inv049_dummy_consumed_unchecked

/-- info: 'BitcoinProofs.AF.PDW80.scr114_pubkey_range' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms scr114_pubkey_range

/-- info: 'BitcoinProofs.AF.PDW80.scr114_sig_range' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms scr114_sig_range

/-- info: 'BitcoinProofs.AF.PDW80.scr114_depth' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms scr114_depth

/-- info: 'BitcoinProofs.AF.PDW80.scr050_minimal_reject' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms scr050_minimal_reject

/-- info: 'BitcoinProofs.AF.PDW80.inv049_dummy_popped_general' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms inv049_dummy_popped_general

/-- info: 'BitcoinProofs.AF.PDW80.minimalOkBE_reverse_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms minimalOkBE_reverse_iff

/-- info: 'BitcoinProofs.AF.PDW80.scr050_minimal_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms scr050_minimal_iff

end BitcoinProofs.AF.PDW80
