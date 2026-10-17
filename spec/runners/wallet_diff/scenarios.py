"""Deterministic regtest scenarios for the wallet differential corpus.

Each public scenario function returns a list of case dictionaries.  A case is
one of:

``rpc``
    A JSON-RPC call, its exact parameters, and Core's observed result or error.
``check``
    A Python-side assertion over observed values.  ``expect`` is always true;
    the ``inputs`` field carries the compared values so a reader can audit the
    check without running the harness.

The scenarios intentionally use one fixed test mnemonic/key, one fixed mock
time, explicit funding inputs, a fixed change address and change position, and
PSBT v0.  Those choices remove the nondeterminism that wallet keypool,
coin-selection, and wall-clock time would otherwise introduce.

Not modeled: wallet database durability, encryption, hardware wallets, PSBT v2
semantics, mempool policy beyond the single ``testmempoolaccept`` call, and any
claim that a descriptor is safe to use.
"""

from __future__ import annotations

from typing import Any, Callable, Iterable

from bitcoind import Bitcoind, RPCError

# A disposable BIP32 test key.  It is never funded on a public network and is
# included only so imports and signing are reproducible.  Do not reuse it.
TPRV = (
    "tprv8ZgxMBicQKsPdpfm4xf4ETfw1HwXrm6Cxw4FRDEk16Xxcb3KQe4EAXaPiVGhoFnNTkp"
    "EV1LPt5RoRAha2xa8aCDkb9JvBccXyMteNwM4nQz"
)

FIXED_PUBKEY = "0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
FIXED_PUBKEY_2 = "02c6047f9441ed7d6d3045406e95c07cd85c778e4b8cef3ca7abac09b95c709ee5"
FIXED_PUBKEY_UNCOMPRESSED = (
    "0479be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"
    "483ada7726a3c4655da4fbfc0e1108a8fd17b448a68554199c47d08ffb10d4b8"
)
FIXED_XONLY = "79be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798"

WALLET = "wallet_diff"
WATCH_WALLET = "wallet_diff_watch"
MOCKTIME = 1_600_000_000
MINING_BLOCKS = 101

PRIV_DESCRIPTORS = {
    "wpkh": f"wpkh({TPRV}/84h/1h/0h/0/*)",
    "shwpkh": f"sh(wpkh({TPRV}/49h/1h/0h/0/*))",
    "pkh": f"pkh({TPRV}/44h/1h/0h/0/*)",
    "tr": f"tr({TPRV}/86h/1h/0h/0/*)",
}


# --------------------------------------------------------------------------
# Case construction helpers
# --------------------------------------------------------------------------


def rpc_case(
    rec: list[dict[str, Any]],
    node: Bitcoind,
    cid: str,
    method: str,
    params: Iterable[Any] = (),
    *,
    wallet: str | None = None,
    note: str = "",
    project: Callable[[Any], Any] | None = None,
) -> tuple[Any, RPCError | None]:
    """Execute one RPC, append the observed result/error, and return it.

    The case records the method, exact positional parameters, optional wallet
    endpoint, and either ``expect.result`` or ``expect.error``.  ``project``
    narrows a large result to the fields the corpus treats as stable.
    """
    params = list(params)
    try:
        result = node.rpc(method, *params, wallet=wallet)
    except RPCError as exc:
        case: dict[str, Any] = {
            "id": cid,
            "kind": "rpc",
            "method": method,
            "params": params,
            "expect": {"error": exc.as_dict()},
        }
        if wallet is not None:
            case["wallet"] = wallet
        if note:
            case["note"] = note
        rec.append(case)
        return None, exc
    expected = project(result) if project is not None else result
    case = {
        "id": cid,
        "kind": "rpc",
        "method": method,
        "params": params,
        "expect": {"result": expected},
    }
    if wallet is not None:
        case["wallet"] = wallet
    if note:
        case["note"] = note
    rec.append(case)
    return result, None


def observed_case(
    rec: list[dict[str, Any]],
    cid: str,
    method: str,
    params: Iterable[Any],
    *,
    result: Any = None,
    error: RPCError | None = None,
    wallet: str | None = None,
    note: str = "",
    project: Callable[[Any], Any] | None = None,
) -> None:
    """Record an RPC observation that was made earlier during preparation."""
    params = list(params)
    if error is not None:
        expect: dict[str, Any] = {"error": error.as_dict()}
    else:
        expect = {"result": project(result) if project is not None else result}
    case: dict[str, Any] = {
        "id": cid,
        "kind": "rpc",
        "method": method,
        "params": params,
        "expect": expect,
    }
    if wallet is not None:
        case["wallet"] = wallet
    if note:
        case["note"] = note
    rec.append(case)


def check_case(
    rec: list[dict[str, Any]],
    cid: str,
    check: str,
    inputs: dict[str, Any],
    *,
    condition: bool,
    note: str = "",
) -> None:
    """Append a deterministic assertion, failing loudly if it is false.

    The corpus only records checks that were evaluated while the case was
    generated.  ``expect`` is therefore always true; a false condition aborts
    emission instead of silently writing an unverified assertion.
    """
    if not condition:
        raise AssertionError(f"check failed during generation: {cid}: {check}: {inputs!r}")
    case = {
        "id": cid,
        "kind": "check",
        "check": check,
        "inputs": inputs,
        "expect": True,
    }
    if note:
        case["note"] = note
    rec.append(case)


