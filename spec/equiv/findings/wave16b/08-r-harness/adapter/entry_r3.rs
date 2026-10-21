//! R-leg ABI v3 *adapter prototype* — rbitcoin public API only, no engine patch.
//!
//! Source pin: reardencode/rbitcoin @ ae47aa98174e04d0d8c493f13041daf65e4ac1d3
//! Toolchain: rustc 1.95.0 (repo pin), the behavioral lane.
//!
//! This is NOT a cell artifact and NOT a proof artifact. It is a prototype that
//! measures how much of the contract ABI v2 domain can be exposed through
//! rbitcoin's *public* API, without patching rbitcoin. It answers F-HARNESS-002:
//!
//!   * flags: 16 of Core's 21 defined bits are mirrored by `ScriptVerifyFlags`;
//!     the five policy-only bits (5 SIGPUSHONLY, 7 DISCOURAGE_UPGRADABLE_NOPS,
//!     18 DISCOURAGE_UPGRADABLE_TAPROOT_VERSION, 19 DISCOURAGE_OP_SUCCESS,
//!     20 DISCOURAGE_UPGRADABLE_PUBKEYTYPE) have no engine field and are
//!     rejected as BAD_INPUT (2) rather than silently ignored.
//!   * input: the public entry verifies *all* inputs. `input_index > 0` cannot
//!     be emulated (the engine returns at the first failing earlier input).
//!     `input_index == 0` on a multi-input tx is emulated: other inputs get a
//!     synthetic OP_TRUE prevout, and a failure annotated `vin != 0` is
//!     discarded because the contract asks only about input 0. This is exact
//!     for BASE/WITNESS_V0; native witness v1 (taproot) is rejected because
//!     BIP341 hashes every spent output (tape.md §6).
//!   * error: rbitcoin has `ConsensusError::Script(String)` (no typed
//!     ScriptError). The table below is a *boundary map* (shims/README.md
//!     permits "map the engine's error to the shared enum") from the engine's
//!     closed message vocabulary to Core ordinals. It is context-sensitive in
//!     exactly one place (`der sig`: DERSIG on => SIG_DER, off => EVAL_FALSE).
//!     Every token not in the table stays EQUIV_ERR_UNKNOWN_ERROR and is
//!     reported by `tools/token_census.py`.
//!
//! Differences from the pinned `shims/rust/entry.rs` (a diff, not a
//! replacement): amount upper bound, no 10k spk cap, full flag map, multi-input
//! input_index==0, and the wider error table.
//!
//! # Safety
//! `equiv_entry` follows contract/tape.md §1/§7. Pointers must be valid for the
//! stated lengths; `error_kind` is written when non-NULL (the contract says
//! callers pass non-NULL; tolerating NULL is defensive only).
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::slice;

use rbitcoin_consensus::{verify_tx_scripts_with_flags, ConsensusError, ScriptVerifyFlags};

const OK: i32 = 1;
const FAIL: i32 = 0;
const BAD_INPUT: i32 = 2;
const INTERNAL: i32 = 3;

const ERR_OK: i32 = 0;
const ERR_UNKNOWN: i32 = 1;

/// contract/tape.md §4
const MAX_MONEY: i64 = 21_000_000 * 100_000_000;
/// contract/tape.md §5: MAX_SCRIPT_VERIFY_FLAGS at the Core pin.
const FLAG_MASK: u64 = 0x1f_ffff;
/// Core bits with no `ScriptVerifyFlags` field.
const UNSUPPORTED_FLAGS: u64 = (1 << 5) | (1 << 7) | (1 << 18) | (1 << 19) | (1 << 20);

fn flag(f: u64, bit: u32) -> bool {
    (f >> bit) & 1 != 0
}

