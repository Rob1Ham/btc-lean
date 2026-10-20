; ModuleID = '/tmp/opencode/wave64/64-policy-low-s-codesep/spec/equiv/cells/policy-flags/C-L-flag-source/build/l_leaf.bc'
source_filename = "/tmp/opencode/wave64/64-policy-low-s-codesep/spec/equiv/cells/policy-flags/C-L-flag-source/l_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 135168) i64 @_Z13l_flag_sourcemm(i64 noundef %exceptionKind, i64 noundef %height) local_unnamed_addr #0 {
entry:
  %0 = add i64 %exceptionKind, -3
  %or.cond.i = icmp ult i64 %0, -2
  %cond16.i = select i1 %or.cond.i, i64 131072, i64 0
  %.not = icmp eq i64 %exceptionKind, 1
  %retval.i.sroa.14.0 = select i1 %.not, i64 0, i64 2048
  %narrow = icmp ne i64 %exceptionKind, 1
  %retval.i.sroa.0.0 = zext i1 %narrow to i64
  %rem = and i64 %height, 4294967295
  %cmp.i16 = icmp samesign ugt i64 %rem, 363724
  %cmp.i15 = icmp samesign ugt i64 %rem, 388380
  %cmp.i14 = icmp samesign ugt i64 %rem, 419327
  %cmp.i = icmp samesign ugt i64 %rem, 481823
  %cond2.i = select i1 %cmp.i16, i64 4, i64 0
  %cond4.i = select i1 %cmp.i, i64 16, i64 0
  %cond7.i = select i1 %cmp.i15, i64 512, i64 0
  %cond10.i = select i1 %cmp.i14, i64 1024, i64 0
  %or.i = or disjoint i64 %retval.i.sroa.14.0, %retval.i.sroa.0.0
  %or5.i = or disjoint i64 %or.i, %cond16.i
  %or8.i = or disjoint i64 %or5.i, %cond2.i
  %or11.i = or disjoint i64 %or8.i, %cond4.i
  %or14.i = or disjoint i64 %or11.i, %cond7.i
  %or17.i = or i64 %or14.i, %cond10.i
  ret i64 %or17.i
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 65545) i64 @_Z25l_flag_source_policy_maskmm(i64 noundef %exceptionKind, i64 noundef %height) local_unnamed_addr #0 {
entry:
  ret i64 0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef i64 @_Z22l_standard_policy_maskv() local_unnamed_addr #0 {
entry:
  ret i64 65544
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 65545) i64 @_Z23l_mandatory_policy_maskv() local_unnamed_addr #0 {
entry:
  ret i64 0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 135168) i64 @cell_flag_source(i64 noundef %exceptionKind, i64 noundef %height) local_unnamed_addr #0 {
entry:
  %0 = add i64 %exceptionKind, -3
  %or.cond.i.i = icmp ult i64 %0, -2
  %cond16.i.i = select i1 %or.cond.i.i, i64 131072, i64 0
  %.not.i = icmp eq i64 %exceptionKind, 1
  %retval.i.sroa.14.0.i = select i1 %.not.i, i64 0, i64 2048
  %narrow.i = icmp ne i64 %exceptionKind, 1
  %retval.i.sroa.0.0.i = zext i1 %narrow.i to i64
  %rem.i = and i64 %height, 4294967295
  %cmp.i16.i = icmp samesign ugt i64 %rem.i, 363724
  %cmp.i15.i = icmp samesign ugt i64 %rem.i, 388380
  %cmp.i14.i = icmp samesign ugt i64 %rem.i, 419327
  %cmp.i.i = icmp samesign ugt i64 %rem.i, 481823
  %cond2.i.i = select i1 %cmp.i16.i, i64 4, i64 0
  %cond4.i.i = select i1 %cmp.i.i, i64 16, i64 0
  %cond7.i.i = select i1 %cmp.i15.i, i64 512, i64 0
  %cond10.i.i = select i1 %cmp.i14.i, i64 1024, i64 0
  %or.i.i = or disjoint i64 %retval.i.sroa.14.0.i, %retval.i.sroa.0.0.i
  %or5.i.i = or disjoint i64 %or.i.i, %cond16.i.i
  %or8.i.i = or disjoint i64 %or5.i.i, %cond2.i.i
  %or11.i.i = or disjoint i64 %or8.i.i, %cond4.i.i
  %or14.i.i = or disjoint i64 %or11.i.i, %cond7.i.i
  %or17.i.i = or i64 %or14.i.i, %cond10.i.i
  ret i64 %or17.i.i
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 25) i64 @_Z17l_lows_gate_blockmmmmmmm(i64 noundef %exceptionKind, i64 noundef %height, i64 noundef %rByte, i64 noundef %s0, i64 noundef %s1, i64 noundef %s2, i64 noundef %s3) local_unnamed_addr #0 {
entry:
  %and = and i64 %rByte, 128
  %cmp = icmp eq i64 %and, 0
  %0 = icmp sgt i64 %s0, 36028797018963967
  %spec.select = and i1 %cmp, %0
  %rem.i = and i64 %height, 4294967295
  %cmp.i16.i = icmp samesign ult i64 %rem.i, 363725
  %brmerge48 = or i1 %cmp.i16.i, %spec.select
  %retval.0 = select i1 %brmerge48, i64 0, i64 24
  ret i64 %retval.0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 256) i64 @_Z18l_const_gate_blockmmmmm(i64 noundef %exceptionKind, i64 noundef %height, i64 noundef %sigversion, i64 noundef %opcode, i64 noundef %foundPositive) local_unnamed_addr #0 {
entry:
  %cmp = icmp ugt i64 %foundPositive, 1
  %retval.1 = select i1 %cmp, i64 255, i64 0
  ret i64 %retval.1
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 25) i64 @cell_lows_gate_block(i64 noundef %exceptionKind, i64 noundef %height, i64 noundef %rByte, i64 noundef %s0, i64 noundef %s1, i64 noundef %s2, i64 noundef %s3) local_unnamed_addr #0 {
entry:
  %and.i = and i64 %rByte, 128
  %cmp.i = icmp eq i64 %and.i, 0
  %0 = icmp sgt i64 %s0, 36028797018963967
  %spec.select.i = and i1 %cmp.i, %0
  %rem.i.i = and i64 %height, 4294967295
  %cmp.i16.i.i = icmp samesign ult i64 %rem.i.i, 363725
  %brmerge48.i = or i1 %cmp.i16.i.i, %spec.select.i
  %retval.0.i = select i1 %brmerge48.i, i64 0, i64 24
  ret i64 %retval.0.i
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 256) i64 @cell_const_gate_block(i64 noundef %exceptionKind, i64 noundef %height, i64 noundef %sigversion, i64 noundef %opcode, i64 noundef %foundPositive) local_unnamed_addr #0 {
entry:
  %cmp.i = icmp ugt i64 %foundPositive, 1
  %retval.1.i = select i1 %cmp.i, i64 255, i64 0
  ret i64 %retval.1.i
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 65545) i64 @cell_flag_source_policy_mask(i64 noundef %exceptionKind, i64 noundef %height) local_unnamed_addr #0 {
entry:
  ret i64 0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef i64 @cell_standard_policy_mask() local_unnamed_addr #0 {
entry:
  ret i64 65544
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 65545) i64 @cell_mandatory_policy_mask() local_unnamed_addr #0 {
entry:
  ret i64 0
}

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }

!llvm.module.flags = !{!0, !1, !2, !3}
!llvm.ident = !{!4}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
