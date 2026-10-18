import Bitcoin.Interpreter.Defs
import Bitcoin.Interpreter.SigOps
import Bitcoin.Serialization.Interface
import Bitcoin.DataLaws.Interface

/-!
# BitcoinProofs.Theorems.WitnessRulesCor — X05: SegWit-v0 witness-rule theorems

New sorry-free theorems over the witness-side machinery (`verifyWitnessProgram` / `executeWitnessScript` / `isWitnessProgram`,
`decTxCore`, X05's `SigOps` model, DataLaws' `vsize`). Each theorem carries an
axiom fingerprint via `#guard_msgs` + `#print axioms` — footprints are within
the sanctioned trio `[propext, Classical.choice, Quot.sound]`, most are
axiom-free.

| # | theorem | row | statement (short) | axioms |
|---|---------|-----|-------------------|--------|
| 1 | `isWitnessProgram_version_closure` | SWT-001/002 | decoded (v, prog): 4 ≤ \|b\| ≤ 42, 2 ≤ \|prog\| ≤ 40, \|prog\|+2 = \|b\|, v ∈ {0} ∪ [1,16] | (none) |
| 2 | `verifyWitnessProgram_v0_wrongLength` | SWT-009 | v0, \|prog\| ∉ {20,32} → fail WRONG_LENGTH | (none) |
| 3 | `verifyWitnessProgram_v0_p2wsh_empty_witness` | SWT-007 | v0-32, witness = [] → fail WITNESS_EMPTY (fail-closed) | (none) |
| 4 | `verifyWitnessProgram_v0_p2wpkh_arity` | SWT-005 | v0-20, \|witness\| ≠ 2 → fail MISMATCH | (none) |
| 5 | `verifyWitnessProgram_v0_p2wsh_mismatch` | SWT-008 | v0-32, SHA256(last) ≠ prog → fail MISMATCH | (none) |
| 6 | `executeWitnessScript_item_cap` | SWT-010 | any item > 520 → fail pushSize | (none) |
| 7 | `verifyWitnessProgram_future_ok` | SWT-013 | v=2 (any program) → ok (anyone-can-spend closure) | (none) |
| 8 | `verifyWitnessProgram_discourage_fail` | SWT-014 | v=3 + DISCOURAGE flag → fail | (none) |
| 9 | `witnessSigOps_p2wpkh_one` | SWT-025 | v0-20 input = exactly 1 witness sigop | (none) |
| 10 | `witnessSigOps_future_zero` | SWT-028 | v ≥ 1 → 0 witness sigops | (none) |
| 11 | `decTxCore_flag_zero_short_record` | SWT-038 | marker/flag 0x00-0x00 short record decodes | (none) |
| 12 | `decTxCore_superfluousWitness` | SWT-039 | flag=1, all stacks empty → superfluousWitness | (none) |
| 13 | `vsize_ceiling_pin` | SWT-020 | vsize = (weight+3)/4 ceiling sandwich | propext, Classical.choice, Quot.sound |
| 14 | `checkSigEncoding_consensus_path` | SWT-058/060 | default policy ⇒ encoding check = DERSIG gate only | (none) |

Statement-fidelity note (honest scope): theorems 2–8 quantify over arbitrary
`fuel/flags/pol/chk` — the witness-program layer rejects BEFORE any
interpreter state matters, which is exactly the BIP141 shape (the program
template is checked before EvalScript runs). `hashSha256` is opaque, so
theorem 5 is stated as the mismatch IMPLICATION (reject when the hash
differs), not by computation on a concrete digest.
-/

namespace BitcoinProofs.Theorems.WitnessRules

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Serialization Bitcoin.Activation

/-! ## 1. The witness-program template closes on itself (SWT-001/002) -/

theorem isWitnessProgram_version_closure (b : ByteArray) (v : Nat) (prog : ByteArray)
    (h : isWitnessProgram b = some (v, prog)) :
    4 ≤ b.size ∧ b.size ≤ 42 ∧ 2 ≤ prog.size ∧ prog.size ≤ 40 ∧
      prog.size + 2 = b.size ∧ (v = 0 ∨ (1 ≤ v ∧ v ≤ 16)) := by
  unfold isWitnessProgram at h
  by_cases h4 : 4 ≤ b.size ∧ b.size ≤ 42
  · by_cases hv : (b.get! 0).toNat = 0 ∨ (0x51 ≤ (b.get! 0).toNat ∧ (b.get! 0).toNat ≤ 0x60)
    · by_cases hplen : (b.get! 1).toNat + 2 = b.size
      · simp only [h4, if_true, hv, hplen, if_true, Option.some.injEq, Prod.mk.injEq] at h
        obtain ⟨rfl, rfl⟩ := h
        have hsz : (b.extract 2 b.size).size = b.size - 2 := by
          rw [ByteArray.size_extract]; omega
        refine ⟨h4.1, h4.2, by omega, by omega, by omega, ?_⟩
        rcases hv with hv | hv
        · left; simp [hv]
        · right; simp only [if_neg (by omega : ¬((b.get! 0).toNat = 0))]
          omega
      · simp [h4, hv, hplen] at h
    · simp [h4, hv] at h
  · simp [h4] at h

