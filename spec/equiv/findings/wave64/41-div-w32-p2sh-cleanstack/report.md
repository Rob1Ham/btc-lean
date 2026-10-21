# Wave64 — independent reproduction of F-DIV-W32-01

**Finding:** Lean `verifyScriptFull` rejects P2SH-wrapped witness spends under
`CLEANSTACK` (recorded in wave 32 as F-DIV-W32-01, proposed global id F-DIV-003).
**Agent:** `41-div-w32-p2sh-cleanstack`
**Worktree:** `/tmp/opencode/wave64/41-div-w32-p2sh-cleanstack`
**Branch:** `wave64/41-div-w32-p2sh-cleanstack`
**Base:** `5946c02` (integrate checksig scriptcode, stack-op, pushonly, and 2DIV cells)
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Tools:** real Bitcoin Core `VerifyScript` from the pin (clang++-20, LLVM 20.1.2),
Lean 4.35.0 (`lake env lean`), Alive2 20 (`alive-tv`).

---

## 0. Verdict

The divergence is **real, in-domain, and reachable for a valid spend**, in the
strongest form: every valid P2SH-wrapped v0 witness spend (the standard
P2SH-P2WPKH and P2SH-P2WSH forms) is rejected by the Lean model when
`pol.cleanstack = true`, while Bitcoin Core accepts it. The smallest witnesses
are a P2SH-P2WPKH spend (22-byte redeem script) and a P2SH-P2WSH spend (one
1-byte witness item).

This is the exact class of spend the SCR-008 row calls "implicit in witness".
The row's `flag` and `pol.` faces remain correct; the witness-implicit face is
not merely unproved — the model's answer for it is wrong. **SCR-008 stays
partial; it must not be marked full on the strength of
`verifyScriptFull_cleanstack_fails`, which only covers the bare / non-P2SH /
non-witness face.**

Two corrections to the wave-32 record are also established below:

1. The recorded Alive2 counterexample (`final_len=0, cs=1, kind=4`) is
   **outside the probe's declared domain** `kind ∈ {0,1,2}`; it comes from the
   C proxy using `bypass_kind != 0` while the L proxy uses `== 1`. It is
   therefore not, by itself, evidence for the divergence at the P2SH-wrapped
   arm. A domain-exact probe (§5) produces the in-domain counterexample.
2. The wave-32 report cites `Defs.lean:1395-1418` for `finalLen`; in the base
   of this worktree the relevant block is `Defs.lean:1412-1431` (the
   `afterBare` resize is `1398-1402`). The code and behaviour are exactly as
   described; only the line range is shifted.

---

## 1. The seam

Core, pristine pin (`src/script/interpreter.cpp`, `VerifyScript` at :2012):

```c
2047            hadWitness = true;           // bare arm
2057            stack.resize(1);             // bypass cleanstack
...
2091                hadWitness = true;       // P2SH-wrapped arm
2102                stack.resize(1);         // bypass cleanstack
...
2110    if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0) {
2113        assert((flags & SCRIPT_VERIFY_P2SH) != 0);
2114        assert((flags & SCRIPT_VERIFY_WITNESS) != 0);
2115        if (stack.size() != 1) {
2116            return set_error(serror, SCRIPT_ERR_CLEANSTACK);
2117        }
2118    }
```

Lean (`spec/core/Bitcoin/Interpreter/Defs.lean`):

```lean
 1398            let afterBare := if flags.witness ∧ (isWitnessProgram spk).isSome then
 1399              -- Bypass the cleanstack check: stack.resize(1)
 1400              (if stack = [] then [] else [stack[0]!])
 1401            else stack
 ...
 1412                let finalLen : Nat :=
 1413                  if flags.witness ∧ (isWitnessProgram spk).isSome then 1
 1414                  else
 1415                    -- non-witness P2SH: inner stack = eval of redeem script
 1416                    -- on stackCopy minus its top; recompute its length
 ...
 1429                          | .ok s2 => s2.length
 1431                if pol.cleanstack ∧ finalLen ≠ 1 then .fail .cleanstack
```

`spk` is the **P2SH scriptPubKey**, so `isWitnessProgram spk = none` in the
wrapped arm and the model takes the "re-evaluate the redeem script" branch.
The comment at :1414-1416 ("`p2shInner`'s success paths leave exactly 1 item")
is false for the witness arm: `p2shInner` (`Defs.lean:1346-1351`) runs
`evalScriptBytes` on the redeem script and then calls `verifyWitnessProgram`,
but never resizes. For a v0 witness program the redeem-script evaluation
leaves `[<0>, <program>]`, i.e. length **2**; `finalLen = 2`, and the check at
:1431 fires.

