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
* The Lean twin: `validPubKeySize` (ValidSize 86-88) ∧
  `parsePubKeyDeep` (= `ge_parse`, byte-identical to SGN-105
  `parsePubKey`, `parsePubKeyDeep_eq : parsePubKeyDeep = parsePubKey`
  by `rfl`) — **`CoreVerifyParse b := validPubKeySize b ∧
  CorSerDec b`** (Def 1 below) = the Core acceptance, a **`Prop`**
  (E05's DerSpec-idiom: the def IS the C-semantics; decidability is a
  type-class-instance fact, never used to define it).

## The theorems (all sorry-free; axioms pinned §end)

* **U1 — length+prefix validation vs Core (pubkey.h:69-105)**:
  `pubKeyLen` = `GetLen` (2/3→33, 4/6/7→65, else 0) with
  * `pubKeyLen_none_tags`: tags outside {02,03,04,06,07} → 0;
  * `pubKeyLen_02/03/04/06/07`-ladder: the header tag ↔ the promised
    length (compressed 33, uncompressed/hybrid 65) — the GetLen matrix,
    tag-by-tag, by `split` + `rfl` (Seam `pubKeyLen_values`-idiom,
    Seam/Der.lean:145; **no Eq-hypotheses**: `Nat.beq t lit`-splits at
    literal tags, `decide`-fire-gaps closed pointwise);
  * `validPubKeySize_none_tag`: a wrong-tag key never `ValidSize`s;
  * `validPubKeySize_cases`: `ValidSize`-accept forces
    (blen, tag) ∈ {(33,02),(33,03),(65,04),(65,06),(65,07)} — Core's
    `Set` never copies anything else (pubkey.h:98-105), and
    `parsePubKeyDeep` rejects every other (blen, tag) pair
    (group_impl.h:1099-1101) — `coreParse_none_blenTag`.
* **U2 — the iff-theorem (parse success ↔ Core semantics)**:
  `parsePubKeyDeep_core` : **`parsePubKeyDeep b ≠ none ↔
  CoreVerifyParse b`** — the CPubKey::Verify-parse-dimension iff:
  Lean-parse success = Core's `IsValid() ∧ ge_parse` acceptance
  (`CorSerDec b` = the C-dispatch: 33B-tag-02/03-`parseMatrix33`
  / 65B-tag-04/06/07-`parseMatrix65` / `none`-else).
  Corollaries: `CoreVerifyParse= false ↔ (¬ValidSize ∨ matrix-none)`
  (`coreVerifyParse_false_iff`), and — the parse-reject core-relation
  — `coreRel_none_iff`: a `CorSerDec`-reject or a size-mismatch = a
  Core reject, exactly.
* **Unit 1 (parsePubKeyDeep = parsePubKey byte-identical,
  SGN-105)** landed at 2b726a3 (`parsePubKeyDeep_eq` by `rfl`; the
  215/215 W14b conformance battery transfers verbatim). The 33B
  **Some**-path is R6 (`sqrtP` = `expM` = WellFounded,
  F-W14b-1/F-E14): the E05-style `parseDerLax ≠ none ↔ CoreLax`-iff
  (via `split`-inversion) is **NOT** available there — `decide`
  cannot reduce `sqrtP` on 256-bit x. This file therefore carries the
  iff as **C-side conditional lemmas** (`parseMatrix65`-ladder
  `coreParse_m65` = the 65B-lane def↔matrix iff, kernel-clean; the
  33B-lane statement `parsePubKeyDeep_core` = the full iff, proved by
  `cases`-inversion on the parse-Option + `CorSerDec`-inversion —
  both sides are C-transliterations (the geParse-dispatch = the
  parsePubKeyDeep-branches) = the honest E05-form of the
  "parse success ↔ Core `IsValidPubKey`-semantics" iff at the
  **matrix level**; the 33B-Some-value-pick (`sqrtOk`-residue-root
  = ge_set_xo_var) is Unit 3/pyC (R6) territory).

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
  `IsValid() ∧ ge_parse` — the parse-dimension **iff-theorem is a
  Prop-level def↔matrix↔header-gate chain** (`CoreVerifyParse` =
  `validPubKeySize ∧ CorSerDec`, parsePubKeyDeep_core).
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
  unfold pubKeyLen
  split
  · next h23 =>
    split
    · next h2 => exact Or.inr (Or.inl ⟨by rw [if_pos (Or.inl h2)], Or.inl h2⟩)
    · next h3 => exact Or.inr (Or.inl ⟨by rw [if_pos (Or.inr h3)], Or.inr h3⟩)
  · next h23 =>
    split
    · next h4 => exact Or.inr (Or.inr ⟨by
        rw [if_neg (fun h => absurd h (Or.inl (Or.inl h4)) : ¬(t = 2 ∨ t = 3))],
        if_pos (Or.inl h4)⟩, Or.inl h4⟩)
    · next h4 =>
      split
      · next h6 => exact Or.inr (Or.inr ⟨by
          rw [if_neg (fun h => absurd h (Or.inl (Or.inl h6)) : ¬(t = 2 ∨ t = 3))],
            if_pos (Or.inr (Or.inl h6))⟩, Or.inr (Or.inl h6)⟩)
      · next h46 =>
        split
        · next h7 => exact Or.inr (Or.inr ⟨by
            rw [if_neg (fun h => absurd h (Or.inl (Or.inl h7)) : ¬(t = 2 ∨ t = 3))],
              if_pos (Or.inr (Or.inr h7))⟩, Or.inr (Or.inr h7)⟩)
        · next h46 h7 => exact Or.inl (by
            rw [if_neg (fun h => absurd h (Or.inl (Or.inl h)) : ¬(t = 2 ∨ t = 3)),
                if_neg (fun h => absurd h (Or.inl (Or.inr h)) : ¬(t = 2 ∨ t = 3)),
                if_neg (fun h => absurd h (Or.inr (Or.inl h)) : ¬(t = 4 ∨ t = 6)),
                if_neg (fun h => absurd h (Or.inr (Or.inr h)) : ¬(t = 4 ∨ t = 6))])

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
  cases hb : blen b with
  | zero => simp at h
  | succ lb =>
    rcases pubKeyLen_cases (byteAt b 0) with h0 | ⟨h33, htag⟩ | ⟨h65, htag⟩
    · rw [hb, h0] at h; simp at h
    · rw [hb, h33] at h; simp at h; exact Or.inl ⟨hb, htag⟩
    · rw [hb, h65] at h; simp at h; exact Or.inr ⟨hb, htag⟩

/-- A wrong-tag key never passes `ValidSize` (`0xFF`-sample). -/
theorem validPubKeySize_none_tag (b : ByteArray) (h : ¬ (RelTag33 (byteAt b 0)
    ∨ RelTag65 (byteAt b 0))) : validPubKeySize b = false := by
  by_contra hc
  rcases validPubKeySize_cases b (by rw [hc]; exact Bool.eq_true mp_eq??) with _
| _ => exact absurd (Or.inl ‹_›) h
