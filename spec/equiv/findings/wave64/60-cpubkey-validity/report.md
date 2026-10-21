# SCR-112 — CPubKey::Set vs Lean `isValidPubKey`: independent divergence reproduction

**Status: CONFIRMED — the seam predicate is not Core's.** SCR-112's block-mode
false-and-continue **outcome** can be closed independently with the real parse
stage (proved in `tools/lean_witness.lean`), but the **gate-level statement**
cannot be closed with the current `isValidPubKey`: it accepts keys Core
rejects, so `ecdsaVerdict`'s invalid-key branch does not fire for them.

- Worktree: `/tmp/opencode/wave64/60-cpubkey-validity`
- Branch: `wave64/60-cpubkey-validity`, base `5946c02`
- Pinned Core: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
  (`/tmp/opencode/equiv-work/bitcoin`)
- Pinned Lean: `spec/` at the branch base, `leanprover/lean4:v4.35.0`
- No files outside this findings directory were modified.

## 1. The two definitions

### C (pinned Core)

`src/pubkey.h`:

```c++
// :69-76
unsigned int static GetLen(unsigned char chHeader) {
    if (chHeader == 2 || chHeader == 3) return COMPRESSED_SIZE; // 33
    if (chHeader == 4 || chHeader == 6 || chHeader == 7) return SIZE; // 65
    return 0;
}
// :86-88
bool static ValidSize(const std::vector<unsigned char> &vch) {
  return vch.size() > 0 && GetLen(vch[0]) == vch.size();
}
// :98-105
template <typename T> void Set(const T pbegin, const T pend) {
    int len = pend == pbegin ? 0 : GetLen(pbegin[0]);
    if (len && len == (pend - pbegin))
        memcpy(vch, (unsigned char*)&pbegin[0], len);
    else
        Invalidate();          // vch[0] = 0xFF
}
// :194-197
bool IsValid() const { return size() > 0; }   // size() == GetLen(vch[0])
```

`CheckECDSASignature` (`src/script/interpreter.cpp:1701-1706`) constructs the
object first and then asks `IsValid()`:

```c++
CPubKey pubkey(vchPubKey);
if (!pubkey.IsValid())
    return false;
```

So the C predicate over **raw bytes** is exactly `CPubKey::ValidSize` /
`validPubKeySize`: **header shape AND length equality**.

### Lean (pinned seam)

`spec/core/Bitcoin/Crypto/Seam/Der.lean`:

```lean
def pubKeyLen (pk : ByteArray) : Nat :=
  if pk.size = 0 then 0
  else if pk[0]! = 0x02 || pk[0]! = 0x03 then 33
  else if pk[0]! = 0x04 || pk[0]! = 0x06 || pk[0]! = 0x07 then 65
  else 0

def isValidPubKey (pk : ByteArray) : Bool := pubKeyLen pk ≠ 0
```

`pubKeyLen` never compares its result to `pk.size`. `isValidPubKey` is therefore
"the first byte names a format", not "these bytes can become a valid CPubKey".

The repository already contains the **correct** C-faithful twin in
`spec/core/Bitcoin/Crypto/EcdsaDeep/PubKeyParse.lean:135-136`:

```lean
def validPubKeySize (b : ByteArray) : Bool :=
  blen b > 0 && pubKeyLen (byteAt b 0) == blen b
```

The seam simply does not use it at `ecdsaVerdict` (`Seam/Entry.lean:52`).

## 2. Smallest witness and exact outcomes

### Minimal witness (1 byte)

`pk = [0x02]` — a compressed header that promises 33 bytes.

| Side | Exact evaluation |
|---|---|
| C `CPubKey::Set` | `pend-pbegin = 1`, `GetLen(0x02) = 33`, `33 != 1` → `Invalidate()` (stored `vch[0] := 0xFF`) |
| C `CPubKey::IsValid()` | `size() = GetLen(0xFF) = 0` → **false** |
| C `CheckECDSASignature` | **false** at `interpreter.cpp:1704-1706`, before any sig/EC work |
| C `CPubKey::Verify` | **false** at `pubkey.cpp:284-285` (`!IsValid()`) |
| Lean `pubKeyLen [0x02]` | **33** |
| Lean `isValidPubKey [0x02]` | **true** (`33 ≠ 0`) |
| Lean `validPubKeySize [0x02]` | **false** (`33 ≠ 1`) |
| Lean `parsePubKey [0x02]` | **none** (length/shape gate) |

