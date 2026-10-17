import BitcoinProofs.EcdsaDeep.VerifyEquation

/-! # PDW95d — SGN-107 / SGN-110 row faces on the ECDSA verifier.

SGN-110 is the crown equation already proved in
`EcdsaDeep.VerifyEquation` (`verifyImpl_iff`); this file attaches the
row id and restates both directions. SGN-107 (the mod-`n` reduction of
`r`, `s` *before* the zero gate) is the new invariance theorem: the
verifier's verdict depends on `r0 % n`, `s0 % n` only, so two
BIP66-admissible 33-byte encodings that agree modulo `n` verify
identically. Residual (documented, not proved here): Core's compact
parse zero-rejects overflow (`≥ n`); the model reduces instead — the
F-E05-001 divergence pinned by `EcdsaDeep.StrictWindow`. -/

namespace BitcoinProofs.AF.PDW95
open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Curve.Mod
open Bitcoin.Crypto.Ecdsa.Verify
open Bitcoin.Crypto.Ecdsa.Der
open BitcoinProofs.EcdsaDeep.VerifyEquation

/-- SGN-110: `verifyImpl` accepts iff the ECDSA verify equation holds
(parses succeed, reduced scalars nonzero, `R.x % n = r`). -/
@[rule "SGN-110"]
theorem sgn110_verifyImpl_iff (sig pk msg : ByteArray) :
    verifyImpl sig pk msg = true ↔ VerifyEqRaw sig pk msg :=
  verifyImpl_iff sig pk msg

/-- SGN-110 (soundness): acceptance implies the equation. -/
@[rule "SGN-110"]
theorem sgn110_verifyImpl_sound (sig pk msg : ByteArray)
    (h : verifyImpl sig pk msg = true) : VerifyEqRaw sig pk msg :=
  verifyImpl_sound sig pk msg h

/-- SGN-110 (exactness): the equation implies acceptance. -/
@[rule "SGN-110"]
theorem sgn110_verifyImpl_exact (sig pk msg : ByteArray)
    (h : VerifyEqRaw sig pk msg) : verifyImpl sig pk msg = true :=
  verifyImpl_exact sig pk msg h

/-- SGN-107: the verifier is invariant under changing the raw DER
integers by multiples of the group order — `r0 % n` and `s0 % n` are
the only scalars it sees (reduction precedes the zero check). This is the
**tree's** model; Core zero-rejects overflow instead (see below). -/
@[rule "SGN-107"]
theorem sgn107_verifyImpl_mod_n_invariant (sig₁ sig₂ pk msg : ByteArray)
    (r₀ s₀ r₀' s₀' : Nat)
    (h₁ : parseDerLax sig₁ = some (r₀, s₀))
    (h₂ : parseDerLax sig₂ = some (r₀', s₀'))
    (hr : r₀ % n = r₀' % n) (hs : s₀ % n = s₀' % n) :
    verifyImpl sig₁ pk msg = verifyImpl sig₂ pk msg := by
  unfold verifyImpl
  rw [h₁, h₂]
  simp only [hr, hs]

/-! ## SGN-107 — the faithful compact-parse window

Core `CPubKey::Verify` does **not** reduce `r`/`s` modulo `n`. The lax DER
parser produces full-width integers, then `secp256k1_ecdsa_signature_parse_compact`
calls `scalar_set_b32`; on overflow (`value ≥ n`, i.e. the 32-byte payload
is not a valid scalar) it zeroes **both** scalars
(`secp256k1.c:407-425`: `ret &= !overflow`, then `memset`), and the
`r = 0 ∨ s = 0` gate in `ecdsa_verify` rejects. Only the message hash is
reduced with overflow ignored (`secp256k1.c:480`). `verifyImplCore` is the
faithful model; `verifyImpl` is the tree's reduction model. -/

/-- Compact-parse window: scalars `≥ n` zero both components. -/
def parseCompact (r0 s0 : Nat) : Nat × Nat :=
  if r0 < n ∧ s0 < n then (r0, s0) else (0, 0)

