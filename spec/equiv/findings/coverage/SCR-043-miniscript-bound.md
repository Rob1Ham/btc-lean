# SCR-043 — `MAX_PUBKEYS_PER_MULTI_A = 999` is a miniscript/wallet construction bound, outside the `VerifyScript` contract

- **row:** SCR-043, family `limits`
- **claim (rules.yaml):** "tapscript multisig-mimic bound (miniscript-side resource limit)"
- **core anchor:** `script.h:37-38@cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
- **census face:** `BitcoinProofs.AF.PDW36.MAX_PUBKEYS_PER_MULTI_A_eq` (a `rfl` constant identity)
- **disposition:** **(b) inapplicable to the script-interpreter equivalence
  harness — wallet/miniscript construction obligation (`MS-035`), not an
  interpreter or consensus check. No cell, no green; the ledger entry stays
  `gap`.**
- **investigated:** 2026-10-21 on base `76dbfe5e42f8a337e41a7308158b0de078afafd9`
  (worktree `wave65/07-scr-043`), Core pin `cce32b168`, Lean model `4d62a97`
- **supersedes:** the 2026-10-20 revision of this file. Substantive changes:
  option (a) is now examined and rejected on model-target grounds (§3), the
  earlier note's interpreter line numbers are corrected (they were taken from
  a P-CORE-01-patched working tree), and a real three-shim ABI experiment
  replaces the purely textual argument (§4).

## 1. Verdict

SCR-043 conflates two different propositions with two different constants:

| | proposition | where enforced | status |
|---|---|---|---|
| **P1** | `multi_a` with more than 999 keys is **rejected at construction/parse** | `script/miniscript.h` `Parse`/`DecodeScript`, `descriptor.cpp`, `solver.cpp` | wallet/miniscript, **not modelled** (`MS-035`); outside this contract |
| **P2** | a tapscript that would need more than 1000 stack elements **fails at execution** | `interpreter.cpp:1865` (initial stack), `:1232` (mid-script) with `MAX_STACK_SIZE = 1000` | consensus, row **SCR-029**, already both-tool green |

The row's check is P1: a *construction* predicate on the miniscript /
descriptor side. The constant `MAX_PUBKEYS_PER_MULTI_A = 999` is never read by
`VerifyScript`, and the normative ABI has no descriptor/miniscript input
channel through which a tape could reach it. P2 is the interpreter-observable
limit in this area, it belongs to a different row and different constant, and
it is already discharged. SCR-043 therefore cannot be closed by an
interpreter cell, and a cell for P1 would be a wallet-layer cell (or a
contract change), not an SCR row.

## 2. Pin evidence

All source facts below are read from the pin object (`git show
HEAD:<path>`), not from a working tree. The shared `/tmp/pcore01` checkout is
dirty with an unrelated experimental P-CORE-01 patch to
`interpreter.cpp`/`script.h`; that patch does not touch the constant but it
shifts line numbers, which is why the earlier revision's line citations were
wrong (§6). Exact commands and raw output: `logs/source-facts.txt`.

### 2.1 The constant and every `src/` use at the pin

```
$ git -C /tmp/pcore01 grep -n MAX_PUBKEYS_PER_MULTI_A HEAD -- src
HEAD:src/script/descriptor.cpp:2469   ... providers.size() > MAX_PUBKEYS_PER_MULTI_A
HEAD:src/script/descriptor.cpp:2470   ... error = "Cannot have %u keys in multi_a ..."
HEAD:src/script/miniscript.cpp:79     CHECK_NONFATAL(n_keys >= 1 && n_keys <= MAX_PUBKEYS_PER_MULTI_A)
HEAD:src/script/miniscript.h:1879     max_keys{is_multi_a ? MAX_PUBKEYS_PER_MULTI_A : MAX_PUBKEYS_PER_MULTISIG}
HEAD:src/script/miniscript.h:2404     if (*k < 1 || *k > MAX_PUBKEYS_PER_MULTI_A) return {}
HEAD:src/script/miniscript.h:2418     if (keys.size() > MAX_PUBKEYS_PER_MULTI_A) return {}
HEAD:src/script/script.h:38           inline constexpr unsigned int MAX_PUBKEYS_PER_MULTI_A = 999;
HEAD:src/script/solver.cpp:124        if (keyspans.size() == 0 || keyspans.size() > MAX_PUBKEYS_PER_MULTI_A) return {}
```

No other `src/` reference exists. In particular:

```
$ git show HEAD:src/script/interpreter.cpp | grep MAX_PUBKEYS_PER_MULTI_A   # rc=1, no match
$ git show HEAD:src/script/interpreter.h   | grep MAX_PUBKEYS_PER_MULTI_A   # rc=1, no match
$ git grep MAX_PUBKEYS_PER_MULTI_A HEAD -- src/consensus                    # rc=1, no match
```

The three parse/construction enforcement sites are inside three different
functions, all downstream of a key/script provider:

| site | enclosing function | layer |
|---|---|---|
| `miniscript.h:1879` + `:1901` | `internal::Parse` (`:1854`), lambda `parse_multi_exp` (`:1878`) | miniscript **string** parser (`FromString` at `:2685`) |
| `miniscript.h:2404`, `:2418` | `internal::DecodeScript` (`:2296`) | miniscript **script** decoder (`FromScript` at `:2691`) |
| `descriptor.cpp:2469-2470` | descriptor `multi_a`/`sortedmulti_a` parse | descriptor layer |
| `solver.cpp:124` | template solver (recognition only) | policy/template inference |
| `miniscript.cpp:79` | `internal::ComputeType` | internal sanity check on an already-built node |

### 2.2 The contract has no channel for any of them

`contract/ABI.md` §1 fixes the only proof-bearing entry point:

```c
extern "C" int equiv_entry(
    const uint8_t *tx_bytes, uint64_t tx_len,   /* serialized tx */
    const uint8_t *spk,      uint64_t spk_len,  /* scriptPubKey, raw bytes */
    int64_t amount, uint32_t input_index, uint64_t flags,
    equiv_error_kind *error_kind);
