import Bitcoin.Interpreter.Hashes

/-!
# Bitcoin.Crypto.RipemdDeep.SpecTables — the clone tables (the RIPEMD mirror)

Structural clones (NEW code, the RIPEMD mirror home) of the FOUR 80-entry message-word
selection and rotation tables of the **consensus-path** RIPEMD-160
(`Bitcoin.Interpreter.Hashes`, `rmdCompress` Hashes.lean:211-224 — the
OP_RIPEMD160 / OP_HASH160 impl via `Interpreter/Defs.lean:591/594`) plus
the two 5-entry round-constant arrays, and the f-index mirror map.

Each clone = `S <name>` (namespace `Bitcoin.Crypto.RipemdDeep`), table
literals copied entry-by-entry **from the C anchor extraction** (see
below), and the unit pin: each clone = its in-tree original `by rfl`
(a `S T = T` literal-clash, one kernel step, zero-information-loss =
the DER layer's T-L em pin).

C ground truth (the RIPEMD mirror anchors/ripemd160.cpp @ cce32b168, PROVENANCE.md):
`Transform`'s 80 interleaved R11/R12 call-pairs L64-222. The LEFT line
(R11..R51 macro calls, k = 0/0x5A827999/0x6ED9EBA1/0x8F1BBCDC/0xA953FD4E
L45-49) and RIGHT line (R12..R52, k = 0x50A28BE6/0x5C4DD124/
0x6D703EF3/0x7A6D76E9/0 L50-54). The C passes w-INDEX (w0..w15) and the
ROTATION as the last macro arg per call; the r/s tables here are the
j→(w-INDEX, s) sequences of those 160 calls, as extracted from the
anchor bytes (80 R11/R21/.../R51 lines → R/rmdR1 + rmdS1; the 80
interleaved R12/.../R52 lines → rmdR2 + rmdS2). f-index mirror: left
call `R{g+1}1` = f_{g+1} (C f1..f5 L20-24) ↔ `rmdF (j/16)`; right call
`R{5-g}2` = f_{5-g} ↔ `rmdF2 (j/16)` (Hashes.lean:195-209).

Extraction provenance: see `RipemdDeep/Tables.lean` (U2b) — the C-side
r/s lists are pinned to the anchor extraction by a 128-entry clone-of-
extraction table (XT = the extraction, XT = anchor C-lists), and
`Test/RipemdDeep/VectorGen.py` (U4) re-extracts them INDEPENDENTLY from
the anchor .cpp (json) — the two extractions cross-checked in
`AnchorsEq.lean` (U4, Test/).
-/

namespace Bitcoin.Crypto.RipemdDeep

/-! ## Message-word selection: left line (C L64-222 R1g w-args) -/

def S_R1 : Array Nat := #[
  0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,
  7,4,13,1,10,6,15,3,12,0,9,5,2,14,11,8,
  3,10,14,4,9,15,8,1,2,7,0,6,13,11,5,12,
  1,9,11,10,0,8,12,4,13,3,7,15,14,5,6,2,
  4,0,5,9,7,12,2,10,14,1,3,8,11,6,15,13]

/-! ## Message-word selection: right line (C L64-222 R2g w-args) -/

def S_R2 : Array Nat := #[
  5,14,7,0,9,2,11,4,13,6,15,8,1,10,3,12,
  6,11,3,7,0,13,5,10,14,15,8,12,4,9,1,2,
  15,5,1,3,7,14,6,9,11,8,12,2,10,0,4,13,
  8,6,4,1,3,11,15,0,5,12,2,13,9,7,10,14,
  12,15,10,4,1,5,8,7,6,2,13,14,0,3,9,11]

/-! ## Rotations: left line (C L64-222 R1g last-arg) -/

def S_S1 : Array Nat := #[
  11,14,15,12,5,8,7,9,11,13,14,15,6,7,9,8,
  7,6,8,13,11,9,7,15,7,12,15,9,11,7,13,12,
  11,13,6,7,14,9,13,15,14,8,13,6,5,12,7,5,
  11,12,14,15,14,15,9,8,9,14,5,6,8,6,5,12,
  9,15,5,11,6,8,13,12,5,12,13,14,11,8,5,6]

/-! ## Rotations: right line (C L64-222 R2g last-arg) -/

