# Twin generator design — Lean model → imperative IR → C++

Status: **E1 base-script surface**. `gen.py` emits a contract-compatible
C++17 twin that decodes `TX_WITH_WITNESS`, evaluates `scriptSig` then
`scriptPubKey`, implements the stack/altstack/flow family, numeric
unary/binary ops, four hash opcodes, and the P2SH wrapper. It does not yet
implement the full engine: valid consensus opcodes outside the subset return
result `3` (`TWIN_INVALID_UNSUPPORTED`), which is outside every cell's
domain, rather than guessing a verdict. Reserved/undefined wire bytes
(`0xbb..0xff`, plus `OP_RESERVED`/`OP_VER*`/`OP_RESERVED1/2`) follow Lean's
dispatch default and return consensus `BAD_OPCODE`.

Source of record: `spec/core/Bitcoin/Interpreter/Defs.lean` at the repo pin.
Nothing in this directory modifies the Lean sources or proofs.

---

## 1. Why generated, not hand-transliterated

The L leg must be *provably* a lowering of the Lean model, not a second
hand-written interpreter that happens to pass a corpus. A generator buys:

1. **Provenance.** The emitted C++ is a deterministic function of a small,
   reviewable IR. The IR is the only place semantics are transcribed; the
   emitter makes no semantic decisions.
2. **Auditability.** Every IR handler carries a Lean line anchor. A reviewer
   diffs one short handler body against one Lean equation, not 3,000 lines
   of C++.
3. **Reproducibility.** `gen.py --check` proves the checked-in artifact is
   exactly what the generator produces (drift gate). No hand edits.
4. **Mutation-testability.** A one-line IR mutation (e.g. drop the SWAP
   order) changes the emitted twin; REDTEAM's mutation lane then requires the
   cell to go red. A hand transliteration cannot do this cleanly.
5. **Tier growth.** Witness/taproot handlers are added as IR entries with
   their own Lean anchors; the harness and error plumbing do not change.

The fallback (hand transliteration) is explicitly **not** preferred: it
downgrades the L-leg link to "reviewed transliteration", loses the drift
gate, and makes mutation testing ambiguous (the mutant may not be the only
difference from the model). The fallback is reserved for a construct the
generator cannot express, and such a construct must be filed as a gap with
the blocking feature named.

**Honest limitation.** The Lean → IR step is a hand transcription (we do not
parse Lean source). The trust base therefore includes "the IR transcription
is faithful to `Defs.lean`", mitigated by line anchors, review, the
differential oracle (§13), and mutation tests (§14). A future stronger
option — extracting the IR from Lean metaprogramming / `Expr` — is a
post-E1 improvement, not a prerequisite.

---

## 2. Pipeline

```
spec/core/Bitcoin/Interpreter/Defs.lean      (specification of record)
        │  hand transcription, one handler per opcode, line-cited
        ▼
twin/ops_ir.py : OPS (wire(s), handler body, Lean anchor)   (imperative IR)
twin/gen.py    : ERRORS + Core-name map; emits enum, CORE_MAP, dispatch
        │  deterministic substitution into twin/runtime.inc
        ▼
twin/build/twin.cpp                          (C++17, contract entry)
        │  pinned clang -O0 (same front-end as the C leg)
        ▼
LLVM IR artifact used by Alive2 / SAW   (target lane; not produced yet)
```

The IR is dumped as JSON (`--dump-ir`) so the CELLS/audit roles can compare
the semantic table against the emitted code and against `Defs.lean` without
reading Python.

### Trust boundary

| Component | Trusted? | Mitigation |
|---|---|---|
| `Defs.lean` | yes (source of record) | pinned repo |
| IR transcription (`gen.py` tables) | yes, reviewed | line anchors; differential; mutation |
| emitter/templates | yes, reviewed | emits handler bodies verbatim; deterministic |
| C++ runtime prelude (stack, parser, truth) | yes, reviewed | small; unit + differential tests |
| pinned clang | yes | `PINS.lock` |
| Lean runner used as oracle | future lane | **not built yet**; see §13/blockers |
| C++ compiler warnings/UB | gated | `-Wall -Wextra`, dev lane with ASan+UBSan |

