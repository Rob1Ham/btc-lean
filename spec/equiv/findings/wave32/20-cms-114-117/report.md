# Wave-32 — CHECKMULTISIG bounded C-L cells (SCR-114 … SCR-117)

**Date:** 2026-10-20
**Branch:** `wave32/20-cms-114-117`
**repo_head:** `805c8042f92d3bed909ca40219a4d21fc9150cc1`
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Tools:** Alive2 v20.0 (LLVM 20.1.2), clang 20.1.2, SAW 1.6
(`68eed5f release-1.6`), Z3 4.8.12.
**Patches:** none. **R leg:** not attempted (documented non-proof,
F-HARNESS-002 / F-TOOL-001).
**Scope:** only the three cell runners under
`spec/equiv/cells/e3-cms/C-L-w32-cms-*` were executed. No shared ledger
updater, no `make equiv`, no edit to the contract, results, pins, or other
worktrees, and no edit to an existing cell.

This report closes the three CHECKMULTISIG rows that the earlier 1-of-1 cell
left as gaps (SCR-115, SCR-116, SCR-117) and widens SCR-114 from a single
1-of-1 witness to the full argument prelude. All three cells are green in
both tools; SCR-115 is honestly `partial`, SCR-114/116/117 are `full` inside
the stated cell models.

## 1. Deliverables

| SCR | Row summary | Cell | Alive2 | SAW | Row coverage |
|---|---|---|---|---|---|
| SCR-114 | nKeys∈[0,20], nSigs∈[0,nKeys], depth checks | `C-L-w32-cms-counts` | green (1/1 fn) | green (54/54) | **full** |
| SCR-116 | sigs to keys in order; early fail when sigs>keys remain | `C-L-w32-cms-loop` | green (1/1 fn) | green (120/120) | **full** |
| SCR-117 | CheckSignatureEncoding+CheckPubKeyEncoding inside loop | `C-L-w32-cms-loop` | green (1/1 fn) | green (120/120) | **full** |
| SCR-115 | all nSigsCount sigs FindAndDelete'd before any check (BASE) | `C-L-w32-cms-finddelete` | green (5/5 fns) | green (128/128) | **partial** (script ≤ 8, needle ≤ 4; general needle chain only nSigs ≤ 2) |

Directions for every cell: `L ⊑ C` and `C ⊑ L` (Alive2 `--bidirectional`;
SAW proves each leg separately against the same oracle constants).

### Evidence

| Cell | Artifacts |
|---|---|
| counts | `cells/e3-cms/C-L-w32-cms-counts/{spec.md, alive2/*, saw/*, build/*}` |
| loop | `cells/e3-cms/C-L-w32-cms-loop/{spec.md, alive2/*, saw/*, build/*}` |
| finddelete | `cells/e3-cms/C-L-w32-cms-finddelete/{spec.md, alive2/*, saw/*, build/*}` |

Tool sources and runners: `cells/_tools/w32cms/`
(`e32_common.h`, `c_sigenc.h`, `l_sigenc.h`, `c_counts.cpp`, `l_counts.cpp`,
`c_loop.cpp`, `l_loop.cpp`, `c_finddel.cpp`, `l_finddel.cpp`,
`oracle_counts.py`, `oracle_loop.py`, `oracle_finddel.py`,
`build_cell.sh`, `run_alive2.sh`, `run_saw.sh`).

### Artifact hashes (sha256)

