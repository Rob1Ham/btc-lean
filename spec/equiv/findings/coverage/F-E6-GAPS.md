# E6 coverage dispositions

Generated from `spec/db/equiv-cells.yaml` by
`results/scripts/build_gap_report.py`. This is an index of the filed
dispositions, not a new claim. Green rows are listed for completeness.

- green: **105**
- unjudged seam: **5**
- filed gap: **73**
- still planned: **0**
- other: **0**

## Green rows

| SCR | family | cells |
|---|---|---|
| SCR-002 | exec-verify | `exec-verify/C-L-w32-verify-final-truth` |
| SCR-004 | exec-verify | `exec-verify/C-L-w32-witness-flag` |
| SCR-006 | exec-verify | `exec-verify/C-L-w32-p2sh-pushonly` |
| SCR-007 | exec-verify | `exec-verify/C-L-w32-p2sh-stackcopy` |
| SCR-009 | exec-verify | `exec-verify/C-L-w32-flag-combo` |
| SCR-014 | exec-verify | `exec-verify/C-L-w32-flags-combo` |
| SCR-015 | exec-verify | `exec-verify/C-L-w32-block-flags` |
| SCR-016 | exec-verify | `exec-verify/C-L-w32-flag-exceptions` |
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
| SCR-032 | limits | `limits/C-L-sigop-site-weights` |
| SCR-033 | limits | `limits/C-L-sigop-site-weights` |
| SCR-035 | limits | `limits/C-L-witness-sigop-dispatch` |
| SCR-037 | limits | `limits/C-L-sigop-cost-arith` |
| SCR-038 | limits | `limits/C-L-sigop-cost-arith` |
| SCR-039 | limits | `limits/C-L-sigop-cost-arith` |
| SCR-041 | limits | `limits/C-L-tapscript-weight` |
| SCR-042 | limits | `limits/C-L-tapscript-weight` |
| SCR-056 | control-flow | `control-flow/C-L-if-notif` |
| SCR-057 | control-flow | `control-flow/C-L-casttobool` |
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
| SCR-094 | hash-ops | `e2-hash/hash160-vector`, `hash-ops/C-L-hash-compose` |
| SCR-102 | checksig | `checksig/C-L-checksig-der` |
| SCR-103 | checksig | `checksig/C-L-checksig-bip66` |
| SCR-105 | checksig | `checksig/C-L-checksig-policy` |
| SCR-106 | checksig | `checksig/C-L-checksig-policy` |
| SCR-107 | checksig | `checksig/C-L-checksig-policy` |
| SCR-108 | checksig | `checksig/C-L-checksig-der` |
| SCR-109 | checksig | `checksig/C-L-checksig-empty` |
| SCR-110 | checksig | `checksig/C-L-checksig-nullfail-hashtype` |
| SCR-111 | checksig | `checksig/C-L-checksig-nullfail-hashtype` |
| SCR-113 | checksig | `checksig/C-L-checksig-opcount` |
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
| SCR-132 | locktime | `locktime/C-L-locktime-input-index` |
| SCR-134 | witness-v0 | `e4-witness/C-L-w32-witness-v0-error-total`, `e4-witness/C-L-witness-v0-dispatch`, `witness-v0/C-L-witness-v0-dispatch` |
| SCR-135 | witness-v0 | `e4-witness/C-L-w32-witness-v0-error-total`, `e4-witness/C-L-witness-v0-dispatch`, `witness-v0/C-L-witness-v0-dispatch` |
| SCR-137 | witness-v0 | `e4-witness/C-L-w32-witness-v0-error-total`, `e4-witness/C-L-witness-v0-dispatch`, `witness-v0/C-L-witness-v0-dispatch` |
| SCR-138 | witness-v0 | `witness-v0/C-L-witness-v0-cleanstack` |
| SCR-139 | witness-v0 | `witness-v0/C-L-sigversion-findanddelete` |
| SCR-141 | witness-v0 | `witness-v0/C-L-bip143-hashoutputs-single-oor` |
| SCR-143 | tapscript | `tapscript/C-L-taproot-annex` |
| SCR-144 | tapscript | `tapscript/C-L-taproot-keypath` |
| SCR-145 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch` |
| SCR-148 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch` |
| SCR-149 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch` |
| SCR-150 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch` |
| SCR-151 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch` |
| SCR-152 | tapscript | `tapscript/C-L-tapscript-isopsuccess` |
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
| SCR-181 | policy-flags | `policy-flags/C-L-const-scriptcode` |
| SCR-182 | policy-flags | `policy-flags/C-L-witness-pubkeytype` |
| SCR-183 | tapscript-reimport | `tapscript-reimport/C-L-tapscript-reimport` |

## Unjudged seams

| SCR | family | disposition |
|---|---|---|
| SCR-045 | push-encoding | SCR-045 (pushdata1/2/4 length parsing; truncation ⇒ false (⇒ BAD_OPCODE in EvalScript)): F-DIV-001 seam — Lean eager parseWire vs Core streaming GetOp changes the error kind on malformed tails; excluded per findings/cross/F-DIV-001-eager-parse.md. This is a model seam, not a tool failure. |
| SCR-146 | tapscript | SCR-146 (TaggedHash("TapLeaf", leaf_ver, CompactSize, script); leaf_ver = control[0]&0xfe): interpreter.cpp:1882-1885 computes TaggedHash("TapLeaf", leaf_version, CompactSize(script), script). Requires SHA256 and the BIP340 tagged-hash construction; outside the seam. |
| SCR-147 | tapscript | SCR-147 (32-byte program == x(tweak(p, merkle_root)); control[0]&1 == parity of the tweaked key): interpreter.cpp:1913-1925 checks program == x(tweak(p, merkle_root)) and control[0]&1 == tweaked-key parity. Pure secp256k1 EC; outside the seam. |
| SCR-153 | tapscript | SCR-153 (overrides all later checks (incl. size limits)): interpreter.cpp:1846-1862 scans the whole tapscript for OP_SUCCESSx before item-size and EvalScript, and returns success immediately. Needs a loop over symbolic script bytes and early-success control flow; the leaf harness is loop-free and does not parse scripts. |
| SCR-154 | tapscript | SCR-154 (pol. flag fails them): interpreter.cpp:1857-1859 fails with DISCOURAGE_OP_SUCCESS during the same pre-scan. Same loop/early-success seam as SCR-153; additionally a policy-flag branch. Consensus=false. |

## Filed gaps

| SCR | family | disposition |
|---|---|---|
| SCR-001 | exec-verify | auto(cells): partial row coverage; exec-verify/C-L-w32-verify-sequential: partial. Proved: (a) a scriptSig EvalScript error short-circuits before the scriptPubKey evaluation; (b) the scriptPubKey evaluation is applied to the post-scriptSig stack (depth, top and length are carried in, not reset and not concatenated); (c) the OP_DUP underflow and MAX_STACK_SIZE edges on that stack; (d) the final decision is taken on the stack the second evaluation produced. NOT proved: the CVE-2010-5141 parse-boundary witness (a push in scriptSig whose declared length would run into scriptPubKey bytes is truncated at the scriptSig end instead of consuming scriptPubKey). That needs GetScriptOp/the script-buffer boundary and the EvalScript loop, which this cell does not model; it is filed as the exact blocker in the wave-32 report. |
| SCR-003 | exec-verify | SCR-003 (Empty/short script evaluates to success with unchanged stack): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-005 | exec-verify | auto(cells): partial row coverage; exec-verify/C-L-w32-p2sh-23byte: partial. Proved: (a) the 23-byte HASH160/EQUAL template predicate for every byte and length (so "23-byte HASH160 script" is exactly Core's IsPayToScriptHash, not an approximation); (b) the P2SH arm restores the post-scriptSig stack (stackCopy), removes exactly one element (the serialized redeem script, the last scriptSig stack element) and evaluates that subscript on the remainder; (c) the resulting stack's final truth is the decision; (d) the hash-equality gate and its precedence over the push-only check. NOT proved: the HASH160 computation itself (opaque seam — `hash_match` is a symbolic premise), the serialization of the redeem script bytes vs. the scriptSig push (`scriptSig == CScript() << pubKey2`, the WITNESS_MALLEATED_P2SH check, a different row SCR-012), the BIP16 activation rule, and sigop counting. The `GetSigOpCount`/P2SH preimage paths are out of scope. |
| SCR-008 | exec-verify | auto(cells): partial row coverage; exec-verify/C-L-w32-cleanstack: partial.  Covered by this cell (both tools green):
- the `flag` face: SCRIPT_VERIFY_CLEANSTACK on/off and the exact
  `stack.size() != 1` test (interpreter.cpp:2110-2118),
- the `pol.` face: the Lean model's `pol.cleanstack` reads the same bit
  and reaches the same `cleanstack` error.
NOT covered / blocked: the `implicit in witness` face.  Core resizes the
stack to one element after a successful witness program, at
:2057 (bare) and :2102 (P2SH-wrapped), so the check at :2115 cannot fire
for those spends.  The Lean model only reproduces the bare case:
`verifyScriptFull` computes
    finalLen := if flags.witness ∧ (isWitnessProgram spk).isSome then 1
                else <re-evaluate the redeem script and take its length>
and `isWitnessProgram spk` is false for a P2SH scriptPubKey, so the
P2SH-wrapped witness spend keeps the inner length instead of 1.  The
concrete Lean evaluation and the Alive2 counterexample are in
`divergence/` (wave-32 finding F-DIV-W32-01, proposed global id
F-DIV-003).  SCR-008 stays partial until that is fixed or the row is
re-scoped. |
| SCR-010 | exec-verify | SCR-010 (scriptSig push-only before eval (pol.)): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-011 | exec-verify | SCR-011 (scriptSig == ∅ for bare witness programs): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-012 | exec-verify | SCR-012 (scriptSig == single push of redeemScript): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-013 | exec-verify | SCR-013 (Non-null witness without witness program fails): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-017 | exec-verify | auto(cells): partial row coverage; exec-verify/C-L-w32-fail-propagation: partial — the propagation combinator is proved for ALL symbolic engine
outcomes, in Core's return order, including every early return named by
interpreter.cpp:2029-2036/2052-2054/2080-2082/2097-2099. What is not
proved: that Core's EvalScript/VerifyWitnessProgram actually return those
outcomes (the E5 residual: GetScriptOp, heap, dispatch loop, exceptions),
and the CScript::IsWitnessProgram / IsPayToScriptHash / scriptSig
predicates are inputs. So the row is discharged at the wrapper seam only,
not over real scripts. |
| SCR-021 | limits | auto(cells): partial row coverage; limits/C-L-witness-push-size: partial — the cell proves the witness item-size predicate `any (item.size() > 520) ⇒ PUSH_SIZE` (represented exactly by max_item > 520) for base/v0 and for tapscript without OP_SUCCESSx, its ordering after the SCR-031 initial-stack guard, and the BIP342 exemption ordering (a tapscript with OP_SUCCESSx returns success before the item loop).  The OP_SUCCESSx scan itself is an abstract boolean: deciding `opSuccessScan exec` over symbolic script bytes needs the per-opcode decode loop and early success, which is SCR-153 and is not modelled here. So the row's "containing OP_SUCCESSx" branch is only modelled at its outcome, not by scanning bytes.  EvalScript is also a stub, but the row ends before it. |
| SCR-034 | limits | SCR-034 (malformed or non-push-only scriptSig returns zero; otherwise count the final push data's valid script prefix accurately): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-036 | limits | SCR-036 (push-only scriptSig; last element as program): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-040 | limits | auto(cells): partial row coverage; limits/C-L-tapscript-weight: - SCR-040 (budget = serialized witness stack size including the
  CompactSize item count, + 50 WU): partial. The formula, the item-count
  CompactSize and the per-item CompactSize+bytes are proved for 0..4 items
  and all 32-bit item lengths; the CompactSize 1/3/5-byte branches are all
  exercised. Missing: an unbounded item count (the cell has four length
  arguments) and the 9-byte CompactSize branch (an item > 2^32-1 bytes,
  unreachable in a valid serialized witness). It must not be cited as a
  full SCR-040 green.
- SCR-041 (decrement on non-empty sig regardless of validity; < 0 =>
  TAPSCRIPT_VALIDATION_WEIGHT): full. The decrement by 50 is proved for
  every non-empty signature and every signed weight value, the negative
  test is exact, and its precedence over the pubkey rules is proved.
  Signature validity is the `checker_ok` input, so the decrement is shown
  for both outcomes, including an invalid signature.
- SCR-042 (non-empty sig + upgradable key still decrements): full. For
  pk_class = 2 (every size other than 0 and 32) with a non-empty signature,
  the budget is decremented before the discouragement b |
| SCR-043 | limits | SCR-043 (tapscript multisig-mimic bound (miniscript-side resource limit)): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-044 | limits | SCR-044 (lower bound for serialized tx weight): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-046 | push-encoding | SCR-046 (OP_0→∅; OP_1..16→single byte 0x01..0x10): no push-encoding cell was built for this row; E1/E2 leaves cover only OP_0/OP_1..16 and fixed pushes; the parse/truncation seam is recorded separately (F-DIV-001). No green is claimed. |
| SCR-047 | push-encoding | SCR-047 (OP_1NEGATE (0x4f) pushes the single byte 0x81: encodeScriptNum (-1) false = serU8 0x81, and an executed OP_1NEGATE pushes it with no MINIMALDATA gate): no push-encoding cell was built for this row; E1/E2 leaves cover only OP_0/OP_1..16 and fixed pushes; the parse/truncation seam is recorded separately (F-DIV-001). No green is claimed. |
| SCR-048 | push-encoding | SCR-048 (canonical push opcode for each data length (under MINIMALDATA, pol.)): no push-encoding cell was built for this row; E1/E2 leaves cover only OP_0/OP_1..16 and fixed pushes; the parse/truncation seam is recorded separately (F-DIV-001). No green is claimed. |
| SCR-049 | push-encoding | SCR-049 (fExec-gated (unexecuted non-minimal pushes OK)): no push-encoding cell was built for this row; E1/E2 leaves cover only OP_0/OP_1..16 and fixed pushes; the parse/truncation seam is recorded separately (F-DIV-001). No green is claimed. |
| SCR-050 | push-encoding | SCR-050 (top byte &0x7f==0 requires size 1 or next-byte high bit (under fRequireMinimal)): no push-encoding cell was built for this row; E1/E2 leaves cover only OP_0/OP_1..16 and fixed pushes; the parse/truncation seam is recorded separately (F-DIV-001). No green is claimed. |
| SCR-051 | push-encoding | SCR-051 (minimal numeric operands under MINIMALDATA (policy, not consensus)): no push-encoding cell was built for this row; E1/E2 leaves cover only OP_0/OP_1..16 and fixed pushes; the parse/truncation seam is recorded separately (F-DIV-001). No green is claimed. |
| SCR-052 | push-encoding | SCR-052 (opcode ≤ OP_16 (incl. OP_RESERVED!) counts as push): no push-encoding cell was built for this row; E1/E2 leaves cover only OP_0/OP_1..16 and fixed pushes; the parse/truncation seam is recorded separately (F-DIV-001). No green is claimed. |
| SCR-053 | push-encoding | SCR-053 (4..42 bytes; OP_0/OP_N + exact-length push; program 2..40): no push-encoding cell was built for this row; E1/E2 leaves cover only OP_0/OP_1..16 and fixed pushes; the parse/truncation seam is recorded separately (F-DIV-001). No green is claimed. |
| SCR-054 | push-encoding | SCR-054 (23-byte HASH160 pattern): no push-encoding cell was built for this row; E1/E2 leaves cover only OP_0/OP_1..16 and fixed pushes; the parse/truncation seam is recorded separately (F-DIV-001). No green is claimed. |
| SCR-055 | push-encoding | SCR-055 (OP_1 0x4e73 (4-byte script / 2-byte v1 program)): no push-encoding cell was built for this row; E1/E2 leaves cover only OP_0/OP_1..16 and fixed pushes; the parse/truncation seam is recorded separately (F-DIV-001). No green is claimed. |
| SCR-072 | control-flow | SCR-072: withdrawn from green after independent audit. The control-flow cell covers NOP/NOP1/NOP4..OP_NOP10/OP_RETURN only; it does not execute CLTV (0xb1) or CSV (0xb2) with the activation flag off, so the pre-activation NOP behavior named by the row is not modelled. Needs a bounded flag-off CLTV/CSV cell; no green is claimed. |
| SCR-073 | stack-ops | auto(cells): partial row coverage; e1-altstack/roundtrip: partial success branch only: TOALTSTACK/FROMALTSTACK roundtrip with budget available and nonempty stacks; empty-main/empty-alt failures and the OP_COUNT edge of SCR-073 are not exercised.; stack/C-L-altstack: partial — closed branches only: empty-alt FROMALTSTACK, empty-main TOALTSTACK, and a success roundtrip; no opcode-budget/OP_COUNT edge, no symbolic stacks. |
| SCR-074 | stack-ops | auto(cells): partial row coverage; e1-stack/dup-order: partial success branch only: DUP executes at depth 2 with no underflow and no stack-size edge; the depth-failure branch of SCR-074 and the popstack path of SCR-078 are not exercised.; e1-stack/rot-direction: partial success branch only: ROT executes at depth 3 with no underflow; the depth-failure branch of SCR-074 is not exercised.; e1-stack/swap-order: partial success branch only: SWAP executes at depth 2 with no underflow and no opcode-budget edge; the depth-failure branch of SCR-074 and the popstack path of SCR-078 are not exercised.; stack-ops/C-L-arity: partial — every opcode in the 2DROP..TUCK arity set is exercised only at an empty stack (n=0) against its per-case Core guard and twin handler. This does not prove all insufficient-depth boundaries for ops that require more than one item; off-by-one threshold mutants survive. The success branches are covered by other E1 cells and are not part of this row.; stack/C-L-dup-drop-swap: partial — closed branches only: empty-stack DUP/SWAP/DROP failures plus one success composition; no symbolic depth or elements, no stack-size edge. |
| SCR-075 | stack-ops | auto(cells): partial row coverage; e1-stack/pick-depth: partial success branch only: PICK selects index 2 at depth 4 (the bottom item); index-bounds/underflow and ROLL are not exercised, so SCR-075 is not discharged as a whole. |
| SCR-076 | stack-ops | auto(cells): partial row coverage; e1-stack/depth-count: partial success branch only: DEPTH at depth 2 pushes the minimal CScriptNum encoding 2; DEPTH at 0/1 and the larger-encoding branches of SCR-076 are not exercised. |
| SCR-077 | stack-ops | SCR-077 (dup iff CastToBool): E1 cells cover only the listed branches; the missing underflow/OOB/budget branch for this row is named in the cell notes. No green is claimed. |
| SCR-078 | stack-ops | auto(cells): partial row coverage; e1-stack/dup-order: partial success branch only: DUP executes at depth 2 with no underflow and no stack-size edge; the depth-failure branch of SCR-074 and the popstack path of SCR-078 are not exercised.; e1-stack/swap-order: partial success branch only: SWAP executes at depth 2 with no underflow and no opcode-budget edge; the depth-failure branch of SCR-074 and the popstack path of SCR-078 are not exercised.; stack/C-L-dup-drop-swap: partial — closed branches only: empty-stack DUP/SWAP/DROP failures plus one success composition; no symbolic depth or elements, no stack-size edge. |
| SCR-079 | numeric | SCR-079 (>limit ⇒ scriptnum_error ⇒ SCRIPT_ERR_SCRIPTNUM): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-080 | numeric | SCR-080 (all numeric opcodes): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-081 | numeric | SCR-081 (nMaxNumSize=5 special case): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-082 | numeric | SCR-082 (0x80 sign bit on top byte; negative zero exists): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-083 | numeric | SCR-083 (0x80 → 0; CastToBool(0x80)=false): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-084 | numeric | SCR-084 (CScriptNum minimal-encoding sign-extension exception: +255 and -255 encode to 0xff00 and 0xff80 (little-endian on the wire) and BOTH are minimal; the exception ): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-085 | numeric | SCR-085 (only re-interpretation enforces limit): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-086 | numeric | SCR-086 (clamp to int32 for depth/count uses): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-087 | numeric | SCR-087 (1ADD/1SUB/NEGATE/ABS/NOT/0NOTEQUAL): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-088 | numeric | SCR-088 (ADD/SUB/BOOLAND/BOOLOR/NUMEQUAL/NUMNOTEQUAL/LE/GE/LT/GT/MIN/MAX (wire 0x93, 0x94, 0x9a-0x9c, 0x9e-0xa4) push the binary result; OP_NUMEQUALVERIFY (0x9d) is a se): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-089 | numeric | auto(cells): partial row coverage; e2-numeric/within-boundary: partial — the cell is symbolic over all 2^24 single-byte operand triples, which is the full half-open-interval rule for one-byte CScriptNum operands. It does not exercise 2-4 byte operands or the SCR-079/SCR-080 width cap, nor the stack-underflow branch of SCR-078; those are separate rows/gaps, not hidden extensions of this cell. |
| SCR-090 | numeric | SCR-090 (false ⇒ NUMEQUALVERIFY error): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-091 | numeric | SCR-091 (raw bytes, not numeric): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-092 | numeric | SCR-092 (0x8e is OP_2DIV (no OP_NOTEQUAL opcode exists); legacy and witness-v0 execution reject it as a disabled opcode, and tapscript treats it as OP_SUCCESS142): E2 numeric attempt did not produce a cell for this row; the CScriptNum/opcode path is not proved. No green is claimed. |
| SCR-093 | hash-ops | auto(cells): partial row coverage; e2-hash/hash160-vector: partial — one concrete HASH160 witness establishes the 20-byte output width (SCR-093's HASH160 arm) and the RIPEMD160(SHA256(x)) composition seam (SCR-094) for that preimage. The SHA256/HASH256/RIPEMD160 output widths, the empty-element row SCR-095, and the hash functions themselves are not proved: the transform is an opaque external on both legs and the SAW override supplies the concrete digest.; hash-ops/C-L-hash-widths: partial |
| SCR-095 | hash-ops | auto(cells): partial row coverage; hash-ops/C-L-hash-widths: partial |
| SCR-096 | checksig | SCR-096 (pbegincodehash .. end): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-097 | checksig | SCR-097 (only executed CODESEPARATOR updates): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-098 | checksig | SCR-098 (byte-level removal of each matched serialized sig push from scriptCode, continuing after the match): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-099 | checksig | SCR-099 (found>0 ⇒ SIG_FINDANDDELETE (pol.)): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-100 | checksig | SCR-100 (BASE, even unexecuted (pol.)): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-101 | checksig | SCR-101 (1-byte opcodes removed from serialization): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-104 | checksig | auto(cells): partial row coverage; checksig/C-L-checksig-lows: partial |
| SCR-112 | checksig | auto(cells): partial row coverage; checksig/C-L-checksig-invalid-pubkey: partial; e3-checksig/C-L-checksig-dispatch: partial |
| SCR-114 | checkmultisig | auto(cells): partial row coverage; e3-cms/C-L-cms-1of1: partial |
| SCR-115 | checkmultisig | SCR-115 (all nSigsCount sigs FindAndDelete'd before any check (BASE)): E3 CMS attempt did not cover this row; R is domain-limited (F-HARNESS-002), and the CMS loop/error-enum equality is not a green cell. No green is claimed. |
| SCR-116 | checkmultisig | SCR-116 (sigs to keys in order; early fail when sigs>keys remain): E3 CMS attempt did not cover this row; R is domain-limited (F-HARNESS-002), and the CMS loop/error-enum equality is not a green cell. No green is claimed. |
| SCR-117 | checkmultisig | SCR-117 (CheckSignatureEncoding+CheckPubKeyEncoding inside loop): E3 CMS attempt did not cover this row; R is domain-limited (F-HARNESS-002), and the CMS loop/error-enum equality is not a green cell. No green is claimed. |
| SCR-118 | checkmultisig | auto(cells): partial row coverage; e3-cms/C-L-cms-1of1: partial |
| SCR-119 | checkmultisig | auto(cells): partial row coverage; e3-cms/C-L-cms-1of1: partial |
| SCR-120 | checkmultisig | auto(cells): partial row coverage; e3-cms/C-L-cms-1of1: partial |
| SCR-121 | checkmultisig | SCR-121 (TAPSCRIPT_CHECKMULTISIG): E3 CMS attempt did not cover this row; R is domain-limited (F-HARNESS-002), and the CMS loop/error-enum equality is not a green cell. No green is claimed. |
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
| SCR-136 | witness-v0 | auto(cells): partial row coverage; e4-witness/C-L-w32-p2wpkh-build: partial for SCR-136.  The reconstruction half is full: for every 20-byte
program the cell proves that the C `exec_script << OP_DUP << OP_HASH160 <<
program << OP_EQUALVERIFY << OP_CHECKSIG` byte expansion and the Lean list
`[0x76,0xa9,0x14] ++ program ++ [0x88,0xac]` emit the same 25 bytes, with
the correct PUSHDATA length prefix 0x14.  The row's second half --
executing that script through ExecuteWitnessScript (EvalScript loop,
HASH160, ECDSA CHECKSIG, cleanstack) -- is not modelled and remains a
blocker; see the task report.; witness-v0/C-L-p2wpkh-script: partial.  The row's script bytes are fully reconstructed and proved for
every symbolic program: DUP HASH160 <20-byte program> EQUALVERIFY CHECKSIG.
What is missing is the row's second half, `ExecuteWitnessScript` on those
bytes (interpreter.cpp:1953): the EvalScript loop, push parsing, HASH160 and
ECDSA/CHECKSIG are not modelled.  SCR-136 therefore stays partial and is not
promoted to full. |
| SCR-140 | witness-v0 | auto(cells): partial row coverage; witness-v0/C-L-bip143-layout: partial.  The row asks for "field order per BIP143; amount included".  This
cell proves the complete 10-field order, every width and offset, and the
presence/position of the 8-byte amount, for all field ids and all
script lengths in [0,75].  It does not model the field CONTENTS: the three
sub-hashes (hashPrevouts/hashSequence/hashOutputs), the transaction
serializer, or the final double SHA256.  Those keep SCR-140 partial; it is
not promoted to full. |
| SCR-142 | tapscript | auto(cells): partial row coverage; tapscript/C-L-taproot-gate: partial. The in-function gate is proved total: flag off -> success with no
witness inspection; flag on -> empty witness fails 39, non-empty continues
into the annex/key/script dispatch. The row also names activation height
709632 and exception block 692261. Those are caller-side flag assembly
outside VerifyWitnessProgram and have no block-height channel in
contract/tape.md, so that arm is not exercised here. |
| SCR-155 | tapscript | SCR-155 (the MAX_OPS budget is not consulted on the tapscript path: an already-over-budget tapscript OP_NOP still succeeds and leaves opCount untouched; on BASE/WITNESS_): interpreter.cpp:460-464 is the MAX_OPS guard, skipped for TAPSCRIPT. A bounded stepBody leaf can set opCount>201 and run OP_NOP in BASE/WITNESS_V0 and TAPSCRIPT; the twin has stepBody handlers. Not attempted. (This is the op-count budget, not sigops.) |
| SCR-167 | tapscript | auto(cells): partial row coverage; tapscript/C-L-w32-tap-codesep-pos: partial — the counter/assignment semantics, the sentinel, the push-length independence and the executed/unexecuted distinction are proved for every pre-decoded 4-opcode stream; the byte-level parse (GetScriptOp), the fExec derivation from vfExec, the loop bound beyond four opcodes, and the switch's other branches are not modelled.  The Core loop itself is not executed by either tool. |
| SCR-169 | tapscript | auto(cells): partial row coverage; tapscript/C-L-w32-tap-epoch-annex: partial — the epoch byte/position, the spend_type formula and the annex-hash inclusion/length/first-word placement are proved for all inputs in the domain; the SHA256 of the annex, the TapSighash tagged hash, the tx-level sub-hashes and the full SigMsg byte order are not modelled.  The row's own text names the digest, so the row is not claimed full. |
| SCR-172 | disabled-opcodes | auto(cells): partial row coverage; disabled/C-L-w32-opsuccess-scan: partial. (a) The wire mapping is full: IsOpSuccess is proved over every byte 0x00..0xff, including all fifteen disabled bytes. (b) The success mechanism is proved for scripts of exactly two non-push opcodes: the scan returns success at the first success byte, in either position, before any evaluation, with the DISCOURAGE_OP_SUCCESS policy arm. Not machine-checked: the n-opcode induction for arbitrary script length (the scan is a fold of the same per-byte predicate), push-payload decode ordering (F-DIV-001), and the rest of ExecuteWitnessScript (item/stack limits, annex, control block), which is SCR-153/157/168 territory. |
| SCR-175 | policy-flags | auto(cells): partial row coverage; policy-flags/C-L-lows-policy: partial |
