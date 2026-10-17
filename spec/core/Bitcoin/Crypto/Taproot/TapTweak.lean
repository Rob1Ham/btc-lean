import Bitcoin.Crypto.Curve.Secp
import Bitcoin.Crypto.Schnorr.TaggedHash

/-!
# Bitcoin.Crypto.Taproot.TapTweak — the TapTweak tweak and output-key
# equation (X03, Unit 1)

BIP341's output-key derivation, the consensus lane of the taproot
commitment (bip-0341.mediawiki §"Script validation rules" items
''t = hash_TapTweak(p || k_m)'' .. ''Q = P + int(t)G''; Core
`XOnlyPubKey::ComputeTapTweakHash` pubkey.cpp:246-255 +
`CheckTapTweak`/`secp256k1_xonly_pubkey_tweak_add_check`
pubkey.cpp:257-263, extrakeys_main_impl.h:142-161 @cce32b168).

## What is ported where

* `tagTapBranch` — the one TapRoot tag X02 did not need
  ("TapBranch"; `HASHER_TAPBRANCH` interpreter.cpp:1887-1896, the only
  Core tag constant without a `Schnorr/TaggedHash.lean` home). Lives HERE,
  beside the X02-owned tags in the importing relationship: `TapTweak.lean`
  imports `Schnorr/TaggedHash.lean` and never edits it.
* `taptweak` (TPR-015/TPR-083) — `ComputeTapTweakHash` EXACTLY:
  `taggedHash "TapTweak" (p ‖ root)` with `p` the 32 raw internal-key
  bytes and `root` = `k_m` AS-IS (32 raw bytes). Core's
  `uint256::Serialize` is `s << span(m_data)` — the 32 bytes are written
  in the order they were READ (no LE reversal); byte-order ground truth
  u256.h/serialize.h. The `merkle_root == nullptr` branch
  (`ComputeTapTweakHash(nullptr)` = `hashTapTweak(p)` alone, pubkey.cpp
  :248-251) is the wallet-side ''commit to an unspendable script path''
  case (BIP341:158) — `CheckTapTweak` (the consensus caller) ALWAYS
  passes a root (the merkle root of the control-block walk, = the tapleaf
  hash itself when the path is empty), so `none` = wallet lane, pinned
  for the python cross-check (vector `scriptPubKey[0]` is key-only).
* `tweakScalar` — `t = int_from_bytes(tagged_hash("TapTweak", pubkey +
  h))` (BIP341:184): the 32 digest bytes reduced **big-endian**
  (BIP340's `int_from_bytes`; libsecp `secp256k1_scalar_set_b32`,
  scalar.h: the 32 bytes are the big-endian magnitude). Core parses
  `tweak.begin()` — same 32 bytes — into a `secp256k1_scalar`.
* `tweakPoint` (TPR-016/TPR-017) — `Q = P + int(t)·G` with libsecp's
  reject conditions collapsed onto `none` = the point at infinity:

  > `secp256k1_xonly_pubkey_tweak_add_check` fails iff
  > `secp256k1_xonly_pubkey_tweak_add` fails, iff
  > `secp256k1_ec_pubkey_tweak_add_helper` fails, iff the tweak OVERFLOWS
  > the secp256k1 group order **or** `P + t·G = infinity`
  > (extrakeys_main_impl.h:151-153, eckey_impl.h:23-33:
  > `gej_is_infinity(&pt) → return 0`).

  `tweakPoint p P root = none` therefore covers both reject modes
  (tweak ≥ n: TPR-017; `P + t·G = ∞`: the infinity reject), and
  `tweakPoint p P root = some (x, y)` covers the accept mode —
  `x = x(Q)`, `y = y(Q)` — with the output-key equation EXACTLY Core's
  comparison form: `x =? q ∧ y parity =? c[0] & 1`
  (`secp256k1_memcmp_var(&pk_expected32, tweaked_pubkey32, 32) == 0 &&
  secp256k1_fe_is_odd(&pk.y) == tweaked_pk_parity`,
  extrakeys_main_impl.h:159-160). The tweak scalar reduction mod n
  inside libsecp (`secp256k1_scalar_set_b32` truncates to the order) is
  modeled by the `n ≤ t → none` reject — same verdict, since Core never
  observes the reduced scalar (only the accept/reject bit).

  Validation-side `P` = `liftX(int(p))` (BIP341:69) — the even-y lift
  (`xonly_pubkey_parse` = `fe_set_b32_limit` + `ge_set_xo_var(0)` =
  even-y + subgroup check, extrakeys_main_impl.h:29-49) — is the
  caller's job (Unit 3: `VerifyTaprootCommitment`), NOT this def's: the
  ''negate before tweak for odd y'' dance is signing-side only
  (`keypair_xonly_tweak_add` negates sk for odd-y pk);
  `secp256k1_xonly_pubkey_load` here works on the even-y point.

