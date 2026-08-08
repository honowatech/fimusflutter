import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/formatters.dart';
import '../utils/translation_helper.dart';
import '../models/expense.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';

class AddExpenseScreen extends StatefulWidget {
  final bool isIncome;
  final String? initialAccountId;
  
  const AddExpenseScreen({super.key, this.isIncome = false, this.initialAccountId});

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

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.initialAccountId;
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final accountProvider = Provider.of<AccountProvider>(context, listen: false);
      
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
        type: widget.isIncome ? 'income' : 'expense',
        accountId: _selectedAccountId,
        creatorId: currentUserId,
        creatorName: currentUserName.isNotEmpty ? currentUserName : null,
      );

      await DatabaseService.instance.runTransaction((txn) async {
        await expenseProvider.addExpense(expense, executor: txn);
        if (_selectedAccountId != null) {
          await accountProvider.updateBalance(
            _selectedAccountId!, 
            widget.isIncome ? _amount : -_amount,
            executor: txn,
          );
        }
      });
      
      if (mounted) {
        Navigator.pop(context);
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

  Future<String?> _showAddCategoryDialog() async {
    final l10n = AppLocalizations.of(context)!;
    String name = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(widget.isIncome ? l10n.addIncomeCategory : l10n.addExpenseCategory),
        content: TextFormField(
          autofocus: true,
          onChanged: (val) => name = val,
          decoration: InputDecoration(labelText: l10n.categoryName),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              if (name.trim().isNotEmpty) {
                final provider = Provider.of<ExpenseProvider>(context, listen: false);
                provider.addCategory(name.trim(), isIncome: widget.isIncome);
                Navigator.pop(ctx, name.trim());
              }
            },
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final categories = widget.isIncome
        ? Provider.of<ExpenseProvider>(context).incomeCategories
        : Provider.of<ExpenseProvider>(context).expenseCategories;
    final accounts = Provider.of<AccountProvider>(context).accounts;
    final currency = Provider.of<ProfileProvider>(context).profile.currency;

    return Scaffold(
      appBar: AppBar(title: Text(widget.isIncome ? l10n.addIncome : l10n.addExpense)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                autofocus: true,
                decoration: InputDecoration(labelText: l10n.title),
                validator: (val) => val == null || val.isEmpty ? l10n.required : null,
                onSaved: (val) => _title = val!.trim(),
              ),
              const SizedBox(height: 16),
              TextFormField(
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
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(labelText: l10n.category),
                items: [
                  ...categories.map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(l10n.translateCategory(cat)),
                  )).toList(),
                  DropdownMenuItem(
                    value: '__add_new__',
                    child: Row(
                      children: [
                        const Icon(Icons.add, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.addNew),
                      ],
                    ),
                  ),
                ],
                onChanged: (val) async {
                  if (val == '__add_new__') {
                    final newCategory = await _showAddCategoryDialog();
                    if (newCategory != null) {
                      setState(() {
                        _selectedCategory = newCategory;
                      });
                    } else {
                      setState(() {
                        _selectedCategory = categories.contains(_selectedCategory) ? _selectedCategory : null;
                      });
                    }
                  } else {
                    setState(() {
                      _selectedCategory = val;
                    });
                  }
                },
                validator: (val) => (val == null || val == '__add_new__') ? l10n.pleaseChooseCategory : null,
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
                      child: Text(acc.name.isNotEmpty ? acc.name : 'Sans nom'),
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
                  side: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.save),
                label: Text(
                  widget.isIncome ? l10n.saveIncome : l10n.saveExpense,
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
