#!/usr/bin/env python3
"""Execute the unchanged pinned Core witness dispatcher at abstract EC seams.

Container/flag/serialization shims; SHA256 is real. Commitment and Schnorr
verdicts and inner execution are explicit test parameters. This tests actual
Core dispatch/order/dataflow, NOT EC arithmetic, signature hashing, a parser
or whole-Core block acceptance. Real crypto is tested separately with the
byte-identical official BIP341 corpus and independent Python signatures.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from check_sigops_core import SOURCE_PAIRS, extract, require

SHIM = r'''
#include <CommonCrypto/CommonDigest.h>
#include <array>
#include <cassert>
#include <cstring>
#include <iostream>
#include <span>
#include <string>
#include <vector>
using valtype=std::vector<unsigned char>;
using uint256=std::array<unsigned char,32>;
using script_verify_flags=unsigned;
constexpr unsigned SCRIPT_VERIFY_TAPROOT=1, SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION=2,
 SCRIPT_VERIFY_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM=4;
constexpr int WITNESS_V0_SCRIPTHASH_SIZE=32,WITNESS_V0_KEYHASH_SIZE=20,WITNESS_V1_TAPROOT_SIZE=32,
 ANNEX_TAG=0x50,TAPROOT_CONTROL_BASE_SIZE=33,TAPROOT_CONTROL_MAX_SIZE=4129,
 TAPROOT_CONTROL_NODE_SIZE=32,TAPROOT_LEAF_MASK=0xfe,TAPROOT_LEAF_TAPSCRIPT=0xc0,
 VALIDATION_WEIGHT_OFFSET=50,OP_DUP=0x76,OP_HASH160=0xa9,OP_EQUALVERIFY=0x88,OP_CHECKSIG=0xac;
enum class SigVersion { WITNESS_V0,TAPROOT,TAPSCRIPT };
using ScriptError=std::string;
const char* SCRIPT_ERR_WITNESS_PROGRAM_WITNESS_EMPTY="witnessProgramWitnessEmpty";
const char* SCRIPT_ERR_WITNESS_PROGRAM_MISMATCH="witnessProgramMismatch";
const char* SCRIPT_ERR_WITNESS_PROGRAM_WRONG_LENGTH="witnessProgramWrongLength";
const char* SCRIPT_ERR_TAPROOT_WRONG_CONTROL_SIZE="taprootWrongControlSize";
const char* SCRIPT_ERR_DISCOURAGE_UPGRADABLE_TAPROOT_VERSION="discourageUpgradableTaprootVersion";
const char* SCRIPT_ERR_DISCOURAGE_UPGRADABLE_WITNESS_PROGRAM="discourageUpgradableWitnessProgram";
bool set_error(ScriptError* e,const char* s){*e=s;return false;}
bool set_success(ScriptError* e){*e="pass";return true;}
struct CScript:valtype {
 using valtype::vector;
 CScript& operator<<(int v){push_back(v);return *this;}
 CScript& operator<<(const valtype& v){insert(end(),v.begin(),v.end());return *this;}
 static bool IsPayToAnchor(int v,const valtype& p){return v==1&&p==valtype({0x4e,0x73});}
};
struct CScriptWitness {std::vector<valtype> stack;};
struct ScriptExecutionData {
 uint256 m_annex_hash{},m_tapleaf_hash{};
 bool m_annex_present=false,m_annex_init=false,m_tapleaf_hash_init=false,m_validation_weight_left_init=false;
 int64_t m_validation_weight_left=0;
};
struct CSHA256 {
 valtype bytes;
 CSHA256& Write(const unsigned char* p,size_t n){bytes.insert(bytes.end(),p,p+n);return *this;}
 void Finalize(unsigned char* out){CC_SHA256(bytes.data(),bytes.size(),out);}
};
size_t csSize(size_t n){return n<253?1:n<=65535?3:n<=0xffffffff?5:9;}
size_t GetSerializeSize(const std::vector<valtype>& w){size_t s=csSize(w.size());for(auto& a:w)s+=csSize(a.size())+a.size();return s;}
struct HashWriter {valtype bytes;HashWriter& operator<<(const valtype& a){
 assert(a.size()<253);bytes.push_back(a.size());bytes.insert(bytes.end(),a.begin(),a.end());return *this;}
 uint256 GetSHA256(){uint256 out{};CC_SHA256(bytes.data(),bytes.size(),out.data());return out;}};
template<class T>const T& SpanPopBack(std::span<const T>& s){auto& r=s.back();s=s.first(s.size()-1);return r;}
uint256 ComputeTapleafHash(int,const valtype&){return {};}
bool commitment=true,executed=false;ScriptExecutionData observed;
bool VerifyTaprootCommitment(const valtype&,const valtype&,const uint256&){return commitment;}
struct BaseSignatureChecker {
 const char* error=nullptr;
 bool CheckSchnorrSignature(const valtype&,const valtype&,SigVersion,ScriptExecutionData& ed,ScriptError* e) const {
  observed=ed;return error?set_error(e,error):set_success(e);}
};
bool ExecuteWitnessScript(std::span<const valtype>,const CScript&,script_verify_flags,SigVersion,
 const BaseSignatureChecker&,ScriptExecutionData& ed,ScriptError* e){executed=true;observed=ed;return set_success(e);}
'''

DRIVER = r'''
void test(const char* name,CScriptWitness w,int version,size_t size,unsigned flags,bool p2sh,
 bool q,const char* sigerror,const char* want,int budget=-1,int annex=-1){
 commitment=q;executed=false;observed={};ScriptError error="pass";BaseSignatureChecker checker{sigerror};
 bool ok=VerifyWitnessProgram(w,version,valtype(size,1),flags,checker,&error,p2sh);
 std::string actual=ok?"pass":error;
 if(actual!=want || (budget>=0&&(!executed||!observed.m_validation_weight_left_init||observed.m_validation_weight_left!=budget)) ||
 (annex>=0&&(!observed.m_annex_init||observed.m_annex_present!=bool(annex))))
  throw std::runtime_error(std::string("mismatch: ")+name+" actual="+actual);
 std::cout<<name<<"\t"<<actual<<"\n";
}
int main(){
 valtype control(33,1);control[0]=0xc0;
 valtype leaf={0x51},annex={0x50,0x99};
 test("active empty witness",{},1,32,1,false,true,nullptr,"witnessProgramWitnessEmpty");
 test("flag off empty witness",{},1,32,0,false,true,nullptr,"pass");
 test("future version empty witness",{},2,32,1,false,true,nullptr,"pass");
 test("future size empty witness",{},1,20,1,false,true,nullptr,"pass");
 test("wrapped taproot is upgradable",{},1,32,1,true,true,nullptr,"pass");
 test("v0 wrong program length",{},0,19,1,false,true,nullptr,"witnessProgramWrongLength");
 test("v0 wrong witness count",{},0,20,1,false,true,nullptr,"witnessProgramMismatch");
 test("bad control size",{{leaf,{1}}},1,32,1,false,false,nullptr,"taprootWrongControlSize");
 test("wrong script commitment",{{leaf,control}},1,32,1,false,false,nullptr,"witnessProgramMismatch");
 test("keypath typed error",{{valtype(63,1)}},1,32,1,false,true,"schnorrSigSize","schnorrSigSize",-1,0);
 test("keypath annex propagation",{{valtype(64,1),annex}},1,32,1,false,true,nullptr,"pass",-1,1);
 test("full witness budget",{{valtype(64,1),valtype(32,1),valtype(16,0x61),control}},1,32,1,false,true,nullptr,"pass",200,0);
 test("annex retained in budget",{{leaf,control,annex}},1,32,1,false,true,nullptr,"pass",90,1);
 control[0]=0xc2;
 test("upgradable leaf still binds q",{{leaf,control}},1,32,1,false,false,nullptr,"witnessProgramMismatch");
 test("upgradable leaf pass",{{leaf,control}},1,32,1,false,true,nullptr,"pass");
 test("upgradable leaf policy",{{leaf,control}},1,32,3,false,true,nullptr,"discourageUpgradableTaprootVersion");
 test("future witness policy",{},2,32,5,false,true,nullptr,"discourageUpgradableWitnessProgram");
}
'''

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--interpreter',type=Path,required=True)
    ap.add_argument('--output',type=Path)
    ap.add_argument('--cxx',default='c++')
    args=ap.parse_args()
    data=args.interpreter.read_bytes();sha=hashlib.sha256(data).hexdigest()
    pins={pair[1]:pin for pair,pin in SOURCE_PAIRS.items()}
    require(sha in pins,'unsupported Core interpreter source hash')
    body=extract(data.decode(),'static bool VerifyWitnessProgram(')
    comparisons={name:hashlib.sha256(extract(data.decode(),sig).encode()).hexdigest() for name,sig in
        [('VerifyWitnessProgram','static bool VerifyWitnessProgram('),('VerifyScript','bool VerifyScript('),
         ('SignatureHashSchnorr','bool SignatureHashSchnorr('),('CheckSequence','bool GenericTransactionSignatureChecker<T>::CheckSequence(')]}
    with tempfile.TemporaryDirectory(prefix='core-taproot-dispatch-') as folder:
        cpp,binary=Path(folder)/'check.cpp',Path(folder)/'check'
        cpp.write_text(SHIM+'\n'+body+'\n'+DRIVER)
        result=subprocess.run([args.cxx,'-std=c++20','-O2',str(cpp),'-o',str(binary)],capture_output=True,text=True,timeout=60)
        require(result.returncode==0,result.stdout+result.stderr)
        proc=subprocess.run([str(binary)],capture_output=True,text=True,timeout=30)
        require(proc.returncode==0,proc.stdout+proc.stderr)
    checks=dict(line.split('\t') for line in proc.stdout.splitlines())
    require(len(checks)==17,'incomplete cases')
    report=dict(core_commit=pins[sha],source_sha256=sha,functions_sha256=comparisons,checks=checks,
        scope=__doc__.strip(),cpp_standard='c++20',compile_timeout_seconds=60,execution_timeout_seconds=30)
    output=json.dumps(report,indent=2)+'\n'
    if args.output:args.output.write_text(output)
    print(output,end='')

if __name__=='__main__':main()
