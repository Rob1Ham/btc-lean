import Bitcoin.Invariants.RC07

/-! # PDW58E.lean — TOP-315: INV-073 BIP341 leaf commitment
(PDW58, RC29). Row face for
`Bitcoin.Invariants.RC07.tapleafCommitment`
(interpreter.cpp:VerifyTaprootCommitment:1913-1926 @ cce32b168).
Route B: zero core writes; the EC `CheckTapTweak` step stays in the X03
seam lane (TPR rows) and is not part of this hash-lane row. -/

namespace BitcoinProofs.AF.PDW58

open Bitcoin.Invariants.RC07

/-- INV-073 (control shape constants, Core-faithful): base 33, node 32,
max 33 + 32*128 = 4129 (`interpreter.h:244-247`). -/
@[rule "INV-073"]
theorem control_shape_pins :
    controlBaseSize = 33 ∧ controlNodeSize = 32 ∧ controlMaxSize = 4129 := by
  decide

/-- INV-073 (malformed control, short arm): a control block under 33 bytes
is rejected (`none`), never committed. -/
@[rule "INV-073"]
theorem tapleafCommitment_short (control script : ByteArray)
    (h : control.size < 33) : tapleafCommitment control script = none := by
  unfold tapleafCommitment
  exact taprootMerkleRoot_short control _ h

/-- INV-073 (malformed control, residue arm): a path length that is not a
multiple of 32 after the 33-byte prefix is rejected. -/
@[rule "INV-073"]
theorem tapleafCommitment_badResidue (control script : ByteArray)
    (h1 : 33 ≤ control.size) (h2 : control.size ≤ 4129)
    (h3 : (control.size - 33) % 32 ≠ 0) :
    tapleafCommitment control script = none := by
  unfold tapleafCommitment
  exact taprootMerkleRoot_badResidue control _ h1 h2 h3

/-- INV-073 (single-leaf taptree): a 33-byte control commits exactly to the
tapleaf hash of the spent script, at the masked leaf version. -/
@[rule "INV-073"]
theorem tapleafCommitment_single (control script : ByteArray)
    (h33 : control.size = 33) :
    tapleafCommitment control script
      = some (Bitcoin.Interpreter.tapLeafHash (control[0]! &&& 0xfe) script) :=
  tapleafCommitment_singleLeaf control script h33

/-- INV-073 (one internal node): a 65-byte control climbs exactly one
lexicographically-ordered TapBranch hash against `control[33..65)`. -/
@[rule "INV-073"]
theorem tapleafCommitment_oneNode (control script : ByteArray)
    (h65 : control.size = 65) :
    tapleafCommitment control script
      = some (tapbranchHash
          (Bitcoin.Interpreter.tapLeafHash (control[0]! &&& 0xfe) script)
          (control.extract 33 65)) := by
  unfold tapleafCommitment
  exact taprootMerkleRoot_single control _ h65

end BitcoinProofs.AF.PDW58
