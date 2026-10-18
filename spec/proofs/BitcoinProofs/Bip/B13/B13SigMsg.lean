import Bitcoin.Crypto.Taproot.Sighash
import Bitcoin.Crypto.Taproot.Tree
import Bitcoin.Interpreter.Defs
import Bitcoin.Interpreter.Hashes

/-!
# B13 — BIP341 kill-vector corpus: SigMsg / sighash / tapleaf / tweak

2026-10-16. Ground truth NOT read off the Lean code:

* the BIP text — bip-0341.mediawiki @ master (BSD-3-Clause), sections
  "Common signature message"
  and "Script validation rules";
* the OFFICIAL corpus `spec/vectors/bips/bip-0341_wallet-test-vectors.json`
  (keyPathSpending[0] + scriptPubKey cases 4/5);
* a python reference — implements SigMsg, sha_annex,
  tapleaf/branch/root and BIP340 verify from the BIP text. Self-checks:
  5/5 sub-hashes vs official intermediaries; the OFFICIAL fullySignedTx
  65-byte signature (ht 0x03) BIP340-VERIFIES against the
  `sighash_single` digest below; a self-signed ht 0x00 round-trip;
  leaves/root/tweak/tweakedPubkey match official for cases 4 and 5.

Why: the SigMsg lane (TPR-032/033/039/041/042/006) had NO test anywhere —
`sigMsgTaproot`/`sighashTaproot` are referenced by no Lean or python test
(the crosscheck file named in Sighash.lean's docstring does not exist),
and NO TPR row carries a test_vector_id (rules.yaml column is `[]` for
all 692 rows; vector_ids.yaml maps 0 TPR rules). Every `decide` below
FAILS if a field is dropped, reordered, double-hashed, zeroed instead of
omitted, or if the annex prefix / epoch byte is mutated.

All theorems sorry-free; `native_decide` (compiler-backed, Lean.ofReduceBool
axiom — Y02/Y03/Y07 precedent) after kernel `decide` hit reduction
stalls on the sha256 pipeline; every theorem is sorry-free.
-/

namespace BitcoinProofs.Bip.B13.SigMsg

set_option maxRecDepth 100000

open Bitcoin.Data
open Bitcoin.Crypto.Taproot (shaPrevouts shaSpentAmounts shaSpentScripts
  shaSequences shaOutputs shaAnnex sigMsgTaproot sighashTaproot TapSighashEnv
  taptweak tapLeaf taprootMerkleRoot)
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)
open Bitcoin.Interpreter (hashSha256 verifyWitnessProgram isPayToAnchor)

set_option autoImplicit false

/-! ## Hex helpers (test infra only; Y08 pattern) -/

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

/-! ## Fixtures — the OFFICIAL keyPathSpending[0] transaction
(9 inputs / 2 outputs, locktime 500000000; b13_ref.py decodes
`rawUnsignedTx` and emits this literal byte-for-byte) -/

def annex13 : ByteArray := fromHex "50beefbeefbeefbeefbeefbeefbeefbeef"

def tx9 : Bitcoin.Data.Tx :=
  { version := 2
    vin := [⟨⟨fromHex "7de20cbff686da83a54981d2b9bab3586f4ca7e48f57f5b55963115f3b334e9c", 0x00000001⟩, ⟨ByteArray.empty⟩, 0x00000000⟩,
         ⟨⟨fromHex "d7b7cab57b1393ace2d064f4d4a2cb8af6def61273e127517d44759b6dafdd99", 0x00000000⟩, ⟨ByteArray.empty⟩, 0xffffffff⟩,
         ⟨⟨fromHex "f8e1f583384333689228c5d28eac13366be082dc57441760d957275419a41842", 0x00000000⟩, ⟨ByteArray.empty⟩, 0xffffffff⟩,
         ⟨⟨fromHex "f0689180aa63b30cb162a73c6d2a38b7eeda2a83ece74310fda0843ad604853b", 0x00000001⟩, ⟨ByteArray.empty⟩, 0xfffffffe⟩,
         ⟨⟨fromHex "aa5202bdf6d8ccd2ee0f0202afbbb7461d9264a25e5bfd3c5a52ee1239e0ba6c", 0x00000000⟩, ⟨ByteArray.empty⟩, 0xfffffffe⟩,
         ⟨⟨fromHex "956149bdc66faa968eb2be2d2faa29718acbfe3941215893a2a3446d32acd050", 0x00000000⟩, ⟨ByteArray.empty⟩, 0x00000000⟩,
         ⟨⟨fromHex "e664b9773b88c09c32cb70a2a3e4da0ced63b7ba3b22f848531bbb1d5d5f4c94", 0x00000001⟩, ⟨ByteArray.empty⟩, 0x00000000⟩,
         ⟨⟨fromHex "e9aa6b8e6c9de67619e6a3924ae25696bb7b694bb677a632a74ef7eadfd4eabf", 0x00000000⟩, ⟨ByteArray.empty⟩, 0xffffffff⟩,
         ⟨⟨fromHex "a778eb6a263dc090464cd125c466b5a99667720b1c110468831d058aa1b82af1", 0x00000001⟩, ⟨ByteArray.empty⟩, 0xffffffff⟩]
    vout := [⟨1000000000, ⟨fromHex "76a91406afd46bcdfd22ef94ac122aa11f241244a37ecc88ac"⟩⟩,
          ⟨3410000000, ⟨fromHex "ac9a87f5594be208f8532db38cff670c450ed2fea8fcdefcc9a663f78bab962b"⟩⟩]
    locktime := 0x1dcd6500
    witness := [] }

