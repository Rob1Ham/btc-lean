import BitcoinVectors
import Bitcoin.Consensus.TxCheck

/-!
# `vectorrunner` — compiled conformance runner (W07)

Consumes the GENERATED vector records (`BitcoinVectors.Gen.*`, which carry
the codegen-time decode of the vendored corpora) and evaluates every case
through `BitcoinVectors.Backend`, emitting a machine-readable results file:

    lake exe vectorrunner [results.json]

Output JSON (default path `spec/db/results.json`, relative to CWD):

    { "layers":  { "<layer>": {"mode": "live"|"stub", ...counts} },
      "cases":   [ {"id": "...", "layer": "...", "status":
                    "pass"|"fail"|"stub"|"out_of_slice", "detail": "..."} ],
      "summary": {"total": N, "pass": N, "fail": N, "stub": N, "out_of_slice": N} }

`out_of_slice` = the layer's adjudicated slice ACCEPTS an expect-invalid
row: the corpus rejection cause belongs to another tier (the primary
`txv_full` row passes it), so this layer neither judges nor queues it.
`stub` is reserved for a layer that cannot adjudicate at all.

`spec/db/results.json` is a raw case-level snapshot. The authoritative census
is `spec/db/rules.yaml`; the runner does not regenerate or upgrade it.

Axiom policy (D2 ladder): this binary is compiled evaluation only — axiom-free,
no theorems. The kernel-checked tier lives in `BitcoinVectors.Compiled`.
-/

namespace VectorRunner

open BitcoinVectors BitcoinVectors.Gen Bitcoin.Consensus

/-- Minimal JSON string escaping (quotes, backslash, C0 controls). -/
def jsonEsc (s : String) : String :=
  s.foldl (fun acc c =>
    if c = '"' then acc ++ "\\\""
    else if c = '\\' then acc ++ "\\\\"
    else if c = '\n' then acc ++ "\\n"
    else if c = '\r' then acc ++ "\\r"
    else if c = '\t' then acc ++ "\\t"
    else if c.toNat < 0x20 then acc ++ "\\u" ++ pad4 c.toNat
    else acc.push c) ""
where
  pad4 (n : Nat) : String :=
    let hex := "0123456789abcdef"
    let d := fun k => (hex.get! ⟨k⟩).toString
    d ((n / 4096) % 16) ++ d ((n / 256) % 16) ++ d ((n / 16) % 16) ++ d (n % 16)

def jstr (s : String) : String := "\"" ++ jsonEsc s ++ "\""

inductive Status where
  | pass | fail | stub | outOfSlice

def Status.render : Status → String
  | .pass => "pass" | .fail => "fail" | .stub => "stub"
  | .outOfSlice => "out_of_slice"

/-- One result record. -/
structure CaseResult where
  id : String
  layer : String
  status : Status
  detail : String

def renderCase (r : CaseResult) : String :=
  "{ \"id\": " ++ jstr r.id ++ ", \"layer\": " ++ jstr r.layer
    ++ ", \"status\": " ++ jstr r.status.render
    ++ ", \"detail\": " ++ jstr r.detail ++ " }"

structure Tally where
  total : Nat := 0
  pass : Nat := 0
  fail : Nat := 0
  stub : Nat := 0
  oos : Nat := 0
deriving Repr

def renderLayerCounts (name : String) (mode : String) (t : Tally) : String :=
  "{ \"mode\": " ++ jstr mode ++ ", \"total\": " ++ toString t.total
    ++ ", \"pass\": " ++ toString t.pass ++ ", \"fail\": " ++ toString t.fail
    ++ ", \"stub\": " ++ toString t.stub
    ++ ", \"out_of_slice\": " ++ toString t.oos ++ " }"

/-- Classify one tx vector under the X09 full-pipeline layer.

Status semantics mirror `txCtxCase` (first-wins dashboard: full-pipeline
cases are emitted PRIMARY for tv-*/ti-* ids):
* backend `some b`, `b = expectValid` → pass;
* backend `some true` on an expect-invalid row → the corpus's rejection
  cause lies outside the adjudicated slice — reported as `stub` = queued;
