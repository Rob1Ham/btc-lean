#!/usr/bin/env python3
"""Execute pinned Core GetBlockScriptFlags and mainnet exception parameters.

Minimal flag-word, index/hash-map and buried-deployment seams are supplied.
The actual function body and pinned mainnet hashes/heights are used. This
tests flag selection/ordering, not script execution or whole-Core validation.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

from check_sigops_core import extract, require

PINS = {
    ("9fad490f96c86ec1561434d01fddba85f304f9304e816958698a21a16486e416",
     "cfadf1478377c32625280520655b598674e6d487f08d7f7a80ac69252104b5e1"):
        "cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66",
    ("b315005125a410a8ac1b920ae4a500eaf830c5aa8ddbcc16fd4b10c97bd49901",
     "839bbbe05d6981d2f37cb8cedb319dd16657b60f6223bb2c21e6b9a9c70d4b8f"):
        "9be056a8a72b624dae9623b2f7bded92c2a21c91",
}

SHIM = r'''
#include <array>
#include <cassert>
#include <iostream>
#include <map>
#include <string>
using script_verify_flags=unsigned;
using uint256=std::string;
constexpr unsigned SCRIPT_VERIFY_NONE=0,SCRIPT_VERIFY_P2SH=1,SCRIPT_VERIFY_WITNESS=2,
 SCRIPT_VERIFY_TAPROOT=4,SCRIPT_VERIFY_DERSIG=8,SCRIPT_VERIFY_CHECKLOCKTIMEVERIFY=16,
 SCRIPT_VERIFY_CHECKSEQUENCEVERIFY=32,SCRIPT_VERIFY_NULLDUMMY=64;
namespace Consensus {
enum Deployment {DEPLOYMENT_DERSIG,DEPLOYMENT_CLTV,DEPLOYMENT_CSV,DEPLOYMENT_SEGWIT};
struct Params {std::map<uint256,unsigned> script_flag_exceptions;std::array<int,4> heights;};
}
struct CBlockIndex {int nHeight;const uint256* phashBlock;};
struct ChainstateManager {
 Consensus::Params params;
 const Consensus::Params& GetConsensus()const{return params;}
};
template<class T>const T* Assert(const T* p){assert(p);return p;}
bool DeploymentActiveAt(const CBlockIndex& b,const ChainstateManager& c,Consensus::Deployment d){
 return b.nHeight>=c.params.heights[d];
}
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--validation", type=Path, required=True)
    ap.add_argument("--chainparams", type=Path, required=True)
    ap.add_argument("--lean-log", type=Path)
    ap.add_argument("--output", type=Path)
    ap.add_argument("--cxx", default="c++")
    args = ap.parse_args()
    data, params = args.validation.read_bytes(), args.chainparams.read_bytes()
    hashes = tuple(hashlib.sha256(x).hexdigest() for x in [data, params])
    require(hashes in PINS, "unsupported or mismatched Core source pair")
    body = extract(data.decode(), "script_verify_flags GetBlockScriptFlags(")
    mainnet = params.decode().split("class CMainParams", 1)[1].split("class CTestNetParams", 1)[0]
    exceptions = re.findall(r'consensus.script_flag_exceptions.emplace\(\s*//[^\n]*\n\s*'
                            r'uint256\{"([0-9a-f]+)"\},\s*([^;]+)\);', mainnet)
    require(len(exceptions) == 2, "expected two mainnet exception entries")
    keys = ["BIP66Height", "BIP65Height", "CSVHeight", "SegwitHeight"]
    heights = [int(re.search(r'consensus\.'+key+r' = (\d+);', mainnet)[1]) for key in keys]
    alternate = "00000000d1145790a8694403d4063f323d499e655c83426834d4ce2f8dd4a2ee"
    cases = [("P2SH alternate", alternate, 170060), ("P2SH named", exceptions[0][0], 170060),
             ("Taproot alternate", alternate, 692261), ("Taproot named", exceptions[1][0], 692261),
             ("buried flags survive P2SH replacement", exceptions[0][0], 692261),
             ("Taproot replacement before buried gates", exceptions[1][0], 0)]
    for name, height in zip(["DERSIG", "CLTV", "CSV", "NULLDUMMY"], heights):
        cases.extend([(name+" before", alternate, height-1), (name+" at", alternate, height)])
    setup = "ChainstateManager c;\n"+"\n".join(
        f'c.params.script_flag_exceptions.emplace("{key}",{value});' for key, value in exceptions)
    setup += "\nc.params.heights={"+",".join(map(str, heights))+"};\n"
    driver = 'int main(){std::cout<<std::boolalpha;\n'+setup
    for name, hash_value, height in cases:
        driver += f'{{uint256 h="{hash_value}";CBlockIndex b{{{height},&h}};auto f=GetBlockScriptFlags(b,c);'
        driver += f'std::cout<<"{name}\\t";'
        flags = ["P2SH", "WITNESS", "TAPROOT", "DERSIG", "CHECKLOCKTIMEVERIFY",
                 "CHECKSEQUENCEVERIFY", "NULLDUMMY"]
        driver += "std::cout"+"<<\":\"".join(f'<<bool(f&SCRIPT_VERIFY_{flag})' for flag in flags)
        driver += '<<"\\n";}\n'
    driver += '}\n'
    with tempfile.TemporaryDirectory(prefix="core-script-flags-") as folder:
        cpp, binary = Path(folder)/"check.cpp", Path(folder)/"check"
        cpp.write_text(SHIM+"\n"+body+"\n"+driver)
        build = subprocess.run([args.cxx, "-std=c++20", "-O2", str(cpp), "-o", str(binary)],
                               capture_output=True, text=True, timeout=60)
        require(build.returncode == 0, build.stdout+build.stderr)
        run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=30)
        require(run.returncode == 0, run.stdout+run.stderr)
    checks = dict(line.split("\t") for line in run.stdout.splitlines())
    require(len(checks) == 14, "incomplete flag cases")
    if args.lean_log:
        rows = re.findall(r'^\[PASS\] selector (.*): expected=(.*), actual=(.*)$',
                          args.lean_log.read_text(), re.MULTILINE)
        lean = {name: actual for name, expected, actual in rows if expected == actual}
        require(lean == checks, "Core and Lean flag selectors disagree")
    report = dict(core_commit=PINS[hashes], validation_sha256=hashes[0],
                  chainparams_sha256=hashes[1], function_sha256=hashlib.sha256(body.encode()).hexdigest(),
                  exceptions=exceptions, buried_heights=dict(zip(keys, heights)), checks=checks,
                  cases=[dict(name=name, hash=hash_value, height=height, flags=checks[name])
                         for name, hash_value, height in cases], scope=__doc__.strip(),
                  compile_timeout_seconds=60, run_timeout_seconds=30)
    output = json.dumps(report, indent=2)+"\n"
    if args.output:
        args.output.write_text(output)
    print(output, end="")


if __name__ == "__main__":
    main()
