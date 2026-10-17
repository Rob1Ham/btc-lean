import Bitcoin.Wallet.Miniscript
import Bitcoin.Wallet.RuleAttr

/-!
# Miniscript type soundness (B/V/K/W)

This file proves the `B`, `V`, `K` and `W` part of the Miniscript type
table of `Bitcoin.Wallet.Miniscript.Node.calcType`, the model of Core's
`ComputeType` (`src/script/miniscript.cpp:43-259` at pin `cce32b168`).

Two layers are proved:

* **Table equations** (`calcType_pkK`, `calcType_wrapA`, ...): the computed
  mask of each modelled fragment, in terms of a public mirror `U2` of the
  model's private union helper.  The mirrors are definitionally equal to the
  private helpers, so the equations are `rfl` after unfolding `calcType`.
* **Property characterisations** (`wrapA_hasB`, `andB_hasB`, ...): for each
  fragment and each base property, a Boolean formula in the child types.
  These are the `B/V/K/W` columns of Core's `ComputeType`.

What is **not** modelled or claimed: execution of the emitted script, the
consensus interpreter, signature/preimage knowledge, the `e/f/s/m/z/o/n/d/u`
malleability and stack-shape columns beyond what the `B/V/K/W` formulas
mention, and the `SanitizeType` debug assertions (`MSType.WellFormed`).
`calcType` itself already contains the model's `thresh`, `multi` and
`multi_a` validity gates; the equations below expose those gates rather than
proving them against Core's scheduler.
-/

namespace BitcoinProofs.Wallet.Miniscript

open Bitcoin.Wallet.Miniscript
open Bitcoin.Wallet.Miniscript.Node
open Bitcoin.Wallet.Miniscript.MSType

/-! ## Type-mask helpers -/

theorem has_ofTy (p q : Ty) :
    (MSType.ofTy p).has q = (p == q) := by
  cases p <;> cases q <;> rfl

theorem has_empty (p : Ty) : (MSType.empty.has p) = false := by
  simp [MSType.empty, MSType.has]

theorem has_union (a b : MSType) (p : Ty) :
    (a.union b).has p = (a.has p || b.has p) := by
  simp [MSType.union, MSType.has, Nat.testBit_or]

theorem has_inter (a b : MSType) (p : Ty) :
    (a.inter b).has p = (a.has p && b.has p) := by
  simp [MSType.inter, MSType.has, Nat.testBit_and]

theorem has_if_ (c : Bool) (t : MSType) (p : Ty) :
    (MSType.if_ c t).has p = (c && t.has p) := by
  cases c <;> simp [MSType.if_, has_empty]

theorem has_foldl_union (init : MSType) (ps : List Ty) (p : Ty) :
    ((ps.foldl (fun acc q => acc.union (MSType.ofTy q)) init).has p) =
      (init.has p || ps.any (fun q => (MSType.ofTy q).has p)) := by
  induction ps generalizing init with
  | nil => simp
  | cons q qs ih =>
    simp only [List.foldl_cons, ih, has_union, List.any_cons]
    cases init.has p <;> cases (MSType.ofTy q).has p <;>
      cases qs.any (fun q => (MSType.ofTy q).has p) <;> rfl

theorem has_ofList (ps : List Ty) (p : Ty) :
    (MSType.ofList ps).has p = ps.any (fun q => (MSType.ofTy q).has p) := by
  simp [MSType.ofList, has_foldl_union, has_empty]

theorem has_ty (ps : List Ty) (p : Ty) :
    (ty ps).has p = ps.any (fun q => (MSType.ofTy q).has p) := by
  simp [ty, has_ofList]

/-- Public mirror of the model's private list-union helper. -/
def U2 (ts : List MSType) : MSType :=
  ts.foldl (fun a b => a.union b) MSType.empty

/-- Public mirror of the model's private timelock-mix test. -/
def mixedLocks2 (a b : MSType) : Bool :=
  (a.has .g && b.has .h) || (a.has .h && b.has .g) ||
  (a.has .i && b.has .j) || (a.has .j && b.has .i)

theorem has_foldl_union_types (init : MSType) (ts : List MSType) (p : Ty) :
    ((ts.foldl (fun a b => a.union b) init).has p) =
      (init.has p || ts.any (fun t => t.has p)) := by
  induction ts generalizing init with
  | nil => simp
  | cons t ts ih =>
    simp only [List.foldl_cons, ih, has_union, List.any_cons]
    cases init.has p <;> cases t.has p <;>
      cases ts.any (fun t => t.has p) <;> rfl

