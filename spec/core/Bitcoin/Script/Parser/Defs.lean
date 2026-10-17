import Bitcoin.Data.Basic
import Bitcoin.Data.Script
import Bitcoin.RuleAttr

/-!
# Bitcoin.Script.Parser — definitions and proof core (W05)

Total bytes→AST parser over the FULL 0x00–0xff opcode table (Core
`GetScriptOp`, script.cpp:313-363 @ `cce32b168`), the roundtrip printer
(canonical push encoding — the inverse of `CheckMinimalPush`'s
canonical forms, script.cpp:373-396), and the parse-level
opcode-counting hook for W09's 201-opcode budget
(SCR-022/023/024/025).

Design notes (C1 gotchas honored):

* No `ByteArray.toList` anywhere in executable code; the parser walks
  the `ByteArray` by index (`getOpt`) with explicit fuel, structural
  on the fuel argument, so it kernel-reduces under `decide`.
* Slicing uses `ByteArray.extract` (core lemmas `extract_append_eq_right`,
  `extract_append_size_add`, `extract_zero_size` make the shift lemmas
  one-liners).
* All proofs are axiom-free; `Test/Script/Parser/Tests` pins the axiom
  footprint with `#guard_msgs in #print axioms`.

**`pushNum` encoding convention (AST frozen by W01, convention pinned
here):** `pushNum n` for `1 ≤ n ≤ 16` is `OP_n` (wire `0x50+n`);
`pushNum 0` is `OP_1NEGATE` (wire `0x4f`, pushes `0x81` = ScriptNum
−1; `Nat` cannot carry −1). `OP_0` is `pushBytes ∅` per the interface
comment. The parser only ever produces `pushNum n` with `n ≤ 16`
(`opcodeWF` of every parsed opcode). `OP_RESERVED` (0x50) is
`op ⟨0x50⟩`, not a push — matching `GetScriptOp` (0x50 > OP_PUSHDATA4
reads no data).
-/

namespace Bitcoin.Script.Parser

open Bitcoin.Data

theorem UInt8_toNat_lt_256 (c : UInt8) : c.toNat < 256 := by
  have := UInt8.toNat_lt c
  exact Nat.lt_of_lt_of_le this (by decide)

/-! ## The frozen opcode AST and constants -/

/-- The full opcode model: pushes carry their payload; every non-push
byte value 0x00-0xff (OP_0 and OP_1..OP_16 are push-shaped but kept as
`pushNum` for interpreter ergonomics) is a `op` carrying its exact byte.
W05 attaches the consensus semantics (enabled/disabled, flags) to this
representation. -/
inductive Opcode where
  | pushBytes (data : ByteArray)   -- OP_0 (empty), OP_1..OP_75 direct, PUSHDATA1/2/4
  | pushNum (n : Nat)              -- OP_1NEGATE (0x4f) → -1, OP_1..OP_16 (0x51..0x60) → 1..16
  | op (code : Fin 256)            -- every other opcode, by its wire byte value
deriving Repr, DecidableEq, BEq

/-- The 15 disabled opcodes (B2: fail even in unexecuted IF branches;
CVE-2010-5137): OP_CAT 0x7e, OP_SUBSTR 0x7f, OP_LEFT 0x80, OP_RIGHT 0x81,
OP_INVERT 0x83, OP_AND 0x84, OP_OR 0x85, OP_XOR 0x86, OP_2MUL 0x8d,
OP_2DIV 0x8e, OP_MUL 0x95, OP_DIV 0x96, OP_MOD 0x97, OP_LSHIFT 0x98,
OP_RSHIFT 0x9a. -/
def isDisabled (c : Fin 256) : Bool :=
  c.toNat ∈ [0x7e, 0x7f, 0x80, 0x81, 0x83, 0x84, 0x85, 0x86,
             0x8d, 0x8e, 0x95, 0x96, 0x97, 0x98, 0x9a]

/-- MAX_SCRIPT_ELEMENT_SIZE (script.h): a single push payload ≤ 520. -/
def MAX_SCRIPT_ELEMENT_SIZE : Nat := 520

/-- Well-formedness for roundtripping: exactly the opcodes the printer
can re-emit byte-faithfully. The parser emits `pushNum n` only with
`n ≤ 16`, never emits `op` below 0x51 except OP_RESERVED (0x50), and
its direct/PUSHDATA1 payloads are ≤ 75 / ≤ 255 bytes; the 520 bound is
the consensus element limit (SCR-045), enforced by the interpreter, not
the parser — so `opcodeWF` is a hypothesis of the roundtrip theorems,
not a consequence of parsing. -/
def opcodeWF (o : Opcode) : Prop :=
  match o with
  | .pushBytes d => d.size ≤ MAX_SCRIPT_ELEMENT_SIZE
  | .pushNum n => n ≤ 16
  | .op c => c.toNat = 0x50 ∨ 0x61 ≤ c.toNat

/-! ## Bounded byte access -/

/-- `b[i]?` spelled out so the proofs stay in `if`-form. Definitional
to the `GetElem?` instance (`getOpt_eq_getElem?` is `rfl`). -/
def getOpt (b : ByteArray) (i : Nat) : Option UInt8 :=
  if h : i < b.size then some b[i] else none

theorem getOpt_eq_getElem? (b : ByteArray) (i : Nat) : getOpt b i = b[i]? := rfl

theorem getOpt_lt {b : ByteArray} {i : Nat} (h : i < b.size) :
    getOpt b i = some b[i] := by
  simp [getOpt, h]

theorem getOpt_ge {b : ByteArray} {i : Nat} (h : b.size ≤ i) :
    getOpt b i = none := by
  simp [getOpt, h]

theorem getOpt_some_lt {b : ByteArray} {i : Nat} {x : UInt8}
    (h : getOpt b i = some x) : i < b.size := by
  unfold getOpt at h
  split at h
  · simp only [Option.some.injEq] at h; omega
  · simp at h

theorem getOpt_some_eq {b : ByteArray} {i : Nat} {x : UInt8}
    (h : getOpt b i = some x) : b[i]'(getOpt_some_lt h) = x := by
  unfold getOpt at h
  split at h
  · simp only [Option.some.injEq] at h; exact h
  · simp at h

theorem getOpt_append_lt {pre q : ByteArray} {i : Nat} (h : i < pre.size) :
    getOpt (pre ++ q) i = getOpt pre i := by
  have hsz : i < (pre ++ q).size := by rw [ByteArray.size_append]; omega
  rw [getOpt, getOpt, dif_pos hsz, dif_pos h, ByteArray.getElem_append_left h]

theorem getOpt_append_ge {pre q : ByteArray} {i : Nat} (h : pre.size ≤ i) :
    getOpt (pre ++ q) i = getOpt q (i - pre.size) := by
  simp only [getOpt, ByteArray.size_append]
  split
  · rename_i hx
    rw [dif_pos (show i - pre.size < q.size by omega), ByteArray.getElem_append_right h]
  · rename_i hx
    rw [dif_neg (show ¬ (i - pre.size < q.size) by omega)]

/-! ## Slicing (`GetScriptOp` pointer arithmetic) -/

