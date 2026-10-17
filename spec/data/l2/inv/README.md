# `inv` — end-to-end CheckTransaction-class invariants (L2-INV)

Seeded differential battery over the repo's transaction-invariant stack
vs pinned Bitcoin Core `cce32b16`.

- `driver/run_inv.py` — generator (seed default `20261017`), oracle
  evaluation, Lean dispatch, `.l2r` writer.
- `driver/oracle_txcheck.py` — Core port: `CheckTransaction`,
  `CheckTxInputs`, `IsFinalTx`, `CalculateSequenceLocks` /
  `EvaluateSequenceLocks`.
- `refs/` — verbatim Core `tx_check.cpp` / `tx_verify.cpp` at the pin.
- `lean/L2InvRunner.lean` — DUT side over
  `Bitcoin.TxValidation.Interface`.
- `cases/inv_cases.txt` — 530 `k=v|k=v|…` cases.
- `results/inv_rc26.l2r` — canonical result rows
  `id|got_ok|got_err|want_ok|want_err|declared`.

Run:

```bash
cd <checkout>/spec
INV_SEED=20261017 python3 vectors/l2/inv/driver/run_inv.py
python3 scripts/l2/l2_harness.py --class inv
```

## Case grammar

Line fields (missing field = empty):

```
id kind version locktime vin vout witness height mtp spendH csv prev prevdata blockH blockT
vin   = hashspec@n@sequence@scriptspec ; …
vout  = value@scriptspec ; …
witness = stack ; …        stack = itemspec + …
prev  = value@coinHeight@isCoinbase ; …     (one per input, `inputs` kind)
prevdata = coinHeight@parentMTP ; …          (one per input, `seq` kind)
scriptspec / hashspec / itemspec = token[,token…]; token = h:<hex> | z:<n> | p:<n>
```

`z:<n>` and `p:<n>` are run-length fills (0x00 / 0x51), which keeps the
4,000,000-byte boundary cases small. `-` means an empty script.

`kind` selects the checked law: `stateless` → `checkTransaction`,
`inputs` → `checkTxInputs`, `final` → `isFinalTx`, `seq` →
`sequenceLocksOk`. Output strings are Core's exact reject reasons;
successful input checks emit `OK:<fee>`, finality emits
`FINAL`/`NOTFINAL`, sequence locks emit `LOCKS-OK`/`LOCKS-FAIL`.

See `spec/db/findings-edge/L2-INV.md` for results and findings
(F-L2INV-001/002: witness-vs-stripped size gate and unconditional BIP144
framing).
