import Bitcoin.SigHash.Interface
import Bitcoin.Crypto.Schnorr.Verify
import Bitcoin.Crypto.Taproot.TapTweak
import Bitcoin.Capstone.Merkle
import Bitcoin.Serialization.Interface
import Bitcoin.Data.Basic
import Bitcoin.Data.Tx

/-! # GENERATED FILE — do not hand-edit.
Regenerate: python3 spec/scripts/audit/gen_mutation_pack.py

MutationPackCrypto: native_decide conformance pins (digests + EC).
§2 BIP143 worked-example digests, §3 BIP340 msg-size non-gate,
§4 TapTweak, §5 Capstone merkle + witness commitment + the
CVE-2012-2459 root-equality property (real sha256d).
-/

namespace Test.Audit.MutationPack

open Bitcoin.Data Bitcoin.SigHash Bitcoin.Serialization
open Bitcoin.Crypto.Schnorr.Verify Bitcoin.Crypto.Taproot
open Bitcoin.Capstone.Merkle Bitcoin.Crypto.Curve.Secp

set_option maxRecDepth 100000
set_option maxHeartbeats 1000000

-- hex helpers (Test.Sighash pattern; compile-time constants)
private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

private def fromHex (s : String) : ByteArray :=
  go (s.toList.filter (fun c => c != '\n' && c != ' ')) ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc

private def beHex (s : String) : ByteArray := fromHex s
private def bytes (a : Array UInt8) : ByteArray := ByteArray.mk a
private def txOf (hex : String) : Tx :=
  match decodeTx (fromHex hex) with
  | .ok t => t
  | .error _ => ⟨0, [], [], 0, []⟩   -- fixtures decode; never hit
private def scOf (hex : String) : Script := ⟨fromHex hex⟩
private def bOf (hex : String) : Bytes := bL (fromHex hex)

/-! ## §2 BIP143 worked-example digests (bip-0143.mediawiki) -/

-- E1 (ALL): full 10-field preimage order, real digests.
example : bytesBEq (signatureHashBip143 (txOf "0100000002fff7f7881a8099afa6940d42d1e7f6362bec38171ea3edf433541db4e4ad969f0000000000eeffffffef51e1b804cc89d182d279655c3aa89e815b1b309fe287d9b2b55d57b90ec68a0100000000ffffffff02202cb206000000001976a9148280b37df378db99f66f85c95a783a76ac7a6d5988ac9093510d000000001976a9143bde42dbee7e4dbe6a21b2d50ce2f0167faa815988ac11000000") 1
    (scOf "76a9141d0f172a0ecb48aee1be1f2687d2963ae33f71a188ac") 0x01 600000000)
    (beHex "c37af31116d1b27caf68aae9e3ac82f1477929014d5b917657d0eb49478cb670") = true := by native_decide

-- E3a: SIGHASH_SINGLE out-of-range ⇒ hashOutputs = ZERO (the
-- tri-modal BIP143 arm; NOT uint256::ONE — bip-0143 E3).
example : bytesBEq (signatureHashBip143 (txOf "0100000002fe3dc9208094f3ffd12645477b3dc56f60ec4fa8e6f5d67c565d1c6b9216b36e0000000000ffffffff0815cf020f013ed6cf91d29f4202e8a58726b1ac6c79da47c23d1bee0a6925f80000000000ffffffff0100f2052a010000001976a914a30741f8145e5acadf23f751864167f32e0963f788ac00000000") 1
    (scOf "21026dccc749adc2a9d0d89497ac511f760f45c47dc5ed9cf352a58ac706453880aeadab210255a9626aebf5e29c0e6538428ba0d1dcf6ca98ffdf086aa8ced5e0d0215ea465ac") 0x03 4900000000)
    (beHex "82dde6e4f1e94d02c2b7ad03d2115d691f48d064e9d52f58194a6637e4194391") = true := by native_decide

-- E4a: SINGLE|ANYONECANPAY — hashPrevouts/hashSequence ZERO.
example : bytesBEq (signatureHashBip143 (txOf "0100000002e9b542c5176808107ff1df906f46bb1f2583b16112b95ee5380665ba7fcfc0010000000000ffffffff80e68831516392fcd100d186b3c2c7b95c80b53c77e77c35ba03a66b429a2a1b0000000000ffffffff0280969800000000001976a914de4b231626ef508c9a74a8517e6783c0546d6b2888ac80969800000000001976a9146648a8cd4531e1ec47f35916de8e259237294d1e88ac00000000") 0
    (scOf "0063ab68210392972e2eb617b2388771abe27235fd5ac44af8e61693261550447a4c3e39da98ac") 0x83 16777215)
    (beHex "e9071e75e25b8a1e298a72f0d2e9f4f95a0f5cdf86a533cda597eb402ed13b3a") = true := by native_decide

