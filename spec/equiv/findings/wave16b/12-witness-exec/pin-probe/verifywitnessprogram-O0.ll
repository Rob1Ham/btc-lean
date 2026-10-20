; ModuleID = 'vw.bc'
source_filename = "src/script/interpreter.cpp"
target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-pc-linux-gnu"

%class.uint256 = type { %class.base_blob }
%class.base_blob = type { %"struct.std::array" }
%"struct.std::array" = type { [32 x i8] }
%class.script_verify_flags = type { i64 }
%class.CScript = type { %class.prevector }
%class.prevector = type { %"union.prevector<36, unsigned char>::direct_or_indirect", i32 }
%"union.prevector<36, unsigned char>::direct_or_indirect" = type { [36 x i8] }
%"class.std::span.52" = type { ptr, %"class.std::__detail::__extent_storage" }
%"class.std::__detail::__extent_storage" = type { i64 }
%struct.ScriptExecutionData = type <{ i8, %class.uint256, i8, [2 x i8], i32, i8, i8, %class.uint256, i8, [5 x i8], i64, %"class.std::optional", [7 x i8] }>
%"class.std::optional" = type { %"struct.std::_Optional_base" }
%"struct.std::_Optional_base" = type { %"struct.std::_Optional_payload" }
%"struct.std::_Optional_payload" = type { %"struct.std::_Optional_payload_base" }
%"struct.std::_Optional_payload_base" = type { %"union.std::_Optional_payload_base<uint256>::_Storage", i8 }
%"union.std::_Optional_payload_base<uint256>::_Storage" = type { %class.uint256 }
%"class.__gnu_cxx::__normal_iterator.31" = type { ptr }
%class.CSHA256 = type { [8 x i32], [64 x i8], i64 }
%"class.std::span" = type { ptr, %"class.std::__detail::__extent_storage" }
%class.HashWriter = type { %class.CSHA256 }
%struct.CScriptWitness = type { %"class.std::vector.0" }
%"class.std::vector.0" = type { %"struct.std::_Vector_base.1" }
%"struct.std::_Vector_base.1" = type { %"struct.std::_Vector_base<std::vector<unsigned char>, std::allocator<std::vector<unsigned char>>>::_Vector_impl" }
%"struct.std::_Vector_base<std::vector<unsigned char>, std::allocator<std::vector<unsigned char>>>::_Vector_impl" = type { %"struct.std::_Vector_base<std::vector<unsigned char>, std::allocator<std::vector<unsigned char>>>::_Vector_impl_data" }
%"struct.std::_Vector_base<std::vector<unsigned char>, std::allocator<std::vector<unsigned char>>>::_Vector_impl_data" = type { ptr, ptr, ptr }

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef i64 @_ZNKSt6vectorIhSaIhEE4sizeEv(ptr noundef nonnull align 8 dereferenceable(24)) #0 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef nonnull align 1 dereferenceable(1) ptr @_ZNKSt6vectorIhSaIhEEixEm(ptr noundef nonnull align 8 dereferenceable(24), i64 noundef) #0 align 2

; Function Attrs: mustprogress noinline optnone uwtable
declare dso_local i64 @_Zan19script_verify_flagsS_(i64, i64) #1

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: readwrite)
declare void @llvm.memcpy.p0.p0.i64(ptr noalias nocapture writeonly, ptr noalias nocapture readonly, i64, i1 immarg) #2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local void @_ZN19script_verify_flagsC2E23script_verify_flag_name(ptr noundef nonnull align 8 dereferenceable(8), i8 noundef zeroext) unnamed_addr #0 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare hidden noundef zeroext i1 @_ZN12_GLOBAL__N_19set_errorEP13ScriptError_tS0_(ptr noundef, i32 noundef) #0

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local void @_ZN7CScriptC2Ev(ptr noundef nonnull align 8 dereferenceable(40)) unnamed_addr #0 align 2

declare i32 @__gxx_personality_v0(...)

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef i32 @_ZNK9prevectorILj36EhjiE4sizeEv(ptr noundef nonnull align 8 dereferenceable(40)) #0 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef nonnull align 8 dereferenceable(40) ptr @_ZN7CScriptaSEOS_(ptr noundef nonnull align 8 dereferenceable(40), ptr noundef nonnull align 8 dereferenceable(40)) #0 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local void @_ZN7CScriptD2Ev(ptr noundef nonnull align 8 dereferenceable(40)) unnamed_addr #0 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef zeroext i1 @_ZNK19script_verify_flagscvbEv(ptr noundef nonnull align 8 dereferenceable(8)) #0 align 2

declare void @_ZN7CSHA256C1Ev(ptr noundef nonnull align 8 dereferenceable(104)) unnamed_addr #3

declare noundef nonnull align 8 dereferenceable(104) ptr @_ZN7CSHA2565WriteEPKhm(ptr noundef nonnull align 8 dereferenceable(104), ptr noundef, i64 noundef) #3

declare void @_ZN7CSHA2568FinalizeEPh(ptr noundef nonnull align 8 dereferenceable(104), ptr noundef) #3

; Function Attrs: nocallback nofree nounwind willreturn memory(argmem: write)
declare void @llvm.memset.p0.i64(ptr nocapture writeonly, i8, i64, i1 immarg) #4

; Function Attrs: mustprogress noinline optnone uwtable
declare dso_local noundef nonnull align 8 dereferenceable(40) ptr @_ZN7CScriptlsESt4spanIKhLm18446744073709551615EE(ptr noundef nonnull align 8 dereferenceable(40), ptr, i64) #1 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare hidden noundef zeroext i1 @_ZN12_GLOBAL__N_111set_successEP13ScriptError_t(ptr noundef) #0

; Function Attrs: mustprogress noinline optnone uwtable
declare dso_local void @_ZN19ScriptExecutionDataC2Ev(ptr noundef nonnull align 8 dereferenceable(121)) unnamed_addr #1 align 2

; Function Attrs: mustprogress noinline optnone uwtable
declare dso_local void @_ZN7uint256C2Ev(ptr noundef nonnull align 1 dereferenceable(32)) unnamed_addr #1 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local void @_ZNSt4spanIKhLm18446744073709551615EEC2IRKSt6vectorIhSaIhEEQaaaaaaaaaaaantsr8__detailE9__is_spanINSt12remove_cvrefITL0__E4typeEEntsr8__detailE14__is_std_arrayISB_Ent10is_array_vISB_Esr6rangesE16contiguous_rangeIS9_Esr6rangesE11sized_rangeIS9_Eoosr6rangesE14borrowed_rangeIS9_E10is_const_vIT_Esr19__is_compatible_refIDTdeclsr3stdE7declvalIRDTclsr6ranges13__cust_accessE7__beginclsr3stdE7declvalIRS9_EEEEEEEEE5valueEEOSC_(ptr noundef nonnull align 8 dereferenceable(16), ptr noundef nonnull align 8 dereferenceable(24)) unnamed_addr #0 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef zeroext i1 @_ZNKSt6vectorIhSaIhEE5emptyEv(ptr noundef nonnull align 8 dereferenceable(24)) #0 align 2

