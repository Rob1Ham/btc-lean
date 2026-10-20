---
# Cell limits/C-L-w32-p2sh-scriptsig
contract: f1841e36406389d6589c870da1f153ce6ddb0a5663ef0191f11cf15c7773c1c6
repo_head: 4d62a97e551082a69b13f495365bff0a903b0c99
pin: cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
legs: C, L
cell: limits/C-L-w32-p2sh-scriptsig
family: limits
tool_status: both-green (symbolic over the whole ABI; semantic scriptSig domain <= 4 bytes)
precondition: |
  - pure scriptSig function: no transaction, coin, flags, or stack input.  The
    caller is in the P2SH branch of `CScript::GetSigOpCount(const CScript&)`
    (`this->IsPayToScriptHash()` is true); the non-P2SH arm is a different
    branch of that function and is not this cell.
  - `w` packs the scriptSig bytes little-endian, byte i = (w >> 8*i) & 0xff;
    `len` is its byte count.  Domain: 0 <= len <= 4.
  - len > 4 returns the shared out-of-domain sentinel 0xffffffff from both
    legs and the Cryptol spec; it is proved identical but is outside the
    semantic claim.
postcondition: |
  - parse the whole scriptSig all-or-nothing.  A truncated length field or a
    payload past the end makes the call return 0; any decoded opcode above
    OP_16 (0x60) also makes it return 0.
  - otherwise take the final GetOp payload register (a push's data, cleared to
    empty by every non-push opcode, including OP_1..OP_16 and OP_RESERVED) and
    return the accurate static sigop count of that data's valid prefix:
    CHECKSIG/CHECKSIGVERIFY = 1; CHECKMULTISIG/CHECKMULTISIGVERIFY = the
    preceding OP_1..OP_16 value, else 20; a malformed push inside the data
    stops the count and keeps the prefix count.
  - C and L return the same uint32_t for every 64-bit `w` and 32-bit `len`,
    and both equal the independent Cryptol `p2shOps32`.
direction:
  - L ⊑ C
  - C ⊑ L
scr_rows: SCR-034
scr_row_coverage: >-
  full — every branch of the P2SH scriptSig arm is exercised symbolically:
  malformed/truncated scriptSig => 0; any opcode above OP_16
  (non-push-only) => 0; empty scriptSig => 0; push-only scriptSig whose last
  push is the redeem data, including OP_0/OP_1..OP_16 last pushes whose data
  register is empty, direct pushes of 0..3 bytes and PUSHDATA1/PUSHDATA2 last
  pushes; and the accurate count of the redeem data covering CHECKSIG = 1,
  CHECKMULTISIG = preceding OP_1..OP_16, else 20, plus a malformed prefix
  inside the redeem data.  The four-byte scriptSig bound is the cell domain,
  not a branch of the row; the out-of-domain sentinel is outside the semantic
  claim.  A direct push of more than three bytes cannot fit, so the largest
  redeem data reachable here is three bytes; all redeem-data counting branches
  are still reachable (e.g. `52 ae ac`).
patches: none
source_citations:
  - script.cpp:183-205 (CScript::GetSigOpCount(const CScript&))
  - script.cpp:186-201 (P2SH push-only loop; opcode > OP_16 => 0)
  - script.cpp:266-286 (CScript::IsPushOnly; opcode > OP_16)
  - script.cpp:313-360 (GetScriptOp; pvchRet cleared then assigned)
  - script.cpp:157-181 (CScript::GetSigOpCount(bool))
  - spec/core/Bitcoin/Interpreter/SigOps.lean:359-374 (pushOnlyLastData, p2shScriptSigOps)
  - spec/core/Bitcoin/Interpreter/SigOps.lean:132-155 (parseWirePrefix, scriptSigOpCount)
  - spec/core/Bitcoin/Interpreter/SigOps.lean:56-101 (sigOpStep)
  - spec/core/Bitcoin/Interpreter/Defs.lean:421-431 (parseWireFrom/parseWire)
  - spec/core/Bitcoin/Interpreter/Defs.lean:496 (isPushOnlyWire)
  - spec/core/Bitcoin/Script/Parser/Defs.lean:206-230 (getOpAux/getOp)
trust_note: >
  C is a line-cited source-excerpt slice of Bitcoin Core script.cpp at the pin,
  not the whole interpreter or transactor.  L is a reviewed transliteration of
  the Lean pushOnlyLastData / p2shScriptSigOps model (model_rev 4d62a97e).  The
  P2SH scriptPubKey test and the transaction/coin loop are outside the cell:
  the cell starts at the already-selected P2SH input.  The shared harness
  unpacks the ABI word, unrolls both walks to the four-byte bound, and applies
  the identical out-of-domain sentinel.  The sentinel 0xffffffff exceeds every
  possible in-domain count, so it cannot mask a disagreement.  No pin,
  contract, engine source, Lean proof, or crypto premise is changed.
---

# limits/C-L-w32-p2sh-scriptsig

Symbolic equivalence of Core's P2SH scriptSig sigop arm and the Lean model,
against an independent Cryptol specification, over the four-byte scriptSig
domain.

## Entry point

```c
extern "C" uint32_t cell_p2sh_sigops(uint64_t w, uint32_t len);
```

`w` packs the scriptSig bytes little-endian; `len` is the byte count.  Returns
`0xffffffff` for `len > 4`.

## What each tool proves

- **Alive2** (`alive2/run.sh`): the extracted C and L modules agree for every
  64-bit `w` and 32-bit `len`.  The runner guards the IR (no `alloca`, no
  `= external`, no `switch.table`) and requires `--always-verify` plus the
  exact summary counts.
- **SAW** (`saw/run.sh`): both modules are verified against
  `p2shOps32 w len` from `src/cell.cry` for every 64-bit `w` and 32-bit `len`;
  two proofs, solver `abc`.

## Row

**SCR-034** — malformed or non-push-only scriptSig returns zero; otherwise the
final push data's valid script prefix is counted accurately.

See `notes.md` for domain coverage, the redeem-data examples, and the
mutation sanity check.
