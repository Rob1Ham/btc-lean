import Bitcoin.RuleAttr
import Bitcoin.Chain.Basic
import Bitcoin.Data.Basic
import Bitcoin.Data.Tx
import Bitcoin.Ledger.Interface
import Bitcoin.Conservation.Interface
import Bitcoin.Activation.Bip9
import Bitcoin.Capstone.Merkle

/-!
# Bitcoin.Block.Params — chain-parameter and meta rules (the block-validation module)

The non-algorithmic block layer: null headers (BLK-004), the header-index
verdict interface (BLK-063/064/065), per-network deployment tables
(BLK-082), the BIP30 disconnect pair (BLK-099), the genesis block pins
(BLK-111/112), DoS/trust parameters that are deliberately NOT consensus
(BLK-122/123/124/127), relay-path mutation guards (BLK-125), the signet
challenge (BLK-126), the coinbase reserved-value constructor (BLK-128),
merkle path replay (BLK-129), disconnect-batch consistency (BLK-106/
107/108) and the timestamp window (BLK-130).

All hashes are byte arrays in **internal little-endian order** (as stored
in headers); display (big-endian) forms are provided for the genesis pins.
The full SHA256d hash equalities are pinned in
`spec/Test/Crypto/SeamHashTest.lean` (Test-scoped `native_decide`, per the
D2 L1 convention) — kernel `decide` does not reduce the seam's SHA256.
-/

namespace Bitcoin.Block.Params

open Bitcoin.Data
open Bitcoin.Chain
open Bitcoin.Ledger
open Bitcoin.Activation
open Bitcoin.Capstone.Merkle

/-- Byte-list builder (the kernel-friendly form; `decide` reduces the
foldl-push on literals). -/
def bytesOf (l : List UInt8) : ByteArray := l.foldl (·.push ·) ByteArray.empty

/-! ## BLK-004: header IsNull -/

/-- `CBlockHeader::IsNull` (primitives/block.h:54-57): `nBits == 0`
defines a null header. -/
@[rule "BLK-004"]
def headerIsNull (h : BlockHeader) : Bool := h.bits = 0

/-- The null header's compact target decodes to zero. -/
theorem compactTarget_zero : compactTarget 0 = 0 := rfl

theorem headerIsNull_compactTarget (h : BlockHeader) (hnull : headerIsNull h) :
    compactTarget h.bits = 0 := by
  have hb : h.bits = 0 := by simpa [headerIsNull] using hnull
  rw [hb]
  exact compactTarget_zero

/-! ## BLK-063/064/065: the header-index verdict interface -/

/-- Header-index entry (chain.h `CBlockIndex`, reduced to what
`AcceptBlockHeader` reads). -/
structure IndexEntry where
  valid : Bool            -- an accepted BLOCK_VALID_* verdict is cached
  failed : Bool           -- BLOCK_FAILED_VALID

/-- BLK-063: `prev-blk-not-found` — the parent must be a known header
(validation.cpp AcceptBlockHeader). -/
@[rule "BLK-063"]
def prevHeaderKnown (idx : Nat → Option IndexEntry) (h : Nat) : Bool :=
  match idx h with | some _ => true | none => false

/-- BLK-064: `bad-prevblk` — the parent must not be BLOCK_FAILED_VALID. -/
@[rule "BLK-064", rule "INV-145"]
def prevNotFailed (idx : Nat → Option IndexEntry) (h : Nat) : Bool :=
  match idx h with | some e => ¬ e.failed | none => false

/-- BLK-065: a known hash short-circuits to the cached verdict
(AcceptBlockHeader's `pindex != nullptr` branch); the genesis block is
exempt from all header checks. -/
@[rule "BLK-065"]
def cachedVerdict (idx : Nat → Option IndexEntry) (self : Nat) (isGenesis : Bool) :
    Option Bool :=
  if isGenesis then some true
  else match idx self with
       | some e => some e.valid
       | none => none

theorem prevNotFailed_of_not_failed (idx : Nat → Option IndexEntry) (h : Nat)
    (e : IndexEntry) (hfound : idx h = some e) (hf : e.failed = false) :
    prevNotFailed idx h = true := by
  unfold prevNotFailed
  rw [hfound]
  simp [hf]

theorem cachedVerdict_genesis (idx : Nat → Option IndexEntry) (self : Nat) :
    cachedVerdict idx self true = some true := rfl

theorem cachedVerdict_known (idx : Nat → Option IndexEntry) (self : Nat)
    (e : IndexEntry) (hfound : idx self = some e) :
    cachedVerdict idx self false = some e.valid := by
  unfold cachedVerdict
  simp [hfound]

/-! ## BLK-082: deployment tables for the other nets -/

/-- BLK-082: testnet4's dormant testdummy (kernel/chainparams.cpp:359-365
@cce32b168): bit 28, NEVER_ACTIVE, threshold 1512 (75%), period 2016. -/
@[rule "BLK-082"]
def testnet4Testdummy : Bip9Deployment :=
  { bit := 28, start := BIP9_NEVER_ACTIVE, timeout := BIP9_ALWAYS_ACTIVE,
    minActivation := 0, threshold := 1512, period := 2016 }