def outs9 : List Bitcoin.Data.TxOut :=
  [⟨420000000, ⟨fromHex "512053a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda343"⟩⟩,
           ⟨462000000, ⟨fromHex "5120147c9c57132f6e7ecddba9800bb0c4449251c92a1e60371ee77557b6620f3ea3"⟩⟩,
           ⟨294000000, ⟨fromHex "76a914751e76e8199196d454941c45d1b3a323f1433bd688ac"⟩⟩,
           ⟨504000000, ⟨fromHex "5120e4d810fd50586274face62b8a807eb9719cef49c04177cc6b76a9a4251d5450e"⟩⟩,
           ⟨630000000, ⟨fromHex "512091b64d5324723a985170e4dc5a0f84c041804f2cd12660fa5dec09fc21783605"⟩⟩,
           ⟨378000000, ⟨fromHex "00147dd65592d0ab2fe0d0257d571abf032cd9db93dc"⟩⟩,
           ⟨672000000, ⟨fromHex "512075169f4001aa68f15bbed28b218df1d0a62cbbcf1188c6665110c293c907b831"⟩⟩,
           ⟨546000000, ⟨fromHex "5120712447206d7a5238acc7ff53fbe94a3b64539ad291c7cdbc490b7577e4b17df5"⟩⟩,
           ⟨588000000, ⟨fromHex "512077e30a5522dd9f894c3f8b8bd4c4b2cf82ca7da8a3ea6a239655c39c050ab220"⟩⟩]

def env9 : TapSighashEnv := ⟨tx9, outs9⟩

/-- ScriptExecutionData with the annex lane initialized, no annex. -/
def edNone : ScriptExecutionData := { annexInit := true }

/-- ScriptExecutionData with a PRESENT annex and the CORRECT BIP341
`sha_annex` (CompactSize prefix — see section 6). -/
def edAnnex : ScriptExecutionData :=
  { annexInit := true, annexPresent := true, annexHash := shaAnnex annex13 }


/-! ## 1 — the five sub-hashes on the OFFICIAL keyPathSpending[0] tx
(9 inputs / 2 outputs; literals = official `intermediary.hash*` fields,
self-checked 5/5 by `b13_ref.py`). Kills any mutation of the field
serializations behind TPR-034..038. -/

theorem subhash_prevouts :
    bytesBEq (shaPrevouts tx9)
      (fromHex "e3b33bb4ef3a52ad1fffb555c0d82828eb22737036eaeb02a235d82b909c4c3f") = true := by native_decide

theorem subhash_amounts :
    bytesBEq (shaSpentAmounts outs9)
      (fromHex "58a6964a4f5f8f0b642ded0a8a553be7622a719da71d1f5befcefcdee8e0fde6") = true := by native_decide

theorem subhash_scriptpubkeys :
    bytesBEq (shaSpentScripts outs9)
      (fromHex "23ad0f61ad2bca5ba6a7693f50fce988e17c3780bf2b1e720cfbb38fbdd52e21") = true := by native_decide

