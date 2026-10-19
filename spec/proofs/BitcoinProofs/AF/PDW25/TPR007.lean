import Bitcoin.Interpreter.Defs
import Bitcoin.Crypto.Taproot.Program
import Bitcoin.Crypto.Taproot.Sighash
import Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2
import Bitcoin.Crypto.Schnorr.Verify

/-!
# TPR-007 — the one-element witness key-path spend is a BIP340 check

`PDW25.classifySpend_one_keyPath` only classifies the witness. The whole
rule also performs `CheckSchnorrSignature` with the OUTPUT key `q` (the
32-byte witness program) as the BIP340 public key and the resolved
BIP341 sighash as the message. This module proves that end-to-end
reduction: with the real BIP340 verifier and `sighashTaproot` bound into
the checker, `verifyWitnessProgram` on `[sig]` returns exactly the
BIP340 verdict `verifyImpl sig q (sighashTaproot ...)`.
-/

namespace BitcoinProofs.AF.PDW25.TPR007

open Bitcoin.Interpreter Bitcoin.Activation
open Bitcoin.Crypto.Seam
open Bitcoin.Crypto.Taproot
open Bitcoin.Crypto.Taproot.Program (classifySpend SpendPath)
open Bitcoin.Crypto.Schnorr.Verify (verifyImpl)
open Bitcoin.Crypto.Seam.Entry (schnorrEntry schnorrVerdict schnorrHashtype_64 SIGHASH_DEFAULT)

/-- The checker with the real BIP340 verifier and the BIP341 taproot
sighash; no typed adapter, so `checkSchnorrWithContext` uses the Boolean
entry point exactly as the consensus checker does. -/
def bip340Checker (env : TapSighashEnv) (inPos : Nat) : ScriptChecker :=
  ⟨Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2.realSchnorrEntry2 env inPos,
    default, none⟩

/-- The annex-free `ScriptExecutionData` the key-path lane builds:
`m_annex_init = true`, `m_annex_present = false`, empty annex hash. -/
def keyPathEd : ScriptExecutionData := { annexInit := true }

/-- The key-path verdict, before the `VerifyOutcome` mapping: the checker
returns `.ok` exactly on a BIP340 accept and `.error .schnorrSig` on a
missing digest or an EC reject. -/
private theorem checkSchnorr_keyPath (env : TapSighashEnv) (inPos : Nat)
    (sig program : ByteArray) (hsig : sig.size = 64) (hprog : program.size = 32) :
    checkSchnorrWithContext (bip340Checker env inPos) sig program
        SigVersion.taproot keyPathEd =
      (match sighashTaproot env inPos SIGHASH_DEFAULT SigVersion.taproot keyPathEd with
       | none => Except.error ExecError.schnorrSig
       | some h => if verifyImpl sig program h then Except.ok ()
                   else Except.error ExecError.schnorrSig) := by
  simp only [bip340Checker, checkSchnorrWithContext,
    Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2.realSchnorrEntry2,
    schnorrEntry, schnorrVerdict,
    Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2.sighashSchnorrTap,
    hsig, hprog, schnorrHashtype_64]
  cases sighashTaproot env inPos SIGHASH_DEFAULT SigVersion.taproot keyPathEd with
  | none => rfl
  | some h => by_cases hv : verifyImpl sig program h <;> simp [hv]

/-- The `VerifyOutcome` mapping of the key-path verdict. -/
private theorem schnorrOutcome_keyPath (env : TapSighashEnv) (inPos : Nat)
    (sig program : ByteArray) (hsig : sig.size = 64) (hprog : program.size = 32) :
    schnorrOutcome (checkSchnorrWithContext (bip340Checker env inPos) sig program
        SigVersion.taproot keyPathEd) =
      (match sighashTaproot env inPos SIGHASH_DEFAULT SigVersion.taproot keyPathEd with
       | none => VerifyOutcome.fail ExecError.schnorrSig
       | some h => if verifyImpl sig program h then VerifyOutcome.ok
                   else VerifyOutcome.fail ExecError.schnorrSig) := by
  rw [checkSchnorr_keyPath env inPos sig program hsig hprog]
  cases sighashTaproot env inPos SIGHASH_DEFAULT SigVersion.taproot keyPathEd with
  | none => rfl
  | some h => by_cases hv : verifyImpl sig program h <;> simp [hv, schnorrOutcome]

/-- TPR-007 (whole rule): a one-element witness is a key-path spend, and
the key-path verifier checks BIP340 with the 32-byte output key `program`
against the BIP341 sighash. The result is `.ok` exactly when
`verifyImpl` accepts (and `.fail .schnorrSig` on a sighash/EC reject),
not merely a classification of the witness. -/
@[rule "TPR-007"]
theorem keyPath_one_element_bip340 (env : TapSighashEnv) (inPos : Nat)
    (fuel : Nat) (sig program : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags)
    (hflag : flags.taproot = true) (hprog : program.size = 32)
    (hsig : sig.size = 64) :
    classifySpend [sig] = SpendPath.keyPath sig ∧
    verifyWitnessProgram fuel [sig] 1 program flags pol
        (bip340Checker env inPos) false =
      (match sighashTaproot env inPos SIGHASH_DEFAULT SigVersion.taproot keyPathEd with
       | none => VerifyOutcome.fail ExecError.schnorrSig
       | some h => if verifyImpl sig program h then VerifyOutcome.ok
                   else VerifyOutcome.fail ExecError.schnorrSig) := by
  constructor
  · exact Bitcoin.Crypto.Taproot.Program.classifySpend_keyPath sig
  · simp only [verifyWitnessProgram]
    rw [if_neg (by decide : ¬(1 = 0))]
    rw [if_pos (by simp [hprog])]
    simp [hflag, keyPathEd]
    exact schnorrOutcome_keyPath env inPos sig program hsig hprog

end BitcoinProofs.AF.PDW25.TPR007