/-- BLK-082: regtest's always-on testdummy (kernel/chainparams.cpp:611-617
@cce32b168): start 0 (active from genesis), threshold 108 (75%), period
144 (faster retarget than mainnet's 2016). -/
@[rule "BLK-082"]
def regtestTestdummy : Bip9Deployment :=
  { bit := 28, start := 0, timeout := BIP9_ALWAYS_ACTIVE,
    minActivation := 0, threshold := 108, period := 144 }

/-- Both non-mainnet testdummy thresholds are the same 75% of their
periods. -/
theorem testnet4_testdummy_ratio :
    testnet4Testdummy.threshold * 4 = 3 * testnet4Testdummy.period := by decide

theorem regtest_testdummy_ratio :
    regtestTestdummy.threshold * 4 = 3 * regtestTestdummy.period := by decide

theorem regtest_testdummy_start_zero : regtestTestdummy.start = 0 := rfl

/-! ## BLK-099: the BIP30 disconnect pair -/

/-- BLK-099: at heights 91722 (…0271a2…) and 91812 (…0af0ae…) the
duplicate-txid blocks relax BIP30's no-duplicates enforcement during
disconnect (validation.cpp:IsBIP30Unspendable:6213): coins from the
FIRST instance are treated as unspendable rather than requiring exact
re-creation, and coinstats excludes them. -/
@[rule "BLK-099", rule "INV-105"]
def bip30DisconnectRelaxed (h : UInt32) : Bool :=
  h.toNat = 91722 ∨ h.toNat = 91812

theorem bip30_relaxed_91722 : bip30DisconnectRelaxed 91722 = true := by decide
theorem bip30_relaxed_91812 : bip30DisconnectRelaxed 91812 = true := by decide
theorem bip30_relaxed_91723 : bip30DisconnectRelaxed 91723 = false := by decide

/-- The relaxed pair sits strictly below BIP34 activation — BIP34's
unique-coinbase requirement is what re-imposes BIP30 from 1983702 on. -/
theorem bip30_relaxed_below_BIP34 (h : UInt32) (hr : bip30DisconnectRelaxed h) :
    h.toNat < Bitcoin.Ledger.BIP34_HEIGHT.toNat := by
  have h34 : Bitcoin.Ledger.BIP34_HEIGHT.toNat = 227931 := rfl
  unfold bip30DisconnectRelaxed at hr
  simp at hr
  omega

/-! ## BLK-106/107/108: disconnect-batch consistency -/

/-- BLK-106: disconnect replays the per-tx undo batches in reverse order
(validation.cpp DisconnectBlock). -/
@[rule "BLK-106"]
def replayUndos (undo : List (OutPoint × Coin)) : List (OutPoint × Coin) :=
  undo.reverse

/-- Double reversal is the identity — disconnect is reversible. -/
theorem replayUndos_involutive (undo : List (OutPoint × Coin)) :
    replayUndos (replayUndos undo) = undo := List.reverse_reverse undo

/-! ### BLK-106 — the block-level disconnect fold

Core `DisconnectBlock` (validation.cpp:2198-2247) walks `block.vtx` in
**reverse**; for every transaction it first spends-and-checks each
non-unspendable output against the coin view (`tx.vout[o] != coin.out`,
height and coinbase-bit included), setting `fClean = false` on mismatch,
then restores the inputs from that transaction's undo batch (skipping the
coinbase, `i > 0`). The verdict is `DISCONNECT_UNCLEAN` iff some output
re-check failed. The definitions below model exactly that fold; the
theorems expose the reverse order, the `unclean` result and the
restore/involutivity face. -/

/-- Verdict of the disconnect fold (`DisconnectResult`): the undo-count
check abort (`DISCONNECT_FAILED`) or an output re-check mismatch
(`DISCONNECT_UNCLEAN`). -/
inductive DisconnectError where
  | inconsistent
  | unclean
deriving Repr, DecidableEq

/-- Per-output re-check (validation.cpp:2208-2226): a non-unspendable
output must be present in the view under **its own transaction's** key —
`COutPoint(tx.GetHash(), o)` — with the same value/script, the same
creation height and the same coinbase bit.  Unspendable outputs were
never stored (`addedCoins`), so they are skipped. -/
def outputCoinMatches (u : UtxoSet) (height : UInt32) (tx : Tx)
    (o : Nat) : Bool :=
  match tx.vout[o]? with
  | none => true
  | some out =>
      if scriptUnspendable out.scriptPubKey then true
      else
        match u (txidPreimageKey tx OutPoint.null (UInt32.ofNat o)) with
        | none => false
        | some c =>
            c.value == out.value && (c.scriptPubKey == out.scriptPubKey) &&
              c.height == height && c.isCoinbase == tx.isCoinBase

/-- The per-output verdict including Core's BIP30 disconnect tolerance:
for the two historical exception blocks a coinbase output mismatch is
ignored (`is_bip30_exception = is_coinbase && !fEnforceBIP30`,
validation.cpp:2200-2226).  `bip30DisconnectRelaxed` is BLK-099's
height-only model of those two blocks. -/
def outputCoinClean (u : UtxoSet) (height : UInt32) (tx : Tx)
    (o : Nat) : Bool :=
  outputCoinMatches u height tx o ||
    (tx.isCoinBase && bip30DisconnectRelaxed height)

/-- The reverse fold over `(tx, optional undo)` pairs: check the outputs
against the current view, undo the transaction when it has an undo batch
(the coinbase has none), then continue.  Every re-check uses the
transaction's own txid key. -/
def disconnectTxs (height : UInt32) (u : UtxoSet) :
    List (Tx × Option (List (OutPoint × Coin))) → UtxoSet × Bool
  | [] => (u, true)
  | (tx, undo?) :: rest =>
      let clean := (List.range tx.vout.length).all
        (fun o => outputCoinClean u height tx o)
      let u' := match undo? with
                | some undo => undoCoins u undo tx (txidPreimageKey tx) height
                | none => u
      let r := disconnectTxs height u' rest
      (r.1, clean && r.2)

/-- BLK-106: block-level disconnect. The count check is
`vtxundo.size() + 1 == vtx.size()` (BLK-108); **all** transactions,
including the coinbase, are walked in reverse order and re-checked
(validation.cpp:2205-2227), and the non-coinbase ones are paired with the
undo batches in reverse order.  The coinbase has an empty undo slot
(`none`), matching Core's `if (i > 0)` restore guard: its outputs are
re-checked but no inputs are restored. -/
@[rule "BLK-106"]
def disconnectBlock (u : UtxoSet) (height : UInt32)
    (txs : List Tx) (undos : List (List (OutPoint × Coin))) :
    Except DisconnectError (UtxoSet × Bool) :=
  if undos.length + 1 ≠ txs.length then .error .inconsistent
  else
    .ok (disconnectTxs height u
      (txs.reverse.zip (undos.reverse.map some ++ [none])))

