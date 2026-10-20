; ModuleID = '/tmp/opencode/wave16/13-policy-reimport/spec/equiv/cells/policy-flags/C-L-minimaldata-push/build/c_cell_minimaldata_push.bc'
source_filename = "/tmp/opencode/wave16/13-policy-reimport/spec/equiv/cells/policy-flags/C-L-minimaldata-push/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 26) i64 @cell_minimaldata_push(i64 noundef %flags, i64 noundef %fExec, i64 noundef %opcode, i64 noundef %dataLen, i64 noundef %b0Arg) local_unnamed_addr #0 {
entry:
  %and.i.i = and i64 %b0Arg, 255
  %cmp.i = icmp ne i64 %fExec, 0
  %cmp1.i = icmp ult i64 %opcode, 79
  %or.cond.i = and i1 %cmp.i, %cmp1.i
  br i1 %or.cond.i, label %if.then.i, label %_Z18c_minimaldata_pushmmmmm.exit

if.then.i:                                        ; preds = %entry
  %cmp2.i = icmp eq i64 %dataLen, 0
  br i1 %cmp2.i, label %if.then3.i, label %if.else.i

if.then3.i:                                       ; preds = %if.then.i
  %cmp4.i = icmp eq i64 %opcode, 0
  br label %if.end36.i

if.else.i:                                        ; preds = %if.then.i
  %cmp5.i = icmp eq i64 %dataLen, 1
  %cmp7.i = icmp ne i64 %and.i.i, 0
  %or.cond43.i = and i1 %cmp5.i, %cmp7.i
  %cmp9.i = icmp samesign ult i64 %and.i.i, 17
  %or.cond44.i = select i1 %or.cond43.i, i1 %cmp9.i, i1 false
  %cmp14.i = icmp eq i64 %and.i.i, 129
  %or.cond45.i = and i1 %cmp5.i, %cmp14.i
  %or.cond58.i = or i1 %or.cond45.i, %or.cond44.i
  br i1 %or.cond58.i, label %if.end36.i, label %if.else16.i

if.else16.i:                                      ; preds = %if.else.i
  %cmp17.i = icmp ult i64 %dataLen, 76
  br i1 %cmp17.i, label %if.then18.i, label %if.else21.i

if.then18.i:                                      ; preds = %if.else16.i
  %cmp19.i = icmp eq i64 %opcode, %dataLen
  br label %if.end36.i

if.else21.i:                                      ; preds = %if.else16.i
  %cmp22.i = icmp ult i64 %dataLen, 256
  br i1 %cmp22.i, label %if.then23.i, label %if.else26.i

if.then23.i:                                      ; preds = %if.else21.i
  %cmp24.i = icmp eq i64 %opcode, 76
  br label %if.end36.i

if.else26.i:                                      ; preds = %if.else21.i
  %cmp27.i = icmp ugt i64 %dataLen, 65535
  %cmp29.i = icmp eq i64 %opcode, 77
  %spec.select.i = or i1 %cmp29.i, %cmp27.i
  br label %if.end36.i

if.end36.i:                                       ; preds = %if.else26.i, %if.then23.i, %if.then18.i, %if.else.i, %if.then3.i
  %ok.0.shrunk.i = phi i1 [ %cmp4.i, %if.then3.i ], [ %cmp19.i, %if.then18.i ], [ %cmp24.i, %if.then23.i ], [ false, %if.else.i ], [ %spec.select.i, %if.else26.i ]
  %and.i = and i64 %flags, 64
  %cmp37.not.i = icmp eq i64 %and.i, 0
  %brmerge.i = or i1 %cmp37.not.i, %ok.0.shrunk.i
  %spec.select59.i = select i1 %brmerge.i, i64 0, i64 25
  br label %_Z18c_minimaldata_pushmmmmm.exit

_Z18c_minimaldata_pushmmmmm.exit:                 ; preds = %entry, %if.end36.i
  %retval.1.i = phi i64 [ 0, %entry ], [ %spec.select59.i, %if.end36.i ]
  ret i64 %retval.1.i
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