/-- The `n` bytes of `b` starting at `i` (`b.extract i (i+n)`); shorter
than `n` only if the script ends first. -/
def slice (b : ByteArray) (i n : Nat) : ByteArray := b.extract i (i + n)

theorem slice_size (b : ByteArray) (i n : Nat) (h : i + n ≤ b.size) :
    (slice b i n).size = n := by
  simp [slice, ByteArray.size_extract]; omega

/-- Bounded read of `n` bytes: `some` iff the bytes are all there. -/
def sliceOpt (b : ByteArray) (i n : Nat) : Option ByteArray :=
  if i + n ≤ b.size then some (slice b i n) else none

theorem sliceOpt_some {b : ByteArray} {i n : Nat} {d : ByteArray}
    (h : sliceOpt b i n = some d) : i + n ≤ b.size ∧ d = slice b i n := by
  unfold sliceOpt at h
  split at h
  · rename_i hc
    simp only [Option.some.injEq] at h
    exact ⟨hc, h.symm⟩
  · simp at h

theorem sliceOpt_some_of_le (b : ByteArray) (i n : Nat) (h : i + n ≤ b.size) :
    sliceOpt b i n = some (slice b i n) := by
  simp [sliceOpt, h]

theorem sliceOpt_none_of_gt {b : ByteArray} {i n : Nat} (h : b.size < i + n) :
    sliceOpt b i n = none := by
  unfold sliceOpt
  exact if_neg (by omega)

/-- Slicing commutes with appending a prefix. -/
theorem slice_shift (pre q : ByteArray) (j k : Nat) :
    slice (pre ++ q) (pre.size + j) k = slice q j k := by
  unfold slice
  rw [ByteArray.extract_append]
  have h1 : pre.extract (pre.size + j) (pre.size + j + k) = ByteArray.empty := by
    rw [ByteArray.extract_eq_empty_iff]; omega
  rw [h1, ByteArray.empty_append]
  congr 2 <;> omega

theorem sliceOpt_shift (pre q : ByteArray) (j k : Nat) :
    sliceOpt (pre ++ q) (pre.size + j) k = sliceOpt q j k := by
  unfold sliceOpt
  simp only [ByteArray.size_append]
  split
  · rename_i hc
    rw [if_pos (show j + k ≤ q.size by omega), slice_shift]
  · rename_i hc
    rw [if_neg (show ¬ j + k ≤ q.size by omega)]

/-! ## Little-endian length reads (`ReadLE16`/`ReadLE32`, script.cpp) -/

/-- Little-endian value of a byte string: `Σ d[j]·256^j`. -/
def leOfBytes (d : ByteArray) : Nat :=
  (List.range d.size).foldl (fun acc j => acc + (d.get! j).toNat * 256 ^ j) 0

/-- Read a `k`-byte little-endian length at index `i`; succeeds iff all
`k` length bytes are present (script.cpp `GetScriptOp` truncation
rule). -/
def readLE (b : ByteArray) (i k : Nat) : Option Nat :=
  let d := slice b i k
  if d.size = k then some (leOfBytes d) else none

theorem readLE_shift (pre q : ByteArray) (j k : Nat) :
    readLE (pre ++ q) (pre.size + j) k = readLE q j k := by
  simp [readLE, slice_shift]

/-! ## Single-opcode decode (`GetOp`, script.cpp:313-363) -/

/-- Decode the opcode whose wire byte is `c`, reading push payloads from
`b` at `i`; returns the AST node and the next index. Full 0x00–0xff
table: 0x00 → `pushBytes ∅` (OP_0), 0x01–0x4b direct push,
0x4c/0x4d/0x4e PUSHDATA1/2/4 with 1/2/4 little-endian length bytes,
0x4f → `pushNum 0` (OP_1NEGATE), 0x50 → `op ⟨0x50⟩` (OP_RESERVED —
not a push), 0x51–0x60 → `pushNum (n-0x50)` (OP_1..OP_16), ≥ 0x61 →
`op` (incl. the 15 disabled opcodes; disabledness is interpreter
policy, `EvalScript` checks `IsDisabled`). -/
def getOpAux (b : ByteArray) (i : Nat) (c : UInt8) : Option (Opcode × Nat) :=
  if c.toNat = 0 then some (Opcode.pushBytes ByteArray.empty, i + 1)
  else if c.toNat ≤ 0x4b then
    (sliceOpt b (i+1) c.toNat).map (fun d => (Opcode.pushBytes d, i + 1 + c.toNat))
  else if c.toNat = 0x4c then
    (readLE b (i+1) 1).bind
      (fun k => (sliceOpt b (i+2) k).map (fun d => (Opcode.pushBytes d, i + 2 + k)))
  else if c.toNat = 0x4d then
    (readLE b (i+1) 2).bind
      (fun k => (sliceOpt b (i+3) k).map (fun d => (Opcode.pushBytes d, i + 3 + k)))
  else if c.toNat = 0x4e then
    (readLE b (i+1) 4).bind
      (fun k => (sliceOpt b (i+5) k).map (fun d => (Opcode.pushBytes d, i + 5 + k)))
  else if c.toNat = 0x4f then some (Opcode.pushNum 0, i + 1)
  else if c.toNat = 0x50 then some (Opcode.op ⟨0x50, by omega⟩, i + 1)
  else if c.toNat ≤ 0x60 then some (Opcode.pushNum (c.toNat - 0x50), i + 1)
  else some (Opcode.op ⟨c.toNat, UInt8_toNat_lt_256 c⟩, i + 1)

/-- Decode one opcode at index `i` (`GetScriptOp` entry point). -/
@[rule "SCR-045"]
def getOp (b : ByteArray) (i : Nat) : Option (Opcode × Nat) :=
  match getOpt b i with
  | none => none
  | some c => getOpAux b i c

/-- The structural facts every parsed opcode satisfies. Weaker than
`opcodeWF`: PUSHDATA2/4 payloads may exceed the 520 element limit
(the parser accepts them; the interpreter rejects, SCR-046). -/
def opcodeShape (o : Opcode) : Prop :=
  match o with
  | .pushBytes _ => True
  | .pushNum n => n ≤ 16
  | .op c => c.toNat = 0x50 ∨ 0x61 ≤ c.toNat

