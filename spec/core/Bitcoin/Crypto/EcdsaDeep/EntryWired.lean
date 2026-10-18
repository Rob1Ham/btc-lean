import Bitcoin.Crypto.EcdsaDeep.Entry
import Bitcoin.Crypto.EcdsaDeep.VerifyStruct

/-!
# EntryWired — the structural-mirror crown wiring of the deep alternate entry point

EcdsaDeep integration file, the second file of
`Crypto/EcdsaDeep/` (`Entry.lean` is the first). This
file executes the **structural-mirror integration slot** of `Entry.lean:272-307`:

> the alternate entry becomes the production entry by two
> instantiations and nothing else:
>
>     ecdsaEntryDeepEqProduction := ecdsaEntryDeep_eq' _ _ _ _ verifyStructEq'
>     txCheckerDeepOfEqProduction := txCheckerDeepOf_eq' _ _ _ _ _ verifyStructEq'

That is EXACTLY what this file adds — nothing more, nothing less:
`verifyD := Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct`
(the kernel-decidable structural mirror
of `Bitcoin.Crypto.Ecdsa.Verify.verifyImpl`,
DECISION-lax-ecdsa semantics) at the two instantiation points.

## VERIFIED vs PROPOSED (the no-axiom policy / R6 honesty split)

* VERIFIED (this file, sorry-free, axiom-pinned in-module): the two
  crown instantiations `ecdsaEntryWired` / `txCheckerWiredOf` (the
  deep alternates at the structural mirror's `verifyStruct`) and their
  production-equality theorems — under the crown equality
  `verifyStructEq'`, taken as an EXPLICIT HYPOTHESIS, the wired
  alternate entries equal the production seam entries `ecdsaEntry` /
  `txCheckerOf` at `Bitcoin.Crypto.Ecdsa.Verify.verifyImpl`. With the structural mirror
  completion's `verifyStructG_eq_verifyImpl` (which discharges exactly
  that hypothesis) these close to unconditional equalities — that
  theorem is the contract, and the ONLY remaining gap.
* PROPOSED (NOT here): (1) the crown equality itself —
  `verifyStruct = verifyImpl` = the structural-mirror completion (`mulPbsG_eq_mulP` +
  `verifyStructG_eq_verifyImpl`, hE/hN structural-mirror hypotheses) —
  **unlanded**: the structural-mirror completion remains at its initial version,
  and this file deliberately does NOT axiomatize, assume, or sorry it
  (the no-axiom policy: never a shortcut through the crypto). (2) The
  capstone-level assembly `realCheckerFullDeepOf` mirroring
  `Capstone/RealChecker.lean:103 realCheckerFullOf` — per the structural mirror
  integration slot it "then lands in a further NEW file of this
  directory" (Entry.lean:298-304); sketch in the PROPOSED section at
  the bottom.

Nothing here edits, replaces, or quarantines any production file: the
deep lane stays an ALTERNATE entry point (no production path may
switch to it until the structural-mirror completion lands).
-/

namespace Bitcoin.Crypto.EcdsaDeep.EntryWired

open Bitcoin.Crypto.Seam
open Bitcoin.Crypto.Seam.Der
open Bitcoin.Crypto.Seam.Entry
open Bitcoin.Crypto.EcdsaDeep.Entry

/-! ## The wired alternate entries (the structural-mirror definition in the alternate-entry layer). -/

/-- `ecdsaEntryDeep` at
`verifyD := Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct`
(the structural mirror, `VerifyStruct.lean:449`): the kernel-decidable
structural mirror in the ECDSA verifier slot of the deep alternate
entry. The first of the two instantiations of the structural-mirror integration
slot (Entry.lean:280-284). -/
def ecdsaEntryWired (sighash : ByteArray → UInt8 → SigVersion → ByteArray)
    (hasAmount : Bool) : BaseSignatureChecker :=
  ecdsaEntryDeep Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct
    sighash hasAmount

/-- `txCheckerDeepOf` at
`verifyD := Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct`: the
deep alternate smart constructor (the wiring level that
`RealChecker.lean:105` / `TxValidation/Full.lean:80` assemble via
`txCheckerOf`), the second instantiation of the structural-mirror integration slot
(Entry.lean:285-292). -/
def txCheckerWiredOf (sighash : ByteArray → UInt8 → SigVersion → ByteArray)
    (hasAmount : Bool)
    (verifySchnorr : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray) :
    BaseSignatureChecker :=
  txCheckerDeepOf Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct
    sighash hasAmount verifySchnorr sighashSchnorr