theorem subhash_sequences :
    bytesBEq (shaSequences tx9)
      (fromHex "18959c7221ab5ce9e26c3cd67b22c24f8baa54bac281d8e6b05e400e6c3a957e") = true := by native_decide

theorem subhash_outputs :
    bytesBEq (shaOutputs tx9)
      (fromHex "a2e6dab7c1f0dcd297c8d61647fd17d821541ea69c3cc37dcbad7f90d4eb4bc5") = true := by native_decide


/-! ## 2 — SigMsg byte-exactness (TPR-033; BIP341 section "Common
signature message", field order/omission verbatim). -/


/-- SIGHASH_DEFAULT (implicit ALL, no hashtype byte). -/
theorem sigmsg_default :
    bytesBEq (sigMsgTaproot env9 0 0x00 SigVersion.taproot edNone).get!
      (fromHex "00020000000065cd1de3b33bb4ef3a52ad1fffb555c0d82828eb22737036eaeb02a235d82b909c4c3f58a6964a4f5f8f0b642ded0a8a553be7622a719da71d1f5befcefcdee8e0fde623ad0f61ad2bca5ba6a7693f50fce988e17c3780bf2b1e720cfbb38fbdd52e2118959c7221ab5ce9e26c3cd67b22c24f8baa54bac281d8e6b05e400e6c3a957ea2e6dab7c1f0dcd297c8d61647fd17d821541ea69c3cc37dcbad7f90d4eb4bc50000000000") = true := by native_decide

/-- ALL. -/
theorem sigmsg_all :
    bytesBEq (sigMsgTaproot env9 0 0x01 SigVersion.taproot edNone).get!
      (fromHex "01020000000065cd1de3b33bb4ef3a52ad1fffb555c0d82828eb22737036eaeb02a235d82b909c4c3f58a6964a4f5f8f0b642ded0a8a553be7622a719da71d1f5befcefcdee8e0fde623ad0f61ad2bca5ba6a7693f50fce988e17c3780bf2b1e720cfbb38fbdd52e2118959c7221ab5ce9e26c3cd67b22c24f8baa54bac281d8e6b05e400e6c3a957ea2e6dab7c1f0dcd297c8d61647fd17d821541ea69c3cc37dcbad7f90d4eb4bc50000000000") = true := by native_decide

/-- NONE — sha_outputs omitted (not zeroed). -/
theorem sigmsg_none :
    bytesBEq (sigMsgTaproot env9 0 0x02 SigVersion.taproot edNone).get!
      (fromHex "02020000000065cd1de3b33bb4ef3a52ad1fffb555c0d82828eb22737036eaeb02a235d82b909c4c3f58a6964a4f5f8f0b642ded0a8a553be7622a719da71d1f5befcefcdee8e0fde623ad0f61ad2bca5ba6a7693f50fce988e17c3780bf2b1e720cfbb38fbdd52e2118959c7221ab5ce9e26c3cd67b22c24f8baa54bac281d8e6b05e400e6c3a957e0000000000") = true := by native_decide

/-- SINGLE — sha_single_output of vout 0. -/
theorem sigmsg_single :
    bytesBEq (sigMsgTaproot env9 0 0x03 SigVersion.taproot edNone).get!
      (fromHex "03020000000065cd1de3b33bb4ef3a52ad1fffb555c0d82828eb22737036eaeb02a235d82b909c4c3f58a6964a4f5f8f0b642ded0a8a553be7622a719da71d1f5befcefcdee8e0fde623ad0f61ad2bca5ba6a7693f50fce988e17c3780bf2b1e720cfbb38fbdd52e2118959c7221ab5ce9e26c3cd67b22c24f8baa54bac281d8e6b05e400e6c3a957e0000000000d0418f0e9a36245b9a50ec87f8bf5be5bcae434337b87139c3a5b1f56e33cba0") = true := by native_decide

/-- ALL|ANYONECANPAY — per-input slice. -/
theorem sigmsg_acp :
    bytesBEq (sigMsgTaproot env9 0 0x81 SigVersion.taproot edNone).get!
      (fromHex "81020000000065cd1da2e6dab7c1f0dcd297c8d61647fd17d821541ea69c3cc37dcbad7f90d4eb4bc5007de20cbff686da83a54981d2b9bab3586f4ca7e48f57f5b55963115f3b334e9c0100000000b108190000000022512053a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda34300000000") = true := by native_decide

