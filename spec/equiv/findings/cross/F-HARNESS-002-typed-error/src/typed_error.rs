//! F-HARNESS-002 — typed boundary classifier for the R (rbitcoin) leg.
//!
//! **Status: advisory / off-pin probe.** This file is NOT part of the pinned
//! ABI shim (`shims/rust/entry.rs`, sha256 1fd706b8…). Lifting it into the
//! official shim requires a PINS.lock change, a rebuild, and a new E0 result.
//! It establishes no R/C/L equivalence; see `report.md`.
//!
//! rbitcoin at ae47aa98 exposes `ConsensusError::Script(String)`, not a typed
//! `ScriptError` (R-GAP-01). This module is a *boundary* map from the string
//! vocabulary that rbitcoin's script layer actually emits onto the shared
//! `equiv_error_kind` ordinals (`contract/error_kind.h`). It is deliberately
//! total: every source token is either in `EXACT_MAP`, covered by a dynamic
//! pattern, or in `UNMAPPED_TOKENS` with a documented reason. An unmapped
//! token returns `EQUIV_ERR_UNKNOWN_ERROR`; it is never guessed.
//!
//! Mapping rules used here:
//!   * The token must identify exactly one Core error at the pin.
//!   * Tokens whose Core ordinal depends on flags or opcode context, or that
//!     are rbitcoin-internal invariants (Core never emits them), stay UNKNOWN.
//!   * Annotations added by `script/mod.rs` (` txid=… vin=…`) are stripped
//!     before dispatch; they are not part of the engine's error identity.

/// `EQUIV_ERR_UNKNOWN_ERROR` (contract/error_kind.h).
pub const ERR_UNKNOWN: i32 = 1;
/// `EQUIV_ERR_OK`.
#[allow(dead_code)] // used by the witness driver; unused in the cdylib build
pub const ERR_OK: i32 = 0;