---

## 3. Imperative IR

- `ERRORS` (`gen.py`): `(twin enum, stable Lean id, Core name, Lean
  constructor)`. The Core name is resolved against
  `contract/error_kind.h`; a missing name is a generator error.
- `OPS` (`ops_ir.py`): `{wires[], name, Lean anchor, body[]}`. `body` is
  emitted verbatim as the body of
  `static TwinErr op_<name>(State&, const Ctx&, const Decoded&)`.
- Push-shaped wires are handled structurally in `runtime.inc` because the
  payload is variable-length; `Decoded` carries the wire byte and `next`.
- `gen.py` rejects any missing or duplicate wire in `0x00..0xff` before
  emission: pushes/`OP_1NEGATE`/`OP_1..16` are structural, the 15 disabled
  wires are structural, and `OPS` must cover the rest exactly once. The
  dispatch `default` is therefore a table-error sentinel, not a verdict.
- Structural checks live in one place (not per opcode): script-size
  pre-check, eager parse validation, element-size check, 201-op budget,
  disabled-opcode check, CONST_SCRIPTCODE/CODESEPARATOR check, terminal
  1000-element guard, truth test at the boundary.

The IR is deliberately **not** a general-purpose language. If a handler
needs control flow beyond early-return + a small loop, it gets a dedicated
emitter function and a review note; that keeps the emitter honest about
where it is interpreting semantics.

---

## 4. Error-code mapping

Twin IDs are stable and mechanically derived: `TWIN_OK = 0`, and for every
Lean `ExecError` constructor, `id = 1 + zero-based constructor position` in
`Defs.lean:119-177`. This makes an audit a table walk, not a judgment call.
IDs 56–57 are twin-internal sentinels and must never appear as a consensus
verdict.

