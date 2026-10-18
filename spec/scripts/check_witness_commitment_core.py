#!/usr/bin/env python3
"""Execute two unchanged witness-check functions from either immutable Core pin.

Uses container/state shims and CommonCrypto SHA256d. The witness-merkle root
shim is limited to a single-coinbase block (whose leaf is zero). This is not
Core block parsing, amount validation, full chain validation or a Lean proof.
"""

import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile

from check_sigops_core import extract, require

PINS = {
    ("9fad490f96c86ec1561434d01fddba85f304f9304e816958698a21a16486e416",
     "2875af77e8e0d4db5b210bc716f37713bd0bd8922dde60713e611b33cdf1806a"):
        "cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66",
    ("b315005125a410a8ac1b920ae4a500eaf830c5aa8ddbcc16fd4b10c97bd49901",
     "a05efe3196a6fec585622102d91c4f7558f1bf56c642cc0df5a21640594a73bf"):
        "9be056a8a72b624dae9623b2f7bded92c2a21c91",
}

SHIM = r"""
#include <CommonCrypto/CommonDigest.h>
#include <algorithm>
#include <array>
#include <cassert>
#include <cstring>
#include <iostream>
#include <memory>
#include <string>
#include <vector>
using Bytes=std::vector<unsigned char>;
using uint256=std::array<unsigned char,32>;
using CScript=Bytes;
constexpr int NO_WITNESS_COMMITMENT=-1, MINIMUM_WITNESS_COMMITMENT=38, OP_RETURN=0x6a;
struct CScriptWitness { std::vector<Bytes> stack; };
struct CTxIn { CScriptWitness scriptWitness; };
struct CTxOut { int64_t nValue; CScript scriptPubKey; };
struct CTransaction {
 std::vector<CTxIn> vin; std::vector<CTxOut> vout;
 bool HasWitness() const {
  for(const auto& in:vin) if(!in.scriptWitness.stack.empty()) return true;
  return false;
 }
};
struct CBlock {
 std::vector<std::shared_ptr<CTransaction>> vtx;
 mutable bool m_checked_witness_commitment=false;
};
enum class BlockValidationResult { BLOCK_MUTATED };
struct BlockValidationState {
 std::string reason;
 bool Invalid(BlockValidationResult, const char* why, std::string) { reason=why; return false; }
};
template<class... Args> std::string strprintf(const char*,Args...) { return {}; }
uint256 BlockWitnessMerkleRoot(const CBlock& b) {
 assert(b.vtx.size()==1 && b.vtx[0]->vin.size()==1); return {};
}
struct CHash256 {
 Bytes data;
 template<class T> CHash256& Write(const T& v) {
  data.insert(data.end(),v.begin(),v.end()); return *this;
 }
 void Finalize(uint256& out) {
  unsigned char mid[32]; CC_SHA256(data.data(),data.size(),mid); CC_SHA256(mid,32,out.data());
 }
};
Bytes hex(std::string s) {
 Bytes b; for(size_t n=0;n<s.size();n+=2) b.push_back(std::stoul(s.substr(n,2),nullptr,16)); return b;
}
void test(std::string name, CBlock block, bool active, std::string want);
"""