This one-byte vector is the minimum possible witness (empty is rejected by both;
no header can be zero bytes). `spec/core/Bitcoin/Crypto/Seam/Tests.lean:106`
currently *asserts the divergent value*: `isValidPubKey (fromHex "02") = true`.

### Requested illustrative witness (2 bytes)

`pk = [0x04, 0x00]` — uncompressed header that promises 65 bytes.

| Side | Exact evaluation |
|---|---|
| C `CPubKey::Set` | `GetLen(0x04) = 65 ≠ 2` → `Invalidate()` |
| C `CPubKey::IsValid()` | **false** |
| C `CheckECDSASignature` | **false** |
| Lean `pubKeyLen` | **65** |
| Lean `isValidPubKey` | **true** |
| Lean `validPubKeySize` | **false** |
| Lean `parsePubKey` | **none** |

With a non-empty signature and block flags (NULLFAIL off; Core's mandatory
flags do not include NULLFAIL, `src/policy/policy.h:104-111`), C proceeds:
`EvalChecksigPreTapscript` returns `true` with `fSuccess=false`
(`interpreter.cpp:345-356`), and `OP_CHECKSIG` pops the operands and pushes
`vchFalse` (`interpreter.cpp:1069-1092`) — i.e. **push false and continue**.
Under policy NULLFAIL (`policy.h:118-130`) the same input instead aborts with
`SCRIPT_ERR_SIG_NULLFAIL`. A valid-DER non-empty signature (as in the witness)
also satisfies the block-active DERSIG gate (`tools/lean_witness.lean` proves
`checkSigEncoding ... sigOk = none` with `dersig := true`).

For the Lean side the checker verdict is **not determined by the gate** for
this key: `ecdsaVerdict` skips the gate because `isValidPubKey = true`, then
calls the abstract `verify`. Two concrete evaluations in
`tools/lean_witness.lean`:

```lean
-- abstract oracle: Lean checker returns TRUE for the C-invalid key
ecdsaVerdict (fun _ _ _ => true) ... sigOk pkTwo ... = true

-- real parsePubKey acceptance: Lean checker returns FALSE, same as C
ecdsaVerdict (fun _ pk _ => (parsePubKey pk).isSome) ... sigOk pkTwo ... = false
```

So under the **real** ECDSA parser the end-to-end verdict coincidentally still
matches (the parser rejects every length-mismatched key). Under an abstract or
lax `verify` oracle — the form used by the equivalence cells and several
theorems — Lean can accept a key C rejects.

## 3. Table (10/17 rows diverge)

Generated by `tools/run_all.sh` from the actual Core header and the pinned Lean
definitions; full table in `results/comparison.md`.

| label | len | header | Core Set/IsValid | Lean isValidPubKey | Lean validPubKeySize | agree? |
|---|---:|---|---|---|---|---|
| empty | 0 | (none) | false | false | false | yes |
| badhdr-1B-01 | 1 | 01 | false | false | false | yes |
| **min-1B-02** | 1 | 02 | **false** | **true** | false | **NO** |
| **one-1B-04** | 1 | 04 | **false** | **true** | false | **NO** |
| **two-2B-0400** | 2 | 04 | **false** | **true** | false | **NO** |
| **32B-02** | 32 | 02 | **false** | **true** | false | **NO** |
| 33B-02 | 33 | 02 | true | true | true | yes |
| **34B-02** | 34 | 02 | **false** | **true** | false | **NO** |
| **64B-04** | 64 | 04 | **false** | **true** | false | **NO** |
| 65B-04 | 65 | 04 | true | true | true | yes |
| **66B-04** | 66 | 04 | **false** | **true** | false | **NO** |
| **33B-04** | 33 | 04 | **false** | **true** | false | **NO** |
| **65B-02** | 65 | 02 | **false** | **true** | false | **NO** |
| **33B-06** | 33 | 06 | **false** | **true** | false | **NO** |
| 65B-06 | 65 | 06 | true | true | true | yes |
| 33B-02-G (real G) | 33 | 02 | true | true | true | yes |
| 65B-04-G (real G) | 65 | 04 | true | true | true | yes |

