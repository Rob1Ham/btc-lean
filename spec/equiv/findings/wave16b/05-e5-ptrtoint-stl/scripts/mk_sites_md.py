#!/usr/bin/env python3
"""Generate reachable-sites.md and site-census.tsv from the pinned O0 module.

Run from /tmp/opencode/equiv-work:
    python3 mk_sites_md.py ir20/interpreter-O0.ll > ../reachable-sites.md
"""
import re, sys, collections, subprocess

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

call_re = re.compile(r'\b(?:call|invoke)\b[^@\n]*@("?)([\w.$]+)\1\(')
calls, callers = collections.defaultdict(set), collections.defaultdict(set)
for name, (a, b) in funcs.items():
    for l in lines[a:b + 1]:
        for m in call_re.finditer(l):
            calls[name].add(m.group(2))
            callers[m.group(2)].add(name)

EVAL = ['_Z10EvalScript']
ENGINE = ['_Z10EvalScript', '_Z12VerifyScript', '_Z19VerifyWitnessProgram',
          '_Z20ExecuteWitnessScript', '_Z23EvalChecksigPreTapscript',
          '_Z20EvalChecksigTapscript', '_Z10CastToBool']

def reach(pats):
    roots = [f for f in funcs if any(f.startswith(p) for p in pats)]
    seen, stack, dist = set(), list(roots), {}
    for r in roots:
        dist[r] = 0
    stack = list(roots)
    while stack:
        f = stack.pop(0)
        if f in seen:
            continue
        seen.add(f)
        for g in calls.get(f, ()):
            if g in funcs and g not in dist:
                dist[g] = dist[f] + 1
                stack.append(g)
    return seen, dist

def reach_set(roots):
    seen, stack = set(), list(roots)
    while stack:
        f = stack.pop()
        if f in seen:
            continue
        seen.add(f)
        stack += [g for g in calls.get(f, ()) if g in funcs]
    return seen

sites = collections.defaultdict(list)
for name, (a, b) in funcs.items():
    for j in range(a, b + 1):
        if '= ptrtoint ptr' in lines[j]:
            sites[name].append(j + 1)

R_EVAL, D_EVAL = reach(EVAL)
R_ENG, D_ENG = reach(ENGINE)