## Rule rows (spec/db/rules.yaml TPR block)

TPR-015 (TapTweak hash), TPR-017 (tweak range check),
TPR-083 (null-root tweak) live on this module's defs;
TPR-016 (commitment equation) is pinned by Unit 3
(`Taproot/Verify.lean`).

## Status: X03 Unit 1 — all theorems sorry-free, axioms pinned at the
bottom (footprints ⊆ the standard trio `[propext, Classical.choice,
Quot.sound]`, X02 style). No `sorry`, no `native_decide`.
-/

namespace Bitcoin.Crypto.Taproot

open Bitcoin.Crypto.Curve.Secp
open Bitcoin.Crypto.Schnorr (taggedHash tagTapTweak taggedHash_size append_size)

/-! ## The TapBranch tag -/

/-- BIP341 TapBranch tag (bip-0341 §3, `ComputeTapbranchHash`;
`HASHER_TAPBRANCH` interpreter.cpp:1887-1896). The one taproot tag X02's
`Schnorr/TaggedHash.lean` does not carry (X02 needed
TapTweak/TapLeaf/TapSighash for its lanes; TapBranch is first used by
X03 Unit 2's merkle walk). -/
def tagTapBranch : ByteArray := "TapBranch".toUTF8

/-! ## TapTweak (TPR-015 / TPR-083) -/

/-- `taptweak p root` = `taggedHash("TapTweak", p ‖ root)` — Core
`XOnlyPubKey::ComputeTapTweakHash(merkle_root)` (pubkey.cpp:246-255):
`(HashWriter{HASHER_TAPTWEAK} << m_keydata << *merkle_root).GetSHA256()`
= `SHA256(SHA256("TapTweak") ‖ SHA256("TapTweak") ‖ p ‖ root)`.
`root = some k_m` = the consensus (script-path) lane (32 raw bytes,
AS-IS); `root = none` = the `merkle_root == nullptr` wallet branch
(pubkey.cpp:248-251, `hashTapTweak(p)` alone = BIP341:158's
"commit to an unspendable script path"). TPR-015 + TPR-083. -/
@[rule "TPR-015", rule "TPR-083"]
def taptweak (p : ByteArray) (root : Option ByteArray) : ByteArray :=
  match root with
  | none => taggedHash tagTapTweak p
  | some root => taggedHash tagTapTweak (p ++ root)

/-- The tweak scalar `t = int_from_bytes(taptweak p root)` (BIP341:184)
— the 32 digest bytes BIG-ENDIAN (BIP340 `int_from_bytes`; libsecp
`secp256k1_scalar_set_b32` reads the 32 bytes big-endian, scalar.h).
Used raw (no mod-n reduction) so the TPR-017 overflow reject
(`t ≥ n`) is a first-class verdict branch, exactly libsecp's
`tweak_add` overflow check. -/
def tweakScalar (p : ByteArray) (root : Option ByteArray) : Nat :=
  bytesToNatBE (taptweak p root)

/-! ## The output-key equation `Q = P + int(t)·G` (TPR-016/TPR-017) -/

/-- `tweakPoint p P root` = the output key `Q` — or `none` = libsecp
reject. EXACTLY Core's `secp256k1_xonly_pubkey_tweak_add_check`
comparison (extrakeys_main_impl.h:142-161) with the two reject modes
collapsed onto the point at infinity:

* `n ≤ tweakScalar p root` → `none` (TPR-017: the tweak overflows the
  group order);
* `addP P (mulP (tweakScalar p root) G) = none` (i.e. `P + t·G = ∞`)
  → `none` (the `gej_is_infinity` reject, eckey_impl.h:28-30);
* otherwise `some Q` with `Q = P + int(t)·G` — Unit 3 compares
  `x(Q) =? q` and `y(Q) parity =? c[0] & 1` (the `memcmp + fe_is_odd`
  pair, extrakeys_main_impl.h:159-160).

Note the reject mode and `Q = ∞` coincide by construction: `none` IS
the point at infinity on the `RawPoint = Option (Nat × Nat)` curve
layer, so `tweakPoint p P root = none` is the single Core fail bit. -/
@[rule "TPR-016", rule "TPR-017"]
def tweakPoint (p : ByteArray) (P : RawPoint) (root : Option ByteArray) :
    RawPoint :=
  if n ≤ tweakScalar p root then none
  else addP P (mulP (tweakScalar p root) G)

/-! ## Size/domain theorems -/

/-- The tweak hash is a 32-byte digest (composition of X02's
`taggedHash_size`; TPR-015's hash-domain size contract). -/
theorem taptweak_size (p : ByteArray) (root : Option ByteArray) :
    (taptweak p root).size = 32 := by
  cases root with
  | none => exact taggedHash_size _ _
  | some root => exact taggedHash_size _ _

/-- The `none` (wallet / null-merkle-root) branch is the bare tagged
hash `hashTapTweak(p)` (pubkey.cpp:248-251; BIP341:158) — definitional
(TPR-083's statement). -/
theorem taptweak_none (p : ByteArray) :
    taptweak p none = taggedHash tagTapTweak p := rfl

/-- The `some` (consensus script-path) branch is the tagged hash of
`p ‖ root` (pubkey.cpp:252-254; BIP341:77) — definitional (TPR-015's
statement). -/
theorem taptweak_some (p root : ByteArray) :
    taptweak p (some root) = taggedHash tagTapTweak (p ++ root) := rfl

/-! ## Verdict theorems (TPR-016/TPR-017) -/

/-- TPR-017 (tweak range check, reject side): a tweak digest whose
big-endian value is ≥ the group order is rejected — `tweakPoint` is
`none` (libsecp `xonly_pubkey_tweak_add` overflow reject). The
contrapositive is `tweakPoint_some` below: an accepted tweak is `< n`. -/
theorem tweakPoint_overflow (p : ByteArray) (P : RawPoint)
    (root : Option ByteArray) (h : n ≤ tweakScalar p root) :
    tweakPoint p P root = none := by
  unfold tweakPoint
  split
  · rfl
  · rename_i hk
    exact absurd h hk

/-- TPR-016 (commitment equation) + TPR-017 (accept side): an accepted
output key exists exactly when the tweak is in range, and then
`Q = some (x, y) = P + int(t)·G` pointwise — Core's
`secp256k1_xonly_pubkey_tweak_add_check` succeeded and the comparison
values are `x(Q)`, `y(Q)`. -/
theorem tweakPoint_some (p : ByteArray) (P : RawPoint)
    (root : Option ByteArray) (x y : Nat)
    (h : tweakPoint p P root = some (x, y)) :
    tweakScalar p root < n ∧
      addP P (mulP (tweakScalar p root) G) = some (x, y) := by
  unfold tweakPoint at h
  split at h
  · exact absurd h (by simp)
  · rename_i hk
    exact ⟨Nat.lt_of_not_ge hk, h⟩

/-- TPR-016/TPR-017 (reject totality): `tweakPoint = none` means the
tweak overflowed the group order OR `P + t·G` is the point at infinity
— the two `secp256k1_xonly_pubkey_tweak_add` failure modes
(extrakeys_main_impl.h:151-153, eckey_impl.h:28-30). The verdict is a
total function of `(p, P, root)`: no third reject mode exists. -/
theorem tweakPoint_none (p : ByteArray) (P : RawPoint)
    (root : Option ByteArray) (h : tweakPoint p P root = none) :
    n ≤ tweakScalar p root ∨
      addP P (mulP (tweakScalar p root) G) = none := by
  unfold tweakPoint at h
  split at h
  · rename_i hk
    exact Or.inl hk
  · exact Or.inr h

/-- A zero tweak is accepted (TPR-016 companion: `t = 0` is in range;
libsecp accepts zero tweaks — only OVERFLOW and infinity reject) and
the output key IS the internal key: `P + 0·G = P + 𝒪 = P`
(`secp256k1_ecmult(&pt, &pt, &scalar_one, tweak)` with zero tweak =
identity; `eckey_impl.h:26`). -/
theorem tweakPoint_zero (p : ByteArray) (P : RawPoint)
    (root : Option ByteArray) (h : tweakScalar p root = 0) :
    tweakPoint p P root = P := by
  unfold tweakPoint
  rw [h]
  have hn : ¬ n ≤ 0 := by have := n_pos; omega
  split
  · rename_i hk
    exact absurd hk hn
  · show addP P (mulP 0 G) = P
    rw [mulP_zero, addP_none]

/-- The `RawPoint` coordinate invariant is preserved: `tweakPoint`'s
output is either `none` (invariant trivially) or a canonical
representative pair (`addP`/`mulP` outputs, `Curve.Secp.addP_ok` /
`mulP_ok`; `G` is on-curve with `Gx < P`, `Gy < P`). W14 discipline:
no primality, no `sorryAx` — representative bookkeeping only. -/
theorem tweakPoint_ok (p : ByteArray) (P : RawPoint)
    (root : Option ByteArray) (hp : RawOK P) :
    RawOK (tweakPoint p P root) := by
  unfold tweakPoint
  split
  · exact trivial
  · exact addP_ok P _ hp (mulP_ok _ (RawOK.some Gx_lt Gy_lt) _)

/-- Determinism / totality (W14b discipline): `tweakPoint` is a pure
function of `(p, P, root)` — equal inputs, equal verdicts. Consensus
requirement (BIP341 §design): the taproot commitment check is
completely specified at the byte level. -/
theorem tweakPoint_congr (p₁ p₂ : ByteArray) (P₁ P₂ : RawPoint)
    (root₁ root₂ : Option ByteArray)
    (hp : p₁ = p₂) (hP : P₁ = P₂) (hr : root₁ = root₂) :
    tweakPoint p₁ P₁ root₁ = tweakPoint p₂ P₂ root₂ := by
  subst hp; subst hP; subst hr; rfl

/-! ## Axiom footprints (X02 style: `#guard_msgs in #print axioms`)

All sorry-free; footprints ⊆ the standard trio
`[propext, Classical.choice, Quot.sound]` (X10 convention: `choice`
inherited from the generalized layers — `simp`/`omega`-closured
structural proofs), pinned by the guard block below.
-/

/-- info: 'Bitcoin.Crypto.Taproot.taptweak_size' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms taptweak_size

/-- info: 'Bitcoin.Crypto.Taproot.taptweak_none' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms taptweak_none

/-- info: 'Bitcoin.Crypto.Taproot.taptweak_some' depends on axioms: [propext, Quot.sound] -/
#guard_msgs in #print axioms taptweak_some

/-- info: 'Bitcoin.Crypto.Taproot.tweakPoint_overflow' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms tweakPoint_overflow

/-- info: 'Bitcoin.Crypto.Taproot.tweakPoint_some' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms tweakPoint_some

/-- info: 'Bitcoin.Crypto.Taproot.tweakPoint_none' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms tweakPoint_none

/-- info: 'Bitcoin.Crypto.Taproot.tweakPoint_zero' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms tweakPoint_zero

/-- info: 'Bitcoin.Crypto.Taproot.tweakPoint_ok' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms tweakPoint_ok

/-- info: 'Bitcoin.Crypto.Taproot.tweakPoint_congr' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms tweakPoint_congr

end Bitcoin.Crypto.Taproot
