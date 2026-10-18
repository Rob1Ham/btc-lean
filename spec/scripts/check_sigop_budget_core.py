#!/usr/bin/env python3
"""Exercise exact pinned Core sigop functions and the ConnectBlock budget site.

Container/coin-view/state declarations are shims. The counter algorithms and
the budget loop fragment are extracted unchanged from hash-pinned sources.
This is resource-accounting reference evidence, not full Core block execution.
"""

import argparse
import hashlib
import json
from pathlib import Path
import struct
import subprocess
import tempfile

import check_sigops_core as base

EXTRA_HASHES = {
    "cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66": (
        "45de31c846d87b202b46f1e314cbd07869c0b3e598cdc7b18342e2fe24de3fc0",
        "9fad490f96c86ec1561434d01fddba85f304f9304e816958698a21a16486e416"),
    "9be056a8a72b624dae9623b2f7bded92c2a21c91": (
        "60470d6b8b19b82ca15e1e32dcb71cd8b3c55690c17ec2e7c2b279cf06b7c7bf",
        "b315005125a410a8ac1b920ae4a500eaf830c5aa8ddbcc16fd4b10c97bd49901"),
}
TX_FUNCTIONS = ["unsigned int GetLegacySigOpCount(", "unsigned int GetP2SHSigOpCount(",
                "int64_t GetTransactionSigOpCost("]

TX_SHIM = r"""
constexpr int WITNESS_SCALE_FACTOR=4, MAX_BLOCK_SIGOPS_COST=80000;
struct CTxIn { size_t prevout; CScript scriptSig; CScriptWitness scriptWitness; };
struct CTxOut { CScript scriptPubKey; };
struct CTransaction {
 std::vector<CTxIn> vin; std::vector<CTxOut> vout; bool coinbase;
 bool IsCoinBase() const { return coinbase; }
};
struct Coin { CTxOut out; bool IsSpent() const { return false; } };
struct CCoinsViewCache {
 std::vector<Coin> coins;
 const Coin& AccessCoin(size_t n) const { return coins.at(n); }
};
enum class BlockValidationResult { BLOCK_CONSENSUS };
struct State {
 std::string reason;
 void Invalid(BlockValidationResult, const char* why, const char*) { reason=why; }
};
CTransaction cb(CScript ss, CScript spk) { return {{{0,ss,{}}},{{spk}},true}; }
CTransaction spend(CScript ss, CScriptWitness w={}) { return {{{0,ss,w}},{{hex("51")}},false}; }
"""


