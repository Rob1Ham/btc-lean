#!/usr/bin/env python3
"""Unpatched-vs-patched differential over the pinned Core script corpus.

Reuses the *encoder* from spec/equiv/differential/run.py (so the tape for a
vector is the same one the official differential harness uses) but replaces
the C-vs-twin comparison with a C(unpatched)-vs-C(variant) comparison.

Every case-like row of spec/data/core/script_tests.json is replayed through
each library.  Comparison is exact on `(result, error_kind)`, including error
precedence.  Exit 0 only if every variant agrees with the baseline on every
row.

Usage:
  diff_corpus.py --baseline LIB --variant name=path [--variant ...] --out DIR
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
import os as _os
SPEC = _os.path.join(_os.path.dirname(_os.path.dirname(_os.path.abspath(__file__))), "spec")
RUN_PY = os.path.join(SPEC, "equiv/differential/run.py")


def load_harness():
    spec = importlib.util.spec_from_file_location("diff_run", RUN_PY)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline", required=True)
    ap.add_argument("--variant", action="append", default=[],
                    help="name=path; repeatable")
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    os.makedirs(args.out, exist_ok=True)
    h = load_harness()
    name_to_value, value_to_name = h.load_error_names(h.ERROR_HEADER)
    data, rows, corpus_sha = h.load_corpus()
    families, selection_meta = h.load_families(data, rows)

    libs = {}
    baseline = h.CLeg(args.baseline)
    libs["baseline"] = baseline
    for spec in args.variant:
        name, path = spec.split("=", 1)
        libs[name] = h.CLeg(path)

    # Build every tape once; the encoder is shared with the official harness.
    tapes = {}
    encode_failures = []
    for ordinal, (source_index, entry) in enumerate(rows):
        row_id = f"sc-{ordinal:04d}"
        try:
            script_sig, spk, flags, expected, witness, amount, raw = h.decode_vector(entry)
            tape = h.build_tape(spk, script_sig, witness, amount)
        except Exception as exc:  # noqa: BLE001
            encode_failures.append((row_id, f"{type(exc).__name__}: {exc}"))
            continue
        tapes[row_id] = (source_index, entry, tape, spk, amount, flags, expected)

    results = {name: {} for name in libs}
    call_failures = []
    for row_id, (source_index, entry, tape, spk, amount, flags, expected) in tapes.items():
        for name, leg in libs.items():
            try:
                result, kind = leg.call(tape, spk, amount, flags)
                results[name][row_id] = (result, kind)
            except Exception as exc:  # noqa: BLE001
                call_failures.append((row_id, name, f"{type(exc).__name__}: {exc}"))

    divergences = []
    per_variant = {}
    base = results["baseline"]
    for name in libs:
        if name == "baseline":
            continue
        n_eq = n_div = n_missing = 0
        fam_div = {}
        for row_id, b in base.items():
            v = results[name].get(row_id)
            if v is None:
                n_missing += 1
                continue
            if v == b:
                n_eq += 1
            else:
                n_div += 1
                source_index, entry, tape, spk, amount, flags, expected = tapes[row_id]
                fams = families.get(source_index, ())
                if fams:
                    for f in fams:
                        fam_div[f] = fam_div.get(f, 0) + 1
                else:
                    fam_div["unassigned"] = fam_div.get("unassigned", 0) + 1
                divergences.append({
                    "variant": name,
                    "row_id": row_id,
                    "families": list(fams) if fams else ["unassigned"],
                    "expected": expected,
                    "baseline": {
                        "result": b[0],
                        "kind": b[1],
                        "name": value_to_name.get(b[1], f"UNKNOWN_{b[1]}"),
                    },
                    "variant_result": {
                        "result": v[0],
                        "kind": v[1],
                        "name": value_to_name.get(v[1], f"UNKNOWN_{v[1]}"),
                    },
                    "flags": flags,
                    "amount": amount,
                })
        per_variant[name] = {
            "rows_compared": n_eq + n_div,
            "equal": n_eq,
            "divergent": n_div,
            "missing": n_missing,
            "divergences_by_family": dict(sorted(fam_div.items())),
            "lib_sha256": sha256_file(libs[name].path),
            "lib_path": os.path.abspath(libs[name].path),
        }

    summary = {
        "corpus": {
            "path": h.CORPUS,
            "sha256": corpus_sha,
            "case_like_rows": len(rows),
            "encoded_rows": len(tapes),
            "selections": selection_meta,
        },
        "compiler": "clang++-20.1.2",
        "baseline_lib": {
            "path": os.path.abspath(args.baseline),
            "sha256": sha256_file(args.baseline),
        },
        "variants": per_variant,
        "encode_failures": encode_failures,
        "call_failures": call_failures,
        "divergences": divergences,
        "result": "zero-divergence" if not divergences and not encode_failures
                  and not call_failures else "DIVERGENCE",
    }
    with open(os.path.join(args.out, "summary.json"), "w", encoding="utf-8") as fh:
        json.dump(summary, fh, indent=2, sort_keys=True)
        fh.write("\n")
    with open(os.path.join(args.out, "divergences.jsonl"), "w", encoding="utf-8") as fh:
        for rec in divergences:
            fh.write(json.dumps(rec, sort_keys=True) + "\n")
    # Compact row-by-row replay for the final all-patches variant, if present.
    final = "pdevirt" if "pdevirt" in libs else None
    with open(os.path.join(args.out, "rows.jsonl"), "w", encoding="utf-8") as fh:
        for row_id, (source_index, entry, tape, spk, amount, flags, expected) in tapes.items():
            fams = families.get(source_index, ())
            rec = {
                "row_id": row_id,
                "families": list(fams) if fams else ["unassigned"],
                "expected": expected,
                "flags": flags,
                "amount": amount,
                "tape_sha256": hashlib.sha256(tape).hexdigest(),
                "baseline": list(base[row_id]),
            }
            for name in libs:
                if name not in ("baseline", final):
                    continue
                v = results[name].get(row_id)
                if v is not None:
                    rec[name] = list(v)
            fh.write(json.dumps(rec, sort_keys=True) + "\n")

    print(json.dumps({k: v for k, v in summary.items()
                      if k in ("result", "variants", "corpus")},
                     indent=2, sort_keys=True))
    return 0 if summary["result"] == "zero-divergence" else 1


if __name__ == "__main__":
    sys.exit(main())
