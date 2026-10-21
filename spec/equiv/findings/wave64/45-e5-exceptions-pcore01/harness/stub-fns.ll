; Executable single-threaded Itanium __cxa_guard_* protocol (probe stub).
define i32 @__cxa_guard_acquire(ptr %g) {
  %v = load i8, ptr %g, align 1
  %z = icmp eq i8 %v, 0
  %r = zext i1 %z to i32
  ret i32 %r
}
define void @__cxa_guard_release(ptr %g) {
  store i8 1, ptr %g, align 1
  ret void
}
define void @__cxa_guard_abort(ptr %g) { ret void }
define i32 @__cxa_atexit(ptr %f, ptr %a, ptr %d) { ret i32 0 }
