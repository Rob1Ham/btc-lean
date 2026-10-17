import Bitcoin.Crypto.Taproot.Sighash
import Bitcoin.Activation.Taproot

/-! # PDW33b — TOP-281..285: BIP341 SigMsg / taproot BIP9 status-debt (route B)

Row-face theorems for `Bitcoin/Crypto/Taproot/Sighash.lean`, the residue
left after PDW35/PDW37: the SigMsg totality/field law (TPR-033), the
spend_type byte (TPR-039), the SIGHASH_SINGLE slice (TPR-042), and the
BIP342 extension-slice layout (TPR-044), plus the historical taproot BIP9
deployment parameters (TPR-075). TPR-043 was found proven at HEAD by
PDW41 before my flip, so it is yielded (no overwrite). Zero core writes;
the core laws are re-used verbatim on my own `@[rule]` tags. -/

namespace BitcoinProofs.AF.PDW33b

open Bitcoin.Crypto.Taproot
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)
open Bitcoin.Data (serU8 serU32)
open Bitcoin.Activation

/-- TPR-033: on the consensus path the SigMsg EXISTS — the `none` lanes are
exactly the documented gate/slice rejects (interpreter.cpp:1529-1576). -/
@[rule "TPR-033"]
theorem sigMsgTaproot_exists_row (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (d : ScriptExecutionData)
    (hgate : sigMsgGate env inPos ht SigVersion.taproot d = true)
    (hspent : inPos < env.spentOutputs.length)
    (hvout : htSingle ht = true → inPos < env.tx.vout.length) :
    ∃ m, sigMsgTaproot env inPos ht SigVersion.taproot d = some m :=
  sigMsgTaproot_isSome env inPos ht d hgate hspent hvout

/-- **TPR-033** (field layout / serialization order): on the consensus
path the SigMsg is exactly the interpreter.cpp:1529-1576 concatenation —
hashtype ‖ nVersion ‖ nLockTime ‖ [¬ACP: prevouts/amounts/scripts/
sequences] ‖ [ALL/DEFAULT: outputs] ‖ spend_type ‖ input-data slice ‖
[annex] ‖ single-output slice ‖ extension slice. The annex slot is
`d.annexHash` iff `d.annexPresent`, and every slice is the resolved
`acpSlice`/`singleSlice`/`extSlice` value (their concrete forms are
`acpSlice_notACP`/`acpSlice_acp`, `singleSlice_some`/`_notSingle`,
`extSlice_taproot`/`_tapscript_some_row`). -/
@[rule "TPR-033"]
theorem sigMsgTaproot_layout_row (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (sv : SigVersion) (d : ScriptExecutionData) (a s e : ByteArray)
    (hg : sigMsgGate env inPos ht sv d = true)
    (ha : acpSlice env inPos ht = some a)
    (hs : singleSlice env inPos ht d = some s)
    (he : extSlice sv d = some e) :
    sigMsgTaproot env inPos ht sv d = some
      (serU8 ht
        ++ serU32 env.tx.version.toUInt32
        ++ serU32 env.tx.locktime
        ++ (if ! htAcp ht then
              shaPrevouts env.tx ++ shaSpentAmounts env.spentOutputs
                ++ shaSpentScripts env.spentOutputs ++ shaSequences env.tx
            else ByteArray.empty)
        ++ (if htOutputAll ht then shaOutputs env.tx else ByteArray.empty)
        ++ serU8 (spendType ((extFlagOf sv).getD 0) d.annexPresent)
        ++ a
        ++ (if d.annexPresent then d.annexHash else ByteArray.empty)
        ++ s
        ++ e) :=
  sigMsgTaproot_body env inPos ht sv d a s e hg ha hs he

/-- TPR-039: `spend_type = ext_flag * 2 + annex_present` (:1545). -/
@[rule "TPR-039"]
theorem spendType_row (extFlag : Nat) (haveAnnex : Bool) :
    spendType extFlag haveAnnex =
      (extFlag * 2 + (if haveAnnex then 1 else 0)).toUInt8 :=
  spendType_def extFlag haveAnnex

/-- TPR-039: key-path, no annex ⇒ byte 0; with annex ⇒ low bit 1. -/
@[rule "TPR-039"]
theorem spendType_keypath_bytes :
    spendType 0 false = 0 ∧ spendType 0 true = 1 := ⟨rfl, rfl⟩

/-- TPR-042: SINGLE with the output present ⇒ `sha_single_output`
(cached hash when set), interpreter.cpp:1558-1566. -/
@[rule "TPR-042"]
theorem singleSlice_some_row (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (d : ScriptExecutionData) (hs : htSingle ht = true)
    (hout : inPos < env.tx.vout.length) :
    singleSlice env inPos ht d = some (d.outputHash.getD
      (shaSingleOutput (env.tx.vout.getD inPos dummyTxOut))) :=
  singleSlice_some env inPos ht d hs hout

/-- TPR-042, cache-soundness branch: when the output-hash cache carries
Core's invariant (`none`, or already the BIP341 hash), the SINGLE slice
is exactly `SHA256(serTxOut(vout[inPos]))` — the hash Core computes at
interpreter.cpp:1561-1566. -/
@[rule "TPR-042"]
theorem singleSlice_some_sound_row (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (d : ScriptExecutionData) (hs : htSingle ht = true)
    (hout : inPos < env.tx.vout.length)
    (hcache : Bitcoin.Crypto.Seam.outputHashSound d
      (env.tx.vout.getD inPos dummyTxOut)) :
    singleSlice env inPos ht d = some
      (Bitcoin.Crypto.Seam.sha256
        (Bitcoin.Data.serTxOut (env.tx.vout.getD inPos dummyTxOut))) := by
  rw [singleSlice_some_row env inPos ht d hs hout]
  have h := Bitcoin.Crypto.Seam.outputHashSound_getD d
    (env.tx.vout.getD inPos dummyTxOut) hcache
  simpa [shaSingleOutput, Bitcoin.Crypto.Seam.sha256] using congrArg some h

/-- TPR-042: SINGLE with no output at the input index ⇒ hashtype failure. -/
@[rule "TPR-042"]
theorem singleSlice_no_output_none_row (env : TapSighashEnv) (inPos : Nat)
    (ht : UInt8) (d : ScriptExecutionData) (hs : htSingle ht = true)
    (hv : env.tx.vout.length ≤ inPos) :
    singleSlice env inPos ht d = none :=
  singleSlice_no_output_none env inPos ht d hs hv

/-- TPR-042: non-SINGLE ⇒ empty slice. -/
@[rule "TPR-042"]
theorem singleSlice_notSingle_row (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (d : ScriptExecutionData) (hs : htSingle ht = false) :
    singleSlice env inPos ht d = some ByteArray.empty :=
  singleSlice_notSingle env inPos ht d hs

/-! TPR-042 residual (FIX-P-DROWS re-audit): the seam's `outputHash` is
an unconstrained `Option ByteArray`, so the unconditional equality
`singleSlice = SOME (SHA256(serTxOut(vout[inPos])))` is not provable for
an arbitrary `d`; a pre-populated cache may hold any bytes. Core only
ever writes the computed hash (interpreter.cpp:1561-1566), modelled here
by `Bitcoin.Crypto.Seam.outputHashSound` and
`singleSlice_some_sound_row`. No reachability theorem ties every
interpreter-produced `d` to that invariant, so arbitrary-cache
behaviour remains an explicit residual, not claimed. -/

/-- Key-path TAPROOT ⇒ empty extension slice (support for TPR-044). -/
theorem extSlice_taproot_row (d : ScriptExecutionData) :
    extSlice SigVersion.taproot d = some ByteArray.empty :=
  extSlice_taproot d

/-- TPR-044: TAPSCRIPT with both init flags ⇒
`tapleaf_hash ‖ key_version(0x00) ‖ codesep_pos(4 LE)` (:1568-1576). -/
@[rule "TPR-044"]
theorem extSlice_tapscript_some_row (d : ScriptExecutionData)
    (h1 : d.tapleafHashInit = true) (h2 : d.codesepPosInit = true) :
    extSlice SigVersion.tapscript d =
      some (d.tapleafHash ++ serU8 0 ++ serU32 d.codesepPos) := by
  simp [extSlice, h1, h2]

/-- TPR-044: the extension slice is `tapleaf_hash.size + 1 + 4` bytes. -/
@[rule "TPR-044"]
theorem extSlice_tapscript_size_row (d : ScriptExecutionData) :
    (d.tapleafHash ++ serU8 0 ++ serU32 d.codesepPos).size =
      d.tapleafHash.size + 5 := by
  rw [Bitcoin.Crypto.Schnorr.append_size, Bitcoin.Crypto.Schnorr.append_size,
    serU8_size, serU32_size]

/-- TPR-075: the historical mainnet taproot BIP9 deployment row — bit 2,
start 1619222400, timeout 1628640000, threshold 1815, period 2016,
min_activation_height 709632 (bip-0341 §Deployment). -/
@[rule "TPR-075"]
theorem taprootBip9Deployment_row :
    taprootBip9Deployment.bit = 2 ∧
    taprootBip9Deployment.start = 1619222400 ∧
    taprootBip9Deployment.timeout = 1628640000 ∧
    taprootBip9Deployment.minActivation = 709632 ∧
    taprootBip9Deployment.threshold = 1815 ∧
    taprootBip9Deployment.period = 2016 :=
  taprootBip9Deployment_values

/-! ## Axiom pins (charter trio; zero sorryAx) -/

/-- info: 'BitcoinProofs.AF.PDW33b.sigMsgTaproot_exists_row' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW33b.sigMsgTaproot_exists_row

/-- info: 'BitcoinProofs.AF.PDW33b.spendType_row' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW33b.spendType_row

/-- info: 'BitcoinProofs.AF.PDW33b.spendType_keypath_bytes' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW33b.spendType_keypath_bytes

/-- info: 'BitcoinProofs.AF.PDW33b.singleSlice_some_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW33b.singleSlice_some_row

/-- info: 'BitcoinProofs.AF.PDW33b.singleSlice_some_sound_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW33b.singleSlice_some_sound_row

/-- info: 'BitcoinProofs.AF.PDW33b.singleSlice_no_output_none_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW33b.singleSlice_no_output_none_row

/-- info: 'BitcoinProofs.AF.PDW33b.singleSlice_notSingle_row' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW33b.singleSlice_notSingle_row

/-- info: 'BitcoinProofs.AF.PDW33b.taprootBip9Deployment_row' does not depend on any axioms -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW33b.taprootBip9Deployment_row

/-- info: 'BitcoinProofs.AF.PDW33b.extSlice_tapscript_some_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW33b.extSlice_tapscript_some_row

/-- info: 'BitcoinProofs.AF.PDW33b.extSlice_tapscript_size_row' depends on axioms: [propext] -/
#guard_msgs in #print axioms BitcoinProofs.AF.PDW33b.extSlice_tapscript_size_row

end BitcoinProofs.AF.PDW33b
