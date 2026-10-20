# Shared script-error taxonomy (normative)

`contract/error_kind.h` is the machine-readable form of this document; it is
generated, never hand-edited. Core's `ScriptError` is the reference.

Rules:

1. **Values mirror Core's ordinals at the pin 1:1.** There is no translation
   table in the Core shim: the `ScriptError` ordinal is passed through as
   `equiv_error_kind`. `EQUIV_ERR_OK = 0` and `EQUIV_ERR_COUNT = 55`
   (sentinel).
2. Every leg must map its engine's failure reason onto exactly one shared
   value. An unmapped failure is `EQUIV_ERR_UNKNOWN_ERROR` **plus a finding**;
   it is never silently renamed.
3. A cell compares `(result, error_kind)` on failure. `error_kind` is
   observable contract behavior, not "don't care".
4. Results `2` and `3` carry `EQUIV_ERR_UNKNOWN_ERROR`; no script error was
   produced.
5. Do not add values. If Core at a future pin adds one, re-pin, re-run the
   extractor, and treat old cell records as a new result.

## Complete mapping table

Generated and verified against the pinned tree; see
[Extraction and verification](#extraction-and-verification).


| Core value | Core name | Shared name | Group | `ScriptErrorString` |
|---:|---|---|---|---|
| 0 | `SCRIPT_ERR_OK` | `EQUIV_ERR_OK` = 0 | ungrouped | No error |
| 1 | `SCRIPT_ERR_UNKNOWN_ERROR` | `EQUIV_ERR_UNKNOWN_ERROR` = 1 | ungrouped | _falls through to "unknown error"_ |
| 2 | `SCRIPT_ERR_EVAL_FALSE` | `EQUIV_ERR_EVAL_FALSE` = 2 | ungrouped | Script evaluated without error but finished with a false/empty top stack element |
| 3 | `SCRIPT_ERR_OP_RETURN` | `EQUIV_ERR_OP_RETURN` = 3 | ungrouped | OP_RETURN was encountered |
| 4 | `SCRIPT_ERR_SCRIPTNUM` | `EQUIV_ERR_SCRIPTNUM` = 4 | ungrouped | Script number overflowed or is non-minimally encoded |
| 5 | `SCRIPT_ERR_SCRIPT_SIZE` | `EQUIV_ERR_SCRIPT_SIZE` = 5 | Max sizes | Script is too big |
| 6 | `SCRIPT_ERR_PUSH_SIZE` | `EQUIV_ERR_PUSH_SIZE` = 6 | Max sizes | Push value size limit exceeded |
| 7 | `SCRIPT_ERR_OP_COUNT` | `EQUIV_ERR_OP_COUNT` = 7 | Max sizes | Operation limit exceeded |
| 8 | `SCRIPT_ERR_STACK_SIZE` | `EQUIV_ERR_STACK_SIZE` = 8 | Max sizes | Stack size limit exceeded |
| 9 | `SCRIPT_ERR_SIG_COUNT` | `EQUIV_ERR_SIG_COUNT` = 9 | Max sizes | Signature count negative or greater than pubkey count |
| 10 | `SCRIPT_ERR_PUBKEY_COUNT` | `EQUIV_ERR_PUBKEY_COUNT` = 10 | Max sizes | Pubkey count negative or limit exceeded |
| 11 | `SCRIPT_ERR_VERIFY` | `EQUIV_ERR_VERIFY` = 11 | Failed verify operations | Script failed an OP_VERIFY operation |
| 12 | `SCRIPT_ERR_EQUALVERIFY` | `EQUIV_ERR_EQUALVERIFY` = 12 | Failed verify operations | Script failed an OP_EQUALVERIFY operation |
| 13 | `SCRIPT_ERR_CHECKMULTISIGVERIFY` | `EQUIV_ERR_CHECKMULTISIGVERIFY` = 13 | Failed verify operations | Script failed an OP_CHECKMULTISIGVERIFY operation |
| 14 | `SCRIPT_ERR_CHECKSIGVERIFY` | `EQUIV_ERR_CHECKSIGVERIFY` = 14 | Failed verify operations | Script failed an OP_CHECKSIGVERIFY operation |
| 15 | `SCRIPT_ERR_NUMEQUALVERIFY` | `EQUIV_ERR_NUMEQUALVERIFY` = 15 | Failed verify operations | Script failed an OP_NUMEQUALVERIFY operation |
| 16 | `SCRIPT_ERR_BAD_OPCODE` | `EQUIV_ERR_BAD_OPCODE` = 16 | Logical/Format/Canonical errors | Opcode missing or not understood |
| 17 | `SCRIPT_ERR_DISABLED_OPCODE` | `EQUIV_ERR_DISABLED_OPCODE` = 17 | Logical/Format/Canonical errors | Attempted to use a disabled opcode |
| 18 | `SCRIPT_ERR_INVALID_STACK_OPERATION` | `EQUIV_ERR_INVALID_STACK_OPERATION` = 18 | Logical/Format/Canonical errors | Operation not valid with the current stack size |
| 19 | `SCRIPT_ERR_INVALID_ALTSTACK_OPERATION` | `EQUIV_ERR_INVALID_ALTSTACK_OPERATION` = 19 | Logical/Format/Canonical errors | Operation not valid with the current altstack size |
| 20 | `SCRIPT_ERR_UNBALANCED_CONDITIONAL` | `EQUIV_ERR_UNBALANCED_CONDITIONAL` = 20 | Logical/Format/Canonical errors | Invalid OP_IF construction |
| 21 | `SCRIPT_ERR_NEGATIVE_LOCKTIME` | `EQUIV_ERR_NEGATIVE_LOCKTIME` = 21 | CHECKLOCKTIMEVERIFY and CHECKSEQUENCEVERIFY | Negative locktime |
| 22 | `SCRIPT_ERR_UNSATISFIED_LOCKTIME` | `EQUIV_ERR_UNSATISFIED_LOCKTIME` = 22 | CHECKLOCKTIMEVERIFY and CHECKSEQUENCEVERIFY | Locktime requirement not satisfied |
| 23 | `SCRIPT_ERR_SIG_HASHTYPE` | `EQUIV_ERR_SIG_HASHTYPE` = 23 | Malleability | Signature hash type missing or not understood |
| 24 | `SCRIPT_ERR_SIG_DER` | `EQUIV_ERR_SIG_DER` = 24 | Malleability | Non-canonical DER signature |
| 25 | `SCRIPT_ERR_MINIMALDATA` | `EQUIV_ERR_MINIMALDATA` = 25 | Malleability | Data push larger than necessary |
| 26 | `SCRIPT_ERR_SIG_PUSHONLY` | `EQUIV_ERR_SIG_PUSHONLY` = 26 | Malleability | Only push operators allowed in signatures |
| 27 | `SCRIPT_ERR_SIG_HIGH_S` | `EQUIV_ERR_SIG_HIGH_S` = 27 | Malleability | Non-canonical signature: S value is unnecessarily high |
| 28 | `SCRIPT_ERR_SIG_NULLDUMMY` | `EQUIV_ERR_SIG_NULLDUMMY` = 28 | Malleability | Dummy CHECKMULTISIG argument must be zero |
| 29 | `SCRIPT_ERR_PUBKEYTYPE` | `EQUIV_ERR_PUBKEYTYPE` = 29 | Malleability | Public key is neither compressed or uncompressed |
| 30 | `SCRIPT_ERR_CLEANSTACK` | `EQUIV_ERR_CLEANSTACK` = 30 | Malleability | Stack size must be exactly one after execution |
| 31 | `SCRIPT_ERR_MINIMALIF` | `EQUIV_ERR_MINIMALIF` = 31 | Malleability | OP_IF/NOTIF argument must be minimal |
| 32 | `SCRIPT_ERR_SIG_NULLFAIL` | `EQUIV_ERR_SIG_NULLFAIL` = 32 | Malleability | Signature must be zero for failed CHECK(MULTI)SIG operation |
| 33 | `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_NOPS` | `EQUIV_ERR_DISCOURAGE_UPGRADABLE_NOPS` = 33 | softfork safeness | NOPx reserved for soft-fork upgrades |
| 34 | `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM` | `EQUIV_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM` = 34 | softfork safeness | Witness version reserved for soft-fork upgrades |
| 35 | `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` | `EQUIV_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` = 35 | softfork safeness | Taproot version reserved for soft-fork upgrades |
| 36 | `SCRIPT_ERR_DISCOURAGE_OP_SUCCESS` | `EQUIV_ERR_DISCOURAGE_OP_SUCCESS` = 36 | softfork safeness | OP_SUCCESSx reserved for soft-fork upgrades |
| 37 | `SCRIPT_ERR_DISCOURAGE_UPGRADABLE_PUBKEYTYPE` | `EQUIV_ERR_DISCOURAGE_UPGRADABLE_PUBKEYTYPE` = 37 | softfork safeness | Public key version reserved for soft-fork upgrades |
| 38 | `SCRIPT_ERR_WITNESS_PROGRAM_WRONG_LENGTH` | `EQUIV_ERR_WITNESS_PROGRAM_WRONG_LENGTH` = 38 | segregated witness | Witness program has incorrect length |
| 39 | `SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY` | `EQUIV_ERR_WITNESS_PROGRAM_WITNESS_EMPTY` = 39 | segregated witness | Witness program was passed an empty witness |
| 40 | `SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH` | `EQUIV_ERR_WITNESS_PROGRAM_MISMATCH` = 40 | segregated witness | Witness program hash mismatch |
| 41 | `SCRIPT_ERR_WITNESS_MALLEATED` | `EQUIV_ERR_WITNESS_MALLEATED` = 41 | segregated witness | Witness requires empty scriptSig |
| 42 | `SCRIPT_ERR_WITNESS_MALLEATED_P2SH` | `EQUIV_ERR_WITNESS_MALLEATED_P2SH` = 42 | segregated witness | Witness requires only-redeemscript scriptSig |
| 43 | `SCRIPT_ERR_WITNESS_UNEXPECTED` | `EQUIV_ERR_WITNESS_UNEXPECTED` = 43 | segregated witness | Witness provided for non-witness script |
| 44 | `SCRIPT_ERR_WITNESS_PUBKEYTYPE` | `EQUIV_ERR_WITNESS_PUBKEYTYPE` = 44 | segregated witness | Using non-compressed keys in segwit |
| 45 | `SCRIPT_ERR_SCHNORR_SIG_SIZE` | `EQUIV_ERR_SCHNORR_SIG_SIZE` = 45 | Taproot | Invalid Schnorr signature size |
| 46 | `SCRIPT_ERR_SCHNORR_SIG_HASHTYPE` | `EQUIV_ERR_SCHNORR_SIG_HASHTYPE` = 46 | Taproot | Invalid Schnorr signature hash type |
| 47 | `SCRIPT_ERR_SCHNORR_SIG` | `EQUIV_ERR_SCHNORR_SIG` = 47 | Taproot | Invalid Schnorr signature |
| 48 | `SCRIPT_ERR_TAPROOT_WRONG_CONTROL_SIZE` | `EQUIV_ERR_TAPROOT_WRONG_CONTROL_SIZE` = 48 | Taproot | Invalid Taproot control block size |
| 49 | `SCRIPT_ERR_TAPSCRIPT_VALIDATION_WEIGHT` | `EQUIV_ERR_TAPSCRIPT_VALIDATION_WEIGHT` = 49 | Taproot | Too much signature validation relative to witness weight |
| 50 | `SCRIPT_ERR_TAPSCRIPT_CHECKMULTISIG` | `EQUIV_ERR_TAPSCRIPT_CHECKMULTISIG` = 50 | Taproot | OP_CHECKMULTISIG(VERIFY) is not available in tapscript |
| 51 | `SCRIPT_ERR_TAPSCRIPT_MINIMALIF` | `EQUIV_ERR_TAPSCRIPT_MINIMALIF` = 51 | Taproot | OP_IF/NOTIF argument must be minimal in tapscript |
| 52 | `SCRIPT_ERR_TAPSCRIPT_EMPTY_PUBKEY` | `EQUIV_ERR_TAPSCRIPT_EMPTY_PUBKEY` = 52 | Taproot | Empty public key in tapscript |
| 53 | `SCRIPT_ERR_OP_CODESEPARATOR` | `EQUIV_ERR_OP_CODESEPARATOR` = 53 | Constant scriptCode | Using OP_CODESEPARATOR in non-witness script |
| 54 | `SCRIPT_ERR_SIG_FINDANDDELETE` | `EQUIV_ERR_SIG_FINDANDDELETE` = 54 | Constant scriptCode | Signature is found in scriptCode |
| 55 | `SCRIPT_ERR_ERROR_COUNT` | `EQUIV_ERR_COUNT` = 55 | sentinel | _falls through to "unknown error"_ |

## ABI names that do not exist in Core at the pin

The earlier ABI §3 sketch listed a few names that are not members of
`ScriptError` at `cce32b168`. They are **not** added to the shared enum; the
table below is the normative disposition. Corpus expectations must use the
Core name/value. (ABI v2 §3 now points here instead of repeating the names.)

| ABI §3 name | Status at pin | Disposition |
|---|---|---|
| `SCRIPTNUM_OVERFLOW` | absent | Core folds this into `SCRIPT_ERR_SCRIPTNUM` (4). `CScriptNum` throws `scriptnum_error("script number overflow")`; `EvalScript` catches it and sets `SCRIPT_ERR_SCRIPTNUM`. |
| `SCRIPTNUM_MINENCODE` | absent | Same as above: `scriptnum_error("non-minimally encoded script number")` → `SCRIPT_ERR_SCRIPTNUM` (4). |
| `DIV_BY_ZERO` | absent | `OP_DIV`/`OP_MOD` are disabled opcodes at the pin. Encountering either yields `SCRIPT_ERR_DISABLED_OPCODE` (17) before any arithmetic. Value is unreachable; never emit it. |
| `MOD_BY_ZERO` | absent | Same as `DIV_BY_ZERO`. |
| `NUMEQUAL*` | partial | Only `SCRIPT_ERR_NUMEQUALVERIFY` (15) exists. `OP_NUMEQUAL` pushes a boolean; it has no error of its own. |
| `SIG_BADLENGTH` | absent | No single Core value. Schnorr length (`!= 64/65`) → `SCRIPT_ERR_SCHNORR_SIG_SIZE` (45). ECDSA length/DER failure → `SCRIPT_ERR_SIG_DER` (24) when `DERSIG`/`LOW_S`/`STRICTENC` applies; otherwise the signature simply fails (`SCRIPT_ERR_SIG_NULLFAIL` (32) under `NULLFAIL`, or `EVAL_FALSE`/`CHECKSIGVERIFY` at the call site). |
| `CONST_SCRIPTCODE` | not an error value | It is a **flag**. Its failures are `SCRIPT_ERR_OP_CODESEPARATOR` (53) and `SCRIPT_ERR_SIG_FINDANDDELETE` (54). |
| `BAD_OPCODE` (listed twice in ABI) | exists once | `SCRIPT_ERR_BAD_OPCODE` (16). |

`SCHNORR_SIG*` in ABI §3 expands to the three real values 45–47
(`SCHNORR_SIG_SIZE`, `SCHNORR_SIG_HASHTYPE`, `SCHNORR_SIG`). `DISCOURAGE_*`
expands to the five real values 33–37. All other ABI names are exact Core
names and appear in the table above.

## Error precedence

Core returns the **first** failing check. Which error wins is observable
behavior: a script can have several latent faults, and the expected kind is
the one Core reaches first in execution order. Cells must not accept "any
plausible error" — they assert the exact value.

## Extraction and verification

```sh
# from spec/equiv
python3 contract/extract_error_enum.py --core-src /path/to/bitcoin --format md
python3 contract/extract_error_enum.py --core-src /path/to/bitcoin --format h \
        --out contract/error_kind.h
```

What was actually run while writing this contract (2026-10-19):

* Core checkout: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
  (sparse checkout of `src/`), `git rev-parse HEAD` matched the pin.
* The extractor parsed 56 entries (0..55), dense, ending in
  `SCRIPT_ERR_ERROR_COUNT`; every name except `SCRIPT_ERR_UNKNOWN_ERROR` and
  `SCRIPT_ERR_ERROR_COUNT` has an explicit `ScriptErrorString` case (those two
  share Core's fall-through `"unknown error"`).
* `python3 -m py_compile` passed.
* Without `CORE_SRC` the script exits `2` and prints:
  `error: CORE_SRC is absent or incomplete: ...`.
* The generated header is `contract/error_kind.h`.

No row in the table is a guess; every Core name/value came from the pinned
header and every message from the pinned `.cpp`. The only judgement calls are
the ABI-name dispositions above, which are labelled as such.

## Leg mapping status

| Leg | State |
|---|---|
| C (Core) | identity pass-through; static asserts in `shims/core/entry.cpp` pin spot values and `COUNT`. |
| L (twin) | TODO(TWIN): map the twin's error result onto these values; record the mapping in `findings/twin/`. |
| R (rbitcoin) | TODO(RUST-IR): map rbitcoin's script error enum onto these values; record it in `findings/rust/`. Until then, `shims/rust/entry.rs` is a stub. |

A mapping that cannot be made total is an E3 finding, not an enum change.
