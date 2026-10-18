import Bitcoin.Crypto.EcdsaDeep.PubKeyParse
import Bitcoin.Crypto.Ecdsa.Der

/-!
# [E07] PubKeyCor — Units 1b/2: the Core-fidelity iff-theorems of
# `parsePubKeyDeep` (the E07 pubkey-parse crown, E05-DerSpec-pattern)

**Bitcoin Core @ `cce32b168`** (pin verified by E05; the parse-relevant
sites, all anchors in the E05-archived bytes
`spec/db/findings-dl/E05-anchors/`):

* `CPubKey::Verify` — **pubkey.cpp:283-294**: `IsValid()` →
  `secp256k1_ec_pubkey_parse(ctx, &pubkey, vch, size())`
  (pubkey.cpp:288). **`CPubKey::Verify` (parse dimension) accepts `vch`
  iff `IsValid() ∧ ge_parse(vch) accepts`** — `IsValid`/`ValidSize`/`Set`
  (pubkey.h:79-105) = the length+prefix validation
  (`GetLen vch[0] = size`, else `Invalidate`), `ge_parse`
  (secp256k1.c:265-281 → group_impl.h:1084-1102) = the
  compressed/uncompressed/hybrid point-parsing.
* The Lean twin: `validPubKeySize` (ValidSize 86-88) and
  `parsePubKeyDeep` (= `ge_parse`, byte-identical to SGN-105
  `parsePubKey`, `parsePubKeyDeep_eq : parsePubKeyDeep = parsePubKey`
  by `rfl`). The combined acceptance predicate
  `CoreVerifyParse b := validPubKeySize b ∧ CorSerDec b` is **not**
  defined here; see the U2 note below.

## The theorems (U1 only; sorry-free; axioms pinned §end)

This module currently proves the **U1** layer — the CPubKey header
(`GetLen`/`ValidSize`) matrix — and nothing above it:

* `pubKeyLen_cases`: every tag is either invalid (`GetLen = 0`) or
  one of the five header shapes;
* `pubKeyLen_none_tags`: tags outside {02,03,04,06,07} → 0;
* `pubKeyLen_02/03/04/06/07`-ladder: the header tag ↔ the promised
  length (compressed 33, uncompressed/hybrid 65);
* `pubKeyLen_FF`: `Invalidate`'s marker tag has `GetLen = 0`;
* `validPubKeySize_none_tag`: a wrong-tag key never `ValidSize`s;
* `validPubKeySize_cases`: `ValidSize`-accept forces
  (blen, tag) ∈ {(33,02),(33,03),(65,04),(65,06),(65,07)} — Core's
  `Set` never copies anything else (pubkey.h:98-105).

**U2 is not present.** Earlier revisions of this header advertised a
`CoreVerifyParse`/`CorSerDec` iff (`parsePubKeyDeep_core`), its
false-iff corollary and `coreRel_none_iff`; those declarations never
existed (and the file did not elaborate). The claims are removed
rather than left dangling. The parse-vs-Core-matrix equivalence
remains an open proof obligation; it is recorded in
`docs/RESIDUALS.md` as an E07 residual. The 33-byte Some-path is the
R6 lane (`sqrtP = expM`), so a total iff would in any case have to
split into a kernel-decidable matrix half and an R6 half.

* **Unit 1 (parsePubKeyDeep = parsePubKey byte-identical,
  SGN-105)** is in the core module (`parsePubKeyDeep_eq` by `rfl`; the
  215/215 W14b conformance battery transfers verbatim). The 33-byte
  Some-path and the 65-byte lane are exercised by
  `BitcoinProofs.EcdsaDeep.PubKeyMatrix`, whose 33-byte Some rows are
  documented there as R6.

## R6-legend (honest kernel-boundary map, D-004/D2)

* `parseMatrix65`-ladder + all `blen`/`tag`-gates + `onCurveN`
  (mulM-GMP) = **kernel-decidable** (S15-M4/M6; PubKeyCorVec rows).
* 33B-lane = R6 (`sqrtP`); `decide`-rows never cross it (x≥P/gates
  short-circuit first; Some-paths = pyC-TRUTH rows only).
* ser-shape rows (serUncompressed/serHybrid on literals) = **R6b**
  (F-Y09-001 echo: `Array.map`/`++`-opacity) — see PubKeyCorProbe.

