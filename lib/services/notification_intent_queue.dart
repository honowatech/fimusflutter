import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import '../providers/security_provider.dart';
import 'notifications/pending_notification_store.dart';

/// File d'intentions de notification.
///
/// Deux natures d'intention y transitent : un *tap* (navigation issue du corps
/// de la notification) et une *action* (bouton « Confirmer » / « Annuler »).
///
/// Un tap ou un bouton d'action ne doit jamais court-circuiter l'écran de
/// verrouillage : `LockScreen` n'est que le widget racine renvoyé par
/// `_AuthGate` dans `main.dart`, donc une route poussée par-dessus resterait
/// visible et laisserait manipuler les données sans code PIN. Tant que l'app
/// n'est pas « prête » (utilisateur non authentifié, verrou PIN actif et non
/// levé, ou navigateur pas encore monté), l'intention est persistée via
/// [PendingNotificationStore] au lieu d'être exécutée, puis rejouée par
/// [drain] au déverrouillage, à la reprise de `MainScreen` et au démarrage.
///
/// La persistance (SharedPreferences) sert aussi de canal entre l'isolat
/// d'arrière-plan des boutons de notification et l'isolat principal : un champ
/// statique n'est pas partagé entre les deux.
class NotificationIntentQueue {
  NotificationIntentQueue._internal();

  static final NotificationIntentQueue instance =
      NotificationIntentQueue._internal();

  /// Exécution réelle d'un tap (navigation), branchée par NotificationService.
  Future<void> Function(Map<String, dynamic> data)? onTap;

  /// Exécution réelle d'un bouton d'action, branchée par NotificationService.
  Future<void> Function(String actionId, String expenseUuid)? onAction;

  bool _draining = false;

  /// L'app peut-elle recevoir une navigation / exécuter une action maintenant ?
  ///
  /// On passe par `navigatorKey.currentContext` comme le reste du service :
  /// c'est le seul contexte disponible depuis un callback de notification.
  bool isReady() {
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) return false;
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.status != AuthStatus.authenticated) return false;
    } catch (_) {
      // Providers indisponibles (arbre pas encore construit) : pas prêt.
      return false;
    }
    try {
      final security = Provider.of<SecurityProvider>(context, listen: false);
      // Tant que les préférences ne sont pas lues, `isAppLockEnabled` vaut
      // false par défaut : agir maintenant reviendrait à pousser une route
      // juste avant que LockScreen ne s'affiche.
      if (!security.isSettingsLoaded) return false;
      if (security.isAppLockEnabled && !security.isAppUnlocked) return false;
    } catch (_) {
      return false;
    }
    return true;
  }

  /// Soumet un tap : exécuté si l'app est prête, mis en file sinon.
  Future<void> submitTap(Map<String, dynamic> data) async {
    if (!isReady()) {
      await PendingNotificationStore.persistData(data);
      return;
    }
    await _runTap(data);
  }

  /// Soumet une action de bouton : exécutée si l'app est prête, mise en file
  /// sinon (cas critique : `scheduled_confirm` débite un compte).
  Future<void> submitAction(String actionId, String expenseUuid) async {
    if (!isReady()) {
      await PendingNotificationStore.persistAction(
          {'action': actionId, 'expense_uuid': expenseUuid});
      return;
    }
    await _runAction(actionId, expenseUuid);
  }

  /// Met en file une réponse brute du plugin (lancement à froid, isolat
  /// d'arrière-plan) sans tenter de l'exécuter.
  Future<void> enqueueRawResponse(String? actionId, String? payload) async {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      if (actionId != null && actionId.isNotEmpty) {
        final expenseUuid = data['expense_uuid']?.toString();
        if (expenseUuid == null || expenseUuid.isEmpty) return;
        await PendingNotificationStore.persistAction(
            {'action': actionId, 'expense_uuid': expenseUuid});
        return;
      }
      await PendingNotificationStore.persistData(data);
    } catch (e) {
      debugPrint('Error enqueuing notification response: $e');
    }
  }

  /// Met en file un payload déjà décodé (message FCM initial).
  Future<void> enqueueData(Map<String, dynamic> data) =>
      PendingNotificationStore.persistData(data);

  /// Rejoue les intentions en attente si l'app est prête.
  ///
  /// Appelé au montage de `MainScreen`, à chaque retour au premier plan et
  /// juste après un déverrouillage réussi (code PIN ou biométrie).
  /// Idempotent : chaque intention est retirée du stockage avant exécution et
  /// un verrou évite les rejeux concurrents.
  Future<void> drain() async {
    if (_draining) return;
    _draining = true;
    try {
      // Relecture systématique : l'isolat d'arrière-plan a pu écrire pendant
      // que l'app était en tâche de fond, sans que le champ statique bouge.
      await PendingNotificationStore.restore();
      if (!isReady()) return;

      final data = PendingNotificationStore.pendingData;
      if (data != null) {
        await PendingNotificationStore.clear(data: true);
        await _runTap(data);
      }

      final pending = PendingNotificationStore.pendingAction;
      if (pending != null) {
        await PendingNotificationStore.clear(action: true);
        final actionId = pending['action']?.toString();
        final expenseUuid = pending['expense_uuid']?.toString();
        if (actionId != null &&
            actionId.isNotEmpty &&
            expenseUuid != null &&
            expenseUuid.isNotEmpty) {
          await _runAction(actionId, expenseUuid);
        }
      }
    } finally {
      _draining = false;
    }
  }

  Future<void> _runTap(Map<String, dynamic> data) async {
    final handler = onTap;
    if (handler == null) {
      await PendingNotificationStore.persistData(data);
      return;
    }
    try {
      await handler(data);
    } catch (e) {
      debugPrint('Error running notification tap intent: $e');
    }
  }

  Future<void> _runAction(String actionId, String expenseUuid) async {
    final handler = onAction;
    if (handler == null) {
      await PendingNotificationStore.persistAction(
          {'action': actionId, 'expense_uuid': expenseUuid});
      return;
    }
    try {
      await handler(actionId, expenseUuid);
    } catch (e) {
      debugPrint('Error running notification action intent: $e');
    }
  }
}
