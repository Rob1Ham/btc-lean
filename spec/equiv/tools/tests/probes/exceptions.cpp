extern "C" int f(int x) {
  try {
    if (x) throw 1;
    return 0;
  } catch (int) {
    return 7;
  }
}
