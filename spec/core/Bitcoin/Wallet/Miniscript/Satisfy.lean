import Bitcoin.Wallet.Miniscript.Script

/-!
# Miniscript satisfaction and sanity

Two independent pieces live here.

## Satisfaction

`satisfy` implements the canonical branch choice of Core's
`Node::ProduceInput` (`src/script/miniscript.h:1247-1440`) for the
modelled fragments: it returns the witness stack (bottom first) or `none`
when the satisfier cannot produce one.  `dissatisfy` returns the canonical
dissatisfaction, which several fragments need in order to satisfy a
sibling branch.  The satisfier is abstract: signing, preimages and
timelock checks are supplied by the caller, corresponding to Core's `Ctx`
(`Sign`, `SatSHA256`, `SatHASH256`, `SatRIPEMD160`, `SatHASH160`,
`CheckOlder`, `CheckAfter`).

This is a **functional** model, not a malleability model.  Core tracks
`Availability`, `has_sig`, `malleable` and `non_canon` on every candidate
stack and uses them to choose the best satisfaction
(`InputStack::operator|`, `miniscript.cpp:335-365`); here `none` versus
`some` is the only distinction and the first viable branch is taken.  In
particular the model does not prove that the produced stack is
non-malleable, does not implement the `MAYBE` availability used for size
estimation, and omits `and_v`'s non-canonical dissatisfaction.

The stack representation matches Core's: a `List ByteArray` is the
witness stack bottom element first, so the last element is on top when the
script starts.  An empty `ByteArray` is Core's `ZERO` item.

## Sanity

`isSaneSubexpression` and `isSane` mirror
`Node::IsSaneSubexpression` / `Node::IsSane`
(`src/script/miniscript.h:1696-1702`): the type must not be empty, must
fit the context's script-size limit, must have `m` (non-malleable), `k`
(no timelock mix) and no duplicate key; the top level must additionally
have `B` and `s`.  `InsaneReason` names each failing condition and
`subexpressionReasons` reports all of them rather than only the first.

Not modelled in the sanity predicate: the operation-count limit
`MAX_OPS_PER_SCRIPT` and the execution stack-size limit
(`CheckOpsLimit`, `CheckStackSize`, `miniscript.h:1571-1610`), because the
operation-count and stack-size summaries (`Ops`, `StackSize`, `SatInfo`)
are not part of this fragment.  Consequently a node can be reported sane
here while Core's `CheckOpsLimit` or `CheckStackSize` rejects it.
-/

namespace Bitcoin.Wallet.Miniscript

/-- A witness stack, bottom element first. -/
abbrev WitnessStack := List ByteArray

/-- The providers a Miniscript satisfier needs.  Each returns `none` when
the required signature/preimage is unavailable.  `checkOlder` and
`checkAfter` answer whether the spending transaction satisfies a relative
or absolute timelock, as Core's `Ctx::CheckOlder`/`CheckAfter`. -/
structure Satisfier where
  /-- Signature for a key, or `none` if the key cannot sign. -/
  sign : Key → Option ByteArray
  /-- Preimage for a SHA256 digest, or `none`. -/
  satSHA256 : ByteArray → Option ByteArray
  /-- Preimage for a HASH256 digest, or `none`. -/
  satHash256 : ByteArray → Option ByteArray
  /-- Preimage for a RIPEMD160 digest, or `none`. -/
  satRIPEMD160 : ByteArray → Option ByteArray
  /-- Preimage for a HASH160 digest, or `none`. -/
  satHASH160 : ByteArray → Option ByteArray
  /-- Is the relative timelock `n` satisfied by the spending input? -/
  checkOlder : Nat → Bool
  /-- Is the absolute timelock `n` satisfied by the spending transaction? -/
  checkAfter : Nat → Bool

/-- Canonical satisfaction (`.2`) and dissatisfaction (`.1`); `none` means
unavailable.  Mirrors Core's `InputResult`. -/
abbrev InputResult := Option WitnessStack × Option WitnessStack

/-- The `ZERO` stack element (an empty byte vector, numeric zero). -/
private def zeroElem : ByteArray := .empty

/-- The `ONE` stack element (`0x01`, numeric one). -/
private def oneElem : ByteArray := bytes [1]

/-- Core's `ZERO32`: 32 zero bytes, the malleable dissatisfaction of a
hash fragment. -/
private def zero32 : ByteArray := bytes (List.replicate 32 0)

/-- Concatenate two optional stacks; `none` if either is unavailable. -/
private def app (a b : Option WitnessStack) : Option WitnessStack :=
  match a, b with
  | some x, some y => some (x ++ y)
  | _, _ => none

