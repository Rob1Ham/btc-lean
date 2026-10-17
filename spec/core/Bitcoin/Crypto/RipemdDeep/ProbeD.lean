import Bitcoin.Crypto.Seam.Hash
import Bitcoin.Interpreter.Hashes

/-! S06 ProbeD (disposable) — THE kernel-decidability ladder.

The brief's core question: is the 80-step/2-line RIPEMD-160 compression
kernel-decidable via `by decide` (structural List.range-folds, D-004-clean),
or does it hit the Y10/X11 wall (elaborator-stuck-on-ByteArray-decEq /
byte-heavy decide OOM)?

Ladder, lightest-first (one file = one cost level; shell `timeout 360`
boxes the whole run — a stall here is a FINDING, cf. Y10 F-Y10-005):

* D1  pad size, 0-byte msg   (List.range 55/8 folds, 63 pushes, size-Nat)
* D2  pad size, 1-byte msg   (same shape)
* D3  pad CONTENT, 0-byte msg (full 64-byte ByteArray decEq — the Y10 path)
* D4  pad CONTENT, 1-byte msg ("a" + pad = 64 bytes)
* D5  single-block COMPRESS, empty msg (16 zero words: the 80×2-line
      machine on all-zero x — no digest assembly, Array UInt32 5-eq)
* D6  single-block COMPRESS, "a" (real data words)
* D7  full `ripemd160 "a"` = 20-byte digest (ByteArray decEq post-compress)
* D8  2-block: `ripemd160 (a56)` (128-pad + 2 compresses)
* D9  the INTERPRETER twin: `hashRipemd160 "a"` = consensus-path digest

#eval expected values (python3-hashlib-verified, 2026-10-17, 7/7 incl.
both impls): "" → 9c1185a5c5e9fc54612808977ee8f548b2258d31,
"a" → 0bdc9d2d256b3ee9daae347be6f4dc835a467ffe,
"a"*56 → e72334b46c83cc70bef979e15453706c95b888be.
-/

open Bitcoin.Crypto.Seam.Hash
open Bitcoin.Interpreter (hashRipemd160 mdPad)

set_option maxRecDepth 100000
set_option maxHeartbeats 2000000
-- D9 attempt 1 hit maxRecDepth (79:64); D7 clean: quantified comparison next run

private def a56 : ByteArray := List.replicate 56 0x61 |>.toByteArray
private def a100 : ByteArray := List.replicate 100 0x61 |>.toByteArray

#eval (Ripemd160.pad ByteArray.empty).size          -- 64
#eval (Ripemd160.pad "a".toUTF8).size               -- 64
#eval (Ripemd160.pad a56).size                      -- 128
#eval (Ripemd160.compress (Ripemd160.pad "a".toUTF8)).toList.map (·.toNat)
#eval (Ripemd160.ripemd160 a56).data.toList.map (·.toNat)
#eval (Ripemd160.ripemd160 a100).data.toList.map (·.toNat)

/-! D1/D2: pad size -/

theorem D1 : (Ripemd160.pad ByteArray.empty).size = 64 := by decide
theorem D2 : (Ripemd160.pad "a".toUTF8).size = 64 := by decide
theorem D2b : (Ripemd160.pad a56).size = 128 := by decide

/-! D3/D4: pad content (full ByteArray decEq — the Y10 danger path) -/

theorem D3 : (Ripemd160.pad ByteArray.empty).data.toList.map (·.toNat)
    = (0x80 :: List.replicate 55 0 ++ List.replicate 8 0) := by decide

theorem D4 : (Ripemd160.pad "a".toUTF8).data.toList.map (·.toNat)
    = (0x61 :: 0x80 :: List.replicate 54 0 ++ (8 :: List.replicate 7 0)) := by decide

/-! D5/D6: single-block compression (Array UInt32 5-eq) -/

theorem D5 : (Ripemd160.compress (Ripemd160.pad ByteArray.empty)).toList.map (·.toNat)
    = [2776961436, 1425861061, 2533894241, 1224075390, 831333810] := by decide

theorem D6 : (Ripemd160.compress (Ripemd160.pad "a".toUTF8)).toList.map (·.toNat)
    = [765320203, 3913181989, 2067050202, 2212295910, 4269753946] := by decide

/-! D7/D8: full digest (ByteArray decEq post-compress) -/

theorem D7 : (Ripemd160.ripemd160 "a".toUTF8).data.toList.map (·.toNat)
    = [0x0b,0xdc,0x9d,0x2d,0x25,0x6b,0x3e,0xe9,0xda,0xae,
       0x34,0x7b,0xe6,0xf4,0xdc,0x83,0x5a,0x46,0x7f,0xfe] := by decide

/-! D9: the consensus-path twin (Interpreter/Hashes.lean) — STUCK, see F-S06-001.

`hashRipemd160 "a"` (=`rmdCompress` with the x-load
`(List.range 16).toArray.map (fun i => wordLE block (off + 4*i))`,
Interpreter/Hashes.lean:212) hits `maximum recursion depth` by decide at
maxRecDepth 100k AND 1000000 (4x reproduced; #eval = correct values).
Root cause isolated (ProbeR): `Array.map` over a `List.toArray` value =
"decide failed to reduce" even at 16 elements (H1); push-fold x-load =
`rmdCompress` verbatim otherwise = `by decide` CLEAN at 100k, correct
values (G1). Commented out to keep this file error-clean; the stall
itself is the F-S06-001 evidence.
theorem D9 : (hashRipemd160 "a".toUTF8).data.toList.map (·.toNat)
    = [0x0b,0xdc,0x9d,0x2d,0x25,0x6b,0x3e,0xe9,0xda,0xae,
       0x34,0x7b,0xe6,0xf4,0xdc,0x83,0x5a,0x46,0x7f,0xfe] := by decide
-/


#print axioms D1
#print axioms D5
#print axioms D7
