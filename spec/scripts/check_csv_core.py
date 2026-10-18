#!/usr/bin/env python3
"""Execute pinned Core CheckSequence with its actual unsigned version field.

The unchanged function body runs against minimal transaction/CScriptNum shims.
This checks the transaction-side gate, mask and comparison, not script decoding,
OP_CSV's operand-disable/activation gates, or whole-block Core acceptance.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

from check_sigops_core import SOURCE_PAIRS, extract, require

HEADERS = {
    "cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66":
        "329c0f009edcda9dc2d3ff00e16066b1ff0f47d349a74c5cfb933aec4492c3fa",
    "9be056a8a72b624dae9623b2f7bded92c2a21c91":
        "83d6f8a6f5e2c7e0f7d80b30758a6ce4ac0ffac14c03626417552b04f627b1e2",
}

SHIM = r'''
#include <cassert>
#include <cstdint>
#include <iostream>
#include <vector>
struct CScriptNum {
 int64_t value;
 CScriptNum(int64_t v):value(v){}
 CScriptNum operator&(uint32_t mask) const {return value & mask;}
 bool operator<(int64_t other) const {return value < other;}
 bool operator>=(int64_t other) const {return value >= other;}
 bool operator>(int64_t other) const {return value > other;}
};
struct CTxIn {
 static constexpr uint32_t SEQUENCE_LOCKTIME_DISABLE_FLAG=1U<<31;
 static constexpr uint32_t SEQUENCE_LOCKTIME_TYPE_FLAG=1U<<22;
 static constexpr uint32_t SEQUENCE_LOCKTIME_MASK=0xffff;
 uint32_t nSequence;
};
struct CTransaction { const uint32_t version; std::vector<CTxIn> vin; };
template<class T>struct GenericTransactionSignatureChecker {
 const T* txTo; unsigned nIn;
 bool CheckSequence(const CScriptNum&) const;
};
'''

DRIVER = r'''
void test(const char* name,uint32_t version,uint32_t sequence,int64_t operand,bool expected){
 CTransaction tx{version,{{sequence}}};
 bool result=GenericTransactionSignatureChecker<CTransaction>{&tx,0}.CheckSequence(CScriptNum(operand));
 std::cout<<name<<"\t"<<(result?"pass":"unsatisfiedLocktime")<<"\n";
 assert(result==expected);
}
int main(){
 test("wire ffffffff version",0xffffffff,1,1,true);
 test("wire fffffffe version",0xfffffffe,1,1,true);
 test("wire 80000000 version",0x80000000,1,1,true);
 test("wire 80000001 version",0x80000001,1,1,true);
 test("wire 7fffffff version",0x7fffffff,1,1,true);
 test("version two control",2,1,1,true);
 test("version three control",3,1,1,true);
 test("version zero rejects",0,1,1,false);
 test("version one rejects",1,1,1,false);
 test("high-bit version insufficient sequence",0xffffffff,0,1,false);
 test("high-bit version disabled input",0xffffffff,0x80000001,1,false);
 test("high-bit version type mismatch",0xffffffff,0x00400001,1,false);
 test("high-bit version time equality",0xffffffff,0x00400001,0x00400001,true);
 test("high-bit version time overrun",0xffffffff,0x00400001,0x00400002,false);
 test("high-bit version reserved sequence bits",0xffffffff,0x00010001,1,true);
}
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--interpreter", type=Path, required=True)
    ap.add_argument("--transaction-header", type=Path, required=True)
    ap.add_argument("--lean-log", type=Path, required=True)
    ap.add_argument("--output", type=Path)
    ap.add_argument("--cxx", default="c++")
    args = ap.parse_args()
    source, header = args.interpreter.read_bytes(), args.transaction_header.read_bytes()
    source_hash = hashlib.sha256(source).hexdigest()
    pins = {pair[1]: pin for pair, pin in SOURCE_PAIRS.items()}
    require(source_hash in pins, "unsupported Core interpreter source hash")
    pin = pins[source_hash]
    require(hashlib.sha256(header).hexdigest() == HEADERS[pin], "wrong transaction header/pin")
    require(b"const uint32_t version;" in header and b"    uint32_t version;" in header,
            "Core immutable and mutable transaction versions must both be uint32_t")
    body = extract(source.decode(), "bool GenericTransactionSignatureChecker<T>::CheckSequence(")
    with tempfile.TemporaryDirectory(prefix="core-csv-") as folder:
        cpp, binary = Path(folder)/"check.cpp", Path(folder)/"check"
        cpp.write_text(SHIM+"\ntemplate<class T>\n"+body+"\n"+DRIVER)
        build = subprocess.run([args.cxx, "-std=c++20", "-O2", str(cpp), "-o", str(binary)],
                               capture_output=True, text=True, timeout=60)
        require(build.returncode == 0, build.stdout+build.stderr)
        run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=30)
        require(run.returncode == 0, run.stdout+run.stderr)
    checks = dict(line.split("\t") for line in run.stdout.splitlines())
    require(len(checks) == 15, "incomplete Core check set")
    lean_rows = re.findall(r"^\[PASS\] (.*): expected=(.*), actual=(.*)$",
                           args.lean_log.read_text(), re.MULTILINE)
    lean = {name: "pass" if actual == "ok:1:0" else actual.rsplit(".", 1)[-1]
            for name, expected, actual in lean_rows if expected == actual}
    require(all(lean.get(name) == result for name, result in checks.items()),
            "Core results disagree with repaired public Lean transaction stage")
    report = dict(core_commit=pin, interpreter_sha256=source_hash,
                  transaction_header_sha256=hashlib.sha256(header).hexdigest(),
                  function_sha256=hashlib.sha256(body.encode()).hexdigest(),
                  transaction_version_type="uint32_t", checks=checks, scope=__doc__.strip(),
                  cpp_standard="c++20", compile_timeout_seconds=60, run_timeout_seconds=30)
    output = json.dumps(report, indent=2)+"\n"
    if args.output:
        args.output.write_text(output)
    print(output, end="")


if __name__ == "__main__":
    main()