/-- SINGLE + annex — spend_type low bit + sha_annex slot. -/
theorem sigmsg_single_annex :
    bytesBEq (sigMsgTaproot env9 0 0x03 SigVersion.taproot edAnnex).get!
      (fromHex "03020000000065cd1de3b33bb4ef3a52ad1fffb555c0d82828eb22737036eaeb02a235d82b909c4c3f58a6964a4f5f8f0b642ded0a8a553be7622a719da71d1f5befcefcdee8e0fde623ad0f61ad2bca5ba6a7693f50fce988e17c3780bf2b1e720cfbb38fbdd52e2118959c7221ab5ce9e26c3cd67b22c24f8baa54bac281d8e6b05e400e6c3a957e0100000000acef2e4cead64fe930e6673fbe48adb290c09450f96c2c5d41bad4e6ad0eea03d0418f0e9a36245b9a50ec87f8bf5be5bcae434337b87139c3a5b1f56e33cba0") = true := by native_decide

/-- ACP on input 4 — outpoint‖CTxOut‖nSequence of THAT input. -/
theorem sigmsg_acp_in4 :
    bytesBEq (sigMsgTaproot env9 4 0x81 SigVersion.taproot edNone).get!
      (fromHex "81020000000065cd1da2e6dab7c1f0dcd297c8d61647fd17d821541ea69c3cc37dcbad7f90d4eb4bc500aa5202bdf6d8ccd2ee0f0202afbbb7461d9264a25e5bfd3c5a52ee1239e0ba6c0000000080098d250000000022512091b64d5324723a985170e4dc5a0f84c041804f2cd12660fa5dec09fc21783605feffffff") = true := by native_decide

/-- ALL + annex — the 206-byte maximum shape. -/
theorem sigmsg_all_annex :
    bytesBEq (sigMsgTaproot env9 0 0x01 SigVersion.taproot edAnnex).get!
      (fromHex "01020000000065cd1de3b33bb4ef3a52ad1fffb555c0d82828eb22737036eaeb02a235d82b909c4c3f58a6964a4f5f8f0b642ded0a8a553be7622a719da71d1f5befcefcdee8e0fde623ad0f61ad2bca5ba6a7693f50fce988e17c3780bf2b1e720cfbb38fbdd52e2118959c7221ab5ce9e26c3cd67b22c24f8baa54bac281d8e6b05e400e6c3a957ea2e6dab7c1f0dcd297c8d61647fd17d821541ea69c3cc37dcbad7f90d4eb4bc50100000000acef2e4cead64fe930e6673fbe48adb290c09450f96c2c5d41bad4e6ad0eea03") = true := by native_decide


/-! ## 3 — the full sighash: epoch byte + TapSighash tagged hash (TPR-032).

`sighash_single` is the digest the OFFICIAL keyPathSpending[0] 65-byte
signature BIP340-verifies against (b13_ref.py) — a byte-for-byte
kill-vector for the whole key-path message chain. `sighash_default`
round-trips through a self-signed BIP340 signature. -/


theorem sighash_default :
    bytesBEq (sighashTaproot env9 0 0x00 SigVersion.taproot edNone).get!
      (fromHex "f4b7d7c520325939370e4598ac01946b6fc6edf7fe2325f434ff1b061f1834e3") = true := by native_decide

theorem sighash_all :
    bytesBEq (sighashTaproot env9 0 0x01 SigVersion.taproot edNone).get!
      (fromHex "674191694e4c979a71522ff9b7a751fd22791cfeb903b69230575998853efbf1") = true := by native_decide

theorem sighash_none :
    bytesBEq (sighashTaproot env9 0 0x02 SigVersion.taproot edNone).get!
      (fromHex "c171721c56da2aae36ac302c75f34b892481ab6139e8c98544679f42b0ec9ec5") = true := by native_decide

theorem sighash_single :
    bytesBEq (sighashTaproot env9 0 0x03 SigVersion.taproot edNone).get!
      (fromHex "2514a6272f85cfa0f45eb907fcb0d121b808ed37c6ea160a5a9046ed5526d555") = true := by native_decide

theorem sighash_acp :
    bytesBEq (sighashTaproot env9 0 0x81 SigVersion.taproot edNone).get!
      (fromHex "2683c3b5b438c0496b2c08c8cf8735bceb6bf4e420032b1680ce5b5aa54138d2") = true := by native_decide

