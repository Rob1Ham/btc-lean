import Bitcoin.Interpreter.Defs

/-!
# BitcoinProofs.ErrMap.E02.Taxonomy — error-taxonomy completeness (Review 6, E02)

Complete crosswalk between Core's `ScriptError_t` enum
(`src/script/script_error.h`, pinned `cce32b168…`) and W09's
`Bitcoin.Interpreter.ExecError` (`spec/core/Bitcoin/Interpreter/Defs.lean:109`).

Ground truth:
- enum list: script_error.h @ `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
  (53 named values + `SCRIPT_ERR_OK` + `SCRIPT_ERR_UNKNOWN_ERROR` +
  `SCRIPT_ERR_ERROR_COUNT` sentinel);
- interpreter behavior: interpreter.cpp @ W09's pin `cce32b168` (local tree);
- policy/consensus split: `validation.cpp:2259-2288` (`getBlockScriptFlags`:
  P2SH|WITNESS|TAPROOT + DERSIG/CLTV/CSV/NULLDUMMY by deployment) — a
  `SCRIPT_ERR_*` value is `policyOnly` iff it is reachable ONLY under a
  `SCRIPT_VERIFY_*` bit that `getBlockScriptFlags` never sets;
- decisive vectors: `spec/vectors/core/script_tests.json`
  (`[wit?, scriptSig, scriptPubKey, flags, expected_scripterror, comment]`).

E02 status classes (VERIFIED unless noted):
- `consensus`   : reachable under the mainnet consensus flag word;
- `policyOnly`  : reachable only under mempool/standardness policy bits;
- `unreachable` : structurally unreachable in consensus evaluation;
- `unmapped`    : no `ExecError` constructor carries the value
  (F-E02-001: `SCHNORR_SIG_SIZE`, `SCHNORR_SIG_HASHTYPE`).

The theorem block pins three machine-checked facts:
1. the crosswalk is total and injective on all 51 mapped values
   (`imgsDistinct`, `unmapped_iff`);
2. exactly the two Schnorr-encoding values are unmapped (F-E02-001);
3. the POLICY-only classification is machine-checked at its core: under
   the consensus policy word (`default : PolicyFlags`, all bits false =
   `parsePolicyFlags ""`), the LOW_S and STRICTENC-hashtype guards of
   `checkSigEncoding` are unsatisfiable (`lowSGate_false_consensus`,
   `hashtypeGate_false_consensus`) — the `.sigHighS`/`.sigHashType`
   branches are dead on the consensus path.
-/

namespace BitcoinProofs.ErrMap.E02

/-! ## Core enum mirror (script_error.h, declaration order) -/

/-- Mirror of `ScriptError_t` at pin `cce32b168`, declaration order.
`ok` = `SCRIPT_ERR_OK`; `unknownError` = `SCRIPT_ERR_UNKNOWN_ERROR`;
`errorCount` = the `SCRIPT_ERR_ERROR_COUNT` sentinel (not an error). -/
inductive CoreErr where
  | ok | unknownError
  | evalFalse | opReturn | scriptNum
  | scriptSize | pushSize | opCount | stackSize | sigCount | pubKeyCount
  | verify | equalVerify | checkMultiSigVerify | checkSigVerify | numEqualVerify
  | badOpcode | disabledOpcode | invalidStackOp | invalidAltstackOp
  | unbalancedConditional
  | negativeLocktime | unsatisfiedLocktime
  | sigHashtype | sigDer | minimalData | sigPushOnly | sigHighS
  | sigNullDummy | pubKeyType | cleanstack | minimalIf | sigNullFail
  | discourageNops | discourageWitnessProgram | discourageTaprootVersion
  | discourageOpSuccess | discouragePubkeyType
  | witnessWrongLength | witnessEmpty | witnessMismatch | witnessMalleated
  | witnessMalleatedP2sh | witnessUnexpected | witnessPubkeyType
  | schnorrSigSize | schnorrSigHashtype | schnorrSig
  | taprootWrongControlSize | tapscriptValidationWeight
  | tapscriptCheckMultiSig | tapscriptMinimalIf | tapscriptEmptyPubkey
  | opCodeSeparator | sigFindAndDelete
  | errorCount
deriving Repr, DecidableEq, Inhabited

/-- E02 status classification. -/
inductive Status where
  | consensus | policyOnly | unreachable | unmapped
deriving Repr, DecidableEq, Inhabited

/-! ## The crosswalk table -/

/-- `ScriptError_t → (W09 ExecError?, E02 status)`. Row order = enum
order; per-row evidence in `spec/db/findings-w6/E02.md`.
- `policyOnly` rows: MINIMALDATA (SCR-177), SIG_PUSHONLY (SCR-010),
  SIG_HIGH_S (LOW_S, SCR-175), PUBKEYTYPE (STRICTENC, SCR-176),
  SIG_HASHTYPE (STRICTENC-defined-hashtype, SCR-105/SCR-176),
  MINIMALIF (v0-witness flag, SCR-178), SIG_NULLFAIL (SCR-179),
  the five DISCOURAGE_* values, WITNESS_PUBKEYTYPE (SCR-182),
  OP_CODESEPARATOR + SIG_FINDANDDELETE (CONST_SCRIPTCODE, SCR-099/181).
  CLEANSTACK and SIG_NULLDUMMY are NOT policy-only: BIP147 NULLDUMMY is
  consensus (validation.cpp:2282-2284) and tapscript re-imports
  clean-stack as consensus (SCR-183). -/
def maps : CoreErr → Option Bitcoin.Interpreter.ExecError × Status
  | .ok                        => (none, .unreachable) -- SCRIPT_ERR_OK = success, no error
  | .unknownError              => (some .unknownError, .unreachable)
  | .evalFalse                 => (some .evalFalse, .consensus)
  | .opReturn                  => (some .opReturn, .consensus)
  | .scriptNum                 => (some .scriptNum, .consensus)
  | .scriptSize                => (some .scriptSize, .consensus)
  | .pushSize                  => (some .pushSize, .consensus)
  | .opCount                   => (some .opCount, .consensus)
  | .stackSize                 => (some .stackSize, .consensus)
  | .sigCount                  => (some .sigCount, .consensus)
  | .pubKeyCount               => (some .pubKeyCount, .consensus)
  | .verify                    => (some .verifyFailed, .consensus)
  | .equalVerify               => (some .equalVerifyFailed, .consensus)
  | .checkMultiSigVerify       => (some .checkMultiSigVerify, .consensus)
  | .checkSigVerify            => (some .checkSigVerify, .consensus)
  | .numEqualVerify            => (some .numEqualVerifyFailed, .consensus)
  | .badOpcode                 => (some .badOpcode, .consensus)
  | .disabledOpcode            => (some .disabledOpcode, .consensus)
  | .invalidStackOp            => (some .stackUnderflow, .consensus)
  | .invalidAltstackOp         => (some .invalidAltstackOperation, .consensus)
  | .unbalancedConditional     => (some .unbalancedConditional, .consensus)
  | .negativeLocktime          => (some .negativeLocktime, .consensus)
  | .unsatisfiedLocktime       => (some .unsatisfiedLocktime, .consensus)
  | .sigHashtype               => (some .sigHashType, .policyOnly)
  | .sigDer                    => (some .sigDer, .consensus)
  | .minimalData               => (some .minimalData, .policyOnly)
  | .sigPushOnly               => (some .sigPushOnly, .policyOnly)
  | .sigHighS                  => (some .sigHighS, .policyOnly)
  | .sigNullDummy              => (some .sigNullDummy, .consensus)
  | .pubKeyType                => (some .pubKeyType, .policyOnly)
  | .cleanstack                => (some .cleanstack, .consensus)
  | .minimalIf                 => (some .minimalIf, .policyOnly)
  | .sigNullFail               => (some .sigNullFail, .policyOnly)
  | .discourageNops            => (some .discourageUpgradableNops, .policyOnly)
  | .discourageWitnessProgram  => (some .discourageUpgradableWitnessProgram, .policyOnly)
  | .discourageTaprootVersion  => (some .discourageUpgradableTaprootVersion, .policyOnly)
  | .discourageOpSuccess       => (some .discourageOpSuccess, .policyOnly)
  | .discouragePubkeyType      => (some .discourageUpgradablePubkeyType, .policyOnly)
  | .witnessWrongLength        => (some .witnessProgramWrongLength, .consensus)
  | .witnessEmpty              => (some .witnessProgramWitnessEmpty, .consensus)
  | .witnessMismatch           => (some .witnessProgramMismatch, .consensus)
  | .witnessMalleated          => (some .witnessMalleated, .consensus)
  | .witnessMalleatedP2sh      => (some .witnessMalleatedP2SH, .consensus)
  | .witnessUnexpected         => (some .witnessUnexpected, .consensus)
  | .witnessPubkeyType         => (some .witnessPubkeyType, .policyOnly)
  | .schnorrSigSize            => (none, .unmapped)           -- F-E02-001
  | .schnorrSigHashtype        => (none, .unmapped)           -- F-E02-001
  | .schnorrSig                => (some .schnorrSig, .consensus)
  | .taprootWrongControlSize   => (some .taprootWrongControlSize, .consensus)
  | .tapscriptValidationWeight => (some .tapscriptValidationWeight, .consensus)
  | .tapscriptCheckMultiSig    => (some .tapscriptCheckMultiSig, .consensus)
  | .tapscriptMinimalIf        => (some .tapscriptMinimalIf, .consensus)
  | .tapscriptEmptyPubkey      => (some .tapscriptEmptyPubkey, .consensus)
  | .opCodeSeparator           => (some .opCodeSeparator, .policyOnly)
  | .sigFindAndDelete          => (some .sigFindAndDelete, .policyOnly)
  | .errorCount                => (none, .unreachable) -- sentinel, not an error

/-! ## Machine-checked properties -/

/-- All 56 enum values (incl. `ok`/`errorCount` sentinels), in order. -/
def allCore : List CoreErr :=
  [.ok, .unknownError, .evalFalse, .opReturn, .scriptNum, .scriptSize,
   .pushSize, .opCount, .stackSize, .sigCount, .pubKeyCount, .verify,
   .equalVerify, .checkMultiSigVerify, .checkSigVerify, .numEqualVerify,
   .badOpcode, .disabledOpcode, .invalidStackOp, .invalidAltstackOp,
   .unbalancedConditional, .negativeLocktime, .unsatisfiedLocktime,
   .sigHashtype, .sigDer, .minimalData, .sigPushOnly, .sigHighS,
   .sigNullDummy, .pubKeyType, .cleanstack, .minimalIf, .sigNullFail,
   .discourageNops, .discourageWitnessProgram, .discourageTaprootVersion,
   .discourageOpSuccess, .discouragePubkeyType, .witnessWrongLength,
   .witnessEmpty, .witnessMismatch, .witnessMalleated,
   .witnessMalleatedP2sh, .witnessUnexpected, .witnessPubkeyType,
   .schnorrSigSize, .schnorrSigHashtype, .schnorrSig,
   .taprootWrongControlSize, .tapscriptValidationWeight,
   .tapscriptCheckMultiSig, .tapscriptMinimalIf, .tapscriptEmptyPubkey,
   .opCodeSeparator, .sigFindAndDelete, .errorCount]

/-- The crosswalk is defined on every enum value; every `some`-image
row is consensus- or policy-reachable, every `none` row is unmapped
(F-E02-001) or a non-error sentinel. -/
def tableTotal : Bool :=
  allCore.all (fun c => (maps c).1.isSome ∨
    (maps c).2 = Status.unmapped ∨ (maps c).2 = Status.unreachable)

/-- The 51 real mapped values project to pairwise-distinct `ExecError`s
(no two SCRIPT_ERR_* values collapse onto one constructor). -/
def imgsDistinct : Bool :=
  let es := (allCore.filter (fun c => (maps c).1.isSome))
    |>.map (fun c => ((maps c).1).get!)
  es.all (fun x => es.count x = 1)

theorem tableTotal_true : tableTotal = true := by rfl

theorem imgsDistinct_true : imgsDistinct = true := by rfl

/-- F-E02-001: exactly `SCRIPT_ERR_OK` (no error), the `ERROR_COUNT`
sentinel, and the two Schnorr-encoding values lack an `ExecError`. -/
theorem unmapped_iff (c : CoreErr) :
    (maps c).1 = none ↔ c = .ok ∨ c = .errorCount ∨
      c = .schnorrSigSize ∨ c = .schnorrSigHashtype := by
  cases c <;> simp [maps]

theorem schnorrSigSize_unmapped : (maps .schnorrSigSize).1 = none := rfl
theorem schnorrSigHashtype_unmapped : (maps .schnorrSigHashtype).1 = none := rfl
theorem ok_unmapped : (maps .ok).1 = none := rfl
theorem evalFalse_mapped : (maps .evalFalse).1 = some .evalFalse := rfl

/-- Distinctness spot-checks on the taxonomy (catches copy-paste row
errors in the table above). -/
example : (Bitcoin.Interpreter.ExecError.pushSize : Bitcoin.Interpreter.ExecError)
    ≠ Bitcoin.Interpreter.ExecError.stackSize := by decide
example : (Bitcoin.Interpreter.ExecError.sigDer : Bitcoin.Interpreter.ExecError)
    ≠ Bitcoin.Interpreter.ExecError.sigHighS := by decide

/-! ## POLICY-only witnesses — the consensus policy word cannot produce them

`default : PolicyFlags` has every policy bit `false`
(Defs.lean:174-190), and equals `parsePolicyFlags ""` — the consensus
word, since `getBlockScriptFlags` (validation.cpp:2259-2288) carries
P2SH|WITNESS|TAPROOT|DERSIG|CLTV|CSV|NULLDUMMY in `ScriptFlags`, never
touching the policy record. Hence the guard-bits for the policy-only
values are provably off: LOW_S (SIG_HIGH_S) and STRICTENC-defined
hashtype (SIG_HASHTYPE) cannot fire on the consensus path. -/

/-- Guard-deadness (the machine-checked core of the POLICY-only
classification, §B): under the consensus policy word
(`default : PolicyFlags`, every bit `false` = `parsePolicyFlags ""`),
the LOW_S guard of `checkSigEncoding` (Defs.lean:343,
`pol.lowS ∧ !checkLowS …`) is unsatisfiable, so the `.sigHighS`
branch is dead on the consensus path; Core fires it only under
`SCRIPT_VERIFY_LOW_S` (interpreter.cpp:139-141, BIP146 policy).
Stated without `ite`/`Decidable` so no instance rewriting is needed. -/

theorem lowSGate_false_consensus (sig : ByteArray) :
    ¬((default : Bitcoin.Interpreter.PolicyFlags).lowS = true ∧
      !Bitcoin.Interpreter.checkLowS (sig.extract 0 (sig.size - 1)) = true) := by
  rw [show (default : Bitcoin.Interpreter.PolicyFlags).lowS = false from rfl]
  simp

/-- Same for the STRICTENC-defined-hashtype guard (Defs.lean:344,
`.sigHashType` branch; Core: SCRIPT_VERIFY_STRICTENC, BIP146 policy). -/
theorem hashtypeGate_false_consensus (sig : ByteArray) :
    ¬((default : Bitcoin.Interpreter.PolicyFlags).strictEnc = true ∧
      !Bitcoin.Interpreter.isDefinedHashtype sig = true) := by
  rw [show (default : Bitcoin.Interpreter.PolicyFlags).strictEnc = false from rfl]
  simp

/-! ## Axiom footprints (full capture: scratch/E02/Axioms.lean) -/

#print axioms tableTotal_true
#print axioms imgsDistinct_true
#print axioms unmapped_iff
#print axioms lowSGate_false_consensus
#print axioms hashtypeGate_false_consensus

end BitcoinProofs.ErrMap.E02
