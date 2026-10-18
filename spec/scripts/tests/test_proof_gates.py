"""End-to-end negative cases for the deliverable proof hygiene gates."""
from pathlib import Path
import os
from concurrent.futures import ThreadPoolExecutor
import shutil
import subprocess
import sys
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[3]


class ProofGates(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="btc-proof-gate-test-")
        self.addCleanup(self.tmp.cleanup)
        self.spec = Path(self.tmp.name) / "spec"
        for part in ("scripts", "db", "core", "proofs", "tmp"):
            (self.spec / part).mkdir(parents=True)
        for name in ("axiom_manifest.sh", "sorry_lint.py", "axiom_manifest_check.py"):
            source = REPO / "spec/scripts" / name
            if source.exists():
                shutil.copyfile(source, self.spec / "scripts" / name)

    def manifest(self, content):
        (self.spec / "db/axiom-manifest.txt").write_text(content)
        return subprocess.run(
            ["bash", str(self.spec / "scripts/axiom_manifest.sh"), "--check-static"],
            capture_output=True, text=True, check=False,
        )

    def lint(self, content, tree="core"):
        (self.spec / tree / "Fixture.lean").write_text(content)
        return subprocess.run(
            [sys.executable, str(self.spec / "scripts/sorry_lint.py")],
            capture_output=True, text=True, check=False,
        )

    def dynamic_probe(self, output, initial, mode=None, copies=1):
        manifest = self.spec / "db/axiom-manifest.txt"
        manifest.write_text(initial)
        (self.spec / "scripts/axiom_probe.lean").write_text("-- isolated probe fixture\n")
        bindir = self.spec / "bin"
        bindir.mkdir()
        lake = bindir / "lake"
        lake.write_text(
            f"#!{sys.executable}\nimport time\ntime.sleep(0.05)\nprint({output!r}, end='')\n"
        )
        lake.chmod(0o755)
        argv = ["bash", str(self.spec / "scripts/axiom_manifest.sh")]
        if mode:
            argv.append(mode)
        env = os.environ | {
            "PATH": str(bindir) + os.pathsep + os.environ["PATH"],
            "TMPDIR": str(self.spec / "tmp"),
        }

        def invoke(_):
            return subprocess.run(argv, capture_output=True, text=True, check=False, env=env)

        if copies > 1:
            with ThreadPoolExecutor(max_workers=copies) as pool:
                return list(pool.map(invoke, range(copies))), manifest.read_text()
        result = invoke(0)
        return result, manifest.read_text()

    def test_standard_axioms_and_empty_footprints_pass(self):
        result = self.manifest(
            "'Example.empty' does not depend on any axioms\n"
            "'Example.standard' depends on axioms: [propext, Classical.choice,\n"
            " Quot.sound]\n"
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_arbitrary_custom_axiom_is_rejected(self):
        result = self.manifest("'Example.unsound' depends on axioms: [ArbitraryFalseAxiom]\n")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("unapproved axiom", result.stderr)

    def test_compiler_trust_axiom_is_rejected(self):
        result = self.manifest("'Example.native' depends on axioms: [Lean.ofReduceBool]\n")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("unapproved axiom", result.stderr)

    def test_matching_dynamic_output_still_requires_allowlist(self):
        invalid = "'Example.unsound' depends on axioms: [ArbitraryFalseAxiom]\n"
        result, _ = self.dynamic_probe(invalid, invalid)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("unapproved axiom", result.stderr)

    def test_update_cannot_record_an_unapproved_axiom(self):
        original = "'Example.valid' depends on axioms: [propext]\n"
        invalid = "'Example.unsound' depends on axioms: [ArbitraryFalseAxiom]\n"
        result, after = self.dynamic_probe(invalid, original, "--update")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("unapproved axiom", result.stderr)
        self.assertEqual(after, original)

    def test_reviewed_standard_update_is_allowed(self):
        original = "'Example.valid' does not depend on any axioms\n"
        updated = "'Example.valid' depends on axioms: [propext]\n"
        result, after = self.dynamic_probe(updated, original, "--update")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(after, updated)

    def test_concurrent_probes_use_independent_temporaries(self):
        valid = "'Example.valid' depends on axioms: [propext]\n"
        results, _ = self.dynamic_probe(valid, valid, copies=8)
        for result in results:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(list((self.spec / "tmp").iterdir()), [])

    def test_tag_cannot_allow_sorry_in_core(self):
        result = self.lint("-- SORRY[EXPERIMENT]: annotation\ntheorem unsound : False := by sorry\n")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("FORBIDDEN SORRY", result.stdout)

    def test_tag_cannot_allow_admit_in_proofs(self):
        result = self.lint("-- SORRY[EXPERIMENT]: annotation\ntheorem unsound : False := by admit\n", "proofs")
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("FORBIDDEN ADMIT", result.stdout)

    def test_prose_and_strings_are_not_code_holes(self):
        result = self.lint(
            '/- sorry /- admit -/ sorry -/\n'
            '-- SORRY[EXAMPLE]: a comment\n'
            'def words := "sorry admit"\n'
            'theorem valid : True := by trivial\n'
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
