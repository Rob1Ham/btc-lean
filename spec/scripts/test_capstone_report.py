#!/usr/bin/env python3
"""Prevent incomplete or contradictory replay output from becoming green."""
import contextlib
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
import unittest

SPEC = importlib.util.spec_from_file_location('capstone_report', Path(__file__).with_name('capstone_report.py'))
REPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(REPORT)

class ReportTests(unittest.TestCase):
    def invoke(self, text):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder)/'run.log'
            path.write_text(text)
            old = sys.argv
            try:
                sys.argv = ['capstone_report.py', str(path)]
                with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                    return REPORT.main()
            finally:
                sys.argv = old

    def test_complete_partial_replay(self):
        self.assertEqual(self.invoke(self.complete()), 0)
        self.assertEqual(self.invoke(self.complete().replace(' missing=0', '')), 0)

    @staticmethod
    def complete():
        return ('ANCHOR 0 ok=true reason= txs=1 scriptOk=0 scriptUnjudged=0 '
                'scriptAdjudication=complete foldAgrees=true ms=1 hash='+REPORT.CANONICAL[0]+'\n'
                'SUMMARY blocks=1 missing=0 allOk=true totalMs=1\n')

    def test_incomplete_and_contradictory_runs_fail(self):
        original = self.complete()
        variants = [
            original.replace('scriptUnjudged=0', 'scriptUnjudged=1'),
            original.replace('scriptAdjudication=complete', 'scriptAdjudication=incomplete'),
            original.replace(' scriptAdjudication=complete', ''),
            original.replace('foldAgrees=true', 'foldAgrees=false'),
            original.replace('ok=true reason=', 'ok=false reason=script-data-unavailable'),
            original.replace('allOk=true', 'allOk=false'),
            original.replace('missing=0', 'missing=1'),
            original.replace('blocks=1', 'blocks=2'),
            original.split('SUMMARY')[0],
            'SUMMARY blocks=0 missing=0 allOk=true totalMs=0\n',
            '',
        ]
        for text in variants:
            with self.subTest(text=text):
                self.assertNotEqual(self.invoke(text), 0)

if __name__ == '__main__':
    unittest.main()
