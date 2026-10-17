import Bitcoin.Crypto.Ecdsa.Der
import Bitcoin.Invariants.RC07
import Bitcoin.Script.Tapscript.LeafVersion

/-! # PDW42B.lean — TOP-209/210 (PDW42, 2026-10-17), claim b86bc7e

Status-debt band, route B: core carries the defs + sorry-free laws; the
DB rows were never flipped. Zero core writes.

* **SGN-111** `isDERSignature` — BIP66 strict DER validator
  (interpreter.cpp:117-179): total size window 9..73 (sighash byte
  included) and the short-input reject.
* **INV-074** `isTapscriptLeaf` — BIP342 §2 leaf-version mask:
  `control[0] &&& 0xfe`, tapscript iff 0xc0; other masked versions are
  the upgradable (consensus-valid) path.
-/

namespace BitcoinProofs.AF.PDW42B

open Bitcoin.Crypto.Ecdsa.Der (isDERSignature blen byteAt)
open Bitcoin.Invariants.RC07 (isTapscriptLeaf tapscriptLeafVersion)

/-- SGN-111: an accepted strict-DER signature has total size in [9, 73]
(the BIP66 window, trailing sighash byte included). -/
@[rule "SGN-111"]
theorem isDERSignature_len {b : ByteArray} (h : isDERSignature b = true) :
    9 ≤ blen b ∧ blen b ≤ 73 := by
  by_cases hlt : blen b < 9
  · have hc : (blen b < 9 || blen b > 73) = true := by simp [hlt]
    simp only [Bitcoin.Crypto.Ecdsa.Der.isDERSignature, hc, ite_true] at h
    exact absurd h (by simp)
  · by_cases hgt : blen b > 73
    · have hc : (blen b < 9 || blen b > 73) = true := by simp [hgt]
      simp only [Bitcoin.Crypto.Ecdsa.Der.isDERSignature, hc, ite_true] at h
      exact absurd h (by simp)
    · omega

/-- SGN-111: the short-input reject — anything below the 9-byte floor
(empty included) fails the strict DER gate. -/
@[rule "SGN-111"]
theorem isDERSignature_short_face (b : ByteArray) (h : blen b < 9) :
    isDERSignature b = false :=
  Bitcoin.Crypto.Ecdsa.Der.isDERSignature_short b h

/-! ### SGN-111 — full BIP66 structural characterization

The definitional gate is a tower of byte tests. The theorem below states
the same predicate as a single structural conjunction (minimal integer
encodings, correct tags and lengths, total-size window), so the row's
"strict DER" claim is a statement about the signature bytes rather than
about the particular `if`-tower used to implement it. -/

@[simp] theorem byteAt_lt_256 (b : ByteArray) (i : Nat) : byteAt b i < 256 := by
  unfold byteAt
  exact UInt8.toNat_lt _

/-- For a byte value, `x / 128` is the high bit. -/
theorem div128_eq (x : Nat) (hx : x < 256) : x / 128 = if x < 128 then 0 else 1 := by
  split
  · exact Nat.div_eq_of_lt ‹x < 128›
  · exact Nat.div_eq_of_lt_le (by omega) (by omega)

/-- `x / 128 % 2 = 0` is "the high bit of `x` is clear". -/
theorem div128mod2_eq_zero (x : Nat) (hx : x < 256) : x / 128 % 2 = 0 ↔ x < 128 := by
  rw [div128_eq x hx]; by_cases h : x < 128 <;> simp [h] <;> omega

/-- `x / 128 % 2 ≠ 1` is "the high bit of `x` is clear" (the test used by
the excessive-padding check). -/
theorem div128mod2_ne_one (x : Nat) (hx : x < 256) : x / 128 % 2 ≠ 1 ↔ x < 128 := by
  rw [div128_eq x hx]; by_cases h : x < 128 <;> simp [h] <;> omega

/-- The BIP66 structural conditions (`IsValidSignatureEncoding`,
interpreter.cpp:117-179), stated on the bytes: total size 9..73, sequence
tag and length, the two INTEGER tags with nonzero lengths, non-negative
high bits, minimal (no superfluous `0x00`) encodings, and declared lengths
that exactly tile the input. -/
def DERShape (b : ByteArray) : Prop :=
  9 ≤ blen b ∧ blen b ≤ 73 ∧
  byteAt b 0 = 0x30 ∧
  byteAt b 1 = blen b - 3 ∧
  5 + byteAt b 3 < blen b ∧
  byteAt b 3 + byteAt b (5 + byteAt b 3) + 7 = blen b ∧
  byteAt b 2 = 0x02 ∧
  byteAt b 3 ≠ 0 ∧
  byteAt b 4 < 128 ∧
  ¬ (byteAt b 3 > 1 ∧ byteAt b 4 = 0 ∧ byteAt b 5 < 128) ∧
  byteAt b (byteAt b 3 + 4) = 0x02 ∧
  byteAt b (5 + byteAt b 3) ≠ 0 ∧
  byteAt b (byteAt b 3 + 6) < 128 ∧
  ¬ (byteAt b (5 + byteAt b 3) > 1 ∧ byteAt b (byteAt b 3 + 6) = 0 ∧
      byteAt b (byteAt b 3 + 7) < 128)

