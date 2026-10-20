#!/usr/bin/env python3
"""Inventory ptrtoint/inttoptr sites in the pinned Core interpreter IR,
classify each by data-flow pattern, and compute reachability from EvalScript.

No LLVM python bindings needed: the textual IR at -O0 is regular enough.
"""
import re, sys, json, collections, hashlib

PATH = sys.argv[1] if len(sys.argv) > 1 else 'ir20/interpreter-O0.ll'
ROOTS = sys.argv[2].split(',') if len(sys.argv) > 2 else None

lines = open(PATH, errors='replace').read().splitlines()

def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()

# ---- split into functions -------------------------------------------------
funcs = {}          # name -> dict(start, end, lines)
order = []
cur = None
for i, l in enumerate(lines):
    if l.startswith('define '):
        m = re.search(r'@("?)([^ ("\)]+)\1\(', l)
        cur = m.group(2)
        funcs[cur] = {'start': i, 'end': None, 'hdr': l}
        order.append(cur)
    elif l.startswith('}') and cur is not None:
        funcs[cur]['end'] = i
        cur = None
if cur is not None:
    funcs[cur]['end'] = len(lines) - 1

# ---- calls ---------------------------------------------------------------
call_re = re.compile(r'\b(?:call|invoke)\b[^@\n]*@("?)([\w.$]+)\1\(')
defcall_re = re.compile(r'^define\b.*?@("?)([^ ("\)]+)\1\(')
calls = collections.defaultdict(set)   # caller -> set(callee)
for name, f in funcs.items():
    for l in lines[f['start']:f['end'] + 1]:
        for m in call_re.finditer(l):
            calls[name].add(m.group(2))
            # indirect call detection
        if re.search(r'\b(?:call|invoke)\b[^@\n]*%[-\w.$]+ *\(', l):
            calls[name].add('<indirect>')

# ---- ptrtoint / inttoptr sites ------------------------------------------
sites = []
for name, f in funcs.items():
    body = lines[f['start']:f['end'] + 1]
    for j, l in enumerate(body):
        if ' ptrtoint ' in l or ' inttoptr ' in l:
            sites.append({'func': name, 'line': f['start'] + j + 1, 'text': l.strip()})

sites_by_func = collections.Counter(s['func'] for s in sites)

# ---- reachability --------------------------------------------------------
defs = set(funcs)
if ROOTS is None:
    roots = [f for f in defs if 'EvalScript' in f]
else:
    roots = [f for f in defs if any(r in f for r in ROOTS)]

seen, stack = set(), list(roots)
while stack:
    f = stack.pop()
    if f in seen:
        continue
    seen.add(f)
    for g in calls.get(f, ()):
        if g in defs:
            stack.append(g)

ext = set()
for f in seen:
    for g in calls.get(f, ()):
        if g not in defs and not g.startswith('llvm.'):
            ext.add(g)

reach_sites = [s for s in sites if s['func'] in seen]
reach_funcs = sorted(sites_by_func, key=lambda x: -sites_by_func[x])

print('module:', PATH)
print('module sha256:', sha(PATH))
print('functions defined:', len(defs))
print('roots:', roots)
print('reachable from roots:', len(seen))
print('ptrtoint/inttoptr sites module-wide:', len(sites),
      ' ptrtoint:', sum(' ptrtoint ' in s['text'] for s in sites),
      ' inttoptr:', sum(' inttoptr ' in s['text'] for s in sites))
print('sites in reachable funcs:', len(reach_sites),
      ' ptrtoint:', sum(' ptrtoint ' in s['text'] for s in reach_sites),
      ' inttoptr:', sum(' inttoptr ' in s['text'] for s in reach_sites))
print('reachable funcs containing sites:', len({s['func'] for s in reach_sites}))
print()

# ---- classify ------------------------------------------------------------
# Pattern classification per site, using the two instruction shapes we expect.
# A "pair subtract" is:  %a = ptrtoint ptr %p to i64 ; %b = ptrtoint ptr %q to i64 ; %d = sub i64 %a, %b
by_func_lines = collections.defaultdict(list)
for s in sites:
    by_func_lines[s['func']].append(s)

pair_count = 0
classes = collections.Counter()
detail = []
for name, ss in by_func_lines.items():
    ss = sorted(ss, key=lambda s: s['line'])
    used = set()
    for k, s in enumerate(ss):
        if k in used:
            continue
        if ' ptrtoint ' not in s['text']:
            classes['inttoptr'] += 1
            detail.append((name, s['line'], 'inttoptr', s['text']))
            continue
        # look ahead within 3 lines for a second ptrtoint and a sub
        nxt = ss[k + 1] if k + 1 < len(ss) else None
        if nxt and nxt['line'] - s['line'] <= 3 and ' ptrtoint ' in nxt['text']:
            # find the sub in between / after
            window = lines[nxt['line'] - 1:nxt['line'] + 3]
            if any(re.search(r'=\s*sub\s+i64', w) for w in window):
                classes['pair-sub-ptrdiff'] += 1
                used.add(k + 1)
                detail.append((name, s['line'], 'pair-sub-ptrdiff',
                               s['text'] + ' ;; ' + nxt['text']))
                continue
        classes['other'] += 1
        detail.append((name, s['line'], 'other', s['text']))

print('classification:', dict(classes))
print()

# ---- per-function table (reachable only) --------------------------------
reach_names = {s['func'] for s in reach_sites}
rows = []
for name in sorted(reach_names, key=lambda x: (-sites_by_func[x], x)):
    f = funcs[name]
    body = lines[f['start']:f['end'] + 1]
    nsite = sites_by_func[name]
    ncall = sum(1 for l in body if re.search(r'\b(?:call|invoke)\b', l))
    # does it touch heap / allocator?
    txt = '\n'.join(body)
    heap = any(k in txt for k in ('_Znwm', 'malloc', 'realloc', 'operator new'))
    fmt = 'tinyformat' in name or 'format' in name.lower()
    cls = collections.Counter()
    for d in detail:
        if d[0] == name:
            cls[d[2]] += 1
    rows.append((name, nsite, f['start'] + 1, f['end'] - f['start'] + 1,
                 ncall, dict(cls), heap, fmt,
                 ','.join(sorted(calls.get(name, ())))))

print('reachable funcs with ptrtoint:')
print('func\tsites\tline\tbodylines\tcalls\tclasses\theap\ttinyformat\tcallees')
for r in rows:
    print('\t'.join(str(x) for x in r))

print()
print('external callees reachable from roots:', len(ext))
for e in sorted(ext):
    print('  ', e)

print()
print('ALL SITES (reachable):')
for s in sorted(reach_sites, key=lambda s: s['line']):
    print(f"{s['line']}\t{s['func']}\t{s['text']}")

json.dump({'path': PATH, 'sha256': sha(PATH), 'roots': roots,
           'reachable': sorted(seen), 'sites': sites,
           'reach_sites': reach_sites, 'classes': dict(classes),
           'funcs': {k: {'start': v['start'], 'end': v['end'], 'hdr': v['hdr']}
                     for k, v in funcs.items()}},
          open(sys.argv[3] if len(sys.argv) > 3 else '/tmp/opencode/wave16b-scratch/05-e5-ptrtoint-stl/inv.json', 'w'),
          indent=1)
