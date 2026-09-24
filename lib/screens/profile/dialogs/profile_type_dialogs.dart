import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../../models/account_type.dart';
import '../../../providers/profile_provider.dart';

/// Feuille de sélection du nouveau profil d'utilisation (changement unique
/// et définitif).
void showProfileSelectionDialog(BuildContext context, String currentKey) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final allTypes = [
    AccountType.particulier,
    AccountType.petitCommerce,
    AccountType.entreprise,
    AccountType.kiosque,
  ].where((t) => t.key != currentKey).toList();

  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileTypeChooseNew,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.profileTypeChangeWarningOnce,
              style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
            ),
            const SizedBox(height: 16),
            ...allTypes.map((type) {
              final icon = type == AccountType.particulier
                  ? Icons.person_rounded
                  : type == AccountType.petitCommerce
                      ? Icons.storefront_rounded
                      : type == AccountType.entreprise
                          ? Icons.business_rounded
                          : Icons.point_of_sale_rounded;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(icon, color: theme.colorScheme.onPrimaryContainer),
                ),
                title: Text(
                  type.label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  showProfileChangeConfirmation(context, targetType: type.key);
                },
              );
            }),
          ],
        ),
      ),
    ),
  );
}

/// Confirmation du changement de profil d'utilisation (bouton neutralisé
/// pendant l'appel réseau / la migration locale).
void showProfileChangeConfirmation(
  BuildContext context, {
  required String targetType,
}) {
  final l10n = AppLocalizations.of(context)!;
  final theme = Theme.of(context);
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  final targetAccountType = AccountType.fromString(targetType);

  final String targetLabel = targetAccountType.label;
  final String description;
  final IconData targetIcon;

  switch (targetAccountType) {
    case AccountType.particulier:
      description = l10n.profileChangeToPersonalDesc;
      targetIcon = Icons.person_rounded;
      break;
    case AccountType.petitCommerce:
      description = l10n.profileChangeToSmallBusinessDesc;
      targetIcon = Icons.storefront_rounded;
      break;
    case AccountType.entreprise:
      description = l10n.profileChangeToCompanyDesc;
      targetIcon = Icons.business_rounded;
      break;
    case AccountType.kiosque:
      description = l10n.profileChangeToKioskDesc;
      targetIcon = Icons.point_of_sale_rounded;
      break;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      bool isLoading = false;
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  color: theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.profileChangeTitle,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target profile badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          targetIcon,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          targetLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  Text(
                    description,
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  // Warning box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber.shade700,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.profileChangeWarning,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade900,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () async {
                        setModalState(() => isLoading = true);
                        final success =
                            await profileProvider.changeProfileType(targetType);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                success
                                    ? '✅ ${l10n.profileChangeSuccess}'
                                    : '❌ ${l10n.profileChangeError}',
                              ),
                              backgroundColor:
                                  success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l10n.confirmProfileChange),
              ),
            ],
          );
        },
      );
    },
  );
}
