import Bitcoin.Script.Parser.Interface

/-!
# BitcoinProofs.Theorems.ParserCor — W15: parser-layer corollaries (sorry-free)

Corollaries of W05's proved parser laws (`Bitcoin.Script.Parser`,
`research/w2-05-script-parser.md`). Zero-dependency: imports only the
`core` package.

C4 portfolio linkage:

| C4 ID   | theorem here            | statement (short) |
|---------|-------------------------|-------------------|
| THM-021p| `parseScript_fuel_indep` | the parse result does not depend on the fuel once it is ≥ byte size + 1 (totality of the parse layer) |
| THM-022p| `parseScript_fuel_indep` (same theorem is the determinism content) | result independent of fuel |
| THM-023p| `parseFrom_fuel_sufficient` | a successful parse never needs more fuel than `size + 1 - i` (each opcode consumes ≥ 1 byte) |
| THM-027p| `parseScript_none_truncation` | a well-fueled parse fails ONLY at a truncated push (`getOp = none` in range) — never by fuel exhaustion |
| THM-027p| `parseScript_shape` | every opcode a successful parse returns satisfies `opcodeShape` |
| THM-009p| `parseScript_roundtrip_fuel` | roundtrip holds at ANY fuel ≥ size+1, not just the canonical one |

Dependencies: W05's `parseFrom_mono`, `parseFrom_none_trunc`, `parseFrom_shape`,
`parseFrom_roundtrip`, `getOp_spec` (all sorry-free in `Bitcoin.Script.Parser.Defs`).
-/

namespace BitcoinProofs.Theorems.ParserCor

open Bitcoin.Data Bitcoin.Script.Parser

/-! ## Fuel sufficiency and fuel-independence -/

