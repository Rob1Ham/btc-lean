import Bitcoin.Crypto.Ecdsa.Der
import Bitcoin.Crypto.EcdsaDeep.DerSpec
import Bitcoin.Crypto.Curve.Secp

/-!
# [E12] StrictWindow - the strict-BIP66 half of the r/s ≥ n divergence
# window (the r/s-range-checks lane).

E05's `CoreZero`/`CoreLax` (Bitcoin.Crypto.EcdsaDeep.DerSpec, repaired
`6066928` = F-E12-001) had ZERO theorems (F-E12-002); `isDERSignature`
(SGN-111, the consensus BIP66 gate) had ZERO theorems (Z25 = anonymous
`by decide` examples only); Z23 pinned the window's LAX half
(`parseDerLax sigGeN` + its own `coreCompactZero` mirror) and audited
"`CoreZero` … no def/theorem/vector yet". This file lands the missing
STRICT↔window↔relation half, sorry-free, kernel-`decide` (D-004/D2
discipline, no `native_decide`).

## The witness `b66GeN` (r = n + 1, 33-byte minimal-pad DER)

`0x30 0x26 0x02 0x21 0x00 ‖ (n+1)_32be ‖ 0x02 0x01 0x01 ‖ 0x01`
(41 bytes incl. the trailing sighash byte; lenR = 33 = 0x00-minimal-pad
of a high-bit payload, lenS = 1, lenR+lenS+7 = 41 = blen, 9 ≤ 41 ≤ 73).
r32 = n+1 = `0x…36 41 42` ≥ n = the F-E05-001 window on a STRICT-DER
input. Read it against the C:

* BIP66 (interpreter.cpp:118-182 @ cce32b168): all 17
  `IsValidSignatureEncoding` checks pass — in particular `sig[4] = 0x00`
  IS the allowed minimal pad (check 13 fires only on `sig[4] = 0` with
  `sig[5]` NOT high-bit; here sig[5] = 0xFF), and NOTHING in BIP66 bounds
  r < n (r ≥ n is admitted; the r/s RANGE check is not in the strict
  gate).
* lax parse (pubkey.cpp:45-185): strips the pad (rpos' = 5, rlen' = 32
  ≤ 32 → no lax-overflow), keeps the RAW r = n+1 = `parseDerLax`-some
  (Der.lean:108-142).
* Core crypto (secp256k1.c:407-427 + pubkey.cpp:175-183): r32 = n+1 ≥ n
  → `scalar_set_b32` overflow → parse_compact = 0 → memset → (r,s) =
  (0,0) → `ecdsa_verify` zero-reject = `CoreZero` (DerSpec.lean:231-237)
  = the C-side REJECT semantics.
* Lean `verifyImpl` (Verify.lean:91): `r % n = (n+1) % n = 1` BEFORE
  the nonzero check → the zero-check does NOT fire = the Lean-side
  continue semantics = the SGN-107 divergence, on a BIP66-admissible
  input.
-/

namespace Bitcoin.Proofs.EcdsaDeep.StrictWindow

open Bitcoin.Crypto.Ecdsa.Der
open Bitcoin.Crypto.EcdsaDeep.DerSpec
open Bitcoin.Crypto.Curve.Secp

set_option maxRecDepth 100000
set_option maxHeartbeats 2000000

/-- The window witness: strict-BIP66-admissible, lax-parseable, r = n+1 ≥ n
raw. 41 bytes incl. sighash (`0x30 0x26 0x02 0x21 0x00 ‖ (n+1)_32 ‖ 0x02
0x01 0x01 0x01`). -/
def b66GeN : ByteArray := ⟨#[
  0x30, 0x26, 0x02, 0x21, 0x00,
  0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF,
  0xFF, 0xFF, 0xFF,
  0xFE, 0xBA, 0xAE, 0xDC, 0xE6, 0xAF, 0x48, 0xA0, 0x3B, 0xBF, 0xD2, 0x5E,
  0x8C, 0xD0, 0x36, 0x41, 0x42,
  0x02, 0x01, 0x01, 0x01]⟩

/-- The 41-byte shape (kernel). -/
theorem b66GeN_blen : blen b66GeN = 41 := by decide

theorem b66GeN_blen' : blen (dropLastByte b66GeN) = 40 := by decide

