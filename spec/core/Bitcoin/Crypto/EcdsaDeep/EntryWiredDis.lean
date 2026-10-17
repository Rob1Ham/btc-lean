import Bitcoin.Crypto.EcdsaDeep.EntryWired

/-!
# EntryWiredDis — the E14-slot crown instantiation (E16B)

Review-RC22 contributor E16B (DL tower: the `EntryWired` `verifyStructEq'`
slot). Third link of the E16 alternate-entry chain
(`Seam/Entry.lean` ← `EcdsaDeep/Entry.lean` ←
`EcdsaDeep/EntryWired.lean` ← **this file**), executing the one
remaining wiring step of the whole chain:

**E11's crown theorem `verifyStructG_eq_verifyImpl` (VerifyStruct.lean,
commit 6aee3e9, sorry-free) reduces the crown equality
`verifyStruct = verifyImpl` to exactly the two universal-completion
hypotheses `hE`/`hN` — E14's fuel-completion layer (F-E14-9/F-E14-8;
the Lamé-depth `egcdLDone` discharge) — and `EntryWired.lean` takes
that crown equality as its one explicit hypothesis
`verifyStructEq'`. This file instantiates that hypothesis with E11's
crown AT THE FIXED FUEL LIST `FL := zeros 600`, i.e. under E14's
`hE`/`hN` the two wired alternate entries of `EntryWired.lean` ARE
the production seam entries — and nothing else is needed.**

## VERIFIED (this file, sorry-free, axiom-pinned in-module)

* `verifyStructEq'` — THE E14-SLOT CROWN EQUALITY:
  `EntryWired.lean`'s `verifyStructEq'` hypothesis
  (`VerifyStruct.verifyStruct = Ecdsa.Verify.verifyImpl`) holds under
  E11's crown hypotheses instantiated at `fs := FL` — by `funext` over
  the three verifier arguments + `verifyStructG_eq_verifyImpl FL hE
  hN` verbatim. (Name = the slot's name: Entry.lean:284's
  `verifyStructEq'` funeq form.)
* `ecdsaEntryWiredDis_eq` / `txCheckerWiredOfDis_eq` — the two crown
  instantiations of `EntryWired.lean`'s production-equality theorems
  with `verifyStructEq' := verifyStructEq' hE hN`: under `hE`/`hN`,
  `ecdsaEntryWired = ecdsaEntry Ecdsa.Verify.verifyImpl` and
  `txCheckerWiredOf = txCheckerOf Ecdsa.Verify.verifyImpl` (the
  RealChecker.lean:105 / TxValidation/Full.lean:80 wiring level).

## PROPOSED (NOT here — the E14-2 discharge layer, read-only)

The `hE : ∀ d < P, egcdLDone FL P d = true` / `hN : ∀ s < n,
egcdLDone FL n s = true` hypotheses themselves (E14-2's
fuel-completion, e.g. the Lamé-halving `egcdLDone_zeros` route on
`zeros (2·j+1)`-fuel, plus the FL = zeros 600 = zeros (2·300+1)
instantiation and the `d = 0` case). When they land, THIS file's
`hE`/`hN` binders are their exact contract (E11's crown
`verifyStructG_eq_verifyImpl` hypothesis shapes verbatim); until then
every statement here is hypothesis-form — nothing is assumed,
axiomatized or sorry-ed (D-004), and no production path may switch to
the deep lane.

Nothing outside `EcdsaDeep/EntryWiredDis.lean` (this file), the
EntryWired.lean pass-2 axiom-pin repair (E16B — the twin's blind
pass-1 pins, see that file's AxiomPins comment) and this report's
companion findings entry was edited: E11's `VerifyStruct.lean`,
E16's `Entry.lean`, E06's `VerifyEquation.lean`, E08's
`SchnorrEquation.lean`, E14's discharge-layer files (E14-2
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

/-- **THE E14-SLOT CROWN EQUALITY**: `EntryWired.lean`'s
`verifyStructEq'` hypothesis (Entry.lean:284's funeq form) HOLDS under
E11's crown `verifyStructG_eq_verifyImpl` at the fixed fuel list
`FL := zeros 600` and E14's fuel-completion hypotheses `hE`/`hN`
(E11's crown hypothesis shapes verbatim — the E14-2 discharge
contract). -/
theorem verifyStructEq'
    (hE : ∀ d : Nat, d < P → egcdLDone FL P d = true)
    (hN : ∀ s : Nat, s < n → egcdLDone FL n s = true) :
    Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct
      = Bitcoin.Crypto.Ecdsa.Verify.verifyImpl := by
  funext sig pk msg
  exact verifyStructG_eq_verifyImpl FL hE hN sig pk msg

/-- **CROWN INSTANTIATION 1 (Dis-form)** = `ecdsaEntryWired_eq` with
`verifyStructEq' := verifyStructEq' hE hN`: under E14's `hE`/`hN`, the
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
`verifyStructEq' := verifyStructEq' hE hN`: under E14's `hE`/`hN`, the
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

-- E16B L3 axiom pins (D2 ladder), pass-1-plain/pass-2-guard (the E16
-- Entry.lean idiom): footprints discovered by the cat-probe
-- probe1.lean (plain #print axioms, 1.46s) and pinned here verbatim.
-- ALL THREE = [propext, Classical.choice, Quot.sound] (⊆ the
-- charter/D2 trio): `verifyStructEq'` = E11's crown
-- (`verifyStructG_eq_verifyImpl`, the trio per its own t15 pins)
-- under `funext` (Quot.sound); the two Dis-instantiations = the
-- EntryWired pass-2 theorems (the trio — the `verifyStruct`/
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
