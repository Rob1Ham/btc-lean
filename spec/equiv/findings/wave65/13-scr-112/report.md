# Wave 65 / 13 — SCR-112 exact pubkey encoding: partial cell + F-DIV-004 no-go

**Row:** SCR-112 — *an invalid pubkey makes CHECKSIG push false and continue
in a block; the pubkey-encoding abort is policy (STRICTENC on SCR-106,
WITNESS_PUBKEYTYPE on SCR-107), and tapscript x-only size rules stay on
SCR-158/159.*

**Base:** `76dbfe5e42f8a337e41a7308158b0de078afafd9` (`equiv/llvm-three-leg`,
PR #29)
**Branch/worktree:** `wave65/13-scr-112` / `/tmp/opencode/wave65/13-scr-112`
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`

**Status: `partial` — SCR-112 stays `gap`. F-DIV-004 remains open and is now
reproduced against an Alive2 IR pair, not only by the wave64 C/Lean
witnesses.**

## 1. Decision in one paragraph

The correct behavior is now proved in a real Alive2 + SAW cell under the
**exact byte-level encoding rules**, in both directions: under block flags a
size-invalid key (`pk = [0x02]`, header promises 33 bytes, actual 1) makes
`CPubKey::ValidSize` false, `CheckECDSASignature` false, and `OP_CHECKSIG`
pushes false and the script continues; under policy STRICTENC the same key
aborts with `PUBKEYTYPE` = 29 before the checker, and under v0
WITNESS_PUBKEYTYPE a 65-byte uncompressed key aborts with 44.  The cell's L
leg uses `validPubKeySize` — the size-exact port **already present** in the
Lean tree — because the pinned seam predicate
`Bitcoin.Crypto.Seam.Der.isValidPubKey` is header-only.  The new Alive2 probe
runs that pinned predicate against the same C slice and produces a value
mismatch (`264` vs `10497`) for `hdr = 0x03, len = 1` under block flags.  So
the row cannot be promoted without a Lean-model change, which this task
forbids; the cell is filed as partial coverage and the gap is retained.

## 2. What was added

### 2.1 New cell — `checksig/C-L-checksig-pubkey-encoding`

`spec/equiv/cells/checksig/C-L-checksig-pubkey-encoding/`

- `src/c_pubkey_encoding.cpp` — C leg, a line-cited slice of pinned Core.  It
  computes `CPubKey::ValidSize` from `(hdr, len)` instead of taking a
  `pk_valid` bit as an input, then applies `CheckPubKeyEncoding` and
  `CheckECDSASignature` in Core's order.
- `src/l_pubkey_encoding.cpp` — L leg, a reviewed transliteration of the
  pinned Lean definitions.  At the ECDSA gate it uses
  `Bitcoin.Crypto.EcdsaDeep.PubKeyParse.validPubKeySize`
  (`PubKeyParse.lean:135-136`), **not** `Der.isValidPubKey`.
- `alive2/run.sh`, `saw/run.sh` — self-contained lanes (no shared tools
  edited).
- `saw/pk_encoding.cry`, `saw/cell.saw` — independent Cryptol restatement and
  six proof obligations.
- `spec.md` (front matter first line is the required partial marker in
  `coverage`/`scr_row_coverage`), `notes.md`.
- `alive2/result.txt`, `saw/result.txt` — raw transcripts.
- `alive2/certificate.sha256`, `saw/certificate.sha256` — tracked-input
  certificates (no `build/` paths, no absolute paths).

The cell proves three functions per leg over symbolic
`hdr: i8`, `len`, `strict_enc`, `witness_pubkey_type`, `sv`, `sig_len`,
`crypto_ok`, `null_fail`:

| function | observable |
|---|---|
| `cell_pubkey_encoding` | policy decision only: 1 pass / 116 (`29<<2`) / 176 (`44<<2`) |
| `cell_pubkey_encoding_checksig` | full path + EVAL_FALSE tail |
| `cell_pubkey_encoding_continue` | same path + one `OP_NOT` |

Key evaluated outcomes (all reproduced by the real parse of the exact
predicates, and by SAW on both legs):

| instantiation | result |
|---|---|
| block flags, `hdr=0x02,len=1,sig_len≠0,crypto_ok=1,null_fail=0` | 264 (push false, EVAL_FALSE) |
| same + `OP_NOT` | 10497 (true final stack, block continues) |
| STRICTENC on the same key | 116 = `PUBKEYTYPE` 29 abort |
| v0 WITNESS_PUBKEYTYPE, `hdr=0x04,len=65` | 176 = `WITNESS_PUBKEYTYPE` 44 abort |
| NULLFAIL, non-empty sig | 128 = `SIG_NULLFAIL` 32 abort |
| canonical `hdr=0x02,len=33` | 10497 |

The policy abort and the block continue are therefore separated exactly as
the row text says.  The cell is **not** a closure of the row: it proves the
post-fix gate, and `spec.md`/`notes.md` say so explicitly.

### 2.2 New divergence probe — `findings/wave65/13-scr-112/probe/`

- `c_probe.cpp` — exact Core slice (same predicates as the cell C leg).
- `l_pinned_probe.cpp` — **pinned** Lean `Der.isValidPubKey`:
  `len > 0 && pubKeyLen(hdr) != 0`, no length equality.
- `run.sh` — builds both, extracts `probe_core`/`probe_pinned` (the L symbol
  is renamed only for Alive2's name matching), runs
  `alive-tv --bidirectional`, requires a counterexample, and prints a
  concrete witness table from a native build of the same functions.
- `alive.log` — raw Alive2 output.
- `witness.txt` — concrete packed outcomes.
- `build.txt` — tool and input hashes.

Alive2 result (raw, `alive.log:186-267`):

```text
Transformation doesn't verify!
ERROR: Value mismatch

Example:
i8 noundef zeroext %hdr = #x03 (3)
i32 noundef %len = #x00000001 (1)
i32 noundef %strict_enc = #x00000000 (0)
i32 noundef %witness_pubkey_type = #x00000000 (0)
i32 noundef %sv = #x00000000 (0)
i32 noundef %sig_len = #x00000001 (1)
i32 noundef %crypto_ok = #x00000001 (1)
i32 noundef %null_fail = #x00000000 (0)
...
Source value: #x0000000000000108 (264)
Target value: #x0000000000002901 (10497)
```

`witness.txt` shows the same class for `hdr=0x02,len=1` and
`hdr=0x02,len=34`, plus the NULLFAIL case (`128` vs `10497`).  It also shows
that STRICTENC (`116` both) and v0 WITNESS_PUBKEYTYPE (`176` both) agree,
because the policy abort masks the gate — the same masking the wave64 report
described.

This is not a second, different finding.  It is F-DIV-004 expressed as an IR
counterexample against the same C slice used by the new cell.

## 3. F-DIV-004 status: open, not papered over

```text
F-DIV-004: Lean isValidPubKey is header-only; Core CPubKey::Set is size-exact
  legs: C | L
  cell: checksig/C-L-checksig-pubkey-encoding (partial) + probe/
  symptom: pk = 0x02 (1 byte), and every non-canonical length with a valid
           header.  Pinned Lean isValidPubKey = true; Core
           CPubKey::ValidSize = false.  Under block flags and an EC oracle
           that does not re-parse the length, Lean returns true where Core
           returns false.
  evidence:
    - cells/checksig/C-L-checksig-pubkey-encoding/{alive2,saw}/result.txt
    - findings/wave65/13-scr-112/probe/{alive.log,witness.txt}
    - findings/wave64/25-scr-112/ (Lean kernel witness)
    - findings/wave64/60-cpubkey-validity/ (independent reproduction)
  disposition: open (model-fidelity/definitional divergence)
  notes: fix the seam predicate to the size-exact port; then the new cell's L
         leg can be swapped to the seam and SCR-112 re-adjudicated.
```

Precise locations:

- Core: `src/pubkey.h:69-76` (`GetLen`), `:86-88` (`ValidSize`), `:98-105`
  (`Set`), `:194-197` (`IsValid`); `src/script/interpreter.cpp:74-99`,
  `:228-237`, `:331-356`, `:1069-1092`, `:1701-1724`.
- Lean, divergent: `spec/core/Bitcoin/Crypto/Seam/Der.lean:165-175`
  (`pubKeyLen`, `isValidPubKey`), used at
  `spec/core/Bitcoin/Crypto/Seam/Entry.lean:48-59`.
- Lean, already correct: `spec/core/Bitcoin/Crypto/EcdsaDeep/PubKeyParse.lean:123-136`
  (`validPubKeySize`); policy predicates at
  `spec/core/Bitcoin/Interpreter/Defs.lean:382-403`; checksig path at
  `:720-742` and `:1033-1047`.

The end-to-end verdict with the real `parsePubKey` still coincides (the
parser rejects every length-mismatched key), exactly as
`findings/wave64/60-cpubkey-validity/` states.  The divergence is at the
gate and is observable with an abstract/lax EC oracle — which is the shape
used by the cell suite and several theorems.  This report does **not** claim
a consensus split with the real parser.

## 4. Why the row remains `gap` (no-go for banked closure)

`spec/db/equiv-cells.yaml` keeps SCR-112 at `gap`.  That is correct:

1. The new cell's L leg is `validPubKeySize`, the remediation target, not the
   pinned seam predicate.  The pinned `Seam/Entry.ecdsaVerdict` calls
   `isValidPubKey`, so the current model does not compute the gate proved
   here.
2. The probe shows a concrete Alive2 mismatch for the pinned predicate.  A
   cell built on the pinned predicate would be red, not green.
3. Promoting the row on the strength of the corrected-predicate cell would
   paper over F-DIV-004.  The cell therefore declares `coverage: partial`
   and `scr_row_coverage: partial`.

No Lean proof, no model source, no shared twin/runtime, and no existing cell
was edited.  The ledger/status files were not touched because they are
outside this task's write scope.

## 5. Remediation (required before SCR-112 can close)

Preferred, matching wave64/25 §6 and wave64/60 §5.3 option 2:

1. In `spec/core/Bitcoin/Crypto/Seam/Der.lean`, make the gate size-exact:
   `def isValidPubKey (pk : ByteArray) : Bool := validPubKeySize pk` (import
   `Bitcoin.Crypto.EcdsaDeep.PubKeyParse`), or leave the name but change
   `Seam/Entry.ecdsaVerdict`'s gate to `validPubKeySize pk`.
2. Update the seam tests that currently pin the divergent value:
   `spec/core/Bitcoin/Crypto/Seam/Tests.lean:106-110` (`isValidPubKey "02"`
   is currently asserted `true`) and the `pkC = fromHex "02"` fixture at
   `:128-133`; add 33-byte `02/03`, 65-byte `04/06/07` positives and
   length-mismatch negatives.
3. Re-run the new cell with its L leg switched from `validPubKeySize` to the
   seam `isValidPubKey`.  Post-fix it must stay both-tool green; then the
   cell can be re-labelled `scr_row_coverage: full` and SCR-112 promoted by
   the ledger updater.  Today that swap is a red cell, which is exactly the
   probe.
4. Keep hybrid 65-byte `06/07` accepted at `CPubKey::IsValid`; STRICTENC /
   WITNESS_PUBKEYTYPE rejection stays on SCR-106/107 as separate policy
   rows.

The fix is small and preserves the valid-key direction: every key Core
accepts still satisfies the strengthened predicate, so existing `hpk`
theorems survive; `ecdsaEntry_badPubKey_false` then covers the full
Core-invalid class.

## 6. Exact commands and raw evidence

All paths relative to `spec/equiv/`.

```sh
# Cell: Alive2 (bidirectional, three closed functions per leg)
bash cells/checksig/C-L-checksig-pubkey-encoding/alive2/run.sh
# -> alive2/result.txt: 3 correct, 0 incorrect, 0 Alive2 errors; STATUS=alive2-green

# Cell: SAW (six obligations: 3 functions x C/L)
bash cells/checksig/C-L-checksig-pubkey-encoding/saw/run.sh
# -> saw/result.txt: Proof succeeded x6; STATUS=saw-green

# Pinned-Lean vs Core divergence probe (expected red)
bash findings/wave65/13-scr-112/probe/run.sh
# -> alive.log: ERROR: Value mismatch; witness.txt: DIVERGE rows
```

Tool versions observed: Alive2 `Ubuntu LLVM version 20.1.2` (optimized
build, `/usr/local/bin/alive-tv`), clang `20.1.2`, SAW `1.6 (68eed5f
release-1.6)`, Cryptol `3.6.0`.

Gate replay at this tree:

```sh
python3 tools/gate_ir_pin.py
# -> cell directories: 165; with a record file: 165
# -> all 183 SCR rows adjudicated (156 both-green, 25 gap, 2 seam)
# -> all 346 certificates replay cleanly
# -> RESULT: PASS (0 failures, 0 warnings)
```

The new cell is picked up by the standard runner:
`run_equiv.run_alive2` and `run_equiv.run_saw` both return `True` for it
(`run.sh rc=0, result.txt`), so it does not need a bespoke gate.

Raw logs and tracked-input certificates:

| artifact | sha256 |
|---|---|
| `cells/checksig/C-L-checksig-pubkey-encoding/alive2/result.txt` | `bdaf33b6faae57ebd940ede87a4ed7b226b2b13d0058ae92c941b2fa36bd8d8f` |
| `cells/checksig/C-L-checksig-pubkey-encoding/saw/result.txt` | `40e0c3bdd413762159dcce29ac2fb460ac9044c3840578ecb254706a5b6902ad` |
| `cells/checksig/C-L-checksig-pubkey-encoding/alive2/certificate.sha256` | `5351236ac24045518a190b19696c8090eadb636187561552e85b42aecd64046e` |
| `cells/checksig/C-L-checksig-pubkey-encoding/saw/certificate.sha256` | `5351236ac24045518a190b19696c8090eadb636187561552e85b42aecd64046e` |
| `findings/wave65/13-scr-112/probe/alive.log` | `ec211e7582284f90e850d715281c1f5a32fb7ac0cbe77f8799cddb8f1a8a9a3a` |
| `findings/wave65/13-scr-112/probe/witness.txt` | `45812ad78f864e24228020ee089175f71028b17d0f9381a2b817ad9385bed2a3` |
| `findings/wave65/13-scr-112/probe/build.txt` | `890c4b7dc4ff9c6614c767997cb0f57e2b1b73bcb3b442281b61b26d40cc161a` |
| `findings/wave65/13-scr-112/probe/certificate.sha256` | `3f2d254c076825492cb7f7813afdf700a3c09b2217864ebaadf932edcd246b88` |
| `findings/wave65/13-scr-112/gate-ir-pin.log` | `e8ca65bc44677c377e4f5d48fd8066f059b2e6906740a9d1ce6a84746a265f59` |
| `cells/.../src/c_pubkey_encoding.cpp` | `912cf70541a75dc52f9b4c3453c1134e1a8447c740cc582ec49e67fac2f5f992` |
| `cells/.../src/l_pubkey_encoding.cpp` | `88e7035a9bc7cb6ff2e70b31f4e07eab0d1b254b5441b935730a251b9f96e52f` |
| `cells/.../spec.md` | `b14606d58b8b0054812c6e84bcd2d87149c9761b19d9b551e763b057cd2bff51` |
| `findings/.../probe/c_probe.cpp` | `016da853e061f3c89510d7aca78b6fdbbb33acff5180c9e0439da40219edd5a2` |
| `findings/.../probe/l_pinned_probe.cpp` | `f2ddfe6a51b65ecb8cc53bbaf35c9af6e95ac5915f032309cf4dadb79b2cf5b1` |
| `findings/.../probe/run.sh` | `dd3430587e9862d8313d4827f13c72ea4cba32bd107092fca35c615704e3b1e4` |

`python3 tools/normalize_certificates.py --check` reports
`changed=0, missing=0` after the two new certificates were normalized.  The
certificates hash only tracked inputs plus the raw `result.txt` (and
`contract/error_kind.h`); `build/` artifacts and absolute machine paths are
excluded.

## 7. Residual and explicit non-claims

- **F-DIV-004 is open.**  No Lean model/proof change was made; the row keeps
  its `gap` status.
- **The new cell is partial.**  Its L leg is the post-fix predicate; it
  advances coverage and is the acceptance test for the remediation, but it
  does not certify the pinned seam.
- **No R leg** (F-HARNESS-002: the pinned rbitcoin shim has no typed
  `ScriptError` and rejects flags != 0).
- **Crypto is abstract.**  `crypto_ok` is an input (same-crypto premise).
  No ECDSA point validation, sighash, or libsecp256k1 behavior is claimed.
- **Payload bytes are omitted** because neither `CPubKey::Set` /
  `ValidSize` nor either encoding predicate reads them.  This is a stated
  domain reduction, not an abstraction of the rule.
- **Signature encoding is assumed to pass** (`CheckSignatureEncoding`); the
  cell isolates the pubkey-encoding gate and does not re-prove
  SCR-105/108/109.
- **No full block replay.**  Continuation is the same `OP_NOT` slice
  convention used by the existing invalid-pubkey cell.
- **No Lean kernel theorem for the cell.**  The L leg is a reviewed C++
  transliteration; the Lean-side kernel witnesses remain
  `findings/wave64/25-scr-112/`.
- **No ledger/status/matrix update.**  `spec/db/equiv-cells.yaml`,
  `results/**`, `docs/**`, `PINS.lock`, `contract/**`, `spec/proofs/**`, the
  shared twin/runtime, and existing cells were not edited.  Integration must
  add the new cell path to the SCR-112 row and decide whether partial
  evidence changes the row's gap note; the row status itself must stay
  `gap` until step 5.3 re-runs green.
