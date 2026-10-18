#!/usr/bin/env python3
"""Require two old compatibility-ECDSA failures and two production controls.

The old full module has broken proof contracts. This harness executes its
unchanged three executable definitions, omitting its proof section. Compile
errors or incomplete output cannot count as runtime regression evidence.
"""
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
BEFORE = '62d11c60d7dc6653981877fe1027b1b00f523745'


def main():
    source = subprocess.check_output(['git', 'show', BEFORE+':spec/core/Bitcoin/Crypto/EcdsaDeep/SchnorrEntry2.lean'],
                                     cwd=ROOT, text=True)
    prefix = source.split('/-! ## The flip is the only change: definitional pins -/')[0]
    if prefix == source:
        raise ValueError('missing executable/proof boundary')
    helpers = (ROOT/'spec/core/Test/Capstone/TaprootFixture.lean').read_text()
    driver = (ROOT/'spec/core/Test/Capstone/SchnorrAssembly.lean').read_text()
    imports = list(dict.fromkeys(line for text in [prefix, helpers, driver] for line in text.splitlines()
        if line.startswith('import ') and line not in
        ['import Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2', 'import Test.Capstone.TaprootFixture']))
    strip = lambda text: '\n'.join(line for line in text.splitlines() if not line.startswith('import '))
    body = strip(prefix)+'\nend Bitcoin.Crypto.EcdsaDeep.SchnorrEntry2\n'+strip(helpers)+'\n'+strip(driver)
    text = '\n'.join(imports)+'\n'+body.replace('Bitcoin.Crypto.EcdsaDeep', 'Bitcoin.Crypto.BeforeSchnorrAssembly')
    with tempfile.TemporaryDirectory(prefix='btc-schnorr-assembly-before-') as folder:
        path = Path(folder)/'Before.lean'
        path.write_text(text)
        proc = subprocess.run(['lake', 'env', 'lean', '--run', str(path)], cwd=ROOT/'spec/core',
                              capture_output=True, text=True, timeout=120)
    rows = re.findall(r'^\[(PASS|FAIL)\] (.*): expected=(.*), actual=(.*)$', proc.stdout, re.MULTILINE)
    failures = {f'compatibility ECDSA input {i}' for i in [2, 5]}
    controls = {f'production ECDSA control {i}' for i in [2, 5]}
    if (proc.returncode != 1 or len(rows) != 4 or len({r[1] for r in rows}) != 4 or
        {r[1] for r in rows if r[0] == 'FAIL'} != failures or
        {r[1] for r in rows if r[0] == 'PASS'} != controls or
        not all((r[2] == r[3]) == (r[0] == 'PASS') for r in rows) or
        not all(r[3] == 'Bitcoin.Interpreter.ExecError.evalFalse' for r in rows if r[0] == 'FAIL')):
        raise ValueError(proc.stdout+proc.stderr)
    for row in rows:
        print(f'[{row[0]}] {row[1]}: expected={row[2]}, actual={row[3]}')
    print(json.dumps(dict(baseline_commit=BEFORE, executable_prefix_sha256=hashlib.sha256(prefix.encode()).hexdigest(),
                          old_lean_exit=1, expected_failures=2, passing_controls=2,
                          scope='Three executable definitions only; original proof section omitted explicitly',
                          reproduction='confirmed')))


if __name__ == '__main__':
    main()