; Function Attrs: mustprogress noinline optnone uwtable
declare dso_local void @_Z18ComputeTapleafHashhSt4spanIKhLm18446744073709551615EE(ptr dead_on_unwind noalias writable sret(%class.uint256) align 1, i8 noundef zeroext, ptr, i64) #1

; Function Attrs: mustprogress noinline optnone uwtable
declare dso_local void @_ZN10HashWriter9GetSHA256Ev(ptr dead_on_unwind noalias writable sret(%class.uint256) align 1, ptr noundef nonnull align 8 dereferenceable(104)) #1 align 2

; Function Attrs: mustprogress noinline optnone uwtable
define hidden noundef zeroext i1 @_ZL20VerifyWitnessProgramRK14CScriptWitnessiRKSt6vectorIhSaIhEE19script_verify_flagsRK20BaseSignatureCheckerP13ScriptError_tb(ptr noundef nonnull align 8 dereferenceable(24) %0, i32 noundef %1, ptr noundef nonnull align 8 dereferenceable(24) %2, i64 %3, ptr noundef nonnull align 8 dereferenceable(8) %4, ptr noundef %5, i1 noundef zeroext %6) #1 personality ptr @__gxx_personality_v0 {
  %8 = alloca i1, align 1
  %9 = alloca %class.script_verify_flags, align 8
  %10 = alloca ptr, align 8
  %11 = alloca i32, align 4
  %12 = alloca ptr, align 8
  %13 = alloca ptr, align 8
  %14 = alloca ptr, align 8
  %15 = alloca i8, align 1
  %16 = alloca %class.CScript, align 8
  %17 = alloca %"class.std::span.52", align 8
  %18 = alloca %struct.ScriptExecutionData, align 8
  %19 = alloca ptr, align 8
  %20 = alloca i32, align 4
  %21 = alloca i32, align 4
  %22 = alloca ptr, align 8
  %23 = alloca %class.CScript, align 8
  %24 = alloca %"class.__gnu_cxx::__normal_iterator.31", align 8
  %25 = alloca %"class.__gnu_cxx::__normal_iterator.31", align 8
  %26 = alloca %class.uint256, align 1
  %27 = alloca %class.CSHA256, align 8
  %28 = alloca %class.script_verify_flags, align 8
  %29 = alloca %"class.std::span", align 8
  %30 = alloca %class.script_verify_flags, align 8
  %31 = alloca %class.script_verify_flags, align 8
  %32 = alloca %class.script_verify_flags, align 8
  %33 = alloca %class.script_verify_flags, align 8
  %34 = alloca ptr, align 8
  %35 = alloca %class.uint256, align 1
  %36 = alloca %class.HashWriter, align 8
  %37 = alloca %"class.std::span", align 8
  %38 = alloca %"class.std::span", align 8
  %39 = alloca ptr, align 8
  %40 = alloca ptr, align 8
  %41 = alloca %class.uint256, align 1
  %42 = alloca %"class.std::span", align 8
  %43 = alloca %class.CScript, align 8
  %44 = alloca %"class.__gnu_cxx::__normal_iterator.31", align 8
  %45 = alloca %"class.__gnu_cxx::__normal_iterator.31", align 8
  %46 = alloca %class.script_verify_flags, align 8
  %47 = alloca %class.script_verify_flags, align 8
  %48 = alloca %class.script_verify_flags, align 8
  %49 = alloca %class.script_verify_flags, align 8
  %50 = alloca %class.script_verify_flags, align 8
  %51 = alloca %class.script_verify_flags, align 8
  %52 = alloca %class.script_verify_flags, align 8
  %53 = getelementptr inbounds nuw %class.script_verify_flags, ptr %9, i32 0, i32 0
  store i64 %3, ptr %53, align 8
  store ptr %0, ptr %10, align 8
  store i32 %1, ptr %11, align 4
  store ptr %2, ptr %12, align 8
  store ptr %4, ptr %13, align 8
  store ptr %5, ptr %14, align 8
  %54 = zext i1 %6 to i8
  store i8 %54, ptr %15, align 1
  call void @_ZN7CScriptC2Ev(ptr noundef nonnull align 8 dereferenceable(40) %16) #6
  %55 = load ptr, ptr %10, align 8
  %56 = getelementptr inbounds nuw %struct.CScriptWitness, ptr %55, i32 0, i32 0
  call void @_ZNSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EEC2IRKS0_IS2_SaIS2_EEQaaaaaaaaaaaantsr8__detailE9__is_spanINSt12remove_cvrefITL0__E4typeEEntsr8__detailE14__is_std_arrayISD_Ent10is_array_vISD_Esr6rangesE16contiguous_rangeISB_Esr6rangesE11sized_rangeISB_Eoosr6rangesE14borrowed_rangeISB_E10is_const_vIT_Esr19__is_compatible_refIDTdeclsr3stdE7declvalIRDTclsr6ranges13__cust_accessE7__beginclsr3stdE7declvalIRSB_EEEEEEEEE5valueEEOSE_(ptr noundef nonnull align 8 dereferenceable(16) %17, ptr noundef nonnull align 8 dereferenceable(24) %56) #6
  invoke void @_ZN19ScriptExecutionDataC2Ev(ptr noundef nonnull align 8 dereferenceable(121) %18)
          to label %57 unwind label %70

57:                                               ; preds = %7
  %58 = load i32, ptr %11, align 4
  %59 = icmp eq i32 %58, 0
  br i1 %59, label %60, label %150

60:                                               ; preds = %57
  %61 = load ptr, ptr %12, align 8
  %62 = call noundef i64 @_ZNKSt6vectorIhSaIhEE4sizeEv(ptr noundef nonnull align 8 dereferenceable(24) %61) #6
  %63 = icmp eq i64 %62, 32
  br i1 %63, label %64, label %115

64:                                               ; preds = %60
  %65 = call noundef i64 @_ZNKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EE4sizeEv(ptr noundef nonnull align 8 dereferenceable(16) %17) #6
  %66 = icmp eq i64 %65, 0
  br i1 %66, label %67, label %74

67:                                               ; preds = %64
  %68 = load ptr, ptr %14, align 8
  %69 = call noundef zeroext i1 @_ZN12_GLOBAL__N_19set_errorEP13ScriptError_tS0_(ptr noundef %68, i32 noundef 39)
  store i1 %69, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

70:                                               ; preds = %333, %332, %326, %308, %307, %297, %292, %281, %263, %251, %232, %230, %208, %198, %195, %194, %192, %161, %160, %140, %138, %136, %129, %127, %125, %108, %97, %94, %92, %90, %89, %87, %76, %74, %7
  %71 = landingpad { ptr, i32 }
          cleanup
  %72 = extractvalue { ptr, i32 } %71, 0
  store ptr %72, ptr %19, align 8
  %73 = extractvalue { ptr, i32 } %71, 1
  store i32 %73, ptr %20, align 4
  call void @_ZN7CScriptD2Ev(ptr noundef nonnull align 8 dereferenceable(40) %16) #6
  br label %348

