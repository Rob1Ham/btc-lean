import Bitcoin.Interpreter.Rules

/-! # PDW47.lean — proof-promotion review RC27, items TOP-231..235
(PDW47, 2026-10-17). Claim b6982a6.

Status-debt band of `Bitcoin/Interpreter/Rules.lean` (X07 §9/§10):

* **SCR-161** — a Schnorr signature size ∉ {64,65} is rejected before
  verification (`SCHNORR_SIG_SIZE`, interpreter.cpp:1736).
* **SCR-162** — a 65-byte signature whose explicit trailing byte is
  `SIGHASH_DEFAULT` (0x00) is a hashtype error (:1741-1744).
* **SCR-165** — `SIGHASH_DEFAULT` is the implicit hashtype of a 64-byte
  signature only; a valid digest + verify accepts (:1524, :1740).
* **SCR-166** — fail-closed: if the BIP341 sighash cannot be built
  (canonically SINGLE with `in_pos ≥ vout.size()`), verdict = false
  (:1559-1560, :1745-1747).
* **SCR-167** — every executed `OP_CODESEPARATOR` records `op.next`
  (the byte offset just past the opcode) in `codeSep` (:444-445, :1065).

Route B (PDW27-SCR-103 / PDW16 / PDW32): zero core writes; row faces are
the in-tree sorry-free theorem statements verbatim (no weakening), with
the `@[rule]` tag re-stated here on my own vehicle. -/

namespace BitcoinProofs.AF.PDW47

open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)
open Bitcoin.Crypto.Seam.Entry (schnorrVerdict schnorrHashtype SIGHASH_DEFAULT)

/-- SCR-161: size ∉ {64,65} ⇒ reject (including the empty signature,
which tapscript resolves earlier as an empty-pubkey/empty-sig case). -/
@[rule "SCR-161"]
theorem schnorrVerdict_size_gate
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (h : sig.size ≠ 64 ∧ sig.size ≠ 65) :
    schnorrVerdict verify sighashSchnorr sig pk v d = false :=
  Bitcoin.Interpreter.schnorrVerdict_size_gate verify sighashSchnorr sig pk v d h

/-- SCR-162: 65-byte sig with explicit trailing 0x00 ⇒ reject. -/
@[rule "SCR-162"]
theorem schnorrVerdict_65_default_rejected
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) (h65 : sig.size = 65)
    (h0 : sig[64]! = SIGHASH_DEFAULT) :
    schnorrVerdict verify sighashSchnorr sig pk v d = false :=
  Bitcoin.Interpreter.schnorrVerdict_65_default_rejected
    verify sighashSchnorr sig pk v d hv hp h65 h0

/-- SCR-165: 64-byte sig ⇒ implicit hashtype 0; some digest + verify ⇒ accept. -/
@[rule "SCR-165"]
theorem schnorrVerdict_default_64
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) (h64 : sig.size = 64)
    (digest : ByteArray)
    (hd : sighashSchnorr d SIGHASH_DEFAULT v = some digest)
    (hok : verify sig pk digest = true) :
    schnorrVerdict verify sighashSchnorr sig pk v d = true :=
  Bitcoin.Interpreter.schnorrVerdict_default_64
    verify sighashSchnorr sig pk v d hv hp h64 digest hd hok

/-- SCR-166: unbuildable sighash (explicit non-default hashtype) ⇒ reject. -/
@[rule "SCR-166"]
theorem schnorrVerdict_sighash_fail_closed
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) (h65 : sig.size = 65)
    (ht : UInt8) (hht : sig[64]! = ht) (hne : ht ≠ SIGHASH_DEFAULT)
    (hnone : sighashSchnorr d ht v = none) :
    schnorrVerdict verify sighashSchnorr sig pk v d = false :=
  Bitcoin.Interpreter.schnorrVerdict_sighash_fail_closed
    verify sighashSchnorr sig pk v d hv hp h65 ht hht hne hnone

/-- SCR-167: an executed CODESEPARATOR records the offset just past it. -/
@[rule "SCR-167"]
theorem stepBody_codesep_records_next
    (ctx : Bitcoin.Interpreter.Ctx) (op : Bitcoin.Interpreter.WireOp)
    (st : Bitcoin.Interpreter.State)
    (hop : op.ast = Bitcoin.Script.Parser.Opcode.op ⟨0xab, by decide⟩)
    (hw : op.wire = 0xab)
    (hts : ctx.sv = SigVersion.tapscript)
    (hexec : st.vf.all id = true) :
    Bitcoin.Interpreter.stepBody ctx op st = .ok { st with codeSep := op.next } :=
  Bitcoin.Interpreter.stepBody_codesep_records_next ctx op st hop hw hts hexec

