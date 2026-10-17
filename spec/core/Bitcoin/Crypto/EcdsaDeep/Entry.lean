import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Crypto.Ecdsa.Verify

/-!
# Bitcoin.Crypto.EcdsaDeep.Entry — the deep-ECDSA alternate seam entry (E16, EcdsaDeep)

EcdsaDeep integration file (contributor E16). The DL suite (E01–E16) is building the
proved, kernel-checkable ECDSA tower (risk R6 / D-004: the WF-recursive
modexp/egcd layer of `Bitcoin.Crypto.Ecdsa.Verify.verifyImpl` cannot be
kernel-reduced). THIS file is the tower's landing pad at the signature seam:
an **alternate entry point** of `Bitcoin.Crypto.Seam.Entry` — the deep
(kernel-decidable) verifier slot — together with the **transport laws** that
reduce "alternate entry ≡ production entry" to exactly "deep verify ≡
production verify", the one equality the tower must prove.

## The seam contract this file instantiates

`Seam/Entry.lean` (W13) is the frozen two-function boundary of the EC layer:
`ecdsaVerdict` / `ecdsaEntry` (interpreter.cpp:1701-1724), `schnorrVerdict` /
`schnorrEntry` (interpreter.cpp:1726-1752) and the smart constructor
`txCheckerOf` (Seam/Entry.lean:48/65/192/208/271) — ALL parameterized over
the raw `verify : ByteArray → ByteArray → ByteArray → Bool`. Production
wires `Bitcoin.Crypto.Ecdsa.Verify.verifyImpl` (W14b lax verifier,
DECISION-lax-ecdsa.md) into that slot at exactly two places:

* `Bitcoin.Capstone.RealChecker.realCheckerFullOf` (RealChecker.lean:105);
* `Bitcoin.TxValidation.Full.txCheckerFor` (TxValidation/Full.lean:80).

Per the suite discipline this file NEVER edits `Seam/Entry.lean` (or any
existing file): the deep alternate entry is a NEW def family
(`ecdsaEntryDeep` / `schnorrEntryDeep` / `txCheckerDeepOf`) over the SAME
abstract `verifyD` parameter, so it is a lawful seam inhabitant by
transport (§ contracts below) and becomes the production entry the moment
`verifyD` is instantiated with a proved-equal deep verifier.

## VERIFIED vs PROPOSED (D-004 / R6 honesty split)

* VERIFIED (this file, sorry-free, axiom-pinned in-module):
  1. Congruence laws — the raw `verify` parameter is the ONLY degree of
     freedom of every seam verdict (`ecdsaVerdict_congr`,
     `schnorrVerdict_congr`): function equality transports to verdict
     equality at every gate (pubkey, size, hashtype, amount).
  2. Entry/assembly equivalence — pointwise `verifyD = verifyI` implies
     `ecdsaEntryDeep verifyD = ecdsaEntry verifyI` and
     `txCheckerDeepOf verifyD = txCheckerOf verifyI` as checkers
     (extensionality via `Seam.checker_eq_of_entry_eq`), and likewise for
     the Schnorr slot. Hence: **deep checker ≡ production checker is
     exactly the E11 crown equality `verifyStruct = verifyImpl`**.
  3. The alternate entry is a lawful seam inhabitant: every frozen W13
     seam contract on the ECDSA entry (execdata-inertness,
     SWT-054 empty-sig, pubkey gate, SWT-053 hashtype-pop,
     SWT-055 witnessV0-missing-amount) transports to `ecdsaEntryDeep`
     for an ARBITRARY deep verifier.
* PROPOSED (NOT here; see the E11 integration slot at the bottom):
  the crown wiring itself — instantiating `verifyD` with
  `Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct` (E11) and
  discharging the hypothesis with E11's mirror-equality theorem. Nothing
  in this file assumes, states or axiomatizes that equality.
-/

namespace Bitcoin.Crypto.EcdsaDeep.Entry

