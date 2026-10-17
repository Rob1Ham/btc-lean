import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Crypto.Taproot.Sighash
import Bitcoin.Crypto.Schnorr.Verify
import Bitcoin.Capstone.RealChecker

/-!
# Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2 — the BIP341/342 sighash flip
# (S03, EcdsaDeep; X10's A4-revisit, first item)

## What this file is

X03-retry's `Bitcoin.Crypto.Taproot.Sighash.sighashTaproot` LANDED
(e904215; TPR-032, 7/7 official wallet vectors + the independent
hashlib mirror), but the production Schnorr wiring was NOT flipped:
`Bitcoin.Capstone.RealChecker.realSchnorrEntry` (RealChecker.lean:96-100)
still carries the fail-closed stand-in `sighashSchnorr := fun _ _ _ =>
none`, so `schnorrVerdict` still returns `false` before BIP340's
`verifyImpl` is ever called (X10's A4: the lane is constantly false).

**VERIFIED BY GREP THIS RUN** (suite discipline, CHECK THE TREE FIRST):
`grep -rn 'sighashSchnorr' spec/core/Bitcoin/Capstone/` shows
RealChecker.lean:100 `(fun _ _ _ => none)  -- BIP342 sighash: X03/X04
slot (fail-closed stand-in)`. The flip has NOT landed. Per the hard
rules (NEW files only; RealChecker.lean + the whole Taproot tree are
running contributors' territory), THIS file lands the flip as a **parallel
entry `realSchnorrEntry2`** in a new module, leaving the frozen seam
untouched: `realSchnorrEntry2` is the `schnorrEntry` of X02's real
BIP340 verifier with **X03's real `sighashTaproot`** in the
`sighashSchnorr` slot, and `realCheckerFullOf2` is the corresponding
`txCheckerOf` assembly. Nothing in `spec/core/**` outside this file
references them; zero existing verdicts change.

## The one-parameter flip, pinned

`sighashSchnorr` is the single verdict-visible change point of the
Schnorr lane (X10 Module A, W08 F-004): both `verify` (X02, 19/19
official vectors) and every W13 gate (sigversion / 32-byte key /
64-65-byte sig / 65th-byte ≠ SIGHASH_DEFAULT, SCR-160..162) were
already real. `realSchnorrEntry2` instantiates exactly that one
parameter:

    schnorrEntry Bitcoin.Crypto.Schnorr.Verify.verifyImpl
                 (sighashSchnorrTap env inPos)          -- THE FLIP

where `sighashSchnorrTap env inPos d ht v = sighashTaproot env inPos
ht v d` is the seam-slot shape (`ScriptExecutionData → UInt8 →
SigVersion → Option ByteArray`) over X03's `TapSighashEnv` — Core's
`GenericTransactionSignatureChecker::CheckSchnorrSignature` calling
`SignatureHashSchnorr` (interpreter.cpp:1747 → :1493-1578). The
`TapSighashEnv` (the spending tx + `m_spent_outputs` cache) is the
Core counterpart of the checker's own `txdata`; the caller-side
coherence `env.tx = tx` (same contract as Core's checker sharing the
tx with its `PrecomputedTransactionData`) is a parameter of the
assembly, `realCheckerFullOf2 env …`.

## Fail-closed equivalence (the seam is untouched)

`realSchnorrEntry2_agrees_old_none`: **the flip is verdict-invisible
exactly when the BIP341 construction fails** — for a fixed `(ht, v, d)`
with `sighashTaproot env inPos ht v d = none` (bad hashtype TPR-030,
SIGHASH_SINGLE with no output TPR-042, missing extdata init TPR-043,
ACP cache miss SCR-169, non-Taproot sigversion SCR-160), the flipped
entry and the frozen `realSchnorrEntry` give the SAME verdict
(both `false`). This is the honest split the flip buys:

* **fail side** — unchanged: every gate that made A4 true without the
  EC math (SCR-161/162/166) still fails closed at the real wiring
  (`realSchnorrEntry2_size_gate`, `_65_default_rejected`,
  `_sighash_fail_closed`, `_bad_msg_fail_closed`);
* **accept side** — was vacuous, now meaningful: A4's
  "constantly `false`" becomes "the W13 gates ∨ the BIP341 construction
  gates ∨ the real `verifyImpl`" (`realSchnorrEntry2_verdict_eq_verify`,
  `realSchnorrEntry2_keypath_accept`) — the exact form W08 asked A4 to
  be re-stated in once a real sighash lands (W08.md:95-98: the old
  `…_execData_independent` "must not be read as a Core fact"; its
  meaningful form, `realSchnorrEntry2_execData_plumbed`, is now the
  real TPR-072 plumbing at the real wiring).

## VERIFIED vs PROPOSED

* VERIFIED (this file, sorry-free, axiom-pinned in-module): the flip
  def family + the fail-closed/equivalence theorem set above. All
  proofs are gate congruences or `none`-eliminations at the
  `schnorrVerdict`/`sighashTaproot` level — nothing reduces
  `verifyImpl` (either lane) or the SHA256 layer (W14 discipline).
* PROPOSED (NOT here): flipping the *production* binding — replacing
  `realSchnorrEntry`/`realCheckerFullOf` in `Capstone/RealChecker.lean`
  (and/or `TxValidation/Full.lean:80`) by this entry, i.e. making
  `realCheckerFullOf2` the checker `validateBlock` binds. That edit is
  in the frozen-seam owner's lane; this file is the proved, drop-in
  replacement with the one-line diff (seam slot only) it rests on.
  Until then every existing verdict is unchanged (grep-clean).

## Off-limit discipline

No existing file is touched. `Bitcoin.Crypto.Taproot.Sighash`,
`Bitcoin.Crypto.Seam.Entry`, `Bitcoin.Capstone.RealChecker`,
`Bitcoin.Crypto.Schnorr.Verify` are IMPORT-ONLY (X03-retry / W13 /
X02-revive lanes). Interpreter/Rules.lean (X07's SCR rows) is also
import-free here on purpose: the SCR-161/162/166 rows it proves over
the abstract `sighashSchnorr` parameter are re-proved here over the
real wiring (same proof terms, `_realSchnorrEntry2_` names) so this
module depends only on the frozen seam + the landed sighash.
-/

namespace Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2

open Bitcoin.Crypto.Seam
open Bitcoin.Crypto.Seam.Entry
open Bitcoin.Crypto.Schnorr.Verify
open Bitcoin.Capstone.RealChecker
open Bitcoin.Data
open Bitcoin.Interpreter

/-! ## The flip -/

/-- **THE FLIP** (X03 → X02 handoff): the seam's `sighashSchnorr` slot
instantiated with X03's real BIP341/342 sighash
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
verdict-visible parameter flipped: X02's real BIP340 `verifyImpl`
(19/19 official vectors) — UNCHANGED — and X03's real `sighashTaproot`
in the `sighashSchnorr` slot (was `fun _ _ _ => none`). Every W13 gate
upstream of the digest (sigversion, 32-byte key, 64/65-byte sig,
65th-byte ≠ SIGHASH_DEFAULT) is the frozen `schnorrVerdict`'s, so this
is the production entry the moment `RealChecker.lean` adopts it —
nothing else in the seam moves. -/
@[rule "TPR-050", rule "TPR-051", rule "TPR-052", rule "TPR-072"]
def realSchnorrEntry2 (env : Bitcoin.Crypto.Taproot.TapSighashEnv)
    (inPos : Nat) : BaseSignatureChecker :=
  schnorrEntry Bitcoin.Crypto.Schnorr.Verify.verifyImpl
    (sighashSchnorrTap env inPos)

/-- The flipped both-real-entries assembly: `txCheckerOf` with W14b's
lax ECDSA entry (the `realCheckerFullOf` one) and the flipped Schnorr
entry. Everything but the `sighashSchnorr` slot is the
`realCheckerFullOf env.tx nIn amount` assembly; the environment is
Core's coherence contract (`env.tx` IS the checker's tx). -/
def realCheckerFullOf2 (env : Bitcoin.Crypto.Taproot.TapSighashEnv)
    (nIn inPos : Nat) (amount : Amount) :
    Bitcoin.Interpreter.ScriptChecker :=
  { base := txCheckerOf verifyImpl (sighashDispatch env.tx nIn amount) true
        Bitcoin.Crypto.Schnorr.Verify.verifyImpl (sighashSchnorrTap env inPos)
    env := { txVersion := env.tx.version
             txLockTime := env.tx.locktime
             txSequence := (env.tx.vin.getD nIn dummyTxIn).sequence } }

/-! ## The flip is the only change: definitional pins -/

/-- The flipped entry IS the frozen seam entry at X02's verifier: the
`schnorrEntry` smart constructor with `verifyImpl` — the only delta vs
`realSchnorrEntry` is the `sighashSchnorr` argument. -/
theorem realSchnorrEntry2_entry (env : Bitcoin.Crypto.Taproot.TapSighashEnv)
    (inPos : Nat) :
    realSchnorrEntry2 env inPos
      = schnorrEntry Bitcoin.Crypto.Schnorr.Verify.verifyImpl
          (sighashSchnorrTap env inPos) := rfl

/-- The verdict of the flipped entry at `(sig, pk, v, d)` is the seam
verdict `schnorrVerdict verifyImpl (sighashSchnorrTap env inPos) sig pk v
d` — i.e. the W13 gates see EXACTLY the real X03 digest. -/
theorem realSchnorrEntry2_verdict (env : Bitcoin.Crypto.Taproot.TapSighashEnv)
    (inPos : Nat) (sig pk : ByteArray) (v : SigVersion)
    (d : ScriptExecutionData) :
    (realSchnorrEntry2 env inPos).checkSchnorrSignature sig pk v d
      = schnorrVerdict Bitcoin.Crypto.Schnorr.Verify.verifyImpl
          (sighashSchnorrTap env inPos) sig pk v d := rfl

/-- The digest the flipped entry hands to `verifyImpl` (when the
construction succeeds) is X03's `sighashTaproot` — the epoch byte 0x00
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

/-! ## A4 (X10), replayed at the frozen wiring — the statement the flip
re-visits. Same proof term as Module A's A4
(`realSchnorrEntry_fail_closed`, Theorems/T3T4RealCheckerCor.lean);
restated here so the equivalence below is in-module and the proofs
package is not a dependency (core-only module). -/

/-- **A4 (replayed, unchanged fact)**: the FROZEN production entry —
X02's real `verifyImpl` behind W13's gates, BIP342 sighash still the
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

/-! ## The fail side: the W13/BIP341 gates still fail closed at the
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
miss — every `none` of X03's `sighashTaproot`), the flipped entry still
fails closed — X03's `none` now plays the role the stand-in's `none`
played in A4. -/
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
The A4-revisit form: at the real wiring, fail-closed totality holds
exactly on the BIP341 construction's own reject set (every other
survivor reaches X02's `verifyImpl`). -/
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

/-! ## A4 re-stated, the now-meaningful forms -/

/-- **A4' (the constantly-false pin, retired)**: past the W13 gates and
the BIP341 construction, the flipped entry's verdict IS X02's real
`verifyImpl` at X03's real digest — the `some h => verify body pk h`
branch of the frozen `schnorrVerdict` (interpreter.cpp:1747), now
reached. A4's "constantly `false`" is exactly the negation of this
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

/-- **A4' (the accept side, was vacuous)**: a key-path Taproot spend
(64-byte sig ⇒ SIGHASH_DEFAULT, interpreter.cpp:1740) with passing W13
gates and a successful BIP341 construction VERIFIES — `verifyImpl` is
called on `tag_TapSighash(0x00 ‖ SigMsg)` (TPR-032) and its verdict is
the entry's verdict. The exact negation of A4: under the frozen wiring
this theorem's hypothesis `hm` still yields `false` (A4); under the
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
`realCheckerFullOf_schnorr_execData_independent` (A4-era, W08 F-006:
true only because the lane was const-false) is now the corollary
`fun _ _ _ => none ⇒ constant` of the stand-in's failure to depend on
`d` — this theorem is the Core-faithful form W08 asked for. -/
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
X03's `none` set (A5/A6, the revisit form). -/

/-- **A4″ (pointwise equivalence)**: whenever the BIP341 construction
fails for the popped hashtype, the flipped entry and the FROZEN
production entry give the same verdict (both `false`) — the one
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
          rw [hnone ht]
          exact match none with | none => rfl | some _ => rfl
    · rw [if_neg hP]
  · rw [if_neg hV]

/-- **A6' (checker non-interference, the revisit form)**: if the BIP341
construction fails for EVERY (hashtype, sigversion, execdata) — a
pre-Taproot checker, or an `env` whose every `sigMsgTaproot` is `none`
— the flipped assembly and the frozen `realCheckerFullOf` are the SAME
`BaseSignatureChecker` (ECDSA entries definitionally equal, Schnorr
entries equal by A4″): **the flip is verdict-invisible exactly on
X03's `none` set**. On a real Taproot checker (a `some` digest
survives) the two assemblies differ precisely at the key-path
`verifyImpl` branch — W08's "every Taproot key-path spend is judged
FAIL" corner, which the flip repairs (X10 A4-revisit). -/
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

/-- **A6″ (the digest-`none` side of A6')**: the hypothesis form of the
checker non-interference — every BIP341 construction over `env` fails
⇒ flipped assembly ≡ frozen assembly. This is the honest X10-A5/A6
revisit statement at the real wiring: A5/A6 held unconditionally at
the stand-in (both Schnorr slots const-false); at the flip they hold
exactly on X03's `none` set, and fail exactly at the key-path accept
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
