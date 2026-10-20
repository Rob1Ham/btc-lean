---
# Cell tapscript/C-L-w32-tap-extslice
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 805c804
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
lean_model_rev: 4d62a97e551082a69b13f495365bff0a903b0c99
legs: C, L
cell: C-L-w32-tap-extslice
family: tapscript
tool_status: both-green (symbolic; all 256-bit tapleaf hashes, all 32-bit codesep positions, both SigVersions)
precondition: |
  - SigVersion in {TAPROOT (0), TAPSCRIPT (1)}.  In Core the switch at
    interpreter.cpp:1494-1508 sets ext_flag = 0 for TAPROOT and ext_flag = 1
    plus key_version = 0 for TAPSCRIPT; no other value reaches this code.
  - m_tapleaf_hash_init and m_codeseparator_pos_init are true.  This is the
    caller contract that Core *asserts* at interpreter.cpp:1571/1574; a
    violated contract is an abort, not a consensus-observable path, so it
    is outside the cell (the Lean extSlice returns `none` there).
  - The tapleaf hash is an arbitrary 32-byte value (four 64-bit words); its
    computation (TaggedHash("TapLeaf", ...)) is SCR-146 and not claimed.
  - codeseparator_pos is an arbitrary 32-bit value.
postcondition: |
  - TAPSCRIPT: the appended slice is exactly
       bytes 0..31  = tapleaf_hash, verbatim (big-endian word order as the
                      uint256 representation)
       byte  32     = 0x00 (key_version)
       bytes 33..36 = codeseparator_pos, 4 little-endian bytes
    and no other byte is written; total length 37 (length marker in the
    harness observable, see trust_note).
  - TAPROOT: the slice is empty (five zero words).
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-164
scr_row_coverage: full — SCR-164's three named appends (tapleaf_hash,
  key_version = 0, codeseparator_pos) are proved byte-for-byte for every
  input in the domain and for both SigVersions.  What is not re-proved is
  the hash *value* (SCR-146) and the position of this slice inside the full
  SigMsg (TPR-033 / SCR-169); the slice is appended last by construction at
  interpreter.cpp:1568-1576, which is the cited range.
patches: none
source_citations:
  - "interpreter.cpp:1494-1508 (TAPROOT ext_flag=0; TAPSCRIPT ext_flag=1, key_version=0)"
  - "interpreter.cpp:1568-1576 (TAPSCRIPT extension slice / extSlice)"
  - "interpreter.cpp:1517-1522 (key_version must be 0 for 32-byte keys)"
  - "spec/core/Bitcoin/Crypto/Taproot/Sighash.lean:237-243 (extSlice)"
  - "spec/core/Bitcoin/Data/Tx.lean (serU8 / serU32 little-endian)"
  - "spec/core/Bitcoin/Crypto/Taproot/Sighash.lean:63-66 (uint256 is 32 bytes)"
trust_note: >
  C is a line-cited slice of SignatureHashSchnorr, not the whole function.
  The serializer convention it relies on (uint256 = 32 raw bytes, uint32_t =
  4 little-endian bytes, no CompactSize prefix for either) is the cited
  lines' HashWriter contract and is not itself proved here.  The slice is
  expressed at word granularity because Alive2 rejects sret structs; the L
  leg builds the same 37 bytes as an explicit byte array and packs them, so
  the two legs are independent expressions of the appends.  The length
  marker in word 4's top byte is cell harness, not preimage content.  L is
  a reviewed transliteration of the Lean extSlice equation (twin/ops_ir.py
  has no sighash handler).  R is not attempted.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256
mutant: "swap key_version and the first codesep byte, or write codesep big-endian; expect both tools to fail"
mutant_site: "src/c_leaf.cpp ext_word4 / src/l_leaf.cpp build"
---

# Cell `tapscript/C-L-w32-tap-extslice`

`cell_ext_w0..w4` observe the five 64-bit words of the 37-byte BIP342
extension slice. Word 4 holds the key_version byte, the four little-endian
codeseparator bytes, and a harness-only length marker.

The C leg is the word-granular expression of
`interpreter.cpp:1568-1576`; the L leg is a byte-level transliteration of
`extSlice` (`Sighash.lean:237-243`). Because they are written at different
granularities, Alive2's successful C↔L check is not syntactic equality.

`scr_row_coverage: full` covers the three appends named by SCR-164. It does
**not** cover TapLeaf tagged hashing (SCR-146), the rest of the preimage
(SCR-169), or the full-message offset (TPR-033).
