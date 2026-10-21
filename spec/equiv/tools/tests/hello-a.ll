; E0 hello-world: source module
define i32 @add_one(i32 %x) {
entry:
  %r = add i32 %x, 1
  ret i32 %r
}

define i32 @abs_val(i32 %x) {
entry:
  %neg = icmp slt i32 %x, 0
  %y = sub i32 0, %x
  %r = select i1 %neg, i32 %y, i32 %x
  ret i32 %r
}
