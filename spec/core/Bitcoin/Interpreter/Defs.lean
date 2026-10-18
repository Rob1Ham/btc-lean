import Bitcoin.Data.Basic
import Bitcoin.Data.Script
import Bitcoin.Data.Tx
import Bitcoin.Script.Parser.Defs
import Bitcoin.Numeric.Interface
import Bitcoin.Activation.Interface
import Bitcoin.Crypto.Seam.Interface
import Bitcoin.Crypto.Taproot.Verify
import Bitcoin.Interpreter.Hashes

/-!
# Bitcoin.Interpreter.Defs — the script interpreter core

A total, fuel-bounded transliteration of Core's `EvalScript` /
`VerifyScript` / `VerifyWitnessProgram` / `ExecuteWitnessScript`
(interpreter.cpp @ `cce32b168`) over the `Opcode` AST.

Ground truth and ordering: every check appears in the same order as
interpreter.cpp; the Python prototype (corpus-validated at 98.8%
against the hash-pinned `script_tests.json`) is the semantic reference.

Design notes:

* Evaluation walks a `List WireOp` — the AST annotated with the
  **wire byte** (needed by `CheckMinimalPush`, the 201-opcode budget and
  the disabled-opcode table, none of which are recoverable from the AST
  alone: `pushBytes ∅` may be OP_0 or a PUSHDATA1 of length 0) and the
  byte offset just past the opcode (OP_CODESEPARATOR's
  `pbegincodehash`). The script bytes ride along in `Ctx`.
* The stack is `List ByteArray` with the **head = top of stack**;
  `topAt st k` is Core's `stacktop(-(k+1))`.
* The 1,000-element STACK_SIZE check (and the terminal
  UNBALANCED_CONDITIONAL check) are factored OUT of the opcode dispatch:
  `stepChecked` wraps `stepBody` with the size guard, so the
  stack-bounds theorem is a two-line consequence of the guard's shape —
  no per-opcode length reasoning needed.
* Numbers are `Bitcoin.Numeric.ScriptNum := Int`. Core's int64 wrap on
  arithmetic overflow is NOT modeled (unbounded `Int`); the conformance
  corpus never exercises int64 overflow (max magnitudes are 2^31-ish),
  and the divergence window is documented in the interpreter notes.
