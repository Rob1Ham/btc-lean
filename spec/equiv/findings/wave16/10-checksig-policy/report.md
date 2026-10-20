# Wave 16 — `10-checksig-policy` report

**Branch:** `wave16/10-checksig-policy` (worktree cut from PR #29 head `805c804`)
**Family:** checksig · **Assigned rows:** SCR-102 … SCR-113
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`
**Contract:** v3 `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`
**Tools:** Alive2 v20.0 (Ubuntu LLVM 20.1.2), SAW 1.6 (`68eed5f release-1.6`),
clang/LLVM 20.1.2 (`/usr/bin/clang++-20`, `/usr/lib/llvm-20/bin`).
**Patches:** none. **R leg:** not attempted (F-HARNESS-002 / F-TOOL-001).

## Row disposition

| Row | Cell | Alive2 | SAW | Coverage |
|---|---|---|---|---|
| SCR-102 (strict DER, 9..73 B) | `checksig/C-L-checksig-der` | green 2/2 | green 4/4 | **full** |
| SCR-103 (BIP66 from height 363725) | `checksig/C-L-checksig-bip66` | green 3/3 | green 6/6 | **full** |
| SCR-104 (LOW_S, S ≤ n/2) | `checksig/C-L-checksig-lows` | green 1/1 | green 2/2 | **partial** |
| SCR-105 (hashtype byte ∈ {1,2,3} after masking) | `checksig/C-L-checksig-policy` | green 4/4 | green 8/8 | **full** |
| SCR-106 (33 B 02/03 or 65 B 04) | `checksig/C-L-checksig-policy` | green 4/4 | green 8/8 | **full** |
| SCR-107 (v0 witness pubkey compressed) | `checksig/C-L-checksig-policy` | green 4/4 | green 8/8 | **full** |
| SCR-108 (∅ signature bypasses DER) | `checksig/C-L-checksig-der` (`cell_der_gate`) | green 2/2 | green 4/4 | **full** |
| SCR-109 (CHECKSIG pushes FALSE on ∅ sig) | `checksig/C-L-checksig-empty` | green 3/3 | green 6/6 | **full** |
| SCR-110 (failed check, non-empty sig ⇒ NULLFAIL) | `checksig/C-L-checksig-nullfail-hashtype` | green 2/2 | green 4/4 | **full** |
| SCR-111 (ANYONECANPAY bit passed through) | `checksig/C-L-checksig-nullfail-hashtype` | green 2/2 | green 4/4 | **full** |
| SCR-112 (invalid pubkey ⇒ CHECKSIG false + continue) | `checksig/C-L-checksig-invalid-pubkey` | green 2/2 | green 4/4 | **partial** |
| SCR-113 (each op counts 1 toward 201) | `checksig/C-L-checksig-opcount` | green 1/1 | green 2/2 | **full** |

Totals: **10 rows full**, **2 rows partial**, 0 remaining gaps within the
assignment. 18 closed functions compared bidirectionally in Alive2; 36 SAW
proof obligations discharged.

## What each cell proves

All cells use the same harness shape: the C leg is a line-cited slice of
pinned Core, the L leg is a **reviewed transliteration** of the Lean model
(not `twin/gen.py` output), and the SAW lane verifies each leg independently
against a hand-written Cryptol predicate. Alive2 compares C (source) with L
(target) **bidirectionally** over all symbolic inputs.

- **der** — `cell_der` = strict BIP66 `IsValidSignatureEncoding`;
  `cell_der_gate` = `CheckSignatureEncoding` DERSIG arm over symbolic
  `dersig/lowS/strictEnc`, including the empty-signature bypass (SCR-108).
  673 symbolic bits.
- **bip66** — `GetBlockScriptFlags` DERSIG derivation: exception-class base
  flags, buried-deployment height compare (`>= 363725` on mainnet), and the
  non-clearing OR, over symbolic heights/flag words.
- **policy** — `IsDefinedHashtypeSignature` + STRICTENC gate (23),
  `IsCompressedOrUncompressedPubKey`/`IsCompressedPubKey` (29), and the
  WITNESS_PUBKEYTYPE v0 rule (44) in Core's order.
- **lows** — the 256-bit `s <= floor(n/2)` predicate (27) under LOW_S.
- **empty** — the empty-signature `OP_CHECKSIG` push-false, the
  `OP_CHECKSIGVERIFY` ordinal 14, the pubkey policy gates (29/44), the
  concrete `CheckECDSASignature` empty-signature short-circuit, and the
  `OP_NOT` continuation witness (10497). The verdict is proven independent
  of pubkey validity, so **no** same-crypto premise is used.
- **nullfail-hashtype** — the NULLFAIL guard (32) over its whole truth table,
  including precedence over ordinal 14, and the trailing-byte decode:
  `nHashType = vchSig.back()`, ACP = bit 0x80, base class = low 5 bits,
  bits 5..6 ignored.
- **invalid-pubkey** — invalid `CPubKey` ⇒ checker false before EC work ⇒
  CHECKSIG pushes false and a block continues; also the NULLFAIL interaction.
- **opcount** — eight symbolic opcodes from a symbolic start count: one
  increment per wire byte > 0x60 in base/witness-v0, error 7 on the 202nd,
  independent of the execution flag.

## Same-crypto statement

SCR-110 and the valid-key branch of SCR-112 take the ECDSA verdict as an
**arbitrary input** (`fSuccess`, `crypto_ok`). The cells prove the guards and
handler tails for every verdict; they do **not** prove that Core's
libsecp256k1-backed checker and the Lean `ScriptChecker` seam agree. That is
the premise of `spec/equiv/docs/DECISION-lax-ecdsa.md`, stated in every
affected `spec.md`/`notes.md`. No cell claims ECDSA, libsecp256k1, DER-lax
parsing, or SHA-256 verification. SCR-111 is structural (decode only) and
makes no digest claim (SCR-140/SWT-042 own that).

## Remaining partial coverage

- **SCR-104** (`C-L-checksig-lows`): the lax-DER S extraction and the
  `s >= n` overflow/reduction window (SGN-107 seam) are outside the cell, so
  only the canonical-scalar comparison is proved.
- **SCR-112** (`C-L-checksig-invalid-pubkey`): `CPubKey::IsValid`/`Set` is an
  unconstrained input rather than a computed byte parse; the valid-key branch
  rides the abstract EC verdict; no R leg. The existing
  `e3-checksig/C-L-checksig-dispatch` cell remains the ledger anchor and was
  not edited (out of write scope).

## Reproduction

From the repository root:

```sh
for c in der bip66 policy lows empty nullfail-hashtype invalid-pubkey opcount; do
  bash spec/equiv/cells/checksig/C-L-checksig-$c/alive2/run.sh
  bash spec/equiv/cells/checksig/C-L-checksig-$c/saw/run.sh
  sha256sum -c spec/equiv/cells/checksig/C-L-checksig-$c/alive2/certificate.sha256
  sha256sum -c spec/equiv/cells/checksig/C-L-checksig-$c/saw/certificate.sha256
done
```

All 16 certificates verified from the repository root after the final runs.
Each certificate covers the cell `spec.md`, lane scripts, harness sources
(`findings/wave16/10-checksig-policy/tools/`), `contract/error_kind.h`,
generated IR/bitcode, and the raw `result.txt`. Note: `build/` is gitignored
by `spec/equiv/.gitignore` (same as the existing e3 cells), so certificates
that hash generated IR verify in this worktree and after re-running the
lanes, not on a clean checkout.

## Tool notes / blockers

- **Alive2 v20 metadata ingestion:** attached `!tbaa`/`!alias.scope` nodes in
  this shape produce `ERROR: Unsupported metadata: N`. Both runners strip
  those optimizer hints identically from both legs before comparison; this is
  a tool-ingestion transform, recorded in each cell's notes.
- **SAW memory safety:** indexing the 80-byte buffer requires
  `sig_len <= 80`; the hashtype cell totalizes to 0 outside `[1,80]` before
  reading (both legs + Cryptol spec), so the buffer representation does not
  bound the proved byte domain.
- **SAW observable detail:** `st_finish` retains a one-element false stack
  (`2312`) rather than an empty one (`264`) after `OP_NOT` on a true value;
  the Cryptol predicate carries the retained element.
- No R leg: the pinned rbitcoin shim has no typed `ScriptError` and rejects
  `flags != 0` (F-HARNESS-002); Alive2 v20 cannot ingest the LLVM 22 R
  module (F-TOOL-001).
- No `make equiv`, ledger updater, mutations, or shared-file edits were run.

## Evidence hashes (sha256)

### `checksig/C-L-checksig-der`
```
044a52b0579497dbdf184e30bb57169258c1748235d10feab9c4c409d1319215  spec.md
1dfefd833bbf6e589bef08d0f2bc020252db08dcc4c0ffc3556638b60d12078e  alive2/result.txt
fc6238480a8c36db6b13828621789d0f643ca5c5dbee1039b3edbc96c19e7ab5  alive2/certificate.sha256
4afa00465c92698f736dfe69d69299fdbc53974b35fee96731258ff0505bea29  saw/result.txt
a1ec1dda434e34d09a39cb18e4d95650c1551a6af4b16eb88a6d81c78ff5529f  saw/certificate.sha256
```

### `checksig/C-L-checksig-bip66`
```
429d8592ee45111ecf2ad206fc1dc921226814f2406320610884d0988d4f9a93  spec.md
b070a537e16ba17f660a835c550d7fdd41abe2116a015fb8d4d7dfa9398bb862  alive2/result.txt
bf324fd7da1092f0665dc9c7ef25b34103afedec91a60720fa5bbb57d1686f7e  alive2/certificate.sha256
b2255cb2ed88d02cead887a3fbfa4a4b4132d91dfe456220009a15623ddc56c2  saw/result.txt
7f9c8757910cb2b2d10c253f726fb00d55527456eaa14b25c5b8a4927626c4be  saw/certificate.sha256
```

### `checksig/C-L-checksig-policy`
```
b1e156cd0ffd38f8aca1340aa8288740f18e91c62345b29dbfceb9dad56b5d4c  spec.md
ba9c6ae01624a761de06d0673152a528d9fe97d8399d562a5bbcdbb0ff9628d6  alive2/result.txt
4e05fb94177c4fe2d04cd60887db1604ebfa1ad838d799cc98a1ffdfc1d2f3ce  alive2/certificate.sha256
b846f9148a55f9009fe9b29b47ea0cc6893a1572eed39b5dd25bc2d40ad65288  saw/result.txt
ac482c105fac3e964cd0a0b2732a52724de26d060e50fda0932004b27538495e  saw/certificate.sha256
```

### `checksig/C-L-checksig-lows`
```
1eee5e1d31750b47d66448ea8192ee9c1fcee55de826b71357baf56d6d986907  spec.md
cf64b93e400f8d62c798d3a82e980db1876c004a4b6ac63c780c0a4d413815f2  alive2/result.txt
f665dd77fbc10cc93ebdd94622fcb9379919ae5f540615607d690e94e30bc622  alive2/certificate.sha256
c76a36241679197673a5a41b37a2bc614ee4a9c957eb69be5873f3f057f56028  saw/result.txt
83d28c6e36ab0b0856f19344a9e6ddb34133b751f1280b925f4d82da816087db  saw/certificate.sha256
```

### `checksig/C-L-checksig-empty`
```
06325ef7cb86c3a6c9bd34e662e48d7aba809c484d69e38ca770f3a8462e3c80  spec.md
180540a434e884458f9e967f21b83da6f044ae05e95513654029163bb823f341  alive2/result.txt
64f1e743ddf1a5e8db2f5573148dc22a76a66decb55b2923a257a6ee524a908c  alive2/certificate.sha256
3123909922efd1e83db5e9ec4b4128368e86964b8c131a78bedabce9d7c1ee23  saw/result.txt
3448dc6a0d37e026752ab92caaab8c4c5c60788aa7793e86633ac326e91cbac4  saw/certificate.sha256
```

### `checksig/C-L-checksig-nullfail-hashtype`
```
2579ad6197f7ea2bb1883472f48a822a9fa32f109bbd9caf5dfcd5c01a3574b8  spec.md
f68cd09a396226e000f6b8677160973ad6ced991f4e0a7cfb1137ac59fdfa83e  alive2/result.txt
09becd71c87aa3abf1a756f4ae4feecf6d40ece5138fcfd0df01c7e33f14b2c8  alive2/certificate.sha256
667014fdb75a867109111cf1bb85c151b4ff992521cabc1d767d0f0b587d56c3  saw/result.txt
c4a248c59ab791db85df2c2183d9fc9c30ddb819cd42dc349f903928212c15ff  saw/certificate.sha256
```

### `checksig/C-L-checksig-invalid-pubkey`
```
57f86e23ea3f05d7168eec731cb661d14d0d5837c7d2aa05902d90ecbe4c8bba  spec.md
4167b13bea9cb0e7921fb9e53ce775e5fa9b1265fe082bb6584082ffd68016a1  alive2/result.txt
e9fc1ba477559cd890f42716cda1cfe3e89c02c3ee0a1a345d36bbfb4a539ec5  alive2/certificate.sha256
5b456007da7aac6e0052be7780197d4ba6375b65ec0a2b16d20c9eac4044aaf2  saw/result.txt
3d993ef9bffe0276f93a41896d80a78ee230933a161e51055a5771005a2a29ae  saw/certificate.sha256
```

### `checksig/C-L-checksig-opcount`
```
ff97e92eeee35a1e1d3d2e205088a11f46651a7aeb92a56b2e9c5a06da5ad909  spec.md
7feeb52ba4c17ca6d9ccdf20de55c0cac2325f7170f839bd3a42d0866c117ae0  alive2/result.txt
3f1d91734ebb6cd3427d62c2def583d55aa626c7bf4ab62917838ed138296fbc  alive2/certificate.sha256
e575474b81a7f8f4eec936c80a8446d7f25cd762661a13d447e65a1d6e425d4d  saw/result.txt
f252515f2ee3d43659bd7c3a8fc0323c5edd38924984f81f3ccf36078e0e03e3  saw/certificate.sha256
```

## Files

New cells (all under `spec/equiv/cells/checksig/`):
`C-L-checksig-der`, `C-L-checksig-bip66`, `C-L-checksig-policy`,
`C-L-checksig-lows`, `C-L-checksig-empty` (extended in place),
`C-L-checksig-nullfail-hashtype`, `C-L-checksig-invalid-pubkey`,
`C-L-checksig-opcount`.

Shared harness: `spec/equiv/findings/wave16/10-checksig-policy/tools/`
(`cell_common.h`, `cell_stack.h`, `c_*`/`l_*` pairs, `stubs.cpp`,
`build.sh`, `run_alive2.sh`, `run_saw.sh`).

No shared ledger/docs/results/contract/twin/shims files were edited. The
orchestrator should update `spec/db/equiv-cells.yaml` for SCR-102..113 after
merge (SCR-109's existing cell id is reused; SCR-112 keeps the e3 cell as its
ledger anchor plus this supplement).
