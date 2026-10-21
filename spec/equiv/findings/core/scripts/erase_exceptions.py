#!/usr/bin/env python3
"""Erase C++ exception edges from textual LLVM IR (prototype).

- invoke X to label %A unwind label %B  ->  call X ; br label %A
- every block whose body starts with a landingpad becomes `unreachable`
- resume {ptr,i32} %x                  ->  unreachable
- function `personality` attribute     -> dropped

This is a domain-restricting transform: it assumes no exception is thrown on
the analysed inputs. Unwind paths become unreachable.
"""
import re, sys

src, dst = sys.argv[1], sys.argv[2]
lines = open(src).read().split('\n')

out = []
i = 0
n_converted = 0
while i < len(lines):
    l = lines[i]
    if re.search(r'\binvoke\b', l) and not l.lstrip().startswith(';'):
        # gather a possible continuation line
        buf = l
        extra = []
        while 'unwind label' not in buf and i + 1 < len(lines):
            i += 1
            extra.append(lines[i])
            buf += ' ' + lines[i].strip()
        m = re.match(r'^(\s*)((?:%[-\w.$]+ = )?)invoke (.*?) to label %([-\w.$]+) unwind label %([-\w.$]+)\s*$', buf)
        if not m:
            out.append(l); out.extend(extra); i += 1; continue
        indent, lhs, callpart, ok, _unwind = m.groups()
        out.append(f"{indent}{lhs}call {callpart}")
        out.append(f"{indent}br label %{ok}")
        n_converted += 1
        i += 1
        continue
    out.append(l)
    i += 1

# Rewrite landingpad blocks to unreachable
lines = out
out = []
i = 0
n_lp = 0
in_func = False
while i < len(lines):
    l = lines[i]
    if l.startswith('define '):
        in_func = True
        pass
    elif l.startswith('}'):
        in_func = False
    if in_func and re.match(r'^[-\w.$]+:', l):
        # gather block
        label = l
        j = i + 1
        body = []
        while j < len(lines) and not re.match(r'^[-\w.$]+:', lines[j]) and not lines[j].startswith('}'):
            body.append(lines[j]); j += 1
        if any(re.search(r'\blandingpad\b', b) for b in body):
            out.append(label)
            n_lp += 1
            skipping_clauses = False
            for x in body:
                if skipping_clauses and re.match(r'^\s+(cleanup|catch |filter )', x):
                    continue
                skipping_clauses = False
                m = re.match(r'^(\s*)(%[-\w.$]+) = landingpad \{[^}]*\}.*$', x)
                if m:
                    out.append(f"{m.group(1)}{m.group(2)} = insertvalue {{ ptr, i32 }} poison, ptr null, 0")
                    skipping_clauses = True
                else:
                    out.append(x)
            i = j
            continue
        out.append(label)
        out.extend(body)
        i = j
        continue
    if re.match(r'^\s+resume\b', l):
        l = '  unreachable'
    out.append(l)
    i += 1

# final sweep: any resume left in an unreachable handler block
out = [re.sub(r'^\s+resume\b.*$', '  unreachable', l) for l in out]
# drop personality attributes: with no landingpad they are dead weight
out = [re.sub(r'\s+personality\s+ptr\s+@\S+', '', l) if l.startswith('define ') else l for l in out]
open(dst, 'w').write('\n'.join(out))
print(f"converted invokes: {n_converted}, neutralised landingpad blocks: {n_lp}")
