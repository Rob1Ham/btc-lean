#!/usr/bin/env python3
"""
BIP341 output/script-path crosscheck — independent pure-python secp256k1 mirror of the
BIP341 taproot OUTPUT construction and script-path SPEND verdict
(bip-0341.mediawiki §"Constructing and spending Taproot outputs" and
§"Script validation"; Core interpreter.cpp:1898-1990 @c50817fe).

EC is implemented from scratch (affine point arithmetic over the prime
field, lift_x per BIP341 step 1, double-and-add scalar multiplication) —
NO external crypto libraries.

1. Validates itself against ALL 7 official `scriptPubKey`-section cases of
   spec/data/bips/bip-0341_wallet-test-vectors.json (merkleRoot via the
   TapLeaf/TapBranch ladder, tweak, tweakedPubkey, scriptPubKey).
2. Re-derives every official literal baked into
   spec/Test/Crypto/TaprootVerifyTest.lean (the case table AND its TapTree
   literals, parsed from the Lean source).
3. Mirrors the 4 synthetic script-path control-block verdicts (minimal
   accept, wrong-parity reject, corrupt-path-node reject, size reject)
   with the same literals the Lean harness uses.

Control-block size note: Program.lean now sets
TAPROOT_CONTROL_BASE_SIZE = 33 (lattice 33 + 32m, max 33 + 128·32 =
4129) = Core's constant (interpreter.h).
The synthetic control blocks and the mirror below follow the Core-33
lattice (the mirror previously followed the old 65/4161 lattice).

Run: python3 spec/Test/Crypto/taproot_verify_crosscheck.py
"""
import hashlib, json, re, sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
VECTORS = str(ROOT / 'spec' / 'data' / 'bips' / 'bip-0341_wallet-test-vectors.json')
HARNESS = str(HERE / 'TaprootVerifyTest.lean')

# ---------- raw primitives (independent: hashlib + own EC) ----------

P = 2**256 - 2**32 - 977
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
G = (0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
     0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8)

def sha256(b): return hashlib.sha256(b).digest()

def tagged_hash(tag, msg):
    t = hashlib.sha256(tag.encode()).digest()
    return hashlib.sha256(t + t + msg).digest()

