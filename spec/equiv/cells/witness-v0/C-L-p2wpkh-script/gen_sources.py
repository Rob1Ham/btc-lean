#!/usr/bin/env python3
"""Generator for the C-L-p2wpkh-script cell sources.

The 25-byte P2WPKH implied script is encoded as four little-endian 64-bit
words (the last word carries the final 0xac byte plus zero padding).  The
encoding is a bijection: bytes 0..24 of the script are exactly the low 25
bytes of the four words.  Generating the repetitive unpack/pack lines avoids
transcription errors; the generated files are committed and reviewed.
"""
import pathlib

OUT = pathlib.Path(__file__).resolve().parent / "src"
OUT.mkdir(exist_ok=True)


def unpack(leg: str) -> str:
    # 20 little-endian program bytes from three words
    lines = []
    for i in range(8):
        lines.append(f"    program[{i}] = (uint8_t)(p0 >> {8*i});")
    for i in range(8):
        lines.append(f"    program[{8+i}] = (uint8_t)(p1 >> {8*i});")
    for i in range(4):
        lines.append(f"    program[{16+i}] = (uint8_t)(p2 >> {8*i});")
    return "\n".join(lines)


def build_c(leg: str) -> str:
    order = range(25) if leg == "c" else reversed(range(25))
    stores = []
    for i in order:
        if i == 0:
            stores.append("    s[0] = 0x76;   // OP_DUP")
        elif i == 1:
            stores.append("    s[1] = 0xa9;   // OP_HASH160")
        elif i == 2:
            stores.append("    s[2] = 0x14;   // push 20 bytes")
        elif 3 <= i <= 22:
            stores.append(f"    s[{i}] = program[{i-3}];")
        elif i == 23:
            stores.append("    s[23] = 0x88;  // OP_EQUALVERIFY")
        else:
            stores.append("    s[24] = 0xac;  // OP_CHECKSIG")
    # Encoding padding: bytes 25..31 are zero, making the four-word view total.
    stores.extend(f"    s[{i}] = 0;" for i in range(25, 32))
    if leg == "l":
        # L stores suffix-first; the generated store order above is already
        # reversed by `order`, so no extra work.
        pass
    return "\n".join(stores)


def pack_fn(n: int) -> str:
    base = 8 * n
    terms = []
    for k in range(8):
        idx = base + k
        shift = 8 * k
        if shift == 0:
            terms.append(f"(uint64_t)s[{idx}]")
        else:
            terms.append(f"((uint64_t)s[{idx}] << {shift})")
    return " |\n           ".join(terms)


def emit(leg: str) -> str:
    header_c = """#include "wv_common.h"

// C leg: line-cited slice of Bitcoin Core src/script/interpreter.cpp at pin
// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66, the P2WPKH implied-script
// construction (interpreter.cpp:1952-1953):
//
//   exec_script << OP_DUP << OP_HASH160 << program << OP_EQUALVERIFY
//               << OP_CHECKSIG;
//   return ExecuteWitnessScript(stack, exec_script, ...);
//
// `CScript::operator<<(std::vector<unsigned char>)` writes a minimal push, so
// the implied script is the 25 bytes
//
//   76 a9 14 <program[0..19]> 88 ac
//
// Only the construction is modelled; ExecuteWitnessScript (line 1953) is the
// EvalScript/HASH160/CHECKSIG seam and is outside this cell.
//
// Encoding: the 20-byte program arrives as three little-endian u64 words
// (p0 = bytes 0..7, p1 = bytes 8..15, p2 = bytes 16..19 in its low 32 bits)
// and the 25-byte script leaves as four little-endian u64 words (bytes 0..7,
// 8..15, 16..23, 24 plus zero padding).  This is a bijection, adopted because
// Alive2 v20 rejects pointer parameters carrying the `nocapture`/`noalias`
// attributes and runs out of memory on a 20-byte symbolic memory input.
"""
    header_l = """#include "wv_common.h"

// L leg: REVIEWED TRANSLITERATION of the verified Lean construction
//   spec/core/Bitcoin/Interpreter/Defs.lean:1297-1303
// (`Bitcoin.SigHash.p2wpkhScriptCodeL`, used by
// `Bitcoin.Interpreter.verifyWitnessProgram` at Defs.lean:1283-1285):
//
//   let exec : ByteArray :=
//     List.toByteArray [0x76, 0xa9, 0x14] ++ program ++
//       List.toByteArray [0x88, 0xac]
//
// The store order below is suffix-first, deliberately different from the C
// slice, so the Alive2 comparison is not a syntactic self-comparison.  The
// same four-word little-endian encoding as the C leg is documented there.
"""
    body = [header_c if leg == "c" else header_l, ""]
    body.append("WV_INLINE void build_script(uint64_t p0, uint64_t p1, uint64_t p2,")
    body.append("                           uint8_t program[20], uint8_t s[32]) {")
    body.append(unpack(leg))
    body.append(build_c(leg))
    body.append("}")
    body.append("")
    for n in range(4):
        body.append(f"extern \"C\" uint64_t cell_p2wpkh_script_w{n}(uint64_t p0, uint64_t p1, uint64_t p2) {{")
        body.append("    uint8_t program[20];")
        body.append("    uint8_t s[32];")
        body.append("    build_script(p0, p1, p2, program, s);")
        body.append("    return " + pack_fn(n) + ";")
        body.append("}")
        body.append("")
    return "\n".join(body)


