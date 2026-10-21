# Wave 64 — task 25-scr-112

Family: checksig. Assigned row: **SCR-112** ("invalid pubkey ⇒
CHECKSIG pushes false and continues in a block").

Pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
Contract: `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
Branch: `wave64/25-scr-112`, cut from `5946c02`. Not pushed. No shared files
edited; this directory is the whole deliverable.

## 1. Result

**F-DIV-w64-112 (proposed global id F-DIV-004): Lean's `isValidPubKey`
accepts header-only keys that Core's `CPubKey::IsValid` rejects.** The
minimal witness is the one-byte pubkey `0x02`:

| side | definition | value on `0x02` |
|---|---|---|
| Core `cce32b168` | `CPubKey(vch).IsValid()` (`src/pubkey.h:194-197`, via `Set` at `:98-105`) | `false` |
| Lean `5946c02` | `Bitcoin.Crypto.Seam.Der.isValidPubKey` (`Der.lean:175`) | `true` |

The divergence is **one-sided**: every byte string Core accepts is accepted
by Lean (`core_valid_imp_lean_valid`), so Lean's predicate is a strict
over-approximation. It is a **gate-value (definitional) divergence**, not a
two-sided verdict split with the real crypto seam: Lean's gate lets `0x02`
through, but the real-crypto seam's downstream `parsePubKey` rejects its
length, so `verifyImpl sig 0x02 msg = false` for all inputs
(`verifyImpl_witness`). With an abstract/other checker that does not
re-parse the length, the Lean verdict can be `true` where Core's is `false`
(the seam's own test suite pins exactly that: `Seam/Tests.lean:106,128-133`).

The block-mode consequence is still worth stating separately, because it is
the row's claim and it depends on the *policy* configuration, not on the
divergence: under block/default policy (`strictEnc = false`,
`witnessPubkeyType = false`, `nullFail = false`) a `false` checker verdict
flows through `evalChecksigPreTapscript` as `.ok false`, and `stepBody`'s
`OP_CHECKSIG` arm pushes `false` and continues. That is kernel-checked for
the witness key, with the pubkey-encoding gate discharged from the policy
bits (`stepBody_pk02_block_false_continue`).

```
F-DIV-w64-112: Lean isValidPubKey is header-only; Core CPubKey::IsValid is size-exact
  legs: C | L
  cell: n/a (witness/report; checksig/C-L-checksig-invalid-pubkey is partial)
  symptom: pk = 0x02 (1 byte). Lean isValidPubKey pk = true; pinned Core
           CPubKey(pk).IsValid() = false (Set sees GetLen(0x02)=33 != 1
           and Invalidate()s). One-sided: Core-valid => Lean-valid.
  evidence:
    - witness/c_core_pubkey.cpp, witness/c_core_pubkey.out  (real pinned
      <pubkey.h>, g++ 13.3.0, Core HEAD checked before compiling)
    - witness/IsValidPubKeyWitness.lean, witness/l_isvalidpubkey.out
      (Lean 4.35.0, kernel `decide` + axiom pins)
    - witness/run.sh, witness/build.txt (pin, sources, hashes)
    - Core: src/pubkey.h:69-76,79-82,86-88,98-105,121,194-197;
      src/script/interpreter.cpp:1704-1706,228-237,1069-1092 @ cce32b168
    - Lean: Der.lean:165,175; EcdsaDeep/PubKeyParse.lean:127,135;
      Seam/Entry.lean:48-59,65-69; Interpreter/Defs.lean:720-742,1033-1047
  disposition: open (model-fidelity / definitional divergence; not a tool gap)
  notes: fix is to make the seam predicate the size-exact port
         `validPubKeySize` (already in EcdsaDeep/PubKeyParse.lean:135) or to
         call it at the ECDSA gate; the seam's own tests (Seam/Tests.lean:
         106-108) currently pin the weak behaviour and must change with it.
