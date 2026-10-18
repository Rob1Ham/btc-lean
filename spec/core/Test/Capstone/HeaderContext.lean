import Bitcoin.Capstone.Block
import Bitcoin.Block.Params

/-!
Executable R04 regressions. The valid public-path control is real mainnet
block 1 (215 bytes, header hash 00000000839a8e6886ab5951d76f411475428afc90947ee320161bbf18eb6048),
retrieved from https://blockstream.info/api/block/00000000839a8e6886ab5951d76f411475428afc90947ee320161bbf18eb6048/raw.
SHA256 of the complete raw fixture: 9c192c128fac3ded236ffed725ae19b3ecef7828e09ed9e633d2e5370550dae0.

The retarget-height cases relabel a parent-index fixture to isolate the
current candidate gate. They are conditional model tests, not a claim that
such a parent index is a reachable mainnet history. Caller-provided historical
chain validity is the ChainContext input-state contract.
-/
namespace Test.Capstone.HeaderContext

open Bitcoin.Data Bitcoin.Chain Bitcoin.Block.Params Bitcoin.Block.Pow
open Bitcoin.Capstone.Block Bitcoin.Capstone.Pow Bitcoin.Capstone.Context

private def block1 : ByteArray := List.toByteArray [
    0x01, 0x00, 0x00, 0x00, 0x6f, 0xe2, 0x8c, 0x0a, 0xb6, 0xf1, 0xb3, 0x72, 0xc1, 0xa6, 0xa2, 0x46, 0xae, 0x63, 0xf7, 0x4f,
    0x93, 0x1e, 0x83, 0x65, 0xe1, 0x5a, 0x08, 0x9c, 0x68, 0xd6, 0x19, 0x00, 0x00, 0x00, 0x00, 0x00, 0x98, 0x20, 0x51, 0xfd,
    0x1e, 0x4b, 0xa7, 0x44, 0xbb, 0xbe, 0x68, 0x0e, 0x1f, 0xee, 0x14, 0x67, 0x7b, 0xa1, 0xa3, 0xc3, 0x54, 0x0b, 0xf7, 0xb1,
    0xcd, 0xb6, 0x06, 0xe8, 0x57, 0x23, 0x3e, 0x0e, 0x61, 0xbc, 0x66, 0x49, 0xff, 0xff, 0x00, 0x1d, 0x01, 0xe3, 0x62, 0x99,
    0x01, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0xff, 0xff,
    0xff, 0xff, 0x07, 0x04, 0xff, 0xff, 0x00, 0x1d, 0x01, 0x04, 0xff, 0xff, 0xff, 0xff, 0x01, 0x00, 0xf2, 0x05, 0x2a, 0x01,
    0x00, 0x00, 0x00, 0x43, 0x41, 0x04, 0x96, 0xb5, 0x38, 0xe8, 0x53, 0x51, 0x9c, 0x72, 0x6a, 0x2c, 0x91, 0xe6, 0x1e, 0xc1,
    0x16, 0x00, 0xae, 0x13, 0x90, 0x81, 0x3a, 0x62, 0x7c, 0x66, 0xfb, 0x8b, 0xe7, 0x94, 0x7b, 0xe6, 0x3c, 0x52, 0xda, 0x75,
    0x89, 0x37, 0x95, 0x15, 0xd4, 0xe0, 0xa6, 0x04, 0xf8, 0x14, 0x17, 0x81, 0xe6, 0x22, 0x94, 0x72, 0x11, 0x66, 0xbf, 0x62,
    0x1e, 0x73, 0xa8, 0x2c, 0xbf, 0x23, 0x42, 0xc8, 0x58, 0xee, 0xac, 0x00, 0x00, 0x00, 0x00]

private def ctx (now : Int := 1231469665) : ChainContext :=
  { parentHeight := 0, headerAt := fun n => if n = 0 then some genesisHeader else none,
    nodeTime := now }

private def publicReason (context : ChainContext) (height : UInt32 := 1) : String :=
  match validateBlockInContext block1
      { height := height, prevHash := headerHash genesisHeader, utxo := [] } context with
  | .ok _ => "ok"
  | .error e => e.reason

private def reportContext (contextual : Bool) : String :=
  let st : CapState := { height := 1, prevHash := headerHash genesisHeader, utxo := [] }
  let result := if contextual then validateBlockInContext block1 st ctx else replayBlock block1 st
  match result with
  | .ok report => toString report.headerContextChecked
  | .error e => e.reason