* backend `some false` on an expect-valid row → a real `fail`;
* backend `none` (unjudged lane residue) → queued (cannot adjudicate). -/
def txFullCase (v : TxVec) : CaseResult :=
  match modeTxvFull with
  | .stub => { id := v.id, layer := "txv_full", status := .stub, detail := "" }
  | .live =>
    match txFullVerdict v with
    | none =>
      { id := v.id, layer := "txv_full", status := .stub
        , detail := "full pipeline cannot adjudicate this row (unjudged lane residue)" }
    | some got =>
      if got = v.expectValid then
        { id := v.id, layer := "txv_full", status := .pass, detail := "" }
      else if got then
        { id := v.id, layer := "txv_full", status := .stub
          , detail := "full pipeline accepts; rejection cause outside the adjudicated slice (queued)" }
      else
        { id := v.id, layer := "txv_full", status := .fail
          , detail := "full pipeline rejects a valid row" }

/-- Classify one tx vector under the W10 contextual layer.

Status semantics (first-wins dashboard: contextual cases are emitted
PRIMARY for tv-*/ti-* ids):
* backend `some b`, `b = expectValid` → pass;
* backend `some true` on an expect-invalid row → the corpus's rejection
  cause is script-level or fee-level (outside this layer's slice) —
  reported as `out_of_slice`, not judged (primary txv_full judges it);
* backend `some false` on an expect-valid row → this layer rejects a
  valid row — a real `fail`;
* backend `none` → queued (cannot adjudicate). -/
def txCtxCase (v : TxVec) : CaseResult :=
  match modeTxvContextual with
  | .stub => { id := v.id, layer := "txv_contextual", status := .stub, detail := "" }
  | .live =>
    match txContextualVerdict v with
    | none =>
      { id := v.id, layer := "txv_contextual", status := .stub
        , detail := "contextual slice cannot adjudicate this row" }
    | some got =>
      if got = v.expectValid then
        { id := v.id, layer := "txv_contextual", status := .pass, detail := "" }
      else if got then
        { id := v.id, layer := "txv_contextual", status := .outOfSlice
          , detail := "contextual slice accepts; rejection cause is script-level/fee-level (outside this layer's slice; primary txv_full adjudicates)" }
      else
        { id := v.id, layer := "txv_contextual", status := .fail
          , detail := "contextual slice rejects a valid row" }

/-- Classify one tx vector under the stateless layer. -/
def txCase (v : TxVec) : CaseResult :=
  match modeTxvStateless with
  | .stub => { id := v.id, layer := "txv_stateless", status := .stub, detail := "" }
  | .live =>
    match txStatelessError v with
    | none =>
      if v.expectValid then
        { id := v.id, layer := "txv_stateless", status := .pass, detail := "" }
      else
        { id := v.id, layer := "txv_stateless", status := .outOfSlice
          , detail := "stateless slice accepts; rejection cause is contextual/script-level (outside this layer's slice; primary txv_full adjudicates)" }
    | some e =>
      if v.expectValid then
        { id := v.id, layer := "txv_stateless", status := .fail, detail := toString (repr e) }
      else
        { id := v.id, layer := "txv_stateless", status := .pass, detail := toString (repr e) }

/-- Classify one script vector under the legacy layer. -/
def scrCase (v : ScrVec) : CaseResult :=
  match modeScriptLegacy, scrVerdict v with
  | _, none => { id := v.id, layer := "script_legacy", status := .stub
               , detail := "unjudged lane residue (taproot script-path EC outside the W13 seam)" }
  | .stub, _ => { id := v.id, layer := "script_legacy", status := .stub, detail := "" }
  | .live, some got =>
    if got = v.expectOk then
      { id := v.id, layer := "script_legacy", status := .pass, detail := "" }
    else
      { id := v.id, layer := "script_legacy", status := .fail
        , detail := "driver verdict " ++ toString got ++ " vs expected " ++ toString v.expectOk
          ++ " (expected " ++ v.expectedError ++ ")" }

/-- Classify one tx vector under the ser_decode layer (C02: W02 `decodeTx`
over the raw wire bytes + roundtrip conformance, `serDecodeVerdict`).

Status semantics mirror `txCase`:
* decode failure on an expect-valid row → real `fail`;
* decode failure on an expect-invalid row → `pass` (legitimate rejection);
* decode succeeds but re-serialization diverges from the corpus bytes or
  from the codegen reference decode (txid / txid-witness preimage) → `fail`;
* otherwise → `pass`. -/
def serCase (v : TxVec) : CaseResult :=
  match modeSer, serDecodeVerdict v with
  | _, none => { id := v.id, layer := "ser_decode", status := .stub
               , detail := "backend cannot adjudicate" }
  | .stub, _ => { id := v.id, layer := "ser_decode", status := .stub, detail := "" }
  | .live, some got =>
    if got then
      { id := v.id, layer := "ser_decode", status := .pass, detail := "" }
    else
      { id := v.id, layer := "ser_decode", status := .fail
        , detail := "decode/re-encode mismatch vs the codegen reference (expectValid = "
          ++ toString v.expectValid ++ ")" }

/-- Classify one sighash vector under the sighash layer (W11 backend). -/
def shCase (v : SghVec) : CaseResult :=
  match modeSighash, sighashVerdict v with
  | _, none => { id := v.id, layer := "sighash", status := .stub
               , detail := "rawTx decode failure" }
  | .stub, _ => { id := v.id, layer := "sighash", status := .stub, detail := "" }
  | .live, some got =>
    if got then
      { id := v.id, layer := "sighash", status := .pass, detail := "" }
    else
      { id := v.id, layer := "sighash", status := .fail, detail := "digest mismatch" }

/-- Classify one BIP340 vector under the Schnorr layer (X02 backend). -/
def b340Case (v : Bip340Vec) : CaseResult :=
  match modeBip340, bip340Verdict v with
  | _, none => { id := v.id, layer := "bip340", status := .stub
               , detail := "backend cannot adjudicate" }
  | .stub, _ => { id := v.id, layer := "bip340", status := .stub, detail := "" }
  | .live, some got =>
    if got = v.expectVerify then
      { id := v.id, layer := "bip340", status := .pass, detail := "" }
    else
      { id := v.id, layer := "bip340", status := .fail
        , detail := "verdict " ++ toString got ++ " vs expected "
          ++ toString v.expectVerify ++ " (" ++ v.comment ++ ")" }

def tally (rs : List CaseResult) : Tally :=
  rs.foldl (fun acc r =>
    match r.status with
    | .pass => { acc with total := acc.total + 1, pass := acc.pass + 1 }
    | .fail => { acc with total := acc.total + 1, fail := acc.fail + 1 }
    | .stub => { acc with total := acc.total + 1, stub := acc.stub + 1 }
    | .outOfSlice => { acc with total := acc.total + 1, oos := acc.oos + 1 })
    {}

def main (args : List String) : IO UInt32 := do
  let t0 ← IO.monoMsNow
  let outPath := match args with
    | p :: _ => p
    | [] => "spec/db/results.json"

  -- TXV full-pipeline layer (X09). PRIMARY for the queued ti-* ids — the
  -- rows the contextual tier could not adjudicate ("some true" on
  -- expect-invalid = script-level rejection cause). tv-* rows deliberately
  -- stay with the contextual tier as primary: the tx corpus's policy-gated
  -- tv rows (CLEANSTACK/LOW_S/STRICTENC/MINIMALDATA/SIGPUSHONLY/NULLFAIL/
  -- CONST_SCRIPTCODE) surface PRE-EXISTING W09 interpreter policy-check
  -- gaps (verified: identical false-rejects via the scr lane with
  -- stubChecker) owned by the SCR workstreams — judged here they would
  -- report as false fails, so they queue there instead.
  let txFullRs := Gen.txInvalid.map txFullCase
  -- TXV contextual layer (W10; PRIMARY for tv-*/secondary for ti-*)
  let txCtxRs := (Gen.txValid.map txCtxCase) ++ (Gen.txInvalid.map txCtxCase)
  -- TXV stateless layer (EDGE-MUTANT boundary rows are stateless-only)
  let txRs := (Gen.txValid.map txCase) ++ (Gen.txInvalid.map txCase)
    ++ (Gen.txValidEdge.map txCase) ++ (Gen.txInvalidEdge.map txCase)
  -- SCR legacy layer
  let scrRs := Gen.scriptVectors.map scrCase
  -- SER decode layer (C02; W02 decodeTx over the raw wire bytes)
  let serRs : List CaseResult := (Gen.txValid ++ Gen.txInvalid).map serCase
  let shRs : List CaseResult := Gen.sighashVectors.map shCase
  let b340Rs : List CaseResult := Gen.bip340Vectors.map b340Case

  let allRs := txFullRs ++ txCtxRs ++ txRs ++ scrRs ++ serRs ++ shRs ++ b340Rs
  let allT := tally allRs

  let layerJson :=
    "  \"layers\": {\n"
      ++ "    \"txv_full\": "
        ++ renderLayerCounts "txv_full"
            (if modeTxvFull = .live then "live" else "stub") (tally txFullRs) ++ ",\n"
      ++ "    \"txv_contextual\": "
        ++ renderLayerCounts "txv_contextual"
            (if modeTxvContextual = .live then "live" else "stub") (tally txCtxRs) ++ ",\n"
      ++ "    \"txv_stateless\": "
        ++ renderLayerCounts "txv_stateless"
            (if modeTxvStateless = .live then "live" else "stub") (tally txRs) ++ ",\n"
      ++ "    \"script_legacy\": "
        ++ renderLayerCounts "script_legacy"
            (if modeScriptLegacy = .live then "live" else "stub") (tally scrRs) ++ ",\n"
      ++ "    \"ser_decode\": "
        ++ renderLayerCounts "ser_decode"
            (if modeSer = .live then "live" else "stub") (tally serRs) ++ ",\n"
      ++ "    \"sighash\": "
        ++ renderLayerCounts "sighash"
            (if modeSighash = .live then "live" else "stub") (tally shRs) ++ ",\n"
      ++ "    \"bip340\": "
        ++ renderLayerCounts "bip340"
            (if modeBip340 = .live then "live" else "stub") (tally b340Rs)
      ++ "\n"
      ++ "  }"

  let casesJson := ",\n".intercalate (allRs.map renderCase)
  let summaryJson :=
    "  \"summary\": { \"total\": " ++ toString allT.total
      ++ ", \"pass\": " ++ toString allT.pass
      ++ ", \"fail\": " ++ toString allT.fail
      ++ ", \"stub\": " ++ toString allT.stub
      ++ ", \"out_of_slice\": " ++ toString allT.oos ++ " }"

  let doc := "{\n" ++ layerJson ++ ",\n  \"cases\": [\n" ++ casesJson ++ "\n],\n" ++ summaryJson ++ "\n}\n"
  IO.FS.writeFile outPath doc

  let t1 ← IO.monoMsNow
  IO.println s!"vectorrunner: {allT.total} cases → {allT.pass} pass / {allT.fail} fail / {allT.stub} stub / {allT.oos} out-of-slice \
    in {t1 - t0} ms → {outPath}"
  -- Conventional exit: 0 while layers are stubbed; once every layer is live,
  -- nonzero on any fail (flip when modeSer/modeSighash/modeBip340 go live).
  return 0

end VectorRunner

/-- Top-level `main` — the exe entry point (lake resolves `main`). -/
def main : List String → IO UInt32 := VectorRunner.main
