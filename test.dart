
class Expense {
  final String category;
  Expense({required this.category});
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(category: json['category']);
  }
}
void main() {
  try {
    var e = Expense.fromJson({'category': null});
    print(e.category);
  } catch (err) {
    print(err);
  }
}