```

`shims/core/entry.cpp` contains no `Miniscript` or `Descriptor` token (grep
rc=1); it deserializes a transaction and calls `VerifyScript`. The
`ir/manifest.json` C closure is 15 TUs and contains no
`script/miniscript.cpp`, `script/descriptor.cpp` or `script/solver.cpp`
(extracted TU list in `logs/source-facts.txt`). A descriptor string or a
miniscript AST is not a tape input, so no in-domain tape can distinguish
`MAX_PUBKEYS_PER_MULTI_A = 999` from any other value. That is a statement
about reachability, not about missing test coverage.

## 3. Option (a) examined: can the bound be stated independently of `FromString`?

The task of this row is to decide whether a faithful model/cell for the
miniscript-side bound exists that does **not** depend on the unmodelled wallet
`FromString`. Three candidate shapes were considered. None is faithful.

### 3.1 Constant-identity cell — rejected

A leaf proving `999 = 999`, or `999 < 1000`, against the C constant is a
restatement of the definition. It is not an equivalence of any behaviour the
row names, and entering it as `both-green` would claim script-interpreter
coverage for a wallet-only constant. This is the same rejection recorded in
`findings/wave16/03-limits-accounting/report.md` §4. The pinned Lean theorem
`PDW36.MAX_PUBKEYS_PER_MULTI_A_eq` is exactly this identity
(`spec/proofs/BitcoinProofs/AF/PDW36/PDW36.lean:196`), and
`MAX_PUBKEYS_PER_MULTI_A_lt_thousand` (`:200-203`) is the arithmetic
`999 < 1000`. Neither is an enforcement theorem.

### 3.2 `Node.calcType` vs `internal::ComputeType` — a model-target mismatch

This is the one pairing that looks plausible, because the pinned Lean tree
*does* carry the bound in a type computation:

```lean
-- spec/core/Bitcoin/Wallet/Miniscript/Node.lean:441-443
| .multiA k ks =>
  if ctx = .p2wsh || k = 0 || k > ks.length || ks.length > 999 then MSType.empty
  else ty [.B, .u, .d, .e, .m, .s, .k]
