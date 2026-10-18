import Bitcoin.TxValidation.Interface
import Bitcoin.Ledger.Interface
import Bitcoin.DataLaws.Interface
import Bitcoin.RuleAttr

/-!
# Bitcoin.TxValidation.ScriptExecCache — TXV-062: the script-execution cache

Landing row TXV-062 (the cache-model note unblocked, route B): Core's
`CheckInputScripts` **script-execution-cache slice** —
validation.cpp:2076-2083 (key + hit) + 2135-2139 (insert) @cce32b168
(row pin 2086-2093 drift, the field-order note; evidence md5
6562d845):

```cpp
uint256 hashCacheEntry;                                          // :2076
CSHA256 hasher = validation_cache.ScriptExecutionCacheHasher();   // :2077 (salted nonce)
hasher.Write(UCharCast(tx.GetWitnessHash().begin()), 32)
      .Write((unsigned char*)&flags, sizeof(flags))
      .Finalize(hashCacheEntry.begin());                          // :2078-2079
if (validation_cache.m_script_execution_cache
      .contains(hashCacheEntry, !cacheFullScriptStore)) {        // :2082
  return true;                                                   // :2083
}
[...]                                                            // :2090-2134
if (cacheFullScriptStore && !pvChecks) {                          // :2135
  // We executed all of the provided scripts, and were told to
  // cache the result. Do so now.
  validation_cache.m_script_execution_cache.insert(hashCacheEntry); // :2138
}
```

The row's own text marks the layer "(optimization, provably
transparent)" = a NON-CONSENSUS CuckooCache perf layer; this file is
the honest model the cache-model note asked for: a cache map + the cached-hit ⇒
same-verdict transparency law.

## What is modeled (Core-faithful)

* the **key** = the `(wtxid, flags)` preimage pair (`ScriptExecCacheKey`).
  Core's `hashCacheEntry = CSHA256(nonce ∥ wtxid ∥ flags)` (:2077-2079)
  is an injective stand-in for its preimage: the model keeps the pair —
  the perfect-collision-free version of the hash (the SHA-256
  collision-freedom + the salted `GetRandHash` nonce = Core's own
  assumption for the same property). The wtxid half =
  `tx.GetWitnessHash()` (the `Bitcoin.DataLaws.wtxid` of TXV-073's
  `mempoolKey`), the flags half = the `ScriptFlags` word (TXV-061).
