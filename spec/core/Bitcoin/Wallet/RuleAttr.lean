import Lean

/-!
# The `walletRule` traceability attribute

Wallet declarations that target a row in `spec/db/rules-wallet.yaml` carry
`@[walletRule "DESC-001"]`. The payload is the row ID. This is a real
parametric attribute: the string is stored in the module's environment
extension and survives into the exported `.olean`, so the wallet
cross-check reads it from elaborated ground truth rather than from a
docstring convention.

The capital `R` is deliberate. The consensus cross-check scans the *raw
text* of every file under `spec/core/` and `spec/proofs/` with a
case-sensitive pattern for the lowercase consensus attribute
(`spec/scripts/rule_crosscheck.py:22`). A wallet tag written with that
lowercase spelling would be collected as a consensus tag, fail to resolve
in `rules.yaml`, and report an orphan attribute. Keeping the wallet
spelling distinct — `walletRule`, never the consensus name — makes the two
databases disjoint at the lexical level as well as in the YAML.

This module registers the attribute only. It does not validate that the
payload names an existing wallet row, does not reject duplicate tags, and
does not connect a declaration to a proof obligation. Those checks live
in `spec/scripts/wallet_crosscheck.py`; the attribute itself is a storage
mechanism, not an enforcement mechanism.

## What is not modelled

The payload is an uninterpreted `String`: no namespace whitelist, no
numeric range check, no link to `rules-wallet.yaml` at elaboration time,
and no guarantee that a tagged declaration proves the row's statement.
The attribute does not distinguish `theorem` from `def` or `instance`, and
it does not participate in the consensus rule namespace. Nothing here is a
consensus rule or a consensus-tree dependency.
-/

open Lean

/-- Attribute syntax: `@[walletRule "DESC-001"]` (string literal = wallet
row ID). The name differs from the consensus `rule` attribute so the
consensus scanner does not mistake wallet tags for consensus rows. -/
syntax (name := walletRuleAttr) "walletRule" ppSpace str : attr

initialize walletRuleAttrImpl : ParametricAttribute String ← registerParametricAttribute {
  name := `walletRuleAttr
  descr := "wallet traceability: marks a declaration as targeting a rules-wallet.yaml row (payload = row ID)"
  getParam := fun _decl stx => do
    match stx[1].isStrLit? with
    | some s => pure s
    | none => throwError "expected @[walletRule \"ID\"] with a string literal"
}
