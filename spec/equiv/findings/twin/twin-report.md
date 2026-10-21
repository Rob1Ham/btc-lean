# TWIN-IR report — L-leg E1 base-script surface

Author: TWIN role. Date: 2026-10-19.
Write scope: `spec/equiv/twin/`, `spec/equiv/findings/twin/`.
No Lean source, proof, rule database, or other role's file was modified.
No git commit was made.

---

## 1. Executive summary (≤200 words)

The L leg now has a generated, contract-compatible C++17 twin for the
base-script surface: `TX_WITH_WITNESS` decode, `scriptSig` then
`scriptPubKey` evaluation in `verifyScriptFull` order, the required
stack/altstack/flow opcodes, numeric unary/binary ops, four hash opcodes,
and the P2SH wrapper. Errors cross the ABI as Core `ScriptError` ordinals;
`TwinErr` stays internal. Unsupported opcodes return result 3, never a
verdict.

The pinned clang 20.1.2 lane compiled and ran **146 cases + 58/58 mapping
coverage, 0 failures**. A Core-corpus probe over `stack.jsonl` put **258 of
316 rows in domain; all 258 matched Core's expected verdict**, with 58 rows
excluded because they contain signature opcodes. A g++ ASan+UBSan lane also
passed 147/147.

This is **not** L⊑C equivalence evidence: the Lean tape runner and
differential were not built, and witness/taproot execution, signature
checking, and shim wiring remain outside the subset.

---

## 2. What changed (i)

| Area | Change |
|---|---|
| Generator | `gen.py` now parses `contract/error_kind.h`, emits the `TwinErr` enum and a total `CORE_MAP`, and substitutes into `runtime.inc`. `ops_ir.py` holds the handler IR; `runtime.inc` holds structural code. A wire-table check rejects any missing or duplicate wire in `0x00..0xff`, so dispatch has no silent fallthrough. |
| Boundary | Normative `equiv_entry` (ABI v2, mandatory `equiv_error_kind*`), plus `entry`/`twin_entry` wrappers. Result 2 for domain failures; result 3 and `UNKNOWN_ERROR` for unsupported/unjudged; result 0 with a Core ordinal for consensus rejection; result 1 with `EQUIV_ERR_OK`. |
| Tape | Canonical legacy/extended `TX_WITH_WITNESS` decode; CompactSize canonicality; `scriptSig` extracted from the input; `input_index`, amount, and flag implications checked; trailing bytes rejected. |
| Ordering | `SIGPUSHONLY` precheck → `scriptSig` → save stack → `scriptPubKey` → truth → bare-witness tail → P2SH (push-only, redeem, truth, cleanstack, witness tails). |
| Stack/flow | `DUP DROP SWAP ROT TOALTSTACK FROMALTSTACK 2DROP 2DUP 3DUP 2OVER 2ROT 2SWAP IFDUP DEPTH PICK ROLL TUCK NIP OVER`, `IF NOTIF ELSE ENDIF VERIFY`, `EQUAL/EQUALVERIFY/SIZE`, `NOP/NOP1/4..10`, `CODESEPARATOR`, `RETURN`. |
| Numeric | 4-byte `CScriptNum` unary/binary surface (`1ADD`…`WITHIN`), minimal-data decode for numeric operands and `PICK/ROLL`. |
| Hashes | Self-contained SHA-256 and RIPEMD-160; `RIPEMD160`, `SHA256`, `HASH160`, `HASH256` pinned by known-answer tests. |
| P2SH | Reachable wrapper with push-only `scriptSig`, redeem evaluation, `CLEANSTACK`, `WITNESS_MALLEATED_P2SH`, `WITNESS_UNEXPECTED`. |
| Flags | `P2SH`, `SIGPUSHONLY`, `MINIMALDATA`, `CONST_SCRIPTCODE`, `CLEANSTACK`, `DISCOURAGE_UPGRADABLE_NOPS`, witness bookkeeping implemented. `CLTV`/`CSV` are no-ops with their flags off and result 3 with them on; `CHECKSIGADD` under base is `BAD_OPCODE`. Signature-policy bits are explicitly inert because their only readers (`CHECKSIG*`, `CHECKMULTISIG*`) return 3. |
| Evidence | `smoke_driver.cpp` uses real tapes and now covers every new op, underflow, altstack-empty, P2SH, hashes, tx domain errors, and unsupported-op mapping. `corpus_probe.py` builds stack-family tapes and diffs against Core's corpus expectations. |
| Docs | `README.md` and `generator.md` updated to the E1 surface. |