theorem has_U2 (ts : List MSType) (p : Ty) :
    (U2 ts).has p = ts.any (fun t => t.has p) := by
  simp [U2, has_foldl_union_types, has_empty]

theorem mixedLocks2_eq_true (a b : MSType) :
    mixedLocks2 a b = true →
      ((a.has .g && b.has .h) || (a.has .h && b.has .g) ||
        (a.has .i && b.has .j) || (a.has .j && b.has .i)) = true := by
  intro h
  simpa [mixedLocks2] using h

end BitcoinProofs.Wallet.Miniscript

namespace BitcoinProofs.Wallet.Miniscript

open Bitcoin.Wallet.Miniscript
open Bitcoin.Wallet.Miniscript.Node
open Bitcoin.Wallet.Miniscript.MSType

/-! ## Fragment type equations -/

@[walletRule "MS-002"]
theorem calcType_pkK (ctx : MiniscriptContext) (key : Key) :
    calcType ctx (.pkK key) = ty [.K, .o, .n, .u, .d, .e, .m, .s, .x, .k] := by
  simp only [calcType]

@[walletRule "MS-003"]
theorem calcType_pkH (ctx : MiniscriptContext) (key keyHash : Key) :
    calcType ctx (.pkH key keyHash) =
      ty [.K, .n, .u, .d, .e, .m, .s, .x, .k] := by
  simp only [calcType]

@[walletRule "MS-007"]
theorem calcType_wrapA (ctx : MiniscriptContext) (x : Node) :
    calcType ctx (.wrapA x) = U2 [
      MSType.if_ ((calcType ctx x).Sub (ty [.B])) (ty [.W]),
      (calcType ctx x).inter (ty [.g, .h, .i, .j, .k]),
      (calcType ctx x).inter (ty [.u, .d, .f, .e, .m, .s]),
      ty [.x]] := by
  simp only [calcType]
  rfl

@[walletRule "MS-004"]
theorem calcType_older (ctx : MiniscriptContext) (n : Nat) :
    calcType ctx (.older n) =
      (if n = 0 || n ≥ 0x80000000 then MSType.empty else U2 [
        MSType.if_ ((n &&& 0x400000) ≠ 0) (ty [.g]),
        MSType.if_ ((n &&& 0x400000) = 0) (ty [.h]),
        ty [.B, .z, .f, .m, .x, .k]]) := by
  simp only [calcType]
  rfl

@[walletRule "MS-005"]
theorem calcType_after (ctx : MiniscriptContext) (n : Nat) :
    calcType ctx (.after n) =
      (if n = 0 || n ≥ 0x80000000 then MSType.empty else U2 [
        MSType.if_ (n ≥ 500000000) (ty [.i]),
        MSType.if_ (n < 500000000) (ty [.j]),
        ty [.B, .z, .f, .m, .x, .k]]) := by
  simp only [calcType]
  rfl

theorem calcType_sha256 (ctx : MiniscriptContext) (h : ByteArray) :
    calcType ctx (.sha256 h) =
      (if h.size ≠ 32 then MSType.empty else ty [.B, .o, .n, .u, .d, .m, .k]) := by
  simp only [calcType]

theorem calcType_hash256 (ctx : MiniscriptContext) (h : ByteArray) :
    calcType ctx (.hash256 h) =
      (if h.size ≠ 32 then MSType.empty else ty [.B, .o, .n, .u, .d, .m, .k]) := by
  simp only [calcType]

theorem calcType_ripemd160 (ctx : MiniscriptContext) (h : ByteArray) :
    calcType ctx (.ripemd160 h) =
      (if h.size ≠ 20 then MSType.empty else ty [.B, .o, .n, .u, .d, .m, .k]) := by
  simp only [calcType]

theorem calcType_hash160 (ctx : MiniscriptContext) (h : ByteArray) :
    calcType ctx (.hash160 h) =
      (if h.size ≠ 20 then MSType.empty else ty [.B, .o, .n, .u, .d, .m, .k]) := by
  simp only [calcType]

