import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/settings_section_card.dart';
import '../contacts_screen.dart';
import '../login_screen.dart';
import 'dialogs/account_actions_dialogs.dart';
import 'dialogs/accounts_sheet.dart';

/// Carte « Compte & Synchronisation » de l'onglet « Mon compte » :
/// identité du compte connecté, pseudo, contacts, synchronisation,
/// comptes multiples, déconnexion et suppression de compte.
class ProfileAccountSection extends StatelessWidget {
  const ProfileAccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return SettingsSectionCard(
          theme: theme,
          children: [
            if (authProvider.isAuthenticated) ...[
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(
                  authProvider.user?['name'] ?? l10n.user,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(authProvider.user?['email'] ?? ''),
              ),
              const Divider(height: 1, indent: 16),
              ListTile(
                leading: Icon(
                  Icons.vpn_key_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.myPseudo),
                subtitle: Text(
                  authProvider.userPseudo ?? l10n.notDefined,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    final pseudo = authProvider.userPseudo;
                    if (pseudo != null) {
                      Clipboard.setData(
                        ClipboardData(text: pseudo),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.pseudoCopied),
                        ),
                      );
                    }
                  },
                ),
              ),
              const Divider(height: 1, indent: 16),
              ListTile(
                leading: Icon(
                  Icons.people_alt_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.myContacts),
                subtitle: Text(l10n.manageContactsDesc),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ContactsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1, indent: 16),
              ListTile(
                leading: authProvider.isSyncing
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.sync_rounded,
                        color: theme.colorScheme.primary,
                      ),
                title: Text(l10n.syncNow),
                subtitle: Text(l10n.syncNowDesc),
                onTap: authProvider.isSyncing
                    ? null
                    : () async {
                        final result = await authProvider.syncNow(
                          context,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.success
                                    ? l10n.syncComplete(
                                        result.pushed,
                                        result.pulled,
                                      )
                                    : l10n.syncError(
                                        result.error ?? '',
                                      ),
                              ),
                              backgroundColor: result.success
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          );
                        }
                      },
              ),
              const Divider(height: 1, indent: 16),
              // --- Multicompte : comptes connectés sur cet appareil ---
              ListTile(
                leading: Icon(
                  Icons.switch_account_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: Text(l10n.accounts),
                subtitle: Text(
                  authProvider.sessions.length > 1
                      ? l10n.accountsCount(authProvider.sessions.length)
                      : l10n.accountsDesc,
                ),
                onTap: () => showAccountsSheet(context),
              ),
              const Divider(height: 1, indent: 16),
              ListTile(
                leading: const Icon(
                  Icons.logout_rounded,
                  color: Colors.red,
                ),
                title: Text(
                  l10n.logout,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () => confirmAndLogout(context, authProvider),
              ),
              const Divider(height: 1, indent: 16),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: Colors.red,
                ),
                title: Text(
                  l10n.deleteUserAccount,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () => confirmAndDeleteAccount(context, authProvider),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.loginToSync,
                      style: const TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.login),
                      label: Text(l10n.login),
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
}
