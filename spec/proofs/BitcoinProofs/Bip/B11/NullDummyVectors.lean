import Bitcoin.Interpreter.Defs
import Bitcoin.Activation.Flags
import Bitcoin.Activation.Bip9

/-!
# B11 — BIP147 NULLDUMMY decisive vectors (build-time, no IO)

Review-5 support suite contributor B11, 2026-10-16. NEW file, owned by B11.

Ground truth:
  * BIP147 (bip-0147.mediawiki, public domain, status: Deployed) §Specification:
    the OP_CHECKMULTISIG/OP_CHECKMULTISIGVERIFY dummy element MUST be the empty
    byte array whenever NULLDUMMY is a consensus flag; anything else fails the
    script. §Deployment: BIP147 rides the BIP9 "segwit" deployment (bit 1,
    start 1479168000, timeout 1510704000 — inherited verbatim from
    bip-0141.mediawiki:305-308).
  * Bitcoin Core @ pinned commit `cce32b168` (checkout
    build/scratch/B5/bitcoin, HEAD verified == cce32b1682d86076ee71c10f9788c48d44458a263):
    `src/script/interpreter.cpp:1211-1213` — the gate runs AFTER signature
    validation and cleanup, BEFORE the CHECKMULTISIGVERIFY success-pop;
    `interpreter.cpp:1118` — tapscript (BIP342) removed CHECKMULTISIG
    entirely, so NULLDUMMY is unreachable there.

Lean implementation under audit: `Bitcoin.Interpreter.stepBody.checkMultiSig`
(gate `ctx.flags.nullDummy ∧ st₃[0]!.size ≠ 0 → .error .sigNullDummy`, rules
SWT-064/SCR-119) and `Bitcoin.Activation.{Interface,Flags}` (BIP147_HEIGHT =
481824, rules BLK-088/SWT-063).

Python cross-check: `scratch/B11/ref147.py` (reference model of
interpreter.cpp:1113-1225 @ cce32b168 with the same seam stub; verdict table
reproduced below and matched 9/9, plus the mainnet activation boundary and the
BIP9 timestamp arithmetic).

Pin style: kernel-checked `native_decide` on structural `BEq` verdict
predicates (`errIs`/`okIs`; `ExecError`/`State` derive structural BEq, so these
are exact verdict pins). `native_decide` examples carry the
`Lean.ofReduceBool` compiler axiom by design (Test-scoped, per the
Delta.lean house pattern); every named theorem below is `rfl`/`decide`-only
(axiom audit in scratch/B11/axioms.md).

