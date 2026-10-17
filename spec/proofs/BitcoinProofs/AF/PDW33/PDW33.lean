import Bitcoin.Interpreter.Rules

/-! # PDW33.lean — TOP-161..165, part 1 (SCR-009 flag combo, SCR-132 locktime env)
(PDW33, review RC27, 2026-10-17; claim a904643).

Route B (zero core writes): row-face theorems on the sorry-free core
defs of `Bitcoin/Interpreter/Rules.lean`; tags ride these theorems and
the `lean_target`s flip at promotion.

* **SCR-009** `flagsComboOk` — VerifyScript's two flag-combination
  assertions (interpreter.cpp:2113-2114, :2124): the consensus selector
  satisfies both at every height, WITNESS without P2SH is fail-closed,
  and CLEANSTACK reduces to the p2sh∧witness arm.
* **SCR-132** `locktimeEnvOf` — the checker environment is input-local:
  version/locktime are the tx fields, sequence is the `nIn`-th input's,
  so CLTV/CSV verdicts are per-input (interpreter.cpp:1755, 1792-1796).
-/

namespace BitcoinProofs.AF.PDW33

open Bitcoin.Interpreter Bitcoin.Activation Bitcoin.Numeric

@[rule "SCR-009"]
theorem flagsComboOk_consensus_row (height : UInt32) :
    flagsComboOk (getBlockScriptFlags height) default = true :=
  (flagsComboOk_consensus height).1

theorem flagsComboOk_witness_requires_p2sh (flags : ScriptFlags) (pol : PolicyFlags)
    (hcs : pol.cleanstack = false) (hw : flags.witness = true)
    (hp : flags.p2sh = false) : flagsComboOk flags pol = false := by
  unfold flagsComboOk
  simp [hcs, hw, hp]

theorem flagsComboOk_witness_p2sh_ok (flags : ScriptFlags) (pol : PolicyFlags)
    (hcs : pol.cleanstack = false) (hw : flags.witness = true)
    (hp : flags.p2sh = true) : flagsComboOk flags pol = true := by
  unfold flagsComboOk
  simp [hcs, hw, hp]

theorem flagsComboOk_cleanstack_arm (flags : ScriptFlags) (pol : PolicyFlags)
    (hcs : pol.cleanstack = true) :
    flagsComboOk flags pol = ((flags.p2sh ∧ flags.witness) ∧ (!flags.witness ∨ flags.p2sh)) := by
  unfold flagsComboOk
  simp [hcs]

@[rule "SCR-132"]
theorem locktimeEnvOf_version (tx : Bitcoin.Data.Tx) (nIn : Nat) :
    (locktimeEnvOf tx nIn).txVersion = tx.version := rfl

theorem locktimeEnvOf_locktime (tx : Bitcoin.Data.Tx) (nIn : Nat) :
    (locktimeEnvOf tx nIn).txLockTime = tx.locktime := rfl

theorem locktimeEnvOf_congr_row (tx tx' : Bitcoin.Data.Tx) (nIn : Nat)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (hvin : (tx.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence
          = (tx'.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence) :
    locktimeEnvOf tx nIn = locktimeEnvOf tx' nIn :=
  locktimeEnvOf_congr tx tx' nIn hver hlt hvin

@[rule "SCR-132"]
theorem checkLockTime_perInput_row (tx tx' : Bitcoin.Data.Tx) (nIn : Nat)
    (n : ScriptNum) (hver : tx.version = tx'.version)
    (hlt : tx.locktime = tx'.locktime)
    (hvin : (tx.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence
          = (tx'.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence) :
    checkLockTimeDef (locktimeEnvOf tx nIn) n
      = checkLockTimeDef (locktimeEnvOf tx' nIn) n :=
  checkLockTime_perInput tx tx' nIn n hver hlt hvin

@[rule "SCR-132"]
theorem checkSequence_perInput_row (tx tx' : Bitcoin.Data.Tx) (nIn : Nat)
    (n : ScriptNum) (hver : tx.version = tx'.version)
    (hlt : tx.locktime = tx'.locktime)
    (hvin : (tx.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence
          = (tx'.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence) :
    checkSequenceDef (locktimeEnvOf tx nIn) n
      = checkSequenceDef (locktimeEnvOf tx' nIn) n :=
  checkSequence_perInput tx tx' nIn n hver hlt hvin

#print axioms flagsComboOk_consensus_row
#print axioms flagsComboOk_witness_requires_p2sh
#print axioms flagsComboOk_witness_p2sh_ok
#print axioms flagsComboOk_cleanstack_arm
#print axioms locktimeEnvOf_version
#print axioms locktimeEnvOf_locktime
#print axioms locktimeEnvOf_congr_row
#print axioms checkLockTime_perInput_row
#print axioms checkSequence_perInput_row

end BitcoinProofs.AF.PDW33