74:                                               ; preds = %64
  %75 = invoke noundef nonnull align 8 dereferenceable(24) ptr @_Z11SpanPopBackIKSt6vectorIhSaIhEEERT_RSt4spanIS4_Lm18446744073709551615EE(ptr noundef nonnull align 8 dereferenceable(16) %17)
          to label %76 unwind label %70

76:                                               ; preds = %74
  store ptr %75, ptr %22, align 8
  %77 = load ptr, ptr %22, align 8
  %78 = call ptr @_ZNKSt6vectorIhSaIhEE5beginEv(ptr noundef nonnull align 8 dereferenceable(24) %77) #6
  %79 = getelementptr inbounds nuw %"class.__gnu_cxx::__normal_iterator.31", ptr %24, i32 0, i32 0
  store ptr %78, ptr %79, align 8
  %80 = load ptr, ptr %22, align 8
  %81 = call ptr @_ZNKSt6vectorIhSaIhEE3endEv(ptr noundef nonnull align 8 dereferenceable(24) %80) #6
  %82 = getelementptr inbounds nuw %"class.__gnu_cxx::__normal_iterator.31", ptr %25, i32 0, i32 0
  store ptr %81, ptr %82, align 8
  %83 = getelementptr inbounds nuw %"class.__gnu_cxx::__normal_iterator.31", ptr %24, i32 0, i32 0
  %84 = load ptr, ptr %83, align 8
  %85 = getelementptr inbounds nuw %"class.__gnu_cxx::__normal_iterator.31", ptr %25, i32 0, i32 0
  %86 = load ptr, ptr %85, align 8
  invoke void @_ZN7CScriptC2ITkSt14input_iteratorN9__gnu_cxx17__normal_iteratorIPKhSt6vectorIhSaIhEEEEEET_S9_(ptr noundef nonnull align 8 dereferenceable(40) %23, ptr %84, ptr %86)
          to label %87 unwind label %70

87:                                               ; preds = %76
  %88 = call noundef nonnull align 8 dereferenceable(40) ptr @_ZN7CScriptaSEOS_(ptr noundef nonnull align 8 dereferenceable(40) %16, ptr noundef nonnull align 8 dereferenceable(40) %23) #6
  call void @_ZN7CScriptD2Ev(ptr noundef nonnull align 8 dereferenceable(40) %23) #6
  invoke void @_ZN7uint256C2Ev(ptr noundef nonnull align 1 dereferenceable(32) %26)
          to label %89 unwind label %70

89:                                               ; preds = %87
  invoke void @_ZN7CSHA256C1Ev(ptr noundef nonnull align 8 dereferenceable(104) %27)
          to label %90 unwind label %70

90:                                               ; preds = %89
  %91 = invoke noundef ptr @_ZN9prevectorILj36EhjiE4dataEv(ptr noundef nonnull align 8 dereferenceable(40) %16)
          to label %92 unwind label %70

92:                                               ; preds = %90
  %93 = invoke noundef i32 @_ZNK9prevectorILj36EhjiE4sizeEv(ptr noundef nonnull align 8 dereferenceable(40) %16)
          to label %94 unwind label %70

94:                                               ; preds = %92
  %95 = zext i32 %93 to i64
  %96 = invoke noundef nonnull align 8 dereferenceable(104) ptr @_ZN7CSHA2565WriteEPKhm(ptr noundef nonnull align 8 dereferenceable(104) %27, ptr noundef %91, i64 noundef %95)
          to label %97 unwind label %70

97:                                               ; preds = %94
  %98 = call noundef ptr @_ZN9base_blobILj256EE5beginEv(ptr noundef nonnull align 1 dereferenceable(32) %26)
  invoke void @_ZN7CSHA2568FinalizeEPh(ptr noundef nonnull align 8 dereferenceable(104) %96, ptr noundef %98)
          to label %99 unwind label %70

99:                                               ; preds = %97
  %100 = call noundef ptr @_ZN9base_blobILj256EE5beginEv(ptr noundef nonnull align 1 dereferenceable(32) %26)
  %101 = load ptr, ptr %12, align 8
  %102 = call noundef ptr @_ZNKSt6vectorIhSaIhEE4dataEv(ptr noundef nonnull align 8 dereferenceable(24) %101) #6
  %103 = call i32 @memcmp(ptr noundef %100, ptr noundef %102, i64 noundef 32) #7
  %104 = icmp ne i32 %103, 0
  br i1 %104, label %105, label %108

105:                                              ; preds = %99
  %106 = load ptr, ptr %14, align 8
  %107 = call noundef zeroext i1 @_ZN12_GLOBAL__N_19set_errorEP13ScriptError_tS0_(ptr noundef %106, i32 noundef 40)
  store i1 %107, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

108:                                              ; preds = %99
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %28, ptr align 8 %9, i64 8, i1 false)
  %109 = load ptr, ptr %13, align 8
  %110 = load ptr, ptr %14, align 8
  %111 = getelementptr inbounds nuw %class.script_verify_flags, ptr %28, i32 0, i32 0
  %112 = load i64, ptr %111, align 8
  %113 = invoke noundef zeroext i1 @_ZL20ExecuteWitnessScriptRKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EERK7CScript19script_verify_flags10SigVersionRK20BaseSignatureCheckerR19ScriptExecutionDataP13ScriptError_t(ptr noundef nonnull align 8 dereferenceable(16) %17, ptr noundef nonnull align 8 dereferenceable(40) %16, i64 %112, i32 noundef 1, ptr noundef nonnull align 8 dereferenceable(8) %109, ptr noundef nonnull align 8 dereferenceable(121) %18, ptr noundef %110)
          to label %114 unwind label %70

114:                                              ; preds = %108
  store i1 %113, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

115:                                              ; preds = %60
  %116 = load ptr, ptr %12, align 8
  %117 = call noundef i64 @_ZNKSt6vectorIhSaIhEE4sizeEv(ptr noundef nonnull align 8 dereferenceable(24) %116) #6
  %118 = icmp eq i64 %117, 20
  br i1 %118, label %119, label %147

119:                                              ; preds = %115
  %120 = call noundef i64 @_ZNKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EE4sizeEv(ptr noundef nonnull align 8 dereferenceable(16) %17) #6
  %121 = icmp ne i64 %120, 2
  br i1 %121, label %122, label %125

122:                                              ; preds = %119
  %123 = load ptr, ptr %14, align 8
  %124 = call noundef zeroext i1 @_ZN12_GLOBAL__N_19set_errorEP13ScriptError_tS0_(ptr noundef %123, i32 noundef 40)
  store i1 %124, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

