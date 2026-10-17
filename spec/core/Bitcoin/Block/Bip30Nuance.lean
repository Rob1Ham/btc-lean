import Bitcoin.Ledger.Interface
import Bitcoin.Block.Params
import Bitcoin.Invariants.RC09
import Bitcoin.Activation.Flags

/-! # S04 / BLK-011 — the mutated-flag row's BIP30-enforcement nuance

`Bitcoin.Block.Bip30Nuance` (NEW file, core pkg). Landing row BLK-011:
Core's ACTUAL BIP30 enforcement conditions (validation.cpp
`ContextualCheckBlock`, Bitcoin Core @cce32b168) vs the BIP34-era
heights-only simplification in the spec's `bip30Enforced`
(`Bitcoin.Ledger.Interface`, rows BLK-096/097/098/INV-104).

BlkPkgNaming (S16) compliance: file = Block/, model = Block, rule =
BLK-011. CT02 line-pins cited per definition.

## Summary
* **F-S04-001 (D2a)** Core 2461's `pindexBIP34height` is null at
  h=227931 (`pprev->GetAncestor(BIP34Height)` on the height-227930
  parent) — Core ENFORCES. **FIXED (RC SWEEP 2026-10-17):** ours'
  elide-window was `[227931, 1983702)`, repaired in
  `Bitcoin.Ledger.bip30Enforced` (Interface.lean `BIP34_HEIGHT ≤ h` →
  `< h`) to the window proper `(227931, 1983702)` — ours now ENFORCES
  at 227931 = Core (see `s04_divergence_core_vs_ours` row 1, now the
  agreement pin). HISTORY (pre-fix, pinned 2026-10-16): ours' elide
  window didn't — the one mainnet divergence.
* **F-S04-002 (D2b)** 227932..1983701 non-canonical-branch (ancestor
  at 227931 ≠ BIP34Hash): Core enforces, ours elides
  (bip30Enforced heights-only) — REMAINS a divergence (D2a fixed,
  D2b documented-not-fixed).
* **F-S04-003 (D2c)** `IsBIP30Repeat` (2401/6205-6210) pins heights
  91842/91880 AND own-hash; ours pins heights only
  (BIP30_DUPLICATE_COINBASE_HEIGHTS) (D2c).
* **F-S04-004 (D4c)** Core 2466-2475 runs the overlap loop on the
  PRISTINE pre-block view, block-pre, unfiltered over vout; ours'
  `bip30Collision` runs per-tx on the EVOLVING fold view, over
  `addedCoins` (unspendable-skipped) — the D4c wrong-accept.
* **F-S04-005 (D4a)** Core rejects duplicate txids (CheckTxInputs,
  2466-2475) vs ours' badTxnsBIP30 (error-kind mismatch).
* **F-S04-006 (D4c)** Core rejects block `[A,B,C]` (B re-creates A's
  spent outpoint x) via 2466-2475 as bad-txns-BIP30; ours'
  applyBlockL accepts (D4c).
* **F-S04-007** multi-site `@[rule]` tags (X08's
  Connect.levelHasAdjacentDup + S04's decls) — RCR tag-hygiene lane.

Statements: Eq Bool / Eq Nat ONLY (never Eq ByteArray / Option /
Except) — the Y10 F-Y10-005 wall (Eq ByteArray/decEq-STUCK) applies
only to `decide (x = y)`-Prop forms, NOT the Eq-Bool idiom.
NO Bitcoin.Consensus.TxCheck import (it shadows OutPoint/Tx/serTx).
Z05 (spec/proofs/BitcoinProofs/Audit/Z05) already lands
coreIsBIP30Repeat/coreBip30RunsCanonical/divergence_227931/divergence_f
ork_91842 — S04 must NOT duplicate Z05's names (this file = core pkg,
new decls, BLK-011 row-landing).
Z05 pins D2a + D2c(91842) only; D2b + D2c(91880) + D4c/D4a pins are
S04's new era rows (CV07 nomenclature). [RC SWEEP 2026-10-17: Z05's
`divergence_227931` repaired to the D2a-fix agreement pin (HISTORY in
its docstring); D2a statements in THIS file repaired likewise — see
`s04_ours_heights_only_window`, `s04_divergence_core_vs_ours`,
`s04_d4d_coinbase_twin_eras`.] -/

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Activation Bitcoin.Block.Params Bitcoin.Invariants.RC09

set_option maxRecDepth 4000
set_option maxHeartbeats 800000

namespace Bitcoin.Block.Bip30Nuance

/-! ## §A: Core constants (validation.cpp @cce32b168, CT02 line-pins) -/

