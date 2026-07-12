
void main() {
  try {
    String f() => null as dynamic;
    f();
  } catch(e) {
    print(e);
  }
}
