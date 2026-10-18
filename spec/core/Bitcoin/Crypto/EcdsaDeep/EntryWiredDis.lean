import Bitcoin.Crypto.EcdsaDeep.EntryWired

/-!
# EntryWiredDis — the fuel-discharge-layer crown instantiation (the alternate-entry integration)

the rule-closure suite (deep-verification tower: the `EntryWired` `verifyStructEq'`
slot). Third link of the alternate-entry chain
(`Seam/Entry.lean` ← `EcdsaDeep/Entry.lean` ←
`EcdsaDeep/EntryWired.lean` ← **this file**), executing the one
remaining wiring step of the whole chain:

**the structural mirror's crown theorem `verifyStructG_eq_verifyImpl` (VerifyStruct.lean,
commit 6aee3e9, sorry-free) reduces the crown equality
`verifyStruct = verifyImpl` to exactly the two universal-completion
hypotheses `hE`/`hN` — the fuel-discharge layer's completion condition (the completion hypotheses;
the Lamé-depth `egcdLDone` discharge) — and `EntryWired.lean` takes
that crown equality as its one explicit hypothesis
`verifyStructEq'`. This file instantiates that hypothesis with the structural mirror's
crown AT THE FIXED FUEL LIST `FL := zeros 600`, i.e. under the fuel-discharge layer's
`hE`/`hN` the two wired alternate entries of `EntryWired.lean` ARE
the production seam entries — and nothing else is needed.**

## VERIFIED (this file, sorry-free, axiom-pinned in-module)

* `verifyStructEq'` — THE fuel-discharge-layer CROWN EQUALITY:
  `EntryWired.lean`'s `verifyStructEq'` hypothesis
  (`VerifyStruct.verifyStruct = Ecdsa.Verify.verifyImpl`) holds under
  the structural mirror's crown hypotheses instantiated at `fs := FL` — by `funext` over
  the three verifier arguments + `verifyStructG_eq_verifyImpl FL hE
  hN` verbatim. (Name = the slot's name: Entry.lean:284's
  `verifyStructEq'` funeq form.)
* `ecdsaEntryWiredDis_eq` / `txCheckerWiredOfDis_eq` — the two crown
  instantiations of `EntryWired.lean`'s production-equality theorems
  with `verifyStructEq' := verifyStructEq' hE hN`: under `hE`/`hN`,
  `ecdsaEntryWired = ecdsaEntry Ecdsa.Verify.verifyImpl` and
  `txCheckerWiredOf = txCheckerOf Ecdsa.Verify.verifyImpl` (the
  RealChecker.lean:105 / TxValidation/Full.lean:80 wiring level).

## PROPOSED (NOT here — the discharge layer, read-only)

The `hE : ∀ d < P, egcdLDone FL P d = true` / `hN : ∀ s < n,
egcdLDone FL n s = true` hypotheses themselves (the discharge layer's
fuel-completion, e.g. the Lamé-halving `egcdLDone_zeros` route on
`zeros (2·j+1)`-fuel, plus the FL = zeros 600 = zeros (2·300+1)
instantiation and the `d = 0` case). When they land, THIS file's
`hE`/`hN` binders are their exact contract (the structural mirror's crown
`verifyStructG_eq_verifyImpl` hypothesis shapes verbatim); until then
every statement here is hypothesis-form — nothing is assumed,
axiomatized or sorry-ed (the no-axiom policy), and no production path may switch to
the deep lane.

Nothing outside `EcdsaDeep/EntryWiredDis.lean` (this file), the
EntryWired.lean completion axiom-pin notes (the alternate-entry integration — see that
file's AxiomPins comment) and the companion discharge-layer notes was edited: the
structural mirror's `VerifyStruct.lean`,
the alternate-entry layer's `Entry.lean`, the verification-equation layer's `VerifyEquation.lean`, the Schnorr-equation layer's
`SchnorrEquation.lean`, the fuel-discharge layer's discharge-layer files (the discharge layer
probes) and the `Seam`/`Ecdsa` production files are read-only
throughout.
-/

namespace Bitcoin.Crypto.EcdsaDeep.EntryWiredDis

