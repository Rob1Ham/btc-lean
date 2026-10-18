import Bitcoin.Crypto.Taproot.Verify
import Bitcoin.Crypto.Seam.Interface

/-!
# Bitcoin.Crypto.Taproot.LeafDispatch — the BIP341 leaf-version
# dispatch (TPR-A, rows TPR-019 / TPR-020 / TPR-021)

Core `interpreter.cpp:1976-1998` (`VerifyWitnessProgram`, the
script-path arm's TAIL) — everything after the control-block size gate
(:1980-1982), the tapleaf hash (:1983) and
`VerifyTaprootCommitment` (:1985-1987):

    if ((control[0] & TAPROOT_LEAF_MASK) == TAPROOT_LEAF_TAPSCRIPT) {
        execdata.m_script = script;                    // :1988-1993
        ExecuteWitnessScript(..., SigVersion::TAPSCRIPT, ...);
    } else if (flags & SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION) {
        return set_error(... SCRIPT_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION);
                                                       // :1995-1997
    } else {
        return set_success(vstate);                    // :1998 (softfork hook)
    }

Row map (this module):

* **TPR-019** — `control[0]&0xfe == 0xc0` executes the script with
  `SigVersion::TAPSCRIPT` (`interpreter.cpp:1988-1993`;
  `interpreter.h:243` `TAPROOT_LEAF_TAPSCRIPT = 0xc0`): the dispatch
  bit the Taproot module's `scriptPathSpend` (Verify.lean:101) returns as its third
  component `ts = leafVersionOf control = TAPROOT_LEAF_TAPSCRIPT`, and
  `leafVersionSpend` consumes it into the `.tapscript` verdict
  carrying the dispatched script (Core's `execdata.m_script = script`).
* **TPR-020** — non-`0xc0` leaf versions validate as SUCCESS
  (the softfork hook; `interpreter.cpp:1995-1998`'s else arm, BIP341
  §"Script validation" "if the leaf version is 0xc0, ...; otherwise
  the script path succeeds"): the `.success` verdict.
* **TPR-021** — `DISCOURAGE_UPGRADABLE_TAPROOT_VERSION`
  (`interpreter.cpp:1995-1997`): the policy error on the non-0xc0 lane
  (a policy bit — Core's `SCRIPT_VERIFY` word; modeled by the
  `discourageUpgradableTaprootVersion : Bool` parameter, the
  `PolicyFlags` bit of `Bitcoin.Interpreter.Defs:188/210`
  (`polHas "DISCOURAGE_UPGRADABLE_TAPROOT_VERSION"`) — the analogous
  tapscript-side twin of `evalChecksigTapscript`'s
  `pol.discourageUpgradablePubkeyType` (TPR-027)).

## Ordering pinned (vs Core)

The commitment check PRECEDES the leaf-version dispatch
(`:1985-1987` before `:1988`): a control block whose recomputed
output key fails is a `witnessProgramMismatch` reject REGARDLESS of
its leaf version — non-`0xc0` is NOT a commitment bypass
(`leafVersionSpend_commitment_fail` takes `ts` arbitrary). The size
gate (`:1980-1982`) precedes everything (`scriptPathSpend = none`
lane = the Taproot module's `scriptPathSpend_badSize_none`, `Verify.lean:193`).

## Layering / honesty notes

* The composition sits on X03's `scriptPathSpend` (Verify.lean:
  size gate → tapleaf hash → `verifyTaprootCommitment` (X06's
  `outputKeyOk` plus the 32-byte `program = x(Q)` binding, TPR-018) →
  the `0xc0` dispatch bit, in Core's order).
  This module is the CALLER side of the bit: it turns the `if`-chain
  of Core :1988-1998 into a verdict. The tapscript-arm's EXECUTION
  (`ExecuteWitnessScript` at `SigVersion::TAPSCRIPT`) is
  `Bitcoin.Interpreter.executeWitnessScript` (the interpreter delta layer's
  `Script/Tapscript/Delta.lean` theorems; `evalChecksigTapscript` =
  the `EvalChecksigTapScript` tapscript-CHECKSIG deltas = TPR-023
/ TPR-027's lane) — `.tapscript script` carries the dispatched script,
  and TPR-019 pins the DISPATCH (leaf 0xc0 ⇒ the tapscript lane), not
  the execution verdict. This mirrors the Program.lean/Interpreter
  split (X06's "deliberate layering", Program.lean:32-40).
* `scriptPathSpend`'s `verifyTaprootCommitment` = `checkTapTweak
  control program (some (scriptPathMerkleRoot ...))` (Verify.lean):
  X06/X03's TPR-009/018/016/017/011 chain — internal-key parse → tweak
  recomputation → parity — PLUS the final
  `xonly_pubkey_tweak_add_check` q-equality of Core
  `pubkey.cpp:255-271` as a 32-byte length check and
  `program = x(Q)` byte comparison. The earlier program-blind
  simplification (F-TPRA-002 / SCR-147 gap) is closed. The dispatch
  rows (TPR-019/020/021) sit strictly AFTER this check, and the
  precedence order is exact.
* `verifyWitnessProgram` (W09's `Bitcoin.Interpreter.Defs:1196`) —
  the interpreter-side twin — currently returns `.unjudged` at the
  tapleaf/CheckTapTweak step (the interpreter rule layer's SCR-146 honesty): THIS module is
  the Crypto-side closure of the dispatch half.
* The module imports `Bitcoin.Crypto.Seam.Interface` for `SigVersion`
  (the frozen seam, `Interface.lean:115-118`): the first
  Taproot-lane file to reference it (no cycle — the seam imports only
  `Data.Basic/Data.Tx/Seam.Hash`). It is NOT consumed in a definition
  (the `.tapscript` constructor IS the mode pin); it is used in the
  `execSigVersion` characterization of TPR-019 below.

Conformance: `Test/Crypto/TaprootLeafTest.lean` — NO official BIP341
script-path SPEND vectors exist (the Taproot module's TaprootVerifyTest honesty); the
harness anchors the dispatch on the official wallet-vector corpus's
own leaf-version cases (case 1 single-leaf 0xc0 → `.tapscript`; case 3
— the two-leaf tree carrying the 0xfa future-version leaf →
`.success`/`.discouraged`), with control blocks derived in-corpus
(leaf version ‖ x(P) ‖ the sibling path) and programs = the official
scriptPubKeys; reject cases = wrong-parity commitment and the 34-byte
size gate. Independent mirror: `taproot_leaf_crosscheck.py`.

No `sorry`, no `native_decide`; axiom pins at the bottom, footprints ⊆
the standard trio `[propext, Classical.choice, Quot.sound]`.
-/

namespace Bitcoin.Crypto.Taproot.LeafDispatch

open Bitcoin.Crypto.Taproot.Verify (scriptPathSpend)
open Bitcoin.Crypto.Taproot.Program (leafVersionOf TAPROOT_LEAF_TAPSCRIPT)
open Bitcoin.Crypto.Seam (SigVersion)

/-! ## The constants (interpreter.h:242-243) -/

/-- `TAPROOT_LEAF_MASK` (interpreter.h:242) = `0xfe` — the low bit of
the control byte is the output-key parity (TPR-011, the tweak lane),
the top 7 bits are the leaf version. The witness-structure module's `leafVersionOf` (TPR-010,
Program.lean:449) applies the mask; the constant is restated here for
the row anchor (`:1988`'s `(control[0] & TAPROOT_LEAF_MASK)`). -/
def TAPROOT_LEAF_MASK : Nat := 0xfe

/-- The mask fixes `TAPROOT_LEAF_TAPSCRIPT`: `0xc0 & 0xfe = 0xc0`
(the tapscript leaf version is even — the masked comparison of Core
:1988 and `leafVersionOf control = TAPROOT_LEAF_TAPSCRIPT`
(Verify.lean:101) are the same test). -/
theorem TAPROOT_LEAF_TAPSCRIPT_masked :
    TAPROOT_LEAF_TAPSCRIPT &&& TAPROOT_LEAF_MASK = TAPROOT_LEAF_TAPSCRIPT := by
  decide

/-! ## The verdict shapes (Core :1980-1998's if-chain) -/

/-- The script-path-arm verdict Core's `:1988-1998` if-chain produces
(see also `TaprootLeafError` for the reject paths into `:1988`). -/
inductive LeafVerdict where
  /-- TPR-019 (Core :1988-1993): masked leaf version `0xc0` —
  `execdata.m_script = script` and the script executes with
  `SigVersion::TAPSCRIPT` (the execution lane). -/
  | tapscript (script : ByteArray)
  /-- TPR-020 (Core :1998): non-`0xc0` leaf version — the script-path
  spend VALIDATES AS SUCCESS, the softfork hook (BIP341 §"Script
  validation"). -/
  | success
  /-- TPR-021 (Core :1995-1997): non-`0xc0` leaf version with the
  `SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` policy bit. -/
  | discouraged
  deriving Repr, DecidableEq, BEq

/-- The execution mode each verdict prescribes (Core `:1988` vs
`:1998`): `0xc0` executes the dispatched script at
`SigVersion::TAPSCRIPT`; non-`0xc0` executes nothing (immediate
success) — `.discouraged` = the policy reject of that same
non-`0xc0` lane. TPR-019's "executes script with
`SigVersion::TAPSCRIPT`" in the seam's own mode type. -/
def execSigVersion (v : LeafVerdict) : SigVersion :=
  match v with
  | .tapscript _ => SigVersion.tapscript
  | .success => SigVersion.taproot
  | .discouraged => SigVersion.taproot

/-- The reject modes the dispatch preserves (Core's `set_error`s on
the paths into `:1988`). -/
inductive TaprootLeafError where
  /-- Core :1980-1982 — the control-block size gate (the TPR-009
  `33 + 32m` lattice; the interpreter rule layer's `.taprootWrongControlSize`,
  Interpreter/Defs.lean:1244). The `scriptPathSpend = none` lane. -/
  | taprootControlSize
  /-- Core :1985-1987 — the `VerifyTaprootCommitment` reject (the
  `scriptPathSpend` ok = false lane; Core's
  `SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH` family). -/
  | witnessProgramMismatch
  /-- Core :1995-1997 — `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION`. -/
  | discourageUpgradableTaprootVersion
  deriving Repr, DecidableEq, BEq

/-! ## TPR-019 / TPR-020 / TPR-021 — the dispatch -/

/-- The script-path-arm dispatch (Core `interpreter.cpp:1988-1998`,
composed on the Taproot module's `scriptPathSpend` = the `:1976-1988` prefix):
`none` = the TPR-009 size reject (`:1980-1982`);
`(tl, ok, ts)` = tapleaf hash, the `VerifyTaprootCommitment` verdict
(`:1985-1887`) and the `0xc0` dispatch bit (`:1988`);
`ok = false` = the commitment reject (leaf-version-INDEPENDENT);
`ok = true, ts = true` = `.ok (.tapscript script)` (TPR-019);
`ok = true, ts = false` = the non-`0xc0` lane: the policy error
(TPR-021) or `.ok .success` (TPR-020). -/
@[rule "TPR-019", rule "TPR-020", rule "TPR-021"]
def leafVersionSpend (control script program : ByteArray)
    (discourageUpgradableTaprootVersion : Bool) :
    Except TaprootLeafError LeafVerdict :=
  match scriptPathSpend control script program,
        discourageUpgradableTaprootVersion with
  | none, _ => .error .taprootControlSize
  | some (_tl, false, _ts), _ => .error .witnessProgramMismatch
  | some (_tl, true, true), _ => .ok (.tapscript script)
  | some (_tl, true, false), true =>
      .error .discourageUpgradableTaprootVersion
  | some (_tl, true, false), false => .ok .success

/-! ### Reject paths (precedence pins) -/

/-- The TPR-009 size gate precedes everything (Core :1980-1982): a
control block outside the `33 + 32m` lattice is a
`.taprootControlSize` reject — the `scriptPathSpend = none` lane
(the Taproot module's `scriptPathSpend_badSize_none`). -/
@[rule "TPR-019"]
theorem leafVersionSpend_badSize (control script program : ByteArray)
    (discourage : Bool)
    (h : scriptPathSpend control script program = none) :
    leafVersionSpend control script program discourage
      = .error .taprootControlSize := by
  simp only [leafVersionSpend, h]

/-- The commitment check precedes the dispatch (Core :1985-1987
before :1988) — a failed `VerifyTaprootCommitment` is a
`witnessProgramMismatch` reject regardless of the leaf version: a
non-`0xc0` control byte is NOT a commitment bypass
(`ts` arbitrary in the hypothesis). -/
@[rule "TPR-019"]
theorem leafVersionSpend_commitment_fail (control script program : ByteArray)
    (discourage : Bool) (tl : ByteArray) (ts : Bool)
    (h : scriptPathSpend control script program = some (tl, false, ts)) :
    leafVersionSpend control script program discourage
      = .error .witnessProgramMismatch := by
  simp only [leafVersionSpend, h]

/-! ### TPR-019 — the 0xc0 dispatch -/

/-- TPR-019: an accepted script-path spend (size gate + commitment)
whose masked leaf version is `0xc0` dispatches to the tapscript lane,
CARRYING THE SPENT SCRIPT (Core :1988-1993:
`execdata.m_script = script`; `ExecuteWitnessScript` at
`SigVersion::TAPSCRIPT` — the execution lane). The dispatch
bit is the Taproot module's `scriptPathSpend` third component
(`leafVersionOf control = TAPROOT_LEAF_TAPSCRIPT`,
Verify.lean:101 + `scriptPathSpend_dispatch` :213). -/
@[rule "TPR-019"]
theorem leafVersionSpend_tapscript (control script program : ByteArray)
    (discourage : Bool) (tl : ByteArray)
    (h : scriptPathSpend control script program = some (tl, true, true)) :
    leafVersionSpend control script program discourage
      = .ok (.tapscript script) := by
  simp only [leafVersionSpend, h]

/-- TPR-019 (mode pin): the `.tapscript` verdict executes at
`SigVersion::TAPSCRIPT` — Core `:1988`'s third argument. -/
@[rule "TPR-019"]
theorem leafVersionSpend_tapscript_sigVersion (control script program : ByteArray)
    (discourage : Bool) (tl : ByteArray)
    (h : scriptPathSpend control script program = some (tl, true, true)) :
    (match leafVersionSpend control script program discourage with
      | .ok v => v = .tapscript script ∧ execSigVersion v = SigVersion.tapscript
      | .error _ => False) := by
  rw [leafVersionSpend_tapscript control script program discourage tl h]
  exact ⟨rfl, rfl⟩

/-! ### TPR-020 — non-0xc0 leaves validate as success -/

/-- TPR-020: an accepted script-path spend whose masked leaf version
is NOT `0xc0` validates as SUCCESS — the softfork hook (Core
:1995-1998's else arm; BIP341: future leaf versions are
success-by-construction, the `0xc0`-test at `:1988` being the only
executing lane). Here with the policy bit OFF. -/
@[rule "TPR-020"]
theorem leafVersionSpend_future_success (control script program : ByteArray)
    (discourageUpgradableTaprootVersion : Bool) (tl : ByteArray)
    (h : scriptPathSpend control script program = some (tl, true, false))
    (hpol : discourageUpgradableTaprootVersion = false) :
    leafVersionSpend control script program
      discourageUpgradableTaprootVersion = .ok .success := by
  simp only [leafVersionSpend, h, hpol]

/-! ### TPR-021 — the policy error -/

/-- TPR-021: the same non-`0xc0` accepted lane under the
`SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` policy bit is
the named error (Core :1995-1997) — an optional, non-consensus reject
of upgradable taproot leaf versions. -/
@[rule "TPR-021"]
theorem leafVersionSpend_discouraged (control script program : ByteArray)
    (discourage : Bool) (tl : ByteArray)
    (h : scriptPathSpend control script program = some (tl, true, false))
    (hpol : discourage = true) :
    leafVersionSpend control script program discourage
      = .error .discourageUpgradableTaprootVersion := by
  simp only [leafVersionSpend, h, hpol]

/-! ### Discrimination -/

/-- The `.tapscript` verdict is the 0xc0 lane ONLY: an accepted spend
whose dispatch bit is false never reaches the tapscript lane (TPR-019
↔ TPR-020/021 partition of the accepted non-policy / policy lanes) —
with the policy bit off, `.success` and `.tapscript` are mutually
exclusive on the ts bit. -/
@[rule "TPR-020"]
theorem leafVersionSpend_success_not_tapscript (control script program : ByteArray)
    (discourageUpgradableTaprootVersion : Bool) (tl : ByteArray)
    (h : scriptPathSpend control script program = some (tl, true, false))
    (hpol : discourageUpgradableTaprootVersion = false) :
    leafVersionSpend control script program
      discourageUpgradableTaprootVersion ≠ .ok (.tapscript script) := by
  rw [leafVersionSpend_future_success control script program
      discourageUpgradableTaprootVersion tl h hpol]
  intro hcon
  injection hcon with hver
  exact LeafVerdict.noConfusion hver

/-- Determinism (the modular-arithmetic layer discipline): equal inputs, equal verdicts. -/
theorem leafVersionSpend_congr (control₁ control₂ script₁ script₂
    program₁ program₂ : ByteArray) (pol₁ pol₂ : Bool)
    (h₁ : control₁ = control₂) (h₂ : script₁ = script₂)
    (h₃ : program₁ = program₂) (h₄ : pol₁ = pol₂) :
    leafVersionSpend control₁ script₁ program₁ pol₁
      = leafVersionSpend control₂ script₂ program₂ pol₂ := by
  subst h₁; subst h₂; subst h₃; subst h₄; rfl

/-! ## Axiom footprints (the existing modules' style: `#guard_msgs in #print axioms`)

All sorry-free; footprints ⊆ the standard trio `[propext,
Classical.choice, Quot.sound]`.
-/

/-- info: 'Bitcoin.Crypto.Taproot.LeafDispatch.TAPROOT_LEAF_TAPSCRIPT_masked' depends on axioms: [propext] -/
#guard_msgs in #print axioms TAPROOT_LEAF_TAPSCRIPT_masked

/-- info: 'Bitcoin.Crypto.Taproot.LeafDispatch.leafVersionSpend_badSize' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms leafVersionSpend_badSize

/-- info: 'Bitcoin.Crypto.Taproot.LeafDispatch.leafVersionSpend_commitment_fail' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms leafVersionSpend_commitment_fail

/-- info: 'Bitcoin.Crypto.Taproot.LeafDispatch.leafVersionSpend_tapscript' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms leafVersionSpend_tapscript

/-- info: 'Bitcoin.Crypto.Taproot.LeafDispatch.leafVersionSpend_tapscript_sigVersion' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms leafVersionSpend_tapscript_sigVersion

/-- info: 'Bitcoin.Crypto.Taproot.LeafDispatch.leafVersionSpend_future_success' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms leafVersionSpend_future_success

/-- info: 'Bitcoin.Crypto.Taproot.LeafDispatch.leafVersionSpend_discouraged' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms leafVersionSpend_discouraged

/-- info: 'Bitcoin.Crypto.Taproot.LeafDispatch.leafVersionSpend_success_not_tapscript' depends on axioms: [propext,
 Classical.choice,
 Quot.sound] -/
#guard_msgs in #print axioms leafVersionSpend_success_not_tapscript

/-- info: 'Bitcoin.Crypto.Taproot.LeafDispatch.leafVersionSpend_congr' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms leafVersionSpend_congr

end Bitcoin.Crypto.Taproot.LeafDispatch