125:                                              ; preds = %119
  %126 = invoke noundef nonnull align 8 dereferenceable(40) ptr @_ZN7CScriptlsE10opcodetype(ptr noundef nonnull align 8 dereferenceable(40) %16, i32 noundef 118)
          to label %127 unwind label %70

127:                                              ; preds = %125
  %128 = invoke noundef nonnull align 8 dereferenceable(40) ptr @_ZN7CScriptlsE10opcodetype(ptr noundef nonnull align 8 dereferenceable(40) %126, i32 noundef 169)
          to label %129 unwind label %70

129:                                              ; preds = %127
  %130 = load ptr, ptr %12, align 8
  call void @_ZNSt4spanIKhLm18446744073709551615EEC2IRKSt6vectorIhSaIhEEQaaaaaaaaaaaantsr8__detailE9__is_spanINSt12remove_cvrefITL0__E4typeEEntsr8__detailE14__is_std_arrayISB_Ent10is_array_vISB_Esr6rangesE16contiguous_rangeIS9_Esr6rangesE11sized_rangeIS9_Eoosr6rangesE14borrowed_rangeIS9_E10is_const_vIT_Esr19__is_compatible_refIDTdeclsr3stdE7declvalIRDTclsr6ranges13__cust_accessE7__beginclsr3stdE7declvalIRS9_EEEEEEEEE5valueEEOSC_(ptr noundef nonnull align 8 dereferenceable(16) %29, ptr noundef nonnull align 8 dereferenceable(24) %130) #6
  %131 = getelementptr inbounds nuw { ptr, i64 }, ptr %29, i32 0, i32 0
  %132 = load ptr, ptr %131, align 8
  %133 = getelementptr inbounds nuw { ptr, i64 }, ptr %29, i32 0, i32 1
  %134 = load i64, ptr %133, align 8
  %135 = invoke noundef nonnull align 8 dereferenceable(40) ptr @_ZN7CScriptlsESt4spanIKhLm18446744073709551615EE(ptr noundef nonnull align 8 dereferenceable(40) %128, ptr %132, i64 %134)
          to label %136 unwind label %70

136:                                              ; preds = %129
  %137 = invoke noundef nonnull align 8 dereferenceable(40) ptr @_ZN7CScriptlsE10opcodetype(ptr noundef nonnull align 8 dereferenceable(40) %135, i32 noundef 136)
          to label %138 unwind label %70

138:                                              ; preds = %136
  %139 = invoke noundef nonnull align 8 dereferenceable(40) ptr @_ZN7CScriptlsE10opcodetype(ptr noundef nonnull align 8 dereferenceable(40) %137, i32 noundef 172)
          to label %140 unwind label %70

140:                                              ; preds = %138
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %30, ptr align 8 %9, i64 8, i1 false)
  %141 = load ptr, ptr %13, align 8
  %142 = load ptr, ptr %14, align 8
  %143 = getelementptr inbounds nuw %class.script_verify_flags, ptr %30, i32 0, i32 0
  %144 = load i64, ptr %143, align 8
  %145 = invoke noundef zeroext i1 @_ZL20ExecuteWitnessScriptRKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EERK7CScript19script_verify_flags10SigVersionRK20BaseSignatureCheckerR19ScriptExecutionDataP13ScriptError_t(ptr noundef nonnull align 8 dereferenceable(16) %17, ptr noundef nonnull align 8 dereferenceable(40) %16, i64 %144, i32 noundef 1, ptr noundef nonnull align 8 dereferenceable(8) %141, ptr noundef nonnull align 8 dereferenceable(121) %18, ptr noundef %142)
          to label %146 unwind label %70

146:                                              ; preds = %140
  store i1 %145, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

147:                                              ; preds = %115
  %148 = load ptr, ptr %14, align 8
  %149 = call noundef zeroext i1 @_ZN12_GLOBAL__N_19set_errorEP13ScriptError_tS0_(ptr noundef %148, i32 noundef 38)
  store i1 %149, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

150:                                              ; preds = %57
  %151 = load i32, ptr %11, align 4
  %152 = icmp eq i32 %151, 1
  br i1 %152, label %153, label %323

153:                                              ; preds = %150
  %154 = load ptr, ptr %12, align 8
  %155 = call noundef i64 @_ZNKSt6vectorIhSaIhEE4sizeEv(ptr noundef nonnull align 8 dereferenceable(24) %154) #6
  %156 = icmp eq i64 %155, 32
  br i1 %156, label %157, label %323

157:                                              ; preds = %153
  %158 = load i8, ptr %15, align 1
  %159 = trunc i8 %158 to i1
  br i1 %159, label %323, label %160

160:                                              ; preds = %157
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %32, ptr align 8 %9, i64 8, i1 false)
  invoke void @_ZN19script_verify_flagsC2E23script_verify_flag_name(ptr noundef nonnull align 8 dereferenceable(8) %33, i8 noundef zeroext 17)
          to label %161 unwind label %70

161:                                              ; preds = %160
  %162 = getelementptr inbounds nuw %class.script_verify_flags, ptr %32, i32 0, i32 0
  %163 = load i64, ptr %162, align 8
  %164 = getelementptr inbounds nuw %class.script_verify_flags, ptr %33, i32 0, i32 0
  %165 = load i64, ptr %164, align 8
  %166 = invoke i64 @_Zan19script_verify_flagsS_(i64 %163, i64 %165)
          to label %167 unwind label %70

167:                                              ; preds = %161
  %168 = getelementptr inbounds nuw %class.script_verify_flags, ptr %31, i32 0, i32 0
  store i64 %166, ptr %168, align 8
  %169 = call noundef zeroext i1 @_ZNK19script_verify_flagscvbEv(ptr noundef nonnull align 8 dereferenceable(8) %31)
  %170 = xor i1 %169, true
  br i1 %170, label %171, label %174

171:                                              ; preds = %167
  %172 = load ptr, ptr %14, align 8
  %173 = call noundef zeroext i1 @_ZN12_GLOBAL__N_111set_successEP13ScriptError_t(ptr noundef %172)
  store i1 %173, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

174:                                              ; preds = %167
  %175 = call noundef i64 @_ZNKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EE4sizeEv(ptr noundef nonnull align 8 dereferenceable(16) %17) #6
  %176 = icmp eq i64 %175, 0
  br i1 %176, label %177, label %180

177:                                              ; preds = %174
  %178 = load ptr, ptr %14, align 8
  %179 = call noundef zeroext i1 @_ZN12_GLOBAL__N_19set_errorEP13ScriptError_tS0_(ptr noundef %178, i32 noundef 39)
  store i1 %179, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

180:                                              ; preds = %174
  %181 = call noundef i64 @_ZNKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EE4sizeEv(ptr noundef nonnull align 8 dereferenceable(16) %17) #6
  %182 = icmp uge i64 %181, 2
  br i1 %182, label %183, label %202

