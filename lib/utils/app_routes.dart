import 'package:flutter/material.dart';
import '../screens/contacts_screen.dart';
import '../screens/debt_detail_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/scheduled_expense_review_screen.dart';

/// Routes nommées utilisées par les taps de notification.
class AppRoutes {
  static const notifications = '/notifications';
  static const contacts = '/contacts';
  static const scheduledExpense = '/scheduled-expense';
  static const debtDetail = '/debt-detail';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case notifications:
        return MaterialPageRoute(
          builder: (_) => const NotificationsScreen(),
          settings: settings,
        );
      case contacts:
        return MaterialPageRoute(
          builder: (_) => const ContactsScreen(),
          settings: settings,
        );
      case scheduledExpense:
        final id = settings.arguments is String
            ? settings.arguments as String
            : '';
        return MaterialPageRoute(
          builder: (_) => ScheduledExpenseReviewScreen(expenseId: id),
          settings: settings,
        );
      case debtDetail:
        final tag = settings.arguments is String
            ? settings.arguments as String
            : '';
        return MaterialPageRoute(
          builder: (_) => DebtDetailScreen(debtTag: tag),
          settings: settings,
        );
      default:
        return null;
    }
  }
}
