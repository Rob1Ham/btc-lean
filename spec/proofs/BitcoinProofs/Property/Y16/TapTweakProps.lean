import Bitcoin.Crypto.Taproot.TapTweak
import Bitcoin.Crypto.Curve.Secp

/-!
# BitcoinProofs.Property.Y16 — property corpus: TapTweak / curve-edges

Review-4 support suite contributor Y16, 2026-10-16. NEW file, owned by Y16.

Ground truth: BIP341 §3 (t = hash_TapTweak(p ‖ k_m), Q = lift_x(int(p)) +
t·G), BIP340 (int_from_bytes big-endian, lift_x even-y), libsecp256k1
extrakeys_main_impl.h:142-161 + eckey_impl.h:23-33 @ cce32b168 (tweak_add
rejects iff t ≥ n OR P + t·G = ∞). The python reference
`scratch/Y16/twtref.py` is validated against the vendored BIP341 wallet
vectors (7/7 tweak hashes, 6/6 output keys) and every EXPECTED value
below comes from it — never from the Lean code. Generator:
`scratch/Y16/gen.py`, seed 20261016 — regenerates this file byte-for-byte.

TWO assertion lanes (kernel economics, F-Y16-004 in findings-w4/Y16.md):
* `decide` lane — structural cases only (kernel whnf stops at the
  WF-recursive egcd/expM/mulP, so computed curve cases cannot decide);
* `#eval` + `#guard_msgs` lane — for every computed case the EXPECTED
  VERDICT from the python reference is a constant below; the section
  `#eval` compares the Lean computation against it and `#guard_msgs`
  FAILS THE BUILD on any divergence (axiom-free, no `native_decide`).

Sections: A BIP341 real vectors (7) · B taptweak byte edges (8) ·
C tweakScalar BE + TPR-017 accept · D addP edges (13) · E negation (6) ·
F liftX edges (5) · G mulP edges + infinity reject (16) ·
H seeded random x-only keys end-to-end (11). 68 cases total.
-/

namespace BitcoinProofs.Property.Y16.TapTweakProps

open Bitcoin.Crypto.Curve.Secp Bitcoin.Crypto.Schnorr Bitcoin.Crypto.Taproot

set_option maxRecDepth 10000
set_option maxHeartbeats 2000000

