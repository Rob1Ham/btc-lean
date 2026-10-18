import Bitcoin.Crypto.Taproot.Verify
import Bitcoin.Crypto.Taproot.OutputKey
import Bitcoin.Crypto.Taproot.Tree
import Bitcoin.Crypto.Taproot.TapTweak
import Bitcoin.Crypto.Curve.Secp
import Bitcoin.Crypto.Schnorr.TaggedHash
import Bitcoin.Data.Basic

/-!
# Z29 dark-corner audit — taproot odd-y lift before tweak + the TapBranch tag
#

2026-10-16. Python3 probes:
`gen.py` + printed probes,
all validated against the OFFICIAL BIP341 wallet vectors
`spec/vectors/bips/bip-0341_wallet-test-vectors.json`).

Ground truth: Core @ `cce32b168`:
* C1: `secp256k1_xonly_pubkey_load` → the tweak ALWAYS runs on the EVEN-y
  lift (`secp256k1_ge_set_xo_var(…, 0)`); `secp256k1_extrakeys_ge_even_y`
  (extrakeys_main_impl.h:95-104) NEGATES an odd-y representative before
  the tweak — `secp256k1_xonly_pubkey_tweak_add_check`
  (extrakeys_main_impl.h:142-161) via `pubkey.cpp:CheckTapTweak:257-263`.
* C2: `ComputeTapbranchHash` (interpreter.cpp:1887-1896): the tag
  `"TapBranch"` + strict-lexicographic sorted pairing;
  `ComputeTaprootMerkleRoot` (interpreter.cpp:1898-1911).

TWO assertion lanes (Y16 discipline; kernel whnf stops at the WF-recursive
sha256/expM/mulP, so computed cases use the `#eval` lane):
* `decide` lane — cheap structural/byte pins;
* `#eval` + `#guard_msgs` lane — every EXPECTED value below comes from the
  python probe (which matched the official vectors), the `#eval` recomputes
  it through the Lean defs, and `#guard_msgs` FAILS THE BUILD on any
  divergence. Axiom-free, no `native_decide`.

## C1 — odd-y P negated before the tweak (even-y lift) — CAPTURED

Entry points into `tweakPoint` (TPR-016/017) in the consensus lanes:
* script-path: `OutputKey.tweakedKey` = `liftX (bytesToNatBE control[1..33])`
  bind `tweakPoint` (OutputKey.lean:150-153) — `liftX` IS the even-y lift
  (`liftPick`: odd sqrt candidate `r` → `negN r` = `P - r`, Curve/Secp.lean:357;
  theorems `liftX_even`/`liftX_snd`/`liftX_onCurve`);
* construction: `Verify.p2trOutput` = `liftX (bytesToNatBE pk)` bind
  `tweakPoint` (Verify.lean:134-141).

So the point entering the tweak ALWAYS has even y — exactly Core's
x-only load semantics; the "negation of odd-y P" is `liftPick`'s else
branch. Decisive official evidence (vector 0, key-path): internal key
`d6889cb0…961d` has raw sqrt candidate `913fcdc5…95e7` (ODD — the
negation fires); only the even lift `6ec0323a…6648` tweakes to the
official output key `53a1f6e4…da343`; the naive odd-y point yields
`aecb3565…4e9ff` — a different P2TR program (consensus-visible).
Vector 4's internal key exercises the OTHER branch (raw candidate even,
passthrough). Both branches pinned below through the real defs.

## C2 — the TapBranch tag (the one tag without an X02 home) — CAPTURED

`tagTapBranch` lives in X03's `Crypto/Taproot/TapTweak.lean:93` (X02's
`Schnorr/TaggedHash.lean` carries only
TapTweak/TapLeaf/TapSighash/BIP0340 tags — verified by reading; X03's
finding resolved in-place, TaggedHash.lean untouched). The pairing is
`Tree.tapBranch` (TPR-013): strict-lex sort (`lexLtB`, pinned irrefl/asym/
both-false↔equal) then `taggedHash "TapBranch" (min‖max)`; the walk is
`taprootMerkleRoot` (TPR-014). Decisive official evidence (vector 4,
two-leaf tree, sort REORDERS: l1 = 2cb2… < l0 = 6451…): the official
merkle root `ab179431…90cc` equals `tapBranch l0 l1` (= `tapBranch l1 l0`,
the commutativity theorem) and DIFFERS from the naive unsorted
`hash(l0‖l1)` = `c2c63ccc…0285`; plus the `k_j = e_j` diag case
(strict irreflexivity → else-branch `a‖a`) and the full end-to-end
script-path SPEND verdict through `scriptPathSpend`.
-/


