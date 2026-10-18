import Bitcoin.Interpreter.Defs

/-!
# BitcoinProofs.Theorems.Ops.O09 — OP_CHECKMULTISIG / OP_CHECKMULTISIGVERIFY semantics

Per-opcode semantics theorems for the crypto3 group, against
interpreter (`Bitcoin.Interpreter.Defs`: `stepBody.checkMultiSig` +
`cmsLoop` + `cmsCleanup`) and Core's `EvalScript` OP_CHECKMULTISIG case
(interpreter.cpp:1113-1225 @ `cce32b168`):

* **Tapscript ban** interpreter.cpp:1115 — `sigversion == TAPSCRIPT` ⇒
  `SCRIPT_ERR_TAPSCRIPT_CHECKMULTISIG` (SCR-121), before any stack read.
* **Count/limit ladder** (SCR-114): `nKeysCount = CScriptNum(stacktop(-1))`
  (:1122), `< 0 ∨ > 20` ⇒ `PUBKEY_COUNT` (:1123-1124); then
  `nOpCount += nKeysCount; > 201` ⇒ `OP_COUNT` (:1128-1130) — the
  *sigop counting* rule, one budget unit per pubkey; `nSigsCount` from
  `stacktop(-(nKeys+2))` (:1132), `< 0 ∨ > nKeysCount` ⇒ `SIG_COUNT`
  (:1136-1137); three depth checks ⇒ `INVALID_STACK_OPERATION`
  (:1119-1121, :1134, :1143).
* **The off-by-one / dummy** (SCR-118, SWT-065): the final arity
  requirement is `nKeys + nSigs + 3` — exactly `nKeys + nSigs + 2` items
  (the "obvious" arguments plus both counts) is NOT enough; the extra
  element is the historical off-by-one dummy. After the match,
  `while (i-- > 1)` pops `nKeys + nSigs + 2` items (:1212-1221) and the
  dummy is popped *separately* (:1220-1223), its contents unchecked
  unless NULLDUMMY (BIP147, consensus post-SegWit ⇒ `SIG_NULLDUMMY`,
  SWT-064).
* **Matching loop** (:1187-1210, SCR-116/117): sigs walk keys in order;
  early `fSuccess = false` when more sigs than keys remain (:1206).
* **VERIFY variant** (:1217-1223, SCR-120): `fSuccess` ⇒ pop the pushed
  bool; `!fSuccess` ⇒ `SCRIPT_ERR_CHECKMULTISIGVERIFY`.

Stack model (head-of-list = top-of-stack): a `k`-of-`n` multisig step
sees, top-down, `[nKeysCount, key_n … key_1, nSigsCount, sig_k … sig_1,
dummy, …rest]` (research/06 §3.3: bottom→top `dummy sig … pubkey … nSigs
nKeys`). Success consumes `nKeys + nSigs + 3` items and pushes
`vchTrue`/`vchFalse`; the op budget pays `nKeys` inside `checkMultiSig`
on top of the opcode's own `+1` (0xae/0xaf > OP_16, :459-463) — a
`stepBody` step charging `k` keys costs `k + 1` total.

