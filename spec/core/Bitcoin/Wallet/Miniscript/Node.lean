import Bitcoin.Wallet.Miniscript.Type

/-!
# Miniscript nodes and canonical types

The node tree mirrors `miniscript::Node` (`src/script/miniscript.h:544-622`)
and the fragment enumeration at `src/script/miniscript.h:213-245`, for the
fragments listed below.  Keys are raw witness-program bytes (`ByteArray`):
33-byte compressed keys under `p2wsh`, 32-byte x-only keys under
`tapscript`.  The model does **not** validate key encodings; that belongs
to the key-expression and descriptor layers.

`calcType` is a direct transliteration of
`internal::ComputeType` (`src/script/miniscript.cpp:43-259`), including
Core's per-fragment "k" timelock-mix rule for `and_v`, `and_b`, `or_b`,
`or_d`, `or_c`, `or_i` and `thresh`.  Invalid parameters that Core rejects
while parsing (for example `older(0)`, `multi(k)` with `k > n`, or a
`multi_a` outside tapscript) yield the empty type, so that `IsSane`
rejects them.

Modelled fragments: `pk_k`, `pk_h`, `older`, `after`, `sha256`, `hash256`,
`ripemd160`, `hash160`, the wrappers `a s c d v j n`, and `and_v`,
`and_b`, `or_b`, `or_d`, `or_c`, `or_i`, `thresh`, `multi`, `multi_a`.
The constant fragments `0`/`1`, `andor` and its `and_n` abbreviation, and
the policy compiler are **not** modelled.
-/

namespace Bitcoin.Wallet.Miniscript

/-- A public key as it appears in a witness program: compressed SEC bytes
under P2WSH, x-only bytes under tapscript. -/
abbrev Key := ByteArray

/-- Miniscript fragment tags, matching `enum class Fragment`
(`src/script/miniscript.h:213-245`) restricted to the modelled set. -/
inductive Fragment where
  /-- `[key]` (`PK_K`). -/
  | pkK
  /-- `OP_DUP OP_HASH160 [keyhash] OP_EQUALVERIFY` (`PK_H`). -/
  | pkH
  /-- `[n] OP_CHECKSEQUENCEVERIFY` (`OLDER`). -/
  | older
  /-- `[n] OP_CHECKLOCKTIMEVERIFY` (`AFTER`). -/
  | after
  /-- `OP_SIZE 32 OP_EQUALVERIFY OP_SHA256 [hash] OP_EQUAL`. -/
  | sha256
  /-- `OP_SIZE 32 OP_EQUALVERIFY OP_HASH256 [hash] OP_EQUAL`. -/
  | hash256
  /-- `OP_SIZE 32 OP_EQUALVERIFY OP_RIPEMD160 [hash] OP_EQUAL`. -/
  | ripemd160
  /-- `OP_SIZE 32 OP_EQUALVERIFY OP_HASH160 [hash] OP_EQUAL`. -/
  | hash160
  /-- `OP_TOALTSTACK [X] OP_FROMALTSTACK` (`WRAP_A`). -/
  | wrapA
  /-- `OP_SWAP [X]` (`WRAP_S`). -/
  | wrapS
  /-- `[X] OP_CHECKSIG(VERIFY)` (`WRAP_C`). -/
  | wrapC
  /-- `OP_DUP OP_IF [X] OP_ENDIF` (`WRAP_D`). -/
  | wrapD
  /-- `[X]` with last opcode folded to its `-VERIFY` form (`WRAP_V`). -/
  | wrapV
  /-- `OP_SIZE OP_0NOTEQUAL OP_IF [X] OP_ENDIF` (`WRAP_J`). -/
  | wrapJ
  /-- `[X] OP_0NOTEQUAL` (`WRAP_N`). -/
  | wrapN
  /-- `[X] [Y]` (`AND_V`). -/
  | andV
  /-- `[X] [Y] OP_BOOLAND` (`AND_B`). -/
  | andB
  /-- `[X] [Y] OP_BOOLOR` (`OR_B`). -/
  | orB
  /-- `[X] OP_IFDUP OP_NOTIF [Y] OP_ENDIF` (`OR_D`). -/
  | orD
  /-- `[X] OP_NOTIF [Y] OP_ENDIF` (`OR_C`). -/
  | orC
  /-- `OP_IF [X] OP_ELSE [Y] OP_ENDIF` (`OR_I`). -/
  | orI
  /-- `[X1] ([Xn] OP_ADD)* [k] OP_EQUAL` (`THRESH`). -/
  | thresh
  /-- `[k] [key]* [n] OP_CHECKMULTISIG(VERIFY)` (`MULTI`, P2WSH only). -/
  | multi
  /-- `[key0] OP_CHECKSIG ([keyn] OP_CHECKSIGADD)* [k] OP_NUMEQUAL(VERIFY)`
      (`MULTI_A`, tapscript only). -/
  | multiA
