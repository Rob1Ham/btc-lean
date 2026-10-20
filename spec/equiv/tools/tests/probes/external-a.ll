declare i32 @ext(i32)

define i32 @f(i32 %x) {
  %r = call i32 @ext(i32 %x)
  %s = add i32 %r, 1
  ret i32 %s
}