def _checked(node: Bitcoind, descriptor: str) -> str:
    """Return ``descriptor`` with its input checksum appended.

    ``getdescriptorinfo`` returns the checksum of the *input* descriptor, which
    is why this helper is used for private descriptors whose public rendering
    would carry a different checksum.
    """
    checksum = node.rpc("getdescriptorinfo", descriptor)["checksum"]
    return f"{descriptor}#{checksum}"


def _derive(node: Bitcoind, descriptor: str, rng: Any = None) -> list[Any]:
    """Call ``deriveaddresses`` and return Core's address array."""
    if rng is None:
        return node.rpc("deriveaddresses", descriptor)
    return node.rpc("deriveaddresses", descriptor, rng)


def _project_network(result: dict[str, Any]) -> dict[str, Any]:
    """Keep stable network-identity fields."""
    keys = ("version", "subversion", "protocolversion", "relayfee", "incrementalfee")
    return {key: result[key] for key in keys}


def _project_chain(result: dict[str, Any]) -> dict[str, Any]:
    """Keep stable chain-state fields (mock time makes block hashes fixed)."""
    keys = ("chain", "blocks", "headers", "bestblockhash", "difficulty", "mediantime", "chainwork")
    return {key: result[key] for key in keys}


def _project_wallet(result: dict[str, Any]) -> dict[str, Any]:
    """Keep wallet fields that do not depend on wall-clock time."""
    keys = (
        "walletname",
        "walletversion",
        "format",
        "txcount",
        "private_keys_enabled",
        "descriptors",
        "blank",
        "keypoolsize",
        "keypoolsize_hd_internal",
    )
    return {key: result[key] for key in keys}


def _project_psbt(result: dict[str, Any]) -> dict[str, Any]:
    """Keep PSBT structure and value fields used by the checks."""
    tx = result["tx"]
    first_input = result["inputs"][0]
    return {
        "psbt_version": result.get("psbt_version"),
        "fee": result.get("fee"),
        "txid": tx["txid"],
        "vsize": tx["vsize"],
        "vin": len(tx["vin"]),
        "vout": [
            {
                "value": out["value"],
                "type": out["scriptPubKey"]["type"],
                "address": out["scriptPubKey"].get("address"),
            }
            for out in tx["vout"]
        ],
        "input_count": len(result["inputs"]),
        "input0_utxo_amount": first_input.get("witness_utxo", {}).get("amount"),
        "input0_partial_sigs": len(first_input.get("partial_signatures", {})),
    }


def _project_analyze(result: dict[str, Any]) -> dict[str, Any]:
    """Keep analyze-psbt estimates and per-input progress."""
    return {
        "inputs": [
            {
                "has_utxo": item.get("has_utxo"),
                "is_final": item.get("is_final"),
                "next": item.get("next"),
            }
            for item in result.get("inputs", [])
        ],
        "estimated_vsize": result.get("estimated_vsize"),
        "estimated_feerate": result.get("estimated_feerate"),
        "fee": result.get("fee"),
        "next": result.get("next"),
    }


def _project_rawtx(result: dict[str, Any]) -> dict[str, Any]:
    """Keep transaction identity, size, and output scripts."""
    return {
        "txid": result["txid"],
        "hash": result["hash"],
        "size": result["size"],
        "vsize": result["vsize"],
        "weight": result["weight"],
        "version": result["version"],
        "locktime": result["locktime"],
        "vin": len(result["vin"]),
        "vout": [
            {
                "value": out["value"],
                "type": out["scriptPubKey"]["type"],
                "address": out["scriptPubKey"].get("address"),
            }
            for out in result["vout"]
        ],
    }


# --------------------------------------------------------------------------
# Preparation (not every preparatory call is a corpus case)
# --------------------------------------------------------------------------


def prepare(node: Bitcoind) -> dict[str, Any]:
    """Create the deterministic chain and descriptor wallet used by scenarios.

    The sequence is fixed: mock time, mine to the wpkh index-0 address, create
    a blank descriptor wallet, import four active ranged descriptors with
    timestamp 0 (full rescan), then select the first mature coinbase output.
    """
    node.rpc("setmocktime", MOCKTIME)

    checksums = {name: node.rpc("getdescriptorinfo", desc)["checksum"] for name, desc in PRIV_DESCRIPTORS.items()}
    private = {name: f"{desc}#{checksums[name]}" for name, desc in PRIV_DESCRIPTORS.items()}

    mining_address = _derive(node, private["wpkh"], [0, 0])[0]
    node.rpc("generatetoaddress", MINING_BLOCKS, mining_address)

    node.rpc("createwallet", WALLET, False, True, "", False, True)
    import_requests = [
        {
            "desc": private[name],
            "timestamp": 0,
            "active": True,
            "range": [0, 10],
        }
        for name in ("wpkh", "shwpkh", "pkh", "tr")
    ]
    import_result = node.rpc("importdescriptors", import_requests, wallet=WALLET)

    public_list = node.rpc("listdescriptors", False, wallet=WALLET)

    def find_desc(prefix: str, marker: str) -> str:
        for item in public_list["descriptors"]:
            if item["desc"].startswith(prefix) and marker in item["desc"] and not item["internal"]:
                return item["desc"]
        raise RuntimeError(f"descriptor not found: {prefix} {marker}")

    public = {
        "wpkh": find_desc("wpkh(", "/84h/1h/0h]"),
        "shwpkh": find_desc("sh(wpkh(", "/49h/1h/0h]"),
        "pkh": find_desc("pkh(", "/44h/1h/0h]"),
        "tr": find_desc("tr(", "/86h/1h/0h]"),
    }

    addresses = {
        "p2wpkh": _derive(node, public["wpkh"], [0, 0])[0],
        "p2sh-p2wpkh": _derive(node, public["shwpkh"], [0, 0])[0],
        "p2pkh": _derive(node, public["pkh"], [0, 0])[0],
        "p2tr": _derive(node, public["tr"], [0, 0])[0],
    }
    change_address = _derive(node, public["wpkh"], [5, 5])[0]

    fixed = {
        "p2wsh": _checked(node, f"wsh(sortedmulti(2,{FIXED_PUBKEY},{FIXED_PUBKEY_2}))"),
        "p2sh-multisig": _checked(node, f"sh(multi(2,{FIXED_PUBKEY},{FIXED_PUBKEY_2}))"),
    }
    addresses["p2wsh"] = _derive(node, fixed["p2wsh"])[0]
    addresses["p2sh-multisig"] = _derive(node, fixed["p2sh-multisig"])[0]

    unspent = node.rpc("listunspent", 100, 9_999_999, wallet=WALLET)
    spendable = [item for item in unspent if item.get("spendable") and item.get("amount", 0.0) >= 1.0]
    if not spendable:
        raise RuntimeError("preparation produced no mature spendable output")
    utxo = sorted(spendable, key=lambda item: (item["txid"], item["vout"]))[0]
    utxo_sats = int(round(utxo["amount"] * 100_000_000))

    return {
        "private": private,
        "public": public,
        "addresses": addresses,
        "change_address": change_address,
        "utxo": utxo,
        "utxo_sats": utxo_sats,
        "import_result": import_result,
        "import_requests": import_requests,
        "public_list": public_list,
        "fixed": fixed,
        "mining_address": mining_address,
    }


