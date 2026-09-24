import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../models/notification_preferences.dart';
import '../providers/notification_preferences_provider.dart';
import 'settings_section_card.dart';

/// Interrupteurs par catégorie de notification.
///
/// Utilisé par `NotificationSettingsScreen`. Les modifications sont
/// optimistes : en cas d'échec réseau le provider restaure l'état précédent
/// et un message est affiché.
class NotificationPreferencesCard extends StatelessWidget {
  const NotificationPreferencesCard({super.key});

  Future<void> _apply(
    BuildContext context,
    NotificationPreferencesProvider provider,
    NotificationPreferences newPrefs,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final success = await provider.updatePreferences(newPrefs);
    if (success || !context.mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.notificationPreferencesSaveError)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Consumer<NotificationPreferencesProvider>(
      builder: (context, prefsProvider, _) {
        final prefs = prefsProvider.effectivePreferences;
        final busy = prefsProvider.isLoading || prefsProvider.isSaving;

        Widget buildSwitch({
          required IconData icon,
          required String title,
          required String subtitle,
          required bool value,
          required NotificationPreferences Function(bool) update,
        }) {
          return SwitchListTile(
            secondary: Icon(
              icon,
              color: value
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(title),
            subtitle: Text(subtitle),
            value: value,
            onChanged: busy
                ? null
                : (newValue) => _apply(context, prefsProvider, update(newValue)),
          );
        }

        return SettingsSectionCard(
          title: l10n.notificationCategoriesSection,
          icon: Icons.notifications_outlined,
          theme: theme,
          children: [
            buildSwitch(
              icon: Icons.compare_arrows_rounded,
              title: l10n.notifyDebtsPref,
              subtitle: l10n.notifyDebtsPrefDesc,
              value: prefs.notifyDebts,
              update: (v) => prefs.copyWith(notifyDebts: v),
            ),
            const Divider(height: 1, indent: 16),
            buildSwitch(
              icon: Icons.person_add_alt_1_rounded,
              title: l10n.notifyContactsPref,
              subtitle: l10n.notifyContactsPrefDesc,
              value: prefs.notifyContacts,
              update: (v) => prefs.copyWith(notifyContacts: v),
            ),
            const Divider(height: 1, indent: 16),
            buildSwitch(
              icon: Icons.account_balance_wallet_outlined,
              title: l10n.notifyJointAccountsPref,
              subtitle: l10n.notifyJointAccountsPrefDesc,
              value: prefs.notifyJointAccounts,
              update: (v) => prefs.copyWith(notifyJointAccounts: v),
            ),
            const Divider(height: 1, indent: 16),
            buildSwitch(
              icon: Icons.event_repeat_rounded,
              title: l10n.notifyScheduledExpensesPref,
              subtitle: l10n.notifyScheduledExpensesPrefDesc,
              value: prefs.notifyScheduledExpenses,
              update: (v) => prefs.copyWith(notifyScheduledExpenses: v),
            ),
            const Divider(height: 1, indent: 16),
            buildSwitch(
              icon: Icons.campaign_outlined,
              title: l10n.notifyAnnouncementsPref,
              subtitle: l10n.notifyAnnouncementsPrefDesc,
              value: prefs.notifyAnnouncements,
              update: (v) => prefs.copyWith(notifyAnnouncements: v),
            ),
            const Divider(height: 1, indent: 16),
            // Bilan hebdomadaire (dixième clé du contrat serveur).
            buildSwitch(
              icon: Icons.insights_outlined,
              title: l10n.notifyWeeklyDigestPref,
              subtitle: l10n.notifyWeeklyDigestPrefDesc,
              value: prefs.notifyWeeklyDigest,
              update: (v) => prefs.copyWith(notifyWeeklyDigest: v),
            ),
          ],
        );
      },
    );
  }
}