/-- The R-structure: tag 0x02 @2, short lenR = 33 @3, payload @4 (pad) /
@5..36 (r32), S-tag 0x02 @37, lenS = 1 @38, s = 1 @39 (kernel). -/
private theorem b66_rlR : readLenAt (dropLastByte b66GeN) 3 = some (33, 4) := by
  decide

private theorem b66_rlS : readLenAt (dropLastByte b66GeN) 38 = some (1, 39) := by
  decide

/-- The pad-stripping (pubkey.cpp:151-155): rpos 4→5, rlen 33→32; S has
no pad (kernel). -/
private theorem b66_stripR : stripZeros (dropLastByte b66GeN) 4 33 = (5, 32) := by
  decide

private theorem b66_stripS : stripZeros (dropLastByte b66GeN) 39 1 = (39, 1) := by
  decide

/-- The raw values: r32 = readBE 5 32 = n+1 (the window), s = 1 (kernel). -/
private theorem b66_rval : readBE (dropLastByte b66GeN) 5 32 = n + 1 := by decide

private theorem b66_sval : readBE (dropLastByte b66GeN) 39 1 = 1 := by decide

/-- The full structural relation `StrOk` on the dropLastByte view
(p2 = 2 short-form seq header; the 13-reject-site prefix all pass)
(kernel). -/
private theorem b66_StrOk : StrOk (dropLastByte b66GeN) 2 33 4 1 39 := by
  refine ⟨⟨by decide, by decide, by decide, fun _ => rfl,
      fun h => absurd h (by decide), by decide⟩,
    ⟨by decide, by decide⟩, b66_rlR, by decide,
    ⟨by decide, by decide⟩, b66_rlS, by decide⟩

/-- **T1** — the strict-gate ↔ window ↔ CoreZero-relation ↔ Lean-wrap
conjunction, in one sorry-free theorem (the F-E05-001 / Z23-C2 / Z25-fork
pin, strict half):

* `isDERSignature b66GeN = true` — BIP66 (the CONSENSUS strict gate)
  ADMITS r = n+1 (33-byte minimal pad): the r/s ≥ n range check is NOT
  in BIP66 (kernel);
* `parseDerLax (dropLastByte b66GeN) = some (n + 1, 1)` — the lax
  parser (what the tree's verifyImpl consumes) keeps the RAW r = n+1
  (kernel);
* `CoreZero (dropLastByte b66GeN)` — Core's C-semantics on the same
  bytes (parse_compact overflow → pubkey zeroing → (0,0) reject):
  the FIRST construction of a `DerSpec` relation (F-E12-002's stillborn
  spec made real), via `StrOk` + strip-equations + `r32 ≥ n`;
* `(n + 1) % n = 1` — the Lean wrap (Verify.lean:91) is NONZERO where
  Core zero-rejects = the SGN-107 divergence, on a BIP66-admissible
  input (kernel). -/
theorem bip66_strict_window_geN :
    isDERSignature b66GeN = true ∧
    parseDerLax (dropLastByte b66GeN) = some (n + 1, 1) ∧
    CoreZero (dropLastByte b66GeN) ∧
    (n + 1) % n = 1 := by
  refine ⟨by decide, by decide, ?_, by decide⟩
  exact ⟨2, 33, 4, 1, 39, 5, 32, 39, 1, b66_StrOk, b66_stripR, b66_stripS,
    by decide, by decide, Or.inl (by decide)⟩

/-- **T2** — `CoreLax` (E05's phantom `parseDerLax_rel` ←-half) on the
window witness: the accept-relation "Core returns 1 with (r, s)" holds
with the RAW r = n+1 — the lax layer and the Core lax layer AGREE on
the window; the divergence is later (parse_compact = `CoreZero`, not
`CoreLax`). `DerCoreSig.crs`-arm (no lax-overflow: rlen' = slen' = 32
≤ 32 = the `czero`-window complement). -/
theorem bip66_strict_window_coreLax :
    CoreLax (dropLastByte b66GeN) (n + 1) 1 := by
  refine ⟨2, 33, 4, 1, 39, 5, 32, 39, 1, b66_StrOk, b66_stripR, b66_stripS, ?_⟩
  exact DerCoreSig.crs (by decide) (by decide) (n + 1) 1 (by decide) (by decide)

#print axioms bip66_strict_window_geN
#print axioms bip66_strict_window_coreLax

end Bitcoin.Proofs.EcdsaDeep.StrictWindow
