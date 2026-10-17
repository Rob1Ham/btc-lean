import BitcoinProofs.Wallet.Sign.Spec
import Bitcoin.Interpreter.Defs

/-!
# Wallet signing — the conditional consensus bridge

This module connects the signer boundary (`BitcoinProofs.Wallet.Sign.Spec`)
to the committed interpreter's signature gate.  It states the bridge as a
proposition, proves the verifier-side implication that needs no
cryptography, and leaves the cryptographic link as an explicitly named,
unproved target.

## The two layers

1. **Verifier-side gate (proved).**  Core's `EvalChecksigPreTapscript`
   accepts an ECDSA signature when `CheckSignatureEncoding` returns no
   error, `CheckPubKeyEncoding` returns no error, and the checker's
   `CheckECDSASignature` entry point returns true
   (`src/script/interpreter.cpp:120-160,225-234,328-368,1701-1724` as
   recorded in `spec/db/rules-wallet.yaml`).  `bridge_conditional_psbt`
   proves that this gate accepts a signature produced for a PSBT input
   under `SignerSpec`, provided the encoded signature is strict-DER and
   has a defined sighash type, the encoded public key passes the pubkey
   check, low-S policy is satisfied (or disabled), and the checker's ECDSA
   entry point accepts.  The last condition is the only cryptographic
   hypothesis; the rest are structural.

2. **Signer soundness (target, no proof).**  `SignerBridgeTarget` is the
   same statement with the `EcdsaVerifies` hypothesis removed.  It says
   that `SignerSpec`, the PSBT request and the produced signature, together
   with the explicit structural encoding hypotheses, yield verifier
   acceptance.  The gap is exactly the missing cryptographic claim: the
   model has no ECDSA implementation and no argument that the abstract
   `(r, s)` produced by a `Signer` satisfies the verification equation
   under the requested key and digest.  It is a `Prop` with no proof; no
   `sorry`, `admit` or axiom is introduced.

## Trust boundary

The boundary is the pair of hypotheses that this layer cannot discharge:

* `encode : EcdsaSig → ByteArray` is an arbitrary serialiser.  The bridge
  assumes its output passes Core's strict-DER and defined-hashtype tests.
  No DER writer is modelled and no claim is made that a particular wallet
  serialises `(r, s)` this way.
* `EcdsaVerifies checker (encode sig) pk scriptCode sv ed` is the
  cryptographic verification verdict.  The consensus model exposes it as
  the checker's `CheckECDSASignature` entry point; this wallet layer does
  not implement it, prove it, or claim that a signer satisfying
  `SignerSpec` produces it.  The predicate records only the boolean
  verdict: Core recomputes the message digest inside the checker from its
  transaction environment, and the seam API does not expose that digest.
  Identifying the checker's internal digest with `req.digest` is therefore
  a further boundary assumption, not a theorem of this module.

The low-S requirement in `SignerSpec` is wallet/relay policy, not a
consensus acceptance condition; `bridge_conditional_psbt` therefore does
not derive acceptance from it.  Side channels, RFC 6979 conformance, key
secrecy, unforgeability and Schnorr/Taproot signing are entirely outside
the boundary (see the module note in `Spec`).

Core anchors are the line references recorded in
`spec/db/rules-wallet.yaml` for commit `cce32b168`.  The source tree may
not be present on every machine; the anchors above are the recorded
ground truth.
-/

namespace BitcoinProofs.Wallet.Sign

open Bitcoin.Data
open Bitcoin.Wallet.Psbt
open Bitcoin.Activation (ScriptFlags)
open Bitcoin.Crypto.Seam (BaseSignatureChecker ScriptExecutionData SigVersion)
open Bitcoin.Interpreter
  (PolicyFlags checkSigEncoding checkPubKeyEncoding isValidSigEncoding
   isDefinedHashtype checkLowS)

/-- The interpreter's ECDSA acceptance condition for one signature, at the
point where `EvalChecksigPreTapscript` decides success: encoding passes,
public-key encoding passes, and the checker's ECDSA entry point returns
true.  This is the verifier-side predicate the bridge targets. -/
def EcdsaAccepted (flags : ScriptFlags) (pol : PolicyFlags)
    (sv : SigVersion) (ed : ScriptExecutionData)
    (checker : BaseSignatureChecker) (sigBytes pk scriptCode : ByteArray) :
    Prop :=
  checkSigEncoding flags pol sigBytes = none ∧
    checkPubKeyEncoding flags pol sv pk = none ∧
    checker.checkECDSASignature sigBytes pk scriptCode sv ed = true

/-- The cryptographic half of the bridge, named so the trust boundary is
visible: the checker accepts the encoded signature under the public key,
scriptCode, signature version and execution data.  This is a verdict, not
a theorem of the wallet layer.  It does not say which message digest the
checker used; the core seam exposes a boolean verdict, not the recomputed
digest, so binding this verdict to the request's digest is outside the
model. -/
def EcdsaVerifies (checker : BaseSignatureChecker) (sigBytes pk scriptCode :
    ByteArray) (sv : SigVersion) (ed : ScriptExecutionData) : Prop :=
  checker.checkECDSASignature sigBytes pk scriptCode sv ed = true

