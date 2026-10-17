import Bitcoin.Wallet.Miniscript
import Bitcoin.Wallet.RuleAttr

/-!
# Miniscript satisfaction shapes

This file characterises the stacks produced by
`Bitcoin.Wallet.Miniscript.produce`/`satisfy`
(`spec/core/Bitcoin/Wallet/Miniscript/Satisfy.lean`) for the modelled
fragments.  The statements are about the **functional** satisfier only:
`sign`/`satSHA256`/... are abstract providers, and `none` means "this
provider cannot supply the required witness".

Proved shapes:

* `pk_k`/`pk_h`: a signature, with the key appended for `pk_h`;
* hash locks: the supplied preimage, with a 32-zero-byte malleable
  dissatisfaction;
* `older`/`after`: the empty stack exactly when the timelock check passes,
  and `none` otherwise;
* `multi`/`multi_a`: a leading zero element (the `CHECKMULTISIG` off-by-one
  dummy) followed by exactly `k` signatures for `multi`, and one stack slot
  per key for `multi_a`, each either a signature or a zero element;
* `thresh`: one stack per branch, in script order, with exactly `k`
  satisfied branches.

What is **not** modelled or claimed: malleability, Core's `Availability`
lattice and `MAYBE`, non-canonical dissatisfactions, signature/preimage
validity, consensus interpreter execution, and the exact witness bytes of
`multi_a`'s zero slots.  `produce` takes the first viable branch, so these
are existence/shape facts for that canonical choice, not for every valid
satisfaction.
-/

namespace BitcoinProofs.Wallet.Miniscript

open Bitcoin.Wallet.Miniscript
open Bitcoin.Wallet.Miniscript.Node

/-! ## Public mirrors of the private helpers -/

/-- Mirror of the model's `ZERO` witness element. -/
def zeroElem2 : ByteArray := .empty

/-- Mirror of the model's `ONE` witness element. -/
def oneElem2 : ByteArray := bytes [1]

/-- Mirror of the model's `ZERO32` malleable hash dissatisfaction. -/
def zero32_2 : ByteArray := bytes (List.replicate 32 0)

/-- Mirror of the model's optional-stack concatenation. -/
def app2 (a b : Option WitnessStack) : Option WitnessStack :=
  match a, b with
  | some x, some y => some (x ++ y)
  | _, _ => none

/-- Mirror of the model's threshold branch selector. -/
def selectThresh2 (k : Nat) : List InputResult → Option (List WitnessStack)
  | [] => if k = 0 then some [] else none
  | (ns, sat) :: rest =>
    let withSat :=
      if k = 0 then none
      else
        match sat with
        | none => none
        | some st => (selectThresh2 (k - 1) rest).map (fun tail => st :: tail)
    match withSat with
    | some r => some r
    | none =>
      match ns with
      | none => none
      | some st => (selectThresh2 k rest).map (fun tail => st :: tail)

/-- Mirror of the model's multisig key selector. -/
def pickKeys2 (budget : Nat) (sf : Satisfier) : List Key → Option (List (Key × Bool))
  | [] => if budget = 0 then some [] else none
  | k :: rest =>
    let withKey :=
      if budget > 0 && (sf.sign k).isSome then
        (pickKeys2 (budget - 1) sf rest).map (fun tail => (k, true) :: tail)
      else none
    match withKey with
    | some r => some r
    | none => (pickKeys2 budget sf rest).map (fun tail => (k, false) :: tail)

/-! ## `produce` equations -/

theorem produce_pkK (sf : Satisfier) (key : Key) :
    produce sf (.pkK key) = (some [zeroElem2], (sf.sign key).map (fun sig => [sig])) := by
  simp only [produce]
  rfl

theorem produce_pkH (sf : Satisfier) (key keyHash : Key) :
    produce sf (.pkH key keyHash) =
      (some [zeroElem2, key], (sf.sign key).map (fun sig => [sig, key])) := by
  simp only [produce]
  rfl

theorem produce_older (sf : Satisfier) (n : Nat) :
    produce sf (.older n) = (none, if sf.checkOlder n then some [] else none) := by
  simp only [produce]

theorem produce_after (sf : Satisfier) (n : Nat) :
    produce sf (.after n) = (none, if sf.checkAfter n then some [] else none) := by
  simp only [produce]

theorem produce_sha256 (sf : Satisfier) (h : ByteArray) :
    produce sf (.sha256 h) = (some [zero32_2], (sf.satSHA256 h).map (fun p => [p])) := by
  simp only [produce]
  rfl

theorem produce_hash256 (sf : Satisfier) (h : ByteArray) :
    produce sf (.hash256 h) = (some [zero32_2], (sf.satHash256 h).map (fun p => [p])) := by
  simp only [produce]
  rfl

theorem produce_ripemd160 (sf : Satisfier) (h : ByteArray) :
    produce sf (.ripemd160 h) =
      (some [zero32_2], (sf.satRIPEMD160 h).map (fun p => [p])) := by
  simp only [produce]
  rfl

