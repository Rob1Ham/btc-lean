import Bitcoin.Wallet.Psbt.Laws
import Bitcoin.SigHash.Interface
import Bitcoin.Crypto.Ecdsa.Der

/-!
# Wallet signing — the observable signer boundary

This module names the requirements a wallet signer must satisfy and proves
the parts of the boundary that are independent of elliptic-curve
cryptography.  It sits on top of the committed wallet models
(`Bitcoin.Wallet.Psbt.*`) and the consensus-digest definitions
(`Bitcoin.SigHash.*`); it does not extend or modify either.

## What is modelled

* `SignerSpec`: the observable requirements on a signing oracle — a
  deterministic nonce observation (the RFC 6979 property, stated as
  determinism in the key and message digest), low-S output form, an
  explicit sighash-type commitment, per-key isolation, and refusal when the
  requested key is absent.
* `EcdsaSig`: the mathematical content of an ECDSA signature (the pair
  `(r, s)`) together with the sighash type that the wallet attaches to it.
* `EcdsaSig.normaliseLowS`: the low-S normalisation rule on that
  representation, and its idempotence.
* `requestOf`: the signing request derived from a PSBT input — its digest
  is the legacy or BIP143 sighash of the unsigned transaction, the input
  index, the scriptCode, the explicitly stored sighash type and the spent
  amount.
* The sighash preimage is a function of exactly those input fields: two
  PSBTs that agree on the unsigned transaction, the input index, the
  scriptCode, the sighash type and the spent output have the same preimage,
  regardless of every other PSBT field.
* Finalising one input replaces only that input map; every other input
  map, and therefore every other input's signing request, is unchanged.

## What is NOT modelled or claimed

* **No ECDSA implementation.**  There is no scalar multiplication, modular
  inverse, RFC 6979 HMAC-DRBG, DER writer or signing algorithm in this
  layer.  `Signer.sign` is an abstract oracle; `EcdsaSig` is not a byte
  encoding.  Nothing here proves that a signer can produce a signature, or
  that a produced `(r, s)` satisfies the ECDSA verification equation.
* **No cryptographic soundness.**  No claim is made about key secrecy,
  unforgeability, nonce reuse resistance, fault resistance, or the
  relationship between a private key and a public key.
* **No side-channel claim.**  Timing, memory-access patterns, power,
  electromagnetic emanations and every other side channel are outside the
  model; `SideChannelNonClaim` records that absence explicitly.
* **No DER/byte-level signature claim.**  The low-S result is about the
  mathematical pair `(r, s)`, not about rewriting a DER byte string.  It
  also does not claim that low-S is a consensus rule: Core's verifier
  accepts high-S; low-S is wallet/relay policy.
* **No Schnorr/Taproot signing.**  The boundary covers ECDSA over the
  legacy and BIP143 digests only.  BIP340/BIP341 signing, taproot tweaks,
  annexes, `OP_CODESEPARATOR` in tapscript and MuSig2 are not modelled.
* **PSBT signing policy** — which keys a wallet owns, which inputs it
  signs, SIGHASH_DEFAULT aliasing, and signature ordering — is not modelled.

Core anchors used below are the line references recorded in
`spec/db/rules-wallet.yaml` for Bitcoin Core commit `cce32b168`:
`src/script/interpreter.cpp:120-160` (`CheckSignatureEncoding`),
`src/script/interpreter.cpp:1701-1724` (`CheckECDSASignature`),
`src/pubkey.cpp::ecdsa_signature_parse_der_lax`, and
`src/psbt.h:371-506` (signing fields suppressed on finalisation).

## Signature representation

`EcdsaSig` stores `r`, `s` and the four-byte sighash type.  The DER byte
string and the trailing one-byte sighash type are deliberately absent.
`isLowS` uses the same bound as the consensus model's policy predicate
(`Bitcoin.Crypto.Ecdsa.Der.halfN`): `s % n ≤ n / 2`.
-/

