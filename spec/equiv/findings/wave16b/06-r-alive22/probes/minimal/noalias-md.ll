define i8 @src(ptr align 1 %p) {
  %v = load i8, ptr %p, align 1, !alias.scope !0, !noalias !3
  ret i8 %v
}
define i8 @tgt(ptr align 1 %p) {
  %v = load i8, ptr %p, align 1, !alias.scope !0, !noalias !3
  ret i8 %v
}
!0 = !{!0}
!3 = !{!3}