| Artifact | sha256 |
|---|---|
| counts `spec.md` | `a75a0180ee1c34a61a3e143aa18d7395751310befc3011e1767e2b986ba26f2a` |
| counts `alive2/result.txt` | `236a71de5931b64ab51ee111bab0db66d6b3dde85043ae890a3463dc37b0b788` |
| counts `alive2/certificate.sha256` | `34c901e8aaa4e26a532f40a40d05d9e4bfe32bb11ef97150e2a0ee2005fbe2b1` |
| counts `saw/result.txt` | `ffb004ca9e2fec652c564896241ab94ef55ed9a561c326edc1791c74b6528d61` |
| counts `saw/certificate.sha256` | `daaa338ba802bd92b8639f21599218c41cb8a384453057c8ae7609d4b8727cfe` |
| loop `spec.md` | `ee2d0480386325059f398d11f4d25b5d7258b9f370bceafaf3c51023c5166ebb` |
| loop `alive2/result.txt` | `b9a4819c2b051e4fff700a9424c549c9a0431a2356f861499cbb9dc60d1b5d67` |
| loop `alive2/certificate.sha256` | `b6add3fa98af780ec7b2656587d9753f1c9c94e52bff47dc875a8bae2dad5441` |
| loop `saw/result.txt` | `251d4d3bb6de746fccfa0fa40c1b88652bc50a579b280638d8dfe693e18d32c9` |
| loop `saw/certificate.sha256` | `d429edc5176c30c2987550c53f58bf4e35ace6fd91f090da84fd2249d53bc701` |
| finddelete `spec.md` | `2c7f2ab755fb50049ef9a0f0904c9493cbeca5958ecd92c2496ed4d9eea6ef59` |
| finddelete `alive2/result.txt` | `394c549d29be412581e5dedac6ff08efae8740d0ff49c3756ad8d101651024b7` |
| finddelete `alive2/certificate.sha256` | `64892761a77cc3133a56305838b701181a780c58f75b8a01c364a9540df6f803` |
| finddelete `saw/result.txt` | `074fa1d3fdbc8497aa3f9d214b75c748333bbd24d0c33a42441fd9566e2c9324` |
| finddelete `saw/certificate.sha256` | `c740666e2ddca6a1a06624efc72d94ec01530cdea92562b1daffb9d7dbb3d4cf` |

## 2. Design of the three cells

### New private toolchain

The shared `cells/_tools/e3/cellsig/` harness is deliberately untouched. The
wave-32 cells use a new directory `cells/_tools/w32cms/` with:

- `e32_common.h` — the cell ABI only (injective element encoding, the
  CHECKMULTISIG stack accessor, the packed observables, the flag word, and
  the shared ECDSA stand-in);
- `c_sigenc.h` / `l_sigenc.h` — signature/pubkey encoding validators, written
  independently: `c_*` from the pinned `script.cpp` / `interpreter.cpp`
  slices, `l_*` from the Lean equations (big-endian digit view,
  `byteOr`-total indexing, `Except` error order);
- one C and one L source per cell.

The L legs are reviewed transliterations of
`spec/core/Bitcoin/Interpreter/Defs.lean` (the twin has no CHECKMULTISIG
handler at this pin — wires `0xae`/`0xaf` map to
`OP_UNSUPPORTED_CHECKSIG`). They were written from the equations, not copied
from the C slice.

### Why the loop uses a concrete checker

The loop's engine code is `checker.CheckECDSASignature(sig, pk, …)` followed
by counter updates that depend on its verdict. If both legs called an
*uninterpreted* external declaration, Alive2 would not correlate the two
argument values, so a wrong `isig`/`ikey` advance would not be observable.

This workstream verified the tool behaviour directly (scratch experiment,
not part of the evidence): with

```c
extern "C" int ext(int);
int a(int x){ return ext(x) + ext(x); }
int b(int x){ return 2 * ext(x); }
```

`alive-tv` reports **not** equivalent, i.e. the two `ext(x)` calls are
independent. Therefore the loop cell replaces the crypto seam with one
**concrete deterministic predicate shared by both legs**
(`e32_check_pair(sig, pk, salt)`), so the proof obligation is:

> given the same verdict function, C and L agree on loop order, counter
> updates, early exit, encoding precedence and the tail observable.

This is a control-flow proof, **not** an ECDSA proof, and the spec says so.
It is strictly better for SCR-116/117 than an unconstrained call, because
the verdict then depends on the *pair actually read at that position*, so a
mis-ordered read changes the result.

### Alive2 settings and the `-O2` lane

`run_alive2.sh` defaults to `--smt-to=600000`. Both legs are compiled with
`-O2` for the Alive2 lane (SAW stays at `-O0`). This is not cosmetic:

- at `-O1`, clang tags every loop with `llvm.loop.unroll.disable`;
- Alive2 v20.0 then does not unroll the bounded loops in the loop and
  finddelete cells. Executions that do not reach a return within its
  unroll budget are treated as unconstrained, so a function can be reported
  equivalent to one that returns a different constant;
- measured directly: a finddelete mutant whose packed result is `0` instead
  of the script bytes came back "equivalent" at `-O1`, even though the two
  functions differ on a concrete input;
- at `-O2` the same bounded loops are emitted without that tag, Alive2
  unrolls them, and the mutants are caught (see §4). The `-O2` build is
  therefore the lane that produces real evidence; the earlier `-O1` runs are
  not cited. The loop cell's `-O1` mutant run was killed before a verdict,
  so no claim is made about it beyond the `-O2` result.

