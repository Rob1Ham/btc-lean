import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Crypto.Taproot.Sighash
import Bitcoin.Crypto.Schnorr.Verify
import Bitcoin.Capstone.RealChecker

/-!
# Boolean BIP341/BIP340 compatibility assembly

This module proves the generic Boolean seam with real `sighashTaproot` and
BIP340 `verifyImpl`. Its definitional slot equations, correspondence with the
historical missing-sighash entry and failure/size contracts remain useful
compatibility facts. The official sighash and signature corpora are finite
conformance checks, separate from these symbolic proofs.

Production now uses `Capstone.RealChecker.realCheckerWithTaproot` and its
typed `checkSchnorrForInput` callback. That assembly uses the same crypto
primitives and preserves exact signature errors and unavailable-data outcomes.
The Boolean factories here retain their fail-closed missing-data contract;
this module alone does not prove a complete transaction or block valid.
-/

namespace Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2

open Bitcoin.Crypto.Seam
open Bitcoin.Crypto.Seam.Entry
open Bitcoin.Crypto.Schnorr.Verify
open Bitcoin.Capstone.RealChecker
open Bitcoin.Data
open Bitcoin.Interpreter

/-! ## The flip -/

/-- **THE FLIP** (the Taproot module → the Schnorr module interface): the seam's `sighashSchnorr` slot
instantiated with the Taproot module's real BIP341/342 sighash
`Bitcoin.Crypto.Taproot.Sighash.sighashTaproot`
(TPR-032, interpreter.cpp:1493-1578) over the `TapSighashEnv`
(spending tx + `m_spent_outputs` cache). `none` = the construction
failed (TPR-030/042/043, SCR-160/169) → the seam's fail-closed
`none => false` (interpreter.cpp:1745-1747). -/
@[rule "SCR-169"]
def sighashSchnorrTap (env : Bitcoin.Crypto.Taproot.TapSighashEnv)
    (inPos : Nat) :
    ScriptExecutionData → UInt8 → SigVersion → Option ByteArray :=
  fun _d ht v => Bitcoin.Crypto.Taproot.sighashTaproot env inPos ht v _d

/-- **`realSchnorrEntry2`** = `RealChecker.realSchnorrEntry` with the one
verdict-visible parameter flipped: the Schnorr module's real BIP340 `verifyImpl`
(19/19 official vectors) — UNCHANGED — and the Taproot module's real `sighashTaproot`
in the `sighashSchnorr` slot (was `fun _ _ _ => none`). Every gate
upstream of the digest (sigversion, 32-byte key, 64/65-byte sig,
65th-byte ≠ SIGHASH_DEFAULT) is the frozen `schnorrVerdict`'s, so this
is a Boolean compatibility entry; production uses the typed adapter —
nothing else in the seam moves. -/
@[rule "TPR-050", rule "TPR-051", rule "TPR-052", rule "TPR-072"]
def realSchnorrEntry2 (env : Bitcoin.Crypto.Taproot.TapSighashEnv)
    (inPos : Nat) : BaseSignatureChecker :=
  schnorrEntry Bitcoin.Crypto.Schnorr.Verify.verifyImpl
    (sighashSchnorrTap env inPos)

/-- The flipped both-real-entries assembly: `txCheckerOf` with the modular-arithmetic layer's
lax ECDSA entry (the `realCheckerFullOf` one) and the flipped Schnorr
entry. Everything but the `sighashSchnorr` slot is the
`realCheckerFullOf env.tx nIn amount` assembly; the environment is
Core's coherence contract (`env.tx` IS the checker's tx). -/
def realCheckerFullOf2 (env : Bitcoin.Crypto.Taproot.TapSighashEnv)
    (nIn inPos : Nat) (amount : Amount) :
    Bitcoin.Interpreter.ScriptChecker :=
  { base := txCheckerOf Bitcoin.Crypto.Ecdsa.Verify.verifyImpl (sighashDispatch env.tx nIn amount) true
        Bitcoin.Crypto.Schnorr.Verify.verifyImpl (sighashSchnorrTap env inPos)
    env := { txVersion := env.tx.version
             txLockTime := env.tx.locktime
             txSequence := (env.tx.vin.getD nIn dummyTxIn).sequence } }

/-- The compatibility assembly preserves the real ECDSA slot for every
transaction/cache, independently of the Schnorr construction's outcome. -/
theorem realCheckerFullOf2_ecdsa_eq
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (nIn inPos : Nat) (amount : Amount) :
    (realCheckerFullOf2 env nIn inPos amount).base.checkECDSASignature =
      (realCheckerFullOf env.tx nIn amount).base.checkECDSASignature := rfl

