// Behavioral runner for E3 cells (NOT proof evidence).
// C and L functions are renamed at compile time so both can be linked into one
// binary; both call the same linked checker stub.
#include <cstdio>
#include <cstdint>

#ifdef BEHAVIOR_CHECKER
extern "C" uint64_t c_cell_checksig();
extern "C" uint64_t l_cell_checksig();
extern "C" uint64_t c_cell_checksigverify();
extern "C" uint64_t l_cell_checksigverify();
extern "C" uint64_t c_cell_checksig_underflow();
extern "C" uint64_t l_cell_checksig_underflow();
int main() {
  printf("cell_checksig %llx %llx\n",
         (unsigned long long)c_cell_checksig(), (unsigned long long)l_cell_checksig());
  printf("cell_checksigverify %llx %llx\n",
         (unsigned long long)c_cell_checksigverify(), (unsigned long long)l_cell_checksigverify());
  printf("cell_checksig_underflow %llx %llx\n",
         (unsigned long long)c_cell_checksig_underflow(), (unsigned long long)l_cell_checksig_underflow());
  return 0;
}
#else
extern "C" uint64_t c_cell_cms();
extern "C" uint64_t l_cell_cms();
extern "C" uint64_t c_cell_cmsverify();
extern "C" uint64_t l_cell_cmsverify();
extern "C" uint64_t c_cell_cms_nulldummy();
extern "C" uint64_t l_cell_cms_nulldummy();
extern "C" uint64_t c_cell_cms_empty();
extern "C" uint64_t l_cell_cms_empty();
int main() {
  printf("cell_cms %llx %llx\n",
         (unsigned long long)c_cell_cms(), (unsigned long long)l_cell_cms());
  printf("cell_cmsverify %llx %llx\n",
         (unsigned long long)c_cell_cmsverify(), (unsigned long long)l_cell_cmsverify());
  printf("cell_cms_nulldummy %llx %llx\n",
         (unsigned long long)c_cell_cms_nulldummy(), (unsigned long long)l_cell_cms_nulldummy());
  printf("cell_cms_empty %llx %llx\n",
         (unsigned long long)c_cell_cms_empty(), (unsigned long long)l_cell_cms_empty());
  return 0;
}
#endif
