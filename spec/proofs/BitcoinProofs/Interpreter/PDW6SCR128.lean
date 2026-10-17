import Bitcoin.Interpreter.Rules

/-!
# PDW6SCR128 — SCR-128 promotion proofs (CSV requires tx version ≥ 2)

PDW6 (proof-promotion review 6, TOP-26..30), recovery review 3,
2026-10-17. Row SCR-128 (d=2, BIP68/BIP112): `Bitcoin.Interpreter
.checkSequenceDef_version_gate` (Interpreter/Rules.lean:136),
in-tree, `@[rule "SCR-128"]`-tagged THM-on-target row (PD02-22
band). Core anchor: interpreter.cpp:1800-1801
(`GenericTransactionSignatureChecker::CheckSequence`) — BIP68
sequence-lock semantics are undefined for transaction version 1,
and Core FAILS the check (returns false; it does not NOP the
opcode) — the first branch of W09's `checkSequenceDef`
(Defs.lean:264: `if env.txVersion < 2 then false`).

The in-tree gate is the one-way direction (`txVersion < 2 →
checkSequenceDef = false`, by gate-hereding: the `if`-arm is
`rfl`, the other arm contradicts `hneg`). Promotion = the
bound-direction gap-fill (PDW5's `cltv_flag_off` iff-gap-fill
pattern over RC11's one-way `cltv_flag_flow`) + the v1 faces:

- `checkSequenceDef_version_gate_converse` — `= true` certifies
  the version gate is open: `¬ (txVersion < 2)`.
- `checkSequenceDef_true_ge2` — the ≥-form: `= true → 2 ≤
  txVersion` (via `Int32.not_lt`).
- `checkSequenceDef_v1_false` — the v1 pin: version-1
  transactions fail the check unconditionally (BIP68 undefined
  ⇒ FAIL, not NOP).
- `checkSequenceDef_v1_true_elim` — the elimination face: a
  version-1 tx with a passing CheckSequence is absurd.

Names (F-RM-01): rules.yaml's `lean_target` reads
`Bitcoin.Interpreter.Rules.checkSequenceDef_version_gate` —
`Rules` is the MODULE name; the file's namespace is
`Bitcoin.Interpreter` (Rules.lean:34). The decl is elaborated as
`Bitcoin.Interpreter.checkSequenceDef_version_gate` (verified by
`#check`); the yaml target is a verbatim-name drift recorded in
the OVERRIDES note, not changed here (crosscheck binds by tag-id
and verbatim target, not by resolution).

Axiom-pinned in-file (D2 L3), zero sorryAx; the in-tree gate,
the def, the converse and both v1 decls are `[propext]` exactly
(PDW5's cltv_flag_off first-try class); `checkSequenceDef_true_ge2`
adds `Int32.not_lt`'s full set ([propext, Classical.choice,
Quot.sound] — p6e-probed). Unregistered in
BitcoinProofs.lean (warzone convention: direct-lean verified,
invisible to the default build).
-/

namespace BitcoinProofs.Interpreter.PDW6

/-- SCR-128 (converse / bound direction): a passing
`checkSequenceDef` certifies the version gate was open — the
transaction is not version-1 (BIP68 defined). Contrapositive of
the in-tree one-way gate: had `txVersion < 2` held, the gate
would have forced `= false`. -/
@[rule "SCR-128"]
theorem checkSequenceDef_version_gate_converse
    (env : Bitcoin.Interpreter.LocktimeEnv)
    (n : Bitcoin.Numeric.ScriptNum)
    (h : Bitcoin.Interpreter.checkSequenceDef env n = true) :
    ¬ (env.txVersion < 2) := by
  intro hlt
  rw [Bitcoin.Interpreter.checkSequenceDef_version_gate env n hlt] at h
  exact Bool.noConfusion h

/-- SCR-128 (≥-form): `= true` implies `2 ≤ txVersion` — the
BIP68/BIP112 version requirement in its inclusive form
(`Int32.not_lt` transports the def's own `<`-comparison). -/
@[rule "SCR-128"]
theorem checkSequenceDef_true_ge2
    (env : Bitcoin.Interpreter.LocktimeEnv)
    (n : Bitcoin.Numeric.ScriptNum)
    (h : Bitcoin.Interpreter.checkSequenceDef env n = true) :
    2 ≤ env.txVersion :=
  Int32.not_lt.mp (checkSequenceDef_version_gate_converse env n h)

/-- SCR-128 (v1 pin): BIP68 sequence-lock semantics are undefined
for transaction version 1; Core FAILS the check (does not NOP) —
`checkSequenceDef` is `false` unconditionally in `n` at version
1. (The DISABLE_FLAG short-circuit never runs: the version gate
is `checkSequenceDef`'s first branch.) -/
@[rule "SCR-128"]
theorem checkSequenceDef_v1_false
    (env : Bitcoin.Interpreter.LocktimeEnv)
    (n : Bitcoin.Numeric.ScriptNum)
    (h1 : env.txVersion = 1) :
    Bitcoin.Interpreter.checkSequenceDef env n = false := by
  have hlt : env.txVersion < 2 := by rw [h1]; decide
  exact Bitcoin.Interpreter.checkSequenceDef_version_gate env n hlt

/-- SCR-128 (v1 elimination): a version-1 transaction with a
passing `CheckSequence` is absurd — the version gate forces
`= false`. -/
@[rule "SCR-128"]
theorem checkSequenceDef_v1_true_elim
    (env : Bitcoin.Interpreter.LocktimeEnv)
    (n : Bitcoin.Numeric.ScriptNum)
    (h1 : env.txVersion = 1)
    (h : Bitcoin.Interpreter.checkSequenceDef env n = true) :
    False := by
  have hlt : env.txVersion < 2 := by rw [h1]; decide
  rw [Bitcoin.Interpreter.checkSequenceDef_version_gate env n hlt] at h
  exact Bool.noConfusion h

/-! ### Axiom pins (D2 L3)

Expected messages as docstrings on the guards; the in-tree gate,
the def, and all four promotion decls are `[propext]`, zero
sorryAx. -/

/-- info: 'Bitcoin.Interpreter.checkSequenceDef' depends on axioms: [propext] -/
#guard_msgs in
#print axioms Bitcoin.Interpreter.checkSequenceDef

/-- info: 'Bitcoin.Interpreter.checkSequenceDef_version_gate' depends on axioms: [propext] -/
#guard_msgs in
#print axioms Bitcoin.Interpreter.checkSequenceDef_version_gate

/-- info: 'BitcoinProofs.Interpreter.PDW6.checkSequenceDef_version_gate_converse' depends on axioms: [propext] -/
#guard_msgs in
#print axioms checkSequenceDef_version_gate_converse

/-- info: 'BitcoinProofs.Interpreter.PDW6.checkSequenceDef_true_ge2' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in
#print axioms checkSequenceDef_true_ge2

/-- info: 'BitcoinProofs.Interpreter.PDW6.checkSequenceDef_v1_false' depends on axioms: [propext] -/
#guard_msgs in
#print axioms checkSequenceDef_v1_false

/-- info: 'BitcoinProofs.Interpreter.PDW6.checkSequenceDef_v1_true_elim' depends on axioms: [propext] -/
#guard_msgs in
#print axioms checkSequenceDef_v1_true_elim

end BitcoinProofs.Interpreter.PDW6