/-- Choose exactly `k` satisfactions among the threshold branches,
preferring satisfaction of earlier branches and falling back to their
dissatisfactions.  Returns one stack per branch in script order. -/
private def selectThresh (k : Nat) : List InputResult → Option (List WitnessStack)
  | [] => if k = 0 then some [] else none
  | (ns, sat) :: rest =>
    let withSat :=
      if k = 0 then none
      else
        match sat with
        | none => none
        | some st => (selectThresh (k - 1) rest).map (fun tail => st :: tail)
    match withSat with
    | some r => some r
    | none =>
      match ns with
      | none => none
      | some st => (selectThresh k rest).map (fun tail => st :: tail)

/-- Mark which keys of a `multi`/`multi_a` will be signed: pick up to
`budget` keys for which the satisfier has a signature, scanning left to
right and backtracking if too few are found. -/
private def pickKeys (budget : Nat) (sf : Satisfier) : List Key → Option (List (Key × Bool))
  | [] => if budget = 0 then some [] else none
  | k :: rest =>
    let withKey :=
      if budget > 0 && (sf.sign k).isSome then
        (pickKeys (budget - 1) sf rest).map (fun tail => (k, true) :: tail)
      else none
    match withKey with
    | some r => some r
    | none => (pickKeys budget sf rest).map (fun tail => (k, false) :: tail)

/-- Produce the canonical satisfaction and dissatisfaction of a node.
The first component is the dissatisfaction, the second the satisfaction,
matching Core's `InputResult{nsat, sat}`. -/
def produce (sf : Satisfier) : Node → InputResult
  | .pkK key => (some [zeroElem], (sf.sign key).map (fun sig => [sig]))
  | .pkH key _ => (some [zeroElem, key], (sf.sign key).map (fun sig => [sig, key]))
  | .older n => (none, if sf.checkOlder n then some [] else none)
  | .after n => (none, if sf.checkAfter n then some [] else none)
  | .sha256 h => (some [zero32], (sf.satSHA256 h).map (fun p => [p]))
  | .hash256 h => (some [zero32], (sf.satHash256 h).map (fun p => [p]))
  | .ripemd160 h => (some [zero32], (sf.satRIPEMD160 h).map (fun p => [p]))
  | .hash160 h => (some [zero32], (sf.satHASH160 h).map (fun p => [p]))
  | .wrapA x => produce sf x
  | .wrapS x => produce sf x
  | .wrapC x => produce sf x
  | .wrapD x =>
    let r := produce sf x
    (some [zeroElem], r.2.map (fun st => st ++ [oneElem]))
  | .wrapV x => (none, (produce sf x).2)
  | .wrapJ x =>
    let r := produce sf x
    (some [zeroElem], r.2)
  | .wrapN x => produce sf x
  | .andV x y =>
    let rx := produce sf x
    let ry := produce sf y
    (none, app ry.2 rx.2)
  | .andB x y =>
    let rx := produce sf x
    let ry := produce sf y
    (app ry.1 rx.1, app ry.2 rx.2)
  | .orB x y =>
    let rx := produce sf x
    let ry := produce sf y
    let nsat := app ry.1 rx.1
    let sat :=
      match app ry.1 rx.2 with
      | some st => some st
      | none => app rx.1 ry.2
    (nsat, sat)
  | .orD x y =>
    let rx := produce sf x
    let ry := produce sf y
    let nsat := app ry.1 rx.1
    let sat :=
      match rx.2 with
      | some st => some st
      | none => app rx.1 ry.2
    (nsat, sat)
  | .orC x y =>
    let rx := produce sf x
    let ry := produce sf y
    let sat :=
      match rx.2 with
      | some st => some st
      | none => app rx.1 ry.2
    (none, sat)
  | .orI x y =>
    let rx := produce sf x
    let ry := produce sf y
    let nsat :=
      match rx.1 with
      | some st => some (st ++ [oneElem])
      | none => (ry.1).map (fun st => st ++ [zeroElem])
    let sat :=
      match rx.2 with
      | some st => some (st ++ [oneElem])
      | none => (ry.2).map (fun st => st ++ [zeroElem])
    (nsat, sat)
  | .thresh k xs =>
    let pairs := xs.map (produce sf)
    let nsat :=
      (selectThresh 0 pairs).map (fun stacks => (stacks.reverse).flatten)
    let sat :=
      (selectThresh k pairs).map (fun stacks => (stacks.reverse).flatten)
    (nsat, sat)
  | .multi k keys =>
    let nsat := some (List.replicate (k + 1) zeroElem)
    let sat :=
      (pickKeys k sf keys).map (fun marked =>
        (zeroElem :: (marked.filterMap (fun (key, chosen) =>
          if chosen then sf.sign key else none))))
    (nsat, sat)
  | .multiA k keys =>
    let nsat := some (List.replicate keys.length zeroElem)
    let sat :=
      (pickKeys k sf keys).map (fun marked =>
        ((marked.reverse).map (fun (key, chosen) =>
          match chosen with
          | true => match sf.sign key with | some sig => sig | none => zeroElem
          | false => zeroElem)))
    (nsat, sat)