def decode_coinbase(data):
    """Independent limited decoder for the one-coinbase BIP144 fixture."""
    pos = 80

    def take(n):
        nonlocal pos
        out = data[pos:pos+n]
        require(len(out) == n, "truncated fixture")
        pos += n
        return out

    def compact():
        n = take(1)[0]
        return n if n < 253 else int.from_bytes(take({253: 2, 254: 4, 255: 8}[n]), "little")

    require(compact() == 1 and take(4) == struct.pack("<I", 1) and take(2) == b"\x00\x01",
            "unexpected witness framing")
    require(compact() == 1 and take(36) == bytes(32)+b"\xff"*4, "not one coinbase input")
    ss = take(compact())
    require(ss == b"\x03"+(481824).to_bytes(3, "little") and take(4) == b"\xff"*4,
            "unexpected coinbase fields")
    outputs = [(int.from_bytes(take(8), "little", signed=True), take(compact()))
               for _ in range(compact())]
    witness = [take(compact()) for _ in range(compact())]
    require(take(4) == bytes(4) and pos == len(data), "trailing data")
    return outputs, witness


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for name in ["validation", "consensus-validation", "fixture"]:
        ap.add_argument("--"+name, type=Path, required=True)
    ap.add_argument("--cxx", default="c++")
    ap.add_argument("--output", type=Path)
    args = ap.parse_args()
    paths = [args.validation, args.consensus_validation]
    hashes = tuple(hashlib.sha256(p.read_bytes()).hexdigest() for p in paths)
    require(hashes in PINS, "unsupported Core source hashes")
    bodies = {"GetWitnessCommitmentIndex": extract(paths[1].read_text(), "inline int GetWitnessCommitmentIndex("),
              "CheckWitnessMalleation": extract(paths[0].read_text(), "static bool CheckWitnessMalleation(")}
    outputs, witness = decode_coinbase(args.fixture.read_bytes())
    out_cpp = ",".join('{'+str(v)+',hex("'+s.hex()+'")} ' for v, s in outputs)
    wit_cpp = ",".join('hex("'+s.hex()+'")' for s in witness)
    driver = r"""
void test(std::string name, CBlock block, bool active, std::string want) {
 block.m_checked_witness_commitment=false;
 BlockValidationState state;
 bool ok=CheckWitnessMalleation(block,active,state);
 std::string actual=ok ? "ok" : state.reason;
 std::cout<<name<<"\t"<<actual<<"\n";
 if(actual!=want) throw std::runtime_error("verdict mismatch: "+name);
}
int main() {
 auto tx=std::make_shared<CTransaction>();
 tx->vin={{{{WITNESS}}}}; tx->vout={OUTPUTS}; CBlock b{{tx}};
 test("nonzero outputs at exact subsidy",b,true,"ok");
 for(auto& out:tx->vout) out.nValue=0;
 test("zero-valued outputs also valid",b,true,"ok");
 tx->vin[0].scriptWitness.stack.clear();
 test("missing reserved item",b,true,"bad-witness-nonce-size");
 tx->vin[0].scriptWitness.stack={Bytes(31,1)};
 test("31-byte reserved item",b,true,"bad-witness-nonce-size");
 tx->vin[0].scriptWitness.stack={Bytes(33,1)};
 test("33-byte reserved item",b,true,"bad-witness-nonce-size");
 tx->vin[0].scriptWitness.stack={Bytes(32,1),Bytes{}};
 test("two reserved items",b,true,"bad-witness-nonce-size");
 tx->vin[0].scriptWitness.stack={Bytes(32,0)};
 test("last matching output binds actual reserved item",b,true,"bad-witness-merkle-match");
 std::reverse(tx->vout.begin(),tx->vout.end());
 test("reversing outputs changes selected commitment",b,true,"ok");
 test("preactivation rejects witness",b,false,"unexpected-witness");
 tx->vin[0].scriptWitness.stack.clear();
 test("preactivation permits commitment without witness",b,false,"ok");
 tx->vout.clear();
 test("absent commitment without witness",b,true,"ok");
 tx->vin[0].scriptWitness.stack={Bytes(32,1)};
 test("absent commitment with witness",b,true,"unexpected-witness");
}
""".replace("WITNESS", wit_cpp).replace("OUTPUTS", out_cpp)
    with tempfile.TemporaryDirectory(prefix="core-witness-") as folder:
        source, binary = Path(folder)/"check.cpp", Path(folder)/"check"
        source.write_text(SHIM+"\n"+"\n".join(bodies.values())+"\n"+driver)
        subprocess.run([args.cxx, "-std=c++17", "-O2", str(source), "-o", str(binary)], check=True,
                       capture_output=True, text=True, timeout=60)
        proc = subprocess.run([str(binary)], check=True, capture_output=True, text=True, timeout=30)
    checks = dict(line.split("\t") for line in proc.stdout.splitlines())
    require(len(checks) == 12, "missing reference cases")
    report = dict(core_commit=PINS[hashes], reference_class="two extracted functions with container/state/single-coinbase-merkle shims and CommonCrypto SHA256d",
                  source_sha256={str(p): h for p, h in zip(paths, hashes)},
                  functions_sha256={k: hashlib.sha256(v.encode()).hexdigest() for k, v in bodies.items()},
                  fixture_sha256=hashlib.sha256(args.fixture.read_bytes()).hexdigest(), checks=checks,
                  scope="Witness-selection/shape/hash/verdict checks only; no Core parser, amount/reward, PoW or full-block validation.")
    output = json.dumps(report, indent=2)+"\n"
    if args.output:
        args.output.write_text(output)
    print(output, end="")


if __name__ == "__main__":
    main()
