#!/usr/bin/env python3
"""ref.py — parser conformance reference (independent Python port of Core).

Ports, faithfully, from Bitcoin Core @ c50817fe:
  * core_io.cpp:ParseScript (92-137) + OpCodeParser (44-70) +
    script.h:push_int64 (434-448) / AppendDataSize (408-427) +
    script.h:CScriptNum::serialize (342-373)
  * script.cpp:GetScriptOp (313-363) — the single-opcode decode walk

Usage:
  python3 ref.py <script_tests.json> <out_dir>

Emits, into <out_dir>:
  conf_input.txt     one hex-encoded script per line ("-" if ParseScript threw)
  conf_expected.txt  the normalized AST: space-separated tokens per script
                     ("FAIL" if the GetScriptOp walk hits truncation, "-" if
                     the line was skipped because ParseScript threw)

Normalized AST tokens (the PUSHDATA1/2/4 *form* is erased — the AST carries
only the payload; this matches Bitcoin.Script.Parser.Opcode):
  push bytes  : "push:<payload hex>"   (OP_0/OP_1..75/PUSHDATA{1,2,4})
  OP_1NEGATE  : "num:0"                (parser convention: pushNum 0 = -1)
  OP_RESERVED : "op:0x50"
  OP_1..OP_16 : "num:<1..16>"
  other ops   : "op:0x<bb>"

License notice: this file is an
independent Python transliteration (port) of MIT-licensed Bitcoin Core
code (core_io.cpp::ParseScript/OpCodeParser, script.h::push_int64/
AppendDataSize/CScriptNum::serialize, script.cpp::GetScriptOp @
c50817fe). Per MIT §2, the notice text for the portion derived from
Bitcoin Core (COPYING):

  The MIT License (MIT)
  Copyright (c) 2009-2026 The Bitcoin Core developers

  Permission is hereby granted, free of charge, to any person obtaining
  a copy of this software and associated documentation files (the
  "Software"), to deal in the Software without restriction, including
  without limitation the rights to use, copy, modify, merge, publish,
  distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to
  the following conditions:

  The above copyright notice and this permission notice shall be
  included in all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
  OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
  MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
  LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
  OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
  WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

  Project license: MIT (repo-root LICENSE, 2026 btc-lean contributors);
  per-file provenance table: docs/PROVENANCE.md §1d.
"""

import json
import sys
from pathlib import Path


# ---------------------------------------------------------------------------
# GetOpName (script.cpp:19-157) — name table for the opcode words.
# Registered exactly like core_io.cpp:OpCodeParser: only op >= OP_NOP (0x61)
# and OP_RESERVED (0x50); name "OP_UNKNOWN" is skipped; the "OP_"-stripped
# alias is registered too.
# ---------------------------------------------------------------------------

OP_NOP = 0x61
OP_RESERVED = 0x50
OP_PUSHDATA1 = 0x4C
OP_PUSHDATA2 = 0x4D
OP_PUSHDATA4 = 0x4E
OP_0 = 0x00
OP_1 = 0x51