/-- Every successful decode consumes at least one byte, stays inside
the script, and produces a shape-well-formed node. -/
theorem getOpAux_spec {b : ByteArray} {i : Nat} {c : UInt8} {o : Opcode} {i' : Nat}
    (h : getOpAux b i c = some (o, i')) (hi : i < b.size) :
    i < i' ∧ i' ≤ b.size ∧ opcodeShape o := by
  unfold getOpAux at h
  split at h
  · rename_i h0
    simp only [Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    exact ⟨by omega, by omega, by simp [opcodeShape]⟩
  · split at h
    · rename_i h1
      simp only [Option.map_eq_some_iff, Prod.mk.injEq] at h
      obtain ⟨d, hd, rfl, rfl⟩ := h
      have hle := (sliceOpt_some hd).1
      exact ⟨by omega, by omega, by simp [opcodeShape]⟩
    · split at h
      · rename_i h1
        simp only [Option.bind_eq_some_iff, Option.map_eq_some_iff, Prod.mk.injEq] at h
        obtain ⟨k, hk, d, hd, rfl, rfl⟩ := h
        have hle := (sliceOpt_some hd).1
        exact ⟨by omega, by omega, by simp [opcodeShape]⟩
      · split at h
        · rename_i h1
          simp only [Option.bind_eq_some_iff, Option.map_eq_some_iff, Prod.mk.injEq] at h
          obtain ⟨k, hk, d, hd, rfl, rfl⟩ := h
          have hle := (sliceOpt_some hd).1
          exact ⟨by omega, by omega, by simp [opcodeShape]⟩
        · split at h
          · rename_i h1
            simp only [Option.bind_eq_some_iff, Option.map_eq_some_iff, Prod.mk.injEq] at h
            obtain ⟨k, hk, d, hd, rfl, rfl⟩ := h
            have hle := (sliceOpt_some hd).1
            exact ⟨by omega, by omega, by simp [opcodeShape]⟩
          · split at h
            · rename_i h1
              simp only [Option.some.injEq, Prod.mk.injEq] at h
              obtain ⟨rfl, rfl⟩ := h
              exact ⟨by omega, by omega, by simp [opcodeShape]⟩
            · split at h
              · rename_i h1
                simp only [Option.some.injEq, Prod.mk.injEq] at h
                obtain ⟨rfl, rfl⟩ := h
                exact ⟨by omega, by omega, by exact Or.inl rfl⟩
              · split at h
                · rename_i h1
                  simp only [Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h
                  refine ⟨by omega, by omega, ?_⟩
                  show c.toNat - 0x50 ≤ 16
                  omega
                · rename_i h1
                  simp only [Option.some.injEq, Prod.mk.injEq] at h
                  obtain ⟨rfl, rfl⟩ := h
                  refine ⟨by omega, by omega, ?_⟩
                  show c.toNat = 0x50 ∨ 0x61 ≤ c.toNat
                  exact Or.inr (by omega)

/-- If `getOp` succeeds at `i`, index `i` is in bounds. -/
theorem getOp_lt {b : ByteArray} {i : Nat} {o : Opcode} {i' : Nat}
    (h : getOp b i = some (o, i')) : i < b.size := by
  unfold getOp at h
  split at h
  · simp at h
  · exact getOpt_some_lt (by assumption)

theorem getOp_spec {b : ByteArray} {i : Nat} {o : Opcode} {i' : Nat}
    (h : getOp b i = some (o, i')) :
    i < i' ∧ i' ≤ b.size ∧ opcodeShape o := by
  unfold getOp at h
  split at h
  · simp at h
  · rename_i c hc
    exact getOpAux_spec h (getOpt_some_lt hc)

theorem getOpAux_none {b : ByteArray} {i : Nat} {c : UInt8}
    (hc : getOpt b i = none) : getOp b i = none := by
  unfold getOp; rw [hc]

theorem getOpAux_some {b : ByteArray} {i : Nat} {c : UInt8}
    (hc : getOpt b i = some c) : getOp b i = getOpAux b i c := by
  unfold getOp; rw [hc]

theorem mapIfDist {α β : Type} (f : α → β) (c : Prop) [inst : Decidable c]
    (x y : Option α) :
    Option.map f (if c then x else y) = if c then Option.map f x else Option.map f y := by
  by_cases h : c <;> simp [h]

theorem mapBindDist {α β γ : Type} (h : β → γ) (x : Option α) (g : α → Option β) :
    @Option.map β γ h (@Option.bind α β x g)
      = @Option.bind α γ x (fun a => @Option.map β γ h (g a)) := by
  cases x <;> rfl

theorem mapMapPair {α : Type} (s : Nat) (f : α → Opcode × Nat) (X : Option α) :
    Option.map (fun p : Opcode × Nat => (p.1, s + p.2)) (Option.map f X)
      = Option.map (fun a => ((f a).1, s + (f a).2)) X := by
  cases X <;> simp

/-- `getOpAux` under a prefix shift: same node, next index shifted by
`pre.size`. -/
theorem getOpAux_map_shift (pre q : ByteArray) (j : Nat) (c : UInt8) :
    getOpAux (pre ++ q) (pre.size + j) c =
      (getOpAux q j c).map (fun p => (p.1, pre.size + p.2)) := by
  unfold getOpAux
  simp only [Nat.add_assoc, sliceOpt_shift, readLE_shift, mapIfDist, mapBindDist,
             mapMapPair, Option.map_some]

/-- `getOp` commutes with appending a prefix (all its reads shift). -/
theorem getOp_shift (pre q : ByteArray) (j : Nat) :
    getOp (pre ++ q) (pre.size + j) =
      (getOp q j).map (fun p => (p.1, pre.size + p.2)) := by
  unfold getOp
  rw [getOpt_append_ge (show pre.size ≤ pre.size + j by omega)]
  simp only [Nat.add_sub_cancel_left]
  cases h : getOpt q j with
  | none => rfl
  | some c => exact getOpAux_map_shift pre q j c

/-! ## The printer (canonical push encoding, `CheckMinimalPush`) -/

/-- Byte encodings of small naturals round-trip through `UInt8`. -/
theorem toUInt8_toNat (n : Nat) : n.toUInt8.toNat = n % 256 := rfl

/-- The length-prefix bytes of a push payload (minimal encoding:
1 byte for ≤ 75, `OP_PUSHDATA1` + 1 for ≤ 255, `OP_PUSHDATA2` + 2 for
≤ 65535, `OP_PUSHDATA4` + 4 beyond). -/
def lenBytes : Nat → List UInt8
  | 0 => [0x00]
  | n+1 =>
    if n + 1 ≤ 75 then [(n + 1).toUInt8]
    else if n + 1 ≤ 0xff then [0x4c, (n + 1).toUInt8]
    else if n + 1 ≤ 0xffff then [0x4d, ((n + 1) % 256).toUInt8, ((n + 1) / 256).toUInt8]
    else [0x4e, ((n + 1) % 256).toUInt8, ((n + 1) / 256 % 256).toUInt8,
             ((n + 1) / 65536 % 256).toUInt8, ((n + 1) / 16777216).toUInt8]

/-- Serialize a push: length prefix then payload. -/
def pushBytesWire (d : ByteArray) : ByteArray := (lenBytes d.size).toByteArray ++ d

/-- Serialize one opcode (canonical minimal push encoding — the exact
inverse of the canonical forms accepted by `CheckMinimalPush`,
script.cpp:373-396). For `pushNum n > 16` the wire byte `0x50 + n`
wraps modulo 256; only `n ≤ 16` (`opcodeWF`) round-trips. -/
def serializeOpcode : Opcode → ByteArray
  | .pushBytes d => pushBytesWire d
  | .pushNum n => List.toByteArray [if n = 0 then 0x4f else (0x50 + n).toUInt8]
  | .op c => List.toByteArray [c.toNat.toUInt8]

/-- Serialize an opcode list; `foldr` so the head equation is `rfl`. -/
def serializeOpcodes : List Opcode → ByteArray :=
  fun ops => ops.foldr (fun o acc => serializeOpcode o ++ acc) ByteArray.empty

theorem serializeOpcodes_cons (o : Opcode) (ops : List Opcode) :
    serializeOpcodes (o :: ops) = serializeOpcode o ++ serializeOpcodes ops := rfl

theorem serializeOpcode_pushNum (n : Nat) : serializeOpcode (.pushNum n) =
    List.toByteArray [if n = 0 then 0x4f else (0x50 + n).toUInt8] := rfl

theorem serializeOpcode_op (c : Fin 256) :
    serializeOpcode (.op c) = List.toByteArray [c.toNat.toUInt8] := rfl

theorem serializeOpcode_pushBytes (d : ByteArray) :
    serializeOpcode (.pushBytes d) = (lenBytes d.size).toByteArray ++ d := rfl

theorem lenBytes_pos (n : Nat) : 1 ≤ (lenBytes n).length := by
  cases n with
  | zero => simp [lenBytes]
  | succ m =>
    simp only [lenBytes]
    split <;> (first | split | skip) <;> (first | split | skip) <;> simp

theorem serializeOpcode_size (o : Opcode) : 1 ≤ (serializeOpcode o).size := by
  cases o with
  | pushBytes d =>
    unfold serializeOpcode pushBytesWire
    rw [ByteArray.size_append, List.size_toByteArray]
    have h := lenBytes_pos d.size
    omega
  | pushNum n => simp [serializeOpcode, List.size_toByteArray]
  | op c => simp [serializeOpcode, List.size_toByteArray]

/-- The payload of `a ++ c` starts right after `a`. -/
theorem extract_after_full (a c : ByteArray) :
    (a ++ c).extract a.size (a.size + c.size) = c :=
  ByteArray.extract_append_eq_right rfl rfl

/-- First byte of `[x].toByteArray ++ r` is `x`. -/
theorem getElem_append_toByteArray_cons {x : UInt8} {r : ByteArray}
    (h : 0 < (List.toByteArray [x] ++ r).size) :
    (List.toByteArray [x] ++ r)[0]'h = x := by
  simp

theorem getOpt_toByteArray_zero {x : UInt8} {r : ByteArray} :
    getOpt (List.toByteArray [x] ++ r) 0 = some x := by
  have h1 : (List.toByteArray [x]).size = 1 := by simp [List.size_toByteArray]
  rw [getOpt_lt (by rw [ByteArray.size_append, h1]; omega)]
  simp

theorem getOp_toByteArray_zero {x : UInt8} {r : ByteArray} :
    getOp (List.toByteArray [x] ++ r) 0 = getOpAux (List.toByteArray [x] ++ r) 0 x :=
  getOpAux_some getOpt_toByteArray_zero

/-- Head-byte access for a multi-byte `toByteArray` prefix: the first
opcode byte of `(x :: l).toByteArray ++ r` is `x`. -/
theorem getOpt_toByteArray_cons0 {x : UInt8} {l : List UInt8} {r : ByteArray} :
    getOpt (List.toByteArray (x :: l) ++ r) 0 = some x := by
  have h1 : (List.toByteArray [x]).size = 1 := by simp [List.size_toByteArray]
  have h2 : List.toByteArray (x :: l) = List.toByteArray [x] ++ List.toByteArray l := by
    rw [show x :: l = ([x] ++ l : List UInt8) from rfl, List.toByteArray_append]
  rw [h2, getOpt_lt (by rw [ByteArray.size_append, ByteArray.size_append, h1]; omega)]
  rw [ByteArray.getElem_append_left
      (a := List.toByteArray [x] ++ List.toByteArray l)
      (by rw [ByteArray.size_append, h1]; omega)]
  rw [getElem_append_toByteArray_cons (by rw [ByteArray.size_append, h1]; omega)]

theorem getOp_toByteArray_cons0 {x : UInt8} {l : List UInt8} {r : ByteArray} :
    getOp (List.toByteArray (x :: l) ++ r) 0 =
      getOpAux (List.toByteArray (x :: l) ++ r) 0 x :=
  getOpAux_some getOpt_toByteArray_cons0

/-- Dropping the first byte of a 2-byte `toByteArray`. -/
theorem toByteArray_tail2 (x y : UInt8) :
    (List.toByteArray [x, y]).extract 1 2 = List.toByteArray [y] := by
  have h2 : List.toByteArray [x, y] = List.toByteArray [x] ++ List.toByteArray [y] := by
    rw [show x :: [y] = ([x] ++ [y] : List UInt8) from rfl, List.toByteArray_append]
  have h1 : (List.toByteArray [x]).size = 1 := by simp [List.size_toByteArray]
  have hB : (List.toByteArray [y]).size = 1 := by simp [List.size_toByteArray]
  rw [h2, ByteArray.extract_append,
      show 1 - (List.toByteArray [x]).size = 0 from by rw [h1],
      show 2 - (List.toByteArray [x]).size = 1 from by rw [h1],
      show (List.toByteArray [x]).extract 1 2 = ByteArray.empty from by
        rw [ByteArray.extract_eq_empty_iff]; simp [h1],
      ByteArray.empty_append,
      show (1 : Nat) = (List.toByteArray [y]).size from hB.symm,
      ByteArray.extract_zero_size]

/-- Dropping the first byte of a 3-byte `toByteArray`. -/
theorem toByteArray_tail3 (x y z : UInt8) :
    (List.toByteArray [x, y, z]).extract 1 3 = List.toByteArray [y, z] := by
  have h2 : List.toByteArray [x, y, z] = List.toByteArray [x] ++ List.toByteArray [y, z] := by
    rw [show x :: [y, z] = ([x] ++ [y, z] : List UInt8) from rfl, List.toByteArray_append]
  have h1 : (List.toByteArray [x]).size = 1 := by simp [List.size_toByteArray]
  have hB : (List.toByteArray [y, z]).size = 2 := by simp [List.size_toByteArray]
  rw [h2, ByteArray.extract_append,
      show 1 - (List.toByteArray [x]).size = 0 from by rw [h1],
      show 3 - (List.toByteArray [x]).size = 2 from by rw [h1],
      show (List.toByteArray [x]).extract 1 3 = ByteArray.empty from by
        rw [ByteArray.extract_eq_empty_iff]; simp [h1],
      ByteArray.empty_append,
      show (2 : Nat) = (List.toByteArray [y, z]).size from hB.symm,
      ByteArray.extract_zero_size]

/-- A window strictly inside the head of an append ignores the tail. -/
theorem extract_head (a r : ByteArray) (s e : Nat) (h1 : s ≤ e) (h2 : e ≤ a.size) :
    (a ++ r).extract s e = a.extract s e := by
  rw [ByteArray.extract_append,
      show s - a.size = 0 from by omega,
      show e - a.size = 0 from by omega,
      ByteArray.extract_same, ByteArray.append_empty]

/-- The payload bytes of `(pre ++ (d ++ r))` starting at `pre.size`. -/
theorem extract_payload (pre d r : ByteArray) :
    (pre ++ (d ++ r)).extract pre.size (pre.size + d.size) = d := by
  rw [ByteArray.extract_append,
      show pre.size - pre.size = 0 from by omega,
      show pre.size + d.size - pre.size = d.size from by omega,
      ByteArray.extract_append_eq_left (rfl)]
  have hE : pre.extract pre.size (pre.size + d.size) = ByteArray.empty := by
    rw [ByteArray.extract_eq_empty_iff]; simp
  rw [hE, ByteArray.empty_append]

theorem extract_payload_at (pre d r : ByteArray) (s t : Nat) (hs : pre.size = s) (ht : d.size = t) :
    (pre ++ (d ++ r)).extract s (s + t) = d := by
  rw [← hs, ← ht]
  exact extract_payload pre d r

theorem sliceOpt_payload (pre d r : ByteArray) (s t : Nat) (hs : pre.size = s) (ht : d.size = t)
    (h : s + t ≤ (pre ++ (d ++ r)).size) :
    sliceOpt (pre ++ (d ++ r)) s t = some d := by
  rw [sliceOpt_some_of_le _ s t h, slice, extract_payload_at pre d r s t hs ht]

theorem readLE_some (b : ByteArray) (i k v : Nat) (h : i + k ≤ b.size)
    (hv : leOfBytes (slice b i k) = v) : readLE b i k = some v := by
  simp only [readLE]
  rw [if_pos (show (slice b i k).size = k from slice_size b i k h), hv]

theorem toByteArray_get! (l : List UInt8) (i : Nat) (h : i < l.length) :
    (List.toByteArray l).get! i = l[i] := by
  show (List.toByteArray l).data[i]! = l[i]
  rw [List.data_toByteArray, List.getElem!_toArray]
  exact getElem!_pos l i h

theorem leOfBytes_one (x : UInt8) : leOfBytes (List.toByteArray [x]) = x.toNat := by
  simp [leOfBytes, List.size_toByteArray]; rfl

theorem leOfBytes_two (x y : UInt8) :
    leOfBytes (List.toByteArray [x, y]) = x.toNat + y.toNat * 256 := by
  unfold leOfBytes
  have h2 : [x, y].toByteArray.size = 2 := by simp [List.size_toByteArray]
  rw [h2, show (List.range 2 : List Nat) = [0, 1] from rfl]
  simp only [List.foldl_cons, List.foldl_nil]
  rw [toByteArray_get! _ 0 (by simp), toByteArray_get! _ 1 (by simp)]
  simp

/-! ## `getOpAux` case-analysis lemmas (one per wire-byte region) -/

theorem getOpAux_00 (b : ByteArray) (i : Nat) (c : UInt8) (h : c.toNat = 0) :
    getOpAux b i c = some (Opcode.pushBytes ByteArray.empty, i + 1) := by
  unfold getOpAux
  rw [if_pos h]

theorem getOpAux_directPush (b : ByteArray) (i : Nat) (c : UInt8) (d : ByteArray)
    (h1 : 1 ≤ c.toNat) (h2 : c.toNat ≤ 0x4b)
    (hd : sliceOpt b (i + 1) c.toNat = some d) :
    getOpAux b i c = some (Opcode.pushBytes d, i + 1 + c.toNat) := by
  unfold getOpAux
  rw [if_neg (show ¬(c.toNat = 0) by omega), if_pos h2]
  simp [hd]

theorem getOpAux_pd1 (b : ByteArray) (i : Nat) (c : UInt8) (k : Nat) (d : ByteArray)
    (hc : c.toNat = 0x4c) (hr : readLE b (i + 1) 1 = some k)
    (hd : sliceOpt b (i + 2) k = some d) :
    getOpAux b i c = some (Opcode.pushBytes d, i + 2 + k) := by
  unfold getOpAux
  rw [if_neg (show ¬(c.toNat = 0) by omega),
      if_neg (show ¬(c.toNat ≤ 0x4b) by omega),
      if_pos hc]
  simp [hr, hd]

theorem getOpAux_pd2 (b : ByteArray) (i : Nat) (c : UInt8) (k : Nat) (d : ByteArray)
    (hc : c.toNat = 0x4d) (hr : readLE b (i + 1) 2 = some k)
    (hd : sliceOpt b (i + 3) k = some d) :
    getOpAux b i c = some (Opcode.pushBytes d, i + 3 + k) := by
  unfold getOpAux
  rw [if_neg (show ¬(c.toNat = 0) by omega),
      if_neg (show ¬(c.toNat ≤ 0x4b) by omega),
      if_neg (show ¬(c.toNat = 0x4c) by omega),
      if_pos hc]
  simp [hr, hd]

theorem getOpAux_4f (b : ByteArray) (i : Nat) (c : UInt8) (h : c.toNat = 0x4f) :
    getOpAux b i c = some (Opcode.pushNum 0, i + 1) := by
  unfold getOpAux
  rw [if_neg (show ¬(c.toNat = 0) by omega),
      if_neg (show ¬(c.toNat ≤ 0x4b) by omega),
      if_neg (show ¬(c.toNat = 0x4c) by omega),
      if_neg (show ¬(c.toNat = 0x4d) by omega),
      if_neg (show ¬(c.toNat = 0x4e) by omega),
      if_pos h]

theorem getOpAux_50 (b : ByteArray) (i : Nat) (c : UInt8) (h : c.toNat = 0x50) :
    getOpAux b i c = some (Opcode.op ⟨0x50, by omega⟩, i + 1) := by
  unfold getOpAux
  rw [if_neg (show ¬(c.toNat = 0) by omega),
      if_neg (show ¬(c.toNat ≤ 0x4b) by omega),
      if_neg (show ¬(c.toNat = 0x4c) by omega),
      if_neg (show ¬(c.toNat = 0x4d) by omega),
      if_neg (show ¬(c.toNat = 0x4e) by omega),
      if_neg (show ¬(c.toNat = 0x4f) by omega),
      if_pos h]

theorem getOpAux_opnum (b : ByteArray) (i : Nat) (c : UInt8) (h : 0x51 ≤ c.toNat)
    (h2 : c.toNat ≤ 0x60) :
    getOpAux b i c = some (Opcode.pushNum (c.toNat - 0x50), i + 1) := by
  unfold getOpAux
  rw [if_neg (show ¬(c.toNat = 0) by omega),
      if_neg (show ¬(c.toNat ≤ 0x4b) by omega),
      if_neg (show ¬(c.toNat = 0x4c) by omega),
      if_neg (show ¬(c.toNat = 0x4d) by omega),
      if_neg (show ¬(c.toNat = 0x4e) by omega),
      if_neg (show ¬(c.toNat = 0x4f) by omega),
      if_neg (show ¬(c.toNat = 0x50) by omega),
      if_pos h2]

theorem getOpAux_ophi (b : ByteArray) (i : Nat) (c : UInt8) (h : 0x61 ≤ c.toNat) :
    getOpAux b i c = some (Opcode.op ⟨c.toNat, UInt8_toNat_lt_256 c⟩, i + 1) := by
  unfold getOpAux
  rw [if_neg (show ¬(c.toNat = 0) by omega),
      if_neg (show ¬(c.toNat ≤ 0x4b) by omega),
      if_neg (show ¬(c.toNat = 0x4c) by omega),
      if_neg (show ¬(c.toNat = 0x4d) by omega),
      if_neg (show ¬(c.toNat = 0x4e) by omega),
      if_neg (show ¬(c.toNat = 0x4f) by omega),
      if_neg (show ¬(c.toNat = 0x50) by omega),
      if_neg (show ¬(c.toNat ≤ 0x60) by omega)]

/-! ## Single-opcode roundtrip: decoding the printed opcode -/

/-- One decoded opcode round-trips through the printer: decoding the
first opcode of `serializeOpcode o ++ q` yields exactly `o` and steps
past its wire image. Crux of the roundtrip theorems. -/
theorem getOp_serialize (o : Opcode) (q : ByteArray) (ho : opcodeWF o) :
    getOp (serializeOpcode o ++ q) 0 = some (o, (serializeOpcode o).size) := by
  cases o with
  | op c =>
    obtain ⟨v, hv⟩ := c
    rw [serializeOpcode_op]
    have hT : (⟨v, hv⟩ : Fin 256).toNat = v := rfl
    rw [hT]
    simp only [opcodeWF, hT] at ho
    rcases ho with h50 | h61
    · subst h50
      have hA : (List.toByteArray [(0x50 : Nat).toUInt8]).size = 1 := by
        simp [List.size_toByteArray]
      rw [getOp_toByteArray_zero,
          getOpAux_50 _ 0 _ (show ((0x50 : Nat).toUInt8).toNat = 0x50 by simp [toUInt8_toNat])]
      simp [hA]
    · have hA : (List.toByteArray [v.toUInt8]).size = 1 := by
        simp [List.size_toByteArray]
      rw [getOp_toByteArray_zero,
          getOpAux_ophi _ 0 _ (show 0x61 ≤ (v.toUInt8).toNat by simp only [toUInt8_toNat]; omega)]
      have hfin : (⟨v.toUInt8.toNat, UInt8_toNat_lt_256 v.toUInt8⟩ : Fin 256) = ⟨v, hv⟩ :=
        Fin.eq_of_val_eq (show v.toUInt8.toNat = v by simp only [toUInt8_toNat]; omega)
      rw [hfin]
      simp [hA]
  | pushNum n =>
    simp only [opcodeWF] at ho
    rcases Nat.eq_zero_or_pos n with rfl | hn
    · have hB0 : serializeOpcode (Opcode.pushNum 0) = List.toByteArray [(0x4f : UInt8)] := rfl
      have hA : (List.toByteArray [(0x4f : UInt8)]).size = 1 := by simp [List.size_toByteArray]
      rw [hB0, getOp_toByteArray_zero,
          getOpAux_4f _ 0 _ (show ((0x4f : UInt8).toNat = 0x4f) by decide)]
      simp [hA]
    · have hbyte : ((0x50 + n : Nat).toUInt8).toNat = 0x50 + n := by
        simp only [toUInt8_toNat]; omega
      have hA : (List.toByteArray [(0x50 + n : Nat).toUInt8]).size = 1 := by
        simp [List.size_toByteArray]
      rw [serializeOpcode_pushNum]
      simp only [if_neg (show ¬(n = 0) from by omega)]
      rw [getOp_toByteArray_zero,
        getOpAux_opnum _ 0 _
          (show 0x51 ≤ ((0x50 + n : Nat).toUInt8).toNat by rw [hbyte]; omega)
          (show ((0x50 + n : Nat).toUInt8).toNat ≤ 0x60 by rw [hbyte]; omega)]
      rw [hbyte, show (0x50 + n) - 0x50 = n from by omega]
      simp [hA]
  | pushBytes d =>
    rw [serializeOpcode_pushBytes, ByteArray.append_assoc]
    simp only [opcodeWF] at ho
    cases heq0 : d.size with
    | zero =>
      have hd0 : d = ByteArray.empty := ByteArray.size_eq_zero_iff.mp heq0
      subst hd0
      simp only [lenBytes, ByteArray.empty_append]
      have hA : (List.toByteArray [(0x00 : UInt8)]).size = 1 := by simp [List.size_toByteArray]
      rw [getOp_toByteArray_zero,
          getOpAux_00 _ 0 _ (show ((0x00 : UInt8).toNat = 0) by decide)]
      simp [hA]
    | succ m =>
      simp only [lenBytes]
      split
      · -- 1 ≤ d.size ≤ 75: direct push
        rename_i h75
        have hbyte : ((m+1 : Nat).toUInt8).toNat = m + 1 := by
          simp only [toUInt8_toNat]; omega
        have hA : (List.toByteArray [(m+1 : Nat).toUInt8]).size = 1 := by
          simp [List.size_toByteArray]
        rw [getOp_toByteArray_zero]
        have hd : sliceOpt (List.toByteArray [(m+1 : Nat).toUInt8] ++ (d ++ q)) (0+1)
            ((m+1 : Nat).toUInt8.toNat) = some d := by
          rw [hbyte, sliceOpt_payload _ d q 1 (m+1) hA heq0
            (by rw [ByteArray.size_append, ByteArray.size_append, hA]; omega)]
        rw [getOpAux_directPush _ 0 _ d
          (show 1 ≤ ((m+1 : Nat).toUInt8).toNat by rw [hbyte]; omega)
          (show ((m+1 : Nat).toUInt8).toNat ≤ 0x4b by rw [hbyte]; omega) hd]
        simp [hA, hbyte, heq0, ByteArray.size_append]
        all_goals omega
      · split
        · -- 76 ≤ d.size ≤ 255: PUSHDATA1
          rename_i hFF
          have hbyte : ((m+1 : Nat).toUInt8).toNat = m + 1 := by
            simp only [toUInt8_toNat]; omega
          have hA : (List.toByteArray [(0x4c : UInt8), ((m+1 : Nat).toUInt8)]).size = 2 := by
            simp [List.size_toByteArray]
          rw [getOp_toByteArray_cons0]
          have hs : (0+1) + 1 ≤ (List.toByteArray [(0x4c : UInt8), ((m+1 : Nat).toUInt8)] ++ (d ++ q)).size := by
            rw [ByteArray.size_append, ByteArray.size_append, hA]; omega
          have hle : leOfBytes (slice (List.toByteArray [(0x4c : UInt8), ((m+1 : Nat).toUInt8)] ++ (d ++ q)) 1 1)
              = m + 1 := by
            rw [slice, extract_head _ (d ++ q) 1 2 (by omega) (by rw [hA]; omega),
                toByteArray_tail2, leOfBytes_one, hbyte]
          have hr : readLE (List.toByteArray [(0x4c : UInt8), ((m+1 : Nat).toUInt8)] ++ (d ++ q)) (0+1) 1
              = some (m+1) := readLE_some _ 1 1 (m+1) hs hle
          have hd : sliceOpt (List.toByteArray [(0x4c : UInt8), ((m+1 : Nat).toUInt8)] ++ (d ++ q)) (0+2) (m+1)
              = some d := by
            rw [sliceOpt_payload _ d q 2 (m+1) hA heq0
              (by rw [ByteArray.size_append, ByteArray.size_append, hA]; omega)]
          rw [getOpAux_pd1 _ 0 _ (m+1) d rfl hr hd]
          simp [hA, heq0, ByteArray.size_append]
        · split
          · -- 256 ≤ d.size ≤ 65535: PUSHDATA2
            rename_i hFF2
            have hA : (List.toByteArray [(0x4d : UInt8), (((m+1) % 256 : Nat).toUInt8),
                (((m+1) / 256 : Nat).toUInt8)]).size = 3 := by
              simp [List.size_toByteArray]
            rw [getOp_toByteArray_cons0]
            have hs : (0+1) + 2 ≤ (List.toByteArray [(0x4d : UInt8), (((m+1) % 256 : Nat).toUInt8),
                (((m+1) / 256 : Nat).toUInt8)] ++ (d ++ q)).size := by
              rw [ByteArray.size_append, ByteArray.size_append, hA]; omega
            have hle : leOfBytes (slice (List.toByteArray [(0x4d : UInt8), (((m+1) % 256 : Nat).toUInt8),
                (((m+1) / 256 : Nat).toUInt8)] ++ (d ++ q)) 1 2) = m + 1 := by
              rw [slice, extract_head _ (d ++ q) 1 3 (by omega) (by rw [hA]; omega),
                  toByteArray_tail3, leOfBytes_two,
                  show ((((m+1) % 256 : Nat).toUInt8).toNat) = ((m+1) % 256 : Nat) from by
                    simp only [toUInt8_toNat]; omega,
                  show ((((m+1) / 256 : Nat).toUInt8).toNat) = ((m+1) / 256 : Nat) from by
                    simp only [toUInt8_toNat]; omega]
              omega
            have hr : readLE (List.toByteArray [(0x4d : UInt8), (((m+1) % 256 : Nat).toUInt8),
                (((m+1) / 256 : Nat).toUInt8)] ++ (d ++ q)) (0+1) 2 = some (m+1) :=
              readLE_some _ 1 2 (m+1) hs hle
            have hd : sliceOpt (List.toByteArray [(0x4d : UInt8), (((m+1) % 256 : Nat).toUInt8),
                (((m+1) / 256 : Nat).toUInt8)] ++ (d ++ q)) (0+3) (m+1) = some d := by
              rw [sliceOpt_payload _ d q 3 (m+1) hA heq0
                (by rw [ByteArray.size_append, ByteArray.size_append, hA]; omega)]
            rw [getOpAux_pd2 _ 0 _ (m+1) d rfl hr hd]
            simp [hA, heq0, ByteArray.size_append]
          · -- d.size > 65535: PUSHDATA4 (unreachable under opcodeWF)
            rename_i hFF3 hFFFF
            exfalso
            have h520 : d.size ≤ MAX_SCRIPT_ELEMENT_SIZE := ho
            simp only [MAX_SCRIPT_ELEMENT_SIZE] at h520
            rw [heq0] at h520
            omega

/-! ## The total parser (`ParseScript`, core_io.cpp) -/

/-- Reassociate `Option.map`/`Option.bind`: binding over the result of a
map commutes with pushing the map inside. -/
theorem bind_map_dist {α β γ : Type} (h : α → β) (x : Option α) (F : β → Option γ) :
    (x.map h).bind F = x.bind (fun a => F (h a)) := by
  cases x <;> rfl

/-- Fuel-bounded parse loop: decodes opcodes from index `i` while bytes
remain, with `f` bounding the number of decodes. Every successful decode
advances the index by at least one (`getOp_spec`), so `f = b.size + 1 - i`
always suffices; `parseFrom 0 _ _ = none` is only reachable at
`i > b.size` where one decode step already returns. -/
def parseFrom : Nat → ByteArray → Nat → Option (List Opcode)
  | 0, _, _ => none
  | f+1, b, i =>
    if b.size ≤ i then some []
    else (getOp b i).bind
      (fun p => (parseFrom f b p.2).map (fun ops => p.1 :: ops))

/-- Head equation for the fuel parser (succ form). -/
theorem parseFrom_succ (f : Nat) (b : ByteArray) (i : Nat) :
    parseFrom (f+1) b i =
      if b.size ≤ i then some []
      else (getOp b i).bind
        (fun p => (parseFrom f b p.2).map (fun ops => p.1 :: ops)) := rfl

/-- Success survives extra fuel: the parse result does not depend on
having more decodes available than needed. -/
theorem parseFrom_mono : ∀ (f : Nat) (b : ByteArray) (ops : List Opcode) (i f' : Nat),
    f ≤ f' → parseFrom f b i = some ops → parseFrom f' b i = some ops := by
  intro f
  induction f with
  | zero =>
    intro b ops i f' _ h
    simp only [parseFrom] at h
    contradiction
  | succ f ih =>
    intro b ops i f' hle h
    cases f' with
    | zero => omega
    | succ f'' =>
      have hle' : f ≤ f'' := by omega
      rw [parseFrom_succ] at h ⊢
      by_cases hbi : b.size ≤ i
      · rw [if_pos hbi] at h ⊢
        exact h
      · rw [if_neg hbi] at h ⊢
        rw [Option.bind_eq_some_iff] at h
        obtain ⟨p, hgp, hp⟩ := h
        obtain ⟨o, i'⟩ := p
        rw [hgp, Option.bind_some]
        rw [Option.map_eq_some_iff] at hp
        obtain ⟨ops', hops', rfl⟩ := hp
        show (parseFrom f'' b i').map (fun ops => o :: ops) = some ((o, i').1 :: ops')
        exact Option.map_eq_some_iff.mpr
          ⟨ops', ih b ops' i' f'' hle' hops', rfl⟩

/-- Parsing at the boundary of a prefix equals parsing the suffix: all
byte reads shift by `pre.size` (`getOp_shift`). -/
theorem parseFrom_shift : ∀ (f : Nat) (pre q : ByteArray) (j : Nat),
    parseFrom f (pre ++ q) (pre.size + j) = parseFrom f q j := by
  intro f
  induction f with
  | zero => intro pre q j; rfl
  | succ f ih =>
    intro pre q j
    rw [parseFrom_succ, parseFrom_succ]
    by_cases hqj : q.size ≤ j
    · rw [if_pos (show (pre ++ q).size ≤ pre.size + j from by
        rw [ByteArray.size_append]; omega),
          if_pos hqj]
    · rw [if_neg (show ¬((pre ++ q).size ≤ pre.size + j) from by
        rw [ByteArray.size_append]; omega),
          if_neg hqj, getOp_shift]
      cases hgo : getOp q j with
      | none => simp
      | some p =>
        obtain ⟨o, j'⟩ := p
        simp only [Option.map_some, Option.bind_some]
        rw [ih pre q j']

/-- One decode step at the head of a script extends the parsed list. -/
theorem parseFrom_cons {f : Nat} {b : ByteArray} {o : Opcode} {i' : Nat}
    {ops : List Opcode}
    (hgo : getOp b 0 = some (o, i'))
    (h : parseFrom (f - 1) b i' = some ops) :
    parseFrom f b 0 = some (o :: ops) := by
  cases f with
  | zero =>
    have h' : parseFrom 0 b i' = some ops := h
    simp only [parseFrom] at h'
    contradiction
  | succ f =>
    rw [parseFrom_succ]
    rw [if_neg (show ¬(b.size ≤ 0) from by have := getOp_lt hgo; omega)]
    rw [hgo, Option.bind_some]
    have h' : parseFrom f b i' = some ops := h
    exact Option.map_eq_some_iff.mpr ⟨ops, h', rfl⟩

/-- **Roundtrip, parse direction.** Parsing the printed form of any list
of well-formed opcodes recovers exactly that list. Fuel
`(serializeOpcodes ops).size + 1` always suffices because each opcode's
wire image is nonempty (`serializeOpcode_size`). -/
theorem parseFrom_roundtrip : ∀ (ops : List Opcode), (∀ o ∈ ops, opcodeWF o) →
    parseFrom ((serializeOpcodes ops).size + 1) (serializeOpcodes ops) 0 = some ops := by
  intro ops
  induction ops with
  | nil =>
    intro _
    show parseFrom (ByteArray.empty.size + 1) ByteArray.empty 0 = some []
    rw [parseFrom_succ, if_pos (show ByteArray.empty.size ≤ 0 by simp)]
  | cons o ops' ih =>
    intro hall
    have ho : opcodeWF o := hall o (by simp)
    have hall' : ∀ o' ∈ ops', opcodeWF o' := fun o' hm => hall o' (by simp [hm])
    rw [serializeOpcodes_cons]
    rw [parseFrom_succ]
    rw [if_neg (show ¬((serializeOpcode o ++ serializeOpcodes ops').size ≤ 0) from by
      have := getOp_lt (getOp_serialize o (serializeOpcodes ops') ho); omega)]
    rw [getOp_serialize o (serializeOpcodes ops') ho, Option.bind_some]
    have hrec : parseFrom ((serializeOpcodes (o :: ops')).size)
        (serializeOpcodes (o :: ops')) ((serializeOpcode o).size + 0) = some ops' := by
      rw [serializeOpcodes_cons, parseFrom_shift]
      have h1 := serializeOpcode_size o
      have hle : (serializeOpcodes ops').size + 1 ≤
          (serializeOpcode o ++ serializeOpcodes ops').size := by
        rw [ByteArray.size_append]; omega
      exact parseFrom_mono _ _ _ _ _ hle (ih hall')
    exact Option.map_eq_some_iff.mpr ⟨ops', hrec, rfl⟩

/-- Parsing cannot loop: with fuel one past the remaining bytes, a
failure is a genuine truncation — some decode at an in-bounds index
failed (truncated push), never fuel exhaustion. -/
theorem parseFrom_none_trunc : ∀ (f : Nat) (b : ByteArray) (i : Nat),
    i ≤ b.size → b.size + 1 - i ≤ f → parseFrom f b i = none →
    ∃ j, j < b.size ∧ getOp b j = none := by
  intro f
  induction f with
  | zero =>
    intro b i _hi hf _
    exfalso
    omega
  | succ f ih =>
    intro b i hi hf h
    rw [parseFrom_succ] at h
    by_cases hbi : b.size ≤ i
    · rw [if_pos hbi] at h; simp at h
    · rw [if_neg hbi] at h
      cases hgo : getOp b i with
      | none => exact ⟨i, by omega, hgo⟩
      | some p =>
        obtain ⟨o, i'⟩ := p
        rw [hgo] at h
        simp only [Option.bind_some, Option.map_eq_none_iff] at h
        have hs := getOp_spec hgo
        have h' : parseFrom f b i' = none := h
        refine ih b i' (by omega) ?_ h'
        omega

/-- Parsing is shape-safe: every opcode the parser returns satisfies
`opcodeShape` (pushes of any size, `pushNum n` with `n ≤ 16`, `op` with
byte 0x50 or ≥ 0x61). -/
theorem parseFrom_shape : ∀ (f : Nat) (b : ByteArray) (ops : List Opcode) (i : Nat),
    parseFrom f b i = some ops → ∀ o ∈ ops, opcodeShape o := by
  intro f
  induction f with
  | zero =>
    intro b ops i h
    simp only [parseFrom] at h
    contradiction
  | succ f ih =>
    intro b ops i h
    rw [parseFrom_succ] at h
    split at h
    · simp only [Option.some.injEq] at h
      subst h
      simp
    · rw [Option.bind_eq_some_iff] at h
      obtain ⟨p, hgp, hp⟩ := h
      obtain ⟨o, i'⟩ := p
      rw [Option.map_eq_some_iff] at hp
      obtain ⟨ops', hops', rfl⟩ := hp
      have hs := getOp_spec hgp
      intro o' hm
      rcases List.mem_cons.mp hm with rfl | hm'
      · exact hs.2.2
      · exact ih b ops' i' hops' o' hm'

/-! ## Opcode counting for the interpreter's op-limit (W09 hook) -/

/-- An opcode counts toward `MAX_OPS_PER_SCRIPT` (201, BASE/WITNESS_V0)
iff its wire byte is `> OP_16` (0x60): pushes and OP_1NEGATE..OP_16 are
exempt (interpreter.cpp:462, SCR-024), and disabled opcodes DO count
(SCR-025). The count is flow-insensitive — it is taken over the whole
parsed list, executed or not (SCR-023). W09 applies this inside the
eval loop; `opcodeCount` is the parse-level hook. -/
@[rule "SCR-024"]
def countsTowardOpLimit (o : Opcode) : Bool :=
  match o with
  | .pushBytes _ => false
  | .pushNum _ => false
  | .op c => 0x60 < c.toNat

/-- Number of op-limit-counting opcodes in a parsed script
(`nOpCount`, interpreter.cpp:460-464). W09 consumes this over the
`List Opcode` returned by `parseScript`. -/
def opcodeCount (ops : List Opcode) : Nat := ops.countP countsTowardOpLimit

theorem countsTowardOpLimit_pushBytes (d : ByteArray) :
    countsTowardOpLimit (.pushBytes d) = false := rfl

theorem countsTowardOpLimit_pushNum (n : Nat) :
    countsTowardOpLimit (.pushNum n) = false := rfl

theorem countsTowardOpLimit_op (c : Fin 256) :
    countsTowardOpLimit (.op c) = decide (0x60 < c.toNat) := rfl

theorem countsTowardOpLimit_op_gt (c : Fin 256) (h : 0x60 < c.toNat) :
    countsTowardOpLimit (.op c) = true := by
  rw [countsTowardOpLimit_op, decide_eq_true h]

theorem countsTowardOpLimit_op_le (c : Fin 256) (h : c.toNat ≤ 0x60) :
    countsTowardOpLimit (.op c) = false := by
  rw [countsTowardOpLimit_op, decide_eq_false (by omega)]

/-- The head-step equation for `opcodeCount`. -/
theorem opcodeCount_cons (o : Opcode) (ops : List Opcode) :
    opcodeCount (o :: ops) =
      (if countsTowardOpLimit o then 1 else 0) + opcodeCount ops := by
  simp only [opcodeCount, List.countP_cons]
  rw [Nat.add_comm]

/-- The op count of a script is at most its opcode list length. -/
theorem opcodeCount_le (ops : List Opcode) : opcodeCount ops ≤ ops.length := by
  simp only [opcodeCount]
  exact List.countP_le_length

end Bitcoin.Script.Parser