# --------------------------------------------------------------------------
# Scenarios
# --------------------------------------------------------------------------


def scenario_context(rec: list[dict[str, Any]], node: Bitcoind, setup: dict[str, Any]) -> None:
    """Record the pinned daemon identity, chain tip, and wallet shape."""
    rpc_case(
        rec,
        node,
        "context.network",
        "getnetworkinfo",
        project=_project_network,
        note="Version string and relay-fee constants of the pinned binary.",
    )
    rpc_case(
        rec,
        node,
        "context.chain",
        "getblockchaininfo",
        project=_project_chain,
        note="Mock time 1600000000 makes the regtest tip reproducible.",
    )
    rpc_case(
        rec,
        node,
        "context.wallet",
        "getwalletinfo",
        wallet=WALLET,
        project=_project_wallet,
        note="Blank descriptor wallet after four active imports; no keys were generated by the wallet.",
    )


def scenario_descriptors(rec: list[dict[str, Any]], node: Bitcoind, setup: dict[str, Any]) -> None:
    """Exercise descriptor checksum parsing, redaction, expansion, and derivation."""
    pub = setup["public"]
    priv = setup["private"]
    addresses = setup["addresses"]

    checksummed_wpkh = _checked(node, f"wpkh({FIXED_PUBKEY})")
    checksummed_pkh = _checked(node, f"pkh({FIXED_PUBKEY})")
    checksummed_tr = _checked(node, f"tr({FIXED_PUBKEY})")
    checksummed_wsh = _checked(node, f"wsh(multi(2,{FIXED_PUBKEY},{FIXED_PUBKEY_2}))")
    checksummed_sh = _checked(node, f"sh(multi(2,{FIXED_PUBKEY},{FIXED_PUBKEY_2}))")
    checksummed_shwsh = _checked(node, f"sh(wsh(pk({FIXED_PUBKEY})))")
    checksummed_tr_script = _checked(node, f"tr({FIXED_PUBKEY},pk({FIXED_PUBKEY_2}))")
    checksummed_tr_multi = _checked(node, f"tr({FIXED_PUBKEY},multi_a(2,{FIXED_PUBKEY},{FIXED_PUBKEY_2}))")
    checksummed_multipath = _checked(node, f"wpkh({TPRV}/84h/1h/0h/<0;1>/*)")
    checksummed_raw = _checked(node, "raw(76a914751e76e8199196d454941c45d1b3a323f1433bd688ac)")

    info_cases: list[tuple[str, str, str]] = [
        ("desc.info.pkh", f"pkh({FIXED_PUBKEY})", "Pay-to-pubkey-hash with a fixed key."),
        ("desc.info.wpkh", f"wpkh({FIXED_PUBKEY})", "Native segwit v0 key hash."),
        ("desc.info.sh_wpkh", f"sh(wpkh({FIXED_PUBKEY}))", "P2SH-wrapped segwit v0 key hash."),
        ("desc.info.wsh_multi", f"wsh(multi(2,{FIXED_PUBKEY},{FIXED_PUBKEY_2}))", "P2WSH multisig."),
        (
            "desc.info.wsh_sortedmulti",
            f"wsh(sortedmulti(2,{FIXED_PUBKEY_2},{FIXED_PUBKEY}))",
            "Sorted multisig canonicalizes key order.",
        ),
        ("desc.info.sh_multi", f"sh(multi(2,{FIXED_PUBKEY},{FIXED_PUBKEY_2}))", "P2SH multisig."),
        ("desc.info.tr_key", f"tr({FIXED_PUBKEY})", "Taproot key-path-only descriptor."),
        ("desc.info.tr_script", f"tr({FIXED_PUBKEY},pk({FIXED_PUBKEY_2}))", "Taproot with one script leaf."),
        (
            "desc.info.tr_multi_a",
            f"tr({FIXED_PUBKEY},multi_a(2,{FIXED_PUBKEY},{FIXED_PUBKEY_2}))",
            "Taproot multisig leaf.",
        ),
        ("desc.info.raw", "raw(76a914751e76e8199196d454941c45d1b3a323f1433bd688ac)", "Raw script descriptor."),
        ("desc.info.addr", f"addr({addresses['p2wpkh']})", "Address descriptor."),
        ("desc.info.combo", f"combo({FIXED_PUBKEY})", "Combo expands to several script forms."),
        ("desc.info.pkh_uncompressed", f"pkh({FIXED_PUBKEY_UNCOMPRESSED})", "P2PKH permits an uncompressed key."),
        ("desc.info.wpkh_uncompressed", f"wpkh({FIXED_PUBKEY_UNCOMPRESSED})", "Segwit v0 rejects uncompressed keys."),
        ("desc.info.private_range", PRIV_DESCRIPTORS["wpkh"], "Private ranged descriptor; output is redacted."),
        ("desc.info.public_account", pub["wpkh"], "Account-level tpub descriptor from listdescriptors."),
        ("desc.info.multipath", f"wpkh({TPRV}/84h/1h/0h/<0;1>/*)", "Two multipath expansions."),
        ("desc.info.xonly_tr", f"tr({FIXED_XONLY})", "Taproot accepts an x-only key."),
        ("desc.info.sh_wsh", f"sh(wsh(pk({FIXED_PUBKEY})))", "P2SH-wrapped witness script."),
        ("desc.info.wsh_pk", f"wsh(pk({FIXED_PUBKEY}))", "Single-key witness script."),
        ("desc.info.checksum_ok", checksummed_wpkh, "Well-formed checksum is accepted."),
        ("desc.info.wrong_checksum", f"wpkh({FIXED_PUBKEY})#deadbeef", "Checksum mismatch is rejected."),
        ("desc.info.empty_checksum", f"wpkh({FIXED_PUBKEY})#", "Empty checksum is rejected."),
        ("desc.info.empty_wpkh", "wpkh()", "Empty key expression is rejected."),
        ("desc.info.bad_key", "wpkh(notakey)", "Non-key text is rejected."),
        ("desc.info.unknown_func", f"unknownfunc({FIXED_PUBKEY})", "Unknown descriptor function is rejected."),
        ("desc.info.unbalanced", f"sh(wpkh({FIXED_PUBKEY})", "Unbalanced parentheses are rejected."),
        ("desc.info.range_fixed", f"wpkh({FIXED_PUBKEY}/0/*)", "Wildcard on a fixed key is rejected."),
        ("desc.info.raw_bad_hex", "raw(zz)", "Non-hex raw script is rejected."),
    ]
    for cid, descriptor, note in info_cases:
        rpc_case(rec, node, cid, "getdescriptorinfo", [descriptor], note=note, project=_project_descriptor_info)

    # Core documents the output descriptor as "without private keys" but keeps
    # the input checksum.  For a master tprv with hardened path components the
    # redacted result is therefore not derivable without the private key.
    redacted, err = rpc_case(
        rec,
        node,
        "desc.info.private_redaction",
        "getdescriptorinfo",
        [priv["wpkh"]],
        note="Descriptor is redacted to tpub, checksum stays that of the input.",
    )
    if redacted is not None:
        rpc_case(
            rec,
            node,
            "desc.derive.redacted_fails",
            "deriveaddresses",
            [redacted["descriptor"], [0, 0]],
            note="Hardened path on a redacted tpub cannot be derived without private keys.",
        )

    derive_cases: list[tuple[str, str, Any, str]] = [
        ("desc.derive.wpkh_r0", checksummed_wpkh, None, "Fixed-key wpkh at index 0."),
        ("desc.derive.pkh_r0", checksummed_pkh, None, "Fixed-key pkh at index 0."),
        ("desc.derive.tr_r0", checksummed_tr, None, "Fixed-key taproot at index 0."),
        ("desc.derive.wsh_multi_r0", checksummed_wsh, None, "P2WSH multisig address."),
        ("desc.derive.sh_multi_r0", checksummed_sh, None, "P2SH multisig address."),
        ("desc.derive.sh_wsh_r0", checksummed_shwsh, None, "P2SH-P2WSH address."),
        ("desc.derive.tr_script_r0", checksummed_tr_script, None, "Taproot output key with one leaf."),
        ("desc.derive.tr_multi_a_r0", checksummed_tr_multi, None, "Taproot output key with multi_a leaf."),
        ("desc.derive.raw_p2pkh", checksummed_raw, None, "Raw P2PKH script is addressable."),
        ("desc.derive.account_wpkh_0_2", pub["wpkh"], [0, 2], "Three receive addresses."),
        ("desc.derive.account_pkh_0_2", pub["pkh"], [0, 2], "Three legacy receive addresses."),
        ("desc.derive.account_shwpkh_0_2", pub["shwpkh"], [0, 2], "Three P2SH-wrapped receive addresses."),
        ("desc.derive.account_tr_0_2", pub["tr"], [0, 2], "Three taproot receive addresses."),
        ("desc.derive.private_hardened_0_2", priv["wpkh"], [0, 2], "Private master key can derive hardened paths."),
        ("desc.derive.multipath_0_1", checksummed_multipath, [0, 1], "Multipath result is nested per expansion."),
        ("desc.derive.unranged_no_range", checksummed_wpkh, None, "Un-ranged descriptor needs no range."),
        ("desc.derive.unranged_with_range", checksummed_wpkh, [0, 0], "Range on an un-ranged descriptor is rejected."),
        ("desc.derive.ranged_no_range", pub["wpkh"], None, "Ranged descriptor without range is rejected."),
        ("desc.derive.range_bad", pub["wpkh"], [5, 2], "Reversed range is rejected."),
        ("desc.derive.missing_checksum", f"wpkh({FIXED_PUBKEY})", [0, 0], "deriveaddresses requires a checksum."),
        ("desc.derive.wrong_checksum", f"wpkh({FIXED_PUBKEY})#deadbeef", [0, 0], "Wrong checksum is rejected."),
        ("desc.derive.pk_no_address", _checked(node, f"pk({FIXED_PUBKEY})"), None, "P2PK has no address in this tree."),
        ("desc.derive.raw_no_destination", _checked(node, "raw(deadbeef)"), None, "Raw script has no destination."),
    ]
    for cid, descriptor, rng, note in derive_cases:
        params = [descriptor] if rng is None else [descriptor, rng]
        rpc_case(rec, node, cid, "deriveaddresses", params, note=note)