/-- MS-006: the four hash fragments jointly have type B,o,n,u,d,m,k at their
Core digest sizes (32 bytes for SHA256/HASH256, 20 for RIPEMD160/HASH160),
and the empty type otherwise. -/
@[walletRule "MS-006"]
theorem calcType_hash_fragments (ctx : MiniscriptContext) (h : ByteArray) :
    calcType ctx (.sha256 h) =
      (if h.size ≠ 32 then MSType.empty else ty [.B, .o, .n, .u, .d, .m, .k]) ∧
    calcType ctx (.hash256 h) =
      (if h.size ≠ 32 then MSType.empty else ty [.B, .o, .n, .u, .d, .m, .k]) ∧
    calcType ctx (.ripemd160 h) =
      (if h.size ≠ 20 then MSType.empty else ty [.B, .o, .n, .u, .d, .m, .k]) ∧
    calcType ctx (.hash160 h) =
      (if h.size ≠ 20 then MSType.empty else ty [.B, .o, .n, .u, .d, .m, .k]) := by
  exact ⟨calcType_sha256 ctx h, calcType_hash256 ctx h,
    calcType_ripemd160 ctx h, calcType_hash160 ctx h⟩


@[walletRule "MS-008"]
theorem calcType_wrapS (ctx : MiniscriptContext) (x : Node) :
    calcType ctx (.wrapS x) = U2 [
      MSType.if_ ((calcType ctx x).Sub (ty [.B, .o])) (ty [.W]),
      (calcType ctx x).inter (ty [.g, .h, .i, .j, .k]),
      (calcType ctx x).inter (ty [.u, .d, .f, .e, .m, .s, .x])] := by
  simp only [calcType]
  rfl

@[walletRule "MS-009"]
theorem calcType_wrapC (ctx : MiniscriptContext) (x : Node) :
    calcType ctx (.wrapC x) = U2 [
      MSType.if_ ((calcType ctx x).Sub (ty [.K])) (ty [.B]),
      (calcType ctx x).inter (ty [.g, .h, .i, .j, .k]),
      (calcType ctx x).inter (ty [.o, .n, .d, .f, .e, .m]),
      ty [.u, .s]] := by
  simp only [calcType]
  rfl

@[walletRule "MS-010"]
theorem calcType_wrapD (ctx : MiniscriptContext) (x : Node) :
    calcType ctx (.wrapD x) = U2 [
      MSType.if_ ((calcType ctx x).Sub (ty [.V, .z])) (ty [.B]),
      MSType.if_ ((calcType ctx x).Sub (ty [.z])) (ty [.o]),
      MSType.if_ ((calcType ctx x).Sub (ty [.f])) (ty [.e]),
      (calcType ctx x).inter (ty [.g, .h, .i, .j, .k]),
      (calcType ctx x).inter (ty [.m, .s]),
      MSType.if_ (ctx = .tapscript) (ty [.u]),
      ty [.n, .d, .x]] := by
  simp only [calcType]
  rfl

@[walletRule "MS-011"]
theorem calcType_wrapV (ctx : MiniscriptContext) (x : Node) :
    calcType ctx (.wrapV x) = U2 [
      MSType.if_ ((calcType ctx x).Sub (ty [.B])) (ty [.V]),
      (calcType ctx x).inter (ty [.g, .h, .i, .j, .k]),
      (calcType ctx x).inter (ty [.z, .o, .n, .m, .s]),
      ty [.f, .x]] := by
  simp only [calcType]
  rfl

@[walletRule "MS-012"]
theorem calcType_wrapJ (ctx : MiniscriptContext) (x : Node) :
    calcType ctx (.wrapJ x) = U2 [
      MSType.if_ ((calcType ctx x).Sub (ty [.B, .n])) (ty [.B]),
      MSType.if_ ((calcType ctx x).Sub (ty [.f])) (ty [.e]),
      (calcType ctx x).inter (ty [.g, .h, .i, .j, .k]),
      (calcType ctx x).inter (ty [.o, .u, .m, .s]),
      ty [.n, .d, .x]] := by
  simp only [calcType]
  rfl

theorem calcType_wrapN (ctx : MiniscriptContext) (x : Node) :
    calcType ctx (.wrapN x) = U2 [
      (calcType ctx x).inter (ty [.g, .h, .i, .j, .k]),
      (calcType ctx x).inter (ty [.B, .z, .o, .n, .d, .f, .e, .m, .s]),
      ty [.u, .x]] := by
  simp only [calcType]
  rfl

