# E4 seam inventory — witness-v0, tapscript, taproot

Pin `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`; contract
`f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`.
Source of truth for rows: `spec/db/rules.yaml`; ledger target:
`spec/db/equiv-cells.yaml` (183 SCR rows).

This file is the E4-DISPATCH handoff for the orchestrator. It does **not**
edit the ledger. The YAML block is the machine-readable filing input.

## Seam definition

The E4 harness seam is the bounded leaf: one C source-excerpt slice at the pin
versus one L handler (copied from `twin/ops_ir.py`) or one reviewed L
transliteration, compiled to loop-free LLVM 20 IR, then checked by Alive2 v20
and SAW 1.6 against a shared contract. It has no `EvalScript` loop, no
`ExecuteWitnessScript`, no transaction decoder, no block height/activation
context, no SHA256/SHA160/Schnorr/EC model, and no sigops or witness-weight
accounting.

Three dispositions are used:

- **unjudged-seam** — the row's claim inherently needs a model or context the
  seam deliberately does not provide (hash/EC, full dispatch, annex/control
  block, OP_SUCCESS pre-scan, EvalScript/cleanstack loop, activation height,
  sighash serialization, sigops/weight). Filed as `unjudged-seam`.
- **gap** — the row is a pure predicate that a bounded leaf *can* express, but
  no cell exists yet. Filed as `gap` with a concrete next action; it must not
  be presented as a seam.
- **judged** — a delivered cell covers the row at this seam. Filed green by
  the orchestrator after review.

`SCR-134`, `SCR-135`, and `SCR-137` are **tool-green but coverage-partial**:
`cells/e4-witness/C-L-witness-v0-dispatch` proves the length/arity error
predicates, while the success arms depend on abstracted SHA256 and
`ExecuteWitnessScript`. The ledger therefore keeps them **gap**, not green;
they are listed only so the partial cell is visible.

`SWT-001..016` are **not** SCR rows in `equiv-cells.yaml` (the ledger contract
says exactly one entry per SCR-* row). They are intentionally absent from the
YAML block; they need their own ledger decision, not an E4 status.

Filing citations: crypto/hash/EC seams are conditional on
`docs/DECISION-lax-ecdsa.md`; full-dispatch/loop seams cite `E4:F-TOOL-001`
(`findings/e4/F-TOOL-001.md`) and the recorded
`cells/_tools/gate/whole_entry_alive2_probe.txt`. The whole-entry probe was
**not** re-run by E4-DISPATCH; no tool result is claimed beyond the two cell
runs.

## Machine-readable inventory