private def header : BlockHeader :=
  { genesisHeader with time := 1231469665 }

private def helperReason (context : ChainContext) (h : BlockHeader := header)
    (height : UInt32 := 1) (parent : ByteArray := headerHash genesisHeader) : String :=
  match checkHeaderContext context height parent h with
  | .ok _ => "ok"
  | .error e => e.reason

private def medianResult (context : ChainContext) (height : Nat) : String :=
  match medianTimePastStrict context height with
  | .ok t => toString t.toNat
  | .error e => e.reason

private def boundaryContext : ChainContext :=
  { parentHeight := 2015,
    headerAt := fun _ => some genesisHeader,
    nodeTime := 1231469665 }

private def missingContext : ChainContext :=
  { parentHeight := 11,
    headerAt := fun n => if n = 11 then some genesisHeader else none,
    nodeTime := 1231469665 }

private def publicChecks : List (String × String × String) :=
  [("public valid block with its real genesis parent", publicReason ctx, "ok"),
   ("public node-clock plus 7200 boundary", publicReason (ctx (1231469665 - 7200)), "ok"),
   ("public node-clock plus 7201 rejects", publicReason (ctx (1231469665 - 7201)), "time-too-new"),
   ("public expected retarget bits reject a difficulty-1 candidate",
     publicReason boundaryContext 2016, "bad-diffbits"),
   ("public sparse MTP history is unavailable", publicReason missingContext 12, "context-missing-ancestor"),
   ("public parent height must match candidate", publicReason ctx 2, "context-height-mismatch"),
   ("public missing parent is unavailable", publicReason { ctx with headerAt := fun _ => none },
     "context-missing-ancestor")]

private def helperChecks : List (String × String × String) :=
  [("timestamp equals parent MTP rejects", helperReason ctx { header with time := genesisHeader.time }, "time-too-old"),
   ("timestamp one above parent MTP", helperReason ctx { header with time := genesisHeader.time + 1 }, "ok"),
   ("wrong non-boundary bits", helperReason ctx { header with bits := 0x1c3fffc0 }, "bad-diffbits"),
   ("wrong index parent hash", helperReason ctx header 1 ByteArray.empty, "context-parent-mismatch"),
   ("retarget exact quarter-timespan clamp", helperReason boundaryContext
     { header with bits := 0x1c3fffc0 } 2016, "ok"),
   ("missing retarget anchor is unavailable", helperReason
     { boundaryContext with headerAt := fun n => if n = 0 then none else some genesisHeader }
     header 2016, "context-missing-ancestor"),
   ("wrong bits precede unresolved MTP", helperReason missingContext { header with bits := 0x1c3fffc0 }
     12, "bad-diffbits"),
   ("strict MTP has upper median for an even genesis window", medianResult
     { ctx with parentHeight := 1, headerAt := fun n => if n ≤ 1 then some ({ genesisHeader with time := (if n = 0 then 10 else 20) } : BlockHeader) else none } 1, "20"),
   ("strict MTP requires an internal missing height", medianResult
     { ctx with parentHeight := 10, headerAt := fun n => if n = 5 then none else some genesisHeader } 10,
     "context-missing-ancestor"),
   ("strict MTP stops at genesis without requiring negative heights", medianResult ctx 0, "1231006505"),
   ("signed node time does not wrap to a large UInt32", helperReason (ctx (-1)), "time-too-new"),
   ("Core height range does not wrap", helperReason { ctx with parentHeight := 4294967295 }
     header 0, "context-height-mismatch")]

def run : IO UInt32 := do
  let checks := publicChecks ++ helperChecks ++
    [("contextual report records header coverage", reportContext true, "true"),
     ("replay report records absent header coverage", reportContext false, "false"),
     ("missing context is unavailable, not a consensus rejection",
       toString (CapError.context (.missingAncestor 5)).isUnavailable, "true"),
     ("bad difficulty is a rejection, not unavailable context",
       toString (CapError.context .badDiffbits).isUnavailable, "false")]
  let results ← checks.mapM fun (name, actual, expected) => do
    let ok := actual == expected
    IO.println s!"[{if ok then "PASS" else "FAIL"}] {name}: expected={expected}, actual={actual}"
    return ok
  return if results.all id then 0 else 1

end Test.Capstone.HeaderContext

def main : IO UInt32 := Test.Capstone.HeaderContext.run
