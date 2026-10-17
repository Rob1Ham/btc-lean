"""Emit and replay the malformed/edge-case PSBT corpus.

``--emit`` starts a disposable regtest bitcoind, submits every candidate from
``psbt_build.py`` to ``decodepsbt``, and writes Core's verdict verbatim to
``spec/data/wallet/psbt_errors.jsonl``.  ``--replay`` performs the same RPC
calls against a fresh node and compares the recorded verdict and a stable
field projection.

The corpus is about PSBT decoding only.  It makes no statement about whether a
transaction is consensus-valid, whether a signature is cryptographically
valid, or whether the wallet would sign the PSBT.  A successful decode means
Core's parser accepted the byte string and produced the projected fields.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import tempfile
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
SPEC_ROOT = HERE.parents[1]
DEFAULT_CORPUS = SPEC_ROOT / "data" / "wallet" / "psbt_errors.jsonl"
DEFAULT_MANIFEST = SPEC_ROOT / "data" / "wallet" / "psbt_errors.manifest.json"
DEFAULT_BITCOIND = "build/scratch/core-build/build/bin/bitcoind"

sys.path.insert(0, str(HERE))
from bitcoind import Bitcoind, RPCError  # noqa: E402
from psbt_build import build_cases  # noqa: E402


# ----------------------------------------------------------------- projection

def _script_hex(value: Any) -> Any:
    if isinstance(value, dict):
        return value.get("hex")
    return value


def _project_input(entry: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    if "witness_utxo" in entry:
        utxo = entry["witness_utxo"]
        out["witness_utxo"] = {
            "amount": utxo.get("amount"),
            "script_pubkey": _script_hex(utxo.get("scriptPubKey")),
        }
    if "non_witness_utxo" in entry:
        prev = entry["non_witness_utxo"]
        out["non_witness_utxo"] = {
            "txid": prev.get("txid"),
            "vsize": prev.get("vsize"),
            "vout_count": len(prev.get("vout", [])),
        }
    for key, target in (
        ("partial_signatures", "partial_signatures"),
        ("sighash", "sighash"),
        ("bip32_derivs", "bip32_derivs"),
        ("final_scriptwitness", "final_scriptwitness"),
        ("taproot_key_path_sig", "taproot_key_path_sig"),
        ("taproot_script_path_sigs", "taproot_script_path_sigs"),
        ("taproot_scripts", "taproot_scripts"),
        ("taproot_bip32_derivs", "taproot_bip32_derivs"),
        ("taproot_internal_key", "taproot_internal_key"),
        ("taproot_merkle_root", "taproot_merkle_root"),
        ("unknown", "unknown"),
        ("proprietary", "proprietary"),
    ):
        if key in entry:
            out[target] = entry[key]
    for key in ("redeem_script", "witness_script"):
        if key in entry:
            out[key] = _script_hex(entry[key])
    if "final_scriptSig" in entry:
        out["final_script_sig"] = _script_hex(entry["final_scriptSig"])
    return out


def _project_output(entry: dict[str, Any]) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for key in ("redeem_script", "witness_script"):
        if key in entry:
            out[key] = _script_hex(entry[key])
    for key in ("bip32_derivs", "unknown", "proprietary"):
        if key in entry:
            out[key] = entry[key]
    return out


def project_decoded(result: dict[str, Any]) -> dict[str, Any]:
    """Project ``decodepsbt`` to the fields a Lean-side verifier can check.

    Values are copied from Core; only volatile or irrelevant shape is dropped
    (for example the full previous transaction inside ``non_witness_utxo``).
    """
    projected: dict[str, Any] = {"psbt_version": result.get("psbt_version")}
    if "tx" in result:
        tx = result["tx"]
        projected["tx"] = {
            "txid": tx.get("txid"),
            "vsize": tx.get("vsize"),
            "vin": [
                {"txid": vin.get("txid"), "vout": vin.get("vout")}
                for vin in tx.get("vin", [])
            ],
            "vout": [
                {
                    "value": vout.get("value"),
                    "script_pubkey": _script_hex(vout.get("scriptPubKey")),
                }
                for vout in tx.get("vout", [])
            ],
        }
    projected["global_xpubs"] = len(result.get("global_xpubs", []))
    projected["unknown"] = result.get("unknown", {})
    projected["proprietary"] = [
        {key: item.get(key) for key in ("identifier", "subtype", "key", "value")}
        for item in result.get("proprietary", [])
    ]
    projected["inputs"] = [_project_input(item) for item in result.get("inputs", [])]
    projected["outputs"] = [_project_output(item) for item in result.get("outputs", [])]
    if "fee" in result:
        projected["fee"] = result["fee"]
    return projected


# --------------------------------------------------------------------- verdicts

def observe(node: Bitcoind, psbt_b64: str) -> dict[str, Any]:
    """Return ``{ok, error, code, fields}`` for one ``decodepsbt`` call."""
    try:
        result = node.rpc("decodepsbt", psbt_b64)
    except RPCError as exc:
        return {"ok": False, "error": exc.message, "code": exc.code, "fields": {}}
    return {"ok": True, "error": None, "code": None, "fields": project_decoded(result)}


def _load_corpus(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, 1):
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError as exc:
                raise SystemExit(f"{path}:{line_number}: invalid JSON: {exc}") from exc
    return rows


# ------------------------------------------------------------------------- emit

def emit(corpus: Path, manifest: Path, binary: str, keep: bool) -> int:
    cases = build_cases()
    seen: set[str] = set()
    for item in cases:
        if item.case_id in seen:
            raise SystemExit(f"duplicate case id: {item.case_id}")
        seen.add(item.case_id)

    node = Bitcoind(binary=binary, extra_args=["-disablewallet=1"])
    rows: list[dict[str, Any]] = []
    try:
        node.start()
        version = node.rpc("getnetworkinfo").get("subversion", "unknown")
        for item in cases:
            verdict = observe(node, item.as_b64())
            rows.append(
                {
                    "case_id": item.case_id,
                    "psbt_b64": item.as_b64(),
                    "expected_ok": verdict["ok"],
                    "expected_error": verdict["error"],
                    "expected_error_code": verdict["code"],
                    "expected_fields_subset": verdict["fields"],
                    "taxonomy": item.taxonomy,
                    "note": item.note,
                }
            )
    finally:
        node.cleanup(keep=keep)

    corpus.parent.mkdir(parents=True, exist_ok=True)
    payload = "".join(
        json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n" for row in rows
    )
    corpus.write_text(payload, encoding="utf-8")

    ok_count = sum(1 for row in rows if row["expected_ok"])
    manifest_data = {
        "format": "wallet-psbt-errors-jsonl-v1",
        "generator": "spec/runners/wallet_diff/psbt_replay.py --emit",
        "case_count": len(rows),
        "valid_case_count": ok_count,
        "error_case_count": len(rows) - ok_count,
        "sha256_corpus": hashlib.sha256(payload.encode("utf-8")).hexdigest(),
        "bitcoind_subversion": version,
    }
    manifest.write_text(json.dumps(manifest_data, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    print(f"wrote {len(rows)} cases to {corpus}")
    print(f"  accepted by decodepsbt: {ok_count}")
    print(f"  rejected by decodepsbt: {len(rows) - ok_count}")
    print(f"  sha256: {manifest_data['sha256_corpus']}")
    return 0


# ----------------------------------------------------------------------- replay

def replay(
    corpus: Path,
    binary: str,
    only: str | None,
    keep: bool,
    show_all: bool,
    failures_out: Path | None,
) -> int:
    rows = _load_corpus(corpus)
    if only:
        rows = [row for row in rows if row["case_id"].startswith(only)]
    if not rows:
        raise SystemExit(f"no cases selected from {corpus}")

    node = Bitcoind(binary=binary, extra_args=["-disablewallet=1"])
    failures: list[dict[str, Any]] = []
    try:
        node.start()
        for row in rows:
            actual = observe(node, row["psbt_b64"])
            failure: str | None = None
            if actual["ok"] != row["expected_ok"]:
                expectation = "success" if row["expected_ok"] else "error"
                failure = f"expected {expectation}, observed {'success' if actual['ok'] else 'error'}"
                if actual["error"] is not None:
                    failure += f": {actual['error']}"
            elif row["expected_ok"]:
                if actual["fields"] != row["expected_fields_subset"]:
                    failure = "decoded field projection differs from the corpus"
            else:
                if actual["error"] != row["expected_error"]:
                    failure = (
                        f"error text differs: expected {row['expected_error']!r}, "
                        f"observed {actual['error']!r}"
                    )
                elif (
                    row.get("expected_error_code") is not None
                    and actual["code"] != row["expected_error_code"]
                ):
                    failure = (
                        f"error code differs: expected {row['expected_error_code']}, "
                        f"observed {actual['code']}"
                    )
            if failure:
                failures.append(
                    {
                        "case_id": row["case_id"],
                        "expected_ok": row["expected_ok"],
                        "observed_ok": actual["ok"],
                        "expected_error": row["expected_error"],
                        "observed_error": actual["error"],
                        "reason": failure,
                    }
                )
                if show_all:
                    print(f"FAIL {row['case_id']}: {failure}")
    finally:
        node.cleanup(keep=keep)

    if failures_out is not None:
        failures_out.write_text(
            json.dumps(failures, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )

    passed = len(rows) - len(failures)
    rate = 100.0 * passed / len(rows)
    print(f"PSBT replay: {passed}/{len(rows)} passed ({rate:.2f}%)")
    if failures:
        print(f"  failures: {len(failures)}")
        if not show_all:
            for item in failures[:10]:
                print(f"  FAIL {item['case_id']}: {item['reason']}")
            if len(failures) > 10:
                print(f"  ... {len(failures) - 10} more (use --show-all)")
    else:
        print("  every recorded decode verdict and field projection matched")
    return 0 if not failures else 1


# -------------------------------------------------------------------------- CLI

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--emit", action="store_true", help="regenerate the corpus from a live node")
    mode.add_argument("--replay", action="store_true", help="replay the corpus (default)")
    parser.add_argument("--corpus", type=Path, default=DEFAULT_CORPUS)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--bitcoind", default=DEFAULT_BITCOIND)
    parser.add_argument("--only", default=None, help="replay only case ids with this prefix")
    parser.add_argument("--keep", action="store_true", help="keep the temporary datadir")
    parser.add_argument("--show-all", action="store_true", help="print every failure")
    parser.add_argument("--failures-out", type=Path, default=None)
    args = parser.parse_args(argv)

    if args.emit:
        return emit(args.corpus, args.manifest, args.bitcoind, args.keep)
    return replay(args.corpus, args.bitcoind, args.only, args.keep, args.show_all, args.failures_out)


if __name__ == "__main__":
    raise SystemExit(main())