183:                                              ; preds = %180
  %184 = call noundef nonnull align 8 dereferenceable(24) ptr @_ZNKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EE4backEv(ptr noundef nonnull align 8 dereferenceable(16) %17) #6
  %185 = call noundef zeroext i1 @_ZNKSt6vectorIhSaIhEE5emptyEv(ptr noundef nonnull align 8 dereferenceable(24) %184) #6
  br i1 %185, label %202, label %186

186:                                              ; preds = %183
  %187 = call noundef nonnull align 8 dereferenceable(24) ptr @_ZNKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EE4backEv(ptr noundef nonnull align 8 dereferenceable(16) %17) #6
  %188 = call noundef nonnull align 1 dereferenceable(1) ptr @_ZNKSt6vectorIhSaIhEEixEm(ptr noundef nonnull align 8 dereferenceable(24) %187, i64 noundef 0) #6
  %189 = load i8, ptr %188, align 1
  %190 = zext i8 %189 to i32
  %191 = icmp eq i32 %190, 80
  br i1 %191, label %192, label %202

192:                                              ; preds = %186
  %193 = invoke noundef nonnull align 8 dereferenceable(24) ptr @_Z11SpanPopBackIKSt6vectorIhSaIhEEERT_RSt4spanIS4_Lm18446744073709551615EE(ptr noundef nonnull align 8 dereferenceable(16) %17)
          to label %194 unwind label %70

194:                                              ; preds = %192
  store ptr %193, ptr %34, align 8
  call void @llvm.memset.p0.i64(ptr align 8 %36, i8 0, i64 104, i1 false)
  invoke void @_ZN10HashWriterC2Ev(ptr noundef nonnull align 8 dereferenceable(104) %36)
          to label %195 unwind label %70

195:                                              ; preds = %194
  %196 = load ptr, ptr %34, align 8
  %197 = invoke noundef nonnull align 8 dereferenceable(104) ptr @_ZN10HashWriterlsISt6vectorIhSaIhEEEERS_RKT_(ptr noundef nonnull align 8 dereferenceable(104) %36, ptr noundef nonnull align 8 dereferenceable(24) %196)
          to label %198 unwind label %70

198:                                              ; preds = %195
  invoke void @_ZN10HashWriter9GetSHA256Ev(ptr dead_on_unwind writable sret(%class.uint256) align 1 %35, ptr noundef nonnull align 8 dereferenceable(104) %197)
          to label %199 unwind label %70

199:                                              ; preds = %198
  %200 = getelementptr inbounds nuw %struct.ScriptExecutionData, ptr %18, i32 0, i32 7
  call void @llvm.memcpy.p0.p0.i64(ptr align 2 %200, ptr align 1 %35, i64 32, i1 false)
  %201 = getelementptr inbounds nuw %struct.ScriptExecutionData, ptr %18, i32 0, i32 6
  store i8 1, ptr %201, align 1
  br label %204

202:                                              ; preds = %186, %183, %180
  %203 = getelementptr inbounds nuw %struct.ScriptExecutionData, ptr %18, i32 0, i32 6
  store i8 0, ptr %203, align 1
  br label %204

204:                                              ; preds = %202, %199
  %205 = getelementptr inbounds nuw %struct.ScriptExecutionData, ptr %18, i32 0, i32 5
  store i8 1, ptr %205, align 8
  %206 = call noundef i64 @_ZNKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EE4sizeEv(ptr noundef nonnull align 8 dereferenceable(16) %17) #6
  %207 = icmp eq i64 %206, 1
  br i1 %207, label %208, label %230

208:                                              ; preds = %204
  %209 = load ptr, ptr %13, align 8
  %210 = call noundef nonnull align 8 dereferenceable(24) ptr @_ZNKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EE5frontEv(ptr noundef nonnull align 8 dereferenceable(16) %17) #6
  call void @_ZNSt4spanIKhLm18446744073709551615EEC2IRKSt6vectorIhSaIhEEQaaaaaaaaaaaantsr8__detailE9__is_spanINSt12remove_cvrefITL0__E4typeEEntsr8__detailE14__is_std_arrayISB_Ent10is_array_vISB_Esr6rangesE16contiguous_rangeIS9_Esr6rangesE11sized_rangeIS9_Eoosr6rangesE14borrowed_rangeIS9_E10is_const_vIT_Esr19__is_compatible_refIDTdeclsr3stdE7declvalIRDTclsr6ranges13__cust_accessE7__beginclsr3stdE7declvalIRS9_EEEEEEEEE5valueEEOSC_(ptr noundef nonnull align 8 dereferenceable(16) %37, ptr noundef nonnull align 8 dereferenceable(24) %210) #6
  %211 = load ptr, ptr %12, align 8
  call void @_ZNSt4spanIKhLm18446744073709551615EEC2IRKSt6vectorIhSaIhEEQaaaaaaaaaaaantsr8__detailE9__is_spanINSt12remove_cvrefITL0__E4typeEEntsr8__detailE14__is_std_arrayISB_Ent10is_array_vISB_Esr6rangesE16contiguous_rangeIS9_Esr6rangesE11sized_rangeIS9_Eoosr6rangesE14borrowed_rangeIS9_E10is_const_vIT_Esr19__is_compatible_refIDTdeclsr3stdE7declvalIRDTclsr6ranges13__cust_accessE7__beginclsr3stdE7declvalIRS9_EEEEEEEEE5valueEEOSC_(ptr noundef nonnull align 8 dereferenceable(16) %38, ptr noundef nonnull align 8 dereferenceable(24) %211) #6
  %212 = load ptr, ptr %14, align 8
  %213 = getelementptr inbounds nuw { ptr, i64 }, ptr %37, i32 0, i32 0
  %214 = load ptr, ptr %213, align 8
  %215 = getelementptr inbounds nuw { ptr, i64 }, ptr %37, i32 0, i32 1
  %216 = load i64, ptr %215, align 8
  %217 = getelementptr inbounds nuw { ptr, i64 }, ptr %38, i32 0, i32 0
  %218 = load ptr, ptr %217, align 8
  %219 = getelementptr inbounds nuw { ptr, i64 }, ptr %38, i32 0, i32 1
  %220 = load i64, ptr %219, align 8
  %221 = load ptr, ptr %209, align 8
  %222 = getelementptr inbounds ptr, ptr %221, i64 1
  %223 = load ptr, ptr %222, align 8
  %224 = invoke noundef zeroext i1 %223(ptr noundef nonnull align 8 dereferenceable(8) %209, ptr %214, i64 %216, ptr %218, i64 %220, i32 noundef 2, ptr noundef nonnull align 8 dereferenceable(121) %18, ptr noundef %212)
          to label %225 unwind label %70

225:                                              ; preds = %208
  br i1 %224, label %227, label %226

226:                                              ; preds = %225
  store i1 false, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

227:                                              ; preds = %225
  %228 = load ptr, ptr %14, align 8
  %229 = call noundef zeroext i1 @_ZN12_GLOBAL__N_111set_successEP13ScriptError_t(ptr noundef %228)
  store i1 %229, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