Notably, the very same arm's `witnessUnexpected` tail (:1432-1440) already
inspects `isWitnessProgram` of the redeem script (`stackCopy` head), so the
information needed for the correct `finalLen` is present one line below the
bug.

---

## 2. Exact witness (byte-for-byte)

All values are hex. `flags = {p2sh, witness}`, `pol = {cleanstack}`
(other policy flags false), signature checker = accept-all.

### W1 — P2SH-P2WPKH (divergent; minimal redeem script, 22 bytes)

| field | bytes |
|---|---|
| scriptSig | `16 0014adfce54f529b2154e3c361bbe3f7d41db0635717` |
| scriptPubKey | `a914 173727a17ada832a0fd90be6c628f63598b3400f87 87` |
| redeemScript | `00 14 adfce54f529b2154e3c361bbe3f7d41db0635717` |
| witness | `[ 300101 , 02 || 11×32 ]` |
| Core | `verify=true, err=OK` |
| Lean | `fail cleanstack` |

### W2 — P2SH-P2WSH (divergent; minimal witness data: one 1-byte item)

| field | bytes |
|---|---|
| scriptSig | `22 0020 4ae81572f06e1b88fd5ced7a1a000945432e83e1551e6f721ee9c00b8cc33260` |
| scriptPubKey | `a914 72c44f957fc011d97e3406667dca5b1c930c402687 87` |
| redeemScript | `00 20 4ae81572…3260` |
| witnessScript | `51` (OP_TRUE); `SHA256(0x51) = 4ae81572…3260` |
| witness | `[ 51 ]` |
| Core | `verify=true, err=OK` |
| Lean | `fail cleanstack` |

### Controls (same flags/policy)

| tape | Core | Lean |
|---|---|---|
| bare P2WPKH, `spk = 0014adfc…5717`, witness `[300101, 02‖11×32]` | ok | **ok** (the model does resize here) |
| plain P2SH, `ss = 0151`, `spk = a914 da1745e9…4b87 87` | ok | **ok** (`finalLen` re-evaluation agrees) |
| W1/W2 with `pol.cleanstack = false` | ok | **ok** |

The machine-readable copy is `witness/tape.json`.

The failure does not depend on the witness contents at all (`finalLen` is
computed from the redeem script, not the witness), so W2's single `OP_TRUE`
witness item is enough — a valid spend built from the least possible witness
data. W1 is simultaneously the smallest redeem script a v0 witness program
admits.

---

## 3. C side — real Core, not an excerpt

The wave-32 record compared two hand-written IR proxies and explicitly said
"Core was not executed on the tape — there is no Core build in this worktree."
That gap is closed here: `witness/core_probe.cpp` links the **real**
`src/script/interpreter.cpp`, `src/script/script.cpp`, `src/pubkey.cpp`,
`src/hash.cpp`, and the hash/cleanse units, then calls `VerifyScript`
directly. The only stub is a `BaseSignatureChecker` subclass accepting every
signature / locktime / sequence — an accept-all checker chosen to isolate the
cleanstack seam; no interpreter logic is rewritten. (Core's own `script_tests`
uses `BaseSignatureChecker` or a transaction checker depending on the row;
here the checker verdict is deliberately irrelevant.)

The local Core checkout (`/tmp/pcore01`) carries unrelated in-progress edits
to `interpreter.cpp`/`script.h` (an `#ifdef`-gated, non-throwing `CScriptNum`
experiment, +83 lines). To keep this evidence honest, `run_core_probe.sh`
extracts the **pristine** files from git at the pin:

```
pristine_interpreter_blob = 98b16eca6bcdfb5c98b5f51f6afc42062efb5f01
pristine_script_h_blob    = 08cd18f2a27ea968a9db49b50743c46b74eb5e30
```

and compiles those, with the pin line numbers used throughout this report.
Raw output (`witness/core-probe.txt`):

```
tape=p2sh-p2wpkh    cleanstack=1 verify=true err=OK(0) scriptSig=160014adfce54f529b2154e3c361bbe3f7d41db0635717 scriptPubKey=a914173727a17ada832a0fd90be6c628f63598b3400f87
tape=p2sh-p2wsh     cleanstack=1 verify=true err=OK(0) scriptSig=2200204ae81572f06e1b88fd5ced7a1a000945432e83e1551e6f721ee9c00b8cc33260 scriptPubKey=a91472c44f957fc011d97e3406667dca5b1c930c402687
tape=bare-p2wpkh    cleanstack=1 verify=true err=OK(0) scriptSig= scriptPubKey=0014adfce54f529b2154e3c361bbe3f7d41db0635717
tape=p2sh-plain     cleanstack=1 verify=true err=OK(0) scriptSig=0151 scriptPubKey=a914da1745e9b549bd0bfa1a569971c77eba30cd5a4b87
```

