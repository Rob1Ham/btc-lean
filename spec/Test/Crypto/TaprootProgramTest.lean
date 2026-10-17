import Bitcoin.Crypto.Taproot.Program
import Bitcoin.Crypto.Taproot.OutputKey
import Bitcoin.Activation.Taproot
import Bitcoin.Activation.Flags
import Bitcoin.Data.Basic

/-!
# W3-X06 Taproot rule-row conformance harness (GENERATED — do not hand-edit)

Run: `bash spec/Test/Crypto/run_taproot_program.sh`
Corpus: the official BIP341 wallet test vectors
(`bips/bip-0341/wallet-test-vectors.json`, 7 scriptPubKey cases + the
keyPathSpending 64-byte witness) — all 7 are `5120…` (P2TR) outputs;
their `intermediary.tweak`/`tweakedPubkey` fields differentially test
X02's taggedHash + X03's tweakPoint through the OUTPUT-KEY lane.
The official corpus has NO annex cases — annex/annexHash/classification
annex cases are hand-constructed per BIP341 §"Script validation".

Semantics: X06's Bitcoin.Crypto.Taproot.{Program,OutputKey} +
Bitcoin.Activation.Taproot, with X02 `liftX`/`bytesToNatBE` and X03
`taptweak`/`tweakPoint` underneath. Checked by compiled runtime
execution (`lean --run`) — deliberately NOT kernel decide (the EC
tweak walks the raw-Nat mulP/expM layer; W14 §5 finding).

Vector → property map:
  spk-0..6  TPR-001 recognition + program extraction = tweakedPubkey;
            TPR-047/015 taptweak == official `tweak` (root none / some);
            TPR-016 tweakPoint x(Q) == official tweakedPubkey;
            TPR-011/018 outputKeyOk pass at the parity byte that
            matches y(Q), fail at the flipped parity (control =
            parity ‖ internal ‖ 32-byte node = 65 bytes, the Core-33
            m=1 shape post F-X03-1; root as given).
  spk-1..6  TPR-008 script-path classification with the vector's
            script + a 0xc0-prefixed control (TPR-009 size, TPR-010
            leaf version 0xc0).
  kp-0      TPR-007 key-path classification of the official 65-byte
            witness (sig + hashtype); TPR-022 validation weight =
            66 + 50 WU.
  synth     TPR-004 P2A template; TPR-005/006 annex detection + hash;
            TPR-009 size lattice (Core-33 post F-X03-1: 33/65 ok /
            66/32 reject / 4129 max ok);
            TPR-018 non-QR and x ≥ p internal-key rejects; TPR-071
            annex counts toward the weight; TPR-075/078 activation
            boundaries (709632 active, 709631 not); TPR-076/077 flag
            regime spot checks.
-/

namespace Bitcoin.Test.Crypto.TaprootProgram

open Bitcoin.Crypto.Taproot.Program (isPayToTaproot p2trProgram p2trScript
  isPayToAnchor isAnnex annexHash spendStack classifySpend SpendPath
  controlBlockSizeOk leafVersionOf witnessSerSize validationWeightInit
  TAPROOT_CONTROL_BASE_SIZE TAPROOT_CONTROL_MAX_SIZE)
open Bitcoin.Crypto.Taproot.OutputKey (internalKeyOk internalKeyBytes
  tweakedKey outputKeyOk)
open Bitcoin.Crypto.Taproot (taptweak tweakPoint)
open Bitcoin.Crypto.Curve.Secp (bytesToNatBE liftX)
open Bitcoin.Activation (taprootBip9Deployment deploymentActiveAt
  TAPROOT_ACTIVATION_HEIGHT getBlockScriptFlagsP mainnetParams
  taprootExceptionHash)
open Bitcoin.Data (compactSizeEnc)

set_option maxRecDepth 100000

/-! ## Test infra -/

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

def mkZeros (n : Nat) : ByteArray :=
  (List.range n).foldl (fun acc _ => acc.push 0) ByteArray.empty

/-- A 65-byte script-path-shaped control: parity byte ‖ 32-byte internal
key ‖ 32-byte node payload — the Core-33 m=1 shape post F-X03-1
(33-byte base + 1 node = the official spk-1 control shape
`0xc0 ‖ P ‖ merkleRoot`; was misread as the 65-byte m=0 base pre-fix). -/
def mkControl65 (parity : UInt8) (internal : ByteArray) : ByteArray :=
  (ByteArray.empty.push parity) ++ internal ++ mkZeros 32