/-- A successful parse never needs more fuel than `b.size + 1 - i`:
each decoded opcode advances the index (`getOp_spec`), so at most
`b.size - i` decodes plus one final "end of script" step are needed.
This is the parser-layer form of C4 THM-021/023 (totality + fuel bound). -/
theorem parseFrom_fuel_sufficient : ∀ (f : Nat) (b : ByteArray) (ops : List Opcode) (i : Nat),
    parseFrom f b i = some ops → i ≤ b.size →
    parseFrom (b.size + 1 - i) b i = some ops := by
  intro f
  induction f with
  | zero =>
      intro b ops i h _
      simp only [parseFrom] at h
      contradiction
  | succ f ih =>
      intro b ops i h hi
      rw [parseFrom_succ] at h
      by_cases hbi : b.size ≤ i
      · -- i = b.size (given hi): both sides are the end-of-script branch
        rw [if_pos hbi] at h
        have hD : b.size + 1 - i = 1 := by omega
        rw [hD, parseFrom_succ, if_pos hbi]
        rw [Option.some.injEq] at h
        exact congrArg some h
      · rw [if_neg hbi] at h
        have hD : b.size + 1 - i = (b.size - i) + 1 := by omega
        rw [hD, parseFrom_succ, if_neg hbi]
        rw [Option.bind_eq_some_iff] at h
        obtain ⟨p, hgp, hp⟩ := h
        obtain ⟨o, i'⟩ := p
        rw [hgp, Option.bind_some]
        rw [Option.map_eq_some_iff] at hp
        obtain ⟨ops', hops', rfl⟩ := hp
        have hspec := getOp_spec hgp
        have hle : b.size + 1 - i' ≤ b.size - i := by
          have h1 := hspec.1
          have h2 := hspec.2.1
          omega
        have hrec := ih b ops' i' hops' hspec.2.1
        have hmono := parseFrom_mono (b.size + 1 - i') b ops' i' (b.size - i) hle hrec
        exact Option.map_eq_some_iff.mpr ⟨ops', hmono, rfl⟩

/-- Failure persistence: with MORE fuel, a failure stays a failure (the
contrapositive direction of `parseFrom_mono`). -/
theorem parseFrom_none_mono (f f' : Nat) (b : ByteArray) (i : Nat) (hf : f ≤ f')
    (h : parseFrom f' b i = none) : parseFrom f b i = none := by
  cases hf2 : parseFrom f b i with
  | none => rfl
  | some ops =>
      exact absurd (parseFrom_mono f b ops i f' hf hf2) (by rw [h]; simp)

/-- THM-021p/022p: the parse result at the canonical fuel
`parseScript s = parseFrom (s.bytes.size + 1) s.bytes 0` is *the* result —
any larger fuel returns exactly the same value. The parser layer is
therefore total AND deterministic in the fuel (C4 THM-021/022, parser side). -/
theorem parseScript_fuel_indep (s : Script) (f : Nat) (hf : s.bytes.size + 1 ≤ f) :
    parseFrom f s.bytes 0 = parseScript s := by
  show parseFrom f s.bytes 0 = parseFrom (s.bytes.size + 1) s.bytes 0
  cases h : parseFrom (s.bytes.size + 1) s.bytes 0 with
  | none =>
      cases hf2 : parseFrom f s.bytes 0 with
      | none => rfl
      | some ops =>
          exfalso
          have hs : parseFrom (s.bytes.size + 1) s.bytes 0 = some ops :=
            parseFrom_fuel_sufficient f s.bytes ops 0 hf2 (by omega)
          exact absurd hs (by rw [h]; simp)
  | some ops => exact parseFrom_mono _ _ _ _ _ hf h

/-- THM-027p (parser side): a parse with the canonical fuel fails ONLY by
hitting a truncated/malformed push in range — the failure witness is a
`getOp = none` at some in-bounds index. (Mirrors Defs.`parseFrom_none_trunc`
at the `parseScript` entry point.) -/
theorem parseScript_none_truncation (s : Script) (h : parseScript s = none) :
    ∃ j, j < s.bytes.size ∧ getOp s.bytes j = none :=
  parseFrom_none_trunc _ s.bytes 0 (by omega) (by omega) h

/-- THM-009p: roundtrip at any sufficient fuel — parsing the printed form
of a well-formed opcode list recovers it at EVERY fuel ≥ size + 1 (W05's
`parse_serialize_roundtrip` pinned at the canonical fuel; this extends it
via `parseScript_fuel_indep`). -/
theorem parseScript_roundtrip_fuel (ops : List Opcode) (f : Nat)
    (h : ∀ o ∈ ops, opcodeWF o) (hf : (serializeOpcodes ops).size + 1 ≤ f) :
    parseFrom f (serializeOpcodes ops) 0 = some ops := by
  have hcanon : parseFrom ((serializeOpcodes ops).size + 1) (serializeOpcodes ops) 0
      = some ops := parse_serialize_roundtrip ops h
  have hindep := parseScript_fuel_indep ⟨serializeOpcodes ops⟩ f hf
  rw [hindep]
  exact hcanon

/-- THM-027p (shape safety): every opcode of a successful parse satisfies
`opcodeShape` — pushes of any payload size, `pushNum n` with `n ≤ 16`,
`op` with wire byte 0x50 or ≥ 0x61. (Defs.`parseFrom_shape` at the
`parseScript` entry point.) -/
theorem parseScript_shape (s : Script) (ops : List Opcode) (h : parseScript s = some ops) :
    ∀ o ∈ ops, opcodeShape o := by
  have h' : parseFrom (s.bytes.size + 1) s.bytes 0 = some ops := h
  exact parseFrom_shape _ s.bytes ops 0 h'

/-! ## Axiom-footprint pins (L3): drift on any of these fails the build -/

/-- info: 'BitcoinProofs.Theorems.ParserCor.parseFrom_fuel_sufficient' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms parseFrom_fuel_sufficient

/-- info: 'BitcoinProofs.Theorems.ParserCor.parseFrom_none_mono' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms parseFrom_none_mono

/-- info: 'BitcoinProofs.Theorems.ParserCor.parseScript_fuel_indep' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms parseScript_fuel_indep

/-- info: 'BitcoinProofs.Theorems.ParserCor.parseScript_none_truncation' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms parseScript_none_truncation

/-- info: 'BitcoinProofs.Theorems.ParserCor.parseScript_roundtrip_fuel' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms parseScript_roundtrip_fuel

/-- info: 'BitcoinProofs.Theorems.ParserCor.parseScript_shape' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms parseScript_shape

end BitcoinProofs.Theorems.ParserCor
