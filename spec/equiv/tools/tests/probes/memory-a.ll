define i32 @f(ptr %p, i32 %v) {
  store i32 %v, ptr %p
  %r = load i32, ptr %p
  ret i32 %r
}
