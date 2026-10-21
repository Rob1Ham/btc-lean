# SCR-142 — exact missing contract context for the 709632 pre-activation clause

Status: filed gap record (cell-local; no shared contract edit).
Cell that covers the pinned half: `tapscript/C-L-taproot-activation-gate`.
Pin: `cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66` (Bitcoin Core v32.99).

## The row sentence under test

> TAPROOT gate: with the flag, a v1-32 non-P2SH spend is not
> anyone-can-spend; without the flag it succeeds silently only pre-activation
> (height 709632, except block 692261)

The cell covers the gate and the exception block.  It cannot cover the
words "only pre-activation" as a height-gated TAPROOT bit, for the two
reasons below.

## 1. The pinned function has no TAPROOT height term

`validation.cpp:2249-2288` (`GetBlockScriptFlags`) at the pin:

```cpp
script_verify_flags flags{SCRIPT_VERIFY_P2SH | SCRIPT_VERIFY_WITNESS
                          | SCRIPT_VERIFY_TAPROOT};              // :2261
const auto it{consensusparams.script_flag_exceptions.find(hash)}; // :2262
if (it != ...end()) flags = it->second;                           // :2264
// then DERSIG / CLTV / CSV / NULLDUMMY OR-ed by buried height    // :2267-2285
```

* The TAPROOT bit is set **unconditionally** at every height.
* The only way it is cleared is a hit on the two hash-keyed
  `script_flag_exceptions` entries (`kernel/chainparams.cpp:115-118`).
* The four `DeploymentActiveAt` calls are all `BuriedDeployment` compares
  (`consensus/params.h:26-36`: HEIGHTINCB, CLTV, DERSIG, CSV, SEGWIT;
  `deploymentstatus.h:27-31`: `nHeight >= DeploymentHeight`).  None of them
  is TAPROOT, and none touches the TAPROOT bit.
* The comment at `:2259-2260` states the design: "always leave
  P2SH+WITNESS+TAPROOT on except for the two violating blocks."

The pin has retired the taproot BIP9 deployment:

* `consensus/params.h:38-44`: `DeploymentPos` contains only
  `DEPLOYMENT_TESTDUMMY`.
* `kernel/chainparams.cpp:132-137` (mainnet): only TESTDUMMY is populated,
  with `nStartTime = NEVER_ACTIVE`.
* The activation height 709632 survives only as a **comment**:
  `kernel/chainparams.cpp:125`,
  `MinBIP9WarningHeight = 711648; // taproot activation height + miner
  confirmation window` (711648 = 709632 + 2016).
* `research/w2-06-flags-activation.md` Appendix B.17 records the same
  history: 692261 = taproot exception (TAPROOT off), 709632 = taproot era
  (all seven flags).  It is the flag vector, not a pin function.

Consequence: at the pin, `taproot_on(hash, height)` is 1 for **every**
height unless `hash` is one of the two exception hashes, and both exception
blocks are below 709632 (170060 and 692261).  A v1-32 non-P2SH spend at
height 709631 revalidated under the pin gets TAPROOT **on** — the same as at
709632.  The historical pre-activation behaviour is therefore not a
property of any function in the pinned tree.

## 2. The tape has no flag-assembly channel

`spec/equiv/contract/tape.md`:

* §1: `equiv_entry(tx_bytes, tx_len, spk, spk_len, amount, input_index,
  flags, error_kind)` — there is no block height and no block hash.
* §5: `flags` is an arbitrary `uint64` mask supplied by the caller; the
  shims pass it verbatim ("no shim adds or removes a flag").
* §7: input domain constrains only the flag mask and the WITNESS/CLEANSTACK
  implications.

So a tape-level test can only exercise `VerifyWitnessProgram` with the flag
already decided.  It cannot exercise `GetBlockScriptFlags`, and it cannot
express "this transaction is in block 709631 vs block 709632".

## What the Lean tree already models (and why it is not a C leg)

`spec/core/Bitcoin/Activation/Taproot.lean` keeps the historical record:

* TPR-075: `taprootBip9Deployment` — bit 2, start 1619222400, timeout
  1628640000, threshold 1815, period 2016, `minActivation := 709632`
  (`Taproot.lean:44-51`).
* TPR-078: `deploymentActiveAt d height := d.minActivation ≤ height`
  (`Taproot.lean:133-137`), with `taproot_first_active` (709632 true) and
  `taproot_not_active_before` (709631 false).
* TPR-076: the taproot exception block has `taproot = false` at **any**
  height, keyed by hash (`Taproot.lean:95-107`).
* TPR-077: away from exceptions the base trio is on at **every** height
  (`Taproot.lean:112-130`).

This is a Verified Lean record, but it is explicitly *not* in the pin's
`mainnetDeployments` (`mainnetDeployments_no_taproot`, `Taproot.lean:68-79`).
There is no C source at cce32b168 that implements `deploymentActiveAt` for
TAPROOT, so a C leg for it cannot be line-cited at the pin.

## The exact missing context (two acceptable resolutions)

**(a) Tape-level block context (preferred if the harness is to carry this).**
A new `contract/tape.md` version adding, per input:

* `block_height: uint32` (the height of the block being validated), and
* `block_hash: bytes[32]` (the hash of that block),

plus a normative rule that the shim assembles `flags` by calling the pinned
`GetBlockScriptFlags(block_index, chainman)` before `VerifyScript` (or
accepts the assembled flags and records the two block fields for audit).
This makes the exception-vs-height question testable end-to-end.  It does
**not** by itself restore the 709632 gate: resolution (a) still yields
"TAPROOT on at every height except the two exceptions", because that is the
pinned code.

**(b) A second pin for the historical window (if the row must be proved as
history).** Cite a Core tree whose `Consensus::DeploymentPos` contains
`DEPLOYMENT_TAPROOT` with `min_activation_height = 709632` (the BIP341
speed-trial era) and build the C leg from that tree's
`GetBlockScriptFlags`/`DeploymentActiveAt`.  That gives a real C counterpart
to `Taproot.lean` TPR-078.  Such a cell must carry a **different pin** and
must not be presented as a cce32b168 result.

Until (a) or (b) is adopted, the honest row coverage is:

* `tapscript/C-L-taproot-activation-gate` — full for the pinned gate and the
  exception block, including the machine-checked fact that height 709631 and
  709632 are indistinguishable at this pin;
* the "only pre-activation" clause — **not representable** at cce32b168,
  because the function and the tape channel both do not exist.

## Files and lines cited

* `src/validation.cpp:2249-2288` (pinned tree)
* `src/kernel/chainparams.cpp:115-125,132-137` (pinned tree)
* `src/consensus/params.h:26-44` (pinned tree)
* `src/deploymentstatus.h:13-18,26-31,33-37` (pinned tree)
* `src/script/interpreter.cpp:1957-1969` (pinned tree)
* `spec/equiv/contract/tape.md:14-25,100-104`
* `spec/core/Bitcoin/Activation/Taproot.lean:29-51,68-79,95-152`
* `spec/core/Bitcoin/Activation/Flags.lean:69-76,127-128,145-157`
* `research/w2-06-flags-activation.md` §2.2, Appendix B.17
