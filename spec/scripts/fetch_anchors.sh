#!/usr/bin/env bash
# fetch_anchors.sh — W17 S1: fetch the 6 mainnet anchor blocks as raw
# serialized bytes, verify each against its block hash (double-SHA256 of
# the 80-byte header, little-endian display), and write a sha256 manifest.
#
# Sources (public APIs, tried in order per block):
#   1. https://blockstream.info/api/block/<hash>/raw
#   2. https://blockchain.info/rawblock/<hash>?format=hex
# Height → hash via https://blockstream.info/api/block-height/<height>
# (the genesis hash is pinned below, canonical).
#
# Output: spec/vectors/anchors/<height>.raw, <height>.hash, MANIFEST.sha256
# Re-run safe: skips blocks whose hash manifest already verifies.
set -euo pipefail
cd "$(dirname "$0")/.."   # spec/
OUT=vectors/anchors
mkdir -p "$OUT"

heights=(0 74638 91842 91880 481824 709632)
GENESIS=000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f

fetch_hash () { # height -> hash on stdout (mempool.space first, blockstream fallback)
  local h="$1"
  if [ "$h" = "0" ]; then echo "$GENESIS"; return; fi
  curl -sf --retry 3 "https://mempool.space/api/block-height/$h"     || curl -sf --retry 3 "https://blockstream.info/api/block-height/$h"
}

fetch_raw () { # hash -> raw bytes on stdout
  local hash="$1"
  if curl -sf --retry 3 "https://blockstream.info/api/block/$hash/raw"; then return 0; fi
  curl -sf --retry 3 "https://blockchain.info/rawblock/$hash?format=hex" \
    | python3 -c 'import sys;sys.stdout.buffer.write(bytes.fromhex(sys.stdin.read().strip()))'
}

verify_raw () { # file -> prints computed display hash; exits 1 on short file
  python3 - "$1" <<'EOF'
import sys, hashlib
b = open(sys.argv[1],'rb').read()
if len(b) < 80: sys.exit(f"{sys.argv[1]}: only {len(b)} bytes")
hdr = b[:80]
h = hashlib.sha256(hashlib.sha256(hdr).digest()).digest()
print(h[::-1].hex())
EOF
}

status=0
for H in "${heights[@]}"; do
  want=""
  for try in 1 2 3 4; do
    want=$(fetch_hash "$H")
    [ -n "$want" ] && break
    sleep 5
  done
  if [ -z "$want" ]; then echo "block $H: no hash from APIs, skipping" >&2; status=1; continue; fi
  f="$OUT/$H.raw"
  if [ -s "$f" ] && [ "$(verify_raw "$f")" = "$want" ]; then
    echo "block $H: cached OK ($want)"
  else
    echo "block $H: fetching ($want)"
    fetch_raw "$want" > "$f.tmp"
    got=$(verify_raw "$f.tmp")
    if [ "$got" != "$want" ]; then
      echo "MISMATCH for $H: computed $got, expected $want" >&2
      status=1; rm -f "$f.tmp"; continue
    fi
    mv "$f.tmp" "$f"
    echo "block $H: verified"
  fi
  printf '%s\n' "$want" > "$OUT/$H.hash"
  # chain-link target: the REAL parent block hash (display order)
  if [ "$H" = "0" ]; then
    echo "0000000000000000000000000000000000000000000000000000000000000000" > "$OUT/0.parent"
  else
    # REAL parent hash: mempool.space first (blockstream rate-caps), and a
    # failure here must not abort the run — the runner reports a vacuous
    # chain-link check when the file is empty.
    { curl -sf --retry 3 "https://mempool.space/api/block-height/$((H-1))" \
      || curl -sf --retry 3 "https://blockstream.info/api/block-height/$((H-1))"; } \
      > "$OUT/$H.parent.tmp" || true
    mv "$OUT/$H.parent.tmp" "$OUT/$H.parent"
  fi
done

python3 - "$OUT" <<'EOF'
import hashlib, sys, os
out = sys.argv[1]
lines = []
for f in sorted(os.listdir(out), key=lambda s: (len(s), s)):
    if f.endswith('.raw'):
        d = hashlib.sha256(open(os.path.join(out,f),'rb').read()).hexdigest()
        lines.append(f"{d}  {f}")
open(os.path.join(out,'MANIFEST.sha256'),'w').write("\n".join(lines)+"\n")
print("\n".join(lines))
EOF

