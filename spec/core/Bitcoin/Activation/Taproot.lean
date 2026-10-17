import Bitcoin.Activation.Bip9
import Bitcoin.Activation.Flags

/-!
# Bitcoin.Activation.Taproot — the BIP9 taproot deployment and the
# always-on flag regime (X06)

The activation-side TPR rows, pinned as a STANDALONE historical record
composed from W10's `Bip9Deployment` (Bitcoin.Activation.Bip9) and W06's
flag port (Bitcoin.Activation.Flags) — no edits to either:

* **TPR-075** — the historical mainnet taproot BIP9 deployment: bit 2,
  start 1619222400 (2021-04-24), timeout 1628640000 (2021-08-11),
  threshold 1815 (90%), period 2016, min_activation_height 709632
  (bip-0341:346-347; chainparams.cpp:117-124's MinBIP9WarningHeight
  comment era). In CURRENT master @cce32b168 the params table carries
  only testdummy — taproot is buried/always-on (TPR-077), so this
  record is deliberately NOT in `mainnetDeployments`, exactly like
  W10's precedent `segwitBip9Deployment` (SWT-036).
* **TPR-076** — the taproot exception block `…1e395ad` (height 692261)
  validates with P2SH|WITNESS only: `taproot = false` there, keyed by
  HASH (W06's `mainnetExceptionMap` / `exception_replaces_base`).
* **TPR-077** — away from exception blocks {P2SH, WITNESS, TAPROOT} is
  the base set at EVERY height (genesis onward; buried heights only OR
  in DERSIG/CLTV/CSV/NULLDUMMY) — validation.cpp:2256-2260,
  `base_flags_p2sh_witness_taproot` (BLK-083) specialized to mainnet.
* **TPR-078** — `DeploymentActiveAt` composes with the PREVIOUS block
  (deploymentstatus.h:14-18: active for `pindex` iff ACTIVE at
  `pindex.pprev`); in the height abstraction the first active block is
  exactly `min_activation_height` = 709632.

Ground truth @cce32b168: `deploymentstatus.h:14-18,36`,
`validation.cpp:GetBlockScriptFlags:2249-2288`,
`kernel/chainparams.cpp:117-124`, bip-0341 §Deployment (lines 310-347).
-/

namespace Bitcoin.Activation

/-! ## TPR-075 — the historical taproot BIP9 deployment -/

/-- The activation height: taproot mainnet rules apply FROM block
709,632 (bip-0341:346-347 "The deployment did activate at height
709632 on Bitcoin mainnet"; BIP9 LOCKED_IN→ACTIVE gate at
`min_activation_height`, bip-0341:341-344). -/
def TAPROOT_ACTIVATION_HEIGHT : UInt32 := 709632

/-- TPR-075: the historical mainnet taproot BIP9 deployment row
(bip-0341 §Deployment: name "taproot", bit 2; mainnet starttime
1619222400, timeout 1628640000, threshold 1815 = 90%, period 2016
(BIP9 default), min_activation_height 709632). Historical record —
NOT in `mainnetDeployments` (current master @cce32b168 is buried/
always-on, TPR-077). -/
@[rule "TPR-075"]
def taprootBip9Deployment : Bip9Deployment :=
  { bit := 2, start := 1619222400, timeout := 1628640000,
    minActivation := 709632, threshold := 1815, period := 2016 }

/-- TPR-075 (value pin): bit 2, the BIP9 parameters of the taproot
rollout, min_activation_height = the 709,632 activation block. -/
theorem taprootBip9Deployment_values :
    taprootBip9Deployment.bit = 2 ∧
    taprootBip9Deployment.start = 1619222400 ∧
    taprootBip9Deployment.timeout = 1628640000 ∧
    taprootBip9Deployment.minActivation = 709632 ∧
    taprootBip9Deployment.threshold = 1815 ∧
    taprootBip9Deployment.period = 2016 := by
  decide

/-- The deployment table @cce32b168 does NOT carry the historical
taproot row (only dormant testdummy) — taproot is always-on there
(TPR-077), so the W10 dormancy theorems over `mainnetDeployments`
stay faithful. -/
theorem mainnetDeployments_no_taproot :
    taprootBip9Deployment ∉ mainnetDeployments := by
  simp only [mainnetDeployments, List.mem_singleton]
  intro h
  have hbit : taprootBip9Deployment.bit = mainnetTestdummy.bit := by rw [h]
  simp [taprootBip9Deployment, mainnetTestdummy] at hbit

/-! ## TPR-076 — the taproot exception block -/

/-- TPR-076 (chainparams.cpp:117-121 @cce32b168): the taproot-violating
block `…1e395ad` (height 692,261; hash keyed, ANY height) validates
with P2SH | WITNESS only — TAPROOT is OFF there, and P2SH/WITNESS are
on. W06's `exception_replaces_base` + `mainnet_taproot_exception_lookup`
specialized; height is irrelevant because the exception map keys on the
block hash alone. -/
@[rule "TPR-076"]
theorem taproot_exception_block_flags (height : UInt32) :
    (getBlockScriptFlagsP mainnetParams taprootExceptionHash height).p2sh
      = true ∧
    (getBlockScriptFlagsP mainnetParams taprootExceptionHash height).witness
      = true ∧
    (getBlockScriptFlagsP mainnetParams taprootExceptionHash height).taproot
      = false := by
  have hexc : mainnetParams.scriptFlagExceptions taprootExceptionHash
      = some { p2sh := true, witness := true, taproot := false } :=
    mainnet_taproot_exception_lookup
  have h := exception_replaces_base mainnetParams taprootExceptionHash height
    _ hexc
  exact h

/-! ## TPR-077 — always-on base flags (buried regime) -/

/-- TPR-077 (validation.cpp:2256-2260 @cce32b168; "mod exceptions"):
on current mainnet {P2SH, WITNESS, TAPROOT} is the base flag set at
EVERY height — genesis onward; the buried heights only ever OR IN
DERSIG/CLTV/CSV/NULLDUMMY and never drop the base trio. This is W06's
BLK-083 `base_flags_p2sh_witness_taproot` specialized to mainnet with
the height universally quantified. -/
@[rule "TPR-077"]
theorem taproot_always_on_base (hash : BlockHash) (height : UInt32)
    (hnone : mainnetExceptionMap hash = none) :
    (getBlockScriptFlagsP mainnetParams hash height).p2sh = true ∧
    (getBlockScriptFlagsP mainnetParams hash height).witness = true ∧
    (getBlockScriptFlagsP mainnetParams hash height).taproot = true :=
  base_flags_p2sh_witness_taproot mainnetParams hash height hnone

/-- TPR-077 (genesis corner): height 0 included — the always-on regime
starts at the very first block (away from exception blocks, which are
all far above genesis). -/
theorem taproot_always_on_genesis (hash : BlockHash)
    (hnone : mainnetExceptionMap hash = none) :
    (getBlockScriptFlagsP mainnetParams hash 0).taproot = true := by
  have h := taproot_always_on_base hash 0 hnone
  exact h.2.2

/-! ## TPR-078 — DeploymentActiveAt composes with the previous block -/

/-- TPR-078 (deploymentstatus.h:14-18,36 @cce32b168): a deployment is
active for a block at `height` iff it is active at its PREVIOUS block
(`DeploymentActiveAt(pindex) = DeploymentActiveAfter(pindex.pprev)`);
in the height abstraction the gate is `min_activation_height ≤ height`
— the LOCKED_IN→ACTIVE transition of bip-0341:340-344 fires exactly
when the block reaches `min_activation_height`. -/
@[rule "TPR-078", rule "INV-138"]
def deploymentActiveAt (d : Bip9Deployment) (height : UInt32) : Bool :=
  d.minActivation ≤ height

/-- TPR-078 (pprev composition): for a block at `height = pprev + 1`
the gate reads on the previous block's height as
`min_activation_height ≤ pprev + 1` — i.e. `DeploymentActiveAfter`
with the +1 that `DeploymentActiveAt` adds when descending to `pprev`. -/
theorem deploymentActiveAt_pprev (d : Bip9Deployment) (pprev height : UInt32)
    (hh : height = pprev + 1) :
    deploymentActiveAt d height = true ↔ d.minActivation ≤ pprev + 1 := by
  rw [deploymentActiveAt, hh]
  exact decide_eq_true_iff

/-- TPR-078 (first active block): taproot is active at EXACTLY height
709,632 — the activation block itself. -/
theorem taproot_first_active :
    deploymentActiveAt taprootBip9Deployment TAPROOT_ACTIVATION_HEIGHT
      = true := by
  unfold deploymentActiveAt
  unfold taprootBip9Deployment
  unfold TAPROOT_ACTIVATION_HEIGHT
  decide

/-- TPR-078 (not active the block before): height 709,631 is the last
pre-activation block. -/
theorem taproot_not_active_before :
    deploymentActiveAt taprootBip9Deployment (TAPROOT_ACTIVATION_HEIGHT - 1)
      = false := by
  unfold deploymentActiveAt
  unfold taprootBip9Deployment
  unfold TAPROOT_ACTIVATION_HEIGHT
  decide

/-- TPR-078 (iff form): taproot deployment active at `height` iff
`709632 ≤ height`. -/
theorem deploymentActiveAt_taproot_iff (height : UInt32) :
    deploymentActiveAt taprootBip9Deployment height = true ↔
      TAPROOT_ACTIVATION_HEIGHT ≤ height := by
  unfold deploymentActiveAt
  unfold taprootBip9Deployment
  unfold TAPROOT_ACTIVATION_HEIGHT
  exact decide_eq_true_iff

/-! ## Axiom footprints (X06 style: `#guard_msgs in #print axioms`)

All sorry-free; footprints ⊆ the standard trio.
-/

/-- info: 'Bitcoin.Activation.taprootBip9Deployment_values' does not depend on any axioms -/
#guard_msgs in #print axioms taprootBip9Deployment_values

/-- info: 'Bitcoin.Activation.mainnetDeployments_no_taproot' depends on axioms: [propext] -/
#guard_msgs in #print axioms mainnetDeployments_no_taproot

/-- info: 'Bitcoin.Activation.taproot_exception_block_flags' depends on axioms: [propext] -/
#guard_msgs in #print axioms taproot_exception_block_flags

/-- info: 'Bitcoin.Activation.taproot_always_on_genesis' depends on axioms: [propext] -/
#guard_msgs in #print axioms taproot_always_on_genesis

/-- info: 'Bitcoin.Activation.deploymentActiveAt_pprev' depends on axioms: [propext] -/
#guard_msgs in #print axioms deploymentActiveAt_pprev

/-- info: 'Bitcoin.Activation.taproot_first_active' does not depend on any axioms -/
#guard_msgs in #print axioms taproot_first_active

/-- info: 'Bitcoin.Activation.taproot_not_active_before' does not depend on any axioms -/
#guard_msgs in #print axioms taproot_not_active_before

/-- info: 'Bitcoin.Activation.deploymentActiveAt_taproot_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms deploymentActiveAt_taproot_iff

end Bitcoin.Activation