@[walletRule "MS-013"]
theorem calcType_andV (ctx : MiniscriptContext) (x y : Node) :
    calcType ctx (.andV x y) = U2 [
      MSType.if_ ((calcType ctx x).Sub (ty [.V]))
        ((calcType ctx y).inter (ty [.K, .V, .B])),
      (calcType ctx x).inter (ty [.n]),
      MSType.if_ ((calcType ctx x).Sub (ty [.z]))
        ((calcType ctx y).inter (ty [.n])),
      MSType.if_ (((calcType ctx x).union (calcType ctx y)).Sub (ty [.z]))
        (((calcType ctx x).union (calcType ctx y)).inter (ty [.o])),
      ((calcType ctx x).inter (calcType ctx y)).inter (ty [.m, .z]),
      ((calcType ctx x).union (calcType ctx y)).inter (ty [.s]),
      MSType.if_ ((calcType ctx y).Sub (ty [.f]) ||
        (calcType ctx x).Sub (ty [.s])) (ty [.f]),
      (calcType ctx y).inter (ty [.u, .x]),
      ((calcType ctx x).union (calcType ctx y)).inter (ty [.g, .h, .i, .j]),
      MSType.if_ ((((calcType ctx x).inter (calcType ctx y)).Sub (ty [.k])) &&
        !mixedLocks2 (calcType ctx x) (calcType ctx y)) (ty [.k])] := by
  simp only [calcType]
  rfl

theorem calcType_andB (ctx : MiniscriptContext) (x y : Node) :
    calcType ctx (.andB x y) = U2 [
      MSType.if_ ((calcType ctx y).Sub (ty [.W]))
        ((calcType ctx x).inter (ty [.B])),
      MSType.if_ (((calcType ctx x).union (calcType ctx y)).Sub (ty [.z]))
        (((calcType ctx x).union (calcType ctx y)).inter (ty [.o])),
      (calcType ctx x).inter (ty [.n]),
      MSType.if_ ((calcType ctx x).Sub (ty [.z]))
        ((calcType ctx y).inter (ty [.n])),
      MSType.if_ (((calcType ctx x).inter (calcType ctx y)).Sub (ty [.s]))
        (((calcType ctx x).inter (calcType ctx y)).inter (ty [.e])),
      ((calcType ctx x).inter (calcType ctx y)).inter (ty [.d, .z, .m]),
      MSType.if_ (((calcType ctx x).inter (calcType ctx y)).Sub (ty [.f]) ||
        (calcType ctx x).Sub (ty [.s, .f]) ||
        (calcType ctx y).Sub (ty [.s, .f])) (ty [.f]),
      ((calcType ctx x).union (calcType ctx y)).inter (ty [.s]),
      ty [.u, .x],
      ((calcType ctx x).union (calcType ctx y)).inter (ty [.g, .h, .i, .j]),
      MSType.if_ ((((calcType ctx x).inter (calcType ctx y)).Sub (ty [.k])) &&
        !mixedLocks2 (calcType ctx x) (calcType ctx y)) (ty [.k])] := by
  simp only [calcType]
  rfl

@[walletRule "MS-015"]
theorem calcType_orB (ctx : MiniscriptContext) (x y : Node) :
    calcType ctx (.orB x y) = U2 [
      MSType.if_ ((calcType ctx x).Sub (ty [.B, .d]) &&
        (calcType ctx y).Sub (ty [.W, .d])) (ty [.B]),
      MSType.if_ (((calcType ctx x).union (calcType ctx y)).Sub (ty [.z]))
        (((calcType ctx x).union (calcType ctx y)).inter (ty [.o])),
      MSType.if_ (((calcType ctx x).union (calcType ctx y)).Sub (ty [.s]) &&
        ((calcType ctx x).inter (calcType ctx y)).Sub (ty [.e]))
        (((calcType ctx x).inter (calcType ctx y)).inter (ty [.m])),
      ((calcType ctx x).inter (calcType ctx y)).inter (ty [.z, .s, .e]),
      ty [.d, .u, .x],
      ((calcType ctx x).union (calcType ctx y)).inter (ty [.g, .h, .i, .j]),
      ((calcType ctx x).inter (calcType ctx y)).inter (ty [.k])] := by
  simp only [calcType]
  rfl

theorem calcType_orD (ctx : MiniscriptContext) (x y : Node) :
    calcType ctx (.orD x y) = U2 [
      MSType.if_ ((calcType ctx x).Sub (ty [.B, .d, .u]))
        ((calcType ctx y).inter (ty [.B])),
      MSType.if_ ((calcType ctx y).Sub (ty [.z]))
        ((calcType ctx x).inter (ty [.o])),
      MSType.if_ ((calcType ctx x).Sub (ty [.e]) &&
        ((calcType ctx x).union (calcType ctx y)).Sub (ty [.s]))
        (((calcType ctx x).inter (calcType ctx y)).inter (ty [.m])),
      ((calcType ctx x).inter (calcType ctx y)).inter (ty [.z, .s]),
      (calcType ctx y).inter (ty [.u, .f, .d, .e]),
      ty [.x],
      ((calcType ctx x).union (calcType ctx y)).inter (ty [.g, .h, .i, .j]),
      ((calcType ctx x).inter (calcType ctx y)).inter (ty [.k])] := by
  simp only [calcType]
  rfl

