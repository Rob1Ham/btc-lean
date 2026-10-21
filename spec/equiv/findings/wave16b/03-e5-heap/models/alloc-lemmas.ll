; wave16b/03-e5-heap -- proof lemmas about the bounded allocator model.
;
; These wrappers exist so SAW can state and prove properties of the model
; itself.  They are NOT part of the engine probe module.
;
;   w16b_lemma_nonnull    : request n in [1,4096] on a fresh arena succeeds
;   w16b_lemma_oversize   : request n > arena capacity returns null
;   w16b_lemma_disjoint   : two successful requests get distinct addresses
;
; All three avoid ptrtoint/inttoptr; comparisons are pointer compares.
; Note: "success" here means "the MODEL does not return a failure"; that is a
; property of the abstraction, not a claim about glibc.

target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

declare ptr @wave16b_raw_alloc(i64)
declare ptr @_Znwm(i64)

define i1 @w16b_lemma_nonnull(i64 %n) {
entry:
  %p = call ptr @wave16b_raw_alloc(i64 %n)
  %c = icmp ne ptr %p, null
  ret i1 %c
}

define i1 @w16b_lemma_oversize(i64 %n) {
entry:
  %p = call ptr @wave16b_raw_alloc(i64 %n)
  %c = icmp eq ptr %p, null
  ret i1 %c
}

define i1 @w16b_lemma_disjoint(i64 %a, i64 %b) {
entry:
  %p1 = call ptr @wave16b_raw_alloc(i64 %a)
  %p2 = call ptr @wave16b_raw_alloc(i64 %b)
  %n1 = icmp eq ptr %p1, null
  %n2 = icmp eq ptr %p2, null
  %bad = or i1 %n1, %n2
  br i1 %bad, label %ret0, label %cmp

cmp:
  %eq = icmp eq ptr %p1, %p2
  %ne = xor i1 %eq, true
  ret i1 %ne

ret0:
  ret i1 false
}

; failure disclosure: if the arena is already full, operator new must take its
; throw branch.  SAW must complain about the uninterpreted throw helper; a
; silent null return here would be a modelling bug.
define i64 @w16b_new_after_full() {
entry:
  %p = call ptr @_Znwm(i64 16)
  ret i64 0
}
