import Bitcoin.Script.Parser.Interface

/-!
# W05 unit tests — decide-based vectors per opcode class

Every check is a build-time `example … := by decide` or `native_decide`
(both kernel/compiler-reduced, no IO), mirroring the C1 PoC pattern.
`native_decide` is confined to this Test-scoped file per the D2 L1
gate; it is used where the kernel's list-backed `Array`/`ByteArray`
evaluation is quadratic in the payload (≥ 256-byte pushes — `extract`
and `DecidableEq` are push-per-byte there) and would blow the heartbeat
budget. Coverage: OP_0, direct pushes (incl. the 75/76 boundary),
PUSHDATA1/2/4 (incl. length-byte truncation and > 520 acceptance),
OP_1NEGATE, OP_RESERVED, OP_1..OP_16, high opcodes, all 15 disabled
opcodes, printer boundaries, truncation failures, and the `opcodeCount`
hook for W09 (SCR-022/024).
-/

namespace Test.Script.Parser.Tests

open Bitcoin.Script.Parser

set_option maxRecDepth 10000

/-- n zero bytes as an Array (built once, reused in several vectors). -/
def azeros (n : Nat) : Array UInt8 := ⟨List.replicate n (0x00 : UInt8)⟩

/-- n zero bytes (computed, so big payloads stay readable). -/
def bzeros (n : Nat) : ByteArray := ByteArray.mk (azeros n)

