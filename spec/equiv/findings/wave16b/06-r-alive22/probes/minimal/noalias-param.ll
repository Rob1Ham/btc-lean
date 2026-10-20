define i8 @src(ptr noalias %p) {
  %v = load i8, ptr %p, align 1
  ret i8 %v
}
define i8 @tgt(ptr noalias %p) {
  %v = load i8, ptr %p, align 1
  ret i8 %v
}