```

## 2. The exact witness, both sides

### 2.1 Core side

Compiled against the real pinned header, not an excerpt:

```
CPubKey pubkey(vchPubKey);          // interpreter.cpp:1704
if (!pubkey.IsValid()) return false; // interpreter.cpp:1705-1706
```

`CPubKey::Set` (`src/pubkey.h:98-105`) computes
`len = GetLen(pbegin[0])`; for `0x02`, `GetLen` returns `COMPRESSED_SIZE`
(33), the actual length is 1, so `len == (pend - pbegin)` is false and
`Invalidate()` sets `vch[0] = 0xFF` (`:79-82`). `size()` is
`GetLen(vch[0])` (`:121`), and `GetLen(0xFF) = 0` (`:75`), hence
`IsValid() = size() > 0` is false (`:194-197`).

`witness/c_core_pubkey.out` (driver `c_core_pubkey.cpp`) shows the full
header matrix. The Lean column is a transliteration of
`Seam/Der.lean:165-175`. Four rows — `02 (1B)`, `04 (1B)`,
`02+00*33 (34B)`, `04+00*32 (33B)` — were additionally checked by kernel
`decide` on the Lean side (with `Array.replicate` filling the payload).

```text
pk=02 (1B)                      len=1   core.IsValid=0 core.size=0   lean.isValidPubKey=1 DIVERGE
pk=04 (1B)                      len=1   core.IsValid=0 core.size=0   lean.isValidPubKey=1 DIVERGE
pk=03 (32B)                     len=32  core.IsValid=0 core.size=0   lean.isValidPubKey=1 DIVERGE
pk=02+00*32 (33B)               len=33  core.IsValid=1 core.size=33  lean.isValidPubKey=1 agree
pk=03+00*32 (33B)               len=33  core.IsValid=1 core.size=33  lean.isValidPubKey=1 agree
pk=02+00*33 (34B)               len=34  core.IsValid=0 core.size=0   lean.isValidPubKey=1 DIVERGE
pk=04+00*32 (33B)               len=33  core.IsValid=0 core.size=0   lean.isValidPubKey=1 DIVERGE
pk=04+00*63 (64B)               len=64  core.IsValid=0 core.size=0   lean.isValidPubKey=1 DIVERGE
pk=04+00*64 (65B)               len=65  core.IsValid=1 core.size=65  lean.isValidPubKey=1 agree
pk=06+00*64 (65B)               len=65  core.IsValid=1 core.size=65  lean.isValidPubKey=1 agree
pk=07+00*64 (65B)               len=65  core.IsValid=1 core.size=65  lean.isValidPubKey=1 agree
pk=02+00*64 (65B)               len=65  core.IsValid=0 core.size=0   lean.isValidPubKey=1 DIVERGE
pk=05+00*32 (33B)               len=33  core.IsValid=0 core.size=0   lean.isValidPubKey=0 agree
pk=ff (1B)                      len=1   core.IsValid=0 core.size=0   lean.isValidPubKey=0 agree
pk=empty                        len=0   core.IsValid=0 core.size=0   lean.isValidPubKey=0 agree
```

Seven of fifteen rows diverge, all in the same direction. Note the valid
side is identical, including the hybrid headers `0x06`/`0x07` at 65 bytes:
both Core's `CPubKey` and `validPubKeySize` accept hybrids at this layer
(hybrid rejection is a later policy/encoding question, not part of `Set`).

### 2.2 Lean side

`Seam/Der.lean:165-169` computes `pubKeyLen` from the first byte only;
`:175` defines `isValidPubKey pk := pubKeyLen pk ≠ 0`. It never compares
`pubKeyLen` with `pk.size`. The size-exact port already exists one layer
down: `EcdsaDeep/PubKeyParse.lean:127-136` defines
`validPubKeySize b := blen b > 0 && pubKeyLen (byteAt b 0) == blen b`,
explicitly documented as the port of `CPubKey::ValidSize` (`pubkey.h:86-88`)
and the `Set` consistency check (`:98-105`). The seam does not use it.

`witness/IsValidPubKeyWitness.lean` proves, by kernel `decide`:

```lean
def pk02 : ByteArray := ByteArray.mk #[0x02]

theorem lean_accepts_pk02 : isValidPubKey pk02 = true
theorem core_rejects_pk02 : validPubKeySize pk02 = false
theorem isValidPubKey_diverges :
    isValidPubKey pk02 = true ∧ validPubKeySize pk02 = false
