#!/usr/bin/env python3
"""Typecheck the refreshed S02 fixtures without its closed reduction experiments.

This is a declaration/interface check, not a successful full-module build.
The original measurement-only file and its 20 closed experiments remain
unchanged in purpose and remain part of the outstanding full-matrix review.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT/'spec/proofs/BitcoinProofs/EcdsaDeep/S02Flip.lean'
EXPECTED_SHA256 = '5d08a9c64e7361d3ae833315e3a94f68788c776036d18bd91340f8f56bc9898b'


def main():
    source = SOURCE.read_bytes()
    if hashlib.sha256(source).hexdigest() != EXPECTED_SHA256:
        raise ValueError('S02 source changed; review the partial-check extraction before updating its pin')
    output, omitted, skipping = [], 0, False
    for line in source.decode().splitlines():
        if line.startswith('example '):
            skipping = True
            omitted += 1
            continue
        if skipping:
            if not line.strip():
                skipping = False
                output.append(line)
            continue
        output.append(line)
    if omitted != 20:
        raise ValueError(f'Unexpected closed-experiment count: {omitted}')
    with tempfile.TemporaryDirectory(prefix='btc-s02-declarations-') as folder:
        path = Path(folder)/'Declarations.lean'
        path.write_text('\n'.join(output)+'\n')
        result = subprocess.run(['lake', 'env', 'lean', str(path)], cwd=ROOT/'spec/proofs',
                                capture_output=True, text=True, timeout=60)
    if result.returncode:
        raise ValueError(result.stdout+result.stderr)
    print(json.dumps(dict(status='declarations_checked_only', full_module_build='not_checked',
                          omitted_closed_experiments=omitted, source_sha256=EXPECTED_SHA256,
                          timeout_seconds=60, lean_exit_code=result.returncode)))


if __name__ == '__main__':
    main()
