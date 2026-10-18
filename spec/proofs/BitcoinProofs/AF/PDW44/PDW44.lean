import Bitcoin.Interpreter.SigOps

/-! # PDW44.lean — RC27, items TOP-216..220
(PDW44, 2026-10-17; claim v3). D-SIGOPS band {SWT-022, SWT-023,
SWT-027, INV-037, TPR-069} — PDW55's v1 claim on the same rows was
released to PDW44 (v1 D-SIGOPS yielded to PDW44;
their `6d4a371`); the earlier v2 RC08 pick is yielded back to PDW55
(`PDW44RC08Yield.lean`, F-PDW44-001/002).

The band is `Bitcoin/Interpreter/SigOps.lean`
(Core `tx_verify.cpp:149-168`, `interpreter.cpp:2133-2173`):

* **SWT-022/023** `sigOpCost` — the legacy and P2SH terms enter at
  `WITNESS_SCALE_FACTOR = 4` (one added legacy/P2SH sigop = +4 cost).
* **SWT-027** `p2shWitnessSigOps` — a P2SH-wrapped v0-20 witness
  program contributes its witness sigops (1); unparsable scriptSig = 0.
* **INV-037** `witnessSigOps` — v0-20 = 1, v0-32 = accurate count of
  the last witness item, other v0 sizes = 0.
* **TPR-069** `witnessSigOps` — a v1 (taproot) input contributes 0 to
  the 80,000 block cost.

Route B: zero core writes, tags ride THESE row-face theorems,
pins ⊆ [propext, Classical.choice, Quot.sound]. -/

namespace BitcoinProofs.AF.PDW44

open Bitcoin.Interpreter Bitcoin.Interpreter.SigOps Bitcoin.Script.Parser

/-! ## SWT-022/023 — the ×4 legacy and P2SH terms -/

/-- **SWT-022**: cost is the ×4 (legacy + P2SH) term plus witness. -/
@[rule "SWT-022"]
theorem sigOpCost_legacy_scale (l p w : Nat) :
    sigOpCost ⟨l, p, w⟩ = 4 * (l + p) + w := rfl

/-- **SWT-022**: one more legacy sigop adds exactly 4 cost units. -/
@[rule "SWT-022"]
theorem sigOpCost_legacy_step (l p w : Nat) :
    sigOpCost ⟨l + 1, p, w⟩ = sigOpCost ⟨l, p, w⟩ + 4 := by
  simp [sigOpCost, LEGACY_SIGOP_SCALE]
  omega

/-- **SWT-023**: one more P2SH redeemScript sigop adds exactly 4. -/
@[rule "SWT-023"]
theorem sigOpCost_p2sh_step (l p w : Nat) :
    sigOpCost ⟨l, p + 1, w⟩ = sigOpCost ⟨l, p, w⟩ + 4 := by
  simp [sigOpCost, LEGACY_SIGOP_SCALE]
  omega

/-- **SWT-023**: P2SH and legacy sigops carry the SAME scale factor. -/
@[rule "SWT-023"]
theorem sigOpCost_p2sh_eq_legacy_scale (l p w : Nat) :
    sigOpCost ⟨l, p, w⟩ = LEGACY_SIGOP_SCALE * l + LEGACY_SIGOP_SCALE * p + w := by
  simp [sigOpCost, LEGACY_SIGOP_SCALE]
  omega

/-! ## SWT-027 — P2SH-wrapped witness program counts its witness sigops -/

@[rule "SWT-027"]
theorem p2shWitnessSigOps_p2wpkh (ss : ByteArray) (witness : List ByteArray)
    (ops : List WireOp) (op : WireOp) (prog p2 : ByteArray)
    (hparse : parseWire ss = some ops) (hlast : ops.getLast? = some op)
    (hpush : op.ast = .pushBytes prog)
    (hisw : isWitnessProgram prog = some (0, p2)) (h20 : p2.size = 20) :
    p2shWitnessSigOps ss witness = 1 := by
  simp [p2shWitnessSigOps, hparse, hlast, hpush, hisw,
    witnessSigOps_p2wpkh p2 witness h20]

@[rule "SWT-027"]
theorem p2shWitnessSigOps_unparsable (ss : ByteArray) (witness : List ByteArray)
    (h : parseWire ss = none) : p2shWitnessSigOps ss witness = 0 := by
  simp [p2shWitnessSigOps, h]