```yaml
seam_inventory:
  pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
  repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
  contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
  harness_cell: e4-witness/C-L-witness-v0-dispatch
  filing_citations:
    crypto_and_ec: docs/DECISION-lax-ecdsa.md
    full_engine_tool_gap: E4:F-TOOL-001
    recorded_probe: cells/_tools/gate/whole_entry_alive2_probe.txt
    tool_limits: findings/verifications/artifacts/tool-limits/README.md
    note: >-
      Crypto/hash/EC seam rows are conditional on the same-crypto boundary in
      docs/DECISION-lax-ecdsa.md. Full-dispatch/loop rows cite E4:F-TOOL-001
      and the recorded whole-entry probe; E4-DISPATCH did not re-run the
      whole-entry probe. No other finding id is invented.
  note: status values below are the proposed ledger filing; the orchestrator owns the ledger write. Every unjudged-seam/gap note names the blocking seam.
  judged:
  - id: SCR-134
    family: witness-v0
    status: gap
    cell: e4-witness/C-L-witness-v0-dispatch
    note: 'TOOL-GREEN BUT ROW-PARTIAL (ledger gap): P2WSH empty-witness predicate: program_len=32 and witness_n=0 returns error 39 (WITNESS_PROGRAM_WITNESS_EMPTY). Alive2 and SAW both green. Non-empty success is conditional on the declared hash/ExecuteWitnessScript abstraction and is not part of this row.'
  - id: SCR-135
    family: witness-v0
    status: gap
    cell: e4-witness/C-L-witness-v0-dispatch
    note: 'TOOL-GREEN BUT ROW-PARTIAL (ledger gap): P2WPKH arity predicate: program_len=20 and witness_n!=2 returns error 40 (WITNESS_PROGRAM_MISMATCH). Alive2 and SAW both green. The 2-item arm''s implied-script success is abstracted.'
  - id: SCR-137
    family: witness-v0
    status: gap
    cell: e4-witness/C-L-witness-v0-dispatch
    note: 'TOOL-GREEN BUT ROW-PARTIAL (ledger gap): v0 wrong-length predicate: every program_len not in {20,32} returns error 38 (WITNESS_PROGRAM_WRONG_LENGTH), total over all 64-bit lengths. Alive2 and SAW both green.'
  unjudged_seam:
  - id: SCR-133
    family: witness-v0
    status: unjudged-seam
    seam: crypto/hash — SHA256(witnessScript) byte comparison
    note: interpreter.cpp:1939-1945 computes a single SHA256 over the popped witnessScript and memcmp's 32 bytes against the program. No SHA256 model exists at the leaf seam; abstracting the equality boolean would prove only the surrounding branch, not the row's hash claim.
  - id: SCR-136
    family: witness-v0
    seam: script-path EvalScript loop + HASH160/CHECKSIG crypto
    status: unjudged-seam
    note: interpreter.cpp:1952-1953 reconstructs OP_DUP OP_HASH160 <program> OP_EQUALVERIFY OP_CHECKSIG and runs it through ExecuteWitnessScript. Requires the EvalScript loop, push parsing, HASH160 and ECDSA/CHECKSIG; the cell seam has none of them.
  - id: SCR-138
    family: witness-v0
    seam: full ExecuteWitnessScript post-state / implicit cleanstack
    status: unjudged-seam
    note: 'interpreter.cpp:1876-1879 checks the stack after EvalScript returns: exactly one item and CastToBool true. This is an EvalScript post-state property; the leaf dispatch cell never runs the interpreter and cannot observe the final stack.'
  - id: SCR-140
    family: witness-v0
    seam: BIP143 sighash serialization + double SHA256
    status: unjudged-seam
    note: interpreter.cpp:1633-1670 builds the BIP143 preimage (field order, amount, prevouts, outputs, hashOutputs) and hashes it. Requires the tx serializer and hash model; no tx decoder is in the seam.
  - id: SCR-141
    family: witness-v0
    seam: BIP143 SINGLE overflow / tx output vector + hash
    status: unjudged-seam
    note: interpreter.cpp:1647-1653 selects a zero hashOutputs when the SINGLE input index is out of range. The branch is pure, but it is defined over the serialized output vector and feeds the sighash preimage; the tape decoder and hash are outside the seam.
  - id: SCR-142
    family: tapscript
    seam: full VerifyWitnessProgram taproot gate + block activation context
    status: unjudged-seam
    note: interpreter.cpp:1959 gates the v1-32 non-P2SH arm on SCRIPT_VERIFY_TAPROOT and is silent-success without the flag. The row also carries pre-activation height 709632 and exception block 692261; the contract tape has no height/block context, so the activation arm cannot be judged here.
  - id: SCR-143
    family: tapscript
    seam: control-block/annex handling over the witness stack
    status: unjudged-seam
    note: interpreter.cpp:1961-1969 detects an annex as >=2 items, last item non-empty and first byte 0x50, then SpanPopBack's it. Requires witness stack item bytes and ordering; the dispatch cell only sees an item count. Annex hashing also feeds the sighash.
  - id: SCR-144
    family: tapscript
    seam: BIP340 Schnorr + taproot output-key binding
    status: unjudged-seam
    note: interpreter.cpp:1970-1975, one post-annex item is a Schnorr signature checked against the 32-byte program key. This is the EC/Schnorr crypto seam; no checker exists in the leaf harness.
  - id: SCR-146
    family: tapscript
    seam: BIP341 tagged hash (TapLeaf)
    status: unjudged-seam
    note: interpreter.cpp:1882-1885 computes TaggedHash("TapLeaf", leaf_version, CompactSize(script), script). Requires SHA256 and the BIP340 tagged-hash construction; outside the seam.
  - id: SCR-147
    family: tapscript
    seam: EC point tweak / x-only key + parity
    status: unjudged-seam
    note: interpreter.cpp:1913-1925 checks program == x(tweak(p, merkle_root)) and control[0]&1 == tweaked-key parity. Pure secp256k1 EC; outside the seam.
  - id: SCR-153
    family: tapscript
    seam: OP_SUCCESS pre-scan / immediate success over the script bytes
    status: unjudged-seam
    note: interpreter.cpp:1846-1862 scans the whole tapscript for OP_SUCCESSx before item-size and EvalScript, and returns success immediately. Needs a loop over symbolic script bytes and early-success control flow; the leaf harness is loop-free and does not parse scripts.
  - id: SCR-154
    family: tapscript
    seam: OP_SUCCESS pre-scan + policy flag
    status: unjudged-seam
    note: interpreter.cpp:1857-1859 fails with DISCOURAGE_OP_SUCCESS during the same pre-scan. Same loop/early-success seam as SCR-153; additionally a policy-flag branch. Consensus=false.
  - id: SCR-156
    family: tapscript
    seam: CHECKSIGADD Schnorr lane + stepBody
    status: unjudged-seam
    note: interpreter.cpp:1094-1113 pops (sig,num,pk), adds the signature check result, and rejects outside tapscript. The stack effect is leaf-shaped but the signature check is the Schnorr/EC seam; no checker.
  - id: SCR-160
    family: tapscript
    seam: Schnorr empty-sig path + validation weight accounting
    status: unjudged-seam
    note: 'interpreter.cpp:367-368: an empty signature against a 32-byte x-only key fails the check and continues without Schnorr verification or weight charge. Requires the tapscript checksig and validation-weight state, both outside the dispatch seam.'
  - id: SCR-164
    family: tapscript
    seam: tapscript sighash extension serialization
    status: unjudged-seam
    note: interpreter.cpp:1570-1576 appends tapleaf_hash, key_version=0 and codeseparator_pos to the BIP341 preimage. Requires the sighash serializer and execdata state; outside the seam.
  - id: SCR-166
    family: tapscript
    seam: SINGLE overflow fail-closed / tx output vector
    status: unjudged-seam
    note: 'interpreter.cpp:1559-1560: in_pos >= vout.size() makes preimage construction fail and maps to SCHNORR_SIG_HASHTYPE. Requires the tx output vector and sighash constructor; outside the seam.'
  - id: SCR-167
    family: tapscript
    seam: EvalScript loop bookkeeping / opcode position
    status: unjudged-seam
    note: interpreter.cpp:1065,444-445 records the 0-based opcode index of each executed OP_CODESEPARATOR, initialized 0xFFFFFFFF. The update is in the EvalScript loop and depends on parsed-but-unexecuted opcodes and multi-byte push counting; the leaf seam has no opcode walk.
  - id: SCR-169
    family: tapscript
    seam: BIP341+342 sighash (epoch, spend_type, annex hash, extensions)
    status: unjudged-seam
    note: interpreter.cpp:1492-1580 constructs the full tapscript sighash preimage and hashes it. Requires tx serialization, SHA256 and annex/ tapleaf execdata; outside the seam.
  - id: SCR-183
    family: tapscript-reimport
    seam: MINIMALIF stepBody + ExecuteWitnessScript cleanstack post-state
    status: unjudged-seam
    note: interpreter.cpp:623-629 re-imports tapscript MINIMALIF and interpreter.cpp:1876-1878 enforces implicit cleanstack. The MINIMALIF half is a bounded stepBody leaf and could be split out later; the cleanstack half depends on the full ExecuteWitnessScript post-state, so the row as stated is a seam.
  gap:
  - id: SCR-139
    family: witness-v0
    status: gap
    note: 'Branch predicate in EvalChecksigPreTapscript: sigversion != BASE skips FindAndDelete on the scriptCode (interpreter.cpp:333-343). Expressible as a bounded EvalChecksig leaf with an abstract signature checker; not attempted. Next action: two-scriptCode leaf.'
  - id: SCR-145
    family: tapscript
    status: gap
    note: 'interpreter.cpp:1980-1982 rejects control.size() < 33, > 33+32*128, or (size-33)%32!=0 with TAPROOT_WRONG_CONTROL_SIZE. Pure u64 arithmetic; judgeable as a bounded leaf. Next action: control-size predicate cell.'
  - id: SCR-148
    family: tapscript
    status: gap
    note: interpreter.cpp:1988-1994 selects tapscript when (control[0]&0xfe)==0xc0. The 8-bit mask predicate is judgeable as a bounded leaf; tapscript execution is a separate seam (SCR-153/155). Not attempted.
  - id: SCR-149
    family: tapscript
    status: gap
    note: 'interpreter.cpp:1995-1998: an unknown leaf version succeeds when DISCOURAGE_UPGRADABLE_TAPROOT_VERSION is off. Pure mask+flag dispatch over an abstracted commitment; judgeable as a bounded leaf. Not attempted.'
  - id: SCR-150
    family: tapscript
    status: gap
    note: 'interpreter.cpp:2000-2001: v1 with a 2-byte program 0x4e73 (P2A) returns true with no execution. Pure version/size/bytes predicate; judgeable, not attempted.'
  - id: SCR-151
    family: tapscript
    status: gap
    note: 'interpreter.cpp:2002-2008: v2..v16, wrong-size v1, and P2SH-wrapped v1 succeed for future softfork compatibility. Pure version/size/P2SH dispatch; judgeable, not attempted.'
  - id: SCR-152
    family: tapscript
    status: gap
    note: script.cpp:IsOpSuccess:365-371 is a pure set-membership test over one byte. Judgeable as a bounded byte-table leaf; not attempted. Its execution consequence is SCR-153, which is a seam.
  - id: SCR-155
    family: tapscript
    status: gap
    note: interpreter.cpp:460-464 is the MAX_OPS guard, skipped for TAPSCRIPT. A bounded stepBody leaf can set opCount>201 and run OP_NOP in BASE/WITNESS_V0 and TAPSCRIPT; the twin has stepBody handlers. Not attempted. (This is the op-count budget, not sigops.)
  - id: SCR-157
    family: tapscript
    status: gap
    note: interpreter.cpp:1103 parses the numeric operand with CScriptNum(fRequireMinimal). A bounded ScriptNum leaf can judge the minimal-4-byte rule; not attempted.
  - id: SCR-158
    family: tapscript
    status: gap
    note: 'interpreter.cpp:377-392 triages pubkey size: 0 fails, 32 enters the Schnorr lane, other non-empty sizes are upgradable. The size triage is a pure bounded predicate, judgeable with Schnorr success abstracted; not attempted.'
  - id: SCR-159
    family: tapscript
    status: gap
    note: interpreter.cpp:377-378 fails TAPSCRIPT_EMPTY_PUBKEY immediately after the validation-weight decrement. The pubkey-length predicate is judgeable as a bounded leaf; the weight decrement is a separate state step. Not attempted.
  - id: SCR-161
    family: tapscript
    status: gap
    note: 'interpreter.cpp:1736: Schnorr signatures are 64 or 65 bytes. Pure length predicate, judgeable as a bounded leaf; not attempted.'
  - id: SCR-162
    family: tapscript
    status: gap
    note: 'interpreter.cpp:1741-1744: a 65-byte signature with explicit hashtype 0x00 fails (SIGHASH_DEFAULT is implicit only). Pure byte predicate; judgeable, not attempted.'
  - id: SCR-163
    family: tapscript
    status: gap
    note: 'interpreter.cpp:1526: valid BIP341 hashtypes are <=0x03 or 0x81..0x83. Pure byte-set predicate; judgeable as a table leaf, not attempted.'
  - id: SCR-165
    family: tapscript
    status: gap
    note: 'interpreter.cpp:1524,1740: a 64-byte key-path signature means SIGHASH_DEFAULT and is treated as ALL without an explicit byte. Pure length/hashtype normalization; judgeable, not attempted. The surrounding preimage/hash is SCR-169.'
  - id: SCR-168
    family: tapscript
    status: gap
    note: interpreter.cpp:373-375 checks validation_weight_left < 0 (not <=0), so a budget of exactly zero succeeds. Pure integer predicate over checksig step inputs; judgeable, not attempted.
  - id: SCR-172
    family: disabled-opcodes
    status: gap
    note: script.cpp:365-371 maps the disabled-opcode bytes to OP_SUCCESS126..153 under tapscript. The wire mapping is a pure table and is judgeable; the 'success' outcome depends on the OP_SUCCESS pre-scan seam (SCR-153). Not attempted. Included because the row is tapscript-facing; SCR-170/171 are base/witness-v0 and out of this inventory.
  out_of_inventory:
  - id: SCR-170
    family: disabled-opcodes
    note: base/witness-v0 disabled-opcode guard; E1/E2 stepBody venue, not a segwit dispatch row.
  - id: SCR-171
    family: disabled-opcodes
    note: disabled-before-fExec ordering; E1/E2 stepBody venue, not a segwit dispatch row.
  - id: SCR-173
    family: disabled-opcodes
    note: GetOpName table; unrelated to the witness/tapscript dispatch seam.
  - id: SCR-174
    family: disabled-opcodes
    note: OP_INVALIDOPCODE stepBody default; E1/E2 stepBody venue.
  - id: SCR-178
    family: policy-flags
    note: MINIMALIF v0-only policy row; cross-references SCR-183 but is a policy-flags row.
  - id: SCR-180
    family: policy-flags
    note: CLEANSTACK policy row; cross-references witness/tapscript cleanstack but is a policy-flags row.

```

