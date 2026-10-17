import Bitcoin.Capstone.Pow
import Bitcoin.Capstone.Block
import Bitcoin.Consensus.TxCheck
import Bitcoin.Ledger.Interface
import Bitcoin.Interpreter.Rules
import Bitcoin.Block.Connect
import Bitcoin.Block.Params
import BitcoinProofs.Theorems.CapstoneDecodeCor

/-!
# PDW68 — structural row-face residue (TOP-361..365)

Row-face theorems for {BLK-003, BLK-028, BLK-031, BLK-110, SCR-173}.
Route B: `@[rule]` tags ride these theorems, zero core writes.
Axiom pin target: `[propext, Classical.choice, Quot.sound]`.
-/

namespace BitcoinProofs.AF.PDW68

open Bitcoin.Data
open Bitcoin.Capstone
open Bitcoin.Consensus
open Bitcoin.Ledger
open Bitcoin.Interpreter

/-! ## BLK-003 — block hash is SHA256d of the 80-byte header -/

/-- **BLK-003** row face: `headerHash` is exactly SHA256d of the canonical
80-byte header encoding (pow.cpp:GetHash). -/
@[rule "BLK-003"]
theorem headerHash_row (h : Bitcoin.Chain.BlockHeader) :
    Pow.headerHash h =
      Bitcoin.Crypto.Seam.Hash.sha256d (Bitcoin.Serialization.encodeBlockHeader h) := rfl

/-- The resulting block hash is a 32-byte digest. -/
theorem headerHash_size (h : Bitcoin.Chain.BlockHeader) :
    (Pow.headerHash h).size = 32 :=
  Bitcoin.Crypto.Seam.Hash.sha256d_size _

/-- **BLK-003** (little-endian reading): the integer value of the block
hash is the sum of the digest bytes weighted by `256^i`, i.e. Core's
`uint256` interpretation with byte 0 least significant. The digest is the
32-byte SHA256d output (so the fold is over exactly 32 bytes). -/
@[rule "BLK-003"]
theorem headerHash_LE_value (h : Bitcoin.Chain.BlockHeader) :
    Pow.hashNatLE (Pow.headerHash h) =
      (List.range 32).foldl (fun acc i =>
        acc + ((Bitcoin.Crypto.Seam.Hash.sha256d
          (Bitcoin.Serialization.encodeBlockHeader h)).get! i).toNat * 256 ^ i) 0 := by
  unfold Pow.hashNatLE Pow.headerHash
  rw [Bitcoin.Crypto.Seam.Hash.sha256d_size]

/-- **BLK-003** (80-byte header): whenever the two 32-byte hash fields are
canonical, the header encoding hashed above is exactly 80 bytes. -/
@[rule "BLK-003"]
theorem encodeBlockHeader_size (h : Bitcoin.Chain.BlockHeader)
    (hp : h.hashPrevBlock.size = 32) (hm : h.hashMerkleRoot.size = 32) :
    (Bitcoin.Serialization.encodeBlockHeader h).size = 80 := by
  unfold Bitcoin.Serialization.encodeBlockHeader
  rw [show (Bitcoin.Serialization.bytesOfList
      (Bitcoin.Serialization.encHeaderL h)).size =
      (Bitcoin.Serialization.encHeaderL h).length by
    simp [Bitcoin.Serialization.bytesOfList]]
  exact BitcoinProofs.Theorems.CapstoneDecode.encHeaderL_length h hp hm

/-! ## BLK-028 — no coinbase after position 0 -/

/-- **BLK-028** reject face: a later coinbase (`bad-cb-multiple`) fails
`cbPositionOk`, regardless of the head (validation.cpp:3959-3963). -/
@[rule "BLK-028"]
theorem cbPositionOk_tail_reject {cb : Tx} {rest : List Tx}
    (h : rest.any (fun t => t.isCoinBase) = true) :
    Block.cbPositionOk (cb :: rest) = false := by
  simp [Block.cbPositionOk, h]

/-! ## BLK-031 — duplicate prevouts (CVE-2018-17144) -/