/-- bip01p — BIP internal key (x-only) -/
def bip01p : ByteArray := ByteArray.mk #[(0xd6:UInt8), (0x88:UInt8), (0x9c:UInt8), (0xb0:UInt8), (0x81:UInt8), (0x03:UInt8), (0x6e:UInt8), (0x0f:UInt8), (0xae:UInt8), (0xfa:UInt8), (0x3a:UInt8), (0x35:UInt8), (0x15:UInt8), (0x7a:UInt8), (0xd7:UInt8), (0x10:UInt8), (0x86:UInt8), (0xb1:UInt8), (0x23:UInt8), (0xb2:UInt8), (0xb1:UInt8), (0x44:UInt8), (0xb6:UInt8), (0x49:UInt8), (0x79:UInt8), (0x8b:UInt8), (0x49:UInt8), (0x4c:UInt8), (0x30:UInt8), (0x0a:UInt8), (0x96:UInt8), (0x1d:UInt8)]
/-- bip02p — BIP internal key (x-only) -/
def bip02p : ByteArray := ByteArray.mk #[(0x18:UInt8), (0x77:UInt8), (0x91:UInt8), (0xb6:UInt8), (0xf7:UInt8), (0x12:UInt8), (0xa8:UInt8), (0xea:UInt8), (0x41:UInt8), (0xc8:UInt8), (0xec:UInt8), (0xdd:UInt8), (0x0e:UInt8), (0xe7:UInt8), (0x7f:UInt8), (0xab:UInt8), (0x3e:UInt8), (0x85:UInt8), (0x26:UInt8), (0x3b:UInt8), (0x37:UInt8), (0xe1:UInt8), (0xec:UInt8), (0x18:UInt8), (0xa3:UInt8), (0x65:UInt8), (0x19:UInt8), (0x26:UInt8), (0xb3:UInt8), (0xa6:UInt8), (0xcf:UInt8), (0x27:UInt8)]
/-- bip02r — BIP merkle root -/
def bip02r : ByteArray := ByteArray.mk #[(0x5b:UInt8), (0x75:UInt8), (0xad:UInt8), (0xec:UInt8), (0xf5:UInt8), (0x35:UInt8), (0x48:UInt8), (0xf3:UInt8), (0xec:UInt8), (0x6a:UInt8), (0xd7:UInt8), (0xd7:UInt8), (0x83:UInt8), (0x83:UInt8), (0xbf:UInt8), (0x84:UInt8), (0xcc:UInt8), (0x57:UInt8), (0xb5:UInt8), (0x5a:UInt8), (0x31:UInt8), (0x27:UInt8), (0xc7:UInt8), (0x2b:UInt8), (0x9a:UInt8), (0x24:UInt8), (0x81:UInt8), (0x75:UInt8), (0x2d:UInt8), (0xd8:UInt8), (0x8b:UInt8), (0x21:UInt8)]
/-- bip03p — BIP internal key (x-only) -/
def bip03p : ByteArray := ByteArray.mk #[(0x93:UInt8), (0x47:UInt8), (0x8e:UInt8), (0x94:UInt8), (0x88:UInt8), (0xf9:UInt8), (0x56:UInt8), (0xdf:UInt8), (0x23:UInt8), (0x96:UInt8), (0xbe:UInt8), (0x2c:UInt8), (0xe6:UInt8), (0xc5:UInt8), (0xcc:UInt8), (0xed:UInt8), (0x75:UInt8), (0xf9:UInt8), (0x00:UInt8), (0xdf:UInt8), (0xa1:UInt8), (0x8e:UInt8), (0x7d:UInt8), (0xab:UInt8), (0xd2:UInt8), (0x42:UInt8), (0x8a:UInt8), (0xae:UInt8), (0x78:UInt8), (0x45:UInt8), (0x18:UInt8), (0x20:UInt8)]
/-- bip03r — BIP merkle root -/
def bip03r : ByteArray := ByteArray.mk #[(0xc5:UInt8), (0x25:UInt8), (0x71:UInt8), (0x4a:UInt8), (0x7f:UInt8), (0x49:UInt8), (0xc2:UInt8), (0x8a:UInt8), (0xed:UInt8), (0xbb:UInt8), (0xba:UInt8), (0x78:UInt8), (0xc0:UInt8), (0x05:UInt8), (0x93:UInt8), (0x1a:UInt8), (0x81:UInt8), (0xc2:UInt8), (0x34:UInt8), (0xb2:UInt8), (0xf6:UInt8), (0xc9:UInt8), (0x9a:UInt8), (0x73:UInt8), (0xe4:UInt8), (0xd0:UInt8), (0x60:UInt8), (0x82:UInt8), (0xad:UInt8), (0xc8:UInt8), (0xbf:UInt8), (0x2b:UInt8)]
/-- bip04p — BIP internal key (x-only) -/
def bip04p : ByteArray := ByteArray.mk #[(0x55:UInt8), (0xad:UInt8), (0xf4:UInt8), (0xe8:UInt8), (0x96:UInt8), (0x7f:UInt8), (0xbd:UInt8), (0x2e:UInt8), (0x29:UInt8), (0xf2:UInt8), (0x0a:UInt8), (0xc8:UInt8), (0x96:UInt8), (0xe6:UInt8), (0x0c:UInt8), (0x3b:UInt8), (0x0f:UInt8), (0x1d:UInt8), (0x5b:UInt8), (0x0e:UInt8), (0xfa:UInt8), (0x9d:UInt8), (0x34:UInt8), (0x94:UInt8), (0x1b:UInt8), (0x59:UInt8), (0x58:UInt8), (0xc7:UInt8), (0xb0:UInt8), (0xa0:UInt8), (0x31:UInt8), (0x2d:UInt8)]
/-- bip04r — BIP merkle root -/
def bip04r : ByteArray := ByteArray.mk #[(0x2f:UInt8), (0x6b:UInt8), (0x2c:UInt8), (0x53:UInt8), (0x97:UInt8), (0xb6:UInt8), (0xd6:UInt8), (0x8c:UInt8), (0xa1:UInt8), (0x8e:UInt8), (0x09:UInt8), (0xa3:UInt8), (0xf0:UInt8), (0x51:UInt8), (0x61:UInt8), (0x66:UInt8), (0x8f:UInt8), (0xfe:UInt8), (0x93:UInt8), (0xa9:UInt8), (0x88:UInt8), (0x58:UInt8), (0x2d:UInt8), (0x55:UInt8), (0xc6:UInt8), (0xf0:UInt8), (0x7b:UInt8), (0xd5:UInt8), (0xb3:UInt8), (0x32:UInt8), (0x9d:UInt8), (0xef:UInt8)]
/-- bip05p — BIP internal key (x-only) -/
def bip05p : ByteArray := ByteArray.mk #[(0xee:UInt8), (0x4f:UInt8), (0xe0:UInt8), (0x85:UInt8), (0x98:UInt8), (0x34:UInt8), (0x62:UInt8), (0xa1:UInt8), (0x84:UInt8), (0x01:UInt8), (0x5d:UInt8), (0x1f:UInt8), (0x78:UInt8), (0x2d:UInt8), (0x6a:UInt8), (0x5f:UInt8), (0x8b:UInt8), (0x9c:UInt8), (0x2b:UInt8), (0x60:UInt8), (0x13:UInt8), (0x0a:UInt8), (0xff:UInt8), (0x05:UInt8), (0x0c:UInt8), (0xe2:UInt8), (0x21:UInt8), (0xec:UInt8), (0xf3:UInt8), (0x78:UInt8), (0x65:UInt8), (0x92:UInt8)]
/-- bip05r — BIP merkle root -/
def bip05r : ByteArray := ByteArray.mk #[(0x6c:UInt8), (0x2d:UInt8), (0xc1:UInt8), (0x06:UInt8), (0xab:UInt8), (0x81:UInt8), (0x6b:UInt8), (0x73:UInt8), (0xf9:UInt8), (0xd0:UInt8), (0x7e:UInt8), (0x3c:UInt8), (0xd1:UInt8), (0xef:UInt8), (0x2c:UInt8), (0x8c:UInt8), (0x12:UInt8), (0x56:UInt8), (0xf5:UInt8), (0x19:UInt8), (0x74:UInt8), (0x8e:UInt8), (0x08:UInt8), (0x13:UInt8), (0xe4:UInt8), (0xed:UInt8), (0xd2:UInt8), (0x40:UInt8), (0x5d:UInt8), (0x27:UInt8), (0x7b:UInt8), (0xef:UInt8)]
/-- bip06p — BIP internal key (x-only) -/
def bip06p : ByteArray := ByteArray.mk #[(0xe0:UInt8), (0xdf:UInt8), (0xe2:UInt8), (0x30:UInt8), (0x0b:UInt8), (0x0d:UInt8), (0xd7:UInt8), (0x46:UInt8), (0xa3:UInt8), (0xf8:UInt8), (0x67:UInt8), (0x4d:UInt8), (0xfd:UInt8), (0x45:UInt8), (0x25:UInt8), (0x62:UInt8), (0x36:UInt8), (0x39:UInt8), (0x04:UInt8), (0x25:UInt8), (0x69:UInt8), (0xd8:UInt8), (0x29:UInt8), (0xc7:UInt8), (0xf0:UInt8), (0xee:UInt8), (0xd9:UInt8), (0x60:UInt8), (0x2d:UInt8), (0x26:UInt8), (0x3e:UInt8), (0x6f:UInt8)]
/-- bip06r — BIP merkle root -/
def bip06r : ByteArray := ByteArray.mk #[(0xcc:UInt8), (0xbd:UInt8), (0x66:UInt8), (0xc6:UInt8), (0xf7:UInt8), (0xe8:UInt8), (0xfd:UInt8), (0xab:UInt8), (0x47:UInt8), (0xb3:UInt8), (0xa4:UInt8), (0x86:UInt8), (0xf5:UInt8), (0x9d:UInt8), (0x28:UInt8), (0x26:UInt8), (0x2b:UInt8), (0xe8:UInt8), (0x57:UInt8), (0xf3:UInt8), (0x0d:UInt8), (0x47:UInt8), (0x73:UInt8), (0xf2:UInt8), (0xd5:UInt8), (0xea:UInt8), (0x47:UInt8), (0xf7:UInt8), (0x76:UInt8), (0x1c:UInt8), (0xe0:UInt8), (0xe2:UInt8)]
/-- bip07p — BIP internal key (x-only) -/
def bip07p : ByteArray := ByteArray.mk #[(0xf9:UInt8), (0xf4:UInt8), (0x00:UInt8), (0x80:UInt8), (0x3e:UInt8), (0x68:UInt8), (0x37:UInt8), (0x27:UInt8), (0xb1:UInt8), (0x4f:UInt8), (0x46:UInt8), (0x38:UInt8), (0x36:UInt8), (0xe1:UInt8), (0xe7:UInt8), (0x8e:UInt8), (0x1c:UInt8), (0x64:UInt8), (0x41:UInt8), (0x76:UInt8), (0x38:UInt8), (0xaa:UInt8), (0x06:UInt8), (0x69:UInt8), (0x19:UInt8), (0x29:UInt8), (0x1a:UInt8), (0x22:UInt8), (0x5f:UInt8), (0x0e:UInt8), (0x8d:UInt8), (0xd8:UInt8)]
/-- bip07r — BIP merkle root -/
def bip07r : ByteArray := ByteArray.mk #[(0xab:UInt8), (0x17:UInt8), (0x94:UInt8), (0x31:UInt8), (0xc2:UInt8), (0x8d:UInt8), (0x3b:UInt8), (0x68:UInt8), (0xfb:UInt8), (0x79:UInt8), (0x89:UInt8), (0x57:UInt8), (0xfa:UInt8), (0xf5:UInt8), (0x49:UInt8), (0x7d:UInt8), (0x69:UInt8), (0xc8:UInt8), (0x83:UInt8), (0xc6:UInt8), (0xfb:UInt8), (0x1e:UInt8), (0x1c:UInt8), (0xd9:UInt8), (0xf8:UInt8), (0x14:UInt8), (0x83:UInt8), (0xd8:UInt8), (0x7b:UInt8), (0xac:UInt8), (0x90:UInt8), (0xcc:UInt8)]
/-- edgeempty32p — 0-byte key material -/
def edgeempty32p : ByteArray := ByteArray.mk #[]
/-- edgeonep — 1-byte key material -/
def edgeonep : ByteArray := ByteArray.mk #[(0x01:UInt8)]
/-- edge31bp — 31-byte key material -/
def edge31bp : ByteArray := ByteArray.mk #[(0x01:UInt8), (0x02:UInt8), (0x03:UInt8), (0x04:UInt8), (0x05:UInt8), (0x06:UInt8), (0x07:UInt8), (0x08:UInt8), (0x09:UInt8), (0x0a:UInt8), (0x0b:UInt8), (0x0c:UInt8), (0x0d:UInt8), (0x0e:UInt8), (0x0f:UInt8), (0x10:UInt8), (0x11:UInt8), (0x12:UInt8), (0x13:UInt8), (0x14:UInt8), (0x15:UInt8), (0x16:UInt8), (0x17:UInt8), (0x18:UInt8), (0x19:UInt8), (0x1a:UInt8), (0x1b:UInt8), (0x1c:UInt8), (0x1d:UInt8), (0x1e:UInt8), (0x1f:UInt8)]
/-- edge32zerop — 32-byte key material -/
def edge32zerop : ByteArray := ByteArray.mk #[(0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8)]
/-- edge32ffp — 32-byte key material -/
def edge32ffp : ByteArray := ByteArray.mk #[(0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8)]
/-- edge33bp — 33-byte key material -/
def edge33bp : ByteArray := ByteArray.mk #[(0x00:UInt8), (0x01:UInt8), (0x02:UInt8), (0x03:UInt8), (0x04:UInt8), (0x05:UInt8), (0x06:UInt8), (0x07:UInt8), (0x08:UInt8), (0x09:UInt8), (0x0a:UInt8), (0x0b:UInt8), (0x0c:UInt8), (0x0d:UInt8), (0x0e:UInt8), (0x0f:UInt8), (0x10:UInt8), (0x11:UInt8), (0x12:UInt8), (0x13:UInt8), (0x14:UInt8), (0x15:UInt8), (0x16:UInt8), (0x17:UInt8), (0x18:UInt8), (0x19:UInt8), (0x1a:UInt8), (0x1b:UInt8), (0x1c:UInt8), (0x1d:UInt8), (0x1e:UInt8), (0x1f:UInt8), (0x07:UInt8)]
/-- edge64bp — 64-byte key material -/
def edge64bp : ByteArray := ByteArray.mk #[(0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8)]
/-- emptyrootp — 32×11 key -/
def emptyrootp : ByteArray := ByteArray.mk #[(0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8), (0x11:UInt8)]
def tscbip01p : ByteArray := ByteArray.mk #[(0xd6:UInt8), (0x88:UInt8), (0x9c:UInt8), (0xb0:UInt8), (0x81:UInt8), (0x03:UInt8), (0x6e:UInt8), (0x0f:UInt8), (0xae:UInt8), (0xfa:UInt8), (0x3a:UInt8), (0x35:UInt8), (0x15:UInt8), (0x7a:UInt8), (0xd7:UInt8), (0x10:UInt8), (0x86:UInt8), (0xb1:UInt8), (0x23:UInt8), (0xb2:UInt8), (0xb1:UInt8), (0x44:UInt8), (0xb6:UInt8), (0x49:UInt8), (0x79:UInt8), (0x8b:UInt8), (0x49:UInt8), (0x4c:UInt8), (0x30:UInt8), (0x0a:UInt8), (0x96:UInt8), (0x1d:UInt8)]
def tscbip01r : ByteArray := ByteArray.mk #[(0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8)]
def tscsc32ffp : ByteArray := ByteArray.mk #[(0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8), (0xff:UInt8)]
def tscsc32ffr : ByteArray := ByteArray.mk #[(0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8), (0x00:UInt8)]
def rnd02r : ByteArray := ByteArray.mk #[(0x37:UInt8), (0x53:UInt8), (0x19:UInt8), (0x01:UInt8), (0x46:UInt8), (0x5a:UInt8), (0x58:UInt8), (0x86:UInt8), (0xcf:UInt8), (0xbb:UInt8), (0xbf:UInt8), (0xe2:UInt8), (0xa9:UInt8), (0x7e:UInt8), (0x9e:UInt8), (0xf0:UInt8), (0x80:UInt8), (0xc7:UInt8), (0x42:UInt8), (0xd5:UInt8), (0x4a:UInt8), (0x0b:UInt8), (0xc6:UInt8), (0xb1:UInt8), (0xfc:UInt8), (0x85:UInt8), (0xeb:UInt8), (0x33:UInt8), (0xbb:UInt8), (0xfd:UInt8), (0xd9:UInt8), (0x3c:UInt8)]
def p32_rnd02 : ByteArray := ByteArray.mk #[(0x39:UInt8), (0x27:UInt8), (0x9a:UInt8), (0x19:UInt8), (0x79:UInt8), (0x95:UInt8), (0x2e:UInt8), (0xe7:UInt8), (0x07:UInt8), (0x3c:UInt8), (0x95:UInt8), (0x3c:UInt8), (0xb4:UInt8), (0x90:UInt8), (0x04:UInt8), (0x4e:UInt8), (0xa9:UInt8), (0x2f:UInt8), (0xa5:UInt8), (0x2b:UInt8), (0x3b:UInt8), (0x41:UInt8), (0xf8:UInt8), (0xb5:UInt8), (0x9a:UInt8), (0x9b:UInt8), (0xf5:UInt8), (0x92:UInt8), (0x80:UInt8), (0x38:UInt8), (0x1d:UInt8), (0xe4:UInt8)]
def p32_rnd04 : ByteArray := ByteArray.mk #[(0x17:UInt8), (0xf9:UInt8), (0x4f:UInt8), (0x3b:UInt8), (0xc9:UInt8), (0x5c:UInt8), (0x88:UInt8), (0x98:UInt8), (0x26:UInt8), (0x35:UInt8), (0xf8:UInt8), (0x78:UInt8), (0x8a:UInt8), (0x11:UInt8), (0xdd:UInt8), (0xec:UInt8), (0x85:UInt8), (0x3a:UInt8), (0x46:UInt8), (0x96:UInt8), (0xdb:UInt8), (0x65:UInt8), (0xb7:UInt8), (0x2f:UInt8), (0xc5:UInt8), (0x64:UInt8), (0x4f:UInt8), (0x12:UInt8), (0x40:UInt8), (0x83:UInt8), (0x69:UInt8), (0x4d:UInt8)]
def p32_rnd07 : ByteArray := ByteArray.mk #[(0x9a:UInt8), (0xf9:UInt8), (0xea:UInt8), (0x03:UInt8), (0x99:UInt8), (0x0c:UInt8), (0xcf:UInt8), (0x81:UInt8), (0x58:UInt8), (0x7e:UInt8), (0x95:UInt8), (0x51:UInt8), (0x77:UInt8), (0x00:UInt8), (0xc5:UInt8), (0xc9:UInt8), (0x1c:UInt8), (0x4c:UInt8), (0x06:UInt8), (0x73:UInt8), (0xa0:UInt8), (0xf6:UInt8), (0xcf:UInt8), (0x04:UInt8), (0x57:UInt8), (0x86:UInt8), (0xb5:UInt8), (0x60:UInt8), (0xa1:UInt8), (0x6e:UInt8), (0xfc:UInt8), (0x06:UInt8)]
def rnd08r : ByteArray := ByteArray.mk #[(0x3e:UInt8), (0x33:UInt8), (0x81:UInt8), (0x39:UInt8), (0x67:UInt8), (0xed:UInt8), (0xcf:UInt8), (0x8b:UInt8), (0x64:UInt8), (0xb7:UInt8), (0x20:UInt8), (0x54:UInt8), (0x1f:UInt8), (0xd4:UInt8), (0x03:UInt8), (0x0a:UInt8), (0xb7:UInt8), (0x2d:UInt8), (0x6f:UInt8), (0x72:UInt8), (0x22:UInt8), (0x56:UInt8), (0x99:UInt8), (0xdc:UInt8), (0x3c:UInt8), (0x9d:UInt8), (0x6c:UInt8), (0x7d:UInt8), (0x83:UInt8), (0xa1:UInt8), (0x44:UInt8), (0xba:UInt8)]
def p32_rnd08 : ByteArray := ByteArray.mk #[(0x59:UInt8), (0x63:UInt8), (0xdb:UInt8), (0xe6:UInt8), (0x17:UInt8), (0x68:UInt8), (0xcd:UInt8), (0xfd:UInt8), (0xfa:UInt8), (0xe6:UInt8), (0xaa:UInt8), (0x9c:UInt8), (0x52:UInt8), (0xce:UInt8), (0xbe:UInt8), (0x1d:UInt8), (0x10:UInt8), (0xef:UInt8), (0x85:UInt8), (0x2c:UInt8), (0xe2:UInt8), (0x14:UInt8), (0xac:UInt8), (0x26:UInt8), (0x0d:UInt8), (0xc0:UInt8), (0x6a:UInt8), (0x71:UInt8), (0xa0:UInt8), (0x9b:UInt8), (0x9f:UInt8), (0xad:UInt8)]
def p32_rnd09 : ByteArray := ByteArray.mk #[(0xaf:UInt8), (0xf4:UInt8), (0xcd:UInt8), (0x19:UInt8), (0xb6:UInt8), (0xf5:UInt8), (0x16:UInt8), (0x82:UInt8), (0x62:UInt8), (0xc9:UInt8), (0xc9:UInt8), (0x99:UInt8), (0x10:UInt8), (0xc2:UInt8), (0x15:UInt8), (0xa0:UInt8), (0xdb:UInt8), (0xcf:UInt8), (0x61:UInt8), (0x07:UInt8), (0xf7:UInt8), (0xa4:UInt8), (0x2e:UInt8), (0xf8:UInt8), (0x8c:UInt8), (0xa4:UInt8), (0x50:UInt8), (0xa6:UInt8), (0x10:UInt8), (0x1d:UInt8), (0x63:UInt8), (0xfd:UInt8)]

