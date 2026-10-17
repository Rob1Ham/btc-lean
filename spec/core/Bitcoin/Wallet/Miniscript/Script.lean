import Bitcoin.Wallet.Miniscript.Node

/-!
# Miniscript script emission

`toScript` emits the byte-exact script Core produces with
`Node::ToScript` (`src/script/miniscript.h:798-880`) for the modelled
fragments.  The `verify` parameter is Core's "this subexpression is
followed by `OP_VERIFY`" state: it is set by the `v:` wrapper and by the
second operand of `and_v`, and it selects `OP_CHECKSIGVERIFY` over
`OP_CHECKSIG`, `OP_CHECKMULTISIGVERIFY` over `OP_CHECKMULTISIG`,
`OP_NUMEQUALVERIFY` over `OP_NUMEQUAL`, and `OP_EQUALVERIFY` over
`OP_EQUAL`.  It is a syntactic property, not a context difference;
the only context-dependent encodings are `multi` (P2WSH only) and
`multi_a` (tapscript only), plus the `d:` wrapper's `u` type bit.

The numeric encodings follow `CScript::operator<<(int64_t)`
(`src/script/script.h`): `0` is `OP_0`, `1..16` are `OP_1..OP_16`, and
larger values are minimally encoded little-endian ScriptNums with a sign
byte when needed.  Hash and key pushes are minimal direct pushes.

Not modelled: the `Ctx` abstraction that converts a descriptor key to
33-byte compressed (`ToPKBytes`) or 32-byte x-only bytes, checksum and
`ToString` round-trips, and Core's `FromScript` parser.
-/

namespace Bitcoin.Wallet.Miniscript

/-- A script: raw serialized opcodes and pushdata, as `CScript`'s bytes. -/
abbrev Script := ByteArray

/-- Build a byte string from a list of byte values. -/
def bytes (l : List Nat) : ByteArray :=
  ByteArray.mk (l.map (fun n => n.toUInt8)).toArray

/-- A single opcode byte. -/
def op (n : Nat) : ByteArray := bytes [n]

/-- Little-endian magnitude bytes of a non-negative integer, least
significant first; empty for zero. -/
def leBytes : Nat → List Nat
  | 0 => []
  | n + 1 => ((n + 1) % 256) :: leBytes ((n + 1) / 256)
termination_by n => n
decreasing_by
  simp_wf
  omega

/-- Minimal signed ScriptNum encoding (`CScriptNum::serialize`):
little-endian magnitude, with an extra `0x00` byte when the top bit of
the last magnitude byte is set.  Zero is the empty string. -/
def scriptNumBytes (n : Nat) : ByteArray :=
  match leBytes n with
  | [] => .empty
  | bs =>
    if bs.getLast! ≥ 0x80 then bytes (bs ++ [0]) else bytes bs

/-- Minimal push of arbitrary bytes.  The 76..255 and 256..65535 cases are
included for completeness; Miniscript itself only pushes at most 33
bytes. -/
def pushBytes (d : ByteArray) : ByteArray :=
  if d.size = 0 then op 0x00
  else if d.size ≤ 75 then op d.size ++ d
  else if d.size ≤ 255 then op 0x4c ++ op d.size ++ d
  else op 0x4d ++ bytes [d.size % 256, d.size / 256] ++ d

/-- Push a non-negative integer the way `CScript << int64_t` does:
`OP_0`, `OP_1..OP_16`, or a minimal ScriptNum push. -/
def pushInt (n : Nat) : ByteArray :=
  if n = 0 then op 0x00
  else if n ≤ 16 then op (0x50 + n)
  else pushBytes (scriptNumBytes n)

/-- Maximum script size Core accepts for a Miniscript, by context:
`MAX_STANDARD_P2WSH_SCRIPT_SIZE` = 3600 for P2WSH
(`src/policy/policy.h:60`), and the tapscript bound computed in
`MaxScriptSize` (`src/script/miniscript.h:283-295`) from the standard
transaction weight, the maximum saturation size, and the control block
limit.  The latter works out to 329482 bytes. -/
def maxScriptSize : MiniscriptContext → Nat
  | .p2wsh => 3600
  | .tapscript =>
    let txBodyLeeway := (8 + 1 + 41 + 1 + 43) * 4 + 2
    let maxSat := 3 + (1 + 65) * 1000 + 3 + 4129
    let maxSize := 400000 - txBodyLeeway - maxSat
    maxSize - 5


