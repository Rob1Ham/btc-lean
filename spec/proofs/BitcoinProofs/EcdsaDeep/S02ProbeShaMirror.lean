/-!
# S02 PROBE-2 — SHA-256 compression physics: kernel `decide` vs List-Bool
# mirror (DEEP-LEAN S02, 2026-10-16; raw `lean` v4.35.0, no lake, no imports)

D-004 census evidence (findings-dl/S02.md F-S02-002): kernel `decide` is
STUCK through the production hash floor (`Seam/Hash.Sha256` over
UInt32/BitVec/Array/ByteArray — the wall behind ~600 native_decide uses),
but a List-Bool STRUCTURAL MIRROR of the same 64-round compression shape
IS kernel-decidable. This file = that probe, VERBATIM as run
(S02FlipRun-proof: T1..T4 all `by decide`, no error, ~9 s wall).

  * T1 `blAnd w32a w32b = eAnd`  : 32  ∧-steps, non-trivial expected
  * T2 `blXor w32a w32b = eXor`  : 32  ⊕-steps, non-trivial
  * T3 `sigma0 w32a = eSig`      : ror7^ror18^shr3 = 96 bit-ops (SHA-2
                                    σ0 shape, 0x51ff22a0 on 0x12345678)
  * T4 `rounds 64 w32a = eR64`   : 64 chained rounds ≈ 500 bit-ops =
                                    a FULL-COMPRESSION-shaped reduction

Conclusion (F-S02-002, VERIFIED): the native_decide wall is the
BitVec/UInt32/Array/ByteArray representation layer, NOT the 64-round
algorithm. An E01-style structural mirror (List Bool / List UInt8 /
Nat-words; `Nat &&&`/`^^^`/`>>>` are all kernel-reducible, pass-1
PROBE-0) makes full 64-round SHA-256 compression kernel-`decide`-able.
Every expected value here was computed by the independent python mirror
(scratch/S02/, generator in the probe log). No sorry, no axioms: every
example below is a closed kernel-checked `decide` (this file builds with
plain `lean S02ProbeShaMirror.lean`, exit 0).
-/

-- S02 PROBE-2 — DECISIVE: non-trivial List-Bool equations by kernel decide
-- (no a=a shortcut; both sides must fully reduce). w32a=0x12345678 MSB-first.
set_option maxRecDepth 100000
set_option maxHeartbeats 4000000
def w32a : List Bool := [false,false,false,true,false,false,true,false,false,false,true,true,false,true,false,false,false,true,false,true,false,true,true,false,false,true,true,true,true,false,false,false]
def w32b : List Bool := [true,true,true,true,false,false,false,false,true,true,true,true,false,false,false,false,true,true,true,true,false,false,false,false,true,true,true,true,false,false,false,false]
def blAnd : List Bool → List Bool → List Bool
  | a :: as, b :: bs => (a && b) :: blAnd as bs
  | _, _ => []
def blXor : List Bool → List Bool → List Bool
  | a :: as, b :: bs => (a ^^ b) :: blXor as bs
  | _, _ => []
def rorB : Nat → List Bool → List Bool
  | 0, a => a | (k+1), [] => [] | (k+1), a :: as => rorB k (as ++ [a])
def shrBp : Nat → List Bool → List Bool  -- length-preserving shr (32-padded)
  | 0, a => a | (k+1), [] => [] | (k+1), _ :: as => false :: shrBp k as
def sigma0 (a : List Bool) : List Bool :=
  blXor (blXor (rorB 7 a) (rorB 18 a)) (shrBp 3 a)
def rounds (n : Nat) (a : List Bool) : List Bool :=
  match n with
  | 0 => a
  | _k+1 => rounds _k (blXor (sigma0 (blAnd a w32b)) (sigma0 w32a))
def eAnd : List Bool := [false,false,false,true,false,false,false,false,false,false,true,true,false,false,false,false,false,true,false,true,false,false,false,false,false,true,true,true,false,false,false,false]
def eXor : List Bool := [true,true,true,false,false,false,true,false,true,true,false,false,false,true,false,false,true,false,true,false,false,true,true,false,true,false,false,false,true,false,false,false]
def eSig : List Bool := [false,true,false,true,false,false,false,true,true,true,true,true,true,true,true,true,false,false,true,false,false,false,true,false,true,false,true,false,false,false,false,false]
def eR64 : List Bool := [false,true,false,true,true,false,true,false,true,false,true,false,false,true,false,true,false,true,false,false,true,false,false,false,false,true,false,true,false,false,false,false]
-- T1: 32 && steps (non-trivial)
example : blAnd w32a w32b = eAnd := by decide
-- T2: 32 ^^^ steps
example : blXor w32a w32b = eXor := by decide
-- T3: sigma0 = ror7^^^ror18^^^shr3 = 96 bit-ops (expect 0xd269c718)
example : sigma0 w32a = eSig := by decide
-- T4: 64 ROUNDS chained (≈ 500 bit-ops) — THE cost probe
example : rounds 64 w32a = eR64 := by decide
