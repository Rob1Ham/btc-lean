import Bitcoin.Capstone.Block
import Test.Audit.Cve2459Gen

/-!
# CVE-2012-2459 block-replay driver (X11, red-team round 2)

Runs the four fully-mined blocks of
`spec/vectors/cve/cve-2012-2459/blocks.json` through the LIVE capstone
validator `Bitcoin.Capstone.Block.validateBlock` and asserts:

1. **Per-case verdicts** — each case's validateBlock outcome (error
   reason via `CapError.reason`, or `OK`) equals the vector's expected
   verdict:
   * `base-even`  [cb, t1]                    → OK
   * `mut-even-dup-tail` [cb, t1, t1copy] under the base-even header
     → `bad-txnmrklroot` (the duplicated leaf pair changes the root:
     the merkle-ROOT-MISMATCH gate rejects — BLK-010);
   * `base-odd`   [cb, t1, t2]                → OK
   * `mut-odd-dup-tail` [cb, t1, t2, t2copy] under the base-odd header
     → `bad-txns-BIP30`. THE CVE-2012-2459 MUTANT: its merkle root is
     EQUAL to the base's (assert 2 below — the odd level's last-element
     duplication, BLK-008, folds the duplicate pair identically), so
     the root-mismatch gate alone would ACCEPT it. The Lean pipeline
     still rejects — via the BIP30 duplicate-outpoint gate in the W12
     fold. Core rejects EARLIER, at CheckBlock, via the `mutated` flag
     (`bad-txns-duplicate`, BLK-011 — planned in rules.yaml, see
     FIND-X11-001).
2. **The CVE property, computed in Lean with the REAL sha256d seam**:
   `merkleRootOfBlock` over the mutated odd-base tx list EQUALS the
   un-mutated twin's root (root-equality vulnerability present), while
   the even-base mutant's root DIFFERS (root-mismatch catches it).

Data: `Test.Audit.Cve2459Gen` is GENERATED from blocks.json by
`spec/scripts/audit/cve_replay.py`:

    cd spec/runners
    lake env lean -o .lake/build/lib/lean/Test/Audit/Cve2459Gen.lean \
        Test/Audit/Cve2459Gen.lean
    lake env lean --run Test/Audit/Cve2459.lean

Output: one JSON line per case + property lines, then
`{"summary": {"total": N, "pass": N, "fail": N}}` — exit 0 iff all pass.

Owner: X11 (red-team & conformance audit, round 2).
-/

namespace Test.Audit.Cve2459

open Bitcoin.Data Bitcoin.Capstone.Block Bitcoin.Capstone.Merkle
open Bitcoin.Serialization _root_.Cve2459

/-- validateBlock verdict as a string: `"OK"` or the Core reject reason. -/
def verdictOf (blk : ByteArray) (st : CapState) : String × Nat :=
  match validateBlock blk st with
  | .error e => (CapError.reason e, 0)
  | .ok rep => ("OK", rep.txs)

def jstr (s : String) : String := "\"" ++ s ++ "\""

/-- Decode a block for the merkle property probes (test infra: errors
yield the empty tx list, which only the property lines see). -/
def txsOf (blk : ByteArray) : List Tx :=
  match decodeBlock blk with
  | .error _ => []
  | .ok (_, txs) => txs

/-- The txid merkle roots of a case block and its un-mutated twin agree? -/
def rootsEqual (c : Cve2459Case) : Option Bool :=
  match c.twinBlock with
  | none => none
  | some twin =>
    some (bytesBEq (merkleRootOfBlock (txsOf c.block))
                   (merkleRootOfBlock (txsOf twin)))

def runCase (c : Cve2459Case) : String × String :=
  let st : CapState := ⟨c.height, c.prevHash, c.utxo⟩
  let (got, _) := verdictOf c.block st
  let ok := got == c.expected
  (jstr c.name ++ " " ++ jstr got
    ++ (if ok then " PASS" else " FAIL expected=" ++ jstr c.expected),
   if ok then "pass" else "fail")

def runAll : IO Unit := do
  -- 1. per-case validateBlock verdicts
  let rows := cve2459Cases.map runCase
  for (line, _) in rows do
    IO.println line
  -- 2. the CVE merkle properties (computed with the real hash seam)
  let mut props : List String := []
  for c in cve2459Cases do
    match c.rootEqual, rootsEqual c with
    | some want, some got =>
        let line := jstr s!"root-equality:{c.name}" ++ " " ++ jstr (toString got)
          ++ (if got == want then " PASS" else " FAIL")
        props := line :: props
    | _, _ => pure ()
  for line in props.reverse do
    IO.println line
  let propPass := props.foldl (fun n l => n + (if l.endsWith "PASS" then 1 else 0)) 0
  let pass := rows.foldl (fun n r => n + (if r.2 == "pass" then 1 else 0)) 0
  let total := rows.length + props.length
  let passN := pass + propPass
  IO.println ("{\"summary\": {\"total\": " ++ toString total
    ++ ", \"pass\": " ++ toString passN ++ ", \"fail\": "
    ++ toString (total - passN) ++ "}}")
  if passN != total then
    throw <| IO.userError "cve2459-replay: at least one case diverged"

end Test.Audit.Cve2459

def main : IO Unit := Test.Audit.Cve2459.runAll
