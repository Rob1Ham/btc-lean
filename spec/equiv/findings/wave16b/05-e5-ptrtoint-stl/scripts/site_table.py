#!/usr/bin/env python3
"""Build the reachable ptrtoint site table for the report (markdown)."""
import re, sys, collections, json, subprocess

PATH = sys.argv[1] if len(sys.argv) > 1 else 'ir20/interpreter-O0.ll'
OUT = sys.argv[2] if len(sys.argv) > 2 else '-'

lines = open(PATH, errors='replace').read().splitlines()
funcs, order, cur = {}, [], None
for i, l in enumerate(lines):
    if l.startswith('define '):
        m = re.search(r'@("?)([^ ("\)]+)\1\(', l)
        cur = m.group(2)
        funcs[cur] = [i, None]
        order.append(cur)
    elif l.startswith('}') and cur is not None:
        funcs[cur][1] = i
        cur = None
if cur:
    funcs[cur][1] = len(lines) - 1

call_re = re.compile(r'\b(?:call|invoke)\b[^@\n]*@("?)([\w.$]+)\1\(')
calls = collections.defaultdict(set)
callers = collections.defaultdict(set)
for name, (a, b) in funcs.items():
    for l in lines[a:b + 1]:
        for m in call_re.finditer(l):
            calls[name].add(m.group(2))
            callers[m.group(2)].add(name)

ENGINE = ['_Z10EvalScript', '_Z12VerifyScript', '_Z19VerifyWitnessProgram',
          '_Z20ExecuteWitnessScript', '_Z23EvalChecksigPreTapscript',
          '_Z20EvalChecksigTapscript', '_Z10CastToBool']
roots = [f for f in funcs if any(f.startswith(p) for p in ENGINE)]

dist = {}
q = collections.deque()
for r in roots:
    dist[r] = 0
    q.append(r)
while q:
    f = q.popleft()
    for g in calls.get(f, ()):
        if g in funcs and g not in dist:
            dist[g] = dist[f] + 1
            q.append(g)

sites = [(name, a + j + 1, lines[a + j].strip())
         for name, (a, b) in funcs.items()
         for j in range(b - a + 1) if ' ptrtoint ' in lines[a + j]]

by_func = collections.defaultdict(list)
for s in sites:
    by_func[s[0]].append(s)

def demangle(n):
    try:
        return subprocess.run(['c++filt', n], capture_output=True, text=True).stdout.strip()
    except Exception:
        return n

def shape(name):
    a, b = funcs[name]
    body = lines[a:b + 1]
    txt = '\n'.join(body)
    if 'sdiv exact i64' in txt:
        sz = re.findall(r'sdiv exact i64 %[-\w.$]+, (\d+)', txt)
        return 'sub+sdiv exact ' + (','.join(sz) if sz else '?')
    if re.search(r'trunc i64 %[-\w.$]+ to i32', txt):
        return 'sub+trunc i32'
    return 'sub (byte distance)'

def observable(name):
    a, b = funcs[name]
    body = lines[a:b + 1]
    obs = set()
    for l in body:
        if re.search(r'ret i(32|64)\b', l):
            obs.add('returned')
        if 'sdiv exact' in l:
            obs.add('divided by sizeof(T)')
        if re.search(r'\btrunc i64\b', l):
            obs.add('truncated to i32')
    return ', '.join(sorted(obs)) or 'internal'

print('| # | helper (demangled) | sites | IR lines | shape | observable | depth | reached via |')
print('|---:|---|---:|---|---|---|---:|---|')
i = 0
reach = sorted([f for f in by_func if f in dist], key=lambda f: (dist[f], f))
for f in reach:
    i += 1
    via = sorted(c for c in callers.get(f, ()) if c in dist)
    via_s = '<br>'.join('`' + demangle(v) + '`' for v in via[:3])
    print(f"| {i} | `{demangle(f)}` | {len(by_func[f])} | "
          f"{','.join(str(s[1]) for s in by_func[f])} | {shape(f)} | "
          f"{observable(f)} | {dist[f]} | {via_s} |")

print()
print('reachable helpers:', len(reach), ' reachable sites:',
      sum(len(by_func[f]) for f in reach))
unreach = [f for f in by_func if f not in dist]
print('module-wide helpers with ptrtoint:', len(by_func), ' sites:', len(sites))
print('unreachable helpers:', len(unreach), ' sites:',
      sum(len(by_func[f]) for f in unreach))
print()
print('## unreachable helpers (module-wide, not reachable from any engine root)')
for f in sorted(unreach, key=lambda x: -len(by_func[x])):
    print(f"- `{demangle(f)}` ({len(by_func[f])} sites)")
