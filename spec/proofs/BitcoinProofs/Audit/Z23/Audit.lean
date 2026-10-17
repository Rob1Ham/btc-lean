import Bitcoin.Crypto.Ecdsa.Der
import Bitcoin.Crypto.Ecdsa.Verify
import Bitcoin.Crypto.Ecdsa.Interface

/-!
# Z23 dark-corner audit — C1 uncompressed/hybrid pubkey forms,
C2 the ONE shared lax-overflow flag (SGN-106/107 interplay)

NEW file, owned by Z23 alone, 2026-10-16. Python3 probe (20/20 PASS against
a byte-exact transcription of Core @ `cce32b168` — `src/pubkey.cpp:45-186,283-298`,
`src/secp256k1/src/secp256k1.c:407-426,472-486`,
`src/secp256k1/src/group_impl.h:1069-1102`,
`src/secp256k1/src/scalar_4x64_impl.h:147-159`, vendored at
`build/scratch/W02/bitcoin` == `build/scratch/W14b/bitcoin`,
`pubkey.cpp` verified identical, both HEAD = c50817f):
`build/scratch/build/scratch/scratch/Z23/z23_probe.py`.
Findings: `spec/db/findings-w4/Z23.md`.

## Verdicts

* **C1 (uncompressed 04 / hybrid 06-07 pubkey acceptance): CAPTURED.**
  `Bitcoin.Crypto.Ecdsa.Verify.parsePubKey` (Verify.lean:47-63, SGN-105)
  is a faithful port of `secp256k1_ge_impl_parse` (group_impl.h:1069-1102):
  33-byte 02/03 with `x < P` + sqrt y-recovery; 65-byte 04/06/07 with
  `x,y < P`, the hybrid parity check `(y odd) ≠ (tag = 07) → reject`
  (group_impl.h:1094-1096) and the on-curve check; subgroup check omitted
  legally (cofactor 1 ⇒ always true, group_impl.h:976-981). The interpreter
  gate `pubKeyLen` (Seam/Der.lean:128-141) = `CPubKey::GetLen` incl.
  `06/07 → 65`. Kernel pins below (`Z23_C1_*`); compiled-runtime accepts
  through `verifyLax` in `main` (harness rows `pkform-*` re-run here).
* **C2 (ONE shared overflow flag zeroing BOTH r and s): PARTIAL.**
  The `>32`-byte branch IS captured: `parseDerLax` zeroes both r and s
  through the shared flag (Der.lean:139-141), pinned by `Z23_C2_overlong`
  below and the 5 compiled `overflow-*` harness vectors. But Core's shared
  flag ALSO fires inside `secp256k1_ecdsa_signature_parse_compact`
  (secp256k1.c:407-426): `scalar_set_b32` sets overflow iff the 32-byte
  value `≥ n` (scalar_4x64_impl.h:147-159, `scalar_check_overflow`), and
  parse_compact then memsets the WHOLE signature → `(0,0)`. Lean's
  `verifyImpl` instead wraps `r0 % n` / `s0 % n` (Verify.lean:91-92) —
  zero-check passes where Core's fails. Pinned by `Z23_C2_geN_divergence`
  below. End-to-end ACCEPT-vs-REJECT verdict flips need `r ∈ [n, 2^256)`
  whose wrap `r-n` satisfies the EC equation — `r-n < 2^256-n ≈ 2^128.35`,
  probability ≈ 2^-128 per signature (probe §W2). Consequence: oracle
  suites cannot see the divergence — and indeed the project's own
  `gen_ecdsa_vectors.py` §5 `rmodn` loop (filter `r + N < 2**256`)
  silently emitted ZERO vectors in 40 tries (expected hits 1.5e-37), while
  rules.yaml SGN-107 and the EcdsaTest.lean docstring still claim 10.
  Same conclusion reached independently by the DEEP-LEAN suite
  (findings-dl E05 F-E05-001; EcdsaDeep/DerSpec.lean header) — unlanded
  there (relation `CoreZero` documented, no def/theorem/vector yet).

All examples kernel-`decide`d on the structural Der layer (no WF-recursive
`mulP`/`expM` reduction, W14 §5 discipline); no `native_decide`.
-/

namespace BitcoinProofs.Audit.Z23

open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Ecdsa
open Bitcoin.Crypto.Ecdsa.Der
open Bitcoin.Crypto.Ecdsa.Verify

