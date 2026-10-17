import Bitcoin.Crypto.Taproot.TapTweak
import Bitcoin.Crypto.Seam.Interface
import Bitcoin.Data.Tx

/-!
# Bitcoin.Crypto.Taproot.Sighash — the BIP341 signature message (X03, Unit 2)

THE consensus-critical sighash lane (bip-0341.mediawiki §"Signature hashing
for key and script path spends"), ported EXACTLY from Core
`SignatureHashSchnorr` (interpreter.cpp:1493-1578 @cce32b168) — the function
the Schnorr checker calls at interpreter.cpp:1747.

## What is ported where

* The transaction-level sub-hashes (`shaPrevouts`/`shaSpentAmounts`/
  `shaSpentScripts`/`shaSequences`/`shaOutputs` + `shaSingleOutput`) —
  Core's `PrecomputedTransactionData` single-SHA256 matrix
  (interpreter.cpp:1447+1412, `GetPrevoutsSHA256` et al.; TPR-034..038).
  NOTE TPR-046: BIP341 sub-hashes and the message use **single** SHA256
  (no double-SHA256 as in BIP143) — `HashWriter::GetSHA256`.
* `shaAnnex` (TPR-006) — interpreter.cpp:1964:
  `execdata.m_annex_hash = (HashWriter{} << annex).GetSHA256()`, where the
  `<<` of a `valtype` writes the CompactSize length first, and the annex
  INCLUDES its mandatory 0x50 prefix byte.
* `sigMsgTaproot` — the SigMsg body, interpreter.cpp:1529-1576 verbatim
  (success-side byte order):
  hashtype (1) ‖ nVersion (4 LE) ‖ nLockTime (4 LE) ‖ [¬ACP: the four
  32-byte sub-hashes] ‖ [output_type = ALL: sha_outputs] ‖ spend_type (1)
  ‖ [ACP: outpoint ‖ full CTxOut ‖ nSequence | else input_index (4 LE)]
  ‖ [annex present: sha_annex] ‖ [SINGLE: sha_single_output]
  ‖ [TAPSCRIPT: tapleaf_hash ‖ key_version 0x00 ‖ codesep_pos (4 LE)].
  `output_type = (ht == 0 ? ALL : ht & 3)` — SIGHASH_DEFAULT 0x00 ≡ ALL
  in the OUTPUT branch (interpreter.cpp:1531); the input branch mask is
  `ht & 0x80` (SIGHASH_INPUT_MASK). The ¬ACP lane commits all four
  sub-hashes even for NONE/SINGLE (TPR-037, interpreter.cpp:1533-1537 —
  a deliberate BIP341 divergence from BIP143).
  The reject conditions (Core `return false` at :1532/:1560 and the
  `assert`s at :1495-1507/:1510/:1543/:1571/:1574) are hoisted into ONE
  gate conjunction (`sigMsgGate`) — every reject is `none`, and Core's
  rejects are unordered with respect to each other (all produce `false`),
  so this is verdict-equivalent (B5: reject *reasons* are not
  consensus-visible).
* `sighashTaproot` — TPR-032: `taggedHash("TapSighash", 0x00 ‖ SigMsg)` —
  the 0x00 epoch byte (interpreter.cpp:1533, "sighash epoch"), single
  SHA256 over the doubled tag (Core `HASHER_TAPSIGHASH`,
  interpreter.cpp:1466 = `TaggedHash("TapSighash")`).

`none` = Core's `return false` (hashtype error TPR-030 / SIGHASH_SINGLE
without a corresponding output TPR-042) or the fail-closed rendering of a
caller-contract violation (Core `assert`s, interpreter.cpp:1510/1543/1571/
1574, `HandleMissingData` FAIL). Verdict channel is `Option`, per the
frozen `sighashSchnorr` seam shape (`Seam/Entry.schnorrVerdict` maps
`none → false`).

Caller contract (NOT re-checked here, exactly Core's asserts):
`in_pos < tx.vin.length`, `annexInit = true` whenever consulted
(interpreter.cpp:1543), and for TAPSCRIPT `tapleafHashInit`/`codesepPosInit`
(interpreter.cpp:1571/1574); the ACP lane additionally needs the spent-
outputs cache to cover the input (Core indexes `m_spent_outputs[in_pos]`).
The def degrades to `none` (fail-closed) when these are violated, which is
at least as strict as Core. The preset `annexHash`/`outputHash` slots
model Core's `m_annex_hash`/`m_output_hash` caches — both `uint256`, hence
always 32 bytes; size theorems touching them carry the matching
hypothesis.

## Rule rows (spec/db/rules.yaml TPR block)

TPR-030 (hashtype validity), TPR-032 (epoch + TapSighash tag),
TPR-033 (field order), TPR-034..038 (sub-hashes), TPR-039 (spend_type),
TPR-041 (input index), TPR-042 (SINGLE output existence), TPR-046
(single SHA256), TPR-006 (sha_annex). Wiring note: `realSchnorrEntry`
(`Capstone/RealChecker.lean`) still holds the fail-closed stand-in —
flipping it is X04's one-parameter seam change (X10's A4/A5/A6 pins the
current wiring); this module supplies the digest function.