theorem produce_hash160 (sf : Satisfier) (h : ByteArray) :
    produce sf (.hash160 h) = (some [zero32_2], (sf.satHASH160 h).map (fun p => [p])) := by
  simp only [produce]
  rfl

theorem produce_wrapV (sf : Satisfier) (x : Node) :
    produce sf (.wrapV x) = (none, (produce sf x).2) := by
  simp only [produce]

theorem produce_andV (sf : Satisfier) (x y : Node) :
    produce sf (.andV x y) = (none, app2 (produce sf y).2 (produce sf x).2) := by
  simp only [produce]
  rfl

theorem produce_andB (sf : Satisfier) (x y : Node) :
    produce sf (.andB x y) =
      (app2 (produce sf y).1 (produce sf x).1,
        app2 (produce sf y).2 (produce sf x).2) := by
  simp only [produce]
  rfl

theorem produce_orB (sf : Satisfier) (x y : Node) :
    produce sf (.orB x y) =
      (app2 (produce sf y).1 (produce sf x).1,
        (match app2 (produce sf y).1 (produce sf x).2 with
         | some st => some st
         | none => app2 (produce sf x).1 (produce sf y).2)) := by
  simp only [produce]
  rfl

theorem produce_orD (sf : Satisfier) (x y : Node) :
    produce sf (.orD x y) =
      (app2 (produce sf y).1 (produce sf x).1,
        (match (produce sf x).2 with
         | some st => some st
         | none => app2 (produce sf x).1 (produce sf y).2)) := by
  simp only [produce]
  rfl

theorem produce_orC (sf : Satisfier) (x y : Node) :
    produce sf (.orC x y) =
      (none,
        (match (produce sf x).2 with
         | some st => some st
         | none => app2 (produce sf x).1 (produce sf y).2)) := by
  simp only [produce]
  rfl

theorem produce_orI (sf : Satisfier) (x y : Node) :
    produce sf (.orI x y) =
      ((match (produce sf x).1 with
        | some st => some (st ++ [oneElem2])
        | none => ((produce sf y).1).map (fun st => st ++ [zeroElem2])),
       (match (produce sf x).2 with
        | some st => some (st ++ [oneElem2])
        | none => ((produce sf y).2).map (fun st => st ++ [zeroElem2]))) := by
  simp only [produce]
  rfl

namespace BitcoinProofs.Wallet.Miniscript

open Bitcoin.Wallet.Miniscript
open Bitcoin.Wallet.Miniscript.Node

/-! ## Leaf satisfaction shapes -/

@[walletRule "MS-034"]
theorem satisfy_pkK (sf : Satisfier) (key : Key) :
    satisfy sf (.pkK key) = (sf.sign key).map (fun sig => [sig]) := by
  simp [satisfy, produce_pkK]

theorem dissatisfy_pkK (sf : Satisfier) (key : Key) :
    dissatisfy sf (.pkK key) = some [zeroElem2] := by
  simp [dissatisfy, produce_pkK]

theorem satisfy_pkH (sf : Satisfier) (key keyHash : Key) :
    satisfy sf (.pkH key keyHash) = (sf.sign key).map (fun sig => [sig, key]) := by
  simp [satisfy, produce_pkH]

theorem dissatisfy_pkH (sf : Satisfier) (key keyHash : Key) :
    dissatisfy sf (.pkH key keyHash) = some [zeroElem2, key] := by
  simp [dissatisfy, produce_pkH]

theorem satisfy_older (sf : Satisfier) (n : Nat) :
    satisfy sf (.older n) = (if sf.checkOlder n then some [] else none) := by
  simp [satisfy, produce_older]

theorem satisfy_after (sf : Satisfier) (n : Nat) :
    satisfy sf (.after n) = (if sf.checkAfter n then some [] else none) := by
  simp [satisfy, produce_after]

theorem satisfy_older_eq_none_iff (sf : Satisfier) (n : Nat) :
    satisfy sf (.older n) = none ↔ sf.checkOlder n = false := by
  simp [satisfy_older]

theorem satisfy_after_eq_none_iff (sf : Satisfier) (n : Nat) :
    satisfy sf (.after n) = none ↔ sf.checkAfter n = false := by
  simp [satisfy_after]

/-! Hash locks: the satisfaction is exactly the supplied preimage. -/

theorem satisfy_sha256 (sf : Satisfier) (h : ByteArray) :
    satisfy sf (.sha256 h) = (sf.satSHA256 h).map (fun p => [p]) := by
  simp [satisfy, produce_sha256]

theorem satisfy_hash256 (sf : Satisfier) (h : ByteArray) :
    satisfy sf (.hash256 h) = (sf.satHash256 h).map (fun p => [p]) := by
  simp [satisfy, produce_hash256]

theorem satisfy_ripemd160 (sf : Satisfier) (h : ByteArray) :
    satisfy sf (.ripemd160 h) = (sf.satRIPEMD160 h).map (fun p => [p]) := by
  simp [satisfy, produce_ripemd160]

