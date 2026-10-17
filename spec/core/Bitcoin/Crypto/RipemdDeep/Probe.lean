import Bitcoin.Crypto.Seam.Hash
import Bitcoin.Interpreter.Hashes

/-! S06 probe (disposable, committed for the record — E06-Probe pattern).

Round 2 (round 1: 1.3s elaboration — all 15 rmdF/rmdF2-arm `rfl` pins vs
verbatim-C-text Cf1..Cf5 PASSED; all P3 literal `decide`s PASSED incl.
`0xFFFFFFFF ^^^ 1 = 0xFFFFFFFE` and a 16-push-ByteArray-fold = replicate;
`#eval hashRipemd160` (80 rounds, compiled) runs <1s; failures: `open A.B
(C D)` with a nested-ns C = unknown-constant; `BitVec.xor_ones` doesn't
exist — Basic.lean:569 `not x := allOnes n ^^^ x` + :784 `not_eq .. :=
(rfl)` instead; `List.asByteArray` → `List.toByteArray`).

P1 (xox) now has 4 routes: (rfl?) / (rw xor_comm?) /
(congrArg-ofBitVec + xor_comm + 0xFFFFFFFF=allOnes-by-decide) / (bv_decide?)
-/

open Bitcoin.Crypto.Seam.Hash
open Bitcoin.Interpreter (hashRipemd160 hashSha1 wordLE mdPad rmdF rmdF2
  rmdCompress hashSha256 hashHash160 RMD_R1 RMD_R2 RMD_S1 RMD_S2 RMD_K1 RMD_K2)

set_option maxRecDepth 100000

def hexOf (b : ByteArray) : String :=
  (List.range b.size).foldl (fun acc i =>
    let v := b[i]!.toNat
    acc ++ "0123456789abcdef".toList[v / 16]!.toString
        ++ "0123456789abcdef".toList[v % 16]!.toString) ""

private def a55 : ByteArray := List.replicate 55 0x61 |>.toByteArray
private def a56 : ByteArray := List.replicate 56 0x61 |>.toByteArray
private def a119 : ByteArray := List.replicate 119 0x61 |>.toByteArray
private def a120 : ByteArray := List.replicate 120 0x61 |>.toByteArray

/-! ## P0 — #eval values (native compiler; sanity only, NOT proof) -/

#eval hexOf (Ripemd160.ripemd160 ByteArray.empty)          -- 9c1185a5c5e9fc54612808977ee8f548b2258d31
#eval hexOf (Ripemd160.ripemd160 "a".toUTF8)               -- 0bdc9d2d256b3ee9daae347be6f4dc835a867360
#eval hexOf (Ripemd160.ripemd160 "abc".toUTF8)             -- 8eb208f7e05d987a9b044a8e98c6b087f15a0bfc
#eval hexOf (Ripemd160.ripemd160 "message digest".toUTF8)  -- 5d0689ef49d2fae572b88123a85ffa21595f36
#eval hexOf (Ripemd160.ripemd160 "abcdefghijklmnopqrstuvwxyz".toUTF8) -- f71c27109c692c1b56bbdceb5b9d2865b3708dbc
#eval hexOf (hashRipemd160 "abc".toUTF8)                   -- same as above (2-impl agree)
#eval hexOf (hashRipemd160 a55) ++ "/" ++ hexOf (hashRipemd160 a56)  -- 2-block boundary
#eval (mdPad a55 false).size    -- 64
#eval (mdPad a56 false).size    -- 128
#eval (mdPad a119 false).size   -- 128
#eval (mdPad a120 false).size   -- 192
#eval (Ripemd160.pad a56).size  -- 128
#eval (Ripemd160.compress (Ripemd160.pad "a".toUTF8)).toList.map (·.toNat)
#eval (Ripemd160.ripemd160 a56).data.toList.map (·.toNat) -- python: rmd('a'*56)

/-! ## P1 — `x ^^^ 0xFFFFFFFF = ~~~x` (Seam ^^^-ones-arms ↔ C/Interpreter ~~~-arms) -/

example (x : UInt32) : (x ^^^ 0xFFFFFFFF) = ~~~x := by rfl

example (x : UInt32) : (x ^^^ 0xFFFFFFFF) = ~~~x := by
  apply congrArg UInt32.ofBitVec
  rw [BitVec.xor_comm]

example (x : UInt32) : (x ^^^ 0xFFFFFFFF) = ~~~x := by
  apply congrArg UInt32.ofBitVec
  rw [BitVec.xor_comm]
  exact congrArg (· ^^^ x.toBitVec) (by decide : (0xFFFFFFFF : BitVec 32) = BitVec.allOnes 32)

