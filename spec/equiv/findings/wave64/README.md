# Wave64 evidence index

**Base:** `5946c02` (PR branch `equiv/llvm-three-leg`)  
**Contract:** `f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6`  
**Core pin:** `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66`

This directory records the wave-64 additive evidence. Integration is through
the PR branch only; the wave branches are local and are not pushed to `main`.
A cell promotes an SCR row only when both tools are green and its
`scr_row_coverage` is full for that row. Partial cells are evidence, not
promotions.

## Full rows added by wave64

| SCR | Cell | Evidence |
|---|---|---|
| SCR-072 | `control-flow/C-L-cltv-csv-nop` | Alive2 4/4; SAW 8/8; flag-off NOP, flag-on/empty contrast; mutants |
| SCR-074 | `stack-ops/C-L-arity` | 55-row (opcode, depth) census; Alive2 55/55; SAW 110/110; mutants |
| SCR-079 | `numeric/C-L-scriptnum-width` | Alive2 2/2; SAW 4/4; exact `SCRIPTNUM` ordinal 4 |
| SCR-080 | `numeric/C-L-numeric-default-4byte` | 7 call sites / 10 decode expressions; Alive2 7/7; SAW 14/14 |
| SCR-081 | `numeric/C-L-nmaxnum5` | CLTV/CSV width-5; Alive2 3/3; SAW 6/6; concrete vectors |
| SCR-082 | `numeric/C-L-scriptnum-sign` | Alive2 8/8; SAW 8/8 |
| SCR-083 | `numeric/C-L-w64-negzero` | Alive2 2/2; SAW 2/2 |
| SCR-084 | `numeric/C-L-scriptnum-signext-exception` | Alive2 2/2; SAW 4/4 |
| SCR-085 | `numeric/C-L-reinterpret-limit` | raw push vs numeric reinterpretation; Alive2 4/4; SAW 8/8 |
| SCR-093/095 | `hash-ops/C-L-hash-widths` | Alive2 10/10; SAW 20/20; SHA1 arm cell-local and same-hash conditional |
| SCR-116/117 | `checkmultisig/C-L-w32-cms-*` | CMS count/finddelete/loop cells; SCR-115 remains partial |

## Partial / seam evidence (no promotion)

| SCR | Evidence | Exact residual |
|---|---|---|
| SCR-005 | `exec-verify/C-L-w64-p2sh-subscript-leaf` | bounded P2SH subscript/EVAL_FALSE leaf; general EvalScript open |
| SCR-008 | `exec-verify/C-L-verifyscript-tail`, `C-L-w32-cleanstack`; `findings/wave64/41-div-w32-p2sh-cleanstack` | **demoted**: `F-DIV-W32-01` P2SH-wrapped witness CLEANSTACK divergence |
| SCR-021/040/044 | limit/weight cells | witness-stack/tx-weight contract context missing |
| SCR-043 | `findings/coverage/SCR-043-miniscript-bound.md` | inapplicable: miniscript/wallet constant, not an interpreter check |
| SCR-051 | `push-encoding/C-L-w32-num-callsites` | MINIMALDATA call-site leaf; twin cannot express flag-on sites |
| SCR-086 | `e2-numeric/C-L-w32-cms-getint-counts` | clamp identity proved; twin `OP_ROLL` symbolic-trip loop open |
| SCR-104 | `checksig/C-L-checksig-lows-numeric`; `findings/wave64/24-scr-104-low-s/` | numeric S-half proved; Core/Lean parse-compact and DER-shape divergences |
| SCR-112 | `findings/wave64/25-scr-112/`, `findings/wave64/60-cpubkey-validity/` | header-only Lean `isValidPubKey` vs Core length check (`pk=[0x02]`) |
| SCR-115 | `checkmultisig/C-L-w32-cms-counts` | partial CMS count coverage |
| SCR-133 | wave64/29 abstract-SHA256 cell (reported, not promoted) | comparison and hash plumbing proved under an uninterpreted shared SHA256 oracle; the SHA256 model itself is still absent, so the row stays gap |
| SCR-136 | `e4-witness/C-L-w32-p2wpkh-exec`; hash cells | HASH160 and EvalChecksig seams remain parametric |
| SCR-140 | `witness-v0/C-L-bip143-preimage-order`, `C-L-bip143-layout-bytemap` | byte order/amount proved; SHA256d and multi-byte CompactSize remain |
| SCR-142 | `tapscript/C-L-taproot-activation-gate`; `findings/wave64/32-scr-142/` | pin has no taproot height gate; tape lacks height/hash channel |
| SCR-146/147 | `findings/wave64/33-scr-146/`, `34-scr-147/` | tagged SHA256 / EC tweak remain same-crypto seams |
| SCR-153/154 | tapscript OP_SUCCESS/policy probes | full OP_SUCCESS/policy row not closed |
| SCR-167 | `tapscript/C-L-w64-tap-codesep-byteseq` | bounded 6-byte CODESEPARATOR/byte-sequence half; loop and pre-checks open |
| SCR-169 | tapscript SigMsg/annex probes | epoch/spend_type/annex hash not closed |
| SCR-172 | `disabled/C-L-w64-row172-flip` | one-byte context flip proved; arbitrary scan/push ordering open |
| SCR-175 | `policy-flags/C-L-flag-source`, `C-L-lows-policy`; wave64/40 source-separation cell (reported) | source/ordering proved; the row's cited `CheckSignatureEncoding` gate and DER/libsecp half remain blocked, so it is not promoted |