def emit_cry() -> str:
    return """module Spec where

// The 25-byte P2WPKH implied script and its four little-endian 64-bit words.
program : [64] -> [64] -> [64] -> [20][8]
program p0 p1 p2 =
  (reverse (split p0) : [8][8]) # (reverse (split p1) : [8][8]) #
  (take (reverse (split p2) : [8][8]) : [4][8])

script : [64] -> [64] -> [64] -> [25][8]
script p0 p1 p2 = [0x76, 0xa9, 0x14] # program p0 p1 p2 # [0x88, 0xac]

padded : [64] -> [64] -> [64] -> [32][8]
padded p0 p1 p2 = script p0 p1 p2 # (zero : [7][8])

w0 : [64] -> [64] -> [64] -> [64]
w0 p0 p1 p2 = join (reverse ((padded p0 p1 p2) @@ [0..7]))

w1 : [64] -> [64] -> [64] -> [64]
w1 p0 p1 p2 = join (reverse ((padded p0 p1 p2) @@ [8..15]))

w2 : [64] -> [64] -> [64] -> [64]
w2 p0 p1 p2 = join (reverse ((padded p0 p1 p2) @@ [16..23]))

w3 : [64] -> [64] -> [64] -> [64]
w3 p0 p1 p2 = join (reverse ((padded p0 p1 p2) @@ [24..31]))
"""


def emit_saw() -> str:
    lines = ['import "cell.cry";', ""]
    for n in range(4):
        lines.append(f'm{n}C <- llvm_load_module "c_cell_p2wpkh_script_w{n}.bc";')
        lines.append(f'm{n}L <- llvm_load_module "l_cell_p2wpkh_script_w{n}.bc";')
    lines.append("")
    for n in range(4):
        lines.append(f"let spec_w{n} = do {{")
        lines.append('  p0 <- llvm_fresh_var "p0" (llvm_int 64);')
        lines.append('  p1 <- llvm_fresh_var "p1" (llvm_int 64);')
        lines.append('  p2 <- llvm_fresh_var "p2" (llvm_int 64);')
        lines.append("  llvm_execute_func [llvm_term p0, llvm_term p1, llvm_term p2];")
        lines.append("  llvm_return (llvm_term {{ " + f"w{n} p0 p1 p2" + " }});")
        lines.append("};")
        lines.append("")
    for n in range(4):
        lines.append(f'llvm_verify m{n}C "cell_p2wpkh_script_w{n}" [] false spec_w{n} abc;')
        lines.append(f'llvm_verify m{n}L "cell_p2wpkh_script_w{n}" [] false spec_w{n} abc;')
    lines.append("")
    lines.append('print "CELL_P2WPKH_SCRIPT_SAW_GREEN";')
    lines.append("")
    return "\n".join(lines)


(OUT / "c_cell.cpp").write_text(emit("c"))
(OUT / "l_cell.cpp").write_text(emit("l"))
(OUT / "cell.cry").write_text(emit_cry())
(OUT / "cell.saw").write_text(emit_saw())
(OUT / "fns.txt").write_text("\n".join(
    f"cell_p2wpkh_script_w{n}" for n in range(4)) + "\n")
print("generated", OUT)