(The `cleanstack=0` rows are in the same file and are also `OK`.)

---

## 4. Lean side — executed on the same tapes

`witness/lean_probe.lean` evaluates `verifyScriptFull 64` on the exact byte
tapes above. Raw output (`witness/lean-probe.txt`):

```
"spkWPKH isWitnessProgram = none"
"redeemWPKH isWitnessProgram = some (0, {...20 bytes...})"
"redeemWSH isWitnessProgram = some (0, {...32 bytes...})"
"eval redeemWPKH on [] length = 2"
"eval redeemWSH on [] length = 2"
"p2shInner WPKH = OK"
"p2shInner WSH  = OK"
"verifyScriptFull P2SH-P2WPKH cleanstack=true  = FAIL Bitcoin.Interpreter.ExecError.cleanstack"
"verifyScriptFull P2SH-P2WSH  cleanstack=true  = FAIL Bitcoin.Interpreter.ExecError.cleanstack"
"verifyScriptFull P2SH-P2WPKH cleanstack=false = OK"
"verifyScriptFull P2SH-P2WSH  cleanstack=false = OK"
"verifyScriptFull BARE-P2WPKH  cleanstack=true  = OK"
"verifyScriptFull P2SH-plain   cleanstack=true  = OK"
```

This isolates the cause: `p2shInner` **succeeds** (witness verification runs
and passes), the post-redeem length is **2**, and the only failing gate is the
cleanstack tail. The `cleanstack=false` rows prove the failure is exactly the
`pol.cleanstack` decision, not witness validity; the bare and plain-P2SH rows
prove the model's two other arms are right.

A general bound, not just these two tapes: for any *valid* P2SH-wrapped
witness spend, `witnessMalleatedP2SH` requires `ss` to be exactly one push of
the redeem script, so `stackCopy = [redeem]`, `rest = []`, and the redeem
script of any v0 witness program is `OP_0 <20|32-byte push>` — its evaluation
is always `[<0>, <program>]`, length 2. Therefore `finalLen = 2 ≠ 1` for
**every** valid P2SH-wrapped v0 witness spend, and the Lean model rejects all
of them under cleanstack.

---

## 5. Differential probe, domain-exact

`witness/alive2/` replaces the wave-32 `bypass_kind` encoding with two
booleans and no out-of-domain value:

```
C (Core) : len = (bare || (wrapped && !bare)) ? 1 : inner_len
L (Lean) : len = bare ? 1 : inner_len
```

`bare = 1` ⇔ a bare witness program was verified; `wrapped = 1` ⇔ a
P2SH-wrapped witness program was verified. The `both = 1` combination is
ill-formed and both legs map it to the bare arm, so the only possible
disagreement is `wrapped && !bare`, i.e. the finding itself. Alive2 reports
(`witness/alive2/result.txt`):

```
Example:
i64 %inner_len = 0
i64 %cs_flag  = 1
i32 %bare     = 0
i32 %wrapped  = 1
Source value: 1 (ok)      Target value: 120 (CLEANSTACK)
```

This is the in-domain counterexample the recorded certificate should have
shown. For the concrete v0 tapes `inner_len = 2` (not 0); the probe is
symbolic in `inner_len` and the fork is on `inner_len ≠ 1`, so the concrete
value 0 is the solver's choice and does not weaken the result — the concrete
tapes pin it to 2 on both sides (§3, §4).

### What was wrong with the recorded counterexample

`divergence/alive2/result.txt` (wave 32) reports
`final_len=0, cs_flag=1, bypass_kind=4`. But its C leg is

```c
const uint64_t len = bypass_kind != 0u ? 1u : final_len;   // c_cell.cpp
```

while its L leg is

```c
const uint64_t len = bypass_kind == 1u ? 1u : final_len;   // l_cell.cpp
```

with `bypass_kind` documented as `0 = none, 1 = bare, 2 = P2SH-wrapped`.
`kind = 4` is outside that domain, so the recorded run only shows that the two
proxies disagree for an out-of-domain kind. It does **not** establish the
divergence at kind 2. The new probe does, and the concrete runs on both sides
remove any doubt.

I did not re-run the wave-32 `divergence/*/run.sh` scripts: they overwrite the
tracked `result.txt`/`certificate.sha256` of another cell, which would be a
shared edit.

---

## 6. Reachability and bound

