define i8 @src(ptr captures(address) align 1 %p) {
  %v = load i8, ptr %p, align 1
  ret i8 %v
}
define i8 @tgt(ptr captures(address) align 1 %p) {
  %v = load i8, ptr %p, align 1
  ret i8 %v
}