/-! ## The flip is the only change: definitional pins -/

/-- The flipped entry IS the frozen seam entry at the Schnorr module's verifier: the
`schnorrEntry` smart constructor with `verifyImpl` — the only delta vs
`realSchnorrEntry` is the `sighashSchnorr` argument. -/
theorem realSchnorrEntry2_entry (env : Bitcoin.Crypto.Taproot.TapSighashEnv)
    (inPos : Nat) :
    realSchnorrEntry2 env inPos
      = schnorrEntry Bitcoin.Crypto.Schnorr.Verify.verifyImpl
          (sighashSchnorrTap env inPos) := rfl

/-- The verdict of the flipped entry at `(sig, pk, v, d)` is the seam
verdict `schnorrVerdict verifyImpl (sighashSchnorrTap env inPos) sig pk v
d` — i.e. the gates see EXACTLY the real Taproot module digest. -/
theorem realSchnorrEntry2_verdict (env : Bitcoin.Crypto.Taproot.TapSighashEnv)
    (inPos : Nat) (sig pk : ByteArray) (v : SigVersion)
    (d : ScriptExecutionData) :
    (realSchnorrEntry2 env inPos).checkSchnorrSignature sig pk v d
      = schnorrVerdict Bitcoin.Crypto.Schnorr.Verify.verifyImpl
          (sighashSchnorrTap env inPos) sig pk v d := rfl

/-- The digest the flipped entry hands to `verifyImpl` (when the
construction succeeds) is the Taproot module's `sighashTaproot` — the epoch byte 0x00
is INSIDE the digest (TPR-032, `sighashTaproot_epoch`). -/
theorem realSchnorrEntry2_sighash_some
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (inPos : Nat)
    (ht : UInt8) (v : SigVersion) (d : ScriptExecutionData)
    (m : ByteArray)
    (hm : Bitcoin.Crypto.Taproot.sigMsgTaproot env inPos ht v d = some m) :
    Bitcoin.Crypto.Taproot.sighashTaproot env inPos ht v d
      = some (Bitcoin.Crypto.Schnorr.taggedHash
          Bitcoin.Crypto.Schnorr.tagTapSighash (Bitcoin.Data.serU8 0 ++ m)) := by
  rw [Bitcoin.Crypto.Taproot.sighashTaproot_epoch, hm]
  rfl

/-! ## The real-verifier criterion (the Schnorr-entry analysis), replayed at the frozen wiring — the statement the flip
re-visits. Same proof term as the Schnorr-entry analysis's real-verifier criterion
(`realSchnorrEntry_fail_closed`, Theorems/T3T4RealCheckerCor.lean);
restated here so the equivalence below is in-module and the proofs
package is not a dependency (core-only module). -/

/-- **the real-verifier criterion (replayed, unchanged fact)**: the historical Boolean compatibility entry —
the Schnorr module's real `verifyImpl` behind gates, BIP342 sighash still the
`none` stand-in — is constantly `false`. THE hypothesis the flip
removes: with a real digest in the slot, the `some h` branch survives
and `verifyImpl` is reached (see `_verdict_eq_verify` below). -/
theorem realSchnorrEntry_old_fail_closed (sig pk : ByteArray) (v : SigVersion)
    (d : ScriptExecutionData) :
    realSchnorrEntry.checkSchnorrSignature sig pk v d = false := by
  simp only [realSchnorrEntry, schnorrEntry, schnorrVerdict]
  by_cases hV : (v = SigVersion.taproot || v = SigVersion.tapscript) = true
  · rw [if_pos hV]
    by_cases hP : pk.size = 32
    · rw [if_pos hP]
      cases hs : schnorrHashtype sig with
      | none => rfl
      | some p =>
        cases p with
        | mk body ht => rfl
    · rw [if_neg hP]
  · rw [if_neg hV]

/-! ## The fail side: the seam layer/BIP341 gates still fail closed at the
real wiring (SCR-161/162/166 re-proved over `realSchnorrEntry2`). -/

/-- **SCR-161** (interpreter.cpp:1736): only 64- and 65-byte signatures
reach the EC math; every other size fails closed. -/
theorem realSchnorrEntry2_size_gate
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (inPos : Nat)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (h : sig.size ≠ 64 ∧ sig.size ≠ 65) :
    (realSchnorrEntry2 env inPos).checkSchnorrSignature sig pk v d = false := by
  simp only [realSchnorrEntry2, schnorrEntry, schnorrVerdict, sighashSchnorrTap,
    schnorrHashtype_none sig h]
  split
  · split <;> rfl
  · rfl

