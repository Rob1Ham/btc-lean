#!/usr/bin/env python3
"""Join the C and Lean witness tables; emit results/comparison.md."""
import csv
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
RES = ROOT / "results"


def load(name):
    text = (RES / name).read_text().splitlines()
    start = next(i for i, line in enumerate(text) if line.startswith("label,"))
    rows = csv.DictReader(text[start:])
    return {r["label"]: r for r in rows if r.get("label")}


def main():
    c = load("c_table.txt")
    lean = load("lean_table.txt")
    assert set(c) == set(lean), (set(c) ^ set(lean))
    lines = [
        "| label | len | header | Core Set/IsValid | Lean isValidPubKey | Lean validPubKeySize | agree? |",
        "|---|---:|---|---|---|---|---|",
    ]
    mismatches = 0
    for label, cr in c.items():
        lr = lean[label]
        agree = cr["core_IsValid"] == lr["lean_isValidPubKey"]
        mismatches += 0 if agree else 1
        hdr = cr["hex"][:2] if cr["len"] != "0" else "(none)"
        lines.append(
            f"| {label} | {cr['len']} | {hdr} | {cr['core_IsValid']} | "
            f"{lr['lean_isValidPubKey']} | {lr['lean_validPubKeySize']} | "
            f"{'yes' if agree else '**NO**'} |"
        )
    lines.append("")
    lines.append(f"Rows: {len(c)}; gate-definition mismatches: {mismatches}.")
    out = "\n".join(lines) + "\n"
    (RES / "comparison.md").write_text(out)
    print(out, end="")


if __name__ == "__main__":
    main()