Divergence classes:

- header `02`/`03`: C accepts only len 33; Lean accepts **every** non-empty len.
- header `04`/`06`/`07`: C accepts only len 65; Lean accepts **every** non-empty len.
- invalid headers, empty: both reject.
- canonical lengths: both accept.

`Lean validPubKeySize` agrees with Core on all 17 rows. The divergence is
solely the seam's header-only predicate.

## 4. Impact

**No consensus-accept divergence in the pinned full model.** `parsePubKey` /
`parsePubKeyDeep` require exactly 33-byte `02/03` or 65-byte `04/06/07`, so a
length-mismatched key still reaches `verify` under Lean and is rejected there.
`tools/lean_witness.lean` proves the general bridge
`parsePubKey_none_of_not_validPubKeySize` (axioms:
`propext, Classical.choice, Quot.sound`): every byte string Core's
`validPubKeySize` rejects is also rejected by the real parser. For the real
verifier, C and Lean therefore agree on the final verdict for all C-invalid
keys. This is not a remotely exploitable consensus bug.

**Real proof/coverage integrity gap, not a false alarm.** The consequences are:

1. `ecdsaVerdict`'s gate is weaker than Core's. `ecdsaEntry_badPubKey_false`
   (`Seam/Entry.lean:99-106`) proves false only for `pubKeyLen = 0`, missing
   every length-mismatched key that Core rejects.
2. The SCR-112 cell
   (`spec/equiv/cells/checksig/C-L-checksig-invalid-pubkey/spec.md`) takes
   `pk_valid` as a symbolic input described as "the result of
   `CPubKey::IsValid()`". The cell proves the verdict/push logic for that
   abstract bit, but it does **not** connect the bit to bytes; moreover, the L
   model's byte-level predicate does not compute that bit. The cell's "partial"
   label is correct, for a stronger reason than previously stated.
3. Any theorem/instantiation using an abstract EC oracle can return **true** for
   `[0x02]` or `[0x04,0x00]` whereas Core's checker is unconditionally false
   (`tools/lean_witness.lean`, first `ecdsaVerdict` example).
4. The core test suite encodes the wrong semantics
   (`Seam/Tests.lean:106-110`, `pkC = fromHex "02"` at :128), so regressions
   here will not be caught.
5. `docs/THEOREMS.md:355` anchors SCR-112 to
   `PDW62b.evalChecksigPreTapscript_pk_invalid`. That theorem is about
   `checkPubKeyEncoding` returning a policy error (STRICTENC /
   WITNESS_PUBKEYTYPE) and does not prove the invalid-key
   false-and-continue claim at all. This is a separate row-mapping defect.

## 5. Can SCR-112 be closed for the block-mode false-and-continue path independently?

**Yes for the block-mode outcome with the real parser; no for the current
gate-level model / abstract checker seam.**

### 5.1 Mechanism — independently closable (proved)

The false-and-continue behaviour consumes only a false checker verdict plus
`pol.nullFail = false`; it never inspects why the key is invalid.
`tools/lean_witness.lean` proves:

```lean
theorem block_false_continue ... (hfalse : checker ... = false)
    (hnf : pol.nullFail = false) :
    evalChecksigPreTapscript ... = .ok false
```

No pubkey predicate is involved (axioms: `propext, Quot.sound`). The existing
C/L cell proves the following OP_CHECKSIG push-false/continue step. So the
*path* half is independent of the Set/`isValidPubKey` mismatch.

### 5.2 Outcome with the real parse stage — independently closable (proved)

`parsePubKey_none_of_not_validPubKeySize` (above) plus the mechanism theorem
yields, for **every** C-invalid raw key:

```lean
theorem block_path_core_invalid_realparse
    ... (hinvalid : validPubKeySize pk = false) ...
    (hnf : pol.nullFail = false) :
    evalChecksigPreTapscript flags pol
      (ecdsaChecker parseOnlyVerify sighash hasAmount) ... = .ok false
```

