import Bitcoin.Block.Pow
import Bitcoin.Block.Params
import Bitcoin.Block.Connect
import Bitcoin.Capstone.Block
import Bitcoin.Ledger.Interface
import Bitcoin.Activation.Flags

/-!
# Bitcoin.Invariants.RC09 — INV-097..INV-108 closure (RC09)

B1's acceptance-spine invariant rows for the block-context lane
(research/05-core-inventory.md §B.8, `ContextualCheckBlockHeader` /
`ContextualCheckBlock` @cce32b168). Inspection found every one of these
behaviors already implemented under a BLK id by the block-validation module and the ledger; this file

1. documents the aliasing: the `@[rule "INV-xxx"]` attributes are
   comma-stacked in-place on the owning declarations (attribute-only
   edits to committed, stable files; no semantics touched), and
2. adds the sorry-free pins + vectors that make the alias honest:
   each INV id is the invariant reading of a check that already carries
   its BLK id.

Mapping (INV row → implementing declaration):

* INV-097 → `Pow.calculateNextWorkRequired` (BLK-044..049): new target =
  old·actual/T truncated, actual clamped [T/4,4T], capped by powLimit.
* INV-098 → `Pow.permittedDifficultyTransition` (BLK-050..052).
* INV-099 → `Pow.timeNotTooOld` ∘ `Pow.medianTimePast` (BLK-056/057).
* INV-100 → `Pow.timewarpOk` (BLK-055): BIP94 timewarp guard, active
  only under `enforce_BIP94` (testnet4/regtest; mainnet off).
* INV-101 → `Pow.timeNotTooNew` (BLK-058): the env clock `now` is an
  explicit parameter — the impurity is the argument, not the definition.
* INV-102 → `Capstone.Block.versionOk` (BLK-060..062): ≥4/≥3/≥2 gates.
* INV-103 → `Capstone.Block.bip34Ok` (BLK-069): coinbase scriptSig
  begins with minimal `CScriptNum(height)`.
* INV-104 → `Ledger.bip30Enforced` + `Ledger.bip30Collision`
  (BLK-096..098): no overwriting an existing UTXO, conditionally
  enforced.
* INV-105 → `Block.Params.bip30DisconnectRelaxed` (BLK-099): the
  91722/91812 historical carve-out pair.
* INV-106 → NEW below (`bip30OptimizationWindow` + `bip34Anchored`):
  the BIP34⇒BIP30 precondition — block@BIP34Height is `BIP34Hash` —
  plus the 1,983,702 re-enable limit.
* INV-107 → `Block.Connect.connectGenesis` (BLK-109): genesis connects
  with no tx fold.
* INV-108 → `Block.Connect.blockSequenceLocksOk` (BLK-104): BIP68
  sequence locks run in-block only when the CSV flag is active.
-/

namespace Bitcoin.Invariants.RC09

/-! ## Route A: attribute aliases (applied in-place on the owning decls;
see the mapping in the module docstring) -/

/-! ## INV-106 (route B): the BIP34 ⇒ BIP30 optimization window

Core skips the BIP30 duplicate check for `BIP34Height < h <
BIP34_IMPLIES_BIP30_LIMIT` (validation.cpp:2429 + the 2458–2466 comment
pair): inside the window BIP34's height-in-coinbase makes duplicate
txids impossible by construction, and from 1,983,702 the check is
re-enabled wholesale (`BIP34_IMPLIES_BIP30_LIMIT`). The precondition
that makes the optimization sound is the chain-level pin that the block
at `BIP34Height` really is Core's `BIP34Hash`
(kernel/chainparams.cpp:119 = BLK-070 constant).

FIX D2a (the 2026-10-17 repair; was `BIP34_HEIGHT ≤ height`, i.e. the
elide-window [227931, 1983702)): Core @cce32b168 validation.cpp:2458-2461
computes `pindexBIP34height = pindex->pprev->GetAncestor(BIP34Height)` —
on the height-227930 parent this is null, so 2461's second conjunct is
VACUOUS at h = 227931 and Core ENFORCES BIP30 there (the 2466 loop gate
`fEnforceBIP30 || h ≥ 1983702` is ON). The skip window proper is
(227931, 1983702) — CV07 D2a; the window here
now matches the fixed `bip30Enforced`'s negated window conjunct
exactly (heights-only; the D2b hash-pin and D2c own-hash-pin remain
documented divergences). -/

/-- The window inside which BIP30 enforcement is elided. -/
@[rule "INV-106"] def bip30OptimizationWindow (height : UInt32) : Bool :=
  Bitcoin.Ledger.BIP34_HEIGHT < height && height < Bitcoin.Ledger.BIP34_IMPLIES_BIP30_LIMIT

/-- The chain-level precondition: the block at `BIP34Height` carries
Core's `BIP34Hash`. -/
@[rule "INV-106"] def bip34Anchored (hashAtBip34Height : Bitcoin.Activation.BlockHash) : Bool :=
  hashAtBip34Height = Bitcoin.Activation.bip34ActivationHash

