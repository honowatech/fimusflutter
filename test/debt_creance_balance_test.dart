import 'package:flutter_test/flutter_test.dart';
import 'package:monitrack/models/expense.dart';

void main() {
  group('Debt and Créance Balance Logic Tests', () {
    test('Lending money (Prêt) creates a positive balance (Créance)', () {
      final pret = Expense(
        id: '1',
        title: 'Prêt à Alice',
        amount: 10000.0,
        category: 'Dette',
        date: DateTime.now(),
        type: 'expense',
        debtTag: 'Alice',
      );

      // Formula: type == 'expense' -> + amount
      final balance = pret.type == 'expense' ? pret.amount : -pret.amount;
      expect(balance, equals(10000.0));
      expect(balance > 0, isTrue); // Positive balance = Créance (On nous doit de l'argent)
    });

    test('Borrowing money (Emprunt) creates a negative balance (Dette)', () {
      final emprunt = Expense(
        id: '2',
        title: 'Emprunt à Bob',
        amount: 5000.0,
        category: 'Dette',
        date: DateTime.now(),
        type: 'income',
        debtTag: 'Bob',
      );

      // Formula: type == 'expense' -> + amount, else -> - amount
      final balance = emprunt.type == 'expense' ? emprunt.amount : -emprunt.amount;
      expect(balance, equals(-5000.0));
      expect(balance < 0, isTrue); // Negative balance = Dette (On doit de l'argent)
    });

    test('Collecting repayment reduces Créance balance', () {
      final pret = Expense(
        id: '1',
        title: 'Prêt à Alice',
        amount: 10000.0,
        category: 'Dette',
        date: DateTime.now(),
        type: 'expense',
        debtTag: 'Alice',
      );

      final encaissement = Expense(
        id: '2',
        title: 'Remboursement perçu',
        amount: 4000.0,
        category: 'Remboursement',
        date: DateTime.now(),
        type: 'income',
        debtTag: 'Alice',
      );

      final expenses = [pret, encaissement];
      final totalBalance = expenses.fold(
        0.0,
        (sum, e) => sum + (e.type == 'expense' ? e.amount : -e.amount),
      );

      expect(totalBalance, equals(6000.0)); // 10,000 - 4,000 = 6,000 remaining créance
    });

    test('Repaying debt reduces Debt balance towards zero', () {
      final emprunt = Expense(
        id: '1',
        title: 'Emprunt à Bob',
        amount: 5000.0,
        category: 'Dette',
        date: DateTime.now(),
        type: 'income',
        debtTag: 'Bob',
      );

      final remboursement = Expense(
        id: '2',
        title: 'Dette remboursée',
        amount: 2000.0,
        category: 'Remboursement',
        date: DateTime.now(),
        type: 'expense',
        debtTag: 'Bob',
      );

      final expenses = [emprunt, remboursement];
      final totalBalance = expenses.fold(
        0.0,
        (sum, e) => sum + (e.type == 'expense' ? e.amount : -e.amount),
      );

      expect(totalBalance, equals(-3000.0)); // -5,000 + 2,000 = -3,000 remaining debt
    });
  });
}
