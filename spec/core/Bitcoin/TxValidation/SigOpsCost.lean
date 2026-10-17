import Bitcoin.TxValidation.Interface
import Bitcoin.Interpreter.Defs
import Bitcoin.Interpreter.SigOps

/-!
# Bitcoin.TxValidation.SigOpsCost — TXV-B: the per-input P2SH/witness sigop counters

`GetP2SHSigOpCount` (tx_verify.cpp:132-147) and `GetWitnessSigOpCount`
/ `CountWitnessSigOps` (tx_verify.cpp:160-167; interpreter.cpp:2160-2182
@`cce32b168`) — the two per-input cost components of
`GetTransactionSigOpCost` (tx_verify.cpp:149-168) beyond the legacy
term (TXV-049). This module is the recovery-review-2 (TXV-B) closure of
rows **TXV-050** (P2SH sigop count) and **TXV-051** (witness sigop
count); the accounting aggregation (×4 scaling, the 80,000 block cap)
is X05's `Bitcoin.Interpreter.SigOps` (TXV-052 / INV-038 / INV-039 /
SWT-021..028), which this file deliberately does not duplicate.

## Design decisions (against the two open audit findings F-TS02-003/007)

The tree currently has **two** models of the sigop counters and both
carry an open TS02 (interpreter audit) finding:

* X07's `Bitcoin.Interpreter.Rules.sigOpCount` (SCR-033) diverges from
  Core `GetSigOpCount(fAccurate)` (**F-TS02-003, HIGH**: non-accurate
  CMS +1 vs +20; last-of-list vs per-CMS lookback). TS02's verdict:
  X05's `Bitcoin.Interpreter.SigOps.accurateSigOpCount` (per-CMS
  preceding-opcode lookback, script.cpp:159-181) "**is** the
  Core-faithful model". Every count in THIS file therefore goes through
  X05's `accurateSigOpCount` / `witnessSigOps` — never X07's
  `sigOpCount`.
* X05's `Bitcoin.Interpreter.SigOps.p2shWitnessSigOps` (SWT-027) is
  missing the `IsPushOnly` gate of Core `CountWitnessSigOps`
  interpreter.cpp:2162 (**F-TS02-007, MODERATE**: a parseable but
  non-push-only scriptSig ending in a witness-program push counts its
  witness sigops in Lean where Core returns 0). `countWitnessSigOps`
  below is the F-TS02-007-repaired shape (Core :2160-2182 verbatim,
  TS02-007's quote): the gate is `isPushOnlyWire` (X05's own SCR-052
  model of `CScript::IsPushOnly`, script.cpp:266-282: bare opcodes
  ≤ OP_16 incl. OP_RESERVED count as push, parse failure → false ⇒ 0).