def _project_descriptor_info(result: dict[str, Any]) -> dict[str, Any]:
    """Keep all documented getdescriptorinfo fields but drop multipath bulk."""
    out = {
        "descriptor": result["descriptor"],
        "checksum": result["checksum"],
        "isrange": result["isrange"],
        "issolvable": result["issolvable"],
        "hasprivatekeys": result["hasprivatekeys"],
    }
    if "multipath_expansion" in result:
        out["multipath_expansion"] = result["multipath_expansion"]
    return out


def _project_private_list(result: dict[str, Any]) -> dict[str, Any]:
    """Project listdescriptors(private=true) without writing private keys.

    The projection proves that every descriptor exposed a private key while
    keeping the corpus free of key material beyond the fixed test key already
    used in inputs.
    """
    descriptors = result["descriptors"]
    return {
        "wallet_name": result["wallet_name"],
        "count": len(descriptors),
        "all_have_private_key": all("tprv" in item["desc"] for item in descriptors),
        "descriptors": [
            {
                "active": item["active"],
                "internal": item["internal"],
                "range": item.get("range"),
                "next": item.get("next"),
                "next_index": item.get("next_index"),
                "has_private_key": "tprv" in item["desc"],
            }
            for item in descriptors
        ],
    }


def scenario_import(rec: list[dict[str, Any]], node: Bitcoind, setup: dict[str, Any]) -> None:
    """Exercise importdescriptors, listdescriptors, and watch-only imports."""
    observed_case(
        rec,
        "import.active_batch",
        "importdescriptors",
        [setup["import_requests"]],
        result=setup["import_result"],
        wallet=WALLET,
        note="Four active descriptors imported with timestamp 0 in one batch.",
    )
    observed_case(
        rec,
        "import.list_public",
        "listdescriptors",
        [False],
        result=setup["public_list"],
        wallet=WALLET,
        note="Public rendering of the four imported descriptors.",
    )
    rpc_case(
        rec,
        node,
        "import.list_private_projection",
        "listdescriptors",
        [True],
        wallet=WALLET,
        project=_project_private_list,
        note="Private listing projected to presence/range metadata.",
    )

    # A second wallet proves the watch-only path and duplicate-import behavior.
    node.rpc("createwallet", WATCH_WALLET, True, True, "", False, True)
    watch_request = {
        "desc": setup["public"]["wpkh"],
        "timestamp": 0,
        "active": True,
        "range": [0, 10],
    }
    rpc_case(
        rec,
        node,
        "import.watch_only",
        "importdescriptors",
        [[watch_request]],
        wallet=WATCH_WALLET,
        note="Public wpkh descriptor imported into a private-keys-disabled wallet.",
    )
    rpc_case(
        rec,
        node,
        "import.watch_duplicate",
        "importdescriptors",
        [[watch_request]],
        wallet=WATCH_WALLET,
        note="Re-importing the same descriptor reports an already-present warning.",
    )
    rpc_case(
        rec,
        node,
        "import.watch_list",
        "listdescriptors",
        [False],
        wallet=WATCH_WALLET,
        note="Watch-only wallet descriptor list.",
    )
    rpc_case(
        rec,
        node,
        "import.watch_address",
        "getaddressinfo",
        [setup["addresses"]["p2wpkh"]],
        wallet=WATCH_WALLET,
        note="The mined address is watch-only in the second wallet.",
    )
    rpc_case(
        rec,
        node,
        "import.invalid",
        "importdescriptors",
        [[{"desc": "wpkh(notakey)", "timestamp": 0}]],
        wallet=WATCH_WALLET,
        note="A bare descriptor is reported per request, not as a top-level RPC error.",
    )
    rpc_case(
        rec,
        node,
        "import.checksumless_rejected",
        "importdescriptors",
        [[{"desc": setup["public"]["pkh"].split("#")[0], "timestamp": 0}]],
        wallet=WATCH_WALLET,
        note="importdescriptors requires a checksum; a bare descriptor is rejected per request.",
    )