## Status: X03 Unit 2 — all theorems sorry-free, axioms pinned at the
bottom (footprints ⊆ the standard trio, Unit-1 style). No `sorry`, no
`native_decide`. Conformance: `Test/Crypto/TaprootSighashTest.lean`
(7/7 official wallet-vector key-path sigMsg/sigHash cases + synthetic
annex/tapscript/SINGLE cases) + `Test/Crypto/taproot_sighash_crosscheck.py`
(independent hashlib mirror).
-/

namespace Bitcoin.Crypto.Taproot

open Bitcoin.Data
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)
open Bitcoin.Crypto.Schnorr (taggedHash tagTapSighash taggedHash_size append_size)
open Bitcoin.Crypto.Seam.Hash (sha256_size)
open Bitcoin.Crypto.Seam.Hash.Sha256 (sha256)

/-! ## Sub-hashes (Core `PrecomputedTransactionData`, TPR-034..038) -/

/-- Outpoint serialization inside the sighash = 32-byte txid AS-IS + 4 LE
(the same `serTxIn` prevout encoding; `uint256::Serialize` writes the
bytes in read order, Unit 1 ground truth). -/
def serOutPoint (o : OutPoint) : ByteArray := o.hash ++ serU32 o.n

/-- `sha_prevouts` = SHA256 of the serialization of all input outpoints
(interpreter.cpp `GetPrevoutsSHA256`; TPR-034). -/
@[rule "TPR-034"]
def shaPrevouts (tx : Tx) : ByteArray :=
  sha256 (tx.vin.foldl (fun acc i => acc ++ serOutPoint i.prevout) ByteArray.empty)

/-- `sha_amounts` = SHA256 of all spent input amounts, 8-byte LE each
(interpreter.cpp `GetSpentAmountsSHA256`; TPR-035 — commits to the fee). -/
@[rule "TPR-035"]
def shaSpentAmounts (outs : List TxOut) : ByteArray :=
  sha256 (outs.foldl (fun acc o =>
    acc ++ serU64 (UInt64.ofNat (amtToU64 o.value))) ByteArray.empty)

/-- A scriptPubKey "serialized as script inside CTxOut": CompactSize
length prefix + raw script bytes. -/
def serSpk (s : Script) : ByteArray := compactSizeEnc s.bytes.size ++ s.bytes

/-- `sha_scriptpubkeys` = SHA256 of all spent outputs' scriptPubKeys in
CTxOut-script form (interpreter.cpp `GetSpentScriptsSHA256`; TPR-036). -/
@[rule "TPR-036"]
def shaSpentScripts (outs : List TxOut) : ByteArray :=
  sha256 (outs.foldl (fun acc o => acc ++ serSpk o.scriptPubKey) ByteArray.empty)

/-- `sha_sequences` = SHA256 of all input nSequence, 4-byte LE each —
INCLUDED even for NONE/SINGLE when ¬ACP (interpreter.cpp
`GetSequencesSHA256`; TPR-037). -/
@[rule "TPR-037"]
def shaSequences (tx : Tx) : ByteArray :=
  sha256 (tx.vin.foldl (fun acc i => acc ++ serU32 i.sequence) ByteArray.empty)

/-- `sha_outputs` = SHA256 of all outputs in CTxOut format (interpreter.cpp
`GetOutputsSHA256`; TPR-038). -/
@[rule "TPR-038"]
def shaOutputs (tx : Tx) : ByteArray :=
  sha256 (tx.vout.foldl (fun acc o => acc ++ serTxOut o) ByteArray.empty)