/-- CT02 V2: BIP34 activation hash (kernel/chainparams.cpp:119 =
W06's BLK-070 constant). Height 227931. Same 256-bit Nat pin as
`Bitcoin.Activation.bip34ActivationHash`. -/
def BIP34_ACTIVATION_HASH : Nat :=
  0x000000000000024b89b42a942fe0d9fea3bb44ab7bd1b19115dd6a759c0808b8

/-- 2401/6205-6210: `IsBIP30Repeat(*pindex)` = repeat pair
{91842, 91880} height-AND-hash-pinned. -/
def BIP30_REPEAT_HASH_91842 : String :=
  "00000000000a4d0a398161ffc163c503763b1f4360639393e0e4c8e300e0caec"
def BIP30_REPEAT_HASH_91880 : String :=
  "00000000000743f190a18c5577a3c2d2a1f610ae9601ac046a38084ccb7cd721"

/-- 2200-2212/6213-6218: DisconnectBlock's inline disconnect pair
{91722, 91812} (height-AND-hash) + `IsBIP30Unspendable`
(coinstatsindex-only). -/
def BIP30_UNSPENDABLE_HASH_91722 : String :=
  "00000000000271a2dc26e7667f8419f2e15416dc6955e5a6c6cdf3f2574dd08e"
def BIP30_UNSPENDABLE_HASH_91812 : String :=
  "00000000000af0aed4792b1acee3d966af36cf5def14935db8de83d6f9306f2f"

/-- 2462 (CT02): Core BIP34 activation height = BIP34Height = 227931
(= `Bitcoin.Ledger.BIP34_HEIGHT`). -/
def BIP34_HEIGHT : Nat := 227931

/-- 2429 (CT02): BIP34_IMPLIES_BIP30_LIMIT = 1983702. -/
def BIP34_IMPLIES_BIP30_LIMIT : Nat := 1983702

/-- 2200-2212 (CT02): DisconnectBlock's inline disconnect-pair check
(height-AND-hash), relaxing BIP30 for coinbases (2208:
`is_bip30_exception = is_coinbase && !fEnforceBIP30`). -/
@[rule "BLK-011"]
def isBip30UnspendableInline (h : Nat) (ownHash : String) : Bool :=
  (h = 91722 && ownHash == BIP30_UNSPENDABLE_HASH_91722) ||
  (h = 91812 && ownHash == BIP30_UNSPENDABLE_HASH_91812)

/-- 6205-6210 (CT02): `IsBIP30Repeat(*pindex)` = repeat pair
{91842, 91880} height-AND-own-hash-pinned (D2c) — Core's
`fEnforceBIP30 = !IsBIP30Repeat(*pindex)` (2401) turns BIP30 OFF
only for these two hash-pinned blocks. -/
@[rule "BLK-011"]
def isBip30Repeat (h : Nat) (ownHash : String) : Bool :=
  (h = 91842 && ownHash == BIP30_REPEAT_HASH_91842) ||
  (h = 91880 && ownHash == BIP30_REPEAT_HASH_91880)

/-- 2460-2461 (CT02): `pindexBIP34height =
pindex->pprev->GetAncestor(BIP34Height)` — null iff pprev.height <
227931 iff h ≤ 227931 (at h = 227931 itself, the height-227930
parent's GetAncestor(227931) is null); non-null AND
`pindexBIP34height->GetBlockHash() == BIP34Hash` (2461) ⇒ fEnforceBIP30
elided (BIP34 implies BIP30). Model: the null case as the height-guard
`BIP34_HEIGHT < h` (D2a: 2461's second conjunct is vacuous at h =
227931 — `pprev->GetAncestor(227931)` on the height-227930 parent),
the hash case as `hashAtBip34Height == BIP34_ACTIVATION_HASH`
(2461: `fEnforceBIP30 &&= (!pindexBIP34height ||
!(pindexBIP34height->GetBlockHash() == BIP34Hash))`). -/
@[rule "BLK-011"]
def bip34PinHolds (h : Nat) (hashAtBip34Height : Nat) : Bool :=
  BIP34_HEIGHT < h && hashAtBip34Height == BIP34_ACTIVATION_HASH

/-- 2401 + 2461 (CT02): `fEnforceBIP30 = !IsBIP30Repeat(*pindex) &&
!bip34PinHolds(h, hashAtBip34Height)`. At h = 227931 (D2a):
pindexBIP34height = null ⇒ 2461 vacuous ⇒ fEnforceBIP30 =
!IsBIP30Repeat(227931) = true (Core ENFORCES; ours now agrees
post-D2a-fix — HISTORY pre-fix: ours' elide-window [227931, 1983702)
didn't). -/
@[rule "BLK-011"]
def coreBip30Enforced (h : Nat) (ownHash : String) (hashAtBip34Height : Nat) : Bool :=
  !isBip30Repeat h ownHash && !bip34PinHolds h hashAtBip34Height

/-- 2466 (CT02): `if (fEnforceBIP30 || nHeight >=
BIP34_IMPLIES_BIP30_LIMIT)` — the bad-txns-BIP30 overlap loop
(2467-2475) runs iff coreBip30Enforced OR h ≥ 1983702. -/
@[rule "BLK-011"]
def coreBip30LoopRuns (h : Nat) (ownHash : String) (hashAtBip34Height : Nat) : Bool :=
  coreBip30Enforced h ownHash hashAtBip34Height || BIP34_IMPLIES_BIP30_LIMIT ≤ h

private def cvK (v : UInt8) : ByteArray :=
  (List.replicate 32 v).foldl (fun acc b => acc.push b) ByteArray.empty
private def cvOp (v : UInt8) (n : UInt32) : OutPoint := ⟨cvK v, n⟩
private def cvIn (o : OutPoint) : TxIn := ⟨o, Script.empty, 0xFFFFFFFF⟩
private def cvOut (v : Amount) : TxOut := ⟨v, scriptOf [0x51]⟩

private def txX : Tx :=
  { version := 1, vin := [cvIn (cvOp 0xE5 0)], vout := [cvOut 50000000],
    locktime := 0, witness := [] }
private def xk : OutPoint := ⟨serTx txX, 0⟩
private def txA : Tx :=
  { version := 1, vin := [cvIn xk], vout := [cvOut 1000000],
    locktime := 0, witness := [] }
private def txC : Tx :=
  { version := 1, vin := [cvIn xk], vout := [cvOut 2],
    locktime := 0, witness := [] }
private def u0 : List (OutPoint × Coin) :=
  [ (xk, ⟨50000000, 100, false, scriptOf [0x51]⟩),
    (cvOp 0xE5 0, ⟨90000000, 100, false, scriptOf [0x51]⟩) ]
private def d4cBlock : List Tx := [txA, txX, txC]

-- P1: serTx reduces; sizes found empirically (Eq Nat)

-- P2: coinLookup over the SERTX key (Eq Bool)

-- P3: isCoinBase / bip30Collision (Eq Bool)

-- P4: applyTxStepL / applyBlockL (Eq Bool)

-- P4b: Except -> constructor-kind Bool (never Except-Eq!)
private def isBadBip30 (r : Except BlockError (List (OutPoint × Coin))) : Bool :=
  match r with | .error BlockError.badTxnsBIP30 => true | _ => false
private def isErr (r : Except BlockError (List (OutPoint × Coin))) : Bool :=
  match r with | .error _ => true | _ => false

-- P5: D4a [A2,A2] same-block duplicate
private def txA2 : Tx :=
  { version := 1, vin := [cvIn (cvOp 0xF6 0)], vout := [cvOut 700000],
    locktime := 0, witness := [] }
private def u0a : List (OutPoint × Coin) :=
  [ (cvOp 0xF6 0, ⟨8000000, 100, false, scriptOf [0x51]⟩) ]

-- P6: D4d coinbase value-twin (null prevout)
private def txOldCb : Tx :=
  { version := 1, vin := [⟨OutPoint.null, Script.empty, 0xFFFFFFFF⟩],
    vout := [cvOut 500000000], locktime := 0, witness := [] }
private def txCbB : Tx :=
  { version := 1, vin := [⟨OutPoint.null, Script.empty, 0xFFFFFFFF⟩],
    vout := [cvOut 500000000], locktime := 0, witness := [] }
private def yk : OutPoint := ⟨serTx txOldCb, 0⟩
private def u0d : List (OutPoint × Coin) :=
  [ (yk, ⟨500000000, 100, true, scriptOf [0x51]⟩) ]

-- P7: the Y10 experiment: Eq (Option Coin) via decEq at 32-byte keys

-- P8: addedCoins over serTx keys (Eq Nat)

-- P9: 2459 odd-shape: [cb, tA, tC] / [cb, tA, tC, tC] over u0s (tA,tC = OP_TRUE twins)
private def cbS : Tx :=
  { version := 1, vin := [⟨OutPoint.null, Script.empty, 0xFFFFFFFF⟩],
    vout := [cvOut 500000000], locktime := 0, witness := [] }


/-! ## §N1: the era grid (Bool-tier, `by decide`)

CV07's A/B/C-era grid + CT02's mirror rows, D-classes per CV07:
D2a = 227931 off-by-one (Core ON / ours OFF; **FIXED RC SWEEP
2026-10-17** — ours ON, agreement, see `s04_divergence_core_vs_ours`
row 1);
D2b = 227932..1983701 non-canonical-anchor branch (Core ON / ours OFF);
D2c = repeat-pair {91842, 91880} own-hash pin (fork hash → Core ON).
Z05 pins D2a + D2c(91842) only — D2b, D2c(91880), and the ours-rows
are S04's (this file). `0x0DEAD` = a stand-in non-canonical
anchor@227931 (≠ bip34ActivationHash). -/

/-- A non-canonical anchor at BIP34Height (≠ BIP34Hash). -/
private def FORK_ANCHOR : Nat := 0x0DEAD

/-- A stand-in own-hash (≠ both repeat-pair pins). -/
private def FORK_STR : String := "forkhash"

/-- §A constants present + the in-tree pins they mirror (BLK-099
`bip30DisconnectRelaxed` @ Block/Params.lean:137, `bip34Anchored` @
Invariants/RC09.lean:72 = reused via import, never redeclared). -/
theorem s04_pins_core :
    (BIP30_REPEAT_HASH_91842.length = 64 ∧ BIP30_REPEAT_HASH_91880.length = 64 ∧
     BIP30_UNSPENDABLE_HASH_91722.length = 64 ∧ BIP30_UNSPENDABLE_HASH_91812.length = 64) ∧
    (BIP34_HEIGHT = 227931 ∧ BIP34_IMPLIES_BIP30_LIMIT = 1983702) ∧
    (BIP34_ACTIVATION_HASH = Bitcoin.Activation.bip34ActivationHash) ∧
    (Bitcoin.Ledger.BIP30_DUPLICATE_COINBASE_HEIGHTS = [91842, 91880]) ∧
    (bip30DisconnectRelaxed 91722 = true ∧ bip30DisconnectRelaxed 91812 = true ∧
     bip30DisconnectRelaxed 91723 = false) ∧
    (bip34Anchored Bitcoin.Activation.bip34ActivationHash = true) := by decide

/-- 2401/6205-6210 (D2c) + 2200-2212 (disconnect pair): the pairs are
height-AND-own-hash; a fork own-hash at a pair height, or a pinned
hash at the wrong height, is NOT a member. -/
theorem s04_pairs_hash_pinned :
    (isBip30Repeat 91842 BIP30_REPEAT_HASH_91842 = true ∧
     isBip30Repeat 91880 BIP30_REPEAT_HASH_91880 = true) ∧
    (isBip30Repeat 91842 FORK_STR = false ∧
     isBip30Repeat 91880 FORK_STR = false ∧
     isBip30Repeat 91843 BIP30_REPEAT_HASH_91842 = false ∧
     isBip30Repeat 91880 BIP30_REPEAT_HASH_91842 = false) ∧
    (isBip30UnspendableInline 91722 BIP30_UNSPENDABLE_HASH_91722 = true ∧
     isBip30UnspendableInline 91812 BIP30_UNSPENDABLE_HASH_91812 = true ∧
     isBip30UnspendableInline 91812 BIP30_UNSPENDABLE_HASH_91722 = false ∧
     isBip30UnspendableInline 91843 BIP30_UNSPENDABLE_HASH_91812 = false) := by decide

/-- The `coreBip30Enforced` grid (2401 + 2460-2461). D2a @227931:
Core 2460's `pprev->GetAncestor(227931)` on the height-227930 parent
is null ⇒ 2461's second conjunct is vacuous ⇒ fEnforceBIP30 = true
regardless of the anchor value. D2b @227932..1983701: the anchor at
227931 exists; canonical (== BIP34Hash) ⇒ elided, fork ⇒ enforced. -/
theorem s04_core_enforced_grid :
    (coreBip30Enforced 0 FORK_STR 0 = true ∧
     coreBip30Enforced 100000 FORK_STR 0 = true ∧
     coreBip30Enforced 91841 FORK_STR 0 = true ∧
     coreBip30Enforced 91843 FORK_STR 0 = true ∧
     coreBip30Enforced 227930 FORK_STR 0 = true) ∧
    (coreBip30Enforced 91842 BIP30_REPEAT_HASH_91842 0 = false ∧
     coreBip30Enforced 91842 FORK_STR 0 = true ∧
     coreBip30Enforced 91880 BIP30_REPEAT_HASH_91880 0 = false ∧
     coreBip30Enforced 91880 FORK_STR 0 = true) ∧
    (coreBip30Enforced 227931 FORK_STR 0 = true ∧
     coreBip30Enforced 227931 FORK_STR BIP34_ACTIVATION_HASH = true) ∧
    (coreBip30Enforced 227932 FORK_STR BIP34_ACTIVATION_HASH = false ∧
     coreBip30Enforced 227932 FORK_STR FORK_ANCHOR = true ∧
     coreBip30Enforced 300000 FORK_STR BIP34_ACTIVATION_HASH = false ∧
     coreBip30Enforced 300000 FORK_STR FORK_ANCHOR = true ∧
     coreBip30Enforced 1983701 FORK_STR BIP34_ACTIVATION_HASH = false ∧
     coreBip30Enforced 1983701 FORK_STR FORK_ANCHOR = true) ∧
    (coreBip30Enforced 1983702 FORK_STR BIP34_ACTIVATION_HASH = false ∧
     coreBip30LoopRuns 1983702 FORK_STR BIP34_ACTIVATION_HASH = true ∧
     coreBip30LoopRuns 1983702 FORK_STR FORK_ANCHOR = true) := by decide

/-- The 2466 gate: the bad-txns-BIP30 loop (2467-2475) runs iff
`fEnforceBIP30 || h ≥ BIP34_IMPLIES_BIP30_LIMIT` — OFF only inside
the canonical BIP34 window (227932..1983701) or at the hash-pinned
repeat pair. -/
theorem s04_core_loop_grid :
    (coreBip30LoopRuns 0 FORK_STR 0 = true ∧
     coreBip30LoopRuns 100000 FORK_STR 0 = true ∧
     coreBip30LoopRuns 227930 FORK_STR 0 = true) ∧
    (coreBip30LoopRuns 91842 BIP30_REPEAT_HASH_91842 0 = false ∧
     coreBip30LoopRuns 91880 BIP30_REPEAT_HASH_91880 0 = false ∧
     coreBip30LoopRuns 91842 FORK_STR 0 = true ∧
     coreBip30LoopRuns 91880 FORK_STR 0 = true) ∧
    (coreBip30LoopRuns 227931 FORK_STR 0 = true ∧
     coreBip30LoopRuns 227931 FORK_STR BIP34_ACTIVATION_HASH = true) ∧
    (coreBip30LoopRuns 227932 FORK_STR BIP34_ACTIVATION_HASH = false ∧
     coreBip30LoopRuns 227932 FORK_STR FORK_ANCHOR = true ∧
     coreBip30LoopRuns 1983701 FORK_STR FORK_ANCHOR = true) ∧
    (coreBip30LoopRuns 1983702 FORK_STR BIP34_ACTIVATION_HASH = true ∧
     coreBip30LoopRuns 0 "x" 0 = true) := by decide

/-- Ours' `bip30Enforced` (Interface.lean:354, rows
BLK-096/097/098/INV-104) is HEIGHTS-ONLY: repeat-pair heights
(91842/91880) elide with no own-hash pin (D2c), and (post-D2a-fix) the
window proper (227931, 1983702) elides with no BIP34Hash branch pin
(D2b; D2a FIXED RC SWEEP 2026-10-17 — 227931 = true = Core; HISTORY
pre-fix: `[227931, 1983702)` elided, `= false` here). -/
theorem s04_ours_heights_only_window :
    (Bitcoin.Ledger.bip30Enforced 0 = true ∧
     Bitcoin.Ledger.bip30Enforced 100000 = true ∧
     Bitcoin.Ledger.bip30Enforced 91841 = true ∧
     Bitcoin.Ledger.bip30Enforced 91842 = false ∧
     Bitcoin.Ledger.bip30Enforced 91843 = true ∧
     Bitcoin.Ledger.bip30Enforced 91880 = false ∧
     Bitcoin.Ledger.bip30Enforced 227930 = true ∧
     Bitcoin.Ledger.bip30Enforced 227931 = true ∧
     Bitcoin.Ledger.bip30Enforced 227932 = false ∧
     Bitcoin.Ledger.bip30Enforced 1983701 = false ∧
     Bitcoin.Ledger.bip30Enforced 1983702 = true) := by decide

/-- F-S04-001 (D2a) / F-S04-002 (D2b) / F-S04-003 (D2c): every
Core-ON/ours-OFF divergence class + the agreement rows (pre-window,
repeat-pair-pinned, canonical window, 2466 re-ON).

RC SWEEP 2026-10-17: row 1 is the D2a-fix AGREEMENT pin (Core ON ∧
ours ON at 227931) — HISTORY (pre-fix divergence, pinned 2026-10-16):
`(coreBip30Enforced 227931 FORK_STR 0 = true ∧
Bitcoin.Ledger.bip30Enforced 227931 = false)`, repaired by the
Interface.lean `BIP34_HEIGHT ≤ h` → `< h` fix (F-S04-001 / F-Z05-001 /
CV07 D2a). -/
theorem s04_divergence_core_vs_ours :
    (coreBip30Enforced 227931 FORK_STR 0 = true ∧
     Bitcoin.Ledger.bip30Enforced 227931 = true) ∧
    (coreBip30Enforced 227932 FORK_STR FORK_ANCHOR = true ∧
     Bitcoin.Ledger.bip30Enforced 227932 = false) ∧
    (coreBip30Enforced 1983701 FORK_STR FORK_ANCHOR = true ∧
     Bitcoin.Ledger.bip30Enforced 1983701 = false) ∧
    (coreBip30Enforced 91842 FORK_STR 0 = true ∧
     Bitcoin.Ledger.bip30Enforced 91842 = false) ∧
    (coreBip30Enforced 91880 FORK_STR 0 = true ∧
     Bitcoin.Ledger.bip30Enforced 91880 = false) ∧
    (coreBip30Enforced 100000 FORK_STR 0 = true ∧
     Bitcoin.Ledger.bip30Enforced 100000 = true) ∧
    (coreBip30Enforced 91842 BIP30_REPEAT_HASH_91842 0 = false ∧
     Bitcoin.Ledger.bip30Enforced 91842 = false) ∧
    (coreBip30Enforced 227932 FORK_STR BIP34_ACTIVATION_HASH = false ∧
     Bitcoin.Ledger.bip30Enforced 227932 = false) ∧
    (coreBip30LoopRuns 1983702 FORK_STR BIP34_ACTIVATION_HASH = true ∧
     Bitcoin.Ledger.bip30Enforced 1983702 = true) := by decide


/-! ## §2: the pristine pre-block overlap (Core 2466-2475)

Core's bad-txns-BIP30 loop (validation.cpp:2466-2475, gated by 2466
`if (fEnforceBIP30 || nHeight >= BIP34_IMPLIES_BIP30_LIMIT)`):
runs on the PRISTINE pre-block coins view, ONCE for the whole block
(block-pre, BEFORE the per-tx ConnectBlock loop ~2519), over every
vout index of every tx (UNFILTERED). Ours' `bip30Collision`
(Interface.lean:361) instead runs per-tx inside the W12 fold on the
EVOLVING view (D4c) and only over `addedCoins` (unspendable-skipped
— equivalent only on AddCoin-closed views). `(u op).isSome` =
Core's `HaveCoin` (spent = none = INV-114). -/

/-- Core 2466-2475 verbatim: some output of some tx of the block
lands on an outpoint already in the PRE-BLOCK view `u` (keyed by
`kf` per-tx, Core's `COutPoint(tx->GetId(), o)`). -/
@[rule "BLK-011"]
def bip30OverlapPristine (u : UtxoSet) (txs : List Tx) (kf : Tx → Key) : Bool :=
  txs.any (fun tx => (List.range tx.vout.length).any (fun o =>
    (u ((kf tx) OutPoint.null (UInt32.ofNat o))).isSome))

/-- Core's reject condition at height h (2466 gate + 2467-2475 loop):
`coreBip30LoopRuns h ownHash anchor && bip30OverlapPristine u txs kf`
⇒ `bad-txns-BIP30`. -/
@[rule "BLK-011"]
def coreBip30Rejects (h : Nat) (ownHash : String) (hashAtBip34Height : Nat)
    (u : UtxoSet) (txs : List Tx) (kf : Tx → Key) : Bool :=
  coreBip30LoopRuns h ownHash hashAtBip34Height && bip30OverlapPristine u txs kf

/-! ## §N2: the D-tier pins (X11 2459-shapes + CV07 D-shapes)

The P-shapes (CV07's u0/d4cBlock/u0a/d4aBlock/u0d + X11's cbS) +
X11's blocks.json seed shape (k41/k61 = the 1000/700-sat OP_TRUE
prevout coins, wire-txids 0x41..0x60 / 0x61..0x80). All statements
Eq Bool / Eq Nat (Y10 F-Y10-005: the Eq-ByteArray/decEq wall hits
only `decide (x = y)`-Prop forms, not the Eq-Bool idiom). -/

/-- X11's blocks.json seed keys (utxo[0] = txid_wire 0x41..0x60,
utxo[1] = 0x61..0x80). -/
private def rngK (b : UInt8) : ByteArray :=
  (List.range 32).foldl (fun acc i => acc.push (b + UInt8.ofNat i)) ByteArray.empty
