; reverse direction: src has no post-call store, tgt adds one -> must NOT refine
declare void @f(ptr dead_on_return)

define void @src() {
  %p = alloca i8
  call void @f(ptr dead_on_return %p)
  ret void
}

define void @tgt() {
  %p = alloca i8
  call void @f(ptr dead_on_return %p)
  store i8 0, ptr %p
  ret void
}
