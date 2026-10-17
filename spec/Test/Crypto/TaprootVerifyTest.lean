import Bitcoin.Crypto.Taproot.Verify

/-!
# W3-X03 Unit-4 BIP341 taproot-verify conformance harness (GENERATED — do
# not hand-edit the literal tables; regenerate via the crosscheck script)

Run: `bash spec/Test/Crypto/run_taproot_verify.sh` and
`python3 spec/Test/Crypto/taproot_verify_crosscheck.py`.

Corpus    : spec/vectors/bips/bip-0341_wallet-test-vectors.json,
            `scriptPubKey` section — ALL 7 official output-construction
            cases (scriptTree null / single leaf 0xc0 / single leaf 0xc0 /
            2-leaf with a 0xfa future-version leaf / 2-leaf 0xc0 / nested
            3-leaf ×2). Each case checks the `merkleRoot` (the treeHash
            ladder), the full `scriptPubKey` through `p2trOutput`, and the
            cross-field template `0x51 0x20 ‖ tweakedPubkey`.

Semantics : Bitcoin.Crypto.Taproot.Verify.p2trOutput / treeMerkleRoot —
            BIP341 §"Constructing and spending Taproot outputs"
            (`Q = P + hash_TapTweak(P ‖ root)·G`, scriptPubKey
            `0x51 0x20 ‖ x(Q)`), plus the script-path SPEND arm
            `scriptPathSpend` (Core interpreter.cpp:1976-1990).

Synthetic cases (honestly non-official): NO official BIP341 vectors
exercise a script-path SPEND, so four synthetic control-block verdicts
(minimal 33-byte m=0 accept, wrong-parity reject, corrupt-path-node
65-byte m=1 reject, 34-byte size reject) are checked; the mirrored
verdicts are re-derived independently in
`taproot_verify_crosscheck.py` (pure-python secp256k1).
-/


namespace Bitcoin.Test.Crypto.TaprootVerifyVectors

open Bitcoin.Crypto.Taproot.Verify
open Bitcoin.Crypto.Taproot (tapLeaf)
open Bitcoin.Crypto.Taproot.OutputKey (tweakedKey)
open Bitcoin.Data (serU8 bytesBEq)
open Bitcoin.Crypto.Taproot.Program (controlBlockSizeOk)

/-- Parse a hex string into a ByteArray (test infra only). -/
def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

/-! ## The 7 official `scriptPubKey`-section cases

Row = (name, internalPubkeyHex, scriptTree, merkleRootHex ("" = null),
tweakedPubkeyHex, scriptPubKeyHex). The trees are the corpus `scriptTree`
JSON translated to `TapTree` literals; leaf versions 192 = 0xc0 (TAPSCRIPT)
and 250 = 0xfa (the future-leaf-version test leaf). -/

def tree1 : Option TapTree :=
  some (.leaf 192 (fromHex "20d85a959b0290bf19bb89ed43c916be835475d013da4b362117393e25a48229b8ac"))

def tree2 : Option TapTree :=
  some (.leaf 192 (fromHex "20b617298552a72ade070667e86ca63b8f5789a9fe8731ef91202a91c9f3459007ac"))

def tree3 : Option TapTree :=
  some (.node (.leaf 192 (fromHex "20387671353e273264c495656e27e39ba899ea8fee3bb69fb2a680e22093447d48ac"))
              (.leaf 250 (fromHex "06424950333431")))

def tree4 : Option TapTree :=
  some (.node (.leaf 192 (fromHex "2044b178d64c32c4a05cc4f4d1407268f764c940d20ce97abfd44db5c3592b72fdac"))
              (.leaf 192 (fromHex "07546170726f6f74")))

def tree5 : Option TapTree :=
  some (.node (.leaf 192 (fromHex "2072ea6adcf1d371dea8fba1035a09f3d24ed5a059799bae114084130ee5898e69ac"))
              (.node (.leaf 192 (fromHex "202352d137f2f3ab38d1eaa976758873377fa5ebb817372c71e2c542313d4abda8ac"))
                     (.leaf 192 (fromHex "207337c0dd4253cb86f2c43a2351aadd82cccb12a172cd120452b9bb8324f2186aac"))))

def tree6 : Option TapTree :=
  some (.node (.leaf 192 (fromHex "2071981521ad9fc9036687364118fb6ccd2035b96a423c59c5430e98310a11abe2ac"))
              (.node (.leaf 192 (fromHex "20d5094d2dbe9b76e2c245a2b89b6006888952e2faa6a149ae318d69e520617748ac"))
                     (.leaf 192 (fromHex "20c440b462ad48c7a77f94cd4532d8f2119dcebbd7c9764557e62726419b08ad4cac"))))