/-- Mainnet satisfies the anchor precondition (BLK-070's constant). -/
theorem inv106_mainnet_anchor :
    bip34Anchored Bitcoin.Activation.bip34ActivationHash = true := rfl

/-- The frozen constants: BIP34Height = 227,931; re-enable limit =
1,983,702. -/
theorem inv106_constants :
    Bitcoin.Ledger.BIP34_HEIGHT = 227931 ∧
    Bitcoin.Ledger.BIP34_IMPLIES_BIP30_LIMIT = 1983702 := ⟨rfl, rfl⟩

/-- Inside the optimization window BIP30 enforcement is OFF — the
`bip30Enforced` BIP34-window conjunct is exactly the negated window
(post-D2a-fix: both are `BIP34_HEIGHT < height`). -/
theorem inv106_window_disables_bip30 (height : UInt32)
    (hw : bip30OptimizationWindow height = true) :
    Bitcoin.Ledger.bip30Enforced height = false := by
  unfold Bitcoin.Ledger.bip30Enforced
  rw [show (Bitcoin.Ledger.BIP34_HEIGHT < height &&
        height < Bitcoin.Ledger.BIP34_IMPLIES_BIP30_LIMIT) = true from hw,
      Bool.not_true, Bool.and_false]

/-! ## Boundary pins for the aliased gates (VERIFIED, decide/rfl) -/

/-- INV-099 boundary: MTP itself is *too old* (strictly-greater check). -/
theorem inv099_boundary :
    Bitcoin.Block.Pow.timeNotTooOld 100 100 = false ∧
    Bitcoin.Block.Pow.timeNotTooOld 101 100 = true := ⟨rfl, rfl⟩

/-- INV-100: mainnet (`enforce = false`) never rejects; testnet4
boundary = prev − 600 exactly. -/
theorem inv100_pin :
    Bitcoin.Block.Pow.timewarpOk false true 99 700 = true ∧
    Bitcoin.Block.Pow.timewarpOk true true 700 700 = true ∧
    Bitcoin.Block.Pow.timewarpOk true true 99 700 = false := ⟨rfl, rfl, rfl⟩

/-- INV-101 boundary: `now + 7200` inclusive (MAX_FUTURE_BLOCK_TIME). -/
theorem inv101_pin :
    Bitcoin.Block.Pow.timeNotTooNew 1284007200 1284000000 = true ∧
    Bitcoin.Block.Pow.timeNotTooNew 1284007201 1284000000 = false := ⟨rfl, rfl⟩

/-- INV-102 boundary: version gates bite exactly at the buried heights. -/
theorem inv102_pin :
    Bitcoin.Capstone.Block.versionOk 227930 1 = true ∧
    Bitcoin.Capstone.Block.versionOk 227931 1 = false ∧
    Bitcoin.Capstone.Block.versionOk 227931 2 = true := ⟨rfl, rfl, rfl⟩

/-- INV-108: with CSV inactive the BIP68 sequence-lock gate is vacuous
(`nLockTimeFlags = 0` — every tx passes). -/
theorem inv108_gate_off (txs : List Bitcoin.Data.Tx)
    (prevDataOf : Bitcoin.Data.Tx → List (Int × Int)) (bh bm : Int) :
    Bitcoin.Block.Connect.blockSequenceLocksOk txs false prevDataOf bh bm = true := by
  simp [Bitcoin.Block.Connect.blockSequenceLocksOk]

/-! ## Vectors

The BIP30 enforcement table below was cross-checked against an
independent python3 evaluation of Core's predicate
`not (h in {91842, 91880}) and not (227931 < h < 1983702)` over the
same 8 boundary heights.

FIX D2a (the 2026-10-17 repair): the window conjunct was
`227931 <= h < 1983702` (pre-fix table `[true, true, false, false,
true, false, false, true]` — 227931 elided). Core @cce32b168
validation.cpp:2458-2461 computes `pindexBIP34height =
pindex->pprev->GetAncestor(BIP34Height)` — null on the height-227930
parent, so 2461's second conjunct is vacuous at h = 227931 and the
2466 loop gate (`fEnforceBIP30 || h ≥ 1983702`) is ON: Core ENFORCES
BIP30 at 227931 (CV07 D2a). The 227931 row
flips false → true; skip window proper (227931, 1983702). -/

-- python3-cross-checked enforce table (Core: not IsBIP30Repeat ∧ outside BIP34 window proper):
/-- info: [true, true, false, false, true, true, false, true] -/
#guard_msgs in
#eval [91722, 91812, 91842, 91880, 227930, 227931, 1983701, 1983702].map
  (fun h => Bitcoin.Ledger.bip30Enforced (h : UInt32))

-- python3 cross-check: minimal CScriptNum(227931) push = 03 5B 7A 03
/-- info: [3, 91, 122, 3] -/
#guard_msgs in
#eval (Bitcoin.Capstone.Block.cbHeightPush 227931).toList

/-! ## Axiom footprints -/

#print axioms inv106_mainnet_anchor
#print axioms inv106_constants
#print axioms inv106_window_disables_bip30
#print axioms inv099_boundary
#print axioms inv100_pin
#print axioms inv101_pin
#print axioms inv102_pin
#print axioms inv108_gate_off

end Bitcoin.Invariants.RC09
