import 'package:flutter/material.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import '../../models/account.dart';
import '../../providers/account_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/add_account_bottom_sheet.dart';
import '../../providers/expense_provider.dart';
import '../account_detail_screen.dart';
import '../../widgets/share_account_dialog.dart';
import 'currency_display.dart';

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

/// Libellé du solde d'un compte.
///
/// Le solde vit dans la devise du compte : les opérations imputées y sont déjà
/// converties à l'écriture (`AccountProvider.updateBalance`). On l'affiche donc
/// dans cette devise — c'est la seule qui soit exacte — et on ajoute
/// l'équivalent dans celle du profil lorsqu'elle diffère, faute de quoi la
/// liste des comptes juxtapose des nombres non comparables entre eux ni avec
/// les totaux du tableau de bord.
String accountBalanceLabel(
  Account account, {
  required String profileCurrency,
  required Map<String, double> activeRates,
}) {
  final own = MoneyFormatter.format(
    account.balance,
    rowCurrency: account.currency,
    profileCurrency: profileCurrency,
    decimalPlaces: null,
  );
  if (!MoneyFormatter.isForeign(account.currency, profileCurrency)) return own;
  return '$own ≈ ${MoneyFormatter.formatConverted(
    account.balance,
    rowCurrency: account.currency,
    profileCurrency: profileCurrency,
    activeRates: activeRates,
    decimalPlaces: null,
  )}';
}

/// Onglet « Comptes » : liste des comptes, partage, édition et suppression.
class ExpenseAccountsTab extends StatelessWidget {
  const ExpenseAccountsTab({super.key});

  @override
  Widget build(BuildContext context) => ExchangeRatesBuilder(
        // Taux chargés une seule fois pour tout l'onglet, jamais par ligne :
        // l'équivalent affiché sous un solde en devise étrangère en a besoin.
        builder: _buildAccounts,
      );

  Widget _buildAccounts(BuildContext context, Map<String, double> rates) {
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
                  subtitle: Text(accountBalanceLabel(
                    account,
                    profileCurrency: currency,
                    activeRates: rates,
                  )),
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