Mutation-kill map (each pin names a mutation it detects):
  V1 kills "gate removed" and "gate checks wrong element";
  V2 kills "gate rejects everything" (empty dummy passes; the sig/pk/nsv
     elements are NOT the dummy — pins the dummy's stack position too);
  V3 kills "gate flag-independent" (pre-activation dummy allowed);
  V4 kills "segwit-v0 scope dropped" (P2WSH in scope per BIP147);
  V5 pins the tapscript re-import interplay (CMS banned ⇒ sigNullDummy
     unreachable under tapscript even with the flag on);
  V6 kills "CMSVERIFY failure masked as sigNullDummy" (empty dummy ⇒
     checkMultiSigVerify; gate ordering from the other side);
  V7 kills "gate moved after the CMSVERIFY branch" (dummy error wins
     over verify error, matching interpreter.cpp:1211 < 1217);
  V8 kills "gate flag-independent on the fail path" (genesis pops the
     dummy unchecked, SWT-065);
  V9 kills "gate only on the fSuccess path" (gate is fSuccess-independent,
     matching Core: the check sits after the cleanup loop either way);
  A1/A2 kill "activation height off by one / wrong height";
  FB kills the flag-bit mapping (NULLDUMMY = 1 <<< 4 = 16, 0x20E15 total).
-/

namespace BitcoinProofs.Bip.B11.NullDummyVectors

open Bitcoin.Interpreter Bitcoin.Activation
open Bitcoin.Crypto.Seam (SigVersion stubChecker)

set_option maxRecDepth 40000

/-! ### Shared vector material -/

/-- CScriptNum encoding of 1 (the nkv / nsv elements). -/
def sn1 : ByteArray := ByteArray.mk #[(0x01 : UInt8)]

/-- 33-byte compressed-form pubkey (unchecked: DERSIG/STRICTENC off). -/
def pk33 : ByteArray := ByteArray.mk (Array.replicate 33 (0x02 : UInt8))

/-- 72-byte nonempty signature — the seam stub accepts any nonempty
(sig, pk) pair, so fSuccess = true. -/
def sig72 : ByteArray := ByteArray.mk (Array.replicate 72 (0x30 : UInt8))

/-- Empty signature — stub rejects ⇒ fSuccess = false. -/
def sigE : ByteArray := ByteArray.empty

/-- Nonempty dummy (the malleability BIP147 kills: any byte would do). -/
def dummy01 : ByteArray := ByteArray.mk #[(0x51 : UInt8)]

/-- Empty dummy (BIP147-compliant). -/
def dummyE : ByteArray := ByteArray.empty

/-- 1-of-1 CHECKMULTISIG stack, head-of-list = top-of-stack:
`[nkv, pk, nsv, sig, dummy]` (nkv at top; nsv at index nKeys+1 = 2;
sig at index isig-1 = 3; pk at index ikey-1 = 1; dummy deepest). -/
def stackFor (sig dummy : ByteArray) : List ByteArray :=
  [sn1, pk33, sn1, sig, dummy]

/-- Context with the NULLDUMMY consensus flag on/off. -/
def mkCtx (nd : Bool) (sv : SigVersion) : Ctx :=
  { flags := { nullDummy := nd }, pol := default,
    chk := ⟨stubChecker, default⟩, sv := sv, bytes := .empty, ed := default }

/-- Fresh machine state. -/
def mkSt (stack : List ByteArray) : State :=
  { stack := stack, alt := [], vf := [], opCount := 0, codeSep := 0, vwLeft := none }

/-- Verdict predicate: the run fails with exactly error `e`
(structural equality via the derived BEq). -/
def errIs (r : Except ExecError State) (e : ExecError) : Bool :=
  match r with | .error e' => e' == e | .ok _ => false

/-- Verdict predicate: the run succeeds with exactly state `s`. -/
def okIs (r : Except ExecError State) (s : State) : Bool :=
  match r with | .ok s' => s' == s | .error _ => false

/-! ### Python-cross-checked conformance pins (ref147.py verdict table) -/

/-- V1 — `cms nullDummy dummy01` → `sigNullDummy` (ref147.py: error). -/
example : errIs (stepBody.checkMultiSig (mkCtx true .base) 0xae (mkSt (stackFor sig72 dummy01)))
    .sigNullDummy = true := by native_decide

/-- V2 — `cms nullDummy dummyEmpty` → ok, stack `[vchTrue]`, opCount 1
(ref147.py: ok [0x01]; the nonempty sig/pk/nsv are untouched by the gate —
this also pins WHICH element is the dummy). -/
example : okIs (stepBody.checkMultiSig (mkCtx true .base) 0xae (mkSt (stackFor sig72 dummyE)))
    { stack := [vchTrue], alt := [], vf := [], opCount := 1, codeSep := 0, vwLeft := none } := by
  native_decide

/-- V3 — `cms flagsOff dummy01` → ok (pre-activation; SWT-065 genesis pop). -/
example : okIs (stepBody.checkMultiSig (mkCtx false .base) 0xae (mkSt (stackFor sig72 dummy01)))
    { stack := [vchTrue], alt := [], vf := [], opCount := 1, codeSep := 0, vwLeft := none } := by
  native_decide

/-- V4 — `cms witnessV0 nullDummy dummy01` → `sigNullDummy` (P2WSH scope). -/
example : errIs (stepBody.checkMultiSig (mkCtx true .witnessV0) 0xae (mkSt (stackFor sig72 dummy01)))
    .sigNullDummy = true := by native_decide

/-- V5 — tapscript interplay: with the flag ON, CHECKMULTISIG is still
banned (BIP342), so `tapscriptCheckMultiSig`, never `sigNullDummy`. -/
example : errIs (stepBody.checkMultiSig (mkCtx true .tapscript) 0xae (mkSt (stackFor sig72 dummy01)))
    .tapscriptCheckMultiSig = true := by native_decide

/-- V6 — `cmsv nullDummy dummyEmpty badSig` → `checkMultiSigVerify`
(gate passes on the empty dummy; the verify failure surfaces). -/
example : errIs (stepBody.checkMultiSig (mkCtx true .base) 0xaf (mkSt (stackFor sigE dummyE)))
    .checkMultiSigVerify = true := by native_decide

/-- V7 — `cmsv nullDummy dummy01 goodSig` → `sigNullDummy` (the dummy
error precedes the CMSVERIFY branch, interpreter.cpp:1211 < 1217). -/
example : errIs (stepBody.checkMultiSig (mkCtx true .base) 0xaf (mkSt (stackFor sig72 dummy01)))
    .sigNullDummy = true := by native_decide

/-- V8 — `cmsv flagsOff dummy01 badSig` → `checkMultiSigVerify`
(flags-off fail path still pops the dummy unchecked). -/
example : errIs (stepBody.checkMultiSig (mkCtx false .base) 0xaf (mkSt (stackFor sigE dummy01)))
    .checkMultiSigVerify = true := by native_decide

/-- V9 — `cms nullDummy dummy01 badSig` → `sigNullDummy` (gate is
fSuccess-independent: it sits after the cleanup loop either way). -/
example : errIs (stepBody.checkMultiSig (mkCtx true .base) 0xae (mkSt (stackFor sigE dummy01)))
    .sigNullDummy = true := by native_decide

/-! ### Activation pins (consensus activation, BIP147 §Deployment) -/

/-- A1 — one below segwit's buried height: NULLDUMMY consensus flag OFF. -/
example : (getBlockScriptFlags (481823 : UInt32)).nullDummy = false := by
  native_decide

/-- A2 — exactly at the buried height 481824: NULLDUMMY consensus flag ON
(a block at exactly the activation height already carries the flag). -/
example : (getBlockScriptFlags (481824 : UInt32)).nullDummy = true := by
  native_decide

/-- A3 — the pinned BIP147 height. -/
theorem bip147_height_pin : BIP147_HEIGHT = 481824 := rfl

/-- FB1 — NULLDUMMY is consensus flag bit 4 (Core `bit(4)` value 16). -/
example : flagBits { nullDummy := true } = 16 := by native_decide

/-- FB2 — post-481824 mainnet flag word is the full seven-flag set
`0x20E15` (pinned through `Interface.getBlockScriptFlags`, tying the
Interface and Flags models together). -/
example : flagBits (getBlockScriptFlags (481824 : UInt32)) = 0x20E15 := by
  native_decide

/-! ### BIP9 deployment parameters (BIP147 §Deployment = BIP141's) -/

/-- BIP147/BIP141 mainnet deployment row (bip-0141.mediawiki:305-308,
values cross-checked by scratch/B11/ref147.py against python datetime):
name "segwit", bit 1, start midnight 2016-11-15 UTC, timeout midnight
2017-11-15 UTC. -/
def bip147DeploymentBit : Nat := 1
def bip147DeploymentStart : Nat := 1479168000
def bip147DeploymentTimeout : Nat := 1510704000

theorem bip147_deployment_params :
    bip147DeploymentBit = 1 ∧
    bip147DeploymentStart = 1479168000 ∧
    bip147DeploymentTimeout = 1510704000 :=
  ⟨rfl, rfl, rfl⟩

/-! ### F-B11-001 divergence record (VERIFIED against the BIP text)

`Bitcoin.Activation.segwitBip9Deployment` (SWT-036, DORMANT historical row,
not in `mainnetDeployments` — so live consensus is unaffected) pins
`start := 1483228800` = 2017-01-01 UTC and `timeout := 1510708800` =
2017-11-15 01:20 UTC, while the BIP text it cites says 1479168000
(2016-11-15) and 1510704000 (2017-11-15). Divergences pinned here so the
delta is machine-checkable; Bip9.lean itself is NOT edited (not B11's
file). -/

theorem swt036_start_divergence :
    segwitBip9Deployment.start = 1483228800 ∧ (1483228800 : Nat) ≠ 1479168000 :=
  ⟨rfl, by decide⟩

theorem swt036_timeout_divergence :
    segwitBip9Deployment.timeout = 1510708800 ∧ (1510708800 : Nat) ≠ 1510704000 :=
  ⟨rfl, by decide⟩

end BitcoinProofs.Bip.B11.NullDummyVectors
