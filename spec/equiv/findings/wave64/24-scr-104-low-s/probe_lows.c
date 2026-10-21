/* Runtime probe for the LOW_S numeric seam at Core cce32b168.
 *
 * It links the pinned libsecp256k1 source and calls Core's
 * ecdsa_signature_parse_der_lax (copied verbatim from src/pubkey.cpp:45-193)
 * followed by secp256k1_ecdsa_signature_normalize, exactly as
 * CPubKey::CheckLowS does (src/pubkey.cpp:393-399).  IsValidSignatureEncoding
 * (src/script/interpreter.cpp:118-180) is copied verbatim to show that each
 * witness reaches CheckLowS through the BIP66 gate.
 *
 * The two Lean-side predicates are printed for comparison:
 *   Defs.checkLowS : raw S (as read by byte offset) <= floor(n/2)
 *   Der.isLowDERSignature : (S % n) <= floor(n/2)
 * with S read after the same leading-zero stripping that parse_der_lax does.
 *
 * Build: see README.md.  This is a witness/probe, not part of the cell proof.
 */
#include <stdio.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include "secp256k1.h"

/* ---- verbatim Core ecdsa_signature_parse_der_lax (pubkey.cpp:45-193) ---- */
int ecdsa_signature_parse_der_lax(secp256k1_ecdsa_signature* sig, const unsigned char *input, size_t inputlen) {
    size_t rpos, rlen, spos, slen;
    size_t pos = 0;
    size_t lenbyte;
    unsigned char tmpsig[64] = {0};
    int overflow = 0;

    /* Hack to initialize sig with a correctly-parsed but invalid signature. */
    secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, sig, tmpsig);

    /* Sequence tag byte */
    if (pos == inputlen || input[pos] != 0x30) {
        return 0;
    }
    pos++;

    /* Sequence length bytes */
    if (pos == inputlen) {
        return 0;
    }
    lenbyte = input[pos++];
    if (lenbyte & 0x80) {
        lenbyte -= 0x80;
        if (lenbyte > inputlen - pos) {
            return 0;
        }
        pos += lenbyte;
    }

    /* Integer tag byte for R */
    if (pos == inputlen || input[pos] != 0x02) {
        return 0;
    }
    pos++;

    /* Integer length for R */
    if (pos == inputlen) {
        return 0;
    }
    lenbyte = input[pos++];
    if (lenbyte & 0x80) {
        lenbyte -= 0x80;
        if (lenbyte > inputlen - pos) {
            return 0;
        }
        while (lenbyte > 0 && input[pos] == 0) {
            pos++;
            lenbyte--;
        }
        if (lenbyte >= 4) {
            return 0;
        }
        rlen = 0;
        while (lenbyte > 0) {
            rlen = (rlen << 8) + input[pos];
            pos++;
            lenbyte--;
        }
    } else {
        rlen = lenbyte;
    }
    if (rlen > inputlen - pos) {
        return 0;
    }
    rpos = pos;
    pos += rlen;

    /* Integer tag byte for S */
    if (pos == inputlen || input[pos] != 0x02) {
        return 0;
    }
    pos++;

    /* Integer length for S */
    if (pos == inputlen) {
        return 0;
    }
    lenbyte = input[pos++];
    if (lenbyte & 0x80) {
        lenbyte -= 0x80;
        if (lenbyte > inputlen - pos) {
            return 0;
        }
        while (lenbyte > 0 && input[pos] == 0) {
            pos++;
            lenbyte--;
        }
        if (lenbyte >= 4) {
            return 0;
        }
        slen = 0;
        while (lenbyte > 0) {
            slen = (slen << 8) + input[pos];
            pos++;
            lenbyte--;
        }
    } else {
        slen = lenbyte;
    }
    if (slen > inputlen - pos) {
        return 0;
    }
    spos = pos;

    /* Ignore leading zeroes in R */
    while (rlen > 0 && input[rpos] == 0) {
        rlen--;
        rpos++;
    }
    /* Copy R value */
    if (rlen > 32) {
        overflow = 1;
    } else {
        memcpy(tmpsig + 32 - rlen, input + rpos, rlen);
    }

    /* Ignore leading zeroes in S */
    while (slen > 0 && input[spos] == 0) {
        slen--;
        spos++;
    }
    /* Copy S value */
    if (slen > 32) {
        overflow = 1;
    } else {
        memcpy(tmpsig + 64 - slen, input + spos, slen);
    }

    if (!overflow) {
        overflow = !secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, sig, tmpsig);
    }
    if (overflow) {
        memset(tmpsig, 0, 64);
        secp256k1_ecdsa_signature_parse_compact(secp256k1_context_static, sig, tmpsig);
    }
    return 1;
}

/* ---- verbatim Core IsValidSignatureEncoding (interpreter.cpp:118-180) ---- */
static bool IsValidSignatureEncoding(const unsigned char sig[], size_t size) {
    if (size < 9 || size > 73) return false;
    if (sig[0] != 0x30) return false;
    if (sig[1] != size - 3) return false;
    unsigned int lenR = sig[3];
    if (5 + lenR >= size) return false;
    unsigned int lenS = sig[5 + lenR];
    if ((size_t)(lenR + lenS + 7) != size) return false;
    if (sig[2] != 0x02) return false;
    if (lenR == 0) return false;
    if (sig[4] & 0x80) return false;
    if (lenR > 1 && (sig[4] == 0x00) && !(sig[5] & 0x80)) return false;
    if (sig[lenR + 4] != 0x02) return false;
    if (lenS == 0) return false;
    if (sig[lenR + 6] & 0x80) return false;
    if (lenS > 1 && (sig[lenR + 6] == 0x00) && !(sig[lenR + 7] & 0x80)) return false;
    return true;
}

static int hexval(char c) {
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

int main(int argc, char** argv) {
    if (argc != 2) { fprintf(stderr, "usage: %s SIGHEX\n", argv[0]); return 2; }
    unsigned char sig[128]; size_t n = 0;
    for (size_t i = 0; argv[1][i] && argv[1][i+1]; i += 2) {
        int h = hexval(argv[1][i]), l = hexval(argv[1][i+1]);
        if (h < 0 || l < 0) { fprintf(stderr, "bad hex\n"); return 2; }
        sig[n++] = (unsigned char)((h << 4) | l);
    }
    bool bip66 = IsValidSignatureEncoding(sig, n);
    secp256k1_ecdsa_signature parsed;
    int parse_ok = ecdsa_signature_parse_der_lax(&parsed, sig, n - 1); /* drop hashtype */
    int high = secp256k1_ecdsa_signature_normalize(secp256k1_context_static, NULL, &parsed);
    /* Normalize's return is 1 iff S is high, so Core CheckLowS == !high. */
    printf("sig=%s bytes=%zu bip66=%d parse_ok=%d check_lows=%d\n",
           argv[1], n, bip66 ? 1 : 0, parse_ok, high ? 0 : 1);
    return 0;
}
