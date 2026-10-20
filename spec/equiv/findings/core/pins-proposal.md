# Proposed `PINS.lock` updates (CORE-IR)

CORE-IR does not own `PINS.lock`; these are the values the orchestrator should
merge. They replace `[core] build = TODO` and add the proof IR fingerprints.
Re-pinning after a patch change is a new result.

```toml
[core]
commit = cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66
version = v32.99
source = bitcoin/bitcoin
build = single-TU: /usr/bin/clang++-20 -std=c++20 -O0 -g0 -emit-llvm -c
        -I src -I build-ir/src -I src/secp256k1/include -I src/univalue/include
        src/script/interpreter.cpp
        (O1 robustness lane identical with -O1)
patches = none

[core.ir]
producer = Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)
lane = unpatched
O0_bc_sha256 = f5718af79c56ccfd5a5437a313d957573cb87c0de0cdf5641013991268801b2c
O1_bc_sha256 = 01003ec095441bad8ada96ed1effa860f84bda23802841c7d7eb15b2e554537f
O0_ftrapv_bc_sha256 = 714ad532b43be61c0f4fdc8f0ef9e45d36cae0b538e9f67cd8665511a6b5c576
root_symbols = CastToBool, operator|(script_verify_flags), EvalScript (7-arg),
               CScriptNum::getint, VerifyScript

[core.ir.patched]
status = PROPOSED (differential evidence not yet run)
macros = BTC_EQUIV_NO_SCRIPTNUM_THROW BTC_EQUIV_HOIST_STATICS BTC_EQUIV_DEVIRT
patches = P-CORE-01, P-CORE-02, P-CORE-03
O0_bc_sha256 = 5993460463314028bf1225784bbbcaa28dab7ab6fec979a17907a369cba302c7
O1_bc_sha256 = deebc447a4c2665efb6f83065420a099abdbaea1577d1c14b7822bfe003bfe6f
hoist_only_O0_bc_sha256 = 984177bd7a04ca402e0e3b6dbb60626b2be8c22abf2e5e3d2176678558b71819
erased_simplifycfg_O0_bc_sha256 = 3bfeecfb06cbecf41aa9edbf6cfe3c2c448f8e8df58d877e7936e4f965a33003
internalized_roots_bc_sha256 = 2b9f683c4fdd3550e4eab43083a4c528ce785d37956f0f24b75311ec756f04a8
note = erased hash is a derived transform (exception edges -> unreachable),
       not a source patch. Patched hash is reproducibility only, not an
       equivalence proof.

[llvm]
clang = 20.1.2 (Ubuntu 1:20.1.2-0ubuntu1~24.04.3; /usr/bin/clang-20,
        /usr/bin/clang++-20)
llvm_ir_version = 20.1.2 (/usr/lib/llvm-20/bin)
flags = -O0 primary, -O1 robustness, -O0 -ftrapv diagnostic lane
triple = x86_64-pc-linux-gnu
```

Retired (must not be cited): the clang 18.1.3 artifacts listed in
`NONPROOF-clang18.txt`.

The existing `[tools]` Alive2/SAW entries in `PINS.lock` are unchanged and
were the binaries used:

```
alive2 = v20.0 (c0f5434f402ad91714ee0952f686cd0f524920ad), LLVM 20.1.2, Z3 4.8.12
saw    = 1.6 (68eed5f), solvers incl. z3 4.8.14 / cvc5 1.3.1
```
