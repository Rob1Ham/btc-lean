import Bitcoin.Capstone.RealChecker
import Bitcoin.SigHash.Theorems

/-!
# BitcoinProofs.Theorems.T3T4SighashCor — THM-032c/033c-ECDSA, the
# sighash-injectivity corollary tier (X10, Review 3, Module B)

C4 portfolio rows **THM-032c** (Tier 3, "sighash injectivity
corollaries") and the **ECDSA half of THM-033c** (real-dispatch totality;
the BIP341 half is X03's lane), proved over W11's frozen
`Bitcoin.SigHash` + W14b/X02's real checker wiring
(`Bitcoin.Capstone.RealChecker`).

## What this module proves

* **THM-032c (msg-level raw-hashtype injectivity)** — both preimages
  (`legacyMsgL`, `bip143MsgL`) end in the raw 4-byte LE `nHashType`
  (`ss << nHashType`, interpreter.cpp:1684-1686), so the **message
  determines the FULL hashtype, not just the class** ((I) + B1), whenever
  the hashtype classes agree (W11's `*_determined` family, class level).
* **THM-032c (digest-level, conditional)** — the same at the digest
  level (B2), **conditional on a named `dsha256`-injectivity hypothesis**
  (`Hdsha : ∀ a b, dshaL a = dshaL b → a = b`) — never an axiom, never
  assumed silently (W14 discipline: W14b's dsha256 is not kernel-reduced
  here), and only on the honest domain: same class, in-range `nIn`,
  non-overflow corner.
* **THM-032c (the honest blindness-corner map, B3)** — out-of-range
  `nIn` blinds the digest to everything (the zero hash, both lanes);
  out-of-range legacy SINGLE blinds it to the constant `uint256::ONE`
  (witnessV0 lane EXEMPT — BIP143 has no ONE early return: the tri-modal
  SIGHASH_SINGLE divergence, W11 `legacyImpl_single_oor` /
  `bip143_single_oor`). On these corners **injectivity provably FAILS**:
  the naive "distinct (tx, idx, hashtype) → distinct digests" is FALSE
  as stated (sanctioned statement-fidelity path, report §5).
* **THM-033c-ECDSA-half (real-dispatch totality)** — the REAL checker's
  `sighashDispatch` is total, deterministic, and case-exhaustive in the
  sigversion (B4a: `witnessV0 → BIP143`, else legacy — all four
  `SigVersion` constructors covered), pure in the environment and in its
  script-visible arguments (B4c/B4d), and W11's Impl-level
  `*_determined` lifts to the Script level the dispatch actually calls
  (B0a/B0b) and through the dispatch itself (B0c/B0d). W13's
  `ecdsaEntry_pops_hashtype` — the hashtype-pop totality: whatever the
  verdict, the signature reaches the verifier only as
  `sig.extract 0 (sig.size - 1)` against the digest of
  `(scriptCode, popped byte, sigversion)` — holds at the real entry
  (`realEcdsaEntry`, B4b) with `hasAmount = true`, so the WITNESS_V0
  missing-amount gate (SWT-055) is INERT at the seam: the
  amount-availability obligation is the pipeline's (Module C).

## Statement-fidelity notes (sanctioned statement-wrong path, §5)

* **Digest-level cross-hashtype determinism is NOT claimed** — and never
  was: W11's Theorems.lean docstring itself says the raw `serU32L ht`
  suffix is the one class-independent hashtype dependence (messages
  ending in `serU32L 0x01` vs `serU32L 0x21` share a class but hash
  differently). B pins the honest raw-suffix INJECTIVITY (same class +
  same message ⇒ same full hashtype) instead of a false determinism.
* **The naive injectivity statement is FALSE** (blindness corners, B3):
  the honest domain is exactly the in-range, non-overflow corner; B3
  maps the corners rather than silently restricting the statement.
* B2's `Hdsha` is a **hypothesis**, so B2 is a theorem ABOUT what
  dsha256-injectivity would buy, not a proof of the EC/hash layer (W14:
  no kernel reduction of the hash or the verifiers anywhere in this
  module).

## E290 note (private re-derivations)

W11's `hashPrevoutsL_determined'` / `hashSequenceL_determined'` /
`hashOutputsL_determined'` are `private` in `Bitcoin.SigHash.Theorems`
(a proof-internal there), so they cannot be imported here. Their
statements are re-derived as the private `hashPrevoutsL_raw_inj'` /
`hashSequenceL_raw_inj'` / `hashOutputsL_raw_inj'` (same statements,
class-split hypotheses) — the public B1b carries the pinned correctness;
the private helpers mirror W11's own privacy.

## THM-032/033 disposition

THM-032 (BIP143 total+deterministic) is **OBSOLETE** as a row (W11:
`bip143MsgL_determined`, the `hashXxxL_cases` family, the 10-field
preimage shape); X10's B-tier adds what W11 deliberately did not claim —
the raw-suffix injectivity corollaries (I)/(B1)/(B2) and the corner map
(B3). THM-033 (BIP341 total+deterministic) is **STILL-BLOCKED (X03)**:
the BIP342 sighash slot in `realSchnorrEntry` is the fail-closed `none`
stand-in (Module A's A4 pins the no-false-accepts half); this module
pins the ECDSA half of the real dispatch only.
-/

namespace BitcoinProofs.Theorems.T3T4SighashCor

open Bitcoin.Crypto.Seam Bitcoin.Crypto.Seam.Entry Bitcoin.Crypto.Seam.Der
  Bitcoin.Capstone.RealChecker Bitcoin.Interpreter Bitcoin.Data Bitcoin.SigHash
  Bitcoin.Serialization

/-! ## 1. (I) — the raw 4-byte LE hashtype suffix is injective
(THM-032c ms-injectivity; Core `ss << nHashType`). -/

/-- **THM-032c ((I) ms-injectivity)**: a common prefix followed by the
4-byte LE serialization of the hashtype determines the hashtype —
`leNat (encU32L x) = x.toNat` (W02) + `serU32L = encU32L` (rfl) +
`UInt32.toNat_inj`. The ms-level engine behind every B1/B2 row. -/
theorem append_serU32L_inj {l : Bytes} {ht ht' : UInt32}
    (h : l ++ serU32L ht = l ++ serU32L ht') : ht = ht' := by
  have h4 : serU32L ht = serU32L ht' := List.append_right_inj l |>.mp h
  have hle : leNat (serU32L ht) = leNat (serU32L ht') := by rw [h4]
  have hle' : leNat (encU32L ht) = leNat (encU32L ht') := hle
  rwa [leNat_encU32L, leNat_encU32L, UInt32.toNat_inj] at hle'

/-! ## 2. B5 — `htToU32` injectivity (the popped byte is the full
hashtype seen by the digest). -/

/-- **THM-033c-ECDSA (B5)**: `htToU32` (the checker's
`int nHashType` from the popped signature byte,
`RealChecker.lean` interpreter.cpp:1707-1712) is injective — a `UInt8`
embedding into `UInt32` by `ofNat`, with `toNat < 256` on both sides
(`u32_ofNat_toNat` + `u8`-bounds + `omega`). Whatever the digest loses
of the hashtype, it does not lose it here. -/
theorem htToU32_inj (ht ht' : UInt8) (h : htToU32 ht = htToU32 ht') :
    ht = ht' := by
  unfold htToU32 at h
  have hN : UInt32.ofNat ht.toNat = UInt32.ofNat ht'.toNat := h
  have h2 : ht.toNat % 4294967296 = ht'.toNat % 4294967296 := by
    calc ht.toNat % 4294967296
        = (UInt32.ofNat ht.toNat).toNat := (u32_ofNat_toNat ht.toNat).symm
      _ = (UInt32.ofNat ht'.toNat).toNat := by rw [hN]
      _ = ht'.toNat % 4294967296 := u32_ofNat_toNat ht'.toNat
  have hb : ht.toNat < 256 := ht.toNat_lt_size
  have hb' : ht'.toNat < 256 := ht'.toNat_lt_size
  have : ht.toNat = ht'.toNat := by omega
  exact UInt8.toNat_inj.mp this

/-! ## 3. E290 — private re-derivations of W11's private
`hashX_determined'` helpers (statements identical; class-split
hypotheses; see the module docstring). -/

private theorem hashPrevoutsL_raw_inj' {tx : Tx} {ht ht' : UInt32}
    (ha : htAcp ht = htAcp ht') :
    hashPrevoutsL tx ht = hashPrevoutsL tx ht' := by
  unfold hashPrevoutsL
  rw [ha]

private theorem hashSequenceL_raw_inj' {tx : Tx} {ht ht' : UInt32}
    (hb : htBase ht = htBase ht') (ha : htAcp ht = htAcp ht') :
    hashSequenceL tx ht = hashSequenceL tx ht' := by
  unfold hashSequenceL
  rw [ha, hb]

private theorem hashOutputsL_raw_inj' {tx : Tx} {nIn : Nat} {ht ht' : UInt32}
    (hb : htBase ht = htBase ht') :
    hashOutputsL tx nIn ht = hashOutputsL tx nIn ht' := by
  unfold hashOutputsL
  rw [hb]

/-! ## 4. B1 — msg-level raw-hashtype injectivity (THM-032c). -/

/-- **THM-032c (B1a, legacy)**: two legacy messages for the same
`(tx, nIn, scriptCode)` in the same hashtype class are equal ONLY IF
the full hashtypes are equal — the preimage is class-determined (W11
`legacyPreimageL_determined`), so the raw `serU32L` suffix is the only
remaining hashtype channel, and it is injective ((I)). -/
theorem legacyMsgL_raw_inj (tx : Tx) (nIn : Nat) (sc : Bytes) (ht ht' : UInt32)
    (hcls : htClass ht = htClass ht')
    (h : legacyMsgL tx nIn sc ht = legacyMsgL tx nIn sc ht') : ht = ht' := by
  have hpre := legacyPreimageL_determined tx nIn sc ht ht' hcls
  unfold legacyMsgL at h
  rw [hpre] at h
  exact append_serU32L_inj h

/-- **THM-032c (B1b, BIP143)**: the same for the 10-field BIP143
preimage — all ten fields up to `hashOutputs`/`nLockTime` are
class-determined (W11's private `hashX_determined'` re-derived here,
E290), so the trailing raw `serU32L` suffix carries the only remaining
hashtype information. -/
theorem bip143MsgL_raw_inj (tx : Tx) (nIn : Nat) (sc : Bytes) (ht ht' : UInt32)
    (amount : Amount) (hcls : htClass ht = htClass ht')
    (h : bip143MsgL tx nIn sc ht amount = bip143MsgL tx nIn sc ht' amount) :
    ht = ht' := by
  have hb : htBase ht = htBase ht' := (htClass_eq hcls).1
  have ha : htAcp ht = htAcp ht' := (htClass_eq hcls).2
  have h1 : hashPrevoutsL tx ht = hashPrevoutsL tx ht' := hashPrevoutsL_raw_inj' ha
  have h2 : hashSequenceL tx ht = hashSequenceL tx ht' := hashSequenceL_raw_inj' hb ha
  have h3 : hashOutputsL tx nIn ht = hashOutputsL tx nIn ht' := hashOutputsL_raw_inj' hb
  unfold bip143MsgL at h
  rw [h1, h2, h3] at h
  exact append_serU32L_inj h

/-! ## 5. B0 — W11-Impl determinism lifted: Script level + the real
dispatch (033c-ECDSA-half, determinedness). -/

/-- **THM-033c-ECDSA (B0a)**: W11's `signatureHashLegacyImpl_determined`
(Impl level, `Bytes` scriptCode) lifted to the Script-level
`signatureHashLegacy` the real dispatch calls (`bL scriptCode.bytes`). -/
theorem signatureHashLegacy_determined (tx : Tx) (nIn : Nat)
    (scriptCode : Script) (ht ht' : UInt32)
    (hcls : htClass ht = htClass ht') (hraw : serU32L ht = serU32L ht') :
    signatureHashLegacy tx nIn scriptCode ht
      = signatureHashLegacy tx nIn scriptCode ht' := by
  exact signatureHashLegacyImpl_determined tx nIn (bL scriptCode.bytes) ht ht'
    hcls hraw

/-- **THM-033c-ECDSA (B0b)**: W11's `signatureHashBip143Impl_determined`
lifted to the Script level (`signatureHashBip143`). -/
theorem signatureHashBip143_determined (tx : Tx) (nIn : Nat)
    (scriptCode : Script) (ht ht' : UInt32) (amount : Amount)
    (hcls : htClass ht = htClass ht') (hraw : serU32L ht = serU32L ht') :
    signatureHashBip143 tx nIn scriptCode ht amount
      = signatureHashBip143 tx nIn scriptCode ht' amount := by
  exact signatureHashBip143Impl_determined tx nIn (bL scriptCode.bytes) ht ht'
    amount hcls hraw

/-- **THM-033c-ECDSA (B0c)**: the real dispatch (witnessV0 lane) is
determined in the hashtype, at the popped-byte level — `htToU32` of the
popped byte, class + raw bytes both equal ⇒ equal digests. -/
theorem sighashDispatch_determined_witnessV0 (tx : Tx) (nIn : Nat)
    (amount : Amount) (scriptCode : ByteArray) (ht ht' : UInt8)
    (hcls : htClass (htToU32 ht) = htClass (htToU32 ht'))
    (hraw : serU32L (htToU32 ht) = serU32L (htToU32 ht')) :
    sighashDispatch tx nIn amount scriptCode ht SigVersion.witnessV0
      = sighashDispatch tx nIn amount scriptCode ht' SigVersion.witnessV0 := by
  show signatureHashBip143 tx nIn ⟨scriptCode⟩ (htToU32 ht) amount
      = signatureHashBip143 tx nIn ⟨scriptCode⟩ (htToU32 ht') amount
  exact signatureHashBip143_determined tx nIn ⟨scriptCode⟩ (htToU32 ht)
    (htToU32 ht') amount hcls hraw

/-- **THM-033c-ECDSA (B0d)**: the real dispatch (legacy lanes — every
sigversion except witnessV0) is determined in the hashtype at the
popped-byte level. All three non-witnessV0 constructors dispatch to
`signatureHashLegacy`. -/
theorem sighashDispatch_determined_legacy (tx : Tx) (nIn : Nat)
    (amount : Amount) (scriptCode : ByteArray) (ht ht' : UInt8)
    (sv : SigVersion) (hcls : htClass (htToU32 ht) = htClass (htToU32 ht'))
    (hraw : serU32L (htToU32 ht) = serU32L (htToU32 ht'))
    (hv : sv ≠ SigVersion.witnessV0) :
    sighashDispatch tx nIn amount scriptCode ht sv
      = sighashDispatch tx nIn amount scriptCode ht' sv := by
  revert hv
  cases sv with
  | witnessV0 => intro h; exact absurd rfl h
  | base => intro _; exact signatureHashLegacy_determined tx nIn ⟨scriptCode⟩ (htToU32 ht) (htToU32 ht') hcls hraw
  | taproot => intro _; exact signatureHashLegacy_determined tx nIn ⟨scriptCode⟩ (htToU32 ht) (htToU32 ht') hcls hraw
  | tapscript => intro _; exact signatureHashLegacy_determined tx nIn ⟨scriptCode⟩ (htToU32 ht) (htToU32 ht') hcls hraw

/-! ## 6. B4a/c/d — the real dispatch: case-totality + purity. -/

/-- **THM-033c-ECDSA (B4a, case-totality)**: the real dispatch is total
and case-exhaustive in the sigversion — `witnessV0 → BIP143`, every
other constructor → legacy (interpreter.cpp:1718-1722 `VerifySignature`).
All four `SigVersion` constructors covered; nothing is stuck. -/
theorem sighashDispatch_cases (tx : Tx) (nIn : Nat) (amount : Amount)
    (scriptCode : ByteArray) (ht : UInt8) :
    sighashDispatch tx nIn amount scriptCode ht SigVersion.witnessV0
      = signatureHashBip143 tx nIn ⟨scriptCode⟩ (htToU32 ht) amount ∧
    ∀ sv, sv ≠ SigVersion.witnessV0 →
      sighashDispatch tx nIn amount scriptCode ht sv
        = signatureHashLegacy tx nIn ⟨scriptCode⟩ (htToU32 ht) := by
  constructor
  · rfl
  · intro sv hv
    revert hv
    cases sv with
    | witnessV0 => intro h; exact absurd rfl h
    | base => intro _; rfl
    | taproot => intro _; rfl
    | tapscript => intro _; rfl

/-- **THM-033c-ECDSA (B4c, purity-in-environment)**: the dispatch closure
is pure in `(tx, nIn, amount)` — equal environments, equal digests. -/
theorem sighashDispatch_pure (tx₁ tx₂ : Tx) (n₁ n₂ : Nat) (am₁ am₂ : Amount)
    (htx : tx₁ = tx₂) (hn : n₁ = n₂) (ham : am₁ = am₂)
    (scriptCode : ByteArray) (ht : UInt8) (sv : SigVersion) :
    sighashDispatch tx₁ n₁ am₁ scriptCode ht sv
      = sighashDispatch tx₂ n₂ am₂ scriptCode ht sv := by
  subst htx; subst hn; subst ham; rfl

/-- **THM-033c-ECDSA (B4d, purity-in-args)**: the dispatch closure is
pure in its two script-visible arguments (scriptCode, popped hashtype
byte). -/
theorem sighashDispatch_pure_args (tx : Tx) (nIn : Nat) (amount : Amount)
    (sc₁ sc₂ : ByteArray) (ht₁ ht₂ : UInt8) (hsc : sc₁ = sc₂)
    (hht : ht₁ = ht₂) (sv : SigVersion) :
    sighashDispatch tx nIn amount sc₁ ht₁ sv
      = sighashDispatch tx nIn amount sc₂ ht₂ sv := by
  subst hsc; subst hht; rfl

/-! ## 7. B2 — digest-level raw-hashtype injectivity, CONDITIONAL
(THM-032c; `Hdsha` a named hypothesis, never an axiom). -/

/-- **THM-032c (B2a, legacy digest)**: on the honest domain — same
hashtype class, NON-overflow (not out-of-range SINGLE), in-range `nIn` —
equal legacy digests determine the full hashtype, GIVEN a named
`dsha256`-injectivity hypothesis `Hdsha` (W14: the hash is never
kernel-reduced here; `Hdsha` is exactly what a future dsha256-injectivity
proof would plug in). -/
theorem signatureHashLegacyImpl_raw_inj (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht ht' : UInt32) (hcls : htClass ht = htClass ht')
    (hcor : ¬ (htBase ht = HtBase.singleHt ∧ tx.vout.length ≤ nIn))
    (hrange : ¬ (tx.vin.length ≤ nIn))
    (Hdsha : ∀ a b : Bytes, dshaL a = dshaL b → a = b)
    (h : signatureHashLegacyImpl tx nIn sc ht
          = signatureHashLegacyImpl tx nIn sc ht') :
    ht = ht' := by
  have hb : htBase ht = htBase ht' := (htClass_eq hcls).1
  have hcor' : ¬ (htBase ht' = HtBase.singleHt ∧ tx.vout.length ≤ nIn) := by
    intro hc; exact hcor ⟨hb.trans hc.1, hc.2⟩
  have hbr : signatureHashLegacyImpl tx nIn sc ht
      = dshaL (legacyMsgL tx nIn sc ht) := by
    unfold signatureHashLegacyImpl
    rw [if_neg hcor, if_neg hrange]
  have hbr' : signatureHashLegacyImpl tx nIn sc ht'
      = dshaL (legacyMsgL tx nIn sc ht') := by
    unfold signatureHashLegacyImpl
    rw [if_neg hcor', if_neg hrange]
  rw [hbr, hbr'] at h
  exact legacyMsgL_raw_inj tx nIn sc ht ht' hcls (Hdsha _ _ h)

/-- **THM-032c (B2b, BIP143 digest)**: the same for the BIP143 digest;
the honest domain is the in-range corner (BIP143 has no SINGLE early
return, so no `hcor` is needed — only in-range `nIn`). -/
theorem signatureHashBip143Impl_raw_inj (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht ht' : UInt32) (amount : Amount) (hcls : htClass ht = htClass ht')
    (hrange : ¬ (tx.vin.length ≤ nIn))
    (Hdsha : ∀ a b : Bytes, dshaL a = dshaL b → a = b)
    (h : signatureHashBip143Impl tx nIn sc ht amount
          = signatureHashBip143Impl tx nIn sc ht' amount) :
    ht = ht' := by
  have hbr : signatureHashBip143Impl tx nIn sc ht amount
      = dshaL (bip143MsgL tx nIn sc ht amount) := by
    unfold signatureHashBip143Impl
    rw [if_neg hrange]
  have hbr' : signatureHashBip143Impl tx nIn sc ht' amount
      = dshaL (bip143MsgL tx nIn sc ht' amount) := by
    unfold signatureHashBip143Impl
    rw [if_neg hrange]
  rw [hbr, hbr'] at h
  exact bip143MsgL_raw_inj tx nIn sc ht ht' amount hcls (Hdsha _ _ h)

/-! ## 8. B3 — the honest blindness-corner map (THM-032c): where
injectivity FAILS, and to what. -/

/-- **THM-032c (B3a, corner: legacy out-of-range SINGLE)**: the early
return fires before any vin indexing — the digest is the constant
`uint256::ONE`, for the ARBITRARY hashtype of the class-hypothesis shape
(W11's `legacyImpl_single_oor` is the ht = 0x03 shape). -/
theorem legacyImpl_single_oor_ht (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht : UInt32) (hs : htBase ht = HtBase.singleHt)
    (h : tx.vout.length ≤ nIn) :
    signatureHashLegacyImpl tx nIn sc ht = singleOverflowOneB := by
  unfold signatureHashLegacyImpl
  rw [if_pos ⟨hs, h⟩]

/-- **THM-032c (B3b, corner: legacy out-of-range nIn)**: the zero hash,
INDEPENDENT of the hashtype (the non-overflow branch) — the digest is
blinded to `(tx, scriptCode, hashtype)`. -/
theorem signatureHashLegacyImpl_oor_zero (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht : UInt32)
    (hcor : ¬ (htBase ht = HtBase.singleHt ∧ tx.vout.length ≤ nIn))
    (hr : tx.vin.length ≤ nIn) :
    signatureHashLegacyImpl tx nIn sc ht = bytesOfList zeroHashL := by
  unfold signatureHashLegacyImpl
  rw [if_neg hcor, if_pos hr]

/-- **THM-032c (B3c, corner: BIP143 out-of-range nIn)**: the zero hash
(NOT `uint256::ONE` — no early return; the tri-modal divergence), also
hashtype-blind. -/
theorem signatureHashBip143Impl_oor_zero (tx : Tx) (nIn : Nat) (sc : Bytes)
    (ht : UInt32) (amount : Amount) (hr : tx.vin.length ≤ nIn) :
    signatureHashBip143Impl tx nIn sc ht amount = bytesOfList zeroHashL := by
  unfold signatureHashBip143Impl
  rw [if_pos hr]

/-- **THM-032c (B3d, corner: the real dispatch, out-of-range nIn)**:
BOTH lanes of the real dispatch blind the digest to everything (zero
hash) when `nIn` is out of range — injectivity provably FAILS on this
corner; this is the honest map of the failure, not a silent domain
restriction. -/
theorem sighashDispatch_oor_zero (tx : Tx) (nIn : Nat) (amount : Amount)
    (scriptCode : ByteArray) (ht : UInt8)
    (hcor : ¬ (htBase (htToU32 ht) = HtBase.singleHt ∧ tx.vout.length ≤ nIn))
    (hr : tx.vin.length ≤ nIn) (sv : SigVersion) :
    sighashDispatch tx nIn amount scriptCode ht sv = bytesOfList zeroHashL := by
  revert hcor
  cases sv with
  | witnessV0 => intro _; exact signatureHashBip143Impl_oor_zero tx nIn (bL scriptCode) (htToU32 ht) amount hr
  | base => intro hcor; exact signatureHashLegacyImpl_oor_zero tx nIn (bL scriptCode) (htToU32 ht) hcor hr
  | taproot => intro hcor; exact signatureHashLegacyImpl_oor_zero tx nIn (bL scriptCode) (htToU32 ht) hcor hr
  | tapscript => intro hcor; exact signatureHashLegacyImpl_oor_zero tx nIn (bL scriptCode) (htToU32 ht) hcor hr

/-- **THM-032c (B3e, corner: the real dispatch, out-of-range SINGLE)**:
the LEGACY lanes blind the digest to the constant `uint256::ONE`; the
witnessV0 lane is EXEMPT (BIP143 has no ONE early return) — the honest
tri-modal statement, at the real checker. -/
theorem sighashDispatch_legacy_single_oor (tx : Tx) (nIn : Nat)
    (amount : Amount) (scriptCode : ByteArray) (ht : UInt8)
    (sv : SigVersion) (hv : sv ≠ SigVersion.witnessV0)
    (hs : htBase (htToU32 ht) = HtBase.singleHt)
    (h : tx.vout.length ≤ nIn) :
    sighashDispatch tx nIn amount scriptCode ht sv = singleOverflowOneB := by
  revert hv
  cases sv with
  | witnessV0 => intro h; exact absurd rfl h
  | base => intro _; exact legacyImpl_single_oor_ht tx nIn (bL scriptCode) (htToU32 ht) hs h
  | taproot => intro _; exact legacyImpl_single_oor_ht tx nIn (bL scriptCode) (htToU32 ht) hs h
  | tapscript => intro _; exact legacyImpl_single_oor_ht tx nIn (bL scriptCode) (htToU32 ht) hs h

/-! ## 9. B4b — W13's hashtype-pop totality at the real entry
(033c-ECDSA-half; SWT-053/SWT-054). -/

/-- **THM-033c-ECDSA (B4b, hashtype-pop totality)**: W13's
`ecdsaEntry_pops_hashtype` at the REAL checker — whatever the verdict,
the signature reaches the verifier only as `sig.extract 0 (sig.size - 1)`
(the hashtype byte popped before hashing/verifying,
interpreter.cpp:1707-1712; SWT-053), against the digest of
`(scriptCode, popped hashtype byte, sigversion)`. At the real wiring
`hasAmount = true`, so the WITNESS_V0 missing-amount gate (SWT-055) is
INERT at the seam — the amount-availability obligation is the
pipeline's (Module C). -/
theorem realEcdsaEntry_pops_hashtype (tx : Tx) (nIn : Nat) (amount : Amount)
    (sig pk code : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hpk : isValidPubKey pk = true) (hne : 0 < sig.size) :
    (realEcdsaEntry tx nIn amount).checkECDSASignature sig pk code v d
      = Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
          (sig.extract 0 (sig.size - 1)) pk
          (sighashDispatch tx nIn amount code sig[sig.size - 1]! v) := by
  exact ecdsaEntry_pops_hashtype Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
    (sighashDispatch tx nIn amount) true sig pk code v d hpk hne
    (fun _ => rfl)

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.append_serU32L_inj' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms append_serU32L_inj
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.htToU32_inj' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms htToU32_inj
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.legacyMsgL_raw_inj' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms legacyMsgL_raw_inj
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.bip143MsgL_raw_inj' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms bip143MsgL_raw_inj
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.signatureHashLegacy_determined' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms signatureHashLegacy_determined
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.signatureHashBip143_determined' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms signatureHashBip143_determined
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.sighashDispatch_determined_witnessV0' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms sighashDispatch_determined_witnessV0
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.sighashDispatch_determined_legacy' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms sighashDispatch_determined_legacy
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.sighashDispatch_cases' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms sighashDispatch_cases
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.sighashDispatch_pure' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms sighashDispatch_pure
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.sighashDispatch_pure_args' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms sighashDispatch_pure_args
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.signatureHashLegacyImpl_raw_inj' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms signatureHashLegacyImpl_raw_inj
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.signatureHashBip143Impl_raw_inj' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms signatureHashBip143Impl_raw_inj
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.legacyImpl_single_oor_ht' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms legacyImpl_single_oor_ht
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.signatureHashLegacyImpl_oor_zero' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms signatureHashLegacyImpl_oor_zero
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.signatureHashBip143Impl_oor_zero' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms signatureHashBip143Impl_oor_zero
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.sighashDispatch_oor_zero' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms sighashDispatch_oor_zero
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.sighashDispatch_legacy_single_oor' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms sighashDispatch_legacy_single_oor
/-- info: 'BitcoinProofs.Theorems.T3T4SighashCor.realEcdsaEntry_pops_hashtype' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms realEcdsaEntry_pops_hashtype

end BitcoinProofs.Theorems.T3T4SighashCor