/-- BLK-106: an undo/tx count mismatch aborts the fold. -/
@[rule "BLK-106"]
theorem disconnectBlock_inconsistent (u : UtxoSet) (height : UInt32)
    (txs : List Tx) (undos : List (List (OutPoint × Coin)))
    (h : undos.length + 1 ≠ txs.length) :
    disconnectBlock u height txs undos = .error .inconsistent := by
  unfold disconnectBlock
  rw [if_pos h]

/-- BLK-106: the coinbase-only block has an empty undo list; its own
outputs are still re-checked (Core does not skip the coinbase output
loop), and no undo step runs. -/
@[rule "BLK-106"]
theorem disconnectBlock_coinbase_only (u : UtxoSet) (height : UInt32)
    (cb : Tx) :
    disconnectBlock u height [cb] [] =
      .ok (u, (List.range cb.vout.length).all
        (fun o => outputCoinClean u height cb o)) := by
  simp [disconnectBlock, disconnectTxs]

/-- BLK-106 (reverse order, two non-coinbase txs): `t2`, the **last**
transaction of the block, is checked and undone first; `t1` then runs
against the view that `t2` produced; the coinbase is re-checked last.
Each transaction uses its own txid key. -/
@[rule "BLK-106"]
theorem disconnectBlock_three (u : UtxoSet) (height : UInt32)
    (cb t1 t2 : Tx) (u1 u2 : List (OutPoint × Coin)) :
    disconnectBlock u height [cb, t1, t2] [u1, u2] =
      .ok (undoCoins (undoCoins u u2 t2 (txidPreimageKey t2) height)
            u1 t1 (txidPreimageKey t1) height,
        (List.range t2.vout.length).all
          (fun o => outputCoinClean u height t2 o) &&
        ((List.range t1.vout.length).all
          (fun o => outputCoinClean
            (undoCoins u u2 t2 (txidPreimageKey t2) height) height t1 o) &&
        (List.range cb.vout.length).all
          (fun o => outputCoinClean
            (undoCoins (undoCoins u u2 t2 (txidPreimageKey t2) height)
              u1 t1 (txidPreimageKey t1) height) height cb o))) := by
  simp [disconnectBlock, disconnectTxs]

/-- The UTXO state produced by the reverse disconnect fold, ignoring the
per-output cleanliness flag. -/
def disconnectFoldUndo (height : UInt32) (u : UtxoSet)
    (pairs : List (Tx × Option (List (OutPoint × Coin)))) : UtxoSet :=
  match pairs with
  | [] => u
  | (tx, undo?) :: rest =>
      disconnectFoldUndo height
        (match undo? with
         | some undo => undoCoins u undo tx (txidPreimageKey tx) height
         | none => u) rest

/-- The conjunction of every per-output cleanliness check in the reverse
disconnect fold. -/
def disconnectClean (height : UInt32) (u : UtxoSet)
    (pairs : List (Tx × Option (List (OutPoint × Coin)))) : Bool :=
  match pairs with
  | [] => true
  | (tx, undo?) :: rest =>
      (List.range tx.vout.length).all (fun o => outputCoinClean u height tx o) &&
      disconnectClean height
        (match undo? with
         | some undo => undoCoins u undo tx (txidPreimageKey tx) height
         | none => u) rest

/-- The reverse fold is precisely `disconnectFoldUndo` paired with the
conjunction of every output check. -/
theorem disconnectTxs_eq_fold (height : UInt32) (u : UtxoSet)
    (pairs : List (Tx × Option (List (OutPoint × Coin)))) :
    disconnectTxs height u pairs =
      (disconnectFoldUndo height u pairs, disconnectClean height u pairs) := by
  induction pairs generalizing u with
  | nil => rfl
  | cons p rest ih =>
    obtain ⟨tx, undo?⟩ := p
    cases undo? with
    | none =>
      simp [disconnectTxs, disconnectFoldUndo, disconnectClean, ih]
    | some undo =>
      simp [disconnectTxs, disconnectFoldUndo, disconnectClean, ih]

/-- **INV-117 (arbitrary-length reverse fold).**  For any block whose undo
list has one fewer entry than its transaction list, `disconnectBlock` is the
reverse zip of the transactions with `some undo` for every non-coinbase
transaction and `none` for the coinbase.  The resulting UTXO state is
`disconnectFoldUndo` on that reverse zip; the verdict is the conjunction
`disconnectClean` of every per-output check, each using the view produced by
the previously undone (later) transaction.  `outputCoinClean` expands to the
value/script/height/coinbase comparison or the two BIP30 exception lanes. -/
@[rule "INV-117"]
theorem disconnectBlock_inv117_fold (u : UtxoSet) (height : UInt32)
    (txs : List Tx) (undos : List (List (OutPoint × Coin)))
    (hlen : undos.length + 1 = txs.length) :
    disconnectBlock u height txs undos =
      .ok (disconnectFoldUndo height u
            (txs.reverse.zip (undos.reverse.map some ++ [none])),
          disconnectClean height u
            (txs.reverse.zip (undos.reverse.map some ++ [none]))) := by
  unfold disconnectBlock
  rw [if_neg (by omega), disconnectTxs_eq_fold]

