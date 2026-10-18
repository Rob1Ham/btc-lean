import Bitcoin.Ledger.Interface
import Bitcoin.Conservation.Interface
import Bitcoin.Block.Connect

/-!
# BitcoinProofs.Theorems.Genchain — synthetic-chain theorems (G03)

Over the G01/G02 synthetic-chain format this module states and proves,
sorry-free:

1. **Fold agreement** (`genchain_fold_agrees`, general form
   `connectChainL_iff_genChainOk`): applying the chain's blocks in order
   through the pure ledger fold (`Bitcoin.Ledger.applyBlockL`, chained
   block by block at each block's connection height) leaves EXACTLY the
   UTXO set the generator predicts — where "the generator predicts" is
   the generator's own documented accounting (`genChainOkFrom`), which
   checks the construction and computes the manifest in one pass. The
   two computations agree iff they agree: the fold succeeds exactly
   when the generator's construction check succeeds, and then the UTXO
   lists are equal.
2. **No-double-spend by construction** (`genchain_no_double_spend`,
   `genStep_inputs_available`, `genStep_bip30_fresh`): under the
   generator's construction every non-coinbase input names a coin
   present in the predicted view at spend time (`inputsAvailable` at
   each step), no outpoint is ever re-created into the live view
   (BIP30 freshness), and the whole-chain fold therefore never fails.
3. **Subsidy-transition correctness at the halving boundaries in the
   synthetic chain** (concrete decide-theorems): at each of the four
   documented scaled boundaries (500/1000/1500/2000, mirroring
   210000/420000/630000/840000) the generated coinbase pays exactly the
   halved subsidy and `cbAmountOk` accepts it; the mainnet-schedule
   link `genSubsidy 210000 = blockSubsidy` is proved for the real
   210,000-block epochs.

## The documented G01 chain schema (JSON shape)

Per block (the shape G01's specification documents: "JSON blocks + a UTXO-set
manifest"):

```json
{"height": <int ≥ 1>,
 "txs":    [{"isCoinbase": bool,
             "vin":  [{"prevTxid": <hex32>, "prevN": <int>},
                      ... coinbase: exactly the null prevout ...],
             "vout": [{"value": <sats>, "scriptPubKey": <hex>}, ...]}]}
```

manifest entry (one per non-unspendable output):
`{"txidPreimage": <hex of the base serialization>, "n": <int>,
  "value": <sats>, "height": <creation height>, "isCoinbase": bool,
  "scriptPubKey": <hex>}` — coins are keyed by the txid PREIMAGE
(`Bitcoin.Ledger.txidPreimageKey`), the documented simplification
pending the hash floor; `n` is the output index.

## Documented simplifications (instance-level, PROPOSED until G01 lands)

* `nBits` constant, timestamps +1s: PoW/time live in `validateBlock`'s
  header gates (CapstonePowCor), NOT in the ledger fold — out of scope
  here by construction.
* Scaled halving interval: the synthetic chain is 2000 blocks, so the
  210,000-block epoch is scaled to 500 (`GEN_HALVING_INTERVAL`), giving
  boundaries 500/1000/1500/2000 mirroring 210000/420000/630000/840000.
  The boundary structure theorems are scale-invariant; the concrete
  numerals below are the scaled instance.
* Coinbases pay exactly the subsidy (0 fees); fee-carrying coinbases
  are governed by the conservation theorems (CapstoneConservationCor).
* BIP30 enforcement is carried as a per-block hypothesis (`hall`);
  at the synthetic heights it holds definitionally
  (`bip30Enforced_at_500` / `_at_2000`).
* The schema-level statements are VERIFIED here; INSTANCE-level claims
  (the actual 2000 generated blocks satisfying the hypotheses) are
  PROPOSED until G01's generator + G02's driver land.

## Axiom footprints

No `sorry`, no `native_decide`, no `unsafe`/`partial`. Theorems proved
by `induction`/`rw`/`simp` carry at most
`[propext, Classical.choice, Quot.sound]` (the core layer's footprint);
the `decide`/`rfl` boundary theorems carry none.
-/

namespace BitcoinProofs.Theorems.Genchain

open Bitcoin.Data Bitcoin.Ledger Bitcoin.Conservation Bitcoin.Block.Connect
  Bitcoin.TxValidation

/-! ## The G01 schema (decode: JSON shape → core `Tx`) -/

/-- Byte payload of the schema (`prevTxid`, `scriptPubKey`); `Nat`
components truncate to `UInt8` (documented generator precondition:
bytes < 256). -/
def genBytes (l : List Nat) : ByteArray :=
  l.foldl (fun acc b => acc.push (b.toUInt8)) ByteArray.empty

def genScript (l : List Nat) : Script := ⟨genBytes l⟩

/-- One schema output: `{"value": sats, "scriptPubKey": hex}`. -/
structure GenOut where
  value : Nat
  scriptPubKey : List Nat

/-- One schema input: `{"prevTxid": hex, "prevN": int}`. -/
structure GenIn where
  prevTxid : List Nat
  prevN : Nat

/-- One schema transaction. -/
structure GenTx where
  isCoinbase : Bool
  vin : List GenIn
  vout : List GenOut

/-- One schema block: connection height + txs, coinbase first. -/
structure GenBlock where
  height : Nat
  txs : List GenTx

/-- A synthetic chain: the list of blocks in order. -/
abbrev GenChain := List GenBlock

/-- Schema → core decode (total; `UInt32.ofNat` truncation is the
documented generator precondition `prevN < 2^32`). -/
def decodeGenOut (o : GenOut) : TxOut := ⟨(o.value : Int), genScript o.scriptPubKey⟩

def decodeGenIn (i : GenIn) : TxIn :=
  ⟨⟨genBytes i.prevTxid, UInt32.ofNat i.prevN⟩, Script.empty, 0xFFFFFFFF⟩

def decodeGenTx (t : GenTx) : Tx :=
  ⟨1, t.vin.map decodeGenIn, t.vout.map decodeGenOut, 0, []⟩

/-- Schema block → (connection height, decoded txs). -/
def decodeGenBlock (b : GenBlock) : UInt32 × List Tx :=
  (UInt32.ofNat b.height, b.txs.map decodeGenTx)

def decodeGenChain (c : GenChain) : List (UInt32 × List Tx) := c.map decodeGenBlock

/-! ## The generator's predicted UTXO accounting

The generator's documented manifest rule: remove each spent prevout;
prepend each non-unspendable output keyed by the txid preimage at the
connection height; coinbases drop nothing. Spelled independently of
`updateCoinsL`, then proved equal — the schema contract. -/

/-- Generator: drop the coins `tx` spends (coinbase exempt — INV-110). -/
def genSpendDrop (l : List (OutPoint × Coin)) (tx : Tx) : List (OutPoint × Coin) :=
  if tx.isCoinBase then l
  else l.filter (fun p => !(tx.vin.any fun i => i.prevout == p.1))

/-- Generator: emit `tx`'s spendable outputs (OP_RETURN never stored —
INV-112), keyed by the txid preimage. -/
def genEmit (tx : Tx) (height : UInt32) : List (OutPoint × Coin) :=
  (List.range tx.vout.length).filterMap (fun k =>
    let o := tx.vout.getD k ⟨0, Script.empty⟩
    if scriptUnspendable o.scriptPubKey then none
    else some (txidPreimageKey tx OutPoint.null (UInt32.ofNat k),
               ⟨o.value, height, tx.isCoinBase, o.scriptPubKey⟩))

/-- One generator manifest step. -/
def genUpdate (l : List (OutPoint × Coin)) (tx : Tx) (height : UInt32) :
    List (OutPoint × Coin) :=
  genEmit tx height ++ genSpendDrop l tx

/-- THE SCHEMA CONTRACT: the generator's step IS the ledger's
`updateCoins` at the canonical key. -/
theorem genUpdate_eq (l : List (OutPoint × Coin)) (tx : Tx) (height : UInt32) :
    genUpdate l tx height = updateCoinsL l tx (txidPreimageKey tx) height := by
  unfold genUpdate updateCoinsL genSpendDrop genEmit addedCoins txidPreimageKey
  by_cases hcb : tx.isCoinBase = true
  · rw [if_pos hcb]
    have hf : l.filter
        (fun p => tx.isCoinBase || !(tx.vin.any fun i => i.prevout == p.1)) = l := by
      rw [List.filter_eq_self]
      intro a _
      simp [hcb]
    rw [hf]
  · rw [if_neg hcb]
    simp only [hcb, Bool.false_or]

/-! ## The generator's construction check (= prediction + well-formedness)

One pass: per tx — the per-tx UTXO gates in ConnectBlock's order
(inputs available, coinbase maturity), then the manifest update. BIP30
is NOT a per-tx gate post-D4c-2: it is the pre-block pristine-view
overlap check (Core 2466-2475), so it sits ONCE in front of the fold
(`genTxsOk`), exactly mirroring ledger `applyBlockL`. A chain the
generator emits by construction satisfies all of these; the fold
returns the predicted final manifest or `none`. -/

/-- One construction-checked generator step (BIP30-free, D4c-2). -/
def genStepOk (l : List (OutPoint × Coin)) (tx : Tx) (height : UInt32) :
    Option (List (OutPoint × Coin)) :=
  if tx.isCoinBase then
    some (genUpdate l tx height)
  else if !inputsAvailable (viewOf l) tx then
    none                                     -- double-spend / missing input
  else if !maturityOk (viewOf l) tx height then
    none                                     -- premature coinbase spend
  else some (genUpdate l tx height)

/-- The generator's per-block manifest fold (BIP30-free inner fold). -/
def genTxsFold (l : List (OutPoint × Coin)) (height : UInt32) :
    List Tx → Option (List (OutPoint × Coin))
  | [] => some l
  | tx :: rest => (genStepOk l tx height).bind fun l' => genTxsFold l' height rest

/-- The generator's per-block manifest check: Core 2466-2475's pristine
pre-block BIP30 overlap gate, then the inner fold — the same shape as
ledger `applyBlockL`. -/
def genTxsOk (l : List (OutPoint × Coin)) (height : UInt32) (txs : List Tx) :
    Option (List (OutPoint × Coin)) :=
  if (bip30BlockCollision (viewOf l) txidPreimageKey txs height
      && bip30Enforced height) then
    none
  else genTxsFold l height txs

/-- Block level: a block MUST open with its coinbase
(`bad-cb-missing`, ConnectBlock:2540-2545). -/
def genBlockOk (l : List (OutPoint × Coin)) (txs : List Tx) (height : UInt32) :
    Option (List (OutPoint × Coin)) :=
  match txs with
  | [] => none
  | cb :: _ => if cb.isCoinBase then genTxsOk l height txs else none

theorem genBlockOk_cons (l : List (OutPoint × Coin)) (cb : Tx) (rest : List Tx)
    (height : UInt32) :
    genBlockOk l (cb :: rest) height =
      if cb.isCoinBase then genTxsOk l height (cb :: rest) else none := rfl

/-- Schema predicate: every block is nonempty and opens with its
coinbase (the exact-once coinbase placement of ConnectBlock). -/
def genSchemaOk (bs : List (UInt32 × List Tx)) : Bool :=
  bs.all fun b =>
    match b.2 with
    | [] => false
    | cb :: _ => cb.isCoinBase

/-- Whole-chain construction check + predicted manifest, from seed `l`
(the synthetic chain starts from the EMPTY Utxo set,
validation.cpp:2330-2334). -/
def genChainOkFrom (l : List (OutPoint × Coin)) :
    List (UInt32 × List Tx) → Option (List (OutPoint × Coin))
  | [] => some l
  | (h, txs) :: rest => (genBlockOk l txs h).bind fun l' => genChainOkFrom l' rest

/-! ## The Lean side: chaining the pure ledger fold over the blocks -/

/-- `applyBlockL` chained block by block: each block folds at its own
connection height, threading the UTXO list — the executable validator
path (what G02's driver feeds the chain through). -/
def connectChainL (l : List (OutPoint × Coin)) (kf : Tx → Key) :
    List (UInt32 × List Tx) → Except BlockError (List (OutPoint × Coin))
  | [] => Except.ok l
  | (h, txs) :: rest =>
      (applyBlockL l kf txs h).bind fun l' => connectChainL l' kf rest

/-- `Except` → `Option` (self-contained; no `native_decide` anywhere). -/
def genOpt (e : Except BlockError (List (OutPoint × Coin))) :
    Option (List (OutPoint × Coin)) :=
  match e with
  | Except.ok l => some l
  | Except.error _ => none

/-- Bind lemmas (all definitional; this core has no `Except.bind_err` etc.). -/
theorem except_bind_err (e : BlockError)
    (f : List (OutPoint × Coin) → Except BlockError (List (OutPoint × Coin))) :
    (Except.error e).bind f = Except.error e := rfl

theorem except_bind_ok (x : List (OutPoint × Coin))
    (f : List (OutPoint × Coin) → Except BlockError (List (OutPoint × Coin))) :
    (Except.ok x).bind f = f x := rfl

theorem option_bind_none
    (f : List (OutPoint × Coin) → Option (List (OutPoint × Coin))) :
    (none : Option (List (OutPoint × Coin))).bind f = none := rfl

theorem option_bind_some (x : List (OutPoint × Coin))
    (f : List (OutPoint × Coin) → Option (List (OutPoint × Coin))) :
    (some x).bind f = f x := rfl

theorem genOpt_ok {m : List (OutPoint × Coin)}
    {e : Except BlockError (List (OutPoint × Coin))} (h : genOpt e = some m) :
    e = Except.ok m := by
  cases e with
  | ok l => simpa [genOpt] using h
  | error _ => simp [genOpt] at h

/-! ## 1. Step-, block-, and chain-level agreement -/

/-- The per-tx agreement: at `txidPreimageKey` keying, the checked
ledger step and the generator's checked manifest step are the same
BIP30-free computation up to error packaging (D4c-2: no collision gate
inside either step). -/
theorem applyTxStepL_genOpt (l : List (OutPoint × Coin)) (tx : Tx) (height : UInt32) :
    genOpt (applyTxStepL l tx (txidPreimageKey tx) height) = genStepOk l tx height := by
  unfold applyTxStepL genStepOk
  by_cases hcb : tx.isCoinBase = true
  · rw [if_pos hcb, if_pos hcb, genUpdate_eq]
    rfl
  · rw [if_neg hcb, if_neg hcb]
    by_cases hia : inputsAvailable (viewOf l) tx = true
    · have hn1 : ¬((!inputsAvailable (viewOf l) tx) = true) := by simp [hia]
      rw [if_neg hn1, if_neg hn1]
      by_cases hm : maturityOk (viewOf l) tx height = true
      · have hn2 : ¬((!maturityOk (viewOf l) tx height) = true) := by simp [hm]
        rw [if_neg hn2, if_neg hn2, genUpdate_eq]
        rfl
      · have hp2 : (!maturityOk (viewOf l) tx height) = true := by simp [hm]
        rw [if_pos hp2, if_pos hp2]
        rfl
    · have hp1 : (!inputsAvailable (viewOf l) tx) = true := by simp [hia]
      rw [if_pos hp1, if_pos hp1]
      rfl

/-- The per-block inner-fold agreement (BIP30-free): ledger
`applyBlockFoldL` vs the generator's `genTxsFold`. -/
theorem applyBlockFoldL_genOpt (height : UInt32) :
    ∀ (l : List (OutPoint × Coin)) (txs : List Tx),
      genOpt (applyBlockFoldL l txidPreimageKey txs height) = genTxsFold l height txs := by
  intro l txs
  induction txs generalizing l with
  | nil => rfl
  | cons tx rest ih =>
    rw [applyBlockFoldL, genTxsFold]
    cases hstep : applyTxStepL l tx (txidPreimageKey tx) height with
    | error e =>
      rw [except_bind_err e]
      simp only [genOpt]
      rw [← applyTxStepL_genOpt l tx height, hstep]
      simp only [genOpt]
      rfl
    | ok l' =>
      rw [except_bind_ok l']
      rw [← applyTxStepL_genOpt l tx height, hstep]
      simp only [genOpt, option_bind_some]
      exact ih l'

/-- The per-block agreement: ledger `applyBlockL` vs the generator's
`genTxsOk` — identical pristine pre-block BIP30 gate + inner fold. -/
theorem applyBlockL_genOpt (height : UInt32) :
    ∀ (l : List (OutPoint × Coin)) (txs : List Tx),
      genOpt (applyBlockL l txidPreimageKey txs height) = genTxsOk l height txs := by
  intro l txs
  unfold applyBlockL genTxsOk
  by_cases hg : (bip30BlockCollision (viewOf l) txidPreimageKey txs height
      && bip30Enforced height) = true
  · rw [if_pos hg, if_pos hg]
    rfl
  · rw [if_neg hg, if_neg hg]
    exact applyBlockFoldL_genOpt height l txs

/-- The whole-chain agreement (general form, any seed): the chained
ledger fold succeeds exactly when the generator's construction check
succeeds, and then the UTXO lists coincide. -/
theorem connectChainL_iff_genChainOk (l : List (OutPoint × Coin)) :
    ∀ (bs : List (UInt32 × List Tx)),
      bs.all (fun b => bip30Enforced b.1 = true) → genSchemaOk bs = true →
      genOpt (connectChainL l txidPreimageKey bs) = genChainOkFrom l bs := by
  intro bs
  induction bs generalizing l with
  | nil => intro _ _; rfl
  | cons b rest ih =>
    intro hall hsch
    rw [List.all_eq_true] at hall
    have hrest30 : rest.all (fun b => bip30Enforced b.1 = true) :=
      List.all_eq_true.mpr (fun x hx => hall x (List.mem_cons_of_mem _ hx))
    rw [genSchemaOk, List.all_eq_true] at hsch
    have hrestsch : genSchemaOk rest = true :=
      List.all_eq_true.mpr (fun x hx => hsch x (List.mem_cons_of_mem _ hx))
    -- the head block opens with its coinbase
    obtain ⟨hgt, txs⟩ := b
    cases txs with
    | nil =>
      have h0 := hsch _ (List.mem_cons_self)
      simp at h0
    | cons cb rest' =>
      have hcb : cb.isCoinBase = true := by
        have h0 := hsch _ (List.mem_cons_self)
        simpa using h0
      unfold connectChainL genChainOkFrom
      have hgb : genBlockOk l (cb :: rest') hgt = genTxsOk l hgt (cb :: rest') := by
        rw [genBlockOk_cons, if_pos hcb]
      cases hblk : applyBlockL l txidPreimageKey (cb :: rest') hgt with
      | error e =>
        rw [except_bind_err e]
        simp only [genOpt]
        have hgx : genTxsOk l hgt (cb :: rest') = none := by
          rw [← applyBlockL_genOpt hgt l (cb :: rest'), hblk]
          simp only [genOpt]
        rw [hgb, hgx]
        rfl
      | ok l' =>
        rw [except_bind_ok l']
        have hgx : genTxsOk l hgt (cb :: rest') = some l' := by
          rw [← applyBlockL_genOpt hgt l (cb :: rest'), hblk]
          simp only [genOpt]
        rw [hgb, hgx]
        exact ih l' hrest30 hrestsch

/-! ## 2. The named fold-agreement + no-double-spend theorems -/

/-- **THE synthetic-chain fold-agreement theorem**: applying the
chain's blocks in order (from the empty Utxo set, the documented
genesis state) through the pure ledger fold leaves EXACTLY the UTXO
set the generator predicts — `m`, the generator's own manifest. -/
theorem genchain_fold_agrees (bs : List (UInt32 × List Tx))
    (hall : bs.all fun b => bip30Enforced b.1 = true) (hsch : genSchemaOk bs = true)
    (m : List (OutPoint × Coin)) (hgen : genChainOkFrom [] bs = some m) :
    connectChainL [] txidPreimageKey bs = Except.ok m :=
  genOpt_ok (by rw [connectChainL_iff_genChainOk [] bs hall hsch, hgen])

/-- Full agreement, iff form: the generator predicts the manifest `m`
iff the chained ledger fold succeeds with exactly `m`. -/
theorem genchain_agreement_iff (bs : List (UInt32 × List Tx))
    (hall : bs.all fun b => bip30Enforced b.1 = true) (hsch : genSchemaOk bs = true)
    (m : List (OutPoint × Coin)) :
    genChainOkFrom [] bs = some m ↔
      connectChainL [] txidPreimageKey bs = Except.ok m := by
  refine ⟨genchain_fold_agrees bs hall hsch m, fun hcon => ?_⟩
  have hcore := connectChainL_iff_genChainOk [] bs hall hsch
  rw [hcon] at hcore
  simpa [genOpt] using hcore.symm

/-- The generator's construction PRECISELY certifies the per-tx gates:
whatever passes it spends only available coins — no double-spend, since
a second spend of the same outpoint no longer finds it and `genStepOk`
rejects. -/
theorem genStep_inputs_available (l : List (OutPoint × Coin)) (tx : Tx)
    (height : UInt32) (m : List (OutPoint × Coin))
    (h : genStepOk l tx height = some m) :
    tx.isCoinBase = true ∨ inputsAvailable (viewOf l) tx = true := by
  unfold genStepOk at h
  by_cases hcb : tx.isCoinBase = true
  · exact Or.inl hcb
  · rw [if_neg hcb] at h
    by_cases hia : inputsAvailable (viewOf l) tx = true
    · exact Or.inr hia
    · rw [if_pos (by simp [hia])] at h
      simp at h

/-- And the block check certifies BIP30 freshness: under enforcement, no
tx of the block re-creates an outpoint already live in the PRISTINE
pre-block view (Core 2466-2475's exact overlap condition). D4c-2 moved
this from the per-tx step to the block gate, so it is a block-level
guarantee now. -/
theorem genTxsOk_bip30_fresh (l : List (OutPoint × Coin)) (txs : List Tx)
    (height : UInt32) (m : List (OutPoint × Coin))
    (hb30 : bip30Enforced height = true)
    (h : genTxsOk l height txs = some m) :
    bip30BlockCollision (viewOf l) txidPreimageKey txs height = false := by
  unfold genTxsOk at h
  by_cases hc : (bip30BlockCollision (viewOf l) txidPreimageKey txs height
      && bip30Enforced height) = true
  · rw [if_pos hc] at h; simp at h
  · have hf : (bip30BlockCollision (viewOf l) txidPreimageKey txs height
        && bip30Enforced height) = false := Bool.eq_false_iff.mpr hc
    rwa [hb30, Bool.and_true] at hf

/-- **No-double-spend by construction**: a generator-constructed chain
runs through the whole ledger fold without ever raising
`bad-txns-inputs-missing-or-spent` (nor any other error). -/
theorem genchain_no_double_spend (bs : List (UInt32 × List Tx))
    (hall : bs.all fun b => bip30Enforced b.1 = true) (hsch : genSchemaOk bs = true)
    (m : List (OutPoint × Coin)) (hgen : genChainOkFrom [] bs = some m) :
    connectChainL [] txidPreimageKey bs
      ≠ Except.error (BlockError.txError TxError.badTxnsInputsMissingOrSpent) := by
  intro hcon
  rw [genchain_fold_agrees bs hall hsch m hgen] at hcon
  cases hcon

/-! ## 3. Subsidy transitions at the synthetic chain's halving boundaries -/

/-- G01's documented scaling of the 210,000-block epoch for the
2000-block synthetic chain (PROPOSED until G01 lands: the boundary
structure is scale-invariant, the numeral 500 is the instance). -/
def GEN_HALVING_INTERVAL : Nat := 500

/-- The generator's subsidy schedule: `50·COIN >> (height / interval)`,
the scaled twin of `GetBlockSubsidy`. -/
def genSubsidy (interval height : Nat) : Amount :=
  ((5000000000 / 2 ^ (height / interval) : Nat) : Amount)

/-- Mainnet link: at the unscaled 210,000-block epoch the generator's
schedule IS Core's `blockSubsidy` (below the `>> 64` saturation). -/
theorem genSubsidy_mainnet_agrees (h : UInt32) (hh : halvingsAt h ≤ 64) :
    genSubsidy 210000 h.toNat = blockSubsidy h := by
  unfold genSubsidy blockSubsidy halvingsAt at *
  rw [Nat.min_def, if_pos hh]

/-- The synthetic chain lives entirely in the first (full-subsidy)
mainnet epoch. -/
theorem subsidy_full_epoch (h : UInt32) (hh : h.toNat < 210000) :
    blockSubsidy h = 5000000000 := by
  unfold blockSubsidy halvingsAt
  rw [Nat.div_eq_of_lt hh]
  rfl

theorem genSubsidy_le_max (interval height : Nat) :
    genSubsidy interval height ≤ 5000000000 := by
  unfold genSubsidy
  exact Int.ofNat_le.mpr (Nat.div_le_self _ _)

/-- A generated coinbase (schema: version 1, single null-prevout input,
one output paying `value`; the BIP34 height push lives in `scriptSig` —
the empty placeholder here is the schema-level shape, validated by
CapstoneBip34Cor at the instance level). -/
def genCoinbase (value : Amount) : Tx :=
  ⟨1, [⟨OutPoint.null, Script.empty, 0xFFFFFFFF⟩],
    [⟨value, genScript [0x51]⟩], 0, []⟩

theorem genCoinbase_isCoinBase (v : Amount) : (genCoinbase v).isCoinBase = true := rfl

/-- The generated coinbase pays out exactly its scripted value. -/
theorem genCoinbase_getValueOut (v : Amount) : (genCoinbase v).getValueOut = v := by
  simp [genCoinbase, Tx.getValueOut]

/-- The generated coinbase is `cbAmountOk`-clean at any synthetic-chain
height: it pays at most the (full-epoch) subsidy with zero fees. -/
theorem genCoinbase_ok (interval : Nat) (h : UInt32) (hh : h.toNat < 210000) :
    cbAmountOk (genCoinbase (genSubsidy interval h.toNat)) 0 h = true := by
  have hsub : blockSubsidy h = 5000000000 := subsidy_full_epoch h hh
  unfold cbAmountOk Bitcoin.Capstone.Block.coinbaseRewardOk
  rw [genCoinbase_getValueOut, hsub, Int.zero_add, decide_eq_true_eq, genSubsidy]
  exact Int.ofNat_le.mpr (Nat.div_le_self _ _)

/-- **Subsidy-transition correctness, boundary 1** (scaled 210000 →
500): the last pre-boundary coinbase pays the full 50 COIN, the first
post-boundary coinbase pays exactly half, and both are `cbAmountOk`. -/
theorem subsidy_transition_500 :
    genSubsidy GEN_HALVING_INTERVAL 499 = 5000000000 ∧
    genSubsidy GEN_HALVING_INTERVAL 500 = 2500000000 ∧
    genSubsidy GEN_HALVING_INTERVAL 500 * 2 = genSubsidy GEN_HALVING_INTERVAL 499 ∧
    cbAmountOk (genCoinbase (genSubsidy GEN_HALVING_INTERVAL 499)) 0 499 = true ∧
    cbAmountOk (genCoinbase (genSubsidy GEN_HALVING_INTERVAL 500)) 0 500 = true := by
  refine ⟨rfl, rfl, rfl, ?_, ?_⟩
  · exact genCoinbase_ok GEN_HALVING_INTERVAL 499 (by decide)
  · exact genCoinbase_ok GEN_HALVING_INTERVAL 500 (by decide)

/-- **Boundary 2** (scaled 420000 → 1000). -/
theorem subsidy_transition_1000 :
    genSubsidy GEN_HALVING_INTERVAL 999 = 2500000000 ∧
    genSubsidy GEN_HALVING_INTERVAL 1000 = 1250000000 ∧
    genSubsidy GEN_HALVING_INTERVAL 1000 * 2 = genSubsidy GEN_HALVING_INTERVAL 999 ∧
    cbAmountOk (genCoinbase (genSubsidy GEN_HALVING_INTERVAL 999)) 0 999 = true ∧
    cbAmountOk (genCoinbase (genSubsidy GEN_HALVING_INTERVAL 1000)) 0 1000 = true := by
  refine ⟨rfl, rfl, rfl, ?_, ?_⟩
  · exact genCoinbase_ok GEN_HALVING_INTERVAL 999 (by decide)
  · exact genCoinbase_ok GEN_HALVING_INTERVAL 1000 (by decide)

/-- **Boundary 3** (scaled 630000 → 1500). -/
theorem subsidy_transition_1500 :
    genSubsidy GEN_HALVING_INTERVAL 1499 = 1250000000 ∧
    genSubsidy GEN_HALVING_INTERVAL 1500 = 625000000 ∧
    genSubsidy GEN_HALVING_INTERVAL 1500 * 2 = genSubsidy GEN_HALVING_INTERVAL 1499 ∧
    cbAmountOk (genCoinbase (genSubsidy GEN_HALVING_INTERVAL 1499)) 0 1499 = true ∧
    cbAmountOk (genCoinbase (genSubsidy GEN_HALVING_INTERVAL 1500)) 0 1500 = true := by
  refine ⟨rfl, rfl, rfl, ?_, ?_⟩
  · exact genCoinbase_ok GEN_HALVING_INTERVAL 1499 (by decide)
  · exact genCoinbase_ok GEN_HALVING_INTERVAL 1500 (by decide)

/-- **Boundary 4** (scaled 840000 → 2000, the synthetic chain's last
block). -/
theorem subsidy_transition_2000 :
    genSubsidy GEN_HALVING_INTERVAL 1999 = 625000000 ∧
    genSubsidy GEN_HALVING_INTERVAL 2000 = 312500000 ∧
    genSubsidy GEN_HALVING_INTERVAL 2000 * 2 = genSubsidy GEN_HALVING_INTERVAL 1999 ∧
    cbAmountOk (genCoinbase (genSubsidy GEN_HALVING_INTERVAL 1999)) 0 1999 = true ∧
    cbAmountOk (genCoinbase (genSubsidy GEN_HALVING_INTERVAL 2000)) 0 2000 = true := by
  refine ⟨rfl, rfl, rfl, ?_, ?_⟩
  · exact genCoinbase_ok GEN_HALVING_INTERVAL 1999 (by decide)
  · exact genCoinbase_ok GEN_HALVING_INTERVAL 2000 (by decide)

/-- Instance-level sanity (schema heights are in the synthetic range):
BIP30 enforcement holds definitionally at the scaled boundaries. -/
theorem bip30Enforced_at_500 : bip30Enforced 500 = true := rfl

theorem bip30Enforced_at_2000 : bip30Enforced 2000 = true := rfl

/-- The general halving law behind the four boundary theorems: at a
boundary `interval ∣ height` whose next epoch's divisor still divides
50·COIN exactly, the subsidy halves EXACTLY. -/
theorem genSubsidy_halves_exactly (interval height : Nat)
    (hpos : 0 < interval)
    (hnext : 2 ^ (height / interval + 1) ∣ 5000000000) :
    genSubsidy interval (height + interval) * 2 = genSubsidy interval height := by
  unfold genSubsidy
  rw [Nat.add_div_right height hpos]
  have hX : 5000000000
      = 2 ^ (height / interval) * 2 * (5000000000 / 2 ^ (height / interval + 1)) := by
    rw [Nat.mul_comm (2 ^ (height / interval) * 2)
        (5000000000 / 2 ^ (height / interval + 1)),
      ← Nat.pow_add_one, Nat.div_mul_cancel hnext]
  have hgoal : 5000000000 / 2 ^ (height / interval)
      = 2 * (5000000000 / 2 ^ (height / interval + 1)) := by
    conv => lhs; rw [hX]
    rw [Nat.mul_assoc]
    exact Nat.mul_div_cancel_left _ (Nat.two_pow_pos _)
  rw [hgoal]
  exact congrArg (fun n : Nat => ((n : Nat) : Amount))
    (Nat.mul_comm (5000000000 / 2 ^ (height / interval + 1)) 2)

end BitcoinProofs.Theorems.Genchain
