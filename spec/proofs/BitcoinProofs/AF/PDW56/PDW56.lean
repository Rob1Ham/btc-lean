import Bitcoin.Crypto.Taproot.Tree
import Bitcoin.Crypto.Taproot.TapTweak
import Bitcoin.Crypto.Taproot.Verify
import Bitcoin.Interpreter.Defs

/-! # PDW56.lean — proof-promotion review RC27, items TOP-276..280
(PDW56, 2026-10-17). Claim 7d94723.

D-TPRTREE / D-TPRTWEAK status-debt band: the BIP341 leaf-hash and
output-key-tweak rows whose sorry-free def-level theorems already live in
`Bitcoin/Crypto/Taproot/{Tree,TapTweak}.lean` but whose rules.yaml rows
were never flipped. Route B: zero core writes, row-face theorems on my own
`@[rule]` tags, core proofs re-used verbatim.

* **TPR-012** `tapLeaf` = tagged hash of `v ‖ CScript(s.size) ‖ s`
  (interpreter.cpp:1882-1885) + 32-byte hash-domain size.
* **TPR-015/083** `taptweak`: `some root` = hash(p ‖ root), `none` =
  hash(p) alone (pubkey.cpp:246-255, BIP341:158).
* **TPR-016/017** `tweakPoint`: accept `Q=(x,y)` ⇒ `t < n` and
  `P + int(t)·G = Q`; `n ≤ t` ⇒ reject `none` (libsecp overflow lane).
-/

namespace BitcoinProofs.AF.PDW56

open Bitcoin.Crypto.Taproot
open Bitcoin.Crypto.Curve.Secp (RawPoint n addP mulP G)
open Bitcoin.Crypto.Schnorr (taggedHash tagTapLeaf tagTapTweak)
open Bitcoin.Data (serU8 compactSizeEnc)

/-- TPR-012: the tapleaf hash is exactly Core's `ComputeTapleafHash`
tagged-hash serialization `serU8 v ‖ compactSize(s.size) ‖ s`. -/
@[rule "TPR-012"]
theorem tapLeaf_wire_eq (v : UInt8) (script : ByteArray) :
    tapLeaf v script =
      taggedHash tagTapLeaf (serU8 v ++ compactSizeEnc script.size ++ script) :=
  tapLeaf_eq v script

/-- TPR-012 hash-domain contract: every tapleaf hash is a 32-byte digest. -/
@[rule "TPR-012"]
theorem tapLeaf_digest_size (v : UInt8) (script : ByteArray) :
    (tapLeaf v script).size = 32 :=
  tapLeaf_size v script

/-- TPR-015: the consensus (script-path) tweak commits to the merkle root:
`tag_TapTweak(p ‖ root)`. -/
@[rule "TPR-015"]
theorem taptweak_some_face (p root : ByteArray) :
    taptweak p (some root) = taggedHash tagTapTweak (p ++ root) :=
  taptweak_some p root

/-- TPR-083: a key-only output (no merkle root) tweaks with `p` alone,
`tag_TapTweak(p)` — BIP341's unspendable-script-path lane. -/
@[rule "TPR-083"]
theorem taptweak_none_face (p : ByteArray) :
    taptweak p none = taggedHash tagTapTweak p :=
  taptweak_none p

/-- TPR-016: an accepted output key satisfies the commitment equation
`Q = P + int(t)·G` and the tweak is in range (`t < n`). -/
@[rule "TPR-016"]
theorem tweakPoint_commitment_face (p : ByteArray) (P : RawPoint)
    (root : Option ByteArray) (x y : Nat)
    (h : tweakPoint p P root = some (x, y)) :
    tweakScalar p root < n ∧ addP P (mulP (tweakScalar p root) G) = some (x, y) :=
  tweakPoint_some p P root x y h

/-- TPR-017: the libsecp overflow reject — `n ≤ t` forces `tweakPoint = none`. -/
@[rule "TPR-017"]
theorem tweakPoint_overflow_face (p : ByteArray) (P : RawPoint)
    (root : Option ByteArray) (h : n ≤ tweakScalar p root) :
    tweakPoint p P root = none :=
  tweakPoint_overflow p P root h

/-! ## TPR-016 model repair — the output-key (x-coordinate) comparison

Core `VerifyTaprootCommitment` (`interpreter.cpp:1913-1925 @cce32b168`)
compares the SCRIPT-PUBKEY PROGRAM itself:

```
const XOnlyPubKey p{... control.subspan(1, 32) ...};
const XOnlyPubKey q{program};
const uint256 merkle_root = ComputeTaprootMerkleRoot(control, tapleaf_hash);
return q.CheckTapTweak(p, merkle_root, control[0] & 1);
```

`CheckTapTweak` (`pubkey.cpp:255-271`) checks BOTH the x-coordinate
(`secp256k1_memcmp_var(&pk_expected32, tweaked_pubkey32, 32) == 0`) and
the parity (`secp256k1_fe_is_odd(&pk.y) == tweaked_pk_parity`).  The
existing `Bitcoin.Crypto.Taproot.Verify.verifyTaprootCommitment` ignores
its `program` argument and `OutputKey.outputKeyOk` checks only parity.
This module adds the faithful check — `program` as the x-coordinate of
`Q` plus the parity — and proves the row's equation and reject face. -/