# ---- Stage 2: UTXO seeds ------------------------------------------------
# The anchor sequence validates each block against the REAL prevout view of
# its inputs (the intermediate blocks are not applied — documented in the
# W17 report; the seed plays the role of W10's vector prevout table).
# Format of <height>.seeds (one line per needed prevout TX, not per
# outpoint):  <wire-order txid hex> <block height> <raw tx hex>
# The Lean runner decodes each raw tx (W02 decodeTx), indexes the vouts and
# materializes Coin entries (value, height, isCoinbase, scriptPubKey).
# isCoinbase is derived Lean-side from the decoded tx (single null-prevout
# input), so only the height is trusted metadata here.
python3 - "$OUT" <<'EOF'
import sys, os, json, urllib.request, concurrent.futures, hashlib
out = sys.argv[1]

def rd_varint(b, i):
    p = b[i]
    if p < 0xfd: return p, i+1
    if p == 0xfd: return int.from_bytes(b[i+1:i+3],'little'), i+3
    if p == 0xfe: return int.from_bytes(b[i+1:i+5],'little'), i+5
    return int.from_bytes(b[i+1:i+9],'little'), i+9

def walk_block(b):
    i = 80
    ntx, i = rd_varint(b, i)
    for _ in range(ntx):
        ver = int.from_bytes(b[i:i+4],'little'); i += 4
        segwit = b[i] == 0 and b[i+1] == 1
        if segwit: i += 2
        nin, i = rd_varint(b, i)
        for _ in range(nin):
            txid = b[i:i+32]          # wire order
            i += 32
            n = int.from_bytes(b[i:i+4],'little'); i += 4
            sl, i = rd_varint(b, i)
            i += sl
            i += 4
            yield txid.hex(), n
        nout, i = rd_varint(b, i)
        for _ in range(nout):
            i += 8
            sl, i = rd_varint(b, i)
            i += sl
        if segwit:
            for _ in range(nin):
                nit, i = rd_varint(b, i)
                for _ in range(nit):
                    l, i = rd_varint(b, i)
                    i += l
        i += 4  # locktime

import http.client, threading, time

_tls = threading.local()

def _conn(host):
    c = getattr(_tls, "conn", None)
    if c is None or c.host != host:
        c = http.client.HTTPSConnection(host, timeout=30)
        _tls.conn = c
    return c

def get_path(host, path):
    # keep-alive per worker thread; reconnect transparently on stale sockets
    for att in range(10):
        try:
            c = _conn(host)
            c.request("GET", path)
            r = c.getresponse()
            data = r.read()
            if r.status in (429, 503) and att < 9:
                time.sleep(1 + att)
                continue
            if r.status != 200:
                raise RuntimeError(f"{host}{path}: HTTP {r.status}")
            return data
        except Exception:
            _tls.conn = None
            if att == 9: raise
            time.sleep(1 + att)
    raise RuntimeError(f"{host}{path}: retries exhausted")

HOSTS = ["mempool.space", "blockstream.info"]
def txmeta(disp):
    for host in HOSTS:
        try:
            j = json.loads(get_path(host, f"/api/tx/{disp}"))
            h = j["status"]["block_height"] if j["status"]["confirmed"] else -1
            raw = get_path(host, f"/api/tx/{disp}/hex").decode().strip()
            return h, raw
        except Exception:
            _tls.conn = None
            continue
    raise RuntimeError(f"all hosts failed for {disp}")


null = "00"*32
for H in [0, 74638, 91842, 91880, 481824, 709632]:
    seeds = f"{out}/{H}.seeds"
    have = set()
    if os.path.exists(seeds):
        have = {l.split(' ',1)[0] for l in open(seeds) if l.strip()}
    raw = open(f"{out}/{H}.raw","rb").read()
    want = {t for t,_ in walk_block(raw) if t != null}
    todo = sorted(want - have)
    print(f"height {H}: {len(want)} prevout txs, {len(todo)} to fetch", flush=True)
    if not todo: continue
    # wire order -> display order
    disp = lambda w: bytes.fromhex(w)[::-1].hex()
    done = [0]
    def fetch_one(w):
        r = (w, txmeta(disp(w)))
        done[0] += 1
        if done[0] % 500 == 0:
            print(f"height {H}: {done[0]}/{len(todo)}", flush=True)
        return r
    with concurrent.futures.ThreadPoolExecutor(max_workers=12) as ex:
        res = dict(ex.map(fetch_one, todo))
    with open(seeds, "a") as f:
        for w in todo:
            h, rawtx = res[w]
            f.write(f"{w} {h} {rawtx}\n")
    print(f"height {H}: seeds now {sum(1 for _ in open(seeds))} lines")
EOF
exit $status
