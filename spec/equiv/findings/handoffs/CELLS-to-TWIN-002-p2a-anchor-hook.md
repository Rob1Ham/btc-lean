from: CELLS (wave64/61-p2a-l-link)
to: TWIN-IR (owner of twin/, Findings/twin) — with a LEDGER ask below
status: open
artifacts:
  - spec/equiv/findings/handoffs/CELLS-to-TWIN-002-p2a-anchor-hook.md (this file)
  - spec/equiv/findings/wave64/61-p2a-l-link/report.md (determination, evidence, hashes)
  - spec/equiv/findings/wave64/61-p2a-l-link/p2a_link_probe.py (contract-entry tape table)
  - spec/equiv/findings/wave64/61-p2a-l-link/p2a_link_probe.lean (Lean-side #eval)
ask: >
  Apply the 48-line `runtime.inc` hook below, re-render `build/twin.cpp`
  (`gen.py --check` must stay clean), then run the acceptance commands.  That
  replaces SCR-055's reviewed-transcription L leg with a generated-twin L leg
  and closes the P2A branch binding for native and P2SH-wrapped spends.
blockers: >
  none technical — the hook is built and proved in a scratch tree (Alive2
  bidirectional green, SAW 4/4, twin smoke 147/147, contract-entry table 10/10).
  It cannot land from the CELLS scope because `twin/runtime.inc` is content-
  addressed by 21 cells / 42 certificates and `make gate-ir-pin` replays every
  certificate; the change is therefore a repo-wide re-certification event, not
  a per-cell edit.  A sibling wave-64 task (62-sha1-twin) edits the same twin
  files, so two concurrent writers would also collide.
evidence: >
  scratch /tmp/opencode/61-p2a-probe at the base pin; patched runtime.inc
  sha256 7c8824e4…, rendered twin.cpp sha256 df78b78e… (79990 bytes), patch file
  sha256 5dd8bff9… (a/b headers); logs quoted in report.md.

# Hook: SCR-055 P2A anchor in the twin

## Why it is needed

`cells/push-encoding/C-L-w32-p2a-anchor` (SCR-055) proves the four-conjunct
predicate `version = 1 ∧ plen = 2 ∧ p0 = 0x4e ∧ p1 = 0x73` with Alive2
(bidirectional) and SAW, but its L leg is a **reviewed transcription** of
`Defs.lean:523-526` because the twin has no anchor helper and
`verify_script_full` returns `TWIN_INVALID_UNSUPPORTED` for every witness
program (`runtime.inc:806-810`, `:829-835` at the base commit).

The scalar predicate is not the whole row: Core's row is the P2A *branch*
(`interpreter.cpp:2000`, `!is_p2sh && IsPayToAnchor(witversion, program)` →
`return true`), and the fall-through ordering matters (P2A is before
`DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM`, and a P2SH-wrapped program never
takes the P2A arm).

## Patch (against `spec/equiv/twin/runtime.inc` at 5946c02)

```diff
@@ -315,6 +315,39 @@
   if (!(v == 0x00 || (0x51 <= v && v <= 0x60))) return false;
   return static_cast<uint32_t>(b[1]) + 2u == n;
 }
+
+// `CScript::IsPayToAnchor(version, program)` (script.cpp:216-222) =
+// Defs.lean:523-526.  Witness v1 with the two-byte program {0x4e,0x73}; the
+// serialized scriptPubKey is 51 02 4e 73.
+static bool is_pay_to_anchor(uint32_t version, const uint8_t* program,
+                             uint32_t plen) {
+  return version == 1 && plen == 2 && program[0] == 0x4e && program[1] == 0x73;
+}
+
+// The VerifyWitnessProgram P2A branch (interpreter.cpp:2000):
+//   `else if (!is_p2sh && CScript::IsPayToAnchor(witversion, program))`
+// = Defs.lean:1319 `else if !isP2SH ∧ isPayToAnchor version program`.
+static bool pay_to_anchor_branch(uint32_t version, const uint8_t* program,
+                                 uint32_t plen, bool is_p2sh) {
+  return !is_p2sh && is_pay_to_anchor(version, program, plen);
+}
+
+// Witness-program decode (Defs.lean:510-521 / script.cpp:250-264): the twin's
+// is_witness_program returns a Boolean only, so the P2A branch needs the
+// decoded (version, program) pair.  Same acceptance test, same bytes.
+struct WitnessProgram {
+  uint32_t version;
+  const uint8_t* program;
+  uint32_t plen;
+};
+static bool decode_witness_program(const uint8_t* b, uint32_t n,
+                                   WitnessProgram& out) {
+  if (!is_witness_program(b, n)) return false;
+  out.version = (b[0] == 0x00) ? 0u : static_cast<uint32_t>(b[0] - 0x50);
+  out.program = b + 2;
+  out.plen = n - 2;
+  return true;
+}
 // `ss == pushBytesWire redeem` (canonical push encoding; Defs.lean:377).
 static bool ss_equals_push(const uint8_t* redeem, uint32_t rlen,
                            const uint8_t* ss, uint32_t sslen) {
@@ -806,6 +839,11 @@
   const bool spk_wp = is_witness_program(spk, spk_len);
   if (ctx.flags.witness && spk_wp) {
     if (tx.ss_len != 0) return TWIN_WITNESS_MALLEATED;
+    WitnessProgram wp;
+    if (decode_witness_program(spk, spk_len, wp) &&
+        pay_to_anchor_branch(wp.version, wp.program, wp.plen, /*is_p2sh=*/false)) {
+      return TWIN_OK;                  // Defs.lean:1319 / interpreter.cpp:2000
+    }
     return TWIN_INVALID_UNSUPPORTED;   // witness v0/v1 engine: E4
   }
 
@@ -832,6 +870,16 @@
       if (!ss_equals_push(redeem, rlen, tx.ss, tx.ss_len)) {
         return TWIN_WITNESS_MALLEATED_P2SH;
       }
+      // is_p2sh = true here, so the P2A branch is excluded by its guard and a
+      // v1 2-byte program falls through to the unencumbered tail
+      // (Defs.lean:1319-1321 / interpreter.cpp:2000-2007).
+      WitnessProgram rwp;
+      if (decode_witness_program(redeem, rlen, rwp) && rwp.version == 1 &&
+          rwp.plen == 2) {
+        return ctx.pol.discourageUpgradableWitnessProgram
+                   ? TWIN_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
+                   : TWIN_OK;
+      }
       return TWIN_INVALID_UNSUPPORTED;   // witness v0 engine: E4
     }
     if (ctx.pol.cleanstack && final_len != 1) return TWIN_CLEANSTACK;
```

Nothing else changes: `gen.py` renders `runtime.inc` by substitution, so no
generator change is required and `gen.py --check` stays clean (verified).

## Acceptance

```sh
cd spec/equiv/twin
python3 gen.py --out build/twin.cpp --dump-ir build/twin.ir.json
python3 gen.py --check build/twin.cpp          # drift gate
CXX=clang++-20 ./smoke.sh --require-clang      # base suite: 147/147

# predicate + branch cell (edit the cell's L leaf to call twin::is_pay_to_anchor
# and twin::pay_to_anchor_branch first; see report.md for the exact leaf)
spec/equiv/cells/push-encoding/C-L-w32-p2a-anchor/alive2/run.sh
spec/equiv/cells/push-encoding/C-L-w32-p2a-anchor/saw/run.sh

python3 spec/equiv/findings/wave64/61-p2a-l-link/p2a_link_probe.py   # 10/10
```

Expected (all reproduced in the scratch tree):

```text
OK: build/twin.cpp matches generator output
cases=147 failures=0
RESULT[pinned-clang]: PASS
cell_p2a / cell_p2a_branch: 1 correct transformations, 0 incorrect, 0 errors
saw: 4 'Proof succeeded!', 0 'Proof failed'
10/10 cases match (8 Core verdicts, 2 E4 boundaries)
```

## Re-certification blast radius (why this is a handoff, not a cell edit)

`twin/runtime.inc` appears in 42 `certificate.sha256` files (21 cells, both
legs).  `tools/gate_ir_pin.py:254` replays every certificate against the tree,
so landing the hook without re-running those cells fails `make gate-ir-pin`:

| cell | certs |
|---|---|
| disabled/C-L-w32-disabled-dispatch | 2 |
| exec-verify/C-L-w32-p2sh-23byte | 2 |
| exec-verify/C-L-w32-verify-final-truth | 2 |
| exec-verify/C-L-w32-verify-sequential | 2 |
| exec-verify/C-L-w32-witness-flag | 2 |
| hash-ops/C-L-hash-compose | 2 |
| numeric/C-L-2div-disabled | 2 |
| numeric/C-L-binary-4byte | 2 |
| numeric/C-L-equal-rawbytes | 2 |
| numeric/C-L-unary-4byte | 2 |
| numeric/C-L-within-4byte | 2 |
| push-encoding/C-L-pushonly | 2 |
| push-encoding/C-L-w32-num-decode-minimal | 2 |
| push-encoding/C-L-w32-p2a-anchor | 2 |
| push-encoding/C-L-w32-p2sh-pattern | 2 |
| push-encoding/C-L-w32-pushonly-opcode | 2 |
| push-encoding/C-L-w32-witness-program | 2 |
| stack-ops/C-L-depth-size | 2 |
| stack-ops/C-L-ifdup | 2 |
| stack-ops/C-L-pick | 2 |
| stack-ops/C-L-w32-altstack-step | 2 |

The extracted leaf functions are disjoint from `verify_script_full`, so the
re-run is expected to reproduce today's results with new digests; the scratch
probe only exercised the p2a cell.

## Second ask (LEDGER, `spec/db/rules.yaml` SCR-055)

The row currently reads

```yaml
- id: SCR-055
  check: "IsPayToAnchor"
  lean_target: "Bitcoin.Interpreter.Defs.isWitnessProgram"
```

i.e. the row's Lean target is the *recognizer* (tagged SCR-053/054/055 at
`Defs.lean:508`), not the anchor predicate or the branch theorem.  The Lean
evidence that actually discharges SCR-055's binding exists and is rule-tagged:

- `BitcoinProofs.AF.PDW57.isPayToAnchor_iff` (`@[rule "SCR-055"]`, exact iff)
- `BitcoinProofs.AF.PDW41.verifyWitnessProgram_p2a_ok` (`@[rule "TPR-004"]`,
  native P2A → `.ok` for every witness/flags/policy/checker)
- `BitcoinProofs.AF.PDW59.verifyWitnessProgram_v1_anchor_ok` (`@[rule
  "SCR-150"]`), `…_v1_p2sh_ok`, `…_v1_p2sh_discourage`, `…_v1_wrong_size_*`
  (`@[rule "SCR-151"]`)

Please repoint `lean_target` to `PDW57.isPayToAnchor_iff,
PDW41.verifyWitnessProgram_p2a_ok` (or add them alongside) and regenerate
`spec/db/axiom-audit-rows.txt` via the usual generator.  No model change is
needed: `Defs.isPayToAnchor` is intentionally untagged (PDW57 follows the
"tags on my theorems, zero core writes" route).

## What this closes and what it does not

Closes: the L leg becomes generated-twin code for both the predicate and the
native/P2SH-wrapped v1 2-byte branch; the cell's `trust_note` caveat can be
deleted after landing.

Still open (unchanged, E4): witness **v0** execution and v1-32 **taproot**
execution; a bare non-P2A v1 2-byte program and v≥2 programs still return
result 3 (`TWIN_INVALID_UNSUPPORTED`).  Those shapes are outside SCR-055 and
are named in `findings/e5`/`findings/e4` as the witness-engine seam.