Concrete verdicts are cross-checked against a faithful python3 port of
the C++ case (`xcheck.py`, run 2026-10-16; python's
`op_count_in` models the state AFTER the opcode's own +1): 0-of-0 with a
nonzero dummy under default flags ⇒ OK, dummy consumed unchecked; 1-of-1
with the stub checker ⇒ OK `vchTrue`; empty signature ⇒ `fSuccess =
false`, verdict `vchFalse`, NO error; the same under CHECKMULTISIGVERIFY
⇒ `CHECKMULTISIGVERIFY`; NULLDUMMY + nonzero dummy ⇒ `SIG_NULLDUMMY`
(empty dummy ⇒ OK); 1-of-1 without the dummy (arity `nKeys+nSigs+2`) ⇒
`INVALID_STACK_OPERATION`; `181+1+20 = 202 > 201` ⇒ `OP_COUNT` (and
`180+1+20 = 201` passes the budget, then fails arity); `PUBKEY_COUNT`
for `-1` and `21`; `SIG_COUNT` for `2 > 1`; tapscript ban; empty-stack
underflow. All theorems are sorry-free.
-/

namespace BitcoinProofs.Theorems.Ops.O09

open Bitcoin.Interpreter Bitcoin.Data Bitcoin.Numeric Bitcoin.Script.Parser

/-! ## Shared fixtures -/

/-- A minimal `.base` context: consensus flags and policy both at their
DoTest defaults (all `false`), stub checker, empty script bytes. -/
def ctx0 : Ctx where
  flags := {}
  pol := {}
  chk := default
  sv := .base
  bytes := ByteArray.empty
  ed := {}

/-- OP_CHECKMULTISIG as a wire op (0xae). -/
def opCMS : WireOp := { ast := .op ⟨0xae, by decide⟩, wire := 0xae, next := 0 }
/-- OP_CHECKMULTISIGVERIFY as a wire op (0xaf). -/
def opCMSV : WireOp := { ast := .op ⟨0xaf, by decide⟩, wire := 0xaf, next := 0 }

/-- The default `State`. -/
def st0 : State where
  stack := []
  alt := []
  vf := []
  opCount := 0
  codeSep := 0
  vwLeft := none

/-- Canonical CScriptNum wire encoding (`getvch`; 0 ⇒ empty). -/
def enc (n : Int) : ByteArray := encodeScriptNum n false

/-- Neither CMS opcode is in the disabled table (interpreter.cpp:447-467). -/
theorem hdisCMS : disabledWire 0xae = false := by decide
theorem hdisCMSV : disabledWire 0xaf = false := by decide

/-! ## Failure modes — exact precondition-implications (checkMultiSig level) -/

/-- **Tapscript ban** (interpreter.cpp:1115, SCR-121): under
`SigVersion::TAPSCRIPT` OP_CHECKMULTISIG fails immediately, before any
stack access — BIP342 replaces it with OP_CHECKSIGADD. -/
theorem cms_tapscript_banned (ctx : Ctx) (st : State) (w : Nat) :
    stepBody.checkMultiSig { ctx with sv := .tapscript } w st
      = .error .tapscriptCheckMultiSig := by
  simp [stepBody.checkMultiSig]

/-- **Empty stack** (interpreter.cpp:1119-1121): with `stack.size() < i = 1`
the key-count read fails — the first of the three depth checks. -/
theorem cms_empty_stack (ctx : Ctx) (st : State)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (h : st.stack = []) :
    stepBody.checkMultiSig ctx 0xae st = .error .stackUnderflow := by
  simp [stepBody.checkMultiSig, hsv, h]

/-- **PUBKEY_COUNT** (interpreter.cpp:1122-1124, SCR-114): the key count
is decoded from the top with the 4-byte minimal CScriptNum ctor; out of
`[0, MAX_PUBKEYS_PER_MULTISIG]` ⇒ exactly this error. -/
theorem cms_pubKeyCount (ctx : Ctx) (st : State) (nkv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hcond : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = true) :
    stepBody.checkMultiSig ctx 0xae st = .error .pubKeyCount := by
  simp [stepBody.checkMultiSig, hsv, hne0, hd, hcond]

/-- **OP_COUNT = the sigop budget** (interpreter.cpp:1128-1130): the
pubkey count is charged wholesale, `nOpCount += nKeysCount`, against the
201-op limit — the per-opcode sigop-counting rule (one unit per pubkey),
on top of the opcode's own charge (SCR-022 / :459-463). -/
theorem cms_opCount (ctx : Ctx) (st : State) (nkv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hcond : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = true) :
    stepBody.checkMultiSig ctx 0xae st = .error .opCount := by
  simp [stepBody.checkMultiSig, hsv, hne0, hd, hrange, hcond]

/-- **SIG_COUNT** (interpreter.cpp:1132-1137, SCR-114): the signature
count is read at depth `nKeys + 2` and must lie in `[0, nKeysCount]`. -/
theorem cms_sigCount (ctx : Ctx) (st : State) (nkv nsv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hcond : (nsv < 0 ∨ max (nkv : Int) 0 < nsv) = true) :
    stepBody.checkMultiSig ctx 0xae st = .error .sigCount := by
  simp [stepBody.checkMultiSig, hsv, hne0, hd1, hrange, hop, hlen2, hd2, hcond]

/-- **The off-by-one depth check** (interpreter.cpp:1141-1143): after both
counts decode in range, the stack must hold `nKeys + nSigs + 3` items —
the `nKeys + nSigs + 2` "real" arguments PLUS the unchecked dummy. This
is the exact precondition under which the historical off-by-one bites:
a stack holding every *semantically* required element still fails. -/
theorem cms_underflow_no_dummy (ctx : Ctx) (st : State) (nkv nsv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hne0 : st.stack ≠ [])
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok nsv)
    (hrange2 : (nsv < 0 ∨ max (nkv : Int) 0 < nsv) = false)
    (hcond : (st.stack.length < nkv.toNat + nsv.toNat + 3) = true) :
    stepBody.checkMultiSig ctx 0xae st = .error .stackUnderflow := by
  simp [stepBody.checkMultiSig, hsv, hne0, hd1, hrange, hop, hlen2, hd2,
    hrange2, hcond]

