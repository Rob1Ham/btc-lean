import Bitcoin.Data.Tx
import Bitcoin.Data.Basic

/-! # GENERATED FILE — do not hand-edit.
Regenerate: python3 spec/scripts/audit/cve_replay.py
Source: spec/vectors/cve/*.json (provenance + expected rule IDs there)
Owner: W16 (red-team & conformance audit). -/

namespace CveReplay
open Bitcoin.Data

abbrev bytes (a : Array UInt8) : ByteArray := ByteArray.mk a

def txOf_cve_2010_overflow_reconstructed : Tx := { version := 1, vin := [{ prevout := ⟨bytes #[189,140,93,27,52,129,3,152,39,121,169,248,229,1,7,187,106,86,63,114,122,31,84,181,97,119,80,177,99,15,227,42], 0⟩, scriptSig := ⟨bytes #[]⟩, sequence := 4294967295 }], vout := [{ value := 9223372036854277039, scriptPubKey := ⟨bytes #[0,20]⟩ }, { value := 9223372036854277039, scriptPubKey := ⟨bytes #[0,20]⟩ }], locktime := 0, witness := [] }
def txOf_cve_2018_dup_input_reconstructed : Tx := { version := 1, vin := [{ prevout := ⟨bytes #[14,117,77,28,138,220,211,143,76,29,142,92,143,126,107,48,235,15,90,42,92,30,159,141,124,107,90,73,56,39,22,80], 0⟩, scriptSig := ⟨bytes #[]⟩, sequence := 4294967295 }, { prevout := ⟨bytes #[14,117,77,28,138,220,211,143,76,29,142,92,143,126,107,48,235,15,90,42,92,30,159,141,124,107,90,73,56,39,22,80], 0⟩, scriptSig := ⟨bytes #[]⟩, sequence := 4294967295 }], vout := [{ value := 200000000, scriptPubKey := ⟨bytes #[0,20,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]⟩ }], locktime := 0, witness := [] }

/-- (id, tx, expected error) triples for the driver. -/
structure CveCase where
  name : String
  tx : Tx
  expected : String

def cveCases : List CveCase :=
  [  { name := "cve-2010-5139:overflow-reconstructed", tx := txOf_cve_2010_overflow_reconstructed, expected := "voutTooLarge" },
  { name := "cve-2018-17144:dup-input-reconstructed", tx := txOf_cve_2018_dup_input_reconstructed, expected := "inputsDuplicate" }]

end CveReplay
