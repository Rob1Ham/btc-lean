---
# Cell tapscript/C-L-w32-tap-hashtype
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
lean_model_rev: 4d62a97e551082a69b13f495365bff0a903b0c99
legs: C, L
cell: C-L-w32-tap-hashtype
family: tapscript
tool_status: both-green (symbolic, all 8-bit hashtypes / all 32-bit sig sizes)
precondition: |
  - BIP341 Schnorr checker context; SigVersion TAPSCRIPT/TAPROOT reach the
    checker only after the caller has enforced pubkey.size() == 32.
  - The signature bytes are represented by (sig_size, last_byte) only:
    content and the BIP340 verdict are outside this cell.
  - flags = 0; no tx / execdata field is read by this slice.
  - Hash-type domain: the full 8-bit space (cell_ht_valid,
    cell_output_type) and the full 32-bit signature-size space
    (cell_sig_to_ht).  A signature is a stack element, bounded by
    MAX_SCRIPT_ELEMENT_SIZE (520) in tapscript, so 32 bits is a complete
    model of the reachable sizes.
postcondition: |
  - cell_ht_valid(ht) packs bit0 = "hashtypeValid(ht)", bits 8..15 = the
    error ordinal Core reaches (0 when valid, 46 SCHNORR_SIG_HASHTYPE when
    the preimage construction returns false), bits 16..23 = ht.
  - cell_sig_to_ht(size, last) packs bit0 = error flag, bits 8..15 =
    hashtype (0x00 for size 64, `last` for size 65), bits 16..23 = error
    (45 SCHNORR_SIG_SIZE otherwise; 46 when size 65 and last == 0), bits
    24..31 = Core output_type (SIGHASH_ALL=1 for DEFAULT 0x00, else ht&3).
  - cell_output_type(ht) = 1 for ht == 0, else ht & 3.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-163, SCR-165
scr_row_coverage: full — SCR-163's predicate is evaluated over all 2^8
  hashtype bytes, with the construction-false => SCHNORR_SIG_HASHTYPE
  mapping; SCR-165's 64-byte => SIGHASH_DEFAULT => output_type ALL rule is
  evaluated over all 2^32 sizes and all 2^8 trailing bytes, together with
  the 65-byte explicit-byte path and the size-error path.
patches: none
source_citations:
  - interpreter.cpp:1524 (output_type DEFAULT=>ALL ternary)
  - interpreter.cpp:1526 (hashtype validity predicate)
  - interpreter.cpp:1559-1560 (SINGLE output-existence check; not used here)
  - interpreter.cpp:1736-1743 (Schnorr size gate; 64-byte default; explicit 0x00 rejected)
  - interpreter.cpp:1747-1748 (construction failure => SCHNORR_SIG_HASHTYPE)
  - "spec/core/Bitcoin/Crypto/Seam/Entry.lean:146-163 (SIGHASH_DEFAULT, schnorrHashtype)"
  - "spec/core/Bitcoin/Crypto/Taproot/Sighash.lean:150-170 (hashtypeValid, htOutputAll/htNone/htSingle)"
  - "spec/core/Bitcoin/Capstone/RealChecker.lean:124-130 (size/hashtype error mapping)"
  - contract/error_kind.h:86-87 (45 SCHNORR_SIG_SIZE, 46 SCHNORR_SIG_HASHTYPE)
trust_note: >
  C is a line-cited composition of four short Core source slices
  (interpreter.cpp:1524, :1526, :1736-1743, :1747-1748), not the whole
  checker: the signature bytes are reduced to their length and trailing
  byte, and the BIP340 verification is never called by this slice.  L is a
  reviewed transliteration of the Lean equations cited above (the Twin's
  generated op table has no Schnorr handler at model rev 4d62a97, so
  mk_leaf.py cannot emit one).  The packed observables are cell harness.
  Nothing here proves SHA256, TapSighash, or secp256k1: SCR-169 carries the
  preimage/hash lane and remains partial.  R is not attempted.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: "accept hashtype 0x80 (drop the 0x81 lower bound) or treat a 65-byte signature as DEFAULT; expect both tools to fail"
mutant_site: "src/c_leaf.cpp / src/l_leaf.cpp cell_ht_valid / cell_sig_to_ht"
---

# Cell `tapscript/C-L-w32-tap-hashtype`

Two rows, one harness: both are pure byte/length predicates in the BIP341
Schnorr checker.

| SCR | Function | Domain | Claim |
|---|---|---|---|
| SCR-163 | `cell_ht_valid` | all 2^8 hashtypes | valid iff `ht <= 3 || 0x81 <= ht <= 0x83`; invalid ⇒ ordinal 46 |
| SCR-165 | `cell_sig_to_ht` | all 2^32 sizes × 2^8 trailing bytes | 64 ⇒ DEFAULT 0x00; 65 ⇒ explicit byte (0x00 rejected); else 45 |
| SCR-165 | `cell_output_type` | all 2^8 hashtypes | DEFAULT 0x00 ⇒ SIGHASH_ALL (=1), else `ht & 3` |

Alive2 compares the C and L modules directly; SAW verifies **each leg
separately** against the independent Cryptol oracle in `src/cell.cry`, so a
shared mistake cannot pass. See `notes.md` for the scope limits.
