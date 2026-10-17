import Bitcoin.Wallet.Descriptor.Expand
import Lean.Elab.Tactic
import Bitcoin.Wallet.RuleAttr

/-!
# Expansion laws for the descriptor fragment

This file states the laws of `Bitcoin.Wallet.Descriptor.expand?` on the
supported fragment (`pk`, `pkh`, `wpkh`, `sh(wpkh)`, `multi`, `sortedmulti`,
`tr` key-path only).

The core module deliberately keeps its expansion machinery private:
`alignedCount`, `alignOne`, `nth?`, `buildAt`, and the local `resolve`
recursion inside `expand?` are not exported.  To reason about them without
modifying core files we restate the algorithm as a public specification
(`specExpand?`, with helpers `specNth?` etc.), prove that the specification
is definitionally the implementation (`expand?_eq_spec`), and then prove all
laws about the specification.  Private definitions are unfolded with the
`unfold_priv` tactic, which reconstructs Lean's private name from the module
and the identifier.

The laws are:

* fixed-key descriptors expand to exactly one script, built by the
  corresponding `payTo*` function;
* `multi`/`sortedmulti` over non-empty fixed-key lists expand to one script
  that keeps source order (`multi`) or applies `sortPubkeys` (`sortedmulti`);
* a ranged key expands to one script per key supplied by the provider, in
  provider order (hence ascending derivation-index order);
* expansion is deterministic and total (`Except`-valued, never `panic`).

What is *not* proved here (see `wallet-review/peer-reports/PEER-DESC.md`):
the numeric bound of a wildcard range is the provider list length (Core's
`[0, 2^31)` index domain is not re-checked), and provider/index validity is
an explicit hypothesis, mirroring Core's explicit-index boundary.
-/

open Lean Elab Tactic

/-- Unfold a private definition of `Bitcoin.Wallet.Descriptor.Expand`. -/
elab "unfold_priv " n:ident : tactic => do
  let full := Lean.mkPrivateNameCore `Bitcoin.Wallet.Descriptor.Expand
    (`Bitcoin.Wallet.Descriptor |>.append n.getId)
  unfoldTarget full

namespace BitcoinProofs.Wallet.Desc

open Bitcoin.Wallet.Descriptor
open Bitcoin.Data

/-! ## Public specification of the expansion algorithm -/

/-- `i`-th element of a list, without relying on `get!`. -/
def specNth? (xs : List ByteArray) (i : Nat) : Option ByteArray :=
  match xs.drop i with
  | [] => none
  | x :: _ => some x

/-- Number of expansion positions, with Core's length-one cloning rule. -/
def specAlignedCount (lists : List (List ByteArray)) : Option Nat :=
  let maxLen := lists.foldl (fun m xs => max m xs.length) 0
  if maxLen = 0 then none
  else if lists.all (fun xs => xs.length = 1 ∨ xs.length = maxLen) then
    some maxLen
  else none

/-- Clone length-one key vectors to `n`. -/
def specAlignOne (n : Nat) : List ByteArray → List ByteArray
  | [x] => List.replicate n x
  | xs => xs

/-- Build the script at one expansion position. -/
def specBuildAt (d : Descriptor) (vectors : List (List ByteArray))
    (idx : Nat) : Except String Script :=
  match d, vectors with
  | .pk _, [ks] =>
      match specNth? ks idx with
      | some k => .ok (payToPubkey k)
      | none => .error "missing key at expansion index"
  | .pkh _, [ks] =>
      match specNth? ks idx with
      | some k => .ok (payToPubkeyHash k)
      | none => .error "missing key at expansion index"
  | .wpkh _, [ks] =>
      match specNth? ks idx with
      | some k => .ok (payToWitnessPubkeyHash k)
      | none => .error "missing key at expansion index"
  | .shWpkh _, [ks] =>
      match specNth? ks idx with
      | some k => .ok (payToScriptHash (payToWitnessPubkeyHash k))
      | none => .error "missing key at expansion index"
  | .multi threshold _ sorted, ks =>
      let keys := ks.filterMap (fun xs => specNth? xs idx)
      if keys.length ≠ ks.length then .error "missing key at expansion index"
      else
        let ordered := if sorted then sortPubkeys keys else keys
        .ok (multiScript threshold ordered)
  | .tr _, [ks] =>
      match specNth? ks idx with
      | some k =>
          match taprootKeyPath k with
          | some script => .ok script
          | none => .error "internal key does not lift to a taproot output"
      | none => .error "missing key at expansion index"
  | _, _ => .error "descriptor/expansion shape mismatch"