/-- BLK-106 (two-transaction block): the single non-coinbase transaction
is checked under its own key and undone with its batch; the coinbase
outputs are re-checked against the post-undo view. -/
@[rule "BLK-106"]
theorem disconnectBlock_two (u : UtxoSet) (height : UInt32)
    (cb tx : Tx) (undo : List (OutPoint × Coin)) :
    disconnectBlock u height [cb, tx] [undo] =
      .ok (undoCoins u undo tx (txidPreimageKey tx) height,
        (List.range tx.vout.length).all
          (fun o => outputCoinClean u height tx o) &&
        (List.range cb.vout.length).all
          (fun o => outputCoinClean
            (undoCoins u undo tx (txidPreimageKey tx) height) height cb o)) := by
  simp [disconnectBlock, disconnectTxs]

/-- BLK-106 (mismatch ⇒ unclean): if a non-unspendable output of the
non-coinbase transaction is absent from the view or differs from the block's
output (value/script/height/coinbase bit, so `outputCoinClean` is false —
i.e. not the BIP30 exception lane), the block-level verdict is `unclean`. -/
@[rule "BLK-106"]
theorem disconnectBlock_two_unclean (u : UtxoSet) (height : UInt32)
    (cb tx : Tx) (undo : List (OutPoint × Coin)) (o : Nat)
    (ho : o < tx.vout.length)
    (hm : outputCoinClean u height tx o = false) :
    ∃ st, disconnectBlock u height [cb, tx] [undo] = .ok st ∧ st.2 = false := by
  refine ⟨_, disconnectBlock_two u height cb tx undo, ?_⟩
  have hc : ((List.range tx.vout.length).all
      (fun o => outputCoinClean u height tx o)) = false :=
    listAll_false_of_mem (fun o => outputCoinClean u height tx o)
      (List.range tx.vout.length) o (List.mem_range.mpr ho) hm
  simp [hc]

/-- The per-output match decomposed into the four Core fields: value,
scriptPubKey, creation height and coinbase bit.  This is the field-level
form of `outputCoinMatches` used by the INV-117 whole-rule theorem. -/
theorem outputCoinMatches_of_fields (u : UtxoSet) (height : UInt32) (tx : Tx)
    (o : Nat) (out : TxOut) (c : Coin)
    (hoff : tx.vout[o]? = some out)
    (hspk : scriptUnspendable out.scriptPubKey = false)
    (hlook : u (txidPreimageKey tx OutPoint.null (UInt32.ofNat o)) = some c)
    (hvalue : c.value = out.value)
    (hscript : c.scriptPubKey = out.scriptPubKey)
    (hheight : c.height = height)
    (hcoinbase : c.isCoinbase = tx.isCoinBase) :
    outputCoinMatches u height tx o = true := by
  have hscriptBeq : (c.scriptPubKey == out.scriptPubKey) = true := by
    rw [hscript]
    cases out.scriptPubKey with
    | mk b => simp [BEq.beq, bytesBEq]
  unfold outputCoinMatches
  rw [hoff]
  simp [hspk, hlook, hvalue, hscriptBeq, hheight, hcoinbase]

/-- The exact truth condition of `outputCoinClean`: an output is clean
either because all four coin fields match, or because it is a coinbase
output of one of the two historical BIP30 exception blocks. -/
theorem outputCoinClean_eq_true_iff (u : UtxoSet) (height : UInt32) (tx : Tx)
    (o : Nat) :
    outputCoinClean u height tx o = true ↔
      outputCoinMatches u height tx o = true ∨
        (tx.isCoinBase = true ∧ bip30DisconnectRelaxed height = true) := by
  unfold outputCoinClean
  rw [Bool.or_eq_true, Bool.and_eq_true]

/-- A matching output is clean. -/
theorem outputCoinClean_of_matches (u : UtxoSet) (height : UInt32) (tx : Tx)
    (o : Nat) (h : outputCoinMatches u height tx o = true) :
    outputCoinClean u height tx o = true := by
  unfold outputCoinClean
  rw [h]
  simp

/-- Coinbase outputs are clean at the two historical BIP30 disconnect
heights even when the duplicate coinbase's value/script/height/coinbase
fields do not match (validation.cpp:2200-2226). -/
theorem outputCoinClean_bip30 (u : UtxoSet) (height : UInt32) (tx : Tx)
    (o : Nat) (hcoinbase : tx.isCoinBase = true)
    (hrelaxed : bip30DisconnectRelaxed height = true) :
    outputCoinClean u height tx o = true := by
  unfold outputCoinClean
  rw [hcoinbase, hrelaxed]
  simp

/-- **INV-117 (the whole disconnect rule).**  For a block with a
coinbase and two non-coinbase transactions, `[cb, t1, t2]`, and two undo
batches, `disconnectBlock`:

* walks the transactions in **reverse** order: it re-checks `t2` against
  the pre-disconnect view, undoes `t2` with `u2`, re-checks `t1` against
  the view `t2` produced, undoes `t1` with `u1`, and only then re-checks
  the coinbase against the fully restored view;
* re-checks each non-unspendable output against the coin created under
  the transaction's own txid key, comparing the output value and
  scriptPubKey, the creation height, and the coinbase bit (the four
  fields `outputCoinMatches_of_fields` isolates);
* accepts a coinbase output of the two BIP30 duplicate-coinbase blocks,
  91722 and 91812, even when those fields do not match
  (`outputCoinClean_bip30`).