```

and Core's `internal::ComputeType` has the corresponding line
(`miniscript.cpp:79`). But the two behaviours differ for exactly the
out-of-range input the row is about:

- Lean returns `MSType.empty`; `Node.type` sanitizes it to the empty type, so
  `IsSane` rejects the node.
- Core's `CHECK_NONFATAL` **throws** `NonFatalCheckError` when the condition
  is false (`util/check.h:72-79`; `NDEBUG` is a compile error at
  `check.h:83-85`, so the throw is live in every supported build). It does not
  return an empty type and it does not return a rejection verdict.

The Lean file says why the empty type is there: it is a **surrogate for
parse-time rejection**, not a transliteration of `ComputeType` on invalid
input —

> "Invalid parameters that Core rejects while parsing (for example
> `older(0)`, `multi(k)` with `k > n`, or a `multi_a` outside tapscript)
> yield the empty type, so that `IsSane` rejects them."
> — `Node.lean:15-21`

So the Lean bound presupposes the parser it does not have. Pairing
`calcType` with `ComputeType` would compare `empty type` against `throw`, on
an input the Core parser can never construct. It would be a cell for a
different function and a different verdict domain, and would not discharge
the row. (It would also still be a wallet-layer function, not an interpreter
one.)

### 3.3 A parser/rejection cell — blocked by the missing L model and ABI

The actual enforcement is `parse_multi_exp` (`miniscript.h:1878-1911`):

```
const auto max_keys{is_multi_a ? MAX_PUBKEYS_PER_MULTI_A : MAX_PUBKEYS_PER_MULTISIG};
...
auto key = ctx.FromString(sp);          // per-key provider
...
if (keys.size() < 1 || keys.size() > max_keys) return false;
if (k < 1 || k > (int64_t)keys.size()) return false;
```

The count test is interleaved with per-key `ctx.FromString`, key de-duplication
and `script_size` accounting, and the whole lambda is templated over `Key` and
`Ctx` with `std::span`/`std::vector` arguments. There is no scalar leaf that
can be extracted without rewriting the parser. On the Lean side:

- `spec/core/Bitcoin/Wallet/Miniscript.lean:18-19` states the scope limit:
  "no policy compiler, no descriptor parser, no `ToString` or `FromScript`".
- Wallet obligation `MS-035` is recorded as *unmodelled* precisely because
  "the parser object is absent, not merely unproved":
  `spec/db/rules-wallet.obligations.tsv:66` (`MS-035`), status `planned`,
  `lean_target: null`, `consensus: false`
  (`spec/db/rules-wallet.yaml:860-871`).
- The descriptor path is unmodelled too: `Wallet/Descriptor.lean:44-45`
  lists "miniscript, and taproot script trees (`tr(key,tree)`)" under
  **what is not modelled**, so `descriptor.cpp:2469-2470` has no L target
  either.

A cell here would need a new contract (byte-array input + a key-provider
stub), a new Lean `Parse` model, and a wallet-layer cell family. That is not
a refinement of SCR-043; it is `MS-035`'s work item.

**Conclusion:** option (a) does not exist. The bound cannot be stated
independently of the unmodelled parser without either restating the constant
(3.1) or mis-pairing two different functions (3.2).

## 4. What is observable: a three-shim ABI experiment

To close the interpreter question empirically rather than only by grep, three
Core shims were built from **clean pin** source with the same recipe as
`shims/core/entry.cpp`:

| shim | change to `script.h` | purpose |
|---|---|---|
| `base` | none | pin behaviour |
| `mut-pubkeys` | `MAX_PUBKEYS_PER_MULTI_A 999 -> 1` | the row's constant |
| `mut-stack` | `MAX_STACK_SIZE 1000 -> 999` | positive control: a constant the interpreter **does** read |

The corpus is 14 normative tapes. Every taproot case is a **valid single-leaf
BIP341 script-path spend** (commitment computed, control block accepted), so
the shim actually reaches `EvalScript`; `multi_a`-shaped scripts of
`N = 1, 2, 20, 21, 998, 999, 1000, 1001, 1005` keys carry `N` empty signature
slots. BIP342 treats an empty slot as "not signed" (`success = false`) without
aborting (`EvalChecksigTapscript`, `interpreter.cpp:357`), so the whole chain is traversed and the
stack limit is reached, independent of signature validity. `N = 999` is also
run with threshold `k = 999`. A tampered control-block parity is the
commitment-check sanity case. Corpus generator: `tapegen.py` (deterministic;
pure-Python BIP341/BIP340 commitment construction).

Result (`logs/observability.txt`; `result/error_kind`, ordinals from
`contract/error_enum.md`):

| case | base | mut-pubkeys | mut-stack |
|---|---|---|---|
| legacy OP_1 / OP_0 | `1/0` / `0/2` | same | same |
| taproot script-path OP_1 | `1/0` | same | same |
| `multi_a` N=1,2,20,21,998 | `0/2` EVAL_FALSE | same | same |
| **`multi_a` N=999 (k=1 and k=999)** | **`0/2` EVAL_FALSE** | **same** | **`0/8` STACK_SIZE** |
| `multi_a` N=1000,1001,1005 | `0/8` STACK_SIZE | same | same |
| control parity flipped | `0/40` WITNESS_PROGRAM_MISMATCH | same | same |

- `base` and `mut-pubkeys` agree on **14/14** cases. Changing the row's
  constant to 1 changes nothing observable through the ABI.
- `base` and `mut-stack` differ on exactly the two N=999 cases, so the corpus
  and the ABI do detect an interpreter-read constant. The experiment is not
  vacuous.
- The execution boundary sits at `N = 999`/`N = 1000`, and it is enforced by
  `MAX_STACK_SIZE` (initial stack at `interpreter.cpp:1865`, mid-script at
  `:1232`), not by `MAX_PUBKEYS_PER_MULTI_A`. This is the mechanism the
  `script.h` comment names ("due to the stack limit in BIP342").
- No signature is claimed valid here; the corpus exercises the stack and
  error paths, not crypto. Crypto remains the declared same-crypto premise.

The new `base` shim also reproduces the fleet shim
`/tmp/opencode/cbuild/libequiv-core.so` on all 14 cases (0 differences), and
both reproduce the E0 hello-world cases, so the build is not a bespoke
semantics.

## 5. The consensus limits actually in this area

- `MAX_PUBKEYS_PER_MULTISIG = 20`, enforced for `OP_CHECKMULTISIG` at
  `interpreter.cpp:1127` — row **SCR-026**, green
  (`limits/C-L-cms-count-bounds`).
- `MAX_STACK_SIZE = 1000`, enforced at `interpreter.cpp:1865` and `:1232` —
  row **SCR-029**, green (`limits/C-L-stack-limit`).
- `MAX_SCRIPT_SIZE = 10'000` is checked only for `BASE`/`WITNESS_V0`
  (`interpreter.cpp:438`), which is why a 34 KB tapscript is admitted and
  then stopped by the stack bound; row **SCR-018/019**, green.