/-- **SCR-162** (interpreter.cpp:1741-1744): a 65-byte signature whose
trailing byte IS `SIGHASH_DEFAULT` is a hashtype error — fails closed
BEFORE the sighash is ever constructed. -/
theorem realSchnorrEntry2_65_default_rejected
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (inPos : Nat)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) (h65 : sig.size = 65)
    (h0 : sig[64]! = SIGHASH_DEFAULT) :
    (realSchnorrEntry2 env inPos).checkSchnorrSignature sig pk v d = false := by
  simp only [realSchnorrEntry2, schnorrEntry, schnorrVerdict]
  rw [if_pos (by rcases hv with hv | hv <;> subst hv <;> simp), if_pos hp,
      schnorrHashtype_65_default_rejected sig h65 h0]

/-- **SCR-166** (interpreter.cpp:1559-1560, 1745-1747): when the BIP341
sighash cannot be built for the popped hashtype (SIGHASH_SINGLE with
`in_pos ≥ vout.size()`, bad hashtype, missing extdata init, ACP cache
miss — every `none` of the Taproot module's `sighashTaproot`), the flipped entry still
fails closed — the Taproot module's `none` now plays the role the stand-in's `none`
played in the real-verifier criterion. -/
theorem realSchnorrEntry2_sighash_fail_closed
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (inPos : Nat)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) (h65 : sig.size = 65)
    (ht : UInt8) (hht : sig[64]! = ht) (hne : ht ≠ SIGHASH_DEFAULT)
    (hnone : Bitcoin.Crypto.Taproot.sighashTaproot env inPos ht v d = none) :
    (realSchnorrEntry2 env inPos).checkSchnorrSignature sig pk v d = false := by
  simp only [realSchnorrEntry2, schnorrEntry, schnorrVerdict, sighashSchnorrTap]
  rw [if_pos (by rcases hv with hv | hv <;> subst hv <;> simp), if_pos hp,
      schnorrHashtype_65 sig h65 (by rw [hht]; exact hne)]
  simp only [hht, hnone]

/-- **TPR-042 + SCR-160 (Core-anchored reject)**: an undefined hashtype
(TPR-030, interpreter.cpp:1532) or SIGHASH_SINGLE with no output at the
input index (TPR-042, :1559-1560) kills the whole message —
`sigMsgTaproot … = none ⇒ sighashTaproot … = none ⇒ verdict = false`.
The real-wiring revisit form: at the real wiring, fail-closed totality holds
exactly on the BIP341 construction's own reject set (every other
survivor reaches the Schnorr module's `verifyImpl`). -/
theorem realSchnorrEntry2_bad_msg_fail_closed
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (inPos : Nat)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) (h65 : sig.size = 65)
    (ht : UInt8) (hht : sig[64]! = ht) (hne : ht ≠ SIGHASH_DEFAULT)
    (hnone : Bitcoin.Crypto.Taproot.sigMsgTaproot env inPos ht v d = none) :
    (realSchnorrEntry2 env inPos).checkSchnorrSignature sig pk v d = false := by
  simp only [realSchnorrEntry2, schnorrEntry, schnorrVerdict, sighashSchnorrTap]
  rw [if_pos (by rcases hv with hv | hv <;> subst hv <;> simp), if_pos hp,
      schnorrHashtype_65 sig h65 (by rw [hht]; exact hne)]
  simp only [hht]
  have hn' : Bitcoin.Crypto.Taproot.sighashTaproot env inPos ht v d = none := by
    rw [Bitcoin.Crypto.Taproot.sighashTaproot_epoch, hnone]
    rfl
  simp only [hn']

/-! ## The real-verifier criterion re-stated, the now-meaningful forms -/

/-- **the real-verifier criterion' (the constantly-false pin, retired)**: past the seam layer gates and
the BIP341 construction, the flipped entry's verdict IS the Schnorr module's real
`verifyImpl` at the Taproot module's real digest — the `some h => verify body pk h`
branch of the frozen `schnorrVerdict` (interpreter.cpp:1747), now
reached. The real-verifier criterion's "constantly `false`" is exactly the negation of this
branch surviving. -/
theorem realSchnorrEntry2_verdict_eq_verify
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (inPos : Nat)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (body : ByteArray) (ht : UInt8) (digest : ByteArray)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32)
    (hs : schnorrHashtype sig = some (body, ht))
    (hd : Bitcoin.Crypto.Taproot.sighashTaproot env inPos ht v d = some digest) :
    (realSchnorrEntry2 env inPos).checkSchnorrSignature sig pk v d
      = Bitcoin.Crypto.Schnorr.Verify.verifyImpl body pk digest := by
  rcases hv with hv | hv
  · subst hv
    simp only [realSchnorrEntry2, schnorrEntry, schnorrVerdict, sighashSchnorrTap]
    rw [if_pos (by simp), if_pos hp]
    simp only [hs, hd]
  · subst hv
    simp only [realSchnorrEntry2, schnorrEntry, schnorrVerdict, sighashSchnorrTap]
    rw [if_pos (by simp), if_pos hp]
    simp only [hs, hd]