/-! ## The production-equality theorems (the crown equality is the one
and only hypothesis). THE integration contract of this file: the structural mirror
completion's crown equality `verifyStructEq'` is the ONLY thing between
the wired alternate entries and the production seam entries. -/

/-- CROWN INSTANTIATION 1 (`ecdsaEntryDeepEqProduction` of the structural mirror
slot): under
`verifyStructEq' : ...VerifyStruct.verifyStruct = ...Ecdsa.Verify.verifyImpl`
(the structural-mirror completion's `verifyStructG_eq_verifyImpl`, UNLANDED — see the
honesty split above), the wired alternate entry IS the production
ECDSA entry `ecdsaEntry Ecdsa.Verify.verifyImpl`. -/
theorem ecdsaEntryWired_eq
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (verifyStructEq' : Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct
      = Bitcoin.Crypto.Ecdsa.Verify.verifyImpl) :
    ecdsaEntryWired sighash hasAmount
      = ecdsaEntry Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount :=
  ecdsaEntryDeep_eq' Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct
    Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount verifyStructEq'

/-- CROWN INSTANTIATION 2 (`txCheckerDeepOfEqProduction` of the structural mirror
slot): under the same crown equality, the wired alternate smart
constructor IS the production assembly
`txCheckerOf Ecdsa.Verify.verifyImpl` — the RealChecker.lean:105 /
TxValidation/Full.lean:80 wiring level. -/
theorem txCheckerWiredOf_eq
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (verifySchnorr : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (verifyStructEq' : Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct
      = Bitcoin.Crypto.Ecdsa.Verify.verifyImpl) :
    txCheckerWiredOf sighash hasAmount verifySchnorr sighashSchnorr
      = txCheckerOf Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount
          verifySchnorr sighashSchnorr :=
  txCheckerDeepOf_eq' Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct
    Bitcoin.Crypto.Ecdsa.Verify.verifyImpl sighash hasAmount verifySchnorr
    sighashSchnorr verifyStructEq'

/-! ## PROPOSED: the capstone-level assembly (NOT here)

Per the structural-mirror integration slot (Entry.lean:298-304):

> The capstone-level assembly (`realCheckerFullDeepOf` mirroring
> `RealChecker.realCheckerFullOf`) then lands in a further NEW file of
> this directory (never editing RealChecker.lean), with
> `realCheckerFullDeepOf_eq` proved by `txCheckerDeepOf_eq'` +
> `checker_ext`.

Sketch (not elaborated here; the structural-mirror and alternate-entry layers
remain future work):

    import Bitcoin.Capstone.RealChecker

    def realCheckerFullDeepOf (tx : Tx) (nIn : Nat) (amount : Amount) :
        Bitcoin.Interpreter.ScriptChecker :=
      { base := txCheckerWiredOf (sighashDispatch tx nIn amount) true
            Bitcoin.Crypto.Schnorr.Verify.verifyImpl (fun _ _ _ => none)
        env := { txVersion := tx.version
                 txLockTime := tx.locktime
                 txSequence := (tx.vin.getD nIn dummyTxIn).sequence } }

    theorem realCheckerFullDeepOf_eq (tx : Tx) (nIn : Nat) (amount : Amount)
        (verifyStructEq' : ...VerifyStruct.verifyStruct
          = ...Ecdsa.Verify.verifyImpl) :
        realCheckerFullDeepOf tx nIn amount
          = realCheckerFullOf tx nIn amount :=
      by congr 1; exact txCheckerWiredOf_eq _ _ _ _ _ verifyStructEq'

(`realCheckerFullOf` = Capstone/RealChecker.lean:103-110,
`sighashDispatch` = RealChecker.lean:69; the env side is identical, so
`congr 1` + the second crown instantiation + `checker_ext`-style
extensionality should close it.) -/

section AxiomPins

-- the alternate-entry layers' axiom pins (axiom-pin checks), EntryWired completion: both public
-- theorems of this module are one-step instantiations of the pinned
-- Entry.lean transport laws (`ecdsaEntryDeep_eq'` /
-- `txCheckerDeepOf_eq'`, both [propext, Quot.sound] — the funext toll
-- of the congruence laws). The initial version of these pins recorded
-- [propext, Quot.sound] here, but that version was never elaborated. The
-- first elaboration showed the actual footprints of BOTH theorems
-- = [propext, Classical.choice,
-- Quot.sound]: unlike the generic Entry.lean transport laws
-- (`verifyD`/`verifyI` are VARIABLES there; [propext, Quot.sound]),
-- these instantiations fix `verifyD := VerifyStruct.verifyStruct`
-- and `verifyI := Ecdsa.Verify.verifyImpl` — def-constants at the
-- argument positions, in the hypothesis's equation TYPE, and on the
-- equality RHS (:102/:117) — and `#print axioms` traverses those
-- definitions' closures (the Int/decide machinery of the egcdL
-- mirror and of the WF original), which depend on Classical.choice.
-- The crown equality remains an ordinary HYPOTHESIS — no proof-term
-- axiom is added by assuming it; the delta is in the statement's/
-- type's constant closure only. NO sorryAx, NO custom axioms; ⊆ the
-- standard trio.

/-- info: 'Bitcoin.Crypto.EcdsaDeep.EntryWired.ecdsaEntryWired_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms ecdsaEntryWired_eq

/-- info: 'Bitcoin.Crypto.EcdsaDeep.EntryWired.txCheckerWiredOf_eq' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms txCheckerWiredOf_eq

end AxiomPins

end Bitcoin.Crypto.EcdsaDeep.EntryWired
