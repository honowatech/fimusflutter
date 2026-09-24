import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/formatters.dart';
import '../models/expense.dart';
import '../widgets/category_form_field.dart';
import 'package:uuid/uuid.dart';

/// Formulaire de création / modification d'une dépense programmée.
/// Calqué sur [AddExpenseScreen] mais avec une date ET une heure d'échéance,
/// obligatoirement dans le futur.
class AddScheduledExpenseScreen extends StatefulWidget {
  /// Dépense programmée existante (mode édition). Null en mode création.
  final Expense? initialExpense;

  const AddScheduledExpenseScreen({super.key, this.initialExpense});

  @override
  State<AddScheduledExpenseScreen> createState() => _AddScheduledExpenseScreenState();
}

class _AddScheduledExpenseScreenState extends State<AddScheduledExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  double _amount = 0.0;
  String? _selectedCategory;
  String? _selectedAccountId;
  late DateTime _selectedDateTime;
  String? _dateTimeError;

  bool get _isEditing => widget.initialExpense != null;

  @override
  void initState() {
    super.initState();
    final original = widget.initialExpense;
    if (original != null) {
      _title = original.title;
      _amount = original.amount;
      _selectedCategory = original.category;
      _selectedAccountId = original.accountId;
      final reminder = original.reminderAt;
      // Si l'échéance est déjà passée (ex: notification reçue puis édition),
      // on propose une nouvelle échéance dans une heure.
      _selectedDateTime = (reminder != null && reminder.isAfter(DateTime.now()))
          ? reminder
          : DateTime.now().add(const Duration(hours: 1));
    } else {
      _selectedDateTime = DateTime.now().add(const Duration(hours: 1));
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (_selectedDateTime.isBefore(DateTime.now())) {
      setState(() {
        _dateTimeError = AppLocalizations.of(context)!.futureDateRequired;
      });
      return;
    }

    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final l10n = AppLocalizations.of(context)!;

    if (_isEditing) {
      final updated = _buildExpenseFrom(widget.initialExpense!);
      await expenseProvider.updateScheduledExpense(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.scheduleUpdated)),
        );
        Navigator.pop(context);
      }
    } else {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final currentUserId = authProvider.user?['id']?.toString() ?? authProvider.user?['uuid']?.toString();
      final currentUserName = '${profileProvider.profile.firstName} ${profileProvider.profile.lastName}'.trim();

      final expense = Expense(
        id: const Uuid().v4(),
        title: _title,
        amount: _amount,
        category: _selectedCategory ?? 'Autre',
        date: _selectedDateTime,
        type: 'expense',
        accountId: _selectedAccountId,
        isLinkedToCashFlow: false,
        isPlanned: true,
        creatorId: currentUserId,
        creatorName: currentUserName.isNotEmpty ? currentUserName : null,
        scheduleStatus: 'scheduled',
        reminderAt: _selectedDateTime,
        createdAt: DateTime.now(),
      );

      await expenseProvider.addExpense(expense);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.scheduleSaved)),
        );
        Navigator.pop(context);
      }
    }
  }

  Expense _buildExpenseFrom(Expense original) {
    return Expense(
      id: original.id,
      title: _title,
      amount: _amount,
      category: _selectedCategory ?? 'Autre',
      date: _selectedDateTime,
      note: original.note,
      type: original.type,
      accountId: _selectedAccountId,
      debtTag: original.debtTag,
      debtorUserId: original.debtorUserId,
      isLinkedToCashFlow: false,
      isPlanned: true,
      interestRate: original.interestRate,
      repaymentDuration: original.repaymentDuration,
      durationUnit: original.durationUnit,
      repaymentFrequency: original.repaymentFrequency,
      installmentAmount: original.installmentAmount,
      creatorId: original.creatorId,
      creatorName: original.creatorName,
      debtStatus: original.debtStatus,
      dueDate: original.dueDate,
      scheduleStatus: 'scheduled',
      reminderAt: _selectedDateTime,
      createdAt: original.createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = _selectedDateTime.isAfter(now) ? _selectedDateTime : now;

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
      _dateTimeError = null;
    });
  }

  String _formatDateTime(DateTime dt) {
    final date = '${dt.day}/${dt.month}/${dt.year}';
    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date à $time';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = Provider.of<ExpenseProvider>(context).expenseCategories;
    final accounts = Provider.of<AccountProvider>(context).accounts;
    final currency = Provider.of<ProfileProvider>(context).profile.currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editScheduledExpense : l10n.addScheduledExpense),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                autofocus: true,
                initialValue: _isEditing ? _title : null,
                decoration: InputDecoration(labelText: l10n.title),
                validator: (val) => val == null || val.isEmpty ? l10n.required : null,
                onSaved: (val) => _title = val!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _isEditing && _amount > 0 ? _amount.toString() : null,
                decoration: InputDecoration(labelText: l10n.amount, prefixText: '$currency '),
                keyboardType: TextInputType.number,
                inputFormatters: [AmountInputFormatter()],
                validator: (val) {
                  if (val == null || val.isEmpty) return l10n.required;
                  if (double.tryParse(val.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.')) == null) return l10n.invalidNumber;
                  return null;
                },
                onSaved: (val) => _amount = double.parse(val!.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.')),
              ),
              const SizedBox(height: 16),
              CategoryFormField(
                categories: categories,
                initialValue: _selectedCategory,
                labelText: l10n.category,
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? l10n.pleaseChooseCategory
                    : null,
                onChanged: (val) => setState(() => _selectedCategory = val),
                onSaved: (val) => _selectedCategory = val,
              ),
              const SizedBox(height: 16),
              if (accounts.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: (accounts.any((a) => a.id == _selectedAccountId)) ? _selectedAccountId : null,
                  decoration: InputDecoration(
                    labelText: l10n.linkedAccountOptional,
                    hintText: l10n.noAccount,
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(l10n.noAccount),
                    ),
                    ...accounts.map((acc) => DropdownMenuItem(
                      value: acc.id,
                      child: Text(acc.name.isNotEmpty ? acc.name : l10n.untitled),
                    ))
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedAccountId = val;
                    });
                  },
                ),
              if (accounts.isNotEmpty) const SizedBox(height: 16),
              ListTile(
                title: Text(l10n.dateAndTime),
                subtitle: Text(_formatDateTime(_selectedDateTime)),
                trailing: const Icon(Icons.schedule),
                onTap: _pickDateTime,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              if (_dateTimeError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 16),
                  child: Text(
                    _dateTimeError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.alarm_add),
                label: Text(
                  l10n.saveSchedule,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