`999 < 1000` is a calibration fact, not a consensus predicate. The pinned
Lean model says the same in `Interpreter/Rules.lean:346-351` ("a
miniscript-side resource limit, not an interpreter check ... it bounds script
construction").

## 6. Ledger and census metadata (reported, not edited)

1. The ledger entry (`spec/db/equiv-cells.yaml`, SCR-043) is **correct in
   substance**: `status: gap`, no cells, no tool runs. It is generated; this
   finding does not edit it.
2. Two line citations in the existing gap note are **not pin line numbers**:
   `interpreter.cpp:1195` and `:1309` are the P-CORE-01-patched working-tree
   offsets. At the pin (`git show HEAD`), the same code is at `:1127`
   (`MAX_PUBKEYS_PER_MULTISIG`), `:1232` (mid-script stack check) and `:1865`
   (initial stack check). The substance of the note is unaffected; the
   numbers should be corrected whenever the generated ledger is regenerated.
3. `spec/db/rules.yaml` marks SCR-043 `consensus: true`, while the row's own
   text says "miniscript-side resource limit" and the wallet census records
   the same behaviour as `MS-035` with `consensus: false`. This is an
   inconsistency for the census maintainers. `rules.yaml` is generated and
   was **not** hand-edited.
4. The `status: proven` in `rules.yaml` is accurate only in the narrow sense
   that a Lean constant definition carries an `@[rule "SCR-043"]` tag; it is
   not an enforcement theorem.

Recommended disposition for the ledger owner (not performed here): keep the
row `gap` with this finding, or reclassify it as wallet `consensus: false`
and let `MS-035` own it. Do not add an interpreter cell.

## 7. Smallest future experiment

**For SCR-043 as written (construction bound):** a **wallet-layer** experiment,
not an SCR cell.

1. Model the `multi_a` branch of `internal::Parse` in
   `spec/core/Bitcoin/Wallet/Miniscript` (context check, `k` bound, key-count
   bound, per-key `ctx.FromString` contract, de-duplication). This is
   `MS-035`; start from the existing `Node` representation and the
   `Wallet/Descriptor.lean` key-provider boundary.
2. Add an ABI that can carry a descriptor string plus a key-provider map
   (a contract v4 extension; `equiv_entry` cannot), and pair the model with a
   compiled C++ leaf of `Parse`/`parse_multi_exp`.
3. Record it under `rules-wallet.yaml` (`MS-035`, `consensus: false`), not
   under SCR-043.

That is the minimum faithful experiment, and it discharges the *wallet*
obligation. It does not create an interpreter row.

**For the interpreter-observable face (P2):** no experiment is missing.
SCR-029 already owns `MAX_STACK_SIZE`; §4's `mut-stack` control shows the ABI
distinguishes it at N=999. If a formal bridge is wanted — "a parse-accepted
`multi_a` (≤ 999 keys) cannot overflow the execution stack" — that is a
wallet+interpreter composition requiring `MS-032` (`CheckStackSize` /
`GetExecStackSize`, recorded unmodelled) plus the `N+1` stack accounting for
the `CHECKSIG`/`CHECKSIGADD` chain. It would still be a wallet theorem, not
SCR-043's construction predicate, and it is strictly more work than the
mutation control that already settles the interpreter question.

## 8. Reproduce

```sh
# pin and source facts (read the pin object, not a dirty working tree)
git -C /tmp/pcore01 rev-parse HEAD                       # cce32b168...
git -C /tmp/pcore01 grep -n MAX_PUBKEYS_PER_MULTI_A HEAD -- src
git -C /tmp/pcore01 show HEAD:src/script/interpreter.cpp | grep MAX_PUBKEYS_PER_MULTI_A  # rc=1

# three shims from clean pin source + corpus + ABI run
sh spec/equiv/findings/coverage/SCR-043-miniscript-bound/build_variants.sh
cd spec/equiv/findings/coverage/SCR-043-miniscript-bound
python3 tapegen.py --out /tmp/opencode/w65-07/corpus.json
python3 run_observability.py --corpus /tmp/opencode/w65-07/corpus.json \
  --lib base=/tmp/opencode/w65-07/lib/libequiv-core-base.so \
  --lib mut-pubkeys=/tmp/opencode/w65-07/lib/libequiv-core-mut-pubkeys.so \
  --lib mut-stack=/tmp/opencode/w65-07/lib/libequiv-core-mut-stack.so \
  --tsv /tmp/opencode/w65-07/results.tsv
# expected: SCR043_OBSERVABILITY_OK
```

The scripts default `W=/tmp/opencode/w65-07`, `CORE_SRC=/tmp/pcore01`;
`build_variants.sh` re-archives the pin commit with `git archive` before
patching, so the mutant builds cannot inherit working-tree edits.

## 9. Evidence hashes

`logs/hashes.txt` records SHA-256 for the corpus, result table, three
libraries, the pinned source files (`git show HEAD:<path> | sha256sum`), the
three variant `script.h` files, and these scripts. Key values:

| artifact | SHA-256 |
|---|---|
| `libequiv-core-base.so` | `6d8297c698a3b8fc099046832d76900c3b2c92dee39bced9c7eeab2e9f0c874e` |
| `libequiv-core-mut-pubkeys.so` | `528ce4b9a4b7338df291bad6ad11eb7562e1348a78d4a4e76db7a1edd140a1f5` |
| `libequiv-core-mut-stack.so` | `0397adf842876471d87c956f7766bac1c81f4ccd8d875451d448f5c8229ee746` |
| `corpus.json` | `0db747efaa745d9f47c30b0a6d8a53f907bd7086dcf87ddaaf32141b99a456f1` |
| `results.tsv` | `871a51aab24104cce87550494cf5fdbe9c54fe4559a8583e4d7a4b7cea4451ba` |
| `results-fleet.tsv` (cross-check) | `4374f402e0c2b9c682c5628ea1c8bb318de426b8a6efab09c7e056ec711e2973` |
| fleet `libequiv-core.so` (cross-check) | `5fef1df004adae637ffd7d3d7bf7dc96700c552dc2c22729d0de06d81457fbb5` |
| pin `script.h` | `43e4eb10ee85ac31996e257d0c5dc45cbe3b29b2d61d1a72d101453ba64ded01` |
| pin `interpreter.cpp` | `57a6f328c7e6202f499e48366a86eb26e09c8ebb78e92eef7e839207230be333` |

## 10. Non-claims

- This report does not claim SCR-043 is false, obsolete, or discharged.
- It does not claim a miniscript or descriptor proof exists; neither parser is
  modelled.
- It does not claim any signature is valid in the experiment; empty signature
  slots are used precisely to traverse the stack path without crypto.
- It does not claim `MAX_PUBKEYS_PER_MULTI_A` is a consensus rule, nor that
  changing it is safe for wallet software — only that it is unobservable
  through the `VerifyScript` ABI at this pin.
- No cell, certificate, ledger entry, matrix, contract, pin, proof, or tool
  result is added or changed by this finding.