theorem sighash_single_annex :
    bytesBEq (sighashTaproot env9 0 0x03 SigVersion.taproot edAnnex).get!
      (fromHex "eda4769211d5c8d494a036bc1b4fc40ca7abc14a94f0943a2af8b3bb7dd7bfbd") = true := by native_decide

theorem sighash_acp_in4 :
    bytesBEq (sighashTaproot env9 4 0x81 SigVersion.taproot edNone).get!
      (fromHex "4eb26a27e967958cbfaa0a318695758c3f57861a7770ea55e7ab6065f294faae") = true := by native_decide

theorem sighash_all_annex :
    bytesBEq (sighashTaproot env9 0 0x01 SigVersion.taproot edAnnex).get!
      (fromHex "d0157701c50734c04d75236b5fe816c910abb199900d19263d6668b183632a73") = true := by native_decide


/-! ## 4 — fail-closed negatives (TPR-030/041/042 kill-vectors) -/

/-- SIGHASH_SINGLE with in_pos = 2 ≥ vout.length = 2: no corresponding
output → hashtype error (BIP341 §SigMsg restrictions; TPR-042). -/
theorem single_out_of_range_none :
    sigMsgTaproot env9 2 0x03 SigVersion.taproot edNone = none := by native_decide

/-- Undefined hash_type 0x40 ∉ {0x00,0x01,0x02,0x03,0x81,0x82,0x83} →
reject (BIP341 §SigMsg; TPR-030). -/
theorem hashtype_0x40_none :
    sigMsgTaproot env9 0 0x40 SigVersion.taproot edNone = none := by native_decide

/-- ACP with in_pos = 9 ≥ vin.length = 9: out-of-range input (caller
contract) → fail-closed (TPR-041). -/
theorem acp_out_of_range_none :
    sigMsgTaproot env9 9 0x81 SigVersion.taproot edNone = none := by native_decide


/-! ## 5 — the SigMsg length formula (BIP341 footnote: 174 − acp·49 −
none·32 + annex·32; maximum 206). All eight shape sizes pinned. -/


theorem sigmsg_size_default :
    (sigMsgTaproot env9 0 0x00 SigVersion.taproot edNone).get!.size = 174 := by native_decide

theorem sigmsg_size_all :
    (sigMsgTaproot env9 0 0x01 SigVersion.taproot edNone).get!.size = 174 := by native_decide

theorem sigmsg_size_none :
    (sigMsgTaproot env9 0 0x02 SigVersion.taproot edNone).get!.size = 142 := by native_decide

theorem sigmsg_size_single :
    (sigMsgTaproot env9 0 0x03 SigVersion.taproot edNone).get!.size = 174 := by native_decide

theorem sigmsg_size_acp :
    (sigMsgTaproot env9 0 0x81 SigVersion.taproot edNone).get!.size = 125 := by native_decide

theorem sigmsg_size_single_annex :
    (sigMsgTaproot env9 0 0x03 SigVersion.taproot edAnnex).get!.size = 206 := by native_decide

theorem sigmsg_size_acp_in4 :
    (sigMsgTaproot env9 4 0x81 SigVersion.taproot edNone).get!.size = 125 := by native_decide

theorem sigmsg_size_all_annex :
    (sigMsgTaproot env9 0 0x01 SigVersion.taproot edAnnex).get!.size = 206 := by native_decide


/-! ## 6 — sha_annex carries the CompactSize prefix (TPR-006), and the
`Bitcoin.Interpreter.Defs.verifyWitnessProgram` annex wiring (plain
`hashSha256` of the annex, NO length prefix, Defs.lean:1222) is NOT the
BIP341 value. Kill-vector for any wiring that drops the CSize prefix. -/

theorem shaAnnex_compactsize_prefix :
    bytesBEq (shaAnnex (fromHex "50beefbeefbeefbeefbeefbeefbeefbeef"))
      (fromHex "acef2e4cead64fe930e6673fbe48adb290c09450f96c2c5d41bad4e6ad0eea03") = true := by native_decide

theorem defsWiring_plainSha_value :
    bytesBEq (hashSha256 (fromHex "50beefbeefbeefbeefbeefbeefbeefbeef"))
      (fromHex "15f7fb4d491966985607000e9d342f3db0fb5a8e01dece75d2cfb7706ef66200") = true := by native_decide