## Findings (E07.md)

* **F-E07-001** (Unit 1): `pubkey.cpp` @cce32b168 has NO GetLen/hybrid
  parse — the length+prefix validation lives in `pubkey.h`
  (GetLen/Set/ValidSize) + `group_impl.h::ge_impl_parse` (the hybrid
  parity check 1094-1096) + `secp256k1.c:265-281`.
* **F-E07-002** (this file): `CPubKey::Verify` (pubkey.cpp:283-294) =
  `IsValid() ∧ ge_parse`. Only the header half (`GetLen`/`ValidSize`)
  is proved here; the parse-dimension iff (`CoreVerifyParse` =
  `validPubKeySize ∧ CorSerDec`, `parsePubKeyDeep_core`) was advertised
  but never landed and its claim has been removed (see the U2 note).
* **F-E07-003** (PubKeyCorProbe): ser-shape `decide`-BLOCKED
  (Array-map/++-opacity = F-Y09-001/F-S02-003 echo) — R6b-wall.
* **F-E07-004** (HYP-risk list): NO Eq-hypotheses in this file (the
  Eq-list §end = every `Eq`-occurrence is `bEq`/`plit`-internal);
  RASMUSSEN-NO = 33-S-literal-splits only.
-/

namespace Bitcoin.Proofs.EcdsaDeep.PubKeyCor

open Bitcoin.Crypto.EcdsaDeep.PubKeyParse
open Bitcoin.Crypto.Ecdsa.Der

/-! ## U1a — GetLen (pubkey.h:69-76) : the header ↔ length matrix -/

/-- The 33-byte header tags (`SECP256K1_TAG_PUBKEY_EVEN/ODD`:
02 = even-y, 03 = odd-y; **compressed**). -/
def RelTag33 (t : Nat) : Prop := t = 0x02 ∨ t = 0x03

/-- The 65-byte header tags (`SECP256K1_TAG_PUBKEY_UNCOMPRESSED /
HYBRID_EVEN / HYBRID_ODD`: 04 = uncompressed, 06/07 = hybrid
(06 = even-y, 07 = odd-y)). -/
def RelTag65 (t : Nat) : Prop := t = 0x04 ∨ t = 0x06 ∨ t = 0x07

/-- Every tag with `GetLen ≠ 0` is a 33- or 65-tag
(`GetLen`-exhaustiveness, pubkey.h:69-76). -/
theorem pubKeyLen_cases (t : Nat) :
    pubKeyLen t = 0 ∨ (pubKeyLen t = 33 ∧ RelTag33 t)
    ∨ (pubKeyLen t = 65 ∧ RelTag65 t) := by
  unfold pubKeyLen RelTag33 RelTag65 compressedSize uncompressedSize
  by_cases h2 : t = 2
  · subst h2; simp
  by_cases h3 : t = 3
  · subst h3; simp
  by_cases h4 : t = 4
  · subst h4; simp
  by_cases h6 : t = 6
  · subst h6; simp
  by_cases h7 : t = 7
  · subst h7; simp
  · simp [h2, h3, h4, h6, h7]

/-- Tags outside the five valid headers give `GetLen = 0` (Core:
`Invalidate`-territory, pubkey.h:79-82). -/
theorem pubKeyLen_none_tags (t : Nat) (h : ¬ (RelTag33 t ∨ RelTag65 t)) :
    pubKeyLen t = 0 := by
  rcases pubKeyLen_cases t with h0 | ⟨h33, htag⟩ | ⟨h65, htag⟩
  · exact h0
  · exact absurd (Or.inl htag) h
  · exact absurd (Or.inr htag) h

/-- `GetLen 0x02 = 33` (compressed even-y). -/
theorem pubKeyLen_02 : pubKeyLen 0x02 = 33 := by decide
/-- `GetLen 0x03 = 33` (compressed odd-y). -/
theorem pubKeyLen_03 : pubKeyLen 0x03 = 33 := by decide
/-- `GetLen 0x04 = 65` (uncompressed). -/
theorem pubKeyLen_04 : pubKeyLen 0x04 = 65 := by decide
/-- `GetLen 0x06 = 65` (hybrid even-y). -/
theorem pubKeyLen_06 : pubKeyLen 0x06 = 65 := by decide
/-- `GetLen 0x07 = 65` (hybrid odd-y). -/
theorem pubKeyLen_07 : pubKeyLen 0x07 = 65 := by decide

