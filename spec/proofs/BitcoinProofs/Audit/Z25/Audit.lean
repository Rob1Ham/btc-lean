import Bitcoin.Crypto.Ecdsa.Der
import Bitcoin.Crypto.Ecdsa.Verify
import Bitcoin.Crypto.Ecdsa.Interface

/-!
# Z25 dark-corner audit — SGN-107 mod-n reduction / SGN-108 high-S

2026-10-16. Probes (all VERIFIED):

* `oracle.py`      — python port of Core @ `cce32b168` lax-verify semantics;
                     agrees 215/215 with `spec/Test/Crypto/EcdsaTest.lean`.
* `gen_vectors.py` — decisive-vector construction `Q = r⁻¹(sR − zG)` (lets a
                     signature be built for a *prescribed tiny* r, so that
                     `r0 = r + n` still fits a 32-byte DER payload).
* `probe.c`        — COMPILED vendored libsecp256k1 + byte-exact transcription
                     of `CPubKey::Verify` (pubkey.cpp:283-298) and
                     `ecdsa_signature_parse_der_lax` (pubkey.cpp:45-180):
                     ALL 5 probes PASS.
* `lean_probe.lean` — runs tree `verifyLax` on the same bytes (`lake env lean
                     --run`, flock-ruled).

## Corner verdicts

**C1 (SGN-107) PARTIAL — confirmed divergence.** Core's compact parse treats
`scalar_set_b32` overflow (value ≥ n, not just > 32 bytes) as parse FAILURE:
`secp256k1.c:417-420 ret &= !overflow` → `parse_der_lax` memsets → **r = s = 0**
→ reject. So Core @ cce32b168 REJECTS every DER r ≥ n / s ≥ n; the mod-n
reduction is consensus-visible *with continuation* ONLY for the message hash
(`secp256k1.c:480 scalar_set_b32(&m, msghash32, NULL)` — overflow ignored).
The tree (`Verify.verifyImpl:90-93`) reduces `r0 % n`/`s0 % n` and CONTINUES
verification — accepting signatures Core rejects (fork vector `z25-fork-r33`).
The `der-*` vectors claimed by rules.yaml SGN-107 (`der-000..der-009`) do not
exist under those ids, and no harness vector exercises r ≥ n at all.

**C2 (SGN-108) CAPTURED.** `verifyImpl` has no normalize step; high-S DER
signatures verify (EcdsaTest `highS-001..009` + probe); `isLowDERSignature` is
the policy word (BIP62 §5), gated behind `pol.lowS` in
`Interpreter/Defs.lean:344` — matching `CPubKey::CheckLowS`. (Pedantic: Core's
`CPubKey::Verify` DOES call `signature_normalize` at pubkey.cpp:296 because
raw libsecp `ecdsa_verify` demands `!scalar_is_high`; the normalize is
verdict-invariant, so the observable behavior — high-S accepted — matches.)

Kernel-decidable facts below pin the Der-layer half of each corner; the
end-to-end verdicts live in the IO probes (mulP is WF-recursive, see §5).
-/

namespace Bitcoin.Proofs.Audit.Z25

open Bitcoin.Crypto.Ecdsa.Der

/-! ### Hex helper (test infra only) -/

def hexDigit (c : Char) : Option Nat :=
  let v := c.toNat
  if 48 ≤ v ∧ v ≤ 57 then some (v - 48)
  else if 97 ≤ v ∧ v ≤ 102 then some (v - 87)
  else if 65 ≤ v ∧ v ≤ 70 then some (v - 55)
  else none

def fromHex (s : String) : ByteArray := go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigit a, hexDigit b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

set_option maxRecDepth 100000

/-! ### The fork signature (SGN-107): r encoded as 33-byte DER, value n+1 -/

/-- r₀ = n+1 (33-byte DER integer `02 21 00 ‖ 32 bytes`), s₀ = n − 0xC0FFEE
(high), built (python `gen_vectors.py`, compiled-C `probe.c`) so that the
verify equation holds against pubkey
`03e8ed37cd4c9cf2bf8413876372d1467677e223d71068f7a9c51b62ae5ca25119` for the
reduced r = 1. -/
def sigFork : ByteArray := fromHex
  "3046022100fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142\
022100fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8ccf754153"

/-- The lax parser passes a 33-byte-DER r ≥ n through UNREDUCED (r₀ = n+1,
s₀ = n − 0xC0FFEE): no overflow at the Der layer (payloads are 32 bytes). -/
example : parseDerLax sigFork =
    some (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364142,
          0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CCF754153) := by
  decide

/-- … so `verifyImpl`'s reduction-then-zero-check (Verify.lean:90-93) sees
r = 1 ≠ 0 and CONTINUES into the scalar muls — while compiled Core zeroes
r and s (compact-parse overflow) and REJECTS. The SGN-107 divergence. -/
example : (0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364142
             % Bitcoin.Crypto.Curve.Secp.n) = 1 := by rfl

/-- BIP66 (`isDERSignature`) ADMITS the fork signature (minimal 33-byte
encoding `00 ‖ high-bit payload`), so it reaches consensus verify post-BIP66. -/
example : isDERSignature (fromHex
    "3046022100fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142\
022100fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8ccf75415301") = true := by
  decide

/-- r₀ = n exactly: the tree's zero-check fires on the REDUCED value (the
reduce-then-zero-check ORDER is pinned); compiled Core agrees (reject) via its
overflow-zeroing path. -/
example : parseDerLax (fromHex
    "3046022100fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141\
022100fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8ccf754153") =
    some (Bitcoin.Crypto.Curve.Secp.n,
          0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CCF754153) := by
  decide

example : Bitcoin.Crypto.Curve.Secp.n % Bitcoin.Crypto.Curve.Secp.n = 0 := by rfl

/-! ### SGN-108: the policy split, pinned at the Der layer -/

/-- The baseline signature: r = 1 (minimal), s₀ = n − 0xC0FFEE > n/2 (high). -/
def sigHighS : ByteArray := fromHex
  "3026020101022100fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8ccf754153"

/-- Strict BIP66 accepts it (with the trailing sighash byte). -/
example : isDERSignature (fromHex
    "3026020101022100fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8ccf75415301") = true := by
  decide

/-- … but it is NOT low-S: `isLowDERSignature` (the POLICY word) rejects the
s-side. Consensus (`verifyImpl`, no normalize) still verifies it — pinned
end-to-end by EcdsaTest `highS-001..009` and the compiled probe. -/
example : isLowDERSignature (fromHex
    "3026020101022100fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8ccf75415301") = false := by
  decide

/-- The low-side twin s ↦ n − s = 0xC0FFEE of the same r: policy ACCEPTS what
consensus accepted — the two agree because verification is invariant under
s ↦ n − s (u₁,u₂ ↦ −u₁,−u₂ ⇒ R ↦ −R, same x). -/
example : isLowDERSignature (fromHex
    "3009020101020400c0ffee01") = true := by decide

end Bitcoin.Proofs.Audit.Z25