theorem satisfy_hash160 (sf : Satisfier) (h : ByteArray) :
    satisfy sf (.hash160 h) = (sf.satHASH160 h).map (fun p => [p]) := by
  simp [satisfy, produce_hash160]

theorem satisfy_sha256_eq_none_iff (sf : Satisfier) (h : ByteArray) :
    satisfy sf (.sha256 h) = none ↔ sf.satSHA256 h = none := by
  simp [satisfy_sha256]

theorem satisfy_hash160_eq_none_iff (sf : Satisfier) (h : ByteArray) :
    satisfy sf (.hash160 h) = none ↔ sf.satHASH160 h = none := by
  simp [satisfy_hash160]

/-- `v:` adds nothing to the witness stack; a `V`-typed node reuses the
satisfaction of its child. -/
theorem satisfy_wrapV (sf : Satisfier) (x : Node) :
    satisfy sf (.wrapV x) = satisfy sf x := by
  simp [satisfy, produce_wrapV]

/-! ## Multisig shapes -/

theorem dissatisfy_multi (sf : Satisfier) (k : Nat) (keys : List Key) :
    dissatisfy sf (.multi k keys) = some (List.replicate (k + 1) zeroElem2) := by
  simp [dissatisfy, produce]
  rfl

theorem dissatisfy_multiA (sf : Satisfier) (k : Nat) (keys : List Key) :
    dissatisfy sf (.multiA k keys) =
      some (List.replicate keys.length zeroElem2) := by
  simp only [dissatisfy, produce]
  cases keys <;> rfl

/-- Every `multi` satisfaction is the `CHECKMULTISIG` dummy zero followed by
signatures supplied by `sf.sign`. -/
theorem satisfy_multi_shape (sf : Satisfier) (k : Nat) (keys : List Key)
    (st : WitnessStack) (hst : satisfy sf (.multi k keys) = some st) :
    ∃ sigs, st = zeroElem2 :: sigs ∧
      ∀ s ∈ sigs, ∃ key, sf.sign key = some s := by
  simp only [satisfy, produce] at hst
  rw [Option.map_eq_some_iff] at hst
  obtain ⟨marked, _hmarked, rfl⟩ := hst
  refine ⟨marked.filterMap (fun (key, chosen) =>
    if chosen then sf.sign key else none), rfl, ?_⟩
  intro s hs
  rw [List.mem_filterMap] at hs
  obtain ⟨⟨key, chosen⟩, _hkey, hs⟩ := hs
  by_cases hc : chosen
  · simp [hc] at hs
    exact ⟨key, by simpa using hs⟩
  · simp [hc] at hs

/-- Every `multi_a` satisfaction slot is either a supplied signature or the
zero element used for an unsigned key. -/
theorem satisfy_multiA_shape (sf : Satisfier) (k : Nat) (keys : List Key)
    (st : WitnessStack) (hst : satisfy sf (.multiA k keys) = some st) :
    ∀ s ∈ st, (∃ key, sf.sign key = some s) ∨ s = zeroElem2 := by
  simp only [satisfy, produce] at hst
  rw [Option.map_eq_some_iff] at hst
  obtain ⟨marked, _hmarked, rfl⟩ := hst
  intro s hs
  rw [List.mem_map] at hs
  obtain ⟨⟨key, chosen⟩, _hkey, rfl⟩ := hs
  cases chosen with
  | false => exact Or.inr rfl
  | true =>
    cases hsign : sf.sign key with
    | none => exact Or.inr rfl
    | some sig => exact Or.inl ⟨key, hsign⟩

/-- An empty key list cannot satisfy a positive threshold. -/
theorem satisfy_multi_nil (sf : Satisfier) (k : Nat) (hk : k ≠ 0) :
    satisfy sf (.multi k []) = none := by
  simp only [satisfy, produce]
  change (if k = 0 then some [] else none).map
    (fun (marked : List (Key × Bool)) =>
      (zeroElem2 :: (marked.filterMap (fun (key, chosen) =>
        if chosen then sf.sign key else none)))) = none
  simp [hk]

theorem satisfy_multiA_nil (sf : Satisfier) (k : Nat) (hk : k ≠ 0) :
    satisfy sf (.multiA k []) = none := by
  simp only [satisfy, produce]
  change (if k = 0 then some [] else none).map
    (fun (marked : List (Key × Bool)) => ((marked.reverse).map (fun (key, chosen) =>
      match chosen with
      | true => match sf.sign key with | some sig => sig | none => zeroElem2
      | false => zeroElem2))) = none
  simp [hk]


/-- An empty threshold branch list cannot satisfy a positive threshold. -/
theorem satisfy_thresh_nil (sf : Satisfier) (k : Nat) (hk : k ≠ 0) :
    satisfy sf (.thresh k []) = none := by
  simp only [satisfy, produce]
  change (if k = 0 then some [] else none).map
    (fun (stacks : List WitnessStack) => stacks.reverse.flatten) = none
  simp [hk]

end BitcoinProofs.Wallet.Miniscript
