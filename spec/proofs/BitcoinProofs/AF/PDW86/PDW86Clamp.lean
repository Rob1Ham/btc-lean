import BitcoinProofs.AF.PDW79.PDW79b
import Bitcoin.Numeric.ScriptNum

/-! PDW86Clamp — SCR-086: `getint` clamping at the depth/count sites.

Core's `CScriptNum::getint()` clamps to `[INT32_MIN, INT32_MAX]`
(script.h:326-333).  A four-byte decode can never leave that range, so
the clamp is the identity on every depth/count operand read by
OP_PICK, OP_ROLL and OP_CHECKMULTISIG.  The consumer theorems below apply
that identity to the actual machine transitions.
-/

namespace BitcoinProofs.AF.PDW86Clamp
open Bitcoin.Interpreter Bitcoin.Numeric
open Bitcoin.Crypto.Seam (SigVersion)

/-- A big-endian digit list of width at most four has magnitude below
`256^3` once the sign byte is removed. -/
theorem magOfBE_lt_256_three (t : List Nat) (h : ∀ d ∈ t, d < 256)
    (hlen : t.length ≤ 3) : magOfBE t < 256 ^ 3 := by
  have h1 := magOfBE_lt t h
  have h2 : 256 ^ t.length ≤ 256 ^ 3 :=
    Nat.pow_le_pow_right (by omega) hlen
  omega

/-- A four-byte `set_vch` value lies in the signed 32-bit range. -/
theorem setVchBE_bounds_of_length_le_four (l : List Nat)
    (hdig : ∀ d ∈ l, d < 256) (hlen : l.length ≤ 4) :
    -2147483648 ≤ setVchBE l ∧ setVchBE l ≤ 2147483647 := by
  cases l with
  | nil => rw [setVchBE]; constructor <;> omega
  | cons d t =>
    have hd : d < 256 := hdig d (by simp)
    have ht : ∀ e ∈ t, e < 256 := fun e he => hdig e (by simp [he])
    have htlen : t.length ≤ 3 := by simpa using hlen
    have hmag : magOfBE t < 256 ^ 3 := magOfBE_lt_256_three t ht htlen
    have hbound : ∀ c : Nat, c ≤ 127 →
        c * 256 ^ t.length + magOfBE t ≤ 2147483647 := by
      intro c hc
      have hpow : 256 ^ t.length ≤ 256 ^ 3 :=
        Nat.pow_le_pow_right (by omega) htlen
      have hm : c * 256 ^ t.length ≤ 127 * 256 ^ 3 :=
        Nat.mul_le_mul hc hpow
      have hsum : c * 256 ^ t.length + magOfBE t ≤
          127 * 256 ^ 3 + (256 ^ 3 - 1) := by omega
      have hconst : 127 * 256 ^ 3 + (256 ^ 3 - 1) = 2147483647 := by decide
      exact Nat.le_trans hsum (Nat.le_of_eq hconst)
    rw [setVchBE]
    split
    · constructor
      · omega
      · exact Int.ofNat_le.mpr (hbound d (by omega))
    · have hge : 128 ≤ d := by omega
      have hd127 : d - 128 ≤ 127 := by omega
      have hb := hbound (d - 128) hd127
      constructor
      · have hle : (((d - 128) * 256 ^ t.length + magOfBE t : Nat) : Int) ≤ 2147483647 := by
          exact Int.ofNat_le.mpr hb
        omega
      · omega