/-! ## SCR-161 / SCR-166 / SCR-165 — faithful `CheckSchnorrSignature`

The existing `schnorrVerdict` is a `Bool` verdict: it loses *which*
`SCRIPT_ERR_*` Core raises. `CheckSchnorrSignature`
(interpreter.cpp:1727-1752) has three observable failures:

* `sig.size() != 64 && != 65` → `SCRIPT_ERR_SCHNORR_SIG_SIZE` (:1736);
* 65-byte sig with explicit `SIGHASH_DEFAULT` → `SCRIPT_ERR_SCHNORR_SIG_HASHTYPE`
  (:1741-1744); `SignatureHashSchnorr` returning false (canonically the
  BIP341 `SIGHASH_SINGLE` `in_pos >= vout.size()` gate at :1559-1560)
  → the same hashtype error (:1745-1748);
* BIP340 verification failure → `SCRIPT_ERR_SCHNORR_SIG` (:1749-1750).

`schnorrCheckCore` below models exactly that error table. Core `assert`s
`sigversion ∈ {TAPROOT, TAPSCRIPT}` and `pubkey.size() == 32`; those
become `sigHashtype` / `sig` fail-closed here (a consensus function
cannot assert), and the row theorems take them as hypotheses. -/

/-- The three `SCRIPT_ERR_*` outcomes of `CheckSchnorrSignature`. -/
inductive SchnorrCheckError where
  | sigSize      -- SCRIPT_ERR_SCHNORR_SIG_SIZE
  | sigHashtype  -- SCRIPT_ERR_SCHNORR_SIG_HASHTYPE
  | sig          -- SCRIPT_ERR_SCHNORR_SIG
deriving Repr, DecidableEq, BEq

/-- BIP341 `SignatureHashSchnorr`'s only *structural* failure
(interpreter.cpp:1559-1560): `SIGHASH_SINGLE` with no matching output.
`digest` supplies every other path (the full BIP341 serialization is
outside this file). `ht &&& 3` is Core's `output_type`. -/
def sighashSchnorrCore (digest : UInt8 → Option ByteArray)
    (inPos voutSize : Nat) (ht : UInt8) : Option ByteArray :=
  if ht &&& 3 = 3 ∧ voutSize ≤ inPos then none else digest ht

/-- SCR-166: `SIGHASH_SINGLE` with `in_pos ≥ vout.size()` makes the
construction return `false` (`:1559-1560`), modelled as `none`. -/
@[rule "SCR-166"]
theorem sighashSchnorrCore_single_overflow
    (digest : UInt8 → Option ByteArray) (inPos voutSize : Nat) (ht : UInt8)
    (hsingle : ht &&& 3 = 3) (hover : voutSize ≤ inPos) :
    sighashSchnorrCore digest inPos voutSize ht = none := by
  unfold sighashSchnorrCore
  rw [if_pos ⟨hsingle, hover⟩]

/-- `CheckSchnorrSignature` (interpreter.cpp:1727-1752) as an error-
carrying total function. The first two gates are Core `assert`s lifted to
fail-closed rejects; the remaining order is verbatim. -/
def schnorrCheckCore
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData) :
    Except SchnorrCheckError Bool :=
  if ¬(v = SigVersion.taproot ∨ v = SigVersion.tapscript) then .error .sigHashtype
  else if pk.size ≠ 32 then .error .sig
  else if sig.size ≠ 64 ∧ sig.size ≠ 65 then .error .sigSize
  else
    let body := if sig.size = 65 then sig.extract 0 64 else sig
    let ht := if sig.size = 65 then sig[64]! else SIGHASH_DEFAULT
    if sig.size = 65 ∧ ht = SIGHASH_DEFAULT then .error .sigHashtype
    else match sighashSchnorr d ht v with
      | none => .error .sigHashtype
      | some h => if verify body pk h then .ok true else .error .sig

/-- SCR-161: `sig.size() != 64 && != 65` ⇒ `SCHNORR_SIG_SIZE`
(interpreter.cpp:1736). -/
@[rule "SCR-161"]
theorem schnorrCheckCore_size_gate
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32)
    (h : sig.size ≠ 64 ∧ sig.size ≠ 65) :
    schnorrCheckCore verify sighashSchnorr sig pk v d = .error .sigSize := by
  unfold schnorrCheckCore
  rw [if_neg (by simp [hv]), if_neg (by simp [hp]), if_pos h]

