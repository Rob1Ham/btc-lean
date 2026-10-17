import Bitcoin.Wallet.Crypto.Sha512
import Bitcoin.Data.Basic

/-!
# Bitcoin.Wallet.Crypto.Hmac

HMAC as defined by RFC 2104 §2, instantiated with the SHA-512 of
`Bitcoin.Wallet.Crypto.Sha512`. With `B = 128` (the SHA-512 block size)
and the two pad bytes `ipad = 0x36`, `opad = 0x5c`:

  HMAC(K, m) = H((K' ⊕ opad) ‖ H((K' ⊕ ipad) ‖ m))

where `K'` is `K` when `K` is at most 128 bytes and `H(K)` followed by
64 zero bytes otherwise (RFC 2104 §2, "the key is first padded to B
bytes ... longer keys are hashed first").

Bitcoin Core writes the same construction out by hand in
`src/crypto/hmac_sha512.cpp:12-32`: a key of at most 128 bytes is copied
and zero-filled, a longer key is hashed and the tail is zeroed, then the
outer pad (`0x5c`) and the inner pad (`0x36`) are applied to a shared
buffer before the two hash passes. BIP32 consumes this function as
`BIP32Hash` (`src/hash.cpp:71-76`), where the chain code is the key and
the data is a 33-byte key prefix concatenated with a big-endian index.

## What is not modelled

No streaming interface, no key-erasure/`memory_cleanse` behaviour, no
constant-time claim, and no separate HMAC key-length validation beyond
RFC 2104's "hash if longer than the block". The result is a total
function of two byte strings; invalid or weak keys are not distinguished
from strong ones.

## Vectors

The `#eval` block checks all seven test cases of RFC 4231 §4.2–4.8
(the SHA-512 column), including the 131-byte key cases that exercise the
"hash the key first" branch and the truncated-output case, whose full
digest is compared. Expected values were recomputed with
`python3 hmac`/`hashlib` before pinning.
-/

namespace Bitcoin.Wallet.Crypto.Hmac

open Bitcoin.Wallet.Crypto.Sha512

/-- The SHA-512 block size in bytes (RFC 2104 §2, `B = 128`). -/
def blockSize : Nat := 128

/-- HMAC-SHA-512 of a message under a byte-string key (RFC 2104 §2). -/
def hmacSha512 (key msg : ByteArray) : ByteArray :=
  let k := if key.size > blockSize then Sha512.hash key else key
  let k := k ++ appendZeros ByteArray.empty (blockSize - k.size)
  let iPad : ByteArray := ByteArray.mk (k.data.map (fun b => b ^^^ 0x36))
  let oPad : ByteArray := ByteArray.mk (k.data.map (fun b => b ^^^ 0x5c))
  Sha512.hash (oPad ++ Sha512.hash (iPad ++ msg))

/-- The MAC is always a 64-byte SHA-512 digest. -/
theorem hmacSha512_size (key msg : ByteArray) :
    (hmacSha512 key msg).size = 64 := by
  unfold hmacSha512
  exact hash_size _

/-! ## RFC 4231 vectors -/

/-- `n` copies of `b`. -/
def repeatByte (n : Nat) (b : UInt8) : ByteArray :=
  ByteArray.mk (Array.replicate n b)

def tc1Key : ByteArray := repeatByte 20 0x0b
def tc1Msg : ByteArray := "Hi There".toUTF8
def tc1Mac : String :=
  "87aa7cdea5ef619d4ff0b4241a1d6cb02379f4e2ce4ec2787ad0b30545e17cde" ++
  "daa833b7d6b8a702038b274eaea3f4e4be9d914eeb61f1702e696c203a126854"

def tc2Key : ByteArray := "Jefe".toUTF8
def tc2Msg : ByteArray := "what do ya want for nothing?".toUTF8
def tc2Mac : String :=
  "164b7a7bfcf819e2e395fbe73b56e0a387bd64222e831fd610270cd7ea250554" ++
  "9758bf75c05a994a6d034f65f8f0e6fdcaeab1a34d4a6b4b636e070a38bce737"

def tc3Key : ByteArray := repeatByte 20 0xaa
def tc3Msg : ByteArray := repeatByte 50 0xdd
def tc3Mac : String :=
  "fa73b0089d56a284efb0f0756c890be9b1b5dbdd8ee81a3655f83e33b2279d39" ++
  "bf3e848279a722c806b485a47e67c807b946a337bee8942674278859e13292fb"

/-- `0x01, 0x02, ..., 0x19`. -/
def tc4Key : ByteArray := ByteArray.mk ((Array.range 25).map (fun i => (i + 1).toUInt8))
def tc4Msg : ByteArray := repeatByte 50 0xcd
def tc4Mac : String :=
  "b0ba465637458c6990e5a8c5f61d4af7e576d97ff94b872de76f8050361ee3db" ++
  "a91ca5c11aa25eb4d679275cc5788063a5f19741120c4f2de2adebeb10a298dd"

def tc5Key : ByteArray := repeatByte 20 0x0c
def tc5Msg : ByteArray := "Test With Truncation".toUTF8
def tc5Mac : String :=
  "415fad6271580a531d4179bc891d87a650188707922a4fbb36663a1eb16da008" ++
  "711c5b50ddd0fc235084eb9d3364a1454fb2ef67cd1d29fe6773068ea266e96b"

def tc6Key : ByteArray := repeatByte 131 0xaa
def tc6Msg : ByteArray := "Test Using Larger Than Block-Size Key - Hash Key First".toUTF8
def tc6Mac : String :=
  "80b24263c7c1a3ebb71493c1dd7be8b49b46d1f41b4aeec1121b013783f8f352" ++
  "6b56d037e05f2598bd0fd2215d6a1e5295e64f73f63f0aec8b915a985d786598"

def tc7Key : ByteArray := repeatByte 131 0xaa
def tc7Msg : ByteArray :=
  ("This is a test using a larger than block-size key and a larger than " ++
   "block-size data. The key needs to be hashed before being used by the " ++
   "HMAC algorithm.").toUTF8
def tc7Mac : String :=
  "e37b6a775dc87dbaa4dfa9f96e5e3ffddebd71f8867289865df5a32d20cdc944" ++
  "b6022cac3c4982b10d5eeb55c3e4de15134676fb6de0446065c97440fa8c6a58"

#eval s!"rfc4231 tc1: {Bitcoin.Data.toHex (hmacSha512 tc1Key tc1Msg) == tc1Mac}"
#eval s!"rfc4231 tc2: {Bitcoin.Data.toHex (hmacSha512 tc2Key tc2Msg) == tc2Mac}"
#eval s!"rfc4231 tc3: {Bitcoin.Data.toHex (hmacSha512 tc3Key tc3Msg) == tc3Mac}"
#eval s!"rfc4231 tc4: {Bitcoin.Data.toHex (hmacSha512 tc4Key tc4Msg) == tc4Mac}"
#eval s!"rfc4231 tc5: {Bitcoin.Data.toHex (hmacSha512 tc5Key tc5Msg) == tc5Mac}"
#eval s!"rfc4231 tc6: {Bitcoin.Data.toHex (hmacSha512 tc6Key tc6Msg) == tc6Mac}"
#eval s!"rfc4231 tc7: {Bitcoin.Data.toHex (hmacSha512 tc7Key tc7Msg) == tc7Mac}"

end Bitcoin.Wallet.Crypto.Hmac