/-- The divergence: plain SHA256 of the annex ≠ sha_annex. -/
theorem defsWiring_diverges :
    bytesBEq (hashSha256 (fromHex "50beefbeefbeefbeefbeefbeefbeefbeef"))
      (shaAnnex (fromHex "50beefbeefbeefbeefbeefbeefbeefbeef")) = false := by native_decide



/-! ## 7 — tapleaf hash, sorted TapBranch walk, merkle root (TPR-012/013/014)

Official scriptPubKey cases 4 (two leaves) and 5 (three leaves, nested
right); leafHashes / merkleRoot literals are the official `intermediary`
fields, self-checked by b13_ref.py. The walks pin BOTH sort orders. -/

theorem tapleaf_case4_leaf0 :
    bytesBEq (tapLeaf 0xc0 (fromHex "2044b178d64c32c4a05cc4f4d1407268f764c940d20ce97abfd44db5c3592b72fdac"))
      (fromHex "64512fecdb5afa04f98839b50e6f0cb7b1e539bf6f205f67934083cdcc3c8d89") = true := by native_decide

theorem tapleaf_case4_leaf1 :
    bytesBEq (tapLeaf 0xc0 (fromHex "07546170726f6f74"))
      (fromHex "2cb2b90daa543b544161530c925f285b06196940d6085ca9474d41dc3822c5cb") = true := by native_decide

/-- Case 4 root: leaf 0's path = [the sibling]; the sort puts the smaller
digest first inside `tapBranch`. -/
theorem merkleRoot_case4 :
    bytesBEq (taprootMerkleRoot [fromHex "2cb2b90daa543b544161530c925f285b06196940d6085ca9474d41dc3822c5cb"] (fromHex "64512fecdb5afa04f98839b50e6f0cb7b1e539bf6f205f67934083cdcc3c8d89"))
      (fromHex "ab179431c28d3b68fb798957faf5497d69c883c6fb1e1cd9f81483d87bac90cc") = true := by native_decide

theorem tapleaf_case5_leaf0 :
    bytesBEq (tapLeaf 0xc0 (fromHex "2072ea6adcf1d371dea8fba1035a09f3d24ed5a059799bae114084130ee5898e69ac"))
      (fromHex "2645a02e0aac1fe69d69755733a9b7621b694bb5b5cde2bbfc94066ed62b9817") = true := by native_decide

theorem tapleaf_case5_leaf1 :
    bytesBEq (tapLeaf 0xc0 (fromHex "202352d137f2f3ab38d1eaa976758873377fa5ebb817372c71e2c542313d4abda8ac"))
      (fromHex "ba982a91d4fc552163cb1c0da03676102d5b7a014304c01f0c77b2b8e888de1c") = true := by native_decide

theorem tapleaf_case5_leaf2 :
    bytesBEq (tapLeaf 0xc0 (fromHex "207337c0dd4253cb86f2c43a2351aadd82cccb12a172cd120452b9bb8324f2186aac"))
      (fromHex "9e31407bffa15fefbf5090b149d53959ecdf3f62b1246780238c24501d5ceaf6") = true := by native_decide

/-- Case 5 inner branch: leaf 1's walk inside the right subtree reaches
the nested subtree digest (sort direction h2 < h1). -/
theorem merkleRoot_case5_inner :
    bytesBEq (taprootMerkleRoot [fromHex "9e31407bffa15fefbf5090b149d53959ecdf3f62b1246780238c24501d5ceaf6"] (fromHex "ba982a91d4fc552163cb1c0da03676102d5b7a014304c01f0c77b2b8e888de1c"))
      (fromHex "ffe578e9ea769027e4f5a3de40732f75a88a6353a09d767ddeb66accef85e553") = true := by native_decide

/-- Case 5 leaf 1's FULL walk: k1 →(h2)→ h12 →(h0)→ root — the two-level
fold through `taprootMerkleRoot`, both sort directions exercised. -/
theorem merkleRoot_case5_leaf1_full :
    bytesBEq (taprootMerkleRoot [fromHex "2645a02e0aac1fe69d69755733a9b7621b694bb5b5cde2bbfc94066ed62b9817"]
                (taprootMerkleRoot [fromHex "9e31407bffa15fefbf5090b149d53959ecdf3f62b1246780238c24501d5ceaf6"] (fromHex "ba982a91d4fc552163cb1c0da03676102d5b7a014304c01f0c77b2b8e888de1c")))
      (fromHex "ccbd66c6f7e8fdab47b3a486f59d28262be857f30d4773f2d5ea47f7761ce0e2") = true := by native_decide