# label, setup key, script prefix, script length in bytes, witness version
ADDRESS_TYPES: list[tuple[str, str, str, int, int | None]] = [
    ("p2pkh", "p2pkh", "76a914", 25, None),
    ("p2sh-p2wpkh", "p2sh-p2wpkh", "a914", 23, None),
    ("p2wpkh", "p2wpkh", "0014", 22, 0),
    ("p2wsh", "p2wsh", "0020", 34, 0),
    ("p2sh-multisig", "p2sh-multisig", "a914", 23, None),
    ("p2tr", "p2tr", "5120", 34, 1),
]


def scenario_addresses(rec: list[dict[str, Any]], node: Bitcoind, setup: dict[str, Any]) -> None:
    """Compare validateaddress, getaddressinfo, and decodescript per script type."""
    for label, key, prefix, expected_length, witness_version in ADDRESS_TYPES:
        address = setup["addresses"][key]
        validated, _ = rpc_case(
            rec,
            node,
            f"addr.{label}.validate",
            "validateaddress",
            [address],
            note=f"validateaddress for {label}.",
        )
        info, _ = rpc_case(
            rec,
            node,
            f"addr.{label}.getaddressinfo",
            "getaddressinfo",
            [address],
            wallet=WALLET,
            note=f"getaddressinfo for {label}.",
        )
        if validated is not None:
            rpc_case(
                rec,
                node,
                f"addr.{label}.decodescript",
                "decodescript",
                [validated["scriptPubKey"]],
                note=f"decodescript of the {label} scriptPubKey.",
            )
        if validated is not None and info is not None:
            same_script = validated["scriptPubKey"] == info["scriptPubKey"]
            check_case(
                rec,
                f"addr.{label}.spk_equivalence",
                "validateaddress.scriptPubKey == getaddressinfo.scriptPubKey",
                {
                    "address": address,
                    "validate_scriptPubKey": validated["scriptPubKey"],
                    "getaddressinfo_scriptPubKey": info["scriptPubKey"],
                },
                condition=same_script,
                note="Both address paths must report the same output script.",
            )
            script = validated["scriptPubKey"]
            shape_ok = script.startswith(prefix) and len(script) == expected_length * 2
            if witness_version is None:
                shape_ok = shape_ok and validated.get("iswitness") is False
            else:
                shape_ok = shape_ok and validated.get("iswitness") is True
                shape_ok = shape_ok and validated.get("witness_version") == witness_version
            check_case(
                rec,
                f"addr.{label}.script_shape",
                "scriptPubKey starts with the expected type prefix and has the expected length",
                {
                    "address": address,
                    "scriptPubKey": script,
                    "expected_prefix": prefix,
                    "expected_length_bytes": expected_length,
                    "iswitness": validated.get("iswitness"),
                    "witness_version": validated.get("witness_version"),
                },
                condition=shape_ok,
                note="Prefix and witness metadata identify the script family.",
            )