/-- Auxiliary form of `DERShape` with the literal bit tests of the
implementation; this is what the `if`-tower unfolds to. -/
private def DERShapeBits (b : ByteArray) : Prop :=
  9 ≤ blen b ∧ blen b ≤ 73 ∧
  byteAt b 0 = 0x30 ∧
  byteAt b 1 = blen b - 3 ∧
  5 + byteAt b 3 < blen b ∧
  byteAt b 3 + byteAt b (5 + byteAt b 3) + 7 = blen b ∧
  byteAt b 2 = 0x02 ∧
  byteAt b 3 ≠ 0 ∧
  byteAt b 4 / 128 % 2 = 0 ∧
  ¬ (byteAt b 3 > 1 ∧ byteAt b 4 = 0 ∧ byteAt b 5 / 128 % 2 ≠ 1) ∧
  byteAt b (byteAt b 3 + 4) = 0x02 ∧
  byteAt b (5 + byteAt b 3) ≠ 0 ∧
  byteAt b (byteAt b 3 + 6) / 128 % 2 = 0 ∧
  ¬ (byteAt b (5 + byteAt b 3) > 1 ∧ byteAt b (byteAt b 3 + 6) = 0 ∧
      byteAt b (byteAt b 3 + 7) / 128 % 2 ≠ 1)

set_option maxHeartbeats 1000000 in
private theorem isDERSignature_iff_bits (b : ByteArray) :
    isDERSignature b = true ↔ DERShapeBits b := by
  unfold isDERSignature DERShapeBits
  constructor
  · intro h
    repeat' (first | split at h | simp_all | omega)
  · intro h
    repeat' (first | split | simp_all | omega)

private theorem bits_iff_shape (b : ByteArray) :
    DERShapeBits b ↔ DERShape b := by
  unfold DERShapeBits DERShape
  simp only [div128mod2_eq_zero, div128mod2_ne_one, byteAt_lt_256]

/-- **SGN-111** (interpreter.cpp:117-179, BIP66): `isDERSignature` accepts
`b` exactly when `b` is a strict-DER signature: size window `[9, 73]`
(sighash byte included), `0x30 len`, two `0x02` integers whose lengths
tile the buffer, nonzero lengths, no negative integers, and minimal
encodings (a `0x00` pad only where the following byte has its high bit
set). This is the full precondition, not merely the length window pinned
by `isDERSignature_len`. -/
@[rule "SGN-111"]
theorem isDERSignature_spec (b : ByteArray) :
    isDERSignature b = true ↔ DERShape b :=
  (isDERSignature_iff_bits b).trans (bits_iff_shape b)

/-- INV-074: definitional characterization of the tapscript gate. -/
@[rule "INV-074"]
theorem isTapscriptLeaf_face (control : ByteArray) :
    isTapscriptLeaf control =
      (match tapscriptLeafVersion control with
       | some 0xc0 => true
       | _ => false) :=
  Bitcoin.Invariants.RC07.isTapscriptLeaf_def control