@[walletRule "MS-017"]
theorem calcType_orC (ctx : MiniscriptContext) (x y : Node) :
    calcType ctx (.orC x y) = U2 [
      MSType.if_ ((calcType ctx x).Sub (ty [.B, .d, .u]))
        ((calcType ctx y).inter (ty [.V])),
      MSType.if_ ((calcType ctx y).Sub (ty [.z]))
        ((calcType ctx x).inter (ty [.o])),
      MSType.if_ ((calcType ctx x).Sub (ty [.e]) &&
        ((calcType ctx x).union (calcType ctx y)).Sub (ty [.s]))
        (((calcType ctx x).inter (calcType ctx y)).inter (ty [.m])),
      ((calcType ctx x).inter (calcType ctx y)).inter (ty [.z, .s]),
      ty [.f, .x],
      ((calcType ctx x).union (calcType ctx y)).inter (ty [.g, .h, .i, .j]),
      ((calcType ctx x).inter (calcType ctx y)).inter (ty [.k])] := by
  simp only [calcType]
  rfl

@[walletRule "MS-018"]
theorem calcType_orI (ctx : MiniscriptContext) (x y : Node) :
    calcType ctx (.orI x y) = U2 [
      ((calcType ctx x).inter (calcType ctx y)).inter (ty [.V, .B, .K, .u, .f, .s]),
      MSType.if_ (((calcType ctx x).inter (calcType ctx y)).Sub (ty [.z]))
        (ty [.o]),
      MSType.if_ (((calcType ctx x).union (calcType ctx y)).Sub (ty [.f]))
        (((calcType ctx x).union (calcType ctx y)).inter (ty [.e])),
      MSType.if_ (((calcType ctx x).union (calcType ctx y)).Sub (ty [.s]))
        (((calcType ctx x).inter (calcType ctx y)).inter (ty [.m])),
      ((calcType ctx x).union (calcType ctx y)).inter (ty [.d]),
      ty [.x],
      ((calcType ctx x).union (calcType ctx y)).inter (ty [.g, .h, .i, .j]),
      ((calcType ctx x).inter (calcType ctx y)).inter (ty [.k])] := by
  simp only [calcType]
  rfl

@[walletRule "MS-020"]
theorem calcType_multi (ctx : MiniscriptContext) (k : Nat) (keys : List Key) :
    calcType ctx (.multi k keys) =
      (if ctx = .tapscript || k = 0 || k > keys.length || keys.length > 20
        then MSType.empty
        else ty [.B, .n, .u, .d, .e, .m, .s, .k]) := by
  simp only [calcType]

@[walletRule "MS-021"]
theorem calcType_multiA (ctx : MiniscriptContext) (k : Nat) (keys : List Key) :
    calcType ctx (.multiA k keys) =
      (if ctx = .p2wsh || k = 0 || k > keys.length || keys.length > 999
        then MSType.empty
        else ty [.B, .u, .d, .e, .m, .s, .k]) := by
  simp only [calcType]


/-! ## Base-property characterisations -/

theorem pkK_hasB (ctx : MiniscriptContext) (key : Key) :
    (calcType ctx (.pkK key)).has .B = false := by
  rw [calcType_pkK]
  simp [has_ty, has_ofTy, List.any_cons]

theorem pkK_hasV (ctx : MiniscriptContext) (key : Key) :
    (calcType ctx (.pkK key)).has .V = false := by
  rw [calcType_pkK]
  simp [has_ty, has_ofTy, List.any_cons]

theorem pkK_hasK (ctx : MiniscriptContext) (key : Key) :
    (calcType ctx (.pkK key)).has .K = true := by
  rw [calcType_pkK]
  simp [has_ty, has_ofTy, List.any_cons]

theorem pkK_hasW (ctx : MiniscriptContext) (key : Key) :
    (calcType ctx (.pkK key)).has .W = false := by
  rw [calcType_pkK]
  simp [has_ty, has_ofTy, List.any_cons]

