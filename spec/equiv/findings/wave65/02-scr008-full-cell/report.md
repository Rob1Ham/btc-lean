# Wave65 / 02 — can a full, behaviour-preserving SCR-008 cell exist at the pin?

**Row:** SCR-008 — "Exactly 1 element after all evaluation (flag; pol.;
implicit in witness)", `interpreter.cpp:VerifyScript:2110-2118@cce32b168`.
**Base:** `76dbfe5e42f8a337e41a7308158b0de078afafd9` (branch
`equiv/llvm-three-leg`, PR #29).
**Branch:** `wave65/02-scr-008`.
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (pristine
`interpreter.cpp` blob `98b16eca6bcdfb5c98b5f51f6afc42062efb5f01`).
**Lean model:** `spec/core/Bitcoin/Interpreter/Defs.lean` blob
`363d3738b66049e260577e9c1fa2cd24d05f6e3b` — byte-identical to the blob
examined by wave64/41, so the model has not moved since the demotion.
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`.

---

## 0. Verdict

**No.** A cell that covers the whole row and is behaviour-preserving *with
respect to the pinned Lean model* cannot be constructed at this base. The
`implicit in witness` face of the row is not merely unproved: for the
P2SH-wrapped witness arm under `CLEANSTACK` the pinned model returns the
**wrong verdict**, so any faithful C–L comparison over that class is
necessarily a counterexample.

What this wave delivers instead:

1. **Re-establishment at this base, on both real sides.** Real pinned Bitcoin
   Core (`VerifyScript` compiled from the pin) accepts P2SH-P2WPKH and
   P2SH-P2WSH spends under `CLEANSTACK`; real Lean 4.35 `verifyScriptFull 64`
   rejects both with `.fail .cleanstack`. Raw logs and hashes below.
2. **A full-domain Alive2 counterexample** at exactly the divergent class
   (`cleanstack=1, witness=1, p2sh=1, spk_p2sh=1, redeem_wit=1, ss_push_ok=1,
   inner_len=2`, Core `1` vs Lean `120 = CLEANSTACK`), and a matching **SAW
   refutation** of the pinned leg against the Core postcondition.
3. **The one-line model fix is sufficient.** With `finalLen` keyed off the
   *redeem* script instead of the scriptPubKey, the **same full-domain probe
   is green under Alive2 and SAW** — i.e. a genuinely full three-arm cell is
   constructible the moment `Defs.lean` is fixed. No Lean file was modified.
4. **The maximum sound cell available now**:
   `cells/exec-verify/C-L-w65-scr008-cleanstack-arms` — a faithful pinned-L
   transliteration, green on Alive2 and SAW, whose declared domain covers the
   plain-script, native-witness, plain-P2SH and non-cleanstack-wrapped faces
   and excludes only the divergent set. Its `scr_row_coverage` is **partial**.
   The ledger is untouched: **SCR-008 remains `gap` and is not closable**.

---

## 1. The seam, in one screen

Core, pin (`src/script/interpreter.cpp`):

```c
2045  if (flags & SCRIPT_VERIFY_WITNESS) {
2046    if (scriptPubKey.IsWitnessProgram(...)) {
2047      hadWitness = true;
2048      if (scriptSig.size() != 0) return WITNESS_MALLEATED;
2052      if (!VerifyWitnessProgram(..., /*is_p2sh=*/false)) return false;
2057      stack.resize(1);            // bare: bypass CLEANSTACK
...
2091      if (pubKey2.IsWitnessProgram(...)) {        // P2SH redeem script
2092        hadWitness = true;
2093        if (scriptSig != CScript() << redeem) return WITNESS_MALLEATED_P2SH;
2097        if (!VerifyWitnessProgram(..., /*is_p2sh=*/true)) return false;
2102        stack.resize(1);          // wrapped: bypass CLEANSTACK
...
2110  if ((flags & SCRIPT_VERIFY_CLEANSTACK) != 0) {
2115    if (stack.size() != 1) return CLEANSTACK;
```

Lean, pin (`Defs.lean`, `verifyScriptFull`, P2SH branch):

```lean
1412  let finalLen : Nat :=
1413    if flags.witness ∧ (isWitnessProgram spk).isSome then 1
1414    else
1415      -- non-witness P2SH: recompute the redeem-script eval length
...
1431  if pol.cleanstack ∧ finalLen ≠ 1 then .fail .cleanstack
```

`spk` is the **P2SH** scriptPubKey, so `isWitnessProgram spk = none` in the
wrapped arm and the `1` branch is never taken. The fallback recomputes the
redeem-script evaluation length; for a v0 witness program
(`OP_0 <20|32 bytes>`) that is **2**. Hence `finalLen = 2`, and with
`pol.cleanstack` the model rejects every valid P2SH-wrapped v0 witness spend.
The model's own `witnessUnexpected` tail four lines below already reads the
redeem-script shape, so the information needed for the correct value is
adjacent to the bug.

---

## 2. Exact witness (re-measured at `76dbfe5`)

All hex; `flags = {p2sh, witness}`, `pol = {cleanstack}`, accept-all
signature checker on both sides.

### W1 — P2SH-P2WPKH (divergent; 22-byte redeem script)

| field | value |
|---|---|
| scriptSig | `160014adfce54f529b2154e3c361bbe3f7d41db0635717` |
| scriptPubKey | `a914173727a17ada832a0fd90be6c628f63598b3400f87` |
| redeemScript | `0014adfce54f529b2154e3c361bbe3f7d41db0635717` |
| witness | `[ 300101 , 02 ‖ 11×32 ]` |
| Core | `verify=true, err=OK(0)` |
| pinned Lean | `FAIL Bitcoin.Interpreter.ExecError.cleanstack` |
| redeem eval length (Lean) | `2` |

### W2 — P2SH-P2WSH (divergent; one 1-byte witness item)

| field | value |
|---|---|
| scriptSig | `2200204ae81572f06e1b88fd5ced7a1a000945432e83e1551e6f721ee9c00b8cc33260` |
| scriptPubKey | `a91472c44f957fc011d97e3406667dca5b1c930c402687` |
| redeemScript | `00204ae81572f06e1b88fd5ced7a1a000945432e83e1551e6f721ee9c00b8cc33260` |
| witnessScript | `51` (OP_TRUE), `SHA256(0x51)` = the 32-byte program |
| witness | `[ 51 ]` |
| Core | `verify=true, err=OK(0)` |
| pinned Lean | `FAIL Bitcoin.Interpreter.ExecError.cleanstack` |

### Controls (same flags; all agree)

| tape | Core | pinned Lean |
|---|---|---|
| bare P2WPKH (`0014adfc…5717`), witness `[300101, 02‖11×32]` | ok | **ok** |
| plain P2SH, `scriptSig=0151`, redeem `51` | ok | **ok** |
| W1 with `pol.cleanstack=false` | ok | **ok** |
| W2 with `pol.cleanstack=false` | ok | **ok** |

Machine-readable: `witness/tape.json`.

**General bound (argument, not just these tapes).** On a valid wrapped spend
`witnessMalleatedP2SH` forces `scriptSig` to be exactly one push of the redeem
script, so `stackCopy = [redeem]`, `rest = []`. Any v0 witness-program redeem
script is exactly `<version push> <program push>`, two pushes, so its
evaluation always has length 2. Therefore `finalLen = 2 ≠ 1` for **every**
valid P2SH-wrapped v0 spend, and the model rejects all of them under
`CLEANSTACK`. The failure is independent of the witness contents.

---

## 3. Real Core at the pin (C side anchored on the actual interpreter)

`witness/run_core_probe.sh` compiles the **pristine** pinned
`src/script/interpreter.cpp`, `script.cpp`, `script.h` (extracted from git at
the pin; blob hashes recorded in the log) together with `pubkey`, hash and
cleanse units, and calls `VerifyScript` directly. The only stub is an
accept-all `BaseSignatureChecker` subclass — no interpreter logic is
rewritten. Raw output (`witness/core-probe.txt`):

```
tape=p2sh-p2wpkh    cleanstack=1 verify=true err=OK(0) ...
tape=p2sh-p2wsh     cleanstack=1 verify=true err=OK(0) ...
tape=p2sh-p2wpkh    cleanstack=0 verify=true err=OK(0) ...
tape=p2sh-p2wsh     cleanstack=0 verify=true err=OK(0) ...
tape=bare-p2wpkh    cleanstack=1 verify=true err=OK(0) ...
tape=bare-p2wpkh    cleanstack=0 verify=true err=OK(0) ...
tape=p2sh-plain     cleanstack=1 verify=true err=OK(0) ...
tape=p2sh-plain     cleanstack=0 verify=true err=OK(0) ...
```

## 4. Real Lean at the pin (L side executed on the same bytes)

`witness/run_lean_probe.sh` evaluates `verifyScriptFull 64` on the same tapes
(`lake env lean`, Lean 4.35.0). Raw output (`witness/lean-probe.txt`):

```
"spkWPKH isWitnessProgram = none"
"redeemWPKH isWitnessProgram = some (0, {...})"
"redeemWSH isWitnessProgram = some (0, {...})"
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

`p2shInner = OK` isolates the cause: witness verification succeeds, the model
still fails, so the failure is the `finalLen`/`pol.cleanstack` tail and
nothing else. The `cleanstack=false` rows prove signature/witness validity is
not involved.

---

## 5. Alive2 — full domain, pinned model (red, as required)

`alive2-pinned/run.sh`: Core excerpt (`src/c_core.cpp`, both `resize(1)`
sites) vs the pinned `finalLen` rule (`src/l_pinned.cpp`), eleven symbolic
inputs. Only script-shape (`¬(spk_wit ∧ spk_p2sh)`) and reachable-ok-path
(`st_n ≥ 1`, `inner_len ≥ 1` on the P2SH branch) restrictions are applied —
the divergent class is **not** fenced out. Raw (`alive2-pinned/result.txt`):

```
ERROR: Value mismatch

Example:
i64 noundef %cleanstack = 1
i64 noundef %witness = 1
i64 noundef %p2sh = 1
i64 noundef %st_n = 2
i64 noundef %spk_wit = 0
i64 noundef %spk_p2sh = 1
i64 noundef %redeem_wit = 1
i64 noundef %ss_push_ok = 1
i64 noundef %sig_n = 0
i64 noundef %wit_n = 0
i64 noundef %inner_len = 2

Source value: 1        (Core: pass)
Target value: 120      (pinned Lean: CLEANSTACK = 30 << 2)
STATUS=alive2-counterexample-as-expected
```

`inner_len = 2` is the value the concrete tapes actually produce (§2), so the
counterexample is not an artefact of an unreachable length. There is no
counterexample anywhere else in the domain: the sound-domain cell (§7) is
green over its whole domain, which includes the plain, native-witness and
plain-P2SH faces.

## 6. SAW — full domain, pinned model (C proves, L refuted)

`saw-pinned/` verifies both leaves against the **same** Cryptol table
(`core_arms`, the Core postcondition including the divergent class). Raw
(`saw-pinned/result.txt`):

```
Proof succeeded! probe_scr008                       <- Core leaf
...
  cleanstack: 1
  witness: 1
  p2sh: 1
  st_n: 2
  spk_wit: 0
  spk_p2sh: 1
  redeem_wit: 1
  ss_push_ok: 1
  sig_n: 0
  wit_n: 0
  inner_len: 3
Proof failed.                                        <- pinned Lean leaf
STATUS=saw-divergence-as-expected
```

SAW's refutation lands on the same class as Alive2's counterexample
(only the unconstrained `inner_len` differs: 3 vs 2; both are ≠ 1).

---

## 7. The fix closes it — and what a full cell would then be

`alive2-fixed/` and `saw-fixed/` use the same Core leaf and the same Cryptol
table, but the L leaf implements the minimal fix proposed by wave64/41 §8:

```lean
let redeemIsWitnessProgram : Bool :=
  match stackCopy with
  | [] => false
  | p :: _ => (isWitnessProgram p).isSome
let finalLen : Nat :=
  if flags.witness ∧ redeemIsWitnessProgram then 1
  else <existing non-witness recomputation>
```

i.e. key the resize off the P2SH **redeem** script (the script `p2shInner`
actually verifies) rather than the scriptPubKey. This is a *shadow* of the
proposed model; `spec/core/` is untouched.

With the fix, the full three-arm domain — plain script, native witness,
P2SH-wrapped witness, with `CLEANSTACK` on and off — is a single green
comparison:

```
Alive2: Transformation seems to be correct!   1 correct, 0 incorrect, 0 Alive2 errors
        STATUS=alive2-green
SAW   : Proof succeeded! probe_scr008  (x2)
        W65_SCR008_SAW_FIXED_GREEN
        STATUS=saw-green
```

So the row is **closable modulo one model line**, not modulo new harness work.
Everything needed for a full cell already exists; the missing piece is the
`Defs.lean` edit (plus re-elaborating `verifyScriptFull_cleanstack_fails`,
whose hypotheses never enter the P2SH arm, and re-running the cells that cite
`finalLen`). That edit is a model change with a pin consequence
(`PINS.lock [lean] model_rev`), which is outside this task's remit.

---

## 8. The sound cell that *is* available now

`spec/equiv/cells/exec-verify/C-L-w65-scr008-cleanstack-arms`
(`both-green`; `scr_row_coverage: partial`):

- L is a **faithful** transliteration of the pinned `finalLen`, including its
  `isWitnessProgram spk` test — no Core-shaped "fix" hidden in the L leg (the
  reason the older `C-L-verifyscript-tail` and `C-L-w32-cleanstack` cells
  cannot speak for the pinned model on this row).
- The declared domain (documented in `spec.md`, implemented once in
  `src/common.h`, called by both legs) excludes only:
  - `spk_wit ∧ spk_p2sh` (no script can be both shapes), and
  - `p2sh ∧ spk_p2sh ∧ witness ∧ redeem_wit ∧ cleanstack ∧ ss_push_ok`
    (the exact divergent set).
- Covered and green: plain script (`final depth = st_n`, all 0..3), native
  witness (`resize(1)`, CLEANSTACK cannot fire), plain P2SH
  (`final depth = inner_len`, all 0..3), P2SH-wrapped witness with
  `cleanstack = false`, and the wrapped arm under `cleanstack = true` when
  `ss_push_ok = false` (42 wins in both models) — plus the 41/42/43
  precedence.

Raw: `alive2/result.txt` `1 correct transformations / 0 incorrect / 0 Alive2
errors`; `saw/result.txt` two `Proof succeeded!`.

**Residual for SCR-008 (unchanged ledger state: `gap`):** the excluded set is
divergent, not unproved. SCR-008 stays `gap` until `Defs.lean:1412-1414` is
fixed and the full-domain probe/cell is re-run green against the new pin.

---

## 9. Exact commands and hashes

```sh
# everything, in order (needs /tmp/pcore01 and a built spec/core)
spec/equiv/findings/wave65/02-scr008-full-cell/reproduce.sh

# individually
CORE_SRC=/tmp/pcore01 spec/equiv/findings/wave65/02-scr008-full-cell/witness/run_core_probe.sh
spec/equiv/findings/wave65/02-scr008-full-cell/witness/run_lean_probe.sh
spec/equiv/findings/wave65/02-scr008-full-cell/alive2-pinned/run.sh    # expected red
spec/equiv/findings/wave65/02-scr008-full-cell/alive2-fixed/run.sh     # green
spec/equiv/findings/wave65/02-scr008-full-cell/saw-pinned/run.sh       # C green / L red
spec/equiv/findings/wave65/02-scr008-full-cell/saw-fixed/run.sh        # green
bash spec/equiv/cells/exec-verify/C-L-w65-scr008-cleanstack-arms/alive2/run.sh
bash spec/equiv/cells/exec-verify/C-L-w65-scr008-cleanstack-arms/saw/run.sh
```

Lean build prerequisite used here:

```sh
cd spec/core && lake build Bitcoin.Interpreter.Defs    # rc 0, 24 jobs
```

Primary artifact hashes (full list in `hashes.txt`; each leg also carries a
`certificate.sha256` over its tracked inputs plus `result.txt`):

```
00c5e7028f296019b226bd25e5ce1705af7cde45c64d0aacb6b5622f446e2c44  witness/core_probe.cpp      (identical to wave64/41)
9f048da2f79c239a884d49bdd6418e032b29d4c006a534042823e19bb47719f3  witness/lean_probe.lean     (identical to wave64/41)
27961d80a7991ad253608f9e6b069d4196854e94767a55537f1ace19941f26ef  witness/core-probe.txt
24bbad6423c3bd66b178e44c2761826ae69bcf3097e472e8253a91fb12068012  witness/lean-probe.txt
e6856689555a6375b353b266ad5c6e3be383527b1699f4694f6c07ce7fb2a303  witness/tape.json
8ea0a35f42af3c7bdae82926b301b680a3ddf8f5d3afbd9af38d052dbf43fa28  src/c_core.cpp
6400598063bea264e48b854c5e7815066fd97d1dab44041e83b4fea470583f83  src/l_pinned.cpp
bcac9e5167ccfcc52a97b8454ec9ff89400c1b65ca1921af40220aeb981cf533  src/l_fixed.cpp
```

The probe sources are byte-identical to wave64/41's, and `Defs.lean`'s blob is
unchanged, so this wave is an independent re-run, not a re-quote: the Core and
Lean outputs above were produced at `76dbfe5` by the commands shown.

---

## 10. Provenance / hygiene

- **Not touched:** `spec/core/**` (no model edit), `spec/equiv/PINS.lock`,
  `spec/equiv/contract/**`, `spec/db/**` (ledger, rules, residuals),
  `spec/equiv/results/**`, `spec/equiv/docs/**`, the shared twin/runtime, and
  every pre-existing cell. `spec/equiv/cells/exec-verify/C-L-w65-scr008-cleanstack-arms/`
  and `spec/equiv/findings/wave65/02-scr008-full-cell/` are new.
- **No ledger change.** SCR-008 remains `status: gap`; the new cell is not
  cited by `spec/db/equiv-cells.yaml` and claims `partial` coverage only.
- **No promotion.** Nothing here changes a row status, a matrix, or a pin.
- **Build outputs** (`build/`) are git-ignored, as in every other cell.
- **Scope.** `CLEANSTACK` is policy (`rules.yaml` SCR-008 `consensus: false`);
  with `cleanstack = false` both models agree, so this is a false rejection at
  the mempool/policy face, not a consensus split. The row's `flag` and `pol.`
  faces remain correct.

## 11. What was not done

- No `Defs.lean` change, no `p2shInner` refactor to carry a resize flag, no
  re-elaboration of `verifyScriptFull_cleanstack_fails` (all proposed only).
- No Lean proof of "every valid P2SH-wrapped v0 spend has inner length 2"
  (argued in §2 from `witnessMalleatedP2SH` and the v0 script shape; confirmed
  concretely for both program sizes).
- No P2SH-wrapped Taproot tape: `CLEANSTACK`/standard policy does not use it,
  and the v0 family already establishes the bound.
- No re-run of the whole cell suite (`make equiv` would rewrite every cell's
  `result.txt` and certificates; that is a shared-state change outside this
  task). Only the new cell's legs and the new probe legs were run.