`gen.py --check` remains green. Generated artifact:
`sha256 39ab7c66ea112ea0108e6f2b93c6bbb8ad0b8261f3230310c989cb8d0af2478f`,
77,830 bytes. IR:
`sha256 e5fbe72707a43bfc950ad67e4a86eff3c4c3c4314aa17323c2a23b9f3cfd6413`.

---

## 3. Commands and real outputs (ii)

### 3.1 Pinned clang lane — ran

```sh
cd spec/equiv/twin
CXX=clang++-20 ./smoke.sh --require-clang
```

Observed:

```text
== generate ==
wrote .../build/twin.cpp (77830 bytes)
wrote .../build/twin.ir.json
OK: .../build/twin.cpp matches generator output
generated sha256: 39ab7c66ea112ea0108e6f2b93c6bbb8ad0b8261f3230310c989cb8d0af2478f
ir        sha256: e5fbe72707a43bfc950ad67e4a86eff3c4c3c4314aa17323c2a23b9f3cfd6413

== pinned-clang: clang++-20 ==
Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)
flags: -std=c++17 -O0 -fno-strict-aliasing -Wall -Wextra -I .../contract
mapping_coverage             PASS (58/58)
...
cases=147 failures=0
RESULT[pinned-clang]: PASS
SMOKE: PASS (pinned clang lane ran)
```

The compiler matches `PINS.lock` (`clang = 20.1.2`; `/usr/bin/clang++-20`).

### 3.2 Development sanitizer lane — ran, not evidence

```sh
g++ -std=c++17 -O0 -fno-strict-aliasing -Wall -Wextra -I ../contract \
    -fsanitize=address,undefined -fno-omit-frame-pointer \
    build/twin.cpp smoke_driver.cpp -o build/smoke-asan
ASAN_OPTIONS=detect_leaks=0 ./build/smoke-asan
```

Observed: `cases=147 failures=0`, exit 0, no ASan/UBSan report. This is a
development lane, **not** pinned-clang evidence.

### 3.3 Core-corpus differential — ran

```sh
cd spec/equiv
CXX=clang++-20 python3 twin/corpus_probe.py --json twin/build/stack_probe.json
```

Observed:

```text
rows=316
in_domain=258 out_result3=58 match=258 mismatch=0
  in  ss=empty    flags  : 9
  in  ss=nonempty flags  : 213
  in  ss=empty    noflags: 0
  in  ss=nonempty noflags: 36
  out ss=empty    flags  : 47
  out ss=nonempty flags  : 5
  out ss=empty    noflags: 0
  out ss=nonempty noflags: 6
unsupported opcode rows (structural): CHECKMULTISIG=31, CHECKMULTISIGVERIFY=24, CHECKSIG=3
corpus differential: PASS (all in-domain rows match Core corpus)
```

The probe compiles `build/libtwin.so` with clang++-20, assembles a
`TX_WITH_WITNESS` tape from each row's `script_sig`/`script_pubkey` via
`spec/core/Test/Script/Parser/ref.py` (read-only), and calls `equiv_entry`.
The corpus `expected` field is Core's verdict at the pin; this is a
Core-corpus differential, **not** the Lean differential.

---

## 4. Stack-family reach (iii)

`corpus/selections/stack.jsonl`, 316 rows. “Empty” means the decoded
`scriptSig` has zero bytes. (56 rows have an empty `scriptSig` text before
and after whitespace normalization; all 316 rows have
`witness_form=false`; 42 rows have an empty flag string.)

| scriptSig | flags | in domain | result 3 | total |
|---|---:|---:|---:|---:|
| empty | non-empty | 9 | 47 | 56 |
| non-empty | non-empty | 213 | 5 | 218 |
| empty | empty | 0 | 0 | 0 |
| non-empty | empty | 36 | 6 | 42 |
| **total** | | **258** | **58** | **316** |

All 258 in-domain rows match Core's expected `(result, error_kind)`. The 58
excluded rows all contain `CHECKSIG`/`CHECKMULTISIG` opcodes structurally;
the counts are mutually exclusive in this selection (CMS 31, CMSVERIFY 24,
CHECKSIG 3). No P2SH-shaped `scriptPubKey` exists in this family, so P2SH is
tested synthetically in the smoke driver.

---

## 5. Findings status

### F-DIV-TWIN-001 — Lean eager parse vs Core per-op decode: **OPEN**

