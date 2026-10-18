import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.Crypto.Seam.Hash

/-!
# Bitcoin.Crypto.Seam — FROZEN INTERFACE (primitives filled in `Seam.Hash`)

## Interface contract (do not edit outside an interface-change PR)

Core counterpart files: src/script/interpreter.h (BaseSignatureChecker,
                        ScriptExecutionData), src/script/interpreter.cpp
                        (GenericTransactionSignatureChecker:
                        CheckECDSASignature, CheckSchnorrSignature),
                        src/hash.h
Status: frozen 2026-10-16. The seam is a VERBATIM
                        port of Core's `BaseSignatureChecker` API boundary
                        (B5 finding: exactly 2 entry points + a mutable
                        ScriptExecutionData output channel), plus the 5
                        consensus-visible primitives (B5 finding).

## The seam rule (exit criterion 2)

The interpreter NEVER calls crypto directly; it calls a
`BaseSignatureChecker` value. This implementation ships ECDSA behind this seam (real
for pre-SegWit anchors if the crypto layer lands, else pre-baked verdicts); Schnorr/
Taproot verification is future work.

## Interface-change notes (sanctioned; all four are
interpreter.h/interpreter.cpp-faithfulness corrections @cce32b168)

1. `SigVersion` 3 → 4 constructors: `taproot` added. Core's enum
   (interpreter.h:201-207) is BASE / WITNESS_V0 / TAPROOT / TAPSCRIPT;
   The 3-ctor version could not even name the key-path sig version.
   Existing `.tapscript` / `.base` / `.witnessV0` references are
   unaffected (no exhaustive matches live outside this namespace).
2. `ScriptExecutionData` replaced by the verbatim 10-field port of
   interpreter.h:209-235 (`m_` prefixes dropped):
   `verificationHashtype` / `tapscriptSpend` fields were invented — the
   hashtype is not interpreter-threaded state (it is popped from the
   signature inside the checker), and "tapscriptSpend" does not exist.
3. The hash primitives `sha256` / `sha256d` / `hash160` are now real
   executable `def`s (were `opaque ... := sorry`): SHA-256 vendored from
   the prototype's PoC, RIPEMD-160 clean-room, both vector-verified (see
   `Seam/Hash.lean` provenance and `Test/Crypto/SeamHashTest.lean`).
   This removes the `sorryAx` footprints the DataLaws axiom pins
   deliberately declared (mechanical pin update in DataLaws/Interface.lean).
4. `BaseSignatureChecker` and `stubChecker` are UNCHANGED (byte-identical
   to the frozen interface): 2 entry points, `stubChecker_deterministic` stays
   pinned in the axiom manifest.
-/

namespace Bitcoin.Crypto.Seam

open Bitcoin.Data

/-! ## Consensus-visible hash primitives (B5: only these cross the seam)

Implementations live in `Bitcoin.Crypto.Seam.Hash`; here they are
exposed under the seam contract names fixed by the interface. -/

/-- SHA-256, single (FIPS 180-4 §6.2; `hash.h` CSHA256). -/
def sha256 (m : ByteArray) : ByteArray := Hash.Sha256.sha256 m

/-- SHA-256 doubled (`hash.h` CHash256). -/
def sha256d (m : ByteArray) : ByteArray := Hash.sha256d m

/-- RIPEMD-160(SHA-256(x)) (`hash.h` CHash160). -/
def hash160 (m : ByteArray) : ByteArray := Hash.hash160 m

/-- Digest-size contracts (B5): dsha256 is 32 bytes, hash160 is 20. -/
theorem sha256d_size (m : ByteArray) : (sha256d m).size = 32 := Hash.sha256d_size m

theorem hash160_size (m : ByteArray) : (hash160 m).size = 20 := Hash.hash160_size m

/-! ## ScriptExecutionData (interpreter.h:209-235, verbatim field port) -/

