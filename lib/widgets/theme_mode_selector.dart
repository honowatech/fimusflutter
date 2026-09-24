import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:monitrack/l10n/app_localizations.dart';

import '../providers/theme_provider.dart';

/// Sélecteur du mode d'affichage (système / clair / sombre).
///
/// Autonome : il lit et écrit lui-même [ThemeProvider], il suffit donc de
/// l'insérer tel quel dans une section de l'écran Profil.
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final options = <ThemeMode, ({IconData icon, String label})>{
      ThemeMode.system: (
        icon: Icons.brightness_auto_outlined,
        label: l10n.themeModeSystem,
      ),
      ThemeMode.light: (
        icon: Icons.light_mode_outlined,
        label: l10n.themeModeLight,
      ),
      ThemeMode.dark: (
        icon: Icons.dark_mode_outlined,
        label: l10n.themeModeDark,
      ),
    };

    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        final current = themeProvider.themeMode;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.brightness_6_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.displayMode,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                l10n.displayModeSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              // `SegmentedButton` gère seul les états sélectionné / pressé et
              // reste lisible dans les deux thèmes (jetons secondaryContainer).
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: [
                    for (final entry in options.entries)
                      ButtonSegment<ThemeMode>(
                        value: entry.key,
                        icon: Icon(entry.value.icon),
                        label: Text(
                          entry.value.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        tooltip: entry.value.label,
                      ),
                  ],
                  selected: <ThemeMode>{current},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    if (selection.isEmpty) return;
                    themeProvider.setThemeMode(selection.first);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
