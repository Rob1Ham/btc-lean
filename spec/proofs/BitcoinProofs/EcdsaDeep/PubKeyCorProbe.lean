import Bitcoin.Crypto.EcdsaDeep.PubKeyParse
import Bitcoin.Crypto.Ecdsa.Der

/-!
# [E07] PubKeyCorProbe — kernel go/no-go for the PubKeyCor row shapes

E09-VerifyStructProbe pattern: decide-idiom census BEFORE generating the
46-row corpus (`gen_pubkeycor_vecs.py` v2: 34 decide rows + 12 R6
pyC-TRUTH rows + 12 R6b-WALL rows; 0 pyC/pyLean mismatches; the 30
pkform M-rows were DROPPED = S15's PubKeyMatrix M4/M6 duplicates).
PROBES (all `by decide`, D-004 — no `native_decide`):

* **P0/P0b** ser-shape `parse (serUncompressed/serHybrid …)`:
  **WALL** (decide-BLOCKED) — see THE WALL below (F-Y09-001 echo,
  Array.map/++-opacity).
* **P1**  fromHex-shape control: pkform-000 = some (X0, Y0) — the
  E05/DerBatteryCor 215-row + S15-M4 built precedent (ALL corpus rows
  ride this shape).
* **P1b** fromHex-mutant: tag-flip 06||X0||Y0 = none (hybrid parity
  reject, `hybridParityOk`).
* **P2**  33B x≥P arm: `02||X14` (BIP340 row-14 pk = P+1) = none
  (x≥P short-circuits BEFORE sqrtP → decide-clean).
* **P3**  65B tag matrix: `0x05||DFF1||D69C` (fromHex) = none.

R6 (NOT probed, E14-evidenced, F-W14b-1): the 33B **Some**-path =
`sqrtP` = `expM` = WellFounded = kernel-stuck; `PubKeyCorSer`/`Vec`
carry those 12 rows as pyC-TRUTH comments (no dishonest kernel claim).

NO sorry, NO native_decide. -/

namespace Bitcoin.Proofs.EcdsaDeep.PubKeyCorProbe

set_option maxRecDepth 100000
set_option maxHeartbeats 4000000

open Bitcoin.Crypto.EcdsaDeep.PubKeyParse
open Bitcoin.Crypto.Ecdsa.Der

private def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

private def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
    go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

/-! ## THE WALL (P0/P0b, probe-NEGATIVE, recorded)

`parsePubKeyDeep (serUncompressed Gx Gy) = some (Gx, Gy)` and the
`serHybrid`-twin **fail `decide`** — kernel reduction gets stuck inside
`blen (ByteArray.empty.push t ++ beBytes32 x ++ beBytes32 y)`:

```
error: Tactic `decide` failed to reduce ... reduction got stuck at
  match parsePubKeyDeep (serHybrid 5506626302227734366957871889516854..24
    32670510020758816978083085130507043184471273380659243275938..24) with
  | none => ... | some a => ...
```

= the **F-Y09-001/F-S02-003 Array-opacity wall** (`beBytes32` =
`ByteArray.mk ((Array.range 32).map (beByte32 x))` rides `Array.map`;
`++`/`Array.append` idem) — a *representation-layer* cousin of R6
(F-W14b-1, kernel-stuck on WellFounded `expM`), NOT a fuel problem:
fromHex-built ByteArrays (`ByteArray.push`/`.data.size`/`.data.getD`
only) decide fine (E05 215/215; P1/P1b/P2/P3 below; S15 M4/M6). →
**F-E07-003**: ser-shape `decide` rows are BLOCKED kernel-side; the
SER-rows of `PubKeyCorVec.lean` therefore pin
`parse (fromHex (hex (ser x y)))` (= the exact bytes `ser x y` produces,
`hex∘ser`-identity oracle-checked in `gen_pubkeycor_vecs.py`) — the
`parse ∘ ser = id` composite is oracle-linked, not one kernel term.
Route: E01/E11 structural mirrors (List-UInt8 `beBytes32'`). -/

/-- P1: fromHex-shape control (pkform-000 = 04||X0||Y0) = some (X0, Y0). -/
example : parsePubKeyDeep (fromHex
    "04F2CF7E8DA5A3EC8CD84F3BE6185F9392A43BA8A2BCF12ECC9CFEAD5F05A4119D0FDF1D16E05C410A69D1AF1EA77A6EEAB482284541CD91E9F79E9336511C4F5B") =
    some (0xF2CF7E8DA5A3EC8CD84F3BE6185F9392A43BA8A2BCF12ECC9CFEAD5F05A4119D,
      0x0FDF1D16E05C410A69D1AF1EA77A6EEAB482284541CD91E9F79E9336511C4F5B) := by
  decide

/-- P1b: tag-flip mutant (06||X0||Y0) = none (hybrid parity reject). -/
example : parsePubKeyDeep (fromHex
    "06F2CF7E8DA5A3EC8CD84F3BE6185F9392A43BA8A2BCF12ECC9CFEAD5F05A4119D0FDF1D16E05C410A69D1AF1EA77A6EEAB482284541CD91E9F79E9336511C4F5B") =
    none := by decide

/-- P2: 33B tag 02, x = BIP340 row-14 pk (P+1) — x ≥ P arm (decide-clean). -/
example : parsePubKeyDeep (fromHex
    "02FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC30") =
    none := by decide

/-- P3: 65B tag 0x05||DFF1||D69C = none (tag matrix). -/
example : parsePubKeyDeep (fromHex
    "05DFF1D77F2A671C5F36183726DB2341BE58FEAE1DA2DECED843240F7B502BA659EEFDEA4CDB677750A420FEE807EACF21EB9898AE79B9768766E4FAA04A2D4A34") =
    none := by decide

end Bitcoin.Proofs.EcdsaDeep.PubKeyCorProbe
