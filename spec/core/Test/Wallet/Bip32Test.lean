import Bitcoin.Wallet.Key.Bip32
import Bitcoin.Data.Basic

/-!
# BIP32 conformance pins

Pins for `Bitcoin.Wallet.Key.Bip32` against the official test vectors 1–3
in `bip-0032.mediawiki` ("Test Vectors"). Each row compares the model's
raw 78-byte extended-key payloads with the payloads decoded from the
published `xprv` / `xpub` Base58Check strings. Decoding and checksum
verification were done outside Lean with an independent script; the
Base58 wrapper itself is deliberately not part of this module.

For every row the private payload is produced by `masterFromSeed` followed
by `derivePath`. The public payload is produced by `neuter` of the private
node, so it also pins the `ser_P(K)` encoding. Rows whose whole path is
non-hardened additionally exercise `ckdPub` through `derivePubPath` on the
neutered master.

The vectors are also the deadline for the leading-zero cases: vector 3
exists precisely because its master secret and `m/0'` secret have leading
zero bytes, which a fixed-width `ser₂₅₆` must retain.
-/

namespace Test.Wallet.Bip32

open Bitcoin.Wallet.Key Bitcoin.Data

/-- Test-only hex decoder. -/
def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  digit (c : Char) : Option Nat :=
    let n := c.toNat
    if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
    else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
    else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
    else none
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match digit a, digit b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

/-- One expected vector row: label, derivation path and the two payloads. -/
structure Row where
  label : String
  path : List UInt32
  xprv : ByteArray
  xpub : ByteArray

def row (label : String) (path : List UInt32) (prv pub : String) : Row :=
  { label, path, xprv := fromHex prv, xpub := fromHex pub }

/-- Vector 1, seed `000102…0e0f`. -/
def vector1Seed : ByteArray := fromHex "000102030405060708090a0b0c0d0e0f"

def vector1 : List Row :=
  [ row "m" []
      "0488ade4000000000000000000873dff81c02f525623fd1fe5167eac3a55a049de3d314bb42ee227ffed37d50800e8f32e723decf4051aefac8e2c93c9c5b214313817cdb01a1494b917c8436b35"
      "0488b21e000000000000000000873dff81c02f525623fd1fe5167eac3a55a049de3d314bb42ee227ffed37d5080339a36013301597daef41fbe593a02cc513d0b55527ec2df1050e2e8ff49c85c2",
    row "m/0'" [0x80000000]
      "0488ade4013442193e8000000047fdacbd0f1097043b78c63c20c34ef4ed9a111d980047ad16282c7ae623614100edb2e14f9ee77d26dd93b4ecede8d16ed408ce149b6cd80b0715a2d911a0afea"
      "0488b21e013442193e8000000047fdacbd0f1097043b78c63c20c34ef4ed9a111d980047ad16282c7ae6236141035a784662a4a20a65bf6aab9ae98a6c068a81c52e4b032c0fb5400c706cfccc56",
    row "m/0'/1" [0x80000000, 1]
      "0488ade4025c1bd648000000012a7857631386ba23dacac34180dd1983734e444fdbf774041578e9b6adb37c19003c6cb8d0f6a264c91ea8b5030fadaa8e538b020f0a387421a12de9319dc93368"
      "0488b21e025c1bd648000000012a7857631386ba23dacac34180dd1983734e444fdbf774041578e9b6adb37c1903501e454bf00751f24b1b489aa925215d66af2234e3891c3b21a52bedb3cd711c",
    row "m/0'/1/2'" [0x80000000, 1, 0x80000002]
      "0488ade403bef5a2f98000000204466b9cc8e161e966409ca52986c584f07e9dc81f735db683c3ff6ec7b1503f00cbce0d719ecf7431d88e6a89fa1483e02e35092af60c042b1df2ff59fa424dca"
      "0488b21e03bef5a2f98000000204466b9cc8e161e966409ca52986c584f07e9dc81f735db683c3ff6ec7b1503f0357bfe1e341d01c69fe5654309956cbea516822fba8a601743a012a7896ee8dc2",
    row "m/0'/1/2'/2" [0x80000000, 1, 0x80000002, 2]
      "0488ade404ee7ab90c00000002cfb71883f01676f587d023cc53a35bc7f88f724b1f8c2892ac1275ac822a3edd000f479245fb19a38a1954c5c7c0ebab2f9bdfd96a17563ef28a6a4b1a2a764ef4"
      "0488b21e04ee7ab90c00000002cfb71883f01676f587d023cc53a35bc7f88f724b1f8c2892ac1275ac822a3edd02e8445082a72f29b75ca48748a914df60622a609cacfce8ed0e35804560741d29",
    row "m/0'/1/2'/2/1000000000" [0x80000000, 1, 0x80000002, 2, 1000000000]
      "0488ade405d880d7d83b9aca00c783e67b921d2beb8f6b389cc646d7263b4145701dadd2161548a8b078e65e9e00471b76e389e528d6de6d816857e012c5455051cad6660850e58372a6c3e6e7c8"
      "0488b21e05d880d7d83b9aca00c783e67b921d2beb8f6b389cc646d7263b4145701dadd2161548a8b078e65e9e022a471424da5e657499d1ff51cb43c47481a03b1e77f951fe64cec9f5a48f7011" ]

