import Bitcoin.Interpreter.Defs

/-!
# BitcoinProofs.Theorems.Audit.CV03 — the OP_EVAL incident probe (AF/CV03)

**Mission** (AF/CV03 brief): the BIP12 OP_EVAL incident (Nov 2011,
removed from Bitcoin Core before activation; the slot it would have
redefined is a plain upgradable NOP today). Four questions:

1. Is our 0xb5 handling pure NOP semantics (never recursively
   evaluating a pushed script)?
2. Incident documentation: why hard-fork risk killed OP_EVAL.
3. The malleability/recursion attack shape it would have enabled.
4. Is OP_SUCCESSx (tapscript) the only recursive-power escape hatch,
   and does it fail closed pre-activation?

**Ground truth**: Bitcoin Core @ cce32b168 (`build/scratch/interpreter.cpp`,
checked out at the same commit as the repo's pin): the NOP1/NOP4-10
switch `interpreter.cpp:605-611` (pure NOP + DISCOURAGE_UPGRADABLE_NOPS
policy), the OP_SUCCESSx pre-pass `:1847-1862` (TAPSCRIPT only), the
taproot script-path dispatch `:1976-2000` (leaf 0xc0 → TAPSCRIPT).
History: BIP12 (Status: Closed) full text; the 2011 reference
implementation `gavinandresen/bitcoin-git@77f21f15` `src/script.h`
(enum comment `OP_EVAL, // Was OP_NOP1` — **OP_EVAL = 0xb0 = OP_NOP1,
NOT 0xb5/OP_NOP6**; `EvalScript(..., bool fStrictOpEval, ...)` = the
"no-op rule" dual-validation parameter). Bitcoin Core PR #669 (2011)
added OP_EVAL, reverted before the 0.6 release train shipped it;
BIP16/P2SH (activated 2012-04-01) is the successor design.

**NOTE on the brief's byte**: the brief says "0xb5 today = OP_NOP6" —
correct that 0xb5 = OP_NOP6 today, but BIP12's OP_EVAL would have
re-**defined OP_NOP1 = 0xb0** (BIP12 §Specification bullet 1: "OP_EVAL
will re-define the existing OP_NOP1 opcode"; reference impl script.h).
Both bytes sit in the same `0xb0 ∨ (0xb3 ≤ w ∧ w ≤ 0xb9)` NOP window
(`stepBody`, Bitcoin/Interpreter/Defs.lean:826), so every probe below
is run on BOTH 0xb5 (the brief's byte) and 0xb0 (the historical
OP_EVAL slot).

**Probe map** (all sorry-free, no native_decide; axiom pins at the
bottom):

* **S0 — wire-table facts** (BIP12 quiescence): 0xb5/0xb0 are neither
  disabled (CVE-2010-5137 set) nor OP_SUCCESSx; 0xbb = OP_SUCCESS187
  (the first byte of the 187..254 success window) IS. `isPushOnlyWire`
  rejects a bare 0xb5 in a scriptSig-shaped push-only check (P2SH
  sigPushOnly analogue).
* **S2 — NOP purity** (question 1): `stepBody` on 0xb5/0xb0 returns
  `.ok st` with the stack IDENTICAL (a pushed script-shaped item is
  never popped, never parsed, never executed); tapscript likewise
  (opCount frozen); DISCOURAGE_UPGRADABLE_NOPS is the only error path,
  and it is POLICY (PolicyFlags), not consensus.
* **S3 — exec-level anti-OP_EVAL + the BIP12 hard-fork example**
  (questions 1-2): end-to-end `evalScriptBytes` runs of the exact
  BIP12 §Backwards-Compatibility example
  `scriptSig {serialized OP_11} / scriptPubKey OP_EVAL OP_11 OP_EQUAL`,
  with 0xb0 executed as the pure NOP Bitcoin Core actually shipped
  (the "no-op rule" interpretation — the transaction fails with an
  empty/falsy stack for EVERYONE). Under hypothetical OP_EVAL
  semantics the same run would push vchTrue (`[0x01]`, valid) — the
  old-clients-INVALID / new-clients-VALID divergence that made BIP12
  a hard fork against the no-op-interpretation unless every node ran
  the fStrictOpEval dual validation forever (see findings for why THAT
  was the risk that killed it).
* **S4 — OP_SUCCESSx raw-byte scan** (question 4): `opSuccessScan`
  returns true on a lone 0xbb (OP_SUCCESS187), false on `0xb5 0x51`.
* **S5 — fail-closed pre-activation** (question 4): the same raw
  0xbb script is `.fail badOpcode` under `.witnessV0` but `.ok` under
  `.tapscript` — the OP_SUCCESSx power is reachable ONLY through the
  tapscript lane, and even there DISCOURAGE_OP_SUCCESS (policy) can
  still fail it.
* **S6 — the taproot activation gate** (question 4): a v1/32-byte
  witness program with the TAPROOT consensus flag OFF (every
  pre-activation block) is an immediate `.ok` with the witness never
  touched — no script is executed at all; with the flag ON and an
  empty witness it fails `.witnessProgramWitnessEmpty`. Tapscript (and
  hence OP_SUCCESSx) is unreachable pre-activation.

Everything here is a PROBE over the frozen W09/X04 interpreter
(`Bitcoin.Interpreter.Defs`); no new definitions of consensus meaning.
-/

namespace BitcoinProofs.Theorems.Audit.CV03

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Script.Parser Bitcoin.Activation
open Bitcoin.Numeric
open Bitcoin.Crypto.Seam (SigVersion ScriptExecutionData stubChecker)

deriving instance Inhabited for Bitcoin.Activation.ScriptFlags

/-! ## S0 — wire-table facts: the OP_EVAL slots are quiet today

BIP12 wanted OP_EVAL at OP_NOP1 (0xb0); the brief asks about 0xb5
(OP_NOP6). Both are in the pure-NOP window `0xb0 ∨ 0xb3..0xb9`
(interpreter.cpp:605-611); neither is in the disabled set
(interpreter.cpp:447-467) nor in BIP342's OP_SUCCESSx set
(script.cpp:365-371) — 0xb5/181 misses every window (…149-153 ends at
0x99, 187-254 starts at 0xbb); 0xbb = OP_SUCCESS187 = the first
success wire byte. -/

theorem nop6_not_disabled : disabledWire 0xb5 = false := by decide
theorem nop1_not_disabled : disabledWire 0xb0 = false := by decide

theorem nop6_not_success : isOpSuccessWire 0xb5 = false := by decide
theorem nop1_not_success : isOpSuccessWire 0xb0 = false := by decide

/-- 0xbb = OP_SUCCESS187: the first byte of the `187 ≤ w ∧ w ≤ 254`
success window (script.cpp:365-371). -/
theorem success187_is_success : isOpSuccessWire 0xbb = true := by decide

/-- Probe inputs (Delta.lean idioms). `sc11` = the 2-byte payload
`0x51 0x51` = "the script `OP_1 OP_1`" — script-SHAPED stack data, the
OP_EVAL recursion operand. -/
def sc11 : ByteArray := ByteArray.mk #[(0x51 : UInt8), (0x51 : UInt8)]
def nop6Op : WireOp := { ast := .op ⟨0xb5, by decide⟩, wire := 0xb5, next := 1 }
def nop1Op : WireOp := { ast := .op ⟨0xb0, by decide⟩, wire := 0xb0, next := 1 }
def push11Op : WireOp := { ast := .pushBytes sc11, wire := 0x02, next := 3 }
def polDiscNops : PolicyFlags := { discourageUpgradableNops := true }
def polDiscSucc : PolicyFlags := { discourageOpSuccess := true }
def flTap : ScriptFlags := { taproot := true }
def p32 : ByteArray := ByteArray.mk (Array.replicate 32 (0x02 : UInt8))

/-- A bare 0xb5 opcode is NOT push-only: `CScript::IsPushOnly`
(script.h) would reject a scriptSig containing it — the P2SH
`sigPushOnly` lane (SWT-004) never lets a bare 0xb5 into the scriptSig
push-only precheck. (An OP_EVAL-style design hides the opcode inside
PUSHED DATA instead — exactly the scriptSig/push boundary the BIP16
review was worried about.) -/
theorem nop6_not_pushonly : isPushOnlyWire [nop6Op] = false := by decide

/-- The 2-byte direct push `0x02 0x51 0x51` IS push-only — the
OP_EVAL operand shape (script-as-data) is a legal scriptSig item. -/
theorem push11_is_pushonly : isPushOnlyWire [push11Op] = true := by decide

/-! ## S2 — NOP purity: 0xb5 / 0xb0 never touch the stack (question 1)

A script-SHAPED item (`sc11` = "OP_1 OP_1") sits on the stack; the
opcode step for 0xb5 (and 0xb0) returns `.ok` with the stack
BYTE-IDENTICAL — nothing popped, parsed, or executed. Under BIP12
OP_EVAL semantics the step would instead POP `sc11`, deserialize it,
and recursively execute `OP_1 OP_1` (stack → `[0x01, 0x01]`, ≠
`[0x51 0x51]`). The only 0xb5 error path is the POLICY bit
DISCOURAGE_UPGRADABLE_NOPS (PolicyFlags, not ScriptFlags) — the
soft-fork-compatibility escape a future redefinition must preserve.
-/

/-- 0xb5 = OP_NOP6 under BASE: `.ok st`, stack `[sc11]` untouched,
opCount 0 → 1 (the only effect). -/ -- PIN
theorem nop6_base_nop : stepBody ⟨default, default, default, SigVersion.base,
    ByteArray.empty, default⟩ nop6Op
    { stack := [sc11], alt := [], vf := [true], opCount := 0, codeSep := 0, vwLeft := none }
    = .ok { stack := [sc11], alt := [], vf := [true], opCount := 1,
            codeSep := 0, vwLeft := none } := by rfl

/-- 0xb0 = OP_NOP1 — the slot BIP12's OP_EVAL would have re-defined
(reference impl script.h: `OP_EVAL, // Was OP_NOP1`) — is the same
pure NOP under BASE. -/ -- PIN
theorem nop1_base_nop : stepBody ⟨default, default, default, SigVersion.base,
    ByteArray.empty, default⟩ nop1Op
    { stack := [sc11], alt := [], vf := [true], opCount := 0, codeSep := 0, vwLeft := none }
    = .ok { stack := [sc11], alt := [], vf := [true], opCount := 1,
            codeSep := 0, vwLeft := none } := by rfl

/-- The ONLY 0xb5 error path: the DISCOURAGE_UPGRADABLE_NOPS policy
bit (mempool policy; a consensus-nop for every activated rule) —
`PolicyFlags`, never `ScriptFlags`. -/ -- PIN
theorem nop6_discouraged_is_policy : stepBody ⟨default, polDiscNops, default,
    SigVersion.base, ByteArray.empty, default⟩ nop6Op
    { stack := [sc11], alt := [], vf := [true], opCount := 0, codeSep := 0, vwLeft := none }
    = .error ExecError.discourageUpgradableNops := by rfl

/-- 0xb5 under TAPSCRIPT (BIP342): still a pure NOP (BIP342 keeps the
NOP semantics of 0xb1..0xb2-checks' NOP-fallbacks and 0xb0/0xb3..0xb9
exactly; only CHECKMULTISIG and the MINIMALIF shape changed), and the
201-opcode budget guard is structurally OFF (opCount frozen at 0) —
`Delta.lean:253 opBudget_frozen_tapscript` idiom. 0xb5 = 181 is NOT
OP_SUCCESSx (S0), so under tapscript it executes, not succeeds. -/ -- PIN
theorem nop6_tapscript_nop_frozen : stepBody ⟨default, default, default,
    SigVersion.tapscript, ByteArray.empty, default⟩ nop6Op
    { stack := [sc11], alt := [], vf := [true], opCount := 0, codeSep := 0, vwLeft := none }
    = .ok { stack := [sc11], alt := [], vf := [true], opCount := 0,
            codeSep := 0, vwLeft := none } := by rfl

/-! ## S3 — exec-level anti-OP_EVAL + the BIP12 hard-fork example
(questions 1-2)

BIP12 §Backwards-Compatibility, verbatim example of "a transaction
that must fail for both old and new miners/clients":

    scriptSig:  {serialized OP_11}          (push the byte 0x5b)
    scriptPubKey:  OP_EVAL OP_11 OP_EQUAL   (0xb0 0x5b 0x87)

2011 `VerifyScript` ran scriptSig then scriptPubKey over ONE shared
stack (our `evalScriptBytes` runs the two byte-strings over a shared
stack in the two probes below). The two probes fix both halves of the
divergence Bitcoin Core actually hit (see findings §2): with 0xb0 as
the PURE NOP Core shipped, OP_11 pushes scriptnum 11 = `0x0b`, the
pushed item is the raw byte `0x5b` (= 91) — OP_EQUAL pops both and
pushes vchFalse (empty) → the script ends with a falsy stack → the
transaction fails FOR EVERYONE (BIP12's "no-op rule" outcome). Under
hypothetical OP_EVAL semantics, 0xb0 would have popped `0x5b`,
EXECUTED it as the script `OP_11`, and compared 11 = 11 → vchTrue →
VALID — for new clients only. Same bytes, opposite verdicts. -/

/-- scriptSig half: `0x01 0x5b` pushes the raw byte `0x5b`
("serialized OP_11") — legal under every rule, then and now. -/ -- PIN
theorem bip12_sigside_push11 : evalScriptBytes 10 default default
    (ByteArray.mk #[(0x01 : UInt8), (0x5b : UInt8)]) [] default
    SigVersion.base default
    = .ok [ByteArray.mk #[(0x5b : UInt8)]] := by
  set_option maxRecDepth 8000 in rfl

/-- scriptPubKey half under the NO-OP interpretation (what Bitcoin
Core shipped): 0xb0 = pure NOP leaves `[0x5b]`; OP_11 pushes `0x0b`;
OP_EQUAL compares `0x5b ≠ 0x0b` (byte-wise) → vchFalse = the EMPTY
`ByteArray` — the script ends with the single empty item = CastToBool
FALSE (interpreter.cpp:242-244) = the transaction FAILS. Hypothetical
OP_EVAL: 0xb0 pops + executes `OP_11` → stack `[0x0b]`; OP_11 →
`[0x0b, 0x0b]`; OP_EQUAL → vchTrue `[0x01]` = VALID. The pair
`.ok [ByteArray.empty]` (ours) vs `.ok [ByteArray.mk #[0x01]]`
(OP_EVAL) is the hard-fork divergence in one stack cell. -/ -- PIN
theorem bip12_noprule_0xb0_fails : evalScriptBytes 10 default default
    (ByteArray.mk #[(0xb0 : UInt8), (0x5b : UInt8), (0x87 : UInt8)])
    [ByteArray.mk #[(0x5b : UInt8)]] default SigVersion.base default
    = .ok [ByteArray.empty] := by
  set_option maxRecDepth 12000 in rfl

/-- End-to-end 0xb5 (the brief's byte): the script
`0x02 0x51 0x51 0xb5` = "push the 2-byte script `OP_1 OP_1`, then 0xb5"
leaves the pushed script BYTES on the stack, un-parsed and un-executed
(`[0x51 0x51]`, NOT OP_EVAL's `[0x01, 0x01]`-with-`0x51 0x51`
-popped). The recursion OP_EVAL would have performed does not exist in
our 0xb5 — question 1. -/ -- PIN
theorem nop6_leaves_scriptbytes_unexeced : evalScriptBytes 10 default default
    (ByteArray.mk #[(0x02 : UInt8), (0x51 : UInt8), (0x51 : UInt8), (0xb5 : UInt8)])
    [] default SigVersion.base default
    = .ok [ByteArray.mk #[(0x51 : UInt8), (0x51 : UInt8)]] := by
  set_option maxRecDepth 12000 in rfl

/-- Same shape for 0xb0 (the historical OP_EVAL slot):
`0x01 0x51 0xb0` = "push `OP_1`, then 0xb0" → `[0x51]` un-executed. -/ -- PIN
theorem nop1_leaves_scriptbytes_unexeced : evalScriptBytes 10 default default
    (ByteArray.mk #[(0x01 : UInt8), (0x51 : UInt8), (0xb0 : UInt8)])
    [] default SigVersion.base default
    = .ok [ByteArray.mk #[(0x51 : UInt8)]] := by
  set_option maxRecDepth 12000 in rfl

/-! ## S4 — the OP_SUCCESSx raw-byte scan (question 4)

`opSuccessScan` (Defs.lean:435-455) is the BIP342 pre-pass over the
RAW tapscript bytes (interpreter.cpp:1846-1862): decode one opcode at
a time; the first OP_SUCCESSx decoded returns `true` (overriding even
a LATER truncated push). 0xbb = OP_SUCCESS187 trips it immediately;
`0xb5 0x51` (a NOP + an OP_1 push) scans clean past both. -/

/-- PIN -/
theorem scan_success187 : opSuccessScan (ByteArray.mk #[(0xbb : UInt8)]) = true := by
  set_option maxRecDepth 8000 in rfl

/-- 0xb5 (not success) then 0x51 = OP_1 (a PUSH — push-shaped decodes
never carry a success wire byte) — nothing succeeds, the scan walks
the whole script. -/ -- PIN
theorem scan_nop6_push : opSuccessScan
    (ByteArray.mk #[(0xb5 : UInt8), (0x51 : UInt8)]) = false := by
  set_option maxRecDepth 8000 in rfl

/-! ## S5 — fail-closed pre-activation (question 4)

The SAME raw script byte 0xbb (OP_SUCCESS187), once as a witness-v0
P2WSH script, once as a tapscript:

* `.witnessV0` (P2WSH): `.fail badOpcode` — OP_SUCCESSx power does
  not exist outside tapscript; 0xbb = 187 falls through the whole
  dispatch (interpreter.cpp:1227-1228 default) and the transaction is
  INVALID. This is "fail closed".
* `.tapscript`: `.ok` — BIP342's OP_SUCCESSx: the tapscript succeeds
  UNCONDITIONALLY (BIP342 §Spec step 2; "overrides everything,
  including stack element size limits", interpreter.cpp:1847). Even
  here the DISCOURAGE_OP_SUCCESS policy bit can fail it (policy
  anti-quiescence, not consensus).

The tapscript SigVersion (and hence the scan) is only reachable
through the S6 gate. -/

/-- PIN -/
theorem raw0xbb_witnessv0_fails : executeWitnessScript 10
    [ByteArray.mk #[(0x01 : UInt8)]] 0
    (ByteArray.mk #[(0xbb : UInt8)]) default default default
    SigVersion.witnessV0
    = VerifyOutcome.fail ExecError.badOpcode := by
  set_option maxRecDepth 12000 in rfl

/-- PIN -/
theorem raw0xbb_tapscript_succeeds : executeWitnessScript 10
    [ByteArray.mk #[(0x01 : UInt8)]] 0
    (ByteArray.mk #[(0xbb : UInt8)]) default default default
    SigVersion.tapscript
    = VerifyOutcome.ok := by
  set_option maxRecDepth 12000 in rfl

/-- PIN -/
theorem raw0xbb_tapscript_discouraged : executeWitnessScript 10
    [ByteArray.mk #[(0x01 : UInt8)]] 0
    (ByteArray.mk #[(0xbb : UInt8)]) default polDiscSucc default
    SigVersion.tapscript
    = VerifyOutcome.fail ExecError.discourageOpSuccess := by
  set_option maxRecDepth 12000 in rfl

/-! ## S6 — the taproot activation gate (question 4)

A version-1 / 32-byte witness program (the P2TR shape) with the
TAPROOT consensus flag OFF (i.e. every block before the BIP341
activation height 709632, and the mainnet exception block 692261) is
an IMMEDIATE `.ok` at `verifyWitnessProgram` (Defs.lean:1215): no
witness item is read, no script is executed, no key is checked. The
tapscript SigVersion — the only lane that runs `opSuccessScan` — is
BELOW this gate (script-path spending, leaf version 0xc0), so
OP_SUCCESSx is unreachable pre-activation. With the flag ON and an
empty witness, it fails `.witnessProgramWitnessEmpty` (no soft
accept). -/

/-- TAPROOT flag OFF (pre-activation): v1/32B is the
upgradable-witness-version SUCCESS lane — nothing is executed, no
recursion power is reachable. -/ -- PIN
theorem taproot_off_v1_is_success : verifyWitnessProgram 10 [] 1 p32
    default default default false
    = VerifyOutcome.ok := by
  set_option maxRecDepth 12000 in rfl

/-- TAPROOT flag ON + empty witness: hard `.fail` — activation makes
v1/32B spendable ONLY through the BIP341 key-path/script-path rules
(key-path `.unjudged`-at-`X03-Verify`-seam / script-path → leaf 0xc0
→ tapscript), never soft-accepted. -/ -- PIN
theorem taproot_on_empty_witness_fails : verifyWitnessProgram 10 [] 1 p32
    flTap default default false
    = VerifyOutcome.fail ExecError.witnessProgramWitnessEmpty := by
  set_option maxRecDepth 12000 in rfl

/-! ## Axiom pins

`#print axioms` on every non-`decide` probe (the `decide`-reduced
S0/G facts are axiom-free by construction): expect
`[propext, Classical.choice, Quot.sound]` or fewer (an axiom-free
`rfl` reduction only means no `Classical` was forced).
-/

#print axioms nop6_base_nop
#print axioms nop1_base_nop
#print axioms nop6_discouraged_is_policy
#print axioms nop6_tapscript_nop_frozen
#print axioms bip12_sigside_push11
#print axioms bip12_noprule_0xb0_fails
#print axioms nop6_leaves_scriptbytes_unexeced
#print axioms nop1_leaves_scriptbytes_unexeced
#print axioms scan_success187
#print axioms scan_nop6_push
#print axioms raw0xbb_witnessv0_fails
#print axioms raw0xbb_tapscript_succeeds
#print axioms raw0xbb_tapscript_discouraged
#print axioms taproot_off_v1_is_success
#print axioms taproot_on_empty_witness_fails

end BitcoinProofs.Theorems.Audit.CV03