The block verdict is `true` exactly when every output of `t2` is clean in
the old view, every output of `t1` is clean in `t2`'s post-undo view, and
every output of `cb` is clean in the fully restored view. -/
@[rule "INV-117"]
theorem disconnectBlock_inv117 (u : UtxoSet) (height : UInt32)
    (cb t1 t2 : Tx) (u1 u2 : List (OutPoint × Coin))
    (hcoinbase : cb.isCoinBase = true)
    (o : Nat) (out : TxOut) (hout : t2.vout[o]? = some out)
    (c : Coin) (hlook : u (txidPreimageKey t2 OutPoint.null (UInt32.ofNat o)) = some c)
    (hspk : scriptUnspendable out.scriptPubKey = false)
    (hvalue : c.value = out.value)
    (hscript : c.scriptPubKey = out.scriptPubKey)
    (hheight : c.height = height)
    (hcoin : c.isCoinbase = t2.isCoinBase)
    (ht2Clean : ∀ q, q < t2.vout.length →
      outputCoinClean u height t2 q = true)
    (ht1Clean : ∀ q, q < t1.vout.length →
      outputCoinClean (undoCoins u u2 t2 (txidPreimageKey t2) height) height t1 q = true)
    (hcbClean : ∀ q, q < cb.vout.length →
      outputCoinClean
        (undoCoins (undoCoins u u2 t2 (txidPreimageKey t2) height)
          u1 t1 (txidPreimageKey t1) height) height cb q = true) :
    disconnectBlock u height [cb, t1, t2] [u1, u2] =
        .ok (undoCoins (undoCoins u u2 t2 (txidPreimageKey t2) height)
              u1 t1 (txidPreimageKey t1) height, true) ∧
      outputCoinMatches u height t2 o = true ∧
      outputCoinClean u height t2 o = true ∧
      ((height.toNat = 91722 ∨ height.toNat = 91812) →
        ∀ q, q < cb.vout.length →
          outputCoinClean
            (undoCoins (undoCoins u u2 t2 (txidPreimageKey t2) height)
              u1 t1 (txidPreimageKey t1) height) height cb q = true) ∧
      (∀ q, q < cb.vout.length →
        outputCoinClean
          (undoCoins (undoCoins u u2 t2 (txidPreimageKey t2) height)
            u1 t1 (txidPreimageKey t1) height) 91722 cb q = true ∧
        outputCoinClean
          (undoCoins (undoCoins u u2 t2 (txidPreimageKey t2) height)
            u1 t1 (txidPreimageKey t1) height) 91812 cb q = true) := by
  have hmatch : outputCoinMatches u height t2 o = true :=
    outputCoinMatches_of_fields u height t2 o out c hout hspk hlook
      hvalue hscript hheight hcoin
  have ht2All : (List.range t2.vout.length).all
      (fun q => outputCoinClean u height t2 q) = true := by
    rw [List.all_eq_true]
    intro q hq
    exact ht2Clean q (List.mem_range.mp hq)
  have ht1All : (List.range t1.vout.length).all
      (fun q => outputCoinClean
        (undoCoins u u2 t2 (txidPreimageKey t2) height) height t1 q) = true := by
    rw [List.all_eq_true]
    intro q hq
    exact ht1Clean q (List.mem_range.mp hq)
  have hcbAll : (List.range cb.vout.length).all
      (fun q => outputCoinClean
        (undoCoins (undoCoins u u2 t2 (txidPreimageKey t2) height)
          u1 t1 (txidPreimageKey t1) height) height cb q) = true := by
    rw [List.all_eq_true]
    intro q hq
    exact hcbClean q (List.mem_range.mp hq)
  refine ⟨?_, hmatch, outputCoinClean_of_matches u height t2 o hmatch, ?_, ?_⟩
  · rw [disconnectBlock_three]
    simp [ht2All, ht1All, hcbAll]
  · intro he q hq
    have hrelaxed : bip30DisconnectRelaxed height = true := by
      unfold bip30DisconnectRelaxed
      simpa using he
    exact outputCoinClean_bip30
      (undoCoins (undoCoins u u2 t2 (txidPreimageKey t2) height)
        u1 t1 (txidPreimageKey t1) height) height cb q hcoinbase hrelaxed
  · intro q hq
    exact ⟨outputCoinClean_bip30
        (undoCoins (undoCoins u u2 t2 (txidPreimageKey t2) height)
          u1 t1 (txidPreimageKey t1) height) 91722 cb q hcoinbase
        bip30_relaxed_91722,
      outputCoinClean_bip30
        (undoCoins (undoCoins u u2 t2 (txidPreimageKey t2) height)
          u1 t1 (txidPreimageKey t1) height) 91812 cb q hcoinbase
        bip30_relaxed_91812⟩

/-- BLK-106 (restore/involutivity): undoing a transaction with the undo
batch that `updateCoins` would have produced restores the post-coinbase
state exactly (the non-overwrite side condition is the BIP30 boundary,
`updateCoins_undo`).  The coinbase layer is not undone (Core's `i > 0`
guard), so the restored state is the state after the coinbase was
connected. -/
@[rule "BLK-106"]
theorem disconnectBlock_two_restores (u : UtxoSet) (height : UInt32)
    (cb tx : Tx)
    (h5 : ∀ q ∈ addedKeys tx (txidPreimageKey tx) height,
      (updateCoins u cb (txidPreimageKey cb) height) q = none ∨
        tx.vin.any (fun i => i.prevout == q) = true) :
    ∃ st, disconnectBlock
        (updateCoins (updateCoins u cb (txidPreimageKey cb) height) tx
          (txidPreimageKey tx) height) height
        [cb, tx]
        [spentUndo (updateCoins u cb (txidPreimageKey cb) height) tx]
      = .ok st ∧ st.1 = updateCoins u cb (txidPreimageKey cb) height := by
  refine ⟨_, disconnectBlock_two
    (updateCoins (updateCoins u cb (txidPreimageKey cb) height) tx
      (txidPreimageKey tx) height) height cb tx
    (spentUndo (updateCoins u cb (txidPreimageKey cb) height) tx), ?_⟩
  exact updateCoins_undo (updateCoins u cb (txidPreimageKey cb) height) tx
    (txidPreimageKey tx) height h5

/-- BLK-107: unspendable outputs are excluded from disconnect
re-verification (symmetry with BLK-093: AddCoin never stored them, so
DisconnectBlock must not re-check them — `scriptUnspendable` from the ledger). -/
@[rule "BLK-107"]
def disconnectRelevant (c : Coin) : Bool := ¬ scriptUnspendable c.scriptPubKey