**Reachable for a valid spend: yes.** Both W1 and W2 are ordinary,
standard-policy spends (P2SH-P2WPKH and P2SH-P2WSH are the canonical
SegWit-wrapped forms) and real Core returns success under the same three
flags/policy bits. The only reason the Lean model rejects them is the
`finalLen` bug.

Bounds that were *not* weakened:

- `CLEANSTACK ⇒ P2SH ∧ WITNESS` is satisfied by the flags used
  (`{p2sh, witness}` + `cleanstack`), so SCR-009's domain rule holds and no
  contract-violating flag combination is involved.
- The scriptSig is push-only and is exactly one canonical push of the redeem
  script, so SCR-006 and the WITNESS_MALLEATED_P2SH check pass.
- The witness programs are verified by the model (`p2shInner` returns `OK`);
  the failure is not a disguised witness failure.
- No signature is required to be valid; both checkers accept all signatures.
  This is a deliberate isolation of the cleanstack seam, not a weakening: the
  divergence is independent of signature validity.
- `pol.cleanstack` is the only policy bit set; all other policy flags are at
  their `false` defaults.

Scope of the divergence:

- **Policy only.** `CLEANSTACK` is policy (`spec/db/rules.yaml` SCR-008
  `consensus: false`). With cleanstack off both models agree (`OK`), so this
  is a false rejection at the policy/mempool face, not a consensus split.
- Only the **P2SH-wrapped** witness arm. The bare arm is resized correctly
  (:1398-1402); plain P2SH agrees (control above).
- It is not specific to P2WPKH or P2WSH: any valid P2SH-wrapped v0 witness
  spend has `finalLen = 2` (argument in §4).

---

## 7. Impact on SCR-008

SCR-008 is `"Exactly 1 element after all evaluation (flag; pol.; implicit in
witness)"`, `consensus: false`.

- The `flag` face (`stack.size() != 1`) and the `pol.` face (Lean reads the
  same bit) are unaffected; the wave-32 cell for them stays green.
- The `implicit in witness` face is the divergent one. The Lean entry point
  `verifyScriptFull` returns `.fail .cleanstack` for valid P2SH-wrapped witness
  spends, so the model does not merely omit the resize — it computes the wrong
  verdict for a real, standard spend class.
- The current ledger entry (`spec/db/equiv-cells.yaml`: `status: both-green`,
  `gap_note: null`, cell `exec-verify/C-L-verifyscript-tail`) and
  `spec/db/rules.yaml` (`status: proven`, target
  `BitcoinProofs.AF.PDW90.verifyScriptFull_cleanstack_fails`) are therefore
  **too strong for the row as summarised**. The theorem is not false: its
  hypotheses explicitly exclude the divergent arm
  (`hprog : isWitnessProgram spk = none`, `hp2sh : isPayToScriptHash spk = false`,
  `hwit : flags.witness = false`, `PDW90.lean:55-67`). It proves only the
  bare/non-P2SH/non-witness face. The witness-implicit and the general P2SH
  `finalLen` faces are not covered by it.
- Consequently: **SCR-008 remains partial.** The wave-32 disposition is
  upheld, with the added requirement that the gap be recorded as a model
  divergence (wrong verdict), not as missing coverage. Either fix `finalLen`
  (§8) and re-run the W1/W2 probes (expected `OK`), or re-scope SCR-008 to the
  flag/pol faces and track the witness-implicit face on a row that owns the
  model defect. Do not mark the row full while `verifyScriptFull` rejects W1.

Secondary observation for the row's trust note: `finalLen` *re-executes* the
redeem script (a second `evalScriptBytes` at :1425-1429) after `p2shInner`
already executed it. Besides being the source of the wrong length for the
witness arm, this double evaluation is a modelling smell: the cleanstack tail
should consume a length (or resize flag) produced by the one real execution,
not recompute it.

---

## 8. Root cause and minimal fix (proposed, not applied)

Root cause: `finalLen` (`Defs.lean:1412`) keys the witness resize off
`isWitnessProgram spk` (the P2SH scriptPubKey) instead of the P2SH **redeem**
script, and never resizes for the wrapped arm.

Minimal correct edit, using information the model already has:

```lean
let redeemIsWitnessProgram : Bool :=
  match stackCopy with
  | [] => false
  | p :: _ => (isWitnessProgram p).isSome
let finalLen : Nat :=
  if flags.witness ∧ redeemIsWitnessProgram then 1
  else <existing non-witness re-evaluation>
```

