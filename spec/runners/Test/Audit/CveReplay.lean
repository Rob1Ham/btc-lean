import BitcoinVectors.Records
import BitcoinVectors.Backend
import Bitcoin.Consensus.TxCheck
import Test.Audit.CveReplayGen

/-!
# CVE replay driver (W16 red-team audit)

Replays historical Bitcoin consensus CVEs through the LIVE Lean backends
(`BitcoinVectors.Backend.txStatelessError` → `Bitcoin.Consensus.TxCheck.
checkTransaction`) and asserts each vector's expected verdict.

Vectors: `spec/vectors/cve/*.json` (provenance + expected rule IDs there).
The data module `Test.Audit.CveReplayGen` is GENERATED from those JSON files
by `spec/scripts/audit/cve_replay.py`, which also runs this driver:

    cd spec/runners
    lake env lean -o .lake/build/lib/lean/Test/Audit/CveReplayGen.olean
                 Test/Audit/CveReplayGen.lean
    lake env lean --run Test/Audit/CveReplay.lean

Output: one JSON line per case, then a summary line
`{"summary": {"total": N, "pass": N, "fail": N}}`. Exit code 0 iff all cases
replay to their expected verdict. Block-level CVEs whose hash primitives sit
behind the W13 seam (CVE-2012-2459) are replayed Python-side by the wrapper
and are NOT exercised here (stub-blocked; documented in the vector JSON).

Owner: W16 (red-team & conformance audit).
-/

namespace Test.Audit.CveReplay

open BitcoinVectors Bitcoin.Consensus _root_.CveReplay

def errName : Option TxCheckError → String
  | some .vinEmpty          => "vinEmpty"
  | some .voutEmpty         => "voutEmpty"
  | some .oversize          => "oversize"
  | some .voutNegative      => "voutNegative"
  | some .voutTooLarge      => "voutTooLarge"
  | some .txoutTotalTooLarge => "txoutTotalTooLarge"
  | some .inputsDuplicate   => "inputsDuplicate"
  | some .cbLength          => "cbLength"
  | some .prevoutNull       => "prevoutNull"
  | none                    => "OK"

def jstr (s : String) : String := "\"" ++ s ++ "\""

/-- Evaluate one replay case through the live backend. -/
def vecOf (c : CveCase) : TxVec :=
  { id := c.name, tx := c.tx, segwit := false,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false },
    policyFlags := "", expectValid := false, comment := "" }

def runCase (c : CveCase) : String × String :=
  let got := errName (txStatelessError (vecOf c))
  let ok := got == c.expected
  (jstr c.name ++ " " ++ jstr got
      ++ (if ok then " PASS" else " FAIL expected=" ++ jstr c.expected),
   if ok then "pass" else "fail")

def runAll : IO Unit := do
  let rows := cveCases.map runCase
  for (line, _) in rows do
    IO.println line
  let pass := rows.foldl (fun n r => n + (if r.2 == "pass" then 1 else 0)) 0
  IO.println ("{\"summary\": {\"total\": " ++ toString rows.length
    ++ ", \"pass\": " ++ toString pass ++ ", \"fail\": "
    ++ toString (rows.length - pass) ++ "}}")
  if pass != rows.length then
    throw <| IO.userError "cve-replay: at least one case diverged"

end Test.Audit.CveReplay

def main : IO Unit := Test.Audit.CveReplay.runAll