230:                                              ; preds = %204
  %231 = invoke noundef nonnull align 8 dereferenceable(24) ptr @_Z11SpanPopBackIKSt6vectorIhSaIhEEERT_RSt4spanIS4_Lm18446744073709551615EE(ptr noundef nonnull align 8 dereferenceable(16) %17)
          to label %232 unwind label %70

232:                                              ; preds = %230
  store ptr %231, ptr %39, align 8
  %233 = invoke noundef nonnull align 8 dereferenceable(24) ptr @_Z11SpanPopBackIKSt6vectorIhSaIhEEERT_RSt4spanIS4_Lm18446744073709551615EE(ptr noundef nonnull align 8 dereferenceable(16) %17)
          to label %234 unwind label %70

234:                                              ; preds = %232
  store ptr %233, ptr %40, align 8
  %235 = load ptr, ptr %39, align 8
  %236 = call noundef i64 @_ZNKSt6vectorIhSaIhEE4sizeEv(ptr noundef nonnull align 8 dereferenceable(24) %235) #6
  %237 = icmp ult i64 %236, 33
  br i1 %237, label %248, label %238

238:                                              ; preds = %234
  %239 = load ptr, ptr %39, align 8
  %240 = call noundef i64 @_ZNKSt6vectorIhSaIhEE4sizeEv(ptr noundef nonnull align 8 dereferenceable(24) %239) #6
  %241 = icmp ugt i64 %240, 4129
  br i1 %241, label %248, label %242

242:                                              ; preds = %238
  %243 = load ptr, ptr %39, align 8
  %244 = call noundef i64 @_ZNKSt6vectorIhSaIhEE4sizeEv(ptr noundef nonnull align 8 dereferenceable(24) %243) #6
  %245 = sub i64 %244, 33
  %246 = urem i64 %245, 32
  %247 = icmp ne i64 %246, 0
  br i1 %247, label %248, label %251

248:                                              ; preds = %242, %238, %234
  %249 = load ptr, ptr %14, align 8
  %250 = call noundef zeroext i1 @_ZN12_GLOBAL__N_19set_errorEP13ScriptError_tS0_(ptr noundef %249, i32 noundef 48)
  store i1 %250, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

251:                                              ; preds = %242
  %252 = load ptr, ptr %39, align 8
  %253 = call noundef nonnull align 1 dereferenceable(1) ptr @_ZNKSt6vectorIhSaIhEEixEm(ptr noundef nonnull align 8 dereferenceable(24) %252, i64 noundef 0) #6
  %254 = load i8, ptr %253, align 1
  %255 = zext i8 %254 to i32
  %256 = and i32 %255, 254
  %257 = trunc i32 %256 to i8
  %258 = load ptr, ptr %40, align 8
  call void @_ZNSt4spanIKhLm18446744073709551615EEC2IRKSt6vectorIhSaIhEEQaaaaaaaaaaaantsr8__detailE9__is_spanINSt12remove_cvrefITL0__E4typeEEntsr8__detailE14__is_std_arrayISB_Ent10is_array_vISB_Esr6rangesE16contiguous_rangeIS9_Esr6rangesE11sized_rangeIS9_Eoosr6rangesE14borrowed_rangeIS9_E10is_const_vIT_Esr19__is_compatible_refIDTdeclsr3stdE7declvalIRDTclsr6ranges13__cust_accessE7__beginclsr3stdE7declvalIRS9_EEEEEEEEE5valueEEOSC_(ptr noundef nonnull align 8 dereferenceable(16) %42, ptr noundef nonnull align 8 dereferenceable(24) %258) #6
  %259 = getelementptr inbounds nuw { ptr, i64 }, ptr %42, i32 0, i32 0
  %260 = load ptr, ptr %259, align 8
  %261 = getelementptr inbounds nuw { ptr, i64 }, ptr %42, i32 0, i32 1
  %262 = load i64, ptr %261, align 8
  invoke void @_Z18ComputeTapleafHashhSt4spanIKhLm18446744073709551615EE(ptr dead_on_unwind writable sret(%class.uint256) align 1 %41, i8 noundef zeroext %257, ptr %260, i64 %262)
          to label %263 unwind label %70

263:                                              ; preds = %251
  %264 = getelementptr inbounds nuw %struct.ScriptExecutionData, ptr %18, i32 0, i32 1
  call void @llvm.memcpy.p0.p0.i64(ptr align 1 %264, ptr align 1 %41, i64 32, i1 false)
  %265 = load ptr, ptr %39, align 8
  %266 = load ptr, ptr %12, align 8
  %267 = getelementptr inbounds nuw %struct.ScriptExecutionData, ptr %18, i32 0, i32 1
  %268 = invoke noundef zeroext i1 @_ZL23VerifyTaprootCommitmentRKSt6vectorIhSaIhEES3_RK7uint256(ptr noundef nonnull align 8 dereferenceable(24) %265, ptr noundef nonnull align 8 dereferenceable(24) %266, ptr noundef nonnull align 1 dereferenceable(32) %267)
          to label %269 unwind label %70

269:                                              ; preds = %263
  br i1 %268, label %273, label %270

270:                                              ; preds = %269
  %271 = load ptr, ptr %14, align 8
  %272 = call noundef zeroext i1 @_ZN12_GLOBAL__N_19set_errorEP13ScriptError_tS0_(ptr noundef %271, i32 noundef 40)
  store i1 %272, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

273:                                              ; preds = %269
  %274 = getelementptr inbounds nuw %struct.ScriptExecutionData, ptr %18, i32 0, i32 0
  store i8 1, ptr %274, align 8
  %275 = load ptr, ptr %39, align 8
  %276 = call noundef nonnull align 1 dereferenceable(1) ptr @_ZNKSt6vectorIhSaIhEEixEm(ptr noundef nonnull align 8 dereferenceable(24) %275, i64 noundef 0) #6
  %277 = load i8, ptr %276, align 1
  %278 = zext i8 %277 to i32
  %279 = and i32 %278, 254
  %280 = icmp eq i32 %279, 192
  br i1 %280, label %281, label %307

281:                                              ; preds = %273
  %282 = load ptr, ptr %40, align 8
  %283 = call ptr @_ZNKSt6vectorIhSaIhEE5beginEv(ptr noundef nonnull align 8 dereferenceable(24) %282) #6
  %284 = getelementptr inbounds nuw %"class.__gnu_cxx::__normal_iterator.31", ptr %44, i32 0, i32 0
  store ptr %283, ptr %284, align 8
  %285 = load ptr, ptr %40, align 8
  %286 = call ptr @_ZNKSt6vectorIhSaIhEE3endEv(ptr noundef nonnull align 8 dereferenceable(24) %285) #6
  %287 = getelementptr inbounds nuw %"class.__gnu_cxx::__normal_iterator.31", ptr %45, i32 0, i32 0
  store ptr %286, ptr %287, align 8
  %288 = getelementptr inbounds nuw %"class.__gnu_cxx::__normal_iterator.31", ptr %44, i32 0, i32 0
  %289 = load ptr, ptr %288, align 8
  %290 = getelementptr inbounds nuw %"class.__gnu_cxx::__normal_iterator.31", ptr %45, i32 0, i32 0
  %291 = load ptr, ptr %290, align 8
  invoke void @_ZN7CScriptC2ITkSt14input_iteratorN9__gnu_cxx17__normal_iteratorIPKhSt6vectorIhSaIhEEEEEET_S9_(ptr noundef nonnull align 8 dereferenceable(40) %43, ptr %289, ptr %291)
          to label %292 unwind label %70