| id | twin enum | Lean `ExecError` | Core `SCRIPT_ERR_*` |
|---:|---|---|---|
| 0 | `TWIN_OK` | `ok` | `OK` |
| 1 | `TWIN_BAD_OPCODE` | `badOpcode` | `BAD_OPCODE` |
| 2 | `TWIN_PUSH_SIZE` | `pushSize` | `PUSH_SIZE` |
| 3 | `TWIN_OP_COUNT` | `opCount` | `OP_COUNT` |
| 4 | `TWIN_STACK_SIZE` | `stackSize` | `STACK_SIZE` |
| 5 | `TWIN_SCRIPT_SIZE` | `scriptSize` | `SCRIPT_SIZE` |
| 6 | `TWIN_INVALID_STACK_OPERATION` | `stackUnderflow` | `INVALID_STACK_OPERATION` |
| 7 | `TWIN_VERIFY` | `verifyFailed` | `VERIFY` |
| 8 | `TWIN_EQUALVERIFY` | `equalVerifyFailed` | `EQUALVERIFY` |
| 9 | `TWIN_DISABLED_OPCODE` | `disabledOpcode` | `DISABLED_OPCODE` |
| 10 | `TWIN_UNBALANCED_CONDITIONAL` | `unbalancedConditional` | `UNBALANCED_CONDITIONAL` |
| 11 | `TWIN_MINIMALIF` | `minimalIf` | `MINIMALIF` |
| 12 | `TWIN_CLEANSTACK` | `cleanstack` | `CLEANSTACK` |
| 13 | `TWIN_UNKNOWN_ERROR` | `unknownError` | `UNKNOWN_ERROR` |
| 14 | `TWIN_EVAL_FALSE` | `evalFalse` | `EVAL_FALSE` |
| 15 | `TWIN_SCRIPTNUM` | `scriptNum` | `SCRIPTNUM` |
| 16 | `TWIN_NUMEQUALVERIFY` | `numEqualVerifyFailed` | `NUMEQUALVERIFY` |
| 17 | `TWIN_CHECKSIGVERIFY` | `checkSigVerify` | `CHECKSIGVERIFY` |
| 18 | `TWIN_CHECKMULTISIGVERIFY` | `checkMultiSigVerify` | `CHECKMULTISIGVERIFY` |
| 19 | `TWIN_INVALID_ALTSTACK_OPERATION` | `invalidAltstackOperation` | `INVALID_ALTSTACK_OPERATION` |
| 20 | `TWIN_OP_RETURN` | `opReturn` | `OP_RETURN` |
| 21 | `TWIN_SIG_OP_CODESEPARATOR` | `opCodeSeparator` | `OP_CODESEPARATOR` |
| 22 | `TWIN_SIG_FINDANDDELETE` | `sigFindAndDelete` | `SIG_FINDANDDELETE` |
| 23 | `TWIN_SIG_DER` | `sigDer` | `SIG_DER` |
| 24 | `TWIN_SIG_HIGH_S` | `sigHighS` | `SIG_HIGH_S` |
| 25 | `TWIN_SIG_HASHTYPE` | `sigHashType` | `SIG_HASHTYPE` |
| 26 | `TWIN_SIG_NULLDUMMY` | `sigNullDummy` | `SIG_NULLDUMMY` |
| 27 | `TWIN_SIG_NULLFAIL` | `sigNullFail` | `SIG_NULLFAIL` |
| 28 | `TWIN_SIG_PUSHONLY` | `sigPushOnly` | `SIG_PUSHONLY` |
| 29 | `TWIN_PUBKEYTYPE` | `pubKeyType` | `PUBKEYTYPE` |
| 30 | `TWIN_PUBKEY_COUNT` | `pubKeyCount` | `PUBKEY_COUNT` |
| 31 | `TWIN_SIG_COUNT` | `sigCount` | `SIG_COUNT` |
| 32 | `TWIN_NEGATIVE_LOCKTIME` | `negativeLocktime` | `NEGATIVE_LOCKTIME` |
| 33 | `TWIN_UNSATISFIED_LOCKTIME` | `unsatisfiedLocktime` | `UNSATISFIED_LOCKTIME` |
| 34 | `TWIN_SCHNORR_SIG` | `schnorrSig` | `SCHNORR_SIG` |
| 35 | `TWIN_SCHNORR_SIG_SIZE` | `schnorrSigSize` | `SCHNORR_SIG_SIZE` |
| 36 | `TWIN_SCHNORR_SIG_HASHTYPE` | `schnorrSigHashtype` | `SCHNORR_SIG_HASHTYPE` |
| 37 | `TWIN_TAPROOT_DATA_UNAVAILABLE` | `taprootDataUnavailable` | (twin-internal, not Core) |
| 38 | `TWIN_WITNESS_PROGRAM_WRONG_LENGTH` | `witnessProgramWrongLength` | `WITNESS_PROGRAM_WRONG_LENGTH` |
| 39 | `TWIN_WITNESS_PROGRAM_WITNESS_EMPTY` | `witnessProgramWitnessEmpty` | `WITNESS_PROGRAM_WITNESS_EMPTY` |
| 40 | `TWIN_WITNESS_PROGRAM_MISMATCH` | `witnessProgramMismatch` | `WITNESS_PROGRAM_MISMATCH` |
| 41 | `TWIN_WITNESS_MALLEATED` | `witnessMalleated` | `WITNESS_MALLEATED` |
| 42 | `TWIN_WITNESS_MALLEATED_P2SH` | `witnessMalleatedP2SH` | `WITNESS_MALLEATED_P2SH` |
| 43 | `TWIN_WITNESS_UNEXPECTED` | `witnessUnexpected` | `WITNESS_UNEXPECTED` |
| 44 | `TWIN_WITNESS_PUBKEYTYPE` | `witnessPubkeyType` | `WITNESS_PUBKEYTYPE` |
| 45 | `TWIN_DISCOURAGE_UPGRADABLE_NOPS` | `discourageUpgradableNops` | `DISCOURAGE_UPGRADABLE_NOPS` |
| 46 | `TWIN_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM` | `discourageUpgradableWitnessProgram` | `DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM` |
| 47 | `TWIN_DISCOURAGE_UPGRADABLE_PUBKEYTYPE` | `discourageUpgradablePubkeyType` | `DISCOURAGE_UPGRADABLE_PUBKEYTYPE` |
| 48 | `TWIN_DISCOURAGE_OP_SUCCESS` | `discourageOpSuccess` | `DISCOURAGE_OP_SUCCESS` |
| 49 | `TWIN_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` | `discourageUpgradableTaprootVersion` | `DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` |
| 50 | `TWIN_TAPROOT_WRONG_CONTROL_SIZE` | `taprootWrongControlSize` | `TAPROOT_WRONG_CONTROL_SIZE` |
| 51 | `TWIN_TAPSCRIPT_VALIDATION_WEIGHT` | `tapscriptValidationWeight` | `TAPSCRIPT_VALIDATION_WEIGHT` |
| 52 | `TWIN_TAPSCRIPT_CHECKMULTISIG` | `tapscriptCheckMultiSig` | `TAPSCRIPT_CHECKMULTISIG` |
| 53 | `TWIN_TAPSCRIPT_EMPTY_PUBKEY` | `tapscriptEmptyPubkey` | `TAPSCRIPT_EMPTY_PUBKEY` |
| 54 | `TWIN_TAPSCRIPT_MINIMALIF` | `tapscriptMinimalIf` | `TAPSCRIPT_MINIMALIF` |
| 55 | `TWIN_MINIMALDATA` | `minimalData` | `MINIMALDATA` |
| 56 | `TWIN_INVALID_UNSUPPORTED` | — | `UNKNOWN_ERROR` (result 3) |
| 57 | `TWIN_BAD_INPUT` | — | `UNKNOWN_ERROR` (result 2) |

