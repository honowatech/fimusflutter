import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../screens/add_expense_screen.dart';
import '../screens/add_scheduled_expense_screen.dart';
import '../screens/expense_screen.dart';
import '../screens/main_screen.dart';
import '../utils/app_theme.dart';
import 'add_account_bottom_sheet.dart';

/// Menu FAB de l'onglet Dépenses (dépense, entrée, compte, programmée).
class AddTransactionSheet {
  static void show(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (dialogContext) {
        // Pastilles d'identité des quatre actions : les teintes claires sont
        // celles d'origine ; en sombre on passe sur des variantes plus denses
        // pour garder l'icône blanche lisible.
        final scheme = Theme.of(dialogContext).colorScheme;
        final expenseColor = scheme.tone(
          light: const Color(0xFFFF5252), // Colors.redAccent
          dark: const Color(0xFFC62828),
        );
        final incomeColor = scheme.tone(
          light: const Color(0xFF4CAF50), // Colors.green
          dark: const Color(0xFF2E7D32),
        );
        final accountColor = scheme.tone(
          light: const Color(0xFF2196F3), // Colors.blue
          dark: const Color(0xFF1565C0),
        );
        final scheduledColor = scheme.tone(
          light: const Color(0xFFFFC107), // Colors.amber
          dark: const Color(0xFF7A5400),
        );
        const onAccent = Colors.white;

        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  l10n.newOperation,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: expenseColor,
                  child: const Icon(Icons.arrow_upward, color: onAccent),
                ),
                title: Text(l10n.expense),
                onTap: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddExpenseScreen(isIncome: false),
                    ),
                  );
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: incomeColor,
                  child: const Icon(Icons.arrow_downward, color: onAccent),
                ),
                title: Text(l10n.income),
                onTap: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddExpenseScreen(isIncome: true),
                    ),
                  );
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: accountColor,
                  child: const Icon(
                    Icons.account_balance_wallet,
                    color: onAccent,
                  ),
                ),
                title: const Text('Compte'),
                onTap: () {
                  Navigator.pop(dialogContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    AddAccountBottomSheet.show(context, onSuccess: () {
                      MainScreen.of(context)?.setSelectedIndex(1);
                      ExpenseScreen.navigateToTab(2);
                    });
                  });
                },
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheduledColor,
                  child: const Icon(Icons.schedule, color: onAccent),
                ),
                title: Text(l10n.scheduledExpense),
                onTap: () {
                  Navigator.pop(dialogContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddScheduledExpenseScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}