/-- **BLK-031** reject face: a repeated prevout in a two-input transaction
is flagged by `hasDupPrevouts` (tx_check.cpp:56). -/
@[rule "BLK-031"]
theorem hasDupPrevouts_pair_dup (a b : TxIn) (h : b.prevout = a.prevout) :
    _root_.Bitcoin.Consensus.hasDupPrevouts [a, b] = true := by
  simp [_root_.Bitcoin.Consensus.hasDupPrevouts, h, Bitcoin.Ledger.outPointBeqSelf]

/-- A single input can never contain a duplicate prevout. -/
theorem hasDupPrevouts_singleton (a : TxIn) :
    _root_.Bitcoin.Consensus.hasDupPrevouts [a] = false := by
  simp [_root_.Bitcoin.Consensus.hasDupPrevouts]

/-- **BLK-031** (general): `hasDupPrevouts` is false exactly when every
later input's outpoint differs from every earlier input's outpoint. This
is the full no-two-inputs-share-an-outpoint claim, not a two-input
instance. -/
@[rule "BLK-031"]
theorem hasDupPrevouts_eq_false_iff (l : List TxIn) :
    _root_.Bitcoin.Consensus.hasDupPrevouts l = false ↔
      l.Pairwise (fun a b => (b.prevout == a.prevout) = false) := by
  induction l with
  | nil => simp [_root_.Bitcoin.Consensus.hasDupPrevouts]
  | cons i rest ih =>
      simp only [_root_.Bitcoin.Consensus.hasDupPrevouts, Bool.or_eq_false_iff, ih,
        List.pairwise_cons, List.any_eq_false, Bool.not_eq_true]

/-! ## BLK-110 — pre-genesis UTXO view is empty -/

/-- **BLK-110** row face: the pre-genesis view maps every outpoint to
`none`; the genesis 50 BTC output never enters the UTXO set. -/
@[rule "BLK-110"]
theorem emptyUtxo_row (p : OutPoint) : emptyUtxo p = none := rfl

/-- **BLK-110** (genesis connection): connecting the genesis block from
an empty UTXO list leaves the view empty for every outpoint — the
connection skips the transaction fold entirely (validation.cpp:2330-2334). -/
@[rule "BLK-110"]
theorem connectGenesis_view_empty (h : Bitcoin.Chain.BlockHeader) :
    viewOf (_root_.Bitcoin.Block.Connect.connectGenesis [] h).1 = emptyUtxo := rfl

/-- **BLK-110** (the concrete 50 BTC output): the genesis coinbase output
outpoint is absent from the view produced by connecting genesis. -/
@[rule "BLK-110"]
theorem genesis_coinbase_output_absent :
    viewOf (_root_.Bitcoin.Block.Connect.connectGenesis []
      _root_.Bitcoin.Block.Params.genesisHeader).1
      (txidPreimageKey _root_.Bitcoin.Block.Params.genesisCoinbaseTx OutPoint.null
        (UInt32.ofNat 0)) = none := rfl

/-- **BLK-110** on the real connect path: `connectBlock` routes the pinned
genesis header through its genesis predicate and returns before the
`applyBlockExec` fold, so the post-state view is still the empty UTXO view. -/
@[rule "BLK-110"]
theorem connectBlock_genesis_view_empty :
    ∃ s, _root_.Bitcoin.Block.Connect.connectBlock
        _root_.Bitcoin.Block.Params.genesisHeader [] 0
        { utxo := [], bestBlock := none } = Except.ok s ∧
      viewOf s.utxo = emptyUtxo := by
  refine ⟨_, _root_.Bitcoin.Block.Connect.connectBlock_genesis _ _ _ _
    _root_.Bitcoin.Block.Connect.isGenesisHeader_genesisHeader, ?_⟩
  rfl

/-- **BLK-110** on the real connect path, at the concrete 50-BTC outpoint:
the genesis coinbase output is absent from the post-state UTXO because the
wired genesis branch never folds `genesisCoinbaseTx`. -/
@[rule "BLK-110"]
theorem genesis_coinbase_output_absent_real :
    ∃ s, _root_.Bitcoin.Block.Connect.connectBlock
        _root_.Bitcoin.Block.Params.genesisHeader
        [_root_.Bitcoin.Block.Params.genesisCoinbaseTx] 0
        { utxo := [], bestBlock := none } = Except.ok s ∧
      viewOf s.utxo
        (txidPreimageKey _root_.Bitcoin.Block.Params.genesisCoinbaseTx
          OutPoint.null (UInt32.ofNat 0)) = none :=
  _root_.Bitcoin.Block.Connect.connectBlock_genesis_coinbase_output_absent