/// Core flag word -> rbitcoin `ScriptVerifyFlags`, or `None` when the word is
/// outside the contract domain or uses a bit this engine cannot express.
fn flags_from_core(f: u64) -> Option<ScriptVerifyFlags> {
    if f & !FLAG_MASK != 0 {
        return None;
    }
    // Core's VerifyScript implications (tape.md §5).
    if flag(f, 11) && !flag(f, 0) {
        return None; // WITNESS => P2SH
    }
    if flag(f, 8) && (!flag(f, 0) || !flag(f, 11)) {
        return None; // CLEANSTACK => P2SH && WITNESS
    }
    if f & UNSUPPORTED_FLAGS != 0 {
        return None; // no engine field; do not silently drop a flag
    }
    Some(ScriptVerifyFlags {
        bip65_active: flag(f, 9),                    // CHECKLOCKTIMEVERIFY
        bip112_active: flag(f, 10),                  // CHECKSEQUENCEVERIFY
        bip66_active: flag(f, 2),                    // DERSIG
        bip16_active: flag(f, 0),                    // P2SH
        taproot_active: flag(f, 17),                 // TAPROOT
        minimal_if: flag(f, 13),                     // MINIMALIF
        nullfail: flag(f, 14),                       // NULLFAIL
        low_s: flag(f, 3),                           // LOW_S
        strictenc: flag(f, 1),                       // STRICTENC
        null_dummy: flag(f, 4),                      // NULLDUMMY
        minimal_data: flag(f, 6),                    // MINIMALDATA
        witness_pubkeytype: flag(f, 15),             // WITNESS_PUBKEYTYPE
        witness_active: flag(f, 11),                 // WITNESS
        discourage_upgradable_witness: flag(f, 12),  // DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
        const_scriptcode: flag(f, 16),               // CONST_SCRIPTCODE
        cleanstack: flag(f, 8),                      // CLEANSTACK
    })
}

/// Strip the ` txid=… vin=…` annotation added by `verify_job_all_inputs`.
fn token_of(msg: &str) -> &str {
    msg.split(" txid=").next().unwrap_or(msg)
}

/// `vin` from the annotation, when present.
fn annotated_vin(msg: &str) -> Option<u32> {
    let after = msg.split(" vin=").nth(1)?;
    after.split_whitespace().next()?.parse().ok()
}