deriving DecidableEq, Repr

/-- A Miniscript expression tree.  The subtree shape determines the
fragment: there is exactly one constructor per modelled fragment. -/
inductive Node where
  /-- `pk_k(key)`. -/
  | pkK (key : Key)
  /-- `pk_h(key)`; `keyHash` is the 20-byte HASH160 digest of `key`.
      The digest is data here, matching Core's `ctx.ToPKHBytes(key)`;
      this model does not recompute HASH160. -/
  | pkH (key : Key) (keyHash : ByteArray)
  /-- `older(n)`, a relative timelock; `1 ≤ n < 2^31`. -/
  | older (n : Nat)
  /-- `after(n)`, an absolute timelock; `1 ≤ n < 2^31`. -/
  | after (n : Nat)
  /-- `sha256(h)`; `h` is the 32-byte digest. -/
  | sha256 (h : ByteArray)
  /-- `hash256(h)`; `h` is the 32-byte digest. -/
  | hash256 (h : ByteArray)
  /-- `ripemd160(h)`; `h` is the 20-byte digest. -/
  | ripemd160 (h : ByteArray)
  /-- `hash160(h)`; `h` is the 20-byte digest. -/
  | hash160 (h : ByteArray)
  /-- `a:X`, the `OP_TOALTSTACK` wrapper. -/
  | wrapA (x : Node)
  /-- `s:X`, the `OP_SWAP` wrapper. -/
  | wrapS (x : Node)
  /-- `c:X`, the `OP_CHECKSIG(VERIFY)` wrapper. -/
  | wrapC (x : Node)
  /-- `d:X`, the `OP_DUP OP_IF` wrapper. -/
  | wrapD (x : Node)
  /-- `v:X`, the verify wrapper. -/
  | wrapV (x : Node)
  /-- `j:X`, the `OP_SIZE OP_0NOTEQUAL OP_IF` wrapper. -/
  | wrapJ (x : Node)
  /-- `n:X`, the `OP_0NOTEQUAL` wrapper. -/
  | wrapN (x : Node)
  /-- `and_v(X,Y)`. -/
  | andV (x y : Node)
  /-- `and_b(X,Y)`; requires `Y` of type `W`. -/
  | andB (x y : Node)
  /-- `or_b(X,Y)`; requires `Y` of type `W`. -/
  | orB (x y : Node)
  /-- `or_d(X,Y)`. -/
  | orD (x y : Node)
  /-- `or_c(X,Y)`. -/
  | orC (x y : Node)
  /-- `or_i(X,Y)`. -/
  | orI (x y : Node)
  /-- `thresh(k, [X1,...,Xn])`; `1 ≤ k ≤ n`. -/
  | thresh (k : Nat) (subs : List Node)
  /-- `multi(k, keys)`; P2WSH only, `1 ≤ k ≤ keys.length ≤ 20`. -/
  | multi (k : Nat) (keys : List Key)
  /-- `multi_a(k, keys)`; tapscript only, `1 ≤ k ≤ keys.length ≤ 999`. -/
  | multiA (k : Nat) (keys : List Key)