### Result-code mapping

| Condition | `entry` result |
|---|---:|
| `TWIN_OK` and final stack truthy | 1 |
| `TWIN_EVAL_FALSE` | 0 |
| any consensus `ExecError` | 0 |
| `TWIN_BAD_INPUT` | 2 |
| `TWIN_TAPROOT_DATA_UNAVAILABLE` (unjudged) | 3 |
| `TWIN_INVALID_UNSUPPORTED` (outside subset) | 3 |
| allocation failure / unknown | 3 |

**Reconciliation gate (satisfied).** `gen.py` resolves every `core` name
against the mechanically generated `contract/error_kind.h` and emits the
`EQUIV_ERR_*` symbol, not a copied integer. `CORE_MAP` has exactly one
initializer per `TwinErr`; `static_assert`s pin `TWIN_OK`, the sentinels, and
the enum shape, and the smoke driver walks all 58 IDs (`mapping_coverage`,
58/58). `TWIN_INVALID_UNSUPPORTED`, `TWIN_BAD_INPUT`, and the unjudged
sentinel map to `UNKNOWN_ERROR`, so they can never be mistaken for a
consensus verdict. The previous E0 ids derived from Lean constructor order
(e.g. `EVAL_FALSE = 14`) are no longer exposed at the boundary; only
`TwinErr` retains them internally.

---

## 5. Mapping table (Lean → C++)