X07's `p2shSigOpCount` (SCR-034) re-parses `pushBytesWire d` (the push
*wrapper* `len ++ d`, a one-push script) where the redeemScript is the
pushed **data** `d` itself (Core `CScript(vchRet)`, and X05's own
SWT-027 shape `isWitnessProgram d`; B2/SCR-034: "accurate count of the
redeemScript"). `p2shScriptSigSigOps` below parses `d` — reported to
the owner lane as a tree discrepancy (see findings-rc/TXV-B.md
F-TXVB-001); the X07 def itself is outside this lane's rows.

## Faithfulness notes (dead states, caller-side gates)

* `p2shScriptSigSigOps` = `CScript::GetSigOpCount(scriptSig)`
  (script.cpp:183-205): parse-fail ⇒ 0 (Core `:188
  if (!scriptSig.GetOp(…)) return 0;`, TS02-007); non-push tail ⇒ the
  `GetOp` walk's data register cleared ⇒ empty subscript ⇒ 0; the
  subscript (last push data) counted with `GetSigOpCount(true)` =
  `accurateSigOpCount`; a subscript that itself fails to parse ⇒ 0
  (Core's partial loop = dead state, TS02-007: unparseable ⇒ script
  validation fails ⇒ block invalid).
* `spkTbl : OutPoint → Option ByteArray` resolves the prevout's
  scriptPubKey (Core: `inputs.AccessCoin(prevout).out.scriptPubKey`).
  `none` = the null Coin (Core's `AccessCoin` on a missing entry) =
  empty scriptPubKey = not P2SH / not a witness program ⇒ 0; in the
  validation pipeline `HaveCoins`/`CheckTxInputs` (TXV-020/021) run
  before the sigop gate, so `none` is a dead state (TS02-007's
  convention).
* `p2shSigOpsTx` (TXV-050) = `GetP2SHSigOpCount`
  (tx_verify.cpp:132-147): **coinbase ⇒ 0** (B3/07-row text), per input
  only P2SH prevouts contribute; the caller-side `SCRIPT_VERIFY_P2SH`
  gate (GetTransactionSigOpCost:156) is X05's `sigOpCost` lane.
* `witnessSigOpsTx` (TXV-051) = `GetWitnessSigOpCount`
  (tx_verify.cpp:160-167): the per-input loop over
  `CountWitnessSigOps(scriptSig, prevout.scriptPubKey, scriptWitness,
  flags)`. The `SCRIPT_VERIFY_WITNESS` gate (Core :2160) and the
  `assert(SCRIPT_VERIFY_P2SH)` (:2161) are caller-side invariants
  (GetTransactionSigOpCost's flag word; the block path's flag word is
  `GetBlockScriptFlags` = TXV-055) — the *counting arms* are what this
  row owns. No coinbase check in the loop (the B3 row is silent here,
  unlike TXV-050's explicit `coinbase = 0`; GetTransactionSigOpCost
  early-returns legacy-only on coinbase, so a coinbase never reaches
  the witness term in the cost path).

Everything is `Nat`/`List`/`ByteArray` arithmetic — sorry-free by
construction (no `sorry`, no `native_decide`).
-/

namespace Bitcoin.TxValidation.SigOpsCost

open Bitcoin.Data Bitcoin.Interpreter Bitcoin.Script.Parser
open Bitcoin.Interpreter.SigOps (accurateSigOpCount witnessSigOps)

/-! ## script.cpp:183-205 — `GetSigOpCount(scriptSig)`, the P2SH arm -/

/-- `CScript::GetSigOpCount(const CScript& scriptSig)`
(script.cpp:183-205): the P2SH-arm counter — the subscript is the
scriptSig's LAST push (the redeemScript), counted with
`GetSigOpCount(true)` = `accurateSigOpCount`. `GetOp` parse failure ⇒ 0
(Core :188); non-push tail ⇒ the data register cleared ⇒ empty
subscript ⇒ 0; unparseable subscript ⇒ 0 (dead state). Called only with
`scriptPubKey.IsPayToScriptHash()` (tx_verify.cpp:132-147's caller
gate, p2shSigOpsTx below).-/
def p2shScriptSigSigOps (scriptSig : ByteArray) : Nat :=
  match parseWire scriptSig with
  | none => 0
  | some ops =>
    match ops.getLast? with
    | none => 0
    | some last =>
      match last.ast with
      | .pushBytes d =>
        match parseWire d with
        | none => 0
        | some rops => accurateSigOpCount rops
      | _ => 0

/-! ## tx_verify.cpp:132-147 — `GetP2SHSigOpCount` (TXV-050) -/

/-- **TXV-050**: `GetP2SHSigOpCount` (tx_verify.cpp:132-147): coinbase
⇒ 0; otherwise the sum over inputs of `GetSigOpCount(scriptSig)`
(BIP16's accurate count of the redeemScript = the scriptSig's last
push) **for P2SH prevouts only**. `spkTbl` resolves the prevout's
scriptPubKey (Core `AccessCoin(prevout).out`; `none` = null Coin ⇒ no
P2SH gate ⇒ 0).-/
@[rule "TXV-050"]
def p2shSigOpsTx (tx : Tx) (spkTbl : OutPoint → Option ByteArray) : Nat :=
  if tx.isCoinBase then 0
  else
    tx.vin.foldl (fun acc i =>
      match spkTbl i.prevout with
      | some spk => if isPayToScriptHash spk then acc + p2shScriptSigSigOps i.scriptSig.bytes else acc
      | none => acc) 0

/-! ## interpreter.cpp:2160-2182 — `CountWitnessSigOps` @cce32b168 -/

/-- `CountWitnessSigOps(scriptSig, scriptPubKey, witness, flags)`
(interpreter.cpp:2160-2182 @`cce32b168`, TS02-007's verbatim quote):
bare witness program in scriptPubKey ⇒ `WitnessSigOps`
(:2133-2147 = X05's `witnessSigOps`); P2SH-wrapped
(`scriptPubKey.IsPayToScriptHash() && scriptSig.IsPushOnly()` — the
**:2162 gate**, F-TS02-007's repair) ⇒ the scriptSig's last push (the
redeemScript) must itself be a witness program, else 0; anything else
⇒ 0. The `SCRIPT_VERIFY_WITNESS` gate (:2160) and the
`assert(SCRIPT_VERIFY_P2SH)` (:2161) are caller-side (the
`GetTransactionSigOpCost` flag word) — not the counting arms' business.
IsPushOnly parse failure ⇒ false ⇒ 0 (script.cpp:266-282; `isPushOnlyWire`
is `ops.all (·.wire ≤ 0x60)` over the PARSED stream, so `parseWire =
none` short-circuits to 0 here exactly as in Core).-/
def countWitnessSigOps (ss spk : ByteArray) (witness : WitnessStack) : Nat :=
  match isWitnessProgram spk with
  | some (v, prog) => witnessSigOps v prog witness
  | none =>
    if isPayToScriptHash spk then
      match parseWire ss with
      | none => 0
      | some ops =>
        if isPushOnlyWire ops then
          match ops.getLast? with
          | none => 0
          | some last =>
            match last.ast with
            | .pushBytes d =>
              match isWitnessProgram d with
              | some (v, prog) => witnessSigOps v prog witness
              | none => 0
            | _ => 0
        else 0
    else 0

/-! ## tx_verify.cpp:160-167 — `GetWitnessSigOpCount` (TXV-051) -/

/-- The per-input indexed loop of `GetWitnessSigOpCount`
(tx_verify.cpp:160-167): `n` threads the input index (the witness stack
resolve, X09's `tx.witness.getD n` idiom); each input's prevout
scriptPubKey comes from `spkTbl` (Core
`AccessCoin(prevout).out.scriptPubKey`).-/
def witnessSigOpsTxFrom (tx : Tx) (spkTbl : OutPoint → Option ByteArray) :
    List TxIn → Nat → Nat
  | [], _ => 0
  | i :: rest, n =>
    match spkTbl i.prevout with
    | some spk =>
      countWitnessSigOps i.scriptSig.bytes spk (tx.witness.getD n [])
        + witnessSigOpsTxFrom tx spkTbl rest (n + 1)
    | none => witnessSigOpsTxFrom tx spkTbl rest (n + 1)

/-- **TXV-051**: `GetWitnessSigOpCount` (tx_verify.cpp:160-167): the
per-input witness sigop count — each input contributes
`CountWitnessSigOps(scriptSig, prevout.scriptPubKey, scriptWitness)`
(TXV-051's "per-input witness program sigop cost"). No coinbase check
in the loop (B3/row text; `GetTransactionSigOpCost` early-returns
legacy-only on coinbase, so the witness term is coinbase-free in the
cost path).-/
@[rule "TXV-051"]
def witnessSigOpsTx (tx : Tx) (spkTbl : OutPoint → Option ByteArray) : Nat :=
  witnessSigOpsTxFrom tx spkTbl tx.vin 0

/-! ## Laws (all sorry-free; axiom pins at the file end) -/

/-! ### TXV-050 laws -/

/-- The `GetP2SHSigOpCount` input fold's running accumulator equals the
plain sum of the per-input contributions (seed 0). -/
private theorem p2shFold_eq_sum (l : List TxIn)
    (spkTbl : OutPoint → Option ByteArray) (init : Nat) :
    l.foldl (fun acc i =>
      match spkTbl i.prevout with
      | some spk =>
        if isPayToScriptHash spk then acc + p2shScriptSigSigOps i.scriptSig.bytes
        else acc
      | none => acc) init
    = init + (l.map (fun i =>
      match spkTbl i.prevout with
      | some spk =>
        if isPayToScriptHash spk then p2shScriptSigSigOps i.scriptSig.bytes else 0
      | none => 0)).sum := by
  induction l generalizing init with
  | nil => simp
  | cons i rest ih =>
    simp only [List.foldl_cons, List.map_cons, List.sum_cons]
    have hstep : (match spkTbl i.prevout with
        | some spk =>
          if isPayToScriptHash spk then init + p2shScriptSigSigOps i.scriptSig.bytes
          else init
        | none => init)
        = init + (match spkTbl i.prevout with
          | some spk =>
            if isPayToScriptHash spk then p2shScriptSigSigOps i.scriptSig.bytes else 0
          | none => 0) := by
      cases hv : spkTbl i.prevout with
      | none => simp
      | some spk =>
        by_cases hp : isPayToScriptHash spk = true
        · simp [hp]
        · simp [hp]
    rw [ih, hstep]
    omega

/-- **TXV-050** (tx_verify.cpp:GetP2SHSigOpCount:132-147): the full
`GetP2SHSigOpCount` fold — coinbase ⇒ 0; otherwise the sum over inputs of
`GetSigOpCount(scriptSig)` for P2SH prevouts, and 0 for non-P2SH or
unresolved prevouts.  This is the row's general statement, with the
scriptSig-as-subscript count `p2shScriptSigSigOps` in the P2SH summand. -/
@[rule "TXV-050"] theorem p2shSigOpsTx_eq_sum (tx : Tx)
    (spkTbl : OutPoint → Option ByteArray) :
    p2shSigOpsTx tx spkTbl =
      (if tx.isCoinBase then 0 else
        (tx.vin.map (fun i =>
          match spkTbl i.prevout with
          | some spk =>
            if isPayToScriptHash spk then p2shScriptSigSigOps i.scriptSig.bytes else 0
          | none => 0)).sum) := by
  unfold p2shSigOpsTx
  by_cases hcb : tx.isCoinBase = true
  · simp [hcb]
  · rw [if_neg hcb]
    show tx.vin.foldl (fun acc i =>
      match spkTbl i.prevout with
      | some spk =>
        if isPayToScriptHash spk then acc + p2shScriptSigSigOps i.scriptSig.bytes
        else acc
      | none => acc) 0 = (if tx.isCoinBase then 0 else _)
    rw [if_neg hcb, p2shFold_eq_sum]
    simp

/-- TXV-050 (tx_verify.cpp:132-147): a coinbase's P2SH sigop count is
exactly 0 — coinbase inputs are never script-looked-up (the row's
`coinbase = 0` half).-/
@[rule "TXV-050"]
theorem p2shSigOpsTx_coinbase_zero (tx : Tx) (spkTbl : OutPoint → Option ByteArray)
    (hcb : tx.isCoinBase = true) :
    p2shSigOpsTx tx spkTbl = 0 := by
  unfold p2shSigOpsTx
  rw [if_pos hcb]

/-- script.cpp:188: an unparseable scriptSig counts 0 (Core's
`GetOp`-failure early return).-/
theorem p2shScriptSigSigOps_parse_fail (ss : ByteArray)
    (h : parseWire ss = none) :
    p2shScriptSigSigOps ss = 0 := by
  simp only [p2shScriptSigSigOps, h]

/-- The non-push-tail law: a parseable scriptSig whose last op is not
a data push counts 0 (Core's `GetOp` walk clears the data register on
non-push opcodes ⇒ empty subscript).-/
theorem p2shScriptSigSigOps_nonpush_tail (ss : ByteArray) (ops : List WireOp)
    (hp : parseWire ss = some ops) (last : WireOp)
    (hl : ops.getLast? = some last) (hnp : (∀ d, last.ast ≠ .pushBytes d)) :
    p2shScriptSigSigOps ss = 0 := by
  simp only [p2shScriptSigSigOps, hp, hl]

/-- The redeem law (B2/SCR-034): for a P2SH prevout whose scriptSig's
last push carries the redeemScript `d` (itself parsing as `rops`), the
input's whole contribution is `GetSigOpCount(d, true)` =
`accurateSigOpCount rops` — the accurate count of the redeemScript
(BIP16).-/
theorem p2shScriptSigSigOps_push_redeem (ss : ByteArray) (ops : List WireOp)
    (hp : parseWire ss = some ops) (last : WireOp) (d : ByteArray)
    (hl : ops.getLast? = some last) (hast : last.ast = .pushBytes d)
    (hd : parseWire d = some rops) :
    p2shScriptSigSigOps ss = accurateSigOpCount rops := by
  simp only [p2shScriptSigSigOps, hp, hl, hast, hd]

/-- The dead-state law: an unparseable redeemScript counts 0 (Core's
partial `GetSigOpCount(true)` loop on the subscript = dead state,
TS02-007).-/
theorem p2shScriptSigSigOps_redeem_parse_fail (ss : ByteArray) (ops : List WireOp)
    (hp : parseWire ss = some ops) (last : WireOp) (d : ByteArray)
    (hl : ops.getLast? = some last) (hast : last.ast = .pushBytes d)
    (hd : parseWire d = none) :
    p2shScriptSigSigOps ss = 0 := by
  simp only [p2shScriptSigSigOps, hp, hl, hast, hd]

/-- The P2SH-gate law (tx_verify.cpp:132-147): for a non-coinbase
one-input tx whose prevout is NOT P2SH (or unresolved = null Coin),
`GetP2SHSigOpCount` = 0 — only P2SH prevouts contribute.-/
theorem p2shSigOpsTx_one_nonp2sh_zero (tx : Tx) (i : TxIn)
    (spkTbl : OutPoint → Option ByteArray) (spk : ByteArray)
    (hcb : { tx with vin := [i] }.isCoinBase = false)
    (ht : spkTbl i.prevout = some spk)
    (hp2sh : isPayToScriptHash spk = false) :
    p2shSigOpsTx { tx with vin := [i] } spkTbl = 0 := by
  unfold p2shSigOpsTx
  rw [if_neg (by simp [hcb] : ¬({ tx with vin := [i] } : Tx).isCoinBase = true)]
  simp only [List.foldl_cons, List.foldl_nil, ht, hp2sh]
  rfl

/-- The one-input law: a non-coinbase one-input tx with a P2SH prevout
contributes exactly `GetSigOpCount(scriptSig)` — the scriptSig-as-
subscript accurate count (the row's "for P2SH prevouts, count with
scriptSig as subscript").-/
theorem p2shSigOpsTx_one_p2sh (tx : Tx) (i : TxIn)
    (spkTbl : OutPoint → Option ByteArray) (spk : ByteArray)
    (hcb : { tx with vin := [i] }.isCoinBase = false)
    (ht : spkTbl i.prevout = some spk)
    (hp2sh : isPayToScriptHash spk = true) :
    p2shSigOpsTx { tx with vin := [i] } spkTbl
      = p2shScriptSigSigOps i.scriptSig.bytes := by
  unfold p2shSigOpsTx
  rw [if_neg (by simp [hcb] : ¬({ tx with vin := [i] } : Tx).isCoinBase = true)]
  simp only [List.foldl_cons, List.foldl_nil, ht]
  rw [if_pos (by simp [hp2sh] : isPayToScriptHash spk = true)]
  simp only [Nat.zero_add]

/-- The unresolved-prevout law: a non-coinbase one-input tx with an
unresolved prevout (the null Coin) counts 0.-/
theorem p2shSigOpsTx_one_missing_zero (tx : Tx) (i : TxIn)
    (spkTbl : OutPoint → Option ByteArray)
    (hcb : { tx with vin := [i] }.isCoinBase = false)
    (ht : spkTbl i.prevout = none) :
    p2shSigOpsTx { tx with vin := [i] } spkTbl = 0 := by
  unfold p2shSigOpsTx
  rw [if_neg (by simp [hcb] : ¬({ tx with vin := [i] } : Tx).isCoinBase = true)]
  simp only [List.foldl_cons, List.foldl_nil, ht]

/-! ### TXV-051 laws -/

/-- The bare-witness-program arm (interpreter.cpp:2163-2165): a prevout
scriptPubKey that IS a witness program contributes exactly
`WitnessSigOps(v, prog, witness)` (X05's :2133-2147 model) — the
per-input "witness program sigop cost" of the row.-/
theorem countWitnessSigOps_witnessprogram (ss spk : ByteArray)
    (witness : WitnessStack) (v : Nat) (prog : ByteArray)
    (hwp : isWitnessProgram spk = some (v, prog)) :
    countWitnessSigOps ss spk witness = witnessSigOps v prog witness := by
  simp only [countWitnessSigOps, hwp]

/-- The fall-through law: a prevout scriptPubKey that is neither a
witness program nor P2SH contributes 0 (Core :2160-2182's final
`return 0`).-/
theorem countWitnessSigOps_nonwp_nonp2sh_zero (ss spk : ByteArray)
    (witness : WitnessStack)
    (hwp : isWitnessProgram spk = none)
    (hp2sh : isPayToScriptHash spk = false) :
    countWitnessSigOps ss spk witness = 0 := by
  simp only [countWitnessSigOps, hwp]
  rw [if_neg (by simp [hp2sh])]

/-- **The IsPushOnly gate** (interpreter.cpp:2162; F-TS02-007's repair):
a P2SH prevout with a parseable but NON-push-only scriptSig counts 0 —
Core skips the whole P2SH branch; the tree's X05
`p2shWitnessSigOps` (SWT-027) counted the witness program here (the
open audit finding).-/
theorem countWitnessSigOps_pushonly_gate (ss spk : ByteArray)
    (witness : WitnessStack) (ops : List WireOp)
    (hwp : isWitnessProgram spk = none)
    (hp2sh : isPayToScriptHash spk = true)
    (hp : parseWire ss = some ops)
    (hpo : isPushOnlyWire ops = false) :
    countWitnessSigOps ss spk witness = 0 := by
  simp only [countWitnessSigOps, hwp]
  rw [if_pos hp2sh]
  simp only [hp]
  rw [if_neg (by simp [hpo])]

/-- The P2SH-witness arm (interpreter.cpp:2162-2173): a P2SH prevout
with a push-only scriptSig whose last push carries a witness program
`(v, prog)` contributes `WitnessSigOps(v, prog, witness)` — the
redeemScript-is-a-witness-program case (BIP141 P2SH-P2WPKH/P2WSH).-/
theorem countWitnessSigOps_p2sh_pushonly_lastpush (ss spk : ByteArray)
    (witness : WitnessStack) (ops : List WireOp) (last : WireOp)
    (d : ByteArray) (v : Nat) (prog : ByteArray)
    (hwp : isWitnessProgram spk = none)
    (hp2sh : isPayToScriptHash spk = true)
    (hp : parseWire ss = some ops)
    (hpo : isPushOnlyWire ops = true)
    (hl : ops.getLast? = some last)
    (hast : last.ast = .pushBytes d)
    (hd : isWitnessProgram d = some (v, prog)) :
    countWitnessSigOps ss spk witness = witnessSigOps v prog witness := by
  simp only [countWitnessSigOps, hwp]
  rw [if_pos hp2sh]
  simp only [hp, hpo, hl, hast, hd]
  rfl

/-- The dead-witness-arm law: P2SH prevout, push-only scriptSig, but
the scriptSig fails to parse ⇒ 0 (IsPushOnly parse failure ⇒ false,
script.cpp:266-282).-/
theorem countWitnessSigOps_parse_fail_zero (ss spk : ByteArray)
    (witness : WitnessStack)
    (hwp : isWitnessProgram spk = none)
    (hp : parseWire ss = none) :
    countWitnessSigOps ss spk witness = 0 := by
  simp only [countWitnessSigOps, hwp]
  split
  · next hp2sh => simp only [hp]
  · rfl

/-- The P2SH-witness non-program law: P2SH prevout, push-only
scriptSig, last push `d` — but `d` is not a witness program ⇒ 0 (Core:
`subscript.IsWitnessProgram(...)` fails ⇒ `return 0`).-/
theorem countWitnessSigOps_p2sh_redeem_nonwp_zero (ss spk : ByteArray)
    (witness : WitnessStack) (ops : List WireOp) (last : WireOp)
    (d : ByteArray)
    (hwp : isWitnessProgram spk = none)
    (hp2sh : isPayToScriptHash spk = true)
    (hp : parseWire ss = some ops)
    (hpo : isPushOnlyWire ops = true)
    (hl : ops.getLast? = some last)
    (hast : last.ast = .pushBytes d)
    (hd : isWitnessProgram d = none) :
    countWitnessSigOps ss spk witness = 0 := by
  simp only [countWitnessSigOps, hwp]
  rw [if_pos hp2sh]
  simp only [hp, hpo, hl, hast, hd]
  rfl

/-- The one-input law (tx_verify.cpp:160-167): a one-input tx's
witness sigop count = its input's `CountWitnessSigOps` at witness
stack index 0 (the `witness.getD 0` resolution).-/
theorem witnessSigOpsTx_one (tx : Tx) (i : TxIn)
    (spkTbl : OutPoint → Option ByteArray) (spk : ByteArray)
    (ht : spkTbl i.prevout = some spk)
    (hvi : { tx with vin := [i] }.vin = [i]) :
    witnessSigOpsTx { tx with vin := [i] } spkTbl
      = countWitnessSigOps i.scriptSig.bytes spk ({ tx with vin := [i] }.witness.getD 0 []) := by
  unfold witnessSigOpsTx
  rw [hvi]
  simp only [witnessSigOpsTxFrom, ht]
  omega

/-- The loop law: no witness program, no P2SH anywhere in the input
list ⇒ the whole indexed loop is 0 at every index (the ∀-index
induction over the input list).-/
theorem witnessSigOpsTxFrom_all_zero (tx : Tx)
    (spkTbl : OutPoint → Option ByteArray) :
    ∀ (l : List TxIn), (∀ (i : TxIn), i ∈ l →
      match spkTbl i.prevout with
      | some spk => isWitnessProgram spk = none ∧ isPayToScriptHash spk = false
      | none => True) →
    ∀ (n : Nat), witnessSigOpsTxFrom tx spkTbl l n = 0 := by
  intro l
  induction l with
  | nil => intro _ n; rfl
  | cons i rest ih =>
    intro hl n
    simp only [witnessSigOpsTxFrom]
    split
    · rename_i spk htbl
      have hall := hl i (List.mem_cons_self ..)
      rw [htbl] at hall
      obtain ⟨hw, hp⟩ := hall
      rw [countWitnessSigOps_nonwp_nonp2sh_zero i.scriptSig.bytes spk
        (tx.witness.getD n []) hw hp]
      have := ih (fun j hj => hl j (List.mem_cons_of_mem _ hj)) (n + 1)
      omega
    · next htbl =>
      have := ih (fun j hj => hl j (List.mem_cons_of_mem _ hj)) (n + 1)
      omega

/-- The per-input fall-through: no witness program, no P2SH ⇒ every
input contributes 0 ⇒ the whole loop is 0.-/
theorem witnessSigOpsTx_nonwp_nonp2sh_zero (tx : Tx)
    (spkTbl : OutPoint → Option ByteArray)
    (h : ∀ (i : TxIn), i ∈ tx.vin →
      match spkTbl i.prevout with
      | some spk => isWitnessProgram spk = none ∧ isPayToScriptHash spk = false
      | none => True) :
    witnessSigOpsTx tx spkTbl = 0 := by
  unfold witnessSigOpsTx
  exact witnessSigOpsTxFrom_all_zero tx spkTbl tx.vin h 0

/-! ## Axiom pins (every theorem here is sorry-free; standard axioms only) -/

section Pins

/-- info: 'Bitcoin.TxValidation.SigOpsCost.p2shScriptSigSigOps_parse_fail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms p2shScriptSigSigOps_parse_fail

/-- info: 'Bitcoin.TxValidation.SigOpsCost.p2shScriptSigSigOps_nonpush_tail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms p2shScriptSigSigOps_nonpush_tail

/-- info: 'Bitcoin.TxValidation.SigOpsCost.p2shScriptSigSigOps_push_redeem' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms p2shScriptSigSigOps_push_redeem

/-- info: 'Bitcoin.TxValidation.SigOpsCost.p2shScriptSigSigOps_redeem_parse_fail' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms p2shScriptSigSigOps_redeem_parse_fail

/-- info: 'Bitcoin.TxValidation.SigOpsCost.p2shSigOpsTx_coinbase_zero' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms p2shSigOpsTx_coinbase_zero

/-- info: 'Bitcoin.TxValidation.SigOpsCost.p2shSigOpsTx_one_nonp2sh_zero' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms p2shSigOpsTx_one_nonp2sh_zero

/-- info: 'Bitcoin.TxValidation.SigOpsCost.p2shSigOpsTx_one_p2sh' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms p2shSigOpsTx_one_p2sh

/-- info: 'Bitcoin.TxValidation.SigOpsCost.p2shSigOpsTx_one_missing_zero' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms p2shSigOpsTx_one_missing_zero

/-- info: 'Bitcoin.TxValidation.SigOpsCost.countWitnessSigOps_witnessprogram' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms countWitnessSigOps_witnessprogram

/-- info: 'Bitcoin.TxValidation.SigOpsCost.countWitnessSigOps_nonwp_nonp2sh_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms countWitnessSigOps_nonwp_nonp2sh_zero

/-- info: 'Bitcoin.TxValidation.SigOpsCost.countWitnessSigOps_pushonly_gate' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms countWitnessSigOps_pushonly_gate

/-- info: 'Bitcoin.TxValidation.SigOpsCost.countWitnessSigOps_p2sh_pushonly_lastpush' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms countWitnessSigOps_p2sh_pushonly_lastpush

/-- info: 'Bitcoin.TxValidation.SigOpsCost.countWitnessSigOps_parse_fail_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms countWitnessSigOps_parse_fail_zero

/-- info: 'Bitcoin.TxValidation.SigOpsCost.countWitnessSigOps_p2sh_redeem_nonwp_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms countWitnessSigOps_p2sh_redeem_nonwp_zero

/-- info: 'Bitcoin.TxValidation.SigOpsCost.witnessSigOpsTx_one' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms witnessSigOpsTx_one

/-- info: 'Bitcoin.TxValidation.SigOpsCost.witnessSigOpsTx_nonwp_nonp2sh_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms witnessSigOpsTx_nonwp_nonp2sh_zero

/-- info: 'Bitcoin.TxValidation.SigOpsCost.witnessSigOpsTxFrom_all_zero' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms witnessSigOpsTxFrom_all_zero

end Pins

end Bitcoin.TxValidation.SigOpsCost
