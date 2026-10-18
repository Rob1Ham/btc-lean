import Bitcoin.Crypto.EcdsaDeep.PubKeyParse
import Bitcoin.Interpreter.Defs
import Bitcoin.Crypto.Ecdsa.Der
import Bitcoin.Crypto.Curve.Secp
import Bitcoin.Crypto.Curve.Mod
import Bitcoin.Data.Basic
import Bitcoin.Activation.Flags
import Bitcoin.Script.Tapscript.Delta

/-!
# [S15] PubKeyMatrix — the Core pubkey acceptance matrix
# (proofs/BitcoinProofs/EcdsaDeep/, S15's home).

## Purpose

The Core `pubkey.cpp` acceptance matrix (CPubKey::GetLen/
ValidSize/Set @ pubkey.h:69-105; `secp256k1_ec_pubkey_parse` @
secp256k1.c:265-281 → `ge_parse` @ group_impl.h:1084-1102;
`CPubKey::Verify` @ pubkey.cpp:283-299) = every length/prefix
case (33-byte 02/03, 65-byte 04/06/07, invalid lengths, hybrid
parity mismatch) vs our pubkey parse acceptance, as a kernel-
decide matrix (D-004-clean: no native_decide) + SGN row
cross-refs (SGN-101..111 span seam+verifier).

GENERATED originally by gen_pubkey_matrix.py; that generator is not part of
this repository, so the matrix is now maintained by hand. The five 33-byte
Some-path rows whose verdict needs `sqrtP` are not kernel-decided and are
listed explicitly in the R6 section at the end of this file.
Oracle = a transliteration of the C ONLY (NO Lean code was
consulted) over the pubkey columns of the 215-vector
battery (EcdsaTest.lean pk-* pkform-* core-*), the pyC-vs-C
tags/lengths synthetic corpus (12 tags x 8 lengths), 65B-lane
mutants on the real pkform-000 curve point, and synthetic
33B-lane None-paths.

## The R6 boundary (kernel-decidable vs pyC TRUTH)

* 65B lane (tags 04/06/07): x,y < P (fe_set_b32_limit) = Nat
  GMP; hybrid parity = y%2 Nat; onCurveN = mulM/addM GMP —
  **fully kernel-decidable** (all M4 rows decide).
* 33B lane (tags 02/03): x >= P check (None) = decide; the
  Some-path needs `sqrtP = expM` = **WF-recursive = R6 wall**
  (F-W14b-1). R6 rows (pk-compressed-wrong-parity, core-* 33B
  Some) = pyC TRUTH = PROPOSED (kernel-decide blocked).
-/
namespace Bitcoin.Proofs.EcdsaDeep.PubKeyMatrix

set_option maxRecDepth 100000
set_option maxHeartbeats 4000000

open Bitcoin.Crypto.EcdsaDeep.PubKeyParse

/-! ## M0b — test infra (fromHex, copied verbatim from the
harness EcdsaTest.lean:36-52 / E05 DerBatteryCor, read-only) -/

private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

private def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

/-! ## M2 — `CPubKey::GetLen` (pubkey.h:69-76)
12 tags x the GetLen value. -/
-- M2-GetLen-00
example : pubKeyLen 0 = 0 := by decide

-- M2-GetLen-01
example : pubKeyLen 1 = 0 := by decide

-- M2-GetLen-02
example : pubKeyLen 2 = 33 := by decide

-- M2-GetLen-03
example : pubKeyLen 3 = 33 := by decide

-- M2-GetLen-04
example : pubKeyLen 4 = 65 := by decide

-- M2-GetLen-05
example : pubKeyLen 5 = 0 := by decide

-- M2-GetLen-06
example : pubKeyLen 6 = 65 := by decide

-- M2-GetLen-07
example : pubKeyLen 7 = 65 := by decide

-- M2-GetLen-08
example : pubKeyLen 8 = 0 := by decide

-- M2-GetLen-7f
example : pubKeyLen 127 = 0 := by decide

-- M2-GetLen-fe
example : pubKeyLen 254 = 0 := by decide

-- M2-GetLen-ff
example : pubKeyLen 255 = 0 := by decide

/-! ## M1 — `CPubKey::ValidSize` (pubkey.h:86-88)
12 tags x 8 lengths (96 rows). -/
-- M1-ValidSize-00-0
example : validPubKeySize (fromHex "") = false := by decide

-- M1-ValidSize-00-1
example : validPubKeySize (fromHex "00") = false := by decide

