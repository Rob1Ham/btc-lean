import Bitcoin.SigHash.Interface
import Bitcoin.Serialization.Interface
import Bitcoin.Interpreter.Defs
import Bitcoin.Interpreter.Interface
import Bitcoin.Script.Tapscript.Delta
import Bitcoin.Capstone.Pow
import Bitcoin.Block.Params
import Bitcoin.Ledger.HashMap
import Bitcoin.Data.Basic
import Bitcoin.Activation.Flags
import Bitcoin.Activation.Bip9

/-!
# S02Flip — native_decide → decide flip measurement (D-004 census)

DEEP-LEAN S02, 2026-10-16. This file's home: proofs/BitcoinProofs/EcdsaDeep/.

METHOD (measurement only — these are verbatim structural copies of the
top-5 `Test/` native_decide use-sites + the two proofs-pkg archetypes,
with `by native_decide` replaced by `by decide`; fixtures are private in
their source files and copied verbatim, source:line tagged in every
section header). NO source file is edited. A section that checks here
= that use-site would flip to kernel `decide` as written; an error =
the wall (classified per F-S02-00x). Axiom footprint of
every flipped example: `decide`-clean = the standard kernel-checked
route (no `Lean.ofReduceBool`).

The sections, by actual-use rank (S02 census @ 2026-10-16 23:15):
  * SighashTest.lean 61 uses  → §A (sample sh-000)
  * HashMapTests.lean 30     → §B (samples 90/94/109/125)
  * Interpreter/Tests.lean 27 → §C (samples 91/92/95/100)
  * Headers.lean 27          → §D (samples 129/139/153/182)
  * Tapscript/Delta.lean 37  → §E (samples 60/103)
  * Y02/Corpus.lean 99 (proofs pkg) → §F (samples 160/161/162)
  * B11/NullDummyVectors.lean 13 (proofs pkg) → §G (samples V1 117 / V2 123)
-/

set_option maxRecDepth 100000
set_option maxHeartbeats 4000000

namespace S02Flip

/-! ## §A — Test/Sighash/SighashTest.lean (61 uses; sample sh-000 :70-73)
Fixtures :29-58 verbatim (hexDigitVal/fromHex/bL?? none/revHex/beHex).
`txOf` (:54) uses `panic!` — itself a decide-wall candidate, noted. -/

namespace A

open Bitcoin.SigHash Bitcoin.Serialization Bitcoin.Data

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

private def bytesOfList : List UInt8 → ByteArray | l => ByteArray.mk l.toArray

private def bL (ba : ByteArray) : List UInt8 := ba.toList

/-- sighash.json / uint256::GetHex() byte order (reversed internal). -/
private def revHex (s : String) : ByteArray := bytesOfList (bL (fromHex s)).reverse

-- Decode a vector's raw transaction (decoder). :54-58 verbatim.
-- (plain comment: a doc comment cannot attach to `deriving instance`)
deriving instance Inhabited for Tx

private def txOf (hex : String) : Tx :=
  match decodeTx (fromHex hex) with
  | .ok t => t
  | .error e => panic! s!"W11 harness: vector tx failed to decode: {repr e}"

private def scOf (hex : String) : Script := ⟨fromHex hex⟩

-- sh-000 (SighashTest.lean:70-73), FLIP-ATTEMPT A1:
example : bytesBEq (signatureHashLegacy (txOf "907c2bc503ade11cc3b04eb2918b6f547b0630ab569273824748c87ea14b0696526c66ba740200000004ab65ababfd1f9bdd\
  4ef073c7afc4ae00da8a66f429c917a0081ad1e1dabce28d373eab81d8628de802000000096aab5253ab52000052ad042b5f\
  25efb33beec9f3364e8a9139e8439d9d7e26529c3c30b6c3fd89f8684cfd68ea0200000009ab53526500636a52ab599ac2fe\
  02a526ed040000000008535300516352515164370e010000000003006300ab2ec229") 2 (scOf "") 0x6f1ce51f)
    (revHex "31af167a6cf3f9d5f6875caa4d31704ceb0eba078d132b78dab52c3b8997317e") = true := by decide

end A

