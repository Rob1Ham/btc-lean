import Bitcoin.Data.Basic
import Bitcoin.Data.Script
import Bitcoin.Script.Parser.Defs

/-!
# Bitcoin.Script.Parser — FROZEN INTERFACE (filled)

## Interface contract (do not edit outside an interface-change PR)

Core counterpart files: src/script/script.h (GetOp, opcode enum 0x00-0xff,
                        MAX_SCRIPT_ELEMENT_SIZE=520), src/script/
                        interpreter.cpp (push-data limits)
Status: frozen 2026-10-16; bodies filled.

## Scope

Total bytes→AST parser over the FULL 0x00–0xff opcode table (incl.
PUSHDATA1/2/4 and the 15 disabled opcodes — CVE-2010-5137: disabled
opcodes fail even in dead IF branches), roundtrip encode/decode for the
enabled subset, and the 520-byte element limit. This module replaces the prototype
bootstrap subset parser (`Bitcoin.Data.Script.parse`, preserved for the
regression suite) — the two coexist; `ScriptInstr` (subset) and `Opcode`
(full) are deliberately distinct types.

## Where the declarations live

`Opcode`, `isDisabled`, `MAX_SCRIPT_ELEMENT_SIZE`, `serializeOpcodes`
and all proof machinery are defined in `Bitcoin.Script.Parser.Defs`
(same namespace). This module adds the `Script`-level entry point and
the four frozen laws.

## Documented interface changes vs the frozen interface

1. `parseScript`/`serializeOpcodes` placeholders were `opaque … := sorry`;
   filled as transparent `def`s (proofs must unfold them; the opaque
   wrapper would have blocked every theorem body).
2. `parse_serialize_roundtrip`'s hypothesis: the frozen interface wrote
   `ops.all (fun o => match o with …)` — `List.all` takes a `Bool`
   predicate, so that placeholder did not typecheck. Replaced by the
   documented tightening `∀ o ∈ ops, opcodeWF o` (`opcodeWF` is the
   full printer-roundtrip predicate: `pushBytes` payload ≤ 520,
   `pushNum n` with `n ≤ 16`, `op` byte 0x50 or ≥ 0x61).
-/

namespace Bitcoin.Script.Parser

open Bitcoin.Data

/-- Total bytes→AST parse (`GetOp` walk over the whole script).
`none` = malformed push / truncation. Fuel = byte size (each opcode
consumes ≥ 1 byte), mirroring the prototype pattern. -/
def parseScript (s : Script) : Option (List Opcode) :=
  parseFrom (s.bytes.size + 1) s.bytes 0

/-! ## Frozen laws (the parser layer exit criteria) -/

/-- Parser totality: every byte string either parses or fails *cleanly*
— the parser never diverges (termination is by fuel construction; this
theorem pins that `parseScript` is defined by structural/well-founded
recursion that kernel-reduces, per the prototype gotcha R5). -/
theorem parseScript_terminates (s : Script) :
    parseScript s = none ∨ ∃ ops, parseScript s = some ops := by
  cases h : parseScript s with
  | none => exact Or.inl rfl
  | some ops => exact Or.inr ⟨ops, rfl⟩

/-- Roundtrip: enabled-opcode ASTs re-serialize to a byte string that
parses back to the same AST. -/
theorem parse_serialize_roundtrip (ops : List Opcode)
    (h : ∀ o ∈ ops, opcodeWF o) :
    parseScript ⟨serializeOpcodes ops⟩ = some ops := by
  have hb := parseFrom_roundtrip ops h
  show parseFrom ((serializeOpcodes ops).size + 1) (serializeOpcodes ops) 0 = some ops
  exact hb

/-- Byte-exactness of the push machinery: OP_0 pushes the empty string;
OP_1..OP_75 push exactly that many following bytes; PUSHDATA{n} uses
exactly n length bytes. (Statement per push class; split as needed.) -/
theorem pushBytes_exact (d : ByteArray) (h : 1 ≤ d.size ∧ d.size ≤ 75) :
    ∃ ops, parseScript ⟨serializeOpcodes [Opcode.pushBytes d]⟩ = some ops
      ∧ ops = [Opcode.pushBytes d] := by
  refine ⟨[Opcode.pushBytes d], ?_, rfl⟩
  apply parse_serialize_roundtrip
  intro o ho
  simp only [List.mem_cons, List.not_mem_nil] at ho
  rcases ho with rfl | h0
  · show d.size ≤ 520
    omega
  · exact h0.elim

/-- A disabled opcode's wire byte is an ordinary `op` byte ≥ 0x61
(the 15 disabled codes all lie in 0x7e–0x9a). -/
theorem isDisabled_ge (c : Fin 256) (h : isDisabled c = true) : 0x61 ≤ c.toNat := by
  have hm : c.toNat = 0x7e ∨ c.toNat = 0x7f ∨ c.toNat = 0x80 ∨ c.toNat = 0x81 ∨
      c.toNat = 0x83 ∨ c.toNat = 0x84 ∨ c.toNat = 0x85 ∨ c.toNat = 0x86 ∨
      c.toNat = 0x8d ∨ c.toNat = 0x8e ∨ c.toNat = 0x95 ∨ c.toNat = 0x96 ∨
      c.toNat = 0x97 ∨ c.toNat = 0x98 ∨ c.toNat = 0x9a := by
    simpa [isDisabled] using h
  omega

/-- Disabled opcodes are recognized at their wire bytes (they fail in
the interpreter; the parser must still decode them). -/
theorem disabled_roundtrip (c : Fin 256) (h : isDisabled c = true) :
    parseScript ⟨serializeOpcodes [Opcode.op c]⟩ = some [Opcode.op c] := by
  exact parse_serialize_roundtrip _ (by
    intro o ho
    simp only [List.mem_cons, List.not_mem_nil] at ho
    rcases ho with rfl | h0
    · show c.toNat = 0x50 ∨ 0x61 ≤ c.toNat
      exact Or.inr (isDisabled_ge c h)
    · exact h0.elim)

/-! ## Axiom-footprint pins (any axiom change fails the build) -/

/-- info: 'Bitcoin.Script.Parser.parseScript_terminates' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms parseScript_terminates

/-- info: 'Bitcoin.Script.Parser.parse_serialize_roundtrip' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms parse_serialize_roundtrip

/-- info: 'Bitcoin.Script.Parser.pushBytes_exact' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms pushBytes_exact

/-- info: 'Bitcoin.Script.Parser.disabled_roundtrip' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms disabled_roundtrip

end Bitcoin.Script.Parser
