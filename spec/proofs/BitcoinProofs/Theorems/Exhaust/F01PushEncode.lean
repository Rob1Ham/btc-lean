import Bitcoin.Script.Parser.Interface

/-!
# BitcoinProofs.Theorems.Exhaust.F01PushEncode — push-encoding decide-matrix (F01)

Exhaustive single-opcode decode matrix over every push-range opcode byte
`0x00–0x4e` (79 bytes: OP_0, direct pushes 0x01–0x4b, PUSHDATA1/2/4 =
0x4c/0x4d/0x4e), plus the adjacent single-byte range `0x4f–0x6a`
(OP_1NEGATE, OP_RESERVED, OP_1..OP_16, OP_NOP..OP_RETURN).

For each byte `c` the matrix pins the **exact** output of parser
(`Bitcoin.Script.Parser.getOp`, `getOpAux` tables — read, never edited)
on a canonical wire image `canonInput c`:

* the AST node — always `Opcode.pushBytes (ab (expectedSize c))` in the
  push range, i.e. payload length (= element size) `expectedSize c` with
  every payload byte `0xAB`;
* the next index `expectedNext c`.

Proof technique: `rfl` — the kernel delta-reduces real `getOp` on
the 107 concrete inputs.  (The `decide` *tactic* is NOT usable here: it
evaluates the `Decidable` instance under reducible transparency and gets
stuck on non-`@[reducible]` `getOp`; plain `rfl` definitional
checking has no such restriction.  No `native_decide`, no `sorry`.)
Per-byte corollaries are extracted from the matrix via `List.all_eq_true`.

Cross-check: a python script re-derives the same table
from Bitcoin Core `script.cpp::GetScriptOp` (v32.99 semantics, the
ground truth) and compares it against these Lean tables for all 79 (+28)
bytes.  Result: MATCH.

Scope note (VERIFIED vs PROPOSED): the matrix is about the PARSER layer
only.  Element sizes above 520, disabledness and opcode counting are
interpreter-side (`opcodeWF` vs `opcodeShape`); Core's `GetScriptOp`
likewise parses any `≤ OP_PUSHDATA4` payload it can read.
-/

namespace BitcoinProofs.Theorems.Exhaust.F01PushEncode

open Bitcoin.Script.Parser

set_option maxRecDepth 8000
set_option maxHeartbeats 4000000

/-! ## Canonical wire images -/

/-- `n` payload bytes, all `0xAB`. -/
def ab (n : Nat) : ByteArray := ByteArray.mk (Array.replicate n 0xAB)

theorem ab_size (n : Nat) : (ab n).size = n := by
  simp [ab, ByteArray.size, Array.size_eq_length_toList, List.length_replicate]

/-- Canonical wire image of opcode byte `c` for `0 ≤ c ≤ 0x4e`, opcode
at index 0, with enough payload bytes that the parse succeeds:

* `c = 0`       : `[0x00]`                         (OP_0, empty push)
* `1 ≤ c ≤ 0x4b`: `[c] ++ 0xAB^c`                  (direct push of `c` bytes)
* `c = 0x4c`    : `[0x4c, 0x01] ++ 0xAB^1`         (PUSHDATA1, len 1)
* `c = 0x4d`    : `[0x4d, 0x02, 0x00] ++ 0xAB^2`   (PUSHDATA2, len 2)
* `c = 0x4e`    : `[0x4e, 0x04, 0,0,0] ++ 0xAB^4`  (PUSHDATA4, len 4) -/
def canonInput (c : Nat) : ByteArray :=
  if c = 0 then ByteArray.mk #[0x00]
  else if c ≤ 0x4b then ByteArray.mk #[c.toUInt8] ++ ab c
  else if c = 0x4c then ByteArray.mk #[0x4c, 0x01] ++ ab 1
  else if c = 0x4d then ByteArray.mk #[0x4d, 0x02, 0x00] ++ ab 2
  else ByteArray.mk #[0x4e, 0x04, 0x00, 0x00, 0x00] ++ ab 4

/-- Element size (push payload length) the parser must produce for byte
`c` on `canonInput c`. -/
def expectedSize (c : Nat) : Nat :=
  if c = 0 then 0
  else if c ≤ 0x4b then c
  else if c = 0x4c then 1
  else if c = 0x4d then 2
  else 4

/-- Next index after decoding byte `c` on `canonInput c`. -/
def expectedNext (c : Nat) : Nat :=
  if c = 0 then 1
  else if c ≤ 0x4b then c + 1
  else if c = 0x4c then 3
  else if c = 0x4d then 5
  else 9

/-! ## The decide-matrix over 0x00–0x4e (79 bytes) -/