/-- The absent output carries the genesis subsidy: 50 COIN. -/
@[rule "BLK-110"]
theorem genesis_coinbase_output_value :
    (_root_.Bitcoin.Block.Params.genesisCoinbaseTx.vout[0]!).value =
      50 * Bitcoin.Data.COIN := by
  unfold _root_.Bitcoin.Block.Params.genesisCoinbaseTx
  simp [Bitcoin.Data.COIN]

/-- **BLK-110** (non-genesis-branch witness): the bare block fold
`applyBlock` has no genesis test of its own; folding the genesis coinbase
directly inserts its 50-COIN output under the txid-preimage key. This is
exactly why the genesis bypass belongs in the router: the wired
`connectBlock` tests `isGenesisHeader` first and never reaches this fold
(`genesis_coinbase_output_absent_real`). The theorem therefore
characterizes the non-genesis `applyBlock` branch, not the connect call
site. -/
@[rule "BLK-110"]
theorem genesis_applyBlock_output_present :
    ∃ u, applyBlock emptyUtxo [_root_.Bitcoin.Block.Params.genesisCoinbaseTx] 0 =
        .ok u ∧
      (u (txidPreimageKey _root_.Bitcoin.Block.Params.genesisCoinbaseTx
        OutPoint.null (UInt32.ofNat 0))).isSome = true := by
  have h := genesis_coin_isSome
    (cb := _root_.Bitcoin.Block.Params.genesisCoinbaseTx) (height := 0)
    (by decide) (by decide) (by decide) (by decide)
  exact ⟨h.choose, h.choose_spec.1, h.choose_spec.2.1⟩

/-! ## SCR-173 — opcode-name table coverage -/

/-- **SCR-173** accept face: every wire byte 0x00..0xba has a name. -/
@[rule "SCR-173"]
theorem opNameKnown_covered (w : Nat) (h : w ≤ 0xba) :
    _root_.Bitcoin.Interpreter.opNameKnown w = true := by
  simp [_root_.Bitcoin.Interpreter.opNameKnown, h]

/-- **SCR-173** reject face: only the reserved 0xbb..0xfe window falls
through to `"OP_UNKNOWN"` (0xff = OP_INVALIDOPCODE is named). -/
theorem opNameKnown_unknown_window (w : Nat) (hlo : 0xba < w) (hne : w ≠ 0xff) :
    _root_.Bitcoin.Interpreter.opNameKnown w = false := by
  simp [_root_.Bitcoin.Interpreter.opNameKnown, Nat.not_le.mpr hlo, hne]

/-- **SCR-173** (full coverage characterization): the bytes with a table
name are exactly 0x00..0xba plus 0xff. -/
@[rule "SCR-173"]
theorem opNameKnown_iff (w : Nat) :
    _root_.Bitcoin.Interpreter.opNameKnown w = true ↔ w ≤ 0xba ∨ w = 0xff := by
  simp [_root_.Bitcoin.Interpreter.opNameKnown]

/-- **SCR-173** (unknown window characterization): the complement of the
named set is exactly every byte above 0xba except 0xff; restricted to wire
bytes this is the reserved 0xbb..0xfe window. -/
@[rule "SCR-173"]
theorem opNameKnown_eq_false_iff (w : Nat) :
    _root_.Bitcoin.Interpreter.opNameKnown w = false ↔ 0xba < w ∧ w ≠ 0xff := by
  simp [_root_.Bitcoin.Interpreter.opNameKnown]

/-- **SCR-173** (wire-byte form): among bytes `0..0xff`, the unnamed set is
exactly the reserved window 0xbb..0xfe. -/
@[rule "SCR-173"]
theorem opNameKnown_unknown_window_iff (w : Nat) (hw : w ≤ 0xff) :
    _root_.Bitcoin.Interpreter.opNameKnown w = false ↔ 0xbb ≤ w ∧ w ≤ 0xfe := by
  rw [opNameKnown_eq_false_iff]
  omega