namespace BitcoinProofs.Wallet.Sign

open Bitcoin.Data
open Bitcoin.Wallet.Psbt
open Bitcoin.Serialization (Bytes bL)
open Bitcoin.Crypto.Curve.Secp (n)

/-! ## Signer observations and requirements -/

/-- Opaque key identity.  The private key itself is not represented.  A
wallet may hold several `KeyMaterial` entries; `id` is the label a signing
request selects. -/
structure KeyMaterial where
  id : Nat
deriving Repr, BEq

/-- One signing request: the selected key label, the 32-byte digest to be
signed, and the sighash type that the signature must carry. -/
structure SignRequest where
  key : Nat
  digest : ByteArray
  hashType : UInt32
deriving Repr, BEq

/-- The mathematical content of an ECDSA signature: the pair `(r, s)` plus
the sighash type.  The DER serialisation and the trailing sighash byte are
not part of this representation. -/
structure EcdsaSig where
  r : Nat
  s : Nat
  hashType : UInt32
deriving Repr, BEq

/-- A signing oracle.  `sign` is uninterpreted: no curve arithmetic or
nonce generation is implemented in this layer.  `nonce` is the model-level
observation of the nonce; it is not recoverable from `(r, s)` and no claim
is made that it equals RFC 6979's output. -/
structure Signer where
  sign : List KeyMaterial → SignRequest → Option EcdsaSig
  nonce : List KeyMaterial → SignRequest → Nat

/-- Look up a key by its label.  `none` means the signer does not hold the
requested key. -/
def keyById (ks : List KeyMaterial) (id : Nat) : Option KeyMaterial :=
  ks.find? (fun k => k.id == id)

/-! ## Low-S representation -/

/-- Low-S in the model's `(r, s)` representation: `s` reduced modulo the
group order is at most `n / 2`, the same bound as
`Bitcoin.Crypto.Ecdsa.Der.halfN`. -/
def EcdsaSig.isLowS (sig : EcdsaSig) : Bool :=
  sig.s % n ≤ Bitcoin.Crypto.Ecdsa.Der.halfN

/-- Low-S normalisation: replace `s` by its residue when that residue is
already low, otherwise by `n` minus that residue.  `r` and the sighash type
are unchanged.  This is a rule on the mathematical pair, not a DER
re-encoder. -/
def EcdsaSig.normaliseLowS (sig : EcdsaSig) : EcdsaSig :=
  if sig.isLowS then { sig with s := sig.s % n }
  else { sig with s := n - sig.s % n }

/-- The explicit non-claim: the model says nothing about side channels.
This proposition is `True` because the model deliberately omits timing,
power, cache, memory-access and electromagnetic observations.  It is not a
security claim and must not be read as one. -/
def SideChannelNonClaim : Prop := True

/-- Observable requirements on a signer.

`nonceDeterministic` is the RFC 6979 property as far as this layer can
state it: the observed nonce is a function of the selected key material and
the message digest.  The concrete HMAC-DRBG construction of RFC 6979 is not
modelled, so this is determinism, not RFC 6979 conformance.

