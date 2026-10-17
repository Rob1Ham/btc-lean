import Bitcoin.Crypto.Field.Interface
import Bitcoin.Crypto.Curve.Secp

/-!
# Bitcoin.Crypto.Curve — frozen interface, FILLED by W14 (2B)

Owning workstream     : W14 (2B slot: group law over the field layer)
Dependent workstreams : W13 (tweak-check EC math for Taproot commitments)
Core counterpart files: src/crypto/secp256k1/group.h, ecmult_impl.h
Status                : frozen 2026-10-16 by W01 — MINIMAL STUB: the real
                        point representation (mathlib `Affine.Point` in the
                        proofs package vs a core-native affine record) is
                        W14's first design call; only the consensus-visible
                        surface is pinned (B5: taproot commitment check
                        pulls point arithmetic into consensus even for
                        zero-sig spends).

FILL HISTORY (W14b): the three `opaque ... := sorry` placeholders below
were replaced by real implementations over the raw Nat layer
(`Bitcoin.Crypto.Curve.Secp`), signatures byte-identical. The `opaque`
wrappers are kept deliberately: the consensus surface stays the frozen
constants, and `#print axioms` on downstream theorems pins against the
interface, not the implementation.

FILL NOTE (handoff): `Fe` arithmetic in `Bitcoin.Crypto.Field`
(feAdd/feMul/feNeg/feInv) is still W14's 2A fill — this module routes
around it with the raw `Nat` layer, so it does NOT depend on those stubs.
-/

namespace Bitcoin.Crypto.Curve

open Bitcoin.Crypto.Field

/-- Affine point, None = point at infinity. -/
abbrev AffinePoint := Option (Fe × Fe)

/-- The secp256k1 curve equation y² = x³ + 7. -/
def curveA : Fe := feZero

def curveB : Fe := ⟨7, by decide⟩

/-! ### Raw-layer bridge (W14b fill machinery)

`Fe = {x : Nat // x < P}` already carries the range invariant in its type,
so the conversion to the raw `Nat` layer is lossless; the way back re-establishes
the invariant from `Secp.RawOK` preservation theorems. -/

private def toRaw : AffinePoint → Secp.RawPoint
  | none => none
  | some (a, b) => some (a.1, b.1)

private theorem toRaw_ok (p : AffinePoint) : Secp.RawOK (toRaw p) := by
  cases p with
  | none => trivial
  | some q => exact ⟨q.1.2, q.2.2⟩

private def ofRaw : (p : Secp.RawPoint) → Secp.RawOK p → AffinePoint
  | none, _ => none
  | some (x, y), ⟨hx, hy⟩ => some (⟨x, hx⟩, ⟨y, hy⟩)

/-- Point addition (group law; mathlib has this fully proven for
Weierstrass curves — the scary layer is borrowed, C2/A4 finding). -/
-- FILL[W14b]: was SORRY[W01] stub; body over the raw Nat layer, signature unchanged.
opaque pointAdd : AffinePoint → AffinePoint → AffinePoint :=
  fun p q =>
    ofRaw (Secp.addP (toRaw p) (toRaw q))
      (Secp.addP_ok _ _ (toRaw_ok p) (toRaw_ok q))

/-- Scalar multiplication (double-and-add over the group). -/
-- FILL[W14b]: was SORRY[W01] stub; body over the raw Nat layer, signature unchanged.
opaque pointMul : Nat → AffinePoint → AffinePoint :=
  fun k p => ofRaw (Secp.mulP k (toRaw p)) (Secp.mulP_ok (toRaw p) (toRaw_ok p) k)

/-- The generator G (secp256k1, standard constants; STUB NOTE: its
`Fe` proofs are `decide`-elaborated, so this constant is total and
kernel-computable — never stub a non-function constant with `sorry`:
compiled sorry constants EXECUTE at module init and panic the binary). -/
def Gx : Nat := 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798

def Gy : Nat := 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8

def generator : AffinePoint :=
  some ⟨⟨Gx, by decide⟩, ⟨Gy, by decide⟩⟩

/-- Taproot tweak check (BIP341: t = tagHash(TapTweak)…; Q = P + tG).
This is consensus-visible even for key-path-only spends. -/
-- FILL[W14b]: was SORRY[W01] stub; Q = P + t·G with `t` read little-endian
-- (BIP341: the 32-byte tweak is `le256(t)`), signature unchanged.
opaque tweakPoint : ByteArray → AffinePoint → AffinePoint :=
  fun t p =>
    let k := Secp.bytesToNatLE t
    if k < Secp.n then pointAdd p (pointMul k generator) else none

end Bitcoin.Crypto.Curve
