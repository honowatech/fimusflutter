import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/auth_service.dart';
import '../../login_screen.dart';

/// Multicompte : liste des comptes connectés sur cet appareil, avec
/// changement de compte rapide et ajout d'un compte (dans la limite
/// configurée dans le backoffice).
void showAccountsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final l10n = AppLocalizations.of(context)!;
            final theme = Theme.of(context);
            final activeUserId = authProvider.user != null
                ? AuthService.userIdOf(authProvider.user!)
                : null;

            return Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.switch_account_rounded,
                            color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.accounts,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ...authProvider.sessions.map((session) {
                    final sessionUserId = AuthService.userIdOf(session);
                    final isActive = sessionUserId == activeUserId;
                    final name =
                        session['name']?.toString() ?? l10n.user;
                    final subtitle = session['email']?.toString() ??
                        session['pseudo']?.toString() ??
                        '';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                        child: isActive
                            ? Icon(Icons.check_circle_rounded,
                                color: theme.colorScheme.primary)
                            : Text(
                                name.isNotEmpty
                                    ? name.characters.first.toUpperCase()
                                    : '?',
                                style: TextStyle(
                                    color: theme.colorScheme.primary),
                              ),
                      ),
                      title: Text(name),
                      subtitle: subtitle.isEmpty ? null : Text(subtitle),
                      trailing: isActive
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                l10n.activeAccount,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          : null,
                      onTap: isActive || sessionUserId == null
                          ? null
                          : () async {
                              Navigator.pop(sheetContext);
                              await authProvider.switchAccount(
                                  context, sessionUserId);
                            },
                    );
                  }),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      Icons.person_add_alt_1_rounded,
                      color: authProvider.canAddAccount
                          ? theme.colorScheme.primary
                          : theme.disabledColor,
                    ),
                    title: Text(
                      l10n.addAccount,
                      style: TextStyle(
                        color: authProvider.canAddAccount
                            ? null
                            : theme.disabledColor,
                      ),
                    ),
                    subtitle: !authProvider.canAddAccount
                        ? Text(l10n.deviceAccountLimit(
                            authProvider.maxAccountsPerDevice))
                        : null,
                    enabled: authProvider.canAddAccount,
                    onTap: authProvider.canAddAccount
                        ? () {
                            Navigator.pop(sheetContext);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(
                                    addAccountMode: true),
                              ),
                            );
                          }
                        : null,
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}
