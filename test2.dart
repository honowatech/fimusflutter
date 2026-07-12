
void main() {
  try {
    String Function() f = () => null as dynamic;
    f();
  } catch(e) {
    print(e);
  }
}