/-- The official BIP341 wallet scriptPubKey corpus:
(name, internalPubkey, merkleRoot?, tweak, tweakedPubkey, scriptPubKey). -/
def spkVectors : List (String × String × Option String × String × String × String) :=
  [
  ("spk-0", "d6889cb081036e0faefa3a35157ad71086b123b2b144b649798b494c300a961d", none,
   "b86e7be8f39bab32a6f2c0443abbc210f0edac0e2c53d501b36b64437d9c6c70",
   "53a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda343",
   "512053a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda343"),
  ("spk-1", "187791b6f712a8ea41c8ecdd0ee77fab3e85263b37e1ec18a3651926b3a6cf27",
   some "5b75adecf53548f3ec6ad7d78383bf84cc57b55a3127c72b9a2481752dd88b21",
   "cbd8679ba636c1110ea247542cfbd964131a6be84f873f7f3b62a777528ed001",
   "147c9c57132f6e7ecddba9800bb0c4449251c92a1e60371ee77557b6620f3ea3",
   "5120147c9c57132f6e7ecddba9800bb0c4449251c92a1e60371ee77557b6620f3ea3"),
  ("spk-2", "93478e9488f956df2396be2ce6c5cced75f900dfa18e7dabd2428aae78451820",
   some "c525714a7f49c28aedbbba78c005931a81c234b2f6c99a73e4d06082adc8bf2b",
   "6af9e28dbf9d6aaf027696e2598a5b3d056f5fd2355a7fd5a37a0e5008132d30",
   "e4d810fd50586274face62b8a807eb9719cef49c04177cc6b76a9a4251d5450e",
   "5120e4d810fd50586274face62b8a807eb9719cef49c04177cc6b76a9a4251d5450e"),
  ("spk-3", "ee4fe085983462a184015d1f782d6a5f8b9c2b60130aff050ce221ecf3786592",
   some "6c2dc106ab816b73f9d07e3cd1ef2c8c1256f519748e0813e4edd2405d277bef",
   "9e0517edc8259bb3359255400b23ca9507f2a91cd1e4250ba068b4eafceba4a9",
   "712447206d7a5238acc7ff53fbe94a3b64539ad291c7cdbc490b7577e4b17df5",
   "5120712447206d7a5238acc7ff53fbe94a3b64539ad291c7cdbc490b7577e4b17df5"),
  ("spk-4", "f9f400803e683727b14f463836e1e78e1c64417638aa066919291a225f0e8dd8",
   some "ab179431c28d3b68fb798957faf5497d69c883c6fb1e1cd9f81483d87bac90cc",
   "639f0281b7ac49e742cd25b7f188657626da1ad169209078e2761cefd91fd65e",
   "77e30a5522dd9f894c3f8b8bd4c4b2cf82ca7da8a3ea6a239655c39c050ab220",
   "512077e30a5522dd9f894c3f8b8bd4c4b2cf82ca7da8a3ea6a239655c39c050ab220"),
  ("spk-5", "e0dfe2300b0dd746a3f8674dfd4525623639042569d829c7f0eed9602d263e6f",
   some "ccbd66c6f7e8fdab47b3a486f59d28262be857f30d4773f2d5ea47f7761ce0e2",
   "b57bfa183d28eeb6ad688ddaabb265b4a41fbf68e5fed2c72c74de70d5a786f4",
   "91b64d5324723a985170e4dc5a0f84c041804f2cd12660fa5dec09fc21783605",
   "512091b64d5324723a985170e4dc5a0f84c041804f2cd12660fa5dec09fc21783605"),
  ("spk-6", "55adf4e8967fbd2e29f20ac896e60c3b0f1d5b0efa9d34941b5958c7b0a0312d",
   some "2f6b2c5397b6d68ca18e09a3f05161668ffe93a988582d55c6f07bd5b3329def",
   "6579138e7976dc13b6a92f7bfd5a2fc7684f5ea42419d43368301470f3b74ed9",
   "75169f4001aa68f15bbed28b218df1d0a62cbbcf1188c6665110c293c907b831",
   "512075169f4001aa68f15bbed28b218df1d0a62cbbcf1188c6665110c293c907b831"),
  ]