/-! ## The dummy: the cleanup pops exactly `nKeys + nSigs + 2`, unchecked -/

/-- Head-of-`drop` bridging: `(l.drop k)[0]! = l[k]!` — the element the
NULLDUMMY gate inspects after the cleanup pops is the dummy at depth
`nKeys + 2` of the original stack. -/
theorem getElem!_drop_zero {l : List ByteArray} (k : Nat) :
    (l.drop k)[0]! = l[k]! := by
  induction k generalizing l with
  | zero => rfl
  | succ k ih =>
    cases l with
    | nil => simp
    | cons a tl => simpa using ih (tl)

/-- `cmsCleanup` (interpreter.cpp:1212-1221) on the success path pops
exactly `i - 1` items and returns `st.drop (i-1)`: by induction on the
fuel each iteration pops one element (`List.tail`) — with
`fSuccess = true` the NULLFAIL gate (`!fSuccess ∧ …`) is inert whatever
the policy word says (SWT-059). `checkMultiSig` calls it with
`i = fuel = nKeys + nSigs + 3`. -/
theorem cmsCleanup_true_eq (pol : PolicyFlags) :
    ∀ (fuel i ikey2 : Nat) (st : Stack), i ≤ fuel → i - 1 ≤ st.length →
      cmsCleanup pol st true i ikey2 fuel = .ok (st.drop (i - 1)) := by
  intro fuel
  induction fuel with
  | zero =>
    intro i ikey2 st hfuel _
    have hi : i = 0 := by omega
    subst hi
    simp [cmsCleanup]
  | succ f ih =>
    intro i ikey2 st hfuel hlen
    rcases st with _ | ⟨a, tl⟩
    · have hle : i ≤ 1 := by
        have h0 : List.length ([] : List ByteArray) = 0 := rfl
        omega
      have hz : i - 1 = 0 := by omega
      simp [cmsCleanup, hle, hz]
    · rcases Nat.lt_or_ge i 2 with hlt | hge
      · have hle : i ≤ 1 := by omega
        have hz : i - 1 = 0 := by omega
        simp [cmsCleanup, hle, hz]
      · have hle : ¬(i ≤ 1) := by omega
        have hf' : i - 1 ≤ f := by omega
        have hlen1 : List.length (a :: tl) = tl.length + 1 := rfl
        have hlen' : (i - 1) - 1 ≤ tl.length := by rw [hlen1] at hlen; omega
        have hrec := ih (i - 1) (if 0 < ikey2 then ikey2 - 1 else ikey2) tl hf' hlen'
        have h2 : (i - 1) - 1 = i - 2 := by omega
        have h1 : i - 1 = (i - 2) + 1 := by omega
        have hk : (a :: tl).drop (i - 1) = tl.drop (i - 2) := by
          rw [h1, List.drop_succ_cons]
        simp [cmsCleanup, hle, hrec, h2, hk, List.tail_cons]