def coinbase_scripts(data):
    """Independent decoder limited to the documented single-coinbase fixtures."""
    pos = 80

    def take(n):
        nonlocal pos
        out = data[pos:pos+n]
        base.require(len(out) == n, "truncated fixture")
        pos += n
        return out

    def compact():
        marker = take(1)[0]
        return marker if marker < 253 else int.from_bytes(take({253: 2, 254: 4, 255: 8}[marker]), "little")

    base.require(compact() == 1 and take(4) == struct.pack("<I", 1) and compact() == 1,
                 "unexpected transaction framing")
    base.require(take(36) == bytes(32)+b"\xff"*4, "not coinbase")
    ss = take(compact())
    base.require(take(4) == b"\xff"*4 and compact() == 1 and take(8) == bytes(8),
                 "unexpected coinbase fields")
    spk = take(compact())
    base.require(take(4) == bytes(4) and pos == len(data), "trailing data")
    return ss, spk


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    for name in ["script", "interpreter", "tx-verify", "validation", "fixtures"]:
        ap.add_argument("--"+name, required=True, type=Path)
    ap.add_argument("--cxx", default="c++")
    ap.add_argument("--output", type=Path)
    args = ap.parse_args()
    files = [args.script, args.interpreter, args.tx_verify, args.validation]
    hashes = tuple(hashlib.sha256(p.read_bytes()).hexdigest() for p in files)
    pin = base.SOURCE_PAIRS.get(hashes[:2])
    base.require(pin is not None and hashes[2:] == EXTRA_HASHES[pin], "unsupported Core source hashes")
    bodies = {s: base.extract(args.script.read_text(), s) for s in base.SCRIPT_FUNCTIONS}
    bodies.update({s: base.extract(args.interpreter.read_text(), s) for s in base.INTERPRETER_FUNCTIONS})
    bodies.update({s: base.extract(args.tx_verify.read_text(), s) for s in TX_FUNCTIONS})
    connect = base.extract(args.validation.read_text(), "bool Chainstate::ConnectBlock(")
    a = connect.index("        // GetTransactionSigOpCost counts 3 types of sigops:")
    b = connect.index("        if (!tx.IsCoinBase() && fScriptChecks)", a)
    site = connect[a:b]
    bodies["ConnectBlock sigop budget site"] = site
    prelude = base.extract(args.validation.read_text(), "bool CheckBlock(")
    positions = {name: connect.index(name) for name in ["Consensus::CheckTxInputs(", "MoneyRange(nFees)",
                  "SequenceLocks(tx,", "nSigOpsCost += GetTransactionSigOpCost(", "CheckInputScripts("]}
    base.require(list(positions.values()) == sorted(positions.values()), "ConnectBlock order drift")
    base.require(prelude.index("CheckTransaction(") < prelude.index("GetLegacySigOpCount("),
                 "CheckBlock order drift")
    decoded = {name: coinbase_scripts((args.fixtures/f"{name}.raw").read_bytes())
               for name in ["at-limit", "over-limit"]}
    definitions = "\n".join(f'auto {name.replace("-", "_")}=cb(hex("{ss.hex()}"),hex("{spk.hex()}"));'
                             for name,(ss,spk) in decoded.items())
    loop = """int64_t budget(const std::vector<CTransaction>& txs, const CCoinsViewCache& view,
       script_verify_flags flags, State& state) {
       int64_t nSigOpsCost=0;
       for(const auto& tx:txs) {
    """ + site + "\n}\nreturn nSigOpsCost;\n}\n"
    redeem = bytes([0,0x63,0xac,0x68,0x51])
    p2sh = b"\xa9\x14" + hashlib.new("ripemd160", hashlib.sha256(redeem).digest()).digest() + b"\x87"
    wscript = bytes([0,0x63]+[0xac]*4+[0x68,0x51])
    wspk = b"\x00\x20" + hashlib.sha256(wscript).digest()
    driver = r"""
int main() {
""" + definitions + r"""
 auto under=at_limit; under.vout[0].scriptPubKey=CScript(999,0xae);
 under.vout[0].scriptPubKey.insert(under.vout[0].scriptPubKey.end(),19,0xac);
 const auto flags=SCRIPT_VERIFY_P2SH|SCRIPT_VERIFY_WITNESS;
 CCoinsViewCache empty{};
 auto check=[](std::string name, std::vector<CTransaction> txs, CCoinsViewCache view, script_verify_flags f) {
   State state; auto total=budget(txs,view,f,state);
   std::cout<<name<<'\t'<<total<<'\t'<<(state.reason.empty()?"ok":state.reason)<<'\n';
 };
 check("mined exact limit",{at_limit},empty,flags);
 check("mined above limit",{over_limit},empty,flags);
 check("coinbase legacy ignores optional flags",{at_limit},empty,0);
""" + f'auto psh=spend(push(hex("{redeem.hex()}")));\nCCoinsViewCache pv{{{{Coin{{{{hex("{p2sh.hex()}")}}}}}}}};\n' + r"""
 check("P2SH exact cumulative limit",{under,psh},pv,flags);
 check("P2SH above cumulative limit",{at_limit,psh},pv,flags);
 check("P2SH disabled",{at_limit,psh},pv,0);
""" + f'auto wit=spend({{}},CScriptWitness{{{{hex("{wscript.hex()}")}}}});\nCCoinsViewCache wv{{{{Coin{{{{hex("{wspk.hex()}")}}}}}}}};\n' + r"""
 check("witness exact cumulative limit",{under,wit},wv,flags);
 check("witness above cumulative limit",{at_limit,wit},wv,flags);
 check("witness disabled",{at_limit,wit},wv,SCRIPT_VERIFY_P2SH);
}
"""
    with tempfile.TemporaryDirectory(prefix="btc-budget-core-") as folder:
        cpp, exe = Path(folder)/"budget.cpp", Path(folder)/"budget"
        # Type declarations must precede the functions that use them.
        cpp.write_text(base.SHIM + "\n".join(list(bodies.values())[:9]) + TX_SHIM +
                       "\n".join(bodies[s] for s in TX_FUNCTIONS) + loop + driver)
        subprocess.run([args.cxx,"-std=c++17","-O2",str(cpp),"-o",str(exe)], check=True)
        out = subprocess.check_output([str(exe)], text=True)
    expected = {"mined exact limit":(80000,"ok"), "mined above limit":(80004,"bad-blk-sigops"),
                "coinbase legacy ignores optional flags":(80000,"ok"), "P2SH exact cumulative limit":(80000,"ok"),
                "P2SH above cumulative limit":(80004,"bad-blk-sigops"), "P2SH disabled":(80000,"ok"),
                "witness exact cumulative limit":(80000,"ok"), "witness above cumulative limit":(80004,"bad-blk-sigops"),
                "witness disabled":(80000,"ok")}
    actual = {}
    for line in out.splitlines():
        name,total,reason = line.split("\t")
        base.require(name not in actual, "duplicate case")
        actual[name] = (int(total),reason)
    base.require(actual == expected, actual)
    report = {"core_commit":pin, "reference_class":"extracted functions and budget site with container/state shims",
              "checks":actual, "source_sha256":dict(zip(map(str,files),hashes)),
              "functions_sha256":{s:hashlib.sha256(body.encode()).hexdigest() for s,body in bodies.items()},
              "connect_order_offsets":positions, "checkblock_function_sha256":hashlib.sha256(prelude.encode()).hexdigest(),
              "fixture_sha256":{name:hashlib.sha256((args.fixtures/f"{name}.raw").read_bytes()).hexdigest()
                                for name in decoded},
              "scope":"Counter/budget behavior with supplied coin views; no Core parser, scripts, fees, BIP68 or whole-block verdict executed."}
    if args.output:
        args.output.write_text(json.dumps(report,indent=2)+"\n")
    print(f"Core budget reference: {len(actual)} checks passed at {pin}")


if __name__ == "__main__":
    main()