/-- The official keyPathSpending witness for the spk-0 input
(inputSpending[0].expected.witness[0]): 65 bytes = 64-byte BIP340
signature + explicit 1-byte hashtype (hashType 3, SIGHASH_SINGLE|
ANYONECANPAY — NOT the 64-byte DEFAULT form). -/
def kp0Sig : ByteArray :=
  fromHex "ed7c1647cb97379e76892be0cacff57ec4a7102aa24296ca39af7541246d8ff14d38958d4cc1e2e478e4d4a764bbfd835b16d4e314b72937b29833060b87276c03"

/-! ## Checks -/

/-- TPR-001: every official spk is recognized as P2TR and its program
is exactly the official tweakedPubkey; the round-trip re-serialization
reproduces the spk byte-for-byte. -/
def checkRecognition : IO Nat := do
  let mut fails := 0
  for (name, _int, _mr, _tw, tweaked, spk) in spkVectors do
    let spkB := fromHex spk
    let tweakedB := fromHex tweaked
    if !isPayToTaproot spkB then do fails := fails + 1; IO.println s!"FAIL {name}: not recognized as P2TR"
    if p2trProgram 1 tweakedB != true then do fails := fails + 1; IO.println s!"FAIL {name}: tweakedPubkey not a v1 program"
    if spkB.extract 2 spkB.size != tweakedB then do fails := fails + 1; IO.println s!"FAIL {name}: program != tweakedPubkey"
    if p2trScript tweakedB != spkB then do fails := fails + 1; IO.println s!"FAIL {name}: round-trip mismatch"
  return fails

/-- TPR-047 + TPR-015 differential: X02's taggedHash("TapTweak", p‖root)
reproduces the official `tweak` field for all 7 wallet cases (root =
none for the no-script-tree case 0, `some merkleRoot` for 1-6). -/
def checkTaptweak : IO Nat := do
  let mut fails := 0
  for (name, int, mr, tw, _tweaked, _spk) in spkVectors do
    let got := taptweak (fromHex int) (mr.map fromHex)
    if got != fromHex tw then do
      fails := fails + 1
      IO.println s!"FAIL {name}: taptweak mismatch"
  return fails

/-- TPR-016 differential: X03's tweakPoint over X02's liftX recomputes
the official tweakedPubkey x-coordinate for all 7 cases (root as
given); the output key exists (no reject mode fires) on honest data. -/
def checkTweakPoint : IO Nat := do
  let mut fails := 0
  for (name, int, mr, _tw, tweaked, _spk) in spkVectors do
    let intB := fromHex int
    match liftX (bytesToNatBE intB), tweakPoint intB (liftX (bytesToNatBE intB)) (mr.map fromHex) with
    | some _, some (xQ, _yQ) =>
        if xQ != bytesToNatBE (fromHex tweaked) then do
          fails := fails + 1
          IO.println s!"FAIL {name}: x(Q) != official tweakedPubkey"
    | _, _ => do fails := fails + 1; IO.println s!"FAIL {name}: tweakPoint rejected honest data"
  return fails

/-- TPR-011 + TPR-018: the composite `outputKeyOk` accepts exactly the
parity byte matching y(Q) of the recomputed key (control = the 65-byte
m=1 shape, key bytes 1..33 = the official internal pubkey), and
`internalKeyOk` holds on all honest controls. -/
def checkOutputKey : IO Nat := do
  let mut fails := 0
  for (name, int, mr, _tw, _tweaked, _spk) in spkVectors do
    let intB := fromHex int
    let root := mr.map fromHex
    let cEven := mkControl65 2 intB
    let cOdd := mkControl65 3 intB
    if internalKeyOk cEven != true || internalKeyOk cOdd != true then do
      fails := fails + 1; IO.println s!"FAIL {name}: internalKeyOk rejected honest internal key"
    let okEven := outputKeyOk cEven root
    let okOdd := outputKeyOk cOdd root
    if okEven == okOdd then do
      fails := fails + 1
      IO.println s!"FAIL {name}: parity verdict not exclusive (even={okEven}, odd={okOdd})"
    -- the passing control's parity byte equals y(Q) & 1 of the recomputed Q
    match tweakedKey cEven root with
    | some (_xQ, yQ) =>
        let want : ByteArray := if yQ % 2 == 0 then cEven else cOdd
        if outputKeyOk want root != true then do
          fails := fails + 1
          IO.println s!"FAIL {name}: parity byte does not match y(Q)"
    | none => do fails := fails + 1; IO.println s!"FAIL {name}: tweakedKey none on honest data"
  return fails

