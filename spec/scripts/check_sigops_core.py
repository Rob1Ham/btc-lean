#!/usr/bin/env python3
"""Run static-count vectors using unmodified functions from pinned Core source.

Supply src/script/script.cpp and src/script/interpreter.cpp downloaded at
the repository's Core pin. The harness supplies only container declarations,
opcode constants, little-endian readers and a driver. It extracts the actual
counting/parsing function bodies; it does not reimplement those algorithms.
This is an executable differential reference, not a C++/Lean equivalence proof.
"""

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


SOURCE_PAIRS = {
    ("210b1720acce295de54c6a08c76b97fa4cfe835f64e0ff7e0730c57ebebb8c55",
     "57a6f328c7e6202f499e48366a86eb26e09c8ebb78e92eef7e839207230be333"):
        "cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66",
    ("6f71c729ce7bb49706d394a0c25d112dbb24703f6b571419f2859af5cc0c8fe3",
     "858d409164ac071eb1ec038330b8c1dca43f5e9edd9f6092e49895258c7edb56"):
        "9be056a8a72b624dae9623b2f7bded92c2a21c91",
}

SCRIPT_FUNCTIONS = [
    "bool GetScriptOp(",
    "unsigned int CScript::GetSigOpCount(bool",
    "unsigned int CScript::GetSigOpCount(const CScript&",
    "bool CScript::IsPayToScriptHash()",
    "bool CScript::IsWitnessProgram(",
    "bool CScript::IsPushOnly(const_iterator",
    "bool CScript::IsPushOnly()",
]
INTERPRETER_FUNCTIONS = ["size_t static WitnessSigOps(", "size_t CountWitnessSigOps("]


def require(condition, detail):
    if not condition:
        raise ValueError(detail)


def extract(source, signature):
    start = source.index(signature)
    brace = source.index("{", start)
    depth = 0
    for pos in range(brace, len(source)):
        depth += (source[pos] == "{") - (source[pos] == "}")
        if depth == 0:
            return source[start:pos + 1]
    raise ValueError(f"Unclosed function: {signature}")


SHIM = r"""
#include <cassert>
#include <cstdint>
#include <iostream>
#include <string>
#include <vector>
enum opcodetype {
 OP_0=0, OP_PUSHDATA1=0x4c, OP_PUSHDATA2=0x4d, OP_PUSHDATA4=0x4e,
 OP_1=0x51, OP_16=0x60, OP_EQUAL=0x87, OP_HASH160=0xa9,
 OP_CHECKSIG=0xac, OP_CHECKSIGVERIFY=0xad, OP_CHECKMULTISIG=0xae,
 OP_CHECKMULTISIGVERIFY=0xaf, OP_INVALIDOPCODE=0xff
};
constexpr unsigned MAX_PUBKEYS_PER_MULTISIG=20;
constexpr size_t WITNESS_V0_KEYHASH_SIZE=20, WITNESS_V0_SCRIPTHASH_SIZE=32;
using script_verify_flags=unsigned;
constexpr script_verify_flags SCRIPT_VERIFY_P2SH=1, SCRIPT_VERIFY_WITNESS=1<<11;
uint16_t ReadLE16(const unsigned char* p) { return p[0] | uint16_t(p[1])<<8; }
uint32_t ReadLE32(const unsigned char* p) {
 return p[0] | uint32_t(p[1])<<8 | uint32_t(p[2])<<16 | uint32_t(p[3])<<24;
}
using CScriptBase=std::vector<unsigned char>;
bool GetScriptOp(CScriptBase::const_iterator&, CScriptBase::const_iterator,
                 opcodetype&, std::vector<unsigned char>*);
struct CScript : CScriptBase {
 using CScriptBase::CScriptBase;
 static int DecodeOP_N(opcodetype op) { return op==OP_0 ? 0 : int(op)-int(OP_1)+1; }
 bool GetOp(const_iterator& pc, opcodetype& op) const {
   return GetScriptOp(pc, end(), op, nullptr);
 }
 bool GetOp(const_iterator& pc, opcodetype& op, std::vector<unsigned char>& data) const {
   return GetScriptOp(pc, end(), op, &data);
 }
 unsigned GetSigOpCount(bool) const;
 unsigned GetSigOpCount(const CScript&) const;
 bool IsPayToScriptHash() const;
 bool IsWitnessProgram(int&, std::vector<unsigned char>&) const;
 bool IsPushOnly(const_iterator) const;
 bool IsPushOnly() const;
};
struct CScriptWitness { std::vector<std::vector<unsigned char>> stack; };
CScript hex(const std::string& h) {
 CScript out;
 for (size_t i=0; i<h.size(); i+=2) out.push_back(std::stoul(h.substr(i,2),nullptr,16));
 return out;
}
CScript push(CScript data) {
 assert(data.size()<=75);
 CScript out{(unsigned char)data.size()}; out.insert(out.end(),data.begin(),data.end()); return out;
}
CScript cat(CScript a, CScript b) { a.insert(a.end(),b.begin(),b.end()); return a; }
"""

