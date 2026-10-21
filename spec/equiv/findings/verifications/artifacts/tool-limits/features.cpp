#include <cstdint>
#include <stdexcept>

// exception edges (invoke/landingpad at -O0)
extern "C" int32_t ex_edges(int32_t x) {
  try { if (x < 0) throw std::runtime_error("neg"); return x + 1; }
  catch (...) { return -1; }
}

// indirect call through a function pointer
using fn = int32_t (*)(int32_t);
extern "C" int32_t indirect(fn f, int32_t x) { return f(x); }

// ptrtoint / inttoptr round-trip
extern "C" uintptr_t ptr_roundtrip(void* p) {
  uintptr_t v = reinterpret_cast<uintptr_t>(p);
  return reinterpret_cast<uintptr_t>(reinterpret_cast<void*>(v));
}
