#!/usr/bin/env python3
"""Census of ptrtoint/inttoptr over the pinned module variants and root sets.

Usage: census.py <file.ll> [<file.ll> ...]

Prints, per variant and per root set, the number of ptrtoint sites, the number
of helpers that contain them, and how many results are used exactly once as an
operand of a `sub` whose other operand is also a ptrtoint (the "pure distance"
shape).  Any escape (store / icmp / call argument / other arithmetic / second
use) is counted as a violation.
"""
import re, sys, collections

def parse(path):
    lines = open(path, errors='replace').read().splitlines()
    funcs, cur = {}, None
    for i, l in enumerate(lines):
        if l.startswith('define '):
            m = re.search(r'@("?)([^ ("\)]+)\1\(', l)
            cur = m.group(2)
            funcs[cur] = [i, None]
        elif l.startswith('}') and cur is not None:
            funcs[cur][1] = i
            cur = None
    if cur:
        funcs[cur][1] = len(lines) - 1
    return lines, funcs

call_re = re.compile(r'\b(?:call|invoke)\b[^@\n]*@("?)([\w.$]+)\1\(')

def calls_of(lines, funcs):
    calls = collections.defaultdict(set)
    for name, (a, b) in funcs.items():
        for l in lines[a:b + 1]:
            for m in call_re.finditer(l):
                calls[name].add(m.group(2))
    return calls

def reachable(funcs, calls, roots):
    seen, stack = set(), list(roots)
    while stack:
        f = stack.pop()
        if f in seen:
            continue
        seen.add(f)
        for g in calls.get(f, ()):
            if g in funcs:
                stack.append(g)
    return seen

def sites_of(lines, funcs):
    out = collections.defaultdict(list)
    for name, (a, b) in funcs.items():
        for j in range(a, b + 1):
            if ' ptrtoint ' in lines[a + j - a] and False:
                pass
        for j in range(a, b + 1):
            l = lines[j]
            if ' ptrtoint ' in l or ' inttoptr ' in l:
                out[name].append((j + 1, l.strip()))
    return out

def shape_ok(lines, funcs, name):
    """Return (ok, violations) for this function's ptrtoint results."""
    a, b = funcs[name]
    body = lines[a:b + 1]
    # map value -> def line idx
    defs = {}
    bad = []
    for j, l in enumerate(body):
        m = re.match(r'\s*(%[-\w.$]+)\s*=\s*ptrtoint\s+ptr\s+(%[-\w.$]+)', l)
        if m:
            defs[m.group(1)] = j
    for val, j in defs.items():
        uses = []
        for k in range(j + 1, len(body)):
            if re.search(re.escape(val) + r'(?![\w.$])', body[k]):
                uses.append(k)
        if len(uses) != 1:
            bad.append((a + j + 1, val, f'{len(uses)} uses'))
            continue
        sub = re.search(r'^\s*(%[-\w.$]+)\s*=\s*sub\s+i\d+\s+(.*)$', body[uses[0]])
        if not sub:
            bad.append((a + j + 1, val, 'use is not sub'))
            continue
        ops = sub.group(2)
        # other operand must itself be a ptrtoint-defined value
        others = [v for v in re.findall(r'%[-\w.$]+', ops) if v != val]
        if not others or others[0] not in defs:
            bad.append((a + j + 1, val, 'other sub operand is not a ptrtoint'))
    return (not bad), bad

EVAL = ['_Z10EvalScript']
ENGINE = ['_Z10EvalScript', '_Z12VerifyScript', '_Z19VerifyWitnessProgram',
          '_Z20ExecuteWitnessScript', '_Z23EvalChecksigPreTapscript',
          '_Z20EvalChecksigTapscript', '_Z10CastToBool']

print('# ptrtoint/inttoptr census (pinned clang 20.1.2 IR)')
print()
print('| module | roots | funcs | ptrtoint | inttoptr | helpers | pure-distance | violations |')
print('|---|---|---:|---:|---:|---:|---:|---:|')
for path in sys.argv[1:]:
    lines, funcs = parse(path)
    calls = calls_of(lines, funcs)
    sites = sites_of(lines, funcs)
    for label, pats in (('EvalScript', EVAL), ('engine entry points', ENGINE),
                        ('module-wide', None)):
        roots = [f for f in funcs if pats and any(f.startswith(p) for p in pats)]
        seen = reachable(funcs, calls, roots) if pats else set(funcs)
        sel = [f for f in sites if f in seen]
        n_pt = sum(1 for f in sel for _, l in sites[f] if ' ptrtoint ' in l)
        n_it = sum(1 for f in sel for _, l in sites[f] if ' inttoptr ' in l)
        ok = viol = 0
        for f in sel:
            good, bad = shape_ok(lines, funcs, f)
            ok += 1 if good else 0
            viol += len(bad)
        print(f'| `{path}` | {label} | {len(funcs)} | {n_pt} | {n_it} | '
              f'{len(sel)} | {ok} | {viol} |')
    print()
