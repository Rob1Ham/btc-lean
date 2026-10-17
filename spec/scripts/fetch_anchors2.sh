#!/usr/bin/env bash
# fetch_anchors2.sh — X12 (Review-3 anchor expansion): fetch the diversity
# anchor blocks as raw serialized bytes, verify each against its block hash
# (double-SHA256 of the 80-byte header, little-endian display), and write a
# sha256 manifest. Companion to W17's fetch_anchors.sh (same verification
# mechanism); the new corpus lives in spec/vectors/anchors2/.
#
# Provider order per request (public APIs), with exponential backoff on
# 429/503 (the W17 lesson: providers rate-cap hard under suite load):
#   1. mempool.space   2. blockstream.info   3. blockchain.info   4. mempool.emzy.de
#
# UTXO seeds (stage 2) use the W17 handoff's documented block-walk path
# (research/w2-17-capstone.md): walk parent blocks backward, parse every tx,
# txid = sha256d(stripped serialization), and materialize only the prevout
# txs the anchor spends — 1 request per ancestor block instead of 1 per
# prevout tx. Stragglers beyond the walk depth fall back to per-tx fetches
# (txid re-derived Lean-independently here and checked against the wire
# reference).
#
# Output: spec/vectors/anchors2/<H>.raw/.hash/.parent/.seeds + MANIFEST.sha256
# (root-level <H>.raw files only; the sibling suite's Vnn/ subdirs untouched).
# Re-run safe: skips verified blocks; seeds append (deduped by txid).
set -euo pipefail
cd "$(dirname "$0")/.."   # spec/
OUT=vectors/anchors2
mkdir -p "$OUT"

# X12 anchor heights (keep in sync with Test/Capstone/Run.lean `anchors2`):
heights=(170 170061 170060 481827 481828 499195 709635)
GENESIS=000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f

bget () { # url... : try each URL in order; exponential backoff on 429/503
  local url code
  for url in "$@"; do
    for att in 1 2 3 4; do
      code=$(curl -s -o /tmp/x12body.$$ -w '%{http_code}' --max-time 60 "$url" 2>/dev/null || true)
      code=${code:-000}
      if [ "$code" = "200" ]; then cat /tmp/x12body.$$; rm -f /tmp/x12body.$$; return 0; fi
      if [ "$code" = "429" ] || [ "$code" = "503" ] || [ "$code" = "000" ]; then
        sleep $((att * att)); continue
      fi
      break   # other status: next provider
    done
  done
  rm -f /tmp/x12body.$$
  return 1
}

fetch_hash () { # height -> display hash on stdout
  local h="$1"
  if [ "$h" = "0" ]; then echo "$GENESIS"; return 0; fi
  bget "https://mempool.space/api/block-height/$h" \
       "https://blockstream.info/api/block-height/$h" \
       "https://mempool.emzy.de/api/block-height/$h"
}

fetch_raw () { # hash -> raw bytes on stdout (binary-safe provider fallback)
  local hash="$1"
  if curl -sf --retry 3 --max-time 120 "https://mempool.space/api/block/$hash/raw"; then return 0; fi
  sleep 2
  if curl -sf --retry 3 --max-time 120 "https://blockstream.info/api/block/$hash/raw"; then return 0; fi
  sleep 2
  curl -sf --retry 3 --max-time 120 "https://blockchain.info/rawblock/$hash?format=hex" \
    | python3 -c 'import sys;sys.stdout.buffer.write(bytes.fromhex(sys.stdin.read().strip()))'
}

verify_raw () { # file -> computed display hash (exits 1 on short file)
  python3 - "$1" <<'EOF'
import sys, hashlib
b = open(sys.argv[1],'rb').read()
if len(b) < 80: sys.exit(f"{sys.argv[1]}: only {len(b)} bytes")
h = hashlib.sha256(hashlib.sha256(b[:80]).digest()).digest()
print(h[::-1].hex())
EOF
}

status=0
for H in "${heights[@]}"; do
  want=$(fetch_hash "$H") || { echo "block $H: no hash from APIs, skipping" >&2; status=1; continue; }
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
  if [ "$H" = "0" ]; then
    echo "0000000000000000000000000000000000000000000000000000000000000000" > "$OUT/0.parent"
  else
    { fetch_hash "$((H-1))" || true; } > "$OUT/$H.parent.tmp"
    mv "$OUT/$H.parent.tmp" "$OUT/$H.parent"
  fi
done

