// wave65/27 -- proof harness: expose the *number of script bytes consumed* by
// the real `GetScriptOp` as an integer, so a SAW postcondition can state the
// loop ranking measure without a symbolic pointer index.
//
// The harness introduces NO parser logic: it constructs two real
// CScriptBase::const_iterator values from a raw buffer (prevector.h class
// const_iterator, a single pointer), calls the real `GetScriptOp` declared in
// script.h, and subtracts using the real `const_iterator::operator-`
// (prevector.h: `friend operator-(const_iterator a, const_iterator b)`).
// No container is constructed, so this path has no heap allocation.
//
// Return value: 0 if GetScriptOp returns false, else the consumed byte count.
// `*op` receives opcodeRet on success.
#include <script/script.h>
#include <cstdint>

extern "C" std::uint64_t w65_gso_consumed(const unsigned char* buf,
                                          std::uint32_t len,
                                          std::uint32_t* op)
{
    CScriptBase::const_iterator pc(buf);
    const CScriptBase::const_iterator begin(buf);
    const CScriptBase::const_iterator end(buf + len);
    opcodetype o = OP_INVALIDOPCODE;
    if (!GetScriptOp(pc, end, o, nullptr)) return 0;
    *op = static_cast<std::uint32_t>(o);
    return static_cast<std::uint64_t>(pc - begin);
}