/// Engine message token -> Core `ScriptError` ordinal. `None` means "no honest
/// map": the caller must return UNKNOWN (result 0) or INTERNAL (result 3).
fn mapped_kind(token: &str) -> Option<i32> {
    let k = match token {
        // end-of-script results
        "script false" | "EVAL_FALSE" => 2,             // SCRIPT_ERR_EVAL_FALSE
        "cleanstack" => 30,                             // SCRIPT_ERR_CLEANSTACK
        // limits and parse
        "script too large" => 5,                        // SCRIPT_ERR_SCRIPT_SIZE
        "PUSH_SIZE" | "push too large" => 6,            // SCRIPT_ERR_PUSH_SIZE
        "op count" => 7,                                // SCRIPT_ERR_OP_COUNT
        "stack size" => 8,                              // SCRIPT_ERR_STACK_SIZE
        "script parse" | "OP_VERIF" => 16,              // SCRIPT_ERR_BAD_OPCODE
        "MINIMALDATA" => 25,                            // SCRIPT_ERR_MINIMALDATA
        "unbalanced IF" | "OP_ELSE" | "OP_ENDIF" => 20, // SCRIPT_ERR_UNBALANCED_CONDITIONAL
        // stack ops
        "stack empty" | "OP_PICK" | "OP_ROLL" => 18,    // SCRIPT_ERR_INVALID_STACK_OPERATION
        "altstack empty" => 19,                         // SCRIPT_ERR_INVALID_ALTSTACK_OPERATION
        // verify ops
        "OP_VERIFY" => 11,                              // SCRIPT_ERR_VERIFY
        "OP_EQUALVERIFY" => 12,                         // SCRIPT_ERR_EQUALVERIFY
        "OP_NUMEQUALVERIFY" => 15,                      // SCRIPT_ERR_NUMEQUALVERIFY
        "CHECKSIGVERIFY" | "CHECKSIGVERIFY empty" => 14, // SCRIPT_ERR_CHECKSIGVERIFY
        "CHECKMULTISIGVERIFY" => 13,                    // SCRIPT_ERR_CHECKMULTISIGVERIFY
        // locktime
        "CLTV negative" | "CSV negative" => 21,         // SCRIPT_ERR_NEGATIVE_LOCKTIME
        "CLTV" | "CLTV type" | "CLTV final sequence" | "CSV" | "CSV version" => 22,
        // signature / key encoding
        "SIG_HASHTYPE" => 23,                           // SCRIPT_ERR_SIG_HASHTYPE
        "SIG_DER" => 24,                                // SCRIPT_ERR_SIG_DER
        "SIG_HIGH_S" => 27,                             // SCRIPT_ERR_SIG_HIGH_S
        "NULLDUMMY" => 28,                              // SCRIPT_ERR_SIG_NULLDUMMY
        "PUBKEYTYPE" => 29,                             // SCRIPT_ERR_PUBKEYTYPE
        "MINIMALIF" => 31,                              // SCRIPT_ERR_MINIMALIF
        "NULLFAIL" => 32,                               // SCRIPT_ERR_SIG_NULLFAIL
        "multisig m" => 9,                              // SCRIPT_ERR_SIG_COUNT
        "multisig n" => 10,                             // SCRIPT_ERR_PUBKEY_COUNT
        // softfork safeness
        "DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM" => 34,
        // witness v0
        "WITNESS_PROGRAM_WRONG_LENGTH" => 38,
        "p2wsh empty witness" => 39,                    // SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY
        "p2wsh script hash" | "WITNESS_PROGRAM_MISMATCH" => 40,
        "WITNESS_MALLEATED" => 41,
        "WITNESS_MALLEATED_P2SH" => 42,
        "WITNESS_UNEXPECTED" => 43,
        "WITNESS_PUBKEYTYPE" => 44,
        // taproot / tapscript
        "p2tr empty witness" => 39,
        "p2tr sig" | "p2tr sig len" => 45,              // SCRIPT_ERR_SCHNORR_SIG_SIZE
        "p2tr sighash type" | "tapscript sighash" => 46, // SCRIPT_ERR_SCHNORR_SIG_HASHTYPE
        "tapscript CHECKSIG failed" | "p2tr xonly" | "p2tr schnorr" | "p2tr schnorr parse"
        | "tapscript xonly" => 47,                      // SCRIPT_ERR_SCHNORR_SIG
        "TAPROOT_WRONG_CONTROL_SIZE" => 48,
        "tapscript validation weight" => 49,
        "CHECKMULTISIG disabled in tapscript"
        | "CHECKMULTISIGVERIFY disabled in tapscript" => 50,
        "tapscript empty pubkey" => 52,
        // constant scriptCode
        "OP_CODESEPARATOR" => 53,
        "SIG_FINDANDDELETE" => 54,
        // typed fast paths. The p2pkh/p2wpkh fast paths run only when
        // LOW_S/STRICTENC/NULLFAIL are off (needs_interpreted_ecdsa), so a
        // signature failure there is Core's plain CHECKSIG false.
        "empty sig" | "pubkey" | "p2pkh ecdsa" | "p2wpkh ecdsa" => 2,
        "p2pkh pubkey hash" | "p2wpkh pubkey hash" => 12, // EQUALVERIFY in the implied script
        "p2sh redeem hash" => 2,                        // <hash> EQUAL leaves false
        "p2sh empty scriptSig" => 18,                   // HASH160 on an empty stack
        "p2sh scriptSig op" => 26,                      // SCRIPT_ERR_SIG_PUSHONLY
        "p2wpkh witness len" => 40,                     // 2-items-in-witness rule
        "der sig" => return Some(2),                    // overridden by caller for DERSIG
        _ => {
            if token.starts_with("disabled opcode 0x") {
                17 // SCRIPT_ERR_DISABLED_OPCODE
            } else if token.starts_with("unknown opcode 0x") {
                16 // SCRIPT_ERR_BAD_OPCODE (OP_RETURN is special-cased below)
            } else {
                return None;
            }
        }
    };
    Some(k)
}

