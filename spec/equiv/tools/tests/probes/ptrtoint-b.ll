define i64 @f(ptr %p) {
  %q = ptrtoint ptr %p to i64
  %r = add i64 %q, 0
  ret i64 %r
}
