import BitcoinVectors.Records

/-! # GENERATED FILE — do not hand-edit.
Regenerate: python3 spec/scripts/runners/codegen.py
Source corpus: spec/vectors/ (hash-pinned in spec/vectors/MANIFEST.sha256)
Owner: W07 (test-vector codegen + runner). -/

set_option maxRecDepth 65536
set_option maxHeartbeats 2000000

namespace BitcoinVectors.Gen
open BitcoinVectors Bitcoin.Data

/-! # EDGE-MUTANT corpus (spec/vectors/edge/) -/
/-! te = tx_invalid_edge (mutation-survivor killing rows),
    ve = tx_valid_edge (accept-side companions). rawTx NOT emitted
    (Records default empty = not ser_judged). -/

/-- ve-002: replication-built voutRange row (99994 vouts) — never a
list literal (elaboration/codegen blowup); weight = f(struct). -/
def edgeTx_ve_002 : Tx :=
  ⟨1, [{ prevout := ⟨bytes #[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], 4294967295⟩, scriptSig := ⟨bytes #[81,81,81,81,81]⟩, sequence := 4294967295 }], (List.range 99994).map (fun _ => ⟨1, ⟨bytes #[81]⟩⟩), 0, []⟩
/-- te-001: replication-built voutRange row (99994 vouts) — never a
list literal (elaboration/codegen blowup); weight = f(struct). -/
def edgeTx_te_001 : Tx :=
  ⟨1, [{ prevout := ⟨bytes #[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0], 4294967295⟩, scriptSig := ⟨bytes #[81,81,81,81,81,81]⟩, sequence := 4294967295 }], (List.range 99994).map (fun _ => ⟨1, ⟨bytes #[81]⟩⟩), 0, []⟩
/-- tx_valid_edge.json (EDGE-MUTANT): 3 cases. — entry 0000. -/
def txValidEdge_0000 : TxVec :=
  { id := "ve-000", tx := { version := 1, vin := [{ prevout := ⟨bytes #[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], 0⟩, scriptSig := ⟨bytes #[]⟩, sequence := 4294967295 }], vout := [{ value := 2100000000000000, scriptPubKey := ⟨bytes #[81]⟩ }, { value := 0, scriptPubKey := ⟨bytes #[81]⟩ }], locktime := 0, witness := [] }, segwit := false,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "", expectValid := true,
    comment := "EDGE-MUTANT ve-000 (FIND-W16-003 accept side) two outputs (MAX_MONEY, 0) summing to EXACTLY MAX_MONEY = 2100000000000000 sat: per-output in range AND cumulative",
    prevouts := [] }

/-- tx_valid_edge.json (EDGE-MUTANT): 3 cases. — entry 0001. -/
def txValidEdge_0001 : TxVec :=
  { id := "ve-001", tx := { version := 1, vin := [{ prevout := ⟨bytes #[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], 0⟩, scriptSig := ⟨bytes #[]⟩, sequence := 4294967295 }], vout := [{ value := 1, scriptPubKey := ⟨bytes #[81]⟩ }], locktime := 0, witness := [[bytes #[81]]] }, segwit := true,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "", expectValid := true,
    comment := "EDGE-MUTANT ve-001 (FIND-W16-001 accept side) NON-empty vin, segwit framing (wire ver 01000000 | 00 01 | nvin 01 | prevout 32x01 n=00 ss=empty seq=ffffffff | nv",
    prevouts := [] }

/-- tx_valid_edge.json (EDGE-MUTANT): 3 cases. — entry 0002. -/
def txValidEdge_0002 : TxVec :=
  { id := "ve-002", tx := edgeTx_ve_002, segwit := false,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "", expectValid := true,
    comment := "EDGE-MUTANT ve-002 v3 (FIND-W16-002 accept side, post-FIX-TS04) bad-txns-oversize AT the exact bound: te-001's structure with the 5-byte scriptSig (s=5) = base ",
    prevouts := [] }

/-- tx_valid_edge.json (EDGE-MUTANT): 3 cases. — full corpus list. -/
def txValidEdge : List TxVec := [
  txValidEdge_0000,
  txValidEdge_0001,
  txValidEdge_0002
]

/-- tx_invalid_edge.json (EDGE-MUTANT): 4 cases. — entry 0000. -/
def txInvalidEdge_0000 : TxVec :=
  { id := "te-000", tx := { version := 1, vin := [], vout := [{ value := 1, scriptPubKey := ⟨bytes #[81]⟩ }], locktime := 0, witness := [] }, segwit := true,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "", expectValid := false,
    comment := "EDGE-MUTANT te-000 (FIND-W16-001) bad-txns-vin-empty: vin=[] is wire-representable via the BIP144 marker path (ver 01000000 | marker 00 | flag 01 | nvin 00 | nv",
    prevouts := [] }

/-- tx_invalid_edge.json (EDGE-MUTANT): 4 cases. — entry 0001. -/
def txInvalidEdge_0001 : TxVec :=
  { id := "te-001", tx := edgeTx_te_001, segwit := false,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "", expectValid := false,
    comment := "EDGE-MUTANT te-001 v3 (post-FIX-TS04 918df3c) bad-txns-oversize at the exact +4 mutant boundary: 1 coinbase-shape input (null prevout, 6-BYTE scriptSig 51x6), 9",
    prevouts := [] }

/-- tx_invalid_edge.json (EDGE-MUTANT): 4 cases. — entry 0002. -/
def txInvalidEdge_0002 : TxVec :=
  { id := "te-002", tx := { version := 1, vin := [{ prevout := ⟨bytes #[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], 0⟩, scriptSig := ⟨bytes #[]⟩, sequence := 4294967295 }], vout := [{ value := 2100000000000001, scriptPubKey := ⟨bytes #[81]⟩ }], locktime := 0, witness := [] }, segwit := false,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "", expectValid := false,
    comment := "EDGE-MUTANT te-002 (FIND-W16-003) bad-txns-vout-toolarge at the exact per-output boundary: 1 output of MAX_MONEY+1 = 2100000000000001 sat. checkTransaction = so",
    prevouts := [] }

/-- tx_invalid_edge.json (EDGE-MUTANT): 4 cases. — entry 0003. -/
def txInvalidEdge_0003 : TxVec :=
  { id := "te-003", tx := { version := 1, vin := [{ prevout := ⟨bytes #[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1], 0⟩, scriptSig := ⟨bytes #[]⟩, sequence := 4294967295 }], vout := [{ value := 2100000000000000, scriptPubKey := ⟨bytes #[81]⟩ }, { value := 1, scriptPubKey := ⟨bytes #[81]⟩ }], locktime := 0, witness := [] }, segwit := false,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "", expectValid := false,
    comment := "EDGE-MUTANT te-003 (FIND-W16-003 companion) bad-txns-txouttotal-toolarge at the exact cumulative boundary: 2 outputs (MAX_MONEY, 1) summing to MAX_MONEY+1 - per",
    prevouts := [] }

/-- tx_invalid_edge.json (EDGE-MUTANT): 4 cases. — full corpus list. -/
def txInvalidEdge : List TxVec := [
  txInvalidEdge_0000,
  txInvalidEdge_0001,
  txInvalidEdge_0002,
  txInvalidEdge_0003
]

end BitcoinVectors.Gen
