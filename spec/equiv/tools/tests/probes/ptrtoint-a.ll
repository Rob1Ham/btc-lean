define i64 @f(ptr %p) {
  %r = ptrtoint ptr %p to i64
  ret i64 %r
}
