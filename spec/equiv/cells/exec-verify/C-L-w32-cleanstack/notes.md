# C-L-w32-cleanstack — notes

## Green part: the flag/policy face

The green cell is a total function of `(final_len, cs)` and both tools prove
it.  It covers the row's `flag` and `pol.` faces: Core's
`SCRIPT_VERIFY_CLEANSTACK` bit and Lean's `PolicyFlags.cleanstack` read the
same input bit in the cell, and the failure condition is exactly
`final_len != 1` -> CLEANSTACK (30).

## Blocked part: `implicit in witness`

Core resizes to one element before the terminal check in **both** witness
arms:

```
2057      stack.resize(1);   // bare witness program
2102      stack.resize(1);   // P2SH-wrapped witness program
```

Lean's `verifyScriptFull` computes `finalLen` as

```
if flags.witness ∧ (isWitnessProgram spk).isSome then 1
else <re-evaluate the redeem script on stackCopy and take its length>
```

`spk` is the P2SH scriptPubKey in the wrapped arm, so `isWitnessProgram spk`
is `none` and the model keeps the inner length (2 for a v0 program evaluated
as a script: `OP_0 <20 bytes>` pushes two items).  Result: with CLEANSTACK on,
Lean rejects a P2SH-wrapped P2WPKH/P2WSH spend that Core accepts.

Evidence in `divergence/`:

- `lean-probe.lean` + `lean-eval.txt`: concrete `verifyScriptFull 64` on a
  P2SH-P2WPKH tape (stub EC checker) returns `.fail .cleanstack`.  Reproduce
  with `cd spec/core && lake env lean ../equiv/cells/.../divergence/lean-probe.lean`.
- `divergence/alive2/`: C excerpt (Core's resize in both arms) vs the Lean
  `finalLen` rule, symbolic over `(final_len, cs, kind)`.  Alive2
  counterexample at `kind = 2` (P2SH-wrapped), `cs = 1`, `final_len = 2`:
  source 1 (ok), target 120 (CLEANSTACK).
- `divergence/saw/`: the same pair against the Core postcondition; the C
  module proves, the L module fails.

The two probe runners *expect* the failure (`red` mode) and write
`STATUS=alive2-counterexample-as-expected` /
`STATUS=saw-proof-failed-as-expected`.  A green status there would mean the
divergence disappeared and the cell's row coverage could be revisited.

Core was not executed on the tape: there is no Core build in this worktree.
The C side is the line-cited excerpt used by the probe.

## Finding

Wave-32 finding `F-DIV-W32-01` (proposed global id `F-DIV-003`) is recorded in
`spec/equiv/findings/wave32/02-exec-006-009/report.md`.  Until it is fixed in
the Lean model or SCR-008 is explicitly re-scoped to the flag/policy faces,
the row must stay partial.