/-- `ScriptExecutionData` — BIP341/342's per-input output channel from the
interpreter to the signature checker. Mutable in Core (fields filled in
during `VerifyWitnessProgram` under `*execdata`); here a plain record
threaded through the checker entry points. Field order and defaults
mirror the C++ struct; the three `*Init` flags model C++'s
uninitialized-until-written fields. `[TAGFIX]` TPR-045 def-side slot:
attributes cannot attach to the `codesepPos` field itself (kernel
restriction), so the tag rides the enclosing structure — the def-side
artifact the row's notes claim (the codesepPos slot + 0xFFFFFFFF
default, interpreter.h:209-235); the last-executed-OP_CODESEPARATOR
counting semantics are NOT claimed here (tapscript-eval wiring). -/
@[rule "TPR-045"]
structure ScriptExecutionData where
  /-- Whether `tapleafHash` is initialized (`m_tapleaf_hash_init`). -/
  tapleafHashInit : Bool := false
  /-- The tapleaf hash (`m_tapleaf_hash`, TPR-012). -/
  tapleafHash : ByteArray := ByteArray.empty
  /-- Whether `codesepPos` is initialized (`m_codeseparator_pos_init`). -/
  codesepPosInit : Bool := false
  /-- Opcode position of the last executed OP_CODESEPARATOR, or 0xFFFFFFFF
  if none executed (`m_codeseparator_pos`, uint32_t). -/
  codesepPos : UInt32 := 0xFFFFFFFF
  /-- Whether `annexPresent`/`annexHash` are initialized (`m_annex_init`). -/
  annexInit : Bool := false
  /-- Whether an annex is present (`m_annex_present`, TPR-006). -/
  annexPresent : Bool := false
  /-- Hash of the annex data (`m_annex_hash`). -/
  annexHash : ByteArray := ByteArray.empty
  /-- Whether `validationWeightLeft` is initialized
  (`m_validation_weight_left_init`). -/
  validationWeightLeftInit : Bool := false
  /-- How much validation weight is left, decremented for every successful
  non-empty signature check (`m_validation_weight_left`, int64_t → `Int`). -/
  validationWeightLeft : Int := 0
  /-- Hash of the corresponding output (`m_output_hash`, BIP341
  key-path commitment extension; `std::optional` → `Option`). -/
  outputHash : Option ByteArray := none
deriving Repr, DecidableEq, BEq, Inhabited

/-- `SigVersion` (interpreter.h:201-207): the four consensus sig versions
(was 3 ctors in the frozen interface — `taproot` added, see interface-change
note 1). -/
inductive SigVersion where
  | base          -- BASE = 0: bare scripts and BIP16 P2SH-wrapped redeemscripts
  | witnessV0     -- WITNESS_V0 = 1 (P2WPKH and P2WSH); see BIP 141
  | taproot       -- TAPROOT = 2: witness v1, key path spending; see BIP 341
  | tapscript     -- TAPSCRIPT = 3: witness v1, script path, leaf 0xc0; see BIP 342
deriving Repr, DecidableEq, BEq

/-! ## BaseSignatureChecker (interpreter.h:275-299) — verbatim boundary -/

/-- Core's abstract `BaseSignatureChecker` has exactly two consensus
entry points (B5 verified; Core additionally virtualizes
CheckLockTime/CheckSequence with default-false bodies — non-crypto,
owned by the locktime comparison, deliberately not here);
everything else in script verification is the interpreter's business. We
port it as a record so the checker can run with a stub checker (pre-baked
verdicts) and the crypto layer can supply the real checker without touching
the interpreter. -/
structure BaseSignatureChecker where
  /-- `CheckECDSASignature(sig, pubKey, scriptCode, sigversion, execdata)`
  (interpreter.cpp:1701-1724): DER range checks (BIP66) happen in the
  interpreter; this entrypoint does the EC math. ECDSA-lax vs strict
  timing for pre-SegWit anchors: see DECISIONS.md OPEN-002. NOTE: Core's
  `GenericTransactionSignatureChecker::CheckECDSASignature` takes no
  ScriptExecutionData (interpreter.cpp:1701-1706 @cce32b168) — the 5th
  parameter here is consensus-inert for every faithful adapter, pinned by
  `Entry.ecdsaEntry_execData_independent`. -/
  checkECDSASignature :
    ByteArray → ByteArray → ByteArray → SigVersion → ScriptExecutionData → Bool
  /-- `CheckSchnorrSignature(sig, pubKey, sigversion, execdata)`
  (interpreter.cpp:1726-1752): BIP340, 64/65-byte sigs, 32-byte keys;
  execdata IS consumed here (TPR-072 plumbing). -/
  checkSchnorrSignature :
    ByteArray → ByteArray → SigVersion → ScriptExecutionData → Bool

/-- The stub checker the bootstrap interpreter runs with: accepts any
nonempty (sig, pubkey) pair. The checker may substitute pre-baked verdicts
via a `List ((ByteArray × ByteArray) × Bool)` table — see `Seam/Mock.lean`. -/
def stubChecker : BaseSignatureChecker :=
  { checkECDSASignature := fun sig pk _ _ _ => sig.size ≠ 0 && pk.size ≠ 0
    checkSchnorrSignature := fun sig pk _ _ => sig.size ≠ 0 && pk.size ≠ 0 }

/-! ## Frozen laws -/

/-- The stub checker is deterministic (a property the real checker must
preserve: script evaluation is a pure function of (tx, input, flags)).
Proven now — it also demonstrates the interface-file pattern of banking
already-true facts. -/
theorem stubChecker_deterministic (sig pk code : ByteArray) (v : SigVersion)
    (d₁ d₂ : ScriptExecutionData) :
    stubChecker.checkECDSASignature sig pk code v d₁
      = stubChecker.checkECDSASignature sig pk code v d₂ := by
  rfl

