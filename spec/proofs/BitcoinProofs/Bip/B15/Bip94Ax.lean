import BitcoinProofs.Bip.B15.Bip94Tests

/- B15 axiom audit — run from the proofs package:
`lake env lean BitcoinProofs/Bip/B15/Bip94Ax.lean`
Expect the standard trio at most (propext, Quot.sound, Classical.choice);
NEVER sorryAx. -/

#print axioms BitcoinProofs.Bip.B15.timewarpOk_true_iff
#print axioms BitcoinProofs.Bip.B15.workOf_eq_formula