private theorem xox (x : UInt32) : (x ^^^ 0xFFFFFFFF) = ~~~x := by
  apply congrArg UInt32.ofBitVec
  rw [BitVec.xor_comm]
  exact congrArg (· ^^^ x.toBitVec) (by decide : (0xFFFFFFFF : BitVec 32) = BitVec.allOnes 32)

#print axioms xox

/-! ## P2 — the f-layer (both impls vs verbatim-C-text Cf1..Cf5) -/

private def Cf1 (x y z : UInt32) : UInt32 := x ^^^ y ^^^ z
private def Cf2 (x y z : UInt32) : UInt32 := (x &&& y) ||| (~~~x &&& z)
private def Cf3 (x y z : UInt32) : UInt32 := (x ||| ~~~y) ^^^ z
private def Cf4 (x y z : UInt32) : UInt32 := (x &&& z) ||| (y &&& ~~~z)
private def Cf5 (x y z : UInt32) : UInt32 := x ^^^ (y ||| ~~~z)

example (b c d : UInt32) : rmdF 0 b c d = Cf1 b c d := by rfl
example (b c d : UInt32) : rmdF 1 b c d = Cf2 b c d := by rfl
example (b c d : UInt32) : rmdF 2 b c d = Cf3 b c d := by rfl
example (b c d : UInt32) : rmdF 3 b c d = Cf4 b c d := by rfl
example (b c d : UInt32) : rmdF 4 b c d = Cf5 b c d := by rfl
example (b c d : UInt32) : rmdF2 0 b c d = Cf5 b c d := by rfl
example (b c d : UInt32) : rmdF2 1 b c d = Cf4 b c d := by rfl
example (b c d : UInt32) : rmdF2 2 b c d = Cf3 b c d := by rfl
example (b c d : UInt32) : rmdF2 3 b c d = Cf2 b c d := by rfl
example (b c d : UInt32) : rmdF2 4 b c d = Cf1 b c d := by rfl

-- Seam `f` (^^^-ones arms) vs C-text — via xox, pointwise:
example (x y z : UInt32) :
    Bitcoin.Crypto.Seam.Hash.Ripemd160.f 1 x y z = Cf2 x y z := by
  show (x &&& y) ||| ((x ^^^ 0xFFFFFFFF) &&& z) = (x &&& y) ||| (~~~x &&& z)
  rw [xox x]

example (x y z : UInt32) :
    Bitcoin.Crypto.Seam.Hash.Ripemd160.f 2 x y z = Cf3 x y z := by
  show (x ||| (y ^^^ 0xFFFFFFFF)) ^^^ z = (x ||| ~~~y) ^^^ z
  rw [xox y]

example (x y z : UInt32) :
    Bitcoin.Crypto.Seam.Hash.Ripemd160.f 3 x y z = Cf4 x y z := by
  show (x &&& z) ||| (y &&& (z ^^^ 0xFFFFFFFF)) = (x &&& z) ||| (y &&& ~~~z)
  rw [xox z]

example (x y z : UInt32) :
    Bitcoin.Crypto.Seam.Hash.Ripemd160.f 4 x y z = Cf5 x y z := by
  show x ^^^ (y ||| (z ^^^ 0xFFFFFFFF)) = x ^^^ (y ||| ~~~z)
  rw [xox z]

example (x y z : UInt32) :
    Bitcoin.Crypto.Seam.Hash.Ripemd160.f 0 x y z = Cf1 x y z := by
  show x ^^^ y ^^^ z = x ^^^ y ^^^ z
  rfl

/-! ## P3 — literal `by decide` costs (round-1: all passed) -/
example : RMD_K2[3]! = (0x7A6D76E9 : UInt32) := by decide
example : (0xFFFFFFFF : UInt32) ^^^ 1 = 0xFFFFFFFE := by decide
example : (List.range 16).foldl (fun a _ => a.push 0x61) ByteArray.empty
    = List.replicate 16 0x61 |>.toByteArray := by decide
example : (rmdF 1 5 7 9 : UInt32) = (5 : UInt32) &&& 7 ||| (~~~(5 : UInt32) &&& 9) := by decide
example : BitVec.xor (0xF0F0F0F0 : BitVec 32) (0x0F0F0F0F : BitVec 32)
    = (0xFFFFFFFF : BitVec 32) := by decide
example : (0xFFFFFFFF : BitVec 32) = BitVec.allOnes 32 := by decide
