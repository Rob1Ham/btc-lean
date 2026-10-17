import Bitcoin.SigHash.Interface
import Bitcoin.Crypto.Seam.Interface

/-!
# Y08 probe — kernel-decide reduction boundary for the hash floor (PINNED)

Three escalating `decide` attempts (probe 3, 2026-10-16), all FAILED with
`Tactic 'decide' failed to reduce` even at `maxHeartbeats 1000000` /
`maxRecDepth 100000`:
  P3a  `sha256 ByteArray.empty` (ONE compression block) via `.data.toList`
  P3b  `sha256d` of a 64-byte message (2 blocks × 2 passes)
  P3c  full `signatureHashLegacy` via `bytesBEq`
The v4.35 kernel cannot whnf-reduce the ByteArray/Array-based compression
(probes 1-2 additionally pinned: `.toList` and `.get!` on a computed
ByteArray both get stuck — cf. Basic.lean's `ByteArray.toList` note).
This independently confirms W11 (spec/Test/Sighash) and W13
(spec/Test/Crypto/SeamHashTest), which use `native_decide` for digest
vectors. Consequence for the Y08 corpus: ByteArray-returning layers (P/D)
are `native_decide` build-time checks; the list-vehicle layers (H0/H1:
htClass, serializeScriptCodeL) stay pure `decide` on the standard trio.
The same three vectors PASS under `native_decide` below (compiler
evaluation) — kept as the pinned boundary evidence.
-/

namespace BitcoinProofs.Property.Y08.Probe

open Bitcoin.SigHash Bitcoin.Crypto.Seam Bitcoin.Data

set_option maxRecDepth 100000
set_option maxHeartbeats 1000000

private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
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

-- P3a: single SHA-256 of empty message (1 compression block)
example : (sha256 ByteArray.empty).data.toList.map (·.toNat) =
    [0xe3, 0xb0, 0xc4, 0x42, 0x98, 0xfc, 0x1c, 0x14, 0x9a, 0xfb, 0xf4, 0xc8,
     0x99, 0x6f, 0xb9, 0x24, 0x27, 0xae, 0x41, 0xe4, 0x64, 0x9b, 0x93, 0x4c,
     0xa4, 0x95, 0x99, 0x1b, 0x78, 0x52, 0xb8, 0x55] := by native_decide

-- P3b: double SHA-256 of a 64-byte message (2 blocks × 2 passes)
example : (sha256d (fromHex "01010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101")).data.toList.map (·.toNat) =
    (fromHex "61a088b4cf1f244e52e5e88fcd91b3b7d6135ebff53476ecc8436e23b5e7f095").data.toList.map (·.toNat) := by
  native_decide

-- P3c: full legacy digest via bytesBEq (the corpus assertion form)
private def txProbe : Tx :=
  { version := 1
    vin := [ ⟨⟨fromHex "1111111111111111111111111111111111111111111111111111111111111111", 0⟩,
              ⟨ByteArray.empty⟩, 0xFFFFFFFF⟩ ]
    vout := [ ⟨1000, ⟨fromHex "51"⟩⟩ ]
    locktime := 0
    witness := [] }

example : bytesBEq (signatureHashLegacy txProbe 0 ⟨fromHex "51"⟩ 0x01)
    (fromHex "b5dbf95b731a8f5a5db7ddc1fc100ad4d625f63a843ef15c791dcbf577ed63b4") = true := by
  native_decide

end BitcoinProofs.Property.Y08.Probe