```

and the same for `0x04` (1 byte), `0x02` × 34 bytes, and `0x04` × 33
bytes. `l_isvalidpubkey.out` records the `#eval` table:
`true/false`, `true/false`, `true/false`, `true/false`.

## 3. What is proved, and with which axioms

| theorem | statement | axiom pin |
|---|---|---|
| `isValidPubKey_diverges` | witness: Lean `true`, Core port `false` | none |
| `core_valid_imp_lean_valid` | ∀ `b`, `validPubKeySize b = true → isValidPubKey b = true` | `propext`, `Quot.sound` |
| `checkPubKeyEncoding_pk02_block` | `strictEnc = false ∧ witnessPubkeyType = false → checkPubKeyEncoding … pk02 = none` | `propext` |
| `verifyImpl_witness` | ∀ sig msg, `verifyImpl sig pk02 msg = false` | `propext`, `Classical.choice`, `Quot.sound` |
| `ecdsaEntry_witness_false` | the real-crypto ECDSA entry returns `false` on `pk02` for every sigversion | `propext`, `Classical.choice`, `Quot.sound` |
| `evalChecksigPreTapscript_witness_false` | false checker + `nullFail = false` ⇒ `.ok false` | `propext`, `Quot.sound` |
| `evalChecksigPreTapscript_ecdsaEntry_witness_false` | the same with the real-crypto entry | `propext`, `Classical.choice`, `Quot.sound` |
| `stepBody_checksig_false_continue` | `OP_CHECKSIG`, false verdict, `nullFail = false` ⇒ push `false`, drop 2, `opCount+1` | `propext`, `Quot.sound` |
| `stepBody_witness_false_continue` | the same for `pk02` + real-crypto entry | `propext`, `Classical.choice`, `Quot.sound` |
| `stepBody_pk02_block_false_continue` | as above, with `checkPubKeyEncoding` discharged from block policy | `propext`, `Classical.choice`, `Quot.sound` |

The inclusion theorem is the honest direction: Lean never rejects a key Core
accepts, so this is an over-approximation, not a two-sided mismatch. The
witness refutes the converse. `core_valid_imp_lean_valid` is proved by case
analysis on the tag (`2/3 → 33`, `4/6/7 → 65`, else `0`), using
`byteAt_zero_eq` and `UInt8.toNat_inj`.

`evalChecksigPreTapscript` (`Interpreter/Defs.lean:720-742`) returns
`.ok fSuccess` when `fSuccess = false` and `pol.nullFail = false` (or the
signature is empty), and `.error .sigNullFail` otherwise. The `stepBody`
`OP_CHECKSIG` arm (`Defs.lean:1033-1047`) pushes the boolean and, for
`0xac`, continues; `0xad` (CHECKSIGVERIFY) errors instead. The guard theorem
is stated for `OP_CHECKSIG` only.

## 4. Reachability, and the policy mask

Under block/default policy the gate is reached. **STRICTENC masks it**:
Core's `CheckPubKeyEncoding` (`interpreter.cpp:228-237`) runs
`IsCompressedOrUncompressedPubKey` (`:74-92`), which rejects any key shorter
than 33 bytes and any length mismatch with `.pubKeyType`, *before*
`CheckECDSASignature`. Lean's port is `Defs.lean:382-405`. So with
`pol.strictEnc = true`, `0x02` aborts at the encoding check in both models
and the divergence is unobservable there. The same holds for
`witnessPubkeyType` on v0 (`isCompressedPubKey`). With
`strictEnc = false` / `witnessPubkeyType = false` — the block/default
configuration for these flags — `checkPubKeyEncoding … pk02 = none`, and
Lean proceeds to the divergent gate (kernel lemma
`checkPubKeyEncoding_pk02_block`).

The ECDSA seam then does:

```lean
-- Seam/Entry.lean:48-59
if !isValidPubKey pk then false
else if sig.size = 0 then false
...
else verify (sig.extract 0 (sig.size - 1)) pk (sighash …)
```