/-- SCR-161 companion: an empty signature in a non-tapscript context is
just a wrong-size signature (`EvalChecksigTapscript`'s empty-sig special
case is resolved before this entry, interpreter.cpp:377-380). -/
@[rule "SCR-161"]
theorem schnorrCheckCore_empty_size_gate
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) :
    schnorrCheckCore verify sighashSchnorr ByteArray.empty pk v d = .error .sigSize :=
  schnorrCheckCore_size_gate verify sighashSchnorr ByteArray.empty pk v d hv hp
    ⟨by simp, by simp⟩

/-- SCR-166: a 65-byte signature whose explicit hashtype is
`SIGHASH_DEFAULT` is a hashtype error (:1741-1744). -/
@[rule "SCR-166"]
theorem schnorrCheckCore_65_default
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) (h65 : sig.size = 65)
    (h0 : sig[64]! = SIGHASH_DEFAULT) :
    schnorrCheckCore verify sighashSchnorr sig pk v d = .error .sigHashtype := by
  unfold schnorrCheckCore
  rw [if_neg (by simp [hv]), if_neg (by simp [hp]), if_neg (by omega)]
  simp only [h65, if_true]
  rw [if_pos (show True ∧ sig[64]! = SIGHASH_DEFAULT from ⟨trivial, h0⟩)]

/-- SCR-166: an unbuildable sighash ⇒ `SCHNORR_SIG_HASHTYPE`
(:1745-1748). -/
@[rule "SCR-166"]
theorem schnorrCheckCore_sighash_none
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) (h65 : sig.size = 65)
    (ht : UInt8) (hht : sig[64]! = ht) (hne : ht ≠ SIGHASH_DEFAULT)
    (hnone : sighashSchnorr d ht v = none) :
    schnorrCheckCore verify sighashSchnorr sig pk v d = .error .sigHashtype := by
  unfold schnorrCheckCore
  rw [if_neg (by simp [hv]), if_neg (by simp [hp]), if_neg (by omega)]
  simp only [h65, if_true]
  have hne0 : ¬(True ∧ sig[64]! = SIGHASH_DEFAULT) := by
    rintro ⟨-, h⟩
    exact hne (by rw [← hht]; exact h)
  rw [if_neg hne0]
  simp [hht, hnone]

/-- SCR-166 on the concrete BIP341 construction model: a `SIGHASH_SINGLE`
spend with `in_pos ≥ vout.size()` is `SCHNORR_SIG_HASHTYPE`
(interpreter.cpp:1559-1560 → :1745-1748). -/
@[rule "SCR-166"]
theorem schnorrCheckCore_single_overflow
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (digest : UInt8 → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (inPos voutSize : Nat) (ht : UInt8)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) (h65 : sig.size = 65)
    (hht : sig[64]! = ht) (hne : ht ≠ SIGHASH_DEFAULT)
    (hsingle : ht &&& 3 = 3) (hover : voutSize ≤ inPos) :
    schnorrCheckCore verify
        (fun _ ht _ => sighashSchnorrCore digest inPos voutSize ht)
        sig pk v d = .error .sigHashtype :=
  schnorrCheckCore_sighash_none verify
    (fun _ ht _ => sighashSchnorrCore digest inPos voutSize ht)
    sig pk v d hv hp h65 ht hht hne
    (sighashSchnorrCore_single_overflow digest inPos voutSize ht hsingle hover)

/-- SCR-165: the 64-byte accept path — implicit `SIGHASH_DEFAULT`, the
digest is built from hashtype `0`, and BIP340 verify succeeds. -/
@[rule "SCR-165"]
theorem schnorrCheckCore_default_64
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) (h64 : sig.size = 64)
    (digest : ByteArray)
    (hd : sighashSchnorr d SIGHASH_DEFAULT v = some digest)
    (hok : verify sig pk digest = true) :
    schnorrCheckCore verify sighashSchnorr sig pk v d = .ok true := by
  unfold schnorrCheckCore
  rw [if_neg (by simp [hv]), if_neg (by simp [hp]), if_neg (by omega)]
  simp only [h64, if_false]
  simp [hd, hok]

/-- SCR-165: `SIGHASH_DEFAULT` is the implicit hashtype **iff** the
signature is exactly 64 bytes (`schnorrHashtype` returns `(sig, 0)`
only in that case; a 65-byte signature always carries an explicit byte). -/
@[rule "SCR-165"]
theorem schnorrHashtype_default_iff (sig : ByteArray) :
    schnorrHashtype sig = some (sig, SIGHASH_DEFAULT) ↔ sig.size = 64 := by
  constructor
  · intro h
    by_cases h64 : sig.size = 64
    · exact h64
    · unfold schnorrHashtype at h
      rw [if_neg h64] at h
      by_cases h65 : sig.size = 65
      · rw [if_pos h65] at h
        by_cases h0 : sig[64]! = SIGHASH_DEFAULT
        · rw [if_pos h0] at h; cases h
        · rw [if_neg h0] at h
          injection h with hp
          have h1 : sig.extract 0 64 = sig := congrArg Prod.fst hp
          have hsz : sig.size = 64 := by
            rw [← h1, ByteArray.size_extract]
            omega
          omega
      · rw [if_neg h65] at h
        cases h
  · intro h
    exact Bitcoin.Crypto.Seam.Entry.schnorrHashtype_64 sig h