/-! ## 8 — TapTweak domain separation: root = some root / none (TPR-015;
tweak literals = official `intermediary.tweak`). -/

theorem taptweak_case4 :
    bytesBEq (taptweak (fromHex "f9f400803e683727b14f463836e1e78e1c64417638aa066919291a225f0e8dd8") (some (fromHex "ab179431c28d3b68fb798957faf5497d69c883c6fb1e1cd9f81483d87bac90cc")))
      (fromHex "639f0281b7ac49e742cd25b7f188657626da1ad169209078e2761cefd91fd65e") = true := by native_decide

theorem taptweak_case5 :
    bytesBEq (taptweak (fromHex "e0dfe2300b0dd746a3f8674dfd4525623639042569d829c7f0eed9602d263e6f") (some (fromHex "ccbd66c6f7e8fdab47b3a486f59d28262be857f30d4773f2d5ea47f7761ce0e2")))
      (fromHex "b57bfa183d28eeb6ad688ddaabb265b4a41fbf68e5fed2c72c74de70d5a786f4") = true := by native_decide

/-- keyPathSpending[0]: merkle_root = null → tweak over p alone (the
BIP341 "commit to an unspendable script path" lane). -/
theorem taptweak_keypath_none :
    bytesBEq (taptweak (fromHex "d6889cb081036e0faefa3a35157ad71086b123b2b144b649798b494c300a961d") none)
      (fromHex "b86e7be8f39bab32a6f2c0443abbc210f0edac0e2c53d501b36b64437d9c6c70") = true := by native_decide



/-! ## 9 — witness-gate kills (BIP341 SS"Script validation rules", clauses
1-2): the `verifyWitnessProgram` v1 gate itself — empty witness FAILS,
and non-taproot v1 shapes (P2SH-wrapped; non-32-byte program) stay
UNENCUMBERED (`ok`), exactly BIP341's "any other outputs ... remain
unencumbered". Mainnet consensus flags = base set
(P2SH|WITNESS|TAPROOT, validation.cpp:2256-2260). -/

/-- BIP341 clause: "Fail if the witness stack has 0 elements" (v1-32,
TAPROOT active). -/
theorem v1_empty_witness_fail (fuel : Nat) (program : ByteArray)
    (pol : Bitcoin.Interpreter.PolicyFlags) (chk : Bitcoin.Interpreter.ScriptChecker)
    (h32 : program.size = 32) :
    verifyWitnessProgram fuel [] 1 program
      { p2sh := true, witness := true, taproot := true } pol chk false
      = .fail .witnessProgramWitnessEmpty := by
  simp [verifyWitnessProgram, h32]

/-- BIP341 clause: "P2SH-wrapped version 1 outputs remain unencumbered"
(the `!isP2SH` conjunct of the taproot gate; isP2SH = true here). -/
theorem v1_p2sh_wrapped_unencumbered (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (flags : Bitcoin.Activation.ScriptFlags)
    (pol : Bitcoin.Interpreter.PolicyFlags)
    (chk : Bitcoin.Interpreter.ScriptChecker) (h32 : program.size = 32)
    (hdisc : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel witness 1 program flags pol chk true = .ok := by
  simp [verifyWitnessProgram, h32, hdisc]

/-- BIP341 clause: "version 1 outputs with lengths other than 32 bytes
remain unencumbered" (native v1, 20-byte program; the P2A template is
2 bytes, so a 20-byte program never classifies as the anchor). -/
theorem v1_wrong_length_unencumbered (fuel : Nat) (witness : WitnessStack)
    (program : ByteArray) (pol : Bitcoin.Interpreter.PolicyFlags)
    (chk : Bitcoin.Interpreter.ScriptChecker)
    (h20 : program.size = 20)
    (hanchor : isPayToAnchor 1 program = false)
    (hdisc : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel witness 1 program
      { p2sh := true, witness := true, taproot := true } pol chk false = .ok := by
  simp [verifyWitnessProgram, h20, hanchor, hdisc]

end BitcoinProofs.Bip.B13.SigMsg