NAMES = {
    0x00: "0",
    0x4C: "OP_PUSHDATA1", 0x4D: "OP_PUSHDATA2", 0x4E: "OP_PUSHDATA4",
    0x4F: "-1", 0x50: "OP_RESERVED",
    **{0x50 + n: str(n) for n in range(1, 17)},
    0x61: "OP_NOP", 0x62: "OP_VER", 0x63: "OP_IF", 0x64: "OP_NOTIF",
    0x65: "OP_VERIF", 0x66: "OP_VERNOTIF", 0x67: "OP_ELSE", 0x68: "OP_ENDIF",
    0x69: "OP_VERIFY", 0x6A: "OP_RETURN",
    0x6B: "OP_TOALTSTACK", 0x6C: "OP_FROMALTSTACK",
    0x6D: "OP_2DROP", 0x6E: "OP_2DUP", 0x6F: "OP_3DUP", 0x70: "OP_2OVER",
    0x71: "OP_2ROT", 0x72: "OP_2SWAP", 0x73: "OP_IFDUP", 0x74: "OP_DEPTH",
    0x75: "OP_DROP", 0x76: "OP_DUP", 0x77: "OP_NIP", 0x78: "OP_OVER",
    0x79: "OP_PICK", 0x7A: "OP_ROLL", 0x7B: "OP_ROT", 0x7C: "OP_SWAP",
    0x7D: "OP_TUCK",
    0x7E: "OP_CAT", 0x7F: "OP_SUBSTR", 0x80: "OP_LEFT", 0x81: "OP_RIGHT",
    0x82: "OP_SIZE",
    0x83: "OP_INVERT", 0x84: "OP_AND", 0x85: "OP_OR", 0x86: "OP_XOR",
    0x87: "OP_EQUAL", 0x88: "OP_EQUALVERIFY", 0x89: "OP_RESERVED1",
    0x8A: "OP_RESERVED2",
    0x8B: "OP_1ADD", 0x8C: "OP_1SUB", 0x8D: "OP_2MUL", 0x8E: "OP_2DIV",
    0x8F: "OP_NEGATE", 0x90: "OP_ABS", 0x91: "OP_NOT", 0x92: "OP_0NOTEQUAL",
    0x93: "OP_ADD", 0x94: "OP_SUB", 0x95: "OP_MUL", 0x96: "OP_DIV",
    0x97: "OP_MOD", 0x98: "OP_LSHIFT", 0x99: "OP_RSHIFT",
    0x9A: "OP_BOOLAND", 0x9B: "OP_BOOLOR",
    0x9C: "OP_NUMEQUAL", 0x9D: "OP_NUMEQUALVERIFY", 0x9E: "OP_NUMNOTEQUAL",
    0x9F: "OP_LESSTHAN", 0xA0: "OP_GREATERTHAN", 0xA1: "OP_LESSTHANOREQUAL",
    0xA2: "OP_GREATERTHANOREQUAL", 0xA3: "OP_MIN", 0xA4: "OP_MAX",
    0xA5: "OP_WITHIN",
    0xA6: "OP_RIPEMD160", 0xA7: "OP_SHA1", 0xA8: "OP_SHA256",
    0xA9: "OP_HASH160", 0xAA: "OP_HASH256", 0xAB: "OP_CODESEPARATOR",
    0xAC: "OP_CHECKSIG", 0xAD: "OP_CHECKSIGVERIFY", 0xAE: "OP_CHECKMULTISIG",
    0xAF: "OP_CHECKMULTISIGVERIFY",
    0xB0: "OP_NOP1", 0xB1: "OP_CHECKLOCKTIMEVERIFY", 0xB2: "OP_CHECKSEQUENCEVERIFY",
    0xB3: "OP_NOP4", 0xB4: "OP_NOP5", 0xB5: "OP_NOP6", 0xB6: "OP_NOP7",
    0xB7: "OP_NOP8", 0xB8: "OP_NOP9", 0xB9: "OP_NOP10",
    0xBA: "OP_CHECKSIGADD", 0xFF: "OP_INVALIDOPCODE",
}

OP_WORDS = {}
for _op in range(0x100):
    if _op < OP_NOP and _op != OP_RESERVED:
        continue
    _name = NAMES.get(_op)
    if _name is None or _name == "OP_UNKNOWN":
        continue
    OP_WORDS[_name] = _op
    if _name.startswith("OP_"):
        OP_WORDS[_name[3:]] = _op


# ---------------------------------------------------------------------------
# CScriptNum::serialize (script.h:342-373) — minimal two's-complement LE.
# ---------------------------------------------------------------------------

def cscriptnum_serialize(value):
    if value == 0:
        return b""
    neg = value < 0
    absvalue = -value if neg else value
    result = bytearray()
    while absvalue:
        result.append(absvalue & 0xFF)
        absvalue >>= 8
    if result[-1] & 0x80:
        result.append(0x80 if neg else 0x00)
    elif neg:
        result[-1] |= 0x80
    return bytes(result)


# ---------------------------------------------------------------------------
# Push helpers (script.h:408-427 AppendDataSize, 434-448 push_int64).
# ---------------------------------------------------------------------------

def append_data_size(size):
    if size < OP_PUSHDATA1:
        return bytes([size])
    elif size <= 0xFF:
        return bytes([OP_PUSHDATA1, size])
    elif size <= 0xFFFF:
        return bytes([OP_PUSHDATA2, size & 0xFF, (size >> 8) & 0xFF])
    else:
        return bytes([OP_PUSHDATA4, size & 0xFF, (size >> 8) & 0xFF,
                      (size >> 16) & 0xFF, (size >> 24) & 0xFF])