/-! ## decide lane (kernel-reducible structural cases) -/

/-- dOxO: 𝒪 + 𝒪 = 𝒪 -/
example : addP none none = none := by decide

/-- dOG: 𝒪 + P = P (left identity) -/
example : addP none (some G) = some (Gx, Gy) := by decide

/-- dGO: P + 𝒪 = P (right identity) -/
example : addP (some G) none = some (Gx, Gy) := by decide

/-- dblO: double 𝒪 = 𝒪 -/
example : doubleP none = none := by decide

/-- dblY0: doubleRaw x 0 = none (vertical-tangent branch; secp256k1 has no 2-torsion so y=0 is unreachable on-curve — def-edge) -/
example : doubleRaw 0 0 = none := by decide

/-- nO: neg 𝒪 = 𝒪 -/
example : negP none = none := by decide

/-- nG: −G = (Gx, P−Gy) — the odd-y twin of the x-only key -/
example : negP (some G) = some (Gx, P - Gy) := by decide

/-- nGneg: G + (−G) = 𝒪 -/
example : addP (some G) (negP (some G)) = none := by decide

/-- nGneg2: −G + G = 𝒪 -/
example : addP (negP (some G)) (some G) = none := by decide

/-- lxxP: lift_x(0xffffffffffff..) = none -/
example : liftX 115792089237316195423570985008687907853269984665640564039457584007908834671663 = (none) := by decide