/-- PUSHDATA2 header (0x4d, LE16 length) + n zero bytes. -/
def pd2 (n : Nat) : ByteArray :=
  ByteArray.mk ((#[(0x4d : UInt8), (n % 256).toUInt8, (n / 256).toUInt8]) ++ azeros n)

/-- PUSHDATA2 header *claiming* length `h`, followed by only `n ≤ h`
payload bytes (truncation vectors). -/
def pd2w (h n : Nat) : ByteArray :=
  ByteArray.mk ((#[(0x4d : UInt8), (h % 256).toUInt8, (h / 256).toUInt8]) ++ azeros n)

/-! ## Parse: immediate-opcode classes -/

example : parseFrom 1 ByteArray.empty 0 = some ([] : List Opcode) := by decide

example : parseFrom 2 (ByteArray.mk #[(0x00 : UInt8)]) 0 =
    some [Opcode.pushBytes ByteArray.empty] := by decide

example : parseFrom 2 (ByteArray.mk #[(0x4f : UInt8)]) 0 =
    some [Opcode.pushNum 0] := by decide

example : parseFrom 2 (ByteArray.mk #[(0x50 : UInt8)]) 0 =
    some [Opcode.op ⟨0x50, by decide⟩] := by decide

example : parseFrom 2 (ByteArray.mk #[(0x51 : UInt8)]) 0 =
    some [Opcode.pushNum 1] := by decide

example : parseFrom 2 (ByteArray.mk #[(0x60 : UInt8)]) 0 =
    some [Opcode.pushNum 16] := by decide

example : parseFrom 2 (ByteArray.mk #[(0x61 : UInt8)]) 0 =
    some [Opcode.op ⟨0x61, by decide⟩] := by decide

example : parseFrom 2 (ByteArray.mk #[(0xff : UInt8)]) 0 =
    some [Opcode.op ⟨0xff, by decide⟩] := by decide

/-! ## Parse: direct pushes -/

example : parseFrom 3 (ByteArray.mk #[(0x01 : UInt8), 0xab]) 0 =
    some [Opcode.pushBytes (ByteArray.mk #[(0xab : UInt8)])] := by decide

example : parseFrom 7 (ByteArray.mk #[(0x03 : UInt8), 1, 2, 3, (0x01 : UInt8), 9]) 0 =
    some [Opcode.pushBytes (ByteArray.mk #[1, 2, 3]),
          Opcode.pushBytes (ByteArray.mk #[9])] := by decide

example : parseFrom 80 (serializeOpcodes
    [Opcode.pushBytes (bzeros 75)]) 0 = some [Opcode.pushBytes (bzeros 75)] := by
  decide

-- 0x4c is PUSHDATA1, NOT a 76-byte direct push: the "76-byte direct push"
-- opcode does not exist — 0x4c reads a length byte instead.
example : parseFrom 80 ((ByteArray.mk #[(0x4c : UInt8), (76 : UInt8)]) ++ bzeros 76) 0 =
    some [Opcode.pushBytes (bzeros 76)] := by
  native_decide

/-! ## Parse: PUSHDATA1/2/4 -/

example : parseFrom 5 (ByteArray.mk #[(0x4c : UInt8), 2, 0xbe, 0xef]) 0 =
    some [Opcode.pushBytes (ByteArray.mk #[(0xbe : UInt8), 0xef])] := by decide

-- PUSHDATA2 with a 256-byte payload (the > 255 boundary; LE16 0x0100)
example : parseFrom 300 (pd2 256) 0 =
    some [Opcode.pushBytes (bzeros 256)] := by
  native_decide

example : parseFrom 9 (ByteArray.mk #[(0x4e : UInt8), 3, 0, 0, 0, 1, 2, 3]) 0 =
    some [Opcode.pushBytes (ByteArray.mk #[1, 2, 3])] := by decide

-- PUSHDATA2 payloads may exceed 520: the parser accepts (SCR-045 decode
-- rules); the 520 element limit is interpreter policy (SCR-046) — the
-- parsed AST is then NOT `opcodeWF`, see the shape section below.
example : parseFrom 530 (pd2 521) 0 = some [Opcode.pushBytes (bzeros 521)] := by
  native_decide

-- a 520-byte payload under the same 521-length header truncates → `none`
example : parseFrom 530 (pd2w 521 520) 0 = none := by
  native_decide

/-! ## Parse: truncation → clean `none` (SCR-045) -/

example : parseFrom 5 (ByteArray.mk #[(0x02 : UInt8), 0xab]) 0 = none := by decide

example : parseFrom 5 (ByteArray.mk #[(0x4c : UInt8)]) 0 = none := by decide

example : parseFrom 5 (ByteArray.mk #[(0x4c : UInt8), 2, 0xbe]) 0 = none := by decide

example : parseFrom 5 (ByteArray.mk #[(0x4d : UInt8), 0x00]) 0 = none := by decide

example : parseFrom 5 (ByteArray.mk #[(0x4e : UInt8), 3, 0, 0]) 0 = none := by decide

-- insufficient fuel also yields `none` (totality by fuel construction)
example : parseFrom 1 (ByteArray.mk #[(0x51 : UInt8), (0x51 : UInt8)]) 0 = none := by
  decide

/-! ## `opcodeShape` vs `opcodeWF` on a >520 payload -/

example : opcodeShape (Opcode.pushBytes (bzeros 521)) := trivial

example : ¬ opcodeWF (Opcode.pushBytes (bzeros 521)) := by
  unfold opcodeWF
  decide

/-! ## Printer boundaries (`AppendDataSize` mirror) -/

example : lenBytes 0 = [(0x00 : UInt8)] := by decide
example : lenBytes 75 = [(75 : UInt8)] := by decide
example : lenBytes 76 = [(0x4c : UInt8), (76 : UInt8)] := by decide
example : lenBytes 255 = [(0x4c : UInt8), (255 : UInt8)] := by decide
example : lenBytes 256 = [(0x4d : UInt8), (0x00 : UInt8), (0x01 : UInt8)] := by decide
example : lenBytes 65535 =
    [(0x4d : UInt8), (0xff : UInt8), (0xff : UInt8)] := by decide
example : lenBytes 65536 =
    [(0x4e : UInt8), (0x00 : UInt8), (0x00 : UInt8), (0x01 : UInt8), (0x00 : UInt8)] := by
  decide

example : serializeOpcode (Opcode.pushNum 0) = ByteArray.mk #[(0x4f : UInt8)] := by
  decide
example : serializeOpcode (Opcode.pushNum 16) = ByteArray.mk #[(0x60 : UInt8)] := by
  decide
example : serializeOpcode (Opcode.op ⟨0xac, by decide⟩) =
    ByteArray.mk #[(0xac : UInt8)] := by decide

/-! ## `isDisabled` — exactly the 15 disabled opcodes (CVE-2010-5137) -/

example : isDisabled ⟨0x7e, by decide⟩ = true := by decide
example : isDisabled ⟨0x7f, by decide⟩ = true := by decide
example : isDisabled ⟨0x80, by decide⟩ = true := by decide
example : isDisabled ⟨0x81, by decide⟩ = true := by decide
example : isDisabled ⟨0x83, by decide⟩ = true := by decide
example : isDisabled ⟨0x84, by decide⟩ = true := by decide
example : isDisabled ⟨0x85, by decide⟩ = true := by decide
example : isDisabled ⟨0x86, by decide⟩ = true := by decide
example : isDisabled ⟨0x8d, by decide⟩ = true := by decide
example : isDisabled ⟨0x8e, by decide⟩ = true := by decide
example : isDisabled ⟨0x95, by decide⟩ = true := by decide
example : isDisabled ⟨0x96, by decide⟩ = true := by decide
example : isDisabled ⟨0x97, by decide⟩ = true := by decide
example : isDisabled ⟨0x98, by decide⟩ = true := by decide
example : isDisabled ⟨0x9a, by decide⟩ = true := by decide

-- near-misses stay enabled
example : isDisabled ⟨0x82, by decide⟩ = false := by decide
example : isDisabled ⟨0x8f, by decide⟩ = false := by decide
example : isDisabled ⟨0x94, by decide⟩ = false := by decide
example : isDisabled ⟨0x99, by decide⟩ = false := by decide
example : isDisabled ⟨0x9b, by decide⟩ = false := by decide

-- disabled opcodes still DECODE (parser-level; rejection is interpreter policy)
example : parseFrom 3 (ByteArray.mk #[(0x7e : UInt8), (0x51 : UInt8)]) 0 =
    some [Opcode.op ⟨0x7e, by decide⟩, Opcode.pushNum 1] := by decide

/-! ## `MAX_SCRIPT_ELEMENT_SIZE` -/

example : MAX_SCRIPT_ELEMENT_SIZE = 520 := by decide

/-! ## `opcodeCount` — the W09 op-budget hook (SCR-022/024: pushes and
OP_1NEGATE..OP_16 don't count; `op` bytes > 0x60 do) -/

example : opcodeCount [Opcode.pushBytes (ByteArray.mk #[(0xab : UInt8)]),
    Opcode.pushNum 3, Opcode.op ⟨0xac, by decide⟩, Opcode.op ⟨0x61, by decide⟩] = 2 := by
  decide

example : opcodeCount [Opcode.pushNum 0, Opcode.pushNum 16] = 0 := by decide

example : opcodeCount (List.replicate 205 (Opcode.op ⟨0x61, by decide⟩)) = 205 := by
  decide

end Test.Script.Parser.Tests