def cases : List (String × String × Option TapTree × String × String × String) :=
  [("spk-off-0-nulltree",
    "d6889cb081036e0faefa3a35157ad71086b123b2b144b649798b494c300a961d",
    none, "",
    "53a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda343",
    "512053a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda343"),
   ("spk-off-1-singleleaf",
    "187791b6f712a8ea41c8ecdd0ee77fab3e85263b37e1ec18a3651926b3a6cf27",
    tree1, "5b75adecf53548f3ec6ad7d78383bf84cc57b55a3127c72b9a2481752dd88b21",
    "147c9c57132f6e7ecddba9800bb0c4449251c92a1e60371ee77557b6620f3ea3",
    "5120147c9c57132f6e7ecddba9800bb0c4449251c92a1e60371ee77557b6620f3ea3"),
   ("spk-off-2-singleleaf",
    "93478e9488f956df2396be2ce6c5cced75f900dfa18e7dabd2428aae78451820",
    tree2, "c525714a7f49c28aedbbba78c005931a81c234b2f6c99a73e4d06082adc8bf2b",
    "e4d810fd50586274face62b8a807eb9719cef49c04177cc6b76a9a4251d5450e",
    "5120e4d810fd50586274face62b8a807eb9719cef49c04177cc6b76a9a4251d5450e"),
   ("spk-off-3-twoleaf-fa",
    "ee4fe085983462a184015d1f782d6a5f8b9c2b60130aff050ce221ecf3786592",
    tree3, "6c2dc106ab816b73f9d07e3cd1ef2c8c1256f519748e0813e4edd2405d277bef",
    "712447206d7a5238acc7ff53fbe94a3b64539ad291c7cdbc490b7577e4b17df5",
    "5120712447206d7a5238acc7ff53fbe94a3b64539ad291c7cdbc490b7577e4b17df5"),
   ("spk-off-4-twoleaf",
    "f9f400803e683727b14f463836e1e78e1c64417638aa066919291a225f0e8dd8",
    tree4, "ab179431c28d3b68fb798957faf5497d69c883c6fb1e1cd9f81483d87bac90cc",
    "77e30a5522dd9f894c3f8b8bd4c4b2cf82ca7da8a3ea6a239655c39c050ab220",
    "512077e30a5522dd9f894c3f8b8bd4c4b2cf82ca7da8a3ea6a239655c39c050ab220"),
   ("spk-off-5-nested3",
    "e0dfe2300b0dd746a3f8674dfd4525623639042569d829c7f0eed9602d263e6f",
    tree5, "ccbd66c6f7e8fdab47b3a486f59d28262be857f30d4773f2d5ea47f7761ce0e2",
    "91b64d5324723a985170e4dc5a0f84c041804f2cd12660fa5dec09fc21783605",
    "512091b64d5324723a985170e4dc5a0f84c041804f2cd12660fa5dec09fc21783605"),
   ("spk-off-6-nested3",
    "55adf4e8967fbd2e29f20ac896e60c3b0f1d5b0efa9d34941b5958c7b0a0312d",
    tree6, "2f6b2c5397b6d68ca18e09a3f05161668ffe93a988582d55c6f07bd5b3329def",
    "75169f4001aa68f15bbed28b218df1d0a62cbbcf1188c6665110c293c907b831",
    "512075169f4001aa68f15bbed28b218df1d0a62cbbcf1188c6665110c293c907b831")]

/-- Check one official output case: merkleRoot through the treeHash
ladder, the full scriptPubKey through `p2trOutput`, and the cross-field
template `0x51 0x20 ‖ tweakedPubkey`. -/
def checkOne (c : String × String × Option TapTree × String × String × String) :
    IO Bool := do
  let (name, pkHex, tree, rootHex, twHex, spkHex) := c
  let rootOk := treeMerkleRoot tree ==
    (if rootHex = "" then (none : Option ByteArray) else some (fromHex rootHex))
  let outOk := p2trOutput (fromHex pkHex) tree == some (fromHex spkHex)
  let tplOk := fromHex spkHex == serU8 0x51 ++ serU8 0x20 ++ fromHex twHex
  unless rootOk && outOk && tplOk do
    IO.println s!"FAIL {name}: rootOk {rootOk} outOk {outOk} tplOk {tplOk}"
  pure (rootOk && outOk && tplOk)

/-! ## Synthetic script-path SPEND verdicts

