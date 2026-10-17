import Bitcoin.Block.Params
import Bitcoin.SigHash.Digest

/-! # PDW23.lean — proof-promotion review RC26, items TOP-111..115

D-PARAMS `@[rule]`-tagged definitions (`Bitcoin/Block/Params.lean`,
validation.cpp:2180-2185, 2330-2334) and the BIP143 preimage field law
(`Bitcoin/SigHash/Digest.lean`, interpreter.cpp:1660-1685).

Route B (PDW25/PDW32 pattern): zero core writes, row theorems carry the
`@[rule]` tag, axiom pins ⊆ [propext, Classical.choice, Quot.sound]. -/

namespace BitcoinProofs.AF.PDW23

open Bitcoin.Block.Params
open Bitcoin.SigHash
open Bitcoin.Data Bitcoin.Serialization Bitcoin.Ledger Bitcoin.Chain

/-! ## BLK-107 — unspendable outputs are never disconnect-relevant -/

@[rule "BLK-107"]
theorem disconnectRelevant_row_iff (c : Coin) :
    disconnectRelevant c = true ↔ scriptUnspendable c.scriptPubKey = false := by
  simp [disconnectRelevant]

@[rule "BLK-107"]
theorem disconnectRelevant_opreturn (v : Amount) (h : UInt32) (cb : Bool) :
    disconnectRelevant ⟨v, h, cb, scriptOf [0x6a]⟩ = false := by
  unfold disconnectRelevant
  rw [show scriptUnspendable (scriptOf [0x6a]) = true from by
    unfold scriptUnspendable scriptOf; decide]
  rfl

/-! ## BLK-108 — vtxundo.size()+1 == vtx.size() -/

@[rule "BLK-108"]
theorem undoCountOk_row_iff (vtx : List Tx) (u : List (List (OutPoint × Coin))) :
    undoCountOk vtx u = true ↔ u.length + 1 = vtx.length := by
  simp [undoCountOk]

@[rule "BLK-108"]
theorem undoCountOk_coinbase_only (cb : Tx) : undoCountOk [cb] [] = true := rfl

@[rule "BLK-108"]
theorem undoCountOk_short (vtx : List Tx) (u : List (List (OutPoint × Coin)))
    (h : u.length + 1 < vtx.length) : undoCountOk vtx u = false := by
  simp [undoCountOk, Nat.ne_of_lt h]

@[rule "BLK-108"]
theorem undoCountOk_long (vtx : List Tx) (u : List (List (OutPoint × Coin)))
    (h : vtx.length < u.length + 1) : undoCountOk vtx u = false := by
  simp [undoCountOk, Nat.ne_of_gt h]

/-! ## BLK-111 — the mainnet genesis header pins -/

@[rule "BLK-111"]
theorem genesisHeader_row :
    genesisHeader.version = 1 ∧ genesisHeader.time = 1231006505 ∧
    genesisHeader.bits = 0x1d00ffff ∧ genesisHeader.nonce = 2083236893 ∧
    genesisHeader.hashPrevBlock = zeroBytes 32 ∧
    genesisHeader.hashMerkleRoot = genesisMerkleRootInternal ∧
    genesisMerkleRootInternal.size = 32 := by
  refine ⟨rfl, rfl, rfl, rfl, rfl, rfl, by decide⟩

@[rule "BLK-111"]
theorem genesisHeader_difficulty_one :
    compactTarget genesisHeader.bits = 0xffff * 256 ^ 26 := by
  rw [show genesisHeader.bits = 0x1d00ffff from rfl]
  exact Bitcoin.Chain.compactTarget_difficulty_one

/-- BLK-111: the remaining genesis pins — the coinbase scriptSig carries the
Times headline starting at its 8th byte (`CScriptNum`-length prefix + push
opcode before the text), and the header's merkle field is the internal
little-endian root whose display (byte-reversed) form is `4a5e1e4b…a33b`.
The display block hash `000000000019d668…ce26f` is the one pin this
kernel-checked theorem does NOT carry: `headerHash` runs two SHA-256
compressions, which the Lean kernel cannot reduce (`decide` gets stuck in
`compressLoop`); the literal digest is pinned only in
`spec/Test/Crypto/SeamHashTest.lean` via a Test-scoped compiled-reduction
escape (deliberately not used here). -/
@[rule "BLK-111"]
theorem genesisCoinbaseText_merkleDisplay_row :
    genesisCoinbaseTx.vin.map (fun i => i.scriptSig.bytes) = [genesisScriptSig] ∧
    genesisScriptSig.extract 8 77 =
      "The Times 03/Jan/2009 Chancellor on brink of second bailout for banks".toUTF8 ∧
    genesisMerkleRootInternal.data.toList.reverse =
      [0x4a,0x5e,0x1e,0x4b,0xaa,0xb8,0x9f,0x3a,0x32,0x51,0x8a,0x88,0xc3,0x1b,0xc8,0x7f,
       0x61,0x8f,0x76,0x67,0x3e,0x2c,0xc7,0x7a,0xb2,0x12,0x7b,0x7a,0xfd,0xed,0xa3,0x3b] := by
  refine ⟨?_, ?_, ?_⟩ <;> decide

/-! ## SWT-050 — the 8-byte LE spent amount is field 6 of the preimage -/

@[rule "SWT-050"]
theorem bip143MsgL_amount_field (tx : Tx) (nIn : Nat) (sc : Bytes) (ht : UInt32)
    (amount : Amount) :
    bip143MsgL tx nIn sc ht amount =
      (serU32L tx.version.toUInt32 ++ hashPrevoutsL tx ht ++ hashSequenceL tx ht
        ++ serOutpointL (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).prevout
        ++ encCSL sc.length ++ sc)
      ++ serAmountL amount
      ++ (serU32L (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).sequence
        ++ hashOutputsL tx nIn ht ++ serU32L tx.locktime ++ serU32L ht) := by
  simp only [bip143MsgL, List.append_assoc]

/-! ## SWT-051 — the 4-byte LE hashtype is the final field -/

@[rule "SWT-051"]
theorem bip143MsgL_hashtype_tail (tx : Tx) (nIn : Nat) (sc : Bytes) (ht : UInt32)
    (amount : Amount) :
    bip143MsgL tx nIn sc ht amount =
      (serU32L tx.version.toUInt32 ++ hashPrevoutsL tx ht ++ hashSequenceL tx ht
        ++ serOutpointL (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).prevout
        ++ encCSL sc.length ++ sc
        ++ serAmountL amount
        ++ serU32L (tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩).sequence
        ++ hashOutputsL tx nIn ht ++ serU32L tx.locktime)
      ++ serU32L ht := by
  simp only [bip143MsgL, List.append_assoc]

end BitcoinProofs.AF.PDW23