/-! ## §B — Test/Ledger/HashMapTests.lean (30 uses; samples :90 :94 :109 :125)
Fixtures :40-85 verbatim (okOf/errOf/keyOf/scr/cb/s1/m0/m1/m2). -/

namespace B

open Bitcoin.Ledger Bitcoin.Data Bitcoin.TxValidation

private def okOf {α : Type _} (x : Except BlockError α) : Option α :=
  match x with | .ok v => some v | .error _ => none

private def errOf {α : Type _} (x : Except BlockError α) : Option BlockError :=
  match x with | .error e => some e | .ok _ => none

private def keyOf (tx : Tx) (k : UInt32) : OutPoint := ⟨serTx tx, k⟩

private def scr : Script := Script.empty

/-- A 50 BTC coinbase paying one output. -/
private def cb : Tx :=
  ⟨1, [⟨OutPoint.null, scr, 0xFFFFFFFF⟩], [⟨5000000000, scr⟩], 0, []⟩

/-- Spending tx: consumes cb's output 0, pays 40 BTC. -/
private def s1 : Tx :=
  ⟨1, [⟨keyOf cb 0, scr, 0xFFFFFFFF⟩], [⟨4000000000, scr⟩], 0, []⟩

/-- The empty map (genesis UTXO view). -/
private def m0 : UtxoMap := Std.HashMap.emptyWithCapacity 0

/-- The map after connecting `cb` at height 0. -/
private def m1 : UtxoMap :=
  match applyTxStepM m0 cb (txidPreimageKey cb) 0 with
  | .ok m => m
  | .error _ => m0

/-- After ALSO connecting `s1` at height 100 (matured). -/
private def m2 : UtxoMap :=
  match applyTxStepM m1 s1 (txidPreimageKey s1) 100 with
  | .ok m => m
  | .error _ => m0

-- HashMapTests.lean:88-90, FLIP-ATTEMPT B1 (coinbase insert; HashMap+mixHash):
example : okOf ((applyTxStepM m0 cb (txidPreimageKey cb) 0).map
    (fun m => (m.get? (keyOf cb 0)).map (·.value))) =
  some (some (5000000000 : Int)) := by decide

-- :92-94, FLIP-ATTEMPT B2 (isCoinbase bit):
example : okOf ((applyTxStepM m0 cb (txidPreimageKey cb) 0).map
    (fun m => (m.get? (keyOf cb 0)).map (·.isCoinbase))) =
  some (some true) := by decide

-- :107-109, FLIP-ATTEMPT B3 (maturity error through the map):
example :
    errOf ((applyTxStepM m0 cb (txidPreimageKey cb) 0).bind
      (fun m => applyTxStepM m s1 (txidPreimageKey s1) 0)) =
    some (BlockError.txError TxError.badTxnsPrematureSpendOfCoinbase) := by decide

-- :125, FLIP-ATTEMPT B4 (double-spend removal):
example : (m2.get? (keyOf cb 0)).isSome = false := by decide

end B

/-! ## §C — Test/Script/Interpreter/Tests.lean (27 uses; samples :91 :92 :95 :100)
Fixtures :40-89 hexDigitVal/hex/reps verbatim. -/

namespace C

open Bitcoin.Interpreter Bitcoin.Activation Bitcoin.Crypto.Seam Bitcoin.Data

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

private def hex (s : String) : ByteArray := fromHex s

-- Interpreter/Tests.lean:91-92, FLIP-ATTEMPT C1 (empty-msg SHA-256):
example : hashSha256 ("".toUTF8) =
    hex "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" := by decide

-- :93-94, FLIP-ATTEMPT C2 ("abc" SHA-256):
example : hashSha256 ("abc".toUTF8) =
    hex "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" := by decide

-- :96-97, FLIP-ATTEMPT C3 (empty-msg SHA-1):
example : hashSha1 ("".toUTF8) =
    hex "da39a3ee5e6b4b0d3255bfef95601890afd80709" := by decide

-- :99-100, FLIP-ATTEMPT C4 ("abc" RIPEMD-160):
example : hashRipemd160 ("abc".toUTF8) =
    hex "8eb208f7e05d987a9b044a8e98c6b087f15a0bfb" := by decide

end C