deriving Repr

/-- The fragment tag of a node. -/
def Node.fragment : Node → Fragment
  | .pkK _ => .pkK
  | .pkH _ _ => .pkH
  | .older _ => .older
  | .after _ => .after
  | .sha256 _ => .sha256
  | .hash256 _ => .hash256
  | .ripemd160 _ => .ripemd160
  | .hash160 _ => .hash160
  | .wrapA _ => .wrapA
  | .wrapS _ => .wrapS
  | .wrapC _ => .wrapC
  | .wrapD _ => .wrapD
  | .wrapV _ => .wrapV
  | .wrapJ _ => .wrapJ
  | .wrapN _ => .wrapN
  | .andV _ _ => .andV
  | .andB _ _ => .andB
  | .orB _ _ => .orB
  | .orD _ _ => .orD
  | .orC _ _ => .orC
  | .orI _ _ => .orI
  | .thresh _ _ => .thresh
  | .multi _ _ => .multi
  | .multiA _ _ => .multiA

/-- Direct subexpressions, in script order.  Leaves have none. -/
def Node.subs : Node → List Node
  | .pkK _ => []
  | .pkH _ _ => []
  | .older _ => []
  | .after _ => []
  | .sha256 _ => []
  | .hash256 _ => []
  | .ripemd160 _ => []
  | .hash160 _ => []
  | .wrapA x => [x]
  | .wrapS x => [x]
  | .wrapC x => [x]
  | .wrapD x => [x]
  | .wrapV x => [x]
  | .wrapJ x => [x]
  | .wrapN x => [x]
  | .andV x y => [x, y]
  | .andB x y => [x, y]
  | .orB x y => [x, y]
  | .orD x y => [x, y]
  | .orC x y => [x, y]
  | .orI x y => [x, y]
  | .thresh _ xs => xs
  | .multi _ _ => []
  | .multiA _ _ => []

/-- All keys occurring in a tree, in depth-first order.  Used by the
duplicate-key sanity check. -/
def keysInAux : Node → List Key
  | .pkK k => [k]
  | .pkH k _ => [k]
  | .older _ => []
  | .after _ => []
  | .sha256 _ => []
  | .hash256 _ => []
  | .ripemd160 _ => []
  | .hash160 _ => []
  | .wrapA x => keysInAux x
  | .wrapS x => keysInAux x
  | .wrapC x => keysInAux x
  | .wrapD x => keysInAux x
  | .wrapV x => keysInAux x
  | .wrapJ x => keysInAux x
  | .wrapN x => keysInAux x
  | .andV x y => keysInAux x ++ keysInAux y
  | .andB x y => keysInAux x ++ keysInAux y
  | .orB x y => keysInAux x ++ keysInAux y
  | .orD x y => keysInAux x ++ keysInAux y
  | .orC x y => keysInAux x ++ keysInAux y
  | .orI x y => keysInAux x ++ keysInAux y
  | .thresh _ xs => xs.flatMap keysInAux
  | .multi _ ks => ks
  | .multiA _ ks => ks
termination_by n => sizeOf n
decreasing_by
  all_goals simp_wf
  all_goals
    first
      | omega
      | (have h := List.sizeOf_lt_of_mem (by assumption); omega)

/-- All keys occurring in a tree, in depth-first order.  Used by the
duplicate-key sanity check. -/
def Node.keysIn (n : Node) : List Key := keysInAux n

/-- Union of a list of types (Core writes these as chains of `|`). -/
private def U (ts : List MSType) : MSType := ts.foldl (fun a b => a.union b) MSType.empty

/-- The "different timelock kinds in the two branches" test used by the
`k` rule of the binary fragments (`miniscript.cpp:160-166`). -/
private def mixedLocks (a b : MSType) : Bool :=
  (a.has .g && b.has .h) || (a.has .h && b.has .g) ||
  (a.has .i && b.has .j) || (a.has .j && b.has .i)