open Bitcoin.Crypto.Taproot.OutputKey (internalKeyBytes parityOk)
open Bitcoin.Crypto.Curve.Secp (liftX bytesToNatBE)
open Bitcoin.Crypto.Taproot.Verify (scriptPathMerkleRoot)

/-- TPR-016 (faithful commitment check): parse the control block's
internal key, recompute `Q = P + int(t)·G` under the script-path merkle
root, and require BOTH `x(Q) = int(program)` (the scriptPubKey witness
program is the x-only output key `q`) and `control[0]&1 = y(Q)&1`.
Fail-closed at every stage. -/
def taprootCommitmentOk (control program tapleafHash : ByteArray) : Bool :=
  if control.size < 33 then false
  else
    match liftX (bytesToNatBE (internalKeyBytes control)) with
    | none => false
    | some P =>
      match tweakPoint (internalKeyBytes control) (some P)
          (some (scriptPathMerkleRoot control tapleafHash)) with
      | none => false
      | some (xQ, yQ) => (bytesToNatBE program == xQ) && parityOk control yQ

/-- TPR-016 (accept face): a successful faithful check exhibits the
internal key, the tweaked output key, the x-coordinate equality
`q = x(P + int(t)·G)` and the parity match. -/
@[rule "TPR-016"]
theorem taprootCommitmentOk_commitment (control program tapleafHash : ByteArray)
    (xI yI : Nat)
    (hp : liftX (bytesToNatBE (internalKeyBytes control)) = some (xI, yI))
    (h : taprootCommitmentOk control program tapleafHash = true) :
    ∃ xQ yQ,
      tweakPoint (internalKeyBytes control) (some (xI, yI))
          (some (scriptPathMerkleRoot control tapleafHash)) = some (xQ, yQ) ∧
      bytesToNatBE program = xQ ∧ parityOk control yQ = true := by
  unfold taprootCommitmentOk at h
  by_cases hsize : control.size < 33
  · rw [if_pos hsize] at h
    simp at h
  · rw [if_neg hsize, hp] at h
    dsimp only at h
    cases ht : tweakPoint (internalKeyBytes control) (some (xI, yI))
        (some (scriptPathMerkleRoot control tapleafHash)) with
    | none =>
      rw [ht] at h
      simp at h
    | some Q =>
      obtain ⟨xQ, yQ⟩ := Q
      rw [ht] at h
      simp [Bool.and_eq_true, beq_iff_eq] at h
      exact ⟨xQ, yQ, rfl, h.1, h.2⟩

/-- TPR-016 (reject face): if the recomputed output key's x-coordinate
differs from the scriptPubKey program, or the parity differs, the
commitment check fails (Core then raises
`SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH` at interpreter.cpp:1985). -/
@[rule "TPR-016"]
theorem taprootCommitmentOk_false_of_mismatch
    (control program tapleafHash : ByteArray) (xI yI xQ yQ : Nat)
    (hp : liftX (bytesToNatBE (internalKeyBytes control)) = some (xI, yI))
    (ht : tweakPoint (internalKeyBytes control) (some (xI, yI))
        (some (scriptPathMerkleRoot control tapleafHash)) = some (xQ, yQ))
    (hm : bytesToNatBE program ≠ xQ ∨ parityOk control yQ = false) :
    taprootCommitmentOk control program tapleafHash = false := by
  unfold taprootCommitmentOk
  by_cases hsize : control.size < 33
  · rw [if_pos hsize]
  · rw [if_neg hsize, hp]
    dsimp only
    rw [ht]
    rcases hm with hm | hm
    · simp [beq_iff_eq, hm]
    · simp [hm]

/-- TPR-016 (Core's error face): the faithful check as a verifier
outcome — success, or `SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH` when the
commitment equation/parity does not hold. -/
def taprootCommitmentOutcome (control program tapleafHash : ByteArray) :
    Bitcoin.Interpreter.VerifyOutcome :=
  if taprootCommitmentOk control program tapleafHash then .ok
  else .fail .witnessProgramMismatch

/-- TPR-016 (outcome characterization): `ok` iff the faithful check
succeeds; otherwise the outcome is exactly
`WITNESS_PROGRAM_MISMATCH`. -/
@[rule "TPR-016"]
theorem taprootCommitmentOutcome_eq (control program tapleafHash : ByteArray) :
    taprootCommitmentOutcome control program tapleafHash =
      (if taprootCommitmentOk control program tapleafHash then
        Bitcoin.Interpreter.VerifyOutcome.ok
       else .fail .witnessProgramMismatch) := rfl

/-- TPR-016 (mismatch outcome): a failed commitment check is reported as
`SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH`, matching
interpreter.cpp:1985. -/
@[rule "TPR-016"]
theorem taprootCommitmentOutcome_mismatch (control program tapleafHash : ByteArray)
    (h : taprootCommitmentOk control program tapleafHash = false) :
    taprootCommitmentOutcome control program tapleafHash =
      .fail .witnessProgramMismatch := by
  unfold taprootCommitmentOutcome
  rw [h]
  rfl

end BitcoinProofs.AF.PDW56