private def k41 : OutPoint := ⟨rngK 0x41, 0⟩
private def k61 : OutPoint := ⟨rngK 0x61, 0⟩
private def u0s : List (OutPoint × Coin) :=
  [ (k41, ⟨1000, 0, false, scriptOf [0x51]⟩),
    (k61, ⟨700, 0, false, scriptOf [0x51]⟩) ]
/-- X11 base-odd / mut-odd-dup-tail: [cb, t1(→900), t2(→600)] /
[cb, t1, t2, t2copy] (t2copy = the CVE-2012-2459 odd-level
duplication). -/
private def tA11 : Tx :=
  { version := 1, vin := [cvIn k41], vout := [cvOut 900],
    locktime := 0, witness := [] }
private def tC11 : Tx :=
  { version := 1, vin := [cvIn k61], vout := [cvOut 600],
    locktime := 0, witness := [] }

/-- F-S04-004 (X11 base-odd, blocks.json case 3): the un-mutated
odd block ACCEPTs end-to-end (X11's Lean verdict) — no pristine
overlap (t1/t2 spend k41/k61, create fresh outpoints), no fold
error. -/
theorem s04_x11_base_odd_accepts :
    (bip30OverlapPristine (viewOf u0s) [cbS, tA11, tC11] txidPreimageKey = false) ∧
    (coreBip30Rejects 1000 FORK_STR 0 (viewOf u0s) [cbS, tA11, tC11] txidPreimageKey = false) ∧
    (applyBlockL u0s txidPreimageKey [cbS, tA11, tC11] 1000).isOk = true ∧
    (bip30OverlapPristine (viewOf u0s) [] txidPreimageKey = false) := by decide

/-- F-S04-004 (X11 mut-odd-dup-tail = the CVE proper, blocks.json
case 4): the mutated block [cb, t1, t2, t2copy] has the SAME merkle
root (X11: root-equality mut-odd-dup-tail = true — BLK-010 passes),
and Core's 2466-2475 loop does NOT see the mutation (t2copy's
outpoint ∉ the PRISTINE pre-block view) — Core rejects EARLIER, at
CheckBlock via the `mutated` flag (`bad-txns-duplicate` = the
BLK-011 row). OURS pre-D4c-2 rejected it in the W12 fold via the
EVOLVING-view collision (t2copy's outpoint ∈ the post-t2 fold view)
as `badTxnsBIP30` — same verdict (REJECT), WRONG RULE + wrong layer.
D4c REPAIRED (BIP30R 2026-10-17): the per-tx BIP30 branch is gone
from the fold (the pristine block gate `bip30BlockCollision` does not
see the twin), so the same-evolving-view collision now lands where
Core's ConnectBlock would put it — the second spend of k61 fails
`inputsAvailable` = `bad-txns-inputs-missing-or-spent`. Same verdict,
Core's LAYER (per-tx fold) — the remaining divergence vs Core's
`mutated`-flag rejection is BLK-011 (CheckBlock tier), NOT BIP30.
Pins: reject in every era (`isErr` always), never `badTxnsBIP30`
(post-D4c-2), pristine/Core-2466 never see it. This is the BLK-011
nuance: rules.yaml's BLK-011 row (mutated-flag /
`bad-txns-duplicate`) is `planned` (X11's FIND-X11-001). -/
theorem s04_x11_mut_organic_wrong_rule :
    (bip30OverlapPristine (viewOf u0s) [cbS, tA11, tC11, tC11] txidPreimageKey = false) ∧
    (coreBip30Rejects 1000 FORK_STR 0 (viewOf u0s) [cbS, tA11, tC11, tC11] txidPreimageKey = false) ∧
    (applyBlockL u0s txidPreimageKey [cbS, tA11, tC11, tC11] 1000).isOk = false ∧
    (isBadBip30 (applyBlockL u0s txidPreimageKey [cbS, tA11, tC11, tC11] 1000)) = false ∧
    (isBadBip30 (applyBlockL u0s txidPreimageKey [cbS, tA11, tC11, tC11] 227932)) = false ∧
    (isErr (applyBlockL u0s txidPreimageKey [cbS, tA11, tC11, tC11] 227932)) = true ∧
    (isBadBip30 (applyBlockL u0s txidPreimageKey [cbS, tA11, tC11, tC11] 1983702)) = false ∧
    (isErr (applyBlockL u0s txidPreimageKey [cbS, tA11, tC11, tC11] 1983702)) = true ∧
    (bip30Collision (viewOf u0s) tC11 (txidPreimageKey tC11) 1000 = false) := by decide

/-- F-S04-004 / F-S04-006 (CV07 D4c): block [A, B=X-twin, C] over u0
(x = X's old coin, unspent PRE-block): A spends x (1M), B (=X exact
duplicate, re-creates x) spends 0xE5:0 (90M), C re-spends x (2).
CORE 2466: the pristine loop sees B's vout-0 (== x) in the pre-block
view → `bad-txns-BIP30` REJECT (BIP30-ON eras). OURS (W12 fold):
B's per-tx `bip30Collision` runs on the POST-A evolving view (x
spent) → no collision → WRONG-ACCEPT (D4c) — in EVERY era, even at
1000/227930 (ours enforced) and 1983702 (2466's `||`-arm re-ON),
and at 227931 (BIP30-ON post-D2a-fix 2026-10-17: ours no longer
elides there, but the D4c evolving-view wrong-accept persists) +
227932/91842 (elide/agree).
D4c REPAIRED (BIP30R 2026-10-17): `applyBlockL` now runs the SAME
pre-loop pristine gate (`bip30BlockCollision (viewOf u0)` = the
2466-2475 loop ONCE) — d4cBlock REJECTS with `badTxnsBIP30` in
every BIP30-ON era (THE acceptance flip: `.isOk` 1000 true →
false), and the X-less control [A, C] still fails in the fold
(inputs) not via BIP30. The `bip30OverlapPristine`/`coreBip30Rejects`
rows (Core-side, definitionally unchanged) keep pinning the Core
loop = the two sides now AGREE. -/
theorem s04_d4c_pristine_vs_fold_1000 :
    (bip30OverlapPristine (viewOf u0) d4cBlock txidPreimageKey = true) ∧
    (bip30Collision (viewOf u0) txX (txidPreimageKey txX) 1000 = true) ∧
    (bip30Collision (viewOf u0) txA (txidPreimageKey txA) 1000 = false) ∧
    (coreBip30LoopRuns 1000 FORK_STR 0 = true) ∧
    (coreBip30Rejects 1000 FORK_STR 0 (viewOf u0) d4cBlock txidPreimageKey = true) ∧
    (applyBlockL u0 txidPreimageKey d4cBlock 1000).isOk = false ∧
    (isBadBip30 (applyBlockL u0 txidPreimageKey d4cBlock 1000)) = true ∧
    (bip30OverlapPristine (viewOf u0) [txA, txC] txidPreimageKey = false) ∧
    (isErr (applyBlockL u0 txidPreimageKey [txA, txC] 1000)) = true ∧
    (isBadBip30 (applyBlockL u0 txidPreimageKey [txA, txC] 1000)) = false := by decide

/-- D4c across the eras (Core 2466 vs the W12 fold). Core REJECTS
wherever `coreBip30LoopRuns` (2466) holds: 1000, 227930, 227931
(D2a Core-ON), 1983702 (`||`-arm), 227932-fork (D2b) — ours isOk (D4c
wrong-accept) at every one of those. Agreement rows: 91842-pinned +
227932-canonical (loop OFF).
D4c REPAIRED (BIP30R 2026-10-17): with the pre-loop pristine gate,
ours REJECTS (`.isOk = false`) at every BIP30-ON era Core rejects
(1000, 227930, 227931, 1983702) = the D4c wrong-accept is gone;
agreement rows stay (91842/227932 = elide, `.isOk` true). The
REMAINING divergence row is D2b (NOT D4c): 1983701 `FORK_ANCHOR`
Core-ON/ours-elide (the `[227932, 1983702)` window, mission D2b) —
plus 227932-`FORK_ANCHOR`/1983702-`FORK_ANCHOR` Core-ON forks. -/
theorem s04_d4c_eras :
    (applyBlockL u0 txidPreimageKey d4cBlock 1000).isOk = false ∧
    (applyBlockL u0 txidPreimageKey d4cBlock 91842).isOk = true ∧
    (applyBlockL u0 txidPreimageKey d4cBlock 227930).isOk = false ∧
    (applyBlockL u0 txidPreimageKey d4cBlock 227931).isOk = false ∧
    (applyBlockL u0 txidPreimageKey d4cBlock 227932).isOk = true ∧
    (applyBlockL u0 txidPreimageKey d4cBlock 1983702).isOk = false ∧
    (coreBip30Rejects 1000 FORK_STR 0 (viewOf u0) d4cBlock txidPreimageKey = true) ∧
    (coreBip30Rejects 227930 FORK_STR 0 (viewOf u0) d4cBlock txidPreimageKey = true) ∧
    (coreBip30Rejects 227931 FORK_STR 0 (viewOf u0) d4cBlock txidPreimageKey = true) ∧
    (coreBip30Rejects 1983702 FORK_STR 0 (viewOf u0) d4cBlock txidPreimageKey = true) ∧
    (coreBip30Rejects 1983702 FORK_STR FORK_ANCHOR (viewOf u0) d4cBlock txidPreimageKey = true) ∧
    (coreBip30Rejects 91842 BIP30_REPEAT_HASH_91842 0 (viewOf u0) d4cBlock txidPreimageKey = false) ∧
    (coreBip30Rejects 227932 FORK_STR BIP34_ACTIVATION_HASH (viewOf u0) d4cBlock txidPreimageKey = false) ∧
    (coreBip30Rejects 227932 FORK_STR FORK_ANCHOR (viewOf u0) d4cBlock txidPreimageKey = true) ∧
    (coreBip30Rejects 1983701 FORK_STR FORK_ANCHOR (viewOf u0) d4cBlock txidPreimageKey = true) ∧
    (applyBlockL u0 txidPreimageKey d4cBlock 1983701).isOk = true ∧
    (applyBlockL u0 txidPreimageKey d4cBlock 227930).isOk = false := by decide

/-- F-S04-005 (CV07 D4a): block [A2, A2] (later exact duplicate of a
spent-prevout tx) — the pristine loop does NOT see the duplicate
(A2's outpoint ∉ the pre-block u0a) → Core rejects at
CheckTxInputs (`inputs-spent`), NOT at 2466. OURS rejects at the
BIP30 gate (`badTxnsBIP30`) in the enforced eras (1000, 1983702:
A2-2nd's outpoint ∈ the post-A2-1st fold view) — error-KIND
divergence (D4a); in the elide-window (227932) ours falls through to
the inputs error = agree-kind.
D4c REPAIRED (BIP30R 2026-10-17): with the per-tx BIP30 branch out
of the fold (A2-2nd's outpoint ∉ the PRISTINE u0a, so the block
gate never fires), the second A2 fails `inputsAvailable` =
`bad-txns-inputs-missing-or-spent` in EVERY era — the error-KIND
divergence (D4a) is gone, ours now agrees with Core's layer
(CheckTxInputs) on this shape; `isErr` always, `badTxnsBIP30`
never. -/
theorem s04_d4a_error_kind_1000 :
    (bip30OverlapPristine (viewOf u0a) [txA2, txA2] txidPreimageKey = false) ∧
    (coreBip30Rejects 1000 FORK_STR 0 (viewOf u0a) [txA2, txA2] txidPreimageKey = false) ∧
    (isBadBip30 (applyBlockL u0a txidPreimageKey [txA2, txA2] 1000)) = false ∧
    (isErr (applyBlockL u0a txidPreimageKey [txA2, txA2] 1000)) = true ∧
    (isBadBip30 (applyBlockL u0a txidPreimageKey [txA2, txA2] 227932)) = false ∧
    (isErr (applyBlockL u0a txidPreimageKey [txA2, txA2] 227932)) = true ∧
    (isBadBip30 (applyBlockL u0a txidPreimageKey [txA2, txA2] 1983702)) = false ∧
    (isErr (applyBlockL u0a txidPreimageKey [txA2, txA2] 1983702)) = true ∧
    (coreBip30Rejects 1000 FORK_STR 0 (viewOf u0a) [txA2] txidPreimageKey = false) ∧
    (isBadBip30 (applyBlockL u0a txidPreimageKey [txA2] 1000)) = false := by decide

/-- CV07 D4d control (the 91842 shape): block [cbB] (exact
byte-twin of the old coinbase txOldCb, re-creating yk = old
coinbase's outpoint) — the pristine loop DOES see this one (cbB's
vout-0 == yk ∈ u0d) → Core `bad-txns-BIP30` REJECTS wherever the
2466 gate holds. Ours agrees at 1000 (cbB = fold's first tx →
collision on u0d) + 1983702 (`||`-arm), elides at 91842-pinned +
227932-canonical = agree; at 227931 ours NOW agrees too (D2a FIXED
RC SWEEP 2026-10-17: BIP30-ON → badTxnsBIP30 = Core; HISTORY
pre-fix: ours elided while Core REJECTS — the D2a divergence on the
D4d shape). -/
theorem s04_d4d_coinbase_twin_eras :
    (serTx txOldCb == serTx txCbB) = true ∧
    (txOldCb.isCoinBase = true ∧ txCbB.isCoinBase = true) ∧
    (bip30OverlapPristine (viewOf u0d) [txCbB] txidPreimageKey = true) ∧
    (coreBip30Rejects 1000 FORK_STR 0 (viewOf u0d) [txCbB] txidPreimageKey = true) ∧
    (isBadBip30 (applyBlockL u0d txidPreimageKey [txCbB] 1000)) = true ∧
    (isErr (applyBlockL u0d txidPreimageKey [txCbB] 1000)) = true ∧
    (isBadBip30 (applyBlockL u0d txidPreimageKey [txCbB] 227930)) = true ∧
    (applyBlockL u0d txidPreimageKey [txCbB] 91842).isOk = true ∧
    -- D2a FIX: 227931 BIP30-ON → cbB collides on u0d (HISTORY: was true)
    (applyBlockL u0d txidPreimageKey [txCbB] 227931).isOk = false ∧
    (applyBlockL u0d txidPreimageKey [txCbB] 227932).isOk = true ∧
    (coreBip30Rejects 227931 FORK_STR 0 (viewOf u0d) [txCbB] txidPreimageKey = true) ∧
    (coreBip30Rejects 227932 FORK_STR BIP34_ACTIVATION_HASH (viewOf u0d) [txCbB] txidPreimageKey = false) ∧
    (coreBip30Rejects 91842 BIP30_REPEAT_HASH_91842 0 (viewOf u0d) [txCbB] txidPreimageKey = false) ∧
    (isBadBip30 (applyBlockL u0d txidPreimageKey [txCbB] 1983702)) = true ∧
    (coreBip30Rejects 1983702 FORK_STR 0 (viewOf u0d) [txCbB] txidPreimageKey = true) ∧
    -- D2a FIX: 227931 BIP30-ON (HISTORY: was `= false`)
    (isBadBip30 (applyBlockL u0d txidPreimageKey [txCbB] 227931)) = true := by decide

/-- F-S04-007 (the Y10-wall echo, P7-tier): `Eq (Option Coin)` /
`==`-idiom decide rows over 32-byte serTx keys — the Y10
F-Y10-005 Eq-ByteArray wall hits only `decide (x = y)`-Prop forms;
the Eq-Bool idiom kernel-reduces. u0[k41]/u0[xk] coin identities
(90000000-coin at 0xE5:0, 50000000-coin at xk). -/
theorem s04_decEq_coin_rows :
    ((coinLookup u0 (cvOp 0xE5 0)) == (some ⟨90000000, 100, false, scriptOf [0x51]⟩)) = true ∧
    ((coinLookup u0 (cvOp 0xE5 0)) == (some ⟨50000000, 100, false, scriptOf [0x51]⟩)) = false ∧
    ((coinLookup u0 ⟨serTx txX, 0⟩) == (some ⟨50000000, 100, false, scriptOf [0x51]⟩)) = true ∧
    ((coinLookup u0s k41) == (some ⟨1000, 0, false, scriptOf [0x51]⟩)) = true ∧
    ((coinLookup u0s k61) == (some ⟨700, 0, false, scriptOf [0x51]⟩)) = true ∧
    ((serTx txX).size > 0) = true ∧
    (serTx tA11 == serTx tA11) = true := by decide


/-! ## §Axioms: the sorry-free pins (F-S04-007)

`#print axioms` per theorem. The §A-pure rows (pairs/enforced/loop —
String/Nat/Bool only) are axiom-CLEAN. Every row whose statement
touches the in-tree `Bitcoin.Ledger.Interface` def-graph
(`bip30Enforced` sits in `applyTxStepL`/`applyBlockL`'s if-chain;
`bip30DisconnectRelaxed`/`bip34Anchored` likewise) inherits the
standard `[propext, Classical.choice, Quot.sound]` trio from that
chain's `List.contains`/`decide`-`propDecidable` idiom — inherited
from the EXISTING spec code, never `sorryAx` (F-S04-007). -/

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_pins_core' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms s04_pins_core

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_pairs_hash_pinned' does not depend on any axioms -/
#guard_msgs in
#print axioms s04_pairs_hash_pinned

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_core_enforced_grid' does not depend on any axioms -/
#guard_msgs in
#print axioms s04_core_enforced_grid

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_core_loop_grid' does not depend on any axioms -/
#guard_msgs in
#print axioms s04_core_loop_grid

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_ours_heights_only_window' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms s04_ours_heights_only_window

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_divergence_core_vs_ours' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms s04_divergence_core_vs_ours

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_x11_base_odd_accepts' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms s04_x11_base_odd_accepts

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_x11_mut_organic_wrong_rule' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms s04_x11_mut_organic_wrong_rule

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_d4c_pristine_vs_fold_1000' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms s04_d4c_pristine_vs_fold_1000

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_d4c_eras' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms s04_d4c_eras

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_d4a_error_kind_1000' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms s04_d4a_error_kind_1000

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_d4d_coinbase_twin_eras' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms s04_d4d_coinbase_twin_eras

/-- info: 'Bitcoin.Block.Bip30Nuance.s04_decEq_coin_rows' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms s04_decEq_coin_rows

end Bitcoin.Block.Bip30Nuance