The counts cell has no loops; it is built with the same runner for
consistency and was mutation-checked at `-O2` too.

### Constant initializers must survive `llvm-extract`

`run_alive2.sh` isolates one cell function with
`llvm-extract --func=… --recursive`. Plain `--recursive` keeps referenced
*function* bodies but demotes the function-local
`static const uint8_t half[32]` table (the low-S half-order constant) to an
**external declaration** in the extracted module. Alive2 then treats every
load from that table as unconstrained, and on the taken comparison branch
as poison, which produced a spurious *"Transformation doesn't verify"* for
the loop pair — and is the most likely reason the full bound-20 run first
appeared to be an SMT timeout.

The runner now adds `--keep-const-init`, which keeps the initializer in the
extracted module. Measured consequences:

- the loop pair is **green bidirectionally at the full bound**
  (`0 ≤ nSigs ≤ nKeys ≤ 20`) in 44 s of wall time;
- the C and L signature/pubkey validators, compared in isolation on the
  cell's element vocabulary, are green (1/1 each);
- the loop mutation (key encoding checked before signature encoding) is
  still **caught** at `-O2` with the flag.

Cells whose extracted module has no constant tables (counts, finddelete)
are unaffected in content; their lanes were re-run through the updated
runner anyway, so all six certificates were produced by the committed
scripts.

### Mutation sensitivity (and one tool/semantics finding)

Each cell was challenged with a source mutation; details in §4. The counts
mutant initially exposed a **false green**:

- clang at `-O1` turns

  ```c
  int64_t nk;
  if (!decode(keys_enc, nk)) return ERR;
  ```

  into a phi with an `undef` incoming for the unused path;
- with that `undef` at the join, `alive-tv` reported the mutant
  (`nk > 19`) equivalent to the original (`nk > 20`) even though concrete
  execution differs (`n=5`, `keys=0x1401`, `sigs=0x0101` → 0x48 vs 0x28);
- replacing the `undef` incoming by `0` in the extracted IR makes Alive2
  report the counterexample immediately (`72` vs `40`);
- fix: initialise the decode out-parameters (`int64_t nk = 0;`) in the cell
  sources. The mutant is now caught (see §4).

The initialised value is never observable (the early-return path does not
read it); this only removes an `undef` that Alive2 was free to refine. The
same pattern was removed from `e32_common.h` and `l_counts.cpp`.

## 3. Row claims

### SCR-114 — `C-L-w32-cms-counts` (full)

`cell_cms_counts(n, keys_enc, sigs_enc, ops_before)` is
`interpreter.cpp:1122-1146`: three depth checks
(`n < 1`, `n < nKeys+2`, `n < nKeys+nSigs+3`), both `CScriptNum` decodes
with the 4-byte limit, `nKeys < 0 || nKeys > 20` →
`PUBKEY_COUNT(10)`, `ops_before + nKeys > 201` → `OP_COUNT(7)`,
`nSigs < 0 || nSigs > nKeys` → `SIG_COUNT(9)`, and `SCRIPTNUM(4)` for both
width failures, in Core's exact order. The observable carries
`nKeys`, `nSigs`, `opCount` and depth on success.

Alive2 proves equality for **all** 64-bit inputs (no fixed witness), so
every branch and every boundary is exercised: 0/1/20/21 keys, negative
sign-magnitude values, 4- vs 5-byte numbers, opcount 201/202, and all three
depth underflows. SAW confirms both modules against 27 independent oracle
constants. The single abstraction is `ops_before` (SCR-113's per-opcode
accumulation is not modelled).

### SCR-116 — `C-L-w32-cms-loop` (full)

`cell_cms_loop(nKeys, nSigs, salt, flags)` is the post-prelude loop
`interpreter.cpp:1163-1225`. Symbolic `0 ≤ nSigs ≤ nKeys ≤ 20`, symbolic
flags, symbolic salt (which selects the pair contents). The observable
includes `nSigsLeft`, `nKeysLeft`, `isig`, `ikey`, `fSuccess` and an early
flag, so both the pair order and every counter update are compared.

- a failed check advances only `ikey`/`nKeysLeft`;
- a successful check also advances `isig`/`nSigsLeft`;
- `nSigsLeft > nKeysLeft` stops the loop with `fSuccess = false` and the
  early flag set when signatures remain;
