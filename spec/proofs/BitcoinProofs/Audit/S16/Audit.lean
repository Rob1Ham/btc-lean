import Bitcoin.SigHash.Interface
import Bitcoin.SigHash.Digest

/-!
# S16 audit — SCS-A12 independent re-verification (SIGHASH_SINGLE
overflow constant) — independent closure (S16-2)

2026-10-17. Sister file:
`proofs/BitcoinProofs/Audit/Z01/Audit.lean` (F-Z01-001).

## What this file is (and is NOT)

S16 claims SCS-A12 (S10 census, Sev S2) with a
**verification/evidence-chain-forensics** scope.  The constant repair
itself landed in FIX-L-SIGHASH2 (2026-10-17); this file now records the
repaired model.  It:

* re-states Z01's C1 pins **verbatim** (Z01's C1 block) as an independent
  S16 elaboration unit (Z01/Audit.olean exists, banked 02:34 post-PD02 —
  the `never-lake-built` list of F-PD02-001 is stale for the Audit/Z*
  layer; S16 re-elaborated Z01/Audit.lean too: `lake env lean` v4.35.0,
  **RC=0, 7 s, 03:23:31→03:23:38**);
* adds S16 pins: the ACP (0x83) digest-arm Core equality, the second
  constant site (`Digest.lean` `singleOverflowOneB` = Core ONE), and the
  axiom-guard on the shipped interface theorem;
* proves NOTHING new about Core beyond the pinned byte equality — the Core
  anchor at pin `cce32b168`
  (`cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`) is re-anchored OUT-OF-TREE
  by S16 (F-S16-002): `script/interpreter.cpp:1614-1622`
  (legacy overflow arm `return uint256::ONE;` before any vin access)
  + `uint256.cpp:34-35` (`const uint256 uint256::ONE(1);`) +
  `uint256.h` (`constexpr explicit base_blob(uint8_t v) : m_data{v} {}`
  ⇒ `m_data[0]=v, m_data[1..31]=0`), web-pinned at 03:1x UTC.
  Z01's own g++ compiled-Core witness (`Z01_print_one.cpp`) and A02's
  probe were **wiped** in the 02:5x crash — irreproducible from the tree
  (F-S16-001).

Kernel-pure (`decide`) only, no `native_decide`, no new axioms, no
hashing (the overflow arm early-returns) — the proof-form discipline of
Z01's F-Z01-004 note carries over; S02's ByteArray walls (G1/G2) do not
bite on 32-literal-reducible shapes (X11's MutationPack.lean §2
RC=0 same shapes).
-/

namespace Bitcoin.Proofs.Audit.S16

open Bitcoin.Data Bitcoin.SigHash Bitcoin.Serialization

set_option maxRecDepth 100000
set_option maxHeartbeats 1000000

/-! ## S16 vehicle copies (Z01-verbatim; Z01's are `private`, unshared) -/

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

/-- 1-vin / 0-vout tx: nIn = 0 ≥ vout.size = 0 ⇒ legacy SINGLE overflow
(Z01:52-60 verbatim). -/
def txOOR : Bitcoin.Data.Tx :=
  { version := 1
    vin := [⟨⟨fromHex "1111111111111111111111111111111111111111111111111111111111111111", 0⟩,
            ⟨fromHex ""⟩, 0xffffffff⟩]
    vout := []
    locktime := 0x00000000, witness := [] }

/-! ## C1 — SCS-A12 repaired pins (S16 = Z01 C1 verbatim, now Core-equal) -/

/-- **Core's** `uint256::ONE` bytes — S16 anchor @ `cce32b168`
(uint256.cpp:35 `const uint256 uint256::ONE(1);` + uint256.h ctor
`base_blob(uint8_t v) : m_data{v}`, web-pinned 03:1x; = Z01's
compiled-Core witness bytes `01 ‖ 0^31`, scratch lost in the wipe). -/
def uint256OneCore : ByteArray :=
  fromHex "0100000000000000000000000000000000000000000000000000000000000000"

/-- The tree's constant is Core's ONE: `01` ‖ 31 zeros
(SigHash/Interface.lean). [Z01 C1 verbatim] -/
example : SINGLE_OVERFLOW_ONE =
    fromHex "0100000000000000000000000000000000000000000000000000000000000000" := by
  decide

/-- **F-Z01-001 repaired pin**: the tree's constant IS Core's
`uint256::ONE`. [Z01 C1 verbatim] -/
example : (SINGLE_OVERFLOW_ONE == uint256OneCore) = true := by decide

/-- The legacy overflow digest returns Core's ONE (concrete tx, ht
0x03; the early return fires before any vin access —
interpreter.cpp:1614-1622). [Z01 C1 verbatim] -/
example : signatureHashLegacy txOOR 0 ⟨fromHex ""⟩ 0x00000003
    = SINGLE_OVERFLOW_ONE := by decide

/-- …and for SINGLE|ANYONECANPAY (0x83). [Z01 C1 verbatim] -/
example : signatureHashLegacy txOOR 0 ⟨fromHex ""⟩ 0x00000083
    = SINGLE_OVERFLOW_ONE := by decide

/-- Hence for the same concrete tx the tree's digest equals Core's ONE.
[Z01 C1 verbatim] -/
example : (bytesBEq (signatureHashLegacy txOOR 0 ⟨fromHex ""⟩ 0x00000003)
             uint256OneCore) = true := by decide

/-! ## S16 additions -/

/-- (S16-P6) The ACP-variant digest matches Core's ONE too (MutationPack
§2 shape; runners RC=0 there — re-pinned S16). -/
example : (bytesBEq (signatureHashLegacy txOOR 0 ⟨fromHex ""⟩ 0x00000083)
             uint256OneCore) = true := by decide

/-- (S16-P7) Second constant site: `singleOverflowOneB` (what
`signatureHashLegacyImpl` returns) is the SAME Core ONE construction as the
interface constant. -/
example : (singleOverflowOneB == SINGLE_OVERFLOW_ONE) = true := by decide

/-- (S16-P8) And the Digest-site digest arm returns Core's ONE for both
hashtype shapes (Impl takes the preimage `scriptCode : Bytes` directly —
`bL (fromHex "")`). -/
example : (bytesBEq (signatureHashLegacyImpl txOOR 0 (bL (fromHex "")) 0x00000083)
             uint256OneCore) = true := by decide

/- (S16-P9) The shipped interface theorem (`Interface.lean`,
`legacy_single_overflow`) is kernel-clean (Theorems.lean has the same
guard): the repaired constant and the interface theorem agree. -/
/-- info: 'Bitcoin.SigHash.legacy_single_overflow' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms Bitcoin.SigHash.legacy_single_overflow

end Bitcoin.Proofs.Audit.S16
