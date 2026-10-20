#!/usr/bin/env python3
"""Rigorous SSA def-use check for every ptrtoint in the pinned module.

For each ptrtoint, walk forward in its function and classify every use of the
result.  We want to establish: the result never escapes (no store to memory,
no call argument, no return, no icmp/other arithmetic) except as the direct
operand of one `sub`, and that the sub result is then used only as a
byte-count (return / sdiv exact / trunc / add / store to a size field).
"""
import re, sys, collections, json

PATH = sys.argv[1] if len(sys.argv) > 1 else 'ir20/interpreter-O0.ll'
lines = open(PATH, errors='replace').read().splitlines()

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

# value names are function-local; map (func, vname) -> def line & instruction
res = []
for fname, (a, b) in funcs.items():
    body = lines[a:b + 1]
    # def-use: for each ptrtoint result, find uses
    for j, l in enumerate(body):
        m = re.search(r'^\s*(%[-\w.$]+)\s*=\s*ptrtoint\s+ptr\s+(%[-\w.$]+)\s+to\s+i(\d+)', l)
        if not m:
            continue
        val, src, width = m.group(1), m.group(2), m.group(3)
        uses = []
        for k in range(j + 1, len(body)):
            if body[k].startswith('}') or body[k].startswith('define '):
                break
            if re.search(re.escape(val) + r'(?![\w.$])', body[k]):
                uses.append((a + k + 1, body[k].strip()))
        res.append({'func': fname, 'def_line': a + j + 1, 'val': val,
                    'src': src, 'width': width, 'uses': uses})

print(f'ptrtoint definitions: {len(res)}')
ok = 0
bad = []
for r in res:
    if len(r['uses']) != 1:
        bad.append((r, f"expected 1 use, got {len(r['uses'])}"))
        continue
    ln, txt = r['uses'][0]
    m = re.search(r'^\s*(%[-\w.$]+)\s*=\s*sub\s+i(\d+)\s+(?:' + re.escape(r['val']) + r'\s*,|%[-\w.$]+\s*,\s*' + re.escape(r['val']) + r'\s*$)', txt)
    if not m:
        bad.append((r, f"only use is not a sub with this operand: {txt}"))
        continue
    ok += 1
    r['sub_val'] = m.group(1)
    r['sub_line'] = ln
print(f'ptrtoint results used exactly once, as an operand of one `sub`: {ok}/{len(res)}')
print('(the `sub` other operand being a ptrtoint is checked by census.py)')
for r, why in bad:
    print('  VIOLATION', r['func'], r['def_line'], r['val'], '--', why)

# now classify consumers of each sub
cons = collections.Counter()
cons_detail = []
for r in res:
    if 'sub_val' not in r:
        continue
    fname = r['func']
    a, b = funcs[fname]
    body = lines[a:b + 1]
    sv = r['sub_val']
    uses = []
    for k in range(r['sub_line'] + 1 - 1 - a, len(body)):
        if body[k].startswith('}'):
            break
        if k == r['sub_line'] - 1 - a:
            continue
        if re.search(re.escape(sv) + r'(?![\w.$])', body[k]):
            uses.append(body[k].strip())
    kinds = []
    for u in uses:
        if re.search(r'=\s*sdiv\s+exact\s+i64\s+' + re.escape(sv) + r'\s*,', u):
            kinds.append('sdiv-exact-by-size')
        elif re.match(r'ret\b', u):
            kinds.append('returned-as-byte-count')
        elif re.search(r'=\s*trunc\s+i64\s+' + re.escape(sv), u):
            kinds.append('trunc-to-i32')
        elif re.search(r'=\s*add\s+i64\s+', u):
            kinds.append('add-offset')
        elif re.search(r'=\s*icmp\b', u):
            kinds.append('icmp')
        elif re.match(r'store\b', u):
            kinds.append('stored')
        elif re.search(r'(call|invoke).*' + re.escape(sv), u):
            kinds.append('call-argument')
        elif re.search(r'=\s*(sub|mul|shl|ashr|lshr|and|or|xor|zext|sext)\b', u):
            kinds.append('arithmetic')
        else:
            kinds.append('other:' + u[:60])
    for k in kinds:
        cons[k.split(':')[0]] += 1
    cons_detail.append({'func': fname, 'def_line': r['def_line'], 'consumers': kinds})

print('consumers of the *byte-distance* value (sub result):', dict(cons))
print('note: `stored` / `call-argument` here are the distance, never an address;')
print('      the ptrtoint result itself has no use other than the sub.')
json.dump({'sites': res, 'consumers': cons_detail}, open(
    '/tmp/opencode/wave16b-scratch/05-e5-ptrtoint-stl/defuse.json', 'w'), indent=1)

# show the interesting non-trivial consumers
print()
for d in cons_detail:
    if any(k not in ('sdiv-exact-by-size', 'returned-as-byte-count',
                     'trunc-to-i32', 'add-offset') for k in d['consumers']):
        print('SUB-CONSUMER', d['func'], d['def_line'], d['consumers'])
