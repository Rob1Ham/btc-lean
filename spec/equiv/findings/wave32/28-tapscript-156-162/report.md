# Wave 32 / task 28 — tapscript rows SCR-156…SCR-162

Worktree `/tmp/opencode/wave32/28-tapscript-156-162`, branch
`wave32/28-tapscript-156-162`, base `805c804` (PR #29 head). Not pushed.

Three new self-contained C-L cells under
`spec/equiv/cells/tapscript/`, all with real Alive2 and SAW runs:

| Cell | Rows | Alive2 | SAW |
|---|---|---|---|
| `C-L-w32-checksigadd` | SCR-156, SCR-157 | green (`cell_add_dispatch`, `cell_add_num`, 0 incorrect / 0 failed-to-prove each) | green, 176/176 proofs |
| `C-L-w32-pubkey-triage` | SCR-158, SCR-159, SCR-160 | green (`cell_triage`, `cell_triage_continue`) | green, 108/108 proofs |
| `C-L-w32-schnorr-shape` | SCR-161, SCR-162 | green (`cell_schnorr_shape`) | green, 116/116 proofs |

All Alive2 runs are `alive-tv --bidirectional` on `llvm-extract
--recursive` slices, so both `L ⊑ C` and `C ⊑ L` are checked. All SAW
scenarios are generated from an independent `src/oracle.py` written from
the SCR row and the pinned Core source, and each scenario is verified
against both legs.

## Row table

| SCR | status | cell | what was proved | what remains | exact blocker |
|---|---|---|---|---|---|
| SCR-156 (`CHECKSIGADD`) | full (bounded one-step cell) | `C-L-w32-checksigadd` | `interpreter.cpp:1094-1113`: BASE/WITNESS_V0 → BAD_OPCODE(16) at every depth; TAPSCRIPT depth < 3 → INVALID_STACK_OPERATION(18); depth ≥ 3 → pop `(sig,num,pk)`, EvalChecksigTapscript, push canonical `num + (success?1:0)`; every branch symbolic in both legs | the real `EvalScript` loop, `ParseScript`, witness/annex layer, sigop accounting (SCR-155), SCRIPT_SIZE, consensus flag selection; the R leg | no Alive2-ingestable R IR at the pin (F-TOOL-001) and no tapscript CHECKSIGADD cell on the R lane |
| SCR-157 (minimal `num`, width ≤ 4) | full (bounded one-step cell) | `C-L-w32-checksigadd` | `script.h:246-271,335-391` / `Defs.lean:629-635,803-815`: `num` length 0..5 symbolic; minimal and non-minimal encodings; width-4 limit; leading-zero and negative-zero (`0x80`) rejection; sign-bit exception (`0xff00`); parse order (arity → num → signature) | full `CScriptNum` over an unbounded script element and the engine's throw/catch; the R leg | same as SCR-156, plus the cell's 5-byte operand domain |
| SCR-158 (pubkey 0 ⇒ fail, 32 ⇒ Schnorr, else upgradable) | full (bounded one-step cell) | `C-L-w32-pubkey-triage` | `interpreter.cpp:377-392`: pubkey lengths 0, 32 and every other length 1..255 symbolic; empty/non-empty sig; both DISCOURAGE_UPGRADABLE_PUBKEYTYPE states; checker 0/1; weight above/at/below the decrement | the caller's full EvalScript invocation and real policy flag set; the R leg | same no-R-IR blocker; the Schnorr verdict is the shared external symbol (same-crypto premise) |
| SCR-159 (`TAPSCRIPT_EMPTY_PUBKEY` after the weight decrement) | full (bounded one-step cell) | `C-L-w32-pubkey-triage` | `interpreter.cpp:369-378`: decrement happens first and in place; empty pubkey with empty sig leaves the weight unchanged; non-empty sig with weight ≥ 50 → 52 after the decrement; weight < 50 → 49 wins, weight observable | the weight *initialisation* (`GetSerializeSize(witness.stack)+50`) and the engine's `m_validation_weight_left` field; the R leg | weight is an explicit cell input (seed − 100) because the Lean `Except` drops machine state; no R IR |
| SCR-160 (empty sig + x-only key: false, no call, no weight) | full (bounded one-step cell) | `C-L-w32-pubkey-triage` | `interpreter.cpp:379-382` and `1094-1113`: empty sig + 32-byte key → `success=0`, checker not called, weight unchanged, eval OK; `cell_triage_continue` pushes the unchanged num and continues (depth 1, result 1); non-empty sig does call the checker | the CHECKSIGADD continuation inside the full stack machine; the R leg | `called` is cell-harness instrumentation of the call site (Lean `Except` has no state); no R IR |
| SCR-161 (`else SCHNORR_SIG_SIZE`) | full (bounded one-step cell) | `C-L-w32-schnorr-shape` | `interpreter.cpp:1736` / `RealChecker.lean:124-125`: signature length symbolic 0..255; only 64 and 65 pass; every other length → 45 regardless of payload and of the trailing-byte operand; 64/65 reach the tail | the tail (`SignatureHashSchnorr`, `VerifySchnorr`), the full checker context, the R leg | tail is one shared external symbol (same-crypto/same-sighash premise); no R IR |
| SCR-162 (`SIGHASH_DEFAULT` invalid as explicit byte) | full (bounded one-step cell) | `C-L-w32-schnorr-shape` | `interpreter.cpp:1741-1744` / `Entry.lean:156-161`: 65-byte sig with trailing byte 0x00 → 46 before any tail work; every non-zero trailing byte (0..255 symbolic) reaches the tail with a 64-byte body; a 64-byte sig ignores the trailing byte and uses implicit default 0 | BIP341 hashtype validity (`≤0x03`/`0x81..0x83`, SCR-163), `htSingle` bounds, sighash preimage and BIP340 verification; the R leg | those checks live inside the shared tail symbol by construction; no R IR |

Rows closed: 7 (SCR-156…SCR-162), each as a full bounded C-L cell.
Rows partial: 0. Rows blocked: 0. The R leg is not attempted in any cell
(the existing C-L cell pattern in PR #29); that is stated as the remaining
work above, not counted as row closure of a three-leg claim.

## Observable and harness notes

* Element ABI: scalar `uint64_t`, bits 0..7 = length, bits 8..47 = bytes
  b0..b4. No arrays or loops, so Alive2 stays tractable. The same encoding
  is passed to the shared checker, so "same arguments" at the seam means
  "same element" over the cell domain.
* CHECKSIGADD observable (`src/tap_common.h`, `tp_pack`): result, error
  ordinal, stack depth, top length and top five bytes. Triage observable
  (`tp_pack_triage`): eval_ok, error ordinal, success, post-call weight,
  checker-call bit. Shape observable (`tp_pack`): eval_ok and error.
* Both legs pack the observable identically; packing is cell harness, not
  engine code.
* Same-crypto/same-sighash premises are explicit in every `spec.md`:
  `btc_equiv_check_schnorr` (cells 1-2) and `btc_equiv_schnorr_tail`
  (cell 3) are one external symbol per cell, called with the same arguments
  in both legs. Nothing claims libsecp256k1, BIP340, BIP341, SHA256 or
  RIPEMD160 internals.
* C legs are line-cited source slices at pin `cce32b168`. L legs are
  reviewed transliterations of `spec/core/Bitcoin/...` at
  `4d62a97e`; the generated `twin/ops_ir.py` has no tapscript handler, so no
  generated Lean IR exists to ingest.
* Out-of-contract inputs (non-32 pubkey for SCR-161/162, TAPROOT
  sigversion for SCR-156) return the same all-ones out-of-domain sentinel
  in both legs; no scenario inside the declared domain can produce it.

## Commands and raw outcomes

```sh
cd spec/equiv/cells/tapscript/C-L-w32-checksigadd && ./alive2/run.sh && ./saw/run.sh
# STATUS=alive2-green; STATUS=saw-green (176/176 proofs)

cd spec/equiv/cells/tapscript/C-L-w32-pubkey-triage && ./alive2/run.sh && ./saw/run.sh
# STATUS_cell_triage=alive2-green
# STATUS_cell_triage_continue=alive2-green
# STATUS=alive2-green; STATUS=saw-green (108/108 proofs)

cd spec/equiv/cells/tapscript/C-L-w32-schnorr-shape && ./alive2/run.sh && ./saw/run.sh
# STATUS_cell_schnorr_shape=alive2-green
# STATUS=alive2-green; STATUS=saw-green (116/116 proofs)

cd /tmp/opencode/wave32/28-tapscript-156-162
for c in spec/equiv/cells/tapscript/C-L-w32-{checksigadd,pubkey-triage,schnorr-shape}; do
  sha256sum -c "$c/alive2/certificate.sha256"
  sha256sum -c "$c/saw/certificate.sha256"
done
# all six certificates: every entry OK
```

Tool versions (recorded in each `result.txt`): `alive-tv` Ubuntu LLVM
20.1.2, `clang++-20` 20.1.2, SAW 1.6 (68eed5f).

Certificates list only committed files (`spec.md`, `run.sh`, `src/*`,
`result.txt`); `build/` is gitignored, so `sha256sum -c` works from a fresh
checkout of the commit.

## Not done / smallest next experiments

* R leg: blocked on `F-TOOL-001` (pinned rbitcoin IR is not
  Alive2-ingestable) and on the absence of tapscript cells in the R lane.
  Smallest next experiment: produce a standalone Alive2-ingestable R
  function for `CheckSchnorrSignature`/`EvalChecksigTapscript`; no such
  extraction exists at this pin.
* Full engine closure: needs the `EvalScript` loop, witness/annex handling,
  validation-weight initialisation and real script parsing. Smallest next
  experiment: lift `C-L-w32-pubkey-triage`'s weight seed to the
  `GetSerializeSize(witness.stack)+50` computation once a witness-stack ABI
  exists.
* SCR-163/165 (hashtype validity, 64-byte implicit default) are deliberately
  left to their own rows; cell 3 exercises them only as the abstract tail.