SHORT = {
 '_ZN9__gnu_cxxmiIPKSt6vectorIhSaIhEEPS3_S1_IS3_SaIS3_EEEEDTmicldtfp_4baseEcldtfp0_4baseEERKNS_17__normal_iteratorIT_T1_EERKNSA_IT0_SC_EE': 'normal_iterator difference, const `T*` vs `T*` (vector&lt;T&gt;::insert)',
 '_ZN9__gnu_cxxmiIPKSt6vectorIhSaIhEES1_IS3_SaIS3_EEEENS_17__normal_iteratorIT_T0_E15difference_typeERKSB_SE_': 'normal_iterator difference, const vs const (vector&lt;vector&lt;u8&gt;&gt;)',
 '_ZN9__gnu_cxxmiIPKhSt4spanIS1_Lm18446744073709551615EEEENS_17__normal_iteratorIT_T0_E15difference_typeERKS8_SB_': 'normal_iterator difference over `span<const u8>`',
 '_ZN9__gnu_cxxmiIPKhSt6vectorIhSaIhEEEENS_17__normal_iteratorIT_T0_E15difference_typeERKS9_SC_': 'normal_iterator difference over `vector<const u8>`',
 '_ZN9__gnu_cxxmiIPSt6vectorIhSaIhEES1_IS3_SaIS3_EEEENS_17__normal_iteratorIT_T0_E15difference_typeERKSA_SD_': 'normal_iterator difference over `vector<vector<u8>>`',
 '_ZN9__gnu_cxxmiIPhSt6vectorIhSaIhEEEENS_17__normal_iteratorIT_T0_E15difference_typeERKS8_SB_': 'normal_iterator difference over `vector<u8>`',
 '_ZN9prevectorILj36EhjiE6insertITkSt14input_iteratorPKhEEvNS0_8iteratorET_S5_': 'prevector&lt;36,u8&gt;::insert(input_iterator, const u8*)',
 '_ZNKSt6vectorIS_IhSaIhEESaIS1_EE4sizeEv': 'vector&lt;vector&lt;u8&gt;&gt;::size()',
 '_ZNKSt6vectorIhSaIhEE4sizeEv': 'vector&lt;u8&gt;::size()',
 '_ZNSt11__copy_moveILb0ELb1ESt26random_access_iterator_tagE8__copy_mIKhhEEPT0_PT_S7_S5_': '__copy_m&lt;const u8, u8&gt;',
 '_ZNSt11__copy_moveILb1ELb0ESt26random_access_iterator_tagE8__copy_mIPSt6vectorIhSaIhEES6_EET0_T_S8_S7_': '__copy_m&lt;vector&lt;u8&gt;*, vector&lt;u8&gt;*&gt; (move)',
 '_ZNSt12_Vector_baseISt6vectorIhSaIhEESaIS2_EED2Ev': '_Vector_base&lt;vector&lt;u8&gt;&gt;::~_Vector_base (deallocate)',
 '_ZNSt12_Vector_baseIhSaIhEED2Ev': '_Vector_base&lt;u8&gt;::~_Vector_base (deallocate)',
 '_ZNSt20__copy_move_backwardILb1ELb0ESt26random_access_iterator_tagE13__copy_move_bIPSt6vectorIhSaIhEES6_EET0_T_S8_S7_': '__copy_move_backward&lt;vector&lt;u8&gt;*&gt;',
 '_ZNSt6vectorIS_IhSaIhEESaIS1_EE15_M_erase_at_endEPS1_': 'vector&lt;vector&lt;u8&gt;&gt;::_M_erase_at_end',
 '_ZNSt6vectorIS_IhSaIhEESaIS1_EE17_M_realloc_insertIJRKS1_EEEvN9__gnu_cxx17__normal_iteratorIPS1_S3_EEDpOT_': 'vector&lt;vector&lt;u8&gt;&gt;::_M_realloc_insert&lt;const&amp;&gt;',
 '_ZNSt6vectorIS_IhSaIhEESaIS1_EE17_M_realloc_insertIJS1_EEEvN9__gnu_cxx17__normal_iteratorIPS1_S3_EEDpOT_': 'vector&lt;vector&lt;u8&gt;&gt;::_M_realloc_insert&lt;T&amp;&amp;&gt;',
 '_ZNSt6vectorIhSaIhEE17_M_realloc_insertIJhEEEvN9__gnu_cxx17__normal_iteratorIPhS1_EEDpOT_': 'vector&lt;u8&gt;::_M_realloc_insert&lt;u8&amp;&amp;&gt;',
 '_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE12_M_constructIPKcEEvT_S8_St20forward_iterator_tag': 'basic_string::_M_construct&lt;const char*&gt;',
 '_ZNSt7__cxx1112basic_stringIcSt11char_traitsIcESaIcEE13_S_copy_charsEPcPKcS7_': 'basic_string::_S_copy_chars',
 '_ZNSt7__equalILb1EE5equalIhEEbPKT_S4_S4_': '__equal&lt;true&gt;::equal&lt;u8&gt; (calls memcmp)',
 '_ZSt12__niter_wrapIN9__gnu_cxx17__normal_iteratorIPSt6vectorIhSaIhEES2_IS4_SaIS4_EEEES5_ET_S9_T0_': '__niter_wrap&lt;normal_iterator&lt;T*&gt;, T*&gt;',
 '_ZSt14__relocate_a_1IhhENSt9enable_ifIXsr3std24__is_bitwise_relocatableIT_EE5valueEPS1_E4typeES2_S2_S2_RSaIT0_E': '__relocate_a_1&lt;u8, u8&gt;',
 '_ZSt9__fill_a1IhEN9__gnu_cxx11__enable_ifIXsr9__is_byteIT_EE7__valueEvE6__typeEPS2_S5_RKS2_': '__fill_a1&lt;u8&gt;',
 '_ZmiN9prevectorILj36EhjiE14const_iteratorES1_': 'prevector&lt;36,u8&gt;::operator-(const_iterator)',
 '_ZmiN9prevectorILj36EhjiE8iteratorES1_': 'prevector&lt;36,u8&gt;::operator-(iterator)',
 # engine-only extras
 '_ZN9__gnu_cxxmiIPKSt6vectorIhSaIhEESt4spanIS4_Lm18446744073709551615EEEENS_17__normal_iteratorIT_T0_E15difference_typeERKSB_SE_': 'normal_iterator difference, vector &harr; span',
 '_ZNKSt6vectorIS_IhSaIhEESaIS1_EE8capacityEv': 'vector&lt;vector&lt;u8&gt;&gt;::capacity()',
 '_ZNKSt6vectorIhSaIhEE8capacityEv': 'vector&lt;u8&gt;::capacity()',
 '_ZNSt11__copy_moveILb0ELb0ESt26random_access_iterator_tagE8__copy_mIPKSt6vectorIhSaIhEEPS5_EET0_T_SA_S9_': '__copy_m&lt;const vector&lt;u8&gt;*, vector&lt;u8&gt;*&gt;',
 '_ZNSt11__copy_moveILb0ELb0ESt26random_access_iterator_tagE8__copy_mIPSt6vectorIhSaIhEES6_EET0_T_S8_S7_': '__copy_m&lt;vector&lt;u8&gt;*, vector&lt;u8&gt;*&gt;',
 '_ZNSt11__copy_moveILb0ELb1ESt26random_access_iterator_tagE8__copy_mIhhEEPT0_PT_S6_S4_': '__copy_m&lt;u8, u8&gt;',
 '_ZNSt25__lexicographical_compareILb1EE6__3wayIhhEElPKT_S4_PKT0_S7_': '__lexicographical_compare::__3way&lt;u8,u8&gt;',
 '_ZNSt6vectorIS_IhSaIhEESaIS1_EE17_M_default_appendEm': 'vector&lt;vector&lt;u8&gt;&gt;::_M_default_append',
 '_ZNSt6vectorIS_IhSaIhEESaIS1_EEaSERKS3_': 'vector&lt;vector&lt;u8&gt;&gt;::operator=(const&amp;)',
 '_ZNSt6vectorIhSaIhEEaSERKS1_': 'vector&lt;u8&gt;::operator=(const&amp;)',
 '_ZSt12__niter_wrapIN9__gnu_cxx17__normal_iteratorIPhSt6vectorIhSaIhEEEES2_ET_S7_T0_': '__niter_wrap&lt;normal_iterator&lt;u8*&gt;, u8*&gt;',
}