-- M1-ValidSize-00-32
example : validPubKeySize (fromHex "0011111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-00-33
example : validPubKeySize (fromHex "001111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-00-34
example : validPubKeySize (fromHex "00111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-00-64
example : validPubKeySize (fromHex "00111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-00-65
example : validPubKeySize (fromHex "0011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-00-66
example : validPubKeySize (fromHex "001111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-01-0
example : validPubKeySize (fromHex "") = false := by decide

-- M1-ValidSize-01-1
example : validPubKeySize (fromHex "01") = false := by decide

-- M1-ValidSize-01-32
example : validPubKeySize (fromHex "0111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-01-33
example : validPubKeySize (fromHex "011111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-01-34
example : validPubKeySize (fromHex "01111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-01-64
example : validPubKeySize (fromHex "01111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-01-65
example : validPubKeySize (fromHex "0111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-01-66
example : validPubKeySize (fromHex "011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-02-0
example : validPubKeySize (fromHex "") = false := by decide

-- M1-ValidSize-02-1
example : validPubKeySize (fromHex "02") = false := by decide

-- M1-ValidSize-02-32
example : validPubKeySize (fromHex "0211111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-02-33
example : validPubKeySize (fromHex "021111111111111111111111111111111111111111111111111111111111111111") = true := by decide

-- M1-ValidSize-02-34
example : validPubKeySize (fromHex "02111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-02-64
example : validPubKeySize (fromHex "02111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-02-65
example : validPubKeySize (fromHex "0211111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-02-66
example : validPubKeySize (fromHex "021111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-03-0
example : validPubKeySize (fromHex "") = false := by decide

-- M1-ValidSize-03-1
example : validPubKeySize (fromHex "03") = false := by decide

-- M1-ValidSize-03-32
example : validPubKeySize (fromHex "0311111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-03-33
example : validPubKeySize (fromHex "031111111111111111111111111111111111111111111111111111111111111111") = true := by decide

-- M1-ValidSize-03-34
example : validPubKeySize (fromHex "03111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-03-64
example : validPubKeySize (fromHex "03111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-03-65
example : validPubKeySize (fromHex "0311111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-03-66
example : validPubKeySize (fromHex "031111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-04-0
example : validPubKeySize (fromHex "") = false := by decide

-- M1-ValidSize-04-1
example : validPubKeySize (fromHex "04") = false := by decide

-- M1-ValidSize-04-32
example : validPubKeySize (fromHex "0411111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-04-33
example : validPubKeySize (fromHex "041111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-04-34
example : validPubKeySize (fromHex "04111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-04-64
example : validPubKeySize (fromHex "04111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-04-65
example : validPubKeySize (fromHex "0411111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = true := by decide

-- M1-ValidSize-04-66
example : validPubKeySize (fromHex "041111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-05-0
example : validPubKeySize (fromHex "") = false := by decide

-- M1-ValidSize-05-1
example : validPubKeySize (fromHex "05") = false := by decide

-- M1-ValidSize-05-32
example : validPubKeySize (fromHex "0511111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-05-33
example : validPubKeySize (fromHex "051111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-05-34
example : validPubKeySize (fromHex "05111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-05-64
example : validPubKeySize (fromHex "05111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-05-65
example : validPubKeySize (fromHex "0511111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-05-66
example : validPubKeySize (fromHex "051111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-06-0
example : validPubKeySize (fromHex "") = false := by decide

-- M1-ValidSize-06-1
example : validPubKeySize (fromHex "06") = false := by decide

-- M1-ValidSize-06-32
example : validPubKeySize (fromHex "0611111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-06-33
example : validPubKeySize (fromHex "061111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-06-34
example : validPubKeySize (fromHex "06111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-06-64
example : validPubKeySize (fromHex "06111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-06-65
example : validPubKeySize (fromHex "0611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = true := by decide

-- M1-ValidSize-06-66
example : validPubKeySize (fromHex "061111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-07-0
example : validPubKeySize (fromHex "") = false := by decide

-- M1-ValidSize-07-1
example : validPubKeySize (fromHex "07") = false := by decide

-- M1-ValidSize-07-32
example : validPubKeySize (fromHex "0711111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-07-33
example : validPubKeySize (fromHex "071111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-07-34
example : validPubKeySize (fromHex "07111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-07-64
example : validPubKeySize (fromHex "07111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-07-65
example : validPubKeySize (fromHex "0711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = true := by decide

-- M1-ValidSize-07-66
example : validPubKeySize (fromHex "071111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-08-0
example : validPubKeySize (fromHex "") = false := by decide

-- M1-ValidSize-08-1
example : validPubKeySize (fromHex "08") = false := by decide

-- M1-ValidSize-08-32
example : validPubKeySize (fromHex "0811111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-08-33
example : validPubKeySize (fromHex "081111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-08-34
example : validPubKeySize (fromHex "08111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-08-64
example : validPubKeySize (fromHex "08111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-08-65
example : validPubKeySize (fromHex "0811111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-08-66
example : validPubKeySize (fromHex "081111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-7f-0
example : validPubKeySize (fromHex "") = false := by decide

-- M1-ValidSize-7f-1
example : validPubKeySize (fromHex "7f") = false := by decide

-- M1-ValidSize-7f-32
example : validPubKeySize (fromHex "7f11111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-7f-33
example : validPubKeySize (fromHex "7f1111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-7f-34
example : validPubKeySize (fromHex "7f111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-7f-64
example : validPubKeySize (fromHex "7f111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-7f-65
example : validPubKeySize (fromHex "7f11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-7f-66
example : validPubKeySize (fromHex "7f1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-fe-0
example : validPubKeySize (fromHex "") = false := by decide

-- M1-ValidSize-fe-1
example : validPubKeySize (fromHex "fe") = false := by decide

-- M1-ValidSize-fe-32
example : validPubKeySize (fromHex "fe11111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-fe-33
example : validPubKeySize (fromHex "fe1111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-fe-34
example : validPubKeySize (fromHex "fe111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-fe-64
example : validPubKeySize (fromHex "fe111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-fe-65
example : validPubKeySize (fromHex "fe11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-fe-66
example : validPubKeySize (fromHex "fe1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-ff-0
example : validPubKeySize (fromHex "") = false := by decide

-- M1-ValidSize-ff-1
example : validPubKeySize (fromHex "ff") = false := by decide

-- M1-ValidSize-ff-32
example : validPubKeySize (fromHex "ff11111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-ff-33
example : validPubKeySize (fromHex "ff1111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-ff-34
example : validPubKeySize (fromHex "ff111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-ff-64
example : validPubKeySize (fromHex "ff111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-ff-65
example : validPubKeySize (fromHex "ff11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M1-ValidSize-ff-66
example : validPubKeySize (fromHex "ff1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

/-! ## M2b — ge_parse tag/size dispatch (group_impl.h:1084-1101)
33B tags NOT in {02,03} = None; 65B tags NOT in {04,06,07} = None;
33B/65B tags in the other lane's tag set = None. (25 rows) -/
-- M2b-33B-00
example : parsePubKeyDeep (fromHex "001111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-33B-01
example : parsePubKeyDeep (fromHex "011111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-33B-02 [R6: 33B Some-path, sqrtP; not kernel-checked — see the R6 list at end]

-- M2b-33B-03 [R6: 33B Some-path, sqrtP; not kernel-checked — see the R6 list at end]

-- M2b-33B-05
example : parsePubKeyDeep (fromHex "051111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-33B-08
example : parsePubKeyDeep (fromHex "081111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-33B-7f
example : parsePubKeyDeep (fromHex "7f1111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-33B-fe
example : parsePubKeyDeep (fromHex "fe1111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-33B-ff
example : parsePubKeyDeep (fromHex "ff1111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-65B-00
example : parsePubKeyDeep (fromHex "0011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-65B-01
example : parsePubKeyDeep (fromHex "0111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-65B-05
example : parsePubKeyDeep (fromHex "0511111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-65B-08
example : parsePubKeyDeep (fromHex "0811111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-65B-7f
example : parsePubKeyDeep (fromHex "7f11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-65B-fe
example : parsePubKeyDeep (fromHex "fe11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-65B-ff
example : parsePubKeyDeep (fromHex "ff11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-33B-02-len64
example : parsePubKeyDeep (fromHex "02111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-33B-02-len66
example : parsePubKeyDeep (fromHex "021111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-33B-03-len64
example : parsePubKeyDeep (fromHex "03111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-33B-03-len66
example : parsePubKeyDeep (fromHex "031111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-65B-04-len33
example : parsePubKeyDeep (fromHex "041111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-65B-06-len33
example : parsePubKeyDeep (fromHex "061111111111111111111111111111111111111111111111111111111111111111") = none := by decide

-- M2b-65B-07-len33
example : parsePubKeyDeep (fromHex "071111111111111111111111111111111111111111111111111111111111111111") = none := by decide

/-! ## M2c — 33B lane x >= P (fe_set_b32_limit, group_impl.h:1087)
(33B Some-path = sqrtP = expM = WF = R6; NOT kernel rows) -/
-- M2c-33B-02-xgeP
example : parsePubKeyDeep (fromHex "02ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff") = none := by decide

-- M2c-33B-03-xgeP
example : parsePubKeyDeep (fromHex "03ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff") = none := by decide

/-! ## M4 — the 65B lane (tags 04/06/07, group_impl.h:1090-1098)
The pk-pubkey columns (pkfield pk pkform pk) + synthetic mutants
on the real pkform-000 point. -/
-- M4-pk-badtag
example : parsePubKeyDeep (fromHex "05f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = none := by decide

-- M4-pk-x-ge-p
example : parsePubKeyDeep (fromHex "03fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f") = none := by decide

-- M4-pk-offcurve
example : parsePubKeyDeep (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") = none := by decide

-- M4-pk-short
example : parsePubKeyDeep (fromHex "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a411") = none := by decide

-- M4-pk-long
example : parsePubKeyDeep (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b00") = none := by decide

-- M4-pk-hybrid-wrong-parity
example : parsePubKeyDeep (fromHex "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = none := by decide

-- M4-pk-hybrid-even-tag-odd-y
example : parsePubKeyDeep (fromHex "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") = none := by decide

-- M4-pk-empty
example : parsePubKeyDeep (fromHex "") = none := by decide

-- M4-pk-garbage
example : parsePubKeyDeep (fromHex "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20") = none := by decide

-- M4-pkform-uncompressed-000
example : parsePubKeyDeep (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = some (109826320138395729779344973899952261859843783151338878966742341141794312688029, 7178900391585363589674616835382523547703372413034984228995838988246862024539) := by decide

-- M4-pkform-hybrid-001
example : parsePubKeyDeep (fromHex "07de7d0279cf7fa80af8571f42cd30b785f7a1fc6b2c96c5250d065f24cdfe9f2af2bae572672f44cdfcf31d87201c3ae9bc142774045e4fef17b872ab68eb8561") = some (100634325356080835745968891523342347392909452903574082640796070279057762066218, 109789926495413191851132286863257181680439544913400092569456951507668150486369) := by decide

-- M4-pkform-uncompressed-002
example : parsePubKeyDeep (fromHex "04f86ac12b105f58d6c64265900753edbf4c98e6785262a2adb166606b42b18ef1d2a3bc132e6f47f23e3b80e39ad65cb06e2f9a5341aabfee6d47e1ed06637cdf") = some (112362205435563430480450972552023641324087582466744390220694597292916219154161, 95274992319487145287379336249972521317302144954663874313837388499954794986719) := by decide

-- M4-pkform-hybrid-003
example : parsePubKeyDeep (fromHex "077a71ebb83f7a7f9c5112a08c70784163edfd71dd3c6734792dc75434b24b0e30ffe63a7e773c7479664610af26c4483896120045e7d6f48d09cb8a640ef0177d") = some (55383448123185206675461019052291996420480952127613798838785344163222047624752, 115746554924430383788450415582876640935209149582542773207827656221101592156029) := by decide

-- M4-pkform-uncompressed-004
example : parsePubKeyDeep (fromHex "04d6e70fd5c439e2e9e85a8b94594bc4449b1998ecee74bb367d7b4e556b75946984090d56529f392b98fc3829f6169e22699d12ee48dd2f58d537a9d22ac1c0fa") = some (97203200558111678096807238402573187039558939986659073218313812215121613001833, 59721289686533198968639589422847248351255835126736102554354387956142098727162) := by decide

-- M4-pkform-hybrid-005
example : parsePubKeyDeep (fromHex "07757404cf6fe5e02f369002bad98762521c93342dfee6f0b7a78c5354e17058243b74ce5b4492aded634a5b5edec9baabb16f49d2afb77e7586d9104a31dde9bb") = some (53125590743235037045948228462357570406578565455199494147467885869427141400612, 26892836546251171303299696558074578362746804260565125079622984324956311906747) := by decide

-- M4-pkform-uncompressed-006
example : parsePubKeyDeep (fromHex "042da6e846e114f65e7fa2597a1c408d49827605a3ad4eee336421f6f07513519b51cad88d75e63fd6b82770c111d68f3edb5fd4fe8114caaebb9d774a5f080f78") = some (20648977915052810435001889892639505618876047233835505643265142240264959775131, 36995738433309455145012544422624606203753194953751655647487987512734153969528) := by decide

-- M4-pkform-hybrid-007
example : parsePubKeyDeep (fromHex "072269827313445de78b0ccf7190a0bea22c32b40fc0c6fd0f217b83221a4b86206b49fdd6ccfd92146788ebbef0ee94cfe3f2c0b139dcc47184b03b45ee975bef") = some (15565056123080795072750371667820675169107230742658088097799293789593488033312, 48528206566980670799551798865177701737865520672271219078907962090196554963951) := by decide

-- M4-pkform-uncompressed-008
example : parsePubKeyDeep (fromHex "04971b7cdaafcfb98aa775d01eb6c156d2f04a7030380c8e654565b06d900bc828cc392eb1228696858814fe7deaa7bba2b71aed228367e5162f988c845f44c95a") = some (68347806719152720546743034175518441926560310773391834590145543316011087546408, 92372853649557207784840937829343206762998901391542870618114612643456530827610) := by decide

-- M4-pkform-hybrid-009
example : parsePubKeyDeep (fromHex "0637eb42b937c48c6b8f28246defbbbb4e0522c63acc273383717107bbe6bbb2f7f244c4ea3d7500a56a1cb86575af22e5dec625085bd766797d23cb2433ab2ad8") = some (25292876241024624689628897406108804444916397923621402681925632763437797585655, 109581214014939069022915443459776412186586533735033484438455246648138086951640) := by decide

-- M4-syn-04-on
example : parsePubKeyDeep (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = some (109826320138395729779344973899952261859843783151338878966742341141794312688029, 7178900391585363589674616835382523547703372413034984228995838988246862024539) := by decide

-- M4-syn-04-on-flip
example : parsePubKeyDeep (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119df020e2e91fa3bef5962e50e1588591154b7dd7babe326e1608616cc8aee3acd4") = some (109826320138395729779344973899952261859843783151338878966742341141794312688029, 108613188845730831833896368173305384305566612252605579810461745019661972647124) := by decide

-- M4-syn-04-offcurve
example : parsePubKeyDeep (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") = none := by decide

-- M4-syn-04-xgeP
example : parsePubKeyDeep (fromHex "04ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = none := by decide

-- M4-syn-04-ygeP
example : parsePubKeyDeep (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff") = none := by decide

-- M4-syn-06-on
example : parsePubKeyDeep (fromHex "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = none := by decide

-- M4-syn-06-on-flip
example : parsePubKeyDeep (fromHex "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119df020e2e91fa3bef5962e50e1588591154b7dd7babe326e1608616cc8aee3acd4") = some (109826320138395729779344973899952261859843783151338878966742341141794312688029, 108613188845730831833896368173305384305566612252605579810461745019661972647124) := by decide

-- M4-syn-06-offcurve
example : parsePubKeyDeep (fromHex "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") = none := by decide

-- M4-syn-06-xgeP
example : parsePubKeyDeep (fromHex "06ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = none := by decide

-- M4-syn-06-ygeP
example : parsePubKeyDeep (fromHex "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff") = none := by decide

-- M4-syn-07-on
example : parsePubKeyDeep (fromHex "07f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = some (109826320138395729779344973899952261859843783151338878966742341141794312688029, 7178900391585363589674616835382523547703372413034984228995838988246862024539) := by decide

-- M4-syn-07-on-flip
example : parsePubKeyDeep (fromHex "07f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119df020e2e91fa3bef5962e50e1588591154b7dd7babe326e1608616cc8aee3acd4") = none := by decide

-- M4-syn-07-offcurve
example : parsePubKeyDeep (fromHex "07f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") = none := by decide

-- M4-syn-07-xgeP
example : parsePubKeyDeep (fromHex "07ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = none := by decide

-- M4-syn-07-ygeP
example : parsePubKeyDeep (fromHex "07f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119dffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff") = none := by decide

/-! ## M5 — interpreter-side map (IsCompressedOrUncompressed/
IsCompressedPubKey, interpreter.cpp:74-99) -/
-- M5-pk-badtag-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "05f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = false := by decide

-- M5-pk-badtag-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "05f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = false := by decide

-- M5-pk-x-ge-p-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "03fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f") = true := by decide

-- M5-pk-x-ge-p-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "03fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f") = true := by decide

-- M5-pk-offcurve-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") = true := by decide

-- M5-pk-offcurve-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") = false := by decide

-- M5-pk-short-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a411") = false := by decide

-- M5-pk-short-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a411") = false := by decide

-- M5-pk-long-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b00") = false := by decide

-- M5-pk-long-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b00") = false := by decide

-- M5-pk-hybrid-wrong-parity-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = false := by decide

-- M5-pk-hybrid-wrong-parity-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = false := by decide

-- M5-pk-hybrid-even-tag-odd-y-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") = false := by decide

-- M5-pk-hybrid-even-tag-odd-y-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") = false := by decide

-- M5-pk-empty-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "") = false := by decide

-- M5-pk-empty-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "") = false := by decide

-- M5-pk-garbage-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20") = false := by decide

-- M5-pk-garbage-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20") = false := by decide

-- M5-pk-compressed-wrong-parity-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "02f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") = true := by decide

-- M5-pk-compressed-wrong-parity-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "02f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") = true := by decide

-- M5-pkform-uncompressed-000-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = true := by decide

-- M5-pkform-uncompressed-000-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = false := by decide

-- M5-pkform-hybrid-001-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "07de7d0279cf7fa80af8571f42cd30b785f7a1fc6b2c96c5250d065f24cdfe9f2af2bae572672f44cdfcf31d87201c3ae9bc142774045e4fef17b872ab68eb8561") = false := by decide

-- M5-pkform-hybrid-001-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "07de7d0279cf7fa80af8571f42cd30b785f7a1fc6b2c96c5250d065f24cdfe9f2af2bae572672f44cdfcf31d87201c3ae9bc142774045e4fef17b872ab68eb8561") = false := by decide

-- M5-pkform-uncompressed-002-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "04f86ac12b105f58d6c64265900753edbf4c98e6785262a2adb166606b42b18ef1d2a3bc132e6f47f23e3b80e39ad65cb06e2f9a5341aabfee6d47e1ed06637cdf") = true := by decide

-- M5-pkform-uncompressed-002-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "04f86ac12b105f58d6c64265900753edbf4c98e6785262a2adb166606b42b18ef1d2a3bc132e6f47f23e3b80e39ad65cb06e2f9a5341aabfee6d47e1ed06637cdf") = false := by decide

-- M5-pkform-hybrid-003-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "077a71ebb83f7a7f9c5112a08c70784163edfd71dd3c6734792dc75434b24b0e30ffe63a7e773c7479664610af26c4483896120045e7d6f48d09cb8a640ef0177d") = false := by decide

-- M5-pkform-hybrid-003-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "077a71ebb83f7a7f9c5112a08c70784163edfd71dd3c6734792dc75434b24b0e30ffe63a7e773c7479664610af26c4483896120045e7d6f48d09cb8a640ef0177d") = false := by decide

-- M5-pkform-uncompressed-004-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "04d6e70fd5c439e2e9e85a8b94594bc4449b1998ecee74bb367d7b4e556b75946984090d56529f392b98fc3829f6169e22699d12ee48dd2f58d537a9d22ac1c0fa") = true := by decide

-- M5-pkform-uncompressed-004-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "04d6e70fd5c439e2e9e85a8b94594bc4449b1998ecee74bb367d7b4e556b75946984090d56529f392b98fc3829f6169e22699d12ee48dd2f58d537a9d22ac1c0fa") = false := by decide

-- M5-pkform-hybrid-005-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "07757404cf6fe5e02f369002bad98762521c93342dfee6f0b7a78c5354e17058243b74ce5b4492aded634a5b5edec9baabb16f49d2afb77e7586d9104a31dde9bb") = false := by decide

-- M5-pkform-hybrid-005-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "07757404cf6fe5e02f369002bad98762521c93342dfee6f0b7a78c5354e17058243b74ce5b4492aded634a5b5edec9baabb16f49d2afb77e7586d9104a31dde9bb") = false := by decide

-- M5-pkform-uncompressed-006-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "042da6e846e114f65e7fa2597a1c408d49827605a3ad4eee336421f6f07513519b51cad88d75e63fd6b82770c111d68f3edb5fd4fe8114caaebb9d774a5f080f78") = true := by decide

-- M5-pkform-uncompressed-006-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "042da6e846e114f65e7fa2597a1c408d49827605a3ad4eee336421f6f07513519b51cad88d75e63fd6b82770c111d68f3edb5fd4fe8114caaebb9d774a5f080f78") = false := by decide

-- M5-pkform-hybrid-007-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "072269827313445de78b0ccf7190a0bea22c32b40fc0c6fd0f217b83221a4b86206b49fdd6ccfd92146788ebbef0ee94cfe3f2c0b139dcc47184b03b45ee975bef") = false := by decide

-- M5-pkform-hybrid-007-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "072269827313445de78b0ccf7190a0bea22c32b40fc0c6fd0f217b83221a4b86206b49fdd6ccfd92146788ebbef0ee94cfe3f2c0b139dcc47184b03b45ee975bef") = false := by decide

-- M5-pkform-uncompressed-008-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "04971b7cdaafcfb98aa775d01eb6c156d2f04a7030380c8e654565b06d900bc828cc392eb1228696858814fe7deaa7bba2b71aed228367e5162f988c845f44c95a") = true := by decide

-- M5-pkform-uncompressed-008-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "04971b7cdaafcfb98aa775d01eb6c156d2f04a7030380c8e654565b06d900bc828cc392eb1228696858814fe7deaa7bba2b71aed228367e5162f988c845f44c95a") = false := by decide

-- M5-pkform-hybrid-009-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "0637eb42b937c48c6b8f28246defbbbb4e0522c63acc273383717107bbe6bbb2f7f244c4ea3d7500a56a1cb86575af22e5dec625085bd766797d23cb2433ab2ad8") = false := by decide

-- M5-pkform-hybrid-009-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "0637eb42b937c48c6b8f28246defbbbb4e0522c63acc273383717107bbe6bbb2f7f244c4ea3d7500a56a1cb86575af22e5dec625085bd766797d23cb2433ab2ad8") = false := by decide

-- M5-core-detsig1-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "030b4c866585dd868a9d62348a9cd008d6a312937048fff31670e7e920cfc7a744") = true := by decide

-- M5-core-detsig1-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "030b4c866585dd868a9d62348a9cd008d6a312937048fff31670e7e920cfc7a744") = true := by decide

-- M5-core-detsig2-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "03183905ae25e815634ce7f5d9bedbaa2c39032ab98c75b5e88fe43f8dd8246f3c") = true := by decide

-- M5-core-detsig2-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "03183905ae25e815634ce7f5d9bedbaa2c39032ab98c75b5e88fe43f8dd8246f3c") = true := by decide

-- M5-core-detsig1-on2-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "03183905ae25e815634ce7f5d9bedbaa2c39032ab98c75b5e88fe43f8dd8246f3c") = true := by decide

-- M5-core-detsig1-on2-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "03183905ae25e815634ce7f5d9bedbaa2c39032ab98c75b5e88fe43f8dd8246f3c") = true := by decide

-- M5-core-detsig2-on1-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "030b4c866585dd868a9d62348a9cd008d6a312937048fff31670e7e920cfc7a744") = true := by decide

-- M5-core-detsig2-on1-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "030b4c866585dd868a9d62348a9cd008d6a312937048fff31670e7e920cfc7a744") = true := by decide

-- M5-core-detsig1-badhash-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "030b4c866585dd868a9d62348a9cd008d6a312937048fff31670e7e920cfc7a744") = true := by decide

-- M5-core-detsig1-badhash-isC
example : Bitcoin.Interpreter.isCompressedPubKey (fromHex "030b4c866585dd868a9d62348a9cd008d6a312937048fff31670e7e920cfc7a744") = true := by decide

-- M5-syn33-00-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "001111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn65-00-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "0011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn33-01-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "011111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn65-01-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "0111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn33-02-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "021111111111111111111111111111111111111111111111111111111111111111") = true := by decide

-- M5-syn65-02-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "0211111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn33-03-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "031111111111111111111111111111111111111111111111111111111111111111") = true := by decide

-- M5-syn65-03-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "0311111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn33-04-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "041111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn65-04-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "0411111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = true := by decide

-- M5-syn33-05-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "051111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn65-05-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "0511111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn33-06-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "061111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn65-06-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "0611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn33-07-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "071111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn65-07-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "0711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn33-08-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "081111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn65-08-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "0811111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn33-7f-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "7f1111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn65-7f-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "7f11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn33-fe-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "fe1111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn65-fe-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "fe11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn33-ff-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "ff1111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M5-syn65-ff-isCU
example : Bitcoin.Interpreter.isCompressedOrUncompressedPubKey (fromHex "ff11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

/-! ## M6 — CPubKey::Verify accept dimension (pubkey.cpp:283-299)
corePubKeyOk = validSize && (ge_parse ok). (R6 rows = pyC TRUTH
recorded as pyC TRUTH comments) -/
/-- `CPubKey::Verify`'s pubkey dimension (S15): valid CPubKey
size (Set+GetLen, pubkey.h:69-105) AND the secp256k1 ge_parse
(group_impl.h:1084-1102) accept. -/
def corePubKeyOk (b : ByteArray) : Bool :=
  validPubKeySize b && (parsePubKeyDeep b).isSome

-- M6-pk-badtag
example : corePubKeyOk (fromHex "05f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = false := by decide

-- M6-pk-x-ge-p
example : corePubKeyOk (fromHex "03fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f") = false := by decide

-- M6-pk-offcurve
example : corePubKeyOk (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") = false := by decide

-- M6-pk-short
example : corePubKeyOk (fromHex "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a411") = false := by decide

-- M6-pk-long
example : corePubKeyOk (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b00") = false := by decide

-- M6-pk-hybrid-wrong-parity
example : corePubKeyOk (fromHex "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = false := by decide

-- M6-pk-hybrid-even-tag-odd-y
example : corePubKeyOk (fromHex "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") = false := by decide

-- M6-pk-empty
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-pk-garbage
example : corePubKeyOk (fromHex "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20") = false := by decide

-- M6-pk-compressed-wrong-parity [R6: 33B Some-path, sqrtP; not kernel-checked — see the R6 list at end]

-- M6-pkform-uncompressed-000
example : corePubKeyOk (fromHex "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") = true := by decide

-- M6-pkform-hybrid-001
example : corePubKeyOk (fromHex "07de7d0279cf7fa80af8571f42cd30b785f7a1fc6b2c96c5250d065f24cdfe9f2af2bae572672f44cdfcf31d87201c3ae9bc142774045e4fef17b872ab68eb8561") = true := by decide

-- M6-pkform-uncompressed-002
example : corePubKeyOk (fromHex "04f86ac12b105f58d6c64265900753edbf4c98e6785262a2adb166606b42b18ef1d2a3bc132e6f47f23e3b80e39ad65cb06e2f9a5341aabfee6d47e1ed06637cdf") = true := by decide

-- M6-pkform-hybrid-003
example : corePubKeyOk (fromHex "077a71ebb83f7a7f9c5112a08c70784163edfd71dd3c6734792dc75434b24b0e30ffe63a7e773c7479664610af26c4483896120045e7d6f48d09cb8a640ef0177d") = true := by decide

-- M6-pkform-uncompressed-004
example : corePubKeyOk (fromHex "04d6e70fd5c439e2e9e85a8b94594bc4449b1998ecee74bb367d7b4e556b75946984090d56529f392b98fc3829f6169e22699d12ee48dd2f58d537a9d22ac1c0fa") = true := by decide

-- M6-pkform-hybrid-005
example : corePubKeyOk (fromHex "07757404cf6fe5e02f369002bad98762521c93342dfee6f0b7a78c5354e17058243b74ce5b4492aded634a5b5edec9baabb16f49d2afb77e7586d9104a31dde9bb") = true := by decide

-- M6-pkform-uncompressed-006
example : corePubKeyOk (fromHex "042da6e846e114f65e7fa2597a1c408d49827605a3ad4eee336421f6f07513519b51cad88d75e63fd6b82770c111d68f3edb5fd4fe8114caaebb9d774a5f080f78") = true := by decide

-- M6-pkform-hybrid-007
example : corePubKeyOk (fromHex "072269827313445de78b0ccf7190a0bea22c32b40fc0c6fd0f217b83221a4b86206b49fdd6ccfd92146788ebbef0ee94cfe3f2c0b139dcc47184b03b45ee975bef") = true := by decide

-- M6-pkform-uncompressed-008
example : corePubKeyOk (fromHex "04971b7cdaafcfb98aa775d01eb6c156d2f04a7030380c8e654565b06d900bc828cc392eb1228696858814fe7deaa7bba2b71aed228367e5162f988c845f44c95a") = true := by decide

-- M6-pkform-hybrid-009
example : corePubKeyOk (fromHex "0637eb42b937c48c6b8f28246defbbbb4e0522c63acc273383717107bbe6bbb2f7f244c4ea3d7500a56a1cb86575af22e5dec625085bd766797d23cb2433ab2ad8") = true := by decide

-- M6-syn-00-0
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-syn-00-1
example : corePubKeyOk (fromHex "00") = false := by decide

-- M6-syn-00-32
example : corePubKeyOk (fromHex "0011111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-00-33
example : corePubKeyOk (fromHex "001111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-00-34
example : corePubKeyOk (fromHex "00111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-00-64
example : corePubKeyOk (fromHex "00111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-00-65
example : corePubKeyOk (fromHex "0011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-00-66
example : corePubKeyOk (fromHex "001111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-01-0
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-syn-01-1
example : corePubKeyOk (fromHex "01") = false := by decide

-- M6-syn-01-32
example : corePubKeyOk (fromHex "0111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-01-33
example : corePubKeyOk (fromHex "011111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-01-34
example : corePubKeyOk (fromHex "01111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-01-64
example : corePubKeyOk (fromHex "01111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-01-65
example : corePubKeyOk (fromHex "0111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-01-66
example : corePubKeyOk (fromHex "011111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-02-0
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-syn-02-1
example : corePubKeyOk (fromHex "02") = false := by decide

-- M6-syn-02-32
example : corePubKeyOk (fromHex "0211111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-02-33 [R6: 33B Some-path, sqrtP; not kernel-checked — see the R6 list at end]

-- M6-syn-02-34
example : corePubKeyOk (fromHex "02111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-02-64
example : corePubKeyOk (fromHex "02111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-02-65
example : corePubKeyOk (fromHex "0211111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-02-66
example : corePubKeyOk (fromHex "021111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-03-0
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-syn-03-1
example : corePubKeyOk (fromHex "03") = false := by decide

-- M6-syn-03-32
example : corePubKeyOk (fromHex "0311111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-03-33 [R6: 33B Some-path, sqrtP; not kernel-checked — see the R6 list at end]

-- M6-syn-03-34
example : corePubKeyOk (fromHex "03111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-03-64
example : corePubKeyOk (fromHex "03111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-03-65
example : corePubKeyOk (fromHex "0311111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-03-66
example : corePubKeyOk (fromHex "031111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-04-0
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-syn-04-1
example : corePubKeyOk (fromHex "04") = false := by decide

-- M6-syn-04-32
example : corePubKeyOk (fromHex "0411111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-04-33
example : corePubKeyOk (fromHex "041111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-04-34
example : corePubKeyOk (fromHex "04111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-04-64
example : corePubKeyOk (fromHex "04111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-04-65
example : corePubKeyOk (fromHex "0411111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-04-66
example : corePubKeyOk (fromHex "041111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-05-0
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-syn-05-1
example : corePubKeyOk (fromHex "05") = false := by decide

-- M6-syn-05-32
example : corePubKeyOk (fromHex "0511111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-05-33
example : corePubKeyOk (fromHex "051111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-05-34
example : corePubKeyOk (fromHex "05111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-05-64
example : corePubKeyOk (fromHex "05111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-05-65
example : corePubKeyOk (fromHex "0511111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-05-66
example : corePubKeyOk (fromHex "051111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-06-0
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-syn-06-1
example : corePubKeyOk (fromHex "06") = false := by decide

-- M6-syn-06-32
example : corePubKeyOk (fromHex "0611111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-06-33
example : corePubKeyOk (fromHex "061111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-06-34
example : corePubKeyOk (fromHex "06111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-06-64
example : corePubKeyOk (fromHex "06111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-06-65
example : corePubKeyOk (fromHex "0611111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-06-66
example : corePubKeyOk (fromHex "061111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-07-0
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-syn-07-1
example : corePubKeyOk (fromHex "07") = false := by decide

-- M6-syn-07-32
example : corePubKeyOk (fromHex "0711111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-07-33
example : corePubKeyOk (fromHex "071111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-07-34
example : corePubKeyOk (fromHex "07111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-07-64
example : corePubKeyOk (fromHex "07111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-07-65
example : corePubKeyOk (fromHex "0711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-07-66
example : corePubKeyOk (fromHex "071111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-08-0
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-syn-08-1
example : corePubKeyOk (fromHex "08") = false := by decide

-- M6-syn-08-32
example : corePubKeyOk (fromHex "0811111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-08-33
example : corePubKeyOk (fromHex "081111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-08-34
example : corePubKeyOk (fromHex "08111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-08-64
example : corePubKeyOk (fromHex "08111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-08-65
example : corePubKeyOk (fromHex "0811111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-08-66
example : corePubKeyOk (fromHex "081111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-7f-0
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-syn-7f-1
example : corePubKeyOk (fromHex "7f") = false := by decide

-- M6-syn-7f-32
example : corePubKeyOk (fromHex "7f11111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-7f-33
example : corePubKeyOk (fromHex "7f1111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-7f-34
example : corePubKeyOk (fromHex "7f111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-7f-64
example : corePubKeyOk (fromHex "7f111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-7f-65
example : corePubKeyOk (fromHex "7f11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-7f-66
example : corePubKeyOk (fromHex "7f1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-fe-0
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-syn-fe-1
example : corePubKeyOk (fromHex "fe") = false := by decide

-- M6-syn-fe-32
example : corePubKeyOk (fromHex "fe11111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-fe-33
example : corePubKeyOk (fromHex "fe1111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-fe-34
example : corePubKeyOk (fromHex "fe111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-fe-64
example : corePubKeyOk (fromHex "fe111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-fe-65
example : corePubKeyOk (fromHex "fe11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-fe-66
example : corePubKeyOk (fromHex "fe1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-ff-0
example : corePubKeyOk (fromHex "") = false := by decide

-- M6-syn-ff-1
example : corePubKeyOk (fromHex "ff") = false := by decide

-- M6-syn-ff-32
example : corePubKeyOk (fromHex "ff11111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-ff-33
example : corePubKeyOk (fromHex "ff1111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-ff-34
example : corePubKeyOk (fromHex "ff111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-ff-64
example : corePubKeyOk (fromHex "ff111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-ff-65
example : corePubKeyOk (fromHex "ff11111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

-- M6-syn-ff-66
example : corePubKeyOk (fromHex "ff1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111") = false := by decide

/-! ## M7 — R6 rows (33B Some = sqrtP = expM = WF; pyC TRUTH
recorded @ cce32b168, kernel-decide PROPOSED) -/
-- M7-R6-pk-compressed-wrong-parity [pyC TRUTH @ cce32b168]
--   parsePubKeyDeep (fromHex "02f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") = some (109826320138395729779344973899952261859843783151338878966742341141794312688029, 108613188845730831833896368173305384305566612252605579810461745019661972647124)
-- M7-R6-core-detsig1 [pyC TRUTH @ cce32b168]
--   parsePubKeyDeep (fromHex "030b4c866585dd868a9d62348a9cd008d6a312937048fff31670e7e920cfc7a744") = some (5110649282401835917424139535448797386973335520905434550270462718090620151620, 55802411797295731719101400949091874687807807377790798615820561701629642824297)
-- M7-R6-core-detsig2 [pyC TRUTH @ cce32b168]
--   parsePubKeyDeep (fromHex "03183905ae25e815634ce7f5d9bedbaa2c39032ab98c75b5e88fe43f8dd8246f3c") = some (10956257852445243689855268313974239232005535804574739534567298206763850166076, 38198880383245090834858187080636144158292647028041063446878918740103134644101)
-- M7-R6-core-detsig1-on2 [pyC TRUTH @ cce32b168]
--   parsePubKeyDeep (fromHex "03183905ae25e815634ce7f5d9bedbaa2c39032ab98c75b5e88fe43f8dd8246f3c") = some (10956257852445243689855268313974239232005535804574739534567298206763850166076, 38198880383245090834858187080636144158292647028041063446878918740103134644101)
-- M7-R6-core-detsig2-on1 [pyC TRUTH @ cce32b168]
--   parsePubKeyDeep (fromHex "030b4c866585dd868a9d62348a9cd008d6a312937048fff31670e7e920cfc7a744") = some (5110649282401835917424139535448797386973335520905434550270462718090620151620, 55802411797295731719101400949091874687807807377790798615820561701629642824297)
-- M7-R6-core-detsig1-badhash [pyC TRUTH @ cce32b168]
--   parsePubKeyDeep (fromHex "030b4c866585dd868a9d62348a9cd008d6a312937048fff31670e7e920cfc7a744") = some (5110649282401835917424139535448797386973335520905434550270462718090620151620, 55802411797295731719101400949091874687807807377790798615820561701629642824297)
-- M7-R6-syn-02-33 [pyC TRUTH @ cce32b168, gate=nosqrt]
--   parsePubKeyDeep (fromHex "021111111111111111111111111111111111111111111111111111111111111111") = none (nosqrt)
-- M7-R6-syn-03-33 [pyC TRUTH @ cce32b168, gate=nosqrt]
--   parsePubKeyDeep (fromHex "031111111111111111111111111111111111111111111111111111111111111111") = none (nosqrt)

/-! ## R6 rows (documented, not kernel-checked)

The following five rows exercise the 33-byte compressed Some-path, whose
acceptance needs `sqrtP = expM` (the WellFounded exponentiation in
`Bitcoin.Crypto.Curve.Secp`).  `by decide` does not reduce that path, so
the rows are recorded here as explicit R6 obligations instead of being
claimed as kernel-decided examples.  Their expected verdicts come from
the pyC/C oracle described in the module header; they are not part of
the passing kernel matrix:

* `M2b-33B-02`: `parsePubKeyDeep (fromHex "0211...11") = none`
* `M2b-33B-03`: `parsePubKeyDeep (fromHex "0311...11") = none`
* `M6-pk-compressed-wrong-parity`: `corePubKeyOk (02 f2cf...119d) = true`
* `M6-syn-02-33`: `corePubKeyOk (fromHex "0211...11") = false`
* `M6-syn-03-33`: `corePubKeyOk (fromHex "0311...11") = false`
-/

end Bitcoin.Proofs.EcdsaDeep.PubKeyMatrix