/-- TPR-007/008: the official key-path witness classifies as a key-path
spend; a script+0xc0-control pair built from the spk-1 vector data
classifies as script-path (and its control passes TPR-009/010). -/
def checkClassification : IO Nat := do
  let mut fails := 0
  -- kp-0: single 64-byte sig => key path
  match classifySpend [kp0Sig] with
  | SpendPath.keyPath sig => if sig != kp0Sig then do fails := fails + 1; IO.println "FAIL kp-0: sig mangled"
  | _ => do fails := fails + 1; IO.println "FAIL kp-0: not keyPath"
  -- key-path with annex (synthetic): [sig, 0x50…] => keyPath over sig
  let annex := ByteArray.empty.push 0x50 ++ mkZeros 3
  match classifySpend [kp0Sig, annex] with
  | SpendPath.keyPath sig => if sig != kp0Sig then do fails := fails + 1; IO.println "FAIL annex-keyPath: sig mangled"
  | _ => do fails := fails + 1; IO.println "FAIL annex-keyPath: not keyPath"
  -- script path (spk-1's script + the official spk-1 control shape
  -- 0xc0 ‖ internal ‖ merkleRoot = 65 bytes = the m=1 lattice point)
  let script := fromHex "20d85a959b0290bf19bb89ed43c916be835475d013da4b362117393e25a48229b8ac"
  let control := (ByteArray.empty.push 0xc0)
      ++ (fromHex "187791b6f712a8ea41c8ecdd0ee77fab3e85263b37e1ec18a3651926b3a6cf27")
      ++ (fromHex "5b75adecf53548f3ec6ad7d78383bf84cc57b55a3127c72b9a2481752dd88b21")
  if control.size != 65 then do fails := fails + 1; IO.println s!"FAIL control size {control.size} != 65"
  if !controlBlockSizeOk control then do fails := fails + 1; IO.println "FAIL: 65-byte (m=1) control rejected"
  if leafVersionOf control != 0xc0 then do fails := fails + 1; IO.println "FAIL: leaf version != 0xc0"
  match classifySpend [script, control] with
  | SpendPath.scriptPath s c =>
      if s != script || c != control then do fails := fails + 1; IO.println "FAIL scriptPath: items mangled"
  | _ => do fails := fails + 1; IO.println "FAIL: not scriptPath"
  -- script path with annex (synthetic 3-item)
  match classifySpend [script, control, annex] with
  | SpendPath.scriptPath s c => if s != script || c != control then do fails := fails + 1; IO.println "FAIL annex-scriptPath: items mangled"
  | _ => do fails := fails + 1; IO.println "FAIL annex-scriptPath: not scriptPath"
  return fails

/-- TPR-005/006 (synthetic annex cases — the official wallet corpus has
none): detection incl. the wrong-tag and empty negatives; annexHash is
32 bytes and deterministic (SHA256(CSize ‖ annex)). -/
def checkAnnex : IO Nat := do
  let mut fails := 0
  let annex := ByteArray.empty.push 0x50 ++ mkZeros 3
  let notAnnex := ByteArray.empty.push 0x51 ++ mkZeros 3
  if !isAnnex [kp0Sig, annex] then do fails := fails + 1; IO.println "FAIL: annex not detected"
  if isAnnex [kp0Sig] then do fails := fails + 1; IO.println "FAIL: single item misdetected as annex"
  if isAnnex [] then do fails := fails + 1; IO.println "FAIL: empty misdetected as annex"
  if isAnnex [kp0Sig, notAnnex] then do fails := fails + 1; IO.println "FAIL: wrong tag 0x51 detected as annex"
  if (annexHash annex).size != 32 then do fails := fails + 1; IO.println "FAIL: annexHash size != 32"
  if annexHash annex != annexHash annex then do fails := fails + 1; IO.println "FAIL: annexHash not deterministic"
  return fails