/-- Vector 2, the descending seed. -/
def vector2Seed : ByteArray :=
  fromHex "fffcf9f6f3f0edeae7e4e1dedbd8d5d2cfccc9c6c3c0bdbab7b4b1aeaba8a5a29f9c999693908d8a8784817e7b7875726f6c696663605d5a5754514e4b484542"

def vector2 : List Row :=
  [ row "m" []
      "0488ade400000000000000000060499f801b896d83179a4374aeb7822aaeaceaa0db1f85ee3e904c4defbd9689004b03d6fc340455b363f51020ad3ecca4f0850280cf436c70c727923f6db46c3e"
      "0488b21e00000000000000000060499f801b896d83179a4374aeb7822aaeaceaa0db1f85ee3e904c4defbd968903cbcaa9c98c877a26977d00825c956a238e8dddfbd322cce4f74b0b5bd6ace4a7",
    row "m/0" [0]
      "0488ade401bd16bee500000000f0909affaa7ee7abe5dd4e100598d4dc53cd709d5a5c2cac40e7412f232f7c9c00abe74a98f6c7eabee0428f53798f0ab8aa1bd37873999041703c742f15ac7e1e"
      "0488b21e01bd16bee500000000f0909affaa7ee7abe5dd4e100598d4dc53cd709d5a5c2cac40e7412f232f7c9c02fc9e5af0ac8d9b3cecfe2a888e2117ba3d089d8585886c9c826b6b22a98d12ea",
    row "m/0/2147483647'" [0, 0xFFFFFFFF]
      "0488ade4025a61ff8effffffffbe17a268474a6bb9c61e1d720cf6215e2a88c5406c4aee7b38547f585c9a37d900877c779ad9687164e9c2f4f0f4ff0340814392330693ce95a58fe18fd52e6e93"
      "0488b21e025a61ff8effffffffbe17a268474a6bb9c61e1d720cf6215e2a88c5406c4aee7b38547f585c9a37d903c01e7425647bdefa82b12d9bad5e3e6865bee0502694b94ca58b666abc0a5c3b",
    row "m/0/2147483647'/1" [0, 0xFFFFFFFF, 1]
      "0488ade403d8ab493700000001f366f48f1ea9f2d1d3fe958c95ca84ea18e4c4ddb9366c336c927eb246fb38cb00704addf544a06e5ee4bea37098463c23613da32020d604506da8c0518e1da4b7"
      "0488b21e03d8ab493700000001f366f48f1ea9f2d1d3fe958c95ca84ea18e4c4ddb9366c336c927eb246fb38cb03a7d1d856deb74c508e05031f9895dab54626251b3806e16b4bd12e781a7df5b9",
    row "m/0/2147483647'/1/2147483646'" [0, 0xFFFFFFFF, 1, 0xFFFFFFFE]
      "0488ade40478412e3afffffffe637807030d55d01f9a0cb3a7839515d796bd07706386a6eddf06cc29a65a0e2900f1c7c871a54a804afe328b4c83a1c33b8e5ff48f5087273f04efa83b247d6a2d"
      "0488b21e0478412e3afffffffe637807030d55d01f9a0cb3a7839515d796bd07706386a6eddf06cc29a65a0e2902d2b36900396c9282fa14628566582f206a5dd0bcc8d5e892611806cafb0301f0",
    row "m/0/2147483647'/1/2147483646'/2" [0, 0xFFFFFFFF, 1, 0xFFFFFFFE, 2]
      "0488ade40531a507b8000000029452b549be8cea3ecb7a84bec10dcfd94afe4d129ebfd3b3cb58eedf394ed27100bb7d39bdb83ecf58f2fd82b6d918341cbef428661ef01ab97c28a4842125ac23"
      "0488b21e0531a507b8000000029452b549be8cea3ecb7a84bec10dcfd94afe4d129ebfd3b3cb58eedf394ed271024d902e1a2fc7a8755ab5b694c575fce742c48d9ff192e63df5193e4c7afe1f9c" ]

/-- Vector 3, the leading-zero seed. -/
def vector3Seed : ByteArray :=
  fromHex "4b381541583be4423346c643850da4b320e46a87ae3d2a4e6da11eba819cd4acba45d239319ac14f863b8d5ab5a0d0c64d2e8a1e7d1457df2e5a3c51c73235be"

