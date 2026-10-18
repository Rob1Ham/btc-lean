import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Crypto.Ecdsa.Verify
import Bitcoin.Crypto.Schnorr.Verify
import Bitcoin.Crypto.Taproot.Sighash
import Bitcoin.SigHash.Interface
import Bitcoin.Data.Tx
import Bitcoin.Interpreter.Defs

/-!
# Bitcoin.Capstone.RealChecker — S2a: the crypto wiring

The ECDSA base adapter instantiates `ecdsaEntry` with the real lax verifier
`Bitcoin.Crypto.Ecdsa.Verify.verifyImpl`. Production extends that adapter
with typed BIP341 hashing and BIP340 verification in `realCheckerWithTaproot`;
the frozen `Entry.lean` Boolean seam remains available for compatibility.

## Flag gate (BIP66 strict / lax)

The seam's ECDSA entry is CONTRACTUALLY lax (DECISIONS.md OPEN-002): the
DER strictness is enforced by the interpreter's BIP66 gate
(`Seam/Der.checkSignatureEncoding` via `checkSigEncoding`, flags
from `getBlockScriptFlags`), BEFORE the adapter is ever reached —
exactly Core's order (interpreter.cpp:1172/1183 call
`CheckSignatureEncoding` first, `CheckECDSASignature` sees only
gate-passing sigs). So "wiring behind the flag-gate" = `verifyImpl` here +
the interpreter's flag-driven DER gate upstream; nothing else is needed.
`verifyImpl`'s lax parser accepts what BIP66's strict gate admits
(strict DER ⊂ lax domain — dual-route note), and for heights
below BIP66 (74638/91842/91880: `dersig = false`) the lax parse is the
consensus semantics itself.

## The real checker

`realCheckerOf tx nIn amount` builds the `ScriptChecker` for input `nIn`
of `tx` spending a coin of `amount`:

* ECDSA entry: `ecdsaEntry verifyImpl sighash true` — the sighash
  closure dispatches on `SigVersion` exactly as Core's
  `GenericTransactionSignatureChecker::VerifySignature`
  (interpreter.cpp:1718-1722): `WITNESS_V0 → SignatureHashBIP143`
  (BIP143, amount-carrying), else `SignatureHash` legacy. The
  `scriptCode`/hashtype reach it from the interpreter, which has
  already constructed the P2WPKH/P2WSH scriptCode.
* `realCheckerOf` retains the historical Boolean-only compatibility seam.
  Production uses `realCheckerWithTaproot`, which installs the typed
  `checkSchnorrForInput` callback with the exact transaction and complete
  ordered spent outputs. It performs real BIP341 hashing and BIP340 verification;
  missing data is an explicit unavailable result, not a false signature.
* `hasAmount = true`: the Capstone ledger always supplies the spent
  coin, so SWT-055's missing-data path is dead for anchor runs.

The locktime/sequence checks are `checkLockTimeDef` /
`checkSequenceDef` over `LocktimeEnv` (IC-2), threaded with the real
per-tx environment.
-/

namespace Bitcoin.Capstone.RealChecker

open Bitcoin.Crypto.Seam Bitcoin.Crypto.Ecdsa.Verify Bitcoin.SigHash
  Bitcoin.Data Bitcoin.Crypto.Seam.Entry

/-- Inhabited stand-in for `getD` on `tx.vin` (real inputs never hit it). -/
def dummyTxIn : TxIn := ⟨OutPoint.null, Script.empty, 0xFFFFFFFF⟩

