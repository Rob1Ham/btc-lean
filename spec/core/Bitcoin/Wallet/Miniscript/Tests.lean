import Bitcoin.Wallet.Miniscript

/-!
# Executable checks for the Miniscript fragment

These are **runtime** cross-checks, not kernel theorems: `toScript` treats
scripts as `ByteArray`, whose append/push operations do not reduce in the
Lean kernel, so `by decide` cannot evaluate them.  The module compiles the
definitions and runs each check through `#eval`; a mismatch raises an IO
error and fails the build.  The propositional claims about this fragment
well-typedness implies interpreter acceptance, and sanity-reason soundness,
are deliberately left to a later proof phase.

Script vectors are copied from Bitcoin Core's
`src/test/miniscript_tests.cpp` (pin `cce32b168`); each check names the
line it came from.  The expected satisfaction stacks are derived from the
`ProduceInput` cases cited in `Satisfy.lean` (`miniscript.h:1247-1440`).
-/

namespace Bitcoin.Wallet.Miniscript.Tests

open Bitcoin.Wallet.Miniscript
open Bitcoin.Wallet.Miniscript.Node
open Bitcoin.Data

/-! ## Test helpers -/

/-- Parse a lowercase hex string into bytes (test infrastructure only). -/
def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  hexDigit (c : Char) : Option Nat :=
    let n := c.toNat
    if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
    else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
    else none
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | a :: b :: rest, acc =>
      match hexDigit a, hexDigit b with
      | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
      | _, _ => acc
    | [_], acc => acc

/-- Check that a node emits exactly `hex` in context `ctx`. -/
def checkScript (label : String) (ctx : MiniscriptContext) (n : Node)
    (hex : String) : IO Unit :=
  let got := toHex (toScript ctx n)
  if got = hex then pure ()
  else throw (IO.userError s!"{label}: script mismatch\n  expected {hex}\n  got      {got}")

/-- Check a boolean property with a readable failure. -/
def checkBool (label : String) (b : Bool) : IO Unit :=
  if b then pure () else throw (IO.userError s!"{label}: expected true")

/-- Check that a node's satisfaction is exactly the given stack (bottom
first, each item as hex; the empty string is an empty item). -/
def checkStack (label : String) (sf : Satisfier) (n : Node)
    (expected : List String) : IO Unit :=
  let got := (satisfy sf n).map (fun st => st.map toHex)
  if got = some expected then pure ()
  else throw (IO.userError s!"{label}: satisfaction mismatch\n  expected {expected}\n  got      {got}")

/-- Check that a node has no satisfaction under a satisfier. -/
def checkUnsatisfiable (label : String) (sf : Satisfier) (n : Node) : IO Unit :=
  match satisfy sf n with
  | none => pure ()
  | some st => throw (IO.userError s!"{label}: unexpectedly satisfiable: {st.map toHex}")

/-! ## Keys, digests, and contexts used by the vectors -/

def k1 : ByteArray := fromHex "03d30199d74fb5a22d47b6e054e2f378cedacffcb89904a61d75d0dbd407143e65"
def k2 : ByteArray := fromHex "03fff97bd5755eeea420453a14355235d382f6472f8568a18b2f057a1460297556"
def k4 : ByteArray := fromHex "02f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f9"
def k5 : ByteArray := fromHex "025cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc"

/-- x-only form of `k1`, used by the tapscript threshold vector. -/
def k1x : ByteArray := fromHex "d30199d74fb5a22d47b6e054e2f378cedacffcb89904a61d75d0dbd407143e65"

/-- x-only form of `k5`, used by the tapscript threshold vector. -/
def k5x : ByteArray := fromHex "5cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bc"

/-- x-only form of the first `multi_a` key, as tapscript pushes it. -/
def k6x : ByteArray := fromHex "d01115d548e7561b15c38f004d734633687cf4419620095bc5b0f47070afe85a"

