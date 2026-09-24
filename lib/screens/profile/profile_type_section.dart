import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../models/account_type.dart';
import '../../providers/profile_provider.dart';
import '../../widgets/settings_section_card.dart';
import 'dialogs/profile_type_dialogs.dart';

/// Carte « Profil d'utilisation » : type de compte courant et bascule
/// unique vers un autre type.
class ProfileTypeSection extends StatelessWidget {
  const ProfileTypeSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Consumer<ProfileProvider>(
      builder: (context, profileProv, _) {
        final currentProfile = profileProv.profile;
        final accountType = currentProfile.accountType;
        final isLocked = currentProfile.hasChangedType;

        final currentIcon = accountType == AccountType.particulier
            ? Icons.person_rounded
            : accountType == AccountType.petitCommerce
                ? Icons.storefront_rounded
                : accountType == AccountType.entreprise
                    ? Icons.business_rounded
                    : Icons.point_of_sale_rounded;

        return SettingsSectionCard(
          title: l10n.profileTypeSection,
          icon: Icons.badge_outlined,
          theme: theme,
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  currentIcon,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(
                l10n.currentProfileType,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              subtitle: Text(
                accountType.label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const Divider(height: 1, indent: 16),
            if (isLocked) ...[
              ListTile(
                leading: Icon(
                  Icons.lock_rounded,
                  color: Colors.grey.shade500,
                ),
                title: Text(
                  l10n.profileTypePermanent,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                subtitle: Text(
                  l10n.profileTypeAlreadyChanged,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                  ),
                ),
              ),
            ] else ...[
              ListTile(
                leading: Icon(
                  Icons.swap_horiz_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(
                  l10n.changeProfileAction,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                subtitle: Text(
                  l10n.profileTypeOneTimeHint,
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.primary,
                ),
                onTap: () => showProfileSelectionDialog(
                  context,
                  accountType.key,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
