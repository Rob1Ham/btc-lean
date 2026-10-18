import Bitcoin.Ledger.Interface
import Bitcoin.Block.Params
import Bitcoin.TxValidation.Interface
import Bitcoin.Activation.Flags

/-!
# Z05 dark-corner audit — BIP30 duplicate txids + coin height/coinbase-bit encoding

2026-10-16. Python3 probes:
`z05_c1_bip30_probe.py`,
`z05_c2_coincode_probe.py`).

Ground truth: Bitcoin Core @ `cce32b1682d86076ee71c10f9788c48d44458a263`
(validation.cpp:2401-2471 + 6207-6211; coins.h:52-87), fetched and read
directly during this audit.

## C1 — BIP30 duplicate txids (blocks 91842/91880 + limit 1,983,702)

The tree captures the height lattice (`Bitcoin.Ledger.bip30Enforced`,
`BIP30_DUPLICATE_COINBASE_HEIGHTS`, `BIP34_IMPLIES_BIP30_LIMIT`) and the
disconnect pair (`Bitcoin.Block.Params.bip30DisconnectRelaxed`). Two
divergences from Core are pinned below:

1. **h = 227931 off-by-one** (F-Z05-001): Core's skip requires the chain's
   ancestor at `BIP34Height` to *exist* (`pindex->pprev->GetAncestor(227931)`,
   validation.cpp:2462) — for the block at height 227931 itself that ancestor
   lookup is null, so Core still ENFORCES BIP30 there. Lean's window
   `BIP34_HEIGHT ≤ h` started the skip one block early.
   **FIXED by the RC SWEEP** (Interface.lean `BIP34_HEIGHT ≤ h` → `< h`,
   the D2a fix = F-S04-001 / CV07 D2a / X11 FIND-X11-004 / CT02 V2):
   `divergence_227931` below is now repaired to the AGREEMENT pin
   (both sides run at 227931) — the divergence statement is preserved
   in history (F-Z05-001).
2. **Hash-pin layer absent from the connect gate** (F-Z05-002): Core's
   `IsBIP30Repeat` also matches the block's OWN hash (6207-6211) and the skip
   is conditional on the chain block@227931 being `BIP34Hash`;
   `bip30Enforced` is height-only (abstraction documented at
   Ledger/Interface.lean:336-337; INV-106 keeps `bip34Anchored` separate but
   never composes it into the connect gate).

## C2 — fCoinBase bit packed into the coin height (not negative-height)

CAPTURED: `Bitcoin.TxValidation.packCoinCode` / `coinHeightOfCode` /
`coinIsCoinbaseOfCode` (TXV-022, roundtrip theorems on the 31-bit domain)
+ the `MEMPOOL_HEIGHT = 0x7FFFFFFF` sentinel (INV-118, TXV-042). The
"(not negative-height)" half is structural: `Coin.height` is an unsigned
`UInt32` (Ledger/Utxo.lean BLK-101) — no negative sentinel exists anywhere,
matching current Core (report 07 §14: negative-height is a pre-0.15 relic).
-/

namespace BitcoinProofs.Audit.Z05

open Bitcoin.Ledger Bitcoin.Block.Params Bitcoin.TxValidation
     Bitcoin.Activation

/-! ## C1: Core's predicate, transcribed verbatim -/

/-- validation.cpp:6207-6211 `IsBIP30Repeat` — height AND the block's own
hash (both hex constants read from Core @ cce32b1682d). -/
def coreIsBIP30Repeat (h : UInt32) (ownHash : String) : Bool :=
  (h.toNat = 91842 && ownHash ==
    "00000000000a4d0a398161ffc163c503763b1f4360639393e0e4c8e300e0caec") ||
  (h.toNat = 91880 && ownHash ==
    "00000000000743f190a18c5577a3c2d2a1f610ae9601ac046a38084ccb7cd721")