* the **cache** = the stored-key membership map
  `ScriptExecCache := Key → Bool` (the tree's `UtxoSet = OutPoint →
  Option Coin` idiom); `cacheContains`/`cacheInsert` (:2082/:2138).
* `checkInputScriptsCached` = the whole cache slice of one
  `CheckInputScripts` run:
  - **hit** (:2082-2083): `contains` ⇒ `(some true, c)` — accept
    WITHOUT executing (and without the deferral loop), cache unchanged;
  - **defer** (:2120-2121): miss + `pvChecks` ⇒ `(some true, c)` —
    Core `pvChecks->emplace_back` defers every check and returns true
    (:2139); NO insert (insert requires `!pvChecks` :2135);
  - **executed** (:2122-2132): miss + `!pvChecks` ⇒ the executed
    verdict `exec k`; a PASS (`exec k = some true`) stores the key iff
    `cacheFullScriptStore` (:2135-2139) — a FAIL, an `unjudged`
    (the transaction-validation module's taproot-EC `none`) or a deferred run NEVER stores.
  `exec : Key → Option Bool` is the model's honesty precondition for
  the transparency (Core's :2106-2111 CScriptCheck comment: "we very
  carefully only pass in things to CScriptCheck which are clearly
  committed to by tx' witness hash" + `assert(!coin.IsSpent())` :2091
  — only key-committed data enters the executed verdict): the would-be
  `Full.scriptLaneTx` verdict (the transaction-validation module's `Option Bool` idiom) as a
  function of the key alone.

## What is deliberately out of model (the cache-model note's scope note)

* CuckooCache randomized eviction, epoch/erasure locking (the
  `contains`'s second arg `!cacheFullScriptStore`, the
  `cacheValid Milli` epoch sweep) and the salted `GetRandHash` nonce =
  nondeterministic process state;
* `cacheSigStore`/`m_signature_cache` (scriptcache.h, the per-signature
  `CScriptCheck` cache) = a different cache;
* the `CheckInputsFromMempoolAndCache` re-run channel (:1176-1181 =
  TXV-061) and the error-KIND split (:2126-2131 = the error-kind note).

## The laws (all sorry-free, axiom pins at the file end)

* `checkInputScriptsCached_hit` (:2082-2083 verbatim),
  `_miss_runs` (miss ⇒ verdict = the executed verdict),
  `_miss_defers` (:2120-2121), `_fail_closed` (a reject is never
  upgraded), `_unjudged_propagate` (never cache what you cannot
  adjudicate), `_insert_on_pass` + `_insert_discipline`
  (:2135-2139 verbatim: the key is stored ONLY by a miss + !pvChecks +
  store + pass run), `goodCache_stores_passes` (the GoodCache
  invariant) and **`checkInputScriptsCached_consensus_invisible`** =
  the row's "provably transparent": on a good cache (no-defer arm) the
  cached pipeline's verdict EQUALS the executed verdict `exec k` — the
  cache never changes a consensus verdict.
-/
namespace Bitcoin.TxValidation.ScriptExecCache

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Activation

/-! ## The cache key (validation.cpp:2076-2079) -/

/-- The script-execution-cache key: the `(wtxid, flags)` PREIMAGE pair
of Core's `hashCacheEntry = CSHA256(nonce ∥ wtxid ∥ flags)`
(:2077-2079). Modeling the preimage (not the hash) = the
perfect-collision-free stand-in; `wtxid = tx.GetWitnessHash()` =
`Bitcoin.DataLaws.wtxid` (TXV-073 `mempoolKey`), `flags` = the
`ScriptFlags` word (TXV-061). -/
structure ScriptExecCacheKey where
  wtxid : ByteArray
  flags : ScriptFlags

/-! `BEq` follows the ledger `OutPoint` pattern (`Data/Tx.lean:42`:
`bytesBEq hash && n == n`): the byte-eq on the wtxid half, the
(derived `DecidableEq`) decide on the flags half. -/
instance : BEq ScriptExecCacheKey where
  beq a b := bytesBEq a.wtxid b.wtxid && (decide (a.flags = b.flags) : Bool)

/-- The key `BEq` is real equality (the `outPointBEq_eq` pattern,
`Ledger/Interface.lean:168`). -/
theorem scriptExecCacheKeyBEq_eq (a b : ScriptExecCacheKey)
    (h : (a == b) = true) : a = b := by
  have h0 : (a == b) = (bytesBEq a.wtxid b.wtxid && decide (a.flags = b.flags)) := rfl
  rw [h0, Bool.and_eq_true] at h
  obtain ⟨h1, h2⟩ := h
  have he1 := bytesBEq_eq_of_true _ _ h1
  have he2 : a.flags = b.flags := of_decide_eq_true h2
  have ha : a = ScriptExecCacheKey.mk a.wtxid a.flags := rfl
  have hb : b = ScriptExecCacheKey.mk b.wtxid b.flags := rfl
  rw [ha, hb, he1, he2]

/-! ## The cache (CuckooCache's stored-key set, map edition) -/

/-- Core's `m_script_execution_cache` (validation.cpp:2082/2138) = the
set of stored keys. Model: the key → Bool membership map (the tree's
`UtxoSet := OutPoint → Option Coin` idiom); CuckooCache's randomized
eviction + epoch locking = out of model. -/
abbrev ScriptExecCache := ScriptExecCacheKey → Bool

/-- `contains` (CuckooCache::contains, :2082). -/
def cacheContains (c : ScriptExecCache) (k : ScriptExecCacheKey) : Bool := c k

/-- `insert` (CuckooCache::insert, :2138): the key joins the stored
set; all other keys keep their membership (the eviction-free insert). -/
def cacheInsert (c : ScriptExecCache) (k : ScriptExecCacheKey) :
    ScriptExecCache := fun k' => (k' == k) || c k'

/-- The empty cache (the process start state). -/
def emptyCache : ScriptExecCache := fun _ => false

/-! ## `CheckInputScripts`'s cache slice (validation.cpp:2076-2083 + 2135-2139) -/

/-- One `CheckInputScripts` run over the script-execution cache.
`exec k` = the EXECUTED verdict for the key's `(wtxid, flags)` (the
:2106-2111 wtxid-commitment precondition; `some true` = every input
verified (the transaction-validation module `scriptLane` `.ok`), `some false` = a script failure
(`:2126-2131` `state.Invalid`), `none` = the unjudged taproot-EC
queue). `store = cacheFullScriptStore`, `pv = pvChecks ≠ null`.
Returns the run's verdict and the resulting cache. -/
@[rule "TXV-062"]
def checkInputScriptsCached (c : ScriptExecCache) (k : ScriptExecCacheKey)
    (exec : ScriptExecCacheKey → Option Bool) (store pv : Bool) :
    Option Bool × ScriptExecCache :=
  if cacheContains c k then (some true, c)
  else if pv then (some true, c)
  else match exec k with
    | some true => (some true, if store then cacheInsert c k else c)
    | some false => (some false, c)
    | none => (none, c)

/-! ## The laws (all sorry-free) -/

/-- :2082-2083 verbatim: a hit accepts WITHOUT executing (and without
deferring) and leaves the cache unchanged. -/
@[rule "TXV-062"]
theorem checkInputScriptsCached_hit (c : ScriptExecCache)
    (k : ScriptExecCacheKey) (exec : ScriptExecCacheKey → Option Bool)
    (store pv : Bool) (hhit : cacheContains c k = true) :
    checkInputScriptsCached c k exec store pv = (some true, c) := by
  simp only [checkInputScriptsCached, if_pos (by simpa using hhit)]

/-- The miss + no-defer arm runs the scripts: the verdict IS the
executed verdict `exec k` (the cache has no effect on it). -/
@[rule "TXV-062"]
theorem checkInputScriptsCached_miss_runs (c : ScriptExecCache)
    (k : ScriptExecCacheKey) (exec : ScriptExecCacheKey → Option Bool)
    (store pv : Bool) (hmiss : cacheContains c k = false)
    (hnpv : pv = false) :
    (checkInputScriptsCached c k exec store pv).1 = exec k := by
  simp only [checkInputScriptsCached, hmiss, hnpv]
  cases hex : exec k with
  | none => rfl
  | some b =>
    cases hb : b with
    | true => cases store <;> simp
    | false => rfl

/-- :2120-2121: a miss on the `pvChecks` arm defers every check (the
verdict comes later) and returns true WITHOUT storing (insert requires
`!pvChecks`, :2135). -/
@[rule "TXV-062"]
theorem checkInputScriptsCached_miss_defers (c : ScriptExecCache)
    (k : ScriptExecCacheKey) (exec : ScriptExecCacheKey → Option Bool)
    (store pv : Bool) (hmiss : cacheContains c k = false)
    (hpv : pv = true) :
    checkInputScriptsCached c k exec store pv = (some true, c) ∧
      (checkInputScriptsCached c k exec store pv).2 = c := by
  simp only [checkInputScriptsCached, hmiss, hpv]
  exact ⟨rfl, rfl⟩

/-- Fail-closedness (TXV-058/060's idiom): a reject verdict can only
  come from the execution itself — never bypassed, never upgraded. -/
@[rule "TXV-062"]
theorem checkInputScriptsCached_fail_closed (c : ScriptExecCache)
    (k : ScriptExecCacheKey) (exec : ScriptExecCacheKey → Option Bool)
    (store pv : Bool)
    (h : (checkInputScriptsCached c k exec store pv).1 = some false) :
    exec k = some false ∧ cacheContains c k = false ∧ pv = false := by
  simp only [checkInputScriptsCached] at h
  by_cases hhit : cacheContains c k = true
  · rw [if_pos (by simpa using hhit)] at h; simp at h
  · rw [if_neg (by simpa [hhit] : ¬(cacheContains c k = true))] at h
    by_cases hpv : pv = true
    · rw [if_pos (by simpa using hpv)] at h; simp at h
    · rw [if_neg (by simp [hpv] : ¬(pv = true))] at h
      by_cases hmiss : cacheContains c k = false
      · by_cases hpv' : pv = false
        · cases hex : exec k with
          | none => simp [hex] at h
          | some b => cases hb : b with
            | true => simp [hex, hb] at h
            | false =>
                simp [hex, hb] at h
                exact ⟨rfl, hmiss, hpv'⟩
        · exact absurd hpv (by cases pv <;> simp [hpv'])
      · exact absurd hhit (by simpa [hmiss] using hhit)

/-- Never cache what you cannot adjudicate: the unjudged queue (`none`
= the transaction-validation module's taproot-EC outside-seam verdict) propagates and stores
nothing. -/
@[rule "TXV-062"]
theorem checkInputScriptsCached_unjudged_propagate (c : ScriptExecCache)
    (k : ScriptExecCacheKey) (exec : ScriptExecCacheKey → Option Bool)
    (store pv : Bool)
    (h : (checkInputScriptsCached c k exec store pv).1 = none) :
    exec k = none ∧ cacheContains c k = false ∧ pv = false := by
  simp only [checkInputScriptsCached] at h
  by_cases hhit : cacheContains c k = true
  · rw [if_pos (by simpa using hhit)] at h; simp at h
  · rw [if_neg (by simpa [hhit] : ¬(cacheContains c k = true))] at h
    by_cases hpv : pv = true
    · rw [if_pos (by simpa using hpv)] at h; simp at h
    · rw [if_neg (by simp [hpv] : ¬(pv = true))] at h
      by_cases hmiss : cacheContains c k = false
      · by_cases hpv' : pv = false
        · cases hex : exec k with
          | none =>
              simp [hex] at h
              exact ⟨rfl, hmiss, hpv'⟩
          | some b => cases hb : b with
            | true => simp [hex, hb] at h
            | false => simp [hex, hb] at h
        · exact absurd hpv (by cases pv <;> simp [hpv'])
      · exact absurd hhit (by simpa [hmiss] using hhit)

/-- :2135-2139 (the `cacheFullScriptStore`-half of the insert
discipline): a miss + !pvChecks + store + PASS run stores the key. -/
@[rule "TXV-062"]
theorem checkInputScriptsCached_insert_on_pass (c : ScriptExecCache)
    (k : ScriptExecCacheKey) (exec : ScriptExecCacheKey → Option Bool)
    (store pv : Bool) (hmiss : cacheContains c k = false)
    (hnpv : pv = false) (hstore : store = true)
    (hpass : exec k = some true) :
    checkInputScriptsCached c k exec store pv = (some true, cacheInsert c k) := by
  simp [checkInputScriptsCached, hmiss, hnpv, hpass, hstore]

/-- :2135-2139 verbatim (the insert discipline): the returned cache
either stays `c`, or the key was inserted AND the full discipline
(miss ∧ !pvChecks ∧ cacheFullScriptStore ∧ executed PASS) held. -/
@[rule "TXV-062"]
theorem checkInputScriptsCached_insert_discipline (c : ScriptExecCache)
    (k : ScriptExecCacheKey) (exec : ScriptExecCacheKey → Option Bool)
    (store pv : Bool) :
    (checkInputScriptsCached c k exec store pv).2 = c ∨
      ((checkInputScriptsCached c k exec store pv).2 = cacheInsert c k ∧
        cacheContains c k = false ∧ pv = false ∧ store = true ∧
          exec k = some true) := by
  simp only [checkInputScriptsCached]
  by_cases hhit : cacheContains c k = true
  · exact Or.inl (by simp [hhit])
  · by_cases hpv : pv = true
    · exact Or.inl (by simp [hhit, hpv])
    · by_cases hpass : exec k = some true
      · by_cases hstore : store = true
        · exact Or.inr ⟨by simp [hhit, hpv, hpass, hstore],
            by simpa using hhit, by simpa using hpv, hstore, hpass⟩
        · exact Or.inl (by simp [hhit, hpv, hpass, hstore])
      · exact Or.inl (by
          simp [hhit, hpv]
          cases hex : exec k with
          | some b => cases hb : b with
            | true => simp [hex, hb] at hpass
            | false => simp [hhit, hpv, hex, hb]
          | none => simp [hhit, hpv, hex])

/-! ## The GoodCache invariant + the transparency -/

/-- The cache after one run (the `.2` projection named). -/
def cacheAfter (c : ScriptExecCache) (k : ScriptExecCacheKey)
    (exec : ScriptExecCacheKey → Option Bool) (store pv : Bool) :
    ScriptExecCache := (checkInputScriptsCached c k exec store pv).2

/-- The insert-discipline invariant (the `(a)`-half of the cache-model note
transparency argument): `GoodCache exec store c` = `c` is reachable
from the empty cache by `checkInputScriptsCached` runs, every store
being a miss + !pvChecks + store + PASS insert (the `hins` step is
`checkInputScriptsCached_insert_on_pass`'s conclusion; `hmiss`/`hpass`
carry the miss + pass facts for the law below). -/
inductive GoodCache (exec : ScriptExecCacheKey → Option Bool) (store : Bool) :
    ScriptExecCache → Prop
  | nil : GoodCache exec store emptyCache
  | step (c : ScriptExecCache) (k : ScriptExecCacheKey) (pv : Bool)
      (h : GoodCache exec store c)
      (hmiss : cacheContains c k = false)
      (hpass : exec k = some true)
      (hins : cacheAfter c k exec store pv = cacheInsert c k) :
      GoodCache exec store (cacheInsert c k)

/-- The stored keys are exactly the passing executions (the
`(a)`-half of the transparency): on a good cache, every key in the
cache has `exec k = some true`. -/
@[rule "TXV-062"]
theorem goodCache_stores_passes (exec : ScriptExecCacheKey → Option Bool)
    (store : Bool) (c : ScriptExecCache)
    (h : GoodCache exec store c) (k : ScriptExecCacheKey)
    (hhit : cacheContains c k = true) : exec k = some true := by
  revert k hhit
  induction h with
  | nil => intro k hhit; exact absurd hhit (by simp [emptyCache, cacheContains])
  | step c' k' pv' h' hmiss' hpass' hins' ih =>
      intro k hhit
      have hmem : ((k == k') || c' k) = true := by
        simpa [cacheContains, cacheInsert] using hhit
      cases hb : (k == k') with
      | true =>
          have hkeq : k = k' := scriptExecCacheKeyBEq_eq _ _ (by simpa using hb)
          rwa [← hkeq] at hpass'
      | false =>
          have hc : c' k = true := by simpa [hb] using hmem
          exact ih k hc

/-- THE transparency (the row's "(optimization, provably
transparent)"): on a good cache (no-defer arm) the cached pipeline's
verdict EQUALS the executed verdict `exec k` — hit by
`goodCache_stores_passes` (hit ⇒ `exec k = some true` = the returned
`some true`), miss by `checkInputScriptsCached_miss_runs`. The cache
never changes a consensus verdict. -/
@[rule "TXV-062"]
theorem checkInputScriptsCached_consensus_invisible (c : ScriptExecCache)
    (k : ScriptExecCacheKey) (exec : ScriptExecCacheKey → Option Bool)
    (store pv : Bool) (hgc : GoodCache exec store c)
    (hnpv : pv = false) :
    (checkInputScriptsCached c k exec store pv).1 = exec k := by
  by_cases hhit : cacheContains c k = true
  · rw [checkInputScriptsCached_hit c k exec store pv hhit]
    exact (goodCache_stores_passes exec store c hgc k hhit).symm
  · exact checkInputScriptsCached_miss_runs c k exec store pv
      (by simpa [hhit] using hhit) hnpv

/-! ## Vectors (the arm grid; `Eq Bool` statements only, the
 / Y10 Eq-Bool idiom; `P4b`-style constructor-kind
projections for the `Option Bool` verdicts) -/

private def isAcc (r : Option Bool) : Bool :=
  match r with | some true => true | _ => false
private def isRej (r : Option Bool) : Bool :=
  match r with | some false => true | _ => false
private def isUnj (r : Option Bool) : Bool :=
  match r with | none => true | _ => false

private def cvK (v : UInt8) : ByteArray :=
  (List.replicate 32 v).foldl (fun acc b => acc.push b) ByteArray.empty
private def kP : ScriptExecCacheKey := ⟨cvK 0x41, { p2sh := true }⟩
private def kF : ScriptExecCacheKey := ⟨cvK 0x61, {} ⟩
private def kO : ScriptExecCacheKey := ⟨cvK 0xE5, {} ⟩
private def execP : ScriptExecCacheKey → Option Bool := fun _ => some true
private def execF : ScriptExecCacheKey → Option Bool := fun _ => some false
private def execU : ScriptExecCacheKey → Option Bool := fun _ => none
private def cGood : ScriptExecCache := cacheInsert emptyCache kP

/-- v1 (miss + executed FAIL): reject, nothing stored — `:2126-2131`
returns Invalid before the `:2135` insert. -/
theorem sec_v1_miss_fail_no_insert :
    (isRej (checkInputScriptsCached emptyCache kF execF true false).1) = true ∧
    (cacheContains (checkInputScriptsCached emptyCache kF execF true false).2 kF) = false ∧
    (cacheContains (checkInputScriptsCached emptyCache kF execF true false).2 kP) = false := by
  decide

/-- v2 (miss + PASS + store + !pvChecks): accept, the key stored —
`:2135-2139` verbatim. -/
theorem sec_v2_miss_pass_store_inserts :
    (isAcc (checkInputScriptsCached emptyCache kP execP true false).1) = true ∧
    (cacheContains (checkInputScriptsCached emptyCache kP execP true false).2 kP) = true ∧
    (cacheContains (checkInputScriptsCached emptyCache kP execP true false).2 kF) = false := by
  decide

/-- v2' (miss + PASS + store + pvChecks): accept, NOTHING stored —
`:2135`'s `!pvChecks` half (the deferral arm never caches). -/
theorem sec_v2p_pass_defer_no_insert :
    (isAcc (checkInputScriptsCached emptyCache kP execP true true).1) = true ∧
    (cacheContains (checkInputScriptsCached emptyCache kP execP true true).2 kP) = false := by
  decide

/-- v2'' (miss + PASS + !store): accept, nothing stored —
`:2135`'s `cacheFullScriptStore` half. -/
theorem sec_v2s_pass_nostore_no_insert :
    (isAcc (checkInputScriptsCached emptyCache kP execP false false).1) = true ∧
    (cacheContains (checkInputScriptsCached emptyCache kP execP false false).2 kP) = false := by
  decide

/-- v3 (HIT): accept WITHOUT executing (:2082-2083) — even when the
executed verdict would be a FAIL (the GoodCache hypothesis of the
transparency law; on a good cache this cannot happen:
`goodCache_stores_passes`), and the cache is unchanged. -/
theorem sec_v3_hit_accepts_without_exec :
    (isAcc (checkInputScriptsCached cGood kP execF true true).1) = true ∧
    (isAcc (checkInputScriptsCached cGood kP execF false false).1) = true ∧
    (cacheContains (checkInputScriptsCached cGood kP execF true true).2 kP) = true ∧
    (cacheContains (checkInputScriptsCached cGood kP execF false false).2 kP) = true ∧
    (cacheContains (checkInputScriptsCached cGood kP execP false false).2 kP) = true := by
  decide

/-- v4 (HIT = the executed verdict, the transparency on a concrete
good cache): `cGood = cacheInsert emptyCache kP` w/ `execP` (all-pass)
= a GoodCache — the hit's `some true` IS `exec kP` = `some true`. -/
theorem sec_v4_hit_is_exec_on_good_cache :
    ((fun h => h) (checkInputScriptsCached cGood kP execP true false).1) =
        ((fun h => h) (execP kP)) ∧
    (isAcc (checkInputScriptsCached cGood kP execP true false).1) = true ∧
    ((fun h => h) (execP kP)) = some true := by
  decide

/-- v5 (miss + unjudged): the `none` queue propagates, nothing stored
(an unjudged run is never cached as a pass). -/
theorem sec_v5_miss_unjudged_no_insert :
    (isUnj (checkInputScriptsCached emptyCache kO execU true false).1) = true ∧
    (cacheContains (checkInputScriptsCached emptyCache kO execU true false).2 kO) = false := by
  decide

/-! ## Axiom pins (every theorem here is sorry-free; standard axioms
only; no `native_decide`) -/

section Pins

/-- info: 'Bitcoin.TxValidation.ScriptExecCache.scriptExecCacheKeyBEq_eq' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms scriptExecCacheKeyBEq_eq
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached_hit' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkInputScriptsCached_hit
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached_miss_runs' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkInputScriptsCached_miss_runs
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached_miss_defers' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkInputScriptsCached_miss_defers
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached_fail_closed' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkInputScriptsCached_fail_closed
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached_unjudged_propagate' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkInputScriptsCached_unjudged_propagate
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached_insert_on_pass' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkInputScriptsCached_insert_on_pass
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached_insert_discipline' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkInputScriptsCached_insert_discipline
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.goodCache_stores_passes' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms goodCache_stores_passes
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.checkInputScriptsCached_consensus_invisible' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms checkInputScriptsCached_consensus_invisible
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.sec_v1_miss_fail_no_insert' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms sec_v1_miss_fail_no_insert
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.sec_v2_miss_pass_store_inserts' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms sec_v2_miss_pass_store_inserts
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.sec_v2p_pass_defer_no_insert' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms sec_v2p_pass_defer_no_insert
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.sec_v2s_pass_nostore_no_insert' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms sec_v2s_pass_nostore_no_insert
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.sec_v3_hit_accepts_without_exec' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms sec_v3_hit_accepts_without_exec
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.sec_v4_hit_is_exec_on_good_cache' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms sec_v4_hit_is_exec_on_good_cache
/-- info: 'Bitcoin.TxValidation.ScriptExecCache.sec_v5_miss_unjudged_no_insert' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms sec_v5_miss_unjudged_no_insert

end Pins

end Bitcoin.TxValidation.ScriptExecCache