292:                                              ; preds = %281
  %293 = call noundef nonnull align 8 dereferenceable(40) ptr @_ZN7CScriptaSEOS_(ptr noundef nonnull align 8 dereferenceable(40) %16, ptr noundef nonnull align 8 dereferenceable(40) %43) #6
  call void @_ZN7CScriptD2Ev(ptr noundef nonnull align 8 dereferenceable(40) %43) #6
  %294 = load ptr, ptr %10, align 8
  %295 = getelementptr inbounds nuw %struct.CScriptWitness, ptr %294, i32 0, i32 0
  %296 = invoke noundef i64 @_Z16GetSerializeSizeISt6vectorIS0_IhSaIhEESaIS2_EEEmRKT_(ptr noundef nonnull align 8 dereferenceable(24) %295)
          to label %297 unwind label %70

297:                                              ; preds = %292
  %298 = add i64 %296, 50
  %299 = getelementptr inbounds nuw %struct.ScriptExecutionData, ptr %18, i32 0, i32 10
  store i64 %298, ptr %299, align 8
  %300 = getelementptr inbounds nuw %struct.ScriptExecutionData, ptr %18, i32 0, i32 8
  store i8 1, ptr %300, align 2
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %46, ptr align 8 %9, i64 8, i1 false)
  %301 = load ptr, ptr %13, align 8
  %302 = load ptr, ptr %14, align 8
  %303 = getelementptr inbounds nuw %class.script_verify_flags, ptr %46, i32 0, i32 0
  %304 = load i64, ptr %303, align 8
  %305 = invoke noundef zeroext i1 @_ZL20ExecuteWitnessScriptRKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EERK7CScript19script_verify_flags10SigVersionRK20BaseSignatureCheckerR19ScriptExecutionDataP13ScriptError_t(ptr noundef nonnull align 8 dereferenceable(16) %17, ptr noundef nonnull align 8 dereferenceable(40) %16, i64 %304, i32 noundef 3, ptr noundef nonnull align 8 dereferenceable(8) %301, ptr noundef nonnull align 8 dereferenceable(121) %18, ptr noundef %302)
          to label %306 unwind label %70

306:                                              ; preds = %297
  store i1 %305, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

307:                                              ; preds = %273
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %48, ptr align 8 %9, i64 8, i1 false)
  invoke void @_ZN19script_verify_flagsC2E23script_verify_flag_name(ptr noundef nonnull align 8 dereferenceable(8) %49, i8 noundef zeroext 18)
          to label %308 unwind label %70

308:                                              ; preds = %307
  %309 = getelementptr inbounds nuw %class.script_verify_flags, ptr %48, i32 0, i32 0
  %310 = load i64, ptr %309, align 8
  %311 = getelementptr inbounds nuw %class.script_verify_flags, ptr %49, i32 0, i32 0
  %312 = load i64, ptr %311, align 8
  %313 = invoke i64 @_Zan19script_verify_flagsS_(i64 %310, i64 %312)
          to label %314 unwind label %70

314:                                              ; preds = %308
  %315 = getelementptr inbounds nuw %class.script_verify_flags, ptr %47, i32 0, i32 0
  store i64 %313, ptr %315, align 8
  %316 = call noundef zeroext i1 @_ZNK19script_verify_flagscvbEv(ptr noundef nonnull align 8 dereferenceable(8) %47)
  br i1 %316, label %317, label %320

317:                                              ; preds = %314
  %318 = load ptr, ptr %14, align 8
  %319 = call noundef zeroext i1 @_ZN12_GLOBAL__N_19set_errorEP13ScriptError_tS0_(ptr noundef %318, i32 noundef 35)
  store i1 %319, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

320:                                              ; preds = %314
  %321 = load ptr, ptr %14, align 8
  %322 = call noundef zeroext i1 @_ZN12_GLOBAL__N_111set_successEP13ScriptError_t(ptr noundef %321)
  store i1 %322, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

323:                                              ; preds = %157, %153, %150
  %324 = load i8, ptr %15, align 1
  %325 = trunc i8 %324 to i1
  br i1 %325, label %332, label %326

326:                                              ; preds = %323
  %327 = load i32, ptr %11, align 4
  %328 = load ptr, ptr %12, align 8
  %329 = invoke noundef zeroext i1 @_ZN7CScript13IsPayToAnchorEiRKSt6vectorIhSaIhEE(i32 noundef %327, ptr noundef nonnull align 8 dereferenceable(24) %328)
          to label %330 unwind label %70

330:                                              ; preds = %326
  br i1 %329, label %331, label %332

331:                                              ; preds = %330
  store i1 true, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

332:                                              ; preds = %330, %323
  call void @llvm.memcpy.p0.p0.i64(ptr align 8 %51, ptr align 8 %9, i64 8, i1 false)
  invoke void @_ZN19script_verify_flagsC2E23script_verify_flag_name(ptr noundef nonnull align 8 dereferenceable(8) %52, i8 noundef zeroext 12)
          to label %333 unwind label %70

333:                                              ; preds = %332
  %334 = getelementptr inbounds nuw %class.script_verify_flags, ptr %51, i32 0, i32 0
  %335 = load i64, ptr %334, align 8
  %336 = getelementptr inbounds nuw %class.script_verify_flags, ptr %52, i32 0, i32 0
  %337 = load i64, ptr %336, align 8
  %338 = invoke i64 @_Zan19script_verify_flagsS_(i64 %335, i64 %337)
          to label %339 unwind label %70

339:                                              ; preds = %333
  %340 = getelementptr inbounds nuw %class.script_verify_flags, ptr %50, i32 0, i32 0
  store i64 %338, ptr %340, align 8
  %341 = call noundef zeroext i1 @_ZNK19script_verify_flagscvbEv(ptr noundef nonnull align 8 dereferenceable(8) %50)
  br i1 %341, label %342, label %345

342:                                              ; preds = %339
  %343 = load ptr, ptr %14, align 8
  %344 = call noundef zeroext i1 @_ZN12_GLOBAL__N_19set_errorEP13ScriptError_tS0_(ptr noundef %343, i32 noundef 34)
  store i1 %344, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

345:                                              ; preds = %339
  store i1 true, ptr %8, align 1
  store i32 1, ptr %21, align 4
  br label %346