## Why these are seams and not merely gaps

The seam rows share one or more of the following, all absent from the bounded
leaf harness:

1. **A hash or EC primitive.** SCR-133/140/141/144/146/147/160/164/166/169
   need SHA256, HASH160, BIP340 tagged hashing or secp256k1. There is no
   abstract-crypto checker in the Alive2/SAW cells; the global trust base does
   not include one.
2. **A whole-script loop.** SCR-136/138/153/154/156/183 need the EvalScript or
   ExecuteWitnessScript loop, including early success, stack post-state,
   cleanstack, or opcode-position bookkeeping. Alive2/SAW can ingest a
   loop-free leaf, not the engine loop.
3. **Witness-stack structure.** SCR-143 needs annex/control-block bytes,
   ordering, and hashing, not just `witness_n`.
4. **Block context.** SCR-142 needs activation height 709632 and the block
   692261 exception; the tape has no block-height channel.
5. **Sighash/tx context.** SCR-140/141/164/166/169 need the transaction
   serializer and output vector, which the leaf seam does not provide.

The gap rows are pure or bounded predicates (`u8` tables, `u64` arithmetic,
length/mask comparisons, one ScriptNum parse, one stepBody guard). A future
bounded cell can judge them without adding a crypto model, a loop, or a
decoder. Filing them as `unjudged-seam` would overstate the block and hide a
cheap next action.

## Suggested next actions (not performed)

- Build bounded cells for the 17 gap rows, starting with the highest-value
  dispatch predicates: SCR-145 (control size), SCR-148/149 (leaf version),
  SCR-150/151 (P2A/future versions), SCR-152/172 (OP_SUCCESS wire set), and
  SCR-161/162/163/165 (Schnorr hashtype/size).
- Keep SCR-134/135/137 green on
  `cells/e4-witness/C-L-witness-v0-dispatch`; add the P2SH-wrapped source
  selection as a sibling cell only if it stays inside the pure predicate
  (scriptSig item count/byte equality), otherwise file it as a seam.
- Do not file any SWT-* row from this document; they are not in the SCR
  ledger.