/-! ## §D — Test/Block/Headers.lean (27 uses; samples :129 :139 :153 :182)
Fixtures :56-92 hexDigitVal/fromHex/rev32/vecHeader/roundTrips/RAW0/HASH0
verbatim. -/

namespace D

open Bitcoin.Data Bitcoin.Chain Bitcoin.Capstone.Pow Bitcoin.Serialization

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
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

private def rev32 (b : ByteArray) : ByteArray :=
  (List.range b.size).foldl (fun acc i => acc.push (b.get! (b.size - 1 - i))) ByteArray.empty

private def vecHeader (raw : ByteArray) : BlockHeader :=
  match decodeBlockHeader raw with
  | .ok h => h
  | .error _ =>
      ({ version := 0, hashPrevBlock := ByteArray.empty, hashMerkleRoot := ByteArray.empty,
          time := 0, bits := 0, nonce := 0 } :
        Bitcoin.Chain.BlockHeader)

private def roundTrips (raw : ByteArray) : Bool :=
  bytesBEq (encodeBlockHeader (vecHeader raw)) raw

private def RAW0 : ByteArray := fromHex
  "0100000000000000000000000000000000000000000000000000000000000000000000003ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a29ab5f49ffff001d1dac2b7c"
private def HASH0 : ByteArray := fromHex
  "000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f"

-- Headers.lean:129, FLIP-ATTEMPT D1 (decode/encode stability, no hash):
example : roundTrips RAW0 = true := by decide

-- :138-139, FLIP-ATTEMPT D2 (BLK-003: SHA256d header hash):
example : bytesBEq (rev32 (headerHash (vecHeader RAW0))) HASH0 = true := by
  decide

-- :153, FLIP-ATTEMPT D3 (powOk: target gate + high-hash ≤ target):
example : powOk (vecHeader RAW0) = true := by decide

end D

/-! ## §E — core/Test/Script/Tapscript/Delta.lean (37 uses; samples :60 :103)
Fixtures :41-49 ckGood/pk1-adjacent verbatim (only what the samples use).
MinimalIF tapscript sample :103-105 (stack/script bytes verbatim). -/

namespace E

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Script.Parser Bitcoin.Activation
open Bitcoin.Crypto.Seam (SigVersion ScriptExecutionData stubChecker)

private def polIf : Bitcoin.Interpreter.PolicyFlags := { minimalIf := true }

private def ckGood : Bitcoin.Interpreter.ScriptChecker := ⟨stubChecker, default, none⟩

