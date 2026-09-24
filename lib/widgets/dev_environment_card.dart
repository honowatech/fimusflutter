import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../config/app_environment.dart';
import '../providers/app_config_provider.dart';
import '../utils/app_theme.dart';
import 'settings_section_card.dart';

/// Carte « Environnement & Mode Dev » du profil (debug uniquement) : bascule
/// production / serveur local, choix de l'hôte, test de connexion, purge.
/// Chaque changement passe par [AppConfigProvider.switchTo], qui redémarre
/// l'application sur le nouvel environnement.
class DevEnvironmentCard extends StatefulWidget {
  const DevEnvironmentCard({super.key});

  @override
  State<DevEnvironmentCard> createState() => _DevEnvironmentCardState();
}

class _DevEnvironmentCardState extends State<DevEnvironmentCard> {
  late final TextEditingController _urlController = TextEditingController(
    text: context.read<AppConfigProvider>().environment.customUrl,
  );

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _enableDevMode(
      AppConfigProvider appConfig, AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(ctx).colorScheme.tone(
                light: const Color(0xFFFFC107), // Colors.amber
                dark: Theme.of(ctx).colorScheme.warning,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.enableDevModeTitle)),
          ],
        ),
        content: Text(l10n.enableDevModeBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.enableDevModeBtn),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await appConfig.switchTo(appConfig.environment.copyWith(isDev: true));
    }
  }

  Future<void> _purge(AppConfigProvider appConfig, AppLocalizations l10n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.purgeTestDbTitle),
        content: Text(l10n.purgeTestDbBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              l10n.purge,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) await appConfig.clearDevDatabase();
  }

  void _applyCustomUrl(AppConfigProvider appConfig) {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    appConfig.switchTo(appConfig.environment.copyWith(customUrl: url));
  }

  String _hostLabel(AppLocalizations l10n, DevHost host) => switch (host) {
        DevHost.vhost => l10n.hostVhost,
        DevHost.emulator => l10n.hostEmulator,
        DevHost.web => l10n.hostWeb,
        DevHost.custom => l10n.hostCustom,
      };

  String _describe(AppLocalizations l10n, ConnectionTestResult result) =>
      switch (result.status) {
        ConnectionTestStatus.success =>
          l10n.connectionTestOk(result.latencyMs ?? 0),
        ConnectionTestStatus.httpError =>
          l10n.connectionTestHttpStatus(result.statusCode ?? 0),
        ConnectionTestStatus.timeout => l10n.connectionTestTimeout,
        ConnectionTestStatus.refused => l10n.connectionTestRefused,
        ConnectionTestStatus.error =>
          l10n.connectionTestError(result.message ?? ''),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Carte de debug : les teintes claires sont celles d'origine, les variantes
    // sombres sont eclaircies pour rester lisibles sur fond fonce.
    final devAmber = scheme.tone(
      light: const Color(0xFFFF8F00), // Colors.amber.shade800
      dark: scheme.warning,
    );
    final okGreen = scheme.tone(
      light: const Color(0xFF4CAF50), // Colors.green
      dark: scheme.success,
    );
    final okGreenStrong = scheme.tone(
      light: const Color(0xFF388E3C), // Colors.green.shade700
      dark: scheme.success,
    );
    final koRed = scheme.tone(
      light: const Color(0xFFF44336), // Colors.red
      dark: scheme.error,
    );
    final koRedStrong = scheme.tone(
      light: const Color(0xFFD32F2F), // Colors.red.shade700
      dark: scheme.error,
    );
    final appConfig = context.watch<AppConfigProvider>();
    final env = appConfig.environment;
    final testResult = appConfig.lastConnectionTest;

    return SettingsSectionCard(
      title: l10n.environmentDevMode,
      icon: Icons.developer_mode_rounded,
      theme: theme,
      children: [
        SwitchListTile(
          secondary: Icon(
            env.isDev ? Icons.bug_report_rounded : Icons.cloud_done_rounded,
            color: env.isDev ? devAmber : okGreen,
          ),
          title: Text(
            env.isDev ? l10n.devModeLocalDb : l10n.productionMode,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            env.isDev
                ? l10n.connectedToLocalDb(appConfig.activeBaseUrl)
                : l10n.connectedToOnlineServer,
          ),
          value: env.isDev,
          onChanged: (value) => value
              ? _enableDevMode(appConfig, l10n)
              : appConfig.switchTo(env.copyWith(isDev: false)),
        ),
        if (env.isDev) ...[
          const Divider(height: 1, indent: 16),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.warningContainer,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scheme.warningOutline),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          color: scheme.onWarningContainer, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.localDbInfo(
                            appConfig.activeDatabaseName,
                            appConfig.activeBaseUrl,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onWarningContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.localEnvType,
                  style:
                      const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final host in DevHost.values)
                      ChoiceChip(
                        label: Text(_hostLabel(l10n, host)),
                        selected: env.host == host,
                        onSelected: (selected) {
                          if (selected) {
                            appConfig.switchTo(env.copyWith(host: host));
                          }
                        },
                      ),
                  ],
                ),
                if (env.host == DevHost.custom) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: l10n.localApiUrlLabel,
                      hintText: l10n.localApiUrlHint,
                      helperText: l10n.localApiUrlHelper,
                      helperMaxLines: 2,
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(
                        tooltip: l10n.devHostApply,
                        icon: const Icon(Icons.check_rounded),
                        onPressed: () => _applyCustomUrl(appConfig),
                      ),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _applyCustomUrl(appConfig),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: appConfig.isTestingConnection
                          ? null
                          : appConfig.testConnection,
                      icon: appConfig.isTestingConnection
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check_rounded, size: 18),
                      label: Text(l10n.testConnection),
                    ),
                    const SizedBox(width: 8),
                    if (testResult != null)
                      Expanded(
                        child: Text(
                          _describe(l10n, testResult),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: testResult.isSuccess
                                ? okGreenStrong
                                : koRedStrong,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _purge(appConfig, l10n),
                      icon: Icon(Icons.delete_outline, size: 16, color: koRed),
                      label: Text(l10n.purgeTests,
                          style: TextStyle(color: koRed)),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          appConfig.switchTo(env.copyWith(isDev: false)),
                      icon: Icon(Icons.cloud_done_outlined,
                          size: 16, color: okGreen),
                      label: Text(l10n.backToProduction,
                          style: TextStyle(color: okGreen)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (env != appConfig.launchDefault) ...[
          const Divider(height: 1, indent: 16),
          ListTile(
            leading: const Icon(Icons.restart_alt_rounded),
            title: Text(l10n.resetToLaunchProfile),
            subtitle: Text(appConfig.launchDefault.apiBaseUrl),
            onTap: appConfig.resetToLaunchDefault,
          ),
        ],
      ],
    );
  }
}