/-- `CPubKey::Verify` with Core's compact-parse window semantics
(`secp256k1.c:407-425`, zero-on-overflow) instead of the tree's
reduce-then-zero-check. -/
def verifyImplCore (sig pk msg : ByteArray) : Bool :=
  match parseDerLax sig with
  | none => false
  | some (r0, s0) =>
    match parsePubKey pk with
    | none => false
    | some (qx, qy) =>
      let z := bytesToNatBE msg % n
      let win := r0 < n ∧ s0 < n
      let r := if win then r0 else 0
      let s := if win then s0 else 0
      if r == 0 || s == 0 then false
      else
        let w := invM n s
        let u1 := mulM n z w
        let u2 := mulM n r w
        match addP (mulP u1 (some G)) (mulP u2 (some (qx, qy))) with
        | none => false
        | some (rx, _) => rx % n == r

/-- SGN-107: a scalar `≥ n` zeroes both — Core's parse failure. -/
@[rule "SGN-107"]
theorem parseCompact_overflow (r0 s0 : Nat) (h : n ≤ r0 ∨ n ≤ s0) :
    parseCompact r0 s0 = (0, 0) := by
  unfold parseCompact
  have : ¬(r0 < n ∧ s0 < n) := by omega
  rw [if_neg this]

/-- SGN-107: in the 32-byte window (`r < n`, `s < n`) the faithful model
and the tree's reduction model agree. -/
@[rule "SGN-107"]
theorem verifyImplCore_eq_of_window (sig pk msg : ByteArray) (r0 s0 : Nat)
    (hp : parseDerLax sig = some (r0, s0))
    (h : r0 < n ∧ s0 < n) :
    verifyImplCore sig pk msg = verifyImpl sig pk msg := by
  unfold verifyImplCore verifyImpl
  rw [hp]
  dsimp only
  cases hpk : parsePubKey pk with
  | none => rfl
  | some q =>
    simp only [hpk]
    simp [h, Nat.mod_eq_of_lt h.1, Nat.mod_eq_of_lt h.2]
    rfl

/-- SGN-107: Core's overflow rejection — any DER integer `≥ n` makes
`verifyImplCore` return `false`, whatever the key or message. -/
@[rule "SGN-107"]
theorem verifyImplCore_overflow_rejects (sig pk msg : ByteArray)
    (r0 s0 : Nat) (hp : parseDerLax sig = some (r0, s0))
    (hover : n ≤ r0 ∨ n ≤ s0) :
    verifyImplCore sig pk msg = false := by
  unfold verifyImplCore
  rw [hp]
  cases hpk : parsePubKey pk with
  | none => rfl
  | some q =>
    simp only [hpk]
    have hwin : ¬(r0 < n ∧ s0 < n) := by omega
    simp [hwin]

/-! ### The 33-byte-DER reachability witness (Z25 fork signature) -/

/-- Test-infra hex reader (same encoding as the Z25 audit). -/
def hexDigit (c : Char) : Option Nat :=
  let v := c.toNat
  if 48 ≤ v ∧ v ≤ 57 then some (v - 48)
  else if 97 ≤ v ∧ v ≤ 102 then some (v - 87)
  else if 65 ≤ v ∧ v ≤ 70 then some (v - 55)
  else none

def fromHex (s : String) : ByteArray := go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigit a, hexDigit b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

set_option maxRecDepth 100000 in
/-- Z25 fork signature: `r` is the minimal 33-byte DER integer `n+1`,
`s = n − 0xC0FFEE`. Strict BIP66 admits it; Core's compact parse
zero-rejects `r`, while the tree reduces `r` to `1` and continues. -/
def sigFork : ByteArray := fromHex
  "3046022100fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142\
022100fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8ccf754153"

set_option maxRecDepth 100000 in
/-- SGN-107 (reachability): the lax parser passes `r = n+1` through
unreduced (the Der layer performs no width reduction). -/
@[rule "SGN-107"]
theorem parseDerLax_sigFork :
    parseDerLax sigFork =
      some (n + 1,
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CCF754153) := by
  decide

set_option maxRecDepth 100000 in
/-- SGN-107: strict BIP66 DER admits the fork signature (with its sighash
byte), so it reaches consensus verification. -/
@[rule "SGN-107"]
theorem isDERSignature_sigFork :
    isDERSignature (sigFork.push 0x01) = true := by
  decide

/-- SGN-107 (the divergence, concretely): on the BIP66-admissible fork
signature the faithful Core model rejects, while the tree continues with
`r % n = 1`. -/
@[rule "SGN-107"]
theorem sigFork_core_rejects (pk msg : ByteArray) :
    verifyImplCore sigFork pk msg = false := by
  apply verifyImplCore_overflow_rejects sigFork pk msg (n + 1) _
    parseDerLax_sigFork
  omega

end BitcoinProofs.AF.PDW95