/-- An OP_RETURN coin is never disconnect-relevant. -/
theorem disconnectRelevant_op_return (v : Amount) (h : UInt32) (cb : Bool) :
    disconnectRelevant ⟨v, h, cb, scriptOf [0x6a]⟩ = false := by
  have h1 : scriptUnspendable (scriptOf [0x6a]) = true := by
    unfold scriptUnspendable scriptOf
    decide
  unfold disconnectRelevant
  rw [h1]
  rfl

/-- BLK-108: undo/tx count consistency (validation.cpp:2180-2185):
`vtxundo.size() + 1 == vtx.size()`, else treat as data corruption. -/
@[rule "BLK-108"]
def undoCountOk (vtx : List Tx) (vtxundo : List (List (OutPoint × Coin))) : Bool :=
  vtxundo.length + 1 = vtx.length

/-- A single-coinbase block has an empty undo batch. -/
theorem undoCountOk_coinbase_only (cb : Tx) : undoCountOk [cb] [] = true := rfl

/-! ## BLK-111/112: the mainnet genesis block -/

/-- Genesis merkle root, internal little-endian byte order (as stored in
the header; display form is its reverse). -/
def genesisMerkleRootInternal : ByteArray := bytesOf
  [0x3b,0xa3,0xed,0xfd,0x7a,0x7b,0x12,0xb2,0x7a,0xc7,0x2c,0x3e,0x67,0x76,0x8f,0x61,
   0x7f,0xc8,0x1b,0xc3,0x88,0x8a,0x51,0x32,0x3a,0x9f,0xb8,0xaa,0x4b,0x1e,0x5e,0x4a]

/-- BLK-111: the mainnet genesis header
(kernel/chainparams.cpp:158 @cce32b168: `CreateGenesisBlock(1231006505,
2083236893, 0x1d00ffff, 1, 50 * COIN)`). The display hash
`000000000019d668…ce26f` is pinned by dsha256 in
`spec/Test/Crypto/SeamHashTest.lean`. -/
@[rule "BLK-111"]
def genesisHeader : BlockHeader :=
  { version := 1, hashPrevBlock := zeroBytes 32,
    hashMerkleRoot := genesisMerkleRootInternal,
    time := 1231006505, bits := 0x1d00ffff, nonce := 2083236893 }

theorem genesis_header_version : genesisHeader.version = 1 := rfl
theorem genesis_header_time : genesisHeader.time = 1231006505 := rfl
theorem genesis_header_bits : genesisHeader.bits = 0x1d00ffff := rfl
theorem genesis_header_nonce : genesisHeader.nonce = 2083236893 := rfl

/-- The genesis difficulty is exactly difficulty-1 (0x1d00ffff). -/
theorem genesis_pow_difficulty_one :
    compactTarget genesisHeader.bits = 0xffff * 256 ^ 26 := by
  rw [genesis_header_bits]
  exact compactTarget_difficulty_one

/-- BLK-112: the genesis output script — `P2PK` to Satoshi's
never-spent pubkey: `OP_PUSH65 <04678afd…b6bf11d5f> OP_CHECKSIG`
(kernel/chainparams.cpp:72). -/
@[rule "BLK-112"]
def genesisPubkey : ByteArray := bytesOf
  [0x04,0x67,0x8a,0xfd,0xb0,0xfe,0x55,0x48,0x27,0x19,0x67,0xf1,0xa6,0x71,0x30,0xb7,
   0x10,0x5c,0xd6,0xa8,0x28,0xe0,0x39,0x09,0xa6,0x79,0x62,0xe0,0xea,0x1f,0x61,0xde,
   0xb6,0x49,0xf6,0xbc,0x3f,0x4c,0xef,0x38,0xc4,0xf3,0x55,0x04,0xe5,0x1e,0xc1,0x12,
   0xde,0x5c,0x38,0x4d,0xf7,0xba,0x0b,0x8d,0x57,0x8a,0x4c,0x70,0x2b,0x6b,0xf1,0x1d,0x5f]

/-- The genesis coinbase scriptSig — the famous quirk: it pushes the
**nBits value 486604799** (`0x04 ‖ ff ff 00 1d`), then `CScriptNum(4)`
as a 1-byte push, then the 69-byte Times headline. -/
def genesisScriptSig : ByteArray := bytesOf
  ([0x04,0xff,0xff,0x00,0x1d,0x01,0x04,0x45] ++
   [0x54,0x68,0x65,0x20,0x54,0x69,0x6d,0x65,0x73,0x20,0x30,0x33,0x2f,0x4a,0x61,0x6e,
    0x2f,0x32,0x30,0x30,0x39,0x20,0x43,0x68,0x61,0x6e,0x63,0x65,0x6c,0x6c,0x6f,0x72,
    0x20,0x6f,0x6e,0x20,0x62,0x72,0x69,0x6e,0x6b,0x20,0x6f,0x66,0x20,0x73,0x65,0x63,
    0x6f,0x6e,0x64,0x20,0x62,0x61,0x69,0x6c,0x6f,0x75,0x74,0x20,0x66,0x6f,0x72,0x20,
    0x62,0x61,0x6e,0x6b,0x73])

/-- The genesis scriptPubKey: push-65 + pubkey + OP_CHECKSIG = 67 bytes. -/
def genesisScriptPubKey : ByteArray :=
  bytesOf [0x41] ++ genesisPubkey ++ bytesOf [0xac]

