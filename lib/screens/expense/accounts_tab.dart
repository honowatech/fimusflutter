import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/add_account_bottom_sheet.dart';
import '../../providers/expense_provider.dart';
import '../account_detail_screen.dart';
import '../../widgets/share_account_dialog.dart';

/// Convertit la couleur stockée en base (`#RRGGBB`, `0xAARRGGBB`…) en [Color].
Color parseAccountColor(String? colorStr, BuildContext context) {
  if (colorStr == null || colorStr.trim().isEmpty) {
    return Theme.of(context).colorScheme.primaryContainer;
  }
  try {
    String hex = colorStr.trim().replaceAll('#', '');
    if (hex.startsWith('0x') || hex.startsWith('0X')) {
      hex = hex.substring(2);
    }
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    if (hex.length == 8) {
      return Color(int.parse(hex, radix: 16));
    }
  } catch (_) {}
  return Theme.of(context).colorScheme.primaryContainer;
}

/// Onglet « Comptes » : liste des comptes, partage, édition et suppression.
class ExpenseAccountsTab extends StatelessWidget {
  const ExpenseAccountsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Abonnements limités à cet onglet.
    final accountProvider = context.watch<AccountProvider>();
    final currentUserId = context.select<AuthProvider, Object?>((a) => a.user?['id']);
    final currency = context.select<ProfileProvider, String>((p) => p.profile.currency);
    final accounts = accountProvider.accounts;
    final expenseProvider = context.read<ExpenseProvider>();

    return RefreshIndicator(
      onRefresh: () =>
          expenseProvider.syncAndReloadAll(accountProvider: accountProvider),
      child: accounts.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.8,
                  child: Center(child: Text(l10n.noAccountSaved)),
                ),
              ],
            )
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];
                final isOwner = account.ownerId == null ||
                    currentUserId == null ||
                    account.ownerId.toString() == currentUserId.toString();
                final String initial = account.name.trim().isNotEmpty
                    ? account.name.trim()[0].toUpperCase()
                    : '?';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: parseAccountColor(account.color, context),
                    child: Text(initial),
                  ),
                  title: Text(
                    account.name.isNotEmpty ? account.name : l10n.untitled,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text('${account.balance.formatAmount()} $currency'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isOwner) ...[
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.share,
                            color: Theme.of(context).colorScheme.success,
                          ),
                          onPressed: () => showShareAccountDialog(context, account, true),
                          tooltip: l10n.tooltipShareAccount,
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          // Bleu d'action : `info` garde la teinte bleue et
                          // reste lisible sur surface sombre (le brand `primary`
                          // dépend de la couleur choisie par l'utilisateur).
                          icon: Icon(
                            Icons.edit,
                            color: Theme.of(context).colorScheme.info,
                          ),
                          onPressed: () => AddAccountBottomSheet.show(context, existingAccount: account),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.delete,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text(l10n.deleteAccountConfirm),
                                content: Text(l10n.irreversibleAction),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
                                  TextButton(
                                    onPressed: () {
                                      accountProvider.deleteAccount(account.id);
                                      Navigator.pop(ctx);
                                    },
                                    child: Text(
                                      l10n.delete,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ] else ...[
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.all(6),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            Icons.group,
                            color: Theme.of(context).colorScheme.success,
                          ),
                          onPressed: () => showShareAccountDialog(context, account, false),
                          tooltip: l10n.tooltipViewMembers,
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountDetailScreen(accountId: account.id),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
