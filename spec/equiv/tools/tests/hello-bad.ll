; E0 negative control: NOT equivalent to hello-a.ll
define i32 @add_one(i32 %x) {
entry:
  %r = add i32 %x, 2
  ret i32 %r
}