| Lean construct (`Defs.lean` unless noted) | Twin C++ | Notes |
|---|---|---|
| `abbrev Stack := List ByteArray` (59–63), head = top | `Stack { uint32_t n; uint32_t len[1000]; uint8_t e[1000][520]; }`, index `0` = bottom, `n-1` = top | `cons` = append at `n`, `tail` = `n--`; `topAt st k` = element `n-k` |
| `alt : Stack` (597) | second `Stack` | same invariant |
| `vf : List Bool`, head = innermost (599) | `bool vf[10000]; uint32_t vf_n` | `vf.all id` = loop `0..vf_n`; IF appends, ELSE flips last, ENDIF pops |
| `opCount : Nat` (600) | `uint32_t opCount` | increment before dispatch; `> 201` fails |
| `codeSep : Nat` (601) | `uint32_t codeSep` | byte offset just past CODESEPARATOR (`op.next`) |
| `opcodeIndex : UInt32`, `codeSepPos : UInt32` (603–604) | same-width fields | BIP342 codesep position |
| `vwLeft : Option Int` (603) | `int64_t vwLeft; bool has_vw` | tapscript validation weight |
| `Except ExecError State` | `TwinErr` return + mutated `State&` | first error is sticky; exactly `Except` bind order |
| `Except.ok x` / `.error e` | `TWIN_OK` / enum value | |
| `Option α` (parse, helpers) | `bool` + out-parameter | e.g. `decode_op(..., Decoded&)` |
| `Nat` index / `.size` | `uint32_t` + explicit bounds | Lean `b[i]!` after a check; C++ must check first (no UB) |
| `b.extract i j`, `take`, `drop` | element moves / `memcpy` | copying, no aliasing |
| `List.range n` fold | `for (uint32_t i = 0; i < n; ++i)` | CMS/FindAndDelete loops |
| `ScriptNum := Int` (`Numeric/Interface.lean`) | `int64_t` | decision + overflow domain, §7 |
| `Bool` | `bool` | |
| `decodeScriptNum b minimal maxSize` (Interface:45–47) | `decode_num` | sign-magnitude LE, width then minimality |
| `encodeScriptNum n false` (Interface:55–56) | `encode_num` | canonical LE; 0 = empty |
| `castToBool` (Interface:64; `castToBoolList` 648–651) | `cast_to_bool` | negative-zero rule included |
| `parseWire` (421–431), `getOp` (Parser 226–229) | `validate_script` + streaming `decode_op` | eager parse order, §6 |
| `findAndDelete` (545–588) | not emitted | only reachable from CHECKSIG/CMS, which return 3 |
| `hashForOp` (637–643) | `sha256`, `ripemd160`, `hash160`, `hash256` | SHA-1 returns 3; the other four are pinned by known-answer smoke vectors |
| `evalFrom fuel` (1144–1150) | `while` over the op array | fuel is not a machine input, §8 |
| `finalStack` (1154–1156) | return `st.stack` to the boundary | |
| `evalScriptBytes` (1163–1178) | `eval_script` | size pre-check → eager parse → loop |
| `verifyScriptFull` (1363–1445) | `verify_script_full` | scriptSig → scriptPubKey → P2SH; witness tails |
| `p2shInner` (1327–1361) | `verify_script_full` P2SH branch | push-only recheck, redeem eval, cleanstack, malleated/unexpected |
| `verifyWitnessProgram`, `executeWitnessScript` | not emitted (E4) | result 3 after the malleated check |

---

## 6. Parsing and error precedence (known divergence candidate)

Lean `evalScriptBytes` **validates the whole script first** (`parseWire`),
then runs `evalFrom`. Core's `EvalScript` decodes one opcode per loop
iteration, so a runtime error on an earlier opcode can precede a later
truncated push.

Concrete code-reading case: script `0x69 0x02 0x01` (`OP_VERIFY`, then a
truncated 2-byte push).

- Lean: `parseWire` fails → `BAD_OPCODE`.
- Core: `OP_VERIFY` runs first on an empty stack → `INVALID_STACK_OPERATION`.

The twin mirrors **Lean** (its provenance), so the differential against the
Lean runner is exact; the Lean-vs-Core difference is a workstream finding
(see `findings/twin/twin-report.md`, F-DIV-TWIN-001) and such scripts must be
excluded from L⊑C cells until it is resolved. Do not "fix" the twin toward
Core without recording the provenance change.

A second order difference is filed as F-DIV-TWIN-002: Lean checks
`CONST_SCRIPTCODE`+`OP_CODESEPARATOR` **before** `fExec`, so a
`CODESEPARATOR` in an unexecuted branch still errors; Core checks it inside
the executed switch and skips it. The twin mirrors Lean; the smoke case
`codesep_const_unexecuted` pins the behavior.

The generated twin's parser implements the full `GetOp` wire table
(`0x00–0x4b`, `PUSHDATA1/2/4`, `OP_1NEGATE`, `OP_RESERVED`, `OP_1..16`,
all other bytes) because malformed-push detection is structural and would
otherwise contaminate every subset cell.