/-- `GetOpName`'s display fallback: named bytes read the table, every
other byte yields the literal `"OP_UNKNOWN"`. The concrete name strings
are display-only and left abstract. -/
def opNameOf (nameAt : Nat → String) (w : Nat) : String :=
  if _root_.Bitcoin.Interpreter.opNameKnown w then nameAt w else "OP_UNKNOWN"

/-- **SCR-173** (fallback direction): an unknown opcode displays exactly
`"OP_UNKNOWN"`. -/
@[rule "SCR-173"]
theorem opNameOf_unknown (nameAt : Nat → String) (w : Nat)
    (h : _root_.Bitcoin.Interpreter.opNameKnown w = false) :
    opNameOf nameAt w = "OP_UNKNOWN" := by
  simp [opNameOf, h]

/-- **SCR-173** (table direction): a known opcode displays its table name. -/
@[rule "SCR-173"]
theorem opNameOf_known (nameAt : Nat → String) (w : Nat)
    (h : _root_.Bitcoin.Interpreter.opNameKnown w = true) :
    opNameOf nameAt w = nameAt w := by
  simp [opNameOf, h]

/-! ### SCR-173 — the concrete `script.cpp:19-157` name table

The prior row face only described a *domain* predicate and left the
name table abstract. The table below is a literal transcription of
`GetOpName` (`script.cpp:19-157`). Note the push-opcode gap: Core has
cases only for `OP_0` and `OP_PUSHDATA1..4`; the direct-push bytes
`0x01..0x4b` fall through to `"OP_UNKNOWN"`. The old predicate
`opNameKnown` (`Rules.lean:760`, `w ≤ 0xba ∨ w = 0xff`) therefore
over-counts that window, which `opNameKnown_push_gap` records below.
-/

