import Bitcoin.Crypto.EcdsaDeep.VerifyStruct

/-!
# VerifyStructProbe — the structural mirror kernel-reducibility probe

GO/NO-GO for the structural-mirror design of `VerifyStruct.lean`:
can the Lean 4 kernel `decide` through the fuel-structural bit lists,
the fuel-list `egcdL` (256-bit values in GMP positions only), the
`Int` arithmetic of the Euclid step, and a full `mulPbsG` point chain?
Every `by decide` here is kernel evaluation (the no-axiom policy-clean; no
`native_decide` anywhere in `spec/` outside `Test/`).
-/

namespace Bitcoin.Crypto.EcdsaDeep.VerifyStructProbe

open Bitcoin.Crypto.EcdsaDeep.VerifyStruct
open Bitcoin.Crypto.Curve.Mod
open Bitcoin.Crypto.Curve.Secp

set_option maxRecDepth 200000

/-- P0: sanity — a 256-bit `Nat` modulus/mul/div/mod/decEq chain reduces
(the `G_onCurve` evidence class, on this toolchain build). -/
example : (0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8 * 0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8) % 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F = 0x4866d6a5ab41ab2c6bcc57ccd3735da5f16f80a548e5e20a44e4e9b8118c26f2 := by
  decide

/-- P1: fuel-254 matching with a 256-bit value in GMP positions:
`bitsLeF 254 x` builds 254 cons cells without ever matching `x`. -/
example : (bitsLeF 254 0x1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF).length = 254 := by
  decide

/-- P2: the full bit-list cycle at the real exponent: `sqrtExp` (254
bits) in, `bitsVal` (GMP mul/add per bit) out. -/
example : bitsVal (bitsLeF 254 sqrtExp) = sqrtExp := by
  decide

/-- P3: `sqrtPG` reduces the full 256-bit `expBits` square-and-multiply
chain (254 squarings = the in-tree Pratt-certificate cost class). -/
example : sqrtPG 3 = expBits P 3 (bitsLeF 254 sqrtExp) := by
  decide

/-- P4: `egcdLDone` on the fuel list `FL = zeros 600` (600 = small
literal match) with 256-bit `(P, Gx)` — the full Euclid-descent
witness, `Int` beq/mul/sub included. -/
example : egcdLDone FL P 0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798 = true := by
  decide

/-- P5: `invMSG` — the `if g == 1`, `Int.emod`, `Int.toNat` path
(`invM`'s tail, Mod.lean:357) at small scalars. -/
example : invMSG FL 7 5 = invMSG FL 7 5 := by
  decide

/-- P6: the mini point chain — `mulPbsG [false, true] p` runs one full
`doubleRawG` = one `invPSG` = one 256-bit `egcdL` descent inside
`mulPbsG`, point-eq decided. -/
example :
    mulPbsG FL [false, true] (some (Gx, Gy))
      = doublePG FL (addPG FL (some (Gx, Gy)) (doublePG FL (mulPbsG FL [] (some (Gx, Gy))))) := by
  decide

end Bitcoin.Crypto.EcdsaDeep.VerifyStructProbe
