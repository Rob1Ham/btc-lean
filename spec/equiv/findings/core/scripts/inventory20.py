#!/usr/bin/env python3
"""Feature inventory for the pinned-clang (20.1.2) Core interpreter IR."""
import hashlib, re, sys, collections

def sha(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()

def scan(path):
    lines = open(path, errors='replace').read().splitlines()
    mod = collections.Counter()
    funcs = []
    cur = None
    for i, l in enumerate(lines):
        if l.startswith('define '):
            m = re.search(r'@([^ (]+)\(', l)
            cur = {'name': m.group(1), 'line': i + 1, 'invoke': 0,
                   'landingpad': 0, 'indcall': 0, 'ptrtoint': 0,
                   'inttoptr': 0, 'instr': 0}
            funcs.append(cur)
        elif l.startswith('}') and cur:
            cur = None
        if cur:
            cur['instr'] += 1
            cur['invoke'] += l.count(' invoke ')
            cur['landingpad'] += l.count('landingpad')
            cur['ptrtoint'] += l.count(' ptrtoint ')
            cur['inttoptr'] += l.count(' inttoptr ')
            if re.search(r'(invoke|call) [^@\n]*%[-\w.$]+ *\(', l):
                cur['indcall'] += 1
        for pat, name in [(' invoke ', 'invoke'), ('landingpad', 'landingpad'),
                          (' resume ', 'resume'), (' ptrtoint ', 'ptrtoint'),
                          (' inttoptr ', 'inttoptr'), ('personality', 'personality'),
                          ('llvm.trap', 'llvm.trap'), ('__cxa_guard', 'cxa_guard'),
                          ('llvm.eh.typeid.for', 'eh.typeid')]:
            mod[name] += l.count(pat)
        if re.search(r'(invoke|call) [^@\n]*%[-\w.$]+ *\(', l):
            mod['indcall'] += 1
    mod['defines'] = sum(1 for l in lines if l.startswith('define '))
    mod['declares'] = sum(1 for l in lines if l.startswith('declare '))
    mod['lines'] = len(lines)
    return mod, funcs

variants = [
    ('unpatched-O0', 'ir20/interpreter-O0.bc', 'ir20/interpreter-O0.ll'),
    ('unpatched-O1', 'ir20/interpreter-O1.bc', 'ir20/interpreter-O1.ll'),
    ('unpatched-O0-ftrapv', 'ir20/interpreter-O0-ftrapv.bc', 'ir20/interpreter-O0-ftrapv.ll'),
    ('hoist-only-O0', 'ir20-proto/interpreter-O0-hoistonly.bc', 'ir20-proto/interpreter-O0-hoistonly.ll'),
    ('patched-O0', 'ir20-proto/interpreter-O0-patched.bc', 'ir20-proto/interpreter-O0-patched.ll'),
    ('patched-O1', 'ir20-proto/interpreter-O1-patched.bc', 'ir20-proto/interpreter-O1-patched.ll'),
    ('patched-O0-erased', 'ir20-proto/interpreter-O0-patched-noexc-s.bc', 'ir20-proto/interpreter-O0-patched-noexc-s.ll'),
    ('patched-O0-erased-internalized', 'ir20-proto/roots.bc', 'ir20-proto/roots.bc.ll'),
]
keys = ['EvalScript', 'VerifyScript', 'VerifyWitnessProgram', 'ExecuteWitnessScript',
        'EvalChecksigPreTapscript', 'EvalChecksigTapscript', 'CastToBool',
        'CheckSignatureEncoding', 'CScriptNumC2ERKSt6vector', 'CountWitnessSigOps',
        'FindAndDelete']
print('variant\tbc\tsha256\tlines\tdefines\tdeclares\tinvoke\tlandingpad\tresume\tptrtoint\tinttoptr\tindirect_callsites\tpersonality\tcxa_guard\teh.typeid')
for name, bc, ll in variants:
    m, _ = scan(ll)
    print('\t'.join(map(str, [name, bc, sha(bc), m['lines'], m['defines'], m['declares'],
          m['invoke'], m['landingpad'], m['resume'], m['ptrtoint'], m['inttoptr'],
          m['indcall'], m['personality'], m['cxa_guard'], m['eh.typeid']])))
print()
print('variant\tfunction\tir_line\tbody_lines\tinvoke\tlandingpad\tptrtoint\tinttoptr\tindirect_callsites')
for name, bc, ll in variants:
    if name not in ('unpatched-O0', 'unpatched-O1', 'patched-O0', 'patched-O0-erased', 'patched-O1'):
        continue
    _, funcs = scan(ll)
    for f in funcs:
        if any(k in f['name'] for k in keys):
            print('\t'.join(map(str, [name, f['name'], f['line'], f['instr'],
                  f['invoke'], f['landingpad'], f['ptrtoint'], f['inttoptr'], f['indcall']])))
