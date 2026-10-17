import BitcoinVectors.Records

/-! # GENERATED FILE — do not hand-edit.
Regenerate: python3 spec/scripts/runners/codegen.py
Source corpus: spec/vectors/ (hash-pinned in spec/vectors/MANIFEST.sha256)
Owner: W07 (test-vector codegen + runner). -/

set_option maxRecDepth 65536
set_option maxHeartbeats 2000000

namespace BitcoinVectors.Gen
open BitcoinVectors

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0000. -/
def scriptVectors_0000 : ScrVec :=
  { id := "sc-0000", scriptSig := bytes #[],
    scriptPubKey := bytes #[116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Test the test: we should have an empty stack after scriptSig evaluation" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0001. -/
def scriptVectors_0001 : ScrVec :=
  { id := "sc-0001", scriptSig := bytes #[],
    scriptPubKey := bytes #[116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "and multiple spaces should not change that." }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0002. -/
def scriptVectors_0002 : ScrVec :=
  { id := "sc-0002", scriptSig := bytes #[],
    scriptPubKey := bytes #[116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "    | DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0003. -/
def scriptVectors_0003 : ScrVec :=
  { id := "sc-0003", scriptSig := bytes #[],
    scriptPubKey := bytes #[116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "     | DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0004. -/
def scriptVectors_0004 : ScrVec :=
  { id := "sc-0004", scriptSig := bytes #[81,82],
    scriptPubKey := bytes #[82,136,81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Similarly whitespace around and between symbols" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0005. -/
def scriptVectors_0005 : ScrVec :=
  { id := "sc-0005", scriptSig := bytes #[81,82],
    scriptPubKey := bytes #[82,136,81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1  2 | 2 EQUALVERIFY 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0006. -/
def scriptVectors_0006 : ScrVec :=
  { id := "sc-0006", scriptSig := bytes #[81,82],
    scriptPubKey := bytes #[82,136,81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "  1  2 | 2 EQUALVERIFY 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0007. -/
def scriptVectors_0007 : ScrVec :=
  { id := "sc-0007", scriptSig := bytes #[81,82],
    scriptPubKey := bytes #[82,136,81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1  2   | 2 EQUALVERIFY 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0008. -/
def scriptVectors_0008 : ScrVec :=
  { id := "sc-0008", scriptSig := bytes #[81,82],
    scriptPubKey := bytes #[82,136,81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "  1  2   | 2 EQUALVERIFY 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0009. -/
def scriptVectors_0009 : ScrVec :=
  { id := "sc-0009", scriptSig := bytes #[81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | " }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0010. -/
def scriptVectors_0010 : ScrVec :=
  { id := "sc-0010", scriptSig := bytes #[2,1,0],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "all bytes are significant, not only the last one" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0011. -/
def scriptVectors_0011 : ScrVec :=
  { id := "sc-0011", scriptSig := bytes #[9,0,0,0,0,0,0,0,0,16],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "equals zero when cast to Int64" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0012. -/
def scriptVectors_0012 : ScrVec :=
  { id := "sc-0012", scriptSig := bytes #[1,11],
    scriptPubKey := bytes #[91,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "push 1 byte" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0013. -/
def scriptVectors_0013 : ScrVec :=
  { id := "sc-0013", scriptSig := bytes #[2,65,122],
    scriptPubKey := bytes #[2,65,122,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x417a | 'Az' EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0014. -/
def scriptVectors_0014 : ScrVec :=
  { id := "sc-0014", scriptSig := bytes #[75,65,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122],
    scriptPubKey := bytes #[75,65,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,122,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "push 75 bytes" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0015. -/
def scriptVectors_0015 : ScrVec :=
  { id := "sc-0015", scriptSig := bytes #[76,1,7],
    scriptPubKey := bytes #[87,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x4c is OP_PUSHDATA1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0016. -/
def scriptVectors_0016 : ScrVec :=
  { id := "sc-0016", scriptSig := bytes #[77,1,0,8],
    scriptPubKey := bytes #[88,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x4d is OP_PUSHDATA2" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0017. -/
def scriptVectors_0017 : ScrVec :=
  { id := "sc-0017", scriptSig := bytes #[78,1,0,0,0,9],
    scriptPubKey := bytes #[89,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x4e is OP_PUSHDATA4" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0018. -/
def scriptVectors_0018 : ScrVec :=
  { id := "sc-0018", scriptSig := bytes #[76,0],
    scriptPubKey := bytes #[0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x4c 0x00 | 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0019. -/
def scriptVectors_0019 : ScrVec :=
  { id := "sc-0019", scriptSig := bytes #[77,0,0],
    scriptPubKey := bytes #[0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x4d 0x0000 | 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0020. -/
def scriptVectors_0020 : ScrVec :=
  { id := "sc-0020", scriptSig := bytes #[78,0,0,0,0],
    scriptPubKey := bytes #[0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x4e 0x00000000 | 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0021. -/
def scriptVectors_0021 : ScrVec :=
  { id := "sc-0021", scriptSig := bytes #[79,2,232,3,147],
    scriptPubKey := bytes #[2,231,3,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x4f 1000 ADD | 999 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0022. -/
def scriptVectors_0022 : ScrVec :=
  { id := "sc-0022", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,80,104,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x50 is reserved (ok if not executed)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0023. -/
def scriptVectors_0023 : ScrVec :=
  { id := "sc-0023", scriptSig := bytes #[81],
    scriptPubKey := bytes #[95,147,96,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x51 through 0x60 push 1 through 16 onto stack" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0024. -/
def scriptVectors_0024 : ScrVec :=
  { id := "sc-0024", scriptSig := bytes #[81],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0025. -/
def scriptVectors_0025 : ScrVec :=
  { id := "sc-0025", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,98,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "VER non-functional (ok if not executed)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0026. -/
def scriptVectors_0026 : ScrVec :=
  { id := "sc-0026", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,80,137,138,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "RESERVED ok in un-executed IF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0027. -/
def scriptVectors_0027 : ScrVec :=
  { id := "sc-0027", scriptSig := bytes #[81],
    scriptPubKey := bytes #[118,99,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | DUP IF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0028. -/
def scriptVectors_0028 : ScrVec :=
  { id := "sc-0028", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | IF 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0029. -/
def scriptVectors_0029 : ScrVec :=
  { id := "sc-0029", scriptSig := bytes #[81],
    scriptPubKey := bytes #[118,99,103,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | DUP IF ELSE ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0030. -/
def scriptVectors_0030 : ScrVec :=
  { id := "sc-0030", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,81,103,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | IF 1 ELSE ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0031. -/
def scriptVectors_0031 : ScrVec :=
  { id := "sc-0031", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0032. -/
def scriptVectors_0032 : ScrVec :=
  { id := "sc-0032", scriptSig := bytes #[81,81],
    scriptPubKey := bytes #[99,99,81,103,0,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 1 | IF IF 1 ELSE 0 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0033. -/
def scriptVectors_0033 : ScrVec :=
  { id := "sc-0033", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[99,99,81,103,0,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | IF IF 1 ELSE 0 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0034. -/
def scriptVectors_0034 : ScrVec :=
  { id := "sc-0034", scriptSig := bytes #[81,81],
    scriptPubKey := bytes #[99,99,81,103,0,104,103,99,0,103,81,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 1 | IF IF 1 ELSE 0 ENDIF ELSE IF 0 ELSE 1 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0035. -/
def scriptVectors_0035 : ScrVec :=
  { id := "sc-0035", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[99,99,81,103,0,104,103,99,0,103,81,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 | IF IF 1 ELSE 0 ENDIF ELSE IF 0 ELSE 1 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0036. -/
def scriptVectors_0036 : ScrVec :=
  { id := "sc-0036", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[100,99,81,103,0,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | NOTIF IF 1 ELSE 0 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0037. -/
def scriptVectors_0037 : ScrVec :=
  { id := "sc-0037", scriptSig := bytes #[81,81],
    scriptPubKey := bytes #[100,99,81,103,0,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 1 | NOTIF IF 1 ELSE 0 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0038. -/
def scriptVectors_0038 : ScrVec :=
  { id := "sc-0038", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[100,99,81,103,0,104,103,99,0,103,81,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | NOTIF IF 1 ELSE 0 ENDIF ELSE IF 0 ELSE 1 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0039. -/
def scriptVectors_0039 : ScrVec :=
  { id := "sc-0039", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[100,99,81,103,0,104,103,99,0,103,81,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 1 | NOTIF IF 1 ELSE 0 ENDIF ELSE IF 0 ELSE 1 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0040. -/
def scriptVectors_0040 : ScrVec :=
  { id := "sc-0040", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,0,103,81,103,0,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Multiple ELSE's are valid and executed inverts on each ELSE encountered" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0041. -/
def scriptVectors_0041 : ScrVec :=
  { id := "sc-0041", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,81,103,0,103,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | IF 1 ELSE 0 ELSE ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0042. -/
def scriptVectors_0042 : ScrVec :=
  { id := "sc-0042", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,103,0,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | IF ELSE 0 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0043. -/
def scriptVectors_0043 : ScrVec :=
  { id := "sc-0043", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,81,103,0,103,81,104,147,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | IF 1 ELSE 0 ELSE 1 ENDIF ADD 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0044. -/
def scriptVectors_0044 : ScrVec :=
  { id := "sc-0044", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[99,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,104,20,104,202,79,236,115,98,100,193,59,133,155,172,67,213,23,61,246,135,22,130,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'' 1 | IF SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE " }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0045. -/
def scriptVectors_0045 : ScrVec :=
  { id := "sc-0045", scriptSig := bytes #[81],
    scriptPubKey := bytes #[100,0,103,81,103,0,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Multiple ELSE's are valid and execution inverts on each ELSE encountered" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0046. -/
def scriptVectors_0046 : ScrVec :=
  { id := "sc-0046", scriptSig := bytes #[0],
    scriptPubKey := bytes #[100,81,103,0,103,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | NOTIF 1 ELSE 0 ELSE ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0047. -/
def scriptVectors_0047 : ScrVec :=
  { id := "sc-0047", scriptSig := bytes #[0],
    scriptPubKey := bytes #[100,103,0,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | NOTIF ELSE 0 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0048. -/
def scriptVectors_0048 : ScrVec :=
  { id := "sc-0048", scriptSig := bytes #[0],
    scriptPubKey := bytes #[100,81,103,0,103,81,104,147,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | NOTIF 1 ELSE 0 ELSE 1 ENDIF ADD 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0049. -/
def scriptVectors_0049 : ScrVec :=
  { id := "sc-0049", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[100,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,103,103,167,104,20,104,202,79,236,115,98,100,193,59,133,155,172,67,213,23,61,246,135,22,130,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'' 0 | NOTIF SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE ELSE SHA1 ELSE EL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0050. -/
def scriptVectors_0050 : ScrVec :=
  { id := "sc-0050", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,81,99,106,103,106,103,106,104,103,81,99,81,103,106,103,81,104,103,106,104,147,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Nested ELSE ELSE" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0051. -/
def scriptVectors_0051 : ScrVec :=
  { id := "sc-0051", scriptSig := bytes #[81],
    scriptPubKey := bytes #[100,0,100,106,103,106,103,106,104,103,0,100,81,103,106,103,81,104,103,106,104,147,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | NOTIF 0 NOTIF RETURN ELSE RETURN ELSE RETURN ENDIF ELSE 0 NOTIF 1 ELSE RETURN ELSE 1 ENDIF ELSE RETURN ENDIF ADD 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0052. -/
def scriptVectors_0052 : ScrVec :=
  { id := "sc-0052", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,106,104,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "RETURN only works if executed" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0053. -/
def scriptVectors_0053 : ScrVec :=
  { id := "sc-0053", scriptSig := bytes #[81,81],
    scriptPubKey := bytes #[105],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 1 | VERIFY" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0054. -/
def scriptVectors_0054 : ScrVec :=
  { id := "sc-0054", scriptSig := bytes #[81,5,1,0,0,0,0],
    scriptPubKey := bytes #[105],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "values >4 bytes can be cast to boolean" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0055. -/
def scriptVectors_0055 : ScrVec :=
  { id := "sc-0055", scriptSig := bytes #[81,1,128],
    scriptPubKey := bytes #[99,0,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "negative 0 is false" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0056. -/
def scriptVectors_0056 : ScrVec :=
  { id := "sc-0056", scriptSig := bytes #[90,0,91,107,117,108],
    scriptPubKey := bytes #[147,1,21,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "10 0 11 TOALTSTACK DROP FROMALTSTACK | ADD 21 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0057. -/
def scriptVectors_0057 : ScrVec :=
  { id := "sc-0057", scriptSig := bytes #[14,103,97,118,105,110,95,119,97,115,95,104,101,114,101,107,91,108],
    scriptPubKey := bytes #[14,103,97,118,105,110,95,119,97,115,95,104,101,114,101,136,91,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'gavin_was_here' TOALTSTACK 11 FROMALTSTACK | 'gavin_was_here' EQUALVERIFY 11 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0058. -/
def scriptVectors_0058 : ScrVec :=
  { id := "sc-0058", scriptSig := bytes #[0,115],
    scriptPubKey := bytes #[116,81,136,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 IFDUP | DEPTH 1 EQUALVERIFY 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0059. -/
def scriptVectors_0059 : ScrVec :=
  { id := "sc-0059", scriptSig := bytes #[81,115],
    scriptPubKey := bytes #[116,82,136,81,136,81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 IFDUP | DEPTH 2 EQUALVERIFY 1 EQUALVERIFY 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0060. -/
def scriptVectors_0060 : ScrVec :=
  { id := "sc-0060", scriptSig := bytes #[5,1,0,0,0,0,115],
    scriptPubKey := bytes #[116,82,136,5,1,0,0,0,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "IFDUP dups non ints" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0061. -/
def scriptVectors_0061 : ScrVec :=
  { id := "sc-0061", scriptSig := bytes #[0,117],
    scriptPubKey := bytes #[116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 DROP | DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0062. -/
def scriptVectors_0062 : ScrVec :=
  { id := "sc-0062", scriptSig := bytes #[0],
    scriptPubKey := bytes #[118,81,147,81,136,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | DUP 1 ADD 1 EQUALVERIFY 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0063. -/
def scriptVectors_0063 : ScrVec :=
  { id := "sc-0063", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[119],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 1 | NIP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0064. -/
def scriptVectors_0064 : ScrVec :=
  { id := "sc-0064", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[120,116,83,136],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | OVER DEPTH 3 EQUALVERIFY" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0065. -/
def scriptVectors_0065 : ScrVec :=
  { id := "sc-0065", scriptSig := bytes #[1,22,1,21,1,20],
    scriptPubKey := bytes #[0,121,1,20,136,116,83,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "22 21 20 | 0 PICK 20 EQUALVERIFY DEPTH 3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0066. -/
def scriptVectors_0066 : ScrVec :=
  { id := "sc-0066", scriptSig := bytes #[1,22,1,21,1,20],
    scriptPubKey := bytes #[81,121,1,21,136,116,83,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "22 21 20 | 1 PICK 21 EQUALVERIFY DEPTH 3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0067. -/
def scriptVectors_0067 : ScrVec :=
  { id := "sc-0067", scriptSig := bytes #[1,22,1,21,1,20],
    scriptPubKey := bytes #[82,121,1,22,136,116,83,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "22 21 20 | 2 PICK 22 EQUALVERIFY DEPTH 3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0068. -/
def scriptVectors_0068 : ScrVec :=
  { id := "sc-0068", scriptSig := bytes #[1,22,1,21,1,20],
    scriptPubKey := bytes #[0,122,1,20,136,116,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "22 21 20 | 0 ROLL 20 EQUALVERIFY DEPTH 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0069. -/
def scriptVectors_0069 : ScrVec :=
  { id := "sc-0069", scriptSig := bytes #[1,22,1,21,1,20],
    scriptPubKey := bytes #[81,122,1,21,136,116,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "22 21 20 | 1 ROLL 21 EQUALVERIFY DEPTH 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0070. -/
def scriptVectors_0070 : ScrVec :=
  { id := "sc-0070", scriptSig := bytes #[1,22,1,21,1,20],
    scriptPubKey := bytes #[82,122,1,22,136,116,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "22 21 20 | 2 ROLL 22 EQUALVERIFY DEPTH 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0071. -/
def scriptVectors_0071 : ScrVec :=
  { id := "sc-0071", scriptSig := bytes #[1,22,1,21,1,20],
    scriptPubKey := bytes #[123,1,22,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "22 21 20 | ROT 22 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0072. -/
def scriptVectors_0072 : ScrVec :=
  { id := "sc-0072", scriptSig := bytes #[1,22,1,21,1,20],
    scriptPubKey := bytes #[123,117,1,20,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "22 21 20 | ROT DROP 20 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0073. -/
def scriptVectors_0073 : ScrVec :=
  { id := "sc-0073", scriptSig := bytes #[1,22,1,21,1,20],
    scriptPubKey := bytes #[123,117,117,1,21,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "22 21 20 | ROT DROP DROP 21 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0074. -/
def scriptVectors_0074 : ScrVec :=
  { id := "sc-0074", scriptSig := bytes #[1,22,1,21,1,20],
    scriptPubKey := bytes #[123,123,1,21,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "22 21 20 | ROT ROT 21 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0075. -/
def scriptVectors_0075 : ScrVec :=
  { id := "sc-0075", scriptSig := bytes #[1,22,1,21,1,20],
    scriptPubKey := bytes #[123,123,123,1,20,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "22 21 20 | ROT ROT ROT 20 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0076. -/
def scriptVectors_0076 : ScrVec :=
  { id := "sc-0076", scriptSig := bytes #[1,25,1,24,1,23,1,22,1,21,1,20],
    scriptPubKey := bytes #[113,1,24,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "25 24 23 22 21 20 | 2ROT 24 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0077. -/
def scriptVectors_0077 : ScrVec :=
  { id := "sc-0077", scriptSig := bytes #[1,25,1,24,1,23,1,22,1,21,1,20],
    scriptPubKey := bytes #[113,117,1,25,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "25 24 23 22 21 20 | 2ROT DROP 25 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0078. -/
def scriptVectors_0078 : ScrVec :=
  { id := "sc-0078", scriptSig := bytes #[1,25,1,24,1,23,1,22,1,21,1,20],
    scriptPubKey := bytes #[113,109,1,20,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "25 24 23 22 21 20 | 2ROT 2DROP 20 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0079. -/
def scriptVectors_0079 : ScrVec :=
  { id := "sc-0079", scriptSig := bytes #[1,25,1,24,1,23,1,22,1,21,1,20],
    scriptPubKey := bytes #[113,109,117,1,21,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "25 24 23 22 21 20 | 2ROT 2DROP DROP 21 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0080. -/
def scriptVectors_0080 : ScrVec :=
  { id := "sc-0080", scriptSig := bytes #[1,25,1,24,1,23,1,22,1,21,1,20],
    scriptPubKey := bytes #[113,109,109,1,22,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "25 24 23 22 21 20 | 2ROT 2DROP 2DROP 22 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0081. -/
def scriptVectors_0081 : ScrVec :=
  { id := "sc-0081", scriptSig := bytes #[1,25,1,24,1,23,1,22,1,21,1,20],
    scriptPubKey := bytes #[113,109,109,117,1,23,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "25 24 23 22 21 20 | 2ROT 2DROP 2DROP DROP 23 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0082. -/
def scriptVectors_0082 : ScrVec :=
  { id := "sc-0082", scriptSig := bytes #[1,25,1,24,1,23,1,22,1,21,1,20],
    scriptPubKey := bytes #[113,113,1,22,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "25 24 23 22 21 20 | 2ROT 2ROT 22 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0083. -/
def scriptVectors_0083 : ScrVec :=
  { id := "sc-0083", scriptSig := bytes #[1,25,1,24,1,23,1,22,1,21,1,20],
    scriptPubKey := bytes #[113,113,113,1,20,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "25 24 23 22 21 20 | 2ROT 2ROT 2ROT 20 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0084. -/
def scriptVectors_0084 : ScrVec :=
  { id := "sc-0084", scriptSig := bytes #[81,82,83,84,85,86],
    scriptPubKey := bytes #[113,116,86,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 2 3 4 5 6 | 2ROT DEPTH 6 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0085. -/
def scriptVectors_0085 : ScrVec :=
  { id := "sc-0085", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[124,81,136,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | SWAP 1 EQUALVERIFY 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0086. -/
def scriptVectors_0086 : ScrVec :=
  { id := "sc-0086", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[125,116,83,136,124,109],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 1 | TUCK DEPTH 3 EQUALVERIFY SWAP 2DROP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0087. -/
def scriptVectors_0087 : ScrVec :=
  { id := "sc-0087", scriptSig := bytes #[93,94],
    scriptPubKey := bytes #[110,123,136,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "13 14 | 2DUP ROT EQUALVERIFY EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0088. -/
def scriptVectors_0088 : ScrVec :=
  { id := "sc-0088", scriptSig := bytes #[79,0,81,82],
    scriptPubKey := bytes #[111,116,87,136,147,147,83,136,109,0,136],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 0 1 2 | 3DUP DEPTH 7 EQUALVERIFY ADD ADD 3 EQUALVERIFY 2DROP 0 EQUALVERIFY" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0089. -/
def scriptVectors_0089 : ScrVec :=
  { id := "sc-0089", scriptSig := bytes #[81,82,83,85],
    scriptPubKey := bytes #[112,147,147,88,136,147,147,86,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 2 3 5 | 2OVER ADD ADD 8 EQUALVERIFY ADD ADD 6 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0090. -/
def scriptVectors_0090 : ScrVec :=
  { id := "sc-0090", scriptSig := bytes #[81,83,85,87],
    scriptPubKey := bytes #[114,147,84,136,147,92,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 3 5 7 | 2SWAP ADD 4 EQUALVERIFY ADD 12 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0091. -/
def scriptVectors_0091 : ScrVec :=
  { id := "sc-0091", scriptSig := bytes #[0],
    scriptPubKey := bytes #[130,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | SIZE 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0092. -/
def scriptVectors_0092 : ScrVec :=
  { id := "sc-0092", scriptSig := bytes #[81],
    scriptPubKey := bytes #[130,81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | SIZE 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0093. -/
def scriptVectors_0093 : ScrVec :=
  { id := "sc-0093", scriptSig := bytes #[1,127],
    scriptPubKey := bytes #[130,81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "127 | SIZE 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0094. -/
def scriptVectors_0094 : ScrVec :=
  { id := "sc-0094", scriptSig := bytes #[2,128,0],
    scriptPubKey := bytes #[130,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "128 | SIZE 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0095. -/
def scriptVectors_0095 : ScrVec :=
  { id := "sc-0095", scriptSig := bytes #[2,255,127],
    scriptPubKey := bytes #[130,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "32767 | SIZE 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0096. -/
def scriptVectors_0096 : ScrVec :=
  { id := "sc-0096", scriptSig := bytes #[3,0,128,0],
    scriptPubKey := bytes #[130,83,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "32768 | SIZE 3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0097. -/
def scriptVectors_0097 : ScrVec :=
  { id := "sc-0097", scriptSig := bytes #[3,255,255,127],
    scriptPubKey := bytes #[130,83,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "8388607 | SIZE 3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0098. -/
def scriptVectors_0098 : ScrVec :=
  { id := "sc-0098", scriptSig := bytes #[4,0,0,128,0],
    scriptPubKey := bytes #[130,84,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "8388608 | SIZE 4 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0099. -/
def scriptVectors_0099 : ScrVec :=
  { id := "sc-0099", scriptSig := bytes #[4,255,255,255,127],
    scriptPubKey := bytes #[130,84,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2147483647 | SIZE 4 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0100. -/
def scriptVectors_0100 : ScrVec :=
  { id := "sc-0100", scriptSig := bytes #[5,0,0,0,128,0],
    scriptPubKey := bytes #[130,85,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2147483648 | SIZE 5 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0101. -/
def scriptVectors_0101 : ScrVec :=
  { id := "sc-0101", scriptSig := bytes #[5,255,255,255,255,127],
    scriptPubKey := bytes #[130,85,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x05ffffffff7f | SIZE 5 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0102. -/
def scriptVectors_0102 : ScrVec :=
  { id := "sc-0102", scriptSig := bytes #[6,0,0,0,0,128,0],
    scriptPubKey := bytes #[130,86,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x06000000008000 | SIZE 6 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0103. -/
def scriptVectors_0103 : ScrVec :=
  { id := "sc-0103", scriptSig := bytes #[8,255,255,255,255,255,255,255,127],
    scriptPubKey := bytes #[130,88,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x08ffffffffffffff7f | SIZE 8 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0104. -/
def scriptVectors_0104 : ScrVec :=
  { id := "sc-0104", scriptSig := bytes #[79],
    scriptPubKey := bytes #[130,81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 | SIZE 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0105. -/
def scriptVectors_0105 : ScrVec :=
  { id := "sc-0105", scriptSig := bytes #[1,255],
    scriptPubKey := bytes #[130,81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-127 | SIZE 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0106. -/
def scriptVectors_0106 : ScrVec :=
  { id := "sc-0106", scriptSig := bytes #[2,128,128],
    scriptPubKey := bytes #[130,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-128 | SIZE 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0107. -/
def scriptVectors_0107 : ScrVec :=
  { id := "sc-0107", scriptSig := bytes #[2,255,255],
    scriptPubKey := bytes #[130,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-32767 | SIZE 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0108. -/
def scriptVectors_0108 : ScrVec :=
  { id := "sc-0108", scriptSig := bytes #[3,0,128,128],
    scriptPubKey := bytes #[130,83,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-32768 | SIZE 3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0109. -/
def scriptVectors_0109 : ScrVec :=
  { id := "sc-0109", scriptSig := bytes #[3,255,255,255],
    scriptPubKey := bytes #[130,83,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-8388607 | SIZE 3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0110. -/
def scriptVectors_0110 : ScrVec :=
  { id := "sc-0110", scriptSig := bytes #[4,0,0,128,128],
    scriptPubKey := bytes #[130,84,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-8388608 | SIZE 4 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0111. -/
def scriptVectors_0111 : ScrVec :=
  { id := "sc-0111", scriptSig := bytes #[4,255,255,255,255],
    scriptPubKey := bytes #[130,84,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-2147483647 | SIZE 4 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0112. -/
def scriptVectors_0112 : ScrVec :=
  { id := "sc-0112", scriptSig := bytes #[5,0,0,0,128,128],
    scriptPubKey := bytes #[130,85,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-2147483648 | SIZE 5 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0113. -/
def scriptVectors_0113 : ScrVec :=
  { id := "sc-0113", scriptSig := bytes #[5,255,255,255,255,255],
    scriptPubKey := bytes #[130,85,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x05ffffffffff | SIZE 5 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0114. -/
def scriptVectors_0114 : ScrVec :=
  { id := "sc-0114", scriptSig := bytes #[6,0,0,0,0,128,128],
    scriptPubKey := bytes #[130,86,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x06000000008080 | SIZE 6 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0115. -/
def scriptVectors_0115 : ScrVec :=
  { id := "sc-0115", scriptSig := bytes #[8,255,255,255,255,255,255,255,255],
    scriptPubKey := bytes #[130,88,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x08ffffffffffffffff | SIZE 8 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0116. -/
def scriptVectors_0116 : ScrVec :=
  { id := "sc-0116", scriptSig := bytes #[26,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122],
    scriptPubKey := bytes #[130,1,26,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'abcdefghijklmnopqrstuvwxyz' | SIZE 26 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0117. -/
def scriptVectors_0117 : ScrVec :=
  { id := "sc-0117", scriptSig := bytes #[1,42],
    scriptPubKey := bytes #[130,81,136,1,42,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "SIZE does not consume argument" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0118. -/
def scriptVectors_0118 : ScrVec :=
  { id := "sc-0118", scriptSig := bytes #[82,1,130,147],
    scriptPubKey := bytes #[0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2 -2 ADD | 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0119. -/
def scriptVectors_0119 : ScrVec :=
  { id := "sc-0119", scriptSig := bytes #[4,255,255,255,127,4,255,255,255,255,147],
    scriptPubKey := bytes #[0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2147483647 -2147483647 ADD | 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0120. -/
def scriptVectors_0120 : ScrVec :=
  { id := "sc-0120", scriptSig := bytes #[79,79,147],
    scriptPubKey := bytes #[1,130,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 -1 ADD | -2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0121. -/
def scriptVectors_0121 : ScrVec :=
  { id := "sc-0121", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 | EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0122. -/
def scriptVectors_0122 : ScrVec :=
  { id := "sc-0122", scriptSig := bytes #[81,81,147],
    scriptPubKey := bytes #[82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 1 ADD | 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0123. -/
def scriptVectors_0123 : ScrVec :=
  { id := "sc-0123", scriptSig := bytes #[81,139],
    scriptPubKey := bytes #[82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 1ADD | 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0124. -/
def scriptVectors_0124 : ScrVec :=
  { id := "sc-0124", scriptSig := bytes #[1,111,140],
    scriptPubKey := bytes #[1,110,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "111 1SUB | 110 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0125. -/
def scriptVectors_0125 : ScrVec :=
  { id := "sc-0125", scriptSig := bytes #[1,111,81,147,92,148],
    scriptPubKey := bytes #[1,100,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "111 1 ADD 12 SUB | 100 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0126. -/
def scriptVectors_0126 : ScrVec :=
  { id := "sc-0126", scriptSig := bytes #[0,144],
    scriptPubKey := bytes #[0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 ABS | 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0127. -/
def scriptVectors_0127 : ScrVec :=
  { id := "sc-0127", scriptSig := bytes #[96,144],
    scriptPubKey := bytes #[96,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "16 ABS | 16 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0128. -/
def scriptVectors_0128 : ScrVec :=
  { id := "sc-0128", scriptSig := bytes #[1,144,144],
    scriptPubKey := bytes #[1,144,143,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-16 ABS | -16 NEGATE EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0129. -/
def scriptVectors_0129 : ScrVec :=
  { id := "sc-0129", scriptSig := bytes #[0,145],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 NOT | NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0130. -/
def scriptVectors_0130 : ScrVec :=
  { id := "sc-0130", scriptSig := bytes #[81,145],
    scriptPubKey := bytes #[0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 NOT | 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0131. -/
def scriptVectors_0131 : ScrVec :=
  { id := "sc-0131", scriptSig := bytes #[91,145],
    scriptPubKey := bytes #[0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "11 NOT | 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0132. -/
def scriptVectors_0132 : ScrVec :=
  { id := "sc-0132", scriptSig := bytes #[0,146],
    scriptPubKey := bytes #[0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0NOTEQUAL | 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0133. -/
def scriptVectors_0133 : ScrVec :=
  { id := "sc-0133", scriptSig := bytes #[81,146],
    scriptPubKey := bytes #[81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0NOTEQUAL | 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0134. -/
def scriptVectors_0134 : ScrVec :=
  { id := "sc-0134", scriptSig := bytes #[1,111,146],
    scriptPubKey := bytes #[81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "111 0NOTEQUAL | 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0135. -/
def scriptVectors_0135 : ScrVec :=
  { id := "sc-0135", scriptSig := bytes #[1,239,146],
    scriptPubKey := bytes #[81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-111 0NOTEQUAL | 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0136. -/
def scriptVectors_0136 : ScrVec :=
  { id := "sc-0136", scriptSig := bytes #[81,81,154],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 1 BOOLAND | NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0137. -/
def scriptVectors_0137 : ScrVec :=
  { id := "sc-0137", scriptSig := bytes #[81,0,154],
    scriptPubKey := bytes #[145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 BOOLAND | NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0138. -/
def scriptVectors_0138 : ScrVec :=
  { id := "sc-0138", scriptSig := bytes #[0,81,154],
    scriptPubKey := bytes #[145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 1 BOOLAND | NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0139. -/
def scriptVectors_0139 : ScrVec :=
  { id := "sc-0139", scriptSig := bytes #[0,0,154],
    scriptPubKey := bytes #[145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 BOOLAND | NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0140. -/
def scriptVectors_0140 : ScrVec :=
  { id := "sc-0140", scriptSig := bytes #[96,1,17,154],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "16 17 BOOLAND | NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0141. -/
def scriptVectors_0141 : ScrVec :=
  { id := "sc-0141", scriptSig := bytes #[81,81,155],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 1 BOOLOR | NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0142. -/
def scriptVectors_0142 : ScrVec :=
  { id := "sc-0142", scriptSig := bytes #[81,0,155],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 BOOLOR | NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0143. -/
def scriptVectors_0143 : ScrVec :=
  { id := "sc-0143", scriptSig := bytes #[0,81,155],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 1 BOOLOR | NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0144. -/
def scriptVectors_0144 : ScrVec :=
  { id := "sc-0144", scriptSig := bytes #[0,0,155],
    scriptPubKey := bytes #[145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 BOOLOR | NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0145. -/
def scriptVectors_0145 : ScrVec :=
  { id := "sc-0145", scriptSig := bytes #[1,128],
    scriptPubKey := bytes #[118,155],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "negative-0 negative-0 BOOLOR" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0146. -/
def scriptVectors_0146 : ScrVec :=
  { id := "sc-0146", scriptSig := bytes #[1,0],
    scriptPubKey := bytes #[118,155],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := " non-minimal-0  non-minimal-0 BOOLOR" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0147. -/
def scriptVectors_0147 : ScrVec :=
  { id := "sc-0147", scriptSig := bytes #[1,129],
    scriptPubKey := bytes #[118,155],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 -1 BOOLOR" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0148. -/
def scriptVectors_0148 : ScrVec :=
  { id := "sc-0148", scriptSig := bytes #[1,128],
    scriptPubKey := bytes #[118,154],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "negative-0 negative-0 BOOLAND" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0149. -/
def scriptVectors_0149 : ScrVec :=
  { id := "sc-0149", scriptSig := bytes #[1,0],
    scriptPubKey := bytes #[118,154],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := " non-minimal-0  non-minimal-0 BOOLAND" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0150. -/
def scriptVectors_0150 : ScrVec :=
  { id := "sc-0150", scriptSig := bytes #[1,129],
    scriptPubKey := bytes #[118,154],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 -1 BOOLAND" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0151. -/
def scriptVectors_0151 : ScrVec :=
  { id := "sc-0151", scriptSig := bytes #[1,0],
    scriptPubKey := bytes #[145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "non-minimal-0 NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0152. -/
def scriptVectors_0152 : ScrVec :=
  { id := "sc-0152", scriptSig := bytes #[1,128],
    scriptPubKey := bytes #[145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "negative-0 NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0153. -/
def scriptVectors_0153 : ScrVec :=
  { id := "sc-0153", scriptSig := bytes #[1,129],
    scriptPubKey := bytes #[145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "negative 1 NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0154. -/
def scriptVectors_0154 : ScrVec :=
  { id := "sc-0154", scriptSig := bytes #[1,128,0],
    scriptPubKey := bytes #[156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "-0 0 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0155. -/
def scriptVectors_0155 : ScrVec :=
  { id := "sc-0155", scriptSig := bytes #[1,0,0],
    scriptPubKey := bytes #[156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "non-minimal-0 0 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0156. -/
def scriptVectors_0156 : ScrVec :=
  { id := "sc-0156", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "non-minimal-0 0 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0157. -/
def scriptVectors_0157 : ScrVec :=
  { id := "sc-0157", scriptSig := bytes #[96,1,17,155],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "16 17 BOOLOR | NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0158. -/
def scriptVectors_0158 : ScrVec :=
  { id := "sc-0158", scriptSig := bytes #[91,90,81,147],
    scriptPubKey := bytes #[156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "11 10 1 ADD | NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0159. -/
def scriptVectors_0159 : ScrVec :=
  { id := "sc-0159", scriptSig := bytes #[91,90,81,147],
    scriptPubKey := bytes #[157,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "11 10 1 ADD | NUMEQUALVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0160. -/
def scriptVectors_0160 : ScrVec :=
  { id := "sc-0160", scriptSig := bytes #[91,90,81,147],
    scriptPubKey := bytes #[158,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "11 10 1 ADD | NUMNOTEQUAL NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0161. -/
def scriptVectors_0161 : ScrVec :=
  { id := "sc-0161", scriptSig := bytes #[1,111,90,81,147],
    scriptPubKey := bytes #[158],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "111 10 1 ADD | NUMNOTEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0162. -/
def scriptVectors_0162 : ScrVec :=
  { id := "sc-0162", scriptSig := bytes #[91,90],
    scriptPubKey := bytes #[159,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "11 10 | LESSTHAN NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0163. -/
def scriptVectors_0163 : ScrVec :=
  { id := "sc-0163", scriptSig := bytes #[84,84],
    scriptPubKey := bytes #[159,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "4 4 | LESSTHAN NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0164. -/
def scriptVectors_0164 : ScrVec :=
  { id := "sc-0164", scriptSig := bytes #[90,91],
    scriptPubKey := bytes #[159],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "10 11 | LESSTHAN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0165. -/
def scriptVectors_0165 : ScrVec :=
  { id := "sc-0165", scriptSig := bytes #[1,139,91],
    scriptPubKey := bytes #[159],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-11 11 | LESSTHAN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0166. -/
def scriptVectors_0166 : ScrVec :=
  { id := "sc-0166", scriptSig := bytes #[1,139,1,138],
    scriptPubKey := bytes #[159],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-11 -10 | LESSTHAN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0167. -/
def scriptVectors_0167 : ScrVec :=
  { id := "sc-0167", scriptSig := bytes #[91,90],
    scriptPubKey := bytes #[160],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "11 10 | GREATERTHAN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0168. -/
def scriptVectors_0168 : ScrVec :=
  { id := "sc-0168", scriptSig := bytes #[84,84],
    scriptPubKey := bytes #[160,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "4 4 | GREATERTHAN NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0169. -/
def scriptVectors_0169 : ScrVec :=
  { id := "sc-0169", scriptSig := bytes #[90,91],
    scriptPubKey := bytes #[160,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "10 11 | GREATERTHAN NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0170. -/
def scriptVectors_0170 : ScrVec :=
  { id := "sc-0170", scriptSig := bytes #[1,139,91],
    scriptPubKey := bytes #[160,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-11 11 | GREATERTHAN NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0171. -/
def scriptVectors_0171 : ScrVec :=
  { id := "sc-0171", scriptSig := bytes #[1,139,1,138],
    scriptPubKey := bytes #[160,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-11 -10 | GREATERTHAN NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0172. -/
def scriptVectors_0172 : ScrVec :=
  { id := "sc-0172", scriptSig := bytes #[91,90],
    scriptPubKey := bytes #[161,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "11 10 | LESSTHANOREQUAL NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0173. -/
def scriptVectors_0173 : ScrVec :=
  { id := "sc-0173", scriptSig := bytes #[84,84],
    scriptPubKey := bytes #[161],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "4 4 | LESSTHANOREQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0174. -/
def scriptVectors_0174 : ScrVec :=
  { id := "sc-0174", scriptSig := bytes #[90,91],
    scriptPubKey := bytes #[161],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "10 11 | LESSTHANOREQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0175. -/
def scriptVectors_0175 : ScrVec :=
  { id := "sc-0175", scriptSig := bytes #[1,139,91],
    scriptPubKey := bytes #[161],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-11 11 | LESSTHANOREQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0176. -/
def scriptVectors_0176 : ScrVec :=
  { id := "sc-0176", scriptSig := bytes #[1,139,1,138],
    scriptPubKey := bytes #[161],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-11 -10 | LESSTHANOREQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0177. -/
def scriptVectors_0177 : ScrVec :=
  { id := "sc-0177", scriptSig := bytes #[91,90],
    scriptPubKey := bytes #[162],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "11 10 | GREATERTHANOREQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0178. -/
def scriptVectors_0178 : ScrVec :=
  { id := "sc-0178", scriptSig := bytes #[84,84],
    scriptPubKey := bytes #[162],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "4 4 | GREATERTHANOREQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0179. -/
def scriptVectors_0179 : ScrVec :=
  { id := "sc-0179", scriptSig := bytes #[90,91],
    scriptPubKey := bytes #[162,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "10 11 | GREATERTHANOREQUAL NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0180. -/
def scriptVectors_0180 : ScrVec :=
  { id := "sc-0180", scriptSig := bytes #[1,139,91],
    scriptPubKey := bytes #[162,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-11 11 | GREATERTHANOREQUAL NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0181. -/
def scriptVectors_0181 : ScrVec :=
  { id := "sc-0181", scriptSig := bytes #[1,139,1,138],
    scriptPubKey := bytes #[162,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-11 -10 | GREATERTHANOREQUAL NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0182. -/
def scriptVectors_0182 : ScrVec :=
  { id := "sc-0182", scriptSig := bytes #[81,0,163],
    scriptPubKey := bytes #[0,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 MIN | 0 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0183. -/
def scriptVectors_0183 : ScrVec :=
  { id := "sc-0183", scriptSig := bytes #[0,81,163],
    scriptPubKey := bytes #[0,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 1 MIN | 0 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0184. -/
def scriptVectors_0184 : ScrVec :=
  { id := "sc-0184", scriptSig := bytes #[79,0,163],
    scriptPubKey := bytes #[79,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 0 MIN | -1 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0185. -/
def scriptVectors_0185 : ScrVec :=
  { id := "sc-0185", scriptSig := bytes #[0,4,255,255,255,255,163],
    scriptPubKey := bytes #[4,255,255,255,255,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 -2147483647 MIN | -2147483647 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0186. -/
def scriptVectors_0186 : ScrVec :=
  { id := "sc-0186", scriptSig := bytes #[4,255,255,255,127,0,164],
    scriptPubKey := bytes #[4,255,255,255,127,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2147483647 0 MAX | 2147483647 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0187. -/
def scriptVectors_0187 : ScrVec :=
  { id := "sc-0187", scriptSig := bytes #[0,1,100,164],
    scriptPubKey := bytes #[1,100,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 100 MAX | 100 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0188. -/
def scriptVectors_0188 : ScrVec :=
  { id := "sc-0188", scriptSig := bytes #[1,228,0,164],
    scriptPubKey := bytes #[0,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-100 0 MAX | 0 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0189. -/
def scriptVectors_0189 : ScrVec :=
  { id := "sc-0189", scriptSig := bytes #[0,4,255,255,255,255,164],
    scriptPubKey := bytes #[0,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 -2147483647 MAX | 0 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0190. -/
def scriptVectors_0190 : ScrVec :=
  { id := "sc-0190", scriptSig := bytes #[0,0,81],
    scriptPubKey := bytes #[165],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 1 | WITHIN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0191. -/
def scriptVectors_0191 : ScrVec :=
  { id := "sc-0191", scriptSig := bytes #[81,0,81],
    scriptPubKey := bytes #[165,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 1 | WITHIN NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0192. -/
def scriptVectors_0192 : ScrVec :=
  { id := "sc-0192", scriptSig := bytes #[0,4,255,255,255,255,4,255,255,255,127],
    scriptPubKey := bytes #[165],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 -2147483647 2147483647 | WITHIN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0193. -/
def scriptVectors_0193 : ScrVec :=
  { id := "sc-0193", scriptSig := bytes #[79,1,228,1,100],
    scriptPubKey := bytes #[165],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 -100 100 | WITHIN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0194. -/
def scriptVectors_0194 : ScrVec :=
  { id := "sc-0194", scriptSig := bytes #[91,1,228,1,100],
    scriptPubKey := bytes #[165],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "11 -100 100 | WITHIN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0195. -/
def scriptVectors_0195 : ScrVec :=
  { id := "sc-0195", scriptSig := bytes #[4,255,255,255,255,1,228,1,100],
    scriptPubKey := bytes #[165,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-2147483647 -100 100 | WITHIN NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0196. -/
def scriptVectors_0196 : ScrVec :=
  { id := "sc-0196", scriptSig := bytes #[4,255,255,255,127,1,228,1,100],
    scriptPubKey := bytes #[165,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2147483647 -100 100 | WITHIN NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0197. -/
def scriptVectors_0197 : ScrVec :=
  { id := "sc-0197", scriptSig := bytes #[0,0,81],
    scriptPubKey := bytes #[165,116,81,136],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "WITHIN must pop all 3 elements" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0198. -/
def scriptVectors_0198 : ScrVec :=
  { id := "sc-0198", scriptSig := bytes #[4,255,255,255,127,4,255,255,255,127,148],
    scriptPubKey := bytes #[0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2147483647 2147483647 SUB | 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0199. -/
def scriptVectors_0199 : ScrVec :=
  { id := "sc-0199", scriptSig := bytes #[4,255,255,255,127,118,147],
    scriptPubKey := bytes #[5,254,255,255,255,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := ">32 bit EQUAL is valid" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0200. -/
def scriptVectors_0200 : ScrVec :=
  { id := "sc-0200", scriptSig := bytes #[4,255,255,255,127,143,118,147],
    scriptPubKey := bytes #[5,254,255,255,255,128,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2147483647 NEGATE DUP ADD | -4294967294 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0201. -/
def scriptVectors_0201 : ScrVec :=
  { id := "sc-0201", scriptSig := bytes #[0],
    scriptPubKey := bytes #[166,20,156,17,133,165,197,233,252,84,97,40,8,151,126,232,245,72,178,37,141,49,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'' | RIPEMD160 0x14 0x9c1185a5c5e9fc54612808977ee8f548b2258d31 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0202. -/
def scriptVectors_0202 : ScrVec :=
  { id := "sc-0202", scriptSig := bytes #[1,97],
    scriptPubKey := bytes #[166,20,11,220,157,45,37,107,62,233,218,174,52,123,230,244,220,131,90,70,127,254,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'a' | RIPEMD160 0x14 0x0bdc9d2d256b3ee9daae347be6f4dc835a467ffe EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0203. -/
def scriptVectors_0203 : ScrVec :=
  { id := "sc-0203", scriptSig := bytes #[26,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122],
    scriptPubKey := bytes #[166,20,247,28,39,16,156,105,44,27,86,187,220,235,91,157,40,101,179,112,141,188,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'abcdefghijklmnopqrstuvwxyz' | RIPEMD160 0x14 0xf71c27109c692c1b56bbdceb5b9d2865b3708dbc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0204. -/
def scriptVectors_0204 : ScrVec :=
  { id := "sc-0204", scriptSig := bytes #[0],
    scriptPubKey := bytes #[167,20,218,57,163,238,94,107,75,13,50,85,191,239,149,96,24,144,175,216,7,9,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'' | SHA1 0x14 0xda39a3ee5e6b4b0d3255bfef95601890afd80709 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0205. -/
def scriptVectors_0205 : ScrVec :=
  { id := "sc-0205", scriptSig := bytes #[1,97],
    scriptPubKey := bytes #[167,20,134,247,228,55,250,165,167,252,225,93,29,220,185,234,234,234,55,118,103,184,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'a' | SHA1 0x14 0x86f7e437faa5a7fce15d1ddcb9eaeaea377667b8 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0206. -/
def scriptVectors_0206 : ScrVec :=
  { id := "sc-0206", scriptSig := bytes #[26,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122],
    scriptPubKey := bytes #[167,20,50,209,12,123,140,249,101,112,202,4,206,55,242,161,157,132,36,13,58,137,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'abcdefghijklmnopqrstuvwxyz' | SHA1 0x14 0x32d10c7b8cf96570ca04ce37f2a19d84240d3a89 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0207. -/
def scriptVectors_0207 : ScrVec :=
  { id := "sc-0207", scriptSig := bytes #[0],
    scriptPubKey := bytes #[168,32,227,176,196,66,152,252,28,20,154,251,244,200,153,111,185,36,39,174,65,228,100,155,147,76,164,149,153,27,120,82,184,85,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'' | SHA256 0x20 0xe3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0208. -/
def scriptVectors_0208 : ScrVec :=
  { id := "sc-0208", scriptSig := bytes #[1,97],
    scriptPubKey := bytes #[168,32,202,151,129,18,202,27,189,202,250,194,49,179,154,35,220,77,167,134,239,248,20,124,78,114,185,128,119,133,175,238,72,187,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'a' | SHA256 0x20 0xca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0209. -/
def scriptVectors_0209 : ScrVec :=
  { id := "sc-0209", scriptSig := bytes #[26,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122],
    scriptPubKey := bytes #[168,32,113,196,128,223,147,214,174,47,30,250,209,68,124,102,201,82,94,49,98,24,207,81,252,141,158,216,50,242,218,241,139,115,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'abcdefghijklmnopqrstuvwxyz' | SHA256 0x20 0x71c480df93d6ae2f1efad1447c66c9525e316218cf51fc8d9ed832f2daf18b73 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0210. -/
def scriptVectors_0210 : ScrVec :=
  { id := "sc-0210", scriptSig := bytes #[0],
    scriptPubKey := bytes #[118,169,124,168,166,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'' | DUP HASH160 SWAP SHA256 RIPEMD160 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0211. -/
def scriptVectors_0211 : ScrVec :=
  { id := "sc-0211", scriptSig := bytes #[0],
    scriptPubKey := bytes #[118,170,124,168,168,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'' | DUP HASH256 SWAP SHA256 SHA256 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0212. -/
def scriptVectors_0212 : ScrVec :=
  { id := "sc-0212", scriptSig := bytes #[0],
    scriptPubKey := bytes #[97,169,20,180,114,162,102,208,189,137,193,55,6,164,19,44,207,177,111,124,59,159,203,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'' | NOP HASH160 0x14 0xb472a266d0bd89c13706a4132ccfb16f7c3b9fcb EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0213. -/
def scriptVectors_0213 : ScrVec :=
  { id := "sc-0213", scriptSig := bytes #[1,97],
    scriptPubKey := bytes #[169,97,20,153,67,85,25,158,81,111,247,108,79,164,170,179,147,55,185,216,76,241,43,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'a' | HASH160 NOP 0x14 0x994355199e516ff76c4fa4aab39337b9d84cf12b EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0214. -/
def scriptVectors_0214 : ScrVec :=
  { id := "sc-0214", scriptSig := bytes #[26,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122],
    scriptPubKey := bytes #[169,76,20,194,134,161,175,9,71,245,141,26,215,135,56,91,28,44,74,151,111,158,113,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'abcdefghijklmnopqrstuvwxyz' | HASH160 0x4c 0x14 0xc286a1af0947f58d1ad787385b1c2c4a976f9e71 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0215. -/
def scriptVectors_0215 : ScrVec :=
  { id := "sc-0215", scriptSig := bytes #[0],
    scriptPubKey := bytes #[170,32,93,246,224,226,118,19,89,211,10,130,117,5,142,41,159,204,3,129,83,69,69,245,92,244,62,65,152,63,93,76,148,86,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'' | HASH256 0x20 0x5df6e0e2761359d30a8275058e299fcc0381534545f55cf43e41983f5d4c9456 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0216. -/
def scriptVectors_0216 : ScrVec :=
  { id := "sc-0216", scriptSig := bytes #[1,97],
    scriptPubKey := bytes #[170,32,191,93,58,255,183,62,253,46,198,195,106,211,17,45,217,51,239,237,99,196,225,203,255,207,168,142,39,89,193,68,242,216,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'a' | HASH256 0x20 0xbf5d3affb73efd2ec6c36ad3112dd933efed63c4e1cbffcfa88e2759c144f2d8 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0217. -/
def scriptVectors_0217 : ScrVec :=
  { id := "sc-0217", scriptSig := bytes #[26,97,98,99,100,101,102,103,104,105,106,107,108,109,110,111,112,113,114,115,116,117,118,119,120,121,122],
    scriptPubKey := bytes #[170,76,32,202,19,155,193,12,47,102,13,164,38,102,247,46,137,162,37,147,111,198,15,25,60,22,17,36,166,114,5,12,67,70,113,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'abcdefghijklmnopqrstuvwxyz' | HASH256 0x4c 0x20 0xca139bc10c2f660da42666f72e89a225936fc60f193c161124a672050c434671 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0218. -/
def scriptVectors_0218 : ScrVec :=
  { id := "sc-0218", scriptSig := bytes #[81],
    scriptPubKey := bytes #[176,177,178,179,180,181,182,183,184,185,81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | NOP1 CHECKLOCKTIMEVERIFY CHECKSEQUENCEVERIFY NOP4 NOP5 NOP6 NOP7 NOP8 NOP9 NOP10 1 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0219. -/
def scriptVectors_0219 : ScrVec :=
  { id := "sc-0219", scriptSig := bytes #[11,78,79,80,95,49,95,116,111,95,49,48,176,177,178,179,180,181,182,183,184,185],
    scriptPubKey := bytes #[11,78,79,80,95,49,95,116,111,95,49,48,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "'NOP_1_to_10' NOP1 CHECKLOCKTIMEVERIFY CHECKSEQUENCEVERIFY NOP4 NOP5 NOP6 NOP7 NOP8 NOP9 NOP10 | 'NOP_1_to_10' EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0220. -/
def scriptVectors_0220 : ScrVec :=
  { id := "sc-0220", scriptSig := bytes #[81],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC, DISCOURAGE_UPGRADABLE_NOPS",
    expectOk := true, expectedError := "OK",
    comment := "Discourage NOPx flag allows OP_NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0221. -/
def scriptVectors_0221 : ScrVec :=
  { id := "sc-0221", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,185,104,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC, DISCOURAGE_UPGRADABLE_NOPS",
    expectOk := true, expectedError := "OK",
    comment := "Discouraged NOPs are allowed if not executed" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0222. -/
def scriptVectors_0222 : ScrVec :=
  { id := "sc-0222", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,186,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "opcodes above MAX_OPCODE invalid if executed" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0223. -/
def scriptVectors_0223 : ScrVec :=
  { id := "sc-0223", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,187,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xbb ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0224. -/
def scriptVectors_0224 : ScrVec :=
  { id := "sc-0224", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,188,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xbc ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0225. -/
def scriptVectors_0225 : ScrVec :=
  { id := "sc-0225", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,189,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xbd ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0226. -/
def scriptVectors_0226 : ScrVec :=
  { id := "sc-0226", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,190,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xbe ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0227. -/
def scriptVectors_0227 : ScrVec :=
  { id := "sc-0227", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,191,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xbf ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0228. -/
def scriptVectors_0228 : ScrVec :=
  { id := "sc-0228", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,192,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xc0 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0229. -/
def scriptVectors_0229 : ScrVec :=
  { id := "sc-0229", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,193,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xc1 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0230. -/
def scriptVectors_0230 : ScrVec :=
  { id := "sc-0230", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,194,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xc2 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0231. -/
def scriptVectors_0231 : ScrVec :=
  { id := "sc-0231", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,195,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xc3 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0232. -/
def scriptVectors_0232 : ScrVec :=
  { id := "sc-0232", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,196,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xc4 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0233. -/
def scriptVectors_0233 : ScrVec :=
  { id := "sc-0233", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,197,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xc5 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0234. -/
def scriptVectors_0234 : ScrVec :=
  { id := "sc-0234", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,198,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xc6 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0235. -/
def scriptVectors_0235 : ScrVec :=
  { id := "sc-0235", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,199,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xc7 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0236. -/
def scriptVectors_0236 : ScrVec :=
  { id := "sc-0236", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,200,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xc8 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0237. -/
def scriptVectors_0237 : ScrVec :=
  { id := "sc-0237", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,201,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xc9 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0238. -/
def scriptVectors_0238 : ScrVec :=
  { id := "sc-0238", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,202,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xca ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0239. -/
def scriptVectors_0239 : ScrVec :=
  { id := "sc-0239", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,203,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xcb ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0240. -/
def scriptVectors_0240 : ScrVec :=
  { id := "sc-0240", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,204,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xcc ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0241. -/
def scriptVectors_0241 : ScrVec :=
  { id := "sc-0241", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,205,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xcd ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0242. -/
def scriptVectors_0242 : ScrVec :=
  { id := "sc-0242", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,206,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xce ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0243. -/
def scriptVectors_0243 : ScrVec :=
  { id := "sc-0243", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,207,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xcf ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0244. -/
def scriptVectors_0244 : ScrVec :=
  { id := "sc-0244", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,208,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xd0 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0245. -/
def scriptVectors_0245 : ScrVec :=
  { id := "sc-0245", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,209,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xd1 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0246. -/
def scriptVectors_0246 : ScrVec :=
  { id := "sc-0246", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,210,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xd2 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0247. -/
def scriptVectors_0247 : ScrVec :=
  { id := "sc-0247", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,211,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xd3 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0248. -/
def scriptVectors_0248 : ScrVec :=
  { id := "sc-0248", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,212,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xd4 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0249. -/
def scriptVectors_0249 : ScrVec :=
  { id := "sc-0249", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,213,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xd5 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0250. -/
def scriptVectors_0250 : ScrVec :=
  { id := "sc-0250", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,214,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xd6 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0251. -/
def scriptVectors_0251 : ScrVec :=
  { id := "sc-0251", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,215,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xd7 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0252. -/
def scriptVectors_0252 : ScrVec :=
  { id := "sc-0252", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,216,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xd8 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0253. -/
def scriptVectors_0253 : ScrVec :=
  { id := "sc-0253", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,217,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xd9 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0254. -/
def scriptVectors_0254 : ScrVec :=
  { id := "sc-0254", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,218,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xda ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0255. -/
def scriptVectors_0255 : ScrVec :=
  { id := "sc-0255", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,219,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xdb ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0256. -/
def scriptVectors_0256 : ScrVec :=
  { id := "sc-0256", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,220,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xdc ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0257. -/
def scriptVectors_0257 : ScrVec :=
  { id := "sc-0257", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,221,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xdd ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0258. -/
def scriptVectors_0258 : ScrVec :=
  { id := "sc-0258", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,222,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xde ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0259. -/
def scriptVectors_0259 : ScrVec :=
  { id := "sc-0259", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,223,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xdf ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0260. -/
def scriptVectors_0260 : ScrVec :=
  { id := "sc-0260", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,224,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xe0 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0261. -/
def scriptVectors_0261 : ScrVec :=
  { id := "sc-0261", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,225,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xe1 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0262. -/
def scriptVectors_0262 : ScrVec :=
  { id := "sc-0262", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,226,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xe2 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0263. -/
def scriptVectors_0263 : ScrVec :=
  { id := "sc-0263", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,227,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xe3 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0264. -/
def scriptVectors_0264 : ScrVec :=
  { id := "sc-0264", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,228,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xe4 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0265. -/
def scriptVectors_0265 : ScrVec :=
  { id := "sc-0265", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,229,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xe5 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0266. -/
def scriptVectors_0266 : ScrVec :=
  { id := "sc-0266", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,230,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xe6 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0267. -/
def scriptVectors_0267 : ScrVec :=
  { id := "sc-0267", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,231,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xe7 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0268. -/
def scriptVectors_0268 : ScrVec :=
  { id := "sc-0268", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,232,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xe8 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0269. -/
def scriptVectors_0269 : ScrVec :=
  { id := "sc-0269", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,233,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xe9 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0270. -/
def scriptVectors_0270 : ScrVec :=
  { id := "sc-0270", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,234,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xea ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0271. -/
def scriptVectors_0271 : ScrVec :=
  { id := "sc-0271", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,235,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xeb ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0272. -/
def scriptVectors_0272 : ScrVec :=
  { id := "sc-0272", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,236,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xec ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0273. -/
def scriptVectors_0273 : ScrVec :=
  { id := "sc-0273", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,237,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xed ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0274. -/
def scriptVectors_0274 : ScrVec :=
  { id := "sc-0274", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,238,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xee ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0275. -/
def scriptVectors_0275 : ScrVec :=
  { id := "sc-0275", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,239,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xef ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0276. -/
def scriptVectors_0276 : ScrVec :=
  { id := "sc-0276", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,240,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xf0 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0277. -/
def scriptVectors_0277 : ScrVec :=
  { id := "sc-0277", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,241,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xf1 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0278. -/
def scriptVectors_0278 : ScrVec :=
  { id := "sc-0278", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,242,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xf2 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0279. -/
def scriptVectors_0279 : ScrVec :=
  { id := "sc-0279", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,243,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xf3 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0280. -/
def scriptVectors_0280 : ScrVec :=
  { id := "sc-0280", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,244,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xf4 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0281. -/
def scriptVectors_0281 : ScrVec :=
  { id := "sc-0281", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,245,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xf5 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0282. -/
def scriptVectors_0282 : ScrVec :=
  { id := "sc-0282", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,246,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xf6 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0283. -/
def scriptVectors_0283 : ScrVec :=
  { id := "sc-0283", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,247,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xf7 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0284. -/
def scriptVectors_0284 : ScrVec :=
  { id := "sc-0284", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,248,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xf8 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0285. -/
def scriptVectors_0285 : ScrVec :=
  { id := "sc-0285", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,249,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xf9 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0286. -/
def scriptVectors_0286 : ScrVec :=
  { id := "sc-0286", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,250,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xfa ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0287. -/
def scriptVectors_0287 : ScrVec :=
  { id := "sc-0287", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,251,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xfb ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0288. -/
def scriptVectors_0288 : ScrVec :=
  { id := "sc-0288", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,252,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xfc ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0289. -/
def scriptVectors_0289 : ScrVec :=
  { id := "sc-0289", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,253,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xfd ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0290. -/
def scriptVectors_0290 : ScrVec :=
  { id := "sc-0290", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,254,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xfe ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0291. -/
def scriptVectors_0291 : ScrVec :=
  { id := "sc-0291", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,255,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | IF 0xff ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0292. -/
def scriptVectors_0292 : ScrVec :=
  { id := "sc-0292", scriptSig := bytes #[97],
    scriptPubKey := bytes #[77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "520 byte push" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0293. -/
def scriptVectors_0293 : ScrVec :=
  { id := "sc-0293", scriptSig := bytes #[81],
    scriptPubKey := bytes #[97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "201 opcodes executed. 0x61 is NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0294. -/
def scriptVectors_0294 : ScrVec :=
  { id := "sc-0294", scriptSig := bytes #[81],
    scriptPubKey := bytes #[96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96,96],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "202 OP_16 do not count towards the 201 opcode limit." }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0295. -/
def scriptVectors_0295 : ScrVec :=
  { id := "sc-0295", scriptSig := bytes #[81,82,83,84,85,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111],
    scriptPubKey := bytes #[81,82,83,84,85,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1,000 stack size (0x6f is 3DUP)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0296. -/
def scriptVectors_0296 : ScrVec :=
  { id := "sc-0296", scriptSig := bytes #[81,107,82,107,83,84,85,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111],
    scriptPubKey := bytes #[81,82,83,84,85,86,87,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1,000 stack size (altstack cleared between scriptSig/scriptPubKey)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0297. -/
def scriptVectors_0297 : ScrVec :=
  { id := "sc-0297", scriptSig := bytes #[77,126,1,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111],
    scriptPubKey := bytes #[77,126,1,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,110,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Max-size (10,000-byte), max-push(520 bytes), max-opcodes(201), max stack size(1,000 items). 0x6f is 3DUP, 0x61 is NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0298. -/
def scriptVectors_0298 : ScrVec :=
  { id := "sc-0298", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,80,104,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := ">201 opcodes, but RESERVED (0x50) doesn't count towards opcode limit." }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0299. -/
def scriptVectors_0299 : ScrVec :=
  { id := "sc-0299", scriptSig := bytes #[97],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0300. -/
def scriptVectors_0300 : ScrVec :=
  { id := "sc-0300", scriptSig := bytes #[81],
    scriptPubKey := bytes #[1,1,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "The following is useful for checking implementations of BN_bn2mpi" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0301. -/
def scriptVectors_0301 : ScrVec :=
  { id := "sc-0301", scriptSig := bytes #[1,127],
    scriptPubKey := bytes #[1,127,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "127 | 0x01 0x7F EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0302. -/
def scriptVectors_0302 : ScrVec :=
  { id := "sc-0302", scriptSig := bytes #[2,128,0],
    scriptPubKey := bytes #[2,128,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Leave room for the sign bit" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0303. -/
def scriptVectors_0303 : ScrVec :=
  { id := "sc-0303", scriptSig := bytes #[2,255,127],
    scriptPubKey := bytes #[2,255,127,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "32767 | 0x02 0xFF7F EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0304. -/
def scriptVectors_0304 : ScrVec :=
  { id := "sc-0304", scriptSig := bytes #[3,0,128,0],
    scriptPubKey := bytes #[3,0,128,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "32768 | 0x03 0x008000 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0305. -/
def scriptVectors_0305 : ScrVec :=
  { id := "sc-0305", scriptSig := bytes #[3,255,255,127],
    scriptPubKey := bytes #[3,255,255,127,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "8388607 | 0x03 0xFFFF7F EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0306. -/
def scriptVectors_0306 : ScrVec :=
  { id := "sc-0306", scriptSig := bytes #[4,0,0,128,0],
    scriptPubKey := bytes #[4,0,0,128,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "8388608 | 0x04 0x00008000 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0307. -/
def scriptVectors_0307 : ScrVec :=
  { id := "sc-0307", scriptSig := bytes #[4,255,255,255,127],
    scriptPubKey := bytes #[4,255,255,255,127,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2147483647 | 0x04 0xFFFFFF7F EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0308. -/
def scriptVectors_0308 : ScrVec :=
  { id := "sc-0308", scriptSig := bytes #[5,0,0,0,128,0],
    scriptPubKey := bytes #[5,0,0,0,128,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2147483648 | 0x05 0x0000008000 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0309. -/
def scriptVectors_0309 : ScrVec :=
  { id := "sc-0309", scriptSig := bytes #[5,255,255,255,255,127],
    scriptPubKey := bytes #[5,255,255,255,255,127,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x05ffffffff7f | 0x05 0xFFFFFFFF7F EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0310. -/
def scriptVectors_0310 : ScrVec :=
  { id := "sc-0310", scriptSig := bytes #[6,0,0,0,0,128,0],
    scriptPubKey := bytes #[6,0,0,0,0,128,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x06000000008000 | 0x06 0x000000008000 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0311. -/
def scriptVectors_0311 : ScrVec :=
  { id := "sc-0311", scriptSig := bytes #[8,255,255,255,255,255,255,255,127],
    scriptPubKey := bytes #[8,255,255,255,255,255,255,255,127,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x08ffffffffffffff7f | 0x08 0xFFFFFFFFFFFFFF7F EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0312. -/
def scriptVectors_0312 : ScrVec :=
  { id := "sc-0312", scriptSig := bytes #[79],
    scriptPubKey := bytes #[1,129,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Numbers are little-endian with the MSB being a sign bit" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0313. -/
def scriptVectors_0313 : ScrVec :=
  { id := "sc-0313", scriptSig := bytes #[1,255],
    scriptPubKey := bytes #[1,255,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-127 | 0x01 0xFF EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0314. -/
def scriptVectors_0314 : ScrVec :=
  { id := "sc-0314", scriptSig := bytes #[2,128,128],
    scriptPubKey := bytes #[2,128,128,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-128 | 0x02 0x8080 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0315. -/
def scriptVectors_0315 : ScrVec :=
  { id := "sc-0315", scriptSig := bytes #[2,255,255],
    scriptPubKey := bytes #[2,255,255,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-32767 | 0x02 0xFFFF EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0316. -/
def scriptVectors_0316 : ScrVec :=
  { id := "sc-0316", scriptSig := bytes #[3,0,128,128],
    scriptPubKey := bytes #[3,0,128,128,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-32768 | 0x03 0x008080 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0317. -/
def scriptVectors_0317 : ScrVec :=
  { id := "sc-0317", scriptSig := bytes #[3,255,255,255],
    scriptPubKey := bytes #[3,255,255,255,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-8388607 | 0x03 0xFFFFFF EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0318. -/
def scriptVectors_0318 : ScrVec :=
  { id := "sc-0318", scriptSig := bytes #[4,0,0,128,128],
    scriptPubKey := bytes #[4,0,0,128,128,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-8388608 | 0x04 0x00008080 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0319. -/
def scriptVectors_0319 : ScrVec :=
  { id := "sc-0319", scriptSig := bytes #[4,255,255,255,255],
    scriptPubKey := bytes #[4,255,255,255,255,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-2147483647 | 0x04 0xFFFFFFFF EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0320. -/
def scriptVectors_0320 : ScrVec :=
  { id := "sc-0320", scriptSig := bytes #[5,0,0,0,128,128],
    scriptPubKey := bytes #[5,0,0,0,128,128,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-2147483648 | 0x05 0x0000008080 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0321. -/
def scriptVectors_0321 : ScrVec :=
  { id := "sc-0321", scriptSig := bytes #[5,255,255,255,255,128],
    scriptPubKey := bytes #[5,255,255,255,255,128,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-4294967295 | 0x05 0xFFFFFFFF80 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0322. -/
def scriptVectors_0322 : ScrVec :=
  { id := "sc-0322", scriptSig := bytes #[5,255,255,255,255,255],
    scriptPubKey := bytes #[5,255,255,255,255,255,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x05ffffffffff | 0x05 0xFFFFFFFFFF EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0323. -/
def scriptVectors_0323 : ScrVec :=
  { id := "sc-0323", scriptSig := bytes #[6,0,0,0,0,128,128],
    scriptPubKey := bytes #[6,0,0,0,0,128,128,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x06000000008080 | 0x06 0x000000008080 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0324. -/
def scriptVectors_0324 : ScrVec :=
  { id := "sc-0324", scriptSig := bytes #[8,255,255,255,255,255,255,255,255],
    scriptPubKey := bytes #[8,255,255,255,255,255,255,255,255,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x08ffffffffffffffff | 0x08 0xFFFFFFFFFFFFFFFF EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0325. -/
def scriptVectors_0325 : ScrVec :=
  { id := "sc-0325", scriptSig := bytes #[4,255,255,255,127],
    scriptPubKey := bytes #[139,5,0,0,0,128,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "We can do math on 4-byte integers, and compare 5-byte ones" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0326. -/
def scriptVectors_0326 : ScrVec :=
  { id := "sc-0326", scriptSig := bytes #[4,255,255,255,127],
    scriptPubKey := bytes #[139,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2147483647 | 1ADD 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0327. -/
def scriptVectors_0327 : ScrVec :=
  { id := "sc-0327", scriptSig := bytes #[4,255,255,255,255],
    scriptPubKey := bytes #[139,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-2147483647 | 1ADD 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0328. -/
def scriptVectors_0328 : ScrVec :=
  { id := "sc-0328", scriptSig := bytes #[81],
    scriptPubKey := bytes #[2,1,0,135,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Not the same byte array..." }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0329. -/
def scriptVectors_0329 : ScrVec :=
  { id := "sc-0329", scriptSig := bytes #[81],
    scriptPubKey := bytes #[2,1,0,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "... but they are numerically equal" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0330. -/
def scriptVectors_0330 : ScrVec :=
  { id := "sc-0330", scriptSig := bytes #[91],
    scriptPubKey := bytes #[76,3,11,0,0,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "11 | 0x4c 0x03 0x0b0000 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0331. -/
def scriptVectors_0331 : ScrVec :=
  { id := "sc-0331", scriptSig := bytes #[0],
    scriptPubKey := bytes #[1,128,135,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | 0x01 0x80 EQUAL NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0332. -/
def scriptVectors_0332 : ScrVec :=
  { id := "sc-0332", scriptSig := bytes #[0],
    scriptPubKey := bytes #[1,128,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Zero numerically equals negative zero" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0333. -/
def scriptVectors_0333 : ScrVec :=
  { id := "sc-0333", scriptSig := bytes #[0],
    scriptPubKey := bytes #[2,0,128,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | 0x02 0x0080 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0334. -/
def scriptVectors_0334 : ScrVec :=
  { id := "sc-0334", scriptSig := bytes #[3,0,0,128],
    scriptPubKey := bytes #[4,0,0,0,128,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x03 0x000080 | 0x04 0x00000080 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0335. -/
def scriptVectors_0335 : ScrVec :=
  { id := "sc-0335", scriptSig := bytes #[3,16,0,128],
    scriptPubKey := bytes #[4,16,0,0,128,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x03 0x100080 | 0x04 0x10000080 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0336. -/
def scriptVectors_0336 : ScrVec :=
  { id := "sc-0336", scriptSig := bytes #[3,16,0,0],
    scriptPubKey := bytes #[4,16,0,0,0,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x03 0x100000 | 0x04 0x10000000 NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0337. -/
def scriptVectors_0337 : ScrVec :=
  { id := "sc-0337", scriptSig := bytes #[97],
    scriptPubKey := bytes #[97,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "The following tests check the if(stack.size() < N) tests in each opcode" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0338. -/
def scriptVectors_0338 : ScrVec :=
  { id := "sc-0338", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "They are here to catch copy-and-paste errors" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0339. -/
def scriptVectors_0339 : ScrVec :=
  { id := "sc-0339", scriptSig := bytes #[0],
    scriptPubKey := bytes #[100,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Most of them are duplicated elsewhere," }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0340. -/
def scriptVectors_0340 : ScrVec :=
  { id := "sc-0340", scriptSig := bytes #[81],
    scriptPubKey := bytes #[105,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "but, hey, more is always better, right?" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0341. -/
def scriptVectors_0341 : ScrVec :=
  { id := "sc-0341", scriptSig := bytes #[0],
    scriptPubKey := bytes #[107,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | TOALTSTACK 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0342. -/
def scriptVectors_0342 : ScrVec :=
  { id := "sc-0342", scriptSig := bytes #[81],
    scriptPubKey := bytes #[107,108],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | TOALTSTACK FROMALTSTACK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0343. -/
def scriptVectors_0343 : ScrVec :=
  { id := "sc-0343", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[109,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 | 2DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0344. -/
def scriptVectors_0344 : ScrVec :=
  { id := "sc-0344", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[110],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 1 | 2DUP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0345. -/
def scriptVectors_0345 : ScrVec :=
  { id := "sc-0345", scriptSig := bytes #[0,0,81],
    scriptPubKey := bytes #[111],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 1 | 3DUP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0346. -/
def scriptVectors_0346 : ScrVec :=
  { id := "sc-0346", scriptSig := bytes #[0,81,0,0],
    scriptPubKey := bytes #[112],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 1 0 0 | 2OVER" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0347. -/
def scriptVectors_0347 : ScrVec :=
  { id := "sc-0347", scriptSig := bytes #[0,81,0,0,0,0],
    scriptPubKey := bytes #[113],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 1 0 0 0 0 | 2ROT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0348. -/
def scriptVectors_0348 : ScrVec :=
  { id := "sc-0348", scriptSig := bytes #[0,81,0,0],
    scriptPubKey := bytes #[114],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 1 0 0 | 2SWAP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0349. -/
def scriptVectors_0349 : ScrVec :=
  { id := "sc-0349", scriptSig := bytes #[81],
    scriptPubKey := bytes #[115],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | IFDUP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0350. -/
def scriptVectors_0350 : ScrVec :=
  { id := "sc-0350", scriptSig := bytes #[97],
    scriptPubKey := bytes #[116,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | DEPTH 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0351. -/
def scriptVectors_0351 : ScrVec :=
  { id := "sc-0351", scriptSig := bytes #[0],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0352. -/
def scriptVectors_0352 : ScrVec :=
  { id := "sc-0352", scriptSig := bytes #[81],
    scriptPubKey := bytes #[118],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | DUP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0353. -/
def scriptVectors_0353 : ScrVec :=
  { id := "sc-0353", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[119],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 1 | NIP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0354. -/
def scriptVectors_0354 : ScrVec :=
  { id := "sc-0354", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[120],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | OVER" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0355. -/
def scriptVectors_0355 : ScrVec :=
  { id := "sc-0355", scriptSig := bytes #[81,0,0,0,83],
    scriptPubKey := bytes #[121],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 0 0 3 | PICK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0356. -/
def scriptVectors_0356 : ScrVec :=
  { id := "sc-0356", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[121],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | PICK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0357. -/
def scriptVectors_0357 : ScrVec :=
  { id := "sc-0357", scriptSig := bytes #[81,0,0,0,83],
    scriptPubKey := bytes #[122],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 0 0 3 | ROLL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0358. -/
def scriptVectors_0358 : ScrVec :=
  { id := "sc-0358", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[122],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | ROLL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0359. -/
def scriptVectors_0359 : ScrVec :=
  { id := "sc-0359", scriptSig := bytes #[81,0,0],
    scriptPubKey := bytes #[123],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 0 | ROT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0360. -/
def scriptVectors_0360 : ScrVec :=
  { id := "sc-0360", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[124],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | SWAP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0361. -/
def scriptVectors_0361 : ScrVec :=
  { id := "sc-0361", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[125],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 1 | TUCK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0362. -/
def scriptVectors_0362 : ScrVec :=
  { id := "sc-0362", scriptSig := bytes #[81],
    scriptPubKey := bytes #[130],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | SIZE" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0363. -/
def scriptVectors_0363 : ScrVec :=
  { id := "sc-0363", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 | EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0364. -/
def scriptVectors_0364 : ScrVec :=
  { id := "sc-0364", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[136,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 | EQUALVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0365. -/
def scriptVectors_0365 : ScrVec :=
  { id := "sc-0365", scriptSig := bytes #[0,0,81],
    scriptPubKey := bytes #[135,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "OP_0 and bools must have identical byte representations" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0366. -/
def scriptVectors_0366 : ScrVec :=
  { id := "sc-0366", scriptSig := bytes #[0],
    scriptPubKey := bytes #[139],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | 1ADD" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0367. -/
def scriptVectors_0367 : ScrVec :=
  { id := "sc-0367", scriptSig := bytes #[82],
    scriptPubKey := bytes #[140],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2 | 1SUB" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0368. -/
def scriptVectors_0368 : ScrVec :=
  { id := "sc-0368", scriptSig := bytes #[79],
    scriptPubKey := bytes #[143],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 | NEGATE" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0369. -/
def scriptVectors_0369 : ScrVec :=
  { id := "sc-0369", scriptSig := bytes #[79],
    scriptPubKey := bytes #[144],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 | ABS" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0370. -/
def scriptVectors_0370 : ScrVec :=
  { id := "sc-0370", scriptSig := bytes #[0],
    scriptPubKey := bytes #[145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0371. -/
def scriptVectors_0371 : ScrVec :=
  { id := "sc-0371", scriptSig := bytes #[79],
    scriptPubKey := bytes #[146],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 | 0NOTEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0372. -/
def scriptVectors_0372 : ScrVec :=
  { id := "sc-0372", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[147],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | ADD" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0373. -/
def scriptVectors_0373 : ScrVec :=
  { id := "sc-0373", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[148],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | SUB" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0374. -/
def scriptVectors_0374 : ScrVec :=
  { id := "sc-0374", scriptSig := bytes #[79,79],
    scriptPubKey := bytes #[154],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 -1 | BOOLAND" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0375. -/
def scriptVectors_0375 : ScrVec :=
  { id := "sc-0375", scriptSig := bytes #[79,0],
    scriptPubKey := bytes #[155],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 0 | BOOLOR" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0376. -/
def scriptVectors_0376 : ScrVec :=
  { id := "sc-0376", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 | NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0377. -/
def scriptVectors_0377 : ScrVec :=
  { id := "sc-0377", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[157,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 | NUMEQUALVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0378. -/
def scriptVectors_0378 : ScrVec :=
  { id := "sc-0378", scriptSig := bytes #[82,0],
    scriptPubKey := bytes #[157],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "NUMEQUALVERIFY",
    comment := "2 0 | NUMEQUALVERIFY" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0379. -/
def scriptVectors_0379 : ScrVec :=
  { id := "sc-0379", scriptSig := bytes #[79,0],
    scriptPubKey := bytes #[158],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 0 | NUMNOTEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0380. -/
def scriptVectors_0380 : ScrVec :=
  { id := "sc-0380", scriptSig := bytes #[79,0],
    scriptPubKey := bytes #[159],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 0 | LESSTHAN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0381. -/
def scriptVectors_0381 : ScrVec :=
  { id := "sc-0381", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[160],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | GREATERTHAN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0382. -/
def scriptVectors_0382 : ScrVec :=
  { id := "sc-0382", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[161],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 | LESSTHANOREQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0383. -/
def scriptVectors_0383 : ScrVec :=
  { id := "sc-0383", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[162],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 | GREATERTHANOREQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0384. -/
def scriptVectors_0384 : ScrVec :=
  { id := "sc-0384", scriptSig := bytes #[79,0],
    scriptPubKey := bytes #[163],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 0 | MIN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0385. -/
def scriptVectors_0385 : ScrVec :=
  { id := "sc-0385", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[164],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 0 | MAX" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0386. -/
def scriptVectors_0386 : ScrVec :=
  { id := "sc-0386", scriptSig := bytes #[79,79,0],
    scriptPubKey := bytes #[165],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "-1 -1 0 | WITHIN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0387. -/
def scriptVectors_0387 : ScrVec :=
  { id := "sc-0387", scriptSig := bytes #[0],
    scriptPubKey := bytes #[166],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | RIPEMD160" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0388. -/
def scriptVectors_0388 : ScrVec :=
  { id := "sc-0388", scriptSig := bytes #[0],
    scriptPubKey := bytes #[167],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | SHA1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0389. -/
def scriptVectors_0389 : ScrVec :=
  { id := "sc-0389", scriptSig := bytes #[0],
    scriptPubKey := bytes #[168],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | SHA256" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0390. -/
def scriptVectors_0390 : ScrVec :=
  { id := "sc-0390", scriptSig := bytes #[0],
    scriptPubKey := bytes #[169],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | HASH160" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0391. -/
def scriptVectors_0391 : ScrVec :=
  { id := "sc-0391", scriptSig := bytes #[0],
    scriptPubKey := bytes #[170],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | HASH256" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0392. -/
def scriptVectors_0392 : ScrVec :=
  { id := "sc-0392", scriptSig := bytes #[97],
    scriptPubKey := bytes #[171,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | CODESEPARATOR 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0393. -/
def scriptVectors_0393 : ScrVec :=
  { id := "sc-0393", scriptSig := bytes #[97],
    scriptPubKey := bytes #[176,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | NOP1 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0394. -/
def scriptVectors_0394 : ScrVec :=
  { id := "sc-0394", scriptSig := bytes #[97],
    scriptPubKey := bytes #[177,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | CHECKLOCKTIMEVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0395. -/
def scriptVectors_0395 : ScrVec :=
  { id := "sc-0395", scriptSig := bytes #[97],
    scriptPubKey := bytes #[178,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | CHECKSEQUENCEVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0396. -/
def scriptVectors_0396 : ScrVec :=
  { id := "sc-0396", scriptSig := bytes #[97],
    scriptPubKey := bytes #[179,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | NOP4 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0397. -/
def scriptVectors_0397 : ScrVec :=
  { id := "sc-0397", scriptSig := bytes #[97],
    scriptPubKey := bytes #[180,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | NOP5 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0398. -/
def scriptVectors_0398 : ScrVec :=
  { id := "sc-0398", scriptSig := bytes #[97],
    scriptPubKey := bytes #[181,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | NOP6 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0399. -/
def scriptVectors_0399 : ScrVec :=
  { id := "sc-0399", scriptSig := bytes #[97],
    scriptPubKey := bytes #[182,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | NOP7 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0400. -/
def scriptVectors_0400 : ScrVec :=
  { id := "sc-0400", scriptSig := bytes #[97],
    scriptPubKey := bytes #[183,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | NOP8 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0401. -/
def scriptVectors_0401 : ScrVec :=
  { id := "sc-0401", scriptSig := bytes #[97],
    scriptPubKey := bytes #[184,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | NOP9 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0402. -/
def scriptVectors_0402 : ScrVec :=
  { id := "sc-0402", scriptSig := bytes #[97],
    scriptPubKey := bytes #[185,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "NOP | NOP10 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0403. -/
def scriptVectors_0403 : ScrVec :=
  { id := "sc-0403", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,0,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "CHECKMULTISIG is allowed to have zero keys and/or sigs" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0404. -/
def scriptVectors_0404 : ScrVec :=
  { id := "sc-0404", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,0,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 0 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0405. -/
def scriptVectors_0405 : ScrVec :=
  { id := "sc-0405", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,0,81,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Zero sigs means no sigs are checked" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0406. -/
def scriptVectors_0406 : ScrVec :=
  { id := "sc-0406", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,0,81,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 0 1 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0407. -/
def scriptVectors_0407 : ScrVec :=
  { id := "sc-0407", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,0,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "CHECKMULTISIG is allowed to have zero keys and/or sigs" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0408. -/
def scriptVectors_0408 : ScrVec :=
  { id := "sc-0408", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,0,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 0 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0409. -/
def scriptVectors_0409 : ScrVec :=
  { id := "sc-0409", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,0,81,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Zero sigs means no sigs are checked" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0410. -/
def scriptVectors_0410 : ScrVec :=
  { id := "sc-0410", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,0,81,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 0 1 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0411. -/
def scriptVectors_0411 : ScrVec :=
  { id := "sc-0411", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,82,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Test from up to 20 pubkeys, all not checked" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0412. -/
def scriptVectors_0412 : ScrVec :=
  { id := "sc-0412", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,83,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 3 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0413. -/
def scriptVectors_0413 : ScrVec :=
  { id := "sc-0413", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,84,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 4 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0414. -/
def scriptVectors_0414 : ScrVec :=
  { id := "sc-0414", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,85,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 5 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0415. -/
def scriptVectors_0415 : ScrVec :=
  { id := "sc-0415", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,86,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 6 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0416. -/
def scriptVectors_0416 : ScrVec :=
  { id := "sc-0416", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,87,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 7 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0417. -/
def scriptVectors_0417 : ScrVec :=
  { id := "sc-0417", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,88,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 8 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0418. -/
def scriptVectors_0418 : ScrVec :=
  { id := "sc-0418", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,89,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 9 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0419. -/
def scriptVectors_0419 : ScrVec :=
  { id := "sc-0419", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,90,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 10 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0420. -/
def scriptVectors_0420 : ScrVec :=
  { id := "sc-0420", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,91,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 11 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0421. -/
def scriptVectors_0421 : ScrVec :=
  { id := "sc-0421", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,92,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 12 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0422. -/
def scriptVectors_0422 : ScrVec :=
  { id := "sc-0422", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,93,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 13 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0423. -/
def scriptVectors_0423 : ScrVec :=
  { id := "sc-0423", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,94,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 14 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0424. -/
def scriptVectors_0424 : ScrVec :=
  { id := "sc-0424", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,95,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 15 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0425. -/
def scriptVectors_0425 : ScrVec :=
  { id := "sc-0425", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,96,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 16 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0426. -/
def scriptVectors_0426 : ScrVec :=
  { id := "sc-0426", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,17,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 'q' 17 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0427. -/
def scriptVectors_0427 : ScrVec :=
  { id := "sc-0427", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,18,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 'q' 'r' 18 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0428. -/
def scriptVectors_0428 : ScrVec :=
  { id := "sc-0428", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,19,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 'q' 'r' 's' 19 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0429. -/
def scriptVectors_0429 : ScrVec :=
  { id := "sc-0429", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,105,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 'q' 'r' 's' 't' 20 CHECKMULTISIG VERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0430. -/
def scriptVectors_0430 : ScrVec :=
  { id := "sc-0430", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,81,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 1 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0431. -/
def scriptVectors_0431 : ScrVec :=
  { id := "sc-0431", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,82,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 2 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0432. -/
def scriptVectors_0432 : ScrVec :=
  { id := "sc-0432", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,83,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 3 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0433. -/
def scriptVectors_0433 : ScrVec :=
  { id := "sc-0433", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,84,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 4 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0434. -/
def scriptVectors_0434 : ScrVec :=
  { id := "sc-0434", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,85,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 5 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0435. -/
def scriptVectors_0435 : ScrVec :=
  { id := "sc-0435", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,86,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 6 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0436. -/
def scriptVectors_0436 : ScrVec :=
  { id := "sc-0436", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,87,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 7 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0437. -/
def scriptVectors_0437 : ScrVec :=
  { id := "sc-0437", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,88,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 8 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0438. -/
def scriptVectors_0438 : ScrVec :=
  { id := "sc-0438", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,89,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 9 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0439. -/
def scriptVectors_0439 : ScrVec :=
  { id := "sc-0439", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,90,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 10 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0440. -/
def scriptVectors_0440 : ScrVec :=
  { id := "sc-0440", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,91,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 11 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0441. -/
def scriptVectors_0441 : ScrVec :=
  { id := "sc-0441", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,92,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 12 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0442. -/
def scriptVectors_0442 : ScrVec :=
  { id := "sc-0442", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,93,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 13 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0443. -/
def scriptVectors_0443 : ScrVec :=
  { id := "sc-0443", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,94,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 14 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0444. -/
def scriptVectors_0444 : ScrVec :=
  { id := "sc-0444", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,95,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 15 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0445. -/
def scriptVectors_0445 : ScrVec :=
  { id := "sc-0445", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,96,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 16 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0446. -/
def scriptVectors_0446 : ScrVec :=
  { id := "sc-0446", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,17,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 'q' 17 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0447. -/
def scriptVectors_0447 : ScrVec :=
  { id := "sc-0447", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,18,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 'q' 'r' 18 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0448. -/
def scriptVectors_0448 : ScrVec :=
  { id := "sc-0448", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,19,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 'q' 'r' 's' 19 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0449. -/
def scriptVectors_0449 : ScrVec :=
  { id := "sc-0449", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 'q' 'r' 's' 't' 20 CHECKMULTISIGVERIFY DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0450. -/
def scriptVectors_0450 : ScrVec :=
  { id := "sc-0450", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "nOpCount is incremented by the number of keys evaluated in addition to the usual one op per op. In this case we have zero keys, so we can execute 201 CHECKMULTI" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0451. -/
def scriptVectors_0451 : ScrVec :=
  { id := "sc-0451", scriptSig := bytes #[81],
    scriptPubKey := bytes #[0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175,0,0,0,175],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | 0 0 0 CHECKMULTISIGVERIFY 0 0 0 CHECKMULTISIGVERIFY 0 0 0 CHECKMULTISIGVERIFY 0 0 0 CHECKMULTISIGVERIFY 0 0 0 CHECKMULTISIGVERIFY 0 0 0 CHECKMULTISIGVERIFY " }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0452. -/
def scriptVectors_0452 : ScrVec :=
  { id := "sc-0452", scriptSig := bytes #[],
    scriptPubKey := bytes #[97,97,97,97,97,97,97,97,97,97,97,97,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Even though there are no signatures being checked nOpCount is incremented by the number of keys." }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0453. -/
def scriptVectors_0453 : ScrVec :=
  { id := "sc-0453", scriptSig := bytes #[81],
    scriptPubKey := bytes #[97,97,97,97,97,97,97,97,97,97,97,97,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1 | NOP NOP NOP NOP NOP NOP NOP NOP NOP NOP NOP NOP 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 'q' 'r' 's' 't' 20 CHECKMULTISIGVERIFY 0" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0454. -/
def scriptVectors_0454 : ScrVec :=
  { id := "sc-0454", scriptSig := bytes #[0,1,81],
    scriptPubKey := bytes #[169,20,218,23,69,233,181,73,189,11,250,26,86,153,113,199,126,186,48,205,90,75,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Very basic P2SH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0455. -/
def scriptVectors_0455 : ScrVec :=
  { id := "sc-0455", scriptSig := bytes #[76,0,1,81],
    scriptPubKey := bytes #[169,20,218,23,69,233,181,73,189,11,250,26,86,153,113,199,126,186,48,205,90,75,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0x4c 0 0x01 1 | HASH160 0x14 0xda1745e9b549bd0bfa1a569971c77eba30cd5a4b EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0456. -/
def scriptVectors_0456 : ScrVec :=
  { id := "sc-0456", scriptSig := bytes #[64,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66],
    scriptPubKey := bytes #[77,64,0,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Basic PUSH signedness check" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0457. -/
def scriptVectors_0457 : ScrVec :=
  { id := "sc-0457", scriptSig := bytes #[76,64,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66],
    scriptPubKey := bytes #[77,64,0,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,66,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Basic PUSHDATA1 signedness check" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0458. -/
def scriptVectors_0458 : ScrVec :=
  { id := "sc-0458", scriptSig := bytes #[76,75,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17],
    scriptPubKey := bytes #[75,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "PUSHDATA1 of 75 bytes equals direct push of it" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0459. -/
def scriptVectors_0459 : ScrVec :=
  { id := "sc-0459", scriptSig := bytes #[77,255,0,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17],
    scriptPubKey := bytes #[76,255,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "PUSHDATA2 of 255 bytes equals PUSHDATA1 of it" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0460. -/
def scriptVectors_0460 : ScrVec :=
  { id := "sc-0460", scriptSig := bytes #[0],
    scriptPubKey := bytes #[130,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "Basic OP_0 execution" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0461. -/
def scriptVectors_0461 : ScrVec :=
  { id := "sc-0461", scriptSig := bytes #[1,129],
    scriptPubKey := bytes #[79,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP1_NEGATE pushes 0x81" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0462. -/
def scriptVectors_0462 : ScrVec :=
  { id := "sc-0462", scriptSig := bytes #[1,1],
    scriptPubKey := bytes #[81,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_1  pushes 0x01" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0463. -/
def scriptVectors_0463 : ScrVec :=
  { id := "sc-0463", scriptSig := bytes #[1,2],
    scriptPubKey := bytes #[82,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_2  pushes 0x02" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0464. -/
def scriptVectors_0464 : ScrVec :=
  { id := "sc-0464", scriptSig := bytes #[1,3],
    scriptPubKey := bytes #[83,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_3  pushes 0x03" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0465. -/
def scriptVectors_0465 : ScrVec :=
  { id := "sc-0465", scriptSig := bytes #[1,4],
    scriptPubKey := bytes #[84,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_4  pushes 0x04" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0466. -/
def scriptVectors_0466 : ScrVec :=
  { id := "sc-0466", scriptSig := bytes #[1,5],
    scriptPubKey := bytes #[85,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_5  pushes 0x05" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0467. -/
def scriptVectors_0467 : ScrVec :=
  { id := "sc-0467", scriptSig := bytes #[1,6],
    scriptPubKey := bytes #[86,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_6  pushes 0x06" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0468. -/
def scriptVectors_0468 : ScrVec :=
  { id := "sc-0468", scriptSig := bytes #[1,7],
    scriptPubKey := bytes #[87,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_7  pushes 0x07" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0469. -/
def scriptVectors_0469 : ScrVec :=
  { id := "sc-0469", scriptSig := bytes #[1,8],
    scriptPubKey := bytes #[88,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_8  pushes 0x08" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0470. -/
def scriptVectors_0470 : ScrVec :=
  { id := "sc-0470", scriptSig := bytes #[1,9],
    scriptPubKey := bytes #[89,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_9  pushes 0x09" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0471. -/
def scriptVectors_0471 : ScrVec :=
  { id := "sc-0471", scriptSig := bytes #[1,10],
    scriptPubKey := bytes #[90,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_10 pushes 0x0a" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0472. -/
def scriptVectors_0472 : ScrVec :=
  { id := "sc-0472", scriptSig := bytes #[1,11],
    scriptPubKey := bytes #[91,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_11 pushes 0x0b" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0473. -/
def scriptVectors_0473 : ScrVec :=
  { id := "sc-0473", scriptSig := bytes #[1,12],
    scriptPubKey := bytes #[92,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_12 pushes 0x0c" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0474. -/
def scriptVectors_0474 : ScrVec :=
  { id := "sc-0474", scriptSig := bytes #[1,13],
    scriptPubKey := bytes #[93,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_13 pushes 0x0d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0475. -/
def scriptVectors_0475 : ScrVec :=
  { id := "sc-0475", scriptSig := bytes #[1,14],
    scriptPubKey := bytes #[94,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_14 pushes 0x0e" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0476. -/
def scriptVectors_0476 : ScrVec :=
  { id := "sc-0476", scriptSig := bytes #[1,15],
    scriptPubKey := bytes #[95,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_15 pushes 0x0f" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0477. -/
def scriptVectors_0477 : ScrVec :=
  { id := "sc-0477", scriptSig := bytes #[1,16],
    scriptPubKey := bytes #[96,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "OP_16 pushes 0x10" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0478. -/
def scriptVectors_0478 : ScrVec :=
  { id := "sc-0478", scriptSig := bytes #[2,128,0],
    scriptPubKey := bytes #[2,128,0,156],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x8000 equals 128" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0479. -/
def scriptVectors_0479 : ScrVec :=
  { id := "sc-0479", scriptSig := bytes #[1,0],
    scriptPubKey := bytes #[0,156],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x00 numequals 0" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0480. -/
def scriptVectors_0480 : ScrVec :=
  { id := "sc-0480", scriptSig := bytes #[1,128],
    scriptPubKey := bytes #[0,156],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x80 (negative zero) numequals 0" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0481. -/
def scriptVectors_0481 : ScrVec :=
  { id := "sc-0481", scriptSig := bytes #[2,0,128],
    scriptPubKey := bytes #[0,156],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x0080 numequals 0" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0482. -/
def scriptVectors_0482 : ScrVec :=
  { id := "sc-0482", scriptSig := bytes #[2,5,0],
    scriptPubKey := bytes #[85,156],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x0500 numequals 5" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0483. -/
def scriptVectors_0483 : ScrVec :=
  { id := "sc-0483", scriptSig := bytes #[3,255,127,128],
    scriptPubKey := bytes #[2,255,255,156],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x03 0xff7f80 | 0x02 0xffff NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0484. -/
def scriptVectors_0484 : ScrVec :=
  { id := "sc-0484", scriptSig := bytes #[3,255,127,0],
    scriptPubKey := bytes #[2,255,127,156],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x03 0xff7f00 | 0x02 0xff7f NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0485. -/
def scriptVectors_0485 : ScrVec :=
  { id := "sc-0485", scriptSig := bytes #[4,255,255,127,128],
    scriptPubKey := bytes #[3,255,255,255,156],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x04 0xffff7f80 | 0x03 0xffffff NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0486. -/
def scriptVectors_0486 : ScrVec :=
  { id := "sc-0486", scriptSig := bytes #[4,255,255,127,0],
    scriptPubKey := bytes #[3,255,255,127,156],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x04 0xffff7f00 | 0x03 0xffff7f NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0487. -/
def scriptVectors_0487 : ScrVec :=
  { id := "sc-0487", scriptSig := bytes #[0,99,76,0,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "non-minimal PUSHDATA1 ignored" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0488. -/
def scriptVectors_0488 : ScrVec :=
  { id := "sc-0488", scriptSig := bytes #[0,99,77,0,0,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "non-minimal PUSHDATA2 ignored" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0489. -/
def scriptVectors_0489 : ScrVec :=
  { id := "sc-0489", scriptSig := bytes #[0,99,76,0,0,0,0,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "non-minimal PUSHDATA4 ignored" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0490. -/
def scriptVectors_0490 : ScrVec :=
  { id := "sc-0490", scriptSig := bytes #[0,99,1,129,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "1NEGATE equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0491. -/
def scriptVectors_0491 : ScrVec :=
  { id := "sc-0491", scriptSig := bytes #[0,99,1,1,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_1  equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0492. -/
def scriptVectors_0492 : ScrVec :=
  { id := "sc-0492", scriptSig := bytes #[0,99,1,2,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_2  equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0493. -/
def scriptVectors_0493 : ScrVec :=
  { id := "sc-0493", scriptSig := bytes #[0,99,1,3,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_3  equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0494. -/
def scriptVectors_0494 : ScrVec :=
  { id := "sc-0494", scriptSig := bytes #[0,99,1,4,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_4  equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0495. -/
def scriptVectors_0495 : ScrVec :=
  { id := "sc-0495", scriptSig := bytes #[0,99,1,5,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_5  equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0496. -/
def scriptVectors_0496 : ScrVec :=
  { id := "sc-0496", scriptSig := bytes #[0,99,1,6,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_6  equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0497. -/
def scriptVectors_0497 : ScrVec :=
  { id := "sc-0497", scriptSig := bytes #[0,99,1,7,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_7  equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0498. -/
def scriptVectors_0498 : ScrVec :=
  { id := "sc-0498", scriptSig := bytes #[0,99,1,8,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_8  equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0499. -/
def scriptVectors_0499 : ScrVec :=
  { id := "sc-0499", scriptSig := bytes #[0,99,1,9,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_9  equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0500. -/
def scriptVectors_0500 : ScrVec :=
  { id := "sc-0500", scriptSig := bytes #[0,99,1,10,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_10 equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0501. -/
def scriptVectors_0501 : ScrVec :=
  { id := "sc-0501", scriptSig := bytes #[0,99,1,11,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_11 equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0502. -/
def scriptVectors_0502 : ScrVec :=
  { id := "sc-0502", scriptSig := bytes #[0,99,1,12,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_12 equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0503. -/
def scriptVectors_0503 : ScrVec :=
  { id := "sc-0503", scriptSig := bytes #[0,99,1,13,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_13 equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0504. -/
def scriptVectors_0504 : ScrVec :=
  { id := "sc-0504", scriptSig := bytes #[0,99,1,14,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_14 equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0505. -/
def scriptVectors_0505 : ScrVec :=
  { id := "sc-0505", scriptSig := bytes #[0,99,1,15,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_15 equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0506. -/
def scriptVectors_0506 : ScrVec :=
  { id := "sc-0506", scriptSig := bytes #[0,99,1,16,104,81],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "OP_16 equiv" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0507. -/
def scriptVectors_0507 : ScrVec :=
  { id := "sc-0507", scriptSig := bytes #[1,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x01 0x00 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0508. -/
def scriptVectors_0508 : ScrVec :=
  { id := "sc-0508", scriptSig := bytes #[1,128],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x01 0x80 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0509. -/
def scriptVectors_0509 : ScrVec :=
  { id := "sc-0509", scriptSig := bytes #[2,1,128],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0180 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0510. -/
def scriptVectors_0510 : ScrVec :=
  { id := "sc-0510", scriptSig := bytes #[2,1,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0100 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0511. -/
def scriptVectors_0511 : ScrVec :=
  { id := "sc-0511", scriptSig := bytes #[2,2,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0200 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0512. -/
def scriptVectors_0512 : ScrVec :=
  { id := "sc-0512", scriptSig := bytes #[2,3,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0300 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0513. -/
def scriptVectors_0513 : ScrVec :=
  { id := "sc-0513", scriptSig := bytes #[2,4,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0400 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0514. -/
def scriptVectors_0514 : ScrVec :=
  { id := "sc-0514", scriptSig := bytes #[2,5,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0500 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0515. -/
def scriptVectors_0515 : ScrVec :=
  { id := "sc-0515", scriptSig := bytes #[2,6,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0600 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0516. -/
def scriptVectors_0516 : ScrVec :=
  { id := "sc-0516", scriptSig := bytes #[2,7,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0700 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0517. -/
def scriptVectors_0517 : ScrVec :=
  { id := "sc-0517", scriptSig := bytes #[2,8,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0800 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0518. -/
def scriptVectors_0518 : ScrVec :=
  { id := "sc-0518", scriptSig := bytes #[2,9,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0900 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0519. -/
def scriptVectors_0519 : ScrVec :=
  { id := "sc-0519", scriptSig := bytes #[2,10,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0a00 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0520. -/
def scriptVectors_0520 : ScrVec :=
  { id := "sc-0520", scriptSig := bytes #[2,11,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0b00 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0521. -/
def scriptVectors_0521 : ScrVec :=
  { id := "sc-0521", scriptSig := bytes #[2,12,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0c00 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0522. -/
def scriptVectors_0522 : ScrVec :=
  { id := "sc-0522", scriptSig := bytes #[2,13,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0d00 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0523. -/
def scriptVectors_0523 : ScrVec :=
  { id := "sc-0523", scriptSig := bytes #[2,14,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0e00 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0524. -/
def scriptVectors_0524 : ScrVec :=
  { id := "sc-0524", scriptSig := bytes #[2,15,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0f00 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0525. -/
def scriptVectors_0525 : ScrVec :=
  { id := "sc-0525", scriptSig := bytes #[2,16,0],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x1000 | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0526. -/
def scriptVectors_0526 : ScrVec :=
  { id := "sc-0526", scriptSig := bytes #[81,2,0,0],
    scriptPubKey := bytes #[121,117],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "1 0x02 0x0000 | PICK DROP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0527. -/
def scriptVectors_0527 : ScrVec :=
  { id := "sc-0527", scriptSig := bytes #[81,2,0,0],
    scriptPubKey := bytes #[122,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "1 0x02 0x0000 | ROLL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0528. -/
def scriptVectors_0528 : ScrVec :=
  { id := "sc-0528", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[139,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 | 1ADD DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0529. -/
def scriptVectors_0529 : ScrVec :=
  { id := "sc-0529", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[140,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 | 1SUB DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0530. -/
def scriptVectors_0530 : ScrVec :=
  { id := "sc-0530", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[143,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 | NEGATE DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0531. -/
def scriptVectors_0531 : ScrVec :=
  { id := "sc-0531", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[144,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 | ABS DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0532. -/
def scriptVectors_0532 : ScrVec :=
  { id := "sc-0532", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 | NOT DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0533. -/
def scriptVectors_0533 : ScrVec :=
  { id := "sc-0533", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[146,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 | 0NOTEQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0534. -/
def scriptVectors_0534 : ScrVec :=
  { id := "sc-0534", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[147,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | ADD DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0535. -/
def scriptVectors_0535 : ScrVec :=
  { id := "sc-0535", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[147,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 | ADD DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0536. -/
def scriptVectors_0536 : ScrVec :=
  { id := "sc-0536", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[148,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | SUB DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0537. -/
def scriptVectors_0537 : ScrVec :=
  { id := "sc-0537", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[148,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 | SUB DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0538. -/
def scriptVectors_0538 : ScrVec :=
  { id := "sc-0538", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[154,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | BOOLAND DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0539. -/
def scriptVectors_0539 : ScrVec :=
  { id := "sc-0539", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[154,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 | BOOLAND DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0540. -/
def scriptVectors_0540 : ScrVec :=
  { id := "sc-0540", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[155,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | BOOLOR DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0541. -/
def scriptVectors_0541 : ScrVec :=
  { id := "sc-0541", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[155,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 | BOOLOR DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0542. -/
def scriptVectors_0542 : ScrVec :=
  { id := "sc-0542", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[156,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | NUMEQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0543. -/
def scriptVectors_0543 : ScrVec :=
  { id := "sc-0543", scriptSig := bytes #[2,0,0,81],
    scriptPubKey := bytes #[156,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 1 | NUMEQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0544. -/
def scriptVectors_0544 : ScrVec :=
  { id := "sc-0544", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[157,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | NUMEQUALVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0545. -/
def scriptVectors_0545 : ScrVec :=
  { id := "sc-0545", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[157,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 | NUMEQUALVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0546. -/
def scriptVectors_0546 : ScrVec :=
  { id := "sc-0546", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[158,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | NUMNOTEQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0547. -/
def scriptVectors_0547 : ScrVec :=
  { id := "sc-0547", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[158,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 | NUMNOTEQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0548. -/
def scriptVectors_0548 : ScrVec :=
  { id := "sc-0548", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[159,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | LESSTHAN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0549. -/
def scriptVectors_0549 : ScrVec :=
  { id := "sc-0549", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[159,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 | LESSTHAN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0550. -/
def scriptVectors_0550 : ScrVec :=
  { id := "sc-0550", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[160,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | GREATERTHAN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0551. -/
def scriptVectors_0551 : ScrVec :=
  { id := "sc-0551", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[160,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 | GREATERTHAN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0552. -/
def scriptVectors_0552 : ScrVec :=
  { id := "sc-0552", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[161,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | LESSTHANOREQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0553. -/
def scriptVectors_0553 : ScrVec :=
  { id := "sc-0553", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[161,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 | LESSTHANOREQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0554. -/
def scriptVectors_0554 : ScrVec :=
  { id := "sc-0554", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[162,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | GREATERTHANOREQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0555. -/
def scriptVectors_0555 : ScrVec :=
  { id := "sc-0555", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[162,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 | GREATERTHANOREQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0556. -/
def scriptVectors_0556 : ScrVec :=
  { id := "sc-0556", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[163,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | MIN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0557. -/
def scriptVectors_0557 : ScrVec :=
  { id := "sc-0557", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[163,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 | MIN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0558. -/
def scriptVectors_0558 : ScrVec :=
  { id := "sc-0558", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[164,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 | MAX DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0559. -/
def scriptVectors_0559 : ScrVec :=
  { id := "sc-0559", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[164,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 | MAX DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0560. -/
def scriptVectors_0560 : ScrVec :=
  { id := "sc-0560", scriptSig := bytes #[2,0,0,0,0],
    scriptPubKey := bytes #[165,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0000 0 0 | WITHIN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0561. -/
def scriptVectors_0561 : ScrVec :=
  { id := "sc-0561", scriptSig := bytes #[0,2,0,0,0],
    scriptPubKey := bytes #[165,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 0 | WITHIN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0562. -/
def scriptVectors_0562 : ScrVec :=
  { id := "sc-0562", scriptSig := bytes #[0,0,2,0,0],
    scriptPubKey := bytes #[165,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0 0x02 0x0000 | WITHIN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0563. -/
def scriptVectors_0563 : ScrVec :=
  { id := "sc-0563", scriptSig := bytes #[0,0,2,0,0],
    scriptPubKey := bytes #[174,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0 0x02 0x0000 | CHECKMULTISIG DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0564. -/
def scriptVectors_0564 : ScrVec :=
  { id := "sc-0564", scriptSig := bytes #[0,2,0,0,0],
    scriptPubKey := bytes #[174,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 0 | CHECKMULTISIG DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0565. -/
def scriptVectors_0565 : ScrVec :=
  { id := "sc-0565", scriptSig := bytes #[0,2,0,0,0,81],
    scriptPubKey := bytes #[174,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 0 1 | CHECKMULTISIG DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0566. -/
def scriptVectors_0566 : ScrVec :=
  { id := "sc-0566", scriptSig := bytes #[0,0,2,0,0],
    scriptPubKey := bytes #[175,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0 0x02 0x0000 | CHECKMULTISIGVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0567. -/
def scriptVectors_0567 : ScrVec :=
  { id := "sc-0567", scriptSig := bytes #[0,2,0,0,0],
    scriptPubKey := bytes #[175,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0x02 0x0000 0 | CHECKMULTISIGVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0568. -/
def scriptVectors_0568 : ScrVec :=
  { id := "sc-0568", scriptSig := bytes #[0],
    scriptPubKey := bytes #[33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 | 0x21 0x02865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac0 CHECKSIG NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0569. -/
def scriptVectors_0569 : ScrVec :=
  { id := "sc-0569", scriptSig := bytes #[0],
    scriptPubKey := bytes #[33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 | 0x21 0x02865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac0 CHECKSIG NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0570. -/
def scriptVectors_0570 : ScrVec :=
  { id := "sc-0570", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[81,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,81,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "0 0 | 1 0x21 0x02865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac0 1 CHECKMULTISIG NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0571. -/
def scriptVectors_0571 : ScrVec :=
  { id := "sc-0571", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[81,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,81,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0 0 | 1 0x21 0x02865c40293a680cb9c020e7b1e106d8c1916d3cef99aa431a56d253e69256dac0 1 CHECKMULTISIG NOT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0572. -/
def scriptVectors_0572 : ScrVec :=
  { id := "sc-0572", scriptSig := bytes #[0,71,48,68,2,32,68,220,23,176,136,124,22,27,182,123,169,99,91,247,88,115,91,221,229,3,228,176,160,152,127,88,127,20,164,225,20,61,2,32,9,162,21,119,45,73,168,93,174,64,216,202,3,149,90,242,106,211,151,138,15,249,101,250,161,41,21,233,88,98,73,165,1,71,48,68,2,32,68,220,23,176,136,124,22,27,182,123,169,99,91,247,88,115,91,221,229,3,228,176,160,152,127,88,127,20,164,225,20,61,2,32,9,162,21,119,45,73,168,93,174,64,216,202,3,149,90,242,106,211,151,138,15,249,101,250,161,41,21,233,88,98,73,165,1],
    scriptPubKey := bytes #[82,0,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,82,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2-of-2 CHECKMULTISIG NOT with the second pubkey invalid, and both signatures validly encoded. Valid pubkey fails, and CHECKMULTISIG exits early, prior to evalua" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0573. -/
def scriptVectors_0573 : ScrVec :=
  { id := "sc-0573", scriptSig := bytes #[0,81,71,48,68,2,32,68,220,23,176,136,124,22,27,182,123,169,99,91,247,88,115,91,221,229,3,228,176,160,152,127,88,127,20,164,225,20,61,2,32,9,162,21,119,45,73,168,93,174,64,216,202,3,149,90,242,106,211,151,138,15,249,101,250,161,41,21,233,88,98,73,165,1],
    scriptPubKey := bytes #[82,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,82,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "2-of-2 CHECKMULTISIG NOT with both pubkeys valid, but second signature invalid. Valid pubkey fails, and CHECKMULTISIG exits early, prior to evaluation of second" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0574. -/
def scriptVectors_0574 : ScrVec :=
  { id := "sc-0574", scriptSig := bytes #[0,81,71,48,68,2,32,68,220,23,176,136,124,22,27,182,123,169,99,91,247,88,115,91,221,229,3,228,176,160,152,127,88,127,20,164,225,20,61,2,32,9,162,21,119,45,73,168,93,174,64,216,202,3,149,90,242,106,211,151,138,15,249,101,250,161,41,21,233,88,98,73,165,1],
    scriptPubKey := bytes #[82,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,82,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "2-of-2 CHECKMULTISIG NOT with both pubkeys valid, but second signature invalid. Valid pubkey fails, and CHECKMULTISIG exits early, prior to evaluation of second" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0575. -/
def scriptVectors_0575 : ScrVec :=
  { id := "sc-0575", scriptSig := bytes #[74,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Overly long signature is correctly encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0576. -/
def scriptVectors_0576 : ScrVec :=
  { id := "sc-0576", scriptSig := bytes #[37,48,34,2,32,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Missing S is correctly encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0577. -/
def scriptVectors_0577 : ScrVec :=
  { id := "sc-0577", scriptSig := bytes #[39,48,36,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,2,10,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "S with invalid S length is correctly encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0578. -/
def scriptVectors_0578 : ScrVec :=
  { id := "sc-0578", scriptSig := bytes #[39,48,36,3,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Non-integer R is correctly encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0579. -/
def scriptVectors_0579 : ScrVec :=
  { id := "sc-0579", scriptSig := bytes #[39,48,36,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,3,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Non-integer S is correctly encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0580. -/
def scriptVectors_0580 : ScrVec :=
  { id := "sc-0580", scriptSig := bytes #[23,48,20,2,0,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Zero-length R is correctly encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0581. -/
def scriptVectors_0581 : ScrVec :=
  { id := "sc-0581", scriptSig := bytes #[23,48,20,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,2,0,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Zero-length S is correctly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0582. -/
def scriptVectors_0582 : ScrVec :=
  { id := "sc-0582", scriptSig := bytes #[39,48,36,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,2,16,135,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Negative S is correctly encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0583. -/
def scriptVectors_0583 : ScrVec :=
  { id := "sc-0583", scriptSig := bytes #[74,48,71,2,34,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,33,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "74-byte signature is correctly encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0584. -/
def scriptVectors_0584 : ScrVec :=
  { id := "sc-0584", scriptSig := bytes #[71,48,67,2,32,68,220,23,176,136,124,22,27,182,123,169,99,91,247,88,115,91,221,229,3,228,176,160,152,127,88,127,20,164,225,20,61,2,32,9,162,21,119,45,73,168,93,174,64,216,202,3,149,90,242,106,211,151,138,15,249,101,250,161,41,21,233,88,98,73,165,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Total-length byte not covering the entire signature is correctly encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0585. -/
def scriptVectors_0585 : ScrVec :=
  { id := "sc-0585", scriptSig := bytes #[3,48,0,0],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "3-byte signature is correctly encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0586. -/
def scriptVectors_0586 : ScrVec :=
  { id := "sc-0586", scriptSig := bytes #[5,0,0,0,128,0],
    scriptPubKey := bytes #[178],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := true, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "CSV passes if stack top bit 1 << 31 is set" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0587. -/
def scriptVectors_0587 : ScrVec :=
  { id := "sc-0587", scriptSig := bytes #[],
    scriptPubKey := bytes #[116],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "Test the test: we should have an empty stack after scriptSig evaluation" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0588. -/
def scriptVectors_0588 : ScrVec :=
  { id := "sc-0588", scriptSig := bytes #[],
    scriptPubKey := bytes #[116],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "and multiple spaces should not change that." }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0589. -/
def scriptVectors_0589 : ScrVec :=
  { id := "sc-0589", scriptSig := bytes #[],
    scriptPubKey := bytes #[116],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "    | DEPTH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0590. -/
def scriptVectors_0590 : ScrVec :=
  { id := "sc-0590", scriptSig := bytes #[],
    scriptPubKey := bytes #[116],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "     | DEPTH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0591. -/
def scriptVectors_0591 : ScrVec :=
  { id := "sc-0591", scriptSig := bytes #[],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := " | " }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0592. -/
def scriptVectors_0592 : ScrVec :=
  { id := "sc-0592", scriptSig := bytes #[],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := " | NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0593. -/
def scriptVectors_0593 : ScrVec :=
  { id := "sc-0593", scriptSig := bytes #[],
    scriptPubKey := bytes #[97,116],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := " | NOP DEPTH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0594. -/
def scriptVectors_0594 : ScrVec :=
  { id := "sc-0594", scriptSig := bytes #[97],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "NOP | " }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0595. -/
def scriptVectors_0595 : ScrVec :=
  { id := "sc-0595", scriptSig := bytes #[97],
    scriptPubKey := bytes #[116],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "NOP | DEPTH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0596. -/
def scriptVectors_0596 : ScrVec :=
  { id := "sc-0596", scriptSig := bytes #[97],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "NOP | NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0597. -/
def scriptVectors_0597 : ScrVec :=
  { id := "sc-0597", scriptSig := bytes #[97],
    scriptPubKey := bytes #[97,116],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "NOP | NOP DEPTH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0598. -/
def scriptVectors_0598 : ScrVec :=
  { id := "sc-0598", scriptSig := bytes #[116],
    scriptPubKey := bytes #[],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "DEPTH | " }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0599. -/
def scriptVectors_0599 : ScrVec :=
  { id := "sc-0599", scriptSig := bytes #[76,1],
    scriptPubKey := bytes #[1,97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "PUSHDATA1 with not enough bytes" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0600. -/
def scriptVectors_0600 : ScrVec :=
  { id := "sc-0600", scriptSig := bytes #[77,2,0,255],
    scriptPubKey := bytes #[1,97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "PUSHDATA2 with not enough bytes" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0601. -/
def scriptVectors_0601 : ScrVec :=
  { id := "sc-0601", scriptSig := bytes #[78,3,0,0,0,255,255],
    scriptPubKey := bytes #[1,97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "PUSHDATA4 with not enough bytes" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0602. -/
def scriptVectors_0602 : ScrVec :=
  { id := "sc-0602", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,80,104,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "0x50 is reserved" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0603. -/
def scriptVectors_0603 : ScrVec :=
  { id := "sc-0603", scriptSig := bytes #[82],
    scriptPubKey := bytes #[95,147,96,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0x51 through 0x60 push 1 through 16 onto stack" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0604. -/
def scriptVectors_0604 : ScrVec :=
  { id := "sc-0604", scriptSig := bytes #[0],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 | NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0605. -/
def scriptVectors_0605 : ScrVec :=
  { id := "sc-0605", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,98,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "VER non-functional" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0606. -/
def scriptVectors_0606 : ScrVec :=
  { id := "sc-0606", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,101,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "VERIF illegal everywhere" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0607. -/
def scriptVectors_0607 : ScrVec :=
  { id := "sc-0607", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,103,81,103,101,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "VERIF illegal everywhere" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0608. -/
def scriptVectors_0608 : ScrVec :=
  { id := "sc-0608", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,102,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "VERNOTIF illegal everywhere" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0609. -/
def scriptVectors_0609 : ScrVec :=
  { id := "sc-0609", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,103,81,103,102,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "VERNOTIF illegal everywhere" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0610. -/
def scriptVectors_0610 : ScrVec :=
  { id := "sc-0610", scriptSig := bytes #[81,99],
    scriptPubKey := bytes #[81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "IF/ENDIF can't span scriptSig/scriptPubKey" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0611. -/
def scriptVectors_0611 : ScrVec :=
  { id := "sc-0611", scriptSig := bytes #[81,99,0,104],
    scriptPubKey := bytes #[81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "1 IF 0 ENDIF | 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0612. -/
def scriptVectors_0612 : ScrVec :=
  { id := "sc-0612", scriptSig := bytes #[81,103,0,104],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "1 ELSE 0 ENDIF | 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0613. -/
def scriptVectors_0613 : ScrVec :=
  { id := "sc-0613", scriptSig := bytes #[0,100],
    scriptPubKey := bytes #[1,123],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "0 NOTIF | 123" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0614. -/
def scriptVectors_0614 : ScrVec :=
  { id := "sc-0614", scriptSig := bytes #[0],
    scriptPubKey := bytes #[118,99,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 | DUP IF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0615. -/
def scriptVectors_0615 : ScrVec :=
  { id := "sc-0615", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 | IF 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0616. -/
def scriptVectors_0616 : ScrVec :=
  { id := "sc-0616", scriptSig := bytes #[0],
    scriptPubKey := bytes #[118,99,103,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 | DUP IF ELSE ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0617. -/
def scriptVectors_0617 : ScrVec :=
  { id := "sc-0617", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,81,103,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 | IF 1 ELSE ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0618. -/
def scriptVectors_0618 : ScrVec :=
  { id := "sc-0618", scriptSig := bytes #[0],
    scriptPubKey := bytes #[100,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 | NOTIF ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0619. -/
def scriptVectors_0619 : ScrVec :=
  { id := "sc-0619", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[99,99,81,103,0,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 1 | IF IF 1 ELSE 0 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0620. -/
def scriptVectors_0620 : ScrVec :=
  { id := "sc-0620", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[99,99,81,103,0,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 0 | IF IF 1 ELSE 0 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0621. -/
def scriptVectors_0621 : ScrVec :=
  { id := "sc-0621", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[99,99,81,103,0,104,103,99,0,103,81,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "1 0 | IF IF 1 ELSE 0 ENDIF ELSE IF 0 ELSE 1 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0622. -/
def scriptVectors_0622 : ScrVec :=
  { id := "sc-0622", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[99,99,81,103,0,104,103,99,0,103,81,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 1 | IF IF 1 ELSE 0 ENDIF ELSE IF 0 ELSE 1 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0623. -/
def scriptVectors_0623 : ScrVec :=
  { id := "sc-0623", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[100,99,81,103,0,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 0 | NOTIF IF 1 ELSE 0 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0624. -/
def scriptVectors_0624 : ScrVec :=
  { id := "sc-0624", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[100,99,81,103,0,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 1 | NOTIF IF 1 ELSE 0 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0625. -/
def scriptVectors_0625 : ScrVec :=
  { id := "sc-0625", scriptSig := bytes #[81,81],
    scriptPubKey := bytes #[100,99,81,103,0,104,103,99,0,103,81,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "1 1 | NOTIF IF 1 ELSE 0 ENDIF ELSE IF 0 ELSE 1 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0626. -/
def scriptVectors_0626 : ScrVec :=
  { id := "sc-0626", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[100,99,81,103,0,104,103,99,0,103,81,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 0 | NOTIF IF 1 ELSE 0 ENDIF ELSE IF 0 ELSE 1 ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0627. -/
def scriptVectors_0627 : ScrVec :=
  { id := "sc-0627", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,106,103,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "OP_RETURN",
    comment := "Multiple ELSEs" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0628. -/
def scriptVectors_0628 : ScrVec :=
  { id := "sc-0628", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,81,103,103,106,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "OP_RETURN",
    comment := "1 | IF 1 ELSE ELSE RETURN ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0629. -/
def scriptVectors_0629 : ScrVec :=
  { id := "sc-0629", scriptSig := bytes #[81],
    scriptPubKey := bytes #[104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "Malformed IF/ELSE/ENDIF sequence" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0630. -/
def scriptVectors_0630 : ScrVec :=
  { id := "sc-0630", scriptSig := bytes #[81],
    scriptPubKey := bytes #[103,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "1 | ELSE ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0631. -/
def scriptVectors_0631 : ScrVec :=
  { id := "sc-0631", scriptSig := bytes #[81],
    scriptPubKey := bytes #[104,103],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "1 | ENDIF ELSE" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0632. -/
def scriptVectors_0632 : ScrVec :=
  { id := "sc-0632", scriptSig := bytes #[81],
    scriptPubKey := bytes #[104,103,99],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "1 | ENDIF ELSE IF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0633. -/
def scriptVectors_0633 : ScrVec :=
  { id := "sc-0633", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,103,104,103],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "1 | IF ELSE ENDIF ELSE" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0634. -/
def scriptVectors_0634 : ScrVec :=
  { id := "sc-0634", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,103,104,103,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "1 | IF ELSE ENDIF ELSE ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0635. -/
def scriptVectors_0635 : ScrVec :=
  { id := "sc-0635", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "1 | IF ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0636. -/
def scriptVectors_0636 : ScrVec :=
  { id := "sc-0636", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,103,103,104,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "1 | IF ELSE ELSE ENDIF ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0637. -/
def scriptVectors_0637 : ScrVec :=
  { id := "sc-0637", scriptSig := bytes #[81],
    scriptPubKey := bytes #[106],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "OP_RETURN",
    comment := "1 | RETURN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0638. -/
def scriptVectors_0638 : ScrVec :=
  { id := "sc-0638", scriptSig := bytes #[81],
    scriptPubKey := bytes #[118,99,106,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "OP_RETURN",
    comment := "1 | DUP IF RETURN ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0639. -/
def scriptVectors_0639 : ScrVec :=
  { id := "sc-0639", scriptSig := bytes #[81],
    scriptPubKey := bytes #[106,4,100,97,116,97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "OP_RETURN",
    comment := "canonical prunable txout format" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0640. -/
def scriptVectors_0640 : ScrVec :=
  { id := "sc-0640", scriptSig := bytes #[0,99],
    scriptPubKey := bytes #[106,104,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "still prunable because IF/ENDIF can't span scriptSig/scriptPubKey" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0641. -/
def scriptVectors_0641 : ScrVec :=
  { id := "sc-0641", scriptSig := bytes #[0],
    scriptPubKey := bytes #[105,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "VERIFY",
    comment := "0 | VERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0642. -/
def scriptVectors_0642 : ScrVec :=
  { id := "sc-0642", scriptSig := bytes #[81],
    scriptPubKey := bytes #[105],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "1 | VERIFY" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0643. -/
def scriptVectors_0643 : ScrVec :=
  { id := "sc-0643", scriptSig := bytes #[81],
    scriptPubKey := bytes #[105,0],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "1 | VERIFY 0" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0644. -/
def scriptVectors_0644 : ScrVec :=
  { id := "sc-0644", scriptSig := bytes #[81,107],
    scriptPubKey := bytes #[108,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_ALTSTACK_OPERATION",
    comment := "alt stack not shared between sig/pubkey" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0645. -/
def scriptVectors_0645 : ScrVec :=
  { id := "sc-0645", scriptSig := bytes #[115],
    scriptPubKey := bytes #[116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "IFDUP | DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0646. -/
def scriptVectors_0646 : ScrVec :=
  { id := "sc-0646", scriptSig := bytes #[117],
    scriptPubKey := bytes #[116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "DROP | DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0647. -/
def scriptVectors_0647 : ScrVec :=
  { id := "sc-0647", scriptSig := bytes #[118],
    scriptPubKey := bytes #[116,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "DUP | DEPTH 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0648. -/
def scriptVectors_0648 : ScrVec :=
  { id := "sc-0648", scriptSig := bytes #[81],
    scriptPubKey := bytes #[118,81,147,82,136,0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "1 | DUP 1 ADD 2 EQUALVERIFY 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0649. -/
def scriptVectors_0649 : ScrVec :=
  { id := "sc-0649", scriptSig := bytes #[97],
    scriptPubKey := bytes #[119],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | NIP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0650. -/
def scriptVectors_0650 : ScrVec :=
  { id := "sc-0650", scriptSig := bytes #[97],
    scriptPubKey := bytes #[81,119],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | 1 NIP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0651. -/
def scriptVectors_0651 : ScrVec :=
  { id := "sc-0651", scriptSig := bytes #[97],
    scriptPubKey := bytes #[81,0,119],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "NOP | 1 0 NIP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0652. -/
def scriptVectors_0652 : ScrVec :=
  { id := "sc-0652", scriptSig := bytes #[97],
    scriptPubKey := bytes #[120,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | OVER 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0653. -/
def scriptVectors_0653 : ScrVec :=
  { id := "sc-0653", scriptSig := bytes #[81],
    scriptPubKey := bytes #[120],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | OVER" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0654. -/
def scriptVectors_0654 : ScrVec :=
  { id := "sc-0654", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[120,116,83,136],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 1 | OVER DEPTH 3 EQUALVERIFY" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0655. -/
def scriptVectors_0655 : ScrVec :=
  { id := "sc-0655", scriptSig := bytes #[1,19,1,20,1,21],
    scriptPubKey := bytes #[121,1,19,136,116,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "19 20 21 | PICK 19 EQUALVERIFY DEPTH 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0656. -/
def scriptVectors_0656 : ScrVec :=
  { id := "sc-0656", scriptSig := bytes #[97],
    scriptPubKey := bytes #[0,121],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | 0 PICK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0657. -/
def scriptVectors_0657 : ScrVec :=
  { id := "sc-0657", scriptSig := bytes #[81],
    scriptPubKey := bytes #[79,121],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | -1 PICK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0658. -/
def scriptVectors_0658 : ScrVec :=
  { id := "sc-0658", scriptSig := bytes #[1,19,1,20,1,21],
    scriptPubKey := bytes #[0,121,1,20,136,116,83,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EQUALVERIFY",
    comment := "19 20 21 | 0 PICK 20 EQUALVERIFY DEPTH 3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0659. -/
def scriptVectors_0659 : ScrVec :=
  { id := "sc-0659", scriptSig := bytes #[1,19,1,20,1,21],
    scriptPubKey := bytes #[81,121,1,21,136,116,83,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EQUALVERIFY",
    comment := "19 20 21 | 1 PICK 21 EQUALVERIFY DEPTH 3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0660. -/
def scriptVectors_0660 : ScrVec :=
  { id := "sc-0660", scriptSig := bytes #[1,19,1,20,1,21],
    scriptPubKey := bytes #[82,121,1,22,136,116,83,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EQUALVERIFY",
    comment := "19 20 21 | 2 PICK 22 EQUALVERIFY DEPTH 3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0661. -/
def scriptVectors_0661 : ScrVec :=
  { id := "sc-0661", scriptSig := bytes #[97],
    scriptPubKey := bytes #[0,122],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | 0 ROLL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0662. -/
def scriptVectors_0662 : ScrVec :=
  { id := "sc-0662", scriptSig := bytes #[81],
    scriptPubKey := bytes #[79,122],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | -1 ROLL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0663. -/
def scriptVectors_0663 : ScrVec :=
  { id := "sc-0663", scriptSig := bytes #[1,19,1,20,1,21],
    scriptPubKey := bytes #[0,122,1,20,136,116,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EQUALVERIFY",
    comment := "19 20 21 | 0 ROLL 20 EQUALVERIFY DEPTH 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0664. -/
def scriptVectors_0664 : ScrVec :=
  { id := "sc-0664", scriptSig := bytes #[1,19,1,20,1,21],
    scriptPubKey := bytes #[81,122,1,21,136,116,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EQUALVERIFY",
    comment := "19 20 21 | 1 ROLL 21 EQUALVERIFY DEPTH 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0665. -/
def scriptVectors_0665 : ScrVec :=
  { id := "sc-0665", scriptSig := bytes #[1,19,1,20,1,21],
    scriptPubKey := bytes #[82,122,1,22,136,116,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EQUALVERIFY",
    comment := "19 20 21 | 2 ROLL 22 EQUALVERIFY DEPTH 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0666. -/
def scriptVectors_0666 : ScrVec :=
  { id := "sc-0666", scriptSig := bytes #[97],
    scriptPubKey := bytes #[123,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | ROT 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0667. -/
def scriptVectors_0667 : ScrVec :=
  { id := "sc-0667", scriptSig := bytes #[97],
    scriptPubKey := bytes #[81,123,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | 1 ROT 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0668. -/
def scriptVectors_0668 : ScrVec :=
  { id := "sc-0668", scriptSig := bytes #[97],
    scriptPubKey := bytes #[81,82,123,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | 1 2 ROT 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0669. -/
def scriptVectors_0669 : ScrVec :=
  { id := "sc-0669", scriptSig := bytes #[97],
    scriptPubKey := bytes #[0,81,82,123],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "NOP | 0 1 2 ROT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0670. -/
def scriptVectors_0670 : ScrVec :=
  { id := "sc-0670", scriptSig := bytes #[97],
    scriptPubKey := bytes #[124,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | SWAP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0671. -/
def scriptVectors_0671 : ScrVec :=
  { id := "sc-0671", scriptSig := bytes #[81],
    scriptPubKey := bytes #[124,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | SWAP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0672. -/
def scriptVectors_0672 : ScrVec :=
  { id := "sc-0672", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[124,81,136],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EQUALVERIFY",
    comment := "0 1 | SWAP 1 EQUALVERIFY" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0673. -/
def scriptVectors_0673 : ScrVec :=
  { id := "sc-0673", scriptSig := bytes #[97],
    scriptPubKey := bytes #[125,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | TUCK 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0674. -/
def scriptVectors_0674 : ScrVec :=
  { id := "sc-0674", scriptSig := bytes #[81],
    scriptPubKey := bytes #[125,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | TUCK 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0675. -/
def scriptVectors_0675 : ScrVec :=
  { id := "sc-0675", scriptSig := bytes #[81,0],
    scriptPubKey := bytes #[125,116,83,136,124,109],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "1 0 | TUCK DEPTH 3 EQUALVERIFY SWAP 2DROP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0676. -/
def scriptVectors_0676 : ScrVec :=
  { id := "sc-0676", scriptSig := bytes #[97],
    scriptPubKey := bytes #[110,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | 2DUP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0677. -/
def scriptVectors_0677 : ScrVec :=
  { id := "sc-0677", scriptSig := bytes #[81],
    scriptPubKey := bytes #[110,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | 2DUP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0678. -/
def scriptVectors_0678 : ScrVec :=
  { id := "sc-0678", scriptSig := bytes #[97],
    scriptPubKey := bytes #[111,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | 3DUP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0679. -/
def scriptVectors_0679 : ScrVec :=
  { id := "sc-0679", scriptSig := bytes #[81],
    scriptPubKey := bytes #[111,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | 3DUP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0680. -/
def scriptVectors_0680 : ScrVec :=
  { id := "sc-0680", scriptSig := bytes #[81,82],
    scriptPubKey := bytes #[111,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 2 | 3DUP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0681. -/
def scriptVectors_0681 : ScrVec :=
  { id := "sc-0681", scriptSig := bytes #[97],
    scriptPubKey := bytes #[112,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | 2OVER 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0682. -/
def scriptVectors_0682 : ScrVec :=
  { id := "sc-0682", scriptSig := bytes #[81],
    scriptPubKey := bytes #[82,83,112,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | 2 3 2OVER 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0683. -/
def scriptVectors_0683 : ScrVec :=
  { id := "sc-0683", scriptSig := bytes #[97],
    scriptPubKey := bytes #[114,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | 2SWAP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0684. -/
def scriptVectors_0684 : ScrVec :=
  { id := "sc-0684", scriptSig := bytes #[81],
    scriptPubKey := bytes #[82,83,114,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | 2 3 2SWAP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0685. -/
def scriptVectors_0685 : ScrVec :=
  { id := "sc-0685", scriptSig := bytes #[97],
    scriptPubKey := bytes #[130,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | SIZE 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0686. -/
def scriptVectors_0686 : ScrVec :=
  { id := "sc-0686", scriptSig := bytes #[1,97,1,98],
    scriptPubKey := bytes #[126],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "CAT disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0687. -/
def scriptVectors_0687 : ScrVec :=
  { id := "sc-0687", scriptSig := bytes #[1,97,1,98,0],
    scriptPubKey := bytes #[99,126,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "CAT disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0688. -/
def scriptVectors_0688 : ScrVec :=
  { id := "sc-0688", scriptSig := bytes #[3,97,98,99,81,81],
    scriptPubKey := bytes #[127],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "SUBSTR disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0689. -/
def scriptVectors_0689 : ScrVec :=
  { id := "sc-0689", scriptSig := bytes #[3,97,98,99,81,81,0],
    scriptPubKey := bytes #[99,127,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "SUBSTR disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0690. -/
def scriptVectors_0690 : ScrVec :=
  { id := "sc-0690", scriptSig := bytes #[3,97,98,99,82,0],
    scriptPubKey := bytes #[99,128,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "LEFT disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0691. -/
def scriptVectors_0691 : ScrVec :=
  { id := "sc-0691", scriptSig := bytes #[3,97,98,99,82,0],
    scriptPubKey := bytes #[99,129,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "RIGHT disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0692. -/
def scriptVectors_0692 : ScrVec :=
  { id := "sc-0692", scriptSig := bytes #[3,97,98,99],
    scriptPubKey := bytes #[99,131,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "INVERT disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0693. -/
def scriptVectors_0693 : ScrVec :=
  { id := "sc-0693", scriptSig := bytes #[81,82,0,99,132,103,81,104],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "AND disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0694. -/
def scriptVectors_0694 : ScrVec :=
  { id := "sc-0694", scriptSig := bytes #[81,82,0,99,133,103,81,104],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "OR disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0695. -/
def scriptVectors_0695 : ScrVec :=
  { id := "sc-0695", scriptSig := bytes #[81,82,0,99,134,103,81,104],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "XOR disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0696. -/
def scriptVectors_0696 : ScrVec :=
  { id := "sc-0696", scriptSig := bytes #[82,0,99,141,103,81,104],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "2MUL disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0697. -/
def scriptVectors_0697 : ScrVec :=
  { id := "sc-0697", scriptSig := bytes #[82,0,99,142,103,81,104],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "2DIV disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0698. -/
def scriptVectors_0698 : ScrVec :=
  { id := "sc-0698", scriptSig := bytes #[82,82,0,99,149,103,81,104],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "MUL disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0699. -/
def scriptVectors_0699 : ScrVec :=
  { id := "sc-0699", scriptSig := bytes #[82,82,0,99,150,103,81,104],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "DIV disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0700. -/
def scriptVectors_0700 : ScrVec :=
  { id := "sc-0700", scriptSig := bytes #[82,82,0,99,151,103,81,104],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "MOD disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0701. -/
def scriptVectors_0701 : ScrVec :=
  { id := "sc-0701", scriptSig := bytes #[82,82,0,99,152,103,81,104],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "LSHIFT disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0702. -/
def scriptVectors_0702 : ScrVec :=
  { id := "sc-0702", scriptSig := bytes #[82,82,0,99,153,103,81,104],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "RSHIFT disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0703. -/
def scriptVectors_0703 : ScrVec :=
  { id := "sc-0703", scriptSig := bytes #[],
    scriptPubKey := bytes #[135,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "EQUAL must error when there are no stack items" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0704. -/
def scriptVectors_0704 : ScrVec :=
  { id := "sc-0704", scriptSig := bytes #[0],
    scriptPubKey := bytes #[135,145],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "EQUAL must error when there are not 2 stack items" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0705. -/
def scriptVectors_0705 : ScrVec :=
  { id := "sc-0705", scriptSig := bytes #[0,81],
    scriptPubKey := bytes #[135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 1 | EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0706. -/
def scriptVectors_0706 : ScrVec :=
  { id := "sc-0706", scriptSig := bytes #[81,81,147],
    scriptPubKey := bytes #[0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "1 1 ADD | 0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0707. -/
def scriptVectors_0707 : ScrVec :=
  { id := "sc-0707", scriptSig := bytes #[91,81,147,92,148],
    scriptPubKey := bytes #[91,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "11 1 ADD 12 SUB | 11 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0708. -/
def scriptVectors_0708 : ScrVec :=
  { id := "sc-0708", scriptSig := bytes #[5,0,0,0,128,0,0,147],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "arithmetic operands must be in range [-2^31...2^31] " }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0709. -/
def scriptVectors_0709 : ScrVec :=
  { id := "sc-0709", scriptSig := bytes #[5,0,0,0,128,128,0,147],
    scriptPubKey := bytes #[97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "arithmetic operands must be in range [-2^31...2^31] " }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0710. -/
def scriptVectors_0710 : ScrVec :=
  { id := "sc-0710", scriptSig := bytes #[4,255,255,255,127,118,147],
    scriptPubKey := bytes #[5,254,255,255,255,0,156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "NUMEQUAL must be in numeric range" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0711. -/
def scriptVectors_0711 : ScrVec :=
  { id := "sc-0711", scriptSig := bytes #[6,97,98,99,100,101,102,145],
    scriptPubKey := bytes #[0,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "NOT is an arithmetic operand" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0712. -/
def scriptVectors_0712 : ScrVec :=
  { id := "sc-0712", scriptSig := bytes #[82,118,149],
    scriptPubKey := bytes #[84,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0713. -/
def scriptVectors_0713 : ScrVec :=
  { id := "sc-0713", scriptSig := bytes #[82,118,150],
    scriptPubKey := bytes #[81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0714. -/
def scriptVectors_0714 : ScrVec :=
  { id := "sc-0714", scriptSig := bytes #[82,141],
    scriptPubKey := bytes #[84,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0715. -/
def scriptVectors_0715 : ScrVec :=
  { id := "sc-0715", scriptSig := bytes #[82,142],
    scriptPubKey := bytes #[81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0716. -/
def scriptVectors_0716 : ScrVec :=
  { id := "sc-0716", scriptSig := bytes #[87,83,151],
    scriptPubKey := bytes #[81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0717. -/
def scriptVectors_0717 : ScrVec :=
  { id := "sc-0717", scriptSig := bytes #[82,82,152],
    scriptPubKey := bytes #[88,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0718. -/
def scriptVectors_0718 : ScrVec :=
  { id := "sc-0718", scriptSig := bytes #[82,81,153],
    scriptPubKey := bytes #[81,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "DISABLED_OPCODE",
    comment := "disabled" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0719. -/
def scriptVectors_0719 : ScrVec :=
  { id := "sc-0719", scriptSig := bytes #[81],
    scriptPubKey := bytes #[176,177,178,179,180,181,182,183,184,185,82,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "1 | NOP1 CHECKLOCKTIMEVERIFY CHECKSEQUENCEVERIFY NOP4 NOP5 NOP6 NOP7 NOP8 NOP9 NOP10 2 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0720. -/
def scriptVectors_0720 : ScrVec :=
  { id := "sc-0720", scriptSig := bytes #[11,78,79,80,95,49,95,116,111,95,49,48,176,177,178,179,180,181,182,183,184,185],
    scriptPubKey := bytes #[11,78,79,80,95,49,95,116,111,95,49,49,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "'NOP_1_to_10' NOP1 CHECKLOCKTIMEVERIFY CHECKSEQUENCEVERIFY NOP4 NOP5 NOP6 NOP7 NOP8 NOP9 NOP10 | 'NOP_1_to_11' EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0721. -/
def scriptVectors_0721 : ScrVec :=
  { id := "sc-0721", scriptSig := bytes #[81],
    scriptPubKey := bytes #[176],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "DISCOURAGE_UPGRADABLE_NOPS",
    expectOk := false, expectedError := "DISCOURAGE_UPGRADABLE_NOPS",
    comment := "1 | NOP1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0722. -/
def scriptVectors_0722 : ScrVec :=
  { id := "sc-0722", scriptSig := bytes #[81],
    scriptPubKey := bytes #[179],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "DISCOURAGE_UPGRADABLE_NOPS",
    expectOk := false, expectedError := "DISCOURAGE_UPGRADABLE_NOPS",
    comment := "1 | NOP4" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0723. -/
def scriptVectors_0723 : ScrVec :=
  { id := "sc-0723", scriptSig := bytes #[81],
    scriptPubKey := bytes #[180],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "DISCOURAGE_UPGRADABLE_NOPS",
    expectOk := false, expectedError := "DISCOURAGE_UPGRADABLE_NOPS",
    comment := "1 | NOP5" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0724. -/
def scriptVectors_0724 : ScrVec :=
  { id := "sc-0724", scriptSig := bytes #[81],
    scriptPubKey := bytes #[181],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "DISCOURAGE_UPGRADABLE_NOPS",
    expectOk := false, expectedError := "DISCOURAGE_UPGRADABLE_NOPS",
    comment := "1 | NOP6" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0725. -/
def scriptVectors_0725 : ScrVec :=
  { id := "sc-0725", scriptSig := bytes #[81],
    scriptPubKey := bytes #[182],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "DISCOURAGE_UPGRADABLE_NOPS",
    expectOk := false, expectedError := "DISCOURAGE_UPGRADABLE_NOPS",
    comment := "1 | NOP7" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0726. -/
def scriptVectors_0726 : ScrVec :=
  { id := "sc-0726", scriptSig := bytes #[81],
    scriptPubKey := bytes #[183],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "DISCOURAGE_UPGRADABLE_NOPS",
    expectOk := false, expectedError := "DISCOURAGE_UPGRADABLE_NOPS",
    comment := "1 | NOP8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0727. -/
def scriptVectors_0727 : ScrVec :=
  { id := "sc-0727", scriptSig := bytes #[81],
    scriptPubKey := bytes #[184],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "DISCOURAGE_UPGRADABLE_NOPS",
    expectOk := false, expectedError := "DISCOURAGE_UPGRADABLE_NOPS",
    comment := "1 | NOP9" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0728. -/
def scriptVectors_0728 : ScrVec :=
  { id := "sc-0728", scriptSig := bytes #[81],
    scriptPubKey := bytes #[185],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "DISCOURAGE_UPGRADABLE_NOPS",
    expectOk := false, expectedError := "DISCOURAGE_UPGRADABLE_NOPS",
    comment := "1 | NOP10" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0729. -/
def scriptVectors_0729 : ScrVec :=
  { id := "sc-0729", scriptSig := bytes #[185],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "DISCOURAGE_UPGRADABLE_NOPS",
    expectOk := false, expectedError := "DISCOURAGE_UPGRADABLE_NOPS",
    comment := "Discouraged NOP10 in scriptSig" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0730. -/
def scriptVectors_0730 : ScrVec :=
  { id := "sc-0730", scriptSig := bytes #[81,1,185],
    scriptPubKey := bytes #[169,20,21,114,114,153,176,91,69,253,175,154,201,236,247,86,92,254,39,195,229,103,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "DISCOURAGE_UPGRADABLE_NOPS",
    expectOk := false, expectedError := "DISCOURAGE_UPGRADABLE_NOPS",
    comment := "Discouraged NOP10 in redeemScript" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0731. -/
def scriptVectors_0731 : ScrVec :=
  { id := "sc-0731", scriptSig := bytes #[80],
    scriptPubKey := bytes #[81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "opcode 0x50 is reserved" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0732. -/
def scriptVectors_0732 : ScrVec :=
  { id := "sc-0732", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,186,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "opcodes above MAX_OPCODE invalid if executed" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0733. -/
def scriptVectors_0733 : ScrVec :=
  { id := "sc-0733", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,187,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xbb ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0734. -/
def scriptVectors_0734 : ScrVec :=
  { id := "sc-0734", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,188,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xbc ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0735. -/
def scriptVectors_0735 : ScrVec :=
  { id := "sc-0735", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,189,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xbd ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0736. -/
def scriptVectors_0736 : ScrVec :=
  { id := "sc-0736", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,190,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xbe ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0737. -/
def scriptVectors_0737 : ScrVec :=
  { id := "sc-0737", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,191,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xbf ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0738. -/
def scriptVectors_0738 : ScrVec :=
  { id := "sc-0738", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,192,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xc0 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0739. -/
def scriptVectors_0739 : ScrVec :=
  { id := "sc-0739", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,193,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xc1 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0740. -/
def scriptVectors_0740 : ScrVec :=
  { id := "sc-0740", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,194,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xc2 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0741. -/
def scriptVectors_0741 : ScrVec :=
  { id := "sc-0741", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,195,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xc3 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0742. -/
def scriptVectors_0742 : ScrVec :=
  { id := "sc-0742", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,196,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xc4 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0743. -/
def scriptVectors_0743 : ScrVec :=
  { id := "sc-0743", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,197,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xc5 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0744. -/
def scriptVectors_0744 : ScrVec :=
  { id := "sc-0744", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,198,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xc6 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0745. -/
def scriptVectors_0745 : ScrVec :=
  { id := "sc-0745", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,199,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xc7 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0746. -/
def scriptVectors_0746 : ScrVec :=
  { id := "sc-0746", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,200,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xc8 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0747. -/
def scriptVectors_0747 : ScrVec :=
  { id := "sc-0747", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,201,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xc9 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0748. -/
def scriptVectors_0748 : ScrVec :=
  { id := "sc-0748", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,202,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xca ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0749. -/
def scriptVectors_0749 : ScrVec :=
  { id := "sc-0749", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,203,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xcb ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0750. -/
def scriptVectors_0750 : ScrVec :=
  { id := "sc-0750", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,204,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xcc ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0751. -/
def scriptVectors_0751 : ScrVec :=
  { id := "sc-0751", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,205,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xcd ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0752. -/
def scriptVectors_0752 : ScrVec :=
  { id := "sc-0752", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,206,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xce ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0753. -/
def scriptVectors_0753 : ScrVec :=
  { id := "sc-0753", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,207,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xcf ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0754. -/
def scriptVectors_0754 : ScrVec :=
  { id := "sc-0754", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,208,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xd0 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0755. -/
def scriptVectors_0755 : ScrVec :=
  { id := "sc-0755", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,209,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xd1 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0756. -/
def scriptVectors_0756 : ScrVec :=
  { id := "sc-0756", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,210,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xd2 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0757. -/
def scriptVectors_0757 : ScrVec :=
  { id := "sc-0757", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,211,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xd3 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0758. -/
def scriptVectors_0758 : ScrVec :=
  { id := "sc-0758", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,212,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xd4 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0759. -/
def scriptVectors_0759 : ScrVec :=
  { id := "sc-0759", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,213,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xd5 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0760. -/
def scriptVectors_0760 : ScrVec :=
  { id := "sc-0760", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,214,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xd6 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0761. -/
def scriptVectors_0761 : ScrVec :=
  { id := "sc-0761", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,215,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xd7 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0762. -/
def scriptVectors_0762 : ScrVec :=
  { id := "sc-0762", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,216,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xd8 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0763. -/
def scriptVectors_0763 : ScrVec :=
  { id := "sc-0763", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,217,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xd9 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0764. -/
def scriptVectors_0764 : ScrVec :=
  { id := "sc-0764", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,218,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xda ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0765. -/
def scriptVectors_0765 : ScrVec :=
  { id := "sc-0765", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,219,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xdb ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0766. -/
def scriptVectors_0766 : ScrVec :=
  { id := "sc-0766", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,220,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xdc ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0767. -/
def scriptVectors_0767 : ScrVec :=
  { id := "sc-0767", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,221,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xdd ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0768. -/
def scriptVectors_0768 : ScrVec :=
  { id := "sc-0768", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,222,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xde ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0769. -/
def scriptVectors_0769 : ScrVec :=
  { id := "sc-0769", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,223,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xdf ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0770. -/
def scriptVectors_0770 : ScrVec :=
  { id := "sc-0770", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,224,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xe0 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0771. -/
def scriptVectors_0771 : ScrVec :=
  { id := "sc-0771", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,225,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xe1 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0772. -/
def scriptVectors_0772 : ScrVec :=
  { id := "sc-0772", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,226,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xe2 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0773. -/
def scriptVectors_0773 : ScrVec :=
  { id := "sc-0773", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,227,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xe3 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0774. -/
def scriptVectors_0774 : ScrVec :=
  { id := "sc-0774", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,228,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xe4 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0775. -/
def scriptVectors_0775 : ScrVec :=
  { id := "sc-0775", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,229,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xe5 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0776. -/
def scriptVectors_0776 : ScrVec :=
  { id := "sc-0776", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,230,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xe6 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0777. -/
def scriptVectors_0777 : ScrVec :=
  { id := "sc-0777", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,231,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xe7 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0778. -/
def scriptVectors_0778 : ScrVec :=
  { id := "sc-0778", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,232,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xe8 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0779. -/
def scriptVectors_0779 : ScrVec :=
  { id := "sc-0779", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,233,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xe9 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0780. -/
def scriptVectors_0780 : ScrVec :=
  { id := "sc-0780", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,234,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xea ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0781. -/
def scriptVectors_0781 : ScrVec :=
  { id := "sc-0781", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,235,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xeb ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0782. -/
def scriptVectors_0782 : ScrVec :=
  { id := "sc-0782", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,236,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xec ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0783. -/
def scriptVectors_0783 : ScrVec :=
  { id := "sc-0783", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,237,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xed ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0784. -/
def scriptVectors_0784 : ScrVec :=
  { id := "sc-0784", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,238,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xee ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0785. -/
def scriptVectors_0785 : ScrVec :=
  { id := "sc-0785", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,239,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xef ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0786. -/
def scriptVectors_0786 : ScrVec :=
  { id := "sc-0786", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,240,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xf0 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0787. -/
def scriptVectors_0787 : ScrVec :=
  { id := "sc-0787", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,241,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xf1 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0788. -/
def scriptVectors_0788 : ScrVec :=
  { id := "sc-0788", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,242,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xf2 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0789. -/
def scriptVectors_0789 : ScrVec :=
  { id := "sc-0789", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,243,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xf3 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0790. -/
def scriptVectors_0790 : ScrVec :=
  { id := "sc-0790", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,244,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xf4 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0791. -/
def scriptVectors_0791 : ScrVec :=
  { id := "sc-0791", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,245,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xf5 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0792. -/
def scriptVectors_0792 : ScrVec :=
  { id := "sc-0792", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,246,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xf6 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0793. -/
def scriptVectors_0793 : ScrVec :=
  { id := "sc-0793", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,247,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xf7 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0794. -/
def scriptVectors_0794 : ScrVec :=
  { id := "sc-0794", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,248,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xf8 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0795. -/
def scriptVectors_0795 : ScrVec :=
  { id := "sc-0795", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,249,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xf9 ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0796. -/
def scriptVectors_0796 : ScrVec :=
  { id := "sc-0796", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,250,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xfa ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0797. -/
def scriptVectors_0797 : ScrVec :=
  { id := "sc-0797", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,251,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xfb ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0798. -/
def scriptVectors_0798 : ScrVec :=
  { id := "sc-0798", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,252,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xfc ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0799. -/
def scriptVectors_0799 : ScrVec :=
  { id := "sc-0799", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,253,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xfd ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0800. -/
def scriptVectors_0800 : ScrVec :=
  { id := "sc-0800", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,254,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xfe ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0801. -/
def scriptVectors_0801 : ScrVec :=
  { id := "sc-0801", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,255,103,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "1 | IF 0xff ELSE 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0802. -/
def scriptVectors_0802 : ScrVec :=
  { id := "sc-0802", scriptSig := bytes #[81,99,81,103],
    scriptPubKey := bytes #[255,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "invalid because scriptSig and scriptPubKey are processed separately" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0803. -/
def scriptVectors_0803 : ScrVec :=
  { id := "sc-0803", scriptSig := bytes #[97],
    scriptPubKey := bytes #[166],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | RIPEMD160" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0804. -/
def scriptVectors_0804 : ScrVec :=
  { id := "sc-0804", scriptSig := bytes #[97],
    scriptPubKey := bytes #[167],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | SHA1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0805. -/
def scriptVectors_0805 : ScrVec :=
  { id := "sc-0805", scriptSig := bytes #[97],
    scriptPubKey := bytes #[168],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | SHA256" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0806. -/
def scriptVectors_0806 : ScrVec :=
  { id := "sc-0806", scriptSig := bytes #[97],
    scriptPubKey := bytes #[169],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | HASH160" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0807. -/
def scriptVectors_0807 : ScrVec :=
  { id := "sc-0807", scriptSig := bytes #[97],
    scriptPubKey := bytes #[170],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | HASH256" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0808. -/
def scriptVectors_0808 : ScrVec :=
  { id := "sc-0808", scriptSig := bytes #[97],
    scriptPubKey := bytes #[77,9,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "PUSH_SIZE",
    comment := ">520 byte push" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0809. -/
def scriptVectors_0809 : ScrVec :=
  { id := "sc-0809", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,77,9,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,104,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "PUSH_SIZE",
    comment := ">520 byte push in non-executed IF branch" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0810. -/
def scriptVectors_0810 : ScrVec :=
  { id := "sc-0810", scriptSig := bytes #[81],
    scriptPubKey := bytes #[97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "OP_COUNT",
    comment := ">201 opcodes executed. 0x61 is NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0811. -/
def scriptVectors_0811 : ScrVec :=
  { id := "sc-0811", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,104,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "OP_COUNT",
    comment := ">201 opcodes including non-executed IF branch. 0x61 is NOP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0812. -/
def scriptVectors_0812 : ScrVec :=
  { id := "sc-0812", scriptSig := bytes #[81,82,83,84,85,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111],
    scriptPubKey := bytes #[81,82,83,84,85,86,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "STACK_SIZE",
    comment := ">1,000 stack size (0x6f is 3DUP)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0813. -/
def scriptVectors_0813 : ScrVec :=
  { id := "sc-0813", scriptSig := bytes #[81,82,83,84,85,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111],
    scriptPubKey := bytes #[81,107,82,107,83,84,85,86,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "STACK_SIZE",
    comment := ">1,000 stack+altstack size" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0814. -/
def scriptVectors_0814 : ScrVec :=
  { id := "sc-0814", scriptSig := bytes #[97],
    scriptPubKey := bytes #[0,77,126,1,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,77,8,2,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,98,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,111,110,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SCRIPT_SIZE",
    comment := "10,001-byte scriptPubKey" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0815. -/
def scriptVectors_0815 : ScrVec :=
  { id := "sc-0815", scriptSig := bytes #[176],
    scriptPubKey := bytes #[185],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "NOP1 | NOP10" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0816. -/
def scriptVectors_0816 : ScrVec :=
  { id := "sc-0816", scriptSig := bytes #[81],
    scriptPubKey := bytes #[98],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "OP_VER is reserved" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0817. -/
def scriptVectors_0817 : ScrVec :=
  { id := "sc-0817", scriptSig := bytes #[81],
    scriptPubKey := bytes #[101],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "OP_VERIF is reserved" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0818. -/
def scriptVectors_0818 : ScrVec :=
  { id := "sc-0818", scriptSig := bytes #[81],
    scriptPubKey := bytes #[102],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "OP_VERNOTIF is reserved" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0819. -/
def scriptVectors_0819 : ScrVec :=
  { id := "sc-0819", scriptSig := bytes #[81],
    scriptPubKey := bytes #[80],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "OP_RESERVED is reserved" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0820. -/
def scriptVectors_0820 : ScrVec :=
  { id := "sc-0820", scriptSig := bytes #[81],
    scriptPubKey := bytes #[137],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "OP_RESERVED1 is reserved" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0821. -/
def scriptVectors_0821 : ScrVec :=
  { id := "sc-0821", scriptSig := bytes #[81],
    scriptPubKey := bytes #[138],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "OP_RESERVED2 is reserved" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0822. -/
def scriptVectors_0822 : ScrVec :=
  { id := "sc-0822", scriptSig := bytes #[81],
    scriptPubKey := bytes #[186],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "0xba == MAX_OPCODE + 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0823. -/
def scriptVectors_0823 : ScrVec :=
  { id := "sc-0823", scriptSig := bytes #[5,0,0,0,128,0],
    scriptPubKey := bytes #[139,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "We cannot do math on 5-byte integers" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0824. -/
def scriptVectors_0824 : ScrVec :=
  { id := "sc-0824", scriptSig := bytes #[5,0,0,0,128,0],
    scriptPubKey := bytes #[143,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "We cannot do math on 5-byte integers" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0825. -/
def scriptVectors_0825 : ScrVec :=
  { id := "sc-0825", scriptSig := bytes #[5,0,0,0,128,128],
    scriptPubKey := bytes #[139,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "Because we use a sign bit, -2147483648 is also 5 bytes" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0826. -/
def scriptVectors_0826 : ScrVec :=
  { id := "sc-0826", scriptSig := bytes #[4,255,255,255,127],
    scriptPubKey := bytes #[139,140,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "We cannot do math on 5-byte integers, even if the result is 4-bytes" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0827. -/
def scriptVectors_0827 : ScrVec :=
  { id := "sc-0827", scriptSig := bytes #[5,0,0,0,128,0],
    scriptPubKey := bytes #[140,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "We cannot do math on 5-byte integers, even if the result is 4-bytes" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0828. -/
def scriptVectors_0828 : ScrVec :=
  { id := "sc-0828", scriptSig := bytes #[5,0,0,0,128,0,81],
    scriptPubKey := bytes #[155,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "We cannot do BOOLOR on 5-byte integers (but we can still do IF etc)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0829. -/
def scriptVectors_0829 : ScrVec :=
  { id := "sc-0829", scriptSig := bytes #[5,0,0,0,128,0,81],
    scriptPubKey := bytes #[154,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "We cannot do BOOLAND on 5-byte integers" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0830. -/
def scriptVectors_0830 : ScrVec :=
  { id := "sc-0830", scriptSig := bytes #[81],
    scriptPubKey := bytes #[81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "ENDIF without IF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0831. -/
def scriptVectors_0831 : ScrVec :=
  { id := "sc-0831", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "IF without ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0832. -/
def scriptVectors_0832 : ScrVec :=
  { id := "sc-0832", scriptSig := bytes #[81,99,81],
    scriptPubKey := bytes #[104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "UNBALANCED_CONDITIONAL",
    comment := "IFs don't carry over" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0833. -/
def scriptVectors_0833 : ScrVec :=
  { id := "sc-0833", scriptSig := bytes #[97],
    scriptPubKey := bytes #[99,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "The following tests check the if(stack.size() < N) tests in each opcode" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0834. -/
def scriptVectors_0834 : ScrVec :=
  { id := "sc-0834", scriptSig := bytes #[97],
    scriptPubKey := bytes #[100,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "They are here to catch copy-and-paste errors" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0835. -/
def scriptVectors_0835 : ScrVec :=
  { id := "sc-0835", scriptSig := bytes #[97],
    scriptPubKey := bytes #[105,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "Most of them are duplicated elsewhere," }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0836. -/
def scriptVectors_0836 : ScrVec :=
  { id := "sc-0836", scriptSig := bytes #[97],
    scriptPubKey := bytes #[107,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "but, hey, more is always better, right?" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0837. -/
def scriptVectors_0837 : ScrVec :=
  { id := "sc-0837", scriptSig := bytes #[81],
    scriptPubKey := bytes #[108],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_ALTSTACK_OPERATION",
    comment := "1 | FROMALTSTACK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0838. -/
def scriptVectors_0838 : ScrVec :=
  { id := "sc-0838", scriptSig := bytes #[81],
    scriptPubKey := bytes #[82,107,108,108],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_ALTSTACK_OPERATION",
    comment := "FROMALTSTACK must pop the altstack" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0839. -/
def scriptVectors_0839 : ScrVec :=
  { id := "sc-0839", scriptSig := bytes #[81],
    scriptPubKey := bytes #[109,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | 2DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0840. -/
def scriptVectors_0840 : ScrVec :=
  { id := "sc-0840", scriptSig := bytes #[81],
    scriptPubKey := bytes #[110],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | 2DUP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0841. -/
def scriptVectors_0841 : ScrVec :=
  { id := "sc-0841", scriptSig := bytes #[81,81],
    scriptPubKey := bytes #[111],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 1 | 3DUP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0842. -/
def scriptVectors_0842 : ScrVec :=
  { id := "sc-0842", scriptSig := bytes #[81,81,81],
    scriptPubKey := bytes #[112],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 1 1 | 2OVER" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0843. -/
def scriptVectors_0843 : ScrVec :=
  { id := "sc-0843", scriptSig := bytes #[81,81,81,81,81],
    scriptPubKey := bytes #[113],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 1 1 1 1 | 2ROT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0844. -/
def scriptVectors_0844 : ScrVec :=
  { id := "sc-0844", scriptSig := bytes #[81,81,81],
    scriptPubKey := bytes #[114],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 1 1 | 2SWAP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0845. -/
def scriptVectors_0845 : ScrVec :=
  { id := "sc-0845", scriptSig := bytes #[97],
    scriptPubKey := bytes #[115,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | IFDUP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0846. -/
def scriptVectors_0846 : ScrVec :=
  { id := "sc-0846", scriptSig := bytes #[97],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0847. -/
def scriptVectors_0847 : ScrVec :=
  { id := "sc-0847", scriptSig := bytes #[97],
    scriptPubKey := bytes #[118,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | DUP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0848. -/
def scriptVectors_0848 : ScrVec :=
  { id := "sc-0848", scriptSig := bytes #[81],
    scriptPubKey := bytes #[119],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | NIP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0849. -/
def scriptVectors_0849 : ScrVec :=
  { id := "sc-0849", scriptSig := bytes #[81],
    scriptPubKey := bytes #[120],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | OVER" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0850. -/
def scriptVectors_0850 : ScrVec :=
  { id := "sc-0850", scriptSig := bytes #[81,81,81,83],
    scriptPubKey := bytes #[121],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 1 1 3 | PICK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0851. -/
def scriptVectors_0851 : ScrVec :=
  { id := "sc-0851", scriptSig := bytes #[0],
    scriptPubKey := bytes #[121,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "0 | PICK 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0852. -/
def scriptVectors_0852 : ScrVec :=
  { id := "sc-0852", scriptSig := bytes #[81,81,81,83],
    scriptPubKey := bytes #[122],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 1 1 3 | ROLL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0853. -/
def scriptVectors_0853 : ScrVec :=
  { id := "sc-0853", scriptSig := bytes #[0],
    scriptPubKey := bytes #[122,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "0 | ROLL 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0854. -/
def scriptVectors_0854 : ScrVec :=
  { id := "sc-0854", scriptSig := bytes #[81,81],
    scriptPubKey := bytes #[123],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 1 | ROT" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0855. -/
def scriptVectors_0855 : ScrVec :=
  { id := "sc-0855", scriptSig := bytes #[81],
    scriptPubKey := bytes #[124],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | SWAP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0856. -/
def scriptVectors_0856 : ScrVec :=
  { id := "sc-0856", scriptSig := bytes #[81],
    scriptPubKey := bytes #[125],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | TUCK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0857. -/
def scriptVectors_0857 : ScrVec :=
  { id := "sc-0857", scriptSig := bytes #[97],
    scriptPubKey := bytes #[130,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | SIZE 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0858. -/
def scriptVectors_0858 : ScrVec :=
  { id := "sc-0858", scriptSig := bytes #[81],
    scriptPubKey := bytes #[135,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | EQUAL 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0859. -/
def scriptVectors_0859 : ScrVec :=
  { id := "sc-0859", scriptSig := bytes #[81],
    scriptPubKey := bytes #[136,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | EQUALVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0860. -/
def scriptVectors_0860 : ScrVec :=
  { id := "sc-0860", scriptSig := bytes #[97],
    scriptPubKey := bytes #[139,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | 1ADD 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0861. -/
def scriptVectors_0861 : ScrVec :=
  { id := "sc-0861", scriptSig := bytes #[97],
    scriptPubKey := bytes #[140,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | 1SUB 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0862. -/
def scriptVectors_0862 : ScrVec :=
  { id := "sc-0862", scriptSig := bytes #[97],
    scriptPubKey := bytes #[143,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | NEGATE 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0863. -/
def scriptVectors_0863 : ScrVec :=
  { id := "sc-0863", scriptSig := bytes #[97],
    scriptPubKey := bytes #[144,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | ABS 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0864. -/
def scriptVectors_0864 : ScrVec :=
  { id := "sc-0864", scriptSig := bytes #[97],
    scriptPubKey := bytes #[145,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | NOT 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0865. -/
def scriptVectors_0865 : ScrVec :=
  { id := "sc-0865", scriptSig := bytes #[97],
    scriptPubKey := bytes #[146,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | 0NOTEQUAL 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0866. -/
def scriptVectors_0866 : ScrVec :=
  { id := "sc-0866", scriptSig := bytes #[81],
    scriptPubKey := bytes #[147],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | ADD" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0867. -/
def scriptVectors_0867 : ScrVec :=
  { id := "sc-0867", scriptSig := bytes #[81],
    scriptPubKey := bytes #[148],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | SUB" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0868. -/
def scriptVectors_0868 : ScrVec :=
  { id := "sc-0868", scriptSig := bytes #[81],
    scriptPubKey := bytes #[154],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | BOOLAND" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0869. -/
def scriptVectors_0869 : ScrVec :=
  { id := "sc-0869", scriptSig := bytes #[81],
    scriptPubKey := bytes #[155],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | BOOLOR" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0870. -/
def scriptVectors_0870 : ScrVec :=
  { id := "sc-0870", scriptSig := bytes #[81],
    scriptPubKey := bytes #[156],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | NUMEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0871. -/
def scriptVectors_0871 : ScrVec :=
  { id := "sc-0871", scriptSig := bytes #[81],
    scriptPubKey := bytes #[157,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | NUMEQUALVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0872. -/
def scriptVectors_0872 : ScrVec :=
  { id := "sc-0872", scriptSig := bytes #[81],
    scriptPubKey := bytes #[158],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | NUMNOTEQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0873. -/
def scriptVectors_0873 : ScrVec :=
  { id := "sc-0873", scriptSig := bytes #[81],
    scriptPubKey := bytes #[159],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | LESSTHAN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0874. -/
def scriptVectors_0874 : ScrVec :=
  { id := "sc-0874", scriptSig := bytes #[81],
    scriptPubKey := bytes #[160],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | GREATERTHAN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0875. -/
def scriptVectors_0875 : ScrVec :=
  { id := "sc-0875", scriptSig := bytes #[81],
    scriptPubKey := bytes #[161],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | LESSTHANOREQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0876. -/
def scriptVectors_0876 : ScrVec :=
  { id := "sc-0876", scriptSig := bytes #[81],
    scriptPubKey := bytes #[162],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | GREATERTHANOREQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0877. -/
def scriptVectors_0877 : ScrVec :=
  { id := "sc-0877", scriptSig := bytes #[81],
    scriptPubKey := bytes #[163],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | MIN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0878. -/
def scriptVectors_0878 : ScrVec :=
  { id := "sc-0878", scriptSig := bytes #[81],
    scriptPubKey := bytes #[164],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | MAX" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0879. -/
def scriptVectors_0879 : ScrVec :=
  { id := "sc-0879", scriptSig := bytes #[81,81],
    scriptPubKey := bytes #[165],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 1 | WITHIN" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0880. -/
def scriptVectors_0880 : ScrVec :=
  { id := "sc-0880", scriptSig := bytes #[97],
    scriptPubKey := bytes #[166,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | RIPEMD160 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0881. -/
def scriptVectors_0881 : ScrVec :=
  { id := "sc-0881", scriptSig := bytes #[97],
    scriptPubKey := bytes #[167,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | SHA1 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0882. -/
def scriptVectors_0882 : ScrVec :=
  { id := "sc-0882", scriptSig := bytes #[97],
    scriptPubKey := bytes #[168,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | SHA256 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0883. -/
def scriptVectors_0883 : ScrVec :=
  { id := "sc-0883", scriptSig := bytes #[97],
    scriptPubKey := bytes #[169,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | HASH160 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0884. -/
def scriptVectors_0884 : ScrVec :=
  { id := "sc-0884", scriptSig := bytes #[97],
    scriptPubKey := bytes #[170,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "NOP | HASH256 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0885. -/
def scriptVectors_0885 : ScrVec :=
  { id := "sc-0885", scriptSig := bytes #[],
    scriptPubKey := bytes #[172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "CHECKSIG must error when there are no stack items" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0886. -/
def scriptVectors_0886 : ScrVec :=
  { id := "sc-0886", scriptSig := bytes #[0],
    scriptPubKey := bytes #[172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "CHECKSIG must error when there are not 2 stack items" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0887. -/
def scriptVectors_0887 : ScrVec :=
  { id := "sc-0887", scriptSig := bytes #[],
    scriptPubKey := bytes #[174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "CHECKMULTISIG must error when there are no stack items" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0888. -/
def scriptVectors_0888 : ScrVec :=
  { id := "sc-0888", scriptSig := bytes #[],
    scriptPubKey := bytes #[79,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "PUBKEY_COUNT",
    comment := "CHECKMULTISIG must error when the specified number of pubkeys is negative" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0889. -/
def scriptVectors_0889 : ScrVec :=
  { id := "sc-0889", scriptSig := bytes #[],
    scriptPubKey := bytes #[81,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "CHECKMULTISIG must error when there are not enough pubkeys on the stack" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0890. -/
def scriptVectors_0890 : ScrVec :=
  { id := "sc-0890", scriptSig := bytes #[],
    scriptPubKey := bytes #[79,0,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SIG_COUNT",
    comment := "CHECKMULTISIG must error when the specified number of signatures is negative" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0891. -/
def scriptVectors_0891 : ScrVec :=
  { id := "sc-0891", scriptSig := bytes #[],
    scriptPubKey := bytes #[81,3,112,107,49,81,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "CHECKMULTISIG must error when there are not enough signatures on the stack" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0892. -/
def scriptVectors_0892 : ScrVec :=
  { id := "sc-0892", scriptSig := bytes #[],
    scriptPubKey := bytes #[5,100,117,109,109,121,4,115,105,103,49,81,3,112,107,49,81,174,99,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "CHECKMULTISIG must push false to stack when signature is invalid when NOT in strict enc mode" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0893. -/
def scriptVectors_0893 : ScrVec :=
  { id := "sc-0893", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174,0,0,174],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "OP_COUNT",
    comment := "202 CHECKMULTISIGS, fails due to 201 op limit" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0894. -/
def scriptVectors_0894 : ScrVec :=
  { id := "sc-0894", scriptSig := bytes #[81],
    scriptPubKey := bytes #[0,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175,0,0,175],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "1 | 0 0 0 CHECKMULTISIGVERIFY 0 0 CHECKMULTISIGVERIFY 0 0 CHECKMULTISIGVERIFY 0 0 CHECKMULTISIGVERIFY 0 0 CHECKMULTISIGVERIFY 0 0 CHECKMULTISIGVERIFY 0 0 CHECKM" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0895. -/
def scriptVectors_0895 : ScrVec :=
  { id := "sc-0895", scriptSig := bytes #[],
    scriptPubKey := bytes #[97,97,97,97,97,97,97,97,97,97,97,97,97,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,174],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "OP_COUNT",
    comment := "Fails due to 201 script operation limit" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0896. -/
def scriptVectors_0896 : ScrVec :=
  { id := "sc-0896", scriptSig := bytes #[81],
    scriptPubKey := bytes #[97,97,97,97,97,97,97,97,97,97,97,97,97,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175,0,0,1,97,1,98,1,99,1,100,1,101,1,102,1,103,1,104,1,105,1,106,1,107,1,108,1,109,1,110,1,111,1,112,1,113,1,114,1,115,1,116,1,20,175],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "OP_COUNT",
    comment := "1 | NOP NOP NOP NOP NOP NOP NOP NOP NOP NOP NOP NOP NOP 0 0 'a' 'b' 'c' 'd' 'e' 'f' 'g' 'h' 'i' 'j' 'k' 'l' 'm' 'n' 'o' 'p' 'q' 'r' 's' 't' 20 CHECKMULTISIGVERI" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0897. -/
def scriptVectors_0897 : ScrVec :=
  { id := "sc-0897", scriptSig := bytes #[0,0,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,1,17,1,18,1,19,1,20,1,21],
    scriptPubKey := bytes #[1,21,174,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "PUBKEY_COUNT",
    comment := "nPubKeys > 20" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0898. -/
def scriptVectors_0898 : ScrVec :=
  { id := "sc-0898", scriptSig := bytes #[0,3,115,105,103,81,0],
    scriptPubKey := bytes #[174,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SIG_COUNT",
    comment := "nSigs > nPubKeys" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0899. -/
def scriptVectors_0899 : ScrVec :=
  { id := "sc-0899", scriptSig := bytes #[97,1,81],
    scriptPubKey := bytes #[169,20,218,23,69,233,181,73,189,11,250,26,86,153,113,199,126,186,48,205,90,75,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SIG_PUSHONLY",
    comment := "Tests for Script.IsPushOnly()" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0900. -/
def scriptVectors_0900 : ScrVec :=
  { id := "sc-0900", scriptSig := bytes #[176,1,81],
    scriptPubKey := bytes #[169,20,218,23,69,233,181,73,189,11,250,26,86,153,113,199,126,186,48,205,90,75,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SIG_PUSHONLY",
    comment := "NOP1 0x01 1 | HASH160 0x14 0xda1745e9b549bd0bfa1a569971c77eba30cd5a4b EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0901. -/
def scriptVectors_0901 : ScrVec :=
  { id := "sc-0901", scriptSig := bytes #[0,1,80],
    scriptPubKey := bytes #[169,20,236,228,36,166,187,109,223,77,181,146,192,250,237,96,104,80,71,163,97,177,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "OP_RESERVED in P2SH should fail" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0902. -/
def scriptVectors_0902 : ScrVec :=
  { id := "sc-0902", scriptSig := bytes #[0,1,98],
    scriptPubKey := bytes #[169,20,15,77,120,69,219,150,143,42,129,181,48,182,243,193,214,36,109,76,126,1,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "BAD_OPCODE",
    comment := "OP_VER in P2SH should fail" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0903. -/
def scriptVectors_0903 : ScrVec :=
  { id := "sc-0903", scriptSig := bytes #[0],
    scriptPubKey := bytes #[2,48,48,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "Basic OP_0 execution" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0904. -/
def scriptVectors_0904 : ScrVec :=
  { id := "sc-0904", scriptSig := bytes #[76,0],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "Empty vector minimally represented by OP_0" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0905. -/
def scriptVectors_0905 : ScrVec :=
  { id := "sc-0905", scriptSig := bytes #[1,129],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "-1 minimally represented by OP_1NEGATE" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0906. -/
def scriptVectors_0906 : ScrVec :=
  { id := "sc-0906", scriptSig := bytes #[1,1],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "1 to 16 minimally represented by OP_1 to OP_16" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0907. -/
def scriptVectors_0907 : ScrVec :=
  { id := "sc-0907", scriptSig := bytes #[1,2],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x02 | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0908. -/
def scriptVectors_0908 : ScrVec :=
  { id := "sc-0908", scriptSig := bytes #[1,3],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x03 | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0909. -/
def scriptVectors_0909 : ScrVec :=
  { id := "sc-0909", scriptSig := bytes #[1,4],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x04 | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0910. -/
def scriptVectors_0910 : ScrVec :=
  { id := "sc-0910", scriptSig := bytes #[1,5],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x05 | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0911. -/
def scriptVectors_0911 : ScrVec :=
  { id := "sc-0911", scriptSig := bytes #[1,6],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x06 | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0912. -/
def scriptVectors_0912 : ScrVec :=
  { id := "sc-0912", scriptSig := bytes #[1,7],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x07 | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0913. -/
def scriptVectors_0913 : ScrVec :=
  { id := "sc-0913", scriptSig := bytes #[1,8],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x08 | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0914. -/
def scriptVectors_0914 : ScrVec :=
  { id := "sc-0914", scriptSig := bytes #[1,9],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x09 | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0915. -/
def scriptVectors_0915 : ScrVec :=
  { id := "sc-0915", scriptSig := bytes #[1,10],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x0a | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0916. -/
def scriptVectors_0916 : ScrVec :=
  { id := "sc-0916", scriptSig := bytes #[1,11],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x0b | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0917. -/
def scriptVectors_0917 : ScrVec :=
  { id := "sc-0917", scriptSig := bytes #[1,12],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x0c | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0918. -/
def scriptVectors_0918 : ScrVec :=
  { id := "sc-0918", scriptSig := bytes #[1,13],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x0d | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0919. -/
def scriptVectors_0919 : ScrVec :=
  { id := "sc-0919", scriptSig := bytes #[1,14],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x0e | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0920. -/
def scriptVectors_0920 : ScrVec :=
  { id := "sc-0920", scriptSig := bytes #[1,15],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x0f | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0921. -/
def scriptVectors_0921 : ScrVec :=
  { id := "sc-0921", scriptSig := bytes #[1,16],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "0x01 0x10 | DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0922. -/
def scriptVectors_0922 : ScrVec :=
  { id := "sc-0922", scriptSig := bytes #[76,72,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "PUSHDATA1 of 72 bytes minimally represented by direct push" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0923. -/
def scriptVectors_0923 : ScrVec :=
  { id := "sc-0923", scriptSig := bytes #[77,255,0,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "PUSHDATA2 of 255 bytes minimally represented by PUSHDATA1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0924. -/
def scriptVectors_0924 : ScrVec :=
  { id := "sc-0924", scriptSig := bytes #[78,0,1,0,0,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17],
    scriptPubKey := bytes #[117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "MINIMALDATA",
    comment := "PUSHDATA4 of 256 bytes minimally represented by PUSHDATA2" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0925. -/
def scriptVectors_0925 : ScrVec :=
  { id := "sc-0925", scriptSig := bytes #[1,0],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "numequals 0" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0926. -/
def scriptVectors_0926 : ScrVec :=
  { id := "sc-0926", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "numequals 0" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0927. -/
def scriptVectors_0927 : ScrVec :=
  { id := "sc-0927", scriptSig := bytes #[1,128],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x80 (negative zero) numequals 0" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0928. -/
def scriptVectors_0928 : ScrVec :=
  { id := "sc-0928", scriptSig := bytes #[2,0,128],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "numequals 0" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0929. -/
def scriptVectors_0929 : ScrVec :=
  { id := "sc-0929", scriptSig := bytes #[2,5,0],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "numequals 5" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0930. -/
def scriptVectors_0930 : ScrVec :=
  { id := "sc-0930", scriptSig := bytes #[3,5,0,0],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "numequals 5" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0931. -/
def scriptVectors_0931 : ScrVec :=
  { id := "sc-0931", scriptSig := bytes #[2,5,128],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "numequals -5" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0932. -/
def scriptVectors_0932 : ScrVec :=
  { id := "sc-0932", scriptSig := bytes #[3,5,0,128],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "numequals -5" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0933. -/
def scriptVectors_0933 : ScrVec :=
  { id := "sc-0933", scriptSig := bytes #[3,255,127,128],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "Minimal encoding is 0xffff" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0934. -/
def scriptVectors_0934 : ScrVec :=
  { id := "sc-0934", scriptSig := bytes #[3,255,127,0],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "Minimal encoding is 0xff7f" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0935. -/
def scriptVectors_0935 : ScrVec :=
  { id := "sc-0935", scriptSig := bytes #[4,255,255,127,128],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "Minimal encoding is 0xffffff" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0936. -/
def scriptVectors_0936 : ScrVec :=
  { id := "sc-0936", scriptSig := bytes #[4,255,255,127,0],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "Minimal encoding is 0xffff7f" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0937. -/
def scriptVectors_0937 : ScrVec :=
  { id := "sc-0937", scriptSig := bytes #[81,2,0,0],
    scriptPubKey := bytes #[121,117],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "1 0x02 0x0000 | PICK DROP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0938. -/
def scriptVectors_0938 : ScrVec :=
  { id := "sc-0938", scriptSig := bytes #[81,2,0,0],
    scriptPubKey := bytes #[122,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "1 0x02 0x0000 | ROLL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0939. -/
def scriptVectors_0939 : ScrVec :=
  { id := "sc-0939", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[139,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 | 1ADD DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0940. -/
def scriptVectors_0940 : ScrVec :=
  { id := "sc-0940", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[140,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 | 1SUB DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0941. -/
def scriptVectors_0941 : ScrVec :=
  { id := "sc-0941", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[143,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 | NEGATE DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0942. -/
def scriptVectors_0942 : ScrVec :=
  { id := "sc-0942", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[144,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 | ABS DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0943. -/
def scriptVectors_0943 : ScrVec :=
  { id := "sc-0943", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[145,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 | NOT DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0944. -/
def scriptVectors_0944 : ScrVec :=
  { id := "sc-0944", scriptSig := bytes #[2,0,0],
    scriptPubKey := bytes #[146,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 | 0NOTEQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0945. -/
def scriptVectors_0945 : ScrVec :=
  { id := "sc-0945", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[147,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | ADD DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0946. -/
def scriptVectors_0946 : ScrVec :=
  { id := "sc-0946", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[147,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 | ADD DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0947. -/
def scriptVectors_0947 : ScrVec :=
  { id := "sc-0947", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[148,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | SUB DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0948. -/
def scriptVectors_0948 : ScrVec :=
  { id := "sc-0948", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[148,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 | SUB DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0949. -/
def scriptVectors_0949 : ScrVec :=
  { id := "sc-0949", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[154,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | BOOLAND DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0950. -/
def scriptVectors_0950 : ScrVec :=
  { id := "sc-0950", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[154,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 | BOOLAND DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0951. -/
def scriptVectors_0951 : ScrVec :=
  { id := "sc-0951", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[155,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | BOOLOR DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0952. -/
def scriptVectors_0952 : ScrVec :=
  { id := "sc-0952", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[155,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 | BOOLOR DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0953. -/
def scriptVectors_0953 : ScrVec :=
  { id := "sc-0953", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[156,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | NUMEQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0954. -/
def scriptVectors_0954 : ScrVec :=
  { id := "sc-0954", scriptSig := bytes #[2,0,0,81],
    scriptPubKey := bytes #[156,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 1 | NUMEQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0955. -/
def scriptVectors_0955 : ScrVec :=
  { id := "sc-0955", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[157,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | NUMEQUALVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0956. -/
def scriptVectors_0956 : ScrVec :=
  { id := "sc-0956", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[157,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 | NUMEQUALVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0957. -/
def scriptVectors_0957 : ScrVec :=
  { id := "sc-0957", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[158,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | NUMNOTEQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0958. -/
def scriptVectors_0958 : ScrVec :=
  { id := "sc-0958", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[158,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 | NUMNOTEQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0959. -/
def scriptVectors_0959 : ScrVec :=
  { id := "sc-0959", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[159,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | LESSTHAN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0960. -/
def scriptVectors_0960 : ScrVec :=
  { id := "sc-0960", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[159,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 | LESSTHAN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0961. -/
def scriptVectors_0961 : ScrVec :=
  { id := "sc-0961", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[160,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | GREATERTHAN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0962. -/
def scriptVectors_0962 : ScrVec :=
  { id := "sc-0962", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[160,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 | GREATERTHAN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0963. -/
def scriptVectors_0963 : ScrVec :=
  { id := "sc-0963", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[161,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | LESSTHANOREQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0964. -/
def scriptVectors_0964 : ScrVec :=
  { id := "sc-0964", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[161,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 | LESSTHANOREQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0965. -/
def scriptVectors_0965 : ScrVec :=
  { id := "sc-0965", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[162,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | GREATERTHANOREQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0966. -/
def scriptVectors_0966 : ScrVec :=
  { id := "sc-0966", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[162,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 | GREATERTHANOREQUAL DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0967. -/
def scriptVectors_0967 : ScrVec :=
  { id := "sc-0967", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[163,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | MIN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0968. -/
def scriptVectors_0968 : ScrVec :=
  { id := "sc-0968", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[163,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 | MIN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0969. -/
def scriptVectors_0969 : ScrVec :=
  { id := "sc-0969", scriptSig := bytes #[0,2,0,0],
    scriptPubKey := bytes #[164,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 | MAX DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0970. -/
def scriptVectors_0970 : ScrVec :=
  { id := "sc-0970", scriptSig := bytes #[2,0,0,0],
    scriptPubKey := bytes #[164,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 | MAX DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0971. -/
def scriptVectors_0971 : ScrVec :=
  { id := "sc-0971", scriptSig := bytes #[2,0,0,0,0],
    scriptPubKey := bytes #[165,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0x02 0x0000 0 0 | WITHIN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0972. -/
def scriptVectors_0972 : ScrVec :=
  { id := "sc-0972", scriptSig := bytes #[0,2,0,0,0],
    scriptPubKey := bytes #[165,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 0 | WITHIN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0973. -/
def scriptVectors_0973 : ScrVec :=
  { id := "sc-0973", scriptSig := bytes #[0,0,2,0,0],
    scriptPubKey := bytes #[165,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0 0x02 0x0000 | WITHIN DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0974. -/
def scriptVectors_0974 : ScrVec :=
  { id := "sc-0974", scriptSig := bytes #[0,0,2,0,0],
    scriptPubKey := bytes #[174,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0 0x02 0x0000 | CHECKMULTISIG DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0975. -/
def scriptVectors_0975 : ScrVec :=
  { id := "sc-0975", scriptSig := bytes #[0,2,0,0,0],
    scriptPubKey := bytes #[174,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 0 | CHECKMULTISIG DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0976. -/
def scriptVectors_0976 : ScrVec :=
  { id := "sc-0976", scriptSig := bytes #[0,2,0,0,0,81],
    scriptPubKey := bytes #[174,117,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 0 1 | CHECKMULTISIG DROP 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0977. -/
def scriptVectors_0977 : ScrVec :=
  { id := "sc-0977", scriptSig := bytes #[0,0,2,0,0],
    scriptPubKey := bytes #[175,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0 0x02 0x0000 | CHECKMULTISIGVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0978. -/
def scriptVectors_0978 : ScrVec :=
  { id := "sc-0978", scriptSig := bytes #[0,2,0,0,0],
    scriptPubKey := bytes #[175,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "0 0x02 0x0000 0 | CHECKMULTISIGVERIFY 1" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0979. -/
def scriptVectors_0979 : ScrVec :=
  { id := "sc-0979", scriptSig := bytes #[0,71,48,68,2,32,68,220,23,176,136,124,22,27,182,123,169,99,91,247,88,115,91,221,229,3,228,176,160,152,127,88,127,20,164,225,20,61,2,32,9,162,21,119,45,73,168,93,174,64,216,202,3,149,90,242,106,211,151,138,15,249,101,250,161,41,21,233,88,98,73,165,1,71,48,68,2,32,68,220,23,176,136,124,22,27,182,123,169,99,91,247,88,115,91,221,229,3,228,176,160,152,127,88,127,20,164,225,20,61,2,32,9,162,21,119,45,73,168,93,174,64,216,202,3,149,90,242,106,211,151,138,15,249,101,250,161,41,21,233,88,98,73,165,1],
    scriptPubKey := bytes #[82,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,0,82,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "PUBKEYTYPE",
    comment := "2-of-2 CHECKMULTISIG NOT with the first pubkey invalid, and both signatures validly encoded." }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0980. -/
def scriptVectors_0980 : ScrVec :=
  { id := "sc-0980", scriptSig := bytes #[0,71,48,68,2,32,68,220,23,176,136,124,22,27,182,123,169,99,91,247,88,115,91,221,229,3,228,176,160,152,127,88,127,20,164,225,20,61,2,32,9,162,21,119,45,73,168,93,174,64,216,202,3,149,90,242,106,211,151,138,15,249,101,250,161,41,21,233,88,98,73,165,1,81],
    scriptPubKey := bytes #[82,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,82,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SIG_DER",
    comment := "2-of-2 CHECKMULTISIG NOT with both pubkeys valid, but first signature invalid (STRICTENC enabled)." }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0981. -/
def scriptVectors_0981 : ScrVec :=
  { id := "sc-0981", scriptSig := bytes #[0,71,48,68,2,32,68,220,23,176,136,124,22,27,182,123,169,99,91,247,88,115,91,221,229,3,228,176,160,152,127,88,127,20,164,225,20,61,2,32,9,162,21,119,45,73,168,93,174,64,216,202,3,149,90,242,106,211,151,138,15,249,101,250,161,41,21,233,88,98,73,165,1,81],
    scriptPubKey := bytes #[82,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,82,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "2-of-2 CHECKMULTISIG NOT with both pubkeys valid, but first signature invalid (DERSIG enabled)." }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0982. -/
def scriptVectors_0982 : ScrVec :=
  { id := "sc-0982", scriptSig := bytes #[0,71,48,68,2,32,84,81,206,101,173,132,77,187,151,139,139,222,223,80,130,227,59,67,202,232,39,156,48,242,199,77,158,158,228,154,148,248,2,32,63,233,90,124,207,116,218,122,35,46,229,35,239,74,83,203,77,20,189,209,98,137,104,12,219,151,166,56,25,184,244,47,1,70,48,68,2,32,84,81,206,101,173,132,77,187,151,139,139,222,223,80,130,227,59,67,202,232,39,156,48,242,199,77,158,158,228,154,148,248,2,32,63,233,90,124,207,116,218,122,35,46,229,35,239,74,83,203,77,20,189,209,98,137,104,12,219,151,166,56,25,184,244,47],
    scriptPubKey := bytes #[82,33,2,166,115,99,140,185,88,124,182,142,160,141,190,246,133,198,242,210,167,81,168,179,198,242,167,233,164,153,158,110,75,250,245,33,2,166,115,99,140,185,88,124,182,142,160,141,190,246,133,198,242,210,167,81,168,179,198,242,167,233,164,153,158,110,75,250,245,33,2,166,115,99,140,185,88,124,182,142,160,141,190,246,133,198,242,210,167,81,168,179,198,242,167,233,164,153,158,110,75,250,245,83,174],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SIG_DER",
    comment := "2-of-3 with one valid and one invalid signature due to parse error, nSigs > validSigs (STRICTENC enabled)." }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0983. -/
def scriptVectors_0983 : ScrVec :=
  { id := "sc-0983", scriptSig := bytes #[0,71,48,68,2,32,84,81,206,101,173,132,77,187,151,139,139,222,223,80,130,227,59,67,202,232,39,156,48,242,199,77,158,158,228,154,148,248,2,32,63,233,90,124,207,116,218,122,35,46,229,35,239,74,83,203,77,20,189,209,98,137,104,12,219,151,166,56,25,184,244,47,1,70,48,68,2,32,84,81,206,101,173,132,77,187,151,139,139,222,223,80,130,227,59,67,202,232,39,156,48,242,199,77,158,158,228,154,148,248,2,32,63,233,90,124,207,116,218,122,35,46,229,35,239,74,83,203,77,20,189,209,98,137,104,12,219,151,166,56,25,184,244,47],
    scriptPubKey := bytes #[82,33,2,166,115,99,140,185,88,124,182,142,160,141,190,246,133,198,242,210,167,81,168,179,198,242,167,233,164,153,158,110,75,250,245,33,2,166,115,99,140,185,88,124,182,142,160,141,190,246,133,198,242,210,167,81,168,179,198,242,167,233,164,153,158,110,75,250,245,33,2,166,115,99,140,185,88,124,182,142,160,141,190,246,133,198,242,210,167,81,168,179,198,242,167,233,164,153,158,110,75,250,245,83,174],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "2-of-3 with one valid and one invalid signature due to parse error, nSigs > validSigs (DERSIG enabled)." }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0984. -/
def scriptVectors_0984 : ScrVec :=
  { id := "sc-0984", scriptSig := bytes #[0],
    scriptPubKey := bytes #[33,6,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "33-byte pubkey with a prefix other than 0x02/0x03 is correctly encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0985. -/
def scriptVectors_0985 : ScrVec :=
  { id := "sc-0985", scriptSig := bytes #[0],
    scriptPubKey := bytes #[33,6,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "PUBKEYTYPE",
    comment := "33-byte pubkey with a prefix other than 0x02/0x03 is incorrectly encoded for STRICTENC" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0986. -/
def scriptVectors_0986 : ScrVec :=
  { id := "sc-0986", scriptSig := bytes #[74,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "Overly long signature is incorrectly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0987. -/
def scriptVectors_0987 : ScrVec :=
  { id := "sc-0987", scriptSig := bytes #[37,48,34,2,32,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "Missing S is incorrectly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0988. -/
def scriptVectors_0988 : ScrVec :=
  { id := "sc-0988", scriptSig := bytes #[39,48,36,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,2,10,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "S with invalid S length is incorrectly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0989. -/
def scriptVectors_0989 : ScrVec :=
  { id := "sc-0989", scriptSig := bytes #[39,48,36,3,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "Non-integer R is incorrectly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0990. -/
def scriptVectors_0990 : ScrVec :=
  { id := "sc-0990", scriptSig := bytes #[39,48,36,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,3,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "Non-integer S is incorrectly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0991. -/
def scriptVectors_0991 : ScrVec :=
  { id := "sc-0991", scriptSig := bytes #[23,48,20,2,0,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "Zero-length R is incorrectly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0992. -/
def scriptVectors_0992 : ScrVec :=
  { id := "sc-0992", scriptSig := bytes #[23,48,20,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,2,0,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "Zero-length S is incorrectly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0993. -/
def scriptVectors_0993 : ScrVec :=
  { id := "sc-0993", scriptSig := bytes #[39,48,36,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,2,16,135,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "Negative S is incorrectly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0994. -/
def scriptVectors_0994 : ScrVec :=
  { id := "sc-0994", scriptSig := bytes #[39,49,36,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,2,16,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,119,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "Non-compound type is incorrectly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0995. -/
def scriptVectors_0995 : ScrVec :=
  { id := "sc-0995", scriptSig := bytes #[74,48,71,2,34,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,33,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "74-byte signature is incorrectly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0996. -/
def scriptVectors_0996 : ScrVec :=
  { id := "sc-0996", scriptSig := bytes #[73,48,70,2,33,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,2,33,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "73-byte signature is correctly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0997. -/
def scriptVectors_0997 : ScrVec :=
  { id := "sc-0997", scriptSig := bytes #[71,48,67,2,32,68,220,23,176,136,124,22,27,182,123,169,99,91,247,88,115,91,221,229,3,228,176,160,152,127,88,127,20,164,225,20,61,2,32,9,162,21,119,45,73,168,93,174,64,216,202,3,149,90,242,106,211,151,138,15,249,101,250,161,41,21,233,88,98,73,165,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "Total-length byte not covering the entire signature is incorrectly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0998. -/
def scriptVectors_0998 : ScrVec :=
  { id := "sc-0998", scriptSig := bytes #[9,48,6,2,1,0,2,1,1,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Null R byte is correctly encoded for DERSIG when R is a single byte" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 0999. -/
def scriptVectors_0999 : ScrVec :=
  { id := "sc-0999", scriptSig := bytes #[9,48,6,2,1,1,2,1,0,1],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Null S byte is correctly encoded for DERSIG when S is a single byte" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1000. -/
def scriptVectors_1000 : ScrVec :=
  { id := "sc-1000", scriptSig := bytes #[3,48,0,0],
    scriptPubKey := bytes #[0,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "3-byte signature is incorrectly encoded for DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1001. -/
def scriptVectors_1001 : ScrVec :=
  { id := "sc-1001", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,110,52,11,156,255,179,122,152,156,165,68,230,187,120,10,44,120,144,29,63,179,55,56,118,133,17,163,6,23,175,160,29],
    witness := [bytes #[0]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "Invalid witness script" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1002. -/
def scriptVectors_1002 : ScrVec :=
  { id := "sc-1002", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,110,52,11,156,255,179,122,152,156,165,68,230,187,120,10,44,120,144,29,63,179,55,56,118,133,17,163,6,23,175,160,29],
    witness := [bytes #[81]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_PROGRAM_MISMATCH",
    comment := "Witness script hash mismatch" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1003. -/
def scriptVectors_1003 : ScrVec :=
  { id := "sc-1003", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,74,232,21,114,240,110,27,136,253,92,237,122,26,0,9,69,67,46,131,225,85,30,111,114,30,233,192,11,140,195,50,97],
    witness := [bytes #[81]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_PROGRAM_MISMATCH",
    comment := "Witness script hash mismatch (last byte differs)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1004. -/
def scriptVectors_1004 : ScrVec :=
  { id := "sc-1004", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,110,52,11,156,255,179,122,152,156,165,68,230,187,120,10,44,120,144,29,63,179,55,56,118,133,17,163,6,23,175,160,29],
    witness := [bytes #[0]],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Invalid witness script without WITNESS" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1005. -/
def scriptVectors_1005 : ScrVec :=
  { id := "sc-1005", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,110,52,11,156,255,179,122,152,156,165,68,230,187,120,10,44,120,144,29,63,179,55,56,118,133,17,163,6,23,175,160,29],
    witness := [bytes #[81]],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Witness script hash mismatch without WITNESS" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1006. -/
def scriptVectors_1006 : ScrVec :=
  { id := "sc-1006", scriptSig := bytes #[],
    scriptPubKey := bytes #[79,2,18,52],
    witness := [bytes #[81]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_UNEXPECTED",
    comment := "OP_1NEGATE does not introduce a witness program" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1007. -/
def scriptVectors_1007 : ScrVec :=
  { id := "sc-1007", scriptSig := bytes #[0],
    scriptPubKey := bytes #[81,2,18,52],
    witness := [bytes #[81]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_MALLEATED",
    comment := "OP_1 does introduce a witness program" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1008. -/
def scriptVectors_1008 : ScrVec :=
  { id := "sc-1008", scriptSig := bytes #[0],
    scriptPubKey := bytes #[96,2,18,52],
    witness := [bytes #[81]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_MALLEATED",
    comment := "OP_16 does introduce a witness program" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1009. -/
def scriptVectors_1009 : ScrVec :=
  { id := "sc-1009", scriptSig := bytes #[],
    scriptPubKey := bytes #[97,2,18,52],
    witness := [bytes #[81]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_UNEXPECTED",
    comment := "NOP does not introduce a witness program" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1010. -/
def scriptVectors_1010 : ScrVec :=
  { id := "sc-1010", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,115,160,160,120,203,95,143,57,207,251,174,172,153,157,162,87,46,101,34,158,249,207,69,16,207,167,101,191,225,170,24,84],
    witness := [bytes #[97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,97,81]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "OP_COUNT",
    comment := ">201 opcodes executed in a P2WSH witness script." }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1011. -/
def scriptVectors_1011 : ScrVec :=
  { id := "sc-1011", scriptSig := bytes #[71,48,68,2,32,10,92,97,99,240,123,141,59,1,60,77,29,109,186,37,231,128,179,150,88,215,155,163,122,247,5,122,59,127,21,255,161,2,32,31,217,180,234,169,148,63,115,73,40,185,154,131,89,44,46,123,243,66,234,38,128,246,162,187,112,81,103,150,107,116,32,1],
    scriptPubKey := bytes #[65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1012. -/
def scriptVectors_1012 : ScrVec :=
  { id := "sc-1012", scriptSig := bytes #[71,48,68,2,32,10,92,97,99,240,123,140,59,1,60,77,29,109,186,37,231,128,179,150,88,215,155,163,122,247,5,122,59,127,21,255,161,2,32,31,217,180,234,169,148,63,115,73,40,185,154,131,89,44,46,123,243,66,234,38,128,246,162,187,112,81,103,150,107,116,32,1],
    scriptPubKey := bytes #[65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "P2PK, bad sig" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1013. -/
def scriptVectors_1013 : ScrVec :=
  { id := "sc-1013", scriptSig := bytes #[71,48,68,2,32,110,5,166,254,35,197,145,150,255,225,118,201,221,195,30,115,169,136,86,56,249,209,50,141,71,192,199,3,134,59,136,118,2,32,118,254,181,56,17,170,91,4,224,231,159,147,142,177,153,6,204,94,103,84,139,197,85,168,232,184,176,252,96,61,132,12,1,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8],
    scriptPubKey := bytes #[118,169,20,16,24,133,54,112,249,243,176,88,44,91,158,232,206,147,118,74,195,43,147,136,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PKH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1014. -/
def scriptVectors_1014 : ScrVec :=
  { id := "sc-1014", scriptSig := bytes #[71,48,68,2,32,52,187,4,148,181,11,142,241,48,226,24,91,178,32,38,91,146,132,239,91,75,138,141,164,216,65,93,244,137,200,59,81,2,32,98,89,162,109,156,192,161,37,172,38,175,97,83,177,124,2,149,104,85,235,225,70,116,18,240,102,228,2,245,240,93,18,1,33,3,54,61,144,212,70,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64],
    scriptPubKey := bytes #[118,169,20,192,131,76,12,21,143,83,190,112,109,35,76,56,253,82,222,126,236,230,86,136,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EQUALVERIFY",
    comment := "P2PKH, bad pubkey" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1015. -/
def scriptVectors_1015 : ScrVec :=
  { id := "sc-1015", scriptSig := bytes #[71,48,68,2,32,71,16,168,81,129,102,59,50,210,92,112,236,43,189,20,173,255,93,223,255,108,181,13,9,225,85,239,95,84,31,200,108,2,32,5,107,12,201,73,190,147,134,236,197,246,194,172,4,147,38,144,49,219,177,133,120,29,185,1,113,181,74,193,39,121,2,129],
    scriptPubKey := bytes #[65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK anyonecanpay" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1016. -/
def scriptVectors_1016 : ScrVec :=
  { id := "sc-1016", scriptSig := bytes #[71,48,68,2,32,71,16,168,81,129,102,59,50,210,92,112,236,43,189,20,173,255,93,223,255,108,181,13,9,225,85,239,95,84,31,200,108,2,32,5,107,12,201,73,190,147,134,236,197,246,194,172,4,147,38,144,49,219,177,133,120,29,185,1,113,181,74,193,39,121,2,1],
    scriptPubKey := bytes #[65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "P2PK anyonecanpay marked with normal hashtype" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1017. -/
def scriptVectors_1017 : ScrVec :=
  { id := "sc-1017", scriptSig := bytes #[71,48,68,2,32,3,254,244,46,214,199,190,137,23,68,18,24,245,37,166,14,36,49,190,151,142,40,183,172,164,215,165,50,204,65,58,232,2,32,103,161,248,44,116,232,214,146,145,185,13,20,135,120,64,92,98,87,187,207,194,53,60,195,138,62,31,34,191,68,37,70,1,35,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,172],
    scriptPubKey := bytes #[169,20,35,176,173,52,119,242,23,139,192,179,238,210,110,78,99,22,244,232,58,161,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2SH(P2PK)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1018. -/
def scriptVectors_1018 : ScrVec :=
  { id := "sc-1018", scriptSig := bytes #[71,48,68,2,32,3,254,244,46,214,199,190,137,23,68,18,24,245,37,166,14,36,49,190,151,142,40,183,172,164,215,165,50,204,65,58,232,2,32,103,161,248,44,116,232,214,146,145,185,13,20,135,120,64,92,98,87,187,207,194,53,60,195,138,62,31,34,191,68,37,70,1,35,33,2,121,190,102,126,249,220,187,172,84,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,172],
    scriptPubKey := bytes #[169,20,35,176,173,52,119,242,23,139,192,179,238,210,110,78,99,22,244,232,58,161,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "P2SH(P2PK), bad redeemscript" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1019. -/
def scriptVectors_1019 : ScrVec :=
  { id := "sc-1019", scriptSig := bytes #[71,48,68,2,32,120,27,164,245,154,123,32,122,16,219,135,98,139,194,22,141,244,213,155,132,75,57,125,45,188,154,88,53,251,47,43,118,2,32,110,216,251,204,16,114,254,45,252,91,178,89,9,38,158,93,196,47,252,174,126,194,188,129,213,150,146,33,15,243,12,43,1,65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,25,118,169,20,145,178,75,249,245,40,133,50,150,10,198,135,171,176,53,18,123,29,40,165,136,172],
    scriptPubKey := bytes #[169,20,127,103,240,82,25,52,165,125,48,57,247,127,159,50,207,49,63,58,199,75,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2SH(P2PKH)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1020. -/
def scriptVectors_1020 : ScrVec :=
  { id := "sc-1020", scriptSig := bytes #[71,48,68,2,32,78,46,176,52,190,123,8,149,52,172,158,121,140,246,162,199,159,56,188,179,77,27,23,158,253,111,45,224,132,23,53,219,2,32,113,70,27,235,5,107,90,123,225,129,157,166,163,227,206,54,98,131,30,204,41,132,25,202,16,30,182,136,123,93,214,164,1,25,118,169,20,124,249,200,70,205,72,130,239,236,75,240,126,68,235,218,212,149,201,79,75,136,172],
    scriptPubKey := bytes #[169,20,45,245,25,148,61,90,204,14,245,34,32,145,249,223,227,84,63,72,154,130,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2SH(P2PKH), bad sig but no VERIFY_P2SH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1021. -/
def scriptVectors_1021 : ScrVec :=
  { id := "sc-1021", scriptSig := bytes #[71,48,68,2,32,78,46,176,52,190,123,8,149,52,172,158,121,140,246,162,199,159,56,188,179,77,27,23,158,253,111,45,224,132,23,53,219,2,32,113,70,27,235,5,107,90,123,225,129,157,166,163,227,206,54,98,131,30,204,41,132,25,202,16,30,182,136,123,93,214,164,1,25,118,169,20,124,249,200,70,205,72,130,239,236,75,240,126,68,235,218,212,149,201,79,75,136,172],
    scriptPubKey := bytes #[169,20,45,245,25,148,61,90,204,14,245,34,32,145,249,223,227,84,63,72,154,130,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EQUALVERIFY",
    comment := "P2SH(P2PKH), bad sig" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1022. -/
def scriptVectors_1022 : ScrVec :=
  { id := "sc-1022", scriptSig := bytes #[0,71,48,68,2,32,81,37,75,159,180,118,165,45,133,83,7,146,181,120,248,111,234,112,236,31,251,67,147,230,97,188,204,178,61,141,99,211,2,32,118,80,95,148,164,3,200,96,151,132,25,68,224,68,199,12,32,69,206,144,227,109,229,31,126,157,56,40,219,152,160,117,1,71,48,68,2,32,10,53,143,117,9,52,179,254,184,34,241,150,107,252,216,187,236,158,234,163,168,202,148,30,17,238,89,96,225,129,250,1,2,32,80,191,107,90,142,119,80,247,3,84,174,4,28,182,138,123,173,230,126,198,195,171,25,235,53,150,56,151,68,16,98,110,1,71,48,68,2,32,9,85,208,49,255,247,29,134,83,34,30,133,227,108,60,133,83,61,35,18,252,48,69,49,75,25,101,11,122,226,248,16,2,32,42,107,184,80,94,54,32,25,9,208,146,31,1,171,255,57,10,230,183,255,151,187,249,89,249,138,237,235,10,86,115,9,1],
    scriptPubKey := bytes #[83,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,83,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "3-of-3" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1023. -/
def scriptVectors_1023 : ScrVec :=
  { id := "sc-1023", scriptSig := bytes #[0,71,48,68,2,32,81,37,75,159,180,118,165,45,133,83,7,146,181,120,248,111,234,112,236,31,251,67,147,230,97,188,204,178,61,141,99,211,2,32,118,80,95,148,164,3,200,96,151,132,25,68,224,68,199,12,32,69,206,144,227,109,229,31,126,157,56,40,219,152,160,117,1,71,48,68,2,32,10,53,143,117,9,52,179,254,184,34,241,150,107,252,216,187,236,158,234,163,168,202,148,30,17,238,89,96,225,129,250,1,2,32,80,191,107,90,142,119,80,247,3,84,174,4,28,182,138,123,173,230,126,198,195,171,25,235,53,150,56,151,68,16,98,110,1,0],
    scriptPubKey := bytes #[83,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,83,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "3-of-3, 2 sigs" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1024. -/
def scriptVectors_1024 : ScrVec :=
  { id := "sc-1024", scriptSig := bytes #[0,71,48,68,2,32,91,125,44,47,23,122,231,108,251,191,20,213,137,193,19,176,179,93,183,83,211,5,213,86,45,208,182,28,191,54,108,251,2,32,46,86,249,60,79,8,162,127,152,108,212,36,255,196,138,70,44,50,2,196,144,33,4,212,208,255,152,237,40,244,191,128,1,71,48,68,2,32,86,62,91,59,31,193,22,98,168,75,197,234,42,50,204,56,25,112,50,84,6,11,163,13,99,154,26,175,45,80,104,173,2,32,96,28,31,71,221,199,109,147,40,77,217,237,104,247,201,151,76,74,14,167,203,232,162,71,214,188,56,120,86,122,95,202,1,76,105,82,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,83,174],
    scriptPubKey := bytes #[169,20,201,228,168,150,209,73,112,45,13,22,149,67,79,237,221,82,226,74,215,141,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2SH(2-of-3)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1025. -/
def scriptVectors_1025 : ScrVec :=
  { id := "sc-1025", scriptSig := bytes #[0,71,48,68,2,32,91,125,44,47,23,122,231,108,251,191,20,213,137,193,19,176,179,93,183,83,211,5,213,86,45,208,182,28,191,54,108,251,2,32,46,86,249,60,79,8,162,127,152,108,212,36,255,196,138,70,44,50,2,196,144,33,4,212,208,255,152,237,40,244,191,128,1,0,76,105,82,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,83,174],
    scriptPubKey := bytes #[169,20,201,228,168,150,209,73,112,45,13,22,149,67,79,237,221,82,226,74,215,141,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "P2SH(2-of-3), 1 sig" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1026. -/
def scriptVectors_1026 : ScrVec :=
  { id := "sc-1026", scriptSig := bytes #[71,48,68,2,32,0,96,85,132,119,51,123,144,34,231,5,52,241,254,167,26,49,140,175,131,104,18,70,90,37,9,147,28,94,124,73,135,2,32,120,236,50,189,80,172,158,3,163,73,186,149,61,253,159,225,200,210,221,139,219,29,56,221,202,132,77,61,92,120,193,24,1],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK with too much R padding but no DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1027. -/
def scriptVectors_1027 : ScrVec :=
  { id := "sc-1027", scriptSig := bytes #[71,48,68,2,32,0,96,85,132,119,51,123,144,34,231,5,52,241,254,167,26,49,140,175,131,104,18,70,90,37,9,147,28,94,124,73,135,2,32,120,236,50,189,80,172,158,3,163,73,186,149,61,253,159,225,200,210,221,139,219,29,56,221,202,132,77,61,92,120,193,24,1],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "P2PK with too much R padding" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1028. -/
def scriptVectors_1028 : ScrVec :=
  { id := "sc-1028", scriptSig := bytes #[72,48,69,2,32,45,232,192,63,197,37,40,92,156,83,86,49,1,154,95,42,247,198,69,79,169,235,57,42,55,86,164,145,124,66,14,221,2,33,0,70,19,11,242,186,247,207,192,101,6,124,139,158,51,160,102,217,193,94,220,234,159,235,12,162,210,51,227,89,121,37,180,1],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK with too much S padding but no DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1029. -/
def scriptVectors_1029 : ScrVec :=
  { id := "sc-1029", scriptSig := bytes #[72,48,69,2,32,45,232,192,63,197,37,40,92,156,83,86,49,1,154,95,42,247,198,69,79,169,235,57,42,55,86,164,145,124,66,14,221,2,33,0,70,19,11,242,186,247,207,192,101,6,124,139,158,51,160,102,217,193,94,220,234,159,235,12,162,210,51,227,89,121,37,180,1],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "P2PK with too much S padding" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1030. -/
def scriptVectors_1030 : ScrVec :=
  { id := "sc-1030", scriptSig := bytes #[71,48,68,2,32,215,160,65,124,63,109,26,21,9,77,28,242,163,55,140,160,80,62,184,165,118,48,149,58,158,41,135,226,29,221,10,101,2,32,122,98,102,214,134,201,144,144,146,2,73,153,29,61,66,6,91,109,67,235,112,24,123,33,156,13,184,46,79,148,209,162,1],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK with too little R padding but no DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1031. -/
def scriptVectors_1031 : ScrVec :=
  { id := "sc-1031", scriptSig := bytes #[71,48,68,2,32,215,160,65,124,63,109,26,21,9,77,28,242,163,55,140,160,80,62,184,165,118,48,149,58,158,41,135,226,29,221,10,101,2,32,122,98,102,214,134,201,144,144,146,2,73,153,29,61,66,6,91,109,67,235,112,24,123,33,156,13,184,46,79,148,209,162,1],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "P2PK with too little R padding" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1032. -/
def scriptVectors_1032 : ScrVec :=
  { id := "sc-1032", scriptSig := bytes #[71,48,68,2,32,0,94,206,19,53,231,247,87,161,161,244,118,167,251,91,217,9,100,232,160,34,72,159,137,6,20,160,74,207,183,52,192,2,32,108,18,184,41,74,101,19,199,113,14,140,130,211,194,61,117,205,191,232,50,0,235,126,251,73,87,1,149,133,1,165,214,1],
    scriptPubKey := bytes #[33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK NOT with bad sig with too much R padding but no DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1033. -/
def scriptVectors_1033 : ScrVec :=
  { id := "sc-1033", scriptSig := bytes #[71,48,68,2,32,0,94,206,19,53,231,247,87,161,161,244,118,167,251,91,217,9,100,232,160,34,72,159,137,6,20,160,74,207,183,52,192,2,32,108,18,184,41,74,101,19,199,113,14,140,130,211,194,61,117,205,191,232,50,0,235,126,251,73,87,1,149,133,1,165,214,1],
    scriptPubKey := bytes #[33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "P2PK NOT with bad sig with too much R padding" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1034. -/
def scriptVectors_1034 : ScrVec :=
  { id := "sc-1034", scriptSig := bytes #[71,48,68,2,32,0,94,206,19,53,231,246,87,161,161,244,118,167,251,91,217,9,100,232,160,34,72,159,137,6,20,160,74,207,183,52,192,2,32,108,18,184,41,74,101,19,199,113,14,140,130,211,194,61,117,205,191,232,50,0,235,126,251,73,87,1,149,133,1,165,214,1],
    scriptPubKey := bytes #[33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "P2PK NOT with too much R padding but no DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1035. -/
def scriptVectors_1035 : ScrVec :=
  { id := "sc-1035", scriptSig := bytes #[71,48,68,2,32,0,94,206,19,53,231,246,87,161,161,244,118,167,251,91,217,9,100,232,160,34,72,159,137,6,20,160,74,207,183,52,192,2,32,108,18,184,41,74,101,19,199,113,14,140,130,211,194,61,117,205,191,232,50,0,235,126,251,73,87,1,149,133,1,165,214,1],
    scriptPubKey := bytes #[33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "P2PK NOT with too much R padding" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1036. -/
def scriptVectors_1036 : ScrVec :=
  { id := "sc-1036", scriptSig := bytes #[71,48,68,2,32,215,160,65,124,63,109,26,21,9,77,28,242,163,55,140,160,80,62,184,165,118,48,149,58,158,41,135,226,29,221,10,101,2,32,122,98,102,214,134,201,144,144,146,2,73,153,29,61,66,6,91,109,67,235,112,24,123,33,156,13,184,46,79,148,209,162,1],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 example 1, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1037. -/
def scriptVectors_1037 : ScrVec :=
  { id := "sc-1037", scriptSig := bytes #[71,48,68,2,32,215,160,65,124,63,109,26,21,9,77,28,242,163,55,140,160,80,62,184,165,118,48,149,58,158,41,135,226,29,221,10,101,2,32,122,98,102,214,134,201,144,144,146,2,73,153,29,61,66,6,91,109,67,235,112,24,123,33,156,13,184,46,79,148,209,162,1],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "BIP66 example 1, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1038. -/
def scriptVectors_1038 : ScrVec :=
  { id := "sc-1038", scriptSig := bytes #[71,48,68,2,32,142,67,192,185,31,124,30,91,197,142,65,200,24,95,138,96,134,225,17,176,9,1,135,150,138,134,242,130,36,98,211,201,2,32,10,88,244,7,107,17,51,177,143,241,220,131,238,81,103,110,68,198,12,198,8,217,83,78,13,245,172,224,66,79,192,190,1],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "BIP66 example 2, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1039. -/
def scriptVectors_1039 : ScrVec :=
  { id := "sc-1039", scriptSig := bytes #[71,48,68,2,32,142,67,192,185,31,124,30,91,197,142,65,200,24,95,138,96,134,225,17,176,9,1,135,150,138,134,242,130,36,98,211,201,2,32,10,88,244,7,107,17,51,177,143,241,220,131,238,81,103,110,68,198,12,198,8,217,83,78,13,245,172,224,66,79,192,190,1],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "BIP66 example 2, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1040. -/
def scriptVectors_1040 : ScrVec :=
  { id := "sc-1040", scriptSig := bytes #[0],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "BIP66 example 3, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1041. -/
def scriptVectors_1041 : ScrVec :=
  { id := "sc-1041", scriptSig := bytes #[0],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "BIP66 example 3, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1042. -/
def scriptVectors_1042 : ScrVec :=
  { id := "sc-1042", scriptSig := bytes #[0],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 example 4, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1043. -/
def scriptVectors_1043 : ScrVec :=
  { id := "sc-1043", scriptSig := bytes #[0],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 example 4, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1044. -/
def scriptVectors_1044 : ScrVec :=
  { id := "sc-1044", scriptSig := bytes #[9,48,6,2,1,1,2,1,1,1],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 example 4, with DERSIG, non-null DER-compliant signature" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1045. -/
def scriptVectors_1045 : ScrVec :=
  { id := "sc-1045", scriptSig := bytes #[0],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "NULLFAIL",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 example 4, with DERSIG and NULLFAIL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1046. -/
def scriptVectors_1046 : ScrVec :=
  { id := "sc-1046", scriptSig := bytes #[9,48,6,2,1,1,2,1,1,1],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "NULLFAIL",
    expectOk := false, expectedError := "NULLFAIL",
    comment := "BIP66 example 4, with DERSIG and NULLFAIL, non-null DER-compliant signature" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1047. -/
def scriptVectors_1047 : ScrVec :=
  { id := "sc-1047", scriptSig := bytes #[81],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "BIP66 example 5, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1048. -/
def scriptVectors_1048 : ScrVec :=
  { id := "sc-1048", scriptSig := bytes #[81],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "BIP66 example 5, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1049. -/
def scriptVectors_1049 : ScrVec :=
  { id := "sc-1049", scriptSig := bytes #[81],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 example 6, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1050. -/
def scriptVectors_1050 : ScrVec :=
  { id := "sc-1050", scriptSig := bytes #[81],
    scriptPubKey := bytes #[33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "BIP66 example 6, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1051. -/
def scriptVectors_1051 : ScrVec :=
  { id := "sc-1051", scriptSig := bytes #[0,71,48,68,2,32,202,224,11,20,68,186,191,191,96,113,176,186,135,7,246,189,55,61,163,223,73,77,110,116,17,155,4,48,197,219,129,5,2,32,93,82,49,184,197,147,156,143,240,200,34,66,101,109,110,6,237,176,115,212,42,243,54,201,159,232,131,124,54,234,57,213,1,71,48,68,2,32,39,194,113,66,105,202,90,238,204,77,112,237,200,139,165,238,14,61,164,152,110,146,22,2,143,72,154,180,241,184,239,206,2,32,34,189,84,91,73,81,33,82,103,228,197,206,171,212,197,53,3,49,178,228,160,182,73,76,86,243,97,250,90,87,161,162,1],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,82,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 example 7, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1052. -/
def scriptVectors_1052 : ScrVec :=
  { id := "sc-1052", scriptSig := bytes #[0,71,48,68,2,32,202,224,11,20,68,186,191,191,96,113,176,186,135,7,246,189,55,61,163,223,73,77,110,116,17,155,4,48,197,219,129,5,2,32,93,82,49,184,197,147,156,143,240,200,34,66,101,109,110,6,237,176,115,212,42,243,54,201,159,232,131,124,54,234,57,213,1,71,48,68,2,32,39,194,113,66,105,202,90,238,204,77,112,237,200,139,165,238,14,61,164,152,110,146,22,2,143,72,154,180,241,184,239,206,2,32,34,189,84,91,73,81,33,82,103,228,197,206,171,212,197,53,3,49,178,228,160,182,73,76,86,243,97,250,90,87,161,162,1],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,82,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "BIP66 example 7, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1053. -/
def scriptVectors_1053 : ScrVec :=
  { id := "sc-1053", scriptSig := bytes #[0,71,48,68,2,32,177,25,214,125,56,147,21,48,141,23,69,247,52,165,31,243,236,114,224,96,129,232,78,35,111,223,157,194,245,210,166,72,2,32,75,4,227,188,56,103,76,68,34,234,49,114,49,214,66,181,109,192,157,33,74,30,203,191,22,236,202,1,237,153,110,34,1,71,48,68,2,32,121,234,128,175,213,56,217,173,164,33,181,16,31,235,235,107,200,116,224,29,222,91,202,16,140,29,4,121,174,195,57,164,2,32,4,87,109,184,246,97,48,209,223,104,108,207,0,147,87,3,104,157,105,207,83,148,56,218,30,218,178,8,176,214,60,72,1],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,82,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "BIP66 example 8, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1054. -/
def scriptVectors_1054 : ScrVec :=
  { id := "sc-1054", scriptSig := bytes #[0,71,48,68,2,32,177,25,214,125,56,147,21,48,141,23,69,247,52,165,31,243,236,114,224,96,129,232,78,35,111,223,157,194,245,210,166,72,2,32,75,4,227,188,56,103,76,68,34,234,49,114,49,214,66,181,109,192,157,33,74,30,203,191,22,236,202,1,237,153,110,34,1,71,48,68,2,32,121,234,128,175,213,56,217,173,164,33,181,16,31,235,235,107,200,116,224,29,222,91,202,16,140,29,4,121,174,195,57,164,2,32,4,87,109,184,246,97,48,209,223,104,108,207,0,147,87,3,104,157,105,207,83,148,56,218,30,218,178,8,176,214,60,72,1],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,82,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "BIP66 example 8, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1055. -/
def scriptVectors_1055 : ScrVec :=
  { id := "sc-1055", scriptSig := bytes #[0,0,71,48,68,2,32,129,170,157,67,111,33,84,232,182,214,0,81,109,176,61,120,222,113,223,104,91,88,90,152,7,234,212,33,11,216,131,73,2,32,83,75,182,189,243,24,164,25,172,7,73,102,11,96,231,141,23,213,21,85,142,243,105,191,135,46,255,64,91,103,107,46,1],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,82,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "BIP66 example 9, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1056. -/
def scriptVectors_1056 : ScrVec :=
  { id := "sc-1056", scriptSig := bytes #[0,0,71,48,68,2,32,129,170,157,67,111,33,84,232,182,214,0,81,109,176,61,120,222,113,223,104,91,88,90,152,7,234,212,33,11,216,131,73,2,32,83,75,182,189,243,24,164,25,172,7,73,102,11,96,231,141,23,213,21,85,142,243,105,191,135,46,255,64,91,103,107,46,1],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,82,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "BIP66 example 9, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1057. -/
def scriptVectors_1057 : ScrVec :=
  { id := "sc-1057", scriptSig := bytes #[0,0,71,48,68,2,32,218,111,68,29,195,180,178,200,76,250,141,176,205,91,52,237,146,201,224,22,134,222,90,128,13,64,73,139,112,192,220,172,2,32,124,44,249,27,12,50,184,96,196,205,73,148,190,54,207,184,76,175,139,183,195,168,228,217,106,49,178,2,44,82,153,197,1],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,82,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 example 10, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1058. -/
def scriptVectors_1058 : ScrVec :=
  { id := "sc-1058", scriptSig := bytes #[0,0,71,48,68,2,32,218,111,68,29,195,180,178,200,76,250,141,176,205,91,52,237,146,201,224,22,134,222,90,128,13,64,73,139,112,192,220,172,2,32,124,44,249,27,12,50,184,96,196,205,73,148,190,54,207,184,76,175,139,183,195,168,228,217,106,49,178,2,44,82,153,197,1],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,82,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "BIP66 example 10, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1059. -/
def scriptVectors_1059 : ScrVec :=
  { id := "sc-1059", scriptSig := bytes #[0,71,48,68,2,32,202,224,11,20,68,186,191,191,96,113,176,186,135,7,246,189,55,61,163,223,73,77,110,116,17,155,4,48,197,219,129,5,2,32,93,82,49,184,197,147,156,143,240,200,34,66,101,109,110,6,237,176,115,212,42,243,54,201,159,232,131,124,54,234,57,213,1,0],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,82,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "BIP66 example 11, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1060. -/
def scriptVectors_1060 : ScrVec :=
  { id := "sc-1060", scriptSig := bytes #[0,71,48,68,2,32,202,224,11,20,68,186,191,191,96,113,176,186,135,7,246,189,55,61,163,223,73,77,110,116,17,155,4,48,197,219,129,5,2,32,93,82,49,184,197,147,156,143,240,200,34,66,101,109,110,6,237,176,115,212,42,243,54,201,159,232,131,124,54,234,57,213,1,0],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,82,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "BIP66 example 11, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1061. -/
def scriptVectors_1061 : ScrVec :=
  { id := "sc-1061", scriptSig := bytes #[0,71,48,68,2,32,177,25,214,125,56,147,21,48,141,23,69,247,52,165,31,243,236,114,224,96,129,232,78,35,111,223,157,194,245,210,166,72,2,32,75,4,227,188,56,103,76,68,34,234,49,114,49,214,66,181,109,192,157,33,74,30,203,191,22,236,202,1,237,153,110,34,1,0],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,82,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 example 12, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1062. -/
def scriptVectors_1062 : ScrVec :=
  { id := "sc-1062", scriptSig := bytes #[0,71,48,68,2,32,177,25,214,125,56,147,21,48,141,23,69,247,52,165,31,243,236,114,224,96,129,232,78,35,111,223,157,194,245,210,166,72,2,32,75,4,227,188,56,103,76,68,34,234,49,114,49,214,66,181,109,192,157,33,74,30,203,191,22,236,202,1,237,153,110,34,1,0],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,82,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 example 12, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1063. -/
def scriptVectors_1063 : ScrVec :=
  { id := "sc-1063", scriptSig := bytes #[72,48,68,2,32,62,69,22,218,114,83,207,6,142,255,236,107,149,196,18,33,192,207,58,142,108,203,140,191,23,37,181,98,233,175,222,44,2,32,84,225,194,88,194,152,28,223,186,93,241,244,102,97,251,101,65,196,79,119,202,0,146,243,96,3,49,171,255,251,18,81,1,1],
    scriptPubKey := bytes #[33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK with multi-byte hashtype, without DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1064. -/
def scriptVectors_1064 : ScrVec :=
  { id := "sc-1064", scriptSig := bytes #[72,48,68,2,32,62,69,22,218,114,83,207,6,142,255,236,107,149,196,18,33,192,207,58,142,108,203,140,191,23,37,181,98,233,175,222,44,2,32,84,225,194,88,194,152,28,223,186,93,241,244,102,97,251,101,65,196,79,119,202,0,146,243,96,3,49,171,255,251,18,81,1,1],
    scriptPubKey := bytes #[33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_DER",
    comment := "P2PK with multi-byte hashtype, with DERSIG" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1065. -/
def scriptVectors_1065 : ScrVec :=
  { id := "sc-1065", scriptSig := bytes #[72,48,69,2,32,62,69,22,218,114,83,207,6,142,255,236,107,149,196,18,33,192,207,58,142,108,203,140,191,23,37,181,98,233,175,222,44,2,33,0,171,30,61,167,61,103,227,32,69,162,14,11,153,158,4,153,120,234,141,110,229,72,13,72,95,207,44,224,208,59,46,240,1],
    scriptPubKey := bytes #[33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK with high S but no LOW_S" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1066. -/
def scriptVectors_1066 : ScrVec :=
  { id := "sc-1066", scriptSig := bytes #[72,48,69,2,32,62,69,22,218,114,83,207,6,142,255,236,107,149,196,18,33,192,207,58,142,108,203,140,191,23,37,181,98,233,175,222,44,2,33,0,171,30,61,167,61,103,227,32,69,162,14,11,153,158,4,153,120,234,141,110,229,72,13,72,95,207,44,224,208,59,46,240,1],
    scriptPubKey := bytes #[33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "LOW_S",
    expectOk := false, expectedError := "SIG_HIGH_S",
    comment := "P2PK with high S" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1067. -/
def scriptVectors_1067 : ScrVec :=
  { id := "sc-1067", scriptSig := bytes #[71,48,68,2,32,87,41,46,45,77,254,119,91,236,221,10,158,101,71,153,124,114,140,223,53,57,15,106,1,125,165,109,101,77,55,78,73,2,32,107,100,59,226,252,83,118,59,78,40,72,69,191,234,44,89,125,45,199,117,153,65,220,233,55,99,108,157,52,27,113,237,1],
    scriptPubKey := bytes #[65,6,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK with hybrid pubkey but no STRICTENC" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1068. -/
def scriptVectors_1068 : ScrVec :=
  { id := "sc-1068", scriptSig := bytes #[71,48,68,2,32,87,41,46,45,77,254,119,91,236,221,10,158,101,71,153,124,114,140,223,53,57,15,106,1,125,165,109,101,77,55,78,73,2,32,107,100,59,226,252,83,118,59,78,40,72,69,191,234,44,89,125,45,199,117,153,65,220,233,55,99,108,157,52,27,113,237,1],
    scriptPubKey := bytes #[65,6,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "PUBKEYTYPE",
    comment := "P2PK with hybrid pubkey" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1069. -/
def scriptVectors_1069 : ScrVec :=
  { id := "sc-1069", scriptSig := bytes #[0],
    scriptPubKey := bytes #[33,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "PUBKEYTYPE",
    comment := "P2PK with invalid length for uncompressed key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1070. -/
def scriptVectors_1070 : ScrVec :=
  { id := "sc-1070", scriptSig := bytes #[0],
    scriptPubKey := bytes #[65,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "PUBKEYTYPE",
    comment := "P2PK with invalid length for compressed key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1071. -/
def scriptVectors_1071 : ScrVec :=
  { id := "sc-1071", scriptSig := bytes #[71,48,68,2,32,3,93,85,78,49,83,193,73,80,201,153,63,65,196,150,96,122,142,36,9,61,176,89,91,231,191,135,92,246,79,207,31,2,32,71,49,200,196,229,218,241,94,112,108,236,25,205,216,242,197,177,208,84,144,225,29,171,132,101,237,66,101,105,182,233,33,1],
    scriptPubKey := bytes #[65,6,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "P2PK NOT with hybrid pubkey but no STRICTENC" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1072. -/
def scriptVectors_1072 : ScrVec :=
  { id := "sc-1072", scriptSig := bytes #[71,48,68,2,32,3,93,85,78,49,83,193,73,80,201,153,63,65,196,150,96,122,142,36,9,61,176,89,91,231,191,135,92,246,79,207,31,2,32,71,49,200,196,229,218,241,94,112,108,236,25,205,216,242,197,177,208,84,144,225,29,171,132,101,237,66,101,105,182,233,33,1],
    scriptPubKey := bytes #[65,6,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "PUBKEYTYPE",
    comment := "P2PK NOT with hybrid pubkey" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1073. -/
def scriptVectors_1073 : ScrVec :=
  { id := "sc-1073", scriptSig := bytes #[71,48,68,2,32,3,93,85,78,49,83,192,73,80,201,153,63,65,196,150,96,122,142,36,9,61,176,89,91,231,191,135,92,246,79,207,31,2,32,71,49,200,196,229,218,241,94,112,108,236,25,205,216,242,197,177,208,84,144,225,29,171,132,101,237,66,101,105,182,233,33,1],
    scriptPubKey := bytes #[65,6,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK NOT with invalid hybrid pubkey but no STRICTENC" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1074. -/
def scriptVectors_1074 : ScrVec :=
  { id := "sc-1074", scriptSig := bytes #[71,48,68,2,32,3,93,85,78,49,83,192,73,80,201,153,63,65,196,150,96,122,142,36,9,61,176,89,91,231,191,135,92,246,79,207,31,2,32,71,49,200,196,229,218,241,94,112,108,236,25,205,216,242,197,177,208,84,144,225,29,171,132,101,237,66,101,105,182,233,33,1],
    scriptPubKey := bytes #[65,6,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "PUBKEYTYPE",
    comment := "P2PK NOT with invalid hybrid pubkey" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1075. -/
def scriptVectors_1075 : ScrVec :=
  { id := "sc-1075", scriptSig := bytes #[0,71,48,68,2,32,46,121,68,26,209,186,245,160,127,184,107,174,55,83,24,79,103,23,217,105,38,128,148,126,168,182,232,183,119,198,154,241,2,32,121,162,98,225,61,134,139,181,160,150,79,239,227,186,38,148,46,27,6,105,175,26,251,85,239,51,68,188,157,79,196,196,1],
    scriptPubKey := bytes #[81,65,6,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,82,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "1-of-2 with the second 1 hybrid pubkey and no STRICTENC" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1076. -/
def scriptVectors_1076 : ScrVec :=
  { id := "sc-1076", scriptSig := bytes #[0,71,48,68,2,32,46,121,68,26,209,186,245,160,127,184,107,174,55,83,24,79,103,23,217,105,38,128,148,126,168,182,232,183,119,198,154,241,2,32,121,162,98,225,61,134,139,181,160,150,79,239,227,186,38,148,46,27,6,105,175,26,251,85,239,51,68,188,157,79,196,196,1],
    scriptPubKey := bytes #[81,65,6,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,82,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := true, expectedError := "OK",
    comment := "1-of-2 with the second 1 hybrid pubkey" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1077. -/
def scriptVectors_1077 : ScrVec :=
  { id := "sc-1077", scriptSig := bytes #[0,71,48,68,2,32,121,199,130,77,108,134,142,14,26,39,52,132,226,140,38,84,162,125,4,60,138,39,244,159,82,203,114,239,237,7,89,9,2,32,69,43,187,247,8,149,116,250,8,32,149,164,252,27,58,22,186,252,249,122,58,52,215,69,250,252,146,44,206,102,178,114,1],
    scriptPubKey := bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,65,6,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,82,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "PUBKEYTYPE",
    comment := "1-of-2 with the first 1 hybrid pubkey" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1078. -/
def scriptVectors_1078 : ScrVec :=
  { id := "sc-1078", scriptSig := bytes #[71,48,68,2,32,97,119,213,19,236,44,218,68,76,2,26,31,79,101,111,196,199,43,161,8,174,6,62,21,126,184,109,195,87,87,132,148,2,32,102,111,198,103,2,129,93,14,84,19,187,155,29,242,42,237,68,245,241,239,184,185,157,65,221,93,201,165,190,109,32,82,5],
    scriptPubKey := bytes #[65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK with undefined hashtype but no STRICTENC" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1079. -/
def scriptVectors_1079 : ScrVec :=
  { id := "sc-1079", scriptSig := bytes #[71,48,68,2,32,97,119,213,19,236,44,218,68,76,2,26,31,79,101,111,196,199,43,161,8,174,6,62,21,126,184,109,195,87,87,132,148,2,32,102,111,198,103,2,129,93,14,84,19,187,155,29,242,42,237,68,245,241,239,184,185,157,65,221,93,201,165,190,109,32,82,5],
    scriptPubKey := bytes #[65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SIG_HASHTYPE",
    comment := "P2PK with undefined hashtype" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1080. -/
def scriptVectors_1080 : ScrVec :=
  { id := "sc-1080", scriptSig := bytes #[71,48,68,2,32,116,9,181,179,32,41,110,94,33,54,167,178,129,167,248,3,2,140,164,202,68,226,184,62,235,212,105,50,103,119,37,222,2,32,45,78,234,28,141,60,152,230,244,38,20,245,71,100,230,229,230,84,46,33,62,180,208,121,115,126,154,139,110,152,18,236,5],
    scriptPubKey := bytes #[65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK NOT with invalid sig and undefined hashtype but no STRICTENC" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1081. -/
def scriptVectors_1081 : ScrVec :=
  { id := "sc-1081", scriptSig := bytes #[71,48,68,2,32,116,9,181,179,32,41,110,94,33,54,167,178,129,167,248,3,2,140,164,202,68,226,184,62,235,212,105,50,103,119,37,222,2,32,45,78,234,28,141,60,152,230,244,38,20,245,71,100,230,229,230,84,46,33,62,180,208,121,115,126,154,139,110,152,18,236,5],
    scriptPubKey := bytes #[65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "SIG_HASHTYPE",
    comment := "P2PK NOT with invalid sig and undefined hashtype" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1082. -/
def scriptVectors_1082 : ScrVec :=
  { id := "sc-1082", scriptSig := bytes #[81,71,48,68,2,32,81,37,75,159,180,118,165,45,133,83,7,146,181,120,248,111,234,112,236,31,251,67,147,230,97,188,204,178,61,141,99,211,2,32,118,80,95,148,164,3,200,96,151,132,25,68,224,68,199,12,32,69,206,144,227,109,229,31,126,157,56,40,219,152,160,117,1,71,48,68,2,32,10,53,143,117,9,52,179,254,184,34,241,150,107,252,216,187,236,158,234,163,168,202,148,30,17,238,89,96,225,129,250,1,2,32,80,191,107,90,142,119,80,247,3,84,174,4,28,182,138,123,173,230,126,198,195,171,25,235,53,150,56,151,68,16,98,110,1,71,48,68,2,32,9,85,208,49,255,247,29,134,83,34,30,133,227,108,60,133,83,61,35,18,252,48,69,49,75,25,101,11,122,226,248,16,2,32,42,107,184,80,94,54,32,25,9,208,146,31,1,171,255,57,10,230,183,255,151,187,249,89,249,138,237,235,10,86,115,9,1],
    scriptPubKey := bytes #[83,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,83,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "3-of-3 with nonzero dummy but no NULLDUMMY" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1083. -/
def scriptVectors_1083 : ScrVec :=
  { id := "sc-1083", scriptSig := bytes #[81,71,48,68,2,32,81,37,75,159,180,118,165,45,133,83,7,146,181,120,248,111,234,112,236,31,251,67,147,230,97,188,204,178,61,141,99,211,2,32,118,80,95,148,164,3,200,96,151,132,25,68,224,68,199,12,32,69,206,144,227,109,229,31,126,157,56,40,219,152,160,117,1,71,48,68,2,32,10,53,143,117,9,52,179,254,184,34,241,150,107,252,216,187,236,158,234,163,168,202,148,30,17,238,89,96,225,129,250,1,2,32,80,191,107,90,142,119,80,247,3,84,174,4,28,182,138,123,173,230,126,198,195,171,25,235,53,150,56,151,68,16,98,110,1,71,48,68,2,32,9,85,208,49,255,247,29,134,83,34,30,133,227,108,60,133,83,61,35,18,252,48,69,49,75,25,101,11,122,226,248,16,2,32,42,107,184,80,94,54,32,25,9,208,146,31,1,171,255,57,10,230,183,255,151,187,249,89,249,138,237,235,10,86,115,9,1],
    scriptPubKey := bytes #[83,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,83,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := true, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_NULLDUMMY",
    comment := "3-of-3 with nonzero dummy" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1084. -/
def scriptVectors_1084 : ScrVec :=
  { id := "sc-1084", scriptSig := bytes #[81,71,48,68,2,32,27,178,237,171,112,10,93,2,2,54,223,23,79,239,237,120,8,118,151,20,55,49,246,89,190,165,150,66,199,89,193,109,2,32,97,244,44,219,174,91,205,62,135,144,242,11,247,102,135,68,52,54,233,74,99,67,33,193,106,114,170,84,203,199,194,234,1,71,48,68,2,32,75,180,166,79,42,110,92,127,178,240,127,239,133,238,86,253,229,230,218,35,76,106,152,66,98,48,122,32,233,152,66,215,2,32,111,131,3,170,186,94,98,93,34,56,151,226,255,211,248,142,241,188,255,239,85,243,141,195,118,142,95,46,148,201,35,249,1,71,48,68,2,32,64,194,128,155,113,255,251,21,94,200,184,47,231,162,127,102,107,217,127,148,18,7,190,78,20,173,232,90,18,73,221,77,2,32,77,86,200,94,197,37,221,24,226,154,5,51,213,221,246,27,107,27,179,41,128,194,246,62,223,149,26,235,247,162,123,254,1],
    scriptPubKey := bytes #[83,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,83,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "3-of-3 NOT with invalid sig and nonzero dummy but no NULLDUMMY" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1085. -/
def scriptVectors_1085 : ScrVec :=
  { id := "sc-1085", scriptSig := bytes #[81,71,48,68,2,32,27,178,237,171,112,10,93,2,2,54,223,23,79,239,237,120,8,118,151,20,55,49,246,89,190,165,150,66,199,89,193,109,2,32,97,244,44,219,174,91,205,62,135,144,242,11,247,102,135,68,52,54,233,74,99,67,33,193,106,114,170,84,203,199,194,234,1,71,48,68,2,32,75,180,166,79,42,110,92,127,178,240,127,239,133,238,86,253,229,230,218,35,76,106,152,66,98,48,122,32,233,152,66,215,2,32,111,131,3,170,186,94,98,93,34,56,151,226,255,211,248,142,241,188,255,239,85,243,141,195,118,142,95,46,148,201,35,249,1,71,48,68,2,32,64,194,128,155,113,255,251,21,94,200,184,47,231,162,127,102,107,217,127,148,18,7,190,78,20,173,232,90,18,73,221,77,2,32,77,86,200,94,197,37,221,24,226,154,5,51,213,221,246,27,107,27,179,41,128,194,246,62,223,149,26,235,247,162,123,254,1],
    scriptPubKey := bytes #[83,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,83,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := true, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_NULLDUMMY",
    comment := "3-of-3 NOT with invalid sig with nonzero dummy" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1086. -/
def scriptVectors_1086 : ScrVec :=
  { id := "sc-1086", scriptSig := bytes #[0,71,48,68,2,32,10,190,180,189,7,248,66,34,244,116,174,213,88,207,189,252,11,78,150,205,227,194,147,91,167,9,139,31,240,189,116,195,2,32,74,4,193,202,103,178,162,10,190,226,16,207,154,33,2,62,220,203,191,128,36,185,136,129,38,52,35,49,21,198,183,57,1,118],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,82,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "2-of-2 with two identical keys and sigs pushed using OP_DUP but no SIGPUSHONLY" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1087. -/
def scriptVectors_1087 : ScrVec :=
  { id := "sc-1087", scriptSig := bytes #[0,71,48,68,2,32,10,190,180,189,7,248,66,34,244,116,174,213,88,207,189,252,11,78,150,205,227,194,147,91,167,9,139,31,240,189,116,195,2,32,74,4,193,202,103,178,162,10,190,226,16,207,154,33,2,62,220,203,191,128,36,185,136,129,38,52,35,49,21,198,183,57,1,118],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,82,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "SIGPUSHONLY",
    expectOk := false, expectedError := "SIG_PUSHONLY",
    comment := "2-of-2 with two identical keys and sigs pushed using OP_DUP" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1088. -/
def scriptVectors_1088 : ScrVec :=
  { id := "sc-1088", scriptSig := bytes #[71,48,68,2,32,24,162,168,26,147,173,213,203,95,93,167,99,5,113,142,78,166,96,69,236,72,136,178,141,132,203,34,250,231,244,100,91,2,32,30,109,170,94,213,210,228,178,178,2,124,247,255,212,61,141,152,68,221,73,247,78,248,104,153,236,142,102,157,253,57,170,1,183,35,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,172],
    scriptPubKey := bytes #[169,20,33,86,64,194,247,47,13,22,180,236,237,38,118,32,53,164,47,254,211,154,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2SH(P2PK) with non-push scriptSig but no P2SH or SIGPUSHONLY" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1089. -/
def scriptVectors_1089 : ScrVec :=
  { id := "sc-1089", scriptSig := bytes #[71,48,68,2,32,62,69,22,218,114,83,207,6,142,255,236,107,149,196,18,33,192,207,58,142,108,203,140,191,23,37,181,98,233,175,222,44,2,32,84,225,194,88,194,152,28,223,186,93,241,244,102,97,251,101,65,196,79,119,202,0,146,243,96,3,49,171,255,251,18,81,1,183],
    scriptPubKey := bytes #[33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,172],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK with non-push scriptSig but with P2SH validation" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1090. -/
def scriptVectors_1090 : ScrVec :=
  { id := "sc-1090", scriptSig := bytes #[71,48,68,2,32,24,162,168,26,147,173,213,203,95,93,167,99,5,113,142,78,166,96,69,236,72,136,178,141,132,203,34,250,231,244,100,91,2,32,30,109,170,94,213,210,228,178,178,2,124,247,255,212,61,141,152,68,221,73,247,78,248,104,153,236,142,102,157,253,57,170,1,183,35,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,172],
    scriptPubKey := bytes #[169,20,33,86,64,194,247,47,13,22,180,236,237,38,118,32,53,164,47,254,211,154,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "SIG_PUSHONLY",
    comment := "P2SH(P2PK) with non-push scriptSig but no SIGPUSHONLY" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1091. -/
def scriptVectors_1091 : ScrVec :=
  { id := "sc-1091", scriptSig := bytes #[71,48,68,2,32,24,162,168,26,147,173,213,203,95,93,167,99,5,113,142,78,166,96,69,236,72,136,178,141,132,203,34,250,231,244,100,91,2,32,30,109,170,94,213,210,228,178,178,2,124,247,255,212,61,141,152,68,221,73,247,78,248,104,153,236,142,102,157,253,57,170,1,183,35,33,3,54,61,144,212,71,176,12,156,153,206,172,5,182,38,46,224,83,68,28,126,85,85,47,254,82,107,173,143,131,255,70,64,172],
    scriptPubKey := bytes #[169,20,33,86,64,194,247,47,13,22,180,236,237,38,118,32,53,164,47,254,211,154,135],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "SIGPUSHONLY",
    expectOk := false, expectedError := "SIG_PUSHONLY",
    comment := "P2SH(P2PK) with non-push scriptSig but not P2SH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1092. -/
def scriptVectors_1092 : ScrVec :=
  { id := "sc-1092", scriptSig := bytes #[0,71,48,68,2,32,10,190,180,189,7,248,66,34,244,116,174,213,88,207,189,252,11,78,150,205,227,194,147,91,167,9,139,31,240,189,116,195,2,32,74,4,193,202,103,178,162,10,190,226,16,207,154,33,2,62,220,203,191,128,36,185,136,129,38,52,35,49,21,198,183,57,1,71,48,68,2,32,10,190,180,189,7,248,66,34,244,116,174,213,88,207,189,252,11,78,150,205,227,194,147,91,167,9,139,31,240,189,116,195,2,32,74,4,193,202,103,178,162,10,190,226,16,207,154,33,2,62,220,203,191,128,36,185,136,129,38,52,35,49,21,198,183,57,1],
    scriptPubKey := bytes #[82,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,82,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "SIGPUSHONLY",
    expectOk := true, expectedError := "OK",
    comment := "2-of-2 with two identical keys and sigs pushed" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1093. -/
def scriptVectors_1093 : ScrVec :=
  { id := "sc-1093", scriptSig := bytes #[91,71,48,68,2,32,10,92,97,99,240,123,141,59,1,60,77,29,109,186,37,231,128,179,150,88,215,155,163,122,247,5,122,59,127,21,255,161,2,32,31,217,180,234,169,148,63,115,73,40,185,154,131,89,44,46,123,243,66,234,38,128,246,162,187,112,81,103,150,107,116,32,1],
    scriptPubKey := bytes #[65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2PK with unnecessary input but no CLEANSTACK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1094. -/
def scriptVectors_1094 : ScrVec :=
  { id := "sc-1094", scriptSig := bytes #[91,71,48,68,2,32,10,92,97,99,240,123,141,59,1,60,77,29,109,186,37,231,128,179,150,88,215,155,163,122,247,5,122,59,127,21,255,161,2,32,31,217,180,234,169,148,63,115,73,40,185,154,131,89,44,46,123,243,66,234,38,128,246,162,187,112,81,103,150,107,116,32,1],
    scriptPubKey := bytes #[65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "CLEANSTACK",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := "P2PK with unnecessary input" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1095. -/
def scriptVectors_1095 : ScrVec :=
  { id := "sc-1095", scriptSig := bytes #[91,71,48,68,2,32,47,117,5,19,43,225,72,114,88,31,53,215,75,117,146,18,217,218,64,72,38,83,241,255,163,17,108,50,148,164,165,23,2,32,106,219,243,71,162,36,12,164,28,102,82,43,26,34,164,22,147,97,11,118,168,231,119,6,69,220,114,29,22,53,133,79,1,67,65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172],
    scriptPubKey := bytes #[169,20,49,237,194,59,218,253,164,99,158,102,159,137,173,107,35,24,221,121,208,50,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2SH with unnecessary input but no CLEANSTACK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1096. -/
def scriptVectors_1096 : ScrVec :=
  { id := "sc-1096", scriptSig := bytes #[91,71,48,68,2,32,47,117,5,19,43,225,72,114,88,31,53,215,75,117,146,18,217,218,64,72,38,83,241,255,163,17,108,50,148,164,165,23,2,32,106,219,243,71,162,36,12,164,28,102,82,43,26,34,164,22,147,97,11,118,168,231,119,6,69,220,114,29,22,53,133,79,1,67,65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172],
    scriptPubKey := bytes #[169,20,49,237,194,59,218,253,164,99,158,102,159,137,173,107,35,24,221,121,208,50,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "CLEANSTACK",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := "P2SH with unnecessary input" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1097. -/
def scriptVectors_1097 : ScrVec :=
  { id := "sc-1097", scriptSig := bytes #[71,48,68,2,32,47,117,5,19,43,225,72,114,88,31,53,215,75,117,146,18,217,218,64,72,38,83,241,255,163,17,108,50,148,164,165,23,2,32,106,219,243,71,162,36,12,164,28,102,82,43,26,34,164,22,147,97,11,118,168,231,119,6,69,220,114,29,22,53,133,79,1,67,65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172],
    scriptPubKey := bytes #[169,20,49,237,194,59,218,253,164,99,158,102,159,137,173,107,35,24,221,121,208,50,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "CLEANSTACK",
    expectOk := true, expectedError := "OK",
    comment := "P2SH with CLEANSTACK" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1098. -/
def scriptVectors_1098 : ScrVec :=
  { id := "sc-1098", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,185,82,55,180,143,170,166,158,176,120,225,23,11,227,181,203,179,253,223,22,208,169,145,225,74,210,116,247,179,58,79,100],
    witness := [bytes #[48,68,2,32,13,70,28,20,12,253,252,243,107,148,150,29,181,122,232,193,141,28,184,14,157,149,169,228,122,194,36,112,193,191,18,85,2,32,28,141,193,203,254,246,163,239,144,172,187,185,146,202,34,254,148,102,238,111,157,72,152,237,162,119,167,172,58,180,178,81,1], bytes #[65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Basic P2WSH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1099. -/
def scriptVectors_1099 : ScrVec :=
  { id := "sc-1099", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,20,145,178,75,249,245,40,133,50,150,10,198,135,171,176,53,18,123,29,40,165],
    witness := [bytes #[48,68,2,32,30,114,22,229,204,179,182,29,70,148,110,198,204,126,140,78,1,23,209,58,194,253,75,21,33,151,228,128,81,145,199,66,2,32,62,153,3,227,62,132,217,238,29,209,63,176,87,175,183,204,251,71,0,108,35,246,160,103,24,94,251,201,221,120,15,197,1], bytes #[4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Basic P2WPKH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1100. -/
def scriptVectors_1100 : ScrVec :=
  { id := "sc-1100", scriptSig := bytes #[34,0,32,185,82,55,180,143,170,166,158,176,120,225,23,11,227,181,203,179,253,223,22,208,169,145,225,74,210,116,247,179,58,79,100],
    scriptPubKey := bytes #[169,20,243,134,194,186,37,92,197,109,32,207,166,234,139,6,47,139,89,148,85,24,135],
    witness := [bytes #[48,68,2,32,102,224,44,25,165,19,4,157,73,52,156,245,49,26,27,1,43,124,79,174,2,55,149,161,138,177,217,28,35,73,108,34,2,32,37,226,22,52,44,142,7,206,142,245,30,141,174,232,143,132,48,106,157,230,98,54,202,178,48,187,99,6,125,237,26,211,1], bytes #[65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Basic P2SH(P2WSH)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1101. -/
def scriptVectors_1101 : ScrVec :=
  { id := "sc-1101", scriptSig := bytes #[22,0,20,145,178,75,249,245,40,133,50,150,10,198,135,171,176,53,18,123,29,40,165],
    scriptPubKey := bytes #[169,20,23,116,59,235,66,156,85,201,66,210,236,112,59,152,196,213,124,45,245,198,135],
    witness := [bytes #[48,68,2,32,9,41,209,21,97,205,149,132,96,55,18,0,248,46,156,174,100,199,39,164,149,113,90,49,130,142,39,167,173,87,179,109,2,32,54,23,50,206,208,74,111,151,53,30,204,162,26,86,208,184,205,73,50,193,218,31,143,86,154,43,104,229,228,138,237,120,1], bytes #[4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Basic P2SH(P2WPKH)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1102. -/
def scriptVectors_1102 : ScrVec :=
  { id := "sc-1102", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,172,142,189,158,82,193,118,25,163,129,250,79,113,174,187,105,96,135,198,239,23,201,96,253,5,135,173,218,217,156,6,16],
    witness := [bytes #[48,68,2,32,37,137,240,81,44,178,64,143,176,142,217,189,36,248,94,179,5,151,68,217,228,242,38,45,11,127,19,56,207,246,232,185,2,32,108,9,120,244,73,105,62,5,120,199,27,197,67,177,16,121,253,11,170,231,0,238,94,154,107,238,148,219,73,10,249,252,1], bytes #[65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,172]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "Basic P2WSH with the wrong key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1103. -/
def scriptVectors_1103 : ScrVec :=
  { id := "sc-1103", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,20,124,249,200,70,205,72,130,239,236,75,240,126,68,235,218,212,149,201,79,75],
    witness := [bytes #[48,68,2,32,110,247,253,178,152,99,37,211,124,110,177,168,187,36,174,180,109,237,225,18,237,143,199,108,125,117,0,185,184,60,13,61,2,32,30,220,35,34,199,148,254,45,107,11,215,62,211,25,231,20,170,155,134,216,137,25,97,83,13,92,155,113,86,182,13,78,1], bytes #[4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "Basic P2WPKH with the wrong key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1104. -/
def scriptVectors_1104 : ScrVec :=
  { id := "sc-1104", scriptSig := bytes #[34,0,32,172,142,189,158,82,193,118,25,163,129,250,79,113,174,187,105,96,135,198,239,23,201,96,253,5,135,173,218,217,156,6,16],
    scriptPubKey := bytes #[169,20,97,3,154,0,56,131,120,124,13,110,188,102,217,127,218,190,142,49,68,157,135],
    witness := [bytes #[48,68,2,32,6,158,163,88,26,250,248,24,127,99,254,238,31,210,189,31,156,13,199,30,167,214,232,168,176,126,226,235,207,130,75,244,2,32,26,79,222,244,197,50,234,229,146,35,190,30,218,106,57,127,200,53,20,45,77,220,108,116,244,170,133,183,102,165,193,111,1], bytes #[65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,172]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "Basic P2SH(P2WSH) with the wrong key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1105. -/
def scriptVectors_1105 : ScrVec :=
  { id := "sc-1105", scriptSig := bytes #[22,0,20,124,249,200,70,205,72,130,239,236,75,240,126,68,235,218,212,149,201,79,75],
    scriptPubKey := bytes #[169,20,78,12,42,237,145,49,83,3,252,106,29,196,199,188,33,200,143,117,64,46,135],
    witness := [bytes #[48,68,2,32,66,9,228,148,87,194,53,143,128,208,37,107,194,69,53,184,117,76,20,208,136,64,252,75,231,98,214,245,160,174,216,11,2,32,46,175,125,143,200,214,47,96,198,122,220,217,146,149,82,141,14,73,26,233,60,25,92,236,90,103,231,160,149,50,168,128,1], bytes #[4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "Basic P2SH(P2WPKH) with the wrong key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1106. -/
def scriptVectors_1106 : ScrVec :=
  { id := "sc-1106", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,172,142,189,158,82,193,118,25,163,129,250,79,113,174,187,105,96,135,198,239,23,201,96,253,5,135,173,218,217,156,6,16],
    witness := [bytes #[48,68,2,32,37,137,240,81,44,178,64,143,176,142,217,189,36,248,94,179,5,151,68,217,228,242,38,45,11,127,19,56,207,246,232,185,2,32,108,9,120,244,73,105,62,5,120,199,27,197,67,177,16,121,253,11,170,231,0,238,94,154,107,238,148,219,73,10,249,252,1], bytes #[65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,172]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Basic P2WSH with the wrong key but no WITNESS" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1107. -/
def scriptVectors_1107 : ScrVec :=
  { id := "sc-1107", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,20,124,249,200,70,205,72,130,239,236,75,240,126,68,235,218,212,149,201,79,75],
    witness := [bytes #[48,68,2,32,110,247,253,178,152,99,37,211,124,110,177,168,187,36,174,180,109,237,225,18,237,143,199,108,125,117,0,185,184,60,13,61,2,32,30,220,35,34,199,148,254,45,107,11,215,62,211,25,231,20,170,155,134,216,137,25,97,83,13,92,155,113,86,182,13,78,1], bytes #[4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Basic P2WPKH with the wrong key but no WITNESS" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1108. -/
def scriptVectors_1108 : ScrVec :=
  { id := "sc-1108", scriptSig := bytes #[34,0,32,172,142,189,158,82,193,118,25,163,129,250,79,113,174,187,105,96,135,198,239,23,201,96,253,5,135,173,218,217,156,6,16],
    scriptPubKey := bytes #[169,20,97,3,154,0,56,131,120,124,13,110,188,102,217,127,218,190,142,49,68,157,135],
    witness := [bytes #[48,68,2,32,6,158,163,88,26,250,248,24,127,99,254,238,31,210,189,31,156,13,199,30,167,214,232,168,176,126,226,235,207,130,75,244,2,32,26,79,222,244,197,50,234,229,146,35,190,30,218,106,57,127,200,53,20,45,77,220,108,116,244,170,133,183,102,165,193,111,1], bytes #[65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,172]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Basic P2SH(P2WSH) with the wrong key but no WITNESS" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1109. -/
def scriptVectors_1109 : ScrVec :=
  { id := "sc-1109", scriptSig := bytes #[22,0,20,124,249,200,70,205,72,130,239,236,75,240,126,68,235,218,212,149,201,79,75],
    scriptPubKey := bytes #[169,20,78,12,42,237,145,49,83,3,252,106,29,196,199,188,33,200,143,117,64,46,135],
    witness := [bytes #[48,68,2,32,66,9,228,148,87,194,53,143,128,208,37,107,194,69,53,184,117,76,20,208,136,64,252,75,231,98,214,245,160,174,216,11,2,32,46,175,125,143,200,214,47,96,198,122,220,217,146,149,82,141,14,73,26,233,60,25,92,236,90,103,231,160,149,50,168,128,1], bytes #[4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Basic P2SH(P2WPKH) with the wrong key but no WITNESS" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1110. -/
def scriptVectors_1110 : ScrVec :=
  { id := "sc-1110", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,185,82,55,180,143,170,166,158,176,120,225,23,11,227,181,203,179,253,223,22,208,169,145,225,74,210,116,247,179,58,79,100],
    witness := [bytes #[48,68,2,32,102,250,168,110,116,232,179,14,130,105,27,152,91,55,61,228,249,226,109,193,68,236,57,156,79,6,106,165,147,8,231,194,2,32,71,18,184,111,40,195,37,3,250,160,81,219,234,191,242,194,56,236,232,97,171,195,108,94,11,64,177,19,156,162,34,240,1], bytes #[65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "Basic P2WSH with wrong value" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1111. -/
def scriptVectors_1111 : ScrVec :=
  { id := "sc-1111", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,20,145,178,75,249,245,40,133,50,150,10,198,135,171,176,53,18,123,29,40,165],
    witness := [bytes #[48,68,2,32,59,51,137,184,116,72,215,223,219,94,130,251,133,79,207,146,215,146,95,153,56,234,84,68,227,106,190,240,44,61,106,150,2,32,36,16,188,50,101,4,154,187,7,253,46,37,44,101,171,112,52,217,92,157,90,204,202,190,159,173,189,198,58,82,113,38,1], bytes #[4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "Basic P2WPKH with wrong value" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1112. -/
def scriptVectors_1112 : ScrVec :=
  { id := "sc-1112", scriptSig := bytes #[34,0,32,185,82,55,180,143,170,166,158,176,120,225,23,11,227,181,203,179,253,223,22,208,169,145,225,74,210,116,247,179,58,79,100],
    scriptPubKey := bytes #[169,20,243,134,194,186,37,92,197,109,32,207,166,234,139,6,47,139,89,148,85,24,135],
    witness := [bytes #[48,68,2,32,0,163,12,76,252,16,228,56,123,229,40,97,53,117,67,72,38,173,60,21,88,116,117,224,223,140,227,177,116,106,162,16,2,32,8,20,146,101,228,248,233,218,254,31,62,165,13,144,203,66,94,158,64,234,126,189,211,131,6,154,124,250,43,119,0,71,1], bytes #[65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "Basic P2SH(P2WSH) with wrong value" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1113. -/
def scriptVectors_1113 : ScrVec :=
  { id := "sc-1113", scriptSig := bytes #[22,0,20,145,178,75,249,245,40,133,50,150,10,198,135,171,176,53,18,123,29,40,165],
    scriptPubKey := bytes #[169,20,23,116,59,235,66,156,85,201,66,210,236,112,59,152,196,213,124,45,245,198,135],
    witness := [bytes #[48,68,2,32,79,195,162,205,97,164,121,19,242,165,249,16,125,10,212,165,4,199,179,30,226,214,179,178,243,140,43,16,238,3,30,148,2,32,5,93,88,183,195,194,129,170,163,129,216,244,134,172,15,62,54,25,57,172,253,86,128,70,203,106,49,28,223,169,116,207,1], bytes #[4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "Basic P2SH(P2WPKH) with wrong value" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1114. -/
def scriptVectors_1114 : ScrVec :=
  { id := "sc-1114", scriptSig := bytes #[],
    scriptPubKey := bytes #[81,20,145,178,75,249,245,40,133,50,150,10,198,135,171,176,53,18,123,29,40,165],
    witness := [bytes #[48,68,2,32,90,229,122,224,83,76,5,202,153,129,200,166,205,243,83,181,5,234,172,183,55,95,150,104,26,45,26,75,166,240,47,132,2,32,86,36,142,104,100,59,125,140,231,199,209,40,201,241,243,72,188,171,139,225,93,9,74,213,202,221,36,37,26,40,223,128,1], bytes #[4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM",
    expectOk := false, expectedError := "DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM",
    comment := "P2WPKH with future witness version" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1115. -/
def scriptVectors_1115 : ScrVec :=
  { id := "sc-1115", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,31,179,75,120,218,22,39,81,100,121,116,213,203,116,16,170,66,138,211,57,219,247,209,225,110,131,63,104,160,203,241,195],
    witness := [bytes #[48,68,2,32,100,16,12,160,226,163,51,50,19,103,117,168,108,216,61,2,48,229,139,154,235,184,137,197,172,149,42,191,247,154,70,239,2,32,95,27,249,0,224,34,3,154,211,9,27,218,242,122,194,174,243,234,233,237,159,25,13,130,29,62,80,132,5,185,81,49,1], bytes #[4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_PROGRAM_WRONG_LENGTH",
    comment := "P2WPKH with wrong witness program length" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1116. -/
def scriptVectors_1116 : ScrVec :=
  { id := "sc-1116", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,185,82,55,180,143,170,166,158,176,120,225,23,11,227,181,203,179,253,223,22,208,169,145,225,74,210,116,247,179,58,79,100],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_PROGRAM_WITNESS_EMPTY",
    comment := "P2WSH with empty witness" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1117. -/
def scriptVectors_1117 : ScrVec :=
  { id := "sc-1117", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,185,82,55,180,143,170,166,158,176,120,225,23,11,227,181,203,179,253,223,22,208,169,145,225,74,210,116,247,179,58,79,100],
    witness := [bytes #[48,68,2,32,57,16,91,153,90,95,68,134,57,169,151,165,201,15,218,6,245,11,73,223,48,195,189,182,102,50,23,191,121,50,61,176,2,32,111,236,213,66,105,222,197,105,252,197,23,23,136,128,235,88,187,64,243,129,162,130,187,117,118,111,243,99,125,95,75,67,1], bytes #[64,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_PROGRAM_MISMATCH",
    comment := "P2WSH with witness program mismatch" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1118. -/
def scriptVectors_1118 : ScrVec :=
  { id := "sc-1118", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,20,145,178,75,249,245,40,133,50,150,10,198,135,171,176,53,18,123,29,40,165],
    witness := [bytes #[48,68,2,32,26,150,149,5,147,203,10,243,45,8,11,15,25,53,23,244,85,146,65,168,235,209,233,94,65,69,51,173,100,163,244,35,2,32,71,244,246,211,9,92,35,35,91,223,243,174,255,72,13,5,41,192,39,163,240,147,203,38,91,124,191,20,133,83,184,81,1], bytes #[4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184], bytes #[]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_PROGRAM_MISMATCH",
    comment := "P2WPKH with witness program mismatch" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1119. -/
def scriptVectors_1119 : ScrVec :=
  { id := "sc-1119", scriptSig := bytes #[91],
    scriptPubKey := bytes #[0,20,145,178,75,249,245,40,133,50,150,10,198,135,171,176,53,18,123,29,40,165],
    witness := [bytes #[48,68,2,32,26,150,149,5,147,203,10,243,45,8,11,15,25,53,23,244,85,146,65,168,235,209,233,94,65,69,51,173,100,163,244,35,2,32,71,244,246,211,9,92,35,35,91,223,243,174,255,72,13,5,41,192,39,163,240,147,203,38,91,124,191,20,133,83,184,81,1], bytes #[4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_MALLEATED",
    comment := "P2WPKH with non-empty scriptSig" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1120. -/
def scriptVectors_1120 : ScrVec :=
  { id := "sc-1120", scriptSig := bytes #[91,22,0,20,124,249,200,70,205,72,130,239,236,75,240,126,68,235,218,212,149,201,79,75],
    scriptPubKey := bytes #[169,20,78,12,42,237,145,49,83,3,252,106,29,196,199,188,33,200,143,117,64,46,135],
    witness := [bytes #[48,68,2,32,66,9,228,148,87,194,53,143,128,208,37,107,194,69,53,184,117,76,20,208,136,64,252,75,231,98,214,245,160,174,216,11,2,32,46,175,125,143,200,214,47,96,198,122,220,217,146,149,82,141,14,73,26,233,60,25,92,236,90,103,231,160,149,50,168,128,1], bytes #[4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_MALLEATED_P2SH",
    comment := "P2SH(P2WPKH) with superfluous push in scriptSig" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1121. -/
def scriptVectors_1121 : ScrVec :=
  { id := "sc-1121", scriptSig := bytes #[71,48,68,2,32,10,92,97,99,240,123,141,59,1,60,77,29,109,186,37,231,128,179,150,88,215,155,163,122,247,5,122,59,127,21,255,161,2,32,31,217,180,234,169,148,63,115,73,40,185,154,131,89,44,46,123,243,66,234,38,128,246,162,187,112,81,103,150,107,116,32,1],
    scriptPubKey := bytes #[65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172],
    witness := [bytes #[]],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "WITNESS_UNEXPECTED",
    comment := "P2PK with witness" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1122. -/
def scriptVectors_1122 : ScrVec :=
  { id := "sc-1122", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,24,99,20,60,20,197,22,104,4,189,25,32,51,86,218,19,108,152,86,120,205,77,39,161,184,198,50,150,4,144,50,98],
    witness := [bytes #[48,68,2,32,66,86,20,111,207,142,115,176,253,129,127,250,42,78,64,143,240,65,143,249,135,221,8,164,244,133,182,37,70,246,196,60,2,32,63,60,140,62,47,235,192,81,225,34,40,103,245,249,208,234,240,57,214,121,41,17,193,9,64,170,60,199,65,35,55,142,1], bytes #[33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,172]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := true, expectedError := "OK",
    comment := "Basic P2WSH with compressed key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1123. -/
def scriptVectors_1123 : ScrVec :=
  { id := "sc-1123", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,20,117,30,118,232,25,145,150,212,84,148,28,69,209,179,163,35,241,67,59,214],
    witness := [bytes #[48,68,2,32,78,223,39,72,111,17,67,36,102,183,68,223,83,62,26,202,199,39,224,200,62,95,145,46,178,137,163,223,91,248,3,95,2,32,117,128,159,221,135,110,222,64,173,33,102,126,186,139,126,150,57,73,56,249,201,197,15,17,182,161,40,12,206,44,234,134,1], bytes #[2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := true, expectedError := "OK",
    comment := "Basic P2WPKH with compressed key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1124. -/
def scriptVectors_1124 : ScrVec :=
  { id := "sc-1124", scriptSig := bytes #[34,0,32,24,99,20,60,20,197,22,104,4,189,25,32,51,86,218,19,108,152,86,120,205,77,39,161,184,198,50,150,4,144,50,98],
    scriptPubKey := bytes #[169,20,228,48,5,49,25,5,135,227,136,13,76,48,4,245,53,93,136,255,146,141,135],
    witness := [bytes #[48,68,2,32,58,84,144,144,204,70,188,225,229,233,92,73,34,234,44,18,116,121,136,224,32,123,4,196,47,129,205,190,135,187,21,57,2,32,80,245,122,36,91,135,95,213,17,156,65,154,175,5,11,205,244,19,132,240,118,95,4,184,9,229,188,237,31,231,9,61,1], bytes #[33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,172]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := true, expectedError := "OK",
    comment := "Basic P2SH(P2WSH) with compressed key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1125. -/
def scriptVectors_1125 : ScrVec :=
  { id := "sc-1125", scriptSig := bytes #[22,0,20,117,30,118,232,25,145,150,212,84,148,28,69,209,179,163,35,241,67,59,214],
    scriptPubKey := bytes #[169,20,188,254,183,40,181,132,37,61,95,63,112,188,183,128,233,239,33,138,104,244,135],
    witness := [bytes #[48,68,2,32,27,192,213,48,70,130,127,74,53,163,22,110,51,227,179,54,108,64,133,84,13,195,131,185,93,33,237,42,177,30,54,138,2,32,51,62,120,198,35,18,20,245,248,229,150,33,225,93,126,234,176,212,228,208,121,100,55,224,11,251,210,104,12,95,156,23,1], bytes #[2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := true, expectedError := "OK",
    comment := "Basic P2SH(P2WPKH) with compressed key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1126. -/
def scriptVectors_1126 : ScrVec :=
  { id := "sc-1126", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,185,82,55,180,143,170,166,158,176,120,225,23,11,227,181,203,179,253,223,22,208,169,145,225,74,210,116,247,179,58,79,100],
    witness := [bytes #[48,68,2,32,13,70,28,20,12,253,252,243,107,148,150,29,181,122,232,193,141,28,184,14,157,149,169,228,122,194,36,112,193,191,18,85,2,32,28,141,193,203,254,246,163,239,144,172,187,185,146,202,34,254,148,102,238,111,157,72,152,237,162,119,167,172,58,180,178,81,1], bytes #[65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := false, expectedError := "WITNESS_PUBKEYTYPE",
    comment := "Basic P2WSH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1127. -/
def scriptVectors_1127 : ScrVec :=
  { id := "sc-1127", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,20,145,178,75,249,245,40,133,50,150,10,198,135,171,176,53,18,123,29,40,165],
    witness := [bytes #[48,68,2,32,30,114,22,229,204,179,182,29,70,148,110,198,204,126,140,78,1,23,209,58,194,253,75,21,33,151,228,128,81,145,199,66,2,32,62,153,3,227,62,132,217,238,29,209,63,176,87,175,183,204,251,71,0,108,35,246,160,103,24,94,251,201,221,120,15,197,1], bytes #[4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := false, expectedError := "WITNESS_PUBKEYTYPE",
    comment := "Basic P2WPKH" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1128. -/
def scriptVectors_1128 : ScrVec :=
  { id := "sc-1128", scriptSig := bytes #[34,0,32,185,82,55,180,143,170,166,158,176,120,225,23,11,227,181,203,179,253,223,22,208,169,145,225,74,210,116,247,179,58,79,100],
    scriptPubKey := bytes #[169,20,243,134,194,186,37,92,197,109,32,207,166,234,139,6,47,139,89,148,85,24,135],
    witness := [bytes #[48,68,2,32,102,224,44,25,165,19,4,157,73,52,156,245,49,26,27,1,43,124,79,174,2,55,149,161,138,177,217,28,35,73,108,34,2,32,37,226,22,52,44,142,7,206,142,245,30,141,174,232,143,132,48,106,157,230,98,54,202,178,48,187,99,6,125,237,26,211,1], bytes #[65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,172]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := false, expectedError := "WITNESS_PUBKEYTYPE",
    comment := "Basic P2SH(P2WSH)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1129. -/
def scriptVectors_1129 : ScrVec :=
  { id := "sc-1129", scriptSig := bytes #[22,0,20,145,178,75,249,245,40,133,50,150,10,198,135,171,176,53,18,123,29,40,165],
    scriptPubKey := bytes #[169,20,23,116,59,235,66,156,85,201,66,210,236,112,59,152,196,213,124,45,245,198,135],
    witness := [bytes #[48,68,2,32,9,41,209,21,97,205,149,132,96,55,18,0,248,46,156,174,100,199,39,164,149,113,90,49,130,142,39,167,173,87,179,109,2,32,54,23,50,206,208,74,111,151,53,30,204,162,26,86,208,184,205,73,50,193,218,31,143,86,154,43,104,229,228,138,237,120,1], bytes #[4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := false, expectedError := "WITNESS_PUBKEYTYPE",
    comment := "Basic P2SH(P2WPKH)" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1130. -/
def scriptVectors_1130 : ScrVec :=
  { id := "sc-1130", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,20,254,120,176,5,37,87,179,214,114,72,208,78,79,123,153,195,97,22,116,50],
    witness := [bytes #[], bytes #[4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := false, expectedError := "WITNESS_PUBKEYTYPE",
    comment := "P2WPKH with invalid prefix for compressed key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1131. -/
def scriptVectors_1131 : ScrVec :=
  { id := "sc-1131", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,6,194,68,32,147,143,15,163,193,203,39,7,216,103,21,66,32,220,163,101,205,191,160,221,42,131,133,71,48,34,20,96],
    witness := [bytes #[], bytes #[48,68,2,32,126,184,165,155,92,101,252,63,106,238,247,112,102,85,110,213,197,65,148,138,83,163,186,127,124,55,91,142,237,118,238,117,2,32,30,3,106,122,154,152,255,145,159,249,77,201,5,214,122,30,192,6,247,158,247,207,240,112,132,133,200,187,121,220,227,142,1], bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := true, expectedError := "OK",
    comment := "P2WSH CHECKMULTISIG with compressed keys" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1132. -/
def scriptVectors_1132 : ScrVec :=
  { id := "sc-1132", scriptSig := bytes #[34,0,32,6,194,68,32,147,143,15,163,193,203,39,7,216,103,21,66,32,220,163,101,205,191,160,221,42,131,133,71,48,34,20,96],
    scriptPubKey := bytes #[169,20,38,40,42,173,124,41,54,157,21,254,208,98,167,120,182,16,13,49,163,64,135],
    witness := [bytes #[], bytes #[48,68,2,32,51,112,106,237,51,184,21,93,84,134,223,59,155,202,140,221,59,212,189,181,67,109,206,70,215,44,218,186,81,210,43,64,2,32,54,38,233,79,229,58,23,138,244,102,36,241,115,21,198,147,31,32,163,11,16,63,94,4,78,30,218,12,63,225,133,198,1], bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := true, expectedError := "OK",
    comment := "P2SH(P2WSH) CHECKMULTISIG with compressed keys" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1133. -/
def scriptVectors_1133 : ScrVec :=
  { id := "sc-1133", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,6,194,68,32,147,143,15,163,193,203,39,7,216,103,21,66,32,220,163,101,205,191,160,221,42,131,133,71,48,34,20,96],
    witness := [bytes #[], bytes #[48,68,2,32,64,72,183,55,26,177,197,68,54,46,251,137,175,12,128,21,71,71,214,101,170,79,207,178,237,253,45,22,30,87,180,46,2,32,126,4,55,72,233,102,55,8,15,252,58,203,212,220,198,254,225,229,141,48,246,209,38,149,53,243,33,136,229,221,174,115,1], bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := true, expectedError := "OK",
    comment := "P2WSH CHECKMULTISIG with compressed keys" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1134. -/
def scriptVectors_1134 : ScrVec :=
  { id := "sc-1134", scriptSig := bytes #[34,0,32,6,194,68,32,147,143,15,163,193,203,39,7,216,103,21,66,32,220,163,101,205,191,160,221,42,131,133,71,48,34,20,96],
    scriptPubKey := bytes #[169,20,38,40,42,173,124,41,54,157,21,254,208,98,167,120,182,16,13,49,163,64,135],
    witness := [bytes #[], bytes #[48,68,2,32,115,144,46,240,184,165,84,195,108,68,204,3,193,182,77,249,108,226,145,78,188,249,70,245,187,54,7,143,213,36,92,223,2,32,91,20,143,27,161,39,6,95,184,200,58,90,149,118,242,220,209,17,115,151,136,237,75,179,238,8,178,189,56,96,201,28,1], bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := true, expectedError := "OK",
    comment := "P2SH(P2WSH) CHECKMULTISIG with compressed keys" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1135. -/
def scriptVectors_1135 : ScrVec :=
  { id := "sc-1135", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,8,166,102,94,191,212,59,2,50,52,35,231,100,225,133,217,141,21,135,249,3,184,21,7,219,182,155,252,65,0,94,250],
    witness := [bytes #[], bytes #[48,68,2,32,45,9,46,222,221,31,6,6,9,219,248,203,118,149,6,52,255,66,179,230,44,244,173,182,154,185,35,151,176,125,116,35,2,32,79,248,134,248,208,129,116,145,169,109,29,172,205,204,130,15,111,235,18,46,230,35,1,67,48,49,0,219,55,223,167,159,1], bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2WSH CHECKMULTISIG with first key uncompressed and signing with the first key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1136. -/
def scriptVectors_1136 : ScrVec :=
  { id := "sc-1136", scriptSig := bytes #[34,0,32,8,166,102,94,191,212,59,2,50,52,35,231,100,225,133,217,141,21,135,249,3,184,21,7,219,182,155,252,65,0,94,250],
    scriptPubKey := bytes #[169,20,111,94,205,75,131,183,127,60,67,143,82,20,239,249,100,84,147,79,197,209,135],
    witness := [bytes #[], bytes #[48,68,2,32,45,215,233,18,67,242,35,84,129,255,182,38,195,183,186,242,200,89,174,58,90,119,251,117,14,249,123,153,168,18,93,192,2,32,73,96,222,61,60,58,185,73,110,33,142,197,126,82,64,224,225,10,111,149,70,49,111,226,64,194,22,212,81,22,210,147,1], bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2SH(P2WSH) CHECKMULTISIG first key uncompressed and signing with the first key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1137. -/
def scriptVectors_1137 : ScrVec :=
  { id := "sc-1137", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,8,166,102,94,191,212,59,2,50,52,35,231,100,225,133,217,141,21,135,249,3,184,21,7,219,182,155,252,65,0,94,250],
    witness := [bytes #[], bytes #[48,68,2,32,45,9,46,222,221,31,6,6,9,219,248,203,118,149,6,52,255,66,179,230,44,244,173,182,154,185,35,151,176,125,116,35,2,32,79,248,134,248,208,129,116,145,169,109,29,172,205,204,130,15,111,235,18,46,230,35,1,67,48,49,0,219,55,223,167,159,1], bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := false, expectedError := "WITNESS_PUBKEYTYPE",
    comment := "P2WSH CHECKMULTISIG with first key uncompressed and signing with the first key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1138. -/
def scriptVectors_1138 : ScrVec :=
  { id := "sc-1138", scriptSig := bytes #[34,0,32,8,166,102,94,191,212,59,2,50,52,35,231,100,225,133,217,141,21,135,249,3,184,21,7,219,182,155,252,65,0,94,250],
    scriptPubKey := bytes #[169,20,111,94,205,75,131,183,127,60,67,143,82,20,239,249,100,84,147,79,197,209,135],
    witness := [bytes #[], bytes #[48,68,2,32,45,215,233,18,67,242,35,84,129,255,182,38,195,183,186,242,200,89,174,58,90,119,251,117,14,249,123,153,168,18,93,192,2,32,73,96,222,61,60,58,185,73,110,33,142,197,126,82,64,224,225,10,111,149,70,49,111,226,64,194,22,212,81,22,210,147,1], bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := false, expectedError := "WITNESS_PUBKEYTYPE",
    comment := "P2SH(P2WSH) CHECKMULTISIG with first key uncompressed and signing with the first key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1139. -/
def scriptVectors_1139 : ScrVec :=
  { id := "sc-1139", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,8,166,102,94,191,212,59,2,50,52,35,231,100,225,133,217,141,21,135,249,3,184,21,7,219,182,155,252,65,0,94,250],
    witness := [bytes #[], bytes #[48,68,2,32,30,158,111,125,238,245,178,242,29,130,35,197,24,155,125,94,130,210,55,193,14,151,22,93,208,143,84,124,78,92,230,237,2,32,103,150,55,46,177,204,106,203,82,225,62,226,215,244,88,7,120,11,249,107,19,44,182,105,127,105,67,75,231,75,26,249,1], bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2WSH CHECKMULTISIG with first key uncompressed and signing with the second key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1140. -/
def scriptVectors_1140 : ScrVec :=
  { id := "sc-1140", scriptSig := bytes #[34,0,32,8,166,102,94,191,212,59,2,50,52,35,231,100,225,133,217,141,21,135,249,3,184,21,7,219,182,155,252,65,0,94,250],
    scriptPubKey := bytes #[169,20,111,94,205,75,131,183,127,60,67,143,82,20,239,249,100,84,147,79,197,209,135],
    witness := [bytes #[], bytes #[48,68,2,32,69,230,103,243,240,243,20,123,149,89,122,36,186,190,154,254,206,161,246,73,253,35,99,125,250,126,215,233,243,172,24,68,2,32,41,87,72,232,16,5,35,17,53,40,159,227,168,131,56,218,187,165,90,250,27,219,68,120,105,19,55,0,157,130,182,141,1], bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2SH(P2WSH) CHECKMULTISIG with first key uncompressed and signing with the second key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1141. -/
def scriptVectors_1141 : ScrVec :=
  { id := "sc-1141", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,8,166,102,94,191,212,59,2,50,52,35,231,100,225,133,217,141,21,135,249,3,184,21,7,219,182,155,252,65,0,94,250],
    witness := [bytes #[], bytes #[48,68,2,32,30,158,111,125,238,245,178,242,29,130,35,197,24,155,125,94,130,210,55,193,14,151,22,93,208,143,84,124,78,92,230,237,2,32,103,150,55,46,177,204,106,203,82,225,62,226,215,244,88,7,120,11,249,107,19,44,182,105,127,105,67,75,231,75,26,249,1], bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := false, expectedError := "WITNESS_PUBKEYTYPE",
    comment := "P2WSH CHECKMULTISIG with first key uncompressed and signing with the second key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1142. -/
def scriptVectors_1142 : ScrVec :=
  { id := "sc-1142", scriptSig := bytes #[34,0,32,8,166,102,94,191,212,59,2,50,52,35,231,100,225,133,217,141,21,135,249,3,184,21,7,219,182,155,252,65,0,94,250],
    scriptPubKey := bytes #[169,20,111,94,205,75,131,183,127,60,67,143,82,20,239,249,100,84,147,79,197,209,135],
    witness := [bytes #[], bytes #[48,68,2,32,69,230,103,243,240,243,20,123,149,89,122,36,186,190,154,254,206,161,246,73,253,35,99,125,250,126,215,233,243,172,24,68,2,32,41,87,72,232,16,5,35,17,53,40,159,227,168,131,56,218,187,165,90,250,27,219,68,120,105,19,55,0,157,130,182,141,1], bytes #[81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,65,4,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,72,58,218,119,38,163,196,101,93,164,251,252,14,17,8,168,253,23,180,72,166,133,84,25,156,71,208,143,251,16,212,184,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := false, expectedError := "WITNESS_PUBKEYTYPE",
    comment := "P2SH(P2WSH) CHECKMULTISIG with first key uncompressed and signing with the second key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1143. -/
def scriptVectors_1143 : ScrVec :=
  { id := "sc-1143", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,35,8,40,237,72,135,31,15,54,44,233,67,42,165,47,98,15,68,44,200,217,206,122,139,94,121,131,101,89,90,56,187],
    witness := [bytes #[], bytes #[48,68,2,32,70,245,54,122,38,31,216,248,215,222,110,179,144,73,19,68,248,236,37,1,99,143,185,161,9,90,5,153,162,29,63,76,2,32,92,27,59,81,210,0,145,197,241,2,8,65,187,202,135,180,78,190,37,64,92,100,228,172,247,88,242,234,232,102,95,132,1], bytes #[81,65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2WSH CHECKMULTISIG with second key uncompressed and signing with the first key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1144. -/
def scriptVectors_1144 : ScrVec :=
  { id := "sc-1144", scriptSig := bytes #[34,0,32,35,8,40,237,72,135,31,15,54,44,233,67,42,165,47,98,15,68,44,200,217,206,122,139,94,121,131,101,89,90,56,187],
    scriptPubKey := bytes #[169,20,52,120,231,1,156,230,26,104,20,143,135,84,149,121,183,4,203,228,195,147,135],
    witness := [bytes #[], bytes #[48,68,2,32,83,226,16,228,251,24,129,230,9,47,215,92,62,252,81,99,16,85,153,226,70,222,214,97,192,238,43,86,130,204,45,108,2,32,58,38,183,173,168,104,42,9,91,132,198,209,184,129,99,112,0,180,125,118,31,200,55,196,206,227,53,85,41,109,99,241,1], bytes #[81,65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2SH(P2WSH) CHECKMULTISIG second key uncompressed and signing with the first key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1145. -/
def scriptVectors_1145 : ScrVec :=
  { id := "sc-1145", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,35,8,40,237,72,135,31,15,54,44,233,67,42,165,47,98,15,68,44,200,217,206,122,139,94,121,131,101,89,90,56,187],
    witness := [bytes #[], bytes #[48,68,2,32,70,245,54,122,38,31,216,248,215,222,110,179,144,73,19,68,248,236,37,1,99,143,185,161,9,90,5,153,162,29,63,76,2,32,92,27,59,81,210,0,145,197,241,2,8,65,187,202,135,180,78,190,37,64,92,100,228,172,247,88,242,234,232,102,95,132,1], bytes #[81,65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := true, expectedError := "OK",
    comment := "P2WSH CHECKMULTISIG with second key uncompressed and signing with the first key should pass as the uncompressed key is not used" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1146. -/
def scriptVectors_1146 : ScrVec :=
  { id := "sc-1146", scriptSig := bytes #[34,0,32,35,8,40,237,72,135,31,15,54,44,233,67,42,165,47,98,15,68,44,200,217,206,122,139,94,121,131,101,89,90,56,187],
    scriptPubKey := bytes #[169,20,52,120,231,1,156,230,26,104,20,143,135,84,149,121,183,4,203,228,195,147,135],
    witness := [bytes #[], bytes #[48,68,2,32,83,226,16,228,251,24,129,230,9,47,215,92,62,252,81,99,16,85,153,226,70,222,214,97,192,238,43,86,130,204,45,108,2,32,58,38,183,173,168,104,42,9,91,132,198,209,184,129,99,112,0,180,125,118,31,200,55,196,206,227,53,85,41,109,99,241,1], bytes #[81,65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := true, expectedError := "OK",
    comment := "P2SH(P2WSH) CHECKMULTISIG with second key uncompressed and signing with the first key should pass as the uncompressed key is not used" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1147. -/
def scriptVectors_1147 : ScrVec :=
  { id := "sc-1147", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,35,8,40,237,72,135,31,15,54,44,233,67,42,165,47,98,15,68,44,200,217,206,122,139,94,121,131,101,89,90,56,187],
    witness := [bytes #[], bytes #[48,68,2,32,108,109,159,93,175,133,181,74,242,169,62,195,139,21,171,39,242,5,219,245,199,53,54,95,241,36,81,228,54,19,209,244,2,32,115,106,68,190,99,66,62,213,235,245,52,145,97,139,124,195,216,165,9,56,97,144,141,168,83,115,156,115,113,121,56,183,1], bytes #[81,65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2WSH CHECKMULTISIG with second key uncompressed and signing with the second key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1148. -/
def scriptVectors_1148 : ScrVec :=
  { id := "sc-1148", scriptSig := bytes #[34,0,32,35,8,40,237,72,135,31,15,54,44,233,67,42,165,47,98,15,68,44,200,217,206,122,139,94,121,131,101,89,90,56,187],
    scriptPubKey := bytes #[169,20,52,120,231,1,156,230,26,104,20,143,135,84,149,121,183,4,203,228,195,147,135],
    witness := [bytes #[], bytes #[48,68,2,32,104,120,113,188,97,68,1,45,117,186,245,133,187,38,206,19,153,127,125,140,98,111,77,136,37,176,105,195,178,208,100,71,2,32,16,137,54,254,28,87,50,119,100,120,34,83,233,144,144,176,156,32,62,196,0,237,53,206,158,2,108,226,236,248,66,160,1], bytes #[81,65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "P2SH(P2WSH) CHECKMULTISIG with second key uncompressed and signing with the second key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1149. -/
def scriptVectors_1149 : ScrVec :=
  { id := "sc-1149", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,35,8,40,237,72,135,31,15,54,44,233,67,42,165,47,98,15,68,44,200,217,206,122,139,94,121,131,101,89,90,56,187],
    witness := [bytes #[], bytes #[48,68,2,32,108,109,159,93,175,133,181,74,242,169,62,195,139,21,171,39,242,5,219,245,199,53,54,95,241,36,81,228,54,19,209,244,2,32,115,106,68,190,99,66,62,213,235,245,52,145,97,139,124,195,216,165,9,56,97,144,141,168,83,115,156,115,113,121,56,183,1], bytes #[81,65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := false, expectedError := "WITNESS_PUBKEYTYPE",
    comment := "P2WSH CHECKMULTISIG with second key uncompressed and signing with the second key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1150. -/
def scriptVectors_1150 : ScrVec :=
  { id := "sc-1150", scriptSig := bytes #[34,0,32,35,8,40,237,72,135,31,15,54,44,233,67,42,165,47,98,15,68,44,200,217,206,122,139,94,121,131,101,89,90,56,187],
    scriptPubKey := bytes #[169,20,52,120,231,1,156,230,26,104,20,143,135,84,149,121,183,4,203,228,195,147,135],
    witness := [bytes #[], bytes #[48,68,2,32,104,120,113,188,97,68,1,45,117,186,245,133,187,38,206,19,153,127,125,140,98,111,77,136,37,176,105,195,178,208,100,71,2,32,16,137,54,254,28,87,50,119,100,120,34,83,233,144,144,176,156,32,62,196,0,237,53,206,158,2,108,226,236,248,66,160,1], bytes #[81,65,4,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,17,248,168,9,133,87,223,228,94,130,86,232,48,182,10,206,98,214,19,172,47,123,23,190,211,27,110,175,246,226,108,175,33,2,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152,82,174]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "WITNESS_PUBKEYTYPE",
    expectOk := false, expectedError := "WITNESS_PUBKEYTYPE",
    comment := "P2SH(P2WSH) CHECKMULTISIG with second key uncompressed and signing with the second key" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1151. -/
def scriptVectors_1151 : ScrVec :=
  { id := "sc-1151", scriptSig := bytes #[0],
    scriptPubKey := bytes #[33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,173,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "CHECKSIGVERIFY",
    comment := "CHECKSIGVERIFY fails with its own error code when the signature check fails" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1152. -/
def scriptVectors_1152 : ScrVec :=
  { id := "sc-1152", scriptSig := bytes #[0,0],
    scriptPubKey := bytes #[81,33,2,134,92,64,41,58,104,12,185,192,32,231,177,225,6,216,193,145,109,60,239,153,170,67,26,86,210,83,230,146,86,218,192,81,175,81],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "STRICTENC",
    expectOk := false, expectedError := "CHECKMULTISIGVERIFY",
    comment := "CHECKMULTISIGVERIFY fails with its own error code when the signature check fails" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1153. -/
def scriptVectors_1153 : ScrVec :=
  { id := "sc-1153", scriptSig := bytes #[],
    scriptPubKey := bytes #[177],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := true, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "CLTV automatically fails on an empty stack" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1154. -/
def scriptVectors_1154 : ScrVec :=
  { id := "sc-1154", scriptSig := bytes #[79],
    scriptPubKey := bytes #[177],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := true, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "NEGATIVE_LOCKTIME",
    comment := "CLTV automatically fails if stack top is negative" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1155. -/
def scriptVectors_1155 : ScrVec :=
  { id := "sc-1155", scriptSig := bytes #[1,128],
    scriptPubKey := bytes #[177],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := true, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "UNSATISFIED_LOCKTIME",
    comment := "Negative zero is treated as 0, so CLTV fails with UNSATISFIED_LOCKTIME rather than NEGATIVE_LOCKTIME" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1156. -/
def scriptVectors_1156 : ScrVec :=
  { id := "sc-1156", scriptSig := bytes #[1,0],
    scriptPubKey := bytes #[177],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := true, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "CLTV use is non-standard if stack top is not minimally encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1157. -/
def scriptVectors_1157 : ScrVec :=
  { id := "sc-1157", scriptSig := bytes #[0],
    scriptPubKey := bytes #[177],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := true, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "UNSATISFIED_LOCKTIME",
    comment := "CLTV fails if the input's nSequence is final, even when the lock time requirement is met" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1158. -/
def scriptVectors_1158 : ScrVec :=
  { id := "sc-1158", scriptSig := bytes #[4,255,100,205,29],
    scriptPubKey := bytes #[177],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := true, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "UNSATISFIED_LOCKTIME",
    comment := "CLTV fails if the stack operand (height) is greater than the tx nLockTime" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1159. -/
def scriptVectors_1159 : ScrVec :=
  { id := "sc-1159", scriptSig := bytes #[4,0,101,205,29],
    scriptPubKey := bytes #[177],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := true, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "UNSATISFIED_LOCKTIME",
    comment := "CLTV fails if the operand is time-based while the tx nLockTime is height-based" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1160. -/
def scriptVectors_1160 : ScrVec :=
  { id := "sc-1160", scriptSig := bytes #[5,0,0,0,0,1],
    scriptPubKey := bytes #[177],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := true, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "UNSATISFIED_LOCKTIME",
    comment := "CLTV accepts a 5-byte operand (2^32), but it is time-based while the tx nLockTime is height-based" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1161. -/
def scriptVectors_1161 : ScrVec :=
  { id := "sc-1161", scriptSig := bytes #[],
    scriptPubKey := bytes #[178],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := true, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "CSV automatically fails on an empty stack" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1162. -/
def scriptVectors_1162 : ScrVec :=
  { id := "sc-1162", scriptSig := bytes #[79],
    scriptPubKey := bytes #[178],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := true, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "NEGATIVE_LOCKTIME",
    comment := "CSV automatically fails if stack top is negative" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1163. -/
def scriptVectors_1163 : ScrVec :=
  { id := "sc-1163", scriptSig := bytes #[1,128],
    scriptPubKey := bytes #[178],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := true, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "UNSATISFIED_LOCKTIME",
    comment := "Negative zero is treated as 0, so CSV fails with UNSATISFIED_LOCKTIME rather than NEGATIVE_LOCKTIME" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1164. -/
def scriptVectors_1164 : ScrVec :=
  { id := "sc-1164", scriptSig := bytes #[1,0],
    scriptPubKey := bytes #[178],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := true, nullDummy := false, witness := false, taproot := false }, policyFlags := "MINIMALDATA",
    expectOk := false, expectedError := "SCRIPTNUM",
    comment := "CSV fails if stack top is not minimally encoded" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1165. -/
def scriptVectors_1165 : ScrVec :=
  { id := "sc-1165", scriptSig := bytes #[0],
    scriptPubKey := bytes #[178],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := true, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "UNSATISFIED_LOCKTIME",
    comment := "CSV fails if stack top bit 1 << 31 is set and the tx version < 2" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1166. -/
def scriptVectors_1166 : ScrVec :=
  { id := "sc-1166", scriptSig := bytes #[5,0,0,0,0,1],
    scriptPubKey := bytes #[178],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := true, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "UNSATISFIED_LOCKTIME",
    comment := "CSV fails if stack top bit 1 << 31 is not set, and tx version < 2" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1167. -/
def scriptVectors_1167 : ScrVec :=
  { id := "sc-1167", scriptSig := bytes #[81],
    scriptPubKey := bytes #[99,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := "1 | IF 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1168. -/
def scriptVectors_1168 : ScrVec :=
  { id := "sc-1168", scriptSig := bytes #[82],
    scriptPubKey := bytes #[99,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := "2 | IF 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1169. -/
def scriptVectors_1169 : ScrVec :=
  { id := "sc-1169", scriptSig := bytes #[2,1,0],
    scriptPubKey := bytes #[99,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0100 | IF 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1170. -/
def scriptVectors_1170 : ScrVec :=
  { id := "sc-1170", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 | IF 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1171. -/
def scriptVectors_1171 : ScrVec :=
  { id := "sc-1171", scriptSig := bytes #[1,0],
    scriptPubKey := bytes #[99,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0x01 0x00 | IF 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1172. -/
def scriptVectors_1172 : ScrVec :=
  { id := "sc-1172", scriptSig := bytes #[81],
    scriptPubKey := bytes #[100,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "1 | NOTIF 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1173. -/
def scriptVectors_1173 : ScrVec :=
  { id := "sc-1173", scriptSig := bytes #[82],
    scriptPubKey := bytes #[100,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "2 | NOTIF 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1174. -/
def scriptVectors_1174 : ScrVec :=
  { id := "sc-1174", scriptSig := bytes #[2,1,0],
    scriptPubKey := bytes #[100,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0x02 0x0100 | NOTIF 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1175. -/
def scriptVectors_1175 : ScrVec :=
  { id := "sc-1175", scriptSig := bytes #[0],
    scriptPubKey := bytes #[100,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := "0 | NOTIF 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1176. -/
def scriptVectors_1176 : ScrVec :=
  { id := "sc-1176", scriptSig := bytes #[1,0],
    scriptPubKey := bytes #[100,81,104],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := "0x01 0x00 | NOTIF 1 ENDIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1177. -/
def scriptVectors_1177 : ScrVec :=
  { id := "sc-1177", scriptSig := bytes #[81,3,99,81,104],
    scriptPubKey := bytes #[169,20,231,48,150,82,168,227,246,0,240,111,93,141,82,214,223,3,210,23,108,195,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := "1 0x03 0x635168 | HASH160 0x14 0xe7309652a8e3f600f06f5d8d52d6df03d2176cc3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1178. -/
def scriptVectors_1178 : ScrVec :=
  { id := "sc-1178", scriptSig := bytes #[82,3,99,81,104],
    scriptPubKey := bytes #[169,20,231,48,150,82,168,227,246,0,240,111,93,141,82,214,223,3,210,23,108,195,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := "2 0x03 0x635168 | HASH160 0x14 0xe7309652a8e3f600f06f5d8d52d6df03d2176cc3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1179. -/
def scriptVectors_1179 : ScrVec :=
  { id := "sc-1179", scriptSig := bytes #[2,1,0,3,99,81,104],
    scriptPubKey := bytes #[169,20,231,48,150,82,168,227,246,0,240,111,93,141,82,214,223,3,210,23,108,195,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := "0x02 0x0100 0x03 0x635168 | HASH160 0x14 0xe7309652a8e3f600f06f5d8d52d6df03d2176cc3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1180. -/
def scriptVectors_1180 : ScrVec :=
  { id := "sc-1180", scriptSig := bytes #[0,3,99,81,104],
    scriptPubKey := bytes #[169,20,231,48,150,82,168,227,246,0,240,111,93,141,82,214,223,3,210,23,108,195,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0 0x03 0x635168 | HASH160 0x14 0xe7309652a8e3f600f06f5d8d52d6df03d2176cc3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1181. -/
def scriptVectors_1181 : ScrVec :=
  { id := "sc-1181", scriptSig := bytes #[1,0,3,99,81,104],
    scriptPubKey := bytes #[169,20,231,48,150,82,168,227,246,0,240,111,93,141,82,214,223,3,210,23,108,195,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0x01 0x00 0x03 0x635168 | HASH160 0x14 0xe7309652a8e3f600f06f5d8d52d6df03d2176cc3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1182. -/
def scriptVectors_1182 : ScrVec :=
  { id := "sc-1182", scriptSig := bytes #[3,99,81,104],
    scriptPubKey := bytes #[169,20,231,48,150,82,168,227,246,0,240,111,93,141,82,214,223,3,210,23,108,195,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "0x03 0x635168 | HASH160 0x14 0xe7309652a8e3f600f06f5d8d52d6df03d2176cc3 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1183. -/
def scriptVectors_1183 : ScrVec :=
  { id := "sc-1183", scriptSig := bytes #[81,3,100,81,104],
    scriptPubKey := bytes #[169,20,12,63,143,227,214,202,38,110,118,49,30,205,165,68,198,125,21,253,213,176,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "1 0x03 0x645168 | HASH160 0x14 0x0c3f8fe3d6ca266e76311ecda544c67d15fdd5b0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1184. -/
def scriptVectors_1184 : ScrVec :=
  { id := "sc-1184", scriptSig := bytes #[82,3,100,81,104],
    scriptPubKey := bytes #[169,20,12,63,143,227,214,202,38,110,118,49,30,205,165,68,198,125,21,253,213,176,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "2 0x03 0x645168 | HASH160 0x14 0x0c3f8fe3d6ca266e76311ecda544c67d15fdd5b0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1185. -/
def scriptVectors_1185 : ScrVec :=
  { id := "sc-1185", scriptSig := bytes #[2,1,0,3,100,81,104],
    scriptPubKey := bytes #[169,20,12,63,143,227,214,202,38,110,118,49,30,205,165,68,198,125,21,253,213,176,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "0x02 0x0100 0x03 0x645168 | HASH160 0x14 0x0c3f8fe3d6ca266e76311ecda544c67d15fdd5b0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1186. -/
def scriptVectors_1186 : ScrVec :=
  { id := "sc-1186", scriptSig := bytes #[0,3,100,81,104],
    scriptPubKey := bytes #[169,20,12,63,143,227,214,202,38,110,118,49,30,205,165,68,198,125,21,253,213,176,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := "0 0x03 0x645168 | HASH160 0x14 0x0c3f8fe3d6ca266e76311ecda544c67d15fdd5b0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1187. -/
def scriptVectors_1187 : ScrVec :=
  { id := "sc-1187", scriptSig := bytes #[1,0,3,100,81,104],
    scriptPubKey := bytes #[169,20,12,63,143,227,214,202,38,110,118,49,30,205,165,68,198,125,21,253,213,176,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := "0x01 0x00 0x03 0x645168 | HASH160 0x14 0x0c3f8fe3d6ca266e76311ecda544c67d15fdd5b0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1188. -/
def scriptVectors_1188 : ScrVec :=
  { id := "sc-1188", scriptSig := bytes #[3,100,81,104],
    scriptPubKey := bytes #[169,20,12,63,143,227,214,202,38,110,118,49,30,205,165,68,198,125,21,253,213,176,135],
    witness := [],
    value := 0,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "0x03 0x645168 | HASH160 0x14 0x0c3f8fe3d6ca266e76311ecda544c67d15fdd5b0 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1189. -/
def scriptVectors_1189 : ScrVec :=
  { id := "sc-1189", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    witness := [bytes #[1], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0x20 0xc7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1190. -/
def scriptVectors_1190 : ScrVec :=
  { id := "sc-1190", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    witness := [bytes #[2], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0x20 0xc7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1191. -/
def scriptVectors_1191 : ScrVec :=
  { id := "sc-1191", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    witness := [bytes #[1,0], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0x20 0xc7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1192. -/
def scriptVectors_1192 : ScrVec :=
  { id := "sc-1192", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    witness := [bytes #[], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := " | 0 0x20 0xc7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1193. -/
def scriptVectors_1193 : ScrVec :=
  { id := "sc-1193", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    witness := [bytes #[0], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := " | 0 0x20 0xc7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1194. -/
def scriptVectors_1194 : ScrVec :=
  { id := "sc-1194", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    witness := [bytes #[1], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0x20 0xc7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1195. -/
def scriptVectors_1195 : ScrVec :=
  { id := "sc-1195", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    witness := [bytes #[2], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "MINIMALIF",
    comment := " | 0 0x20 0xc7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1196. -/
def scriptVectors_1196 : ScrVec :=
  { id := "sc-1196", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    witness := [bytes #[1,0], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "MINIMALIF",
    comment := " | 0 0x20 0xc7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1197. -/
def scriptVectors_1197 : ScrVec :=
  { id := "sc-1197", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    witness := [bytes #[], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := " | 0 0x20 0xc7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1198. -/
def scriptVectors_1198 : ScrVec :=
  { id := "sc-1198", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    witness := [bytes #[0], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "MINIMALIF",
    comment := " | 0 0x20 0xc7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1199. -/
def scriptVectors_1199 : ScrVec :=
  { id := "sc-1199", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    witness := [bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := " | 0 0x20 0xc7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1200. -/
def scriptVectors_1200 : ScrVec :=
  { id := "sc-1200", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    witness := [bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := " | 0 0x20 0xc7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1201. -/
def scriptVectors_1201 : ScrVec :=
  { id := "sc-1201", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    witness := [bytes #[1], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := " | 0 0x20 0xf913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1202. -/
def scriptVectors_1202 : ScrVec :=
  { id := "sc-1202", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    witness := [bytes #[2], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := " | 0 0x20 0xf913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1203. -/
def scriptVectors_1203 : ScrVec :=
  { id := "sc-1203", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    witness := [bytes #[1,0], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := " | 0 0x20 0xf913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1204. -/
def scriptVectors_1204 : ScrVec :=
  { id := "sc-1204", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    witness := [bytes #[], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0x20 0xf913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1205. -/
def scriptVectors_1205 : ScrVec :=
  { id := "sc-1205", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    witness := [bytes #[0], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0x20 0xf913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1206. -/
def scriptVectors_1206 : ScrVec :=
  { id := "sc-1206", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    witness := [bytes #[1], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := " | 0 0x20 0xf913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1207. -/
def scriptVectors_1207 : ScrVec :=
  { id := "sc-1207", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    witness := [bytes #[2], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "MINIMALIF",
    comment := " | 0 0x20 0xf913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1208. -/
def scriptVectors_1208 : ScrVec :=
  { id := "sc-1208", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    witness := [bytes #[1,0], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "MINIMALIF",
    comment := " | 0 0x20 0xf913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1209. -/
def scriptVectors_1209 : ScrVec :=
  { id := "sc-1209", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    witness := [bytes #[], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := " | 0 0x20 0xf913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1210. -/
def scriptVectors_1210 : ScrVec :=
  { id := "sc-1210", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    witness := [bytes #[0], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "MINIMALIF",
    comment := " | 0 0x20 0xf913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1211. -/
def scriptVectors_1211 : ScrVec :=
  { id := "sc-1211", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    witness := [bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := " | 0 0x20 0xf913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1212. -/
def scriptVectors_1212 : ScrVec :=
  { id := "sc-1212", scriptSig := bytes #[],
    scriptPubKey := bytes #[0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    witness := [bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := " | 0 0x20 0xf913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1213. -/
def scriptVectors_1213 : ScrVec :=
  { id := "sc-1213", scriptSig := bytes #[34,0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    scriptPubKey := bytes #[169,20,155,39,238,109,144,16,194,27,248,55,179,52,208,67,190,93,21,14,123,167,135],
    witness := [bytes #[1], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x22 0x0020c7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d | HASH160 0x14 0x9b27ee6d9010c21bf837b334d043be5d150e7ba7 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1214. -/
def scriptVectors_1214 : ScrVec :=
  { id := "sc-1214", scriptSig := bytes #[34,0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    scriptPubKey := bytes #[169,20,155,39,238,109,144,16,194,27,248,55,179,52,208,67,190,93,21,14,123,167,135],
    witness := [bytes #[2], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x22 0x0020c7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d | HASH160 0x14 0x9b27ee6d9010c21bf837b334d043be5d150e7ba7 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1215. -/
def scriptVectors_1215 : ScrVec :=
  { id := "sc-1215", scriptSig := bytes #[34,0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    scriptPubKey := bytes #[169,20,155,39,238,109,144,16,194,27,248,55,179,52,208,67,190,93,21,14,123,167,135],
    witness := [bytes #[1,0], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x22 0x0020c7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d | HASH160 0x14 0x9b27ee6d9010c21bf837b334d043be5d150e7ba7 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1216. -/
def scriptVectors_1216 : ScrVec :=
  { id := "sc-1216", scriptSig := bytes #[34,0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    scriptPubKey := bytes #[169,20,155,39,238,109,144,16,194,27,248,55,179,52,208,67,190,93,21,14,123,167,135],
    witness := [bytes #[], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := "0x22 0x0020c7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d | HASH160 0x14 0x9b27ee6d9010c21bf837b334d043be5d150e7ba7 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1217. -/
def scriptVectors_1217 : ScrVec :=
  { id := "sc-1217", scriptSig := bytes #[34,0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    scriptPubKey := bytes #[169,20,155,39,238,109,144,16,194,27,248,55,179,52,208,67,190,93,21,14,123,167,135],
    witness := [bytes #[0], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := "0x22 0x0020c7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d | HASH160 0x14 0x9b27ee6d9010c21bf837b334d043be5d150e7ba7 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1218. -/
def scriptVectors_1218 : ScrVec :=
  { id := "sc-1218", scriptSig := bytes #[34,0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    scriptPubKey := bytes #[169,20,155,39,238,109,144,16,194,27,248,55,179,52,208,67,190,93,21,14,123,167,135],
    witness := [bytes #[1], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := "0x22 0x0020c7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d | HASH160 0x14 0x9b27ee6d9010c21bf837b334d043be5d150e7ba7 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1219. -/
def scriptVectors_1219 : ScrVec :=
  { id := "sc-1219", scriptSig := bytes #[34,0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    scriptPubKey := bytes #[169,20,155,39,238,109,144,16,194,27,248,55,179,52,208,67,190,93,21,14,123,167,135],
    witness := [bytes #[2], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "MINIMALIF",
    comment := "0x22 0x0020c7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d | HASH160 0x14 0x9b27ee6d9010c21bf837b334d043be5d150e7ba7 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1220. -/
def scriptVectors_1220 : ScrVec :=
  { id := "sc-1220", scriptSig := bytes #[34,0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    scriptPubKey := bytes #[169,20,155,39,238,109,144,16,194,27,248,55,179,52,208,67,190,93,21,14,123,167,135],
    witness := [bytes #[1,0], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "MINIMALIF",
    comment := "0x22 0x0020c7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d | HASH160 0x14 0x9b27ee6d9010c21bf837b334d043be5d150e7ba7 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1221. -/
def scriptVectors_1221 : ScrVec :=
  { id := "sc-1221", scriptSig := bytes #[34,0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    scriptPubKey := bytes #[169,20,155,39,238,109,144,16,194,27,248,55,179,52,208,67,190,93,21,14,123,167,135],
    witness := [bytes #[], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := "0x22 0x0020c7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d | HASH160 0x14 0x9b27ee6d9010c21bf837b334d043be5d150e7ba7 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1222. -/
def scriptVectors_1222 : ScrVec :=
  { id := "sc-1222", scriptSig := bytes #[34,0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    scriptPubKey := bytes #[169,20,155,39,238,109,144,16,194,27,248,55,179,52,208,67,190,93,21,14,123,167,135],
    witness := [bytes #[0], bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "MINIMALIF",
    comment := "0x22 0x0020c7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d | HASH160 0x14 0x9b27ee6d9010c21bf837b334d043be5d150e7ba7 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1223. -/
def scriptVectors_1223 : ScrVec :=
  { id := "sc-1223", scriptSig := bytes #[34,0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    scriptPubKey := bytes #[169,20,155,39,238,109,144,16,194,27,248,55,179,52,208,67,190,93,21,14,123,167,135],
    witness := [bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "0x22 0x0020c7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d | HASH160 0x14 0x9b27ee6d9010c21bf837b334d043be5d150e7ba7 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1224. -/
def scriptVectors_1224 : ScrVec :=
  { id := "sc-1224", scriptSig := bytes #[34,0,32,199,234,240,109,90,224,26,88,227,118,225,38,235,30,111,171,32,54,7,105,34,185,107,39,17,255,190,193,229,144,102,93],
    scriptPubKey := bytes #[169,20,155,39,238,109,144,16,194,27,248,55,179,52,208,67,190,93,21,14,123,167,135],
    witness := [bytes #[99,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "0x22 0x0020c7eaf06d5ae01a58e376e126eb1e6fab2036076922b96b2711ffbec1e590665d | HASH160 0x14 0x9b27ee6d9010c21bf837b334d043be5d150e7ba7 EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1225. -/
def scriptVectors_1225 : ScrVec :=
  { id := "sc-1225", scriptSig := bytes #[34,0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    scriptPubKey := bytes #[169,20,219,183,209,192,165,107,122,156,66,51,0,200,204,166,230,224,101,186,241,220,135],
    witness := [bytes #[1], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := "0x22 0x0020f913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8 | HASH160 0x14 0xdbb7d1c0a56b7a9c423300c8cca6e6e065baf1dc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1226. -/
def scriptVectors_1226 : ScrVec :=
  { id := "sc-1226", scriptSig := bytes #[34,0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    scriptPubKey := bytes #[169,20,219,183,209,192,165,107,122,156,66,51,0,200,204,166,230,224,101,186,241,220,135],
    witness := [bytes #[2], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := "0x22 0x0020f913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8 | HASH160 0x14 0xdbb7d1c0a56b7a9c423300c8cca6e6e065baf1dc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1227. -/
def scriptVectors_1227 : ScrVec :=
  { id := "sc-1227", scriptSig := bytes #[34,0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    scriptPubKey := bytes #[169,20,219,183,209,192,165,107,122,156,66,51,0,200,204,166,230,224,101,186,241,220,135],
    witness := [bytes #[1,0], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := "0x22 0x0020f913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8 | HASH160 0x14 0xdbb7d1c0a56b7a9c423300c8cca6e6e065baf1dc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1228. -/
def scriptVectors_1228 : ScrVec :=
  { id := "sc-1228", scriptSig := bytes #[34,0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    scriptPubKey := bytes #[169,20,219,183,209,192,165,107,122,156,66,51,0,200,204,166,230,224,101,186,241,220,135],
    witness := [bytes #[], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x22 0x0020f913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8 | HASH160 0x14 0xdbb7d1c0a56b7a9c423300c8cca6e6e065baf1dc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1229. -/
def scriptVectors_1229 : ScrVec :=
  { id := "sc-1229", scriptSig := bytes #[34,0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    scriptPubKey := bytes #[169,20,219,183,209,192,165,107,122,156,66,51,0,200,204,166,230,224,101,186,241,220,135],
    witness := [bytes #[0], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "0x22 0x0020f913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8 | HASH160 0x14 0xdbb7d1c0a56b7a9c423300c8cca6e6e065baf1dc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1230. -/
def scriptVectors_1230 : ScrVec :=
  { id := "sc-1230", scriptSig := bytes #[34,0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    scriptPubKey := bytes #[169,20,219,183,209,192,165,107,122,156,66,51,0,200,204,166,230,224,101,186,241,220,135],
    witness := [bytes #[1], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "CLEANSTACK",
    comment := "0x22 0x0020f913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8 | HASH160 0x14 0xdbb7d1c0a56b7a9c423300c8cca6e6e065baf1dc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1231. -/
def scriptVectors_1231 : ScrVec :=
  { id := "sc-1231", scriptSig := bytes #[34,0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    scriptPubKey := bytes #[169,20,219,183,209,192,165,107,122,156,66,51,0,200,204,166,230,224,101,186,241,220,135],
    witness := [bytes #[2], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "MINIMALIF",
    comment := "0x22 0x0020f913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8 | HASH160 0x14 0xdbb7d1c0a56b7a9c423300c8cca6e6e065baf1dc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1232. -/
def scriptVectors_1232 : ScrVec :=
  { id := "sc-1232", scriptSig := bytes #[34,0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    scriptPubKey := bytes #[169,20,219,183,209,192,165,107,122,156,66,51,0,200,204,166,230,224,101,186,241,220,135],
    witness := [bytes #[1,0], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "MINIMALIF",
    comment := "0x22 0x0020f913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8 | HASH160 0x14 0xdbb7d1c0a56b7a9c423300c8cca6e6e065baf1dc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1233. -/
def scriptVectors_1233 : ScrVec :=
  { id := "sc-1233", scriptSig := bytes #[34,0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    scriptPubKey := bytes #[169,20,219,183,209,192,165,107,122,156,66,51,0,200,204,166,230,224,101,186,241,220,135],
    witness := [bytes #[], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := true, expectedError := "OK",
    comment := "0x22 0x0020f913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8 | HASH160 0x14 0xdbb7d1c0a56b7a9c423300c8cca6e6e065baf1dc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1234. -/
def scriptVectors_1234 : ScrVec :=
  { id := "sc-1234", scriptSig := bytes #[34,0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    scriptPubKey := bytes #[169,20,219,183,209,192,165,107,122,156,66,51,0,200,204,166,230,224,101,186,241,220,135],
    witness := [bytes #[0], bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "MINIMALIF",
    comment := "0x22 0x0020f913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8 | HASH160 0x14 0xdbb7d1c0a56b7a9c423300c8cca6e6e065baf1dc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1235. -/
def scriptVectors_1235 : ScrVec :=
  { id := "sc-1235", scriptSig := bytes #[34,0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    scriptPubKey := bytes #[169,20,219,183,209,192,165,107,122,156,66,51,0,200,204,166,230,224,101,186,241,220,135],
    witness := [bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "0x22 0x0020f913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8 | HASH160 0x14 0xdbb7d1c0a56b7a9c423300c8cca6e6e065baf1dc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1236. -/
def scriptVectors_1236 : ScrVec :=
  { id := "sc-1236", scriptSig := bytes #[34,0,32,249,19,234,207,46,56,165,214,252,58,131,17,215,42,231,4,203,131,134,99,80,169,132,221,62,94,183,109,42,140,40,232],
    scriptPubKey := bytes #[169,20,219,183,209,192,165,107,122,156,66,51,0,200,204,166,230,224,101,186,241,220,135],
    witness := [bytes #[100,81,104]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := false }, policyFlags := "MINIMALIF",
    expectOk := false, expectedError := "INVALID_STACK_OPERATION",
    comment := "0x22 0x0020f913eacf2e38a5d6fc3a8311d72ae704cb83866350a984dd3e5eb76d2a8c28e8 | HASH160 0x14 0xdbb7d1c0a56b7a9c423300c8cca6e6e065baf1dc EQUAL" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1237. -/
def scriptVectors_1237 : ScrVec :=
  { id := "sc-1237", scriptSig := bytes #[],
    scriptPubKey := bytes #[81,32,122,248,89,125,16,240,202,50,250,239,53,92,205,8,72,80,84,173,184,130,80,85,25,158,128,141,61,155,5,38,165,196],
    witness := [bytes #[31,254,18,52,86,120,144], bytes #[0], bytes #[170,118,167,117,118,117,107,170,118,117,107,108], bytes #[193,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := true }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "TAPSCRIPT Tests testing tapscript with many different op codes including ALTSTACK interactions" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1238. -/
def scriptVectors_1238 : ScrVec :=
  { id := "sc-1238", scriptSig := bytes #[],
    scriptPubKey := bytes #[81,32,51,232,60,122,185,231,240,207,206,83,234,101,3,28,172,161,46,162,155,93,17,46,0,171,79,249,90,200,204,109,170,4],
    witness := [bytes #[171,205,239], bytes #[81,99,168,104,130,124,117,1,32,135], bytes #[192,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := true }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "TAPSCRIPT Test IF conditional when true" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1239. -/
def scriptVectors_1239 : ScrVec :=
  { id := "sc-1239", scriptSig := bytes #[],
    scriptPubKey := bytes #[81,32,64,97,66,81,242,156,127,198,236,74,60,130,7,111,252,130,73,7,198,61,64,233,71,234,84,213,179,91,43,224,170,151],
    witness := [bytes #[171,205,239], bytes #[0,99,168,104,130,124,117,1,32,135], bytes #[192,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := true }, policyFlags := "",
    expectOk := false, expectedError := "EVAL_FALSE",
    comment := "TAPSCRIPT Test IF conditional when false" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1240. -/
def scriptVectors_1240 : ScrVec :=
  { id := "sc-1240", scriptSig := bytes #[],
    scriptPubKey := bytes #[81,32,230,5,30,170,8,67,73,160,173,162,26,52,208,24,49,178,24,146,181,158,19,11,223,175,238,83,61,148,99,209,14,244],
    witness := [bytes #[170], bytes #[187], bytes #[204], bytes #[135,99,117,117,104], bytes #[192,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := true }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "TAPSCRIPT Test that DROP operations do not execute inside of a false IF conditional" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1241. -/
def scriptVectors_1241 : ScrVec :=
  { id := "sc-1241", scriptSig := bytes #[],
    scriptPubKey := bytes #[81,32,153,210,121,68,70,102,224,227,125,89,12,100,92,2,100,196,222,221,59,86,250,115,224,196,200,17,176,53,199,27,138,153],
    witness := [bytes #[0], bytes #[99,81,104], bytes #[193,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := true }, policyFlags := "",
    expectOk := false, expectedError := "TAPSCRIPT_MINIMALIF",
    comment := "TAPSCRIPT Test that OP_IF with 1-byte vector 0x00 must fail with TAPSCRIPT_MINIMALIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1242. -/
def scriptVectors_1242 : ScrVec :=
  { id := "sc-1242", scriptSig := bytes #[],
    scriptPubKey := bytes #[81,32,88,27,24,36,246,238,28,245,27,249,115,78,164,137,135,240,0,253,248,227,107,73,79,81,122,2,25,91,197,77,53,61],
    witness := [bytes #[0], bytes #[100,81,104], bytes #[192,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := true }, policyFlags := "",
    expectOk := false, expectedError := "TAPSCRIPT_MINIMALIF",
    comment := "TAPSCRIPT Test that OP_NOTIF with 1-byte vector 0x00 must fail with TAPSCRIPT_MINIMALIF" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1243. -/
def scriptVectors_1243 : ScrVec :=
  { id := "sc-1243", scriptSig := bytes #[],
    scriptPubKey := bytes #[81,32,175,135,145,170,133,120,201,6,14,146,150,43,126,135,181,83,88,149,72,225,61,75,179,137,221,190,222,66,183,95,90,180],
    witness := [bytes #[170], bytes #[0,172], bytes #[192,121,190,102,126,249,220,187,172,85,160,98,149,206,135,11,7,2,155,252,219,45,206,40,217,89,242,129,91,22,248,23,152]],
    value := 1,
    flags := { p2sh := true, dersig := false, cltv := false, csv := false, nullDummy := false, witness := true, taproot := true }, policyFlags := "",
    expectOk := false, expectedError := "TAPSCRIPT_EMPTY_PUBKEY",
    comment := "TAPSCRIPT: OP_CHECKSIG with empty pubkey must fail" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1244. -/
def scriptVectors_1244 : ScrVec :=
  { id := "sc-1244", scriptSig := bytes #[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    scriptPubKey := bytes #[1,20,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,1,20,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 and NULLFAIL-compliant" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1245. -/
def scriptVectors_1245 : ScrVec :=
  { id := "sc-1245", scriptSig := bytes #[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    scriptPubKey := bytes #[1,20,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,1,20,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "NULLFAIL",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 and NULLFAIL-compliant" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1246. -/
def scriptVectors_1246 : ScrVec :=
  { id := "sc-1246", scriptSig := bytes #[81,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    scriptPubKey := bytes #[1,20,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,1,20,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "NULLFAIL",
    expectOk := true, expectedError := "OK",
    comment := "BIP66 and NULLFAIL-compliant, not NULLDUMMY-compliant" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1247. -/
def scriptVectors_1247 : ScrVec :=
  { id := "sc-1247", scriptSig := bytes #[81,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    scriptPubKey := bytes #[1,20,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,1,20,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := true, witness := false, taproot := false }, policyFlags := "NULLFAIL",
    expectOk := false, expectedError := "SIG_NULLDUMMY",
    comment := "BIP66 and NULLFAIL-compliant, not NULLDUMMY-compliant" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1248. -/
def scriptVectors_1248 : ScrVec :=
  { id := "sc-1248", scriptSig := bytes #[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,48,6,2,1,1,2,1,1,1],
    scriptPubKey := bytes #[1,20,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,1,20,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "BIP66-compliant but not NULLFAIL-compliant" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1249. -/
def scriptVectors_1249 : ScrVec :=
  { id := "sc-1249", scriptSig := bytes #[0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,9,48,6,2,1,1,2,1,1,1],
    scriptPubKey := bytes #[1,20,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,1,20,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "NULLFAIL",
    expectOk := false, expectedError := "NULLFAIL",
    comment := "BIP66-compliant but not NULLFAIL-compliant" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1250. -/
def scriptVectors_1250 : ScrVec :=
  { id := "sc-1250", scriptSig := bytes #[0,9,48,6,2,1,1,2,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    scriptPubKey := bytes #[1,20,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,1,20,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "BIP66-compliant but not NULLFAIL-compliant" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1251. -/
def scriptVectors_1251 : ScrVec :=
  { id := "sc-1251", scriptSig := bytes #[0,9,48,6,2,1,1,2,1,1,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0],
    scriptPubKey := bytes #[1,20,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,81,1,20,174,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := true, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "NULLFAIL",
    expectOk := false, expectedError := "NULLFAIL",
    comment := "BIP66-compliant but not NULLFAIL-compliant" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1252. -/
def scriptVectors_1252 : ScrVec :=
  { id := "sc-1252", scriptSig := bytes #[81],
    scriptPubKey := bytes #[171],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "CONST_SCRIPTCODE",
    expectOk := false, expectedError := "OP_CODESEPARATOR",
    comment := "OP_CODESEPARATOR in an executed pre-segwit script" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1253. -/
def scriptVectors_1253 : ScrVec :=
  { id := "sc-1253", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,171,104,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "CONST_SCRIPTCODE",
    expectOk := false, expectedError := "OP_CODESEPARATOR",
    comment := "OP_CODESEPARATOR is rejected even in an unexecuted branch" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1254. -/
def scriptVectors_1254 : ScrVec :=
  { id := "sc-1254", scriptSig := bytes #[0],
    scriptPubKey := bytes #[99,171,104,81],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Without CONST_SCRIPTCODE, OP_CODESEPARATOR in an unexecuted branch is allowed" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1255. -/
def scriptVectors_1255 : ScrVec :=
  { id := "sc-1255", scriptSig := bytes #[2,0,1],
    scriptPubKey := bytes #[2,0,1,117,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "CONST_SCRIPTCODE",
    expectOk := false, expectedError := "SIG_FINDANDDELETE",
    comment := "CHECKSIG fails when the signature push is found in the scriptCode" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1256. -/
def scriptVectors_1256 : ScrVec :=
  { id := "sc-1256", scriptSig := bytes #[0,2,0,1],
    scriptPubKey := bytes #[2,0,1,117,81,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,81,174],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "CONST_SCRIPTCODE",
    expectOk := false, expectedError := "SIG_FINDANDDELETE",
    comment := "CHECKMULTISIG fails when a signature push is found in the scriptCode" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — entry 1257. -/
def scriptVectors_1257 : ScrVec :=
  { id := "sc-1257", scriptSig := bytes #[2,0,1],
    scriptPubKey := bytes #[2,0,1,117,33,3,130,130,38,50,18,198,9,217,234,42,110,62,23,45,226,56,216,195,156,171,213,172,28,161,6,70,226,63,213,245,21,8,172,145],
    witness := [],
    value := 0,
    flags := { p2sh := false, dersig := false, cltv := false, csv := false, nullDummy := false, witness := false, taproot := false }, policyFlags := "",
    expectOk := true, expectedError := "OK",
    comment := "Without CONST_SCRIPTCODE, FindAndDelete silently drops the signature push from the scriptCode" }

/-- script_tests.json @ the pinned Core commit: 1258 vector rows. — full corpus list. -/
def scriptVectors : List ScrVec := [
  scriptVectors_0000,
  scriptVectors_0001,
  scriptVectors_0002,
  scriptVectors_0003,
  scriptVectors_0004,
  scriptVectors_0005,
  scriptVectors_0006,
  scriptVectors_0007,
  scriptVectors_0008,
  scriptVectors_0009,
  scriptVectors_0010,
  scriptVectors_0011,
  scriptVectors_0012,
  scriptVectors_0013,
  scriptVectors_0014,
  scriptVectors_0015,
  scriptVectors_0016,
  scriptVectors_0017,
  scriptVectors_0018,
  scriptVectors_0019,
  scriptVectors_0020,
  scriptVectors_0021,
  scriptVectors_0022,
  scriptVectors_0023,
  scriptVectors_0024,
  scriptVectors_0025,
  scriptVectors_0026,
  scriptVectors_0027,
  scriptVectors_0028,
  scriptVectors_0029,
  scriptVectors_0030,
  scriptVectors_0031,
  scriptVectors_0032,
  scriptVectors_0033,
  scriptVectors_0034,
  scriptVectors_0035,
  scriptVectors_0036,
  scriptVectors_0037,
  scriptVectors_0038,
  scriptVectors_0039,
  scriptVectors_0040,
  scriptVectors_0041,
  scriptVectors_0042,
  scriptVectors_0043,
  scriptVectors_0044,
  scriptVectors_0045,
  scriptVectors_0046,
  scriptVectors_0047,
  scriptVectors_0048,
  scriptVectors_0049,
  scriptVectors_0050,
  scriptVectors_0051,
  scriptVectors_0052,
  scriptVectors_0053,
  scriptVectors_0054,
  scriptVectors_0055,
  scriptVectors_0056,
  scriptVectors_0057,
  scriptVectors_0058,
  scriptVectors_0059,
  scriptVectors_0060,
  scriptVectors_0061,
  scriptVectors_0062,
  scriptVectors_0063,
  scriptVectors_0064,
  scriptVectors_0065,
  scriptVectors_0066,
  scriptVectors_0067,
  scriptVectors_0068,
  scriptVectors_0069,
  scriptVectors_0070,
  scriptVectors_0071,
  scriptVectors_0072,
  scriptVectors_0073,
  scriptVectors_0074,
  scriptVectors_0075,
  scriptVectors_0076,
  scriptVectors_0077,
  scriptVectors_0078,
  scriptVectors_0079,
  scriptVectors_0080,
  scriptVectors_0081,
  scriptVectors_0082,
  scriptVectors_0083,
  scriptVectors_0084,
  scriptVectors_0085,
  scriptVectors_0086,
  scriptVectors_0087,
  scriptVectors_0088,
  scriptVectors_0089,
  scriptVectors_0090,
  scriptVectors_0091,
  scriptVectors_0092,
  scriptVectors_0093,
  scriptVectors_0094,
  scriptVectors_0095,
  scriptVectors_0096,
  scriptVectors_0097,
  scriptVectors_0098,
  scriptVectors_0099,
  scriptVectors_0100,
  scriptVectors_0101,
  scriptVectors_0102,
  scriptVectors_0103,
  scriptVectors_0104,
  scriptVectors_0105,
  scriptVectors_0106,
  scriptVectors_0107,
  scriptVectors_0108,
  scriptVectors_0109,
  scriptVectors_0110,
  scriptVectors_0111,
  scriptVectors_0112,
  scriptVectors_0113,
  scriptVectors_0114,
  scriptVectors_0115,
  scriptVectors_0116,
  scriptVectors_0117,
  scriptVectors_0118,
  scriptVectors_0119,
  scriptVectors_0120,
  scriptVectors_0121,
  scriptVectors_0122,
  scriptVectors_0123,
  scriptVectors_0124,
  scriptVectors_0125,
  scriptVectors_0126,
  scriptVectors_0127,
  scriptVectors_0128,
  scriptVectors_0129,
  scriptVectors_0130,
  scriptVectors_0131,
  scriptVectors_0132,
  scriptVectors_0133,
  scriptVectors_0134,
  scriptVectors_0135,
  scriptVectors_0136,
  scriptVectors_0137,
  scriptVectors_0138,
  scriptVectors_0139,
  scriptVectors_0140,
  scriptVectors_0141,
  scriptVectors_0142,
  scriptVectors_0143,
  scriptVectors_0144,
  scriptVectors_0145,
  scriptVectors_0146,
  scriptVectors_0147,
  scriptVectors_0148,
  scriptVectors_0149,
  scriptVectors_0150,
  scriptVectors_0151,
  scriptVectors_0152,
  scriptVectors_0153,
  scriptVectors_0154,
  scriptVectors_0155,
  scriptVectors_0156,
  scriptVectors_0157,
  scriptVectors_0158,
  scriptVectors_0159,
  scriptVectors_0160,
  scriptVectors_0161,
  scriptVectors_0162,
  scriptVectors_0163,
  scriptVectors_0164,
  scriptVectors_0165,
  scriptVectors_0166,
  scriptVectors_0167,
  scriptVectors_0168,
  scriptVectors_0169,
  scriptVectors_0170,
  scriptVectors_0171,
  scriptVectors_0172,
  scriptVectors_0173,
  scriptVectors_0174,
  scriptVectors_0175,
  scriptVectors_0176,
  scriptVectors_0177,
  scriptVectors_0178,
  scriptVectors_0179,
  scriptVectors_0180,
  scriptVectors_0181,
  scriptVectors_0182,
  scriptVectors_0183,
  scriptVectors_0184,
  scriptVectors_0185,
  scriptVectors_0186,
  scriptVectors_0187,
  scriptVectors_0188,
  scriptVectors_0189,
  scriptVectors_0190,
  scriptVectors_0191,
  scriptVectors_0192,
  scriptVectors_0193,
  scriptVectors_0194,
  scriptVectors_0195,
  scriptVectors_0196,
  scriptVectors_0197,
  scriptVectors_0198,
  scriptVectors_0199,
  scriptVectors_0200,
  scriptVectors_0201,
  scriptVectors_0202,
  scriptVectors_0203,
  scriptVectors_0204,
  scriptVectors_0205,
  scriptVectors_0206,
  scriptVectors_0207,
  scriptVectors_0208,
  scriptVectors_0209,
  scriptVectors_0210,
  scriptVectors_0211,
  scriptVectors_0212,
  scriptVectors_0213,
  scriptVectors_0214,
  scriptVectors_0215,
  scriptVectors_0216,
  scriptVectors_0217,
  scriptVectors_0218,
  scriptVectors_0219,
  scriptVectors_0220,
  scriptVectors_0221,
  scriptVectors_0222,
  scriptVectors_0223,
  scriptVectors_0224,
  scriptVectors_0225,
  scriptVectors_0226,
  scriptVectors_0227,
  scriptVectors_0228,
  scriptVectors_0229,
  scriptVectors_0230,
  scriptVectors_0231,
  scriptVectors_0232,
  scriptVectors_0233,
  scriptVectors_0234,
  scriptVectors_0235,
  scriptVectors_0236,
  scriptVectors_0237,
  scriptVectors_0238,
  scriptVectors_0239,
  scriptVectors_0240,
  scriptVectors_0241,
  scriptVectors_0242,
  scriptVectors_0243,
  scriptVectors_0244,
  scriptVectors_0245,
  scriptVectors_0246,
  scriptVectors_0247,
  scriptVectors_0248,
  scriptVectors_0249,
  scriptVectors_0250,
  scriptVectors_0251,
  scriptVectors_0252,
  scriptVectors_0253,
  scriptVectors_0254,
  scriptVectors_0255,
  scriptVectors_0256,
  scriptVectors_0257,
  scriptVectors_0258,
  scriptVectors_0259,
  scriptVectors_0260,
  scriptVectors_0261,
  scriptVectors_0262,
  scriptVectors_0263,
  scriptVectors_0264,
  scriptVectors_0265,
  scriptVectors_0266,
  scriptVectors_0267,
  scriptVectors_0268,
  scriptVectors_0269,
  scriptVectors_0270,
  scriptVectors_0271,
  scriptVectors_0272,
  scriptVectors_0273,
  scriptVectors_0274,
  scriptVectors_0275,
  scriptVectors_0276,
  scriptVectors_0277,
  scriptVectors_0278,
  scriptVectors_0279,
  scriptVectors_0280,
  scriptVectors_0281,
  scriptVectors_0282,
  scriptVectors_0283,
  scriptVectors_0284,
  scriptVectors_0285,
  scriptVectors_0286,
  scriptVectors_0287,
  scriptVectors_0288,
  scriptVectors_0289,
  scriptVectors_0290,
  scriptVectors_0291,
  scriptVectors_0292,
  scriptVectors_0293,
  scriptVectors_0294,
  scriptVectors_0295,
  scriptVectors_0296,
  scriptVectors_0297,
  scriptVectors_0298,
  scriptVectors_0299,
  scriptVectors_0300,
  scriptVectors_0301,
  scriptVectors_0302,
  scriptVectors_0303,
  scriptVectors_0304,
  scriptVectors_0305,
  scriptVectors_0306,
  scriptVectors_0307,
  scriptVectors_0308,
  scriptVectors_0309,
  scriptVectors_0310,
  scriptVectors_0311,
  scriptVectors_0312,
  scriptVectors_0313,
  scriptVectors_0314,
  scriptVectors_0315,
  scriptVectors_0316,
  scriptVectors_0317,
  scriptVectors_0318,
  scriptVectors_0319,
  scriptVectors_0320,
  scriptVectors_0321,
  scriptVectors_0322,
  scriptVectors_0323,
  scriptVectors_0324,
  scriptVectors_0325,
  scriptVectors_0326,
  scriptVectors_0327,
  scriptVectors_0328,
  scriptVectors_0329,
  scriptVectors_0330,
  scriptVectors_0331,
  scriptVectors_0332,
  scriptVectors_0333,
  scriptVectors_0334,
  scriptVectors_0335,
  scriptVectors_0336,
  scriptVectors_0337,
  scriptVectors_0338,
  scriptVectors_0339,
  scriptVectors_0340,
  scriptVectors_0341,
  scriptVectors_0342,
  scriptVectors_0343,
  scriptVectors_0344,
  scriptVectors_0345,
  scriptVectors_0346,
  scriptVectors_0347,
  scriptVectors_0348,
  scriptVectors_0349,
  scriptVectors_0350,
  scriptVectors_0351,
  scriptVectors_0352,
  scriptVectors_0353,
  scriptVectors_0354,
  scriptVectors_0355,
  scriptVectors_0356,
  scriptVectors_0357,
  scriptVectors_0358,
  scriptVectors_0359,
  scriptVectors_0360,
  scriptVectors_0361,
  scriptVectors_0362,
  scriptVectors_0363,
  scriptVectors_0364,
  scriptVectors_0365,
  scriptVectors_0366,
  scriptVectors_0367,
  scriptVectors_0368,
  scriptVectors_0369,
  scriptVectors_0370,
  scriptVectors_0371,
  scriptVectors_0372,
  scriptVectors_0373,
  scriptVectors_0374,
  scriptVectors_0375,
  scriptVectors_0376,
  scriptVectors_0377,
  scriptVectors_0378,
  scriptVectors_0379,
  scriptVectors_0380,
  scriptVectors_0381,
  scriptVectors_0382,
  scriptVectors_0383,
  scriptVectors_0384,
  scriptVectors_0385,
  scriptVectors_0386,
  scriptVectors_0387,
  scriptVectors_0388,
  scriptVectors_0389,
  scriptVectors_0390,
  scriptVectors_0391,
  scriptVectors_0392,
  scriptVectors_0393,
  scriptVectors_0394,
  scriptVectors_0395,
  scriptVectors_0396,
  scriptVectors_0397,
  scriptVectors_0398,
  scriptVectors_0399,
  scriptVectors_0400,
  scriptVectors_0401,
  scriptVectors_0402,
  scriptVectors_0403,
  scriptVectors_0404,
  scriptVectors_0405,
  scriptVectors_0406,
  scriptVectors_0407,
  scriptVectors_0408,
  scriptVectors_0409,
  scriptVectors_0410,
  scriptVectors_0411,
  scriptVectors_0412,
  scriptVectors_0413,
  scriptVectors_0414,
  scriptVectors_0415,
  scriptVectors_0416,
  scriptVectors_0417,
  scriptVectors_0418,
  scriptVectors_0419,
  scriptVectors_0420,
  scriptVectors_0421,
  scriptVectors_0422,
  scriptVectors_0423,
  scriptVectors_0424,
  scriptVectors_0425,
  scriptVectors_0426,
  scriptVectors_0427,
  scriptVectors_0428,
  scriptVectors_0429,
  scriptVectors_0430,
  scriptVectors_0431,
  scriptVectors_0432,
  scriptVectors_0433,
  scriptVectors_0434,
  scriptVectors_0435,
  scriptVectors_0436,
  scriptVectors_0437,
  scriptVectors_0438,
  scriptVectors_0439,
  scriptVectors_0440,
  scriptVectors_0441,
  scriptVectors_0442,
  scriptVectors_0443,
  scriptVectors_0444,
  scriptVectors_0445,
  scriptVectors_0446,
  scriptVectors_0447,
  scriptVectors_0448,
  scriptVectors_0449,
  scriptVectors_0450,
  scriptVectors_0451,
  scriptVectors_0452,
  scriptVectors_0453,
  scriptVectors_0454,
  scriptVectors_0455,
  scriptVectors_0456,
  scriptVectors_0457,
  scriptVectors_0458,
  scriptVectors_0459,
  scriptVectors_0460,
  scriptVectors_0461,
  scriptVectors_0462,
  scriptVectors_0463,
  scriptVectors_0464,
  scriptVectors_0465,
  scriptVectors_0466,
  scriptVectors_0467,
  scriptVectors_0468,
  scriptVectors_0469,
  scriptVectors_0470,
  scriptVectors_0471,
  scriptVectors_0472,
  scriptVectors_0473,
  scriptVectors_0474,
  scriptVectors_0475,
  scriptVectors_0476,
  scriptVectors_0477,
  scriptVectors_0478,
  scriptVectors_0479,
  scriptVectors_0480,
  scriptVectors_0481,
  scriptVectors_0482,
  scriptVectors_0483,
  scriptVectors_0484,
  scriptVectors_0485,
  scriptVectors_0486,
  scriptVectors_0487,
  scriptVectors_0488,
  scriptVectors_0489,
  scriptVectors_0490,
  scriptVectors_0491,
  scriptVectors_0492,
  scriptVectors_0493,
  scriptVectors_0494,
  scriptVectors_0495,
  scriptVectors_0496,
  scriptVectors_0497,
  scriptVectors_0498,
  scriptVectors_0499,
  scriptVectors_0500,
  scriptVectors_0501,
  scriptVectors_0502,
  scriptVectors_0503,
  scriptVectors_0504,
  scriptVectors_0505,
  scriptVectors_0506,
  scriptVectors_0507,
  scriptVectors_0508,
  scriptVectors_0509,
  scriptVectors_0510,
  scriptVectors_0511,
  scriptVectors_0512,
  scriptVectors_0513,
  scriptVectors_0514,
  scriptVectors_0515,
  scriptVectors_0516,
  scriptVectors_0517,
  scriptVectors_0518,
  scriptVectors_0519,
  scriptVectors_0520,
  scriptVectors_0521,
  scriptVectors_0522,
  scriptVectors_0523,
  scriptVectors_0524,
  scriptVectors_0525,
  scriptVectors_0526,
  scriptVectors_0527,
  scriptVectors_0528,
  scriptVectors_0529,
  scriptVectors_0530,
  scriptVectors_0531,
  scriptVectors_0532,
  scriptVectors_0533,
  scriptVectors_0534,
  scriptVectors_0535,
  scriptVectors_0536,
  scriptVectors_0537,
  scriptVectors_0538,
  scriptVectors_0539,
  scriptVectors_0540,
  scriptVectors_0541,
  scriptVectors_0542,
  scriptVectors_0543,
  scriptVectors_0544,
  scriptVectors_0545,
  scriptVectors_0546,
  scriptVectors_0547,
  scriptVectors_0548,
  scriptVectors_0549,
  scriptVectors_0550,
  scriptVectors_0551,
  scriptVectors_0552,
  scriptVectors_0553,
  scriptVectors_0554,
  scriptVectors_0555,
  scriptVectors_0556,
  scriptVectors_0557,
  scriptVectors_0558,
  scriptVectors_0559,
  scriptVectors_0560,
  scriptVectors_0561,
  scriptVectors_0562,
  scriptVectors_0563,
  scriptVectors_0564,
  scriptVectors_0565,
  scriptVectors_0566,
  scriptVectors_0567,
  scriptVectors_0568,
  scriptVectors_0569,
  scriptVectors_0570,
  scriptVectors_0571,
  scriptVectors_0572,
  scriptVectors_0573,
  scriptVectors_0574,
  scriptVectors_0575,
  scriptVectors_0576,
  scriptVectors_0577,
  scriptVectors_0578,
  scriptVectors_0579,
  scriptVectors_0580,
  scriptVectors_0581,
  scriptVectors_0582,
  scriptVectors_0583,
  scriptVectors_0584,
  scriptVectors_0585,
  scriptVectors_0586,
  scriptVectors_0587,
  scriptVectors_0588,
  scriptVectors_0589,
  scriptVectors_0590,
  scriptVectors_0591,
  scriptVectors_0592,
  scriptVectors_0593,
  scriptVectors_0594,
  scriptVectors_0595,
  scriptVectors_0596,
  scriptVectors_0597,
  scriptVectors_0598,
  scriptVectors_0599,
  scriptVectors_0600,
  scriptVectors_0601,
  scriptVectors_0602,
  scriptVectors_0603,
  scriptVectors_0604,
  scriptVectors_0605,
  scriptVectors_0606,
  scriptVectors_0607,
  scriptVectors_0608,
  scriptVectors_0609,
  scriptVectors_0610,
  scriptVectors_0611,
  scriptVectors_0612,
  scriptVectors_0613,
  scriptVectors_0614,
  scriptVectors_0615,
  scriptVectors_0616,
  scriptVectors_0617,
  scriptVectors_0618,
  scriptVectors_0619,
  scriptVectors_0620,
  scriptVectors_0621,
  scriptVectors_0622,
  scriptVectors_0623,
  scriptVectors_0624,
  scriptVectors_0625,
  scriptVectors_0626,
  scriptVectors_0627,
  scriptVectors_0628,
  scriptVectors_0629,
  scriptVectors_0630,
  scriptVectors_0631,
  scriptVectors_0632,
  scriptVectors_0633,
  scriptVectors_0634,
  scriptVectors_0635,
  scriptVectors_0636,
  scriptVectors_0637,
  scriptVectors_0638,
  scriptVectors_0639,
  scriptVectors_0640,
  scriptVectors_0641,
  scriptVectors_0642,
  scriptVectors_0643,
  scriptVectors_0644,
  scriptVectors_0645,
  scriptVectors_0646,
  scriptVectors_0647,
  scriptVectors_0648,
  scriptVectors_0649,
  scriptVectors_0650,
  scriptVectors_0651,
  scriptVectors_0652,
  scriptVectors_0653,
  scriptVectors_0654,
  scriptVectors_0655,
  scriptVectors_0656,
  scriptVectors_0657,
  scriptVectors_0658,
  scriptVectors_0659,
  scriptVectors_0660,
  scriptVectors_0661,
  scriptVectors_0662,
  scriptVectors_0663,
  scriptVectors_0664,
  scriptVectors_0665,
  scriptVectors_0666,
  scriptVectors_0667,
  scriptVectors_0668,
  scriptVectors_0669,
  scriptVectors_0670,
  scriptVectors_0671,
  scriptVectors_0672,
  scriptVectors_0673,
  scriptVectors_0674,
  scriptVectors_0675,
  scriptVectors_0676,
  scriptVectors_0677,
  scriptVectors_0678,
  scriptVectors_0679,
  scriptVectors_0680,
  scriptVectors_0681,
  scriptVectors_0682,
  scriptVectors_0683,
  scriptVectors_0684,
  scriptVectors_0685,
  scriptVectors_0686,
  scriptVectors_0687,
  scriptVectors_0688,
  scriptVectors_0689,
  scriptVectors_0690,
  scriptVectors_0691,
  scriptVectors_0692,
  scriptVectors_0693,
  scriptVectors_0694,
  scriptVectors_0695,
  scriptVectors_0696,
  scriptVectors_0697,
  scriptVectors_0698,
  scriptVectors_0699,
  scriptVectors_0700,
  scriptVectors_0701,
  scriptVectors_0702,
  scriptVectors_0703,
  scriptVectors_0704,
  scriptVectors_0705,
  scriptVectors_0706,
  scriptVectors_0707,
  scriptVectors_0708,
  scriptVectors_0709,
  scriptVectors_0710,
  scriptVectors_0711,
  scriptVectors_0712,
  scriptVectors_0713,
  scriptVectors_0714,
  scriptVectors_0715,
  scriptVectors_0716,
  scriptVectors_0717,
  scriptVectors_0718,
  scriptVectors_0719,
  scriptVectors_0720,
  scriptVectors_0721,
  scriptVectors_0722,
  scriptVectors_0723,
  scriptVectors_0724,
  scriptVectors_0725,
  scriptVectors_0726,
  scriptVectors_0727,
  scriptVectors_0728,
  scriptVectors_0729,
  scriptVectors_0730,
  scriptVectors_0731,
  scriptVectors_0732,
  scriptVectors_0733,
  scriptVectors_0734,
  scriptVectors_0735,
  scriptVectors_0736,
  scriptVectors_0737,
  scriptVectors_0738,
  scriptVectors_0739,
  scriptVectors_0740,
  scriptVectors_0741,
  scriptVectors_0742,
  scriptVectors_0743,
  scriptVectors_0744,
  scriptVectors_0745,
  scriptVectors_0746,
  scriptVectors_0747,
  scriptVectors_0748,
  scriptVectors_0749,
  scriptVectors_0750,
  scriptVectors_0751,
  scriptVectors_0752,
  scriptVectors_0753,
  scriptVectors_0754,
  scriptVectors_0755,
  scriptVectors_0756,
  scriptVectors_0757,
  scriptVectors_0758,
  scriptVectors_0759,
  scriptVectors_0760,
  scriptVectors_0761,
  scriptVectors_0762,
  scriptVectors_0763,
  scriptVectors_0764,
  scriptVectors_0765,
  scriptVectors_0766,
  scriptVectors_0767,
  scriptVectors_0768,
  scriptVectors_0769,
  scriptVectors_0770,
  scriptVectors_0771,
  scriptVectors_0772,
  scriptVectors_0773,
  scriptVectors_0774,
  scriptVectors_0775,
  scriptVectors_0776,
  scriptVectors_0777,
  scriptVectors_0778,
  scriptVectors_0779,
  scriptVectors_0780,
  scriptVectors_0781,
  scriptVectors_0782,
  scriptVectors_0783,
  scriptVectors_0784,
  scriptVectors_0785,
  scriptVectors_0786,
  scriptVectors_0787,
  scriptVectors_0788,
  scriptVectors_0789,
  scriptVectors_0790,
  scriptVectors_0791,
  scriptVectors_0792,
  scriptVectors_0793,
  scriptVectors_0794,
  scriptVectors_0795,
  scriptVectors_0796,
  scriptVectors_0797,
  scriptVectors_0798,
  scriptVectors_0799,
  scriptVectors_0800,
  scriptVectors_0801,
  scriptVectors_0802,
  scriptVectors_0803,
  scriptVectors_0804,
  scriptVectors_0805,
  scriptVectors_0806,
  scriptVectors_0807,
  scriptVectors_0808,
  scriptVectors_0809,
  scriptVectors_0810,
  scriptVectors_0811,
  scriptVectors_0812,
  scriptVectors_0813,
  scriptVectors_0814,
  scriptVectors_0815,
  scriptVectors_0816,
  scriptVectors_0817,
  scriptVectors_0818,
  scriptVectors_0819,
  scriptVectors_0820,
  scriptVectors_0821,
  scriptVectors_0822,
  scriptVectors_0823,
  scriptVectors_0824,
  scriptVectors_0825,
  scriptVectors_0826,
  scriptVectors_0827,
  scriptVectors_0828,
  scriptVectors_0829,
  scriptVectors_0830,
  scriptVectors_0831,
  scriptVectors_0832,
  scriptVectors_0833,
  scriptVectors_0834,
  scriptVectors_0835,
  scriptVectors_0836,
  scriptVectors_0837,
  scriptVectors_0838,
  scriptVectors_0839,
  scriptVectors_0840,
  scriptVectors_0841,
  scriptVectors_0842,
  scriptVectors_0843,
  scriptVectors_0844,
  scriptVectors_0845,
  scriptVectors_0846,
  scriptVectors_0847,
  scriptVectors_0848,
  scriptVectors_0849,
  scriptVectors_0850,
  scriptVectors_0851,
  scriptVectors_0852,
  scriptVectors_0853,
  scriptVectors_0854,
  scriptVectors_0855,
  scriptVectors_0856,
  scriptVectors_0857,
  scriptVectors_0858,
  scriptVectors_0859,
  scriptVectors_0860,
  scriptVectors_0861,
  scriptVectors_0862,
  scriptVectors_0863,
  scriptVectors_0864,
  scriptVectors_0865,
  scriptVectors_0866,
  scriptVectors_0867,
  scriptVectors_0868,
  scriptVectors_0869,
  scriptVectors_0870,
  scriptVectors_0871,
  scriptVectors_0872,
  scriptVectors_0873,
  scriptVectors_0874,
  scriptVectors_0875,
  scriptVectors_0876,
  scriptVectors_0877,
  scriptVectors_0878,
  scriptVectors_0879,
  scriptVectors_0880,
  scriptVectors_0881,
  scriptVectors_0882,
  scriptVectors_0883,
  scriptVectors_0884,
  scriptVectors_0885,
  scriptVectors_0886,
  scriptVectors_0887,
  scriptVectors_0888,
  scriptVectors_0889,
  scriptVectors_0890,
  scriptVectors_0891,
  scriptVectors_0892,
  scriptVectors_0893,
  scriptVectors_0894,
  scriptVectors_0895,
  scriptVectors_0896,
  scriptVectors_0897,
  scriptVectors_0898,
  scriptVectors_0899,
  scriptVectors_0900,
  scriptVectors_0901,
  scriptVectors_0902,
  scriptVectors_0903,
  scriptVectors_0904,
  scriptVectors_0905,
  scriptVectors_0906,
  scriptVectors_0907,
  scriptVectors_0908,
  scriptVectors_0909,
  scriptVectors_0910,
  scriptVectors_0911,
  scriptVectors_0912,
  scriptVectors_0913,
  scriptVectors_0914,
  scriptVectors_0915,
  scriptVectors_0916,
  scriptVectors_0917,
  scriptVectors_0918,
  scriptVectors_0919,
  scriptVectors_0920,
  scriptVectors_0921,
  scriptVectors_0922,
  scriptVectors_0923,
  scriptVectors_0924,
  scriptVectors_0925,
  scriptVectors_0926,
  scriptVectors_0927,
  scriptVectors_0928,
  scriptVectors_0929,
  scriptVectors_0930,
  scriptVectors_0931,
  scriptVectors_0932,
  scriptVectors_0933,
  scriptVectors_0934,
  scriptVectors_0935,
  scriptVectors_0936,
  scriptVectors_0937,
  scriptVectors_0938,
  scriptVectors_0939,
  scriptVectors_0940,
  scriptVectors_0941,
  scriptVectors_0942,
  scriptVectors_0943,
  scriptVectors_0944,
  scriptVectors_0945,
  scriptVectors_0946,
  scriptVectors_0947,
  scriptVectors_0948,
  scriptVectors_0949,
  scriptVectors_0950,
  scriptVectors_0951,
  scriptVectors_0952,
  scriptVectors_0953,
  scriptVectors_0954,
  scriptVectors_0955,
  scriptVectors_0956,
  scriptVectors_0957,
  scriptVectors_0958,
  scriptVectors_0959,
  scriptVectors_0960,
  scriptVectors_0961,
  scriptVectors_0962,
  scriptVectors_0963,
  scriptVectors_0964,
  scriptVectors_0965,
  scriptVectors_0966,
  scriptVectors_0967,
  scriptVectors_0968,
  scriptVectors_0969,
  scriptVectors_0970,
  scriptVectors_0971,
  scriptVectors_0972,
  scriptVectors_0973,
  scriptVectors_0974,
  scriptVectors_0975,
  scriptVectors_0976,
  scriptVectors_0977,
  scriptVectors_0978,
  scriptVectors_0979,
  scriptVectors_0980,
  scriptVectors_0981,
  scriptVectors_0982,
  scriptVectors_0983,
  scriptVectors_0984,
  scriptVectors_0985,
  scriptVectors_0986,
  scriptVectors_0987,
  scriptVectors_0988,
  scriptVectors_0989,
  scriptVectors_0990,
  scriptVectors_0991,
  scriptVectors_0992,
  scriptVectors_0993,
  scriptVectors_0994,
  scriptVectors_0995,
  scriptVectors_0996,
  scriptVectors_0997,
  scriptVectors_0998,
  scriptVectors_0999,
  scriptVectors_1000,
  scriptVectors_1001,
  scriptVectors_1002,
  scriptVectors_1003,
  scriptVectors_1004,
  scriptVectors_1005,
  scriptVectors_1006,
  scriptVectors_1007,
  scriptVectors_1008,
  scriptVectors_1009,
  scriptVectors_1010,
  scriptVectors_1011,
  scriptVectors_1012,
  scriptVectors_1013,
  scriptVectors_1014,
  scriptVectors_1015,
  scriptVectors_1016,
  scriptVectors_1017,
  scriptVectors_1018,
  scriptVectors_1019,
  scriptVectors_1020,
  scriptVectors_1021,
  scriptVectors_1022,
  scriptVectors_1023,
  scriptVectors_1024,
  scriptVectors_1025,
  scriptVectors_1026,
  scriptVectors_1027,
  scriptVectors_1028,
  scriptVectors_1029,
  scriptVectors_1030,
  scriptVectors_1031,
  scriptVectors_1032,
  scriptVectors_1033,
  scriptVectors_1034,
  scriptVectors_1035,
  scriptVectors_1036,
  scriptVectors_1037,
  scriptVectors_1038,
  scriptVectors_1039,
  scriptVectors_1040,
  scriptVectors_1041,
  scriptVectors_1042,
  scriptVectors_1043,
  scriptVectors_1044,
  scriptVectors_1045,
  scriptVectors_1046,
  scriptVectors_1047,
  scriptVectors_1048,
  scriptVectors_1049,
  scriptVectors_1050,
  scriptVectors_1051,
  scriptVectors_1052,
  scriptVectors_1053,
  scriptVectors_1054,
  scriptVectors_1055,
  scriptVectors_1056,
  scriptVectors_1057,
  scriptVectors_1058,
  scriptVectors_1059,
  scriptVectors_1060,
  scriptVectors_1061,
  scriptVectors_1062,
  scriptVectors_1063,
  scriptVectors_1064,
  scriptVectors_1065,
  scriptVectors_1066,
  scriptVectors_1067,
  scriptVectors_1068,
  scriptVectors_1069,
  scriptVectors_1070,
  scriptVectors_1071,
  scriptVectors_1072,
  scriptVectors_1073,
  scriptVectors_1074,
  scriptVectors_1075,
  scriptVectors_1076,
  scriptVectors_1077,
  scriptVectors_1078,
  scriptVectors_1079,
  scriptVectors_1080,
  scriptVectors_1081,
  scriptVectors_1082,
  scriptVectors_1083,
  scriptVectors_1084,
  scriptVectors_1085,
  scriptVectors_1086,
  scriptVectors_1087,
  scriptVectors_1088,
  scriptVectors_1089,
  scriptVectors_1090,
  scriptVectors_1091,
  scriptVectors_1092,
  scriptVectors_1093,
  scriptVectors_1094,
  scriptVectors_1095,
  scriptVectors_1096,
  scriptVectors_1097,
  scriptVectors_1098,
  scriptVectors_1099,
  scriptVectors_1100,
  scriptVectors_1101,
  scriptVectors_1102,
  scriptVectors_1103,
  scriptVectors_1104,
  scriptVectors_1105,
  scriptVectors_1106,
  scriptVectors_1107,
  scriptVectors_1108,
  scriptVectors_1109,
  scriptVectors_1110,
  scriptVectors_1111,
  scriptVectors_1112,
  scriptVectors_1113,
  scriptVectors_1114,
  scriptVectors_1115,
  scriptVectors_1116,
  scriptVectors_1117,
  scriptVectors_1118,
  scriptVectors_1119,
  scriptVectors_1120,
  scriptVectors_1121,
  scriptVectors_1122,
  scriptVectors_1123,
  scriptVectors_1124,
  scriptVectors_1125,
  scriptVectors_1126,
  scriptVectors_1127,
  scriptVectors_1128,
  scriptVectors_1129,
  scriptVectors_1130,
  scriptVectors_1131,
  scriptVectors_1132,
  scriptVectors_1133,
  scriptVectors_1134,
  scriptVectors_1135,
  scriptVectors_1136,
  scriptVectors_1137,
  scriptVectors_1138,
  scriptVectors_1139,
  scriptVectors_1140,
  scriptVectors_1141,
  scriptVectors_1142,
  scriptVectors_1143,
  scriptVectors_1144,
  scriptVectors_1145,
  scriptVectors_1146,
  scriptVectors_1147,
  scriptVectors_1148,
  scriptVectors_1149,
  scriptVectors_1150,
  scriptVectors_1151,
  scriptVectors_1152,
  scriptVectors_1153,
  scriptVectors_1154,
  scriptVectors_1155,
  scriptVectors_1156,
  scriptVectors_1157,
  scriptVectors_1158,
  scriptVectors_1159,
  scriptVectors_1160,
  scriptVectors_1161,
  scriptVectors_1162,
  scriptVectors_1163,
  scriptVectors_1164,
  scriptVectors_1165,
  scriptVectors_1166,
  scriptVectors_1167,
  scriptVectors_1168,
  scriptVectors_1169,
  scriptVectors_1170,
  scriptVectors_1171,
  scriptVectors_1172,
  scriptVectors_1173,
  scriptVectors_1174,
  scriptVectors_1175,
  scriptVectors_1176,
  scriptVectors_1177,
  scriptVectors_1178,
  scriptVectors_1179,
  scriptVectors_1180,
  scriptVectors_1181,
  scriptVectors_1182,
  scriptVectors_1183,
  scriptVectors_1184,
  scriptVectors_1185,
  scriptVectors_1186,
  scriptVectors_1187,
  scriptVectors_1188,
  scriptVectors_1189,
  scriptVectors_1190,
  scriptVectors_1191,
  scriptVectors_1192,
  scriptVectors_1193,
  scriptVectors_1194,
  scriptVectors_1195,
  scriptVectors_1196,
  scriptVectors_1197,
  scriptVectors_1198,
  scriptVectors_1199,
  scriptVectors_1200,
  scriptVectors_1201,
  scriptVectors_1202,
  scriptVectors_1203,
  scriptVectors_1204,
  scriptVectors_1205,
  scriptVectors_1206,
  scriptVectors_1207,
  scriptVectors_1208,
  scriptVectors_1209,
  scriptVectors_1210,
  scriptVectors_1211,
  scriptVectors_1212,
  scriptVectors_1213,
  scriptVectors_1214,
  scriptVectors_1215,
  scriptVectors_1216,
  scriptVectors_1217,
  scriptVectors_1218,
  scriptVectors_1219,
  scriptVectors_1220,
  scriptVectors_1221,
  scriptVectors_1222,
  scriptVectors_1223,
  scriptVectors_1224,
  scriptVectors_1225,
  scriptVectors_1226,
  scriptVectors_1227,
  scriptVectors_1228,
  scriptVectors_1229,
  scriptVectors_1230,
  scriptVectors_1231,
  scriptVectors_1232,
  scriptVectors_1233,
  scriptVectors_1234,
  scriptVectors_1235,
  scriptVectors_1236,
  scriptVectors_1237,
  scriptVectors_1238,
  scriptVectors_1239,
  scriptVectors_1240,
  scriptVectors_1241,
  scriptVectors_1242,
  scriptVectors_1243,
  scriptVectors_1244,
  scriptVectors_1245,
  scriptVectors_1246,
  scriptVectors_1247,
  scriptVectors_1248,
  scriptVectors_1249,
  scriptVectors_1250,
  scriptVectors_1251,
  scriptVectors_1252,
  scriptVectors_1253,
  scriptVectors_1254,
  scriptVectors_1255,
  scriptVectors_1256,
  scriptVectors_1257
]

end BitcoinVectors.Gen
