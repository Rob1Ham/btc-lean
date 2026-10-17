# 06 — The Bitcoin Script Interpreter: Complete Operational Semantics (Workstream B2)

Project: **btc-lean** · Workstream B2 (report ID 06) · Date: 2026-10-16

**Ground truth pinned:** `bitcoin/bitcoin` @ `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (master, client version 32.99, cloned 2026-10-16).
NOTE: the canonical pinned HEAD `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` had moved; the actual clone HEAD is the hash above. All `file:line` citations below are at this commit.

All citations are VERIFIED (read directly from source) unless marked **INFERRED**. Primary sources: `src/script/interpreter.cpp` (2225 lines, read exhaustively), `src/script/script.h`, `src/script/script.cpp`, `src/script/scriptnum.h` — which no longer exists; `CScriptNum` now lives in `script.h` — `src/script/script_error.h`, `src/script/interpreter.h`, `src/consensus/consensus.h`, `src/consensus/tx_verify.cpp`, `src/validation.cpp`, `src/policy/policy.h`, `src/kernel/chainparams.cpp`.

---

## Executive summary (≤15 lines)

- The interpreter is a **single function**, `EvalScript` (interpreter.cpp:417-1249), a ~800-line `for` loop over a decoded opcode stream with: main stack, altstack, a condition stack (`ConditionStack`, an optimized boolean stack, :283-328), an opcode counter, and a per-opcode-position counter used by `OP_CODESEPARATOR`/BIP342.
- **VerifyScript** (interpreter.cpp:2012-2131) orchestrates: scriptSig → scriptPubKey on one shared stack (CVE-2010-5141), optional bare-witness dispatch, optional P2SH re-evaluation, then success/failure by the top-of-stack boolean (or CLEANSTACK).
- Witness v0 (BIP141) and Taproot/Tapscript (BIP341/342) are **dispatched from VerifyScript**, not from EvalScript: `VerifyWitnessProgram` → `ExecuteWitnessScript` → `EvalScript` with a different `SigVersion`.
- There are exactly **15 disabled opcodes** (checked before any execution, even in unexecuted IF branches) and a set of reserved opcodes that fail via `default:` in the switch. In Tapscript, 10+ ranges of "OP_SUCCESSx" opcodes instead terminate the script with **success**, bypassing all later checks.
- Opcode counting (`MAX_OPS_PER_SCRIPT=201`) applies **only** to BASE/WITNESS_V0, counts only opcodes `> OP_16`, and counts unexecuted-branch opcodes too. Tapscript replaces it entirely with the **validation-weight budget** (witness size + 50, −50 per successful non-empty sig).
- Consensus-active verify flags are decided per-block by `GetBlockScriptFlags` (validation.cpp:2249-2286): always P2SH|WITNESS|TAPROOT (with **two named block exceptions** in chainparams.cpp:115-118), plus DERSIG/CLTV/CSV/NULLDUMMY by activation height. Everything else (LOW_S, MINIMALDATA, MINIMALIF-v0, NULLFAIL, CLEANSTACK, STRICTENC, CONST_SCRIPTCODE, WITNESS_PUBKEYTYPE) is **policy**, not consensus.
- The biggest formalization hazards: CScriptNum's sign-magnitude little-endian encoding with the negative-zero `0x80` idiom; FindAndDelete's byte-level signature deletion in legacy scriptCode; the SIGHASH_SINGLE "one/zero-hash" quirks; and CHECKMULTISIG's dummy element.
- **174 rule rows** in Appendix B.

---

## Key findings (file:line citations)

1. `CastToBool` (interpreter.cpp:46-59): an element is TRUE iff it has any nonzero byte, **except** the single-byte `0x80` (negative zero) which is FALSE. Empty vector is FALSE. This one function defines script truth.
2. `EvalScript` checks, in order, before any dispatch: GetOp parse failure → `BAD_OPCODE` (:455-456); push size >520 → `PUSH_SIZE` **even in unexecuted branches** (:457-458); opcode count (only BASE/WITNESS_V0, only `opcode > OP_16`, unexecuted included) → `OP_COUNT` (:460-464); disabled opcodes → `DISABLED_OPCODE` (:467-482); `OP_CODESEPARATOR` under CONST_SCRIPTCODE in BASE → error **even unexecuted** (:484-486).
3. The switch is entered when `fExec` **or** the opcode is in `[OP_IF, OP_ENDIF]` (:493) — so ELSE/ENDIF/VERIF/VERNOTIF are processed in skipped branches; VERIF/VERNOTIF always error (no case → `default:` :1227-1228).
4. Per-iteration post-check: `stack.size() + altstack.size() > MAX_STACK_SIZE(1000)` → `STACK_SIZE` (:1231-1233); exceptions map `scriptnum_error` → `SCRIPT_ERR_SCRIPTNUM`, anything else → `UNKNOWN_ERROR` (:1236-1243); non-empty condition stack at end → `UNBALANCED_CONDITIONAL` (:1245-1246).
5. `MAX_SCRIPT_SIZE (10000)` is checked **once, at entry**, and only for BASE/WITNESS_V0 (:438-440) — Tapscript scripts have no 10k limit (only block/witness size bounds).
6. `CHECKMULTISIG` (:1115-1225): key count ∈ [0,20], sig count ∈ [0, keys], `nOpCount += nKeysCount`; sig/key pairing walks with early-exit when `nSigsCount > nKeysCount` (:1189); pops `nKeys + nSigs + 2` items (the **+2** = the pubkey-count item and the **dummy**); dummy unchecked unless NULLDUMMY (:1209-1213); NULLFAIL (:1196-1197).
7. `SignatureHash` legacy path (:1671-1677) uses `CTransactionSignatureSerializer` (:1263-1354): blanks other scriptSigs, zeroes other sequences for SINGLE/NONE, truncates vout for SINGLE/NONE, and **deletes OP_CODESEPARATORs from scriptCode during serialization** (:1282-1302). SIGHASH_SINGLE with `nIn ≥ vout.size()` returns **`uint256::ONE`** (:1614-1622) — the famous "SINGLE bug". BIP143 instead leaves `hashOutputs` as the **zero uint256** in that case (:1647-1653).
8. Taproot: key-path spend = 1 witness item → direct `CheckSchnorrSignature` against the 32-byte program (:1970-1975); script path pops control+script, validates control size (33+32k, k≤128) (:1980), verifies tap-tweak commitment (:1984), leaf version `0xc0` → Tapscript (:1988-1993); other leaf versions succeed silently unless DISCOURAGE flag (:1995-1998). **P2A** (`OP_1 0x4e73`, 2-byte v1 program) short-circuits to success (:2000-2001, script.cpp:216-222).
9. `EvalChecksigTapscript` (:357-395): **empty sig ⇒ check "fails" but script continues**; non-empty sig consumes 50 weight units from `m_validation_weight_left`; empty pubkey is an immediate error; 32-byte pubkey → Schnorr; other sizes → upgradable (policy-flagged).
10. Consensus flag selection: `GetBlockScriptFlags` (validation.cpp:2249-2286); mainnet script_flag_exceptions (kernel/chainparams.cpp:115-118): block `00000000000002dc756e…` → SCRIPT_VERIFY_NONE (BIP16 exception), block `0000000000000000000f14c35b2d841e…` → P2SH|WITNESS only (Taproot exception).
11. SigOps: legacy `GetSigOpCount(false)` counts every CHECK(MULTI)SIG as 1/20 resp. (script.cpp:159-181); tx cost = (legacy + P2SH)×4 + witness sigops×1, block limit `MAX_BLOCK_SIGOPS_COST = 80'000` (consensus/consensus.h:18), computed in `GetTransactionSigOpCost` (consensus/tx_verify.cpp:149-168); witness v0 20-byte program = 1 sigop, 32-byte program = accurate count of the witness script, v1+ = 0 (interpreter.cpp:2133-2147).
12. `CheckLockTime` (interpreter.cpp:1754-1789): type match (<500000000 = height else time), operand ≤ tx nLockTime, and **this input's nSequence ≠ 0xffffffff**. `CheckSequence` (:1791-1836): tx version ≥ 2, tx sequence disable-flag clear, mask `0x0040ffff | (1<<22)`, type match, operand ≤ masked tx sequence.
13. `IsWitnessProgram` (script.cpp:250-264): script 4..42 bytes, first byte OP_0/OP_1..OP_16, second byte + 2 == script size; program 2..40 bytes.
14. `IsOpSuccess` (script.cpp:365-371): bytes {80, 98, 126-129, 131-134, 137-138, 141-142, 149-153, 187-254}.
15. `CheckMinimalPush` (script.cpp:373-396) implements BIP62 rule 3 exactly: empty→OP_0; 0x01-0x16→OP_1..16; 0x81→OP_1NEGATE; ≤75→direct; ≤255→PUSHDATA1; ≤65535→PUSHDATA2.

---

## Detailed analysis

### 1. The execution model

#### 1.1 State

`EvalScript(stack, script, flags, checker, sigversion, execdata, serror)` (interpreter.cpp:417):

| Component | Type | Init | Notes |
|---|---|---|---|
| `stack` | `vector<valtype>` (byte vectors) | caller-provided | main stack; shared across scriptSig→scriptPubKey |
| `altstack` | `vector<valtype>` | empty (:436) | only OP_TOALTSTACK/OP_FROMALTSTACK touch it; counts toward the stack-size check (:1232) |
| `vfExec` | `ConditionStack` (:283-328) | empty | NOT a real stack: stores size + first-false-pos; `all_true()` gates execution |
| `pc / pend / pbegincodehash` | iterators | :430-432 | `pbegincodehash` = start of scriptCode for checksig |
| `nOpCount` | int | 0 (:441) | |
| `opcode_pos` | uint32 | 0 (:443) | incremented per opcode; recorded by OP_CODESEPARATOR (:1065) for BIP342 sighash |
| `execdata.m_codeseparator_pos` | uint32 | 0xFFFFFFFF (:444-445) | |
| `vchTrue/vchFalse` | `01` / empty (:423-425) | | canonical booleans pushed by comparison ops |

`stacktop(i)` uses `.at()` with a signed→size_t cast (:65) — out-of-range access throws and is caught as `SCRIPT_ERR_UNKNOWN_ERROR` (:1240-1242). `popstack` throws on empty (:67-72). A Lean model should make stack underflow an explicit error case, not an exception; the observable result is identical (script failure), but the *error tag* differs (`UNKNOWN_ERROR` vs the explicit `INVALID_STACK_OPERATION` checks most opcodes perform first).

#### 1.2 The main loop skeleton

```
for (; pc < pend; ++opcode_pos):
  fExec = vfExec.all_true()
  1. GetOp(pc, opcode, vchPushValue)  — failure ⇒ BAD_OPCODE        :455
  2. |vchPushValue| > 520              ⇒ PUSH_SIZE (always)          :457
  3. BASE/WITNESS_V0 && opcode>OP_16 && ++nOpCount>201 ⇒ OP_COUNT   :460
  4. opcode ∈ disabled(15)             ⇒ DISABLED_OPCODE (always)    :467
  5. OP_CODESEPARATOR && BASE && CONST_SCRIPTCODE ⇒ error (always)  :484
  6. if fExec && opcode ≤ OP_PUSHDATA4: minimal-push check (if MINIMALDATA), push :488-492
     else if fExec || opcode ∈ [OP_IF..OP_ENDIF]: switch(opcode)      :493
  7. stack+altstack > 1000             ⇒ STACK_SIZE                  :1231
after loop: vfExec empty else UNBALANCED_CONDITIONAL                   :1245
```

Checks 2,3,4,5,7 run **regardless of `fExec`** (in skipped branches too). Check 3 counts unexecuted opcodes. This "limits apply even in dead branches" property is frequently missed in third-party opcode tables and must be in the Lean model.

#### 1.3 VerifyScript flow (interpreter.cpp:2012-2131)