/-- UInt8 hashtype → UInt32 (Core's `int nHashType` from the popped byte). -/
def htToU32 (ht : UInt8) : UInt32 := UInt32.ofNat ht.toNat

/-- The sighash closure: `WITNESS_V0 → BIP143`, else legacy
(interpreter.cpp:1718-1722, `VerifySignature`). -/
def sighashDispatch (tx : Tx) (nIn : Nat) (amount : Amount) :
    ByteArray → UInt8 → SigVersion → ByteArray :=
  fun scriptCode ht sv =>
    match sv with
    | SigVersion.witnessV0 =>
        signatureHashBip143 tx nIn ⟨scriptCode⟩ (htToU32 ht) amount
    | _ => signatureHashLegacy tx nIn ⟨scriptCode⟩ (htToU32 ht)

/-- **THE WIRING**: `ecdsaEntry` with the real ECDSA verifier. The Schnorr
slot stays the fail-closed stub. -/
@[rule "SGN-107", rule "SGN-110"]
def realEcdsaEntry (tx : Tx) (nIn : Nat) (amount : Amount) : BaseSignatureChecker :=
  ecdsaEntry Bitcoin.Crypto.Ecdsa.Verify.verifyImpl (sighashDispatch tx nIn amount) true

/-- Historical Boolean Schnorr compatibility entry: real BIP340 verifier,
with unavailable sighash data represented by none. Production installs the
typed `checkSchnorrForInput` callback through `realCheckerWithTaproot`, which
preserves exact errors and explicit unavailable-context outcomes. -/
@[rule "TPR-050", rule "TPR-051", rule "TPR-052"]
def realSchnorrEntry : BaseSignatureChecker :=
  schnorrEntry Bitcoin.Crypto.Schnorr.Verify.verifyImpl
    (fun _ _ _ => none)  -- BIP342 sighash: the Taproot and interpreter delta layers' slot (fail-closed stand-in)

/-- The full checker with BOTH real entries assembled (`txCheckerOf`):
real lax-ECDSA + real-BIP340-verifier Schnorr + the real locktime
environment. -/
def realCheckerFullOf (tx : Tx) (nIn : Nat) (amount : Amount) :
    Bitcoin.Interpreter.ScriptChecker :=
  { base := txCheckerOf Bitcoin.Crypto.Ecdsa.Verify.verifyImpl (sighashDispatch tx nIn amount) true
        Bitcoin.Crypto.Schnorr.Verify.verifyImpl (fun _ _ _ => none)
    env := { txVersion := tx.version
             txLockTime := tx.locktime
             txSequence := (tx.vin.getD nIn dummyTxIn).sequence } }

/-- The full per-input checker the interpreter layer's `verifyScript` consumes: real lax
ECDSA (BIP66-gated upstream), fail-closed Schnorr (slot), and the
real locktime environment (`LocktimeEnv` IC-2: tx version / locktime /
this input's nSequence). -/
def realCheckerOf (tx : Tx) (nIn : Nat) (amount : Amount) :
    Bitcoin.Interpreter.ScriptChecker :=
  { base := realEcdsaEntry tx nIn amount
    env := { txVersion := tx.version
             txLockTime := tx.locktime
             txSequence := (tx.vin.getD nIn dummyTxIn).sequence } }

/-- Typed production Schnorr adapter. Shape and hashtype failures are
adjudicable without transaction caches. Missing prevout/execution data is
explicitly unavailable, never an assumed pass or an invalid-signature verdict.
The supplied outputs are in vin order and belong to this exact transaction. -/
def checkSchnorrForInput (tx : Tx) (nIn : Nat) (spentOutputs : Option (List TxOut))
    (sig pk : ByteArray) (sv : SigVersion) (ed : ScriptExecutionData) :
    Except Bitcoin.Interpreter.ExecError Unit := do
  if ¬(sv = .taproot ∨ sv = .tapscript) ∨ pk.size ≠ 32 then
    throw Bitcoin.Interpreter.ExecError.schnorrSig
  if sig.size ≠ 64 ∧ sig.size ≠ 65 then
    throw Bitcoin.Interpreter.ExecError.schnorrSigSize
  let (body, ht) ← match schnorrHashtype sig with
    | none => throw Bitcoin.Interpreter.ExecError.schnorrSigHashtype
    | some value => pure value
  if !Bitcoin.Crypto.Taproot.hashtypeValid ht then
    throw Bitcoin.Interpreter.ExecError.schnorrSigHashtype
  if Bitcoin.Crypto.Taproot.htSingle ht && nIn ≥ tx.vout.length then
    throw Bitcoin.Interpreter.ExecError.schnorrSigHashtype
  let outputs ← match spentOutputs with
    | none => throw Bitcoin.Interpreter.ExecError.taprootDataUnavailable
    | some outputs => pure outputs
  if outputs.length ≠ tx.vin.length ∨ nIn ≥ tx.vin.length then
    throw Bitcoin.Interpreter.ExecError.taprootDataUnavailable
  if !ed.annexInit || (sv = .tapscript && (!ed.tapleafHashInit || !ed.codesepPosInit)) then
    throw Bitcoin.Interpreter.ExecError.taprootDataUnavailable
  let digest ← match Bitcoin.Crypto.Taproot.sighashTaproot ⟨tx, outputs⟩ nIn ht sv ed with
    | none => throw Bitcoin.Interpreter.ExecError.schnorrSigHashtype
    | some digest => pure digest
  if !Bitcoin.Crypto.Schnorr.Verify.verifyImpl body pk digest then
    throw Bitcoin.Interpreter.ExecError.schnorrSig

/-- The existing real ECDSA/environment assembly plus a typed BIP340/341
adapter. A partial caller can supply none; a live caller supplies every spent
output from its current ledger, before any of this transaction's inputs spend. -/
def realCheckerWithTaproot (tx : Tx) (nIn : Nat) (amount : Amount)
    (spentOutputs : Option (List TxOut)) : Bitcoin.Interpreter.ScriptChecker :=
  { realCheckerOf tx nIn amount with
    checkSchnorrTyped := some (checkSchnorrForInput tx nIn spentOutputs) }

end Bitcoin.Capstone.RealChecker
