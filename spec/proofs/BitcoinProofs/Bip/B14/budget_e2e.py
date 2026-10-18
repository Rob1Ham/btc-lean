#!/usr/bin/env python3
"""B14 — full-stack simulation of the 3-sigop tapscript budget pair,
mirroring the tapscript machine (head=top; BIP342 budget = 50 + serialized witness)."""
def decode_num(b):  # minimal LE scriptnum (all our nums are 1-byte)
    return int.from_bytes(b, "little") if b else 0

def run(items, script, vw_ser):
    # budget seeded by ExecuteWitnessScript: vwSer + VALIDATION_WEIGHT_OFFSET(50)
    vw = vw_ser + 50
    st = list(reversed(items))  # machine stack, head = TOP
    pc = 0
    while pc < len(script):
        w = script[pc]; pc += 1
        if w == 0x21:            # push 33 bytes
            st.insert(0, script[pc:pc+33]); pc += 33
        elif w in (0x51, 0x52, 0x53):  # OP_1/2/3
            st.insert(0, bytes([w - 0x50]))
        elif w == 0xac:          # CHECKSIG (stub verify: nonempty sig+pk -> True)
            pk, sig = st.pop(0), st.pop(0)
            if len(sig) == 0:
                st.insert(0, b"")
                continue
            vw -= 50
            if vw < 0: return ("FAIL", "TAPSCRIPT_VALIDATION_WEIGHT", vw)
            st.insert(0, b"\x01")
        elif w == 0xba:          # CHECKSIGADD
            pk, num, sig = st.pop(0), st.pop(0), st.pop(0)
            n = decode_num(num)
            if len(sig) != 0:
                vw -= 50
                if vw < 0: return ("FAIL", "TAPSCRIPT_VALIDATION_WEIGHT", vw)
                n += 1
            st.insert(0, n.to_bytes(1, "little"))
        elif w == 0x9c:          # NUMEQUAL
            a, b = st.pop(0), st.pop(0)
            st.insert(0, b"\x01" if a == b else b"")
        else:
            return ("FAIL", "BAD_OPCODE", vw)
    if len(st) != 1: return ("FAIL", "CLEANSTACK", vw)
    return ("OK", st[0].hex(), vw)

sig = bytes([0xab]*64)
pk  = bytes([0x11]*33)
script = bytes([0x21]) + pk + bytes([0xac]) + bytes([0x21]) + pk + bytes([0xba]) \
       + bytes([0x21]) + pk + bytes([0xba, 0x53, 0x9c])
items = [sig, sig, sig]
print("vwSer=100:", run(items, script, 100))   # expect OK, budget lands exactly 0
print("vwSer= 99:", run(items, script, 99))    # expect FAIL below zero
print("vwSer=  0:", run(items, script, 0))     # expect FAIL below zero (2nd sigop)