/-- The four historical constants are full-width 256-bit hashes (hex = 64):
91842/91880 (repeat pair) and 91722/91812 (disconnect pair). -/
theorem core_repeat_hash_len :
    ("00000000000a4d0a398161ffc163c503763b1f4360639393e0e4c8e300e0caec".length = 64) ∧
    ("00000000000743f190a18c5577a3c2d2a1f610ae9601ac046a38084ccb7cd721".length = 64) ∧
    ("00000000000271a2dc26e7667f8419f2e15416dc6955e5a6c6cdf3f2574dd08e".length = 64) ∧
    ("00000000000af0aed4792b1acee3d966af36cf5def14935db8de83d6f9306f2f".length = 64) :=
  by decide

/-- validation.cpp:2462-2464 skip precondition on the CANONICAL chain: the
chain's ancestor at `BIP34Height` exists and is `BIP34Hash` iff `227931 < h`
(for the block at 227931 itself, `pprev->GetAncestor(227931)` on its
height-227930 parent is null). -/
def coreBip34PinHoldsCanonical (h : UInt32) : Bool :=
  Bitcoin.Ledger.BIP34_HEIGHT.toNat < h.toNat

/-- validation.cpp:2401-2471, canonical chain: the BIP30 duplicate check
runs iff `(!IsBIP30Repeat && !pin) || h ≥ 1983702`. -/
def coreBip30RunsCanonical (h : UInt32) (ownHash : String) : Bool :=
  (!coreIsBIP30Repeat h ownHash && !coreBip34PinHoldsCanonical h) ||
    (1983702 ≤ h.toNat)

/-- Lean's gate (Ledger/Interface.lean:354-356). -/
def leanBip30Runs (h : UInt32) : Bool := Bitcoin.Ledger.bip30Enforced h

/-- Decisive case 1 — block 91842's duplicate coinbase (own hash matches
the historical constant): Core ACCEPTS (repeat exception), Lean ACCEPTS. -/
theorem repeat_91842_agree :
    coreBip30RunsCanonical 91842
      "00000000000a4d0a398161ffc163c503763b1f4360639393e0e4c8e300e0caec" = false ∧
    leanBip30Runs 91842 = false := by decide

/-- Decisive case 2 — block 91880's duplicate coinbase: both ACCEPT. -/
theorem repeat_91880_agree :
    coreBip30RunsCanonical 91880
      "00000000000743f190a18c5577a3c2d2a1f610ae9601ac046a38084ccb7cd721" = false ∧
    leanBip30Runs 91880 = false := by decide

/-- Pre-BIP34 neighbors enforce on BOTH models (the repeat exception is
height-exact, not a range). -/
theorem pre_bip34_neighbors_agree :
    (leanBip30Runs 91841 = true ∧ leanBip30Runs 91843 = true ∧
     leanBip30Runs 91882 = true) ∧
    (coreBip30RunsCanonical 91841 "x" = true ∧
     coreBip30RunsCanonical 91843 "x" = true ∧
     coreBip30RunsCanonical 91882 "x" = true) := by decide

/-- F-Z05-001 (D2a), FIXED by the RC SWEEP (Interface.lean
`BIP34_HEIGHT ≤ h` → `< h`): at h = 227931 itself Core's ancestor lookup
is null ⇒ the check RUNS, and `leanBip30Runs` now agrees (both true).
HISTORY (pre-fix divergence): `coreBip30RunsCanonical 227931 "x" = true ∧
leanBip30Runs 227931 = false` — pinned 2026-10-16 (F-Z05-001),
cross-confirmed by S04 F-S04-001 / CV07 D2a / X11 FIND-X11-004 /
CT02 V2, and fixed by the RC SWEEP 2026-10-17. -/
theorem divergence_227931 :
    coreBip30RunsCanonical 227931 "x" = true ∧
    leanBip30Runs 227931 = true := by decide

/-- Agreement holds through the whole skip window proper (227932..1983701)
and at the 1,983,702 re-enable boundary (post-D2a-fix: agreement
everywhere on the canonical chain; see `divergence_227931` above). -/
theorem window_boundaries_agree :
    (coreBip30RunsCanonical 227932 "x" = false ∧ leanBip30Runs 227932 = false) ∧
    (coreBip30RunsCanonical 1983701 "x" = false ∧ leanBip30Runs 1983701 = false) ∧
    (coreBip30RunsCanonical 1983702 "x" = true ∧ leanBip30Runs 1983702 = true) :=
  by decide

