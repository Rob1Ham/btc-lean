@fp = global ptr @inc

define i32 @inc(i32 %x) {
  %r = add i32 %x, 1
  ret i32 %r
}

define i32 @f(i32 %x) {
  %p = load ptr, ptr @fp
  %r = call i32 %p(i32 %x)
  ret i32 %r
}