/-- The concrete `GetOpName` table (`script.cpp:19-157`). -/
@[rule "SCR-173"]
def opNameWire : Nat → String
  | 0x00 => "0"
  | 0x4c => "OP_PUSHDATA1"
  | 0x4d => "OP_PUSHDATA2"
  | 0x4e => "OP_PUSHDATA4"
  | 0x4f => "-1"
  | 0x50 => "OP_RESERVED"
  | 0x51 => "1"
  | 0x52 => "2"
  | 0x53 => "3"
  | 0x54 => "4"
  | 0x55 => "5"
  | 0x56 => "6"
  | 0x57 => "7"
  | 0x58 => "8"
  | 0x59 => "9"
  | 0x5a => "10"
  | 0x5b => "11"
  | 0x5c => "12"
  | 0x5d => "13"
  | 0x5e => "14"
  | 0x5f => "15"
  | 0x60 => "16"
  | 0x61 => "OP_NOP"
  | 0x62 => "OP_VER"
  | 0x63 => "OP_IF"
  | 0x64 => "OP_NOTIF"
  | 0x65 => "OP_VERIF"
  | 0x66 => "OP_VERNOTIF"
  | 0x67 => "OP_ELSE"
  | 0x68 => "OP_ENDIF"
  | 0x69 => "OP_VERIFY"
  | 0x6a => "OP_RETURN"
  | 0x6b => "OP_TOALTSTACK"
  | 0x6c => "OP_FROMALTSTACK"
  | 0x6d => "OP_2DROP"
  | 0x6e => "OP_2DUP"
  | 0x6f => "OP_3DUP"
  | 0x70 => "OP_2OVER"
  | 0x71 => "OP_2ROT"
  | 0x72 => "OP_2SWAP"
  | 0x73 => "OP_IFDUP"
  | 0x74 => "OP_DEPTH"
  | 0x75 => "OP_DROP"
  | 0x76 => "OP_DUP"
  | 0x77 => "OP_NIP"
  | 0x78 => "OP_OVER"
  | 0x79 => "OP_PICK"
  | 0x7a => "OP_ROLL"
  | 0x7b => "OP_ROT"
  | 0x7c => "OP_SWAP"
  | 0x7d => "OP_TUCK"
  | 0x7e => "OP_CAT"
  | 0x7f => "OP_SUBSTR"
  | 0x80 => "OP_LEFT"
  | 0x81 => "OP_RIGHT"
  | 0x82 => "OP_SIZE"
  | 0x83 => "OP_INVERT"
  | 0x84 => "OP_AND"
  | 0x85 => "OP_OR"
  | 0x86 => "OP_XOR"
  | 0x87 => "OP_EQUAL"
  | 0x88 => "OP_EQUALVERIFY"
  | 0x89 => "OP_RESERVED1"
  | 0x8a => "OP_RESERVED2"
  | 0x8b => "OP_1ADD"
  | 0x8c => "OP_1SUB"
  | 0x8d => "OP_2MUL"
  | 0x8e => "OP_2DIV"
  | 0x8f => "OP_NEGATE"
  | 0x90 => "OP_ABS"
  | 0x91 => "OP_NOT"
  | 0x92 => "OP_0NOTEQUAL"
  | 0x93 => "OP_ADD"
  | 0x94 => "OP_SUB"
  | 0x95 => "OP_MUL"
  | 0x96 => "OP_DIV"
  | 0x97 => "OP_MOD"
  | 0x98 => "OP_LSHIFT"
  | 0x99 => "OP_RSHIFT"
  | 0x9a => "OP_BOOLAND"
  | 0x9b => "OP_BOOLOR"
  | 0x9c => "OP_NUMEQUAL"
  | 0x9d => "OP_NUMEQUALVERIFY"
  | 0x9e => "OP_NUMNOTEQUAL"
  | 0x9f => "OP_LESSTHAN"
  | 0xa0 => "OP_GREATERTHAN"
  | 0xa1 => "OP_LESSTHANOREQUAL"
  | 0xa2 => "OP_GREATERTHANOREQUAL"
  | 0xa3 => "OP_MIN"
  | 0xa4 => "OP_MAX"
  | 0xa5 => "OP_WITHIN"
  | 0xa6 => "OP_RIPEMD160"
  | 0xa7 => "OP_SHA1"
  | 0xa8 => "OP_SHA256"
  | 0xa9 => "OP_HASH160"
  | 0xaa => "OP_HASH256"
  | 0xab => "OP_CODESEPARATOR"
  | 0xac => "OP_CHECKSIG"
  | 0xad => "OP_CHECKSIGVERIFY"
  | 0xae => "OP_CHECKMULTISIG"
  | 0xaf => "OP_CHECKMULTISIGVERIFY"
  | 0xb0 => "OP_NOP1"
  | 0xb1 => "OP_CHECKLOCKTIMEVERIFY"
  | 0xb2 => "OP_CHECKSEQUENCEVERIFY"
  | 0xb3 => "OP_NOP4"
  | 0xb4 => "OP_NOP5"
  | 0xb5 => "OP_NOP6"
  | 0xb6 => "OP_NOP7"
  | 0xb7 => "OP_NOP8"
  | 0xb8 => "OP_NOP9"
  | 0xb9 => "OP_NOP10"
  | 0xba => "OP_CHECKSIGADD"
  | 0xff => "OP_INVALIDOPCODE"
  | _ => "OP_UNKNOWN"