/-! ## INV-037 — the v0 witness-size trichotomy -/

@[rule "INV-037"]
theorem witnessSigOps_v0_20 (prog : ByteArray) (w : List ByteArray)
    (h : prog.size = 20) : witnessSigOps 0 prog w = 1 :=
  witnessSigOps_p2wpkh prog w h

@[rule "INV-037"]
theorem witnessSigOps_v0_32 (prog : ByteArray) (w : List ByteArray)
    (h : prog.size = 32) :
    witnessSigOps 0 prog w =
      (match w.getLast? with
       | some script => witnessScriptSigOps script
       | none => 0) :=
  witnessSigOps_p2wsh prog w h

@[rule "INV-037"]
theorem witnessSigOps_v0_other (prog : ByteArray) (w : List ByteArray)
    (h20 : prog.size ≠ 20) (h32 : prog.size ≠ 32) :
    witnessSigOps 0 prog w = 0 := by
  simp [witnessSigOps, h20, h32]

/-- **INV-037**: the complete v0 branch table — 20-byte programs cost 1
(P2WPKH), 32-byte programs cost the accurate count of the last witness
item (P2WSH), every other v0 length costs 0. -/
@[rule "INV-037"]
theorem witnessSigOps_v0_cases (prog : ByteArray) (w : List ByteArray) :
    witnessSigOps 0 prog w =
      (if prog.size = 20 then 1
       else if prog.size = 32 then
         (match w.getLast? with
          | some script => witnessScriptSigOps script
          | none => 0)
       else 0) := rfl

/-- **INV-037**: every non-zero witness version (v1+ — taproot & beyond)
contributes 0 to the block sigop budget; v1 sigops are priced by BIP342
validation weight at execution time (the separate SCR-040/TPR-022 lane),
not by `CountWitnessSigOps`. -/
@[rule "INV-037"]
theorem witnessSigOps_version_ne_zero (v : Nat) (prog : ByteArray)
    (w : List ByteArray) (hv : v ≠ 0) : witnessSigOps v prog w = 0 := by
  unfold witnessSigOps
  rw [if_neg hv]

/-- **INV-037**: the row's full trichotomy in one conjunction: P2WPKH = 1,
P2WSH = last-witness-item count, other v0 = 0, and all v1+ versions = 0. -/
@[rule "INV-037"]
theorem witnessSigOps_trichotomy (prog : ByteArray) (w : List ByteArray) :
    (prog.size = 20 → witnessSigOps 0 prog w = 1) ∧
    (prog.size = 32 → witnessSigOps 0 prog w =
      (match w.getLast? with
       | some script => witnessScriptSigOps script
       | none => 0)) ∧
    (prog.size ≠ 20 → prog.size ≠ 32 → witnessSigOps 0 prog w = 0) ∧
    (∀ v : Nat, v ≠ 0 → witnessSigOps v prog w = 0) := by
  refine ⟨?_, ?_, ?_, ?_⟩
  · intro h; exact witnessSigOps_v0_20 prog w h
  · intro h; exact witnessSigOps_v0_32 prog w h
  · intro h20 h32; exact witnessSigOps_v0_other prog w h20 h32
  · intro v hv; exact witnessSigOps_version_ne_zero v prog w hv

/-! ## TPR-069 — taproot (v1) inputs are outside the sigop budget -/

@[rule "TPR-069"]
theorem witnessSigOps_v1_zero (prog : ByteArray) (w : List ByteArray) :
    witnessSigOps 1 prog w = 0 := by
  simp [witnessSigOps]

/-- **TPR-069** composed with the cost model: a taproot-only input costs 0. -/
@[rule "TPR-069"]
theorem sigOpCost_taproot_input_zero (prog : ByteArray) (w : List ByteArray) :
    sigOpCost ⟨0, 0, witnessSigOps 1 prog w⟩ = 0 := by
  simp [sigOpCost, LEGACY_SIGOP_SCALE, witnessSigOps]

#print axioms witnessSigOps_v0_cases
#print axioms witnessSigOps_version_ne_zero
#print axioms witnessSigOps_trichotomy

end BitcoinProofs.AF.PDW44