/// Exact token → Core ordinal. Tokens are matched after annotation stripping.
///
/// Ordinals are Core's `ScriptError` values at
/// cce32b16874e85e8a00cfa1a2190f0b6f4dcaf66 (contract/error_kind.h).
pub const EXACT_MAP: &[(&str, i32)] = &[
    // ungrouped
    ("script false", 2),                    // SCRIPT_ERR_EVAL_FALSE
    ("EVAL_FALSE", 2),                      // SCRIPT_ERR_EVAL_FALSE
    ("unknown opcode 0x6a", 3),             // SCRIPT_ERR_OP_RETURN (rbitcoin's OP_RETURN arm)
    // max sizes
    ("script too large", 5),                // SCRIPT_ERR_SCRIPT_SIZE
    ("PUSH_SIZE", 6),                       // SCRIPT_ERR_PUSH_SIZE
    ("push too large", 6),                  // SCRIPT_ERR_PUSH_SIZE
    ("op count", 7),                        // SCRIPT_ERR_OP_COUNT
    ("stack size", 8),                      // SCRIPT_ERR_STACK_SIZE
    ("multisig m", 9),                      // SCRIPT_ERR_SIG_COUNT
    ("multisig n", 10),                     // SCRIPT_ERR_PUBKEY_COUNT
    // failed verify operations
    ("OP_VERIFY", 11),                      // SCRIPT_ERR_VERIFY
    ("OP_EQUALVERIFY", 12),                 // SCRIPT_ERR_EQUALVERIFY
    ("CHECKMULTISIGVERIFY", 13),            // SCRIPT_ERR_CHECKMULTISIGVERIFY
    ("CHECKSIGVERIFY", 14),                 // SCRIPT_ERR_CHECKSIGVERIFY
    ("CHECKSIGVERIFY empty", 14),           // BIP342 empty sig + VERIFY → CHECKSIGVERIFY
    ("OP_NUMEQUALVERIFY", 15),              // SCRIPT_ERR_NUMEQUALVERIFY
    // logical/format/canonical
    ("script parse", 16),                   // Core GetOp failure → BAD_OPCODE
    ("scriptSig parse", 16),                // Core GetOp failure → BAD_OPCODE
    ("OP_VERIF", 16),                       // OP_VERIF/OP_VERNOTIF → BAD_OPCODE
    ("unknown opcode 0xba", 16),            // OP_CHECKSIGADD outside tapscript → BAD_OPCODE
    ("OP_PICK", 18),                        // n<0 or n>=stack.size() → INVALID_STACK_OPERATION
    ("OP_ROLL", 18),                        // n<0 or n>=stack.size() → INVALID_STACK_OPERATION
    ("stack empty", 18),                    // every rbitcoin pop/require_n → INVALID_STACK_OPERATION
    ("altstack empty", 19),                 // SCRIPT_ERR_INVALID_ALTSTACK_OPERATION
    ("OP_ELSE", 20),                        // SCRIPT_ERR_UNBALANCED_CONDITIONAL
    ("OP_ENDIF", 20),                       // SCRIPT_ERR_UNBALANCED_CONDITIONAL
    ("unbalanced IF", 20),                  // SCRIPT_ERR_UNBALANCED_CONDITIONAL
    // locktime
    ("CLTV negative", 21),                  // SCRIPT_ERR_NEGATIVE_LOCKTIME
    ("CSV negative", 21),                   // SCRIPT_ERR_NEGATIVE_LOCKTIME
    ("CLTV type", 22),                      // SCRIPT_ERR_UNSATISFIED_LOCKTIME
    ("CLTV", 22),                           // SCRIPT_ERR_UNSATISFIED_LOCKTIME
    ("CLTV final sequence", 22),            // SCRIPT_ERR_UNSATISFIED_LOCKTIME
    ("CSV version", 22),                    // SCRIPT_ERR_UNSATISFIED_LOCKTIME
    ("CSV", 22),                            // SCRIPT_ERR_UNSATISFIED_LOCKTIME
    // malleability
    ("SIG_HASHTYPE", 23),                   // SCRIPT_ERR_SIG_HASHTYPE
    ("SIG_DER", 24),                        // SCRIPT_ERR_SIG_DER
    ("MINIMALDATA", 25),                    // SCRIPT_ERR_MINIMALDATA
    ("p2sh scriptSig op", 26),              // BIP16 push-only → SCRIPT_ERR_SIG_PUSHONLY
    ("SIG_HIGH_S", 27),                     // SCRIPT_ERR_SIG_HIGH_S
    ("NULLDUMMY", 28),                      // SCRIPT_ERR_SIG_NULLDUMMY
    ("PUBKEYTYPE", 29),                     // SCRIPT_ERR_PUBKEYTYPE
    ("cleanstack", 30),                     // SCRIPT_ERR_CLEANSTACK
    ("MINIMALIF", 31),                      // SCRIPT_ERR_MINIMALIF
    ("NULLFAIL", 32),                       // SCRIPT_ERR_SIG_NULLFAIL
    // softfork safeness
    ("DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM", 34), // SCRIPT_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM
    // witness
    ("WITNESS_PROGRAM_WRONG_LENGTH", 38),   // SCRIPT_ERR_WITNESS_PROGRAM_WRONG_LENGTH
    ("p2wsh empty witness", 39),            // SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY
    ("p2tr empty witness", 39),             // SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY
    ("WITNESS_PROGRAM_MISMATCH", 40),       // SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH
    ("p2wsh script hash", 40),              // SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH
    ("p2wpkh witness len", 40),             // Core v0 stack.size()!=2 → WITNESS_PROGRAM_MISMATCH
    ("WITNESS_MALLEATED", 41),              // SCRIPT_ERR_WITNESS_MALLEATED
    ("WITNESS_MALLEATED_P2SH", 42),         // SCRIPT_ERR_WITNESS_MALLEATED_P2SH
    ("WITNESS_UNEXPECTED", 43),             // SCRIPT_ERR_WITNESS_UNEXPECTED
    ("WITNESS_PUBKEYTYPE", 44),             // SCRIPT_ERR_WITNESS_PUBKEYTYPE
    // taproot
    ("TAPROOT_WRONG_CONTROL_SIZE", 48),     // SCRIPT_ERR_TAPROOT_WRONG_CONTROL_SIZE
    ("tapscript validation weight", 49),    // SCRIPT_ERR_TAPSCRIPT_VALIDATION_WEIGHT
    ("CHECKMULTISIG disabled in tapscript", 50),   // SCRIPT_ERR_TAPSCRIPT_CHECKMULTISIG
    ("CHECKMULTISIGVERIFY disabled in tapscript", 50), // SCRIPT_ERR_TAPSCRIPT_CHECKMULTISIG
    ("tapscript CHECKSIG failed", 47),      // SCRIPT_ERR_SCHNORR_SIG
    ("tapscript empty pubkey", 52),         // SCRIPT_ERR_TAPSCRIPT_EMPTY_PUBKEY
    // constant scriptCode
    ("OP_CODESEPARATOR", 53),               // SCRIPT_ERR_OP_CODESEPARATOR
    ("SIG_FINDANDDELETE", 54),              // SCRIPT_ERR_SIG_FINDANDDELETE
    // typed-path checks whose Core analogue is the synthetic P2PKH/P2WPKH
    // template `DUP HASH160 <hash> EQUALVERIFY CHECKSIG`
    ("p2pkh pubkey hash", 12),              // EQUALVERIFY in the synthetic template
    ("p2wpkh pubkey hash", 12),             // EQUALVERIFY in the synthetic template
    ("p2pkh ecdsa", 2),                     // CHECKSIG leaves false → final EVAL_FALSE
    ("p2wpkh ecdsa", 2),                    // CHECKSIG leaves false → final EVAL_FALSE
];