open Bitcoin.Crypto.Seam
open Bitcoin.Crypto.Seam.Der
open Bitcoin.Crypto.Seam.Entry

/-! ## Congruence laws: the verify parameter is the seam's only degree
of freedom. Pointwise equality of the raw verifier is a congruence for
`ecdsaVerdict` (hence for `ecdsaEntry`'s ECDSA branch) and for
`schnorrVerdict` (hence for `schnorrEntry`'s BIP340 branch). -/

/-- The ECDSA verdict is invariant under replacing the raw verifier with
a pointwise-equal one, at every interpreter gate (pubkey-validity,
empty-signature, WITNESS_V0 amount) — the gate logic lives in
`ecdsaVerdict` BEFORE `verify` is ever called (Seam/Entry.lean:48-66). -/
theorem ecdsaVerdict_congr (verifyD verifyI : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (v : SigVersion) (sig pk code : ByteArray)
    (h : ∀ a b c, verifyD a b c = verifyI a b c) :
    ecdsaVerdict verifyD sighash hasAmount v sig pk code
      = ecdsaVerdict verifyI sighash hasAmount v sig pk code := by
  have he : verifyD = verifyI := funext fun a => funext fun b => funext fun c => h a b c
  simp only [ecdsaVerdict, he]

/-- The Schnorr verdict is invariant under replacing the raw verifier
with a pointwise-equal one, at every gate (sigversion, 32-byte key,
64/65-byte sig, hashtype split, missing-data fail-closed). -/
theorem schnorrVerdict_congr (verifyD verifyI : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (h : ∀ a b c, verifyD a b c = verifyI a b c) :
    schnorrVerdict verifyD sighashSchnorr sig pk v d
      = schnorrVerdict verifyI sighashSchnorr sig pk v d := by
  have he : verifyD = verifyI := funext fun a => funext fun b => funext fun c => h a b c
  simp only [schnorrVerdict, he]

/-! ## The deep alternate entry points (E16, EcdsaDeep).

These mirror `Seam.Entry.ecdsaEntry` / `schnorrEntry` / `txCheckerOf`
exactly, with the EC verifier slot named `verifyD` for the deep
(kernel-decidable) implementation E11 will land. -/

/-- `Seam.Entry.ecdsaEntry` with the EC verifier slot reserved for the
deep verifier: the E16 alternate entry point of the ECDSA seam. Its
checkers are equal to the production ones whenever
`verifyD = Bitcoin.Crypto.Ecdsa.Verify.verifyImpl` pointwise
(`ecdsaEntryDeep_eq`). -/
def ecdsaEntryDeep (verifyD : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray)
    (hasAmount : Bool) : BaseSignatureChecker :=
  ecdsaEntry verifyD sighash hasAmount

/-- `Seam.Entry.schnorrEntry` with the BIP340 verifier slot reserved for
the deep verifier (E08 / S03 lane). -/
def schnorrEntryDeep (verifyD : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray) :
    BaseSignatureChecker :=
  schnorrEntry verifyD sighashSchnorr

/-- `Seam.Entry.txCheckerOf` with the ECDSA slot reserved for the deep
verifier: the E16 alternate of the smart constructor W09's interpreter
binds the seam to (vs `RealChecker.realCheckerFullOf` at
RealChecker.lean:105 and `TxValidation.Full.txCheckerFor` at
TxValidation/Full.lean:80). -/
def txCheckerDeepOf (verifyD : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (verifySchnorr : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray) :
    BaseSignatureChecker :=
  txCheckerOf verifyD sighash hasAmount verifySchnorr sighashSchnorr

/-! ## Entry-level equivalence: the E16 transport laws.

THE integration contract of this file: a pointwise equality
`verifyD = verifyI` of raw verifiers (E11's crown deliverable takes
`verifyD := EcdsaDeep.VerifyStruct.verifyStruct` and
`verifyI := Bitcoin.Crypto.Ecdsa.Verify.verifyImpl`) makes the deep
alternate entries EQUAL to the production seam entries as
`BaseSignatureChecker`s — the interpreter cannot distinguish them
(`Seam.checker_eq_of_entry_eq`), at the `ecdsaEntry`, `schnorrEntry` and
`txCheckerOf` assembly levels alike. -/

/-- Pointwise `verifyD = verifyI` ⇒ `ecdsaEntryDeep verifyD` IS the
production ECDSA entry `ecdsaEntry verifyI`. -/
theorem ecdsaEntryDeep_eq (verifyD verifyI : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (h : ∀ a b c, verifyD a b c = verifyI a b c) :
    ecdsaEntryDeep verifyD sighash hasAmount = ecdsaEntry verifyI sighash hasAmount := by
  apply checker_eq_of_entry_eq
  · intro sig pk code v d
    exact ecdsaVerdict_congr verifyD verifyI sighash hasAmount v sig pk code h
  · intro sig pk v d
    rfl

/-- Function-equality form of `ecdsaEntryDeep_eq`. -/
theorem ecdsaEntryDeep_eq' (verifyD verifyI : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (h' : verifyD = verifyI) :
    ecdsaEntryDeep verifyD sighash hasAmount = ecdsaEntry verifyI sighash hasAmount :=
  ecdsaEntryDeep_eq verifyD verifyI sighash hasAmount
    (fun a b c => by rw [h'])

/-- Pointwise `verifyD = verifyI` ⇒ `schnorrEntryDeep verifyD` IS the
production Schnorr entry `schnorrEntry verifyI` (E08 / S03 lane). -/
theorem schnorrEntryDeep_eq (verifyD verifyI : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (h : ∀ a b c, verifyD a b c = verifyI a b c) :
    schnorrEntryDeep verifyD sighashSchnorr = schnorrEntry verifyI sighashSchnorr := by
  apply checker_eq_of_entry_eq
  · intro sig pk code v d
    rfl
  · intro sig pk v d
    exact schnorrVerdict_congr verifyD verifyI sighashSchnorr sig pk v d h

/-- Function-equality form of `schnorrEntryDeep_eq`. -/
theorem schnorrEntryDeep_eq' (verifyD verifyI : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (h' : verifyD = verifyI) :
    schnorrEntryDeep verifyD sighashSchnorr = schnorrEntry verifyI sighashSchnorr :=
  schnorrEntryDeep_eq verifyD verifyI sighashSchnorr
    (fun a b c => by rw [h'])

/-- Pointwise `verifyD = verifyI` ⇒ the deep smart constructor
`txCheckerDeepOf verifyD` IS the production assembly
`txCheckerOf verifyI` (the RealChecker.lean:105 /
TxValidation/Full.lean:80 wiring level). -/
theorem txCheckerDeepOf_eq (verifyD verifyI : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (verifySchnorr : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (h : ∀ a b c, verifyD a b c = verifyI a b c) :
    txCheckerDeepOf verifyD sighash hasAmount verifySchnorr sighashSchnorr
      = txCheckerOf verifyI sighash hasAmount verifySchnorr sighashSchnorr := by
  apply checker_eq_of_entry_eq
  · intro sig pk code v d
    exact ecdsaVerdict_congr verifyD verifyI sighash hasAmount v sig pk code h
  · intro sig pk v d
    rfl

/-- Function-equality form of `txCheckerDeepOf_eq`. -/
theorem txCheckerDeepOf_eq' (verifyD verifyI : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (verifySchnorr : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (h' : verifyD = verifyI) :
    txCheckerDeepOf verifyD sighash hasAmount verifySchnorr sighashSchnorr
      = txCheckerOf verifyI sighash hasAmount verifySchnorr sighashSchnorr :=
  txCheckerDeepOf_eq verifyD verifyI sighash hasAmount verifySchnorr sighashSchnorr
    (fun a b c => by rw [h'])

/-! ## The alternate entry is a lawful seam inhabitant (W13 contracts).

Every frozen seam contract on the ECDSA entry holds for
`ecdsaEntryDeep` with an ARBITRARY deep verifier `verifyD` — by exact
transport of the W13 theorems (the deep entry is the same adapter).
These are the contracts the production wiring relies on
(RealChecker.lean's "nothing else is needed" note); none of them touches
the EC math. -/

/-- SEAM CONTRACT (ecdsaEntry_execData_independent, Seam/Entry.lean:77):
the 5th (execdata) parameter is consensus-inert for the deep entry too —
Core's `CheckECDSASignature` takes no ScriptExecutionData
(interpreter.cpp:1701-1706). -/
theorem ecdsaEntryDeep_execData_independent (verifyD : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (sig pk code : ByteArray) (v : SigVersion) (d₁ d₂ : ScriptExecutionData) :
    (ecdsaEntryDeep verifyD sighash hasAmount).checkECDSASignature sig pk code v d₁
      = (ecdsaEntryDeep verifyD sighash hasAmount).checkECDSASignature sig pk code v d₂ :=
  ecdsaEntry_execData_independent verifyD sighash hasAmount sig pk code v d₁ d₂

/-- SWT-054 transport: empty signatures fail closed before any EC math
(interpreter.cpp:1708-1709), whatever the deep verifier is. -/
theorem ecdsaEntryDeep_empty_sig_false (verifyD : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    (ecdsaEntryDeep verifyD sighash hasAmount).checkECDSASignature
      ByteArray.empty pk code v d = false :=
  ecdsaEntry_empty_sig_false verifyD sighash hasAmount pk code v d

/-- Pubkey-gate transport: an invalid pubkey header fails before the
signature is even looked at (interpreter.cpp:1703-1704). -/
theorem ecdsaEntryDeep_badPubKey_false (verifyD : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (sig pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (h : isValidPubKey pk = false) :
    (ecdsaEntryDeep verifyD sighash hasAmount).checkECDSASignature sig pk code v d = false :=
  ecdsaEntry_badPubKey_false verifyD sighash hasAmount sig pk code v d h

/-- SWT-053 transport: the hashtype byte is popped before verify — the
deep adapter hands the deep verifier EXACTLY `sig` minus its last byte,
and hashes with exactly the popped byte (interpreter.cpp:1707-1712). -/
theorem ecdsaEntryDeep_pops_hashtype (verifyD : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray) (hasAmount : Bool)
    (sig pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hpk : isValidPubKey pk = true) (hne : 0 < sig.size)
    (ham : v = SigVersion.witnessV0 → hasAmount = true) :
    (ecdsaEntryDeep verifyD sighash hasAmount).checkECDSASignature sig pk code v d
      = verifyD (sig.extract 0 (sig.size - 1)) pk (sighash code sig[sig.size - 1]! v) :=
  ecdsaEntry_pops_hashtype verifyD sighash hasAmount sig pk code v d hpk hne ham

/-- SWT-055 transport: a WITNESS_V0 sighash with missing amount data
fails closed (interpreter.cpp:1715-1716). -/
theorem ecdsaEntryDeep_witnessV0_missing_amount_false
    (verifyD : ByteArray → ByteArray → ByteArray → Bool)
    (sighash : ByteArray → UInt8 → SigVersion → ByteArray)
    (sig pk code : ByteArray) (d : ScriptExecutionData)
    (hpk : isValidPubKey pk = true) (hne : 0 < sig.size) :
    (ecdsaEntryDeep verifyD sighash false).checkECDSASignature
      sig pk code SigVersion.witnessV0 d = false :=
  ecdsaEntry_witnessV0_missing_amount_false verifyD sighash sig pk code d hpk hne

/-! ## The E11 integration slot (PROPOSED — EcdsaDeep, not this file)

This file is the landing pad; the crown wiring is deliberately NOT here
(nothing here assumes E11's existence). Once the DL suite lands
`Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct` (E11's
kernel-decidable mirror of `Bitcoin.Crypto.Ecdsa.Verify.verifyImpl`,
DECISION-lax-ecdsa.md semantics) with the mirror equality

    verifyStructEq : ∀ a b c,
      Bitcoin.Crypto.EcdsaDeep.VerifyStruct.verifyStruct a b c
        = Bitcoin.Crypto.Ecdsa.Verify.verifyImpl a b c

(funeq form `verifyStructEq' :
`VerifyStruct.verifyStruct = Ecdsa.Verify.verifyImpl` equally usable),
the alternate entry becomes the production entry by two instantiations
and nothing else:

    ecdsaEntryDeepEqProduction :=
      ecdsaEntryDeep_eq' _ _ _ _ verifyStructEq'
    txCheckerDeepOfEqProduction :=
      txCheckerDeepOf_eq' _ _ _ _ _ verifyStructEq'

— i.e. `txCheckerDeepOf VerifyStruct.verifyStruct ... = txCheckerOf
Ecdsa.Verify.verifyImpl ...` at exactly the RealChecker.lean:105 /
TxValidation/Full.lean:80 wiring level. The capstone-level assembly
(`realCheckerFullDeepOf` mirroring `RealChecker.realCheckerFullOf`) then
lands in a further NEW file of this directory (never editing
RealChecker.lean), with `realCheckerFullDeepOf_eq` proved by
`txCheckerDeepOf_eq'` + `checker_ext`. Until E11's equality is proved,
EVERY use of the deep lane is an alternate entry point only — no
production path may switch to it (D-004 quarantines the shortcut side;
this file quarantines nothing: it adds, never replaces). -/

section AxiomPins

-- E16 L3 axiom pins (D2 ladder): every public theorem of this module,
-- footprint discovered pass-1 (plain #print) and pinned guard-style.
-- Honest split: the congruence/transport laws pay the funext toll
-- ([propext, Quot.sound] — funext is Quot.sound-derived in core Lean);
-- three of the five contract transports are pure record-eta/simp
-- ([propext] only); pops_hashtype/witnessV0 transport their seam
-- theorem's funext. NO sorryAx, NO Classical.choice, NO custom axioms
-- anywhere in this module.

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.ecdsaVerdict_congr' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms ecdsaVerdict_congr

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.schnorrVerdict_congr' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms schnorrVerdict_congr

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.ecdsaEntryDeep_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms ecdsaEntryDeep_eq

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.ecdsaEntryDeep_eq'' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms ecdsaEntryDeep_eq'

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.schnorrEntryDeep_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms schnorrEntryDeep_eq

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.schnorrEntryDeep_eq'' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms schnorrEntryDeep_eq'

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.txCheckerDeepOf_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txCheckerDeepOf_eq

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.txCheckerDeepOf_eq'' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms txCheckerDeepOf_eq'

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.ecdsaEntryDeep_execData_independent' depends on axioms: [propext] -/
#guard_msgs in #print axioms ecdsaEntryDeep_execData_independent

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.ecdsaEntryDeep_empty_sig_false' depends on axioms: [propext] -/
#guard_msgs in #print axioms ecdsaEntryDeep_empty_sig_false

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.ecdsaEntryDeep_badPubKey_false' depends on axioms: [propext] -/
#guard_msgs in #print axioms ecdsaEntryDeep_badPubKey_false

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.ecdsaEntryDeep_pops_hashtype' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms ecdsaEntryDeep_pops_hashtype

/-- info: 'Bitcoin.Crypto.EcdsaDeep.Entry.ecdsaEntryDeep_witnessV0_missing_amount_false' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms ecdsaEntryDeep_witnessV0_missing_amount_false

end AxiomPins

end Bitcoin.Crypto.EcdsaDeep.Entry