- the tail maps false to `CHECKMULTISIGVERIFY(13)` on the verify wire and
  `EVAL_FALSE(2)` otherwise, true to `result 1`.

### SCR-117 — `C-L-w32-cms-loop` (full)

The same symbolic loop calls, per pair and in this order,
`CheckSignatureEncoding` (DER under DERSIG/LOW_S/STRICTENC, `HIGH_S` under
LOW_S, defined hashtype under STRICTENC) and then `CheckPubKeyEncoding`
(compressed/uncompressed under STRICTENC, compressed under
WITNESS_PUBKEYTYPE when sigversion is witness-v0). All five error ordinals
are reachable at iterations 1, 2 and 3 (SAW scenarios include DER, HIGH_S
and hashtype at later iterations), and the error exits **before** the
checker and before any counter increment, which is the row's claim.

The encoder implementations are compared C↔L on the cell's element
vocabulary (a 5-kind signature set and a 3-kind pubkey set, driven by
position + salt). Completeness of the DER/hashtype/pubkey parsers over
arbitrary byte strings is SCR-102/104/105/106/107, not this row. The
`full` label covers the row's own branches (per-pair invocation, all gates,
all ordinals, precedence, inside-loop placement).

### SCR-115 — `C-L-w32-cms-finddelete` (partial)

Five functions: `cell_fd_found`, `cell_fd_len`, `cell_fd_bytes`,
`cell_fd_chain` (nSigs ∈ {0,1,2}, caller-chosen needles) and
`cell_fd_chain_n` (symbolic nSigs 0..20, one-byte signature pushes,
BASE deletes / non-BASE no-op). Alive2 compares all five bidirectionally;
SAW checks 64 scenarios × 2 legs.

Covered: opcode-boundary walking (direct push, PUSHDATA1/2/4, truncated
push), greedy multi-match, match inside a push payload (not deleted), match
spanning a boundary (not deleted), no-match, empty needle, and the
per-signature loop applied in order before any check.

Why partial: script ≤ 8 bytes and needle ≤ 4 bytes (a bounded domain, not a
tool failure), and the general-needle chain is only nSigs ≤ 2. The nSigs
0..20 chain uses one-byte signature elements. No signature check is
modelled, so "before any check" is shown as the slice's position in
`checkMultiSig`, not as a full `EvalScript` run.

## 4. Mutation sensitivity

All mutants are scratch-only (not committed) and were compiled with the same
settings as the Alive2 lane (`-O2 -fno-discard-value-names
-fno-strict-aliasing`) against the unmutated opposite leg.

| Cell | Mutation (C leg) | Comparison | Result at -O2 |
|---|---|---|---|
| counts | `nk > 20` → `nk > 19` | C-mutant vs L, `cell_cms_counts` | **caught**: source `0x48` vs target `0x28` |
| loop | key encoding checked before signature encoding | C-mutant vs L, `cell_cms_loop` | **caught**: source error 24 (SIG_DER) vs target 29 (PUBKEYTYPE) |
| finddelete | drop the final tail accumulation | C-mutant vs L, `cell_fd_len` | **caught** (1 incorrect transformation) |
| finddelete | drop the final tail accumulation | C-mutant vs L, `cell_fd_chain_n` | **caught** (1 incorrect transformation) |

The `-O2` requirement is itself a measured result: at `-O1`, the finddelete
mutant (`fd_pack` returning `0`, which changes the packed bytes for the input
`script=0x4CAA01, slen=3, needle=0xAA01, nlen=2` from `0x4c` to `0`) was
reported **equivalent** by Alive2, while the same source pair is caught at
`-O2`. The same `-O1` comparison of the unmutated cell is therefore not
evidence and is not cited. See §2.

Concrete corroboration (drivers linked against each leg):

```
counts, n=5 keys_enc=0x1401 sigs_enc=0x0101 ops=0
  original 0x48  (INVALID_STACK_OPERATION: n < nKeys+2 = 22)
  mutant   0x28  (PUBKEY_COUNT: nKeys = 20 > 19)

loop, nKeys=1 nSigs=1 salt=2 flags=DERSIG|STRICTENC
  original err=24 (SIG_DER)      packed=0x0000000021010460
  mutant   err=29 (PUBKEYTYPE)   packed=0x0000000021010474

finddelete, script=0x4CAA01 slen=3 needle=0xAA01 nlen=2
  original len=1 bytes=0x4c ; chain_n(1, 0x4CAA01, 3, salt=0xAA, BASE)
                               = 0x010000000000004c
  mutant   len=0 bytes=0x00 ; chain_n = 0
```

