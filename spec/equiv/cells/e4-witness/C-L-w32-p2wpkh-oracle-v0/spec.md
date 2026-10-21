---
# Cell e4-witness/C-L-w32-p2wpkh-oracle-v0
cell: C-L-w32-p2wpkh-oracle-v0
family: e4-witness
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 76dbfe5e42f8a337e41a7308158b0de078afafd9
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
tool_status: both-green (total P2WPKH v0 outcome + the HASH160/CHECKSIG oracle interface, symbolic 160-bit program, symbolic hash and checker seams, symbolic selector/word index)
precondition: |
  - Seam: the P2WPKH arm of VerifyWitnessProgram (interpreter.cpp:1947-1953),
    the ExecuteWitnessScript consumer (interpreter.cpp:1842-1879) and the five
    EvalScript iterations the implied script performs.  No transaction, no
    amount, no flags/policy word, no P2SH, no taproot, no whole-engine loop.
  - Export (A) cell_p2wpkh_scr136 inputs (all 64-bit words, all symbolic):
      p0,p1,p2      the 20-byte witness program (bytes 0..7, 8..15, 16..19;
                    p2 bits 32..63 do not reach any script byte);
      n_wit         witness stack size;
      sig_len       witness item 0 length (the signature);
      pk_len        witness item 1 length (the pubkey);
      h0,h1,h2      the modelled HASH160(pubkey) result, 20 bytes (hash seam);
      ck_err        modelled EvalChecksig ScriptError ordinal, low 6 bits;
      ck_ok         modelled EvalChecksig fSuccess when ck_err = 0.
  - Export (B) cell_p2wpkh_seam takes the same inputs plus
      sel           transcript selector (0..8; see the postcondition table);
      k             transcript word index, any 64-bit value;
      s0..s9        80 bytes of signature-item content;
      k0..k8        72 bytes of pubkey-item content.
    sel and k are ordinary inputs, so one symbolic proof covers every selector
    and every word index.  Only sel,k<2^32 can matter (the leaf narrows both to
    the low 32 bits, matching a uint32_t field), and bytes beyond pk_len /
    sig_len read as 0.
  - h0..h2 and (ck_err, ck_ok) are *free inputs*: the cell assumes nothing
    about them and proves the outcome and the oracle arguments for every
    possible value.  They are the declared same-hash / same-crypto seams
    (same value on both legs and in the Cryptol contract).
  - Bounded representation: script bytes are a pure selector over the 25-byte
    implied-script emission (no buffer/heap); the GetScriptOp walk and the
    EvalScript loop are unrolled exactly five times; stack elements carry a
    20-byte payload window, the true byte length and a byte-source tag.  The
    pubkey item window is 72 bytes and the signature window 80 bytes, covering
    every compressed (33) or uncompressed (65) pubkey and every DER signature
    (<= 73); lengths are exact up to the 520-byte witness item cap.
  - The witness stack is two items; pushed payloads longer than 20 bytes and
    instructions outside the fixed five take the out-of-domain arm and are not
    reachable for the unmutated program.  The EvalScript terminal 1000-item
    STACK_SIZE guard is not modelled because depth never exceeds 4.