theorem wrapA_hasW (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapA x)).has .W =
      (calcType ctx x).Sub (ty [.B]) := by
  rw [calcType_wrapA]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapA_hasB (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapA x)).has .B = false := by
  rw [calcType_wrapA]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapA_hasV (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapA x)).has .V = false := by
  rw [calcType_wrapA]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapA_hasK (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapA x)).has .K = false := by
  rw [calcType_wrapA]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapS_hasW (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapS x)).has .W =
      (calcType ctx x).Sub (ty [.B, .o]) := by
  rw [calcType_wrapS]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapS_hasB (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapS x)).has .B = false := by
  rw [calcType_wrapS]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapS_hasV (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapS x)).has .V = false := by
  rw [calcType_wrapS]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapS_hasK (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapS x)).has .K = false := by
  rw [calcType_wrapS]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapC_hasB (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapC x)).has .B =
      (calcType ctx x).Sub (ty [.K]) := by
  rw [calcType_wrapC]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapC_hasV (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapC x)).has .V = false := by
  rw [calcType_wrapC]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapC_hasK (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapC x)).has .K = false := by
  rw [calcType_wrapC]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapC_hasW (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapC x)).has .W = false := by
  rw [calcType_wrapC]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapD_hasB (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapD x)).has .B =
      (calcType ctx x).Sub (ty [.V, .z]) := by
  rw [calcType_wrapD]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapD_hasV (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapD x)).has .V = false := by
  rw [calcType_wrapD]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapD_hasK (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapD x)).has .K = false := by
  rw [calcType_wrapD]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapD_hasW (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapD x)).has .W = false := by
  rw [calcType_wrapD]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapV_hasV (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapV x)).has .V =
      (calcType ctx x).Sub (ty [.B]) := by
  rw [calcType_wrapV]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapV_hasB (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapV x)).has .B = false := by
  rw [calcType_wrapV]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapV_hasK (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapV x)).has .K = false := by
  rw [calcType_wrapV]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapV_hasW (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapV x)).has .W = false := by
  rw [calcType_wrapV]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapJ_hasB (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapJ x)).has .B =
      (calcType ctx x).Sub (ty [.B, .n]) := by
  rw [calcType_wrapJ]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapJ_hasV (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapJ x)).has .V = false := by
  rw [calcType_wrapJ]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapJ_hasK (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapJ x)).has .K = false := by
  rw [calcType_wrapJ]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapJ_hasW (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapJ x)).has .W = false := by
  rw [calcType_wrapJ]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapN_hasB (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapN x)).has .B = (calcType ctx x).has .B := by
  rw [calcType_wrapN]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]
  have hg : (Ty.g == Ty.B || (Ty.h == Ty.B || (Ty.i == Ty.B ||
      (Ty.j == Ty.B || Ty.k == Ty.B)))) = false := by decide
  have hu : (Ty.u == Ty.B || Ty.x == Ty.B) = false := by decide
  simp [hg, hu]

theorem wrapN_hasV (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapN x)).has .V = false := by
  rw [calcType_wrapN]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapN_hasK (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapN x)).has .K = false := by
  rw [calcType_wrapN]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem wrapN_hasW (ctx : MiniscriptContext) (x : Node) :
    (calcType ctx (.wrapN x)).has .W = false := by
  rw [calcType_wrapN]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]