/-- The wrong tags give `GetLen = 0` (a sample; the full lattice is
`pubKeyLen_none_tags`). `0xFF` = `CPubKey::Invalidate`'s marker
(pubkey.h:79-82). -/
theorem pubKeyLen_FF : pubKeyLen 0xFF = 0 := by decide

/-! ## U1b — ValidSize/Set (pubkey.h:86-105) : the CPubKey header gate -/

/-- A `ValidSize`-accepted key has one of the five (length, tag)
header shapes — Core's `CPubKey::Set` (pubkey.h:98-105) copies
nothing else (a mismatched header/length pair never becomes a valid
CPubKey). -/
theorem validPubKeySize_cases (b : ByteArray) (h : validPubKeySize b = true) :
    (blen b = 33 ∧ RelTag33 (byteAt b 0))
    ∨ (blen b = 65 ∧ RelTag65 (byteAt b 0)) := by
  unfold validPubKeySize at h
  simp only [Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at h
  obtain ⟨hbpos, hlen⟩ := h
  cases hb : blen b with
  | zero => simp [hb] at hbpos
  | succ lb =>
    rcases pubKeyLen_cases (byteAt b 0) with h0 | ⟨h33, htag⟩ | ⟨h65, htag⟩
    · rw [hb, h0] at hlen; simp at hlen
    · exact Or.inl ⟨by omega, htag⟩
    · exact Or.inr ⟨by omega, htag⟩

/-- A wrong-tag key never passes `ValidSize` (`0xFF`-sample). -/
theorem validPubKeySize_none_tag (b : ByteArray) (h : ¬ (RelTag33 (byteAt b 0)
    ∨ RelTag65 (byteAt b 0))) : validPubKeySize b = false := by
  cases hv : validPubKeySize b with
  | false => rfl
  | true =>
    rcases validPubKeySize_cases b hv with ⟨_, htag⟩ | ⟨_, htag⟩
    · exact absurd (Or.inl htag) h
    · exact absurd (Or.inr htag) h

/-! ## Axiom pins (U1) -/

/-- info: 'Bitcoin.Proofs.EcdsaDeep.PubKeyCor.pubKeyLen_cases' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms pubKeyLen_cases

/-- info: 'Bitcoin.Proofs.EcdsaDeep.PubKeyCor.pubKeyLen_none_tags' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms pubKeyLen_none_tags

/-- info: 'Bitcoin.Proofs.EcdsaDeep.PubKeyCor.pubKeyLen_02' does not depend on any axioms -/
#guard_msgs in #print axioms pubKeyLen_02

/-- info: 'Bitcoin.Proofs.EcdsaDeep.PubKeyCor.pubKeyLen_03' does not depend on any axioms -/
#guard_msgs in #print axioms pubKeyLen_03

/-- info: 'Bitcoin.Proofs.EcdsaDeep.PubKeyCor.pubKeyLen_04' does not depend on any axioms -/
#guard_msgs in #print axioms pubKeyLen_04

/-- info: 'Bitcoin.Proofs.EcdsaDeep.PubKeyCor.pubKeyLen_06' does not depend on any axioms -/
#guard_msgs in #print axioms pubKeyLen_06

/-- info: 'Bitcoin.Proofs.EcdsaDeep.PubKeyCor.pubKeyLen_07' does not depend on any axioms -/
#guard_msgs in #print axioms pubKeyLen_07

/-- info: 'Bitcoin.Proofs.EcdsaDeep.PubKeyCor.pubKeyLen_FF' does not depend on any axioms -/
#guard_msgs in #print axioms pubKeyLen_FF

/-- info: 'Bitcoin.Proofs.EcdsaDeep.PubKeyCor.validPubKeySize_cases' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms validPubKeySize_cases

/-- info: 'Bitcoin.Proofs.EcdsaDeep.PubKeyCor.validPubKeySize_none_tag' depends on axioms: [propext, Classical.choice, Quot.sound] -/
#guard_msgs in #print axioms validPubKeySize_none_tag
