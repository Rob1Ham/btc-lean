# L2-TXV oracle pins

The oracle side of `../model.py` is a semantic port of the pinned Core
sources below.  Nothing is fetched at run time; the committed refs are
the evidence.

| Pin | File | sha256 | Lines used |
|---|---|---|---|
| cce32b16 | `spec/vectors/l2/inv/refs/tx_check.cpp.cce32b16` | `66ff205c2bb482133eb864968815158e3474554870ad64e6e795fe313d803ed5` | 19-68 (`CheckTransaction`) |
| cce32b16 | `spec/vectors/l2/inv/refs/tx_verify.cpp.cce32b16` | `45de31c846d87b202b46f1e314cbd07869c0b3e598cdc7b18342e2fe24de3fc0` | 23-43 (`IsFinalTx`), 45-121 (BIP68), 117-168 (legacy/P2SH/witness/cost), 170-220 (`CheckTxInputs`) |
| c50817fe | `spec/vectors/l2/swt/refs/script.cpp.c50817fe` | `210b1720acce295de54c6a08c76b97fa4cfe835f64e0ff7e0730c57ebebb8c55` | 159-205 (`GetSigOpCount`), 313+ (`GetScriptOp`) |
| c50817fe | `spec/vectors/l2/scr/refs/interpreter.cpp.c50817fe` | `57a6f328c7e6202f499e48366a86eb26e09c8ebb78e92eef7e839207230be333` | 2133-2182 (`WitnessSigOps`/`CountWitnessSigOps`) |

The two pins are the campaign pins recorded in
`spec/db/findings-edge/EDGE-DIFF2.md` §1: cce32b16 for the
block/consensus lane, c50817fe for the script lane.

`probe/lean_sigops_probe.lean` + `.out` is a read-only `#eval` probe of
the *actual* shipped Lean definitions (no build, no core edits):

```
20   p2shSigOpCount   P2SH redeem OP_2 CHECKMULTISIG     (Core: 2)
80   txSigOpCost      same input                          (Core: 8)
20   p2shSigOpCount   scriptSig OP_DUP then push(redeem)  (Core: 0)
20   witnessSigOps    P2WSH witnessScript OP_2 CMS        (Core: 2)
20   txSigOpCost      same input                          (Core: 2)
0    witnessSigOps    P2SH-P2WPKH                        (Core: 1)
0    txSigOpCost      P2SH-P2WPKH                        (Core: 1)
1000000  serTxSize    1-in/1-out tx, 999936-byte spk
4000003  txWeightL    same tx                             (Core stripped*4: 4000000)
some .oversize       checkTransaction                     (Core: none)
```
