import Bitcoin.Data.Basic

/-!
# Bitcoin.Data.Script

`CScript` is raw bytes (`std::vector<unsigned char>` in
`src/primitives/script.h`); the interpreter never works over the raw
bytes directly — `EvalScript` walks a parsed opcode stream
(`GetOp` in `src/script/script.h`). We mirror that split:

  * `Script`       = opaque `ByteArray` (the on-chain representation)
  * `ScriptInstr`  = the AST opcode model
  * `Script.parse` = `GetOp`-style decode into `List ScriptInstr`
-/


namespace Bitcoin.Data

/-- `CScript` — raw serialized script bytes. -/
structure Script where
  bytes : ByteArray
deriving Repr

def Script.empty : Script := ⟨ByteArray.empty⟩

instance : BEq Script where
  beq a b := bytesBEq a.bytes b.bytes

/-- Opcodes understood by the PoC interpreter (a strict subset;
the full opcode model is workstream B2). -/
inductive ScriptInstr where
  | push (data : ByteArray)      -- OP_0 / OP_1..OP_75 direct pushes
  | op1negate                    -- 0x4f
  | const (n : Nat)              -- OP_1 (0x51) .. OP_16 (0x60)
  | nop                          -- 0x61
  | verify                       -- 0x69
  | equal                        -- 0x87
  | equalVerify                  -- 0x88
  | add                          -- 0x93
  | checkSig                     -- 0xac (stubbed in the PoC)
deriving Repr, DecidableEq, BEq

/-! ## Parser (`GetOp`, `script/script.h`) -/

/-- Read `n` bytes at index `i`. -/
def takeBytes (b : ByteArray) (i n : Nat) : Option ByteArray :=
  if i + n ≤ b.size then
    some ((List.range n).foldl
      (fun acc k => acc.push (b.get! (i + k))) ByteArray.empty)
  else none

/-- Decode one opcode at index `i`; returns instruction and next index. -/
def decodeOp (b : ByteArray) (i : Nat) : Option (ScriptInstr × Nat) :=
  match b[i]? with
  | none => none
  | some op =>
    let n := op.toNat
    if n = 0 then some (.push ByteArray.empty, i + 1)
    else if n ≤ 0x4b then
      match takeBytes b (i + 1) n with
      | some data => some (.push data, i + 1 + n)
      | none => none
    else if n = 0x4f then some (.op1negate, i + 1)
    else if 0x51 ≤ n ∧ n ≤ 0x60 then some (.const (n - 0x50), i + 1)
    else if n = 0x61 then some (.nop, i + 1)
    else if n = 0x69 then some (.verify, i + 1)
    else if n = 0x87 then some (.equal, i + 1)
    else if n = 0x88 then some (.equalVerify, i + 1)
    else if n = 0x93 then some (.add, i + 1)
    else if n = 0xac then some (.checkSig, i + 1)
    else none

/-- Parse a full script; unknown opcodes reject. Fuel = script size
guarantees termination (each opcode consumes ≥ 1 byte). -/
def Script.parse (s : Script) : Option (List ScriptInstr) :=
  parseWith s.bytes s.bytes.size 0 []
where
  parseWith (b : ByteArray) : Nat → Nat → List ScriptInstr → Option (List ScriptInstr)
    | 0, i, acc => if b.size ≤ i then some acc.reverse else none
    | fuel+1, i, acc =>
        if b.size ≤ i then some acc.reverse
        else match decodeOp b i with
          | some (op, i') => parseWith b fuel i' (op :: acc)
          | none => none

/-! ## Builders (test helpers) -/

def scriptOf (bytes : List UInt8) : Script := ⟨bytes.foldl (·.push ·) ByteArray.empty⟩

end Bitcoin.Data
