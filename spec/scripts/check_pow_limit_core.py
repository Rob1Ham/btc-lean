#!/usr/bin/env python3
"""Check exact Core network limits and execute its compact encoder.

Pinned chainparams literals and unchanged bits/right-shift/GetCompact bodies
are used. Shims supply the word container, low-word read, construction and
CeilDiv. This is a parameter/encoding check, not whole-Core block validation.
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
    ("cfadf1478377c32625280520655b598674e6d487f08d7f7a80ac69252104b5e1",
     "0bf5e52d78e6454c566b46675903d0980e7905b4c03f91cabb1be110ad9818f5"):
        "cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66",
    ("839bbbe05d6981d2f37cb8cedb319dd16657b60f6223bb2c21e6b9a9c70d4b8f",
     "b09fca6c7f1a170585f0255855a2da7f8019b5db37f2de9bbfab131685238e9e"):
        "9be056a8a72b624dae9623b2f7bded92c2a21c91",
}

SHIM = r'''
#include <cassert>
#include <cstdint>
#include <iostream>
#include <string>
unsigned CeilDiv(unsigned n,unsigned d){return n/d+(n%d!=0);}
template<unsigned BITS>struct base_uint {
 static constexpr int WIDTH=BITS/32;
 uint32_t pn[WIDTH]{};
 unsigned bits() const;
 base_uint& operator>>=(unsigned);
 uint64_t GetLow64() const {return uint64_t(pn[0])|(uint64_t(pn[1])<<32);}
};
struct arith_uint256:base_uint<256> {
 explicit arith_uint256(std::string hex){
  assert(hex.size()==64);
  for(int i=0;i<WIDTH;i++)pn[i]=std::stoul(hex.substr(64-8*(i+1),8),nullptr,16);
 }
 arith_uint256 operator>>(unsigned n)const{auto copy=*this;copy>>=n;return copy;}
 uint32_t GetCompact(bool negative=false)const;
};
'''


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--chainparams", type=Path, required=True)
    ap.add_argument("--arith", type=Path, required=True)
    ap.add_argument("--cases", type=Path, required=True)
    ap.add_argument("--output", type=Path)
    ap.add_argument("--cxx", default="c++")
    args = ap.parse_args()
    params, arith = args.chainparams.read_bytes(), args.arith.read_bytes()
    hashes = tuple(hashlib.sha256(x).hexdigest() for x in [params, arith])
    require(hashes in PINS, "unsupported or mismatched Core source pair")
    limits = re.findall(r'consensus.powLimit = uint256\{"([0-9a-f]+)"\}', params.decode())
    expected = ["00000000"+"f"*56]*3+[
        "00000377ae"+"0"*54, "7"+"f"*63]
    require(limits == expected, "unexpected network parameter literals")
    functions = {"bits": extract(arith.decode(), "unsigned int base_uint<BITS>::bits()"),
                 "right_shift": extract(arith.decode(), "base_uint<BITS>& base_uint<BITS>::operator>>=("),
                 "GetCompact": extract(arith.decode(), "uint32_t arith_uint256::GetCompact(")}
    cases = json.loads(args.cases.read_text())
    encoded = [x for x in cases if "target" in x and "nbits_core" in x]
    require(len(encoded) >= 45, "incomplete encoding corpus")
    rows = []
    for case in encoded:
        require(0 <= case["target"] < 2**256, "encoding target outside shim's 256-bit domain")
        rows.append((case["id"], f'{case["target"]:064x}', case["nbits_core"]))
    rows.extend([("mainnet-limit", limits[0], 0x1d00ffff),
                 ("testnet3-limit", limits[1], 0x1d00ffff),
                 ("testnet4-limit", limits[2], 0x1d00ffff)])
    driver = 'int main(){\n'+"\n".join(
        f'{{auto n=arith_uint256("{value}").GetCompact();assert(n=={bits}U);'
        f'std::cout<<"{name}\\t"<<n<<"\\n";}}' for name, value, bits in rows)+'\n}\n'
    with tempfile.TemporaryDirectory(prefix="core-pow-limit-") as folder:
        cpp, binary = Path(folder)/"check.cpp", Path(folder)/"check"
        cpp.write_text(SHIM+"\ntemplate<unsigned BITS>\n"+functions["bits"]+
                       "\ntemplate<unsigned BITS>\n"+functions["right_shift"]+
                       "\n"+functions["GetCompact"]+"\n"+driver)
        build = subprocess.run([args.cxx, "-std=c++20", "-O2", str(cpp), "-o", str(binary)],
                               capture_output=True, text=True, timeout=60)
        require(build.returncode == 0, build.stdout+build.stderr)
        run = subprocess.run([str(binary)], capture_output=True, text=True, timeout=30)
        require(run.returncode == 0, run.stdout+run.stderr)
    results = dict(line.split("\t") for line in run.stdout.splitlines())
    require(len(results) == len(rows), "incomplete Core outputs")
    report = dict(core_commit=PINS[hashes], chainparams_sha256=hashes[0], arith_sha256=hashes[1],
                  functions_sha256={name: hashlib.sha256(body.encode()).hexdigest()
                                    for name, body in functions.items()},
                  network_limits=limits, encoding_cases=len(encoded),
                  explicit_network_encodings=3, checks=results,
                  cases_sha256=hashlib.sha256(args.cases.read_bytes()).hexdigest(),
                  scope=__doc__.strip(), compile_timeout_seconds=60, run_timeout_seconds=30)
    output = json.dumps(report, indent=2)+"\n"
    if args.output:
        args.output.write_text(output)
    print(output, end="")


if __name__ == "__main__":
    main()
