import Bitcoin.Interpreter.Interface
import Bitcoin.Interpreter.SigOps
import Bitcoin.Activation.Flags
import Bitcoin.Crypto.Seam.Entry
import Bitcoin.Crypto.Schnorr.TaggedHash
import Bitcoin.Crypto.Taproot.TapTweak
import Bitcoin.Crypto.Taproot.OutputKey

/-!
# Bitcoin.Interpreter.Rules — the interpreter rule layer SCR rule-row completion

The remaining SCR rows of the rule DB (`spec/db/rules.yaml`), one honest
consensus check + `@[rule]` tag + theorem per rule family. Ground truth:
interpreter.cpp @ `cce32b168` (the pin); every definition here is
total and sorry-free.

Row families landed in this module (the interpreter rule layer):

1. **Flag-combination well-formedness** (SCR-009/014): CLEANSTACK
   requires P2SH+WITNESS (interpreter.cpp:2113-2114), WITNESS requires
   P2SH (:2124) — `flagsComboOk`, proved for the mainnet consensus
   selector at EVERY height (exception blocks included).
2. **Per-input locktime checker** (SCR-132): `locktimeEnvOf` — the
   `GenericTransactionSignatureChecker` is constructed per input `nIn`
   and CheckLockTime/CheckSequence see only `txTo->nLockTime`,
   `txTo->vin[nIn].nSequence`, `txTo->nVersion` (:1755, 1792-1796);
   proved input-local by a congruence theorem.
3. **CSV tx-version gate** (SCR-128): `CheckSequence` fails when
   `txTo->version < 2` (uint32_t) (:1800-1801) — already the first branch of
   `checkSequenceDef`; theorem-pinned here.
4. **OP_1NEGATE encoding** (SCR-047): the `pushNum 0` arm of
   `stepBody` pushes `encodeScriptNum (-1)`; the wire form is exactly
   `0x81` (:499-523).
-/

namespace Bitcoin.Interpreter

open Bitcoin.Data Bitcoin.Numeric Bitcoin.Activation
open Bitcoin.Crypto.Seam (ScriptExecutionData SigVersion)

/-! ## 1. Flag-combination well-formedness (SCR-009 / SCR-014) -/

/-- The two flag-combination constraints `VerifyScript` asserts in Core
(interpreter.cpp:2113-2114: CLEANSTACK ⇒ P2SH ∧ WITNESS; :2124:
WITNESS ⇒ P2SH). `true` = the flag/policy pair is well-formed for the
full `VerifyScript` path. -/
@[rule "SCR-009", rule "SCR-014"]
def flagsComboOk (flags : ScriptFlags) (pol : PolicyFlags) : Bool :=
  (!pol.cleanstack ∨ (flags.p2sh ∧ flags.witness)) ∧
  (!flags.witness ∨ flags.p2sh)

/-- With the consensus policy word (CLEANSTACK off — it is a policy bit,
never set by `getBlockScriptFlags`), the second arm is the only content. -/
theorem flagsComboOk_consensus_pol (flags : ScriptFlags) :
    flagsComboOk flags default = (!flags.witness ∨ flags.p2sh) := by
  unfold flagsComboOk
  have hdc : (default : PolicyFlags).cleanstack = false := rfl
  simp [hdc]

/-- The mainnet consensus flag selector satisfies BOTH combination
constraints at every height: the three reachable base sets (NONE,
P2SH|WITNESS, P2SH|WITNESS|TAPROOT) each satisfy WITNESS ⇒ P2SH —
including the two named exception blocks — and the buried ORs touch only
DERSIG/CLTV/CSV/NULLDUMMY, so the record update preserves both arms. -/
theorem flagsComboOk_consensus (height : UInt32) :
    flagsComboOk (getBlockScriptFlags height) default = true ∧
    ((getBlockScriptFlags height).witness = true →
      (getBlockScriptFlags height).p2sh = true) := by
  by_cases h1 : height = BIP16_EXCEPTION_HEIGHT
  · subst h1
    rw [flags_bip16_exception]
    refine ⟨?_, ?_⟩
    · rw [flagsComboOk_consensus_pol]; simp
    · intro hw; simp at hw
  by_cases h2 : height = TAPROOT_EXCEPTION_HEIGHT
  · subst h2
    rw [flags_taproot_exception]
    exact ⟨by rw [flagsComboOk_consensus_pol]; simp, by intro _; rfl⟩
  · rw [flags_norm height h1 h2]
    exact ⟨by rw [flagsComboOk_consensus_pol]; simp, by intro _; rfl⟩

/-! ## 2. The per-input locktime checker (SCR-132) -/

/-- The `LocktimeEnv` a checker for input `nIn` of `tx` carries:
`GenericTransactionSignatureChecker` is constructed with `txTo` and
`nIn` (interpreter.cpp:1755, 1792-1796) and its CheckLockTime/
CheckSequence read exactly `txTo->nLockTime`, `txTo->vin[nIn].nSequence`
and `txTo->nVersion`. Out-of-range `nIn` (Core: `assert`ed,
consensus-unreachable) totalizes to the zero sequence. -/
@[rule "SCR-132"]
def locktimeEnvOf (tx : Bitcoin.Data.Tx) (nIn : Nat) : LocktimeEnv :=
  { txVersion := tx.version
    txLockTime := tx.locktime
    txSequence :=
      (tx.vin.getD nIn { prevout := .null, scriptSig := .empty,
                         sequence := 0 }).sequence }

