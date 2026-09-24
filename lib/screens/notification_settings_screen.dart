import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../models/account.dart';
import '../models/notification_preferences.dart';
import '../providers/account_provider.dart';
import '../providers/alert_settings_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/notification_preferences_provider.dart';
import '../services/alerts/alert_settings.dart';
import '../services/alerts/alert_settings_store.dart';
import '../services/alerts/local_alerts_hook.dart';
import '../services/notification_permission_service.dart';
import '../services/notifications/notification_texts.dart';
import '../utils/category_normalizer.dart';
import '../widgets/notification_preferences_card.dart';
import '../widgets/settings_section_card.dart';

/// Écran « Profil → Notifications ».
///
/// Regroupe l'état de la permission système, les interrupteurs par catégorie,
/// l'heure des rappels d'échéance et les heures calmes.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  /// `null` tant que l'état des alarmes exactes n'a pas été lu.
  bool? _exactAlarmsAllowed;

  /// Devise du profil, utilisée pour afficher budgets et seuils.
  String _currency = AlertSettingsStore.fallbackCurrency;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshAll();
      final prefsProvider = context.read<NotificationPreferencesProvider>();
      // Cache local d'abord (lisible hors ligne), puis rafraîchissement
      // serveur.
      prefsProvider.loadCachedPreferences().then((_) {
        if (mounted) prefsProvider.fetchPreferences();
      });
      // Alertes locales : réglages purement locaux, aucun appel réseau.
      context.read<AlertSettingsProvider>().load();
      _loadCurrency();
    });
  }

  Future<void> _loadCurrency() async {
    final currency = await const AlertSettingsStore().readCurrency();
    if (!mounted || currency == _currency) return;
    setState(() => _currency = currency);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Retour depuis les réglages système : l'autorisation a pu changer.
    if (state == AppLifecycleState.resumed) _refreshAll();
  }

  Future<void> _refreshAll() async {
    if (!mounted) return;
    final permissionService = context.read<NotificationPermissionService>();
    await permissionService.checkPermission();
    final allowed = await permissionService.canScheduleExactAlarms();
    if (!mounted) return;
    setState(() => _exactAlarmsAllowed = allowed);
  }

  // --- Permission système --------------------------------------------------

  /// Demande contextualisée : on explique d'abord pourquoi, puis on affiche la
  /// boîte de dialogue système (ou on renvoie vers les réglages si le système
  /// ne la présente plus).
  Future<void> _handlePermissionRequest(
    NotificationPermissionService service,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    if (service.isPermanentlyDenied) {
      await service.openSettings();
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.notificationPermissionRationaleTitle),
        content: Text(l10n.notificationPermissionRationaleBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.notificationPermissionRationaleDismiss),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.notificationPermissionRationaleConfirm),
          ),
        ],
      ),
    );

    if (accepted != true || !mounted) return;

    final granted = await service.requestPermission();
    if (!mounted || granted) return;

    // Le système n'a pas (re)présenté la boîte de dialogue : seul un passage
    // par les réglages débloque la situation.
    if (service.isPermanentlyDenied) {
      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.notificationPermissionSettingsHint),
            action: SnackBarAction(
              label: l10n.notificationPermissionOpenSettings,
              onPressed: service.openSettings,
            ),
          ),
        );
    }
  }

  Widget _buildPermissionCard(ThemeData theme, AppLocalizations l10n) {
    return Consumer<NotificationPermissionService>(
      builder: (context, service, _) {
        final (IconData icon, Color color, String title, String description) =
            switch (service.status) {
          NotificationPermissionStatus.granted => (
              Icons.notifications_active_rounded,
              Colors.green.shade600,
              l10n.notificationPermissionGranted,
              l10n.notificationPermissionGrantedDesc,
            ),
          NotificationPermissionStatus.denied => (
              Icons.notifications_off_rounded,
              Colors.orange.shade800,
              l10n.notificationPermissionDenied,
              l10n.notificationPermissionDeniedDesc,
            ),
          NotificationPermissionStatus.unknown => (
              Icons.help_outline_rounded,
              Colors.grey.shade600,
              l10n.notificationPermissionUnknown,
              l10n.notificationPermissionUnknownDesc,
            ),
        };

        return SettingsSectionCard(
          title: l10n.notificationPermissionSection,
          icon: Icons.verified_user_outlined,
          theme: theme,
          children: [
            ListTile(
              leading: Icon(icon, color: color),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(description),
              isThreeLine: !service.isExplicitlyGranted,
            ),
            if (!service.isExplicitlyGranted) ...[
              if (service.isPermanentlyDenied)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    l10n.notificationPermissionSettingsHint,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _refreshAll,
                      child: Text(l10n.notificationPermissionCheck),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => _handlePermissionRequest(service),
                      icon: Icon(
                        service.isPermanentlyDenied
                            ? Icons.settings_rounded
                            : Icons.notifications_rounded,
                        size: 18,
                      ),
                      label: Text(
                        service.isPermanentlyDenied
                            ? l10n.notificationPermissionOpenSettings
                            : l10n.activate,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // --- Rappels -------------------------------------------------------------

  Future<void> _pickTime({
    required NotificationPreferencesProvider provider,
    required TimeOfDay initial,
    required NotificationPreferences Function(String) update,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final success = await provider.updatePreferences(
      update(NotificationPreferences.formatTime(picked)),
    );
    if (success || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.notificationPreferencesSaveError)),
      );
  }

  Future<void> _setQuietHoursEnabled(
    NotificationPreferencesProvider provider,
    NotificationPreferences prefs,
    bool enabled,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final success = await provider
        .updatePreferences(prefs.copyWith(quietHoursEnabled: enabled));
    if (success || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(l10n.notificationPreferencesSaveError)),
      );
  }

  Widget _buildReminderCard(ThemeData theme, AppLocalizations l10n) {
    return Consumer<NotificationPreferencesProvider>(
      builder: (context, provider, _) {
        final prefs = provider.effectivePreferences;
        final busy = provider.isLoading || provider.isSaving;
        final crossesMidnight = prefs.quietHoursEnabled &&
            (prefs.quietStartTime.hour * 60 + prefs.quietStartTime.minute) >
                (prefs.quietEndTime.hour * 60 + prefs.quietEndTime.minute);

        return SettingsSectionCard(
          title: l10n.reminderScheduleSection,
          icon: Icons.schedule_rounded,
          theme: theme,
          children: [
            ListTile(
              leading: Icon(
                Icons.alarm_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(l10n.reminderHourTitle),
              subtitle: Text(l10n.reminderHourDesc),
              trailing: Text(
                prefs.reminderTime.format(context),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
              onTap: busy
                  ? null
                  : () => _pickTime(
                        provider: provider,
                        initial: prefs.reminderTime,
                        update: (value) => prefs.copyWith(reminderHour: value),
                      ),
            ),
            const Divider(height: 1, indent: 16),
            SwitchListTile(
              secondary: Icon(
                Icons.bedtime_outlined,
                color: prefs.quietHoursEnabled
                    ? theme.colorScheme.primary
                    : Colors.grey,
              ),
              title: Text(l10n.quietHoursTitle),
              subtitle: Text(l10n.quietHoursDesc),
              value: prefs.quietHoursEnabled,
              onChanged: busy
                  ? null
                  : (value) => _setQuietHoursEnabled(provider, prefs, value),
            ),
            if (prefs.quietHoursEnabled) ...[
              const Divider(height: 1, indent: 16),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                title: Text(l10n.quietHoursStartLabel),
                trailing: Text(
                  prefs.quietStartTime.format(context),
                  style: theme.textTheme.titleMedium,
                ),
                onTap: busy
                    ? null
                    : () => _pickTime(
                          provider: provider,
                          initial: prefs.quietStartTime,
                          update: (value) =>
                              prefs.copyWith(quietHoursStart: value),
                        ),
              ),
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: 16),
                title: Text(l10n.quietHoursEndLabel),
                trailing: Text(
                  prefs.quietEndTime.format(context),
                  style: theme.textTheme.titleMedium,
                ),
                onTap: busy
                    ? null
                    : () => _pickTime(
                          provider: provider,
                          initial: prefs.quietEndTime,
                          update: (value) =>
                              prefs.copyWith(quietHoursEnd: value),
                        ),
              ),
              if (crossesMidnight)
                Padding(
                  padding: const EdgeInsets.fromLTRB(72, 0, 16, 12),
                  child: Text(
                    l10n.quietHoursOvernightHint,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        );
      },
    );
  }

  // --- Alertes locales (budget, solde bas, synchronisation) ----------------

  /// Montant affiché avec la devise du profil.
  String _amountLabel(double value) =>
      '${NotificationTexts.formatAmount(value)} $_currency';

  /// Réévalue les alertes après un changement de réglage : l'utilisateur voit
  /// immédiatement l'effet de son budget ou de son seuil.
  Future<void> _reevaluateAlerts() async {
    if (!mounted) return;
    await runLocalAlerts(context, force: true);
  }

  /// Saisie d'un montant (budget ou seuil). Renvoie `null` si l'utilisateur
  /// annule ; la suppression d'une valeur passe par le bouton dédié de la
  /// liste, jamais par ce retour.
  Future<double?> _promptAmount({
    required String title,
    required String fieldLabel,
    required bool positiveOnly,
    double? initial,
  }) {
    return showDialog<double>(
      context: context,
      builder: (dialogContext) => _AmountPromptDialog(
        title: title,
        fieldLabel: fieldLabel,
        positiveOnly: positiveOnly,
        initial: initial,
        currency: _currency,
      ),
    );
  }

  Future<void> _openBudgetsDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final categories = [...context.read<ExpenseProvider>().expenseCategories]
      ..sort((a, b) => categorySortKey(a).compareTo(categorySortKey(b)));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.alertBudgetsDialogTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: categories.isEmpty
              ? Text(l10n.alertNoCategories)
              : Consumer<AlertSettingsProvider>(
                  builder: (context, provider, _) => ListView.builder(
                    shrinkWrap: true,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final category = normalizeCategory(categories[index]);
                      final budget = provider.settings.budgetFor(category);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(category),
                        subtitle: Text(budget == null
                            ? l10n.alertValueNotSet
                            : _amountLabel(budget)),
                        trailing: budget == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                tooltip: l10n.delete,
                                onPressed: () =>
                                    provider.setCategoryBudget(category, null),
                              ),
                        onTap: () async {
                          final amount = await _promptAmount(
                            title: category,
                            fieldLabel: l10n.alertBudgetFieldLabel,
                            positiveOnly: true,
                            initial: budget,
                          );
                          if (amount == null) return;
                          await provider.setCategoryBudget(category, amount);
                        },
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
    await _reevaluateAlerts();
  }

  Future<void> _openThresholdsDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final accounts = <Account>[...context.read<AccountProvider>().accounts];

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.alertThresholdsDialogTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: accounts.isEmpty
              ? Text(l10n.alertNoAccounts)
              : Consumer<AlertSettingsProvider>(
                  builder: (context, provider, _) => ListView.builder(
                    shrinkWrap: true,
                    itemCount: accounts.length,
                    itemBuilder: (context, index) {
                      final account = accounts[index];
                      final threshold =
                          provider.settings.thresholdFor(account.id);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(account.name),
                        subtitle: Text(threshold == null
                            ? l10n.alertValueNotSet
                            : _amountLabel(threshold)),
                        trailing: threshold == null
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.clear_rounded),
                                tooltip: l10n.delete,
                                onPressed: () => provider.setAccountThreshold(
                                    account.id, null),
                              ),
                        onTap: () async {
                          final amount = await _promptAmount(
                            title: account.name,
                            fieldLabel: l10n.alertThresholdFieldLabel,
                            positiveOnly: false,
                            initial: threshold,
                          );
                          if (amount == null) return;
                          await provider.setAccountThreshold(
                              account.id, amount);
                        },
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
    await _reevaluateAlerts();
  }

  Future<void> _pickUnsyncedDelay(AlertSettingsProvider provider) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(l10n.alertUnsyncedDelayTitle),
        children: [
          for (final hours in AlertSettings.unsyncedThresholdChoices)
            ListTile(
              title: Text(l10n.alertUnsyncedDelayValue(hours ~/ 24)),
              trailing: hours == provider.settings.unsyncedThresholdHours
                  ? Icon(
                      Icons.check_rounded,
                      color: Theme.of(dialogContext).colorScheme.primary,
                    )
                  : null,
              onTap: () => Navigator.of(dialogContext).pop(hours),
            ),
        ],
      ),
    );
    if (selected == null) return;
    await provider.setUnsyncedThresholdHours(selected);
    await _reevaluateAlerts();
  }

  Future<void> _resetEmissionState(AlertSettingsProvider provider) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    await provider.resetEmissionState();
    if (!mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.alertResetStateDone)));
  }

  Widget _buildLocalAlertsCard(ThemeData theme, AppLocalizations l10n) {
    return Consumer<AlertSettingsProvider>(
      builder: (context, provider, _) {
        final settings = provider.settings;
        final busy = provider.isBusy;

        Widget subEntry({
          required IconData icon,
          required String title,
          required String subtitle,
          required bool enabled,
          required VoidCallback onTap,
        }) {
          return ListTile(
            contentPadding: const EdgeInsets.only(left: 72, right: 16),
            leading: null,
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: Icon(icon, size: 18, color: theme.colorScheme.primary),
            enabled: enabled && !busy,
            onTap: enabled && !busy ? onTap : null,
          );
        }

        return SettingsSectionCard(
          title: l10n.localAlertsSection,
          icon: Icons.warning_amber_rounded,
          theme: theme,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                l10n.alertsLocalOnlyNotice,
                style: theme.textTheme.bodySmall,
              ),
            ),
            SwitchListTile(
              secondary: Icon(
                Icons.pie_chart_outline_rounded,
                color: settings.budgetAlertsEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(l10n.alertBudgetSwitchTitle),
              subtitle: Text(l10n.alertBudgetSwitchDesc),
              value: settings.budgetAlertsEnabled,
              onChanged: busy
                  ? null
                  : (value) async {
                      await provider.setBudgetAlertsEnabled(value);
                      await _reevaluateAlerts();
                    },
            ),
            subEntry(
              icon: Icons.chevron_right_rounded,
              title: l10n.alertBudgetsManageTitle,
              subtitle: settings.categoryBudgets.isEmpty
                  ? l10n.alertTrackedNone
                  : l10n.alertBudgetsCount(settings.categoryBudgets.length),
              enabled: settings.budgetAlertsEnabled,
              onTap: _openBudgetsDialog,
            ),
            const Divider(height: 1, indent: 16),
            SwitchListTile(
              secondary: Icon(
                Icons.account_balance_wallet_rounded,
                color: settings.lowBalanceAlertsEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(l10n.alertLowBalanceSwitchTitle),
              subtitle: Text(l10n.alertLowBalanceSwitchDesc),
              value: settings.lowBalanceAlertsEnabled,
              onChanged: busy
                  ? null
                  : (value) async {
                      await provider.setLowBalanceAlertsEnabled(value);
                      await _reevaluateAlerts();
                    },
            ),
            subEntry(
              icon: Icons.chevron_right_rounded,
              title: l10n.alertThresholdsManageTitle,
              subtitle: settings.accountThresholds.isEmpty
                  ? l10n.alertTrackedNone
                  : l10n.alertThresholdsCount(settings.accountThresholds.length),
              enabled: settings.lowBalanceAlertsEnabled,
              onTap: _openThresholdsDialog,
            ),
            const Divider(height: 1, indent: 16),
            SwitchListTile(
              secondary: Icon(
                Icons.cloud_upload_outlined,
                color: settings.unsyncedDataAlertsEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(l10n.alertUnsyncedSwitchTitle),
              subtitle: Text(l10n.alertUnsyncedSwitchDesc),
              value: settings.unsyncedDataAlertsEnabled,
              onChanged: busy
                  ? null
                  : (value) async {
                      await provider.setUnsyncedDataAlertsEnabled(value);
                      await _reevaluateAlerts();
                    },
            ),
            subEntry(
              icon: Icons.schedule_rounded,
              title: l10n.alertUnsyncedDelayTitle,
              subtitle: l10n.alertUnsyncedDelayValue(
                  settings.unsyncedThresholdHours ~/ 24),
              enabled: settings.unsyncedDataAlertsEnabled,
              onTap: () => _pickUnsyncedDelay(provider),
            ),
            const Divider(height: 1, indent: 16),
            ListTile(
              leading: Icon(
                Icons.restart_alt_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(l10n.alertResetStateTitle),
              subtitle: Text(l10n.alertResetStateDesc),
              onTap: busy ? null : () => _resetEmissionState(provider),
            ),
          ],
        );
      },
    );
  }

  // --- Alarmes exactes -----------------------------------------------------

  Future<void> _requestExactAlarms(
    NotificationPermissionService service,
  ) async {
    await service.requestExactAlarmPermission();
    // Sur Android 13+ le système ouvre une page dédiée : l'état réel n'est
    // connu qu'au retour dans l'app (cf. didChangeAppLifecycleState).
    final allowed = await service.canScheduleExactAlarms();
    if (!mounted) return;
    setState(() => _exactAlarmsAllowed = allowed);
  }

  Widget? _buildExactAlarmsCard(ThemeData theme, AppLocalizations l10n) {
    final service = context.read<NotificationPermissionService>();
    if (!service.supportsExactAlarms) return null;
    // Tant que l'état est inconnu, ou si tout est déjà autorisé, on n'affiche
    // aucun point d'entrée superflu.
    if (_exactAlarmsAllowed != false) return null;

    return SettingsSectionCard(
      title: l10n.exactAlarmsTitle,
      icon: Icons.alarm_on_rounded,
      theme: theme,
      children: [
        ListTile(
          leading: Icon(Icons.alarm_off_rounded, color: Colors.orange.shade800),
          title: Text(l10n.exactAlarmsMissing),
          subtitle: Text(l10n.exactAlarmsDesc),
          isThreeLine: true,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => _requestExactAlarms(service),
              icon: const Icon(Icons.alarm_add_rounded, size: 18),
              label: Text(l10n.exactAlarmsAllow),
            ),
          ),
        ),
      ],
    );
  }

  // --- Erreur de chargement ------------------------------------------------

  Widget _buildLoadErrorBanner(ThemeData theme, AppLocalizations l10n) {
    return Consumer<NotificationPreferencesProvider>(
      builder: (context, provider, _) {
        if (provider.lastError != NotificationPreferencesError.fetch) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.notificationPreferencesLoadError,
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    if (provider.preferences != null)
                      Text(
                        l10n.notificationPreferencesOfflineHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: provider.isLoading ? null : provider.fetchPreferences,
                child: Text(l10n.retry),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final exactAlarmsCard = _buildExactAlarmsCard(theme, l10n);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notificationSettingsTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          final provider = context.read<NotificationPreferencesProvider>();
          await _refreshAll();
          if (!mounted) return;
          await provider.fetchPreferences();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildLoadErrorBanner(theme, l10n),
            _buildPermissionCard(theme, l10n),
            const SizedBox(height: 16),
            const NotificationPreferencesCard(),
            const SizedBox(height: 16),
            _buildReminderCard(theme, l10n),
            const SizedBox(height: 16),
            _buildLocalAlertsCard(theme, l10n),
            if (exactAlarmsCard != null) ...[
              const SizedBox(height: 16),
              exactAlarmsCard,
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Boîte de saisie d'un montant (budget mensuel ou seuil de solde).
///
/// Renvoie le montant validé, ou `null` si l'utilisateur annule. La
/// suppression d'une valeur existante se fait depuis la liste, pas ici.
class _AmountPromptDialog extends StatefulWidget {
  const _AmountPromptDialog({
    required this.title,
    required this.fieldLabel,
    required this.positiveOnly,
    required this.currency,
    this.initial,
  });

  final String title;
  final String fieldLabel;

  /// `true` pour un budget (strictement positif), `false` pour un seuil de
  /// solde (zéro et valeurs négatives acceptés).
  final bool positiveOnly;

  final String currency;
  final double? initial;

  @override
  State<_AmountPromptDialog> createState() => _AmountPromptDialogState();
}

class _AmountPromptDialogState extends State<_AmountPromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial == null ? '' : _plain(widget.initial!),
  );
  String? _error;

  /// Saisie initiale sans décimale inutile (« 10000 » plutôt que « 10000.0 »).
  static String _plain(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Accepte la virgule décimale (clavier francophone) et les espaces.
  double? _parse(String raw) {
    final cleaned =
        raw.trim().replaceAll(' ', '').replaceAll('\u00a0', '').replaceAll(',', '.');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null || !value.isFinite) return null;
    if (widget.positiveOnly && value <= 0) return null;
    return value;
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final value = _parse(_controller.text);
    if (value == null) {
      setState(() => _error = l10n.alertInvalidAmount);
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: widget.fieldLabel,
          suffixText: widget.currency,
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}