/-- Every named byte maps to its literal Core name (`script.cpp:19-157`). -/
@[rule "SCR-173"]
theorem opNameWire_table :
    opNameWire 0x00 = "0" ∧
    opNameWire 0x4c = "OP_PUSHDATA1" ∧
    opNameWire 0x4d = "OP_PUSHDATA2" ∧
    opNameWire 0x4e = "OP_PUSHDATA4" ∧
    opNameWire 0x4f = "-1" ∧
    opNameWire 0x50 = "OP_RESERVED" ∧
    opNameWire 0x51 = "1" ∧
    opNameWire 0x52 = "2" ∧
    opNameWire 0x53 = "3" ∧
    opNameWire 0x54 = "4" ∧
    opNameWire 0x55 = "5" ∧
    opNameWire 0x56 = "6" ∧
    opNameWire 0x57 = "7" ∧
    opNameWire 0x58 = "8" ∧
    opNameWire 0x59 = "9" ∧
    opNameWire 0x5a = "10" ∧
    opNameWire 0x5b = "11" ∧
    opNameWire 0x5c = "12" ∧
    opNameWire 0x5d = "13" ∧
    opNameWire 0x5e = "14" ∧
    opNameWire 0x5f = "15" ∧
    opNameWire 0x60 = "16" ∧
    opNameWire 0x61 = "OP_NOP" ∧
    opNameWire 0x62 = "OP_VER" ∧
    opNameWire 0x63 = "OP_IF" ∧
    opNameWire 0x64 = "OP_NOTIF" ∧
    opNameWire 0x65 = "OP_VERIF" ∧
    opNameWire 0x66 = "OP_VERNOTIF" ∧
    opNameWire 0x67 = "OP_ELSE" ∧
    opNameWire 0x68 = "OP_ENDIF" ∧
    opNameWire 0x69 = "OP_VERIFY" ∧
    opNameWire 0x6a = "OP_RETURN" ∧
    opNameWire 0x6b = "OP_TOALTSTACK" ∧
    opNameWire 0x6c = "OP_FROMALTSTACK" ∧
    opNameWire 0x6d = "OP_2DROP" ∧
    opNameWire 0x6e = "OP_2DUP" ∧
    opNameWire 0x6f = "OP_3DUP" ∧
    opNameWire 0x70 = "OP_2OVER" ∧
    opNameWire 0x71 = "OP_2ROT" ∧
    opNameWire 0x72 = "OP_2SWAP" ∧
    opNameWire 0x73 = "OP_IFDUP" ∧
    opNameWire 0x74 = "OP_DEPTH" ∧
    opNameWire 0x75 = "OP_DROP" ∧
    opNameWire 0x76 = "OP_DUP" ∧
    opNameWire 0x77 = "OP_NIP" ∧
    opNameWire 0x78 = "OP_OVER" ∧
    opNameWire 0x79 = "OP_PICK" ∧
    opNameWire 0x7a = "OP_ROLL" ∧
    opNameWire 0x7b = "OP_ROT" ∧
    opNameWire 0x7c = "OP_SWAP" ∧
    opNameWire 0x7d = "OP_TUCK" ∧
    opNameWire 0x7e = "OP_CAT" ∧
    opNameWire 0x7f = "OP_SUBSTR" ∧
    opNameWire 0x80 = "OP_LEFT" ∧
    opNameWire 0x81 = "OP_RIGHT" ∧
    opNameWire 0x82 = "OP_SIZE" ∧
    opNameWire 0x83 = "OP_INVERT" ∧
    opNameWire 0x84 = "OP_AND" ∧
    opNameWire 0x85 = "OP_OR" ∧
    opNameWire 0x86 = "OP_XOR" ∧
    opNameWire 0x87 = "OP_EQUAL" ∧
    opNameWire 0x88 = "OP_EQUALVERIFY" ∧
    opNameWire 0x89 = "OP_RESERVED1" ∧
    opNameWire 0x8a = "OP_RESERVED2" ∧
    opNameWire 0x8b = "OP_1ADD" ∧
    opNameWire 0x8c = "OP_1SUB" ∧
    opNameWire 0x8d = "OP_2MUL" ∧
    opNameWire 0x8e = "OP_2DIV" ∧
    opNameWire 0x8f = "OP_NEGATE" ∧
    opNameWire 0x90 = "OP_ABS" ∧
    opNameWire 0x91 = "OP_NOT" ∧
    opNameWire 0x92 = "OP_0NOTEQUAL" ∧
    opNameWire 0x93 = "OP_ADD" ∧
    opNameWire 0x94 = "OP_SUB" ∧
    opNameWire 0x95 = "OP_MUL" ∧
    opNameWire 0x96 = "OP_DIV" ∧
    opNameWire 0x97 = "OP_MOD" ∧
    opNameWire 0x98 = "OP_LSHIFT" ∧
    opNameWire 0x99 = "OP_RSHIFT" ∧
    opNameWire 0x9a = "OP_BOOLAND" ∧
    opNameWire 0x9b = "OP_BOOLOR" ∧
    opNameWire 0x9c = "OP_NUMEQUAL" ∧
    opNameWire 0x9d = "OP_NUMEQUALVERIFY" ∧
    opNameWire 0x9e = "OP_NUMNOTEQUAL" ∧
    opNameWire 0x9f = "OP_LESSTHAN" ∧
    opNameWire 0xa0 = "OP_GREATERTHAN" ∧
    opNameWire 0xa1 = "OP_LESSTHANOREQUAL" ∧
    opNameWire 0xa2 = "OP_GREATERTHANOREQUAL" ∧
    opNameWire 0xa3 = "OP_MIN" ∧
    opNameWire 0xa4 = "OP_MAX" ∧
    opNameWire 0xa5 = "OP_WITHIN" ∧
    opNameWire 0xa6 = "OP_RIPEMD160" ∧
    opNameWire 0xa7 = "OP_SHA1" ∧
    opNameWire 0xa8 = "OP_SHA256" ∧
    opNameWire 0xa9 = "OP_HASH160" ∧
    opNameWire 0xaa = "OP_HASH256" ∧
    opNameWire 0xab = "OP_CODESEPARATOR" ∧
    opNameWire 0xac = "OP_CHECKSIG" ∧
    opNameWire 0xad = "OP_CHECKSIGVERIFY" ∧
    opNameWire 0xae = "OP_CHECKMULTISIG" ∧
    opNameWire 0xaf = "OP_CHECKMULTISIGVERIFY" ∧
    opNameWire 0xb0 = "OP_NOP1" ∧
    opNameWire 0xb1 = "OP_CHECKLOCKTIMEVERIFY" ∧
    opNameWire 0xb2 = "OP_CHECKSEQUENCEVERIFY" ∧
    opNameWire 0xb3 = "OP_NOP4" ∧
    opNameWire 0xb4 = "OP_NOP5" ∧
    opNameWire 0xb5 = "OP_NOP6" ∧
    opNameWire 0xb6 = "OP_NOP7" ∧
    opNameWire 0xb7 = "OP_NOP8" ∧
    opNameWire 0xb8 = "OP_NOP9" ∧
    opNameWire 0xb9 = "OP_NOP10" ∧
    opNameWire 0xba = "OP_CHECKSIGADD" ∧
    opNameWire 0xff = "OP_INVALIDOPCODE"
  := by
  repeat' (first | apply And.intro | rfl)