/-- One matrix row: parser, on the canonical input for byte `c`,
must produce exactly `pushBytes (ab (expectedSize c))` at next-index
`expectedNext c`. -/
def row (c : Nat) : Bool :=
  decide (getOp (canonInput c) 0
    = some (Opcode.pushBytes (ab (expectedSize c)), expectedNext c))

/-- The full matrix: all 79 push-range bytes `0x00–0x4e`. -/
def matrix : Bool := (List.range 79).all row

/-- **Decide-matrix theorem (push range).**  Kernel-checked for all 79
bytes at once by `rfl` (definitional evaluation of `getOp`). -/
theorem matrix_true : matrix = true := by rfl

theorem row_true (c : Nat) (hc : c < 79) : row c = true := by
  have h : matrix = true := matrix_true
  rw [matrix, List.all_eq_true] at h
  exact h c (List.mem_range.mpr hc)

/-- Per-byte corollary: the exact parse result for every byte
`0x00–0x4e` — element size, payload contents (`0xAB` each) and next
index all pinned. -/
theorem getOp_canon (c : Nat) (hc : c < 79) :
    getOp (canonInput c) 0
      = some (Opcode.pushBytes (ab (expectedSize c)), expectedNext c) :=
  decide_eq_true_iff.mp (row_true c hc)

/-- Element size of the parsed node equals `expectedSize c`. -/
theorem elementSize_canon (c : Nat) (hc : c < 79) (d : ByteArray) (i : Nat)
    (h : getOp (canonInput c) 0 = some (Opcode.pushBytes d, i)) :
    d.size = expectedSize c := by
  rw [getOp_canon c hc, Option.some.injEq, Prod.mk.injEq] at h
  rcases h with ⟨h1, -⟩
  injection h1 with h1
  rw [h1.symm]
  exact ab_size _

/-! ## Adjacent single-byte range 0x4f–0x6a (aux matrix)

OP_1NEGATE (0x4f) → `pushNum 0`; OP_RESERVED (0x50) → `op ⟨0x50⟩` (not
a push); OP_1..OP_16 (0x51–0x60) → `pushNum (c - 0x50)`; OP_NOP..OP_RETURN
(0x61–0x6a) → `op c`.  All consume exactly 1 byte, no payload. -/

def canonAux (c : Nat) : ByteArray := ByteArray.mk #[c.toUInt8]

/-- Expected parse result for byte `c` in `0x4f–0x6a` (per
`getOpAux` table). -/
def expectedAux (c : Nat) : Option (Opcode × Nat) :=
  if c = 0x4f then some (Opcode.pushNum 0, 1)
  else if c = 0x50 then some (Opcode.op ⟨0x50, by omega⟩, 1)
  else if c ≤ 0x60 then some (Opcode.pushNum (c - 0x50), 1)
  else some (Opcode.op ⟨c % 256, Nat.mod_lt c (by omega)⟩, 1)

def rowAux (c : Nat) : Bool := decide (getOp (canonAux c) 0 = expectedAux c)

/-- The aux matrix: all 28 bytes `0x4f–0x6a`. -/
def matrixAux : Bool := (List.range 28).all (fun k => rowAux (0x4f + k))

/-- **Decide-matrix theorem (aux range).** -/
theorem matrixAux_true : matrixAux = true := by rfl

theorem getOp_aux (c : Nat) (hc : 0x4f ≤ c) (hc' : c ≤ 0x6a) :
    getOp (canonAux c) 0 = expectedAux c := by
  have h : matrixAux = true := matrixAux_true
  rw [matrixAux, List.all_eq_true] at h
  have hk : 0x4f + (c - 0x4f) = c := by omega
  rw [← hk]
  exact decide_eq_true_iff.mp (h (c - 0x4f) (List.mem_range.mpr (by omega)))

/-! ## Spot-check corollaries (named) -/

theorem op_0 : getOp (ByteArray.mk #[0x00]) 0
    = some (Opcode.pushBytes ByteArray.empty, 1) := by rfl

theorem op_1negate : getOp (ByteArray.mk #[0x4f]) 0
    = some (Opcode.pushNum 0, 1) := by rfl

theorem op_16 : getOp (ByteArray.mk #[0x60]) 0
    = some (Opcode.pushNum 16, 1) := by rfl

theorem op_pushdata1_len1 : getOp (canonInput 0x4c) 0
    = some (Opcode.pushBytes (ab 1), 3) := by rfl

theorem op_pushdata2_len2 : getOp (canonInput 0x4d) 0
    = some (Opcode.pushBytes (ab 2), 5) := by rfl

theorem op_pushdata4_len4 : getOp (canonInput 0x4e) 0
    = some (Opcode.pushBytes (ab 4), 9) := by rfl

theorem op_max_direct : getOp (canonInput 0x4b) 0
    = some (Opcode.pushBytes (ab 0x4b), 0x4c) := by rfl

end BitcoinProofs.Theorems.Exhaust.F01PushEncode