def _build_psbt(
    node: Bitcoind,
    setup: dict[str, Any],
    receiver: str,
    fee_rate: int,
    *,
    psbt_version: int = 0,
) -> dict[str, Any]:
    """Call walletcreatefundedpsbt with explicit input and fixed change."""
    utxo = setup["utxo"]
    inputs = [{"txid": utxo["txid"], "vout": utxo["vout"]}]
    outputs = [{receiver: 1.0}]
    options = {
        "fee_rate": fee_rate,
        "changePosition": 1,
        "changeAddress": setup["change_address"],
        "replaceable": True,
    }
    return node.rpc(
        "walletcreatefundedpsbt",
        inputs,
        outputs,
        0,
        options,
        True,
        2,
        psbt_version,
        wallet=WALLET,
    )


def _funding_case(
    rec: list[dict[str, Any]],
    node: Bitcoind,
    setup: dict[str, Any],
    cid: str,
    receiver_key: str,
    fee_rate: int,
    expected_output_type: str,
) -> None:
    """Emit one create/process/finalize/accept chain and its arithmetic checks."""
    receiver = setup["addresses"][receiver_key]
    created, err = rpc_case(
        rec,
        node,
        f"{cid}.create",
        "walletcreatefundedpsbt",
        [
            [{"txid": setup["utxo"]["txid"], "vout": setup["utxo"]["vout"]}],
            [{receiver: 1.0}],
            0,
            {
                "fee_rate": fee_rate,
                "changePosition": 1,
                "changeAddress": setup["change_address"],
                "replaceable": True,
            },
            True,
            2,
            0,
        ],
        wallet=WALLET,
        note=f"Explicit 50 BTC input, 1 BTC to {receiver_key}, fee_rate={fee_rate} sat/vB.",
    )
    if err is not None or created is None:
        return
    psbt = created["psbt"]

    rpc_case(
        rec,
        node,
        f"{cid}.decode_unsigned",
        "decodepsbt",
        [psbt],
        project=_project_psbt,
        note="Unsigned PSBT structure and fee before signing.",
    )
    processed, proc_err = rpc_case(
        rec,
        node,
        f"{cid}.process",
        "walletprocesspsbt",
        [psbt],
        wallet=WALLET,
        note="Wallet signs the wallet-owned input.",
    )
    if proc_err is not None or processed is None:
        return
    finalized, fin_err = rpc_case(
        rec,
        node,
        f"{cid}.finalize",
        "finalizepsbt",
        [processed["psbt"]],
        note="Finalize and extract the network transaction.",
    )
    if fin_err is not None or finalized is None or "hex" not in finalized:
        return
    raw, raw_err = rpc_case(
        rec,
        node,
        f"{cid}.rawtx",
        "decoderawtransaction",
        [finalized["hex"]],
        project=_project_rawtx,
        note="Signed transaction size and output scripts.",
    )
    rpc_case(
        rec,
        node,
        f"{cid}.testmempoolaccept",
        "testmempoolaccept",
        [[finalized["hex"]]],
        note="Policy acceptance under default maxfeerate.",
    )
    if raw_err is not None or raw is None:
        return

    input_sats = setup["utxo_sats"]
    output_sats = sum(int(round(out["value"] * 100_000_000)) for out in raw["vout"])
    fee_sats = input_sats - output_sats
    reported_fee_sats = int(round(created["fee"] * 100_000_000))
    change_sats = int(round(raw["vout"][1]["value"] * 100_000_000))

    check_case(
        rec,
        f"{cid}.fee_conservation",
        "input_sats - output_sats == reported_fee_sats and change_sats == input_sats - 100000000 - fee_sats",
        {
            "input_sats": input_sats,
            "output_sats": output_sats,
            "fee_sats": fee_sats,
            "reported_fee_sats": reported_fee_sats,
            "change_sats": change_sats,
        },
        condition=(
            fee_sats == reported_fee_sats
            and change_sats == input_sats - 100_000_000 - fee_sats
        ),
        note="No satoshi is created or lost; the reported fee is the actual fee.",
    )
    check_case(
        rec,
        f"{cid}.fee_rate_met",
        "fee_sats >= fee_rate * vsize",
        {
            "fee_sats": fee_sats,
            "fee_rate": fee_rate,
            "vsize": raw["vsize"],
            "effective_sat_per_vb": fee_sats / raw["vsize"],
        },
        condition=fee_sats >= fee_rate * raw["vsize"],
        note="Signing may make the transaction smaller than the estimate; it must not underpay the requested rate.",
    )
    check_case(
        rec,
        f"{cid}.output_types",
        "recipient script type matches requested type and change is bech32",
        {
            "recipient_address": receiver,
            "recipient_type": raw["vout"][0]["scriptPubKey"]["type"],
            "recipient_expected_type": expected_output_type,
            "change_type": raw["vout"][1]["scriptPubKey"]["type"],
            "changepos": created["changepos"],
        },
        condition=(
            raw["vout"][0]["scriptPubKey"]["type"] == expected_output_type
            and raw["vout"][1]["scriptPubKey"]["type"] == "witness_v0_keyhash"
            and created["changepos"] == 1
        ),
        note="Change position is fixed at 1 so output order is reproducible.",
    )