/-- MSType of `thresh(k, ts)`, transliterating the `THRESH` case of
`ComputeType` (`src/script/miniscript.cpp:229-258`). -/
private def threshType (k : Nat) (ts : List MSType) : MSType :=
  let n := ts.length
  if k = 0 || k > n then MSType.empty else
  let rec go (i : Nat) (acc : MSType) (allE allM : Bool) (numS args : Nat) :
      List MSType → Option (MSType × Bool × Bool × Nat × Nat)
    | [] => some (acc, allE, allM, numS, args)
    | t :: rest =>
      let req := if i = 0 then ty [.B, .d, .u] else ty [.W, .d, .u]
      if !t.Sub req then none else
      let acc' := U [
        (acc.union t).inter (ty [.g, .h, .i, .j]),
        MSType.if_ (((acc.inter t).Sub (ty [.k])) &&
          (k ≤ 1 || !mixedLocks acc t)) (ty [.k])]
      go (i + 1) acc' (allE && t.has .e) (allM && t.has .m)
        (if t.has .s then numS + 1 else numS)
        (args + (if t.has .z then 0 else if t.has .o then 1 else 2)) rest
  match go 0 (ty [.k]) true true 0 0 ts with
  | none => MSType.empty
  | some (acc, allE, allM, numS, args) =>
    U [
      ty [.B, .d, .u],
      MSType.if_ (args = 0) (ty [.z]),
      MSType.if_ (args = 1) (ty [.o]),
      MSType.if_ (allE && numS = n) (ty [.e]),
      MSType.if_ (allE && allM && numS ≥ n - k) (ty [.m]),
      MSType.if_ (numS ≥ n - k + 1) (ty [.s]),
      acc]