termination_by n => sizeOf n
decreasing_by
  all_goals simp_wf
  all_goals
    first
      | omega
      | (have h := List.sizeOf_lt_of_mem (by assumption); omega)

/-- The canonical witness stack satisfying a node, or `none` if the
satisfier cannot satisfy it. -/
def satisfy (sf : Satisfier) (n : Node) : Option WitnessStack :=
  (produce sf n).2

/-- The canonical witness stack dissatisfying a node, or `none`. -/
def dissatisfy (sf : Satisfier) (n : Node) : Option WitnessStack :=
  (produce sf n).1

/-- Why a node is not sane.  Each constructor corresponds to one failing
condition of `IsSane`/`IsSaneSubexpression`
(`src/script/miniscript.h:1696-1702`). -/
inductive InsaneReason where
  /-- The computed type is empty (`IsValid`). -/
  | invalidType
  /-- The script exceeds the context's maximum script size (`IsValid`). -/
  | scriptTooLarge
  /-- The top-level expression is not of type `B` (`IsValidTopLevel`). -/
  | notTopLevel
  /-- The expression lacks `m`: a non-malleable satisfaction is not guaranteed. -/
  | notNonMalleable
  /-- The expression lacks `k`: a satisfaction may mix timelock kinds. -/
  | timelockMix
  /-- A key occurs more than once in the tree (`CheckDuplicateKey`). -/
  | duplicateKey
  /-- No satisfaction requires a signature (`NeedsSignature`). -/
  | missingSignature
deriving Repr, DecidableEq, BEq

/-- Does a tree contain the same key twice?  Core's `CheckDuplicateKey`
treats `pk_k` and `pk_h` occurrences of one key as duplicates as well. -/
def hasDuplicateKey (n : Node) : Bool :=
  let rec go (seen : List Key) : List Key → Bool
    | [] => false
    | k :: ks => if seen.contains k then true else go (k :: seen) ks
  go [] n.keysIn

/-- `IsValid`: nonempty type and a script within the context limit
(`src/script/miniscript.h:1675-1679`). -/
def isValid (ctx : MiniscriptContext) (n : Node) : Bool :=
  let t := calcType ctx n
  t ≠ MSType.empty && (toScript ctx n).size ≤ maxScriptSize ctx

/-- All subexpression-level sanity failures of a node, in the order:
empty type, oversized script, missing `m`, missing `k`, duplicate key.
This reports every detected reason, unlike Core's `FindInsaneSub`, which
returns the first offending subtree. -/
def subexpressionReasons (ctx : MiniscriptContext) (n : Node) : List InsaneReason :=
  let t := calcType ctx n
  (if t = MSType.empty then [.invalidType] else []) ++
  (if (toScript ctx n).size > maxScriptSize ctx then [.scriptTooLarge] else []) ++
  (if t.has .m then [] else [.notNonMalleable]) ++
  (if t.has .k then [] else [.timelockMix]) ++
  (if hasDuplicateKey n then [.duplicateKey] else [])

/-- `IsSaneSubexpression`: valid, non-malleable, timelock-consistent and
free of duplicate keys.  Operation and stack-size limits are not included
(see the module note). -/
def isSaneSubexpression (ctx : MiniscriptContext) (n : Node) : Bool :=
  (subexpressionReasons ctx n).isEmpty

/-- Top-level sanity failures: not a `B` expression, or no satisfaction
requires a signature. -/
def topLevelReasons (ctx : MiniscriptContext) (n : Node) : List InsaneReason :=
  let t := calcType ctx n
  (if t.Sub (ty [.B]) then [] else [.notTopLevel]) ++
  (if t.has .s then [] else [.missingSignature])

/-- `IsSane`: `IsValidTopLevel` and `IsSaneSubexpression` and
`NeedsSignature` (`src/script/miniscript.h:1702`). -/
def isSane (ctx : MiniscriptContext) (n : Node) : Bool :=
  (subexpressionReasons ctx n ++ topLevelReasons ctx n).isEmpty

end Bitcoin.Wallet.Miniscript
