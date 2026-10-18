import Bitcoin.Block.Index

/-!
# Blk120Cor — BLK-120 promotion proof (PDW8, row TOP-38)

Row BLK-120 (cached-failed block re-submission rejected as
`duplicate-invalid` without re-validation, validation.cpp:4205-4219
@cce32b168): the `failedCache` lane of header acceptance.

Semantics port (route B): `submitVerdict` (Index.lean:285) —
`if failedCache h then some "duplicate-invalid" else none`. The
theorems here pin the two directions: the `duplicate-invalid` verdict
holds iff the hash is in the failed cache (no re-validation — the
cache verdict IS the verdict), and the `none` fall-through (fresh
validation) iff the hash is not cached-failed. `by_cases` +
`rw`/`simp` + `simp at hv` contradiction (reference proof). Companion to the
core `submitVerdict_failed` (one-directional, Index.lean:288).
PDW8-2 build evidence: the tree file was clean FIRST-BUILD RC=0
(the w3-120 gold assembly; contrast Blk063Cor which died with the
:53/:54 errors).

Axiom-pinned in-file (D2 L3); zero sorryAx — pin-sets per theorem
(PDW8-2 probe pass): all 6 decls (the 4 private lemmas + both
rule-iff theorems) [propext] (the `unfold`/`rw`/`simp`-herd route);
every pin ⊆ [propext, Classical.choice, Quot.sound] = the charter
trio (sorry_lint G1 class).
-/

namespace BitcoinProofs.AF.PDW8

/-- The cached-failed lane yields `duplicate-invalid` (core
`submitVerdict_failed` restated, P4 `rw`/`simp` routing). -/
private theorem submitVerdict_true (failedCache : ByteArray → Bool)
    (h : ByteArray) (hf : failedCache h = true) :
    Bitcoin.Block.Index.submitVerdict failedCache h = some "duplicate-invalid" := by
  unfold Bitcoin.Block.Index.submitVerdict; rw [hf]; simp

/-- The `none` fall-through (fresh validation) when the hash is not
cached-failed. -/
private theorem submitVerdict_false (failedCache : ByteArray → Bool)
    (h : ByteArray) (hf : failedCache h = false) :
    Bitcoin.Block.Index.submitVerdict failedCache h = none := by
  unfold Bitcoin.Block.Index.submitVerdict; rw [hf]; simp

/-- The `duplicate-invalid` verdict forces the cache hit (no
re-validation: nothing else produces this verdict). -/
private theorem submitVerdict_true_inv (failedCache : ByteArray → Bool)
    (h : ByteArray)
    (hv : Bitcoin.Block.Index.submitVerdict failedCache h = some "duplicate-invalid") :
    failedCache h = true := by
  by_cases hb : failedCache h = true
  · exact hb
  · rw [Bool.not_eq_true] at hb
    unfold Bitcoin.Block.Index.submitVerdict at hv
    rw [hb] at hv; simp at hv

/-- The `none` verdict forces a cache miss. -/
private theorem submitVerdict_false_inv (failedCache : ByteArray → Bool)
    (h : ByteArray)
    (hv : Bitcoin.Block.Index.submitVerdict failedCache h = none) :
    failedCache h = false := by
  by_cases hb : failedCache h = true
  · unfold Bitcoin.Block.Index.submitVerdict at hv
    rw [hb] at hv; simp at hv
  · rw [Bool.not_eq_true] at hb; exact hb

/-- BLK-120 (`duplicate-invalid` dir): the re-submission verdict is
`duplicate-invalid` iff the hash is cached-failed. -/
@[rule "BLK-120"]
theorem submitVerdict_duplicate_invalid_iff (failedCache : ByteArray → Bool)
    (h : ByteArray) :
    Bitcoin.Block.Index.submitVerdict failedCache h = some "duplicate-invalid" ↔
      failedCache h = true :=
  ⟨fun hv => submitVerdict_true_inv failedCache h hv,
   fun hf => submitVerdict_true failedCache h hf⟩

/-- BLK-120 (fall-through dir): the verdict is `none` (proceed to full
validation) iff the hash is not cached-failed. -/
@[rule "BLK-120"]
theorem submitVerdict_none_iff (failedCache : ByteArray → Bool)
    (h : ByteArray) :
    Bitcoin.Block.Index.submitVerdict failedCache h = none ↔
      failedCache h = false :=
  ⟨fun hv => submitVerdict_false_inv failedCache h hv,
   fun hf => submitVerdict_false failedCache h hf⟩

/-- A submission path that consults the validator only on a cache miss —
the shape of Core's `AcceptBlock`/`ProcessNewBlock` failed-cache early
return (validation.cpp:4205-4219). -/
def submitVerdictWith (validate : ByteArray → Option String)
    (failedCache : ByteArray → Bool) (h : ByteArray) : Option String :=
  if failedCache h then some "duplicate-invalid" else validate h

/-- **BLK-120** (validation-skip face): a cached-failed hash short-circuits
to `duplicate-invalid` without consulting the validator at all. -/
@[rule "BLK-120"]
theorem submitVerdictWith_cached_skips_validation
    (validate : ByteArray → Option String) (failedCache : ByteArray → Bool)
    (h : ByteArray) (hf : failedCache h = true) :
    submitVerdictWith validate failedCache h = some "duplicate-invalid" := by
  unfold submitVerdictWith
  rw [ite_eq_left hf]

/-- **BLK-120** (no re-validation): on a cache hit the verdict is
independent of which validator would have run. -/
@[rule "BLK-120"]
theorem submitVerdictWith_cached_validation_independent
    (validate1 validate2 : ByteArray → Option String)
    (failedCache : ByteArray → Bool) (h : ByteArray)
    (hf : failedCache h = true) :
    submitVerdictWith validate1 failedCache h =
      submitVerdictWith validate2 failedCache h := by
  rw [submitVerdictWith_cached_skips_validation validate1 failedCache h hf,
      submitVerdictWith_cached_skips_validation validate2 failedCache h hf]

/-! ## L3 axiom pins (D2): drift on any of these fails the build.
Both rule-theorems sorry-free; pin-sets (PDW8-2 probe pass):
duplicate_invalid_iff [propext], none_iff [propext] (the
`unfold`/`rw`/`simp [hc]`-herd + `simp at hv` contra route); the 4
private lemmas (true/false/_true_inv/_false_inv, probe pass) all
[propext] too. Every pin ⊆ [propext, Classical.choice, Quot.sound] =
the charter trio; zero `sorryAx` (sorry_lint G1 class). -/

/-- info: 'BitcoinProofs.AF.PDW8.submitVerdict_duplicate_invalid_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW8.submitVerdict_duplicate_invalid_iff

/-- info: 'BitcoinProofs.AF.PDW8.submitVerdict_none_iff' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW8.submitVerdict_none_iff

end BitcoinProofs.AF.PDW8
