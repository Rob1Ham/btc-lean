import Bitcoin.Crypto.EcdsaDeep.EntryWiredDis
import Bitcoin.Crypto.EcdsaDeep.FuelDischarge

/-!
# EntryWiredDisUncond — the Dis-form crown, hypothesis-free (the alternate-entry integration)

the rule-closure suite. Fourth link of the alternate-entry chain
(`Seam/Entry.lean` ← `EcdsaDeep/Entry.lean` ← `EcdsaDeep/EntryWired.lean`
← `EcdsaDeep/EntryWiredDis.lean` ← **this file**): `EntryWiredDis.lean`
proved the Dis-form production equalities under the structural mirror's `hE`/`hN`; the discharge layer's
`FuelDischarge.lean` (`hE_uncond`/`hN_uncond`, already landed and pinned
⊆ the standard trio) discharges those hypotheses. This file is the
three-line application — nothing else, no re-proof, no new hypothesis.

`FuelDischarge.lean` and `EntryWiredDis.lean` are read-only here; this
file adds no `sorry`, no axiom, no `native_decide`. The deep lane remains
an ALTERNATE entry point: no production path (`Capstone/RealChecker.lean`,
`TxValidation/Full.lean`) is switched by this file.
-/

namespace Bitcoin.Crypto.EcdsaDeep.EntryWiredDisUncond

open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Seam.Entry
open Bitcoin.Crypto.EcdsaDeep.EntryWired
open Bitcoin.Crypto.EcdsaDeep.EntryWiredDis
open Bitcoin.Crypto.EcdsaDeep.FuelDischarge

/-- the structural mirror's crown at `FL = zeros 600`, hypothesis-free (via the discharge layer). -/
theorem verifyStructEq'_uncond :
    Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct
      = Bitcoin.Crypto.Ecdsa.Verify.verifyImpl :=
  verifyStructEq' hE_uncond hN_uncond

/-- The wired ECDSA alternate entry IS the production entry. -/
theorem ecdsaEntryWiredDis_eq_uncond
    (sighash : ByteArray → UInt8 → Bitcoin.Crypto.Seam.SigVersion → ByteArray)
    (hasAmount : Bool) :
    ecdsaEntryWired sighash hasAmount
      = ecdsaEntry Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount :=
  ecdsaEntryWiredDis_eq sighash hasAmount hE_uncond hN_uncond

/-- The wired smart constructor IS the production assembly. -/
theorem txCheckerWiredOfDis_eq_uncond
    (sighash : ByteArray → UInt8 → Bitcoin.Crypto.Seam.SigVersion → ByteArray)
    (hasAmount : Bool)
    (verifySchnorr : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : Bitcoin.Crypto.Seam.ScriptExecutionData → UInt8 →
      Bitcoin.Crypto.Seam.SigVersion → Option ByteArray) :
    txCheckerWiredOf sighash hasAmount verifySchnorr sighashSchnorr
      = txCheckerOf Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount
          verifySchnorr sighashSchnorr :=
  txCheckerWiredOfDis_eq sighash hasAmount verifySchnorr sighashSchnorr
    hE_uncond hN_uncond

section AxiomPins

/-- info: 'Bitcoin.Crypto.EcdsaDeep.EntryWiredDisUncond.verifyStructEq'_uncond' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms verifyStructEq'_uncond

/-- info: 'Bitcoin.Crypto.EcdsaDeep.EntryWiredDisUncond.ecdsaEntryWiredDis_eq_uncond' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms ecdsaEntryWiredDis_eq_uncond

/-- info: 'Bitcoin.Crypto.EcdsaDeep.EntryWiredDisUncond.txCheckerWiredOfDis_eq_uncond' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms txCheckerWiredOfDis_eq_uncond

end AxiomPins

end Bitcoin.Crypto.EcdsaDeep.EntryWiredDisUncond