/-- TPR-009: the control-size lattice at runtime (Core-33 post F-X03-1) —
33 (m=0, the F-X03-1 regression case the old 65-gate wrongly rejected)
and 65 (m=1) ok, 4129 (m=128, the BIP341 maximum) ok, 66 (off-lattice)
and 32 (below the 33-byte base) rejected. -/
def checkControlSizes : IO Nat := do
  let mut fails := 0
  let base33 := (ByteArray.empty.push 0xc0) ++ mkZeros 32
  if !controlBlockSizeOk base33 then do fails := fails + 1; IO.println "FAIL: 33 rejected"
  let base := mkControl65 0xc0 (mkZeros 32)
  if !controlBlockSizeOk base then do fails := fails + 1; IO.println "FAIL: 65 rejected"
  let maxC := (ByteArray.empty.push 0xc0) ++ mkZeros (32 + 128 * 32)
  if maxC.size != TAPROOT_CONTROL_MAX_SIZE then do fails := fails + 1; IO.println "FAIL: max size construction"
  if !controlBlockSizeOk maxC then do fails := fails + 1; IO.println "FAIL: 4129 rejected"
  if controlBlockSizeOk (base ++ mkZeros 1) then do fails := fails + 1; IO.println "FAIL: 66 accepted"
  if controlBlockSizeOk (ByteArray.empty.push 0xc0 ++ mkZeros 31) then
    fails := fails + 1; IO.println "FAIL: 32 accepted"
  return fails