theorem andV_hasB (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.andV x y)).has .B =
      ((calcType ctx x).Sub (ty [.V]) && (calcType ctx y).has .B) := by
  rw [calcType_andV]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem andV_hasV (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.andV x y)).has .V =
      ((calcType ctx x).Sub (ty [.V]) && (calcType ctx y).has .V) := by
  rw [calcType_andV]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem andV_hasK (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.andV x y)).has .K =
      ((calcType ctx x).Sub (ty [.V]) && (calcType ctx y).has .K) := by
  rw [calcType_andV]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem andV_hasW (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.andV x y)).has .W = false := by
  rw [calcType_andV]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem andB_hasB (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.andB x y)).has .B =
      ((calcType ctx y).Sub (ty [.W]) && (calcType ctx x).has .B) := by
  rw [calcType_andB]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem andB_hasV (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.andB x y)).has .V = false := by
  rw [calcType_andB]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem andB_hasK (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.andB x y)).has .K = false := by
  rw [calcType_andB]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem andB_hasW (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.andB x y)).has .W = false := by
  rw [calcType_andB]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orB_hasB (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orB x y)).has .B =
      ((calcType ctx x).Sub (ty [.B, .d]) &&
        (calcType ctx y).Sub (ty [.W, .d])) := by
  rw [calcType_orB]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orB_hasV (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orB x y)).has .V = false := by
  rw [calcType_orB]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orB_hasK (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orB x y)).has .K = false := by
  rw [calcType_orB]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orB_hasW (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orB x y)).has .W = false := by
  rw [calcType_orB]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orD_hasB (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orD x y)).has .B =
      ((calcType ctx x).Sub (ty [.B, .d, .u]) && (calcType ctx y).has .B) := by
  rw [calcType_orD]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orD_hasV (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orD x y)).has .V = false := by
  rw [calcType_orD]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orD_hasK (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orD x y)).has .K = false := by
  rw [calcType_orD]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orD_hasW (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orD x y)).has .W = false := by
  rw [calcType_orD]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orC_hasV (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orC x y)).has .V =
      ((calcType ctx x).Sub (ty [.B, .d, .u]) && (calcType ctx y).has .V) := by
  rw [calcType_orC]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orC_hasB (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orC x y)).has .B = false := by
  rw [calcType_orC]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orC_hasK (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orC x y)).has .K = false := by
  rw [calcType_orC]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orC_hasW (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orC x y)).has .W = false := by
  rw [calcType_orC]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orI_hasB (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orI x y)).has .B =
      ((calcType ctx x).has .B && (calcType ctx y).has .B) := by
  rw [calcType_orI]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orI_hasV (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orI x y)).has .V =
      ((calcType ctx x).has .V && (calcType ctx y).has .V) := by
  rw [calcType_orI]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orI_hasK (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orI x y)).has .K =
      ((calcType ctx x).has .K && (calcType ctx y).has .K) := by
  rw [calcType_orI]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem orI_hasW (ctx : MiniscriptContext) (x y : Node) :
    (calcType ctx (.orI x y)).has .W = false := by
  rw [calcType_orI]
  simp [has_U2, has_if_, has_inter, has_union, has_ty, has_ofTy, List.any_cons]

theorem multi_hasB (ctx : MiniscriptContext) (k : Nat) (keys : List Key) :
    (calcType ctx (.multi k keys)).has .B =
      (if ctx = .tapscript || k = 0 || k > keys.length || keys.length > 20
        then false else true) := by
  rw [calcType_multi]
  split
  · simp [has_empty]
  · simp [has_ty, has_ofTy, List.any_cons]

theorem multi_hasV (ctx : MiniscriptContext) (k : Nat) (keys : List Key) :
    (calcType ctx (.multi k keys)).has .V = false := by
  rw [calcType_multi]
  split
  · simp [has_empty]
  · simp [has_ty, has_ofTy, List.any_cons]

theorem multi_hasK (ctx : MiniscriptContext) (k : Nat) (keys : List Key) :
    (calcType ctx (.multi k keys)).has .K = false := by
  rw [calcType_multi]
  split
  · simp [has_empty]
  · simp [has_ty, has_ofTy, List.any_cons]

theorem multi_hasW (ctx : MiniscriptContext) (k : Nat) (keys : List Key) :
    (calcType ctx (.multi k keys)).has .W = false := by
  rw [calcType_multi]
  split
  · simp [has_empty]
  · simp [has_ty, has_ofTy, List.any_cons]

theorem multiA_hasB (ctx : MiniscriptContext) (k : Nat) (keys : List Key) :
    (calcType ctx (.multiA k keys)).has .B =
      (if ctx = .p2wsh || k = 0 || k > keys.length || keys.length > 999
        then false else true) := by
  rw [calcType_multiA]
  split
  · simp [has_empty]
  · simp [has_ty, has_ofTy, List.any_cons]

theorem multiA_hasV (ctx : MiniscriptContext) (k : Nat) (keys : List Key) :
    (calcType ctx (.multiA k keys)).has .V = false := by
  rw [calcType_multiA]
  split
  · simp [has_empty]
  · simp [has_ty, has_ofTy, List.any_cons]

theorem multiA_hasK (ctx : MiniscriptContext) (k : Nat) (keys : List Key) :
    (calcType ctx (.multiA k keys)).has .K = false := by
  rw [calcType_multiA]
  split
  · simp [has_empty]
  · simp [has_ty, has_ofTy, List.any_cons]

theorem multiA_hasW (ctx : MiniscriptContext) (k : Nat) (keys : List Key) :
    (calcType ctx (.multiA k keys)).has .W = false := by
  rw [calcType_multiA]
  split
  · simp [has_empty]
  · simp [has_ty, has_ofTy, List.any_cons]


