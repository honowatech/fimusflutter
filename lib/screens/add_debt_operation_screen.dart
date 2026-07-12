import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:monitrack/l10n/app_localizations.dart';
import '../providers/expense_provider.dart';
import '../providers/account_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/contact_provider.dart';
import '../providers/auth_provider.dart';
import '../models/contact.dart';
import '../utils/formatters.dart';
import '../models/expense.dart';
import '../models/expense.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import 'package:uuid/uuid.dart';

class AddDebtOperationScreen extends StatefulWidget {
  final String? initialTag;
  final bool? initialIsIncome;

  const AddDebtOperationScreen({super.key, this.initialTag, this.initialIsIncome});

  @override
  State<AddDebtOperationScreen> createState() => _AddDebtOperationScreenState();
}

class _AddDebtOperationScreenState extends State<AddDebtOperationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  double _amount = 0.0;
  DateTime _selectedDate = DateTime.now();
  
  late bool _isIncome; // false = Prêt/Dépense, true = Emprunt/Revenu
  bool _isLinkedToCashFlow = false;
  
  // Credit Simulator fields
  bool _isCreditSimulation = false;
  double _interestRate = 5.0;
  String _interestPeriodicity = 'Annuel';
  int _repaymentDuration = 12;
  String _durationUnit = 'Mois';
  String _repaymentFrequency = 'Mensuelle';
  double _installmentAmount = 0.0;
  double _totalDebtAmount = 0.0;
  
  String? _selectedDebtTag;
  String? _selectedDebtorUserId;
  String? _selectedCategory;
  String? _selectedAccountId;
  
  bool _addComment = false;
  String? _comment;

  @override
  void initState() {
    super.initState();
    _isIncome = widget.initialIsIncome ?? false;
    _amountController.addListener(_recalculate);
    _selectedDebtTag = widget.initialTag;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ContactProvider>().fetchContacts();
      
      if (_selectedDebtTag != null) {
        final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
        final balance = expenseProvider.getDebtBalance(_selectedDebtTag!);
        setState(() {
          _isIncome = balance < 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _recalculate() {
    double amount = double.tryParse(_amountController.text.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.')) ?? 0.0;
    if (amount <= 0 || !_isCreditSimulation) {
      setState(() {
        _installmentAmount = 0.0;
        _totalDebtAmount = amount;
      });
      return;
    }

    double durationInYears = _durationUnit == 'Années' ? _repaymentDuration.toDouble() : _repaymentDuration / 12;
    int n = 1;
    if (_repaymentFrequency == 'Mensuelle') n = (durationInYears * 12).round();
    else if (_repaymentFrequency == 'Hebdomadaire') n = (durationInYears * 52).round();
    else if (_repaymentFrequency == 'Quotidienne') n = (durationInYears * 365).round();
    else if (_repaymentFrequency == 'Annuelle') n = durationInYears.round();

    if (n <= 0) n = 1;

    double annualRate = _interestPeriodicity == 'Annuel' ? _interestRate / 100 : (_interestRate / 100) * 12;
    double r = 0;
    if (_repaymentFrequency == 'Mensuelle') r = annualRate / 12;
    else if (_repaymentFrequency == 'Hebdomadaire') r = annualRate / 52;
    else if (_repaymentFrequency == 'Quotidienne') r = annualRate / 365;
    else if (_repaymentFrequency == 'Annuelle') r = annualRate;

    double pmt = 0;
    if (r > 0) {
      pmt = amount * (r * pow(1 + r, n)) / (pow(1 + r, n) - 1);
    } else {
      pmt = amount / n;
    }

    setState(() {
      _installmentAmount = pmt;
      _totalDebtAmount = pmt * n;
    });
  }

  Future<void> _save() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      final authUser = await AuthService().getCachedUser();
      final currentUserId = authUser?['id']?.toString() ?? authUser?['uuid']?.toString();
      final currentUserName = authUser?['name']?.toString() ?? 'Utilisateur';

      final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
      final accountProvider = Provider.of<AccountProvider>(context, listen: false);
      
      final generatedTitle = widget.initialTag != null
          ? (_isIncome ? 'Remboursement perçu' : 'Dette remboursée')
          : (_isIncome ? 'Emprunt' : 'Prêt');

      double originalAmount = double.tryParse(_amountController.text.replaceAll(RegExp(r'\s+'), '').replaceAll(',', '.')) ?? 0.0;
      double amountToRecord = _isCreditSimulation ? _totalDebtAmount : _amount;

      await DatabaseService.instance.runTransaction((txn) async {
        await expenseProvider.addExpense(Expense(
          id: const Uuid().v4(),
          title: generatedTitle,
          amount: amountToRecord,
          category: _isLinkedToCashFlow ? (_selectedCategory ?? 'Autre') : 'Dette',
          date: _selectedDate,
          type: _isIncome ? 'income' : 'expense',
          accountId: _isLinkedToCashFlow ? _selectedAccountId : null,
          debtTag: _selectedDebtTag,
          debtorUserId: _selectedDebtorUserId,
          isLinkedToCashFlow: _isLinkedToCashFlow,
          note: _addComment ? _comment : null,
          interestRate: _isCreditSimulation ? _interestRate : null,
          repaymentDuration: _isCreditSimulation ? _repaymentDuration : null,
          durationUnit: _isCreditSimulation ? _durationUnit : null,
          repaymentFrequency: _isCreditSimulation ? _repaymentFrequency : null,
          installmentAmount: _isCreditSimulation ? _installmentAmount : null,
          creatorId: currentUserId,
          creatorName: currentUserName,
        ), executor: txn);

        if (_isCreditSimulation) {
          double durationInYears = _durationUnit == 'Années' ? _repaymentDuration.toDouble() : _repaymentDuration / 12;
          int n = 1;
          if (_repaymentFrequency == 'Mensuelle') n = (durationInYears * 12).round();
          else if (_repaymentFrequency == 'Hebdomadaire') n = (durationInYears * 52).round();
          else if (_repaymentFrequency == 'Quotidienne') n = (durationInYears * 365).round();
          else if (_repaymentFrequency == 'Annuelle') n = durationInYears.round();
          if (n <= 0) n = 1;

          for (int i = 1; i <= n; i++) {
            DateTime nextDate = _selectedDate;
            if (_repaymentFrequency == 'Mensuelle') nextDate = DateTime(_selectedDate.year, _selectedDate.month + i, _selectedDate.day);
            else if (_repaymentFrequency == 'Hebdomadaire') nextDate = _selectedDate.add(Duration(days: 7 * i));
            else if (_repaymentFrequency == 'Quotidienne') nextDate = _selectedDate.add(Duration(days: i));
            else if (_repaymentFrequency == 'Annuelle') nextDate = DateTime(_selectedDate.year + i, _selectedDate.month, _selectedDate.day);

            await expenseProvider.addExpense(Expense(
              id: const Uuid().v4(),
              title: 'Échéance $i/$n',
              amount: _installmentAmount,
              category: 'Remboursement de dette',
              date: nextDate,
              type: 'expense',
              debtTag: _selectedDebtTag,
              debtorUserId: _selectedDebtorUserId,
              isLinkedToCashFlow: false,
              isPlanned: true,
              creatorId: currentUserId,
              creatorName: currentUserName,
            ), executor: txn);
          }
        }

        if (_isLinkedToCashFlow && _selectedAccountId != null) {
          await accountProvider.updateBalance(
            _selectedAccountId!, 
            _isIncome ? _amount : -_amount,
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

  Future<String?> _showAddDebtTagDialog() async {
    final l10n = AppLocalizations.of(context)!;
    String name = '';
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.addDebtTag),
        content: TextFormField(
          autofocus: true,
          onChanged: (val) => name = val,
          decoration: InputDecoration(labelText: l10n.debtTag),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
          TextButton(
            onPressed: () {
              if (name.trim().isNotEmpty) {
                final profile = Provider.of<ProfileProvider>(context, listen: false).profile;
                final tagLower = name.trim().toLowerCase();
                if (tagLower == '${profile.firstName} ${profile.lastName}'.trim().toLowerCase() ||
                    (profile.firstName.isNotEmpty && tagLower == profile.firstName.trim().toLowerCase()) ||
                    (profile.lastName.isNotEmpty && tagLower == profile.lastName.trim().toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vous ne pouvez pas vous ajouter vous-même.')),
                  );
                  return;
                }
                final provider = Provider.of<ExpenseProvider>(context, listen: false);
                provider.addDebtTag(name.trim());
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
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final categories = _isIncome ? expenseProvider.incomeCategories : expenseProvider.expenseCategories;
    final accounts = Provider.of<AccountProvider>(context).accounts;
    final currency = Provider.of<ProfileProvider>(context).profile.currency;
    final debtTags = expenseProvider.debtTags;
    final authUser = Provider.of<AuthProvider>(context).user;
    final currentUserEmail = authUser?['email']?.toString().toLowerCase() ?? '';
    final currentUserId = expenseProvider.currentUserId;
    final allContacts = Provider.of<ContactProvider>(context).contacts;
    
    final contacts = allContacts.where((c) {
      if (currentUserId != null && c.id.toString() == currentUserId) return false;
      if (currentUserEmail.isNotEmpty && c.email.toLowerCase() == currentUserEmail) return false;
      return true;
    }).toList();

    // Resolve contact ID from tag if not set
    if (_selectedDebtTag != null && _selectedDebtorUserId == null && contacts.isNotEmpty) {
      final match = contacts.firstWhere(
        (c) => c.name.toLowerCase() == _selectedDebtTag!.toLowerCase(),
        orElse: () => Contact(id: -1, name: '', email: '', userCode: ''),
      );
      if (match.id != -1) {
        _selectedDebtorUserId = match.id.toString();
      }
    }

    // List of names/tags that are not contacts to show them separately
    final contactNames = contacts.map((c) => c.name.toLowerCase()).toList();
    
    final profile = Provider.of<ProfileProvider>(context).profile;
    final currentUserNameStr = '${profile.firstName} ${profile.lastName}'.trim().toLowerCase();
    final firstNameStr = profile.firstName.trim().toLowerCase();
    final lastNameStr = profile.lastName.trim().toLowerCase();
    
    final remainingTags = debtTags.where((t) {
      final tagLower = t.toLowerCase();
      if (contactNames.contains(tagLower)) return false;
      if (tagLower == currentUserNameStr) return false;
      if (firstNameStr.isNotEmpty && tagLower == firstNameStr) return false;
      if (lastNameStr.isNotEmpty && tagLower == lastNameStr) return false;
      if (currentUserEmail.isNotEmpty && tagLower == currentUserEmail) return false;
      return true;
    }).toList();

    // Map dropdown value
    String? dropdownValue;
    if (_selectedDebtorUserId != null) {
      dropdownValue = 'contact_$_selectedDebtorUserId';
    } else if (_selectedDebtTag != null) {
      dropdownValue = 'tag_$_selectedDebtTag';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.initialTag != null
              ? (_isIncome ? 'Percevoir un remboursement' : 'Rembourser cette dette')
              : l10n.addDebtOperation,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Contact (Debt Tag) Selection at the very top
              DropdownButtonFormField<String>(
                key: ValueKey('debt_tag_$_isIncome'),
                value: dropdownValue,
                decoration: InputDecoration(
                  labelText: l10n.debtTag,
                  helperText: widget.initialTag != null
                      ? (_isIncome
                          ? 'Percevoir un remboursement de la part de $_selectedDebtTag'
                          : 'Rembourser la dette envers $_selectedDebtTag')
                      : null,
                ),
                items: [
                  ...contacts.map((contact) {
                    final balance = expenseProvider.getDebtBalance(contact.name);
                    final isDebt = balance < 0;
                    final isSettled = balance == 0;
                    final balanceText = isSettled 
                        ? '(Soldé)' 
                        : '(${balance > 0 ? '+' : ''}${balance.toStringAsFixed(0)} $currency)';
                    return DropdownMenuItem(
                      value: 'contact_${contact.id}',
                      child: RichText(
                        text: TextSpan(
                          text: '👤 ${contact.displayName} ',
                          style: Theme.of(context).textTheme.bodyLarge,
                          children: [
                            TextSpan(
                              text: balanceText,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSettled ? Colors.grey : (isDebt ? Colors.red : Colors.green),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  ...remainingTags.map((tag) {
                    final balance = expenseProvider.getDebtBalance(tag);
                    final isDebt = balance < 0;
                    final isSettled = balance == 0;
                    final balanceText = isSettled 
                        ? '(Soldé)' 
                        : '(${balance > 0 ? '+' : ''}${balance.toStringAsFixed(0)} $currency)';
                    return DropdownMenuItem(
                      value: 'tag_$tag',
                      child: RichText(
                        text: TextSpan(
                          text: '🏷️ $tag ',
                          style: Theme.of(context).textTheme.bodyLarge,
                          children: [
                            TextSpan(
                              text: balanceText,
                              style: TextStyle(
                                fontSize: 12,
                                color: isSettled ? Colors.grey : (isDebt ? Colors.red : Colors.green),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  DropdownMenuItem(
                    value: '__add_new__',
                    child: Row(
                      children: [
                        const Icon(Icons.add, size: 18),
                        const SizedBox(width: 8),
                        Text(l10n.addDebtTag),
                      ],
                    ),
                  ),
                ],
                onChanged: widget.initialTag != null ? null : (val) async {
                  if (val == '__add_new__') {
                    final newTag = await _showAddDebtTagDialog();
                    if (newTag != null) {
                      setState(() {
                        _selectedDebtTag = newTag;
                        _selectedDebtorUserId = null;
                      });
                    }
                  } else if (val != null) {
                    if (val.startsWith('contact_')) {
                      final id = val.replaceFirst('contact_', '');
                      final contact = contacts.firstWhere((c) => c.id.toString() == id);
                      setState(() {
                        _selectedDebtTag = contact.name;
                        _selectedDebtorUserId = id;
                      });
                    } else if (val.startsWith('tag_')) {
                      final tag = val.replaceFirst('tag_', '');
                      setState(() {
                        _selectedDebtTag = tag;
                        _selectedDebtorUserId = null;
                      });
                    }
                  }
                },
                validator: (val) => (val == null || val == '__add_new__') ? l10n.required : null,
              ),
              const SizedBox(height: 16),
              
              if (widget.initialTag == null) ...[
                // Type Selection (Income vs Expense)
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      label: Text('Créance (Vous devez percevoir)'),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      label: Text('Dette (Vous devez rembourser)'),
                    ),
                  ],
                  selected: {_isIncome},
                  onSelectionChanged: (Set<bool> newSelection) {
                    setState(() {
                      _isIncome = newSelection.first;
                      if (!_isIncome) {
                        _isCreditSimulation = false;
                      }
                      _recalculate();
                      // Reset category when type changes
                      if (_isLinkedToCashFlow) {
                        _selectedCategory = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: 16),
              ],
              
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: l10n.amount, 
                  prefixText: '$currency ',
                  helperText: _isCreditSimulation 
                      ? 'Total à rembourser : ${_totalDebtAmount.toStringAsFixed(2)} $currency'
                      : null,
                  helperStyle: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
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

              if (widget.initialTag == null && _isIncome) ...[
                SwitchListTile(
                  title: const Text('Dette avec intérêt (Simulateur)'),
                  subtitle: const Text('Calculer et planifier les échéances de remboursement automatiquement'),
                  value: _isCreditSimulation,
                  onChanged: (val) {
                    setState(() {
                      _isCreditSimulation = val;
                      _recalculate();
                    });
                  },
                ),
                if (_isCreditSimulation) ...[
                  Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Détails du crédit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: _interestRate.toString(),
                                  decoration: const InputDecoration(labelText: 'Taux d\'intérêt', suffixText: '%'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    _interestRate = double.tryParse(val) ?? 0.0;
                                    _recalculate();
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: _interestPeriodicity,
                                  decoration: const InputDecoration(labelText: 'Périodicité'),
                                  items: ['Annuel', 'Mensuel'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _interestPeriodicity = val!;
                                      _recalculate();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: _repaymentDuration.toString(),
                                  decoration: const InputDecoration(labelText: 'Durée'),
                                  keyboardType: TextInputType.number,
                                  onChanged: (val) {
                                    _repaymentDuration = int.tryParse(val) ?? 1;
                                    _recalculate();
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: _durationUnit,
                                  decoration: const InputDecoration(labelText: 'Unité'),
                                  items: ['Mois', 'Années'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                                  onChanged: (val) {
                                    setState(() {
                                      _durationUnit = val!;
                                      _recalculate();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _repaymentFrequency,
                            decoration: const InputDecoration(labelText: 'Fréquence de remboursement'),
                            items: ['Mensuelle', 'Hebdomadaire', 'Quotidienne', 'Annuelle'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                            onChanged: (val) {
                              setState(() {
                                _repaymentFrequency = val!;
                                _recalculate();
                              });
                            },
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                const Text('Montant par échéance', style: TextStyle(fontSize: 14)),
                                const SizedBox(height: 8),
                                Text(
                                  '${_installmentAmount.toStringAsFixed(2)} $currency',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
              
              const SizedBox(height: 24),
              
              // Cash flow link toggle
              SwitchListTile(
                title: Text(l10n.linkToCashFlow),
                subtitle: Text(l10n.linkToCashFlowDescription),
                value: _isLinkedToCashFlow,
                onChanged: (val) {
                  setState(() {
                    _isLinkedToCashFlow = val;
                  });
                },
              ),
              
              if (_isLinkedToCashFlow) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(labelText: l10n.category),
                  items: categories.map((cat) => DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  )).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedCategory = val;
                    });
                  },
                  validator: (val) => val == null ? l10n.pleaseChooseCategory : null,
                ),
                const SizedBox(height: 16),
                if (accounts.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedAccountId,
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
                        child: Text(acc.name),
                      )).toList()
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedAccountId = val;
                      });
                    },
                  ),
              ],
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              
              SwitchListTile(
                title: const Text('Ajouter un commentaire'),
                value: _addComment,
                onChanged: (val) {
                  setState(() {
                    _addComment = val;
                  });
                },
              ),
              if (_addComment) ...[
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Commentaire (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  onSaved: (val) => _comment = val,
                ),
                const SizedBox(height: 16),
              ],
              
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
                  l10n.save,
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