/-- **the real-verifier criterion' (the accept side, was vacuous)**: a key-path Taproot spend
(64-byte sig ⇒ SIGHASH_DEFAULT, interpreter.cpp:1740) with passing
gates and a successful BIP341 construction VERIFIES — `verifyImpl` is
called on `tag_TapSighash(0x00 ‖ SigMsg)` (TPR-032) and its verdict is
the entry's verdict. The exact negation of the real-verifier criterion: under the frozen wiring
this theorem's hypothesis `hm` still yields `false` (the real-verifier criterion); under the
flip it yields `verifyImpl`. -/
theorem realSchnorrEntry2_keypath_accept
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (inPos : Nat)
    (sig pk : ByteArray) (d : ScriptExecutionData) (m : ByteArray)
    (hp : pk.size = 32) (h64 : sig.size = 64)
    (hm : Bitcoin.Crypto.Taproot.sigMsgTaproot env inPos SIGHASH_DEFAULT
            SigVersion.taproot d = some m)
    (hvfy : Bitcoin.Crypto.Schnorr.Verify.verifyImpl sig pk
        (Bitcoin.Crypto.Schnorr.taggedHash Bitcoin.Crypto.Schnorr.tagTapSighash
          (Bitcoin.Data.serU8 0 ++ m)) = true) :
    (realSchnorrEntry2 env inPos).checkSchnorrSignature
        sig pk SigVersion.taproot d = true := by
  simp only [realSchnorrEntry2, schnorrEntry, schnorrVerdict, sighashSchnorrTap]
  rw [if_pos (by simp), if_pos hp, schnorrHashtype_64 sig h64]
  have hd : Bitcoin.Crypto.Taproot.sighashTaproot env inPos SIGHASH_DEFAULT
      SigVersion.taproot d
      = some (Bitcoin.Crypto.Schnorr.taggedHash
          Bitcoin.Crypto.Schnorr.tagTapSighash
          (Bitcoin.Data.serU8 0 ++ m)) := by
    rw [Bitcoin.Crypto.Taproot.sighashTaproot_epoch, hm]
    rfl
  simp only [hd]
  exact hvfy

/-- **TPR-072 (the meaningful execdata form)**: at the flipped wiring
the entry's verdict depends on the execdata record EXACTLY through the
BIP341 sighash — two execution datas agreeing on `sighashTaproot` for
every hashtype give identical verdicts (Core's
`SignatureHashSchnorr` reads `m_annex_*`/`m_tapleaf_hash`/
`m_codeseparator_pos`/`m_output_hash` from the execdata,
interpreter.cpp:1543-1575). The frozen wiring's
`realCheckerFullOf_schnorr_execData_independent` (the real-verifier criterion-era:
true only because the lane was const-false) is now the corollary
`fun _ _ _ => none ⇒ constant` of the stand-in's failure to depend on
`d` — this theorem is the Core-faithful form asked for. -/
theorem realSchnorrEntry2_execData_plumbed
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (inPos : Nat)
    (sig pk : ByteArray) (v : SigVersion) (d₁ d₂ : ScriptExecutionData)
    (hag : ∀ ht : UInt8, Bitcoin.Crypto.Taproot.sighashTaproot env inPos ht v d₁
      = Bitcoin.Crypto.Taproot.sighashTaproot env inPos ht v d₂) :
    (realSchnorrEntry2 env inPos).checkSchnorrSignature sig pk v d₁
      = (realSchnorrEntry2 env inPos).checkSchnorrSignature sig pk v d₂ := by
  exact schnorrEntry_execData_plumbed
    Bitcoin.Crypto.Schnorr.Verify.verifyImpl (sighashSchnorrTap env inPos)
    sig pk v d₁ d₂ (fun ht => by simpa [sighashSchnorrTap] using hag ht)