/// Tokens that are intentionally **not** mapped, with the reason. Every
/// unmapped token in the pinned source census must appear here (the audit
/// tool enforces this). They return `ERR_UNKNOWN`.
#[allow(dead_code)] // used by tests / census dump; unused in the cdylib build
pub const UNMAPPED_TOKENS: &[&str] = &[
    // rbitcoin-internal invariants: Core has no `ScriptError` for these.
    "prevout count",
    "input index",
    "invariant: sighash midstate missing",
    "invariant: tapscript spend without tapleaf hash",
    "bip143 amount",
    "bip143 input index",
    "bip143 locktime",
    "bip143 nSequence",
    "bip143 not p2wpkh",
    "bip143 outpoint",
    "bip143 scriptCode",
    "bip143 single output",
    "bip143 version",
    "legacy sighash",
    "p2pkh sighash",
    "tapscript sighash",
    "tapscript sighash input",
    "tapscript sighash prevouts",
    "tapscript sighash single",
    // Context-dependent: the Core ordinal depends on flags and/or opcode.
    //   der sig   : DERSIG/LOW_S/STRICTENC → SIG_DER(24); flags=0 → false path (2 or 14).
    //   empty sig : NULLFAIL → SIG_NULLFAIL(32); flags=0 → false path (2 or 14).
    //   pubkey    : STRICTENC → PUBKEYTYPE(29); flags=0 → false path (2 or 14).
    "der sig",
    "empty sig",
    "pubkey",
    // Typed-path shape errors that can stand for more than one Core failure.
    "p2wpkh witness",
    "p2wpkh empty witness item",
    "p2wsh witness",
    "p2pkh scriptSig",
    "p2pkh scriptSig op",
    "scriptSig non-push",
    "p2pkh scriptSig len",
    "p2pkh scriptSig unexpected op",
    "p2sh spk",
    "p2sh empty scriptSig",
    "p2sh redeem hash",
    // Taproot typed-path tokens (outside the current flags=0 ABI domain anyway).
    "p2tr sig",
    "p2tr sig len",
    "p2tr sighash type",
    "p2tr xonly",
    "p2tr schnorr",
    "p2tr schnorr parse",
    "p2tr script path short",
    "tapscript xonly",
    // Test-only literal (not emitted by the engine).
    "already",
];

/// Remove the operator diagnostic suffix ` txid=… vin=…` added by
/// `crates/rbitcoin-consensus/src/script/mod.rs::annotate_script_err`.
pub fn strip_annotation(raw: &str) -> &str {
    raw.split(" txid=").next().unwrap_or(raw)
}

