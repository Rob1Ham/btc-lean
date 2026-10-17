import Bitcoin.Crypto.Seam.Interface
import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Capstone.RealChecker
import Bitcoin.Capstone.Block
import Bitcoin.TxValidation.Full

/-!
# Bitcoin.Proofs.Shortcuts.CENSUS2.FailClosedSeam — B01/B02 re-land (RC4)

CENSUS2 re-land of S05's phantom `Shortcuts/S05/FailClosedSeam.lean`
(F-C2-001: never landed, doc-ahead-of-artifact). SCS-B01/B02, the
fail-closed axis at every production none-wiring site:

* **B01 site 1** `RealChecker.lean:96-98` `realSchnorrEntry` — S03's
  crashed-lane A4 (`realSchnorrEntry_old_fail_closed`,
  EcdsaDeep/SchnorrEntry2.lean:204) re-proved INDEPENDENTLY (no import
  of the banked file): the frozen production entry is constantly
  `false` — the BIP342 stand-in can never false-accept.
* **B01 site 2** `RealChecker.lean:106` `realCheckerFullOf` (S05's
  F-S05-002 anchor-gap site) — same const-false via the
  `txCheckerOf_schnorr` bridge.
* **B01 site 3** `TxValidation/Full.lean:83` `txCheckerFor` (X09-Full,
  S05's F-S05-002 second missed site) — same bridge.
* **B02** `Capstone/Block.lean:242` `verifyInput` — a Taproot program
  input routes to `unjudgedTaproot` BEFORE the checker is ever
  consulted (:244); the quarantine is never `pass`
  (`InputVerdict`-DecidableEq); non-Taproot inputs inherit
  `verifyScriptFull`'s verdict (`.unjudged` → the same quarantine).

Nothing reduces `verifyImpl`'s EC math (W14 discipline), the SHA256
layer, or any tagged rule row. No `@[rule]` (nothing is a rules.yaml
row). New file, CENSUS2-owned, outside the `BitcoinProofs` root closure
(A18 pattern).
-/

namespace Bitcoin.Proofs.Shortcuts.CENSUS2.FailClosedSeam

open Bitcoin.Crypto.Seam Bitcoin.Crypto.Seam.Entry
  Bitcoin.Capstone.Pow Bitcoin.Capstone.Merkle Bitcoin.Capstone.RealChecker
  Bitcoin.Data Bitcoin.Ledger Bitcoin.Consensus Bitcoin.TxValidation.Full
  Bitcoin.Activation Bitcoin.Interpreter Bitcoin.Serialization
  Bitcoin.Numeric Bitcoin.Capstone.Block

/-! ## B01 — the BIP342 `none` stand-in fails closed at EVERY production site -/

/-- **B01 site 1** (S03-A4 re-proved independently, no EcdsaDeep
import): the frozen production Schnorr entry — real BIP340 verifier
behind W13's gates, BIP342 sighash still the `fun _ _ _ => none`
stand-in (`RealChecker.lean:96-98`) — is constantly `false`. The
shortcut false-REJECTS everything; it can never false-accept. -/

theorem c2s_realSchnorrEntry_fail_closed (sig pk : ByteArray) (v : SigVersion)
    (d : ScriptExecutionData) :
    realSchnorrEntry.checkSchnorrSignature sig pk v d = false := by
  simp only [realSchnorrEntry, schnorrEntry, schnorrVerdict]
  by_cases hV : (v = SigVersion.taproot || v = SigVersion.tapscript) = true
  · rw [if_pos hV]
    by_cases hP : pk.size = 32
    · rw [if_pos hP]
      cases hs : schnorrHashtype sig with
      | none => rfl
      | some p =>
        cases p with
        | mk body ht => rfl
    · rw [if_neg hP]
  · rw [if_neg hV]

/-- **B01 site 2** (F-S05-002 anchor-gap site,
`RealChecker.lean:106`): `realCheckerFullOf` — the full checker with
BOTH real entries — carries the same none stand-in in its `txCheckerOf`
base; the Schnorr arm is the same const-false. -/

theorem c2s_realCheckerFullOf_schnorr_fail_closed (tx : Tx) (nIn : Nat)
    (amount : Amount) (sig pk : ByteArray) (v : SigVersion)
    (d : ScriptExecutionData) :
    (realCheckerFullOf tx nIn amount).base.checkSchnorrSignature
      sig pk v d = false := by
  show (txCheckerOf Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
      (sighashDispatch tx nIn amount) true
      Bitcoin.Crypto.Schnorr.Verify.verifyImpl (fun _ _ _ => none)).checkSchnorrSignature
      sig pk v d = false
  rw [txCheckerOf_schnorr Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
      (sighashDispatch tx nIn amount) true
      Bitcoin.Crypto.Schnorr.Verify.verifyImpl (fun _ _ _ => none)]
  exact c2s_realSchnorrEntry_fail_closed sig pk v d

/-- **B01 site 3** (F-S05-002 second missed site,
`TxValidation/Full.lean:83`, X09's Full-lane checker): `txCheckerFor`
— the X09 pipeline's checker, real BIP340 verifier + the same none
stand-in — Schnorr arm const-false. **Together with sites 1+2: the A4
family covers ALL THREE live none-wiring points.** -/

theorem c2s_txCheckerFor_schnorr_fail_closed (tx : Tx) (nIn : Nat)
    (amount : Option Amount) (sig pk : ByteArray) (v : SigVersion)
    (d : ScriptExecutionData) :
    (txCheckerFor tx nIn amount).base.checkSchnorrSignature
      sig pk v d = false := by
  show (txCheckerOf Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
      (sighashDispatch tx nIn (amount.getD 0)) amount.isSome
      Bitcoin.Crypto.Schnorr.Verify.verifyImpl (fun _ _ _ => none)).checkSchnorrSignature
      sig pk v d = false
  rw [txCheckerOf_schnorr Bitcoin.Crypto.Ecdsa.Verify.verifyImpl
      (sighashDispatch tx nIn (amount.getD 0)) amount.isSome
      Bitcoin.Crypto.Schnorr.Verify.verifyImpl (fun _ _ _ => none)]
  exact c2s_realSchnorrEntry_fail_closed sig pk v d

/-! ## B02 — the Taproot unjudged quarantine (`Capstone/Block.lean:242`) -/

/-- **B02** (SCS-B02): a Taproot program input (witness version ≥ 1)
routes to `InputVerdict.unjudgedTaproot` at `Block.lean:244`'s gate —
BEFORE the (const-false) checker is ever consulted. Neither accept nor
reject: the unjudged lane. -/

theorem c2s_taproot_routes_unjudged (height : UInt32) (tx : Tx) (i : Nat)
    (coin : Coin) (txIdx inputIdx : Nat)
    (h : isTaprootProgram coin.scriptPubKey.bytes = true) :
    verifyInput height tx i coin txIdx inputIdx
      = InputVerdict.unjudgedTaproot := by
  unfold verifyInput
  rw [if_pos h]

/-- Non-Taproot inputs (`Block.lean:244`'s else arm): the verdict is
exactly `verifyScriptFull`'s under the real checker (W09 flags = W06
`getBlockScriptFlags` at the block height) — in particular the
interpreter's `.unjudged` verdict (P15-slot) is inherited as the SAME
quarantine `unjudgedTaproot`, and `.ok`/`.fail` are the only ways to
`pass`/`fail`. (Block's private `dummyTxIn` inlined as its literal.) -/

theorem c2s_nontap_verdict_shape (height : UInt32) (tx : Tx) (i : Nat)
    (coin : Coin) (txIdx inputIdx : Nat)
    (h : isTaprootProgram coin.scriptPubKey.bytes = false) :
    verifyInput height tx i coin txIdx inputIdx =
      (let ss := (tx.vin.getD i ⟨OutPoint.null, Script.empty, 0xFFFFFFFF⟩).scriptSig.bytes
       let spk := coin.scriptPubKey.bytes
       let w := witnessAt tx i
       let wbytes := (w.map (·.size)).foldl Nat.add 0
       let fuel := ss.size + spk.size + wbytes + 10
       let flags := getBlockScriptFlags height
       let chk := realCheckerOf tx i coin.value
       match verifyScriptFull fuel flags default ss spk w chk with
       | .ok => InputVerdict.pass
       | .unjudged => InputVerdict.unjudgedTaproot
       | .fail e => InputVerdict.fail (CapError.scriptFail txIdx inputIdx e)) := by
  unfold verifyInput
  split
  · next hhe => exact absurd h (by simp [hhe])
  · match h' : (let ss := (tx.vin.getD i ⟨OutPoint.null, Script.empty, 0xFFFFFFFF⟩).scriptSig.bytes;
        let spk := coin.scriptPubKey.bytes;
        let w := witnessAt tx i;
        let wbytes := (w.map (·.size)).foldl Nat.add 0;
        let fuel := ss.size + spk.size + wbytes + 10;
        let flags := getBlockScriptFlags height;
        let chk := realCheckerOf tx i coin.value;
        verifyScriptFull fuel flags default ss spk w chk)
      with
  | .ok => rfl
  | .unjudged => rfl
  | .fail e => rfl

/-- **B02 safety**: the blocked Taproot lane can never silently accept
— `unjudgedTaproot ≠ pass` (verdict-visible at the block tier,
`InputVerdict` DecidableEq). -/

theorem c2s_unjudged_never_pass :
    InputVerdict.unjudgedTaproot ≠ InputVerdict.pass := by decide

/-- **B02 safety (strong form)**: a Taproot program input is NEVER
`pass` at the block tier (gate ⇒ `unjudgedTaproot` ⇒ ≠ `pass`), and a
non-Taproot spend reaching the Schnorr entry is always `false` (B01
site 3) — the two ways the BIP342 shortcut can manifest, both pinned,
neither fail-open. -/

theorem c2s_taproot_never_pass (height : UInt32) (tx : Tx) (i : Nat)
    (coin : Coin) (txIdx inputIdx : Nat)
    (h : isTaprootProgram coin.scriptPubKey.bytes = true) :
    verifyInput height tx i coin txIdx inputIdx ≠ InputVerdict.pass := by
  rw [c2s_taproot_routes_unjudged height tx i coin txIdx inputIdx h]
  decide

/-! ## Axiom guard (S16-P9/G08 style, CENSUS2 anchors) -/

#print axioms c2s_realSchnorrEntry_fail_closed        -- S03-A4 shape; no sorryAx
#print axioms c2s_realCheckerFullOf_schnorr_fail_closed -- no sorryAx
#print axioms c2s_txCheckerFor_schnorr_fail_closed    -- no sorryAx
#print axioms c2s_taproot_routes_unjudged             -- no sorryAx
#print axioms c2s_nontap_verdict_shape                -- no sorryAx
#print axioms c2s_unjudged_never_pass                 -- no sorryAx
#print axioms c2s_taproot_never_pass                  -- no sorryAx

end Bitcoin.Proofs.Shortcuts.CENSUS2.FailClosedSeam