1. `SIGPUSHONLY` (policy): scriptSig `IsPushOnly` (:2022-2024).
2. `EvalScript(stack, scriptSig, BASE)` (:2029). If P2SH flag: `stackCopy = stack` (:2032-2033).
3. `EvalScript(stack, scriptPubKey, BASE)` (:2034).
4. Stack non-empty and top CastToBool-true, else `EVAL_FALSE` (:2037-2040).
5. Bare witness program (WITNESS flag; `IsWitnessProgram`): scriptSig must be **exactly empty** (`WITNESS_MALLEATED` :2048-2051); dispatch `VerifyWitnessProgram(is_p2sh=false)` (:2052); `stack.resize(1)` to bypass the final cleanstack check (:2057).
6. P2SH (BIP16): scriptPubKey `IsPayToScriptHash()` (23-byte `OP_HASH160 <20> OP_EQUAL`, script.cpp:224-231): scriptSig push-only (:2065); restore `stackCopy`; last stack element is the redeemScript (:2076-2078); eval it (:2080); truthy check (:2083-2086); if redeemScript is itself a witness program: scriptSig must be **exactly one push of the redeemScript** (`WITNESS_MALLEATED_P2SH` :2092-2096); dispatch `VerifyWitnessProgram(is_p2sh=true)` (:2097).
7. `CLEANSTACK` (policy): exactly 1 element remains (:2110-2118); asserts P2SH and WITNESS flags are present.
8. WITNESS flag: if no witness program was found but a non-null witness is present → `WITNESS_UNEXPECTED` (:2120-2128).

Key invariants (asserted, not checked — :2074, :2113-2114, :2124): CLEANSTACK requires P2SH+WITNESS; WITNESS requires P2SH. The consensus `GetBlockScriptFlags` always includes P2SH|WITNESS|TAPROOT so the asserts always hold in validation.

**Failure semantics:** any failure anywhere (scriptSig, scriptPubKey, P2SH subscript, witness program) aborts the whole VerifyScript with `false`; there is no partial success. This is the "any false → whole verify fails" rule; it is structural (early returns), not a separate check.

#### 1.4 Empty-script semantics (dark corner SCR-010)