open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Seam
open Bitcoin.Crypto.Seam.Der
open Bitcoin.Crypto.Seam.Entry
open Bitcoin.Crypto.EcdsaDeep.Entry
open Bitcoin.Crypto.EcdsaDeep.EntryWired
open Bitcoin.Crypto.EcdsaDeep.VerifyStruct

/-- **THE fuel-discharge-layer CROWN EQUALITY**: `EntryWired.lean`'s
`verifyStructEq'` hypothesis (Entry.lean:284's funeq form) HOLDS under
the structural mirror's crown `verifyStructG_eq_verifyImpl` at the fixed fuel list
`FL := zeros 600` and the fuel-discharge layer's fuel-completion hypotheses `hE`/`hN`
(the structural mirror's crown hypothesis shapes verbatim — the discharge layer discharge
contract). -/
theorem verifyStructEq'
    (hE : ∀ d : Nat, d < P → egcdLDone FL P d = true)
    (hN : ∀ s : Nat, s < n → egcdLDone FL n s = true) :
    Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct
      = Bitcoin.Crypto.Ecdsa.Verify.verifyImpl := by
  funext sig pk msg
  exact verifyStructG_eq_verifyImpl FL hE hN sig pk msg

/-- **CROWN INSTANTIATION 1 (Dis-form)** = `ecdsaEntryWired_eq` with
`verifyStructEq' := verifyStructEq' hE hN`: under the fuel-discharge layer's `hE`/`hN`, the
wired alternate entry IS the production ECDSA entry
`ecdsaEntry Ecdsa.Verify.verifyImpl`. -/
theorem ecdsaEntryWiredDis_eq
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (hE : ∀ d : Nat, d < P → egcdLDone FL P d = true)
    (hN : ∀ s : Nat, s < n → egcdLDone FL n s = true) :
    ecdsaEntryWired sighash hasAmount
      = ecdsaEntry Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount :=
  ecdsaEntryWired_eq sighash hasAmount (verifyStructEq' hE hN)

/-- **CROWN INSTANTIATION 2 (Dis-form)** = `txCheckerWiredOf_eq` with
`verifyStructEq' := verifyStructEq' hE hN`: under the fuel-discharge layer's `hE`/`hN`, the
wired alternate smart constructor IS the production assembly
`txCheckerOf Ecdsa.Verify.verifyImpl` (the RealChecker.lean:105 /
TxValidation/Full.lean:80 wiring level). -/
theorem txCheckerWiredOfDis_eq
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (verifySchnorr : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (hE : ∀ d : Nat, d < P → egcdLDone FL P d = true)
    (hN : ∀ s : Nat, s < n → egcdLDone FL n s = true) :
    txCheckerWiredOf sighash hasAmount verifySchnorr sighashSchnorr
      = txCheckerOf Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount
          verifySchnorr sighashSchnorr :=
  txCheckerWiredOf_eq sighash hasAmount verifySchnorr sighashSchnorr
    (verifyStructEq' hE hN)

section AxiomPins

-- the alternate-entry integration axiom pins (axiom-pin checks), plain/guarded (the alternate-entry layer
-- Entry.lean idiom): footprints discovered by the combined probe
-- (plain #print axioms) and pinned here verbatim.
-- ALL THREE = [propext, Classical.choice, Quot.sound] (⊆ the
-- standard trio): `verifyStructEq'` = the structural mirror's crown
-- (`verifyStructG_eq_verifyImpl`, the trio per its own t15 pins)
-- under `funext` (Quot.sound); the two Dis-instantiations = the
-- EntryWired completion theorems (the trio — the `verifyStruct`/
-- `verifyImpl` def-constant closures) ∪ the crown (the trio). NO
-- sorryAx, NO custom axioms anywhere in this module.

/-- info: 'Bitcoin.Crypto.EcdsaDeep.EntryWiredDis.verifyStructEq'' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms verifyStructEq'

/-- info: 'Bitcoin.Crypto.EcdsaDeep.EntryWiredDis.ecdsaEntryWiredDis_eq' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms ecdsaEntryWiredDis_eq

/-- info: 'Bitcoin.Crypto.EcdsaDeep.EntryWiredDis.txCheckerWiredOfDis_eq' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms txCheckerWiredOfDis_eq

end AxiomPins

end Bitcoin.Crypto.EcdsaDeep.EntryWiredDis
