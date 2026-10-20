# `twin/` — the L leg (Lean-derived C++ twin)

This directory owns the **L leg** of `spec/equiv`: a C++17 twin generated from
the btc-lean interpreter model. The Lean source is the specification of record;
nothing here modifies it.

**Current status: E1 base-script surface.** The generated twin decodes
`TX_WITH_WITNESS`, evaluates `scriptSig` then `scriptPubKey` in
`verifyScriptFull` order, implements the stack/altstack/flow family, numeric
unary/binary ops, the four SHA-256/RIPEMD-160 hash opcodes, and the P2SH
wrapper. Signature checking and witness/taproot execution remain outside the
subset and return result `3` (never a verdict). This is not yet full-engine
equivalence evidence.

| Artifact | Role |
|---|---|
| `gen.py` | Lean → IR → C++ generator; error enum/Core map; drift gate |
| `ops_ir.py` | opcode IR table: handler body + wire byte(s) + `Lean:` anchor |
| `runtime.inc` | structural C++ template (stack, GetOp, EvalScript, tx, VerifyScript) |
| `generator.md` | design, mapping, error taxonomy, audit story |
| `smoke_driver.cpp` | hand-written contract harness (not engine logic) |
| `smoke.sh` | generate + drift check + compile + run (pinned clang lane) |
| `corpus_probe.py` | builds tapes for `corpus/selections/stack.jsonl`, runs the twin |
| `build/` | generated artifacts (disposable, never hand-edited) |
| `../findings/twin/` | reports, risks, divergence findings |

---

## Quick start

```sh
cd spec/equiv/twin
CXX=clang++-20 ./smoke.sh --require-clang   # pinned lane (clang 20.1.2)
python3 corpus_probe.py                      # Core-corpus differential, stack family
python3 gen.py --out build/twin.cpp --dump-ir build/twin.ir.json
python3 gen.py --check build/twin.cpp        # drift gate: exit 1 on hand edits
```

`--require-clang` exits 77 when the requested compiler is absent. A g++ lane is
available explicitly and is labelled **NOT EVIDENCE**; it exercises the
generator, not the pinned front-end.

---

## Supported subset (E1)

- **Tape**: one canonical `TX_WITH_WITNESS` (legacy or extended form), one
  input, `input_index` in range; non-canonical CompactSize, trailing bytes,
  bad flags, and out-of-range indices return `2`.
- **Pushes**: `OP_0`, direct 1–75, `PUSHDATA1/2/4`, `OP_1NEGATE`, `OP_1..16`
  (full `GetOp` structure, eager parse).
- **Stack/altstack**: `DUP DROP SWAP ROT TOALTSTACK FROMALTSTACK 2DROP 2DUP
  3DUP 2OVER 2ROT 2SWAP IFDUP DEPTH PICK ROLL TUCK NIP OVER`, plus
  `EQUAL EQUALVERIFY SIZE`.
- **Flow**: `IF NOTIF ELSE ENDIF VERIFY`; `NOP`, `NOP1/4..10`,
  `CODESEPARATOR`; `RETURN` returns its consensus error.
- **Numeric**: `1ADD 1SUB NEGATE ABS NOT 0NOTEQUAL ADD SUB BOOLAND BOOLOR
  NUMEQUAL NUMEQUALVERIFY NUMNOTEQUAL LESSTHAN GREATERTHAN LESSTHANOREQUAL
  GREATERTHANOREQUAL MIN MAX WITHIN` on 4-byte `CScriptNum`.
- **Hashes**: `RIPEMD160 SHA256 HASH160 HASH256`.
- **P2SH**: push-only `scriptSig`, redeem-script evaluation, cleanstack,
  witness-malleated/unexpected tails.
- **Flags**: `P2SH`, `SIGPUSHONLY`, `MINIMALDATA`, `CONST_SCRIPTCODE`
  (`OP_CODESEPARATOR`), `CLEANSTACK`, `DISCOURAGE_UPGRADABLE_NOPS`, and the
  witness bookkeeping bits. `CLTV`/`CSV` are no-ops with their activation
  flags off. Signature-policy bits are accepted and inert only because
  `CHECKSIG`/`CHECKMULTISIG` return result `3`.

`CHECKSIG*`, `CHECKMULTISIG*`, `SHA1`, and witness/taproot script execution
return result `3` / `TWIN_INVALID_UNSUPPORTED` once execution reaches them.
`CHECKSIGADD` is tapscript-only and returns consensus `BAD_OPCODE` under
base/witnessV0; `CLTV`/`CSV` return result `3` only when their activation
flag is on. Result `3` is a declared boundary, not a verdict. Structural
failures that precede dispatch (script size, malformed push, element size, op
budget) still return the consensus error.

Boundary mapping (ABI v2):

| Condition | result | `error_kind` |
|---|---:|---|
| final stack truthy | 1 | `EQUIV_ERR_OK` |
| consensus rejection (incl. `EVAL_FALSE`) | 0 | Core `ScriptError` ordinal |
| malformed harness input | 2 | `EQUIV_ERR_UNKNOWN_ERROR` |
| outside subset / unjudged / internal | 3 | `EQUIV_ERR_UNKNOWN_ERROR` |

`TwinErr` is internal; `CORE_MAP` is one initializer per enumerator, with
compile-time assertions and a 58/58 runtime coverage check. Unsupported and
bad-input sentinels can never name a consensus error.

---

## Invariants

1. **Generated, never hand-edited.** `build/twin.cpp` is reproducible from
   `gen.py` + `ops_ir.py` + `runtime.inc`; `--check` enforces it.
2. **No verdict outside the subset.** A valid opcode the twin does not
   implement ⇒ 3, never 0/1. Reserved/undefined wires and wrong-sigversion
   opcodes follow Lean's consensus error (`BAD_OPCODE`).
3. **Mirror Lean, then compare to Core.** The twin follows Lean ordering
   (including eager `parseWire`); Lean-vs-Core divergences are findings, not
   silent twin edits.
4. **No UB.** Bounds are checked before every read/index; numeric operands are
   4-byte `CScriptNum` in `int64_t`, so supported arithmetic cannot overflow;
   fixed-capacity state means no allocator inside the engine.
5. **Determinism.** No clock, environment, locale, or allocator-dependent
   behavior in the engine; the tape is the only input.
6. **Cell-shaped code.** One `static TwinErr op_<NAME>(State&, const Ctx&,
   const Decoded&)` per handler, with a `Lean:` anchor, so per-op leaf wrappers
   can be emitted later.

---

## Evidence and what is not claimed

- Pinned lane: Ubuntu clang 20.1.2, `-std=c++17 -O0 -fno-strict-aliasing
  -Wall -Wextra`, 146 script cases plus the 58/58 mapping-coverage test
  (147 cases total), 0 failures.
- Core-corpus differential (`stack.jsonl`): 258/316 rows in domain, all 258
  match Core's `expected`; 58 rows return result `3` and are excluded.
- **Not claimed**: Lean differential (no Lean tape runner yet), witness/taproot
  execution, signature checking, full policy-flag behaviour, or shim wiring
  (`shims/twin/entry.cpp` remains outside this role's write scope).
- F-DIV-TWIN-001 (eager parse precedence), F-DIV-TWIN-002
  (`CONST_SCRIPTCODE` on an unexecuted `CODESEPARATOR`), and F-UB-TWIN-001
  (ScriptNum representation) are recorded in
  `../findings/twin/twin-report.md`.
