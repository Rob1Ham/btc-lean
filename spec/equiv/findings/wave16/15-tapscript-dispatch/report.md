# Wave 16 / `15-tapscript-dispatch` — report

Pin `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`; PR head `805c804`;
contract `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`.
Branch `wave16/15-tapscript-dispatch`; all cells and this report are in the
single local commit at the branch tip (SHA in the task response and
`git log -1`). Reads `spec/db/equiv-cells.yaml`
(SCR-142..SCR-152) but does not edit the ledger or any shared file.

## Outcome

| row | disposition | cell | what is proved / what is missing |
|---|---|---|---|
| SCR-142 | **partial** (gap, tool-green) | `cells/tapscript/C-L-taproot-gate` | In-function taproot gate is total: flag off ⇒ silent success; flag on + empty witness ⇒ error 39; flag on + non-empty ⇒ continue. **Missing:** activation height 709632 / exception block 692261, which are caller-side flag assembly and have no height channel in `contract/tape.md`. |
| SCR-143 | **full both-green** | `cells/tapscript/C-L-taproot-annex` | Annex detection `n>=2 && last_len!=0 && last_byte0==0x50` and `dropLast` removal, total over 64-bit inputs. Annex hashing is not part of the row and is not claimed. |
| SCR-144 | **full both-green, conditional on P12** | `cells/tapscript/C-L-taproot-keypath` | Key-path arity (`stack_n==1`), checker call with `(sig, 32-byte key, TAPROOT=2, key_len=32)`, and exact verdict/error pass-through. BIP340/libsecp is the same-crypto premise; nothing here proves it. |
| SCR-145 | **full both-green** | `cells/tapscript/C-L-taproot-scriptpath-dispatch` | `33 <= size <= 4129 && (size-33)%32 == 0`, else ordinal 48; total u64 arithmetic. |
| SCR-146 | **blocked, no cell** | — | `ComputeTapleafHash` = `TaggedHash("TapLeaf", leaf_ver, CompactSize(script), script)` at `interpreter.cpp:1882-1885`. Needs SHA256 compression plus the BIP340 tagged-hash domain; no hash model at the leaf seam. |
| SCR-147 | **blocked, no cell** | — | `VerifyTaprootCommitment` at `interpreter.cpp:1910-1925`: `q.CheckTapTweak(p, merkle_root, control[0]&1)`, i.e. secp256k1 x-only tweak and parity. Pure EC; no EC model at the leaf seam. |
| SCR-148 | **full both-green** | `cells/tapscript/C-L-taproot-scriptpath-dispatch` | `(control[0]&0xfe)==0xc0` selects tapscript for exactly 0xc0/0xc1 and no other byte. Execution is SCR-153/155 and is not claimed. |
| SCR-149 | **full both-green** | `cells/tapscript/C-L-taproot-scriptpath-dispatch` | Unknown leaf versions succeed with the policy bit off and fail ordinal 35 with it on. Note: the row text names `DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM`, but the pinned leaf branch uses `DISCOURAGE_UPGRADABLE_TAPROOT_VERSION` (`interpreter.cpp:1995`); the cell proves the pinned behavior. |
| SCR-150 | **full both-green** | `cells/tapscript/C-L-taproot-scriptpath-dispatch` | v1 2-byte `4e73` (P2A) succeeds with no execution and does so *before* the upgradable policy flag; every other upgradable shape fails 34 with the flag set. |
| SCR-151 | **full both-green** | `cells/tapscript/C-L-taproot-scriptpath-dispatch` | v2..v16, wrong-size v1 and P2SH-wrapped v1 succeed (or fail 34 under policy); the v1-2 P2A shape is routed to SCR-150. |
| SCR-152 | **full both-green** | `cells/tapscript/C-L-tapscript-isopsuccess` | Exact byte set `{80,98,126-129,131-134,137-138,141-142,149-153,187-254}`, total over 64-bit inputs. OP_SUCCESS execution is SCR-153 and is not claimed. |

Tally: 8 rows full both-green (SCR-143, 144, 145, 148, 149, 150, 151, 152;
144 conditional on P12), 1 row partial (SCR-142), 2 rows blocked (SCR-146,
SCR-147). No row was promoted from a witness-only or success-only branch.

## Evidence

Five cells, ten tool attempts, all exit 0:

| cell | Alive2 | SAW |
|---|---|---|
| `C-L-taproot-gate` | 1 transformation correct, 0 incorrect, 0 errors | 2/2 proofs |
| `C-L-taproot-annex` | 2 transformations correct, 0 incorrect, 0 errors | 4/4 proofs |
| `C-L-taproot-keypath` | 1 transformation correct, 0 incorrect, 0 errors | 4/4 proofs (checker pinned to success and to ordinal 47) |
| `C-L-taproot-scriptpath-dispatch` | 3 transformations correct, 0 incorrect, 0 errors | 6/6 proofs |
| `C-L-tapscript-isopsuccess` | 1 transformation correct, 0 incorrect, 0 errors | 2/2 proofs |