-- Delta.lean:60-61 (success_prepass), FLIP-ATTEMPT E1:
example : executeWitnessScript 100 [] 0 (ByteArray.mk #[(0x50:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.ok := by decide

-- :103-105 (minimalif_tap_fail), FLIP-ATTEMPT E2:
example : executeWitnessScript 100 [ByteArray.mk #[(0x02:UInt8),(0x01:UInt8),(0x00:UInt8)]] 0 (ByteArray.mk #[(0x63:UInt8),(0x68:UInt8)]) default default ckGood SigVersion.tapscript
  = VerifyOutcome.fail ExecError.tapscriptMinimalIf := by decide

-- :106-107 (minimalif_v0_nopolicy), FLIP-ATTEMPT E3:
example : executeWitnessScript 100 [ByteArray.mk #[(0x02:UInt8),(0x01:UInt8),(0x00:UInt8)]] 0 (ByteArray.mk #[(0x63:UInt8),(0x68:UInt8)]) default default ckGood SigVersion.witnessV0
  = VerifyOutcome.fail ExecError.cleanstack := by decide

end E

end S02Flip

/-! ## §F+§G — proofs-pkg archetypes (Y02/Corpus.lean :160-162;
B11/NullDummyVectors.lean :117-123). Same file (Bitcoin.* imports). -/

namespace S02FlipP

/-! ## §F — BitcoinProofs/Property/Y02/Corpus.lean (99 uses; :160 :161 :162)
Fixtures :44-88 + v_TX_LEG_0 :152-159 verbatim (non-private there).
NOTE: `theorem` (named!) in the source; measurement copies stay
`example` (no manifest pollution). -/

namespace F

open Bitcoin.Data Bitcoin.Serialization Bitcoin.Capstone.Merkle

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

private def errOfTx : Except SerError Tx → Option SerError
  | .ok _ => none
  | .error e => some e

private def reEncodeTx : Except SerError Tx → ByteArray
  | .ok t => encodeTx t
  | .error _ => ByteArray.empty

private def decTx : String → Except SerError Tx := fun s => decodeTx (fromHex s)

private def v_TX_LEG_0 : String := "0100000001000000000000000000000000000000000000000000000000000000\
   0000000000ffffffff4d04ffff001d0104455468652054696d65732030332f4a\
   616e2f32303039204368616e63656c6c6f72206f6e206272696e6b206f662073\
   65636f6e64206261696c6f757420666f722062616e6b73ffffffff0100f2052a\
   01000000434104678afdb0fe5548271967f1a67130b7105cd6a828e03909a679\
   62e0ea1f61deb649f6bc3f4cef38c4f35504e51ec112de5c384df7ba0b8d578a\
   4c702b6bf11d5fac00000000"

-- Y02/Corpus.lean:160, FLIP-ATTEMPT F1 (decode-side, no hash):
example : errOfTx (decTx v_TX_LEG_0) = none := by decide

-- :161, FLIP-ATTEMPT F2 (roundtrip; Eq ByteArray):
example : reEncodeTx (decTx v_TX_LEG_0) = fromHex v_TX_LEG_0 := by decide

-- :162, FLIP-ATTEMPT F3 (txid = sha256d):
example : (match decTx v_TX_LEG_0 with | .ok t => txidOf t | .error _ => ByteArray.empty)
    = fromHex "3ba3edfd7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a" := by decide

end F

/-! ## §G — BitcoinProofs/Bip/B11/NullDummyVectors.lean (13; V1 :117 V2 :123)
Fixtures :71-101 sn1/pk33/sig72/sigE/dummy01/dummyE/stackFor/mkCtx/mkSt/
errIs/okIs verbatim (vchTrue = Bitcoin.Interpreter.Defs:273). -/

namespace G

open Bitcoin.Interpreter Bitcoin.Activation
open Bitcoin.Crypto.Seam (SigVersion stubChecker)

private def sn1 : ByteArray := ByteArray.mk #[(0x01 : UInt8)]
private def pk33 : ByteArray := ByteArray.mk (Array.replicate 33 (0x02 : UInt8))
private def sig72 : ByteArray := ByteArray.mk (Array.replicate 72 (0x30 : UInt8))
private def dummy01 : ByteArray := ByteArray.mk #[(0x51 : UInt8)]
private def dummyE : ByteArray := ByteArray.empty

private def stackFor (sig dummy : ByteArray) : List ByteArray :=
  [sn1, pk33, sn1, sig, dummy]

private def mkCtx (nd : Bool) (sv : SigVersion) : Bitcoin.Interpreter.Ctx :=
  { flags := { nullDummy := nd }, pol := default,
    chk := ⟨stubChecker, default, none⟩, sv := sv, bytes := .empty, ed := default }

private def mkSt (stack : List ByteArray) : Bitcoin.Interpreter.State :=
  { stack := stack, alt := [], vf := [], opCount := 0, codeSep := 0, vwLeft := none }

private def errIs (r : Except ExecError Bitcoin.Interpreter.State) (e : ExecError) : Bool :=
  match r with | .error e' => e' == e | .ok _ => false

private def okIs (r : Except ExecError Bitcoin.Interpreter.State) (s : Bitcoin.Interpreter.State) : Bool :=
  match r with | .ok s' => s' == s | .error _ => false

-- B11:116-117 (V1 nullDummy gate), FLIP-ATTEMPT G1:
example : errIs (stepBody.checkMultiSig (mkCtx true .base) 0xae (mkSt (stackFor sig72 dummy01)))
    .sigNullDummy = true := by decide

-- :118-124 (V2 empty dummy ok), FLIP-ATTEMPT G2:
example : okIs (stepBody.checkMultiSig (mkCtx true .base) 0xae (mkSt (stackFor sig72 dummyE)))
    { stack := [vchTrue], alt := [], vf := [], opCount := 1, codeSep := 0, vwLeft := none } := by
  decide

end G

end S02FlipP