/-- x-only form of the second `multi_a` key. -/
def k7x : ByteArray := fromHex "5601570cb47f238d2b0286db4a990fa0f3ba28d1a319f5e7cf55c2a2444da7cc"

def h160_1 : ByteArray := fromHex "fcd35ddacad9f2d5be5e464639441c6065e6955d"
def h160_2 : ByteArray := fromHex "20195b5a3d650c17f0f29f91c33f8f6335193d07"
def hsha_1 : ByteArray := fromHex "96de8fc8c256fa1e1556d41af431cace7dca68707c78dd88c3acab8b17164c47"
def hsha_2 : ByteArray := fromHex "d9147961436944f43cd99d28b2bbddbf452ef872b30c8279e255e7daafc7f946"
def hsha_3 : ByteArray := fromHex "e38990d0c7fc009880a9c07c23842e886c6bbdc964ce6bdd5817ad357335ee6f"
def hsha_4 : ByteArray := fromHex "38df1c1f64a24a77b23393bca50dff872e31edc4f3b5aa3b90ad0b82f4f089b6"
def h256_1 : ByteArray := fromHex "32ba476771d01e37807990ead8719f08af494723de1d228f2c2c07cc0aa40bac"
def h256_2 : ByteArray := fromHex "131772552c01444cd81360818376a040b7c3b2b7b0a53550ee3edde216cec61b"

def ctxW : MiniscriptContext := .p2wsh
def ctxT : MiniscriptContext := .tapscript

/-! ## Script vectors (Core `miniscript_tests.cpp`) -/

/-- Core line 558: `pk(K)` is `c:pk_k(K)`. -/
def nPk : Node := wrapC (pkK k1)

/-- Core line 559: `pkh(K)` is `c:pk_h(K)`. -/
def nPkh : Node := wrapC (pkH k1 h160_1)

/-- Core line 568, the `multi(1,...)` subexpression. -/
def nMulti : Node := multi 1 [k4]

/-- Core line 574: `and_b(hash256(..),a:and_b(hash256(..),a:older(1)))`. -/
def nAndB : Node :=
  andB (hash256 h256_1) (wrapA (andB (hash256 h256_2) (wrapA (older 1))))

/-- Core line 573: `j:and_v(v:hash160(..),or_d(sha256(..),older(16)))`. -/
def nJAndV : Node :=
  wrapJ (andV (wrapV (hash160 h160_2)) (orD (sha256 hsha_1) (older 16)))

/-- Core line 582: `or_i(c:and_v(v:after(500000),pk_k(..)),sha256(..))`. -/
def nOrI : Node :=
  orI (wrapC (andV (wrapV (after 500000)) (pkK k1))) (sha256 hsha_2)

/-- Core line 572: `and_b(older(16),s:or_d(sha256(..),n:after(..)))`. -/
def nAndB2 : Node :=
  andB (older 16) (wrapS (orD (sha256 hsha_3) (wrapN (after 1567547623))))

/-- Core line 577: `or_d(nd:and_v(v:older(..),v:older(..)),sha256(..))`. -/
def nOrD : Node :=
  orD (wrapN (wrapD (andV (wrapV (older 4252898)) (wrapV (older 4252898)))))
    (sha256 hsha_4)

/-- Core line 608: `and_v(v:multi_a(2,..),after(1231488000))`, tapscript. -/
def nMultiA : Node := andV (wrapV (multiA 2 [k6x, k7x])) (after 1231488000)

/-- Core line 618: `thresh(2,dv:older(42),s:pk(..),s:pk(..))`, tapscript. -/
def nThreshT : Node :=
  thresh 2 [wrapD (wrapV (older 42)), wrapS (wrapC (pkK k5x)), wrapS (wrapC (pkK k1x))]

/-- Core line 664: `thresh(1,c:pk_k(..),sc:pk_k(..))`. -/
def nThreshW : Node :=
  thresh 1 [wrapC (pkK k1), wrapS (wrapC (pkK k2))]

