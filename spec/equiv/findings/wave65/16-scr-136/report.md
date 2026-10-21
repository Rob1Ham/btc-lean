# Wave 65 / 16 — SCR-136 P2WPKH oracle interface (Alive2 + SAW)

- **Task:** `wave65/16-scr-136`
- **Branch:** `wave65/16-scr-136`
- **Base:** `76dbfe5e42f8a337e41a7308158b0de078afafd9`
  (`docs(equiv): record final 164-cell make equiv pass`)
- **Cell commit:** `8789bb80e01e3695727ec29009ca5e178e415f95`
- **Date:** 2026-10-21
- **Mode:** new cell + this finding only. No edit to `spec/proofs/**`,
  `PINS.lock`, `contract/**`, `spec/db/**`, `results/**`, `docs/**`, shared
  twin/runtime, or any existing cell.
- **Verdict:** **both tools green.** Alive2 proves C ≡ L in both directions for
  both exports; SAW proves each of the 4 obligations against an independent
  Cryptol contract. SCR-136 is **full at this cell's scope**, conditional on the
  named same-hash/same-crypto oracle premise; the primitive implementations
  remain the residual.

---

## 1. What was added

`spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-oracle-v0/` — a bounded, loop-free
cell over the same five-op P2WPKH machine as
`e4-witness/C-L-w32-p2wpkh-exec`, with **two exports**:

| export | statement |
|---|---|
| `cell_p2wpkh_scr136` | total execution outcome `result(2) | error(6) << 2`, parametric in the hash `h0..h2` and the checker verdict `(ck_err, ck_ok)` |
| `cell_p2wpkh_seam` | the *argument word* a selected crypto seam receives, selected by symbolic `sel`/`k`, or the all-ones sentinel when that seam is not reached |

The second export is the new strength. The exec cell proved the outcome is
right for every oracle **value**; this cell additionally proves **what the
oracles are called with**:

| selector | transcript result |
|---|---|
| `sel 0, k` | word k of the HASH160 preimage = the pk witness item, masked to `pk_len` |
| `sel 4` | HASH160 preimage length = `pk_len` |
| `sel 5` | HASH160 output width = 20 |
| `sel 1, k` | word k of EvalChecksig's signature argument, masked to `sig_len` |
| `sel 2, k` | word k of EvalChecksig's pubkey argument, masked to `pk_len` |
| `sel 3, k` | word k of EvalChecksig's scriptCode = the whole 25-byte implied script |
| `sel 6 / 7 / 8` | EvalChecksig sig length / pubkey length / scriptCode length (25) |
| other / not reached | `0xffffffffffffffff` |

Selection follows execution order: hash seam before OP_EQUALVERIFY (so
`sel 0/4/5` do not require the hash to match), checksig seam only after
OP_EQUALVERIFY succeeds, arity (40) and item-size (6) before both. This
ordering is itself compared.

## 2. Exact commands and raw results

Run from the repository root. Toolchain on this host: Alive2
`Ubuntu LLVM version 20.1.2`, SAW `1.6 (68eed5f release-1.6)`, clang `20.1.2`,
z3 `4.8.12`.

```sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-oracle-v0/src/build.sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-oracle-v0/alive2/run.sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-oracle-v0/saw/run.sh
spec/equiv/cells/e4-witness/C-L-w32-p2wpkh-oracle-v0/src/matrix.sh
```

### Alive2 (both exports, bidirectional)

Command executed by the runner:
`alive-tv --bidirectional --smt-to=120000 build/c_<fn>.ll build/l_<fn>.ll`

```
===== cell_p2wpkh_scr136 =====
Transformation seems to be correct!
These functions seem to be equivalent!
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
===== cell_p2wpkh_seam =====
Transformation seems to be correct!
These functions seem to be equivalent!
  1 correct transformations
  0 incorrect transformations
  0 failed-to-prove transformations
  0 Alive2 errors
STATUS=alive2-green
```

Raw output: `alive2/result.txt`
(sha256 `1303beb9d07f24a16a96999c8072c77ff04274a0bf6140a26763f773d7bdb05d`).

### SAW (four obligations, solver z3)

```
Proof succeeded! cell_p2wpkh_scr136      (C)
Proof succeeded! cell_p2wpkh_scr136      (L)
Proof succeeded! cell_p2wpkh_seam        (C)
Proof succeeded! cell_p2wpkh_seam        (L)
STATUS=saw-green
```