/-- SCR-173 (corrected domain): the bytes with a `script.cpp` name are
exactly `0x00`, `0x4c..0xba`, and `0xff`. -/
@[rule "SCR-173"]
def opNameWireKnown (w : Nat) : Bool :=
  decide (w = 0 ∨ (0x4c ≤ w ∧ w ≤ 0xba) ∨ w = 0xff)

@[rule "SCR-173"]
theorem opNameWireKnown_iff (w : Nat) :
    opNameWireKnown w = true ↔
      w = 0 ∨ (0x4c ≤ w ∧ w ≤ 0xba) ∨ w = 0xff := by
  simp [opNameWireKnown]

/- SCR-173 (exhaustive check over all 256 wire bytes). -/
set_option maxRecDepth 100000 in
@[rule "SCR-173"]
theorem opNameWire_unknown_check :
    (List.range 256).all (fun w =>
      (opNameWire w == "OP_UNKNOWN") ==
        decide ((1 ≤ w ∧ w ≤ 0x4b) ∨ (0xbb ≤ w ∧ w ≤ 0xfe))) = true := by
  decide

/-- SCR-173 (unknown ⇒ `"OP_UNKNOWN"`): the fallback set is exactly
the direct-push window `0x01..0x4b` plus the reserved `0xbb..0xfe`. -/
@[rule "SCR-173"]
theorem opNameWire_unknown_iff (w : Nat) (hw : w < 256) :
    opNameWire w = "OP_UNKNOWN" ↔
      (1 ≤ w ∧ w ≤ 0x4b) ∨ (0xbb ≤ w ∧ w ≤ 0xfe) := by
  have hm : w ∈ List.range 256 := List.mem_range.mpr hw
  have hall := List.all_eq_true.mp opNameWire_unknown_check w hm
  have hEq : (opNameWire w == "OP_UNKNOWN") =
      decide ((1 ≤ w ∧ w ≤ 0x4b) ∨ (0xbb ≤ w ∧ w ≤ 0xfe)) :=
    beq_iff_eq.mp hall
  have hbeq : (opNameWire w == "OP_UNKNOWN") = true ↔
      decide ((1 ≤ w ∧ w ≤ 0x4b) ∨ (0xbb ≤ w ∧ w ≤ 0xfe)) = true := by
    rw [hEq]
  exact beq_iff_eq.symm.trans (hbeq.trans decide_eq_true_iff)