postcondition: |
  - Export (A), packed result(2) | error_ordinal(6) << 2, total over all inputs:
      n_wit != 2                                   -> (0, 40) WITNESS_PROGRAM_MISMATCH
      sig_len > 520 or pk_len > 520                -> (0,  6) PUSH_SIZE
      program != HASH160(pubkey) (20 bytes)        -> (0, 12) EQUALVERIFY
      program = HASH160(pubkey), ck_err != 0       -> (0, ck_err low 6 bits)
      program = HASH160(pubkey), ck_err = 0,
        ck_ok = 0                                  -> (0,  2) EVAL_FALSE
      otherwise                                    -> (1,  0) success
    with the ordering above (arity, witness item cap, then the script), and
    each row converse: 40 iff n_wit != 2; 6 iff an item exceeds 520; 12 iff the
    two 20-byte values differ; the checksig ordinal iff reached with
    ck_err != 0; 2 iff reached with a false checksig; 1 iff reached with a true
    checksig.
  - Export (B), the oracle-interface transcript (result is a raw word).  The
    only seam reached is the first one selected:
      sel 0, word k -> word k of the HASH160 preimage, which is exactly the pk
                       witness item (OP_DUP duplicates pk before OP_HASH160;
                       interpreter.cpp:1048-1056 hashes the whole top element),
                       masked to pk_len;
      sel 4         -> HASH160 preimage length = pk_len;
      sel 5         -> HASH160 output width = 20 (interpreter.cpp:1042);
      sel 1, word k -> EvalChecksig signature argument, word k of the sig item,
                       masked to sig_len (stacktop(-2), interpreter.cpp:1075);
      sel 2, word k -> EvalChecksig pubkey argument, word k of the pk item,
                       masked to pk_len (stacktop(-1), interpreter.cpp:1076);
      sel 3, word k -> EvalChecksig scriptCode, word k of the whole 25-byte
                       implied script (pbegincodehash = begin, no
                       OP_CODESEPARATOR, WITNESS_V0 skips FindAndDelete;
                       interpreter.cpp:331-355);
      sel 6         -> EvalChecksig signature length = sig_len;
      sel 7         -> EvalChecksig pubkey length = pk_len;
      sel 8         -> EvalChecksig scriptCode length = 25.
    Selection precedence is execution precedence: a witness-arity failure or a
    witness-item size failure is an error before any seam; the hash seam is
    reached at OP_HASH160 before OP_EQUALVERIFY, so sel 0/4/5 do not depend on
    the hash matching; the checksig seam is reached only when program =
    HASH160(pubkey), because OP_EQUALVERIFY (12) otherwise aborts first.
    Every other case (a selector that is not a seam, a non-matching program
    before a checksig selector, an error before the seam, or an out-of-domain
    decode) returns the all-ones sentinel 0xffffffffffffffff.
  - Converse forms hold for the transcript too: each selector returns its
    stated word/length, and the sentinel is returned exactly on the
    non-reached/out-of-domain conditions above.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-136
scr_row_coverage: |
  full — SCR-136 at this cell's scope, conditional on the named same-hash and
  same-crypto oracle premise.  SCR-136 is the whole P2WPKH arm: the 20-byte
  program selects the five-instruction implied script and
  ExecuteWitnessScript consumes it.  This cell proves, for every input and in
  both directions:
  - the total execution outcome of that arm (arity 40, item cap 6, hash
    mismatch 12, checksig ordinal, false 2, success 1), and
  - the oracle interface itself: the HASH160 preimage is the whole pk witness
    item with its exact length and a 20-byte output; EvalChecksig receives the
    sig item, the pk item and the 25-byte implied script as scriptCode, with
    their exact lengths.
  Together with e4-witness/C-L-w32-p2wpkh-build (the 25-byte reconstruction,
  unchanged) and e4-witness/C-L-w32-p2wpkh-exec (the same outcome without the
  oracle-interface export), the row no longer has an unmodelled
  build/decode/execute step.  The only remaining objects are the two named
  primitives:
  - HASH160(pk) is a free 20-byte input h0..h2.  The cell proves that this is
    exactly the preimage/width the interpreter would hand to CHash160; it does
    not compute RIPEMD160(SHA256(pk)) (hash floor, SCR-093/SCR-133 territory).
  - EvalChecksig at WITNESS_V0 is a free (ck_err, ck_ok) pair.  The cell proves
    the exact arguments and lengths it receives; it does not implement the DER/
    hashtype/low-S/NULLFAIL checks or the ECDSA decision (E3/SCR-112 territory).
  The same-crypto premise is the accepted boundary used by
  checksig/C-L-checksig-nullfail-hashtype (SCR-110/SCR-111 full with a
  symbolic checker verdict) and hash-ops/C-L-hash-widths (SCR-093/SCR-095 full
  with opaque externals).  It is stated, not silently discharged: no concrete
  hash or ECDSA implementation is claimed.