/-! ## SCR-167 — the UInt32 instruction-index model

Core's `opcode_pos` is the **instruction index** in the `GetOp` walk,
initialized to `0` but stored into `m_codeseparator_pos` only on an
executed `OP_CODESEPARATOR` (`interpreter.cpp:450,1065`), while the field
itself is initialized to `0xFFFFFFFF` (`:445`). The interpreter state
`State.codeSep` is instead a **byte offset** initialized to `0`. The fold
below is the faithful Core model; the witness shows the two disagree on
the same script. -/

/-- `m_codeseparator_pos` init (interpreter.cpp:445:
`execdata.m_codeseparator_pos = 0xFFFFFFFFUL`). -/
def CODESEP_POS_INIT : UInt32 := 0xFFFFFFFF

/-- Fold `opcode_pos` over the `GetOp` walk: `idx` increments once per
instruction, and an executed `OP_CODESEPARATOR` records the *current*
index (`interpreter.cpp:1065`). -/
def codesepPosFoldAux : List Bitcoin.Interpreter.WireOp → UInt32 → UInt32 → UInt32
  | [], _, pos => pos
  | op :: rest, idx, pos =>
      codesepPosFoldAux rest (idx + 1)
        (if op.wire = 0xab then idx else pos)

/-- The Core `ScriptExecutionData.m_codeseparator_pos` after executing a
whole `GetOp` walk, starting from `0xFFFFFFFF`. -/
def codesepPosFold (ops : List Bitcoin.Interpreter.WireOp) : UInt32 :=
  codesepPosFoldAux ops 0 CODESEP_POS_INIT

/-- SCR-167 (init): no instruction means the `0xFFFFFFFF` sentinel. -/
@[rule "SCR-167"]
theorem codesepPosFold_nil : codesepPosFold [] = CODESEP_POS_INIT := rfl

/-- The Lean state slot starts at `0`, not `0xFFFFFFFF` — the init half
of the divergence. -/
@[rule "SCR-167"]
theorem codeSep_init_zero : (0 : Nat) ≠ CODESEP_POS_INIT.toNat := by decide

/-- A concrete 2-byte-push + CODESEPARATOR script: the push occupies wire
bytes 0-2 (`next = 3`), so the CODESEPARATOR is at byte offset 3 and ends
at `next = 4`; its **instruction index** is 1. -/
def pushTwoBytes : Bitcoin.Interpreter.WireOp :=
  { ast := .pushBytes (ByteArray.mk #[0xaa, 0xbb]), wire := 0x02, next := 3 }

def codesepAfterPush : Bitcoin.Interpreter.WireOp :=
  { ast := .op ⟨0xab, by decide⟩, wire := 0xab, next := 4 }

/-- SCR-167 (divergence witness): on the same walk Core stores index `1`
while the byte-offset model records `op.next = 4`; the init values differ
too (`0xFFFFFFFF` vs `0`). This is the precise model divergence the row
must state, not the false claim that the two agree. -/
@[rule "SCR-167"]
theorem codesep_index_vs_byteoffset_witness :
    codesepPosFold [pushTwoBytes, codesepAfterPush] = 1 ∧
    codesepAfterPush.next = 4 ∧
    codesepPosFold [pushTwoBytes, codesepAfterPush] ≠ (4 : UInt32) ∧
    CODESEP_POS_INIT.toNat ≠ 0 := by
  decide

/-- SCR-167: the byte-offset value the tree records for the witness
script is `op.next = 4` — the existing `stepBody_codesep_records_next`
face, restated on the concrete op. -/
@[rule "SCR-167"]
theorem codesep_byteoffset_witness
    (ctx : Bitcoin.Interpreter.Ctx) (st : Bitcoin.Interpreter.State)
    (hts : ctx.sv = SigVersion.tapscript)
    (hexec : st.vf.all id = true) :
    Bitcoin.Interpreter.stepBody ctx codesepAfterPush st =
      .ok { st with codeSep := 4 } := by
  have h := Bitcoin.Interpreter.stepBody_codesep_records_next ctx codesepAfterPush st
    rfl rfl hts hexec
  simpa [codesepAfterPush] using h

end BitcoinProofs.AF.PDW47