---

## 7. Numerics: `ScriptNum`

Lean models `ScriptNum` as unbounded `Int` and explicitly does not model
Core's `int64_t` wrap (module header, `Defs.lean:36-40`). The twin must be a
compiled C++ function that agrees with **both** on the cell domain:

- E1 now emits the unary/binary numeric surface (except multiplication,
  which Bitcoin does not have). Decode/encode are exact for the 4-byte
  operand width used by these opcodes (`int64_t`).
- Two 4-byte operands are in `[-(2^31-1), 2^31-1]`; `ADD`/`SUB`, unary
  `+1`/`-1`, `NEGATE`, and `ABS` cannot overflow `int64_t`. Results may
  serialise to 5 bytes; a later numeric op then rejects them with
  `SCRIPTNUM`, matching Core.
- `PICK`/`ROLL` decode their index with the same `decode_num(..., 4,
  minimalData)` path. `CLTV`/`CSV` use a 5-byte width in Core; with their
  activation flag off they are consensus no-ops, and with it on they return
  result 3, so that path is not claimed.
- The Lean `Int` / Core `int64_t` divergence (F-UB-TWIN-001) is therefore
  dormant on the supported surface. It would reappear if a future opcode
  could produce a value outside `int64_t`; that needs a domain restriction
  before it is added.

---

## 8. Fuel

- Lean `evalFrom 0 _ _ = .error .unknownError`; every other step consumes
  one unit. `evalScriptBytes` takes fuel from the caller.
- Fuel exhaustion is an **oracle artifact**, not consensus behavior: a
  correct caller supplies at least the number of parsed ops, and the 201-op
  budget bounds real runs. `evalFrom_succ_ok` / `evalFrom_fuel_mono`
  (`Defs.lean:1496-1520`) prove more fuel never breaks a succeeding run.
- The twin has no fuel input: its loop is bounded by `script.size`, which is
  the canonical sufficient fuel (`ops + 1`). Therefore the twin's result
  equals Lean's result for **any** sufficient fuel, and the differential
  runner must use a sufficient fuel (the production `pipelineFuel`).
- If a cell needs to *prove* something about fuel exhaustion itself, add an
  explicit `twin_entry_fuel(..., uint64_t fuel)` variant; do not change the
  contract entry. That variant is currently not emitted.

---

## 9. Stack/state representation (why fixed capacity)

`Stack` is a fixed-capacity struct: 1000 slots × 520 bytes + lengths, no
heap inside the engine, no allocator in any leaf cell. Rationale:

- Alive2/SAW leaf proofs should not reason through `std::vector` growth,
  reallocation, or allocator calls.
- The 1000-element cap is enforced after every step (`stepChecked`), so
  capacity equals the consensus bound; a push when full maps to
  `TWIN_STACK_SIZE` (the same verdict the post-step guard would produce).
- `element > 520` is rejected before push (`PUSH_SIZE`), so a slot always
  fits.
- The entry allocates one `State` (three stacks: main, alt, post-scriptSig
  `saved`; ≈1.56 MB) with `new (std::nothrow)` at the harness boundary only;
  all engine functions take `State&`.

For SAW/Alive2, per-op handlers have the shape of leaf cells:
`static TwinErr op_X(State&, const Ctx&, const Decoded&)`. A later emitter
can add `extern "C"` wrappers (`twin_step_drop`, …) so a cell can quantify
over a small stack without the dispatch table. The wrappers are not emitted
yet.

---

## 10. Generated code shape

- `equiv_entry` (8-arg, normative ABI v2, mandatory `equiv_error_kind*`),
  plus `entry` (7-arg) and `twin_entry` (`int32_t*`) convenience wrappers.
- `decode_tx`: canonical `TX_WITH_WITNESS` (legacy/extended), input
  `scriptSig`, sequence, witness-presence; trailing bytes rejected.
- `verify_script_full`: SIGPUSHONLY precheck → scriptSig → save stack →
  scriptPubKey → truth → bare-witness tail → P2SH wrapper (push-only,
  redeem, truth, cleanstack, witness tails).