patches: none
source_citations:
  - interpreter.cpp:1947-1953 (v0 20-byte arm, arity != 2 -> 40, implied script, ExecuteWitnessScript)
  - interpreter.cpp:1842-1879 (ExecuteWitnessScript item cap, EvalScript, cleanstack, CastToBool)
  - interpreter.cpp:446-490 (EvalScript prologue; GetOp failure -> 16; push size; op budget; disabled table)
  - interpreter.cpp:803-812 (OP_DUP)
  - interpreter.cpp:896-925 (OP_EQUAL / OP_EQUALVERIFY, error 12)
  - interpreter.cpp:1032-1059 (OP_HASH160 dispatch; :1042 20-byte result; :1048-1056 CHash160 over the whole top element)
  - interpreter.cpp:1069-1088 (OP_CHECKSIG / OP_CHECKSIGVERIFY; :1075-1076 stacktop(-2)/stacktop(-1))
  - interpreter.cpp:331-355 (EvalChecksigPreTapscript: scriptCode = CScript(pbegincodehash, pend); WITNESS_V0 skips FindAndDelete)
  - interpreter.cpp:46-59 (CastToBool)
  - script.cpp:313-363 (GetScriptOp; direct push, PUSHDATA1/2/4, truncation)
  - script.h:29,32 (MAX_SCRIPT_ELEMENT_SIZE = 520, MAX_OPS_PER_SCRIPT = 201)
  - script.h:408-431,470-488 (implied-script byte emission)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1259-1280 (Lean verifyWitnessProgram v0 arm)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1207-1236 (executeWitnessScript)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1163-1185 (evalScriptBytes)
  - spec/core/Bitcoin/Interpreter/Defs.lean:1144-1152 (evalFrom)
  - spec/core/Bitcoin/Interpreter/Defs.lean:817-860,940-1010,1030-1059,1131-1142 (stepBody/stepChecked dispatch; HASH160 hashes topAt 1; CHECKSIG reads topAt 2/1)
  - spec/core/Bitcoin/Interpreter/Defs.lean:720-739 (evalChecksigPreTapscript scriptCode extract)
  - spec/core/Bitcoin/Script/Parser/Defs.lean:206-231 (getOpAux/getOp)
  - spec/core/Bitcoin/Numeric/Interface.lean:64-65 (castToBool)
  - spec/equiv/contract/error_enum.md (ordinals 2, 6, 7, 12, 16, 18, 30, 40)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core at the pin, not the
  whole VerifyWitnessProgram and not the whole EvalScript: the implied script
  has five instructions, so the loop and the GetOp walk are unrolled five
  times.  L is a reviewed manual transliteration of the Lean step semantics
  (the twin has no ExecuteWitnessScript handler, so there is no generated body
  and no mk_leaf instance), with the Lean byte-list construction indexed
  directly.  The bounded representation (20-byte payload window per stack
  element plus a byte-source tag, 72-byte pubkey / 80-byte signature windows,
  a pure byte selector instead of a std::vector, a fixed policy/flags word) is
  stated in the precondition; item lengths, the 520 cap, the 201-op budget,
  the disabled table, the error ordinals, the EQUALVERIFY-before-CHECKSIG
  ordering and the cleanstack/CastToBool predicates are exact.  HASH160 and
  EvalChecksig are NOT modelled: their results are free inputs, so the cell
  proves the *interface* (which bytes and lengths each primitive receives) and
  the outcome for every possible primitive verdict, but makes no claim that a
  concrete hash or ECDSA implementation returns those values.  Instantiating
  the two seams is the residual obligation.  F-DIV-004 (Lean isValidPubKey is
  header-only here while Core's CPubKey::ValidSize is exercised through the
  free checksig verdict) is inherited through the seam and is not discharged
  by this cell; since ck_err/ck_ok are arbitrary, the cell is sound for any
  pubkey-validity policy.  Alive2 compares the emitted C and L IR in both
  directions for both exports; SAW verifies each module against the same
  independent Cryptol postcondition with z3.  No Core source patch, no
  override and no assumption is used.
evidence:
  - alive2/result.txt, alive2/certificate.sha256
  - saw/result.txt, saw/certificate.sha256, saw/spec.cry, saw/spec.saw
  - evidence/matrix.txt (concrete outcome + transcript table with independent asserts)
  - evidence/leaf-shape.txt (0 loops, 0 calls, 0 allocas on both legs and both exports)
mutant: >
  Scratch probes (notes.md §6, not committed): (M1) change the HASH160 dispatch
  to hash the program element instead of the duplicated pk item; (M2) change
  scriptCode in the transcript to only the program bytes instead of the whole
  25-byte script; (M3) drop the EQUALVERIFY-before-CHECKSIG ordering so a
  checksig selector answers on a hash mismatch.  Alive2 reports
  "Transformation doesn't verify!" and SAW fails the corresponding transcript
  obligation for each.  These constrain the seam interface, not just the
  final outcome.
---

# e4-witness/C-L-w32-p2wpkh-oracle-v0