/-- `sha_single_output` = SHA256 of the corresponding output in CTxOut
format (interpreter.cpp:1562-1564; TPR-042's success side). -/
def shaSingleOutput (o : TxOut) : ByteArray := sha256 (serTxOut o)

/-- `sha_annex` = SHA256(CSize(len) ‖ annex), annex INCLUDING the 0x50
prefix byte (interpreter.cpp:1964; TPR-006). -/
def shaAnnex (annex : ByteArray) : ByteArray :=
  sha256 (compactSizeEnc annex.size ++ annex)

/-! ## Hashtype classification (interpreter.cpp:1531-1532) -/

/-- The hashtype validity gate (interpreter.cpp:1532: `!(hash_type <= 0x03
|| (hash_type >= 0x81 && hash_type <= 0x83)) → return false`; TPR-030).
`SIGHASH_DEFAULT` (0x00) is valid. -/
@[rule "TPR-030"]
def hashtypeValid (ht : UInt8) : Bool :=
  ht.toNat ≤ 3 ∨ (0x81 ≤ ht.toNat ∧ ht.toNat ≤ 0x83)

/-- Input branch mask `ht & 0x80 == SIGHASH_ANYONECANPAY`
(interpreter.cpp:1531, `SIGHASH_INPUT_MASK`). -/
def htAcp (ht : UInt8) : Bool := (ht &&& 0x80) != 0

/-- Output branch: `output_type == SIGHASH_ALL` — DEFAULT (0x00) counts as
ALL (interpreter.cpp:1531, the `hash_type == SIGHASH_DEFAULT` ternary;
TPR-038's "only when output_type = ALL/DEFAULT"). -/
def htOutputAll (ht : UInt8) : Bool := ht.toNat == 0 ∨ (ht &&& 3).toNat == 1

/-- `hash_type & 3 == SIGHASH_NONE` (the sha_outputs exclusion). -/
def htNone (ht : UInt8) : Bool := (ht &&& 3).toNat == 2

/-- `hash_type & 3 == SIGHASH_SINGLE` (the sha_single_output branch;
TPR-042's gate). -/
def htSingle (ht : UInt8) : Bool := (ht &&& 3).toNat == 3

/-- The extension flag (interpreter.cpp:1496-1508): TAPROOT ⇒ 0, TAPSCRIPT
⇒ 1; other sigversions are Core `assert(false)` — fail-closed `none` here
(same policy as the seam's sigversion restriction). -/
def extFlagOf (sv : SigVersion) : Option Nat :=
  match sv with
  | .taproot => some 0
  | .tapscript => some 1
  | _ => none

/-- `spend_type = (ext_flag * 2) + annex_present` (interpreter.cpp:1545;
TPR-039) — the low bit indicates an annex. -/
@[rule "TPR-039"]
def spendType (extFlag : Nat) (haveAnnex : Bool) : UInt8 :=
  (extFlag * 2 + (if haveAnnex then 1 else 0)).toUInt8

/-! ## SigMsg (interpreter.cpp:1529-1576, TPR-033) -/

/-- Inhabited stand-in for out-of-range indexing (never reached: the def
gates on the real index first, mirroring Core's asserts). -/
def dummyTxOut : TxOut := ⟨0, Script.empty⟩

/-- Inhabited stand-in for out-of-range `vin` indexing (same policy). -/
def dummyTxIn : TxIn := ⟨OutPoint.null, Script.empty, 0xFFFFFFFF⟩

/-- The environment the sighash closure captures: the spending transaction
and the list of spent outputs (Core's `cache.m_spent_outputs`; the ACP
lane reads amount + scriptPubKey from it). -/
structure TapSighashEnv where
  tx : Tx
  spentOutputs : List TxOut

/-- The input/prevout slice (interpreter.cpp:1547-1552): ACP ⇒
`outpoint ‖ full CTxOut ‖ nSequence` (Core `ss << m_spent_outputs[in_pos]`
= the standard CTxOut serialization, amount 8-LE + CTxOut-script); else the
4-byte LE input index (TPR-041). `none` = spent-outputs cache does not
cover the input (Core indexes it directly — caller contract). -/
def acpSlice (env : TapSighashEnv) (inPos : Nat) (ht : UInt8) : Option ByteArray :=
  if htAcp ht then
    if inPos < env.spentOutputs.length then
      some (serOutPoint (env.tx.vin.getD inPos dummyTxIn).prevout
        ++ serTxOut (env.spentOutputs.getD inPos dummyTxOut)
        ++ serU32 (env.tx.vin.getD inPos dummyTxIn).sequence)
    else none
  else some (serU32 inPos.toUInt32)

/-- The single-output slice (interpreter.cpp:1558-1566): SIGHASH_SINGLE ⇒
`sha_single_output` (the cached `outputHash` when present, else computed —
Core :1561-1565), gated on the output EXISTING (`none` = TPR-042's
hashtype error, :1559-1560). Non-SINGLE ⇒ empty. -/
@[rule "TPR-042"]
def singleSlice (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (d : ScriptExecutionData) : Option ByteArray :=
  if htSingle ht then
    if inPos ≥ env.tx.vout.length then none
    else some (d.outputHash.getD
      (shaSingleOutput (env.tx.vout.getD inPos dummyTxOut)))
  else some ByteArray.empty

/-- The BIP342 extension slice (interpreter.cpp:1568-1576): TAPSCRIPT ⇒
`tapleaf_hash ‖ key_version(0x00) ‖ codesep_pos(4 LE)` (TPR-043/044), with
the two init flags enforced (Core asserts :1571/:1574 — fail-closed here);
TAPROOT ⇒ empty. `[SCR3, recovery review 2]` SCR-164 (interpreter.cpp:1570-1576
@cce32b168) A-aliases THIS def — the tapscript sighash ext fields; attribute
stacked by SCR3, def body X03's verbatim. Gap (X03's, not fixed here):
extSlice carries no `TPR-044` tag — X03 tagged the seam lane, not this def.
`[TAGFIX]` gap closed: `@[rule "TPR-043", rule "TPR-044"]` stacked below
(rules.yaml lean_target names extSlice for both rows). -/
@[rule "SCR-164", rule "TPR-043", rule "TPR-044"]
def extSlice (sv : SigVersion) (d : ScriptExecutionData) : Option ByteArray :=
  if sv = SigVersion.tapscript then
    if d.tapleafHashInit ∧ d.codesepPosInit then
      some (d.tapleafHash ++ serU8 0 ++ serU32 d.codesepPos)
    else none
  else some ByteArray.empty

/-- The BIP341 caller gate: the conjunction of Core's `return false`
verdicts and `assert`ed caller contracts (see module docstring). -/
def sigMsgGate (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (sv : SigVersion) (d : ScriptExecutionData) : Bool :=
  hashtypeValid ht
    && (extFlagOf sv).isSome
    && d.annexInit
    && (!(htAcp ht) || decide (inPos < env.tx.vin.length))

/-- The BIP341 signature message (before the epoch byte and the TapSighash
tagged-hash wrapper). Byte order is interpreter.cpp:1529-1576 EXACTLY;
`none` = the gate failed or a slice came up empty (docstrings above). -/
@[rule "TPR-033"]
def sigMsgTaproot (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (sv : SigVersion) (d : ScriptExecutionData) : Option ByteArray :=
  if sigMsgGate env inPos ht sv d then
    match acpSlice env inPos ht with
    | none => none
    | some a =>
    match singleSlice env inPos ht d with
    | none => none
    | some s =>
    match extSlice sv d with
    | none => none
    | some e =>
      some (serU8 ht                                              -- :1530
        ++ serU32 env.tx.version.toUInt32                         -- nVersion
        ++ serU32 env.tx.locktime                                 -- nLockTime
        ++ (if ! htAcp ht then                                    -- :1533-1537
              shaPrevouts env.tx ++ shaSpentAmounts env.spentOutputs
                ++ shaSpentScripts env.spentOutputs ++ shaSequences env.tx
            else ByteArray.empty)
        ++ (if htOutputAll ht then shaOutputs env.tx else ByteArray.empty)  -- :1538-1540
        ++ serU8 (spendType ((extFlagOf sv).getD 0) d.annexPresent)  -- :1545-1546
        ++ a                                                      -- :1547-1552
        ++ (if d.annexPresent then d.annexHash else ByteArray.empty)  -- :1554-1556
        ++ s                                                      -- :1558-1566
        ++ e)                                                     -- :1568-1576
  else none

/-- The BIP341 sighash: `hash_TapSighash(0x00 ‖ SigMsg(ht, ext_flag))`
(TPR-032; interpreter.cpp:1533 epoch byte + `ss.GetSHA256()` over
`HASHER_TAPSIGHASH` = `TaggedHash("TapSighash")`, interpreter.cpp:1466).
`[SCR3, recovery review 2]` SCR-169 (interpreter.cpp:1490-1580 @cce32b168)
A-aliases THIS def — the full `SigTaprootHash` (BIP341 §signature
hashing); attribute stacked by SCR3, def body X03's verbatim (e904215).
Honest gaps (other contributors' frozen lanes, NOT fixed here): the tapscript
`ed` is not yet threaded from the interpreter into the seam (audit
F-TS02-008 MOD, X04's one-parameter seam change); the frozen
`schnorrVerdict` seam still fail-closes on the none-sighash case
(SCR-166); `RealChecker.realSchnorrEntry` is the fail-closed stand-in
(X04's flip; S03's banked dead-contributor `SchnorrEntry2.realSchnorrEntry2`
carries the drop-in). -/
@[rule "SCR-169"]
def sighashTaproot (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (sv : SigVersion) (d : ScriptExecutionData) : Option ByteArray :=
  (sigMsgTaproot env inPos ht sv d).map
    (fun m => taggedHash tagTapSighash (serU8 0 ++ m))

/-! ## Size contracts -/

theorem serU8_size (x : UInt8) : (serU8 x).size = 1 := rfl

theorem serU32_size (x : UInt32) : (serU32 x).size = 4 := rfl

/-- `serOutPoint` telescopes to the txid length plus the 4-byte LE index. -/
theorem serOutPoint_size (o : OutPoint) : (serOutPoint o).size = o.hash.size + 4 := by
  unfold serOutPoint
  rw [append_size, serU32_size]

/-- The sub-hashes are 32-byte digests (single SHA256, TPR-046;
TPR-034..038's hash-domain size contracts). -/
theorem shaPrevouts_size (tx : Tx) : (shaPrevouts tx).size = 32 := sha256_size _
theorem shaSpentAmounts_size (outs : List TxOut) :
    (shaSpentAmounts outs).size = 32 := sha256_size _
theorem shaSpentScripts_size (outs : List TxOut) :
    (shaSpentScripts outs).size = 32 := sha256_size _
theorem shaSequences_size (tx : Tx) : (shaSequences tx).size = 32 := sha256_size _
theorem shaOutputs_size (tx : Tx) : (shaOutputs tx).size = 32 := sha256_size _
theorem shaSingleOutput_size (o : TxOut) : (shaSingleOutput o).size = 32 :=
  sha256_size _

/-- TPR-006: `sha_annex` is a 32-byte digest of `CSize(len) ‖ annex`. -/
theorem shaAnnex_size (annex : ByteArray) : (shaAnnex annex).size = 32 :=
  sha256_size _

/-- TPR-032 + TPR-046: the sighash digest is 32 bytes (epoch ‖ SigMsg
through the TapSighash tagged hash). -/
@[rule "TPR-046"]
theorem sighashTaproot_size (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (sv : SigVersion) (d : ScriptExecutionData) (m : ByteArray)
    (h : sighashTaproot env inPos ht sv d = some m) :
    m.size = 32 := by
  unfold sighashTaproot at h
  cases hm : sigMsgTaproot env inPos ht sv d with
  | none => rw [hm] at h; exact absurd h (by simp)
  | some msg =>
      rw [hm] at h
      simp at h
      exact h ▸ taggedHash_size _ _

/-- TPR-032 + TPR-046 (definitional statement): the sighash is the
TapSighash tagged hash of `0x00 ‖ SigMsg` — the epoch byte first, single
SHA256 over the doubled tag. -/
@[rule "TPR-032"]
theorem sighashTaproot_epoch (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (sv : SigVersion) (d : ScriptExecutionData) :
    sighashTaproot env inPos ht sv d
      = (sigMsgTaproot env inPos ht sv d).map
          (fun m => taggedHash tagTapSighash (serU8 0 ++ m)) := rfl

/-- **TPR-046** (single-SHA256 matrix): every BIP341 transaction-level
sub-hash is ONE application of SHA256 to its serialized preimage — the
`HashWriter::GetSHA256` lane (`hash.h:134-138`), not `SHA256d`. This is
stated for all six sub-hashes together; the `rfl` faces are the definitional
uses of the single-hash primitive in this module. -/
@[rule "TPR-046"]
theorem bip341_subhashes_single_sha256 (tx : Tx) (outs : List TxOut)
    (o : TxOut) (annex : ByteArray) :
    shaPrevouts tx = sha256
        (tx.vin.foldl (fun acc i => acc ++ serOutPoint i.prevout) ByteArray.empty) ∧
      shaSpentAmounts outs = sha256
        (outs.foldl (fun acc x =>
          acc ++ serU64 (UInt64.ofNat (amtToU64 x.value))) ByteArray.empty) ∧
      shaSpentScripts outs = sha256
        (outs.foldl (fun acc x => acc ++ serSpk x.scriptPubKey) ByteArray.empty) ∧
      shaSequences tx = sha256
        (tx.vin.foldl (fun acc i => acc ++ serU32 i.sequence) ByteArray.empty) ∧
      shaOutputs tx = sha256
        (tx.vout.foldl (fun acc x => acc ++ serTxOut x) ByteArray.empty) ∧
      shaSingleOutput o = sha256 (serTxOut o) ∧
      shaAnnex annex = sha256 (compactSizeEnc annex.size ++ annex) := by
  exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, rfl⟩

/-- **TPR-046** (message digest): every successful BIP341 sighash is a
SINGLE SHA256 over `SHA256(tag) ‖ SHA256(tag) ‖ 0x00 ‖ SigMsg` (the tagged
hash construction). In particular the message is not passed through a
second SHA256 (`SHA256d`): exactly one `sha256` call consumes it. -/
@[rule "TPR-046"]
theorem sighashTaproot_single_sha256 (env : TapSighashEnv) (inPos : Nat)
    (ht : UInt8) (sv : SigVersion) (d : ScriptExecutionData) (m : ByteArray)
    (h : sighashTaproot env inPos ht sv d = some m) :
    ∃ msg, sigMsgTaproot env inPos ht sv d = some msg ∧
      m = sha256 (sha256 tagTapSighash ++ sha256 tagTapSighash
        ++ (serU8 0 ++ msg)) := by
  unfold sighashTaproot at h
  cases hm : sigMsgTaproot env inPos ht sv d with
  | none => rw [hm] at h; exact absurd h (by simp)
  | some msg =>
      rw [hm] at h
      simp only [Option.map_some, Option.some.injEq] at h
      exact ⟨msg, rfl, by rw [← h]; simp [taggedHash]⟩

/-- TPR-039 (definitional statement): the spend_type byte is
`(ext_flag * 2) + annex_present` with the annex in the low bit. -/
theorem spendType_def (extFlag : Nat) (haveAnnex : Bool) :
    spendType extFlag haveAnnex = (extFlag * 2 + (if haveAnnex then 1 else 0)).toUInt8 := rfl

/-! ## Reject theorems (TPR-030, TPR-042) -/

/-- TPR-030 (reject side): an undefined hashtype is rejected before any
serialization (interpreter.cpp:1532). -/
theorem sigMsgTaproot_bad_hashtype_none (env : TapSighashEnv) (inPos : Nat)
    (ht : UInt8) (sv : SigVersion) (d : ScriptExecutionData)
    (h : hashtypeValid ht = false) :
    sigMsgTaproot env inPos ht sv d = none := by
  have hg : sigMsgGate env inPos ht sv d = false := by
    simp only [sigMsgGate, h, Bool.false_and]
  unfold sigMsgTaproot
  rw [if_neg (by rw [hg]; simp)]

/-- TPR-042 (reject side): SIGHASH_SINGLE with no output at the input's
index is a hashtype error — `none` (interpreter.cpp:1559-1560:
`if (in_pos >= tx_to.vout.size()) return false;`). -/
theorem singleSlice_no_output_none (env : TapSighashEnv) (inPos : Nat)
    (ht : UInt8) (d : ScriptExecutionData)
    (hs : htSingle ht = true) (hv : env.tx.vout.length ≤ inPos) :
    singleSlice env inPos ht d = none := by
  unfold singleSlice
  rw [if_pos hs, if_pos hv]

/-- TPR-042 (reject side, full message): the single-output existence gate
rejects the whole message. -/
theorem sigMsgTaproot_single_no_output_none (env : TapSighashEnv) (inPos : Nat)
    (ht : UInt8) (sv : SigVersion) (d : ScriptExecutionData)
    (hs : htSingle ht = true) (hv : env.tx.vout.length ≤ inPos) :
    sigMsgTaproot env inPos ht sv d = none := by
  unfold sigMsgTaproot
  split
  · rename_i hgate
    rw [singleSlice_no_output_none env inPos ht d hs hv]
    cases hacp : acpSlice env inPos ht with
    | none => rfl
    | some a => rfl
  · rfl

/-! ## Slice equations (definitional, TPR-041) -/

/-- ¬ACP: the input slice is the 4-byte LE input index (TPR-041). -/
@[rule "TPR-041"]
theorem acpSlice_notACP (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (hn : htAcp ht = false) :
    acpSlice env inPos ht = some (serU32 inPos.toUInt32) := by
  unfold acpSlice
  rw [if_neg (by simpa [htAcp] using hn)]

/-- ACP with the cache covering the input: the input slice is
`outpoint ‖ CTxOut ‖ nSequence` (interpreter.cpp:1547-1550). -/
@[rule "TPR-040"]
theorem acpSlice_acp (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (hA : htAcp ht = true) (hspent : inPos < env.spentOutputs.length) :
    acpSlice env inPos ht = some (serOutPoint (env.tx.vin.getD inPos dummyTxIn).prevout
      ++ serTxOut (env.spentOutputs.getD inPos dummyTxOut)
      ++ serU32 (env.tx.vin.getD inPos dummyTxIn).sequence) := by
  unfold acpSlice
  rw [if_pos hA, if_pos hspent]

/-- TAPROOT: the extension slice is empty (no BIP342 data). -/
theorem extSlice_taproot (d : ScriptExecutionData) :
    extSlice SigVersion.taproot d = some ByteArray.empty := by
  unfold extSlice
  rw [if_neg (by decide)]

/-- ¬SINGLE: the single-output slice is empty. -/
theorem singleSlice_notSingle (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (d : ScriptExecutionData) (hs : htSingle ht = false) :
    singleSlice env inPos ht d = some ByteArray.empty := by
  unfold singleSlice
  rw [if_neg (by simpa using hs)]

/-- SINGLE with the output present: the slice is `sha_single_output`
(Core's cached `m_output_hash` when set, else computed; :1561-1566). -/
theorem singleSlice_some (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (d : ScriptExecutionData) (hs : htSingle ht = true)
    (hout : inPos < env.tx.vout.length) :
    singleSlice env inPos ht d = some (d.outputHash.getD
      (shaSingleOutput (env.tx.vout.getD inPos dummyTxOut))) := by
  unfold singleSlice
  rw [if_pos hs, if_neg (by omega)]

/-! ## Totality on the consensus path -/

theorem isSome_some {α : Type} (o : Option α) (h : o.isSome = true) :
    ∃ a, o = some a := by
  cases o with
  | none => simp at h
  | some a => exact ⟨a, rfl⟩

/-- Totality on the consensus path (key path): with the gate satisfied and
the slices present, the message EXISTS — the `none` lanes are exactly the
ones enumerated in the def docstrings, no fourth reject mode. -/
theorem sigMsgTaproot_isSome (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
    (d : ScriptExecutionData)
    (hgate : sigMsgGate env inPos ht SigVersion.taproot d = true)
    (hspent : inPos < env.spentOutputs.length)
    (hvout : htSingle ht = true → inPos < env.tx.vout.length) :
    ∃ m, sigMsgTaproot env inPos ht SigVersion.taproot d = some m := by
  unfold sigMsgTaproot
  rw [if_pos hgate]
  have hacp : ∃ a, acpSlice env inPos ht = some a := by
    cases hA : htAcp ht with
    | false => exact ⟨_, acpSlice_notACP env inPos ht hA⟩
    | true => exact ⟨_, acpSlice_acp env inPos ht hA hspent⟩
  have hsingle : ∃ s, singleSlice env inPos ht d = some s := by
    cases hS : htSingle ht with
    | false => exact ⟨_, singleSlice_notSingle env inPos ht d hS⟩
    | true => exact ⟨_, singleSlice_some env inPos ht d hS (hvout hS)⟩
  obtain ⟨a, ha⟩ := hacp
  obtain ⟨s, hss⟩ := hsingle
  rw [ha, hss, extSlice_taproot]
  exact ⟨_, rfl⟩

/-! ## The key-path size formula (BIP341 length analysis) -/

set_option maxHeartbeats 4000000 in
/-- TPR-033 + the BIP341 length analysis ("174 - is_anyonecanpay * 49 -
is_none * 32 + has_annex * 32"), ¬ACP key-path lane: the message is
1 + 4 + 4 + 4×32 + [ALL: 32] + 1 + 4 + [annex: 32] + [SINGLE: 32] =
142 + 32·(output ALL) + 32·(annex present) + 32·(SINGLE). Requires the
vout index to exist when SINGLE (else `none`, size meaningless) and the
cached `annexHash`/`outputHash`, when used, to be 32-byte uint256s (Core's
type guarantee, interpreter.h:231/236). -/
theorem sigMsgTaproot_size_keypath (env : TapSighashEnv) (inPos : Nat)
    (ht : UInt8) (d : ScriptExecutionData)
    (hgate : sigMsgGate env inPos ht SigVersion.taproot d = true)
    (hn : htAcp ht = false)
    (hout : inPos < env.tx.vout.length)
    (hah : d.annexPresent = true → d.annexHash.size = 32)
    (hoh : ∀ b, d.outputHash = some b → b.size = 32) :
    ∃ m, sigMsgTaproot env inPos ht SigVersion.taproot d = some m ∧
      m.size = 142 + (if htOutputAll ht then 32 else 0)
        + (if d.annexPresent then 32 else 0)
        + (if htSingle ht then 32 else 0) := by
  unfold sigMsgTaproot
  rw [if_pos hgate, acpSlice_notACP env inPos ht hn, extSlice_taproot]
  -- resolve the ¬ACP conditional (the four sub-hashes)
  rw [if_pos (show (! htAcp ht) = true from by simp [hn])]
  have hempty : (ByteArray.empty : ByteArray).size = 0 := rfl
  cases hsing : htSingle ht with
  | false =>
      rw [singleSlice_notSingle env inPos ht d hsing]
      refine ⟨_, rfl, ?_⟩
      cases houtall : htOutputAll ht <;>
        cases hpres : d.annexPresent <;>
          simp only [Bool.false_eq_true, if_false, reduceIte, append_size,
            serU8_size, serU32_size, shaPrevouts_size, shaSpentAmounts_size,
            shaSpentScripts_size, shaSequences_size, shaOutputs_size, hempty] <;>
          (first | rw [show d.annexHash.size = 32 from hah hpres] | skip) <;>
          omega
  | true =>
      -- the single-output slice is the 32-byte single-output hash
      have hso : (d.outputHash.getD
          (shaSingleOutput (env.tx.vout.getD inPos dummyTxOut))).size = 32 := by
        cases hd : d.outputHash with
        | none => simp only [Option.getD]; exact shaSingleOutput_size _
        | some b => exact hoh b hd
      rw [singleSlice_some env inPos ht d hsing hout]
      refine ⟨_, rfl, ?_⟩
      cases houtall : htOutputAll ht <;>
        cases hpres : d.annexPresent <;>
          simp only [Bool.false_eq_true, if_false, reduceIte, append_size,
            serU8_size, serU32_size, shaPrevouts_size, shaSpentAmounts_size,
            shaSpentScripts_size, shaSequences_size, shaOutputs_size, hso,
            hempty] <;>
          (first | rw [show d.annexHash.size = 32 from hah hpres] | skip) <;>
          omega

/-! ## Exact SigMsg body (TPR-033) and the annex slot (TPR-006) -/

/-- **TPR-033 / TPR-006** (exact body): on the consensus path the SigMsg is
the interpreter.cpp:1529-1576 concatenation, in field order, where `a` is
the resolved input slice, `s` the resolved single-output slice and `e` the
resolved extension slice. The annex slot is present exactly when
`d.annexPresent` is set (and absent — empty — otherwise), which is the
sighash-entry half of TPR-006. The theorem is stated for an arbitrary
`sigversion`, so it covers both the key-path and tapscript lanes; TPR-033
only additionally needs the slice values (`acpSlice_notACP`/`acpSlice_acp`,
`singleSlice_some`/`singleSlice_notSingle`, `extSlice_*`). -/
@[rule "TPR-033", rule "TPR-006"]
theorem sigMsgTaproot_body (env : TapSighashEnv) (inPos : Nat) (ht : UInt8)
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
        ++ e) := by
  simp [sigMsgTaproot, hg, ha, hs, he]

/-! ## Determinism (W14b discipline) -/

/-- Determinism / totality: `sigMsgTaproot` is a pure function of
`(env, inPos, ht, sv, d)` — equal inputs, equal messages. Consensus
requirement (BIP341 §design): the sighash is completely specified at the
byte level. -/
theorem sigMsgTaproot_congr (env₁ env₂ : TapSighashEnv) (inPos₁ inPos₂ : Nat)
    (ht₁ ht₂ : UInt8) (sv₁ sv₂ : SigVersion) (d₁ d₂ : ScriptExecutionData)
    (he : env₁ = env₂) (hi : inPos₁ = inPos₂) (hh : ht₁ = ht₂)
    (hsv : sv₁ = sv₂) (hd : d₁ = d₂) :
    sigMsgTaproot env₁ inPos₁ ht₁ sv₁ d₁ = sigMsgTaproot env₂ inPos₂ ht₂ sv₂ d₂ := by
  subst he; subst hi; subst hh; subst hsv; subst hd; rfl

theorem sighashTaproot_congr (env₁ env₂ : TapSighashEnv) (inPos₁ inPos₂ : Nat)
    (ht₁ ht₂ : UInt8) (sv₁ sv₂ : SigVersion) (d₁ d₂ : ScriptExecutionData)
    (he : env₁ = env₂) (hi : inPos₁ = inPos₂) (hh : ht₁ = ht₂)
    (hsv : sv₁ = sv₂) (hd : d₁ = d₂) :
    sighashTaproot env₁ inPos₁ ht₁ sv₁ d₁ = sighashTaproot env₂ inPos₂ ht₂ sv₂ d₂ := by
  subst he; subst hi; subst hh; subst hsv; subst hd; rfl

/-! ## Axiom footprints (X02/Unit-1 style: `#guard_msgs in #print axioms`)

All sorry-free; footprints ⊆ the standard trio `[propext, Classical.choice,
Quot.sound]`. Pinned by the guard block below.
-/

/-- info: 'Bitcoin.Crypto.Taproot.serU8_size' does not depend on any axioms -/
#guard_msgs in #print axioms serU8_size

/-- info: 'Bitcoin.Crypto.Taproot.serU32_size' depends on axioms: [propext] -/
#guard_msgs in #print axioms serU32_size

/-- info: 'Bitcoin.Crypto.Taproot.serOutPoint_size' depends on axioms: [propext] -/
#guard_msgs in #print axioms serOutPoint_size

/-- info: 'Bitcoin.Crypto.Taproot.shaPrevouts_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms shaPrevouts_size

/-- info: 'Bitcoin.Crypto.Taproot.shaSpentAmounts_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms shaSpentAmounts_size

/-- info: 'Bitcoin.Crypto.Taproot.shaSpentScripts_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms shaSpentScripts_size

/-- info: 'Bitcoin.Crypto.Taproot.shaSequences_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms shaSequences_size

/-- info: 'Bitcoin.Crypto.Taproot.shaOutputs_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms shaOutputs_size

/-- info: 'Bitcoin.Crypto.Taproot.shaSingleOutput_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms shaSingleOutput_size

/-- info: 'Bitcoin.Crypto.Taproot.shaAnnex_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms shaAnnex_size

/-- info: 'Bitcoin.Crypto.Taproot.sighashTaproot_size' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms sighashTaproot_size

/-- info: 'Bitcoin.Crypto.Taproot.sighashTaproot_epoch' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms sighashTaproot_epoch

/-- info: 'Bitcoin.Crypto.Taproot.spendType_def' does not depend on any axioms -/
#guard_msgs in #print axioms spendType_def

/-- info: 'Bitcoin.Crypto.Taproot.sigMsgTaproot_bad_hashtype_none' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms sigMsgTaproot_bad_hashtype_none

/-- info: 'Bitcoin.Crypto.Taproot.singleSlice_no_output_none' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms singleSlice_no_output_none

/-- info: 'Bitcoin.Crypto.Taproot.sigMsgTaproot_single_no_output_none' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms sigMsgTaproot_single_no_output_none

/-- info: 'Bitcoin.Crypto.Taproot.acpSlice_notACP' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms acpSlice_notACP

/-- info: 'Bitcoin.Crypto.Taproot.acpSlice_acp' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms acpSlice_acp

/-- info: 'Bitcoin.Crypto.Taproot.extSlice_taproot' depends on axioms: [propext] -/
#guard_msgs in #print axioms extSlice_taproot

/-- info: 'Bitcoin.Crypto.Taproot.singleSlice_notSingle' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms singleSlice_notSingle

/-- info: 'Bitcoin.Crypto.Taproot.singleSlice_some' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms singleSlice_some

/-- info: 'Bitcoin.Crypto.Taproot.isSome_some' depends on axioms: [propext] -/
#guard_msgs in #print axioms isSome_some

/-- info: 'Bitcoin.Crypto.Taproot.sigMsgTaproot_isSome' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms sigMsgTaproot_isSome

/-- info: 'Bitcoin.Crypto.Taproot.sigMsgTaproot_size_keypath' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms sigMsgTaproot_size_keypath

/-- info: 'Bitcoin.Crypto.Taproot.sigMsgTaproot_congr' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms sigMsgTaproot_congr

/-- info: 'Bitcoin.Crypto.Taproot.sighashTaproot_congr' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms sighashTaproot_congr

end Bitcoin.Crypto.Taproot
