#!/usr/bin/env python3
"""Reproduce the 2026-10-18 review observations without editing project sources.

Run with a Python environment containing PyYAML. All synthetic inputs and
download transport fixtures live in a temporary directory. No network is used.
Results describe observed behavior; a false result after repairs is expected.
"""
from __future__ import annotations

import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile

REPO = Path(__file__).resolve().parents[3]


def run(argv: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(argv, text=True, capture_output=True, check=False, **kwargs)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> None:
    results = {}
    with tempfile.TemporaryDirectory(prefix="btc-lean-review-") as tmp:
        root = Path(tmp)
        spec = root / "spec"
        for part in ("scripts", "db", "core", "proofs"):
            (spec / part).mkdir(parents=True, exist_ok=True)

        for name in ("axiom_manifest.sh", "rule_crosscheck.py", "sorry_lint.py"):
            shutil.copyfile(REPO / "spec/scripts" / name, spec / "scripts" / name)

        (spec / "db/axiom-manifest.txt").write_text(
            "'Test.unsound' depends on axioms: [ArbitraryFalseAxiom]\n"
        )
        proc = run(["bash", str(spec / "scripts/axiom_manifest.sh"), "--check-static"])
        results["R09_unapproved_axiom_accepted"] = {
            "observed": proc.returncode == 0,
            "exit_code": proc.returncode,
            "output": proc.stdout + proc.stderr,
        }

        (spec / "db/rules.yaml").write_text(
            "rules:\n- id: SCR-001\n  status: proven\n  lean_target: Does.Not.Exist\n"
        )
        (spec / "core/CommentOnly.lean").write_text('/- @[rule "SCR-001"] -/\n')
        proc = run([sys.executable, str(spec / "scripts/rule_crosscheck.py")])
        results["R11_comment_only_tag_and_missing_target_accepted"] = {
            "observed": proc.returncode == 0,
            "exit_code": proc.returncode,
            "output": proc.stdout + proc.stderr,
        }

        (spec / "core/Tagged.lean").write_text(
            "-- SORRY[REVIEW]: isolated fixture\ntheorem unsound : False := by sorry\n"
        )
        proc = run([sys.executable, str(spec / "scripts/sorry_lint.py")])
        results["R10_tagged_sorry_accepted"] = {
            "observed": proc.returncode == 0,
            "exit_code": proc.returncode,
            "output": proc.stdout + proc.stderr,
        }

        remote = root / "remote"
        remote.mkdir()
        archive = "btc-lean-data-2026.10.17.tar.gz"
        with tarfile.open(remote / archive, "w:gz") as bundle:
            for name, data in (
                ("spec/data/fixture.txt", b"listed\n"),
                ("extra-unverified.txt", b"unlisted\n"),
            ):
                member = tarfile.TarInfo(name)
                member.size = len(data)
                bundle.addfile(member, io.BytesIO(data))
            fifo = tarfile.TarInfo("extra-fifo")
            fifo.type = tarfile.FIFOTYPE
            bundle.addfile(fifo)
        (remote / "manifest.sha256").write_text(
            digest(b"listed\n") + "  spec/data/fixture.txt\n"
        )
        (remote / "assets.sha256").write_text(
            "".join(
                digest((remote / name).read_bytes()) + "  " + name + "\n"
                for name in (archive, "manifest.sha256")
            )
        )
        bindir = root / "bin"
        bindir.mkdir()
        mock = bindir / "curl"
        mock.write_text(
            "#!" + sys.executable + "\n"
            "import os, shutil, sys\n"
            "from pathlib import Path\n"
            "args = sys.argv[1:]\n"
            "out = args[args.index('--output') + 1]\n"
            "shutil.copyfile(Path(os.environ['BTC_REVIEW_REMOTE']) / "
            "args[-1].rsplit('/', 1)[-1], out)\n"
        )
        mock.chmod(0o755)
        env = os.environ | {
            "PATH": str(bindir) + os.pathsep + os.environ["PATH"],
            "BTC_REVIEW_REMOTE": str(remote),
        }
        extract = root / "extract"
        args = [
            "bash", str(REPO / "scripts/fetch_data.sh"),
            "--base-url", "https://example.invalid/review-fixture",
            "--assets-sha256", digest((remote / "assets.sha256").read_bytes()),
            "--dest", str(root / "downloads"), "--extract", str(extract),
        ]
        proc = run(args, env=env)
        extra_file = (extract / "extra-unverified.txt").is_file()
        extra_fifo = (extract / "extra-fifo").is_fifo()
        results["R12_unlisted_member_and_fifo_accepted"] = {
            "observed": proc.returncode == 0 and extra_file and extra_fifo,
            "exit_code": proc.returncode,
            "unlisted_file_extracted": extra_file,
            "fifo_extracted": extra_fifo,
            "output": proc.stdout + proc.stderr,
        }
        existing = extract / "spec/data/fixture.txt"
        if existing.exists():
            existing.write_text("newer checkout data\n")
            proc = run(args, env=env)
            results["R13_existing_newer_payload_conflict"] = {
                "observed": proc.returncode != 0,
                "exit_code": proc.returncode,
                "output": proc.stdout + proc.stderr,
            }

    metadata = []
    for line in (REPO / "release/manifest.sha256").read_text().splitlines():
        expected, name = line.split("  ", 1)
        if name.startswith("spec/db/"):
            metadata.append({
                "path": name,
                "matches_current_checkout": digest((REPO / name).read_bytes()) == expected,
            })
    results["R13_release_metadata"] = metadata

    hashes = []
    for line in (REPO / "spec/db/interface-hashes.txt").read_text().splitlines():
        expected, name = line.split("  ", 1)
        path = REPO / "spec" / name
        hashes.append({
            "path": "spec/" + name,
            "matches": path.exists() and digest(path.read_bytes()) == expected,
        })
    results["R16_interface_hashes"] = hashes
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