def scenario_psbt(rec: list[dict[str, Any]], node: Bitcoind, setup: dict[str, Any]) -> None:
    """Run one complete PSBT lifecycle plus negative PSBT/funding cases."""
    receiver = setup["addresses"]["p2wpkh"]
    created, err = rpc_case(
        rec,
        node,
        "psbt.lifecycle.create",
        "walletcreatefundedpsbt",
        [
            [{"txid": setup["utxo"]["txid"], "vout": setup["utxo"]["vout"]}],
            [{receiver: 1.0}],
            0,
            {
                "fee_rate": 10,
                "changePosition": 1,
                "changeAddress": setup["change_address"],
                "replaceable": True,
            },
            True,
            2,
            0,
        ],
        wallet=WALLET,
        note="PSBT v0, one wallet-owned input, one payment plus change.",
    )
    if err is not None or created is None:
        return
    psbt = created["psbt"]
    rpc_case(rec, node, "psbt.lifecycle.decode_unsigned", "decodepsbt", [psbt], project=_project_psbt)
    processed, proc_err = rpc_case(
        rec,
        node,
        "psbt.lifecycle.process",
        "walletprocesspsbt",
        [psbt, True, "ALL", True, False],
        wallet=WALLET,
        note="Sign but do not finalize, so the partial signature is visible in the next decode.",
    )
    if proc_err is not None or processed is None:
        return
    signed_psbt = processed["psbt"]
    rpc_case(rec, node, "psbt.lifecycle.decode_signed", "decodepsbt", [signed_psbt], project=_project_psbt)
    rpc_case(
        rec,
        node,
        "psbt.lifecycle.analyze_signed",
        "analyzepsbt",
        [signed_psbt],
        project=_project_analyze,
        note="Estimates are available before finalization.",
    )
    finalized, fin_err = rpc_case(rec, node, "psbt.lifecycle.finalize", "finalizepsbt", [signed_psbt])
    if fin_err is not None or finalized is None or "hex" not in finalized:
        return
    rpc_case(
        rec,
        node,
        "psbt.lifecycle.rawtx",
        "decoderawtransaction",
        [finalized["hex"]],
        project=_project_rawtx,
    )
    rpc_case(rec, node, "psbt.lifecycle.testmempoolaccept", "testmempoolaccept", [[finalized["hex"]]])

    # Policy trap: a valid transaction can still fail the client fee-rate cap.
    rpc_case(
        rec,
        node,
        "psbt.lifecycle.maxfeerate_reject",
        "testmempoolaccept",
        [[finalized["hex"]], 0.00001],
        note="Same bytes, maxfeerate=1 sat/vB; the tx pays 10 sat/vB and is rejected by policy.",
    )

    # Finalizing an unsigned PSBT is not an error; it simply reports incomplete.
    rpc_case(
        rec,
        node,
        "psbt.lifecycle.finalize_unsigned",
        "finalizepsbt",
        [psbt],
        note="Unsigned PSBT yields complete=false rather than an RPC error.",
    )

    rpc_case(
        rec,
        node,
        "psbt.error.malformed_process",
        "walletprocesspsbt",
        ["not-a-psbt"],
        wallet=WALLET,
        note="Malformed base64 is an RPC error.",
    )
    rpc_case(
        rec,
        node,
        "psbt.error.malformed_finalize",
        "finalizepsbt",
        ["not-a-psbt"],
        note="Malformed base64 is an RPC error.",
    )
    rpc_case(
        rec,
        node,
        "psbt.error.insufficient_funds",
        "walletcreatefundedpsbt",
        [
            [{"txid": setup["utxo"]["txid"], "vout": setup["utxo"]["vout"]}],
            [{receiver: 100.0}],
            0,
            {"fee_rate": 10, "changePosition": 1, "changeAddress": setup["change_address"]},
            True,
            2,
            0,
        ],
        wallet=WALLET,
        note="Explicit input is smaller than the requested output plus fee.",
    )
    rpc_case(
        rec,
        node,
        "psbt.error.bad_address",
        "walletcreatefundedpsbt",
        [
            [{"txid": setup["utxo"]["txid"], "vout": setup["utxo"]["vout"]}],
            [{"not-an-address": 1.0}],
            0,
            {"fee_rate": 10},
            True,
            2,
            0,
        ],
        wallet=WALLET,
        note="Invalid destination address is rejected.",
    )
    rpc_case(
        rec,
        node,
        "psbt.error.negative_fee_rate",
        "walletcreatefundedpsbt",
        [
            [{"txid": setup["utxo"]["txid"], "vout": setup["utxo"]["vout"]}],
            [{receiver: 1.0}],
            0,
            {"fee_rate": -1},
            True,
            2,
            0,
        ],
        wallet=WALLET,
        note="Negative fee rate is rejected.",
    )


