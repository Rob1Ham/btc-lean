//! R-leg ABI v2 shim — rbitcoin public API only, no engine patch.
//!
//! Source pin: reardencode/rbitcoin @ ae47aa98174e04d0d8c493f13041daf65e4ac1d3
//! Toolchain: rustc 1.95.0 (the repo pin), LLVM 22.1.2 (behavioral lane;
//! the proof-IR lane is the separate rustc 1.88 build in PINS.lock).
//!
//! Build with `shims/rust/build.sh`; it checks the clean tree and links the
//! crate rlibs. Do not build the patched `equiv-ffi` lane as an official
//! artifact.
//!
//! Known boundary restriction (R-GAP-01): rbitcoin returns
//! `ConsensusError::Script(String)`, not a typed ScriptError. The map below is
//! deliberately narrow: only tokens exercised by E0 are mapped; every other
//! failure stays EQUIV_ERR_UNKNOWN_ERROR rather than being guessed.
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::slice;

use rbitcoin_consensus::{
    verify_tx_scripts_with_flags, ConsensusError, ScriptVerifyFlags,
};

const OK: i32 = 1;
const FAIL: i32 = 0;
const BAD_INPUT: i32 = 2;
const INTERNAL: i32 = 3;
const ERR_UNKNOWN: i32 = 1;

fn no_flags() -> ScriptVerifyFlags {
    ScriptVerifyFlags {
        bip65_active: false,
        bip112_active: false,
        bip66_active: false,
        bip16_active: false,
        taproot_active: false,
        minimal_if: false,
        nullfail: false,
        low_s: false,
        strictenc: false,
        null_dummy: false,
        minimal_data: false,
        witness_pubkeytype: false,
        witness_active: false,
        discourage_upgradable_witness: false,
        const_scriptcode: false,
        cleanstack: false,
    }
}

fn kind_of(e: &ConsensusError) -> i32 {
    match e {
        ConsensusError::Script(s) => {
            // rbitcoin exposes only `Script(String)` (R-GAP-01). This is a
            // boundary map, not engine logic; it is deliberately narrow and
            // every unmapped token stays UNKNOWN rather than being guessed.
            if s.contains("script false") {
                2 // Core SCRIPT_ERR_EVAL_FALSE
            } else if s.contains("unknown opcode 0x6a") {
                3 // Core SCRIPT_ERR_OP_RETURN
            } else if s.contains("unknown opcode") {
                16 // Core SCRIPT_ERR_BAD_OPCODE
            } else {
                ERR_UNKNOWN
            }
        }
        ConsensusError::BadBlock(_) => INTERNAL,
        _ => ERR_UNKNOWN,
    }
}

/// # Safety
/// Pointers must be valid for the stated lengths; `error_kind` may be null.
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
    // ABI domain: one input, flags 0 supported by this shim; everything else
    // is a named bad-input result, never a silent reinterpretation.
    if tx_bytes.is_null()
        || tx_len == 0
        || (spk_len > 0 && spk.is_null())
        || spk_len > 10_000
        || amount < 0
        || input_index != 0
        || flags != 0
    {
        return BAD_INPUT;
    }
    let txb = slice::from_raw_parts(tx_bytes, usize::try_from(tx_len).unwrap_or(usize::MAX));
    let spkb = if spk_len == 0 {
        &[][..]
    } else {
        slice::from_raw_parts(spk, usize::try_from(spk_len).unwrap_or(usize::MAX))
    };
    let tx: bitcoin::Transaction = match bitcoin::consensus::encode::deserialize(txb) {
        Ok(t) => t,
        Err(_) => return BAD_INPUT,
    };
    if tx.input.len() != 1 {
        return BAD_INPUT;
    }
    let prevout = bitcoin::TxOut {
        value: bitcoin::Amount::from_sat(amount as u64),
        script_pubkey: bitcoin::ScriptBuf::from_bytes(spkb.to_vec()),
    };
    let res = catch_unwind(AssertUnwindSafe(|| {
        verify_tx_scripts_with_flags(vec![prevout], tx, no_flags())
    }));
    match res {
        Ok(Ok(())) => { if !error_kind.is_null() { *error_kind = 0; } OK }
        Ok(Err(e)) => {
            if !error_kind.is_null() {
                *error_kind = kind_of(&e);
            }
            FAIL
        }
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
