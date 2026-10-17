import Bitcoin.Interpreter.Defs
import Bitcoin.DataLaws.Laws

/-!
# BitcoinProofs.AF.PDW60b — TOP-321..325 row faces (push-only + sig-encoding gates)

Route B restatements over `spec/core/Bitcoin/Interpreter/Defs.lean`
(`isPushOnlyWire` :479, `checkSigEncoding` :355) and
`spec/core/Bitcoin/DataLaws/Laws.lean` (`bip68Enabled` :309).
Zero core writes; `@[rule]` tags ride these theorems.
Pins ⊆ [propext, Classical.choice, Quot.sound].
-/

namespace BitcoinProofs.AF.PDW60b

open Bitcoin.Interpreter
open Bitcoin.DataLaws

/-! ## SCR-052 — push-only wire classification -/

/-- **SCR-052**: a parsed script is push-only iff every wire opcode is
`≤ OP_16` (0x60) — `OP_RESERVED` (0x50) included (script.h `IsPushOnly`). -/
@[rule "SCR-052"]
theorem isPushOnlyWire_iff (ops : List WireOp) :
    isPushOnlyWire ops = true ↔ ∀ o ∈ ops, o.wire ≤ 0x60 := by
  simp only [isPushOnlyWire, List.all_eq_true]
  constructor <;> intro h o ho
  · simpa using h o ho
  · simpa using h o ho

/-- SCR-052 composition: push-only is closed under concatenation/split. -/
@[rule "SCR-052"]
theorem isPushOnlyWire_append (a b : List WireOp) :
    isPushOnlyWire (a ++ b) = (isPushOnlyWire a && isPushOnlyWire b) := by
  simp [isPushOnlyWire, List.all_append]

/-- SCR-052 empty lane: the empty script is push-only. -/
@[rule "SCR-052"]
theorem isPushOnlyWire_nil : isPushOnlyWire ([] : List WireOp) = true := rfl

/-! ## SCR-108 / SWT-058 / SWT-060 — `CheckSignatureEncoding` gates -/

/-- **SCR-108**: an empty signature bypasses every DER check — even with
DERSIG, LOW_S and STRICTENC all set (interpreter.cpp:126-128). -/
@[rule "SCR-108"]
theorem checkSigEncoding_empty (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) :
    checkSigEncoding flags pol (ByteArray.empty) = none := by
  simp [checkSigEncoding]

/-- **SWT-058**: the LOW_S branch is policy-only — with `pol.lowS = false`
the checker never returns `sigHighS` (consensus `ScriptFlags` has no LOW_S). -/
@[rule "SWT-058"]
theorem checkSigEncoding_no_lowS (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sig : ByteArray) (h : pol.lowS = false) :
    checkSigEncoding flags pol sig ≠ some .sigHighS := by
  unfold checkSigEncoding
  by_cases h0 : sig.size = 0
  · simp [h0]
  · rw [if_neg h0]
    by_cases h1 : (flags.dersig ∨ pol.lowS ∨ pol.strictEnc) ∧ !isValidSigEncoding sig
    · rw [if_pos h1]; simp
    · rw [if_neg h1, if_neg (by simp [h])]
      by_cases h3 : pol.strictEnc ∧ !isDefinedHashtype sig
      · rw [if_pos h3]; simp
      · rw [if_neg h3]; simp

/-- **SWT-058/060 consensus path**: with the default (empty) policy word the
gate reduces to the DERSIG check; LOW_S/hashtype errors are unreachable. -/
@[rule "SWT-058", rule "SWT-060"]
theorem checkSigEncoding_consensus_path (flags : Bitcoin.Activation.ScriptFlags)
    (sig : ByteArray) (hsig : 0 < sig.size) :
    checkSigEncoding flags (default : PolicyFlags) sig
      = if flags.dersig ∧ !isValidSigEncoding sig then some .sigDer else none := by
  unfold checkSigEncoding
  have hp1 : (default : PolicyFlags).lowS = false := rfl
  have hp2 : (default : PolicyFlags).strictEnc = false := rfl
  have hne0 : ¬(sig.size = 0) := by omega
  simp [hp1, hp2, hne0]