/-! ## Seam contract theorems (the seam layer) -/

/-- The checker record is determined by its two entry points (record eta,
definitional): the seam is EXACTLY the two-function boundary — there is
no hidden state a checker implementation could carry. -/
theorem checker_ext (c : BaseSignatureChecker) :
    { checkECDSASignature := c.checkECDSASignature
      checkSchnorrSignature := c.checkSchnorrSignature } = c := rfl

/-- Two checkers agreeing pointwise on both entry points ARE the same
checker — the interpreter cannot distinguish them (dual of `checker_ext`). -/
theorem checker_eq_of_entry_eq {c₁ c₂ : BaseSignatureChecker}
    (h₁ : ∀ sig pk code v d,
      c₁.checkECDSASignature sig pk code v d = c₂.checkECDSASignature sig pk code v d)
    (h₂ : ∀ sig pk v d,
      c₁.checkSchnorrSignature sig pk v d = c₂.checkSchnorrSignature sig pk v d) :
    c₁ = c₂ := by
  cases c₁
  cases c₂
  simp only [BaseSignatureChecker.mk.injEq]
  constructor
  · funext sig pk code v d
    exact h₁ sig pk code v d
  · funext sig pk v d
    exact h₂ sig pk v d

/-- The execdata record is determined by its ten fields (record eta,
definitional): the output channel is fully observable, so the
interpreter can construct it field-by-field and the crypto checkers can
read it field-by-field with no information lost. -/
theorem scriptExecData_ext (d : ScriptExecutionData) :
    { tapleafHashInit := d.tapleafHashInit
      tapleafHash := d.tapleafHash
      codesepPosInit := d.codesepPosInit
      codesepPos := d.codesepPos
      annexInit := d.annexInit
      annexPresent := d.annexPresent
      annexHash := d.annexHash
      validationWeightLeftInit := d.validationWeightLeftInit
      validationWeightLeft := d.validationWeightLeft
      outputHash := d.outputHash } = d := rfl

/-- The execdata channel is total: a default value exists and every
field of it is the C++ struct's field initializer
(interpreter.h:209-235). Any interpreter run can therefore start from
`default` and only overwrite the fields it fills. -/
theorem scriptExecData_default_fields :
    (default : ScriptExecutionData).tapleafHashInit = false
    ∧ (default : ScriptExecutionData).tapleafHash = ByteArray.empty
    ∧ (default : ScriptExecutionData).codesepPosInit = false
    ∧ (default : ScriptExecutionData).annexInit = false
    ∧ (default : ScriptExecutionData).annexPresent = false
    ∧ (default : ScriptExecutionData).validationWeightLeftInit = false
    ∧ (default : ScriptExecutionData).outputHash = none := by
  decide

/-! ## TPR-042 output-hash cache invariant

Core's `SignatureHashSchnorr` fills `m_output_hash` exactly once, with
`SHA256(serTxOut(vout[in_pos]))` (interpreter.cpp:1561-1566); afterwards
the cached value is read. The seam keeps the field as an unconstrained
`Option ByteArray`, so this predicate records the missing invariant:
either the cache is unset, or it already holds precisely that hash. -/

/-- TPR-042: soundness of the BIP341 single-output hash cache for a
given output — the cache is empty or is exactly `SHA256(serTxOut o)`.
This is the invariant Core establishes at interpreter.cpp:1561-1566. -/
@[rule "TPR-042"]
def outputHashSound (d : ScriptExecutionData) (o : TxOut) : Prop :=
  d.outputHash = none ∨ d.outputHash = some (sha256 (serTxOut o))

/-- TPR-042: a sound cache yields the computed hash through `getD` — the
`getD` fallback and a populated-but-sound cache agree. -/
@[rule "TPR-042"]
theorem outputHashSound_getD (d : ScriptExecutionData) (o : TxOut)
    (h : outputHashSound d o) :
    d.outputHash.getD (sha256 (serTxOut o)) = sha256 (serTxOut o) := by
  rcases h with h | h <;> simp [h]

/-- TPR-042: the default execdata cache is sound (it is unset). -/
@[rule "TPR-042"]
theorem outputHashSound_default (o : TxOut) :
    outputHashSound (default : ScriptExecutionData) o :=
  Or.inl rfl

/-- TPR-042: a populated but sound cache is exactly the computed hash. -/
@[rule "TPR-042"]
theorem outputHashSound_some (d : ScriptExecutionData) (o : TxOut)
    (h : outputHashSound d o) (hne : d.outputHash ≠ none) :
    d.outputHash = some (sha256 (serTxOut o)) := by
  rcases h with h | h
  · exact absurd h hne
  · exact h

end Bitcoin.Crypto.Seam
