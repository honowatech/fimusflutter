import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/formatters.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import '../widgets/category_form_field.dart';
import 'package:uuid/uuid.dart';
import 'expense_screen.dart';
import 'main_screen.dart';

class AddExpenseScreen extends StatefulWidget {
  final bool isIncome;
  final String? initialAccountId;
  final Expense? expenseToEdit;
  
  const AddExpenseScreen({
    super.key,
    this.isIncome = false,
    this.initialAccountId,
    this.expenseToEdit,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  double _amount = 0.0;
  String? _selectedCategory;
  String? _selectedAccountId;
  DateTime _selectedDate = DateTime.now();

  bool get _isEditing => widget.expenseToEdit != null;
  bool get _isIncome => _isEditing ? (widget.expenseToEdit!.type == 'income') : widget.isIncome;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final exp = widget.expenseToEdit!;
      _title = exp.title;
      _amount = exp.amount;
      _selectedCategory = exp.category;
      _selectedAccountId = exp.accountId;
      _selectedDate = exp.date;
    } else {
      _selectedAccountId = widget.initialAccountId;
    }
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final accountProvider = Provider.of<AccountProvider>(context, listen: false);
      
      if (_isEditing) {
        final original = widget.expenseToEdit!;
        final updatedExpense = original.copyWith(
          title: _title,
          amount: _amount,
          category: _selectedCategory ?? 'Autre',
          date: _selectedDate,
          type: _isIncome ? 'income' : 'expense',
          accountId: _selectedAccountId,
          updatedAt: DateTime.now(),
        );

        await DatabaseService.instance.runTransaction((txn) async {
          await expenseProvider.updateExpense(updatedExpense, executor: txn);

          final oldAccountId = original.accountId;
          final oldAmount = original.amount;
          final oldIsIncome = original.type == 'income';

          final newAccountId = _selectedAccountId;
          final newAmount = _amount;
          final newIsIncome = _isIncome;

          if (oldAccountId == newAccountId) {
            if (oldAccountId != null) {
              final oldContribution = oldIsIncome ? oldAmount : -oldAmount;
              final newContribution = newIsIncome ? newAmount : -newAmount;
              final delta = newContribution - oldContribution;
              if (delta != 0) {
                await accountProvider.updateBalance(oldAccountId, delta, executor: txn);
              }
            }
          } else {
            if (oldAccountId != null) {
              final revertDelta = oldIsIncome ? -oldAmount : oldAmount;
              await accountProvider.updateBalance(oldAccountId, revertDelta, executor: txn);
            }
            if (newAccountId != null) {
              final applyDelta = newIsIncome ? newAmount : -newAmount;
              await accountProvider.updateBalance(newAccountId, applyDelta, executor: txn);
            }
          }
        });
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
          date: _selectedDate,
          type: _isIncome ? 'income' : 'expense',
          accountId: _selectedAccountId,
          creatorId: currentUserId,
          creatorName: currentUserName.isNotEmpty ? currentUserName : null,
          createdAt: DateTime.now(),
        );

        await DatabaseService.instance.runTransaction((txn) async {
          await expenseProvider.addExpense(expense, executor: txn);
          if (_selectedAccountId != null) {
            await accountProvider.updateBalance(
              _selectedAccountId!, 
              _isIncome ? _amount : -_amount,
              executor: txn,
            );
          }
        });
      }
      
      if (mounted) {
        Navigator.pop(context);
        if (!_isEditing) {
          MainScreen.globalKey.currentState?.setSelectedIndex(1);
          ExpenseScreen.navigateToTab(1);
        }
      }
    }
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = _isIncome
        ? Provider.of<ExpenseProvider>(context).incomeCategories
        : Provider.of<ExpenseProvider>(context).expenseCategories;
    final accounts = Provider.of<AccountProvider>(context).accounts;
    final currency = Provider.of<ProfileProvider>(context).profile.currency;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? (_isIncome ? l10n.editIncome : l10n.editExpense)
              : (_isIncome ? l10n.addIncome : l10n.addExpense),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: _title,
                autofocus: !_isEditing,
                decoration: InputDecoration(labelText: l10n.title),
                validator: (val) => val == null || val.isEmpty ? l10n.required : null,
                onSaved: (val) => _title = val!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _amount > 0 ? (_amount % 1 == 0 ? _amount.toInt().toString() : _amount.toString()) : '',
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
                isIncome: _isIncome,
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? l10n.pleaseChooseCategory
                    : null,
                onChanged: (val) => setState(() => _selectedCategory = val),
                onSaved: (val) => _selectedCategory = val,
              ),
              const SizedBox(height: 16),
              if (accounts.isNotEmpty)
                DropdownButtonFormField<String>(
                  value: (accounts.any((a) => a.id == _selectedAccountId)) ? _selectedAccountId : null,
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
                    )).toList()
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedAccountId = val;
                    });
                  },
                ),
              if (accounts.isNotEmpty) const SizedBox(height: 16),
              ListTile(
                title: Text(l10n.date),
                subtitle: Text('${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
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
                icon: Icon(_isEditing ? Icons.check : Icons.save),
                label: Text(
                  _isEditing
                      ? l10n.modify
                      : (_isIncome ? l10n.saveIncome : l10n.saveExpense),
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
