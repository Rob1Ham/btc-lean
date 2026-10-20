; wave16b/03-e5-heap -- bounded explicit-failure allocator model.
;
; PURPOSE.  Replace the external allocator symbols reached from EvalScript
; (`_Znwm`, `_ZdlPv`, and the prevector `malloc`/`free`/`realloc` triple) with a
; concrete, inspectable model so that SAW can symbolically execute the first
; `std::vector` growth.  The model is a bump arena over one global array.
; It NEVER pretends allocation cannot fail:
;
;   * `wave16b_raw_alloc` returns null when the request does not fit.
;   * `_Znwm` (C++ operator new) has the C++ contract: on failure it does NOT
;     return null; it calls `_ZSt17__throw_bad_allocv`, which is deliberately
;     left as an EXTERNAL.  If a probe ever reaches the failure branch SAW will
;     report "No implementation or override found" for that symbol, i.e. the
;     failure path is visible and remains an obligation.
;   * `malloc` returns null on failure, as C requires.
;   * `free` is a no-op (leak), stated as an abstraction below.
;
; NOT A LIBC.  This is a prototype heap abstraction, not a proof of glibc.
; The refinement obligation is recorded in README.md: the model must be shown
; to implement the abstract allocator contract (disjoint live blocks of at
; least the requested size, aligned, null/failure observable) and the analysed
; execution must stay inside the arena.
;
; Layout chosen so that no ptrtoint/inttoptr is needed:
;   * raw blocks are 16-byte aligned, distinct even for size 0 (>=1 byte bump);
;   * malloc blocks carry a 16-byte header holding the requested size, so
;     realloc can recover it without malloc_usable_size.
;
; Build: clang++-20 -O0 -S -emit-llvm  (see build/build-heap-probe.sh), then
; llvm-link with the engine probe module.

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

@wave16b_heap = dso_local global [67108864 x i8] zeroinitializer, align 16
@wave16b_off = dso_local global i64 0, align 8
@wave16b_alloc_calls = dso_local global i64 0, align 8
@wave16b_first_n = dso_local global i64 0, align 8
@wave16b_last_n = dso_local global i64 0, align 8

declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg)
declare void @_ZSt17__throw_bad_allocv() noreturn

; ---------------------------------------------------------------------------
; raw bump allocation: 16-byte aligned, never the same address twice
; ---------------------------------------------------------------------------
define dso_local ptr @wave16b_raw_alloc(i64 %n) {
entry:
  %off = load i64, ptr @wave16b_off, align 8
  %rounded = add i64 %off, 15
  %aligned = and i64 %rounded, -16
  ; at least one byte per allocation keeps distinct live objects distinct
  %sz = add i64 %n, 1
  ; n >= CAP also covers the n = 2^64-1 wrap of %sz
  %toobig = icmp uge i64 %n, 67108864
  %room = sub i64 67108864, %sz
  %noroom = icmp ugt i64 %aligned, %room
  %fail = or i1 %toobig, %noroom
  %need = add i64 %aligned, %sz
  br i1 %fail, label %failbb, label %okbb

okbb:
  %p = getelementptr inbounds i8, ptr @wave16b_heap, i64 %aligned
  store i64 %need, ptr @wave16b_off, align 8
  %calls = load i64, ptr @wave16b_alloc_calls, align 8
  %isfirst = icmp eq i64 %calls, 0
  br i1 %isfirst, label %first, label %afterfirst

first:
  store i64 %n, ptr @wave16b_first_n, align 8
  br label %afterfirst

afterfirst:
  store i64 %n, ptr @wave16b_last_n, align 8
  %calls1 = add i64 %calls, 1
  store i64 %calls1, ptr @wave16b_alloc_calls, align 8
  ret ptr %p

failbb:
  ret ptr null
}

; ---------------------------------------------------------------------------
; C++ operator new / delete (the first symbol EvalScript reaches)
; ---------------------------------------------------------------------------
define dso_local noalias noundef nonnull ptr @_Znwm(i64 noundef %n) {
entry:
  %p = call ptr @wave16b_raw_alloc(i64 %n)
  %isnull = icmp eq ptr %p, null
  br i1 %isnull, label %fail, label %ok

fail:
  ; C++ contract: operator new reports failure by throwing, never by null.
  call void @_ZSt17__throw_bad_allocv()
  unreachable

ok:
  ret ptr %p
}

define dso_local void @_ZdlPv(ptr noundef %p) {
entry:
  ; no-op: bump arena does not recycle.  Leak is intentional and bounded by
  ; the number of allocations on the analysed path.
  ret void
}

; sized delete: same no-op
define dso_local void @_ZdlPvm(ptr noundef %p, i64 noundef %n) {
entry:
  ret void
}

; ---------------------------------------------------------------------------
; C allocator
; ---------------------------------------------------------------------------
define dso_local noalias ptr @malloc(i64 noundef %n) {
entry:
  %ovf = icmp ugt i64 %n, 67108848
  br i1 %ovf, label %retnull, label %alloc

alloc:
  %sz = add i64 %n, 16
  %p = call ptr @wave16b_raw_alloc(i64 %sz)
  %isnull = icmp eq ptr %p, null
  br i1 %isnull, label %retnull, label %hdr

hdr:
  store i64 %n, ptr %p, align 8
  %q = getelementptr inbounds i8, ptr %p, i64 16
  ret ptr %q

retnull:
  ret ptr null
}

define dso_local void @free(ptr %p) {
entry:
  ; no-op (see _ZdlPv); null is accepted, as C requires
  ret void
}

define dso_local ptr @realloc(ptr %p, i64 noundef %n) {
entry:
  %isnull = icmp eq ptr %p, null
  br i1 %isnull, label %domalloc, label %copy

domalloc:
  %m = call ptr @malloc(i64 %n)
  ret ptr %m

copy:
  %oldp = getelementptr inbounds i8, ptr %p, i64 -16
  %old = load i64, ptr %oldp, align 8
  %newp = call ptr @malloc(i64 %n)
  %newnull = icmp eq ptr %newp, null
  br i1 %newnull, label %retnull, label %docopy

docopy:
  %take = icmp ult i64 %old, %n
  %cn = select i1 %take, i64 %old, i64 %n
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %newp, ptr align 1 %p, i64 %cn, i1 false)
  ret ptr %newp

retnull:
  ret ptr null
}