/-- `CheckSignatureEncoding` returns `none` when the signature is strict
DER, has a defined sighash type (or STRICTENC is off), and satisfies the
low-S policy check when LOW_S is on.  These are the structural premises the
bridge supplies explicitly. -/
theorem checkSigEncoding_none_of
    (flags : ScriptFlags) (pol : PolicyFlags) (sig : ByteArray)
    (hder : isValidSigEncoding sig = true)
    (hlow : pol.lowS = false ∨
      checkLowS (sig.extract 0 (sig.size - 1)) = true)
    (hht : pol.strictEnc = false ∨ isDefinedHashtype sig = true) :
    checkSigEncoding flags pol sig = none := by
  unfold checkSigEncoding
  have hsize : sig.size ≠ 0 := by
    intro h
    unfold isValidSigEncoding at hder
    simp [h] at hder
  rcases hlow with hlow | hlow <;>
    rcases hht with hht | hht <;>
      simp [hsize, hder, hlow, hht]

/-- The conclusion of the conditional bridge: verifier acceptance together
with the observable specification facts that the signature carries the
requested sighash type and is low-S. -/
def BridgeConclusion (encode : EcdsaSig → ByteArray)
    (req : SignRequest) (sig : EcdsaSig) (pk scriptCode : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (sv : SigVersion)
    (ed : ScriptExecutionData) (checker : BaseSignatureChecker) : Prop :=
  EcdsaAccepted flags pol sv ed checker (encode sig) pk scriptCode ∧
    sig.hashType = req.hashType ∧
    sig.isLowS = true

/-- **Conditional bridge (proved).**  Suppose a PSBT input's signing
request is formed from its explicit sighash type and spent output, the
signer produces a signature for that request under `SignerSpec`, the
encoded signature is strict DER and has a defined sighash type, the low-S
policy check passes (or is disabled), the encoded public key passes the
pubkey check, and the consensus checker's ECDSA entry point accepts the
encoded signature.  Then the interpreter's ECDSA acceptance condition
holds, the signature carries the requested sighash type, and it is low-S.

The `_hreq` premise records the PSBT wiring; the verifier-side proof does
not inspect it, which is the point of the separation: `requestOf_digest`
(and `requestOf_bip143_preimage`) in `Spec` establish that the request's
digest is the core sighash of the input fields. -/
theorem bridge_conditional_psbt
    (encode : EcdsaSig → ByteArray)
    (s : Signer) (spec : SignerSpec s) (ks : List KeyMaterial)
    (p : Psbt) (k : Nat) (sc : Script) (v : EcdsaVersion) (key : Nat)
    (req : SignRequest) (sig : EcdsaSig) (pk : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (sv : SigVersion)
    (ed : ScriptExecutionData) (checker : BaseSignatureChecker)
    (_hreq : requestOf p k sc v key = some req)
    (hsign : s.sign ks req = some sig)
    (hder : isValidSigEncoding (encode sig) = true)
    (hht : isDefinedHashtype (encode sig) = true)
    (hlow : pol.lowS = false ∨
      checkLowS ((encode sig).extract 0 ((encode sig).size - 1)) = true)
    (hpk : checkPubKeyEncoding flags pol sv pk = none)
    (hver : EcdsaVerifies checker (encode sig) pk sc.bytes sv ed) :
    BridgeConclusion encode req sig pk sc.bytes flags pol sv ed checker := by
  have hsig : checkSigEncoding flags pol (encode sig) = none :=
    checkSigEncoding_none_of flags pol (encode sig) hder hlow (Or.inr hht)
  have htype : sig.hashType = req.hashType :=
    spec.hashTypeCommitted ks req sig hsign
  have hlowSig : sig.isLowS = true :=
    spec.lowSNormalised ks req sig hsign
  exact ⟨⟨hsig, hpk, hver⟩, htype, hlowSig⟩

/-- **TARGET — no proof.**  A PSBT input signed under `SignerSpec` yields a
signature that the consensus verifier accepts, for a fixed signature
serialiser and consensus checker, assuming the encoded signature is strict
DER, carries a defined sighash type, satisfies the low-S policy check when
enabled, and the encoded public key passes the pubkey check.

This is `bridge_conditional_psbt` with the `EcdsaVerifies` hypothesis
removed.  The gap is exactly the missing cryptographic claim: that the
abstract signer's output satisfies the ECDSA verification equation under
the requested key and digest.  The wallet layer has no ECDSA
implementation and no proof of that claim; this proposition is therefore a
target, not a theorem.  It is a `def ... : Prop`, so it introduces no
`sorry`, no `admit`, and no axiom. -/
def SignerBridgeTarget (encode : EcdsaSig → ByteArray)
    (checker : BaseSignatureChecker) : Prop :=
  ∀ (s : Signer), SignerSpec s →
    ∀ (ks : List KeyMaterial)
      (p : Psbt) (k : Nat) (sc : Script) (v : EcdsaVersion) (key : Nat)
      (req : SignRequest) (sig : EcdsaSig) (pk : ByteArray)
      (flags : ScriptFlags) (pol : PolicyFlags) (sv : SigVersion)
      (ed : ScriptExecutionData),
      requestOf p k sc v key = some req →
      s.sign ks req = some sig →
      isValidSigEncoding (encode sig) = true →
      isDefinedHashtype (encode sig) = true →
      (pol.lowS = false ∨
        checkLowS ((encode sig).extract 0 ((encode sig).size - 1)) = true) →
      checkPubKeyEncoding flags pol sv pk = none →
      EcdsaAccepted flags pol sv ed checker (encode sig) pk sc.bytes

/-! ## Axiom pins -/

#print axioms checkSigEncoding_none_of
#print axioms bridge_conditional_psbt

end BitcoinProofs.Wallet.Sign