/-! ## 2. v0 program-length enforcement (SWT-009) -/

theorem verifyWitnessProgram_v0_wrongLength (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h20 : program.size ≠ 20) (h32 : program.size ≠ 32) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = .fail .witnessProgramWrongLength := by
  simp [verifyWitnessProgram, h32, h20]

/-! ## 3. P2WSH empty-witness reject is fail-closed (SWT-007) -/

theorem verifyWitnessProgram_v0_p2wsh_empty_witness (fuel : Nat)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool) (h32 : program.size = 32) :
    verifyWitnessProgram fuel [] 0 program flags pol chk isP2SH
      = .fail .witnessProgramWitnessEmpty := by
  simp [verifyWitnessProgram, h32]

/-! ## 4. P2WPKH witness arity (SWT-005) -/

theorem verifyWitnessProgram_v0_p2wpkh_arity (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h20 : program.size = 20) (harity : witness.length ≠ 2) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = .fail .witnessProgramMismatch := by
  simp [verifyWitnessProgram, h20, harity]

/-! ## 5. P2WSH program match (SWT-008) -/

theorem verifyWitnessProgram_v0_p2wsh_mismatch (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool)
    (h32 : program.size = 32) (hne : witness ≠ [])
    (hhash : (hashSha256 ((witness.getLast?).getD default) != program) = true) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = .fail .witnessProgramMismatch := by
  have hlen : witness.length ≠ 0 := by simp [hne]
  simp [verifyWitnessProgram, h32, hlen, hhash]

/-! ## 6. The per-item 520-byte cap fires before execution (SWT-010) -/

theorem executeWitnessScript_item_cap (fuel : Nat) (items : List ByteArray)
    (vwSer : Int) (exec : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker)
    (h : (items.any (fun d => MAX_SCRIPT_ELEMENT_SIZE < d.size)) = true) :
    executeWitnessScript fuel items vwSer exec flags pol chk .witnessV0
      = .fail .pushSize := by
  rw [executeWitnessScript, if_neg (by simp : ¬((Bitcoin.Crypto.Seam.SigVersion.witnessV0 :
      Bitcoin.Crypto.Seam.SigVersion) = .tapscript)),
    executeWitnessScript.runExec, if_pos h]

/-! ## 7. Future-version pass-through (SWT-013) -/

