import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../services/notification_permission_service.dart';
import '../../widgets/settings_section_card.dart';
import '../notification_settings_screen.dart';

/// Entrée de menu vers l'écran dédié aux notifications
/// (autorisation système, catégories, heures calmes).
class ProfileNotificationsSection extends StatelessWidget {
  const ProfileNotificationsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return SettingsSectionCard(
      theme: theme,
      children: [
        Consumer<NotificationPermissionService>(
          builder: (context, permService, _) {
            final denied = permService.isDenied;
            return ListTile(
              leading: Icon(
                denied
                    ? Icons.notifications_off_rounded
                    : Icons.notifications_outlined,
                color: denied
                    ? Colors.orange.shade800
                    : theme.colorScheme.primary,
              ),
              title: Text(
                l10n.notificationSettingsTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                denied
                    ? l10n.notificationPermissionDenied
                    : l10n.notificationSettingsSubtitle,
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