/// Context-aware error map. R-GAP-01 is a string map, so the one token whose
/// Core kind depends on a flag is resolved here.
fn kind_of(msg: &str, flags: ScriptVerifyFlags) -> i32 {
    let token = token_of(msg);
    if token == "unknown opcode 0x6a" {
        return 3; // Core OP_RETURN
    }
    if token == "der sig" {
        // p2pkh/p2wpkh fast path: strict_der = bip66_active. Without DERSIG a
        // lax-parse failure is a plain false, i.e. EVAL_FALSE at the tail.
        return if flags.bip66_active { 24 } else { 2 };
    }
    mapped_kind(token).unwrap_or(ERR_UNKNOWN)
}

/// Tokens that mean "the engine was misused or hit an unreachable encoding
/// error". They are result 3 (internal), not a script verdict.
fn is_internal_token(token: &str) -> bool {
    token == "prevout count"
        || token == "input index"
        || token == "invariant: sighash midstate missing"
        || token == "invariant: tapscript spend without tapleaf hash"
        || token == "p2pkh sighash"
        || token == "legacy sighash"
        || token == "bip143 input index"
        || token == "bip143 single output"
        || token == "bip143 outpoint"
        || token == "bip143 scriptCode"
        || token == "bip143 amount"
        || token == "bip143 nSequence"
        || token == "bip143 locktime"
        || token == "bip143 version"
        || token == "bip143 not p2wpkh"
        || token == "p2wsh witness"
        || token == "p2wpkh witness"
        || token == "p2sh spk"
        || token == "p2tr script path short"
        // p2pkh fast-path shape sentinels: mod.rs falls back to verify_bare, so
        // they never escape verify_tx_scripts_with_flags.
        || token == "p2pkh scriptSig"
        || token == "p2pkh scriptSig len"
        || token == "p2pkh scriptSig op"
        || token == "p2pkh scriptSig unexpected op"
        || token.starts_with("p2tr sighash")
        || token.starts_with("tapscript sighash ") // prevouts/input/single
}

/// A witness v1+ program is a native taproot/unknown-version target. Multi-input
/// emulation is invalid there because BIP341 hashes every spent output.
fn is_native_witness_v1_plus(spk: &[u8]) -> bool {
    (4..=42).contains(&spk.len())
        && (0x51..=0x60).contains(&spk[0])
        && usize::from(spk[1]) == spk.len() - 2
}


fn build_prevouts(
    n: usize,
    input_index: usize,
    amount: i64,
    spk: &[u8],
) -> Vec<bitcoin::TxOut> {
    let mut prevouts = Vec::with_capacity(n);
    for i in 0..n {
        if i == input_index {
            prevouts.push(bitcoin::TxOut {
                value: bitcoin::Amount::from_sat(amount as u64),
                script_pubkey: bitcoin::ScriptBuf::from_bytes(spk.to_vec()),
            });
        } else {
            // OP_TRUE: the contract supplies no prevout for other inputs, and
            // their scriptSigs/witnesses are not part of the question. Any
            // failure at vin != input_index is discarded below.
            prevouts.push(bitcoin::TxOut {
                value: bitcoin::Amount::from_sat(0),
                script_pubkey: bitcoin::ScriptBuf::from_bytes(vec![0x51]),
            });
        }
    }
    prevouts
}