def lift_x(x):
    """BIP341 §Constructing step 1: even-y lift; none if x is not a field
    element or not on the curve."""
    if x >= P: return None
    y_sq = (pow(x, 3, P) + 7) % P
    y = pow(y_sq, (P + 1) // 4, P)
    if (y * y) % P != y_sq: return None
    return (x, y if y % 2 == 0 else P - y)

def pt_add(p, q):
    """Affine point addition (None = point at infinity)."""
    if p is None: return q
    if q is None: return p
    if p[0] == q[0]:
        if (p[1] + q[1]) % P == 0: return None       # 2P + (-2P) = inf
        lam = (3 * p[0] * p[0]) * pow(2 * p[1], -1, P) % P   # doubling
    else:
        lam = (q[1] - p[1]) * pow(q[0] - p[0], -1, P) % P
    x = (lam * lam - p[0] - q[0]) % P
    y = (lam * (p[0] - x) - p[1]) % P
    return (x, y)

def pt_mul(k, p):
    """Double-and-add scalar multiplication (k ≥ 0)."""
    r = None
    while k > 0:
        if k & 1: r = pt_add(r, p)
        p = pt_add(p, p)
        k >>= 1
    return r

def tapleaf(leaf_version, script):
    return tagged_hash('TapLeaf', bytes([leaf_version]) + varbytes(script))

def varbytes(b):
    n = len(b)
    if n < 0xfd: return bytes([n]) + b
    if n <= 0xffff: return b'\xfd' + n.to_bytes(2, 'little') + b
    if n <= 0xffffffff: return b'\xfe' + n.to_bytes(4, 'little') + b
    return b'\xff' + n.to_bytes(8, 'little') + b

def tapbranch(a, b):
    lo, hi = (a, b) if a <= b else (b, a)   # lexicographic sort (Core :1890)
    return tagged_hash('TapBranch', lo + hi)

def tree_hash(t):
    """t: JSON scriptTree — leaf dict or [left, right] nested lists."""
    if isinstance(t, list):
        return tapbranch(tree_hash(t[0]), tree_hash(t[1]))
    return tapleaf(t['leafVersion'], bytes.fromhex(t['script']))

def tweak_key(internal_pk, root):
    """Q = P + int(tagged('TapTweak', x ‖ root))·G; None on overflow."""
    t = int.from_bytes(tagged_hash('TapTweak', internal_pk + root), 'big')
    if t >= N: return None
    Pint = lift_x(int.from_bytes(internal_pk, 'big'))
    if Pint is None: return None
    return pt_add(Pint, pt_mul(t, G))

def p2tr_output(internal_pk_hex, root):
    q = tweak_key(bytes.fromhex(internal_pk_hex), root)
    assert q is not None
    return bytes([0x51, 0x20]) + q[0].to_bytes(32, 'big')

# ---------- 1. self-validation against the official corpus ----------

with open(VECTORS) as f:
    corpus = json.load(f)

ok = 0
for i, case in enumerate(corpus['scriptPubKey']):
    g, it, e = case['given'], case['intermediary'], case['expected']
    root = None if g['scriptTree'] is None else tree_hash(g['scriptTree'])
    if it['merkleRoot'] is None:
        assert root is None, f"case {i}: merkleRoot should be null"
    else:
        assert root == bytes.fromhex(it['merkleRoot']), f"case {i}: merkleRoot"
    q = tweak_key(bytes.fromhex(g['internalPubkey']),
                  root if root is not None else b'')
    assert q is not None, f"case {i}: tweak failed"
    assert q[0].to_bytes(32, 'big') == bytes.fromhex(it['tweakedPubkey']), \
        f"case {i}: tweakedPubkey"
    assert bytes([0x51, 0x20]) + q[0].to_bytes(32, 'big') == \
        bytes.fromhex(e['scriptPubKey']), f"case {i}: scriptPubKey"
    ok += 1
print(f"mirror: {ok}/7 official scriptPubKey-section output cases "
      f"(merkleRoot + tweakedPubkey + scriptPubKey) re-derived: OK")

# ---------- 2. re-derive the harness literals ----------

src = open(HARNESS).read()

# TapTree literals: def treeN : Option TapTree := some (<expr>)
def parse_tree(expr):
    expr = expr.strip()
    m = re.fullmatch(r'\(\.leaf (\d+) \(fromHex "([0-9a-f]+)"\)\)', expr)
    if m: return tapleaf(int(m.group(1)), bytes.fromhex(m.group(2)))
    # (.node A\n B) — split on the top-level .node's two arguments
    assert expr.startswith('(.node '), expr
    inner = expr[len('(.node '):-1]
    depth, split = 0, None
    for j, ch in enumerate(inner):
        if ch == '(': depth += 1
        elif ch == ')': depth -= 1
        elif ch == ' ' and depth == 0: split = j; break
    assert split is not None, expr
    return tapbranch(parse_tree(inner[:split]), parse_tree(inner[split+1:]))

trees = {}
for m in re.finditer(r'def (tree\d) : Option TapTree :=\s*some ', src):
    i = src.index('(', m.end())
    depth, j = 0, i
    while True:
        if src[j] == '(': depth += 1
        elif src[j] == ')':
            depth -= 1
            if depth == 0: break
        j += 1
    trees[m.group(1)] = parse_tree(src[i:j + 1])
assert len(trees) == 6, f"expected 6 TapTree literals, got {len(trees)}"

pat = re.compile(
    r'\("(spk-off-[0-9a-z-]+)",\s*"([0-9a-f]+)",\s*(none|tree\d),'
    r'\s*"([0-9a-f]*)",\s*"([0-9a-f]+)",\s*"([0-9a-f]+)"\)')
ok2 = 0
for m in pat.finditer(src):
    name, pk_hex, tree_ref, root_hex, tw_hex, spk_hex = m.groups()
    root = None if tree_ref == 'none' else trees[tree_ref]
    want_root = None if root_hex == '' else bytes.fromhex(root_hex)
    got_root = None if root is None else root
    assert got_root == want_root, f"{name}: merkleRoot"
    got_spk = p2tr_output(pk_hex, root if root is not None else b'')
    assert got_spk == bytes.fromhex(spk_hex), f"{name}: scriptPubKey"
    assert bytes.fromhex(spk_hex) == bytes([0x51, 0x20]) + bytes.fromhex(tw_hex), \
        f"{name}: template cross-field"
    ok2 += 1
assert ok2 == 7, f"harness must embed exactly the 7 official cases, got {ok2}"
print(f"crosscheck: {ok2} official output-case literals re-derived from the "
      f"Lean TapTree table: OK")

# ---------- 3. mirror the 4 synthetic script-path verdicts ----------

def script_path_spend(control, script):
    """Mirror of Verify.scriptPathSpend: spec TPR-009 lattice
    (TAPROOT_CONTROL_BASE_SIZE = 33), path nodes at
    33 + 32i, masked tapleaf, tweak+parity commitment, 0xc0 dispatch."""
    if not (33 <= len(control) <= 33 + 128 * 32
            and (len(control) - 33) % 32 == 0):
        return None
    m = (len(control) - 33) // 32
    tl = tapleaf(control[0] & 0xfe, script)
    k = tl
    for i in range(m):
        k = tapbranch(k, control[33 + 32 * i:65 + 32 * i])
    internal = control[1:33]
    q = tweak_key(internal, k)
    if q is None: return (tl, False, (control[0] & 0xfe) == 0xc0)
    parity_ok = (control[0] & 1) == (q[1] & 1)
    return (tl, parity_ok, (control[0] & 0xfe) == 0xc0)

def def_hex(name):
    m = re.search(r'def %s : ByteArray :=\s*fromHex "([0-9a-f]+)"' % name, src)
    assert m, name
    return bytes.fromhex(m.group(1))

pk1, script1, root1 = def_hex('pk1'), def_hex('script1'), def_hex('root1')
m_garbage = re.search(r'let controlBad := control \+\+ fromHex "([0-9a-f]+)"', src)
assert m_garbage, "corrupt-path garbage node literal"
garbage = bytes.fromhex(m_garbage.group(1))

t = int.from_bytes(tagged_hash('TapTweak', pk1 + root1), 'big')
assert t < N
q1 = pt_add(lift_x(int.from_bytes(pk1, 'big')), pt_mul(t, G))
parity = q1[1] & 1
control = bytes([0xc0 | parity]) + pk1
assert len(control) == 33

verdicts = {
    'accept':       script_path_spend(control, script1),
    'wrongparity':  script_path_spend(bytes([0xc0 | (1 - parity)]) + pk1, script1),
    'corruptpath':  script_path_spend(control + garbage, script1),
    'badsize':      script_path_spend(control + b'\x00', script1),
}
assert verdicts['accept'] == (tapleaf(0xc0, script1), True, True), \
    f"accept: {verdicts['accept']}"
assert verdicts['wrongparity'] == (tapleaf(0xc0, script1), False, True), \
    f"wrongparity: {verdicts['wrongparity']}"
assert verdicts['corruptpath'] == (tapleaf(0xc0, script1), False, True), \
    f"corruptpath: {verdicts['corruptpath']}"
assert verdicts['badsize'] is None, f"badsize: {verdicts['badsize']}"
print("crosscheck: 4 synthetic script-path verdicts mirrored "
      "(accept/wrongparity/corruptpath/badsize): OK")