def push_data(data):
    """CScript::operator<<(span) — AppendDataSize + raw data."""
    return append_data_size(len(data)) + data


def push_int64(n):
    if n == -1 or (1 <= n <= 16):
        return bytes([(n + (OP_1 - 1)) & 0xFF])
    elif n == 0:
        return bytes([OP_0])
    else:
        # CScript& operator<<(const CScriptNum&) == operator<<(getvch())
        return push_data(cscriptnum_serialize(n))


HEXDIGITS = set("0123456789abcdefABCDEF")


def parse_script(s):
    """core_io.cpp:ParseScript (92-137). Returns bytes; raises on bad words."""
    out = bytearray()
    for w in s.split(" "):  # Core splits on " \t\n"; empty words are skipped
        for tok in w.split("\t"):
            for word in tok.split("\n"):
                if not word:
                    continue
                body = word[1:] if word[0] == "-" else word
                if body.isdigit() and body.isascii():
                    num = int(word)
                    if num > 0xFFFFFFFF or num < -0xFFFFFFFF:
                        raise ValueError("number out of range")
                    out += push_int64(num)
                elif (word.startswith("0x") and len(word) > 2
                      and all(c in HEXDIGITS for c in word[2:])
                      and len(word) % 2 == 0):
                    out += bytes.fromhex(word[2:])
                elif len(word) >= 2 and word[0] == "'" and word[-1] == "'":
                    out += push_data(word[1:-1].encode())
                else:
                    if word not in OP_WORDS:
                        raise ValueError(f"unknown opcode word {word!r}")
                    out.append(OP_WORDS[word])
    return bytes(out)


# ---------------------------------------------------------------------------
# GetScriptOp walk (script.cpp:313-363) with normalized tokens.
# ---------------------------------------------------------------------------

def norm_walk(b):
    """Walk b with the GetScriptOp rules; return token list or None (FAIL)."""
    ops = []
    i = 0
    n = len(b)
    while i < n:
        opcode = b[i]
        i += 1
        if opcode <= OP_PUSHDATA4:
            if opcode < OP_PUSHDATA1:
                size = opcode
            elif opcode == OP_PUSHDATA1:
                if n - i < 1:
                    return None
                size = b[i]
                i += 1
            elif opcode == OP_PUSHDATA2:
                if n - i < 2:
                    return None
                size = b[i] | (b[i + 1] << 8)
                i += 2
            else:  # OP_PUSHDATA4
                if n - i < 4:
                    return None
                size = b[i] | (b[i + 1] << 8) | (b[i + 2] << 16) | (b[i + 3] << 24)
                i += 4
            if n - i < size:
                return None
            payload = b[i:i + size]
            i += size
            ops.append("push:" + payload.hex())
        elif opcode == 0x4F:
            ops.append("num:0")
        elif opcode == OP_RESERVED:
            ops.append("op:0x50")
        elif opcode <= 0x60:
            ops.append(f"num:{opcode - OP_RESERVED}")
        else:
            ops.append(f"op:0x{opcode:02x}")
    return " ".join(ops)


def main():
    corpus = Path(sys.argv[1])
    outdir = Path(sys.argv[2])
    entries = json.loads(corpus.read_text())
    n_vec = n_skip = 0
    with open(outdir / "conf_input.txt", "w") as fin, \
         open(outdir / "conf_expected.txt", "w") as fexp:
        for v in entries:
            if not isinstance(v, list):
                continue
            # [scriptSig, scriptPubKey, flags, expected] or
            # [witness, scriptSig, scriptPubKey, flags, expected] (+comment)
            if len(v) >= 5 and isinstance(v[0], list):
                scripts = (v[1], v[2])
            elif len(v) >= 4:
                scripts = (v[0], v[1])
            else:
                continue
            n_vec += 1
            for asm in scripts:
                try:
                    raw = parse_script(asm)
                except ValueError:
                    fin.write("-\n")
                    fexp.write("-\n")
                    n_skip += 1
                    continue
                fin.write(raw.hex() + "\n")
                walk = norm_walk(raw)
                fexp.write(("FAIL" if walk is None else walk) + "\n")
    print(f"ref.py: {n_vec} vectors -> {2 * n_vec} script lines "
          f"({n_skip} skipped: ParseScript raised)")


if __name__ == "__main__":
    main()