/-- SCR-173 (named ⇒ not the fallback). -/
@[rule "SCR-173"]
theorem opNameWire_known_not_unknown (w : Nat)
    (h : opNameWireKnown w = true) : opNameWire w ≠ "OP_UNKNOWN" := by
  have hdom := (opNameWireKnown_iff w).mp h
  have hw : w < 256 := by
    rcases hdom with rfl | ⟨h1, h2⟩ | rfl <;> omega
  intro hu
  have hun := (opNameWire_unknown_iff w hw).mp hu
  rcases hdom with rfl | ⟨h1, h2⟩ | rfl <;> omega

/-- SCR-173 (direct-push fallback): every direct-push byte is unnamed. -/
@[rule "SCR-173"]
theorem opNameWire_unknown_push (w : Nat) (h1 : 1 ≤ w) (h2 : w ≤ 0x4b) :
    opNameWire w = "OP_UNKNOWN" := by
  have hw : w < 256 := by omega
  exact (opNameWire_unknown_iff w hw).mpr (Or.inl ⟨h1, h2⟩)

/-- SCR-173 (model correction): the old `opNameKnown` predicate calls the
direct-push byte `0x01` named, while `GetOpName` returns `OP_UNKNOWN`. -/
@[rule "SCR-173"]
theorem opNameKnown_push_gap :
    _root_.Bitcoin.Interpreter.opNameKnown 0x01 = true ∧
      opNameWire 0x01 = "OP_UNKNOWN" := by
  decide

/-- SCR-173 (old predicate is not the Core name domain). -/
@[rule "SCR-173"]
theorem opNameKnown_not_core_table :
    ∃ w, _root_.Bitcoin.Interpreter.opNameKnown w = true ∧
      opNameWire w = "OP_UNKNOWN" :=
  ⟨0x01, by decide⟩

end BitcoinProofs.AF.PDW68

#print axioms BitcoinProofs.AF.PDW68.headerHash_row
#print axioms BitcoinProofs.AF.PDW68.headerHash_size
#print axioms BitcoinProofs.AF.PDW68.cbPositionOk_tail_reject
#print axioms BitcoinProofs.AF.PDW68.hasDupPrevouts_pair_dup
#print axioms BitcoinProofs.AF.PDW68.hasDupPrevouts_singleton
#print axioms BitcoinProofs.AF.PDW68.emptyUtxo_row
#print axioms BitcoinProofs.AF.PDW68.opNameKnown_covered
#print axioms BitcoinProofs.AF.PDW68.opNameKnown_unknown_window
#print axioms BitcoinProofs.AF.PDW68.headerHash_LE_value
#print axioms BitcoinProofs.AF.PDW68.encodeBlockHeader_size
#print axioms BitcoinProofs.AF.PDW68.hasDupPrevouts_eq_false_iff
#print axioms BitcoinProofs.AF.PDW68.connectGenesis_view_empty
#print axioms BitcoinProofs.AF.PDW68.genesis_coinbase_output_absent
#print axioms BitcoinProofs.AF.PDW68.connectBlock_genesis_view_empty
#print axioms BitcoinProofs.AF.PDW68.genesis_coinbase_output_absent_real
#print axioms BitcoinProofs.AF.PDW68.genesis_coinbase_output_value
#print axioms BitcoinProofs.AF.PDW68.opNameKnown_iff
#print axioms BitcoinProofs.AF.PDW68.opNameKnown_eq_false_iff
#print axioms BitcoinProofs.AF.PDW68.opNameKnown_unknown_window_iff
#print axioms BitcoinProofs.AF.PDW68.opNameOf_unknown
#print axioms BitcoinProofs.AF.PDW68.opNameOf_known
#print axioms BitcoinProofs.AF.PDW68.genesis_applyBlock_output_present
#print axioms BitcoinProofs.AF.PDW68.opNameWire_table
#print axioms BitcoinProofs.AF.PDW68.opNameWireKnown_iff
#print axioms BitcoinProofs.AF.PDW68.opNameWire_unknown_iff
#print axioms BitcoinProofs.AF.PDW68.opNameWire_known_not_unknown
#print axioms BitcoinProofs.AF.PDW68.opNameWire_unknown_push
#print axioms BitcoinProofs.AF.PDW68.opNameKnown_push_gap
#print axioms BitcoinProofs.AF.PDW68.opNameKnown_not_core_table
