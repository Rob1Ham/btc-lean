import BitcoinProofs.EcdsaDeep.SchnorrEquation

/-! # PDW95f — TPR-052 row face: BIP340 verification equation.

The crown theorem is `EcdsaDeep.SchnorrEquation.verifyImpl_iff`; this
file attaches the row id and restates soundness and the `R = s·G − e·P`
form. No statement is weakened: the equation is the native BIP340
verification predicate (`R.x = r`, even `y(R)`, `e` reduced mod `n`). -/

namespace BitcoinProofs.AF.PDW95
open BitcoinProofs.EcdsaDeep.SchnorrEquation

/-- TPR-052: BIP340 verification ⇔ the verification equation
(sizes, even-y lift, `r < P`, `s < n`, `R = s·G − e·P` with
`x(R) = r` and `e = eOf r px msg`). -/
@[rule "TPR-052"]
theorem tpr052_verifyImpl_iff (sig pk msg : ByteArray) :
    Bitcoin.Crypto.Schnorr.Verify.verifyImpl sig pk msg = true ↔
      satisfiesEquation sig pk msg :=
  verifyImpl_iff sig pk msg

/-- TPR-052 (soundness): an accepted signature satisfies the equation;
in particular `R ≠ ∞`, `y(R)` is even, and `x(R) = r`. -/
@[rule "TPR-052"]
theorem tpr052_verifyImpl_sound (sig pk msg : ByteArray)
    (h : Bitcoin.Crypto.Schnorr.Verify.verifyImpl sig pk msg = true) :
    satisfiesEquation sig pk msg :=
  verifyImpl_true_satisfies sig pk msg h

end BitcoinProofs.AF.PDW95
