import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monitrack/l10n/app_localizations.dart';

import '../utils/app_theme.dart';

/// Bandeau Android : sans exemption Doze, les rappels locaux (Tecno, Infinix,
/// Xiaomi…) sont souvent tués. Un tap ouvre la demande système.
class BatteryOptimizationBanner extends StatefulWidget {
  const BatteryOptimizationBanner({super.key});

  @override
  State<BatteryOptimizationBanner> createState() =>
      _BatteryOptimizationBannerState();
}

class _BatteryOptimizationBannerState extends State<BatteryOptimizationBanner> {
  static const _dismissedKey = 'battery_opt_prompt_dismissed';
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_dismissedKey) == true) return;
      final granted = await Permission.ignoreBatteryOptimizations.isGranted;
      if (mounted) setState(() => _visible = !granted);
    } catch (_) {}
  }

  Future<void> _activate() async {
    try {
      await Permission.ignoreBatteryOptimizations.request();
    } catch (_) {}
    await _refresh();
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dismissedKey, true);
    if (mounted) setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    // Bandeau informatif : teinte bleue dérivée du thème (identique au bleu
    // Material d'origine en clair, version lisible sur fond sombre).
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.infoContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.infoOutline),
      ),
      child: Row(
        children: [
          Icon(Icons.battery_alert_rounded, color: scheme.info),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l10n.batteryOptimizationPrompt,
              style: TextStyle(color: scheme.onInfoContainer),
            ),
          ),
          TextButton(
            onPressed: _activate,
            child: Text(l10n.activate),
          ),
          IconButton(
            tooltip: l10n.cancel,
            onPressed: _dismiss,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}