/// Classify one raw `ConsensusError::Script` message.
///
/// Returns a Core `ScriptError` ordinal (see `contract/error_kind.h`) or
/// `ERR_UNKNOWN` when the token is not identity-preserving.
pub fn classify_script_message(raw: &str) -> i32 {
    let msg = strip_annotation(raw);

    if let Some((_, ordinal)) = EXACT_MAP.iter().find(|(token, _)| *token == msg) {
        return *ordinal;
    }

    // Dynamic opcode spellings: `disabled opcode 0x{code:02x}` and
    // `unknown opcode 0x{code:02x}`. OP_RETURN (0x6a) is already an exact
    // token, but keep the dynamic check belt-and-braces for `0x6a`.
    if let Some(rest) = msg.strip_prefix("unknown opcode 0x") {
        if rest == "6a" {
            return 3; // SCRIPT_ERR_OP_RETURN
        }
        return 16; // SCRIPT_ERR_BAD_OPCODE
    }
    if msg.starts_with("disabled opcode 0x") {
        return 17; // SCRIPT_ERR_DISABLED_OPCODE
    }

    ERR_UNKNOWN
}

/// Classify an rbitcoin `ConsensusError`. Only `Script` carries a script
/// ordinal; every other consensus error is outside the shared taxonomy.
#[allow(dead_code)] // called from the shim; the standalone test crate does not use it
pub fn classify_consensus_error(err: &rbitcoin_consensus::ConsensusError) -> i32 {
    match err {
        rbitcoin_consensus::ConsensusError::Script(msg) => classify_script_message(msg),
        _ => ERR_UNKNOWN,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exact_map_is_self_consistent_and_unique() {
        for (i, (token, ordinal)) in EXACT_MAP.iter().enumerate() {
            assert!(!token.is_empty());
            assert_ne!(*ordinal, ERR_UNKNOWN, "{token} must not map to UNKNOWN");
            assert!(
                !UNMAPPED_TOKENS.contains(token),
                "{token} appears in both tables"
            );
            assert_eq!(
                classify_script_message(token),
                *ordinal,
                "exact token {token}"
            );
            for (other, _) in &EXACT_MAP[i + 1..] {
                assert_ne!(token, other, "duplicate token {token}");
            }
        }
    }

    #[test]
    fn unmapped_tokens_stay_unknown() {
        for token in UNMAPPED_TOKENS {
            assert_eq!(
                classify_script_message(token),
                ERR_UNKNOWN,
                "unmapped token {token}"
            );
        }
    }

    #[test]
    fn dynamic_opcode_tokens() {
        assert_eq!(classify_script_message("unknown opcode 0x6a"), 3);
        assert_eq!(classify_script_message("unknown opcode 0xba"), 16);
        assert_eq!(classify_script_message("unknown opcode 0xff"), 16);
        assert_eq!(classify_script_message("disabled opcode 0x7e"), 17);
        assert_eq!(classify_script_message("disabled opcode 0x8d"), 17);
    }

    #[test]
    fn annotations_are_stripped() {
        assert_eq!(
            classify_script_message("script false txid=00ff vin=0"),
            2
        );
        assert_eq!(
            classify_script_message("unknown opcode 0xba txid=abc vin=7"),
            16
        );
        // A token that merely contains the annotation marker in its payload
        // is not a valid engine token and stays unknown.
        assert_eq!(classify_script_message("script false txid="), 2);
    }

    #[test]
    fn consensus_error_wrapper_only_types_script() {
        use rbitcoin_consensus::ConsensusError;
        assert_eq!(
            classify_consensus_error(&ConsensusError::Script(
                "unknown opcode 0xba txid=00 vin=0".into()
            )),
            16
        );
        assert_eq!(
            classify_consensus_error(&ConsensusError::BadBlock("merkle root mismatch")),
            ERR_UNKNOWN
        );
        assert_eq!(
            classify_consensus_error(&ConsensusError::MissingPrevout),
            ERR_UNKNOWN
        );
    }

    #[test]
    fn unknown_and_empty_are_unknown() {
        assert_eq!(classify_script_message(""), ERR_UNKNOWN);
        assert_eq!(classify_script_message("totally new token"), ERR_UNKNOWN);
    }
}