python3 - "$OUT" <<'EOF'
import hashlib, sys, os
out = sys.argv[1]
lines = []
for f in sorted(os.listdir(out)):
    if f.endswith('.raw'):          # root-level only: Vnn/ suite dirs untouched
        d = hashlib.sha256(open(os.path.join(out, f), 'rb').read()).hexdigest()
        lines.append(f"{d}  {f}")
open(os.path.join(out, 'MANIFEST.sha256'), 'w').write("\n".join(lines) + "\n")
print("\n".join(lines))
EOF

# ---- Stage 2: UTXO seeds (W17 block-walk mechanism) ----------------------
# <H>.seeds: one line per needed prevout TX:
#   <wire-order txid hex> <confirming block height> <raw tx hex>
python3 - "$OUT" <<'EOF'
import sys, os, time, hashlib, http.client, json
out = sys.argv[1]
heights = [int(x) for x in os.environ.get(
    "X12_HEIGHTS", "170 170061 170060 481827 481828 499195 709635").split()]
NULLTXID = '00' * 32

def rd_varint(b, i):
    p = b[i]
    if p < 0xfd: return p, i+1
    if p == 0xfd: return int.from_bytes(b[i+1:i+3], 'little'), i+3
    if p == 0xfe: return int.from_bytes(b[i+1:i+5], 'little'), i+5
    return int.from_bytes(b[i+1:i+9], 'little'), i+9

def txid_of_raw(rawtx):
    """sha256d of the STRIPPED serialization (BIP141), wire (internal) order."""
    b = rawtx
    segwit = len(b) > 6 and b[4] == 0 and b[5] == 1
    if not segwit:
        return hashlib.sha256(hashlib.sha256(b).digest()).digest().hex()
    i = 6
    nin, i = rd_varint(b, i)
    for _ in range(nin):
        i += 36
        sl, i = rd_varint(b, i); i += sl; i += 4
    nout, i = rd_varint(b, i)
    for _ in range(nout):
        i += 8; sl, i = rd_varint(b, i); i += sl
    wit_start = i                      # start of the witness section
    for _ in range(nin):
        nit, i = rd_varint(b, i)
        for _ in range(nit):
            l, i = rd_varint(b, i); i += l
    # i now points at the 4-byte locktime; stripped = ver + vin/vout + locktime
    stripped = b[:4] + b[6:wit_start] + b[i:i+4]
    return hashlib.sha256(hashlib.sha256(stripped).digest()).digest().hex()

def needed_prevouts(raw):
    i = 80
    ntx, i = rd_varint(raw, i)
    need = set()
    for _ in range(ntx):
        i += 4
        segwit = raw[i] == 0 and raw[i+1] == 1
        if segwit: i += 2
        nin, i = rd_varint(raw, i)
        for _ in range(nin):
            txid = raw[i:i+32].hex(); i += 36
            sl, i = rd_varint(raw, i); i += sl; i += 4
            if txid != NULLTXID: need.add(txid)
        nout, i = rd_varint(raw, i)
        for _ in range(nout):
            i += 8; sl, i = rd_varint(raw, i); i += sl
        if segwit:
            for _ in range(nin):
                nit, i = rd_varint(raw, i)
                for _ in range(nit):
                    l, i = rd_varint(raw, i); i += l
        i += 4
    return need

def own_txids(raw):
    """Every txid in THIS block (wire order, stripped-serialization sha256d).

    FIND-X12-001: same-block spends must NOT be seeded. The UTXO fold applies
    the anchor block's own txs from <H>.raw itself; at BIP30-active heights
    (< 227931) a seeded same-block coin collides with the fold's own
    application of that tx -> false bad-txns-BIP30. (At >= 227931 BIP30 is
    enforced only via the BIP34-implied carve-out for the two duplicated
    coinbases, so own-txid seeds were harmless there — but excluded anyway:
    the fold is the single source for own txs.)"""
    i = 80
    ntx, i = rd_varint(raw, i)
    ids = set()
    for _ in range(ntx):
        start = i
        i += 4  # tx version
        segwit = raw[i] == 0 and raw[i+1] == 1
        if segwit: i += 2  # marker + flag
        nin, i = rd_varint(raw, i)
        for _ in range(nin):
            i += 36
            sl, i = rd_varint(raw, i); i += sl; i += 4
        nout, i = rd_varint(raw, i)
        for _ in range(nout):
            i += 8; sl, i = rd_varint(raw, i); i += sl
        if segwit:
            for _ in range(nin):  # witness: one stack per input
                nit, i = rd_varint(raw, i)
                for _ in range(nit):
                    l, i = rd_varint(raw, i); i += l
        i += 4
        ids.add(txid_of_raw(raw[start:i]))
    return ids