set_option maxRecDepth 100000
set_option maxHeartbeats 2000000

/-! ## Hex helper (test infra only, mirrors Test/Crypto/EcdsaTest.lean) -/

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

/-! ## C1 — uncompressed / hybrid pubkey form rules (SGN-105) -/

-- valid-000 triple (compiled harness control, 33-byte compressed pk)
def sigValid000 := fromHex
  "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd"
def pkValid000 := fromHex
  "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d"
def msg000 := fromHex
  "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d"

-- probe keypair(2001), even-y Q, serialized in all three 65-byte forms
def pkUncompressed := fromHex
  "04025ca43eb507e712af2f6b49287297aa47b3608414349b657e9ba959ab1e67cac7ece12aa64c352ecd5b674d8c97824b1ec87b3079c1f2bf1a08549af1fd9334"
def pkHybridEven := fromHex
  "06025ca43eb507e712af2f6b49287297aa47b3608414349b657e9ba959ab1e67cac7ece12aa64c352ecd5b674d8c97824b1ec87b3079c1f2bf1a08549af1fd9334"
def pkHybridWrongParity := fromHex  -- tag 06 but odd y (probe -Q)
  "06025ca43eb507e712af2f6b49287297aa47b3608414349b657e9ba959ab1e67ca38131ed559b3cad132a498b273687db4e13784cf863e0d40e5f7ab640e0268fb"
def pkTag05 := fromHex  -- 0x05 is NO format (not 02/03/04/06/07)
  "05025ca43eb507e712af2f6b49287297aa47b3608414349b657e9ba959ab1e67cac7ece12aa64c352ecd5b674d8c97824b1ec87b3079c1f2bf1a08549af1fd9334"

/-- Hybrid with mismatched parity (tag 06, y odd) is REJECTED — the
group_impl.h:1094-1096 parity check, kernel-reduced through the parse
prefix (stops before the on-curve evaluation). -/
theorem Z23_C1_hybrid_wrong_parity_rejected :
    parsePubKey pkHybridWrongParity = none := by
  decide

/-- Tag 0x05 names no key format: 65 bytes but not 04/06/07 → reject
(group_impl.h:1099-1101 `else return 0`). -/
theorem Z23_C1_tag05_rejected :
    parsePubKey pkTag05 = none := by
  decide

/-- A well-formed hybrid (tag 06, y even, on curve) PARSES — the hybrid
accept path exists (group_impl.h:1090-1097). -/
theorem Z23_C1_hybrid_accepts :
    (parsePubKey pkHybridEven).isSome = true := by
  decide

/- Harness row `pkform-hybrid-001`: a 0x07-tagged (odd-y) hybrid pubkey
verifies end-to-end — checked by COMPILED RUNTIME execution in `main`
below (verifyImpl routes through the WF-recursive `mulP`/`expM`, which
kernel `decide` must not reduce; W14 §5 discipline, D-004: no
`native_decide`). -/

/-! ## C2 — the ONE shared overflow flag (SGN-106) and its ≥n twin -/

-- probe W1: overlong r (33-byte payload, top byte nonzero) — the captured
-- >32 branch. Same shape as harness row overflow-000.
def sigOverlongR := fromHex
  "3045022101e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a020084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd"

-- probe W2: r = 2^256-1 as a *33-byte* DER int (0x00-padded, strips back to
-- 32 bytes), s = the VALID s2 of valid-000. Well-formed DER throughout.
def sigGeN := fromHex
  "3046022100ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd"

/-- Core's parse_compact-level shared overflow: EITHER 32-byte value ≥ n
zeroes BOTH (secp256k1.c:416-424 `memset(sig, 0, sizeof(*sig))`;
scalar_4x64_impl.h:153 `scalar_reduce(check_overflow)`). Net effect of the
full `ecdsa_signature_parse_der_lax` chain (pubkey.cpp:175-183). -/
def coreCompactZero (r0 s0 : Nat) : Bool := r0 ≥ n ∨ s0 ≥ n

/-- The captured `>32` branch: overlong r ⇒ BOTH r and s come out 0, yet
the signature still PARSES (`some (0,0)`, pubkey.cpp:178-186 returns 1) —
the shared-flag semantics, exactly. -/
theorem Z23_C2_overlong_shared :
    parseDerLax sigOverlongR = some (0, 0) := by
  decide