DRIVER = r"""
int main() {
 const CScript p2sh=hex("a914"+std::string(40,'0')+"87");
 const CScript wpkh=hex("0014"+std::string(40,'1'));
 const CScript wsh=hex("0020"+std::string(64,'1'));
 auto check=[](std::string name, size_t actual, size_t expected) {
   std::cout<<name<<'\t'<<actual<<'\t'<<expected<<'\n';
 };
 check("accurate per-CMS lookback",hex("52ae53af").GetSigOpCount(true),5);
 check("inaccurate CMS is twenty",hex("52ae53af").GetSigOpCount(false),40);
 check("trailing OP_N adds nothing",hex("ac60").GetSigOpCount(true),1);
 check("intervening opcode clears lookback",hex("5261ae").GetSigOpCount(true),20);
 check("pushed sigops are data",hex("03acaeafad").GetSigOpCount(true),1);
 check("truncated direct push retains prefix",hex("ac02ae").GetSigOpCount(true),1);
 check("truncated PUSHDATA1 length retains prefix",hex("ac4c").GetSigOpCount(true),1);
 check("truncated PUSHDATA1 payload retains prefix",hex("52ae4c02ac").GetSigOpCount(true),2);
 check("truncated PUSHDATA2 length retains prefix",hex("ad4d01").GetSigOpCount(true),1);
 check("truncated PUSHDATA4 length retains prefix",hex("af4e000000").GetSigOpCount(true),20);
 check("P2SH redeem bytes are counted directly",p2sh.GetSigOpCount(push(hex("52ae"))),2);
 check("P2SH valid redeem prefix survives",p2sh.GetSigOpCount(push(hex("ac4c"))),1);
 auto nonpush=cat(hex("76"),push(hex("ac")));
 check("P2SH non-push prefix is rejected",p2sh.GetSigOpCount(nonpush),0);
 check("rule P2SH non-push prefix is rejected",p2sh.GetSigOpCount(nonpush),0);
 check("block P2SH non-push prefix is rejected",p2sh.GetSigOpCount(nonpush),0);
 auto malformed=cat(push(hex("ac")),hex("4c"));
 check("P2SH truncated scriptSig returns zero",p2sh.GetSigOpCount(malformed),0);
 check("block truncated scriptSig returns zero",p2sh.GetSigOpCount(malformed),0);
 check("small-int tail clears redeem data",p2sh.GetSigOpCount(cat(push(hex("ac")),hex("51"))),0);
 check("OP_RESERVED tail clears redeem data",p2sh.GetSigOpCount(cat(push(hex("ac")),hex("50"))),0);
 const auto flags=SCRIPT_VERIFY_P2SH|SCRIPT_VERIFY_WITNESS;
 auto witness=[&](CScript ss, CScript spk, CScriptWitness w) {
   return CountWitnessSigOps(ss,spk,w,flags);
 };
 check("witness P2WSH retains valid prefix",witness({},wsh,{{hex("ac4c")}}),1);
 check("wrapped witness requires push-only",witness(cat(hex("76"),push(wpkh)),p2sh,{}),0);
 check("wrapped P2WPKH counts without witness",witness(push(wpkh),p2sh,{}),1);
 check("native P2WPKH counts without witness",witness({},wpkh,{}),1);
 check("wrapped P2WSH accurate count",witness(push(wsh),p2sh,{{hex("52ae")}}),2);
 check("native P2WSH accurate count",witness({},wsh,{{hex("52ae")}}),2);
 check("empty witness P2WSH counts zero",witness({},wsh,{}),0);
 check("future witness counts zero",WitnessSigOps(1,std::vector<unsigned char>(32,1),{{hex("ac")}}),0);
 check("legacy malformed script retains prefix",hex("ae4c").GetSigOpCount(false),20);
}
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--script", required=True, type=Path)
    parser.add_argument("--interpreter", required=True, type=Path)
    parser.add_argument("--lean-log", type=Path, help="Compare exact named Lean results")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--cxx", default="c++", help="Compatible installed C++ compiler")
    args = parser.parse_args()
    source_hashes = tuple(hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in [args.script, args.interpreter])
    if source_hashes not in SOURCE_PAIRS:
        parser.error("source files do not match either supported immutable Core revision")
    bodies = {s: extract(args.script.read_text(), s) for s in SCRIPT_FUNCTIONS}
    bodies.update({s: extract(args.interpreter.read_text(), s) for s in INTERPRETER_FUNCTIONS})
    with tempfile.TemporaryDirectory(prefix="btc-sigops-core-") as folder:
        source = Path(folder)/"sigops.cpp"
        binary = Path(folder)/"sigops"
        source.write_text(SHIM + "\n".join(bodies.values()) + DRIVER)
        subprocess.run([args.cxx, "-std=c++17", "-O2", str(source), "-o", str(binary)], check=True)
        output = subprocess.check_output([str(binary)], text=True)
    results = {}
    for line in output.splitlines():
        name, actual, expected = line.split("\t")
        require(name not in results, f"duplicate result: {name}")
        require(int(actual) == int(expected), line)
        results[name] = int(actual)
    require(len(results) == 28, results)
    if args.lean_log:
        import re
        lean = dict((m[1], int(m[3])) for m in re.finditer(
            r"^\[(?:PASS|FAIL)\] (.*): expected=(\d+), actual=(\d+)$",
            args.lean_log.read_text(), re.MULTILINE))
        require(lean == results, {k: (lean.get(k), v) for k, v in results.items() if lean.get(k) != v})
    report = {
        "kind": "extracted_pinned_core_function_harness",
        "core_commit": SOURCE_PAIRS[source_hashes],
        "compiler": args.cxx,
        "functions_sha256": {s: hashlib.sha256(b.encode()).hexdigest() for s,b in bodies.items()},
        "source_sha256": {str(p): hashlib.sha256(p.read_bytes()).hexdigest()
                          for p in [args.script, args.interpreter]},
        "checks": results,
        "lean_results_compared": args.lean_log is not None,
    }
    if args.output:
        args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(f"Core function harness: {len(results)} checks passed; Lean comparison={args.lean_log is not None}")


if __name__ == "__main__":
    main()