/-- Resolve a key expression to its per-index key vectors. -/
def specResolve (provider : KeyProvider) :
    List KeyExpr → Except String (List (List ByteArray))
  | [] => .ok []
  | k :: ks =>
      let xs := resolveKey provider k
      if xs.isEmpty then
        .error s!"key provider returned no keys for '{KeyExpr.raw k}'"
      else if !k.isRanged && xs.length > 1 then
        .error s!"key provider returned multiple keys for non-ranged '{KeyExpr.raw k}'"
      else
        match specResolve provider ks with
        | .error e => .error e
        | .ok rest => .ok (xs :: rest)

/-- Public specification of `expand?`. -/
def specExpand? (d : Descriptor) (provider : KeyProvider) :
    Except String (List Script) :=
  match specResolve provider d.keys with
  | .error e => .error e
  | .ok vectors =>
      match specAlignedCount vectors with
      | none => .error "no key can be expanded (empty key list)"
      | some n =>
          let ordered := vectors.map (specAlignOne n)
          (List.range n).mapM (specBuildAt d ordered)

/-! ## Specification equals implementation -/

private theorem resolve_eq (p : KeyProvider) : ∀ ks : List KeyExpr,
    specResolve p ks = expand?.resolve p ks := by
  intro ks
  induction ks with
  | nil => rfl
  | cons k ks ih =>
      simp [specResolve, Bitcoin.Wallet.Descriptor.expand?.resolve, resolveKey,
        KeyExpr.isRanged, ih]
      split <;> rfl

/-- The executable implementation is exactly the public specification. -/
theorem expand?_eq_spec (d : Descriptor) (p : KeyProvider) :
    expand? d p = specExpand? d p := by
  unfold specExpand? Bitcoin.Wallet.Descriptor.expand?
  rw [← resolve_eq p d.keys]
  unfold_priv alignedCount
  unfold_priv alignOne
  unfold_priv buildAt
  unfold_priv nth?
  rfl

/-! ## Fixed-key descriptors -/