/-- THE DIVERGENCE: for a 32-byte (post-strip) r = 2^256-1 ≥ n, Core's
chain yields (0,0) — shared flag — while Lean's `parseDerLax` hands the
RAW value to `verifyImpl`, which wraps `r0 % n ≠ 0` (Verify.lean:91) and
therefore PASSES the zero check (Verify.lean:93) where Core fails it. -/
theorem Z23_C2_geN_divergence :
    parseDerLax sigGeN
      = some (2^256 - 1,
        0x84d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd)
    ∧ coreCompactZero (2^256 - 1)
        0x84d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd
      = true
    ∧ (2^256 - 1) % n ≠ 0 := by
  decide

/-- The same ≥n divergence on the s side (probe W3): s = 2^256-1 33-byte
encoded, r = the VALID r2 — Core zeroes BOTH (killing a perfectly good
r through the shared flag); Lean wraps s instead. -/
theorem Z23_C2_geN_divergence_s_side :
    parseDerLax (fromHex
      "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a022100ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff")
      = some (0xe4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a,
        2^256 - 1)
    ∧ coreCompactZero 0xe4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a
        (2^256 - 1) = true := by
  decide

/- End-to-end control: the ≥n-r signature still REJECTS in Lean too (the
wrapped r does not satisfy the EC equation here) — the divergence is in
the PARSED VALUE / zero-check stage, not the final verdict, for all
reachable signatures. Verified by compiled runtime in `main`
(`z23-geN-endtoend` row); not kernel-decided (WF-recursive EC math). -/

/-! ## Compiled-runtime checks (IO; mirrors the harness methodology) -/

/-- C1 accept rows re-run through `verifyLax` + parse traces for C2. -/
def main : IO Unit := do
  let mut fails := 0
  let rows : List (String × Bool × String × String × String) :=
    [ ("pkform-uncompressed-000", true,
       "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd",
       "04f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b",
       "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d"),
      ("pkform-hybrid-001", true,
       "30450221009a12cae343568734d0b82c554a07b0a24ca663810f206b395a75926286337b6602201b645730c49cc66aab4f487b10b38d8ca7e2064499e7375dff9e1a7366dd3a83",
       "07de7d0279cf7fa80af8571f42cd30b785f7a1fc6b2c96c5250d065f24cdfe9f2af2bae572672f44cdfcf31d87201c3ae9bc142774045e4fef17b872ab68eb8561",
       "44be3cc75e29124c5757d399cb5b2bc1f08b3518321a9e44b3f3d8d933393968"),
      ("pk-hybrid-wrong-parity", false,
       "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd",
       "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5b",
       "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d"),
      ("pk-hybrid-even-tag-odd-y", false,
       "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd",
       "06f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d0fdf1d16e05c410a69d1af1ea77a6eeab482284541cd91e9f79e9336511c4f5c",
       "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d"),
      ("valid-000-control", true,
       "3046022100e4c37eeeb8e79101e1214bb8419d9c5b4a0ad53abb8f43274cac4edc843d0b6a02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd",
       "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d",
       "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d"),
      ("z23-geN-endtoend (Core also rejects)", false,
       "3046022100ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff02210084d997aa48f7ffc45ce89850cf5ec9a88919c76a929f0e6acdbe2575b8f9a6dd",
       "03f2cf7e8da5a3ec8cd84f3be6185f9392a43ba8a2bcf12ecc9cfead5f05a4119d",
       "dc82cf80e86022c9de86da5cbd484fcbb7f4726312006f6cee2c85a019d7888d")]
  for (name, expected, sg, pk, m) in rows do
    let got := verifyLax (fromHex sg) (fromHex pk) (fromHex m)
    if got != expected then
      fails := fails + 1
      IO.println s!"FAIL {name}: expected {expected}, got {got}"
  IO.println s!"[parse] overflow>32 shared flag: {repr (parseDerLax sigOverlongR)}"
  IO.println s!"[parse] r=2^256-1 as 33B int : {repr (parseDerLax sigGeN)}"
  IO.println s!"[core ] Core would give (0,0) for BOTH (shared flag ≥n, python probe)"
  IO.println s!"TOTAL {rows.length} FAILURES {fails}"
  if fails > 0 then throw (IO.userError "Z23 audit failures")

end BitcoinProofs.Audit.Z23

/-- Runner entry (`lake env lean --run`). -/
def main : IO Unit := BitcoinProofs.Audit.Z23.main