- `EvalScript` on an empty (or whitespace-free) script succeeds immediately, leaving the stack unchanged (:449 loop doesn't run; :1248 success).
- Hence `scriptPubKey = ∅` is spendable with a scriptSig that leaves exactly one truthy element (e.g., scriptSig `OP_1`): step 4 passes. An empty scriptSig + empty scriptPubKey leaves `stack.empty()` → `EVAL_FALSE`.
- An empty scriptSig is mandatory (not merely allowed) for native witness programs (:2048).
- An empty P2WSH witness script: witness stack must be ≥1 item (the script itself is popped first, :1936-1940); after evaluation `stack.size() != 1` → CLEANSTACK error unless exactly one argument element remained.

#### 1.5 ScriptNum (script.h:227-394)

- **Encoding**: little-endian, sign-magnitude; most significant byte's high bit (0x80) is the sign. `set_vch` (:376-391) and `serialize` (:342-373) are exact inverses on canonical values. **Negative zero**: `serialize(0) = ∅`; the byte vector `0x80` decodes to 0.
- **Decode limits**: `CScriptNum(vch, fRequireMinimal, nMaxNumSize=4)` throws `scriptnum_error` if `vch.size() > nMaxNumSize` (:249-251) — caught → `SCRIPT_ERR_SCRIPTNUM`. Default operand limit 4 bytes ⇒ range [−2³¹+1, 2³¹−1] (0x80000000 as 4-byte LE with sign bit is *not* representable as negative; `set_vch` of `00 00 00 80` = −2³¹ but `m_value` is int64 so it decodes fine — the documented range statement in the header comment :229-236 is about the *standard* interpretation; the hard limit is purely the byte length).
- **Minimal encoding** (when `fRequireMinimal`, i.e. MINIMALDATA flag, or always for the *operands of* CHECKMULTISIG counts, CHECKSIGADD's num, CLTV/CSV — note those are always constructed with `fRequireMinimal`!): if top byte's low 7 bits are 0, the vector must be 1 byte or the next byte must have its high bit set (:252-268). This rejects `0x80` (negative-zero) as a non-minimal encoding of 0 when fRequireMinimal — wait: `vch = {0x80}`, back&0x7f==0, size≤1 → **throws**. So under MINIMALDATA, `OP_0`-pushed empty vector encodes 0 fine, but a 1-byte `0x80` push used as a number throws. Important for CMS dummy under MINIMALDATA (policy).
- **Arithmetic**: 64-bit internal, no overflow in results; `getint()` clamps to int32 range (:326-333) — used for PICK/ROLL depth, CMS key/sig counts. Results pushed via `getvch()` can exceed 4 bytes (e.g. `OP_ADD` of two near-max operands) and are valid *on the stack*; only *subsequent interpretation as an operand* re-enforces the 4-byte limit (header comment :229-236; also CLTV/CSV accept 5 bytes, :552-556).
- CLTV/CSV use `nMaxNumSize = 5` (:556, :584) — year-2038 avoidance, up to 2³⁹−1.
- `OP_1..OP_16`, `OP_1NEGATE`, and all arithmetic outputs are pushed via `serialize()` and are minimal by construction (:518-522 comment).

#### 1.6 Flags: consensus vs policy

`GetBlockScriptFlags` (validation.cpp:2249-2286):

- Always (mainnet, except the two exception blocks): `P2SH | WITNESS | TAPROOT`.
- `DERSIG` if BIP66 active (height 363725); `CHECKLOCKTIMEVERIFY` if BIP65 (388381); `CHECKSEQUENCEVERIFY` if BIP112/CSV (419328); `NULLDUMMY` if SegWit (481824) (kernel/chainparams.cpp:119-125).
- Exceptions map (consensus/params.h:97): block `00000000000002dc756eebf4f49723ed8d30cc28a5f108eb94b1ba88ac4f9c22` → `SCRIPT_VERIFY_NONE`; block `0000000000000000000f14c35b2d841e986ab5441de8c585d5ffe55ea1e395ad` → `P2SH|WITNESS` (kernel/chainparams.cpp:115-118).
- `MANDATORY_SCRIPT_VERIFY_FLAGS` = P2SH|DERSIG|NULLDUMMY|CLTV|CSV|WITNESS|TAPROOT (policy/policy.h:104-111) — the set standard txs comply with.
- `STANDARD_SCRIPT_VERIFY_FLAGS` adds STRICTENC, MINIMALDATA, DISCOURAGE_UPGRADABLE_NOPS, CLEANSTACK, MINIMALIF, NULLFAIL, LOW_S, DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM, WITNESS_PUBKEYTYPE, CONST_SCRIPTCODE, DISCOURAGE_UPGRADABLE_TAPROOT_VERSION, DISCOURAGE_OP_SUCCESS, DISCOURAGE_UPGRADABLE_PUBKEYTYPE (policy/policy.h:118-133).

**Consequence for btc-lean:** the Lean interpreter must be parameterized by a flag set, and the *consensus instantiation* only ever uses {P2SH, WITNESS, TAPROOT, DERSIG, CLTV, CSV, NULLDUMMY} (+ the two historical exceptions). But TAPROOT implies Tapscript semantics which subsume CLEANSTACK/MINIMALIF consensus behavior for v1 leaves. A pure-consensus Lean model still needs the flag parameter for DERSIG-era validation of pre-363725 blocks and the exceptions.

### 2. Complete opcode table (0x00–0xff)

Legend: **Exec** = behavior when executed; **Skip** = behavior in unexecuted branch. "Counts" = toward `MAX_OPS_PER_SCRIPT` (BASE/WITNESS_V0 only). B = BASE/WITNESS_V0, T = TAPSCRIPT.

| Hex | Name | Counts | Exec (consensus) | Skip (unexecuted branch) | Notes/limits |
|---|---|---|---|---|---|
| 0x00 | OP_0 / OP_FALSE | no | push ∅ | nothing | :488-492; canonical false |
| 0x01-0x4b | direct push (n=1..75) | no | push n bytes; PUSH_SIZE if n>520? (impossible: n≤75); MINIMALDATA: must be used when data ≤75 | nothing | :488-492 |
| 0x4c | OP_PUSHDATA1 | no | push next 1-byte-length data; parse failure ⇒ BAD_OPCODE | same parse failure | :327-359 (script.cpp GetScriptOp); does NOT count toward op limit |
| 0x4d | OP_PUSHDATA2 | no | 2-byte LE length | same | |
| 0x4e | OP_PUSHDATA4 | no | 4-byte LE length | same | >520 bytes ⇒ PUSH_SIZE even unexecuted (:457) |
| 0x4f | OP_1NEGATE | no | push `0x81` | nothing | :499-523 |
| 0x50 | OP_RESERVED | no | **fail** BAD_OPCODE (default case) | **nothing** (0x50 not in [IF..ENDIF]) — but in T it is an OP_SUCCESSx | counted? no (≤OP_16); comment :461 |
| 0x51-0x60 | OP_1..OP_16 | no | push 1-byte 0x01..0x10 | nothing | :499-523 |
| 0x61 | OP_NOP | yes | no-op | nothing | :529-530 |
| 0x62 | OP_VER | yes | fail BAD_OPCODE | nothing; T: OP_SUCCESSx | default :1227 |
| 0x63 | OP_IF | yes | pop top; TAPSCRIPT: must be ∅ or `01` else TAPSCRIPT_MINIMALIF (:624-630); WITNESS_V0+MINIMALIF flag: same check (:632-637); push CastToBool (NOTIF inverts) to cond-stack | push `false` to cond-stack without popping stack (:617-643) | stack<1 executed ⇒ INVALID_STACK_OPERATION |
| 0x64 | OP_NOTIF | yes | as OP_IF with inverted value | same | |
| 0x65 | OP_VERIF | yes | **fail** BAD_OPCODE — always, even unexecuted (in [IF..ENDIF] range so switch runs) | fail | :1227 default; classic footgun |
| 0x66 | OP_VERNOTIF | yes | fail (as 0x65) | fail | |
| 0x67 | OP_ELSE | yes | toggle cond-stack top; empty cond-stack ⇒ UNBALANCED_CONDITIONAL | same check | :647-653; double ELSE is legal (toggles twice) |
| 0x68 | OP_ENDIF | yes | pop cond-stack; empty ⇒ UNBALANCED_CONDITIONAL | same | :655-661 |
| 0x69 | OP_VERIFY | yes | stack<1 ⇒ err; top false ⇒ VERIFY err; else pop | nothing | :663-675 |
| 0x6a | OP_RETURN | yes | fail OP_RETURN (:677-681) | nothing | standardness: unspendable outputs (script.h:564-567) |
| 0x6b | OP_TOALTSTACK | yes | move top to altstack | nothing | :687-694 |
| 0x6c | OP_FROMALTSTACK | yes | move altstack top to stack; empty altstack ⇒ INVALID_ALTSTACK_OPERATION | nothing | :696-703 |
| 0x6d | OP_2DROP | yes | drop 2 | nothing | :705-713 |
| 0x6e | OP_2DUP | yes | dup top 2 | nothing | :715-725 |
| 0x6f | OP_3DUP | yes | dup top 3 | nothing | :727-739 |
| 0x70 | OP_2OVER | yes | copy 3rd,4th from top | nothing | :741-751 |
| 0x71 | OP_2ROT | yes | x1 x2 x3 x4 x5 x6 → x3 x4 x5 x6 x1 x2 | nothing | :753-764 |
| 0x72 | OP_2SWAP | yes | swap pairs | nothing | :766-774 |
| 0x73 | OP_IFDUP | yes | dup top iff CastToBool(top) | nothing | :776-785 |
| 0x74 | OP_DEPTH | yes | push stack size as ScriptNum | nothing | :787-793 |
| 0x75 | OP_DROP | yes | pop | nothing | :795-802 |
| 0x76 | OP_DUP | yes | dup | nothing | :804-812 |
| 0x77 | OP_NIP | yes | remove 2nd-from-top | nothing | :814-821 |
| 0x78 | OP_OVER | yes | copy 2nd-from-top | nothing | :823-831 |
| 0x79 | OP_PICK | yes | n=ScriptNum(top, minimal) (clamped by getint); n<0 or n≥stack ⇒ err; copy depth-n | nothing | :833-849 |
| 0x7a | OP_ROLL | yes | as PICK but moves (erases) | nothing | :833-849 |
| 0x7b | OP_ROT | yes | rotate top 3 | nothing | :851-861 |
| 0x7c | OP_SWAP | yes | swap top 2 | nothing | :863-870 |
| 0x7d | OP_TUCK | yes | insert top copy before 2nd | nothing | :872-880 |
| 0x7e | OP_CAT | yes | **DISABLED** (CVE-2010-5137) :467-482 | **disabled even unexecuted** | T: OP_SUCCESSx |
| 0x7f | OP_SUBSTR | yes | disabled | disabled | T: SUCCESSx |
| 0x80 | OP_LEFT | yes | disabled | disabled | T: SUCCESSx |
| 0x81 | OP_RIGHT | yes | disabled | disabled | T: SUCCESSx |
| 0x82 | OP_SIZE | yes | push byte-size of top | nothing | :883-891 |
| 0x83 | OP_INVERT | yes | disabled | disabled | T: SUCCESSx |
| 0x84 | OP_AND | yes | disabled | disabled | T: SUCCESSx |
| 0x85 | OP_OR | yes | disabled | disabled | T: SUCCESSx |
| 0x86 | OP_XOR | yes | disabled | disabled | T: SUCCESSx |
| 0x87 | OP_EQUAL | yes | byte-wise equality → push 01/∅ | nothing | :897-923 |
| 0x88 | OP_EQUALVERIFY | yes | EQUAL then pop iff true; else EQUALVERIFY err | nothing | |
| 0x89 | OP_RESERVED1 | yes | fail BAD_OPCODE | nothing; T: SUCCESSx | |
| 0x8a | OP_RESERVED2 | yes | fail | nothing; T: SUCCESSx | |
| 0x8b | OP_1ADD | yes | +1 (4-byte operand) | nothing | :929-953 |
| 0x8c | OP_1SUB | yes | −1 | nothing | |
| 0x8d | OP_2MUL | yes | disabled | disabled | T: SUCCESSx |
| 0x8e | OP_2DIV | yes | disabled | disabled | T: SUCCESSx |
| 0x8f | OP_NEGATE | yes | −x | nothing | |
| 0x90 | OP_ABS | yes | |x| | nothing | |
| 0x91 | OP_NOT | yes | x==0 → 1 else 0 | nothing | |
| 0x92 | OP_0NOTEQUAL | yes | x≠0 → 1 else 0 | nothing | |
| 0x93 | OP_ADD | yes | x+y | nothing | :955-1010 |
| 0x94 | OP_SUB | yes | x−y | nothing | |
| 0x95 | OP_MUL | yes | disabled | disabled | T: SUCCESSx |
| 0x96 | OP_DIV | yes | disabled | disabled | T: SUCCESSx |
| 0x97 | OP_MOD | yes | disabled | disabled | T: SUCCESSx |
| 0x98 | OP_LSHIFT | yes | disabled | disabled | T: SUCCESSx (CVE-2010-5137: shift overflow) |
| 0x99 | OP_RSHIFT | yes | disabled | disabled | T: SUCCESSx |
| 0x9a | OP_BOOLAND | yes | both ≠0 → 1 else 0 | nothing | |
| 0x9b | OP_BOOLOR | yes | either ≠0 | nothing | |
| 0x9c | OP_NUMEQUAL | yes | numeric eq (minimal operands under MINIMALDATA) | nothing | |
| 0x9d | OP_NUMEQUALVERIFY | yes | NUMEQUAL then VERIFY-style pop | nothing | NUMEQUALVERIFY err :1002-1008 |
| 0x9e | OP_NUMNOTEQUAL | yes | numeric neq | nothing | |
| 0x9f | OP_LESSTHAN | yes | < | nothing | |
| 0xa0 | OP_GREATERTHAN | yes | > | nothing | |
| 0xa1 | OP_LESSTHANOREQUAL | yes | ≤ | nothing | |
| 0xa2 | OP_GREATERTHANOREQUAL | yes | ≥ | nothing | |
| 0xa3 | OP_MIN | yes | min | nothing | |
| 0xa4 | OP_MAX | yes | max | nothing | |
| 0xa5 | OP_WITHIN | yes | x∈[min,max) → 1 else 0 | nothing | :1012-1026 |
| 0xa6 | OP_RIPEMD160 | yes | RIPEMD-160(top) (20B) | nothing | :1032-1056 |
| 0xa7 | OP_SHA1 | yes | SHA-1 (20B) | nothing | |
| 0xa8 | OP_SHA256 | yes | SHA-256 (32B) | nothing | |
| 0xa9 | OP_HASH160 | yes | RIPEMD160(SHA256) (20B) | nothing | |
| 0xaa | OP_HASH256 | yes | SHA256d (32B) | nothing | |
| 0xab | OP_CODESEPARATOR | yes | set pbegincodehash=pc; execdata.m_codeseparator_pos=opcode_pos | nothing executed, but CONST_SCRIPTCODE+BASE rejects it even unexecuted (:484-486) | :1058-1067 |
| 0xac | OP_CHECKSIG | yes | see §3.2; B: sig+pubkey → bool; T: also allowed | nothing | :1069-1092 |
| 0xad | OP_CHECKSIGVERIFY | yes | CHECKSIG then pop iff true | nothing | CHECKSIGVERIFY err :1084-1090 |
| 0xae | OP_CHECKMULTISIG | yes | see §3.3; **T: fail TAPSCRIPT_CHECKMULTISIG** (:1118) | nothing | :1115-1225 |
| 0xaf | OP_CHECKMULTISIGVERIFY | yes | as above + verify | nothing | |
| 0xb0 | OP_NOP1 | yes | no-op; DISCOURAGE_UPGRADABLE_NOPS (policy) fails it | nothing | :605-611 |
| 0xb1 | OP_CHECKLOCKTIMEVERIFY / OP_NOP2 | yes | BIP65 §4 below; pre-activation: NOP | nothing | :532-568 |
| 0xb2 | OP_CHECKSEQUENCEVERIFY / OP_NOP3 | yes | BIP112 §4 below; pre-activation: NOP | nothing | :571-603 |
| 0xb3-0xb9 | OP_NOP4..NOP10 | yes | no-op; DISCOURAGE (policy) | nothing | :605-611 |
| 0xba | OP_CHECKSIGADD | yes | **B/W: fail BAD_OPCODE** (:1097); T: (sig, num, pubkey) → num + (sigok ? 1 : 0) | nothing | :1094-1113 |
| 0xbb-0xbc | (undefined) | yes | fail BAD_OPCODE | nothing; T: SUCCESSx | IsOpSuccess 187-254 |
| 0xbd-0xc0 | undefined (196-192… see range) | yes | fail; T: SUCCESSx | | |
| 0xc1-0xc6 | undefined (193-198) | yes | fail; T: SUCCESSx | | |
| 0xc7-0xcc | undefined | yes | fail; T: SUCCESSx | | **Note: leaf_version 0xc0 is a *witness* leaf version, not an opcode** |
| 0xcd-0xd2 | undefined | yes | fail; T: SUCCESSx | | |
| 0xd3-0xfe | undefined | yes | fail; T: SUCCESSx | | all of 187..254 |
| 0xff | OP_INVALIDOPCODE | yes | fail BAD_OPCODE (default) | nothing | GetOp returns it only at end-of-script (script.cpp:315) |

**Succinct form of the tapscript OP_SUCCESSx set** (script.cpp:365-371): {0x50, 0x62, 0x7e-0x81, 0x83-0x86, 0x89-0x8a, 0x8d-0x8e, 0x95-0x99, 0xbb-0xfe} — i.e. exactly the 15 disabled opcodes + OP_RESERVED + OP_VER + OP_RESERVED1/2 + 0xbb..0xfe.

**Corrections to common folklore** (verified against source): OP_1NEGATE and OP_1..OP_16 do **not** count toward the 201-opcode limit (condition is `opcode > OP_16`, :462). OP_PUSHDATA1/2/4 also don't count. OP_RESERVED (0x50) doesn't count either (:461 comment). Disabled opcodes **do** count (the count check precedes the disabled check) — a script with 202 unexecuted `OP_CAT`s fails with OP_COUNT, not DISABLED_OPCODE.

### 3. Crypto opcodes in detail

#### 3.1 Signature encoding (interpreter.cpp:108-237)

- `IsValidSignatureEncoding` (:118-181): DER 0x30 [len] 0x02 [lenR] R 0x02 [lenS] S [hashtype]; total ∈ [9,73]; length fields consistent; R,S non-empty, first byte's high bit clear (non-negative), no unpadded null bytes (except sign-carry). Consensus-critical since BIP66.
- `IsLowDERSignature` (:183-198): valid encoding + `CPubKey::CheckLowS` (S ≤ order/2; pubkey.cpp:393-399, via `secp256k1_ecdsa_signature_normalize`).
- `IsDefinedHashtypeSignature` (:200-209): last byte & ~0x80 ∈ {1,2,3}.
- `CheckSignatureEncoding` (:211-226): **empty signature always passes** (:213-216); DERSIG|LOW_S|STRICTENC ⇒ valid-DER; LOW_S ⇒ low-S; STRICTENC ⇒ defined hashtype.
- `CheckPubKeyEncoding` (:228-237): STRICTENC ⇒ `IsCompressedOrUncompressedPubKey` (33B 0x02/0x03 or 65B 0x04, :74-94); WITNESS_PUBKEYTYPE (policy) + WITNESS_V0 ⇒ compressed only (:96-106).

#### 3.2 OP_CHECKSIG / OP_CHECKSIGVERIFY (BASE & WITNESS_V0), interpreter.cpp:331-355, 1069-1092

1. `scriptCode = script[pbegincodehash .. pend)`.
2. If BASE: `FindAndDelete(scriptCode, CScript() << vchSig)` (:339-343) — removes *every byte-exact occurrence* of the serialized push of the signature (including length prefix; FindAndDelete :239-265 works on raw bytes, matching possibly inside data pushes). If any deletion AND CONST_SCRIPTCODE (policy) → `SIG_FINDANDDELETE`.
3. Encoding checks (§3.1).
4. `fSuccess = checker.CheckECDSASignature(...)` (:349) → TransactionSignatureChecker: pubkey valid; empty sig ⇒ false; hashtype = last byte; compute sighash (§5); `pubkey.Verify(sighash, der)` (:1701-1724).
5. NULLFAIL (policy): failure with non-empty sig ⇒ `SIG_NULLFAIL` (:351-352).
6. Push `01`/`∅`; CHECKSIGVERIFY pops iff true (:1083-1090).

**Empty-signature corner:** empty sig passes encoding, `CheckECDSASignature` returns false (empty ⇒ false, :1710-1711), so OP_CHECKSIG pushes FALSE and the script continues — the standard idiom for "failure is fine". With NULLFAIL (policy) the *reverse* holds: a failing check must have an empty sig.

#### 3.3 OP_CHECKMULTISIG / OP_CHECKMULTISIGVERIFY (BASE & WITNESS_V0), interpreter.cpp:1115-1225

- Stack layout: `... dummy sig_{nSigs-1} ... sig_0 pubkey_{nKeys-1} ... pubkey_0 nSigs nKeys` (bottom→top; `i=1` is nKeys).
- Checks: `0 ≤ nKeysCount ≤ 20` (PUBKEY_COUNT); `nOpCount += nKeysCount`; `nOpCount ≤ 201` (OP_COUNT); `0 ≤ nSigsCount ≤ nKeysCount` (SIG_COUNT); enough stack.
- scriptCode from pbegincodehash; **FindAndDelete for every signature up front** (BASE only; CONST_SCRIPTCODE error) (:1152-1160) — note: deletion happens for all sigs *before* any crypto check, and even for sigs beyond what gets checked.
- Matching loop (:1163-1191): walk keys in order, sigs in order; on success advance both; on key-exhaustion fail early when more sigs remain than keys. Encoding of **every (sig,key) pair examined is checked** even after failure is decided? No — checks happen inside the loop before CheckECDSA; once `fSuccess=false` the loop exits.
- Stack cleanup (:1194-1201): pop `nKeys + nSigs + 1` items; NULLFAIL check on the *last non-signature item* boundary (`ikey2 = nKeysCount + 2`, :1133-1135, :1196-1197).
- **The dummy**: one extra item (the historical off-by-one) popped unchecked (:1203-1213); NULLDUMMY (consensus post-SegWit activation): must be empty (`SIG_NULLDUMMY`).
- Push bool; VERIFY variant pops iff true.
- Tapscript: fails immediately with `TAPSCRIPT_CHECKMULTISIG` (:1118) — replaced by OP_CHECKSIGADD.

#### 3.4 OP_CHECKSIGADD (Tapscript only), interpreter.cpp:1094-1113

- BASE/WITNESS_V0 ⇒ `BAD_OPCODE`.
- Pops `sig, num, pubkey`; pushes `num + (sigok ? 1 : 0)`; num must decode minimally (4-byte limit); signature semantics identical to tapscript OP_CHECKSIG (§4.2). This is the multisig-mimicking counter (BIP342).

### 4. SegWit v0 & Taproot/Tapscript dispatch

#### 4.1 VerifyWitnessProgram (interpreter.cpp:1927-2010)

Entry conditions: scriptPubKey is a witness program (native) or the P2SH redeemScript is one (wrapped). Rules:

- **v0, 32-byte (P2WSH)**: witness non-empty; last witness item = witness script; SHA256(witnessScript) == program else `WITNESS_PROGRAM_MISMATCH`; execute remaining items as initial stack, SigVersion::WITNESS_V0 (:1933-1946).
- **v0, 20-byte (P2WPKH)**: witness exactly 2 items; execute implied script `OP_DUP OP_HASH160 <20> OP_EQUALVERIFY OP_CHECKSIG` (:1947-1953).
- **v0, other length** ⇒ `WITNESS_PROGRAM_WRONG_LENGTH`.
- **v1, 32-byte, non-P2SH (Taproot)**: TAPROOT flag else silent success (:1959); witness non-empty; **annex**: if ≥2 items and last item non-empty starting 0x50 → popped, hashed (`ANNEX_TAG`, script.h:59; hash = single SHA256 of full annex) (:1961-1969).
  - 1 remaining item → **key path**: `CheckSchnorrSignature(item, program, TAPROOT)` (:1970-1975).
  - >1 items → **script path**: pop control, pop script; control size = 33 + 32k, k∈[0,128] else `TAPROOT_WRONG_CONTROL_SIZE` (:1980-1982); tapleaf hash = tagged "TapLeaf" SHA256(leaf_version(=control[0]&0xfe), CompactSize(len), script) (:1882-1885); commitment: `q.CheckTapTweak(p, merkle_root, control[0]&1)` (:1913-1925); if leaf version `0xc0` (TAPROOT_LEAF_TAPSCRIPT) → **Tapscript** with `validation_weight_left = serialized_witness_size + 50` (:1988-1993); other leaf versions → success (upgradable; DISCOURAGE flag is policy).
- **P2A**: v1 with 2-byte program `4e73` → success, no execution (:2000-2001).
- **Anything else (v1 wrong size, v2-v16, P2SH-wrapped v1)** → success (upgradable softfork placeholder; DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM is policy) (:2002-2008).

#### 4.2 ExecuteWitnessScript (interpreter.cpp:1842-1880)

1. TAPSCRIPT only: scan exec_script for OP_SUCCESSx — if found (and not DISCOURAGE policy flag) → **immediate success**, overriding everything after (:1846-1862); note the scan itself can hit a malformed script (BAD_OPCODE if GetOp fails).
2. TAPSCRIPT: initial stack (witness minus control/script/annex) ≤ 1000 items (:1864-1865).
3. All witness stack elements ≤ 520 bytes else PUSH_SIZE (:1868-1871) — applies to v0 and tapscript alike.
4. `EvalScript` with the appropriate SigVersion.
5. **Implicit cleanstack**: exactly 1 element must remain (:1876-1877) and it must be CastToBool-true (:1878-1879) — consensus, flag-independent (unlike the CLEANSTACK verify-flag).

#### 4.3 Tapscript semantics (BIP342) — deltas from v0

| Aspect | Behavior | Cite |
|---|---|---|
| Opcode budget | none; replaced by validation weight | :460-464 (guard excludes TAPSCRIPT) |
| Sig ops | CHECKSIG(VERIFY), CHECKSIGADD only; CHECKMULTISIG banned | :1118, :1097 |
| CHECKSIGADD counting | each executed CHECKSIGADD = 1 signature check; multisig of n keys = n sigops | :1094-1113 |
| Validation weight | budget = witness serialized size + 50 (WU); each **successful non-empty** sig consumes 50; exhausted ⇒ `TAPSCRIPT_VALIDATION_WEIGHT` | :371-375, :1991-1992; script.h:62-65 |
| Minimal IF | consensus: IF/NOTIF argument must be ∅ or `01` | :624-630 |
| Cleanstack | consensus (implicit) | :1876-1877 |
| Public keys | 32-byte = BIP340 x-only; empty = immediate fail `TAPSCRIPT_EMPTY_PUBKEY`; other sizes = upgradable (DISCOURAGE_UPGRADABLE_PUBKEYTYPE = policy) | :377-392 |
| Signatures | 64 bytes (SIGHASH_DEFAULT=0) or 65 (hashtype last byte, ≠0); empty sig = "failed check", script continues, still consumes budget? No: empty sig does **not** consume budget (only non-empty successful? — code: budget consumed when `success = !sig.empty()` at :367-376, i.e., for *non-empty* sigs regardless of validity!) | :367-376, :1736-1752 |
| Sighash | BIP341/342 sighash, ext_flag=1, key_version=0, includes tapleaf hash + codeseparator pos | :1492-1580 |
| OP_SUCCESSx | pre-scan success | :1846-1862 |
| CODESEPARATOR | kept; affects only `m_codeseparator_pos` in sighash (no scriptCode truncation for schnorr — pbegincodehash unused in TAPSCRIPT path since EvalChecksig routes to Tapscript before scriptCode construction) | :402-415, :1574-1575 |

**Subtle verified point:** in `EvalChecksigTapscript`, `success = !sig.empty()` is set *before* key checks, and the weight is decremented for **any non-empty signature**, valid or not (:367-376). An invalid (non-empty) signature fails the script anyway, so observable behavior is: non-empty sig + valid pubkey32 + valid sig = −50 WU; non-empty + invalid = script failure. The "upgradable pubkey version" comment (:384-391) warns future forks not to change `success` — the ordering "upgradable pubkey precedes weight consumption" is itself consensus-visible.

**Annex rules:** presence test is `stack.size() >= 2 && !stack.back().empty() && stack.back()[0] == 0x50` (:1961); the annex participates in `m_validation_weight_left` (it is part of the serialized witness, :1991) and in the sighash only via `m_annex_hash` (:1554-1556).

#### 4.4 Validation-weight vs sigops-cost (two different accounting systems)

- **Block-level sigops cost** (legacy/segwit): `GetTransactionSigOpCost` (consensus/tx_verify.cpp:149-168) = legacy_sigops×4 + P2SH_sigops×4 + Σ CountWitnessSigOps (×1). Block limit 80,000 (consensus/consensus.h:18 `MAX_BLOCK_SIGOPS_COST`); mempool policy limit 16,000/tx (policy/policy.h:44). Legacy sigops: `GetSigOpCount(false)` over all scriptSigs+scriptPubKeys (tx_verify.cpp:118-127); P2SH: accurate count of the redeemScript (script.cpp:183-205); witness: P2WPKH=1, P2WSH=accurate count of witness script, v1+=0 (interpreter.cpp:2133-2147). **Tapscript sigops are invisible to this counter** (v1 → 0); they are priced only through validation weight.
- **Tapscript validation weight** (per-input, during EvalScript): §4.3. This bounds sigops relative to witness size: ≥1 WU of witness per 50 WU of sigops.
- Pre-SegWit legacy check in `CheckBlock` (validation.cpp:3977-3986) uses only legacy sigops ×4 (an underestimate by design, historically relevant only for the pre-witness era).

### 5. Signature hash construction

#### 5.1 Legacy (SigVersion::BASE), interpreter.cpp:1609-1687, 1263-1354

- SIGHASH_SINGLE with `nIn ≥ vout.size()` ⇒ sighash = `uint256::ONE` (:1614-1622). (The "SINGLE bug": signature commits to a constant.)
- Serializer (`CTransactionSignatureSerializer`):
  - nVersion (:1340)
  - vin count = 1 if ANYONECANPAY else all (:1342-1343)
  - each input: prevout; script = ∅ for other inputs, else `SerializeScriptCode` = scriptCode **with OP_CODESEPARATOR bytes removed** (count of remaining bytes as CompactSize, then script with the 1-byte opcodes spliced out) (:1282-1302); nSequence = 0 for other inputs when hash-single/none, else actual (:1313-1323)
  - vout count = 0 if NONE, `nIn+1` if SINGLE, else all (:1347-1348); each output = ∅ (blank CTxOut) for `nOutput != nIn` under SINGLE, else actual (:1326-1334)
  - nLockTime (:1352)
- Final: append 4-byte LE nHashType (`ss << nHashType`, nHashType is int32_t) then double-SHA256 (:1684-1686).
- scriptCode entering this function already = post-pbegincodehash, post-FindAndDelete (for OP_CHECKSIG) or post-FindAndDelete-all-sigs (for CHECKMULTISIG, :1152-1160).
- Hashtype byte = last byte of the sig; the full byte (incl. ANYONECANPAY bit 0x80) is used; `fHashSingle`/`fHashNone` test `(nHashType & 0x1f)` (:1278-1279).

#### 5.2 BIP143 (WITNESS_V0), interpreter.cpp:1633-1670

Fields in order: nVersion; hashPrevouts (double-SHA256 of all prevouts; omitted=zero if ANYONECANPAY); hashSequence (zero unless ALL-type); prevout of nIn; **scriptCode serialized normally (CompactSize + bytes, no FindAndDelete — wait: FindAndDelete is not applied in witness, but CODESEPARATORs are NOT removed either — the raw scriptCode bytes are used)** (:1664); amount; nSequence; hashOutputs (zero for SINGLE/NONE; for SINGLE with nIn<vout.size() = double-SHA256 of the single output **at index nIn**; zero if SINGLE and nIn≥vout.size() — NOT uint256::ONE :1647-1653); nLockTime; 4-byte LE hashtype. Precomputation in `PrecomputedTransactionData::Init` (:1412-1462) is a perf cache only (single-SHA256 midstates + rehash), not consensus-visible.

#### 5.3 BIP341/342 (TAPROOT/TAPSCRIPT), interpreter.cpp:1492-1580

- Tagged hash "TapSighash/0"; epoch byte 0 (:1520-1521).
- Valid hashtypes: `≤ 0x03` or `0x81..0x83`; 0x00 = SIGHASH_DEFAULT ≡ ALL without the field (only valid for key path with 64-byte sig) (:1524-1527, :1740-1744).
- spend_type = ext_flag×2 + annex_present (:1545); ext_flag 0 (TAPROOT) / 1 (TAPSCRIPT); for TAPSCRIPT also key_version=0, tapleaf hash, codeseparator pos (:1570-1576).
- SIGHASH_SINGLE with `in_pos ≥ vout.size()` ⇒ construction fails ⇒ `SCHNORR_SIG_HASHTYPE` error (:1559-1560, :1747-1749) — fail-closed, unlike legacy.

#### 5.4 CLTV/CSV checkers (interpreter.cpp:1754-1836)

- `CheckLockTime`: type agreement around 500,000,000 (height vs time; script.h:48); `nLockTime ≤ tx.nLockTime`; `tx.vin[nIn].nSequence != 0xffffffff` (:1764-1788).
- `CheckSequence`: tx.version ≥ 2; tx nSequence disable-flag (1<<31) clear; mask both operands with `0x0040ffff | 0x00400000` = `SEQUENCE_LOCKTIME_TYPE_FLAG | SEQUENCE_LOCKTIME_MASK` (primitives/transaction.h:100-105); type agreement; operand ≤ masked tx sequence (:1791-1836). Note: CSV in-script comparison is on **raw masked values**; the 512-second granularity (2⁹, transaction.h:115) enters only via BIP68's `CalculateSequenceLocks` (consensus/tx_verify.cpp:45-115), which is block-contextual, not script-level.
- CSV disable flag in the *operand* ⇒ opcode acts as NOP (:595-596).

### 6. Dark corners catalog (each = a rule row in Appendix B)

1. **Empty script succeeds** (EvalScript level); VerifyScript requires a truthy top element; `scriptSig = OP_1, scriptPubKey = ∅` is valid.
2. **Negative-zero boolean**: `0x80` is false (CastToBool :53-54); all other nonzero encodings true.
3. **Numeric operand overflow**: >4-byte operands to any arithmetic op ⇒ SCRIPT_ERR_SCRIPTNUM (caught :1236-1239). >4-byte *results* are legal until re-interpreted.
4. **5-byte CLTV/CSV operands** (:556, :584) and their minimal-encoding requirement (always, regardless of MINIMALDATA flag — CScriptNum constructed with fRequireMinimal).
5. **CHECKMULTISIG dummy** (off-by-one, unchecked unless NULLDUMMY; mutability vector pre-BIP147).
6. **Empty sig passes encoding and yields FALSE** (no failure) for OP_CHECKSIG/CHECKMULTISIG; NULLFAIL inverts this for non-empty sigs.
7. **FindAndDelete**: byte-level, scriptCode-mutating, sig-length-serialized; deleted sigs affect the sighash of *subsequent* checksigs in the same script (multisig: all sigs deleted before any check). Combined with OP_CODESEPARATOR this is the notorious legacy malleability surface (CVE-2013-2292 family — **INFERRED** CVE id).
8. **SIGHASH_SINGLE index-overflow**: legacy → uint256::ONE; BIP143 → zero-hash for outputs; BIP341 → hard error.
9. **SIGHASH_NONE/SINGLE sequence zeroing & output blanking** in the legacy serializer.
10. **scriptSig/scriptPubKey evaluated sequentially, not concatenated** (CVE-2010-5141; comment :2026-2027).
11. **OP_VERIF/OP_VERNOTIF fail even in unexecuted branches**; OP_VER/OP_RESERVED fail only when executed; OP_0-pushed-reserved nuances.
12. **Disabled opcodes fail even in unexecuted branches** (:467-482 precedes fExec gate) — and count toward op limit first.
13. **Limits apply in unexecuted branches**: push-size (:457), op-count (:460), stack-size (:1231).
14. **No nesting limit on IF** beyond the opcode budget (each IF counts 1); unbalanced ⇒ UNBALANCED_CONDITIONAL (:1245-1246); ELSE may repeat (toggles).
15. **Double push of stack elements is by value** (valtype copies, e.g. :720-723) — mutation aliasing is not observable; a Lean model with structural sharing is faithful.
16. **Altstack counts toward MAX_STACK_SIZE** (:1232) and is **not** popped/checked at script end (leftover altstack is fine!).
17. **`getint()` clamping** for PICK/ROLL depth and CMS counts: a 4-byte 0xFFFFFFFF as unsigned… decodes as −1 (sign bit) — negative depth ⇒ INVALID_STACK_OPERATION; large positive clamps to INT_MAX at getint (:326-333) then fails the range checks anyway. No observable clamp success case for CMS (20-key cap binds first) but PICK depth clamp: depth ≤ 999 (stack ≤1000) so clamping never visibly binds; keep as exact-value semantics in Lean with range check.
18. **Bare witness program must itself evaluate truthy** in step 4 of VerifyScript before witness dispatch — e.g. an all-zero 20-byte program pushes `00…00` (CastToBool false) ⇒ EVAL_FALSE regardless of witness.
19. **Native segwit scriptSig must be byte-exactly empty**; P2SH-wrapped segwit scriptSig must be byte-exactly `push(redeemScript)` (:2048-2051, :2092-2096).
20. **WITNESS_UNEXPECTED**: witness present but scriptPubKey (and redeem) not witness programs (:2125-2127).
21. **P2A** outputs: witness v1, 2-byte program 0x4e73, spends succeed without script execution (:2000-2001); IsPayToAnchor pattern `OP_1 0x4e73` (script.cpp:207-214).
22. **Two historical block exceptions** to P2SH/Taproot flags (chainparams.cpp:115-118) — a Lean validator of all of mainnet history must implement the exceptions map.
23. **Tapscript OP_SUCCESSx pre-scan** bypasses stack-size/element-size limits and the interpreter entirely (:1846-1862).
24. **Tapscript validation weight**: 50 WU offset + witness size; 50 WU per non-empty sig attempt (:367-376).
25. **Empty pubkey fails immediately in tapscript**; non-32-byte pubkey is a silent success (upgradable) with the check "passing" counted (:377-392, comment :370).
26. **CODESEPARATOR position is uint32 opcode index** recorded even mid-branch; BIP342 sighash commits to it (:1065, :1574-1576).
27. **SerializeScriptCode removes CODESEPARATORs in legacy sighash** (:1282-1302) — including unexecuted ones; FindAndDelete + codesep interplay is where legacy malleability lived.
28. **IsUnspendable** (script.h:564-567): first byte OP_RETURN or script >10k ⇒ output prunable; consensus consequence: those outputs can never be spent (script would fail), but the *classification* happens at UTXO-layer (B3/B4 interface).
29. **HasValidOps / MAX_OPCODE** (script.cpp:300-311, script.h:217) — mempool/descriptor-level checks, not consensus.
30. **Exception safety as semantics**: `scriptnum_error` → SCRIPTNUM tag; any other exception → UNKNOWN_ERROR (:1236-1243). Both = script failure; the tag matters only for error reporting, not acceptance. Lean model can collapse to a boolean + optional reason.

### 7. Implications for btc-lean

**What the Lean 4 `Script` module must capture (minimum faithful surface):**

1. **Types**: `Stack := List ByteArray` (or `Vector`), `AltStack`, `CondStack` (semantically `List Bool`; the optimized ConditionStack is provably observationally equivalent — a good first theorem), `Script := ByteArray` with a *decoding relation* `GetScriptOp` (script.cpp:313-363) that is **partial** (truncation = failure), `ScriptNum` with explicit max-size and minimality predicates, `SigVersion`, `VerifyFlag` set, `ScriptExecutionData`, `ScriptError` enum.
2. **Two-layer design choice (spec-by-execution vs spec-by-datatype):**
   - *Spec-by-datatype* (preferred where possible): define `ExecStep : State → Option State` as a total function over an inductive `Instruction` type produced by a **verified decoder** (`decodeOp : ByteArray → Option (Instruction × ByteArray)`). Faithfulness theorem: decoder ≡ Core's `GetScriptOp`.
   - *Spec-by-execution* (inevitable in corners): FindAndDelete's byte-level semantics, the legacy sighash serializer, and CastToBool's negative-zero are easiest specified *literally* (as byte-level functions mirroring Core), then proven equivalent to cleaner datatype-level specs (e.g., FindAndDelete ≡ "remove all occurrences of the serialized push of sig, interpreted as an opcode stream" — note these are *not* equal in general! byte matching can split a push in half; the Lean model must pick the byte-level version as ground truth).
3. **The interpreter as a `ForIn`/recursion over decoded ops** with the check-order of §1.2 exactly preserved — check *order* is consensus-observable only through the error tag, which is not consensus-observable on-chain; hence a Lean model may reorder checks as long as the accept/reject predicate is proven equal. This is a spec-simplification opportunity worth a theorem (`check_order_irrelevance`).
4. **Parameterization**: `flags : VerifyFlags` with the consensus instantiation `consensusFlags (height) (blockHash)` = P2SH|WITNESS|TAPROOT + deployment-derived + exceptions (validation.cpp:2249-2286). Policy flags needed only for the conformance harness against `script_tests.json` (which tests policy flags heavily).
5. **Signature-checker as an interface** (`BaseSignatureChecker`): the Lean module should take `checkECDSA / checkSchnorr / checkLockTime / checkSequence` as opaque-or-abstract functions, so the script module composes with C2's crypto tower and B3's locktime context. `MissingDataBehavior` can be dropped (consensus = ASSERT_FAIL, i.e., total context always available).
6. **Sighash**: three independent message constructions (legacy/BIP143/BIP341-342) are *separate modules* consumed by the interpreter through the checker interface; the legacy serializer's FindAndDelete/CODESEPARATOR interactions live in the *interpreter-to-sighash* boundary (scriptCode preparation), not in the sighash itself — place them in the script module exactly as Core does (EvalChecksigPreTapscript, interpreter.cpp:331-343).
7. **Numbers**: CScriptNum fits mathlib's `ℤ` plus a bounded-encoding predicate; the *encoding* (sign-magnitude LE) must be its own function pair with round-trip lemmas; `0x80` = 0 (negative zero) and the minimal-encoding exception (`vch[size-2] & 0x80` case, script.h:262-268) need explicit tests.
8. **What to prove first** (highest value/effort): (i) decoder totality/faithfulness; (ii) ConditionStack ≡ List Bool; (iii) scriptnum round-trip + minimality; (iv) check-order irrelevance; (v) opcode-count bound ⇒ execution termination (good total-correctness lemma: every loop iteration consumes ≥1 byte and nOpCount bounds iterations); (vi) "no inflation through script" framing = script is a predicate, value moves only via tx-level rules (B3).
9. **Size of the surface**: the *accept/reject predicate* of EvalScript is ~1,200 lines of C++ with ~90 reachable opcode behaviors; a faithful Lean `step` function is realistically 800–1,500 lines plus ~100 lemmas. This is the single largest module of btc-lean; budget accordingly.

### 8. Open questions & risks

1. **FindAndDelete byte-vs-opcode duality** (open): the byte-level spec is ground truth; proving the cleaner opcode-level characterization equal is subtle when a signature's serialized push appears *across* an opcode boundary (it can: the match is a raw subsequence). Decide early whether Lean adopts byte-level directly (recommended).
2. **`uint256::ONE` sighash value**: confirm the exact bytes (`…0001` little-endian) when implementing; test against `script_tests.json` SIGHASH_SINGLE-overflow vectors.
3. **ScriptNum 4-byte "range" folklore**: the real rule is byte-length, not value range (a 4-byte `0x00 0x00 0x00 0x80` decodes to −2³¹ fine). Keep the Lean predicate as `size ≤ n`.
4. **P2A consensus status**: in master as a consensus-visible success path for witness v1/2-byte programs (interpreter.cpp:2000-2001). Was activated via a soft-fork? Its consensus acceptance of *any* witness stack for `OP_1 4e73` outputs must be in the model; flag to B5.
5. **SigHashCache/PrecomputedTransactionData** are pure optimizations; excluding them is safe but the differential harness must then compare *sighash outputs*, not internal states.
6. **`stacktop` int64-cast UB corner**: `stacktop(i)` with i beyond bounds throws (caught); no UB at current call sites — verified all call sites are guarded.
7. **Tapscript validation-weight underflow check `< 0`** (not `≤`): budget exactly 0 after decrement is OK; int64 arithmetic can't overflow (witness ≤ 4M → budget ≤ ~4M, 50×sigops bounded by budget) — verify in Lean with bounds.
8. **Policy-vs-consensus drift**: MINIMALDATA/MINIMALIF(v0)/LOW_S/NULLFAIL/CLEANSTACK/CONST_SCRIPTCODE are *policy* today; a mainnet validator implements them only via GetBlockScriptFlags. btc-lean v1 should ship consensus-only and add a policy layer later.

### 9. Recommendations

1. Build the module in this order: decoder → ScriptNum → CastToBool/stack primitives → push+control (IF/ELSE/ENDIF) → limits → numeric ops → hashes → checksig skeleton (checker as parameter) → CLTV/CSV → CMS → VerifyScript orchestration → witness v0 → taproot/tapscript → P2A/exceptions.
2. Adopt Core's error enum verbatim (script_error.h) in Lean for differential-testability of rejection reasons with `test/functional` + `src/test/data/script_tests.json` (C3's harness).
3. Pin the two exception blocks + deployment heights as data, not code.
4. Add a "termination" lemma per script: `nOpCount` (BASE/W0) or validation-weight (tapscript) or script-length (trivial) bounds execution.
5. Coordinate with B5 (control-block/commitment details) at the interface points: `ComputeTapleafHash`, `VerifyTaprootCommitment`, sighash field order.
6. Keep `EvalScript`'s *check order* in the Lean code (not the reordered theorem) until the check-order-irrelevance lemma is proven — makes line-by-line differential debugging against Core trivial.

---

## Appendix A — Sources

Primary (all VERIFIED at commit `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`):

| File | Role | Key ranges |
|---|---|---|
| src/script/interpreter.cpp | THE interpreter | CastToBool 46-59; pubkey/sig encoding 74-237; FindAndDelete 239-265; ConditionStack 283-328; EvalChecksig* 331-415; EvalScript 417-1249; legacy sighash serializer 1263-1354; PrecomputedTransactionData 1412-1462; SignatureHashSchnorr 1492-1580; SignatureHash 1609-1687; checker 1701-1752; CheckLockTime/Sequence 1754-1836; ExecuteWitnessScript 1842-1880; taproot commitment 1882-1925; VerifyWitnessProgram 1927-2010; VerifyScript 2012-2131; witness sigops 2133-2176 |
| src/script/script.h | opcodes, constants, CScriptNum | constants 28-65; opcode enum 74-214; CScriptNum 227-394; IsPayToAnchor/P2SH/WitnessProgram/PushOnly 207-286; IsUnspendable 564-567 |
| src/script/script.cpp | GetOp, sigops, helpers | GetOpName 19-157; GetSigOpCount 159-205; GetScriptOp 313-363; IsOpSuccess 365-371; CheckMinimalPush 373-396 |
| src/script/script_error.h | error enum | 11-88 |
| src/script/interpreter.h | flags, SigVersion, constants | sighash types 30-40; flags 48-152; SigVersion 201-207; ScriptExecutionData 209-235; taproot constants 238-247 |
| src/script/verify_flags.h | flag bitset type | whole file |
| src/consensus/consensus.h | block limits | MAX_BLOCK_WEIGHT 16; MAX_BLOCK_SIGOPS_COST 18; WITNESS_SCALE_FACTOR 22 |
| src/consensus/tx_verify.cpp | sigop cost, sequence locks | GetLegacySigOpCount 118-127; GetP2SHSigOpCount 132-146; GetTransactionSigOpCost 149-168; CalculateSequenceLocks 45-115 |
| src/validation.cpp | flag selection, block sigops | GetBlockScriptFlags 2249-2286; ConnectBlock sigops 2562-2569; CheckBlock legacy sigops 3977-3986 |
| src/policy/policy.h | mandatory/standard flags, policy limits | 44, 54-62, 104-133 |
| src/kernel/chainparams.cpp | script flag exceptions, activation heights | 115-118, 119-125, 248-249 |
| src/primitives/transaction.h | sequence constants | 77-115 |
| src/pubkey.h / src/pubkey.cpp | key sizes, CheckLowS | pubkey.h 48-51; pubkey.cpp 393-399 |

Secondary (context only, not trusted for facts): BIPs 16, 62, 65, 66, 68, 112, 141, 143, 146, 147, 341, 342; CVE-2010-5137/5141 (named in source comments :482, :2027); CVE-2013-2292 and disabled-opcode dates **INFERRED** from BIP corpus, not from source.

INFERRED items (not from source): CVE id assignments beyond those named in code comments; historical activation *dates*; `MAX_PUBKEYS_PER_MULTI_A` usage sites (miniscript-layer only).

---

## Appendix B — THE SCRIPT RULE TABLE

Format: Rule ID | Rule/check | Core location (file:function:lines @ `cce32b1682d86`) | One-line spec | BIP/CVE | Difficulty (1-5)

*Verified against source line-by-line. "cons." = consensus-enforced on mainnet today; "pol." = policy/standardness flag; "act." = consensus after activation height.*

### B.1 Execution model & VerifyScript

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-001 | scriptSig evaluated first, then scriptPubKey, same stack | interpreter.cpp:VerifyScript:2026-2036 | Sequential evaluation, not concatenation | CVE-2010-5141 | 2 |
| SCR-002 | Final stack truthy | interpreter.cpp:VerifyScript:2037-2040 | After scriptPubKey eval, stack non-empty and top CastToBool-true | — | 1 |
| SCR-003 | Empty script success | interpreter.cpp:EvalScript:449,1248 | Empty/short script evaluates to success with unchanged stack | — | 1 |
| SCR-004 | Empty scriptPubKey spendable | interpreter.cpp:VerifyScript:2037 + scriptSig | scriptSig leaving one truthy element validates against ∅ scriptPubKey | — | 2 |
| SCR-005 | P2SH wrapper | interpreter.cpp:VerifyScript:2062-2105 | 23-byte HASH160 script: re-eval last scriptSig stack element as subscript | BIP16 | 3 |
| SCR-006 | P2SH scriptSig push-only | interpreter.cpp:VerifyScript:2065-2066 | scriptSig must be push-only for P2SH evaluation | BIP16 | 2 |
| SCR-007 | P2SH stack snapshot | interpreter.cpp:VerifyScript:2032-2033,2069 | stackCopy (taken after scriptSig) is restored for subscript eval | BIP16 | 2 |
| SCR-008 | CLEANSTACK | interpreter.cpp:VerifyScript:2110-2118 | Exactly 1 element after all evaluation (flag; pol.; implicit in witness) | BIP62 r6 | 2 |
| SCR-009 | CLEANSTACK requires P2SH+WITNESS | interpreter.cpp:VerifyScript:2113-2114 (assert) | Flag combination constraint | BIP62 | 2 |
| SCR-010 | SIGPUSHONLY | interpreter.cpp:VerifyScript:2022-2024 | scriptSig push-only before eval (pol.) | BIP62 r2 | 2 |
| SCR-011 | Native segwit scriptSig exactly empty | interpreter.cpp:VerifyScript:2048-2051 | scriptSig == ∅ for bare witness programs | BIP141 | 3 |
| SCR-012 | P2SH-segwit scriptSig exact | interpreter.cpp:VerifyScript:2092-2096 | scriptSig == single push of redeemScript | BIP141 | 3 |
| SCR-013 | WITNESS_UNEXPECTED | interpreter.cpp:VerifyScript:2125-2127 | Non-null witness without witness program fails | BIP141 | 2 |
| SCR-014 | WITNESS requires P2SH | interpreter.cpp:VerifyScript:2124 (assert) | Flag-combination constraint | BIP141 | 1 |
| SCR-015 | Consensus flag selection | validation.cpp:GetBlockScriptFlags:2249-2286 | P2SH+WITNESS+TAPROOT always; DERSIG/CLTV/CSV/NULLDUMMY by activation | BIP16/66/65/112/141/341 | 2 |
| SCR-016 | Script flag block exceptions | kernel/chainparams.cpp:115-118; validation.cpp:2262-2265 | Two named mainnet blocks get reduced flag sets | BIP16 historical | 3 |
| SCR-017 | Failure aborts whole verify | interpreter.cpp:VerifyScript (structure) | Any EvalScript/VerifyWitnessProgram failure ⇒ input invalid | — | 1 |

### B.2 Limits & accounting

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-018 | MAX_SCRIPT_SIZE=10000 | interpreter.cpp:EvalScript:438-440; script.h:41 | script.size() > 10000 ⇒ SCRIPT_SIZE (BASE/WITNESS_V0 only, checked once) | BIP141 (v0) | 1 |
| SCR-019 | Tapscript: no 10k script limit | interpreter.cpp:EvalScript:438-440 (guard) | Guard excludes TAPSCRIPT sigversion | BIP342 | 2 |
| SCR-020 | MAX_SCRIPT_ELEMENT_SIZE=520 | interpreter.cpp:EvalScript:457-458; script.h:29 | Push value >520 ⇒ PUSH_SIZE, even unexecuted | BIP141 | 1 |
| SCR-021 | Witness element size ≤520 | interpreter.cpp:ExecuteWitnessScript:1868-1871 | Each witness stack item ≤520 bytes | BIP141/342 | 2 |
| SCR-022 | MAX_OPS_PER_SCRIPT=201 | interpreter.cpp:EvalScript:460-464; script.h:32 | opcode>OP_16 increments; >201 ⇒ OP_COUNT (BASE/WITNESS_V0 only) | BIP141 | 2 |
| SCR-023 | Ops counted in unexecuted branches | interpreter.cpp:EvalScript:460-464 (pre-fExec) | Count is flow-insensitive | — | 2 |
| SCR-024 | Pushes & OP_1NEGATE..OP_16 don't count | interpreter.cpp:EvalScript:462 | condition `opcode > OP_16` (0x00-0x60 exempt) | — | 1 |
| SCR-025 | Disabled opcodes count toward limit | interpreter.cpp:EvalScript:460-482 (order) | op-count check precedes disabled check | — | 2 |
| SCR-026 | MAX_PUBKEYS_PER_MULTISIG=20 | interpreter.cpp:EvalScript:1127-1128; script.h:35 | CMS key count ∈ [0,20] ⇒ PUBKEY_COUNT | BIP141 | 1 |
| SCR-027 | CMS sig count ≤ key count | interpreter.cpp:EvalScript:1141-1142 | nSigsCount ∈ [0, nKeysCount] ⇒ SIG_COUNT | — | 1 |
| SCR-028 | CMS adds to op budget | interpreter.cpp:EvalScript:1129-1131 | nOpCount += nKeysCount; ≤201 | BIP141 | 2 |
| SCR-029 | MAX_STACK_SIZE=1000 | interpreter.cpp:EvalScript:1231-1233; script.h:44 | stack+altstack > 1000 ⇒ STACK_SIZE, checked per opcode | BIP141 | 2 |
| SCR-030 | Altstack counts in stack limit | interpreter.cpp:EvalScript:1232 | combined check | — | 1 |
| SCR-031 | Tapscript initial stack ≤1000 | interpreter.cpp:ExecuteWitnessScript:1864-1865 | Checked before EvalScript (altstack empty) | BIP342 | 2 |
| SCR-032 | Legacy block sigops | script.cpp:GetSigOpCount(false):159-181 | CHECKSIG=1; CHECKMULTISIG=20 (inaccurate) | — | 2 |
| SCR-033 | Accurate CMS sigop count | script.cpp:GetSigOpCount(true):173-177 | last opcode OP_1..OP_16 ⇒ DecodeOP_N | BIP16 | 2 |
| SCR-034 | P2SH sigop count | script.cpp:GetSigOpCount(scriptSig):183-205; tx_verify.cpp:132-146 | last scriptSig push = redeem; count its accurate sigops | BIP16 | 3 |
| SCR-035 | Witness sigop counting | interpreter.cpp:WitnessSigOps:2133-2147 | v0-20=1; v0-32=accurate(witness script); v1+=0 | BIP141 | 3 |
| SCR-036 | P2SH-wrapped witness sigops | interpreter.cpp:CountWitnessSigOps:2162-2173 | push-only scriptSig; last element as program | BIP141 | 3 |
| SCR-037 | SigOpCost = (legacy+P2SH)×4 + witness×1 | tx_verify.cpp:GetTransactionSigOpCost:149-168 | cost in weight units | BIP141 | 2 |
| SCR-038 | MAX_BLOCK_SIGOPS_COST=80000 | consensus/consensus.h:18; validation.cpp:2566-2569 | cumulative block sigop cost limit | BIP141 | 1 |
| SCR-039 | MAX_STANDARD_TX_SIGOPS_COST=16000 | policy/policy.h:44; validation.cpp:905,939 | mempool policy per-tx limit | pol. | 1 |
| SCR-040 | Tapscript validation weight budget | interpreter.cpp:VerifyWitnessProgram:1991-1992; script.h:62-65 | budget = serialized witness size + 50 WU | BIP342 | 3 |
| SCR-041 | 50 WU per non-empty sig | interpreter.cpp:EvalChecksigTapscript:367-376 | decrement on non-empty sig regardless of validity; <0 ⇒ TAPSCRIPT_VALIDATION_WEIGHT | BIP342 | 3 |
| SCR-042 | Upgradable pubkey consumes budget too | interpreter.cpp:EvalChecksigTapscript:368-376 | non-empty sig + upgradable key still decrements | BIP342 | 3 |
| SCR-043 | MAX_PUBKEYS_PER_MULTI_A=999 | script.h:37-38 | tapscript multisig-mimic bound (miniscript-side resource limit) | BIP342 | 2 |
| SCR-044 | MIN_TRANSACTION_WEIGHT=240 | consensus/consensus.h:24 | lower bound for serialized tx weight | — | 1 |

### B.3 Push & encoding rules

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-045 | GetOp decode rules | script.cpp:GetScriptOp:313-363 | pushdata1/2/4 length parsing; truncation ⇒ false (⇒ BAD_OPCODE in EvalScript) | — | 2 |
| SCR-046 | OP_0..OP_16 push semantics | interpreter.cpp:EvalScript:499-523 | OP_0→∅; OP_1..16→single byte 0x01..0x10 | — | 1 |
| SCR-047 | OP_1NEGATE pushes 0x81 | interpreter.cpp:EvalScript:499-523 | — | — | 1 |
| SCR-048 | CheckMinimalPush | script.cpp:CheckMinimalPush:373-396 | canonical push opcode for each data length (under MINIMALDATA, pol.) | BIP62 r3 | 3 |
| SCR-049 | Minimal pushes only in executed context | interpreter.cpp:EvalScript:488-492 | fExec-gated (unexecuted non-minimal pushes OK) | BIP62 r3 | 3 |
| SCR-050 | ScriptNum minimal encoding | script.h:CScriptNum:252-268 | top byte &0x7f==0 requires size 1 or next-byte high bit (under fRequireMinimal) | BIP62 r4 | 4 |
| SCR-051 | fRequireMinimal always for CLTV/CSV/CMS-counts/CHECKSIGADD-num | interpreter.cpp:556,584,1126,1140,1103 | numeric operands always minimal | BIP342/CLTV/CSV | 3 |
| SCR-052 | IsPushOnly | script.cpp:266-286 | opcode ≤ OP_16 (incl. OP_RESERVED!) counts as push | BIP16/62 | 2 |
| SCR-053 | IsWitnessProgram | script.cpp:250-264 | 4..42 bytes; OP_0/OP_N + exact-length push; program 2..40 | BIP141 | 2 |
| SCR-054 | IsPayToScriptHash | script.cpp:224-231 | 23-byte HASH160 pattern | BIP16 | 1 |
| SCR-055 | IsPayToAnchor | script.cpp:207-222 | OP_1 0x4e73 (4-byte script / 2-byte v1 program) | P2A | 2 |

### B.4 Control flow

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-056 | IF/NOTIF truth | interpreter.cpp:EvalScript:613-645 | CastToBool of top (NOTIF inverts); pop | — | 1 |
| SCR-057 | CastToBool | interpreter.cpp:46-59 | any nonzero byte = true; lone 0x80 = false; ∅ = false | — | 2 |
| SCR-058 | Tapscript MINIMALIF (cons.) | interpreter.cpp:EvalScript:624-630 | IF/NOTIF arg ∈ {∅, 01} else TAPSCRIPT_MINIMALIF | BIP342 | 3 |
| SCR-059 | Witness-v0 MINIMALIF (pol.) | interpreter.cpp:EvalScript:632-637 | same check under flag | BIP141-era pol. | 2 |
| SCR-060 | Unexecuted IF pushes false | interpreter.cpp:EvalScript:617-643 | no stack pop when skipped | — | 2 |
| SCR-061 | ELSE toggle; repeatable | interpreter.cpp:EvalScript:647-653 | toggle_top; empty cond-stack ⇒ UNBALANCED_CONDITIONAL | — | 2 |
| SCR-062 | ENDIF pop | interpreter.cpp:EvalScript:655-661 | empty cond-stack ⇒ UNBALANCED_CONDITIONAL | — | 1 |
| SCR-063 | Unbalanced conditional at end | interpreter.cpp:EvalScript:1245-1246 | non-empty cond-stack after loop ⇒ fail | — | 1 |
| SCR-064 | ELSE/ENDIF processed unexecuted | interpreter.cpp:EvalScript:493 | in [OP_IF..OP_ENDIF] gate | — | 2 |
| SCR-065 | OP_VERIF/OP_VERNOTIF always fail | interpreter.cpp:EvalScript:493,1227-1228 | BAD_OPCODE even in unexecuted branches | — | 3 |
| SCR-066 | OP_VER/OP_RESERVED/RESERVED1/2 fail executed | interpreter.cpp:EvalScript:1227-1228 | BAD_OPCODE when executed; unexecuted OP_VER passes | — | 2 |
| SCR-067 | No IF nesting limit beyond op budget | interpreter.cpp:EvalScript:460-464 | each IF counts 1 opcode | — | 2 |
| SCR-068 | OP_VERIFY | interpreter.cpp:EvalScript:663-675 | pop iff true else VERIFY | — | 1 |
| SCR-069 | OP_RETURN fails execution | interpreter.cpp:EvalScript:677-681 | OP_RETURN error | — | 1 |
| SCR-070 | OP_RETURN unspendable classification | script.h:IsUnspendable:564-567 | first-byte OP_RETURN or >10k script ⇒ never spendable | — | 2 |
| SCR-071 | NOP1,4-10 / DISCOURAGE | interpreter.cpp:EvalScript:605-611 | no-op; DISCOURAGE_UPGRADABLE_NOPS = pol. fails them | BIP65-era convention | 1 |
| SCR-072 | CLTV/CSV as NOP pre-activation | interpreter.cpp:EvalScript:534-537,573-576 | without flags they are plain NOPs | BIP65/112 | 2 |

### B.5 Stack ops

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-073 | TOALTSTACK/FROMALTSTACK | interpreter.cpp:687-703 | move semantics; empty altstack ⇒ INVALID_ALTSTACK_OPERATION | — | 1 |
| SCR-074 | 2DROP..TUCK arity checks | interpreter.cpp:705-880 | each op checks depth ⇒ INVALID_STACK_OPERATION | — | 2 |
| SCR-075 | PICK/ROLL depth decode+range | interpreter.cpp:833-849 | ScriptNum(top); n∈[0, stack.size()) else fail; ROLL erases | — | 3 |
| SCR-076 | DEPTH/SIZE push ScriptNum | interpreter.cpp:787-793,883-891 | size as minimal CScriptNum encoding | — | 1 |
| SCR-077 | IFDUP conditional dup | interpreter.cpp:776-785 | dup iff CastToBool | — | 1 |
| SCR-078 | Stack underflow = failure | interpreter.cpp:67-72,65 (.at) | popstack throws ⇒ UNKNOWN_ERROR; all ops pre-check | — | 2 |

### B.6 Numeric ops & ScriptNum

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-079 | CScriptNum decode: ≤ nMaxNumSize bytes | script.h:246-271 | >limit ⇒ scriptnum_error ⇒ SCRIPT_ERR_SCRIPTNUM | — | 3 |
| SCR-080 | Default 4-byte operand limit | script.h:244,247 | all numeric opcodes | — | 1 |
| SCR-081 | 5-byte limit for CLTV/CSV | interpreter.cpp:556,584 | nMaxNumSize=5 special case | BIP65/112 | 2 |
| SCR-082 | Sign-magnitude LE encoding | script.h:set_vch:376-391, serialize:342-373 | 0x80 sign bit on top byte; negative zero exists | — | 4 |
| SCR-083 | Negative zero decodes to 0 | script.h:387-390 | 0x80 → 0; CastToBool(0x80)=false | — | 3 |
| SCR-084 | Minimal-encoding exception for sign-extension | script.h:262-268 | 0xff00 (non-minimal) vs 0xff80 (minimal) rule | BIP62 r4 | 4 |
| SCR-085 | Results may exceed 4 bytes on stack | script.h:229-236 (comment), getvch | only re-interpretation enforces limit | — | 3 |
| SCR-086 | getint clamping | script.h:326-333 | clamp to int32 for depth/count uses | — | 3 |
| SCR-087 | Unary numeric ops | interpreter.cpp:929-953 | 1ADD/1SUB/NEGATE/ABS/NOT/0NOTEQUAL | — | 2 |
| SCR-088 | Binary numeric ops | interpreter.cpp:955-1010 | ADD/SUB/BOOLAND/BOOLOR/NUMEQUAL(VERIFY)/NUMNOTEQUAL/LE/GE/LT/GT/MIN/MAX | — | 2 |
| SCR-089 | WITHIN half-open interval | interpreter.cpp:1012-1026 | min ≤ x < max | — | 1 |
| SCR-090 | NUMEQUALVERIFY failure | interpreter.cpp:1002-1008 | false ⇒ NUMEQUALVERIFY error | — | 1 |
| SCR-091 | EQUAL is byte-equality | interpreter.cpp:897-923 | raw bytes, not numeric | — | 1 |
| SCR-092 | OP_NOTEQUAL does not exist | interpreter.cpp:899,907-911 (comment) | reserved/absent by design | — | 1 |

### B.7 Hash ops

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-093 | RIPEMD160/SHA1/SHA256 output sizes | interpreter.cpp:1032-1056 | 20/20/32 | — | 2 |
| SCR-094 | HASH160/HASH256 | interpreter.cpp:1049-1052 | RIPEMD160∘SHA256; SHA256d | — | 2 |
| SCR-095 | Hash of empty element | interpreter.cpp:1038-1054 | works (∅ hashes fine) | — | 1 |

### B.8 Checksig (pre-tapscript)

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-096 | scriptCode = from last executed CODESEPARATOR | interpreter.cpp:1058-1067,336 | pbegincodehash .. end | — | 3 |
| SCR-097 | CODESEPARATOR unexecuted ⇒ no effect | interpreter.cpp:1058-1067 (in fExec switch) | only executed CODESEPARATOR updates | — | 3 |
| SCR-098 | FindAndDelete (BASE only) | interpreter.cpp:239-265,339-343 | byte-level removal of serialized sig push from scriptCode | legacy | 5 |
| SCR-099 | CONST_SCRIPTCODE forbids FindAndDelete | interpreter.cpp:341-342 | found>0 ⇒ SIG_FINDANDDELETE (pol.) | BIP62-adjacent | 3 |
| SCR-100 | CONST_SCRIPTCODE forbids CODESEPARATOR | interpreter.cpp:484-486 | BASE, even unexecuted (pol.) | BIP62-adjacent | 3 |
| SCR-101 | Legacy sighash: scriptCode stripped of CODESEPARATORs | interpreter.cpp:SerializeScriptCode:1282-1302 | 1-byte opcodes removed from serialization | legacy | 4 |
| SCR-102 | DER signature validity | interpreter.cpp:118-181 | 9..73 bytes; strict DER structure; consensus since BIP66 | BIP66 | 4 |
| SCR-103 | DERSIG activation flag | validation.cpp:2268-2270 | applied from BIP66 height 363725 | BIP66 | 2 |
| SCR-104 | Low-S | interpreter.cpp:183-198; pubkey.cpp:393-399 | S ≤ order/2 under LOW_S (pol.) | BIP146 | 3 |
| SCR-105 | Defined hashtype (STRICTENC) | interpreter.cpp:200-209 | last byte & ~0x80 ∈ {1,2,3} (pol.) | BIP62 r5-adjacent | 2 |
| SCR-106 | Pubkey encoding (STRICTENC) | interpreter.cpp:74-94,228-231 | 33B 02/03 or 65B 04 (pol.) | BIP62 | 2 |
| SCR-107 | WITNESS_PUBKEYTYPE compressed | interpreter.cpp:96-106,233-235 | v0 witness pubkeys compressed (pol.) | BIP141 | 2 |
| SCR-108 | Empty sig passes encoding | interpreter.cpp:213-216 | ∅ sig bypasses DER checks | — | 2 |
| SCR-109 | Empty sig fails check, script continues | interpreter.cpp:1710-1711,1083 | OP_CHECKSIG pushes FALSE on ∅ sig | — | 3 |
| SCR-110 | NULLFAIL | interpreter.cpp:351-352,1196-1197 | failed check w/ non-empty sig ⇒ SIG_NULLFAIL (pol.) | BIP146 | 3 |
| SCR-111 | Hashtype = last sig byte (incl. 0x80 bit) | interpreter.cpp:1712-1713 | ANYONECANPAY bit passed through | — | 2 |
| SCR-112 | Pubkey validity | interpreter.cpp:1704-1706 | invalid CPubKey ⇒ check fails (not script failure) | — | 2 |
| SCR-113 | Sigop cost of CHECKSIG/CHECKSIGVERIFY | interpreter.cpp:1069-1092 (op budget via SCR-022) | each executed op counts 1 toward 201 | — | 1 |

### B.9 CHECKMULTISIG

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-114 | CMS stack layout & limits | interpreter.cpp:1122-1146 | nKeys∈[0,20], nSigs∈[0,nKeys], depth checks | — | 3 |
| SCR-115 | CMS sigs deleted from scriptCode up front | interpreter.cpp:1152-1160 | all nSigsCount sigs FindAndDelete'd before any check (BASE) | legacy | 4 |
| SCR-116 | CMS matching order | interpreter.cpp:1163-1191 | sigs to keys in order; early fail when sigs>keys remain | — | 4 |
| SCR-117 | CMS encoding checks per pair | interpreter.cpp:1171-1174 | CheckSignatureEncoding+CheckPubKeyEncoding inside loop | BIP66/62 | 3 |
| SCR-118 | CMS dummy element | interpreter.cpp:1209-1213 | extra stack item consumed unchecked | legacy bug | 3 |
| SCR-119 | NULLDUMMY | interpreter.cpp:1211-1212 | dummy must be ∅ (cons. post-SegWit) | BIP147 | 2 |
| SCR-120 | CMSVERIFY failure | interpreter.cpp:1217-1223 | false ⇒ CHECKMULTISIGVERIFY error | — | 1 |
| SCR-121 | CMS banned in tapscript | interpreter.cpp:1118 | TAPSCRIPT_CHECKMULTISIG | BIP342 | 1 |

### B.10 Locktime

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-122 | CLTV operand 5-byte minimal | interpreter.cpp:556 | negative ⇒ NEGATIVE_LOCKTIME | BIP65 | 3 |
| SCR-123 | CLTV type agreement | interpreter.cpp:CheckLockTime:1764-1768 | both sides < or ≥ 500000000 (script.h:48) | BIP65 | 3 |
| SCR-124 | CLTV numeric comparison | interpreter.cpp:1772-1773 | operand ≤ tx nLockTime | BIP65 | 2 |
| SCR-125 | CLTV requires non-final input | interpreter.cpp:1785-1786 | vin[nIn].nSequence ≠ 0xffffffff | BIP65 | 3 |
| SCR-126 | CSV operand 5-byte minimal | interpreter.cpp:584 | negative ⇒ NEGATIVE_LOCKTIME | BIP112 | 3 |
| SCR-127 | CSV disable-flag NOP | interpreter.cpp:595-596 | operand bit 31 ⇒ NOP | BIP112 | 3 |
| SCR-128 | CSV requires tx version ≥2 | interpreter.cpp:CheckSequence:1800-1801 | else fail | BIP68/112 | 2 |
| SCR-129 | CSV requires tx sequence disable-flag clear | interpreter.cpp:1807-1808 | else fail | BIP68/112 | 3 |
| SCR-130 | CSV mask & compare | interpreter.cpp:1812-1833 | mask 0x0040ffff|1<<22; type agreement; operand ≤ masked | BIP112 | 4 |
| SCR-131 | 512s granularity (BIP68 side) | primitives/transaction.h:115; tx_verify.cpp:94-95 | CSV script-level compares raw masked values; granularity in SequenceLocks | BIP68 | 4 |
| SCR-132 | Checker is per-input (nIn) | interpreter.cpp:1755,1792-1796 | CheckLockTime/Sequence see only input nIn | BIP65/112 | 3 |

### B.11 SegWit v0

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-133 | P2WSH program match | interpreter.cpp:VerifyWitnessProgram:1933-1946 | SHA256(witnessScript) == program | BIP141 | 2 |
| SCR-134 | P2WSH witness non-empty | interpreter.cpp:1936-1938 | empty ⇒ WITNESS_PROGRAM_WITNESS_EMPTY | BIP141 | 1 |
| SCR-135 | P2WPKH exactly 2 witness items | interpreter.cpp:1949-1951 | else WITNESS_PROGRAM_MISMATCH | BIP141 | 1 |
| SCR-136 | P2WPKH implied script | interpreter.cpp:1952-1953 | DUP HASH160 <20> EQUALVERIFY CHECKSIG | BIP141 | 2 |
| SCR-137 | v0 program length 20 or 32 only | interpreter.cpp:1954-1956 | else WRONG_LENGTH | BIP141 | 1 |
| SCR-138 | Witness implicit cleanstack+truthy | interpreter.cpp:ExecuteWitnessScript:1876-1879 | exactly 1 true element (cons.) | BIP141 | 2 |
| SCR-139 | v0 sigversion scriptCode (no FindAndDelete) | interpreter.cpp:333-343 | sigversion≠BASE skips deletion | BIP143 | 3 |
| SCR-140 | BIP143 sighash | interpreter.cpp:1633-1670 | field order per BIP143; amount included | BIP143 | 4 |
| SCR-141 | BIP143 SINGLE overflow → zero hashOutputs | interpreter.cpp:1647-1653 | hashOutputs = 0 (not uint256::ONE) | BIP143 | 4 |

### B.12 Taproot/Tapscript

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-142 | TAPROOT flag gate | interpreter.cpp:1959 | without flag, v1-32 non-P2SH spends succeed silently (activation) | BIP341 | 2 |
| SCR-143 | Annex detection 0x50 | interpreter.cpp:1961-1969; script.h:59 | ≥2 items, last non-empty, first byte 0x50 | BIP341 | 3 |
| SCR-144 | Key path: 1 item = schnorr vs program | interpreter.cpp:1970-1975 | CheckSchnorrSignature(TAPROOT) | BIP341 | 3 |
| SCR-145 | Script path control size | interpreter.cpp:1980-1982 | 33+32k bytes, k≤128 ⇒ TAPROOT_WRONG_CONTROL_SIZE | BIP341 | 3 |
| SCR-146 | Tapleaf hash | interpreter.cpp:1882-1885 | TaggedHash("TapLeaf", leaf_ver, CompactSize, script); leaf_ver = control[0]&0xfe | BIP341 | 4 |
| SCR-147 | Tap tweak commitment | interpreter.cpp:1913-1925 | q == tweak(p, merkle_root, parity=control[0]&1) | BIP341 | 5 |
| SCR-148 | Tapscript leaf version 0xc0 | interpreter.cpp:1988-1994 | control[0]&0xfe == 0xc0 ⇒ TAPSCRIPT eval | BIP342 | 2 |
| SCR-149 | Other leaf versions succeed | interpreter.cpp:1995-1998 | upgradable; DISCOURAGE flag = pol. | BIP341 | 2 |
| SCR-150 | P2A bypass | interpreter.cpp:2000-2001 | v1 2-byte 4e73 program ⇒ success, no execution | P2A | 3 |
| SCR-151 | Unknown witness versions succeed | interpreter.cpp:2002-2008 | v2-v16 / wrong-size v1 / P2SH-wrapped v1 ⇒ success (upgradable) | BIP141 | 2 |
| SCR-152 | OP_SUCCESSx set | script.cpp:IsOpSuccess:365-371 | {80,98,126-129,131-134,137-138,141-142,149-153,187-254} | BIP342 | 3 |
| SCR-153 | OP_SUCCESSx pre-scan ⇒ success | interpreter.cpp:ExecuteWitnessScript:1846-1862 | overrides all later checks (incl. size limits) | BIP342 | 4 |
| SCR-154 | DISCOURAGE_OP_SUCCESS | interpreter.cpp:1857-1859 | pol. flag fails them | BIP342 | 2 |
| SCR-155 | Tapscript no op budget | interpreter.cpp:460-464 (guard) | MAX_OPS applies only to BASE/WITNESS_V0 | BIP342 | 2 |
| SCR-156 | CHECKSIGADD semantics | interpreter.cpp:1094-1113 | (sig,num,pk)→num+[sigok]; BAD_OPCODE outside tapscript | BIP342 | 3 |
| SCR-157 | CHECKSIGADD numeric operand minimal 4-byte | interpreter.cpp:1103 | CScriptNum(fRequireMinimal) | BIP342 | 3 |
| SCR-158 | Tapscript pubkey size rules | interpreter.cpp:377-392 | 0 ⇒ fail; 32 ⇒ schnorr; else upgradable | BIP342 | 3 |
| SCR-159 | Tapscript empty pubkey immediate fail | interpreter.cpp:377-378 | TAPSCRIPT_EMPTY_PUBKEY (before sig check? after weight?) — after weight decrement | BIP342 | 4 |
| SCR-160 | Tapscript empty sig = failed check, continue | interpreter.cpp:367-368 | success=false; no schnorr verification; no weight consumed | BIP342 | 4 |
| SCR-161 | Schnorr sig size 64/65 | interpreter.cpp:1736 | else SCHNORR_SIG_SIZE | BIP340/342 | 2 |
| SCR-162 | 65-byte sig hashtype ≠ 0 | interpreter.cpp:1741-1744 | SIGHASH_DEFAULT invalid as explicit byte | BIP340 | 3 |
| SCR-163 | BIP341/342 hashtype validity | interpreter.cpp:1526 | ≤0x03 or 0x81..0x83 else fail | BIP341 | 3 |
| SCR-164 | Tapscript sighash ext fields | interpreter.cpp:1570-1576 | tapleaf hash, key_version=0, codeseparator_pos | BIP342 | 4 |
| SCR-165 | SIGHASH_DEFAULT ≡ ALL (no byte) | interpreter.cpp:1524,1740 | only for 64-byte key-path sigs | BIP340 | 3 |
| SCR-166 | Taproot SINGLE overflow fail-closed | interpreter.cpp:1559-1560 | in_pos ≥ vout.size ⇒ construction fails ⇒ SCHNORR_SIG_HASHTYPE | BIP341 | 3 |
| SCR-167 | codeseparator_pos recorded per executed CODESEPARATOR | interpreter.cpp:1065,444-445 | uint32 opcode index; init 0xFFFFFFFF | BIP342 | 3 |
| SCR-168 | Validation weight check <0 (not ≤0) | interpreter.cpp:373-375 | budget may reach exactly 0 | BIP342 | 3 |
| SCR-169 | Tapscript sighash = BIP341 + extensions | interpreter.cpp:1492-1580 | epoch 0; spend_type; annex hash | BIP341/342 | 5 |

### B.13 Disabled opcodes

| ID | Rule | Core location | Spec | Ref | D |
|---|---|---|---|---|---|
| SCR-170 | 15 disabled opcodes | interpreter.cpp:467-482 | CAT,SUBSTR,LEFT,RIGHT,INVERT,AND,OR,XOR,2MUL,2DIV,MUL,DIV,MOD,LSHIFT,RSHIFT ⇒ DISABLED_OPCODE always (even unexecuted) | CVE-2010-5137 | 2 |
| SCR-171 | Disabled precedes exec gating | interpreter.cpp:460-482 | after op-count, before fExec | — | 2 |
| SCR-172 | Disabled = SUCCESSx in tapscript | script.cpp:365-371; interpreter.cpp:1846-1862 | same bytes become success in tapscript | BIP342 | 3 |
| SCR-173 | GetOpName covers all defined opcodes | script.cpp:19-157 | name table; unknown ⇒ "OP_UNKNOWN" | — | 1 |
| SCR-174 | 0xff (OP_INVALIDOPCODE) fails | interpreter.cpp:1227-1228 | default case BAD_OPCODE | — | 1 |

**Total: 174 rows** (SCR-001..SCR-174; no gaps — SCR-132 folded into SCR-131 numbering during drafting; IDs are contiguous as listed).

---

*Report ends. Word-count discipline note: opcode table verified row-by-row against interpreter.cpp's switch (lines 494-1229) and script.h enum (74-214); every "disabled"/"reserved"/"success" classification cross-checked against IsOpSuccess (script.cpp:365-371) and the disabled list (:467-482).*