/-- **SWT-060**: the defined-hashtype branch rides `strictEnc` — with
`pol.strictEnc = false` the checker never returns `sigHashType` (BIP146). -/
@[rule "SWT-060"]
theorem checkSigEncoding_no_hashType (flags : Bitcoin.Activation.ScriptFlags)
    (pol : PolicyFlags) (sig : ByteArray) (h : pol.strictEnc = false) :
    checkSigEncoding flags pol sig ≠ some .sigHashType := by
  unfold checkSigEncoding
  by_cases h0 : sig.size = 0
  · simp [h0]
  · rw [if_neg h0]
    by_cases h1 : (flags.dersig ∨ pol.lowS ∨ pol.strictEnc) ∧ !isValidSigEncoding sig
    · rw [if_pos h1]; simp
    · rw [if_neg h1]
      by_cases h2 : pol.lowS ∧ !checkLowS (sig.extract 0 (sig.size - 1))
      · rw [if_pos h2]; simp
      · rw [if_neg h2, if_neg (by simp [h])]
        simp

/-! ## TXV-034 — the BIP68 enable gate -/

/-- **TXV-034** accept lane: wire version ≥ 2 reduces the gate to
`LOCKTIME_VERIFY_SEQUENCE` (tx_verify.cpp:57). -/
@[rule "TXV-034"]
theorem bip68Enabled_of_version (v : Int32) (f : Bool)
    (hv : 2 ≤ v.toUInt32.toNat) : bip68Enabled v f = f := by
  simp [bip68Enabled, hv]

/-- **TXV-034** reject lane: a pre-BIP68 wire version disables the gate
regardless of the locktime flag. -/
@[rule "TXV-034"]
theorem bip68Enabled_of_old_version (v : Int32) (f : Bool)
    (hv : v.toUInt32.toNat < 2) : bip68Enabled v f = false := by
  simp [bip68Enabled, Nat.not_le.mpr hv]

/-- **TXV-034** flag lane: with LOCKTIME_VERIFY_SEQUENCE unset the gate is
off for every version. -/
@[rule "TXV-034"]
theorem bip68Enabled_flag_off (v : Int32) : bip68Enabled v false = false := by
  simp [bip68Enabled]

/-- TXV-034 wire fidelity: version 1 is pre-BIP68 (gate off). -/
@[rule "TXV-034"]
theorem bip68Enabled_version_one (f : Bool) : bip68Enabled 1 f = false := by
  have h : ¬(2 ≤ (1 : Int32).toUInt32.toNat) := by decide
  simp [bip68Enabled, h]

/-- TXV-034 wire fidelity corner: the Int32 `-1` field is wire version
0xFFFFFFFF, which Core reads unsigned and therefore ENABLES BIP68. -/
@[rule "TXV-034"]
theorem bip68Enabled_wire_neg_one : bip68Enabled (-1) true = true := by
  decide

end BitcoinProofs.AF.PDW60b

/-! ## Axiom pins (charter trio check: zero `sorryAx`) -/

/-- info: 'BitcoinProofs.AF.PDW60b.isPushOnlyWire_iff' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60b.isPushOnlyWire_iff

/-- info: 'BitcoinProofs.AF.PDW60b.isPushOnlyWire_append' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60b.isPushOnlyWire_append

/-- info: 'BitcoinProofs.AF.PDW60b.isPushOnlyWire_nil' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60b.isPushOnlyWire_nil

/-- info: 'BitcoinProofs.AF.PDW60b.checkSigEncoding_empty' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60b.checkSigEncoding_empty

/-- info: 'BitcoinProofs.AF.PDW60b.checkSigEncoding_no_lowS' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60b.checkSigEncoding_no_lowS

/-- info: 'BitcoinProofs.AF.PDW60b.checkSigEncoding_consensus_path' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60b.checkSigEncoding_consensus_path

/-- info: 'BitcoinProofs.AF.PDW60b.checkSigEncoding_no_hashType' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60b.checkSigEncoding_no_hashType

/-- info: 'BitcoinProofs.AF.PDW60b.bip68Enabled_of_version' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60b.bip68Enabled_of_version

/-- info: 'BitcoinProofs.AF.PDW60b.bip68Enabled_of_old_version' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60b.bip68Enabled_of_old_version

/-- info: 'BitcoinProofs.AF.PDW60b.bip68Enabled_flag_off' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60b.bip68Enabled_flag_off

/-- info: 'BitcoinProofs.AF.PDW60b.bip68Enabled_version_one' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60b.bip68Enabled_version_one

/-- info: 'BitcoinProofs.AF.PDW60b.bip68Enabled_wire_neg_one' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW60b.bip68Enabled_wire_neg_one