def vector3 : List Row :=
  [ row "m" []
      "0488ade400000000000000000001d28a3e53cffa419ec122c968b3259e16b65076495494d97cae10bbfec3c36f0000ddb80b067e0d4993197fe10f2657a844a384589847602d56f0c629c81aae32"
      "0488b21e00000000000000000001d28a3e53cffa419ec122c968b3259e16b65076495494d97cae10bbfec3c36f03683af1ba5743bdfc798cf814efeeab2735ec52d95eced528e692b8e34c4e5669",
    row "m/0'" [0x80000000]
      "0488ade40141d63b5080000000e5fea12a97b927fc9dc3d2cb0d1ea1cf50aa5a1fdc1f933e8906bb38df3377bd00491f7a2eebc7b57028e0d3faa0acda02e75c33b03c48fb288c41e2ea44e1daef"
      "0488b21e0141d63b5080000000e5fea12a97b927fc9dc3d2cb0d1ea1cf50aa5a1fdc1f933e8906bb38df3377bd026557fdda1d5d43d79611f784780471f086d58e8126b8c40acb82272a7712e7f2" ]

/-- Fail a vector row with both payloads in the message. -/
def checkRow (seed : ByteArray) (r : Row) : IO Unit :=
  match masterFromSeed seed with
  | .error e => throw (IO.userError s!"{r.label}: master failed: {repr e}")
  | .ok m =>
    match derivePath m r.path with
    | .error e => throw (IO.userError s!"{r.label}: derive failed: {repr e}")
    | .ok y =>
      let prv := serializePriv y
      let pub := serializePub (neuter y)
      if prv = r.xprv ∧ pub = r.xpub then pure ()
      else
        let msg := s!"{r.label}: mismatch
  xprv expected {toHex r.xprv}
  xprv got      {toHex prv}
  xpub expected {toHex r.xpub}
  xpub got      {toHex pub}"
        throw (IO.userError msg)

/-- For an all-non-hardened path, check that public derivation from the
neutered master reaches the same payload as the private derivation. -/
def checkPubAgreement (seed : ByteArray) (r : Row) : IO Unit :=
  if r.path.any isHardened then pure ()
  else
    match masterFromSeed seed with
    | .error e => throw (IO.userError s!"{r.label}: master failed: {repr e}")
    | .ok m =>
      match derivePubPath (neuter m) r.path with
      | .error e => throw (IO.userError s!"{r.label}: pub derive failed: {repr e}")
      | .ok y =>
        if serializePub y = r.xpub then pure ()
        else
          let msg := s!"{r.label}: pub agreement mismatch
  expected {toHex r.xpub}
  got      {toHex (serializePub y)}"
          throw (IO.userError msg)

def checkAll (seed : ByteArray) (rows : List Row) : IO Unit := do
  for r in rows do
    checkRow seed r
    checkPubAgreement seed r

/-- The 78-byte length that the vector hex strings already exhibit. -/
def checkLength (r : Row) : IO Unit :=
  if r.xprv.size = 78 ∧ r.xpub.size = 78 then pure ()
  else
    let msg := s!"{r.label}: expected 78-byte payloads, got {r.xprv.size} and {r.xpub.size}"
    throw (IO.userError msg)

#eval checkAll vector1Seed vector1
#eval checkAll vector2Seed vector2
#eval checkAll vector3Seed vector3
#eval (vector1 ++ vector2 ++ vector3).forM checkLength

/-- Hardened public derivation must fail, not silently derive. -/
def checkHardenedPubFails : IO Unit :=
  match masterFromSeed vector1Seed with
  | .error e => throw (IO.userError s!"master: {repr e}")
  | .ok m =>
    match ckdPub (neuter m) 0x80000000 with
    | .error .hardenedFromPublic => pure ()
    | .error e => throw (IO.userError s!"expected hardenedFromPublic, got {repr e}")
    | .ok _ => throw (IO.userError "expected hardenedFromPublic, derivation succeeded")

/-- A 15-byte seed is below BIP32's 16-byte minimum; Core asserts it
(`src/key.cpp:381-392`), this model returns an error. -/
def checkShortSeedFails : IO Unit :=
  match masterFromSeed (fromHex "000102030405060708090a0b0c0d0e") with
  | .error .invalidSeedLength => pure ()
  | .error e => throw (IO.userError s!"expected invalidSeedLength, got {repr e}")
  | .ok _ => throw (IO.userError "expected invalidSeedLength, master succeeded")

/-- Depth 255 cannot produce a child. -/
def checkDepthOverflow : IO Unit :=
  match masterFromSeed vector1Seed with
  | .error e => throw (IO.userError s!"master: {repr e}")
  | .ok m =>
    let deep : ExtPrivKey := { m with depth := 0xFF }
    match ckdPriv deep 0 with
    | .error .depthOverflow => pure ()
    | .error e => throw (IO.userError s!"expected depthOverflow, got {repr e}")
    | .ok _ => throw (IO.userError "expected depthOverflow, derivation succeeded")

#eval checkHardenedPubFails
#eval checkShortSeedFails
#eval checkDepthOverflow

end Test.Wallet.Bip32
