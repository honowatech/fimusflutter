import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../main.dart';
import '../../providers/expense_provider.dart';
import '../../providers/security_provider.dart';
import '../../screens/main_screen.dart';
import '../../utils/app_routes.dart';
import '../../utils/notification_route.dart';
import '../auth_service.dart';
import 'pending_notification_store.dart';

/// Index des onglets de `MainScreen` visés par un tap de notification
/// (0: accueil, 1: dépenses, 2: dettes, 3: écran spécialisé, 4: profil).
const homeTabIndex = 0;
const expensesTabIndex = 1;
const debtsTabIndex = 2;

/// Navigation issue des taps de notification. Respecte le verrou PIN.
class NotificationNavigator {
  bool isLocked(BuildContext context) {
    try {
      final security = Provider.of<SecurityProvider>(context, listen: false);
      return security.isAppLockEnabled && !security.isAppUnlocked;
    } catch (_) {
      return false;
    }
  }

  Future<void> open(Map<String, dynamic> data) async {
    final context = navigatorKey.currentContext;
    if (context == null || isLocked(context)) {
      await PendingNotificationStore.persistData(data);
      return;
    }
    await _push(context, NotificationRoute.fromData(data));
  }

  Future<void> _push(BuildContext context, NotificationRoute route) async {
    switch (route.target) {
      case NotificationTarget.contacts:
        Navigator.pushNamed(context, AppRoutes.contacts);
      case NotificationTarget.scheduledExpense:
        final expenseUuid = route.expenseId;
        if (expenseUuid != null && expenseUuid.isNotEmpty) {
          Navigator.pushNamed(
            context,
            AppRoutes.scheduledExpense,
            arguments: expenseUuid,
          );
        }
      case NotificationTarget.jointAccount:
        MainScreen.of(context)?.setSelectedIndex(homeTabIndex);
      case NotificationTarget.debt:
        final directDebtTag = route.debtTag;
        if (directDebtTag != null && directDebtTag.isNotEmpty) {
          Navigator.pushNamed(
            context,
            AppRoutes.debtDetail,
            arguments: directDebtTag,
          );
          return;
        }
        final expenseUuid = route.expenseId;
        if (expenseUuid != null && expenseUuid.isNotEmpty) {
          final expenseProvider =
              Provider.of<ExpenseProvider>(context, listen: false);
          try {
            final expense = expenseProvider.expenses
                .firstWhere((e) => e.id.toString() == expenseUuid);
            if (expense.debtTag != null && expense.debtTag!.isNotEmpty) {
              Navigator.pushNamed(
                context,
                AppRoutes.debtDetail,
                arguments: expense.debtTag,
              );
              return;
            }
          } catch (_) {}
        }
        MainScreen.of(context)?.setSelectedIndex(debtsTabIndex);
      case NotificationTarget.broadcast:
        // Une annonce (`mass_broadcast`) n'a pas d'écran dédié : son contenu
        // est servi par `AnnouncementService` et affiché dans le carrousel de
        // l'écran d'accueil. On ramène donc l'utilisateur à l'accueil (onglet
        // 0), en refermant les écrans empilés pour que le carrousel soit
        // effectivement visible. Le jour où un écran d'annonce existera, il
        // suffira de router ici sur `AppRoutes` avec `route.campaignId`.
        Navigator.of(context).popUntil((r) => r.isFirst);
        MainScreen.of(context)?.setSelectedIndex(homeTabIndex);
      case NotificationTarget.weeklyDigest:
        // Le bilan résume les dépenses de la semaine : l'onglet Dépenses est
        // le seul écran qui prolonge utilement le message (la boîte de
        // réception, route par défaut, n'apporterait rien de plus).
        Navigator.of(context).popUntil((r) => r.isFirst);
        MainScreen.of(context)?.setSelectedIndex(expensesTabIndex);
      case NotificationTarget.securityAlert:
        await _handleSecurityAlert(context, route);
      case NotificationTarget.unknown:
        _openInbox(context);
    }
  }

  void _openInbox(BuildContext context) {
    if (ModalRoute.of(context)?.settings.name == AppRoutes.notifications) {
      return;
    }
    Navigator.pushNamed(context, AppRoutes.notifications);
  }

  // --- Alerte « nouvelle connexion » (sprint 5) -----------------------------

  /// Tap sur une alerte `new_login` : propose l'action « Ce n'était pas moi »
  /// (révocation des autres sessions) avant de l'exécuter.
  ///
  /// L'appel n'arrive ici que par [open], donc après la garde de verrouillage
  /// (file d'intentions + [isLocked]) : une révocation de sessions ne peut
  /// pas partir sans déverrouillage préalable.
  ///
  /// Une confirmation explicite est demandée : la révocation est irréversible
  /// (elle déconnecte tous les autres appareils du compte) et un tap sur le
  /// corps d'une notification est trop facile à déclencher par accident.
  Future<void> _handleSecurityAlert(
    BuildContext context,
    NotificationRoute route,
  ) async {
    if (!route.canRevokeOtherSessions) {
      _openInbox(context);
      return;
    }

    final auth = AuthService();
    final localDeviceId = await auth.getDeviceId();
    if (!context.mounted) return;

    // Garde-fou : l'appareil courant ne se révoque jamais lui-même. Si
    // l'alerte décrit cet appareil-ci (connexion légitime signalée à cause
    // d'un `device_id` manquant sur une version antérieure), déclencher la
    // révocation couperait nos propres sessions.
    final alertDeviceId = route.deviceId;
    if (alertDeviceId != null && alertDeviceId == localDeviceId) {
      _openInbox(context);
      return;
    }

    final confirmed = await _confirmRevoke(context, route);
    if (confirmed != true || !context.mounted) return;

    // Messager et traductions résolus AVANT l'appel réseau : le contexte
    // peut être démonté pendant la révocation.
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final result = await auth.revokeOtherSessions(
      endpoint: route.actionEndpoint,
    );
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result == null
                ? l10n.revokeOtherSessionsError
                : l10n.revokeOtherSessionsDone(
                    result.revokedSessions,
                    result.revokedDevices,
                  ),
          ),
        ),
      );
  }

  /// Confirmation avant révocation. Les libellés du serveur (`action_label`,
  /// déjà traduits selon la locale du compte) sont préférés quand ils sont
  /// présents.
  Future<bool?> _confirmRevoke(
    BuildContext context,
    NotificationRoute route,
  ) {
    final details = <String>[
      if (route.deviceLabel != null) route.deviceLabel!,
      if (route.location != null) route.location!,
    ].join(' — ');

    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.newLoginConfirmTitle),
        content: Text(
          details.isEmpty
              ? l10n.newLoginConfirmBody
              : l10n.newLoginConfirmBodyWithDetails(details),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            // Le serveur envoie déjà ce libellé traduit dans le payload.
            child: Text(route.actionLabel ?? l10n.newLoginConfirmAction),
          ),
        ],
      ),
    );
  }
}
