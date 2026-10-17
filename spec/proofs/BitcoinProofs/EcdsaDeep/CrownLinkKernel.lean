import Bitcoin.Crypto.Ecdsa.Verify
import Bitcoin.Crypto.Ecdsa.Der
import BitcoinProofs.EcdsaDeep.CrownBattery
import BitcoinProofs.EcdsaDeep.CrownLink
import BitcoinProofs.EcdsaDeep.VerifyEquation

/-!
# [CROWNLINK] CrownLinkKernel — the KERNEL layer of the E05-battery ×
# E06-crown bridge: 17/215 rows pinned HYPOTHESIS-FREE (verdict + crown)

Contributor CROWNLINK (recovery review 5), 2026-10-17. See `CrownBattery.lean`
(the corpus), `CrownLink.lean` (the bridge theorem),
`CrownLinkRun.lean` (the 215-row runtime layer) and
`db/findings-dl/CROWNLINK.md`.

**The kernel layer.** Of the 215 battery rows, **17 reject-rows are
pinned by bare kernel `decide`** — 8 parse-rejects (E05
`DerBatteryCor`'s none-set) + 9 pk-structural-rejects — each TWICE:

1. **the VERDICT**: `verifyImpl sig pk msg = false := by decide`
   (kernel reduction; NO WF-recursive def is reached: 8 rows die at
   `parseDerLax = none` BEFORE `parsePubKey`; 9 rows die in
   `parsePubKey` = none via tag/length/range/hybrid-parity paths +
   `onCurveN` (off-curve));
2. **THE CROWN-KILL** (the money pin): `¬ VerifyEqRaw sig pk msg`
   — `rw [← verifyImpl_iff]` rewrites the goal THROUGH the E06 crown
   into the Bool verdict, then `decide` closes it: **the row is
   DEAD ON THE CROWN'S EQUATION SIDE, unconditionally** (no
   hypothesis, no runtime): for these 17 rows the sample-consistency
   `crownLink` holds with `hv` supplied by the KERNEL.

**The kernel-decidability frontier (F-CK-002, empirical b1/probe1)**
— 215 = 17 kernel + 198 runtime:
* STUCK = WF-RECURSIVE only: `mulP`/`expM`/`egcd` (R6 wall). The
  one pk-reject in the wall = `pk-compressed-wrong-parity` (33B
  02-tag, x < P → `sqrtP` = `expM`); every ACCEPT row (139) and
  every parse-ok pk-some row (gate/equation rejects) reach
  `invM` = `egcd` → stuck.
* KERNEL-GREEN = plain/GMP-Nat: `parseDerLax` (all, E05),
  `parsePubKey` tag/len/range/hybrid-parity branches, AND
  `onCurveN` (=`mulM`, GMP-mulmod) — `pk-offcurve` +
  `pk-hybrid-even-tag-odd-y` (65B off-curve) are kernel-DECIDED.
The 198 wall-rows = the RUNTIME layer (`CrownLinkRun.lean`, TOTAL
215 FAILURES 0) = exactly R6; "kernel-decidable where possible" =
17/215 = 100% of what the kernel can see.

Probes: probe1 (24 rows = 18 cand + 6 ctrl: 17 green + 7 stuck),
clk-b1 (18 rows: 17 green + 1 stuck = pk-compressed-wrong-parity),
kN1/kPK splits (N1 8/8 green; kPK 9/10) — b2 = THIS file (17 rows
× verdict+crown). NO sorry, NO native_decide.
-/

namespace BitcoinProofs.EcdsaDeep.CrownLinkKernel

open Bitcoin.Crypto.Ecdsa.Der Bitcoin.Crypto.Ecdsa.Verify
open BitcoinProofs.EcdsaDeep.CrownBattery
open BitcoinProofs.EcdsaDeep.CrownLink
open BitcoinProofs.EcdsaDeep.VerifyEquation

set_option maxRecDepth 100000

/-- Parse a hex string into a ByteArray (test infra only; copied from
the W14b harness, EcdsaTest.lean:36-52, read-only). -/
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

/-! ## The 8 parse-rejects (E05 DerBatteryCor's none-set) -/

-- overflow-002 [parse-reject]
example : verifyImpl (fromHex
    "30440221018efae13b6c5ca5c0de44a445644fda40a8dbfc52f8a45aab1b82579633e39aa9023d7162216d6aa1cc2fb5ef2d9855698b73a4bd896c47db45b5339d52796cb485") (fromHex
    "03f86ac12b105f58d6c64265900753edbf4c98e6785262a2adb166606b42b18ef1") (fromHex
    "6a499f9639f0f0c60cb2641721c8854a14192d23c153c9637ab10cdbdcb924e1") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "30440221018efae13b6c5ca5c0de44a445644fda40a8dbfc52f8a45aab1b82579633e39aa9023d7162216d6aa1cc2fb5ef2d9855698b73a4bd896c47db45b5339d52796cb485") (fromHex
    "03f86ac12b105f58d6c64265900753edbf4c98e6785262a2adb166606b42b18ef1") (fromHex
    "6a499f9639f0f0c60cb2641721c8854a14192d23c153c9637ab10cdbdcb924e1") := by
  rw [← verifyImpl_iff]
  decide
-- der-empty [parse-reject]
example : verifyImpl (fromHex
    "") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- der-tag [parse-reject]
example : verifyImpl (fromHex
    "3146022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3146022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- der-trunc [parse-reject]
example : verifyImpl (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- der-inttag [parse-reject]
example : verifyImpl (fromHex
    "3046032100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3046032100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- der-nonseq [parse-reject]
example : verifyImpl (fromHex
    "0246022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "0246022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- der-emptykey [parse-reject]
example : verifyImpl (fromHex
    "") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- der-r-only [parse-reject]
example : verifyImpl (fromHex
    "3023022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3023022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
/-! ## The 9 pk-structural-rejects (parsePubKey = none) -/
/-! ## The 9 pk-structural-rejects (parsePubKey = none) -/
-- pk-badtag [pk-reject]
example : verifyImpl (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "05f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "05f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- pk-empty [pk-reject]
example : verifyImpl (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- pk-garbage [pk-reject]
example : verifyImpl (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- pk-hybrid-even-tag-odd-y [pk-reject]
example : verifyImpl (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- pk-hybrid-wrong-parity [pk-reject]
example : verifyImpl (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- pk-long [pk-reject]
example : verifyImpl (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b00") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b00") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- pk-offcurve [pk-reject]
example : verifyImpl (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- pk-short [pk-reject]
example : verifyImpl (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a411") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a411") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
-- pk-x-ge-p [pk-reject]
example : verifyImpl (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "03fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") = false := by decide
example : ¬ VerifyEqRaw (fromHex
    "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd") (fromHex
    "03fffffffffffffffffffffffffffffffffffffffffffffffffffffffefffffc2f") (fromHex
    "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d") := by
  rw [← verifyImpl_iff]
  decide
end BitcoinProofs.EcdsaDeep.CrownLinkKernel