/-- The checker environment is input-LOCAL: two transactions agreeing on
version, locktime and the `nIn`-th input give the same environment. -/
theorem locktimeEnvOf_congr (tx tx' : Bitcoin.Data.Tx) (nIn : Nat)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (hvin : (tx.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence
          = (tx'.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence) :
    locktimeEnvOf tx nIn = locktimeEnvOf tx' nIn := by
  unfold locktimeEnvOf
  simp only [hver, hlt, hvin]

/-- Consequently CheckLockTime is a per-input predicate: swapping any
input other than `nIn` (or any output) cannot change the CLTV verdict. -/
theorem checkLockTime_perInput (tx tx' : Bitcoin.Data.Tx) (nIn : Nat) (n : ScriptNum)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (hvin : (tx.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence
          = (tx'.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence) :
    checkLockTimeDef (locktimeEnvOf tx nIn) n
      = checkLockTimeDef (locktimeEnvOf tx' nIn) n := by
  rw [locktimeEnvOf_congr tx tx' nIn hver hlt hvin]

/-- Same for CheckSequence (BIP112). -/
theorem checkSequence_perInput (tx tx' : Bitcoin.Data.Tx) (nIn : Nat) (n : ScriptNum)
    (hver : tx.version = tx'.version) (hlt : tx.locktime = tx'.locktime)
    (hvin : (tx.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence
          = (tx'.vin.getD nIn { prevout := .null, scriptSig := .empty,
                                sequence := 0 }).sequence) :
    checkSequenceDef (locktimeEnvOf tx nIn) n
      = checkSequenceDef (locktimeEnvOf tx' nIn) n := by
  rw [locktimeEnvOf_congr tx tx' nIn hver hlt hvin]

/-! ## 3. CSV requires unsigned wire version ≥ 2 (SCR-128) -/

/-- `CheckSequence` (interpreter.cpp:1800-1801): BIP68/112 semantics are
undefined for unsigned wire versions 0 and 1, and Core fails the check — the first branch of `checkSequenceDef`. -/
@[rule "SCR-128"]
theorem checkSequenceDef_version_gate (env : LocktimeEnv) (n : ScriptNum)
    (hv : env.txVersion.toUInt32 < 2) : checkSequenceDef env n = false := by
  unfold checkSequenceDef
  split
  · rfl
  · rename_i hneg
    exact absurd hv hneg

/-- CSV reads the version's unsigned wire bits and the current input's
sequence; the transaction locktime is irrelevant to CheckSequence. -/
theorem checkSequenceDef_wire_congr (env env' : LocktimeEnv) (n : ScriptNum)
    (hv : env.txVersion.toUInt32 = env'.txVersion.toUInt32)
    (hs : env.txSequence = env'.txSequence) :
    checkSequenceDef env n = checkSequenceDef env' n := by
  simp only [checkSequenceDef, hv, hs]

/-- High-bit wire versions pass the version gate; ordinary sequence and
operand checks still apply. These closed examples use kernel reduction. -/
theorem checkSequenceDef_high_bit_versions :
    checkSequenceDef { txVersion := -1, txSequence := 1 } 1 = true ∧
    checkSequenceDef { txVersion := -2, txSequence := 1 } 1 = true ∧
    checkSequenceDef { txVersion := -2147483648, txSequence := 1 } 1 = true ∧
    checkSequenceDef { txVersion := -2147483647, txSequence := 1 } 1 = true := by
  decide

/-- info: 'Bitcoin.Interpreter.checkSequenceDef_version_gate' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkSequenceDef_version_gate

/-- info: 'Bitcoin.Interpreter.checkSequenceDef_wire_congr' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkSequenceDef_wire_congr

/-- info: 'Bitcoin.Interpreter.checkSequenceDef_high_bit_versions' depends on axioms: [propext] -/
#guard_msgs in #print axioms checkSequenceDef_high_bit_versions

/-! ## 4. OP_1NEGATE pushes 0x81 (SCR-047) -/

/-- The `pushNum 0` arm of `stepBody` (the `n = 0 ⇒ -1` mapping,
interpreter.cpp:499-523's OP_1NEGATE) pushes the 1-byte minimal encoding
`0x81`. This is the wire form the corpus checks against. -/
@[rule "SCR-047"]
theorem encodeScriptNum_1negate_0x81 :
    encodeScriptNum (-1 : ScriptNum) false = serU8 0x81 := by
  rfl

/-! ## 5. Sigop counting (SCR-033 / SCR-034 / SCR-035 / SCR-036)

The resource-accounting family the block-level cost limit reads
(`CScript::GetSigOpCount` script.cpp:173-205, `WitnessSigOps`
interpreter.cpp:2133-2147, `CountWitnessSigOps` :2162-2173). Pure
functions over the wire layer; the interpreter-side 201-opcode
budget (SCR-022/023) is separate and already in `Defs.lean`. -/

/-- The four signature-checking wire opcodes (0xac OP_CHECKSIG,
0xad OP_CHECKSIGVERIFY, 0xae OP_CHECKMULTISIG, 0xaf
OP_CHECKMULTISIGVERIFY) — each counts as 1 sigop in `GetSigOpCount`. -/
def isSigOpWire (w : Nat) : Bool :=
  w = 0xac ∨ w = 0xad ∨ w = 0xae ∨ w = 0xaf

/-- Core's static counter over parsed opcodes: CHECKSIG costs one;
CHECKMULTISIG costs the preceding OP_1..OP_16 value in accurate mode,
and twenty otherwise. A trailing OP_N has no independent cost. -/
@[rule "SCR-033"]
def sigOpCount (ops : List WireOp) (accurate : Bool) : Nat :=
  SigOps.sigOpCount ops accurate

/-- A single opcode has no preceding OP_N, so both modes agree. -/
theorem sigOpCount_single (op : WireOp) :
    sigOpCount [op] true = sigOpCount [op] false := rfl

/-- `CScript::GetSigOpCount(scriptSig)` (script.cpp:183-205): the P2SH
side — the subscript is the LAST PUSH of scriptSig (Core's `GetOp`
walk leaves the last push data in `vchRet`, clearing it on non-push
opcodes; a malformed scriptSig — `pc != end` — counts 0), evaluated
with the ACCURATE convention. The caller gates on
`scriptPubKey.IsPayToScriptHash()` (tx_verify.cpp:132-146). -/
@[rule "SCR-034"]
def p2shSigOpCount (scriptSig : ByteArray) : Nat :=
  SigOps.p2shScriptSigOps scriptSig

/-- `WitnessSigOps` (interpreter.cpp:2133-2147): witness v0 — program 20
(P2WPKH) = 1 sigop; program 32 (P2WSH) = the ACCURATE sigop count of
the witness script (the last witness item); everything else = 0. -/
@[rule "SCR-035"]
def witnessSigOps (version : Nat) (program : ByteArray) (witness : WitnessStack) : Nat :=
  if version = 0 then
    if program.size = 20 then 1
    else if program.size = 32 then
      match witness.getLast? with
      | none => 0
      | some script =>
        SigOps.witnessScriptSigOps script
    else 0
  else 0

/-- Witness v1+ programs contribute zero witness sigops. -/
theorem witnessSigOps_v1_zero (v : Nat) (program : ByteArray) (witness : WitnessStack)
    (hv : v ≠ 0) : witnessSigOps v program witness = 0 := by
  unfold witnessSigOps
  rw [ite_eq_right hv]

/-- A bare v0-20 program is exactly 1 sigop, independent of the witness. -/
theorem witnessSigOps_v0_20_one (witness : WitnessStack) (prog : ByteArray)
    (h20 : prog.size = 20) :
    witnessSigOps 0 prog witness = 1 := by
  unfold witnessSigOps
  rw [ite_eq_left rfl, ite_eq_left h20]

/-- `CountWitnessSigOps` (interpreter.cpp:2162-2173): the WITNESS-flag
gated extended counter — the caller only invokes this under
SCRIPT_VERIFY_WITNESS. Bare witness program in scriptPubKey →
`WitnessSigOps`; P2SH-wrapped (scriptPubKey P2SH AND scriptSig
push-only) → the redeem script (scriptSig's LAST push) must itself be a
witness program, else 0 extra; anything else → just the P2SH sigops. -/
@[rule "SCR-036"]
def countWitnessSigOps (ss spk : ByteArray) (witness : WitnessStack) : Nat :=
  match isWitnessProgram spk with
  | some (v, prog) => witnessSigOps v prog witness
  | none =>
    if isPayToScriptHash spk then
      match parseWire ss with
      | none => 0   -- Core: `pc != scriptSig.end()` ⇒ return 0
      | some ops =>
        if !isPushOnlyWire ops then 0
        else match ops.getLast? with
          | none => 0
          | some last =>
            match last.ast with
            | .pushBytes d =>
              match isWitnessProgram d with
              | some (v, prog) => witnessSigOps v prog witness
              | none => 0
            | _ => 0
    else 0

/-- For a bare witness-program scriptPubKey the counter reduces to
`WitnessSigOps` exactly (no P2SH component is ever added). -/
theorem countWitnessSigOps_bare (ss : ByteArray) (spk : ByteArray) (witness : WitnessStack)
    (v : Nat) (prog : ByteArray) (hbare : isWitnessProgram spk = some (v, prog)) :
    countWitnessSigOps ss spk witness = witnessSigOps v prog witness := by
  unfold countWitnessSigOps
  rw [hbare]

/-! ## 6. Transaction sigop cost + resource limits
(SCR-037 / SCR-038 / SCR-039 / SCR-043 / SCR-044) -/

/-- `GetLegacySigOpCount` (tx_verify.cpp:117-131): the INACCURATE
sigop count of every scriptSig and scriptPubKey (no P2SH subscripting,
no witness extension). -/
def txLegacySigOps (tx : Bitcoin.Data.Tx) : Nat :=
  tx.vin.foldl (fun acc i =>
    acc + SigOps.scriptSigOpCount i.scriptSig.bytes false) 0 +
  tx.vout.foldl (fun acc o =>
    acc + SigOps.scriptSigOpCount o.scriptPubKey.bytes false) 0

/-- `GetP2SHSigOpCount` (tx_verify.cpp:132-146): for every input whose
prevout scriptPubKey is a P2SH script, the accurate sigop count of the
redeem script (the last scriptSig push). -/
def txP2shSigOpsFrom (spkOf : Nat → ByteArray) : List Bitcoin.Data.TxIn → Nat → Nat
  | [], _ => 0
  | input :: rest, n =>
    (if isPayToScriptHash (spkOf n) then p2shSigOpCount input.scriptSig.bytes else 0) +
      txP2shSigOpsFrom spkOf rest (n+1)

def txP2shSigOps (tx : Bitcoin.Data.Tx) (spkOf : Nat → ByteArray) : Nat :=
  if tx.isCoinBase then 0 else txP2shSigOpsFrom spkOf tx.vin 0

theorem txP2shSigOps_coinbase (tx : Bitcoin.Data.Tx) (spkOf : Nat → ByteArray)
    (h : tx.isCoinBase = true) : txP2shSigOps tx spkOf = 0 := by
  simp [txP2shSigOps, h]

/-- `GetTransactionSigOpCost` (tx_verify.cpp:149-168): legacy and P2SH
sigops each weigh `WITNESS_SCALE_FACTOR` (4) cost units; the
witness-extended count (SCR-036) weighs 1. -/
@[rule "SCR-037"]
def sigOpCost (legacy p2sh witness : Nat) : Nat :=
  legacy * 4 + p2sh * 4 + witness

/-- The cost law in Core's factored form. -/
theorem sigOpCost_factored (legacy p2sh witness : Nat) :
    sigOpCost legacy p2sh witness = (legacy + p2sh) * 4 + witness := by
  unfold sigOpCost
  omega

/-- Witness-extended sigops contribute at least themselves to the cost
(the ×1 leg — the reason the witness extension is CHEAPER per sigop). -/
theorem sigOpCost_ge_witness (legacy p2sh witness : Nat) :
    witness ≤ sigOpCost legacy p2sh witness := by
  unfold sigOpCost
  omega

/-- `MAX_BLOCK_SIGOPS_COST` (consensus/consensus.h:18): the cumulative
per-block sigop-cost budget enforced in ConnectBlock
(validation.cpp:2566-2569). -/
@[rule "SCR-038"]
def MAX_BLOCK_SIGOPS_COST : Nat := 80000

/-- The block-level check shape: a block's summed sigop cost must fit
the 80,000 budget. -/
def blockSigOpsCostOk (totalCost : Nat) : Bool :=
  totalCost ≤ MAX_BLOCK_SIGOPS_COST

/-- `MAX_STANDARD_TX_SIGOPS_COST` (policy/policy.h:44): the mempool
policy per-tx sigop-cost cap enforced at StandardScriptVerifyFlags
admission (validation.cpp:905,939) — POLICY, not consensus
(rule DB `consensus: false`). -/
@[rule "SCR-039"]
def MAX_STANDARD_TX_SIGOPS_COST : Nat := 16000

/-- `MAX_PUBKEYS_PER_MULTI_A` (script.h:37-38): the tapscript
CHECKMULTISIG-mimic (miniscript `multi_a`) pubkey bound — a
miniscript-side resource limit, not an interpreter check (the BIP342
interpreter never reads it; it bounds script construction). -/
@[rule "SCR-043"]
def MAX_PUBKEYS_PER_MULTI_A : Nat := 999

/-- `MIN_TRANSACTION_WEIGHT` (consensus/consensus.h:24): the lower bound
for a serialized tx's weight (a minimal 1-in-1-out non-witness
transaction serializes to ≥ 60 bytes ⇒ weight ≥ 240). -/
@[rule "SCR-044"]
def MIN_TRANSACTION_WEIGHT : Nat := 240

/-- The weight floor in Core's own factored form: 240 = 4 × 60, the
WITNESS_SCALE_FACTOR × minimal-serialized-size pairing. -/
theorem MIN_TRANSACTION_WEIGHT_factored :
    MIN_TRANSACTION_WEIGHT = 4 * 60 := by
  rfl

/-! ## 8. BIP341 key-path spending (SCR-142 / SCR-144 / SCR-149)

The key-path semantics live in `verifyWitnessProgram`; this
section pins the three verdict-visible behaviors. -/

/-- SCR-142: the TAPROOT flag gate (interpreter.cpp:1959) — without
SCRIPT_VERIFY_TAPROOT, a v1-32 non-P2SH spend succeeds SILENTLY
(`.ok`, no witness inspection at all): the activation-soft-fork
behavior. -/
theorem verifyWitnessProgram_taproot_gate_silent_ok
    (fuel : Nat) (witness : WitnessStack) (program : ByteArray)
    (pol : PolicyFlags) (chk : ScriptChecker) (isP2SH : Bool)
    (h32 : program.size = 32) (hp2 : isP2SH = false)
    (hnotap : flags.taproot = false) :
    verifyWitnessProgram fuel witness 1 program flags pol chk isP2SH
      = VerifyOutcome.ok := by
  simp [verifyWitnessProgram, hnotap, h32, hp2]

/-- SCR-144: the key-path spend (interpreter.cpp:1970-1975) — exactly
one (post-annex) stack item is a BIP340 signature checked against the
output key (`program`) at SigVersion TAPROOT; the verdict is precisely
the checker's, fail-closed (`.fail .schnorrSig` on rejection). -/
@[rule "INV-072"]
theorem verifyWitnessProgram_keypath
    (fuel : Nat) (sig program : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker) (isP2SH : Bool)
    (htap : flags.taproot = true)
    (h32 : program.size = 32) (hp2 : isP2SH = false) :
    verifyWitnessProgram fuel [sig] 1 program flags pol chk isP2SH
      = schnorrOutcome (checkSchnorrWithContext chk sig program SigVersion.taproot
              { (default : ScriptExecutionData) with
                annexInit := true, annexPresent := false,
                annexHash := (default : ScriptExecutionData).annexHash }) := by
  simp [verifyWitnessProgram, htap, h32, hp2]

/-- SCR-149: witness versions ≥ 2 are UPGRADABLE — success today,
with DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM as the policy hook
(interpreter.cpp:1995-1998's else arm; P2A at v1 is BIP345's separate
grant). -/
theorem verifyWitnessProgram_upgradable_leaf_ok
    (fuel : Nat) (witness : WitnessStack) (program : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker) (isP2SH : Bool)
    (hv2 : 2 ≤ version)
    (hpa : isPayToAnchor version program = false)
    (hnodisc : pol.discourageUpgradableWitnessProgram = false) :
    verifyWitnessProgram fuel witness version program flags pol chk isP2SH
      = VerifyOutcome.ok := by
  have hv0 : ¬(version = 0) := by omega
  have hv1 : ¬(version = 1 ∧ program.size = 32 ∧ (!isP2SH) = true) := by
    intro h; rcases h with ⟨h1, _⟩; omega
  have hpa' : ¬((!isP2SH) = true ∧ isPayToAnchor version program = true) := by
    intro h; rcases h with ⟨_, h2⟩
    rw [hpa] at h2
    exact absurd h2 (by decide)
  have hnodisc' : ¬(pol.discourageUpgradableWitnessProgram = true) := by
    rw [hnodisc]; decide
  unfold verifyWitnessProgram
  rw [ite_eq_right hv0, ite_eq_right hv1, ite_eq_right hpa', ite_eq_right hnodisc']

/-! ## 7. BIP342 validation-weight budget (SCR-031 / SCR-040 / SCR-041 /
## SCR-042 / SCR-168)

The budget semantics live in `executeWitnessScript` (init)
and `evalChecksigTapscript` (decrement) — this section theorem-pins
them. The `evalChecksigTapscript` wiring into the CHECKSIG dispatch is
the interpreter delta layer's (`evalChecksigDispatch`). -/

/-- SCR-031: the BIP342 initial-stack gate (:1864-1865) — on the
tapscript path, away from an OP_SUCCESSx override, a witness stack of
more than MAX_STACK_SIZE (1000) items fails the script with STACK_SIZE
(the gate runs BEFORE evaluation). -/
theorem executeWitnessScript_tapscript_stackgate
    (fuel : Nat) (items : List ByteArray) (vwSer : Int) (exec : ByteArray)
    (flags : ScriptFlags) (pol : PolicyFlags) (chk : ScriptChecker)
    (hscan : opSuccessScan exec = false)
    (hmany : MAX_STACK_SIZE < items.length) :
    executeWitnessScript fuel items vwSer exec flags pol chk .tapscript
      = VerifyOutcome.fail .stackSize := by
  simp [executeWitnessScript, hscan, hmany]

/-- SCR-040/041: a SUCCESSFUL tapscript CHECKSIG decrements the budget
by exactly VALIDATION_WEIGHT_PER_SIGOP_PASSED (50) — the decrement is
computed before the signature verdict, so it is charged for non-empty
signatures regardless of validity (on failure the script errors; the
budget arithmetic is the same). -/
theorem evalChecksigTapscript_decrements_50
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk : pk.size = 32)
    (hok : checkSchnorrWithContext chk sig pk SigVersion.tapscript ed = .ok ())
    (hvw : 0 ≤ (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED) :
    evalChecksigTapscript pol chk ed sig pk vw
      = .ok (true, some ((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED)) := by
  simp [evalChecksigTapscript, hsig, hpk, hok,
    show ¬((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0) by omega]

/-- SCR-168: the budget check is `< 0`, NOT `≤ 0` — a budget that lands
EXACTLY on 0 after the decrement is still accepted. -/
theorem evalChecksigTapscript_budget_exactly_zero
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk : pk.size = 32)
    (hok : checkSchnorrWithContext chk sig pk SigVersion.tapscript ed = .ok ())
    (hvw : (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED = 0) :
    evalChecksigTapscript pol chk ed sig pk vw = .ok (true, some 0) := by
  simp [evalChecksigTapscript, hsig, hpk, hok, hvw]

/-- SCR-042: an upgradable (non-32-byte, non-empty) pubkey still
consumes the budget — the decrement precedes the pubkey-size dispatch
and the upgradable arm returns the decremented budget. -/
theorem evalChecksigTapscript_upgradable_key_decrements
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk0 : pk.size ≠ 0) (hpk32 : pk.size ≠ 32)
    (hno : pol.discourageUpgradablePubkeyType = false)
    (hvw : 0 ≤ (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED) :
    evalChecksigTapscript pol chk ed sig pk vw
      = .ok (true, some ((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED)) := by
  simp [evalChecksigTapscript, hsig, hpk0, hpk32, hno,
    show ¬((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0) by omega]

/-- SCR-158: the pubkey-size rules — 0 bytes FAILS
(TAPSCRIPT_EMPTY_PUBKEY), 32 bytes routes to BIP340 Schnorr, anything
else is upgradable (accepted with the decremented budget unless the
DISCOURAGE policy bit is set). -/
theorem evalChecksigTapscript_empty_pubkey_fails
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0)
    (hvw : 0 ≤ (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED)
    (hp0 : pk.size = 0) :
    evalChecksigTapscript pol chk ed sig pk vw = .error .tapscriptEmptyPubkey := by
  simp [evalChecksigTapscript, hsig, hp0,
    show ¬((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0) by omega]

theorem evalChecksigTapscript_32_is_schnorr
    (pol : PolicyFlags) (chk : ScriptChecker) (ed : ScriptExecutionData)
    (sig pk : ByteArray) (vw : Option Int)
    (hsig : sig.size ≠ 0) (hpk : pk.size = 32)
    (hbad : checkSchnorrWithContext chk sig pk SigVersion.tapscript ed = .error .schnorrSig)
    (hvw : 0 ≤ (vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED) :
    evalChecksigTapscript pol chk ed sig pk vw = .error .schnorrSig := by
  simp [evalChecksigTapscript, hsig, hpk, hbad,
    show ¬((vw.getD 0) - VALIDATION_WEIGHT_PER_SIGOP_PASSED < 0) by omega]

/-! ## 9. BIP340/341/342 Schnorr signature encoding (SCR-161/162/163/165/166)

Wrapper theorems over the frozen seam entry (`schnorrHashtype` /
`schnorrVerdict`, Seam/Entry.lean) — the seam is generic, so the
consensus facts below are pinned HERE, against the seam's parameters. -/

open Bitcoin.Crypto.Seam.Entry (schnorrHashtype schnorrVerdict SIGHASH_DEFAULT
  schnorrHashtype_none schnorrHashtype_64 schnorrHashtype_65
  schnorrHashtype_65_default_rejected)

/-- SCR-161 (interpreter.cpp:1736): only 64- and 65-byte signatures
reach Schnorr verification; every other size — including the empty
signature, which tapscript resolves BEFORE this entry (:377-380) — is
rejected (`SCHNORR_SIG_SIZE`). -/
@[rule "SCR-161"]
theorem schnorrVerdict_size_gate
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (h : sig.size ≠ 64 ∧ sig.size ≠ 65) :
    schnorrVerdict verify sighashSchnorr sig pk v d = false := by
  simp only [schnorrVerdict, schnorrHashtype_none sig h]
  split
  · split <;> rfl
  · rfl

/-- SCR-162 (interpreter.cpp:1741-1744): a 65-byte signature whose
trailing byte IS `SIGHASH_DEFAULT` (0x00) is a hashtype error —
`SIGHASH_DEFAULT` is never valid as an EXPLICIT byte. -/
@[rule "SCR-162"]
theorem schnorrVerdict_65_default_rejected
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) (h65 : sig.size = 65)
    (h0 : sig[64]! = SIGHASH_DEFAULT) :
    schnorrVerdict verify sighashSchnorr sig pk v d = false := by
  simp only [schnorrVerdict]
  rw [if_pos (by rcases hv with hv | hv <;> subst hv <;> simp), if_pos hp,
      schnorrHashtype_65_default_rejected sig h65 h0]

/-- SCR-163 (interpreter.cpp:1524-1527): the BIP341/342 hashtype
validity predicate — `≤ 0x03` or `0x81..0x83` (base 1..3, optionally
ANYONECANPAY'd). 0x00 (`SIGHASH_DEFAULT`) counts as valid here, but
only in its implicit 64-byte role (SCR-165); as an explicit 65th byte
it is rejected upstream (SCR-162, :1741-1744). -/
def isValidBip341Hashtype (ht : UInt8) : Bool :=
  ht ≤ 3 || (0x81 ≤ ht && ht ≤ 0x83)

@[rule "SCR-163"]
theorem isValidBip341Hashtype_char (ht : UInt8) :
    isValidBip341Hashtype ht = true ↔ ht ≤ 3 ∨ (0x81 ≤ ht ∧ ht ≤ 0x83) := by
  simp [isValidBip341Hashtype, Bool.or_eq_true, Bool.and_eq_true]

/-- The full valid hashtype matrix: 0x00..0x03 and 0x81..0x83 are all
accepted — everything else (e.g. 0x40, 0x84, 0xff) is not. -/
@[rule "SCR-163"]
theorem isValidBip341Hashtype_matrix :
    isValidBip341Hashtype 0x00 = true ∧ isValidBip341Hashtype 0x01 = true ∧
    isValidBip341Hashtype 0x02 = true ∧ isValidBip341Hashtype 0x03 = true ∧
    isValidBip341Hashtype 0x81 = true ∧ isValidBip341Hashtype 0x82 = true ∧
    isValidBip341Hashtype 0x83 = true ∧
    isValidBip341Hashtype 0x40 = false ∧ isValidBip341Hashtype 0x84 = false ∧
    isValidBip341Hashtype 0xff = false := by
  decide

/-- SCR-165 (interpreter.cpp:1524, 1740): `SIGHASH_DEFAULT` ≡ ALL
without the hashtype field — it arises ONLY as the implicit hashtype of
a 64-byte signature, and the digest is then computed for hashtype 0. -/
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
    schnorrVerdict verify sighashSchnorr sig pk v d = true := by
  simp only [schnorrVerdict]
  rw [if_pos (by rcases hv with hv | hv <;> subst hv <;> simp), if_pos hp,
      schnorrHashtype_64 sig h64]
  simp only [hd]
  exact hok

/-- SCR-166 (interpreter.cpp:1559-1560, 1745-1747): fail-closed sighash
construction — when the BIP341 sighash cannot be built for the popped
hashtype `ht` (e.g. SIGHASH_SINGLE with `in_pos ≥ vout.size()`, which
is the canonical construction failure the seam models as `none`), the
verdict is reject. The SignatureHashSchnorr body producing that `none`
is SCR-169 (blocked on the Taproot module). -/
@[rule "SCR-166"]
theorem schnorrVerdict_sighash_fail_closed
    (verify : ByteArray → ByteArray → ByteArray → Bool)
    (sighashSchnorr : ScriptExecutionData → UInt8 → SigVersion → Option ByteArray)
    (sig pk : ByteArray) (v : SigVersion) (d : ScriptExecutionData)
    (hv : v = SigVersion.taproot ∨ v = SigVersion.tapscript)
    (hp : pk.size = 32) (h65 : sig.size = 65)
    (ht : UInt8) (hht : sig[64]! = ht) (hne : ht ≠ SIGHASH_DEFAULT)
    (hnone : sighashSchnorr d ht v = none) :
    schnorrVerdict verify sighashSchnorr sig pk v d = false := by
  simp only [schnorrVerdict]
  rw [if_pos (by rcases hv with hv | hv <;> subst hv <;> simp), if_pos hp,
      schnorrHashtype_65 sig h65 (by rw [hht]; exact hne)]
  simp only [hht, hnone]

/-! ## 10. Misc pins (SCR-092 / SCR-167) -/

/-- SCR-092: OP_NOTEQUAL does not exist — the wire byte 0x8e is one of
the 15 DISABLED opcodes under base/segwit rules (interpreter.cpp:899's
"Note that OP_NOTEQUAL does not exist" comment sits right above the
disabled table), and under tapscript the same byte is an OP_SUCCESSx. -/
@[rule "SCR-092"]
theorem opNotequal_0x8e_disabled_and_success :
    disabledWire 0x8e = true ∧ isOpSuccessWire 0x8e = true := by
  decide

/-- SCR-092 (semantic half): there is no OP_NOTEQUAL execution rule. The
only opcode at wire byte 0x8e is OP_2DIV (`script.h`'s name table), and
`stepBody` rejects it as a disabled opcode before dispatch — no
comparison/not-equal state transition exists for this byte. `hcnt` is the
preceding OP_COUNT budget check (interpreter.cpp:459-463); a well-formed
execution that reaches the disabled table satisfies it. -/
@[rule "SCR-092"]
theorem opNotequal_0x8e_no_semantics (ctx : Ctx) (op : WireOp) (st : State)
    (hast : op.ast = Bitcoin.Script.Parser.Opcode.op ⟨0x8e, by decide⟩)
    (hw : op.wire = 0x8e) (hcnt : st.opCount < MAX_OPS_PER_SCRIPT) :
    stepBody ctx op st = .error .disabledOpcode := by
  unfold stepBody
  by_cases hsv : ctx.sv = SigVersion.base ∨ ctx.sv = SigVersion.witnessV0
  · simp [hast, hw, hsv, disabledWire]
    omega
  · simp [hast, hw, hsv, disabledWire]

/-- SCR-092 (tapscript half, wire check): a tapscript containing 0x8e is
an OP_SUCCESSx script — `opSuccessScan` succeeds before any opcode
semantics run (BIP342 §"OP_SUCCESSx"). -/
@[rule "SCR-092"]
theorem opSuccessScan_0x8e :
    opSuccessScan (ByteArray.mk #[0x8e]) = true := by decide

/-- SCR-167: every EXECUTED OP_CODESEPARATOR records `pbegincodehash`
as the byte offset just past the opcode (`op.next`, interpreter.cpp:444-445
`pbegincodehash = pc - pbegin` … :1065), consumed downstream by the
pre-tapscript sighash as `bytes.extract codeSep` (interpreter.cpp:1282's
scriptCode tail; `State.codeSep`, initialized to 0 = "from the
beginning" at ExecScript entry). -/
@[rule "SCR-167"]
theorem stepBody_codesep_records_next
    (ctx : Ctx) (op : WireOp) (st : State)
    (hop : op.ast = Bitcoin.Script.Parser.Opcode.op ⟨0xab, by decide⟩)
    (hw : op.wire = 0xab)
    (hts : ctx.sv = SigVersion.tapscript)
    (hexec : st.vf.all id = true) :
    stepBody ctx op st = .ok { st with codeSep := op.next, codeSepPos := st.opcodeIndex } := by
  rcases op with ⟨ast, wire, next⟩
  subst hop; subst hw
  simp only [stepBody, stepBody.dispatchOp, hexec, hts]
  rfl

/-! ## 11. Tapleaf hash, tweak pin, success matrix, opcode names
(SCR-146 / SCR-147 / SCR-172 / SCR-173) -/

/-- SCR-146 (interpreter.cpp:1882-1885, BIP341 §3): the tapleaf hash —
`hashTapLeaf = taggedHash("TapLeaf", leaf_ver ‖ CompactSize(script) ‖ script)`
with `leaf_ver = control[0] & 0xfe` (the parity bit stripped).
script path returns `.unjudged` at the tapleaf/CheckTapTweak EC step;
this pins the digest CONSTRUCTION on the Schnorr module's tagged-hash floor. -/
@[rule "SCR-146"]
def tapLeafHash (leafVersion : UInt8) (script : ByteArray) : ByteArray :=
  Bitcoin.Crypto.Schnorr.taggedHash Bitcoin.Crypto.Schnorr.tagTapLeaf
    (ByteArray.mk #[leafVersion &&& 0xfe] ++
      compactSizeEnc script.size ++ script)

/-- The tapleaf digest is 32 bytes (composition of `sha256_size`). -/
@[rule "SCR-146"]
theorem tapLeafHash_size (leafVersion : UInt8) (script : ByteArray) :
    (tapLeafHash leafVersion script).size = 32 := by
  unfold tapLeafHash
  exact Bitcoin.Crypto.Schnorr.taggedHash_size _ _

/-- SCR-147 (interpreter.cpp:1913-1925): the tap tweak commitment is a
FUNCTION of the internal key `p` and the script-tree merkle root — equal
inputs give the same tweaked output key `q` (the Taproot module's `tweakPoint`; the
parity bit `control[0] & 1` enters the SERIALIZATION of the control
block, not the commitment input `taptweak(p, root)`). -/
@[rule "SCR-147"]
theorem tweakPoint_determined (p p' : ByteArray) (P : Bitcoin.Crypto.Curve.Secp.RawPoint)
    (root root' : Option ByteArray)
    (hp : p = p') (hr : root = root') :
    Bitcoin.Crypto.Taproot.tweakPoint p P root
      = Bitcoin.Crypto.Taproot.tweakPoint p' P root' := by
  subst hp; subst hr; rfl

/-- SCR-147 (the commitment equation itself, interpreter.cpp:1913-1925):
with the internal key `p` parsed from `control[1..33]` and
`q = tweakPoint p (liftX p) root` for the script-tree merkle root, the
output-key commitment accepts iff the control block's parity bit
`control[0] & 1` equals the parity of `y(q)`. This is the tweak/parity
equation, not merely congruence of `tweakPoint`. -/
@[rule "SCR-147"]
theorem taprootCommitment_iff (control : ByteArray) (root : Option ByteArray)
    (xI yI xQ yQ : Nat)
    (hsize : Bitcoin.Crypto.Taproot.Program.TAPROOT_CONTROL_BASE_SIZE ≤ control.size)
    (hparse : Bitcoin.Crypto.Curve.Secp.liftX
        (Bitcoin.Crypto.Curve.Secp.bytesToNatBE
          (Bitcoin.Crypto.Taproot.OutputKey.internalKeyBytes control)) = some (xI, yI))
    (htweak : Bitcoin.Crypto.Taproot.tweakPoint
        (Bitcoin.Crypto.Taproot.OutputKey.internalKeyBytes control) (some (xI, yI)) root
        = some (xQ, yQ)) :
    Bitcoin.Crypto.Taproot.OutputKey.outputKeyOk control root
      = ((control.get! 0).toNat % 2 == yQ % 2) := by
  have hpos : 0 < control.size := by
    have h33 : Bitcoin.Crypto.Taproot.Program.TAPROOT_CONTROL_BASE_SIZE = 33 := rfl
    omega
  rw [Bitcoin.Crypto.Taproot.OutputKey.outputKeyOk_parity control root xI yI xQ yQ
      hsize hparse htweak,
    Bitcoin.Crypto.Taproot.OutputKey.parityOk_eq control yQ hpos]

/-- SCR-172 (script.cpp:365-371 + interpreter.cpp:1846-1862): EVERY
legacy-disabled wire byte (the CVE-2010-5137 15-set, = `disabledWire`)
is an OP_SUCCESSx under tapscript — BIP342 renames exactly these
OP_SUCCESS126..OP_SUCCESS153, so the disabled failure never fires
there. -/
@[rule "SCR-172"]
theorem disabledWire_successx_matrix :
    isOpSuccessWire 0x7e = true ∧ isOpSuccessWire 0x7f = true ∧
    isOpSuccessWire 0x80 = true ∧ isOpSuccessWire 0x81 = true ∧
    isOpSuccessWire 0x83 = true ∧ isOpSuccessWire 0x84 = true ∧
    isOpSuccessWire 0x85 = true ∧ isOpSuccessWire 0x86 = true ∧
    isOpSuccessWire 0x8d = true ∧ isOpSuccessWire 0x8e = true ∧
    isOpSuccessWire 0x95 = true ∧ isOpSuccessWire 0x96 = true ∧
    isOpSuccessWire 0x97 = true ∧ isOpSuccessWire 0x98 = true ∧
    isOpSuccessWire 0x99 = true := by
  decide

/-- SCR-173 (script.cpp:19-157): GetOpName's coverage — the name table
spans wire bytes 0x00..0xba contiguously (pushes, control, stack, crypto,
NOPs, CHECKSIGADD) plus 0xff = OP_INVALIDOPCODE; ONLY the reserved
0xbb..0xfe window falls through to `"OP_UNKNOWN"`. Display-only
(non-consensus). -/
def opNameKnown (w : Nat) : Bool := w ≤ 0xba || w = 0xff

@[rule "SCR-173"]
theorem opNameKnown_covers_table (w : Nat) (h : w ≤ 0xba) :
    opNameKnown w = true := by
  simp [opNameKnown, h]

@[rule "SCR-173"]
theorem opNameKnown_unknown_window (w : Nat) (h1 : 0xbb ≤ w) (h2 : w ≤ 0xfe) :
    opNameKnown w = false := by
  simp [opNameKnown]
  constructor
  · omega
  · omega

end Bitcoin.Interpreter
