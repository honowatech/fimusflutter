import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../providers/security_provider.dart';
import '../../widgets/settings_section_card.dart';
import 'dialogs/security_pin_dialogs.dart';

/// Carte « Sécurité d'accès » : verrou par code PIN, changement de PIN et
/// déverrouillage biométrique.
class ProfileSecuritySection extends StatelessWidget {
  const ProfileSecuritySection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Consumer<SecurityProvider>(
      builder: (context, securityProvider, _) {
        return SettingsSectionCard(
          title: l10n.accessSecurity,
          icon: Icons.security_rounded,
          theme: theme,
          children: [
            ListTile(
              leading: Icon(
                Icons.lock_outline_rounded,
                color: securityProvider.isAppLockEnabled
                    ? theme.colorScheme.primary
                    : Colors.grey,
              ),
              title: Text(l10n.lockApp),
              subtitle: Text(l10n.lockAppDesc),
              trailing: Switch(
                value: securityProvider.isAppLockEnabled,
                onChanged: (value) {
                  if (value) {
                    showSetPinDialog(context);
                  } else {
                    showDisablePinDialog(context);
                  }
                },
              ),
            ),
            if (securityProvider.isAppLockEnabled) ...[
              const Divider(height: 1, indent: 16),
              ListTile(
                leading: Icon(
                  Icons.pin_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.changePinCode),
                subtitle: Text(l10n.changePinCodeDesc),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showChangePinDialog(context),
              ),
              if (securityProvider.isBiometricsAvailable) ...[
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: Icon(
                    Icons.fingerprint_rounded,
                    color: securityProvider.isBiometricEnabled
                        ? theme.colorScheme.primary
                        : Colors.grey,
                  ),
                  title: Text(l10n.fingerprintFaceId),
                  subtitle: Text(l10n.unlockWithBiometrics),
                  trailing: Switch(
                    value: securityProvider.isBiometricEnabled,
                    onChanged: (value) async {
                      await securityProvider.setBiometricEnabled(
                        value,
                      );
                    },
                  ),
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}