Lean `evalScriptBytes` validates the whole script before execution; Core
decodes per iteration. The twin mirrors Lean deliberately. Smoke case
`fdiv_eager_parse` (`OP_VERIFY` + truncated push) returns `BAD_OPCODE`,
where Core would hit `INVALID_STACK_OPERATION` first. The twin was not
changed toward Core. Malformed-tail rows remain outside L⊑C cells until the
model owners choose a disposition.

### F-DIV-TWIN-002 — `CONST_SCRIPTCODE` on an unexecuted `CODESEPARATOR`: **OPEN**

Lean's pre-dispatch check `w = 0xab ∧ sv = base ∧ pol.constScriptCode`
fires even when the opcode is in an unexecuted branch (`Defs.lean:833`).
Core checks `OP_CODESEPARATOR` inside the executed switch, so it skips the
opcode when `fExec` is false and returns no error. The twin mirrors Lean.
Smoke cases: `codesep_const_unexecuted` (`OP_0 IF CODESEPARATOR ENDIF 1`,
CONST flag) returns `OP_CODESEPARATOR`; the same script without the flag
passes. This needs the same disposition as F-DIV-TWIN-001.

### F-ERR-TWIN-001 — error enum reconciliation: **RESOLVED (boundary)**

`gen.py` resolves every boundary name against `contract/error_kind.h`
(`EQUIV_ERR_*`) rather than copying Lean-derived ids. `CORE_MAP` is total,
with `static_assert`s on `TWIN_OK`, the sentinels, and enum shape, plus a
58/58 runtime walk. Unsupported/bad-input/unjudged map to `UNKNOWN_ERROR`
and result 3/2, never to 0/1. Examples of the changed boundary values:
`EVAL_FALSE = 2` (was 14), `BAD_OPCODE = 16` (was 1),
`INVALID_STACK_OPERATION = 18` (was 6).

### F-TOOL-TWIN-001 — no pinned clang: **RESOLVED: clang 20.1.2**

Ubuntu clang 20.1.2 is installed at `/usr/bin/clang++-20`; the pinned lane
ran and is recorded in §3.1. No clang result is simulated.

### F-UB-TWIN-001 — Lean `Int` vs Core `int64_t`: **DORMANT on this surface**

Supported numeric operands are 4-byte `CScriptNum`; unary/binary arithmetic
cannot overflow `int64_t`. Results may serialise to 5 bytes and are then
rejected by the next numeric decode, matching Core. Wider (`CLTV/CSV`, 5-byte)
paths are unsupported and return 3. The finding reopens if a future opcode
can produce an out-of-`int64_t` value.

---

## 6. Remaining blockers (iv)

1. **Lean differential not run.** No Lean tape runner over `verifyScriptFull`
   and no JSON-lines tape binary exist in this workstream. The Core-corpus
   probe is not a substitute.
2. **No LLVM IR / equivalence artifact.** The twin has not been compiled to
   LLVM IR, run through Alive2/SAW, or compared leaf-by-leaf. No cell is
   green.
3. **Witness/taproot execution (E4).** v0/v1 witness programs and taproot
   paths return result 3 after the malleated/precondition checks. Witness
   vectors cannot be judged yet.
4. **Signature checking (E3).** `CHECKSIG*`, `CHECKMULTISIG*`, and `SHA1`
   are unsupported; this is why the 58 stack rows are excluded.
   `CHECKSIGADD` is `BAD_OPCODE` under base (correct consensus), not
   unsupported. Signature-policy flags are inert only on the excluded path.
   `CLTV`/`CSV` with their activation flags on are also unsupported (result
   3); with the flags off they are consensus no-ops and pass.
5. **Shim wiring.** `shims/twin/entry.cpp` remains a stub and is outside this
   role's write scope; the generated `equiv_entry` is exercised directly.
6. **Mutation/LLVM lanes not run.** No IR mutation run, no per-op leaf
   wrappers, no `-emit-llvm` inspection.
7. **Corpus tape builder is script-text based.** It covers the stack family;
   witness tapes and the 1,258-row corpus are not yet driven through the
   twin.

---

## 7. Handoff

- To **CONTRACT/CORE-IR**: wire the generated `equiv_entry` into
  `shims/twin/entry.cpp` (or replace the stub with a call), and provide the
  Lean tape runner/JSON-lines format.
- To **E2/E3/E4 owners**: signature ops, `SHA1`, `CLTV/CSV`, and
  witness/taproot execution are declared result-3 boundaries; adding them
  requires new `OPS` entries with Lean anchors and new smoke/corpus cases.
- To **REDTEAM**: mutate `ops_ir.py` bodies (swap order, underflow guards,
  push value) and require the corresponding smoke/corpus case to fail.