SCR-136 (`DUP HASH160 <20> EQUALVERIFY CHECKSIG`) is the P2WPKH v0 arm.
The two existing cells already prove the byte reconstruction
(`e4-witness/C-L-w32-p2wpkh-build`) and the five-op execution outcome
(`e4-witness/C-L-w32-p2wpkh-exec`), but in both of them the two crypto pieces
are opaque *inputs* whose arguments are never checked: the h0..h2 hash is not
tied to the pubkey bytes, the signature/pubkey contents are unobservable, and
scriptCode is not modelled at all.

This cell closes that interface gap.  It keeps the same bounded five-op machine
and adds a second export that returns the argument word each seam receives, so
the C and L legs are compared not only on the final `(result, error)` pair but
on **which byte string and length the interpreter would hand to HASH160 and to
EvalChecksig**.

## 1. What is proved

Two independent Cryptol contracts (`saw/spec.cry`) drive four SAW obligations
and two bidirectional Alive2 comparisons:

1. **Outcome** (`cell_p2wpkh_scr136`, same contract as the exec cell):
   arity 40, item cap 6, hash mismatch 12, checksig ordinal, false 2,
   success 1 — total and converse-characterised.
2. **Oracle interface** (`cell_p2wpkh_seam`): with symbolic `sel` and `k`,
   - `sel 0,k` = word k of the HASH160 preimage = the pk witness item;
   - `sel 4` = preimage length = `pk_len`; `sel 5` = output width = 20;
   - `sel 1,k` / `sel 2,k` = word k of the sig / pk argument to EvalChecksig;
   - `sel 3,k` = word k of the 25-byte implied script used as scriptCode;
   - `sel 6/7/8` = the three lengths EvalChecksig receives;
   - all-ones sentinel iff the selected seam is not reached.
   Selection follows execution order: the hash seam is before OP_EQUALVERIFY,
   the checksig seam is after it (so it requires program = HASH160(pk)).

`sel` and `k` are inputs, so one symbolic run covers every selector and every
word index; the exposed item windows are 80 bytes for the signature and 72 for
the pubkey (every DER signature <= 73, every compressed/uncompressed key).

## 2. Why this is the strongest sound step

- It does not weaken the exec cell: the outcome contract is identical.
- It removes the "unproven oracle arguments" residual: the bytes HASH160 hashes
  and the scriptCode/sig/pubkey EvalChecksig sees are now inside the compared
  functions and the same on C, L and the independent contract.
- It stays sound: the primitives themselves remain free (`h0..h2`,
  `ck_err/ck_ok`), so the cell is parametric and makes no concrete-hash or
  ECDSA claim.  Instantiating the seams is named as the residual.

## 3. Boundedness

`src/build.sh` extracts each export and records
`evidence/leaf-shape.txt`: **0 loops, 0 calls, 0 allocas** on both legs and
both exports.  The script is a pure byte selector over the 25 implied bytes;
the GetOp walk and EvalScript loop are unrolled five times.  Stack elements are
a 20-byte window plus an exact length plus a byte-source tag, which is what
lets the transcript export tell "pk item" apart from "program" or "hash".

## 4. Exact runs

```sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-oracle-v0/alive2/run.sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-oracle-v0/saw/run.sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-oracle-v0/src/matrix.sh
```

Alive2, `--bidirectional --smt-to=120000`, both exports:
`Transformation seems to be correct!`, `1 correct`, `0 incorrect`,
`0 failed-to-prove`, `0 Alive2 errors`.

SAW 1.6, solver z3, four obligations:
`Proof succeeded!` for outcome C/L and transcript C/L.

Both `certificate.sha256` files cover the tracked cell inputs and the raw
result only (no `build/**`), so they replay from a fresh checkout.

## 5. Residual

1. HASH160: instantiate `h0..h2` with a model of `CHash160` and prove it equals
   `RIPEMD160(SHA256(pk))` over the witness byte strings (hash floor).
2. EvalChecksig at WITNESS_V0: instantiate `(ck_err, ck_ok)` with the encoding
   checks and the ECDSA decision (E3 / SCR-112).
3. `witversion = 0` is a shared precondition of every v0 cell, not modelled
   here; program length/version dispatch is SCR-135/SCR-137
   (`e4-witness/C-L-w32-witness-v0-error-total`).
4. F-DIV-004 (Lean `isValidPubKey` header-only vs Core `CPubKey::ValidSize`) is
   inherited through the free checker verdict and is not discharged; the cell
   is sound for any pubkey-validity policy because the verdict is arbitrary.
