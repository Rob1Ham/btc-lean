import Bitcoin.Crypto.Taproot.Program

/-! # PDW41/TPR010.lean — TPR-010 row face (leaf-version extraction)

Claim v2 `d87a0cb`. Route B, zero core writes.

TPR-010: `v = control[0] & 0xfe` (interpreter.cpp:1983;
interpreter.h:242 TAPROOT_LEAF_MASK). Row faces: the mask pin, the
evenness law (bit 0 belongs to the output-key parity, not the version),
and the mask bound (a leaf version is a 7-bit value). -/

namespace BitcoinProofs.AF.PDW41

open Bitcoin.Crypto.Taproot.Program

/-- TPR-010 (row face): the extracted version is the control byte with
the parity bit cleared. -/
@[rule "TPR-010"]
theorem leafVersionOf_row (control : ByteArray) :
    leafVersionOf control = ((control.get! 0).toNat &&& 0xfe) := rfl

/-- TPR-010 (evenness): the masked value is always even, so it can never
be mistaken for the control-block parity bit. -/
theorem leafVersionOf_even_row (control : ByteArray) :
    leafVersionOf control % 2 = 0 :=
  Bitcoin.Crypto.Taproot.Program.leafVersionOf_even control

/-- TPR-010 (7-bit bound): a leaf version is ≤ 0xfe (the top bit is
masked off along with bit 0). -/
theorem leafVersionOf_le (control : ByteArray) : leafVersionOf control ≤ 0xfe := by
  unfold leafVersionOf
  exact Nat.and_le_right

/-- TPR-010 (tapscript lane): the 0xc0 leaf version is itself even, so
`control[0] & 0xfe = 0xc0` is the reachable TAPSCRIPT dispatch byte. -/
theorem tapscriptLeaf_even_row : TAPROOT_LEAF_TAPSCRIPT &&& 1 = 0 :=
  Bitcoin.Crypto.Taproot.Program.tapscriptLeaf_even

end BitcoinProofs.AF.PDW41