/-- lxxPp1: lift_x(0xffffffffffff..) = none -/
example : liftX 115792089237316195423570985008687907853269984665640564039457584007908834671664 = (none) := by decide

/-! ## #eval lane (python-reference verdicts, build-checked) -/

/-- A check that contributes its label to the failure list when false. -/
def chk (s : String) (ok : Bool) : String :=
  if ok then "" else s ++ " "

/-! ### A-BIP341 (7 cases / 14 checks) -/

def secA : String :=
  let fails : String :=
    chk "bip01.tweak" (taptweak bip01p none == ByteArray.mk #[(0xb8:UInt8), (0x6e:UInt8), (0x7b:UInt8), (0xe8:UInt8), (0xf3:UInt8), (0x9b:UInt8), (0xab:UInt8), (0x32:UInt8), (0xa6:UInt8), (0xf2:UInt8), (0xc0:UInt8), (0x44:UInt8), (0x3a:UInt8), (0xbb:UInt8), (0xc2:UInt8), (0x10:UInt8), (0xf0:UInt8), (0xed:UInt8), (0xac:UInt8), (0x0e:UInt8), (0x2c:UInt8), (0x53:UInt8), (0xd5:UInt8), (0x01:UInt8), (0xb3:UInt8), (0x6b:UInt8), (0x64:UInt8), (0x43:UInt8), (0x7d:UInt8), (0x9c:UInt8), (0x6c:UInt8), (0x70:UInt8)]) ++
    chk "bip01.Q" (tweakPoint bip01p (some (97036322228596276742471839538959008486850821533798083003381037996694416561693, 50093994658426546908880986328472134188904900706363697505209876895040178906696)) none == (some (37828132795247592880523530402019234288859019741740453258219684951577010742083, 89613609348607293425405219478014065052589902034076665466173496988808705101445))) ++
    chk "bip02.tweak" (taptweak bip02p (some bip02r) == ByteArray.mk #[(0xcb:UInt8), (0xd8:UInt8), (0x67:UInt8), (0x9b:UInt8), (0xa6:UInt8), (0x36:UInt8), (0xc1:UInt8), (0x11:UInt8), (0x0e:UInt8), (0xa2:UInt8), (0x47:UInt8), (0x54:UInt8), (0x2c:UInt8), (0xfb:UInt8), (0xd9:UInt8), (0x64:UInt8), (0x13:UInt8), (0x1a:UInt8), (0x6b:UInt8), (0xe8:UInt8), (0x4f:UInt8), (0x87:UInt8), (0x3f:UInt8), (0x7f:UInt8), (0x3b:UInt8), (0x62:UInt8), (0xa7:UInt8), (0x77:UInt8), (0x52:UInt8), (0x8e:UInt8), (0xd0:UInt8), (0x01:UInt8)]) ++
    chk "bip02.Q" (tweakPoint bip02p (some (11066768852657411358033665226495933979131770118717760330312330414619225411367, 85170852694181267522666122094006687091134557873765180725484361146627860107652)) (some bip02r) == (some (9266425027663752573789736742050047055381512431074250380558703101458024185507, 44808052622542047536655262092696730110840796463858168457203307008252046266287))) ++
    chk "bip03.tweak" (taptweak bip03p (some bip03r) == ByteArray.mk #[(0x6a:UInt8), (0xf9:UInt8), (0xe2:UInt8), (0x8d:UInt8), (0xbf:UInt8), (0x9d:UInt8), (0x6a:UInt8), (0xaf:UInt8), (0x02:UInt8), (0x76:UInt8), (0x96:UInt8), (0xe2:UInt8), (0x59:UInt8), (0x8a:UInt8), (0x5b:UInt8), (0x3d:UInt8), (0x05:UInt8), (0x6f:UInt8), (0x5f:UInt8), (0xd2:UInt8), (0x35:UInt8), (0x5a:UInt8), (0x7f:UInt8), (0xd5:UInt8), (0xa3:UInt8), (0x7a:UInt8), (0x0e:UInt8), (0x50:UInt8), (0x08:UInt8), (0x13:UInt8), (0x2d:UInt8), (0x30:UInt8)]) ++
    chk "bip03.Q" (tweakPoint bip03p (some (66616418935817819299586722549639144821686680603875050840184727105942107527200, 115486213645551887037830857155535181402909539786714549716193314336277867009084)) (some bip03r) == (some (103509085700246265650407897924615444490139867152715936217721971363519835489550, 18272821375193858155928279685838941572852787288902820614593465887505506274768))) ++
    chk "bip04.tweak" (taptweak bip04p (some bip04r) == ByteArray.mk #[(0x65:UInt8), (0x79:UInt8), (0x13:UInt8), (0x8e:UInt8), (0x79:UInt8), (0x76:UInt8), (0xdc:UInt8), (0x13:UInt8), (0xb6:UInt8), (0xa9:UInt8), (0x2f:UInt8), (0x7b:UInt8), (0xfd:UInt8), (0x5a:UInt8), (0x2f:UInt8), (0xc7:UInt8), (0x68:UInt8), (0x4f:UInt8), (0x5e:UInt8), (0xa4:UInt8), (0x24:UInt8), (0x19:UInt8), (0xd4:UInt8), (0x33:UInt8), (0x68:UInt8), (0x30:UInt8), (0x14:UInt8), (0x70:UInt8), (0xf3:UInt8), (0xb7:UInt8), (0x4e:UInt8), (0xd9:UInt8)]) ++
    chk "bip04.Q" (tweakPoint bip04p (some (38753946968449939698307101704917462127608664873845608429300090440316281172269, 70403952640782425514782832637420958534815767931428545851232865827177923606594)) (some bip04r) == (some (52960573022948433164155328544524361148011369883195225619720411864444564912177, 48133479539993644482565829504442274487855746904189245144450134509487717359523))) ++
    chk "bip05.tweak" (taptweak bip05p (some bip05r) == ByteArray.mk #[(0x9e:UInt8), (0x05:UInt8), (0x17:UInt8), (0xed:UInt8), (0xc8:UInt8), (0x25:UInt8), (0x9b:UInt8), (0xb3:UInt8), (0x35:UInt8), (0x92:UInt8), (0x55:UInt8), (0x40:UInt8), (0x0b:UInt8), (0x23:UInt8), (0xca:UInt8), (0x95:UInt8), (0x07:UInt8), (0xf2:UInt8), (0xa9:UInt8), (0x1c:UInt8), (0xd1:UInt8), (0xe4:UInt8), (0x25:UInt8), (0x0b:UInt8), (0xa0:UInt8), (0x68:UInt8), (0xb4:UInt8), (0xea:UInt8), (0xfc:UInt8), (0xeb:UInt8), (0xa4:UInt8), (0xa9:UInt8)]) ++
    chk "bip05.Q" (tweakPoint bip05p (some (107791588473818498998856054743487232830286481768424497142104566701004533818770, 86185461229274620729485181717210818043847246405169345849213544648749122808556)) (some bip05r) == (some (51175449282479399006444950333066230853459067524434869837663421023973167693301, 2691363654161005387380032937045324557702655248288941144182932625462934474548))) ++
    chk "bip06.tweak" (taptweak bip06p (some bip06r) == ByteArray.mk #[(0xb5:UInt8), (0x7b:UInt8), (0xfa:UInt8), (0x18:UInt8), (0x3d:UInt8), (0x28:UInt8), (0xee:UInt8), (0xb6:UInt8), (0xad:UInt8), (0x68:UInt8), (0x8d:UInt8), (0xda:UInt8), (0xab:UInt8), (0xb2:UInt8), (0x65:UInt8), (0xb4:UInt8), (0xa4:UInt8), (0x1f:UInt8), (0xbf:UInt8), (0x68:UInt8), (0xe5:UInt8), (0xfe:UInt8), (0xd2:UInt8), (0xc7:UInt8), (0x2c:UInt8), (0x74:UInt8), (0xde:UInt8), (0x70:UInt8), (0xd5:UInt8), (0xa7:UInt8), (0x86:UInt8), (0xf4:UInt8)]) ++
    chk "bip06.Q" (tweakPoint bip06p (some (101713646068013194425030958459718561238696342020764874349999916529083423800943, 19679880292994949767559057119491106080428610604575876206685099175556207906824)) (some bip06r) == (some (65907462886345802047505570016534253556318602027546374473333985924973971650053, 107637230968305887611795712628476426690815226028902259417089603505794157639040))) ++
    chk "bip07.tweak" (taptweak bip07p (some bip07r) == ByteArray.mk #[(0x63:UInt8), (0x9f:UInt8), (0x02:UInt8), (0x81:UInt8), (0xb7:UInt8), (0xac:UInt8), (0x49:UInt8), (0xe7:UInt8), (0x42:UInt8), (0xcd:UInt8), (0x25:UInt8), (0xb7:UInt8), (0xf1:UInt8), (0x88:UInt8), (0x65:UInt8), (0x76:UInt8), (0x26:UInt8), (0xda:UInt8), (0x1a:UInt8), (0xd1:UInt8), (0x69:UInt8), (0x20:UInt8), (0x90:UInt8), (0x78:UInt8), (0xe2:UInt8), (0x76:UInt8), (0x1c:UInt8), (0xef:UInt8), (0xd9:UInt8), (0x1f:UInt8), (0xd6:UInt8), (0x5e:UInt8)]) ++
    chk "bip07.Q" (tweakPoint bip07p (some (113057013438484663709345853392560431215936572758746138878872196660884463848920, 88686044269974354859727047059989443806564661624282364798766617969020677514488)) (some bip07r) == (some (54226374577844116481187757387865931369302607373781964776318178602057305076256, 106401479959208494874094442262827930472633449532221985774670168016307853254847))) ++
    ""
  if fails == "" then "A: 14/14 OK"
  else "FAILURES: " ++ fails

/-- info: "A: 14/14 OK" -/
#guard_msgs in #eval secA

/-! ### B-taptweak-edges (8 cases / 9 checks) -/

def secB : String :=
  let fails : String :=
    chk "edgeempty32.digest" (taptweak edgeempty32p none == ByteArray.mk #[(0x8a:UInt8), (0xa4:UInt8), (0x22:UInt8), (0x94:UInt8), (0x74:UInt8), (0xab:UInt8), (0x01:UInt8), (0x00:UInt8), (0xb2:UInt8), (0xd6:UInt8), (0xf0:UInt8), (0x68:UInt8), (0x7f:UInt8), (0x03:UInt8), (0x1d:UInt8), (0x1f:UInt8), (0xc9:UInt8), (0xd8:UInt8), (0xee:UInt8), (0xf9:UInt8), (0x2a:UInt8), (0x04:UInt8), (0x2a:UInt8), (0xd9:UInt8), (0x7d:UInt8), (0x27:UInt8), (0x9b:UInt8), (0xff:UInt8), (0x45:UInt8), (0x6b:UInt8), (0x15:UInt8), (0xe4:UInt8)]) ++
    chk "edgeone.digest" (taptweak edgeonep none == ByteArray.mk #[(0x85:UInt8), (0x97:UInt8), (0x64:UInt8), (0xe8:UInt8), (0xdb:UInt8), (0x14:UInt8), (0xc2:UInt8), (0x2f:UInt8), (0x52:UInt8), (0xa5:UInt8), (0x8d:UInt8), (0xbd:UInt8), (0x0e:UInt8), (0x1e:UInt8), (0x64:UInt8), (0xbf:UInt8), (0x5c:UInt8), (0x80:UInt8), (0x00:UInt8), (0x9e:UInt8), (0x8c:UInt8), (0x69:UInt8), (0x4e:UInt8), (0x7d:UInt8), (0x2c:UInt8), (0x1e:UInt8), (0x81:UInt8), (0x34:UInt8), (0xff:UInt8), (0x51:UInt8), (0x42:UInt8), (0x42:UInt8)]) ++
    chk "edge31b.digest" (taptweak edge31bp none == ByteArray.mk #[(0xd3:UInt8), (0xc5:UInt8), (0xc1:UInt8), (0x51:UInt8), (0xdc:UInt8), (0xf7:UInt8), (0x4e:UInt8), (0x7d:UInt8), (0x5d:UInt8), (0x3e:UInt8), (0xc9:UInt8), (0x9f:UInt8), (0x35:UInt8), (0xd3:UInt8), (0xf4:UInt8), (0xd5:UInt8), (0x64:UInt8), (0xf3:UInt8), (0x60:UInt8), (0x72:UInt8), (0x12:UInt8), (0xa4:UInt8), (0x2c:UInt8), (0x01:UInt8), (0xa0:UInt8), (0x2d:UInt8), (0xef:UInt8), (0x74:UInt8), (0x9b:UInt8), (0x95:UInt8), (0x60:UInt8), (0x56:UInt8)]) ++
    chk "edge32zero.digest" (taptweak edge32zerop none == ByteArray.mk #[(0x38:UInt8), (0xac:UInt8), (0xfd:UInt8), (0x2d:UInt8), (0x72:UInt8), (0xad:UInt8), (0x71:UInt8), (0x54:UInt8), (0x15:UInt8), (0x03:UInt8), (0xbf:UInt8), (0x95:UInt8), (0x21:UInt8), (0x48:UInt8), (0x5e:UInt8), (0xd4:UInt8), (0x0e:UInt8), (0xb7:UInt8), (0x0a:UInt8), (0xd4:UInt8), (0x0d:UInt8), (0xd5:UInt8), (0x62:UInt8), (0xd2:UInt8), (0x96:UInt8), (0x77:UInt8), (0xa3:UInt8), (0x2c:UInt8), (0x91:UInt8), (0x7d:UInt8), (0x8e:UInt8), (0x61:UInt8)]) ++
    chk "edge32ff.digest" (taptweak edge32ffp none == ByteArray.mk #[(0xe1:UInt8), (0x6b:UInt8), (0x66:UInt8), (0xad:UInt8), (0x6d:UInt8), (0x14:UInt8), (0xa9:UInt8), (0xd1:UInt8), (0x0a:UInt8), (0x82:UInt8), (0xc8:UInt8), (0x87:UInt8), (0x49:UInt8), (0x61:UInt8), (0x0e:UInt8), (0xab:UInt8), (0x0a:UInt8), (0x4d:UInt8), (0x66:UInt8), (0xd7:UInt8), (0xc9:UInt8), (0x5c:UInt8), (0xab:UInt8), (0x14:UInt8), (0x43:UInt8), (0xa1:UInt8), (0x45:UInt8), (0x37:UInt8), (0xb9:UInt8), (0xd9:UInt8), (0x7f:UInt8), (0x24:UInt8)]) ++
    chk "edge33b.digest" (taptweak edge33bp none == ByteArray.mk #[(0x55:UInt8), (0xaa:UInt8), (0xd9:UInt8), (0xe8:UInt8), (0x45:UInt8), (0x60:UInt8), (0x87:UInt8), (0x96:UInt8), (0x32:UInt8), (0x74:UInt8), (0x69:UInt8), (0x7d:UInt8), (0x84:UInt8), (0xb4:UInt8), (0x19:UInt8), (0xa3:UInt8), (0x0e:UInt8), (0x70:UInt8), (0x73:UInt8), (0xce:UInt8), (0xd9:UInt8), (0x7c:UInt8), (0xeb:UInt8), (0x88:UInt8), (0xfe:UInt8), (0xca:UInt8), (0xc5:UInt8), (0xe1:UInt8), (0xb0:UInt8), (0x6e:UInt8), (0xe2:UInt8), (0x24:UInt8)]) ++
    chk "edge64b.digest" (taptweak edge64bp none == ByteArray.mk #[(0xce:UInt8), (0xd1:UInt8), (0xe3:UInt8), (0xa0:UInt8), (0x07:UInt8), (0xf2:UInt8), (0xdc:UInt8), (0x7a:UInt8), (0xb7:UInt8), (0x1f:UInt8), (0x96:UInt8), (0x3b:UInt8), (0xbf:UInt8), (0x14:UInt8), (0x2f:UInt8), (0x7e:UInt8), (0x15:UInt8), (0x18:UInt8), (0xc2:UInt8), (0xf5:UInt8), (0x38:UInt8), (0x18:UInt8), (0xd1:UInt8), (0xeb:UInt8), (0xe9:UInt8), (0x9c:UInt8), (0x1b:UInt8), (0x0d:UInt8), (0xad:UInt8), (0x9c:UInt8), (0x45:UInt8), (0x37:UInt8)]) ++
    chk "emptyroot.eqnull" (taptweak emptyrootp (some (ByteArray.mk #[])) == taptweak emptyrootp none) ++
    chk "emptyroot.value" (taptweak emptyrootp none == ByteArray.mk #[(0x6a:UInt8), (0xc0:UInt8), (0xbe:UInt8), (0x55:UInt8), (0xc1:UInt8), (0x9b:UInt8), (0x88:UInt8), (0xf3:UInt8), (0xd4:UInt8), (0xda:UInt8), (0x89:UInt8), (0x7f:UInt8), (0x8c:UInt8), (0xcc:UInt8), (0xad:UInt8), (0xc9:UInt8), (0x91:UInt8), (0xd5:UInt8), (0x71:UInt8), (0xb2:UInt8), (0xf9:UInt8), (0xfb:UInt8), (0xb3:UInt8), (0xee:UInt8), (0x9b:UInt8), (0x2e:UInt8), (0xdb:UInt8), (0x90:UInt8), (0x6b:UInt8), (0xf6:UInt8), (0xe6:UInt8), (0x80:UInt8)]) ++
    ""
  if fails == "" then "B: 9/9 OK"
  else "FAILURES: " ++ fails

/-- info: "B: 9/9 OK" -/
#guard_msgs in #eval secB

/-! ### C-tweakScalar (2 cases / 4 checks) -/

def secC : String :=
  let fails : String :=
    chk "tscbip01.BE" (tweakScalar tscbip01p (some tscbip01r) == 106096800529162258824797010989859310254659460503396360001835730278709819829352) ++
    chk "tscbip01.range" (decide (tweakScalar tscbip01p (some tscbip01r) < n)) ++
    chk "tscsc32ff.BE" (tweakScalar tscsc32ffp (some tscsc32ffr) == 40105337936378584280649100151727714544145477809185339309689827344200321237556) ++
    chk "tscsc32ff.range" (decide (tweakScalar tscsc32ffp (some tscsc32ffr) < n)) ++
    ""
  if fails == "" then "C: 4/4 OK"
  else "FAILURES: " ++ fails

/-- info: "C: 4/4 OK" -/
#guard_msgs in #eval secC

/-! ### D-addP-edges (13 cases / 13 checks) -/

def secD : String :=
  let fails : String :=
    chk "dOxO.O" (addP none none == none) ++
    chk "dOG.O" (addP none (some G) == some (Gx, Gy)) ++
    chk "dGO.O" (addP (some G) none == some (Gx, Gy)) ++
    chk "dblO.O" (doubleP none == none) ++
    chk "dGG.add" (addP (some G) (some G) == (some (89565891926547004231252920425935692360644145829622209833684329913297188986597, 12158399299693830322967808612713398636155367887041628176798871954788371653930))) ++
    chk "dG2G.add" (addP (some (89565891926547004231252920425935692360644145829622209833684329913297188986597, 12158399299693830322967808612713398636155367887041628176798871954788371653930)) (some G) == (some (112711660439710606056748659173929673102114977341539408544630613555209775888121, 25583027980570883691656905877401976406448868254816295069919888960541586679410))) ++
    chk "d2GG.add" (addP (some G) (some (89565891926547004231252920425935692360644145829622209833684329913297188986597, 12158399299693830322967808612713398636155367887041628176798871954788371653930)) == (some (112711660439710606056748659173929673102114977341539408544630613555209775888121, 25583027980570883691656905877401976406448868254816295069919888960541586679410))) ++
    chk "dVSG.eq" (addP (some G) (some G) == doubleP (some G)) ++
    chk "d2G7.add" (addP (some (112711660439710606056748659173929673102114977341539408544630613555209775888121, 25583027980570883691656905877401976406448868254816295069919888960541586679410)) (some (103388573995635080359749164254216598308788835304023601477803095234286494993683, 37057141145242123013015316630864329550140216928701153669873286428255828810018)) == (some (41948375291644419605210209193538855353224492619856392092318293986323063962044, 48361766907851246668144012348516735800090617714386977531302791340517493990618))) ++
    chk "dR12.add" (addP (some (48026088320478804476357551140571835146765313035722021998422468705772839318385, 29901797504339208355782740523808411984936492538976095530822879551054381897193)) (some (107756433554863028582257623132367726828398413499917494267400002658199687840564, 86943760500670013714009416815213238608398581922579422923294665297895562306209)) == (some (114445614799074638298413085975028341102613456177401733117860059172760925341529, 100560015766135721303844058856555900932149191915158080420842464513319051743117))) ++
    chk "dR13.add" (addP (some (48026088320478804476357551140571835146765313035722021998422468705772839318385, 29901797504339208355782740523808411984936492538976095530822879551054381897193)) (some (38198109542269728578073620848622035081966549013826612343354752321541086136875, 44467709396035657010307493002749968946497388847033914285475271425141924158516)) == (some (1562657140216044645352953071317171229371008748365309595944524685842049824338, 70159455796860565554935493049996160262955315174687367489274631394977889727552))) ++
    chk "dblY0.vt" (doubleRaw 0 0 == none) ++
    chk "offcurve.total" (addP (some (305419896, 1)) (some (305419896, 2)) == some (115792089237316195423570985008687907853269984665640564039457584007908223831871, 115792089237316195423570985008687907853269984665640564039457584007908834671662)) ++
    ""
  if fails == "" then "D: 13/13 OK"
  else "FAILURES: " ++ fails

/-- info: "D: 13/13 OK" -/
#guard_msgs in #eval secD

/-! ### E-negation (6 cases / 6 checks) -/

def secE : String :=
  let fails : String :=
    chk "nO.neg" (negP none == none) ++
    chk "nG.neg" (negP (some G) == some (Gx, P - Gy)) ++
    chk "nGneg.add" (addP (some G) (negP (some G)) == none) ++
    chk "nGneg2.add" (addP (negP (some G)) (some G) == none) ++
    chk "n2G.add" (addP (negP (some (89565891926547004231252920425935692360644145829622209833684329913297188986597, 12158399299693830322967808612713398636155367887041628176798871954788371653930))) (some (89565891926547004231252920425935692360644145829622209833684329913297188986597, 12158399299693830322967808612713398636155367887041628176798871954788371653930)) == none) ++
    chk "nDbl.dbl" (doubleP (negP (some G)) == (some (89565891926547004231252920425935692360644145829622209833684329913297188986597, 103633689937622365100603176395974509217114616778598935862658712053120463017733))) ++
    ""
  if fails == "" then "E: 6/6 OK"
  else "FAILURES: " ++ fails

/-- info: "E: 6/6 OK" -/
#guard_msgs in #eval secE

/-! ### F-liftX (5 cases / 5 checks) -/

def secF : String :=
  let fails : String :=
    chk "lxx0.lift" (liftX 0 == (none)) ++
    chk "lxxPm1.lift" (liftX 115792089237316195423570985008687907853269984665640564039457584007908834671662 == (none)) ++
    chk "lxxP.lift" (liftX 115792089237316195423570985008687907853269984665640564039457584007908834671663 == (none)) ++
    chk "lxxPp1.lift" (liftX 115792089237316195423570985008687907853269984665640564039457584007908834671664 == (none)) ++
    chk "lxxNR.lift" (liftX 5 == (none)) ++
    ""
  if fails == "" then "F: 5/5 OK"
  else "FAILURES: " ++ fails

/-- info: "F: 5/5 OK" -/
#guard_msgs in #eval secF

/-! ### G-mulP (16 cases / 16 checks) -/

def secG : String :=
  let fails : String :=
    chk "m0.mul" (mulP 0 (some G) == none) ++
    chk "m1.mul" (mulP 1 (some G) == some (Gx, Gy)) ++
    chk "m2.mul" (mulP 2 (some G) == (some (89565891926547004231252920425935692360644145829622209833684329913297188986597, 12158399299693830322967808612713398636155367887041628176798871954788371653930))) ++
    chk "m3.mul" (mulP 3 (some G) == (some (112711660439710606056748659173929673102114977341539408544630613555209775888121, 25583027980570883691656905877401976406448868254816295069919888960541586679410))) ++
    chk "m7.mul" (mulP 7 (some G) == (some (41948375291644419605210209193538855353224492619856392092318293986323063962044, 48361766907851246668144012348516735800090617714386977531302791340517493990618))) ++
    chk "mNm1.mul" (mulP (n - 1) (some G) == (some (55066263022277343669578718895168534326250603453777594175500187360389116729240, 83121579216557378445487899878180864668798711284981320763518679672151497189239))) ++
    chk "mN.mul" (mulP n (some G) == none) ++
    chk "mNp1.mul" (mulP (n + 1) (some G) == some (Gx, Gy)) ++
    chk "m256.mul" (mulP 115792089237316195423570985008687907853269984665640564039457584007913129639936 (some G) == (some (100056811408208733275829432225571761443897154861420255832015183193056831248263, 55225563209553524050574769423916742683973132338171759239001668957831436739955))) ++
    chk "m2N.mul" (mulP (2 * n) (some G) == none) ++
    chk "mR5313.mul" (mulP 63425964878609031400627877277587186671547128891715406176755671784460575468044 (some G) == (some (48026088320478804476357551140571835146765313035722021998422468705772839318385, 29901797504339208355782740523808411984936492538976095530822879551054381897193))) ++
    chk "mR8489.mul" (mulP 98288817845238844022845801969417018512599873589761569348253724758003648085506 (some G) == (some (107756433554863028582257623132367726828398413499917494267400002658199687840564, 86943760500670013714009416815213238608398581922579422923294665297895562306209))) ++
    chk "mR4733.mul" (mulP 88321757315097206023090417272552053889206249018753350378567016755608187553657 (some G) == (some (38198109542269728578073620848622035081966549013826612343354752321541086136875, 44467709396035657010307493002749968946497388847033914285475271425141924158516))) ++
    chk "mR2017.mul" (mulP 75969158120827180760986585177658806632945420707300429686528423092579358623730 (some G) == (some (79140858461755395723820324723283352445346678601700911882477136313186482583250, 1099627885898174700975055033429915897126154105527240430664663657587080857539))) ++
    chk "mR1084.mul" (mulP 41446240139205686736609780745191995960179686188980040929870065552982154133946 (some G) == (some (103277876372895577527843491650912001552589887452019359641579115878008448451245, 103467240347444064823510101277915548959628693096915205539639153341971344932859))) ++
    chk "addinf.inf" (addP (some (19159225021811614913109695861537721250918483612406791443539800450507555921893, 78346917874304954279042060697488371165356766722760724171432792132159278845710)) (mulP 12648430 (some G)) == none) ++
    ""
  if fails == "" then "G: 16/16 OK"
  else "FAILURES: " ++ fails

/-- info: "G: 16/16 OK" -/
#guard_msgs in #eval secG

/-! ### H-random (11 cases / 21 checks) -/

def secH : String :=
  let fails : String :=
    chk "rnd00.lift" (liftX 68538499697262566476800026041932435455721950012886447569722995331554967443565 == none) ++
    chk "rnd01.lift" (liftX 6990811748200721420822644252291406193161919044690465959317706841469864073306 == none) ++
    chk "rnd02.lift" (liftX 25851802960512771257716099050936703217023349790444345414031103920888492858852 == (some (25851802960512771257716099050936703217023349790444345414031103920888492858852, 99607810325068912841164253699901293070034708786418660646327448716504390956250))) ++
    chk "rnd02.range" (decide (tweakScalar p32_rnd02 (some rnd02r) < n)) ++
    chk "rnd02.Q" (tweakPoint p32_rnd02 (liftX 25851802960512771257716099050936703217023349790444345414031103920888492858852) (some rnd02r) == (some (11087660425255369678334861299178749130997486411092031501740583483009392308702, 54048630235595662574714883352996080305756235481146038346968654199544067206793))) ++
    chk "rnd03.lift" (liftX 15925304034522881762171535843911807568406287274111072716976264518833875978879 == none) ++
    chk "rnd04.lift" (liftX 10843687286349031175908443904140303814442341153408965995323439672236739619149 == (some (10843687286349031175908443904140303814442341153408965995323439672236739619149, 55248416224705517851667279102541580656316780547532063702308943773627977134420))) ++
    chk "rnd04.range" (decide (tweakScalar p32_rnd04 none < n)) ++
    chk "rnd04.Q" (tweakPoint p32_rnd04 (liftX 10843687286349031175908443904140303814442341153408965995323439672236739619149) none == (some (32843597585791726225740377850180814784915407733914517378729332465946018097745, 13974868600897361985938997564801052033329038983099522363720421513992285209862))) ++
    chk "rnd05.lift" (liftX 8990392955444819489847418714455927778308431128359609068103465659267850777039 == none) ++
    chk "rnd06.lift" (liftX 35363816985994813683642743977545052322752589549951935306310401040859108009655 == none) ++
    chk "rnd07.lift" (liftX 70097738706595881087988717513126367719932639905389817475842147363808571489286 == (some (70097738706595881087988717513126367719932639905389817475842147363808571489286, 33506590737012186341761422970419747438620724018187823560009219202236529438640))) ++
    chk "rnd07.range" (decide (tweakScalar p32_rnd07 none < n)) ++
    chk "rnd07.Q" (tweakPoint p32_rnd07 (liftX 70097738706595881087988717513126367719932639905389817475842147363808571489286) none == (some (100161493400897812110151857611179510031872623137452877124789547575527039050286, 73640293953157784059382937355059119934219071562621902773070006083291171108211))) ++
    chk "rnd08.lift" (liftX 40432279069026746035396252111314138677155644751712031887956228384236012019629 == (some (40432279069026746035396252111314138677155644751712031887956228384236012019629, 65562157240271314909425669220207088047874049023869316640801422636051845217746))) ++
    chk "rnd08.range" (decide (tweakScalar p32_rnd08 (some rnd08r) < n)) ++
    chk "rnd08.Q" (tweakPoint p32_rnd08 (liftX 40432279069026746035396252111314138677155644751712031887956228384236012019629) (some rnd08r) == (some (7654888899642629335764299968981001545616490129485110767490154916681159526194, 72478201750226031117008861154576270456622370458388021159254598863382535159777))) ++
    chk "rnd09.lift" (liftX 79587274737144962894988283172292314265574794691391172797516054214879571960829 == (some (79587274737144962894988283172292314265574794691391172797516054214879571960829, 41372210708117750518571777389932934136780150328027889610404918290794138368946))) ++
    chk "rnd09.range" (decide (tweakScalar p32_rnd09 none < n)) ++
    chk "rnd09.Q" (tweakPoint p32_rnd09 (liftX 79587274737144962894988283172292314265574794691391172797516054214879571960829) none == (some (86348181790359194305993037679475906871288230261644092918609969137924595449269, 66748815384909461958146196477627417036846732749384316404238806190283415885910))) ++
    chk "negtwin.twin" (tweakPoint p32_rnd02 (negP (liftX 25851802960512771257716099050936703217023349790444345414031103920888492858852)) none == (some (100608837629175817182972725972295199886208515900123747791520915814043681091433, 75510711931478845058224361822633182764162570692274052017476188746846357044867))) ++
    ""
  if fails == "" then "H: 21/21 OK"
  else "FAILURES: " ++ fails

/-- info: "H: 21/21 OK" -/
#guard_msgs in #eval secH

/-! ## Named instances + axiom footprint pins -/

theorem y16_mulP0 : mulP 0 (some G) = none := by simp [mulP]

theorem y16_OG : addP none (some G) = some (Gx, Gy) := by decide

/-- info: 'BitcoinProofs.Property.Y16.TapTweakProps.y16_mulP0' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms y16_mulP0

/-- info: 'BitcoinProofs.Property.Y16.TapTweakProps.y16_OG' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms y16_OG

end BitcoinProofs.Property.Y16.TapTweakProps
