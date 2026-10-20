# E6 coverage dispositions

Generated from `spec/db/equiv-cells.yaml` by
`results/scripts/build_gap_report.py`. This is an index of the filed
dispositions, not a new claim. Green rows are listed for completeness.

- green: **22**
- unjudged seam: **17**
- filed gap: **144**
- still planned: **0**
- other: **0**

## Green rows

| SCR | family | cells |
|---|---|---|
| SCR-018 | limits | `limits/C-L-script-size` |
| SCR-019 | limits | `limits/C-L-script-size` |
| SCR-020 | limits | `limits/C-L-push-size` |
| SCR-022 | limits | `limits/C-L-opcount` |
| SCR-023 | limits | `limits/C-L-opcount` |
| SCR-024 | limits | `limits/C-L-opcount` |
| SCR-025 | limits | `limits/C-L-opcount` |
| SCR-029 | limits | `limits/C-L-stack-limit` |
| SCR-030 | limits | `limits/C-L-stack-limit` |
| SCR-031 | limits | `limits/C-L-tapscript-precheck` |
| SCR-069 | control-flow | `control-flow/C-L-nop-return` |
| SCR-071 | control-flow | `control-flow/C-L-nop-return` |
| SCR-072 | control-flow | `control-flow/C-L-nop-return` |
| SCR-074 | stack-ops | `e1-stack/dup-order`, `e1-stack/rot-direction`, `e1-stack/swap-order`, `stack-ops/C-L-arity`, `stack/C-L-dup-drop-swap` |
| SCR-143 | tapscript | `tapscript/C-L-taproot-annex` |
| SCR-144 | tapscript | `tapscript/C-L-taproot-keypath` |
| SCR-145 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch` |
| SCR-148 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch` |
| SCR-149 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch` |
| SCR-150 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch` |
| SCR-151 | tapscript | `tapscript/C-L-taproot-scriptpath-dispatch` |
| SCR-152 | tapscript | `tapscript/C-L-tapscript-isopsuccess` |

## Unjudged seams