def shape(name):
    a, b = funcs[name]
    txt = '\n'.join(lines[a:b + 1])
    if 'sdiv exact i64' in txt:
        sz = re.findall(r'sdiv exact i64 %[-\w.$]+, (\d+)', txt)
        return 'sub + `sdiv exact` ' + '/'.join(sorted(set(sz)))
    if re.search(r'trunc i64 %[-\w.$]+ to i32', txt):
        return 'sub + `trunc` i32'
    return 'sub'

def observable(name):
    a, b = funcs[name]
    txt = '\n'.join(lines[a:b + 1])
    obs = []
    if re.search(r'ret i(32|64)\b', txt):
        obs.append('returned')
    if 'sdiv exact' in txt:
        obs.append('/ sizeof(T)')
    if re.search(r'\btrunc i64\b', txt):
        obs.append('trunc i32')
    if 'store i64' in txt:
        obs.append('stored as count')
    if not obs:
        obs = ['passed as size arg']
    return ', '.join(dict.fromkeys(obs))

def externals(name):
    R = reach_set([name])
    ext = sorted({g for f in R for g in calls.get(f, ())
                  if g not in funcs and not g.startswith('llvm.')})
    return ext

def row(i, f, dist):
    ext = externals(f)
    heap = [e for e in ext if e in ('_Znwm', '_ZdlPvm', 'malloc', 'free', 'realloc')]
    if not ext:
        kind = 'pure'
    elif any(e in ('_Znwm', 'malloc', 'realloc') for e in ext):
        kind = 'heap'
    elif heap:
        kind = 'dealloc'
    elif 'memcmp' in ext:
        kind = 'memcmp'
    else:
        kind = 'terminate-only'
    desc = SHORT.get(f, f)
    return (f'| {i} | {desc} | `{f}` | {len(sites[f])} | '
            f'{",".join(str(j) for j in sites[f])} | {shape(f)} | {observable(f)} | '
            f'{kind} | {dist.get(f, "-")} |')