#eval checkScript "pk (cpp:558)" ctxW nPk
  "2103d30199d74fb5a22d47b6e054e2f378cedacffcb89904a61d75d0dbd407143e65ac"

#eval checkScript "pkh (cpp:559)" ctxW nPkh
  "76a914fcd35ddacad9f2d5be5e464639441c6065e6955d88ac"

#eval checkScript "multi(1) (cpp:568)" ctxW nMulti
  "512102f9308a019258c31049344f85f89d5229b531c845836f99b08601f113bce036f951ae"

#eval checkScript "and_b hash256 (cpp:574)" ctxW nAndB
  "82012088aa2032ba476771d01e37807990ead8719f08af494723de1d228f2c2c07cc0aa40bac876b82012088aa20131772552c01444cd81360818376a040b7c3b2b7b0a53550ee3edde216cec61b876b51b26c9a6c9a"

#eval checkScript "j:and_v hash160 (cpp:573)" ctxW nJAndV
  "82926382012088a91420195b5a3d650c17f0f29f91c33f8f6335193d078882012088a82096de8fc8c256fa1e1556d41af431cace7dca68707c78dd88c3acab8b17164c4787736460b26868"

#eval checkScript "or_i after/pk (cpp:582)" ctxW nOrI
  "630320a107b1692103d30199d74fb5a22d47b6e054e2f378cedacffcb89904a61d75d0dbd407143e65ac6782012088a820d9147961436944f43cd99d28b2bbddbf452ef872b30c8279e255e7daafc7f9468768"

#eval checkScript "and_b older/or_d (cpp:572)" ctxW nAndB2
  "60b27c82012088a820e38990d0c7fc009880a9c07c23842e886c6bbdc964ce6bdd5817ad357335ee6f87736404e7e06e5db192689a"

#eval checkScript "or_d d:and_v (cpp:577)" ctxW nOrD
  "766303e2e440b26903e2e440b2696892736482012088a82038df1c1f64a24a77b23393bca50dff872e31edc4f3b5aa3b90ad0b82f4f089b68768"

#eval checkScript "multi_a tapscript (cpp:608)" ctxT nMultiA
  "20d01115d548e7561b15c38f004d734633687cf4419620095bc5b0f47070afe85aac205601570cb47f238d2b0286db4a990fa0f3ba28d1a319f5e7cf55c2a2444da7ccba529d0400046749b1"

#eval checkScript "thresh tapscript (cpp:618)" ctxT nThreshT
  "7663012ab269687c205cbdf0646e5db4eaa398f365f2ea7a0e3d419b7e0330e39ce92bddedcac4f9bcac937c20d30199d74fb5a22d47b6e054e2f378cedacffcb89904a61d75d0dbd407143e65ac935287"

#eval checkScript "thresh(1) c/sc (cpp:664)" ctxW nThreshW
  "2103d30199d74fb5a22d47b6e054e2f378cedacffcb89904a61d75d0dbd407143e65ac7c2103fff97bd5755eeea420453a14355235d382f6472f8568a18b2f057a1460297556ac935187"

/-! ## Type and sanity checks -/

/-- Satisfier with two keys, three preimages, and fixed timelock answers. -/
def sf : Satisfier where
  sign := fun k =>
    if k = k1 then some (fromHex "3001")
    else if k = k2 then some (fromHex "3002")
    else if k = k6x then some (fromHex "3006")
    else if k = k7x then some (fromHex "3007")
    else none
  satSHA256 := fun h =>
    if h = hsha_1 then some (fromHex "aa01")
    else if h = hsha_3 then some (fromHex "aa03")
    else none
  satHash256 := fun h =>
    if h = h256_1 then some (fromHex "bb01") else none
  satRIPEMD160 := fun _ => none
  satHASH160 := fun h =>
    if h = h160_2 then some (fromHex "cc02") else none
  checkOlder := fun n => n ≤ 5000000
  checkAfter := fun n => n = 500000

