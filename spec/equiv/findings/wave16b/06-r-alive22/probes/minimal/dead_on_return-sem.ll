; src stores through the pointer AFTER the call returns -> dead_on_return violated -> UB
; tgt drops the store -> valid refinement (src UB allows anything)
declare void @f(ptr dead_on_return)

define void @src() {
  %p = alloca i8
  call void @f(ptr dead_on_return %p)
  store i8 0, ptr %p
  ret void
}

define void @tgt() {
  %p = alloca i8
  call void @f(ptr dead_on_return %p)
  ret void
}
