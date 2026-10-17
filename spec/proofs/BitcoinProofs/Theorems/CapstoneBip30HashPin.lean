import Bitcoin.Ledger.Interface

/-!
# CapstoneBip30HashPin — D2b/D2c hash pins (BIP30R-5, F-S04-002/003)

Core validation.cpp @cce32b168:
* 2401/6205-6210 `IsBIP30Repeat(pindex)` pins {91842, 91880} by height
  AND the block's OWN hash (D2c). A fork block at 91842/91880 is NOT a
  repeat — BIP30 stays enforced there.
* 2458-2461 clears `fEnforceBIP30` in the BIP34 window only when the
  ancestor at BIP34Height exists and its hash == BIP34Hash (D2b). A
  non-canonical ancestor inside 227932..1983701 re-enables the loop.
* 2466 the loop runs iff `fEnforceBIP30 || h >= 1983702`.

`Bitcoin.Ledger.bip30EnforcedAt` models the hash-context gate;
`bip30Enforced` is its canonical-chain specialization
(`bip30EnforcedAt_canonical`, proved beside the def). The witnesses
below pin both divergences that the heights-only predicate alone cannot
express, so D2b/D2c are MODELED, not merely documented.
-/

open Bitcoin.Ledger
open Bitcoin.Ledger (bip30Enforced bip30EnforcedAt)

/-- D2c @91842: a fork block at 91842 (own hash != the pinned repeat
hash) has BIP30 ENFORCED; the heights-only predicate wrongly elides it. -/
theorem bip30EnforcedAt_fork_91842 :
    bip30EnforcedAt 91842 false false = true ∧ bip30Enforced 91842 = false := by
  decide

/-- D2c @91880: same own-hash pin for the second repeat block. -/
theorem bip30EnforcedAt_fork_91880 :
    bip30EnforcedAt 91880 false false = true ∧ bip30Enforced 91880 = false := by
  decide

/-- D2c positive face: the canonical hash-pinned repeats stay elided. -/
theorem bip30EnforcedAt_canonical_repeats :
    bip30EnforcedAt 91842 true false = false ∧
      bip30EnforcedAt 91880 true false = false := by
  decide

/-- D2b @227932 (first window height): a non-canonical ancestor at
BIP34Height re-enables the loop; the canonical ancestor elides it and the
heights-only predicate agrees with the canonical face. -/
theorem bip30EnforcedAt_window_227932 :
    bip30EnforcedAt 227932 false false = true ∧
      bip30EnforcedAt 227932 false true = false ∧
      bip30Enforced 227932 = false := by
  decide

/-- D2b @1983701 (last window height): same fork/canonical split. -/
theorem bip30EnforcedAt_window_1983701 :
    bip30EnforcedAt 1983701 false false = true ∧
      bip30EnforcedAt 1983701 false true = false ∧
      bip30Enforced 1983701 = false := by
  decide

/-- Below the window the hash context is vacuous (null ancestor): both
faces enforce, matching Core 2461. -/
theorem bip30EnforcedAt_below_window :
    bip30EnforcedAt 227931 false false = true ∧
      bip30EnforcedAt 227931 false true = true := by
  decide

/-- Above/at the limit the loop runs wholesale (Core 2466 second
disjunct), regardless of the ancestor hash. -/
theorem bip30EnforcedAt_limit_on :
    bip30EnforcedAt 1983702 false false = true ∧
      bip30EnforcedAt 1983702 false true = true := by
  decide

/-! ## Hash-typed witnesses (FIX-B30PINS)

`bip30EnforcedAtHashes` discharges the pins from the ACTUAL own hash and
ancestor hash (Core `IsBIP30Repeat` pins and `BIP34Hash`). The fork rows
below are the three L2-ACT divergences: with a non-pinned own hash /
ancestor hash the loop is ENFORCED; the canonical hash controls elide. -/

/-- D2c @91842: a fork block (own hash 0 ≠ the pinned repeat hash) is
enforced, while the canonical own hash elides. -/
theorem bip30EnforcedAtHashes_fork_91842 :
    bip30EnforcedAtHashes 91842 0 0 = true ∧
      bip30EnforcedAtHashes 91842 BIP30_REPEAT_HASH_91842 BIP34_ACTIVATION_HASH = false := by
  decide

/-- D2c @91880: same own-hash pin. -/
theorem bip30EnforcedAtHashes_fork_91880 :
    bip30EnforcedAtHashes 91880 0 0 = true ∧
      bip30EnforcedAtHashes 91880 BIP30_REPEAT_HASH_91880 BIP34_ACTIVATION_HASH = false := by
  decide

/-- D2b @227932 (first window height): a non-canonical ancestor (0 ≠
`BIP34Hash`) re-enables the loop; `BIP34Hash` elides it. -/
theorem bip30EnforcedAtHashes_window_227932 :
    bip30EnforcedAtHashes 227932 0 0 = true ∧
      bip30EnforcedAtHashes 227932 0 BIP34_ACTIVATION_HASH = false := by
  decide

/-- D2b @1983701 (last window height): same ancestor-hash split. -/
theorem bip30EnforcedAtHashes_window_1983701 :
    bip30EnforcedAtHashes 1983701 0 0 = true ∧
      bip30EnforcedAtHashes 1983701 0 BIP34_ACTIVATION_HASH = false := by
  decide

/-- Below/at the window the ancestor hash is irrelevant; at/above the
limit the loop runs wholesale (Core 2466 second disjunct). -/
theorem bip30EnforcedAtHashes_below_and_limit :
    bip30EnforcedAtHashes 227931 0 0 = true ∧
      bip30EnforcedAtHashes 1983702 0 0 = true := by
  decide