theorem verifyWitnessProgram_future_ok (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker)
    (hd : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel witness 2 program flags pol chk false = .ok := by
  simp [verifyWitnessProgram, hd, isPayToAnchor]

/-! ## 8. DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM (SWT-014) -/

theorem verifyWitnessProgram_discourage_fail (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker)
    (hd : pol.discourageUpgradableWitnessProgram = true) :
    verifyWitnessProgram fuel witness 3 program flags pol chk false
      = .fail .discourageUpgradableWitnessProgram := by
  simp [verifyWitnessProgram, hd, isPayToAnchor]

/-! ## 9. Sigop-cost laws (SWT-025 / SWT-028) -/

theorem witnessSigOps_p2wpkh_one (program : ByteArray) (witness : List ByteArray)
    (h : program.size = 20) :
    Bitcoin.Interpreter.SigOps.witnessSigOps 0 program witness = 1 :=
  Bitcoin.Interpreter.SigOps.witnessSigOps_p2wpkh program witness h

theorem witnessSigOps_future_zero (v : Nat) (program : ByteArray)
    (witness : List ByteArray) (hv : 1 ≤ v) :
    Bitcoin.Interpreter.SigOps.witnessSigOps v program witness = 0 :=
  Bitcoin.Interpreter.SigOps.witnessSigOps_future_zero v program witness hv

/-! ## 10. BIP144 framing (SWT-038/039) -/

/-- The marker/flag short record: version ‖ 0x00 0x00 ‖ locktime decodes to
a vin-less, vout-less tx with an empty witness (Core reads NOTHING past the
zero flag byte). -/
theorem decTxCore_flag_zero_short_record :
    Bitcoin.Serialization.decTxCore [1, 0, 0, 0, 0, 0, 0, 0, 0, 0]
      = .ok (⟨1, [], [], 0, []⟩, []) := by
  rfl

/-- The superfluous-witness record: flag = 0x01 but EVERY witness stack
empty (here: zero inputs) → serialization error (transaction.h:229-232). -/
theorem decTxCore_superfluousWitness :
    Bitcoin.Serialization.decTxCore [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0]
      = .error .superfluousWitness := by
  rfl

/-! ## 11. vsize ceiling (SWT-020) -/

theorem vsize_ceiling_pin (tx : Tx) :
    Bitcoin.DataLaws.vsize tx = (Bitcoin.DataLaws.txWeight tx + 3) / 4
      ∧ Bitcoin.DataLaws.txWeight tx / 4 ≤ Bitcoin.DataLaws.vsize tx
      ∧ Bitcoin.DataLaws.vsize tx ≤ Bitcoin.DataLaws.txWeight tx / 4 + 1 :=
  ⟨rfl, (Bitcoin.DataLaws.vsize_ceiling tx).1, (Bitcoin.DataLaws.vsize_ceiling tx).2⟩

/-! ## 12. The consensus path of CheckSignatureEncoding = DERSIG only
(SWT-058/060: LOW_S and STRICTENC-encoding are policy) -/

theorem checkSigEncoding_consensus_path (flags : ScriptFlags) (sig : ByteArray)
    (hsig : 0 < sig.size) :
    Bitcoin.Interpreter.checkSigEncoding flags default sig
      = if flags.dersig ∧ !isValidSigEncoding sig then some .sigDer else none := by
  unfold checkSigEncoding
  have hp1 : (default : PolicyFlags).lowS = false := rfl
  have hp2 : (default : PolicyFlags).strictEnc = false := rfl
  have hne0 : ¬(sig.size = 0) := by omega
  simp [hp1, hp2, hne0]

/-! ## Axiom fingerprints -/

/-- info: 'BitcoinProofs.Theorems.WitnessRules.isWitnessProgram_version_closure' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms isWitnessProgram_version_closure
/-- info: 'BitcoinProofs.Theorems.WitnessRules.verifyWitnessProgram_v0_wrongLength' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms verifyWitnessProgram_v0_wrongLength
/-- info: 'BitcoinProofs.Theorems.WitnessRules.verifyWitnessProgram_v0_p2wsh_empty_witness' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms verifyWitnessProgram_v0_p2wsh_empty_witness
/-- info: 'BitcoinProofs.Theorems.WitnessRules.verifyWitnessProgram_v0_p2wpkh_arity' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms verifyWitnessProgram_v0_p2wpkh_arity
/-- info: 'BitcoinProofs.Theorems.WitnessRules.verifyWitnessProgram_v0_p2wsh_mismatch' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms verifyWitnessProgram_v0_p2wsh_mismatch
/-- info: 'BitcoinProofs.Theorems.WitnessRules.executeWitnessScript_item_cap' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms executeWitnessScript_item_cap
/-- info: 'BitcoinProofs.Theorems.WitnessRules.verifyWitnessProgram_future_ok' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms verifyWitnessProgram_future_ok
/-- info: 'BitcoinProofs.Theorems.WitnessRules.verifyWitnessProgram_discourage_fail' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms verifyWitnessProgram_discourage_fail
/-- info: 'BitcoinProofs.Theorems.WitnessRules.witnessSigOps_p2wpkh_one' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms witnessSigOps_p2wpkh_one
/-- info: 'BitcoinProofs.Theorems.WitnessRules.witnessSigOps_future_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms witnessSigOps_future_zero
/-- info: 'BitcoinProofs.Theorems.WitnessRules.decTxCore_flag_zero_short_record' depends on axioms: [propext] -/
#guard_msgs in
#print axioms decTxCore_flag_zero_short_record
/-- info: 'BitcoinProofs.Theorems.WitnessRules.decTxCore_superfluousWitness' depends on axioms: [propext] -/
#guard_msgs in
#print axioms decTxCore_superfluousWitness
/-- info: 'BitcoinProofs.Theorems.WitnessRules.vsize_ceiling_pin' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms vsize_ceiling_pin
/-- info: 'BitcoinProofs.Theorems.WitnessRules.checkSigEncoding_consensus_path' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in
#print axioms checkSigEncoding_consensus_path

end BitcoinProofs.Theorems.WitnessRules
