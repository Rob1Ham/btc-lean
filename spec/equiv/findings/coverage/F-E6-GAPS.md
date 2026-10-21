# E6 coverage dispositions

Generated from `spec/db/equiv-cells.yaml` by
`results/scripts/build_gap_report.py`. This is an index of the filed
dispositions, not a new claim. Green rows are listed for completeness.

- green: **159**
- unjudged seam: **1**
- filed gap: **23**
- still planned: **0**
- other: **0**

## Green rows

| SCR | family | cells |
|---|---|---|
| SCR-001 | exec-verify | `exec-verify/C-L-verify-sequential-boundary`, `exec-verify/C-L-w32-verify-sequential` |
| SCR-002 | exec-verify | `exec-verify/C-L-verifyscript-tail`, `exec-verify/C-L-w32-verify-final-truth` |
| SCR-004 | exec-verify | `exec-verify/C-L-verifyscript-tail`, `exec-verify/C-L-w32-witness-flag` |
| SCR-007 | exec-verify | `exec-verify/C-L-p2sh-handoff`, `exec-verify/C-L-w32-p2sh-stackcopy` |
| SCR-009 | exec-verify | `exec-verify/C-L-flags-domain`, `exec-verify/C-L-w32-flag-combo` |
| SCR-011 | exec-verify | `exec-verify/C-L-verifyscript-tail` |
| SCR-012 | exec-verify | `exec-verify/C-L-verifyscript-tail`, `exec-verify/C-L-w64-p2sh-single-push` |
| SCR-013 | exec-verify | `exec-verify/C-L-verifyscript-tail` |
| SCR-014 | exec-verify | `exec-verify/C-L-flags-domain`, `exec-verify/C-L-w32-flags-combo` |
| SCR-015 | exec-verify | `exec-verify/C-L-w32-block-flags` |
| SCR-016 | exec-verify | `exec-verify/C-L-w32-flag-exceptions` |
| SCR-017 | exec-verify | `exec-verify/C-L-failure-propagation`, `exec-verify/C-L-w32-fail-propagation` |
| SCR-018 | limits | `limits/C-L-script-size` |
| SCR-019 | limits | `limits/C-L-script-size` |
| SCR-020 | limits | `limits/C-L-push-size` |
| SCR-022 | limits | `limits/C-L-opcount` |
| SCR-023 | limits | `limits/C-L-opcount` |
| SCR-024 | limits | `limits/C-L-opcount` |
| SCR-025 | limits | `limits/C-L-opcount` |
| SCR-026 | limits | `limits/C-L-cms-count-bounds` |
| SCR-027 | limits | `limits/C-L-cms-count-bounds` |
| SCR-028 | limits | `limits/C-L-cms-count-bounds` |
| SCR-029 | limits | `limits/C-L-stack-limit` |
| SCR-030 | limits | `limits/C-L-stack-limit` |
| SCR-031 | limits | `limits/C-L-tapscript-precheck` |
| SCR-032 | limits | `limits/C-L-sigop-site-weights`, `limits/C-L-w32-sigop-count` |
| SCR-033 | limits | `limits/C-L-sigop-site-weights`, `limits/C-L-w32-sigop-count` |
| SCR-034 | limits | `limits/C-L-w32-p2sh-scriptsig` |
| SCR-035 | limits | `limits/C-L-w32-witness-sigops`, `limits/C-L-witness-sigop-dispatch` |
| SCR-037 | limits | `limits/C-L-sigop-cost-arith`, `limits/C-L-w32-sigop-cost` |
| SCR-038 | limits | `limits/C-L-sigop-cost-arith` |
| SCR-039 | limits | `limits/C-L-sigop-cost-arith` |
| SCR-040 | limits | `limits/C-L-scr-040-loop-fold`, `limits/C-L-scr-040-witness-budget`, `limits/C-L-tapscript-weight` |
| SCR-041 | limits | `limits/C-L-tapscript-weight` |
| SCR-042 | limits | `limits/C-L-tapscript-weight` |
| SCR-045 | push-encoding | `push-encoding/C-L-w32-push-parse` |
| SCR-046 | push-encoding | `push-encoding/C-L-w32-pushnum` |
| SCR-047 | push-encoding | `push-encoding/C-L-w32-pushnum` |
| SCR-048 | push-encoding | `push-encoding/C-L-w32-checkminimalpush` |
| SCR-049 | push-encoding | `push-encoding/C-L-w32-fexec-push` |
| SCR-050 | push-encoding | `push-encoding/C-L-w32-cscriptnum-minimal` |
| SCR-051 | push-encoding | `push-encoding/C-L-w32-num-callsites`, `push-encoding/C-L-w32-num-decode-minimal`, `push-encoding/C-L-w66-minimaldata-arbitrary-num` |
| SCR-052 | push-encoding | `push-encoding/C-L-pushonly`, `push-encoding/C-L-w32-pushonly-opcode` |
| SCR-053 | push-encoding | `push-encoding/C-L-w32-witness-program` |
| SCR-054 | push-encoding | `push-encoding/C-L-w32-p2sh-pattern` |
| SCR-055 | push-encoding | `push-encoding/C-L-w32-p2a-anchor` |
| SCR-056 | control-flow | `control-flow/C-L-if-notif` |
| SCR-057 | control-flow | `control-flow/C-L-casttobool`, `control-flow/C-L-casttobool-full` |
| SCR-058 | control-flow | `control-flow/C-L-if-notif` |
| SCR-059 | control-flow | `control-flow/C-L-if-notif` |
| SCR-060 | control-flow | `control-flow/C-L-if-notif` |
| SCR-061 | control-flow | `control-flow/C-L-conditional-stack` |
| SCR-062 | control-flow | `control-flow/C-L-conditional-stack` |
| SCR-063 | control-flow | `control-flow/C-L-conditional-stack` |
| SCR-064 | control-flow | `control-flow/C-L-conditional-stack` |
| SCR-065 | control-flow | `control-flow/C-L-bad-opcode` |
| SCR-066 | control-flow | `control-flow/C-L-bad-opcode` |
| SCR-067 | control-flow | `control-flow/C-L-opcount` |
| SCR-068 | control-flow | `control-flow/C-L-verify`, `stack/C-L-verify` |
| SCR-069 | control-flow | `control-flow/C-L-nop-return` |
| SCR-070 | control-flow | `control-flow/C-L-unspendable` |
| SCR-071 | control-flow | `control-flow/C-L-nop-return` |
| SCR-072 | control-flow | `control-flow/C-L-cltv-csv-nop` |
| SCR-073 | stack-ops | `e1-altstack/roundtrip`, `stack-ops/C-L-w32-altstack-step`, `stack/C-L-altstack` |
| SCR-074 | stack-ops | `e1-stack/dup-order`, `e1-stack/rot-direction`, `e1-stack/swap-order`, `stack-ops/C-L-arity`, `stack/C-L-dup-drop-swap` |
| SCR-075 | stack-ops | `e1-stack/pick-depth`, `stack-ops/C-L-pick` |
| SCR-076 | stack-ops | `e1-stack/depth-count`, `stack-ops/C-L-depth-size` |
| SCR-077 | stack-ops | `stack-ops/C-L-ifdup` |
| SCR-079 | numeric | `numeric/C-L-scriptnum-width` |
| SCR-080 | numeric | `numeric/C-L-numeric-default-4byte` |
| SCR-081 | numeric | `numeric/C-L-nmaxnum5` |
| SCR-082 | numeric | `numeric/C-L-scriptnum-sign` |
| SCR-083 | numeric | `numeric/C-L-w64-negzero` |
| SCR-084 | numeric | `numeric/C-L-scriptnum-signext-exception` |
| SCR-085 | numeric | `numeric/C-L-reinterpret-limit` |
| SCR-086 | numeric | `e2-numeric/C-L-w32-cms-getint-counts`, `e2-numeric/C-L-w66-scr086-clamp-uses` |
| SCR-087 | numeric | `numeric/C-L-unary-4byte` |
| SCR-088 | numeric | `numeric/C-L-binary-4byte` |
| SCR-089 | numeric | `e2-numeric/within-boundary`, `numeric/C-L-within-4byte` |
| SCR-090 | numeric | `numeric/C-L-binary-4byte` |
| SCR-091 | numeric | `numeric/C-L-equal-rawbytes` |
| SCR-092 | numeric | `e2-numeric/C-L-w32-disabled-2div`, `numeric/C-L-2div-disabled` |
| SCR-093 | hash-ops | `e2-hash/hash160-vector`, `hash-ops/C-L-hash-widths` |
| SCR-094 | hash-ops | `e2-hash/hash160-vector`, `hash-ops/C-L-hash-compose` |
| SCR-095 | hash-ops | `hash-ops/C-L-hash-widths` |
| SCR-096 | checksig | `checksig/C-L-w32-checksig-codesep` |
| SCR-097 | checksig | `checksig/C-L-w32-checksig-codesep` |
| SCR-098 | checksig | `checksig/C-L-w32-checksig-findanddelete` |
| SCR-099 | checksig | `checksig/C-L-w32-checksig-constscriptcode` |
| SCR-100 | checksig | `checksig/C-L-w32-checksig-codesep` |
| SCR-101 | checksig | `checksig/C-L-w32-checksig-serialize-scriptcode` |
| SCR-102 | checksig | `checksig/C-L-checksig-der` |
| SCR-103 | checksig | `checksig/C-L-checksig-bip66` |
| SCR-105 | checksig | `checksig/C-L-checksig-policy` |
| SCR-106 | checksig | `checksig/C-L-checksig-policy` |
| SCR-107 | checksig | `checksig/C-L-checksig-policy` |
| SCR-108 | checksig | `checksig/C-L-checksig-der` |
| SCR-109 | checksig | `checksig/C-L-checksig-empty` |
| SCR-110 | checksig | `checkmultisig/C-L-cms-nullfail-loop`, `checksig/C-L-checksig-nullfail-hashtype` |
| SCR-111 | checksig | `checksig/C-L-checksig-nullfail-hashtype` |
| SCR-113 | checksig | `checksig/C-L-checksig-opcount` |
| SCR-114 | checkmultisig | `checkmultisig/C-L-cms-layout-sym`, `e3-cms/C-L-cms-1of1`, `e3-cms/C-L-w32-cms-counts` |
| SCR-116 | checkmultisig | `checkmultisig/C-L-cms-order-unroll`, `e3-cms/C-L-w32-cms-loop` |
| SCR-117 | checkmultisig | `checkmultisig/C-L-cms-enc-loop`, `e3-cms/C-L-w32-cms-loop` |
| SCR-118 | checkmultisig | `checkmultisig/C-L-cms-tail-sym`, `e3-cms/C-L-cms-1of1` |
| SCR-119 | checkmultisig | `checkmultisig/C-L-cms-tail-sym`, `e3-cms/C-L-cms-1of1` |
| SCR-120 | checkmultisig | `checkmultisig/C-L-cms-tail-sym`, `e3-cms/C-L-cms-1of1` |
| SCR-121 | checkmultisig | `checkmultisig/C-L-cms-tapscript-ban` |
| SCR-122 | locktime | `locktime/C-L-cltv-op` |
| SCR-123 | locktime | `locktime/C-L-cltv-op` |
| SCR-124 | locktime | `locktime/C-L-cltv-op` |
| SCR-125 | locktime | `locktime/C-L-cltv-op` |
| SCR-126 | locktime | `locktime/C-L-csv-op` |
| SCR-127 | locktime | `locktime/C-L-csv-op` |
| SCR-128 | locktime | `locktime/C-L-csv-op` |
| SCR-129 | locktime | `locktime/C-L-csv-op` |
| SCR-130 | locktime | `locktime/C-L-csv-op` |
| SCR-131 | locktime | `locktime/C-L-csv-granularity` |
| SCR-132 | locktime | `locktime/C-L-locktime-input-index`, `locktime/C-L-locktime-input-index-general` |
| SCR-134 | witness-v0 | `e4-witness/C-L-w32-witness-v0-error-total`, `e4-witness/C-L-witness-v0-dispatch`, `witness-v0/C-L-witness-v0-dispatch` |
| SCR-135 | witness-v0 | `e4-witness/C-L-w32-witness-v0-error-total`, `e4-witness/C-L-witness-v0-dispatch`, `witness-v0/C-L-witness-v0-dispatch` |
| SCR-136 | witness-v0 | `e4-witness/C-L-w32-p2wpkh-build`, `e4-witness/C-L-w32-p2wpkh-exec`, `e4-witness/C-L-w32-p2wpkh-oracle-v0`, `witness-v0/C-L-p2wpkh-script` |
| SCR-137 | witness-v0 | `e4-witness/C-L-w32-witness-v0-error-total`, `e4-witness/C-L-witness-v0-dispatch`, `witness-v0/C-L-witness-v0-dispatch` |
| SCR-138 | witness-v0 | `witness-v0/C-L-witness-v0-cleanstack` |
| SCR-139 | witness-v0 | `witness-v0/C-L-sigversion-findanddelete` |
| SCR-141 | witness-v0 | `witness-v0/C-L-bip143-hashoutputs-single-oor` |
| SCR-143 | tapscript | `tapscript/C-L-taproot-annex` |
| SCR-144 | tapscript | `tapscript/C-L-taproot-keypath` |
| SCR-145 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch` |
| SCR-148 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch` |
| SCR-149 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch`, `tapscript/C-L-w32-witness-dispatch-upgradable` |
| SCR-150 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch`, `tapscript/C-L-w32-witness-dispatch-upgradable` |
| SCR-151 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch`, `tapscript/C-L-w32-witness-dispatch-upgradable` |
| SCR-152 | tapscript | `tapscript/C-L-tapscript-isopsuccess`, `tapscript/C-L-w32-op-success-set` |
| SCR-155 | tapscript | `tapscript/C-L-w32-opcount-budget` |
| SCR-156 | tapscript | `tapscript/C-L-w32-checksigadd` |
| SCR-157 | tapscript | `tapscript/C-L-w32-checksigadd` |
| SCR-158 | tapscript | `tapscript/C-L-w32-pubkey-triage` |
| SCR-159 | tapscript | `tapscript/C-L-w32-pubkey-triage` |
| SCR-160 | tapscript | `tapscript/C-L-w32-pubkey-triage` |
| SCR-161 | tapscript | `tapscript/C-L-w32-schnorr-shape` |
| SCR-162 | tapscript | `tapscript/C-L-w32-schnorr-shape` |
| SCR-163 | tapscript | `tapscript/C-L-w32-tap-hashtype` |
| SCR-164 | tapscript | `tapscript/C-L-w32-tap-extslice` |
| SCR-165 | tapscript | `tapscript/C-L-w32-tap-hashtype` |
| SCR-166 | tapscript | `tapscript/C-L-w32-tap-single-output` |
| SCR-168 | tapscript | `tapscript/C-L-w32-tap-vw-zero` |
| SCR-170 | disabled-opcodes | `disabled/C-L-w32-disabled-dispatch` |
| SCR-171 | disabled-opcodes | `disabled/C-L-w32-disabled-dispatch` |
| SCR-173 | disabled-opcodes | `disabled/C-L-w32-opname-table` |
| SCR-174 | disabled-opcodes | `disabled/C-L-w32-disabled-dispatch` |
| SCR-176 | policy-flags | `policy-flags/C-L-strictenc-pubkey` |
| SCR-177 | policy-flags | `policy-flags/C-L-minimaldata-push` |
| SCR-178 | policy-flags | `policy-flags/C-L-minimalif-v0` |
| SCR-179 | policy-flags | `policy-flags/C-L-nullfail` |
| SCR-180 | policy-flags | `policy-flags/C-L-cleanstack-base` |
| SCR-181 | policy-flags | `policy-flags/C-L-const-scriptcode`, `policy-flags/C-L-flag-source` |
| SCR-182 | policy-flags | `policy-flags/C-L-witness-pubkeytype` |
| SCR-183 | tapscript-reimport | `tapscript-reimport/C-L-tapscript-reimport` |

## Unjudged seams

| SCR | family | disposition |
|---|---|---|
| SCR-147 | tapscript | SCR-147 (32-byte program == x(tweak(p, merkle_root)); control[0]&1 == parity of the tweaked key): interpreter.cpp:1913-1925 checks program == x(tweak(p, merkle_root)) and control[0]&1 == tweaked-key parity. Pure secp256k1 EC; outside the seam. |

## Filed gaps

| SCR | family | disposition |
|---|---|---|
| SCR-003 | exec-verify | auto(cells): partial row coverage; exec-verify/C-L-eval-empty: partial — the cell covers only the zero-op/empty-script frame; the row's
"short script" case with one or more ops is not covered.
- empty op list                         -> success, stack unchanged;
- non-empty conditional vector at exit  -> UNBALANCED_CONDITIONAL.
The row summary says "empty/short"; this cell's reading is "a script that
parses to no opcodes", which is exactly the empty script, because any
non-empty script produces at least one opcode.  Execution of any opcode
(pushes included) is the E5 dispatch residual and is NOT covered here; the
cell therefore says nothing about "short scripts with one or more ops". |
| SCR-005 | exec-verify | auto(cells): partial row coverage; exec-verify/C-L-p2sh-handoff: - SCR-005 **partial** — "23-byte HASH160 script: re-eval last scriptSig
  stack element as subscript".  Proved: the 23-byte shape predicate
  exactly (all four fields Core reads, for arbitrary length/bytes) and the
  identification/transfer of the **last scriptSig stack element** as the
  subscript script.  NOT proved: the subscript `EvalScript(pubKey2)` call
  itself (interpreter.cpp:2080-2082) and its EVAL_FALSE checks
  (2083-2086) — the E5 dispatch residual.  The cell proves what is handed
  over, not what the re-evaluation does with it.; exec-verify/C-L-w32-p2sh-23byte: partial. Proved: (a) the 23-byte HASH160/EQUAL template predicate for every byte and length (so "23-byte HASH160 script" is exactly Core's IsPayToScriptHash, not an approximation); (b) the P2SH arm restores the post-scriptSig stack (stackCopy), removes exactly one element (the serialized redeem script, the last scriptSig stack element) and evaluates that subscript on the remainder; (c) the resulting stack's final truth is the decision; (d) the hash-equality gate and its precedence over the push-only check. NOT proved: the HASH160 computation itsel |
| SCR-006 | exec-verify | auto(cells): partial row coverage; exec-verify/C-L-pushonly: - SCR-006 **partial** — "scriptSig must be push-only for P2SH evaluation"
  (interpreter.cpp:2065-2066).  Proved: the exact `IsPushOnly` predicate
  and the `SIG_PUSHONLY` (26) result for every script of 0..8 bytes, plus
  the arm gating (only when P2SH is set and the scriptPubKey is P2SH).
  Missing: scripts longer than 8 bytes, i.e. the general unbounded
  `GetScriptOp` walk (E5 residual).  Also not claimed: that the check is
  the *only* precondition of the arm (the handoff is `C-L-p2sh-handoff`).; exec-verify/C-L-w32-p2sh-pushonly: partial — the decoded-scriptSig branch set is covered, but malformed-tail
error-kind equality is excluded as F-DIV-001:
- push-only scriptSig under P2SH passes the gate (C :2065 / Lean
  `isPushOnlyWire ops = true`),
- non-push-only scriptSig under P2SH returns SIG_PUSHONLY (C :2066 /
  Lean `.fail .sigPushOnly`), including the 0x60/0x61 boundary,
- the gate is not executed when the P2SH flag is clear (:2062), so no
  SIG_PUSHONLY can originate here without P2SH.
Named boundary of the claim: scriptSig decoding is abstracted, so the
malformed-tail input class is not judged (F-DIV-001); that  |
| SCR-008 | exec-verify | auto(cells): partial row coverage; exec-verify/C-L-verifyscript-tail: - SCR-008 partial — "exactly 1 element after all evaluation" (flag; pol.;
  interpreter.cpp:2110-2118): the flag/policy check is proved for every
  final depth in Core's order, but the witness-implicit face is blocked by
  the model divergence F-DIV-W32-01: for a valid P2SH-wrapped v0 witness
  spend Core resizes the stack to one element at :2102 while the pinned Lean
  `verifyScriptFull` reuses the redeem-script length and rejects with
  CLEANSTACK.  See findings/wave64/41-div-w32-p2sh-cleanstack.  What is
  assumed in the green flag/policy face is only the depth handed in by the
  abstracted evaluations.; exec-verify/C-L-w32-cleanstack: partial.  Covered by this cell (both tools green):
- the `flag` face: SCRIPT_VERIFY_CLEANSTACK on/off and the exact
  `stack.size() != 1` test (interpreter.cpp:2110-2118),
- the `pol.` face: the Lean model's `pol.cleanstack` reads the same bit
  and reaches the same `cleanstack` error.
NOT covered / blocked: the `implicit in witness` face.  Core resizes the
stack to one element after a successful witness program, at
:2057 (bare) and :2102 (P2SH-wrapped), so the check at :2115 ca |
| SCR-010 | exec-verify | auto(cells): partial row coverage; exec-verify/C-L-pushonly: - SCR-010 **partial** — "scriptSig push-only before eval (pol.)"
  (interpreter.cpp:2022-2024).  Proved: the policy-flag short-circuit and
  the `SIG_PUSHONLY` result for every 0..8-byte script.  Missing: the
  *sequencing* claim "before eval" — that the pre-check runs before the
  scriptSig `EvalScript` call.  That is whole-function composition
  (SCR-001 / E5 residual), not a leaf property; and the same 8-byte bound
  applies. |
| SCR-021 | limits | auto(cells): partial row coverage; limits/C-L-witness-push-size: partial — the cell proves the witness item-size predicate `any (item.size() > 520) ⇒ PUSH_SIZE` (represented exactly by max_item > 520) for base/v0 and for tapscript without OP_SUCCESSx, its ordering after the SCR-031 initial-stack guard, and the BIP342 exemption ordering (a tapscript with OP_SUCCESSx returns success before the item loop).  The OP_SUCCESSx scan itself is an abstract boolean: deciding `opSuccessScan exec` over symbolic script bytes needs the per-opcode decode loop and early success, which is SCR-153 and is not modelled here. So the row's "containing OP_SUCCESSx" branch is only modelled at its outcome, not by scanning bytes.  EvalScript is also a stub, but the row ends before it. |
| SCR-036 | limits | SCR-036 (push-only scriptSig; last element as program): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-043 | limits | SCR-043 (tapscript multisig-mimic bound (miniscript-side resource limit)): inapplicable to the script-interpreter harness, not a missing bounded limit cell. script.h:37-38 only defines MAX_PUBKEYS_PER_MULTI_A=999; at the pin the interpreter never reads it (no reference in interpreter.cpp/.h or consensus/). Its src uses are wallet construction code: miniscript.h:1879,2404,2418, miniscript.cpp:79, solver.cpp:124, descriptor.cpp:2469-2470. The consensus limits in this area are MAX_PUBKEYS_PER_MULTISIG=20 (interpreter.cpp:1195, SCR-026) and MAX_STACK_SIZE=1000 (interpreter.cpp:1309, SCR-029). The Lean model agrees (Rules.lean:346-351: "not an interpreter check ... bounds script construction") and proves only the constant identity PDW36.MAX_PUBKEYS_PER_MULTI_A_eq (rfl). A miniscript-parse cell is blocked: the pinned Lean tree has no Miniscript FromString parser (Wallet/Miniscript.lean scope note; wallet obligation MS-035 is unmodelled, WALLET-OBLIGATIONS.md:403-408) and Node.lean:442 checks an already-built AST, not parse input. No C/L pair exists in this harness, so no cell and no green are claimed. Report: spec/equiv/findings/coverage/SCR-043-miniscript-bound.md. Census flag consensus:true is inconsistent with the row text and with wallet MS-035 (consensus:false); rules.yaml is generated and was not hand-edited. |
| SCR-044 | limits | SCR-044 (lower bound for serialized tx weight): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-078 | stack-ops | auto(cells): partial row coverage; e1-stack/dup-order: partial success branch only: DUP executes at depth 2 with no underflow and no stack-size edge; the depth-failure branch of SCR-074 and the popstack path of SCR-078 are not exercised.; e1-stack/swap-order: partial success branch only: SWAP executes at depth 2 with no underflow and no opcode-budget edge; the depth-failure branch of SCR-074 and the popstack path of SCR-078 are not exercised.; stack/C-L-dup-drop-swap: partial — closed branches only: empty-stack DUP/SWAP/DROP failures plus one success composition; no symbolic depth or elements, no stack-size edge. |
| SCR-104 | checksig | auto(cells): partial row coverage; checksig/C-L-checksig-lows: The cell assumes the canonical-scalar domain `s < n` (the signature already passed strict BIP66 DER and the compact parser did not hit its overflow window). It does **not** model how S is extracted from the DER blob, nor the `ecdsa_signature_parse_der_lax` `s >= n` overflow/reduction window (the SGN-107 seam of `docs/DECISION-lax-ecdsa.md`). SCR-104 therefore stays partial.; checksig/C-L-checksig-lows-numeric: partial |
| SCR-112 | checksig | auto(cells): partial row coverage; checksig/C-L-checksig-invalid-pubkey: - `CPubKey::IsValid()` / `CPubKey::Set` is taken as an input, not computed from the pubkey bytes; the byte-level structural parse is not modelled. - The valid-key branch uses the abstract EC verdict (`crypto_ok`), i.e. the same-crypto premise of `docs/DECISION-lax-ecdsa.md`. The invalid-key implication itself does not depend on it. - No R leg (F-HARNESS-002 / F-TOOL-001). - The existing ledger anchor `e3-checksig/C-L-checksig-dispatch` is outside this task's write scope and was not edited; this cell supplements it.; checksig/C-L-checksig-pubkey-encoding: (and why the row must stay `gap`) The L leg uses `validPubKeySize` (the size-exact port already present at `Bitcoin/Crypto/EcdsaDeep/PubKeyParse.lean:135-136`), **not** the pinned `Bitcoin/Crypto/Seam/Der.isValidPubKey` (`Der.lean:175`), which is header-only and is F-DIV-004. The pinned `Seam/Entry.ecdsaVerdict` gate therefore does not compute the predicate proved here. The cell demonstrates that the corrected gate is behavior-preserving against Core and gives the exact coverage a post-fix cell would carry; it does not certify the current model. The divergence |
| SCR-115 | checkmultisig | auto(cells): partial row coverage; checkmultisig/C-L-cms-fad-probe: - FindAndDelete is abstract (algorithm = SCR-098/INV-056). - The fold and probe loop are unrolled to nSigs = nKeys <= 2; the row allows 20. Larger counts are rejected by the guard.; e3-cms/C-L-w32-cms-finddelete: partial |
| SCR-133 | witness-v0 | auto(cells): partial row coverage; e4-witness/C-L-w32-witness-hash-compare: partial for SCR-133.  The comparison half is full: for all 2^256
(digest, program) pairs the cell proves that a mismatch in any of the 32
bytes yields WITNESS_PROGRAM_MISMATCH and that a full 32-byte match
proceeds, against an independent Cryptol equality on the same marshalling.
The other half -- `CSHA256().Write(exec_script).Finalize(hash_exec_script)`
at interpreter.cpp:1940-1941 -- is not modelled.  SCR-133 is therefore not
closed: no SHA256 model exists at the leaf seam (see the task report for the
exact blocker and the smallest next experiment).; witness-v0/C-L-p2wsh-hashmatch: partial.  The row's stated check is "SHA256(witnessScript) == program".  The
32-byte equality and the mismatch/continue dispatch are proved completely
and for every input, but SHA256(witnessScript) is an abstract digest input,
so the hash computation itself is not proved.  The row stays partial; it is
not promoted as a hash proof.  Because equality is invariant under any fixed
byte permutation, the four-word encoding is an exact representation of
memcmp(digest, program, 32) == 0, not a weakened comparison. |
| SCR-140 | witness-v0 | auto(cells): partial row coverage; witness-v0/C-L-bip143-encoding-cs: partial, but this closes two limits the sibling SCR-140 cells name:
integer field ENCODING and CompactSize ordering beyond one byte.
Covered:
  (a) version, amount, nSequence, nLockTime and nHashType are written as
      little-endian wire integers at their BIP143 positions (preimage at
      L=253); the amount is exactly 8 bytes of LE u64 at [360,368), i.e.
      105 + L + 2 with L=253;
  (b) CompactSize selects a 1/3/5/9-byte prefix at the 253 / 65536 /
      2^32 boundaries for every u64 length, and each branch's bytes are
      the canonical LE encoding;
  (c) the amount offset is 105 + L + (cs_width(L) - 1) for every
      0 <= L <= 4294967295, so field order after scriptCode is correct for
      one-, three- and five-byte prefixes.
NOT covered (SCR-140 therefore stays partial):
  - the CONTENTS of hashPrevouts / hashSequence / hashOutputs.  Exact
    dependency: a decoded-transaction model (vin/vout vectors) plus the
    sub-hash serializers (serOutpointL, sequence and serTxOutL folds) and
    the ACP/SINGLE/NONE value selection, then SHA256d.  The txid/vout
    fields here are opaque wire slices; no transa |
| SCR-142 | tapscript | auto(cells): partial row coverage; tapscript/C-L-taproot-activation-gate: partial, and the remaining gap is now exact.
- COVERED: "with the flag, a v1-32 non-P2SH spend is not anyone-can-spend"
  (empty witness -> error 39; non-empty -> continuation) for every
  hash/height/shape.  COVERED: "without the flag it succeeds silently"
  for the taproot exception block, hash `…1e395ad` at height 692261, and
  for the same hash at every other height.  COVERED/NEGATIVE: the pinned
  assembly has no height term for TAPROOT, so the cell proves height
  709631 and 709632 produce identical results (the historical "only
  pre-activation" window is not a property of this pin).
- NOT COVERED: the row's historical clause "only pre-activation (height
  709632 ...)" as a height-gated behaviour.  At cce32b168 there is no
  DEPLOYMENT_TAPROOT and no height compare on the TAPROOT bit; the BIP9
  window survives only as a historical Lean record
  (Activation/Taproot.lean, TPR-075/078, min_activation 709632).  The
  exact missing contract context is filed in GAP-CONTEXT.md: the tape has
  no block-height/block-hash flag-assembly channel, and the pin has no
  function to transliterate.  A cell asserting a |
| SCR-146 | tapscript | auto(cells): partial row coverage; tapscript/C-L-tapleaf-taggedhash: partial, explicitly, and deliberately so.  SCR-146's row text names the
*digest*: `TaggedHash("TapLeaf", leaf_ver, CompactSize, script)` with
`leaf_ver = control[0] & 0xfe`.  This cell proves the complete tagged-hash
*input construction* against the named opaque oracle H:
  (a) the tag string is exactly the seven ASCII bytes "TapLeaf";
  (b) the prefix is exactly 64 bytes = T \|\| T for ONE symbolic 32-byte T,
      so the two copies are the same value (tag derivation, not two calls);
  (c) the leaf-version mask and its separation from the parity bit, for all
      256 control bytes;
  (d) the exact CompactSize encoding (1/3/5/9-byte forms, all boundaries)
      at offset 65, total over all 64-bit lengths;
  (e) the exact field map for every 64-bit length and the exact composed
      preimage byte string for scripts of 0..4 bytes;
  (f) preimage invariance under the parity bit, hence digest equality by
      function congruence for any deterministic H.
It does NOT prove SHA256: no compression, padding, length loop, streamed
vs one-shot equivalence, or concrete 32-byte value.  The residual is the
named premise
  `H = |
