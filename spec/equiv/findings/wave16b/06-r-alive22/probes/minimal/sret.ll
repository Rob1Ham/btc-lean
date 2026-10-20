define void @src(ptr sret([24 x i8]) align 8 %out) {
  store i64 0, ptr %out, align 8
  ret void
}
define void @tgt(ptr sret([24 x i8]) align 8 %out) {
  store i64 0, ptr %out, align 8
  ret void
}
