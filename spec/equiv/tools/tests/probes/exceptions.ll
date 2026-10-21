; ModuleID = 'tools/tests/probes/exceptions.cpp'
source_filename = "tools/tests/probes/exceptions.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

@_ZTIi = external constant ptr

; Function Attrs: mustprogress noinline optnone uwtable
define dso_local i32 @f(i32 noundef %0) #0 personality ptr @__gxx_personality_v0 !dbg !10 {
  %2 = alloca i32, align 4
  %3 = alloca i32, align 4
  %4 = alloca ptr, align 8
  %5 = alloca i32, align 4
  %6 = alloca i32, align 4
  store i32 %0, ptr %3, align 4
    #dbg_declare(ptr %3, !15, !DIExpression(), !16)
  %7 = load i32, ptr %3, align 4, !dbg !17
  %8 = icmp ne i32 %7, 0, !dbg !17
  br i1 %8, label %9, label %23, !dbg !17

9:                                                ; preds = %1
  %10 = call ptr @__cxa_allocate_exception(i64 4) #3, !dbg !20
  store i32 1, ptr %10, align 16, !dbg !20
  invoke void @__cxa_throw(ptr %10, ptr @_ZTIi, ptr null) #4
          to label %32 unwind label %11, !dbg !20

11:                                               ; preds = %9
  %12 = landingpad { ptr, i32 }
          catch ptr @_ZTIi, !dbg !21
  %13 = extractvalue { ptr, i32 } %12, 0, !dbg !21
  store ptr %13, ptr %4, align 8, !dbg !21
  %14 = extractvalue { ptr, i32 } %12, 1, !dbg !21
  store i32 %14, ptr %5, align 4, !dbg !21
  br label %15, !dbg !21

15:                                               ; preds = %11
  %16 = load i32, ptr %5, align 4, !dbg !22
  %17 = call i32 @llvm.eh.typeid.for.p0(ptr @_ZTIi) #3, !dbg !22
  %18 = icmp eq i32 %16, %17, !dbg !22
  br i1 %18, label %19, label %27, !dbg !22

19:                                               ; preds = %15
    #dbg_declare(ptr %6, !23, !DIExpression(), !24)
  %20 = load ptr, ptr %4, align 8, !dbg !22
  %21 = call ptr @__cxa_begin_catch(ptr %20) #3, !dbg !22
  %22 = load i32, ptr %21, align 4, !dbg !22
  store i32 %22, ptr %6, align 4, !dbg !22
  store i32 7, ptr %2, align 4, !dbg !25
  call void @__cxa_end_catch() #3, !dbg !27
  br label %25

23:                                               ; preds = %1
  store i32 0, ptr %2, align 4, !dbg !28
  br label %25, !dbg !28

24:                                               ; No predecessors!
  call void @llvm.trap(), !dbg !27
  unreachable, !dbg !27

25:                                               ; preds = %19, %23
  %26 = load i32, ptr %2, align 4, !dbg !29
  ret i32 %26, !dbg !29

27:                                               ; preds = %15
  %28 = load ptr, ptr %4, align 8, !dbg !22
  %29 = load i32, ptr %5, align 4, !dbg !22
  %30 = insertvalue { ptr, i32 } poison, ptr %28, 0, !dbg !22
  %31 = insertvalue { ptr, i32 } %30, i32 %29, 1, !dbg !22
  resume { ptr, i32 } %31, !dbg !22

32:                                               ; preds = %9
  unreachable
}

declare ptr @__cxa_allocate_exception(i64)

declare void @__cxa_throw(ptr, ptr, ptr)

declare i32 @__gxx_personality_v0(...)

; Function Attrs: nounwind memory(none)
declare i32 @llvm.eh.typeid.for.p0(ptr) #1

declare ptr @__cxa_begin_catch(ptr)

declare void @__cxa_end_catch()

; Function Attrs: cold noreturn nounwind memory(inaccessiblemem: write)
declare void @llvm.trap() #2

attributes #0 = { mustprogress noinline optnone uwtable "frame-pointer"="all" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { nounwind memory(none) }
attributes #2 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #3 = { nounwind }
attributes #4 = { noreturn }

!llvm.dbg.cu = !{!0}
!llvm.module.flags = !{!2, !3, !4, !5, !6, !7, !8}
!llvm.ident = !{!9}

!0 = distinct !DICompileUnit(language: DW_LANG_C_plus_plus_14, file: !1, producer: "Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)", isOptimized: false, runtimeVersion: 0, emissionKind: FullDebug, splitDebugInlining: false, nameTableKind: None)
!1 = !DIFile(filename: "tools/tests/probes/exceptions.cpp", directory: "/home/ubuntu/btc-lean-public/spec/equiv", checksumkind: CSK_MD5, checksum: "a65fc5ae84768c13782458ab19e2d4ee")
!2 = !{i32 7, !"Dwarf Version", i32 5}
!3 = !{i32 2, !"Debug Info Version", i32 3}
!4 = !{i32 1, !"wchar_size", i32 4}
!5 = !{i32 8, !"PIC Level", i32 2}
!6 = !{i32 7, !"PIE Level", i32 2}
!7 = !{i32 7, !"uwtable", i32 2}
!8 = !{i32 7, !"frame-pointer", i32 2}
!9 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
!10 = distinct !DISubprogram(name: "f", scope: !1, file: !1, line: 1, type: !11, scopeLine: 1, flags: DIFlagPrototyped, spFlags: DISPFlagDefinition, unit: !0, retainedNodes: !14)
!11 = !DISubroutineType(types: !12)
!12 = !{!13, !13}
!13 = !DIBasicType(name: "int", size: 32, encoding: DW_ATE_signed)
!14 = !{}
!15 = !DILocalVariable(name: "x", arg: 1, scope: !10, file: !1, line: 1, type: !13)
!16 = !DILocation(line: 1, column: 22, scope: !10)
!17 = !DILocation(line: 3, column: 9, scope: !18)
!18 = distinct !DILexicalBlock(scope: !19, file: !1, line: 3, column: 9)
!19 = distinct !DILexicalBlock(scope: !10, file: !1, line: 2, column: 7)
!20 = !DILocation(line: 3, column: 12, scope: !18)
!21 = !DILocation(line: 8, column: 1, scope: !18)
!22 = !DILocation(line: 5, column: 3, scope: !19)
!23 = !DILocalVariable(scope: !10, file: !1, line: 5, type: !13)
!24 = !DILocation(line: 5, column: 15, scope: !10)
!25 = !DILocation(line: 6, column: 5, scope: !26)
!26 = distinct !DILexicalBlock(scope: !10, file: !1, line: 5, column: 17)
!27 = !DILocation(line: 7, column: 3, scope: !26)
!28 = !DILocation(line: 4, column: 5, scope: !19)
!29 = !DILocation(line: 8, column: 1, scope: !10)
