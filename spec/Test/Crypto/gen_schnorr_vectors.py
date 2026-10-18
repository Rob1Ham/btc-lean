#!/usr/bin/env python3
"""gen_schnorr_vectors.py — BIP340: emit spec/Test/Crypto/SchnorrTest.lean from
the official BIP340 corpus (spec/data/bips/bip-0340_test-vectors.csv).

Preserves each vector's CSV `comment` (what it exercises) as a Lean
docstring, per the BIP340 brief ("each vector has a comment explaining what
it exercises — preserve that mapping").

Usage: python3 spec/Test/Crypto/gen_schnorr_vectors.py
"""
import csv, pathlib

HERE = pathlib.Path(__file__).resolve().parent
CSV = HERE / ".." / ".." / "data" / "bips" / "bip-0340_test-vectors.csv"

rows = list(csv.DictReader(CSV.open()))
assert len(rows) == 19, f"expected 19 official vectors, got {len(rows)}"

def lean_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

entries = []
for r in rows:
    idx = int(r["index"])
    comment = (r.get("comment") or "").strip()
    entries.append(f"""  -- vector {idx}: {comment if comment else "(canonical accept case)"}
  ({lean_str(f"b340-{idx:02d}")}, {r["verification result"].strip().lower() == "true"},
    {lean_str(r["public key"])}, {lean_str(r["message"])}, {lean_str(r["signature"])}),""")

body = "\n".join(entries)

out = f"""import Bitcoin.Crypto.Schnorr.Verify
import Bitcoin.Data.Basic

/-!
# BIP340 conformance harness (GENERATED — do not hand-edit)

Run: `bash spec/Test/Crypto/run_schnorr.sh`.
Generator : spec/Test/Crypto/gen_schnorr_vectors.py
Corpus    : spec/data/bips/bip-0340_test-vectors.csv — ALL 19 official
            BIP340 vectors (9 accept / 10 reject), each with its official
            `comment` preserved as the docstring stating what it exercises.
Semantics : Bitcoin.Crypto.Schnorr.Verify.verifyImpl — BIP340 verification
            over the ECDSA-lax raw-Nat curve layer (Curve.Secp liftX/addP/mulP).
Checked by: compiled runtime execution (`main` below) — deliberately NOT
            kernel/native_decide through the WF-recursive mulP/expM (ECDSA
            §5 finding: decide cannot reduce WF-recursive defs).

Vector → property map (from the official comments):
  0–4    accept: canonical cases incl. 32-byte-all-zero msg (0), max
         values (3), sig with s < n/2 boundary shape (4)
  5      reject: public key not on the curve
  6      reject: has_even_y(R) is false
  7      reject: negated message
  8      reject: negated s value
  9,10   reject: sG − eP is infinite (x(inf) interpreted as 0 / 1)
  11     reject: sig[0:32] is not an X coordinate on the curve
  12     reject: sig[0:32] is equal to field size (r = p)
  13     reject: sig[32:64] is equal to curve order (s = n)
  14     reject: public key exceeds the field size (x = p)
  15–18  accept: message of size 0 / 1 / 17 / 100 (msg NOT size-gated)
-/

namespace Bitcoin.Test.Crypto.SchnorrVectors

open Bitcoin.Crypto.Schnorr.Verify Bitcoin.Data

set_option maxRecDepth 100000

/-- Parse a hex string into a ByteArray (test infra only). -/
def hexDigitVal (c : Char) : Option Nat :=
  let n := c.toNat
  if 48 ≤ n ∧ n ≤ 57 then some (n - 48)
  else if 97 ≤ n ∧ n ≤ 102 then some (n - 87)
  else if 65 ≤ n ∧ n ≤ 70 then some (n - 55)
  else none

def fromHex (s : String) : ByteArray :=
  go s.toList ByteArray.empty
where
  go : List Char → ByteArray → ByteArray
    | [], acc => acc
    | [_], acc => acc
    | a :: b :: rest, acc =>
        match hexDigitVal a, hexDigitVal b with
        | some hi, some lo => go rest (acc.push ((hi * 16 + lo).toUInt8))
        | _, _ => go (b :: rest) acc

/-- `name`, `expected`, pubkey hex, msg hex, sig hex. -/
def vectors : List (String × Bool × String × String × String) :=
  [
{body}
  ]

/-! ## IO harness: the official vectors through `verifyImpl` -/

def runVectors : IO Unit := do
  let mut fails := 0
  for (name, expected, pkH, msgH, sigH) in vectors do
    let got := verifyImpl (fromHex sigH) (fromHex pkH) (fromHex msgH)
    if got != expected then
      fails := fails + 1
      IO.println s!"FAIL {{name}}: expected {{expected}}, got {{got}}"
  let nTrue := (vectors.filter (fun v => v.2.1)).length
  IO.println s!"BIP340: {{vectors.length}} official vectors ({{nTrue}} accept / {{vectors.length - nTrue}} reject), FAILURES {{fails}}"
  if fails > 0 then throw (IO.userError "BIP340 conformance failures")

end Bitcoin.Test.Crypto.SchnorrVectors

/-- Runner entry (root `main` for `lake env lean --run`). -/
def main : IO Unit := Bitcoin.Test.Crypto.SchnorrVectors.runVectors
"""

(HERE / "SchnorrTest.lean").write_text(out)
print(f"wrote SchnorrTest.lean with {len(rows)} vectors")