The loop mutant is the sharpest test of the SCR-117 design: a pair whose
signature and pubkey are both invalid must report the *signature* ordinal
(24/27/23) rather than the pubkey ordinal (29/44), so swapping the checks is
observable only because the checker and the encoders read the actual pair at
that position.

## 5. Verification

Certificates are repo-root relative. From the repo root:

```sh
for c in counts loop finddelete; do
  sha256sum -c spec/equiv/cells/e3-cms/C-L-w32-cms-$c/alive2/certificate.sha256
  sha256sum -c spec/equiv/cells/e3-cms/C-L-w32-cms-$c/saw/certificate.sha256
done
```

- `C-L-w32-cms-counts/alive2`: OK (14 files verified, 0 failed)
- `C-L-w32-cms-counts/saw`: OK (17 files verified, 0 failed)
- `C-L-w32-cms-loop/alive2`: OK (14 files verified, 0 failed)
- `C-L-w32-cms-loop/saw`: OK (17 files verified, 0 failed)
- `C-L-w32-cms-finddelete/alive2`: OK (22 files verified, 0 failed)
- `C-L-w32-cms-finddelete/saw`: OK (17 files verified, 0 failed)

Two caveats about certificates, matching existing cell practice:

- they include `build/…` artifacts (extracted IR, linked bitcode, oracle
  scenarios). `spec/equiv/.gitignore` excludes `build/`, so those lines
  verify in the worktree where the run was produced; the committed
  certificate still pins the source, runner, tool, `twin/`, contract and
  result hashes. The build artifacts are regenerated by the runners.
- any later edit to a cell's `spec.md`, its `run.sh`, or a tool source
  invalidates that cell's certificate. The final runs in this branch were
  made after the last such edit.

## 6. Trust notes and limitations

1. **Same-crypto premise, counts/finddelete:** no crypto is modelled; these
   rows are numeric/byte-string control flow.
2. **Same-checker premise, loop:** the ECDSA verdict is the shared concrete
   predicate `e32_check_pair`, not an uninterpreted call and not secp256k1.
   The claim is conditional on both legs using that one function — they do,
   by construction and by the certificate hash of `e32_common.h`. Nothing
   here says Core's ECDSA accepts the same signatures as the Lean model.
3. **Element vocabulary, loop:** pair contents are position/salt-derived
   from a fixed vocabulary rather than fully symbolic bytes; every encoding
   gate has a witness, but arbitrary DER encodings are not quantified.
4. **opCount:** `ops_before` is an input; SCR-113 is not claimed.
5. **FindAndDelete bounds:** script ≤ 8, needle ≤ 4; general needle chain
   only nSigs ≤ 2. This is why SCR-115 is partial.
6. **L legs are reviewed transliterations**, not `twin/gen.py` output: at
   this pin the twin maps `0xae`/`0xaf` to `OP_UNSUPPORTED_CHECKSIG`. A
   review of the transliteration is the trust anchor, exactly as in the
   existing `C-L-cms-1of1` cell.
7. **No R leg, no whole-engine claim, no NULLFAIL/NULLDUMMY/tapscript**
   (those rows have their own cells or gaps).
8. **Alive2 `undef` caveat:** a cell whose IR contains an `undef` at a
   control-flow join can be reported equivalent even when concrete inputs
   differ. The cell sources avoid uninitialised out-parameters for this
   reason; the mutation check in §4 guards the property.

## 7. Reproduce

From the repo root:

```sh
spec/equiv/cells/e3-cms/C-L-w32-cms-counts/alive2/run.sh
spec/equiv/cells/e3-cms/C-L-w32-cms-counts/saw/run.sh
spec/equiv/cells/e3-cms/C-L-w32-cms-loop/alive2/run.sh      # ≈157 s
spec/equiv/cells/e3-cms/C-L-w32-cms-loop/saw/run.sh
spec/equiv/cells/e3-cms/C-L-w32-cms-finddelete/alive2/run.sh
spec/equiv/cells/e3-cms/C-L-w32-cms-finddelete/saw/run.sh
```

Expected terminal lines: `STATUS=alive2-green` for each lane and
`STATUS=saw-green (54/54 proofs)`, `(120/120)`, `(128/128)` respectively.