`parseOnlyVerify` models the real verifier's parse stage; for a C-invalid key
the ECDSA stage is unreachable, so the checker verdict is false. This closes
SCR-112's block-mode false-and-continue **outcome** without using
`isValidPubKey` at all (axioms: `propext, Classical.choice, Quot.sound`). The
theorem lives in the findings artifact; banking it in core would not require
changing the gate definition.

### 5.3 What cannot be closed as stated

The current model's gate is not Core's predicate:

- `ecdsaVerdict` calls `isValidPubKey` (`Seam/Entry.lean:52`), and both
  witnesses satisfy `isValidPubKey = true`. Therefore
  `block_path_lean_invalid` — whose hypothesis is `isValidPubKey pk = false` —
  cannot be instantiated for them. It closes the path only for header-invalid
  keys, not the length-invalid class Core rejects.
- The SCR-112 cell takes `pk_valid` as a symbolic input described as the
  result of `CPubKey::IsValid()`. The L leg's `pk_valid=false` branch is valid
  for that abstract bit, but nothing connects the bit to raw-byte
  `CPubKey::Set`; for the L model, the bit is not computed by
  `isValidPubKey` on these bytes.
- Under an abstract `verify` oracle, Lean returns **true** for `[0x02]` /
  `[0x04,0x00]` while Core returns false (proved example). Several proof
  consumers take `verify` abstractly.
- The row's cited Lean target `PDW62b.evalChecksigPreTapscript_pk_invalid`
  proves the policy `checkPubKeyEncoding` abort (STRICTENC /
  WITNESS_PUBKEYTYPE), not the invalid-key false-and-continue claim.

So SCR-112 can be closed in one of these forms:

1. **Outcome closure with a real-parse checker (already demonstrated here):**
   state the theorem over `validPubKeySize pk = false` and a checker whose
   `verify` rejects unparseable keys, as in
   `block_path_core_invalid_realparse`. This is the cleanest independent
   closure and does not require resolving the gate definition.
2. **Definitional fix (preferred for the model):** replace `isValidPubKey pk`
   with `validPubKeySize pk` (or `0 < pk.size ∧ pubKeyLen pk = pk.size`) in
   `Seam/Der.lean`, update the docstring/tests, and re-check the `hpk`
   theorems. All C-valid keys still satisfy the strengthened predicate, so
   the valid-key theorems survive; `ecdsaEntry_badPubKey_false` then covers
   the full C-invalid class and composes with `block_false_continue` without
   needing a parse-stage argument.
3. **Weaker restatement:** state SCR-112 with an explicit
   `validPubKeySize pk = false` hypothesis and a separate bridge theorem; do
   not claim it for `isValidPubKey`.
4. **Not acceptable:** closing SCR-112 by citing the current symbolic
   `pk_valid` cell as if it were the byte-level C predicate, or citing
   `PDW62b.evalChecksigPreTapscript_pk_invalid` as the false-and-continue
   proof.

Option 2 is a small core change but outside this task's write scope; this
report records the required fix rather than editing shared core files.

## 6. Reproduction

```bash
cd spec/equiv/findings/wave64/60-cpubkey-validity
./tools/run_all.sh
cat results/comparison.md
```

Artifacts:

- `tools/c_cpubkey_validity.cpp` — includes the **actual** pinned
  `src/pubkey.h`; exercises `CPubKey::ValidSize`, `CPubKey::Set` via the
  span/iterator constructor, `CPubKey::IsValid`, and `size()`.
- `tools/lean_witness.lean` — pinned Lean predicates, divergence witnesses,
  abstract-vs-real verifier examples, and the conditional block-path theorem.
- `tools/run_c.sh`, `tools/run_lean.sh`, `tools/compare.py`,
  `tools/run_all.sh`.
- `results/c_table.txt`, `results/lean_table.txt`,
  `results/comparison.md`, `results/c_commit.txt`,
  `results/lean_stderr.txt` (empty on success).

Observed environment: g++ 13.3.0, Lean 4.35.0, Core
`cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`.