/-- The genesis coinbase transaction: one null-prevout input, one output
paying 50 COIN to the P2PK script (BLK-027's IsCoinBase template). -/
def genesisCoinbaseTx : Tx :=
  { version := 1,
    vin := [⟨OutPoint.null, ⟨genesisScriptSig⟩, 0xFFFFFFFF⟩],
    vout := [⟨50 * COIN, ⟨genesisScriptPubKey⟩⟩],
    locktime := 0, witness := [] }

theorem genesis_pubkey_shape :
    genesisPubkey.size = 65 ∧ (genesisPubkey.get! 0).toNat = 0x04 ∧
      (genesisPubkey.get! 64).toNat = 0x5f := by unfold genesisPubkey bytesOf; decide

theorem genesis_scriptsig_len : genesisScriptSig.size = 77 := by
  unfold genesisScriptSig bytesOf; decide

theorem genesis_scriptpubkey_len : genesisScriptPubKey.size = 67 := by
  unfold genesisScriptPubKey genesisPubkey bytesOf; decide

theorem genesis_scriptpubkey_template :
    (genesisScriptPubKey.get! 0).toNat = 0x41 ∧
    (genesisScriptPubKey.get! 1).toNat = 0x04 ∧
    (genesisScriptPubKey.get! 66).toNat = 0xac := by
  unfold genesisScriptPubKey genesisPubkey bytesOf; decide

theorem genesis_coinbase_isCoinBase : genesisCoinbaseTx.isCoinBase = true := by
  decide

instance : Inhabited TxOut := ⟨⟨0, Script.empty⟩⟩

theorem genesis_coinbase_value :
    genesisCoinbaseTx.vout.length = 1 ∧ genesisCoinbaseTx.vout.head!.value = 50 * COIN := by
  decide

/-- The genesis subsidy: `GetBlockSubsidy(0) = 50·COIN` (the ledger layer's
`blockSubsidy`, halvings 0). -/
theorem genesis_subsidy : Bitcoin.Conservation.blockSubsidy 0 = 50 * COIN := by
  unfold Bitcoin.Conservation.blockSubsidy Bitcoin.Conservation.halvingsAt
  decide

/-! ## BLK-122/123/124/127: DoS & trust parameters (NOT consensus) -/

/-- BLK-122: mainnet `nMinimumChainWork`
(kernel/chainparams.cpp:141 @cce32b168). Headers-first sync does not
index headers below this accumulated work (`too-little-chainwork`,
validation.cpp:4270-4276) — anti-DoS, not consensus: every honest chain
exceeds it by orders of magnitude. -/
@[rule "BLK-122", rule "INV-149"]
def nMinimumChainWorkMainnet : Nat :=
  0x000000000000000000000000000000000000000145ec036acc5ba740052af1a0

/-- The min-chain-work gate. -/
@[rule "INV-147"]
def minChainWorkOk (work : Nat) : Bool := nMinimumChainWorkMainnet ≤ work

theorem minChainWorkOk_zero_false : minChainWorkOk 0 = false := by decide

theorem minChainWorkOk_at_limit : minChainWorkOk nMinimumChainWorkMainnet = true := by
  unfold minChainWorkOk
  rfl

/-- BLK-123: mainnet `defaultAssumeValid`
(kernel/chainparams.cpp:142 @cce32b168) — block 966143. -/
def assumevalidMainnetHeight : Nat := 966143

/-- BLK-123: the assumevalid skip (validation.cpp:2344-2400): script
checks are skippable for inputs whose coins sit strictly below the
assumevalid ancestor, gated by the 2-week equivalent-time guard.
Trust-parameterized, not consensus: with `none` nothing is skipped. -/
@[rule "BLK-123", rule "INV-148"]
def assumevalidSkipped (assumevalid : Option Nat) (inputHeight : Nat)
    (timeGuardOk : Bool) : Bool :=
  (assumevalid.map (fun a => if inputHeight < a then timeGuardOk else false)).getD false

theorem assumevalidSkipped_none (inputHeight : Nat) (timeGuardOk : Bool) :
    assumevalidSkipped none inputHeight timeGuardOk = false := rfl

theorem assumevalidSkipped_at_or_above (a h : Nat) (g : Bool) (hle : a ≤ h) :
    assumevalidSkipped (some a) h g = false := by
  simp only [assumevalidSkipped, Option.map_some, Option.getD_some]
  rw [if_neg (Nat.not_lt.mpr hle)]

theorem assumevalidSkipped_below_no_guard (a h : Nat)
    (hlt : h < a) : assumevalidSkipped (some a) h false = false := by
  simp only [assumevalidSkipped, Option.map_some, Option.getD_some]
  rw [if_pos hlt]

/-- BLK-124: parallel script verification (`CCheckQueue`,
validation.cpp:2344-2400): per-tx verdicts are pure functions, so ANY
partition of `vtx` yields the same verdict list as serial execution. -/
@[rule "BLK-124"]
def scriptVerdicts (check : Tx → Bool) (vtx : List Tx) : List Bool :=
  vtx.map check

theorem scriptVerdicts_partition_invariant (check : Tx → Bool) (vtx : List Tx)
    (n : Nat) :
    scriptVerdicts check (vtx.take n ++ vtx.drop n) = scriptVerdicts check vtx := by
  simp [scriptVerdicts, List.take_append_drop]

/-- BLK-127: `fChecked`/`m_checked_*` memoization flags (validation.h,
node/blockstorage) are memoization only: when a cached verdict is
present it must agree with the fresh verdict; a miss falls through to
the fresh check. -/
@[rule "BLK-127"]
def memoVerdict (cached : Option Bool) (fresh : Bool) : Bool := cached.getD fresh

theorem memoVerdict_agrees (cached : Option Bool) (fresh : Bool)
    (h : cached = some fresh) : memoVerdict cached fresh = fresh := by
  subst h; rfl

theorem memoVerdict_miss (fresh : Bool) : memoVerdict none fresh = fresh := rfl

/-! ## BLK-125: the 64-byte-tx mutation guard -/

/-- BLK-125 (validation.cpp:3868-3874): a coinbase-less block that
contains a 64-byte serialized tx is reported as BLOCK_MUTATED — a
relay-path distinction only (both verdicts reject; the 64-byte size
collides with the block-hash/tx-hash ambiguity exploited by the
duplicate-injection weakness). -/
@[rule "BLK-125"]
def mutated64ByteTx (vtx : List Tx) : Bool :=
  match vtx with
  | cb :: _ => ¬ cb.isCoinBase && vtx.any (fun t => serTxSize t = 64)
  | [] => false

theorem mutated64ByteTx_nil : mutated64ByteTx [] = false := rfl

theorem mutated64ByteTx_coinbaseFirst (cb : Tx) (rest : List Tx)
    (hcb : cb.isCoinBase = true) : mutated64ByteTx (cb :: rest) = false := by
  unfold mutated64ByteTx
  simp [hcb]

/-! ## BLK-126: the signet challenge -/

/-- BLK-126: the default signet challenge (kernel/signet.h:20, BIP325):
a 1-of-2 CHECKMULTISIG script, 71 bytes. -/
@[rule "BLK-126"]
def signetDefaultChallenge : ByteArray := bytesOf
  [0x51,0x21,
   0x03,0xad,0x5e,0x0e,0xda,0xd1,0x8c,0xb1,0xf0,0xfc,0x0d,0x28,0xa3,0xd4,0xf1,0xf3,
   0xe4,0x45,0x64,0x03,0x37,0x48,0x9a,0xbb,0x10,0x40,0x4f,0x2d,0x1e,0x08,0x6b,0xe4,
   0x30,0x21,
   0x03,0x59,0xef,0x50,0x21,0x96,0x4f,0xe2,0x2d,0x6f,0x8e,0x05,0xb2,0x46,0x3c,0x95,
   0x40,0xce,0x96,0x88,0x3f,0xe3,0xb2,0x78,0x76,0x0f,0x04,0x8f,0x51,0x89,0xf2,0xe6,
   0xc4,0x52,0xae]

theorem signetDefaultChallenge_shape :
    signetDefaultChallenge.size = 71 ∧
    (signetDefaultChallenge.get! 0).toNat = 0x51 ∧
    (signetDefaultChallenge.get! 70).toNat = 0xae := by decide

/-- BLK-126: on signet, the block solution must satisfy the challenge
script when spent as a witness (`CheckSignetBlockSolution`, BIP325
§"consensus"); abstracted over the script engine. Nets with
`signet_blocks = false` (mainnet/testnet/testnet4/regtest) skip the
check entirely. -/
def signetSolutionOk (satisfies : ByteArray → ByteArray → Bool)
    (challenge solution : ByteArray) : Bool := satisfies challenge solution

/-- The solution check applies only where `signet_blocks` is set. -/
def signetCheckApplies (signetBlocks : Bool) : Bool := signetBlocks

theorem signetCheckApplies_mainnet : signetCheckApplies false = false := rfl

/-! ## BLK-128: the coinbase witness reserved value -/

/-- BLK-128 (BIP141 §"mining"): when segwit is active the block
constructor fills a 32-byte zero reserved value into the coinbase
witness when none was given. Construction-side; validation only requires
BLK-018's exact-shape check. -/
@[rule "BLK-128"]
def reservedValueFill (segwitActive : Bool) (reserved : ByteArray) : ByteArray :=
  if segwitActive && reserved.size = 0 then zeroBytes 32 else reserved

theorem reservedValueFill_default (segwitActive : Bool)
    (h : segwitActive = true) :
    reservedValueFill segwitActive ByteArray.empty = zeroBytes 32 := by
  unfold reservedValueFill
  simp [h]

theorem reservedValueFill_keeps (segwitActive : Bool) (r : ByteArray)
    (hr : r.size ≠ 0) : reservedValueFill segwitActive r = r := by
  unfold reservedValueFill
  simp [hr]

/-! ## BLK-129: constant-space merkle path replay -/

/-- BLK-129: constant-space merkle path replay — fold the sibling list
(`(isLeftSibling, hash)` per level) with the level hash
`SHA256d(left ‖ right)`; the equivalence with the level-duplication tree
(`merkleLevel` in Capstone.Merkle) is exactly this replay. -/
@[rule "BLK-129"]
def merklePathRoot (leaf : ByteArray) (path : List (Bool × ByteArray)) : ByteArray :=
  path.foldl (fun acc p => if p.1 then pairHash p.2 acc else pairHash acc p.2) leaf

/-- Path verification: replaying the path reproduces the root. -/
def merklePathVerify (root leaf : ByteArray) (path : List (Bool × ByteArray)) : Bool :=
  bytesBEq (merklePathRoot leaf path) root

theorem bytesBEq_self (b : ByteArray) : bytesBEq b b = true := by
  unfold bytesBEq
  simp

/-- Soundness: the path replayed from the leaf verifies against its own
root. -/
theorem merklePathRoot_sound (leaf : ByteArray) (path : List (Bool × ByteArray)) :
    merklePathVerify (merklePathRoot leaf path) leaf path = true := by
  unfold merklePathVerify
  exact bytesBEq_self _

theorem merklePathVerify_empty (root leaf : ByteArray) :
    merklePathVerify root leaf [] = bytesBEq leaf root := rfl

/-! ## BLK-130: the timestamp window -/

/-- BLK-130: `MAX_FUTURE_BLOCK_TIME` (validation.h) = 7200 s — the same
constant defines the headers-sync `TIMESTAMP_WINDOW`; the
`timeNotTooNew` composes with it. -/
@[rule "BLK-130"]
def MAX_FUTURE_BLOCK_TIME : Nat := 7200

/-- The headers-sync timestamp window. -/
def TIMESTAMP_WINDOW : Nat := MAX_FUTURE_BLOCK_TIME

theorem TIMESTAMP_WINDOW_eq : TIMESTAMP_WINDOW = 7200 := rfl

/-! ## Axiom pin for the INV-117 whole-rule theorem -/

/-- info: 'Bitcoin.Block.Params.disconnectBlock_inv117' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms disconnectBlock_inv117

end Bitcoin.Block.Params
