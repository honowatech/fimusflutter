import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/currency_converter.dart';
import '../utils/formatters.dart';
import '../models/expense.dart';
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

  /// Devise dans laquelle l'utilisateur saisit : celle du compte imputé s'il en
  /// porte une, sinon celle du profil. Même règle que la devise estampillée sur
  /// l'opération à sa création, pour que l'étiquette affichée corresponde à ce
  /// qui sera réellement enregistré.
  ///
  /// En modification, la devise de l'opération est figée et ne se réécrit
  /// jamais : c'est elle qu'on annonce, quel que soit le compte choisi.
  String _entryCurrency(BuildContext context) {
    final profileCurrency =
        Provider.of<ProfileProvider>(context).profile.currency;
    if (_isEditing && widget.expenseToEdit!.currency != null) {
      return widget.expenseToEdit!.currency!;
    }
    final accountCurrency = Provider.of<AccountProvider>(context)
        .accounts
        .where((a) => a.id == _selectedAccountId)
        .firstOrNull
        ?.currency;
    return CurrencyConverter.resolveForNewOperation(
          accountCurrency: accountCurrency,
          profileCurrency: profileCurrency,
        ) ??
        profileCurrency;
  }

  /// Signale un refus d'écriture sans fermer le formulaire : aucune ligne n'a
  /// été écrite, la saisie de l'utilisateur doit rester à l'écran pour qu'il
  /// puisse réessayer après une synchronisation.
  void _showWriteFailure(BalanceWriteResult result) {
    final l10n = AppLocalizations.of(context)!;
    final message = result.isRateUnavailable
        ? l10n.balanceRateUnavailable(
            result.missingFrom ?? '?', result.missingTo ?? '?')
        : l10n.operationNotFound;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final accountProvider = Provider.of<AccountProvider>(context, listen: false);

      final BalanceWriteResult result;
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

        // Delta, changement de compte et conversion sont entièrement traités
        // par le provider, dans une seule transaction.
        result = await expenseProvider.updateExpenseWithBalance(
          original: original,
          updated: updatedExpense,
          accountProvider: accountProvider,
        );
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

        result = await expenseProvider.addExpenseWithBalance(
          expense,
          accountProvider: accountProvider,
        );
      }

      if (!mounted) return;
      // Écriture refusée : rien n'a été enregistré, on garde le formulaire
      // ouvert plutôt que d'annoncer un faux succès.
      if (!result.isSuccess) {
        _showWriteFailure(result);
        return;
      }

      Navigator.pop(context);
      if (!_isEditing) {
        MainScreen.globalKey.currentState?.setSelectedIndex(1);
        ExpenseScreen.navigateToTab(1);
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
    // Devise de saisie annoncée à l'utilisateur : elle suit le compte imputé,
    // pas systématiquement celle du profil.
    final currency = _entryCurrency(context);

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
                decoration: InputDecoration(
                  labelText: l10n.amount,
                  prefixText: '$currency ',
                  // Rappel explicite : sur un compte en devise étrangère, le
                  // préfixe seul passe inaperçu.
                  helperText: l10n.entryCurrencyHint(currency),
                ),
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
