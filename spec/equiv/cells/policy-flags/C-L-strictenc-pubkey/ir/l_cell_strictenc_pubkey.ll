; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/policy-flags/C-L-strictenc-pubkey/build/l_cell_strictenc_pubkey.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/policy-flags/C-L-strictenc-pubkey/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 30) i64 @cell_strictenc_pubkey(i64 noundef %flags, i64 noundef %pkLen, i64 noundef %pk0) local_unnamed_addr #0 {
entry:
  %cmp.i = icmp ult i64 %pkLen, 33
  br i1 %cmp.i, label %_Z18l_strictenc_pubkeymmm.exit, label %if.else.i

if.else.i:                                        ; preds = %entry
  %and.i.i = and i64 %pk0, 255
  %cmp1.i = icmp eq i64 %and.i.i, 4
  br i1 %cmp1.i, label %if.then2.i, label %if.else4.i

if.then2.i:                                       ; preds = %if.else.i
  %cmp3.i = icmp eq i64 %pkLen, 65
  br label %_Z18l_strictenc_pubkeymmm.exit

if.else4.i:                                       ; preds = %if.else.i
  %0 = and i64 %pk0, 254
  %or.cond.i = icmp eq i64 %0, 2
  %cmp8.i = icmp eq i64 %pkLen, 33
  %spec.select.i = and i1 %cmp8.i, %or.cond.i
  br label %_Z18l_strictenc_pubkeymmm.exit

_Z18l_strictenc_pubkeymmm.exit:                   ; preds = %entry, %if.then2.i, %if.else4.i
  %enc_ok.0.shrunk.i = phi i1 [ %cmp3.i, %if.then2.i ], [ false, %entry ], [ %spec.select.i, %if.else4.i ]
  %and.i = and i64 %flags, 2
  %cmp13.not.i = icmp eq i64 %and.i, 0
  %brmerge.i = or i1 %cmp13.not.i, %enc_ok.0.shrunk.i
  %retval.0.i = select i1 %brmerge.i, i64 0, i64 29
  ret i64 %retval.0.i
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