/-- TPR-018 negatives: x ≥ p (0xff…ff30, Schnorr vector 14's key
encoding) and a non-residue x (Schnorr vector 5's pubkey) both fail the
internal-key parse. -/
def checkInternalKeyRejects : IO Nat := do
  let mut fails := 0
  let cGeP := mkControl65 2 (fromHex "FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC30")
  if internalKeyOk cGeP then do fails := fails + 1; IO.println "FAIL: x >= p accepted"
  let cNonQR := mkControl65 2 (fromHex "EEFDEA4CDB677750A420FEE807EACF21EB9898AE79B9768766E4FAA04A2D4A34")
  if internalKeyOk cNonQR then do fails := fails + 1; IO.println "FAIL: non-residue x accepted"
  -- below the 33-byte gate: fail-closed
  if internalKeyOk (ByteArray.empty.push 2 ++ mkZeros 10) then
    fails := fails + 1; IO.println "FAIL: short control internalKeyOk not fail-closed"
  return fails

/-- TPR-022 + TPR-071: the official key-path witness weighs
1(CSize) + 65(sig+hashtype) = 66 → budget 66 + 50 WU; appending an
annex adds its CSize + size to the weight (the annex COUNTS toward
validation weight). -/
def checkValidationWeight : IO Nat := do
  let mut fails := 0
  if validationWeightInit [kp0Sig] != 66 + 50 then
    fails := fails + 1; IO.println s!"FAIL: kp-0 weight {validationWeightInit [kp0Sig]} != 116"
  let annex := ByteArray.empty.push 0x50 ++ mkZeros 3
  let expect := validationWeightInit [kp0Sig] + Int.ofNat ((compactSizeEnc annex.size).size + annex.size)
  if validationWeightInit [kp0Sig, annex] != expect then
    fails := fails + 1; IO.println "FAIL: annex weight not added"
  return fails

/-- TPR-004: the P2A anchor template is recognized and is NOT P2TR;
a P2TR spk is NOT the anchor. -/
def checkP2A : IO Nat := do
  let mut fails := 0
  if !isPayToAnchor 1 (fromHex "4e73") then do fails := fails + 1; IO.println "FAIL: 4e73 not P2A"
  if isPayToAnchor 1 (fromHex "512053a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda343") then
    fails := fails + 1; IO.println "FAIL: P2TR spk misdetected as P2A"
  if isPayToTaproot (fromHex "4e73") then do fails := fails + 1; IO.println "FAIL: P2A misdetected as P2TR"
  return fails

/-- Negative P2TR recognition: P2PKH, bare P2SH, and a v1 program of
the WRONG length (31 bytes) are all not P2TR. -/
def checkRecognitionNegatives : IO Nat := do
  let mut fails := 0
  if isPayToTaproot (fromHex "76a914751e76e8199196d454941c45d1b3a323f1433bd688ac") then
    fails := fails + 1; IO.println "FAIL: P2PKH accepted"
  if isPayToTaproot (fromHex "a914751e76e8199196d454941c45d1b3a323f1433bd687") then
    fails := fails + 1; IO.println "FAIL: P2SH accepted"
  if isPayToTaproot (fromHex "512053a1f6e454df1aa2776a2814a721372d6258050de330b3c6d10ee8f4e0dda") then
    fails := fails + 1; IO.println "FAIL: 31-byte program accepted"
  return fails

/-- TPR-075/078: activation boundary at runtime — the historical
deployment is active exactly from 709,632 (709631 is the last
pre-activation block, 709632 the first active, deep-past active). -/
def checkActivation : IO Nat := do
  let mut fails := 0
  if taprootBip9Deployment.bit != 2 then do fails := fails + 1; IO.println "FAIL: bit != 2"
  if taprootBip9Deployment.minActivation != 709632 then do fails := fails + 1; IO.println "FAIL: minActivation != 709632"
  if deploymentActiveAt taprootBip9Deployment (709631 : UInt32) then
    fails := fails + 1; IO.println "FAIL: active before 709632"
  if !deploymentActiveAt taprootBip9Deployment (709632 : UInt32) then
    fails := fails + 1; IO.println "FAIL: not active at 709632"
  if !deploymentActiveAt taprootBip9Deployment (840000 : UInt32) then
    fails := fails + 1; IO.println "FAIL: not active at 840000"
  return fails

/-- TPR-076/077: flag-regime spot checks — the exception block
…1e395ad has taproot OFF; an ordinary hash at any height has the full
base trio ON. -/
def checkFlagRegime : IO Nat := do
  let mut fails := 0
  if (getBlockScriptFlagsP mainnetParams taprootExceptionHash 0).taproot != false then
    fails := fails + 1; IO.println "FAIL: exception block taproot not off"
  if (getBlockScriptFlagsP mainnetParams taprootExceptionHash 0).witness != true then
    fails := fails + 1; IO.println "FAIL: exception block witness not on"
  if (getBlockScriptFlagsP mainnetParams 0x1234 0).taproot != true then
    fails := fails + 1; IO.println "FAIL: ordinary block taproot not on"
  if (getBlockScriptFlagsP mainnetParams 0x1234 709631).p2sh != true then
    fails := fails + 1; IO.println "FAIL: ordinary block p2sh not on"
  return fails

/-! ## Runner -/

def runAll : IO Unit := do
  let mut fails := 0
  fails := fails + (← checkRecognition)
  IO.println "TPR-001 recognition: 7 official spk + 3 negatives done"
  fails := fails + (← checkTaptweak)
  IO.println "TPR-047/015 taptweak: 7 official tweak fields matched"
  fails := fails + (← checkTweakPoint)
  IO.println "TPR-016 tweakPoint: 7 official tweakedPubkeys recomputed"
  fails := fails + (← checkOutputKey)
  IO.println "TPR-011/018 outputKeyOk: 7 parity-verdict + internal-key checks done"
  fails := fails + (← checkClassification)
  IO.println "TPR-007/008/009/010 classification: kp-0 + annex + script-path done"
  fails := fails + (← checkAnnex)
  IO.println "TPR-005/006 annex: detection + hash done"
  fails := fails + (← checkControlSizes)
  IO.println "TPR-009 control sizes: 33/65/66/32/4129 done"
  fails := fails + (← checkInternalKeyRejects)
  IO.println "TPR-018 internal-key rejects: x>=p / non-QR / short done"
  fails := fails + (← checkValidationWeight)
  IO.println "TPR-022/071 validation weight: 116 WU + annex done"
  fails := fails + (← checkP2A)
  IO.println "TPR-004 P2A: template + discrimination done"
  fails := fails + (← checkRecognitionNegatives)
  IO.println "TPR-001 negatives: P2PKH/P2SH/31-byte done"
  fails := fails + (← checkActivation)
  IO.println "TPR-075/078 activation: 709632 boundary done"
  fails := fails + (← checkFlagRegime)
  IO.println "TPR-076/077 flag regime: exception + always-on done"
  if fails > 0 then throw (IO.userError s!"taproot program rows: {fails} FAILURES")
  IO.println "X06 taproot harness: ALL CHECKS PASSED"

end Bitcoin.Test.Crypto.TaprootProgram

/-- Runner entry (root `main` for `lake env lean --run`). -/
def main : IO Unit := Bitcoin.Test.Crypto.TaprootProgram.runAll
