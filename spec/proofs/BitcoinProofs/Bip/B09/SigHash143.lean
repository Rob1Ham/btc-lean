import Bitcoin.SigHash.Interface
import Bitcoin.Serialization.Interface

/-!
# B09 BIP143 kill-vector corpus — the digests the existing harness does NOT pin

Review-5 support suite contributor B09, 2026-10-16. NEW file, owned by B09.

BIP143 (Transaction Signature Verification for Version 0 Witness Program,
public domain, bitcoin/bips `bip-0143.mediawiki`). Ground truth: the BIP
text (vendored at `spec/vectors/bips/bip-0143.mediawiki`) and Core
`src/script/interpreter.cpp:1633-1670` @ `cce32b168`.

Audit context (findings: `spec/db/findings-w5/B09.md`): the kernel-checked
harness `spec/Test/Sighash/SighashTest.lean` pins BIP143 digests E1, E2,
E3a/E3b, E4a/E4b, E5(ALL) — the 7 worked examples — but leaves the
following consensus clauses WITHOUT any digest-level kill-vector:

  1. `SIGHASH_NONE` base ⇒ `hashOutputs = 0` and `hashSequence = 0` (non-ACP)
  2. `SIGHASH_SINGLE` in-range ⇒ `hashOutputs = dSHA256(vout[nIn])` (non-ACP)
  3. `ALL|ANYONECANPAY` ⇒ zero `hashPrevouts`/`hashSequence` while
     `hashOutputs` stays FULL (kills ACP/outputs conflation)
  4. `NONE|ANYONECANPAY` ⇒ all three sub-hashes zero
  5. `SINGLE|ANYONECANPAY` in-range (the 6-of-6 example's variant)
  6. **No FindAndDelete**: the two BIP §No-FindAndDelete examples, whose
     `scriptCode` literally CONTAINS the signature pushes (a legacy-style
     `FindAndDelete(sig)` inside the digest would change these digests)
  7. Non-standard base hashtype `0x41` (`& 0x1f` = ALL, `& 0x80` = 0):
     sub-hashes identical to the `0x01` case, field 10 carries the RAW
     4-byte `0x41` (kills exact-match classification and 1-byte framing)
  8. `SINGLE|ANYONECANPAY` does not commit to the input index: swapping the
     input/output PAIRS leaves both signatures valid (BIP's swapped tx)

Every expected digest below was cross-checked with an independent
python3 reference transcribed from the BIP text alone
(`scratch/B09/bip143_ref.py`, 18/18 PASS, 2026-10-16); the reference
reproduces all 10 BIP-published digests and both published full preimages
byte-exactly before the new constants were extracted.

The digest examples use `native_decide` (plain `decide` does not
whnf-reduce the SHA256 compression — see SighashTest header); the one
theorem is `unfold`/`rw`-only, sorry-free, with its axiom footprint pinned
by the `#guard_msgs in #print axioms` at the bottom.
-/

namespace BitcoinProofs.Bip.B09

open Bitcoin.Data Bitcoin.SigHash Bitcoin.Serialization

set_option maxRecDepth 100000
set_option maxHeartbeats 4000000

private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

private def hx (s : String) : ByteArray :=
  go (s.toList.filter (fun c => c != '\n' && c != ' ')) ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc

/-! ## Shared vectors (BIP §P2SH-P2WSH 6-of-6 example) -/

def txE5 : Tx :=
  { version := 1
    vin :=
      [ ⟨⟨hx "36641869ca081e70f394c6948e8af409e18b619df2ed74aa106c1ca29787b96e", 1⟩, Script.empty, 0xFFFFFFFF⟩ ]
    vout :=
      [ ⟨0x35a4e900, ⟨hx "76a914389ffce9cd9ae88dcc0631e88a821ffdbe9bfe2688ac"⟩⟩
        , ⟨0x052f83c0, ⟨hx "76a9147480a33f950689af511e6e84c138dbbd3c3ee41588ac"⟩⟩ ]
    locktime := 0
    witness := [] }

/-- The 6-of-6 multisig `witnessScript` (207 bytes), raw (no CompactSize
prefix — `bip143MsgL` adds it as the CTxOut-style serialization). -/
def scE5 : Script := ⟨hx "56210307b8ae49ac90a048e9b53357a2354b3334e9c8bee813ecb98e99a7e07e8c3ba3
  2103b28f0c28bfab54554ae8c658ac5c3e0ce6e79ad336331f78c428dd43eea8449b
  21034b8113d703413d57761b8b9781957b8c0ac1dfe69f492580ca4195f50376ba4a
  21033400f6afecb833092a9a21cfdf1ed1376e58c5d1f47de74683123987e967a8f4
  2103a6d48b1131e94ba04d9737d61acdaa1322008af9602b3b14862c07a1789aac16
  2102d8b661b0b3302ee2f162b09e07a55ad5dfbe673a9f01d9f0c19617681024306b56ae"⟩

def amtE5 : Amount := 987654321

/-! ## A — the four unpinned cells of the hashtype matrix (BIP §P2SH-P2WSH) -/

-- E5-NONE (0x02): kills `NONE ⇒ hashOutputs ≠ 0` and `NONE ⇒ hashSequence ≠ 0`.
-- BIP digest: e9733bc60ea13c95c6527066bb975a2ff29a925e80aa14c213f686cbae5d2f36
example : bytesBEq (signatureHashBip143 txE5 0 scE5 0x02 amtE5)
    (hx "e9733bc60ea13c95c6527066bb975a2ff29a925e80aa14c213f686cbae5d2f36") = true := by
  native_decide

-- E5-SINGLE (0x03, in range): kills `SINGLE ⇒ hashOutputs ≠ dSHA256(vout[0])`.
-- BIP digest: 1e1f1c303dc025bd664acb72e583e933fae4cff9148bf78c157d1e8f78530aea
example : bytesBEq (signatureHashBip143 txE5 0 scE5 0x03 amtE5)
    (hx "1e1f1c303dc025bd664acb72e583e933fae4cff9148bf78c157d1e8f78530aea") = true := by
  native_decide

-- E5-ALL|ACP (0x81): kills `ACP ⇒ hashOutputs = 0` (it must stay FULL here).
-- BIP digest: 2a67f03e63a6a422125878b40b82da593be8d4efaafe88ee528af6e5a9955c6e
example : bytesBEq (signatureHashBip143 txE5 0 scE5 0x81 amtE5)
    (hx "2a67f03e63a6a422125878b40b82da593be8d4efaafe88ee528af6e5a9955c6e") = true := by
  native_decide

-- E5-NONE|ACP (0x82): kills any arm that keeps a nonzero sub-hash here.
-- BIP digest: 781ba15f3779d5542ce8ecb5c18716733a5ee42a6f51488ec96154934e2c890a
example : bytesBEq (signatureHashBip143 txE5 0 scE5 0x82 amtE5)
    (hx "781ba15f3779d5542ce8ecb5c18716733a5ee42a6f51488ec96154934e2c890a") = true := by
  native_decide

-- E5-SINGLE|ACP (0x83, in range): completes the 8-row matrix alongside E1-E5.
-- BIP digest: 511e8e52ed574121fc1b654970395502128263f62662e076dc6baf05c2e6a99b
example : bytesBEq (signatureHashBip143 txE5 0 scE5 0x83 amtE5)
    (hx "511e8e52ed574121fc1b654970395502128263f62662e076dc6baf05c2e6a99b") = true := by
  native_decide

/-! ## B — No FindAndDelete (BIP §No FindAndDelete, both examples) -/

/-- BIP §No-FindAndDelete example 1 tx: P2WSH spend of `69c1…87f1` at
index 0x1d4c, single 1-sat output, `nHashType = 0x01`, amount 200000
(preimage amount field `400d030000000000`). The `scriptCode` is
`OP_CHECKSIGVERIFY ‖ push(72) ‖ <sig>` — the signature push is PART of the
scriptCode; a legacy-style `FindAndDelete(sig)` inside the digest would
shrink it and change the digest below. -/
def txF1 : Tx :=
  { version := 1
    vin :=
      [ ⟨⟨hx "69c12106097dc2e0526493ef67f21269fe888ef05c7a3a5dacab38e1ac8387f1", 0x1d4c⟩, Script.empty, 0xFFFFFFFF⟩ ]
    vout := [ ⟨1, Script.empty⟩ ]
    locktime := 0
    witness := [] }

-- BIP digest: 71c9cd9b2869b9c70b01b1f0360c148f42dee72297db312638df136f43311f23
example : bytesBEq (signatureHashBip143 txF1 0
    ⟨hx "ad4830450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e01"⟩
    0x01 200000)
    (hx "71c9cd9b2869b9c70b01b1f0360c148f42dee72297db312638df136f43311f23") = true := by
  native_decide

/-- BIP §No-FindAndDelete example 2 tx: `OP_CHECKMULTISIGVERIFY` variant,
`scriptCode = OP_2 ‖ OP_CHECKMULTISIGVERIFY ‖ push(72) ‖ <sig> ‖ push(72) ‖
<sig'> ‖ OP_VERIFY` (149 bytes, both signature pushes retained). -/
def txF2 : Tx :=
  { version := 1
    vin :=
      [ ⟨⟨hx "9275cb8d4a485ce95741c013f7c0d28722160008021bb469a11982d47a662896", 0x1d4c⟩, Script.empty, 0xFFFFFFFF⟩ ]
    vout := [ ⟨1, Script.empty⟩ ]
    locktime := 0
    witness := [] }

-- BIP digest: c1628a1e7c67f14ca0c27c06e4fdeec2e6d1a73c7a91d7c046ff83e835aebb72
example : bytesBEq (signatureHashBip143 txF2 0
    ⟨hx "52af4830450220487fb382c4974de3f7d834c1b617fe15860828c7f96454490edd6d891556dcc9022100baf95feb48f845d5bfc9882eb6aeefa1bc3790e39f59eaa46ff7f15ae626c53e0148304502205286f726690b2e9b0207f0345711e63fa7012045b9eb0f19c2458ce1db90cf43022100e89f17f86abc5b149eba4115d4f128bcf45d77fb3ecdd34f594091340c0395960175"⟩
    0x01 200000)
    (hx "c1628a1e7c67f14ca0c27c06e4fdeec2e6d1a73c7a91d7c046ff83e835aebb72") = true := by
  native_decide

/-! ## C — non-standard base hashtype 0x41 (B9-NEW-1, python-derived) -/

/-- `0x41 & 0x1f = 1` (ALL base), `0x41 & 0x80 = 0` (no ACP): the sub-hashes
are byte-identical to the E1 ALL case, while field 10 carries the RAW
`0x41000000`. Kills implementations that classify by exact match on
0x01/0x02/0x03 (fail-closed on valid consensus hashtypes) or that frame the
hashtype as 1 byte. Cross-checked with scratch/B09/bip143_ref.py. -/
example : bytesBEq (signatureHashBip143
    { version := 1
      vin :=
        [ ⟨⟨hx "fff7f7881a8099afa6940d42d1e7f6362bec38171ea3edf433541db4e4ad969f", 0⟩, Script.empty, 0xffffffee⟩
          , ⟨⟨hx "ef51e1b804cc89d182d279655c3aa89e815b1b309fe287d9b2b55d57b90ec68a", 1⟩, Script.empty, 0xFFFFFFFF⟩ ]
      vout :=
        [ ⟨112340000, ⟨hx "76a9148280b37df378db99f66f85c95a783a76ac7a6d5988ac"⟩⟩
          , ⟨223450000, ⟨hx "76a9143bde42dbee7e4dbe6a21b2d50ce2f0167faa815988ac"⟩⟩ ]
      locktime := 0x11
      witness := [] } 1
    ⟨hx "76a9141d0f172a0ecb48aee1be1f2687d2963ae33f71a188ac"⟩ 0x41 600000000)
    (hx "467f411d178762db122a6aced76370a1c8324355bf0796502bf82eeaeda86a35") = true := by
  native_decide

/-! ## D — SINGLE|ANYONECANPAY does not commit to the input index -/

/-- BIP's swapped-pairs transaction: the §Native-P2WSH-2 example with the two
input/output PAIRS exchanged. Under `SINGLE|ACP` the signatures remain valid
at their NEW indices (python cross-check B9-NEW-2). -/
def txE4swap : Tx :=
  { version := 1
    vin :=
      [ ⟨⟨hx "80e68831516392fcd100d186b3c2c7b95c80b53c77e77c35ba03a66b429a2a1b", 0⟩, Script.empty, 0xFFFFFFFF⟩
        , ⟨⟨hx "e9b542c5176808107ff1df906f46bb1f2583b16112b95ee5380665ba7fcfc001", 0⟩, Script.empty, 0xFFFFFFFF⟩ ]
    vout :=
      [ ⟨10000000, ⟨hx "76a9146648a8cd4531e1ec47f35916de8e259237294d1e88ac"⟩⟩
        , ⟨10000000, ⟨hx "76a914de4b231626ef508c9a74a8517e6783c0546d6b2888ac"⟩⟩ ]
    locktime := 0
    witness := [] }

-- former input 1 (scriptCode E4b) now at index 0, digest unchanged:
example : bytesBEq (signatureHashBip143 txE4swap 0
    ⟨hx "68210392972e2eb617b2388771abe27235fd5ac44af8e61693261550447a4c3e39da98ac"⟩ 0x83 16777215)
    (hx "cd72f1f1a433ee9df816857fad88d8ebd97e09a75cd481583eb841c330275e54") = true := by
  native_decide

-- former input 0 (scriptCode E4a) now at index 1, digest unchanged:
example : bytesBEq (signatureHashBip143 txE4swap 1
    ⟨hx "0063ab68210392972e2eb617b2388771abe27235fd5ac44af8e61693261550447a4c3e39da98ac"⟩ 0x83 16777215)
    (hx "e9071e75e25b8a1e298a72f0d2e9f4f95a0f5cdf86a533cda597eb402ed13b3a") = true := by
  native_decide

/-! ## E — sorry-free theorem: ACP digests do not read the OTHER inputs -/

/-- helper: `hashOutputsL` never reads `vin` — only `vout` (any hashtype). -/
private theorem hashOutputsL_of_vout (tx tx' : Tx) (nIn : Nat) (ht : UInt32)
    (hvout : tx.vout = tx'.vout) :
    hashOutputsL tx nIn ht = hashOutputsL tx' nIn ht := by
  unfold hashOutputsL
  rw [hvout]

/-- BIP143 semantics clause 5 (the `SINGLE`/`ANYONECANPAY` paragraph): when
`ANYONECANPAY` is set, the preimage commits to the signed input's own
outpoint/sequence only — the other inputs' prevouts and sequences are
irrelevant (they enter no sub-hash: `hashPrevouts` and `hashSequence` are
the zero vector, and `hashOutputs` reads only `vout`). This is the formal
statement behind the BIP's swapped-pairs example. -/
theorem bip143_acp_vin_indep (tx tx' : Tx) (nIn : Nat) (sc : Bytes) (ht : UInt32)
    (amount : Amount)
    (hacp : htAcp ht = true)
    (hvin : tx.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩
          = tx'.vin.getD nIn ⟨OutPoint.null, Script.empty, 0⟩)
    (hvout : tx.vout = tx'.vout)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime) :
    bip143MsgL tx nIn sc ht amount = bip143MsgL tx' nIn sc ht amount := by
  -- Under ACP both input-side sub-hashes are the zero vector regardless of
  -- the tx's OTHER inputs (BIP143 hashPrevouts/hashSequence rules).
  have hp : ∀ t : Tx, hashPrevoutsL t ht = zeroHashL := by
    intro t; unfold hashPrevoutsL; rw [if_pos hacp]
  have hsq : ∀ t : Tx, hashSequenceL t ht = zeroHashL := by
    intro t; unfold hashSequenceL
    rw [if_pos (show htAcp ht = true ∨ htBase ht = HtBase.singleHt ∨
      htBase ht = HtBase.noneHt from Or.inl hacp)]
  have ho : hashOutputsL tx nIn ht = hashOutputsL tx' nIn ht :=
    hashOutputsL_of_vout tx tx' nIn ht hvout
  unfold bip143MsgL
  rw [hp tx, hp tx', hsq tx, hsq tx', ho, hvin, hver, hlt]

/-- info: 'BitcoinProofs.Bip.B09.bip143_acp_vin_indep' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (info) in #print axioms bip143_acp_vin_indep

end BitcoinProofs.Bip.B09
