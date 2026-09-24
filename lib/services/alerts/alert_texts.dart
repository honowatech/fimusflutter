import '../../l10n/app_localizations.dart';
import '../notifications/notification_texts.dart';
import 'alert_models.dart';

/// Mise en mots des alertes locales.
///
/// Séparée de la décision (`alert_evaluator.dart`, pure) et de l'affichage
/// (`local_alerts_service.dart`, plugin). Les traductions arrivent par
/// paramètre : aucun `BuildContext` n'est requis, la langue est celle résolue
/// par `NotificationTexts` (isolat compris).
class AlertTexts {
  AlertTexts._();

  /// Titre affiché pour une alerte. Fonction pure (à `texts` donné).
  static String titleFor(PendingAlert alert, AppLocalizations texts) =>
      switch (alert) {
        BudgetThresholdAlert a => a.tier >= 100
            ? texts.alertBudgetReachedTitle
            : texts.alertBudgetWarningTitle,
        LowBalanceAlert _ => texts.alertLowBalanceTitle,
        UnsyncedDataAlert _ => texts.alertUnsyncedTitle,
      };

  /// Corps affiché pour une alerte. Fonction pure (à `texts` donné).
  ///
  /// Les montants passent par `NotificationTexts.formatAmount` (séparateur de
  /// milliers, décimales seulement si elles existent), comme les rappels.
  static String bodyFor(PendingAlert alert, AppLocalizations texts) =>
      switch (alert) {
        BudgetThresholdAlert a => a.tier >= 100
            ? texts.alertBudgetReachedBody(
                a.category,
                a.consumedPercent,
                NotificationTexts.formatAmount(a.spent),
                NotificationTexts.formatAmount(a.budget),
                a.currency,
              )
            : texts.alertBudgetWarningBody(
                a.category,
                a.consumedPercent,
                NotificationTexts.formatAmount(a.spent),
                NotificationTexts.formatAmount(a.budget),
                a.currency,
              ),
        LowBalanceAlert a => texts.alertLowBalanceBody(
            a.accountName,
            NotificationTexts.formatAmount(a.balance),
            NotificationTexts.formatAmount(a.threshold),
            a.currency,
          ),
        UnsyncedDataAlert a => texts.alertUnsyncedBody(
            a.pendingCount,
            a.pendingSinceHours,
          ),
      };
}
