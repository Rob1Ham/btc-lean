import Bitcoin.Data.Script

/-!
# Bitcoin.Script.Interp

A fuel-limited interpreter for the PoC opcode subset.
Ground truth: `EvalScript` / `src/script/interpreter.cpp` (the complete semantics is not modeled here;
this file only demonstrates the
architecture: AST in → stack machine out, every failure explicit).

Simplifications vs Core (documented, deliberate):
  * `CScriptNum` here is unsigned LE with minimal encoding (Core: int64,
    little-endian, sign bit, 4-byte default carry limit).
  * `OP_CHECKSIG` is a **stub**: pops `(sig, pubkey)` and pushes `0x01`
    iff both are nonempty. Real ECDSA/Schnorr is not modeled here.
  * No OP_CODESEPARATOR, no if/else branches, no altstack, no P2SH.
-/


namespace Bitcoin.Script

open Bitcoin.Data

/-- Interpreter failure reasons (naming follows Core's
`SCRIPT_ERR_*` enum, `interpreter.h`). -/
inductive InterpError where
  | badOpcode
  | stackUnderflow
  | verifyFailed       -- SCRIPT_ERR_VERIFY
  | equalVerifyFailed  -- SCRIPT_ERR_EQUALVERIFY
  | scriptSize
deriving Repr, DecidableEq

/-- Machine state: just the main stack plus fuel. -/
abbrev Stack := List ByteArray

/-- `CScriptNum` decode: unsigned little-endian (simplified).
Index-based (not `ByteArray.toList`, which is well-founded and does
not kernel-reduce). -/
def numOfBytes (b : ByteArray) : Nat :=
  (List.range b.size).foldr (fun i acc => (b.get! i).toNat + 256 * acc) 0

/-- `CScriptNum` encode: minimal little-endian (0 encodes as empty).
Structural on an explicit fuel: a `/ 256`-recursive version compiles to
`WellFounded.fix`, which does **not** kernel-reduce under `decide`. -/
def bytesOfNumAux : Nat → Nat → ByteArray
  | 0, _ => ByteArray.empty
  | fuel+1, n =>
      if n < 256 then serU8 n.toUInt8
      else (bytesOfNumAux fuel (n / 256)).push (n % 256).toUInt8

def bytesOfNum (n : Nat) : ByteArray := bytesOfNumAux n n

/-- Boolean → stack encoding: `0x01` true, empty false
(`interpreter.cpp`, `cast_to_bool` inverse / `push_bool`). -/
def pushBool (v : Bool) : ByteArray :=
  if v then serU8 0x01 else ByteArray.empty

/-- One opcode transition. -/
def step : ScriptInstr → Stack → Except InterpError Stack
  | .push data, st => .ok (data :: st)
  | .op1negate, st => .ok (serU8 0x81 :: st)
  | .const n, st => .ok (bytesOfNum n :: st)
  | .nop, st => .ok st
  | .verify, st =>
    match st with
    | [] => .error .stackUnderflow
    | top :: rest =>
        if top.size = 0 then .error .verifyFailed else .ok rest
  | .equal, st =>
    match st with
    | _ :: _ :: rest => .ok (pushBool (bytesBEq st.head! (st.tail!.head!)) :: rest)
    | _ => .error .stackUnderflow
  | .equalVerify, st =>
    match st with
    | _ :: _ :: rest =>
        if bytesBEq st.head! (st.tail!.head!) then .ok rest else .error .equalVerifyFailed
    | _ => .error .stackUnderflow
  | .add, st =>
    match st with
    | _ :: _ :: rest =>
        let a := numOfBytes st.head!
        let b := numOfBytes st.tail!.head!
        .ok (bytesOfNum (a + b) :: rest)
    | _ => .error .stackUnderflow
  | .checkSig, st =>
    -- STUB: real BIP66 DER + ECDSA/Schnorr verification (not modeled here).
    match st with
    | _ :: _ :: rest => .ok (pushBool (st.head!.size ≠ 0 ∧ st.tail!.head!.size ≠ 0) :: rest)
    | _ => .error .stackUnderflow

/-- Run a parsed program under fuel; returns the final stack.
Processes opcodes front-to-back like `EvalScript`'s pc loop. -/
def run : Nat → List ScriptInstr → Stack → Except InterpError Stack
  | 0, _, _ => .error .scriptSize   -- budget exhausted (stand-in for op-count limit)
  | _+1, [], st => .ok st
  | fuel+1, op :: rest, st => do
      let st' ← step op st
      run fuel rest st'

/-- Convenience: does this script complete and leave a truthy top of stack? -/
def runsTrue (fuel : Nat) (prog : List ScriptInstr) : Bool :=
  match run fuel prog [] with
  | .ok (top :: _) => top.size ≠ 0
  | _ => false

/-- Convenience: does this script complete at all (script-level success)? -/
def runsClean (fuel : Nat) (prog : List ScriptInstr) : Bool :=
  match run fuel prog [] with
  | .ok _ => true
  | _ => false

end Bitcoin.Script