`lowSNormalised` is a wallet/relay-policy requirement.  It is not a
consensus rule and is not used by the bridge as an acceptance condition.
-/
structure SignerSpec (s : Signer) : Prop where
  /-- Same selected key and same digest imply the same observed nonce. -/
  nonceDeterministic :
    ∀ (ks ks' : List KeyMaterial) (req req' : SignRequest),
      keyById ks req.key = keyById ks' req'.key →
      req.digest = req'.digest →
      s.nonce ks req = s.nonce ks' req'
  /-- Every produced signature is low-S in the model's representation. -/
  lowSNormalised :
    ∀ (ks : List KeyMaterial) (req : SignRequest) (sig : EcdsaSig),
      s.sign ks req = some sig → sig.isLowS = true
  /-- The signature carries exactly the requested sighash type. -/
  hashTypeCommitted :
    ∀ (ks : List KeyMaterial) (req : SignRequest) (sig : EcdsaSig),
      s.sign ks req = some sig → sig.hashType = req.hashType
  /-- The result depends only on the selected key, not on other key
  material the signer may hold. -/
  keyIsolation :
    ∀ (ks ks' : List KeyMaterial) (req : SignRequest),
      keyById ks req.key = keyById ks' req.key →
      s.sign ks req = s.sign ks' req
  /-- A request for an absent key produces no signature. -/
  missingKeyRefuses :
    ∀ (ks : List KeyMaterial) (req : SignRequest),
      keyById ks req.key = none → s.sign ks req = none
  /-- The explicit side-channel non-claim. -/
  sideChannelsNotClaimed : SideChannelNonClaim

/-! ## Low-S normalisation -/

/-- Low-S normalisation is idempotent.  The only arithmetic used is that the
group order is odd (`n = 2 * (n / 2) + 1`), so `n - (s % n)` lies below
`n / 2` whenever `s % n` lies above it. -/
theorem EcdsaSig.normaliseLowS_idempotent (sig : EcdsaSig) :
    sig.normaliseLowS.normaliseLowS = sig.normaliseLowS := by
  have hn : 0 < n := Bitcoin.Crypto.Curve.Secp.n_pos
  have hodd : n = 2 * (n / 2) + 1 := by
    have h := Nat.div_add_mod n 2
    have h1 : n % 2 = 1 := by decide
    rw [h1] at h
    omega
  unfold EcdsaSig.normaliseLowS EcdsaSig.isLowS
    Bitcoin.Crypto.Ecdsa.Der.halfN
  by_cases h : sig.s % n ≤ n / 2
  · simp [h, Nat.mod_eq_of_lt (Nat.mod_lt _ hn)]
  · simp [h]
    have hlt : sig.s % n < n := Nat.mod_lt _ hn
    have hle : n - sig.s % n ≤ n / 2 := by omega
    simp [hle, Nat.mod_eq_of_lt (by omega : n - sig.s % n < n)]

/-- The normalised signature is low-S. -/
theorem EcdsaSig.normaliseLowS_isLow (sig : EcdsaSig) :
    sig.normaliseLowS.isLowS = true := by
  have hn : 0 < n := Bitcoin.Crypto.Curve.Secp.n_pos
  have hodd : n = 2 * (n / 2) + 1 := by
    have h := Nat.div_add_mod n 2
    have h1 : n % 2 = 1 := by decide
    rw [h1] at h
    omega
  unfold EcdsaSig.normaliseLowS EcdsaSig.isLowS
    Bitcoin.Crypto.Ecdsa.Der.halfN
  by_cases h : sig.s % n ≤ n / 2
  · simp [h, Nat.mod_eq_of_lt (Nat.mod_lt _ hn)]
  · simp [h]
    have hlt : sig.s % n < n := Nat.mod_lt _ hn
    have hle : n - sig.s % n ≤ n / 2 := by omega
    simp [hle, Nat.mod_eq_of_lt (by omega : n - sig.s % n < n)]

/-- Normalisation preserves the `r` component. -/
theorem EcdsaSig.normaliseLowS_r (sig : EcdsaSig) :
    sig.normaliseLowS.r = sig.r := by
  unfold EcdsaSig.normaliseLowS
  split <;> rfl

/-- Normalisation preserves the sighash-type commitment. -/
theorem EcdsaSig.normaliseLowS_hashType (sig : EcdsaSig) :
    sig.normaliseLowS.hashType = sig.hashType := by
  unfold EcdsaSig.normaliseLowS
  split <;> rfl

/-! ## Structural consequences of the specification -/

/-- The observed nonce depends only on the selected key and the digest. -/
theorem SignerSpec.nonce_eq_of_selected_key_and_digest {s : Signer}
    (spec : SignerSpec s) {ks ks' : List KeyMaterial}
    {req req' : SignRequest}
    (hkey : keyById ks req.key = keyById ks' req'.key)
    (hdigest : req.digest = req'.digest) :
    s.nonce ks req = s.nonce ks' req' :=
  spec.nonceDeterministic ks ks' req req' hkey hdigest

/-- A produced signature carries the requested sighash type. -/
theorem SignerSpec.hashType_of_sign {s : Signer} (spec : SignerSpec s)
    {ks : List KeyMaterial} {req : SignRequest} {sig : EcdsaSig}
    (h : s.sign ks req = some sig) : sig.hashType = req.hashType :=
  spec.hashTypeCommitted ks req sig h

/-- A produced signature is low-S. -/
theorem SignerSpec.isLowS_of_sign {s : Signer} (spec : SignerSpec s)
    {ks : List KeyMaterial} {req : SignRequest} {sig : EcdsaSig}
    (h : s.sign ks req = some sig) : sig.isLowS = true :=
  spec.lowSNormalised ks req sig h

/-- The signing result does not depend on key material other than the
selected key. -/
theorem SignerSpec.sign_eq_of_selected_key {s : Signer} (spec : SignerSpec s)
    {ks ks' : List KeyMaterial} {req : SignRequest}
    (h : keyById ks req.key = keyById ks' req.key) :
    s.sign ks req = s.sign ks' req :=
  spec.keyIsolation ks ks' req h

/-- An absent key yields no signature. -/
theorem SignerSpec.sign_eq_none_of_absent_key {s : Signer} (spec : SignerSpec s)
    {ks : List KeyMaterial} {req : SignRequest}
    (h : keyById ks req.key = none) : s.sign ks req = none :=
  spec.missingKeyRefuses ks req h

/-! ## Sighash requests from PSBT inputs -/

/-- The two ECDSA signature versions in scope.  Taproot and tapscript are
absent by construction; Schnorr signing is outside this boundary. -/
inductive EcdsaVersion where
  | base
  | witnessV0
deriving Repr, DecidableEq, BEq

/-- The consensus digest selected by the signature version.  `base` is the
legacy serialisation; `witnessV0` is the BIP143 ten-field preimage.  Both
are the committed core definitions, unchanged. -/
def digestOf (v : EcdsaVersion) (tx : Tx) (k : Nat) (sc : Script)
    (ht : UInt32) (amount : Amount) : ByteArray :=
  match v with
  | .base => Bitcoin.SigHash.signatureHashLegacy tx k sc ht
  | .witnessV0 => Bitcoin.SigHash.signatureHashBip143 tx k sc ht amount

/-- The explicitly stored sighash type of a PSBT input.  `none` means the
input does not carry `PSBT_IN_SIGHASH`; default selection is not modelled,
so a request is formed only when the type is explicit. -/
def inputSighashType (p : Psbt) (k : Nat) : Option UInt32 :=
  (p.inputs[k]?).bind (fun i => i.sighashType)

/-- The signing request for input `k`: it exists only when the input map
has an explicit sighash type and the spent output is available.  The digest
is computed from the unsigned transaction, the input index, the supplied
scriptCode, the stored sighash type and the spent amount.  No default
sighash type, annex, taproot leaf hash or `OP_CODESEPARATOR` position is
invented. -/
def requestOf (p : Psbt) (k : Nat) (sc : Script) (v : EcdsaVersion)
    (key : Nat) : Option SignRequest :=
  match inputSighashType p k, spentOutput p k with
  | some ht, some out =>
      some { key := key
             digest := digestOf v p.global.unsignedTx k sc ht out.value
             hashType := ht }
  | _, _ => none

/-- A successful request exposes the input's explicit sighash type and the
spent output it used. -/
theorem requestOf_some (p : Psbt) (k : Nat) (sc : Script) (v : EcdsaVersion)
    (key : Nat) (req : SignRequest) (h : requestOf p k sc v key = some req) :
    ∃ (ht : UInt32) (out : TxOut),
      inputSighashType p k = some ht ∧ spentOutput p k = some out ∧
        req = { key := key
                digest := digestOf v p.global.unsignedTx k sc ht out.value
                hashType := ht } := by
  unfold requestOf at h
  split at h
  · rename_i ht out hts hout
    simp only [Option.some.injEq] at h
    exact ⟨ht, out, hts, hout, h.symm⟩
  · simp at h

/-- The digest and sighash type of a successful request are exactly the
ones computed from the input fields. -/
theorem requestOf_digest (p : Psbt) (k : Nat) (sc : Script) (v : EcdsaVersion)
    (key : Nat) (req : SignRequest) (h : requestOf p k sc v key = some req) :
    ∃ (ht : UInt32) (out : TxOut),
      req.hashType = ht ∧
        req.digest = digestOf v p.global.unsignedTx k sc ht out.value := by
  obtain ⟨ht, out, _, _, rfl⟩ := requestOf_some p k sc v key req h
  exact ⟨ht, out, rfl, rfl⟩

/-! ## Sighash preimages are determined by the input fields -/

/-- The legacy preimage (the modified transaction serialisation, before the
four-byte sighash suffix) as a function of the PSBT's unsigned transaction,
the input index, the scriptCode and the sighash type.  No other PSBT field
enters. -/
def legacyPreimageOf (p : Psbt) (k : Nat) (sc : Script) (ht : UInt32) :
    Bytes :=
  Bitcoin.SigHash.legacyPreimageL p.global.unsignedTx k (bL sc.bytes) ht

/-- The BIP143 ten-field preimage as a function of the PSBT's unsigned
transaction, the input index, the scriptCode, the sighash type and the
spent amount.  It is `none` when no spent output is available.  No other
PSBT field enters. -/
def bip143PreimageOf (p : Psbt) (k : Nat) (sc : Script) (ht : UInt32) :
    Option Bytes :=
  (spentOutput p k).map (fun o =>
    Bitcoin.SigHash.bip143MsgL p.global.unsignedTx k (bL sc.bytes) ht o.value)

/-- Equal unsigned transactions, input indices, scriptCodes and sighash
types give equal legacy preimages, whatever else the two PSBTs contain. -/
theorem legacyPreimageOf_eq_of_fields
    (p q : Psbt) (k l : Nat) (sc sc' : Script) (ht ht' : UInt32)
    (htx : p.global.unsignedTx = q.global.unsignedTx)
    (hk : k = l) (hsc : sc = sc') (hht : ht = ht') :
    legacyPreimageOf p k sc ht = legacyPreimageOf q l sc' ht' := by
  unfold legacyPreimageOf
  rw [htx, hk, hsc, hht]

/-- Equal unsigned transactions, input indices, scriptCodes, sighash types
and spent outputs give equal BIP143 preimages, whatever else the two PSBTs
contain.  The spent output enters only through its amount. -/
theorem bip143PreimageOf_eq_of_fields
    (p q : Psbt) (k l : Nat) (sc sc' : Script) (ht ht' : UInt32)
    (htx : p.global.unsignedTx = q.global.unsignedTx)
    (hk : k = l) (hsc : sc = sc') (hht : ht = ht')
    (hutxo : spentOutput p k = spentOutput q l) :
    bip143PreimageOf p k sc ht = bip143PreimageOf q l sc' ht' := by
  unfold bip143PreimageOf
  rw [hk] at hutxo ⊢
  rw [htx, hsc, hht, hutxo]

/-- The legacy digest is likewise determined by the same input fields. -/
theorem legacyDigestOf_eq_of_fields
    (p q : Psbt) (k l : Nat) (sc sc' : Script) (ht ht' : UInt32)
    (htx : p.global.unsignedTx = q.global.unsignedTx)
    (hk : k = l) (hsc : sc = sc') (hht : ht = ht') :
    Bitcoin.SigHash.signatureHashLegacy p.global.unsignedTx k sc ht =
      Bitcoin.SigHash.signatureHashLegacy q.global.unsignedTx l sc' ht' := by
  rw [htx, hk, hsc, hht]

/-- The BIP143 digest is determined by the same input fields, including the
spent output. -/
theorem bip143DigestOf_eq_of_fields
    (p q : Psbt) (k l : Nat) (sc sc' : Script) (ht ht' : UInt32)
    (htx : p.global.unsignedTx = q.global.unsignedTx)
    (hk : k = l) (hsc : sc = sc') (hht : ht = ht')
    (amt amt' : Amount) (hamount : amt = amt') :
    Bitcoin.SigHash.signatureHashBip143 p.global.unsignedTx k sc ht amt =
      Bitcoin.SigHash.signatureHashBip143 q.global.unsignedTx l sc' ht' amt' := by
  rw [htx, hk, hsc, hht, hamount]

/-- The BIP143 preimage of a successful request is the core BIP143
preimage at the request's digest fields. -/
theorem requestOf_bip143_preimage (p : Psbt) (k : Nat) (sc : Script)
    (key : Nat) (req : SignRequest) (h : requestOf p k sc .witnessV0 key = some req) :
    ∃ (ht : UInt32) (out : TxOut),
      req.hashType = ht ∧
        bip143PreimageOf p k sc ht =
          some (Bitcoin.SigHash.bip143MsgL p.global.unsignedTx k
            (bL sc.bytes) ht out.value) := by
  obtain ⟨ht, out, hts, hout, rfl⟩ := requestOf_some p k sc .witnessV0 key req h
  refine ⟨ht, out, rfl, ?_⟩
  unfold bip143PreimageOf
  rw [hout]
  rfl

/-! ## Finalising one input leaves the other inputs unchanged -/

/-- Replace input map `k` by `i`.  Out-of-range `k` leaves the list
unchanged (`List.set` semantics). -/
def finalizeAt (p : Psbt) (k : Nat) (i : PsbtInput) : Psbt :=
  { p with inputs := p.inputs.set k i }

/-- Finalise input `k` with a scriptSig and witness stack.  When `k` is
out of range the PSBT is returned unchanged. -/
def finalizeAtWith (p : Psbt) (k : Nat) (scriptSig : ByteArray)
    (witness : List ByteArray) : Psbt :=
  match p.inputs[k]? with
  | none => p
  | some i => finalizeAt p k (Bitcoin.Wallet.Psbt.finalizeInput i scriptSig witness)

/-- The global map is untouched by `finalizeAt`. -/
theorem finalizeAt_global (p : Psbt) (k : Nat) (i : PsbtInput) :
    (finalizeAt p k i).global = p.global := rfl

/-- The output maps are untouched by `finalizeAt`. -/
theorem finalizeAt_outputs (p : Psbt) (k : Nat) (i : PsbtInput) :
    (finalizeAt p k i).outputs = p.outputs := rfl

/-- Every other input map is untouched by `finalizeAt`. -/
theorem finalizeAt_inputs_other (p : Psbt) (k : Nat) (i : PsbtInput)
    (j : Nat) (h : j ≠ k) :
    (finalizeAt p k i).inputs[j]? = p.inputs[j]? := by
  simp [finalizeAt, List.getElem?_set_ne h.symm]

/-- The selected input map is exactly the replacement, when `k` is in
range. -/
theorem finalizeAt_inputs_self (p : Psbt) (k : Nat) (i : PsbtInput)
    (h : k < p.inputs.length) :
    (finalizeAt p k i).inputs[k]? = some i := by
  simp [finalizeAt, List.getElem?_set_self h]

/-- Every other input map is untouched by `finalizeAtWith`. -/
theorem finalizeAtWith_inputs_other (p : Psbt) (k j : Nat)
    (scriptSig : ByteArray) (witness : List ByteArray) (h : j ≠ k) :
    (finalizeAtWith p k scriptSig witness).inputs[j]? = p.inputs[j]? := by
  unfold finalizeAtWith
  split
  · rfl
  · exact finalizeAt_inputs_other p k _ j h

/-- The selected input map is exactly Core's `finalizeInput` applied to it. -/
theorem finalizeAtWith_inputs_self (p : Psbt) (k : Nat)
    (scriptSig : ByteArray) (witness : List ByteArray)
    (h : k < p.inputs.length) :
    (finalizeAtWith p k scriptSig witness).inputs[k]? =
      some (Bitcoin.Wallet.Psbt.finalizeInput p.inputs[k] scriptSig witness) := by
  unfold finalizeAtWith
  rw [List.getElem?_eq_getElem h]
  simp only
  exact finalizeAt_inputs_self p k _ h

/-- Finalising input `k` does not change the spent output selected for any
other input `j`. -/
theorem spentOutput_finalizeAt_other (p : Psbt) (k j : Nat) (i : PsbtInput)
    (h : j ≠ k) :
    spentOutput (finalizeAt p k i) j = spentOutput p j := by
  unfold spentOutput finalizeAt
  simp [List.getElem?_set_ne h.symm]

/-- Finalising input `k` does not change the signing request for any other
input `j`: the unsigned transaction, the other input map and the other
spent output are all untouched. -/
theorem requestOf_finalizeAt_other (p : Psbt) (k j : Nat) (i : PsbtInput)
    (sc : Script) (v : EcdsaVersion) (key : Nat) (h : j ≠ k) :
    requestOf (finalizeAt p k i) j sc v key = requestOf p j sc v key := by
  unfold requestOf inputSighashType
  rw [finalizeAt_inputs_other p k i j h]
  rw [spentOutput_finalizeAt_other p k j i h]
  rw [finalizeAt_global]

/-- The same invariance for the higher-level finalisation operation. -/
theorem requestOf_finalizeAtWith_other (p : Psbt) (k j : Nat)
    (scriptSig : ByteArray) (witness : List ByteArray)
    (sc : Script) (v : EcdsaVersion) (key : Nat) (h : j ≠ k) :
    requestOf (finalizeAtWith p k scriptSig witness) j sc v key =
      requestOf p j sc v key := by
  unfold finalizeAtWith
  split
  · rfl
  · exact requestOf_finalizeAt_other p k j _ sc v key h

/-- The low-S normalisation is also idempotent when applied to every
component of a signature list, which is how a wallet would normalise the
partial signatures of one input. -/
theorem normaliseLowS_list_idempotent (sigs : List EcdsaSig) :
    (sigs.map EcdsaSig.normaliseLowS).map EcdsaSig.normaliseLowS =
      sigs.map EcdsaSig.normaliseLowS := by
  induction sigs with
  | nil => rfl
  | cons sig rest ih =>
      simp only [List.map_cons, ih, EcdsaSig.normaliseLowS_idempotent]

/-! ## Axiom pins for the proved structural results -/

#print axioms EcdsaSig.normaliseLowS_idempotent
#print axioms EcdsaSig.normaliseLowS_isLow
#print axioms requestOf_some
#print axioms requestOf_digest
#print axioms legacyPreimageOf_eq_of_fields
#print axioms bip143PreimageOf_eq_of_fields
#print axioms legacyDigestOf_eq_of_fields
#print axioms bip143DigestOf_eq_of_fields
#print axioms requestOf_bip143_preimage
#print axioms finalizeAt_inputs_other
#print axioms finalizeAtWith_inputs_self
#print axioms requestOf_finalizeAtWith_other
#print axioms normaliseLowS_list_idempotent

end BitcoinProofs.Wallet.Sign