/-- Canonical type of a node, Core's `Node::CalcType` fed through
`SanitizeType` (`src/script/miniscript.h:780-794`,
`src/script/miniscript.cpp:43-259`). -/
def calcType (ctx : MiniscriptContext) : Node → MSType
  | .pkK _ => ty [.K, .o, .n, .u, .d, .e, .m, .s, .x, .k]
  | .pkH _ _ => ty [.K, .n, .u, .d, .e, .m, .s, .x, .k]
  | .older n =>
    if n = 0 || n ≥ 0x80000000 then MSType.empty else
    U [
      MSType.if_ ((n &&& 0x400000) ≠ 0) (ty [.g]),
      MSType.if_ ((n &&& 0x400000) = 0) (ty [.h]),
      ty [.B, .z, .f, .m, .x, .k]]
  | .after n =>
    if n = 0 || n ≥ 0x80000000 then MSType.empty else
    U [
      MSType.if_ (n ≥ 500000000) (ty [.i]),
      MSType.if_ (n < 500000000) (ty [.j]),
      ty [.B, .z, .f, .m, .x, .k]]
  | .sha256 h =>
    if h.size ≠ 32 then MSType.empty else ty [.B, .o, .n, .u, .d, .m, .k]
  | .hash256 h =>
    if h.size ≠ 32 then MSType.empty else ty [.B, .o, .n, .u, .d, .m, .k]
  | .ripemd160 h =>
    if h.size ≠ 20 then MSType.empty else ty [.B, .o, .n, .u, .d, .m, .k]
  | .hash160 h =>
    if h.size ≠ 20 then MSType.empty else ty [.B, .o, .n, .u, .d, .m, .k]
  | .wrapA x =>
    let xt := calcType ctx x
    U [
      MSType.if_ (xt.Sub (ty [.B])) (ty [.W]),
      xt.inter (ty [.g, .h, .i, .j, .k]),
      xt.inter (ty [.u, .d, .f, .e, .m, .s]),
      ty [.x]]
  | .wrapS x =>
    let xt := calcType ctx x
    U [
      MSType.if_ (xt.Sub (ty [.B, .o])) (ty [.W]),
      xt.inter (ty [.g, .h, .i, .j, .k]),
      xt.inter (ty [.u, .d, .f, .e, .m, .s, .x])]
  | .wrapC x =>
    let xt := calcType ctx x
    U [
      MSType.if_ (xt.Sub (ty [.K])) (ty [.B]),
      xt.inter (ty [.g, .h, .i, .j, .k]),
      xt.inter (ty [.o, .n, .d, .f, .e, .m]),
      ty [.u, .s]]
  | .wrapD x =>
    let xt := calcType ctx x
    U [
      MSType.if_ (xt.Sub (ty [.V, .z])) (ty [.B]),
      MSType.if_ (xt.Sub (ty [.z])) (ty [.o]),
      MSType.if_ (xt.Sub (ty [.f])) (ty [.e]),
      xt.inter (ty [.g, .h, .i, .j, .k]),
      xt.inter (ty [.m, .s]),
      MSType.if_ (ctx = .tapscript) (ty [.u]),
      ty [.n, .d, .x]]
  | .wrapV x =>
    let xt := calcType ctx x
    U [
      MSType.if_ (xt.Sub (ty [.B])) (ty [.V]),
      xt.inter (ty [.g, .h, .i, .j, .k]),
      xt.inter (ty [.z, .o, .n, .m, .s]),
      ty [.f, .x]]
  | .wrapJ x =>
    let xt := calcType ctx x
    U [
      MSType.if_ (xt.Sub (ty [.B, .n])) (ty [.B]),
      MSType.if_ (xt.Sub (ty [.f])) (ty [.e]),
      xt.inter (ty [.g, .h, .i, .j, .k]),
      xt.inter (ty [.o, .u, .m, .s]),
      ty [.n, .d, .x]]
  | .wrapN x =>
    let xt := calcType ctx x
    U [
      xt.inter (ty [.g, .h, .i, .j, .k]),
      xt.inter (ty [.B, .z, .o, .n, .d, .f, .e, .m, .s]),
      ty [.u, .x]]
  | .andV x y =>
    let xt := calcType ctx x
    let yt := calcType ctx y
    let both := xt.union yt
    U [
      MSType.if_ (xt.Sub (ty [.V])) (yt.inter (ty [.K, .V, .B])),
      xt.inter (ty [.n]),
      MSType.if_ (xt.Sub (ty [.z])) (yt.inter (ty [.n])),
      MSType.if_ (both.Sub (ty [.z])) (both.inter (ty [.o])),
      (xt.inter yt).inter (ty [.m, .z]),
      both.inter (ty [.s]),
      MSType.if_ (yt.Sub (ty [.f]) || xt.Sub (ty [.s])) (ty [.f]),
      yt.inter (ty [.u, .x]),
      both.inter (ty [.g, .h, .i, .j]),
      MSType.if_ (((xt.inter yt).Sub (ty [.k])) && !mixedLocks xt yt) (ty [.k])]
  | .andB x y =>
    let xt := calcType ctx x
    let yt := calcType ctx y
    let both := xt.union yt
    U [
      MSType.if_ (yt.Sub (ty [.W])) (xt.inter (ty [.B])),
      MSType.if_ (both.Sub (ty [.z])) (both.inter (ty [.o])),
      xt.inter (ty [.n]),
      MSType.if_ (xt.Sub (ty [.z])) (yt.inter (ty [.n])),
      MSType.if_ ((xt.inter yt).Sub (ty [.s])) ((xt.inter yt).inter (ty [.e])),
      (xt.inter yt).inter (ty [.d, .z, .m]),
      MSType.if_ ((xt.inter yt).Sub (ty [.f]) || xt.Sub (ty [.s, .f]) ||
        yt.Sub (ty [.s, .f])) (ty [.f]),
      both.inter (ty [.s]),
      ty [.u, .x],
      both.inter (ty [.g, .h, .i, .j]),
      MSType.if_ (((xt.inter yt).Sub (ty [.k])) && !mixedLocks xt yt) (ty [.k])]
  | .orB x y =>
    let xt := calcType ctx x
    let yt := calcType ctx y
    let both := xt.union yt
    U [
      MSType.if_ (xt.Sub (ty [.B, .d]) && yt.Sub (ty [.W, .d])) (ty [.B]),
      MSType.if_ (both.Sub (ty [.z])) (both.inter (ty [.o])),
      MSType.if_ (both.Sub (ty [.s]) && (xt.inter yt).Sub (ty [.e]))
        ((xt.inter yt).inter (ty [.m])),
      (xt.inter yt).inter (ty [.z, .s, .e]),
      ty [.d, .u, .x],
      both.inter (ty [.g, .h, .i, .j]),
      (xt.inter yt).inter (ty [.k])]
  | .orD x y =>
    let xt := calcType ctx x
    let yt := calcType ctx y
    let both := xt.union yt
    U [
      MSType.if_ (xt.Sub (ty [.B, .d, .u])) (yt.inter (ty [.B])),
      MSType.if_ (yt.Sub (ty [.z])) (xt.inter (ty [.o])),
      MSType.if_ (xt.Sub (ty [.e]) && both.Sub (ty [.s]))
        ((xt.inter yt).inter (ty [.m])),
      (xt.inter yt).inter (ty [.z, .s]),
      yt.inter (ty [.u, .f, .d, .e]),
      ty [.x],
      both.inter (ty [.g, .h, .i, .j]),
      (xt.inter yt).inter (ty [.k])]
  | .orC x y =>
    let xt := calcType ctx x
    let yt := calcType ctx y
    let both := xt.union yt
    U [
      MSType.if_ (xt.Sub (ty [.B, .d, .u])) (yt.inter (ty [.V])),
      MSType.if_ (yt.Sub (ty [.z])) (xt.inter (ty [.o])),
      MSType.if_ (xt.Sub (ty [.e]) && both.Sub (ty [.s]))
        ((xt.inter yt).inter (ty [.m])),
      (xt.inter yt).inter (ty [.z, .s]),
      ty [.f, .x],
      both.inter (ty [.g, .h, .i, .j]),
      (xt.inter yt).inter (ty [.k])]
  | .orI x y =>
    let xt := calcType ctx x
    let yt := calcType ctx y
    let both := xt.union yt
    U [
      (xt.inter yt).inter (ty [.V, .B, .K, .u, .f, .s]),
      MSType.if_ ((xt.inter yt).Sub (ty [.z])) (ty [.o]),
      MSType.if_ (both.Sub (ty [.f])) (both.inter (ty [.e])),
      MSType.if_ (both.Sub (ty [.s])) ((xt.inter yt).inter (ty [.m])),
      both.inter (ty [.d]),
      ty [.x],
      both.inter (ty [.g, .h, .i, .j]),
      (xt.inter yt).inter (ty [.k])]
  | .thresh k xs => threshType k (xs.map (calcType ctx))
  | .multi k ks =>
    if ctx = .tapscript || k = 0 || k > ks.length || ks.length > 20 then MSType.empty
    else ty [.B, .n, .u, .d, .e, .m, .s, .k]
  | .multiA k ks =>
    if ctx = .p2wsh || k = 0 || k > ks.length || ks.length > 999 then MSType.empty
    else ty [.B, .u, .d, .e, .m, .s, .k]

termination_by n => sizeOf n
decreasing_by
  all_goals simp_wf
  all_goals
    first
      | omega
      | (have h := List.sizeOf_lt_of_mem (by assumption); omega)

/-- The canonical type of a node, with Core's `SanitizeType` applied
(`miniscript.cpp:18-40`): a mask lacking `B`, `V`, `K` and `W` becomes
the empty type. -/
def Node.type (ctx : MiniscriptContext) (n : Node) : MSType :=
  (calcType ctx n).sanitize

end Bitcoin.Wallet.Miniscript