This is sound because the `.ok` branch of the P2SH arm is reached only after
`p2shInner` has (a) passed the `witnessMalleatedP2SH` check and (b) returned
`verifyWitnessProgram … = .ok` for the redeem script, whenever
`flags.witness` is set and the redeem is a witness program. The cleaner
refactor — and the one that also removes the double evaluation — is to have
`p2shInner` return the `hadWitness`/resize flag alongside its `VerifyOutcome`
and set `finalLen := if hadWitness then 1 else innerLen`. The misleading
comment at :1414-1416 should be deleted in either case.

No change was made to `spec/core/`, to any existing cell, or to the ledger in
this task. With the fix, W1/W2 should return `OK`; the controls must stay
`OK`. `verifyScriptFull_cleanstack_fails` should remain true (its hypotheses
never enter the P2SH arm), but its proof term may need the new `finalLen`
shape when re-elaborated.

---

## 9. Reproduce

```sh
# from the worktree root
spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/reproduce.sh
```

Component commands:

```sh
# 1. real Core at the pin (CORE_SRC defaults to /tmp/pcore01; pristine
#    interpreter.cpp/script.h are re-extracted from git at the pin)
CORE_SRC=/tmp/pcore01 \
  spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/run_core_probe.sh

# 2. Lean 4.35.0 on the same tapes (needs spec/core built: lake build)
spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/run_lean_probe.sh

# 3. domain-exact Alive2 differential (expected red)
spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/alive2/run.sh

# certificate checks
sha256sum -c spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/alive2/certificate.sha256
sha256sum -c spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/core-probe.sha256
sha256sum -c spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/witness/lean-probe.sha256
```

Observed status on the recorded runs: Core probe all `verify=true`; Lean probe
W1/W2 `FAIL cleanstack`, four controls `OK`; Alive2
`STATUS=alive2-counterexample-as-expected`; all certificate entries `OK`.

Primary artifact hashes (the `*.sha256` files additionally cover the run
scripts, logs and generated IR):

```
00c5e7028f296019b226bd25e5ce1705af7cde45c64d0aacb6b5622f446e2c44  witness/core_probe.cpp
9f048da2f79c239a884d49bdd6418e032b29d4c006a534042823e19bb47719f3  witness/lean_probe.lean
1b9b1232bb2d5b05a69a20c99562297169874c23c5c6ab98778acfef65ad3647  witness/core-probe.txt
04af84d61ef6a6596d6f3607c2d6dea0ae07094a0e9e553d51bd76576b9a7c59  witness/lean-probe.txt
f179c5aac40f868a60f2d3a18cc53216eb1fe959c78d06878dfadf8dfe83f9ca  witness/tape.json
```

`witness/build/` is ignored by `spec/equiv/.gitignore` (`build/`), matching the
cell convention; the certificates therefore verify after re-running the
scripts, which regenerate it deterministically.

---

## 10. Provenance / hygiene

- **No shared edits.** Only new files under
  `spec/equiv/findings/wave64/41-div-w32-p2sh-cleanstack/` were added.
  `spec/core/`, the wave-32 cell, the ledger, and `/tmp/opencode/equiv-pr`
  were not touched.
- **Pin purity of the C side.** `/tmp/pcore01` is a local checkout at
  `cce32b168…` but is *modified* (an unrelated `#ifdef`-gated `CScriptNum`
  experiment shifts `VerifyScript` down by 83 lines). The runner extracts
  `src/script/interpreter.cpp`, `src/script/script.cpp` and
  `src/script/script.h` from `git show <pin>:…` and records their blob hashes,
  so the compiled interpreter is the pristine pin and the line citations above
  are the pin's own.
- **Signature checker.** Both sides use accept-all checkers. This is an
  explicit isolation of the cleanstack seam; the finding is independent of
  signature validity and of the E5 `EvalScript` residual (only push / OP_TRUE /
  witness-v0 execution is involved, all inside the verified model).
- **Not re-run.** The wave-32 divergence scripts were not executed because
  they write into a tracked cell directory. Their raw outputs were read, and
  the in-domain gap in their counterexample is analysed in §5.
- **No mutations, no ledger regeneration, nothing pushed.**

## 11. What was not done

- No fix was committed to `spec/core/Bitcoin/Interpreter/Defs.lean`; the edit in
  §8 is a proposal. Re-running W1/W2 against a patched model is the natural
  next experiment.
- No attempt to prove the "every valid P2SH-wrapped v0 spend has inner length
  2" statement as a Lean theorem; it is argued from `witnessMalleatedP2SH` and
  the v0 program shape, and confirmed concretely for both program sizes.
- No P2SH-wrapped v1/Taproot tape: `CLEANSTACK`/standard policy does not use
  P2SH-wrapped Taproot in practice, and the witness checker would need the
  full Taproot seam. The v0 family already establishes the general bound.
