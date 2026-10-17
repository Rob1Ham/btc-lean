import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Crypto.Ecdsa.Verify
import Bitcoin.Crypto.Schnorr.Verify
import Bitcoin.SigHash.Interface
import Bitcoin.Data.Tx
import Bitcoin.Interpreter.Defs

/-!
# Bitcoin.Capstone.RealChecker — S2a: the W14b → W13 wiring

THE one wiring left in Review 2 (W13 handoff, w2-13 §4): instantiate the
abstract `verify` parameter of `ecdsaEntry` with W14b's real verifier
`Bitcoin.Crypto.Ecdsa.Verify.verifyImpl` (215/215 conformance, lax
semantics = Core `CPubKey::Verify`), leaving W13's `Entry.lean` untouched.

## Flag gate (BIP66 strict / lax)

The seam's ECDSA entry is CONTRACTUALLY lax (DECISIONS.md OPEN-002): the
DER strictness is enforced by the interpreter's BIP66 gate
(`Seam/Der.checkSignatureEncoding` via W09's `checkSigEncoding`, flags
from W06's `getBlockScriptFlags`), BEFORE the adapter is ever reached —
exactly Core's order (interpreter.cpp:1172/1183 call
`CheckSignatureEncoding` first, `CheckECDSASignature` sees only
gate-passing sigs). So "wiring behind the flag-gate" = `verifyImpl` here +
the interpreter's flag-driven DER gate upstream; nothing else is needed.
`verifyImpl`'s lax parser accepts what BIP66's strict gate admits
(strict DER ⊂ lax domain — W14b's dual-route note), and for heights
below BIP66 (74638/91842/91880: `dersig = false`) the lax parse is the
consensus semantics itself.

## The real checker

`realCheckerOf tx nIn amount` builds the `ScriptChecker` for input `nIn`
of `tx` spending a coin of `amount`:

* ECDSA entry: `ecdsaEntry verifyImpl sighash true` — the sighash
  closure dispatches on `SigVersion` exactly as Core's
  `GenericTransactionSignatureChecker::VerifySignature`
  (interpreter.cpp:1718-1722): `WITNESS_V0 → SignatureHashBIP143`
  (W11, amount-carrying), else `SignatureHash` legacy (W11). The
  `scriptCode`/hashtype reach it from W09's interpreter, which has
  already constructed the P2WPKH/P2WSH scriptCode.
* Schnorr entry: `schnorrEntry` with the Review-3 fail-closed stub
  (`verify := fun _ _ _ => false`, `sighashSchnorr := fun _ _ _ =>
  none`) — Taproot spends cannot verify; the Capstone block layer
  routes v1-witness inputs to an explicit "unjudged" lane instead of
  letting them fail-closed (documented depth semantics, W17 report §3).
* `hasAmount = true`: the Capstone ledger always supplies the spent
  coin, so SWT-055's missing-data path is dead for anchor runs.

The locktime/sequence checks are W09's `checkLockTimeDef` /
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

/-- **THE WIRING**: `ecdsaEntry` with W14b's real verifier. The Schnorr
slot stays the Review-3 fail-closed stub. -/
@[rule "SGN-107", rule "SGN-110"]
def realEcdsaEntry (tx : Tx) (nIn : Nat) (amount : Amount) : BaseSignatureChecker :=
  ecdsaEntry verifyImpl (sighashDispatch tx nIn amount) true

/-- **THE SCHNORR WIRING (X02)**: `schnorrEntry` with the REAL BIP340
verifier `Bitcoin.Crypto.Schnorr.Verify.verifyImpl` (19/19 official
vectors incl. negatives). W13's gates are untouched — `schnorrVerdict`
still enforces, upstream of the EC math: the taproot/tapscript sigversion
restriction (fail-closed otherwise), the 32-byte key gate, the 64/65-byte
signature size gate with the SIGHASH_DEFAULT 65th-byte rule
(`schnorrHashtype`), and the missing-txdata fail-closed path. The BIP342
sighash function itself (`sighashSchnorr`) is X03/X04's lane and REMAINS
the fail-closed `none` stand-in here — flipping it is a one-parameter
change with this file as the single wiring point, exactly as W13's
handoff prescribed. Until then, key-path spends reach `verifyImpl` only
once a real sighash lands; every gate above it is already real. -/
@[rule "TPR-050", rule "TPR-051", rule "TPR-052"]
def realSchnorrEntry : BaseSignatureChecker :=
  schnorrEntry Bitcoin.Crypto.Schnorr.Verify.verifyImpl
    (fun _ _ _ => none)  -- BIP342 sighash: X03/X04 slot (fail-closed stand-in)

/-- The full checker with BOTH real entries assembled (`txCheckerOf`):
real lax-ECDSA + real-BIP340-verifier Schnorr + the real locktime
environment. -/
def realCheckerFullOf (tx : Tx) (nIn : Nat) (amount : Amount) :
    Bitcoin.Interpreter.ScriptChecker :=
  { base := txCheckerOf verifyImpl (sighashDispatch tx nIn amount) true
        Bitcoin.Crypto.Schnorr.Verify.verifyImpl (fun _ _ _ => none)
    env := { txVersion := tx.version
             txLockTime := tx.locktime
             txSequence := (tx.vin.getD nIn dummyTxIn).sequence } }

/-- The full per-input checker W09's `verifyScript` consumes: real lax
ECDSA (BIP66-gated upstream), fail-closed Schnorr (Review-3 slot), and the
real locktime environment (`LocktimeEnv` IC-2: tx version / locktime /
this input's nSequence). -/
def realCheckerOf (tx : Tx) (nIn : Nat) (amount : Amount) :
    Bitcoin.Interpreter.ScriptChecker :=
  { base := realEcdsaEntry tx nIn amount
    env := { txVersion := tx.version
             txLockTime := tx.locktime
             txSequence := (tx.vin.getD nIn dummyTxIn).sequence } }

end Bitcoin.Capstone.RealChecker