/-- F-Z05-002: the repeat exception is HEIGHT-only in Lean — a fork block
at height 91842 with a different hash still gets the exemption, while
Core's `IsBIP30Repeat` (own-hash conjunct) would ENFORCE. -/
theorem divergence_fork_91842 :
    coreBip30RunsCanonical 91842 "forkhash" = true ∧
    leanBip30Runs 91842 = false := by decide

/-- The two constants of F-Z05-002's missing pin layer DO exist in-tree
(`BIP30_DUPLICATE_COINBASE_HEIGHTS`, BLK-070's `bip34ActivationHash`) but
`bip30Enforced` consumes only the heights. -/
theorem pin_constants_present :
    Bitcoin.Ledger.BIP30_DUPLICATE_COINBASE_HEIGHTS = [91842, 91880] ∧
    (bip34ActivationHash =
      0x000000000000024b89b42a942fe0d9fea3bb44ab7bd1b19115dd6a759c0808b8) :=
  ⟨rfl, rfl⟩

/-- Disconnect pair (BLK-099): heights captured, hashes likewise absent
from the predicate (`bip30DisconnectRelaxed` is height-only; Core's
`IsBIP30Unspendable` :6213-6218 checks both). -/
theorem disconnect_pair :
    (bip30DisconnectRelaxed 91722 = true ∧ bip30DisconnectRelaxed 91812 = true ∧
     bip30DisconnectRelaxed 91723 = false) ∧
    ("00000000000271a2dc26e7667f8419f2e15416dc6955e5a6c6cdf3f2574dd08e".length = 64 ∧
     "00000000000af0aed4792b1acee3d966af36cf5def14935db8de83d6f9306f2f".length = 64) :=
  ⟨⟨rfl, rfl, rfl⟩, by decide⟩

/-! ## C2: the coin code packing -/

/-- Decisive bytes: coinbase coin at height 900000 packs to code 1800001;
Core serializes it to disk as VARINT(1800001) = C1 EE 6D (probe output). -/
theorem coincode_900000_cb :
    packCoinCode 900000 true = 1800001 ∧
    coinHeightOfCode 1800001 = 900000 ∧
    coinIsCoinbaseOfCode 1800001 = true := ⟨rfl, rfl, rfl⟩

/-- Non-coinbase twin: LSB clear. -/
theorem coincode_900000_plain :
    packCoinCode 900000 false = 1800000 ∧
    coinIsCoinbaseOfCode 1800000 = false := ⟨rfl, rfl⟩

/-- The sentinel height is EXACTLY the 31-bit max — `MEMPOOL_HEIGHT`
(0x7FFFFFFF) roundtrips through the pack and is expressible as a real
`Coin.height` (unsigned, no negative marker). -/
theorem coincode_sentinel :
    Bitcoin.Ledger.MEMPOOL_HEIGHT = 0x7FFFFFFF ∧
    Bitcoin.Ledger.MEMPOOL_HEIGHT.toNat = 2147483647 ∧
    coinHeightOfCode (packCoinCode 2147483647 true) = 2147483647 ∧
    coinIsCoinbaseOfCode (packCoinCode 2147483647 false) = false :=
  ⟨rfl, rfl, rfl, rfl⟩

/-- The existing TXV-022 roundtrip theorem applies at the sentinel: its
31-bit hypothesis (`h < 2^31`) admits `2147483647` with one decide. -/
theorem txv022_at_sentinel :
    coinHeightOfCode (packCoinCode 2147483647 true) = 2147483647 := by
  exact Bitcoin.TxValidation.coinHeightOfCode_pack 2147483647 true (by decide)

/-- The sentinel cannot collide with a real height: mainnet heights are
≤ the current tip (≈ 9·10^5), orders of magnitude below 2^31 − 1 — the
RC10 INV-118 formulation (`prevHeightOrNext`). -/
theorem sentinel_above_reachable :
    (900000 : UInt32).toNat < Bitcoin.Ledger.MEMPOOL_HEIGHT.toNat := by decide

end BitcoinProofs.Audit.Z05
