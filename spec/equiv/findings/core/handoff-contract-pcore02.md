# Handoff draft — CONTRACT: P-CORE-02 checker seam

**Status:** OPEN (CORE-IR cannot edit `shims/`; this is the requested change)
**From:** CORE-IR
**To:** CONTRACT
**Blocked artifact:** any cell that uses the devirtualized engine
(`BTC_EQUIV_DEVIRT`) cannot link/run until this seam exists.

## Why

`P-CORE-02` makes `BaseSignatureChecker` concrete and routes its four methods
to `extern "C"` hooks. The engine still calls the same four operations at
`src/script/interpreter.cpp:349`, `:380`, `:565`, `:599`, `:1177`, `:1972`,
but the dispatch target is now the hook, not the vtable. The existing shim
constructs a `TransactionSignatureChecker` and passes it directly:

```cpp
// shims/core/entry.cpp:137-149 (current, unpatched build)
PrecomputedTransactionData txdata;
txdata.Init(tx, std::move(spent_outputs));
TransactionSignatureChecker checker(
    &tx, input_index, amount, txdata, MissingDataBehavior::FAIL);
const bool ok = VerifyScript(..., checker, &err);
```

Under `BTC_EQUIV_DEVIRT`, passing that object as `const BaseSignatureChecker&`
would call the base hooks with `m_ctx == nullptr` because the derived object
did not set the base context. The hooks would have no transaction state.

## Ask

In a `BTC_EQUIV_DEVIRT` build of `shims/core/entry.cpp`:

1. Define a context object that owns/points at the transaction data needed by
   the four checks:

```cpp
struct CoreCheckerCtx {
    const CTransaction* tx;
    unsigned int nIn;
    CAmount amount;
    const PrecomputedTransactionData* txdata;
    MissingDataBehavior mdb;
};
```

2. Construct the base checker with that context and pass **it** to
   `VerifyScript`:

```cpp
CoreCheckerCtx ctx{&tx, input_index, amount, &txdata, MissingDataBehavior::FAIL};
BaseSignatureChecker checker(&ctx);
const bool ok = VerifyScript(..., checker, &err);
```

3. Define the four hooks in the shim TU. They must reconstruct the exact
   arguments the virtual methods received and call a
   `TransactionSignatureChecker` built from `ctx`:

```cpp
extern "C" bool btc_equiv_check_ecdsa(
    const void* p, const unsigned char* sig, size_t sig_len,
    const unsigned char* pubkey, size_t pubkey_len,
    const unsigned char* script, size_t script_len, int sigversion)
{
    const auto* c = static_cast<const CoreCheckerCtx*>(p);
    TransactionSignatureChecker checker(
        c->tx, c->nIn, c->amount, *c->txdata, c->mdb);
    CScript script_code;
    if (script_len != 0) script_code.assign(script, script + script_len);
    return checker.CheckECDSASignature(
        std::vector<unsigned char>(sig, sig + sig_len),
        std::vector<unsigned char>(pubkey, pubkey + pubkey_len),
        script_code, static_cast<SigVersion>(sigversion));
}
```

Do the analogous thing for `btc_equiv_check_schnorr` (forward `execdata` and
`serror` as `ScriptExecutionData*` / `ScriptError*`), and for
`btc_equiv_check_locktime` / `btc_equiv_check_sequence` (forward the
`int64_t`).

4. Keep the ABI and result mapping unchanged: `equiv_entry` still returns
   `0` fail, `1` pass, `2` bad input, `3` internal; `error_kind` is still
   Core's `ScriptError` ordinal 1:1.

5. Guard the new code with the same `BTC_EQUIV_DEVIRT` macro so the normal
   shim build is byte-for-byte unchanged.

## Constraints

- Do not edit `src/script/*` for this; the source patch is CORE's
  `P-CORE-02` and is already in `patches/core/`.
- `script_len == 0` must not form a range from a possibly-null pointer.
- Do not add engine logic to the hooks; they are marshalling plus a direct
  call to `TransactionSignatureChecker`, exactly as the vtable target was.
- The shim remains line-reviewable; keep the hook bodies small and cite
  `patches/core/README.md` §P-CORE-02.

## Acceptance

- `shims/core/entry.cpp` compiles standalone with and without
  `BTC_EQUIV_DEVIRT`.
- The devirt build links against the patched `interpreter.cpp` and has no
  undefined `btc_equiv_check_*` symbols.
- A smoke call and the checksig/cms corpus selections return the same
  `(result, error_kind)` as the unpatched virtual-dispatch build (differential
  run is CORE's P-CORE-02 plan, but CONTRACT should provide the linked
  binary).
