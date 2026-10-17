import Bitcoin.Wallet.Crypto.Sha512
import Bitcoin.Data.Basic

/-!
# SHA-512 conformance pins

Build-time pins for `Bitcoin.Wallet.Crypto.Sha512` against FIPS 180-4
Appendix C.2 (the byte-oriented examples repeated in the NIST CAVS
corpus). The expected hex strings are the published digests; they were
independently recomputed with `python3 hashlib.sha512` before being
pinned here.

The one-million-byte case is a runtime measurement as much as a
correctness pin: it forces 7,813 compressions through the interpreter.
It is included here rather than in the library module so that ordinary
builds do not pay for it; on the development machine it takes roughly
six seconds.
-/

namespace Test.Wallet.Sha512

open Bitcoin.Wallet.Crypto.Sha512 Bitcoin.Data

/-- FIPS 180-4 C.2.1: SHA-512(""). -/
def emptyHex : String :=
  "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce" ++
  "47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"

/-- FIPS 180-4 C.2.2: SHA-512("abc"). -/
def abcHex : String :=
  "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a" ++
  "2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"

/-- FIPS 180-4 C.2.3: the 112-byte two-block message. -/
def twoBlockMsg : ByteArray :=
  "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmno" ++
  "ijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu" |>.toUTF8

/-- FIPS 180-4 C.2.3 digest. -/
def twoBlockHex : String :=
  "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018" ++
  "501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909"

/-- FIPS 180-4 C.2.4: one million repetitions of `a`. -/
def millionA : ByteArray := ByteArray.mk (Array.replicate 1000000 (0x61 : UInt8))

/-- FIPS 180-4 C.2.4 digest. -/
def millionAHex : String :=
  "e718483d0ce769644e2e42c7bc15b4638e1f98b13b2044285632a803afa973eb" ++
  "de0ff244877ea60a4cb0432ce577c31beb009c5c2c49aa2e4eadb217ad8cc09b"

def abcMsg : ByteArray := "abc".toUTF8

#eval s!"sha512 empty:      {toHex (hash ByteArray.empty) == emptyHex}"
#eval s!"sha512 abc:        {toHex (hash abcMsg) == abcHex}"
#eval s!"sha512 two-block:  {toHex (hash twoBlockMsg) == twoBlockHex}"
#eval s!"sha512 1e6 a:      {toHex (hash millionA) == millionAHex}"

end Test.Wallet.Sha512