The control block for case 1's single-leaf tree: `control[0] = 0xc0 | y(Q)&1`,
`control[1..33] = internalPubkey`, no path nodes (33 bytes — the Core m=0
minimal control post F-X03-1: the tree's only leaf IS the merkle root,
`tapleaf(0xc0, script1) = root1`). The parity bit
is derived through `tweakedKey` (the same recomputation the verdict itself
performs — a wallet knows it from its own tweak). The tapleaf spent IS the
tree's only leaf, so the path-recomputed root equals the tweak root and the
commitment verifies. -/

/-- The parity bit (0 or 1) of y(Q) for an internal key + root. -/
def parityBitOf (pk root : ByteArray) : Option Nat :=
  match tweakedKey (serU8 0 ++ pk) (some root) with
  | some (_, yQ) => some (yQ % 2)
  | none => none

/-- The minimal script-path control block under the spec's TPR-009
lattice (`TAPROOT_CONTROL_BASE_SIZE = 33` post F-X03-1: 1 parity byte +
32 internal-key bytes, m = 0), or none if the tweak failed. -/
def minimalControl (pk root : ByteArray) : Option ByteArray := do
  let parity ← parityBitOf pk root
  pure (serU8 ((0xc0 + parity).toUInt8) ++ pk)

def script1 : ByteArray :=
  fromHex "20d85a959b0290bf19bb89ed43c916be835475d013da4b362117393e25a48229b8ac"

def root1 : ByteArray :=
  fromHex "5b75adecf53548f3ec6ad7d78383bf84cc57b55a3127c72b9a2481752dd88b21"

def pk1 : ByteArray :=
  fromHex "187791b6f712a8ea41c8ecdd0ee77fab3e85263b37e1ec18a3651926b3a6cf27"

/-- name, verdict — the four synthetic control-block cases. -/
def checkScriptPath : IO Nat := do
  let mut fails := 0
  match minimalControl pk1 root1 with
  | none => do
    IO.println "FAIL spk-synth-accept: parity derivation returned none"
    pure 1
  | some control =>
    -- accept: the minimal 33-byte (m=0) control block over the tree's own leaf
    let tl := scriptPathTapleaf control script1
    let acceptOk :=
      control.size == 33 &&
      controlBlockSizeOk control &&
      scriptPathSpend control script1 (fromHex "") ==
        some (tl, true, true)
    unless acceptOk do
      IO.println s!"FAIL spk-synth-accept: {acceptOk}"
    unless acceptOk do fails := fails + 1
    -- reject: wrong parity bit (control[0] flipped)
    let controlWrong := serU8 ((0xc0 + (1 - (control.get! 0).toNat % 2)).toUInt8) ++ pk1
    let wrongOk := scriptPathSpend controlWrong script1 (fromHex "") ==
      some (scriptPathTapleaf controlWrong script1, false, true)
    unless wrongOk do
      IO.println s!"FAIL spk-synth-wrongparity: {wrongOk}"
    unless wrongOk do fails := fails + 1
    -- reject: one corrupt path node (65 bytes ⇒ m = 1, garbage root)
    let controlBad := control ++ fromHex "ff31c8b9e15c4d8a5f2e6b7a0c9d3f410031c8b9e15c4d8a5f2e6b7a0c9d3f41"
    let badOk := scriptPathSpend controlBad script1 (fromHex "") ==
      some (scriptPathTapleaf controlBad script1, false, true)
    unless badOk do
      IO.println s!"FAIL spk-synth-corruptpath: {badOk}"
    unless badOk do fails := fails + 1
    -- reject: 34-byte control block (TPR-009 lattice: (34-33) % 32 ≠ 0)
    let control34 := control ++ serU8 0x00
    let sizeOk := scriptPathSpend control34 script1 (fromHex "") == none
    unless sizeOk do
      IO.println s!"FAIL spk-synth-badsize: {sizeOk}"
    unless sizeOk do fails := fails + 1
    pure fails

/-! ## IO harness -/

def runVectors : IO Unit := do
  let mut fails := 0
  for c in cases do
    unless ← checkOne c do
      fails := fails + 1
  let spathFails ← checkScriptPath
  fails := fails + spathFails
  IO.println s!"BIP341 taproot verify: {cases.length} official output cases \
    + 4 synthetic script-path verdicts, FAILURES {fails}"
  if fails > 0 then throw (IO.userError "BIP341 taproot verify conformance failures")

end Bitcoin.Test.Crypto.TaprootVerifyVectors

/-- Runner entry (root `main` for `lake env lean --run`). -/
def main : IO Unit := Bitcoin.Test.Crypto.TaprootVerifyVectors.runVectors