| SCR-153 | tapscript | auto(cells): partial row coverage; tapscript/C-L-w32-op-success-prescan: - SCR-153 "overrides all later checks (incl. size limits)": partial —
  proved for every script of length <= 4 over all byte values: an OP_SUCCESSx
  returns success before the initial stack-size check, the 520-byte item
  check and EvalScript, and its outcome is independent of those inputs.  Not
  proved: scripts longer than 4 bytes (the scan is straight-line unrolled;
  the 8-byte version was attempted and Alive2 could not discharge it inside
  the 60 s SMT budget), and the BAD_OPCODE-vs-STACK_SIZE ordering on a
  truncated tail (F-DIV-w32-001; the cell compares the found bit only). |
| SCR-154 | tapscript | auto(cells): partial row coverage; tapscript/C-L-w32-op-success-prescan: - SCR-154 "pol. flag fails them": partial — same bound: with
  DISCOURAGE_OP_SUCCESS set, every found OP_SUCCESSx in a <= 4-byte script
  yields DISCOURAGE_OP_SUCCESS (36) and not success.  The row is policy
  (consensus=false), and the flag is modelled as a policy input, not as a
  consensus ScriptFlags bit.
NOT claimed: the EvalScript result for scripts without OP_SUCCESSx
(`later_rc`), the initial stack-size/item-size preconditions themselves, and
any script longer than 4 bytes. |
| SCR-167 | tapscript | auto(cells): partial row coverage; tapscript/C-L-w32-tap-codesep-pos: partial — the counter/assignment semantics, the sentinel, the push-length independence and the executed/unexecuted distinction are proved for every pre-decoded 4-opcode stream; the byte-level parse (GetScriptOp), the fExec derivation from vfExec, the loop bound beyond four opcodes, and the switch's other branches are not modelled.  The Core loop itself is not executed by either tool.; tapscript/C-L-w64-tap-codesep-byteseq: partial — the init, the per-parsed-opcode increment, the
executed/unexecuted split, the push-length independence, the tapscript
opcode-index assignment, and the strict byte-offset/index separation are
proved for every six-byte script and symbolic fExec mask.  Not modelled:
the vfExec derivation, scripts longer than six bytes / more than six
parsed opcodes, the pre-checks named above, and the downstream
scriptCode/final-stack consumers.  Neither tool executes the Core loop. |
| SCR-169 | tapscript | auto(cells): partial row coverage; tapscript/C-L-w32-tap-epoch-annex: partial — the epoch byte/position, the spend_type formula and the annex-hash inclusion/length/first-word placement are proved for all inputs in the domain; the SHA256 of the annex, the TapSighash tagged hash, the tx-level sub-hashes and the full SigMsg byte order are not modelled.  The row's own text names the digest, so the row is not claimed full. |
| SCR-172 | disabled-opcodes | auto(cells): partial row coverage; disabled/C-L-w32-opsuccess-scan: partial. (a) The wire mapping is full: IsOpSuccess is proved over every byte 0x00..0xff, including all fifteen disabled bytes. (b) The success mechanism is proved for scripts of exactly two non-push opcodes: the scan returns success at the first success byte, in either position, before any evaluation, with the DISCOURAGE_OP_SUCCESS policy arm. Not machine-checked: the n-opcode induction for arbitrary script length (the scan is a fold of the same per-byte predicate), push-payload decode ordering (F-DIV-001), and the rest of ExecuteWitnessScript (item/stack limits, annex, control block), which is SCR-153/157/168 territory.; disabled/C-L-w64-row172-flip: partial, with the flip itself machine-checked on a one-byte script. Proved: for every 8-bit wire and every 64-bit flag word the BASE disabled classification and the tapscript one-byte OP_SUCCESSx pre-scan are exactly the table above, and the fifteen legacy-disabled wires are precisely the bytes whose outcome flips from 17 to 0 (or 36 under the policy bit). Not machine-checked: the n-opcode/arbitrary-length scan induction (the scan is a fold of the same per-byte predic |
| SCR-175 | policy-flags | auto(cells): partial row coverage; policy-flags/C-L-flag-source: partial; policy-flags/C-L-lows-policy: partial |
