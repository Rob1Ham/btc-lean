#!/usr/bin/env bash
# run.sh — W13 test runner: builds the Seam modules, runs the IO hash
# harness, and diffs its output against python3 hashlib (independent
# implementation cross-check).
set -euo pipefail
CORE="$(cd "$(dirname "$0")/../../core" && pwd)"
cd "$CORE"

echo "== lake build Seam modules =="
lake build Bitcoin.Crypto.Seam.Interface Bitcoin.Crypto.Seam.Hash \
  Bitcoin.Crypto.Seam.Der Bitcoin.Crypto.Seam.Entry \
  Bitcoin.Crypto.Seam.Mock Bitcoin.Crypto.Seam.Tests

echo "== SeamHashTest (native_decide vectors are build-time-checked above) =="
OUT="$(lake env lean --run ../Test/Crypto/SeamHashTest.lean)"
echo "$OUT"

echo "== diff against python3 hashlib =="
python3 - "$OUT" <<'PYEOF' > /dev/null && echo "hashlib cross-check: OK"
import hashlib, sys
out = {}
for line in sys.argv[1].splitlines():
    parts = line.split()
    name, algo, hexd = " ".join(parts[:-2]), parts[-2], parts[-1]
    out[(name, algo)] = hexd
def pad(b):
    ln = len(b); k = (55 + 64 - ln % 64) % 64
    return b + b'\x80' + b'\x00'*k + (ln*8).to_bytes(8, 'little')
def rmd(msg):
    # pure-python RIPEMD-160 (Bitcoin Core test_framework formulation)
    ML=[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,7,4,13,1,10,6,15,3,12,0,9,5,2,14,11,8,
        3,10,14,4,9,15,8,1,2,7,0,6,13,11,5,12,1,9,11,10,0,8,12,4,13,3,7,15,14,5,6,2,
        4,0,5,9,7,12,2,10,14,1,3,8,11,6,15,13]
    MR=[5,14,7,0,9,2,11,4,13,6,15,8,1,10,3,12,6,11,3,7,0,13,5,10,14,15,8,12,4,9,1,2,
        15,5,1,3,7,14,6,9,11,8,12,2,10,0,4,13,8,6,4,1,3,11,15,0,5,12,2,13,9,7,10,14,
        12,15,10,4,1,5,8,7,6,2,13,14,0,3,9,11]
    RL=[11,14,15,12,5,8,7,9,11,13,14,15,6,7,9,8,7,6,8,13,11,9,7,15,7,12,15,9,11,7,13,12,
        11,13,6,7,14,9,13,15,14,8,13,6,5,12,7,5,11,12,14,15,14,15,9,8,9,14,5,6,8,6,5,12,
        9,15,5,11,6,8,13,12,5,12,13,14,11,8,5,6]
    RR=[8,9,9,11,13,15,15,5,7,7,8,11,14,14,12,6,9,13,15,7,12,8,9,11,7,7,12,7,6,15,13,11,
        9,7,15,11,8,6,6,14,12,13,5,14,13,13,7,5,15,5,8,11,14,14,6,14,6,9,12,9,12,5,15,8,
        8,5,12,9,12,5,14,6,8,13,6,5,15,13,11,11]
    KL=[0,0x5a827999,0x6ed9eba1,0x8f1bbcdc,0xa953fd4e]
    KR=[0x50a28be6,0x5c4dd124,0x6d703ef3,0x7a6d76e9,0]
    def fi(x,y,z,i):
        return x^y^z if i==0 else (x&y)|(~x&z) if i==1 else (x|~y)^z if i==2 else (x&z)|(y&~z) if i==3 else x^(y|~z)
    def rol(x,i): return ((x<<i)|((x&0xffffffff)>>(32-i)))&0xffffffff
    def compress(h0,h1,h2,h3,h4,block):
        al,bl,cl,dl,el=h0,h1,h2,h3,h4; ar,br,cr,dr,er=h0,h1,h2,h3,h4
        x=[int.from_bytes(block[4*i:4*(i+1)],'little') for i in range(16)]
        for j in range(80):
            rnd=j>>4
            al=rol(al+fi(bl,cl,dl,rnd)+x[ML[j]]+KL[rnd],RL[j])+el
            al,bl,cl,dl,el=el,al,bl,rol(cl,10),dl
            ar=rol(ar+fi(br,cr,dr,4-rnd)+x[MR[j]]+KR[rnd],RR[j])+er
            ar,br,cr,dr,er=er,ar,br,rol(cr,10),dr
        return (h1+cl+dr)&0xffffffff,(h2+dl+er)&0xffffffff,(h3+el+ar)&0xffffffff,(h4+al+br)&0xffffffff,(h0+bl+cr)&0xffffffff
    st=(0x67452301,0xefcdab89,0x98badcfe,0x10325476,0xc3d2e1f0)
    data=pad(msg)
    for b in range(len(data)>>6):
        st=compress(*st,data[64*b:64*(b+1)])
    return b"".join(h.to_bytes(4,'little') for h in st)
GEN = bytes.fromhex(
    "0100000000000000000000000000000000000000000000000000000000000000000000003ba3edfd"
    "7a7b12b27ac72c3e67768f617fc81bc3888a51323a9fb8aa4b1e5e4a29ab5f49ffff001d1dac2b7c")
for (name, algo), got in out.items():
    msg = {"empty": b"", "abc": b"abc", "message digest": b"message digest",
           "alphabet": b"abcdefghijklmnopqrstuvwxyz",
           "55a": b"a"*55, "genesis-header": GEN}[name]
    if algo == "sha256":
        exp = hashlib.sha256(msg).hexdigest()
    elif algo == "sha256d":
        exp = hashlib.sha256(hashlib.sha256(msg).digest()).hexdigest()
    else:
        exp = rmd(hashlib.sha256(msg).digest()).hex()
    assert got == exp, f"{name} {algo}: got {got}, expected {exp}"
print("checked", len(out), "digests", file=sys.stderr)
PYEOF

echo "W13 tests: harness exited 0"