346:                                              ; preds = %345, %342, %331, %320, %317, %306, %270, %248, %227, %226, %177, %171, %147, %146, %122, %114, %105, %67
  call void @_ZN7CScriptD2Ev(ptr noundef nonnull align 8 dereferenceable(40) %16) #6
  %347 = load i1, ptr %8, align 1
  ret i1 %347

348:                                              ; preds = %70
  %349 = load ptr, ptr %19, align 8
  %350 = load i32, ptr %20, align 4
  %351 = insertvalue { ptr, i32 } poison, ptr %349, 0
  %352 = insertvalue { ptr, i32 } %351, i32 %350, 1
  resume { ptr, i32 } %352
}

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local ptr @_ZNKSt6vectorIhSaIhEE5beginEv(ptr noundef nonnull align 8 dereferenceable(24)) #0 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local ptr @_ZNKSt6vectorIhSaIhEE3endEv(ptr noundef nonnull align 8 dereferenceable(24)) #0 align 2

; Function Attrs: mustprogress noinline optnone uwtable
declare dso_local void @_ZN7CScriptC2ITkSt14input_iteratorN9__gnu_cxx17__normal_iteratorIPKhSt6vectorIhSaIhEEEEEET_S9_(ptr noundef nonnull align 8 dereferenceable(40), ptr, ptr) unnamed_addr #1 align 2

; Function Attrs: nounwind
declare i32 @memcmp(ptr noundef, ptr noundef, i64 noundef) #5

; Function Attrs: mustprogress noinline optnone uwtable
declare dso_local void @_ZN10HashWriterC2Ev(ptr noundef nonnull align 8 dereferenceable(104)) unnamed_addr #1 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef ptr @_ZNKSt6vectorIhSaIhEE4dataEv(ptr noundef nonnull align 8 dereferenceable(24)) #0 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef ptr @_ZN9base_blobILj256EE5beginEv(ptr noundef nonnull align 1 dereferenceable(32)) #0 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local void @_ZNSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EEC2IRKS0_IS2_SaIS2_EEQaaaaaaaaaaaantsr8__detailE9__is_spanINSt12remove_cvrefITL0__E4typeEEntsr8__detailE14__is_std_arrayISD_Ent10is_array_vISD_Esr6rangesE16contiguous_rangeISB_Esr6rangesE11sized_rangeISB_Eoosr6rangesE14borrowed_rangeISB_E10is_const_vIT_Esr19__is_compatible_refIDTdeclsr3stdE7declvalIRDTclsr6ranges13__cust_accessE7__beginclsr3stdE7declvalIRSB_EEEEEEEEE5valueEEOSE_(ptr noundef nonnull align 8 dereferenceable(16), ptr noundef nonnull align 8 dereferenceable(24)) unnamed_addr #0 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef i64 @_ZNKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EE4sizeEv(ptr noundef nonnull align 8 dereferenceable(16)) #0 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef nonnull align 8 dereferenceable(24) ptr @_Z11SpanPopBackIKSt6vectorIhSaIhEEERT_RSt4spanIS4_Lm18446744073709551615EE(ptr noundef nonnull align 8 dereferenceable(16)) #0

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef ptr @_ZN9prevectorILj36EhjiE4dataEv(ptr noundef nonnull align 8 dereferenceable(40)) #0 align 2

; Function Attrs: mustprogress noinline optnone uwtable
declare hidden noundef zeroext i1 @_ZL20ExecuteWitnessScriptRKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EERK7CScript19script_verify_flags10SigVersionRK20BaseSignatureCheckerR19ScriptExecutionDataP13ScriptError_t(ptr noundef nonnull align 8 dereferenceable(16), ptr noundef nonnull align 8 dereferenceable(40), i64, i32 noundef, ptr noundef nonnull align 8 dereferenceable(8), ptr noundef nonnull align 8 dereferenceable(121), ptr noundef) #1

; Function Attrs: mustprogress noinline optnone uwtable
declare dso_local noundef nonnull align 8 dereferenceable(40) ptr @_ZN7CScriptlsE10opcodetype(ptr noundef nonnull align 8 dereferenceable(40), i32 noundef) #1 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef nonnull align 8 dereferenceable(24) ptr @_ZNKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EE4backEv(ptr noundef nonnull align 8 dereferenceable(16)) #0 align 2

; Function Attrs: mustprogress noinline optnone uwtable
declare dso_local noundef nonnull align 8 dereferenceable(104) ptr @_ZN10HashWriterlsISt6vectorIhSaIhEEEERS_RKT_(ptr noundef nonnull align 8 dereferenceable(104), ptr noundef nonnull align 8 dereferenceable(24)) #1 align 2

; Function Attrs: mustprogress noinline nounwind optnone uwtable
declare dso_local noundef nonnull align 8 dereferenceable(24) ptr @_ZNKSt4spanIKSt6vectorIhSaIhEELm18446744073709551615EE5frontEv(ptr noundef nonnull align 8 dereferenceable(16)) #0 align 2

; Function Attrs: mustprogress noinline optnone uwtable
declare hidden noundef zeroext i1 @_ZL23VerifyTaprootCommitmentRKSt6vectorIhSaIhEES3_RK7uint256(ptr noundef nonnull align 8 dereferenceable(24), ptr noundef nonnull align 8 dereferenceable(24), ptr noundef nonnull align 1 dereferenceable(32)) #1

; Function Attrs: mustprogress noinline optnone uwtable
declare dso_local noundef i64 @_Z16GetSerializeSizeISt6vectorIS0_IhSaIhEESaIS2_EEEmRKT_(ptr noundef nonnull align 8 dereferenceable(24)) #1

declare noundef zeroext i1 @_ZN7CScript13IsPayToAnchorEiRKSt6vectorIhSaIhEE(i32 noundef, ptr noundef nonnull align 8 dereferenceable(24)) #3

attributes #0 = { mustprogress noinline nounwind optnone uwtable "frame-pointer"="all" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #1 = { mustprogress noinline optnone uwtable "frame-pointer"="all" "min-legal-vector-width"="0" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #2 = { nocallback nofree nounwind willreturn memory(argmem: readwrite) }
attributes #3 = { "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #4 = { nocallback nofree nounwind willreturn memory(argmem: write) }
attributes #5 = { nounwind "frame-pointer"="all" "no-trapping-math"="true" "stack-protector-buffer-size"="8" "target-cpu"="x86-64" "target-features"="+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87" "tune-cpu"="generic" }
attributes #6 = { nounwind }
attributes #7 = { nounwind willreturn memory(read) }

!llvm.linker.options = !{}
!llvm.module.flags = !{!0, !1, !2, !3, !4}
!llvm.ident = !{!5}

!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
!2 = !{i32 7, !"PIE Level", i32 2}
!3 = !{i32 7, !"uwtable", i32 2}
!4 = !{i32 7, !"frame-pointer", i32 2}
!5 = !{!"Ubuntu clang version 20.1.2 (0ubuntu1~24.04.3)"}