- `eval_script`: size pre-check → eager validation → loop (element size, op
  budget, disabled ops, CONST_SCRIPTCODE, conditionals, dispatch, terminal
  stack-size guard).
- `dispatch`: push-shaped ops first, then a `switch` over supported wires;
  default is `TWIN_INVALID_UNSUPPORTED` (result 3).
- One `static TwinErr op_<NAME>(State&, const Ctx&, const Decoded&)` per
  handler, each with a `// Lean:` anchor.
- Everything in `namespace twin`; only the `extern "C"` functions have
  external linkage. The boundary catches any exception and returns result 3.

---

## 11. Determinism and drift gate

- `gen.py` reads no clock, environment, locale, or filesystem state.
- Output uses LF, fixed ordering, no timestamps.
- `python3 twin/gen.py --check twin/build/twin.cpp` exits 1 on any drift.
  CI/Make target: regenerate, hash, `--check`, then compile.
- The IR JSON is content-stable and can be hashed into the cell record.

---

## 12. What the generated twin actually supports

- **Tape**: canonical legacy or extended `TX_WITH_WITNESS`; one input;
  `input_index` in range; `amount` in `[0, MAX_MONEY]`; flags within
  `0x1fffff` with the `WITNESS ⇒ P2SH` and `CLEANSTACK ⇒ P2SH ∧ WITNESS`
  implications. Anything else is result 2.
- **Pushes**: `OP_0`, direct 1–75, `PUSHDATA1/2/4`, `OP_1NEGATE`,
  `OP_1..OP_16`; full structural `GetOp`; eager parse.
- **Stack/altstack**: `DUP DROP SWAP ROT TOALTSTACK FROMALTSTACK 2DROP 2DUP
  3DUP 2OVER 2ROT 2SWAP IFDUP DEPTH PICK ROLL TUCK NIP OVER`, plus
  `EQUAL EQUALVERIFY SIZE`.
- **Flow**: `IF NOTIF ELSE ENDIF VERIFY`; `NOP`, `NOP1/4..10`,
  `CODESEPARATOR`; `RETURN` returns `OP_RETURN`.
- **Numeric**: 4-byte `CScriptNum` unary/binary surface listed in §12a.
- **Hashes**: `RIPEMD160`, `SHA256`, `HASH160`, `HASH256`.
- **P2SH**: push-only scriptSig recheck, redeem evaluation, cleanstack,
  witness-malleated and witness-unexpected tails.
- **Flags read**: `P2SH`, `SIGPUSHONLY`, `MINIMALDATA`,
  `CONST_SCRIPTCODE`, `CLEANSTACK`, `DISCOURAGE_UPGRADABLE_NOPS`,
  `WITNESS` bookkeeping. Signature-policy bits are accepted and inert only
  because the opcodes that read them return result 3.

Valid consensus opcodes outside the subset (`CHECKSIG*`, `CHECKMULTISIG*`,
`SHA1`) return result 3 / `TWIN_INVALID_UNSUPPORTED` once execution reaches
dispatch. Reserved and unknown wire bytes follow Lean's dispatch default and
return consensus `BAD_OPCODE`. Witness/taproot engine paths return result 3
after the malleated/precondition checks. Result 3 is a declared boundary,
not a verdict. Structural checks that run before dispatch (script size,
malformed push, element size, op budget, disabled opcode) still return the
consensus error.

### 12a. Not implemented

| Area | Status |
|---|---|
| `CHECKSIG*`, `CHECKMULTISIG*`, checker seam | E3; result 3 |
| `CHECKSIGADD` under base/witnessV0 | consensus `BAD_OPCODE`; tapscript path E4 |
| `SHA1` | result 3 |
| `CLTV`, `CSV` with activation flag on | result 3; flag off is a consensus no-op |
| witness v0/v1 execution, taproot key/script path, tapscript | E4; result 3 |
| shim wiring (`shims/twin/entry.cpp`) | outside this role's write scope |
| Lean differential runner | blocker; see §13 |

---

## 13. Differential oracle (design)