Raw output: `saw/result.txt`
(sha256 `431ee194602049048624fb1ab264e310ad4facfdb683b9f46528a4c98f11d723`).
No `llvm_unsafe_assume_spec`, no override, no `unsafe_assume`.

### Leaf shape

`evidence/leaf-shape.txt`: no loop blocks and

```
[c:cell_p2wpkh_scr136] call/invoke=0 alloca=0
[c:cell_p2wpkh_seam]   call/invoke=0 alloca=0
[l:cell_p2wpkh_scr136] call/invoke=0 alloca=0
[l:cell_p2wpkh_seam]   call/invoke=0 alloca=0
```

## 3. Certificates and tracked-input hashes

Both certificates cover only git-tracked inputs plus the raw result (no
`build/**`), and `sha256sum -c` passes from the clean tree:

```
$ sha256sum -c .../alive2/certificate.sha256   # 10 lines OK
$ sha256sum -c .../saw/certificate.sha256      # 12 lines OK
```

| input | sha256 |
|---|---|
| `spec.md` | `af4d3dc9c6d3a840a85e8498d603cfd9857da91cadf0f51d8a380fc80b3bd34c` |
| `notes.md` | `2f17ec769384a2952a53c468313a1bab8e4e6831a6e7727521290faf680a3504` |
| `src/c_leaf.cpp` | `8833816ba4a961630c68cece78efc0d7552bf046ba0ff7dcd3b850b4f9e1e19e` |
| `src/l_leaf.cpp` | `48123cd869aa577bb0c963c9a87a1c663bc9ae5e00d6083c67c167383ebf7172` |
| `saw/spec.cry` | `91c957d64f1f1dc9e9cc2aa3e6d20de0c0f635ab8c250a1ec084bb3d18f55df0` |
| `saw/spec.saw` | `3c396576b2b7859729fb6fb197b51ab2e6b4066e436b7d02a4e1c4c49068ddc8` |
| `evidence/matrix.txt` | `8167a85f4c9751d05a1c9e9ec46972e090eecdf5264eca60436aa2891c53b194` |
| `evidence/leaf-shape.txt` | `18af2260a860cbe8b0768d3d8345f07ea605e924097bece5672d4ab801a233cd` |
| `alive2/result.txt` | `1303beb9d07f24a16a96999c8072c77ff04274a0bf6140a26763f773d7bdb05d` |
| `saw/result.txt` | `431ee194602049048624fb1ab264e310ad4facfdb683b9f46528a4c98f11d723` |
| `alive2/certificate.sha256` | `802cd0f8c244d69594d1c85aae398974440fb5742ed9fa31845347fd115a2d7f` |
| `saw/certificate.sha256` | `60cd11494c4d9f6336d90ea35f90bc1cd15c39bb4b28630c03f4e478b34abc98` |

No tracked, certificate-bound file contains a machine-local checkout path
(`/tmp/...`, `/home/...`, `file://`).

The concrete matrix (`evidence/matrix.txt`) has 11 outcome rows and 24
transcript rows, with eight independent asserts (preimage word = `0x21` when
only byte 32 is in range, past-length = 0, script word 0 =
`0x040302010014a976`, script word 3 = `0xac`, lengths 33/20/25, and `sel`
truncation).

## 4. Sub-obligation determination for SCR-136

SCR-136 is `interpreter.cpp:1952-1953` — the `DUP HASH160 <20> EQUALVERIFY
CHECKSIG` arm. Split into its actual obligations at the pin:

| sub-obligation | status in this workstream |
|---|---|
| dispatch by `program.size() == 20` / `witversion == 0` | **out of this cell:** SCR-135/SCR-137 (`e4-witness/C-L-w32-witness-v0-error-total`); `witversion=0` is a shared precondition of every v0 cell |
| witness arity `stack.size() == 2` → 40 | **covered here** (and in exec) |
| implied-script emission `76 a9 14 <program> 88 ac` | **covered** by `e4-witness/C-L-w32-p2wpkh-build`; re-derived here through the byte selector |
| `ExecuteWitnessScript` item cap → 6 | **covered here** |
| `GetScriptOp` decode of exactly 5 instructions, walk ends at 25 | **covered here** |
| per-op checks: push size, 201-op budget, disabled table | **covered here**; loop unrolled 5×, 1000-item stack guard unreachable at depth ≤ 4 |
| `OP_DUP` semantics | **covered here** |
| `OP_HASH160` dispatch **and** preimage/width interface | **covered as interface:** preimage = whole pk item, length `pk_len`, output 20. The hash function itself is the named seam (residual) |
| `OP_EQUALVERIFY` on 20-byte values → 12, before checksig | **covered here**, including the ordering |
| `OP_CHECKSIG` dispatch **and** `(sig, pk, scriptCode)` interface | **covered as interface:** stacktop(-2)/stacktop(-1), 25-byte scriptCode, no OP_CODESEPARATOR, WITNESS_V0 no FindAndDelete, exact lengths. The DER/hashtype/low-S/NULLFAIL/ECDSA decision is the named seam (residual) |
| `ExecuteWitnessScript` tail: cleanstack 30, CastToBool 2 | **covered here** |
| F-DIV-004 pubkey encoding divergence | **inherited through the free checker verdict, not discharged**; sound for any policy because `ck_err/ck_ok` are arbitrary |

So the only objects not proved are the two primitives the row is defined
against, plus the shared `witversion=0` precondition and F-DIV-004.

## 5. Negative controls (scratch, not committed)

Three one-line mutants of the L transcript arm, checked against the unmutated C
leg and against the shared contract:

| mutant | change | Alive2 | SAW |
|---|---|---|---|
| M1 | HASH160 preimage reads the program element instead of the duplicated pk item | `Transformation doesn't verify!`, `Value mismatch` (source `0`, target `3`) | `Proof failed`, cex `sel=0,k=0,pk_len=20` |
| M2 | scriptCode is the 20-byte program instead of the 25-byte script | `Value mismatch` (source `0x14a976`, target `0`) | `Proof failed`, cex `sel=3,k=2` |
| M3 | OP_EQUALVERIFY no longer aborts, so a checksig selector answers on mismatch | `Value mismatch` (source all-ones sentinel, target `0`) | `Proof failed`, cex `sel=2,k=3452028158` |

This shows the proof constrains the seam interface and the error ordering, not
just the final branch table.

## 6. Residual (honest non-claims)

1. **HASH160 is not computed.** `h0..h2` are universally quantified. The cell
   proves the preimage and width handed to the hash; it does not prove
   `CHash160(pk) = RIPEMD160(SHA256(pk))` (hash floor, SCR-093/SCR-133).
2. **EvalChecksig is not implemented.** `(ck_err, ck_ok)` are universally
   quantified. The cell proves the exact `(sig, pk, scriptCode)` arguments and
   lengths; it does not model DER/hashtype/low-S/NULLFAIL or ECDSA
   (E3/SCR-112).
3. **`witversion = 0`** is a shared v0 precondition; version/length dispatch is
   SCR-135/SCR-137.
4. **F-DIV-004** (Lean `isValidPubKey` header-only vs Core
   `CPubKey::ValidSize`) is inherited via the free verdict and not discharged.
5. Bounded representation: 20-byte element payload window, 72-byte pk / 80-byte
   sig transcript windows, pure byte selector instead of `std::vector`, fixed
   flags word. These are stated in `spec.md`; lengths, caps, ordinals and
   ordering are exact.

The `full` coverage claim is at cell scope under the same-crypto premise used
by `checksig/C-L-checksig-nullfail-hashtype` (SCR-110/111) and
`hash-ops/C-L-hash-widths` (SCR-093/SCR-095); it is not a claim that a concrete
hash or ECDSA implementation was proved.

## 7. Ledger projection (not applied)

`update_ledger.py --check` reports the shared ledger untouched and cleanly
derivable:

```
cells scanned: 165 (valid 165, malformed 0)
  - SCR-136: gap -> both-green (4 cell(s))
```

SCR-136 is derived from the four cells
`e4-witness/C-L-w32-p2wpkh-build`, `e4-witness/C-L-w32-p2wpkh-exec`,
`e4-witness/C-L-w32-p2wpkh-oracle-v0`, `witness-v0/C-L-p2wpkh-script`.
`spec/db/equiv-cells.yaml` was **not** written (the run was `--check` only), so
the orchestrator owns the promotion.

## 8. Files changed / tree state

Cell commit `8789bb80e01e3695727ec29009ca5e178e415f95` adds 16 files, all under
the new cell directory (4298 insertions, 0 deletions, no existing file
modified). Working tree is clean after the commit. This report is a separate
commit on the same branch.