/-! ## The fail-closed equivalence: the flip is invisible exactly on
the Taproot module's `none` set (the digest-none pins, the revisit form). -/

/-- **the real-verifier criterion″ (pointwise equivalence)**: whenever the BIP341 construction
fails for the popped hashtype, the flipped entry and the FROZEN
compatibility entry give the same verdict (both `false`) — the one
verdict-visible parameter of the flip is `sighashTaproot … = none`.
Corollary form over ALL hashtypes:
`realSchnorrEntry2_agrees_old_none` below. -/
theorem realSchnorrEntry2_agrees_old
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (inPos : Nat)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hnone : ∀ ht : UInt8, Bitcoin.Crypto.Taproot.sighashTaproot env inPos ht v d
      = none) :
    (realSchnorrEntry2 env inPos).checkSchnorrSignature sig pk v d
      = realSchnorrEntry.checkSchnorrSignature sig pk v d := by
  rw [realSchnorrEntry_old_fail_closed]
  simp only [realSchnorrEntry2, schnorrEntry, schnorrVerdict, sighashSchnorrTap]
  by_cases hV : (v = SigVersion.taproot || v = SigVersion.tapscript) = true
  · rw [if_pos hV]
    by_cases hP : pk.size = 32
    · rw [if_pos hP]
      cases hs : schnorrHashtype sig with
      | none => rfl
      | some p =>
        cases p with
        | mk body ht =>
          simp [hnone ht]
    · rw [if_neg hP]
  · rw [if_neg hV]

/-- **the non-interference criterion' (checker non-interference, the revisit form)**: if the BIP341
construction fails for EVERY (hashtype, sigversion, execdata) — a
pre-Taproot checker, or an `env` whose every `sigMsgTaproot` is `none`
— the flipped assembly and the frozen `realCheckerFullOf` are the SAME
`BaseSignatureChecker` (ECDSA entries definitionally equal, Schnorr
entries equal by the real-verifier criterion″): **the flip is verdict-invisible exactly on
the Taproot module's `none` set**. On a real Taproot checker (a `some` digest
survives) the two assemblies differ precisely at the key-path
`verifyImpl` branch — "every Taproot key-path spend is judged
FAIL" corner, which the flip repairs (the Schnorr-entry analysis real-wiring revisit). -/
theorem realCheckerFullOf2_base_eq
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (nIn inPos : Nat)
    (amount : Amount)
    (h : ∀ (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData),
      (realSchnorrEntry2 env inPos).checkSchnorrSignature sig pk v d
        = realSchnorrEntry.checkSchnorrSignature sig pk v d) :
    (realCheckerFullOf2 env nIn inPos amount).base
      = (realCheckerFullOf env.tx nIn amount).base := by
  apply checker_eq_of_entry_eq
    (c₁ := (realCheckerFullOf2 env nIn inPos amount).base)
    (c₂ := (realCheckerFullOf env.tx nIn amount).base)
  · intro sig pk code v d; rfl
  · intro sig pk v d; exact h sig pk v d

/-- **the non-interference criterion″ (the digest-`none` side of the non-interference criterion')**: the hypothesis form of the
checker non-interference — every BIP341 construction over `env` fails
⇒ flipped assembly ≡ frozen assembly. This is the honest Schnorr-entry analysis and digest-none pins
revisit statement at the real wiring: the digest-none pins held unconditionally at
the stand-in (both Schnorr slots const-false); at the flip they hold
exactly on the Taproot module's `none` set, and fail exactly at the key-path accept
branch (see `realSchnorrEntry2_keypath_accept`). -/
theorem realCheckerFullOf2_noninterference_none
    (env : Bitcoin.Crypto.Taproot.TapSighashEnv) (nIn inPos : Nat)
    (amount : Amount)
    (hnone : ∀ (ht : UInt8) (v : SigVersion) (d : ScriptExecutionData),
      Bitcoin.Crypto.Taproot.sighashTaproot env inPos ht v d = none) :
    (realCheckerFullOf2 env nIn inPos amount).base
      = (realCheckerFullOf env.tx nIn amount).base :=
  realCheckerFullOf2_base_eq env nIn inPos amount
    (fun sig pk v d => realSchnorrEntry2_agrees_old env inPos sig pk v d
      (fun ht => hnone ht v d))

end Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2

/-- info: 'Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2.realCheckerFullOf2_ecdsa_eq' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in
#print axioms Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2.realCheckerFullOf2_ecdsa_eq