* Hashes come from `Bitcoin.Interpreter.Hashes` (the interpreter's own
  hash floor; see that module's header for the supersession path).
* Signature checks route through `ScriptChecker` — the frozen
  `BaseSignatureChecker` seam plus the locktime environment
  (`CheckLockTime`/`CheckSequence` are virtual `BaseSignatureChecker`
  members in Core; the frozen seam deliberately excludes them, so the interpreter
  carries them as pure defs — interface-change IC-2).
* Taproot key and script paths run the real output-key commitment and
  interpreter. The optional typed Schnorr adapter distinguishes unavailable
  transaction data from an invalid signature. Only unavailable data reaches
  `VerifyOutcome.unjudged`; the production adapter supplies real BIP341/BIP340.
-/

namespace Bitcoin.Interpreter

open Bitcoin.Data Bitcoin.Script.Parser Bitcoin.Numeric Bitcoin.Activation
open Bitcoin.Crypto.Seam (BaseSignatureChecker ScriptExecutionData SigVersion stubChecker)

/-- The machine stack, head = TOP of stack.

MOVED here from the frozen `Interface.lean` (interface-change IC-1;
the name `Bitcoin.Interpreter.Stack` is unchanged). -/
abbrev Stack := List ByteArray

/-! ## Limits and constants -/

/-- MAX_SCRIPT_ELEMENT_SIZE (script.h). -/
def MAX_SCRIPT_ELEMENT_SIZE : Nat := 520
/-- MAX_SCRIPT_SIZE (interpreter.cpp; the 10,000-byte pre-parse cap). -/
def MAX_SCRIPT_SIZE : Nat := 10000
/-- MAX_OPS_PER_SCRIPT (interpreter.h). -/
def MAX_OPS_PER_SCRIPT : Nat := 201
/-- MAX_STACK_SIZE (interpreter.h); main + alt combined. -/
def MAX_STACK_SIZE : Nat := 1000
/-- MAX_PUBKEYS_PER_MULTISIG (interpreter.h). -/
def MAX_PUBKEYS_PER_MULTISIG : Nat := 20
/-- LOCKTIME_THRESHOLD (script.h): above this, nLockTime/nSequence are
timestamps. -/
def LOCKTIME_THRESHOLD : Nat := 500000000
/-- CTxIn::SEQUENCE_LOCKTIME_DISABLE_FLAG (1 << 31). -/
def SEQUENCE_LOCKTIME_DISABLE_FLAG : Nat := 0x80000000
/-- CTxIn::SEQUENCE_LOCKTIME_TYPE_FLAG (1 << 22). -/
def SEQUENCE_LOCKTIME_TYPE_FLAG : Nat := 0x00400000
/-- CTxIn::SEQUENCE_LOCKTIME_MASK (0x0000ffff). -/
def SEQUENCE_LOCKTIME_MASK : Nat := 0x0000ffff
/-- Sighash-order half of the secp256k1 group order (the LOW_S bound;
`n/2`, pubkey.h CheckLowS). -/
def SIG_S_HALF_ORDER : Nat :=
  0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0
/-- VALIDATION_WEIGHT_PER_SIGOP_PASSED (interpreter.h; BIP342). -/
def VALIDATION_WEIGHT_PER_SIGOP_PASSED : Int := 50
/-- VALIDATION_WEIGHT_OFFSET (interpreter.h; BIP342). -/
def VALIDATION_WEIGHT_OFFSET : Int := 50
/-- ANNEX_TAG (BIP341). -/
def ANNEX_TAG : Nat := 0x50
/-- TAPROOT_CONTROL_BASE_SIZE (33) / _NODE_SIZE (32) / _MAX_SIZE (33 +
32·128 = 4129) — interpreter.h:244-247 @cce32b168.

FIX (the control-size note, 2026-10-17; was `:= 65`, MAX `65 + 128 * 32` = 4161): Core's
lattice is BASE = 33 = 1 version/parity byte + 32 x-only internal-key
bytes (interpreter.cpp:1918 `subspan(1, 32)`), MAX = 33 + 32·128 = 4129
(BIP341 depth ≤ 128) — the same Core-33 fix as the Taproot/Program
lattice (commits 201e050/8a3343b, the control-size fix) and RC07's local mirrors
(Invariants/RC07.lean). The old 65/4161 reading wrongly rejected the
m=0 single-leaf control (33 bytes) and accepted m=129 (4161 bytes):
the control-size note, the offset pin, and the control-size fix. -/
def TAPROOT_CONTROL_BASE_SIZE : Nat := 33
def TAPROOT_CONTROL_NODE_SIZE : Nat := 32
def TAPROOT_CONTROL_MAX_SIZE : Nat := 33 + 128 * 32

/-! ## ExecError — the SCRIPT_ERR_* taxonomy

MOVED here from the frozen `Interface.lean` (interface-change IC-1:
the full name `Bitcoin.Interpreter.ExecError` is unchanged). The first
13 constructors are the frozen interface, in order; the rest are
extension completing the interpreter-facing subset of Core's enum
(script_error.h), appended in script_error.h-adjacent groups. -/

inductive ExecError where
  -- frozen block (order preserved)
  | badOpcode              -- SCRIPT_ERR_BAD_OPCODE
  | pushSize               -- SCRIPT_ERR_PUSH_SIZE (element > 520)
  | opCount                -- SCRIPT_ERR_OP_COUNT (201-opcode budget)
  | stackSize              -- SCRIPT_ERR_STACK_SIZE (1000-element cap)
  | scriptSize             -- SCRIPT_ERR_SCRIPT_SIZE (10,000-byte cap)
  | stackUnderflow         -- SCRIPT_ERR_INVALID_STACK_OPERATION
  | verifyFailed           -- SCRIPT_ERR_VERIFY
  | equalVerifyFailed      -- SCRIPT_ERR_EQUALVERIFY
  | disabledOpcode         -- SCRIPT_ERR_DISABLED_OPCODE (CVE-2010-5137)
  | unbalancedConditional  -- SCRIPT_ERR_UNBALANCED_CONDITIONAL
  | minimalIf              -- SCRIPT_ERR_MINIMALIF (witness v0, policy-gated)
  | cleanstack             -- SCRIPT_ERR_CLEANSTACK
  | unknownError
  -- extension (documented interface change)
  | evalFalse              -- SCRIPT_ERR_EVAL_FALSE
  | scriptNum              -- SCRIPT_ERR_SCRIPTNUM (CScriptNum ctor)
  | numEqualVerifyFailed   -- SCRIPT_ERR_NUMEQUALVERIFY
  | checkSigVerify         -- SCRIPT_ERR_CHECKSIGVERIFY
  | checkMultiSigVerify    -- SCRIPT_ERR_CHECKMULTISIGVERIFY
  | invalidAltstackOperation -- SCRIPT_ERR_INVALID_ALTSTACK_OPERATION
  | opReturn               -- SCRIPT_ERR_OP_RETURN
  | opCodeSeparator        -- SCRIPT_ERR_SIG_OP_CODESEPARATOR
  | sigFindAndDelete       -- SCRIPT_ERR_SIG_FINDANDDELETE
  | sigDer                 -- SCRIPT_ERR_SIG_DER
  | sigHighS               -- SCRIPT_ERR_SIG_HIGH_S
  | sigHashType            -- SCRIPT_ERR_SIG_HASHTYPE
  | sigNullDummy           -- SCRIPT_ERR_SIG_NULLDUMMY
  | sigNullFail            -- SCRIPT_ERR_SIG_NULLFAIL
  | sigPushOnly            -- SCRIPT_ERR_SIG_PUSHONLY
  | pubKeyType             -- SCRIPT_ERR_PUBKEYTYPE
  | pubKeyCount            -- SCRIPT_ERR_PUBKEY_COUNT
  | sigCount               -- SCRIPT_ERR_SIG_COUNT
  | negativeLocktime       -- SCRIPT_ERR_NEGATIVE_LOCKTIME
  | unsatisfiedLocktime    -- SCRIPT_ERR_UNSATISFIED_LOCKTIME
  | schnorrSig             -- SCRIPT_ERR_SCHNORR_SIG
  | schnorrSigSize         -- SCRIPT_ERR_SCHNORR_SIG_SIZE
  | schnorrSigHashtype     -- SCRIPT_ERR_SCHNORR_SIG_HASHTYPE
  | taprootDataUnavailable -- internal incomplete-adjudication signal, not a Core rejection
  | witnessProgramWrongLength -- SCRIPT_ERR_WITNESS_PROGRAM_WRONG_LENGTH
  | witnessProgramWitnessEmpty -- SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY
  | witnessProgramMismatch -- SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH
  | witnessMalleated       -- SCRIPT_ERR_WITNESS_MALLEATED
  | witnessMalleatedP2SH   -- SCRIPT_ERR_WITNESS_MALLEATED_P2SH
  | witnessUnexpected      -- SCRIPT_ERR_WITNESS_UNEXPECTED
  | witnessPubkeyType      -- SCRIPT_ERR_WITNESS_PUBKEYTYPE
  | discourageUpgradableNops -- SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS
  | discourageUpgradableWitnessProgram -- SCRIPT_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
  | discourageUpgradablePubkeyType -- SCRIPT_ERR_DISCOURAGE_UPGRADABLE_PUBKEYTYPE
  | discourageOpSuccess    -- SCRIPT_ERR_DISCOURAGE_OP_SUCCESS
  | discourageUpgradableTaprootVersion -- SCRIPT_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION
  | taprootWrongControlSize -- SCRIPT_ERR_TAPROOT_WRONG_CONTROL_SIZE
  | tapscriptValidationWeight -- SCRIPT_ERR_TAPSCRIPT_VALIDATION_WEIGHT
  | tapscriptCheckMultiSig -- SCRIPT_ERR_TAPSCRIPT_CHECKMULTISIG
  | tapscriptEmptyPubkey   -- SCRIPT_ERR_TAPSCRIPT_EMPTY_PUBKEY
  | tapscriptMinimalIf     -- SCRIPT_ERR_TAPSCRIPT_MINIMALIF
  | minimalData            -- SCRIPT_ERR_MINIMALDATA (MINIMALDATA policy)
deriving Repr, DecidableEq, BEq, Inhabited

/-! ## Policy flags

The policy-only `SCRIPT_VERIFY_*` bits the interpreter reads (Core
unifies consensus + policy in one flag word; consensus
`ScriptFlags` holds the 7 consensus bits, this record holds the rest).
`DoTest` (script_tests.cpp:120-131) is the corpus judge: it forces
`CLEANSTACK ⇒ P2SH|WITNESS` — applied by the vector Backend, not here. -/

structure PolicyFlags where
  minimalData : Bool := false                 -- MINIMALDATA
  minimalIf : Bool := false                   -- MINIMALIF
  nullFail : Bool := false                    -- NULLFAIL
  strictEnc : Bool := false                   -- STRICTENC
  constScriptCode : Bool := false             -- CONST_SCRIPTCODE
  cleanstack : Bool := false                  -- CLEANSTACK
  sigPushOnly : Bool := false                 -- SIGPUSHONLY
  lowS : Bool := false                        -- LOW_S
  witnessPubkeyType : Bool := false           -- WITNESS_PUBKEYTYPE
  discourageUpgradableNops : Bool := false    -- DISCOURAGE_UPGRADABLE_NOPS
  discourageUpgradableWitnessProgram : Bool := false -- DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
  discourageUpgradablePubkeyType : Bool := false -- DISCOURAGE_UPGRADABLE_PUBKEYTYPE
  discourageOpSuccess : Bool := false         -- DISCOURAGE_OP_SUCCESS
  discourageUpgradableTaprootVersion : Bool := false -- DISCOURAGE_UPGRADABLE_TAPROOT_VERSION
deriving Repr, DecidableEq, BEq, Inhabited

/-- Membership test for a comma-separated flag string (the corpus
`policyFlags` column, e.g. "MINIMALDATA,NULLFAIL").  Surrounding spaces
are trimmed: `codegen.py` joins policy flags with `", "`, and Core's
`script_tests.json` / `ParseScriptFlags` treats the whitespace as a
separator, so `"MINIMALIF, MINIMALDATA"` must enable both flags. -/
def polHas (s : String) (name : String) : Bool :=
  (s.splitOn ",").any (fun t => t.trimAscii.toString == name)

/-- Decode the corpus policy-flags string. -/
def parsePolicyFlags (s : String) : PolicyFlags :=
  { minimalData := polHas s "MINIMALDATA"
    minimalIf := polHas s "MINIMALIF"
    nullFail := polHas s "NULLFAIL"
    strictEnc := polHas s "STRICTENC"
    constScriptCode := polHas s "CONST_SCRIPTCODE"
    cleanstack := polHas s "CLEANSTACK"
    sigPushOnly := polHas s "SIGPUSHONLY"
    lowS := polHas s "LOW_S"
    witnessPubkeyType := polHas s "WITNESS_PUBKEYTYPE"
    discourageUpgradableNops := polHas s "DISCOURAGE_UPGRADABLE_NOPS"
    discourageUpgradableWitnessProgram := polHas s "DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM"
    discourageUpgradablePubkeyType := polHas s "DISCOURAGE_UPGRADABLE_PUBKEYTYPE"
    discourageOpSuccess := polHas s "DISCOURAGE_OP_SUCCESS"
    discourageUpgradableTaprootVersion := polHas s "DISCOURAGE_UPGRADABLE_TAPROOT_VERSION" }

/-! ## The checker: seam + locktime environment

Core's `GenericTransactionSignatureChecker` implements four virtuals the
interpreter calls: CheckECDSASignature, CheckSchnorrSignature (the two
frozen seam entry points) and CheckLockTime, CheckSequence (deliberately
not in the frozen seam — see IC-2). `ScriptChecker` pairs the seam
record with the transaction environment those last two read
(`txTo->nLockTime`, `txTo->vin[nIn].nSequence`, `txTo->nVersion`). The
corpus environment (`script_tests.cpp` DoTest's CMutableTransaction) is
version 1, nLockTime 0, nSequence 0xFFFFFFFF — the defaults. -/

structure LocktimeEnv where
  txVersion : Int32 := 1
  txLockTime : UInt32 := 0
  txSequence : UInt32 := 0xFFFFFFFF   -- CTxIn::SEQUENCE_FINAL
deriving Repr, DecidableEq, BEq, Inhabited

structure ScriptChecker where
  base : BaseSignatureChecker
  env : LocktimeEnv := default
  /-- The real adapter can preserve exact Schnorr errors and unavailable
  transaction context. `none` retains the abstract Boolean seam contract. -/
  checkSchnorrTyped : Option (ByteArray → ByteArray → SigVersion →
    ScriptExecutionData → Except ExecError Unit) := none

/-- `ScriptChecker` holds function fields, so the derivable-instances
story stops at `Inhabited` (via the seam's stub checker). -/
instance : Inhabited ScriptChecker := ⟨⟨stubChecker, default, none⟩⟩

/-- One Schnorr decision boundary shared by key-path and tapscript callers.
Only an explicit typed adapter can signal unavailable transaction context;
the legacy abstract Boolean checker retains its fail-closed interpretation. -/
def checkSchnorrWithContext (chk : ScriptChecker) (sig pk : ByteArray)
    (sv : SigVersion) (ed : ScriptExecutionData) : Except ExecError Unit :=
  match chk.checkSchnorrTyped with
  | some check => check sig pk sv ed
  | none =>
      if chk.base.checkSchnorrSignature sig pk sv ed then .ok ()
      else .error .schnorrSig

/-- `GenericTransactionSignatureChecker::CheckLockTime`
(interpreter.cpp:1755-1788), as a pure function of the environment. -/
@[rule "SCR-122", rule "SCR-123", rule "SCR-124", rule "SCR-125", rule "INV-022"]
def checkLockTimeDef (env : LocktimeEnv) (n : ScriptNum) : Bool :=
  let txlt : Int := env.txLockTime.toNat
  if !((txlt < LOCKTIME_THRESHOLD ∧ n < LOCKTIME_THRESHOLD) ∨
       (txlt ≥ LOCKTIME_THRESHOLD ∧ n ≥ LOCKTIME_THRESHOLD)) then false
  else if n > txlt then false
  else if env.txSequence.toNat = 0xFFFFFFFF then false  -- input final
  else true

/-- `GenericTransactionSignatureChecker::CheckSequence`
(interpreter.cpp:1791-1848). The operand's disable-flag NOP lives in
the CSV opcode; this is the transaction-side comparison. Core stores the
transaction version as uint32_t: compare the unsigned wire bits even when
our Int32 storage has its high bit set. -/
def checkSequenceDef (env : LocktimeEnv) (n : ScriptNum) : Bool :=
  if env.txVersion.toUInt32 < 2 then false
  else
    let txSeq := env.txSequence.toNat
    if (txSeq &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0 then false
    else
      let mask := SEQUENCE_LOCKTIME_TYPE_FLAG ||| SEQUENCE_LOCKTIME_MASK
      let txMasked := txSeq &&& mask
      let nMasked := n.toNat &&& mask   -- n ≥ 0 (caller checked)
      if !((txMasked < SEQUENCE_LOCKTIME_TYPE_FLAG ∧ nMasked < SEQUENCE_LOCKTIME_TYPE_FLAG) ∨
           (txMasked ≥ SEQUENCE_LOCKTIME_TYPE_FLAG ∧ nMasked ≥ SEQUENCE_LOCKTIME_TYPE_FLAG)) then false
      else !(nMasked > txMasked)

/-! ## Byte helpers -/

/-- In-bounds read or 0x00. All of the encoding validators index with
length-guarded offsets; `byteOr` keeps them total without panics. -/
def byteOr (b : ByteArray) (i : Nat) : UInt8 :=
  match getOpt b i with | some v => v | none => 0

/-- `vchTrue` (interpreter.cpp: `static const valtype vchTrue(1, 1)`). -/
def vchTrue : ByteArray := serU8 1
/-- `vchFalse` — the empty vector. -/
def vchFalse : ByteArray := ByteArray.empty
/-- push_bool (interpreter.cpp OP_1+boolean sites): 0x01 / empty. -/
def pushBoolV (v : Bool) : ByteArray := if v then vchTrue else vchFalse

/-! ## Signature / pubkey encoding validators
(CheckSignatureEncoding interpreter.cpp:120-160, CheckPubKeyEncoding
interpreter.cpp:225-234, IsValidSignatureEncoding script.cpp,
IsCompressedOrUncompressedPubKey interpreter.cpp:74, CheckLowS
pubkey.h — DER-level S ≤ n/2 formulation, corpus-validated.) -/

/-- `IsValidSignatureEncoding` (BIP66, script.cpp:169-211). -/
@[rule "SCR-102"]
def isValidSigEncoding (sig : ByteArray) : Bool :=
  if sig.size < 9 ∨ 73 < sig.size then false
  else if byteOr sig 0 ≠ 0x30 then false
  else if (byteOr sig 1).toNat ≠ sig.size - 3 then false
  else
    let lenR := (byteOr sig 3).toNat
    if 5 + lenR ≥ sig.size then false
    else
      let lenS := (byteOr sig (5 + lenR)).toNat
      if lenR + lenS + 7 ≠ sig.size then false
      else if byteOr sig 2 ≠ 0x02 then false
      else if lenR = 0 then false
      else if (byteOr sig 4) &&& 0x80 ≠ 0 then false
      else if lenR > 1 ∧ byteOr sig 4 = 0 ∧ (byteOr sig 5) &&& 0x80 = 0 then false
      else if byteOr sig (lenR + 4) ≠ 0x02 then false
      else if lenS = 0 then false
      else if (byteOr sig (lenR + 6)) &&& 0x80 ≠ 0 then false
      else if lenS > 1 ∧ byteOr sig (lenR + 6) = 0 ∧ (byteOr sig (lenR + 7)) &&& 0x80 = 0 then false
      else true

/-- `IsDefinedHashtype` (interpreter.cpp:162-167): SIGHASH range
1..3 after masking out ANYONECANPAY. -/
@[rule "SCR-105"]
def isDefinedHashtype (sig : ByteArray) : Bool :=
  if sig.size = 0 then false
  else
    let n := (byteOr sig (sig.size - 1)).toNat &&& 0x7f
    1 ≤ n ∧ n ≤ 3

/-- `CPubKey::CheckLowS` — the DER-level form: S parses (lax) and
S ≤ n/2. Takes the signature WITHOUT the hashtype byte; the validity
pre-check appends a dummy hashtype to reuse `isValidSigEncoding`'s
@[rule "SCR-104"]
structural walk (the corpus-validated formulation). -/
@[rule "INV-053"]
def checkLowS (sigNoHT : ByteArray) : Bool :=
  if !isValidSigEncoding (sigNoHT.push 0x01) then false
  else
    let lenR := (byteOr sigNoHT 3).toNat
    let lenS := (byteOr sigNoHT (5 + lenR)).toNat
    let sval := (List.range lenS).foldl
      (fun acc j => acc * 256 + (byteOr sigNoHT (6 + lenR + j)).toNat) 0
    sval ≤ SIG_S_HALF_ORDER

/-- `CheckSignatureEncoding` (interpreter.cpp:120-160) as an
`Option ExecError` (none = pass). SWT-058: the LOW_S branch
(`pol.lowS ∧ !checkLowS …`) reads the POLICY word only — consensus
`ScriptFlags` carries no LOW_S bit (BIP146, policy). SWT-060: the
defined-hashtype check rides `pol.strictEnc`, likewise policy-only
(BIP146 STRICTENC). The consensus-path consequence (default policy ⇒ the
check reduces to the DERSIG gate) is pinned in
BitcoinProofs.Theorems.WitnessRulesCor. -/
@[rule "SCR-108", rule "SWT-058", rule "SWT-060"]
def checkSigEncoding (flags : ScriptFlags) (pol : PolicyFlags) (sig : ByteArray) :
    Option ExecError :=
  if sig.size = 0 then none
  else if (flags.dersig ∨ pol.lowS ∨ pol.strictEnc) ∧ !isValidSigEncoding sig then some .sigDer
  else if pol.lowS ∧ !checkLowS (sig.extract 0 (sig.size - 1)) then some .sigHighS
  else if pol.strictEnc ∧ !isDefinedHashtype sig then some .sigHashType
  else none

/-- `IsCompressedOrUncompressedPubKey` (interpreter.cpp:74-92). -/
def isCompressedOrUncompressedPubKey (pk : ByteArray) : Bool :=
  if pk.size < 33 then false
  else if byteOr pk 0 = 0x04 then pk.size = 65
  else if byteOr pk 0 = 0x02 ∨ byteOr pk 0 = 0x03 then pk.size = 33
  else false

/-- `IsCompressedPubKey` (interpreter.cpp:94-99). -/
def isCompressedPubKey (pk : ByteArray) : Bool :=
  pk.size = 33 ∧ (byteOr pk 0 = 0x02 ∨ byteOr pk 0 = 0x03)

/-- `CheckPubKeyEncoding` (interpreter.cpp:225-234). `flags` is kept in
the signature for Core-shape parity (Core reads STRICTENC there; the
policy word carries it here). SWT-056: the WITNESS_PUBKEYTYPE
compressed-only restriction is a POLICY bit (`pol.witnessPubkeyType`),
never a consensus `ScriptFlags` field (interpreter.cpp:228-236). -/
@[rule "SCR-106", rule "SCR-107", rule "SWT-056", rule "INV-054"]
def checkPubKeyEncoding (_flags : ScriptFlags) (pol : PolicyFlags) (sv : SigVersion)
    (pk : ByteArray) : Option ExecError :=
  if pol.strictEnc ∧ !isCompressedOrUncompressedPubKey pk then some .pubKeyType
  else if pol.witnessPubkeyType ∧ sv = .witnessV0 ∧ !isCompressedPubKey pk then
    some .witnessPubkeyType
  else none

/-! ## The wire-op layer -/

/-- An AST opcode annotated with the data the interpreter needs and the
AST does not carry: the **wire byte** (`CheckMinimalPush`, the op
budget, the disabled table — all keyed on the wire encoding) and the
byte offset just past this opcode (OP_CODESEPARATOR's
`pbegincodehash`). -/
structure WireOp where
  ast : Opcode
  wire : Nat
  next : Nat
deriving Repr, DecidableEq, BEq

/-- Walk the raw script into wire ops (`GetOp` order; fuel
`b.size + 1` always suffices). `none` = malformed (truncated push) —
EvalScript's mid-script `GetOp` failure → BAD_OPCODE. -/
def parseWireFrom : Nat → ByteArray → Nat → Option (List WireOp)
  | 0, _, _ => none
  | f+1, b, i =>
    if b.size ≤ i then some []
    else match getOp b i with
      | none => none
      | some (o, i') => (parseWireFrom f b i').map
          (fun tl => { ast := o, wire := b[i]!.toNat, next := i' } :: tl)

/-- `parseWireFrom` with the canonical fuel. -/
def parseWire (b : ByteArray) : Option (List WireOp) := parseWireFrom (b.size + 1) b 0

/-- The wire byte of a canonical encoding (`evalScript`'s AST entry). -/
def wireOfAst (o : Opcode) : Nat :=
  match o with
  | .pushBytes d =>
      if d.size = 0 then 0
      else if d.size ≤ 75 then d.size
      else if d.size ≤ 0xff then 0x4c
      else if d.size ≤ 0xffff then 0x4d else 0x4e
  | .pushNum n => if n = 0 then 0x4f else 0x50 + n
  | .op c => c.toNat

/-- AST → wire ops at canonical offsets (`serializeOpcodes` layout). -/
def wireOpsFrom (off : Nat) : List Opcode → List WireOp
  | [] => []
  | o :: tl =>
      let sz := (serializeOpcode o).size
      { ast := o, wire := wireOfAst o, next := off + sz } :: wireOpsFrom (off + sz) tl

/-- The disabled-opcode wire set (interpreter.cpp:447-467; verified
against script.h's opcode table @master — note OP_RSHIFT is 0x99, cf.
the `isDisabled` discrepancy documented in the interpreter notes). -/
@[rule "SCR-152", rule "INV-063"]
def disabledWire (w : Nat) : Bool :=
  w ∈ [0x7e, 0x7f, 0x80, 0x81, 0x83, 0x84, 0x85, 0x86,
       0x8d, 0x8e, 0x95, 0x96, 0x97, 0x98, 0x99]

/-- `IsOpSuccess` (script.cpp:365-371, BIP342). `[TAGFIX]` TPR-060:
the OP_SUCCESSx set; side pins in Tapscript.Delta (checksigadd_not_
success, disabledWire_success = TPR-074). -/
@[rule "TPR-060"]
def isOpSuccessWire (w : Nat) : Bool :=
  w = 80 ∨ w = 98 ∨ (126 ≤ w ∧ w ≤ 129) ∨ (131 ≤ w ∧ w ≤ 134) ∨
  (137 ≤ w ∧ w ≤ 138) ∨ (141 ≤ w ∧ w ≤ 142) ∨ (149 ≤ w ∧ w ≤ 153) ∨
  (187 ≤ w ∧ w ≤ 254)

/-- The OP_SUCCESSx pre-pass over RAW tapscript bytes
(`ExecuteWitnessScript`'s GetOp loop, interpreter.cpp:1846-1862): opcodes
are decoded one by one, and the walk returns `true` the moment an
OP_SUCCESSx is decoded. Decode failures are ordered WITH the scan — a
SUCCESSx before a truncated push still succeeds, a truncated push before
any SUCCESSx is BAD_OPCODE (BIP342 §Spec step 2: "This is true even if
later bytes in the tapscript would fail to decode otherwise"). The all
or-nothing `parseWire` CANNOT model this ordering (the interpreter delta layer fix: the
pre-pass keyed `ops.any` off a full parse). Push-shaped decodes
never carry a success wire byte (the success set is ≥ 80 and push wires
are ≤ 0x60), so only `.op` payloads are tested. -/
def opSuccessScanFrom : Nat → ByteArray → Nat → Bool
  | 0, _, _ => false
  | f+1, b, i =>
    if b.size ≤ i then false
    else match getOp b i with
      | none => false
      | some (o, i') =>
        match o with
        | .op c => if isOpSuccessWire c.toNat then true else opSuccessScanFrom f b i'
        | _ => opSuccessScanFrom f b i'

/-- `opSuccessScanFrom` at the canonical fuel (`b.size + 1` suffices:
each step advances `i` past one opcode). -/
def opSuccessScan (b : ByteArray) : Bool := opSuccessScanFrom (b.size + 1) b 0

/-- `CScript::IsPushOnly` at the wire level: every opcode ≤ OP_16. -/
@[rule "SCR-052"]
def isPushOnlyWire (ops : List WireOp) : Bool := ops.all (fun o => o.wire ≤ 0x60)

/-- `CScript::IsPayToScriptHash` (script.h). -/
def isPayToScriptHash (b : ByteArray) : Bool :=
  b.size = 23 ∧ (b.get! 0).toNat = 0xa9 ∧ (b.get! 1).toNat = 0x14 ∧
    (b.get! 22).toNat = 0x87

/-- `CScript::IsWitnessProgram` (script.h): version byte ∈ {OP_0,
OP_1..OP_16}, length byte + 2 = script size. Returns (version, program).
SWT-001: the witness-program template (4..42 bytes, direct push of
2..40 bytes, `len + 2 = size`). SWT-002: the version decoding
(OP_0→0, OP_1..OP_16→1..16). -/
@[rule "SCR-053", rule "SCR-054", rule "SCR-055",
  rule "SWT-001", rule "SWT-002"]
def isWitnessProgram (b : ByteArray) : Option (Nat × ByteArray) :=
  if 4 ≤ b.size ∧ b.size ≤ 42 then
    let v := (b.get! 0).toNat
    if v = 0 ∨ (0x51 ≤ v ∧ v ≤ 0x60) then
      let plen := (b.get! 1).toNat
      if plen + 2 = b.size then
        some (if v = 0 then 0 else v - 0x50, b.extract 2 b.size)
      else none
    else none
  else none

/-- `CScript::IsPayToAnchor` (script.h, BIP345 P2A): witness v1,
program 0x4e73. -/
def isPayToAnchor (version : Nat) (program : ByteArray) : Bool :=
  version = 1 ∧ program.size = 2 ∧ (program.get! 0).toNat = 0x4e ∧
    (program.get! 1).toNat = 0x73

/-- `CheckMinimalPush` (script.cpp:373-396). -/
@[rule "INV-046"]
def checkMinimalPush (data : ByteArray) (opcode : Nat) : Bool :=
  if data.size = 0 then opcode = 0
  else if data.size = 1 ∧ 1 ≤ (data.get! 0).toNat ∧ (data.get! 0).toNat ≤ 16 then false
  else if data.size = 1 ∧ (data.get! 0).toNat = 0x81 then false
  else if data.size ≤ 75 then opcode = data.size
  else if data.size ≤ 0xff then opcode = 0x4c
  else if data.size ≤ 0xffff then opcode = 0x4d
  else true

/-! ## FindAndDelete (interpreter.cpp:239-265)

Byte-level, walking opcode boundaries with `getOp`; returns
(nFound, newScript). Mirrors the do-while loop exactly (including the
trailing `[pc2, end)` tail copy when `nFound > 0`). -/

/-- Greedy run of `b`-matches starting at `pc`: returns (newPc, count). -/
def findAndDeleteMatches (script b : ByteArray) (pc n fuel : Nat) : Nat × Nat :=
  if fuel = 0 then (pc, n)
  else if script.size < pc + b.size then (pc, n)
  else if script.extract pc (pc + b.size) == b then
    findAndDeleteMatches script b (pc + b.size) (n + 1) (fuel - 1)
  else (pc, n)

def findAndDeleteAux (script b : ByteArray) :
    Nat → Nat → Nat → ByteArray → Nat → Nat × ByteArray
  | 0, _, _, acc, found => (found, acc)
  | fuel+1, pc, pc2, acc, found =>
      -- copy bytes skipped since the last iteration, then greedy-match
      let acc1 := acc ++ script.extract pc2 pc
      let (pc', n') := findAndDeleteMatches script b pc 0 (script.size + 1)
      let found' := found + n'
      if script.size ≤ pc' then (found', acc1)
      else match getOp script pc' with
        | none => (found', acc1)   -- truncated tail: loop exits (Core GetOp failure)
        | some (_, next) => findAndDeleteAux script b fuel next pc' acc1 found'

/-- The `pc2` left by the final loop iteration — recomputed by a second
walk (kept simple; FindAndDelete only runs on small scripts). This is the
**post-match** position: Core assigns `pc2 = pc` after the greedy match
loop and before the `GetOp` loop test (interpreter.cpp:239-265), so the
final tail copy starts there. The base case returns the last post-match
position, matching the value `pc2` had when the walk stopped. -/
def fdLastPc2 (script b : ByteArray) : Nat → Nat → Nat → Nat
  | 0, _, pc2 => pc2
  | fuel+1, pc, pc2 =>
      let (pc', _) := findAndDeleteMatches script b pc 0 (script.size + 1)
      if script.size ≤ pc' then pc'
      else match getOp script pc' with
        | none => pc'
        | some (_, next) => fdLastPc2 script b fuel next pc'

/-- `FindAndDelete(script, b)` — deletes every opcode-boundary
occurrence of `b` from `script`. -/
@[rule "SCR-098", rule "INV-056"]
def findAndDelete (script b : ByteArray) : Nat × ByteArray :=
  if b.size = 0 then (0, script)
  else
    let (found, acc) := findAndDeleteAux script b (script.size + 1) 0 0 ByteArray.empty 0
    if 0 < found then (found, acc ++ script.extract (fdLastPc2 script b (script.size + 1) 0 0) script.size)
      else (found, script)

/-! ## Machine state and context -/

/-- Machine state (`EvalScript`'s locals). `vf` head = innermost
condition (`vfExec.back()`); `alt` head = altstack top; `codeSep` is
the byte offset of `pbegincodehash`; `vwLeft` carries BIP342's
validation-weight budget (initialized only on the tapscript path). -/
structure State where
  stack : Stack
  alt : Stack
  vf : List Bool
  opCount : Nat
  codeSep : Nat
  vwLeft : Option Int
  opcodeIndex : UInt32 := 0
  codeSepPos : UInt32 := 0xffffffff
deriving Repr, DecidableEq, BEq, Inhabited

/-- Everything an opcode step reads except the state itself. -/
structure Ctx where
  flags : ScriptFlags
  pol : PolicyFlags
  chk : ScriptChecker
  sv : SigVersion
  bytes : ByteArray            -- the script being executed
  ed : ScriptExecutionData     -- passed through to the checker

/-- BIP342 signs the last executed separator's opcode index, while the
legacy scriptCode path keeps its independent byte offset. -/
def signatureExecutionData (ctx : Ctx) (st : State) : ScriptExecutionData :=
  if ctx.sv = .tapscript then
    { ctx.ed with codesepPosInit := true, codesepPos := st.codeSepPos }
  else ctx.ed

/-- `stacktop(-k)` for k ≥ 1 (head-of-list = top-of-stack). -/
def topAt (st : Stack) (k : Nat) : ByteArray := st[k-1]!

/-- CScriptNum decode with the interpreter's error mapping
(`scriptnum_error` → SCRIPT_ERR_SCRIPTNUM). -/
@[rule "SCR-050", rule "SCR-051", rule "SCR-157", rule "INV-058"]
def decodeNum (pol : PolicyFlags) (b : ByteArray) (maxSize : Nat) :
    Except ExecError ScriptNum :=
  match decodeScriptNum b pol.minimalData maxSize with
  | some n => .ok n
  | none => .error .scriptNum

/-- The five hash opcodes (0xa6-0xaa) over the interpreter hash floor. -/
@[rule "SCR-093", rule "SCR-094", rule "SCR-095"]
def hashForOp (w : Nat) (d : ByteArray) : ByteArray :=
  match w with
  | 0xa6 => hashRipemd160 d
  | 0xa7 => hashSha1 d
  | 0xa8 => hashSha256 d
  | 0xa9 => hashHash160 d
  | _    => hashSha256d d

/-- Unary arithmetic dispatch (0x8b, 0x8c, 0x8f, 0x90, 0x91, 0x92). -/
def unOp (w : Nat) (bn : ScriptNum) : ScriptNum :=
  match w with
  | 0x8b => bn + 1
  | 0x8c => bn - 1
  | 0x8f => -bn
  | 0x90 => Int.ofNat bn.natAbs
  | 0x91 => if bn = 0 then 1 else 0
  | _    => if bn = 0 then 0 else 1   -- 0x92 OP_0NOTEQUAL

/-- Binary arithmetic dispatch (0x93, 0x94, 0x9a-0xa4). -/
def binOp (w : Nat) (bn1 bn2 : ScriptNum) : ScriptNum :=
  match w with
  | 0x93 => bn1 + bn2
  | 0x94 => bn1 - bn2
  | 0x9a => if bn1 ≠ 0 ∧ bn2 ≠ 0 then 1 else 0
  | 0x9b => if bn1 ≠ 0 ∨ bn2 ≠ 0 then 1 else 0
  | 0x9c => if bn1 = bn2 then 1 else 0
  | 0x9d => if bn1 = bn2 then 1 else 0
  | 0x9e => if bn1 ≠ bn2 then 1 else 0
  | 0x9f => if bn1 < bn2 then 1 else 0
  | 0xa0 => if bn1 > bn2 then 1 else 0
  | 0xa1 => if bn1 ≤ bn2 then 1 else 0
  | 0xa2 => if bn1 ≥ bn2 then 1 else 0
  | 0xa3 => if bn1 ≤ bn2 then bn1 else bn2
  | _    => if bn1 ≥ bn2 then bn1 else bn2   -- 0xa4 OP_MAX

/-- The OP_CHECKMULTISIG verification loop
(interpreter.cpp:1187-1210): returns `fSuccess`. -/
@[rule "SCR-026", rule "SCR-027", rule "SCR-028", rule "SCR-032", rule "SCR-114", rule "SCR-116", rule "SCR-117"]
def cmsLoop (flags : ScriptFlags) (pol : PolicyFlags) (sv : SigVersion)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (scriptCode : ByteArray)
    (st : Stack) (fuel nKeys nSigs isig ikey : Nat) : Except ExecError Bool :=
  if nSigs = 0 then .ok true
  else match fuel with
    | 0 => .ok false   -- unreachable: each iteration consumes a signature
    | f+1 =>
      let sig := st[isig-1]!
      let pk := st[ikey-1]!
      match checkSigEncoding flags pol sig, checkPubKeyEncoding flags pol sv pk with
      | some e, _ => .error e
      | _, some e => .error e
      | none, none =>
        let fOk := chk.base.checkECDSASignature sig pk scriptCode sv ed
        let isig' := if fOk then isig + 1 else isig
        let nSigs' := if fOk then nSigs - 1 else nSigs
        let ikey' := ikey + 1
        let nKeys' := nKeys - 1
        if nSigs' > nKeys' then .ok false
        else cmsLoop flags pol sv chk ed scriptCode st f nKeys' nSigs' isig' ikey'

/-- The CMS argument-cleanup pop loop (interpreter.cpp:1212-1221) with
the NULLFAIL check; pops `i - 1` items. SWT-059: the NULLFAIL gate is
`pol.nullFail` — the POLICY word (BIP146; consensus `ScriptFlags` has no
NULLFAIL bit, so block validation with the consensus-default policy
never raises sigNullFail). -/
@[rule "SWT-059", rule "INV-051"]
def cmsCleanup (pol : PolicyFlags) (st : Stack) (fSuccess : Bool)
    (i ikey2 fuel : Nat) : Except ExecError Stack :=
  if i ≤ 1 then .ok st
  else match fuel with
    | 0 => .ok st   -- unreachable
    | f+1 =>
      if !fSuccess ∧ pol.nullFail ∧ ikey2 = 0 ∧ st[0]!.size ≠ 0 then .error .sigNullFail
      else
        let ikey2' := if 0 < ikey2 then ikey2 - 1 else ikey2
        cmsCleanup pol st.tail fSuccess (i - 1) ikey2' f

/-- `EvalChecksigPreTapscript` (interpreter.cpp:328-368): returns
`fSuccess` or an error. SWT-048: the scriptCode is the executed script
from the last OP_CODESEPARATOR onward (`extract codeSep`). SWT-049:
FindAndDelete applies only for SigVersion::BASE (BIP143 §No
FindAndDelete — v0 keeps the signature in the scriptCode). -/
@[rule "SCR-099", rule "SCR-100", rule "SCR-110", rule "SCR-112", rule "SCR-139",
  rule "SWT-048", rule "SWT-049", rule "INV-051"]
def evalChecksigPreTapscript (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (sv : SigVersion)
    (codeSep : Nat) (bytes : ByteArray) (sig pk : ByteArray) :
    Except ExecError Bool :=
  let scriptCode0 := bytes.extract codeSep bytes.size
  let sc : Except ExecError ByteArray :=
    if sv = .base then
      let (found, sc') := findAndDelete scriptCode0 (pushBytesWire sig)
      if 0 < found ∧ pol.constScriptCode then .error .sigFindAndDelete else .ok sc'
    else .ok scriptCode0
  match sc with
  | .error e => .error e
  | .ok scriptCode =>
    match checkSigEncoding flags pol sig, checkPubKeyEncoding flags pol sv pk with
    | some e, _ => .error e
    | _, some e => .error e
    | none, none =>
      let fSuccess := chk.base.checkECDSASignature sig pk scriptCode sv ed
      if !fSuccess ∧ pol.nullFail ∧ sig.size ≠ 0 then .error .sigNullFail
      else .ok fSuccess

/-- `EvalChecksigTapscript` (interpreter.cpp:370-410). `vw` threads
BIP342's validation-weight budget (Core decrements
`execdata.m_validation_weight_left` in place; here the budget rides the
machine state, initialized from `ScriptExecutionData` by `evalScriptBytes`
on the tapscript path). Consensus-critical validation sequence per the
Core comment: budget check precedes the pubkey rules; a non-empty INVALID
signature fails the script (`SCRIPT_ERR_SCHNORR_SIG` — the BIP342
"Validation failure in this case immediately terminates script execution
with failure"; NULLFAIL baked in as consensus, not flag-gated). The interpreter delta layer
fix: an earlier draft returned `.ok (ok && success, …)`, which pushed `false`
and continued on a failed 32-byte-key verification — legacy CHECKSIG
semantics, NOT tapscript. (Tags restored by the sigop model after the interpreter delta layer's rewrite
dropped the docstring-embedded attributes: SCR-121 tapscript-CMS ban via
the `.tapscriptCheckMultiSig` path in `stepBody`, SCR-159/160 the
empty-pubkey / empty-sig sequence below.) -/
@[rule "SCR-121", rule "SCR-159", rule "SCR-160", rule "SCR-041", rule "SCR-042", rule "SCR-158", rule "SCR-168", rule "TPR-027"]
def evalChecksigTapscript (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (sig pk : ByteArray) (vw : Option Int) :
    Except ExecError (Bool × Option Int) :=
  let success := sig.size ≠ 0
  if success then
    let vw' := (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED
    if vw' < 0 then .error .tapscriptValidationWeight
    else if pk.size = 0 then .error .tapscriptEmptyPubkey
    else if pk.size = 32 then
      match checkSchnorrWithContext chk sig pk .tapscript ed with
      | .error e => .error e
      | .ok () => .ok (true, some vw')
    else if pol.discourageUpgradablePubkeyType then .error .discourageUpgradablePubkeyType
    else .ok (success, some vw')
  else
    if pk.size = 0 then .error .tapscriptEmptyPubkey
    else if pk.size = 32 then .ok (false, vw)
    else if pol.discourageUpgradablePubkeyType then .error .discourageUpgradablePubkeyType
    else .ok (false, vw)

/-- `EvalChecksig` (interpreter.cpp:402-415): the SigVersion mode
dispatch for the signature opcodes — BASE/WITNESS_V0 →
`EvalChecksigPreTapscript` (ECDSA, encoding validators, FindAndDelete),
TAPSCRIPT → `EvalChecksigTapscript` (Schnorr-only, budget,
empty-sig-false); TAPROOT is unreachable (key-path spending executes no
script). The `vw` slot threads the validation-weight budget; the
pre-tapscript arm passes it through untouched. -/
def evalChecksigDispatch (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (ed : ScriptExecutionData) (sv : SigVersion)
    (codeSep : Nat) (bytes : ByteArray) (sig pk : ByteArray)
    (vw : Option Int) : Except ExecError (Bool × Option Int) :=
  if sv = .base ∨ sv = .witnessV0 then
    match evalChecksigPreTapscript flags pol chk ed sv codeSep bytes sig pk with
    | .error e => .error e
    | .ok b => .ok (b, vw)
  else if sv = .tapscript then
    evalChecksigTapscript pol chk ed sig pk vw
  else .error .badOpcode

/-- OP_CHECKSIGADD's stack arithmetic (interpreter.cpp:1103-1112): the
`num` operand decodes FIRST (4-byte `CScriptNum` ctor bound — BIP342:
"If n is larger than 4 bytes, the script MUST fail"; minimal-encoding via
the policy word exactly as for OP_ADD: BIP342 "All CScriptNum-related
behaviours of OP_ADD are also applicable to OP_CHECKSIGADD"), then
`EvalChecksig` runs; the result is `n + (success ? 1 : 0)`. -/
@[rule "INV-060"]
def checksigAddStep (pol : PolicyFlags) (chk : ScriptChecker)
    (ed : ScriptExecutionData) (sig num pk : ByteArray) (vw : Option Int) :
    Except ExecError (ScriptNum × Option Int) :=
  match decodeNum pol num 4 with
  | .error e => .error e
  | .ok n =>
    match evalChecksigTapscript pol chk ed sig pk vw with
    | .error e => .error e
    | .ok (success, vw') => .ok (n + (if success then 1 else 0), vw')

/-- One opcode transition, `stepBody`: everything except the terminal
STACK_SIZE guard (`stepChecked` wraps this). Check order mirrors
interpreter.cpp:423-570 exactly. -/
@[rule "SCR-046", rule "SCR-062", rule "SCR-064", rule "SCR-078", rule "SCR-156", rule "INV-042", rule "INV-043", rule "INV-045", rule "TPR-068"]
def stepBody (ctx : Ctx) (op : WireOp) (st : State) : Except ExecError State :=
  let w := op.wire
  -- (1) element size limit — right after GetOp, executed or not
  let sizeOk : Bool :=
    match op.ast with
    | .pushBytes d => d.size ≤ MAX_SCRIPT_ELEMENT_SIZE
    | _ => true
  if !sizeOk then .error .pushSize
  else
  -- (2) opcode budget (interpreter.cpp:459-463)
  let counts := (ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧ 0x60 < w
  let opCount' := if counts then st.opCount + 1 else st.opCount
  if counts ∧ MAX_OPS_PER_SCRIPT < opCount' then .error .opCount
  -- (3) disabled opcodes (CVE-2010-5137) — unexecuted branches included
  else if disabledWire w then .error .disabledOpcode
  -- (4) OP_CODESEPARATOR under CONST_SCRIPTCODE in non-segwit script
  else if w = 0xab ∧ ctx.sv = .base ∧ ctx.pol.constScriptCode then .error .opCodeSeparator
  else
    let fExec := st.vf.all id
    let st₁ := { st with opCount := opCount' }
    match op.ast with
    | .pushBytes d =>
        -- pushes are outside the 0x63-0x68 window: unexecuted ⇒ skip
        if !fExec then .ok st₁
        else if ctx.pol.minimalData ∧ !checkMinimalPush d w then .error .minimalData
        else .ok { st₁ with stack := d :: st.stack }
    | .pushNum n =>
        if !fExec then .ok st₁
        else .ok { st₁ with stack := encodeScriptNum (if n = 0 then (-1 : ScriptNum) else (n : ScriptNum)) false :: st.stack }
    | .op _ =>
        if !(fExec ∨ (0x63 ≤ w ∧ w ≤ 0x68)) then .ok st₁
        else dispatchOp ctx op w fExec st₁
where

  /-- The opcode dispatch (Core's `switch (opcode)`). -/
  dispatchOp (ctx : Ctx) (op : WireOp) (w : Nat) (fExec : Bool) (st : State) :
      Except ExecError State :=
    let flags := ctx.flags
    let pol := ctx.pol
    if w = 0x61 then .ok st                                 -- OP_NOP
    else if w = 0xb1 then                                   -- OP_CHECKLOCKTIMEVERIFY
      if !flags.cltv then .ok st
      else if st.stack.length < 1 then .error .stackUnderflow
      else match decodeNum pol (topAt st.stack 1) 5 with
        | .error e => .error e
        | .ok n =>
          if n < 0 then .error .negativeLocktime
          else if !checkLockTimeDef ctx.chk.env n then .error .unsatisfiedLocktime
          else .ok st
    else if w = 0xb2 then                                   -- OP_CHECKSEQUENCEVERIFY
      if !flags.csv then .ok st
      else if st.stack.length < 1 then .error .stackUnderflow
      else match decodeNum pol (topAt st.stack 1) 5 with
        | .error e => .error e
        | .ok n =>
          if n < 0 then .error .negativeLocktime
          else if (n.toNat &&& SEQUENCE_LOCKTIME_DISABLE_FLAG) ≠ 0 then .ok st
          else if !checkSequenceDef ctx.chk.env n then .error .unsatisfiedLocktime
          else .ok st
    else if w = 0xb0 ∨ (0xb3 ≤ w ∧ w ≤ 0xb9) then           -- OP_NOP1/4-10
      if pol.discourageUpgradableNops then .error .discourageUpgradableNops else .ok st
    else if w = 0x63 ∨ w = 0x64 then                        -- OP_IF / OP_NOTIF
      if fExec then
        if st.stack.length < 1 then .error .stackUnderflow
        else
          let vch := topAt st.stack 1
          if ctx.sv = .tapscript ∧ (1 < vch.size ∨ (vch.size = 1 ∧ (byteOr vch 0).toNat ≠ 1)) then
            .error .tapscriptMinimalIf
          else if ctx.sv = .witnessV0 ∧ pol.minimalIf ∧
              (1 < vch.size ∨ (vch.size = 1 ∧ (byteOr vch 0).toNat ≠ 1)) then
            .error .minimalIf
          else
            let fValue := if w = 0x64 then !(castToBool vch) else castToBool vch
            .ok { st with vf := fValue :: st.vf, stack := st.stack.tail }
      else .ok { st with vf := false :: st.vf }             -- unexecuted IF pushes false
    else if w = 0x65 ∨ w = 0x66 then .error .badOpcode      -- OP_VERIF / OP_VERNOTIF
    else if w = 0x67 then                                   -- OP_ELSE
      match st.vf with
      | [] => .error .unbalancedConditional
      | v :: rest => .ok { st with vf := (!v) :: rest }
    else if w = 0x68 then                                   -- OP_ENDIF
      match st.vf with
      | [] => .error .unbalancedConditional
      | _ :: rest => .ok { st with vf := rest }
    else if w = 0x69 then                                   -- OP_VERIFY
      if st.stack.length < 1 then .error .stackUnderflow
      else if castToBool (topAt st.stack 1) then .ok { st with stack := st.stack.tail }
      else .error .verifyFailed
    else if w = 0x6a then .error .opReturn                  -- OP_RETURN
    else if w = 0x6b then                                   -- OP_TOALTSTACK
      if st.stack.length < 1 then .error .stackUnderflow
      else .ok { st with alt := topAt st.stack 1 :: st.alt, stack := st.stack.tail }
    else if w = 0x6c then                                   -- OP_FROMALTSTACK
      match st.alt with
      | [] => .error .invalidAltstackOperation
      | v :: rest => .ok { st with stack := v :: st.stack, alt := rest }
    else if w = 0x6d then                                   -- OP_2DROP
      if st.stack.length < 2 then .error .stackUnderflow
      else .ok { st with stack := st.stack.drop 2 }
    else if w = 0x6e then                                   -- OP_2DUP
      if st.stack.length < 2 then .error .stackUnderflow
      else
        let a := topAt st.stack 1; let b := topAt st.stack 2
        .ok { st with stack := a :: b :: a :: b :: st.stack.drop 2 }
    else if w = 0x6f then                                   -- OP_3DUP
      if st.stack.length < 3 then .error .stackUnderflow
      else
        let a := topAt st.stack 1; let b := topAt st.stack 2; let c := topAt st.stack 3
        .ok { st with stack := a :: b :: c :: a :: b :: c :: st.stack.drop 3 }
    else if w = 0x70 then                                   -- OP_2OVER
      if st.stack.length < 4 then .error .stackUnderflow
      else
        let a := topAt st.stack 1; let b := topAt st.stack 2
        let c := topAt st.stack 3; let d := topAt st.stack 4
        -- bottom-up [x1,x2,x3,x4] → [x1,x2,x3,x4,x1,x2]; head-first: x2,x1,x4,x3,…
        .ok { st with stack := c :: d :: a :: b :: c :: d :: st.stack.drop 4 }
    else if w = 0x71 then                                   -- OP_2ROT
      if st.stack.length < 6 then .error .stackUnderflow
      else
        let a := topAt st.stack 1; let b := topAt st.stack 2
        let c := topAt st.stack 3; let d := topAt st.stack 4
        let e := topAt st.stack 5; let f := topAt st.stack 6
        -- bottom-up [x1..x6] → [x3,x4,x5,x6,x1,x2]; head-first: x2,x1,x6,x5,x4,x3
        .ok { st with stack := e :: f :: a :: b :: c :: d :: st.stack.drop 6 }
    else if w = 0x72 then                                   -- OP_2SWAP
      if st.stack.length < 4 then .error .stackUnderflow
      else
        let a := topAt st.stack 1; let b := topAt st.stack 2
        let c := topAt st.stack 3; let d := topAt st.stack 4
        -- bottom-up [x1,x2,x3,x4] → [x3,x4,x1,x2]; head-first: x2,x1,x4,x3
        .ok { st with stack := c :: d :: a :: b :: st.stack.drop 4 }
    else if w = 0x73 then                                   -- OP_IFDUP
      if st.stack.length < 1 then .error .stackUnderflow
      else if castToBool (topAt st.stack 1) then .ok { st with stack := topAt st.stack 1 :: st.stack }
      else .ok st
    else if w = 0x74 then                                   -- OP_DEPTH
      .ok { st with stack := encodeScriptNum (st.stack.length : ScriptNum) false :: st.stack }
    else if w = 0x75 then                                   -- OP_DROP
      if st.stack.length < 1 then .error .stackUnderflow
      else .ok { st with stack := st.stack.tail }
    else if w = 0x76 then                                   -- OP_DUP
      if st.stack.length < 1 then .error .stackUnderflow
      else .ok { st with stack := topAt st.stack 1 :: st.stack }
    else if w = 0x77 then                                   -- OP_NIP
      if st.stack.length < 2 then .error .stackUnderflow
      else .ok { st with stack := topAt st.stack 1 :: st.stack.drop 2 }
    else if w = 0x78 then                                   -- OP_OVER
      if st.stack.length < 2 then .error .stackUnderflow
      else .ok { st with stack := topAt st.stack 2 :: st.stack }
    else if w = 0x79 ∨ w = 0x7a then                        -- OP_PICK / OP_ROLL
      if st.stack.length < 2 then .error .stackUnderflow
      else match decodeNum pol (topAt st.stack 1) 4 with
        | .error e => .error e
        | .ok n =>
          let st' := st.stack.tail
          if n < 0 ∨ st'.length ≤ n.toNat then .error .stackUnderflow
          else
            let vch := st'[n.toNat]!  -- n-th from the TOP (Core stacktop(-n-1))
            if w = 0x79 then .ok { st with stack := vch :: st' }
            else .ok { st with stack := vch :: (st'.take n.toNat ++ st'.drop (n.toNat + 1)) }
    else if w = 0x7b then                                   -- OP_ROT
      if st.stack.length < 3 then .error .stackUnderflow
      else
        let a := topAt st.stack 1; let b := topAt st.stack 2; let c := topAt st.stack 3
        -- bottom-up [x1,x2,x3] → [x2,x3,x1]; head-first: x1,x3,x2
        .ok { st with stack := c :: a :: b :: st.stack.drop 3 }
    else if w = 0x7c then                                   -- OP_SWAP
      if st.stack.length < 2 then .error .stackUnderflow
      else
        let a := topAt st.stack 1; let b := topAt st.stack 2
        .ok { st with stack := b :: a :: st.stack.drop 2 }
    else if w = 0x7d then                                   -- OP_TUCK
      if st.stack.length < 2 then .error .stackUnderflow
      else
        let a := topAt st.stack 1; let b := topAt st.stack 2
        .ok { st with stack := a :: b :: a :: st.stack.drop 2 }
    else if w = 0x82 then                                   -- OP_SIZE
      if st.stack.length < 1 then .error .stackUnderflow
      else .ok { st with stack := encodeScriptNum ((topAt st.stack 1).size : ScriptNum) false :: st.stack }
    else if w = 0x87 ∨ w = 0x88 then                        -- OP_EQUAL / OP_EQUALVERIFY
      if st.stack.length < 2 then .error .stackUnderflow
      else
        let fEqual := topAt st.stack 2 == topAt st.stack 1
        if w = 0x87 then .ok { st with stack := pushBoolV fEqual :: st.stack.drop 2 }
        else if fEqual then .ok { st with stack := st.stack.drop 2 }
        else .error .equalVerifyFailed
    else if w = 0x8b ∨ w = 0x8c ∨ w = 0x8f ∨ w = 0x90 ∨ w = 0x91 ∨ w = 0x92 then
      if st.stack.length < 1 then .error .stackUnderflow
      else match decodeNum pol (topAt st.stack 1) 4 with
        | .error e => .error e
        | .ok bn => .ok { st with stack := encodeScriptNum (unOp w bn) false :: st.stack.tail }
    else if w = 0x93 ∨ w = 0x94 ∨ (0x9a ≤ w ∧ w ≤ 0xa4) then
      if st.stack.length < 2 then .error .stackUnderflow
      else match decodeNum pol (topAt st.stack 2) 4, decodeNum pol (topAt st.stack 1) 4 with
        | .error e, _ => .error e
        | _, .error e => .error e
        | .ok bn1, .ok bn2 =>
          let r := encodeScriptNum (binOp w bn1 bn2) false
          if w = 0x9d then                                  -- OP_NUMEQUALVERIFY
            if castToBool r then .ok { st with stack := st.stack.drop 2 }
            else .error .numEqualVerifyFailed
          else .ok { st with stack := r :: st.stack.drop 2 }
    else if w = 0xa5 then                                   -- OP_WITHIN
      if st.stack.length < 3 then .error .stackUnderflow
      else match decodeNum pol (topAt st.stack 3) 4, decodeNum pol (topAt st.stack 2) 4,
          decodeNum pol (topAt st.stack 1) 4 with
        | .error e, _, _ => .error e
        | _, .error e, _ => .error e
        | _, _, .error e => .error e
        | .ok bn1, .ok bn2, .ok bn3 =>
          .ok { st with stack := pushBoolV (bn2 ≤ bn1 ∧ bn1 < bn3) :: st.stack.drop 3 }
    else if 0xa6 ≤ w ∧ w ≤ 0xaa then                        -- hash opcodes
      if st.stack.length < 1 then .error .stackUnderflow
      else .ok { st with stack := hashForOp w (topAt st.stack 1) :: st.stack.tail }
    else if w = 0xab then                                   -- OP_CODESEPARATOR
      .ok { st with codeSep := op.next, codeSepPos := st.opcodeIndex }
    else if w = 0xac ∨ w = 0xad then                        -- OP_CHECKSIG / …VERIFY
      if st.stack.length < 2 then .error .stackUnderflow
      else
        let sig := topAt st.stack 2
        let pk := topAt st.stack 1
        -- the interpreter delta layer: EvalChecksig SigVersion mode dispatch (tapscript ≠ legacy)
        match evalChecksigDispatch flags pol ctx.chk (signatureExecutionData ctx st) ctx.sv st.codeSep ctx.bytes
            sig pk st.vwLeft with
        | .error e => .error e
        | .ok (fSuccess, vw') =>
          let st₂ := { st with vwLeft := vw' }
          if w = 0xad then
            if fSuccess then .ok { st₂ with stack := st₂.stack.drop 2 }
            else .error .checkSigVerify
          else .ok { st₂ with stack := pushBoolV fSuccess :: st₂.stack.drop 2 }
    else if w = 0xba then                                   -- OP_CHECKSIGADD (BIP342)
      -- tapscript-only: BAD_OPCODE under base/witnessV0 (interpreter.cpp:1097)
      if ctx.sv = .base ∨ ctx.sv = .witnessV0 then .error .badOpcode
      else if st.stack.length < 3 then .error .stackUnderflow
      else
        -- (sig num pubkey -- num+{0,1}); num decodes before EvalChecksig
        match checksigAddStep ctx.pol ctx.chk (signatureExecutionData ctx st)
            (topAt st.stack 3) (topAt st.stack 2) (topAt st.stack 1) st.vwLeft with
        | .error e => .error e
        | .ok (r, vw') =>
          .ok { st with vwLeft := vw',
                        stack := encodeScriptNum r false :: st.stack.drop 3 }
    else if w = 0xae ∨ w = 0xaf then                        -- OP_CHECKMULTISIG / …VERIFY
      checkMultiSig ctx w st
    else if w = 0x50 ∨ w = 0x62 ∨ w = 0x89 ∨ w = 0x8a then .error .badOpcode
    else .error .badOpcode

  /-- OP_CHECKMULTISIG / OP_CHECKMULTISIGVERIFY (interpreter.cpp:1113-1225).
  SWT-064: the NULLDUMMY gate (consensus post-segwit, `flags.nullDummy`).
  SWT-065: the extra dummy element is consumed unconditionally — the
  `nKeys + 2` arity checks and the `cmsCleanup` pop run regardless of flags
  (genesis CHECKMULTISIG shape). -/
  @[rule "SWT-064", rule "SWT-065", rule "INV-043", rule "INV-049", rule "INV-050"]
  checkMultiSig (ctx : Ctx) (w : Nat) (st : State) : Except ExecError State :=
    if ctx.sv = .tapscript then .error .tapscriptCheckMultiSig
    else if st.stack.length < 1 then .error .stackUnderflow
    else match decodeNum ctx.pol (topAt st.stack 1) 4 with
      | .error e => .error e
      | .ok nkv =>
        if nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv then .error .pubKeyCount
        else
          let nKeys := nkv.toNat
          let opCount₂ := st.opCount + nKeys
          if MAX_OPS_PER_SCRIPT < opCount₂ then .error .opCount
          else if st.stack.length < nKeys + 2 then .error .stackUnderflow
          else match decodeNum ctx.pol (st.stack[nKeys+1]!) 4 with
            | .error e => .error e
            | .ok nsv =>
              if nsv < 0 ∨ nKeys < nsv then .error .sigCount
              else
                let nSigs := nsv.toNat
                if st.stack.length < nKeys + nSigs + 3 then .error .stackUnderflow
                else
                  let scriptCode0 := ctx.bytes.extract st.codeSep ctx.bytes.size
                  -- per-signature FindAndDelete (base only), cumulative
                  let fd : Except ExecError ByteArray :=
                    (List.range nSigs).foldl (fun acc k =>
                      match acc with
                      | .error e => .error e
                      | .ok sc =>
                        if ctx.sv = .base then
                          let (found, sc') := findAndDelete sc
                            (pushBytesWire (st.stack[nKeys + k + 2]!))
                          if 0 < found ∧ ctx.pol.constScriptCode then .error .sigFindAndDelete
                          else .ok sc'
                        else .ok sc) (.ok scriptCode0)
                  match fd with
                  | .error e => .error e
                  | .ok scriptCode =>
                    match cmsLoop ctx.flags ctx.pol ctx.sv ctx.chk ctx.ed scriptCode
                        st.stack (nKeys + nSigs + 1) nKeys nSigs (nKeys + 3) 2 with
                    | .error e => .error e
                    | .ok fSuccess =>
                      match cmsCleanup ctx.pol st.stack fSuccess
                          (nKeys + nSigs + 3) (nKeys + 2) (nKeys + nSigs + 3) with
                      | .error e => .error e
                      | .ok st₃ =>
                        if st₃.length < 1 then .error .stackUnderflow
                        else if ctx.flags.nullDummy ∧ st₃[0]!.size ≠ 0 then .error .sigNullDummy
                        else
                          let st₄ :=
                            { st with opCount := opCount₂,
                                      stack := pushBoolV fSuccess :: st₃.tail }
                          if w = 0xaf then
                            if fSuccess then .ok { st₄ with stack := st₄.stack.tail }
                            else .error .checkMultiSigVerify
                          else .ok st₄

/-- `step` = `stepBody` + the terminal STACK_SIZE guard
(interpreter.cpp:566-569, checked after every opcode) + the tapscript
CHECKSIG state threading. Proof-friendly shape: the guard is on the
OUTSIDE, so `stepChecked_ok_bound` reads it off directly. -/
@[rule "INV-044", rule "TPR-067"]
def stepChecked (ctx : Ctx) (op : WireOp) (st : State) : Except ExecError State :=
  match stepBody ctx op st with
  | .ok st' =>
      if MAX_STACK_SIZE < st'.stack.length + st'.alt.length then .error .stackSize
      else .ok st'
  | .error e => .error e

/-- The eval loop (EvalScript's `for` over the opcode stream). Fuel =
remaining opcode budget; fuel exhaustion maps to `unknownError` (a
correct caller supplies ≥ the script's opcode count, which the 201-op
limit bounds; the SCRIPT_SIZE/parse pre-checks mean real runs always
have enough). -/
@[rule "SCR-003", rule "SCR-063", rule "INV-047"]
def evalFrom (ctx : Ctx) : Nat → List WireOp → State → Except ExecError State
  | 0, _, _ => .error .unknownError
  | _+1, [], st => if st.vf = [] then .ok st else .error .unbalancedConditional
  | f+1, op :: rest, st =>
      match stepChecked ctx op st with
      | .ok st' => evalFrom ctx f rest { st' with opcodeIndex := st.opcodeIndex + 1 }
      | .error e => .error e

/-- Lift `evalFrom`'s final machine state to the exported stack
(the only projection `EvalScript`'s callers see). -/
def finalStack : Except ExecError State → Except ExecError Stack
  | .ok st' => .ok st'.stack
  | .error e => .error e

/-- `EvalScript` from raw script bytes: SCRIPT_SIZE pre-check
(interpreter.cpp:419-421), parse, run. This is the entry used by
`ExecuteWitnessScript` and (via canonical re-serialization) by the
frozen `evalScript`. -/
@[rule "SCR-018", rule "SCR-019", rule "INV-041"]
def evalScriptBytes (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (b : ByteArray) (st0 : Stack) (chk : ScriptChecker) (sv : SigVersion)
    (ed : ScriptExecutionData) : Except ExecError Stack :=
  if (sv = .base ∨ sv = .witnessV0) ∧ MAX_SCRIPT_SIZE < b.size then .error .scriptSize
  else match parseWire b with
    | none => .error .badOpcode
    | some ops =>
      finalStack (evalFrom ⟨flags, pol, chk, sv, b, ed⟩ fuel ops
        { stack := st0, alt := [], vf := [], opCount := 0, codeSep := 0,
          -- the interpreter delta layer: the BIP342 validation-weight budget starts at the value
          -- ExecuteWitnessScript seeded into `ed` (Core mutates
          -- execdata.m_validation_weight_left in place; the machine
          -- threads it through State.vwLeft)
          vwLeft := if sv = .tapscript then some ed.validationWeightLeft else none })

/-! ## Witness verification (BIP141/341/342) -/

/-- The three-way verdict of a full script validation. `unjudged` is
reserved for taproot script-path spending (see module header). -/
inductive VerifyOutcome where
  | ok
  | fail (e : ExecError)
  | unjudged
deriving Repr, DecidableEq, BEq, Inhabited

/-- Missing signature context is incomplete adjudication, while every
actual checker rejection retains its exact script error. -/
def schnorrOutcome : Except ExecError Unit → VerifyOutcome
  | .ok () => .ok
  | .error .taprootDataUnavailable => .unjudged
  | .error e => .fail e

/-- Exact serialized witness-stack size, including stack-count CompactSize.
Shared with the crypto/program layer so the live budget cannot drift. -/
def witnessSerSize (items : List ByteArray) : Int :=
  Bitcoin.Crypto.Taproot.Program.witnessSerSize items

/-- `ExecuteWitnessScript` (interpreter.cpp:1854-1894). Returns the
VerifyOutcome of the inner evaluation. SWT-010: the ≤520 per-item cap;
SWT-012: the implicit witness cleanstack (exactly 1 truthy final item).
the interpreter rule layer: SCR-031 (BIP342 initial main+alt stack ≤ 1000, :1864-1865) and
SCR-040 (validation-weight budget = serialized witness size + 50 WU,
:1991-1992 + script.h:62-65). -/
@[rule "SCR-021", rule "SWT-010", rule "SWT-012", rule "SCR-031", rule "SCR-040", rule "TPR-066"]
def executeWitnessScript (fuel : Nat) (items : List ByteArray) (vwSer : Int)
    (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (sv : SigVersion) (edSeed : ScriptExecutionData := default) : VerifyOutcome :=
  if sv = .tapscript then
    -- OP_SUCCESSx scan overrides everything (incl. item size limits);
    -- ordered per-opcode with the decode step (opSuccessScan, the interpreter delta layer)
    if opSuccessScan exec then
      if pol.discourageOpSuccess then .fail .discourageOpSuccess else .ok
    else if MAX_STACK_SIZE < items.length then .fail .stackSize
    else runExec items
  else runExec items
where
  runExec (items : List ByteArray) : VerifyOutcome :=
    -- item size limits (BIP141)
    if items.any (fun d => MAX_SCRIPT_ELEMENT_SIZE < d.size) then .fail .pushSize
    else
      let edDflt : ScriptExecutionData := edSeed
      let ed : ScriptExecutionData :=
        if sv = .tapscript then
          { edDflt with
            validationWeightLeftInit := true,
            validationWeightLeft := vwSer + VALIDATION_WEIGHT_OFFSET }
        else edDflt
      -- `items` is in witness order (first pushed = bottom); the machine
      -- stack is head = TOP, so hand EvalScript the reversed list.
      match evalScriptBytes fuel flags pol exec items.reverse chk sv ed with
      | .error .taprootDataUnavailable => .unjudged
      | .error e => .fail e
      | .ok st =>
        -- witness scripts implicitly require cleanstack
        if st.length ≠ 1 then .fail .cleanstack
        else if castToBool st[0]! then .ok else .fail .evalFalse

/-- BIP341 annex digest (interpreter.cpp:1964 + 1554-1556): `SHA256(
CompactSize(len(annex)) ‖ annex)`. Core's `HashWriter` serializes the
annex span with a CompactSize length prefix; the annex includes its
mandatory `0x50` tag byte. -/
def annexHash (annex : ByteArray) : ByteArray :=
  hashSha256 (compactSizeEnc annex.size ++ annex)

/-- `VerifyWitnessProgram`: real script-path commitment binding and typed
key/script signature dispatch. Only missing signature context is unjudged. -/
@[rule "SCR-133", rule "SCR-134", rule "SCR-135", rule "SCR-136", rule "SCR-137", rule "SCR-138", rule "SCR-143", rule "SCR-145", rule "SCR-150", rule "SCR-151",
  rule "SWT-005", rule "SWT-006", rule "SWT-007", rule "SWT-008", rule "SWT-009",
  rule "SWT-013", rule "SWT-014",
  -- the interpreter rule layer: TAPROOT flag gate / key-path spend / upgradable leaf versions
  rule "SCR-142", rule "SCR-144", rule "SCR-149",
  -- RC06: witness program shapes + v0 dispatch (INV-067/070)
  rule "INV-067", rule "INV-070",
  -- RC07: BIP341 annex parse + hash into ScriptExecutionData
  rule "INV-075"]
def verifyWitnessProgram (fuel : Nat) (witness : WitnessStack) (version : Nat)
    (program : ByteArray) (flags : ScriptFlags) (pol : PolicyFlags)
    (chk : ScriptChecker) (isP2SH : Bool) : VerifyOutcome :=
  if version = 0 then
    if program.size = 32 then
      -- P2WSH: Core `SpanPopBack`s the witness script (the LAST item)
      if witness.length = 0 then .fail .witnessProgramWitnessEmpty
      else
        let script := witness.getLast!
        let rest := witness.dropLast
        if hashSha256 script != program then .fail .witnessProgramMismatch
        else executeWitnessScript fuel rest (witnessSerSize witness) script flags pol chk .witnessV0
    else if program.size = 20 then
      -- P2WPKH: implied script OP_DUP OP_HASH160 <program> OP_EQUALVERIFY OP_CHECKSIG
      if witness.length ≠ 2 then .fail .witnessProgramMismatch
      else
        let exec : ByteArray :=
          List.toByteArray [0x76, 0xa9, 0x14] ++ program ++
            List.toByteArray [0x88, 0xac]
        executeWitnessScript fuel witness (witnessSerSize witness) exec flags pol chk .witnessV0
    else .fail .witnessProgramWrongLength
  else if version = 1 ∧ program.size = 32 ∧ !isP2SH then
    -- BIP341 taproot
    if !flags.taproot then .ok
    else match witness with
      | [] => .fail .witnessProgramWitnessEmpty
      | _ =>
        -- annex detection: last item nonempty starting with 0x50
        let annex := 2 ≤ witness.length ∧ (witness.getLast!).size ≠ 0 ∧
          (byteOr (witness.getLast!) 0).toNat = ANNEX_TAG
        let stack := if annex then witness.dropLast else witness
        let edDflt : ScriptExecutionData := default
        let ed : ScriptExecutionData :=
          { edDflt with
            annexInit := true,
            annexPresent := annex,
            annexHash := (if annex then annexHash (witness.getLast!) else edDflt.annexHash) }
        if stack.length = 1 then
          -- key path spend
          schnorrOutcome (checkSchnorrWithContext chk stack[0]! program .taproot ed)
        else
          -- script path: control = top = LAST item, script = second-to-last
          -- (Core `SpanPopBack`s control then script)
          let control := stack.getLast!
          if control.size < TAPROOT_CONTROL_BASE_SIZE ∨
              TAPROOT_CONTROL_MAX_SIZE < control.size ∨
              (control.size - TAPROOT_CONTROL_BASE_SIZE) % TAPROOT_CONTROL_NODE_SIZE ≠ 0 then
            .fail .taprootWrongControlSize
          else
            let script := (stack.dropLast).getLast!
            let tapleaf := Bitcoin.Crypto.Taproot.Verify.scriptPathTapleaf control script
            if !Bitcoin.Crypto.Taproot.Verify.verifyTaprootCommitment control program tapleaf then
              .fail .witnessProgramMismatch
            else if ((byteOr control 0).toNat &&& 0xfe) = 0xc0 then
              let ed := { ed with tapleafHashInit := true, tapleafHash := tapleaf }
              executeWitnessScript fuel (stack.dropLast.dropLast) (witnessSerSize witness)
                script flags pol chk .tapscript ed
            else if pol.discourageUpgradableTaprootVersion then
              .fail .discourageUpgradableTaprootVersion
            else .ok
  else if !isP2SH ∧ isPayToAnchor version program then .ok
  else if pol.discourageUpgradableWitnessProgram then .fail .discourageUpgradableWitnessProgram
  else .ok

/-! ## VerifyScript (interpreter.cpp:2012-2111) -/

/-- The P2SH-wrapped inner evaluation (interpreter.cpp:2063-2101). -/
@[rule "SCR-005", rule "SCR-006", rule "SCR-007", rule "SCR-012", rule "SWT-004", rule "INV-066", rule "INV-069"]
def p2shInner (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (ss : ByteArray) (stackCopy : Stack) (witness : WitnessStack)
    (chk : ScriptChecker) : VerifyOutcome :=
  -- scriptSig must be literals-only
  match parseWire ss with
  | none => .fail .badOpcode
  | some ops =>
    if !isPushOnlyWire ops then .fail .sigPushOnly
    else
      -- restore the scriptSig-final stack; top = serialized redeem script
      match stackCopy with
      | [] => .fail .unknownError   -- Core: assert(!stack.empty()) — unreachable
      | pubKeySerialized :: rest =>
        let pubKey2 := pubKeySerialized
        match evalScriptBytes fuel flags pol pubKey2 rest chk .base default with
        | .error e => .fail e
        | .ok stack =>
          if stack = [] ∨ !castToBool stack[0]! then .fail .evalFalse
          else
            -- P2SH witness program
            if flags.witness then
              match isWitnessProgram pubKey2 with
              | some (v, prog) =>
                if ss != pushBytesWire pubKey2 then .fail .witnessMalleatedP2SH
                else verifyWitnessProgram fuel witness v prog flags pol chk true
              | none => .ok
            else .ok

/-- `VerifyScript` with the full error taxonomy (the consensus entry —
flags come from `getBlockScriptFlags`, policy from the mempool
policy the caller models). Check order mirrors interpreter.cpp:2012-2111. -/
@[rule "SCR-001", rule "SCR-002", rule "SCR-004", rule "SCR-008", rule "SCR-010", rule "SCR-011", rule "SCR-013", rule "SCR-017",
  rule "SWT-003", rule "SWT-015", rule "INV-048",
  rule "INV-064", rule "INV-065", rule "INV-068",
  -- RC07: WITNESS implies P2SH; unexpected witness data fails (both tails)
  rule "INV-077"]
def verifyScriptFull (fuel : Nat) (flags : ScriptFlags) (pol : PolicyFlags)
    (ss spk : ByteArray) (witness : WitnessStack) (chk : ScriptChecker) : VerifyOutcome :=
  -- pre-check: scriptSig push-only under SIGPUSHONLY (IsPushOnly: parse
  -- failure also fails)
  let pre :=
    if pol.sigPushOnly then
      match parseWire ss with
      | none => .fail .sigPushOnly
      | some ops => if !isPushOnlyWire ops then .fail .sigPushOnly else VerifyOutcome.ok
    else VerifyOutcome.ok
  match pre with
  | .fail e => .fail e
  | _ =>
    match evalScriptBytes fuel flags pol ss [] chk .base default with
    | .error e => .fail e
    | .ok stack1 =>
      let stackCopy := stack1   -- saved when P2SH (interpreter.cpp:2032)
      match evalScriptBytes fuel flags pol spk stack1 chk .base default with
      | .error e => .fail e
      | .ok stack =>
        if stack = [] ∨ !castToBool stack[0]! then .fail .evalFalse
        else
          -- bare witness programs
          let bare : VerifyOutcome :=
            if flags.witness then
              match isWitnessProgram spk with
              | some (v, prog) =>
                if ss.size ≠ 0 then .fail .witnessMalleated
                else verifyWitnessProgram fuel witness v prog flags pol chk false
              | none => .ok
            else .ok
          match bare with
          | .fail e => .fail e
          | .unjudged => .unjudged
          | .ok =>
            let afterBare := if flags.witness ∧ (isWitnessProgram spk).isSome then
              -- Bypass the cleanstack check: stack.resize(1)
              (if stack = [] then [] else [stack[0]!])
            else stack
            -- P2SH
            if flags.p2sh ∧ isPayToScriptHash spk then
              match p2shInner fuel flags pol ss stackCopy witness chk with
              | .fail e => .fail e
              | .unjudged => .unjudged
              | .ok =>
                -- the inner evaluation resized to 1 (witness) or left the
                -- cleanstack-relevant stack; final stack after P2SH is the
                -- inner stack — for CLEANSTACK only its size matters, and
                -- p2shInner's success paths leave exactly 1 item
                let finalLen : Nat :=
                  if flags.witness ∧ (isWitnessProgram spk).isSome then 1
                  else
                    -- non-witness P2SH: inner stack = eval of redeem script
                    -- on stackCopy minus its top; recompute its length
                    match parseWire ss with
                    | none => 0
                    | some ops =>
                      if !isPushOnlyWire ops then 0
                      else
                        match stackCopy with
                        | [] => 0
                        | _ :: rest =>
                          match evalScriptBytes fuel flags pol
                              (match stackCopy with
                               | [] => ByteArray.empty
                               | p :: _ => p) rest chk .base default with
                          | .error _ => 0
                          | .ok s2 => s2.length
                if pol.cleanstack ∧ finalLen ≠ 1 then .fail .cleanstack
                else if flags.witness ∧ witness ≠ [] ∧
                    ¬(flags.witness ∧ ((isWitnessProgram spk).isSome ∧ ss.size = 0) ∨
                      ((isWitnessProgram (match stackCopy with
                        | [] => ByteArray.empty
                        | p :: _ => p)).isSome ∧ ss == pushBytesWire
                          (match stackCopy with
                           | [] => ByteArray.empty
                           | p :: _ => p))) then
                  .fail .witnessUnexpected
                else .ok
            else
              if pol.cleanstack ∧ afterBare.length ≠ 1 then .fail .cleanstack
              else if flags.witness ∧ witness ≠ [] ∧ ¬(flags.witness ∧ (isWitnessProgram spk).isSome) then
                .fail .witnessUnexpected
              else .ok

/-! ## Reusable properties of the evaluation core -/

/-- A successful `stepChecked` output satisfies the STACK_SIZE cap —
read straight off the guard (this is why the guard wraps `stepBody`
rather than living inside the dispatch). -/
@[rule "SCR-029"]
theorem stepChecked_ok_bound {ctx : Ctx} {op : WireOp} {st st' : State}
    (h : stepChecked ctx op st = .ok st') :
    st'.stack.length + st'.alt.length ≤ MAX_STACK_SIZE := by
  unfold stepChecked at h
  split at h
  · split at h
    · simp at h
    · rename_i hle
      simp only [Except.ok.injEq] at h
      subst h
      omega
  · simp at h

/-- Every opcode step preserves the stack bound; so a successful
`evalFrom` run from a bounded stack ends on a bounded stack. -/
theorem evalFrom_ok_stack_bound (ctx : Ctx) :
    ∀ (f : Nat) (ops : List WireOp) (st st' : State),
      st.stack.length ≤ MAX_STACK_SIZE →
      evalFrom ctx f ops st = .ok st' →
      st'.stack.length ≤ MAX_STACK_SIZE := by
  intro f
  induction f with
  | zero => intro ops st st' _ h; simp [evalFrom] at h
  | succ f ih =>
    intro ops st st' h0 h
    cases ops with
    | nil =>
      simp only [evalFrom] at h
      split at h
      · simp only [Except.ok.injEq] at h
        subst h
        exact h0
      · simp at h
    | cons op rest =>
      simp only [evalFrom] at h
      cases hsc : stepChecked ctx op st with
      | error e => rw [hsc] at h; simp at h
      | ok s =>
        rw [hsc] at h
        have hb := stepChecked_ok_bound hsc
        exact ih rest { s with opcodeIndex := st.opcodeIndex + 1 } st' (by change s.stack.length ≤ MAX_STACK_SIZE; omega) h

/-- One more unit of fuel never breaks a succeeding run: the `[]` arm is
fuel-independent and the cons arm just shifts the recursive fuel. -/
theorem evalFrom_succ_ok (ctx : Ctx) (f : Nat) (ops : List WireOp) (st : State)
    (h : (evalFrom ctx f ops st).isOk) : (evalFrom ctx (f + 1) ops st).isOk := by
  induction f generalizing ops st with
  | zero => exact absurd h (by simp [evalFrom, Except.isOk, Except.toBool])
  | succ f ih =>
    cases ops with
    | nil => simpa only [evalFrom, Except.isOk, Except.toBool] using h
    | cons op rest =>
      simp only [evalFrom, Except.isOk, Except.toBool] at h ⊢
      cases hsc : stepChecked ctx op st with
      | error e => rw [hsc] at h; simp [Except.isOk, Except.toBool] at h
      | ok s => rw [hsc] at h; exact ih rest { s with opcodeIndex := st.opcodeIndex + 1 } h

/-- Fuel monotonicity for the loop: `f₁ ≤ f₂`, success at `f₁` ⇒
success at `f₂` (fuel only gates the empty-stream arm). -/
theorem evalFrom_fuel_mono (ctx : Ctx) :
    ∀ (f₁ : Nat) (ops : List WireOp) (st : State) (f₂ : Nat),
      f₁ ≤ f₂ →
      (evalFrom ctx f₁ ops st).isOk → (evalFrom ctx f₂ ops st).isOk := by
  intro f₁ ops st f₂ hf h
  induction hf with
  | refl => exact h
  | step _ ih => exact evalFrom_succ_ok ctx _ ops st ih

/-- `finalStack` preserves and reflects success. -/
theorem finalStack_isOk_iff {r : Except ExecError State} :
    (finalStack r).isOk = true ↔ r.isOk = true := by
  cases r with
  | ok s => simp [finalStack, Except.isOk, Except.toBool]
  | error e => simp [finalStack, Except.isOk, Except.toBool]

/-- A successful `finalStack` result comes from a successful run whose
exported stack is the machine state's main stack. -/
theorem finalStack_ok {r : Except ExecError State} {st' : Stack}
    (h : finalStack r = .ok st') : ∃ s, r = .ok s ∧ st' = s.stack := by
  cases r with
  | ok s => simp [finalStack] at h; exact ⟨s, rfl, h.symm⟩
  | error e => simp [finalStack] at h

/-- The `evalScriptBytes` entry shares the two lemmas above (the
SCRIPT_SIZE pre-check and the parse are fuel-independent). -/
@[rule "SCR-030"]
theorem evalScriptBytes_ok_stack_bound {fuel : Nat} {flags : ScriptFlags}
    {pol : PolicyFlags} {b : ByteArray} {st0 : Stack} {chk : ScriptChecker}
    {sv : SigVersion} {ed : ScriptExecutionData} (h0 : st0.length ≤ MAX_STACK_SIZE) :
    ∀ st', evalScriptBytes fuel flags pol b st0 chk sv ed = .ok st' →
      st'.length ≤ MAX_STACK_SIZE := by
  intro st' h
  unfold evalScriptBytes at h
  by_cases hsz : (sv = SigVersion.base ∨ sv = SigVersion.witnessV0) ∧
      MAX_SCRIPT_SIZE < b.size
  · rw [if_pos hsz] at h; simp at h
  · rw [if_neg hsz] at h
    cases hp : parseWire b with
    | none => rw [hp] at h; simp at h
    | some ops =>
      rw [hp] at h
      have h2 : finalStack (evalFrom ⟨flags, pol, chk, sv, b, ed⟩ fuel ops
          { stack := st0, alt := [], vf := [], opCount := 0, codeSep := 0,
            vwLeft := if sv = .tapscript then some ed.validationWeightLeft else none }) = .ok st' := h
      obtain ⟨s, hr, hst⟩ := finalStack_ok h2
      have hb := evalFrom_ok_stack_bound ⟨flags, pol, chk, sv, b, ed⟩ fuel ops
        { stack := st0, alt := [], vf := [], opCount := 0, codeSep := 0,
          vwLeft := if sv = .tapscript then some ed.validationWeightLeft else none } s h0 hr
      rw [hst]; exact hb

theorem evalScriptBytes_fuel_mono {flags : ScriptFlags} {pol : PolicyFlags}
    {b : ByteArray} {st0 : Stack} {chk : ScriptChecker} {sv : SigVersion}
    {ed : ScriptExecutionData} :
    ∀ (f₁ f₂ : Nat), f₁ ≤ f₂ →
      (evalScriptBytes f₁ flags pol b st0 chk sv ed).isOk →
      (evalScriptBytes f₂ flags pol b st0 chk sv ed).isOk := by
  intro f₁ f₂ hf h
  unfold evalScriptBytes at h ⊢
  by_cases hsz : (sv = SigVersion.base ∨ sv = SigVersion.witnessV0) ∧
      MAX_SCRIPT_SIZE < b.size
  · rw [if_pos hsz] at h; simp [Except.isOk, Except.toBool] at h
  · rw [if_neg hsz] at h ⊢
    cases hp : parseWire b with
    | none => rw [hp] at h; simp [Except.isOk, Except.toBool] at h
    | some ops =>
      rw [hp] at h
      have h2 : (finalStack (evalFrom ⟨flags, pol, chk, sv, b, ed⟩ f₁ ops
          { stack := st0, alt := [], vf := [], opCount := 0, codeSep := 0,
            vwLeft := if sv = .tapscript then some ed.validationWeightLeft else none })).isOk = true := h
      exact finalStack_isOk_iff.mpr
        (evalFrom_fuel_mono ⟨flags, pol, chk, sv, b, ed⟩ f₁ ops
          { stack := st0, alt := [], vf := [], opCount := 0, codeSep := 0,
            vwLeft := if sv = .tapscript then some ed.validationWeightLeft else none }
          f₂ hf (finalStack_isOk_iff.mp h2))

/-! ## DEEP-A remediation row faces (2026-10-17)

The companion rows in this bundle whose existing `lean_target` was a
definition.  Each theorem below states the row's actual consensus
content over the same definition, without changing any definition. -/

/-- INV-041 (`interpreter.cpp:437-439 @cce32b168`, the pre-parse
`MAX_SCRIPT_SIZE` check): a successful BASE/WITNESS_V0 evaluation
implies `len(script) ≤ 10000`.  TAPSCRIPT is exempt in the model and in
Core (the check is inside the non-tapscript arm), hence the `hsv`
precondition. -/
@[rule "INV-041"]
theorem evalScriptBytes_size_bound {fuel : Nat} {flags : ScriptFlags}
    {pol : PolicyFlags} {b : ByteArray} {st0 : Stack} {chk : ScriptChecker}
    {sv : SigVersion} {ed : ScriptExecutionData} {st' : Stack}
    (hsv : sv = .base ∨ sv = .witnessV0)
    (h : evalScriptBytes fuel flags pol b st0 chk sv ed = .ok st') :
    b.size ≤ MAX_SCRIPT_SIZE := by
  by_cases hle : b.size ≤ MAX_SCRIPT_SIZE
  · exact hle
  · have hs : MAX_SCRIPT_SIZE < b.size := by omega
    unfold evalScriptBytes at h
    rw [if_pos ⟨hsv, hs⟩] at h
    exact absurd h (by simp)

/-- INV-045 (`interpreter.cpp:472-483 @cce32b168`, CVE-2010-5137): a
disabled wire opcode can never step a state to `.ok`; every path out of
`stepBody` is an `.error` (including the unexecuted-branch gate). -/
@[rule "INV-045"]
theorem stepBody_disabledWire_ne_ok {ctx : Ctx} {st st' : State} {op : WireOp}
    (hd : disabledWire op.wire = true) :
    stepBody ctx op st ≠ .ok st' := by
  intro h
  simp only [stepBody] at h
  rw [hd] at h
  simp at h
  repeat' split at h
  all_goals nomatch h

/-- INV-066 (`interpreter.cpp:2062-2090 @cce32b168`, BIP16): for a
push-only scriptSig the saved top item `p` is the redeemScript (the last
scriptSig element) and `p2shInner` evaluates exactly `evalScriptBytes
… p rest …`, propagating errors and applying the truth test before the
witness-program branch. -/
@[rule "INV-066"]
theorem p2shInner_redeem_eq (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (ss p : ByteArray) (rest witness : List ByteArray)
    (chk : ScriptChecker) (ops : List WireOp)
    (hparse : parseWire ss = some ops)
    (hpush : isPushOnlyWire ops = true) :
    p2shInner fuel flags pol ss (p :: rest) witness chk =
      (match evalScriptBytes fuel flags pol p rest chk .base default with
       | .error e => .fail e
       | .ok stack =>
           if stack = [] ∨ !castToBool stack[0]! then .fail .evalFalse
           else if flags.witness then
             (match isWitnessProgram p with
              | some (v, prog) =>
                  if ss != pushBytesWire p then .fail .witnessMalleatedP2SH
                  else verifyWitnessProgram fuel witness v prog flags pol chk true
              | none => .ok)
           else .ok) := by
  unfold p2shInner
  rw [hparse]
  simp [hpush]

/-- INV-066 (accept face): a truthy successful redeemScript evaluation
with the witness flag off passes P2SH. -/
@[rule "INV-066"]
theorem p2shInner_redeem_ok (fuel : Nat) (flags : ScriptFlags)
    (pol : PolicyFlags) (ss p : ByteArray) (rest witness : List ByteArray)
    (chk : ScriptChecker) (ops : List WireOp) (stack : Stack)
    (hparse : parseWire ss = some ops)
    (hpush : isPushOnlyWire ops = true)
    (hev : evalScriptBytes fuel flags pol p rest chk .base default = .ok stack)
    (hne : stack ≠ []) (htrue : castToBool stack[0]! = true)
    (hw : flags.witness = false) :
    p2shInner fuel flags pol ss (p :: rest) witness chk = .ok := by
  rw [p2shInner_redeem_eq fuel flags pol ss p rest witness chk ops hparse hpush, hev]
  cases stack with
  | nil => exact absurd rfl hne
  | cons a t =>
    have h' : castToBool a = true := by simpa using htrue
    simp [hw, h']

/-- INV-075 (`interpreter.cpp:1961-1969 @cce32b168`, BIP341): a witness
`[sig, annex]` with a nonempty `0x50`-tagged last item is parsed as an
annex, the annex is hashed into `ScriptExecutionData`
(`annexHash = SHA256(CompactSize(len(annex)) ‖ annex)`, `annexPresent = true`, `annexInit =
true`), stripped from the stack, and the remaining single item is the
key-path signature checked against the output key. -/
@[rule "INV-075"]
theorem verifyWitnessProgram_annex_keypath (fuel : Nat)
    (sig annex program : ByteArray) (flags : ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker)
    (htap : flags.taproot = true) (h32 : program.size = 32)
    (hnonempty : annex.size ≠ 0) (htag : (byteOr annex 0).toNat = ANNEX_TAG) :
    verifyWitnessProgram fuel [sig, annex] 1 program flags pol chk false =
      schnorrOutcome (checkSchnorrWithContext chk sig program SigVersion.taproot
          { (default : ScriptExecutionData) with
            annexInit := true, annexPresent := true,
            annexHash := annexHash annex }) := by
  simp [verifyWitnessProgram, htap, h32, hnonempty, htag]

/-- TPR-002 (`interpreter.cpp:1959 @cce32b168`): without
`SCRIPT_VERIFY_TAPROOT`, a native v1-32 witness program returns success
immediately — `if (!(flags & SCRIPT_VERIFY_TAPROOT)) return
set_success(serror);`.  This is the interpreter bridge the old
`Taproot.Program.taprootLane` target lacked. -/
@[rule "TPR-002"]
theorem verifyWitnessProgram_taproot_flag_off (fuel : Nat)
    (witness : WitnessStack) (program : ByteArray) (flags : ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) (h32 : program.size = 32)
    (h : flags.taproot = false) :
    verifyWitnessProgram fuel witness 1 program flags pol chk false = .ok := by
  simp [verifyWitnessProgram, h32, h]

/-- TPR-003 (`interpreter.cpp:1957 → 2002-2008 @cce32b168`): a v1-32
program reached through P2SH fails the native-only taproot condition
(`!is_p2sh` false), skips the anchor branch, and takes the upgradable
pass-through, i.e. success unless DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
is set. -/
@[rule "TPR-003"]
theorem verifyWitnessProgram_p2sh_v1 (fuel : Nat)
    (witness : WitnessStack) (program : ByteArray) (flags : ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) (h32 : program.size = 32)
    (hd : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel witness 1 program flags pol chk true = .ok := by
  simp [verifyWitnessProgram, h32, hd]

/-- SWT-013 reject face (`interpreter.cpp:1954-1955 @cce32b168`): a
witness v0 program whose length is neither 20 (P2WPKH) nor 32 (P2WSH)
fails with `SCRIPT_ERR_WITNESS_PROGRAM_WRONG_LENGTH` — it is NOT an
anyone-can-spend pass-through. -/
@[rule "SWT-013"]
theorem verifyWitnessProgram_v0_wrong_length (fuel : Nat)
    (witness : WitnessStack) (program : ByteArray) (flags : ScriptFlags)
    (pol : PolicyFlags) (chk : ScriptChecker) (isP2SH : Bool)
    (h20 : program.size ≠ 20) (h32 : program.size ≠ 32) :
    verifyWitnessProgram fuel witness 0 program flags pol chk isP2SH
      = .fail .witnessProgramWrongLength := by
  simp [verifyWitnessProgram, h20, h32]

/-- SWT-013 pass-through face (`interpreter.cpp:2002-2008 @cce32b168`):
witness versions `≥ 2`, and v1 programs other than the native v1-32
shape (wrong length, or v1-32 through P2SH), validate as anyone-can-spend
unless the policy bit is set. -/
@[rule "SWT-013"]
theorem verifyWitnessProgram_other_pass (fuel : Nat)
    (witness : WitnessStack) (v : Nat) (program : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (isP2SH : Bool)
    (hv : 2 ≤ v ∨ (v = 1 ∧ (program.size ≠ 32 ∨ isP2SH = true)))
    (hd : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel witness v program flags pol chk isP2SH = .ok := by
  rcases hv with hv | ⟨hv1, hcase⟩
  · have hv0 : v ≠ 0 := by omega
    have hv1 : v ≠ 1 := by omega
    simp [verifyWitnessProgram, hv0, hv1, hd]
  · subst hv1
    by_cases h32 : program.size = 32
    · have hp2sh : isP2SH = true := by
        rcases hcase with h | h
        · exact absurd h32 h
        · exact h
      simp [verifyWitnessProgram, h32, hp2sh, hd]
    · simp [verifyWitnessProgram, h32, hd]

/-- SCR-078 (`interpreter.cpp:67-72,65 @cce32b168`), **stack-shuffling
subset**: the 19 opcodes listed in `hw` pre-check depth on an empty stack
and return `SCRIPT_ERR_INVALID_STACK_OPERATION`, so the evaluator never
reaches a throwing `popstack` on this lane.

This theorem does **not** cover every consuming opcode: the flow ops
(`OP_IF`/`OP_NOTIF`/`OP_VERIFY`/`OP_TOALTSTACK`), unary/binary numeric
ops, `OP_WITHIN`, the hash ops, and the checksig family have their own
underflow paths (and `OP_CHECKMULTISIG`/`OP_CHECKSIGADD` additionally
depend on the sigversion). The blanket "all ops pre-check" reading is a
model observation, not this theorem's statement. -/
@[rule "SCR-078"]
theorem stepBody_stackop_empty_underflow (ctx : Ctx) (op : WireOp) (st : State)
    (c : Fin 256) (ha : op.ast = .op c)
    (hw : op.wire = 0x6d ∨ op.wire = 0x6e ∨ op.wire = 0x6f ∨ op.wire = 0x70 ∨
      op.wire = 0x71 ∨ op.wire = 0x72 ∨ op.wire = 0x73 ∨ op.wire = 0x75 ∨
      op.wire = 0x76 ∨ op.wire = 0x77 ∨ op.wire = 0x78 ∨ op.wire = 0x79 ∨
      op.wire = 0x7a ∨ op.wire = 0x7b ∨ op.wire = 0x7c ∨ op.wire = 0x7d ∨
      op.wire = 0x82 ∨ op.wire = 0x87 ∨ op.wire = 0x88)
    (hempty : st.stack = [])
    (hfe : st.vf.all id = true)
    (hb : ¬ ((ctx.sv = .base ∨ ctx.sv = .witnessV0) ∧
      MAX_OPS_PER_SCRIPT < st.opCount + 1)) :
    stepBody ctx op st = .error .stackUnderflow := by
  have hb2 : (ctx.sv = .base ∨ ctx.sv = .witnessV0) →
      (if ctx.sv = .base ∨ ctx.sv = .witnessV0 then st.opCount + 1 else st.opCount)
        ≤ MAX_OPS_PER_SCRIPT := by
    intro hA
    rw [ite_eq_left hA]
    exact Nat.le_of_not_lt (fun hlt => hb ⟨hA, hlt⟩)
  rcases hw with hw | hw | hw | hw | hw | hw | hw | hw | hw | hw |
      hw | hw | hw | hw | hw | hw | hw | hw | hw <;>
    simp [stepBody, ha, hw, hempty, hfe, disabledWire, hb,
      Bitcoin.Interpreter.stepBody.dispatchOp]
  all_goals exact hb2

end Bitcoin.Interpreter