/-- SCR-086 (numeric core): every operand decoded at the four-byte call
sites is already inside the int32 range, so `getIntClamped` is the
identity. -/
@[rule "SCR-086"]
theorem decodeNum_getIntClamped {pol : PolicyFlags} {b : ByteArray} {n : ScriptNum}
    (h : decodeNum pol b 4 = .ok n) :
    getIntClamped n = n := by
  unfold decodeNum at h
  cases hd : decodeScriptNum b pol.minimalData 4 with
  | none => simp [hd] at h
  | some n0 =>
    have hn : n0 = n := by simpa [hd] using h
    subst hn
    obtain ⟨hval, hlen, _⟩ :=
      Bitcoin.Numeric.decodeScriptNum_value b pol.minimalData 4 n0 hd
    rw [hval]
    have hdig : ∀ d ∈ (bytesOf b).reverse, d < 256 := by
      intro d hdmem
      exact bytesOf_lt b d (List.mem_reverse.mp hdmem)
    have hlen' : (bytesOf b).reverse.length ≤ 4 := by
      simpa [bytesOf_length] using hlen
    exact getIntClamped_id (setVchBE_bounds_of_length_le_four _ hdig hlen').1
      (setVchBE_bounds_of_length_le_four _ hdig hlen').2

/-- SCR-086 (OP_PICK depth read): the selected depth `n.toNat` is exactly
the clamped read `(getIntClamped n).toNat`. -/
@[rule "SCR-086"]
theorem pick_depth_read_clamped {pol : PolicyFlags} {b : ByteArray} {n : ScriptNum}
    (h : decodeNum pol b 4 = .ok n) :
    (getIntClamped n).toNat = n.toNat := by
  rw [decodeNum_getIntClamped h]

/-- SCR-086 (OP_ROLL depth read): the selected depth `n.toNat` is exactly
the clamped read `(getIntClamped n).toNat`. -/
@[rule "SCR-086"]
theorem roll_depth_read_clamped {pol : PolicyFlags} {b : ByteArray} {n : ScriptNum}
    (h : decodeNum pol b 4 = .ok n) :
    (getIntClamped n).toNat = n.toNat :=
  pick_depth_read_clamped h

/-- SCR-086 (OP_PICK consumer): an in-range OP_PICK selects the item at
the clamped depth; the exact result is the same transition as the model's
`n.toNat` read. -/
@[rule "SCR-086"]
theorem stepBody_pick_ok_clamped {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x79)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hnn : 0 ≤ n) (hbound : n.toNat < (st.stack.tail).length) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1, stack := st.stack.tail[(getIntClamped n).toNat]! :: st.stack.tail } := by
  rw [pick_depth_read_clamped hdec]
  exact BitcoinProofs.AF.PDW79.stepBody_pick_ok ha hw hsv hfe hb hstack hdec hnn hbound

/-- SCR-086 (OP_ROLL consumer): the erased/selected item is addressed by
the clamped depth. -/
@[rule "SCR-086"]
theorem stepBody_roll_ok_clamped {ctx : Ctx} {op : WireOp} {st : State}
    {o : Fin 256} {n : ScriptNum}
    (ha : op.ast = .op o) (hw : op.wire = 0x7a)
    (hsv : ctx.sv = .base) (hfe : st.vf.all id = true)
    (hb : ¬ (MAX_OPS_PER_SCRIPT < st.opCount + 1))
    (hstack : 1 < st.stack.length)
    (hdec : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok n)
    (hnn : 0 ≤ n) (hbound : n.toNat < (st.stack.tail).length) :
    stepBody ctx op st =
      .ok { st with opCount := st.opCount + 1, stack := st.stack.tail[(getIntClamped n).toNat]! :: (st.stack.tail.take (getIntClamped n).toNat ++ st.stack.tail.drop ((getIntClamped n).toNat + 1)) } := by
  rw [pick_depth_read_clamped hdec]
  exact BitcoinProofs.AF.PDW79.stepBody_roll_ok ha hw hsv hfe hb hstack hdec hnn hbound

/-- SCR-086 (CHECKMULTISIG key-count read): a successful key-count decode
is already in int32 range, so the clamped `nKeys` equals the model's
count. -/
@[rule "SCR-086"]
theorem checkMultiSig_key_count_clamped {pol : PolicyFlags} {b : ByteArray}
    {nkv : ScriptNum} (h : decodeNum pol b 4 = .ok nkv) :
    (getIntClamped nkv).toNat = nkv.toNat :=
  pick_depth_read_clamped h

/-- SCR-086 (CHECKMULTISIG signature-count read): the same clamp identity
for `nSigs`. -/
@[rule "SCR-086"]
theorem checkMultiSig_sig_count_clamped {pol : PolicyFlags} {b : ByteArray}
    {nsv : ScriptNum} (h : decodeNum pol b 4 = .ok nsv) :
    (getIntClamped nsv).toNat = nsv.toNat :=
  pick_depth_read_clamped h

/-- SCR-086 (CHECKMULTISIG budget read): the wholesale key-count charge
uses the same clamped count, so `opCount + getIntClamped nkv` equals the
model's `opCount + nkv`. -/
@[rule "SCR-086"]
theorem checkMultiSig_opCount_clamped {pol : PolicyFlags} {b : ByteArray}
    {nkv : ScriptNum} (h : decodeNum pol b 4 = .ok nkv) (base : Nat) :
    base + (getIntClamped nkv).toNat = base + nkv.toNat := by
  rw [checkMultiSig_key_count_clamped h]

end BitcoinProofs.AF.PDW86Clamp
