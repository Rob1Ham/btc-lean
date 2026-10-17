import Bitcoin.Data.Basic

/-!
# Miniscript type lattice

This file models the Miniscript type system of Bitcoin Core's
`src/script/miniscript.h`, restricted to the fragments modelled in
`Bitcoin.Wallet.Miniscript.Node`.  A `MSType` is a set of the nineteen
boolean properties Core packs into a 32-bit mask (`miniscript.h:129-197`):

* base properties `B V K W`;
* stack-shape properties `z o n d u`;
* malleability properties `e f s m x`;
* timelock properties `g h i j k`.

The encoding is deliberately the same as Core's `_mst` literal: property
`p` is bit `p.bit`, and `Sub a b` is Core's `a << b` ("`a` is a subtype of
`b`").  `Sanitize` mirrors `internal::SanitizeType`
(`src/script/miniscript.cpp:18-40`): a computed mask with no base property
is the empty type, because it denotes no valid expression.

What is **not** modelled here: the debug assertions in `SanitizeType`
(the implication and conflict checks are exposed as
`WellFormed` but `Sanitize` does not enforce them), and the `x` bit's
script-level meaning beyond `ToScript`'s `OP_VERIFY` folding.  There is
no parser for Core's `_mst` string literal; types are built with `ty`.
-/

namespace Bitcoin.Wallet.Miniscript

/-- The nineteen Miniscript type properties, in the bit order of Core's
`operator""_mst` (`src/script/miniscript.h:161-197`). -/
inductive Ty where
  /-- `B`: base expression, leaves one boolean on the stack. -/
  | B
  /-- `V`: verify expression, leaves nothing on success. -/
  | V
  /-- `K`: key expression, leaves a public key on the stack. -/
  | K
  /-- `W`: wrapped expression, takes one argument off the stack. -/
  | W
  /-- `z`: zero-argument satisfaction/dissatisfaction. -/
  | z
  /-- `o`: one-argument satisfaction/dissatisfaction. -/
  | o
  /-- `n`: nonzero top stack element in every satisfaction. -/
  | n
  /-- `d`: a dissatisfaction is available. -/
  | d
  /-- `u`: satisfaction leaves exactly `1` on the stack. -/
  | u
  /-- `e`: non-malleable dissatisfaction (implies `d`). -/
  | e
  /-- `f`: dissatisfactions require a signature. -/
  | f
  /-- `s`: satisfactions require a signature. -/
  | s
  /-- `m`: non-malleable satisfaction. -/
  | m
  /-- `x`: last opcode is not `EQUAL`, `CHECKSIG` or `CHECKMULTISIG`. -/
  | x
  /-- `g`: contains a relative-time (`CSV`) timelock. -/
  | g
  /-- `h`: contains a relative-height (`CSV`) timelock. -/
  | h
  /-- `i`: contains an absolute-time (`CLTV`) timelock. -/
  | i
  /-- `j`: contains an absolute-height (`CLTV`) timelock. -/
  | j
  /-- `k`: no satisfaction mixes height and time locks of one kind. -/
  | k
deriving DecidableEq, Repr

/-- Bit position of a property, matching `miniscript.h:163-181`. -/
def Ty.bit : Ty → Nat
  | .B => 0
  | .V => 1
  | .K => 2
  | .W => 3
  | .z => 4
  | .o => 5
  | .n => 6
  | .d => 7
  | .u => 8
  | .e => 9
  | .f => 10
  | .s => 11
  | .m => 12
  | .x => 13
  | .g => 14
  | .h => 15
  | .i => 16
  | .j => 17
  | .k => 18

/-- A Miniscript type: a 19-bit property mask.  Equality is mask
equality, as in Core's `MSType::operator==`. -/
structure MSType where
  /-- Raw property mask; bit `p.bit` is set iff property `p` holds. -/
  mask : Nat
deriving DecidableEq, Repr

namespace MSType

/-- The empty type (`""_mst`), denoting an ill-typed expression. -/
def empty : MSType := ⟨0⟩

/-- The type consisting of one property. -/
def ofTy (p : Ty) : MSType := ⟨1 <<< p.bit⟩

/-- Union of properties, Core's `MSType::operator|`. -/
def union (a b : MSType) : MSType := ⟨a.mask ||| b.mask⟩

/-- Intersection of properties, Core's `MSType::operator&`. -/
def inter (a b : MSType) : MSType := ⟨a.mask &&& b.mask⟩

/-- `a` is a subtype of `b`, Core's `MSType::operator<<`. -/
def Sub (a b : MSType) : Bool := (a.mask &&& b.mask) == b.mask

/-- Does the type contain property `p`? -/
def has (t : MSType) (p : Ty) : Bool := t.mask.testBit p.bit

/-- Core's `MSType::If`: the empty type when the condition is false,
`t` otherwise. -/
def if_ (c : Bool) (t : MSType) : MSType := if c then t else empty

/-- The union of a list of properties. -/
def ofList (ps : List Ty) : MSType := ps.foldl (fun acc p => acc.union (ofTy p)) empty

/-- Any base property (`B`, `V`, `K`, `W`) present? -/
def hasBase (t : MSType) : Bool := t.has .B || t.has .V || t.has .K || t.has .W

/-- `Sanitize` as in `miniscript.cpp:18-40`: a mask with no base property
is replaced by the empty type.  The conflict/implication assertions of
Core are not enforced here; `WellFormed` states them separately. -/
def sanitize (t : MSType) : MSType := if t.hasBase then t else empty

/-- The invariants Core asserts in `SanitizeType`
(`src/script/miniscript.cpp:21-38`), expressed as a decidable predicate.
This is a checker, not a proof obligation: `Sanitize` does not reject a
type that violates it. -/
def WellFormed (e : MSType) : Bool :=
  let count :=
    (if Sub e (ofTy .K) then 1 else 0) +
    (if Sub e (ofTy .V) then 1 else 0) +
    (if Sub e (ofTy .B) then 1 else 0) +
    (if Sub e (ofTy .W) then 1 else 0)
  (count ≤ 1) &&
  !(has e .z && has e .o) &&
  !(has e .n && has e .z) &&
  !(has e .n && has e .W) &&
  !(has e .V && has e .d) &&
  (!(has e .K) || has e .u) &&
  !(has e .V && has e .u) &&
  !(has e .e && has e .f) &&
  (!(has e .e) || has e .d) &&
  !(has e .V && has e .e) &&
  !(has e .d && has e .f) &&
  (!(has e .V) || has e .f) &&
  (!(has e .K) || has e .s) &&
  (!(has e .z) || has e .m)

end MSType

/-- Build a type from a list of properties. -/
def ty (ps : List Ty) : MSType := MSType.ofList ps

/-- Miniscript evaluation context: legacy witness v0 script (BIP141)
or tapscript (BIP342).  Core's `MiniscriptContext`
(`src/script/miniscript.h:249-254`). -/
inductive MiniscriptContext where
  /-- P2WSH witness script context (BIP141). -/
  | p2wsh
  /-- Tapscript leaf context (BIP342). -/
  | tapscript
deriving DecidableEq, Repr

end Bitcoin.Wallet.Miniscript