namespace Bitcoin.Proofs.Audit.Z29

open Bitcoin.Crypto.Curve.Secp (liftX bytesToNatBE liftX_even)
open Bitcoin.Crypto.Schnorr (taggedHash tagTapTweak)
open Bitcoin.Crypto.Taproot (taptweak tweakPoint tagTapBranch
  tapLeaf tapBranch taprootMerkleRoot tapBranch_comm tapBranch_diag)
open Bitcoin.Crypto.Taproot.Verify
open Bitcoin.Crypto.Taproot.OutputKey (internalKeyBytes tweakedKey)

set_option maxRecDepth 10000
set_option maxHeartbeats 2000000

-- hex helpers (Z01/Y08 pattern)
private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else none

private def fromHex (s : String) : ByteArray :=
  go (s.toList.filter (fun c => c != '\n' && c != ' ')) ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some ha, some hb => go rest (acc.push ((ha * 16 + hb).toUInt8))
        | _, _ => go rest acc

/-! ## C1 literals — BIP341 wallet vector 0 (key path; negation FIRES)
     + vector 4 internal key (even passthrough) -/

/-- bip341 vector 0 internal key (x-only). -/
def pk0 : ByteArray := ByteArray.mk #[(0xd6:UInt8), (0x88:UInt8), (0x9c:UInt8), (0xb0:UInt8), (0x81:UInt8), (0x03:UInt8), (0x6e:UInt8), (0x0f:UInt8), (0xae:UInt8), (0xfa:UInt8), (0x3a:UInt8), (0x35:UInt8), (0x15:UInt8), (0x7a:UInt8), (0xd7:UInt8), (0x10:UInt8), (0x86:UInt8), (0xb1:UInt8), (0x23:UInt8), (0xb2:UInt8), (0xb1:UInt8), (0x44:UInt8), (0xb6:UInt8), (0x49:UInt8), (0x79:UInt8), (0x8b:UInt8), (0x49:UInt8), (0x4c:UInt8), (0x30:UInt8), (0x0a:UInt8), (0x96:UInt8), (0x1d:UInt8)]
/-- official tweak digest of vector 0 (taptweak pk0 none). -/
def tdig0 : ByteArray := ByteArray.mk #[(0xb8:UInt8), (0x6e:UInt8), (0x7b:UInt8), (0xe8:UInt8), (0xf3:UInt8), (0x9b:UInt8), (0xab:UInt8), (0x32:UInt8), (0xa6:UInt8), (0xf2:UInt8), (0xc0:UInt8), (0x44:UInt8), (0x3a:UInt8), (0xbb:UInt8), (0xc2:UInt8), (0x10:UInt8), (0xf0:UInt8), (0xed:UInt8), (0xac:UInt8), (0x0e:UInt8), (0x2c:UInt8), (0x53:UInt8), (0xd5:UInt8), (0x01:UInt8), (0xb3:UInt8), (0x6b:UInt8), (0x64:UInt8), (0x43:UInt8), (0x7d:UInt8), (0x9c:UInt8), (0x6c:UInt8), (0x70:UInt8)]
/-- raw sqrt candidate of pk0 — ODD (parity 1): the branch where Core's `secp256k1_extrakeys_ge_even_y` negates before the tweak. -/
def rOdd0 : ByteArray := ByteArray.mk #[(0x91:UInt8), (0x3f:UInt8), (0xcd:UInt8), (0xc5:UInt8), (0x01:UInt8), (0x2e:UInt8), (0x65:UInt8), (0x5f:UInt8), (0x61:UInt8), (0xc0:UInt8), (0xc8:UInt8), (0x47:UInt8), (0xd8:UInt8), (0xe2:UInt8), (0x99:UInt8), (0x20:UInt8), (0xb0:UInt8), (0xa0:UInt8), (0xc4:UInt8), (0x98:UInt8), (0x53:UInt8), (0xa8:UInt8), (0x00:UInt8), (0x49:UInt8), (0x1f:UInt8), (0x68:UInt8), (0x29:UInt8), (0x95:UInt8), (0xbd:UInt8), (0x91:UInt8), (0x95:UInt8), (0xe7:UInt8)]
/-- the even-y lift `P - r` — the point Core actually tweaks (liftPick else-branch). -/
def yEven0 : ByteArray := ByteArray.mk #[(0x6e:UInt8), (0xc0:UInt8), (0x32:UInt8), (0x3a:UInt8), (0xfe:UInt8), (0xd1:UInt8), (0x9a:UInt8), (0xa0:UInt8), (0x9e:UInt8), (0x3f:UInt8), (0x37:UInt8), (0xb8:UInt8), (0x27:UInt8), (0x1d:UInt8), (0x66:UInt8), (0xdf:UInt8), (0x4f:UInt8), (0x5f:UInt8), (0x3b:UInt8), (0x67:UInt8), (0xac:UInt8), (0x57:UInt8), (0xff:UInt8), (0xb6:UInt8), (0xe0:UInt8), (0x97:UInt8), (0xd6:UInt8), (0x69:UInt8), (0x42:UInt8), (0x6e:UInt8), (0x66:UInt8), (0x48:UInt8)]
/-- official tweakedPubkey of vector 0 (x(Q), even-lift). -/
def xQ0 : ByteArray := ByteArray.mk #[(0x53:UInt8), (0xa1:UInt8), (0xf6:UInt8), (0xe4:UInt8), (0x54:UInt8), (0xdf:UInt8), (0x1a:UInt8), (0xa2:UInt8), (0x77:UInt8), (0x6a:UInt8), (0x28:UInt8), (0x14:UInt8), (0xa7:UInt8), (0x21:UInt8), (0x37:UInt8), (0x2d:UInt8), (0x62:UInt8), (0x58:UInt8), (0x05:UInt8), (0x0d:UInt8), (0xe3:UInt8), (0x30:UInt8), (0xb3:UInt8), (0xc6:UInt8), (0xd1:UInt8), (0x0e:UInt8), (0xe8:UInt8), (0xf4:UInt8), (0xe0:UInt8), (0xdd:UInt8), (0xa3:UInt8), (0x43:UInt8)]
/-- y(Q) of vector 0 (parity 1 — python probe). -/
def yQ0 : ByteArray := ByteArray.mk #[(0xc6:UInt8), (0x1f:UInt8), (0x81:UInt8), (0x65:UInt8), (0xcf:UInt8), (0xc1:UInt8), (0x12:UInt8), (0x38:UInt8), (0x42:UInt8), (0xf9:UInt8), (0x1c:UInt8), (0xc1:UInt8), (0x3e:UInt8), (0x17:UInt8), (0x39:UInt8), (0xc3:UInt8), (0x5c:UInt8), (0x43:UInt8), (0x82:UInt8), (0x0c:UInt8), (0xfb:UInt8), (0xfd:UInt8), (0xd7:UInt8), (0xe7:UInt8), (0xd1:UInt8), (0xa6:UInt8), (0x65:UInt8), (0xcc:UInt8), (0x2f:UInt8), (0x0a:UInt8), (0x4e:UInt8), (0x85:UInt8)]
/-- x(Q') for the NAIVE odd-y tweak (no negation) — a different output key: consensus-visible divergence. -/
def xQ0n : ByteArray := ByteArray.mk #[(0xae:UInt8), (0xcb:UInt8), (0x35:UInt8), (0x65:UInt8), (0x10:UInt8), (0xc2:UInt8), (0x46:UInt8), (0x87:UInt8), (0xa9:UInt8), (0x4d:UInt8), (0x2e:UInt8), (0x52:UInt8), (0x4e:UInt8), (0xfa:UInt8), (0x4c:UInt8), (0x7e:UInt8), (0x55:UInt8), (0x4a:UInt8), (0x3f:UInt8), (0x57:UInt8), (0x9d:UInt8), (0x88:UInt8), (0x23:UInt8), (0xc4:UInt8), (0x0d:UInt8), (0x8b:UInt8), (0x07:UInt8), (0x2e:UInt8), (0x2d:UInt8), (0xf4:UInt8), (0xe9:UInt8), (0xff:UInt8)]
/-- y(Q') of the naive odd-y tweak. -/
def yQ0n : ByteArray := ByteArray.mk #[(0xb6:UInt8), (0x86:UInt8), (0x31:UInt8), (0x20:UInt8), (0x0b:UInt8), (0x8a:UInt8), (0x95:UInt8), (0xaf:UInt8), (0x2c:UInt8), (0x2e:UInt8), (0xea:UInt8), (0x6f:UInt8), (0xe4:UInt8), (0xa7:UInt8), (0xa5:UInt8), (0x36:UInt8), (0xab:UInt8), (0x27:UInt8), (0x93:UInt8), (0xfc:UInt8), (0x1e:UInt8), (0x71:UInt8), (0xb9:UInt8), (0x18:UInt8), (0xc0:UInt8), (0x71:UInt8), (0x0a:UInt8), (0x2d:UInt8), (0xbd:UInt8), (0x35:UInt8), (0x9f:UInt8), (0x22:UInt8)]
/-- vector 4's internal key (control[1..33]) — raw sqrt candidate EVEN (passthrough branch). -/
def pk4int : ByteArray := ByteArray.mk #[(0xf9:UInt8), (0xf4:UInt8), (0x00:UInt8), (0x80:UInt8), (0x3e:UInt8), (0x68:UInt8), (0x37:UInt8), (0x27:UInt8), (0xb1:UInt8), (0x4f:UInt8), (0x46:UInt8), (0x38:UInt8), (0x36:UInt8), (0xe1:UInt8), (0xe7:UInt8), (0x8e:UInt8), (0x1c:UInt8), (0x64:UInt8), (0x41:UInt8), (0x76:UInt8), (0x38:UInt8), (0xaa:UInt8), (0x06:UInt8), (0x69:UInt8), (0x19:UInt8), (0x29:UInt8), (0x1a:UInt8), (0x22:UInt8), (0x5f:UInt8), (0x0e:UInt8), (0x8d:UInt8), (0xd8:UInt8)]
/-- the even sqrt candidate of pk4int — used AS-IS (no negation). -/
def rEven4 : ByteArray := ByteArray.mk #[(0xc4:UInt8), (0x12:UInt8), (0x85:UInt8), (0xb0:UInt8), (0xdc:UInt8), (0xfe:UInt8), (0x7d:UInt8), (0x6c:UInt8), (0xdf:UInt8), (0x27:UInt8), (0x07:UInt8), (0x02:UInt8), (0xf2:UInt8), (0xc6:UInt8), (0x0c:UInt8), (0x18:UInt8), (0xde:UInt8), (0x53:UInt8), (0x45:UInt8), (0xca:UInt8), (0xeb:UInt8), (0x69:UInt8), (0x07:UInt8), (0x7c:UInt8), (0x1d:UInt8), (0x6b:UInt8), (0xe6:UInt8), (0xee:UInt8), (0x27:UInt8), (0xa5:UInt8), (0xe4:UInt8), (0xf8:UInt8)]
/-- official tweak digest of vector 4 (taptweak pk4int (some root4)). -/
def tdig4 : ByteArray := ByteArray.mk #[(0x63:UInt8), (0x9f:UInt8), (0x02:UInt8), (0x81:UInt8), (0xb7:UInt8), (0xac:UInt8), (0x49:UInt8), (0xe7:UInt8), (0x42:UInt8), (0xcd:UInt8), (0x25:UInt8), (0xb7:UInt8), (0xf1:UInt8), (0x88:UInt8), (0x65:UInt8), (0x76:UInt8), (0x26:UInt8), (0xda:UInt8), (0x1a:UInt8), (0xd1:UInt8), (0x69:UInt8), (0x20:UInt8), (0x90:UInt8), (0x78:UInt8), (0xe2:UInt8), (0x76:UInt8), (0x1c:UInt8), (0xef:UInt8), (0xd9:UInt8), (0x1f:UInt8), (0xd6:UInt8), (0x5e:UInt8)]
/-- official tweakedPubkey of vector 4. -/
def xQ4 : ByteArray := ByteArray.mk #[(0x77:UInt8), (0xe3:UInt8), (0x0a:UInt8), (0x55:UInt8), (0x22:UInt8), (0xdd:UInt8), (0x9f:UInt8), (0x89:UInt8), (0x4c:UInt8), (0x3f:UInt8), (0x8b:UInt8), (0x8b:UInt8), (0xd4:UInt8), (0xc4:UInt8), (0xb2:UInt8), (0xcf:UInt8), (0x82:UInt8), (0xca:UInt8), (0x7d:UInt8), (0xa8:UInt8), (0xa3:UInt8), (0xea:UInt8), (0x6a:UInt8), (0x23:UInt8), (0x96:UInt8), (0x55:UInt8), (0xc3:UInt8), (0x9c:UInt8), (0x05:UInt8), (0x0a:UInt8), (0xb2:UInt8), (0x20:UInt8)]
/-- y(Q) of vector 4 (parity 1 = control[0]&1 = 1; python probe). -/
def yQ4 : ByteArray := ByteArray.mk #[(0xeb:UInt8), (0x3d:UInt8), (0x1a:UInt8), (0x7f:UInt8), (0x11:UInt8), (0xc4:UInt8), (0x8f:UInt8), (0x40:UInt8), (0x9f:UInt8), (0xdd:UInt8), (0xb7:UInt8), (0x69:UInt8), (0xfa:UInt8), (0x9b:UInt8), (0xa8:UInt8), (0x80:UInt8), (0x76:UInt8), (0xcb:UInt8), (0xe3:UInt8), (0x4a:UInt8), (0x7b:UInt8), (0x38:UInt8), (0x8d:UInt8), (0x69:UInt8), (0x95:UInt8), (0xd9:UInt8), (0xb5:UInt8), (0x2c:UInt8), (0x0a:UInt8), (0x88:UInt8), (0xe0:UInt8), (0xbf:UInt8)]

/-- vector 0's internal key as a Nat (big-endian, `bytesToNatBE`). -/
def x0N : Nat := 97036322228596276742471839538959008486850821533798083003381037996694416561693
/-- raw ODD sqrt candidate of pk0 as a Nat. -/
def rOdd0N : Nat := 65698094578889648514689998680215773664365083959276866534247707112868655764967
/-- the even-y lift of pk0 as a Nat (`P - r`). -/
def yEven0N : Nat := 50093994658426546908880986328472134188904900706363697505209876895040178906696
/-- official x(Q) of vector 0. -/
def xQ0N : Nat := 37828132795247592880523530402019234288859019741740453258219684951577010742083
/-- y(Q) of vector 0. -/
def yQ0N : Nat := 89613609348607293425405219478014065052589902034076665466173496988808705101445
/-- naive odd-y x(Q'). -/
def xQ0nN : Nat := 79061474124914273852909252864134073965460089355244122431635923568393687722495
/-- naive odd-y y(Q'). -/
def yQ0nN : Nat := 82558034998339517919481696195222707207580488085706689827250282254980179402530
/-- pk4int as a Nat. -/
def x4N : Nat := 113057013438484663709345853392560431215936572758746138878872196660884463848920
/-- the EVEN sqrt candidate of pk4int as a Nat (passthrough). -/
def rEven4N : Nat := 88686044269974354859727047059989443806564661624282364798766617969020677514488
/-- official x(Q) of vector 4. -/
def xQ4N : Nat := 54226374577844116481187757387865931369302607373781964776318178602057305076256
/-- y(Q) of vector 4. -/
def yQ4N : Nat := 106401479959208494874094442262827930472633449532221985774670168016307853254847

/-! ## C2 literals — BIP341 wallet vector 4 (two 0xc0 leaves; sort REORDERS) -/

/-- vector 4 leaf 0 script (33-byte push, leaf version 0xc0). -/
def s0 : ByteArray := ByteArray.mk #[(0x20:UInt8), (0x44:UInt8), (0xb1:UInt8), (0x78:UInt8), (0xd6:UInt8), (0x4c:UInt8), (0x32:UInt8), (0xc4:UInt8), (0xa0:UInt8), (0x5c:UInt8), (0xc4:UInt8), (0xf4:UInt8), (0xd1:UInt8), (0x40:UInt8), (0x72:UInt8), (0x68:UInt8), (0xf7:UInt8), (0x64:UInt8), (0xc9:UInt8), (0x40:UInt8), (0xd2:UInt8), (0x0c:UInt8), (0xe9:UInt8), (0x7a:UInt8), (0xbf:UInt8), (0xd4:UInt8), (0x4d:UInt8), (0xb5:UInt8), (0xc3:UInt8), (0x59:UInt8), (0x2b:UInt8), (0x72:UInt8), (0xfd:UInt8), (0xac:UInt8)]
/-- vector 4 leaf 1 script (07 + 'Taproot', leaf version 0xc0). -/
def s1 : ByteArray := ByteArray.mk #[(0x07:UInt8), (0x54:UInt8), (0x61:UInt8), (0x70:UInt8), (0x72:UInt8), (0x6f:UInt8), (0x6f:UInt8), (0x74:UInt8)]
/-- official leafHash 0 = tapLeaf 0xc0 s0. -/
def l0 : ByteArray := ByteArray.mk #[(0x64:UInt8), (0x51:UInt8), (0x2f:UInt8), (0xec:UInt8), (0xdb:UInt8), (0x5a:UInt8), (0xfa:UInt8), (0x04:UInt8), (0xf9:UInt8), (0x88:UInt8), (0x39:UInt8), (0xb5:UInt8), (0x0e:UInt8), (0x6f:UInt8), (0x0c:UInt8), (0xb7:UInt8), (0xb1:UInt8), (0xe5:UInt8), (0x39:UInt8), (0xbf:UInt8), (0x6f:UInt8), (0x20:UInt8), (0x5f:UInt8), (0x67:UInt8), (0x93:UInt8), (0x40:UInt8), (0x83:UInt8), (0xcd:UInt8), (0xcc:UInt8), (0x3c:UInt8), (0x8d:UInt8), (0x89:UInt8)]
/-- official leafHash 1 = tapLeaf 0xc0 s1. -/
def l1 : ByteArray := ByteArray.mk #[(0x2c:UInt8), (0xb2:UInt8), (0xb9:UInt8), (0x0d:UInt8), (0xaa:UInt8), (0x54:UInt8), (0x3b:UInt8), (0x54:UInt8), (0x41:UInt8), (0x61:UInt8), (0x53:UInt8), (0x0c:UInt8), (0x92:UInt8), (0x5f:UInt8), (0x28:UInt8), (0x5b:UInt8), (0x06:UInt8), (0x19:UInt8), (0x69:UInt8), (0x40:UInt8), (0xd6:UInt8), (0x08:UInt8), (0x5c:UInt8), (0xa9:UInt8), (0x47:UInt8), (0x4d:UInt8), (0x41:UInt8), (0xdc:UInt8), (0x38:UInt8), (0x22:UInt8), (0xc5:UInt8), (0xcb:UInt8)]
/-- official merkle root = tag_TapBranch(min‖max) — the SORTED pair. -/
def root4 : ByteArray := ByteArray.mk #[(0xab:UInt8), (0x17:UInt8), (0x94:UInt8), (0x31:UInt8), (0xc2:UInt8), (0x8d:UInt8), (0x3b:UInt8), (0x68:UInt8), (0xfb:UInt8), (0x79:UInt8), (0x89:UInt8), (0x57:UInt8), (0xfa:UInt8), (0xf5:UInt8), (0x49:UInt8), (0x7d:UInt8), (0x69:UInt8), (0xc8:UInt8), (0x83:UInt8), (0xc6:UInt8), (0xfb:UInt8), (0x1e:UInt8), (0x1c:UInt8), (0xd9:UInt8), (0xf8:UInt8), (0x14:UInt8), (0x83:UInt8), (0xd8:UInt8), (0x7b:UInt8), (0xac:UInt8), (0x90:UInt8), (0xcc:UInt8)]
/-- the NAIVE unsorted hash(l0‖l1) — NOT the official root: the sort is consensus-visible. -/
def unsrt4 : ByteArray := ByteArray.mk #[(0xc2:UInt8), (0xc6:UInt8), (0x3c:UInt8), (0xcc:UInt8), (0x76:UInt8), (0x7b:UInt8), (0xcc:UInt8), (0x3b:UInt8), (0x5f:UInt8), (0xb7:UInt8), (0xd3:UInt8), (0xcc:UInt8), (0x13:UInt8), (0x91:UInt8), (0xf5:UInt8), (0xac:UInt8), (0x8c:UInt8), (0xe4:UInt8), (0x39:UInt8), (0xd5:UInt8), (0x0d:UInt8), (0x03:UInt8), (0xef:UInt8), (0xe3:UInt8), (0x5d:UInt8), (0xbc:UInt8), (0x15:UInt8), (0x0f:UInt8), (0xc1:UInt8), (0x1f:UInt8), (0x02:UInt8), (0x85:UInt8)]
/-- tag_TapBranch(l0‖l0) — the k_j = e_j diag case (strict-lex else-branch). -/
def diag4 : ByteArray := ByteArray.mk #[(0x42:UInt8), (0xa4:UInt8), (0xc5:UInt8), (0x97:UInt8), (0xcf:UInt8), (0x67:UInt8), (0x34:UInt8), (0xed:UInt8), (0xcf:UInt8), (0xd7:UInt8), (0x86:UInt8), (0x32:UInt8), (0x08:UInt8), (0xdc:UInt8), (0xe0:UInt8), (0xda:UInt8), (0xf4:UInt8), (0xf1:UInt8), (0xbf:UInt8), (0xd9:UInt8), (0x05:UInt8), (0x46:UInt8), (0x4c:UInt8), (0x4b:UInt8), (0xd9:UInt8), (0x18:UInt8), (0x5d:UInt8), (0x83:UInt8), (0x89:UInt8), (0x04:UInt8), (0xa1:UInt8), (0xd3:UInt8)]
/-- vector 4's control block for leaf 0: 0xc1 ‖ internal key ‖ path node l1 (65 bytes). -/
def control4 : ByteArray := ByteArray.mk #[(0xc1:UInt8), (0xf9:UInt8), (0xf4:UInt8), (0x00:UInt8), (0x80:UInt8), (0x3e:UInt8), (0x68:UInt8), (0x37:UInt8), (0x27:UInt8), (0xb1:UInt8), (0x4f:UInt8), (0x46:UInt8), (0x38:UInt8), (0x36:UInt8), (0xe1:UInt8), (0xe7:UInt8), (0x8e:UInt8), (0x1c:UInt8), (0x64:UInt8), (0x41:UInt8), (0x76:UInt8), (0x38:UInt8), (0xaa:UInt8), (0x06:UInt8), (0x69:UInt8), (0x19:UInt8), (0x29:UInt8), (0x1a:UInt8), (0x22:UInt8), (0x5f:UInt8), (0x0e:UInt8), (0x8d:UInt8), (0xd8:UInt8), (0x2c:UInt8), (0xb2:UInt8), (0xb9:UInt8), (0x0d:UInt8), (0xaa:UInt8), (0x54:UInt8), (0x3b:UInt8), (0x54:UInt8), (0x41:UInt8), (0x61:UInt8), (0x53:UInt8), (0x0c:UInt8), (0x92:UInt8), (0x5f:UInt8), (0x28:UInt8), (0x5b:UInt8), (0x06:UInt8), (0x19:UInt8), (0x69:UInt8), (0x40:UInt8), (0xd6:UInt8), (0x08:UInt8), (0x5c:UInt8), (0xa9:UInt8), (0x47:UInt8), (0x4d:UInt8), (0x41:UInt8), (0xdc:UInt8), (0x38:UInt8), (0x22:UInt8), (0xc5:UInt8), (0xcb:UInt8)]
/-- vector 4's scriptPubKey: 0x51 0x20 ‖ tweakedPubkey. -/
def program4 : ByteArray := ByteArray.mk #[(0x51:UInt8), (0x20:UInt8), (0x77:UInt8), (0xe3:UInt8), (0x0a:UInt8), (0x55:UInt8), (0x22:UInt8), (0xdd:UInt8), (0x9f:UInt8), (0x89:UInt8), (0x4c:UInt8), (0x3f:UInt8), (0x8b:UInt8), (0x8b:UInt8), (0xd4:UInt8), (0xc4:UInt8), (0xb2:UInt8), (0xcf:UInt8), (0x82:UInt8), (0xca:UInt8), (0x7d:UInt8), (0xa8:UInt8), (0xa3:UInt8), (0xea:UInt8), (0x6a:UInt8), (0x23:UInt8), (0x96:UInt8), (0x55:UInt8), (0xc3:UInt8), (0x9c:UInt8), (0x05:UInt8), (0x0a:UInt8), (0xb2:UInt8), (0x20:UInt8)]

/-! ## Abstract pins (sorry-free, reusing X02/X03 theorems) -/

/-- The internal-key point entering `tweakPoint` in the script-path
consensus lane (`OutputKey.tweakedKey`) ALWAYS has even y — the even-y
lift (`liftX_even`); the odd-y representative never reaches the tweak. -/
theorem audit_tweakedKey_enters_even (control : ByteArray)
    (_root : Option ByteArray) (xI yI : Nat)
    (h : liftX (bytesToNatBE (internalKeyBytes control)) = some (xI, yI)) :
    yI % 2 = 0 := liftX_even h

/-- The internal-key point entering `tweakPoint` in the construction
lane (`Verify.p2trOutput`) ALWAYS has even y, likewise. -/
theorem audit_p2trOutput_enters_even (pk : ByteArray) (_tree : Option TapTree)
    (xI yI : Nat)
    (h : liftX (bytesToNatBE pk) = some (xI, yI)) :
    yI % 2 = 0 := liftX_even h

/-- The tweak input is x-only: `tweakPoint` sees exactly the `liftX`
result, so the verdict is a function of `x` (plus tag/domain bytes) —
no y-parity of any full-key encoding enters (Core: `xonly_pubkey_load`
even-y; `extrakeys_ge_even_y` negation is INSIDE the lift). -/
theorem audit_tweakPoint_sees_lift (p : ByteArray) (root : Option ByteArray)
    (x y : Nat) (h : liftX x = some (x, y)) :
    tweakPoint p (liftX x) root = tweakPoint p (some (x, y)) root := by rw [h]

/-- Tag-pin: `tagTapBranch` is the 9 ASCII bytes `TapBranch`
(54 61 70 42 72 61 6e 63 68) — the tag X02's `Schnorr/TaggedHash.lean`
does NOT carry (it lives in X03's TapTweak.lean:93). -/
example : (tagTapBranch == fromHex "5461704272616e6368") = true := by decide

/-- Tag-pin: `tagTapTweak` = `TapTweak` (the X02 home tag it lives beside). -/
example : (tagTapTweak == fromHex "546170547765616b") = true := by decide

/-- Sorted-pair commutativity (X03's `tapBranch_comm`, re-exercised). -/
example (a b : ByteArray) : tapBranch a b = tapBranch b a := tapBranch_comm a b

/-- Diag case (X03's `tapBranch_diag`: strict irreflexivity → else-branch). -/
example (a : ByteArray) : tapBranch a a = taggedHash tagTapBranch (a ++ a) :=
  tapBranch_diag a

/-! ## #eval lane (python-reference verdicts, build-checked) -/

/-- A check that contributes its label to the failure list when false. -/
def chk (s : String) (ok : Bool) : String :=
  if ok then "" else s ++ " "

/-! ### C1 — even-y lift before the tweak (8 checks) -/

def secC1 : String :=
  let fails : String :=
    chk "c1.lift.negates" (liftX x0N == some (x0N, yEven0N)) ++
    chk "c1.taptweak"     (taptweak pk0 none == tdig0) ++
    chk "c1.Q.official"   (tweakPoint pk0 (liftX x0N) none
                             == some (xQ0N, yQ0N)) ++
    chk "c1.naive.oddY"   (tweakPoint pk0 (some (x0N, rOdd0N)) none
                             == some (xQ0nN, yQ0nN)) ++
    chk "c1.divergence"   (decide (xQ0nN ≠ xQ0N)) ++
    chk "c1b.lift.passthrough" (liftX x4N == some (x4N, rEven4N)) ++
    chk "c1b.taptweak"    (taptweak pk4int (some root4) == tdig4) ++
    chk "c1b.Q.official"  (tweakPoint pk4int (liftX x4N) (some root4)
                             == some (xQ4N, yQ4N)) ++
    ""
  if fails == "" then "C1: 8/8 OK"
  else "FAILURES: " ++ fails

/-- info: "C1: 8/8 OK" -/
#guard_msgs in #eval secC1

/-! ### C2 — the TapBranch tag + sorted pairing (8 checks) -/

def tree4 : Option TapTree :=
  some (.node (.leaf (0xc0 : UInt8) s0) (.leaf (0xc0 : UInt8) s1))

def secC2 : String :=
  let fails : String :=
    chk "c2.leaf0"        (tapLeaf (0xc0 : UInt8) s0 == l0) ++
    chk "c2.leaf1"        (tapLeaf (0xc0 : UInt8) s1 == l1) ++
    chk "c2.branch.sorted"     (tapBranch l0 l1 == root4) ++
    chk "c2.branch.comm"       (tapBranch l0 l1 == tapBranch l1 l0) ++
    chk "c2.unsorted.diverges" (decide (taggedHash tagTapBranch (l0 ++ l1) ≠ root4)) ++
    chk "c2.unsorted.value"    (taggedHash tagTapBranch (l0 ++ l1) == unsrt4) ++
    chk "c2.diag"         (tapBranch l0 l0 == taggedHash tagTapBranch (l0 ++ l0)) ++
    chk "c2.diag.value"   (tapBranch l0 l0 == diag4) ++
    chk "c2.treeRoot"     (treeMerkleRoot tree4 == some root4) ++
    chk "c2.spend"        (scriptPathSpend control4 s0 xQ4
                             == some (l0, true, true)) ++
    chk "c2.commitment.binds"
      (verifyTaprootCommitment control4 xQ4 l0 == true) ++
    chk "c2.wrongProgram" (scriptPathSpend control4 s0 xQ0
                             == some (l0, false, true)) ++
    chk "c2.wrongLength"  (scriptPathSpend control4 s0 program4
                             == some (l0, false, true)) ++
    chk "c2.wrongLength.verdict"
      (verifyTaprootCommitment control4 program4 l0 == false) ++
    ""
  if fails == "" then "C2: 14/14 OK"
  else "FAILURES: " ++ fails

/-- info: "C2: 14/14 OK" -/
#guard_msgs in #eval secC2

end Bitcoin.Proofs.Audit.Z29

-- axioms printed in scratch only (doctrine: audit only in scratch)
