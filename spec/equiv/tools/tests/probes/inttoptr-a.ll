define ptr @f(ptr %p) {
  %i = ptrtoint ptr %p to i64
  %q = inttoptr i64 %i to ptr
  ret ptr %q
}
