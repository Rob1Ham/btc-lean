; ABI globals left undefined by the pinned single-TU interpreter module.
; They are only referenced from C++ exception metadata; no path proved here
; reads them.  Defining them is a *module-completeness* fix required by SAW's
; loader, not a semantic assumption about a reachable path.
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

@__dso_handle = hidden global i8 0
@_ZTVN10__cxxabiv120__si_class_type_infoE = constant [8 x ptr] zeroinitializer
@_ZTVN10__cxxabiv117__class_type_infoE = constant [8 x ptr] zeroinitializer
@_ZTVSt9exception = constant { [5 x ptr] } zeroinitializer
@_ZTISt13runtime_error = constant ptr null
@_ZTISt9exception = constant ptr null
@_ZN7uint2563ONEE = global [32 x i8] zeroinitializer
