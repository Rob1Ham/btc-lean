define i32 @f(i32 %n) {
entry:
  %m = sub i32 %n, 1
  %p = mul i32 %n, %m
  %r = lshr i32 %p, 1
  ret i32 %r
}