With the real-crypto `verifyImpl`, `parsePubKey pk02 = none`, so the answer
is still `false` (`ecdsaEntry_witness_false`). If a caller supplies a
checker whose verification does not re-parse the key — e.g. the always-true
verifier used by the seam's own tests — the Lean model returns `true` for a
pubkey Core rejects. `Seam/Tests.lean:106` even asserts
`isValidPubKey (fromHex "02") = true`, and `:128-133` defines
`pkC : ByteArray := fromHex "02"` with the comment "valid header ⇒
isValidPubKey" and expects a passing CHECKSIG. That is the strongest local
evidence that the weak predicate is load-bearing in the model's own tests,
but it contradicts the Core pin.

## 5. Why the existing SCR-112 artifacts do not catch this

Two artifacts are routinely cited for SCR-112, and neither covers this
divergence:

1. **`spec/equiv/cells/checksig/C-L-checksig-invalid-pubkey`** is
   `coverage: partial` and says so. Its `pk_valid` is an unconstrained
   symbolic 0/1 input; the precondition explicitly notes that
   "`CPubKey::Set` is structural … so this cell does not model the
   byte-level parse". Both legs therefore agree on a shared *assumption*,
   and the byte-level predicate that is the subject of this finding is
   outside the cell. The cell can show that an invalid key continues; it
   cannot show that Lean and Core disagree about which keys are invalid.

2. **`BitcoinProofs.AF.PDW62b.evalChecksigPreTapscript_pk_invalid`**
   (`spec/proofs/BitcoinProofs/AF/PDW62b/PDW62b.lean:54-66`) is tagged
   `SCR-112`, but its hypothesis is
   `checkPubKeyEncoding flags pol sv pk = some e` and its conclusion is
   `.error e`. That is the **policy encoding abort** (the SCR-106/107
   face), not the Core-invalid-key false-and-continue arm. `docs/THEOREMS.md`
   row SCR-112 describes the false-and-continue behaviour yet points at this
   theorem; `docs/ISSUE-16-PLAN.md:50` already lists SCR-112 among the rows
   whose summaries "mix policy with consensus or overstate the model". This
   finding is consistent with that plan item; the row should stay open
   until the gate predicate itself is corrected.

The mismatch is also visible in `Seam/Tests.lean:106-108`, which treats
single-byte `02`/`03`/`04` as valid pubkeys, i.e. the test suite pins the
divergent value.

## 6. Disposition

`open` — model-fidelity / definitional divergence. Not a tool gap (the
witness is kernel-checked and the C side is the real pinned header), not
domain-restricted (the key is a legal script stack element in block
validation), and not a consensus split with the real checker (see §1).

Why it still matters:

- Any Lean statement of the form "`isValidPubKey pk = true`, therefore the
  Core checker will proceed to EC verification" is false for these keys.
  With `verifyImpl` the downstream parse rescues the *verdict*, but the
  *reason* (gate vs. parse) is wrong, and any refinement/proof that treats
  the gate as Core's `IsValid` inherits the gap.