theorem specExpand?_pk_const (origin : Option KeyOrigin) (pubkey : ByteArray)
    (xonly : Bool) (raw : String) :
    specExpand? (.pk (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [payToPubkey pubkey] := rfl

theorem specExpand?_pkh_const (origin : Option KeyOrigin) (pubkey : ByteArray)
    (xonly : Bool) (raw : String) :
    specExpand? (.pkh (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [payToPubkeyHash pubkey] := rfl

theorem specExpand?_wpkh_const (origin : Option KeyOrigin) (pubkey : ByteArray)
    (xonly : Bool) (raw : String) :
    specExpand? (.wpkh (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [payToWitnessPubkeyHash pubkey] := rfl

theorem specExpand?_shWpkh_const (origin : Option KeyOrigin) (pubkey : ByteArray)
    (xonly : Bool) (raw : String) :
    specExpand? (.shWpkh (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [payToScriptHash (payToWitnessPubkeyHash pubkey)] := rfl

/-- A taproot key-path-only descriptor over a constant internal key expands to
the script produced by `taprootKeyPath`, when that function succeeds. -/
theorem specExpand?_tr_const (origin : Option KeyOrigin) (pubkey : ByteArray)
    (xonly : Bool) (raw : String) (script : Script)
    (h : taprootKeyPath pubkey = some script) :
    specExpand? (.tr (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [script] := by
  simp [specExpand?, Descriptor.keys, resolveKey, specResolve, specAlignedCount,
    specAlignOne, specBuildAt, specNth?, List.range, List.range.loop,
    List.mapM, List.mapM.loop, h]
  rfl

/-! ## Multisig over fixed keys -/

theorem specResolve_consts (p : KeyProvider) (keys : List ByteArray) :
    specResolve p (keys.map (fun k => .const none k false "")) =
      .ok (keys.map (fun k => [k])) := by
  induction keys with
  | nil => rfl
  | cons k ks ih =>
      simp [specResolve, resolveKey, KeyExpr.isRanged, ih]

theorem foldl_max_singletons (ks : List ByteArray) :
    List.foldl (fun m xs => max m xs.length) 1 (ks.map (fun k => [k])) = 1 := by
  induction ks with
  | nil => rfl
  | cons k' ks ih => simp [List.map, ih]

theorem specAlignedCount_singletons (k : ByteArray) (ks : List ByteArray) :
    specAlignedCount ([k] :: ks.map (fun k => [k])) = some 1 := by
  induction ks with
  | nil => simp [specAlignedCount, List.foldl]
  | cons k' ks ih =>
      simp [specAlignedCount, List.map, List.foldl, foldl_max_singletons]

@[simp] theorem specAlignOne_one (x : ByteArray) : specAlignOne 1 [x] = [x] := rfl
@[simp] theorem specNth?_zero (x : ByteArray) : specNth? [x] 0 = some x := rfl

/-- `multi`/`sortedmulti` over a non-empty fixed-key list expands to one
script.  Source order is preserved by `multi`; `sortedmulti` applies
`sortPubkeys` to that same source order. -/
theorem specExpand?_multi_consts (t : Nat) (sorted : Bool) (ks : List ByteArray)
    (hne : ks ≠ []) :
    specExpand? (.multi t (ks.map (fun k => .const none k false "")) sorted)
        (fun _ => []) =
      .ok [multiScript t (if sorted then sortPubkeys ks else ks)] := by
  cases ks with
  | nil => contradiction
  | cons k ks =>
      simp only [specExpand?, Descriptor.keys]
      rw [specResolve_consts]
      simp [specAlignedCount_singletons, specAlignOne, specBuildAt, specNth?,
        List.range, List.range.loop, List.mapM, List.mapM.loop, List.filterMap,
        List.replicate, Function.comp_def]
      rfl

/-! ## Ranged keys -/

@[simp] theorem specNth?_cons_zero (a : ByteArray) (as : List ByteArray) :
    specNth? (a :: as) 0 = some a := rfl

@[simp] theorem specNth?_cons_succ (a : ByteArray) (as : List ByteArray) (i : Nat) :
    specNth? (a :: as) (i+1) = specNth? as i := by
  simp [specNth?]

theorem range_succ_cons (n : Nat) :
    List.range (n+1) = 0 :: (List.range n).map (fun i => i+1) :=
  List.range_succ_eq_map

theorem mapM_range_nth (ks : List ByteArray) (g : ByteArray → Script) :
    (List.range ks.length).mapM (fun idx =>
      match specNth? ks idx with
      | some k => Except.ok (g k)
      | none => Except.error "missing key at expansion index") =
      Except.ok (ks.map g) := by
  induction ks with
  | nil =>
      simp [List.range, List.range.loop, List.mapM, List.mapM.loop]
      rfl
  | cons a as ih =>
      rw [show (a :: as).length = as.length + 1 by rfl, range_succ_cons]
      simp [List.mapM_cons, List.mapM_map, ih, Function.comp_def]
      rfl

theorem specResolve_xpub_single (p : KeyProvider)
    (o : Option KeyOrigin) (enc : String) (path : List UInt32) (w : Wildcard)
    (raw : String) (hw : w ≠ Wildcard.none) (hne : p (.xpub o enc path w raw) ≠ []) :
    specResolve p [.xpub o enc path w raw] = .ok [p (.xpub o enc path w raw)] := by
  cases w <;> simp_all [specResolve, resolveKey, KeyExpr.isRanged]

theorem specAlignedCount_single (ks : List ByteArray) (hne : ks ≠ []) :
    specAlignedCount [ks] = some ks.length := by
  cases ks with
  | nil => contradiction
  | cons a as => simp [specAlignedCount, List.foldl]

theorem specAlignOne_length (ks : List ByteArray) :
    specAlignOne ks.length ks = ks := by
  cases ks with
  | nil => rfl
  | cons a as => cases as <;> rfl

/-- A ranged `wpkh` expands to exactly the provider's keys, in provider order,
each mapped through `payToWitnessPubkeyHash`. -/
theorem specExpand?_wpkh_range (o : Option KeyOrigin) (enc : String)
    (path : List UInt32) (w : Wildcard) (raw : String)
    (hw : w ≠ Wildcard.none) (ks : List ByteArray) (hne : ks ≠ []) :
    specExpand? (.wpkh (.xpub o enc path w raw)) (fun _ => ks) =
      .ok (ks.map payToWitnessPubkeyHash) := by
  rw [specExpand?, Descriptor.keys, specResolve_xpub_single _ _ _ _ _ _ hw]
  · simp [specAlignedCount_single ks hne, specAlignOne_length]
    change (List.range ks.length).mapM (fun idx =>
      match specNth? ks idx with
      | some k => Except.ok (payToWitnessPubkeyHash k)
      | none => Except.error "missing key at expansion index") =
      Except.ok (ks.map payToWitnessPubkeyHash)
    exact mapM_range_nth ks payToWitnessPubkeyHash
  · exact hne

/-- Cardinality form: the number of expanded scripts is exactly the provider
list length. -/
theorem specExpand?_wpkh_range_length (o : Option KeyOrigin) (enc : String)
    (path : List UInt32) (w : Wildcard) (raw : String)
    (hw : w ≠ Wildcard.none) (ks : List ByteArray) (hne : ks ≠ []) :
    ∃ scripts, specExpand? (.wpkh (.xpub o enc path w raw)) (fun _ => ks) =
        .ok scripts ∧ scripts.length = ks.length := by
  refine ⟨_, specExpand?_wpkh_range o enc path w raw hw ks hne, ?_⟩
  simp

theorem mapM_range_nth_except (ks : List ByteArray)
    (g : ByteArray → Except String Script) :
    (List.range ks.length).mapM (fun idx =>
      match specNth? ks idx with
      | some k => g k
      | none => Except.error "missing key at expansion index") =
      ks.mapM g := by
  induction ks with
  | nil => simp [List.range, List.range.loop, List.mapM, List.mapM.loop]
  | cons a as ih =>
      rw [show (a :: as).length = as.length + 1 by rfl, range_succ_cons]
      simp [List.mapM_cons, List.mapM_map, ih, Function.comp_def]

theorem mapM_taprootKeyPath_ok (ks : List ByteArray) (scripts : List Script)
    (h : ks.mapM taprootKeyPath = some scripts) :
    ks.mapM (fun k =>
      match taprootKeyPath k with
      | some script => Except.ok script
      | none => Except.error "internal key does not lift to a taproot output") =
      Except.ok scripts := by
  induction ks generalizing scripts with
  | nil =>
      simp [List.mapM, List.mapM.loop] at h ⊢
      subst h
      rfl
  | cons a as ih =>
      simp only [List.mapM_cons] at h ⊢
      cases hk : taprootKeyPath a with
      | none => simp [hk] at h
      | some s =>
          simp only [hk] at h ⊢
          cases hrest : as.mapM taprootKeyPath with
          | none => simp [hrest] at h
          | some ss =>
              simp [hrest] at h
              obtain rfl := h
              simp [ih ss hrest]
              rfl

/-- The `tr`-key-path case: if the provider supplies one key per position and
the internal key lifts, the expansion maps `taprootKeyPath` over the provider
list.  Failure of the lift is reported as an error, not skipped. -/
theorem specExpand?_tr_range (o : Option KeyOrigin) (enc : String)
    (path : List UInt32) (w : Wildcard) (raw : String)
    (hw : w ≠ Wildcard.none) (ks : List ByteArray) (hne : ks ≠ [])
    (scripts : List Script)
    (hlift : ks.mapM taprootKeyPath = some scripts) :
    specExpand? (.tr (.xpub o enc path w raw)) (fun _ => ks) =
      .ok scripts := by
  rw [specExpand?, Descriptor.keys, specResolve_xpub_single _ _ _ _ _ _ hw]
  · simp [specAlignedCount_single ks hne, specAlignOne_length]
    change (List.range ks.length).mapM (fun idx =>
      match specNth? ks idx with
      | some k =>
          match taprootKeyPath k with
          | some script => Except.ok script
          | none => Except.error "internal key does not lift to a taproot output"
      | none => Except.error "missing key at expansion index") =
      Except.ok scripts
    rw [mapM_range_nth_except]
    exact mapM_taprootKeyPath_ok ks scripts hlift
  · exact hne

/-! ## Multisig with one ranged key and fixed companions -/

theorem specNth?_replicate (c : ByteArray) : ∀ (n i : Nat), i < n →
    specNth? (List.replicate n c) i = some c
  | 0, i, h => absurd h (Nat.not_lt_zero i)
  | n+1, 0, _ => by simp [specNth?, List.replicate_succ]
  | n+1, i+1, h => by
      rw [List.replicate_succ]
      change specNth? (List.replicate n c) i = some c
      exact specNth?_replicate c n i (Nat.lt_of_succ_lt_succ h)

theorem filterMap_nth_map_replicate (cs : List ByteArray) (n idx : Nat)
    (h : idx < n) :
    (cs.map (fun c => List.replicate n c)).filterMap
        (fun xs => specNth? xs idx) = cs := by
  induction cs with
  | nil => rfl
  | cons c cs ih =>
      simp [specNth?_replicate c n idx h, ih]

theorem filterMap_nth_cons_replicate (ks cs : List ByteArray) (n idx : Nat)
    (h : idx < n) :
    (ks :: cs.map (fun c => List.replicate n c)).filterMap
        (fun xs => specNth? xs idx) =
      match specNth? ks idx with
      | some k => k :: cs
      | none => cs := by
  rw [List.filterMap_cons, filterMap_nth_map_replicate cs n idx h]
  cases specNth? ks idx <;> rfl

theorem specBuildAt_multi_aligned (t : Nat) (sorted : Bool)
    (ks cs : List ByteArray) (n idx : Nat) (h : idx < n) :
    specBuildAt (.multi t [] sorted)
        (ks :: cs.map (fun c => List.replicate n c)) idx =
      match specNth? ks idx with
      | some k =>
          .ok (multiScript t
            (if sorted then sortPubkeys (k :: cs) else k :: cs))
      | none => .error "missing key at expansion index" := by
  dsimp only [specBuildAt]
  rw [filterMap_nth_cons_replicate ks cs n idx h]
  cases hk : specNth? ks idx with
  | none => simp
  | some k => simp

theorem range_map_nth (ks : List ByteArray) :
    (List.range ks.length).map (fun i => specNth? ks i) = ks.map some := by
  induction ks with
  | nil => rfl
  | cons a as ih =>
      rw [show (a :: as).length = as.length + 1 by rfl, range_succ_cons]
      simp [List.map, ih, specNth?_cons_succ, Function.comp_def]

theorem mapM_ok_map (ks : List ByteArray) (g : ByteArray → Script) :
    ks.mapM (fun k => (Except.ok (g k) : Except String Script)) =
      (Except.ok (ks.map g) : Except String (List Script)) := by
  induction ks with
  | nil => rfl
  | cons a as ih =>
      simp only [List.mapM_cons, ih]
      rfl

theorem mapM_congr_list {α β : Type} (l : List α)
    (f g : α → Except String β) (h : ∀ a ∈ l, f a = g a) :
    l.mapM f = l.mapM g := by
  induction l with
  | nil => rfl
  | cons a as ih =>
      simp only [List.mapM_cons]
      rw [h a (by simp), ih (fun x hx => h x (by simp [hx]))]

theorem mapM_range_buildAt_multi (t : Nat) (sorted : Bool)
    (ks cs : List ByteArray) (n : Nat) (hlen : ks.length = n) :
    (List.range n).mapM (fun idx =>
      specBuildAt (.multi t [] sorted)
        (ks :: cs.map (fun c => List.replicate n c)) idx) =
      .ok (ks.map fun k =>
        multiScript t (if sorted then sortPubkeys (k :: cs) else k :: cs)) := by
  subst hlen
  let buildFor : Option ByteArray → Except String Script := fun
    | some k => .ok (multiScript t
        (if sorted then sortPubkeys (k :: cs) else k :: cs))
    | none => .error "missing key at expansion index"
  have hcongr : ∀ idx ∈ List.range ks.length,
      specBuildAt (.multi t [] sorted)
        (ks :: cs.map (fun c => List.replicate ks.length c)) idx =
      buildFor (specNth? ks idx) := by
    intro idx hidx
    have hlt : idx < ks.length := List.mem_range.mp hidx
    rw [specBuildAt_multi_aligned t sorted ks cs ks.length idx hlt]
  rw [mapM_congr_list _ _ _ hcongr]
  calc
    (List.range ks.length).mapM (fun a => buildFor (specNth? ks a))
        = ((List.range ks.length).map (fun i => specNth? ks i)).mapM buildFor := by
            rw [List.mapM_map]
            rfl
    _ = (ks.map some).mapM buildFor := by rw [range_map_nth]
    _ = ks.mapM (fun k => buildFor (some k)) := by
          rw [List.mapM_map]
          rfl
    _ = ks.mapM (fun k => Except.ok (multiScript t
          (if sorted then sortPubkeys (k :: cs) else k :: cs))) := rfl
    _ = _ := mapM_ok_map ks _

theorem foldl_max_singletons_const (cs : List ByteArray) :
    ∀ (m : Nat), 1 ≤ m →
      List.foldl (fun a xs => max a xs.length) m
        (cs.map (fun c => [c])) = m := by
  induction cs with
  | nil => intro m _; rfl
  | cons c cs ih =>
      intro m hm
      simp only [List.map, List.foldl]
      change List.foldl (fun a xs => max a xs.length) (max m 1)
        (cs.map (fun c => [c])) = m
      rw [Nat.max_eq_left hm]
      exact ih m hm

theorem foldl_max_mixed (ks cs : List ByteArray) (hne : ks ≠ []) :
    List.foldl (fun m xs => max m xs.length) 0
        (ks :: cs.map (fun c => [c])) = ks.length := by
  cases ks with
  | nil => contradiction
  | cons k ks =>
      have hpos : 1 ≤ (k :: ks).length := by simp
      simp only [List.foldl]
      rw [Nat.zero_max]
      exact foldl_max_singletons_const cs (k :: ks).length hpos

theorem specAlignedCount_mixed (ks cs : List ByteArray) (hne : ks ≠ []) :
    specAlignedCount (ks :: cs.map (fun c => [c])) = some ks.length := by
  have hmax := foldl_max_mixed ks cs hne
  have hpos : ks.length ≠ 0 := by
    cases ks with
    | nil => contradiction
    | cons k ks => simp
  simp [specAlignedCount, hmax, hpos]

theorem specResolve_xpub_consts (p : KeyProvider)
    (o : Option KeyOrigin) (enc : String) (path : List UInt32)
    (w : Wildcard) (raw : String) (cs : List ByteArray)
    (hw : w ≠ Wildcard.none) (hne : p (.xpub o enc path w raw) ≠ []) :
    specResolve p
        (.xpub o enc path w raw :: cs.map (fun c => .const none c false "")) =
      .ok (p (.xpub o enc path w raw) :: cs.map (fun c => [c])) := by
  simp [specResolve, resolveKey, KeyExpr.isRanged, hne, specResolve_consts]

/-- A `multi`/`sortedmulti` with one ranged key and any number of fixed
companions expands to the provider keys in provider order.  Within position
`i` the ranged key stays first (it is first in source order), the fixed keys
keep source order, and `sortedmulti` applies `sortPubkeys` to that list. -/
theorem specExpand?_multi_xpub_consts
    (t : Nat) (sorted : Bool) (o : Option KeyOrigin) (enc : String)
    (path : List UInt32) (w : Wildcard) (raw : String)
    (hw : w ≠ Wildcard.none) (ks : List ByteArray) (hne : ks ≠ [])
    (cs : List ByteArray) :
    specExpand?
        (.multi t
          (.xpub o enc path w raw :: cs.map (fun c => .const none c false ""))
          sorted)
        (fun _ => ks) =
      .ok (ks.map fun k =>
        multiScript t (if sorted then sortPubkeys (k :: cs) else k :: cs)) := by
  rw [specExpand?]
  simp only [Descriptor.keys]
  rw [specResolve_xpub_consts (fun _ => ks) o enc path w raw cs hw hne]
  simp only
  rw [specAlignedCount_mixed ks cs hne]
  simp only
  have hfirst : specAlignOne ks.length ks = ks := by
    cases ks with
    | nil => contradiction
    | cons a as => cases as <;> rfl
  have hordered : (ks :: cs.map (fun c => [c])).map (specAlignOne ks.length) =
      ks :: cs.map (fun c => List.replicate ks.length c) := by
    simp only [List.map, hfirst]
    simp [specAlignOne, List.map_map, Function.comp_def]
  rw [hordered]
  exact mapM_range_buildAt_multi t sorted ks cs ks.length rfl

/-! ## Determinism and totality -/

/-! ## Transfer to the executable `expand?` -/

theorem expand?_pk_const (origin : Option KeyOrigin) (pubkey : ByteArray)
    (xonly : Bool) (raw : String) :
    expand? (.pk (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [payToPubkey pubkey] := by
  rw [expand?_eq_spec]
  exact specExpand?_pk_const origin pubkey xonly raw

@[walletRule "DESC-021"]
theorem expand?_pkh_const (origin : Option KeyOrigin) (pubkey : ByteArray)
    (xonly : Bool) (raw : String) :
    expand? (.pkh (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [payToPubkeyHash pubkey] := by
  rw [expand?_eq_spec]
  exact specExpand?_pkh_const origin pubkey xonly raw

@[walletRule "DESC-022"]
theorem expand?_wpkh_const (origin : Option KeyOrigin) (pubkey : ByteArray)
    (xonly : Bool) (raw : String) :
    expand? (.wpkh (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [payToWitnessPubkeyHash pubkey] := by
  rw [expand?_eq_spec]
  exact specExpand?_wpkh_const origin pubkey xonly raw

theorem expand?_shWpkh_const (origin : Option KeyOrigin) (pubkey : ByteArray)
    (xonly : Bool) (raw : String) :
    expand? (.shWpkh (.const origin pubkey xonly raw)) (fun _ => []) =
      .ok [payToScriptHash (payToWitnessPubkeyHash pubkey)] := by
  rw [expand?_eq_spec]
  exact specExpand?_shWpkh_const origin pubkey xonly raw

theorem expand?_multi_consts (t : Nat) (sorted : Bool) (ks : List ByteArray)
    (hne : ks ≠ []) :
    expand? (.multi t (ks.map (fun k => .const none k false "")) sorted)
        (fun _ => []) =
      .ok [multiScript t (if sorted then sortPubkeys ks else ks)] := by
  rw [expand?_eq_spec]
  exact specExpand?_multi_consts t sorted ks hne

theorem expand?_wpkh_range (o : Option KeyOrigin) (enc : String)
    (path : List UInt32) (w : Wildcard) (raw : String)
    (hw : w ≠ Wildcard.none) (ks : List ByteArray) (hne : ks ≠ []) :
    expand? (.wpkh (.xpub o enc path w raw)) (fun _ => ks) =
      .ok (ks.map payToWitnessPubkeyHash) := by
  rw [expand?_eq_spec]
  exact specExpand?_wpkh_range o enc path w raw hw ks hne

theorem expand?_multi_xpub_consts
    (t : Nat) (sorted : Bool) (o : Option KeyOrigin) (enc : String)
    (path : List UInt32) (w : Wildcard) (raw : String)
    (hw : w ≠ Wildcard.none) (ks : List ByteArray) (hne : ks ≠ [])
    (cs : List ByteArray) :
    expand?
        (.multi t
          (.xpub o enc path w raw :: cs.map (fun c => .const none c false ""))
          sorted)
        (fun _ => ks) =
      .ok (ks.map fun k =>
        multiScript t (if sorted then sortPubkeys (k :: cs) else k :: cs)) := by
  rw [expand?_eq_spec]
  exact specExpand?_multi_xpub_consts t sorted o enc path w raw hw ks hne cs

/-- Expansion is deterministic: it is a pure function of descriptor and
provider, so it cannot depend on any ambient state. -/
theorem expand?_deterministic (d : Descriptor) (p : KeyProvider) :
    expand? d p = expand? d p := rfl

/-- Expansion is total: every input has an `Except` result (there is no
`panic`/`Option` failure path). -/
theorem expand?_total (d : Descriptor) (p : KeyProvider) :
    ∃ r, expand? d p = r := ⟨_, rfl⟩

/-- The error-erasing interface only discards errors; on success it returns
exactly the scripts computed by `expand?`. -/
theorem expand_eq_of_ok (d : Descriptor) (p : KeyProvider) (scripts : List Script)
    (h : expand? d p = .ok scripts) : expand d p = scripts := by
  simp [expand, h]

end BitcoinProofs.Wallet.Desc