The Lean model is executable. The L-leg gate is a differential run, not a
corpus spot check:

1. Build a **tape runner** on the Lean side:
   `entry(tx_bytes, spk, amount, input_index, flags) -> (result, error)` via
   `verifyScriptFull` with the real checker adapter (or a stub for
   crypto-free families), compiled from the pin. Handoff: TWIN-IR →
   CONTRACT/CORE-IR for the runner binary and tape format.
2. Generate scripts: (a) the SCR corpus rows that fall in the subset;
   (b) grammar-based fuzz over supported wires and push encodings, including
   boundary lengths 0/1/75/76/255/256/520/521 and malformed tails;
   (c) adversarial ordering cases (error precedence, stack-size boundary,
   op-count 201/202).
3. Compare **result, error id, and final stack** (debug entry). Any
   divergence is minimized and filed with the tape bytes.
4. Repeat for every tier; the twin is only allowed to claim a cell whose
   subset the oracle covers.

The **Lean** differential is not yet run: no Lean tape runner over
`verifyScriptFull` and no JSON-lines tape binary exist in this workstream
(blocker recorded in the report). A weaker but real differential *was* run
against the pinned Core corpus: `twin/corpus_probe.py` assembles a tape for
every `stack.jsonl` row and compares result/error to the corpus `expected`.
At the current shape, 258/316 rows are in domain and 258/258 match; the 58
excluded rows all contain `CHECKSIG`/`CHECKMULTISIG` opcodes. This is
Core-corpus evidence, not L⊑C equivalence.

---

## 14. Mutation tests (E1 acceptance)

REDTEAM mutates the IR (or generator) and requires the cell to fail:

| Mutation | Expected failure |
|---|---|
| `OP_SWAP` becomes a no-op | swap-order differential/smoke case |
| `OP_DUP` drops the underflow guard | empty-stack cell (would read slot 0×) |
| push value `wire - 0x50` → `wire` | value-equality differential |
| terminal stack-size guard removed | 1000/1001 boundary cell |
| `opCount` counted on pushes too | 201/202 push-heavy script |

The smoke driver already contains order/underflow/budget cases that make the
first three visible at the C++ level; the formal requirement is that the
**cell**, not just the smoke test, goes red.

---

## 15. Audit checklist (reviewer)

1. Diff each `OPS` body against its `// Lean:` anchor.
2. Check the IR dump lists every supported wire exactly once and every
   `TwinErr` maps to an `EQUIV_ERR_*` name.
3. `gen.py --check` passes; generated and IR hashes recorded.
4. Parser table matches `getOpAux` (including `OP_RESERVED` not being a push).
5. Truth function matches `castToBool` negative-zero rule.
6. Boundary ids are Core ordinals (not Lean constructor ids); result mapping
   matches `contract/ABI.md`; the 58/58 mapping smoke test passes.
7. Supported-subset corpus differential is green; Lean differential and
   mutation lane are tracked separately.
8. No unsupported opcode can return 0/1 (it must be 3), including the
   CHECKSIG/CMS and witness-program cases.
9. No `std::vector`/allocation inside `eval_script`; no uninitialized reads.
10. Compile with pinned clang `-O0` and inspect LLVM IR (no `invoke`,
    no indirect calls, no `ptrtoint`).

---

## 16. References

- `spec/core/Bitcoin/Interpreter/Defs.lean` (stepBody 817–849, dispatchOp
  852–1063, stepChecked 1131–1136, evalFrom 1144–1150, evalScriptBytes
  1163–1178, p2shInner 1327–1361, verifyWitnessProgram 1259–1321,
  verifyScriptFull 1363–1445).
- `spec/core/Bitcoin/Numeric/ScriptNum.lean` and `Numeric/Interface.lean`.
- `spec/core/Bitcoin/Script/Parser/Defs.lean` (getOpAux 206–222).
- `spec/equiv/contract/ABI.md`; `spec/equiv/README.md` §3–4.
- Bitcoin Core v32.99 @ `cce32b168`, `src/script/interpreter.cpp`,
  `script.h`, `script_error.h`.