/-- INV-074: the parity bit is stripped — control 0xc1 is leaf version 0xc0. -/
@[rule "INV-074"]
theorem leafVersion_parity_face :
    tapscriptLeafVersion (ByteArray.mk #[0xc1] ++ ByteArray.mk (Array.replicate 32 0))
      = some 0xc0 :=
  Bitcoin.Invariants.RC07.leafVersion_parity_stripped

/-- INV-074: an unknown masked version (0xbe) is not tapscript — it takes
the upgradable path, which is consensus-valid. -/
@[rule "INV-074"]
theorem leafVersion_unknown_face :
    isTapscriptLeaf (ByteArray.mk #[0xbe] ++ ByteArray.mk (Array.replicate 32 0))
      = false :=
  Bitcoin.Invariants.RC07.unknownLeafVersion_not_tapscript

/-- INV-074: a control block shorter than 33 bytes carries no leaf version. -/
@[rule "INV-074"]
theorem leafVersion_short_face (c : ByteArray) (h : c.size < 33) :
    tapscriptLeafVersion c = none :=
  Bitcoin.Invariants.RC07.leafVersion_short c h

/-- INV-074 (interpreter.cpp:1988-1994): the 0xc0 leaf version dispatches
the script path into `executeWitnessScript` at `SigVersion.tapscript`,
seeding the validation weight from the full witness. This is the
execution-side meaning of the leaf-version test, not just its definition. -/
@[rule "INV-074"]
theorem tapscriptLeafDispatch_c0 (fuel : Nat) (items : Bitcoin.Data.WitnessStack)
    (control script : ByteArray) (witness : Bitcoin.Data.WitnessStack)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (chk : Bitcoin.Interpreter.ScriptChecker)
    (hleaf : Bitcoin.Script.Tapscript.isTapscriptLeaf control = true) :
    Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch fuel items control
        script witness flags pol chk =
      Bitcoin.Interpreter.executeWitnessScript fuel items
        (Bitcoin.Interpreter.witnessSerSize witness) script flags pol chk
        Bitcoin.Crypto.Seam.SigVersion.tapscript :=
  Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_tapscript
    fuel items control script witness flags pol chk hleaf

/-- INV-074 (interpreter.cpp:1995-1998, policy): an unknown (non-0xc0)
leaf version with `DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` set fails with
the named discouragement error — the "unknown versions discouraged"
half of the row. -/
@[rule "INV-074"]
theorem tapscriptLeafDispatch_unknown_discouraged (fuel : Nat)
    (items : Bitcoin.Data.WitnessStack) (control script : ByteArray)
    (witness : Bitcoin.Data.WitnessStack)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (chk : Bitcoin.Interpreter.ScriptChecker)
    (hnot : Bitcoin.Script.Tapscript.isTapscriptLeaf control = false)
    (hd : pol.discourageUpgradableTaprootVersion = true) :
    Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch fuel items control
        script witness flags pol chk =
      Bitcoin.Interpreter.VerifyOutcome.fail
        Bitcoin.Interpreter.ExecError.discourageUpgradableTaprootVersion :=
  Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_upgradable_discourage
    fuel items control script witness flags pol chk hnot hd

/-- INV-074 (interpreter.cpp:1998, consensus): without the policy bit an
unknown leaf version follows the upgradable path and succeeds. -/
@[rule "INV-074"]
theorem tapscriptLeafDispatch_unknown_ok (fuel : Nat)
    (items : Bitcoin.Data.WitnessStack) (control script : ByteArray)
    (witness : Bitcoin.Data.WitnessStack)
    (flags : Bitcoin.Activation.ScriptFlags) (pol : Bitcoin.Interpreter.PolicyFlags)
    (chk : Bitcoin.Interpreter.ScriptChecker)
    (hnot : Bitcoin.Script.Tapscript.isTapscriptLeaf control = false)
    (hnd : pol.discourageUpgradableTaprootVersion = false) :
    Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch fuel items control
        script witness flags pol chk = Bitcoin.Interpreter.VerifyOutcome.ok :=
  Bitcoin.Script.Tapscript.verifyTaprootLeafDispatch_upgradable_ok
    fuel items control script witness flags pol chk hnot hnd

end BitcoinProofs.AF.PDW42B

/-- info: 'BitcoinProofs.AF.PDW42B.isDERSignature_len' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42B.isDERSignature_len
/-- info: 'BitcoinProofs.AF.PDW42B.isDERSignature_short_face' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42B.isDERSignature_short_face
/-- info: 'BitcoinProofs.AF.PDW42B.isTapscriptLeaf_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42B.isTapscriptLeaf_face
/-- info: 'BitcoinProofs.AF.PDW42B.leafVersion_parity_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42B.leafVersion_parity_face
/-- info: 'BitcoinProofs.AF.PDW42B.leafVersion_unknown_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42B.leafVersion_unknown_face
/-- info: 'BitcoinProofs.AF.PDW42B.leafVersion_short_face' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42B.leafVersion_short_face
/-- info: 'BitcoinProofs.AF.PDW42B.isDERSignature_spec' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42B.isDERSignature_spec
/-- info: 'BitcoinProofs.AF.PDW42B.tapscriptLeafDispatch_c0' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42B.tapscriptLeafDispatch_c0
/-- info: 'BitcoinProofs.AF.PDW42B.tapscriptLeafDispatch_unknown_discouraged' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42B.tapscriptLeafDispatch_unknown_discouraged
/-- info: 'BitcoinProofs.AF.PDW42B.tapscriptLeafDispatch_unknown_ok' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW42B.tapscriptLeafDispatch_unknown_ok