/// # Safety
/// Pointers must be valid for the stated lengths.
#[no_mangle]
pub unsafe extern "C" fn equiv_entry(
    tx_bytes: *const u8,
    tx_len: u64,
    spk: *const u8,
    spk_len: u64,
    amount: i64,
    input_index: u32,
    flags: u64,
    error_kind: *mut i32,
) -> i32 {
    if !error_kind.is_null() {
        *error_kind = ERR_UNKNOWN;
    }
    // ---- domain checks: no engine semantics ----
    if tx_bytes.is_null()
        || tx_len == 0
        || (spk_len > 0 && spk.is_null())
        || !(0..=MAX_MONEY).contains(&amount)
    {
        return BAD_INPUT;
    }
    let Some(vf) = flags_from_core(flags) else {
        return BAD_INPUT;
    };
    let txb = match usize::try_from(tx_len) {
        Ok(n) => slice::from_raw_parts(tx_bytes, n),
        Err(_) => return BAD_INPUT,
    };
    let spkb: &[u8] = if spk_len == 0 {
        &[]
    } else {
        match usize::try_from(spk_len) {
            Ok(n) => slice::from_raw_parts(spk, n),
            Err(_) => return BAD_INPUT,
        }
    };
    // `deserialize` consumes the whole buffer (tape.md §2: trailing bytes => 2).
    let tx: bitcoin::Transaction = match bitcoin::consensus::encode::deserialize(txb) {
        Ok(t) => t,
        Err(_) => return BAD_INPUT,
    };
    let n_in = tx.input.len();
    let idx = input_index as usize;
    if idx >= n_in {
        return BAD_INPUT;
    }
    // The public entry has no per-input variant. For index>0 every earlier
    // input would have to pass first, and their prevouts are not on the tape.
    if idx != 0 {
        return BAD_INPUT;
    }
    if n_in > 1 {
        // BIP341 commits to all spent outputs; the synthetic prevouts would
        // change input 0's signature hash. Tape §6 already files that gap.
        // Native only: Core's VerifyWitnessProgram excludes `is_p2sh` v1 from
        // the taproot branch, so P2SH-wrapped v1 is an unknown program (ACS),
        // not BIP341.
        if is_native_witness_v1_plus(spkb) {
            return BAD_INPUT;
        }
    }

    let prevouts = build_prevouts(n_in, idx, amount, spkb);
    let res = catch_unwind(AssertUnwindSafe(|| {
        verify_tx_scripts_with_flags(prevouts, tx, vf)
    }));
    match res {
        Ok(Ok(())) => {
            if !error_kind.is_null() {
                *error_kind = ERR_OK;
            }
            OK
        }
        Ok(Err(e)) => match e {
            ConsensusError::Script(msg) => {
                let token = token_of(&msg);
                if n_in > 1 {
                    match annotated_vin(&msg) {
                        // A later input failed; the contract asks about input 0,
                        // and input 0 already passed (the loop is in order).
                        Some(v) if v != idx as u32 => {
                            if !error_kind.is_null() {
                                *error_kind = ERR_OK;
                            }
                            return OK;
                        }
                        // No annotation: do not guess a per-input verdict.
                        None => return INTERNAL,
                        _ => {}
                    }
                }
                if is_internal_token(token) {
                    return INTERNAL;
                }
                if !error_kind.is_null() {
                    *error_kind = kind_of(&msg, vf);
                }
                FAIL
            }
            // Any other consensus error is not a script verdict.
            _ => INTERNAL,
        },
        Err(_) => INTERNAL,
    }
}

/// # Safety
/// Same contract as `equiv_entry`, without the out-parameter.
#[no_mangle]
pub unsafe extern "C" fn entry(
    tx_bytes: *const u8,
    tx_len: u64,
    spk: *const u8,
    spk_len: u64,
    amount: i64,
    input_index: u32,
    flags: u64,
) -> i32 {
    equiv_entry(
        tx_bytes,
        tx_len,
        spk,
        spk_len,
        amount,
        input_index,
        flags,
        std::ptr::null_mut(),
    )
}