-- `older(0)` is invalid; Core rejects it (`cpp:507`).
#eval checkBool "older(0) invalid (cpp:507)" (!isValid ctxW (older 0))

-- `older(2^31-1)` is valid (`cpp:508`).
#eval checkBool "older(2^31-1) valid (cpp:508)" (isValid ctxW (older 2147483647))

-- `older(2^31)` is invalid (`cpp:509`).
#eval checkBool "older(2^31) invalid (cpp:509)" (!isValid ctxW (older 2147483648))

-- `thresh(3, 2 subs)` is invalid (`cpp:666`).
#eval checkBool "thresh k > n invalid (cpp:666)"
  (!isValid ctxW (thresh 3 [wrapC (pkK k1), wrapC (pkK k2)]))

-- A `multi` is P2WSH-only; `multi_a` is tapscript-only (`cpp:606-608`).
#eval checkBool "multi under tapscript invalid (cpp:608)"
  (!isValid ctxT (multi 1 [k1]))

#eval checkBool "multi_a under p2wsh invalid (cpp:618)"
  (!isValid ctxW (multiA 1 [k6x]))

/-- A clean `and_v(v:pk, pk)` is sane. -/
def nSane : Node := andV (wrapV (wrapC (pkK k1))) (wrapC (pkK k2))

#eval checkBool "sane and_v" (isSane ctxW nSane)

/-- Reusing a key makes a node insane (`cpp:706-710`). -/
def nDup : Node := andV (wrapV (wrapC (pkK k1))) (wrapC (pkK k1))

#eval checkBool "duplicate key is insane (cpp:706)"
  ((subexpressionReasons ctxW nDup).contains .duplicateKey)

/-- `after(1)` (height) and `after(1000000000)` (time) mix (`cpp:705-709`). -/
def nMix : Node := andB (after 1) (wrapA (after 1000000000))

#eval checkBool "timelock mix is insane (cpp:709)"
  ((subexpressionReasons ctxW nMix).contains .timelockMix)

-- `pk` alone needs a signature and is sane (`cpp:715`).
#eval checkBool "pk is sane (cpp:715)" (isSane ctxW nPk)

/-! ## Satisfaction examples -/

#eval checkStack "satisfy pk" sf nPk ["3001"]

#eval checkStack "satisfy pkh" sf nPkh
  ["3001", "03d30199d74fb5a22d47b6e054e2f378cedacffcb89904a61d75d0dbd407143e65"]

#eval checkStack "satisfy and_v(v:pk,after)"
  sf (andV (wrapV (wrapC (pkK k1))) (after 500000)) ["3001"]

#eval checkStack "satisfy or_i(pk,sha256)" sf
  (orI (wrapC (pkK k1)) (sha256 hsha_2)) ["3001", "01"]

#eval checkStack "satisfy multi(2)" sf (multi 2 [k1, k2])
  ["", "3001", "3002"]

#eval checkStack "satisfy multi_a(1) tapscript" sf (multiA 1 [k6x, k7x])
  ["", "3006"]

-- A threshold whose selected branches are `pk`, `sha256` and the
-- dissatisfied `hash160`; `X1 X2 ADD X3 ADD` means the stack is X3, X2, X1
-- bottom-to-top.
#eval checkStack "satisfy thresh(2)" sf
  (thresh 2 [wrapC (pkK k1), wrapA (sha256 hsha_3), wrapA (hash160 h160_2)])
  ["0000000000000000000000000000000000000000000000000000000000000000", "aa03", "3001"]

-- Missing preimage: explicit unsatisfiability.
#eval checkUnsatisfiable "no preimage" sf (sha256 hsha_2)

-- Unsatisfied timelock: explicit unsatisfiability.
#eval checkUnsatisfiable "timelock not met" sf (after 500001)

end Bitcoin.Wallet.Miniscript.Tests