/-- Concatenate scripts in order. -/
def concatScripts : List Script → Script
  | [] => .empty
  | x :: xs => x ++ concatScripts xs

/-- Join threshold-branch scripts with `OP_ADD` between consecutive
branches, matching Core's `[X1] ([Xn] OP_ADD)*`. -/
def intersperseAdd : List Script → Script
  | [] => .empty
  | x :: xs => x ++ concatScripts (xs.map (fun s => s ++ op 0x93))

/-- Emit `multi_a`'s key sequence: the first key is followed by
`OP_CHECKSIG`, every later key by `OP_CHECKSIGADD`. -/
def multiAKeyScript : List Key → Script
  | [] => .empty
  | key :: rest =>
    pushBytes key ++ op 0xac ++
      concatScripts (rest.map (fun k => pushBytes k ++ op 0xba))

/-- Emit the script of a node.  `verify` is `true` when the caller will
execute `OP_VERIFY` on the node's result, which folds the last opcode to
its `-VERIFY` variant exactly as Core's `downfn`/`upfn` pair does
(`src/script/miniscript.h:798-880`). -/
def toScriptWith (ctx : MiniscriptContext) (verify : Bool) : Node → Script
  | .pkK key => pushBytes key
  | .pkH _ keyHash => op 0x76 ++ op 0xa9 ++ pushBytes keyHash ++ op 0x88
  | .older n => pushInt n ++ op 0xb2
  | .after n => pushInt n ++ op 0xb1
  | .sha256 h =>
    op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xa8 ++
      pushBytes h ++ (if verify then op 0x88 else op 0x87)
  | .hash256 h =>
    op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xaa ++
      pushBytes h ++ (if verify then op 0x88 else op 0x87)
  | .ripemd160 h =>
    op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xa6 ++
      pushBytes h ++ (if verify then op 0x88 else op 0x87)
  | .hash160 h =>
    op 0x82 ++ op 0x01 ++ op 0x20 ++ op 0x88 ++ op 0xa9 ++
      pushBytes h ++ (if verify then op 0x88 else op 0x87)
  | .wrapA x => op 0x6b ++ toScriptWith ctx false x ++ op 0x6c
  | .wrapS x => op 0x7c ++ toScriptWith ctx verify x
  | .wrapC x => toScriptWith ctx verify x ++ (if verify then op 0xad else op 0xac)
  | .wrapD x => op 0x76 ++ op 0x63 ++ toScriptWith ctx false x ++ op 0x68
  | .wrapV x =>
    let s := toScriptWith ctx true x
    if (calcType ctx x).has .x then s ++ op 0x69 else s
  | .wrapJ x => op 0x82 ++ op 0x92 ++ op 0x63 ++ toScriptWith ctx false x ++ op 0x68
  | .wrapN x => toScriptWith ctx false x ++ op 0x92
  | .andV x y => toScriptWith ctx false x ++ toScriptWith ctx verify y
  | .andB x y => toScriptWith ctx false x ++ toScriptWith ctx false y ++ op 0x9a
  | .orB x y => toScriptWith ctx false x ++ toScriptWith ctx false y ++ op 0x9b
  | .orD x y =>
    toScriptWith ctx false x ++ op 0x73 ++ op 0x64 ++
      toScriptWith ctx false y ++ op 0x68
  | .orC x y =>
    toScriptWith ctx false x ++ op 0x64 ++ toScriptWith ctx false y ++ op 0x68
  | .orI x y =>
    op 0x63 ++ toScriptWith ctx false x ++ op 0x67 ++
      toScriptWith ctx false y ++ op 0x68
  | .thresh k xs =>
    intersperseAdd (xs.map (toScriptWith ctx false)) ++
      pushInt k ++ (if verify then op 0x88 else op 0x87)
  | .multi k keys =>
    pushInt k ++ concatScripts (keys.map pushBytes) ++ pushInt keys.length ++
      (if verify then op 0xaf else op 0xae)
  | .multiA k keys =>
    multiAKeyScript keys ++ pushInt k ++
      (if verify then op 0x9d else op 0x9c)
termination_by n => sizeOf n
decreasing_by
  all_goals simp_wf
  all_goals
    first
      | omega
      | (have h := List.sizeOf_lt_of_mem (by assumption); omega)

/-- Emit the top-level script of a node (no following `OP_VERIFY`). -/
def toScript (ctx : MiniscriptContext) (n : Node) : Script :=
  toScriptWith ctx false n

end Bitcoin.Wallet.Miniscript