Every cell has raw `alive2/result.txt`, `saw/result.txt` and
`alive2/certificate.sha256`, `saw/certificate.sha256`. The C legs are
line-cited source-excerpt slices at the pin; the L legs are reviewed
transliterations of the Lean definitions (the twin has no
`VerifyWitnessProgram` handler). SAW checks both legs against one shared
Cryptol statement written from the Core branch table, not from either C++
leg. Alive2 is bidirectional throughout.

Reproduce from the repository root:

```sh
for c in spec/equiv/cells/tapscript/*/; do
  bash "$c/alive2/run.sh" && bash "$c/saw/run.sh" || echo "FAIL $c"
done
sha256sum -c spec/equiv/cells/tapscript/*/alive2/certificate.sha256
sha256sum -c spec/equiv/cells/tapscript/*/saw/certificate.sha256
```

Observed validation:

- 10/10 `run.sh` exits 0; every `result.txt` carries `STATUS=alive2-green`
  or `STATUS=saw-green` and the expected proof/transformation counts; no
  `Proof failed`, no `0 incorrect transformations` violation, no `ERROR:`.
- 10/10 certificates verify with `sha256sum -c` from the repository root
  (paths are repo-root-relative and include `result.txt`).
- `python3 spec/equiv/results/scripts/update_ledger.py --check` reports
  `cells scanned: 22 (valid 22, malformed 0)` and derives exactly the nine
  ledger changes above. `--check` exits 1 by design because the shared ledger
  is intentionally left unedited; the orchestrator applies it after merge.

Tool versions: Ubuntu clang 20.1.2, Alive2/LLVM 20.1.2, SAW 1.6
(`68eed5f release-1.6`), Cryptol 3.6.

## Blockers in detail

### SCR-146 — TapLeaf tagged hash

`interpreter.cpp:1882-1885`:

```cpp
uint256 ComputeTapleafHash(uint8_t leaf_version, std::span<const unsigned char> script)
{
    return (HashWriter{HASHER_TAPLEAF} << leaf_version << CompactSizeWriter(script.size()) << script).GetSHA256();
}
```

Blocking feature: a full SHA256 compression function with the BIP340
`TapLeaf` tag prefix and `CompactSize` serialization. A leaf cell can
abstract the 32-byte hash equality, but that proves only the surrounding
branch, not the row's hash claim, so no cell is filed. Next action: a
hash-vector cell (pinned TapLeaf vectors) or a shipped, reviewed SHA256 model
under the same-hash premise; either is a different workstream than bounded
IR equivalence.

### SCR-147 — EC tweak and parity

`interpreter.cpp:1910-1925` (`VerifyTaprootCommitment`), ending in:

```cpp
return q.CheckTapTweak(p, merkle_root, control[0] & 1);
```

Blocking feature: secp256k1 x-only public-key tweak (`p + H(p||m)·G`), point
decompression/re-encoding and parity comparison. The leaf seam has no EC
model. Next action: treat `CheckTapTweak` as a single external same-crypto
symbol (same shape as the key-path checker) and prove argument/parity
plumbing, or supply a concrete BIP341 vector. That would still be conditional
on P12 and would not prove libsecp256k1.

### SCR-142 — activation context

The in-function gate is fully proved, but `709632`/`692261` are block-height
activation rules applied where `SCRIPT_VERIFY_TAPROOT` is assembled, outside
`VerifyWitnessProgram`. `contract/tape.md` carries no height or block context,
so the cell is explicitly `partial` and the ledger keeps the row `gap` (the
updater's `_partial_coverage` path).

## Scope / trust notes

- No Core patch (`patches: none` in every cell). No edits to
  `spec/db/equiv-cells.yaml`, `spec/equiv/results/**`, `docs/STATE.md`,
  `TRUST-BASE.md`, `README.md`, `PINS.lock`, `spec/db/rules.yaml`,
  `contract/**`, `twin/**` or `shims/**`.
- SCR-144 and any future SCR-147 cell are conditional on P12
  (`docs/DECISION-lax-ecdsa.md`): crypto is shared and abstract, not proved.
- Mutants are proposed in each `spec.md` but none was executed; no mutation
  result is claimed.
- The dispatch cell starts after a successful tapleaf commitment check; that
  precondition is precisely why SCR-146/147 are filed as blockers rather than
  silently absorbed.