FUNDING_MATRIX: list[tuple[str, str, str]] = [
    ("bech32", "p2wpkh", "witness_v0_keyhash"),
    ("p2sh-segwit", "p2sh-p2wpkh", "scripthash"),
    ("legacy", "p2pkh", "pubkeyhash"),
]


def scenario_funding(rec: list[dict[str, Any]], node: Bitcoind, setup: dict[str, Any]) -> None:
    """Run the 3 output types x 3 fee rates funding arithmetic matrix."""
    for label, receiver_key, expected_type in FUNDING_MATRIX:
        for rate in (1, 10, 50):
            _funding_case(
                rec,
                node,
                setup,
                f"fund.{label}.r{rate}",
                receiver_key,
                rate,
                expected_type,
            )


SCENARIOS: list[Callable[[list[dict[str, Any]], Bitcoind, dict[str, Any]], None]] = [
    scenario_context,
    scenario_descriptors,
    scenario_import,
    scenario_addresses,
    scenario_psbt,
    scenario_funding,
]


def run_all(node: Bitcoind) -> list[dict[str, Any]]:
    """Prepare the wallet, run every scenario, and return the case list."""
    setup = prepare(node)
    rec: list[dict[str, Any]] = []
    for scenario in SCENARIOS:
        scenario(rec, node, setup)
    return rec


def run_smoke(node: Bitcoind) -> list[dict[str, Any]]:
    """Run ten representative cases for a fast end-to-end check.

    Preparation (mining, wallet creation, import) is still required, but the
    ten recorded observations span descriptor inspection, derivation, address
    validation, PSBT creation, signing, finalization, and mempool policy.
    """
    setup = prepare(node)
    rec: list[dict[str, Any]] = []
    scenario_context(rec, node, setup)
    rec[:] = rec[:2]  # network + chain

    checksummed = _checked(node, f"wpkh({FIXED_PUBKEY})")
    rpc_case(rec, node, "smoke.descriptor.wpkh", "getdescriptorinfo", [checksummed])
    rpc_case(rec, node, "smoke.descriptor.tr", "getdescriptorinfo", [_checked(node, f"tr({FIXED_PUBKEY})")])
    rpc_case(rec, node, "smoke.derive.wpkh", "deriveaddresses", [setup["public"]["wpkh"], [0, 2]])

    pub_list = node.rpc("listdescriptors", False, wallet=WALLET)
    observed_case(
        rec,
        "smoke.listdescriptors",
        "listdescriptors",
        [False],
        result=pub_list,
        wallet=WALLET,
        project=lambda r: {"count": len(r["descriptors"]), "wallet_name": r["wallet_name"]},
    )

    rpc_case(
        rec,
        node,
        "smoke.address.validate",
        "validateaddress",
        [setup["addresses"]["p2wpkh"]],
        project=lambda r: {
            "address": r["address"],
            "scriptPubKey": r["scriptPubKey"],
            "iswitness": r["iswitness"],
            "witness_version": r["witness_version"],
        },
    )

    created = _build_psbt(node, setup, setup["addresses"]["p2wpkh"], 10)
    observed_case(
        rec,
        "smoke.psbt.create",
        "walletcreatefundedpsbt",
        [
            [{"txid": setup["utxo"]["txid"], "vout": setup["utxo"]["vout"]}],
            [{setup["addresses"]["p2wpkh"]: 1.0}],
            0,
            {
                "fee_rate": 10,
                "changePosition": 1,
                "changeAddress": setup["change_address"],
                "replaceable": True,
            },
            True,
            2,
            0,
        ],
        result=created,
        wallet=WALLET,
    )
    processed = node.rpc("walletprocesspsbt", created["psbt"], wallet=WALLET)
    observed_case(
        rec,
        "smoke.psbt.process",
        "walletprocesspsbt",
        [created["psbt"]],
        result=processed,
        wallet=WALLET,
    )
    finalized = node.rpc("finalizepsbt", processed["psbt"])
    rpc_case(
        rec,
        node,
        "smoke.psbt.testmempoolaccept",
        "testmempoolaccept",
        [[finalized["hex"]]],
        project=lambda r: {"allowed": r[0]["allowed"], "vsize": r[0]["vsize"], "fees": r[0]["fees"]},
    )
    return rec[:10]