| SCR | family | disposition |
|---|---|---|
| SCR-045 | push-encoding | SCR-045 (pushdata1/2/4 length parsing; truncation ⇒ false (⇒ BAD_OPCODE in EvalScript)): F-DIV-001 seam — Lean eager parseWire vs Core streaming GetOp changes the error kind on malformed tails; excluded per findings/cross/F-DIV-001-eager-parse.md. This is a model seam, not a tool failure. |
| SCR-133 | witness-v0 | SCR-133 (SHA256(witnessScript) == program): interpreter.cpp:1939-1945 computes a single SHA256 over the popped witnessScript and memcmp's 32 bytes against the program. No SHA256 model exists at the leaf seam; abstracting the equality boolean would prove only the surrounding branch, not the row's hash claim. |
| SCR-136 | witness-v0 | SCR-136 (DUP HASH160 <20> EQUALVERIFY CHECKSIG): interpreter.cpp:1952-1953 reconstructs OP_DUP OP_HASH160 <program> OP_EQUALVERIFY OP_CHECKSIG and runs it through ExecuteWitnessScript. Requires the EvalScript loop, push parsing, HASH160 and ECDSA/CHECKSIG; the cell seam has none of them. |
| SCR-138 | witness-v0 | SCR-138 (exactly 1 true element (cons.)): interpreter.cpp:1876-1879 checks the stack after EvalScript returns: exactly one item and CastToBool true. This is an EvalScript post-state property; the leaf dispatch cell never runs the interpreter and cannot observe the final stack. |
| SCR-140 | witness-v0 | SCR-140 (field order per BIP143; amount included): interpreter.cpp:1633-1670 builds the BIP143 preimage (field order, amount, prevouts, outputs, hashOutputs) and hashes it. Requires the tx serializer and hash model; no tx decoder is in the seam. |
| SCR-141 | witness-v0 | SCR-141 (hashOutputs = 0 (not uint256::ONE)): interpreter.cpp:1647-1653 selects a zero hashOutputs when the SINGLE input index is out of range. The branch is pure, but it is defined over the serialized output vector and feeds the sighash preimage; the tape decoder and hash are outside the seam. |
| SCR-146 | tapscript | SCR-146 (TaggedHash("TapLeaf", leaf_ver, CompactSize, script); leaf_ver = control[0]&0xfe): interpreter.cpp:1882-1885 computes TaggedHash("TapLeaf", leaf_version, CompactSize(script), script). Requires SHA256 and the BIP340 tagged-hash construction; outside the seam. |
| SCR-147 | tapscript | SCR-147 (32-byte program == x(tweak(p, merkle_root)); control[0]&1 == parity of the tweaked key): interpreter.cpp:1913-1925 checks program == x(tweak(p, merkle_root)) and control[0]&1 == tweaked-key parity. Pure secp256k1 EC; outside the seam. |
| SCR-153 | tapscript | SCR-153 (overrides all later checks (incl. size limits)): interpreter.cpp:1846-1862 scans the whole tapscript for OP_SUCCESSx before item-size and EvalScript, and returns success immediately. Needs a loop over symbolic script bytes and early-success control flow; the leaf harness is loop-free and does not parse scripts. |
| SCR-154 | tapscript | SCR-154 (pol. flag fails them): interpreter.cpp:1857-1859 fails with DISCOURAGE_OP_SUCCESS during the same pre-scan. Same loop/early-success seam as SCR-153; additionally a policy-flag branch. Consensus=false. |
| SCR-156 | tapscript | SCR-156 ((sig,num,pk)→num+[sigok]; BAD_OPCODE outside tapscript): interpreter.cpp:1094-1113 pops (sig,num,pk), adds the signature check result, and rejects outside tapscript. The stack effect is leaf-shaped but the signature check is the Schnorr/EC seam; no checker. |
| SCR-160 | tapscript | SCR-160 (An empty tapscript signature against a 32-byte x-only key fails the check and continues: no Schnorr verification and no validation weight charged): interpreter.cpp:367-368: an empty signature against a 32-byte x-only key fails the check and continues without Schnorr verification or weight charge. Requires the tapscript checksig and validation-weight state, both outside the dispatch seam. |
| SCR-164 | tapscript | SCR-164 (tapleaf hash, key_version=0, codeseparator_pos): interpreter.cpp:1570-1576 appends tapleaf_hash, key_version=0 and codeseparator_pos to the BIP341 preimage. Requires the sighash serializer and execdata state; outside the seam. |
| SCR-166 | tapscript | SCR-166 (in_pos ≥ vout.size ⇒ construction fails ⇒ SCHNORR_SIG_HASHTYPE): interpreter.cpp:1559-1560: in_pos >= vout.size() makes preimage construction fail and maps to SCHNORR_SIG_HASHTYPE. Requires the tx output vector and sighash constructor; outside the seam. |
| SCR-167 | tapscript | SCR-167 (Executed OP_CODESEPARATOR records the 0-based opcode index (opcode_pos) in m_codeseparator_pos; the field is initialized to 0xFFFFFFFF (interpreter.cpp:445,1065): interpreter.cpp:1065,444-445 records the 0-based opcode index of each executed OP_CODESEPARATOR, initialized 0xFFFFFFFF. The update is in the EvalScript loop and depends on parsed-but-unexecuted opcodes and multi-byte push counting; the leaf seam has no opcode walk. |
| SCR-169 | tapscript | SCR-169 (epoch 0; spend_type; annex hash): interpreter.cpp:1492-1580 constructs the full tapscript sighash preimage and hashes it. Requires tx serialization, SHA256 and annex/ tapleaf execdata; outside the seam. |
| SCR-183 | tapscript-reimport | SCR-183 (for SigVersion::TAPSCRIPT minimal-IF and clean-stack are consensus requirements regardless of the policy flags): interpreter.cpp:623-629 re-imports tapscript MINIMALIF and interpreter.cpp:1876-1878 enforces implicit cleanstack. The MINIMALIF half is a bounded stepBody leaf and could be split out later; the cleanstack half depends on the full ExecuteWitnessScript post-state, so the row as stated is a seam. |

## Filed gaps

| SCR | family | disposition |
|---|---|---|
| SCR-001 | exec-verify | SCR-001 (Sequential evaluation, not concatenation): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-002 | exec-verify | SCR-002 (After scriptPubKey eval, stack non-empty and top CastToBool-true): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-003 | exec-verify | SCR-003 (Empty/short script evaluates to success with unchanged stack): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-004 | exec-verify | SCR-004 (with the WITNESS flag off, a scriptSig leaving one truthy element validates against an empty scriptPubKey; with WITNESS on a non-empty witness still fails WITNE): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-005 | exec-verify | SCR-005 (23-byte HASH160 script: re-eval last scriptSig stack element as subscript): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-006 | exec-verify | SCR-006 (scriptSig must be push-only for P2SH evaluation): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-007 | exec-verify | SCR-007 (stackCopy (taken after scriptSig) is restored for subscript eval): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-008 | exec-verify | SCR-008 (Exactly 1 element after all evaluation (flag; pol.; implicit in witness)): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-009 | exec-verify | SCR-009 (Flag combination constraint): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-010 | exec-verify | SCR-010 (scriptSig push-only before eval (pol.)): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-011 | exec-verify | SCR-011 (scriptSig == ∅ for bare witness programs): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-012 | exec-verify | SCR-012 (scriptSig == single push of redeemScript): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-013 | exec-verify | SCR-013 (Non-null witness without witness program fails): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-014 | exec-verify | SCR-014 (Flag-combination constraint): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-015 | exec-verify | SCR-015 (Away from named hash exceptions, P2SH/WITNESS/TAPROOT are enabled; DERSIG/CLTV/CSV/NULLDUMMY are added at buried heights. Scripts and costs use actual candidate): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-016 | exec-verify | SCR-016 (Two named mainnet blocks get reduced flag sets): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-017 | exec-verify | SCR-017 (Any EvalScript/VerifyWitnessProgram failure ⇒ input invalid): whole VerifyScript/EvalScript path is the E5 scoped residual (findings/e5/E5-RESIDUAL.md); no bounded cell exercises this row. No green is claimed. |
| SCR-021 | limits | auto(cells): partial row coverage; limits/C-L-witness-push-size: partial — the cell proves the witness item-size predicate `any (item.size() > 520) ⇒ PUSH_SIZE` (represented exactly by max_item > 520) for base/v0 and for tapscript without OP_SUCCESSx, its ordering after the SCR-031 initial-stack guard, and the BIP342 exemption ordering (a tapscript with OP_SUCCESSx returns success before the item loop).  The OP_SUCCESSx scan itself is an abstract boolean: deciding `opSuccessScan exec` over symbolic script bytes needs the per-opcode decode loop and early success, which is SCR-153 and is not modelled here. So the row's "containing OP_SUCCESSx" branch is only modelled at its outcome, not by scanning bytes.  EvalScript is also a stub, but the row ends before it. |
| SCR-026 | limits | SCR-026 (CMS key count ∈ [0,20] ⇒ PUBKEY_COUNT): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-027 | limits | SCR-027 (nSigsCount ∈ [0, nKeysCount] ⇒ SIG_COUNT): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-028 | limits | SCR-028 (nOpCount += nKeysCount; ≤201): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-032 | limits | SCR-032 (CHECKSIG=1; CHECKMULTISIG=20 (inaccurate)): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-033 | limits | SCR-033 (accurate CHECKMULTISIG counts the immediately preceding OP_1..OP_16 value, else 20, at each site): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-034 | limits | SCR-034 (malformed or non-push-only scriptSig returns zero; otherwise count the final push data's valid script prefix accurately): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-035 | limits | SCR-035 (v0-20=1; v0-32=accurate(witness script); v1+=0): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-036 | limits | SCR-036 (push-only scriptSig; last element as program): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-037 | limits | SCR-037 (cost in weight units): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-038 | limits | SCR-038 (cumulative block sigop cost <= MAX_BLOCK_SIGOPS_COST (80,000)): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-039 | limits | SCR-039 (mempool policy per-tx limit): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-040 | limits | SCR-040 (budget = serialized witness stack size (including the CompactSize item count) + 50 WU): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-041 | limits | SCR-041 (decrement on non-empty sig regardless of validity; <0 ⇒ TAPSCRIPT_VALIDATION_WEIGHT): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
| SCR-042 | limits | SCR-042 (non-empty sig + upgradable key still decrements): no bounded limit cell covers this row; the E2 limit attempt does not exercise this boundary/placement. No green is claimed. |
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
| SCR-056 | control-flow | SCR-056 (CastToBool of top (NOTIF inverts); pop): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-057 | control-flow | SCR-057 (any nonzero byte = true; lone 0x80 = false; ∅ = false): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-058 | control-flow | SCR-058 (IF/NOTIF arg ∈ {∅, 01} else TAPSCRIPT_MINIMALIF): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-059 | control-flow | SCR-059 (same check under flag): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-060 | control-flow | SCR-060 (no stack pop when skipped): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-061 | control-flow | SCR-061 (toggle_top; empty cond-stack ⇒ UNBALANCED_CONDITIONAL): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-062 | control-flow | SCR-062 (empty cond-stack ⇒ UNBALANCED_CONDITIONAL): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-063 | control-flow | SCR-063 (non-empty cond-stack after loop ⇒ fail): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-064 | control-flow | SCR-064 (in [OP_IF..OP_ENDIF] gate): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-065 | control-flow | SCR-065 (BAD_OPCODE even in unexecuted branches): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-066 | control-flow | SCR-066 (BAD_OPCODE when executed; unexecuted OP_VER passes): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-067 | control-flow | SCR-067 (each IF counts 1 opcode): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-068 | control-flow | auto(cells): partial row coverage; stack/C-L-verify: partial — closed branches only: true (pop), false (VERIFY), and empty-stack (INVALID_STACK_OPERATION); no symbolic truth values, no flags, no scriptSig. |
| SCR-070 | control-flow | SCR-070 (first-byte OP_RETURN or >10k script ⇒ never spendable): E2 control cell covers SCR-069/071/072 only; this row's branch, signature version, or policy flag is not modeled. No green is claimed. |
| SCR-073 | stack-ops | auto(cells): partial row coverage; e1-altstack/roundtrip: partial success branch only: TOALTSTACK/FROMALTSTACK roundtrip with budget available and nonempty stacks; empty-main/empty-alt failures and the OP_COUNT edge of SCR-073 are not exercised.; stack/C-L-altstack: partial — closed branches only: empty-alt FROMALTSTACK, empty-main TOALTSTACK, and a success roundtrip; no opcode-budget/OP_COUNT edge, no symbolic stacks. |
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
| SCR-093 | hash-ops | auto(cells): partial row coverage; e2-hash/hash160-vector: partial — one concrete HASH160 witness establishes the 20-byte output width (SCR-093's HASH160 arm) and the RIPEMD160(SHA256(x)) composition seam (SCR-094) for that preimage. The SHA256/HASH256/RIPEMD160 output widths, the empty-element row SCR-095, and the hash functions themselves are not proved: the transform is an opaque external on both legs and the SAW override supplies the concrete digest. |
| SCR-094 | hash-ops | auto(cells): partial row coverage; e2-hash/hash160-vector: partial — one concrete HASH160 witness establishes the 20-byte output width (SCR-093's HASH160 arm) and the RIPEMD160(SHA256(x)) composition seam (SCR-094) for that preimage. The SHA256/HASH256/RIPEMD160 output widths, the empty-element row SCR-095, and the hash functions themselves are not proved: the transform is an opaque external on both legs and the SAW override supplies the concrete digest. |
| SCR-095 | hash-ops | SCR-095 (works (∅ hashes fine)): E2 hash attempt treats the hash primitive as an opaque shared external; same-hash is a premise, not an IR proof, and this row's composition is not a green cell. No green is claimed. |
| SCR-096 | checksig | SCR-096 (pbegincodehash .. end): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-097 | checksig | SCR-097 (only executed CODESEPARATOR updates): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-098 | checksig | SCR-098 (byte-level removal of each matched serialized sig push from scriptCode, continuing after the match): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-099 | checksig | SCR-099 (found>0 ⇒ SIG_FINDANDDELETE (pol.)): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-100 | checksig | SCR-100 (BASE, even unexecuted (pol.)): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-101 | checksig | SCR-101 (1-byte opcodes removed from serialization): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-102 | checksig | SCR-102 (9..73 bytes; strict DER structure; consensus since BIP66): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-103 | checksig | SCR-103 (applied from BIP66 height 363725): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-104 | checksig | SCR-104 (S ≤ order/2 under LOW_S (pol.)): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-105 | checksig | SCR-105 (last byte & ~0x80 ∈ {1,2,3} (pol.)): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-106 | checksig | SCR-106 (33B 02/03 or 65B 04 (pol.)): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-107 | checksig | SCR-107 (v0 witness pubkeys compressed (pol.)): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-108 | checksig | SCR-108 (∅ sig bypasses DER checks): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-109 | checksig | auto(cells): partial row coverage; checksig/C-L-checksig-empty: partial — only the empty-signature push-false arm and the CHECKSIGVERIFY error ordinal 14 are modeled. The checker is a shared model returning false for the empty signature, not a proof of Core/libsecp or rbitcoin crypto. DER (SCR-102/103), LOW_S (SCR-104), STRICTENC (SCR-105/106), WITNESS_PUBKEYTYPE (SCR-107), NULLFAIL (SCR-110), sighash (SCR-111), pubkey-failure continuation (SCR-112) and CHECKMULTISIG (SCR-114..121) are not covered; their rows remain gaps/seams. |
| SCR-110 | checksig | SCR-110 (failed check w/ non-empty sig ⇒ SIG_NULLFAIL (pol.)): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-111 | checksig | SCR-111 (ANYONECANPAY bit passed through): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-112 | checksig | auto(cells): partial row coverage; e3-checksig/C-L-checksig-dispatch: partial |
| SCR-113 | checksig | SCR-113 (each executed op counts 1 toward 201): E3 checksig attempt is conditional on the same abstract crypto checker; R has no typed ScriptError and a single-input/flags=0 domain (F-HARNESS-002/R-GAP-01), and this row has no C/L cell. No green is claimed. |
| SCR-114 | checkmultisig | auto(cells): partial row coverage; e3-cms/C-L-cms-1of1: partial |
| SCR-115 | checkmultisig | SCR-115 (all nSigsCount sigs FindAndDelete'd before any check (BASE)): E3 CMS attempt did not cover this row; R is domain-limited (F-HARNESS-002), and the CMS loop/error-enum equality is not a green cell. No green is claimed. |
| SCR-116 | checkmultisig | SCR-116 (sigs to keys in order; early fail when sigs>keys remain): E3 CMS attempt did not cover this row; R is domain-limited (F-HARNESS-002), and the CMS loop/error-enum equality is not a green cell. No green is claimed. |
| SCR-117 | checkmultisig | SCR-117 (CheckSignatureEncoding+CheckPubKeyEncoding inside loop): E3 CMS attempt did not cover this row; R is domain-limited (F-HARNESS-002), and the CMS loop/error-enum equality is not a green cell. No green is claimed. |
| SCR-118 | checkmultisig | auto(cells): partial row coverage; e3-cms/C-L-cms-1of1: partial |
| SCR-119 | checkmultisig | auto(cells): partial row coverage; e3-cms/C-L-cms-1of1: partial |
| SCR-120 | checkmultisig | auto(cells): partial row coverage; e3-cms/C-L-cms-1of1: partial |
| SCR-121 | checkmultisig | SCR-121 (TAPSCRIPT_CHECKMULTISIG): E3 CMS attempt did not cover this row; R is domain-limited (F-HARNESS-002), and the CMS loop/error-enum equality is not a green cell. No green is claimed. |
| SCR-122 | locktime | SCR-122 (negative ⇒ NEGATIVE_LOCKTIME): no locktime cell was built; CLTV/CSV need the transaction context and the E2/E4 harness does not model it. No green is claimed. |
| SCR-123 | locktime | SCR-123 (both sides < or ≥ 500000000 (script.h:48)): no locktime cell was built; CLTV/CSV need the transaction context and the E2/E4 harness does not model it. No green is claimed. |
| SCR-124 | locktime | SCR-124 (operand ≤ tx nLockTime): no locktime cell was built; CLTV/CSV need the transaction context and the E2/E4 harness does not model it. No green is claimed. |
| SCR-125 | locktime | SCR-125 (vin[nIn].nSequence ≠ 0xffffffff): no locktime cell was built; CLTV/CSV need the transaction context and the E2/E4 harness does not model it. No green is claimed. |
| SCR-126 | locktime | SCR-126 (negative ⇒ NEGATIVE_LOCKTIME): no locktime cell was built; CLTV/CSV need the transaction context and the E2/E4 harness does not model it. No green is claimed. |
| SCR-127 | locktime | SCR-127 (operand bit 31 ⇒ NOP): no locktime cell was built; CLTV/CSV need the transaction context and the E2/E4 harness does not model it. No green is claimed. |
| SCR-128 | locktime | SCR-128 (else fail): no locktime cell was built; CLTV/CSV need the transaction context and the E2/E4 harness does not model it. No green is claimed. |
| SCR-129 | locktime | SCR-129 (else fail): no locktime cell was built; CLTV/CSV need the transaction context and the E2/E4 harness does not model it. No green is claimed. |
| SCR-130 | locktime | SCR-130 (mask 0x0040ffff): no locktime cell was built; CLTV/CSV need the transaction context and the E2/E4 harness does not model it. No green is claimed. |
| SCR-131 | locktime | SCR-131 (CSV script-level compares raw masked values; granularity in SequenceLocks): no locktime cell was built; CLTV/CSV need the transaction context and the E2/E4 harness does not model it. No green is claimed. |
| SCR-132 | locktime | SCR-132 (CheckLockTime/Sequence see only input nIn): no locktime cell was built; CLTV/CSV need the transaction context and the E2/E4 harness does not model it. No green is claimed. |
| SCR-134 | witness-v0 | auto(cells): partial row coverage; e4-witness/C-L-witness-v0-dispatch: partial (dispatch predicate only), per row:
- SCR-134 "empty => WITNESS_PROGRAM_WITNESS_EMPTY": full for the empty
  predicate on the 32-byte program; the non-empty arm's success is the
  declared hash/ExecuteWitnessScript abstraction.
- SCR-135 "else WITNESS_PROGRAM_MISMATCH" (P2WPKH exactly 2 items): full for
  the arity predicate on the 20-byte program; the 2-item arm's success is
  the declared implied-script/ExecuteWitnessScript abstraction.
- SCR-137 "else WRONG_LENGTH" (v0 length 20 or 32 only): full; the function
  is total over all other lengths.
NOT claimed here: SCR-133 (SHA256 program match), SCR-136 (P2WPKH script
reconstruction/execution), SCR-138 (witness cleanstack), and every
taproot/tapscript row. Those remain seams, listed in findings/e4/seams.md. |
| SCR-135 | witness-v0 | auto(cells): partial row coverage; e4-witness/C-L-witness-v0-dispatch: partial (dispatch predicate only), per row:
- SCR-134 "empty => WITNESS_PROGRAM_WITNESS_EMPTY": full for the empty
  predicate on the 32-byte program; the non-empty arm's success is the
  declared hash/ExecuteWitnessScript abstraction.
- SCR-135 "else WITNESS_PROGRAM_MISMATCH" (P2WPKH exactly 2 items): full for
  the arity predicate on the 20-byte program; the 2-item arm's success is
  the declared implied-script/ExecuteWitnessScript abstraction.
- SCR-137 "else WRONG_LENGTH" (v0 length 20 or 32 only): full; the function
  is total over all other lengths.
NOT claimed here: SCR-133 (SHA256 program match), SCR-136 (P2WPKH script
reconstruction/execution), SCR-138 (witness cleanstack), and every
taproot/tapscript row. Those remain seams, listed in findings/e4/seams.md. |
| SCR-137 | witness-v0 | auto(cells): partial row coverage; e4-witness/C-L-witness-v0-dispatch: partial (dispatch predicate only), per row:
- SCR-134 "empty => WITNESS_PROGRAM_WITNESS_EMPTY": full for the empty
  predicate on the 32-byte program; the non-empty arm's success is the
  declared hash/ExecuteWitnessScript abstraction.
- SCR-135 "else WITNESS_PROGRAM_MISMATCH" (P2WPKH exactly 2 items): full for
  the arity predicate on the 20-byte program; the 2-item arm's success is
  the declared implied-script/ExecuteWitnessScript abstraction.
- SCR-137 "else WRONG_LENGTH" (v0 length 20 or 32 only): full; the function
  is total over all other lengths.
NOT claimed here: SCR-133 (SHA256 program match), SCR-136 (P2WPKH script
reconstruction/execution), SCR-138 (witness cleanstack), and every
taproot/tapscript row. Those remain seams, listed in findings/e4/seams.md. |
| SCR-139 | witness-v0 | SCR-139 (sigversion≠BASE skips deletion): Branch predicate in EvalChecksigPreTapscript: sigversion != BASE skips FindAndDelete on the scriptCode (interpreter.cpp:333-343). Expressible as a bounded EvalChecksig leaf with an abstract signature checker; not attempted. Next action: two-scriptCode leaf. |
| SCR-142 | tapscript | auto(cells): partial row coverage; tapscript/C-L-taproot-gate: partial. The in-function gate is proved total: flag off -> success with no
witness inspection; flag on -> empty witness fails 39, non-empty continues
into the annex/key/script dispatch. The row also names activation height
709632 and exception block 692261. Those are caller-side flag assembly
outside VerifyWitnessProgram and have no block-height channel in
contract/tape.md, so that arm is not exercised here. |
| SCR-155 | tapscript | SCR-155 (the MAX_OPS budget is not consulted on the tapscript path: an already-over-budget tapscript OP_NOP still succeeds and leaves opCount untouched; on BASE/WITNESS_): interpreter.cpp:460-464 is the MAX_OPS guard, skipped for TAPSCRIPT. A bounded stepBody leaf can set opCount>201 and run OP_NOP in BASE/WITNESS_V0 and TAPSCRIPT; the twin has stepBody handlers. Not attempted. (This is the op-count budget, not sigops.) |
| SCR-157 | tapscript | SCR-157 (CScriptNum(fRequireMinimal)): interpreter.cpp:1103 parses the numeric operand with CScriptNum(fRequireMinimal). A bounded ScriptNum leaf can judge the minimal-4-byte rule; not attempted. |
| SCR-158 | tapscript | SCR-158 (0 ⇒ fail; 32 ⇒ schnorr; else upgradable): interpreter.cpp:377-392 triages pubkey size: 0 fails, 32 enters the Schnorr lane, other non-empty sizes are upgradable. The size triage is a pure bounded predicate, judgeable with Schnorr success abstracted; not attempted. |
| SCR-159 | tapscript | SCR-159 (TAPSCRIPT_EMPTY_PUBKEY: a zero-length (empty) tapscript pubkey fails immediately after the validation-weight decrement): interpreter.cpp:377-378 fails TAPSCRIPT_EMPTY_PUBKEY immediately after the validation-weight decrement. The pubkey-length predicate is judgeable as a bounded leaf; the weight decrement is a separate state step. Not attempted. |
| SCR-161 | tapscript | SCR-161 (else SCHNORR_SIG_SIZE): interpreter.cpp:1736: Schnorr signatures are 64 or 65 bytes. Pure length predicate, judgeable as a bounded leaf; not attempted. |
| SCR-162 | tapscript | SCR-162 (SIGHASH_DEFAULT invalid as explicit byte): interpreter.cpp:1741-1744: a 65-byte signature with explicit hashtype 0x00 fails (SIGHASH_DEFAULT is implicit only). Pure byte predicate; judgeable, not attempted. |
| SCR-163 | tapscript | SCR-163 (≤0x03 or 0x81..0x83 else fail): interpreter.cpp:1526: valid BIP341 hashtypes are <=0x03 or 0x81..0x83. Pure byte-set predicate; judgeable as a table leaf, not attempted. |
| SCR-165 | tapscript | SCR-165 (only for 64-byte key-path sigs): interpreter.cpp:1524,1740: a 64-byte key-path signature means SIGHASH_DEFAULT and is treated as ALL without an explicit byte. Pure length/hashtype normalization; judgeable, not attempted. The surrounding preimage/hash is SCR-169. |
| SCR-168 | tapscript | SCR-168 (budget may reach exactly 0): interpreter.cpp:373-375 checks validation_weight_left < 0 (not <=0), so a budget of exactly zero succeeds. Pure integer predicate over checksig step inputs; judgeable, not attempted. |
| SCR-170 | disabled-opcodes | SCR-170 (CAT,SUBSTR,LEFT,RIGHT,INVERT,AND,OR,XOR,2MUL,2DIV,MUL,DIV,MOD,LSHIFT,RSHIFT ⇒ DISABLED_OPCODE in base/witness-v0, even unexecuted, unless the 201-op budget is a): no disabled-opcode cell was built; the twin does not expose this opcode and the base/tapscript split is not modeled. No green is claimed. |
| SCR-171 | disabled-opcodes | SCR-171 (after op-count, before fExec): no disabled-opcode cell was built; the twin does not expose this opcode and the base/tapscript split is not modeled. No green is claimed. |
| SCR-172 | disabled-opcodes | SCR-172 (same bytes become success in tapscript): script.cpp:365-371 maps the disabled-opcode bytes to OP_SUCCESS126..153 under tapscript. The wire mapping is a pure table and is judgeable; the 'success' outcome depends on the OP_SUCCESS pre-scan seam (SCR-153). Not attempted. Included because the row is tapscript-facing; SCR-170/171 are base/witness-v0 and out of this inventory. |
| SCR-173 | disabled-opcodes | SCR-173 (name table; unknown ⇒ "OP_UNKNOWN"): no disabled-opcode cell was built; the twin does not expose this opcode and the base/tapscript split is not modeled. No green is claimed. |
| SCR-174 | disabled-opcodes | SCR-174 (default case BAD_OPCODE): no disabled-opcode cell was built; the twin does not expose this opcode and the base/tapscript split is not modeled. No green is claimed. |
| SCR-175 | policy-flags | SCR-175 (SCRIPT_VERIFY_LOW_S is mempool policy, never in GetBlockScriptFlags): flags are fixed at 0 in the bounded harness; this policy-flag row is not exercised. No green is claimed. |
| SCR-176 | policy-flags | SCR-176 (SCRIPT_VERIFY_STRICTENC is policy (hybrid/hybrid pubkey rejection)): flags are fixed at 0 in the bounded harness; this policy-flag row is not exercised. No green is claimed. |
| SCR-177 | policy-flags | SCR-177 (SCRIPT_VERIFY_MINIMALDATA is policy (push minimality)): flags are fixed at 0 in the bounded harness; this policy-flag row is not exercised. No green is claimed. |
| SCR-178 | policy-flags | SCR-178 (SCRIPT_VERIFY_MINIMALIF applies to v0 witness spends only; tapscript re-imports it (SCR-183)): flags are fixed at 0 in the bounded harness; this policy-flag row is not exercised. No green is claimed. |
| SCR-179 | policy-flags | SCR-179 (SCRIPT_VERIFY_NULLFAIL is policy (empty sig must fail check)): flags are fixed at 0 in the bounded harness; this policy-flag row is not exercised. No green is claimed. |
| SCR-180 | policy-flags | SCR-180 (SCRIPT_VERIFY_CLEANSTACK is a policy flag for base (non-witness) spends; witness-v0 and tapscript clean-stack are enforced implicitly as consensus regardless of): flags are fixed at 0 in the bounded harness; this policy-flag row is not exercised. No green is claimed. |
| SCR-181 | policy-flags | SCR-181 (SCRIPT_VERIFY_CONST_SCRIPTCODE is policy (no OP_CODESEPARATOR evolution)): flags are fixed at 0 in the bounded harness; this policy-flag row is not exercised. No green is claimed. |
| SCR-182 | policy-flags | SCR-182 (SCRIPT_VERIFY_WITNESS_PUBKEYTYPE is policy (compressed keys)): flags are fixed at 0 in the bounded harness; this policy-flag row is not exercised. No green is claimed. |