def S_S2 : Array Nat := #[
  8,9,9,11,13,15,15,5,7,7,8,11,14,14,12,6,
  9,13,15,7,12,8,9,11,7,7,12,7,6,15,13,11,
  9,7,15,11,8,6,6,14,12,13,5,14,13,13,7,5,
  15,5,8,11,14,14,6,14,6,9,12,9,12,5,15,8,
  8,5,12,9,12,5,14,6,8,13,6,5,15,13,11,11]

/-! ## Round constants (C L45-54) -/

def S_K1 : Array UInt32 := #[0x00000000, 0x5A827999, 0x6ED9EBA1, 0x8F1BBCDC, 0xA953FD4E]

def S_K2 : Array UInt32 := #[0x50A28BE6, 0x5C4DD124, 0x6D703EF3, 0x7A6D76E9, 0x00000000]

/-! ## Clone pins: clones ≡ in-tree originals (the DER-layer T-L em pattern) -/

open Bitcoin.Interpreter (RMD_R1 RMD_R2 RMD_S1 RMD_S2 RMD_K1 RMD_K2)

-- T-pins: each clone = its consensus-path original, one kernel step.
theorem S_R1_eq : S_R1 = RMD_R1 := by rfl
theorem S_R2_eq : S_R2 = RMD_R2 := by rfl
theorem S_S1_eq : S_S1 = RMD_S1 := by rfl
theorem S_S2_eq : S_S2 = RMD_S2 := by rfl
theorem S_K1_eq : S_K1 = RMD_K1 := by rfl
theorem S_K2_eq : S_K2 = RMD_K2 := by rfl

-- Table lengths (the 80-step fold's r/s-index domain).
theorem S_R1_len : S_R1.size = 80 := by decide
theorem S_R2_len : S_R2.size = 80 := by decide
theorem S_S1_len : S_S1.size = 80 := by decide
theorem S_S2_len : S_S2.size = 80 := by decide
theorem S_K1_len : S_K1.size = 5 := by decide
theorem S_K2_len : S_K2.size = 5 := by decide

-- Round-constant spots (C L45-54; kL[0]=kR[4]=0 = the R11/R52 zero
-- constants; 0xA953FD4E = R51 left, 0x50A28BE6 = R12 right).
theorem S_K1_0 : S_K1[0]! = 0x00000000 := by decide
theorem S_K1_1 : S_K1[1]! = 0x5A827999 := by decide
theorem S_K1_2 : S_K1[2]! = 0x6ED9EBA1 := by decide
theorem S_K1_3 : S_K1[3]! = 0x8F1BBCDC := by decide
theorem S_K1_4 : S_K1[4]! = 0xA953FD4E := by decide
theorem S_K2_0 : S_K2[0]! = 0x50A28BE6 := by decide
theorem S_K2_1 : S_K2[1]! = 0x5C4DD124 := by decide
theorem S_K2_2 : S_K2[2]! = 0x6D703EF3 := by decide
theorem S_K2_3 : S_K2[3]! = 0x7A6D76E9 := by decide
theorem S_K2_4 : S_K2[4]! = 0x00000000 := by decide

-- Selection-table boundary spots (C L64 first R11(w0,11)/R12(w5,8);
-- L222 last R51(w13,6)/R52(w11,11); group heads L80/L96/L112/L128 =
-- rounds 1..4 left line).
theorem S_R1_0 : S_R1[0]! = 0 := by decide
theorem S_R2_0 : S_R2[0]! = 5 := by decide
theorem S_R1_79 : S_R1[79]! = 13 := by decide
theorem S_R2_79 : S_R2[79]! = 11 := by decide
theorem S_S1_0 : S_S1[0]! = 11 := by decide
theorem S_S2_0 : S_S2[0]! = 8 := by decide
theorem S_S1_79 : S_S1[79]! = 6 := by decide
theorem S_S2_79 : S_S2[79]! = 11 := by decide
theorem S_R1_16 : S_R1[16]! = 7 := by decide
theorem S_R1_32 : S_R1[32]! = 3 := by decide
theorem S_R1_48 : S_R1[48]! = 1 := by decide
theorem S_R1_64 : S_R1[64]! = 4 := by decide

-- Axiom pins (unit-2 evidence).
#print axioms S_R1_eq
#print axioms S_K2_eq
#print axioms S_R1_len
#print axioms S_K1_4
#print axioms S_R2_79

end Bitcoin.Crypto.RipemdDeep
