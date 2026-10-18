import Bitcoin.Crypto.Taproot.Program

/-! # PDW25.lean — RC22, items TOP-121..125
(PDW25, RC22, 2026-10-17; claim v1 = `6ff8ca6`).

Five sorry-free promotion theorems (11 theorems / 5 rows), one per
claimed rules.yaml row — the D-TPRPRG c-true thm+attr+flip five of
`spec/core/Bitcoin/Crypto/Taproot/Program.lean` (X06 program-lane):

* **TPR-001** `p2trProgram`/`isPayToTaproot` (Program.lean:60/:67) →
  `p2trProgram_eq` (P9 recognition-template def-mirror, the
  decide-coercion face; script.cpp:241-246) +
  `isPayToTaproot_p2trScript_iff` (P2 round-trip: the `OP_1 <32B>`
  wallet-constructor output is P2TR iff a 32-byte program).
* **TPR-002** `taprootLane` (Program.lean:128) →
  `taprootLane_gate_off` (P11 flag-off: without
  SCRIPT_VERIFY_TAPROOT the v1-32-native spend is not routed to
  the taproot lane = Core's `set_success`, interpreter.cpp:1959) +
  `taprootLane_true_iff` (P11: an exact characterization — the lane is
  entered iff the flag is on, the version is 1, the program is 32 bytes
  and the spend is native; no policy input). The earlier
  `taprootLane_consensus_pure` congruence only restated equal inputs ⇒
  equal outputs and is replaced by this characterization.
* **TPR-005** `isAnnex` (Program.lean:219) → `isAnnex_def`
  (P2 def-mirror: ≥2 items ∧ last nonempty ∧ last[0]=0x50,
  interpreter.cpp:1961-1969) + `isAnnex_empty_stack` +
  `isAnnex_one_item` (the arity rejects = the BIP341 "at least two
  witness elements" guard).
* **TPR-007** `classifySpend` (Program.lean:325) →
  `classifySpend_one_keyPath` (P2 key-path: exactly 1 post-annex
  element = the single BIP340 signature against the output key q,
  interpreter.cpp:1970-1975) +
  `classifySpend_annex_pop_keyPath` (the annex is popped BEFORE
  the arity test = Core SpanPopBack:1966-1969).
* **TPR-008** `classifySpend` (same stacked site) →
  `classifySpend_many_scriptPath` (P2 script-path: ≥2 elements,
  last = control block, second-to-last = script,
  interpreter.cpp:1976-1979) +
  `classifySpend_annex_pop_scriptPath` (the 3-raw-items annex
  case).

Statements = the in-tree green theorems of the home file verbatim
(S-statement-grade, sorry-free, axiom-pinned in-tree); proofs RIDE
the core twins (the PDW14 F-PDW14-001 re-proof-rides-core pattern,
NO weakening) or are decide-coercion `rfl` def-mirrors (the PDW16
`compactTarget_eq` class). Probe = PDW25/p1.lean (11 examples,
RC=0) + PDW25/q.lean (4 coercion-shape probes, RC=0).

Route B (PDW11/PDW12/PDW15/PDW16 pattern): ZERO core writes, tags
`@[rule "row"]` ride THESE theorems (the core tag-sites on the
DEFS :60/:67/:128/:219/:325 stay untouched = the F-PDW16-001
tag/target split-repair class); module deliberately NOT imported
by the `BitcoinProofs` root (PDW12-isolation pattern) — own-target
built, outside `core/**` (sorry_lint scans core only).
-/

namespace BitcoinProofs.AF.PDW25

open Bitcoin.Crypto.Taproot.Program (p2trProgram isPayToTaproot
  p2trScript taprootLane isAnnex spendStack classifySpend SpendPath)

/-! ## TPR-001 (P2/P9) — the P2TR output template.

`script.cpp:IsPayToTaproot:241-246`: witness v1 with a 32-byte
program = the consensus template of a Taproot output (BIP341: "A
Taproot output is a native SegWit output with version number 1,
and a 32-byte witness program"). The def-mirror `rfl` is the
decide-coercion face (q.lean shape A); `_iff` = the round-trip
against `p2trScript` (the wallet-vector constructor, `OP_1 <32B>`
= 0x5120 ‖ program) — recognition on its own constructor output
holds iff the trailing 32 bytes form the program. -/

/-- TPR-001 (P9): the recognition template — `p2trProgram v p =
decide (v = 1 ∧ p.size = 32)` (native v1-32 only). -/
@[rule "TPR-001"]
theorem p2trProgram_eq (v : Nat) (program : ByteArray) :
    p2trProgram v program = decide (v = 1 ∧ program.size = 32) :=
  rfl

/-- TPR-001 (P2): round-trip — `isPayToTaproot (p2trScript prog)`
holds iff `prog` is 32 bytes (the template recognition on its own
constructor output). -/
@[rule "TPR-001"]
theorem isPayToTaproot_p2trScript_iff (program : ByteArray) :
    isPayToTaproot (p2trScript program) = (program.size = 32) :=
  Bitcoin.Crypto.Taproot.Program.isPayToTaproot_p2trScript program

/-! ## TPR-002 (P11) — the TAPROOT flag gate.

`interpreter.cpp:1959`: `if (!flags.verify_script_verify_taproot) {
set_success; return; }` — without the flag the v1-32-native spend
succeeds regardless of the witness (anyone-can-spend semantics
preserved pre-activation); with it, the lane depends only on
(version, program, isP2SH). -/

/-- TPR-002 (P11, gate side): with the flag off, the v1-32-native
witness program is NOT routed to the taproot lane. -/
@[rule "TPR-002"]
theorem taprootLane_gate_off (version : Nat) (program : ByteArray)
    (isP2SH : Bool) :
    taprootLane false version program isP2SH = false :=
  Bitcoin.Crypto.Taproot.Program.taprootLane_off version program
    isP2SH

/-- TPR-002 (P11, exact lane characterization): the taproot lane is
entered **iff** the TAPROOT flag is on, the witness version is 1, the
program is exactly 32 bytes and the spend is native (not P2SH-wrapped).
This states the actual gate predicate rather than the earlier vacuous
"equal inputs ⇒ equal outputs" congruence; it is the Core
`if (flags & SCRIPT_VERIFY_TAPROOT) && version == 1 && program.size() ==
32 && !p2sh` condition of interpreter.cpp:1957-1959. -/
@[rule "TPR-002"]
theorem taprootLane_true_iff (f : Bool) (version : Nat)
    (program : ByteArray) (isP2SH : Bool) :
    taprootLane f version program isP2SH = true ↔
      f = true ∧ version = 1 ∧ program.size = 32 ∧ isP2SH = false := by
  unfold taprootLane p2trProgram
  cases f <;> cases isP2SH <;>
    by_cases h : version = 1 ∧ program.size = 32 <;> simp [h]

/-! ## TPR-005 (P2) — annex detection.

`interpreter.cpp:1961-1969`: with ≥2 witness items, the LAST item
is the annex iff it is nonempty and starts with the 0x50 tag
(`SpanPopBack` semantics: popped before spend classification).
The arity rejects = the empty/1-item witness guards (a 1-item
witness's bare key-path signature is never read as an annex). -/

/-- TPR-005 (P2, def-mirror): `isAnnex items = decide (2 ≤
items.length ∧ last.size ≠ 0 ∧ last[0] = 0x50)`. -/
@[rule "TPR-005"]
theorem isAnnex_def (items : List ByteArray) :
    isAnnex items =
      decide (2 ≤ items.length ∧ (items.getLast!).size ≠ 0 ∧
        ((items.getLast!).get! 0).toNat = 0x50) :=
  rfl

/-- TPR-005 (P2, arity reject): no annex on the empty witness. -/
@[rule "TPR-005"]
theorem isAnnex_empty_stack : isAnnex [] = false :=
  Bitcoin.Crypto.Taproot.Program.isAnnex_nil

/-- TPR-005 (P2, arity reject): a 1-item witness has no annex. -/
@[rule "TPR-005"]
theorem isAnnex_one_item (a : ByteArray) : isAnnex [a] = false :=
  Bitcoin.Crypto.Taproot.Program.isAnnex_single a

/-- TPR-005 (population): the annex is CONSUMED — a post-annex stack
spends exactly its pre-annex prefix (`SpanPopBack`, interpreter.cpp:1963). -/
@[rule "TPR-005"]
theorem spendStack_pop_dropLast (items : List ByteArray)
    (h : isAnnex items = true) :
    spendStack items = items.dropLast :=
  Bitcoin.Crypto.Taproot.Program.spendStack_eq_dropLast items h

/-- TPR-005 (population): every element of the post-annex spend stack is
a pre-annex element. -/
@[rule "TPR-005"]
theorem spendStack_pop_mem (items : List ByteArray)
    (h : isAnnex items = true) {x : ByteArray}
    (hx : x ∈ spendStack items) : x ∈ items.dropLast :=
  Bitcoin.Crypto.Taproot.Program.spendStack_mem_dropLast items h hx

/-- TPR-005 (append form): `items ++ [annex]` with an annex-shaped last
item spends exactly `items`. -/
@[rule "TPR-005"]
theorem spendStack_append_annex_pop (items : List ByteArray) (annex : ByteArray)
    (h : isAnnex (items ++ [annex]) = true) :
    spendStack (items ++ [annex]) = items :=
  Bitcoin.Crypto.Taproot.Program.spendStack_append_annex items annex h

/-! ## TPR-007 (P2) — the key-path spend.

`interpreter.cpp:1970-1975`: exactly 1 post-annex element = a
single BIP340 signature against the OUTPUT key q. -/

/-- TPR-007 (P2): a 1-item (annex-free) witness is a key-path
spend — the single element is the signature. -/
@[rule "TPR-007"]
theorem classifySpend_one_keyPath (sig : ByteArray) :
    classifySpend [sig] = SpendPath.keyPath sig :=
  Bitcoin.Crypto.Taproot.Program.classifySpend_keyPath sig

/-- TPR-007 (P2): an annex-carrying key-path spend (2 raw items,
last = annex) classifies as key-path over the FIRST item — the
annex is popped before the arity test. -/
@[rule "TPR-007"]
theorem classifySpend_annex_pop_keyPath (sig annex : ByteArray) :
    isAnnex [sig, annex] = true →
    classifySpend [sig, annex] = SpendPath.keyPath sig :=
  Bitcoin.Crypto.Taproot.Program.classifySpend_annex_keyPath sig
    annex

/-! ## TPR-008 (P2) — the script-path spend.

`interpreter.cpp:1976-1979`: ≥2 elements = script path — last =
control block, second-to-last = script. -/

/-- TPR-008 (P2): a 2-element witness whose last item is NOT
annex-shaped is a script-path spend (second-to-last = script,
last = control block). -/
@[rule "TPR-008"]
theorem classifySpend_many_scriptPath (script control : ByteArray)
    (h : isAnnex [script, control] = false) :
    classifySpend [script, control] =
      SpendPath.scriptPath script control :=
  Bitcoin.Crypto.Taproot.Program.classifySpend_scriptPath script
    control h

/-- TPR-008 (P2): script-path WITH annex — 3 raw items, last =
annex; classification sees the script + control pair. -/
@[rule "TPR-008"]
theorem classifySpend_annex_pop_scriptPath
    (script control annex : ByteArray) :
    isAnnex [script, control, annex] = true →
    classifySpend [script, control, annex] =
      SpendPath.scriptPath script control :=
  Bitcoin.Crypto.Taproot.Program.classifySpend_annex_scriptPath
    script control annex

/-- TPR-008 (general): EVERY annex-free post-annex stack of length at
least two is script-path — last = control block, second-to-last = script
(not just the 2-item instance). -/
@[rule "TPR-008"]
theorem classifySpend_many_scriptPath_general (stack : List ByteArray)
    (hlen : 2 ≤ stack.length) (h : isAnnex stack = false) :
    classifySpend stack =
      SpendPath.scriptPath stack[stack.length - 2]! stack.getLast! :=
  Bitcoin.Crypto.Taproot.Program.classifySpend_scriptPath_general
    stack hlen h

/-- TPR-008 (general annex case): a raw witness of at least three items
with an annex classifies over `dropLast`, exposing the script/control
pair at the end of the consumed stack. -/
@[rule "TPR-008"]
theorem classifySpend_annex_pop_scriptPath_general (items : List ByteArray)
    (hlen : 3 ≤ items.length) (h : isAnnex items = true) :
    classifySpend items =
      SpendPath.scriptPath items.dropLast[items.dropLast.length - 2]!
        items.dropLast.getLast! :=
  Bitcoin.Crypto.Taproot.Program.classifySpend_annex_scriptPath_general
    items hlen h

end BitcoinProofs.AF.PDW25
