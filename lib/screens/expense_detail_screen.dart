import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/account_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/profile_provider.dart';
import '../models/account.dart';
import '../models/expense.dart';
import '../utils/formatters.dart';
import '../utils/translation_helper.dart';
import '../services/database_service.dart';
import 'add_expense_screen.dart';
import 'add_scheduled_expense_screen.dart';
import '../utils/app_theme.dart';

/// Détail complet d'une opération (dépense, revenu, dette ou opération
/// programmée). Accessible par un clic sur une ligne de l'historique.
class ExpenseDetailScreen extends StatefulWidget {
  final Expense expense;

  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  bool get _isIncome => _expense.type == 'income';

  /// Version à jour de l'opération (reflète une éventuelle modification).
  Expense get _expense {
    return Provider.of<ExpenseProvider>(context, listen: false)
        .expenses
        .firstWhere(
          (e) => e.id == widget.expense.id,
          orElse: () => widget.expense,
        );
  }

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$day/$month/${local.year} à $time';
  }

  String _recordedByLabel(AppLocalizations l10n) {
    final creatorName = _expense.creatorName;
    if (creatorName != null && creatorName.trim().isNotEmpty) {
      return creatorName.trim();
    }
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?['id']?.toString() ?? authProvider.user?['uuid']?.toString();
    if (_expense.creatorId != null &&
        _expense.creatorId.toString() == currentUserId?.toString()) {
      return l10n.me;
    }
    return '—';
  }

  String _accountName(AppLocalizations l10n) {
    final accountId = _expense.accountId;
    if (accountId == null || accountId.isEmpty) return l10n.noAccount;
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);
    final account = accountProvider.accounts.firstWhere(
      (a) => a.id == accountId,
      orElse: () => Account(id: accountId, name: l10n.unknownAccount, balance: 0.0),
    );
    return account.name.isNotEmpty ? account.name : l10n.untitled;
  }

  String _debtStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'pending':
        return l10n.debtStatusPending;
      case 'accepted':
        return l10n.debtStatusAccepted;
      default:
        return status;
    }
  }

  void _edit() {
    if (_expense.scheduleStatus == 'scheduled') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddScheduledExpenseScreen(initialExpense: _expense),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AddExpenseScreen(
            expenseToEdit: _expense,
            isIncome: _isIncome,
          ),
        ),
      );
    }
  }

  /// Libellé traduit d'une unité de durée stockée en base ('Mois'/'Années').
  String _durationUnitLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Années':
        return l10n.years;
      case 'Mois':
        return l10n.months;
      default:
        return value;
    }
  }

  /// Libellé traduit d'une fréquence de remboursement stockée en base.
  String _frequencyLabel(AppLocalizations l10n, String value) {
    switch (value) {
      case 'Mensuelle':
        return l10n.frequencyMonthly;
      case 'Hebdomadaire':
        return l10n.frequencyWeekly;
      case 'Quotidienne':
        return l10n.frequencyDaily;
      case 'Annuelle':
        return l10n.frequencyAnnual;
      default:
        return value;
    }
  }

  Future<void> _confirmDelete() async {
    final l10n = AppLocalizations.of(context)!;
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final accountProvider = Provider.of<AccountProvider>(context, listen: false);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteEntryConfirm),
        content: Text(l10n.deleteEntryWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (_expense.scheduleStatus == 'scheduled') {
      await expenseProvider.deleteExpense(_expense.id);
    } else {
      await DatabaseService.instance.runTransaction((txn) async {
        if (_expense.accountId != null) {
          await accountProvider.updateBalance(
            _expense.accountId!,
            _isIncome ? -_expense.amount : _expense.amount,
            executor: txn,
          );
        }
        await expenseProvider.deleteExpense(_expense.id, executor: txn);
      });
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Réagit aux modifications de l'opération (ex: retour depuis l'écran de
    // modification) pour rafraîchir le détail affiché.
    Provider.of<ExpenseProvider>(context);
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final currency = Provider.of<ProfileProvider>(context).profile.currency;
    final isScheduled = _expense.scheduleStatus == 'scheduled';

    // Compte partagé : on met en avant la personne à l'origine de l'opération
    // quand elle n'est pas l'utilisateur courant.
    final Account? linkedAccount = _expense.accountId != null
        ? Provider.of<AccountProvider>(context, listen: false)
            .accounts
            .where((a) => a.id == _expense.accountId)
            .firstOrNull
        : null;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?['id']?.toString() ?? authProvider.user?['uuid']?.toString();
    final createdByOther = linkedAccount != null &&
        linkedAccount.isShared &&
        _expense.creatorId != null &&
        _expense.creatorId.toString() != currentUserId?.toString() &&
        (_expense.creatorName != null && _expense.creatorName!.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.detailsTitle),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(l10n, currency),
            const SizedBox(height: 16),

            if (createdByOther) ...[
              _buildSharedAccountBanner(l10n),
              const SizedBox(height: 16),
            ],

            _buildSectionCard([
              _DetailRow(
                icon: Icons.swap_vert,
                label: l10n.typeLabel,
                value: _isIncome ? l10n.income : l10n.expense,
                // Teintes d'origine en clair, jetons `income`/`expense` en
                // sombre (les rouges/verts bruts y manquent de contraste).
                valueColor: _isIncome
                    ? colorScheme.tone(
                        light: Colors.green,
                        dark: colorScheme.income,
                      )
                    : colorScheme.tone(
                        light: Colors.red,
                        dark: colorScheme.expense,
                      ),
              ),
              _DetailRow(
                icon: Icons.event,
                label: l10n.operationDate,
                value: _formatDateTime(_expense.date),
              ),
              _DetailRow(
                icon: Icons.history,
                label: l10n.recordedDate,
                value: _formatDateTime(_expense.recordedAt),
              ),
              _DetailRow(
                icon: Icons.person_outline,
                label: l10n.recordedBy,
                value: _recordedByLabel(l10n),
              ),
              _DetailRow(
                icon: Icons.account_balance_wallet_outlined,
                label: l10n.linkedAccount,
                value: _accountName(l10n),
              ),
              _DetailRow(
                icon: Icons.category_outlined,
                label: l10n.category,
                value: l10n.translateCategory(_expense.category),
              ),
              _DetailRow(
                icon: Icons.sticky_note_2_outlined,
                label: l10n.noteLabel,
                value: (_expense.note != null && _expense.note!.trim().isNotEmpty)
                    ? _expense.note!
                    : l10n.noNote,
              ),
            ]),

            if (isScheduled) ...[
              const SizedBox(height: 16),
              _buildSectionCard([
                _DetailRow(
                  icon: Icons.schedule,
                  label: l10n.status,
                  value: l10n.scheduledLabel,
                  // Statut « planifie » : ambre d'avertissement.
                  valueColor: colorScheme.tone(
                    light: Colors.amber.shade800,
                    dark: colorScheme.warning,
                  ),
                ),
                _DetailRow(
                  icon: Icons.alarm,
                  label: l10n.dueDateLabel,
                  value: _formatDateTime(_expense.reminderAt ?? _expense.date),
                ),
              ]),
            ],

            if (_expense.debtTag != null && _expense.debtTag!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildSectionCard([
                _DetailRow(
                  icon: Icons.handshake_outlined,
                  label: l10n.debtTagLabel,
                  value: _expense.debtTag!,
                ),
                if (_expense.debtStatus.isNotEmpty)
                  _DetailRow(
                    icon: Icons.verified_outlined,
                    label: l10n.status,
                    value: _debtStatusLabel(_expense.debtStatus, l10n),
                  ),
                if (_expense.interestRate != null)
                  _DetailRow(
                    icon: Icons.percent,
                    label: l10n.interestRate,
                    value: '${_expense.interestRate!.toStringAsFixed(_expense.interestRate! % 1 == 0 ? 0 : 2)}%',
                  ),
                if (_expense.repaymentDuration != null)
                  _DetailRow(
                    icon: Icons.calendar_month_outlined,
                    label: l10n.duration,
                    value: _expense.durationUnit == null
                        ? '${_expense.repaymentDuration}'
                        : '${_expense.repaymentDuration} '
                            '${_durationUnitLabel(l10n, _expense.durationUnit!)}',
                  ),
                if (_expense.repaymentFrequency != null)
                  _DetailRow(
                    icon: Icons.repeat,
                    label: l10n.repaymentFrequency,
                    value: _frequencyLabel(l10n, _expense.repaymentFrequency!),
                  ),
                if (_expense.installmentAmount != null)
                  _DetailRow(
                    icon: Icons.payments_outlined,
                    label: l10n.amountPerInstallment,
                    value: '${_expense.installmentAmount!.formatAmountDouble()} $currency',
                  ),
                if (_expense.dueDate != null)
                  _DetailRow(
                    icon: Icons.event_repeat,
                    label: l10n.dueDateLabel,
                    value: _formatDateTime(_expense.dueDate!),
                  ),
              ]),
            ],

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _edit,
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(l10n.modify),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _confirmDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.delete),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.tone(
                        light: Colors.red,
                        dark: colorScheme.error,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, String currency) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _isIncome
        ? colorScheme.tone(light: Colors.green, dark: colorScheme.income)
        : colorScheme.tone(light: Colors.redAccent, dark: colorScheme.expense);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color,
                // En sombre `color` devient une teinte pastel claire : le blanc
                // n'y passerait plus, on bascule sur un contenu sombre.
                foregroundColor: colorScheme.tone(
                  light: Colors.white,
                  dark: Colors.black87,
                ),
                child: Icon(_isIncome ? Icons.arrow_downward : Icons.arrow_upward),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _expense.title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_isIncome ? l10n.income : l10n.expense} • ${l10n.translateCategory(_expense.category)}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_isIncome ? '+' : '-'}${_expense.amount.formatAmountDouble()} $currency',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSharedAccountBanner(AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    // Bandeau informatif « compte partage » : le teal d'origine n'a pas de
    // jeton dedie, on le garde en clair et on retombe sur la famille `info*`
    // en sombre.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.tone(
          light: Colors.teal.shade50,
          dark: colorScheme.infoContainer,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.tone(
            light: Colors.teal.shade200,
            dark: colorScheme.infoOutline,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.people_alt_outlined,
            color: colorScheme.tone(
              light: Colors.teal.shade700,
              dark: colorScheme.info,
            ),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l10n.sharedAccountOperationBy(_expense.creatorName!.trim()),
              style: TextStyle(
                color: colorScheme.tone(
                  light: Colors.teal.shade900,
                  dark: colorScheme.onInfoContainer,
                ),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(List<Widget> rows) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 52,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 14)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color:
                    valueColor ?? Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
