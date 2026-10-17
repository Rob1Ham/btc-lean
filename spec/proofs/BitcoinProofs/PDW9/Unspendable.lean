import Bitcoin.Ledger.Interface
import Bitcoin.Data.Script

/-!
# PDW9/Unspendable — BLK-094 + SCR-070 promotion (route B)

PDW9 (proof-promotion review 5), recovery review 5 (RC5), 2026-10-17.
Rows BLK-094 + SCR-070 (TOP-41..45 claim `1c53f09`):
`CScript::IsUnspendable()` (script/script.h:564-567) — the two
unspendable-script classification faces.

Route B (RC03-4 B-vehicle): both rows' tags sit on the core
*definition* `Bitcoin.Ledger.scriptUnspendable`
(Ledger/Interface.lean:100, `@[rule "INV-112", "BLK-094",
"SCR-070"]` — INV-112 = W12's pre-existing tag, BLK-094/SCR-070 =
X08-Added) — tag-on-def tagdebt. Promotion = this file's sorry-free
theorems, my `@[rule]` tags, zero core edits.

- `scriptUnspendable_of_opReturn` (THE BLK-094 vehicle): the
  OP_RETURN face — first byte `0x6a` on a nonempty script ⇒
  `scriptUnspendable s = true` (`simp [scriptUnspendable, h, h2]`
  through the `&&`-short-circuit def).
- `scriptUnspendable_of_oversize` (THE SCR-070 vehicle): the
  size face — `s.bytes.size > MAX_SCRIPT_SIZE` (= 10000,
  script.h) ⇒ `scriptUnspendable s = true` (the `||`-second
  disjunct).
- `scriptUnspendable_eq_true_iff`: the full iff — the def is
  exactly the disjunction of the two faces.
- `scriptUnspendable_empty`: the Core-faithful empty-script fact
  — `scriptUnspendable Script.empty = **false**`.

**Letter-drift (F-RM-04 class, recorded not fixed)**: row BLK-094's
check text says "script **empty** or first byte OP_RETURN ⇒
unspendable", but Core's (and the Lean port's) `IsUnspendable` is
`size > 0 && first == OP_RETURN` — an *empty* script is NOT
unspendable (it has no first byte to test). `scriptUnspendable_empty`
pins the def's actual (Core-faithful) behavior; the row text is the
spec-letter drift, documented in findings-af/PDW9.md (F-PDW9-002).

**lean_target name-drift (F-PDW11-004 class)**: rules.yaml
BLK-094/SCR-070 lean_targets spelled `Bitcoin.Ledger.
scriptUnspendable` / `Bitcoin.Ledger.Interface.
scriptUnspendable` (spelling variant); both are repointed to this
file's tagged theorems at the flip (drift thereby moot).

Core-only imports (root-env elaborable, `cd spec && lake env lean
proofs/BitcoinProofs/PDW9/Unspendable.lean`, direct-lean
RC05/PDW11Check route). Additive module, not imported by anything.

Axiom pins (house style: bare `#print axioms`, info-level only,
B07/RC03/PDW10Guards discipline); footprints in findings-af/PDW9.md
v2; all ⊆ the charter trio `[propext, Classical.choice,
Quot.sound]`, zero `sorryAx`.
-/

namespace BitcoinProofs.PDW9
open Bitcoin.Data Bitcoin.Ledger

/-- **BLK-094 vehicle**: the OP_RETURN face — a nonempty script
whose first byte is `0x6a` is unspendable (script.h:566
`(script.size() > 0 && script[0] == OP_RETURN)`; `simp` through the
Bool `&&`-short-circuit port). -/
@[rule "BLK-094"]
theorem scriptUnspendable_of_opReturn {s : Script}
    (h : 0 < s.bytes.size) (h2 : s.bytes.get! 0 = 0x6a) :
    scriptUnspendable s = true := by
  simp [scriptUnspendable, h, h2]

/-- **SCR-070 vehicle**: the size face — a script larger than
`MAX_SCRIPT_SIZE` (10000) is unspendable (script.h:567
`sz > MAX_SCRIPT_SIZE`). -/
@[rule "SCR-070"]
theorem scriptUnspendable_of_oversize {s : Script}
    (h : s.bytes.size > MAX_SCRIPT_SIZE) :
    scriptUnspendable s = true := by
  simp [scriptUnspendable, h]

/-- The full iff: `scriptUnspendable` is exactly the disjunction of
the OP_RETURN face and the oversize face (the def's propositional
content). Tagged BLK-094: this is the *narrowed* row semantics — the
OP_RETURN face requires a nonempty script. -/
@[rule "BLK-094"]
theorem scriptUnspendable_eq_true_iff {s : Script} :
    scriptUnspendable s = true ↔
      ((0 < s.bytes.size ∧ s.bytes.get! 0 = 0x6a) ∨ s.bytes.size > MAX_SCRIPT_SIZE) := by
  simp [scriptUnspendable]

/-- Core-faithful empty-script fact (F-PDW9-002 letter-drift pin):
Core's `IsUnspendable` tests `size() > 0 && script[0] == OP_RETURN`
— an **empty** script fails the first conjunct, so it is *not*
unspendable (and it is not oversize either). Tagged BLK-094: the row's
"script empty ⇒ unspendable" letter is the narrowed-away half. -/
@[rule "BLK-094"]
theorem scriptUnspendable_empty : scriptUnspendable Script.empty = false := by
  simp [scriptUnspendable, Script.empty]

end BitcoinProofs.PDW9

#print axioms BitcoinProofs.PDW9.scriptUnspendable_of_opReturn
#print axioms BitcoinProofs.PDW9.scriptUnspendable_of_oversize
#print axioms BitcoinProofs.PDW9.scriptUnspendable_eq_true_iff
#print axioms BitcoinProofs.PDW9.scriptUnspendable_empty