## Cross-cutting findings

- `41-div-w32-p2sh-cleanstack/`: `F-DIV-W32-01`; valid P2SH-P2WPKH/P2WSH
  spend accepted by Core, rejected by Lean with CLEANSTACK.
- `../wave16b/07-r-sanitize/EXTENSION-W64.md`: advisory off-pin R lane;
  214/351 functions translate after sanitization, 137 blocked by `sret`
  (57) + atomics (80); eight mutual refinements are SMT-backed, not a proof
  of the pinned artifact.
- `54-taproot-annex-control/`: bounded annex/control layout/parity evidence
  (Alive2 6/6, SAW 12/12) with no `scr_rows`; the TapLeaf/TapTweak hash and
  EC seams remain open.
- `25-scr-112/`, `60-cpubkey-validity/`: `F-DIV-004`; Lean header-only
  pubkey validity vs Core length check.
- `43-e5-getscriptop-progress/`: bounded `GetScriptOp` progress lemma;
  prototype only, no cell; `failure ⇒ end` is false and machine-disconfirmed.
- `44-e5-heap-refinement/`: bounded pinned B2 allocator/capacity model; no
  symbolic-`EvalScript` loop and no whole-function claim.
- `45-e5-exceptions-pcore01/`: P-CORE-01 remains PROPOSED; amended form
  preserves catches, but no green cell and no consensus claim.
- `47-mutations-e2/`: E2 required set 4/4 killed, including a model-site
  application at `twin/ops_ir.py`.
- `48-mutations-e3e4/`: E3 2/5, E4 3/5; required site pairing incomplete.
- `49-bip143-layout/`: shared SAW runner can print green after an
  unknown-function error; `update_ledger.py` classification hardened.
- `52-tool-nondeterminism/`: measured solver/flag variance; one Alive2 raw
  `-O1` control is vacuous (2 queries) and becomes incorrect after `opt -O2`
  (34 queries; native 64 vs 32); 118/141 Alive2 greens lack `--always-verify`
  and 114/141 SAW greens use `abc`. Evidence-quality follow-up, not a row
  re-adjudication.
- `59-lows-numeric/`: LOW_S numeric `S <= n/2` proved over all 2^256 S with an
  external secp acceptance seam; BIP66 S-field forms covered, whole-DER
  offset/length walk and libsecp internals open; no row promotion.
- `55-tapscript-opsuccess-symbolic/`: OP_SUCCESS prescan length <=8 both-green
  after `--keep-const-init`; exact Alive2 encoding bound N=16; arbitrary-length
  scan remains no-go.
- `05-scr-021/`: bounded 0..6 witness push-size/OP_SUCCESS scan; longer
  scripts and truncated-tail ordering remain open.
- `50-r-harness-typed-error/`: R typed-error shim proposal; off-pin, no R
  equivalence claim.
- `51-cert-repro-hardening/`: clean-checkout certificate replay; no cell-cert
  replay errors; hygiene warnings listed, not hidden.
- `53-abi-flags-015-016/`: independent flag-source/oracle audit; cells sound,
  but the ledger’s green is not tape/ABI-level coverage.
- `61-p2a-l-link/`: real generator-linked P2A L leg is buildable; hook is a
  handoff because `twin/runtime.inc` is hash-pinned by 21 cells / 42 certs.
