; ModuleID = '/tmp/opencode/wave64-integrate/spec/equiv/cells/policy-flags/C-L-flag-source/build/c_leaf.bc'
source_filename = "/tmp/opencode/wave64-integrate/spec/equiv/cells/policy-flags/C-L-flag-source/c_cell.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 135168) i64 @_Z13c_flag_sourcemm(i64 noundef %exceptionKind, i64 noundef %height) local_unnamed_addr #0 {
entry:
  %rem = and i64 %height, 4294967295
  %switch.selectcmp.i = icmp eq i64 %exceptionKind, 2
  %switch.select.i = select i1 %switch.selectcmp.i, i64 2049, i64 133121
  %switch.selectcmp27.i = icmp eq i64 %exceptionKind, 1
  %switch.select28.i = select i1 %switch.selectcmp27.i, i64 0, i64 %switch.select.i
  %cmp4.i = icmp samesign ugt i64 %rem, 363724
  %or.i = or disjoint i64 %switch.select28.i, 4
  %spec.select.i = select i1 %cmp4.i, i64 %or.i, i64 %switch.select28.i
  %cmp7.i = icmp samesign ugt i64 %rem, 388380
  %or9.i = or disjoint i64 %spec.select.i, 512
  %flags.2.i = select i1 %cmp7.i, i64 %or9.i, i64 %spec.select.i
  %cmp11.i = icmp samesign ugt i64 %rem, 419327
  %or13.i = or i64 %flags.2.i, 1024
  %flags.3.i = select i1 %cmp11.i, i64 %or13.i, i64 %flags.2.i
  %cmp15.i = icmp samesign ugt i64 %rem, 481823
  %or17.i = or i64 %flags.3.i, 16
  %flags.4.i = select i1 %cmp15.i, i64 %or17.i, i64 %flags.3.i
  ret i64 %flags.4.i
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 65545) i64 @_Z25c_flag_source_policy_maskmm(i64 noundef %exceptionKind, i64 noundef %height) local_unnamed_addr #0 {
entry:
  ret i64 0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef i64 @_Z22c_standard_policy_maskv() local_unnamed_addr #0 {
entry:
  ret i64 65544
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef i64 @_Z23c_mandatory_policy_maskv() local_unnamed_addr #0 {
entry:
  ret i64 0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 28) i64 @_Z17c_lows_gate_blockmmmmmmm(i64 noundef %exceptionKind, i64 noundef %height, i64 noundef %rByte, i64 noundef %s0, i64 noundef %s1, i64 noundef %s2, i64 noundef %s3) local_unnamed_addr #0 {
entry:
  %and = and i64 %rByte, 128
  %cmp = icmp eq i64 %and, 0
  %0 = icmp sgt i64 %s0, 36028797018963967
  %spec.select = and i1 %cmp, %0
  %rem = and i64 %height, 4294967295
  %cmp4.i = icmp samesign ult i64 %rem, 363725
  %brmerge = or i1 %spec.select, %cmp4.i
  %retval.0 = select i1 %brmerge, i64 0, i64 24
  ret i64 %retval.0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local noundef range(i64 0, 256) i64 @_Z18c_const_gate_blockmmmmm(i64 noundef %exceptionKind, i64 noundef %height, i64 noundef %sigversion, i64 noundef %opcode, i64 noundef %foundPositive) local_unnamed_addr #0 {
entry:
  %cmp = icmp ugt i64 %foundPositive, 1
  %retval.1 = select i1 %cmp, i64 255, i64 0
  ret i64 %retval.1
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 135168) i64 @cell_flag_source(i64 noundef %exceptionKind, i64 noundef %height) local_unnamed_addr #0 {
entry:
  %rem.i = and i64 %height, 4294967295
  %switch.selectcmp.i.i = icmp eq i64 %exceptionKind, 2
  %switch.select.i.i = select i1 %switch.selectcmp.i.i, i64 2049, i64 133121
  %switch.selectcmp27.i.i = icmp eq i64 %exceptionKind, 1
  %switch.select28.i.i = select i1 %switch.selectcmp27.i.i, i64 0, i64 %switch.select.i.i
  %cmp4.i.i = icmp samesign ugt i64 %rem.i, 363724
  %or.i.i = or disjoint i64 %switch.select28.i.i, 4
  %spec.select.i.i = select i1 %cmp4.i.i, i64 %or.i.i, i64 %switch.select28.i.i
  %cmp7.i.i = icmp samesign ugt i64 %rem.i, 388380
  %or9.i.i = or disjoint i64 %spec.select.i.i, 512
  %flags.2.i.i = select i1 %cmp7.i.i, i64 %or9.i.i, i64 %spec.select.i.i
  %cmp11.i.i = icmp samesign ugt i64 %rem.i, 419327
  %or13.i.i = or i64 %flags.2.i.i, 1024
  %flags.3.i.i = select i1 %cmp11.i.i, i64 %or13.i.i, i64 %flags.2.i.i
  %cmp15.i.i = icmp samesign ugt i64 %rem.i, 481823
  %or17.i.i = or i64 %flags.3.i.i, 16
  %flags.4.i.i = select i1 %cmp15.i.i, i64 %or17.i.i, i64 %flags.3.i.i
  ret i64 %flags.4.i.i
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none) uwtable
define dso_local range(i64 0, 25) i64 @cell_lows_gate_block(i64 noundef %exceptionKind, i64 noundef %height, i64 noundef %rByte, i64 noundef %s0, i64 noundef %s1, i64 noundef %s2, i64 noundef %s3) local_unnamed_addr #0 {
entry:
  %and.i = and i64 %rByte, 128
  %cmp.i = icmp eq i64 %and.i, 0
  %0 = icmp sgt i64 %s0, 36028797018963967
  %spec.select.i = and i1 %cmp.i, %0
  %rem.i = and i64 %height, 4294967295
  %cmp4.i.i = icmp samesign ult i64 %rem.i, 363725
  %brmerge.i = or i1 %cmp4.i.i, %spec.select.i
  %retval.0.i = select i1 %brmerge.i, i64 0, i64 24
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
define dso_local noundef i64 @cell_mandatory_policy_mask() local_unnamed_addr #0 {
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