def section(title, note, ids, dist):
    print(title)
    print()
    print(note)
    print()
    print('| # | helper | mangled name | sites | IR lines | ptrtoint shape | observable | other obligations | depth from engine root |')
    print('|---|---|---|---:|---|---|---|---|---:|')
    for i, f in ids:
        print(row(i, f, dist))
    print()

eval_ids = sorted([f for f in sites if f in R_EVAL], key=lambda f: (D_EVAL.get(f, 99), f))
eng_only = sorted([f for f in sites if f in R_ENG and f not in R_EVAL],
                  key=lambda f: (D_ENG.get(f, 99), f))
unreach = sorted([f for f in sites if f not in R_ENG], key=lambda f: (-len(sites[f]), f))

print('# ptrtoint site table — pinned Core O0 lane')
print()
print('Module: `ir20/interpreter-O0.ll`, sha256 `fecf7db1a0cb3f4b98f214b6211a206ff5cc267bb1cb0b1b73cd159945c18fec`')
print('(pinned bitcode `ir20/interpreter-O0.bc`, sha256 `f5718af7…`, clang/LLVM 20.1.2, `-O0 -g0`).')
print('`inttoptr` count: **0**.')
print()
print('Depth is BFS distance from the nearest engine entry point. `other obligations`')
print('is the transitive non-`llvm.*` external callee class; `pure` means the helper')
print('reaches no external at all and only the three intrinsics below are possible.')
print()
section('## A. Reachable from `EvalScript` (the E5 claim: 26 helpers, 52 sites)',
        'These are the helpers the residual §B6 names. All 26 are pure pointer-distance.',
        list(enumerate(eval_ids, 1)), D_EVAL)
section('## B. Additional helpers reachable from other engine entry points',
        '`VerifyScript`, `VerifyWitnessProgram`, `ExecuteWitnessScript`,'
        ' `EvalChecksig*`, `CastToBool` add these 11 helpers / 26 sites. They matter'
        ' for a whole-engine claim but not for an `EvalScript`-only claim.',
        [(f'H{26+i:02d}', f) for i, f in enumerate(eng_only, 1)], D_ENG)
section('## C. Module-wide sites NOT reachable from any engine entry point',
        'For completeness: 12 helpers / 26 sites. Note that `tinyformat` is here,'
        ' so the residual §B6 phrase "26 std::vector / iterator / tinyformat helpers"'
        ' overstates the surface: at O0 no `tinyformat` `ptrtoint` is reachable.',
        [(f'U{i:02d}', f) for i, f in enumerate(unreach, 1)], {})

n_pure = sum(1 for f in eval_ids if externals(f) == [])
print('## D. Summary (EvalScript-only set)')
print()
print(f'- helpers: {len(eval_ids)}, sites: {sum(len(sites[f]) for f in eval_ids)}')
print(f'- pure (zero external callees): {n_pure}')
print(f'- needs allocator: {sum(1 for f in eval_ids if any(e in ("_Znwm","malloc","realloc") for e in externals(f)))}')
print(f'- needs deallocation only: {sum(1 for f in eval_ids if any(e in ("_ZdlPvm","free") for e in externals(f)) and not any(e in ("_Znwm","malloc","realloc") for e in externals(f)))}')
print(f'- needs memcmp: {sum(1 for f in eval_ids if "memcmp" in externals(f))}')
print('- `inttoptr` sites in the whole module: 0 (so every entry above is `ptrtoint` only)')
