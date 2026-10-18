import Lean

/-!
# The `rule` traceability attribute

Every Lean declaration that implements (or will implement) a rule-DB row
carries `@[rule "XXX-nnn"]`. The attribute payload is the rule ID from
`spec/db/rules.yaml`; `scripts/rule_crosscheck.py` enforces
`@[rule]` ↔ YAML ↔ Core-anchor consistency in CI (a repository invariant,
D1 traceability design, seL4-style pinned-source discipline).

This is a real kernel-side parametric attribute (payload stored in the
environment extension and exported with the module), NOT a comment
convention — so the cross-check reads ground truth from the `.lean`
sources, not from docstrings.

This file is frozen; it must not be edited without an
interface-change PR.
-/

open Lean

/-- Attribute syntax: `@[rule "SCR-001"]` (string literal = rule ID). -/
syntax (name := ruleAttr) "rule" ppSpace str : attr

initialize ruleAttrImpl : ParametricAttribute String ← registerParametricAttribute {
  name := `ruleAttr
  descr := "traceability: marks a declaration as implementing a rule-DB row (payload = rule ID)"
  getParam := fun _decl stx => do
    match stx[1].isStrLit? with
    | some s => pure s
    | none => throwError "expected @[rule \"RULE-ID\"] with a string literal"
}