/-! ## Timelock classification (height versus time) -/

/-- A relative timelock with the BIP68 type flag set is a **time**
(`g`) lock, not a height (`h`) lock. -/
theorem older_has_g (ctx : MiniscriptContext) (n : Nat)
    (hpos : 1 ≤ n) (hmax : n < 0x80000000)
    (hflag : n &&& 0x400000 ≠ 0) :
    (calcType ctx (.older n)).has .g = true := by
  rw [calcType_older]
  have hvalid : ¬ (n = 0 || n ≥ 0x80000000) := by
    have h0 : ¬ n = 0 := by omega
    have hlt : ¬ n ≥ 0x80000000 := by omega
    simp [h0, hlt]
  simp [hvalid, has_U2, has_if_, has_ty, has_ofTy, List.any_cons, hflag,
    decide_eq_true_eq]

/-- A relative timelock without the BIP68 type flag is a **height** (`h`)
lock, not a time (`g`) lock. -/
theorem older_has_h (ctx : MiniscriptContext) (n : Nat)
    (hpos : 1 ≤ n) (hmax : n < 0x80000000)
    (hflag : n &&& 0x400000 = 0) :
    (calcType ctx (.older n)).has .h = true := by
  rw [calcType_older]
  have hvalid : ¬ (n = 0 || n ≥ 0x80000000) := by
    have h0 : ¬ n = 0 := by omega
    have hlt : ¬ n ≥ 0x80000000 := by omega
    simp [h0, hlt]
  simp [hvalid, has_U2, has_if_, has_ty, has_ofTy, List.any_cons, hflag,
    decide_eq_true_eq]

theorem older_hasB (ctx : MiniscriptContext) (n : Nat)
    (hpos : 1 ≤ n) (hmax : n < 0x80000000) :
    (calcType ctx (.older n)).has .B = true := by
  rw [calcType_older]
  have hvalid : ¬ (n = 0 || n ≥ 0x80000000) := by
    have h0 : ¬ n = 0 := by omega
    have hlt : ¬ n ≥ 0x80000000 := by omega
    simp [h0, hlt]
  simp [hvalid, has_U2, has_if_, has_ty, has_ofTy, List.any_cons]

/-- An absolute locktime at or above `LOCKTIME_THRESHOLD` (500000000) is a
**time** (`i`) lock. -/
theorem after_has_i (ctx : MiniscriptContext) (n : Nat)
    (hpos : 1 ≤ n) (hmax : n < 0x80000000)
    (hthr : n ≥ 500000000) :
    (calcType ctx (.after n)).has .i = true := by
  rw [calcType_after]
  have hvalid : ¬ (n = 0 || n ≥ 0x80000000) := by
    have h0 : ¬ n = 0 := by omega
    have hlt : ¬ n ≥ 0x80000000 := by omega
    simp [h0, hlt]
  simp [hvalid, has_U2, has_if_, has_ty, has_ofTy, List.any_cons, hthr,
    decide_eq_true_eq]

/-- An absolute locktime below `LOCKTIME_THRESHOLD` is a **height** (`j`)
lock. -/
theorem after_has_j (ctx : MiniscriptContext) (n : Nat)
    (hpos : 1 ≤ n) (hmax : n < 0x80000000)
    (hthr : n < 500000000) :
    (calcType ctx (.after n)).has .j = true := by
  rw [calcType_after]
  have hvalid : ¬ (n = 0 || n ≥ 0x80000000) := by
    have h0 : ¬ n = 0 := by omega
    have hlt : ¬ n ≥ 0x80000000 := by omega
    simp [h0, hlt]
  simp [hvalid, has_U2, has_if_, has_ty, has_ofTy, List.any_cons, hthr,
    decide_eq_true_eq]

theorem after_hasB (ctx : MiniscriptContext) (n : Nat)
    (hpos : 1 ≤ n) (hmax : n < 0x80000000) :
    (calcType ctx (.after n)).has .B = true := by
  rw [calcType_after]
  have hvalid : ¬ (n = 0 || n ≥ 0x80000000) := by
    have h0 : ¬ n = 0 := by omega
    have hlt : ¬ n ≥ 0x80000000 := by omega
    simp [h0, hlt]
  simp [hvalid, has_U2, has_if_, has_ty, has_ofTy, List.any_cons]

end BitcoinProofs.Wallet.Miniscript
