#!/usr/bin/env python3
"""Require six pre-R06 public-pipeline failures and two missing-coin controls.

Uses the unchanged mined fixture, helper and driver against a namespaced
parent Block.lean. Compile failures, timeouts or missing rows are errors.
"""
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BEFORE = '62d11c6'

def main():
    commit = subprocess.check_output(['git', 'rev-parse', BEFORE+'^{commit}'], cwd=ROOT, text=True).strip()
    source = subprocess.check_output(['git', 'show', commit+':spec/core/Bitcoin/Capstone/Block.lean'], cwd=ROOT, text=True)
    helpers = (ROOT/'spec/core/Test/Capstone/TaprootFixture.lean').read_text()
    driver = (ROOT/'spec/core/Test/Capstone/TaprootBlocks.lean').read_text()
    imports = list(dict.fromkeys(line for text in [source, helpers, driver]
        for line in text.splitlines() if line.startswith('import ') and line not in
        ['import Bitcoin.Capstone.Block', 'import Test.Capstone.TaprootFixture']))
    bodies = '\n'.join('\n'.join(line for line in text.splitlines() if not line.startswith('import '))
                       for text in [source, helpers, driver])
    text = '\n'.join(imports)+'\n'+bodies.replace('Bitcoin.Capstone.Block', 'Bitcoin.Capstone.BeforeTaproot')
    with tempfile.TemporaryDirectory(prefix='btc-taproot-block-before-') as folder:
        path = Path(folder)/'Before.lean'
        path.write_text(text)
        proc = subprocess.run(['lake', 'env', 'lean', '--run', str(path)], cwd=ROOT/'spec/core',
                              capture_output=True, text=True, timeout=180)
    rows = re.findall(r'^\[(PASS|FAIL)\] (.*): expected=(.*), actual=(.*)$', proc.stdout, re.MULTILINE)
    names = ['real signed key/script paths and same-block cache',
             'key-path signature binds actual previous amount', 'script path binds actual previous output key']
    expected = {prefix+' '+name for prefix in ['context', 'replay'] for name in names}
    controls = {prefix+' missing coin is rejected before scripts' for prefix in ['context', 'replay']}
    if (proc.returncode != 1 or len(rows) != 8 or len({r[1] for r in rows}) != 8 or
        {r[1] for r in rows if r[0] == 'FAIL'} != expected or
        {r[1] for r in rows if r[0] == 'PASS'} != controls or
        not all((r[2] == r[3]) == (r[0] == 'PASS') for r in rows) or
        not all(r[3] == 'ok:2:10' for r in rows if r[0] == 'FAIL')):
        raise ValueError(proc.stdout+proc.stderr)
    for row in rows:
        print(f'[{row[0]}] {row[1]}: expected={row[2]}, actual={row[3]}')
    print(json.dumps(dict(baseline_commit=commit, old_lean_exit=1, expected_failures=6,
                          passing_controls=2, reproduction='confirmed')))

if __name__ == '__main__':
    main()
