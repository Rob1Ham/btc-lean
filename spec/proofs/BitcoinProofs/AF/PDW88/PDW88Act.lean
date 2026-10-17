import Bitcoin.Activation.Taproot

/-! PDW88 — INV-138 / TPR-078: the BIP9 `DeploymentActiveAt` gate and its
previous-block composition (deploymentstatus.h @cce32b168). -/

namespace BitcoinProofs.AF.PDW88
open Bitcoin.Activation

/-- INV-138: the BIP9 `DeploymentActiveAt` helper is exactly the
`min_activation_height ≤ height` gate. -/
@[rule "INV-138"]
theorem deploymentActiveAt_iff (d : Bip9Deployment) (height : UInt32) :
    deploymentActiveAt d height = true ↔ d.minActivation ≤ height := by
  unfold deploymentActiveAt
  exact decide_eq_true_iff

/-- TPR-078: `DeploymentActiveAt(pindex) = DeploymentActiveAfter(pprev)` —
for a block at `height = pprev + 1` the gate reads
`min_activation_height ≤ pprev + 1`. -/
@[rule "TPR-078"]
theorem deploymentActiveAt_pprev_row (d : Bip9Deployment) (pprev height : UInt32)
    (hh : height = pprev + 1) :
    deploymentActiveAt d height = true ↔ d.minActivation ≤ pprev + 1 :=
  deploymentActiveAt_pprev d pprev height hh

end BitcoinProofs.AF.PDW88

/-- info: 'BitcoinProofs.AF.PDW88.deploymentActiveAt_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW88.deploymentActiveAt_iff
/-- info: 'BitcoinProofs.AF.PDW88.deploymentActiveAt_pprev_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW88.deploymentActiveAt_pprev_row