- Any checker parameterised over `verify` (the seam's public shape) can
  return `true` on a Core-invalid key; the always-true verifier in the test
  suite is a concrete instance.
- The cell bookkeeping currently labels SCR-112 partial for the right
  reason but does not name this predicate as the missing piece.

### Proposed fix

Prefer making the seam predicate the size-exact port:

```lean
-- spec/core/Bitcoin/Crypto/Seam/Der.lean
-- (import Bitcoin.Crypto.EcdsaDeep.PubKeyParse)
def isValidPubKey (pk : ByteArray) : Bool := validPubKeySize pk
```

or keep `Der.isValidPubKey` header-only but have `ecdsaVerdict`
(`Seam/Entry.lean:48-59`) call `validPubKeySize` at the gate. The first is
closer to Core, where `CPubKey::IsValid` is exactly "`Set` accepted the
bytes" = `ValidSize`; the second avoids changing `Der.isValidPubKey`'s
public shape but leaves a predicate that no longer means what its name and
docstring say. Either way:

- `Seam/Tests.lean:106-108` must change (single-byte headers become
  `false`; add 33/65-byte positives and hybrid 65-byte positives).
- `Seam/Tests.lean:128-133` (`pkC = "02"`) must use a real 33-byte key.
- Proofs with `hpk : isValidPubKey pk = true` keep working (the hypothesis
  becomes stronger); `ecdsaEntry_badPubKey_false` (hypothesis
  `isValidPubKey pk = false`) also keeps working, since more keys now take
  that branch. No proof was edited here.
- Keep hybrid `06`/`07` at 65 bytes accepted by the gate: Core's `Set`
  accepts them; STRICTENC/WITNESS_PUBKEYTYPE rejection is a separate policy
  layer (SCR-106/107), not `IsValid`.

## 7. What was not done (explicit non-claims)

- **No R leg.** No rbitcoin harness was built or run.
- **No Alive2/SAW cell.** The C side is the actual pinned Core header
  compiled with g++, not the twin translation unit; nothing here is an
  Alive2 certificate, and no `L ⊑ C` / `C ⊑ L` claim is made.
- **No end-to-end transaction.** `VerifyScript` is not executed on a
  crafted spend. The block-mode result is a theorem about `stepBody` and
  `evalChecksigPreTapscript`, not a replayed block.
- **No claim that the end-to-end verdict differs with the real crypto
  seam.** It does not: `verifyImpl` re-parses the key and returns false
  (`verifyImpl_witness`). The divergence is at the gate, and the finding is
  filed as such.
- **No claim that a false verdict is an error.** With `nullFail = false`
  the result is `.ok false`; with `nullFail = true` and a non-empty
  signature it is `.error .sigNullFail`. Both are stated in the Lean file;
  only the block/default arm is packaged as the guard.
- No edits to `PINS.lock`, `contract/**`, `spec/db/*`, `results/**`,
  `docs/**`, the shared findings index, existing cells, or the ledger. No
  push.

## 8. Artifacts and reproduction

All paths relative to
`spec/equiv/findings/wave64/25-scr-112/`:

| file | sha256 |
|---|---|
| `witness/IsValidPubKeyWitness.lean` | `861000746167630bbcfcb0adf7d5bd14f766c054415d172ad57020dc6d95ee4d` |
| `witness/c_core_pubkey.cpp` | `ae4e19a1aa332e0c4f6ded47fea2af836c838bce2c1bf3e90efc744d3b5dba0e` |
| `witness/run.sh` | `3e90e76dbfd6a47584f965661a8bc6c078f293000242280aef988386968ff5d2` |
| `witness/c_core_pubkey.out` | `90d417f14785d72c4824906231acac6a086d763d927f58a0a2938b3f0fe6b758` |
| `witness/l_isvalidpubkey.out` | `33b4b43fda18f7470b98b2b75aa1d966e446adf1d962d3c09d2ae832dc0aa04c` |

`witness/build.txt` also records the Core pin and the pinned
`src/pubkey.h` hash
(`b586b35e4749579e9dad6c6c56c1d7ceecce20ddbd7e066b5c86cadf5d16bb71`).

Exact commands:

```sh
cd /tmp/opencode/wave64/25-scr-112

# One shot: pin check, compile the C driver against real Core, run it,
# then kernel-check the Lean witness with the project toolchain.
spec/equiv/findings/wave64/25-scr-112/witness/run.sh

# Individually:
g++ -std=c++20 -O2 -I /tmp/opencode/core-pin/src \
    -I /tmp/opencode/core-build/build/src \
    spec/equiv/findings/wave64/25-scr-112/witness/c_core_pubkey.cpp -o /tmp/cpub
/tmp/cpub

cd spec/core
lake env lean ../equiv/findings/wave64/25-scr-112/witness/IsValidPubKeyWitness.lean
```

Toolchain: g++ 13.3.0; Lean 4.35.0 (`eb6cafb7290e8bd5f2937522d8d804f58f02bafc`,
the repo's `spec/core/lean-toolchain`). The C driver refuses to run unless
`git -C /tmp/opencode/core-pin rev-parse HEAD` is the pin above; the
compilation include path supplies Core's generated
`bitcoin-build-config.h`.

The Lean file is a standalone witness file; it is not imported by the build
and no existing module was modified. All twelve `#print axioms` lines are
captured in `l_isvalidpubkey.out`; `isValidPubKey_diverges`,
`lean_accepts_pk02`, and `core_rejects_pk02` have no axioms, and the rest
use only `propext`, `Quot.sound`, and (where the real-crypto entry or
`stepBody` is involved) `Classical.choice`.