_tls = threading_local = threading.local()
def get(host, path):
    for att in range(8):
        try:
            c = getattr(_tls, "conn", None)
            if c is None or c.host != host:
                c = http.client.HTTPSConnection(host, timeout=45); _tls.conn = c
            c.request("GET", path)
            r = c.getresponse(); d = r.read()
            if r.status in (429, 503):
                time.sleep(1 + att); continue
            if r.status != 200: raise RuntimeError(f"{host}{path}: HTTP {r.status}")
            return d
        except Exception:
            _tls.conn = None
            time.sleep(0.5 + att)
    raise RuntimeError(f"{host}{path}: retries exhausted")

def fetch_block_raw(hhash):
    try:
        return bytes.fromhex(get("blockchain.info", f"/rawblock/{hhash}?format=hex").decode().strip())
    except Exception:
        pass
    for host in ("mempool.space", "blockstream.info", "mempool.emzy.de"):
        try:
            return get(host, f"/api/block/{hhash}/raw")
        except Exception:
            continue
    raise RuntimeError(f"all providers failed for block {hhash}")

def fetch_tx_raw(disp):
    for host in ("mempool.space", "blockstream.info", "mempool.emzy.de"):
        try:
            return get(host, f"/api/tx/{disp}/hex").decode().strip()
        except Exception:
            continue
    return get("blockchain.info", f"/rawtx/{disp}?format=hex").decode().strip()

for H in heights:
    rawf = f"{out}/{H}.raw"
    if not os.path.exists(rawf): continue
    seeds = f"{out}/{H}.seeds"
    have = set()
    if os.path.exists(seeds):
        have = {l.split(' ', 1)[0] for l in open(seeds) if l.strip()}
    need = needed_prevouts(open(rawf, 'rb').read()) - have
    # FIND-X12-001: never seed the anchor block's own txs (same-block spends);
    # the fold applies them from <H>.raw — see own_txids above.
    need -= own_txids(open(rawf, 'rb').read())
    print(f"height {H}: {len(need)} prevout txs to resolve", flush=True)
    if not need: continue
    parent_disp = open(f"{out}/{H}.parent").read().strip()
    found = {}
    depth = 0
    while need and depth < 400:
        blk = fetch_block_raw(parent_disp)
        pos = 80
        ntx, pos = rd_varint(blk, pos)
        hits = 0
        for _ in range(ntx):
            start = pos
            pos += 4
            segwit = blk[pos] == 0 and blk[pos+1] == 1
            if segwit: pos += 2
            nin, pos = rd_varint(blk, pos)
            for _ in range(nin):
                pos += 36
                sl, pos = rd_varint(blk, pos); pos += sl; pos += 4
            nout, pos = rd_varint(blk, pos)
            for _ in range(nout):
                pos += 8; sl, pos = rd_varint(blk, pos); pos += sl
            if segwit:
                for _ in range(nin):
                    nit, pos = rd_varint(blk, pos)
                    for _ in range(nit):
                        l, pos = rd_varint(blk, pos); pos += l
            pos += 4
            txraw = blk[start:pos]
            txid = txid_of_raw(txraw)
            if txid in need:
                need.discard(txid)
                found[txid] = (H - 1 - depth, txraw.hex())
                hits += 1
        if hits or depth % 10 == 0:
            print(f"  {H} depth {depth}: block {H-1-depth} +{hits} hits, {len(need)} left", flush=True)
        if need:
            parent_disp = blk[4:36][::-1].hex()
        depth += 1
        time.sleep(0.3)
    # stragglers beyond walk depth: per-tx fetch + confirming height
    for txid in sorted(need):
        disp = bytes.fromhex(txid)[::-1].hex()
        try:
            j = json.loads(get("mempool.emzy.de", f"/api/tx/{disp}"))
            h = j["status"]["block_height"] if j["status"]["confirmed"] else -1
            rawhex = fetch_tx_raw(disp)
            assert txid_of_raw(bytes.fromhex(rawhex)) == txid, "txid mismatch"
            found[txid] = (h, rawhex)
            print(f"  {H} straggler {txid[:12]} @ {h}", flush=True)
        except Exception as e:
            print(f"  {H} STRAGGLER FAILED {txid}: {e}", flush=True)
    with open(seeds, "a") as f:
        for txid in sorted(found):
            h, rawhex = found[txid]
            f.write(f"{txid} {h} {rawhex}\n")
    print(f"height {H}: seeds now {sum(1 for _ in open(seeds))} lines", flush=True)
EOF
exit $status
