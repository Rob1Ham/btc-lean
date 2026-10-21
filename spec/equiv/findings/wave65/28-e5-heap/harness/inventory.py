# usage: llvm-dis-20 <carrier>.bc -o <carrier>.ll; python3 inventory.py <carrier>.ll
import re, sys, json, collections

def parse(path):
    txt = open(path, encoding='utf-8', errors='replace').read()
    lines = txt.splitlines()
    funcs = {}
    cur = None
    for i, ln in enumerate(lines):
        m = re.match(r'^define\s+(?:[^@]*?)\s*@([A-Za-z0-9_$.]+)\s*\(', ln)
        if m:
            cur = m.group(1)
            funcs[cur] = {'start': i, 'end': None, 'body': []}
            continue
        if cur is not None:
            if ln.strip() == '}':
                funcs[cur]['end'] = i
                cur = None
            else:
                funcs[cur]['body'].append(ln)
    decls = set(re.findall(r'^declare\s+[^@]*@([A-Za-z0-9_$.]+)', txt, re.M))
    ext_globals = sorted(set(re.findall(r'^@([A-Za-z0-9_$.]+)\s*=\s*external', txt, re.M)))
    info = {}
    edges = collections.defaultdict(set)
    for name, f in funcs.items():
        b = "\n".join(f['body'])
        calls = re.findall(r'(?:call|invoke)\s+[^@]*?@([A-Za-z0-9_$.]+)\s*\(', b)
        targets = set(c for c in calls if c in funcs)
        edges[name] = targets
        info[name] = {
            'invoke': len(re.findall(r'\binvoke\b', b)),
            'call': len(re.findall(r'(?<!in)\bcall\b', b)),
            'landingpad': len(re.findall(r'landingpad', b)),
            'ptrtoint': len(re.findall(r'ptrtoint', b)),
            'load_atomic': len(re.findall(r'load atomic', b)),
            'guard_refs': len(re.findall(r'@_ZGV', b)),
            'calls_undef': sorted(set(c for c in calls if c in decls)),
        }
    return funcs, info, edges, decls, ext_globals

def reach(edges, roots):
    seen = set()
    stack = [r for r in roots if r in edges]
    while stack:
        n = stack.pop()
        if n in seen: continue
        seen.add(n)
        for m in edges.get(n, ()):
            if m not in seen: stack.append(m)
    return seen

path = sys.argv[1]
funcs, info, edges, decls, extg = parse(path)
roots = [r for r in funcs if 'VerifyScript' in r or r.startswith('_Z10EvalScript')]
R = reach(edges, roots)
print("module:", path)
print("defined functions:", len(funcs), "declared externals:", len(decls))
print("verify/eval roots:", len(roots))
print("reachable from roots:", len(R))
agg = collections.Counter()
for n in R:
    for k in ('invoke','call','landingpad','ptrtoint','load_atomic','guard_refs'):
        agg[k]+=info[n][k]
print("reachable totals:", dict(agg))
unreached = sorted(set(funcs)-R)
print("unreached defined functions:", len(unreached))
print()
print("functions with invokes/landingpads reachable from roots (top 25 by invokes):")
rows = sorted(((info[n]['invoke'], info[n]['landingpad'], n) for n in R), reverse=True)
for inv, lp, n in rows[:25]:
    if inv or lp: print(f"  inv={inv:4d} lp={lp:4d} {n}")
print()
print("reachable functions with atomic loads:")
for n in sorted(R):
    if info[n]['load_atomic']: print(f"  {info[n]['load_atomic']} {n}")
print()
print("reachable functions with ptrtoint:")
for n in sorted(R):
    if info[n]['ptrtoint']: print(f"  {info[n]['ptrtoint']:3d} {n}")
print()
# external symbols reached (direct, one level from reachable funcs)
ext = collections.Counter()
for n in R:
    for c in info[n]['calls_undef']: ext[c]+=1
print("distinct undefined externals called from reachable functions:", len(ext))
for k,v in sorted(ext.items()): print(f"  {v:3d} {k}")