/-! ## Generic ok-path stack effect (0 sigs ⇒ the matching loop trivially succeeds) -/

/-- **Stack effect, success path with `nSigs = 0`** (interpreter.cpp:1113-1225,
SCR-114/118 + SWT-064/065): with the signature count decoding to `0` the
matching loop returns `fSuccess = true` without consulting the checker,
the cleanup pops `nKeys + 2` items (both counts; zero sigs), and the
dummy at depth `nKeys + 2` is popped *unchecked* unless NULLDUMMY demands
it empty. Result: `opCount := opCount + nKeys` (the sigop charge — the
opcode's own `+1` lives in `stepBody`) and stack
`vchTrue :: stack.drop (nKeys + 3)`. -/
theorem cms_ok_zero_sigs (ctx : Ctx) (st : State) (nkv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok 0)
    (hlen3 : (st.stack.length < nkv.toNat + 3) = false)
    (hnd : ctx.flags.nullDummy = false ∨ st.stack[nkv.toNat + 2]?.getD default = ByteArray.empty) :
    stepBody.checkMultiSig ctx 0xae st =
      .ok { st with opCount := st.opCount + nkv.toNat,
                    stack := vchTrue :: st.stack.drop (nkv.toNat + 3) } := by
  have hl3 : ¬(st.stack.length < nkv.toNat + 3) := by rw [hlen3]; simp
  have hne0 : st.stack ≠ [] := by
    intro h
    rw [h] at hl3
    have h0 : List.length ([] : List ByteArray) = 0 := rfl
    omega
  have hcond0 : ¬(max (nkv : Int) 0 < (0 : Int)) :=
    Int.not_lt_of_ge (Int.le_max_right (nkv : Int) 0)
  have hne4 : ¬(List.length st.stack - (nkv.toNat + 2) = 0) := by omega
  have hcl : cmsCleanup ctx.pol st.stack true (nkv.toNat + 3) (nkv.toNat + 2)
      (nkv.toNat + 3) = .ok (st.stack.drop (nkv.toNat + 2)) := by
    have h := cmsCleanup_true_eq ctx.pol (nkv.toNat + 3) (nkv.toNat + 3)
      (nkv.toNat + 2) st.stack (Nat.le_refl _)
      (by omega)
    rw [show nkv.toNat + 3 - 1 = nkv.toNat + 2 from by omega] at h
    exact h
  have hdrop : List.drop (nkv.toNat + 2 + 1) st.stack
      = List.drop (nkv.toNat + 3) st.stack := by
    rw [show nkv.toNat + 2 + 1 = nkv.toNat + 3 from by omega]
  rcases hnd with hnd | hnd
  · simp [stepBody.checkMultiSig, hsv, hd1, hrange, hop, hlen2, hd2, hlen3,
      cmsLoop, hcl, hne0, hcond0, hne4, hnd, pushBoolV, vchTrue, List.tail_drop,
      hdrop]
  · simp [stepBody.checkMultiSig, hsv, hd1, hrange, hop, hlen2, hd2, hlen3,
      cmsLoop, hcl, hne0, hcond0, hne4, hnd, pushBoolV, vchTrue, List.tail_drop,
      hdrop]

/-- **VERIFY variant of the same** (interpreter.cpp:1217-1223, SCR-120):
with `fSuccess = true` OP_CHECKMULTISIGVERIFY additionally pops the
pushed `vchTrue`, so the net effect is a pure `nKeys + nSigs + 3`-pop
(here `nSigs = 0`). -/
theorem cmsv_ok_zero_sigs (ctx : Ctx) (st : State) (nkv : ScriptNum)
    (hsv : (ctx.sv = Bitcoin.Crypto.Seam.SigVersion.tapscript) = false)
    (hd1 : decodeNum ctx.pol (topAt st.stack 1) 4 = .ok nkv)
    (hrange : (nkv < 0 ∨ MAX_PUBKEYS_PER_MULTISIG < nkv) = false)
    (hop : (MAX_OPS_PER_SCRIPT < st.opCount + nkv.toNat) = false)
    (hlen2 : (st.stack.length < nkv.toNat + 2) = false)
    (hd2 : decodeNum ctx.pol (st.stack[nkv.toNat + 1]?.getD default) 4 = .ok 0)
    (hlen3 : (st.stack.length < nkv.toNat + 3) = false)
    (hnd : ctx.flags.nullDummy = false ∨ st.stack[nkv.toNat + 2]?.getD default = ByteArray.empty) :
    stepBody.checkMultiSig ctx 0xaf st =
      .ok { st with opCount := st.opCount + nkv.toNat,
                    stack := st.stack.drop (nkv.toNat + 3) } := by
  have hl3 : ¬(st.stack.length < nkv.toNat + 3) := by rw [hlen3]; simp
  have hne0 : st.stack ≠ [] := by
    intro h
    rw [h] at hl3
    have h0 : List.length ([] : List ByteArray) = 0 := rfl
    omega
  have hcond0 : ¬(max (nkv : Int) 0 < (0 : Int)) :=
    Int.not_lt_of_ge (Int.le_max_right (nkv : Int) 0)
  have hne4 : ¬(List.length st.stack - (nkv.toNat + 2) = 0) := by omega
  have hcl : cmsCleanup ctx.pol st.stack true (nkv.toNat + 3) (nkv.toNat + 2)
      (nkv.toNat + 3) = .ok (st.stack.drop (nkv.toNat + 2)) := by
    have h := cmsCleanup_true_eq ctx.pol (nkv.toNat + 3) (nkv.toNat + 3)
      (nkv.toNat + 2) st.stack (Nat.le_refl _)
      (by omega)
    rw [show nkv.toNat + 3 - 1 = nkv.toNat + 2 from by omega] at h
    exact h
  have hdrop : List.drop (nkv.toNat + 2 + 1) st.stack
      = List.drop (nkv.toNat + 3) st.stack := by
    rw [show nkv.toNat + 2 + 1 = nkv.toNat + 3 from by omega]
  rcases hnd with hnd | hnd
  · simp [stepBody.checkMultiSig, hsv, hd1, hrange, hop, hlen2, hd2, hlen3,
      cmsLoop, hcl, hne0, hcond0, hne4, hnd, pushBoolV, vchTrue, List.tail_drop,
      hdrop]
  · simp [stepBody.checkMultiSig, hsv, hd1, hrange, hop, hlen2, hd2, hlen3,
      cmsLoop, hcl, hne0, hcond0, hne4, hnd, pushBoolV, vchTrue, List.tail_drop,
      hdrop]

/-! ## Concrete verdicts (python3-cross-checked) -/

/-- `OP_CHECKMULTISIG`, 0-of-0 with dummy `[7]` and preserved tail `[9]`
(python A: `ops 0+1+0 = 1`, stack `[01, 09]`): OK — the nonzero dummy is
consumed unchecked (NULLDUMMY off, pre-BIP147). -/
theorem cms_0of0_concrete :
    stepBody ctx0 opCMS { st0 with stack := [enc 0, enc 0, serU8 7, serU8 9] } =
      .ok { st0 with opCount := 1, stack := vchTrue :: [serU8 9] } := by
  rfl

/-- `OP_CHECKMULTISIGVERIFY`, 0-of-0 (python B): OK, net pure 3-pop,
`[09]` preserved. -/
theorem cmsv_0of0_concrete :
    stepBody ctx0 opCMSV { st0 with stack := [enc 0, enc 0, serU8 7, serU8 9] } =
      .ok { st0 with opCount := 1, stack := [serU8 9] } := by
  rfl

/-- `OP_CHECKMULTISIG`, 1-of-1 with stub checker (sig `[5]`, key `[6]`,
dummy `[7]`, tail `[9]`) (python C: `ops 1+1+1 = 2`... python models the
post-`+1` state with `op_count_in = 1`, total 2; stack `[01, 09]`). -/
theorem cms_1of1_concrete :
    stepBody ctx0 opCMS
        { st0 with stack := [enc 1, serU8 6, enc 1, serU8 5, serU8 7, serU8 9] } =
      .ok { st0 with opCount := 2, stack := vchTrue :: [serU8 9] } := by
  simp [stepBody, stepBody.dispatchOp, stepBody.checkMultiSig, cmsLoop, cmsCleanup,
    opCMS, hdisCMS, ctx0, st0, enc, vchTrue, MAX_OPS_PER_SCRIPT,
    MAX_PUBKEYS_PER_MULTISIG] <;> rfl

/-- `OP_CHECKMULTISIGVERIFY`, 1-of-1 (python D): OK, all five arguments
consumed, `[09]` preserved. -/
theorem cmsv_1of1_concrete :
    stepBody ctx0 opCMSV
        { st0 with stack := [enc 1, serU8 6, enc 1, serU8 5, serU8 7, serU8 9] } =
      .ok { st0 with opCount := 2, stack := [serU8 9] } := by
  simp [stepBody, stepBody.dispatchOp, stepBody.checkMultiSig, cmsLoop, cmsCleanup,
    opCMSV, hdisCMSV, ctx0, st0, enc, vchTrue, MAX_OPS_PER_SCRIPT,
    MAX_PUBKEYS_PER_MULTISIG] <;> rfl

/-- **Empty signature ⇒ FALSE verdict, not failure** (python E,
SCR-109-adjacent): a 1-of-1 with an empty signature fails the check
(stub checker: `sig.size ≠ 0` is false), the loop early-exits with
`fSuccess = false`, and OP_CHECKMULTISIG pushes `vchFalse` — the script
continues. -/
theorem cms_falsesig_concrete :
    stepBody ctx0 opCMS
        { st0 with stack := [enc 1, serU8 6, enc 1, ByteArray.empty, serU8 7] } =
      .ok { st0 with opCount := 2, stack := vchFalse :: [] } := by
  simp [stepBody, stepBody.dispatchOp, stepBody.checkMultiSig, cmsLoop, cmsCleanup,
    opCMS, hdisCMS, ctx0, st0, enc, vchFalse, MAX_OPS_PER_SCRIPT,
    MAX_PUBKEYS_PER_MULTISIG] <;> rfl

/-- Same under **OP_CHECKMULTISIGVERIFY** (python E', SCR-120):
`fSuccess = false` ⇒ `SCRIPT_ERR_CHECKMULTISIGVERIFY`. -/
theorem cmsv_falsesig_concrete :
    stepBody ctx0 opCMSV
        { st0 with stack := [enc 1, serU8 6, enc 1, ByteArray.empty, serU8 7] } =
      .error .checkMultiSigVerify := by
  simp [stepBody, stepBody.dispatchOp, stepBody.checkMultiSig, cmsLoop, cmsCleanup,
    opCMSV, hdisCMSV, ctx0, st0, enc, MAX_OPS_PER_SCRIPT,
    MAX_PUBKEYS_PER_MULTISIG] <;> rfl

/-- **NULLDUMMY** (python F/F', BIP147, SWT-064): with the consensus
post-SegWit flag, a nonzero dummy ⇒ `SIG_NULLDUMMY`; the empty dummy
passes and yields the normal verdict. -/
theorem cms_nulldummy_concrete :
    stepBody { ctx0 with flags := { nullDummy := true } } opCMS
        { st0 with stack := [enc 0, enc 0, serU8 7] } = .error .sigNullDummy ∧
    stepBody { ctx0 with flags := { nullDummy := true } } opCMS
        { st0 with stack := [enc 0, enc 0, ByteArray.empty] } =
      .ok { st0 with opCount := 1, stack := [vchTrue] } := by
  constructor <;> rfl

/-- **The off-by-one, concretely** (python G): a 1-of-1 whose stack holds
all `nKeys + nSigs + 2 = 4` semantically required items but no dummy
fails with `INVALID_STACK_OPERATION` — the dummy is a 5th, unchecked
slot. -/
theorem cms_off_by_one_concrete :
    stepBody ctx0 opCMS { st0 with stack := [enc 1, serU8 6, enc 1, serU8 5] } =
      .error .stackUnderflow := by
  rfl

/-- **Sigop budget boundary** (python H/H', interpreter.cpp:1128-1130):
a 20-key count charges 20 units; `181 + 1 + 20 = 202 > 201` ⇒
`OP_COUNT`, while `180 + 1 + 20 = 201` passes the budget — and then
fails the arity check (depth `nKeys + 2 = 22` needed). -/
theorem cms_sigops_boundary_concrete :
    stepBody ctx0 opCMS { st0 with opCount := 181, stack := [serU8 20] } =
      .error .opCount ∧
    stepBody ctx0 opCMS { st0 with opCount := 180, stack := [serU8 20] } =
      .error .stackUnderflow := by
  constructor <;> rfl

/-- **Count-range failures + tapscript ban + empty stack** (python
I/J/J'/K/L): `SIG_COUNT` for `2 > 1`; `PUBKEY_COUNT` for `-1` (wire
`0x81`) and `21`; `TAPSCRIPT_CHECKMULTISIG` under tapscript;
`INVALID_STACK_OPERATION` on the empty stack. -/
theorem cms_counts_concrete :
    stepBody ctx0 opCMS { st0 with stack := [enc 1, ByteArray.empty, enc 2] } =
      .error .sigCount ∧
    stepBody ctx0 opCMS { st0 with stack := [serU8 0x81] } = .error .pubKeyCount ∧
    stepBody ctx0 opCMS { st0 with stack := [serU8 21] } = .error .pubKeyCount ∧
    stepBody { ctx0 with sv := .tapscript } opCMS
        { st0 with stack := [enc 0, enc 0, serU8 7] } =
      .error .tapscriptCheckMultiSig ∧
    stepBody ctx0 opCMS st0 = .error .stackUnderflow := by
  refine ⟨rfl, rfl, rfl, rfl, rfl⟩

/-! ## Axiom pins (sorry-free; Classical.choice only where the full-simp
concrete proofs normalize through the default simp set — same footprint
pattern as O07's step-level theorems) -/

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_tapscript_banned' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_tapscript_banned

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_empty_stack' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_empty_stack

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_pubKeyCount' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_pubKeyCount

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_opCount' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_opCount

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_sigCount' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_sigCount

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_underflow_no_dummy' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_underflow_no_dummy

/-- info: 'BitcoinProofs.Theorems.Ops.O09.getElem!_drop_zero' depends on axioms: [propext] -/
#guard_msgs (whitespace := lax) in #print axioms getElem!_drop_zero

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cmsCleanup_true_eq' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cmsCleanup_true_eq

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_ok_zero_sigs' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_ok_zero_sigs

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cmsv_ok_zero_sigs' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cmsv_ok_zero_sigs

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_0of0_concrete' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_0of0_concrete

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cmsv_0of0_concrete' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cmsv_0of0_concrete

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_1of1_concrete' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_1of1_concrete

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cmsv_1of1_concrete' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cmsv_1of1_concrete

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_falsesig_concrete' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_falsesig_concrete

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cmsv_falsesig_concrete' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cmsv_falsesig_concrete

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_nulldummy_concrete' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_nulldummy_concrete

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_off_by_one_concrete' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_off_by_one_concrete

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_sigops_boundary_concrete' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_sigops_boundary_concrete

/-- info: 'BitcoinProofs.Theorems.Ops.O09.cms_counts_concrete' depends on axioms: [propext, Quot.sound] -/
#guard_msgs (whitespace := lax) in #print axioms cms_counts_concrete

end BitcoinProofs.Theorems.Ops.O09