/-! ## §3 BIP340 msg-size non-gate (X02's spec fix, regression guard) -/

-- The message is NOT size-gated (bip-0340 step 1 gates only
-- sig=64/pk=32; X02's first draft gated msg=32 and vectors 15-18
-- caught it). Valid signatures over 0- and 64-byte messages
-- (official reference.py schnorr_sign, aux = zeros):
def b340pk : ByteArray := beHex "256099f819e3901bc6e4f3aab3c7765472df6ad23e691ed7c092ca7b5617b0f1"
def b340sig0 : ByteArray := beHex "dd6a8ead4aed140a6aeb2e721f8f23929658ccad05dc75cd160fc143e688654cf76080996d9797d412ab43a17f1a37658d28683d557ee0f174fb7b9d9ce28812"
def b340sig64 : ByteArray := beHex "c08e80dd2ba8456356eef5112147e8cce5af0f51896df505fb7a10f168c5aae0f0c993267dd40314ac57045c87ff52f3262d12978a1685233fa9b6bbce9537da"
example : verifyImpl b340sig0 b340pk (beHex "") = true := by native_decide
example : verifyImpl b340sig64 b340pk
    (bytes #[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63]) = true := by native_decide
-- 65-byte signature: base gate rejects (a `>= 64` loosening would
-- accept — the extra byte is never extracted):
def b340sig65 : ByteArray := beHex "dd6a8ead4aed140a6aeb2e721f8f23929658ccad05dc75cd160fc143e688654cf76080996d9797d412ab43a17f1a37658d28683d557ee0f174fb7b9d9ce2881200"
example : verifyImpl b340sig65 b340pk (beHex "") = false := by native_decide
-- corrupted-r signature: base rejects at the x(R)=r check (an
-- accept-all spine would accept):
def b340sigBad : ByteArray := beHex "dc6a8ead4aed140a6aeb2e721f8f23929658ccad05dc75cd160fc143e688654cf76080996d9797d412ab43a17f1a37658d28683d557ee0f174fb7b9d9ce28812"
example : verifyImpl b340sigBad b340pk (beHex "") = false := by native_decide

/-! ## §4 TapTweak (BIP341): tagged hash + output-key equation -/

def twP : ByteArray := beHex "202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f"
def twRoot : ByteArray := beHex "a0a1a2a3a4a5a6a7a8a9aaabacadaeafb0b1b2b3b4b5b6b7b8b9babbbcbdbebf"
-- taptweak p none = taggedHash "TapTweak" p (tag‖tag‖msg,
-- hashlib-verified):
example : taptweak twP none = beHex "feab942dfaaece71b4e5c3ac3d09b57442bd9d02b0682ddede9d46588c93f33f" := by native_decide
-- taptweak p (some root) = taggedHash "TapTweak" (p ‖ root):
example : taptweak twP (some twRoot) = beHex "aa97dad4e2e46f8958fc78d59e7033605e11f5b108607f949feeb04e4247b17e" := by native_decide
-- tweakPoint: Q = P + int(t)·G, t = tweakScalar (big-endian), for a
-- REAL x-only key (official-vector-derived), root none / some:
example : tweakPoint (beHex "256099f819e3901bc6e4f3aab3c7765472df6ad23e691ed7c092ca7b5617b0f1")
    (some (16906255371783834923850040444051183935340707224966366242989890916111112188145, 14088023395070399822515760061054606699990044898431894711576607781426755088210)) none
    = some (67228702288663855456479341168483241681895152075532835335905868526977765549091, 87747601208147985609279038672332030130291538409549675245857808108671397764783) := by native_decide
example : tweakPoint (beHex "256099f819e3901bc6e4f3aab3c7765472df6ad23e691ed7c092ca7b5617b0f1")
    (some (16906255371783834923850040444051183935340707224966366242989890916111112188145, 14088023395070399822515760061054606699990044898431894711576607781426755088210)) (some twRoot)
    = some (20317148914368116133504279538165982419310893612643538517033473457102188544973, 74480018027366694154552073328982177108719743110665229502288246384259399876429) := by native_decide

/-! ## §5 Capstone merkle + witness commitment + CVE-2012-2459 -/

def blk_base_even : ByteArray := beHex "040000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a9dfcf2c959f7b186a46ea7da980c6a2bb07412fb27b4fe07bc347709d1cdd0a16400005fffff001d12746c780201000000010000000000000000000000000000000000000000000000000000000000000000ffffffff025151ffffffff0100f2052a0100000001510000000001000000014142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f600000000000ffffffff018403000000000000015100000000"
def blk_mut_even_dup_tail : ByteArray := beHex "040000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a9dfcf2c959f7b186a46ea7da980c6a2bb07412fb27b4fe07bc347709d1cdd0a16400005fffff001d12746c780301000000010000000000000000000000000000000000000000000000000000000000000000ffffffff025151ffffffff0100f2052a0100000001510000000001000000014142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f600000000000ffffffff01840300000000000001510000000001000000014142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f600000000000ffffffff018403000000000000015100000000"
def blk_base_odd : ByteArray := beHex "040000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0ab31e57a10f1deb038f7d452aeedf867386fdc18fb537d755fc5ab43e53090be16400005fffff001db7145c410301000000010000000000000000000000000000000000000000000000000000000000000000ffffffff025151ffffffff0100f2052a0100000001510000000001000000014142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f600000000000ffffffff01840300000000000001510000000001000000016162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f800000000000ffffffff01bc02000000000000015100000000"
def blk_mut_odd_dup_tail : ByteArray := beHex "040000000a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0a0ab31e57a10f1deb038f7d452aeedf867386fdc18fb537d755fc5ab43e53090be16400005fffff001db7145c410401000000010000000000000000000000000000000000000000000000000000000000000000ffffffff025151ffffffff0100f2052a0100000001510000000001000000014142434445464748494a4b4c4d4e4f505152535455565758595a5b5c5d5e5f600000000000ffffffff01840300000000000001510000000001000000016162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f800000000000ffffffff01bc0200000000000001510000000001000000016162636465666768696a6b6c6d6e6f707172737475767778797a7b7c7d7e7f800000000000ffffffff01bc02000000000000015100000000"

-- base blocks: computed txid root == header root (BLK-010).
example : (match decodeBlock blk_base_odd with
  | .ok (h, txs) => bytesBEq h.hashMerkleRoot (merkleRootOfBlock txs)
  | .error _ => false) = true := by native_decide
example : (match decodeBlock blk_base_even with
  | .ok (h, txs) => bytesBEq h.hashMerkleRoot (merkleRootOfBlock txs)
  | .error _ => false) = true := by native_decide
-- THE CVE-2012-2459 PROPERTY, in Lean, real sha256d: the odd-base
-- mutant (dup tail) has the SAME merkle root as its twin (the
-- odd-level duplication BLK-008 folds the duplicate pair
-- identically); the even-base mutant's root DIFFERS.
def rootOf (blk : ByteArray) : ByteArray :=
  match decodeBlock blk with
  | .ok (_, txs) => merkleRootOfBlock txs
  | .error _ => Bitcoin.Data.zeroBytes 32
example : bytesBEq (rootOf blk_base_odd) (rootOf blk_mut_odd_dup_tail) = true
  := by native_decide
example : bytesBEq (rootOf blk_base_even) (rootOf blk_mut_even_dup_tail) = false
  := by native_decide

-- witness commitment fixture (hashlib per merkle.cpp:118-126):
def wcb : Tx := txOf "01000000010000000000000000000000000000000000000000000000000000000000000000ffffffff0451515151ffffffff020000000000000000266a24aa21a9ed00491e0922bed1d6b0b62f0bcab368d7a6d9927b4255b808ed5d221ee68f1e5b0100000000000000015100000000"
def wspend : Tx := txOf "02000000000101c6bb6478d409f0bec4eaf014d4668fdc9072dbc744aff168b66fa09f62b530180000000000ffffffff0100e1f5050000000001510120222222222222222222222222222222222222222222222222222222222222222200000000"
example : bytesBEq (witnessMerkleRoot [wcb, wspend])
    (beHex "0c12a1d2330ee2e1852df991f3599e20e35eb7f6c558e7845fd057db01441590") = true := by native_decide
example : witnessCommitmentOk [wcb, wspend] wcb = true := by native_decide
example : commitmentValueZero wcb = true := by native_decide
-- the nonce rule: exactly one 32-byte witness item (the spend's
-- witness stack is the nonce slot):
example : commitmentNonceOk wspend = true := by native_decide

end Test.Audit.MutationPack
